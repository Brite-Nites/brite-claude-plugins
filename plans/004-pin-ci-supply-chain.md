# Plan 004: Pin CI supply chain in secret-bearing workflows + cap eval-artifact retention

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 04d87b12..HEAD -- .github/workflows/`
> If any workflow changed since this plan was written, compare the "Current
> state" excerpts against the live files before proceeding; on a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (but if plan 002 already merged, `validate-plugin.yml` step list differs — the drift check will flag it; only the `uses:` pins matter there, proceed on that basis)
- **Category**: security
- **Planned at**: commit `04d87b12`, 2026-07-02

## Why this matters

Every third-party GitHub Action in this repo is referenced by a **mutable
major tag** (`actions/checkout@v4`, `actions/upload-artifact@v4`,
`actions/download-artifact@v4`), and the two secret-bearing workflows also
`npm install -g` **unpinned** CLIs at run time. `behavioral-tests.yml` holds
`ANTHROPIC_API_KEY`; `jwt-validity-probe.yml` holds `SFDX_AUTH_URL_PROD` (a
prod Salesforce refresh token) and `LINEAR_API_KEY`. A moved tag or a
compromised npm release runs arbitrary code with those secrets in scope. The
repo is public, raising exposure. Additionally, behavioral-test artifacts
serialize **full model output** (`scripts/test-behavioral.sh:397` json-dumps
the transcript) into artifacts retained **90 days** — longer than any debrief
needs.

## Current state

- `.github/workflows/validate-plugin.yml` — 8× `uses: actions/checkout@v4`,
  1× `uses: actions/upload-artifact@v4` (mode-classifier report). No secrets;
  `permissions: contents: read` everywhere (good). Pin these too for
  consistency, but they're the low-risk tier.
- `.github/workflows/behavioral-tests.yml`:
  - line 22: `EVALS_MODEL: "claude-sonnet-4-6"` (see Step 4)
  - line 29 + 66: `uses: actions/checkout@v4`
  - line 33: `npm install -g @anthropic-ai/claude-code` (unpinned)
  - line 37/76: `ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}`
  - lines 52-58 and 79-85: `uses: actions/upload-artifact@v4` /
    `actions/download-artifact@v4`, `path: tests/evals/behavioral-*.json`,
    `retention-days: 90`
- `.github/workflows/jwt-validity-probe.yml`:
  - line 30: `npm install -g @salesforce/cli` (unpinned)
  - lines 32-36: writes `secrets.SFDX_AUTH_URL_PROD` to `$RUNNER_TEMP`, logs
    in, removes the file (this handling is fine — do not change it)
  - no third-party `uses:` actions (nothing to pin besides the npm CLI)
- Existing MCP supply-chain convention in this repo: everything pinned to
  exact versions (`@salesforce/mcp@0.30.5`, `mcp-remote@0.1.38`, etc.) — CI
  should match that posture.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Resolve a tag to its commit SHA | `gh api repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha'` (if the object is an annotated tag, dereference: `gh api repos/actions/checkout/git/tags/<sha> --jq '.object.sha'`) | 40-char SHA |
| Latest claude-code CLI version | `npm view @anthropic-ai/claude-code version` | semver string |
| Latest sf CLI version | `npm view @salesforce/cli version` | semver string |
| YAML sanity | visual diff + `git diff` | only intended lines changed |
| Full local gate | `bash scripts/validate.sh` | exit 0 (workflows aren't validated by it, but ensures nothing else broke) |

## Scope

**In scope**:
- `.github/workflows/behavioral-tests.yml`
- `.github/workflows/jwt-validity-probe.yml`
- `.github/workflows/validate-plugin.yml` (uses: pins only)
- `.github/dependabot.yml` (add/extend `github-actions` ecosystem stanza if absent — read it first; it exists and mentions pip/uv policy)
- `plans/README.md` (status row)

**Out of scope**:
- The secret values themselves (no rotation implied — nothing leaked).
- `jwt-validity-probe.yml`'s auth-file handling and Linear issue-filing logic.
- Any workflow logic/step reordering beyond pinning and retention.
- `scripts/test-behavioral.sh` internals (transcript serialization is used by
  the scoring job; redaction there is a maintainer call — flagged in
  Maintenance notes, not done here).

## Git workflow

- **Bare-root repo**: `git worktree add <path> -b fix/pin-ci-supply-chain origin/main`.
- Conventional commit, e.g. `fix(ci): SHA-pin actions + pin npm CLIs in secret-bearing workflows; cap eval-artifact retention`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Pin all `uses:` references to full commit SHAs

For each distinct action (`actions/checkout@v4`, `actions/upload-artifact@v4`,
`actions/download-artifact@v4`): resolve the current v4 tag SHA (command
above), then replace every occurrence across the three workflow files with
`uses: actions/checkout@<40-char-sha> # v4` (keep the human-readable version
as a trailing comment — this is the convention Dependabot understands and
updates).

**Verify**: `grep -rn "uses: actions/" .github/workflows/ | grep -v "# v"` →
no output (every uses-line pinned + commented).

### Step 2: Pin the npm-installed CLIs

- `behavioral-tests.yml:33` → `npm install -g @anthropic-ai/claude-code@<exact-version>` (resolve current with `npm view`).
- `jwt-validity-probe.yml:30` → `npm install -g @salesforce/cli@<exact-version>`.
Add a one-line comment above each: bump deliberately; Dependabot does not
track `npm -g` in workflows.

**Verify**: `grep -n "npm install -g" .github/workflows/*.yml` → both lines
show `@<x.y.z>`.

### Step 3: Cap artifact retention

In `behavioral-tests.yml`, change both `retention-days: 90` (lines ~58 and
~85) to `retention-days: 14`, with a comment: transcripts of model output —
keep only long enough for the twice-weekly debrief cycle.

**Verify**: `grep -n "retention-days" .github/workflows/behavioral-tests.yml`
→ two lines, both `14`.

### Step 4: Update the eval model ID

`behavioral-tests.yml:22`: `EVALS_MODEL: "claude-sonnet-4-6"` is a superseded
model generation; scheduled runs will break silently when it's retired.
Change to `claude-sonnet-5` (current Sonnet line). Then check the default in
`scripts/test-behavioral.sh` (grep `sonnet` / `EVALS_MODEL`) — if the script
hardcodes a fallback model ID, update it to the same value so CI and local
agree. Do NOT touch `plugins/marketing/skills/icp-scoring/evals/evals.json`
(plugin-owned eval config; bumping it requires a plugin version bump — out of
scope, flagged in Maintenance notes).

**Verify**: `grep -rn "claude-sonnet-4-6" .github/ scripts/` → no output.

### Step 5: Dependabot coverage for actions

Read `.github/dependabot.yml`. If it lacks a `package-ecosystem: github-actions`
stanza, add one (weekly). If it exists, no change.

**Verify**: `grep -n "github-actions" .github/dependabot.yml` → ≥1 hit.

### Step 6: Full gate + commit

`bash scripts/validate.sh` → exit 0 (unrelated to workflows but confirms clean
tree). Commit.

## Test plan

No test framework applies to workflow YAML in this repo. The machine checks
are the greps in each step plus (post-merge, operator-observed) one green run
of each workflow — note in your report that `behavioral-tests.yml` and
`jwt-validity-probe.yml` are schedule/dispatch-only, so a manual
`workflow_dispatch` trigger after merge is the real end-to-end verification;
you cannot do it from the worktree.

## Done criteria

- [ ] Every `uses:` in `.github/workflows/` is a 40-char SHA with `# vN` comment
- [ ] Both `npm install -g` lines carry exact versions
- [ ] Both retention-days are 14
- [ ] `claude-sonnet-4-6` absent from `.github/` and `scripts/`
- [ ] Dependabot tracks github-actions
- [ ] `git status` — only in-scope files changed
- [ ] `plans/README.md` status row updated; report flags the post-merge dispatch check

## STOP conditions

Stop and report back (do not improvise) if:

- `gh api` can't resolve a tag→SHA (network/auth) — do not guess SHAs from
  memory or the internet; report instead.
- `npm view` reports a claude-code or sf-cli major version that differs from
  what the workflow last ran (a major bump may change CLI flags — flag it
  rather than pin blindly; suggest pinning the last-known-good major's latest).
- `claude-sonnet-5` seems wrong at execution time (e.g. the scoring script
  documents a model-family constraint) — report options rather than choosing.
- Plan 002 landed first and the `validate` job steps moved — pin whatever
  `uses:` lines exist; if any step disappeared entirely, note it and continue.

## Maintenance notes

- Deferred, flagged for the maintainer: (a) whether
  `scripts/test-behavioral.sh` should redact/turncate model transcripts before
  artifact upload (SEC-04's residual); (b)
  `plugins/marketing/skills/icp-scoring/evals/evals.json` still references the
  old model ID — needs a marketing-plugin patch bump in the same commit per
  repo rule; (c) rotate the `ANTHROPIC_API_KEY` / `SFDX_AUTH_URL_PROD` secrets
  on normal schedule — nothing here leaked them.
- Reviewers on future workflow PRs should reject unpinned `uses:` tags and
  unpinned `npm install -g` — this plan sets that convention.
