# Gate-Respect Contract

Once the user picks an option at an `AskUserQuestion` gate, the skill runs exactly that behavior. If, during execution, the skill wants to switch to a different option or a different pattern than the one the user selected, the skill MUST pause and re-prompt via a new `AskUserQuestion`. Writing to `dogfood-notes.md`, the housekeeping log, or any other file does not constitute user authorization.

## Why

Correction from the 2026-04-20 W17 dogfood of `/cadence:weekly` (BC-5763 → BC-5866). At the Phase 2 entry gate, the planner selected "Active projects only (Recommended)" from a 4-option menu. Immediately after the pick, `sprint-scoping` silently switched to a behavior closer to the *rejected* "Abbreviated form" option — batching scope questions per project — while logging the deviation to dogfood notes as if logging were permission to proceed.

Three things went wrong at once:

1. **The gate pick was not honored.** The user picked option A; the skill executed behavior closer to option D. No intermediate re-prompt.
2. **Logging was treated as consent.** "Log the deviation, then proceed" is not a substitute for asking the user to approve the deviation. Notes files are descriptive, not authorizing.
3. **There was no contract for mid-execution deviation.** The skill had no guidance for what to do when it wanted to change approach after a gate was answered, and defaulted to silent self-selection.

This file is the durable fix for the class of bug. The two specific instances that surfaced it are fixed under BC-5864 (project-level triage gate) and BC-5865 (condensed-prompt shortcut).

## Application

1. **Header link.** Every Cadence skill or command that calls `AskUserQuestion` with >1 option MUST link this file in a top-of-file `## Gate-respect` section, immediately after the lead paragraph.
2. **Call-site reminder.** Every multi-option `AskUserQuestion` call-site MUST carry a one-line reminder comment within the same section: `<!-- gate-respect: honor user pick; re-prompt before any behavior change -->`. A single top-of-section comment covers every `AskUserQuestion` call in that section — no need to spam one per question.
3. **Notes are not permission.** A mention in `dogfood-notes.md`, a breadcrumb file, a housekeeping log, or any other written artifact is NEVER permission to deviate from the selected option. The only permissioning instrument is a new `AskUserQuestion` whose answer explicitly authorizes the new option.
4. **Exempt primitives.** Skills that never render `AskUserQuestion` themselves are out of scope — the contract applies to the *caller* that renders the prompt. Example: `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md` is a pure primitive returning `{check, status, message}` tuples; its consumers (`sprint-scoping` § 5, `linear-housekeeping` § 6) render the gate. The consumers carry the contract; the primitive does not.
5. **Quality-gate block-with-override is not a gate-respect deviation.** Per-row override with a reason is a structured, pre-authorized deviation pattern spec'd by BC-5810 § 3.3 — the user re-answers per-row via a follow-up `AskUserQuestion`. That satisfies Rule 1 by construction.

## Tripwires

If you are about to write any of the following in a skill body, STOP and re-prompt the user instead:

- *"…I'll use a pragmatic condensed pattern…"*
- *"…I'll skip the strict interview for projects without carry-over…"*
- *"…logging this deviation as Entry N, then proceeding…"*
- *"…for efficiency, I'll batch these into one prompt…"*
- *"…under context pressure, I'll…"* (see BC-5896/5898/5902 — there is no "context-pressure" escape hatch; fail-loud re-prompt instead)

## References

- [BC-5866](https://linear.app/brite-nites/issue/BC-5866/cadence-skills-must-not-self-select-a-lower-option-pattern-when-user) — authoritative issue
- [BC-5763](https://linear.app/brite-nites/issue/BC-5763) — W17/W18 dogfood parent (origin)
- [BC-5810](https://linear.app/brite-nites/issue/BC-5810) — orchestration spec (§ 1.1c gate reasons, § 2.3 per-question adaptive-skip)
- `memory/feedback_honor_user_gate_selection.md` — planner rule: option selected = option executed
- `memory/feedback_no_condensed_shortcuts_in_skill_specs.md` — sibling rule: no in-flight batching
- `memory/feedback_one_question_at_a_time.md` — underlying one-at-a-time hard rule
- `plugins/cadence/skills/sprint-scoping/SKILL.md` — consumer
- `plugins/cadence/skills/linear-housekeeping/SKILL.md` — consumer
- `plugins/cadence/commands/weekly.md` — consumer (entry command with Gate #1 + Gate #3 + Phase 0 / Phase 0.5 prompts)
- `scripts/_lib/lint_cadence_gates.py` — structural linter that enforces this contract in CI
