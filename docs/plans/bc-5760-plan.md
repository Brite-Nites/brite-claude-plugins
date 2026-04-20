# BC-5760 Plan — Cadence Phase 2 Scope Skill

**Linear:** BC-5760 · **Milestone:** Cadence Plugin · **Branch:** `holden/bc-5760-cadence-phase-2-scope`

## Deliverables

1. `plugins/cadence/skills/sprint-scoping/SKILL.md` — new skill, ~250 lines
2. `plugins/cadence/commands/weekly.md` — replace § Phase 2 stub with pointer into the skill
3. Version bump: `plugins/cadence/.claude-plugin/plugin.json` 0.2.0 → 0.3.0 + `.claude-plugin/marketplace.json` cadence entry

## Resolved departures

1. **audit_card gap for § 2.3 skip rules** — enrich carry-over issues inline via parallel `get_issue` on entering each project (to populate `blocker_count` + `auto_superseded_by`). Bounded cost since carry-over count is small per project.
2. **Checkpoint shape** — match W16 freeform voice. Minimum header bar per block (Project name + Owner + Headline outcome); everything else freeform per scope-Q answers. AC row will be re-worded in the PR to reflect ground truth.
3. **Prior-narrative parser** — deferred to a sibling follow-up issue in the Cadence milestone (will be filed on PR open). Keeps BC-5760 atomic.
4. **brainstorming invocation** — via the `Skill` tool (not Agent dispatch). Explicit match for AC "invoked per active project verified by counting tool calls".
5. **Checkpoint file path** — resolve as `$(git rev-parse --show-toplevel)/../weekly-planning/w<NN>-<date>/w<NN>-planning-checkpoint.md`. Mirrors Phase 1's `audit.json` resolution.

## Skill structure (9 sections)

### § 0 Frontmatter
- `name: sprint-scoping`
- `description:` triggers on `"sprint planning"`, `"weekly scope"`, `"what ships this week"`, `"/cadence:weekly phase 2"`
- `allowed-tools: mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, AskUserQuestion, Read, Write, Edit, Bash, Skill`
- Model inherits (Phase 2 is inline interactive Q&A — cannot run as dispatched subagent per issue body Notes)

### § 1 Inputs
State object fields the skill reads:
- `state.team.id`
- `state.cycle.current` (the cycle being *planned*)
- `state.cycle.previous` (the cycle being *audited*)
- `state.projects[].audit_card` (from Phase 1)
- `state.cross_project_stats`
- Optional: `state.leadership_planning_notes` (freeform file if the user pre-loaded it)

Populates / mutates:
- `state.projects[i].scope_decisions = {q1_headline, q2_ship_ids, q3_reassignments, q4_dependencies, q5_parked, carry_over_answers}`
- `state.projects[i].overrides = [{issue_id, check, reason}]`
- `state.bottleneck_warnings = [{assignee, count, issues}]` (populated after the loop)

### § 2 Per-project loop entry
For each `state.projects[i]` where the project was included in Phase 0.3's selection:
1. Resume check — if the current-week checkpoint file already has a block for this project (matched by `### N. <project_name>` header), skip to project[i+1].
2. Enrich carry-over — parallel `get_issue` for every ID in `audit_card.carry_over.issues[].id` to pull `relations` (for blockers + auto_superseded_by) and `description`. Store enrichment under `audit_card.carry_over.issues[].enriched`.
3. Run § 3 (carry-over interview) if `carry_over.count > 0`.
4. Run § 4 (scope interview).
5. Run § 5 (quality gate on scope-in candidates).
6. Run § 6 (append project block to checkpoint).

### § 3 Carry-over interview
Per carry-over issue, ask 5 Qs from BC-5810 § 2.1 verbatim, each a separate `AskUserQuestion` tool call. Skip rules from § 2.3 applied before each call. Each question carries:
- Issue ID + title
- One-line audit summary snippet
- Default option marked `(Recommended)` first
- "Other" free-text escape

Question Q-IDs map to BC-5810:
- CQ1 — Move to next cycle?
- CQ2 — Assignee still correct?
- CQ3 — Superseded by chain? (prefilled if `auto_superseded_by` is set)
- CQ4 — Blockers still live? (skipped if `blocker_count == 0`)
- CQ5 — Target cycle/milestone?

Every skip logs a one-liner to `state.projects[i].skip_log`.

### § 4 Scope interview
Once per project (after carry-over if run). Before SQ2, invoke `workflows:brainstorming` via the `Skill` tool with a project-scoped prompt: *"Propose next-cycle scope for project `<name>` given carry-over `<count>` + backlog `<count>` + High-or-Urgent priority. Surface alternatives and `what-if-we-parked-X` prompts."* Output feeds SQ2's candidate list.

5 Qs from BC-5810 § 2.2 verbatim, each a separate `AskUserQuestion` call:
- SQ1 — Headline outcome sentence?
- SQ2 — Which issue IDs ship this cycle? (candidates filtered through the quality gate)
- SQ3 — Owner per issue if different?
- SQ4 — Dependencies between picked issues?
- SQ5 — Explicitly parked this cycle?

If `project.status == "parked"`, only SQ1 is asked (for acknowledgement).

### § 5 Quality gate + block-with-override
For each SQ2 scope-in ID, invoke the shared `issue-quality-gate` skill (reads the issue via `get_issue`, returns 7-tuple). On any `fail`:
1. Surface the failure — issue ID, check name, message
2. `AskUserQuestion` with 3 options:
   - **Fix now** — echo the Linear URL, wait for user to fix + confirm, re-run gate
   - **Override with reason** — free-text; stored under `state.projects[i].overrides`
   - **Drop from scope** — remove from `q2_ship_ids`, prompt for replacement

No global skip.

### § 6 Checkpoint append
Append a project block to `$(git rev-parse --show-toplevel)/../weekly-planning/w<NN>-<date>/w<NN>-planning-checkpoint.md` after § 5 passes. Block structure:

```markdown
### N. <Project Name>

**Owner:** <primary assignee or team>
**Headline:** <SQ1 answer>

<freeform body rendered from the scope-Q answers — carry-over summary, ship-this-week list with owners, dependencies, stretch items, parked items, risks. Match W16 voice.>
```

Minimum required headers: `### N. <name>`, `**Owner:**`, `**Headline:**`. Everything else freeform per W16 ground truth. File path is constructed via `git rev-parse`; fall back to `state.weekly_planning_root` if set.

### § 7 Cross-project bottleneck detection
After the project loop: scan `state.projects[].scope_decisions.q2_ship_ids` + `q3_reassignments`. Group by assignee; emit a warning if any owner has > N primary assignments (default N=4; configurable via `state.bottleneck_threshold`). Rendered at the end of the checkpoint file under a `## Cross-project flags` section.

### § 8 Idempotency + resume
- On re-invoke: read the current checkpoint file, parse `### N. <name>` headers, populate `state.projects[i].scope_confirmed = true` for each match, skip-ahead in § 2 loop.
- Atomic append per project — write the block only after § 5 completes; partial failure leaves state in a recoverable spot.

### § 9 References
- `docs/designs/cadence-orchestration.md` § 2 (interview) + § 3 (gate)
- `docs/designs/cadence-plugin.md` § 1 (voice spec)
- `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md` (primitive)
- `plugins/cadence/agents/project-audit.md` (audit_card producer)
- `memory/feedback_one_question_at_a_time.md` (hard rule enforcement)
- `memory/feedback_thorough_audits.md` (per-item rigor)
- `memory/gotcha_linear_markdown_mangling.md` (if the skill ever writes to Linear)

## Execution order

1. ✅ Worktree created + plan file saved (this file)
2. Write `plugins/cadence/skills/sprint-scoping/SKILL.md`
3. Edit `plugins/cadence/commands/weekly.md` § Phase 2 (replace stub with 2-line pointer to the skill)
4. Bump `plugins/cadence/.claude-plugin/plugin.json` version to `0.3.0`
5. Bump `.claude-plugin/marketplace.json` cadence entry to `0.3.0`
6. Run `./scripts/validate.sh` — confirm 0 errors
7. Run `./scripts/check-guardrails.sh` on the new skill — confirm no anti-slop
8. Checkpoint — present the skill to user for review before commit
9. Commit with message: `BC-5760: Cadence Phase 2 sprint-scoping skill`
10. Push + open PR → Linear In Review
11. File the deferred-narrative-parser sibling issue (Cadence milestone)

## Verification (per issue AC)

- [ ] Auto-invoke on 3+ phrases: `"sprint planning"`, `"weekly scope"`, `"what ships this week"` (description-field trigger test)
- [ ] Pre-draft references all 5 inputs: audit card, Linear Todo/In-Progress, prior carry-overs, leadership notes if present, BC-5810 question set
- [ ] `workflows:brainstorming` invoked once per active project (count tool calls in session log)
- [ ] Quality gate runs on every scope-in; all 7 failure modes surface correctly (seed test: synthesize one failing-each-check issue)
- [ ] One project at a time: N separate `AskUserQuestion` calls per project × Q count (tool-call log diff)
- [ ] Checkpoint format: minimum header bar present per block, freeform body matches W16 voice (diff against W16 reference)
- [ ] Bottleneck detection: seed an owner with 5+ assignments, confirm warning
- [ ] Idempotent resume: kill mid-session, re-invoke, confirm skip-ahead logic
