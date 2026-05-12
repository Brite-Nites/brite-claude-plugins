# BC-6971 — /flow:office-hours implementation plan

> Source-of-truth memory: `~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md`
> - Q42 lock (lines 885+) — 7 sub-decisions
> - Q42 refinement audit trail (line 970)
> - Q31 amendment 1 (line 318) — `office_hours_state` slot
> - Q41 template — verified live at `Brite-Nites/handbook:about-handbook/style-guide/templates/project-intent.md`
> - CDR-013 — verified live at `Brite-Nites/handbook:decisions/CDR-013-project-standards.md`; 4 overlapping-section pre-fill pairs match.

## Deliverable

Single new command file: `plugins/flow-architecture/commands/office-hours.md` (utility command, not orchestrator — no breadcrumb writes from the command itself; reads breadcrumb on resume).

## Approach

The spec is fully locked (Q42 + Q31 amendment 1). No design decisions remain. Drafting tasks are mechanical assembly of the locked sub-decisions into the existing `commands/<name>.md` shape (precedent: `commands/audit.md`, `commands/start-project.md`).

## Tasks

### Task 1 — Draft `plugins/flow-architecture/commands/office-hours.md` body

File sections (in order):

1. **Frontmatter** — `description:` one-liner matching CLAUDE.md surface map ("utility command — project-intent interview with internal L1-review phase").
2. **Lede** — Single paragraph: utility scope, output target (`docs/product/intent.md`), Q42 lock cite, parking-lot v1.1 notes (Q46 Linear routing of L1 concerns parked per Q42 sub-decision 4).
3. **DO NOT re-derive** banner pointing to Q42 / Q41 / Q31 amendment 1 / Q54 / four-mode-framework.
4. **Invocation contract**:
   - User-invocable + auto-invoked from `/flow:start-project` Phase 2 + `/flow:retrofit-project` (when intent.md absent).
   - Flags: `--linear-context={auto|skip|force}` + `--refresh`.
   - Defaults decision tree (7 states) — verbatim cite from memory:889–899 as markdown table.
5. **Input contract — hybrid (CDR-013 Build Brief + interview gap-filling)**:
   - `--linear-context=auto` (default) — preflight via `get_project`; if description has CDR-013 shape (regex-detect `## Problem` + `## Outcome`), parse + use as pre-fill for 4 overlapping sections.
   - `--linear-context=skip` — pure interview.
   - `--linear-context=force` — require CDR-013 shape or error.
   - CDR-013 → Q41 mapping table (4 pairs, verbatim per Q42 sub-decision 2).
6. **Interview shape — sequential `AskUserQuestion`, one section at a time**:
   - 6 substantive Q41 sections (Mission / Target users / Problem we're solving / Success criteria / Out of scope / Constraints). L1 review summary auto-populated separately.
   - Per-section UX: display Q41 section description, show pre-fill draft (if any) with Approve / Edit / Replace, free-text input with Q41 length guidance.
   - Per-section validation: soft-warn `AskUserQuestion` when input doesn't meet shape guidance. User retains final call.
   - Final-review step: after all 6 sections, fire `AskUserQuestion` "Approve / Edit specific section / Cancel" (FIX-2(b) AC: 3 separate greps).
7. **L1 dispatch — after final-review approves**:
   - 4 agents in parallel (`plan-ceo-reviewer`, `plan-design-reviewer`, `plan-eng-reviewer`, `plan-devex-reviewer`) via Agent tool with `run_in_background: true`.
   - Each agent receives `review_input` per four-mode-framework.md — `perspective`, `scope_level: "L1"`, `context: {q41_template, linear_brief_snapshot?, custom_framing?}`.
   - Collect 4 returns: `{mode, headline, ...}`. Headlines populate intent.md `## L1 review summary` four sub-headings (CEO / Design / Engineering / Developer-experience).
   - Concerns persist to `docs/plans/l1-concerns-<ISO-8601>.md` (4 H2 sections).
   - UX message before completion: "L1 review surfaced <N> concerns across 4 perspectives — review at `docs/plans/l1-concerns-<timestamp>.md`."
8. **Atomic write semantics (Q42 sub-decision 5)**:
   - Final-atomic-write only — NOT incremental. Single write per Q31.5 pattern (write to `<path>.tmp` → atomic `mv` → parse-verify).
   - Fires AFTER all sections + final-review approved + L1 review fires + headlines populated.
   - Embed all three phrasings to satisfy fuzzy-regex AC: `final-atomic-write`, `atomic.write`, `tmp.*mv`.
9. **Resume contract**:
   - Cite Q31 amendment 1 + `office_hours_state` schema.
   - Resume behavior: read `sections_completed`, offer per-section "preserve / edit / re-do", resume interview from first incomplete; on L1 phase resume, skip perspectives marked `complete` with stored results.
   - Stale-breadcrumb policy lives in flow-preflight Q31.3 — orchestrator does not re-implement.
10. **Output**: `docs/product/intent.md` exists; front-matter populated; all 6 body sections present; `## L1 review summary` populated with 4 sub-headings.
11. **Auto-invocation contract** — paragraph noting `/flow:start-project` Phase 2 + `/flow:retrofit-project` `intent.md`-absent path.
12. **Gate-respect contract** — paragraph pointing to `_shared/gate-respect.md` (Once user picks option, execute exactly that option; mentions in batch notes do NOT constitute authorization).
13. **See also**:
   - Q42 lock cite (`plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:885`)
   - Q41 template URL on handbook
   - CDR-013 URL on handbook
   - `_shared/four-mode-framework.md`
   - `agents/plan-{ceo,design,eng,devex}-reviewer.md`
   - `scripts/flow-resume-breadcrumb.sh` (Q31.5 atomic-rename helper)
   - sibling `commands/audit.md` (utility-shape precedent)

Length target: ~250–400 LOC matching audit.md utility shape.

**Embed-verbatim discipline (per Q-lock-respect):** the Defaults decision tree (memory:889–899) and CDR-013 → Q41 mapping (Q42 sub-decision 2) are cribbed verbatim from memory and the live handbook template respectively. Do not paraphrase.

### Task 2 — Verify ACs locally

Run each acceptance-criteria grep against the new file:

```bash
F=plugins/flow-architecture/commands/office-hours.md
test -f "$F" || echo FAIL:exists
grep -q "intent.md" "$F" || echo FAIL:intent.md
grep -q "L1 review summary" "$F" || echo FAIL:l1-summary
grep -q "plan-ceo-reviewer" "$F" || echo FAIL:ceo
grep -q "plan-design-reviewer" "$F" || echo FAIL:design
grep -q "plan-eng-reviewer" "$F" || echo FAIL:eng
grep -q "plan-devex-reviewer" "$F" || echo FAIL:devex
grep -q -- "--linear-context" "$F" || echo FAIL:flag-context
grep -q -- "--refresh" "$F" || echo FAIL:flag-refresh
grep -q -- "--linear-context=auto" "$F" || echo FAIL:auto
grep -q -- "--linear-context=skip" "$F" || echo FAIL:skip
grep -q -- "--linear-context=force" "$F" || echo FAIL:force
grep -qE "final-atomic-write|atomic.write|tmp.*mv" "$F" || echo FAIL:atomic
grep -q "Approve" "$F" || echo FAIL:approve
grep -q "Edit" "$F" || echo FAIL:edit
grep -q "Cancel" "$F" || echo FAIL:cancel
```

All 16 must pass silently (no `FAIL:*` lines).

### Task 3 — Bump plugin version + marketplace entry (BC-6000 same-commit rule)

Both files in the same commit as the new command file:

- `plugins/flow-architecture/.claude-plugin/plugin.json` — `0.2.19` → `0.2.20`
- `.claude-plugin/marketplace.json` — flow-architecture entry `0.2.19` → `0.2.20`

### Task 4 — Run repo validators

```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md plugins/flow-architecture/CLAUDE.md
```

Both must exit 0.

## Out-of-scope (per issue body)

- v1.1 routing L1 concerns to Linear via Q46 writeback (parking lot per Q42 sub-decision 4).
- `/flow:design-consult` (Q45 v1.1 deferral).
- gstack design-consultation interview branches (Q42 sub-decision 7 NOT-transferred).

## Risk / known gotchas

- **APFS case-insensitive gotcha** (BC-6969): `commands/office-hours.md` lowercase; no current rule conflicts in `.gitignore` (verified `git check-ignore -v` after write before commit).
- **Write tool absolute-path discipline** (gotcha_write_tool_worktree_path): all Write/Edit calls must include `.claude/worktrees/bc-6971-office-hours/` prefix or files land in the primary checkout.
- **Plugin cache key** (BC-6000): version bump MUST be in the same commit as the command file or downstream clients serve stale cache.

## Done condition

- All 16 grep ACs pass.
- `./scripts/validate.sh` exits 0.
- `./scripts/check-guardrails.sh --claude-md plugins/flow-architecture/CLAUDE.md` exits 0.
- Plugin + marketplace versions bumped in the same commit.
- Ready for `/workflows:review`.
