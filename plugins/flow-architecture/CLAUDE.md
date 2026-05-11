<!-- TODO: when handbook migrates to public GitBook docs site, replace absolute GitHub URLs with GitBook canonical URLs. -->

# Flow-Architecture Plugin

Scaffolds UI-bearing Brite product builds into the Flow-Driven Architecture shape: 4-tier hierarchy (project intent → domains → sub-flows → discipline children), Linear milestones + 5N children, repo docs at `docs/product/{intent.md, master-flow-inventory.md, journeys/<domain>.md, flows/<domain>/<flow-id>.md, flows/INDEX.md}`. Implements [CDR-023][cdr-023] (Proposed; transitions to Accepted at plugin v1.0 per Q33 sub-decision 1); operationalized via [how-we-work/operating-standards/flow-driven-architecture.md][ops-fda].

This file is dual-audience: maintainer reference for plugin contributors AND LLM-context guidance loaded whenever the plugin is active. Sibling artifact distinction — Q34 (org handbook) targets the practitioner; CDR-023 (Q33) is the decision rationale; `README.md` (Q30.7) targets the installer; this file (Q55) targets the LLM dispatching plugin behavior and the maintainer extending it.

## Plugin overview

FDA replaces the legacy Phase Pattern (Phase 1 → Phase N stage gates) for **UI-bearing product builds**. Backend and non-product platform work stay on the Phase Pattern (CDR-014, scoped by Q35 amendment).

The plugin is the runtime that **creates and maintains FDA-shaped substrates**: it owns the orchestrators that scaffold new projects and retrofit legacy ones, the inner-loop utilities that drive per-session execution, the sub-skills that author the canonical docs, and the agents that fire multi-perspective reviews at every meaningful scope.

**v1 acceptance gate (Q8):** a successful Brand Hub retrofit dogfood per the concrete criteria locked at Q40 sub-decision 4. The plugin ships pre-1.0 (currently on the `0.x` cache-propagation series per the BC-6000 same-commit bump rule) and flips to `1.0.0` only after Brand Hub `/flow:retrofit-project` succeeds end-to-end against those criteria, tracked at [BC-6998](https://linear.app/brite-nites/issue/BC-6998).

## Surface map

Drift-tolerant per Q55 sub-decision 4 — categorical prose for commands and sub-skills, literal MATRIX for agent dispatch. Source of truth is the filesystem; do **not** assert top-level counts in body text.

### Slash command MAP (categorical prose)

Slash commands organized by role. The directory `commands/` and `plugin.json` are the source of truth.

- **Orchestrators** — multi-phase runs with user-confirmation gates between phases. Examples: `/flow:start-project` (greenfield), `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`.
- **Utilities** — single-purpose commands with no user-gates between internal steps. Examples: `/flow:audit`, `/flow:office-hours` (project-intent interview with internal L1-review phase).
- **Reflect** — `/flow:retro` (sub-flow-scoped retrospective).
- **L4 plan-X suite** — one per discipline, dispatched on-demand from `/flow:session-start`. Examples: `/flow:plan-story`, `/flow:plan-eng`, `/flow:plan-design`, `/flow:plan-qa`, `/flow:plan-docs`.
- **Cloned inner-loop commands** — FDA-swapped clones of workflows-plugin commands per the workflows-cloned cribbing pattern (see § Methodology notes). Examples: `/flow:session-start`, `/flow:review`, `/flow:ship`.

### Sub-skill orchestration MAP (categorical prose)

Sub-skills are **not user-invocable** — they declare `disable-model-invocation: true` per Q7 lock and are called by orchestrators. Source of truth is `skills/<name>/SKILL.md`.

- **Preflight** — `flow-preflight` (Q12 + Q36 embedded bootstrap). Mode classification (`greenfield | retrofit | incremental-add | resume`); writes `.flow/config.json` on first successful run.
- **Inventory** — `flow-inventory-interview` (Q19 greenfield Socratic), `flow-inventory-codebase-scan` (Q11 retrofit code-signal mining), `flow-inventory-add` (Q20 incremental).
- **Scaffold** — `flow-linear-scaffold` (Q13 milestone + parent + 5N children), `flow-legacy-cross-reference` (Q14 retrofit-only `## FDA migration` appendix on legacy milestones).
- **Authoring** — `flow-doc-author` (Q15 per-sub-flow story doc), `flow-journey-author` (Q16 per-domain journey doc), `flow-sandbox-scaffold` (Q17 sandbox harness).
- **Regen** — `flow-regen-index` (Q18 idempotent `flows/INDEX.md` rebuild).

### Agent dispatch MATRIX (literal table)

Rows = named agents; columns = L-scope (Q54), primary invoker, return-shape. Source of truth is `agents/<name>.md`.

| Agent | L-scope | Return shape | Invoker |
|---|---|---|---|
| `plan-ceo-reviewer` | L1, L2 | four-mode | `/flow:office-hours` (L1); inventory interview (L2) |
| `plan-design-reviewer` | L1, L2, L3, L4 | four-mode | `/flow:office-hours` (L1); inventory (L2); `flow-linear-scaffold` (L3); `/flow:plan-design` (L4) |
| `plan-eng-reviewer` | L1, L3, L4 | four-mode | `/flow:office-hours` (L1); `flow-linear-scaffold` (L3); `/flow:plan-eng` (L4) |
| `plan-devex-reviewer` | L1 | four-mode | `/flow:office-hours` |
| `plan-story-reviewer` | L3, L4 | four-mode | `flow-linear-scaffold` (L3); `/flow:plan-story` (L4) |
| `plan-qa-reviewer` | L3, L4 | four-mode | `flow-linear-scaffold` (L3); `/flow:plan-qa` (L4) |
| `plan-docs-reviewer` | L3, L4 | four-mode | `flow-linear-scaffold` (L3); `/flow:plan-docs` (L4) |
| `story-doc-author` | n/a | story-doc markdown | `flow-doc-author` |
| `journey-doc-author` | n/a | journey-doc markdown | `flow-journey-author` |
| `fidelity-reviewer` | L3 (per-issue) | issue-fidelity verdict | `flow-linear-scaffold` Q13.3 |
| `inventory-author` / `codebase-inferrer` | n/a | inventory rows | inventory sub-skills |

Reviewer agents share the `_shared/four-mode-framework.md` contract; the L4 plan-X invocations consume `four-mode` for the per-discipline plan-section content per Q43 sub-decision 5.

## Workflows plugin dependency

The flow-architecture plugin **requires** the `workflows` plugin to be installed alongside it. The dependency is structural and load-bearing — not advisory.

- **MCP reuse (Q30.4 + Q32):** all Linear access goes through `mcp__plugin_workflows_linear-server__*`. FDA's own `.mcp.json` is empty `{}` per the cadence precedent. Registering a duplicate Linear server breaks tool routing (per [BC-5810](https://linear.app/brite-nites/issue/BC-5810) § 4 and [BC-5811](https://linear.app/brite-nites/issue/BC-5811) § 4.2).
- **Three-channel reuse mechanism (Q50 sub-decisions 4-6):** (1) **REUSE** — workflows tools called transparently from FDA sub-skills (Linear MCP, sequential-thinking, Context7); (2) **CLONE** — three workflows command bodies copied into `commands/{session-start,review,ship}.md` with locked FDA-swap axes per Q51 / Q52 / Q53; (3) **TRANSITIVE REUSE** (per Q50 amendment 2) — cloned commands invoke workflows skills and agents the cloned body already references (`/workflows:diff-triage`, the workflows review agents, etc.); those callees are not re-implemented in FDA.
- **No modifications to workflows from this plugin.** If a workflows-side change is needed, edit the workflows plugin directly and bump its version. FDA never mutates `../workflows/`.

Relative path note: this file lives at `plugins/flow-architecture/CLAUDE.md`; `../workflows/` resolves to the sibling plugin per Q30.2 directory placement.

## MCP + dependencies

**MCPs (Q32):**

- **Required** — `mcp__plugin_workflows_linear-server__*` (provided transitively by the workflows plugin).
- **Available but not depended on** — `mcp__plugin_workflows_sequential-thinking__*`, `mcp__plugin_workflows_context7__*`. FDA does not register either; both remain usable through the workflows registration.

**External CLIs (Q32):**

- `bash 3.x+` — target macOS default 3.2. Avoid associative arrays, `mapfile`, `${var,,}` lowercasing, and other bash-4-only features. Guard `"${arr[@]}"` of arrays that may be empty under `set -u`.
- `python3 3.6+` — Q31.5 JSON parse-verify and any structured-data manipulation. **Stdlib only** — no PyYAML, no `requests`; plugin scripts run with whatever ships on the developer's machine.
- `git 2.x+` — Q12 repo-root detection.
- `gh` — soft (optional auth check at preflight).

**OS:** macOS + Linux with POSIX filesystem (atomic rename). No Windows in v1.

**No telemetry, no hooks in v1** (per Q30.8 lock). Both are parking-lot candidates for v1.1.

## Bootstrap + first-run

First-run bootstrap is **embedded in `flow-preflight`** (Q36) — there is no separate `/flow:bootstrap` command in v1. The flow:

1. **Detect** — `flow-preflight` reads `.flow/config.json` (repo root). Absence = first-run.
2. **Prompt** — `AskUserQuestion` collects `linear_project_id`, `linear_project_name`, `linear_team_key`.
3. **Persist** — `flow-preflight` writes `.flow/config.json` (committed to git, team-shared) with v1 fields: `linear_project_id`, `linear_project_name`, `linear_team_key`, `fda_first_setup_at`, `fda_plugin_version`. Stale config (project ID no longer resolves) → warn, re-prompt, update in place.
4. **Classify mode** — `greenfield | retrofit | incremental-add | resume` per Q12 mode classifier.
5. **Dispatch** — preflight hands off to the appropriate orchestrator with a structured preamble (`MODE / LINEAR_PROJECT_ID / LINEAR_PROJECT_NAME / REPO_ROOT / INTENT_EXISTS / INVENTORY_EXISTS / FLOWS_DIR_EXISTS / BREADCRUMB_EXISTS / GH_AUTH / LINEAR_MCP`).

**Per-org bootstrap (parking lot #33):** v1 expects the org maintainer to manually merge the handbook PRs (CDR-023, CDR-014 amendment, operating-standards FDA page) and the about-handbook templates PR (Q22-Q28 + Q41) **before** any project consumes the plugin. A `/flow:bootstrap-org` orchestrator that automates these PR creations is a v1.1 candidate.

## Quality gate stack reference

Per Q29 lock, the plugin owns a **35-gate quality stack** across three categories — phase-transition gates (8), per-flow discipline-child gates (~22), and cross-cutting consistency gates (5). Full enumeration lives in `docs/design-rationale/fda-plugin-architecture-overview.md` § 3h; do not duplicate the list here.

**Runner.** `/flow:audit` (Q38) is the only runner. Three-phase execution: (A) `scripts/verify-docs.sh` for mechanical checks (build / lint / test / links / orphan flow IDs); (B) deterministic filesystem gates (Q29.2); (C) Linear MCP gates (Q29.3 + the Eng / Design / Docs subsets of Q29.2). If Phase A fails, Phase B/C is marked skipped.

**Output.** Markdown to stdout (default) or `--json` for structured consumption. Exit codes: `0` = all hard gates pass; `1` = unoverridden hard-gate fail; `2` = `verify-docs.sh` failed.

**Auto-invocation.** `/flow:ship` invokes `/flow:audit --domain=<DOMAIN>` as a pre-flight (Q38 sub-decision 5). `/flow:plan-{discipline}` invokes the audit before generating plan content. Orchestrators do **not** auto-invoke audit (avoids double-fire during scaffold).

**Override-counts-as-pass (Q38 sub-decision 6).** When a hard gate fails and the user selects `Override` via `AskUserQuestion`, the gate is recorded in `state.overrides[]` with `{gate, reason, timestamp, scope}` and downstream phases proceed as if the gate had passed. The override is auditable — every override row is preserved in the breadcrumb and surfaces in `/flow:audit --json`. There is no silent bypass.

## L-review pattern

Per Q54 (meta-Q on review scoping) and `_shared/four-mode-framework.md` (Q48 outcome contract), every artifact gets multi-perspective AI review at the appropriate scope. Reviews fire in parallel within scope, populate target docs, and never block — they are informational + auditable.

**Scoping (Q54).**

- **L1 — project scope.** Reviewers: CEO + Design + Eng + DevEx (4 parallel). Target: `docs/product/intent.md ## L1 review summary`. Fires from `/flow:office-hours` phase 2.
- **L2 — domain scope.** Reviewers: CEO + Design (2 parallel). Target: `docs/product/journeys/<domain>.md ## L2 review summary`. Fires from inventory phase, one per domain.
- **L3 — sub-flow scope.** Reviewers: 5 disciplines (Story + Eng + Design + QA + Docs). Target: Linear parent-issue body `## L3 review summary`. Fires from `flow-linear-scaffold` phase 4, one per sub-flow.
- **L4 — discipline-child scope.** Reviewer: the single discipline reviewer matching the command. Target: discipline-child Plan section (via Q46 markers). Fires JIT during `/flow:session-start` step 5 → `/flow:plan-{discipline}`.

**Four-mode outcome contract (Q48; cross-cutting requirement #3).** Every reviewer agent returns exactly one mode per invocation, mutually exclusive:

- **`SCOPE_EXPANSION`** — recommend expanding scope; "dream bigger".
- **`SELECTIVE_EXPANSION`** — hold overall scope but cherry-pick specific expansions.
- **`HOLD_SCOPE`** — keep scope as-is; focus on execution rigor.
- **`SCOPE_REDUCTION`** — strip scope to essentials.

The mode taxonomy is **orthogonal** to the L-scope axis: L-scope decides when reviewers run and how many parallel agents fire; four-mode decides what each agent returns. The full input/output schema and mode-specific field rules live at `skills/_shared/four-mode-framework.md`. Do not re-derive — that file is the canonical contract and any change requires a Q48 amendment with audit trail.

## Boundaries

Several command pairs have overlapping vocabulary but distinct purposes. Mixing them up causes subtle scope creep in future Q-locks.

- **`/flow:audit` vs `/flow:review` (Q52 sub-decision 4; cross-cutting requirement #5).** `/flow:audit` runs FDA-process-compliance gates (filesystem-existence + Linear-state checks against the 35-gate stack). `/flow:review` runs code-review agents on a diff (P1/P2/P3 findings classification, simplification pass). Distinct purposes. `/flow:audit` auto-invokes before `/flow:ship`; `/flow:review` is invoked when the user wants diff-level review. A `--audit-preflight` flag for `/flow:review` is a v1.1 candidate (parking lot #48) if Brand Hub dogfood reveals demand for bundled coverage.
- **Orchestrators vs utilities vs cloned commands.** Orchestrators (`/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`) are multi-phase + multi-gate and own the breadcrumb. Utilities (`/flow:audit`, `/flow:office-hours`, `/flow:retro`) are single-purpose. Cloned commands (`/flow:session-start`, `/flow:review`, `/flow:ship`) preserve workflows structure with FDA-swap axes — they are **not** orchestrators and do not write the breadcrumb.
- **`/flow:office-hours` vs `/flow:retro`.** Office-hours is a **project-scoped** intent interview (Q42 — output is `intent.md`); retro is a **sub-flow-scoped** retrospective (Q44). Different scope, different output target, different cadence (office-hours fires once or rarely; retro fires per sub-flow shipped).
- **`flow-sandbox-scaffold` vs hand-off agents.** `flow-sandbox-scaffold` (Q17) is a sub-skill that bootstraps the sandbox harness during scaffold. Hand-off agents (`story-doc-author`, `journey-doc-author`) are review-style agents that **produce** doc markdown for an authoring sub-skill to write. Same shape, different layer.

## Q46 writeback layer

`linear-writeback` (Q46) is the thin write executor that backs every Linear write FDA-side. Callers pass one `(issue_id, type, content)` tuple per intended write; Q46 does not merge or rebalance tuples on its behalf.

**Type registry (Q46 sub-decision 2).** Closed enum in v1 (extensible via amendment): `ship-summary`, `retro-summary`, `plan-story-section`, `plan-eng-section`, `plan-design-section`, `plan-qa-section`, `plan-docs-section`, `audit-concerns`. New types require a Q46 amendment with audit trail (this is the **schema-discipline amendment pattern**). v1.1 adds `review-summary` per the parking-lot #49 sequence (Q46 amendment 3 + Q52 amendment 1).

**Idempotency markers.** Every Q46 write is bracketed by `<!-- FDA-WRITEBACK-<type>-START -->` / `<!-- FDA-WRITEBACK-<type>-END -->` HTML comments inside the target surface. Re-runs locate the existing block by marker pair and clobber-with-warning (sub-decision 4); they do **not** append duplicates.

**Double-layer safety (Q43 caller-side + Q46 executor-side; cross-cutting requirement #2).** Two layers catch two different failure modes:

- **Q43 layer (caller-side).** Caller reads the target via `get_issue` before Q46 fires; if the inter-marker content lacks the stable substring `Plan not yet generated` and `--refresh` is absent, the caller errors out with `"Plan section already populated for <issue-id>. Use --refresh to regenerate."`. Catches accidental re-writes of valid plans.
- **Q46 layer (executor-side).** If `--refresh` bypasses the Q43 layer, Q46's clobber-with-warning surfaces in-marker human edits the caller-side check is too coarse to see.

The names "double-layer safety" and "Q43 caller-side + Q46 executor-side" are deliberate. Do not collapse the layers.

**Batching convention (Q46 sub-decision 5; cross-cutting requirement #1).** Q46 is intentionally thin — consumer skills (Q53 ship, Q44 retro, Q43 plan-X) own their batching strategy. **Prefer a single parent comment with sub-sections per child when writes target sibling issues sharing a parent.** This is a per-consumer concern; Q46 enforces a within-skill throttle via `linear_writeback_state.written_pairs[]` (Q31 amendment 2) but does not enforce cross-skill rate-limiting in v1. A global rate-limiter is a v1.1 candidate (parking lot #38).

## Concurrency caveat

**Single-orchestrator-at-a-time per Q31.6 (memory:298).** v1 does not support concurrent orchestrators in the same repo — running `/flow:start-project` and `/flow:add-domain` simultaneously, or two `/flow:add-sub-flow` runs against the same project, will produce breadcrumb collisions at `docs/plans/.flow-phase-state.json` (the single transient run-artifact path locked at Q31.4). The breadcrumb is per-repo, not per-run.

If you need to fan out (e.g., scaffolding several domains in parallel), run them sequentially with the user re-invoking the orchestrator between runs. The internal per-domain inner loop inside `/flow:start-project` Phase 4 (Q37) is **not** a concurrency exception — it is sequential per-domain, scheduled by the orchestrator.

## Methodology notes ("How this plugin evolves")

Four operational disciplines load-bearing for v1.1+ Q-locks inside the plugin's own evolution: **validation-first cycle**, **parking-lot-#39 + extension**, **three-way cribbing taxonomy**, **schema-discipline amendment pattern**.

1. **validation-first cycle.** Orchestrator → drafter → orchestrator → drafter's-own-prior-work. Surface contradictions at the first downstream consumer, re-verify at the source, escalate to the user only when consensus + drafter judgement converge. ~20 distinct catches across the B + C + D interview sessions are preserved in `docs/design-rationale/project_fda_plugin_interview.md` audit trails — that file is the source.
2. **parking-lot-#39 + extension.** Before drafting any new cribbed content, `gh api` re-fetch the cribbed source and grep for the structural elements you intend to crib. Re-verify at EACH downstream lock that consumes the source — heavily-cited foundation locks accumulate errors at downstream consumer drafting (Q51 and Q53 each caught Q50 errors via this discipline; Q50 amendments 1 and 2 are the audit trail). Apply even without a formal cribbing relationship (e.g., the cadence/CLAUDE.md link-convention divergence preserved in § See also).
3. **three-way cribbing taxonomy (Q50 sub-decision 7; cross-cutting requirement #4).** Three patterns govern every new cribbing decision:
   - **FDA-native** — no external source crib. Examples: Q37 orchestrator phase flows, Q38 audit, Q47 add-domain / add-sub-flow, Q43 plan-X dispatcher, the Q11-Q20 sub-skills.
   - **gstack-inspired** — loose transfer; structural inspiration, not directly cribbable. Source = `repos/garrytan/gstack`. Examples: Q42 `office-hours` (adapts heavily), Q44 `retro` (cribs 5 verbatim section headers, adapts time-windowed → scope-bounded), Q48 `four-mode-framework` (cribs the `plan-ceo-review` scope-axis taxonomy verbatim).
   - **workflows-cloned** — full clone with FDA-swap per the 7-axis framework. Source = `plugins/workflows/`. Examples: Q51 `/flow:session-start`, Q52 `/flow:review`, Q53 `/flow:ship`. Each cloned file carries an HTML-comment header recording the source SHA and clone date (drift-detection baseline per Q40 sub-decision 7; consumed by parking-lot #45 runtime tooling in v1.1).
4. **schema-discipline amendment pattern.** Schema changes propagate through both the originating Q-lock and the target Q-lock with an audit trail preserved in `project_fda_plugin_interview.md`; original incorrect text preserved when applicable. Precedents: Q31 amendments 1 and 2 (office-hours-state, linear-writeback-state); Q24 amendment 1 (Plan-section Q46 markers in discipline-child templates); Q21 amendment 1 (adjustments[] reframed); Q50 amendments 1 and 2 (workflows-cloned classification + TRANSITIVE REUSE).

## Pre-existing-vs-FDA-output mapping

What FDA creates vs what already exists in the consuming project. Use this when retrofitting (BriteBase, Brand Hub) to know what to scaffold vs preserve. In the Brand Hub column, a bare `no` means FDA creates the artifact fresh during retrofit (Brand Hub is greenfield).

| Artifact | Created by FDA | Pre-existing in BriteBase | Pre-existing in Brand Hub (v1 dogfood target) |
|---|---|---|---|
| `docs/product/intent.md` | yes (Q42) | yes (legacy) — Q42 overwrites or augments per office-hours flow | no |
| `docs/product/master-flow-inventory.md` | yes (Q11 retrofit / Q19 greenfield) | yes (28-domain canonical) | no; Brand Hub picks its own domain count at runtime (see `project_fda_plugin_interview.md` line 1951, Q34 disambiguation #10), not pinned to BriteBase's 28 nor the legacy-milestone count of 27 |
| `docs/product/flows/<domain>/<flow-id>.md` | yes (Q15 author) | partial (some flows pre-authored) | no |
| `docs/product/journeys/<domain>.md` | yes (Q16 author) | partial | no |
| `docs/product/flows/INDEX.md` | yes (Q18 regen) | yes | no |
| Linear domain milestones | yes (Q13 scaffold) | yes (legacy + FDA mixed; cross-referenced via Q14) | no |
| Linear sub-flow parent issues | yes (Q13) | yes (legacy mixed) | no |
| Linear 5N discipline children | yes (Q13) | partial (legacy work has irregular shapes) | no |
| `.flow/config.json` | yes (Q12 preflight) | no | no |
| `docs/plans/.flow-phase-state.json` | yes (Q31 breadcrumb) | no | no |
| `## FDA migration` legacy-milestone appendix | yes (Q14 retrofit-only) | yes (added at retrofit time) | n/a (no legacy milestones) |

## See also

- [CDR-023 — Flow-Driven Architecture][cdr-023] — Brite handbook decision record (Q33 lock).
- [operating-standards/flow-driven-architecture.md][ops-fda] — practitioner-facing operating standard (Q34 lock).
- [CDR-014 (amended by CDR-023, 2026-05-07)](https://github.com/Brite-Nites/handbook/blob/main/decisions/CDR-014-milestone-standards.md) + [milestones.md](https://github.com/Brite-Nites/handbook/blob/main/how-we-work/operating-standards/milestones.md) — Phase Pattern scoped to non-product surfaces (Q35 lock).
- [about-handbook/style-guide/templates/](https://github.com/Brite-Nites/handbook/tree/main/about-handbook/style-guide/templates/) — Q22-Q28 + Q41 promoted templates (issue templates, journey template, story-doc template, INDEX schema, PROJECT-INTENT template).
- `docs/design-rationale/project_fda_plugin_interview.md` — canonical Q-lock record (Q1-Q55, multiple amendments). When in doubt, read the Q-lock entry, not this file.
- `docs/design-rationale/fda-plugin-architecture-overview.md` — visual architecture overview (4-tier hierarchy, command surface diagrams, phase flows, quality-gate stack diagram, state substrate map).
- `docs/design-rationale/00-resume-bridge.md` — paste this as the first user message in a fresh Claude Code session to restore plugin-design context.
- `../workflows/` — required dependency.
- `../cadence/CLAUDE.md` — structural precedent for this file (intentional divergence on link convention: cadence uses no markdown links at all; this file uses inline + reference-style links because the 5 cross-cutting documentation requirements need cross-refs).
- Parking lot: `project_fda_plugin_interview.md` § "Parking Lot" — v1.1+ candidates. Re-triage post-Brand-Hub-dogfood per Q40 sub-decision 3.

[cdr-023]: https://github.com/Brite-Nites/handbook/blob/main/decisions/CDR-023-flow-driven-architecture.md
[ops-fda]: https://github.com/Brite-Nites/handbook/blob/main/how-we-work/operating-standards/flow-driven-architecture.md
