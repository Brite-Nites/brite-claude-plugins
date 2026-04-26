---
name: sf-flow
description: Creates and validates Salesforce Flows (Brite edition) with 110-point scoring. TRIGGER when user builds or edits record-triggered, screen, autolaunched, or scheduled flows, touches .flow-meta.xml files, works in brite-salesforce, asks about the Apex-first flow policy (Flows only for screen flows + simple notifications), the Screen-Flow-deploy-as-Draft trap (regardless of source `<status>Active</status>`), `sf data update record` failing to activate flows, post-deploy Tooling API verification (`SELECT Status FROM Flow WHERE Definition.DeveloperName = '...'`), scratch-org flow activation gaps, or `/revops:post-deploy-runbook` Phase 2 cross-reference. DO NOT TRIGGER when Apex automation (use sf-apex), process builder migration questions only, or non-Flow declarative config (use sf-metadata).
user-invocable: false
license: MIT
metadata:
  version: "2.1.0-brite.1"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "110 points across 6 categories"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Engineering Standards (line 41, Apex-first flow policy) + §Apex & Automation (line 189, Screen-Flow-deploy-as-Draft trap). -->

# sf-flow: Salesforce Flow Creation and Validation (Brite edition)

Use this skill when the user needs **Flow design or Flow XML work**: record-triggered, screen, autolaunched, scheduled, or platform-event Flows, including validation, architecture choices, and safe deployment sequencing.

## Brite Context

Brite's flow stance:

- **Apex-first by policy.** Brite uses Flows only for (a) Screen Flows (user-facing UI) and (b) simple notifications where Apex would be overkill. Never auto-launched flows for business logic. Source: `brite-salesforce/CLAUDE.md` §Engineering Standards line 41.
- **Screen Flows deploy as Draft regardless of source `<status>Active</status>`.** `sf data update record` cannot activate flows (fails serializing the complex `Metadata` field). Activation is a manual Setup-UI step that ships in `/revops:post-deploy-runbook` Phase 2.
- **Post-deploy verification is non-optional.** After every deploy that includes flows, verify via Tooling API SOQL: `SELECT Status FROM Flow WHERE Definition.DeveloperName = '<Flow_Name>'`. Deploy `Status: Succeeded` is necessary but not sufficient.
- **Scratch orgs share the Draft trap.** Same activation gap applies to scratch-org CI runs after a deploy preprocess.

**See also:** [sf-apex](../sf-apex/SKILL.md) for the Apex-first automation patterns (trigger handler dispatch, Queueable design); [sf-deploy](../sf-deploy/SKILL.md) for safe deployment sequencing; [sf-lwc](../sf-lwc/SKILL.md) when a flow embeds an LWC for richer UI; `/revops:post-deploy-runbook` for the post-deploy activation walk-through.

## Brite Flow Policy

These rules are non-negotiable on `brite-salesforce` and must surface during flow design, deploy, and post-deploy verification.

### 1. Flow policy — Apex-first; Flows only for screen flows + simple notifications

Auto-launched flows for business logic are out — use Apex. Record-triggered flows for trivial branching only. Source: §Engineering Standards line 41.

### 2. Screen Flows deploy as Draft

Even when source XML specifies `<status>Active</status>`, newly-deployed screen flows land in Draft in the target org. Activate via Setup → Flows → find the flow → click Activate on the version row. Verified during BC-5021 prod deploy (2026-04-16).

### 3. `sf data update record` cannot activate flows

It fails serializing the complex `Metadata` field on the Flow object. Use Setup UI; do not script the activation.

### 4. Post-deploy SOQL verification — Tooling API

After a flow deploy:

```sql
SELECT Status FROM Flow WHERE Definition.DeveloperName = '<Flow_Name>'
```

Confirm `Status = 'Active'` before treating the deploy as landed.

### 5. Scratch org applicability

The Draft trap applies to scratch orgs too; CI deploys that run flows must include the activation step (or skip flow-dependent assertions).

### 6. Some Screen Flow settings are UI-only

Like the Kanban Group By selection (covered in sf-metadata), some flow runtime configurations live at the Lightning UI layer and aren't deployable. Document any UI-only setup per-org so sandbox refreshes don't lose it.

### 7. `/revops:post-deploy-runbook` cross-reference

Phase 2 of the post-deploy runbook walks through Screen Flow activation, diff-driven (only prompts when the deploy includes new/changed flows). Use it as the canonical post-deploy gate.

## When This Skill Owns the Task

Use `sf-flow` when the work involves:
- `.flow-meta.xml` files
- Flow Builder architecture and XML generation
- record-triggered, screen, scheduled, autolaunched, or platform-event flows
- Flow-specific bulk safety, fault paths, and subflow orchestration

Delegate elsewhere when the user is:
- writing Apex-first automation → [sf-apex](../sf-apex/SKILL.md)
- creating objects / fields first → [sf-metadata](../sf-metadata/SKILL.md)
- deploying metadata → [sf-deploy](../sf-deploy/SKILL.md)
- seeding post-deploy test data → [sf-data](../sf-data/SKILL.md)

---

## Required Context to Gather First

Ask for or infer:
- flow type
- trigger object / entry conditions
- core business goal
- whether this is new, refactor, or repair
- target org alias if deployment or validation is needed
- whether related objects / fields already exist

---

## Recommended Workflow

### 1. Choose the right automation tool
Before building, confirm Flow is the right answer rather than:
- formula field
- validation rule
- roll-up summary
- Apex

### 2. Choose the right Flow type
| Need | Default flow type |
|---|---|
| same-record update before save | before-save record-triggered |
| related-record work / emails / callouts | after-save record-triggered |
| guided UI | screen flow |
| reusable background logic | autolaunched / subflow |
| scheduled processing | scheduled flow |
| event-driven declarative response | platform-event flow |
| AI-evaluated routing (sentiment, intent, tone) | autolaunched with AI Decision element |

### 3. Start from a template
Prefer the provided assets:
- `assets/record-triggered-before-save.xml`
- `assets/record-triggered-after-save.xml`
- `assets/screen-flow-template.xml`
- `assets/autolaunched-flow-template.xml`
- `assets/scheduled-flow-template.xml`
- `assets/platform-event-flow-template.xml`
- `assets/ai-decision-template.xml`
- `assets/subflows/`

### 4. Validate against Flow guardrails
Focus on:
- no DML in loops
- no Get Records inside loops
- proper fault paths
- correct trigger conditions
- safe subflow composition
- AI Decision elements not placed inside loops (credit cost per iteration)
- AI Decision prompts include merge field references for data context

### 5. Hand off deployment and testing
Use:
- [sf-deploy](../sf-deploy/SKILL.md) for deploy / dry-run
- [sf-data](../sf-data/SKILL.md) for high-volume test data

---

## High-Signal Rules

### Flow architecture
- before-save for same-record field updates
- after-save for related records, emails, and callouts
- do not loop over `$Record`
- use subflows when logic becomes wide or repetitive

### Bulk safety
- no DML in loops
- no Get Records in loops
- test with **251+ records** when bulk behavior matters
- prefer Transform when the job is shaping data, not per-record branching

### Error handling
- every data-changing path should have fault handling
- avoid self-referencing fault connectors
- deploy Flows as Draft first when activation risk is non-trivial

---

## Output Format

When finishing, report in this order:
1. **Flow type and goal**
2. **Files created or updated**
3. **Architecture choices**
4. **Bulk/error-handling notes**
5. **Deploy/testing next steps**

Suggested shape:

```text
Flow: <name>
Type: <flow type>
Files: <paths>
Design: <trigger choice, subflows, key decisions>
Risks: <bulk safety, fault paths, dependencies>
Next step: <dry-run deploy, activate, or test>
```

---

## Flow Testing (CLI)

Run Flow tests from the command line without VS Code:

```bash
# Run all flow tests
sf flow run test --target-org <alias> --json

# Run tests for a specific flow
sf flow run test --class-names MyFlow --target-org <alias> --json

# Get results for an asynchronous run
sf flow get test --test-run-id <id> --target-org <alias> --json
```

Flow tests execute in the org and can take 1-5 minutes. `sf flow run test` returns a test run ID for asynchronous runs; use `sf flow get test` to retrieve results later. Always run with `--json` and use background execution for longer runs.

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| create objects / fields first | [sf-metadata](../sf-metadata/SKILL.md) | schema readiness |
| deploy / activate flow | [sf-deploy](../sf-deploy/SKILL.md) | safe deployment sequence |
| create realistic bulk test data | [sf-data](../sf-data/SKILL.md) | post-deploy verification |
| create Apex actions / invocables | [sf-apex](../sf-apex/SKILL.md) | imperative logic |
| embed LWC in a screen flow | [sf-lwc](../sf-lwc/SKILL.md) | custom UI components |
| expose Flow to Agentforce | [sf-ai-agentscript](../sf-ai-agentscript/SKILL.md) | agent action orchestration |

---

## Reference Map

### Start here
- [references/flow-best-practices.md](references/flow-best-practices.md)
- [references/flow-quick-reference.md](references/flow-quick-reference.md)
- [references/orchestration.md](references/orchestration.md)
- [references/testing-guide.md](references/testing-guide.md)

### Design / orchestration
- [references/subflow-library.md](references/subflow-library.md)
- [references/governance-checklist.md](references/governance-checklist.md)
- [references/transform-vs-loop-guide.md](references/transform-vs-loop-guide.md)
- [references/orchestration-guide.md](references/orchestration-guide.md)
- [references/orchestration-parent-child.md](references/orchestration-parent-child.md)
- [references/orchestration-sequential.md](references/orchestration-sequential.md)
- [references/orchestration-conditional.md](references/orchestration-conditional.md)

### AI Decision
- [references/ai-decision-guide.md](references/ai-decision-guide.md)

### Screen / integration / troubleshooting
- [references/form-building-guide.md](references/form-building-guide.md)
- [references/integration-patterns.md](references/integration-patterns.md)
- [references/lwc-integration-guide.md](references/lwc-integration-guide.md)
- [references/agentforce-flow-integration.md](references/agentforce-flow-integration.md)
- [references/xml-gotchas.md](references/xml-gotchas.md)
- [references/testing-checklist.md](references/testing-checklist.md)
- [references/wait-patterns.md](references/wait-patterns.md)
- [assets/](assets/)

---

## Score Guide

| Score | Meaning |
|---|---|
| 88+ | production-ready Flow |
| 75–87 | good Flow with some review items |
| 60–74 | functional but needs stronger guardrails |
| < 60 | unsafe / incomplete for deployment |
