---
description: Incremental-add Flow-Driven Architecture orchestrator (whole new domain with N sub-flows) — 6 phases / 2 gates / authors the new domain's journey doc per Q47 sub-decision 2
---

# /flow:add-domain

Heavier of the two incremental-add FDA orchestrators. Adds a whole new domain (1 milestone + N sub-flows + N story docs + 1 journey doc) under an existing FDA-shaped project. Runs **6 phases / 2 user-confirmation gates** per Q47 lock (`plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:745`): Phase 3 is a per-domain inner loop with `N=1` domain but N sub-flows inside, mirroring the Q37 hybrid control flow degenerated to N=1 domain (memory:756); Phases 4-5 are globally batched with N=1 domain (degenerate but consistent with the start-project sibling). Wall ≈ 10-30 min depending on sub-flow count.

> **Scope:** UI-bearing builds only (CDR-023 partition). Non-UI-bearing work uses CDR-014's Phase Pattern, not FDA. `flow-preflight` performs upstream mode classification — `/flow:add-domain` runs only when mode resolves to `incremental-add`.

> **DO NOT re-derive** the phase sequence, gate count + labels (`Q20.6`, `Q13.4` — NOT `G1`/`G2`), interactive-only invocation form, per-domain write-count formula `2+7N`, or per-phase failure matrix below. All seven Q47 sub-decisions are locked at memory:745-780 with a refinement audit trail at memory:782-789. The `G1`/`G2` framing is a known mis-label that has appeared in earlier derivative drafts (and in this command's Linear issue body) — Q47 sub-decision 5 (memory:771) explicitly labels both gates by their owning sub-skill (`Q20.6` + `Q13.4`); use the sub-skill labels.

## Architecture overview

```
  /flow:add-domain (incremental-add) — 6 phases / 2 gates
  ═══════════════════════════════════════════════════════════════════════

   ┌─ Phase 1 ─┐    ┌─ Phase 2 ─┐ Q20.6 ┌─ Phase 3 ─┐ Q13.4 ┌─ Phase 4 ─┐    ┌─ Phase 5 ─┐    ┌─ Phase 6 ─┐
   │ preflight │───►│  inventory│──────►│  linear-  │──────►│  doc-     │───►│  journey- │───►│  regen-   │
   │ bootstrap │    │ add domain│       │  scaffold │       │  author   │    │   author  │    │   index   │
   │   (Q12)   │    │   (Q20    │       │   (Q13)   │       │   (Q15)   │    │   (Q16)   │    │   (Q18)   │
   └───────────┘    │  domain-  │       └─────┬─────┘       └───────────┘    └───────────┘    └─────┬─────┘
   mode=            │   add)    │             ↓ L3 review                                           ↓
   incremental-add  └─────┬─────┘             → 5 disciplines                                  status: completed
                          ↓ within-skill        per sub-flow
                          gate (Q20.6 owns)     (before Q13.4
                          + L2 review per       preview)
                          domain (CEO+Design,
                          stashed for Phase 5)
```

> **Diagram note.** The `Q20.6` and `Q13.4` arrow labels above mark **within-skill gates** owned by the named sub-skill — they fire inside Phase 2 (Q20.6) and Phase 3 (Q13.4), not at the inter-phase boundary the horizontal arrow visually suggests. See § The 2 user gates for the full within-skill semantics (authoritative source for gate placement; the visual layout above is non-load-bearing).

**AUTHORS `flow-journey-author`** (Q16, Phase 5) — THE substantive differentiator from the sibling `/flow:add-sub-flow` (which skips Q16 and emits a journey-staleness warning instead per Q47 sub-decision 5.5). Authoring fresh is the correct behavior here because the new domain has no pre-existing journey doc to clobber.

**SKIPS `flow-legacy-cross-reference`** (Q14) per Q47 sub-decision 2 — incremental-add isn't a retrofit operation.

> **Gate labeling note.** Both gates are within-skill and labeled by their sub-skill locks per Q47 sub-decision 5 (memory:771): **Q20.6** lives inside `flow-inventory-add`; **Q13.4** lives inside `flow-linear-scaffold`. Sibling commands `/flow:start-project` and `/flow:retrofit-project` use orchestrator-budget gate numbering (`G1`-`G4`, `G1`-`G5`) because Q10 (memory:66) is mode-aware on retrofit/greenfield budgets and silent on incremental-add (Q47 refinement 6 confirmation, memory:789). Q47 refinement 2 (memory:785) further corrected drafter C's earlier 1+2 gate-count draft to the locked 2+2 (Q20.6 + Q13.4 per command).

## Invocation

`/flow:add-domain [--force-incremental-add] [--resume]`

**Interactive only — no positional args** per Q47 sub-decision 1 (memory:749). The new domain's code, display name, and sub-flow set are collected by the Q19-mini interview inside `flow-inventory-add` (domain-add mode per Q20 sub-decision 1, memory:226). A single-command shape with `subcommand`-style positional args was rejected at lock time — Q30.2 enumerates two distinct slash entries (`/flow:add-domain` + `/flow:add-sub-flow`) and Q47 commits to thin orchestrators over the underlying Q20 modes rather than re-litigating Q30.

`--force-incremental-add` flag (Q47 sub-decision 3, memory:764): bypasses the preflight mode-classifier check; surfaces a warning + writes an audit-log entry to the breadcrumb's `overrides[]` per Q29.5. Auto-redirect (silently running the recommended command instead of erroring) was rejected at lock time as too magical.

`--resume`: see § Resume contract.

## Mode classifier integration

`flow-preflight` MUST emit `MODE=incremental-add` for this command to proceed. Error redirects per Q47 sub-decision 3 (memory:758-762) — surface the recommended command but **do NOT auto-run** it:

- `MODE=greenfield` (no FDA artifacts present) — error:
  > "Project not yet initialized. Use `/flow:start-project` first."
- `MODE=retrofit` (FDA artifacts absent + ≥10 Linear issues per Q36.3 step 4) — error:
  > "Project has legacy work. Use `/flow:retrofit-project` to retrofit FDA shape, then `/flow:add-*` for incremental additions."
- `MODE=resume` (breadcrumb `in_flight` and non-stale) — error:
  > "Existing orchestrator run in flight at `docs/plans/.flow-phase-state.json`. Options: (a) resume via re-invocation of the original orchestrator (preflight will detect `mode=resume` and dispatch at `current_phase`); (b) manually discard by deleting `docs/plans/.flow-phase-state.json`; (c) wait until breadcrumb auto-stales (>7 days inactive per Q31.3) for `AskUserQuestion`-driven discard. Stale-breadcrumb auto-discard only fires after 7 days OR `status=completed|abandoned` per Q31.3 — does not apply to fresh `in_flight` breadcrumbs."
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
  "current_phase": "1|2|3|4|5|6",
  "completed_phases": ["1", "2", ...],
  "domains": [
    {
      "slug": "<new-domain-slug>",
      "scaffold_state": "pending|in_progress|completed|failed",
      "failure_reason": null,
      "parent_issue_ids": [],
      "milestone_id": null,
      "new_sub_flow_count": 0
    }
  ],
  "status": "in_flight",
  "last_updated": "<ISO-8601 refreshed each write>"
}
```

`status` transitions: `in_flight` (set at Phase 1 entry) → `completed` (Phase 6 terminator) OR `abandoned` (user halt at any gate OR Q20.4 duplicate hard-reject in Phase 2 per Q47 sub-decision 7 + user lock 2026-05-07).

The `domains[]` array always has exactly one entry — the new domain being added. The `milestone_id` field captures the Linear milestone ID created in Phase 3 so Phase 3 resume can skip re-creating the milestone. The `new_sub_flow_count` field captures the N value chosen during the Q19-mini interview so Phase 3-5 resume can size their work without re-probing inventory.

**Schema note on `milestone_id` + `new_sub_flow_count`.** Both fields on `domains[0]` are incremental-add-specific extensions to the canonical Q31.4 `domains[]` entry shape (siblings `start-project.md` and `retrofit-project.md` use the 4-field shape `{slug, scaffold_state, failure_reason, parent_issue_ids}`; `add-sub-flow.md` adds `new_sub_flow_id`). The extension is admissible under Q31.7 forward-tolerance ("v1.x reader is forward-tolerant within major — ignores unknown fields"); a Q31 amendment formalizing the field as part of the incremental-add breadcrumb is a v1.1 candidate.

**Single-orchestrator-at-a-time per Q31.6 v1**: concurrent `/flow:add-*` + `/flow:start-project` not supported in v1 — breadcrumb is per-repo, not per-run.

## Resume contract

`flow-preflight` is the entry — every orchestrator dispatches through it. When preflight detects an in-flight non-stale breadcrumb with `mode: incremental-add`, it returns `MODE=resume` and the orchestrator dispatches at `current_phase`:

| Resume phase | Behavior |
|---|---|
| 1 | re-run Phase 1 (preflight + bootstrap is idempotent). |
| 2 | re-run the § 2.0 classifier against `domains[0].slug` (the persisted target domain code) + Linear MCP overlay. If the classifier returns `inventory-only` AND `domains[0].inventory_only_rescaffold == true`, Branch B (§ 2.B) resumes — re-dispatch `flow-inventory-add` in `inventory-read` mode + re-fire L2 (in-memory) + re-fire Q20.6 with the Branch-B preview surface. Otherwise re-invoke `flow-inventory-add` in `domain-add` mode (Branch A) with `domains[0].slug` as the target; Q20.4 idempotency hard-rejects if the domain section already landed AND `inventory_only_rescaffold` is unset/false; if so, breadcrumb advances to `current_phase: 3`. Branches C / D were terminal on first run if the user picked Cancel (breadcrumb `status: abandoned` → preflight stale-policy offers discard, never re-enters Phase 2); a non-Cancel Branch C/D choice routes through Branch B's resume path on subsequent re-entry. |
| 3 | re-invoke `flow-linear-scaffold` for the single new domain (N sub-flows inside). Q13.5 sub-flow-atomic recovery applies inside Q13 across the N sub-flows; the milestone-create step is idempotent against the stored `milestone_id`. L3 review state not persisted (re-runs per parking lot #31 v1). |
| 4 | re-run Phase 4 (`flow-doc-author` for the new domain's N sub-flows). Q15's skip-if-exists per Q15.3 keeps already-written story docs from being clobbered without `--force`. |
| 5 | re-run Phase 5 (`flow-journey-author` for the new domain). Q16's skip-if-exists per Q16.3 likewise gates the journey-doc clobber. The L2 review state is in-memory only (parking lot #31 v1) — Phase 5 reads its L2 stash from `state.l2_review_<domain>` and re-fires inside the inventory-add step if Phase 2 re-runs first. |
| 6 | re-run Phase 6 — INDEX regen is idempotent. |

Stale breadcrumb handling (>7 days, or `status: completed | abandoned`, or malformed) lives inside `flow-preflight` Section 3.1 and prompts the user via `AskUserQuestion` to discard / force-resume / cancel. Orchestrator does not re-implement that policy.

## L-review routing

L-review routing for `/flow:add-domain` is fully determined by artifact scope — incremental-add does not touch project-scope artifacts, so L1 does not fire. L2 fires for the new domain (new journey doc); L3 fires per sub-flow (new parent issues). (Q47 sub-decision 4 boundary holds: L-review routing per artifact scope is a Q23/Q26/Q54 concern, not Q47's responsibility.) Concretely:

| Level | Phase | Where it fires | Output target | Notes |
|---|---|---|---|---|
| L1 review | — | not fired | — | `intent.md` is not re-authored in incremental-add. |
| **L2 review** | 2 | inside `flow-inventory-add` domain-add mode for the new domain — CEO + Design parallel per Q54 | in-memory `state.l2_review_<domain>` stash; consumed by Phase 5 to populate journey doc `## L2 review summary` per Q26 mod 2 / Q16.7 optional read path | fires once for the single new domain |
| **L3 review** | 3 | inside `flow-linear-scaffold` per sub-flow BEFORE the Q13.4 preview gate — all 5 disciplines (Story + Eng + Design + QA + Docs) parallel | Linear parent issue `## L3 review summary` section per Q23 mod 2; headlines visible in Q13.4 preview | fires N times — once per new sub-flow under the new domain |
| L4 review | n/a | JIT during `/flow:session-start` Step 5 — not orchestrator-driven |  — |  |

L2 + L3 review state is **in-memory only** during single invocation per parking lot #31 v1. On crash-resume, L2 re-runs when Phase 2 re-runs; L3 re-runs when Phase 3 re-runs.

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
  "current_phase":         "1..6",
  "completed_phases":      [...],
  "preamble":              { ...10 KEY=VALUE fields from flow-preflight Section 5 },
  "inventory_path":        "docs/product/master-flow-inventory.md",
  "target_domain":         "<DOMAIN slug — collected by Q19-mini interview inside flow-inventory-add>",
  "target_domain_display": "<display name — collected by Q19-mini>",
  "new_sub_flow_ids":      ["<DOMAIN-01>", "<DOMAIN-02>", ...],
  "inventory_changed":     false,
  "domains":               [ { "slug", "scaffold_state", "failure_reason", "parent_issue_ids": [...], "milestone_id", "new_sub_flow_count" } ],
  "l2_review_<slug>":      "<in-memory blob; consumed by Phase 5>",
  "l3_review":             { "<sub-flow-id>": "<in-memory blob>" },
  "ship_artifacts":        { "story_docs": [...], "journey_doc": "<path>", "index_path": "<path>" },
  "status":                "in_flight"
}
```

This object is **session-scoped**. The breadcrumb is the persistent projection — `current_phase`, `completed_phases[]`, `domains[]`, `run_started_at`, `status`. L2 + L3 review state is not breadcrumb-persisted (parking lot #31 v1). `inventory_changed` flips to `true` when Q20 emits the Q20.7 flag at the end of Phase 2 — Phase 6 reads it to confirm `flow-regen-index` has new rows to render.

## The 2 user gates (Q47 sub-decision 5)

Both gates are **within-skill** — the orchestrator does not fire its own `AskUserQuestion` for either gate; the sub-skill owns the prompt. The orchestrator's responsibility is to honor the gate outcome (Approve / Edit / Cancel) per the Gate-respect contract section below.

- **`Q20.6`** (Phase 2 internal — `flow-inventory-add` domain-add within-skill confirmation per Q20 sub-decision 6, memory:236): matches Q19 Phase 5 surface — preview proposed domain section + sub-flow rows; Approve / Edit inline / Reject.

  Owned by Q20; fires inside the sub-skill, NOT the orchestrator. On Approve → new domain section is appended to `master-flow-inventory.md` under the derived top-level grouping. On Edit → re-prompt with current values pre-filled. On Reject → no write; orchestrator writes breadcrumb `status: abandoned`.

- **`Q13.4`** (Phase 3 internal — `flow-linear-scaffold` pre-scaffold preview per Q13 lock memory:88):

  Reviews the **2+7N planned Linear writes** for the single new domain per Q47 sub-decision 2 (memory:753; Q13 lock's per-domain formula `2 + 7N`):

  - 2 milestone-level writes: 1 milestone create + 1 milestone description write (Sub-flows table populated per Q22 schema).
  - 7 writes per sub-flow × N sub-flows: 1 parent issue + 5 discipline children (Story + Eng + Design + QA + Docs) + 1 children-summary comment per parent.
  - Total = `2 + 7N`.

  Fires **regardless of N** (no trivial-preview suppression per Q47 refinement 2, memory:785). L3 review headlines from inside Q13 are already populated in each parent issue's `## L3 review summary` at preview time so the user sees discipline-grade signal before authorizing the writes.

Q20.6 + Q13.4 do **NOT collapse** — they serve different review purposes (inventory content vs Linear scaffold preview); the user can edit between them.

## Per-phase failure matrix (Q47 sub-decision 7 — verbatim from memory:780)

| Phase | Failure semantics |
|---|---|
| 1 | preflight fail-closed per Q36.5. No partial `.flow/config.json` on disk — atomic-rename guarantees absent-or-complete. |
| 2 | Branch A (classifier=`absent`): Q20 hard-reject on duplicate per Q20.4 (memory:232 — domain code already exists) is now a race-condition signal (the classifier should have routed away from Branch A); write breadcrumb at phase 2 entry → on hard-reject, mark `status: abandoned` with `reason: 'duplicate detected (Q20.4)'` for audit trail (per user lock 2026-05-07, memory:780). Branch B (classifier=`inventory-only`, Q20 amendment 1): user Cancel at the Q20.6 preview → `status: abandoned` with synthetic override `reason: 'inventory-only-rescaffold cancelled at Q20.6 (Q20 amendment 1)'`. Branch C / D failure semantics carry through the user's `AskUserQuestion` choice — Cancel paths write `status: abandoned` with override rows tagging the declined-state reason. Consistent with Q31 lifecycle (Q31.3 accommodates abandoned status — future preflight offers discard); diverges from Q36.5's "no partial state" (which applies to bootstrap config-json, NOT breadcrumbs — different concerns). |
| 3 | per Q13.5 sub-flow-atomic recovery — failure isolated to one sub-flow inside the N-many. Orchestrator pauses inner loop for user adjudication (`AskUserQuestion`: retry / skip-sub-flow / abort). On user choice "retry" or "skip", inner loop resumes with the next pending sub-flow. |
| 4 | per Q15.5 log + continue. Per-sub-flow failures within the N-doc batch surface in batch summary; orchestrator does NOT roll back since outputs are filesystem writes reviewable via `git diff` + `verify-docs.sh`. |
| 5 | per Q16.5 log + continue. Single-domain journey author failure surfaces in batch summary. |
| 6 | per Q18.7 skip-row + marker. INDEX renders a "regen-failed: `<reason>`" row instead of clobbering with a partial INDEX. |
| user halt at any gate | breadcrumb `status: abandoned`; future `/flow:add-domain` invocation detects abandoned + offers discard per Q31.3 stale-breadcrumb policy. (Q31.1 lock reserves the `reason` field for `overrides[]` entries — Q29.5 hard-gate decisions, not user-cancel attribution; do not add a top-level `reason` field without a Q31 amendment + audit trail.) |

---

## Phase 1: preflight + bootstrap

**Sub-skill:** `flow-preflight` (Q12 + Q36 embedded 7-step bootstrap; BC-6957 shipped at `plugins/flow-architecture/skills/flow-preflight/SKILL.md`).

**Pre-flow-preflight setup:** the orchestrator owns the `LINEAR_ISSUE_COUNT` env-var per `flow-preflight` Section 6.4 ownership note. Before dispatching the skill:

1. Call the Linear MCP `mcp__plugin_workflows_linear-server__list_issues` with `{project: <candidate project_id from .flow/config.json>, limit: 10}`.
2. Count the returned items as an integer (0–10).
3. `export LINEAR_ISSUE_COUNT=<integer>` so `flow-preflight` Section 6.4 picks it up.

Treat the captured integer as data only — never interpolate any Linear-derived field (issue titles, project name, descriptions) into a shell expression, `bash -c`, `eval`, or unquoted `$(...)`. Only the integer count crosses into env. The MCP call is the trust boundary; values from the MCP response stay inside the LLM context, never inside a shell pipeline.

The `limit: 10` cap aligns with Q36.3 step-4's threshold-IS-the-cap semantics — a returned count of exactly 10 means "≥ 10" (no pagination needed). For `/flow:add-domain`, the `.flow/config.json` is expected to exist (incremental-add precondition); if absent, preflight will surface the missing-config error before the mode-classifier check fires.

**Run:** dispatch `flow-preflight` inline (skill is `disable-model-invocation: true`, `user-invocable: false` — orchestrators call directly).

`flow-preflight` runs its 5 environment checks (Section 1), FDA-artifact discovery (Section 2), mode classification (Section 3), Linear scope confirmation (Section 4), preamble emission (Section 5), and on first-run the Q36 7-step bootstrap (Section 6) — though for `/flow:add-domain`, the bootstrap should already be complete (incremental-add precondition).

**Mode guard:** if `flow-preflight` emits `MODE != incremental-add`, surface the error redirect per Q47 sub-decision 3 (see § Mode classifier integration above) and STOP. Honor `--force-incremental-add` if passed: skip the mode-guard hard-stop, surface a warning, and append an audit-log entry to the breadcrumb's `overrides[]` per Q29.5.

**Capture from preamble** (10 KEY=VALUE fields per `flow-preflight` Section 5):

- `LINEAR_PROJECT_ID`, `LINEAR_PROJECT_NAME`, `LINEAR_TEAM_KEY` (derived from `.flow/config.json`)
- `REPO_ROOT`
- `INTENT_EXISTS`, `INVENTORY_EXISTS`, `FLOWS_DIR_EXISTS`, `BREADCRUMB_EXISTS` (all expected `yes` for incremental-add)
- `GH_AUTH`, `LINEAR_MCP`

**Initial breadcrumb write:** at end of Phase 1, write the breadcrumb with `run_started_at` (ISO-8601 now), `current_phase: 2`, `completed_phases: ["1"]`, `mode: incremental-add`, `status: in_flight`, empty `domains: []` (populated by Phase 2 once the user picks the new domain code).

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

The `mktemp` file intermediate is the BC-9027 fix: the previous pattern `python3 <<'PY' | bash $HELPER write ...` tripped the workflows security-hook classifier as a "piped download/execution" false-positive. Routing through `$TMP_JSON` keeps the helper-call as a plain argv invocation.

**No user gate after Phase 1.** Q47 sub-decision 5 locks both gates as within-skill (Q20.6 + Q13.4); Phase 1's only failure path is `flow-preflight`'s own fail-closed surface per Q36.5.

**Failure semantics (Phase 1):** fail-closed per Q36.5. No partial `.flow/config.json`. Any failure inside `flow-preflight` surfaces verbatim with the remediation hint preflight emitted.

---

## Phase 2: inventory append (domain-add mode) — gate Q20.6

**Sub-skill:** `flow-inventory-add` (Q20; not yet shipped — orchestrator references by name).

> **Q20 amendment 1 (BC-9971) note.** Phase 2 runs a 4-outcome pre-dispatch classifier (filesystem + Linear MCP) BEFORE dispatching `flow-inventory-add`. The historical "always-dispatch-domain-add" path is preserved only on the `absent` classifier outcome; three additional branches (`inventory-only`, `journey-exists`, `fully-scaffolded-fs`) route differently. See § 2.0 Pre-dispatch classifier (below) and `docs/design-rationale/fda-plugin-interview.md` § "Q20 amendment 1" for the canonical rationale + four-outcome table.

**Inputs handed to the sub-skill** (Branch A — when classifier returns `absent`, the only dispatch path):

- `mode: domain-add` — dispatches the heavier mode per Q20 sub-decision 1 (memory:226), running the Q19-mini interview (Phases 1+4+5 of Q19 for one domain only).
- No positional pre-fills — the domain code, display name, and sub-flow set are collected entirely inside the Q19-mini interview per Q47 sub-decision 1 (memory:749).

**Boundary contract (Q47 sub-decision 4, memory:769): Q47 delegates to Q20 — the orchestrator NEVER edits inventory directly.** Q20 owns inventory append mechanics (memory:230 — append-only semantics; never rewrites existing rows; never renames IDs); the orchestrator only dispatches and observes. If the orchestrator detects a desired inventory change for the new domain mid-flight, it re-invokes Q20; it never edits inventory directly. **The classifier in § 2.0 below is read-only against inventory** — it does NOT write; only the dispatched `flow-inventory-add` (Branch A) writes.

### 2.0 Pre-dispatch classifier (Q20 amendment 1, BC-9971)

Before dispatching `flow-inventory-add` in domain-add mode, classify the target domain's current scaffold state. The classifier resolves the gap surfaced by the Brand Hub iter-2 dogfood (BC-6998, 2026-05-13): iter-2 deliberately partial-scaffolded 1 domain × 1 sub-flow as a v1.0 demonstration, leaving 9 inventoried-but-unscaffolded domains. The 9 BC-9559 children (BC-9560..BC-9568) all said "Run /flow:add-domain for the `<domain>` domain" but pre-amendment that hit Q20.4 hard-reject because the H3 section was already in inventory.

**Step 1 — collect the target domain code.** Before invoking the classifier, prompt for the target domain code via `AskUserQuestion` (or accept from a re-entry on resume). The Q19-mini interview Phase 1 surface form remains the source of truth for new domains; this step only collects the slug ahead of dispatch so the classifier can run.

> "Which domain code? (uppercase `[A-Z][A-Z0-9_-]*` — e.g., `ASSET-DISCOVERY`, `LIGHTING`, `RESERVATIONS`. Re-running against an inventoried-but-unscaffolded domain is supported; pick its code from `docs/product/master-flow-inventory.md`.)"

Treat the collected value as data only — never interpolate into a shell expression, `bash -c`, or unquoted `$(...)`. The classifier validates the slug against the Q20.4 schema regex internally and exits 2 on rejection; the orchestrator surfaces the rejection verbatim and re-prompts.

**Step 2 — invoke the classifier** (filesystem-only). Capture both stdout (the classification token) and stderr (any rejection message) separately so the LLM can re-prompt Step 1 on rejection instead of terminating Phase 2:

```bash
CLASSIFIER_STDERR="$(mktemp -t flow-classify-stderr.XXXXXX)"
CLASSIFIER_STDOUT="$(bash "$CLAUDE_PLUGIN_ROOT/scripts/flow-classify-domain-state.sh" \
    "$REPO_ROOT/docs/product/master-flow-inventory.md" \
    "$REPO_ROOT/docs/product/flows" \
    "$REPO_ROOT/docs/product/journeys" \
    "$TARGET_DOMAIN" 2>"$CLASSIFIER_STDERR")"
CLASSIFIER_EXIT=$?
CLASSIFIER_ERR="$(cat "$CLASSIFIER_STDERR")"
rm -f "$CLASSIFIER_STDERR"
```

After this Bash block returns, the orchestrator (LLM) inspects `CLASSIFIER_EXIT`:

- `0` — `CLASSIFIER_STDOUT` is one of `absent` / `inventory-only` / `journey-exists` / `fully-scaffolded-fs`. Proceed to Step 3.
- `2` — `CLASSIFIER_ERR` carries the rejection reason (malformed DOMAIN per Q20.4 schema, missing inventory file, etc.). Surface the rejection text verbatim to the user via natural language and **re-prompt Step 1** (the slug-collection `AskUserQuestion`); do NOT terminate Phase 2. The orchestrator runs Step 1 + Step 2 in a Step-1↔Step-2 loop until the classifier exits 0 OR the user cancels (in which case write breadcrumb `status: abandoned` and exit cleanly).

**Step 3 — Linear milestone overlay.** Query `mcp__plugin_workflows_linear-server__list_milestones` for the project. Combine the classifier outcome with the milestone-presence check per the table below:

| Classifier | `FDA: <domain>` milestone | Combined → orchestrator branch |
|---|---|---|
| `absent` | (not checked) | **Branch A — domain-add** (unchanged; today's path) |
| `inventory-only` | absent | **Branch B — inventory-only re-scaffold** (new; the load-bearing fix) |
| `inventory-only` | present | **Branch B with drift advisory** — log: "inventory says inventory-only but Linear milestone exists — possible drift; proceeding with idempotent re-scaffold (milestone-create step is idempotent against stored `milestone_id`)". Then proceed as Branch B. |
| `journey-exists` | (not checked) | **Branch C — journey-already-authored** |
| `fully-scaffolded-fs` | (not checked) | **Branch D — fully-scaffolded no-op** |

**Step 4 — dispatch to the appropriate branch** (rest of Phase 2 + Phase 3 ingestion path differ per branch; see § 2.A-D below).

### 2.A Branch A — domain-add (classifier returned `absent`)

This is today's path. Proceed exactly as before this amendment:

**Pre-write breadcrumb stub (two writes inside Phase 2):** the helper script reads `<input-path>` as a **complete** JSON document — it does NOT merge with the on-disk state — so each python3 heredoc MUST include every canonical field per § Phase-exit breadcrumb update. Two distinct writes inside Phase 2:

- **Write 2a — pre-Q19-mini, on Phase 2 entry:** `current_phase: 2`, `completed_phases: ["1"]`, `domains: []`. This ensures a Q20.4 duplicate hard-reject during the interview has a complete-schema breadcrumb to mark `abandoned` against.
- **Write 2b — post-Q19-mini-interview, pre-Q20.6:** refresh `domains` to `[{slug: <target_domain>, scaffold_state: "pending", failure_reason: null, parent_issue_ids: [], milestone_id: null, new_sub_flow_count: <N>}]`.

**Run:** dispatch `flow-inventory-add` (domain-add mode). The sub-skill:

1. Runs the Q19-mini interview (Phase 1 app-classifier-style probes for the new domain + Phase 4 synthesis for the new domain's sub-flows). The interview collects: domain code (uppercase slug per Q20.4 schema), display name, derived top-level grouping (per Q19.4), N sub-flows with `id` / `title` / `primary persona` / `Notes` (status-priority tags per Q19.3).
2. Fires the **L2 review** for the new domain — CEO + Design parallel per Q54 + Q19 Phase 4 synthesis pattern. Headlines are stashed in `state.l2_review_<target_domain>` for Phase 5 hand-off (in-memory only per parking lot #31 v1; on crash-resume, Phase 2 re-runs and re-fires L2 — ~2-5 min).
3. Fires the **Q20.6 within-skill confirmation gate** (matches Q19 Phase 5 surface — preview proposed domain section + sub-flow rows). The orchestrator does NOT fire this `AskUserQuestion` itself — Q20 owns the prompt.

   > Approve / Edit inline / Reject.

4. On Approve → appends the new domain block (H3 + metadata line + sub-flow table) at the end of the derived top-level grouping in `master-flow-inventory.md` per Q20 sub-decision 3 (memory:230) + atomic-rename writes.
5. On Edit → re-prompts the relevant Q19-mini fields with current values pre-filled, then re-fires Q20.6.
6. On Reject → no write; orchestrator writes breadcrumb `status: abandoned` + exits cleanly.
7. Emits Q20.7 `state.inventory_changed = true` flag — orchestrator captures into `state.inventory_changed` for Phase 6 INDEX regen trigger.

**Capture into state:** `state.target_domain` (final slug), `state.target_domain_display` (final display name), `state.new_sub_flow_ids[]` (the N sub-flow IDs the Q19-mini interview produced), `state.inventory_changed = true`, `state.l2_review_<target_domain>`, `state.domains[0]` populated.

**Breadcrumb update (end of Phase 2):** per § Phase-exit; next phase is `3`. Phase 3 will flip `domains[0].scaffold_state` from `pending` → `in_progress` → `completed` and populate `milestone_id` + `parent_issue_ids`.

**Failure semantics (Branch A):** Q20 hard-reject on duplicate per Q20.4 (memory:232 — domain code already has a section). Pre-amendment this fired whenever the H3 section existed; post-amendment the classifier routes such cases away from Branch A, so a Q20.4 hard-reject reaching the user here means the classifier saw `absent` but `flow-inventory-add` saw an H3 — a race condition (a concurrent inventory edit between § 2.0 Step 2 and § 2.A dispatch) or a classifier-vs-skill regex mismatch. Either way, surface the Q20.4 error verbatim (which still includes the canonical hint "use `/flow:add-sub-flow` if you intended to add a sub-flow under an existing domain"), and capture the diagnostic in the breadcrumb's synthetic override row so the operator can distinguish race / regex-drift from genuine user error.

Per Q47 sub-decision 7 + user lock 2026-05-07: on Q20.4 hard-reject, write breadcrumb `status: abandoned` with `reason: 'duplicate detected (Q20.4)'` for audit trail. (Note: the `reason` field referenced here is on the breadcrumb `overrides[]` entry pattern from Q29.5, not a top-level breadcrumb field — append a synthetic override row tagging the duplicate-detect event rather than adding a new top-level field. This preserves Q31.1's schema discipline.) Q31.3 stale-breadcrumb policy will offer discard naturally on the next `/flow:add-domain` invocation.

Inventory parse failure (malformed table, missing grouping section) → Q20 aborts + surfaces line number; orchestrator does NOT auto-repair (would risk silent data loss per Q20 sub-decision 5).

User-cancel at Q20.6 → no write; clean exit; breadcrumb `status: abandoned` (top-level `status` change — no synthetic override row needed for user-cancel).

### 2.B Branch B — inventory-only re-scaffold (classifier returned `inventory-only`)

The new load-bearing path. Unblocks BC-9559 + its 9 children (BC-9560..BC-9568). Do NOT dispatch `flow-inventory-add` — the existing H3 section + sub-flow rows + status tags + persona column ARE the canonical record per Q20 amendment 1.

**Step 1 — log the detected mode.** Surface to stdout:

> "Detected inventory-only domain `<target_domain>` — proceeding to Phase 3 scaffold using existing inventory section as canonical."

**Step 2 — dispatch `flow-inventory-add` in `inventory-read` mode** (Q20 amendment 1 new mode; the orchestrator does NOT re-implement the H3 parser per Q47 sub-decision 4). The sub-skill returns structured metadata that the orchestrator captures into session-state:

- `state.target_domain` — the H3 domain code (echoed back).
- `state.target_domain_display` — extracted by Q20 from the H3 line.
- `state.new_sub_flow_ids[]` — every `<DOMAIN>-NN` ID Q20 read from the sub-flow table rows.
- `state.new_sub_flow_count` — count of sub-flow rows Q20 returned.
- Per-sub-flow metadata (title, primary persona, Notes / status tag) — Q20-returned row tuples; carried through into the Q13 preview content for Phase 3.
- `state.inventory_changed = false` — IMPORTANT: this branch does NOT modify inventory, so Phase 6 INDEX regen does not need a fresh trigger from this run; the existing INDEX may already render the inventory section correctly (post-Phase-6 audit will verify).
- `domains[0].inventory_only_rescaffold = true` — per-domain flag for resume + breadcrumb persistence. Q31.7 forward-tolerance (`v1.x reader is forward-tolerant within major — ignores unknown fields`) covers the new optional `domains[0].inventory_only_rescaffold: bool` breadcrumb field without a Q31 amendment; extending the rule established by `milestone_id` + `new_sub_flow_count` on the same `domains[0]` shape (Q47 sub-decision 7 schema note). A Q31 amendment 3 to formalize the field is a v1.1 candidate.

Q20.5 parse-failure semantics apply at this step exactly as in Branch A: malformed table / missing column header → Q20 aborts + surfaces line number; do NOT auto-repair.

**Step 3 — fire L2 review for the new domain** (CEO + Design parallel, per Q54). Stash headlines in `state.l2_review_<target_domain>` exactly as Branch A does. L2 reviewers read the same inputs they would have read in Branch A — `intent.md` + the existing inventory H3 section. On crash-resume, re-running Branch B re-fires L2.

**Step 4 — fire the Q20.6 confirmation gate with a Branch-B-specific preview surface.** The orchestrator does NOT call `flow-inventory-add` (which owns the Branch-A Q20.6 surface); instead, surface the gate directly:

> "Detected inventory-only domain `<DOMAIN>`. Inventory section at `<H3 line>` (preserves status tags + sub-flow rows verbatim):
>
> ```
> <render of the H3 section + table>
> ```
>
> Proceed to Phase 3 scaffold using this inventory section as canonical?
>
> - Approve — proceed to Phase 3 with existing inventory section as canonical.
> - Cancel — write breadcrumb `status: abandoned` with synthetic override `reason: 'inventory-only-rescaffold cancelled at Q20.6 (Q20 amendment 1)'` and exit cleanly."

Q20 amendment 1 deliberately omits "Edit inline" — editing the inventory section while running Branch B would re-introduce the boundary-contract violation Q47 sub-decision 4 forbids. If the user wants to edit inventory, they cancel here and run `/flow:add-sub-flow` for sub-flow additions, or hand-edit the inventory file + re-run `/flow:add-domain`.

**Step 5 — breadcrumb update.** Write the per-§-Phase-exit breadcrumb with `domains[0]` populated from Step 2 + the new optional field `domains[0].inventory_only_rescaffold: true`.

**Failure semantics (Branch B):**

- Classifier-vs-Linear-milestone drift advisory (per § 2.0 Step 3 table row) — log + continue; Phase 3's milestone-create step is idempotent against any stored `milestone_id`.
- L2 review failures — log + continue; the journey doc's `## L2 review summary` section becomes empty if L2 produced no headlines (parking lot #31 v1 acceptance).
- Inventory parse failure (malformed table, missing column header) — abort + surface line number; do NOT auto-repair (same Q20.5 discipline as Branch A).
- User Cancel at Q20.6 — no write; clean exit; breadcrumb `status: abandoned` per the synthetic override pattern above.

### 2.C Branch C — journey-already-authored (classifier returned `journey-exists`)

This intermediate state usually means Phase 5 (journey author) succeeded but Phase 4 (story docs) failed or was deferred. Surface an `AskUserQuestion`:

> "Domain `<DOMAIN>` has a journey doc at `docs/product/journeys/<domain>.md` but no story docs at `docs/product/flows/<domain>/`. How should I proceed?
>
> - Re-run Phase 4 only — invoke `flow-doc-author` for the N sub-flows in the inventory section; skip Phase 5 (journey doc preserved per Q16.3).
> - Re-run Phases 3-6 with `--force` — clobbers the existing journey doc; treat as Branch B with `--force` propagated to Q15 + Q16.
> - Cancel — write breadcrumb `status: abandoned` with synthetic override `reason: 'journey-exists state declined at Q20 amendment 1'`."

Capture the user's choice into `state.branch_c_choice` and route Phase 3 entry accordingly.

### 2.D Branch D — fully-scaffolded no-op (classifier returned `fully-scaffolded-fs`)

Surface an `AskUserQuestion`:

> "Domain `<DOMAIN>` already has an inventory section, a journey doc, and at least one story doc on filesystem. Re-scaffolding requires `--force` (clobbers existing journey doc + any story docs whose Q15.3 / Q16.3 skip-if-exists is bypassed). How should I proceed?
>
> - Cancel (Recommended) — write breadcrumb `status: abandoned` with synthetic override `reason: 'already-scaffolded (Q20 amendment 1)'` and exit cleanly.
> - Re-scaffold via `--force` — proceed as Branch B + `--force` on Q15 + Q16."

Default-Recommended is Cancel to mirror Q15.3 / Q16.3 skip-if-exists discipline at the orchestrator scope.

---

## Phase 3: linear scaffold (per-domain inner loop, N=1 domain × N sub-flows) — gate Q13.4

**Sub-skill:** `flow-linear-scaffold` (Q13; not yet shipped — orchestrator references by name).

This phase mirrors the sibling greenfield Phase-4 per-domain inner loop degenerated to N=1 domain — but the new domain has N sub-flows inside, so the per-sub-flow L3 review + atomic recovery semantics still apply across the N sub-flows. Q13.5's sub-flow-atomic failure recovery semantics + Q13.4's per-domain preview content apply unchanged.

**Per-domain footprint** (Q13 lock + Q47 sub-decision 2 explicit formula, memory:753):

- 1 milestone create (the new domain milestone)
- 1 milestone description write (populating the Sub-flows table per Q22 schema)
- N parent issues (one per sub-flow)
- 5N discipline children (Story + Eng + Design + QA + Docs × N sub-flows)
- N children-summary comments (one per parent)

Total: **`2 + 7N` Linear writes** for the new domain (Q47 sub-decision 2 explicit lock; Q13 lock's per-domain formula — the bullets above sum to `2 + N + 5N + N = 2 + 7N`). Carry the formula symbolically through the preview — substitute `N` with the actual count at runtime.

### 3.1 L3 review fires INSIDE flow-linear-scaffold (before Q13.4 preview)

Per Q23 mod 2 (memory:515; as corrected by Q23 amendment 1, memory:517) + Q13 sub-decision 4 (memory:88) — all 5 disciplines (Story + Eng + Design + QA + Docs) fire in parallel **for each of the N sub-flows** under the new domain. Headlines populate each parent issue's `## L3 review summary` section **before** the Q13.4 preview gate so the preview shows L3 discipline signal for human review.

L3 review output is stashed in `state.l3_review[<sub-flow-id>]` for the duration of the orchestrator run. Not breadcrumb-persisted — on crash-resume, Phase 3 re-runs and re-fires L3 (parking lot #31 v1 acceptance).

### 3.2 Q13.4 pre-scaffold preview (gate)

After the L3 reviews fire (one per sub-flow) + per-domain preview content is computed, Q13 fires the **Q13.4 within-skill preview gate** showing the `2+7N` planned Linear writes. The orchestrator does NOT fire this `AskUserQuestion` itself — Q13 owns the prompt. The preview content is computed deterministically from inventory + parent issue numbering (next available BC-NNNN per project) up front; user authorization at Q13.4 covers the whole-domain batch.

Q13.4 fires **regardless of N** per Q47 refinement 2 (memory:785) — there is no trivial-preview suppression at this lock; the gate is mandatory.

### 3.3 Execution with Q13.5 atomic recovery (per sub-flow inside N)

After Q13.4 approval, `flow-linear-scaffold` executes the writes in order: first the 2 milestone-level writes (create + description), then the 7 writes per sub-flow × N sub-flows. **Q13.5 sub-flow-atomic recovery applies per sub-flow within the N:**

- On success (for a given sub-flow): mark that sub-flow's writes complete; capture its parent issue ID into `state.domains[0].parent_issue_ids[]`; continue to the next pending sub-flow in the inner loop.
- On failure (for a given sub-flow): Q13 surfaces an `AskUserQuestion`:

  > "Sub-flow `<DOMAIN-NN>` scaffold failed: `<reason>`. How should I proceed?"
  >
  > - **Retry this sub-flow** — re-invoke `flow-linear-scaffold` for `<DOMAIN-NN>`.
  > - **Skip this sub-flow + continue** — leave Linear writes incomplete for `<DOMAIN-NN>`; mark per-sub-flow failure in the scaffold log; continue inner loop with next pending sub-flow.
  > - **Abort Phase 3** — write `status: abandoned` to breadcrumb; exit cleanly. Successful per-sub-flow writes (e.g., 3 of N sub-flows complete) remain on Linear and surface in the abandoned breadcrumb's audit trail.

On milestone-create failure (the first of the 2 milestone-level writes), Q13 retries once with 2s backoff per Q13.5 transient-retry pattern; on persistent failure, aborts the whole domain (no parent issues created yet, so cleanup is empty).

After all N sub-flows processed (any combination of completed / failed / skipped), mark `breadcrumb.domains[0].scaffold_state = "completed"` if all N succeeded, or `"failed"` with `failure_reason` set if any failed without skip-and-continue. Capture `milestone_id` + the populated `parent_issue_ids[]`.

**Breadcrumb update (end of Phase 3):** per § Phase-exit; next phase is `4`. Additionally set `domains[0].scaffold_state` to `"completed"` (or `"failed"`), `domains[0].milestone_id`, and `domains[0].parent_issue_ids`.

**Failure semantics (Phase 3):** per Q13.5 sub-flow-atomic recovery (memory:780). Q13 retry / skip / abort `AskUserQuestion` per failed sub-flow honors the Gate-respect contract.

---

## Phase 4: doc author (new domain's N sub-flows)

**Sub-skill:** `flow-doc-author` (Q15; not yet shipped — orchestrator references by name).

This phase invokes `flow-doc-author` ONCE with the new domain's N sub-flows. This activates Q15.2's per-sub-flow internal parallelism (~30-60s wall regardless of N for typical N=2-8).

**Pre-condition:** Phase 3 completed; `state.domains[0].scaffold_state == "completed"` (or partial-with-skipped-sub-flows tracked); `parent_issue_ids[]` populated for each completed sub-flow.

**Run:** dispatch `flow-doc-author` with the new domain's sub-flow set from `state.new_sub_flow_ids[]` filtered to sub-flows where Phase 3 scaffold succeeded. The skill:

1. Reads `intent.md` + `master-flow-inventory.md` + per-sub-flow parent issue (for L3 headlines + AC).
2. Writes story docs at `docs/product/flows/<target_domain>/<sub-flow-id>.md` per sub-flow.
3. Q15.2 internal parallelism dispatches per-sub-flow drafters concurrently.
4. Skip-if-exists per Q15.3: existing story docs preserved unless `--force` flag passed (escalated through the orchestrator's CLI flag handling).
5. Q15.5 log + continue: partial failures within the batch surface in batch summary; orchestrator does NOT roll back successful writes.

**Capture into state:** `state.ship_artifacts.story_docs[]` (list of paths written).

**No gate.** Q15.6 locks 0 sync gates for Phase 4. The phase runs to completion (or partial-with-batch-summary) and dispatches to Phase 5.

**Breadcrumb update (end of Phase 4):** per § Phase-exit; next phase is `5`. No phase-specific delta fields.

**Failure semantics (Phase 4):** log + continue per Q15.5. Partial Q15 failures surface in batch summary; outputs are filesystem writes reviewable via `git diff` + `bash scripts/verify-docs.sh`.

---

## Phase 5: journey author (new domain)

**Sub-skill:** `flow-journey-author` (Q16; not yet shipped — orchestrator references by name).

This phase invokes `flow-journey-author` ONCE for the new domain. This is the substantive differentiator from the sibling `/flow:add-sub-flow` (which skips Q16 + emits a journey-staleness warning per Q47 sub-decision 5.5). For `/flow:add-domain`, the journey doc is authored fresh — no pre-existing journey doc exists for the new domain to clobber.

**Pre-condition:** Phase 4 completed; story docs written for the new domain's sub-flows.

**Run:** dispatch `flow-journey-author` with the new domain from `state.domains[0]`. The skill:

1. Reads `intent.md` + `master-flow-inventory.md` + the new domain's story docs + `state.l2_review_<target_domain>` stash from Phase 2.
2. Writes the journey doc at `docs/product/journeys/<target_domain>.md`.
3. Populates the journey doc's `## L2 review summary` section from the L2 stash per Q26 mod 2 / Q16.7 optional read path. **Read the stash only — DO NOT re-fire L2 reviewers in Phase 5.** L2 fires exactly once inside Phase 2's inventory-add step; on crash-resume, Phase 2 re-runs (and re-fires L2) per parking lot #31 v1, never Phase 5.
4. Skip-if-exists per Q16.3: an existing journey doc is preserved unless the user passes `--force` (escalated through the orchestrator's CLI flag handling). For a fresh domain (incremental-add), Q16.3 skip should not trigger — the journey doc shouldn't exist yet — but the discipline holds for safety against accidental re-runs.
5. Q16.5 log + continue: a single-domain Q16 failure surfaces in summary; orchestrator does NOT roll back successful writes (the story docs from Phase 4 + Linear writes from Phase 3 remain).

**Capture into state:** `state.ship_artifacts.journey_doc = "docs/product/journeys/<target_domain>.md"`.

**No gate.** Q16.6 locks 0 sync gates for Phase 5.

**Breadcrumb update (end of Phase 5):** per § Phase-exit; next phase is `6`. No phase-specific delta fields.

**Failure semantics (Phase 5):** log + continue per Q16.5. Same shape as Phase 4.

---

## Phase 6: regen index

**Sub-skill:** `flow-regen-index` (Q18; not yet shipped — orchestrator references by name).

`state.inventory_changed = true` was set by Q20.7 at the end of Phase 2 (Branch A only) — this is the Q47 sub-decision 4 boundary signal that `flow-regen-index` should run. Dispatch `flow-regen-index`. The skill regenerates `docs/product/flows/INDEX.md` from `master-flow-inventory.md` + per-domain story doc presence. Idempotent — re-running yields the same INDEX content for the same input.

> **Q20 amendment 1 note (BC-9971):** on Branch B (`inventory-only` re-scaffold), `state.inventory_changed = false` because the existing inventory section is the canonical record (no append happens). Phase 6 still runs `flow-regen-index` so that the INDEX picks up the new per-sub-flow story doc rows authored in Phase 4 + the journey doc row authored in Phase 5; regen-index is idempotent so a no-op-regen against an already-correct INDEX is also safe. Branches C / D inherit whichever Q15.3 / Q16.3 path their `AskUserQuestion` choice selected.

**Capture into state:** `state.ship_artifacts.index_path = "docs/product/flows/INDEX.md"`.

**No gate.** Q18.8 locks 0 sync gates for Phase 6.

**Failure semantics (Phase 6):** Q18.7 log + continue + skip-row marker. If a specific row's render fails (e.g., a sub-flow's story doc missing), INDEX includes a `regen-failed: <reason>` marker for that row rather than clobbering with a partial INDEX or omitting the row silently.

### 6.1 Phase 6 terminator + final breadcrumb write

After `flow-regen-index` completes, render a user-facing completion summary listing artifacts produced:

- `docs/product/master-flow-inventory.md` (1 new domain block appended)
- `docs/product/flows/<target_domain>/<sub-flow-id>.md` per sub-flow (count = N)
- `docs/product/journeys/<target_domain>.md` (1 journey doc)
- `docs/product/flows/INDEX.md` (regenerated)
- Linear: 1 milestone + 1 milestone description + N parents + 5N children + N children-summary comments = `2 + 7N` writes (list URLs grouped by sub-flow)
- L-review coverage: L2 (1 invocation, journey doc) + L3 (N invocations, parent issues) — L1 not fired (incremental-add scope)

**Final breadcrumb write:** `status: completed`, `current_phase: 6`, `completed_phases: ["1","2","3","4","5","6"]`. The Q31.5 atomic-rename write through `flow-resume-breadcrumb.sh write` is the **last operation** of the orchestrator — never write the `completed` marker before all artifacts land on disk (BC-5761 precedent applied here; BC-6962/BC-6963/BC-6965 sibling pattern).

Recommend next steps:

- Run `/flow:audit --domain=<target_domain>` (Q38; pending) for project-health snapshot scoped to the new domain.
- Run `/flow:plan-<discipline>` per discipline child for AC + Tasks population.
- Hand-edit `docs/product/journeys/<target_domain>.md` to refine narrative voice if needed (atomic rename ensures journey doc fully written; `--force` regen will clobber hand-edits per Q16.3).

**Failure semantics (6.1):** n/a — terminator. Any failure prior to the final breadcrumb write leaves breadcrumb at Phase 5 or earlier; resume picks up appropriately.

---

## Gate-respect contract

Every `AskUserQuestion` in this command — the Q20.6 within-skill confirmation, the Q13.4 pre-scaffold preview, the per-sub-flow Phase 3 retry/abort adjudication, and the Phase 1 `--force-incremental-add` warning — is bound by the gate-respect contract (`plugins/flow-architecture/skills/_shared/gate-respect.md` once promoted; cf. cadence `skills/_shared/gate-respect.md`). Once the user picks an option, execute exactly that option. To deviate, re-prompt via a new `AskUserQuestion`. Mentions in the breadcrumb, notes, or batch summaries do NOT constitute user authorization.

Origin: cadence BC-5866 precedent surfaced this class-bug across orchestrators; same discipline applies here from day 1, consistent with sibling commands `/flow:start-project` (BC-6962), `/flow:retrofit-project` (BC-6963), and `/flow:add-sub-flow` (BC-6965).

## Phase-exit breadcrumb update (canonical pattern)

Every phase ends with a breadcrumb update so resume can reason about what's complete. Each phase ID (`1` through `6`) appends at the phase's terminal step:

1. Append the phase number to `breadcrumb.completed_phases` (in order).
2. Set `breadcrumb.current_phase` to the next phase number (or leave at `6` after Phase 6).
3. Set `breadcrumb.status` (`in_flight` until Phase 6 terminator; then `completed`).
4. Refresh `breadcrumb.last_updated` with the current ISO-8601 timestamp (**NOT `updated_at`** — the helper script's stale-detection in `read` mode keys on `last_updated`; writing the wrong field name would silently break staleness checks).
5. Persist via the BC-6956 helper. The helper `write` subcommand takes two positional arguments — `<state-path>` (the breadcrumb on disk) and `<input-path>` (a `mktemp`'d file holding the new JSON) — per BC-9027. See the Phase 1 example for the canonical `python3 > $TMP_JSON <<'PY' ... PY; bash $HELPER write $BREADCRUMB_PATH $TMP_JSON; rm -f $TMP_JSON` form. Construct dynamic values inside a single-quoted python heredoc (`<<'PY'`) so Linear-derived strings cannot expand into the shell; pass `$BREADCRUMB_PATH` and `$TMP_JSON` as discrete arguments to the helper (never inside `bash -c` or an unquoted `$(...)`). The `mktemp` file intermediate replaces the previous stdin-pipe pattern, which tripped the workflows security-hook classifier.

The breadcrumb append is the **last step** of a phase, after all of the phase's artifacts (inventory block / Linear writes / story docs / journey doc / INDEX) have landed. Writing the breadcrumb earlier would let a killed session resume with a phase marked "complete" but artifact missing.

## See also

- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:745` — Q47 lock (canonical source; seven sub-decisions + refinement audit trail at line 782). Sub-decision 1 at line 747-749 locks the interactive-only invocation form; sub-decision 4 at line 766-769 locks the `delegates to Q20 — never edits inventory` boundary.
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:224` — Q20 lock (sub-skill ownership boundary; sub-flow-add vs domain-add modes; Q19-mini interview; Q20.4 hard-reject; Q20.6 within-skill gate; Q20.7 `inventory_changed` flag) + Q20 amendment 1 (BC-9971; inventory-only-domain re-scaffold branch — the four-outcome classifier table is the canonical source for § 2.0 in this file).
- `plugins/flow-architecture/scripts/flow-classify-domain-state.sh` — Q20 amendment 1 filesystem classifier (BC-9971; emits `absent` / `inventory-only` / `journey-exists` / `fully-scaffolded-fs`).
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-architecture-overview.md` §3c — plugin command surface (where this command sits in the ~17-command catalog).
- `plugins/flow-architecture/commands/add-sub-flow.md` — sibling incremental-add orchestrator (BC-6965; 5 phases / 2 gates / skips journey-author; this command is the heavier 6-phase variant that authors the new journey doc).
- `plugins/flow-architecture/commands/start-project.md` — sibling greenfield orchestrator (BC-6962; 8 phases / 4 gates / hybrid control flow; this command's per-sub-flow inner loop is the N=1-domain degenerate case of start-project's per-domain inner loop).
- `plugins/flow-architecture/commands/retrofit-project.md` — sibling retrofit orchestrator (BC-6963; 9 phases / 5 gates).
- `plugins/flow-architecture/skills/flow-preflight/SKILL.md` — Phase 1 sub-skill (BC-6957 shipped).
- `plugins/flow-architecture/scripts/flow-resume-breadcrumb.sh` — Q31.5 atomic-rename breadcrumb helper (BC-6956 shipped).
- Handbook CDR-023 — Flow-Driven Architecture (the policy this plugin implements).
- Handbook `how-we-work/operating-standards/flow-driven-architecture.md` — operating-standards page (Q34 lock).
