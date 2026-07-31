# Changelog

All notable changes to the marketing plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- **ADR-008 default-flip executed (BC-16888)** — `enrichment_provider` auto-detect now resolves `brite_mcp` first when the brite-enrichment MCP is registered (was: opt-in only; auto-detect went `brite_cli` → `blitz_waterfall`). Engine-maturity sign-off recorded as an operator decision (2026-07-08) on BC-16888; the fail-open fall-through to `blitz_waterfall` is unchanged. ADR-008 + `tam-mapping` + `list-building` updated in lockstep (`plugin.json` and `/marketing:tam-map` already described the target order). BC-13096/BC-6322 continue as hardening tracks.

### Added
- **bw-run.sh opt-in Keychain self-unlock** — when `BW_SESSION` is absent or stale, the wrapper now mints a session itself from the macOS Keychain item `bw-master` (`bw unlock --raw --passwordenv`); machines without the item keep the original fail-closed behavior byte-for-byte, and error messages gain a provisioning hint. Kills both the vault-lock-mid-session recovery tax and the "MCP spawn fails because the launching shell had no `BW_SESSION`" mode. Both subprocesses that touch the master password must resolve to a trusted path — a known install location, or a mode-0700 directory only its owner can traverse — and the `BW_RUN_BW_BIN` / `BW_RUN_SECURITY_BIN` overrides are held to the same check instead of bypassing it. The Keychain lookup is account-scoped to match the provisioning command. 8 new test cases (T16–T23) + a PATH-stubbed `security`; ADR-010 § 1 and the CONTRIBUTING canon updated in lockstep.
- Brite-specific brand content in product-marketing-context skill
- Social media strategy skill stub
- Content strategy skill stub

## [0.13.8] - 2026-06-10

BC-13165 — activate the `brite_mcp` bulk-enrichment door in the marketing skills (the deferred Task 1 of BC-6170). The published `enrichment` MCP server already carries `bulk_enrich` and points at the live Railway REST door (BC-5316 / BC-13016); this grants the skills permission to call it, so selecting `brite_mcp` finally routes through the bulk door instead of silently falling through to `blitz_waterfall`. Opt-in only — the auto-detect default stays `blitz_waterfall` (the default-flip remains deferred pending an engine-maturity sign-off; see ADR-008 Future Work).

### Changed
- `list-building` + `tam-mapping` `allowed-tools`: granted `mcp__plugin_marketing_enrichment__bulk_enrich` so the `brite_mcp` enrichment provider is operative (least-privilege — only the bulk-door tool, not the whole enrichment surface).
- Removed now-stale "pending BC-5316" caveats throughout both skills; reworded the `bulk_enrich`-unavailable fall-through message to a runtime-reachability reason ("MCP server not reachable") while keeping the `blitz_waterfall` safety net.
- ADR-008: marked the config-invariant pair (server-SHA pin + `allowed-tools` grant) satisfied; kept the auto-detect default-flip deferred behind an engine-maturity sign-off (bulk-path robustness BC-13096 + throughput BC-6322).

## [0.10.0] - 2026-05-29

BC-5537 (plugins half) — register the Brite Enrichment MCP (3-tool scaffold) so marketing skills can reach the enrichment engine.

### Added
- `enrichment` server in `plugins/marketing/.mcp.json` — stdio + `bw-run.sh` broker (7 provider keys from the Engineering Bitwarden collection), running `tools/enrichment-mcp/brite-enrichment-mcp` from `brite-data-platform` pinned to SHA `6854446` (PR #181). Non-secret config (`USE_MOCK_PROVIDERS=False`, `MARTS_DATABASE=ANALYTICS`, `MARTS_SCHEMA=MARTS`) in the entry's `env` block; Snowflake creds sourced from the developer's shell profile.
- `tools/integrations/brite-enrichment.md` — integration guide for the 3-tool MVP (`check_enrichment_health`, `enrich_contacts`, `query_entity`): auth, registration, tool inventory, common workflow, confirmation gates, costs, gotchas. Full 9-command surface deferred to BC-5538.

### Changed
- `email-bison.md` upstream-integration note now points at the Brite Enrichment MCP (was "No MCP server exists for the enrichment engine").
- `_template/OUTBOUND-SKILL-TEMPLATE.md` §5 availability-check list adds the `enrichment` server (`check_enrichment_health`).

## [0.3.13] - 2026-04-29

BC-6301 — 5th BC-5906 round-2 follow-up. Two distinct sequence-step spec drifts in `/marketing:launch-campaign` Phase 9.

### Fixed
- **Sx-13** — `variant` field on sequence steps is BOOLEAN (`false`/`true`), not the string `"A"`. Updated `launch-campaign.md` Phase 9 request body example (lines 615 + 623). EB API spec marks the field boolean; sending `"A"` would silently coerce or 422.
- **Sx-14** — EB auto-prepends `Re: ` to subjects when `thread_reply: true`. Reversed the spec rule in `launch-campaign.md` Phase 9 step-2 validation (line 600), updated the explanatory text below the JSON body (line 630), and corrected the Phase 10 preview example (line 689) to show the auto-prepend explicitly. Step 2 subjects must NOT include `Re:` in the artifact — EB inserts it at delivery, otherwise the recipient sees `"Re: Re: ..."`.
- Swept `email-copywriting/SKILL.md` for the same `Re:` prefix rule (4 instances: rule statement at line 55, skeleton step-2 bump examples at lines 135 + 155, and JSON artifact schema example at line 237). All corrected.
- Updated production-template artifact `docs/dogfood/bc-5826/test-copy.json` step_2.subject to drop the `Re:` prefix. (Round-2 evidence file `docs/dogfood/bc-5906/test-copy.json` kept verbatim as historical input that surfaced Sx-14.)
- Co-updated `tools/integrations/email-bison.md` § Known gotchas with both findings — variant-boolean and auto-Re: prepend now documented at the canonical EB integration-doc layer.

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
