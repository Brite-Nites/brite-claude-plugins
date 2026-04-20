---
name: sf-soql
description: SOQL query generation, optimization, and analysis with 100-point scoring. TRIGGER when: user writes, optimizes, or debugs SOQL/SOSL queries, touches .soql files, asks about relationship queries, aggregates, query performance, or Brite-specific patterns (Territory__c scope, cross-env User lookup via Email, Task polymorphic Who/What, Lifecycle_Stage__c filters, Opportunity RT-prefix scoping by business line). DO NOT TRIGGER when: bulk data operations (use sf-data), Apex DML logic (use sf-apex), or report/dashboard queries.
user-invocable: false
license: MIT
metadata:
  version: "1.1.0-brite.1"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "100 points across 5 categories"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Business Context + §Apex & Automation. -->

# sf-soql: Salesforce SOQL Query Expert

Use this skill when the user needs **SOQL/SOSL authoring or optimization**: natural-language-to-query generation, relationship queries, aggregates, query-plan analysis, and performance/safety improvements for Salesforce queries.

## Brite Context

Brite's object model wraps a standard Salesforce core (Account, Contact, Lead, Opportunity, Campaign, Activity) with five custom extensions that drive nearly every non-trivial query: `Territory__c`, `Location` (FSL standard), `Lifecycle_Stage_History__c`, `AccountContactRelation`, `In_App_Checklist_Settings__c`. Know the four business lines (Rule 3), the FSL/Territory distinction (Rules 4-5), and the automation-written audit table (Rule 6) before writing any pipeline or attribution SOQL.

Authoritative landmarks:
- `brite-salesforce/force-app/main/default/objects/` — canonical schema
- `brite-salesforce/CLAUDE.md` §Business Context + §Apex & Automation — behavioral gotchas
- `brite-salesforce/docs/artifacts/data-dictionary.md` — authoritative field reference

SOQL-specific gotchas (Rules 7-16) trace to verified incidents: BC-5021 (before-update cascade), BC-5545 (Task re-parenting, in-flight), BC-5609 (cross-env User + sharing).

**See also:** [sf-apex](../sf-apex/SKILL.md) for DML context · [sf-data](../sf-data/SKILL.md) for execution · [sf-permissions](../sf-permissions/SKILL.md) for FLS-aware queries · [sf-metadata](../sf-metadata/SKILL.md) for field-shape authoring.

## Brite SOQL Conventions

18 rules grounded in `brite-salesforce/CLAUDE.md`. Each rule cites a specific source line (verified via `gh api` 2026-04-20).

### Theme A — Source + API context

1. **API version 65.0** — queries inherit `sourceApiVersion` from `sfdx-project.json`. Bump via BC-issued follow-up when brite-salesforce moves to v66.0. _(§Engineering Standards line 40)_
2. **Tooling API via `useToolingApi: true`** — the same `run_soql_query` MCP tool switches to Tooling API for `CustomField`, `ApexClass.Body`, and `Flow` status verification. Canonical prod-deploy verification: `SELECT Status FROM Flow WHERE Definition.DeveloperName = 'Flow_Name'`. _(§Apex & Automation lines 186-187)_

### Theme B — Brite object model

3. **Four business lines → Opportunity RT name prefixes**: `Brite_Nites_*` (residential), `Brite_Labs_*` (commercial), `Brite_Supply_*` (ecommerce/B2B + Brite Base), `Acquisition` (M&A). Scope pipeline queries with `RecordType.DeveloperName LIKE 'Brite_Nites_%'` rather than hand-listing RT IDs. _(§Business Context lines 213-216)_
4. **`Location` (standard FSL)** separates "who" (Account) from "where" (service address). Join via the `AssociatedLocation` junction (many-to-many), NOT a direct `Account.Location__c` lookup. _(§Business Context line 220)_
5. **`Territory__c` is custom, NOT Enterprise Territory Management.** Simple custom object for 12-15 territories. Look up via `Account.Territory__c` / `Lead.Territory__c` — do not query `UserTerritory2Association` / `Territory2`. _(§Business Context line 221)_
6. **`Lifecycle_Stage_History__c` is an automation-written audit trail** — read-only for SOQL purposes; never `INSERT`/`UPDATE` directly. Driven by `Lifecycle_Stage__c` transitions (see Rule 16). _(§Metadata Authoring line 168 + issue body)_

### Theme C — Task & polymorphic relationship gotchas

7. **SOQL semi-join from other objects to Task is not supported.** `Contact WHERE Id IN (SELECT WhoId FROM Task ...)` fails with `Entity 'Task' is not supported for semi join inner selects`. Use two queries: pull `WhoId`s from Task first, then filter Contact by Id. _(§Apex & Automation line 189)_
8. **Polymorphic `Who`/`What` relationships don't support dot-walking.** `SELECT Who.AccountId FROM Task` fails because `Who` is the polymorphic `Name` entity. Use `TYPEOF Who WHEN Contact THEN AccountId END` or a separate query by `WhoId`. _(§Apex & Automation line 190)_
9. **`Task.AccountId` does NOT cascade when `Contact.AccountId` changes.** It's set at creation from `WhatId` (or derived from the `WhoId` Contact's AccountId at that moment). To re-parent: `UPDATE Task SET WhatId = :newAccountId` — `AccountId` follows `WhatId`. _(§Apex & Automation line 188, verified during BC-5545 contact re-parenting)_
10. **Activity-object field authoring** — custom fields on Task/Event live in `objects/Activity/fields/`, but SOQL filter references still use `Task.Custom_Field__c` / `Event.Custom_Field__c`, NOT `Activity.Custom_Field__c`. _(§Metadata Authoring line 122)_

### Theme D — User object cross-env + sharing

11. **Cross-env `User` lookup: query by `Email`, NOT `Username`.** Sandbox refreshes append `.sandbox` / `.full` / `.preview` to every `User.Username`; `User.Email` is NOT rewritten on refresh. Always pair with `IsActive = TRUE` and `LIMIT 1` (Email is not unique). For scratch-org CI, combine with a `@TestVisible` override field set to `UserInfo.getUserId()` so the empty-query doesn't NPE. Pattern: `LeadTriggerHandler.resolveWebFormOwnerId`. _(§Apex & Automation line 194, BC-5609)_
12. **`with sharing` does NOT restrict `User` object queries.** `User` is always org-wide visible to any authenticated Apex context (including Guest and Integration Users). `public with sharing` on a handler that queries `User` is misleading — add a code comment noting the distinction. Only `User` is special; other standard objects respect sharing. _(§Apex & Automation line 196)_

### Theme E — Trigger-context + scheduler SOQL

13. **Before-update triggers querying the same object see pre-update DB state.** When checking "does this Contact have other open Opps?" while closing an Opp, the closing Opp still appears open. Exclude current trigger records: `AND OpportunityId NOT IN :closedLostOpps.keySet()`. _(§Apex & Automation line 183, BC-5021)_
14. **Schedulable DML row limit = 10,000 per transaction.** `DisqualifiedRecycleScheduler` runs 4 queries (DQ Contacts, DQ Leads, Lost Contacts, Lost Leads) each with `LIMIT 2500`. Do not raise individual query limits without switching to Batchable. _(§Apex & Automation line 184)_
15. **`LeadSource` is a WHERE-clause dispatcher, not just a label.** `Web_Form` → `webFormAfterInsertServices` registry; `Newsletter_Signup` → `newsletterAfterInsertServices`. Any SOQL-driven Lead analytics grouping by source must use these exact picklist values. _(§Apex & Automation line 177)_

### Theme F — Lifecycle_Stage picklist semantics

16. **`Lifecycle_Stage__c` filters use restricted-picklist values defined at the RT level.** Each record type carries explicit `picklistValues` blocks even though the GVS defines all values. Query side: use exact case from the GVS. Write side: `Lifecycle_Stage__c` is automation-only — editable only via the `Sales_Operations` permset — so `UPDATE` from arbitrary user context will silently drop the field. _(§Metadata Authoring lines 128 + 168)_

### Theme G — Campaign Influence 2.0

17. **Campaign Influence 2.0 is enabled** in `config/project-scratch-def.json`. Use `SELECT CampaignId, ContactId, Influence FROM CampaignInfluence` for attribution rollups (NOT the legacy `CampaignInfluenceModel`). _(§Metadata Authoring line 158)_

### Theme H — Canonical Brite query patterns

18. **Composite pattern reference:**
    - **Territory scope:** `SELECT Id FROM Lead WHERE Territory__c = :terrId AND IsConverted = FALSE`
    - **Pipeline by business line:** `SELECT Id, Amount FROM Opportunity WHERE RecordType.DeveloperName LIKE 'Brite_Nites_%' AND IsClosed = FALSE`
    - **Task re-parenting (Rule 9):** `UPDATE Task SET WhatId = :acctId WHERE WhoId IN :contactIds`
    - **Cross-env user (Rule 11):** `SELECT Id FROM User WHERE Email = :e AND IsActive = TRUE LIMIT 1`
    _(Issue body + §Business Context)_

---

## When This Skill Owns the Task

Use `sf-soql` when the work involves:
- `.soql` files
- query generation from natural language
- relationship queries and aggregate queries
- query optimization and selectivity analysis
- SOQL/SOSL syntax and governor-aware design

Delegate elsewhere when the user is:
- performing bulk data operations → [sf-data](../sf-data/SKILL.md)
- embedding query logic inside broader Apex implementation → [sf-apex](../sf-apex/SKILL.md)
- debugging via logs rather than query shape → [sf-debug](../sf-debug/SKILL.md)

---

## Required Context to Gather First

Ask for or infer:
- target object(s)
- fields needed
- filter criteria
- sort / limit requirements
- whether the query is for display, automation, reporting-like analysis, or Apex usage
- whether performance / selectivity is already a concern

---

## Recommended Workflow

### 1. Generate the simplest correct query
Prefer:
- only needed fields
- clear WHERE criteria
- reasonable LIMIT when appropriate
- relationship depth only as deep as necessary

### 2. Choose the right query shape
| Need | Default pattern |
|---|---|
| parent data from child | child-to-parent traversal |
| child rows from parent | subquery |
| counts / rollups | aggregate query |
| records with / without related rows | semi-join / anti-join |
| text search across objects | SOSL |

### 3. Optimize for selectivity and safety
Check:
- indexed / selective filters
- no unnecessary fields
- no avoidable wildcard or scan-heavy patterns
- security enforcement expectations

### 4. Validate execution path if needed
If the user wants runtime verification, hand off execution to:
- [sf-data](../sf-data/SKILL.md)

---

## High-Signal Rules

- never use `SELECT *` style thinking; query only required fields
- do not query inside loops in Apex contexts
- prefer filtering in SOQL rather than post-filtering in Apex
- use aggregates for counts and grouped summaries instead of loading unnecessary records
- evaluate wildcard usage carefully; leading wildcards often defeat indexes
- account for security mode / field access requirements when queries move into Apex

---

## Output Format

When finishing, report in this order:
1. **Query purpose**
2. **Final SOQL/SOSL**
3. **Why this shape was chosen**
4. **Optimization or security notes**
5. **Execution suggestion if needed**

Suggested shape:

```text
Query goal: <summary>
Query: <soql or sosl>
Design: <relationship / aggregate / filter choices>
Notes: <selectivity, limits, security, governor awareness>
Next step: <run in sf-data or embed in Apex>
```

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| run the query against an org | [sf-data](../sf-data/SKILL.md) | execution and export |
| embed the query in services/selectors | [sf-apex](../sf-apex/SKILL.md) | implementation context |
| analyze slow-query symptoms from logs | [sf-debug](../sf-debug/SKILL.md) | runtime evidence |
| wire query-backed UI | [sf-lwc](../sf-lwc/SKILL.md) | frontend integration |

---

## Reference Map

### Start here
- [references/soql-syntax-reference.md](references/soql-syntax-reference.md)
- [references/query-optimization.md](references/query-optimization.md)
- [references/cli-commands.md](references/cli-commands.md)

### Specialized guidance
- [references/soql-reference.md](references/soql-reference.md)
- [references/anti-patterns.md](references/anti-patterns.md)
- [references/selector-patterns.md](references/selector-patterns.md)
- [references/field-coverage-rules.md](references/field-coverage-rules.md)
- [assets/](assets/)

---

## Score Guide

| Score | Meaning |
|---|---|
| 90+ | production-optimized query |
| 80–89 | good query with minor improvements possible |
| 70–79 | functional but performance concerns remain |
| < 70 | needs revision before production use |
