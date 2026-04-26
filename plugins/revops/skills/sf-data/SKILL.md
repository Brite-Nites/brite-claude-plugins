---
name: sf-data
description: Salesforce data operations (Brite edition) with 130-point scoring. TRIGGER when user creates test data, performs bulk import/export, uses sf data CLI commands, needs data factory patterns for Apex tests, works in brite-salesforce, asks about HubSpot migration ETL, email-as-Task migration semantics, setSaveAsActivity Email Logs monitoring, Bulk API session-permset gotchas, CreateAuditFields INSERT-only behavior, #N/A null sentinel in Bulk CSVs, or Task.AccountId re-parenting via WhatId. DO NOT TRIGGER when SOQL query writing only (use sf-soql), Apex test execution (use sf-testing), or metadata deployment (use sf-deploy).
user-invocable: false
license: MIT
metadata:
  version: "1.2.0-brite.1"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "130 points across 7 categories"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Metadata Authoring (lines 130, 143-144) + §Permissions & Security (lines 175-176) + §Apex & Automation (lines 182, 191-193) + §Migration Reference + scripts/migration/. -->

# Salesforce Data Operations Expert (sf-data) (Brite edition)

Use this skill when the user needs **Salesforce data work**: record CRUD, bulk import/export, test data generation, cleanup scripts, or data factory patterns for validating Apex, Flow, or integration behavior.

## Brite Context

- **HubSpot migration is complete** (Phase 1 2026-03-20, Phase 2 2026-03-24) — see Rule 1 for ETL layout.
- **HubSpot emails surface as Task, not EmailMessage** — see Rule 2 (loads) and Rule 3 (`setSaveAsActivity` outbound).
- **Bulk API has session-permset and audit-field gotchas** — see Rules 4 and 5.
- **Task re-parenting follows `WhatId`, not Contact** — see Rule 7.

**See also:** [sf-soql](../sf-soql/SKILL.md) for query-only work (no record mutations); [sf-integration](../sf-integration/SKILL.md) for the Email Bison → OutboundSync handshake that produces Tasks; [sf-permissions](../sf-permissions/SKILL.md) for the 7-permset FLS sync discipline.

## Brite Data Discipline

### 1. HubSpot migration architecture

ETL scripts in `brite-salesforce/scripts/migration/` are layered: `extract/` (HubSpot pull), `transform/` (Brite mapping), `load/` (SF push), `validate/` (post-load reconciliation), `fix/` (drift remediation), `coverage/` (Jest mapping coverage). When asked "load 5000 records into Salesforce" or "fix migration drift," reference these scripts as the starting point — do not author one-off load scripts.

### 2. HubSpot emails migrate as Task, not EmailMessage

HubSpot email engagements load as `Task` records with `Type: "Email"`. EmailMessage requires `hs_email_from`, `hs_email_to`, and `EmailMessageRelation` junction records — Salesforce only renders native email icons/threading for that object. The migration's Task-shape choice is intentional. Source: §Metadata Authoring line 143.

### 3. `Messaging.SingleEmailMessage` + `setSaveAsActivity(false)` → no EmailMessage record AND no Task activity

Outbound emails sent this way leave zero rows in both objects. The ONLY monitoring path is Setup → Email Logs (24-hour rolling window). Do not instruct triagers to "check the EmailMessage object" — they'll find nothing and assume the notification silently failed. `NewsletterSignupNotificationService` is the current example. See `docs/artifacts/email-notification-matrix.md`. Source: §Metadata Authoring line 144.

### 4. Bulk API does not honor session-based permsets

`HubSpot_Migration` permset has `hasActivationRequired:true` — activation only happens per UI session via `SessionPermissionSetActivation`, NOT in Bulk API or `sf` CLI sessions. For data loads that need the bypass, verify with `FeatureManagement.checkPermission()` first; workarounds: (a) `sf data create record` (single REST call), (b) patch the data, (c) temporarily flip `hasActivationRequired:false`. Source: §Permissions & Security line 175.

### 5. `CreateAuditFields` is INSERT-only

API name is **capitalized** (`createAuditFields` is rejected at deploy time with "Unknown user permission"). Records inserted without the permission must be DELETED and re-inserted to set `CreatedDate` — upsert takes the UPDATE path for existing records and silently leaves `CreatedDate` unchanged. Requires the org-level **"Set Audit Fields upon Record Creation"** toggle enabled in Setup → User Interface. Verified during BC-2744. Source: §Permissions & Security line 176.

### 6. Bulk API empty CSV cells = "skip", not "set null"; use `#N/A` for null

Leaving a field empty in `sf data update bulk` CSVs causes Bulk API v1 to NOT UPDATE that field. To actually null out a field via bulk update, the cell must be literally `#N/A`. Common trap when writing migration/cleanup scripts that need to null foreign keys (`WhatId`, `AccountId`, `OwnerId`). Verified during drift audit 2026-04-24. Source: §Apex & Automation line 193.

### 7. `Task.AccountId` follows `Task.WhatId`, not `Contact.AccountId`

Task.AccountId is set at creation from `WhatId` (or derived from the `WhoId` Contact's AccountId at that moment) and **does not cascade** when the related Contact's AccountId later changes. To re-parent Tasks, explicitly `UPDATE Task SET WhatId = :newAccountId` — `WhatId` is polymorphic and Account is a valid target. Setting `WhatId = null` ALSO nulls AccountId, orphaning the task. Verified during BC-5545 contact re-parenting. Source: §Apex & Automation lines 191-192.

### 8. Salesforce seed sample data may carry real correspondence

Orgs provisioned with default sample data (`Acme (Sample)`, `salesforce.com (Sample)`, `Global Media (Sample)`) can accumulate real emails via HubSpot / Email Bison domain matching. Before deleting seed Accounts, ALWAYS check: `SELECT COUNT() FROM Task WHERE Account.Name = '...' AND Subject LIKE 'Email:%'`. Preserve by re-parenting Tasks (`UPDATE Task SET WhatId = [AccountId]`) and EmailMessages (`UPDATE EmailMessage SET RelatedToId = [AccountId]`) before the cascade. Verified during drift audit 2026-04-24: `salesforce.com (Sample)` had 58 real Slack/FSL emails mixed with 2 seed tasks. Source: §Metadata Authoring line 130.

## When This Skill Owns the Task

Use `sf-data` when the work involves:
- `sf data` CLI commands
- record creation, update, delete, upsert, export, or tree import/export
- realistic test data generation
- bulk data operations and cleanup
- Apex anonymous scripts for data seeding / rollback

Delegate elsewhere when the user is:
- writing SOQL only → [sf-soql](../sf-soql/SKILL.md)
- running or repairing Apex tests → [sf-testing](../sf-testing/SKILL.md)
- deploying metadata first → [sf-deploy](../sf-deploy/SKILL.md)
- discovering schema / field definitions → [sf-metadata](../sf-metadata/SKILL.md)

---

## Important Mode Decision

Confirm which mode the user wants:

| Mode | Use when |
|---|---|
| Script generation | they want reusable `.apex`, CSV, or JSON assets without touching an org yet |
| Remote execution | they want records created / changed in a real org now |

Do not assume remote execution if the user may only want scripts.

---

## Required Context to Gather First

Ask for or infer:
- target object(s)
- org alias, if remote execution is required
- operation type: query, create, update, delete, upsert, import, export, cleanup
- expected volume
- whether this is test data, migration data, or one-off troubleshooting data
- any parent-child relationships that must exist first

---

## Core Operating Rules

- `sf-data` acts on **remote org data** unless the user explicitly wants local script generation.
- Objects and fields must already exist before data creation.
- For automation testing, prefer **251+ records** when bulk behavior matters.
- Always think about cleanup before creating large or noisy datasets.
- Never use real PII in generated test data.
- Prefer **CLI-first** for straightforward CRUD; use anonymous Apex when the operation truly needs server-side orchestration.

If metadata is missing, stop and hand off to:
- [sf-metadata](../sf-metadata/SKILL.md) or [sf-deploy](../sf-deploy/SKILL.md)

---

## Recommended Workflow

### 1. Verify prerequisites
Confirm object / field availability, org auth, and required parent records.

### 2. Run describe-first pre-flight validation when schema is uncertain
Before creating or updating records, use object describe data to validate:
- required fields
- createable vs non-createable fields
- picklist values
- relationship fields and parent requirements

Example pattern:
```bash
sf sobject describe --sobject ObjectName --target-org <alias> --json
```

Helpful filters:
```bash
# Required + createable fields
jq '.result.fields[] | select(.nillable==false and .createable==true) | {name, type}'

# Valid picklist values for one field
jq '.result.fields[] | select(.name=="StageName") | .picklistValues[].value'

# Fields that cannot be set on create
jq '.result.fields[] | select(.createable==false) | .name'
```

### 3. Choose the smallest correct mechanism
| Need | Default approach |
|---|---|
| small one-off CRUD | `sf data` single-record commands |
| large import/export | Bulk API 2.0 via `sf data ... bulk` |
| parent-child seed set | tree import/export |
| reusable test dataset | factory / anonymous Apex script |
| reversible experiment | cleanup script or savepoint-based approach |

### 4. Execute or generate assets
Use the built-in templates under `assets/` when they fit:
- `assets/factories/`
- `assets/bulk/`
- `assets/cleanup/`
- `assets/soql/`
- `assets/csv/`
- `assets/json/`

### 5. Verify results
Check counts, relationships, and record IDs after creation or update.

### 6. Apply a bounded retry strategy
If creation fails:
1. try the primary CLI shape once
2. retry once with corrected parameters
3. re-run describe / validate assumptions
4. pivot to a different mechanism or provide a manual workaround

Do **not** repeat the same failing command indefinitely.

### 7. Leave cleanup guidance
Provide exact cleanup commands or rollback assets whenever data was created.

---

## High-Signal Rules

### Bulk safety
- use bulk operations for large volumes
- test automation-sensitive behavior with 251+ records where appropriate
- avoid one-record-at-a-time patterns for bulk scenarios

### Data integrity
- include required fields
- validate picklist values before creation
- verify parent IDs and relationship integrity
- account for validation rules and duplicate constraints
- exclude non-createable fields from input payloads

### Cleanup discipline
Prefer one of:
- delete-by-ID
- delete-by-pattern
- delete-by-created-date window
- rollback / savepoint patterns for script-based test runs

---

## Common Failure Patterns

| Error | Likely cause | Default fix direction |
|---|---|---|
| `INVALID_FIELD` | wrong field API name or FLS issue | verify schema and access |
| `REQUIRED_FIELD_MISSING` | mandatory field omitted | include required values from describe data |
| `INVALID_CROSS_REFERENCE_KEY` | bad parent ID | create / verify parent first |
| `FIELD_CUSTOM_VALIDATION_EXCEPTION` | validation rule blocked the record | use valid test data or adjust setup |
| invalid picklist value | guessed value instead of describe-backed value | inspect picklist values first |
| non-writeable field error | field is not createable / updateable | remove it from the payload |
| bulk limits / timeouts | wrong tool for the volume | switch to bulk / staged import |

---

## Output Format

When finishing, report in this order:
1. **Operation performed**
2. **Objects and counts**
3. **Target org or local artifact path**
4. **Record IDs / output files**
5. **Verification result**
6. **Cleanup instructions**

Suggested shape:

```text
Data operation: <create / update / delete / export / seed>
Objects: <object + counts>
Target: <org alias or local path>
Artifacts: <record ids / csv / apex / json files>
Verification: <passed / partial / failed>
Cleanup: <exact delete or rollback guidance>
```

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| discover object / field structure | [sf-metadata](../sf-metadata/SKILL.md) | accurate schema grounding |
| run bulk-sensitive Apex validation | [sf-testing](../sf-testing/SKILL.md) | test execution and coverage |
| deploy missing schema first | [sf-deploy](../sf-deploy/SKILL.md) | metadata readiness |
| implement production logic consuming the data | [sf-apex](../sf-apex/SKILL.md) or [sf-flow](../sf-flow/SKILL.md) | behavior implementation |

---

## Reference Map

### Start here
- [references/sf-cli-data-commands.md](references/sf-cli-data-commands.md)
- [references/test-data-best-practices.md](references/test-data-best-practices.md)
- [references/orchestration.md](references/orchestration.md)
- [references/test-data-patterns.md](references/test-data-patterns.md)
- [references/test-data-factory-usage.md](references/test-data-factory-usage.md)

### Query / bulk / cleanup
- [references/soql-relationship-guide.md](references/soql-relationship-guide.md)
- [references/relationship-query-examples.md](references/relationship-query-examples.md)
- [references/bulk-operations-guide.md](references/bulk-operations-guide.md)
- [references/cleanup-rollback-guide.md](references/cleanup-rollback-guide.md)
- [references/cleanup-rollback-example.md](references/cleanup-rollback-example.md)

### Examples / limits
- [references/crud-workflow-example.md](references/crud-workflow-example.md)
- [references/bulk-testing-example.md](references/bulk-testing-example.md)
- [references/anonymous-apex-guide.md](references/anonymous-apex-guide.md)
- [references/governor-limits-reference.md](references/governor-limits-reference.md)
- [assets/](assets/)

---

## Score Guide

| Score | Meaning |
|---|---|
| 117+ | strong production-safe data workflow |
| 104–116 | good operation with minor improvements possible |
| 91–103 | acceptable but review advised |
| 78–90 | partial / risky patterns present |
| < 78 | blocked until corrected |
