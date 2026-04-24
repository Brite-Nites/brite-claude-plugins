# BC-5925 — Tighten Marketing_Claude_MCP service user permissions

**Linear:** https://linear.app/brite-nites/issue/BC-5925/
**Blocks:** first SF-consuming marketing skill ship (BC-2717 et al)
**BlockedBy:** BC-5924 (Done, PR #178)
**Milestone:** RevOps Plugin
**Scope:** cross-repo (brite-salesforce metadata PR + prod org-data ops) — destructive to prod.

## 1. Context

BC-5924 audited the `Marketing_Claude_MCP` service user (`marketingadmin@britenites.com`) on 2026-04-22 and found it sitting on the `System Administrator` profile with 6 permission-set assignments against a minimum-required baseline of `Api Enabled` + Read-only on 11 marketing-relevant objects. Findings documented in `plugins/marketing/tools/integrations/salesforce.md` §Service User Permissions.

## 2. Re-run audit (2026-04-24, this session)

Ran the full BC-5924 audit methodology (Q1–Q4) from `brite-salesforce/` via `sf data query --target-org marketing-claude-prod`. **Zero drift.**

| Query | Result | Delta vs 2026-04-22 |
|---|---|---|
| Q1 User identity | Profile=`System Administrator`, Id=`005a500001nSS9VAAW`, IsActive=true | none |
| Q2 Permset assignments | 6 (1 profile-owned auto + `OutboundSync_Integration` + `StandardEinsteinActivityCapturePsl` + `Automation_Validation_Bypass` + `Sales_Operations` + `AirCall_PermissionSet`) | none |
| Q3 High-risk perm flags (per explicit permset) | `ModifyAllData` / `ViewAllData` / `ApiEnabled` / `AuthorApex` — **all `false` across all 5 explicit permsets** | none |
| Q4 ObjectPermissions on 11 marketing objects | **only `Sales_Operations`** surfaces rows: CRUD+Delete on Account / Contact / Lead / Campaign / Territory__c / Opportunity; Read-only on Lifecycle_Stage_History__c | none |

**Implication:** every high-risk capability (Modify All Data, View All Data, Author Apex, Api Enabled) flows from the `System Administrator` profile — not from any explicit permset. Downgrading the profile evaporates all four cleanly.

**Implication 2:** Location, Task, Event, AccountContactRelation, and In_App_Checklist_Settings__c Read today reaches **only** through the SysAdmin profile (no permset row exists). Post-downgrade, the new narrow permset must grant Read on **all 11 targets**, not just the 6 that Sales_Operations already covers.

**Implication 3:** `User` must also be readable — the MCP availability check (`SELECT Id FROM User LIMIT 1`) is canonical in `salesforce.md` §Availability check (1 MCP call). Include User in the permset's object list to preserve T7. Permset grants Read on **12 objects** total.

## 3. Target state

| Field | Current | Target |
|---|---|---|
| Profile | `System Administrator` | `Minimum Access - Salesforce` |
| Permset assignments (count) | 6 | 2 (profile-owned + new narrow) |
| Api Enabled source | Profile (System Administrator) | `Marketing_MCP_Read_Only` permset |
| Object access | Full CRUD+VA+MA on every object (profile) | Read-only on 12 specified objects |
| Modify All Data | Yes | No |
| Validation rule bypass | Yes (`Automation_Validation_Bypass`) | No |
| Author Apex | Yes | No |

Aligns with [ADR-004 Permission Set Strategy](https://github.com/Brite-Nites/brite-salesforce/blob/main/docs/decisions/004-permission-set-strategy.md) — Minimum Access profile + composable permsets.

## 4. Changes

### 4.1 brite-salesforce PR (metadata)

**New file:** `force-app/main/default/permissionsets/Marketing_MCP_Read_Only.permissionset-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Marketing MCP Read Only</label>
    <description>Read-only access for the Marketing_Claude_MCP service user. API-enabled; grants Read on the 12 objects the planned SOQL skills touch (including User for the canonical MCP availability check). Do not assign to interactive users. See BC-5925.</description>
    <hasActivationRequired>false</hasActivationRequired>
    <license>Salesforce</license>
    <!-- System permissions -->
    <userPermissions>
        <enabled>true</enabled>
        <name>ApiEnabled</name>
    </userPermissions>
    <!-- Object permissions: Read-only on 12 objects -->
    <objectPermissions>
        <allowRead>true</allowRead>
        <allowCreate>false</allowCreate>
        <allowEdit>false</allowEdit>
        <allowDelete>false</allowDelete>
        <viewAllRecords>false</viewAllRecords>
        <modifyAllRecords>false</modifyAllRecords>
        <object>Account</object>
    </objectPermissions>
    <!-- ... repeat for: AccountContactRelation, Campaign, Contact, Event, In_App_Checklist_Settings__c, Lead, Lifecycle_Stage_History__c, Location, Opportunity, Task, Territory__c, User ... -->
</PermissionSet>
```

Exact object list (13 total, alphabetized for XML stability):
1. `Account`
2. `AccountContactRelation`
3. `Campaign`
4. `Contact`
5. `Event`
6. `In_App_Checklist_Settings__c`
7. `Lead`
8. `Lifecycle_Stage_History__c`
9. `Location`
10. `Opportunity`
11. `Task`
12. `Territory__c`
13. `User`

> **Note:** final count is 13 including `User`, not 11. The 11-object framing in BC-5924 salesforce.md counts planned-skill query targets only; `User` is implicit via the MCP availability check recipe documented in the same file.

**No changes to:**
- `.profile-meta.xml` (target profile `Minimum Access - Salesforce` is already source-controlled)
- `.object-meta.xml` (FLS grants flow from the permset's objectPermissions, no field-level tightening needed for SOQL-only use)
- existing permsets (`Sales_Operations` / `OutboundSync_Integration` etc. remain in repo — we're only changing the service user's *assignments*)

### 4.2 Org-data operations (post-merge, documented in PR body, not in metadata)

PermissionSetAssignment records and User.ProfileId are **data**, not metadata — they don't deploy via `sf project deploy`. Executed manually via `sf data` commands after the permset XML is deployed.

**Sequencing: staged (additive first, destructive last)** to allow per-step verification and cheap rollback.

| # | Step | Command | Rollback |
|---|---|---|---|
| 1 | Deploy permset XML to prod | `sf project deploy start --source-dir force-app/main/default/permissionsets/Marketing_MCP_Read_Only.permissionset-meta.xml --target-org brite-prod` | Delete the permset via UI |
| 2 | Assign new permset to service user (**additive** — no loss) | `sf data create record --sobject PermissionSetAssignment --values "AssigneeId=005a500001nSS9VAAW PermissionSetId=<id-of-new-permset>" --target-org brite-prod` | `sf data delete record` the PSA |
| 3 | Smoke test (still SysAdmin — must pass) | MCP: `run_soql_query("SELECT Id FROM User LIMIT 1")` | — |
| 4 | **Cut-over:** change User.ProfileId to Minimum Access (Id lookup first) | `sf data update record --sobject User --record-id 005a500001nSS9VAAW --values "ProfileId=<minimum-access-profile-id>" --target-org brite-prod` | `sf data update record` back to SysAdmin ProfileId |
| 5 | Smoke test (now relies on new permset) | MCP: `run_soql_query("SELECT Id FROM User LIMIT 1")` | rollback step 4 if fails |
| 6 | Cleanup unassignments (5 PSAs: 4 broad + Sales_Operations) | `sf data delete record --sobject PermissionSetAssignment --record-id <psa-id>` × 5 | Re-create PSAs (IDs captured pre-delete) |
| 7 | Final smoke + audit re-run | Q1–Q4 from §2 above | — |

**Why staged over all-at-once:** step 4 is the only destructive move. Steps 1–3 are additive (new grant on top of existing SysAdmin). Step 4 flips the only dependency from profile to permset. If the MCP smoke test (step 5) fails, step 4 rolls back in one command and the service user is back to SysAdmin in seconds. If we did all-at-once, a bug in the permset XML would lock out the MCP while we still had to unwind 5 PSA deletions to recover.

## 5. Verify — objective criteria

Reuse BC-5924's re-runnable audit queries (salesforce.md §Audit methodology) for post-tightening verification. Executed from `brite-salesforce/` via `sf data query --target-org marketing-claude-prod`.

| Test | Command / Action | Pass criteria |
|---|---|---|
| T6 | `SELECT PermissionsModifyAllData, PermissionsApiEnabled FROM PermissionSet WHERE Id IN (<2 assigned permset IDs>)` | `ModifyAllData=false` on both; `ApiEnabled=true` on `Marketing_MCP_Read_Only`, `false` on profile-owned |
| T7 | Service user runs `SELECT Id FROM User LIMIT 1` via plugin MCP | Query succeeds (no regression) |
| T8 (sanity, from BC-5924) | Service user runs `SELECT Id, Email, Status FROM Lead LIMIT 1` via plugin MCP against prod | Query succeeds — Lead read path intact |
| T9 (new) | Service user runs `SELECT Id FROM Account LIMIT 1` via plugin MCP | Query succeeds (covers object not in original T8) |
| T10 (new) | Service user runs `UPDATE Lead ...` equivalent via MCP (not supported by read-only toolset, so test via `sf data update record`) | **Expected to FAIL** with insufficient-privilege — proves write path is blocked |
| T11 (new, profile check) | Q1 from §2 re-run | Profile.Name = `Minimum Access - Salesforce` |
| T12 (new, permset count) | Q2 from §2 re-run | 2 assignments: 1 profile-owned + `Marketing_MCP_Read_Only` |

All test results paste into the brite-salesforce PR body at Gate 4.

## 6. Rollback

| Scenario | Rollback |
|---|---|
| Step 1 deploy fails | No org change yet — fix XML, retry |
| Step 2 PSA create fails | No effect on service user — investigate, retry |
| Step 5 smoke fails after profile change | `sf data update record --sobject User --record-id 005a500001nSS9VAAW --values "ProfileId=<sysadmin-profile-id>"` — service user back to SysAdmin in one call |
| Step 6 PSA deletes fail | Re-create PSAs using IDs captured from Q2 re-run at start of session |
| Discovery: a planned skill needs a field/object not in the permset | Add an `objectPermissions` block to the permset, re-deploy (additive, no cut-over) |

## 7. Check-in gates (from BC-5925 issue body)

| # | Gate | When |
|---|---|---|
| 1 | Present findings + scope | ✅ done this session (§2 + §3 + §4.1) |
| 2 | Plan approval | ← **current** — before opening the brite-salesforce PR |
| 3 | Dry-run + Apex test review | after `sf project deploy validate` + `sf apex run test` on sandbox |
| 4 | Pre-merge review | review dry-run output + Apex test results |
| 5 | Pre-prod-deploy | before running §4.2 step 1 on brite-prod |
| 6 | Pre-cut-over | before §4.2 step 4 (User.ProfileId change) |
| 7 | Pre-cleanup | before §4.2 step 6 (5 PSA deletes) |
| 8 | Final | after T6–T12 |

One question at a time per gate. Never batch.

## 8. Out of scope

- ECA consumer key / scopes (BC-5579)
- JWT flow
- `salesforce.md` doc updates — BC-5924 owns it; at most, append a `2026-04-MM` Last-verified line after T6–T12 pass
- Any broadening of service user permissions
- Changes to skills (BC-2717 et al) — they query via the service user, which retains identical object-read paths
- Permset tightening for other integration users (AirCall, OutboundSync, Einstein Activity Capture) — those are separate integrations owned by their respective Connected Apps

## 9. Worktree + branch

- Plugins repo worktree: `.claude/worktrees/bc-5925-tighten-marketing-mcp-permissions/` (current branch `worktree-bc-5925-tighten-marketing-mcp-permissions`; will rename to `holden/bc-5925-tighten-marketing_claude_mcp-service-user-permissions-brite` before push to match Linear `gitBranchName`)
- brite-salesforce worktree: to be created at `brite-salesforce/.claude/worktrees/bc-5925/` on branch `holden/bc-5925-tighten-marketing-mcp-permset` at §4 execution time
