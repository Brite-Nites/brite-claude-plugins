# Plan 002: Make `validate.sh` the single verification entrypoint that mirrors CI

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 04d87b12..HEAD -- scripts/validate.sh .github/workflows/validate-plugin.yml`
> If either file changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `04d87b12`, 2026-07-02

## Why this matters

CI (`.github/workflows/validate-plugin.yml`) runs five blocking test steps
that `scripts/validate.sh` — the documented local gate AND the pre-push hook
(`.githooks/pre-push:23` runs *only* validate.sh) — never runs:
`test-hook-model-lint.sh`, `test-skill-triggers.sh`, `test-contracts.sh`,
`test-scenarios.sh` (validate.sh already runs `test-hooks.sh` in section 2d).
A developer can go green locally, push, and fail CI. Separately, ~19
validate.sh sections that delegate to sub-harnesses treat an **unparseable
`RESULT pass=N` line as a PASS** ("count unparsed") and never require
`pass >= 1` — so a harness that exits 0 having run zero assertions is
reported green. This plan closes both gaps: after it, `bash scripts/validate.sh`
green ⇒ CI `validate` job green, and every harness must prove it ran
assertions.

## Current state

- `scripts/validate.sh` — 3,019 lines, `set -euo pipefail`, helpers
  `pass()/fail()/warn()/section()` at lines 13-16 (`fail` increments `errors`).
  Its existing delegate pattern, section 2d (lines 844-859):

  ```bash
  section "2d. Security Hook Regex Regression"

  hooks_test="$REPO_ROOT/scripts/test-hooks.sh"

  if [ ! -f "$hooks_test" ]; then
    warn "scripts/test-hooks.sh not found — hook regex regression check skipped"
  else
    if hooks_out=$(bash "$hooks_test" 2>&1); then
      pass_count=$(printf '%s\n' "$hooks_out" | sed -n 's/^  Total: \([0-9]*\)  Passed: \([0-9]*\).*/\2\/\1/p' | tail -1)
      pass "security hook regex regression (${pass_count:-?} scenarios)"
    else
      fail "security hook regex regression failed — run scripts/test-hooks.sh for details"
      printf '%s\n' "$hooks_out" | tail -25 | sed 's/^/    /' >&2
    fi
  fi
  ```

- The "count unparsed" anti-pattern — example at lines 2472-2482 (section
  15a-bc-12701); there are ~19 sites total, listable via
  `grep -n "count unparsed" scripts/validate.sh`:

  ```bash
  if csf_harness_out=$(bash "$csf_harness" "$csf_helper" 2>&1); then
    csf_pass_count=$(printf '%s\n' "$csf_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$csf_pass_count" ]; then
      pass "create-sf-campaign builder unit suite (${csf_pass_count} assertions)"
    else
      pass "create-sf-campaign builder unit suite — passed (count unparsed)"
    fi
  else
    fail "create-sf-campaign builder unit suite failed:"
    ...
  fi
  ```

- `.github/workflows/validate-plugin.yml`, `validate` job steps (all blocking):
  `bash scripts/validate.sh`, `bash scripts/test-hooks.sh`,
  `bash scripts/test-hook-model-lint.sh`, `bash scripts/test-skill-triggers.sh`,
  `bash scripts/test-contracts.sh`, `bash scripts/test-scenarios.sh`.
- The four missing harnesses exist at `scripts/test-hook-model-lint.sh`,
  `scripts/test-skill-triggers.sh` (self-discovers
  `plugins/*/skills/_shared/trigger-registry.json`), `scripts/test-contracts.sh`
  (workflows-only by design), `scripts/test-scenarios.sh` (workflows-only by
  design). Each exits nonzero on failure (that's what CI relies on).
- Full validate.sh currently takes ~3m03s; the four harnesses add whatever they
  cost in CI today (they're already in every CI run, so total CI time is
  unchanged if CI is deduplicated — see Step 4).
- Known settled decision you must honor: harness sections are **explicitly
  wired** (a named section per harness), not glob-discovered (BC-12909
  decision). This plan adds explicit sections; it does not introduce globbing.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `bash scripts/validate.sh` | exit 0, `0 errors` |
| Each harness standalone | `bash scripts/test-hook-model-lint.sh` (etc. ×4) | exit 0 |
| Syntax check after edits | `bash -n scripts/validate.sh` | exit 0, silent |
| Count unparsed sites | `grep -c "count unparsed" scripts/validate.sh` | 0 after Step 3 |

## Scope

**In scope**:
- `scripts/validate.sh`
- `.github/workflows/validate-plugin.yml` (only the `validate` job's step list, only in Step 4)
- `plans/README.md` (status row)

**Out of scope**:
- The four `scripts/test-*.sh` harnesses themselves — do not edit them. If one
  fails, that's a STOP condition, not a fix-it-here.
- The `claude plugin list` install-status section (line ~2915) — separate
  finding (TEST-08), deliberately not touched here.
- Any restructuring/consolidation of the ~40 existing harness sections
  (separate finding DEBT-2). You are ADDING four sections and hardening a
  fallback branch — nothing else moves.
- `.githooks/pre-push` — it already delegates to validate.sh; no change needed.

## Git workflow

- **Bare-root repo**: create a worktree first —
  `git worktree add <path> -b feat/validate-sh-ci-parity origin/main`.
- Conventional commit, e.g.
  `feat(validate): CI-parity sections for 4 harnesses + RESULT-line hard fail`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add four delegate sections to validate.sh

Insert after section 2d' ("Pre-commit Advisory Hook", ends before section 2e
"workflows helper-script unit tests" around line 890) four new sections named
`2d''`-style or `2f`-style (match the file's existing naming spirit; suggested:
`2f. Hook model tier-alias lint`, `2g. Skill trigger matching`,
`2h. Cross-skill contracts (workflows)`, `2i. End-to-end scenarios (workflows)`).
Each section copies the section-2d shape exactly (warn-if-missing, run, fail
with tail -25 on nonzero), pointing at the respective script:
`scripts/test-hook-model-lint.sh`, `scripts/test-skill-triggers.sh`,
`scripts/test-contracts.sh`, `scripts/test-scenarios.sh`. Don't parse a count
for these four unless the harness emits the `RESULT pass=` contract line —
check each harness's output format first (`bash <harness> | tail -3`) and only
add a count-parse for ones that emit it.

**Verify**: `bash -n scripts/validate.sh` → silent. `bash scripts/validate.sh`
→ exit 0 and the four new section headers appear in output.

### Step 2: Prove the new sections can fail

Temporarily break one target (e.g. `mv scripts/test-contracts.sh{,.bak}` makes
it a warn — instead inject a failure: run
`bash -c 'exit 1'`-style by temporarily editing the new section's command to
`bash -c "exit 1"`). Run validate.sh → the section must `fail` and the summary
must show ≥1 error with exit 1. Revert the temporary edit.

**Verify**: with the injected failure `bash scripts/validate.sh; echo $?` → `1`;
after revert → `0`.

### Step 3: Convert "count unparsed" fallbacks to hard failures

For every site found by `grep -n "count unparsed" scripts/validate.sh`
(~19 sites, all shaped like the excerpt in Current state): replace the
`pass "... — passed (count unparsed)"` branch with

```bash
fail "<same label> — exited 0 but no parsable 'RESULT pass=N' line (harness contract broken)"
```

and additionally, in the `[ -n "$..._pass_count" ]` branch, require the count
be non-zero:

```bash
if [ -n "$X_pass_count" ] && [ "$X_pass_count" -gt 0 ]; then
  pass "... (${X_pass_count} assertions)"
else
  fail "... — RESULT line missing or pass=0 (harness ran no assertions)"
fi
```

Keep each site's label text intact. Do NOT touch section 2d (test-hooks.sh
uses a `Total:/Passed:` format, not the RESULT contract) or section 2e's
workflows loop unless it also has a count-unparsed fallback (it does not — it
uses `${wf_pass_count:-?}` inside a pass; leave it, it's driven by exit code
and is a loop, not a per-harness registration).

**Verify**: `grep -c "count unparsed" scripts/validate.sh` → 0.
`bash scripts/validate.sh` → still exit 0 with all sections passing and every
formerly-fallback section now printing a real assertion count. If ANY section
now fails, that harness genuinely doesn't emit the contract line — STOP
condition (report which).

### Step 4: Deduplicate the CI step list

In `.github/workflows/validate-plugin.yml` `validate` job, the five explicit
harness steps (`test-hooks.sh`, `test-hook-model-lint.sh`,
`test-skill-triggers.sh`, `test-contracts.sh`, `test-scenarios.sh`) are now
redundant with validate.sh. Remove those five steps, keeping the
marketplace fast-fail step and the `bash scripts/validate.sh` step (and all
other jobs untouched). Add a YAML comment noting validate.sh §2d/2f-2i now own
them (single source of truth).

**Verify**: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/validate-plugin.yml'))"`
→ silent (if pyyaml is unavailable, use `ruby -ryaml -e "YAML.load_file(...)"`
or a careful visual diff). `git diff .github/workflows/validate-plugin.yml`
shows only step removals + comment in the `validate` job.

### Step 5: Full gate + commit

`bash scripts/validate.sh` → exit 0. Commit.

## Test plan

The negative test in Step 2 is the test (a validator change must be shown able
to fail). No new test files. Machine verification is the Done criteria below.

## Done criteria

- [ ] `bash scripts/validate.sh` exits 0 on the unmodified tree
- [ ] The four harnesses each appear as a section in validate.sh output
- [ ] Injected failure test (Step 2) demonstrated exit 1, then reverted
- [ ] `grep -c "count unparsed" scripts/validate.sh` → 0
- [ ] CI workflow `validate` job no longer lists the five harness steps individually
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Any of the four harnesses fails when run standalone on the clean tree (the
  gap this plan closes may have already let a regression in — that's a bug
  report, not something to patch here).
- Step 3 causes any existing section to fail because its harness never emits
  `RESULT pass=N` — report the harness list; do not weaken the check back.
- validate.sh runtime grows past ~5 minutes (pre-push viability threshold —
  report; the operator may want the four sections gated behind a flag instead).
- The count-unparsed grep finds sites whose surrounding shape does NOT match
  the Current-state excerpt (drifted structure).

## Maintenance notes

- Future harness sections must use the hardened shape (RESULT line required,
  pass>0) — reviewers should reject new sections with a silent fallback.
- This plan intentionally leaves the ~40-section registration boilerplate and
  the 3-minute runtime alone; finding DEBT-2/DIR-3 (registration-table
  consolidation) builds on this and should land after it.
- If a per-plugin release process later splits validate.sh, the four new
  sections belong to the "repo-wide" half (they self-discover across plugins
  or are workflows-scoped by design).
