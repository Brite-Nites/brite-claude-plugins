# Brand Hub dogfood findings

> Iteration log + acceptance-criteria verdict for [BC-6998](https://linear.app/brite-nites/issue/BC-6998), the v1.0 acceptance gate for the flow-architecture plugin. Companion to [`brand-hub-preflight-findings.md`](brand-hub-preflight-findings.md) (BC-7058). Skeleton written 2026-05-12 to satisfy AC7 ("Failure modes documented at `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md`"). Body populated as each iteration progresses.

## Run context

| Field | Value |
|---|---|
| Plugin version at iter-1 start | `0.2.22` |
| Brand Hub repo | `/Users/holdenhalford/projects/work/brite-nites/brand-hub` |
| Brand Hub commit at iter-1 start | _populated at iter-1 Phase 1 entry_ |
| Brand Hub Linear project | slug `brand-hub-beb1f3e9de7f` / id `61d8cd9b-67ba-4e62-b474-81d9ccf36d31` |
| Brand Hub release target | 2026-05-19 |

## Iteration log

Each row records one `/flow:retrofit-project` invocation through the 9-phase sequence. Cap = 2 iterations per Q40 sub-decision 6; iter 3+ requires Q56+ Q-lock escalation.

### Iteration 1 — _in progress_

Entry conditions: Brand Hub FDA-blank (verified 2026-05-12 via 5 filesystem `test -f` probes — all 5 absent).

| Phase | Started | Exit | Reason | Artifacts |
|---|---|---|---|---|
| 1 — preflight + bootstrap | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 2 — office-hours (fires; intent.md absent) | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 3 render — cross-reference doc draft | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 3 execute — Linear milestone appendix | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 4 — inventory codebase-scan | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 5 — Linear scaffold (per-domain inner loop) | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 6 — story-doc author (batched) | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 7 — journey-doc author (batched) | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 8 — INDEX regen | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 9 — complete | _TBD_ | _TBD_ | _TBD_ | _TBD_ |

### Iteration 2 — _not yet started_

Triggered only if Iter 1 leaves any AC un-PASSed.

## Acceptance criteria verdict

Q8 7 sub-criteria + 4 quality gates added 2026-05-10. Verdict populated post-execution.

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| AC1 | All 9 retrofit phases complete without unrecovered failures | _TBD_ | iter log above |
| AC2 | 5 user-confirmation gates fire as expected | _TBD_ | iter log above |
| AC3 | Outputs match locked schemas (intent / inventory / per-flow / journeys / INDEX / Linear chain / cross-ref) | _TBD_ | `test -f` checks below |
| AC4 | `/flow:audit` against Brand Hub repo exits `0` | _TBD_ | run from `brand-hub/` |
| AC5 | `npm run build && npm run lint && npm test` on Brand Hub exit `0` | _TBD_ | run from `brand-hub/`; BC-7058 baselined all three at 0 |
| AC6 | Linear FDA-shaped milestones + 5N children created cleanly | _TBD_ | MCP query against Brand Hub project |
| AC7 | `test -f plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` succeeds | PASS | this file exists |
| Q1 | Pre-flight gate: BC-7058 Done + 0 NEEDS-FIX in pre-flight findings | _TBD_ | confirm BC-7058 Linear state |
| Q2 | V-slice gate: BC-7057 Done + `vslice-greenfield` CI green | _TBD_ | confirm BC-7057 Linear state + CI |
| Q3 | Audit-smoke-test gate (advisory): BC-7059 Done | _TBD_ | confirm BC-7059 Linear state |
| Q4 | Iteration count ≤ 2 | _TBD_ | this section's row count |

Five separate `test -f` checks (per AC body literal):

```bash
cd /Users/holdenhalford/projects/work/brite-nites/brand-hub
test -f docs/product/intent.md                                          && echo intent OK
test -f docs/product/master-flow-inventory.md                            && echo inventory OK
test -f docs/product/flows/INDEX.md                                      && echo index OK
find docs/product/flows -mindepth 2 -name "*.md" | head -1                # at least one per-sub-flow story doc
find docs/product/journeys -name "*.md" | head -1                         # at least one journey doc
```

## Bugs surfaced

Plugin-side bugs caught during dogfood. Each gets a separate BC-issue with `flow-architecture` label (NOT BC-6998 blocker per in-flight protocol). Each row captures the BC-issue id, severity verdict (P1 / P2 / P3), and the phase that surfaced it.

| BC-issue | Severity | Phase | One-line summary |
|---|---|---|---|
| _none yet_ | | | |

## Memory drift caught

Drift between memory snapshots / design-rationale prose and reality observed at dogfood time. Inline corrections rolled into this doc + linked memory file updates noted here.

| Drift | Memory line / file | Reality | Fix |
|---|---|---|---|
| _none yet_ | | | |

## Cross-reference

- [BC-6998](https://linear.app/brite-nites/issue/BC-6998) — this milestone.
- [BC-7058](https://linear.app/brite-nites/issue/BC-7058) — pre-flight audit shipped 2026-05-11.
- [`brand-hub-preflight-findings.md`](brand-hub-preflight-findings.md) — pre-flight findings, sibling artifact.
- [`fda-plugin-drafter-e-revision-2.md:1117-1133`](fda-plugin-drafter-e-revision-2.md) — Q8 7 sub-criteria source-of-truth.
- [`fda-plugin-architecture-overview.md`](fda-plugin-architecture-overview.md) § 7 — outer-loop Phase 6 / Q40 release sequence step 5 framing.
- BC-6999 (downstream) — v1.0 release + CDR-023 Proposed → Accepted; blocked by BC-6998.
