# BC-7059 — `/flow:audit` smoke-test fixtures (clean + broken shapes)

> Source-of-truth: BC-7059 Linear issue body. Q38 sub-decision 6 exit-code contract (0/1/2/64) confirmed at `plugins/flow-architecture/commands/audit.md:286-294`. Canonical 35-gate registry at `plugins/flow-architecture/skills/_shared/artifact-gate-pattern.md`. Re-address note honored: exit-code contract verified.

## Scope

Reusable fixture pair under `plugins/flow-architecture/tests/fixtures/` plus a deterministic bash smoke test. The smoke test exercises the **Phase B subset** of `/flow:audit` (filesystem-only gates) since `/flow:audit` is an LLM slash command — not a directly bash-invocable runner. The vslice-greenfield precedent (`run-greenfield-vslice.sh`) establishes this pattern: test the deterministic surface, skip-with-reason for LLM-runner / Linear-MCP parts. Fixtures are reusable by any future audit harness (LLM-driven dogfood or v1.1 headless runner).

## Tasks

### T1 — Author `audit-clean-shape` fixture

Full FDA shape representing a successful retrofit:

- `.flow/config.json` — v1 fields per Q12.4 (linear_project_id, linear_project_name, linear_team_key, fda_first_setup_at, fda_plugin_version).
- `docs/product/intent.md` — 6 substantive front-matter fields + 7 sections per Q41 (Mission / Problem we're solving / Target users / Success criteria / Out of scope / Constraints + `## L1 review summary`).
- `docs/product/master-flow-inventory.md` — 2 domain sections × 3 sub-flows each (TEAM-01/02/03, SHIP-01/02/03), table rows with `flow_id` columns matching the story-doc filenames.
- `docs/product/flows/TEAM/TEAM-01.md`, `TEAM-02.md`, `TEAM-03.md` — story docs with full Q23 front-matter (`flow_id`, `status: shipped`, `qa_status: signed-off`, `qa_last_signed_off`, `children.{story,engineering,design,qa,docs}`, `figma`, `user_docs_url`); body has the `> **When** … **I want to** … **so I can**` job-story sentence and 3-5 Gherkin `Scenario:` blocks.
- `docs/product/flows/SHIP/SHIP-01.md`, `SHIP-02.md`, `SHIP-03.md` — same shape.
- `docs/product/journeys/TEAM.md`, `SHIP.md` — Q26 journey docs.
- `docs/product/flows/INDEX.md` — `generated_at:` newer than the breadcrumb's `run_started_at`, Status column matches story-doc front-matter `status`.
- `docs/plans/.flow-phase-state.json` — `status: "completed"`, `run_started_at` older than INDEX `generated_at`.
- Stub `scripts/verify-docs.sh` — exits 0 (Phase A pass).

### T2 — Author `audit-broken-shape` fixture

Same shape as clean but with **three deliberate violations** (filesystem-side substitutes for the issue's Phase C violation, since Linear-state isn't reachable from a bash test):

1. **Missing flow story doc** — `TEAM-03.md` absent → `story-docs-complete` (TEAM) hard-fails (inventory advertises 3 flows but only 2 story docs exist). Note: `inventory-story-doc-id-match` does NOT fail here — that gate iterates EXISTING story docs and verifies each has an inventory row; with TEAM-03.md absent, the orphan inventory row goes uniterated. Reverse-direction "every inventory row has a story doc" is exactly the `story-docs-complete` gate.
2. **INDEX.md out-of-sync** — `generated_at` older than breadcrumb `run_started_at` → `index-complete` hard-fail.
3. **Missing `children.engineering` front-matter** on `SHIP-01.md` → `eng-children-engineering-populated` hard-fail (filesystem substitute for "parent issue without discipline-children chain").

### T3 — Author `run-audit-smoke.sh`

Bash 3.2 compatible (no associative arrays, no `mapfile`, no `${var,,}`). Sections:

1. Fixture-shape preflight — `test -d` + `test -f` per spec AC #1 / #2.
2. Clean-fixture Phase B-equivalent gate-runner — assert every enumerated gate reports `PASS` (would yield `/flow:audit` exit 0). Counters: `CLEAN_PASS / CLEAN_FAIL`.
3. Broken-fixture Phase B-equivalent gate-runner — assert the **three named gates** above hard-fail and all others pass (would yield `/flow:audit` exit 1). Verify named-gate fails are recognized — not bucketed as `UNCATEGORIZED-GATE-FAIL`.
4. **`UNCATEGORIZED-GATE-FAIL` assertion** — script contains the literal string (AC #5) AND asserts no evaluated gate name falls into the uncategorized bucket on either fixture.
5. Skip-with-reason for Phase A `verify-docs.sh` per-doc parsing (no real verifier in fixture; out-of-scope per issue) and Phase C Linear-MCP gates (no Linear access from CI).

Exit 0 on all assertions pass; exit 1 on any failure.

### T4 — Wire `audit-smoke-test` CI job

Add to `.github/workflows/validate-plugin.yml`:

```
audit-smoke-test:
  runs-on: ubuntu-latest
  needs: validate
  timeout-minutes: 3
  continue-on-error: true  # advisory per BC-7059 spec
  permissions:
    contents: read
  steps:
    - uses: actions/checkout@v4
    - name: Run /flow:audit smoke test (BC-7059)
      run: bash plugins/flow-architecture/tests/run-audit-smoke.sh
```

Job name `audit-smoke-test` matches AC #4 verbatim.

### T5 — Bump plugin version 0.2.19 → 0.2.20

- `plugins/flow-architecture/.claude-plugin/plugin.json` → `0.2.20`
- `.claude-plugin/marketplace.json` entry → `0.2.20`

Same-commit bump per BC-6000 cache-propagation rule.

### T6 — Local validate + smoke run

- `./scripts/validate.sh` — confirm no plugin-validation regression.
- `bash plugins/flow-architecture/tests/run-audit-smoke.sh` — confirm exit 0.
- `bash ./scripts/check-guardrails.sh --claude-md plugins/flow-architecture/CLAUDE.md` — confirm no plugin-CLAUDE.md regression.

## Acceptance criteria mapping

| AC# | AC text | Where satisfied |
|---|---|---|
| 1 | `test -d` for `audit-clean-shape` + `audit-broken-shape` | T1 + T2 (smoke test re-asserts in T3 Section 1) |
| 2 | `test -f run-audit-smoke.sh` | T3 |
| 3 | `./run-audit-smoke.sh` exits 0 | T3 + T6 |
| 4 | CI job `audit-smoke-test` runs on PR to main | T4 |
| 5 | `grep -q "UNCATEGORIZED-GATE-FAIL"` succeeds against script | T3 (literal string in body) |

## Out of scope (per issue body)

- Exhaustive per-gate coverage of all 35 Q29 gates (parking-lot #52-#55).
- Fixture for retrofit / incremental-add modes (covered by BC-6998 retrofit + greenfield v-slice respectively).
- Fixture for resume-mode breadcrumb recovery (v1.1 candidate).
