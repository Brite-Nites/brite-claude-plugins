# Plan: BC-5902 — Cadence Phase 2/3 context-pressure architectural fix

**Issue**: BC-5902 — Cadence Phase 2: architectural fix for context-pressure family (parent for BC-5896/5897/5898/5899)
**Branch**: `holden/bc-5902-cadence-phase-2-architectural-fix-for-context-pressure`
**Closes (in one PR)**: BC-5902 + BC-5896 + BC-5897 + BC-5898 + BC-5899 + **BC-5867** (absorbed — enricher owns brainstorming ranker)
**Tasks**: 8 (estimated ~3h implementation + 4–6 review iterations per BC-5761)

## Prerequisites
- Worktree created at `.claude/worktrees/bc-5902` on the branch above (Step 7 of session-start owns this).
- Design doc read: `docs/designs/bc-5902-cadence-context-pressure-fix.md`.
- **Precedent alignment**:
  - **BC-5760** (architecture) — canonical state schema lives in `plugins/cadence/commands/weekly.md § Session State Object`; update schema in Task 1 *before* any skill body changes, so the PR opens with a legible schema diff.
  - **BC-5761 / BC-5762** (pattern-choice) — budget 4–6 review iterations; iter-4 routinely re-introduces P1s from iter-3 fixes.
  - **BC-5798** (parallel-session plan-file-loss) — write ALL worktree-scoped artifacts to `${WORKTREE}/...`, not absolute paths into primary checkout. This plan file itself is written to primary checkout (reference material); subsequent mutable artifacts stay in the worktree.
- **CDR check**: Context7 quota exceeded — CDR check skipped, proceeding per plan rules.
- **Parallel-safety**: every file in this plan is project-scoped; no cross-repo edits. Other parallel sessions touching Cadence plugin files would conflict — verify Cadence-adjacent issues aren't simultaneously assigned before starting execution.

## Tasks

### Task 1: Update canonical state-object schema in `commands/weekly.md`
**Files**: `plugins/cadence/commands/weekly.md` (edits to `## Session State Object` section only)
**Why**: BC-5760 precedent — schema lives in one place, updated in lockstep with the phases that produce/consume it. Opens the PR with the schema diff so architecture-reviewer has a reading order.

**Implementation**:
1. Locate the `## Session State Object` section (around line ~140–185 per the existing file).
2. Under `state.projects[]` block, add a new field:
   ```
   "_enrichment": { /* Phase 2 project-enricher agent output — populated by sprint-scoping § 2 pre-loop */
     "backlog_candidates": [ { "id", "title", "priority", "assignee", "assigneeId", "cycleId", "stateName" } ],
     "carry_over_enriched": [ { "id", "blocker_count", "auto_superseded_by", "title", "priority", "assignee" } ],
     "brainstorming_ranked": [ { "id_or_title", "rationale", "rank" } ],
     "enriched_at": "<ISO-8601>",
     "dispatch_error": null | "<message>"
   }
   ```
3. Under the top-level state block (after `state.mutations[]`), add a new field:
   ```
   "_preflight_manifest": { /* Phase 3 housekeeping-preflight agent output — populated by linear-housekeeping § 4 */
     "[mutation_id]": { "gate_detail": [ { "check", "status", "message" } ], "fetched_at": "<ISO-8601>" },
     "dispatch_error": null | "<message>"
   }
   ```
4. Add a comment under the `state.projects[].audit_card` block noting `backlog_high_count` + `backlog_high_candidates[]` (populated by the sprint-scoping § 2 pre-loop in the old flow) are **removed** — the enricher now owns this data under `_enrichment.backlog_candidates[]`.
5. In the `_fetched_issues` comment, tighten wording: "Phase 2 carry-over + gate fetch cache — populated on-demand by Phase 3 § 3 pre-flight when not already present; enricher writes `_enrichment.carry_over_enriched[]` instead of this cache during Phase 2."

**Test**:
- Run: `./scripts/validate.sh`
- Expected: PASS on `commands/weekly.md` (no frontmatter errors); baseline warning count unchanged.

**Verify**: grep `_enrichment` in `plugins/cadence/commands/weekly.md` returns ≥1 match; grep `_preflight_manifest` returns ≥1 match; grep `backlog_high_count` returns 0 matches (removed).

---

### Task 2: Create `project-enricher` agent
**Files**: `plugins/cadence/agents/project-enricher.md` (new file)
**Why**: Phase 2 per-project fan-out absorbs backlog fetch + carry-over enrichment + brainstorming ranking into a Sonnet subagent with compact output. Closes BC-5896 (backlog fetch reliability) and BC-5867 (brainstorming ranker invocation).
**Parallelizable with**: Task 3.

**Implementation**:
1. Frontmatter (exact shape, per BC-5793/project-audit precedent):
   ```yaml
   ---
   name: project-enricher
   description: Phase 2 of /cadence:weekly per-project enrichment — backlog fetch (High/Urgent), carry-over relations, brainstorming-ranked SQ2 candidates. Dispatched per project by sprint-scoping § 2 pre-loop. Read-only.
   model: sonnet
   tools: mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, Read
   ---
   ```
2. Body section `## Inputs (from dispatcher prompt)`: list `project_id`, `project_name`, `audit_card` (JSON snapshot of Phase 1 output for this project), `cycle.current` (object with id + name + startsAt), `cycle.previous` (object with id + title), `team_id`, `cross_project_stats` (optional — used for ranker context).
3. Body section `## Steps`:
   - Step 1: `list_issues` with `project: project_id`, `team: team_id`, `cycle: null`, `state: "backlog"`, and priority filter ≤2 (Urgent+High). Cap 50. Store as `backlog_candidates[]` — keep only the fields the SKILL SQ2 Option 1 default needs: `id, title, priority, assignee, assigneeId, cycleId, stateName`.
   - Step 2: For every ID in `audit_card.carry_over.issues[]`, call `get_issue` in parallel (single message with all calls). For each returned issue, derive `blocker_count = relations.blockedBy.length` and `auto_superseded_by = relations.duplicateOf[0].id || null`. Store as `carry_over_enriched[]`.
   - Step 3: Rank scope candidates. Build the ranking pool from `audit_card.carry_over.issues[]` (with enriched blocker/super info) + `backlog_candidates[]`. Output: 2–3 alternative scope shapes with one-line rationale each, ordered by composite of priority + carry-over-continuity + owner-load-hint from `cross_project_stats`. Rank format `{id_or_title, rationale, rank}` where `rank` is 1..N ascending.
   - Step 4: Freeze `enriched_at = <ISO-8601 now>`.
4. `## Output (return as a single JSON block — nothing else)`:
   ```json
   {
     "project_id": "<uuid>",
     "project_name": "<name>",
     "enriched_at": "<ISO-8601>",
     "backlog_candidates": [ {"id","title","priority","assignee","assigneeId","cycleId","stateName"} ],
     "carry_over_enriched": [ {"id","blocker_count","auto_superseded_by","title","priority","assignee"} ],
     "brainstorming_ranked": [ {"id_or_title","rationale","rank"} ]
   }
   ```
5. `## Failure handling`:
   - `list_issues` error → return `{"project_id","project_name","dispatch_error":"list_issues failed: <msg>"}`. Dispatcher (main thread) treats any `dispatch_error` as a hard stop — surfaces `AskUserQuestion` Retry / Pause / Proceed-without-enrichment per BC-5896 AC.
   - Individual `get_issue` error → still emit the issue under `carry_over_enriched[]` with `blocker_count: null, auto_superseded_by: null` and prepend a one-line note in the ranker rationale.
   - Top-level MCP outage → return `{"dispatch_error":"<message>"}`.
6. `## Conventions`: Read-only — never `save_*` / `update_*` / `delete_*`. Namespace is `mcp__plugin_workflows_linear-server__*` (Cadence reuses workflows' Linear MCP). Keep output strictly the JSON block (no preamble, no explanation). Mirrors `project-audit.md` conventions verbatim.

**Test**:
- Run: `./scripts/validate.sh`
- Expected: PASS — new agent file discovered, frontmatter valid, tools list parseable, baseline warning count unchanged.

**Verify**: `plugins/cadence/agents/project-enricher.md` exists, frontmatter `model: sonnet` present, `## Output` section contains the 3-key JSON block, `list_issues` + `get_issue` both appear in `allowed-tools`-equivalent frontmatter.

---

### Task 3: Create `housekeeping-preflight` agent
**Files**: `plugins/cadence/agents/housekeeping-preflight.md` (new file)
**Why**: Phase 3 batch-once dispatch runs the 7-check issue-quality-gate per cycle-path mutation row, returning a compact manifest keyed by `mutation_id`. Closes BC-5898 (quality-gate preflight under context pressure).
**Parallelizable with**: Task 2.

**Implementation**:
1. Frontmatter:
   ```yaml
   ---
   name: housekeeping-preflight
   description: Phase 3 of /cadence:weekly — runs issue-quality-gate (7 checks) per cycle-path mutation row, returns compact {mutation_id → gate_detail[7]} manifest. Dispatched once per invocation by linear-housekeeping § 4. Read-only.
   model: sonnet
   tools: mcp__plugin_workflows_linear-server__get_issue, Read
   ---
   ```
2. `## Inputs (from dispatcher prompt)`: `cycle.current` (object), `team_id`, `mutation_rows` (array of `{mutation_id, issue_id}` for every row where `decision_path == "cycle"`; non-cycle rows are filtered out before dispatch). Optional: `overrides` (array `[{issue_id, check, reason}]`) so the agent can flag override-matches in the output.
3. `## Steps`:
   - Step 1: Parallel `get_issue` for every unique `issue_id` in `mutation_rows`. Single tool-call message. De-duplicate by `issue_id` before dispatch so multiple rows sharing an issue cost one fetch.
   - Step 2: For each mutation row, apply the 7 gate checks from `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md`. The agent does NOT import/re-declare the check rules — it reads the shared skill file via `Read` and applies the checks inline. Return one 7-tuple per row.
   - Step 3: Cross-match failures against `overrides`. Any `(issue_id, check)` tuple present in overrides becomes `status: "override"` in the output (not `"fail"`), with `matched_reason` echoed.
4. `## Output (return as a single JSON block — nothing else)`:
   ```json
   {
     "preflight_at": "<ISO-8601>",
     "manifest": {
       "<mutation_id>": {
         "issue_id": "<id>",
         "gate_detail": [
           {"check": "assignee_present", "status": "pass|fail|override", "message": "<>", "matched_reason": null | "<override reason>"}
         ]
       }
     }
   }
   ```
5. `## Failure handling`:
   - Any `get_issue` error → emit that row's manifest entry with `gate_detail: []` and a top-level `row_errors: [{mutation_id, issue_id, error}]` list. Dispatcher treats non-empty `row_errors` as "some rows unchecked" and surfaces `AskUserQuestion` per BC-5898 AC.
   - Top-level MCP outage → return `{"dispatch_error":"<message>"}`.
6. `## Conventions`: Read-only, inherits `project-audit` conventions (namespace, no mutations, JSON-only response).

**Test**:
- Run: `./scripts/validate.sh`
- Expected: PASS — agent frontmatter + tool list valid, baseline warning count unchanged.

**Verify**: `plugins/cadence/agents/housekeeping-preflight.md` exists, frontmatter `model: sonnet` present, `## Output` includes `manifest` keyed by `mutation_id`.

---

### Task 4: Refactor `sprint-scoping/SKILL.md` to dispatch enricher + iterate carry-over per issue
**Files**: `plugins/cadence/skills/sprint-scoping/SKILL.md` (edit)
**Why**: Collapse inline `list_issues` + `workflows:brainstorming` Skill call into one `project-enricher` dispatch per project. Tighten CQ loop to iterate every carry-over. Add unconditional § 7 emit. Add fail-loud dispatch error handling. Closes BC-5896 + BC-5897 + BC-5899 + BC-5867.
**Depends on**: Task 1 (schema), Task 2 (agent exists).

**Implementation**:
1. `## § 1 Inputs (state object)` — update **Populates / mutates** list: add `state.projects[i]._enrichment` (produced per-project by the enricher); remove the `audit_card.backlog_high_count` / `backlog_high_candidates[]` bullet (now inside `_enrichment.backlog_candidates[]`).
2. `## § 2 Per-project loop entry` → **Pre-loop** section — replace the current "Backlog enrichment" paragraph with:
   > **Enricher dispatch fan-out.** In a single `Agent` tool-call message, dispatch `project-enricher` once per project in `state.projects[]` with `status.type == "started"`. Cap 10 concurrent dispatches (mirrors Phase 1 § 1.4 per `weekly.md`). Prompt body per dispatch: `project_id`, `project_name`, `audit_card` (full Phase 1 output for this project), `cycle.current`, `cycle.previous`, `team_id`, `cross_project_stats`. Parse each returned JSON block into `state.projects[i]._enrichment`. On any `_enrichment.dispatch_error`, halt the pre-loop and surface an `AskUserQuestion` with three options: **Retry** (re-dispatch just the failed projects), **Pause session** (write breadcrumb, exit), **Proceed without enrichment for failed projects** (mark `_enrichment.backlog_candidates = []` + free-text-prompt user for SQ2 IDs when that project's turn comes — explicit user opt-in, NEVER silent).
3. `## § 2 ... For each state.projects[i] ...` step 2 "Enrich carry-over" — replace the inline parallel `get_issue` block with: "Read `state.projects[i]._enrichment.carry_over_enriched[]` populated by the Pre-loop enricher dispatch. Derive `audit_card.carry_over.issues[i].enriched.blocker_count` and `.enriched.auto_superseded_by` from those entries. No additional MCP reads in Phase 2."
4. `## § 3 Carry-over interview` first paragraph — **tighten the loop wording explicitly per BC-5897**: "For **every** issue in `state.projects[i].audit_card.carry_over.issues[]` (not just the highest-priority one), run the CQ1–CQ5 block. Iteration order is `carry_over.issues[]` array order (Phase 1 audit sorts by priority already). No priority-filter / rank-filter on block entry — only question-level adaptive-skip from § 2.3 applies."
5. `## § 4 Scope interview` → **Brainstorming invocation** paragraph — replace the `Skill` tool invocation with: "Read the pre-dispatched `state.projects[i]._enrichment.brainstorming_ranked[]` populated by the enricher. The top-ranked candidate becomes SQ2's `(Recommended)` default; alternatives 2–3 become options 2–3 per `AskUserQuestion`. No `workflows:brainstorming` Skill call — the enricher already ran that logic with the same inputs. **(Closes BC-5867: brainstorming ranker moves from spec-misfit inline Skill call to dispatched subagent output consumed as data.)**"
6. `## § 7 Cross-project bottleneck detection` — prepend a new first paragraph: "Emit the § 7 summary **unconditionally** at Phase 2 exit — even when `bottleneck_warnings == []`. The checkpoint always includes a `## Cross-project flags` section; the empty case renders `_None this cycle._`. This satisfies BC-5899 AC #7 regardless of whether any owner exceeds the threshold."
7. `## § 9 References` — add `plugins/cadence/agents/project-enricher.md` (BC-5902) and remove `plugins/workflows/skills/brainstorming/SKILL.md` (no longer invoked from this skill).
8. Update frontmatter `allowed-tools` — remove `Skill` if the only use was `workflows:brainstorming`. **Verify** before removing: grep the skill body for `Skill` tool invocations; if any remain (e.g., `cadence:issue-quality-gate` in § 5), keep `Skill` in the list.
9. `## Deferred to follow-up issues` — add a bullet: "Seeded synthetic-25-project fixture test — deferred; BC-5874 third dogfood is the end-to-end verification."

**Test**:
- Run: `./scripts/validate.sh` — SKILL.md frontmatter parses, `allowed-tools` entries match existing MCP registration.
- Run: `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — anti-slop guardrails (size, vagueness) pass.
- Expected: PASS on both; baseline warning count unchanged (±0).

**Verify**:
- grep `project-enricher` in SKILL.md → ≥3 matches (pre-loop paragraph, § 3 reference, § 9 references).
- grep `workflows:brainstorming` in SKILL.md → 0 matches (all invocations removed).
- grep `every issue in state.projects\[i\].audit_card.carry_over` in SKILL.md → 1 match (BC-5897 loop fix wording).
- grep `unconditionally` in SKILL.md § 7 → 1 match (BC-5899 unconditional emit).

---

### Task 5: Refactor `linear-housekeeping/SKILL.md` to dispatch preflight-agent
**Files**: `plugins/cadence/skills/linear-housekeeping/SKILL.md` (edit)
**Why**: Replace § 4 inline per-mutation-row `Skill → cadence:issue-quality-gate` invocations with one `housekeeping-preflight` dispatch that returns a compact manifest. Adds fail-loud dispatch error handling. Closes BC-5898.
**Depends on**: Task 1 (schema), Task 3 (agent exists).

**Implementation**:
1. `## § 1 Inputs` — **Populates / mutates** list: add `state._preflight_manifest` (produced by Phase 3 § 4 via housekeeping-preflight dispatch).
2. `## § 4 Quality gate re-run for cycle-path mutations` — replace the step-list with:
   > **Batch dispatch.** After § 2 derivation produces `state.mutations[]`, collect every row where `decision_path == "cycle"` into `preflight_input = [{mutation_id: m.id, issue_id: m.target.id} for m in state.mutations if m.decision_path == "cycle"]`. Collect `state.projects[].overrides[]` into a flat list. Dispatch `housekeeping-preflight` once via the `Agent` tool with `{cycle.current, team_id, mutation_rows: preflight_input, overrides: flat_overrides}`. Parse the returned JSON into `state._preflight_manifest`.
   >
   > **Dispatch error handling (fail-loud per BC-5898 AC).** On `_preflight_manifest.dispatch_error` non-null, halt before § 5 and surface `AskUserQuestion`: **Retry**, **Pause session** (breadcrumb + exit), **Execute without preflight (NOT RECOMMENDED — explicit spec-departure override, captured as a `state.phase_3_spec_departure = "preflight-skipped-user-override"` flag rendered in the housekeeping log summary + § 7.5 and surfaced in Phase 4 narrative Known gaps callout)**. No silent "context-pressure-skipped" path anywhere.
   >
   > **Row-level error handling.** On `_preflight_manifest.row_errors[]` non-empty, surface each errored row as a `## Preflight errors (resolve before execute)` section at the top of the § 5 preview and consume a `Preflight errors` group approval in § 6 (pre-groups ordering becomes: 0 CQ3 parse → 1 Conflicts → 2 Preflight errors → 3 Gate failures → 4 regular decision-path groups).
   >
   > **Manifest consumption.** For each cycle-path mutation row, look up `state._preflight_manifest.manifest[row.id]` and set `row.gate_detail = manifest_entry.gate_detail` + derive `row.gate_status` from the tuple: all pass → `"pass"`, any `status == "override"` and no `"fail"` → `"override"` (copy `matched_reason` into `row.override_reason`), any `"fail"` → `"fail"` (row moves to `## Gate failures` preview section). Non-cycle-path rows keep `gate_status = "n/a", gate_detail = []` unchanged.
3. `## § 5 Preview rendering` — add a new subsection between `## Conflicts (resolve before execute)` and `## Gate failures (resolve before execute)`:
   ```markdown
   ## Preflight errors (resolve before execute)

   _Rendered only if `state._preflight_manifest.row_errors[]` is non-empty. Each row shows the mutation_id + issue_id + fetch error. Resolved THIRD in § 6.2 before regular decision-path groups._

   | Mutation | Issue | Error |
   |---|---|---|
   | <id> | BC-XXXX | <fetch error message> |
   ```
4. `## § 6 Per-group approval` — renumber pre-groups: 0 CQ3 parse (existing) → 1 Conflicts (existing) → **2 Preflight errors (new)** → 3 Gate failures (was 2) → 4 regular decision-path groups (was 3). Update the literal numbers in section headers and the "AC #3 regular-group count" paragraph to clarify that pre-groups 0/1/2 are per-row by necessity. For the new pre-group 2, per-row `AskUserQuestion` with three options: **Retry fetch** (re-dispatch just the single row via `get_issue` + re-run the 7 checks inline — belt-and-suspenders fallback), **Override all 7 checks for this row with reason**, **Drop from scope**.
5. `## § 9 References` — add `plugins/cadence/agents/housekeeping-preflight.md` (BC-5902).

**Test**:
- Run: `./scripts/validate.sh`
- Run: `./scripts/check-guardrails.sh --claude-md CLAUDE.md`
- Expected: PASS on both; baseline warning count unchanged.

**Verify**:
- grep `housekeeping-preflight` in SKILL.md → ≥3 matches (§ 4 dispatch, § 5 preview subsection, § 9 references).
- grep `_preflight_manifest` → ≥4 matches (§ 1, § 4, § 5, § 6).
- grep `Preflight errors` in § 5 + § 6 → matches in both sections.
- grep `Skill.*cadence:issue-quality-gate` → remains 0 or reduced by 1 (depending on § 4 vs § 6 Fix-now flow; § 6 Fix-now may still invoke the skill inline on user-Retry).

---

### Task 6: Update `docs/designs/cadence-orchestration.md` with § 2.5 hybrid dispatch subsection
**Files**: `docs/designs/cadence-orchestration.md` (edit)
**Why**: BC-5810's locked design doc must reflect the new pattern. Adds a new § 2.5 subsection explaining the hybrid-dispatch rationale, updates § 1.1 reason (b) footnote, extends § 4 cross-phase-summary table.
**Depends on**: Tasks 1, 2, 3, 4, 5 (all spec changes landed).

**Implementation**:
1. After existing `## 2.5 Pull-quote` subsection, renumber existing § 2.5 → § 2.6 and insert new:
   ```markdown
   ### 2.5 Hybrid dispatch for heavy reads (BC-5902)

   Phase 2's interactive interview and Phase 3's per-mutation gate re-run must run inline in main thread because `AskUserQuestion` cannot fire from dispatched subagents. At 25 projects, accumulated context (audit cards + backlog fetches + per-project scope state + brainstorming outputs + per-mutation gate reads) exceeds main-thread budget and the skills silently drop spec-required steps.

   The fix: **two Sonnet agents absorb every heavy read.** Each Phase 2 project dispatches `project-enricher` (cap-10 parallel, mirrors Phase 1 `project-audit` fan-out) which returns a compact card (~1–2KB) containing backlog candidates + enriched carry-over relations + brainstorming-ranked scope candidates. Phase 3 dispatches `housekeeping-preflight` once with the cycle-path mutation slice and receives a `{mutation_id → gate_detail[7]}` manifest (~300B × ~100 rows).

   Main-thread context after Phase 1 reads only compact agent outputs — never raw Linear results. Empirically keeps the main-thread Messages category ≤150K across 25 projects (BC-5902 AC evidence).

   Failure posture is fail-loud: any dispatch error halts the phase and surfaces `AskUserQuestion` with Retry / Pause / explicit user-override-to-proceed options. No silent degradation path exists — a spec departure is always opt-in and logged as such.

   See `plugins/cadence/agents/project-enricher.md`, `plugins/cadence/agents/housekeeping-preflight.md`, and the Phase 2/3 SKILL files for the concrete interface.
   ```
2. In `## 1.1 Three reasons this shape wins` reason (b) paragraph, append one sentence: "The per-project interactive loop additionally dispatches a read-only enricher subagent per project (see § 2.5) to keep main-thread context lean across 25+ projects."
3. In `## 4 Cross-phase summary` table, add a new row:
   ```
   | Hybrid dispatch (BC-5902) | — | project-audit (existing) | project-enricher per project | housekeeping-preflight once | — |
   ```

**Test**:
- Run: `./scripts/validate.sh`
- Expected: PASS; design doc isn't validated for content but must not break the marketplace JSON.

**Verify**:
- grep `2.5 Hybrid dispatch` in `cadence-orchestration.md` → 1 match.
- grep `BC-5902` in `cadence-orchestration.md` → ≥3 matches.
- Old § 2.5 Pull-quote remains intact, renumbered as § 2.6.

---

### Task 7: Wire dispatch steps into `commands/weekly.md` Phase 2 and Phase 3 sections
**Files**: `plugins/cadence/commands/weekly.md` (edit; Phase 2 + Phase 3 orchestration sections only — does not touch § Session State Object from Task 1)
**Why**: Command file is the runtime orchestrator; document the dispatch step, cap-10 concurrency, and failure handling so the command's control flow matches the SKILL bodies.
**Depends on**: Tasks 4, 5.

**Implementation**:
1. Locate `## Phase 2: Scope` section. Prepend a new paragraph before the "Phase 2 is idempotent" line:
   > **Pre-loop enricher dispatch.** Before entering the per-project scope loop, the command dispatches `project-enricher` in a single `Agent` tool-call message covering every active project (cap 10 concurrent, batched sequentially if project count > 10). Parsed outputs populate `state.projects[i]._enrichment` before any SQ/CQ question runs. On any `_enrichment.dispatch_error`, the command surfaces `AskUserQuestion` (Retry / Pause / Proceed-without-enrichment) per BC-5896 AC before falling into the skill.
2. In the same Phase 2 section, find the paragraph describing the sprint-scoping skill invocation. Append: "The skill reads `_enrichment` as pre-dispatched input and never calls `list_issues` / `workflows:brainstorming` inline (BC-5902 hybrid-dispatch pattern — see `docs/designs/cadence-orchestration.md` § 2.5)."
3. Locate `## Phase 3: Housekeeping` section. Prepend a new paragraph before the existing "Inline (not subagent) — interactive approval gates..." paragraph:
   > **Pre-preview preflight dispatch.** After `linear-housekeeping` derives `state.mutations[]` in § 2, the command dispatches `housekeeping-preflight` once with the cycle-path slice. Parsed `state._preflight_manifest` feeds § 4's gate-status derivation before any preview rendering or approval prompt. On `dispatch_error`, `AskUserQuestion` halts before § 5 per BC-5898 AC.
4. Do NOT edit `## Session State Object` section — Task 1 owns that.

**Test**:
- Run: `./scripts/validate.sh`
- Expected: PASS; baseline warning count unchanged.

**Verify**:
- grep `Pre-loop enricher dispatch` in `commands/weekly.md` → 1 match.
- grep `Pre-preview preflight dispatch` → 1 match.
- grep `BC-5902` → ≥2 matches.
- grep `_enrichment` and `_preflight_manifest` → both ≥1 match (Task 1 added them to schema; Task 7 references them in orchestration).

---

### Task 8: Write `docs/precedents/BC-5902.md` + INDEX.md entry
**Files**: `docs/precedents/BC-5902.md` (new), `docs/precedents/INDEX.md` (edit — append one row).
**Why**: Flywheel compound-learnings: architectural pattern for "subagent-dispatched heavy reads feeding interactive per-item loops over N items" is reusable for any future Cadence-style plugin (retrospective, quarterly cadence, annual planning).
**Depends on**: Tasks 1–7 (trace the as-implemented state, not the planned state).

**Implementation**:
1. `docs/precedents/BC-5902.md` template — mirror BC-5760 + BC-5761 shape:
   ```markdown
   # BC-5902: Hybrid subagent dispatch for heavy reads feeding interactive per-item loops

   **Date:** 2026-04-21
   **Category:** architecture
   **Confidence:** [8 or 9 / 10 — fill in post-implementation]

   ## Decision

   [1 paragraph: when a plugin runs an interactive per-item loop over N items in main thread (AskUserQuestion constraint), offload every heavy read (Linear fetches, ranking, gate checks) to dispatched subagents that return compact JSON. Main thread consumes pre-dispatched outputs as data, never reads raw results directly after the initial batch. Fail-loud on dispatch error — never silent degradation.]

   ## Context

   [Paragraphs: BC-5763 W17 dogfood attempt 2 surfaced 4 P1s in the context-pressure family. Root cause analysis from the issue body. Options A/B/C. Chosen: Option A with per-project fan-out + full-bundle enricher.]

   ## Alternatives Considered

   [Numbered list: Option B per-project compact (rejected — lossy for § 7 cross-project tally). Option C external resume (rejected — breaks one-command intent). Bulk-once enricher (rejected — loses parallelism). Reuse project-enricher for Phase 3 (rejected — asymmetric interface). Post-Phase-2 state compact + inline (rejected — compact not lossless for Phase 3 gate).]

   ## Outcome

   [Final state: N commits on branch, SKILL refactors + 2 new agents + schema diff + orchestration doc update. PR URL. Review iteration count vs BC-5761 budget. Did iter-4 re-introduce P1s as predicted? Did BC-5867/5896/5897/5898/5899 all verify-close via BC-5874 third dogfood?]

   **Reusable beyond this case.** [Any Cadence-style plugin that orchestrates interactive per-item loops (retrospective, quarterly cadence, annual OKR planning) should adopt the hybrid-dispatch pattern — main thread keeps AskUserQuestion, subagents absorb heavy reads. Two-agent split (per-item fan-out + batch-once preflight) applies when the plugin has both a per-item interactive phase and a batch approval phase.]

   **Secondary learning — [N].** [Fill from implementation experience, e.g., Sonnet vs Haiku tier calibration, fail-loud vs silent-degradation posture, review-loop iteration count confirmation.]

   **Strengthens** BC-5760 (state-schema canonical single source) — same schema-first PR discipline applied here. **Strengthens** BC-5761 (4-5 iteration review loop budget) — confirms or refines on larger-surface PR.

   **Precedent Referenced:** BC-5760, BC-5761, BC-5762, BC-5798 (parallel-session plan-file-loss — this PR wrote plan to worktree path), BC-5867 (brainstorming ranker spec-misfit — absorbed by this architectural fix).

   ## Tags

   architecture, subagent-dispatch, context-pressure, interactive-loop, cadence
   ```
2. `docs/precedents/INDEX.md` — append one row (after the BC-5798 row currently at line 31):
   ```
   | [BC-5902](BC-5902.md) | Hybrid subagent dispatch for heavy reads feeding interactive per-item loops over N items | architecture | 2026-04-21 | architecture, subagent-dispatch, context-pressure, interactive-loop, cadence |
   ```

**Test**:
- Run: `./scripts/validate.sh`
- Expected: PASS; precedent files aren't structurally validated but must not break marketplace.json.

**Verify**:
- `docs/precedents/BC-5902.md` exists; has required sections (Decision, Context, Alternatives Considered, Outcome, Tags); `**Confidence:**` line present.
- `docs/precedents/INDEX.md` has exactly one new row for BC-5902.

---

## Task Dependencies
- **Task 1** (schema) → opens the PR; no prerequisites.
- **Tasks 2 & 3** (new agents) → independent of Task 1, parallelizable with each other.
- **Task 4** (sprint-scoping SKILL) → depends on Task 1 + Task 2.
- **Task 5** (linear-housekeeping SKILL) → depends on Task 1 + Task 3. Independent of Task 4, parallelizable.
- **Task 6** (design doc § 2.5) → depends on Tasks 1–5 for accurate wording.
- **Task 7** (command file Phase 2/3 wiring) → depends on Tasks 4 + 5; independent of Task 6.
- **Task 8** (precedent + INDEX) → last; depends on all prior tasks for trace accuracy.

Execution order: Task 1 → (Task 2 ‖ Task 3) → (Task 4 ‖ Task 5) → (Task 6 ‖ Task 7) → Task 8.

## Verification Checklist
- [ ] `./scripts/validate.sh` passes (exit 0, 0 errors; baseline warning count — currently 17 — unchanged ±0).
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` passes (exit 0).
- [ ] `grep -rn "workflows:brainstorming" plugins/cadence/` → 0 matches (BC-5867 absorbed).
- [ ] `grep -rn "_enrichment" plugins/cadence/` → matches in commands/weekly.md + sprint-scoping SKILL + project-enricher agent.
- [ ] `grep -rn "_preflight_manifest" plugins/cadence/` → matches in commands/weekly.md + linear-housekeeping SKILL + housekeeping-preflight agent.
- [ ] `grep -n "context pressure" plugins/cadence/skills/*/SKILL.md` → 0 matches claiming silent skip as spec-departure (all silent-skip language replaced with fail-loud AskUserQuestion flow).
- [ ] All 9 AC rows in the design doc's "Coverage of Acceptance Criteria" table mapped to a concrete file change.
- [ ] Parallel-review (code + architecture + security + performance + cdr-compliance) returns 0 P1 / 0 P2 at iter 5 or 6 (BC-5761 + BC-5762 iteration budget).
- [ ] `docs/precedents/BC-5902.md` exists and appears in `docs/precedents/INDEX.md`.

## Review iteration budget (BC-5761 / BC-5762 precedent)
Expect 4–6 fix-review loops. Budget per-iteration:
- Iter 1: initial bugs (schema drift, missing allowed-tools, dispatch-error wording)
- Iter 2: drift from iter-1 fixes (manifest field-name consistency across SKILL/agent/command)
- Iter 3: refinements (BC-5760 schema cross-reference, BC-5867 closure wording)
- Iter 4: drift from iter-3 fixes (watch for new P1s — BC-5761 precedent says expect this)
- Iter 5: convergence (≤1 P3)
- Iter 6: safety buffer — cap here and ship with residuals documented in PR body per BC-5761 precedent.
