# BC-6998 plan — Brand Hub dogfood (FDA plugin v1.0 acceptance gate)

> Linear: [BC-6998](https://linear.app/brite-nites/issue/BC-6998). Milestone: `Flow-Driven Architecture Plugin v1.0` (`0bf7b980-5d7c-4a18-a2ca-3af58df4a8f8`). Status entering plan: Backlog. Plugin version entering dogfood: `0.2.22`.

## Goal

Run `/flow:retrofit-project` end-to-end against Brand Hub. Clean execution per Q8's 7 sub-criteria + the 4 added quality gates flips the FDA plugin to `1.0.0` (Phase 6 release tracked at BC-6999).

## Scope boundary

- **Brand Hub repo writes**: `.flow/config.json`, `docs/product/{intent.md, master-flow-inventory.md, flows/<domain>/<flow-id>.md, journeys/<domain>.md, flows/INDEX.md}`, `docs/plans/.flow-phase-state.json`, `docs/plans/brand-hub-cross-reference.md` (transient).
- **Brand Hub Linear (project `61d8cd9b-67ba-4e62-b474-81d9ccf36d31` / slug `brand-hub-beb1f3e9de7f`)**: 26 legacy milestone descriptions get a `## FDA migration` appendix (Q14 markers); ~10 new FDA-shaped milestones + ~50 sub-flow parents + ~250 discipline children created per Phase 5 inner loop (counts emerge from Q11 runtime scan — NOT pinned).
- **Plugins repo (this worktree)**: `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` (AC7 artifact), plus any plugin-side bug-fix follow-ups filed as separate BC-issues (in-flight protocol — NOT BC-6998 blockers).

## Pre-flight readiness (verified 2026-05-12)

- 22 hard blockers + 4 advisory (BC-7057/58/59/60/61) all have commits in `main`. Plugin surface: 15 commands / 11 skills / 12 agents.
- Brand Hub repo at `/Users/holdenhalford/projects/work/brite-nites/brand-hub`: clean working tree, on `main`, synced with origin. All 5 FDA artifact filesystem checks confirm absence (greenfield-for-docs per `CLAUDE.md` pre-existing-vs-FDA-output mapping). 5 PRDs in `.context/prd/` available for office-hours pre-fill.
- BC-7058 pre-flight findings ([`brand-hub-preflight-findings.md`](../../plugins/flow-architecture/docs/design-rationale/brand-hub-preflight-findings.md)) verdict: 3 READY · 4 DEFERRED · 0 NEEDS-FIX. R1–R5 risks captured with inline mitigations; R2 (target 2026-05-19, 7 days out) is the only Medium that touches scheduling.

## Execution strategy

Single-session attempt for Iteration 1. The orchestrator's own G1–G5 gates pace human review; this plan does not re-impose external pauses. If a phase fails or the session bounds (context, time, attention), the breadcrumb at `docs/plans/.flow-phase-state.json` (Brand Hub repo) supports clean resume per the orchestrator's Resume contract.

**Iteration cap**: 2 per AC. Iter 1 surfaces bugs and gets to the first clean run that satisfies the 7 sub-criteria. Iter 2 (if needed) closes the remaining gaps. Iter 3+ requires Q56+ Q-lock escalation per Q40 sub-decision 6.

## Phase-by-phase runbook

| Phase | Sub-skill / target | Wall est. | Output |
|---|---|---|---|
| 1 | `flow-preflight` (Q12 + Q36 bootstrap) | ~30s + interactive | `.flow/config.json` written; mode classified `retrofit`; preamble emitted; G1 confirms |
| 2 | `/flow:office-hours` (Q42 — fires; intent.md absent) | ~5–10 min | `docs/product/intent.md` with `## L1 review summary`; G2 confirms |
| 3 (render) | `flow-legacy-cross-reference` (Q14 first pass) | ~30s | `docs/plans/brand-hub-cross-reference.md` written with `last_reviewed: TBD` + Q14.1 3-tier mapping table; exit before G3 |
| **3 review** | **human** | — | Edit mappings in-place; bump `last_reviewed` to `2026-05-12` |
| 3 (execute) | `flow-legacy-cross-reference` (Q14 second pass) | ~27s (26 × ~1s serial) | 26 Brand Hub milestones get `## FDA migration` section inside `<!-- FDA-MIGRATION-START / END -->` markers; G3 confirms |
| 4 | `flow-inventory-codebase-scan` (Q11) | ~3–5 min | `master-flow-inventory.md` with status taxonomy; L2 stash per domain; G4 confirms |
| 5 (preview) | `flow-linear-scaffold` Phase 5.1 per domain | ~2–5 min per domain | L3 reviews per sub-flow populate `## L3 review summary` on parent issue bodies; per-domain previews collected; G5 batch preview |
| 5 (execute) | `flow-linear-scaffold` Phase 5.3 per domain | ~10s per (2+7N) write batch | ~10 milestones + ~50 sub-flow parents + ~250 discipline children created with chains + labels |
| 6 | `flow-doc-author` (Q15, globally batched) | ~30–60s | Story docs at `docs/product/flows/<domain>/<flow-id>.md` |
| 7 | `flow-journey-author` (Q16, globally batched) | ~60–90s | Journey docs at `docs/product/journeys/<domain>.md` populated from Phase 4 L2 stash |
| 8 | `flow-regen-index` (Q18) | ~5s | `docs/product/flows/INDEX.md` regenerated idempotently |
| 9 | inline terminator | ~5s | Completion summary; breadcrumb `status: completed` |

## Logging discipline (during execution)

Each phase boundary writes a row into the findings doc's iteration log table: phase, exit reason (`PASS` / `FAIL: <one-line cause>`), wall-clock, artifacts touched. Linear write counts captured as Phase 5 inner-loop progresses. Bugs surfaced go to the findings doc's `### Bugs surfaced` subsection; plugin-side fixes file as new BC-issues with `flow-architecture` label, NOT as BC-6998 blockers (in-flight protocol from BC-6998 body).

## Post-execution verification

The 7 AC + 4 quality gate checks run from `cd /Users/holdenhalford/projects/work/brite-nites/brand-hub`. Each check's verdict lands in the findings doc's `## Acceptance criteria verdict` table.

## Out of scope (do not let dogfood pull into BC-6998)

- v1.0 release tag + CDR-023 status flip → BC-6999.
- v1.1 backlog grooming / parking-lot re-triage → post-v1.0.
- Brand Hub product-side fixes surfaced by retrofit → file in Brand Hub Linear project, not as BC-6998 blockers.
- Pushing Brand Hub-side commits → leave as local commit; Brand Hub team merges on their 2026-05-19 release cadence.

## Worktree path

`/Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins/.claude/worktrees/bc-6998-brand-hub-dogfood` (branch `worktree-bc-6998-brand-hub-dogfood`). Findings doc + this plan doc + plugin version bump land here.
