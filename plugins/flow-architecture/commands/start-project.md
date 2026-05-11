---
description: Greenfield Flow-Driven Architecture orchestrator — 8 phases / 4 gates / hybrid control flow per Q37 lock
---

# /flow:start-project

Greenfield UI-bearing FDA build orchestrator. Runs **8 phases / 4 user-confirmation gates** with **hybrid control flow** per Q37 lock (`plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:671`): Phase 4 is a per-domain inner loop preserving Q13.5 atomic recovery; Phases 5+6 are globally batched activating Q15.2 + Q16.2 internal parallelism. Wall ≈ 22–70 min on Brand Hub-shape projects depending on domain count.

> **Scope:** UI-bearing builds only (CDR-023 partition). Non-UI-bearing work uses CDR-014's Phase Pattern with `/workflows:fix-milestone --migrate ...`, not FDA. `flow-preflight` performs upstream mode classification — `/flow:start-project` runs only when mode resolves to `greenfield`.

> **DO NOT re-derive** the phase sequence, gate positions, L-review routing, or per-phase failure matrix below. All seven sub-decisions are locked at memory:671+ with a refinement audit trail at memory:687. Re-litigation already resolved at lock time.

## Architecture overview

```
  /flow:start-project (greenfield) — 8 phases / 4 gates
  ═══════════════════════════════════════════════════════════════════

   ┌─ Phase 1 ─┐ G1 ┌─ Phase 2 ─┐ G2 ┌─ Phase 3 ─┐ G3 ┌─ Phase 4 ─┐
   │ preflight │───►│  office-  │───►│ inventory │───►│  linear-  │
   │ bootstrap │    │   hours   │    │ interview │    │  scaffold │
   │   (Q12)   │    │   (Q42)   │    │   (Q19)   │    │   (Q13)   │
   └───────────┘    └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
                          ↓ L1 review      ↓ L2 review      ↓ L3 review
                          → intent.md      → journey stash  → parent issue
                          (CEO+Des+Eng+DX  (CEO+Des per     (5 disciplines
                          parallel)         domain)          per sub-flow)

   ┌─ Phase 4 ─┐ G4 ┌─ Phase 5 ─┐    ┌─ Phase 6 ─┐    ┌─ Phase 7 ─┐
   │  linear-  │───►│  doc-     │───►│  journey- │───►│  regen-   │
   │  scaffold │    │  author   │    │   author  │    │   index   │
   │   (Q13)   │    │   (Q15)   │    │   (Q16)   │    │   (Q18)   │
   └───────────┘    └───────────┘    └───────────┘    └─────┬─────┘
   per-domain       globally         globally               ↓
   inner loop       batched          batched           ┌─ Phase 8 ─┐
   (preserves       (Q15.2 internal  (Q16.2 internal   │ complete  │
   Q13.5 atomic     parallelism)     parallelism)      │           │
   recovery)                                           └───────────┘
                                                       status: completed
                                                       written to
                                                       breadcrumb
```

Greenfield SKIPS `flow-legacy-cross-reference` (Q14) — that's retrofit-only. Retrofit shape is 9 phases / 5 gates and lives in `/flow:retrofit-project` (BC-6963 territory).

## Breadcrumb

The orchestrator writes phase progress to `docs/plans/.flow-phase-state.json` (Q31.4 lock — note the **leading dot** on the filename; NOT `.flow/phase-state.json`) after every phase completion. Writes go through `bash $CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh write` (BC-6956 shipped) — atomic-rename via mktemp + python3 json.dump + parse-verify + content-match per Q31.5 lock. Never write the breadcrumb file directly with a heredoc.

Breadcrumb shape (per Q31.4):

```json
{
  "mode": "greenfield",
  "linear_project_id": "<uuid from .flow/config.json>",
  "linear_project_name": "<string from .flow/config.json>",
  "linear_team_key": "<e.g., BC>",
  "run_started_at": "<ISO-8601; set once at Phase 1 entry; consumed by Q29.1 index-complete gate>",
  "current_phase": "1|2|3|4|5|6|7|8",
  "completed_phases": ["1", "2", ...],
  "domains": [
    {"slug": "<domain-slug>", "scaffold_state": "pending|in_progress|completed|failed", "failure_reason": null}
  ],
  "status": "in_flight",
  "updated_at": "<ISO-8601 refreshed each write>"
}
```

`status` transitions: `in_flight` (set at Phase 1 entry) → `completed` (Phase 8 terminator) OR `abandoned` (user halt at any gate). Phase 4's per-domain inner loop maintains `domains[]` so resume can pick up at the next pending domain.

## Resume contract

`flow-preflight` is the entry — every orchestrator dispatches through it. When preflight detects an in-flight non-stale breadcrumb, it returns `MODE=resume` and the orchestrator dispatches at `current_phase`:

| Resume phase | Behavior |
|---|---|
| 1 | re-run Phase 1 (preflight + bootstrap is idempotent). |
| 2 | re-emit G1 confirmation summary from `.flow/config.json` then continue at Phase 2. |
| 3 | re-emit G2 summary from `docs/product/intent.md` then continue at Phase 3. |
| 4 | per-domain replay — iterate `breadcrumb.domains[]`; skip `scaffold_state == "completed"`; resume at first non-completed. L3 review state not persisted (re-runs per parking lot #31 v1; ~2-5 min per sub-flow). |
| 5 | re-run whole Phase 5 (~30-60s with Q15.2 internal parallelism). Q15's skip-if-exists per Q15.3 keeps already-written story docs from being clobbered without `--force`. |
| 6 | re-run whole Phase 6 (~60-90s with Q16.2 internal parallelism). L2 review state not persisted; re-runs (~2-5 min per domain) per parking lot #31 v1. Q16's skip-if-exists per Q16.3 likewise gates journey-doc clobber. |
| 7 | re-run whole Phase 7. INDEX regeneration is idempotent. |
| 8 | inline terminator; write `status: completed`. |

Stale breadcrumb handling (>7 days, or `status: completed | abandoned`, or malformed) lives inside `flow-preflight` Section 3.1 and prompts the user via `AskUserQuestion` to discard / force-resume / cancel. Orchestrator does not re-implement that policy.

## L-review routing (Q37 sub-decision 4 + Q54)

| Level | Phase | Where it fires | Output target |
|---|---|---|---|
| **L1 review** | 2 | inside `/flow:office-hours` (Q42) — 4 reviewers (CEO + Design + Engineering + Developer-experience) parallel | `docs/product/intent.md` `## L1 review summary` section |
| **L2 review** | 3 | inside `flow-inventory-interview` per domain — CEO + Design parallel | in-memory `state.l2_review_<domain>` stash; consumed by Phase 6 to populate journey doc `## L2 review summary` per Q26 mod 2 / Q16.7 optional read path |
| **L3 review** | 4 | inside `flow-linear-scaffold` per sub-flow **BEFORE** the G4 preview gate — all 5 disciplines (Story + Eng + Design + QA + Docs) parallel | Linear parent issue `## L3 review summary` section per Q23 mod 2; headlines visible in G4 preview |
| L4 review | n/a | JIT during `/flow:session-start` Step 5 — not orchestrator-driven |  — |

L-review state is **in-memory only** during single invocation per parking lot #31 v1 acceptance. On crash-resume, L2 + L3 re-run when their phase re-runs.

## Session state object

Phases flow via a single session-scoped state object. No re-fetching from filesystem or Linear between phases unless explicitly re-probed.

```
{
  "mode":              "greenfield",
  "linear_project_id": "<uuid>",
  "linear_project_name":"<string>",
  "linear_team_key":   "<e.g., BC>",
  "repo_root":         "<absolute path>",
  "run_started_at":    "<ISO-8601>",
  "current_phase":     "1..8",
  "completed_phases":  [...],
  "preamble":          { ...10 KEY=VALUE fields from flow-context-load.sh },
  "intent_path":       "docs/product/intent.md",
  "inventory_path":    "docs/product/master-flow-inventory.md",
  "inventory":         { "domains": [ { "slug", "display_name", "sub_flows": [...] } ] },
  "domains":           [ { "slug", "scaffold_state", "failure_reason", "parent_issue_ids": [...] } ],
  "l1_review":         { "summary_written_at": "<ISO-8601 | null>" },
  "l2_review":         { "<domain-slug>": "<in-memory blob>" },
  "l3_review":         { "<sub-flow-id>": "<in-memory blob>" },
  "ship_artifacts":    { "story_docs": [...], "journey_docs": [...], "index_path": "..." },
  "status":            "in_flight"
}
```

This object is **session-scoped**. The breadcrumb is the persistent projection — `current_phase`, `completed_phases[]`, `domains[]`, `run_started_at`, `status`. L-review state is not breadcrumb-persisted (parking lot #31 v1).

## The 4 user gates

- **G1 (1→2):** bootstrap completed; `.flow/config.json` written + verified.
- **G2 (2→3):** PROJECT-INTENT.md content review (post-office-hours, L1-vetted).
- **G3 (3→4):** `master-flow-inventory.md` content review (post-inventory-interview, L2 stashed per domain).
- **G4 (3→4):** pre-scaffold batch preview consolidating ALL domains' planned scaffolds — NOT N separate gates. L3 reviews per sub-flow already populated at this point.

Phases 5/6/7 run without further orchestrator gates per Q15.6 / Q16.6 / Q18.8 lock 0 sync gates each.

## Per-phase failure matrix (Q37 sub-decision 6 — verbatim from memory:683)

| Phase | Failure semantics |
|---|---|
| 1 | fail-closed per Q36.5. No partial `.flow/config.json` on disk — atomic-rename guarantees absent-or-complete. |
| 2 | pause at G2 + retry. User can re-run office-hours; intent.md gets re-written via Q41 template + Q42 L1-review write. |
| 3 | Q19.6 interview-loop max-retry. Inventory append is hard-rejected on duplicate per Q20.4. |
| 4 | per-domain Q13.5 sub-flow-atomic recovery — failure isolated to one domain. Orchestrator pauses inner loop for user adjudication (`AskUserQuestion`: retry / skip-domain / abort). On user choice "retry" or "skip", inner loop resumes with the next pending domain in `breadcrumb.domains[]`. |
| 5 | log + continue per Q15.5. Operating at global batch scope — partial Q15 failures surface in batch summary. Orchestrator does NOT roll back since outputs are filesystem writes reviewable via `git diff` + `verify-docs.sh`. |
| 6 | log + continue per Q16.5 (same shape as Phase 5). |
| 7 | Q18.7 log + continue + skip-row marker. INDEX renders a "regen-failed: <reason>" row instead of clobbering with a partial INDEX. |
| 8 | n/a — terminator. |
| user halt at any gate | breadcrumb `status: abandoned` with `reason: 'user-cancel-at-<gate>'`; future `/flow:start-project` invocation detects abandoned + offers discard per Q31.3 stale-breadcrumb policy. |

---

## Phase 1: preflight + bootstrap

**Sub-skill:** `flow-preflight` (Q12 + Q36 embedded 7-step bootstrap; BC-6957 shipped at `plugins/flow-architecture/skills/flow-preflight/SKILL.md`).

**Pre-flow-preflight setup:** the orchestrator owns the `LINEAR_ISSUE_COUNT` env-var per flow-preflight Section 6.4 ownership note. Before dispatch:

```bash
LINEAR_ISSUE_COUNT="$(... list_issues scoped to candidate project, limit: 10 ...)"
export LINEAR_ISSUE_COUNT
```

The `limit: 10` cap matches the Q36.3 step-4 threshold IS the cap behavior — a returned count of exactly 10 means "≥ 10" without paginating. If the candidate project isn't yet known (first-ever run with no `.flow/config.json`), pass `LINEAR_ISSUE_COUNT=` (empty) and flow-preflight degrades to `greenfield` by default per Section 6.4.

**Run:**

```bash
# Dispatch flow-preflight inline (skill is disable-model-invocation: true,
# user-invocable: false — orchestrators call directly).
```

flow-preflight runs its 5 environment checks (Section 1), FDA-artifact discovery (Section 2), mode classification (Section 3), Linear scope confirmation (Section 4), preamble emission (Section 5), and on first-run the Q36 7-step bootstrap (Section 6).

**Mode guard:** if flow-preflight emits `MODE != greenfield`, surface error redirect per Q47 sub-decision 3 and STOP:

- `MODE=retrofit` → `"Project has legacy work signal. Use /flow:retrofit-project to retrofit FDA shape, then /flow:add-* for incremental additions."`
- `MODE=incremental-add` → `"Project already has FDA shape. Use /flow:add-domain (new domain) or /flow:add-sub-flow (new flow under existing domain)."`
- `MODE=resume` → orchestrator dispatches at breadcrumb's `current_phase` per the Resume contract section above.

**Capture from preamble** (10 KEY=VALUE fields per flow-preflight Section 5):

- `LINEAR_PROJECT_ID`, `LINEAR_PROJECT_NAME`, `LINEAR_TEAM_KEY` (last derived from `.flow/config.json`)
- `REPO_ROOT`
- `INTENT_EXISTS`, `INVENTORY_EXISTS`, `FLOWS_DIR_EXISTS`, `BREADCRUMB_EXISTS` (all `no` for fresh greenfield)
- `GH_AUTH`, `LINEAR_MCP` (orchestrator already probed Linear in flow-preflight Section 1.1)

**Initial breadcrumb write:** at end of Phase 1, set `run_started_at` (ISO-8601 now), `current_phase: 2`, `completed_phases: ["1"]`, `status: in_flight`, empty `domains: []`. Dispatch:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh" write \
  --mode greenfield \
  --current-phase 2 \
  --completed-phases 1 \
  --status in_flight
```

### Gate G1 (1→2)

`AskUserQuestion`:

> "Phase 1 complete. `.flow/config.json` written for Linear project `<LINEAR_PROJECT_NAME>` (team `<LINEAR_TEAM_KEY>`). Continue to Phase 2 (office-hours intent capture)?"

Options:

- **Continue to Phase 2** *(Recommended)*
- **Pause + resume later** — exits cleanly; breadcrumb retains `status: in_flight`; next `/flow:start-project` invocation resumes at Phase 2.
- **Cancel session** — write `status: abandoned`; exit cleanly.

**Failure semantics (Phase 1):** fail-closed per Q36.5. No partial `.flow/config.json`. Any failure inside flow-preflight surfaces verbatim with the remediation hint flow-preflight emitted.

---

## Phase 2: office hours

**Sub-skill / command:** `/flow:office-hours` (Q42 — pending; orchestrator references by name; pre-shipped sub-skill names locked in interview record at memory:671).

**Run:** dispatch `/flow:office-hours`. The command:

1. Captures the project mission, target users, problem, success criteria, out-of-scope, and constraints via guided interview per Q41 template (`docs/product/intent.md` skeleton at `handbook/about-handbook/style-guide/templates/project-intent.md`).
2. Fires the **L1 review** — 4 reviewers (CEO + Design + Engineering + Developer-experience) in parallel — and writes one-paragraph headlines into the `## L1 review summary` section of `intent.md`. The Q42 write uses Q31.5 atomic-rename per Q41 sub-decision 5.
3. Updates intent.md front-matter `l1_reviewed` to the current ISO-8601 timestamp.

**Output:** `docs/product/intent.md` exists; front-matter populated; all 7 required body sections present; `## L1 review summary` populated.

**Capture into state:** `state.intent_path`, `state.l1_review.summary_written_at`.

**Breadcrumb update:** `current_phase: 3`, `completed_phases: ["1", "2"]`.

### Gate G2 (2→3)

`AskUserQuestion`:

> "Phase 2 complete. `docs/product/intent.md` written + L1 multi-perspective review embedded. Review the intent doc before proceeding to inventory."

Options:

- **Continue to Phase 3** *(Recommended)* — intent looks right; proceed to inventory interview.
- **Re-run office-hours** — re-enter Phase 2; previous intent.md is preserved (`/flow:office-hours` skip-if-exists + `--force` semantics).
- **Pause + resume later** — exits cleanly; resumes at Phase 3 next run.
- **Cancel session** — write `status: abandoned`; exit cleanly.

**Failure semantics (Phase 2):** pause at G2 + retry. If `/flow:office-hours` fails mid-run (e.g., L1 reviewer dispatch error, file-write failure), surface error; user re-runs Phase 2.

---

## Phase 3: inventory

**Sub-skill:** `flow-inventory-interview` (Q19; not yet shipped — orchestrator references by name).

**Run:** dispatch `flow-inventory-interview`. The skill:

1. Reads `docs/product/intent.md` as Phase 0 priority filter per Q19 Phase 0 input contract (memory:192).
2. Runs the Q19.6 interview-loop to enumerate domains + their sub-flows. Hard-rejects duplicate domain or sub-flow IDs per Q20.4.
3. Fires the **L2 review** per domain — CEO + Design parallel — and the orchestrator stashes each domain's L2 output as `state.l2_review_<domain-slug>` for Phase 6 hand-off (in-memory only per parking lot #31 v1; on crash-resume, Phase 6 re-runs L2 — ~2-5 min per domain).
4. Writes `docs/product/master-flow-inventory.md` via atomic-rename.

**Capture into state:** `state.inventory_path`, `state.inventory.domains[]`, `state.l2_review.<domain-slug>` per domain.

**Initialize `state.domains[]` from inventory:** for each domain in `state.inventory.domains[]`, append `{slug, scaffold_state: "pending", failure_reason: null, parent_issue_ids: []}` to `state.domains[]`. Persist to breadcrumb `domains[]` for Phase 4's per-domain resume support.

**Breadcrumb update:** `current_phase: 4`, `completed_phases: ["1", "2", "3"]`, `domains: [...]`.

### Gate G3 (3→4)

`AskUserQuestion`:

> "Phase 3 complete. `docs/product/master-flow-inventory.md` written + L2 reviews stashed per domain. Review inventory before scaffold preview."

Options:

- **Continue to G4 batch preview** *(Recommended)* — inventory looks right; proceed to Phase 4 scaffold preview consolidating all domains.
- **Edit inventory + re-run** — opens the inventory doc for hand-edit; user can then re-trigger Phase 3 via re-invocation (skip-if-exists + `--force` semantics in Q19).
- **Pause + resume later** — exits cleanly; resumes at Phase 4 next run.
- **Cancel session** — write `status: abandoned`; exit cleanly.

**Failure semantics (Phase 3):** Q19.6 interview-loop max-retry. Q20.4 duplicate-ID hard-reject surfaces user-visible error; orchestrator does not retry automatically.

---

## Phase 4: linear scaffold (per-domain inner loop)

**Sub-skill:** `flow-linear-scaffold` (Q13; not yet shipped — orchestrator references by name).

This is the **per-domain inner loop** — orchestrator iterates over `state.domains[]` and invokes `flow-linear-scaffold` one domain at a time. This preserves Q13.5's sub-flow-atomic failure recovery semantics + Q13.4's per-domain preview content (consolidated by orchestrator at G4 below).

**Per-domain footprint** (Q13 lock): 1 milestone + 1 parent per sub-flow + 5 children per sub-flow + chains + labels = `2 + 7N` writes per domain where N = sub-flow count.

### 4.1 Inner-loop iteration

For each domain in `state.domains[]` (in inventory order):

1. **Skip-if-completed:** if `breadcrumb.domains[<i>].scaffold_state == "completed"`, skip (resume support).
2. **L3 review fires INSIDE flow-linear-scaffold** per sub-flow per Q23 mod 2 — all 5 disciplines (Story + Eng + Design + QA + Docs) in parallel. Headlines populate the parent issue's `## L3 review summary` section **before** the G4 preview gate so the preview includes L3 headlines for human review.
3. **Per-domain preview content** computed deterministically from inventory + parent issue numbers — used in G4 consolidation below.
4. **Domain scaffold execution gated by G4:** the orchestrator does NOT execute Linear writes for this domain inside 4.1. Per-domain Q13.4 preview content is collected; **G4** (next subsection) consolidates ALL domains' previews into a single user-facing preview; only after G4 approval does the orchestrator execute Linear writes for all approved domains.

### 4.2 Aggregate previews + Gate G4 (3→4)

After the inner loop completes (all domains' previews collected, all L3 reviews fired + parent `## L3 review summary` populated), present **a single consolidated preview** via `AskUserQuestion`:

> "Phase 4 scaffold preview — ALL domains consolidated:
>
> - **Domain `<slug-1>` (`<N>` sub-flows):** `<2+7N>` Linear writes — `<headline summary>`. L3 review headlines: `<one-line per discipline>`.
> - **Domain `<slug-2>` (`<M>` sub-flows):** `<2+7M>` writes — `<headline summary>`. L3 headlines: ...
> - ...
>
> Total: `<sum>` writes across `<D>` domains. Apply all?"

Options:

- **Apply all** *(Recommended)* — execute Linear writes for every domain. Per-domain Q13.5 atomic recovery applies during execution (see 4.3).
- **Apply per-domain (re-prompt)** — re-prompt per domain (preserves Q13.4's per-domain semantics for users who want finer control). Each per-domain decision applies / skips that domain's writes.
- **Edit before applying** — surface the underlying inventory + L3 review content; user edits + re-runs Phase 4.
- **Pause + resume later** — exits cleanly; resumes at Phase 4 next run; in-memory L3 state lost (re-runs per parking lot #31 v1).
- **Cancel session** — write `status: abandoned`; exit cleanly.

This is **a single G4 gate**, NOT N separate gates for N domains (Q37 sub-decision 3 explicit lock). User authorization at G4 covers the whole batch.

### 4.3 Per-domain execution with Q13.5 atomic recovery

After G4 approval, orchestrator iterates `state.domains[]` and invokes `flow-linear-scaffold` for each domain to execute that domain's Linear writes. **Q13.5 sub-flow-atomic recovery applies per domain:**

- On success: mark `breadcrumb.domains[<i>].scaffold_state = "completed"`, capture `parent_issue_ids[]`, write breadcrumb.
- On failure: mark `breadcrumb.domains[<i>].scaffold_state = "failed"`, set `failure_reason`, write breadcrumb. Orchestrator pauses inner loop via `AskUserQuestion`:

  > "Domain `<slug>` scaffold failed: `<reason>`. How should I proceed?"
  >
  > - **Retry this domain** — re-invoke `flow-linear-scaffold` for `<slug>`.
  > - **Skip this domain + continue** — leave Linear writes incomplete for `<slug>`; mark `scaffold_state = "failed"`; continue inner loop with next pending domain.
  > - **Abort Phase 4** — write `status: abandoned` to breadcrumb; exit. Successful domains remain scaffolded.

After all domains processed (any combination of completed / failed / skipped), proceed to Phase 5 with the domains that completed successfully.

**Breadcrumb update at end of Phase 4:** `current_phase: 5`, `completed_phases: ["1", "2", "3", "4"]`, `domains[].scaffold_state` reflecting per-domain outcome.

**Failure semantics (Phase 4):** per-domain Q13.5 sub-flow-atomic recovery — failure isolated to one domain; orchestrator pauses inner loop for user adjudication then resumes with remaining domains.

---

## Phase 5: doc author (globally batched)

**Sub-skill:** `flow-doc-author` (Q15; not yet shipped — orchestrator references by name).

This phase is **globally batched** — orchestrator invokes `flow-doc-author` ONCE with all N domains' sub-flows. This activates Q15.2's per-sub-flow internal parallelism (~30-60s wall regardless of N).

**Pre-condition:** Phase 4 completed; `state.domains[]` populated with parent issue IDs per completed domain.

**Run:** dispatch `flow-doc-author` with the full set of sub-flows from `state.inventory.domains[*].sub_flows[*]`, filtered to domains where `scaffold_state == "completed"`. The skill:

1. Reads `intent.md` + `master-flow-inventory.md` + per-sub-flow parent issue (for L3 headlines + AC).
2. Writes story docs at `docs/product/flows/<domain>/<sub-flow-id>.md` per sub-flow.
3. Q15.2 internal parallelism dispatches per-sub-flow drafters concurrently.
4. Skip-if-exists per Q15.3: existing story docs preserved unless `--force` flag passed.
5. Q15.5 log + continue: partial failures within the batch surface in batch summary; orchestrator does NOT roll back successful writes.

**Capture into state:** `state.ship_artifacts.story_docs[]`.

**No gate.** Q15.6 locks 0 sync gates for Phase 5. The phase runs to completion (or partial-with-batch-summary) and dispatches to Phase 6.

**Breadcrumb update:** `current_phase: 6`, `completed_phases: ["1", "2", "3", "4", "5"]`.

**Failure semantics (Phase 5):** log + continue per Q15.5. Partial Q15 failures surface in batch summary; outputs are filesystem writes reviewable via `git diff` + `bash scripts/verify-docs.sh`.

---

## Phase 6: journey author (globally batched)

**Sub-skill:** `flow-journey-author` (Q16; not yet shipped — orchestrator references by name).

This phase is **globally batched** — orchestrator invokes `flow-journey-author` ONCE with all N domains. This activates Q16.2's per-domain internal parallelism (~60-90s wall regardless of N).

**Pre-condition:** Phase 5 completed; story docs written for all completed domains.

**Run:** dispatch `flow-journey-author` with the full set of domains from `state.inventory.domains[]`, filtered to `scaffold_state == "completed"`. The skill:

1. Reads `intent.md` + `master-flow-inventory.md` + per-domain story docs + `state.l2_review_<domain>` stash from Phase 3.
2. Writes journey docs at `docs/product/journeys/<domain>.md` per domain.
3. Populates each journey doc's `## L2 review summary` section from the stash per Q26 mod 2 / Q16.7 optional read path.
4. Q16.2 internal parallelism dispatches per-domain drafters concurrently.
5. Skip-if-exists per Q16.3: existing journey docs preserved unless `--force` flag passed.
6. Q16.5 log + continue: partial failures within the batch surface in batch summary.

**Capture into state:** `state.ship_artifacts.journey_docs[]`.

**No gate.** Q16.6 locks 0 sync gates for Phase 6.

**Breadcrumb update:** `current_phase: 7`, `completed_phases: ["1", "2", "3", "4", "5", "6"]`.

**Failure semantics (Phase 6):** log + continue per Q16.5. Same shape as Phase 5.

---

## Phase 7: regen index

**Sub-skill:** `flow-regen-index` (Q18; not yet shipped — orchestrator references by name).

**Run:** dispatch `flow-regen-index`. The skill regenerates `docs/product/flows/INDEX.md` from `master-flow-inventory.md` + per-domain story doc presence. Idempotent — re-running yields the same INDEX content for the same input.

**No gate.** Q18.8 locks 0 sync gates for Phase 7.

**Capture into state:** `state.ship_artifacts.index_path`.

**Breadcrumb update:** `current_phase: 8`, `completed_phases: ["1", "2", "3", "4", "5", "6", "7"]`.

**Failure semantics (Phase 7):** Q18.7 log + continue + skip-row marker. If a specific row's render fails (e.g., a sub-flow's story doc missing), INDEX includes a "regen-failed: <reason>" marker for that row rather than clobbering with a partial INDEX or omitting the row silently.

---

## Phase 8: complete

Inline terminator phase. No sub-skill dispatch — orchestrator owns the final summary + breadcrumb write.

**Run:**

1. Render user-facing completion summary listing artifacts produced:
   - `docs/product/intent.md`
   - `docs/product/master-flow-inventory.md`
   - `docs/product/flows/<domain>/<sub-flow>.md` per sub-flow (count + sample paths)
   - `docs/product/journeys/<domain>.md` per domain
   - `docs/product/flows/INDEX.md`
   - Linear: `<N>` milestones + `<sum>` parent issues + `<sum × 5>` discipline children — list URLs grouped by domain
   - L-review coverage: L1 (1 invocation, intent.md) + L2 (`<D>` invocations, journey docs) + L3 (`<sum>` invocations, parent issues)

2. **Final breadcrumb write:** `status: completed`, `current_phase: 8`, `completed_phases: ["1"..."8"]`. The Q31.5 atomic-rename write through `flow-resume-breadcrumb.sh write` is the **last operation** of the orchestrator — never write the `completed` marker before all artifacts land on disk (BC-5761 precedent applied here).

3. Recommend next steps:
   - Run `/flow:audit` (Q38; BC-? — pending) for project-health snapshot covering the 35-gate stack.
   - Run `/flow:plan-<discipline>` per discipline child for AC + Tasks population.
   - Hand-edit `docs/product/journeys/<domain>.md` to refine narrative voice if needed (atomic rename ensures journey doc fully written; `--force` regen will clobber hand-edits per Q16.3).

**Failure semantics (Phase 8):** n/a — terminator. Any failure prior to the final breadcrumb write leaves breadcrumb at Phase 7 or earlier; resume picks up appropriately.

---

## Gate-respect contract

Every `AskUserQuestion` in this command — G1, G2, G3, G4, per-domain Phase 4 adjudication prompts, and Phase 4.2's "Apply per-domain (re-prompt)" escape — is bound by the gate-respect contract (`plugins/flow-architecture/skills/_shared/gate-respect.md` once promoted; cf. cadence `skills/_shared/gate-respect.md`). Once the user picks an option, execute exactly that option. To deviate, re-prompt via a new `AskUserQuestion`. Mentions in the breadcrumb, notes, or batch summaries do NOT constitute user authorization.

Origin: cadence BC-5866 precedent surfaced this class-bug across orchestrators; same discipline applies here from day 1.

## Phase-exit breadcrumb update (canonical pattern)

Every phase ends with a breadcrumb update so resume can reason about what's complete. Each phase ID (`1` through `8`) appends at the phase's terminal step:

1. Append the phase number to `breadcrumb.completed_phases` (in order).
2. Set `breadcrumb.current_phase` to the next phase number (or leave at `8` after Phase 8).
3. Set `breadcrumb.status` (`in_flight` until Phase 8 terminator; then `completed`).
4. Refresh `breadcrumb.updated_at` with the current ISO-8601 timestamp.
5. Persist via `bash $CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh write ...` (BC-6956 helper; Q31.5 atomic-rename).

The breadcrumb append is the **last step** of a phase, after all of the phase's artifacts (intent.md / inventory / Linear writes / story docs / journey docs / INDEX) have landed. Writing the breadcrumb earlier would let a killed session resume with a phase marked "complete" but artifact missing.

## See also

- `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:671` — Q37 lock (canonical source; seven sub-decisions + refinement audit trail at line 687).
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-architecture-overview.md` §3e — Greenfield Orchestrator Phase Flow (synthesis view).
- `plugins/flow-architecture/skills/flow-preflight/SKILL.md` — Phase 1 sub-skill (BC-6957 shipped).
- `plugins/flow-architecture/scripts/flow-resume-breadcrumb.sh` — Q31.5 atomic-rename breadcrumb helper (BC-6956 shipped).
- `plugins/cadence/commands/weekly.md` — orchestrator precedent (5 phases / 3 gates / phase-state breadcrumb / gate-respect contract).
- Handbook CDR-023 — Flow-Driven Architecture (the policy this plugin implements).
- Handbook `how-we-work/operating-standards/flow-driven-architecture.md` — operating-standards page (Q34 lock).
