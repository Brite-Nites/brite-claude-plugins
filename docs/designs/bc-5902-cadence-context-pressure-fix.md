## Design: BC-5902 Cadence Phase 2/3 context-pressure architectural fix

**Issue**: BC-5902 — Cadence Phase 2: architectural fix for context-pressure family (parent for BC-5896/5897/5898/5899)
**Closes**: BC-5902 + BC-5896 + BC-5897 + BC-5898 + BC-5899 + **BC-5867** (absorbed — enricher owns brainstorming ranker)
**Date**: 2026-04-21

### Problem
At 25 projects, `sprint-scoping` (Phase 2) and `linear-housekeeping` (Phase 3) accumulate enough context (audit cards + backlog fetches + per-project scope state + brainstorming outputs + per-mutation gate reads) that the skills silently drop spec-required steps — no backlog fetch on 3 projects, CQ-per-issue iteration missing, Phase 3 quality-gate preflight annotated `"context pressure — skipped"`, § 7 bottleneck summary invisible. All four manifest as logged-after-the-fact spec departures; none halt or re-prompt. Root cause is that both skills must run inline in main thread (`AskUserQuestion` is in-main) while also carrying every project's heavy reads.

### Approach
**Hybrid dispatch — two new Sonnet agents absorb every heavy read; main thread keeps the interactive Q&A and the cross-project tally.** Each Phase 2 project-enricher dispatch returns a compact card (~1–2KB) that contains backlog candidates + enriched carry-over relations + brainstorming-ranked scope candidates. Phase 3 dispatches a housekeeping-preflight agent once with the full `state.mutations[]` cycle-path slice and receives a `{mutation_id → gate_detail[7]}` manifest. Main-thread context never reads raw Linear results directly after Phase 1 — only compact agent outputs.

Mirrors the existing Phase 1 `project-audit` fan-out (cap 10 concurrent). Two agents, one shape: "accept project/mutation refs, do heavy reads, return compact JSON."

### Key Decisions
1. **Two agents, same shape.** `project-enricher` (Phase 2, per-project fan-out) + `housekeeping-preflight` (Phase 3, batch-once). Consistent architecture across phases; symmetric file layout under `plugins/cadence/agents/`.
2. **Full-bundle enricher.** Enricher owns backlog `list_issues`, per-carry-over `get_issue` fan-out with `includeRelations: true`, audit-card rehydration, AND brainstorming ranking. This closes **BC-5867** as a by-product — the `workflows:brainstorming` Skill call from main thread goes away; its role moves into the enricher's output.
3. **§ 7 bottleneck stays in main, unconditional emit.** The post-loop tally is cheap (dict aggregation over `scope_decisions.q2_ship_ids` + `q3_reassignments`) and needs no fresh Linear reads. AC #7 (BC-5899) is satisfied by emitting the summary unconditionally — including the empty case "§ 7: no owner exceeds threshold" — rather than skipping when nothing trips.
4. **CQ block iterates every carry-over.** BC-5897 is a spec tightening, not an architectural change: loop `carry_over[]` and run CQ1–CQ5 per issue, applying § 2.3 adaptive-skip only at question level. The enricher returns enriched relations for all carry-overs so the skip logic has ground truth.
5. **State schema opens the PR (BC-5760 precedent).** First commit updates `plugins/cadence/commands/weekly.md § Session State Object` with `state.projects[i]._enrichment`, `state._preflight_manifest`, timestamps. Skill bodies follow. Opens the PR to the architecture-reviewer with the schema diff legible up-front.
6. **Fail-loud on dispatch failure.** If an enricher or preflight-agent dispatch errors, main thread surfaces `AskUserQuestion` "Retry / Pause / Proceed without enrichment" — never silent degradation. Directly encodes the BC-5896/5898 spec-fix posture.

### Alternatives Considered
- **Option B — per-project context compact.** Rejected. Compact is lossy. § 7 bottleneck tally requires every project's `q2_ship_ids` and `q3_reassignments` accumulated across the loop; compact could drop that. Cross-project carry-over tracking also at risk.
- **Option C — external resume protocol.** Rejected per issue body. Defeats "one command, one session" intent; terrible UX for 25-project weekly cadence.
- **Bulk-once enricher (one dispatch for all 25 projects).** Rejected. Maximum context compression but loses parallel dispatch (Phase 1 runs cap-10 concurrent). Creates a pattern not used elsewhere in Cadence.
- **Reuse project-enricher for Phase 3.** Rejected. Phase 3 input is `mutation_rows[]`, not `{project_id, audit_card}` — asymmetric interface couples two unrelated concerns. Second agent is cheap (single file, similar shape).
- **Post-Phase-2 state compact + inline Phase 3.** Rejected. Relies on compact being lossless for Phase 3's per-mutation gate re-run; the attempt-2 evidence says context pressure already blows at Phase 3 even with less data. One more subagent is cheap insurance.

### State Flow
```
Phase 1: project-audit fan-out (existing)
         → state.projects[i].audit_card
         │
         ▼  Gate #1

Phase 2: FOR each project:
           ├─ dispatch project-enricher (Sonnet, per-project, cap-10 parallel)
           │    input: {project_id, audit_card, cycle.current, cycle.previous}
           │    output: {backlog_candidates[], carry_over_enriched[], brainstorming_ranked[]}
           │  → state.projects[i]._enrichment
           └─ main: CQ-per-carry-over + SQ1-5 via AskUserQuestion
                → state.projects[i].scope_decisions
         THEN main: § 7 bottleneck tally (unconditional emit)
                → state.bottleneck_warnings[]
         │
         ▼  (no gate; falls into Phase 3 preview)

Phase 3: main: derive state.mutations[] from scope_decisions (unchanged)
         ├─ dispatch housekeeping-preflight (Sonnet, batch-once)
         │    input: {mutations[] filtered to decision_path == "cycle"}
         │    output: {[mutation_id]: gate_detail[7]}
         │  → state._preflight_manifest
         └─ main: render § 5 preview + § 6 per-group approvals + § 7 execute
                → w<NN>-housekeeping-log.md
         │
         ▼  Gate #2 per-group, Gate final Execute

Phase 4: narrative (existing, unchanged)
Phase 5: ops file (existing, unchanged)
```

### Coverage of Acceptance Criteria
| AC | Issue | How covered |
|---|---|---|
| Architectural fix landed | BC-5902 | Two new agents + SKILL refactors + schema update + cadence-orchestration.md § 2.5 "hybrid dispatch" subsection |
| No "No backlog fetched" annotations | BC-5896 | Enricher always fetches; on error, main fails loud via AskUserQuestion |
| CQ block runs per carry-over | BC-5897 | SKILL § 2 loop iterates `carry_over[]`; enricher returns enriched relations for every issue |
| Quality-gate preflight per-row | BC-5898 | Preflight-agent returns per-mutation gate_detail; § 5 preview column populated per row |
| § 7 bottleneck summary visible | BC-5899 | Main-thread post-loop tally with unconditional empty-case emit |
| Main `/context` ≤ 150K across 25 projects | BC-5902 | Enricher output ~1–2KB × 25 ≈ 50KB; preflight manifest ~300B × ~100 rows ≈ 30KB; well under ceiling |
| Design doc updated | BC-5902 | `docs/designs/cadence-orchestration.md` § 2.5 added + § 4 table row for new agents |
| Precedent trace captured | BC-5902 | `docs/precedents/BC-5902.md` — architectural pattern for subagent-dispatched heavy reads feeding interactive per-item loops |
| Brainstorming invocation resolved | BC-5867 | Enricher owns ranker; main no longer calls `workflows:brainstorming`; BC-5760 AC #3 updates accordingly |

### Risks & Mitigations
- **Enricher ranker quality vs `workflows:brainstorming`** → Sonnet-tier matches the main thread's current brainstorming skill model, so rank quality should meet parity. "Other" escape path on SQ2 preserves planner override regardless.
- **Cost / latency of Sonnet agents** → 25 per-project enricher dispatches + 1 batch preflight per cadence run ≈ 26 Sonnet calls per `/cadence:weekly` invocation. Weekly cadence, so ~26/week — trivial cost footprint. Wall-clock per dispatch ~2–5s; parallel fan-out keeps total Phase 2 enrichment ≤ 15s even at 25 projects.
- **Review-loop iteration count (BC-5761 precedent)** → Budget 4–5 iterations. This PR's surface (2 new agents + 2 SKILL refactors + design doc § + schema diff + precedent) is larger than BC-5761's; may need 5–6. Cap at 6 and ship with residuals documented.
- **Agent dispatch concurrency limit** → Cap at 10 parallel per Phase 1 precedent; 25 projects means 3 batched rounds. Wall-clock overhead ≤ single-digit seconds.
- **State-schema drift escapes validate.sh (BC-5760 precedent)** → First commit = weekly.md schema update; open PR with schema diff legible up-front so architecture-reviewer catches drift early.
- **Parallel-session plan-file-loss (BC-5798 observation)** → Plan file lives in worktree: `${WORKTREE}/docs/plans/BC-5902-plan.md`, not primary checkout. Design doc already written to primary (not worktree-scoped); acceptable because it's reference material, not session-mutable state.

### Scope Boundaries
**In scope:**
- `plugins/cadence/agents/project-enricher.md` (new, Sonnet)
- `plugins/cadence/agents/housekeeping-preflight.md` (new, Sonnet)
- `plugins/cadence/skills/sprint-scoping/SKILL.md` — § 2 pre-loop removes inline `list_issues` + `workflows:brainstorming` Skill call; dispatches enricher per project; § 3 carry-over loop iterates every issue
- `plugins/cadence/skills/linear-housekeeping/SKILL.md` — § 4 gate re-run dispatches preflight-agent; § 3 pre-flight still reads `_fetched_issues` cache where hot
- `plugins/cadence/commands/weekly.md` — state schema: new `_enrichment` / `_preflight_manifest` fields; removed main-thread dispatch wording; cap-10 enricher concurrency note
- `docs/designs/cadence-orchestration.md` — § 2.5 new "hybrid dispatch" subsection; § 4 cross-phase-summary table row
- `docs/precedents/BC-5902.md` — architectural-pattern trace + INDEX.md entry

**Out of scope:**
- Third dogfood cycle (BC-5874 owns; this PR is the pre-requisite)
- Phase 4 narrative / Phase 5 ops changes (not context-pressure-affected)
- Bumping plugin to 1.0.0 (BC-5874 owns the version bump post-dogfood)
- Seeded synthetic-25-project fixture test (W18 dogfood is the end-to-end verification per BC-5874; if third dogfood surfaces gaps, seeded test filed as follow-up)
- SQ4 dependency writes, advanced merge-flow preview (pre-existing Phase 3 deferrals, unchanged)

### Open Questions
- None. All architectural decisions resolved; implementation details belong in the plan.
