# Cadence Plugin

Weekly planning cadence — audit, scope, housekeep, narrate, ops. Replaces the manual W15/W16 checkpoint + narrative flow with `/cadence:weekly`.

## Entry Command

`/cadence:weekly` — runs the five-phase loop with three gates between phases plus a phase-state breadcrumb for resume support.

## Architecture

Five phases, three gates (BC-5810 + BC-5762):

1. **Phase 0 preflight** (§ 0.1–0.4) — Linear MCP connectivity, current-cycle detection, active-project echo, GitHub `gh` probe.
2. **Phase 0.5 resume detection** — create week folder if missing, read `.cadence-phase-state.json` breadcrumb, validate completed-phase artifacts, prompt user to Resume / Restart / Cancel.
3. **Phase 1 audit** (batch fan-out) — `project-audit` subagent per active project; read-only; produces audit cards + cross-project stats.
4. **Gate #1** — user approves moving to scope.
5. **Phase 2 scope** (per-project loop, inline) — `sprint-scoping` skill runs the 5 carry-over + 5 scope questions one-at-a-time, enforces the issue-quality gate with block-with-override, appends per-project blocks to the checkpoint.
6. **Phase 3 housekeeping** (batch, inline) — `linear-housekeeping` skill derives mutations, re-runs the gate on cycle-path rows, renders a per-group preview, collects **Gate #2** per-group approval + final **Execute now** gate, and writes the audit log.
7. **Phase 4 narrative + PDF** (batch) — `narrative-writer` subagent drafts voice-bound `w<NN>-sprint-narrative.md`; main thread runs post-gen section-header + paragraph-word-count + Sprint-card checks; **Gate #3** shows draft + violations; on Approve, writes the file and exports PDF via `npx md-to-pdf` with a clipboard → Google Docs fallback for security-hook blocks.
8. **Phase 5 ops file** (inline) — templates `w<NN>-remaining-ops.md` with 4 checkbox sections (Linear manual ops / Calendar / Share / Phase-3 follow-up), source-filtered from state.

Phases flow via a session-scoped state object; no re-fetching from Linear between phases. Every phase writes a JSON breadcrumb so a killed session resumes at the current phase.

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
- **Narrative-writer reads the reference narrative via an absolute sibling-repo path.** `/Users/<user>/Projects/work/brite-nites/weekly-planning/w*-*/w*-sprint-narrative.md` lives outside this repo. When the agent can't resolve it (first-ever cadence run, or an install on a machine without the sibling repo), it emits `<!-- VOICE-CHECK: no-reference-narrative -->` at EOF and the main thread surfaces that violation in Gate #3 so the planner knows the draft is unanchored. Do not silently substitute a different voice anchor.
- **Phase 4 breadcrumb write follows the narrative file write.** The breadcrumb `"phase-4"` marker appends only AFTER the `Write` tool places the `.md` on disk and the PDF step resolves (primary, fallback, or explicit skip). Writing the breadcrumb earlier would let a killed session resume with a "complete" Phase 4 that has no `.md` on disk — the § 0.5.2 artifact check would then downgrade the phase, but the order of operations matters for the AC #7 kill-mid-Phase-3 test. Same pattern applies to every phase: breadcrumb append is the *last* step of a phase, after all its artifacts land on disk.
- **Phase 5 is idempotent template write, no gate.** The ops file is derivative (all content from state + narrative), reversible (planner deletes and re-runs), and non-destructive. Gating it would add a confirmation prompt for zero safety gain. If BC-5763 dogfood surfaces a reason to gate, add a Gate #4 in a follow-up.
- **Bash variable needs a visible producer in the spec.** Every `$FOO` referenced in a Bash block of a skill/command/agent markdown must have a visible assignment site: either (a) `FOO=...` inline in the same block, (b) the state schema names it and the main thread template-substitutes before invoking Bash, or (c) a prose bullet directly above the block telling the main thread to mint + export the variable. A prose mention like "`$FOO` is a temp file" is not a producer — an executor LLM copying the block verbatim gets an unset variable. Captured during BC-5762 iter 2 after `$DRAFT_PATH` / `$NARRATIVE_MD` / `$PDF_PATH` each surfaced the same failure mode. Related to BC-5760's printf-with-prose-placeholder gotcha; this is the general form.
- **Cross-cycle artifacts live under the planned cycle's week folder.** Phase 1 audits the *previous* cycle but writes `audit.json` under the *current* cycle's `$WEEK_DIR` alongside the checkpoint, housekeeping log, narrative, and ops file. The internal `cycle.id` field inside each artifact identifies which cycle it describes. Mixing cycle folders (some artifacts under previous, some under current) creates resume bugs — `$WEEK_DIR`-based paths go stale cross-cycle, and the § 0.5.2 artifact-check can't reason about artifacts in a folder it can't reach. BC-5762 iter 2 found a cross-cycle folder drift when Phase 0.5's `$WEEK_DIR` was hoisted to current-cycle while Phase 1 § 1.1 still built the audit path from previous-cycle metadata.
