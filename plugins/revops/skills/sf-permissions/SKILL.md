---
name: sf-permissions
description: Salesforce Permission Set / Permission Set Group analysis and access auditing for Brite's brite-salesforce repo. TRIGGER when user asks "who has access to X?", analyzes permsets or permset groups, adds CustomField FLS (reminder: 7-permset sync across Base_CRM_Access + Finance_Read + Deal_Financial_Read + Sales_Operations + Marketing + Account_Location_Edit + Acquisition_Full_Access), touches {Team}_Group / {Team}_Management_Group naming, debugs Lifecycle_Stage__c automation-only restrictions, session-based permset activation (HubSpot_Migration, SessionPermissionSetActivation), CreateAuditFields INSERT-only gotcha, or restricted record-type visibility scoping (Acquisition, Partner_Fulfillment). DO NOT TRIGGER when creating new metadata (use sf-metadata), deploying permission sets (use sf-deploy), or Apex-managed sharing logic (use sf-apex).
user-invocable: false
license: MIT
metadata:
  version: "1.2.0-brite.1"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  inspiration: "PSLab by Oumaima Arbani (github.com/OumArbani/PSLab)"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Permissions & Security (lines 164–173) and @imports docs/decisions/004-permission-set-strategy.md. -->

# sf-permissions: Permission Analysis (Brite edition)

Permission-set analysis and access auditing for the **brite-salesforce** org: hierarchy views, "who has access to X?" investigations, user-permission analysis, and permission-metadata review. Layered with Brite's capability-named permset taxonomy, 7-permset FLS sync discipline, Lifecycle automation-only restrictions, restricted record-type scoping, and session-based activation caveats.

---

## Brite Context

Brite's permission model (per `brite-salesforce/CLAUDE.md` §Engineering Standards + §Permissions & Security):

- **Profiles:** only `Minimum Access` is tracked in source; all grants flow through Permission Sets.
- **Permset naming:** permsets named for capabilities (`Base_CRM_Access`, `Work_Order_Read`); permset groups named for teams — `{Team}_Group` for ICs, `{Team}_Management_Group` for leads.
- **Canonical role map:** `brite-salesforce/docs/artifacts/user-role-matrix.md` §3.
- **Strategy ADR:** `brite-salesforce/docs/decisions/004-permission-set-strategy.md` (imported by `brite-salesforce/CLAUDE.md`).

---

## Brite Permission Conventions

These rules are non-negotiable on brite-salesforce and must surface during permset edits, FLS changes, and access investigations.

### 7-permset FLS sync

When adding a `CustomField`, update FLS in **all seven** of these permission sets:

1. `Base_CRM_Access`
2. `Finance_Read`
3. `Deal_Financial_Read`
4. `Sales_Operations`
5. `Marketing`
6. `Account_Location_Edit`
7. `Acquisition_Full_Access`

Missing any of these ships a field that Dynamic Forms silently hides — **even for System Administrators** — because `View All Data` / `Modify All Data` do **not** bypass Field-Level Security. When a `--source-dir` deploy rolls back (e.g., ECA failure), deploy fields and FLS individually with `-m` flags so partial progress is preserved.

### Lifecycle fields = automation-only

`Lifecycle_Stage__c` and `Lifecycle_*_Date__c` must be `editable: false` in every permset **except** `Sales_Operations`. These drive the `Lifecycle_Stage_History__c` audit trail; manual edits corrupt history.

### App visibility lives in permsets, not the profile

Custom Lightning apps default to `visible: false` in the `Minimum Access` profile. Grant via `applicationVisibilities` on relevant permsets:
- `Base_CRM_Access` for all-user apps
- Dedicated `App_*` permsets for team-scoped apps (see `App_Business_Development`, `App_Sales_Leader` as templates)

Manual org toggles get reverted on every deploy — always enforce via source.

### Restricted record-type visibility — intentional scope gaps

Acquisition and Partner_Fulfillment record-type visibility is intentionally **absent** from `Base_CRM_Access`, `Sales_Operations`, `Finance_Read`, `Marketing`, and `Minimum Access`. Only dedicated permsets (`Acquisition_Full_Access`, `Acquisition_Pipeline_View`, `Partner_Fulfillment_Access`) grant visibility. Adding RT visibility to baseline permsets breaks the scoping model — audit carefully before widening.

### New record type → Minimum Access profile updates required

When adding a new Opportunity record type, also update the `Minimum Access` profile with `layoutAssignments`, `recordTypeVisibilities`, and `fieldPermissions` (for any new fields). Missing entries cause deploy failures or unintended default-layout assignment.

### Session-based permsets ≠ Bulk API / `sf` CLI

`HubSpot_Migration` has `hasActivationRequired: true`. The `Bypass_Validation_Rules` custom permission activates **per-UI-session** via `SessionPermissionSetActivation` — it does **not** take effect in Bulk API or `sf` CLI sessions. For data loads that need the bypass:

- verify with `FeatureManagement.checkPermission()` first
- workarounds: `sf data create record` (single REST call), patch data after load, or temporarily flip `hasActivationRequired: false`

All validation rules should gate on `NOT($Permission.Bypass_Validation_Rules)` as the first `AND` argument so the bypass is universally available when activated.

### `CreateAuditFields` — INSERT-only, capitalization matters

The `CreateAuditFields` user permission (API name **capitalized** — `createAuditFields` is rejected with "Unknown user permission" at deploy time) allows setting `CreatedDate` on record creation. Salesforce silently **ignores it on UPDATE**. Records inserted without the permission must be DELETED and re-inserted — `upsert` takes the UPDATE path for existing records and `CreatedDate` remains unchanged.

Requires the org-level **"Set Audit Fields upon Record Creation"** toggle (Setup → User Interface). Verified empirically during BC-2744 activity-date fix.

---

## When This Skill Owns the Task

Use `sf-permissions` when the work involves:
- permission set / permission set group analysis
- user access investigation
- finding which permission grants object / field / Apex / flow / tab / custom-permission access
- auditing or exporting permission configuration
- reviewing permission metadata impacts

Delegate elsewhere when the user is:
- creating new metadata definitions → [sf-metadata](../sf-metadata/SKILL.md)
- deploying permission sets → [sf-deploy](../sf-deploy/SKILL.md)
- analyzing Apex-managed sharing logic → [sf-apex](../sf-apex/SKILL.md)

---

## Required Context to Gather First

Ask for or infer:
- target org alias
- whether the question is about an object, field, Apex class, flow, tab, custom permission, or specific user
- whether the goal is hierarchy visualization, access detection, export, or metadata generation
- whether the output should be terminal-focused or documentation-friendly

---

## Recommended Workflow

### 1. Classify the request
| Request shape | Default capability |
|---|---|
| “who has access to X?” | permission detector |
| “what does this user have?” | user analyzer |
| “show me the hierarchy” | hierarchy viewer |
| “export this permset” | exporter |
| “generate metadata from analysis” | generator or handoff |

### 2. Connect to the correct org
Verify `sf` auth before running permission analysis.

### 3. Use the narrowest useful query
Prefer focused analysis over broad org-wide scans unless the user explicitly wants a full audit.

When choosing identifiers, prefer stable metadata names first:
- `PermissionSet.Name`
- `PermissionSetGroup.DeveloperName`
- `CustomPermission.DeveloperName`
- object and field API names such as `Account` or `Account.AnnualRevenue`
- `Assignee.Username` / email for user-centric checks

Use Salesforce record IDs only when:
- the underlying object model requires `ParentId` or `SetupEntityId`, or
- you are drilling into records returned by a prior read-only query in the same investigation

### 4. Render findings clearly
Use:
- ASCII tree or table output for terminal work
- Mermaid only when documentation benefit is clear
- concise summaries of which permission source grants access

### 5. Hand off creation or deployment work
Use:
- [sf-metadata](../sf-metadata/SKILL.md) for richer metadata generation
- [sf-deploy](../sf-deploy/SKILL.md) for deployment

---

## High-Signal Rules

- distinguish direct Permission Set grants from grants via Permission Set Groups
- prefer `Name` / `DeveloperName` / API names over org-specific record IDs for first-pass investigation queries
- be explicit about whether access is object-level, field-level, class-level, flow-level, or custom-permission-based
- use Tooling API where required for setup entities and advanced visibility questions
- for agent access questions, verify exact agent-name matching in permission metadata
- when a follow-up child query requires `ParentId` or `SetupEntityId`, resolve the ID from a prior result instead of starting with copied IDs

---

## Output Format

When finishing, report in this order:
1. **What was analyzed**
2. **Org / subject scope**
3. **Which permissions grant access**
4. **Whether access is direct or inherited**
5. **Recommended follow-up**

Suggested shape:

```text
Permission analysis: <hierarchy / detect / user / export>
Scope: <org, user, permission target>
Findings: <permsets / groups / access level>
Source: <direct assignment or via group>
Next step: <export, generate metadata, or deploy changes>
```

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| generate or modify permission metadata | [sf-metadata](../sf-metadata/SKILL.md) | metadata authoring |
| deploy permission changes | [sf-deploy](../sf-deploy/SKILL.md) | rollout |
| identify Apex classes needing grants | [sf-apex](../sf-apex/SKILL.md) | implementation context |
| bulk user assignment analysis | [sf-data](../sf-data/SKILL.md) | larger data operations |

---

## Reference Map

### Start here
- [references/permission-model.md](references/permission-model.md)
- [references/soql-reference.md](references/soql-reference.md)
- [references/workflow-examples.md](references/workflow-examples.md)

### Specialized analysis
- [references/agent-access-guide.md](references/agent-access-guide.md)
- [references/usage-examples.md](references/usage-examples.md)

---

## Score Guide

| Score | Meaning |
|---|---|
| 90+ | strong permission analysis with clear access sourcing |
| 75–89 | useful audit with minor gaps |
| 60–74 | partial visibility only |
| < 60 | insufficient evidence; expand analysis |
