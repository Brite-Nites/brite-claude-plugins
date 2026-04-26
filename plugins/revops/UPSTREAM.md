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

Original work © Jaganpro and contributors, MIT-licensed. See `plugins/revops/LICENSE` for the verbatim license text. Each Brite-customized skill carries an attribution comment at the top of its `SKILL.md` (above the H1):

```
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md. -->
```

This wording is canonical across all Phase 3 customized skills (BC-5793 onward) and matches the `T2` verification grep in each issue body. References-directory files adapted from upstream carry the same comment prefixed with `<!-- Parent: <skill>/SKILL.md -->` on line 1.

## Lineage classes

Three lineage classes exist within `plugins/revops/skills/`:

### 1. Adapted from upstream (Brite layer on top of Jaganpro)

The dominant class — Phase 3 customized skills. Frontmatter pattern: `version: <upstream>-brite.1`, dual-author attribution, `upstream: Jaganpro/sf-skills@ff1ab74` pin, plus a `## Brite Context` + `## Brite <Domain> Discipline` section layered onto the upstream body. Attribution comment opens with `<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). ... -->`.

Members: `sf-apex`, `sf-connected-apps`, `sf-data`, `sf-debug`, `sf-deploy`, `sf-flow`, `sf-integration`, `sf-lwc`, `sf-metadata`, `sf-permissions`, `sf-soql`, `sf-testing` (12 skills).

### 2. Adopted verbatim from upstream (no Brite layer)

Precedent set by `sf-docs` in BC-5931 (PR #TBD). The skill's concern (web-retrieval playbook for official Salesforce.com documentation) is upstream-pure with explicit non-goals "no local corpus, no repo-specific scripts" — folding Brite conventions onto it would couple a stable upstream contract to a Brite-volatile artifact inventory. We adopt verbatim and let the orthogonal Brite concern live in a sibling skill.

Frontmatter pattern: **upstream frontmatter unchanged** (no `-brite.1` suffix, no `upstream:` field, original author preserved). The only diff against upstream is a single attribution HTML comment naming the verbatim-adoption decision and pointing at the sibling skill that owns the Brite concern. Comment form:

```
<!-- Adopted verbatim from Jaganpro/sf-skills@ff1ab74 (MIT). Web-retrieval concern only. Brite-internal SF documentation lives in sibling sf-internal-docs (BC-XXXX). -->
```

Members: `sf-docs` (1 skill); `sf-diagram-mermaid` predates this taxonomy and ships fully verbatim with no attribution comment — leaving as-is unless re-evaluated.

### 3. Added by Brite (no upstream)

For Brite-original skills that have no upstream lineage. Precedent will be set by `sf-internal-docs` in BC-6081 (the sibling pattern flagged above, which owns the Brite-internal documentation navigation concern).

Frontmatter pattern: `version: 0.1.0` (semver from scratch, no `-brite.N` suffix), `author: "Brite Company"` (single attribution), no `upstream:` field, no attribution HTML comment (the comment template above is for adapted skills). The `## Brite Context` template is also dropped — every section is Brite-original by definition.

Members: `sf-internal-docs` (planned, not yet authored).

## Re-importing deleted content

Any deleted skill or agent can be recovered from the subtree squash commit `bc47155` (or upstream `ff1ab74`):

```bash
git checkout bc47155 -- plugins/revops/<path>
```
