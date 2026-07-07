# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Superpowers methodology + compound engineering + Linear integration.** A Process + Org plugin bundle for the Brite organization — structured workflow (brainstorm → plan → worktree → execute → review → compound → audit) with Linear woven into every step. No build process; changes are pure markdown/JSON.

## Linear Project

Project: **Brite Skill Packs** (team: Brite Company, prefix: `BC-`, not `BRI-`).
Sibling projects (same team, same prefix, same initiative — created 2026-05-27 4-layer re-org): **Brite Orchestration Layer** (Layer A), **Brite Knowledge Layer** (Layer D), **Brite Runtime & Harness** (Layer B). See `docs/history/prd-m5-m8-archive.md`.

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
- **Independent review receipt pattern:** [`docs/guides/independent-review-receipt.md`](docs/guides/independent-review-receipt.md) — handoff prompt → fresh session → structured receipt back; use before merging bash/shell logic changes.

## Architecture Decisions

On-demand ADR index moved to [docs/architecture-decisions.md](docs/architecture-decisions.md); decisions live in `docs/decisions/`.

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
- **Not domain**: Skills that teach framework-specific patterns (React, Python, CI/CD) belong in domain plugins. Process skills (brainstorming, planning, execution) stay here.

## Repository Structure

Multi-plugin monorepo — full layout in [docs/repository-structure.md](docs/repository-structure.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Skill Routing

Skills activate via their `description` field — Claude matches user intent against descriptions. Full catalog (Inner Loop, Backend & Quality, Design, Post-Plan, Utility) in [ARCHITECTURE.md#skill-routing](ARCHITECTURE.md).

## Review Agents

Override the default review agent selection by adding a `## Review Agents` section to your project CLAUDE.md with `include:` / `exclude:` lists (Tier 1 agents — code, security, performance — cannot be excluded). Full spec, depth modes, confidence scoring, and model tiering in `docs/workflow-guide.md`.

## Agent skills

### Issue tracker

Issues live in **Linear** (Brite Company team, `BC-` prefix, *Brite Skill Packs* project) via the workflows-plugin Linear MCP — not GitHub Issues, despite the GitHub remote. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles with default label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context; ADRs live in `docs/decisions/` (not `docs/adr/`). See `docs/agents/domain.md`.

## Gotchas

Full catalog: [docs/gotchas.md](docs/gotchas.md) — read before touching `plugin.json`, hooks, versions, or CI. Two that gate every session: **bump the plugin version in the SAME commit** as any `plugins/<p>/{hooks,skills,commands,agents}/**` edit (plugin.json + marketplace.json); and **plugin.json is a strict schema** — any unrecognized field silently hard-fails.
