# audit-broken-shape fixture

Synthetic FDA shape with **three deliberate violations** for BC-7059's `/flow:audit` smoke test negative-path coverage. Mirrors `audit-clean-shape` exactly except for the violations enumerated below.

| # | Violation | Affected gate |
|---|---|---|
| 1 | `docs/product/flows/TEAM/TEAM-03.md` is missing (still listed in `master-flow-inventory.md`). | `story-docs-complete` (TEAM domain) hard-fails: inventory advertises 3 TEAM flows but only 2 story docs exist. |
| 2 | `docs/product/flows/INDEX.md` `generated_at` is older than `docs/plans/.flow-phase-state.json` `run_started_at`. | `index-complete` hard-fails: INDEX was not regenerated as part of the most recent orchestrator run. |
| 3 | `docs/product/flows/SHIP/SHIP-01.md` front-matter omits `children.engineering`. | `eng-children-engineering-populated` hard-fails. Filesystem-side substitute for the issue's "parent issue without discipline-children chain" violation, which is a Phase C Linear-MCP check unreachable from a bash test. |

The smoke test (`run-audit-smoke.sh`) asserts these three named gates fail and no other gate hits the `UNCATEGORIZED-GATE-FAIL` bucket.
