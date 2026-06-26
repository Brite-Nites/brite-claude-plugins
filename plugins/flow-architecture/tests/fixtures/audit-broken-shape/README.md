# audit-broken-shape fixture

Synthetic FDA shape with **three deliberate structural violations** for BC-7059's `/flow:audit` smoke test negative-path coverage. Mirrors `audit-clean-shape` exactly except for the violations enumerated below. (All story + journey docs carry the full canonical frontmatter — BC-13915 hardcoded the full-canon floor — so the only frontmatter-completeness failure is the one caused by violation 3 below.)

| # | Violation | Affected gate(s) |
|---|---|---|
| 1 | `docs/product/flows/TEAM/TEAM-03.md` is missing (still listed in `master-flow-inventory.md`). | `story-docs-complete` (TEAM domain) hard-fails: inventory advertises 3 TEAM flows but only 2 story docs exist. |
| 2 | `docs/product/flows/INDEX.md` `generated_at` is older than `docs/plans/.flow-phase-state.json` `run_started_at`. | `index-complete` hard-fails: INDEX was not regenerated as part of the most recent orchestrator run. |
| 3 | `docs/product/flows/SHIP/SHIP-01.md` front-matter omits `children.engineering`. | `eng-children-engineering-populated` hard-fails. **AND** `story-front-matter-populated` hard-fails — since BC-13915 hardcoded the full-canon floor, `children.engineering` is a `STORY_CANON` key, so this one structural omission trips both gates. (Filesystem-side substitute for the issue's "parent issue without discipline-children chain" violation, which is a Phase C Linear-MCP check unreachable from a bash test.) |

So the 3 deliberate violations produce **4 hard-gate FAILs** (violation 3 trips two gates). The smoke test (`run-audit-smoke.sh`) and the unit test (`test_build_audit_report.sh`) assert exactly these four named gates fail and no other gate hits the `UNCATEGORIZED-GATE-FAIL` bucket.
