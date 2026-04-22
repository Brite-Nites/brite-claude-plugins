---
description: Run the weekly planning loop — audit, scope, housekeep, narrate
---

# /cadence:weekly

Five-phase weekly planning loop. Replaces the manual W15/W16 checkpoint + narrative flow.

> **Status: feature-complete, pre-dogfood.** Phases 0–5 are implemented. End-to-end dogfood against W18 planning data (BC-5763) is the last gate before production.

## Phase 0: Preflight

Run every session before any phase work. All four checks are fail-closed — if any block errors, stop and report the specific failure to the user.

### 0.1 Linear MCP connectivity

Call `mcp__plugin_workflows_linear-server__list_projects` with `limit: 1`. On success, confirm "Linear MCP: OK". On failure, stop with: "Linear MCP is not reachable. Run `/workflows:smoke-test` to diagnose."

### 0.2 Current cycle detection

<!-- gate-respect: honor user pick; re-prompt before any behavior change. -->
<!-- cycle-window format: `<startsAt> → <endsAt − 1 day>`. Linear's `endsAt` is exclusive (equals next cycle's `startsAt`); subtract 1 day for the inclusive last day. Applies to every cycle-window render — § 0.2, § 0.3, § 5.2, narrative-writer H2. Raw `state.cycle.current.endsAt` stays as-is for idempotency predicates and `cycle.id` equality. Origin: BC-5868 (W17 dogfood cosmetic fix). -->

Call `mcp__plugin_workflows_linear-server__list_cycles` with `type: "current"` scoped to the Brite Company team (`teamId` required per BC-5757 § 2.3 — cycle queries need the UUID, not the team name). Extract the cycle `name`, `startsAt`, `endsAt`. Present via `AskUserQuestion`:

> Current cycle appears to be **W##** (`<startsAt>` → `<endsAt − 1 day>`). Is this the week you want to plan?

Options: (Recommended) "Yes, plan W##"; "Use a different cycle" (free-text); "Cancel".

### 0.3 Active project count echo

<!-- gate-respect: honor user pick; re-prompt before any behavior change. -->


Call `mcp__plugin_workflows_linear-server__list_projects` with pagination (the `state: "started"` + team filter returns empty — list all and filter client-side per BC-5757 § 2.3). Filter to `status.type == "started"`. For each selected project, store `{id, name, status, owner: project.lead.name || null}` in `state.projects[]` — `owner` is the Linear project lead's display name (null if the project has no lead), consumed by Phase 4's narrative-writer Sprint Plans cards. Echo the count and top 5 by `updatedAt`:

> **W<NN>** (`<startsAt>` → `<endsAt − 1 day>`) — **N active projects** will be audited this session. Top 5 most recent: `<project>`, `<project>`, …

`AskUserQuestion`: "Proceed with all N, or pick a subset?" Default: "All N (Recommended)". Escape: "Pick a subset" (free-text comma-separated project names).

### 0.4 GitHub integration probe

Per BC-5811 § 4.2, the Cadence plugin does not register a GitHub MCP. Phase 5's connectivity check uses `gh` CLI via Bash. Probe:

```bash
gh auth status 2>&1 | head -3
```

If `gh` is authenticated, report "GitHub: gh CLI ready". If not, report "GitHub: `gh auth login` required before Phase 5 connectivity check" — Phase 5 will skip the per-project GitHub probe and narrate it as "GitHub integration unavailable this session."

Do not stop on GitHub probe failure — Phases 1–5 do not require it.

## Phase 0.5: Week folder + resume detection

After Phase 0 preflight succeeds, ensure the week folder exists and check for a prior partial run.

### 0.5.0 Resolve prior cycle

Before artifact validation (§ 0.5.2) can reference `state.cycle.previous.id`, that field must be populated. Call `mcp__plugin_workflows_linear-server__list_cycles` with `teamId: state.team.id` and `type: "previous"`. Capture `id`, `title`, `startsAt`, `endsAt`, `completedIssueCountHistory`, `issueCountHistory`. Store as `state.cycle.previous`. (`state.cycle.current` was populated in Phase 0.2 — that's the cycle being *planned*; this previous cycle is the one being *audited*.)

**Failure semantics (fail-closed like other Phase 0 steps):**
- MCP error → stop with: `"Prior cycle lookup failed. Run /workflows:smoke-test to diagnose, then /cadence:weekly to retry."`
- Empty response (first-ever cycle for this team — no prior cycle exists) → stop with: `"No prior cycle found. /cadence:weekly requires a completed cycle to audit. Re-run once Week 1 completes."`

Phase 1 § 1.0 is now a cache-hit no-op: if `state.cycle.previous.id` is already populated (as it will be after Phase 0.5.0), Phase 1 § 1.0 skips the redundant MCP call and proceeds directly to § 1.1 idempotency.

### 0.5.1 Resolve week folder + breadcrumb path

Pre-extract `CYCLE_NN` (numeric week from `state.cycle.current.name`, e.g. `"W17"` → `17`) and `CYCLE_DATE` (`state.cycle.current.startsAt` formatted `YYYY-MM-DD`). Reject if `CYCLE_DATE` does not match `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`. In Bash, with runtime guards:

```bash
[[ "$CYCLE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "Invalid CYCLE_DATE: $CYCLE_DATE" >&2; exit 1; }
[[ "$CYCLE_NN" =~ ^[0-9]+$ ]] || { echo "Invalid CYCLE_NN: $CYCLE_NN" >&2; exit 1; }
WEEK_NN=$(printf "%02d" "$CYCLE_NN")
ROOT=$(git rev-parse --show-toplevel)
WEEK_DIR="$ROOT/../weekly-planning/w${WEEK_NN}-${CYCLE_DATE}"
mkdir -p "$WEEK_DIR"
BREADCRUMB="$WEEK_DIR/.cadence-phase-state.json"
```

If `state.weekly_planning_root` is set, use it as the prefix instead of `$ROOT/..` (mirrors Phase 2 § 6 + Phase 3 § 7.1). Cache at `state.phase_state.breadcrumb_path`.

### 0.5.2 Detect + validate

If `$BREADCRUMB` does not exist: initialize `state.phase_state = { cycle_id: state.cycle.current.id, cycle_name: state.cycle.current.name, current_phase: "phase-1", completed_phases: [], updated_at: <ISO-8601 now>, breadcrumb_path: $BREADCRUMB }`. Write the JSON file. Proceed to Phase 1.

If the file exists, `Read` it and parse as JSON. Validate:

- `breadcrumb.cycle_id == state.cycle.current.id` — if mismatch, warn user: `Prior breadcrumb for cycle <breadcrumb.cycle_id> found but current planning cycle is <state.cycle.current.id>. Ignoring breadcrumb.` and initialize fresh per the "no breadcrumb" branch above.
- For each phase ID in `breadcrumb.completed_phases`, verify the artifact on disk:

  | Phase | Artifact check |
  |---|---|
  | `phase-1` | `<WEEK_DIR>/audit.json` exists, parses as JSON, and top-level `cycle.id == state.cycle.previous.id` |
  | `phase-2` | checkpoint (`w<NN>-planning-checkpoint.md`) exists AND the count of `### N. ` lines ≥ `state.projects.length` |
  | `phase-3` | housekeeping log (`w<NN>-housekeeping-log.md`) exists AND contains a populated `## Execution summary` section (i.e. not just the stub header) |
  | `phase-4` | narrative (`w<NN>-sprint-narrative.md`) exists AND matches all 6 required `## ` headers (Context / Strategic Decisions / Sprint Plans / Parked This Week / Check-in Schedule / Team Assignments) |
  | `phase-5` | ops (`w<NN>-remaining-ops.md`) exists AND contains all four required `## ` headers (Linear manual ops / Calendar / Share / Phase-3 follow-up) |

Any failing artifact check downgrades that phase and every later phase back to pending: remove them from `completed_phases`, set `current_phase` to the earliest downgraded phase, rewrite breadcrumb. Log the downgrade reason per phase.

### 0.5.3 Resume prompt

<!-- gate-respect: honor user pick; re-prompt before any behavior change — the Resume / Restart / Cancel pick is load-bearing for state management. Never self-downgrade to "Restart" when the user picked "Resume" or vice versa. -->

If `completed_phases` is non-empty after validation, `AskUserQuestion`:

> *"Prior /cadence:weekly run for W<NN> found. Completed phases: <list>. Resume at <current_phase>?"*

| Option | Effect |
|---|---|
| **Resume at `<current_phase>`** *(Recommended)* | Run § 0.5.4 to rehydrate state from artifacts; jump the control flow to the first not-yet-completed phase. |
| **Re-run from Phase 1** | Reset breadcrumb (`completed_phases: []`, `current_phase: "phase-1"`); prior artifacts remain on disk but phases re-run in order and overwrite them. |
| **Cancel session** | Exit cleanly; breadcrumb unchanged. |

If `completed_phases` is empty (e.g. a prior run failed in Phase 1 before the audit.json write), skip the prompt and start at Phase 1 — no user ask is needed when there's nothing to resume.

### 0.5.4 Rehydrate state from artifacts (on Resume)

- **From `audit.json`:** populate `state.projects[].audit_card` + `state.cross_project_stats`. Files are deterministic JSON so this is a direct parse.
- **From checkpoint:** parse each `### N. <Project>` block into `state.projects[i].scope_decisions` (headline, ship IDs, reassignments, parked). Parse `## Cross-project flags` bullets into `state.bottleneck_warnings`. Populate `state.projects[i].overrides` from any callouts that cite override reasons.
- **From housekeeping log:** parse the `## Mutations` table into `state._executed_mutation_ids[]` and the summary counts into `state.mutations[]` summary fields consumed by Phase 4's `mutations_summary` dispatch.
- **From narrative:** `state.narrative_path = <path>`; `state.narrative_draft = <file contents>` (in case user picks Edit post-resume).
- **From ops:** `state.ops_path = <path>`.

Rehydration is read-only — no Linear MCP calls. If the planner made out-of-band changes to Linear since the prior run, Phase 3's pre-flight checks catch them when that phase runs; Phase 1's audit is not re-issued since its artifact was just validated.

**Rehydration row shape for `state.mutations[]`.** Parse each row of the housekeeping log's `## Mutations` table. For each column: `Timestamp` → `started_at` + `executed_at`; `Decision path` → `decision_path`; `Mutation type` → `mutation_type`; `Issue` cell → extract leading `^BC-\d+` into `target.id` and keep the full cell text for display; `Before`/`After` columns are not re-derived on resume (no consumer reads them post-execute); `Gate` → `gate_status`; `Result` → `result`; `Error` → `error`. Append to `state.mutations[]`. Phase 4 § 4.2's `mutations_summary` counts + Phase 5 § 5.2's errored-row enumeration (`r => r.result == "errored"`) both read the rehydrated full rows — do not reduce to counts at rehydration time.

### 0.5.5 Phase-exit breadcrumb update (canonical pattern)

Every phase ends with a breadcrumb update so resume (§ 0.5.2) can reason about what's complete. Each phase ID (`phase-1` through `phase-5`) appends at the phase's terminal step (Phase 1 § 1.7 Proceed branch, end of Phase 2 cross-project flags, Phase 3 § 7.5 log close-out, Phase 4 § 4.6, Phase 5 § 5.3). The three-step pattern:

1. Append the phase ID to `state.phase_state.completed_phases` (in order).
2. Set `state.phase_state.current_phase` to the next phase ID (or `"complete"` after phase-5).
3. Refresh `state.phase_state.updated_at` with the current ISO-8601 timestamp. Write the breadcrumb JSON to `state.phase_state.breadcrumb_path`.

Per BC-5761 gotcha: the breadcrumb append is the *last* step, after all of the phase's artifacts (audit.json / checkpoint / housekeeping log / narrative / ops) have landed on disk. Writing the breadcrumb earlier would let a killed session resume with a phase marked "complete" but artifact missing.

## Gates Between Phases

Three `AskUserQuestion` gates, per BC-5810 § 1:

- **Gate #1** — after Phase 1 audit (§ 1.7): show audit summary, user approves moving to scope.
- **Gate #2** — inside Phase 3 housekeeping (§ 6): per-group approval + final "Execute now" gate, before any Linear write.
- **Gate #3** — inside Phase 4 narrative (§ 4.4): show draft + voice-check violations, user approves file + PDF write.

Phase 2 has no gate (falls straight into Phase 3 preview). Phase 5 is un-gated — see `plugins/cadence/CLAUDE.md` § Gotchas for rationale. Gates use the `AskUserQuestion` convention — first option wins `(Recommended)`, "Other" is the escape hatch.

## Gate-respect

Every multi-option `AskUserQuestion` in this command — cycle confirmation (§ 0.2), project-count subset prompt (§ 0.3), resume menu (§ 0.5.3), Gate #1 (§ 1.7), Phase 2 enricher dispatch-error prompt (§ 2), Phase 3 preflight dispatch-error prompt (§ 3), Gate #3 narrative approval (§ 4.4), PDF-export fallback prompt (§ 4.5) — is bound by the [gate-respect contract](../skills/_shared/gate-respect.md). Once the planner picks an option, execute exactly that option. If any downstream step wants to deviate, re-prompt via a new `AskUserQuestion`. Mentions in the phase-state breadcrumb, the dogfood-notes, or the housekeeping log do NOT constitute user authorization. Origin: BC-5866 (W17 dogfood class-bug fix).

## Session State Object

Phases flow via a single session-scoped state object. No re-fetching from Linear between phases. Schema owned by BC-5758 follow-ups; initial shape per BC-5810 § 1.3:

```
{
  "team":  { "id", "name" },
  "cycle": {
    "current":  { "id", "name", "startsAt", "endsAt" },
    "previous": { "id", "title", "startsAt", "endsAt", "issueCountHistory", "completedIssueCountHistory" }
  },
  "projects": [ {
      "id", "name", "status", "owner",       // id/name/status/owner(=lead.name or null) from Phase 0.3 list_projects
      "audit_card",                          // populated by Phase 1 project-audit agent. NOTE (BC-5902): the prior backlog-high count + candidates fields are removed from audit_card — enricher now owns that data under _enrichment.backlog_candidates[]
      "_enrichment": { /* Phase 2 project-enricher agent output — populated by sprint-scoping § 2 pre-loop (BC-5902) */
        "backlog_candidates": [ { "id", "title", "priority", "assignee", "assigneeId", "cycleId", "stateName" } ],
        "carry_over_enriched": [ { "id", "blocker_count", "auto_superseded_by", "title", "priority", "assignee", "issue_snapshot": { "cycleId", "stateType", "assigneeId", "labelIds" } } ],
        "brainstorming_ranked": [ { "id_or_title", "rationale", "rank" } ],
        "enriched_at": "<ISO-8601>",
        "dispatch_error": null | "<message>"
      },
      "scope_decisions", "overrides",        // populated by Phase 2 sprint-scoping skill; scope_decisions shape = {q1_headline, q2_ship_ids, q3_reassignments, q4_dependencies, q5_parked, carry_over_answers[]} per sprint-scoping SKILL.md § 1
      "skip_log", "scope_confirmed",         // populated by Phase 2 sprint-scoping skill
      "_fetched_issues"                      // Phase 2 carry-over + gate fetch cache — populated on-demand by Phase 3 § 3 pre-flight when not already present; enricher writes _enrichment.carry_over_enriched[] instead of this cache during Phase 2.
  } ],
  "cross_project_stats": { "completion_rate", "shipped_total", "carry_over_total", "dropped_total", "team_standouts", "unplanned_ratio" },
  "bottleneck_warnings": [ { "assignee", "count", "issues" } ],   // Phase 2 sprint-scoping § 7
  "bottleneck_threshold": 4,                                      // Phase 2 config (default 4)
  "weekly_planning_root": null,                                   // Phase 2 optional path override
  "checkpoint_path": null,                                        // Phase 2 resolves once at entry
  "_scoped_project_names": [],                                    // Phase 2 resume cache
  "leadership_planning_notes": null,                              // Phase 2 optional input
  "mutations": [ {                                                // Phase 3 linear-housekeeping populates
      "id", "decision_path", "mutation_type",
      "target": { "kind", "id", "name", "projectId" },
      "before": {…}, "after": {…},                                // both carry ID-form + name-form fields
      "gate_status", "gate_detail": [...], "override_reason",
      "approved" /* bool, set by Phase 3 § 6 group approval */, "started_at", "executed_at", "result", "error", "source_project"
  } ],
  // Phase 3 is authoritative for the mutation row shape — see
  // plugins/cadence/skills/linear-housekeeping/SKILL.md § 2.1.
  "_preflight_manifest": { /* Phase 3 housekeeping-preflight agent output — populated by linear-housekeeping § 4 (BC-5902) */
    "preflight_at": "<ISO-8601>",
    "manifest": { "[mutation_id]": { "issue_id": "<id>", "gate_detail": [ { "check", "status", "message", "matched_reason" } ], "issue_snapshot": { "cycleId", "stateType", "assigneeId", "labelIds" } } },
    "row_errors": [ { "mutation_id", "issue_id", "error" } ],
    "dispatch_error": null | "<message>"
  },
  "phase_3_spec_departure": null,                                 // Phase 3 § 4 sets e.g. "preflight-skipped-user-override" on BC-5898 Execute-without-preflight path; read by § 7.5 log + Phase 4 narrative Known gaps callout
  "_mutation_conflicts": [ {                                      // Phase 3 § 2.5 cross-project dedup
      "issue_id", "source_projects": [ ... ], "conflicting_targets": [ ... ]
  } ],
  "_cq3_parse_errors": [ {                                        // Phase 3 § 2.2 CQ3 free-text parse failures
      "project_id", "issue_id", "raw_cq3_answer"
  } ],
  "_create_preflight_cache": { /* [projectId]: list_issues-response */ },  // Phase 3 § 3 per-project list_issues memoization
  "housekeeping_log_path": null,                                  // Phase 3 resolves once at § 7 entry
  "_executed_mutation_ids": [],                                   // Phase 3 resume cache
  "narrative_draft": null,                                        // Phase 4 holds the in-memory draft between § 4.2 and § 4.4 approval
  "narrative_path": null,                                         // Phase 4 resolves at § 4.1 (idempotency) / § 4.4 (write)
  "pdf_path": null,                                               // Phase 4 resolves at § 4.5 export (primary or fallback)
  "pdf_method": null,                                             // Phase 4: "primary-md-to-pdf" | "fallback-clipboard" | "skipped"
  "primary_retries": 0,                                           // Phase 4 § 4.5 fallback retry counter; capped at 2 before Retry option is greyed (lives in state, not bash, because decisions span multiple Bash tool calls)
  "ops_path": null,                                               // Phase 5 resolves at § 5.1 / § 5.2
  "phase_state": {                                                // Phase 0.5 breadcrumb; updated at each phase entry and exit
    "cycle_id": null,                                             // equals state.cycle.current.id; guard against cross-cycle resume
    "cycle_name": null,                                           // equals state.cycle.current.name; rendered to user on resume prompt
    "current_phase": null,                                        // "phase-1" | "phase-2" | "phase-3" | "phase-4" | "phase-5" | "complete"
    "completed_phases": [],                                       // append-only, in the order each phase exits successfully
    "updated_at": null,                                           // ISO-8601 timestamp of the last breadcrumb write
    "breadcrumb_path": null                                       // absolute path to .cadence-phase-state.json in the week folder
  }
}
```

`cycle.current` is populated by Phase 0.2 (the cycle the user is *planning*); `cycle.previous` is populated by Phase 1 § 1.0 (the cycle being *audited*). `team` is populated by Phase 0 (`list_teams` lookup of `"Brite Company"` — currently inlined per the Phase 1 prerequisite note below). `cross_project_stats.unplanned_ratio` and per-assignee planned attribution require a prior-narrative parser tracked as a sibling follow-up (see BC-5821 — Cadence prior-narrative parser); until that ships, the field remains `null` and Phase 4 narrative falls back to raw cycle-completion ratios.

## Phase 1: Audit

Batch fan-out — one `project-audit` subagent per active project, parallel, capped at 10 concurrent. Each subagent produces a structured audit card; the main thread merges the cards and computes cross-project stats. Read-only — no Linear mutations in this phase.

> **Phase 0 prerequisite (out of scope for this issue):** Phase 0 must populate `state.team.id` via a one-time `list_teams` lookup of `"Brite Company"`. Until that lands, dispatchers may resolve it inline. Issue tracked separately as a Phase 0 enhancement.

### 1.0 Resolve prior cycle (cache-hit aware)

Phase 0.5.0 already populated `state.cycle.previous` during preflight. If `state.cycle.previous.id` is non-null, skip the MCP call and proceed to § 1.1. Otherwise (standalone `--resume-phase 1` invocation that bypassed Phase 0.5), call `mcp__plugin_workflows_linear-server__list_cycles` with `teamId: state.team.id` and `type: "previous"`, capture `id`, `title`, `startsAt`, `endsAt`, `completedIssueCountHistory`, `issueCountHistory`, and store as `state.cycle.previous`.

### 1.1 Idempotency check

Construct the audit file path: `$WEEK_DIR/audit.json` (the current-cycle week folder resolved by Phase 0.5.1, not the previous cycle's folder — every phase's artifact lives under the cycle being *planned*, even when the artifact's content describes the *audited* cycle; the internal `cycle.id` field inside audit.json identifies the audited/previous cycle). If the file exists, parse it as JSON, and `cycle.id == state.cycle.previous.id`, populate `state.projects[].audit_card` + `state.cross_project_stats` from the file and skip to § 1.6 (synthesis). Log: `Phase 1 audit cached — re-using audit.json (0 dispatches).`

### 1.2 Dispatch

For each project in `state.projects[]` (already filtered to `status.type == "started"` and deduped by `id` in Phase 0.3), dispatch the `project-audit` subagent with a prompt body containing:

- `project_id`, `project_name`
- `cycle_id` (= `state.cycle.previous.id`), `cycle_title`, `cycle_window` (= `{startsAt, endsAt}`)
- `team_id` (= `state.team.id`)

Send all dispatches in a single `Agent` tool message to run them in parallel. Cap concurrent in-flight subagents at **10**; if `state.projects[].length > 10`, batch sequentially in groups of 10. Reason: Linear MCP throughput observed at ~10 in-flight calls.

### 1.3 Merge

Parse each subagent's returned JSON block into `state.projects[<index>].audit_card`. If a subagent returned an `error` field, record `audit_card = {error, project_id, project_name}` and continue with the rest.

### 1.4 Cross-project synthesis

Compute and store under `state.cross_project_stats`:

- `completion_rate` = `sum(p.audit_card.shipped.count) / state.cycle.previous.issueCountHistory[0]` (denominator is day-1 scope per BC-5757 § 2.2 gotcha).
- `shipped_total`, `dropped_total`, `carry_over_total` (each = sum across projects).
- `team_standouts` = list of assignees with completion ratio ≥90% in this cycle, where ratio = `shipped_count / (shipped_count + carry_over_count + dropped_count)` from the `by_assignee` rollups. Only count assignees with `(shipped + carry_over + dropped) ≥ 3` to avoid noise from one-issue owners.

**Deferred to a sibling follow-up (BC-5821 — Cadence prior-narrative parser):**

- `unplanned_ratio` — needs `planned_count_from_prior_narrative`, which only the prior-narrative parser can extract. Phase 1 leaves the field `null`; BC-5821 will populate it by parsing the prior `w<NN-1>-sprint-narrative.md` for declared planned scope, then updating Phase 1 § 1.4 synthesis + Phase 1 § 1.6 headline anchors to include it.
- Per-assignee *planned* attribution — same dependency. AC #4's "≥90% planned completion" framing is approximated by the cycle-completion ratio above until BC-5821 lands.

### 1.5 Persist audit file

Write `{cycle: state.cycle.previous, cross_project_stats: state.cross_project_stats, audit_cards: <every state.projects[].audit_card>}` to `audit.json` at the path constructed in § 1.1. The top-level `cycle` field is what § 1.1's idempotency predicate (`parsed.cycle.id == state.cycle.previous.id`) reads. Pretty-print (2-space indent) for `git diff` legibility.

### 1.6 User-facing synthesis (≤300 words)

Render to the user:

1. **Headline anchors** — one line: `<completion_rate>% completion / <shipped_total> shipped / <carry_over_total> carrying over / standouts: <team_standouts>`. (Note: `unplanned_ratio` headline lands in Phase 2 once the narrative parser extracts the planned baseline — see § 1.4 deferred list.)
2. **Per-project drift bullets** — one line per project: `**<project>** — <shipped> shipped, <carry_over> carrying over, <dropped> dropped. <highest-priority carry-over ID if any>`.
3. **Audit gaps** subsection — only if any subagent failed: list each failed project + the suggested retry command (`/cadence:weekly --resume-phase 1 --project <name>`).
4. **Quality flags** subsection — only if any flagged: one line per flag — `<issue_id> — <check>: <message>`.

Do not batch projects into categories. Surface every project, even ones with zero activity, per `memory/feedback_thorough_audits.md`.

### 1.7 Gate #1

<!-- gate-respect: honor user pick; re-prompt before any behavior change. -->

Call `AskUserQuestion`:

> *"Audit complete. <N> projects audited, <shipped_total> shipped, <carry_over_total> carrying over. Proceed to Phase 2 scope?"*

Options:

- **"Proceed to Phase 2"** — `(Recommended)` — apply the § 0.5.5 breadcrumb update with `phase-1` appended to `completed_phases` and `current_phase = "phase-2"`, then move into the per-project scope loop.
- **"Re-run Phase 1"** — clears the `audit.json` cache and re-dispatches.
- **"Cancel session"** — exits cleanly, leaves `audit.json` in place for the next invocation.

## Phase 2: Scope

<!-- gate-respect: honor user pick; re-prompt before any behavior change — applies to the enricher dispatch-error AskUserQuestion (Retry / Pause / Proceed-without-enrichment) and to every CQ/SQ prompt inside the dispatched sprint-scoping skill. Never silent fallback to "Proceed without enrichment" when the user did not pick it. -->

**Pre-loop enricher dispatch (BC-5902).** Before entering the per-project scope loop, the command dispatches `project-enricher` in a single `Agent` tool-call message covering every project with `status.type == "started"` (cap 10 concurrent, batched sequentially in groups of 10 if project count > 10 — mirrors Phase 1 § 1.2 Dispatch). Parsed outputs populate `state.projects[i]._enrichment` keyed by project id before any SQ/CQ question runs. On any `_enrichment.dispatch_error` non-null, the command surfaces `AskUserQuestion` (Retry / Pause / Proceed-without-enrichment per BC-5896 AC) before falling into the skill. The skill reads `_enrichment` as pre-dispatched input and never calls `list_issues` or `workflows:brainstorming` inline (BC-5902 hybrid-dispatch pattern — see `docs/designs/cadence-orchestration.md § 2.5`).

Sequential per-project loop. Implemented by the `sprint-scoping` skill (`plugins/cadence/skills/sprint-scoping/SKILL.md`, BC-5760). For each project, the skill reads the Phase 1 audit card plus the pre-dispatched `state.projects[i]._enrichment` (per the enricher paragraph above — BC-5902), runs the BC-5810 § 2 interview (5 carry-over Qs + 5 scope Qs, one at a time via separate `AskUserQuestion` calls) iterating the carry-over block per issue (BC-5897), enforces the `cadence:issue-quality-gate` with block-with-override (BC-5810 § 3), and appends a project block to the weekly-planning checkpoint as decisions accumulate. SQ2's `(Recommended)` default is drawn from `_enrichment.brainstorming_ranked[rank=1]` (BC-5867 absorbed — no inline `workflows:brainstorming` Skill call). Inline (not subagent) — interactive Q&A cannot run inside a dispatched agent.

Phase 2 is idempotent — re-invoking after a partial session resumes from the next unconfirmed project (skill § 8). After every project is scoped, the skill emits a `## Cross-project flags` section flagging any owner with > 4 primary assignments.

**Phase-exit breadcrumb.** Once every project is scoped and cross-project flags are written, the command applies § 0.5.5: append `phase-2` to `completed_phases`, set `current_phase = "phase-3"`, rewrite the breadcrumb. This happens in the command control flow after the sprint-scoping skill returns — the skill itself does not touch the breadcrumb (per skill-vs-command separation: skills own their artifact; the command owns inter-phase orchestration).

The deferred prior-narrative parser (needed for `state.cross_project_stats.unplanned_ratio`) lands in a sibling Cadence-milestone follow-up tracked as BC-5821.

## Phase 3: Housekeeping

<!-- gate-respect: honor user pick; re-prompt before any behavior change — applies to the preflight dispatch-error AskUserQuestion (Retry / Pause / Execute-without-preflight) and to every per-group approval prompt inside the dispatched linear-housekeeping skill. Execute-without-preflight is an explicit spec-departure and requires an explicit user pick. -->

**Pre-preview preflight dispatch (BC-5902).** After `linear-housekeeping` derives `state.mutations[]` in § 2, the command dispatches `housekeeping-preflight` once via the `Agent` tool with prompt body `{cycle.current, team_id, mutation_rows: <cycle-path slice>, overrides: <flattened state.projects[].overrides[]>}`. Parsed `state._preflight_manifest` feeds § 4's gate-status derivation before any preview rendering or approval prompt. On `dispatch_error` non-null, `AskUserQuestion` halts before § 5 (Retry / Pause / Execute-without-preflight with explicit spec-departure flag per BC-5898 AC — no silent degradation path exists). On `row_errors[]` non-empty, partial-fetch failures are surfaced as a dedicated `## Preflight errors` group in § 5/§ 6 for per-row resolution.

Batch mutation preview + atomic execute. Implemented by the `linear-housekeeping` skill (`plugins/cadence/skills/linear-housekeeping/SKILL.md`, BC-5761). Consumes `state.projects[].scope_decisions` + `state.projects[].overrides` populated by Phase 2. Derives `state.mutations[]` tagged by decision path (cycle / backlog / cancel / reassign / leave) and mutation type (cycle-assign / state-change / reassign / cancel / create / milestone-rename / label-change / backlog-return). Re-runs the `cadence:issue-quality-gate` on every cycle-path mutation with block-with-override. Renders the preview grouped first by decision path, then by mutation type. Collects per-group approval via `AskUserQuestion` (count = distinct non-empty groups), followed by a final execute gate. Executes sequentially; each write is pre-flight checked against current Linear state for idempotency (second run = zero writes) and timestamped in a housekeeping log at `weekly-planning/w<NN>-<yyyy-mm-dd>/w<NN>-housekeeping-log.md`.

Inline (not subagent) — interactive approval gates cannot run inside a dispatched agent. Idempotent — re-invoking after a partial session retries only errored rows; successful rows pre-flight as "already applied" and skip.

**Phase-exit breadcrumb.** Once the linear-housekeeping skill closes out § 7.5 (Execution summary populated), the command applies § 0.5.5: append `phase-3` to `completed_phases`, set `current_phase = "phase-4"`, rewrite the breadcrumb. This happens in the command control flow after the skill returns.

## Phase 4: Narrative + PDF export

Voice-bound subagent drafts `w<NN>-sprint-narrative.md`; main thread runs a post-generation voice check; Gate #3 presents draft + violations to the user; primary ships a PDF via `npx md-to-pdf`; clipboard → Google Docs fallback covers security-hook blocks and offline environments.

Agent: `plugins/cadence/agents/narrative-writer.md` (Opus; `Read`-only tools; voice-bound to `docs/designs/cadence-plugin.md` § 1).

### 4.1 Idempotency check

Resolve the narrative path from `state.checkpoint_path` by replacing suffix `-planning-checkpoint.md` → `-sprint-narrative.md` in the same parent directory. Cache at `state.narrative_path`. If `state.checkpoint_path` is null (missing Phase 2 handoff), stop with: `Phase 4 requires Phase 2 checkpoint. Run /cadence:weekly --resume-phase 2 first.`

If `state.narrative_path` exists on disk AND `state.phase_state.completed_phases` includes `"phase-4"` AND `state.phase_state.cycle_id == state.cycle.current.id`, populate `state.narrative_draft` from the file contents and skip to Phase 5. Log: `Phase 4 cached — re-using <narrative_path>. No subagent dispatched.`

If the `.md` exists but the breadcrumb does not include `"phase-4"` or the cycle mismatches, warn the user: `Stale narrative at <path> (cycle mismatch or breadcrumb gap). Overwriting this run.` Fall through to § 4.2.

### 4.2 Dispatch narrative-writer

Resolve paths for the dispatch body:

- `voice_spec`: `$ROOT/docs/designs/cadence-plugin.md`
- `reference_narrative`: most recent prior week narrative. Find via `ls` scan of `<weekly-planning-root>/w*-*/w*-sprint-narrative.md`, sort descending by folder name, take the first entry that is NOT the current week. If none exists (first-ever cadence run), pass an empty string — the agent handles this via `<!-- VOICE-CHECK: no-reference-narrative -->`.
- `audit_json`: `<WEEK_DIR>/audit.json` (Phase 1 § 1.5 product)
- `checkpoint`: `state.checkpoint_path`
- `housekeeping_log`: `state.housekeeping_log_path` (may be `null` if Phase 3 produced zero mutations — agent tolerates)
- `prior_narrative`: same as `reference_narrative` for now (room to diverge if a planner wants to anchor against a specific older week)

Derive `mutations_summary` from `state.mutations[]`: `{ executed: count(result=="executed"), errored: count(result=="errored"), dropped_by_user: count(result=="dropped-by-user"), skipped_idempotent: count(result=="skipped-idempotent") }`.

Invoke `narrative-writer` via the `Agent` tool. Prompt body is a JSON block containing `cycle`, `cross_project_stats`, `bottleneck_warnings`, `mutations_summary`, `projects[].{id,name,status,owner,overrides}`, and `paths`. Capture the returned markdown as `state.narrative_draft`.

### 4.3 Main-thread voice-check (post-generation, pre-approval)

Parse and strip any `<!-- VOICE-CHECK: … -->` and `<!-- NARRATIVE-ERROR: … -->` HTML comments from `state.narrative_draft`. Accumulate their payloads into a `voice_violations[]` list. If any `NARRATIVE-ERROR` comment is present, treat the entire run as errored: surface the message to the user and return to § 4.2 with the user's edit guidance.

Then run three fresh checks in-thread (belt-and-suspenders for the subagent's self-check):

1. **Section-header diff.** Use Bash grep to extract every `^## ` line from the draft. The required set is exactly `Context`, `Strategic Decisions`, `Sprint Plans`, `Parked This Week`, `Check-in Schedule`, `Team Assignments`. Any missing or extra header appends to `voice_violations[]` with type `section-header-diff`.
2. **Context paragraph + word count.** Inline Python stdlib pass (no deps): extract the `## Context` body, split on blank-line boundaries, count paragraphs (must be 4–6 inclusive, per voice spec § 1.3 + § 1.5), word-count each paragraph (must be 80–200). Every out-of-band paragraph appends a `context-paragraph-band` violation with the measured count and target band.
3. **Sprint Plans cards.** Extract every `### ` subsection under `## Sprint Plans`. Grep each card block for `**Ship this week:**` and `**Team:**`. Any card missing either string appends a `sprint-card-missing-line` violation.

Setup + example. Before running the voice-check for the first time, the main thread mints a tempfile, `Write`s `state.narrative_draft` to it, and exports the path for the Bash block. Repeat the Write on every Edit/Regenerate iteration so the check sees the latest draft:

```
# One-time setup (first voice-check pass, before the Bash block below):
# 1. DRAFT_PATH = mktemp result, e.g. "/tmp/cadence-draft.ABC123.md"
# 2. Write state.narrative_draft to DRAFT_PATH via the Write tool.
# 3. Pass DRAFT_PATH as a bash environment variable to the Bash block.
#
# On each Edit/Regenerate iteration:
# 1. Write the updated state.narrative_draft to the SAME DRAFT_PATH (overwrite).
# 2. Re-run the Bash block.
```

Bash block (pass `$DRAFT_PATH` as argv — the single-quoted heredoc `<<'PY'` deliberately suppresses bash expansion inside the Python body; `sys.argv[1]` pulls the path in):

```bash
python3 - "$DRAFT_PATH" <<'PY'
import re, sys
draft = open(sys.argv[1]).read()
m = re.search(r"## Context\n\n(.*?)(?=\n## )", draft, re.DOTALL)
if not m: print("ERR: no Context section"); sys.exit(0)
paragraphs = [p.strip() for p in m.group(1).split("\n\n") if p.strip()]
print(f"paragraph_count={len(paragraphs)}")
for i, p in enumerate(paragraphs, 1):
    words = len(p.split())
    print(f"paragraph_{i}_words={words}")
PY
```

The temp file is intentional: `state.narrative_draft` is a main-thread in-memory string; passing a ~300-line draft through the Bash tool's arg list is fragile (embedded newlines, shell metachars, quoting). After Gate #3 Approve + § 4.6 breadcrumb close-out, remove the tempfile with `rm -f "$DRAFT_PATH"` in a trailing Bash block (do not use `trap EXIT` — `memory/MEMORY.md` notes each Bash call is a separate subprocess, so the trap fires prematurely). Do not write to `state.narrative_path` yet — that write is gated on Gate #3 approval.

### 4.4 Gate #3 — narrative approval

<!-- gate-respect: honor user pick; re-prompt before any behavior change — the Approve / Edit / Regenerate pick is load-bearing. Never silent-Edit after an Approve or silent-Regenerate after an Edit. Follow-up AskUserQuestions (edit guidance, regeneration guidance) are themselves gates; honor their picks identically. -->


Render the preview block to the user:

```markdown
# Narrative draft for W<NN>

<state.narrative_draft with <!-- VOICE-CHECK --> comments stripped>

---

## Voice-check results
<if voice_violations is empty>
  ✓ Section headers: 6 of 6 required
  ✓ Context paragraphs: <count> (target 4–6); all within 80–200 words
  ✓ Sprint Plans cards: <count> cards, all carry **Ship this week:** and **Team:**
<else>
  One bullet per violation, formatted: `- ⚠ <type>: <detail>`
</if>

## PDF export preview
`cd <WEEK_DIR> && npx -y md-to-pdf <narrative-filename>` — ~4 seconds after first-run Chromium download
Output: `<WEEK_DIR>/w<NN>-sprint-narrative.pdf`
```

`AskUserQuestion`:

| Option | Effect |
|---|---|
| **Approve** *(Recommended when `voice_violations == []`)* | Write the stripped draft to `state.narrative_path` via the `Write` tool. Proceed to § 4.5 PDF export. |
| **Edit** | Follow-up `AskUserQuestion` collects free-text edit guidance. The main thread mutates `state.narrative_draft` in-process to apply the edits (no `Edit` tool call — `Edit` operates on files, and the draft is still in memory; no file write yet). After applying, re-write `$DRAFT_PATH` with the updated draft, re-run § 4.3 voice-check, re-prompt § 4.4. |
| **Regenerate** | Follow-up `AskUserQuestion` collects one-line guidance ("make Context shorter", "emphasize GTM blitz", etc.). Re-dispatch `narrative-writer` (§ 4.2) with the guidance appended to the prompt body under a `regeneration_guidance:` field. Return to § 4.3. |

No PDF export, no file write, no Phase 5 fires until Gate #3 returns Approve.

### 4.5 PDF export

<!-- gate-respect: honor user pick; re-prompt before any behavior change — applies to the fallback AskUserQuestion (Confirmed / Skip / Retry primary). Never silent-Skip the PDF when the user picked Confirmed or Retry. -->


**Primary path.** Shell out via Bash. Each Bash tool call runs in a separate subprocess per `memory/MEMORY.md` — re-derive `$WEEK_DIR` and `$WEEK_NN` at the top of every Bash block in Phase 4/5 (same pattern as Phase 3 § 7.1):

```bash
# Re-derive from state at each Bash call:
#   CYCLE_NN   = numeric week from state.cycle.current.name (e.g. "W17" → 17)
#   CYCLE_DATE = state.cycle.current.startsAt formatted YYYY-MM-DD
[[ "$CYCLE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "Invalid CYCLE_DATE: $CYCLE_DATE" >&2; exit 1; }
[[ "$CYCLE_NN" =~ ^[0-9]+$ ]] || { echo "Invalid CYCLE_NN: $CYCLE_NN" >&2; exit 1; }
WEEK_NN=$(printf "%02d" "$CYCLE_NN")
ROOT=$(git rev-parse --show-toplevel)
WEEK_DIR="$ROOT/../weekly-planning/w${WEEK_NN}-${CYCLE_DATE}"

cd "$WEEK_DIR" && npx -y md-to-pdf "w${WEEK_NN}-sprint-narrative.md"
```

`-y` auto-confirms the first-run install prompt (`npx` v7+ prompts interactively for "Need to install ..." — without `-y`, the Bash tool stalls past the 120s timeout). Expected: exit 0 and a new file `w${WEEK_NN}-sprint-narrative.pdf` in `$WEEK_DIR`. First run fetches Chromium (~30-60s); subsequent runs are ~4s.

Post-run check (re-derive WEEK_DIR + WEEK_NN inside the same Bash call — bash vars do not persist across Bash tool calls):

```bash
[[ "$CYCLE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "Invalid CYCLE_DATE: $CYCLE_DATE" >&2; exit 1; }
[[ "$CYCLE_NN" =~ ^[0-9]+$ ]] || { echo "Invalid CYCLE_NN: $CYCLE_NN" >&2; exit 1; }
WEEK_NN=$(printf "%02d" "$CYCLE_NN")
ROOT=$(git rev-parse --show-toplevel)
WEEK_DIR="$ROOT/../weekly-planning/w${WEEK_NN}-${CYCLE_DATE}"
[[ -f "$WEEK_DIR/w${WEEK_NN}-sprint-narrative.pdf" ]] && echo "PDF_OK" || echo "PDF_MISSING"
```

On `PDF_OK`: `state.pdf_path = "$WEEK_DIR/w${WEEK_NN}-sprint-narrative.pdf"`; `state.pdf_method = "primary-md-to-pdf"`.

**Fallback path.** Trigger on any of: non-zero exit, `PDF_MISSING`, security hook blocked `npx`. Uses `state.primary_retries` (persists across Bash tool calls — bash env vars do not) as the retry counter; the Retry option is hidden once `state.primary_retries >= 2`.

1. Check tool availability: if `mcp__computer-use__write_clipboard` is not in the tool registry (the computer-use MCP is a user-level install, not bundled with this plugin — see `memory/gotcha_security_hook_blocks_infra.md`), fall through to step 2's Bash fallback. Otherwise, `Read` the narrative file at `state.narrative_path` to get the markdown content as a main-thread string, then call `mcp__computer-use__write_clipboard` with that content.
2. Bash clipboard fallback (macOS `pbcopy`): if step 1 is skipped, shell out directly from the on-disk file (no intermediate bash var):

   ```bash
   cat "$NARRATIVE_PATH" | pbcopy
   ```

   where `$NARRATIVE_PATH` expands to `state.narrative_path` — main thread substitutes the literal path before invoking Bash. Preinstalled on macOS; on Linux, instruct the planner to `xclip -selection clipboard < "$NARRATIVE_PATH"` (or copy the markdown file manually and skip this step).
3. `AskUserQuestion`:

   > *"PDF primary failed (reason: `<exit code | security-hook-block | missing-output>`). Markdown copied to clipboard. Paste into Google Docs → File → Download → PDF document. Save the PDF to `<WEEK_DIR>/w<NN>-sprint-narrative.pdf`. Confirm when done."*

   | Option | Effect |
   |---|---|
   | **Confirmed, PDF saved** | Run the re-derivation preamble + `PDF_PATH="$WEEK_DIR/w${WEEK_NN}-sprint-narrative.pdf"; [[ -f "$PDF_PATH" ]] && echo "PDF_FOUND" \|\| echo "PDF_MISSING"`. On `PDF_FOUND`, record `state.pdf_method = "fallback-clipboard"`, `state.pdf_path = "$PDF_PATH"`. On `PDF_MISSING`, re-prompt. |
   | **Skip PDF for now** | `state.pdf_method = "skipped"`; `state.pdf_path = null`. Phase 5's Share section will surface a manual follow-up checkbox. |
   | **Retry primary** *(hidden when `state.primary_retries >= 2`)* | Increment `state.primary_retries`, jump back to "Primary path" above. |

### 4.6 Update phase-state breadcrumb

Append `"phase-4"` to `state.phase_state.completed_phases`; set `state.phase_state.current_phase = "phase-5"`; refresh `updated_at`. Write the breadcrumb JSON. Proceed to Phase 5.

## Phase 5: Remaining operations file

Generates `w<NN>-remaining-ops.md` with exactly four checklist sections (AC #6: Linear manual ops / Calendar / Share / Phase-3 follow-up). Inline (no subagent) — it's a template write with state-filtered content.

### 5.1 Idempotency check

Resolve `state.ops_path` by replacing the narrative's `-sprint-narrative.md` suffix with `-remaining-ops.md`.

If `state.ops_path` exists AND `state.phase_state.completed_phases` includes `"phase-5"` AND `state.phase_state.cycle_id == state.cycle.current.id` (same predicate as § 4.1): log `Phase 5 cached — re-using <ops_path>. Skipping.` and jump to § 5.3 close out.

### 5.2 Render template

Pre-compute from state. Always prefer the in-memory `state.narrative_draft` (populated by Phase 4 § 4.2 or § 0.5.4 rehydration) over re-reading `state.narrative_path` — both paths guarantee the draft is in memory by the time Phase 5 runs:

- `TBD_COUNT`: scan `state.narrative_draft` for `| TBD |` occurrences within the `## Check-in Schedule` section.
- `TOP_BOTTLENECK`: if `state.bottleneck_warnings[]` is non-empty, the first entry (highest count). Else the owner of the first Sprint Plans card extracted from the narrative. If both are empty (all projects parked, no cards), set `TOP_BOTTLENECK = null` — the template below renders a generic roster-confirmation bullet instead.
- `HEADLINE_COMMITMENT`: first `- **` bullet from `## Strategic Decisions`. If Strategic Decisions is empty, set to `null` and the template substitutes a generic "the week's commitments".
- `PHASE3_ERRORS`: `state.mutations[].filter(r => r.result == "errored")`. On Phase 0.5.4 rehydration from the housekeeping log, rows carry full `{issue_id, mutation_type, error}` per the rehydration contract in § 0.5.4.

Write (overwrites any existing file — this is a fresh generation, not a merge):

```markdown
# W<NN> Remaining Operations

_Generated <ISO-8601 now> by /cadence:weekly Phase 5. Target cycle: W<NN> (<startsAt> → <endsAt − 1 day>)._

Narrative: `<narrative_path>`
PDF: `<pdf_path or "SKIPPED — see Share section">`
Housekeeping log: `<housekeeping_log_path or "no mutations this cycle">`

## Linear manual ops (API can't do these)

- [ ] Rename BC cycle "Week <NN>" → <narrative-matching label> in the Linear UI if the planner wants a non-default title (MCP has no cycle-rename; BC-5757 § 2)
<!-- No other Linear-MCP-incapable mutations are emitted by Phase 3 today. If a future Phase 2/3 scope decision produces one, add a row here; until then, leave as the single cycle-rename row. -->

## Calendar

- [ ] Fill exact times for the `TBD` slots in the narrative's Check-in Schedule (count this run: <TBD_COUNT>)
<if TOP_BOTTLENECK is not null>
- [ ] Block `<TOP_BOTTLENECK.assignee or TOP_BOTTLENECK>`'s calendar for the headline commitment: `<HEADLINE_COMMITMENT or "this week's commitments">`
<else>
- [ ] Confirm Sprint Plans card owners and block their calendars for any deadline-bound commitments
</if>
<one extra row per weekday that has ≥1 TBD meeting, derived by scanning narrative's `### <Day>` subsections; if a day has only "TBD" meetings, include: `- [ ] Confirm <Day> meeting roster + times`>

## Share

- [ ] Share `w<NN>-sprint-narrative.pdf` with the team. Pick one channel: Slack / Google Doc / Linear doc
- [ ] Link the narrative in the W<NN> Monday standup calendar invite
<if state.pdf_method == "skipped">
- [ ] Generate the PDF manually (`cd <WEEK_DIR> && npx md-to-pdf w<NN>-sprint-narrative.md`) and save to `<WEEK_DIR>/w<NN>-sprint-narrative.pdf`
</if>
<if state.pdf_method == "fallback-clipboard">
- [x] PDF generated via Google Docs fallback (clipboard → Docs → Download)
</if>

## Phase-3 follow-up (manual)

<if PHASE3_ERRORS is non-empty:
  for each errored row:
    - [ ] <issue_id> — <mutation_type> failed: <error_message>. Linear: https://linear.app/brite-nites/issue/<issue_id>
 else:
  - [x] No Phase 3 errors this cycle.
>
```

Empty-section guard: every one of the four sections must render at least one checkbox (AC #6). The template above achieves that by design — `- [x] No Phase 3 errors this cycle.` is the explicit fallback for the one section that is conditionally empty.

### 5.3 Close out

Append `"phase-5"` to `state.phase_state.completed_phases`; set `current_phase = "complete"`; refresh `updated_at`; write breadcrumb.

Final log to user:

```
/cadence:weekly W<NN> complete.
  Narrative: <narrative_path>
  PDF:       <pdf_path or SKIPPED>
  Ops:       <ops_path>
  Breadcrumb: <breadcrumb_path>
```

## References

- `docs/designs/cadence-plugin.md` (BC-5757) — voice spec, Linear query recipes, PDF flow
- `docs/designs/cadence-orchestration.md` (BC-5810) — phases, interview, quality gate
- `docs/research/cadence-github-integration-findings.md` (BC-5811) — `gh` CLI adoption
- `plugins/cadence/agents/project-audit.md` (BC-5759) — Phase 1 subagent
- `plugins/cadence/agents/narrative-writer.md` (BC-5762) — Phase 4 subagent, voice-bound to BC-5757 § 1
- `plugins/cadence/skills/sprint-scoping/SKILL.md` (BC-5760) — Phase 2 scope interview
- `plugins/cadence/skills/linear-housekeeping/SKILL.md` (BC-5761) — Phase 3 batch mutations
