# Changelog

All notable changes to the marketing plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Brite-specific brand content in product-marketing-context skill
- Social media strategy skill stub
- Content strategy skill stub

## [0.3.0] - 2026-04-19

Guided onboarding for user-level EB registration + updated investigation of plugin-scoped alternatives.

### Added
- New slash command `/marketing:setup-email-bison` — interactive walkthrough that detects current EB MCP registration state and guides the developer through Bitwarden retrieval, shell profile edits, `.mcp.json` registration, reload, and end-to-end verification. Single entry point for first-time onboarding and for recovering from partial/broken setups.
- `plugins/marketing/commands/` directory (first command in the marketing plugin).

### Changed
- `plugin.json` declares `"commands": "./commands/"`.
- `email-bison.md` § One-time per-dev onboarding leads with the `/marketing:setup-email-bison` command; manual 5-step path retained as a fallback.
- `email-bison.md` § Known Claude Code limitation expanded with the 2026-04-19 `${user_config.*}` validation result (token-via-curl returns 200; same value via Claude Code's plugin MCP client fails to connect — same class of bug as `${ENV_VAR}`, different mechanism). Secondary finding noted: two HTTP MCP entries sharing the same `url` are silently deduped in `claude mcp list`.
- `CONTRIBUTING.md § Email Bison MCP Onboarding` updated to lead with the new slash command.

### Infrastructure
- `scripts/validate.sh` + `scripts/check-prereqs.sh` + `CLAUDE.md` plugin.json allowlist now includes `userConfig` — keeps local validators in sync with Claude Code's actual Zod schema (the field is supported even though the substitution it feeds into is currently broken for HTTP headers).

## [0.2.1] - 2026-04-17

Documentation + credential-distribution polish. No new MCP server registrations (the plugin-scoped EB migration originally scoped for BC-5551 was blocked by an upstream Claude Code limitation — see email-bison.md § Known Claude Code limitation).

### Added
- CONTRIBUTING.md § Email Bison MCP Onboarding — documents the Bitwarden-sourced + shell-profile credential-distribution flow for user-level `.mcp.json` registration.
- Engineering Bitwarden item **"Email Bison MCP — API tokens"** as the credential source of truth (replaces the raw-token pattern in the gitignored repo-root `.mcp.json`).

### Changed
- `email-bison.md` § Auth prose flipped from "API key" to "API token" to match the vendor's canonical term (`docs.emailbison.com/get-started/authentication`).
- `email-bison.md` § Registration rewritten to document user-level registration today; § Known Claude Code limitation added citing the upstream bugs that prevent plugin-scoped distribution.

## [0.1.0] - 2026-03-30

### Added
- Initial plugin scaffold
- Domain context skill (product-marketing-context)
- Tools directory structure (clis, integrations, REGISTRY.md)
