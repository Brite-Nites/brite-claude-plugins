---
description: Run the weekly planning loop — audit, scope, housekeep, narrate
---

# /cadence:weekly

Four-phase weekly planning loop. Replaces the manual W15/W16 checkpoint + narrative flow.

> **Status: in-progress build.** Phase 0 preflight + Phase 1 audit are implemented; Phase 2–4 are stubbed and owned by downstream issues. End-to-end dogfood (BC-5763) is required before this command is production-ready.

## Phase 0: Preflight

Run every session before any phase work. All four checks are fail-closed — if any block errors, stop and report the specific failure to the user.

### 0.1 Linear MCP connectivity

Call `mcp__plugin_workflows_linear-server__list_projects` with `limit: 1`. On success, confirm "Linear MCP: OK". On failure, stop with: "Linear MCP is not reachable. Run `/workflows:smoke-test` to diagnose."

### 0.2 Current cycle detection

Call `mcp__plugin_workflows_linear-server__list_cycles` with `type: "current"` scoped to the Brite Company team (`teamId` required per BC-5757 § 2.3 — cycle queries need the UUID, not the team name). Extract the cycle `name`, `startsAt`, `endsAt`. Present via `AskUserQuestion`:

> Current cycle appears to be **W##** (`<startsAt>` to `<endsAt>`). Is this the week you want to plan?

Options: (Recommended) "Yes, plan W##"; "Use a different cycle" (free-text); "Cancel".

### 0.3 Active project count echo

Call `mcp__plugin_workflows_linear-server__list_projects` with pagination (the `state: "started"` + team filter returns empty — list all and filter client-side per BC-5757 § 2.3). Filter to `status.type == "started"`. Echo the count and top 5 by `updatedAt`:

> **N active projects** will be audited this session. Top 5 most recent: `<project>`, `<project>`, …

`AskUserQuestion`: "Proceed with all N, or pick a subset?" Default: "All N (Recommended)". Escape: "Pick a subset" (free-text comma-separated project names).

### 0.4 GitHub integration probe

Per BC-5811 § 4.2, the Cadence plugin does not register a GitHub MCP. Phase 5's connectivity check uses `gh` CLI via Bash. Probe:

```bash
gh auth status 2>&1 | head -3
```

If `gh` is authenticated, report "GitHub: gh CLI ready". If not, report "GitHub: `gh auth login` required before Phase 5 connectivity check" — Phase 5 will skip the per-project GitHub probe and narrate it as "GitHub integration unavailable this session."

Do not stop on GitHub probe failure — Phases 1–4 do not require it.

## Gates Between Phases

Three `AskUserQuestion` gates, per BC-5810 § 1:

- **Gate #1** — after Phase 1 audit: show audit summary, user approves moving to scope.
- **Gate #2** — after Phase 2 scope: show accumulated mutation preview, user approves batch.
- **Gate #3** — after Phase 3 housekeeping: show narrative draft, user approves ship.

Gates use the `AskUserQuestion` convention — first option wins `(Recommended)`, "Other" is the escape hatch.

## Session State Object

Phases flow via a single session-scoped state object. No re-fetching from Linear between phases. Schema owned by BC-5758 follow-ups; initial shape per BC-5810 § 1.3:

```
{
  "team":  { "id", "name" },
  "cycle": {
    "current":  { "id", "name", "startsAt", "endsAt" },
    "previous": { "id", "title", "startsAt", "endsAt", "issueCountHistory", "completedIssueCountHistory" }
  },
  "projects": [ { "id", "name", "audit_card", "scope_decisions", "overrides" } ],
  "cross_project_stats": { "completion_rate", "shipped_total", "carry_over_total", "dropped_total", "team_standouts" },
  "mutations": [ ... ],
  "narrative_draft": null
}
```

`cycle.current` is populated by Phase 0.2 (the cycle the user is *planning*); `cycle.previous` is populated by Phase 1 § 1.0 (the cycle being *audited*). `team` is populated by Phase 0 (`list_teams` lookup of `"Brite Company"` — currently inlined per the Phase 1 prerequisite note below). `cross_project_stats.unplanned_ratio` and per-assignee planned attribution are computed in Phase 2 once the prior-narrative parser lands (BC-5760 owns the parser per BC-5757 § 2.6).

## Phase 1: Audit

Batch fan-out — one `project-audit` subagent per active project, parallel, capped at 10 concurrent. Each subagent produces a structured audit card; the main thread merges the cards and computes cross-project stats. Read-only — no Linear mutations in this phase.

> **Phase 0 prerequisite (out of scope for this issue):** Phase 0 must populate `state.team.id` via a one-time `list_teams` lookup of `"Brite Company"`. Until that lands, dispatchers may resolve it inline. Issue tracked separately as a Phase 0 enhancement.

### 1.0 Resolve prior cycle

Call `mcp__plugin_workflows_linear-server__list_cycles` with `teamId: state.team.id` and `type: "previous"`. Capture `id`, `title`, `startsAt`, `endsAt`, `completedIssueCountHistory`, `issueCountHistory`. Store as `state.cycle.previous`. (`state.cycle.current` was populated in Phase 0.2 — that's the cycle the user is *planning*; this previous cycle is the one being *audited*.)

### 1.1 Idempotency check

Construct the audit file path: `weekly-planning/w<NN>-<startsAt-yyyy-mm-dd>/audit.json` (relative to the user's repo root, where `<NN>` is parsed from `state.cycle.previous.title` and the date is the previous cycle's `startsAt` formatted `YYYY-MM-DD`). If the file exists, parse it as JSON, and `cycle.id == state.cycle.previous.id`, populate `state.projects[].audit_card` + `state.cross_project_stats` from the file and skip to § 1.6 (synthesis). Log: `Phase 1 audit cached — re-using audit.json (0 dispatches).`

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

**Deferred to Phase 2** (BC-5760, requires prior-narrative parser per BC-5757 § 2.6):

- `unplanned_ratio` — needs `planned_count_from_prior_narrative`, which only the Phase 2 narrative parser can extract. Phase 1 leaves the field unset; Phase 2 fills it in once the prior `w<NN-1>-sprint-narrative.md` is parsed for declared planned scope.
- Per-assignee *planned* attribution — same dependency. AC #4's "≥90% planned completion" framing is approximated by the cycle-completion ratio above until Phase 2 lands.

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

Call `AskUserQuestion`:

> *"Audit complete. <N> projects audited, <shipped_total> shipped, <carry_over_total> carrying over. Proceed to Phase 2 scope?"*

Options:

- **"Proceed to Phase 2"** — `(Recommended)` — moves into the per-project scope loop.
- **"Re-run Phase 1"** — clears the `audit.json` cache and re-dispatches.
- **"Cancel session"** — exits cleanly, leaves `audit.json` in place for the next invocation.

## Phase 2: Scope

> **Not yet implemented — see BC-5760.**

Sequential per-project loop. For each project, read the Phase 1 audit card and run the adaptive interview (10 questions max, one at a time) per BC-5810 § 2. Calls the quality gate on scope-in candidates; blocks with per-check override.

## Phase 3: Housekeeping

> **Not yet implemented — see BC-5761.**

Batch preview + atomic execute. Renders every mutation (`reassign BC-X`, `cancel BC-Y`, `add BC-Q to cycle`, `rename milestone`). User approves the full batch before any write.

## Phase 4: Narrative + Export

> **Not yet implemented — see BC-5762.**

Voice-bound subagent drafts `w##-sprint-narrative.md` per BC-5757 § 1 skeleton. Reads state object end-to-end; renders override reasons under a `> **Known gaps this cycle**` callout. Export trailer: per-project GitHub connectivity check via `gh` CLI (BC-5811 § 4.2), PDF render via `npx md-to-pdf` (BC-5757 § 3), ops-checklist file write.

## References

- `docs/designs/cadence-plugin.md` (BC-5757) — voice + queries + PDF
- `docs/designs/cadence-orchestration.md` (BC-5810) — phases, interview, quality gate
- `docs/research/cadence-github-integration-findings.md` (BC-5811) — gh CLI adoption
