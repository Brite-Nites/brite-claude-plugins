---
description: Run the weekly planning loop — audit, scope, housekeep, narrate
---

# /cadence:weekly

Four-phase weekly planning loop. Replaces the manual W15/W16 checkpoint + narrative flow.

> **Status: scaffold only.** Phase 0 preflight runs; Phase 1–5 are stubbed and owned by downstream issues. Do not rely on this command for a real weekly planning session yet.

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
  "cycle": { "id", "name", "startsAt", "endsAt" },
  "projects": [ { "id", "name", "audit_card", "scope_decisions", "overrides" } ],
  "cross_project_stats": { "completion_rate", "unplanned_ratio", "shipped_total", "planned_total", "team_standouts" },
  "mutations": [ ... ],
  "narrative_draft": null
}
```

## Phase 1: Audit

> **Not yet implemented — see BC-5759.**

Batch fan-out. One subagent per project, parallel. Each subagent produces a structured audit card: shipped, dropped, carry-over, by-assignee rollup, quality-gate flags (via `skills/_shared/issue-quality-gate`). Cross-project stats computed after fan-out completes. Read-only.

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
