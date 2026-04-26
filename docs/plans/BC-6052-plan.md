# BC-6052 — project-audit subagent drops per-flag list (spec departure)

**Linear:** https://linear.app/brite-nites/issue/BC-6052/
**Branch:** `holden/bc-6052-project-audit-quality-gate-flags`
**Worktree:** `.claude/worktrees/bc-6052/`
**Parent:** BC-5763 (W17 dogfood)
**Related:** BC-5870 (renders the per-check breakdown that this issue unblocks)

## Problem

W17 audit.json against real data showed every `audit_cards[]` entry with **flags** stored as:

```json
{
  "quality_gate_flags": [],
  "quality_gate_flags_count": 5
}
```

But `plugins/cadence/agents/project-audit.md:42` declares the canonical schema as:

```json
"quality_gate_flags": [{"issue_id": "", "check": "", "message": ""}]
```

The agent is improvising a count-only shape that no spec declares. Consequence:

1. BC-5870's § 1.6 aggregation line (>10 flags → top-3 projects + top-3 check types) **cannot compute the per-check breakdown** without the full list — degrades to the per-project half against real data.
2. `commands/weekly.md § 1.5` persistence contract ("audit.json always retains the full per-flag record — display decision, not data-loss decision") is silently violated.
3. Any downstream consumer (sprint-scoping § 25 list, project-enricher, narrative-writer) is silently flag-blind.

## Discovered during read (in scope, same PR)

`commands/weekly.md` § 1.6 lines 297–298 read `audit_cards[].flags[]` and `flag.check` — drifted field names. The canonical name is `quality_gate_flags` (per project-audit.md § Output line 42). The renderer would silently render `0 flags` even with a fully-populated full-list shape — a separate but coupled bug.

## Approach

Two coupled, surgical edits + one validation:

1. **Tighten `agents/project-audit.md` Step 5 + Output schema** so the LLM running as the agent cannot improvise a count-only form. Make the imperative explicit, add a populated-shape positive example, and explicitly forbid the `_count`-only shape with a "MUST emit each entry" sentence.
2. **Fix `commands/weekly.md § 1.6` renderer drift** — `audit_cards[].flags[]` → `audit_cards[].quality_gate_flags[]`, `flag.check` → `quality_gate_flag.check` (4 occurrences across lines 297–298). Add a one-line `audit_cards[].quality_gate_flags[]` reference next to the existing `audit_card.shipped.count` reference in line 291 vicinity if needed for symmetry.
3. **Validation** — manual seeded check: hand-construct an audit_card with 3 flags and re-run § 1.6 rendering against it (paste-and-trace, no test runner). Confirm:
   (a) the persistence path under § 1.5 retains the full shape;
   (b) the >10 render path can name top-3 check types, not just top-3 projects.
4. **Decision micro-question:** should `quality_gate_flags_count` be retained as a parallel convenience field (cheap, declared, no consumers update needed) or dropped (one-source-of-truth, cleaner)? Recommendation: **drop** — it has no declared consumers and parallel fields invite drift. If kept, it must be added to the Output schema explicitly. (Plan-doc gate, asked at execution start, not a brainstorm.)

This is bounded and reversible. No new persistence, no new state fields (assuming we drop `_count`), no consumer updates required (the spec said to emit the list — consumers were already coded against that contract; it's the agent that drifted).

## Tasks

### Task 1 — Tighten project-audit.md Step 5 + Output schema

**File:** `plugins/cadence/agents/project-audit.md`

**Step 5 (line 28):** rewrite as:

> 5. **Quality-gate flags.** For each shipped issue without a `pr_url` from step 3, emit a JSON object `{issue_id: <id>, check: "done_with_evidence", message: "completed but no PR/commit URL in comments"}` and append it to the `quality_gate_flags` array. **Emit the full object per failure — do NOT replace the array with a `quality_gate_flags_count` integer or any count-only form. The dispatcher's renderer (`commands/weekly.md § 1.6`) and downstream consumers (`sprint-scoping/SKILL.md § 25`) read individual entries, not aggregates.** Phase 1 surfaces only check #7 (cheapest fake-Done detector); checks 1–6 run at scope time in Phase 2 against the broader skill.

**Output schema (line 42):** replace the placeholder shape with a populated example so the model has a concrete pattern to emit:

```json
"quality_gate_flags": [
  {"issue_id": "BC-1234", "check": "done_with_evidence", "message": "completed but no PR/commit URL in comments"},
  {"issue_id": "BC-1235", "check": "done_with_evidence", "message": "completed but no PR/commit URL in comments"}
]
```

…and add a one-line note immediately after the JSON block:

> Each `quality_gate_flags[]` entry MUST be a full `{issue_id, check, message}` object. An empty list (`[]`) means no flags. Do not emit `quality_gate_flags_count`, `quality_gate_flags_summary`, or any count-only convenience field — they are not declared in this schema and the dispatcher does not read them.

**Verification:** grep `plugins/cadence/agents/project-audit.md` for the literal string `quality_gate_flags_count`. Should return one match (the prohibition line, not a schema declaration).

### Task 2 — Fix weekly.md § 1.6 renderer drift

**File:** `plugins/cadence/commands/weekly.md`

**Line 297:** "**>10 flags total**: one aggregation line — `<N> flags total; highest density in <proj-1> (<n1>), <proj-2> (<n2>), <proj-3> (<n3>); by check: <check-1> (<m1>), <check-2> (<m2>), <check-3> (<m3>). Full records in audit.json.`" — no field names referenced, leave as-is.

**Line 298:** rewrite the field references:

- `audit_cards[].flags[]` → `audit_cards[].quality_gate_flags[]`
- `flag.check` → `quality_gate_flag.check`

Resulting line:

> Top-3 projects are ranked by absolute flag count across `audit_cards[].quality_gate_flags[]`, ties broken alphabetically by project name. Top-3 check types apply the same rule over `quality_gate_flag.check`. If fewer than 3 distinct projects or check types have flags, emit the actual count. `audit.json` always retains the full per-flag record regardless of which render path fires (§ 1.5 persistence is unchanged — the cap is a display decision, not a data-loss decision).

**Verification:** grep `plugins/cadence/commands/weekly.md` for `flags\[\]` (escape brackets for grep). Should match only `quality_gate_flags[]`, not bare `flags[]`. Also grep for `flag\.check` — should match `quality_gate_flag.check` only.

### Task 3 — Seeded persistence + render trace

**No file change** — paste-and-trace verification.

Construct in plan-doc Verify section: a synthetic 3-project, 12-flag scenario:

```json
{
  "cycle": {"id": "abc", "name": "Week 17"},
  "audit_cards": [
    {"project_name": "A", "quality_gate_flags": [
      {"issue_id": "BC-1", "check": "done_with_evidence", "message": "..."},
      {"issue_id": "BC-2", "check": "done_with_evidence", "message": "..."},
      {"issue_id": "BC-3", "check": "done_with_evidence", "message": "..."},
      {"issue_id": "BC-4", "check": "title_clarity",      "message": "..."},
      {"issue_id": "BC-5", "check": "title_clarity",      "message": "..."}
    ]},
    {"project_name": "B", "quality_gate_flags": [
      {"issue_id": "BC-6", "check": "done_with_evidence", "message": "..."},
      {"issue_id": "BC-7", "check": "done_with_evidence", "message": "..."},
      {"issue_id": "BC-8", "check": "done_with_evidence", "message": "..."},
      {"issue_id": "BC-9", "check": "done_with_evidence", "message": "..."}
    ]},
    {"project_name": "C", "quality_gate_flags": [
      {"issue_id": "BC-10", "check": "ac_present",   "message": "..."},
      {"issue_id": "BC-11", "check": "ac_present",   "message": "..."},
      {"issue_id": "BC-12", "check": "title_clarity", "message": "..."}
    ]}
  ]
}
```

12 flags total → triggers >10 aggregation path. Apply the renderer rules:

- Top-3 projects by absolute flag count: **A (5), B (4), C (3)** — alphabetical ties moot.
- Top-3 check types: **done_with_evidence (7), title_clarity (3), ac_present (2)** — alphabetical ties moot.
- Expected render: `12 flags total; highest density in A (5), B (4), C (3); by check: done_with_evidence (7), title_clarity (3), ac_present (2). Full records in audit.json.`

If the rendering rule traces cleanly against the post-fix field names, Task 2 is verified. Paste both the synthetic input and the expected render into the plan-doc Verify section. No test runner — this is spec discipline.

### Task 4 — Validate + ship

1. Run `./scripts/validate.sh` from the worktree.
2. Run `./scripts/check-guardrails.sh --claude-md plugins/cadence/CLAUDE.md` if it covers the cadence sub-CLAUDE.md.
3. Bump `plugins/cadence/.claude-plugin/plugin.json` version (0.5.4 → 0.5.5) AND `.claude-plugin/marketplace.json` cadence entry to match (BC-6000 same-commit rule).
4. Commit + open PR. The 4 ACs from the issue:
   - [x] Subagent emits full `quality_gate_flags` list (Task 1 spec tightening).
   - [x] Seeded run confirms persisted shape matches `agents/project-audit.md:42` (Task 3 paste-and-trace).
   - [x] BC-5870 § 1.6 aggregation renders both per-project density AND per-check breakdown (Task 2 + Task 3 trace).
   - [x] If `quality_gate_flags_count` retained → schema declares it; if dropped → consumers updated. (Plan recommends drop; no consumers reference it.)

## Risks & non-risks

- **Not a runtime test.** This fix is spec-side. We cannot prove the agent will obey the tightened spec without a real Phase 1 dispatch — that confirmation falls to the BC-5874 third dogfood, where audit.json is inspected post-Phase 1.
- **No state-schema lockstep needed.** `commands/weekly.md § Session State Object` does not declare `quality_gate_flags` or `quality_gate_flags_count` — the field lives inside `audit_card` objects and is governed by `agents/project-audit.md`'s Output block. So this is a single-spec-site fix on the agent side + a single renderer-site fix on the command side.
- **Drop vs keep `_count`.** Recommend drop. If user prefers keep, Task 1's prohibition flips to a declaration (`"quality_gate_flags_count": <int>` added to schema with a "convenience parallel — derivable as `quality_gate_flags.length`" note). Asked at execution start.

## Verify (filled at execute)

### Decision recorded

`quality_gate_flags_count` **dropped** (user pick, 2026-04-26). Schema declares the array only; both Step 5 prose and post-schema note explicitly forbid the count-only / summary forms.

### Edits landed

1. `plugins/cadence/agents/project-audit.md`:
   - **Step 5 (line 28)** — rewrite makes the imperative explicit: emit the full `{issue_id, check, message}` object, name the consumers (`§ 1.6` renderer + `sprint-scoping/SKILL.md § 25`), prohibit `quality_gate_flags_count` and other count-only / aggregate / summary forms. Empty case: `quality_gate_flags: []`.
   - **Output schema (line 42)** — placeholder shape replaced with a 2-entry populated example (`BC-1234`, `BC-1235`) so the model has a concrete pattern. Post-schema note forbids `quality_gate_flags_count`, `quality_gate_flags_summary`, and any count-only / aggregate convenience field, citing BC-6052 against W17's audit.json.
2. `plugins/cadence/commands/weekly.md` § 1.6:
   - **Line 298** — `audit_cards[].flags[]` → `audit_cards[].quality_gate_flags[]`; `flag.check` → `quality_gate_flag.check`. Closing sentence cites the canonical schema source and forbids reader fallback to `flags` or `quality_gate_flags_count`.

### Field-name grep verification

```
$ grep -n 'quality_gate_flags_count' plugins/cadence/agents/project-audit.md
28: ... — do NOT replace the array with a `quality_gate_flags_count` integer ...
50: ... Do not emit `quality_gate_flags_count`, `quality_gate_flags_summary` ...
```
Both matches are prohibitions, not schema declarations. ✓

```
$ grep -n 'audit_cards\[\]\.flags\[\]' plugins/cadence/commands/weekly.md
(no matches)
$ grep -nE '[^_]flag\.check' plugins/cadence/commands/weekly.md
(no matches)
```
Bare `flags[]` and bare `flag.check` are gone. ✓

### Synthetic 12-flag trace

Input (3 projects, 12 flags):

| Project | Flags | Breakdown |
|---|---|---|
| A | 5 | 3 × done_with_evidence, 2 × title_clarity |
| B | 4 | 4 × done_with_evidence |
| C | 3 | 2 × ac_present, 1 × title_clarity |

Total: 12 → triggers `>10 flags total` aggregation path.

Renderer trace against post-fix § 1.6:

- **Top-3 projects by absolute flag count across `audit_cards[].quality_gate_flags[]`:** A (5), B (4), C (3). No ties; alphabetical tiebreaker not exercised.
- **Top-3 check types over `quality_gate_flag.check`:**
  - `done_with_evidence`: 3 (A) + 4 (B) + 0 (C) = **7**
  - `title_clarity`: 2 (A) + 0 (B) + 1 (C) = **3**
  - `ac_present`: 0 (A) + 0 (B) + 2 (C) = **2**
  → ranking: `done_with_evidence (7), title_clarity (3), ac_present (2)`.

Expected render:

> `12 flags total; highest density in A (5), B (4), C (3); by check: done_with_evidence (7), title_clarity (3), ac_present (2). Full records in audit.json.`

Both ranking branches resolve cleanly against the post-fix field names. The pre-fix `audit_cards[].flags[]` reference would have evaluated to `undefined` against any spec-compliant audit_card and degraded the entire rendering, not just the breakdown — confirming the renderer fix is load-bearing alongside the agent-spec fix.

### Acceptance-criteria walk

| AC | Evidence |
|---|---|
| Subagent emits full `quality_gate_flags` list, no card silently `[]` when flags exist | `agents/project-audit.md` Step 5 imperative + Output post-schema prohibition (lines 28, 50) |
| Seeded run confirms persisted shape matches `agents/project-audit.md:42` | Schema example now populated; `commands/weekly.md § 1.5` write-through unchanged so the agent shape lands directly in `audit.json` |
| Re-running Phase 1 produces audit.json where BC-5870 § 1.6 aggregation renders both per-project density AND per-check breakdown | Synthetic 12-flag trace above; renderer reads correct field names post-fix |
| If `quality_gate_flags_count` retained → declared in schema; if dropped → consumers updated in lockstep | **Dropped.** No consumer references it (grep across `plugins/cadence/**` returned only the new prohibitions). State schema in `commands/weekly.md § Session State Object` does not declare it. ✓ |

### Live-runtime confirmation deferred

This fix is spec-side. The agent obeying the tightened spec is unverifiable here — that confirmation falls to the BC-5874 third dogfood (W18+), where Phase 1 audit.json is inspected post-dispatch. Plan AC #3 is met spec-wise; runtime obedience is a BC-5874 concern.

