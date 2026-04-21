# BC-5791 Plan — Build `/revops:deploy-prod` orchestration command

**Issue:** [BC-5791](https://linear.app/brite-nites/issue/BC-5791/build-revopsdeploy-prod-orchestration-command)
**Priority:** High
**Milestone:** RevOps Plugin (Phase 2 — Orchestration Commands, 2nd of 3)
**Branch:** `holden/bc-5791-build-revopsdeploy-prod-orchestration-command`
**Worktree:** `.claude/worktrees/bc-5791`
**Baseline:** `origin/main` at `0b5b03c` — validate.sh: 0 errors, 16 warnings.

## Goal

Ship `plugins/revops/commands/deploy-prod.md` — a 7-phase orchestration command for production Salesforce deploys. Inherits the BC-5790 `/revops:deploy-sandbox` template (ratified in PR #160). Applies BC-5791-specific overrides: double-confirmation gate, hard-gate on coverage, Tooling API post-deploy verification, pre-flight git-state enforcement.

## Inherited template contract (BC-5790 precedent)

Per `docs/precedents/BC-5790.md` and the shipped `deploy-sandbox.md`, every Phase 2 RevOps command must:

1. Frontmatter: `description` + `allowed-tools: Bash, AskUserQuestion` only. No MCP, no file I/O.
2. Top-of-file **Rules** section that states which phases are mutating.
3. Parse every `sf ... --json` response via top-level `status === 0` — never `result.success` (BC-5790 simplify-pass confirmed cross-version stability).
4. Every mutating phase is preceded by an `AskUserQuestion` gate.
5. Pin `--target-org` explicitly on every `sf` call — never rely on default-org.
6. Use `sf`, never legacy `sfdx`.
7. No silent retries on `sf` failure — surface raw output and halt.
8. Phase 5 (manual verification) style: human is the sensor, no automation.

## BC-5791 departures from BC-5790

| Aspect | BC-5790 sandbox | BC-5791 prod |
|---|---|---|
| Target org alias | `brite-sandbox` | `brite-prod` |
| Pre-flight scope | cwd is SFDX, alias confirm | cwd is SFDX, **branch=main**, **no uncommitted changes**, intent confirm |
| Mutation confirm | Single AskUserQuestion | **TWO distinct AskUserQuestion calls** (non-batched, non-negotiable) |
| Coverage policy | Soft warning on Apex test fail | **Hard-gate**: <90% coverage halts with user-escape prompt |
| Post-deploy verify | None | **Tooling API SOQL** (ApexTrigger/CustomField/Flow) |
| Mutating phases | 2, 3 (dry-run + deploy) | **Phase 4 only** (dry-run is separate, gated) |
| Next-step hint | Review / Ship / deploy-prod | **`/revops:post-deploy-runbook`** (Flow activation, Scheduled Apex re-schedule, Named Credentials) |

## Phase structure (from issue body §Plan)

- **Phase 1 — Pre-flight**: cwd is SFDX project → halt if not; current branch is `main` → halt if not; no uncommitted changes → halt if unclean; show summary (branch, latest commit SHA) + `AskUserQuestion` "Proceed to dry-run?"
- **Phase 2 — Prod dry-run**: `sf project deploy start --source-dir force-app --dry-run --target-org brite-prod --json`; halt on non-zero `status`; on success, report component counts + test execution plan.
- **Phase 3 — DOUBLE confirmation gate**: two distinct `AskUserQuestion` calls. Gate A: "Dry-run passed. Ready to deploy to PRODUCTION?" (Yes/No). Gate B: "This will modify the production Salesforce org. Confirm one more time." (Confirm/Cancel). Both must pass.
- **Phase 4 — Actual prod deploy** *(mutating)*: `sf project deploy start --source-dir force-app --target-org brite-prod --json`; halt on non-zero `status`; capture `result.details.componentSuccesses[*]` for Phase 6 SOQL.
- **Phase 5 — Coverage check**: parse `result.details.runTestResult.codeCoverage` + org-wide coverage fields from Phase 4 JSON. If <90%: surface the gap + `AskUserQuestion` "Coverage below 90% — continue verification anyway?" Confirm/Halt. **Hard-gate per BC-5791 precedent override**.
- **Phase 6 — Tooling API post-deploy verification**: for each deployed component of type ApexTrigger / CustomField / Flow, run `sf data query --use-tooling-api --query "..." --target-org brite-prod --json`. Verify presence + Flow `Status='Active'` (flag Draft). Surface report; **do not auto-retry** (BC-5795 rule).
- **Phase 7 — Runbook trigger**: suggest `/revops:post-deploy-runbook` + print completion checklist.

## Tasks

1. **Write `plugins/revops/commands/deploy-prod.md`** (~20 min)
   - Copy skeleton from `plugins/revops/commands/deploy-sandbox.md`.
   - Update frontmatter `description` — prod-specific wording.
   - Rewrite all 7 phases per issue body.
   - Top-of-file Rules block explicitly lists **Phase 4** as the sole mutating phase (BC-5790 precedent).
   - Rules block restates: `status === 0` parse, `--target-org brite-prod` pin, `sf` not `sfdx`, no retries, no default-org.
   - Phase 3 must contain **two distinct `AskUserQuestion` prompts** (T10 grep-check passes).

2. **Simplify pass** (~5 min)
   - Remove any dead default-org check (BC-5790 simplify precedent).
   - Grep for any referenced `sf` CLI JSON field (`status`, `result.details.componentSuccesses`, `result.details.runTestResult.codeCoverage`, `result.id`, `result.numberComponentsTotal`) and confirm shape vs `sf` docs. If uncertain about a field, either fall back to a more conservative parse or halt with explicit error + operator instruction (avoid BC-5795 factual-error class).
   - De-duplicate: if any Rules-section directive is also repeated inline in a phase, keep the phase-level one and trim the global.

3. **Static verify matrix walk** (~10 min)
   - Walk T1–T10 from issue body statically against the drafted markdown.
   - T10 is objective: `grep -c "AskUserQuestion" plugins/revops/commands/deploy-prod.md` must be ≥ 3 (Phase 1 intent gate, Phase 3 gate A, Phase 3 gate B, Phase 5 coverage escape).
   - Other rows (T1–T9) are flow-walk — each should trace to a phase halt/branch in the markdown.
   - Paste the walked results into the PR body (per issue body requirement).

4. **validate.sh + check-guardrails** (~2 min)
   - `./scripts/validate.sh` → 0 errors, ≤17 warnings (16 baseline + possibly 0 delta).
   - `./scripts/check-guardrails.sh --claude-md CLAUDE.md` → 0 violations.

5. **Commit** (~1 min)
   - Message: `BC-5791: add /revops:deploy-prod orchestration command`
   - Include plan file + command file in single commit.

## Out of scope

- `/revops:post-deploy-runbook` (BC-5792, next Phase 2 issue).
- Rollback automation — if deploy fails, user diagnoses manually.
- T1 live end-to-end (prod deploy) — deferred to first real-world prod ship. The 10-row matrix is static/dry-path verification only.
- Extending to other `sf` CLI versions — we target current stable only.

## Precedent overrides to apply verbatim

- **BC-5790 (pattern-choice, 8/10):** state mutating phases in Rules; ratify `status === 0`; no dead default-org checks; simplify-pass pre-commit.
- **BC-5795 (pattern-choice, 9/10):** independently verify every CLI field referenced; if uncertain, halt with explicit guidance rather than proceed with a guessed field.
- **BC-5826 (pattern-choice, 8/10):** one up-front semantic operator-intent gate per batch, but per-phase mutating-call gates remain; this is a **single-mutation** command, so BC-5790's per-phase gate pattern applies, not BC-5826's batched semantic+turn-structure split.

## Links

- Issue body: `gitBranchName: holden/bc-5791-build-revopsdeploy-prod-orchestration-command`
- Related: BC-5790 (template source, PR #160), BC-5792 (runbook sibling), BC-5806 (SessionStart hook)
- Master plan: `docs/plans/revops-plugin-master-plan.md` §8 Issue 2.2
- Template: `plugins/revops/commands/deploy-sandbox.md` (inherited pattern)
