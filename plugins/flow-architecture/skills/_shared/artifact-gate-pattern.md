# Artifact-Existence Gate Pattern

Quality gates in FDA are **filesystem-artifact-existence checks**, NOT LLM self-report. Per Q7 (`docs/design-rationale/fda-plugin-interview.md:60`): deterministic, re-runnable, scriptable. A gate either reads a file (or queries the Linear API), matches a predicate, and passes — or it fails. Self-reports like "the agent says it ran" are not gates.

## Why

LLM self-report drifts. An agent can say "phase 2 complete" while the artifact it was supposed to produce is missing, malformed, or partial. Filesystem checks do not drift — either the file exists with the required content shape or it does not. Q7 locks this philosophy; Q29 enumerates the 36 gate types that follow from it; `/flow:audit` (Q38, pending) is the runner.

## Gate categories

Q29 manifests **36 distinct gate types** across three categories (post-Q29 amendment 2 adding the 6th cross-cutting gate). Full per-gate definitions are locked at `docs/design-rationale/fda-plugin-interview.md` lines 240-273; this file names the categories and counts and points at the canonical source.

### Phase-transition gates (8)

Fire between FDA orchestrator phases. Per Q29 sub-decision 1 (`:242`) plus Q29 amendment 1 (`:275`, LOCKED 2026-05-11 per BC-7066 reconciliation):

- `env-ready` — Linear MCP reachable + repo root + `gh` auth (Q12).
- `preflight-complete` — `.flow/config.json` exists with required v1 fields per Q12.4; structured preamble emitted per Q12.5. Maps to greenfield-orchestrator G1 user-gate ("bootstrap completed"). **Added per Q29 amendment 1.**
- `intent-exists` — `docs/product/intent.md` exists with required sections (per Q41).
- `inventory-complete` — `master-flow-inventory.md` has ≥1 domain section + `verify-docs.sh` orphan-flow-IDs check passes.
- `scaffold-complete` (per domain) — `.flow/scaffold-log/<domain>.md` has rows for 1 milestone + N parents + 5N children, all `result: executed` or `skipped-idempotent`.
- `story-docs-complete` (per domain) — N story-doc files at `docs/product/flows/<domain>/*.md` for all N flows in the domain.
- `journey-complete` (per domain) — `docs/product/journeys/<domain>.md` exists.
- `index-complete` — `INDEX.md` `generated_at` >= orchestrator's `run_started_at` from the breadcrumb. Semantically: "INDEX regenerated as part of this orchestrator run."

### Discipline-child-completion gates (~22 per-flow)

Aggregated from Q24 templates' Done-means / Verify sections per Q29 sub-decision 2 (`:252`):

- [Story] — 5 checks (file exists, front-matter populated — per-repo schema strictness via `.flow/config.json` `frontmatter_schema` (BC-12572): `lenient` default = the 4-key presence floor `flow_id`/`status`/`figma`/`user_docs_url`; `strict` = the full 20-key story canon (ADR-029 + job-story template), presence not non-emptiness; the standalone `flow-frontmatter-lint.sh` A-10/A-11 is the always-on truth surface that also names drift keys — story-frame regex match — the canonical human job-story `When/I want to/so I can` (operator- or customer-anchored even for infra, per rubric D11) OR the legacy constraint-spec `Given/MUST/so that` still tolerated for backward-compat (BC-12134), 3-5 Gherkin scenarios, `verify-docs.sh` passes for the doc).
- [Eng] — 4 checks (Linear child `state.type == "completed"`, `npm run build && npm run lint && npm test` pass on `main`, sandbox URL HTTP 200, story-doc `children.engineering` populated).
- [Design] — 3 checks (Linear child completed, `figma:` URL with node ID matches `figma\.com/file/.*\?node-id=`, story-doc `children.design` populated).
- [QA] — 5 checks (story-doc `qa_status: signed-off`, valid `qa_last_signed_off` ISO-8601, history table row with `signed-off`, structured QA-run comment on the Linear QA child, story-doc `children.qa` populated).
- [Docs] — 5 checks (customer-doc file exists at `docs/product/customer-docs/<domain>/<flow-id>.md`, front-matter per Q28 schema, `user_docs_url` non-TBD, `verify-docs.sh` passes for the customer-doc, story-doc `children.docs` populated).

Per-flow total: 5 + 4 + 3 + 5 + 5 = 22.

### Cross-cutting consistency gates (6)

Cross-file integrity per Q29 sub-decision 3 (`:261`) plus Q29 amendment 2 (`cross-domain-deps-bidirectional`, LOCKED 2026-05-26 per BC-10729):

- `inventory-story-doc-id-match` — every story doc's `flow_id` exists as a row in `master-flow-inventory.md`.
- `index-story-doc-status-match` — `INDEX.md` Status column matches story-doc front-matter `status`.
- `linear-children-match` — story-doc `children.*` BC numbers match the actual Linear `parentId` chain.
- `parent-l3-summary-populated` — Linear parent issue body contains `## L3 review summary` with 5 discipline headlines (Q23 mod 2).
- `milestone-subflows-table-match` — Linear domain milestone description's Sub-flows table matches actual children of that milestone (Q22).
- `cross-domain-deps-bidirectional` — every story-doc `## Cross-domain dependencies` bullet (Q27 amendment 1 mod 4) has a matching Linear `blockedBy` relation on the sub-flow parent issue, and every Linear `blockedBy` between FDA sub-flow parents has a matching doc-side bullet. Bidirectional set-comparison via the same batched `list_issues({label: "domain:<slug>"})` call backing `linear-children-match`. Same-domain sibling blockedBy (tracked via `related_flows` front-matter) and discipline-child relations excluded. **Added per Q29 amendment 2.**

Arithmetic: 8 + 22 + 6 = 36 distinct gate types (multiplied by N flows for per-flow gates).

## Hard vs soft classification

Per Q29 sub-decision 4 (`:267`):

- **Hard** (blocks downstream) — file existence, Linear issue creation, AC count (3-5 Gherkin), `qa_status: signed-off` for [Docs] to start, `verify-docs.sh` mechanical pass.
- **Soft** (warns but does not block; surfaces in `/flow:audit` summary) — stale `last_reviewed` (>90 days), missing optional front-matter fields (`e2e_test: TBD` is OK), missing `## L3 review summary` section, transient cross-cutting drift mid-edit.

## Override mechanism

Per Q29 sub-decision 5 (`:269`), hard-gate failure follows the cadence linear-housekeeping § 6 precedent:

1. `AskUserQuestion` — **Fix now** / **Override with reason** / **Halt**.
2. On Override: a follow-up `AskUserQuestion` for the reason.
3. Append `{gate, reason, timestamp, scope}` to the breadcrumb's `overrides[]` slot — see `checkpoint-pattern.md` for the slot reference.

Overrides persist for the phase invocation; they are NOT re-prompted within the same run. `/flow:audit` reports overrides in its summary.

## Runner

`/flow:audit` (Q38, pending) is the gate runner: emits stdout + optional `--json`. v1 is strictly local — no Linear writeback (per Q38 sub-decision 4 deferred-decision resolution, `:1057`). The `audit-concerns` marker type is registered in `linear-writeback-pattern.md`'s v1 enum but UNUSED in v1; it is reserved for v1.1 `--linear-surface` promotion. `/flow:audit` runs `verify-docs.sh` FIRST (mechanical layer: build/lint/test, internal links, orphan flow IDs, front-matter presence, stale dates), then layers FDA-specific gates on top (Q29 sub-decision 7, `:273`).

## References

- `docs/design-rationale/fda-plugin-interview.md:60` — Q7 gate philosophy (filesystem-artifact-existence, not LLM self-report).
- `docs/design-rationale/fda-plugin-interview.md:240-273` — Q29 full gate manifest (sub-decisions 1-7).
- `docs/design-rationale/fda-plugin-interview.md:275-283` — Q29 amendment 1 (names the 8th phase-transition gate `preflight-complete`, LOCKED 2026-05-11 per BC-7066).
- Q29 amendment 2 — adds the 6th cross-cutting gate `cross-domain-deps-bidirectional` (LOCKED 2026-05-26 per BC-10729); sibling to Q27 amendment 1 (story-doc `## Cross-domain dependencies` section).
- Q38 (pending) — `/flow:audit` runner lock; see Q38 sub-decision 4 (`:1057`) for the `--linear-surface` parking-lot resolution.
- `checkpoint-pattern.md` — `overrides[]` breadcrumb slot.
- `linear-writeback-pattern.md` — `audit-concerns` v1.1 promotion path.
- `docs/design-rationale/fda-plugin-interview.md:292` — Q30.2 file-location lock.
