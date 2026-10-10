---
name: sf-deploy
description: Salesforce deploy orchestration for Brite's brite-salesforce repo. TRIGGER when a user needs a per-dev preview, an integration PR, the CI production dispatcher, lane-owned post-deploy verification, ticket-scoped destruction, or deploy-failure diagnosis. DO NOT TRIGGER for Apex/LWC authoring (use sf-apex/sf-lwc), metadata creation (use sf-metadata), or org data work (use sf-data).
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

> **Brite entry points**: use [`/revops:preview-changes`](../../commands/preview-changes.md) for the developer's own org and [`/revops:push-to-production`](../../commands/push-to-production.md) for production via CI. See [Orchestration Commands](#orchestration-commands-recommended-path-for-brite-salesforce) for every lane, including documented break glass.

---

## Brite Context

The `brite-salesforce` repo is the **source of truth** for the Salesforce org. All configuration flows repo → org via `sf project deploy start`; never use Setup UI as an alternate metadata editor. The only guided UI exceptions are the exact post-deploy steps named by `/revops:run-manual-post-deploy-steps`; none authorizes production Flow activation outside CI's selected `plan|canary|apply` stage.

- **Source format:** SFDX (not MDAPI). Metadata lives under `force-app/main/default/`.
- **API version:** 65.0 (pinned in `sfdx-project.json`).
- **Automation:** Apex-first. Flows used only for screen flows and simple notifications.
- **CLI:** `sf` v2 only. Legacy `sfdx` is deprecated.
- **Laptop target:** only an explicit `brite-dev-<name>` alias. Shared and production orgs move through CI.

Canonical entry points:

```text
/revops:preview-changes --target-org brite-dev-<name>
/revops:submit-changes-to-integration
/revops:push-to-production --activation plan|canary|apply
/revops:run-manual-post-deploy-steps --production
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

```text
/revops:preview-changes --target-org brite-dev-<name>
```

The command owns the branch boundary, target classification, deletion tripwire,
concurrency probe, dry-run, and same-scope deploy. If a component fails, fix source and
re-run the command.

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
- **OAuth settings (`ExtlClntAppOauthSettings`) carry org-scoped state.** The shared pre-flight classifies them, and the reviewed CI lane owns any approved production handling. Keep the repository `.forceignore` intact locally.
- **Do not use JWT Bearer Flow + ECA + scratch org.** `sf org create scratch` rejects JWT-ECA sessions with `INVALID_INPUT: The callback URL provided is not valid` — see `forcedotcom/cli#3025`, `#3482`. Brite CI uses `SFDX_AUTH_URL` via the built-in `PlatformCLI` Connected App instead. Full context in brite-salesforce/`docs/plans/bc-5400-research.md`.
- Brite currently has 4 active ECAs: `Marketing_Claude_MCP`, `Outbound_Sales_Ops`, `CI_Deploy`, `OutboundSync`.

See brite-salesforce/CLAUDE.md §External Client Apps and brite-salesforce/`docs/gotchas.md` for the full reference.

---

## Required Context to Gather First

Resolve these before choosing a command:

- repository and current branch
- lane: per-dev preview, integration PR, production CI, or documented break glass
- a `brite-dev-<name>` alias for the per-dev lane; never infer a shared or production alias
- requested activation scope (`plan`, `canary`, or `apply`) for production
- whether the diff contains deletions, Flow changes, Named Credentials, or other `.forceignore`-classified metadata

Then enter the matching orchestrator below. Each orchestrator owns its own current-state and authentication preflight; do not reproduce it with a generic CLI recipe.

---

## Recommended Workflow

1. **Per-dev:** run `/revops:preview-changes --target-org brite-dev-<name>`. Completion is a clean dry-run, scoped deploy, targeted tests, and manual UI verification in that dev org.
2. **Integration:** run `/revops:submit-changes-to-integration`. Completion is a reviewed PR whose required checks are current; merging is a human action and CI owns `briteint`.
3. **Production:** after the Kells-gated integration → main promotion, run `/revops:push-to-production --activation plan|canary|apply`. Completion is the exact Actions receipt showing deploy, activation policy, six-type verification, and final summary in order.
4. **Manual remainder:** run `/revops:run-manual-post-deploy-steps --production`. It owns only the steps CI cannot automate; it never widens the selected Flow activation scope.
5. **Deletion:** stop the normal path and use `manifest/destructive/BC-<ticket>.xml` plus the dispatch-only destructive ceremony.

Summarize the lane, exact receipt, selected activation scope, verification result, and next human gate.

Output template: [references/deployment-report-template.md](references/deployment-report-template.md)

---

## Orchestration Commands (recommended path for brite-salesforce)

Route every deploy from the **brite-salesforce** repo through these orchestration commands. They bind the branch, target, scope, dry-run, tests, verification, and human gates into one reviewable flow.

- [`/revops:preview-changes`](../../commands/preview-changes.md) — inner-loop deploy: pre-flight, blocking concurrency probe, dry-run, deploy, Apex tests, manual browser verification. Targets your own `brite-dev-<name>` org. Use after metadata changes are review-clean and before submitting to integration.
- [`/revops:submit-changes-to-integration`](../../commands/submit-changes-to-integration.md) — opens the PR into `integration`. CI deploys to `brite-integration` on merge; you never deploy there yourself.
- [`/revops:push-to-production`](../../commands/push-to-production.md) — production ship: pre-flight (cwd + branch + in-sync + clean tree + blocking concurrency probe + `.forceignore` + intent), double-confirmation gate, then it **dispatches and watches CI**. The deploy, the coverage gate, and post-deploy verification run in CI, not on your laptop. Use after the change has been through integration and merged to `main`.
- [`/revops:emergency-deploy-to-production`](../../commands/emergency-deploy-to-production.md) — last resort, only when the CI lane itself is down. Requires a reason plus durable acknowledgement from the other production admin, keeps every guard, enforces coverage, and F2-verifies after quick-deploy.
- [`/revops:run-manual-post-deploy-steps`](../../commands/run-manual-post-deploy-steps.md) — post-deploy manual steps. After the inner loop, use `--target-org brite-dev-<name> --deploy-id <exact-0Af-id>` so any dev Flow cleanup binds to the completed deploy receipt; use `--production` after the normal CI lane or `--production-breakglass` after the emergency lane. Normal production Flow activation remains owned by CI; break glass leaves it blocked for a separate release-manager decision.

The ordinary laptop lane is `/revops:preview-changes` with an explicit per-dev alias.
Scratch validation belongs to CI, shared-org movement belongs to CI, and the only local
production path is the separately gated emergency command.

---

## High-Signal Failure Patterns

| Error / symptom | Likely cause | Default fix direction |
|---|---|---|
| `FIELD_CUSTOM_VALIDATION_EXCEPTION` | validation rule or bad test data | adjust data or rule timing; check `Bypass_Validation_Rules` custom permission |
| `INVALID_CROSS_REFERENCE_KEY` | missing dependency | deploy referenced metadata first |
| `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` | trigger / Flow / validation side effect | inspect the automation stack |
| tests fail during deploy | broken code or fragile tests | run targeted tests, fix root cause, revalidate |
| field/object not found in permset | wrong order | deploy objects/fields before permission sets |
| Flow invalid / version conflict | dependency or activation problem | in a per-dev org, deploy as Draft, verify, then use the explicit dev activation gate; production stays in CI's selected `plan|canary|apply` scope |
| 1-original + N silent "Completed" Queueable retries in Apex Jobs | callout failure inside self-chaining Queueable | check Named Credential URL first (common regression after deploy) |
| Screen Flow shows Draft in a dev org | deploys as Draft regardless of source | use the explicit-target dev post-deploy runbook |
| Flow remains Draft in production | selected CI activation scope did not include it or policy blocked it | read the exact Actions receipt; make a new release-manager decision rather than activating manually |
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
Lane / target: <per-dev alias | integration CI | production CI>
Scope: <source-dir / metadata / manifest>
Result: <passed / failed / partial>
Activation scope: <dev-only manual | plan | canary | apply | not applicable>
Post-deploy manual steps: <NC URL / Scheduled Apex / UI cache / not applicable>
CI verification receipt: <run URL | pending | not applicable>
Next step: <safe follow-up action>
```
