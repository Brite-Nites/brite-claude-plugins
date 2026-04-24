# Plan: Cadence Phase 1 synthesis — filter-to-active + zero-activity footer

**Issue**: BC-5869 — Cadence Phase 1: 300-word synthesis cap breaks at 26 projects — codify an aggregation rule or raise the cap
**Branch**: `holden/bc-5869-phase-1-synthesis-cap-scale`
**Tasks**: 4 (estimated ~20 minutes)
**Design doc**: `docs/designs/bc-5869-phase-1-synthesis-cap-scale.md`

## Prerequisites

- Working from a git worktree rooted under `.claude/worktrees/bc-5869/` (set up by the git-worktrees skill in Step 7)
- `plugins/cadence/commands/weekly.md`, `plugins/cadence/CLAUDE.md`, and `docs/designs/bc-5869-phase-1-synthesis-cap-scale.md` accessible from that worktree path
- `/Users/holdenhalford/Projects/work/brite-nites/weekly-planning/w17-2026-04-20/audit.json` (sibling-repo path) readable for verification — 25 cards, 19 active, 6 zero-activity
- Linear MCP reachable (`mcp__plugin_workflows_linear-server__save_issue` + `get_issue` used in T3)
- **CDR alignment**: CDR check skipped (Context7 quota exceeded this session); handbook not indexed at plan time — no blockers
- **Precedent alignment**: aligns with BC-5902 (cadence architectural fix pattern — same W17 dogfood family; this plan inherits BC-5902's fail-loud-no-silent-degradation posture applied to rendering)

## Tasks

### Task 1: Rewrite `§ 1.6 User-facing synthesis` in `weekly.md`

**Files**: `plugins/cadence/commands/weekly.md`

**Why**: Replace the "bullet per project" rendering rule with "bullet per project with activity + single zero-activity footer" per the approved design. This is the single load-bearing change; the other tasks are downstream alignment.

**Implementation**:

1. In `plugins/cadence/commands/weekly.md`, locate the block starting at line 275 (`### 1.6 User-facing synthesis (≤300 words)`) and ending at line 284 (just before `### 1.7 Gate #1`).

2. Replace the heading line `### 1.6 User-facing synthesis (≤300 words)` with:
   ```
   ### 1.6 User-facing synthesis
   ```
   (Drop the `(≤300 words)` suffix — the cap becomes scale-aware, documented in the body rather than pinned to the header.)

3. Replace the body of § 1.6 with:

   ```markdown
   Render to the user:

   1. **Headline anchors** — one line: `<completion_rate>% completion / <shipped_total> shipped / <carry_over_total> carrying over / standouts: <team_standouts>`. (Note: `unplanned_ratio` headline lands in Phase 2 once the narrative parser extracts the planned baseline — see § 1.4 deferred list.)
   2. **Per-project drift bullets** — one line per project *with activity*: `**<project>** — <shipped> shipped, <carry_over> carrying over, <dropped> dropped. <highest-priority carry-over ID if any>`. A project has activity when `audit_card.shipped.count + audit_card.carry_over.count + audit_card.dropped.count > 0`.
   3. **Zero-activity footer** — one line, only if any project had no activity: `Zero-activity this cycle (<N>): <comma-separated project names in the order they appear in state.projects[]>`. Project names are preserved so the planner can still spot idle-project signals; full audit cards remain in `audit.json`.
   4. **Audit gaps** subsection — only if any subagent failed: list each failed project + the suggested retry command (`/cadence:weekly --resume-phase 1 --project <name>`).
   5. **Quality flags** subsection — only if any flagged: one line per flag — `<issue_id> — <check>: <message>`.

   **Scale target.** The rendering holds `≤300 words` when `≤20 projects have activity`. Each additional active project adds `~15 words` (per-bullet cost) and each additional zero-activity project adds `~1 word` (name in the footer). At 26+ projects where `~18` are active, the render lands near `~270 words`. Observed regression point: ~40+ active projects may push the render toward `~600 words` — if that threshold approaches in a future dogfood, file a follow-up for Option C paginated synthesis.

   Do not batch projects with activity into drift categories (e.g. "3 projects improved") — `memory/feedback_thorough_audits.md` prohibits semantic batching. The zero-activity footer is a factual rollup of projects with no data, not a drift category.
   ```

4. Confirm the block now contains **5 numbered rendering steps** (was 4 — the zero-activity footer is the new step 3, old steps 3 and 4 shift to 4 and 5).

5. No other section touches § 1.6; no imports/references to update in this file.

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exit 0, no new warnings/errors attributable to the § 1.6 edit

**Verify**:
- `grep -n '### 1.6 User-facing synthesis' plugins/cadence/commands/weekly.md` returns exactly one hit without `(≤300 words)` on the same line
- `grep -c 'Zero-activity this cycle' plugins/cadence/commands/weekly.md` returns `1`
- `grep -c 'per-project drift bullets' plugins/cadence/commands/weekly.md` returns `1` (preserves cross-section ref count)

---

### Task 2: Add scale-assumption gotcha to `plugins/cadence/CLAUDE.md § Gotchas`

**Files**: `plugins/cadence/CLAUDE.md`

**Why**: BC-5869 AC #4 requires a one-line gotcha note so future skill edits don't regress the scale-aware rendering rule.

**Implementation**:

1. Open `plugins/cadence/CLAUDE.md`.

2. Locate the final bullet of `## Gotchas` (the bullet starting `**Gate-respect contract.**` ending with `extend \`FORBIDDEN_PHRASE_PATTERNS\` in the linter.`).

3. Append one new bullet after it (keep the leading `- ` to match the existing list style):

   ```markdown
   - **Phase 1 synthesis is scale-aware, not word-capped.** `commands/weekly.md § 1.6` renders one bullet per *active* project (`shipped + carry_over + dropped > 0`) plus a single `Zero-activity this cycle (N): <names>` footer. BC-5759 AC #6's `≤300 words` target holds when `≤20 projects have activity`; the rule fails gracefully as the roster grows (each new active project adds ~15 words, each new zero-activity adds ~1 word). If an ~40+-active-project cycle pushes the render over ~600 words in a future dogfood, file a follow-up for Option C paginated synthesis. Origin: BC-5869 (W17 dogfood surfaced 26-project / ~370-word render against the original 18-project assumption).
   ```

4. Confirm the `## Gotchas` section now ends with this new bullet; no other gotcha is modified.

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exit 0; `plugins/cadence/CLAUDE.md` passes lint; no size warnings (the file was 53 lines; one bullet adds ~5 lines and stays well below any cap)

**Verify**:
- `grep -c 'Phase 1 synthesis is scale-aware' plugins/cadence/CLAUDE.md` returns `1`
- `grep -c 'BC-5869' plugins/cadence/CLAUDE.md` returns `1` (the attribution in the new bullet)
- `wc -l plugins/cadence/CLAUDE.md` returns a line count within `[55, 60]` — confirms the addition landed without duplicating other gotchas

---

### Task 3: Update BC-5759 AC #6 in Linear to the scale-aware wording

**Files**: none (Linear mutation via `mcp__plugin_workflows_linear-server__save_issue`)

**Why**: BC-5869 AC #3 requires BC-5759 AC #6 to be updated to match the new rule (or the implementation to match AC #6 as written). The implementation diverged, so AC #6 must be updated.

**Implementation**:

1. Read BC-5759 current description with `mcp__plugin_workflows_linear-server__get_issue` `id: "BC-5759"`. Capture the full description markdown.

2. Locate the AC #6 line inside `## Acceptance Criteria`:
   ```
   - [ ] User-facing synthesis at the gate is ≤300 words (word count pasted in Verify).
   ```

3. Replace it with:
   ```
   - [ ] User-facing synthesis at the gate holds ≤300 words when ≤20 projects have activity. Rendering shape: one bullet per project with activity (`shipped + carry_over + dropped > 0`); zero-activity projects collapse into a single `Zero-activity this cycle (N): <names>` footer. Word count pasted in Verify along with active-project count. Rule documented in `plugins/cadence/commands/weekly.md § 1.6`. (Amended 2026-04-24 by BC-5869 after W17 dogfood hit 26 projects / ~370 words against the original 18-project assumption.)
   ```

4. Call `mcp__plugin_workflows_linear-server__save_issue` with `id: "BC-5759"` and the full description containing the new AC #6 line. **Do not** change any other AC, the title, or any other field.

5. Immediately re-read with `get_issue` `id: "BC-5759"` and confirm AC #6 matches the new wording byte-for-byte. Linear Prosemirror sometimes mangles list formatting (per `memory/gotcha_linear_markdown_mangling.md`) — this AC is a single checkbox line in paragraph form, which is the safe shape per that gotcha; no list markup inside the text itself.

**Test**:
- Run: `./scripts/validate.sh` (baseline — not affected by this task, but confirms no drift)
- Expected: exit 0

**Verify**:
- `get_issue` result for BC-5759 shows the new AC #6 text with the `(Amended 2026-04-24 by BC-5869...)` attribution
- AC #1–#5 and AC #7 are unchanged (diff the before/after description against the captured baseline from step 1)
- Linear UI (manual check, optional) shows BC-5759 still in Done status, only description changed

---

### Task 4: Verify synthesis render against W17 seeded audit.json

**Files**: none (verification only)

**Why**: BC-5869 AC #2 requires "the user-facing synthesis word count holds under the chosen rule across ~26 projects, verified by running the audit phase against seeded 26-project state and counting the rendered output." Running the full `/cadence:weekly` is out of scope for this issue — we verify by rendering the synthesis inline from the W17 audit.json seed.

**Implementation**:

1. Render the synthesis inline (Bash + python3) from the seeded W17 audit.json, following the new § 1.6 rule:

   ```bash
   AUDIT=/Users/holdenhalford/Projects/work/brite-nites/weekly-planning/w17-2026-04-20/audit.json
   python3 - "$AUDIT" <<'PY'
   import json, sys
   data = json.load(open(sys.argv[1]))
   cards = data.get("audit_cards", [])
   stats = data.get("cross_project_stats", {})

   lines = []
   # Headline
   cr = stats.get("completion_rate")
   st = stats.get("shipped_total")
   co = stats.get("carry_over_total")
   standouts = ", ".join(stats.get("team_standouts", []) or ["none"])
   pct = f"{cr*100:.0f}%" if isinstance(cr, (int, float)) else f"{cr}"
   lines.append(f"{pct} completion / {st} shipped / {co} carrying over / standouts: {standouts}")
   lines.append("")

   active, zero = [], []
   for c in cards:
       s = c.get("shipped", {}).get("count", 0)
       cv = c.get("carry_over", {}).get("count", 0)
       d = c.get("dropped", {}).get("count", 0)
       name = c.get("project_name") or c.get("project", "")
       if s + cv + d == 0:
           zero.append(name)
       else:
           top_co = None
           issues = c.get("carry_over", {}).get("issues", [])
           if issues:
               top_co = sorted(issues, key=lambda x: -(x.get("priority") or 0))[0].get("id")
           bullet = f"**{name}** — {s} shipped, {cv} carrying over, {d} dropped."
           if top_co:
               bullet += f" {top_co}"
           active.append(bullet)

   lines.extend(active)
   if zero:
       lines.append(f"Zero-activity this cycle ({len(zero)}): {', '.join(zero)}")

   rendered = "\n".join(lines)
   words = len(rendered.split())
   print(rendered)
   print()
   print(f"--- {len(active)} active / {len(zero)} zero-activity ---")
   print(f"--- word count: {words} ---")
   PY
   ```

2. Capture the output. Expected: active ≈ 19, zero ≈ 6, word count ≤ 300.

3. If word count > 300, pause and evaluate: does the design need revision (e.g., shorter bullets), or does the 20-active-project threshold need to be revised downward in § 1.6 and the gotcha?

4. Paste the rendered output + word count into the conversation as AC #2 evidence. This becomes the verification artifact shipped with the PR description.

**Test**:
- Run the Bash block above.
- Expected: `word count: <N>` where `N ≤ 300`; `--- <active_count> active / <zero_count> zero-activity ---` matches the pre-computed 19 / 6.

**Verify**:
- Word count is ≤ 300 for W17's 25-project / 19-active seed
- Active-count and zero-count in the output match 19 and 6
- The `Zero-activity this cycle (6): ...` line appears exactly once at the end of the rendered block (before any Audit gaps / Quality flags, which are absent in this seed)
- `./scripts/validate.sh` — exit 0 (final lint after all edits)

## Task Dependencies

- **T1 → T4**: T4 verifies the rule codified in T1. T1 must land before T4's render is meaningful.
- **T2 independent of T1/T3/T4**: CLAUDE.md gotcha is pure documentation, no runtime dependency.
- **T3 independent of T1/T2/T4**: Linear AC update is a remote mutation with no code dependency.
- **T1, T2, T3 can run in any order**; T4 must run last. **T1 + T2 in parallel + T3 in parallel** is fine; **T4 sequential after all three.**

## Verification Checklist

- [ ] `./scripts/validate.sh` — exit 0 (no new errors/warnings; baseline was 0 errors / 16 warnings per last session's memory)
- [ ] `grep -n 'Zero-activity this cycle' plugins/cadence/commands/weekly.md` — exactly 1 match in § 1.6
- [ ] `grep -c 'Phase 1 synthesis is scale-aware' plugins/cadence/CLAUDE.md` — returns 1
- [ ] `get_issue` BC-5759 — AC #6 matches the new wording byte-for-byte; other ACs unchanged
- [ ] Inline render of W17 audit.json yields ≤300 words; 19 active / 6 zero-activity
- [ ] BC-5869 ACs (1–4) all have documented evidence pasted in the conversation before marking complete
