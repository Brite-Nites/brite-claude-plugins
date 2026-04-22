# BC-5924 — Audit Marketing_Claude_MCP Service User Permission Baseline

**Linear:** [BC-5924](https://linear.app/brite-nites/issue/BC-5924/audit-marketing-claude-mcp-service-user-permission-baseline-plugins)
**Branch:** `holden/bc-5924-audit-marketing-mcp-baseline`
**Worktree:** `.claude/worktrees/bc-5924-audit-marketing-mcp-baseline`
**Priority:** High (P2)
**Blocks:** BC-5925 (Part B permset-tightening, conditional on findings)

---

## 1. Goal

Document the `Marketing_Claude_MCP` service user's current permission baseline in `plugins/marketing/tools/integrations/salesforce.md` via read-only SF org queries, and flag any over-provisioning for Part B follow-up. **No org mutations in this issue.**

## 2. Why this is worth doing first (in the remaining milestone)

`@salesforce/mcp` has **no server-side read-only mode, no row limits, no destructive-tool gates**. Blast radius is controlled entirely by the service user's permset assignments. The plugin's `--toolsets data` scoping is belt-and-suspenders false comfort if the user has `Modify All Data` or broad write permissions. This audit is the highest-leverage safety gate before BC-2717 / BC-2720 / BC-2725 / BC-2727 / BC-2728 start hitting the org at runtime.

## 3. Cross-repo constraint (flag early)

The SOQL queries must run from `~/Projects/work/brite-nites/brite-salesforce`, authenticated as either:
- The service user itself (`marketing-claude-prod` alias — already set as `sf config target-org`), **if** it has sufficient read on `PermissionSetAssignment` / `ObjectPermissions` / `PermissionSet`.
- Or a Brite SF admin with Setup visibility (alias TBD — surface at the Explore gate).

The resulting doc edit lands in this repo. No commits to `brite-salesforce` in this issue.

## 4. Phase structure

Explore → Plan → Execute → Verify. Three explicit check-in gates. One question at a time at each gate.

## 5. Task list (9 tasks, tracked via TaskCreate)

| # | Phase | Task | Gate |
|---|-------|------|------|
| 1 | Explore | Query SF: service user identity + permset assignments | — |
| 2 | Explore | Enumerate object permissions on 11 marketing objects | — |
| 3 | — | **Check-in gate 1:** findings + Part B Y/N | ✅ |
| 4 | Plan | Draft §Service User Permissions section content | — |
| 5 | — | **Check-in gate 2:** plan approval | ✅ |
| 6 | Execute | Edit salesforce.md (pre-edit + post-edit checkpoints) | ✅✅ |
| 7 | Execute | Commit | — |
| 8 | Verify | Run objective test table (T1–T5, T8) | — |
| 9 | — | **Check-in gate 3:** verify results + final approval | ✅ |

## 6. Explore — step-by-step SOQL

All queries run from `~/Projects/work/brite-nites/brite-salesforce` via `sf data query`. Service-user email is in Bitwarden item *"Marketing Claude MCP — JWT private key"* Notes field.

### 6.1 Identify service user

```sql
SELECT Id, Username, Email, ProfileId, Profile.Name, IsActive
FROM User
WHERE Email = '<service-user-email>'
```

### 6.2 Enumerate permset assignments

```sql
SELECT Id, PermissionSetId, PermissionSet.Name, PermissionSet.Label
FROM PermissionSetAssignment
WHERE AssigneeId = '<service-user-id>'
```

### 6.3 High-risk permissions per permset

```sql
SELECT Name, PermissionsModifyAllData, PermissionsViewAllData,
       PermissionsApiEnabled, PermissionsAuthorApex
FROM PermissionSet
WHERE Id IN ('<permset-ids>')
```

### 6.4 Object permissions across 11 marketing objects

```sql
SELECT Parent.Name, SobjectType,
       PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete,
       PermissionsViewAllRecords, PermissionsModifyAllRecords
FROM ObjectPermissions
WHERE Parent.Id IN ('<permset-ids>')
  AND SobjectType IN (
    'Account','Contact','Lead','Campaign','Territory__c','Location','Activity',
    'Lifecycle_Stage_History__c','Opportunity','AccountContactRelation',
    'In_App_Checklist_Settings__c'
  )
```

### 6.5 Cross-reference

Read `brite-salesforce/docs/artifacts/user-role-matrix.md` for expected baseline.

### 6.6 Per-skill minimum-required mapping

Enumerate the min required permissions per planned consumer skill: BC-2717 (list-building), BC-2720 (reply-processing), BC-2725 (lead-routing), BC-2727 (data-enrichment), BC-2728 (crm-hygiene).

## 7. Check-in gate 1

Present:
- Actual permset assignments (permset names + labels).
- 11-object CRUD matrix.
- 5 high-risk flags (ModifyAllData, ViewAllData, ApiEnabled, AuthorApex, Delete rights).
- Comparison vs required-minimum per skill.

Ask the user exactly one question: **"Did the audit surface over-provisioning → file Part B (BC-5925) tightening next session? Or audit clean → mark Part B Not Applicable?"**

## 8. Plan — §Service User Permissions section

~40 lines, inserted between §Auth and §Registration in `plugins/marketing/tools/integrations/salesforce.md`. Contents:

1. Service user identity (email, profile, active Y/N).
2. Permset assignment list (name + label).
3. Object-level CRUD matrix across the 11 objects (table).
4. Destructive capabilities summary (ModifyAllData, ViewAllData, ApiEnabled, AuthorApex, Delete rights).
5. Minimum-required-per-skill matrix (5 skills × required permissions + cited SOQL patterns).
6. Outcome:
   - **Over-provisioned** → explicit pointer to BC-5925 Part B + the specific permset + permission that exceeds baseline.
   - **Clean** → explicit `audit clean YYYY-MM-DD` line + "Part B not applicable."

Style conventions: follow existing §Auth / §Registration table layout; use Markdown tables (not dense bullets — avoids Linear list-mangling patterns).

## 9. Execute

1. **CHECKPOINT (pre-edit):** confirm section content + placement.
2. Edit `plugins/marketing/tools/integrations/salesforce.md`.
3. **CHECKPOINT (post-edit, pre-commit):** confirm diff is correct.
4. Commit: `BC-5924: document Marketing_Claude_MCP service user permission baseline`.

## 10. Verify — objective tests

| Test | Setup | Command / Action | Pass criteria |
|------|-------|------------------|---------------|
| T1 | — | `grep -c "§Service User Permissions\|## Service User Permissions" plugins/marketing/tools/integrations/salesforce.md` | ≥1 |
| T2 | — | Section lists actual permset names from live org query | Names match output of PermissionSetAssignment query |
| T3 | — | Section contains 11-object CRUD matrix | 11 rows present |
| T4 | — | Section contains 5-skill minimum-required matrix | 5 skill rows, each with cited SOQL patterns |
| T5 | — | `./scripts/validate.sh` | Exit 0 |
| T8 | Cross-repo verification | `run_soql_query` with `SELECT Id FROM User LIMIT 1` from a known authenticated context | Returns row(s) without auth error |

Paste all results in the PR body. T6 + T7 (post-tightening permset verification) live in BC-5925 (Part B).

## 11. Out of scope

- ECA consumer key / scope changes (BC-5579 territory).
- JWT flow changes.
- Tightening `brite-salesforce` permsets (that's BC-5925 Part B, conditional on Section 7 findings).
- Any skill authoring (BC-2717 et al).
- Broadening scope — this is audit + documentation only.

## 12. Risks + unknowns

- **R1: Service user lacks Setup read.** Mitigation: at Explore task 1, test the PermissionSetAssignment query with current `marketing-claude-prod` alias. If it errors on insufficient permissions, surface at check-in gate 1 with a question about which admin alias to use instead.
- **R2: Linear markdown mangling.** Mitigation: per `memory/gotcha_linear_markdown_mangling.md`, use Markdown tables (not dense bullets) in the new section. No update-pass on the issue body after creation.
- **R3: 11-object list drift.** The issue body enumerates 11 objects; cross-reference against `brite-salesforce/docs/artifacts/user-role-matrix.md` at Explore step 5 — if new objects are in-scope, note it in the findings.
- **R4: Context7 quota exceeded** (3rd consecutive session). Handbook lookups degraded — fall back to direct `gh api` reads if needed for handbook cross-references.

## 13. References

- **Issue:** [BC-5924](https://linear.app/brite-nites/issue/BC-5924/...)
- **Rescope plan:** `docs/plans/revops-milestone-rescope-plan.md`
- **Sibling (blocked by this):** [BC-5925](https://linear.app/brite-nites/issue/BC-5925/...) Part B permset tightening
- **Related skills (consumers):** BC-2717, BC-2720, BC-2725, BC-2727, BC-2728
- **Prior provisioning:** BC-5534 (SF MCP research), BC-5535 (plugin adoption), BC-5579 (admin ECA + cert)
- **Target file:** `plugins/marketing/tools/integrations/salesforce.md`
- **Cross-repo:** `brite-salesforce/docs/artifacts/user-role-matrix.md`
- **Credentials:** Bitwarden item *"Marketing Claude MCP — JWT private key"* (Engineering collection)
