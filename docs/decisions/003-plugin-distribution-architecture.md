# 003. Plugin Distribution Architecture: Monorepo Marketplace

**Status:** Accepted
**Date:** 2026-03-30

> **Amendment 2026-07-08 (BC-16297 / BC-16819):** the monorepo-marketplace decision stands, but its release tooling changed — `scripts/release.sh` + the root `VERSION` file were **retired**. Independent per-plugin versioning (below) is now done via per-PR bumps in `plugin.json` + `marketplace.json`; there is no bundle release step. The `release.sh` / "needs per-plugin release support (BC-1728)" references below are historical.

## Context

PRD Section 12, Question 4 (BC-2011):

> Should domain plugins be installable from a registry (like npm), or always bundled in the monorepo? Registry is more scalable but adds complexity. Monorepo is simpler but doesn't support community plugins.

The Brite Agent Platform plans 5-7 domain plugins (marketing, engineering, design, data, etc.) alongside the existing `workflows` plugin. This decision determines the distribution model, versioning strategy, CI/CD architecture, and community contribution path for the entire Plugin Ecosystem Foundation (M4) and Domain Plugin Expansion (M5) milestones.

**Current state:** Single monorepo (`britenites-claude-plugins`) with one plugin (`plugins/workflows/`). Distribution is via git clone. `marketplace.json` lists plugins with relative source paths.

**Constraints:**
- No build process, no dependencies (by design)
- Plugins are markdown files + JSON config + shell scripts
- Team is small — infrastructure overhead must be minimal
- Claude Code plugin system is still evolving (upstream bugs like #6305)
- Community contribution is aspirational but not an immediate need

## Options Considered

### Option 1: Monorepo Marketplace (current approach)

All Brite plugins live in `plugins/` subdirectories within this repo. `marketplace.json` lists each with relative paths. External consumers add the repo as a marketplace.

- **Pros**: Zero new infrastructure. Atomic cross-plugin changes. Single CI pipeline. Existing tooling (validate.sh, release.sh, create-plugin) already works. Matches Anthropic's official distribution model.
- **Cons**: All plugins versioned together. Repo grows larger (though it's mostly markdown). Community plugins can't live here.

### Option 2: Separate Repos Per Plugin

Each domain plugin gets its own GitHub repo with its own `marketplace.json`.

- **Pros**: Independent versioning and release cycles. Smaller repos.
- **Cons**: Duplicated CI, validation scripts, and templates across N repos. Can't make atomic cross-plugin changes. More infrastructure to maintain. Harder to keep consistency across plugins.

### Option 3: npm Distribution

Plugins published as npm packages, installed via `marketplace.json` npm source type.

- **Pros**: Standard package management. Version pinning. Familiar tooling.
- **Cons**: Adds package.json, npm publish pipeline, and package management overhead to a repo that deliberately has no dependencies or build process. Doesn't align with the "no build, no deps" philosophy. Claude Code plugins are markdown — npm is overkill.

### Option 4: Hybrid (Core monorepo + registry for extras)

Core plugins in monorepo, community plugins installed from external sources.

- **Pros**: Best of both worlds — internal simplicity + external extensibility.
- **Cons**: Requires designing and maintaining a registry mechanism. Additional complexity for a use case (community plugins) that isn't needed yet.

## Ecosystem Research

Surveyed how other Claude Code plugin authors handle distribution:

| Project | Stars | Model | Distribution |
|---------|-------|-------|-------------|
| **claude-plugins-official** (Anthropic) | — | Monorepo marketplace, 40+ plugins | Central `marketplace.json`, plugins in subdirectories |
| **gstack** (Garry Tan) | 57K | Single plugin, 31 skills | `git clone` → `~/.claude/skills/gstack` |
| **marketingskills** (Corey Haines) | — | Single plugin, 33 skills | Single plugin in `marketplace.json`, GitHub distribution |

**Key finding:** The monorepo marketplace is the dominant pattern for multi-plugin catalogs. Anthropic's official plugin marketplace uses exactly this approach. Single-plugin repos exist but are used by authors who only have one plugin.

**Claude Code source types:** The plugin system natively supports 5 source types: relative paths, GitHub repos, git URLs, git subdirectories (sparse clone), and npm packages. The `git-subdir` source type means a monorepo can serve as a distributed registry — external users can install individual plugins from subdirectories without cloning the entire repo.

## Decision

**Monorepo marketplace** — all Brite domain plugins live in `plugins/` subdirectories within this repo, listed in `.claude-plugin/marketplace.json` with relative source paths. This validates and continues the current architecture.

**Distribution model:**

```
INTERNAL (development):
  marketplace.json → { "source": "./plugins/<name>" }
  Developers work directly in the monorepo

EXTERNAL (consumers):
  /plugin marketplace add Brite-Nites/britenites-claude-plugins
  Users get all Brite plugins, enable/disable individually

COMMUNITY (future, if needed):
  Third-party authors create their own repos with marketplace.json
  Users add them separately: /plugin marketplace add author/their-plugin
  No changes needed to the Brite monorepo
```

**Versioning:** Independent per-plugin versioning. Each plugin has its own version in `plugin.json` and its corresponding `marketplace.json` entry. New plugins start at `0.1.0`. The `workflows` plugin retains its existing version lineage. `validate.sh` checks that each plugin's `plugin.json` version matches its marketplace entry. `release.sh` needs per-plugin release support (tracked by BC-1728).

**Rationale:** The monorepo approach requires zero new infrastructure, matches Anthropic's official distribution model, and leverages existing tooling that already supports multiple plugins (validate.sh uses `plugins/*/` glob, release.sh discovers all plugin.json files dynamically). The "community plugins" concern is a non-issue — Claude Code's marketplace system natively supports adding multiple marketplaces from different repos.

## Consequences

### Positive

- Zero infrastructure changes needed — existing tooling supports multi-plugin monorepo
- Atomic cross-plugin changes (shared templates, hooks, MCP configs)
- Single CI pipeline validates all plugins together
- External consumers get a one-command install for all Brite plugins
- Independent versioning allows new plugins to start at `0.1.0` and iterate at their own pace
- Unblocks BC-1724 (scaffold marketing plugin) and all M4/M5 work

### Negative

- Independent versions require per-plugin release tooling (BC-1728)
- Repo size grows with each plugin (mitigated: plugins are markdown, not heavy assets)
- Community plugins require separate repos (mitigated: this is how the ecosystem works anyway)

### Infrastructure Readiness

| Component | Multi-plugin ready? | Notes |
|-----------|-------------------|-------|
| validate.sh | Yes | Uses `plugins/*/` glob |
| release.sh | No (BC-1728) | Hardcodes `plugins[0]` — needs per-plugin release support |
| create-plugin command | Yes | Scaffolds into `plugins/<name>/` |
| marketplace.json | Yes | Array of plugin entries |
| Test scripts | No (BC-1728) | Hardcoded to `plugins/workflows/` — tracked separately |
| telemetry-log.sh | No (BC-1728) | Hardcoded to `plugins/workflows/` — tracked separately |

## Reversibility

If independent versioning becomes critical (e.g., a plugin needs rapid iteration while others are stable):

1. Extract the plugin to its own repo
2. Update marketplace.json to reference it via GitHub source instead of relative path
3. No consumer-facing changes — `/plugin install <name>@brite-claude-plugins` still works

Migration cost is low because Claude Code's source types are interchangeable — switching from relative path to GitHub source is a one-line change in marketplace.json.

## Community Contribution Strategy

- **Internal contributions:** Fork + PR to this repo (standard open source workflow)
- **External/third-party plugins:** Authors create their own repos with `marketplace.json`. Users add them as separate marketplaces. No gatekeeping needed.
- **Discovery:** Community plugins can be listed in awesome-claude-code-plugins or similar curated lists
- **No plugin registry infrastructure needed** — Claude Code's marketplace system handles distribution natively
