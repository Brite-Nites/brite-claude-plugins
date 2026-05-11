# BC-7057 — vertical-slice integration test (greenfield synthetic fixture)

> Linear: [BC-7057](https://linear.app/brite-nites/issue/BC-7057). Branch: `worktree-bc-7057-vslice-greenfield`. Plan author: Holden, 2026-05-11.

## Context

BC-7057 is the v-slice integration test that proves `/flow:start-project` works end-to-end against a small synthetic fixture **before** the Brand Hub dogfood (BC-6998 — v1.0 acceptance gate). It is a hard pre-flight gate for BC-6998 per that issue's spec language.

**The gap between BC-7057's assumption and today's state:** the BC-7057 spec lists `BC-6959` (9 sub-skills) as a dependency and assumes those sub-skills are shipped before this test runs. Today only `flow-preflight` is shipped; the other 8 sub-skills (`/flow:office-hours`, `flow-inventory-interview`, `flow-linear-scaffold`, `flow-doc-author`, `flow-journey-author`, `flow-regen-index`, `flow-sandbox-scaffold`, `flow-legacy-cross-reference`) do not exist on disk. Running `/flow:start-project` against the fixture today would halt at Phase 2 because `/flow:office-hours` is missing.

**The honest read:** the v-slice harness has standalone value before BC-6959 lands. It de-risks helper-script behavior under fixture conditions, establishes the fixture pattern future sub-skill PRs will extend, and wires the `vslice-greenfield` CI job so each sub-skill PR gets advisory pass/fail signal as it lands. Each future sub-skill PR adds its own assertion to the harness.

**Strategy: build the harness now, scope assertions to what's shipped today, extend per sub-skill PR.** Skip-with-reason markers for Phases 2-8 keep CI green while honestly documenting the missing surface. The vslice-report.md tracks the matrix of which Q8 sub-criteria the harness covers per sub-skill landing.

## Goal

Ship the v-slice test infrastructure (fixture + harness script + CI job + report) so that:

1. `test -d plugins/flow-architecture/tests/fixtures/synthetic-greenfield` succeeds.
2. `test -f plugins/flow-architecture/tests/run-greenfield-vslice.sh` succeeds.
3. `./plugins/flow-architecture/tests/run-greenfield-vslice.sh` exits 0 on a clean run today.
4. CI job named `vslice-greenfield` runs on PR to main.
5. `plugins/flow-architecture/tests/vslice-report.md` documents scope today + pending coverage + extension protocol.

Per BC-7057 spec acceptance criteria. Phase 2-8 deep assertions arrive as BC-6959 sub-skills land.

## Approach summary

**Build now, extend later.** The harness today tests the four FDA helper scripts (`flow-context-load.sh`, `flow-detect-fda-shape.sh`, `flow-detect-mode.sh`, `flow-resume-breadcrumb.sh`) end-to-end against a synthetic fixture project — these are the deterministic core of Phase 1. The LLM-dispatched orchestrator/sub-skill layer is tested through the `behavioral-tests.yml` pattern later (when sub-skills exist).

**Why helpers-not-orchestrator today:** `/flow:start-project` is a markdown command file that an LLM session executes — it can't be invoked from a bash CI script without a Claude Code runner. The `behavioral-tests.yml` workflow uses `claude -p ...` with budget gating (~$2-5/run, 2x/week schedule). A PR-on-every-push test cannot use that pattern. The helpers cover Q31.5 atomic-rename, Q12 mode classification, Q12.5 preamble emission — all the deterministic core that LLM dispatch sits on top of.

**Sandbox Linear handling:** `.flow/config.json` carries stub UUIDs (`00000000-0000-0000-0000-000000000000`). The harness does NOT call Linear MCP. flow-preflight's Linear-MCP probe is bypassed by setting `LINEAR_ISSUE_COUNT=0` before invoking helpers and not running the SKILL.md body (which is LLM-only anyway). Hermetic CI; no live Linear writes.

**Plugin version bump per BC-6000 rule:** any edit under `plugins/flow-architecture/{commands,skills,agents,hooks}/**` requires a version bump in the same commit. This PR touches `plugins/flow-architecture/tests/**` + `.github/workflows/**` — strictly speaking BC-6000 applies to runtime-cached content (skills, commands, agents, hooks), not test infrastructure. Default position: bump plugin.json + marketplace.json 0.2.7 → 0.2.8 anyway for cache-invalidation safety; ack in commit message. If the user prefers no bump for test-only changes, we strip it.

## Critical files

**Create:**
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/package.json` — minimal npm package with `build`, `lint`, `test` scripts that exit 0 (no real code; just shape).
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/.flow/config.json` — pre-filled with stub UUIDs (`linear_project_id`, `linear_project_name=synthetic-greenfield-fixture`, `linear_team_key=BC`, `fda_first_setup_at`, `fda_plugin_version=0.2.8`).
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/README.md` — fixture shape (3 domains × ~5 sub-flows total) + invocation docs.
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/docs/plans/.gitkeep` — directory so breadcrumb test has a target dir.
- `plugins/flow-architecture/tests/run-greenfield-vslice.sh` — bash 3.2-compat harness (`set -euo pipefail`; empty-array guards per BC-6905 gotcha).
- `plugins/flow-architecture/tests/vslice-report.md` — scope today + extension protocol.

**Modify:**
- `.github/workflows/validate-plugin.yml` — add new job `vslice-greenfield` after the existing `validate` job. Runs on PR to main. `continue-on-error: true` per spec's "advisory" framing.
- `plugins/flow-architecture/.claude-plugin/plugin.json` — `version: "0.2.7"` → `"0.2.8"`.
- `.claude-plugin/marketplace.json` — matching flow-architecture entry → `0.2.8`.

**Reuse (read-only references):**
- `plugins/flow-architecture/scripts/flow-context-load.sh` — emits Q12.5 10-field preamble. Harness invokes + parses.
- `plugins/flow-architecture/scripts/flow-detect-fda-shape.sh` — probes `docs/product/` shape. Harness invokes + asserts greenfield response.
- `plugins/flow-architecture/scripts/flow-detect-mode.sh` — classifies mode. Harness invokes with `LINEAR_ISSUE_COUNT=0` + asserts `MODE=greenfield`.
- `plugins/flow-architecture/scripts/flow-resume-breadcrumb.sh` — `read` + `write` subcommands. Harness writes a Phase-1-complete breadcrumb + reads it back + asserts shape match.

## Tasks (atomic, ~5-15 min each)

### T1. Fixture skeleton

Files:
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/package.json`
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/.flow/config.json`
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/README.md`
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/docs/plans/.gitkeep`

`package.json` shape (matches BC-7057 spec's "minimal Brand-Hub-shape" hint):

```json
{
  "name": "synthetic-greenfield-fixture",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "build": "echo synthetic-build && exit 0",
    "lint": "echo synthetic-lint && exit 0",
    "test": "echo synthetic-test && exit 0"
  }
}
```

`.flow/config.json` shape (per flow-preflight Section 6 schema):

```json
{
  "version": "1",
  "linear_project_id": "00000000-0000-0000-0000-000000000000",
  "linear_project_name": "synthetic-greenfield-fixture",
  "linear_team_key": "BC",
  "fda_first_setup_at": "2026-05-11T00:00:00Z",
  "fda_plugin_version": "0.2.8"
}
```

`README.md` documents the planned 3-domain × 5-sub-flow shape (target inventory state once BC-6959 ships) — domain stubs are documentation-only for v0.2.8.

**Verify:** `test -d plugins/flow-architecture/tests/fixtures/synthetic-greenfield && test -f plugins/flow-architecture/tests/fixtures/synthetic-greenfield/.flow/config.json && python3 -m json.tool plugins/flow-architecture/tests/fixtures/synthetic-greenfield/.flow/config.json > /dev/null`.

### T2. Harness script

File: `plugins/flow-architecture/tests/run-greenfield-vslice.sh`

Structure (bash 3.2-compat; `set -euo pipefail`; empty-array guards per memory `gotcha`):

```bash
#!/usr/bin/env bash
# BC-7057 v-slice integration test: greenfield against synthetic fixture.
# Tests Phase 1 surface (helpers + breadcrumb round-trip + fixture shape) today.
# Phase 2-8 deep assertions arrive as BC-6959 sub-skills land — see vslice-report.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE="$SCRIPT_DIR/fixtures/synthetic-greenfield"

# Six assertion groups, exit non-zero on any failure.
# 1. Fixture shape: package.json/.flow/config.json/docs/plans/ exist + parse.
# 2. Helper: flow-detect-fda-shape.sh against fixture returns greenfield-shape.
# 3. Helper: flow-detect-mode.sh with LINEAR_ISSUE_COUNT=0 returns MODE=greenfield.
# 4. Helper: flow-context-load.sh emits all 10 Q12.5 preamble fields.
# 5. Helper: flow-resume-breadcrumb.sh write/read round-trip preserves shape.
# 6. Skip-with-reason: Phase 2-8 assertions deferred to BC-6959 landing PRs.
```

Each group prints a pass/fail line + summary. Exit 0 on all-pass + skip-with-reason; exit 1 on any hard failure.

**Verify locally:** `chmod +x plugins/flow-architecture/tests/run-greenfield-vslice.sh && ./plugins/flow-architecture/tests/run-greenfield-vslice.sh` — exits 0; visible output enumerates pass / skip status.

### T3. vslice-report.md

File: `plugins/flow-architecture/tests/vslice-report.md`

Sections:
- **Scope today (v0.2.8):** Phase 1 + fixture shape + helper round-trip — concrete assertions enumerated.
- **Pending coverage:** Matrix of Q8 sub-criteria × sub-skill PR landing. One row per missing sub-skill (8 rows): which assertions activate when each lands.
- **Extension protocol:** how each future sub-skill PR adds its assertion(s) to `run-greenfield-vslice.sh` + reduces the skip-with-reason list.
- **No findings today:** acceptance criterion satisfied via "no findings — Phase 1 helpers all pass under fixture conditions" attestation. Future runs may surface bugs; those file as separate issues per spec.

**Verify:** `test -f plugins/flow-architecture/tests/vslice-report.md && grep -c "^## " plugins/flow-architecture/tests/vslice-report.md` returns at least 4.

### T4. CI job wiring

File: `.github/workflows/validate-plugin.yml`

Add a new job `vslice-greenfield` after the existing `validate` job:

```yaml
  vslice-greenfield:
    runs-on: ubuntu-latest
    needs: validate
    timeout-minutes: 5
    continue-on-error: true
    steps:
      - uses: actions/checkout@v4
      - name: Run v-slice greenfield harness
        run: bash plugins/flow-architecture/tests/run-greenfield-vslice.sh
```

`continue-on-error: true` per BC-7057 spec "advisory job" framing — does NOT block PRs even if harness fails. `needs: validate` keeps the lint/structure check upstream.

**Verify:** `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate-plugin.yml'))"` parses cleanly (already guarded by the existing `validate` job, but worth re-checking after the diff).

### T5. Plugin version bump

Files:
- `plugins/flow-architecture/.claude-plugin/plugin.json` — `"version": "0.2.7"` → `"0.2.8"`.
- `.claude-plugin/marketplace.json` — flow-architecture entry version → `"0.2.8"`.

Both bumped in the same commit as the test/CI changes per BC-6000 rule.

**Verify:** `grep -c '"version": "0.2.8"' plugins/flow-architecture/.claude-plugin/plugin.json` returns 1; `grep "flow-architecture" .claude-plugin/marketplace.json` line shows 0.2.8.

### T6. Local verification

Run:
- `./scripts/validate.sh` — must exit 0 (catches plugin.json schema regressions + marketplace.json validity).
- `./plugins/flow-architecture/tests/run-greenfield-vslice.sh` — must exit 0.
- `./scripts/check-guardrails.sh --claude-md plugins/flow-architecture/CLAUDE.md` — must exit 0 (size + anti-slop on CLAUDE.md; new files don't trigger this but worth checking).
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate-plugin.yml'))"` — parses cleanly.

If any fail, fix root cause before commit.

## Verification (end-to-end)

After all tasks land:

1. **Fixture exists:** `test -d plugins/flow-architecture/tests/fixtures/synthetic-greenfield` exits 0.
2. **Script exists + executable:** `test -x plugins/flow-architecture/tests/run-greenfield-vslice.sh` exits 0.
3. **Script passes:** `./plugins/flow-architecture/tests/run-greenfield-vslice.sh` exits 0; stdout shows the 6 assertion groups with PASS/SKIP markers.
4. **CI job declared:** `grep -q "vslice-greenfield:" .github/workflows/validate-plugin.yml` exits 0.
5. **Report exists:** `test -f plugins/flow-architecture/tests/vslice-report.md` exits 0.
6. **Plugin validate clean:** `./scripts/validate.sh` exits 0.
7. **Version bumped:** flow-architecture plugin.json + marketplace.json both at 0.2.8.

After PR opens + CI runs, verify the `vslice-greenfield` GitHub Actions job appears and reports a status (advisory; non-blocking).

## Risks + open questions

- **R1 (low):** the harness today tests the helper layer but not LLM-dispatched orchestration. A future regression in the orchestrator markdown that doesn't break helpers would slip past until BC-6998 dogfood. Mitigation: vslice-report.md tracks the coverage matrix; each BC-6959 sub-skill PR extends harness assertions; behavioral-tests.yml is the deep-coverage runner.
- **R2 (low):** `continue-on-error: true` makes the CI job advisory. If the team expects a hard-blocking gate, the spec needs amendment. The BC-7057 spec text says "advisory job (so Phase 4 work continues even if v-slice surfaces issues)" — current direction matches.
- **OQ1:** should the harness's `flow-resume-breadcrumb.sh write/read` round-trip live in the fixture's `docs/plans/.flow-phase-state.json` (test ephemeral), and what's the cleanup contract — leave the file in place for inspection, or `rm -f` at end of run? **Default: clean up after success; leave in place on failure for inspection.**
- **OQ2:** does the version bump (T5) feel right for a test-only change? BC-6000 origin precedent is for plugin runtime files (skills/commands/agents/hooks); tests/CI strictly fall outside. **Default: bump anyway for safety; revisit at /workflows:review if user disagrees.**

## Out of scope

- Brand Hub dogfood (BC-6998) — separate v1.0 acceptance gate; this issue de-risks it.
- Retrofit-orchestrator v-slice — separate fixture would duplicate; Brand Hub dogfood covers retrofit.
- LLM-runner integration with `vslice-greenfield` — separate test category (`behavioral-tests.yml` pattern; budget-gated).
- v1.1 expanded test suite — parking lot #52-#55 territory.

## Done definition

All 5 BC-7057 acceptance criteria pass + worktree merged into main + `vslice-greenfield` CI job visible on next PR + vslice-report.md committed + plugin version at 0.2.8.

## See also

- BC-7057 Linear issue (this work).
- BC-6998 Linear issue (consumer; v1.0 acceptance gate).
- BC-6959 Linear issue (the 8 missing sub-skills; harness extends as these land).
- `plugins/flow-architecture/docs/design-rationale/brand-hub-preflight-findings.md` — BC-7058 sibling pre-flight doc.
- `plugins/flow-architecture/scripts/` — 4 FDA helper scripts the harness exercises.
- `.github/workflows/validate-plugin.yml` — host workflow for the new CI job.
- `.github/workflows/behavioral-tests.yml` — separate LLM-runner test category (out of scope for this issue).
