# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Superpowers methodology + compound engineering + Linear integration.** A Process + Org plugin bundle for the Brite organization — structured workflow (brainstorm → plan → worktree → execute → review → compound → audit) with Linear woven into every step. No build process; changes are pure markdown/JSON.

## Linear Project

Project: **Brite Plugin Marketplace** (team: Brite Company, prefix: `BC-`, not `BRI-`).

## Quick Start

```bash
./scripts/validate.sh                              # Validate all plugins (CI-equivalent)
./scripts/check-guardrails.sh --claude-md CLAUDE.md # Enforce CLAUDE.md size + anti-slop
./scripts/dev-setup.sh                             # Symlink plugin for live editing
./scripts/release.sh <major|minor|patch> [name]    # Cut a release
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full script reference, `plugin.json` schema, frontmatter rules, and CI checks.

## Key References

- **Memory:** `memory/MEMORY.md` — session-spanning knowledge (project status, recent decisions, session history). Always loaded at session start; check it before asking about prior work.
- **Skill ↔ tool integration pattern:** [`docs/guides/skill-tool-integration-pattern.md`](docs/guides/skill-tool-integration-pattern.md) — how skills reference MCP servers. Apply the 6-item PR checklist before merging any skill that calls an external service.
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md) — plugin resolution, runtime flow, hook execution, full skill routing catalog.
- **Marketing skill porting:** [`docs/guides/marketing-skill-porting.md`](docs/guides/marketing-skill-porting.md) — upstream `coreyhaines31/marketingskills` → `plugins/marketing/` conventions.

## Architecture Decisions

On-demand references — read when working on these subsystems, not auto-loaded every session:

- [ADR-001: Cross-repo import solution](docs/decisions/001-cross-repo-import-solution.md) — Context7 for cross-repo handbook access
- [ADR-002: Trait evolution mechanism](docs/decisions/002-trait-evolution-mechanism.md) — Trait add/remove commands + auto-detect
- [ADR-003: Plugin distribution architecture](docs/decisions/003-plugin-distribution-architecture.md)
- [ADR-007: RevOps plugin design decisions](docs/decisions/007-revops-plugin-design.md) — naming, subtree, augment-not-replace, skill filter, MCP scope
- [Context-Skill Standard](docs/designs/BC-1966-context-skill-standard.md)

## Company Context

initiative: Shared Infrastructure to Move Quick
goal: Universal agent platform — structured discovery routes any project type to domain plugins, with handbook as company brain and autonomous execution
team: Brite Company / lead: Amanuel Belay
related-projects: Brite Enterprise Data Platform, Brite Handbook
handbook-library: /brite-nites/handbook
handbook-topics: architecture, coding-standards, tools, team-structure, onboarding

## Plugin Philosophy

- **Process**: Superpowers' full workflow with TDD, subagent-per-task execution, and compound knowledge accumulation
- **Org**: Linear integration at every step, security hooks, team conventions
- **Not domain**: Skills that teach framework-specific patterns (React, Python, CI/CD) belong in domain plugins. Process skills (brainstorming, planning, execution) stay here. Use context7 MCP for framework docs.

## Repository Structure

Multi-plugin monorepo. Each plugin under `plugins/<domain>/` follows the same structure.

```
.claude-plugin/marketplace.json    # Plugin registry (lists all plugins)
plugins/
  workflows/                       # Process + org plugin (primary)
    .claude-plugin/plugin.json     # Plugin metadata
    commands/*.md                  # Slash commands
    skills/*/SKILL.md              # Auto-invoked skills (+ _shared/ utilities)
    agents/*.md                    # Review and utility agents
    hooks/hooks.json               # SessionStart hooks (auto-loaded)
    .mcp.json                      # MCP server configurations
  marketing/                       # Marketing domain plugin
    skills/*/SKILL.md              # Domain skills (context-skill pattern)
    tools/integrations/*.md        # Tool integration guides (see pattern)
    references/                    # Shared reference content read by skills (MIT upstream port, see UPSTREAM.md)
    hooks/hooks.json
    .mcp.json
  revops/                          # SF dev + CRM data (subtree from Jaganpro/sf-skills, MIT — see UPSTREAM.md)
    skills/                        # 14 retained SF skills (filtered from upstream 36)
    .mcp.json                      # plugin:revops:salesforce
  cadence/                         # Weekly planning cadence (commands/weekly.md — 5 phases, 3 gates, resume breadcrumb; agents/narrative-writer.md drives Phase 4)
```

## Skill Routing

Skills activate via their `description` field — Claude matches user intent against descriptions. Full catalog (Inner Loop, Backend & Quality, Design, Post-Plan, Utility) in [ARCHITECTURE.md#skill-routing](ARCHITECTURE.md).

## Review Agents

Override the default review agent selection by adding a `## Review Agents` section to your project CLAUDE.md with `include:` / `exclude:` lists (Tier 1 agents — code, security, performance — cannot be excluded). Full spec, depth modes, confidence scoring, and model tiering in `docs/workflow-guide.md`.

## Gotchas

- **`plugin.json` strict schema.** Any unrecognized field causes silent hard failure with no error. Allowlist: `name`, `description`, `author`, `version`, `homepage`, `repository`, `license`, `keywords`, `commands`, `skills`, `mcpServers` (inline object only), `userConfig` (inline object declaring user-prompted settings; use with `sensitive: true` for secrets stored in OS keychain — but note that `${user_config.*}` substitution into HTTP MCP headers is currently broken in Claude Code, see `email-bison.md` § Known Claude Code limitation). **Never** add `agents`, `hooks`, or `mcpServers` as string path — they're auto-discovered by convention.
- **MCP server soft cap ~5–6 per plugin.** The cap is per-plugin, not global. Adding a 6th eats context budget and startup latency — retire one first.
- **Anchor `/.mcp.json` in `.gitignore`**, never unanchored `.mcp.json`. The unanchored form would match at any depth and silently ignore `plugins/*/.mcp.json` files, breaking plugin distribution.
- **Skill frontmatter for MCP tools:** `allowed-tools: mcp__plugin_<plugin>_<server>__*` for multi-tool servers, `mcp__plugin_<plugin>_<server>__<tool_name>` for single-tool servers. The `plugin_<plugin>_` namespace is auto-generated — don't hand-edit. See the pattern guide for the full rule set.
- **Hook `type: "prompt"` requires a concrete model ID.** Tier aliases (`haiku`, `sonnet`, `opus`) are rejected by the hook evaluator with `Hook evaluator API error: There's an issue with the selected model (...)`. Use `claude-haiku-4-5` (or the dated `claude-haiku-4-5-20251001`). Agent frontmatter is a separate resolver that still accepts tier names. **Enforced by `scripts/_lib/lint_hooks.py`** (runs in `validate.sh` + via `validate-single.sh hooks`).
- **PreToolUse/PostToolUse plugin hooks now fire** — upstream bug [#6305](https://github.com/anthropics/claude-code/issues/6305) previously suppressed them. Recent Claude Code versions run them normally. Hook errors fail open (the tool call proceeds) but surface as red banners in the UI.
- **`context: fork` has upstream bugs** ([#16803](https://github.com/anthropics/claude-code/issues/16803), [#17283](https://github.com/anthropics/claude-code/issues/17283)) — skills declaring it run inline in the parent context for now.
