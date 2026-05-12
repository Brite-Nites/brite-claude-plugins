---
name: flow-linear-scaffold
description: Heaviest-mutation sub-skill for the flow-architecture plugin (implements CDR-023). Writes per-domain Linear scaffolding — 1 milestone + N sub-flow parent issues + 5N discipline children + N Children-summary comments + 1 milestone description refresh = 2+7N writes per domain. Per-sub-flow execution unit, per-domain preview/approval. 3-layer idempotency (`.flow/scaffold-log/<domain>.md` append-only + per-sub-flow `list_issues` lookup + MCP error row flag). 100% per-issue fidelity-review coverage via background `Agent(general-purpose)` dispatch with sub-flow-boundary collection (every 6 issues). 1 mandatory pre-scaffold preview gate; conditional gates for failure recovery only. Sub-flow-atomic classified retry on failure (transient -> 1 retry + 2s backoff; permanent -> AskUserQuestion; cascading -> permanent + abort). Preview budget `(2+7N) × 500ms` -> N=10 ~36s, N=30 ~106s.
user-invocable: false
disable-model-invocation: true
allowed-tools: mcp__plugin_workflows_linear-server__list_milestones, mcp__plugin_workflows_linear-server__save_milestone, mcp__plugin_workflows_linear-server__get_milestone, mcp__plugin_workflows_linear-server__save_issue, mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, mcp__plugin_workflows_linear-server__save_comment, Agent, AskUserQuestion, Bash, Read, Write
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q13, Q22, Q23, Q24"
  related-locks: "memory:80-93 (Q13 5 sub-decisions); Q22 milestone schema; Q23 parent-issue template; Q24 discipline-child templates; Q46 linear-writeback layer (consumed via _shared/linear-writeback-pattern.md)"
---

# flow-linear-scaffold

Per-domain Linear scaffolding sub-skill. Writes the foundational structure for every FDA domain: 1 milestone + N sub-flow parents + 5N discipline children + N Children-summary comments + a final milestone-description refresh. **2+7N writes per domain.**

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7). Invoked from `/flow:start-project` (greenfield, per-domain), `/flow:retrofit-project` (retrofit, per-new-domain after `flow-legacy-cross-reference`), and `/flow:add-domain` (single-domain orchestrator).

**Heaviest-mutation skill in the plugin.** All Linear writes go through `skills/_shared/linear-writeback-pattern.md` (Q46 layer). Preview-all -> one-approval -> execute -> log + pre-flight reads is the load-bearing pattern (cadence linear-housekeeping precedent).

The full design rationale lives in `docs/design-rationale/project_fda_plugin_interview.md` Q13 (memory:80-93). Q22 (milestone schema), Q23 (parent-issue template), Q24 (discipline-child templates) are the upstream content contracts.

---

## 1. Mutation order (Q13.1)

### Per sub-flow execution unit

```
parent
  -> [Story] (foundation, no blockedBy)
  -> ([Design] || [Eng] in parallel, both blockedBy [Story])
  -> [QA] (blockedBy [Eng] + [Design])
  -> [Docs] (blockedBy [QA])
  -> Children-summary comment on parent
```

**Execution graph:** `[Story] -> ([Design] || [Eng]) -> [QA] -> [Docs]`. Design and Eng parallelize AFTER Story exists --- NOT from the start. The `blockedBy` chain encodes this; the writes happen in this dependency order so each new issue's `blockedBy` refs already exist.

### Per-domain wrapper

1. **Mandatory pre-scaffold preview gate** (Section 4) --- shows the full per-domain write plan + L3 review headlines.
2. Execute one sub-flow at a time (sub-flow-atomic --- Section 5).
3. After ALL sub-flows in the domain complete: refresh the milestone description's Sub-flows table via `save_milestone`.

### Write tally (per domain)

| Write type | Count | Endpoint |
|---|---|---|
| Milestone create | 1 | `save_milestone` |
| Sub-flow parent | N | `save_issue` |
| [Story] discipline child | N | `save_issue` |
| [Design] discipline child | N | `save_issue` |
| [Eng] discipline child | N | `save_issue` |
| [QA] discipline child | N | `save_issue` |
| [Docs] discipline child | N | `save_issue` |
| Children-summary comment | N | `save_comment` |
| Milestone description refresh | 1 | `save_milestone` (idempotent on Sub-flows table content) |
| **Total** | **2 + 7N** | --- |

---

## 2. Idempotency (Q13.2) --- 3 layers

### L1 --- `.flow/scaffold-log/<domain>.md` append-only log

A cheap resume cache (no Linear reads required for the common-case re-run). One row per write:

```
2026-05-11T18:30:00Z  parent  AUTH-01  BC-XXXXX  result: executed
2026-05-11T18:30:01Z  story   AUTH-01  BC-XXXXY  result: executed
2026-05-11T18:30:01Z  design  AUTH-01  BC-XXXXZ  result: executed
2026-05-11T18:30:02Z  eng     AUTH-01  BC-XXX10  result: executed
...
```

Re-run: skill reads the log, identifies executed rows, skips them.

### L2 --- per-sub-flow `list_issues` lookup

At sub-flow start, even with no L1 entry, run:

```
list_issues({labels: ["domain:<slug>"], title contains "<DOMAIN-NN>"})
```

Catches **manual creates outside the plugin** (someone hand-rolled the parent issue between runs). If found, populate L1 retroactively and skip those writes.

### L3 --- MCP error row flag

When a write fails permanently and the user picks `Skip sub-flow + continue domain`, the L1 row carries `result: errored`. On re-run, errored rows are skipped (don't re-attempt) unless the user explicitly passes `--retry-errored`.

---

## 3. Per-issue fidelity-review (Q13.3) --- 100% coverage, background dispatch

`Agent(general-purpose, run_in_background: true)` per issue. Sub-flow-boundary collection (every 6 issues: parent + 5 children).

Each review agent receives:

- Live Linear body of the just-written issue.
- Rendered template (parent: Q23; children: Q24).
- L3 review summary content (for parent issues).

Returns either `PASS` or top-5 drift findings capped at 150 words.

**FAILs fixed via** `save_issue {id, body: <corrected>}` + re-dispatch the review on the fixed version. Re-fixes loop until PASS OR `--max-fix-attempts=2` (defaults to 2). Persistent FAIL after attempts -> flag in scaffold log, surface in end-of-run summary.

**Fix-attempt writes inflate the 2+7N happy-path tally.** The headline "2+7N writes per domain" budget is the lower bound — fix-loop iterations add up to 2 extra `save_issue` calls per failed fidelity-review. Per Section 3's sub-flow-boundary cadence ("every 6 issues: parent + 5 children"), only the **6N fidelity-reviewed surfaces** (N parents + 5N children) can trigger fix-attempts; the 2 milestone writes (initial create + Sub-flows table refresh) and N Children-summary comments are NOT fidelity-reviewed per Q13.3. Worst-case write count is `2 + 7N + 2 * (fail_rate * 6N)`. With 10% fidelity-review fail rate and N=8 sub-flows: 2 + 56 + 2 * 0.10 * 48 ≈ 58 + 10 = **~68 worst-case writes** (vs 58 happy-path floor). The pre-scaffold preview gate's wall-time estimate is a lower-bound floor — surface this caveat in the preview as a bracketed range, e.g., `Estimated wall time: ~29s happy-path; up to ~34s with fidelity-fix retries at 10% fail rate`.

Pattern from `feedback_bulk_create_review_agents.md`.

---

## 4. User-confirmation gates (Q13.4) --- 1 mandatory + conditional recovery

### Mandatory pre-scaffold preview gate

```
Scaffold AUTH domain (8 sub-flows = 1 milestone + 8 parents + 40 children + 8 summary comments + 1 description refresh = 58 writes)?

Per-sub-flow L3 review headlines:
  AUTH-01: [Story] PASS / [Eng] PASS / [Design] PASS / [QA] PASS / [Docs] PASS
  AUTH-02: ...
  ...

Estimated wall time: ~29s happy-path (58 * 500ms); up to ~34s if fidelity-review fixes fire at 10% fail rate (see Section 3 caveat).

  - Execute
  - Edit (open inventory rows for editing)
  - Cancel
```

**Two distinct review passes — do not conflate.**

| Pass | Fires | Reviews | Lives at |
|---|---|---|---|
| **L3 review** (5-discipline, parent-scope) | Pre-write, BEFORE the preview gate | The **draft** parent + children bodies in memory | Parent issue body `## L3 review summary` (post-write) |
| **Per-issue fidelity review** (Section 3) | Post-write, AFTER each issue is written | The **live Linear body** of the just-written issue | Background-collected at sub-flow boundary |

L3 reviews run against drafts so their per-discipline headlines can populate the parent's `## L3 review summary` section in the preview-gate render — the user sees them before approving the scaffold. Per-issue fidelity reviews (Section 3) run against live Linear bodies post-write to catch Prosemirror mangling and template-substitution drift. **They are separate passes against different content with different cadences** — Section 3's "live Linear body" claim and this section's "BEFORE the preview gate" claim describe the two passes respectively.

### Conditional recovery gates (Q13.5)

Fire only on failure (Section 5). Not pre-budgeted.

---

## 5. Failure recovery (Q13.5) --- sub-flow-atomic with classified retry

### Classification

| Category | Examples | Behavior |
|---|---|---|
| **Transient** | timeout, rate-limit | 1 retry + 2s backoff. Persists -> reclassify as permanent. |
| **Permanent** | invalid label, missing project membership, malformed markdown rejected by Prosemirror, fractional estimate's `auth_invalid` | Abort the sub-flow. `AskUserQuestion`: Retry sub-flow / Skip sub-flow + continue domain / Halt domain. |
| **Cascading** | `[Story]` failed -> `[Eng]` `blockedBy` unresolvable | Treat as permanent. NEVER proceed with empty `blockedBy` (would produce broken Linear state). |

### Sub-flow-atomic

A sub-flow either fully scaffolds (parent + 5 children + comment) OR rolls back to "errored row in scaffold log + no half-state". The L1 log gets one row per attempted write; the L2 list_issues lookup catches half-state on re-run.

### Preview time-budget

`(2 + 7N) × ~500ms` for the gate UX:

- N=10 -> ~36s preview generation time.
- N=30 -> ~106s.

Cadence linear-housekeeping is the closest precedent (preview-all -> one-approval -> execute -> log + pre-flight reads).

---

## Worked example

`/flow:start-project` for the AUTH domain with N=8 sub-flows:

1. Skill reads inventory `master-flow-inventory.md` AUTH section -> 8 inventory rows.
2. **L1 check.** `.flow/scaffold-log/auth.md` missing -> fresh run.
3. **L2 check.** `list_issues({labels: ["domain:auth"]})` -> 0 hits. Confirms no manual creates.
4. Skill drafts: 1 milestone body (Q22) + 8 parents (Q23) + 40 discipline-child bodies (Q24).
5. Fans 8 background L3-review agents (1 per parent, each scoring 5 discipline headlines).
6. Pre-scaffold preview gate fires; user reviews, approves.
7. Skill executes 58 writes in sub-flow order. Per-issue fidelity-review fans out background; collected every 6 issues at sub-flow boundary.
8. Mid-run: AUTH-04 [Eng] hits a rate-limit -> 2s backoff -> retry succeeds. AUTH-06 [Docs] hits Prosemirror rejection (permanent). `AskUserQuestion` -> user picks `Skip + continue domain`. AUTH-06 row marked `result: errored` in L1.
9. After all 8 sub-flows: refresh milestone description's Sub-flows table.
10. End-of-run summary: `flow-linear-scaffold: 57/58 writes executed, 1 errored (AUTH-06 [Docs] --- Prosemirror rejected; re-run with --retry-errored after fixing).`

---

## Helper utilities

This skill depends on three `_shared/` utilities (BC-6955):

| Utility | Role |
|---|---|
| `_shared/linear-writeback-pattern.md` | Q46 layer; every Linear write goes through this contract. |
| `_shared/artifact-gate-pattern.md` | Pre-scaffold preview gate UX template. |
| `_shared/checkpoint-pattern.md` | Sub-flow-boundary fidelity-review collection cadence. |

---

## See also

- `docs/design-rationale/project_fda_plugin_interview.md` Q13 --- canonical 5-sub-decision spec.
- `docs/design-rationale/project_fda_plugin_interview.md` Q22 --- milestone schema (Sub-flows table this skill writes + refreshes).
- `docs/design-rationale/project_fda_plugin_interview.md` Q23 --- parent-issue template + `## L3 review summary` (mod 2).
- `docs/design-rationale/project_fda_plugin_interview.md` Q24 --- discipline-child templates ([Story]/[Eng]/[Design]/[QA]/[Docs]).
- `docs/design-rationale/project_fda_plugin_interview.md` Q46 --- linear-writeback layer (executor-side double-layer safety).
- `skills/_shared/linear-writeback-pattern.md` --- Q46 implementation.
- `skills/flow-doc-author/SKILL.md` --- downstream sub-skill that consumes `state.scaffold_log.<domain>` for parent + children BC numbers.
- `skills/flow-journey-author/SKILL.md` --- downstream sub-skill that consumes the milestone BC for journey-doc front-matter.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; `MODE` signal drives whether this skill writes net-new domains (greenfield/retrofit-Phase-4/incremental-add) or skips (resume).
- `plugins/cadence/commands/weekly.md` --- closest mutation-pattern precedent (preview-all -> one-approval -> execute -> log).
