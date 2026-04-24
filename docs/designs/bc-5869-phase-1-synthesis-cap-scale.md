## Design: Cadence Phase 1 synthesis — filter-to-active + zero-activity footer

**Issue**: BC-5869 — Cadence Phase 1: 300-word synthesis cap breaks at 26 projects — codify an aggregation rule or raise the cap
**Date**: 2026-04-24

### Problem

BC-5759 AC #6 set a `≤300 words` cap on the user-facing synthesis rendered at Gate #1, written against a `~18 active projects` assumption. W17 dogfood ran against 26 active projects and rendered `~370 words` (dogfood-notes Entry 2). Each per-project drift bullet is `~15 words`, so bullet count × per-project cost exceeds the cap on its own. Without a structural fix, the rendering fails harder as the Brite project roster grows toward 40+.

### Approach

Change the Phase 1 § 1.6 rendering rule from "one bullet per project" to **"one bullet per project with activity, plus a single rollup bullet for zero-activity projects"**. A project has activity when `shipped.count + carry_over.count + dropped.count > 0` (per the audit card shape already emitted by `project-audit`). Zero-activity projects fold into `Zero-activity this cycle (N): <project names, comma-separated>` — names preserved so the planner can still spot "why is project X idle?". Full per-project audit cards remain in `audit.json`. Update BC-5759 AC #6 to be scale-aware.

### Key Decisions

1. **Filter by activity, not by priority or drift narrative** — Rationale: activity is a factual boolean (all three counts = 0), not a semantic judgment. `feedback_thorough_audits.md` prohibits batching projects into drift categories (*"3 projects improved"*); a zero-activity rollup is not a drift category, it is the absence of data.
2. **Preserve zero-activity project names in the footer bullet** — Rationale: keeps per-project visibility without manufacturing drift narratives. The planner can still read "Brite Recruiting, Brite Training" and ask "why idle?" if relevant.
3. **Update BC-5759 AC #6 to scale-aware wording** — Rationale: the original `≤300 words` cap was unanchored and fails at 26. The revised wording (`≤300 words assuming ≤20 projects with activity; synthesis renders projects-with-activity per-line and rolls zero-activity into a single footer bullet`) pins the rule to a measurable rendering shape rather than a headcount.
4. **Add a `plugins/cadence/CLAUDE.md § Gotchas` one-liner** — Rationale: AC #4 requires it. The gotcha documents the original 18-project scale assumption and the scale-aware rule so future skill edits don't regress.
5. **Defer pagination (Option C) to a follow-up** — Rationale: the filter-to-active shape fails gracefully as roster grows (each new active project adds `~15 words`, each new zero-activity adds `~1 word`). Interactive pagination adds a new AskUserQuestion gate every Gate #1 render — real interaction cost to solve a hypothetical 60+-project problem. YAGNI until observed.

### Alternatives Considered

- **Option A (collapse zero-activity only)** — The issue's recommended path. This design IS Option A, with the AC #6 wording pinned to the rendering shape rather than to a raw word count. The difference is fit-to-growth wording.
- **Option B (raise cap to `≤500` or `≤20 × active_count`)** — Rejected: cap was arbitrary to start with, and raising it trades a cap that fails at 26 for a cap that fails at 40. Does not address the structural driver (bullet count × per-project cost).
- **Option C (paginated synthesis with "show remaining N?" AskUserQuestion)** — Rejected for now. Solves growth beyond ~60 projects cleanly but adds a new interactive gate that fires every week. Reconsider if/when active-project count crosses a point where filter-to-active alone exceeds `~600 words`.
- **Drop the synthesis, render audit.json summary only** — Rejected. Gate #1 needs a human-readable snapshot; `audit.json` is 800+ lines at 26 projects. The synthesis is the proxy-for-reading.
- **Tiered rendering (Hot / Active / Idle groups)** — Rejected. Moves toward batching-by-drift, which is the specific pattern `feedback_thorough_audits.md` prohibits.

### Risks & Mitigations

- **Risk**: Zero-activity projects may be meaningful (parked, blocked, understaffed) and collapsing them could hide a signal. → **Mitigation**: Names preserved in the footer bullet; planner can still spot specific projects and act on them.
- **Risk**: The "activity" predicate is shipped/carry/dropped > 0, which excludes projects that had in-flight work that didn't change state this cycle. → **Mitigation**: By definition, such projects have `carry_over.count > 0` and thus are active. The predicate is correct.
- **Risk**: Footer render drift between skill / command / narrative-writer if another phase consumes the synthesis shape. → **Mitigation**: The synthesis is rendered-to-user-only; no downstream phase parses it. `audit.json` is the machine-readable truth.
- **Risk**: Growth past 60 active projects eventually breaks this too. → **Mitigation**: Accepted. Filter-to-active buys us the next `~30 projects` of growth; pagination is the clear follow-up when that threshold approaches.

### Scope Boundaries

**In scope:**
- `plugins/cadence/commands/weekly.md § 1.6` — rendering rule change (filter-to-active + zero-activity footer)
- `plugins/cadence/CLAUDE.md § Gotchas` — one-line scale-assumption note
- BC-5759 AC #6 — update wording (Linear mutation via `save_issue`)
- Verification: re-compute rendered word count against W17's seeded audit.json (26 projects, `~18 active`)

**Out of scope:**
- Interactive pagination (Option C) — deferred follow-up
- Changes to `audit.json` format or `project-audit` agent — upstream, untouched
- Fixes to BC-5870 (quality-flag aggregation) or BC-5871 (scope-reconciliation delta) — sibling issues with their own ACs
- Fixes to sprint-narrative rendering in Phase 4 — separate Gate (Gate #3) with its own voice spec
- Word-count verification harness / test fixture — not required by AC, ad-hoc verification against W17 data suffices

### Open Questions

None.
