---
description: Create a Salesforce Campaign record from canonical GTM slug + persona/offer/vertical/entity inputs. Idempotent (refuses duplicate slugs), soft-fail (all errors exit 0 with structured JSON), and orchestrator-friendly (single-line JSON on stdout). Called by `/marketing:plan-campaign` Step 8b (BC-8724) at scaffold time; can also be invoked manually for SF reconciliation when an earlier auto-create failed. Triggers on "create sf campaign", "scaffold sf campaign", "sigma3 auto-create", or direct `/revops:create-sf-campaign` invocation.
allowed-tools: Bash, mcp__plugin_revops_salesforce__run_soql_query
---

# /revops:create-sf-campaign

Implements σ3 SF Campaign auto-create per [ADR-015](../../docs/decisions/015-gtm-sigma3-sf-campaign-sync.md). Replaces the originally-planned `mcp__plugin_revops_salesforce__create_sf_campaign` write tool (BC-8717 respec'd 2026-05-19) — the upstream `@salesforce/mcp` package is not Brite-owned, so the write surface lives here as a slash command instead.

**Soft-fail contract** (load-bearing, per BC-8724 design): every error path exits 0 with a structured `{"error":"<kind>", ...}` JSON object. Orchestrators detect failure by parsing the `error` key, NOT by exit code. NEVER throw, NEVER exit non-zero, NEVER halt with prose.

**Single-line JSON on stdout.** No narration, no banners, no markdown. The caller pipes the output to `jq`. If you need to log diagnostic context, write it to stderr — stdout is reserved for the one JSON line.

## Input flags

Parse from the invocation (e.g. `/revops:create-sf-campaign --slug=... --entity=... ...`):

| Flag | Required | Notes |
|---|---|---|
| `--slug` | yes | Regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`. Becomes `Campaign.Name`. |
| `--entity` | yes | One of `nites` / `supply` / `labs` / `cross-entity`. Mirrors `Campaign.Entity__c` picklist from BC-8713. |
| `--vertical` | yes | Canonical vertical slug from `plugins/marketing/data/canonicals/`. |
| `--persona` | yes | Canonical persona slug. |
| `--offer` | yes | Canonical offer slug. |
| `--year` | yes | 4-digit, e.g. `2026`. |
| `--month` | yes | Integer 1-12. |
| `--owner-email` | yes | SF user email (literal username, NOT alias — per `gotcha_sf_mcp_username_not_alias.md`). |
| `--launch-date` | yes | ISO `YYYY-MM-DD`. Maps to `Campaign.StartDate`. |
| `--target-org` | no | Defaults to `brite-prod` (SF prod-org canonical alias). NOTE: This default does NOT auto-read `~/.sf/config.json`'s `target-org`. If the caller wants the SF MCP's session default, they MUST resolve it via `mcp__plugin_revops_salesforce__get_username(defaultTargetOrg=true).value` and pass that as `--target-org` explicitly. BC-8727 friction-log F11. |
| `--dry-run` | no | Boolean. If present, print preview JSON and exit without inserting. |

If any required flag is missing, emit `{"error":"missing_required_flag","flag":"<name>"}` exit 0 and stop. Do NOT prompt the user — orchestrators expect non-interactive behavior.

## Phase 1 — Validate slug format

Check that `--slug` matches the regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`.

If it does NOT match, emit and exit:

```json
{"error":"invalid_slug_format","slug":"<value>"}
```

## Phase 2 — Idempotency precheck

Call `mcp__plugin_revops_salesforce__run_soql_query` with:

- `usernameOrAlias`: the literal username for `--target-org` (see § Gotchas — `gotcha_sf_mcp_username_not_alias.md`; do NOT pass `DEFAULT_TARGET_ORG`).
- `query`: `SELECT Id FROM Campaign WHERE Name = '<slug>' LIMIT 1`

If the SOQL call ITSELF fails (auth refresh, network, permset, FLS), emit and exit (BC-8727 friction-log F13):

```json
{"error":"sf_cli_error","phase":"idempotency_precheck","detail":"<message from MCP>"}
```

Otherwise, if the result contains any record, emit and exit:

```json
{"error":"duplicate_slug","existing_id":"<Id from response>"}
```

The idempotency check is the load-bearing safety property: `/marketing:plan-campaign` re-runs MUST be no-ops when the slug already exists.

## Phase 3 — Owner lookup

Call `mcp__plugin_revops_salesforce__run_soql_query` with:

- `usernameOrAlias`: as in Phase 2.
- `query`: `SELECT Id FROM User WHERE Email = '<owner-email>' AND IsActive = TRUE LIMIT 1`

If the SOQL call ITSELF fails (auth, network, permset), emit and exit (BC-8727 friction-log F13):

```json
{"error":"sf_cli_error","phase":"owner_lookup","detail":"<message from MCP>"}
```

Otherwise, if the result is empty, emit and exit:

```json
{"error":"missing_owner","email":"<owner-email>"}
```

Capture the returned `Id` as `<owner-id>` for Phase 5.

## Phase 4 — Dry-run preview (conditional)

If `--dry-run` is present, emit the preview JSON and exit (NO insert attempted):

```json
{"dry_run":true,"command":"sf data create record --sobject Campaign --values \"Name='<slug>' Vertical__c='<vertical>' Persona__c='<persona>' Offer__c='<offer>' Entity__c='<entity>' StartDate=<launch-date> OwnerId='<owner-id>' Status='Planned'\" --target-org <target-org> --json","payload":{"Name":"<slug>","Vertical__c":"<vertical>","Persona__c":"<persona>","Offer__c":"<offer>","Entity__c":"<entity>","StartDate":"<launch-date>","OwnerId":"<owner-id>","Status":"Planned"},"target_org":"<target-org>"}
```

The preview proves the lookup + payload assembly without mutating SF. Useful for both human dry-run inspection and orchestrator-side integration tests.

## Phase 5 — Insert via SF CLI

Run via the `Bash` tool:

```bash
sf data create record \
  --sobject Campaign \
  --values "Name='<slug>' Vertical__c='<vertical>' Persona__c='<persona>' Offer__c='<offer>' Entity__c='<entity>' StartDate=<launch-date> OwnerId='<owner-id>' Status='Planned'" \
  --target-org <target-org> \
  --json
```

Parse the `--json` response:

- `status === 0` and `result.id` present → capture `<campaign-id>`, proceed to Phase 6.
- Any other shape → emit and exit:

  ```json
  {"error":"sf_cli_error","detail":<raw upstream JSON>}
  ```

  Do NOT exit non-zero. The soft-fail contract requires exit 0 even on CLI failure.

## Phase 6 — Construct Campaign URL

Run via the `Bash` tool:

```bash
sf org display --target-org <target-org> --json
```

Parse `.result.instanceUrl` from the response (e.g. `https://britenites.lightning.force.com`). Construct:

```
<instanceUrl>/lightning/r/Campaign/<campaign-id>/view
```

If `sf org display` itself fails (auth expired, network), fall back to a deterministic instanceless URL placeholder and still emit success — the campaign WAS created, the URL is convenience metadata:

```json
{"campaign_id":"<id>","campaign_url":"https://lightning.force.com/lightning/r/Campaign/<id>/view","campaign_name":"<slug>","warning":"instance_url_unknown"}
```

## Phase 7 — Success output

Emit a single-line JSON object on stdout:

```json
{"campaign_id":"<id>","campaign_url":"<url>","campaign_name":"<slug>"}
```

This is the canonical success shape. Orchestrators capture `campaign_id` into `manifest.json.salesforce.campaign_id`.

## Error path catalog (all exit 0)

| `error` key | When | Recovery |
|---|---|---|
| `missing_required_flag` | A required flag was omitted | Caller re-invokes with full flag set |
| `invalid_slug_format` | `--slug` fails regex | Caller normalizes slug (per ADR-012 + canonicals lint) |
| `duplicate_slug` | Phase 2 SOQL found existing Campaign | Caller treats as idempotent success; the existing `Id` is in `existing_id` |
| `missing_owner` | Phase 3 returned 0 rows | Caller verifies `--owner-email` is an active SF user, OR provisions the user |
| `sf_cli_error` | Phase 2 SOQL failure (auth/network/permset) OR Phase 3 SOQL failure OR Phase 5 returned non-zero status | Caller inspects `detail` field; common causes: SF JWT refresh failure (re-auth `sf`), missing `Substatus__c` field deploy, permset gap, FLS on custom field. Optional `phase` field (`idempotency_precheck` / `owner_lookup` / `insert`) signals which phase failed; absent for Phase 5 backward-compat. |

## Gotchas

- **`usernameOrAlias` must be a literal username.** Per [`memory/gotcha_sf_mcp_username_not_alias.md`](../../../../memory/gotcha_sf_mcp_username_not_alias.md), the upstream `@salesforce/mcp` rejects `DEFAULT_TARGET_ORG` sentinels and alias values for `run_soql_query`. Resolve `--target-org` to a literal username before invoking the MCP tool (e.g., via `sf org display --target-org brite-prod --json | jq -r .result.username`).
- **Soft-fail is non-negotiable.** A non-zero exit will halt `/marketing:plan-campaign` (BC-8724) mid-scaffold. Every branch in this command emits exit 0.
- **One JSON object, one line.** No pretty-printing, no trailing newlines, no banners. The caller's `jq` pipeline does not expect garbage.
- **No `AskUserQuestion`.** This is an orchestrator-callable command. Missing flags are errors, not prompts.
- **`Substatus__c` is set later, not here.** σ3 status sync (BC-8723 / `/revops:update-sf-campaign-status`) handles the `paused` overlay. This command always inserts `Status='Planned'` with no Substatus.
