## Design: Context Budget Management Strategy

**Issue**: BC-2003 — Context budget management strategy
**Date**: 2026-03-16

### Problem

A fully-loaded project could consume ~690 lines (10-15% of context window) before any code loads — and it grows as CDRs and precedents accumulate.

Budget breakdown from the PRD:

| Source | Lines |
|--------|-------|
| Company profile | ~50 |
| CDR INDEX | ~30 |
| 3 CDR details (full) | ~150 |
| Engineering context doc | ~80 |
| Marketing context doc | ~80 |
| Project CLAUDE.md | ~100 |
| Precedent search results | ~200 |
| **Total** | **~690** |

The tiering model (Tier 1/2/3/5) is defined in BRI-2006 but has no formal budget guards, no per-task context selection, and no documented offloading strategy.

### Strategies

**Strategy 1: Context Tiering** — Status: **delivered**
Tier definitions live in `docs/workflow-spec.md` Section 6c. Tier 1+2 are pre-loaded at session-start. Tier 3 stays in the filesystem. Tier 5 is task-scoped in subagents.

**Strategy 2: Per-Task Context Selection** — Status: **delivered**
`executing-plans` now classifies tasks by file paths and injects only task-relevant CLAUDE.md sections into each subagent. See `plugins/workflows/skills/executing-plans/SKILL.md` → Context Selection Per Task.

**Strategy 3: Progressive Disclosure** — Status: **partially delivered**
- CDR INDEX → full CDR: implemented (BRI-1939, writing-plans queries CDR INDEX via Context7, lazy-loads full CDRs only on conflict)
- Precedent INDEX → full trace: planned (BRI-1960)
- Metric definitions → values: planned (no issue yet)

**Strategy 4: Context Offloading** — Status: **documented**
Offloading table below. Large outputs live in the filesystem — agents read them when needed.

### Key Decisions

1. **Per-task context selection uses file-path heuristics** — Task plans already contain exact file paths. Classify by extension and directory, not by semantic analysis.
2. **Budget guards are advisory** (logged, not blocking) — Consistent with CDR check pattern (BRI-1939). Agents warn but don't stop.
3. **Measurement is manual line-count audit per release** — Not runtime token counting. Context window sizes change with model updates; line counts are stable and auditable.
4. **Precedent progressive disclosure deferred to BRI-1960** — The precedent database doesn't exist yet. Document the pattern now, implement when the infrastructure lands.

### Measurement Baseline

Current Tier 1+2 consumption (measured against actual plugin repo):

| Source | Tier | Lines | Notes |
|--------|------|-------|-------|
| Project CLAUDE.md | 1 | ~80-100 | Under 100-line target |
| Auto-memory | 1 | ~20-40 | Session summaries, follow-ups |
| Company Context pointers | 2 | ~3-5 | Pointers only, not payload |
| **Total Tier 1+2** | | **~103-145** | **Well within 5% target** |

Target: Tier 1+2 should consume <5% of context window (~100-300 lines total).

### Offloading Table

| Content | Location | Why |
|---------|----------|-----|
| Project CLAUDE.md | In context (Tier 1) | Always needed for conventions |
| Auto-memory | In context (Tier 1) | Session continuity |
| Company Context pointers | In context (Tier 2) | Team/project metadata |
| Build & test commands | In context (Tier 1) | Every task needs these |
| Full CDR documents | Filesystem → on-demand (Tier 3) | Only needed when planning touches architecture |
| Precedent search results | Filesystem → on-demand (Tier 3) | Only needed during brainstorm/plan |
| Design docs | Filesystem → on-demand (Tier 3) | Loaded per-task by executing-plans |
| Domain context docs | Filesystem → @import (Tier 2) | Per-project, loaded at session-start |
| Analytical metrics | Filesystem → on-demand (Tier 3) | Only needed for data tasks |
| Architecture Decision Records | Filesystem → @import (Tier 2) | Per-project, loaded at session-start |

### Cross-References

- **Tiering definitions**: `docs/workflow-spec.md` Section 6c (`<!-- spec:cascade:tiers -->`)
- **Budget guards**: `docs/workflow-spec.md` Section 6d (`<!-- spec:cascade:budget-guards -->`)
- **Cascade architecture**: `docs/designs/BRI-2006-context-loading-cascade.md`
- **CDR check pattern**: BRI-1939 (writing-plans CDR INDEX query)
- **Precedent search**: BRI-1960 (planned)
- **PRD context budget section**: `docs/designs/brite-agent-platform.md` lines 870-904

### Risks & Mitigations

- **Over-classification** — File-path heuristics may mis-classify tasks (e.g., a `.md` file that documents API contracts). Mitigation: Always include Build & Test Commands regardless of classification; subagents can request more context if stuck.
- **Budget drift** — New @imports or CLAUDE.md sections grow over time. Mitigation: Advisory guard in session-start warns when CLAUDE.md exceeds ~120 lines; best-practices-audit (via /ship) enforces conciseness.
- **Measurement lag** — Manual audit only happens per release, not continuously. Mitigation: Acceptable for current scale; revisit if context consumption becomes a user-reported issue.
