# Upstream provenance

`plugins/revops/` was imported from [Jaganpro/sf-skills](https://github.com/Jaganpro/sf-skills) (MIT) via `git subtree add --squash` on **2026-04-20**.

## Pinned commit

- **Source repo:** https://github.com/Jaganpro/sf-skills
- **Branch:** `main`
- **Commit SHA:** `ff1ab745b20f3e55178132165282ce80b088cc15`
- **Short SHA:** `ff1ab74`

## What was imported

The full upstream tree (36 skills, 7 agents, hooks, LSP loops, scoring rubrics, scripts, shared utilities, tests, tools, docs, and the MIT LICENSE) landed under `plugins/revops/` via squash merge.

## What was filtered out (BC-5789)

After import, BC-5789 removed 22 skills + all 7 agents that don't apply to Brite's stack. See `docs/decisions/007-revops-plugin-design.md` §3.5 for the locked filter rationale, and `docs/precedents/BC-5789.md` (TBD) for the per-item audit.

**Removed (22 skills):**

- 5 sf-ai-* (Agentforce — Brite doesn't license)
- 7 sf-datacloud-* (Data Cloud — Brite uses Snowflake + dbt)
- 7 sf-industry-* (Communications/Media/Energy + OmniStudio Industries — wrong vertical)
- 1 sf-vlocity-build-deploy (legacy Vlocity CLI)
- 1 sf-flex-estimator (Agentforce + Data Cloud cost projections)
- 1 sf-diagram-nanobananapro (Nano Banana Pro AI image generation)

**Removed (7 agents):**

- 4 with deleted skill dependencies: fde-engineer, fde-experience-specialist, fde-qa-engineer, fde-strategist
- 3 with KEEP-only dependencies, deferred to a follow-up porting issue: fde-release-engineer, ps-solution-architect, ps-technical-architect (Brite agent infra evaluation)

**Retained (14 skills):**

sf-apex, sf-connected-apps, sf-data, sf-debug, sf-deploy, sf-diagram-mermaid, sf-docs, sf-flow, sf-integration, sf-lwc, sf-metadata, sf-permissions, sf-soql, sf-testing.

13 of these will be Brite-customized via Phase 3 issues (BC-5793 through BC-5805). sf-diagram-mermaid ships unmodified.

## Sync model

**Fork-by-default.** We treat `plugins/revops/` as our code going forward (per ADR-007 §3.2). No automatic upstream pulls.

If we ever want to pull upstream improvements:

```bash
git subtree pull --prefix=plugins/revops https://github.com/Jaganpro/sf-skills main --squash
```

This will surface merge conflicts on any Brite-customized files. Keeping upstream skill names (per ADR-007 §3.6) reduces conflict density on directory renames; per-skill content customization will still produce conflicts on the same files.

## Attribution

Original work © Jaganpro and contributors, MIT-licensed. See `plugins/revops/LICENSE` for the verbatim license text. Each Brite-customized skill carries an attribution header inside its `SKILL.md`:

```
# Brite-customized from Jaganpro/sf-skills@ff1ab74
# Original skill: <name> (MIT)
# This file layers in Brite conventions from brite-salesforce/CLAUDE.md
```

## Re-importing deleted content

Any deleted skill or agent can be recovered from the subtree squash commit `bc47155` (or upstream `ff1ab74`):

```bash
git checkout bc47155 -- plugins/revops/<path>
```
