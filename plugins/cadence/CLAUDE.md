# Cadence Plugin

Weekly planning cadence — audit, scope, housekeep, narrate. Replaces the manual W15/W16 checkpoint + narrative flow with `/cadence:weekly`.

## Entry Command

`/cadence:weekly` — runs the four-phase loop with three gates between phases. Scaffold only; phase issues fill in behavior.

## Architecture

Four phases, three gates (locked in BC-5810):

1. **Phase 1 audit** (batch fan-out) — per-project subagent produces audit cards + cross-project stats. Read-only.
2. **Gate #1** — user approves moving to scope.
3. **Phase 2 scope** (per-project loop) — adaptive interview, one question at a time, per project sequentially.
4. **Gate #2** — user approves the accumulated mutation batch.
5. **Phase 3 housekeeping** (batch) — executes Linear mutations atomically.
6. **Gate #3** — user approves narrative ship.
7. **Phase 4 narrative** (batch) — voice-bound subagent drafts, PDF export via `npx md-to-pdf`.

Phases flow via a session-scoped state object; no re-fetching from Linear between phases.

## Locked Design Docs

- `docs/designs/cadence-plugin.md` (BC-5757) — voice spec (§ 1), Linear query recipes (§ 2), PDF flow (§ 3)
- `docs/designs/cadence-orchestration.md` (BC-5810) — phases + gates (§ 1), interview set (§ 2), issue-quality gate (§ 3)
- `docs/research/cadence-github-integration-findings.md` (BC-5811) — `gh` CLI adopted, GitHub MCP deferred

## Shared Skills

`skills/_shared/issue-quality-gate` — 7 checks (assignee, title, priority, state/cycle alignment, dependencies, AC, done-with-evidence). Consumed by Phase 1 audit (flag) and Phase 2 scope (block-with-override). Spec in BC-5810 § 3.

## MCP Servers

None registered. Linear is consumed via `mcp__plugin_workflows_linear-server__*` from the workflows plugin — duplicate registration breaks tooling. Sequential-thinking + Context7 similarly inherited. `gh` CLI covers the only GitHub use (Phase 5 connectivity check); see BC-5811 § 4.2.

## Gotchas

- **Cycle ≠ week number in Linear.** Match on cycle title string or resolve via `type: "current" | "previous"`.
- **`list_projects` `state: "started"` + team filter returns empty.** List all projects and filter client-side (BC-5757 § 2.3).
- **Day-1 cycle scope is not exposed by MCP.** Phase 2 parses the prior week's narrative for the planned-vs-unplanned denominator.
- **Linear Prosemirror markdown mangling.** Always verify Linear writes via `get_issue` after `save_issue`. See `memory/gotcha_linear_markdown_mangling.md` — 8 known patterns, paragraph form with `**Bold.** sentence.` leads is safest.
- **State-schema drift has two scopes — both caught by review, not validate.sh.** Cross-phase drift (Phase N producer vs Phase N+1 consumer): canonical schema lives in `commands/weekly.md § Session State Object`; every phase PR updates it in lockstep (BC-5760 precedent). In-skill drift (§ 2.1 declaration vs § 3/§ 7/§ 8 consumers): every `result` enum value, every schema field (`cycleName`, `stateType`, etc.), and every `state.*` underscore field must be used in a downstream section. Fix-review loops converge in 4-5 iterations for destructive-path skills — budget accordingly (BC-5761 precedent).
- **Linear MCP skills need dual-form ID+name schema.** Pre-flight reads (`get_issue`) return ID-form fields (`cycleId`, `stateType`, `assigneeId`); write calls (`save_issue`) take name-form (`assignee`, `cycle`, `state` per `memory/MEMORY.md`). A mutation row's `before`/`after` must carry BOTH forms from derivation time, or execute steps reference undefined fields. Declare both in the state schema explicitly.
- **Placeholder `result` values need skip rules in every `state.mutations[]` consumer.** Virtual mutations (e.g. `pending-cq3-reparse` placeholders that render in preview but aren't Linear writes) need explicit short-circuits in § 3 pre-flight, § 7 execute, and § 8 resume. Missing even one consumer section = destructive-write leak. Belt-and-suspenders guards in the execute loop are load-bearing.
