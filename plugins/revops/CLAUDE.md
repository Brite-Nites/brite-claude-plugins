# revops Plugin

The Salesforce **engineering** layer — a portable plugin bundling SF dev knowledge (skills), deploy/ops discipline (commands), and the org MCP, usable from any repo. Subtree from [Jaganpro/sf-skills](https://github.com/Jaganpro/sf-skills) (MIT) + Brite customization. Glossary (`revops` / `brite-salesforce` / org aliases) in [`../../CONTEXT.md`](../../CONTEXT.md).

## Charter — three concerns

1. **SF dev knowledge** — 14 skills that auto-activate inside `workflows:*` phases via description-matching.
2. **SF deploy/ops discipline** — the `/revops:*` command lifecycle (onboard → health → deploy → post-deploy).
3. **GTM campaign-sync seam** — `create-sf-campaign` + `update-sf-campaign-status`. **Owned by `marketing`** ([ADR-015](../../docs/decisions/015-gtm-sigma3-sf-campaign-sync.md)), hosted here as commands. NOT part of the core charter — defer GTM logic to marketing.

Locked decisions: [ADR-007](../../docs/decisions/007-revops-plugin-design.md) (design), [ADR-009](../../docs/decisions/009-sf-capability-adoption.md) (capability-adoption 6-check), [ADR-010](../../docs/decisions/010-plugin-secret-config-canon.md) (secret config), [ADR-015](../../docs/decisions/015-gtm-sigma3-sf-campaign-sync.md) (campaign-sync), [ADR-021](../../docs/decisions/021-sfdx-hardis-adoption.md) (sfdx-hardis selective adopt-as-tool), [ADR-022](../../docs/decisions/022-revops-promotion-topology.md) (promotion-topology command model & vocabulary).

## Commands (7)

Deploy lifecycle: `setup-sandbox` (guided auth) → `doctor` (zero-mutation health check) → `deploy-sandbox` → `deploy-prod` → `post-deploy-runbook` (manual steps `sf` can't automate). Every command gates on `AskUserQuestion`, parses `--json` (not stdout), passes `--target-org` explicitly, and runs from inside an SFDX repo (Phase-1 cwd check for `sfdx-project.json`).

Campaign-sync (marketing seam): `create-sf-campaign`, `update-sf-campaign-status` — idempotent, soft-fail.

## Skills (14)

`sf-apex`, `sf-flow`, `sf-lwc`, `sf-soql`, `sf-metadata`, `sf-data`, `sf-testing`, `sf-debug`, `sf-deploy`, `sf-integration`, `sf-connected-apps`, `sf-permissions`, `sf-docs`, `sf-diagram-mermaid`. Filtered from upstream 36 (ADR-007 §3.5). Lineage classes + attribution rules in [`UPSTREAM.md`](UPSTREAM.md). Upstream pinned at `Jaganpro@ff1ab74` (2026-04-20); **fork-by-default, no auto-pulls**.

## MCP Servers (2)

- `plugin:revops:salesforce` — `@salesforce/mcp@0.30.5`, `--orgs DEFAULT_TARGET_ORG --toolsets data,metadata,testing`, **GA-only** (no `--allow-non-ga-tools`). Medium scope (ADR-007 §3.4). Auths via `sf` CLI org login, not embedded secrets.
- `plugin:revops:gbrain-team` — Brite handbook brain, via `scripts/gbrain-team-broker.sh`. Canonical owner is the `brite-core` plugin; revops self-registers for standalone resilience (open consolidation question — see ADR-007 §3.4 update note).

## Relationship to brite-salesforce

`brite-salesforce` (`github.com/Brite-Nites/brite-salesforce`) is the live SFDX metadata repo deploys ship to. Its `CLAUDE.md` is the **authoritative** source for Brite deploy discipline; revops *mirrors* it outward so agents in other repos inherit it. Authority is one-way — when the two disagree, brite-salesforce wins and revops is what's stale.

## Gotchas

- **`sf`, never `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Always pass `--target-org`.** Commands pin `brite-sandbox` / `brite-prod` — never the CLI default org, so behavior is reproducible across machines.
- **The MCP version pin is a GA-gate decision, not staleness.** `@salesforce/mcp` stays at 0.30.5 until a newer GA release passes the ADR-009 6-check (standing monitor BC-5787). Don't bump on sight.
- **Keep upstream skill names** (ADR-007 §3.6). Renaming to `brite-*` breaks `git subtree pull`. Customize the SKILL.md `description` + body, not the directory name.
- **Bump the version in the SAME commit as any `skills/`, `commands/`, or `hooks/` edit** — bump BOTH `plugins/revops/.claude-plugin/plugin.json` AND the matching `.claude-plugin/marketplace.json` entry, or clients serve stale cache (root CLAUDE.md; BC-6000).
- **`allowed-tools` is not cross-validated against `.mcp.json`.** A skill listing an unregistered `mcp__plugin_revops_<server>__*` fails silently at runtime. Cross-check before merge.
