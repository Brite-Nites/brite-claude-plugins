# BC-5868 Plan — Cadence Phase 0.2: cycle end-date display shows exclusive endsAt instead of inclusive last day

**Linear:** https://linear.app/brite-nites/issue/BC-5868
**Milestone:** Cadence Plugin (P2 toward BC-5874 5/8 threshold — moves 0→1/8)
**Parent:** BC-5763 (W17 dogfood umbrella)
**Priority:** Medium (Bug label) — cosmetic but user-facing on every `/cadence:weekly` run
**Branch / worktree:** `holden/bc-5868-cycle-end-date-display` / `.claude/worktrees/bc-5868/`

## Context

W17 dogfood (2026-04-20) rendered *"Current cycle appears to be Week 17 (2026-04-20 to 2026-04-27)"*. W17 is a Mon-Sun cycle ending Sunday 2026-04-26. Linear's `endsAt` is the **exclusive** upper bound — equal to W18's `startsAt`. Every site that consumes `state.cycle.current.endsAt` verbatim renders a confusing "W17 ends 04-27" read.

Fix format (Option A from issue body): `<startsAt> → <endsAt − 1 day>` with an ISO-date form (`2026-04-20 → 2026-04-26`). Apply consistently at the four render sites.

## Acceptance criteria (from BC-5868)

- [ ] Phase 0.2 prompt renders the last *inclusive* day of the cycle (e.g. `W17 (2026-04-20 → 2026-04-26)`).
- [ ] Phase 0.3 echo + Phase 4 narrative Context + Phase 5 ops header all use the same corrected window format.
- [ ] A test run against a known Mon-Sun cycle confirms inclusive-end rendering; `endsAt − 1 day` math is documented in a one-line comment at the render site.
- [ ] Cosmetic only — does not affect cycle resolution, week-folder naming, or idempotency predicates.

## Render sites

| # | File | Anchor line | Change |
|---|---|---|---|
| A | `plugins/cadence/commands/weekly.md` | § 0.2 L25 prompt | `(\`<startsAt>\` to \`<endsAt>\`)` → `` (`<startsAt>` → `<endsAt − 1 day>`) `` with one-line comment on the rule |
| B | `plugins/cadence/commands/weekly.md` | § 0.3 L36 echo | Add cycle-window reinforcement: `**W<NN>** (<startsAt> → <endsAt − 1 day>), **N active projects**…` |
| C | `plugins/cadence/agents/narrative-writer.md` | § "Hard skeleton" L41 + supporting rule | Add explicit rule: the H2 `## <Month DD-DD, YYYY>` uses `cycle.current.endsAt − 1 day` for the `DD-DD` range. Also applies to Context paragraph if a clause echoes the window. |
| D | `plugins/cadence/commands/weekly.md` | § 5.2 L516 template header | `(\`<startsAt>\` to \`<endsAt>\`)` → `` (`<startsAt>` → `<endsAt − 1 day>`) `` |

Out of scope (do NOT touch):
- `state.cycle.current.endsAt` raw value — stays the exclusive-upper-bound MCP value (Phase 0.5.1 `CYCLE_DATE` math, idempotency predicates, `cycle.id` equality, housekeeping-log mutations). The fix is display-only per issue note "Cosmetic only — does not affect cycle resolution, week-folder naming, or idempotency predicates".
- `CYCLE_DATE` (L68) = `state.cycle.current.startsAt` → no change needed (uses startsAt, not endsAt).
- Footer (narrative-writer L55) uses `cycle.current.startsAt` only → no change needed.

## Tasks

### T1 — Phase 0.2 render fix (Render site A)

File: `plugins/cadence/commands/weekly.md` § 0.2
Lines: 25 (prompt text) + new comment directly above the `AskUserQuestion` block describing the rule.

Edit:
- Replace `(\`<startsAt>\` to \`<endsAt>\`)` with `` (`<startsAt>` → `<endsAt − 1 day>`) ``.
- Add a one-line HTML comment directly above the prompt explaining the rule, matching the existing gate-respect comment idiom:
  ```
  <!-- cycle-window format: <startsAt> → <endsAt − 1 day>. Linear endsAt is exclusive (equals next cycle's startsAt); subtract 1 day for inclusive last day. Origin: BC-5868 W17 dogfood. -->
  ```
- Update L27 option text: `"Yes, plan W##"` remains unchanged (user-answer echo — not a window render).

Verify: `grep -n "endsAt − 1 day\|startsAt.*→.*endsAt" plugins/cadence/commands/weekly.md` shows the expected occurrence at § 0.2.

### T2 — Phase 0.3 echo (Render site B, new render)

File: `plugins/cadence/commands/weekly.md` § 0.3
Lines: 34–36 (project-count echo).

Edit:
- Update L36 echo from `> **N active projects** will be audited this session. Top 5 most recent: \`<project>\`, \`<project>\`, …` to: `> **W<NN>** (\`<startsAt>\` → \`<endsAt − 1 day>\`) — **N active projects** will be audited this session. Top 5 most recent: \`<project>\`, \`<project>\`, …`
- This is the "Phase 0.3 echo" referenced in BC-5868 AC — provides a second cycle-window reinforcement between user pick and Phase 1 dispatch.
- No separate comment needed — the T1 comment in § 0.2 establishes the format rule for the whole command file.

Verify: `grep -nE 'W<NN>.*<startsAt>.*endsAt − 1 day' plugins/cadence/commands/weekly.md` shows the new § 0.3 occurrence.

### T3 — narrative-writer H2 rule (Render site C)

File: `plugins/cadence/agents/narrative-writer.md`
Anchor: § "Hard skeleton" L41 (`## <Month DD-DD, YYYY>`).

Edit:
- Extend L41 or add an inline rule bullet below the skeleton fence. Rule text:
  > The `DD-DD` range uses `cycle.current.startsAt.day` and `(cycle.current.endsAt − 1 day).day` — Linear's `endsAt` is exclusive (equals W+1 `startsAt`); subtract one day for the inclusive last day. Same convention as `/cadence:weekly` § 0.2 prompt. Origin: BC-5868.
- If § Context (L61 onward) references the window explicitly anywhere, apply the same rule.

Verify: `grep -n "endsAt − 1 day" plugins/cadence/agents/narrative-writer.md` shows the new rule.

### T4 — Phase 5 template header (Render site D)

File: `plugins/cadence/commands/weekly.md` § 5.2
Lines: 516 (Target cycle header inside the template markdown block).

Edit:
- Replace `Target cycle: W<NN> (\`<startsAt>\` to \`<endsAt>\`)` with `Target cycle: W<NN> (\`<startsAt>\` → \`<endsAt − 1 day>\`)`.
- No new comment needed (T1 comment covers the file).

Verify: `grep -n "Target cycle.*endsAt − 1 day" plugins/cadence/commands/weekly.md` shows the expected occurrence.

### T5 — validate.sh + lint_cadence_gates + structural checks

Run:
```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md plugins/cadence/CLAUDE.md
python3 scripts/_lib/lint_cadence_gates.py plugins/cadence/commands/weekly.md plugins/cadence/skills/sprint-scoping/SKILL.md plugins/cadence/skills/linear-housekeeping/SKILL.md plugins/cadence/skills/_shared/gate-respect.md 2>&1 | head -50
```

Acceptance:
- `validate.sh`: 0 errors; warnings ≤ 16 (BC-5864/5865 baseline per session memory).
- `check-guardrails.sh`: 0 violations.
- `lint_cadence_gates.py`: green on both files.

### T6 — CLAUDE.md gotcha note

File: `plugins/cadence/CLAUDE.md`
Anchor: `## Gotchas` list (add one bullet).

Edit:
- Add a bullet: `- **Cycle window is display-inclusive, stored-exclusive.** Every user-facing cycle render (\`/cadence:weekly\` § 0.2 / § 0.3 / § 5.2 + narrative-writer H2) uses \`<startsAt> → <endsAt − 1 day>\` — Linear's \`endsAt\` is exclusive (equals W+1 \`startsAt\`). \`state.cycle.current.endsAt\` raw stays as-is for idempotency predicates + \`cycle.id\` equality. Origin: BC-5868 (W17 dogfood cosmetic fix).`

Verify:
- `grep -n "display-inclusive.*stored-exclusive" plugins/cadence/CLAUDE.md` shows the new bullet.
- `./scripts/check-guardrails.sh --claude-md plugins/cadence/CLAUDE.md` still passes.

### T7 — Bench check: known Mon-Sun cycle

No auto-test harness for cosmetic renders, so do a manual bench: construct a fake `state.cycle.current = {name: "W17", startsAt: "2026-04-20", endsAt: "2026-04-27"}` and mentally walk each of the 4 render sites. Expected:
- § 0.2: `(2026-04-20 → 2026-04-26)` ✓
- § 0.3: `W17 (2026-04-20 → 2026-04-26)` ✓
- § 5.2: `Target cycle: W17 (2026-04-20 → 2026-04-26)` ✓
- narrative-writer H2 (LLM rendering): `## April 20–26, 2026` ✓ (inclusive Sunday)

Document this walk in the PR description — no test file written (consistent with other cosmetic-fix precedents BC-5873 polish pass).

## Out of scope (deliberate)

- No change to `state.cycle.current.endsAt` raw value or derived Bash vars (`CYCLE_DATE`, `WEEK_DIR`, `$BREADCRUMB`).
- No test file — cosmetic-only per issue AC, matches BC-5866/5864/5865 precedent for display-only changes (ship-gate = validate.sh + linter + grep spot-checks).
- No new lint rule for endsAt handling — a single linter pattern for a 4-site fix is over-engineering. If a 5th render site appears in the future, the T6 CLAUDE.md gotcha will catch it during review.
- No retroactive fix in existing narrative files (`weekly-planning/w*-sprint-narrative.md`) — those are historical artifacts, not re-rendered.

## Review scope

Minimal-diff cosmetic change. Run `/workflows:review` with default agent selection — code + security + performance. Expected: 0 P1 / 0 P2 / ≤ 3 P3 (wording nits). Context7 quota exhausted — cdr-compliance-reviewer will fall back to sibling-template per BC-5792 precedent. Skip architectural review agents (cosmetic only, no architecture).

## Commit shape

Per BC-5864/5865 precedent: 2 atomic commits
1. `BC-5868: cycle window display uses inclusive last day across 4 render sites` — T1–T4 + T6 CLAUDE.md note
2. (conditional) simplify-pass + any review-follow-up if review surfaces nits

## Linear lifecycle

- Plan approved → EnterWorktree creates `.claude/worktrees/bc-5868/`
- During execution: `save_issue` set status → `In Progress`
- Pre-PR: run verify-before-completion (all 4 levels)
- Ship: `save_issue` links PR, set status → `In Review`
- Merge: auto-flip to Done

## Departures from plan

(Track any deviations here during execution for session-history compound learnings.)
