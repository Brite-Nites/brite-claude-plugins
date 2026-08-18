---
name: sf-deploy
description: Salesforce deploy orchestration for Brite's brite-salesforce repo. TRIGGER when user deploys SFDX metadata to sandbox or production, runs `sf project deploy start`, validates with dry-run, needs post-deploy Tooling API SOQL verification, toggles `.forceignore` for ECA/Named Credential/Prompt exclusions, re-activates Screen Flows that deploy as Draft, re-schedules Apex after sandbox refresh, or troubleshoots deploy-time failures. DO NOT TRIGGER when writing Apex/LWC code (use sf-apex/sf-lwc), creating metadata XML (use sf-metadata), or querying org data (use sf-data).
user-invocable: false
license: MIT
metadata:
  version: "2.3.0-brite.1"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md. -->

# sf-deploy: Salesforce Deploy Orchestration (Brite edition)

Deploy orchestration for the **brite-salesforce** repo: per-dev inner-loop validation, CI-owned integration and production deploys, post-deploy verification, `.forceignore` discipline, explicitly scoped Flow activation, Scheduled Apex recovery, Named Credential PLACEHOLDER handling, and the ticket-scoped destructive ceremony.

## When This Skill Owns the Task

Use `sf-deploy` when the work involves:
- `sf project deploy start`, `quick`, `report`, or retrieval workflows in brite-salesforce
- release sequencing across objects, permission sets, Apex, and Flows
- movement through the invariant dev → integration → main → production topology
- post-deploy verification via Tooling API SOQL
- Flow activation scope, Scheduled Apex re-scheduling, Named Credential URL setup

Delegate elsewhere when the user is:
- authoring Apex or LWC code → [sf-apex](../sf-apex/SKILL.md), [sf-lwc](../sf-lwc/SKILL.md)
- creating metadata definitions → [sf-metadata](../sf-metadata/SKILL.md)
- building Flows → [sf-flow](../sf-flow/SKILL.md)
- doing org data operations → [sf-data](../sf-data/SKILL.md)

> **Default recommendation for brite-salesforce deploys**: prefer [`/revops:preview-changes`](../../commands/preview-changes.md) (your own dev org) or [`/revops:push-to-production`](../../commands/push-to-production.md) (production, via CI) over raw `sf project deploy start`. See [Orchestration Commands](#orchestration-commands-recommended-path-for-brite-salesforce) below for the gate sequence and the non-orchestrable-cases fallback.

---

## Brite Context

The `brite-salesforce` repo is the **source of truth** for the Salesforce org. All configuration flows repo → org via `sf project deploy start`; never make changes in Setup UI.

- **Source format:** SFDX (not MDAPI). Metadata lives under `force-app/main/default/`.
- **API version:** 65.0 (pinned in `sfdx-project.json`).
- **Automation:** Apex-first. Flows used only for screen flows and simple notifications.
- **CLI:** `sf` v2 only. Legacy `sfdx` is deprecated.
- **Target org:** always pass `--target-org <alias>` explicitly. Never rely on a default org.

Canonical deploy + test invocations:

```bash
# Validate (dry-run)
sf project deploy start --source-dir force-app --dry-run --target-org <alias>

# Deploy
sf project deploy start --source-dir force-app --target-org <alias>

# Retrieve (WARNING: overwrites local; commit first)
sf project retrieve start --source-dir force-app --target-org <alias>

# Apex tests (cannot run locally)
sf apex run test --target-org <alias> --wait 10
```

Brite-owned org aliases, per [ADR-026](../../../../docs/decisions/026-revops-promotion-topology.md) and the single list in [`config/org-aliases.json`](../../config/org-aliases.json): `brite-dev-<name>` (per-developer, the only laptop-deployable org), `brite-integration` / `briteint` and `brite-uat` (CI-deployed), `brite-prod` / `brite-prod-marketingadmin` (production, CI-deployed), `brite-sandbox` (retiring). A normal command never targets prod from the laptop; it dispatches the reviewed CI workflow.

---

## Critical Operating Rules

- **Always prove before mutating.** `/revops:preview-changes` dry-runs a per-dev deploy; production is validated on the promotion PR and the CI deploy lane retains its own fail-closed checks.
- **Prod deploys require the lane's Apex coverage gate.** Read the Actions receipt; do not substitute a laptop test run.
- **"Succeeded" is necessary, not sufficient.** The prod workflow follows the deploy with the selected activation stage and six-type verification.
- Local deploy commands require an explicit per-dev target and scope: `--source-dir`, `--metadata`, or `--manifest`.
- **Flow activation is a separate behavioral decision.** Production uses explicit `plan|canary|apply`; the manual runbook never widens it.
- **`.forceignore` is a deploy input.** Run the shared pre-flight and let the reviewed CI lane own any approved production handling; never improvise a local prod toggle/deploy.
- Delegate test-data creation to [sf-data](../sf-data/SKILL.md) once metadata is deployed.

### Default deploy order

| Phase | Metadata |
|---|---|
| 1 | Custom objects / fields |
| 2 | Permission sets (FLS requires fields to exist) |
| 3 | Apex classes + triggers |
| 4 | Flows (plan activation separately) |
| 5 | Lane-owned activation decision + verification |

---

## Brite Deploy Discipline

These rules are non-negotiable on the brite-salesforce repo.

### Dry-run-first

```bash
sf project deploy start --source-dir force-app --dry-run --target-org brite-dev-<name> --wait 30 --json
```

Inspect the job report. If a component fails, fix in source and re-validate. Only proceed to actual deploy after a clean dry-run.

### Production coverage and verification

`deploy-prod.yml` is the evidence surface. It runs the production Apex gate, the explicit `plan|canary|apply` Flow stage, and the six-type verifier in order; both activation policy and component verification fail closed, and the summary runs last. Use the exact Actions run returned by `/revops:push-to-production`. Do not issue ad-hoc prod test/query commands as a substitute for that receipt.

### `.forceignore` pre-flight

`.forceignore` contains both sandbox-capability exclusions and permanent production exclusions. The shared pre-flight classifies changed-but-ignored metadata before either the dev or production path continues. Never apply the old blanket "comment it out for prod" recipe: several exclusions are permanent because prod rejects the metadata or the file carries org-issued/secret state. Follow the repository's current `.claude/rules/deploy.md` and let the CI lane perform only its reviewed handling.

---

## Post-Deploy Regressions to Watch For

Deploy succeeded ≠ feature works. These are Brite-specific regressions that silently slip past a `Status: Succeeded`:

- **Flow versions can remain Draft** — in a dev org, the explicit-target manual runbook may guide activation. In production, preserve the CI `plan|canary|apply` decision; do not activate from a generic post-deploy checklist.
- **Scheduled Apex does not survive sandbox refresh** — `CronTrigger` records are copied but don't execute. Re-schedule via Developer Console. Current scheduled jobs: `DisqualifiedRecycleScheduler` (cron `0 0 6 1 1 ?`).
- **Named Credential URLs carry PLACEHOLDER values** — metadata deploys cannot contain real endpoints (secrets don't belong in source). Update manually in Setup → Named Credentials after every deploy that touches a NC. Current NCs requiring post-deploy URL config: `Slack_Webform_Alerts`. Miss this and you get the 1-original + 3-silent-retry signature in Apex Jobs (Queueable callout failure masked by silent retries).
- **Kanban Group By dropdown caches field metadata for hours** — after deploying a picklist field on a standard object, add the field to any page layout for that object and redeploy to flush the UI cache. See brite-salesforce/CLAUDE.md §Metadata Authoring for the full list of UI-cache gotchas.
- **Flexipage IndexedDB cache (hours TTL)** — after flexipage changes, hard refresh doesn't clear. Log out + back in, or run `indexedDB.deleteDatabase("actions")` in Chrome console.

---

## External Client Apps (not Connected Apps)

**Connected App creation is disabled as of Spring '26.** Brite uses External Client Apps (ECAs) with metadata type `ExternalClientApplication` (NOT `ConnectedApp`).

- **ECAs don't propagate between orgs.** Must be created/deployed separately in each org.
- **OAuth settings (`ExtlClntAppOauthSettings`) are excluded from sandbox deploys** via `.forceignore` because `oauthLink` is org-scoped. Comment out the `.forceignore` line when crossing to production; restore before committing.
- **Do not use JWT Bearer Flow + ECA + scratch org.** `sf org create scratch` rejects JWT-ECA sessions with `INVALID_INPUT: The callback URL provided is not valid` — see `forcedotcom/cli#3025`, `#3482`. Brite CI uses `SFDX_AUTH_URL` via the built-in `PlatformCLI` Connected App instead. Full context in brite-salesforce/`docs/plans/bc-5400-research.md`.
- Brite currently has 4 active ECAs: `Marketing_Claude_MCP`, `Outbound_Sales_Ops`, `CI_Deploy`, `OutboundSync`.

See brite-salesforce/CLAUDE.md §External Client Apps and brite-salesforce/`docs/gotchas.md` for the full reference.

---

## Required Context to Gather First

Ask for or infer:
- target org alias (never assume `--target-org`)
- which lane the deploy is in — your own dev org (`brite-dev-<name>`), integration (`brite-integration`), or production (`brite-prod`)
- deploy scope: `--source-dir force-app` (default), `--metadata <list>`, or `--manifest`
- validate-only vs deploy vs quick-deploy vs retrieve
- Apex test level (`NoTestRun` only for non-Apex sandbox deploys; `RunLocalTests` for any prod deploy)
- whether special metadata types are involved (Flow, ECA, Named Credential, Prompt — these need `.forceignore` toggles)

Preflight:

```bash
sf --version
sf org list
sf org display --target-org <alias> --json
test -f sfdx-project.json
```

---

## Recommended Workflow

### 1. Preflight
Confirm `sf` CLI version, auth, and that `sfdx-project.json` is present.

### 2. Validate (dry-run)
```bash
sf project deploy start --dry-run --source-dir force-app --target-org <alias> --wait 30 --json
```
Use manifest- or metadata-scoped validation when the change set is narrow.

### 3. Deploy the smallest correct scope

```bash
# source-dir deploy (canonical Brite pattern)
sf project deploy start --source-dir force-app --target-org <alias> --wait 30 --json

# manifest deploy
sf project deploy start --manifest manifest/package.xml --target-org <alias> --test-level RunLocalTests --wait 30 --json

# quick deploy after a successful validation (skips re-running tests)
sf project deploy quick --job-id <validation-job-id> --target-org <alias> --json
```

### 4. Run Apex tests (any deploy touching Apex)
```bash
sf apex run test --target-org <alias> --wait 10
```
For prod, add `--code-coverage --result-format human` and confirm ≥90% org-wide.

### 5. Manual post-deploy steps
- Activate any Screen Flows via Setup → Flows.
- Update Named Credential URLs if the deploy touched NCs.
- Re-schedule Apex if this was a sandbox refresh.
- Toggle `.forceignore` exclusions back on if they were commented out for this deploy.

### 6. Verify (production)
```bash
sf project deploy report --job-id <job-id> --target-org <alias> --json
```
Then run the Tooling API SOQL verifications above for critical components.

### 7. Report
Summarize what deployed, what was skipped, which post-deploy manual steps ran, and what the next safe action is.

Output template: [references/deployment-report-template.md](references/deployment-report-template.md)

---

## Orchestration Commands (recommended path for brite-salesforce)

For any deploy from the **brite-salesforce** repo, prefer these orchestration commands over raw `sf project deploy start`. They bake the dry-run + Apex tests + Tooling API verification + manual browser checks into a sequenced gate flow; raw CLI skips all of that.

- [`/revops:preview-changes`](../../commands/preview-changes.md) — inner-loop deploy: pre-flight, blocking concurrency probe, dry-run, deploy, Apex tests, manual browser verification. Targets your own `brite-dev-<name>` org. Use after metadata changes are review-clean and before submitting to integration.
- [`/revops:submit-changes-to-integration`](../../commands/submit-changes-to-integration.md) — opens the PR into `integration`. CI deploys to `brite-integration` on merge; you never deploy there yourself.
- [`/revops:push-to-production`](../../commands/push-to-production.md) — production ship: pre-flight (cwd + branch + in-sync + clean tree + blocking concurrency probe + `.forceignore` + intent), double-confirmation gate, then it **dispatches and watches CI**. The deploy, the coverage gate, and post-deploy verification run in CI, not on your laptop. Use after the change has been through integration and merged to `main`.
- [`/revops:emergency-deploy-to-production`](../../commands/emergency-deploy-to-production.md) — last resort, only when the CI lane itself is down. Requires `--reason`, keeps every guard, validates before it quick-deploys.
- [`/revops:run-manual-post-deploy-steps`](../../commands/run-manual-post-deploy-steps.md) — post-deploy manual steps. Use `--target-org brite-dev-<name>` after the inner loop, `--production` after the normal CI lane, or `--production-breakglass` after the emergency lane. Normal production Flow activation remains owned by CI; break glass leaves it blocked for a separate release-manager decision.

Raw `sf project deploy start` is limited to an explicit per-dev org, scratch-org work, or a different repository whose own policy permits it. It is never a fallback to `briteint` or `brite-prod`; normal shared-org movement stays in CI, and the only local prod path is the separately gated emergency command.

---

## High-Signal Failure Patterns

| Error / symptom | Likely cause | Default fix direction |
|---|---|---|
| `FIELD_CUSTOM_VALIDATION_EXCEPTION` | validation rule or bad test data | adjust data or rule timing; check `Bypass_Validation_Rules` custom permission |
| `INVALID_CROSS_REFERENCE_KEY` | missing dependency | deploy referenced metadata first |
| `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` | trigger / Flow / validation side effect | inspect the automation stack |
| tests fail during deploy | broken code or fragile tests | run targeted tests, fix root cause, revalidate |
| field/object not found in permset | wrong order | deploy objects/fields before permission sets |
| Flow invalid / version conflict | dependency or activation problem | deploy as Draft, verify, then activate |
| 1-original + N silent "Completed" Queueable retries in Apex Jobs | callout failure inside self-chaining Queueable | check Named Credential URL first (common regression after deploy) |
| Screen Flow shows Draft in target org | deploys as Draft regardless of source | activate via Setup UI + SOQL-verify |
| `INVALID_INPUT: The callback URL provided is not valid` on `sf org create scratch` | JWT Bearer Flow + ECA incompatibility | use `SFDX_AUTH_URL` via `PlatformCLI` instead |

Full workflows: [references/orchestration.md](references/orchestration.md), [references/trigger-deployment-safety.md](references/trigger-deployment-safety.md)

---

## CI/CD Guidance

Brite's CI uses **scratch-org-per-PR**, not a shared sandbox:
- `.github/workflows/validate-deploy.yml` creates a scratch, preprocesses the working tree via `./scripts/prepare-scratch-deploy.sh`, dry-runs the deploy, destroys the scratch.
- Auth is `SFDX_AUTH_URL_DEVHUB` from the `marketingadmin@britenites.com` shared service user (refresh token under the CLI's `PlatformCLI` Connected App — not JWT, not an ECA).
- ~2.5 min validate + 33s lint.

Full architecture: brite-salesforce/`docs/ci-architecture.md`. Scratch preprocessing: brite-salesforce/`scripts/prepare-scratch-deploy.sh`.

Local dry-runs do not require the preprocess step; CI does because of profile scratch-incompatibility.

Generic CI patterns (apply where relevant): [references/deployment-workflows.md](references/deployment-workflows.md). Static analysis uses **Code Analyzer v5** (`sf code-analyzer`).

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| custom object / field creation | [sf-metadata](../sf-metadata/SKILL.md) | define metadata before deploy |
| Apex compile / review / fixes | [sf-apex](../sf-apex/SKILL.md) | code authoring and repair |
| Flow creation / repair | [sf-flow](../sf-flow/SKILL.md) | Flow authoring and activation guidance |
| test data or seed records | [sf-data](../sf-data/SKILL.md) | describe-first data setup and cleanup |
| permission set changes | [sf-permissions](../sf-permissions/SKILL.md) | FLS sync across 7 perm sets; Lifecycle fields |
| ECA / Named Credential setup | [sf-connected-apps](../sf-connected-apps/SKILL.md), [sf-integration](../sf-integration/SKILL.md) | auth + integration metadata |

---

## Reference Map

### Start here
- [references/orchestration.md](references/orchestration.md) — multi-skill deploy coordination
- [references/deployment-workflows.md](references/deployment-workflows.md) — worked examples (Brite scenarios first, generic second)
- [references/deployment-report-template.md](references/deployment-report-template.md)

### Specialized deployment safety
- [references/trigger-deployment-safety.md](references/trigger-deployment-safety.md)
- [references/deploy.sh](references/deploy.sh)

### Brite source material (cross-repo)
- brite-salesforce/CLAUDE.md §Deploy & Retrieve, §External Client Apps, §Apex & Automation
- brite-salesforce/`docs/gotchas.md`
- brite-salesforce/`docs/ci-architecture.md`
- brite-salesforce/`docs/artifacts/testing-strategy.md`

---

## Score Guide

| Score | Meaning |
|---|---|
| 90+ | strong deploy plan + post-deploy verification + forceignore discipline |
| 75–89 | good deploy guidance with minor review items |
| 60–74 | partial coverage of Brite-specific regressions |
| < 60 | insufficient — likely missing lane-owned verification, explicit Flow-activation scope, or `.forceignore` pre-flight |

---

## Completion Format

```text
Deployment goal: <validate / deploy / retrieve / quick-deploy>
Target org: <alias>
Scope: <source-dir / metadata / manifest>
Result: <passed / failed / partial>
Post-deploy manual steps: <Flow activation / NC URL / Scheduled Apex / forceignore restore>
Tooling API verification: <passed / pending / not applicable>
Next step: <safe follow-up action>
```
