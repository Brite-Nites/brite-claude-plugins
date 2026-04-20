---
name: sprint-scoping
description: Phase 2 of /cadence:weekly. Sequential per-project scope interview (5 carry-over Qs + 5 scope Qs, one at a time) with brainstorming and the issue-quality-gate. Triggers on "sprint planning", "weekly scope", "what ships this week", "scope the next cycle", or "/cadence:weekly phase 2".
user-invocable: false
allowed-tools: mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, AskUserQuestion, Read, Write, Edit, Bash, Skill
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

- `state.projects[i].scope_decisions = {q1_headline, q2_ship_ids, q3_reassignments, q4_dependencies, q5_parked, carry_over_answers[]}`
- `state.projects[i].overrides = [{issue_id, check, reason}]`
- `state.projects[i].skip_log = [string, ...]` (one line per skipped question with the audit-card reason)
- `state.bottleneck_warnings = [{assignee, count, issues[]}]` (populated after the project loop)

## § 2 Per-project loop entry

For each `state.projects[i]` selected in Phase 0.3 (`status.type == "started"`, deduped by id):

1. **Resume check** — read the current-week checkpoint file (path resolved per § 6). If the file already contains a `### N. <project_name>` heading matching this project, set `state.projects[i].scope_confirmed = true` and skip to `state.projects[i+1]`. Log: `Project <name> already scoped — skipping (resume).`
2. **Enrich carry-over** — if `audit_card.carry_over.count > 0`, parallel `get_issue` for every ID in `audit_card.carry_over.issues[].id` with `includeRelations: true`. Store the returned `relations.blockedBy` length under `audit_card.carry_over.issues[i].enriched.blocker_count` and the first `relations.duplicateOf.id` (if any) under `audit_card.carry_over.issues[i].enriched.auto_superseded_by`. Bounded cost — carry-over count is small per project.
3. **Run § 3 carry-over interview** (skipped entirely if `carry_over.count == 0` per BC-5810 § 2.3).
4. **Run § 4 scope interview**.
5. **Run § 5 quality gate** on every issue ID in `q2_ship_ids`.
6. **Run § 6 checkpoint append**.

After all projects: **§ 7 cross-project bottleneck pass**.

## § 3 Carry-over interview (5 questions per issue)

For each issue in `audit_card.carry_over.issues[]`, ask the 5 questions from BC-5810 § 2.1 verbatim. Each question is a **separate** `AskUserQuestion` tool call — no batching. Hard rule per `memory/feedback_one_question_at_a_time.md`. Skip rules from BC-5810 § 2.3 are evaluated *before* each `AskUserQuestion` call; skipped questions append a one-line entry to `skip_log`.

Every question carries: issue ID + title, one-line audit summary snippet (e.g. *"BC-2690 — MI reply sync. In Progress W15. No PR. Holden. 0 blockers."*), recommended default first with `(Recommended)` suffix, and "Other" as the free-text escape.

| Q-ID | Question | Recommended default | Skip condition |
|---|---|---|---|
| CQ1 | Move `<id>` to next cycle? | Move to W+1 | (never skipped) |
| CQ2 | Assignee still correct (`<current>`)? | Unchanged | (never skipped) |
| CQ3 | Superseded by a different chain? | Keep as-is *(or prefilled `<auto_superseded_by>` if set)* | Skipped if `auto_superseded_by` set AND user confirmed CQ1 = "Move" — prefill is shown for confirmation only |
| CQ4 | Blockers still live? | Yes, keep declared blockers | `enriched.blocker_count == 0` → skip + log `"CQ4 skipped — 0 blockers per Linear relations"` |
| CQ5 | If staying, which cycle/milestone lands it? | Next cycle | Skipped if CQ1 == "Park indefinitely" |

Answers are stored under `state.projects[i].scope_decisions.carry_over_answers[]` keyed by issue ID.

## § 4 Scope interview (5 questions per project)

Once per project after carry-over completes (or immediately if carry-over was skipped). If `audit_card.project_status == "parked"`, only SQ1 is asked (for acknowledgement) and SQ2–SQ5 are skipped + logged.

**Brainstorming invocation.** Before SQ2, invoke `workflows:brainstorming` via the `Skill` tool with this prompt body — exactly once per active project (counted by AC #3):

> *"Propose next-cycle scope for project `<project_name>`. Inputs: carry-over count `<carry_over_count>`, backlog candidates at High-or-Urgent priority `<backlog_high_count>`, recent shipped pace `<shipped_total>` issues last cycle. Surface 2–3 alternative scope shapes and explicit `what-if-we-parked-X` prompts. Output: ranked candidate IDs with one-line rationale each."*

The brainstorming output feeds SQ2's candidate list as the `(Recommended)` default plus 2–3 alternatives.

The 5 questions from BC-5810 § 2.2 verbatim, each a **separate** `AskUserQuestion` call:

| Q-ID | Question | Recommended default |
|---|---|---|
| SQ1 | Headline outcome sentence for `<project>`? | Agent draft from top-priority carry-over + top backlog |
| SQ2 | Which issue IDs ship this cycle? | Brainstorming output (top-ranked candidates after the quality gate) |
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

Resolve the checkpoint path:

```bash
WEEK_NN=$(printf "%02d" "<cycle_number_parsed_from_cycle.current.title>")
WEEK_DATE="<cycle.current.startsAt formatted YYYY-MM-DD>"
ROOT=$(git rev-parse --show-toplevel)
CHECKPOINT="$ROOT/../weekly-planning/w${WEEK_NN}-${WEEK_DATE}/w${WEEK_NN}-planning-checkpoint.md"
```

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

After the per-project loop completes, scan every project's `scope_decisions.q2_ship_ids` and `q3_reassignments`. Group by primary assignee. Emit a warning under `state.bottleneck_warnings[]` for any owner with > N primary assignments (default `N == 4`; configurable via `state.bottleneck_threshold`). Each warning is `{assignee, count, issues: [ids]}`.

Append a `## Cross-project flags` section to the checkpoint file with one bullet per warning:

```markdown
## Cross-project flags

- **<assignee>** is primary on <count> issues this cycle: BC-X, BC-Y, BC-Z, ... — review for bottleneck risk.
```

If `bottleneck_warnings == []`, append a single line: `## Cross-project flags\n\n_None this cycle._`

## § 8 Idempotency + resume

- **On re-invoke**: read the current checkpoint file (path from § 6). Parse `### N. <name>` headers. For each match, set `state.projects[i].scope_confirmed = true` and skip-ahead in the § 2 loop. Log: `Resume: <count> project(s) already scoped from prior session.`
- **Atomic append** per project — the block is written only after § 5 completes. Partial failure (e.g. user `Cancel` mid-interview, MCP timeout, kernel SIGINT) leaves the checkpoint in a recoverable spot and the next invocation continues from the next unconfirmed project.
- **Cancel mid-interview**: if the user picks "Cancel" inside any `AskUserQuestion`, do not append to the checkpoint, do not mutate state for the in-flight project. Exit cleanly with `Phase 2 paused. <N> project(s) scoped, <M> remaining. Re-run /cadence:weekly to resume.`
- **Cycle change detection**: if the file's parsed `<NN>` does not match `state.cycle.current.title`'s number, refuse to append and stop with an error pointing the user at `/cadence:weekly --resume-phase 2` after they confirm the cycle.

## § 9 References

- `docs/designs/cadence-orchestration.md` § 2 (interview), § 3 (gate) — BC-5810 authoritative spec
- `docs/designs/cadence-plugin.md` § 1 — voice spec (BC-5757)
- `weekly-planning/w16-2026-04-13/w16-planning-checkpoint.md` — ground-truth checkpoint format
- `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md` — quality gate primitive (BC-5810 § 3)
- `plugins/cadence/agents/project-audit.md` — audit_card producer (BC-5759)
- `plugins/cadence/commands/weekly.md` § Phase 2 — entry command pointer
- `plugins/workflows/skills/brainstorming/SKILL.md` — Socratic exploration invocation pattern
- `memory/feedback_one_question_at_a_time.md` — hard rule enforcement
- `memory/feedback_thorough_audits.md` — per-item rigor (no batching across projects)
- `memory/feedback_more_checkins_for_infra_issues.md` — each project confirmation is one check-in gate
- `memory/gotcha_linear_markdown_mangling.md` — applies if Phase 3 ever writes scope decisions back to Linear

## Deferred to follow-up issues

- **Prior-narrative parser** for `state.cycle.previous`'s sprint narrative — needed to compute `cross_project_stats.unplanned_ratio` and per-assignee *planned* attribution. Filed as a sibling Cadence-milestone issue when this PR opens. Out of scope for BC-5760 to keep the skill atomic.
- **Configurable `state.bottleneck_threshold`** beyond the default `N == 4` — currently hard-coded; surface as `--bottleneck-threshold` flag on `/cadence:weekly` if user demand emerges.
