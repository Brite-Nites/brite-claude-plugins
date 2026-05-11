# BC-7057 v-slice greenfield report

> Initial scope shipped at plugin v0.2.8. Mode: "no findings — Phase 1 helpers all pass under fixture conditions." Extended per sub-skill PR as BC-6959 lands.

## Scope today (v0.2.8)

`run-greenfield-vslice.sh` exercises **Phase 1 surface only** — the four FDA helper scripts under `plugins/flow-architecture/scripts/` against the `tests/fixtures/synthetic-greenfield/` fixture. Six assertion groups, 37 hard assertions:

| Group | Asserts |
|---|---|
| 1. Fixture shape | Fixture dir + `package.json` + `.flow/config.json` (parses) + `docs/plans/` + `npm run build` exits 0 |
| 2. `flow-detect-fda-shape.sh` | Exits 0; emits 5 `EXISTS=no` lines for a fresh greenfield fixture (INTENT / INVENTORY / FLOWS_DIR / JOURNEYS_DIR / BREADCRUMB) |
| 3. `flow-detect-mode.sh` | `MODE=greenfield` with `LINEAR_ISSUE_COUNT=0`; `MODE=retrofit` with `LINEAR_ISSUE_COUNT=10` (Q36.3 step 4 heuristic) |
| 4. `flow-context-load.sh` | Exits 0; emits exactly 10-line Q12.5 preamble with all canonical fields populated correctly |
| 5. `flow-resume-breadcrumb.sh` | Write/read round-trip preserves `STATUS=in_flight` + `STALE=no`; subsequent shape probe flips `BREADCRUMB_EXISTS=yes`; subsequent mode probe returns `MODE=resume` |
| 6. Phase 2-8 skip-with-reason | 8 skip lines documenting pending coverage (see § Pending coverage matrix) |

CI job: `vslice-greenfield` in `.github/workflows/validate-plugin.yml` (advisory; `continue-on-error: true` per BC-7057 spec "advisory job" framing). Runs on every PR to `main`.

## Pending coverage matrix

One row per missing surface. Each future PR adds its assertion(s) to `run-greenfield-vslice.sh` and removes the matching `skip()` line.

| Surface | Q8 sub-criterion | Lands with | Assertion to add |
|---|---|---|---|
| `/flow:office-hours` (Q42) | 3 (intent.md schema) | BC-6959 child (TBD) | Run command via LLM-runner; assert `docs/product/intent.md` exists + has 7 required Q41 sections + `## L1 review summary` populated |
| `flow-inventory-interview` (Q19) | 3 (inventory schema) | BC-6959 child (TBD) | Run skill; assert `docs/product/master-flow-inventory.md` exists with 3 domains × 5 sub-flows + L2 stash captured |
| `flow-linear-scaffold` (Q13) | 6 (Linear chain) | BC-6959 child (TBD) | Mock Linear MCP; assert milestone + parent + 5N children per sub-flow + `## L3 review summary` populated on parent issues |
| `flow-doc-author` (Q15) | 3 (per-flow story doc) | BC-6959 child (TBD) | Run skill; assert 13 story docs at `docs/product/flows/<domain>/<flow-id>.md` |
| `flow-journey-author` (Q16) | 3 (journey doc) | BC-6959 child (TBD) | Run skill; assert 3 journey docs at `docs/product/journeys/<domain>.md` with `## L2 review summary` populated |
| `flow-regen-index` (Q18) | 3 (INDEX schema) | BC-6959 child (TBD) | Run skill; assert `docs/product/flows/INDEX.md` regenerated + idempotent across two consecutive runs |
| Phase 8 terminator | 1, 2 (8 phases + breadcrumb) | BC-6962 follow-up | Assert breadcrumb `status=completed` + 8 `completed_phases` after end-to-end run |
| Gates G1-G4 | 2 (4 gates fire) | LLM-runner category | Move to `behavioral-tests.yml`; not headlessly testable in this category — `AskUserQuestion` is LLM-only |

## Extension protocol

Each future PR that lands a sub-skill (or a follow-up that closes a Phase 2-8 surface):

1. Add a `pass` line to the relevant section of `run-greenfield-vslice.sh` (or a whole new section if the surface is large).
2. Remove the matching `skip()` line from Section 6.
3. Update this `vslice-report.md` matrix row from "pending" to "covered" + add a row to the next section.
4. Bump `plugins/flow-architecture/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` per BC-6000 same-commit rule if the harness change touches `plugins/flow-architecture/**` runtime files (test-only changes are advisory).

If the new surface requires LLM dispatch to test end-to-end, route through `behavioral-tests.yml` (budget-gated weekly schedule, ~$2-5/run) instead of extending this script. Keep `run-greenfield-vslice.sh` cheap-and-fast for every-PR signal.

## No findings (v0.2.8 initial run)

All 37 hard assertions pass under the synthetic fixture as of 2026-05-11. No bugs surfaced in any of the four helper scripts under the fixture conditions tested.

Per BC-7057 acceptance criterion 5: this report constitutes the formal "no findings" attestation. Future runs may surface regressions — those file as separate Linear issues in the `flow-architecture` Linear project.

## Coverage history

| Date | Plugin version | Covered | Pending |
|---|---|---|---|
| 2026-05-11 | 0.2.8 | Phase 1 (37 assertions across helpers + breadcrumb round-trip) | Phases 2-8 (8 skips) |

Append new rows as sub-skill PRs land.

## See also

- `plugins/flow-architecture/tests/run-greenfield-vslice.sh` — the harness this report tracks.
- `plugins/flow-architecture/tests/fixtures/synthetic-greenfield/README.md` — fixture shape + 3-domain × 5-sub-flow target inventory.
- [BC-7057](https://linear.app/brite-nites/issue/BC-7057) — issue spec (this work).
- [BC-6959](https://linear.app/brite-nites/issue/BC-6959) — parent for the 9 sub-skills; harness extends as children land.
- [BC-6998](https://linear.app/brite-nites/issue/BC-6998) — Brand Hub dogfood (v1.0 acceptance gate); this harness is its hard pre-flight gate.
- `.github/workflows/validate-plugin.yml` — host CI workflow for the `vslice-greenfield` job.
- `.github/workflows/behavioral-tests.yml` — separate LLM-runner test category for surfaces that need orchestrator dispatch.
