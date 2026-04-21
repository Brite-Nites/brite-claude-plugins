---
name: sprint-scoping
description: Phase 2 of /cadence:weekly. Sequential per-project scope interview (5 carry-over Qs + 5 scope Qs, one at a time) with brainstorming and the issue-quality-gate. Triggers on "sprint planning", "weekly scope", "what ships this week", "scope the next cycle", or "/cadence:weekly phase 2".
user-invocable: false
allowed-tools: mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, mcp__plugin_workflows_linear-server__list_comments, AskUserQuestion, Read, Write, Edit, Bash, Skill, Agent
---

# Phase 2 — Sprint Scoping

Sequential per-project loop. For each active project, surface alternatives via brainstorming, run the adaptive interview from BC-5810 § 2 (5 carry-over Qs + 5 scope Qs), enforce the issue-quality-gate from § 3 with block-with-override, and append a project block to the weekly-planning checkpoint as decisions accumulate. No Linear mutations — those are deferred to Phase 3 (BC-5761).

This skill is inline (model inherits). Phase 2 is interactive Q&A — it cannot run as a dispatched subagent (per BC-5760 issue Notes).

## § 1 Inputs (state object)

Reads from the session state object populated by Phases 0–1:

- `state.team.id` — Brite Company UUID, set in Phase 0
- `state.cycle.current` — cycle being *planned* (W+1)
- `state.cycle.previous` — cycle being *audited* (W)
- `state.projects[].audit_card` — Phase 1 fan-out output (`shipped`, `carry_over`, `dropped`, `quality_gate_flags`, `by_assignee`)
- `state.cross_project_stats` — completion rate, shipped totals, standouts
- `state.leadership_planning_notes` — optional freeform file path the user may pre-load (skill reads if present, ignores if absent)

Populates / mutates:

- `state.projects[i]._enrichment = { backlog_candidates[], carry_over_enriched[], brainstorming_ranked[], enriched_at, dispatch_error }` (produced per-project by the § 2 pre-loop enricher dispatch — BC-5902; authoritative shape lives in `commands/weekly.md § Session State Object`)
- `state.projects[i].scope_decisions = {q1_headline, q2_ship_ids, q3_reassignments, q4_dependencies, q5_parked, carry_over_answers[]}`
- `state.projects[i].overrides = [{issue_id, check, reason}]`
- `state.projects[i].skip_log = [string, ...]` (one line per skipped question with the audit-card reason)
- `state.bottleneck_warnings = [{assignee, count, issues[]}]` (populated after the project loop)

## § 2 Per-project loop entry

**Pre-loop (once per Phase 2 invocation):**

- **Resume parse.** Read the current-week checkpoint file (path resolved per § 6) once. Parse every `### N. <project_name>` heading and build `state._scoped_project_names: Set<string>`. This is the single source of truth for resume state — § 2 step 1 and § 8 both consult this set. (If the file does not exist, the set is empty.)
- **Enricher dispatch fan-out** (BC-5902). In a single `Agent` tool-call message, dispatch `project-enricher` once per project in `state.projects[]` with `status.type == "started"`. Cap 10 concurrent dispatches (mirrors Phase 1 § 1.2 Dispatch per `commands/weekly.md`); batch sequentially in groups of 10 if `state.projects[].length > 10`. Prompt body per dispatch: `project_id`, `project_name`, `audit_card` (full Phase 1 output for this project), `cycle.current`, `cycle.previous`, `team_id`, `cross_project_stats`. Parse each returned JSON block into `state.projects[i]._enrichment` keyed by project id. On any `_enrichment.dispatch_error` (non-null), halt the pre-loop and surface `AskUserQuestion` with three options: **Retry** (re-dispatch only the failed projects with fresh Agent calls), **Pause session** (append `phase-2` to `completed_phases = []` NOT yet — leave state unchanged, write breadcrumb `current_phase = "phase-2"`, exit cleanly), **Proceed without enrichment for failed projects** (explicit spec-departure: set `_enrichment.backlog_candidates = []` + `_enrichment.brainstorming_ranked = []` for that project and free-text-prompt the user for SQ2 IDs when that project's turn comes; log under `state.projects[i].skip_log`). NEVER silent degradation — this is the BC-5896 AC fail-loud contract.

**For each `state.projects[i]` selected in Phase 0.3 (`status.type == "started"`, deduped by id):**

1. **Resume skip.** If `state.projects[i].name ∈ state._scoped_project_names`, set `state.projects[i].scope_confirmed = true` and continue to the next project. Log: `Project <name> already scoped — skipping (resume).` If this is the last project and it was already scoped, exit the loop cleanly.
2. **Enrich carry-over** — Read `state.projects[i]._enrichment.carry_over_enriched[]` populated by the § 2 pre-loop enricher dispatch. For each entry, hydrate the matching `audit_card.carry_over.issues[i]` with: `enriched.blocker_count = _enrichment.carry_over_enriched[id].blocker_count`, `enriched.auto_superseded_by = _enrichment.carry_over_enriched[id].auto_superseded_by`. No additional MCP reads in Phase 2 — the enricher already did the parallel `get_issue` fan-out with `includeRelations: true`. Bounded cost — work is a dict merge.
3. **Run § 3 carry-over interview** (skipped entirely if `carry_over.count == 0` per BC-5810 § 2.3).
4. **Run § 4 scope interview**.
5. **Run § 5 quality gate** on every issue ID in `q2_ship_ids` (pre-fan-out `get_issue` for any ID not already in `_fetched_issues`).
6. **Run § 6 checkpoint append**.

After all projects: **§ 7 cross-project bottleneck pass**.

## § 3 Carry-over interview (5 questions per issue)

For **every** issue in `state.projects[i].audit_card.carry_over.issues[]` (not just the highest-priority one — BC-5897), ask the 5 questions from BC-5810 § 2.1 verbatim. Iteration order is `carry_over.issues[]` array order (Phase 1 audit sorts by priority already). No priority-filter / rank-filter on block entry — only question-level adaptive-skip from § 2.3 applies. Each question is a **separate** `AskUserQuestion` tool call — no batching. Hard rule per `memory/feedback_one_question_at_a_time.md`. Skip rules from BC-5810 § 2.3 are evaluated *before* each `AskUserQuestion` call; skipped questions append a one-line entry to `skip_log`.

Every question carries: issue ID + title, one-line audit summary snippet (e.g. *"BC-2690 — MI reply sync. In Progress W15. No PR. Holden. 0 blockers."*), recommended default first with `(Recommended)` suffix, and "Other" as the free-text escape.

| Q-ID | Question | Recommended default | Skip condition |
|---|---|---|---|
| CQ1 | Move `<id>` to next cycle? | Move to W+1 | (never skipped) |
| CQ2 | Assignee still correct (`<current>`)? | Unchanged | (never skipped) |
| CQ3 | Superseded by a different chain? | Keep as-is *(or prefilled with `<auto_superseded_by>` chain as `(Recommended)` if set)* | Never skipped. If `enriched.auto_superseded_by` is set, the chain is prefilled as the recommended default but the question is still asked for confirmation (per BC-5810 § 2.3). |
| CQ4 | Blockers still live? | Yes, keep declared blockers | `enriched.blocker_count == 0` → skip + log `"CQ4 skipped — 0 blockers per Linear relations"` |
| CQ5 | If staying, which cycle/milestone lands it? | Next cycle | Skipped if CQ1 == "Park indefinitely" |

Answers are stored under `state.projects[i].scope_decisions.carry_over_answers[]` keyed by issue ID.

## § 4 Scope interview (5 questions per project)

Once per project after carry-over completes (or immediately if carry-over was skipped). If `state.projects[i].status.type == "parked"` (from the Linear project shape captured in Phase 0.3, not from the audit card), only SQ1 is asked (for acknowledgement) and SQ2–SQ5 are skipped + logged.

**Scope candidate injection from enricher.** Before SQ2, read `state.projects[i]._enrichment.brainstorming_ranked[]` populated by the § 2 pre-loop `project-enricher` dispatch. The top-ranked candidate (`rank == 1`) becomes SQ2's `(Recommended)` default in the `AskUserQuestion` call; alternatives at ranks 2–3 become options 2–3. No main-thread `workflows:brainstorming` Skill call — the enricher already ran the ranker logic with the same inputs (carry-over count, backlog-high count, shipped-pace, owner-load hint). If `brainstorming_ranked` is empty (e.g. enricher fell back to `Proceed without enrichment`), SQ2's default becomes `"carry-over only — no backlog proposals"` and the user escape-path "Other" carries free-text. **(Closes BC-5867 — brainstorming ranker moves from spec-misfit inline Skill call to dispatched subagent output consumed as data — BC-5902.)**

The 5 questions from BC-5810 § 2.2 verbatim, each a **separate** `AskUserQuestion` call:

| Q-ID | Question | Recommended default |
|---|---|---|
| SQ1 | Headline outcome sentence for `<project>`? | Agent draft from top-priority carry-over + top backlog |
| SQ2 | Which issue IDs ship this cycle? | Brainstorming output (top-ranked candidates; quality-gate filtering runs in § 5 on the user's picks, not here) |
| SQ3 | Owner per issue, if different from existing? | Keep existing assignees |
| SQ4 | Dependencies between picked issues? | Agent infers from descriptions + `relations.blockedBy` |
| SQ5 | Explicitly parked this cycle? | Agent proposes from stale current-cycle items + Low-priority carry-over |

## § 5 Quality gate + block-with-override

For every ID in `q2_ship_ids` (from SQ2), invoke the `cadence:issue-quality-gate` shared skill via the `Skill` tool with the issue object (fetched via `get_issue` if not already enriched). The gate returns 7 `{check, status, message}` tuples. On any `status == "fail"`:

1. Surface the failure to the user — show issue ID, title, the failing check name, and the message.
2. `AskUserQuestion` with 3 options:
   - **Fix the issue now** — echo the Linear URL (`https://linear.app/brite-nites/issue/<id>`); wait for the user to fix + confirm; re-run the gate; on pass, the issue stays in `q2_ship_ids`.
   - **Override this check with a reason** *(Recommended only when the user explicitly opts in)* — collect a one-line free-text reason; append `{issue_id, check, reason}` to `state.projects[i].overrides`. The reason will surface in Phase 4's narrative `> **Known gaps this cycle**` callout (BC-5762).
   - **Drop from scope** — remove the ID from `q2_ship_ids`; prompt for a replacement candidate from the brainstorming list.

No global "skip all gates" escape exists. Per-check override with a reason is the only path. Re-run the gate on any issue the user re-adds.

## § 6 Checkpoint append (per project, after § 5 passes)

Resolve the checkpoint path **once at Phase 2 entry** and cache under `state.checkpoint_path`. Both § 6 and § 8 read that cached value — no `git rev-parse` calls inside the per-project loop.

Resolution algorithm (pseudocode — the skill pre-extracts the numeric and date components from `state.cycle.current` before calling bash, since `cycle.current.name` is the cycle title string like `"W17"` and `startsAt` is an ISO timestamp):

```
# Pre-extracted by the skill from state:
#   CYCLE_NN  = numeric week from state.cycle.current.name (e.g. "W17" → 17)
#   CYCLE_DATE = state.cycle.current.startsAt formatted YYYY-MM-DD
# Then in Bash:
WEEK_NN=$(printf "%02d" "$CYCLE_NN")
ROOT=$(git rev-parse --show-toplevel)
CHECKPOINT="$ROOT/../weekly-planning/w${WEEK_NN}-${CYCLE_DATE}/w${WEEK_NN}-planning-checkpoint.md"
```

Reject `CYCLE_DATE` if it does not match `^[0-9]{4}-[0-9]{2}-[0-9]{2}$` — fail the phase with a clear error rather than writing a malformed path.

If `state.weekly_planning_root` is set in the state object, use that as the prefix instead of `$ROOT/..`. Mirrors Phase 1's `audit.json` resolution (BC-5759 § 1.1).

Append a project block to the file. **Atomic** — write only after § 5 completes for this project so partial failure leaves the file in a recoverable state.

```markdown
### N. <Project Name>

**Owner:** <primary assignee or team>
**Headline:** <SQ1 answer>

<freeform body rendered from the scope-Q answers>

- Carry-over summary (one line per issue with the CQ1–CQ5 outcome)
- Ship this cycle (SQ2 IDs grouped by phase or owner per the project's voice)
- Owner reassignments (SQ3)
- Dependencies (SQ4 — list explicit edges or "all parallel")
- Stretch / parked (SQ5 + carry-overs sent past W+1)
- Risks (auto-surface from any `overrides` entries on this project + bottleneck flags from § 7 if pre-computed)
```

Minimum required headers per AC: `### N. <name>`, `**Owner:**`, `**Headline:**`. Everything else freeform per W16 ground-truth (`weekly-planning/w16-2026-04-13/w16-planning-checkpoint.md`) — voice matches `docs/designs/cadence-plugin.md` § 1.

Note: BC-5760 issue AC #6 references literal sub-sections (`Ship this week`, `Stretch`, `Parked`, `Risks`). The W16 ground truth uses freeform headers per project (e.g. *"Devops unblock"*, *"OutboundSync pipeline"*, *"BDR pipeline cleanup"*); the plan resolved this in favour of voice-fidelity. Document the departure in the PR description.

## § 7 Cross-project bottleneck detection

**Unconditional emit (BC-5899).** Always emit the § 7 summary at Phase 2 exit — even when `bottleneck_warnings == []`. The checkpoint always gets a `## Cross-project flags` section; the empty case renders `_None this cycle._`. Satisfies BC-5760 AC #7 regardless of whether any owner exceeds the threshold, so the planner sees the check ran and reads the result.

After the per-project loop completes, scan every project's `scope_decisions.q2_ship_ids` and `q3_reassignments`. Group by primary assignee. Emit a warning under `state.bottleneck_warnings[]` for any owner with > N primary assignments (default `N == 4`; configurable via `state.bottleneck_threshold`). Each warning is `{assignee, count, issues: [ids]}`.

Append a `## Cross-project flags` section to the checkpoint file with one bullet per warning:

```markdown
## Cross-project flags

- **<assignee>** is primary on <count> issues this cycle: BC-X, BC-Y, BC-Z, ... — review for bottleneck risk.
```

If `bottleneck_warnings == []`, append a single line: `## Cross-project flags\n\n_None this cycle._`

## § 8 Idempotency + resume

- **Resume pass** is owned by § 2's pre-loop *Resume parse* step, which populates `state._scoped_project_names` once per invocation. § 2 step 1 is an O(1) set-membership check against that cache. Log at the end of the pre-loop parse: `Resume: <|_scoped_project_names|> project(s) already scoped from prior session.`
- **Atomic append** per project — the block is written only after § 5 completes. Partial failure (e.g. user `Cancel` mid-interview, MCP timeout, kernel SIGINT) leaves the checkpoint in a recoverable spot and the next invocation continues from the next unconfirmed project.
- **Cancel mid-interview**: if the user picks "Cancel" inside any `AskUserQuestion`, do not append to the checkpoint, do not mutate state for the in-flight project. Exit cleanly with `Phase 2 paused at <project_name>. Re-run /cadence:weekly to resume.`
- **Cycle change detection**: if a checkpoint file already exists at `state.checkpoint_path` AND its filename's `w<NN>` segment does not match the cycle number derived from `state.cycle.current.name`, refuse to append and stop with an error pointing the user at `/cadence:weekly --resume-phase 2` after they confirm the cycle. Guards against a stale `state.weekly_planning_root` override pointing at a prior cycle's folder.

## § 9 References

- `docs/designs/cadence-orchestration.md` § 2 (interview), § 3 (gate) — BC-5810 authoritative spec
- `docs/designs/cadence-plugin.md` § 1 — voice spec (BC-5757)
- `weekly-planning/w16-2026-04-13/w16-planning-checkpoint.md` — ground-truth checkpoint format
- `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md` — quality gate primitive (BC-5810 § 3)
- `plugins/cadence/agents/project-audit.md` — audit_card producer (BC-5759)
- `plugins/cadence/agents/project-enricher.md` — enricher agent this skill dispatches (BC-5902)
- `plugins/cadence/commands/weekly.md` § Phase 2 — entry command pointer
- `memory/feedback_one_question_at_a_time.md` — hard rule enforcement
- `memory/feedback_thorough_audits.md` — per-item rigor (no batching across projects)
- `memory/feedback_more_checkins_for_infra_issues.md` — each project confirmation is one check-in gate
- `memory/gotcha_linear_markdown_mangling.md` — applies if Phase 3 ever writes scope decisions back to Linear

## Deferred to follow-up issues

- **Prior-narrative parser** for `state.cycle.previous`'s sprint narrative — needed to compute `cross_project_stats.unplanned_ratio` and per-assignee *planned* attribution. Filed as **BC-5821** in the Cadence Plugin milestone. Out of scope for BC-5760 to keep the skill atomic.
- **Configurable `state.bottleneck_threshold`** beyond the default `N == 4` — currently hard-coded; surface as `--bottleneck-threshold` flag on `/cadence:weekly` if user demand emerges.
- **Seeded synthetic-25-project fixture test** — deferred to follow-up. BC-5874 third dogfood is the end-to-end verification for the BC-5902 hybrid-dispatch fix. If dogfood surfaces gaps, file a separate issue for a synthetic fixture.
