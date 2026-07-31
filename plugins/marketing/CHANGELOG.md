# Changelog

All notable changes to the marketing plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- **Phase 3a's troubleshooting loop gave a healthy machine a false diagnosis.** Step 1 told the user to check `SPIDER_API_KEY` / `AIARK_API_KEY` / `DISCOLIKE_API_KEY` in their own shell and expect `set`. Under `bws` those variables only ever exist in the **child process** the broker spawns — a correctly configured developer has just `BWS_ACCESS_TOKEN`, so all three read empty and step 2 blamed a missing token. The loop now checks the broker credential, and adds a step 2b that lists the project's secrets by name to distinguish a bad token from a missing secret from a misnamed one. (A misnamed secret is worth catching on its own: a secret's name *is* the injected variable name, so the server starts with that variable silently unset.) Reported by Greptile on PR #571.
- **Phase 3d's four-provider probe died on its first line under Linux.** `bws` joins the command argv and runs it through `sh -c`, which is dash on most Linux boxes. The probe body opened `set -uo pipefail`; dash rejects `-o pipefail`, and because `set` is a POSIX special builtin, a failing `set` exits a non-interactive shell outright — so none of the four checks ran. It survived review because it previously ran under an explicit `bash -c`, which the migration dropped, and because macOS `/bin/sh` is bash in POSIX mode and accepts `pipefail`. Now `set -u`, with a comment saying why. Nothing needed `pipefail`: every pipeline ends in `jq -e ... && echo 1 || echo 0`, so `&&` already tests jq's status.
- Stale references to the deleted `bw-run.sh` era inside files this migration rewrote — `BW_SESSION` in a troubleshooting step whose own Step 2b no longer mentions it, "Bitwarden item"/"the wrapper", an inner `bash -c` that no longer exists, and `bw list items --search tam-map-` as a provisioning check.
- Two mapping tables contradicted the naming rule this migration introduces. `scripts/tam-map/README.md` renamed its header to "Secrets Manager secret" but kept the old `tam-map-*` vault item names, and `tools/integrations/brite-enrichment.md` still said "Bitwarden item" and listed 7 rows for an 8-secret project (`ENRICHMENT_API_TOKEN` was missing). An admin provisioning from either table would have created secrets that inject the wrong variable names.
- `CONTRIBUTING.md § Plugin secret-config canon` credited ADR-010 for the decision ADR-044 records, and never linked ADR-044 despite ADR-044 naming that section as its companion doc. It also dropped `jq` from the stated requirements while three files still pipe through it; `jq` is now documented as a setup-and-verification requirement, not an MCP-runtime one.

### Changed

- **The `gbrain-team` broker reads its OAuth client from the environment (ADR-045).** `scripts/gbrain-team-broker.sh` no longer touches Bitwarden, so it needs no `bw`, no `BW_SESSION`, and no `bw unlock`. With ADR-044 this removes the last vault-session consumer in the repo. The same change lands byte-identically in all six plugins that register the server.

  **Required operator action — this breaks existing installs until done:**
  1. Open the Bitwarden item `Brite team gbrain — my client` and export its username as `GBRAIN_CLIENT_ID` and its password as `GBRAIN_CLIENT_SECRET` in your shell profile.
  2. If you have gbrain write access, also export `GBRAIN_WRITE_CLIENT_ID` / `GBRAIN_WRITE_CLIENT_SECRET` from `Brite team gbrain — write OAuth client`.
  3. Re-launch Claude Code from a shell that has them.

  Teammates whose personal client hasn't been issued yet (BC-11758) export the shared Engineering client's values instead — open tier only. The personal → shared fallback chain is gone: it existed only so the broker could *discover* which vault item was present, and an exported variable holds exactly one value. The read and write pairs stay separate on purpose — `--write` never falls back to the read pair, so a missing write client fails loudly at spawn instead of surfacing later as a `put_page` 403 (BC-12113).
- **Secrets now come from Bitwarden Secrets Manager via `bws run` (ADR-044).** `bw-run.sh` and its test suite are deleted. The four secret-bearing MCP servers and the skills' Python CLI call sites authenticate with a machine-account access token scoped to two projects — `brite-claude-tam-map` (7 secrets) and `brite-claude-enrichment` (8). No vault master password, no `bw unlock`, no `BW_SESSION`.

  **Required operator action — this breaks existing installs until done:**
  1. Install `bws`. There is **no Homebrew formula**; `brew install bitwarden-cli` gives you `bw`, a different tool. Use Bitwarden's script or the [`bitwarden/sdk-sm` releases](https://github.com/bitwarden/sdk-sm/releases).
  2. Get a machine-account token from your Brite admin and `export BWS_ACCESS_TOKEN=...` in your shell profile. Once per machine, not per session.
  3. Re-launch Claude Code from a shell that has it. Run `/marketing:setup-tam-map` to verify.

  Two projects rather than one is forced, not preferred: a secret's name *is* its environment variable name, and `PROSPEO_API_KEY` / `ICYPEAS_API_KEY` are each fed from a different vault item depending on caller, so one project cannot hold both. Note also that `bws run --project-id` injects **every** secret in the project — there is no per-key selection, so each server sees its whole project.

  Why the wrapper was removed rather than hardened: an attempt to keep it (PR #565) produced eight security findings across nine review rounds, five of them introduced by the hardening itself. All traced to one inversion — a broker holding the key to the entire vault in order to fetch eleven vendor API keys. ADR-044 records the analysis.
- **ADR-008 default-flip executed (BC-16888)** — `enrichment_provider` auto-detect now resolves `brite_mcp` first when the brite-enrichment MCP is registered (was: opt-in only; auto-detect went `brite_cli` → `blitz_waterfall`). Engine-maturity sign-off recorded as an operator decision (2026-07-08) on BC-16888; the fail-open fall-through to `blitz_waterfall` is unchanged. ADR-008 + `tam-mapping` + `list-building` updated in lockstep (`plugin.json` and `/marketing:tam-map` already described the target order). BC-13096/BC-6322 continue as hardening tracks.

### Added
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
