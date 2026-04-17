# Changelog

All notable changes to the marketing plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Brite-specific brand content in product-marketing-context skill
- Social media strategy skill stub
- Content strategy skill stub

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
