---
name: linear-housekeeping
description: Phase 3 of /cadence:weekly. Derives Linear mutations from Phase 2 scope decisions, re-runs the issue-quality-gate on every cycle-path mutation, previews the batch grouped by decision path + mutation type, and executes atomically with per-group user approval, idempotent pre-flight checks, and an ISO-8601 timestamped audit log. Triggers on "sprint cleanup", "linear housekeeping", "move to cycle", "back to backlog", "batch mutations", "apply scope decisions", or "/cadence:weekly phase 3".
user-invocable: false
allowed-tools: mcp__plugin_workflows_linear-server__save_issue, mcp__plugin_workflows_linear-server__save_milestone, mcp__plugin_workflows_linear-server__save_comment, mcp__plugin_workflows_linear-server__get_issue, mcp__plugin_workflows_linear-server__get_milestone, mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__list_comments, mcp__plugin_workflows_linear-server__list_milestones, AskUserQuestion, Read, Write, Edit, Bash, Skill, Agent
---

# Phase 3 — Linear Housekeeping

Batch mutation preview and atomic execute. Consumes the state object populated by Phase 2 (`sprint-scoping`), derives a `mutations[]` list, re-runs the `issue-quality-gate` on every cycle-path mutation with block-with-override, renders the full preview grouped by decision path, collects per-group approval, then executes sequentially while timestamping every write in a housekeeping log for audit trail. No Linear mutations fire until the user approves the full preview (BC-5810 § 1.1c). No Phase 4 narrative work.

This skill is inline (model inherits). Interactive approval gates cannot run inside a dispatched subagent.

**Namespace note.** Cadence reuses `mcp__plugin_workflows_linear-server__*` — Cadence does not register its own Linear MCP (per `plugins/cadence/CLAUDE.md` § MCP Servers + BC-5810 § 4 + BC-5811 § 4.2). Duplicate registration breaks tool routing. The issue body's `mcp__plugin_cadence_linear-server__*` suggestion is stale.

## § 1 Inputs (state object)

Reads from the session state object populated by Phases 0–2:

- `state.team.id`, `state.team.name` — Brite Company, set in Phase 0
- `state.cycle.current` — the cycle being *planned* (W+1). Source of truth for every `cycle-assign` target.
- `state.projects[].id`, `.name` — resolved in Phase 0.3.
- `state.projects[].scope_decisions` — Phase 2 output. Fields consumed: `q2_ship_ids[]`, `q3_reassignments[]`, `q5_parked[]`, `carry_over_answers[]` (each keyed by `issue_id` with `cq1..cq5` outcomes).
- `state.projects[]._fetched_issues` — Phase 2 enriched issue cache (authoritative source for `before` snapshots; avoids duplicate reads).
- `state.projects[].overrides` — Phase 2 quality-gate overrides, shape `[{issue_id, check, reason}]`.
- `state.checkpoint_path` — Phase 2 cached path; the housekeeping log sits in the same folder.

Populates / mutates:

- `state.mutations[]` — the derived mutation list (schema per § 2).
- `state._preflight_manifest = { preflight_at, manifest: {[mutation_id]: {issue_id, gate_detail[7]}}, row_errors[], dispatch_error }` — produced by § 4 via the `housekeeping-preflight` agent (BC-5902). Canonical shape lives in `plugins/cadence/commands/weekly.md § Session State Object`; do not re-declare here.
- `state._mutation_conflicts[]` — cross-project conflicts detected during § 2.5 de-duplication (each entry carries both source projects + both target states). Surfaced in the § 5 preview under `## Conflicts (resolve before execute)` and resolved via a dedicated § 6.1 group approval before regular groups run.
- `state._cq3_parse_errors[]` — carry-over rows where CQ3's "superseded by" answer contained zero `^BC-\d+$` tokens. Each entry `{project_id, issue_id, raw_cq3_answer}`. Surfaced in the § 5 preview under `## CQ3 parse errors (resolve before execute)` and resolved via § 6.0 pre-preview re-parse (not through the quality-gate, which only handles the 7-check tuple on live issues).
- `state.housekeeping_log_path` — resolved once at § 7 entry.
- `state._executed_mutation_ids[]` — resume cache (populated on successful writes).
- `state._create_preflight_cache` — `{ [projectId]: list_issues-response }` memoization used by § 3's `create` pre-flight so multiple create rows in the same project share one fetch. Phase-3-scoped; reset on each invocation.
- `state.projects[i].overrides[]` — appended to when the user picks "Override with reason" during the § 6 `Gate failures` group prompt (the gate re-run in § 4 is read-only and stages failures under `gate_status="fail"`).

Writes no fields used by Phase 4 beyond what Phase 2 already populated (`overrides` + `scope_decisions`). Phase 4 narrative reads those directly.

## § 2 Decision-path + mutation-type derivation

### 2.1 Mutation object shape

Every row in `state.mutations[]` has:

```
{
  "id": "<decision_path>-<mutation_type>-<target.id or target.name slug>",  // stable for idempotency log
  "decision_path": "cycle" | "backlog" | "cancel" | "reassign" | "leave",
  "mutation_type": "cycle-assign" | "state-change" | "reassign" | "cancel" | "create" | "milestone-rename" | "label-change" | "backlog-return",
  "target": { "kind": "issue" | "milestone", "id": "<uuid or null-for-create>", "name": "<identifier or title>", "projectId": "<uuid or null-for-global>" },
  "before": { "cycleId", "cycleName", "stateType", "stateName", "assigneeId", "assigneeName", "title", "labelIds", "labelNames" },
  "after":  { "cycleId", "cycleName", "stateType", "stateName", "assigneeId", "assigneeName", "title", "labelIds", "labelNames", "duplicateOfId" },  // `duplicateOfId` only populated on cancel rows
  "gate_status": "pass" | "fail" | "override" | "n/a",
  "gate_detail": [ … ],       // 7-tuple from issue-quality-gate; empty if path != "cycle"
  "override_reason": "<string>" | null,
  "executed_at": "<ISO-8601>" | null,
  "result": "executed" | "skipped-idempotent" | "errored" | "dropped-by-user" | "pending-cq3-reparse" | null,
  "error": "<string>" | null,
  "source_project": "<project_name>"  // "(global)" for milestone renames
}
```

Both ID-form (`cycleId`, `stateType`, `assigneeId`, `labelIds`, `duplicateOfId`) and name-form (`cycleName`, `stateName`, `assigneeName`, `labelNames`) are populated at derivation time. § 3's pre-flight uses IDs for equality comparisons against the live issue; § 7.3's Linear MCP `save_issue` calls pass names (per `memory/MEMORY.md` — the write API takes `assignee`, `cycle`, `state`, `labels` name strings, not IDs).

### 2.2 Per-issue derivation (applied to every `state.projects[i].scope_decisions.carry_over_answers[]` entry)

For each carry-over answer tuple keyed by `issue_id`:

| Answer condition | Decision path | Mutation type(s) emitted |
|---|---|---|
| CQ1 answered "Park indefinitely" *(per sprint-scoping § 3: CQ5 is auto-skipped in this case; rule fires before any CQ5 row so the user's explicit park intent is not silently dropped)* | `backlog` | `backlog-return` (`cycleId` → null, `state.type` → `backlog`, `assignee` → null) |
| CQ3 answered "superseded by <IDs>" | `cancel` | `cancel` (parse IDs from CQ3 free-text: split on comma/whitespace, dedup tokens via set semantics, match each token against `^BC-\d+$` requiring a non-zero integer suffix (`^BC-[1-9]\d*$`), cap at 10 IDs. If ≥1 token matches: primary valid ID → `duplicateOf`; rest → `relatedTo`; plain-text comment `"Superseded by BC-X, BC-Y per W<NN> planning."` using only the validated IDs. If ZERO tokens match: append `{project_id, issue_id, raw_cq3_answer}` to `state._cq3_parse_errors[]` AND emit a placeholder row `{decision_path: "cancel", mutation_type: "cancel", result: "pending-cq3-reparse", gate_status: "n/a"}` under the `cancel` group so the § 5 preview shows the full intent count, then surface in § 6.0 for inline re-parse before § 6.3 approves the `cancel` group. This preserves the "what you see in the preview is what you approve" contract. |
| CQ5 answered "back to backlog" | `backlog` | `backlog-return` (`cycleId` → null, `state.type` → `backlog`, `assignee` → null) |
| CQ5 answered "specific future cycle <X>" (not W+1) | `cycle` | `cycle-assign` with target = that cycle |
| CQ1 answered "move to W+1" AND CQ3 not "superseded" AND CQ5 not "backlog" | `cycle` | `cycle-assign` with target = `state.cycle.current.id` |
| CQ2 changed assignee AND path is `cycle` or `leave` | (same as primary path; or `reassign` if nothing else changed) | additional `reassign` mutation on same issue |
| CQ2 changed assignee AND path is `cancel` or `backlog` | (primary path wins — assignee change is subsumed) | no separate `reassign` emitted; cancel sets assignee irrelevant, backlog-return nulls assignee anyway |
| All five Qs answered default AND no assignee change | `leave` | *(none — no mutation emitted)* |

`leave`-path issues emit no mutation row at all — they are not written to `state.mutations[]`, not rendered in the § 5 preview, not consumed by a § 6 approval, and not logged. A leave-path outcome is implicit (the issue stays in Linear as-is); only actionable mutations appear in the audit trail.

### 2.3 Per-project scope-block derivation

From `state.projects[i].scope_decisions`:

- **SQ2 `ship_ids` for an ID not already in `carry_over_answers`** (backlog pull): emit `cycle-assign` + `state-change` (backlog → unstarted) as two rows sharing path `cycle`.
- **SQ2 `ship_ids` that name a *new* issue to create** (entry does not match `^BC-\d+$` — planner wrote a title instead of an existing ID): emit `create` row under path `cycle` with `target.id = null`, `target.name` set to the trimmed entry text, and `target.projectId = state.projects[i].id`. Reject empty strings. Every other mutation type also populates `target.projectId` from `state.projects[i].id` (for `milestone-rename` in the global bucket, `target.projectId = null` since milestones are cross-project); this keeps § 3's project-scoped pre-flight reads correct.
- **SQ3 `reassignments` for any issue ID not already covered by CQ2**: emit `reassign` row under path `reassign`.
- **SQ5 `parked` IDs**: emit `backlog-return` row under path `backlog`.
- **SQ4 dependencies**: *(out of scope for this issue; declared in Phase 4 narrative only — no Linear write for this round)*.

### 2.4 Global mutations

- **Milestone renames** from the planning checkpoint (e.g. W16's `"Pre-Launch Hardening" → "Production Hardening"`): emit one `milestone-rename` row with `source_project: "(global)"`. Preview renders under a separate `## Global mutations` section.
- **New-issue creation** with cross-project scope: same section.
- **Label changes** (mutation type `label-change`): enumerated in § 2.1 and supported by § 3 + § 7.3 to satisfy AC #8's "issue label changes" requirement. No derivation rule in the current implementation emits `label-change` rows — the type is reserved for a future Phase 2 extension that strips per-cycle labels (`carrying-over`, `stretch`) on backlog-return / cycle-assign. If BC-5763 dogfood surfaces a concrete label-change need, add an emitter rule here; until then, the dispatch path exists and has been verified against a seeded mutation but is not derived from scope decisions.

### 2.5 De-duplication

If two projects reference the same issue (e.g. an assignee change on an issue owned by project A but scoped into project B's cycle), merge into a single mutation row with last-write-wins on target state. If the two decisions conflict (different target cycles, different assignees, or one says cancel while the other says cycle-assign), do NOT prompt mid-derivation — instead, append the conflict to `state._mutation_conflicts[]` with both source projects + both target states. The conflict rows render as a dedicated `## Conflicts (resolve before execute)` section in the § 5 preview (after the `## CQ3 parse errors` section at the very top) and consume a `Conflicts` group approval in § 6 pre-group 1 — after pre-group 0 CQ3 parse errors, before pre-group 2 Preflight errors, pre-group 3 Gate failures, and the regular decision-path groups. This preserves the "no AskUserQuestion before the preview renders" contract (§ 5 + BC-5810 § 1.1c).

## § 3 Pre-flight idempotency checks (before every write)

Each `state.mutations[i]` entry runs a pre-flight read to detect already-applied state. **Pre-flight short-circuit**: if a row carries `result == "pending-cq3-reparse"`, skip it entirely (do not issue any MCP call, do not enter the dispatch in § 7.3). The row is an intentional placeholder used to make § 5's preview count match § 6.3's approval count; a placeholder that reaches § 7 means § 6.0 resolution was skipped — treat as user-dropped and log `result: "dropped-by-user"` with message "pending-cq3-reparse placeholder unresolved at execute time".

(Synthetic-integrity rows — `gate_detail[0].check == "preflight_integrity"` with `gate_status == "fail"` from § 4 step 4 — are resolved earlier in § 6 pre-group 2's Retry-fetch / Override / Drop handler, not here. A row still carrying that signature at § 7 means § 6 resolution was skipped — § 7.3's loop-entry filter drops them as `"dropped-by-user"`. The § 3 pre-flight ladder below is never entered for such rows.)

Skip-condition field references below use the flat field names populated by `_fetched_issues` under BC-5902 (`issue.cycleId`, `issue.stateType`, `issue.assigneeId`, `issue.labelIds`). When § 3 falls through to a fresh `get_issue` (no cache hit), the caller normalizes the Linear MCP response's nested shape (`issue.state.type` → `issue.stateType`; `issue.labels.map(l => l.id)` → `issue.labelIds`) before applying the skip condition — so the table reads consistently regardless of source.

| Mutation type | Pre-flight read | Skip condition |
|---|---|---|
| `cycle-assign` | `get_issue(id)` | `issue.cycleId == after.cycleId` |
| `state-change` | `get_issue(id)` | `issue.stateType == after.stateType` |
| `reassign` | `get_issue(id)` | `issue.assigneeId == after.assigneeId` |
| `cancel` | `get_issue(id)` + `list_comments(issueId: id)` | `issue.stateType == "canceled"` AND at least one comment body matches `/^Superseded by .* per W\d+ planning\.$/`. Both conditions required — a partial prior run that canceled the issue but failed on `save_comment` must re-attempt the comment step on the next invocation instead of being silently skipped. |
| `create` | `list_issues(project: target.projectId, limit: 250)` | any returned row where `normalize(row.title) == normalize(target.name)` — normalize by trimming whitespace and collapsing internal whitespace runs. Fetch the full project issue set rather than using the fuzzy `query` param (which can miss exact-title duplicates ranked below the default pagination cap). Page if `hasNextPage` is true. **Memoize the full issue list per `target.projectId` in a Phase-3-scoped cache** (`state._create_preflight_cache[projectId]`) — multiple create rows in the same project reuse the first fetch instead of re-paginating. |
| `milestone-rename` | `list_milestones(project: target.projectId)` | milestone exists with `name == after.name` |
| `label-change` | `get_issue(id)` | set of `issue.labelIds` equal to `after.labelIds` set |
| `backlog-return` | `get_issue(id)` | `issue.cycleId == null AND issue.stateType == "backlog" AND issue.assigneeId == null` (all three fields must already be cleared — skipping without the assignee check would leave the `assignee: null` write un-applied on first run) |

On skip: log the row with `result: "skipped-idempotent"`, timestamp the skip decision, move to next mutation. No Linear write issued.

Pre-flight reads are cheap relative to writes — the trade-off is acceptable for AC #5 (second run produces zero write calls). Reuse order for every pre-flight:

1. If § 4's gate-fetch populated `state.projects[i]._fetched_issues[id]` during this Phase 3 invocation, pre-flight reads from that cache without a fresh MCP call. Stale-read risk is bounded by the gate #2 approval window (typically seconds).
2. Else, if Phase 2 populated the same cache earlier in the session, reuse it — same staleness bound.
3. Else, issue a fresh `get_issue(id)` and populate the cache for subsequent reuse.

This drops a redundant `get_issue` per cycle-path row (§ 4 gate fetch + § 3 pre-flight + § 7 execute is the worst case without reuse; with reuse it's one fetch per row).

## § 4 Quality gate re-run for cycle-path mutations

Every mutation with `decision_path == "cycle"` runs the gate again in Phase 3. Two reasons:

1. State may have drifted since Phase 2 approved scope-in (another session, manual Linear edit, Phase 3 resume after pause).
2. Phase 2 captured overrides for *known* failures; Phase 3 belt-and-suspenders catches *new* failures introduced after the scope approval.

**§ 4 is read-only — no `AskUserQuestion` fires in this section.** The gate re-run classifies every cycle-path row; live failures surface in the § 5 preview under a dedicated `## Gate failures (resolve before execute)` section and consume a `Gate failures` group approval in § 6. This preserves the "full preview before any prompt" contract stated in § 2.5.

**Batch dispatch (BC-5902).** After § 2 derivation produces `state.mutations[]`, collect every row where `decision_path == "cycle"` into `preflight_input = [{mutation_id: m.id, issue_id: m.target.id} for m in state.mutations if m.decision_path == "cycle"]`. Flatten `state.projects[].overrides[]` into a single list `flat_overrides = [{issue_id, check, reason}]` across all projects. Dispatch `housekeeping-preflight` once via the `Agent` tool with prompt body: `{cycle.current, team_id, mutation_rows: preflight_input, overrides: flat_overrides}`. Parse the returned JSON into `state._preflight_manifest`.

**Dispatch error handling (fail-loud per BC-5898 AC).** On `_preflight_manifest.dispatch_error` non-null, halt before § 5 and surface `AskUserQuestion` with three options: **Retry** (re-dispatch the agent with the same input), **Pause session** (breadcrumb update `current_phase = "phase-3"`, exit cleanly), **Execute without preflight** (NOT RECOMMENDED — explicit spec-departure override: set `state.phase_3_spec_departure = "preflight-skipped-user-override"`, every cycle-path row gets `gate_status = "n/a"` + `gate_detail = []`, surfacing flag rendered in § 7.5 housekeeping-log Execution summary AND carried into Phase 4 narrative `> **Known gaps this cycle**` callout). No silent "context-pressure-skipped" path anywhere (BC-5898 root-cause fix — attempt-2 regression).

**Row-level error handling.** On `_preflight_manifest.row_errors[]` non-empty (partial fetch failure), surface each errored row as a `## Preflight errors (resolve before execute)` section at the TOP of the § 5 preview and consume a `Preflight errors` group approval in § 6 (pre-group ordering becomes: 0 CQ3 parse → 1 Conflicts → **2 Preflight errors** → 3 Gate failures → 4 regular decision-path groups).

**Manifest consumption.** For each cycle-path mutation row, look up `state._preflight_manifest.manifest[row.id]`:

1. Set `row.gate_detail = manifest_entry.gate_detail` (the 7-tuple from the agent).
2. Derive `row.gate_status` from the tuple: all `status == "pass"` → `"pass"`; any `status == "override"` and no `"fail"` → `"override"` (and copy the matched `matched_reason` into `row.override_reason` — first override wins if multiple checks overridden, but mechanically every override carries its own reason inside the tuple so no loss); any `"fail"` → `"fail"` (row moves from its primary decision-path preview group to the `## Gate failures (resolve before execute)` preview section for § 6 pre-group 3 handling).
3. **Populate `_fetched_issues` cache from snapshot (BC-5902).** If `manifest_entry.issue_snapshot` is present, write it to `state.projects[i]._fetched_issues[manifest_entry.issue_id]` keyed under whichever project owns the mutation via `row.source_project` (every cycle-path row has a non-`(global)` source_project by construction — § 2.1 populates `target.projectId` from `state.projects[i].id` on all cycle-path rows). § 3's pre-flight reuse ladder step 1 reads this cache for equality comparisons against `after.cycleId`/`after.stateType`/`after.assigneeId`/`after.labelIds` (the flat-form fields — § 3's skip-condition table references them directly post-BC-5902), eliminating the redundant `get_issue` per cycle-path row that would otherwise fire in § 3.
4. If `row.id` is NOT present in `_preflight_manifest.manifest` but the row IS in the `preflight_input` (i.e. the agent skipped it without reporting a row_error — bug surface), set `row.gate_status = "fail"` with a synthetic `gate_detail = [{check: "preflight_integrity", status: "fail", message: "mutation_id absent from preflight manifest with no row_error — dispatch agent output integrity violation; re-dispatch required"}]`. Surface under `## Gate failures` so the user can Fix-now by Retry.

Non-cycle-path mutations (`cancel`, `reassign`, `backlog`, `milestone-rename`, global `create`) skip the gate — `gate_status = "n/a"`, `gate_detail = []`. No preflight dispatch for them.

## § 5 Preview rendering

After § 2 derivation + § 4 gate pass, render the preview to the user as plain markdown (one tool-call message, no interactive prompts yet). Group first by `decision_path`, then by `mutation_type` within each path. `leave`-path issues emit no mutation row so they never appear here (see § 2.2 trailing paragraph). Each path with ≥1 row gets its own `## Decision path: <path>` header. A final `## Global mutations` section covers `milestone-rename` + global `create` rows.

```markdown
# W<NN> Housekeeping Preview

Generated: <ISO-8601 now>
Source: <state.checkpoint_path>
Target cycle: <state.cycle.current.name> (<state.cycle.current.id>)

## CQ3 parse errors (resolve before execute)

_Rendered only if `state._cq3_parse_errors[]` is non-empty. Each row shows the carry-over issue + the raw CQ3 answer that produced zero `^BC-\d+$` tokens. Resolved FIRST in § 6.0 before any other group._

Rendering sanitization for the Raw CQ3 answer column: replace `|` with `\|`, replace newlines / carriage returns with the visible glyph `␤`, truncate to 120 characters with ellipsis, and wrap the entire cell in backticks so markdown/HTML inside the user's text is inert. Raw values are logged to the housekeeping log with the same escaping (§ 7.5).

| Issue | Project | Raw CQ3 answer |
|---|---|---|
| BC-XXXX | <project> | `<sanitized free-text>` |

## Conflicts (resolve before execute)

_Rendered only if `state._mutation_conflicts[]` is non-empty. Each row shows the issue ID + both source projects + both target states. Resolved SECOND in § 6.1._

| Issue | Source projects | Target A | Target B |
|---|---|---|---|
| BC-XXXX | <project_A>, <project_B> | <e.g. cycle=W17, assignee=Corinne> | <e.g. cancel, duplicateOf=BC-YYYY> |

## Preflight errors (resolve before execute)

_Rendered only if `state._preflight_manifest.row_errors[]` is non-empty. Each row shows the `mutation_id` + `issue_id` + the fetch error returned by the `housekeeping-preflight` agent. Resolved THIRD in § 6.2 (after CQ3 parse errors + Conflicts) before regular decision-path groups._

| Mutation | Issue | Error |
|---|---|---|
| <mutation_id> | BC-XXXX | <fetch error message> |

## Gate failures (resolve before execute)

_Rendered only if any cycle-path row has `gate_status == "fail"` from § 4. Resolved in § 6 pre-group 3 — after pre-group 0 CQ3 parse errors, pre-group 1 Conflicts, and pre-group 2 Preflight errors._

| Issue | Failing check | Message | Options |
|---|---|---|---|
| BC-XXXX | `dependencies_declared` | "description has no '## Dependencies' header" | Fix now / Override / Drop |

## Decision path: cycle (<N> mutations)

### Type: cycle-assign
| Issue | Title | Action | Before → After | Gate |
|---|---|---|---|---|
| BC-XXXX | <title> | Move to <cycle> | cycle:<before> → <after> | ✓ pass |
| BC-YYYY | <title> | Move to <cycle> | cycle:<before> → <after>, state:started→unstarted | ⚠ override: <check> (reason: <reason>) |

### Type: state-change
…

### Type: reassign
…

## Decision path: cancel (<M> mutations)

### Type: cancel
| BC-ZZZZ | <title> | Cancel, superseded-by BC-AAAA, BC-BBBB | state:unstarted → canceled | n/a |

## Decision path: reassign (<P> mutations)

### Type: reassign
| BC-QQQQ | <title> | <old> → <new> | assignee:<old> → <new> | n/a |

## Decision path: backlog (<R> mutations)

### Type: backlog-return
| BC-SSSS | <title> | Return to backlog | cycle:<w>,state:started → cycle:null,state:backlog | n/a |

## Global mutations

### Type: milestone-rename
| Milestone ID | Action | Before → After |
|---|---|---|
| <uuid> | Rename | "<old>" → "<new>" |

### Type: create
| Title | Project | Target cycle | Assignee |
|---|---|---|---|
| <title> | <project> | <cycle> | <assignee or "(unassigned)"> |

## Summary
- **Total mutations:** <T>
- **By path:** cycle <N>, cancel <M>, reassign <P>, backlog <R>, global <G>
- **Gate blocks:** <F> failing cycle mutations unresolved (0 expected after § 4)
- **Overrides carried forward:** <O> from Phase 2 + <O'> new in Phase 3
- **Estimated execute time:** ~<T × 0.5>s at ~500ms/call through MCP
```

Render the full preview before any `AskUserQuestion`. The user reads the whole thing before approving the first group.

## § 6 Per-group approval via AskUserQuestion

After the preview renders, iterate over the distinct non-empty groups in this order — four pre-groups first so that CQ3 parse errors, conflicts, preflight errors, and gate failures are resolved before any regular decision-path group is approved:

0. **CQ3 parse errors** (from `state._cq3_parse_errors[]`, § 2.2 cancel-row derivation). For each entry, surface the carry-over issue's identity in the prompt (the placeholder's `result == "pending-cq3-reparse"` row in the `cancel` group is the row that will be resolved; § 2.2 rules ensure no concurrent `leave`/`backlog` row exists for CQ3-parse-fail issues unless CQ1=Park AND CQ3 were both answered, a rare overlap the prompt should enumerate). `AskUserQuestion` with three options: **Re-enter IDs** (follow-up free-text `AskUserQuestion`; re-parse with `^BC-[1-9]\d*$` requirement; dedup tokens via set semantics; cap at 10 IDs; on ≥1 valid ID, **replace the placeholder row in-place**: match by `issue_id` + `result == "pending-cq3-reparse"`, set `after.duplicateOfId`, set `after.relatedToIds`, clear `result` to `null`, regenerate the row's `id`. Remove the corresponding entry from `state._cq3_parse_errors[]`. Do not touch any other row for this issue), **Drop cancel** (remove the placeholder row from `state.mutations[]`; the issue retains whatever other rows § 2.2 derived — if none, the issue stays in Linear as-is), **Keep as leave** (remove the placeholder row; no mutation emitted for this issue). Handler is inline re-parse — does NOT call the quality-gate.
1. **Conflicts** (from `state._mutation_conflicts[]`, § 2.5). For each conflict row, `AskUserQuestion` with three options:

   | Option | Effect |
   |---|---|
   | **Pick source A/B** | Replace the issue's mutation row(s) with A's (or B's) decision; drop the other source's row. |
   | **Merge manually** | Collect the merged target state via **four sequential `AskUserQuestion` calls** (one field per call, per `memory/feedback_one_question_at_a_time.md`): (i) target cycle name (free-text; leave blank for `null`/backlog), (ii) assignee name (free-text; leave blank for unassigned), (iii) target state name (free-text), (iv) comma-separated labels (free-text; blank for none). After collecting all four, re-derive `decision_path` from the merged fields (state=`backlog` + cycle=`null` → `backlog`; state=`Canceled` → `cancel`; state in cycle workflow → `cycle`). If the derived path is `cycle`, re-run `cadence:issue-quality-gate` on the merged row before replacing existing rows. Invalid field values are not pre-validated (no Phase-0 cache of cycles/users/states/labels exists); `save_issue` at § 7.3 will surface Linear's rejection message as `result: "errored"` on execute. This prevents merge-flow bypass of the § 4 gate while keeping Phase 3 free of lookup-cache dependencies that weekly.md Phase 0 does not provide. |
   | **Drop the issue** | Remove every mutation row for this `issue_id` across all groups (not just the conflicting pair). |

   Resolution updates `state.mutations[]` in place before the next group runs.
2. **Preflight errors** (from `state._preflight_manifest.row_errors[]`, § 4). Each errored row requires inline resolution because the gate could not be applied. For each entry, surface the mutation_id + issue_id + error via `AskUserQuestion` with three options:

   | Option | Effect |
   |---|---|
   | **Retry fetch** | Dispatcher issues a fresh `get_issue(id)` in main thread + inline-re-applies the 7 checks from `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md`. On success, the row's `gate_detail` populates in `_preflight_manifest.manifest[mutation_id]` and the row proceeds to its primary decision-path group. On continued failure, re-prompt with the same three options. |
   | **Override all 7 checks for this row with reason** | Follow-up free-text `AskUserQuestion` (one question) collecting the reason. Append `{issue_id, check: "all", reason}` to `state.projects[i].overrides`. Row is flagged `gate_status = "override"` with a synthetic gate_detail of 7 `override` tuples sharing the same reason. |
   | **Drop from scope** | Remove the row from `state.mutations[]`; the mutation does not execute. |
3. **Gate failures** (rows with `gate_status == "fail"` from § 4). For each failing row, `AskUserQuestion` with three options: Fix now (echo `https://linear.app/brite-nites/issue/<id>`, wait for user confirmation, re-run gate, on pass the row re-enters its primary decision-path group), Override with reason (collect a one-line free-text reason via follow-up `AskUserQuestion`, append `{issue_id, check, reason}` to `state.projects[i].overrides`, set `gate_status = "override"`, re-enter primary group), or Drop from scope (remove the row from `state.mutations[]`).
4. **Regular decision-path groups** — iterate the four `decision_path` values (`cycle`, `cancel`, `reassign`, `backlog`) plus the `global` preview bucket (rows with `source_project == "(global)"` — e.g. `milestone-rename` + cross-project `create`). Skip any empty group. For each non-empty group, one `AskUserQuestion` call with the three options defined below.

The count of `AskUserQuestion` group-approval calls for the **regular decision-path groups** (step 4) equals the number of distinct non-empty decision-path groups in the checkpoint — this is the literal AC #3 assertion. Pre-groups (0/1/2/3) are per-row by necessity — each CQ3 parse error, conflict, preflight error, or live gate failure requires individual resolution because merging them into a single batch prompt would lose the per-row context the user needs to decide. Fix-now / Override / Retry-fetch follow-ups inside regular-group or preflight-group entries are also per-row conditional and not part of the AC #3 regular-group count. When tallying AC #3 evidence, count only the prompts fired in step 4.

Each group prompt offers three options:

| Option | Effect |
|---|---|
| **Approve these <N> mutations** *(Recommended)* | Flag every row in the group as `approved: true`; continue to next group. |
| **Reject all in this group** | Flag every row in the group as `result: "dropped-by-user"`; log reason; continue to next group. |
| **Edit** | Follow-up `AskUserQuestion` asks "Which issue IDs to drop from this group?" with free-text input; parse comma-separated IDs matching `^BC-\d+$`; drop matching rows from the group; remaining rows flag `approved: true`. The standard `AskUserQuestion` "Other" escape is always present and accepts free-text override instructions per the platform convention. |

After all groups have been answered, render a final execution gate:

> *"Ready to execute <A> approved mutations across <G> groups. <D> dropped by user, <O> overrides captured. Proceed?"*

| Option | Effect |
|---|---|
| **Execute now** *(Recommended)* | Move to § 7 batch execute. |
| **Cancel** | Log the cancel, exit cleanly. No mutations issued. State object retained so user can re-invoke `/cadence:weekly --resume-phase 3`. |

Hard rule: no Linear write is issued until the final **Execute now** approval. This is the gate reason (c) from BC-5810 § 1.1.

## § 7 Batch execute + housekeeping log

### 7.1 Resolve housekeeping log path

Prefer reusing Phase 2's already-resolved path. If `state.checkpoint_path` is non-null, derive the log path by replacing the filename suffix `-planning-checkpoint.md` → `-housekeeping-log.md` within the same parent directory — no `git rev-parse` Bash call needed.

If `state.checkpoint_path` is null (Phase 3 was invoked standalone via `--resume-phase 3`), resolve from scratch. Mirror Phase 2 § 6: pre-extract `CYCLE_NN` from `state.cycle.current.name` and `CYCLE_DATE` from `state.cycle.current.startsAt` (formatted `YYYY-MM-DD`). Reject if `CYCLE_DATE` does not match `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`. Pseudocode:

```
# Pre-extracted by the skill from state:
#   CYCLE_NN   = numeric week from state.cycle.current.name (e.g. "W17" → 17)
#   CYCLE_DATE = state.cycle.current.startsAt formatted YYYY-MM-DD
# Then in Bash, with runtime guards (defense-in-depth — prose rejection above is advisory; these assertions enforce shape at shell level):
[[ "$CYCLE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "Invalid CYCLE_DATE: $CYCLE_DATE" >&2; exit 1; }
[[ "$CYCLE_NN" =~ ^[0-9]+$ ]] || { echo "Invalid CYCLE_NN: $CYCLE_NN" >&2; exit 1; }
WEEK_NN=$(printf "%02d" "$CYCLE_NN")
ROOT=$(git rev-parse --show-toplevel)
LOG="$ROOT/../weekly-planning/w${WEEK_NN}-${CYCLE_DATE}/w${WEEK_NN}-housekeeping-log.md"
```

If `state.weekly_planning_root` is set, use it as the prefix instead of `$ROOT/..`. Cache the resolved path at `state.housekeeping_log_path`. The Bash `exit 1` on a shape-check failure is intentional fail-fast — upstream Phase 0 must produce a well-formed `state.cycle.current.{name,startsAt}`. On fail-fast, the skill surfaces the stderr message to the user and exits cleanly without partial state mutation.

### 7.2 Log header (write once before any mutation)

```markdown
# W<NN> Housekeeping Log

Generated: <ISO-8601>
Phase 3 run by: /cadence:weekly phase 3
Target cycle: W<NN> (<cycle_id>)
Source preview: see preview output from this session

## Execution summary
_Populated at end of run._

## Mutations
| Timestamp | Decision path | Mutation type | Issue | Before | After | Gate | Result | Error |
|---|---|---|---|---|---|---|---|---|
```

### 7.3 Execute each mutation

For each row in `state.mutations[]` where `approved: true` AND `result != "pending-cq3-reparse"` (belt-and-suspenders guard against a placeholder leaking past § 6.0) AND not a synthetic-integrity row still carrying `gate_detail[0].check == "preflight_integrity"` with `gate_status == "fail"` (which would indicate § 6 pre-group 2 Retry/Override resolution was skipped — treat as `"dropped-by-user"` and log `result: "dropped-by-user"` with message "preflight_integrity synthetic failure unresolved at execute time"):

1. Record `started_at = <ISO-8601 now>`.
2. Run the § 3 pre-flight read. If skip condition met: set `result = "skipped-idempotent"`, `executed_at = started_at`, append row to log, continue.
3. Otherwise, call the appropriate Linear MCP mutation:

   | Type | MCP call | Key parameters |
   |---|---|---|
   | `cycle-assign` | `save_issue` | `{ id, cycle: after.cycleName }` |
   | `state-change` | `save_issue` | `{ id, state: after.stateName }` |
   | `reassign` | `save_issue` | `{ id, assignee: after.assigneeName }` (use `assignee`, NOT `assigneeId`, per `memory/MEMORY.md`) |
   | `cancel` | `save_issue` + `save_comment` | `save_issue { id, state: "Canceled", duplicateOf: after.duplicateOfId }`, then `save_comment { issueId: id, body: "Superseded by <IDs> per W<NN> planning." }` (plain text, no markdown — avoids Prosemirror mangling) |
   | `create` | `save_issue` | `{ title, team, project, cycle, assignee, priority, description }` |
   | `milestone-rename` | `save_milestone` | `{ id, name: after.name }` |
   | `label-change` | `save_issue` | `{ id, labels: after.labelNames }` |
   | `backlog-return` | `save_issue` | `{ id, cycle: null, state: "Backlog", assignee: null }` *(multiple fields in one call)* |

4. On success: record `executed_at = <ISO-8601 now>`, `result = "executed"`. Append log row.
5. On MCP error: record `result = "errored"`, `error = <message>`. Append log row. Continue to next mutation — do not abort.
6. Only for mutations that write prose (`create`, `cancel`'s `save_comment` body, `milestone-rename` when new name contains `**`/`→`/`=`/`§`), re-read post-write via `get_issue` / `get_milestone` and verify Prosemirror did not mangle the text (per `memory/gotcha_linear_markdown_mangling.md`). `cycle-assign`, `state-change`, `reassign`, `label-change`, `backlog-return` skip the post-write read — they touch only structured fields, not markdown bodies. If mangled, log a warning but do not fail.

### 7.4 Rate limiting

Linear GraphQL mutations average ~300-600ms per call through the MCP round-trip. Natural pacing keeps burst rate at ~3-4 writes/sec — well under the 10/sec ceiling. No explicit sleep is inserted in the happy path.

The log's ISO-8601 timestamps are the audit source for AC #7. Post-execution assertion in § 7.5 slides a 1-second window across the `executed_at` column **filtered to rows where `result == "executed"`** — skipped-idempotent rows share `started_at` as their `executed_at` (instant, no MCP call) and must not count against the rate-limit check. AC #5's "second run = zero writes" path would otherwise false-positive a rate-limit fail by bunching 80 instant skip rows into a sub-second window. If the filtered assertion ever fails in practice, add `Bash sleep 0.15` between executed writes in a follow-up PR.

### 7.5 Close out log

Once every mutation has been attempted, populate the `## Execution summary` section:

```markdown
## Execution summary
- **Mutations previewed:** <T>
- **Approved by user:** <A>
- **Executed:** <E>
- **Skipped (idempotent):** <S>
- **Dropped by user:** <D>
- **Errored:** <X>
- **Duration:** <started>..<ended> (<elapsed>s)
- **Max writes/sec observed:** <rate> (AC #7 compliance — computed from rows where `result == "executed"` only; skipped/errored/dropped rows excluded because they issued no MCP call)
- **Rate-limit check:** <pass|fail> (AC #7 requires ≤10/sec)
```

## § 8 Idempotency + resume + failure handling

- **Resume pass.** On Phase 3 entry, if `state.housekeeping_log_path` already points at a file and that file contains a `## Mutations` table with rows, parse the existing rows to populate `state._executed_mutation_ids[]`. Any mutation in `state.mutations[]` whose `id` appears in the cache is short-circuited to `result: "skipped-idempotent"` without a Linear read. This handles the "second run" path required by AC #5.
- **Pre-flight read as second line of defense.** Even if the cache is cold, § 3's pre-flight read catches already-applied state. AC #5's "second run = zero writes" holds in both cached and uncached second-run scenarios.
- **Mid-batch user cancel.** The § 6 execution gate is the last user decision. Once execute starts, the skill does not re-prompt until § 7.5's summary. A SIGINT / session exit mid-batch leaves `state.mutations[]` partially populated with `executed_at` timestamps — resume picks up via `_executed_mutation_ids[]` on next run.
- **Cycle-change guard.** If `state.housekeeping_log_path` exists and its filename's `w<NN>` segment does not match the cycle derived from `state.cycle.current.name`, refuse to append and stop with an error pointing the user at `/cadence:weekly --resume-phase 3` after they confirm the cycle. Guards against a stale `state.weekly_planning_root` override pointing at a prior cycle's folder.
- **Errored mutations.** A mutation logged with `result: "errored"` does not set `_executed_mutation_ids[]`. Re-invoking Phase 3 retries the errored mutation only (successful ones pre-flight as idempotent).
- **Pending-cq3-reparse placeholder rows.** Placeholders never enter `_executed_mutation_ids[]` (they are not Linear writes). On resume, `_cq3_parse_errors[]` is re-derived from `state.projects[i].scope_decisions.carry_over_answers[]` so the placeholder rows re-appear in the preview and re-prompt in § 6.0 until the user resolves them. AC #5's "second run = zero writes" guarantee assumes the user's CQ3 resolution is stable across runs; a second-run resolution that emits new valid IDs legitimately produces writes.

## § 9 References

- `docs/designs/cadence-orchestration.md` § 1.1c (batch-at-end reason) + § 3 (gate spec) — BC-5810 authoritative
- `docs/designs/cadence-plugin.md` (BC-5757) — voice, Linear query recipes, PDF flow
- `plugins/cadence/skills/sprint-scoping/SKILL.md` (BC-5760) — state-object producer, checkpoint path resolution, idempotency pattern
- `plugins/cadence/skills/_shared/issue-quality-gate/SKILL.md` — gate primitive (BC-5810 § 3)
- `plugins/cadence/agents/housekeeping-preflight.md` — preflight agent this skill dispatches (BC-5902)
- `plugins/cadence/agents/project-audit.md` (BC-5759) — audit card field names for `before`-state lookups
- `plugins/cadence/commands/weekly.md` § Phase 3 — entry command pointer + session state object schema
- `plugins/workflows/skills/create-issues/SKILL.md` — canonical create-mutation pattern
- `memory/MEMORY.md` (Conventions) — `assignee:` not `assigneeId:` on `save_issue`
- `memory/gotcha_linear_markdown_mangling.md` — Prosemirror mangling; plain-text comment bodies; post-write `get_issue` verification
- `memory/feedback_more_checkins_for_infra_issues.md` — Phase 3 is the most destructive phase; per-group approval + final execute gate satisfy the check-in rule
- `weekly-planning/w16-2026-04-13/w16-planning-checkpoint.md` § Actions Taken — ground-truth example exercising every mutation type

## Deferred to follow-up issues

- **SQ4 dependency writes** (`blockedBy` / `blocks` relations on issues scoped into the cycle) — currently declared in Phase 4 narrative only. If planner wants these written back to Linear, file a follow-up issue in the Cadence Plugin milestone.
- **Partial preview re-render on "Edit"** — current impl drops rows by ID and proceeds to the next group. A richer edit flow (change target cycle, rewrite cancel supersede chain, retarget milestone rename) belongs in a v2 issue if usage demand surfaces during BC-5763 dogfood.
