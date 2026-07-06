# Plan 003: Execute the 26 orphaned Python test files in CI (they currently never run)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 04d87b12..HEAD -- plugins/revops/tests plugins/marketing/tests plugins/workflows/tests .github/workflows/validate-plugin.yml plugins/revops/pyproject.toml`
> If in-scope files changed since this plan was written, compare the "Current
> state" facts against the live tree before proceeding; on a mismatch, treat
> it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (first enforced run may surface rotted tests — quarantine mechanism included)
- **Depends on**: plans/002-single-verification-entrypoint.md (lands the "validate.sh mirrors CI" invariant this plan extends)
- **Category**: tests
- **Planned at**: commit `04d87b12`, 2026-07-02

## Why this matters

The repo contains 26 `test_*.py` files that no CI step, no `validate.sh`
section, and no hook ever executes. `.github/dependabot.yml:10` states it
plainly: "Brite CI does not invoke uv, pytest, or black." Among the untested
code are **live runtime security guards** — the revops PreToolUse validators
(`soql_validator.py`, `security_validator.py`, `naming_validator.py`,
`validator-dispatcher.py`, `llm_pattern_validator.py`) that gate Salesforce
operations. A regression in any of them ships with zero signal, while the
existing test files give reviewers false confidence that coverage exists.

## Current state

- The 26 files (all paths repo-relative):
  ```
  plugins/marketing/tests/test_import_campaign_contracts.py
  plugins/marketing/tests/test_plan_campaign_contracts.py
  plugins/marketing/tests/test_sync_campaign_status_contracts.py
  plugins/revops/tests/hooks/test_agentscript_validator.py
  plugins/revops/tests/hooks/test_apex_validators.py
  plugins/revops/tests/hooks/test_dispatcher_execution.py
  plugins/revops/tests/hooks/test_dispatcher_routing.py
  plugins/revops/tests/hooks/test_flow_validator.py
  plugins/revops/tests/hooks/test_integration_validator.py
  plugins/revops/tests/hooks/test_lwc_validators.py
  plugins/revops/tests/hooks/test_metadata_validator.py
  plugins/revops/tests/hooks/test_soql_validator.py
  plugins/revops/tests/test_create_sf_campaign_contracts.py
  plugins/revops/tests/test_datacloud_registry_contracts.py
  plugins/revops/tests/test_datacloud_runtime_integration.py
  plugins/revops/tests/test_datacloud_skill_contracts.py
  plugins/revops/tests/test_deploy_scope_contracts.py
  plugins/revops/tests/test_doctor_contracts.py
  plugins/revops/tests/test_flex_estimator_contracts.py
  plugins/revops/tests/test_install_datacloud_runtime.py
  plugins/revops/tests/test_install_hooks_config.py
  plugins/revops/tests/test_post_deploy_runbook_contracts.py
  plugins/revops/tests/test_setup_sandbox_contracts.py
  plugins/revops/tests/test_skill_registry_contracts.py
  plugins/revops/tests/test_update_sf_campaign_status_contracts.py
  plugins/workflows/tests/test_gbrain_flywheel_contracts.py
  ```
- They are **pytest** tests, not stdlib unittest. Head of
  `plugins/revops/tests/hooks/test_soql_validator.py`:
  ```python
  """Tests for sf-soql post-tool-validate.py validator."""
  from __future__ import annotations

  import pytest

  from tests.hooks.conftest import (
      FIXTURES_DIR,
      run_validator,
  )
  ```
  Note the absolute-style `from tests.hooks.conftest import …` — pytest must
  run with rootdir/`PYTHONPATH` such that `tests` is importable, i.e. run
  **from `plugins/revops/`**, per plugin, not from the repo root.
- `plugins/revops/pyproject.toml` exists and (per its dependabot note)
  declares test/dev optional-dependencies (pytest, black, isort, mypy). Read
  it before Step 1 to confirm any `[tool.pytest.ini_options]` config.
- `.github/workflows/validate-plugin.yml` — the `validate` job currently has
  no Python-test step. All jobs use `permissions: contents: read`.
- Repo gotcha that applies: `__pycache__/` and `*.pyc` are already gitignored.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Install runner (CI + local) | `python3 -m pip install pytest` | exit 0 |
| Run one plugin's tests | `cd plugins/revops && python3 -m pytest tests/ -q` | `N passed` or documented quarantines |
| Full local gate | `bash scripts/validate.sh` | exit 0 |
| List collected tests without running | `cd plugins/revops && python3 -m pytest tests/ --collect-only -q \| tail -3` | count line, no collection errors |

## Scope

**In scope**:
- `.github/workflows/validate-plugin.yml` (add one job)
- `scripts/test-python-units.sh` (new — thin wrapper so local == CI)
- `scripts/validate.sh` (one new section delegating to the wrapper, using the
  hardened section shape from plan 002)
- `docs/python-test-quarantine.md` (new — only if Step 2 finds failures)
- Individual `test_*.py` files ONLY to apply `@pytest.mark.skip(reason=…)`
  quarantine markers per Step 3 (no other edits)
- `plans/README.md` (status row)

**Out of scope**:
- Fixing the production code under test. If a test fails because the validator
  is wrong (not the test), that's a bug report in your final summary, and the
  test gets quarantined with a reason pointing at the discrepancy — the fix is
  a separate change.
- Rewriting tests to stdlib unittest, adding coverage tooling, black/mypy.
- The tam-map and cadence missing-test findings (TEST-06) — different plan.

## Git workflow

- **Bare-root repo**: `git worktree add <path> -b feat/run-python-unit-tests origin/main`.
- Conventional commit, e.g. `feat(ci): execute the 26 orphaned python test suites (pytest job + validate.sh section)`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Discover the true pass/fail baseline

For each of the three plugins with tests, from the plugin directory:
`python3 -m pytest tests/ -q` (revops), and for marketing/workflows check
first whether their tests also use a conftest/package import style
(`head -15` each file) and run from whichever directory makes collection
succeed. Record per-file pass/fail/error counts. Do not fix anything yet.

**Verify**: a written baseline table in your working notes: file → outcome.
Collection errors count as failures.

### Step 2: Create `scripts/test-python-units.sh`

A small wrapper that, for each plugin in `revops marketing workflows`
(explicit list — repo convention is explicit wiring, per BC-12909):
`( cd "plugins/$p" && python3 -m pytest tests/ -q --no-header )`,
accumulating failures, and finally emitting the repo's harness contract line
`RESULT pass=<total-passed> fail=<total-failed>` and exiting nonzero on any
failure. Guard the case where pytest is not installed with a clear
`SKIP: pytest not installed — pip install pytest` + exit 0 **only when**
`CI` env var is unset (local machines may lack pytest; CI must hard-require it:
if `CI=true` and pytest missing → exit 1). Follow existing script style
(`set -euo pipefail`, bash-3.2-safe constructs — no `mapfile`, no `${arr[-1]}`).

**Verify**: `bash scripts/test-python-units.sh` → prints per-plugin results +
`RESULT pass=N fail=M` matching Step 1's baseline; exit code 0 iff M=0.

### Step 3: Quarantine genuinely-rotted tests (only if Step 1 found failures)

For each failing test file, decide: (a) trivially stale assertion (fixture
path moved, constant renamed) — fix the TEST file only; (b) failure implicates
production code or requires >15 lines of test change — add
`pytestmark = pytest.mark.skip(reason="quarantined: <one-line reason> — see docs/python-test-quarantine.md")`
at module top, and add a row to a new `docs/python-test-quarantine.md`
(file, reason, suspected cause, date). The quarantine doc's header must state
the goal is emptying itself.

**Verify**: `bash scripts/test-python-units.sh` → exit 0, `fail=0`,
and pass-count within (baseline passes ± quarantined/fixed delta).

### Step 4: Wire into validate.sh and CI

(a) Add one validate.sh section (place near section 2e, name it e.g.
`2j. Python unit suites (pytest)`) delegating to
`scripts/test-python-units.sh` with the plan-002 hardened shape (RESULT line
required, `pass -gt 0`, fail branch tails output). Keep the pytest-missing
local SKIP path surfacing as a `warn`, not a `pass`.
(b) Add a `python-units` job to `.github/workflows/validate-plugin.yml`
(mirror the `vslice-greenfield` job shape: `needs: validate`,
`timeout-minutes: 10`, `permissions: contents: read`, NO `continue-on-error` —
this gate is blocking): steps = checkout@v4, `python3 -m pip install pytest`,
`bash scripts/test-python-units.sh` with `CI: "true"` in env.

**Verify**: `bash -n scripts/validate.sh` silent; `bash scripts/validate.sh` →
exit 0 including the new section with a real count; workflow YAML parses.

### Step 5: Full gate + commit

`bash scripts/validate.sh` → exit 0. Commit everything (including the
quarantine doc if created).

## Test plan

The suite IS the test. Negative check: temporarily add `assert False` to any
one collected test, run `bash scripts/test-python-units.sh` → exit 1 and
validate.sh section fails; revert.

## Done criteria

- [ ] `bash scripts/test-python-units.sh` exits 0 with `RESULT pass=N fail=0`, N > 0
- [ ] Negative check demonstrated (assert False → exit 1 → reverted)
- [ ] validate.sh has the new section; full run exits 0
- [ ] CI workflow has the blocking `python-units` job
- [ ] Every quarantined test has a skip reason + a row in `docs/python-test-quarantine.md`; zero silent deletions
- [ ] Final report lists: baseline table, what was fixed vs quarantined, any production-code bugs implicated
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- More than 8 of the 26 files fail at baseline (the rot is bigger than a
  quarantine list — the operator should see the picture before you bulk-skip).
- A failing test implicates a SECURITY validator's production behavior
  (soql/security/naming validators under `plugins/revops/**/hooks/scripts/`) —
  report immediately; do not quarantine silently.
- Tests import packages beyond pytest + stdlib that aren't in the repo
  (e.g. need `uv sync` of revops optional-deps) and a plain
  `pip install pytest` can't collect them — report the dependency set instead
  of installing arbitrary packages.
- marketing/workflows test files turn out to need a different runner layout
  that `cd plugins/<p> && pytest tests/` can't satisfy after one honest
  attempt at conftest/pythonpath adjustment.

## Maintenance notes

- New `test_*.py` files under any `plugins/*/tests/` are auto-collected only
  for the three wired plugins; adding a fourth plugin's Python tests requires
  adding it to the explicit list in `scripts/test-python-units.sh` (convention:
  explicit wiring — reviewers should check for this on new-plugin PRs).
- The quarantine doc is a ratchet like `docs/skill-eval-debt.md` — reviews
  should push it toward empty, and any PR touching a validator should be
  expected to un-quarantine its tests.
- Watch CI runtime: if pytest exceeds ~2 min, split per-plugin jobs.
