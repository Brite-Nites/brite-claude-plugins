# flow-architecture — Architecture

This document is a **high-level pointer**. The canonical architecture record is the multi-session design interview at `docs/design-rationale/project_fda_plugin_interview.md` (2,306 lines, 54 Q-locks, 16 amendments). The synthesis overview is at `docs/design-rationale/fda-plugin-architecture-overview.md`.

## What the plugin codifies

Flow-Driven Architecture (FDA), defined in handbook CDR-023. It generalizes the BriteBase pattern (28 domains, ~397 sub-flows, 5-discipline children per sub-flow) so any UI-bearing Brite product can adopt the same structure in 22–70 minutes instead of weeks.

## The 4-tier domain model

| Tier | Linear side | Repo side |
|---|---|---|
| 1. Domain | Milestone (e.g., `TEAM: Team Management`) | `docs/product/journeys/<domain>.md` |
| 2. Sub-flow | Parent issue (e.g., `TEAM-04: Edit user role`) | `docs/product/flows/<domain>/<flow-id>.md` |
| 3. Disciplines | 5 children per parent: `[Story]` / `[Eng]` / `[Design]` / `[QA]` / `[Docs]` | 5 discipline artifacts (sandbox harness, Figma frame, test plan, customer how-to, etc.) |
| 4. Index | — | `docs/product/flows/INDEX.md` (auto-regenerated) |

Linear owns workflow state (status, assignee, `blockedBy`); the repo owns authoritative content (intent, narrative, specs). Stable foreign keys (`QUO-17`, etc.) bind them. Once published, flow IDs never change — splits get suffixed (`QUO-17a`/`QUO-17b`); deprecations stay in the registry tagged `[DEPRECATED]`.

## Discipline blockedBy chain

```
[Story] is foundational (sets the contract)
   |
   +--> [Design] --+
   |              +--> [QA] --> [Docs]
   +--> [Eng] ----+
```

## Plugin surface (v1.0 planned)

### Slash commands

- **4 orchestrators** — `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`
- **6 inner-loop utilities** — `/flow:audit`, `/flow:office-hours`, `/flow:retro`, `/flow:session-start`, `/flow:review`, `/flow:ship`
- **5 plan-X commands** — `/flow:plan-{story,eng,design,qa,docs}`

The 17-vs-15-count delta between Q30.2's `commands/` directory list and the architecture-overview §3c user-invocable surface reconciles in subsequent issues: two of the 17 entries (`regen-index`, `inventory`) are thin wrappers in front of same-name sub-skills, or get re-classified during command-file authoring.

### Sub-skills (planned; not user-invocable)

10 sub-skills under `skills/<name>/SKILL.md`: `flow-preflight`, `flow-inventory-codebase-scan`, `flow-inventory-interview`, `flow-inventory-add`, `flow-linear-scaffold`, `flow-legacy-cross-reference`, `flow-doc-author`, `flow-journey-author`, `flow-sandbox-scaffold`, `flow-regen-index`.

### Agents (planned)

12 named agents under `agents/` per Q21:

- **7 four-mode reviewer agents** — 5 per-discipline (`plan-{story,eng,design,qa,docs}-reviewer`) + `plan-ceo-reviewer` + `plan-devex-reviewer`. Reused across L-scopes (L1 project, L2 domain, L3 sub-flow, L4 discipline-child) via scope-axis fields per Q21 amendment 1 — dispatch context decides which fire where.
- **5 specialist agents** — `inventory-author`, `codebase-inferrer`, `story-doc-author`, `journey-doc-author`, `fidelity-reviewer`.

### Shared utilities

6 utilities under `skills/_shared/` (per Q30.2 memory L281): `app-classifier-pattern.md`, `code-evidence-collector.md`, `linear-writeback-pattern.md`, `checkpoint-pattern.md`, `artifact-gate-pattern.md`, `four-mode-framework.md`.

### Scripts

4 bash helpers under `scripts/` (per Q30.6 memory L284): `flow-detect-mode.sh`, `flow-detect-fda-shape.sh`, `flow-resume-breadcrumb.sh`, `flow-context-load.sh`. Invoked from skill bash preambles via `source $CLAUDE_PLUGIN_ROOT/scripts/<helper>.sh` (gstack pattern from Q12 lock).

## State substrates

Per Q31, the plugin uses two persistent state files in a consumer project:

- **`.flow/config.json`** — per-project config (Linear project ID, team key, plugin version, first-setup timestamp). Committed.
- **`docs/plans/.flow-phase-state.json`** — resume breadcrumb (mode, current phase, completed phases, in-flight artifacts, per-domain status). Transient.

Plus orchestrator in-memory state for L2 review hand-off between phases.

## Multi-perspective L-review pattern

Every artifact gets multi-agent AI review at the appropriate scope (Q54). Reviews fire in parallel within scope, populate target docs, and never block — they are informational + auditable.

| Scope | Reviewers | Target |
|---|---|---|
| L1 — Project | plan-ceo + plan-design + plan-eng + plan-devex (4 parallel) | `docs/product/intent.md` `## L1 review summary` |
| L2 — Domain | plan-ceo + plan-design (2 parallel × N domains) | `docs/product/journeys/<domain>.md` `## L2 review summary` |
| L3 — Sub-flow | 5 discipline reviewers (parallel × N sub-flows) | Linear parent issue body `## L3 review summary` |
| L4 — Discipline-child | Single per-discipline reviewer | JIT during `/flow:session-start` step 5 |

## Orchestrator phase flows

- `/flow:start-project` (greenfield) — 8 phases / 4 gates / hybrid control flow (Q37)
- `/flow:retrofit-project` — 9 phases / 5 gates (adds Phase 3 legacy-cross-reference)
- `/flow:add-domain` — 6 phases / 2 gates (Q47)
- `/flow:add-sub-flow` — 5 phases / 2 gates (Q47)

Phase trees, gate definitions, and per-phase artifacts are documented in the design-rationale memory at the cited Q-lock line refs.

## Validation-first methodology

The plugin itself was designed using a validation-first multi-session pattern — drafter session reads canonical memory first, orchestrator session reviews drafts as hypotheses to verify against memory + source files, user has final lock authority. This same discipline is baked into the plugin's review agents: every reviewer validates claims against the artifact before flagging.

## Dependencies

- `workflows` plugin (required for Linear MCP routing — `.mcp.json` is intentionally empty to avoid duplicate registration; see BC-5810 / BC-5811)
- bash 3.x+, python3 3.6+, git 2.x+
- `gh` (soft)

See [CONTRIBUTING.md](./CONTRIBUTING.md) for plugin development conventions.
