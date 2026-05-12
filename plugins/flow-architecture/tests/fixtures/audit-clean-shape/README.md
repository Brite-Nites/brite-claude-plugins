# audit-clean-shape fixture

Synthetic, complete-and-clean FDA shape for BC-7059's `/flow:audit` smoke test positive-path coverage. Represents a successful retrofit project at end-of-Phase-8 (status=completed breadcrumb).

## Layout

```
.flow/config.json                                   # Q12.4 bootstrap config (v1 fields)
docs/plans/.flow-phase-state.json                   # status=completed breadcrumb (Q31)
docs/product/intent.md                              # Q41 — 6 substantive sections + ## L1 review summary
docs/product/master-flow-inventory.md               # 2 domains × 3 sub-flows
docs/product/journeys/{TEAM,SHIP}.md                # Q26 journey docs
docs/product/flows/{TEAM,SHIP}/<flow-id>.md         # Q23 story docs (×6 total)
docs/product/flows/INDEX.md                         # Q18 regen output, generated_at newer than breadcrumb run_started_at
scripts/verify-docs.sh                              # Stub returning exit 0 (Phase A pass)
```

## Gate coverage (Phase B subset; what the smoke test exercises)

- `preflight-complete` — `.flow/config.json` exists with v1 fields → PASS
- `intent-exists` — `intent.md` exists with Q41 sections + ## L1 summary → PASS
- `inventory-complete` — `master-flow-inventory.md` has 2 domain sections → PASS
- `story-docs-complete` (per domain) — 3 story docs per domain present → PASS
- `journey-complete` (per domain) — journey docs present → PASS
- `index-complete` — `INDEX.md generated_at >= breadcrumb run_started_at` → PASS
- Per-flow [Story] front-matter / job-story / Gherkin / QA → PASS
- Per-flow `children.{story,engineering,design,qa,docs}` populated → PASS

Out of scope (skipped-with-reason): Phase A `verify-docs.sh` deep coverage, Phase C Linear-MCP state checks, L4 plan-X review coverage.
