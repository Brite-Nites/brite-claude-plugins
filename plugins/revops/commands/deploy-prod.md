---
description: Production deploy orchestration for brite-salesforce — pre-flight (cwd + branch + clean tree + intent), prod dry-run, double-confirmation gate, actual deploy, coverage check, Tooling API post-deploy verification, runbook trigger. Use after `/revops:deploy-sandbox` has verified cleanly and the PR is merged to `main`. Closes the production-deploy discipline gap that `/workflows:ship` alone doesn't cover.
allowed-tools: Bash, AskUserQuestion
---

# /revops:deploy-prod

Execute the phases below sequentially. Use `AskUserQuestion` at every gate so the user explicitly acknowledges state before any mutating step. If the user answers anything other than the proceed option, halt and surface the blocker — never re-run past phases silently.

**One question at a time.** Never batch gate questions.

Canonical invocation pattern comes from `brite-salesforce/CLAUDE.md` §Development Flow step 4 (Deploy to Production) + §Apex & Automation (Prod deploy verification: always SOQL-verify target components). Production alias is `brite-prod`. Always pass `--target-org brite-prod` explicitly — never rely on a default org. Always use `sf`, never legacy `sfdx`.

Out of scope for this command: sandbox deploy (use `/revops:deploy-sandbox`), manual post-deploy runbook (use `/revops:post-deploy-runbook`), automating browser verification, rollback automation. If deploy fails, user diagnoses manually.

See the **Rules** section at the bottom for the enforcement contract (mutating-phase discipline, `--json` parsing, CLI field verification, etc.).

---

## Phase 1 — Pre-flight

Narrate: `Phase 1/7: Pre-flight checks...`

### 1.1 Confirm cwd is an SFDX project

Run:

```bash
test -f sfdx-project.json && echo "SFDX_PROJECT_OK" || echo "NOT_SFDX"
```

- `SFDX_PROJECT_OK` → continue.
- `NOT_SFDX` → **halt** with this message:

  > Not in an SFDX project — no `sfdx-project.json` in the current directory. `/revops:deploy-prod` must be run from the root of a Salesforce DX repo (e.g., `brite-salesforce`). `cd` into the repo and re-run.

  Do not continue. Do not prompt further.

### 1.2 Confirm current git branch is `main`

Run:

```bash
git rev-parse --abbrev-ref HEAD
```

- Output equals `main` → continue.
- Any other output → **halt** with:

  > Current branch is `{branch}`, not `main`. Production deploys must originate from `main` — check out the merged PR's target branch first. If you need to deploy a feature branch to production, do it manually with `sf` and understand the risk.

  Do not continue.

### 1.3 Confirm working tree is clean

Run:

```bash
git status --porcelain
```

- Empty output → continue.
- Any output → **halt** with:

  > Working tree is not clean. Production deploys must run against a committed, pushed state — uncommitted changes on `main` indicate this is not the intended production baseline. Commit, revert, or stash before re-running `/revops:deploy-prod`.

  Print the `git status --porcelain` output verbatim so the user can see what's dirty.

### 1.4 Confirm intent

Collect:

```bash
git rev-parse --short HEAD
git log -1 --pretty=format:'%s'
```

Show the user a pre-flight summary:

> You are about to deploy to **PRODUCTION** (`brite-prod`).
>
> - Branch: `main`
> - Latest commit: `{short-sha}` — `{commit-subject}`
> - Working tree: clean
>
> Next: prod dry-run.

Ask via `AskUserQuestion`:

- Question: `Proceed to prod dry-run?`
- Options:
  - `Yes, run prod dry-run` — proceed to Phase 2.
  - `No, stop here` — **halt** cleanly. Print: *"Stopped before dry-run. No `sf` commands were issued. Re-run `/revops:deploy-prod` when ready."* Exit.

Narrate: `Phase 1/7: Pre-flight checks... done`

---

## Phase 2 — Prod dry-run

Narrate: `Phase 2/7: Prod dry-run...`

Run:

```bash
sf project deploy start --source-dir force-app --dry-run --target-org brite-prod --json
```

Parse the JSON response. Treat top-level `status === 0` as success:

- `status: 0` → dry-run passed. Extract and report `result.numberComponentsTotal`, `result.numberComponentsDeployed`, `result.numberTestsTotal` (if present). If `result.details.runTestResult.codeCoverage` is present in the dry-run, report the number of classes covered for visibility.
- Any other `status` → dry-run failed. Print `result.details.componentFailures[*].problem` for each failure (or the raw JSON if the shape is unexpected). **Halt** with:

  > Prod dry-run failed against `brite-prod`. Fix the errors above locally, sandbox-verify with `/revops:deploy-sandbox`, reopen/amend the PR if needed, and re-run `/revops:deploy-prod`. No actual deploy was attempted.

  Do **not** continue to Phase 3 under any circumstances. Do **not** prompt for confirmation.

Narrate: `Phase 2/7: Prod dry-run... done`

---

## Phase 3 — DOUBLE confirmation gate

Narrate: `Phase 3/7: Double-confirmation gate...`

This phase issues **two separate** `AskUserQuestion` calls — never a single multi-option picker. The second confirmation must occur after the user has committed to the first.

### 3.1 Gate A — intent

Ask via `AskUserQuestion`:

- Question: `Dry-run passed ({N} components). Ready to deploy to PRODUCTION?`
  - Substitute `{N}` with `numberComponentsTotal` from Phase 2.
- Options:
  - `Yes, deploy to brite-prod` — proceed to Gate B (below).
  - `No, stop here` — **halt** cleanly. Print: *"Stopped after dry-run. No deploy was attempted. Re-run `/revops:deploy-prod` when ready."* Exit.

### 3.2 Gate B — final confirmation

Only reached if Gate A returned `Yes, deploy to brite-prod`. Ask via `AskUserQuestion`:

- Question: `This will modify the production Salesforce org. Confirm one more time.`
- Options:
  - `Confirm — deploy now` — proceed to Phase 4.
  - `Cancel — do not deploy` — **halt** cleanly. Print: *"Canceled at final confirmation. No deploy was attempted."* Exit.

Narrate: `Phase 3/7: Double-confirmation gate... done` only after both gates return proceed.

---

## Phase 4 — Actual prod deploy *(mutating)*

Narrate: `Phase 4/7: Actual prod deploy...`

Run (same command as Phase 2, without `--dry-run`):

```bash
sf project deploy start --source-dir force-app --target-org brite-prod --json
```

Parse the JSON (same `status === 0` check as Phase 2):

- `status: 0` → deploy succeeded. Print `result.numberComponentsDeployed` and `result.id` (the AsyncResult Id — useful for Setup > Deployment Status lookups in the prod org).
- Any other `status` → deploy failed after dry-run passed. This is unusual (dry-run normally catches failures) but can happen with rollbacks, race conditions, or test-level differences. Print `result.details.componentFailures[*]` verbatim. **Halt** with:

  > Deploy failed in `brite-prod` despite dry-run passing. The production org may be in a partial state depending on how far the deploy progressed — inspect `Setup > Deployment Status` in `brite-prod` immediately. Do not re-run `/revops:deploy-prod` until you understand what partial state (if any) exists. Coverage + post-deploy verification were not attempted.

  Do **not** continue to Phase 5.

Capture the deploy response for Phase 5 (coverage check) and Phase 6 (Tooling API verification). Specifically keep the `result.details.componentSuccesses[*]` array — each element's `componentType` + `fullName` drives Phase 6 SOQL.

Narrate: `Phase 4/7: Actual prod deploy... done`

---

## Phase 5 — Coverage check (hard-gate)

Narrate: `Phase 5/7: Coverage check...`

Production deploys that include Apex must meet the Brite bar of ≥90% test coverage per the `brite-salesforce` standard. This phase checks the coverage reported in the Phase 4 deploy response and hard-gates continuation if the bar isn't met.

Read `result.details.runTestResult` from the Phase 4 JSON. Handle the three distinct cases separately — do not conflate "field absent" with "zero tests ran" (BC-5795 precedent):

- **`runTestResult` is entirely absent** — this is unexpected for a successful deploy envelope. **Halt** with the raw Phase 4 JSON printed verbatim and this message:

  > Expected `runTestResult` field missing from the deploy envelope, but Phase 4 reported success. This indicates a `sf` CLI shape drift — do not trust the coverage check or Phase 6 verification. Inspect `Setup > Deployment Status` in `brite-prod` and verify coverage manually in `Setup > Apex Test Execution` before running `/revops:post-deploy-runbook`.

  Do not proceed to Phase 6 automatically.

- **`runTestResult` is present and `numTestsRun === 0`** — the deploy did not include Apex changes that triggered test execution. Report: *"Deploy did not trigger test execution (no Apex in change set). Coverage check N/A — proceeding to Phase 6."* Skip to Phase 6.
- **`runTestResult` is present and `numTestsRun > 0`** — compute aggregate coverage from `runTestResult.codeCoverage[*]`. Sum `numLocations` and `numLocationsNotCovered` across all array entries:

  ```
  total_lines = sum(entry.numLocations for entry in runTestResult.codeCoverage)
  uncovered   = sum(entry.numLocationsNotCovered for entry in runTestResult.codeCoverage)
  coverage_pct = ((total_lines - uncovered) / total_lines) * 100  if total_lines > 0 else 0
  ```

  If any listed field is absent at runtime, **halt** with the raw `runTestResult` JSON printed verbatim and this message:

  > Could not compute aggregate coverage — expected fields (`numLocations`, `numLocationsNotCovered`) are missing from `runTestResult.codeCoverage`. The deploy landed in `brite-prod`, but coverage verification could not proceed automatically. Inspect the `runTestResult` JSON above and verify coverage manually in `Setup > Apex Test Execution`. Do not run Phase 6 blindly — re-invoke manually after you've confirmed the platform-level state.

  Do not guess a coverage value. Do not skip forward.

Report the computed coverage percentage to the user.

- **`coverage_pct >= 90`** → narrate `Phase 5/7: Coverage check... done` and proceed to Phase 6.
- **`coverage_pct < 90`** → surface the gap with per-class detail (from `runTestResult.codeCoverage[*]` — sort ascending by coverage ratio, print the bottom 5 classes). Then ask via `AskUserQuestion`:

  - Question: `Org coverage is {X.X}% — below the 90% bar. Continue to Tooling API verification anyway?`
    - Substitute `{X.X}` with the computed percentage.
  - Options:
    - `Continue — I'll remediate separately` — proceed to Phase 6. Print: *"Coverage below bar — file a follow-up issue to restore ≥90% before the next prod deploy."*
    - `Halt — investigate now` — **halt** cleanly. Print: *"Halted at coverage gate. Deploy landed in `brite-prod` but test coverage regressed below 90%. Investigate failing/missing tests, restore coverage, and re-deploy if needed. Do NOT run `/revops:post-deploy-runbook` on this state."* Exit.

Narrate: `Phase 5/7: Coverage check... done` (or `... halted`).

---

## Phase 6 — Tooling API post-deploy verification

Narrate: `Phase 6/7: Tooling API post-deploy verification...`

Confirm that what we believe we deployed actually landed in `brite-prod` as visible entities. Some component classes (Flow in particular) can deploy successfully but end up in a non-functional state (Draft rather than Active) — Tooling API SOQL is the authoritative check.

Iterate `result.details.componentSuccesses[*]` from the Phase 4 JSON. Group by `componentType`. Run the matching SOQL below via `sf data query --use-tooling-api` for each non-empty group. Always pin `--target-org brite-prod --json`.

### 6.1 ApexTrigger

If any successes have `componentType: "ApexTrigger"`, collect their `fullName` values into a quoted-list `{names}`:

```bash
sf data query --use-tooling-api --query "SELECT Id, Name, Status FROM ApexTrigger WHERE Name IN ({names})" --target-org brite-prod --json
```

Verify every name in `{names}` appears in `result.records` with `Status = 'Active'`. Report any missing or non-Active triggers.

### 6.2 CustomField

If any successes have `componentType: "CustomField"`, `fullName` values look like `Object__c.Field__c`. Split each on the first `.` into `{object}` and `{field-api-name}`. Both sides must have any trailing `__c` suffix **stripped** before interpolating into SOQL — Tooling API `EntityDefinition.DeveloperName` stores the unsuffixed name for custom objects (e.g., `Account__c` → `Account`), and `CustomField.DeveloperName` likewise stores the unsuffixed field name. Batch queries per-object after stripping:

```bash
sf data query --use-tooling-api --query "SELECT Id, DeveloperName FROM CustomField WHERE EntityDefinition.DeveloperName = '{object-stripped}' AND DeveloperName IN ({field-names-stripped})" --target-org brite-prod --json
```

Where `{object-stripped}` is `{object}` with the trailing `__c` removed (if present — standard objects have no suffix), and `{field-names-stripped}` is the quoted list of `{field-api-name}` values, each with its trailing `__c` removed.

Report any field expected in the deploy but missing from the query result.

### 6.3 Flow

If any successes have `componentType: "Flow"`, collect their `fullName` values into `{names}`. The Tooling API `Flow` sObject is per-**version** (one row per version, not per definition) — filter to current states only, excluding historical `Obsolete` versions that would skew Phase 6.4's denominator:

```bash
sf data query --use-tooling-api --query "SELECT Id, DeveloperName, Status FROM Flow WHERE DeveloperName IN ({names}) AND Status IN ('Active','Draft')" --target-org brite-prod --json
```

For each returned record: confirm `Status = 'Active'`. **Flag any Flow with `Status = 'Draft'`** — these deployed but require manual activation (this is a known Salesforce platform behavior for Screen Flows via metadata API). Report the full list:

> ⚠️ Flow(s) deployed as Draft — require manual activation in Setup → Flows. Affected: `{names}`. Run `/revops:post-deploy-runbook` to walk the activation steps.

### 6.4 Reporting

Surface a compact verification report:

- `✓ ApexTrigger verified: {N}/{N}` (or `✗ {missing}/{N} missing` with the names)
- `✓ CustomField verified: {N}/{N}` (or the same pattern)
- `Flow verified: {active}/{total} active, {draft}/{total} Draft` (Draft is a warning, not a fail)

**Do not auto-retry any query.** If a SOQL call returns `status != 0`, print the raw response and surface the query verbatim so the user can re-run it manually. Silent retries can mask Tooling API rate limits or transient auth issues that the user needs to see.

Component types not listed above (ApexClass, PermissionSet, Layout, etc.) are not auto-verified by Phase 6 — the `componentSuccesses` array plus `Setup > Deployment Status` is sufficient for those. Add new component-type branches to this phase only when a repeat post-deploy surprise justifies it.

Narrate: `Phase 6/7: Tooling API post-deploy verification... done`

---

## Phase 7 — Runbook trigger + completion

Narrate: `Phase 7/7: Completion...`

Print the summary:

- `✓ Pre-flight passed (branch=main, clean tree, intent confirmed)`
- `✓ Dry-run passed ({N} components)`
- `✓ Double-confirmation gate passed`
- `✓ Prod deploy succeeded (deploy id: {id})`
- `✓ Coverage: {X.X}%` (or `⚠ Coverage: {X.X}% (below bar, user continued)`, or `Coverage: N/A (no Apex)`)
- `✓ Tooling API verification: {summary}` (surface Flow Draft warnings here)

Then the next-step hint:

> Production deploy landed. **Next: run `/revops:post-deploy-runbook`** to walk manual post-merge steps:
>
> - Screen Flow activation (flagged above if any)
> - Scheduled Apex re-schedule (if Apex jobs were redeployed)
> - Named Credential URL refresh (per prod org)
> - Kanban / page layout cache flush (if new picklist values landed on standard objects)

Narrate: `Phase 7/7: Completion... done`

---

## Rules

- **Never skip a gate.** Every `AskUserQuestion` halt path must halt — no silent continuation.
- **Phase 3 gates are two separate `AskUserQuestion` calls.** A single multi-option picker is unacceptable.
- **Always pass `--target-org brite-prod`.** Never rely on the default org — behavior must be reproducible across machines and safe against a mis-set default.
- **Parse `--json` output via `status === 0`.** Never parse `result.success` — it has changed shape across `sf` CLI 2.x versions.
- **Verify CLI fields before using them.** If a documented `sf` JSON field is not present at runtime, halt with the raw JSON and operator instructions — never invent a fallback value or guess.
- **`sf`, not `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Do not retry on failure.** Any `sf` invocation that fails surfaces the raw output and halts. Silent retries mask real issues (Tooling API limits, auth drift, partial-deploy state).
- **Phase 4 is the only mutating phase.** If a future amendment adds a mutating call elsewhere (e.g., auto-activating a Flow), it MUST be preceded by an explicit `AskUserQuestion` gate and this list MUST be updated.
- **Flow Draft is a warning, not an error.** The Salesforce metadata API deploys Screen Flows as Draft — this is platform behavior, not a deploy failure. Phase 6 surfaces the list; Phase 7 points at `/revops:post-deploy-runbook` for activation.
