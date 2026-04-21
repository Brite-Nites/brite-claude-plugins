# BC-5866 — Cadence gate-respect contract

**Issue:** [BC-5866](https://linear.app/brite-nites/issue/BC-5866/cadence-skills-must-not-self-select-a-lower-option-pattern-when-user) — Cadence skills: must not self-select a lower-option pattern when user picked a higher-option at a prior gate
**Milestone:** Cadence Plugin
**Branch:** `holden/bc-5866-cadence-skills-gate-respect-contract`
**Worktree:** `.claude/worktrees/bc-5866`
**Parent:** BC-5763 (W18 dogfood)
**Siblings:** BC-5864 (remove project-level triage gate), BC-5865 (remove condensed-prompt shortcut)

## Objective

Codify a repo-level contract that prevents any Cadence skill or command from silently executing a different option than the one the user picked at an `AskUserQuestion` gate. BC-5864 and BC-5865 fix the two concrete instances observed in the W17 dogfood; this issue fixes the *class* of bug so new skills don't recreate it.

## Scope (confirmed in brainstorm)

**In scope:**
- New contract file: `plugins/cadence/skills/_shared/gate-respect.md`
- Edit three gate-rendering files under `plugins/cadence/`:
  - `skills/sprint-scoping/SKILL.md`
  - `skills/linear-housekeeping/SKILL.md`
  - `commands/weekly.md` (Gate #1, Gate #3, Phase 0 prompt, Phase 0.5 resume menu)
- Add one-line reference in `plugins/cadence/CLAUDE.md` § Gotchas
- New structural linter: `scripts/_lib/lint_cadence_gates.py` + wire into `scripts/validate.sh` § 12.5 (new section) so CI fails when a cadence skill/command with an `AskUserQuestion` call lacks the contract reference

**Out of scope:**
- `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md` — exempt (pure primitive, consumers render gates, not the primitive itself)
- Concrete fixes to sprint-scoping's triage gate + condensed-prompt shortcut — those are BC-5864 / BC-5865
- Runtime behavioral test — defers to BC-5763 dogfood re-run (AC #5)

## Acceptance Criteria (from issue)

- [ ] AC #1 — `plugins/cadence/skills/_shared/gate-respect.md` contains the contract language verbatim (as stated in issue body § Fix).
- [ ] AC #2 — `sprint-scoping`, `linear-housekeeping`, and `weekly.md` each link the contract in a header section and carry a one-line summary near the entry gate itself.
- [ ] AC #3 — `plugins/cadence/CLAUDE.md` § Gotchas carries a one-line gate-respect reference pointing to the shared file.
- [ ] AC #4 — Structural compliance check: `scripts/validate.sh` fails when a cadence skill/command that calls `AskUserQuestion` does not link `_shared/gate-respect.md` in a header AND does not carry a near-gate summary line. Proxy for the "seeded test" per spec-level repo tooling.
- [ ] AC #5 — BC-5763 dogfood re-run verifies at runtime — no "logging as permission" pattern in Phase 2, no silent option-switching. Deferred to BC-5763 execution.

## Tasks

### Task 1 — Write the gate-respect contract file

**File:** `plugins/cadence/skills/_shared/gate-respect.md` (new)

**Content structure:**
1. `# Gate-Respect Contract` heading
2. One-paragraph rule (verbatim from issue § Fix): *"Once the user picks an option at an `AskUserQuestion` gate, the skill runs exactly that behavior. If, during execution, the skill wants to switch to a different option or a different pattern than the one the user selected, the skill MUST pause and re-prompt via a new `AskUserQuestion`. Writing to `dogfood-notes.md`, the housekeeping log, or any other file does not constitute user authorization."*
3. `## Why` section — one paragraph, cites the W17 dogfood origin (BC-5866 → BC-5763), names the failure mode: logging as permission slip, silent lower-option self-selection.
4. `## Application` section — enumerated rules:
   - Rule 1: each gate-rendering skill / command MUST link this file in a top-of-file `## Gate-respect` header.
   - Rule 2: each `AskUserQuestion` call-site with >1 option MUST carry a one-line reminder immediately above the call: `<!-- gate-respect: honor user pick; re-prompt before any behavior change -->`.
   - Rule 3: file-level mention in a notes/log/breadcrumb file is NEVER permission to deviate — re-prompt via a new `AskUserQuestion` instead.
   - Rule 4: exempt: pure primitive skills that never call `AskUserQuestion` themselves (e.g. `issue-quality-gate`).
5. `## References` — link to BC-5866, BC-5810, `memory/feedback_honor_user_gate_selection.md`, `memory/feedback_no_condensed_shortcuts_in_skill_specs.md`.

**Verify:** `ls plugins/cadence/skills/_shared/gate-respect.md` returns the path; `grep -q "Once the user picks an option" plugins/cadence/skills/_shared/gate-respect.md` exits 0.

---

### Task 2 — Reference the contract from `sprint-scoping/SKILL.md`

**File:** `plugins/cadence/skills/sprint-scoping/SKILL.md`

**Changes:**
1. Insert a new `## Gate-respect` section after the existing lead paragraph (between line 12 body and `## § 1 Inputs`). Section body: two sentences + link to `../_shared/gate-respect.md`.
2. At each `AskUserQuestion` call-site with >1 option, insert the reminder comment `<!-- gate-respect: honor user pick; re-prompt before any behavior change -->` immediately above. Gate sites to annotate (from code reading):
   - § 2 pre-loop enricher dispatch-error prompt (Retry / Pause / Proceed-without-enrichment)
   - § 3 carry-over questions (CQ1–CQ5, each is a separate `AskUserQuestion`) — one comment at the top of § 3 stating "the reminder applies to every CQ prompt in this section" is sufficient; don't spam per-question
   - § 4 scope questions (SQ1–SQ5) — same, one comment at top of § 4
   - § 5 quality-gate failure prompt (Fix now / Override / Drop)

**Verify:** `grep -c "gate-respect" plugins/cadence/skills/sprint-scoping/SKILL.md` returns ≥5 (1 header section link + 4 gate-site reminders: §2 enricher, §3 CQ top, §4 SQ top, §5 quality-gate).

---

### Task 3 — Reference the contract from `linear-housekeeping/SKILL.md`

**File:** `plugins/cadence/skills/linear-housekeeping/SKILL.md`

**Changes:**
1. Insert a new `## Gate-respect` section after the existing lead paragraph (after line 14 "Namespace note" block). Same two sentences + link.
2. Reminder comments at each `AskUserQuestion` gate in § 6:
   - § 6.0 CQ3 parse errors (one per entry, but a top-of-section comment suffices)
   - § 6.1 Conflicts (same, top-of-section)
   - § 6.2 Preflight errors (top-of-section)
   - § 6.3 Gate failures (top-of-section)
   - § 6.4 Regular decision-path groups (top-of-section covers all four paths)
   - Final Execute-now gate (its own comment immediately above)

**Verify:** `grep -c "gate-respect" plugins/cadence/skills/linear-housekeeping/SKILL.md` returns ≥7 (1 header section link + 6 gate-site reminders).

---

### Task 4 — Reference the contract from `commands/weekly.md`

**File:** `plugins/cadence/commands/weekly.md`

**Changes:**
1. Insert a `## Gate-respect` section near the top of the file, after the existing "Three `AskUserQuestion` gates, per BC-5810 § 1" block (around line 134–140).
2. Reminder comments at each multi-option `AskUserQuestion` gate:
   - Phase 0 "Proceed with all N, or pick a subset?" (line 33)
   - Phase 0.5 resume menu (around line 98)
   - Gate #1 after Phase 1 audit (§ 1.7, around line 274–276)
   - Phase 2 pre-loop enricher dispatch-error prompt (around line 288)
   - Phase 3 pre-preview preflight dispatch-error prompt (around line 300)
   - Gate #3 § 4.4 narrative approval (around line 378, Approve / Edit / Regenerate)
   - Any other multi-option `AskUserQuestion` caught by grep sweep

**Verify:** `grep -c "gate-respect" plugins/cadence/commands/weekly.md` returns ≥7 (1 header section link + 6 gate-site reminders minimum).

---

### Task 5 — Add gotcha line to `plugins/cadence/CLAUDE.md`

**File:** `plugins/cadence/CLAUDE.md`

**Change:** Append one new bullet to the `## Gotchas` section (after line 51):

```markdown
- **Gate-respect contract.** Once the user picks an option at an `AskUserQuestion` gate with >1 option, the skill runs exactly that behavior — never silently self-selects a lighter variant, even under context pressure, scale friction, or "pragmatic" observation. Writing to a notes/log/breadcrumb file is NOT permission to deviate; re-prompt via a new `AskUserQuestion`. Full contract: `skills/_shared/gate-respect.md`. Origin: BC-5866 (W17 dogfood).
```

**Verify:** `grep -q "Gate-respect contract" plugins/cadence/CLAUDE.md` exits 0.

---

### Task 6 — Write the structural linter `lint_cadence_gates.py`

**File:** `scripts/_lib/lint_cadence_gates.py` (new)

**Behavior (mirrors `lint_hooks.py` OK:/ERROR: convention):**
- CLI: `python3 lint_cadence_gates.py <cadence-plugin-dir>` (default `plugins/cadence/`).
- Walks every `skills/*/SKILL.md` (skipping `_shared/`), every `commands/*.md`.
- For each file:
  - Count `AskUserQuestion` literal occurrences that are inside `## § N` or `### N.N` sections (exclude comments and prose mentions in deferred/references sections).
  - A file that has ≥1 such occurrence is an "AUQ file" subject to the contract.
  - For AUQ files, check:
    - (a) Header section `## Gate-respect` exists AND its body contains a link to `_shared/gate-respect.md` (relative path).
    - (b) Every `AskUserQuestion` occurrence in §-level sections is preceded (within 20 lines above, in the same §-section) by at least one comment matching `gate-respect:` — OR the entire § has one top-of-section comment matching `gate-respect:` after the `## §` heading.
- Emit `OK:<file> — gate-respect header + N call-site reminders` on pass.
- Emit `ERROR:<file> — missing gate-respect header` / `ERROR:<file>:§<N> — <M> AskUserQuestion call(s) without gate-respect reminder` on fail.
- Exit 0 on normal runs (success + validation errors); validate.sh parses OK:/ERROR: lines (see `lint_hooks.py` § 90–96 + validate.sh § 631–646 precedent).
- Exempt allowlist: file-name list inside the script — `issue-quality-gate/SKILL.md`. Prose `AskUserQuestion` mentions inside `## § X References` or `## Deferred to follow-up issues` sections don't count (filter by section heading before scanning).

**Python stdlib only** (per memory `No PyYAML in test scripts`). Use regex + string splitting on `## § ` and `## Deferred`.

**Verify (TDD):**
1. Red: craft a minimal fixture string in-script at `__main__` — a dummy cadence skill markdown with one `AskUserQuestion` and NO header/comment. Confirm the linter emits `ERROR:…`.
2. Green: run `python3 scripts/_lib/lint_cadence_gates.py plugins/cadence` AFTER Tasks 1–4 land; confirm `OK:` for all three files.

---

### Task 7 — Wire linter into `scripts/validate.sh`

**File:** `scripts/validate.sh`

**Change:** Insert a new `## 12.5 Cadence Gate-Respect` section between existing § 12 (Step Sequence) and § 13 (or whatever currently sits at that slot — check line numbers at implement time). Only runs when `$plugin_name == "cadence"`. Invokes `python3 "$REPO_ROOT/scripts/_lib/lint_cadence_gates.py" "$PLUGIN_ROOT"` and parses OK:/ERROR: per existing convention (mirror the block at lines 631–646).

**Verify:**
- `./scripts/validate.sh` runs clean on the worktree at the end of execution (zero errors, warnings within baseline).
- If any of Tasks 1–4 are incomplete, validate.sh fails with the specific missing-contract error from the linter.

---

### Task 8 — Self-verify end-to-end

**Commands:**
1. `./scripts/validate.sh 2>&1 | tee /tmp/bc-5866-validate.log` — expect 0 errors, baseline warnings.
2. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — expect 0 violations.
3. Manual grep audit: `grep -rn "gate-respect" plugins/cadence/` — confirm every AskUserQuestion-rendering file has ≥1 header + ≥1 call-site reminder.
4. Deliberate-break test: temporarily delete `## Gate-respect` section from `sprint-scoping/SKILL.md`, re-run `validate.sh`, confirm it fails with the expected ERROR line. Restore the section.

**Verify:** All four pass. Step 4 proves AC #4 bite (linter catches missing contract).

---

## Risk register

- **File-conflict with concurrent cadence workstreams.** Mitigated by the worktree-based branch. If another session lands a concurrent edit to sprint-scoping/SKILL.md or linear-housekeeping/SKILL.md before this PR merges, rebase and re-insert the contract references at the new line numbers.
- **Comment-syntax drift.** The `<!-- gate-respect: -->` marker must not overlap with other markdown-comment conventions. Grep for existing `<!--` lines in the target files: `grep -n "<!--" plugins/cadence/skills/**/*.md plugins/cadence/commands/*.md` — confirm no collision.
- **Linter false-positives on "AskUserQuestion" prose mentions** (e.g. in § References, § Deferred, or explanatory paragraphs). Mitigation: linter allowlists `## § X References` and `## Deferred` sections, and scopes the "AUQ occurrence" regex to `AskUserQuestion` appearing inside a `### N.N` or `## § N` structured-content section — not a bullet-list explanatory note. Test case: sprint-scoping § 9 mentions `AskUserQuestion` in a deferred note; must not count.

## References

- [BC-5866 Linear issue](https://linear.app/brite-nites/issue/BC-5866/cadence-skills-must-not-self-select-a-lower-option-pattern-when-user)
- [BC-5763 parent — W18 dogfood](https://linear.app/brite-nites/issue/BC-5763)
- `docs/designs/cadence-orchestration.md` § 1.1c + § 2.3 (BC-5810) — per-question adaptive-skip spec this contract re-affirms
- `memory/feedback_honor_user_gate_selection.md` — planner rule that motivated this issue
- `memory/feedback_no_condensed_shortcuts_in_skill_specs.md` — sibling rule
- `scripts/_lib/lint_hooks.py` — Python-stdlib-only linter precedent this new linter mirrors
- `scripts/validate.sh` § 11 (hooks linter invocation) — wiring precedent
