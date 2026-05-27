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

## Architecture Decisions

On-demand references — read when working on these subsystems, not auto-loaded every session:

- [ADR-001: Cross-repo import solution](docs/decisions/001-cross-repo-import-solution.md) — Context7 for cross-repo handbook access
- [ADR-002: Trait evolution mechanism](docs/decisions/002-trait-evolution-mechanism.md) — Trait add/remove commands + auto-detect
- [ADR-003: Plugin distribution architecture](docs/decisions/003-plugin-distribution-architecture.md)
- [ADR-007: RevOps plugin design decisions](docs/decisions/007-revops-plugin-design.md) — naming, subtree, augment-not-replace, skill filter, MCP scope
- [ADR-008: tam-mapping enrichment pluggability](docs/decisions/008-tam-mapping-enrichment-pluggability.md) — provider selection via userConfig, shared input/output schema, swap path
- [ADR-009: SF capability adoption framework](docs/decisions/009-sf-capability-adoption.md) — 6-check framework (runtime model, license, plugin slot, toolset breadth, GA gate, domain fit) with worked examples
- [ADR-010: Plugin secret-config canon](docs/decisions/010-plugin-secret-config-canon.md) — Bitwarden + `bw-run.sh` broker for stdio MCPs and CLI scripts; HTTP MCPs covered by BC-5551 exception

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
    data/canonicals/               # GTM canonicals (slug+display+personas+offers per ADR-016; lint at plugins/marketing/scripts/lint_canonicals.py)
    scripts/                       # Plugin-owned scripts (bw-run.sh secret broker, tam-map/, lint_canonicals.py)
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

- **`plugin.json` strict schema.** Any unrecognized field causes silent hard failure with no error. Allowlist: `name`, `description`, `author`, `version`, `homepage`, `repository`, `license`, `keywords`, `commands`, `skills`, `mcpServers` (inline object only), `userConfig` (inline object declaring user-prompted settings; use with `sensitive: true` for secrets stored in OS keychain — but note that `${user_config.*}` substitution into HTTP MCP headers is currently broken in Claude Code (BC-5551), see `email-bison.md` § Known Claude Code limitation; for stdio MCPs the recommended pattern is OS env-vars populated by `bw-run.sh` rather than `userConfig` substitution, see [CONTRIBUTING.md § Plugin secret-config canon](CONTRIBUTING.md#plugin-secret-config-canon) — full Rejected Alternatives and rotation semantics in [ADR-010](docs/decisions/010-plugin-secret-config-canon.md)). **Never** add `agents`, `hooks`, or `mcpServers` as string path — they're auto-discovered by convention.
- **`userConfig` field paired with an ADR-defined "unset → auto-detect" resolution: omit `default`.** When an ADR specifies that an unset `${user_config.<field>}` triggers a probe-fallback chain (e.g., ADR-008 for `enrichment_provider` probes `brite_mcp` → `brite_cli` → `blitz_waterfall`), the userConfig MUST NOT specify a `default` — the field would never be "unset" at substitution time, silently making the auto-detect path unreachable. Cross-cite the ADR's resolution-order section in the userConfig description. Origin: BC-5832 review-fix.
- **`.claude-plugin/marketplace.json` registers a plugin; it does not install it.** A plugin can be in the marketplace registry, on disk under `plugins/<name>/`, and pass `scripts/validate.sh` while never appearing in `claude plugin list` — that's "registered but uninstalled." Symptom: commands, skills, AND agents are all absent from dispatchable lists (not just one of the three). Source of truth: `claude plugin list` output and `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` presence. Fix: `claude plugin install <name>@<marketplace>` (or `/plugin install` slash-command equivalent) once per scope (user or project). Defense-in-depth: `scripts/validate.sh` cross-checks every plugin in `.claude-plugin/marketplace.json` against `claude plugin list` and emits `WARN` for any registered-but-uninstalled plugin. Costly precedent: BC-9023 — BC-6998 iter 1 burned a full session diagnosing a "plugin-loader bug" that was actually an uninstalled plugin; the 6-plugin / 28-agent counts `/reload-plugins` kept printing were the totals WITHOUT flow-architecture, which iter 1's operator read as evidence the plugin was loading-but-broken.
- **MCP server soft cap ~5–6 per plugin (advisory).** Per-plugin, not global — user-level registrations (e.g., Email Bison) do not count. The cap protects startup latency and context budget, both measurable. A plugin at or near the cap must demonstrate `< 2s` startup-latency delta and `< 500 tokens` context-budget delta against a clean-session baseline before merge. See [`docs/research/tam-map-port-policy.md`](docs/research/tam-map-port-policy.md) § 1 for methodology.
- **Anchor `/.mcp.json` in `.gitignore`**, never unanchored `.mcp.json`. The unanchored form would match at any depth and silently ignore `plugins/*/.mcp.json` files, breaking plugin distribution.
- **Skill frontmatter for MCP tools:** `allowed-tools: mcp__plugin_<plugin>_<server>__*` for multi-tool servers, `mcp__plugin_<plugin>_<server>__<tool_name>` for single-tool servers. The `plugin_<plugin>_` namespace is auto-generated from the OWNING plugin's `.mcp.json` (where the server is registered) — don't hand-edit. **Cross-plugin invocation IS supported**: a skill in plugin A can declare `mcp__plugin_B_<server>__*` and it resolves at runtime, because the namespace is globally addressable. Confirmed sibling pattern: `plugins/cadence/skills/linear-housekeeping/SKILL.md` declares `mcp__plugin_workflows_linear-server__*` from a non-workflows plugin and works. `allowed-tools` is NOT cross-validated: listing a server that isn't registered ANYWHERE (typo, deleted server) fails silently at runtime (the first availability probe hits a missing server and halts). Cross-check every `mcp__plugin_<plugin>_<server>__*` entry against `plugins/<owning-plugin>/.mcp.json` before merging. See the pattern guide for the full rule set.
- **Hook `type: "prompt"` requires a concrete model ID.** Tier aliases (`haiku`, `sonnet`, `opus`) are rejected by the hook evaluator with `Hook evaluator API error: There's an issue with the selected model (...)`. Use `claude-haiku-4-5` (or the dated `claude-haiku-4-5-20251001`). Agent frontmatter is a separate resolver that still accepts tier names. **Enforced by `scripts/_lib/lint_hooks.py`** (runs in `validate.sh` + via `validate-single.sh hooks`).
- **PreToolUse/PostToolUse plugin hooks now fire** — upstream bug [#6305](https://github.com/anthropics/claude-code/issues/6305) previously suppressed them. Recent Claude Code versions run them normally. Hook errors fail open (the tool call proceeds) but surface as red banners in the UI.
- **Bump plugin version in the SAME commit as any edit under `plugins/<plugin>/{hooks,skills,commands,agents}/**`.** Clients' plugin cache is keyed by plugin version; deferring the bump leaves every client serving the old content. Bump BOTH `plugins/<plugin>/.claude-plugin/plugin.json` and the matching `.claude-plugin/marketplace.json` entry. Costly precedent: BC-6000 — a hook fix sat uncollected in cache for 4+ `/workflows:ship` sessions before anyone diagnosed the cause.
- **`context: fork` has upstream bugs** ([#16803](https://github.com/anthropics/claude-code/issues/16803), [#17283](https://github.com/anthropics/claude-code/issues/17283)) — skills declaring it run inline in the parent context for now.
- **`SessionStart` `command`-hook stdout is model-context-only in Claude Code v2.1.x** (observed in v2.1.123; upstream pins window) — stdout reaches the model via `<system-reminder>` (skills activate normally) but no longer renders as a visible terminal block. Tracked upstream as [#24425](https://github.com/anthropics/claude-code/issues/24425). For user-visible session context, use statusline (`statusLine` setting) or a slash command. Diagnosed in BC-6434.
- **Bash scripts using `set -u` MUST guard `"${arr[@]}"` of arrays that may be empty.** macOS ships bash 3.2 by default; bash 3.2 + `set -u` errors with `arr[@]: unbound variable` for empty-array expansion. Wrap with `if [ "${#arr[@]}" -gt 0 ]; then for x in "${arr[@]}"; do ...; done; fi`. Surfaced in BC-6905 — the spike's verbatim wrapper code wouldn't have run on macOS without this guard.
- **`validate.sh` Step-sequence lint treats `## Step N.M` as duplicate Step N.** The regex `^#{2,4} Step [0-9]+([^0-9a-zA-Z]|$)` extracts the leading integer; `.` matches `[^0-9a-zA-Z]`, so `## Step 1.5 — ...` registers as Step 1 + creates `gap Step 1 to Step 2` AND `duplicate Step 1` errors. Use the sub-step letter-suffix form `## Step 1b — ...` instead — `1b` fails the regex (next char after `1` is alphanumeric), excluded from sequence counting, no false-positive. Per the validator's own comment: "Sub-steps like 'Step 2b' are excluded." Surfaced in BC-8724 iter-1 fixes 2026-05-19 when a new parse-time-validation sub-step landed as `## Step 1.5` and blocked validate.sh.
- **APFS case-insensitive `.gitignore` matches silently swallow new files.** macOS APFS is case-insensitive by default; git's gitignore matching follows the filesystem's case-sensitivity. A top-level `AUDIT.md` rule (or any case-overlapping pattern) silently matches `audit.md`, `Audit.md`, etc. — symptom: file written + visible via `ls`, but absent from `git status` and `git ls-files` (not even `??`). Always run `git check-ignore -v <path>` after writing a new file whose name case-insensitively overlaps an existing gitignore pattern; add an explicit `!path/to/file.md` negation when needed. Surfaced in BC-6969 ([precedent task-4](docs/precedents/BC-6969.md#BC-6969-task-4)) — `audit.md` was silently swallowed by `.gitignore`'s `AUDIT.md` rule.
- **`git push --force-with-lease` is carved out for user-owned branches only.** The Haiku prompt-hook classifier (BC-11117, workflows v3.30.1) treats `--force-with-lease` as safe on feature branches matching `holden/*`, `feat/*`, `fix/*`, `bug/*`, `refactor/*`, `docs/*`, `chore/*`, or any `<username>/*` pattern. It still blocks `--force-with-lease` on protected refs (`main`, `master`, `release/*`, `prod/*`, `production/*`) — use the `!`-prefix escape hatch for those. Plain `--force` / `-f` is always blocked regardless of target branch. Regression-locked by `scripts/test_security_hook_classifier.sh` (10 scenarios, wired into validate.sh §2d).
