# BC-5872 — Lock SQ3 to three options; ban "Add co-owner" improvisation

**Linear:** BC-5872 (parent BC-5763) — Cadence Plugin milestone
**Branch:** `holden/bc-5872-sq3-co-owner-option`
**Worktree:** `.claude/worktrees/bc-5872/`
**Option selected:** **A — remove "Add co-owner" from SQ3** (user-locked, 2026-04-22)

## Summary

W17 attempt1 dogfood surfaced a Phase 2 SQ3 runtime improvisation — an *"Add co-owner"* option that does not map to Linear's single-assignee data model. Attempt2 (post-BC-5864/5865) empirically dropped the option, but the drop is not codified — a future regression could reintroduce it. This plan codifies Option A: lock SQ3's options to Keep existing / Reassign / Other in `sprint-scoping/SKILL.md § 4`, extend the `lint_cadence_gates.py` linter with BC-5872 forbidden-phrase regexes, and update the plugin CLAUDE.md gotcha bullet to list BC-5872 alongside BC-5864/5865 as a mechanical instance of the BC-5866 class-fix contract.

Mirrors the BC-5864/5865 PR shape (PR #173): contract-addition + linter-extension + CLAUDE.md bullet update + deliberate-break test confirms the regex bites.

## Acceptance criteria (from BC-5872)

- [x] Decision made between A / B / C → **Option A locked** (this plan)
- [ ] Codified in `sprint-scoping/SKILL.md`'s SQ3 prompt template — lock options list + STOP block
- [ ] Seeded test of SQ3 co-owner pick flow — linter deliberate-break rejects `*Add co-owner*` authorization line
- [ ] Option B/C surface (new mutation type / Phase 5 row / state field) — N/A under Option A

## Task list (8 tasks, each 2–5 minutes)

### Task 1 — Add `## § 4.1 SQ3 option lock` subsection

**File:** `plugins/cadence/skills/sprint-scoping/SKILL.md`

**Location:** Directly after the § 4 SQ1–SQ5 table (currently ends at the line `| SQ5 | Explicitly parked this cycle? | Agent proposes from stale current-cycle items + Low-priority carry-over |`). Insert BEFORE the `## § 5 Quality gate + block-with-override` header.

**Content to add** (new subsection; mirrors § 2's "Specifically banned improvisation patterns" style):

```markdown
### § 4.1 SQ3 option lock

SQ3's `AskUserQuestion` MUST render exactly three options (plus the implicit "Other" free-text escape):

1. **Keep existing assignees** `(Recommended)`
2. **Reassign to `<name>`** — single-assignee change; one target name
3. **Mark unassigned** — clears `assignee` to `null`

Linear has exactly one `assignee` field per issue. SQ3 maps 1:1 to that field. Specifically banned improvisation patterns (origin: BC-5872 W17 attempt1 dogfood):

- *"Add co-owner"* / *"co-owner on <ID>"* — no such field in Linear; if picked, Phase 3 silently drops the second assignee or silently replaces the first.
- *"co-watcher"* / *"Add subscriber as co-owner"* — `subscribers` is a watchers list, not an owners list. Reframing ownership as watching persists a different semantic mismatch.
- *"multi-assignee"* / *"multiple assignees"* / *"Holden + Rainer both on BC-XXXX"* — any phrasing that implies a list-valued assignee.

If co-ownership becomes a legitimate weekly pattern, file a spec amendment to BC-5810 § 2.2 — do not improvise here. The escape path for one-off co-lead intent is **Phase 5 manual-ops checklist** (the planner writes a freeform row after the run); SQ3 itself stays locked to the three options above.
```

**Verify:** `sed -n '107,140p' plugins/cadence/skills/sprint-scoping/SKILL.md` shows the new subsection between the SQ table and § 5.

### Task 2 — Add BC-5872 regex tier to `FORBIDDEN_PHRASE_PATTERNS`

**File:** `scripts/_lib/lint_cadence_gates.py`

**Location:** Inside the `FORBIDDEN_PHRASE_PATTERNS` list (lines 69–79). Append a new comment-labeled tier BELOW the existing BC-5865 block.

**Content to add:**

```python
    # BC-5872: SQ3 co-owner improvisation (Linear single-assignee mismatch)
    (re.compile(r"add\s+co-owner", re.IGNORECASE), "BC-5872"),
    (re.compile(r"\bco-owner(?:s|ship)?\b", re.IGNORECASE), "BC-5872"),
    (re.compile(r"\bco-watcher\b", re.IGNORECASE), "BC-5872"),
    (re.compile(r"multi-assignee", re.IGNORECASE), "BC-5872"),
    (re.compile(r"multiple\s+assignees", re.IGNORECASE), "BC-5872"),
```

**Rationale:** Five regexes because the W17 attempt1 prompt surfaced three distinct phrasings (*"Add co-owner on BC-5857"*, *"Rainer + Holden both on BC-5857"*, *"Holden as creative-side lead"*) plus Option B's `"Add subscriber / co-watcher"` reframing. The italic-quote + negation-cue exempt patterns already in `FORBIDDEN_EXEMPT_PATTERNS` (lines 89–99) will correctly exempt the STOP-block citations from Task 1.

**Verify:** `python3 scripts/_lib/lint_cadence_gates.py plugins/cadence` returns green (no ERROR lines for sprint-scoping/SKILL.md) because the Task 1 citations are italic-quoted.

### Task 3 — Deliberate-break test: confirm each BC-5872 regex bites

**File:** `plugins/cadence/skills/sprint-scoping/SKILL.md` (temporary edit)

**Steps:**
1. In § 4.1 (freshly added in Task 1), temporarily insert at the bottom of the subsection body: `Planner may add co-owner when site-visit co-lead is needed.` (no italic quote, no negation cue — should trigger BC-5872).
2. Run `python3 scripts/_lib/lint_cadence_gates.py plugins/cadence`.
3. Confirm at least two ERROR lines fire, one per matching regex (`add co-owner` + `co-owner`), with `banned by BC-5872` in the message.
4. Revert the insertion.

**Verify:** After revert, linter is green again.

### Task 4 — Update plugin CLAUDE.md Gate-respect gotcha bullet

**File:** `plugins/cadence/CLAUDE.md`

**Location:** The last line of the **Gate-respect contract** bullet in the `## Gotchas` list — currently reads:

> *"First mechanical instances shipped: BC-5864 (project-level triage gate removed at Phase 2 entry) + BC-5865 (condensed-prompt shortcut removed from § 3 + § 4)."*

**Content change (Edit tool):**

```
BC-5864 (project-level triage gate removed at Phase 2 entry) + BC-5865 (condensed-prompt shortcut removed from § 3 + § 4) + BC-5872 (SQ3 co-owner improvisation removed from § 4).
```

### Task 5 — Run full `validate.sh` baseline

**Command:** `./scripts/validate.sh`

**Expected:** 0 errors, warnings consistent with baseline (16 per BC-5866 ship note). The Cadence Gate-Respect § 12.5 block should show OK lines for `sprint-scoping/SKILL.md` (with the 5 existing call-site reminders preserved).

### Task 6 — Smoke-test the linter with the previously-shipped deliberate-break fixtures

**Command:** `cd /tmp && cat > bc5872-smoke.md <<'EOF'
# Test

## § 1 Smoke

**Add co-owner on BC-XXXX when needed.**
EOF
python3 <repo>/scripts/_lib/lint_cadence_gates.py <repo>/plugins/cadence`

**Expected:** Not needed — Task 3 covers it for the real file. Skip if Task 3 passed.

### Task 7 — Commit message

**Subject:** `BC-5872: lock SQ3 options to keep/reassign/unassign; ban co-owner improvisation`

**Body sketch:**

```
Surfaced by W17 attempt1 dogfood (2026-04-20, project #1/26 SQ3). Attempt2 post-
BC-5864/5865 empirically dropped the "Add co-owner" option, but the drop was
not codified.

Option A: remove "Add co-owner" from SQ3.
- plugins/cadence/skills/sprint-scoping/SKILL.md § 4.1 adds a lock subsection
  enumerating the three permitted options + a STOP block with 5 banned phrasings.
- scripts/_lib/lint_cadence_gates.py extends FORBIDDEN_PHRASE_PATTERNS with 5
  BC-5872 regexes covering co-owner / co-watcher / multi-assignee phrasings.
- plugins/cadence/CLAUDE.md gotcha bullet names BC-5872 as a third mechanical
  instance of the BC-5866 class-fix contract, alongside BC-5864/5865.

Mirrors PR #173 (BC-5864+BC-5865) shape. Co-authored-by Claude.
```

### Task 8 — Open PR and update Linear

Handled by `/workflows:ship` after review. Plan will produce:
- Precedent trace `docs/precedents/BC-5872.md` (pattern-application category, confidence ~6/10 — derivative of BC-5866 template)
- `docs/precedents/INDEX.md` new row
- Linear comment on BC-5872 with PR link; mark Done on merge.

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| `co-owner` regex false-positive in other cadence files (e.g. narrative-writer referring to "co-owner" in an example) | Word-boundary `\b` anchoring; italic-quote exempt rule already in place; Task 6 smoke test would catch it |
| SQ3 rendering in actual runtime still drifts despite the lock | Out of scope for this PR — that's a runtime issue covered by BC-5874 third dogfood. This PR ensures the spec rejects drift if it happens. |
| Plan drift between `docs/plans/BC-5872-plan.md` and the shipped PR | Add a "Departures from plan" section to this plan if any task deviates (BC-5864/5865 precedent) |

## Departures from plan

**Added gate-respect reminder inside § 4.1** (not in original Task 1 body). The linter walks `##` and `###` headers as independent sections, so § 4.1 needs its own `<!-- gate-respect: ... -->` comment — § 4's comment does not cascade into its ### subsection. First linter run flagged `ERROR:...§ 4.1 SQ3 option lock: AskUserQuestion at line 118 without gate-respect reminder`. Added a one-line comment directly under the § 4.1 header; re-run returned 5 call-site reminders (up from 4). Deliberate-break test then bit two BC-5872 regexes as expected.

## References

- BC-5872 issue (full description + 3 options + AC)
- BC-5866 class-fix contract: `plugins/cadence/skills/_shared/gate-respect.md`
- BC-5864/5865 precedent: `docs/precedents/BC-5864-5865.md`
- BC-5810 § 2.2 SQ3 spec: `docs/designs/cadence-orchestration.md`
- W17 attempt1 dogfood: `weekly-planning/w17-2026-04-20-attempt1/dogfood-notes.md` § Entry 8
- Linter: `scripts/_lib/lint_cadence_gates.py` FORBIDDEN_PHRASE_PATTERNS
