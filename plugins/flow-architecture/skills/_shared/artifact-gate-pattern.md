# Artifact-Existence Gate Pattern

Quality gates in FDA are **filesystem-artifact-existence checks**, NOT LLM self-report. Per Q7: deterministic, re-runnable, scriptable. A gate either reads a file (or queries the Linear API) and matches a predicate, or it fails. Self-reports like "the agent says it ran" are not gates.

## Gate categories (Q29 manifest)

Q29 enumerates 35 distinct gate types across three categories. Counts are summarized below; the full per-gate definitions live in the Q29 lock entry (`docs/design-rationale/project_fda_plugin_interview.md` lines 240-273) and the runner is `/flow:audit` (Q38, pending).

### Phase-transition gates (8)

Fire between FDA orchestrator phases. Per Q29 sub-decision 1:

- `env-ready` — Linear MCP reachable + repo root + `gh` auth.
- `intent-exists` — `docs/product/intent.md` exists with required sections.
- `inventory-complete` — `master-flow-inventory.md` has ≥1 domain section + `verify-docs.sh` orphan-flow-IDs check passes.
- `scaffold-complete` (per domain) — `.flow/scaffold-log/<domain>.md` has rows for 1 milestone + N parents + 5N children, all `result: executed` or `skipped-idempotent`.
- `story-docs-complete` (per domain) — N story doc files at `docs/product/flows/<domain>/*.md` for all N flows.
- `journey-complete` (per domain) — `docs/product/journeys/<domain>.md` exists.
- `index-complete` — `INDEX.md` `generated_at` >= orchestrator's `run_started_at` from the breadcrumb. Semantically: "INDEX regenerated as part of this orchestrator run."

### Discipline-child-completion gates (~22 per-flow)

Aggregated from Q24 templates' Done-means / Verify sections per Q29 sub-decision 2:

- [Story] — 5 checks (file exists, front-matter populated, job-story regex, 3-5 Gherkin scenarios, `verify-docs.sh` passes).
- [Eng] — 4 checks (Linear child completed, build/lint/test pass, sandbox URL HTTP 200, story-doc `children.engineering` populated).
- [Design] — 3 checks (Linear child completed, `figma:` URL with node ID, story-doc `children.design` populated).
- [QA] — 5 checks (story-doc `qa_status: signed-off`, valid `qa_last_signed_off` ISO-8601, history table row, signed-off comment posted, story-doc `children.qa` populated).
- [Docs] — 5 checks (customer-doc file exists, front-matter per Q28 schema, `user_docs_url` populated, `verify-docs.sh` passes for the customer-doc, story-doc `children.docs` populated).

Total: 5 + 4 + 3 + 5 + 5 = 22 per-flow.

### Cross-cutting consistency gates (5)

Cross-file integrity per Q29 sub-decision 3:

- `inventory-story-doc-id-match` — every story doc's `flow_id` exists as a row in `master-flow-inventory.md`.
- `index-story-doc-status-match` — `INDEX.md` Status column matches story doc front-matter `status`.
- `linear-children-match` — story doc `children.*` BC numbers match Linear `parentId` chain.
- `parent-l3-summary-populated` — Linear parent issue body contains `## L3 review summary` with 5 discipline headlines.
- `milestone-subflows-table-match` — Linear domain milestone description's Sub-flows table matches actual children.

## Hard vs soft classification

Per Q29 sub-decision 4:

- **Hard** (blocks downstream) — file existence, Linear issue creation, AC count (3-5 Gherkin), `qa_status: signed-off` for [Docs] to start, `verify-docs.sh` mechanical pass.
- **Soft** (warns; surfaces in `/flow:audit` summary) — stale `last_reviewed` (>90 days), missing optional front-matter fields (`e2e_test: TBD` is OK), missing `## L3 review summary`, transient mid-edit cross-cutting drift.

## Override mechanism

Per Q29 sub-decision 5, hard-gate failure follows the cadence linear-housekeeping § 6 precedent:

1. `AskUserQuestion` — **Fix now** / **Override with reason** / **Halt**.
2. On Override: follow-up `AskUserQuestion` for the reason.
3. Append `{gate, reason, timestamp, scope}` to the breadcrumb's `overrides[]` slot — see `checkpoint-pattern.md` for the slot reference.

Overrides persist for the phase invocation and are NOT re-prompted within the same run. `/flow:audit` reports overrides in its summary.

## Runner

`/flow:audit` (Q38, pending) is the gate runner: emits stdout + optional `--json`. v1 is strictly local — no Linear writeback (per Q38 sub-decision 4 deferred-decision resolution, lines 1041-1048). The `audit-concerns` writeback type IS registered in `linear-writeback-pattern.md` but UNUSED in v1; reserved for v1.1 `--linear-surface` promotion.

## References

- Q7 — `docs/design-rationale/project_fda_plugin_interview.md` line 60 (gate philosophy: filesystem-artifact-existence, not LLM self-report).
- Q29 — lines 240-273 (full gate manifest).
- Q38 — pending lock entry for `/flow:audit` runner; see Q38 sub-decision 4 at memory:1046 for the `--linear-surface` parking-lot entry.
- `checkpoint-pattern.md` — for `overrides[]` breadcrumb slot.
- Q30.2 — line 281 (file location lock).
