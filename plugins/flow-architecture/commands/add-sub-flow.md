---
description: Incremental-add Flow-Driven Architecture orchestrator (sub-flow) — 5 phases / 2 gates / skips flow-journey-author per Q47 sub-decision 5.5 lock
---

<!-- eval-waiver: Lightest FDA orchestrator: adds one sub-flow under an existing domain by dispatching flow-inventory-add plus flow-linear-scaffold and emitting a journey-staleness warning; output is AI-authored Linear scaffold plus a story doc, with no deterministic fixed-answer artifact separable from LLM narration. -->

# /flow:add-sub-flow

Lightest FDA orchestrator. Adds a single new sub-flow under an existing domain. Runs **5 phases / 2 user-confirmation gates** per Q47 lock (`plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:743`): Phase 3 mirrors the sibling greenfield Phase-4 per-domain inner loop with N=1; Phases 4-5 are globally batched with N=1 (degenerate but consistent with the Q37 sibling shape). Wall ≈ 3-5 min on a typical sub-flow add. See § Architecture overview for the journey-author skip and journey-staleness warning that differentiate this command from `/flow:add-domain`.

> **Scope:** UI-bearing builds only (CDR-023 partition). Non-UI-bearing work uses CDR-014's Phase Pattern, not FDA. `flow-preflight` performs upstream mode classification — `/flow:add-sub-flow` runs only when mode resolves to `incremental-add`.

> **DO NOT re-derive** the phase sequence, gate count + labels (`Q20.6`, `Q13.4` — NOT `G1`/`G2`), positional-arg form mapping (`no-arg` / `TEAM` / `TEAM-09`), journey-staleness warning text, or per-phase failure matrix below. All seven sub-decisions are locked at memory:743+ with a refinement audit trail at memory:780. Re-litigation already resolved at lock time. The journey-staleness warning sentence is **user-locked verbatim** (per Q47 sub-decision 5.5, memory:771-773) — word-for-word preservation is the most load-bearing constraint in this command.

## Architecture overview

```
  /flow:add-sub-flow (incremental-add) — 5 phases / 2 gates
  ═══════════════════════════════════════════════════════════════════

   ┌─ Phase 1 ─┐    ┌─ Phase 2 ─┐ Q20.6 ┌─ Phase 3 ─┐ Q13.4 ┌─ Phase 4 ─┐    ┌─ Phase 5 ─┐
   │ preflight │───►│  inventory│──────►│  linear-  │──────►│  doc-     │───►│  regen-   │
   │ bootstrap │    │   append  │       │  scaffold │       │  author   │    │   index   │
   │   (Q12)   │    │   (Q20)   │       │   (Q13)   │       │   (Q15)   │    │   (Q18)   │
   └───────────┘    └─────┬─────┘       └─────┬─────┘       └───────────┘    └─────┬─────┘
   mode=                  ↓ within-skill      ↓ L3 review                          ↓
   incremental-add        gate (Q20.6 owns)   → parent issue                  Journey-staleness
                          → row appended      (5 disciplines                  warning emitted
                          + H3 count bump     parallel; before                (Q47 sub-decision 5.5
                                              Q13.4 preview)                  verbatim text)
                                                                              status: completed
```

> **Diagram note.** The `Q20.6` and `Q13.4` arrow labels above mark **within-skill gates** owned by the named sub-skill — they fire inside Phase 2 (Q20.6) and Phase 3 (Q13.4), not at the inter-phase boundary the horizontal arrow visually suggests. See § The 2 user gates for the full within-skill semantics. The visual placement is for layout only; the authoritative source is the gate descriptions in § The 2 user gates.

**SKIPS `flow-journey-author`** (Q16) per Q47 sub-decision 5.5 (user-locked 2026-05-07) — the verbatim journey-staleness warning is emitted at Phase 5 completion instead. THE substantive differentiator from `/flow:add-domain` (which runs the 6-phase variant with journey-author).

**SKIPS `flow-legacy-cross-reference`** (Q14) per Q47 sub-decision 2 — incremental-add isn't a retrofit operation.

> **Gate labeling note.** Both gates are within-skill and labeled by their sub-skill locks per Q47 sub-decision 5 (memory:769): **Q20.6** lives inside `flow-inventory-add`; **Q13.4** lives inside `flow-linear-scaffold`. Sibling commands `/flow:start-project` and `/flow:retrofit-project` use orchestrator-budget gate numbering (`G1`-`G4`, `G1`-`G5`) because Q10 (memory:48) is mode-aware on retrofit/greenfield budgets and silent on incremental-add. Q47 derives the incremental-add gate count from the underlying sub-skill locks instead (memory:787 confirmation).

## Invocation

`/flow:add-sub-flow [<DOMAIN>|<DOMAIN-NN>] [--title=<text>] [--force-incremental-add] [--resume]`

Three positional-arg forms per Q47 sub-decision 1 (memory:746) — each maps to Q20.1's input contract (Q20 takes target domain as INPUT, auto-suggests flow_id NN per Q20.2):

| Form | Example | Behavior |
|---|---|---|
| `no-arg` | `/flow:add-sub-flow` | Q20 prompts for target domain interactively; once selected, auto-suggests next `<DOMAIN>-(N+1)` flow_id per Q20.2 |
| `TEAM` (bare domain) | `/flow:add-sub-flow TEAM` | Pre-fills domain as `TEAM`; Q20.2 auto-suggests next `TEAM-(N+1)` flow_id |
| `TEAM-09` (domain-NN) | `/flow:add-sub-flow TEAM-09` | Pre-fills domain `TEAM` + flow_id `TEAM-09`; Q20.4 hard-rejects if duplicate |

Optional `--title=<text>` flag pre-fills the title prompt in any form.

**Positional-arg validation (defense-in-depth, parallel to retrofit-project.md BC-6963 `87d5886` slug-halt precedent).** Before dispatching to `flow-inventory-add`, the orchestrator validates positional args at the trust boundary:

- `<DOMAIN>` form must match `^[A-Z][A-Z0-9_]*$` (uppercase Linear-team-style slug; admits `TEAM`, `BC`, `AUTH_FLOWS`).
- `<DOMAIN-NN>` form must match `^[A-Z][A-Z0-9_]*-[0-9]{2}(-[a-z])?$` (uppercase slug + 2-digit suffix + optional `-a`/`-b` split-suffix per Q20.2 split-suffix support).
- Halt-on-fail with a clear error: `"Invalid positional arg <value>: expected <DOMAIN> form ^[A-Z][A-Z0-9_]*$ or <DOMAIN-NN> form ^[A-Z][A-Z0-9_]*-[0-9]{2}(-[a-z])?$"`. Path-traversal and command-injection slugs are rejected here rather than relying on downstream Q20 H3-header regex + Q20.4 duplicate-hard-reject (defense-in-depth — the orchestrator boundary is the same layer where sibling orchestrators codify input validation).
- `--title=<text>` value is treated as **opaque content** by the orchestrator — captured into `state.target_sub_flow_title` and passed verbatim to Q20's template-fill prompt. Never `echo`-ed, `eval`-ed, backtick-spliced, or shell-interpolated. Downstream sub-skills (Q20 inventory row write, Q23 parent-issue body render) MUST handle the title via `printf "%s"` / python3 stdin only.

`--force-incremental-add` flag (Q47 sub-decision 3): bypasses the preflight mode-classifier check; surfaces a warning + writes an audit-log entry to the breadcrumb. Auto-redirect (silently running the recommended command instead of erroring) was rejected at lock time as too magical.

`--resume` is documented for symmetry with sibling orchestrators; in practice the resume entry runs through `flow-preflight` (`MODE=resume`) and dispatches at `breadcrumb.current_phase` — see § Resume contract.

## Mode classifier integration

`flow-preflight` MUST emit `MODE=incremental-add` for this command to proceed. Error redirects per Q47 sub-decision 3 (memory:756-762) — surface the recommended command but **do NOT auto-run** it:

- `MODE=greenfield` (no FDA artifacts present) — error:
  > "Project not yet initialized. Use `/flow:start-project` first."
- `MODE=retrofit` (FDA artifacts absent + ≥10 Linear issues per Q36.3 step 4) — error:
  > "Project has legacy work. Use `/flow:retrofit-project` to retrofit FDA shape, then `/flow:add-*` for incremental additions."
- `MODE=resume` (breadcrumb `in_flight` and non-stale) — three actionable options per memory:759:
  - (a) resume via re-invocation of the original orchestrator (preflight will detect `mode=resume` and dispatch at `current_phase`);
  - (b) manually discard by deleting `docs/plans/.flow-phase-state.json`;
  - (c) wait until breadcrumb auto-stales (>7 days inactive per Q31.3) for `AskUserQuestion`-driven discard. Stale-breadcrumb auto-discard only fires after 7 days OR `status=completed|abandoned` per Q31.3 — does not apply to fresh `in_flight` breadcrumbs.
- `MODE=incremental-add` — proceed.

## Breadcrumb

The orchestrator writes phase progress to `docs/plans/.flow-phase-state.json` (Q31.4 lock — **leading dot** on the filename; NOT `.flow/phase-state.json`) after every phase completion. Writes go through `bash $CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh write <state-path> <input-path>` (BC-6956 shipped; BC-9027 file-arg refactor) — atomic-rename via mktemp + python3 json.dump + parse-verify + content-match per Q31.5 lock. Never write the breadcrumb file directly with a heredoc.

Breadcrumb shape (per Q31.4 + Q47 sub-decision 6 simplification — the `last_updated` field name is load-bearing: `scripts/flow-resume-breadcrumb.sh read` keys on it for stale detection, so writing `updated_at` would silently skip staleness checks):

```json
{
  "version": "1",
  "mode": "incremental-add",
  "linear_project_id": "<uuid from .flow/config.json>",
  "linear_project_name": "<string from .flow/config.json>",
  "linear_team_key": "<e.g., BC>",
  "run_started_at": "<ISO-8601; set once at Phase 1 entry>",
  "current_phase": "1|2|3|4|5",
  "completed_phases": ["1", "2", ...],
  "domains": [
    {
      "slug": "<existing-domain-slug>",
      "scaffold_state": "pending|in_progress|completed|failed",
      "failure_reason": null,
      "parent_issue_ids": [],
      "new_sub_flow_id": "<DOMAIN-NN>"
    }
  ],
  "status": "in_flight",
  "last_updated": "<ISO-8601 refreshed each write>"
}
```

`status` transitions: `in_flight` (set at Phase 1 entry) → `completed` (Phase 5 terminator) OR `abandoned` (user halt at any gate OR Q20.4 duplicate hard-reject in Phase 2 per Q47 sub-decision 7 + user lock 2026-05-07).

The `domains[]` array always has exactly one entry — the existing domain receiving the new sub-flow. The `new_sub_flow_id` field on that entry tags which `<DOMAIN-NN>` is being added (used by the journey-staleness warning interpolation at Phase 5).

**Schema note on `new_sub_flow_id`.** The `new_sub_flow_id` field on `domains[0]` is an incremental-add-specific extension to the canonical Q31.4 `domains[]` entry shape (siblings `start-project.md` and `retrofit-project.md` use the 4-field shape `{slug, scaffold_state, failure_reason, parent_issue_ids}`). The extension is admissible under Q31.7 forward-tolerance ("v1.x reader is forward-tolerant within major — ignores unknown fields"); a Q31 amendment formalizing the field as part of the incremental-add breadcrumb is a v1.1 candidate. The orchestrator carries the extension in v1 to drive the Phase 5.2 journey-staleness warning interpolation without re-probing inventory at completion time.

**Single-orchestrator-at-a-time per Q31.6 v1**: concurrent `/flow:add-*` + `/flow:start-project` not supported in v1 — breadcrumb is per-repo, not per-run.

## Resume contract

`flow-preflight` is the entry — every orchestrator dispatches through it. When preflight detects an in-flight non-stale breadcrumb with `mode: incremental-add`, it returns `MODE=resume` and the orchestrator dispatches at `current_phase`:

| Resume phase | Behavior |
|---|---|
| 1 | re-run Phase 1 (preflight + bootstrap is idempotent). |
| 2 | re-invoke `flow-inventory-add` with the stored `target_domain` + `target_sub_flow_id` + `title`. Q20.4 idempotency will hard-reject if the row already landed; if so, the breadcrumb is updated to `current_phase: 3` and the orchestrator advances. |
| 3 | re-invoke `flow-linear-scaffold` for the single sub-flow. Q13.5 sub-flow-atomic semantics apply — completed writes are not re-applied; missing writes are filled in. L3 review state not persisted (re-runs per parking lot #31 v1). |
| 4 | re-run Phase 4 (`flow-doc-author` for the single sub-flow). Q15's skip-if-exists per Q15.3 keeps an already-written story doc from being clobbered without `--force`. |
| 5 | re-run Phase 5 — INDEX regen is idempotent; journey-staleness warning is re-emitted. |

Stale breadcrumb handling (>7 days, or `status: completed | abandoned`, or malformed) lives inside `flow-preflight` Section 3.1 and prompts the user via `AskUserQuestion` to discard / force-resume / cancel. Orchestrator does not re-implement that policy.

## L-review routing

L-review routing for `/flow:add-sub-flow` is fully determined by artifact scope — incremental-add does not touch project-scope or domain-scope artifacts, so only L3 fires. (Q47 sub-decision 4 boundary holds: L-review routing per artifact scope is a Q23/Q26/Q54 concern, not Q47's responsibility.) Concretely:

| Level | Phase | Where it fires | Output target | Notes |
|---|---|---|---|---|
| L1 review | — | not fired | — | `intent.md` is not re-authored in incremental-add. |
| L2 review | — | not fired | — | Journey doc is not re-authored — the journey-staleness warning is the explicit substitute. |
| **L3 review** | 3 | inside `flow-linear-scaffold` BEFORE the Q13.4 preview gate — all 5 disciplines (Story + Eng + Design + QA + Docs) parallel | Linear parent issue `## L3 review summary` section per Q23 mod 2; headlines visible in Q13.4 preview | fires for the single new sub-flow (N=1) |
| L4 review | n/a | JIT during `/flow:session-start` Step 5 — not orchestrator-driven |  — |  |

L3 review state is **in-memory only** during single invocation per parking lot #31 v1. On crash-resume, L3 re-runs when Phase 3 re-runs.

## Session state object

Phases flow via a single session-scoped state object. No re-fetching from filesystem or Linear between phases unless explicitly re-probed.

```
{
  "mode":                  "incremental-add",
  "linear_project_id":     "<uuid>",
  "linear_project_name":   "<string>",
  "linear_team_key":       "<e.g., BC>",
  "repo_root":             "<absolute path>",
  "run_started_at":        "<ISO-8601>",
  "current_phase":         "1..5",
  "completed_phases":      [...],
  "preamble":              { ...10 KEY=VALUE fields from flow-preflight Section 5 },
  "inventory_path":        "docs/product/master-flow-inventory.md",
  "target_domain":         "<DOMAIN slug — captured from positional arg or Q20 interactive prompt>",
  "target_sub_flow_id":    "<DOMAIN-NN — captured from positional arg, Q20.2 auto-suggestion, or user override>",
  "target_sub_flow_title": "<title — captured from --title flag or Q20 prompt>",
  "inventory_changed":     false,
  "domains":               [ { "slug", "scaffold_state", "failure_reason", "parent_issue_ids": [...], "new_sub_flow_id" } ],
  "l3_review":             { "<sub-flow-id>": "<in-memory blob>" },
  "ship_artifacts":        { "story_doc": "<path>", "index_path": "<path>" },
  "status":                "in_flight"
}
```

This object is **session-scoped**. The breadcrumb is the persistent projection — `current_phase`, `completed_phases[]`, `domains[]`, `run_started_at`, `status`. L3 review state is not breadcrumb-persisted (parking lot #31 v1). `inventory_changed` flips to `true` when Q20 emits the Q20.7 flag at the end of Phase 2 — Phase 5 reads it to decide whether `flow-regen-index` has new rows to render.

## The 2 user gates (Q47 sub-decision 5)

Both gates are **within-skill** — the orchestrator does not fire its own `AskUserQuestion` for either gate; the sub-skill owns the prompt. The orchestrator's responsibility is to honor the gate outcome (Approve / Edit / Cancel) per the Gate-respect contract section below.

- **`Q20.6`** (Phase 2 internal — `flow-inventory-add` within-skill confirmation per Q20 lock memory:236):
  > "Add `<DOMAIN-NN>: <title>` under `<DOMAIN>` section as flow #`<N>`? Notes: `<notes>`. Approve / Edit / Cancel"

  Owned by Q20; fires inside the sub-skill, NOT the orchestrator. On Approve → inventory row is appended + H3 flow-count is bumped. On Edit → re-prompt with current values pre-filled. On Cancel → no write; orchestrator writes breadcrumb `status: abandoned`.

- **`Q13.4`** (Phase 3 internal — `flow-linear-scaffold` pre-scaffold preview per Q13 lock memory:88; Q47 amendment 1 corrects the Q47 sub-decision 5 propagated `memory:70` citation typo for Q13.4):

  Reviews the **8 planned Linear writes** (1 parent + 5 children + 1 children-summary comment + 1 milestone description refresh) for the single new sub-flow per Q47 sub-decision 2 + Q47 amendment 1 (arithmetic correction from `= 7 writes` to `= 8 writes`; Q13 lock per-domain formula `2 + 7N` minus the milestone-create that doesn't apply to incremental-add against an existing domain = `7×1 + 1 milestone refresh = 8` writes). Fires **regardless of N=1** (no trivial-preview suppression per Q47 refinement 2, memory:783). L3 review headlines from inside Q13 are already populated in the parent issue's `## L3 review summary` at preview time so the user sees discipline-grade signal before authorizing the writes.

Q20.6 + Q13.4 do **NOT collapse** — they serve different review purposes (inventory content vs Linear scaffold preview); the user can edit between them.

## Per-phase failure matrix (Q47 sub-decision 7 — verbatim from memory:778)

| Phase | Failure semantics |
|---|---|
| 1 | preflight fail-closed per Q36.5. No partial `.flow/config.json` on disk — atomic-rename guarantees absent-or-complete. |
| 2 | Q20 hard-reject on duplicate per Q20.4: write breadcrumb at phase 2 entry → on hard-reject, mark `status: abandoned` with `reason: 'duplicate detected (Q20.4)'` for audit trail (per user lock 2026-05-07). Consistent with Q31 lifecycle (Q31.3 accommodates abandoned status — future preflight offers discard); diverges from Q36.5's "no partial state" (which applies to bootstrap config-json, NOT breadcrumbs — different concerns). |
| 3 | per Q13.5 sub-flow-atomic recovery — transient retry / permanent abort + `AskUserQuestion`. With N=1 this collapses to a single retry/abort decision. |
| 4 | per Q15.5 log + continue. Single-doc failure surfaces in batch summary. Orchestrator does NOT roll back since outputs are filesystem writes reviewable via `git diff` + `verify-docs.sh`. |
| 5 | per Q18.7 skip-row + marker. INDEX renders a "regen-failed: `<reason>`" row instead of clobbering with a partial INDEX. Journey-staleness warning is still emitted (orchestrator-owned text, not gated on `flow-regen-index` success). |
| user halt at any gate | breadcrumb `status: abandoned`; future `/flow:add-sub-flow` invocation detects abandoned + offers discard per Q31.3 stale-breadcrumb policy. (Q31.1 lock reserves the `reason` field for `overrides[]` entries — Q29.5 hard-gate decisions, not user-cancel attribution; do not add a top-level `reason` field without a Q31 amendment + audit trail.) |

---

## Phase 1: preflight + bootstrap

**Sub-skill:** `flow-preflight` (Q12 + Q36 embedded 7-step bootstrap; BC-6957 shipped at `plugins/flow-architecture/skills/flow-preflight/SKILL.md`).

**Pre-flow-preflight setup:** the orchestrator owns the `LINEAR_ISSUE_COUNT` env-var per `flow-preflight` Section 6.4 ownership note. Before dispatching the skill:

1. Call the Linear MCP `mcp__plugin_workflows_linear-server__list_issues` with `{project: <candidate project_id from .flow/config.json>, limit: 10}`.
2. Count the returned items as an integer (0–10).
3. `export LINEAR_ISSUE_COUNT=<integer>` so `flow-preflight` Section 6.4 picks it up.

Treat the captured integer as data only — never interpolate any Linear-derived field (issue titles, project name, descriptions) into a shell expression, `bash -c`, `eval`, or unquoted `$(...)`. Only the integer count crosses into env. The MCP call is the trust boundary; values from the MCP response stay inside the LLM context, never inside a shell pipeline.

The `limit: 10` cap aligns with Q36.3 step-4's threshold-IS-the-cap semantics — a returned count of exactly 10 means "≥ 10" (no pagination needed). For `/flow:add-sub-flow`, the `.flow/config.json` is expected to exist (incremental-add precondition); if absent, preflight will surface the missing-config error before the mode-classifier check fires.

**Run:** dispatch `flow-preflight` inline (skill is `disable-model-invocation: true`, `user-invocable: false` — orchestrators call directly).

`flow-preflight` runs its 5 environment checks (Section 1), FDA-artifact discovery (Section 2), mode classification (Section 3), Linear scope confirmation (Section 4), preamble emission (Section 5), and on first-run the Q36 7-step bootstrap (Section 6) — though for `/flow:add-sub-flow`, the bootstrap should already be complete (incremental-add precondition).

**Mode guard:** if `flow-preflight` emits `MODE != incremental-add`, surface the error redirect per Q47 sub-decision 3 (see § Mode classifier integration above) and STOP. Honor `--force-incremental-add` if passed: skip the mode-guard hard-stop, surface a warning, and append an audit-log entry to the breadcrumb's `overrides[]` per Q29.5.

**Capture from preamble** (10 KEY=VALUE fields per `flow-preflight` Section 5):

- `LINEAR_PROJECT_ID`, `LINEAR_PROJECT_NAME`, `LINEAR_TEAM_KEY` (derived from `.flow/config.json`)
- `REPO_ROOT`
- `INTENT_EXISTS`, `INVENTORY_EXISTS`, `FLOWS_DIR_EXISTS`, `BREADCRUMB_EXISTS` (all expected `yes` for incremental-add)
- `GH_AUTH`, `LINEAR_MCP`

**Initial breadcrumb write:** at end of Phase 1, write the breadcrumb with `run_started_at` (ISO-8601 now), `current_phase: 2`, `completed_phases: ["1"]`, `mode: incremental-add`, `status: in_flight`, empty `domains: []` (populated by Phase 2 once the user picks the target domain).

The helper script `flow-resume-breadcrumb.sh write <state-path> <input-path>` reads the full JSON document from `<input-path>` (per BC-6956 contract as amended by BC-9027; it does **not** take `--mode` / `--current-phase` / `--status` flags and no longer reads from stdin). Construct the JSON via python3 (stdlib only per Q32), redirect into a `mktemp` file, then call the helper with both paths:

```bash
BREADCRUMB_PATH="$REPO_ROOT/docs/plans/.flow-phase-state.json"
TMP_JSON="$(mktemp -t flow-breadcrumb.XXXXXX)"
python3 > "$TMP_JSON" <<'PY'
import json, sys, datetime
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump({
    "version": "1",
    "mode": "incremental-add",
    "status": "in_flight",
    "run_started_at": now,
    "last_updated": now,
    "current_phase": "2",
    "completed_phases": ["1"],
    "domains": [],
}, sys.stdout)
PY
bash "$CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh" write "$BREADCRUMB_PATH" "$TMP_JSON"
rm -f "$TMP_JSON"
```

The `<<'PY'` heredoc is single-quoted to disable shell expansion of the python body. The `mktemp` file intermediate is the BC-9027 fix: the previous pattern `python3 <<'PY' | bash $HELPER write ...` tripped the workflows security-hook classifier as a "piped download/execution" false-positive. Routing through `$TMP_JSON` keeps the helper-call as a plain argv invocation. See § Phase-exit breadcrumb update for the discrete-argument + single-quoted-heredoc + file-intermediate discipline that applies to every subsequent breadcrumb write in this orchestrator.

**No user gate after Phase 1.** Q47 sub-decision 5 locks both gates as within-skill (Q20.6 + Q13.4); Phase 1's only failure path is `flow-preflight`'s own fail-closed surface per Q36.5.

**Failure semantics (Phase 1):** fail-closed per Q36.5. No partial `.flow/config.json`. Any failure inside `flow-preflight` surfaces verbatim with the remediation hint preflight emitted.

---

## Phase 2: inventory append (sub-flow-add mode) — gate Q20.6

**Sub-skill:** `flow-inventory-add` (Q20; not yet shipped — orchestrator references by name).

**Inputs handed to the sub-skill:**

- `mode: sub-flow-add` — dispatches the lighter mode per Q20 sub-decision 1 (memory:226).
- `target_domain`: resolved from positional arg (`TEAM` or `TEAM-09` form) OR Q20 interactive prompt (no-arg form). Captured into `state.target_domain`.
- `target_sub_flow_id`: optional — pre-filled in the `TEAM-09` form; otherwise Q20.2 auto-suggests `<DOMAIN>-(N+1)` after Q20 parses target domain rows to find the highest existing `<DOMAIN>-NN`.
- `title`: optional — pre-filled from `--title=<text>` flag; otherwise prompted inside Q20.
- Other Q20 sub-flow-add inputs (primary persona, related_flows, Notes) collected by Q20's template-fill prompt.

**Pre-write breadcrumb stub:** before invoking the sub-skill, write a breadcrumb following the canonical § Phase-exit breadcrumb update pattern. The helper script reads `<input-path>` as a **complete** JSON document — it does NOT merge with the on-disk state — so the python3 heredoc MUST include every canonical field. Specifically: preserve `version`, `mode: incremental-add`, `linear_project_id`, `linear_project_name`, `linear_team_key`, `run_started_at`, and `status: in_flight` from the Phase 1 write; set `current_phase: 2`, `completed_phases: ["1"]`, `last_updated: <now>`; and populate `domains[0]` with `{slug: <target_domain>, scaffold_state: "pending", failure_reason: null, parent_issue_ids: [], new_sub_flow_id: <target_sub_flow_id-if-known>}`. This ensures a Q20.4 duplicate hard-reject (see failure semantics below) has a complete-schema breadcrumb to mark `abandoned` against.

**Run:** dispatch `flow-inventory-add`. The sub-skill:

1. Parses `docs/product/master-flow-inventory.md` to locate target domain section by H3 header `^### <DOMAIN> — .* \(\d+ flows\)$` per Q20 sub-decision 3 (memory:230).
2. If `target_sub_flow_id` is empty, computes Q20.2 auto-suggestion `<DOMAIN>-(N+1)` (2-digit zero-padded).
3. Fires the **Q20.6 within-skill confirmation gate**:

   > "Add `<DOMAIN-NN>: <title>` under `<DOMAIN>` section as flow #`<N>`? Notes: `<notes>`. Approve / Edit / Cancel"

   The orchestrator does NOT fire this `AskUserQuestion` itself — Q20 owns the prompt.
4. On Approve → appends the inventory row before the table terminator + bumps the H3 heading flow count + atomic-rename writes `master-flow-inventory.md`.
5. On Edit → re-prompts the relevant Q20 fields with current values pre-filled, then re-fires Q20.6.
6. On Cancel → no write; orchestrator writes breadcrumb `status: abandoned` + exits cleanly.
7. Emits Q20.7 `state.inventory_changed = true` flag — orchestrator captures into `state.inventory_changed` for Phase 5 INDEX regen trigger.

**Capture into state:** `state.target_domain` (final), `state.target_sub_flow_id` (final), `state.target_sub_flow_title` (final), `state.inventory_changed = true`, `state.domains[0].new_sub_flow_id`.

**Breadcrumb update at end of Phase 2:** `current_phase: 3`, `completed_phases: ["1", "2"]`, `domains[0].scaffold_state: "pending"` (Phase 3 will flip to `in_progress` → `completed`).

**Failure semantics (Phase 2):** Q20 hard-reject on duplicate per Q20.4 (memory:232). If proposed `<DOMAIN-NN>` already exists, Q20 surfaces a clear error citing line number + suggesting split-suffix (`<DOMAIN>-NN-a` / `-b` per Q20.2 split-suffix support) or next sequential + aborts.

Per Q47 sub-decision 7 + user lock 2026-05-07: on Q20.4 hard-reject, write breadcrumb `status: abandoned` with `reason: 'duplicate detected (Q20.4)'` for audit trail. (Note: the `reason` field referenced here is on the breadcrumb `overrides[]` entry pattern from Q29.5, not a top-level breadcrumb field — append a synthetic override row tagging the duplicate-detect event rather than adding a new top-level field. This preserves Q31.1's schema discipline.) Q31.3 stale-breadcrumb policy will offer discard naturally on the next `/flow:add-sub-flow` invocation.

Inventory parse failure (malformed table, missing target domain section) → Q20 aborts + surfaces line number; orchestrator does NOT auto-repair (would risk silent data loss per Q20 sub-decision 5).

User-cancel at Q20.6 → no write; clean exit; breadcrumb `status: abandoned` (top-level `status` change — no synthetic override row needed for user-cancel).

---

## Phase 3: linear scaffold (per-sub-flow, N=1) — gate Q13.4

**Sub-skill:** `flow-linear-scaffold` (Q13; not yet shipped — orchestrator references by name).

This phase mirrors the sibling greenfield Phase-4 per-domain inner loop degenerated to N=1. Q13.5's sub-flow-atomic failure recovery semantics + Q13.4's per-domain preview content apply unchanged — the only difference is the iteration count.

**Per-sub-flow footprint** (Q13 lock + Q47 sub-decision 2 explicit count, as corrected by Q47 amendment 1):

- 1 parent issue (the new sub-flow's parent)
- 5 discipline children (Story + Eng + Design + QA + Docs)
- 1 children-summary comment on the parent issue
- 1 milestone description refresh on the domain's existing milestone (adds the new sub-flow row to the Sub-flows table per Q22 schema)

Total: **8 Linear writes** for the single new sub-flow. (Q47 sub-decision 2 originally stated `= 7 writes`; Q47 amendment 1 — locked 2026-05-11 per BC-6965 /workflows:review iteration 1 fold-in — corrects the arithmetic to 8, consistent with Q13 lock's per-domain formula `2 + 7N` minus the not-applicable milestone-create for incremental-add against an existing domain = `7×1 + 1 refresh = 8`.)

### 3.1 L3 review fires INSIDE flow-linear-scaffold (before Q13.4 preview)

Per Q23 mod 2 (memory:515; as corrected by Q23 amendment 1, memory:517) + Q13 sub-decision 4 (memory:88) — all 5 disciplines (Story + Eng + Design + QA + Docs) fire in parallel for the single new sub-flow. Headlines populate the parent issue's `## L3 review summary` section **before** the Q13.4 preview gate so the preview shows L3 discipline signal for human review.

L3 review output is stashed in `state.l3_review[<sub-flow-id>]` for the duration of the orchestrator run. Not breadcrumb-persisted — on crash-resume, Phase 3 re-runs and re-fires L3 (parking lot #31 v1 acceptance).

### 3.2 Q13.4 pre-scaffold preview (gate)

After the L3 review fires + per-sub-flow preview content is computed, Q13 fires the **Q13.4 within-skill preview gate** showing the 8 planned Linear writes (per Q47 amendment 1; see § Per-sub-flow footprint above). The orchestrator does NOT fire this `AskUserQuestion` itself — Q13 owns the prompt. The preview content is computed deterministically from inventory + parent issue numbering (next available BC-NNNN per project) up front; user authorization at Q13.4 covers the single-sub-flow batch.

Q13.4 fires **regardless of N=1** per Q47 refinement 2 (memory:783) — there is no trivial-preview suppression at this lock; the gate is mandatory.

### 3.3 Execution with Q13.5 atomic recovery (N=1)

After Q13.4 approval, `flow-linear-scaffold` executes the 8 writes for the single sub-flow (per Q47 amendment 1). **Q13.5 sub-flow-atomic recovery applies:**

- On success: mark `breadcrumb.domains[0].scaffold_state = "completed"`, capture `parent_issue_ids` (single entry — the new parent), write breadcrumb.
- On failure: mark `breadcrumb.domains[0].scaffold_state = "failed"`, set `failure_reason`, write breadcrumb. Q13 surfaces an `AskUserQuestion`:

  > "Sub-flow `<DOMAIN-NN>` scaffold failed: `<reason>`. How should I proceed?"
  >
  > - **Retry this sub-flow** — re-invoke `flow-linear-scaffold` for `<DOMAIN-NN>`.
  > - **Abort Phase 3** — write `status: abandoned` to breadcrumb; exit cleanly. Any successful writes (e.g., parent created but children failed) remain on Linear and surface in the abandoned breadcrumb's audit trail.

With N=1, the "skip this and continue" option from the sibling greenfield Phase-4 inner loop collapses away — there is no "next pending sub-flow" to advance to. Per Q47 sub-decision 2 (sibling phase shape with N=1), this is degenerate-but-consistent.

**Breadcrumb update at end of Phase 3:** `current_phase: 4`, `completed_phases: ["1", "2", "3"]`, `domains[0].scaffold_state: "completed"` + `parent_issue_ids: ["<parent-id>"]`.

**Failure semantics (Phase 3):** per Q13.5 sub-flow-atomic recovery (memory:778 — Phase 3 in this orchestrator maps to the sibling Phase-4 sub-flow-atomic semantic). Q13 retry / abort `AskUserQuestion` honors the Gate-respect contract.

---

## Phase 4: doc author (single sub-flow)

**Sub-skill:** `flow-doc-author` (Q15; not yet shipped — orchestrator references by name).

This phase is **globally batched with N=1** — orchestrator invokes `flow-doc-author` ONCE with the single new sub-flow's record. Q15.2's per-sub-flow internal parallelism is moot at N=1 but consistent with the sibling greenfield Phase-5 contract.

**Pre-condition:** Phase 3 completed; `state.domains[0].scaffold_state == "completed"` with `parent_issue_ids` populated.

**Run:** dispatch `flow-doc-author` with the single sub-flow from `state.inventory.domains[<target>].sub_flows[<new>]` (filtered by `scaffold_state == "completed"`). The skill:

1. Reads `intent.md` + `master-flow-inventory.md` + the new sub-flow's parent issue (for L3 headlines + AC).
2. Writes story doc at `docs/product/flows/<target_domain>/<target_sub_flow_id>.md`.
3. Skip-if-exists per Q15.3: an existing story doc is preserved unless the user passes `--force` (escalated through the orchestrator's CLI flag handling).

See § Failure semantics below for the Q15.5 log+continue behavior — owned by that block to avoid restatement.

**Capture into state:** `state.ship_artifacts.story_doc = "docs/product/flows/<target_domain>/<target_sub_flow_id>.md"`.

**No gate.** Q15.6 locks 0 sync gates for Phase 4. The phase runs to completion (or partial-with-batch-summary) and dispatches to Phase 5.

**Breadcrumb update:** `current_phase: 5`, `completed_phases: ["1", "2", "3", "4"]`.

**Failure semantics (Phase 4):** log + continue per Q15.5. A partial Q15 failure surfaces in batch summary; outputs are filesystem writes reviewable via `git diff` + `verify-docs.sh`.

---

## Phase 5: regen index + journey-staleness warning

**Sub-skill:** `flow-regen-index` (Q18; not yet shipped — orchestrator references by name).

**Phase-5 has two ordered steps:** (1) INDEX regen via `flow-regen-index`; (2) journey-staleness warning emission. The warning is orchestrator-owned text, not part of `flow-regen-index`.

### 5.1 Invoke flow-regen-index

`state.inventory_changed = true` was set by Q20.7 at the end of Phase 2 — this is the Q47 sub-decision 4 boundary signal that `flow-regen-index` should run. Dispatch `flow-regen-index`. The skill regenerates `docs/product/flows/INDEX.md` from `master-flow-inventory.md` + per-domain story doc presence. Idempotent — re-running yields the same INDEX content for the same input.

**Capture into state:** `state.ship_artifacts.index_path = "docs/product/flows/INDEX.md"`.

**Failure semantics (5.1):** Q18.7 log + continue + skip-row marker. If the new sub-flow's INDEX row fails to render (e.g., story doc missing), INDEX includes a `regen-failed: <reason>` marker for that row rather than clobbering with a partial INDEX or omitting the row silently. The journey-staleness warning (step 5.2) still emits — its text does not depend on `flow-regen-index` success.

### 5.2 Journey-staleness warning (Q47 sub-decision 5.5 — VERBATIM)

Per Q47 sub-decision 5.5 lock at memory:771-773 (user-locked 2026-05-07): emit the following sentence at completion of Phase 5. The `<DOMAIN-NN>` and `<domain>` placeholders are interpolated from `state.target_sub_flow_id` and `state.target_domain` respectively; the rest of the text is **literal and word-for-word preserved**:

> "Sub-flow `<DOMAIN-NN>` added. Journey doc at `docs/product/journeys/<domain>.md` may need narrative refresh — the new sub-flow is in inventory + Linear + story doc but not yet woven into the journey narrative. Run `flow-journey-author --force` when ready (will regenerate from scratch; back up hand-edits first), or wait for v1.1 selective-re-author mode (parking lot #19)."

This sentence captures the known-stale state created by skipping `flow-journey-author` without forcing destructive `--force` regeneration. The v1.1 trajectory (selective-re-author + `/flow:journey-refresh`) is tracked in § See also via parking lot #19.

**This text is the most load-bearing constraint in this command.** The issue's AC has 5 separate grep anchors against the sentence (`Journey doc at`, `narrative refresh`, `inventory + Linear + story doc`, `flow-journey-author --force`, `parking lot #19`). Re-phrasing breaks the contract.

### 5.3 Phase 5 terminator + final breadcrumb write

After the warning emits, render a user-facing completion summary listing artifacts produced:

- `docs/product/master-flow-inventory.md` (1 row appended)
- `docs/product/flows/<target_domain>/<target_sub_flow_id>.md` (1 story doc)
- `docs/product/flows/INDEX.md` (regenerated)
- Linear: 1 parent + 5 children + 1 children-summary comment + 1 milestone description refresh = 8 writes per Q47 amendment 1 (list URLs)
- L-review coverage: L3 (1 invocation, parent issue) — L1 + L2 not fired (incremental-add scope)

**Final breadcrumb write:** `status: completed`, `current_phase: 5`, `completed_phases: ["1","2","3","4","5"]`. The Q31.5 atomic-rename write through `flow-resume-breadcrumb.sh write` is the **last operation** of the orchestrator — never write the `completed` marker before all artifacts land on disk (BC-5761 precedent applied here; BC-6962/BC-6963 sibling pattern).

Recommend next steps:

- Run `/flow:audit --domain=<target_domain>` (Q38; pending) for project-health snapshot scoped to the affected domain.
- Run `/flow:plan-<discipline>` per discipline child for AC + Tasks population.
- Address the journey-staleness warning emitted in step 5.2 above when ready (the warning text itself enumerates the available actions).

**Failure semantics (5.3):** n/a — terminator. Any failure prior to the final breadcrumb write leaves breadcrumb at Phase 4 or earlier; resume picks up appropriately.

---

## Gate-respect contract

Every `AskUserQuestion` in this command — the Q20.6 within-skill confirmation, the Q13.4 pre-scaffold preview, the per-sub-flow Phase 3 retry/abort adjudication, and the Phase 1 `--force-incremental-add` warning — is bound by the gate-respect contract (`plugins/flow-architecture/skills/_shared/gate-respect.md` once promoted; cf. cadence `skills/_shared/gate-respect.md`). Once the user picks an option, execute exactly that option. To deviate, re-prompt via a new `AskUserQuestion`. Mentions in the breadcrumb, notes, or batch summaries do NOT constitute user authorization.

Origin: cadence BC-5866 precedent surfaced this class-bug across orchestrators; same discipline applies here from day 1, consistent with sibling commands `/flow:start-project` (BC-6962) and `/flow:retrofit-project` (BC-6963).

## Phase-exit breadcrumb update (canonical pattern)

Every phase ends with a breadcrumb update so resume can reason about what's complete. Each phase ID (`1` through `5`) appends at the phase's terminal step:

1. Append the phase number to `breadcrumb.completed_phases` (in order).
2. Set `breadcrumb.current_phase` to the next phase number (or leave at `5` after Phase 5).
3. Set `breadcrumb.status` (`in_flight` until Phase 5 terminator; then `completed`).
4. Refresh `breadcrumb.last_updated` with the current ISO-8601 timestamp (**NOT `updated_at`** — the helper script's stale-detection in `read` mode keys on `last_updated`; writing the wrong field name would silently break staleness checks).
5. Persist via the BC-6956 helper. The helper `write` subcommand takes two positional arguments — `<state-path>` (the breadcrumb on disk) and `<input-path>` (a `mktemp`'d file holding the new JSON) — per BC-9027. See the Phase 1 example for the canonical `python3 > $TMP_JSON <<'PY' ... PY; bash $HELPER write $BREADCRUMB_PATH $TMP_JSON; rm -f $TMP_JSON` form. Construct dynamic values inside a single-quoted python heredoc (`<<'PY'`) so Linear-derived strings cannot expand into the shell; pass `$BREADCRUMB_PATH` and `$TMP_JSON` as discrete arguments to the helper (never inside `bash -c` or an unquoted `$(...)`). The `mktemp` file intermediate replaces the previous stdin-pipe pattern, which tripped the workflows security-hook classifier.

The breadcrumb append is the **last step** of a phase, after all of the phase's artifacts (inventory row / Linear writes / story doc / INDEX) have landed. Writing the breadcrumb earlier would let a killed session resume with a phase marked "complete" but artifact missing.

## See also

- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:743` — Q47 lock (canonical source; seven sub-decisions + refinement audit trail at line 780). Sub-decision 5.5 at line 771 holds the user-locked journey-staleness warning text.
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:224` — Q20 lock (sub-skill ownership boundary; sub-flow-add vs domain-add modes; Q20.2 auto-suggestion; Q20.4 hard-reject; Q20.6 within-skill gate; Q20.7 `inventory_changed` flag).
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-architecture-overview.md` §3c — plugin command surface (where this command sits in the ~17-command catalog).
- `plugins/flow-architecture/commands/start-project.md` — sibling greenfield orchestrator (BC-6962; 8 phases / 4 gates / hybrid control flow; this command's per-sub-flow N=1 inner loop is the degenerate case).
- `plugins/flow-architecture/commands/retrofit-project.md` — sibling retrofit orchestrator (BC-6963; 9 phases / 5 gates; closer in shape to start-project than to this command).
- `plugins/flow-architecture/skills/flow-preflight/SKILL.md` — Phase 1 sub-skill (BC-6957 shipped).
- `plugins/flow-architecture/scripts/flow-resume-breadcrumb.sh` — Q31.5 atomic-rename breadcrumb helper (BC-6956 shipped).
- Handbook CDR-023 — Flow-Driven Architecture (the policy this plugin implements).
- Handbook `how-we-work/operating-standards/flow-driven-architecture.md` — operating-standards page (Q34 lock).
- Parking lot #19 — v1.1 selective-re-author mode + `/flow:journey-refresh` command (the v1.1 plan that the journey-staleness warning text points users toward).
