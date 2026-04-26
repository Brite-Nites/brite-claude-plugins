---
name: sprint-scoping
description: Phase 2 of /cadence:weekly. Sequential per-project scope interview (5 carry-over Qs + 5 scope Qs, one at a time) with brainstorming and the issue-quality-gate. Triggers on "sprint planning", "weekly scope", "what ships this week", "scope the next cycle", or "/cadence:weekly phase 2".
user-invocable: false
allowed-tools: mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, mcp__plugin_workflows_linear-server__list_comments, AskUserQuestion, Read, Write, Edit, Bash, Skill, Agent
---

# Phase 2 — Sprint Scoping

Sequential per-project loop. For each active project, surface alternatives via brainstorming, run the adaptive interview from BC-5810 § 2 (5 carry-over Qs + 5 scope Qs), enforce the issue-quality-gate from § 3 with block-with-override, and append a project block to the weekly-planning checkpoint as decisions accumulate. No Linear mutations — those are deferred to Phase 3 (BC-5761).

This skill is inline (model inherits). Phase 2 is interactive Q&A — it cannot run as a dispatched subagent (per BC-5760 issue Notes).

## Gate-respect

Every multi-option `AskUserQuestion` in this skill is bound by the [gate-respect contract](../_shared/gate-respect.md). Once the planner picks an option — at the enricher-dispatch-error prompt, any CQ/SQ prompt, or the quality-gate failure prompt — execute that exact option. If an internal code path wants to deviate (condense, skip, batch, fast-path under context pressure), re-prompt via a new `AskUserQuestion` instead of silently self-selecting a lighter variant. Writing to a dogfood-notes, checkpoint, or breadcrumb file is not permission to deviate. Origin: BC-5866 (W17 dogfood of this skill).

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
- `state.projects[i].scope_decisions = {q1_headline, q2_ship_ids, q3_reassignments, q4_dependencies, q5_parked, carry_over_answers[], ritual}` — `ritual: true` set when § 2.3 ritual close-out row fires; SQ2–5 are skipped + logged in `skip_log` and the narrative renders a Ritual Cadence card variant instead of a Sprint Plans card.
- `state.projects[i].overrides = [{issue_id, check, reason}]`
- `state.projects[i].skip_log = [string, ...]` (one line per skipped question with the audit-card reason)
- `state.bottleneck_warnings = [{assignee, count, issues[]}]` (populated after the project loop)

## § 2 Per-project loop entry

<!-- gate-respect: honor user pick; re-prompt before any behavior change — applies to every AskUserQuestion in this § 2 pre-loop. -->

**No project-level triage gate.** Do not surface any `AskUserQuestion` at Phase 2 entry that asks the user to narrow the project set before the interview begins. Every project in `state.projects[]` (already filtered to `status.type == "started"` by Phase 0.3) is interviewed. Adaptive-skip is per-question (§ 2.3), never per-project. A quiet prior cycle does NOT imply empty W+1 scope — backlog + Todo may still contain items to promote into the cycle.

Specifically banned improvisation patterns (origin: BC-5864 W17 dogfood):

- *"Active projects only (N of M)"* — auto-parks quiet-prior-cycle projects. A quiet prior cycle is not the same as empty W+1 scope.
- *"Top N by ship count"* — filters by ship volume. Ship volume ≠ scope volume.
- *"All N, strict spec"* presented as one of several options — legitimizes the other options by including them in the menu.
- *"Abbreviated form"* / *"condensed form"* / any form that reduces per-project question count as a function of project count.

Do not invent synonyms for the above. If the prompt count feels unsustainable (e.g. 130+ AskUserQuestion calls for 26 projects), that is the planner experience BC-5810 locked in — the right lever is a different spec decision (a new sub-cohort gate amended into BC-5810), not an improvised triage menu here.

**Pre-loop (once per Phase 2 invocation):**

- **Resume parse.** Read the current-week checkpoint file (path resolved per § 6) once. Parse every `### N. <project_name>` heading and build `state._scoped_project_names: Set<string>`. This is the single source of truth for resume state — § 2 step 1 and § 8 both consult this set. (If the file does not exist, the set is empty.)
- **Enricher dispatch fan-out** (BC-5902). Filter to projects not already scoped: `dispatch_set = [p for p in state.projects if p.status.type == "started" AND p.name ∉ state._scoped_project_names]` — on resume, projects already in the set from the Resume-parse step above are skipped entirely (no wasted Sonnet dispatch for work the loop will skip anyway). In a single `Agent` tool-call message, dispatch `project-enricher` once per project in `dispatch_set`. Cap 10 concurrent dispatches (mirrors Phase 1 § 1.2 Dispatch per `commands/weekly.md`); batch sequentially in groups of 10 if `dispatch_set.length > 10`. Prompt body per dispatch: `project_id`, `project_name`, `audit_card` (full Phase 1 output for this project), `cycle.current`, `cycle.previous`, `team_id`, `cross_project_stats`. Parse each returned JSON block into `state.projects[i]._enrichment` keyed by project id. On any `_enrichment.dispatch_error` (non-null), halt the pre-loop and surface `AskUserQuestion` with three options: **Retry** (re-dispatch only the failed projects with fresh Agent calls), **Pause session** (do NOT append `phase-2` to `completed_phases`; leave state unchanged; write breadcrumb `current_phase = "phase-2"`; exit cleanly), **Proceed without enrichment for failed projects** (explicit spec-departure: set `_enrichment.backlog_candidates = []` + `_enrichment.carry_over_enriched = []` + `_enrichment.brainstorming_ranked = []` for that project so downstream `.find()`/`.length` calls return empty rather than throwing on `undefined`, and free-text-prompt the user for SQ2 IDs when that project's turn comes; log under `state.projects[i].skip_log`). NEVER silent degradation — this is the BC-5896 AC fail-loud contract.

**For each `state.projects[i]` selected in Phase 0.3 (`status.type == "started"`, deduped by id):**

1. **Resume skip.** If `state.projects[i].name ∈ state._scoped_project_names`, set `state.projects[i].scope_confirmed = true` and continue to the next project. Log: `Project <name> already scoped — skipping (resume).` If this is the last project and it was already scoped, exit the loop cleanly.
2. **Enrich carry-over** — Read `state.projects[i]._enrichment.carry_over_enriched[]` populated by the § 2 pre-loop enricher dispatch (this is a flat array of `{id, blocker_count, auto_superseded_by, title, priority, assignee, issue_snapshot}`, not a map). For each audit-card carry-over issue, look up its enrichment entry via find-by-id: `const entry = _enrichment.carry_over_enriched.find(e => e.id === audit_card_issue.id)` — if no match (enricher hit an individual `get_issue` error for that issue, or Proceed-without-enrichment was chosen), log a one-line skip under `state.projects[i].skip_log` ("carry-over enrichment missing for BC-XXXX — fell through to defaults") and skip hydration for that issue. If `entry` is present, hydrate the matching `audit_card.carry_over.issues[i]` with: `enriched.blocker_count = entry.blocker_count`, `enriched.auto_superseded_by = entry.auto_superseded_by`. **Populate `_fetched_issues` from snapshot (BC-5902):** if `entry.issue_snapshot` is present, write it to `state.projects[i]._fetched_issues[audit_card_issue.id]` so Phase 3 § 3 pre-flight's reuse ladder step 1 hits the cache and skips the redundant `get_issue` per carry-over. No additional MCP reads in Phase 2 — the enricher already did the parallel `get_issue` fan-out with `includeRelations: true`. Bounded cost — work is a dict merge plus N `.find()` lookups over the enrichment array (N = carry-over count per project, typically <10).
3. **Run § 3 carry-over interview** (skipped entirely if `carry_over.count == 0` per BC-5810 § 2.3).
4. **Run § 4 scope interview**.
5. **Run § 5 quality gate** on every issue ID in `q2_ship_ids` (pre-fan-out `get_issue` for any ID not already in `_fetched_issues`).
6. **Run § 6 checkpoint append**.

After all projects: **§ 7 cross-project bottleneck pass**.

## § 3 Carry-over interview (5 questions per issue)

<!-- gate-respect: honor user pick; re-prompt before any behavior change — applies to every CQ1–CQ5 AskUserQuestion in this section. -->

For **every** issue in `state.projects[i].audit_card.carry_over.issues[]` (not just the highest-priority one — BC-5897), ask the 5 questions from BC-5810 § 2.1 verbatim. Iteration order is `carry_over.issues[]` array order (Phase 1 audit sorts by priority already). No priority-filter / rank-filter on block entry — only question-level adaptive-skip from § 2.3 applies.

Each question is a **separate** `AskUserQuestion` tool call. **No batching, condensing, or consolidation — ever.** This applies regardless of carry-over count, project count, or context pressure. Specifically banned improvisation patterns (origin: BC-5865 W17 dogfood):

- *"condensed-prompt"* / *"consolidated AskUserQuestion"* / *"pragmatic condensed pattern"* — any phrasing that batches 2+ CQs into one call.
- *"batched carry-over block"* / *"skip the strict interview for projects without carry-over"* — any phrasing that groups CQs by issue or selectively batches across issues.

Adaptive-skip (§ 2.3) may drop a question entirely with a `skip_log` entry — it may **never** merge a question with another. Hard rule per `memory/feedback_one_question_at_a_time.md`. Skip rules from BC-5810 § 2.3 are evaluated *before* each `AskUserQuestion` call; skipped questions append a one-line entry to `skip_log`.

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

<!-- gate-respect: honor user pick; re-prompt before any behavior change — applies to every SQ1–SQ5 AskUserQuestion in this section. No condensed/batched alternatives, ever. -->

Once per project after carry-over completes (or immediately if carry-over was skipped). If `state.projects[i].status.type == "parked"` (from the Linear project shape captured in Phase 0.3, not from the audit card), only SQ1 is asked (for acknowledgement) and SQ2–SQ5 are skipped + logged.

**Scope candidate injection from enricher.** Before SQ2, read `state.projects[i]._enrichment.brainstorming_ranked[]` populated by the § 2 pre-loop `project-enricher` dispatch. The top-ranked candidate (`rank == 1`) becomes SQ2's `(Recommended)` default in the `AskUserQuestion` call; alternatives at ranks 2–3 become options 2–3. No main-thread `workflows:brainstorming` Skill call — the enricher already ran the ranker logic with the same inputs (carry-over count, backlog-high count, shipped-pace, owner-load hint). If `brainstorming_ranked` is empty (e.g. enricher fell back to `Proceed without enrichment`), SQ2's default becomes `"carry-over only — no backlog proposals"` and the user escape-path "Other" carries free-text. **(Closes BC-5867 — brainstorming ranker moves from spec-misfit inline Skill call to dispatched subagent output consumed as data — BC-5902.)**

The 5 questions from BC-5810 § 2.2 verbatim. **Each a separate `AskUserQuestion` call. No batching, condensing, or consolidation — ever.** This applies regardless of carry-over status, project count, or context pressure. Specifically banned improvisation patterns (origin: BC-5865 W17 dogfood):

- *"one consolidated scope AskUserQuestion per project"* — exactly what the agent improvised during W17 for the 16 no-carry-over projects. Do not do this.
- *"pragmatic condensed pattern"* / *"condensed-prompt"* / *"consolidated"* / *"batched scope questions"* — any phrasing that collapses 2+ SQs into one call.

SQ1's answer constrains SQ2's option set (SQ1's headline drives SQ2's viable issue IDs); asking them simultaneously breaks the decision tree. If the condensed form ever feels justified, file a spec amendment to BC-5810 — do not improvise here.

**No-signal SQ1 fallback.** When `state.projects[i]._enrichment.carry_over_enriched.length == 0` AND `state.projects[i]._enrichment.backlog_candidates` is empty (or every entry has `priority.value >= 3` Medium/Low), SQ1's `(Recommended)` default switches from an agent-drafted headline to *"Owner picks next track — free-text (Recommended)"* — the agent does NOT invent a fake default. SQ1 is still asked (no `skip_log` entry — this is a default-switch, not a skip); the user's free-text answer becomes the headline verbatim. SQ2–SQ5 still ask normally with the `brainstorming_ranked` empty fallback (see paragraph above) handling SQ2. **(Closes BC-5900 — codifies the W17 attempt-2 honest-abstention path as spec-compliant per `docs/designs/cadence-orchestration.md` § 2.3 no-signal row, rather than rendering a "spec departure noted" annotation.)**

**Ritual close-out fallback.** When `state.projects[i].audit_card.shipped.count >= 3` AND `state.projects[i].audit_card.carry_over.count == 0` AND `state.projects[i].audit_card.dropped.count == 0` AND `len(set(state.projects[i].audit_card.shipped.issues[*].assignee)) == 1` AND `state.projects[i].audit_card.shipped.issues[0].assignee != "(unassigned)"` AND `state.projects[i]._enrichment.dispatch_error == null` AND `state.projects[i]._enrichment.backlog_candidates` is empty (or every entry has `priority.value >= 3` Medium/Low), SQ1's `(Recommended)` default switches from an agent-drafted headline to *"Defer to offline touch-base with owner (Recommended)"* with the 3-option lock from § 4.2 below. SQ1 is still asked (no `skip_log` entry — this is a default-switch, not a skip). SQ2–SQ5 are SKIPPED for this project and logged: `state.projects[i].skip_log` gets one entry per skipped question with reason `"ritual close-out — single owner consistent shipping, no signal for new scope"`, and `state.projects[i].scope_decisions.ritual = true` is set so Phase 4's narrative-writer renders the project as a Ritual Cadence card rather than a Sprint Plans card. **(Closes BC-5901 — codifies the W17 attempt-2 skill-invented ritual-project degradation across Meeting Auto / Brite Training / Partnership Management / Comm Infra as spec-compliant per `docs/designs/cadence-orchestration.md` § 2.3 ritual close-out row, rather than rendering a "spec departure noted" annotation.)**

**Ritual vs no-signal precedence.** Both the BC-5900 no-signal SQ1 fallback (line 108 above) and this BC-5901 ritual close-out fallback can co-fire on the same project — when audit shows zero carry-over AND backlog is empty/Medium-Low, both predicates are true. The ritual rule takes precedence over no-signal: single-owner consistent shipping (3+ shipped, zero dropped, zero enricher error) is a stronger signal than empty-backlog alone, and the ritual path skips SQ2–5 while no-signal still asks them — running both yields contradictory behavior. Evaluation order: check ritual conjuncts first; only if any conjunct fails fall through to the no-signal check.

| Q-ID | Question | Recommended default |
|---|---|---|
| SQ1 | Headline outcome sentence for `<project>`? | Agent draft from top-priority carry-over + top backlog *(or free-text "Owner picks next track" if both empty — see no-signal fallback above; or 3-option lock when ritual close-out fires — see § 4.2 below)* |
| SQ2 | Which issue IDs ship this cycle? | Brainstorming output (top-ranked candidates; quality-gate filtering runs in § 5 on the user's picks, not here) |
| SQ3 | Owner per issue, if different from existing? | Keep existing assignees |
| SQ4 | Dependencies between picked issues? | Agent infers from descriptions + `relations.blockedBy` |
| SQ5 | Explicitly parked this cycle? | Agent proposes from stale current-cycle items + Low-priority carry-over |

### § 4.1 SQ3 option lock

<!-- gate-respect: honor user pick; re-prompt before any behavior change — SQ3 option set is locked to the three items below, Other escape always available. -->

SQ3's `AskUserQuestion` MUST render exactly three options (plus the implicit "Other" free-text escape):

1. **Keep existing assignees** `(Recommended)`
2. **Reassign to `<name>`** — single-assignee change; one target name
3. **Mark unassigned** — clears `assignee` to `null`

Linear has exactly one `assignee` field per issue. SQ3 maps 1:1 to that field. Specifically banned improvisation patterns (origin: BC-5872 W17 attempt1 dogfood):

- *"Add co-owner"* / *"co-owner on <ID>"* — no such field in Linear; if picked, Phase 3 silently drops the second assignee or silently replaces the first.
- *"co-watcher"* / *"Add subscriber as co-owner"* — `subscribers` is a watchers list, not an owners list. Reframing ownership as watching persists a different semantic mismatch.
- *"multi-assignee"* / *"multiple assignees"* / *"Holden + Rainer both on BC-XXXX"* — any phrasing that implies a list-valued assignee.

If co-ownership becomes a legitimate weekly pattern, file a spec amendment to BC-5810 § 2.2 — do not improvise here. The escape path for one-off co-lead intent is the Phase 5 manual-ops checklist (the planner writes a freeform row after the run); SQ3 itself stays locked to the three options above.

### § 4.2 SQ1 ritual option lock

<!-- gate-respect: honor user pick; re-prompt before any behavior change — SQ1 option set under § 2.3 ritual close-out is locked to the three items below, Other escape always available. -->

When the § 2.3 ritual close-out row fires (see "Ritual close-out fallback" prose above), SQ1's `AskUserQuestion` MUST render exactly three options (plus the implicit "Other" free-text escape):

1. **Defer to offline touch-base with owner** `(Recommended)` — sets `q1_headline = "Continue cadence — owner picks next track offline"` and proceeds to skip SQ2–5 (logged in `skip_log` per the ritual fallback prose).
2. **Park this cycle** — sets `scope_decisions.q5_parked = "<project> — parked this cycle, owner unavailable"` and routes to Parked This Week instead of Ritual Cadence in Phase 4.
3. **Specify scope instead** — overrides the ritual flag (`scope_decisions.ritual = false`), unlocks SQ1 free-text, and runs SQ2–5 normally. Use when the audit signal is correct but the planner has unsurfaced backlog or a deliberate stretch goal.

Specifically banned improvisation patterns (origin: BC-5901 W17 attempt-2 dogfood across 4 ritual-pattern projects):

- *"redundant free-text Option N + Other Option N+1 pattern"* — exposing a fake "Option 4: free-text" that duplicates the implicit Other escape. Lock the option set to three; planner uses Other to deviate.
- *"merge SQ1 and SQ5 into a defer-and-park combo option"* — keep park-this-cycle and specify-instead distinct from defer-offline; they map to different downstream renders (Ritual Cadence card vs Parked This Week table vs Sprint Plans card).

## § 5 Quality gate + block-with-override

<!-- gate-respect: honor user pick; re-prompt before any behavior change — applies to the 3-option AskUserQuestion per failing check below. -->

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

**Ritual close-out checkpoint render (BC-5901).** When `scope_decisions.ritual == true` (the SQ1 § 4.2 lock fired), append a `**Ritual close-out:** true` line immediately after `**Headline:**` and skip the per-section bullet list (Carry-over, Ship this cycle, etc.) — render the freeform body as a single one-liner: `Ritual cadence — owner picks next track offline.` (or the SQ1 free-text answer when the planner picked Other). Required so § 0.5.4 Resume parse can rehydrate `scope_decisions.ritual` from disk (the parser keys on the `**Ritual close-out:**` line); without it, a resumed Phase 4 silently demotes ritual-flagged projects back to Sprint Plans cards.

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
