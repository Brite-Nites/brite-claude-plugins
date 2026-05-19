# BC-8717 — `/revops:create-sf-campaign` slash command

**Issue:** [BC-8717](https://linear.app/brite-nites/issue/BC-8717) (respec'd 2026-05-19 — Path 3 chosen; was MCP write tool)
**Branch:** `holden/bc-8717-create-sf-campaign`
**Worktree:** `.claude/worktrees/bc-8717/`
**Complexity:** M
**Repo:** `britenites-claude-plugins` (plugin work only — no `brite-salesforce` edits)

## Why this is a slash command, not an MCP tool

The original ticket asked for a `create_sf_campaign` tool added to the `mcp__plugin_revops_salesforce__*` namespace. That namespace is served by upstream **`@salesforce/mcp@0.30.5`** (Salesforce-published npm package), not a Brite-owned server — there is no Brite source code to extend. Two architectural paths were considered after that discovery:

| Path | What | Why rejected / chosen |
|---|---|---|
| Path 1 — stand up a new Brite-owned `revops:campaign` MCP server | TS/Python MCP wrapping `sf` CLI | L-sized + rename cascade for two write tools (BC-8717, BC-8723); below the ~5-tool threshold where a fresh MCP earns its boilerplate. **Rejected.** |
| **Path 3 — slash command at `plugins/revops/commands/create-sf-campaign.md`** | Markdown skill calling upstream `run_soql_query` MCP + `sf data create record` Bash | Additive to existing `/revops:sf-*` skill family. No `mcp__plugin_revops_salesforce__*` rename cascade. Composes naturally with `/marketing:plan-campaign` (BC-8724) via the Skill tool. **Chosen.** |

Full rationale lives in the [respec'd Linear body](https://linear.app/brite-nites/issue/BC-8717) ("Respec 2026-05-19 — was MCP write tool, now slash command").

## Deliverables

| Path | Purpose |
|---|---|
| `plugins/revops/commands/create-sf-campaign.md` | The slash command itself. Frontmatter declares `allowed-tools: Bash, mcp__plugin_revops_salesforce__run_soql_query`. |
| `plugins/revops/tests/test_create_sf_campaign_contracts.py` | Contract tests for the markdown — frontmatter shape, soft-fail error keys present, every required input flag documented, idempotency precheck SOQL present. Pattern mirrors `test_skill_registry_contracts.py`. |
| `plugins/revops/.claude-plugin/plugin.json` | Version 0.2.6 → 0.2.7 (patch — additive command). |
| `.claude-plugin/marketplace.json` | Mirror revops version bump (per CLAUDE.md plugin-cache gotcha). |
| `docs/project-plan-refined.md` § Task T2-E | Replace MCP-tool framing with slash-command framing. |
| `docs/gtm-campaign-orchestration-README.md` | §3.6 worked example Step 8b, §3.7 cheatsheet, §5 V3 callouts, §7 Tier table, §7.5 decision table — all `create_sf_campaign MCP` → `/revops:create-sf-campaign` slash command. |
| `docs/decisions/015-gtm-sigma3-sf-campaign-sync.md` | Tool framing → slash-command framing; consequence rewrite acknowledges no MCP server change. |

**Not in this PR** (documented in PR body, not silently skipped):

- `plugins/revops/README.md` — upstream Jaganpro content (per `UPSTREAM.md`); no Brite-specific commands listing to extend.
- BC-8723 / `/revops:update-sf-campaign-status` — separate ship.
- BC-8724 / `/marketing:plan-campaign` — consumer, not in this PR. Its caller contract update is implicit in the T4-I plan-doc section (line 425 + 449) which references `create_sf_campaign`; touching it here would bloat the diff. Filed as part of BC-8724's plan-doc author session.

## Behavior summary

Implements the 5 phases from the Linear issue's "Behavior" section:

1. **Slug regex** — `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`; mismatch → `{"error":"invalid_slug_format","slug":"<v>"}` exit 0.
2. **Idempotency precheck** — `SELECT Id FROM Campaign WHERE Name = '<slug>' LIMIT 1` via upstream `run_soql_query` MCP; hit → `{"error":"duplicate_slug","existing_id":"<id>"}` exit 0.
3. **Owner lookup** — `SELECT Id FROM User WHERE Email = '<owner-email>' AND IsActive = TRUE LIMIT 1`; empty → `{"error":"missing_owner","email":"<email>"}` exit 0.
4. **Dry-run preview** — print `sf data create record` invocation + payload + computed URL; exit 0.
5. **Insert** — `sf data create record --sobject Campaign --values "..." --target-org <org> --json`; bubble errors as `{"error":"sf_cli_error","detail":<upstream-json>}` exit 0.
6. **URL construction** — `sf org display --target-org <org> --json` → `.result.instanceUrl` → `<instanceUrl>/lightning/r/Campaign/<id>/view`.
7. **Success** — `{"campaign_id":"<id>","campaign_url":"<url>","campaign_name":"<slug>"}` single-line JSON.

**Soft-fail contract** (non-negotiable per BC-8724 design): every error path exits 0 with structured `{"error":...}` JSON. Orchestrators parse for the `error` key, not the exit code.

## Test plan

`pytest plugins/revops/tests/test_create_sf_campaign_contracts.py -v` covers:

- Command file exists at expected path.
- Frontmatter declares `description` + `allowed-tools` containing both `Bash` and `mcp__plugin_revops_salesforce__run_soql_query`.
- All 10 input flags documented (`--slug` through `--dry-run`).
- All 5 error keys present in body (`invalid_slug_format`, `duplicate_slug`, `missing_owner`, `sf_cli_error`, `missing_required_flag`).
- Idempotency precheck SOQL string appears verbatim.
- Owner-lookup SOQL string appears verbatim with `IsActive = TRUE`.
- Body explicitly states "exit 0" for error paths (soft-fail contract).
- Plugin version bumped to 0.2.7 in both `plugin.json` and `marketplace.json`.

Runtime tests (slash-command Bash + MCP invocation) are deliberately out of scope — slash commands are Claude-orchestrated markdown, not executable code. Runtime validation happens in the PR's manual evidence (`--dry-run` invocation + throwaway-slug insert against `brite-prod`).

## Validation evidence (paste into tracker)

The shipper session (this one) will paste back to the tracker:

1. `pytest` output (all green).
2. `./scripts/validate.sh` output (no new FAIL for revops).
3. `/revops:create-sf-campaign --dry-run` invocation JSON (no SF mutation).
4. Real-mode invocation against throwaway slug `test-bc8717-shipdebug-fy26-m05` → success JSON.
5. Idempotency re-run → `{"error":"duplicate_slug","existing_id":"..."}`.
6. `sf data delete record --sobject Campaign --record-id <id> --target-org brite-prod` to clean up.
7. PR URL + `gh pr checks` summary.
8. Linear close-out comment posted.

## Out of scope (explicit)

- **No upstream `@salesforce/mcp` edits.** Step 0 of the pre-respec ticket asked for this; the respec eliminates the premise.
- **No new MCP server.** Path 1 above, rejected for size.
- **No sandbox testing.** `brite-sandbox` has 5-PR drift on Lead metadata per BC-10261 — unrelated to Campaign but adds noise. Real-mode validation uses `brite-prod` with a deliberately throwaway slug, deleted immediately after.
- **No BC-8723 in this PR.** Sibling architectural pattern (`/revops:update-sf-campaign-status`), separate ship.
- **No Python package install.** Pure markdown + JSON edits + a contract pytest file.
