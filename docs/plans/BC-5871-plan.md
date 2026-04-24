# BC-5871 — Phase 1 scope-reconciliation delta codification

**Parent:** BC-5763 (Cadence dogfood).
**Same-surface partner:** BC-5870 (§ 1.6 quality-flags threshold, just shipped as #206).
**Downstream consumer:** BC-5821 (Cadence prior-narrative parser — not yet started).

## Surface

**Primary file:** `plugins/cadence/commands/weekly.md` (§ 1.4, § 1.5, § 1.6, Session State Object schema comment).
**Schema-sync files:** `plugins/cadence/agents/narrative-writer.md:15`, `plugins/cadence/agents/project-enricher.md:18` (both declare the cross_project_stats shape — CLAUDE.md state-schema-drift gotcha mandates lockstep update).
**Gotchas file:** `plugins/cadence/CLAUDE.md` (add one bullet per BC-5869 / BC-5870 precedent).
**Version:** `plugins/cadence/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` cadence entry.

## Tasks

### Task 1 — § 1.4: add `linear_raw_completed` fetch recipe

Insert a new bullet in `commands/weekly.md § 1.4` describing the MCP call:
- `mcp__plugin_workflows_linear-server__list_issues` with `cycle: state.cycle.previous.title`, `team: state.team.id`, `state: "completed"`, no `project` filter.
- Paginate until exhausted (W17 had 179 raw — default limit 50 = ~4 pages).
- Capture `{id}` per returned issue; reduce to `linear_raw_completed_ids` (list of IDs).

Verify: bullet cites the BC-5757 § 2.3 gotcha about client-side filtering and uses the `cycle` title string, not ID.

### Task 2 — § 1.4: promote the 4 fields + compute `unattributed_issues`

Extend the `state.cross_project_stats` compute list with:
- `day1_scope_count` = `state.cycle.previous.issueCountHistory[0]`
- `linear_raw_completed` = `linear_raw_completed_ids.length`
- `project_sum_shipped` = `sum(state.projects[].audit_card.shipped.count)` (alias of existing `shipped_total` — keep both for back-compat)
- `unattributed_count` = `max(0, linear_raw_completed - project_sum_shipped)` (clamp ≥ 0 against project-audit race)

Compute list (top-level state, not inside cross_project_stats because it's a list, not a scalar):
- `unattributed_issues` (list of IDs) = `linear_raw_completed_ids − union(state.projects[].audit_card.shipped.issues[].id)`

### Task 3 — § 1.5: persist `unattributed_issues` in audit.json

Extend the audit.json write body to include `unattributed_issues: [...]` at root level **only when `unattributed_count > 0`**. Pretty-print (2-space indent) consistent with existing format. The cycle/cross_project_stats/audit_cards root keys are unchanged.

### Task 4 — § Session State Object: update schema comment

Line 179 area in `commands/weekly.md`: add the 4 new scalar fields to the `cross_project_stats` schema comment. Add `unattributed_issues` as a separate top-level state key (list scope, not scalar).

### Task 5 — § 1.6: add "Cycle reconciliation" bullet

Insert as a new item in § 1.6 user-facing synthesis, positioned **after item 3 (Zero-activity footer) and before item 4 (Audit gaps)**. One line, conditional on `unattributed_count > 0`:

> `**Cycle reconciliation** — <linear_raw_completed> issues completed cycle-wide; <project_sum_shipped> attributed across audited projects; <unattributed_count> unattributed (team-level or pre-dated project changes). Full IDs in audit.json.`

Include a **Scale target** sentence clarifying this is a single-line rollup regardless of unattributed count — IDs are persisted in audit.json, not rendered inline (mirrors BC-5870 threshold-aggregation precedent).

### Task 6 — Schema-sync: narrative-writer + project-enricher

Update:
- `agents/narrative-writer.md:15` — add the 4 new scalar fields to the declared `cross_project_stats` shape.
- `agents/project-enricher.md:18` — same, to the declared subset (pass-through).

Do NOT pass `unattributed_issues` to either agent — neither consumes it. Only the main-thread § 1.5 write does.

### Task 7 — CLAUDE.md: add gotcha bullet

One line under `plugins/cadence/CLAUDE.md § Gotchas`, mirroring BC-5869 / BC-5870 format:

> **Phase 1 cross-project synthesis reconciles day-1 scope / Linear-raw / project-sum.** `commands/weekly.md § 1.4` computes 4 scalar fields (`day1_scope_count`, `linear_raw_completed`, `project_sum_shipped`, `unattributed_count`) + optional top-level `unattributed_issues: [...]` (only when `unattributed_count > 0`). § 1.6 renders one "Cycle reconciliation" line when `unattributed_count > 0`; full IDs stay in audit.json. Origin: BC-5871 (unblocks BC-5821 prior-narrative parser).

### Task 8 — Version bump

- `plugins/cadence/.claude-plugin/plugin.json`: `0.5.1` → `0.5.2`.
- `.claude-plugin/marketplace.json` cadence entry: `0.5.1` → `0.5.2`.

### Task 9 — Seeded verification (PR body)

Three verification cases documented in the PR body:
- **Real W17 case** — `~/Projects/work/brite-nites/weekly-planning/w17-2026-04-20/audit.json`: 330 day-1 / 179 raw / 160 project-sum / ~19 unattributed (numbers from BC-5871 issue context paragraph).
- **Synthetic zero-case** — unattributed_count == 0: confirm reconciliation bullet does NOT render.
- **Synthetic non-empty case** — confirm bullet renders AND audit.json contains `unattributed_issues: [...]`.

### Task 10 — validate.sh baseline preservation

Run `./scripts/validate.sh` — expect 0 errors, ≤16 warnings. Baseline matches BC-5870.

## Acceptance criteria mapping

- AC1 (4 fields populated) → Task 2
- AC2 (seeded test confirms delta math) → Task 9
- AC3 (reconciliation bullet renders when `unattributed_count > 0`) → Task 5
- AC4 (audit.json includes `unattributed_issues` when applicable) → Task 3
- AC5 (BC-5821 can consume day1/raw without additional Linear calls) → Task 2

## Risks

- **MCP pagination correctness.** W17 returns ~180 issues; default limit 50. Verify pagination recipe handles >1 page.
- **Cycle-filter format.** Use `cycle` title string per BC-5757 § 2.3. `state: "completed"` is different from `state: "started"` gotcha — expected to work but flag the divergence in the spec.
- **Schema-sync thoroughness.** CLAUDE.md gotcha: state-schema drift across phases. Verify narrative-writer and project-enricher both declare shape in sync with weekly.md § Session State Object.

## Out of scope

- BC-6052 (project-audit subagent per-flag list fix). Sibling follow-up — separate PR.
- BC-5821 (prior-narrative parser). This PR provides its inputs; parser itself is its own Linear issue.

## Branch + worktree

- Branch: `holden/bc-5871-phase-1-scope-reconciliation`
- Worktree: `.claude/worktrees/bc-5871/`

## Review addenda (post /workflows:review)

All P1/P2/P3 findings resolved or explicitly dismissed. Applied in-PR:

- **P2 (CONFIRMED)** — Pagination contract: removed `or node count < limit` disjunct (silent-truncation bug introduced in simplify pass); canonical single-signal stop now matches `skills/linear-housekeeping/SKILL.md`. Added explicit `limit: 50` + per-page reduce-to-id hint for bounded session memory. [weekly.md § 1.4]
- **P3 (DOWNGRADED)** — `project_sum_shipped` / `shipped_total` alias: added explicit `project_sum_shipped == shipped_total` invariant line (prose-level; no runtime assertion possible for spec prose). [weekly.md § 1.4]
- **P3 (DOWNGRADED)** — § 1.4 fetch parallelization: added implementer SHOULD-dispatch-in-same-turn hint (no structural § 1.2 rewrite). [weekly.md § 1.4]
- **P3 (CONFIRMED)** — CLAUDE.md gotchas now reference `§ 1.6 Quality flags subsection` and `§ 1.6 Cycle reconciliation line` by slug instead of ordinal; drop "item 5 → 6" trailer (brittle under future § 1.6 inserts). [CLAUDE.md § Gotchas]
- **P3 (filtered)** — Clamp rationale reworded to describe the *inverse-direction* race (clamp guards `project_sum > linear_raw`; the expected `linear_raw > project_sum` delta is never clamped — that's the field's reason for existing). [weekly.md § 1.4]
- **P3 (filtered)** — "Same invariant as item 6" forward-ref replaced with self-contained phrasing ("Render is a display decision; audit.json is canonical, same invariant as Quality flags subsection below"). [weekly.md § 1.6 item 4]
- **P3 (filtered)** — Set() construction hint added to `unattributed_issues` compute bullet (O(n+m) vs O(n·m) clarity). [weekly.md § 1.4]
- **P3 (filtered)** — Errored audit cards caveat added: IDs that would have attributed to errored projects surface as unattributed; BC-5821 should cross-check `audit_card.error`. [weekly.md § 1.4]
- **P3 (filtered)** — `unattributed_issues` top-level placement: added intentional-asymmetry comment to Session State schema (cross_project_stats holds scalars only; list lives at sibling top-level). [weekly.md § Session State Object]

Explicitly **dismissed by validation** (not applied):
- Cache-rehydration gap: `state.unattributed_issues` has no in-memory downstream consumer post-Phase-1; BC-5821 re-reads audit.json directly.
- `project-enricher.md:18` schema-sync: its declared subset is intentionally narrow (only `team_standouts` consumed); adding unused fields is cosmetic documentation padding.
- Page-payload retention concern: already foreclosed by the explicit "reduce to `[node.id for node in page.nodes]` per page and discard" wording added in Edit 1.

`validate.sh` after all edits: 0 errors, 16 warnings — baseline preserved.
