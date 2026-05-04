---
issue: BC-6557
title: Research/design — smart-merge formula layer for content variables
scope: research-deliverable
session_date: 2026-05-04
---

# BC-6557 plan — smart-merge formula layer (research/design)

## Context

BC-6557 is the long-term-direction follow-up to BC-6549 / BC-6556. BC-6556 shipped the near-term backstop (fail-closed gate when content variables have empty defaults at launch). BC-6557 designs the richer fallback layer Holden proposed — a per-variable formula that produces a clean rendered string per lead, even when the lead's raw value is missing.

This is a **research/design issue.** Deliverable is a design doc + working Python prototype. Production implementation is a separate follow-up ticket (deferred until Holden review).

## Per-task execution protocol

Per user pacing preference for this issue:

1. Execute one task end-to-end
2. Run the task's Verify step(s); paste/show output to user
3. User confirms they're following + nothing broke
4. Commit (one commit per task, message format: `BC-6557: task N — <short summary>`)
5. Move to next task

If verify fails or user is confused: pause, debug, re-verify, only then commit. Never commit broken state.

## Locked-in design decisions (from brainstorm session)

These are settled, not open. Plan tasks transcribe them into the doc.

| Item | Decision |
|---|---|
| Formula execution home | launch-campaign Phase 4 (just before EB upload) — only place with both per-lead context and the upload point |
| Formula authoring home | email-copywriting skill, in copy artifact JSON, alongside variable name |
| Authoring library | Preset files extend to carry suggested formulas per variable per vertical |
| Verbs (v1) | `use_raw` (always); `substitute_static` (substitute string when raw missing); `valid_if` (optional quality predicate, defaults to non-null/non-empty) |
| Variable-referencing in fallbacks | Included in v1. Engine routes fallback string through existing render engine. |
| No-cascading rule | Fallback strings can reference campaign-level variables and built-in (CSV-row) variables, but NOT other per-lead variables that have their own formulas. v2 may lift this rule. |
| Schema | New `formula` field alongside existing `default`. Both keep working. Formula wins if present. |
| Belt-and-suspenders rule | Authors MUST write a non-empty `default` even when also writing `formula`. Guarantees rollback path. |
| Raw-column population (per-lead enrichment) | OUT OF SCOPE. That's enrichment's job (BC-5537 / BC-2727). |
| Drop-neighborhood / drop-clause / conditional / multi-tier / recursive | OUT OF SCOPE for v1. Documented as future work. |
| Implementation issue spawn | DEFERRED. Don't file the build ticket until Holden has reviewed. |

---

## Tasks

### Task 1 — Create design doc skeleton

**Output:** `docs/research/smart-merge-formula-design.md`

**Steps:**
1. Create the file with YAML frontmatter (issue: BC-6557, status: research/design, date, related issues list).
2. Add empty section headings in this order: Context · Architecture · Formula Language · Schema · Examples · Migration · Rollback · Out of Scope · Open Questions · Sources.

**Verify:**
- `test -f docs/research/smart-merge-formula-design.md` succeeds
- `grep -c "^## " docs/research/smart-merge-formula-design.md` returns 10
- `grep -c "^---$" docs/research/smart-merge-formula-design.md` returns 2 (frontmatter delimiters)

**Commit:** `BC-6557: task 1 — design doc skeleton`

---

### Task 2 — Write Context section

**Output:** `## Context` section populated in `docs/research/smart-merge-formula-design.md`

**Steps:**
1. Write 1-2 paragraphs covering: empty-render finding from BC-6308 round-3 (R-2b); BC-6556 backstop; Holden's per-variable-formula proposal; this issue's scope (design + prototype, not build).
2. Reference launch-campaign.md line 217 (which already cites BC-6557 by name).

**Verify:**
- Section is non-empty (`awk '/^## Context/,/^## /' docs/research/smart-merge-formula-design.md | wc -l` > 5)
- References "BC-6549", "BC-6556", "BC-6308" by name
- States "design + prototype, not build" verbatim

**Commit:** `BC-6557: task 2 — context section`

---

### Task 3 — Write Architecture section

**Output:** `## Architecture` section

**Steps:**
1. Explain the two seams: formula execution (launch-campaign Phase 4), formula definition (copy artifact JSON, authored by email-copywriting).
2. Justify the split (execution needs per-lead data + upload point; definition needs template position context).
3. Include an ASCII data-flow diagram: `lead row → (raw value | null) + formula → rendered string → custom_variables[].value → EB upload`.
4. Carve out raw-column population as out of scope (Holden's enrichment territory).
5. Briefly note rejected alternatives (list-building / campaign-orchestration / launch-campaign-runtime / separate-skill).

**Verify:**
- Section names "launch-campaign Phase 4" and "email-copywriting" both
- Has ASCII diagram (contains `→` or `->`)
- Explicitly says raw-column population is out of scope

**Commit:** `BC-6557: task 3 — architecture section`

---

### Task 4 — Write Formula Language section (verbs + rules)

**Output:** `## Formula language` section

**Steps:**
1. Define each verb with semantics + 1 example: `use_raw`, `substitute_static`, `valid_if` (optional).
2. State the no-cascading rule verbatim.
3. State the belt-and-suspenders rule verbatim (`default` required non-empty even when `formula` present).
4. Render-order pseudocode: check raw → check `valid_if` → use raw if valid, else render `formula.if_missing` through render engine.

**Verify:**
- Section names all 3 verbs
- Both rules stated word-for-word
- Pseudocode block present

**Commit:** `BC-6557: task 4 — formula language section`

---

### Task 5 — Write Schema section

**Output:** `## Schema` section

**Steps:**
1. Show today's `custom_variables[]` schema (bare-string `default`).
2. Show tomorrow's `custom_variables[]` schema (`default` + optional `formula` object).
3. One full JSON example of a variable with formula.
4. State explicitly: existing artifacts continue to work without modification.
5. Reiterate the required-non-empty-`default` rule.

**Verify:**
- Both schemas present (today vs. tomorrow)
- One full JSON example with a `formula` object
- "non-breaking" / "additive" stated

**Commit:** `BC-6557: task 5 — schema section`

---

### Task 6 — Write Examples section (concrete per-variable cases)

**Output:** `## Examples` section

**Steps:**
1. For each of 4 priority variables, show: real template position (cite preset file where applicable) + empty-render breakage + recommended formula + rendered output for both raw-present and raw-null.
2. Variables: `RECENCY_ANCHOR`, `PROOF_POINT_COMPANY`, `SPECIFIC_FRICTION`, `FIRST_NAME`.
3. Note explicitly that PROOF_POINT_COMPANY and SPECIFIC_FRICTION are forward-looking (not in current production presets, but plausible in per-lead enriched future).

**Verify:**
- All 4 variables have a complete example block
- Each example shows both raw-present and raw-null cases
- Production preset files cited where applicable

**Commit:** `BC-6557: task 6 — examples section`

---

### Task 7 — Write Migration + Rollback sections

**Output:** `## Migration` and `## Rollback` sections

**Steps (Migration):**
1. State: existing copy artifacts continue to work unchanged; formulas are purely additive.
2. Note: email-copywriting skill changes are a separate ticket, not part of BC-6557.

**Steps (Rollback):**
1. Render the 7-row rollback table from the brainstorm.
2. Big-picture rollback path: stop writing `formula` fields, engine ignores any present, all campaigns fall back to `default`.
3. Note the one cost that ISN'T reversible: time/effort sunk into engine + prototype (bounded by deferred impl-issue).

**Verify:**
- Migration says "additive" or "non-breaking"
- Rollback table has all 7 design-decision rows
- Big-picture rollback path stated

**Commit:** `BC-6557: task 7 — migration and rollback sections`

---

### Task 8 — Write Out of Scope + Open Questions sections

**Output:** `## Out of Scope` and `## Open Questions` sections

**Steps (Out of Scope, with concrete revisit triggers):**
1. Drop-neighborhood verb
2. Drop-clause verb
3. Conditional logic across variables
4. Multi-tier fallback
5. Recursive formula evaluation
6. Format transformations

**Steps (Open Questions):**
1. Does home pick (execution at Phase 4, definition in copy artifact) match Holden's intent?
2. Is no-cascading rule acceptable for v1, or recursive-from-day-1 preferred?
3. Should `valid_if` be authored by email-copywriting alone (v1 plan) or split with enrichment side?
4. Acknowledge: implementation issue spawn deferred pending Holden review.

**Verify:**
- All 6 out-of-scope items present with revisit-triggers
- All 4 open questions present
- Holden named explicitly as reviewer

**Commit:** `BC-6557: task 8 — out-of-scope and open-questions sections`

**[Natural pause point — full design doc skeleton is now drafted. Recommended user review before continuing to prototype.]**

---

### Task 9 — Write the Python prototype script

**Output:** `docs/research/smart-merge-prototype.py`

**Steps:**
1. Write a Python 3 script (~80-120 lines, stdlib only — `csv`, `json`, `argparse`, `re`, `sys` allowed).
2. CLI: `python smart-merge-prototype.py --leads <csv> --variables <json>` → prints rendered output per lead.
3. Implements: read leads CSV (built-in fields + per-lead custom_variables columns); read variables JSON (with `default` + optional `formula`); evaluate raw → `valid_if` → use raw if valid, else render `formula.if_missing` through substitution engine; print rendered template body per lead.
4. Sample template at top of script (a 1-paragraph email body using all 4 priority variables).

**Verify:**
- File exists; passes `python -c "import ast; ast.parse(open('docs/research/smart-merge-prototype.py').read())"` (syntax check)
- Stdlib only: `grep -E "^import|^from" docs/research/smart-merge-prototype.py | grep -vE "import (csv|json|sys|argparse|re|os|pathlib)"` returns empty
- Has CLI args `--leads` and `--variables`

**Commit:** `BC-6557: task 9 — prototype script`

---

### Task 10 — Build sample input data + run prototype

**Outputs:**
- `docs/research/smart-merge-sample-leads.csv` — 5 leads, mix of populated/null per-lead values
- `docs/research/smart-merge-sample-variables.json` — variable definitions covering all 3 verbs, including one variable-referencing fallback (per-lead → campaign-level)

**Steps:**
1. Create the CSV with 5 fake-but-realistic leads, varying which per-lead columns are populated vs null.
2. Create the JSON with variable definitions for the 4 priority variables, exercising: `use_raw` only (no formula), `substitute_static` (formula with literal fallback), `substitute_static` with variable-reference (formula falling back to a campaign-level variable), `valid_if` (formula with quality predicate).
3. Run: `python docs/research/smart-merge-prototype.py --leads docs/research/smart-merge-sample-leads.csv --variables docs/research/smart-merge-sample-variables.json` and capture stdout.

**Verify:**
- Both input files exist; CSV has header + 5 data rows
- Script exits 0
- Stdout shows: leads with raw values render raw; leads with null raw render the formula's fallback; variable-referencing fallback resolves cleanly
- Output covers all 4 priority variables

**Commit:** `BC-6557: task 10 — sample data and prototype run`

---

### Task 11 — Embed prototype output in design doc

**Output:** New "Prototype evidence" subsection at the end of `## Examples` section in `docs/research/smart-merge-formula-design.md`

**Steps:**
1. Take the captured stdout from Task 10.
2. Show in the doc: 1-2 sample leads as input + relevant variable definitions + the rendered output for each.
3. Add one paragraph commentary: "this demonstrates that the 3-verb formula language plus variable-referencing produces clean rendered emails for both raw-present and raw-missing cases."
4. Cite the prototype file path so a reader can re-run.

**Verify:**
- "Prototype evidence" subsection exists
- Shows both raw-present and raw-null cases
- Cites `docs/research/smart-merge-prototype.py`

**Commit:** `BC-6557: task 11 — prototype evidence embedded in doc`

**[Natural pause point — full deliverable is now complete. Recommended user review before final cross-link + commit pass.]**

---

### Task 12 — Cross-link + final self-review

**Output:** Updates to `docs/research/smart-merge-formula-design.md` (Sources section) + AC checklist in this plan

**Steps:**
1. Add Sources section content: Linear URLs for BC-6549, BC-6556, BC-6308, BC-5537, BC-2717, BC-2727; production preset file paths; dogfood evidence paths.
2. Self-review against BC-6557's 5 ACs (4 met, 1 deferred); update this plan's AC table to mark which is deferred.
3. Optional: attach the design doc URL to BC-6557 via Linear MCP if supported.

**Verify:**
- Sources section non-empty, contains all 6 Linear issue references
- AC table updated in this plan with status per criterion

**Commit:** `BC-6557: task 12 — cross-links and self-review`

---

### Task 13 — Final commit + push

**Output:** Branch pushed; ready for Holden review

**Steps:**
1. `git status` to confirm all expected files are tracked + clean.
2. Push: `git push -u origin <branch-name>` (branch created earlier in worktree setup).
3. Optional: open a draft PR with title `BC-6557: smart-merge formula layer — research/design + prototype` and body explaining: design doc + Python prototype landed; impl-issue spawn deferred pending Holden review; refs BC-6549, BC-6556, BC-6308.

**Verify:**
- `git status` is clean
- `git log --oneline | head -1` shows the latest commit on the branch
- Branch visible on remote (`git ls-remote origin <branch-name>` succeeds)

**Commit:** N/A (this task is the push, not a new commit)

---

## Acceptance criteria mapping

| AC | Status |
|---|---|
| Research deliverable exists at `docs/research/smart-merge-formula-design.md` | Tasks 1-8, 11, 12 |
| Document picks the home with reasoning | Task 3 |
| Document defines the formula DSL with concrete examples for high-risk variables | Tasks 4-6 |
| Prototype demonstrates formula logic against sample CSV | Tasks 9-11 |
| Implementation issue filed (separate ticket) | **DEFERRED** — flagged in Task 8 Open Questions and Task 12 self-review |

## Out of scope for this session

- Wiring the engine into launch-campaign Phase 4 (production implementation)
- Email-copywriting skill changes to author formulas
- Updating email-copywriting evals.json to allow new schema
- Filing the implementation issue ticket
- Touching any preset files

## References

- Issue: https://linear.app/brite-nites/issue/BC-6557
- BC-6556 PR: https://github.com/Brite-Nites/brite-claude-plugins/pull/245
- launch-campaign.md line 217 — already cites BC-6557 as the deeper context-aware fallback
- Production presets: `plugins/marketing/skills/email-copywriting/presets/list-building-ski-resorts.md`, `list-building-casinos.md`, `risk-reversal-sports-stadiums.md`
- Dogfood evidence: `docs/dogfood/bc-6308/test-copy.json`, `launch-metadata.json`
