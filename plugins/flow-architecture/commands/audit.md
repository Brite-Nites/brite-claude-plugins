---
description: Flow-Driven Architecture quality-gate runner — three-phase pipeline (verify-docs → filesystem gates → Linear MCP gates) emitting markdown or --json over Q29's 35-gate stack
---

# /flow:audit

Utility command. Single-purpose runner for the Q29 35-gate quality-gate stack (`plugins/flow-architecture/skills/_shared/artifact-gate-pattern.md`). Three phases / **zero user-confirmation gates between internal steps** (utility, not orchestrator) / READ-ONLY against the filesystem and Linear MCP. Default wall ≈ 14s on a 28-domain Brand-Hub-shape project (Q38 sub-decision 3 batched-list-issues optimization); ~125s without batching.

> **Scope:** UI-bearing FDA projects (CDR-023). Non-UI-bearing work uses CDR-014's Phase Pattern + `/workflows:fix-milestone --migrate ...`, not this audit. The audit assumes the consuming project has been bootstrapped through `flow-preflight` (Q12 + Q36 embedded 7-step bootstrap) and has FDA artifacts on disk; absent artifacts surface as Q29.1 phase-transition gate failures, not infrastructure errors.

> **DO NOT re-derive** the gate manifest, hard/soft classification, override mechanism, or three-section reporting format. All seven sub-decisions of Q38 are locked at `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:700` with a refinement audit trail at `:716`. Q38 sub-decision 4's "stays strictly local in v1" deferred-decision resolution is locked at `:730`. Re-litigation already resolved at lock time. Q29's full 35-gate manifest is locked at `:240` and surfaced via `_shared/artifact-gate-pattern.md`; this command is the runner for that manifest, not a re-statement of it.

> **`/flow:audit` vs `/flow:review` boundary** (plugin CLAUDE.md § Boundaries; Q52 sub-decision 4). `/flow:audit` checks **FDA process compliance** (filesystem-existence + Linear-state checks against the 35-gate stack). `/flow:review` runs **diff-level code-review agents** (P1/P2/P3 findings, simplification pass). Distinct purposes. `/flow:audit` auto-invokes before `/flow:ship`; `/flow:review` is invoked when the user wants diff-level review. A `--audit-preflight` flag for `/flow:review` is a v1.1 candidate (parking lot #48) if Brand Hub dogfood reveals demand for bundled coverage.

## Architecture overview

```
  /flow:audit — three-phase, halt-aware pipeline
  ═══════════════════════════════════════════════════════════════════════

   ┌─ Phase A ──────────┐    ┌─ Phase B ──────────┐    ┌─ Phase C ──────────┐
   │ verify-docs.sh     │───►│ deterministic       │───►│ Linear MCP gates    │
   │ (mechanical:        │    │ filesystem gates    │    │ (Q29.3 cross-       │
   │  build/lint/test    │    │ (Q29.2 22 per-flow  │    │  cutting + Q29.2    │
   │  + internal links   │    │  checks + Q29.1     │    │  Eng/Design/Docs    │
   │  + orphan flow IDs  │    │  file-existence     │    │  state checks via   │
   │  + front-matter     │    │  phase-transition   │    │  batched list_issues│
   │  + stale dates)     │    │  gates)             │    │  per-domain)        │
   └────────┬───────────┘    └────────┬────────────┘    └────────┬───────────┘
            │ exit !=0                │                          │
            ▼                         ▼                          ▼
       Phase B+C              Hard-gate fail →             Hard-gate fail →
       marked                 AskUserQuestion              AskUserQuestion
       skipped                Fix-now / Override /         Fix-now / Override /
       (verify-docs           Halt (Q29.5; record          Halt (Q29.5; record
       failed)                in breadcrumb                in breadcrumb
                              overrides[])                 overrides[])
                                                                  ↓
                                                    Render Q29.6 three-section
                                                    markdown (or --json) +
                                                    Summary line + Overrides
                                                    section (with stale-
                                                    override re-evaluate
                                                    sub-section)
```

The pipeline is **halt-aware** at the Phase A boundary only: a non-zero exit from `verify-docs.sh` marks Phase B+C as skipped (`skipped (verify-docs failed)`) without running them — exit code 2. Within Phases B and C, hard-gate failures do NOT halt the run; they accumulate in the report and trigger the override `AskUserQuestion` per Q29.5.

## Invocation

`/flow:audit [--domain=<CODE>] [--flow=<DOMAIN-NN>] [--discipline={story|eng|design|qa|docs}] [--gate=<id>] [--json] [--no-verify-docs]`

All args are flag-based (vs positional) per Q38 sub-decision 1 — explicit naming + composability. Defaults: full-project markdown report.

| Flag | Purpose |
|---|---|
| `--domain=<CODE>` | Filter to one domain's gates. Example: `--domain=TEAM` runs only TEAM's per-flow + cross-cutting gates that touch TEAM. |
| `--flow=<DOMAIN-NN>` | Filter to a single flow. Example: `--flow=TEAM-09` runs only TEAM-09's 22 per-flow gates. |
| `--discipline={story\|eng\|design\|qa\|docs}` | Filter to one discipline's child-completion gates across the selected scope. Composable with `--domain` and `--flow`. |
| `--gate=<id>` | Re-run a single gate by stable ID (useful for fix-and-verify cycles). Example: `--gate=parent-l3-summary-populated`. |
| `--json` | Emit machine-readable output for CI scripting. See § Output formats. |
| `--no-verify-docs` | Skip Phase A. **Debugging only** — bypasses the mechanical-layer pre-flight; downstream gate output may be misleading if mechanical issues exist. |

**Filter composition.** Filters compose intersectionally: `--domain=TEAM --discipline=eng` runs TEAM's [Eng] gates only (Q29.2 4 checks per flow × N TEAM flows + the relevant cross-cutting subset). `--flow=TEAM-09 --gate=parent-l3-summary-populated` re-runs that single gate against TEAM-09's parent.

**Invalid args** — surface a clear usage error and exit 64 (`os.EX_USAGE`).

## Auto-invocation contract

`/flow:audit` is both **user-invocable** and **auto-invocable**. Per Q38 sub-decision 5:

- **Called by `/flow:ship`** (Q53) as a ship-readiness check — hard-gate failures halt the ship. The ship command invokes `/flow:audit --domain=<DOMAIN>` scoped to the affected domain.
- **Called by `/flow:plan-{discipline}`** (Q43 children) pre-completion, scope-filtered to that discipline child. Example: `/flow:plan-eng` invokes `/flow:audit --flow=<DOMAIN-NN> --discipline=eng` before generating plan content.
- **NOT called by orchestrators** (`/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`) — orchestrators have their own per-phase artifact-existence gates per Q7's filesystem-artifact-existence semantics, and double-firing during scaffold would be expensive without informational benefit (the gates are already evaluated at scaffold time).
- **NOT called by `/flow:session-start`** (Q51) — frequency × Linear MCP cost (~14s) is non-trivial; the user can run `/flow:audit` explicitly when they want a project-health snapshot.

## Phase A — verify-docs.sh

Run the consuming project's mechanical-layer documentation verifier:

```bash
bash scripts/verify-docs.sh
```

`verify-docs.sh` is **owned by the consuming project**, not the FDA plugin (the plugin assumes BriteBase / Brand Hub / equivalent infrastructure provides it). Per Q29.7 lock: leverage existing infrastructure rather than duplicating it. The script's contract: build / lint / test + internal-link integrity + orphan-flow-IDs check + front-matter presence + stale-date detection. Output goes to stdout; exit code is the signal.

**On non-zero exit:**

- Mark Phase B + Phase C entries as `skipped (verify-docs failed)` in the audit report.
- Render the audit summary with the skip annotation.
- Set the process exit code to `exit 2` (Phase B+C skipped due to verify-docs.sh failure).
- The user fixes the mechanical issues first, then re-runs `/flow:audit`.

**On zero exit:** proceed to Phase B.

**`--no-verify-docs` skip path** (debugging only): skip Phase A entirely; do NOT mark Phase B+C as skipped (run them normally). This flag exists for fix-and-verify cycles where the user knows mechanical issues remain but wants a B+C snapshot anyway. Surface a warning in the report header: `WARNING: --no-verify-docs in effect; mechanical-layer pre-flight skipped.`

## Phase B — deterministic filesystem gates

Run the Q29.2 22 per-flow discipline-child checks plus the Q29.1 phase-transition gates that don't require Linear MCP. These are pure filesystem-artifact-existence + regex-match checks, scriptable, deterministic, re-runnable per Q7 (`docs/design-rationale/project_fda_plugin_interview.md:60`).

**Q29.1 phase-transition file-existence gates evaluated in Phase B (no Linear MCP needed):**

- `intent-exists` — `docs/product/intent.md` exists with required sections (per Q41).
- `inventory-complete` — `master-flow-inventory.md` has ≥1 domain section. (The orphan-flow-IDs check inside this gate ran in Phase A via `verify-docs.sh`; Phase B re-confirms section count.)
- `scaffold-complete` per domain — `.flow/scaffold-log/<domain>.md` has rows for 1 milestone + N parents + 5N children with `result: executed` or `skipped-idempotent`. (Linear-side state is verified in Phase C.)
- `story-docs-complete` per domain — N story-doc files at `docs/product/flows/<domain>/*.md` for all N flows in the domain.
- `journey-complete` per domain — `docs/product/journeys/<domain>.md` exists.
- `index-complete` — `INDEX.md` `generated_at` >= the most recent breadcrumb's `run_started_at`. Reads `docs/plans/.flow-phase-state.json` if present; if absent, the gate is informational-only (no breadcrumb means no orchestrator run to compare against).

**Q29.2 per-flow discipline-child checks** (22 per flow; aggregated from `_shared/artifact-gate-pattern.md`):

- **[Story] (5 checks)** — story doc exists at `docs/product/flows/<domain>/<flow-id>.md`; required front-matter populated; job-story sentence matches regex `^> \*\*When\*\*.*\*\*I want to\*\*.*\*\*so I can\*\*`; AC has 3-5 Gherkin `Scenario:` blocks; story doc passes `verify-docs.sh` (re-checked from Phase A output).
- **[Eng] (4 checks)** — Linear [Eng] child `state.type == "completed"` (Phase C); `npm run build && npm run lint && npm test` pass on `main` (delegated to `verify-docs.sh` integration in Phase A); sandbox URL HTTP 200 (Phase C HTTP smoke-test); story-doc front-matter `children.engineering` populated.
- **[Design] (3 checks)** — Linear [Design] child `state.type == "completed"` (Phase C); `figma:` field with node ID matches `figma\.com/file/.*\?node-id=` (filesystem regex); story-doc front-matter `children.design` populated.
- **[QA] (5 checks)** — story-doc front-matter `qa_status: signed-off`; valid `qa_last_signed_off` ISO-8601; QA history table has ≥1 row with `signed-off`; structured QA-run comment posted on Linear QA child (Phase C, signature match via `list_comments`); story-doc front-matter `children.qa` populated.
- **[Docs] (5 checks)** — customer-doc file exists at `docs/product/customer-docs/<domain>/<flow-id>.md`; customer-doc front-matter populated per Q28 schema; `user_docs_url` non-TBD; customer-doc passes `verify-docs.sh` (re-checked from Phase A); story-doc front-matter `children.docs` populated.

Phase B emits one `gate.status` entry per evaluated check into the report. Filter args (`--domain`, `--flow`, `--discipline`) gate which checks fire — unfiltered checks are simply not evaluated (not marked skipped — they are out of scope for the requested audit).

## Phase C — Linear MCP gates

Run the Q29.3 cross-cutting consistency gates plus the Q29.2 [Eng]/[Design]/[Docs] state-completion checks that need Linear MCP reads. All read-only.

**Q38 sub-decision 3 — Linear MCP batching (inline implementation).** Use batched `list_issues({labels: ["domain:<slug>"]})` per domain instead of naive per-child `get_issue`. Wall-time delta on a 50-flow / 28-domain project: ~14s batched vs ~125s naive. Implementation is a ~10-line inline re-implementation of Q18.3's batching pattern, NOT a shared utility — parking lot #27 reserves promotion to `_shared/linear-batched-list-pattern.md` for v1.1 only if a third caller (Q43 plan-X dispatcher, Q53 ship, or Q46 writeback) needs the pattern.

Concretely, for each in-scope domain:

```
batched_issues_for_domain[<slug>] = list_issues({
  team: <project_team_key from .flow/config.json>,
  labels: ["domain:<slug>"],
  limit: 250,            # cap; pages if domain has more children (rare)
})
```

Then evaluate per-child gates against the batched response in memory — never per-child `get_issue` for the routine state checks. (Single `get_issue` calls remain acceptable for one-off `--gate=<id> --flow=<DOMAIN-NN>` re-runs targeting a single child where the batched optimization is moot.)

**Q29.3 cross-cutting consistency gates (5):**

- `inventory-story-doc-id-match` — every story doc's `flow_id` front-matter exists as a row in `master-flow-inventory.md`. (Filesystem-only; included in Phase C for grouping with the other cross-cutting gates.)
- `index-story-doc-status-match` — `INDEX.md` Status column matches story-doc front-matter `status` field.
- `linear-children-match` — story-doc `children.*` BC numbers match the actual Linear `parentId` chain. Uses the batched response per domain.
- `parent-l3-summary-populated` — Linear parent issue body contains `## L3 review summary` section with 5 discipline headlines (Q23 mod 2). This is the **L3 review coverage gate** per Q38 sub-decision 2 clarification.
- `milestone-subflows-table-match` — Linear domain milestone description's Sub-flows table matches actual children of that milestone (Q22 schema).

**L-review coverage (Q38 sub-decision 2 clarification).** L3 is gated via `parent-l3-summary-populated` above. **L2 is intentionally NOT gated** — Q26 mod 2 locks `## L2 review summary` as optional, so a missing L2 section is not a hard-gate fail. **L1 coverage will fold in when Q41 (PROJECT-INTENT.md template) lands and tightens Q29.1's `intent-exists` required-sections list** — until then, no L1 gate fires.

**Q29.2 [Eng]/[Design]/[Docs] Linear-state checks** are intermixed with Phase B's filesystem-side checks for those disciplines: a single per-flow discipline grade aggregates filesystem + Linear-state checks for that discipline. Phase C provides the Linear-side input; Phase B owns aggregation in the per-flow report row.

## Output formats

### Markdown (default per Q29.6)

Three-section report plus Summary line plus Overrides section:

```
# /flow:audit report — <project name>

Run started: <ISO-8601>
Filters: <flag echo or "none">
Mode: <verify-docs ran | --no-verify-docs in effect>

## Phase status

| Phase | Status | Notes |
|---|---|---|
| A — verify-docs.sh | <PASS/FAIL/SKIPPED> | <stdout snippet on fail> |
| B — filesystem gates | <PASS/PARTIAL/SKIPPED> | <count: X pass / Y soft / Z hard-fail> |
| C — Linear MCP gates | <PASS/PARTIAL/SKIPPED> | <count: X pass / Y soft / Z hard-fail> |

## Per-flow discipline grid

Q25 legend: ✓ pass | 🚧 in progress | ⏳ pending | ❌ fail | — n/a | ⚠ soft warn

| Flow | Story | Eng | Design | QA | Docs |
|---|---|---|---|---|---|
| TEAM-01 | ✓ | ✓ | ⚠ | ✓ | ⏳ |
| TEAM-02 | ✓ | ❌ | ✓ | ⚠ | ✓ |
| ... |

## Cross-cutting consistency

- inventory-story-doc-id-match: ✓
- index-story-doc-status-match: ⚠ (TEAM-03 INDEX status drifted from story-doc — see line 47)
- linear-children-match: ✓
- parent-l3-summary-populated: ❌ (TEAM-04 parent missing 2 of 5 discipline headlines)
- milestone-subflows-table-match: ✓

## Summary

<N> hard pass · <N> hard fail · <N> soft warn · <N> overrides · exit <code>

## Overrides

| Gate | Reason | Timestamp | Scope |
|---|---|---|---|
| <gate-id> | <user-supplied reason> | <ISO-8601> | <flow / domain / project> |

### Stale overrides — re-evaluate

| Gate | Reason | Timestamp | Why stale |
|---|---|---|---|
| <gate-id> | <reason> | <>30 days ago> | timestamp older than 30-day threshold |
| <gate-id> | <reason> | <ISO-8601> | underlying condition has changed (file now exists) |
```

The Overrides section omits the `## Stale overrides — re-evaluate` subsection when there are no stale overrides. The Overrides section omits the entire section when `overrides[]` is empty.

### `--json` (CI scripting)

Structured shape per Q38 sub-decision 4:

```json
{
  "gates": [
    {
      "id": "<stable gate ID e.g. parent-l3-summary-populated>",
      "type": "phase-transition | per-flow | cross-cutting",
      "status": "pass | soft-warn | hard-fail | skipped | overridden",
      "scope": "project | domain:<slug> | flow:<DOMAIN-NN> | discipline:<name>",
      "message": "<human-readable detail; URL on Linear-side findings>"
    }
  ],
  "summary": {
    "hard_pass": <int>,
    "hard_fail": <int>,
    "soft_warn": <int>,
    "overrides": <int>,
    "exit_code": <int>
  }
}
```

**No file write by default.** stdout is terminal-reviewable; the user redirects to a file via shell (`/flow:audit --json > audit.json`) when they want persistence. Q38 sub-decision 4's "stays strictly local in v1" resolution applies — see § v1 boundary note below.

## Exit codes

Per Q38 sub-decision 6 — exit codes are CI-significant and follow `os.EX_USAGE` convention for arg errors:

- `exit 0` — All hard gates pass (overrides counted as pass per Q29.5 override-counts-as-pass behavior). Soft-gate failures do NOT affect this exit code (informational only).
- `exit 1` — At least one hard gate failed AND was not overridden. The audit report enumerates which gate(s) failed.
- `exit 2` — `verify-docs.sh` failed (Phase A non-zero exit). Phase B + Phase C were marked skipped. The user fixes mechanical issues first, then re-runs.
- `exit 64` — Invalid args (`os.EX_USAGE` convention). Examples: unknown flag, malformed `--gate=<id>` reference, `--flow` value that doesn't match any inventory row, `--discipline` value outside the 5-element enum.

**Override-counts-as-pass (Q29.5).** When a hard gate fails and the user picks `Override` via `AskUserQuestion`, the gate is recorded in the breadcrumb's `overrides[]` slot with `{gate, reason, timestamp, scope}` and downstream phases proceed as if the gate had passed — including this exit-code calculation. The override is auditable: every override row is preserved in the breadcrumb and surfaces in `--json` summary + the markdown Overrides section.

**`--strict` flag** (parking lot v1.1 — Q38 sub-decision 6): would cause `exit 1` whenever overrides are present regardless of pass/fail. Deferred until Brand Hub dogfood reveals override accumulation as a problem.

## Override mechanism

Per Q29.5 (mirrors cadence linear-housekeeping § 6 precedent): on hard-gate failure, fire `AskUserQuestion` with three options — **Fix now** / **Override with reason** / **Halt**.

- **Fix now** — exit the audit, return control to the user with a clear pointer to the failing gate. User fixes, re-runs `/flow:audit`.
- **Override with reason** — fire a follow-up `AskUserQuestion` collecting the reason. Append `{gate, reason, timestamp, scope}` to `docs/plans/.flow-phase-state.json` `overrides[]` (Q31.1 schema). Continue evaluating remaining gates. The override is persistent for the run AND across runs until the user explicitly removes it via interactive prompt or manual breadcrumb edit (no auto-clear).
- **Halt** — exit the audit immediately with `exit 1`. No breadcrumb mutation.

`/flow:audit` is **read-mostly** — the only write it ever performs is appending to `overrides[]` when the user picks Override. It never writes `current_phase`, `completed_phases[]`, `status`, or the breadcrumb's per-phase artifact-state slots — those are owned by orchestrators. Append-to-`overrides[]` goes through `bash $CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh write` (BC-6956 helper, Q31.5 atomic-rename contract) just like every other breadcrumb write.

## Stale-override detection

Per Q38 sub-decision 7 — extend Q29.5 with a re-evaluate prompt for entries that may no longer be load-bearing.

On every audit run, after evaluating Phase B + Phase C, scan the breadcrumb's `overrides[]` for two staleness conditions:

1. **Timestamp older than 30 days.** Compare each entry's `timestamp` field against `now - 30 days`. The 30-day threshold is an arbitrary first cut per the Q38 sub-decision 7 lock; tune via Brand Hub dogfood feedback. (`30-day` literal preserved here to anchor the AC grep.)
2. **Underlying gate condition has changed.** For each override, re-evaluate the gate that was overridden. If the gate now passes (e.g., overridden gate was `journey-complete` for FOO domain when the file was missing, but the journey doc now exists), the override is structurally stale.

Each stale override surfaces in the markdown report's `### Stale overrides — re-evaluate` subsection of the Overrides section, with a `Why stale` annotation distinguishing the two conditions. In `--json`, stale overrides have `status: "overridden"` plus a `stale: true` field on the gate entry — CI scripts can grep for `stale: true` to gate on override hygiene.

**No auto-clear.** Stale overrides are surfaced for human review only. Removing an override is always a deliberate user action — either via an interactive prompt (`Re-evaluate now? Yes / Keep / Skip`) when the user runs `/flow:audit` interactively, or via manual breadcrumb edit. `/flow:audit` does NOT auto-mutate `overrides[]` to remove entries.

## L-review coverage clarification

L3 covered via Q29.3 `parent-l3-summary-populated`; L2 intentionally NOT gated (Q26 mod 2 locks `## L2 review summary` as optional); L1 coverage will fold in when Q41 (PROJECT-INTENT.md template) lands and tightens Q29.1's `intent-exists` required-sections list. L4 is JIT during `/flow:session-start` Step 5 → `/flow:plan-{discipline}` and is not orchestrator-driven; the per-discipline plan-section content is what each L4 reviewer returns and is captured via Q46 markers, not via `/flow:audit`.

## v1 boundary note

Per Q38 sub-decision 4's deferred-decision resolution (locked 2026-05-07 per Q46 lock; user-confirmed at `:730`): `/flow:audit` stays **strictly local** in v1. stdout markdown + `--json` only; no Linear writeback in v1.

The `audit-concerns marker reserved` in `_shared/linear-writeback-pattern.md`'s v1 type registry is **registered but UNUSED in v1** — explicitly preserved as a future-promotion slot, not an active code path. v1.1 only — promotion via a `--linear-surface[=parent|milestone]` flag on `/flow:audit` (Q38 amendment territory; would constitute Q38 amendment 1 if/when authored). The flag would route audit findings into Q46 via `linear_writeback({type: 'audit-concerns', surface: ..., content: ...})`. Until then, no Linear writes. (This is the v1.1 promotion path.)

**Why this resolution.** /flow:audit auto-fires from /flow:ship + /flow:plan-{discipline} (sub-decision 5); routing those auto-fires to Linear would generate ~5+ comments per ship cycle per sub-flow — notification spam. /flow:ship already routes `ship-summary` as the team-facing checkpoint; `audit-concerns` is developer-internal pre-flight. Most reversible architectural choice — preserves Q38's "stdout-only by default" framing exactly. v1.1 only — no Q38 sub-decision 4 amendment needed in v1.

## Failure semantics summary

| Source | Behavior |
|---|---|
| `verify-docs.sh` non-zero | Phase B+C marked skipped; `exit 2` |
| Phase B hard-gate fail | Fire override `AskUserQuestion` per Q29.5; if Halt or unoverridden → contributes to `exit 1` |
| Phase B soft-gate fail | Surface in report only; no exit-code impact |
| Phase C Linear MCP error (transient) | Treat as gate `unknown` in report; surface in summary; do NOT count as hard fail |
| Phase C Linear MCP error (persistent / auth missing) | Surface as Phase C status `SKIPPED` in Phase status table; do NOT contribute to `exit 1` (no signal); user fixes auth, re-runs |
| Invalid arg (unknown flag, malformed value) | Surface usage error to stderr; `exit 64` |
| User halt at override prompt | Stop run; `exit 1` |

## See also

- `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:700` — Q38 lock (canonical source; seven sub-decisions + refinement audit trail at `:716`).
- `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:730` — Q38 sub-decision 4 deferred-decision resolution (stays strictly local in v1; `audit-concerns marker reserved` for v1.1 promotion).
- `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:240` — Q29 35-gate manifest lock.
- `plugins/flow-architecture/skills/_shared/artifact-gate-pattern.md` — gate manifest reference (categories + counts; canonical source for re-derivation prevention).
- `plugins/flow-architecture/skills/_shared/linear-writeback-pattern.md` — Q46 layer; `audit-concerns` marker enum entry.
- `plugins/flow-architecture/skills/_shared/checkpoint-pattern.md` — `overrides[]` breadcrumb slot + `flow-resume-breadcrumb.sh` helper contract.
- `plugins/flow-architecture/commands/start-project.md` — sibling orchestrator (BC-6962). Distinct shape: orchestrator owns breadcrumb writes; `/flow:audit` does not.
- `plugins/flow-architecture/commands/add-sub-flow.md` — sibling orchestrator (BC-6965). Distinct shape: gate placement inside sub-skills; `/flow:audit` has no within-skill gates.
- `plugins/flow-architecture/CLAUDE.md` § Quality gate stack reference — runtime overview of this command in plugin context.
- Handbook CDR-023 — Flow-Driven Architecture (the policy this command implements).
- Parking lot #27 — v1.1 promotion of batched-list-issues pattern to `_shared/linear-batched-list-pattern.md` if a third caller emerges.
- Parking lot #48 — v1.1 `--audit-preflight` flag for `/flow:review` if Brand Hub dogfood reveals demand.
