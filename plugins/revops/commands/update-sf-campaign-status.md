---
description: Sync a Salesforce Campaign's Status (and Substatus__c overlay) to a Linear label transition. Soft-fail when the SF Campaign doesn't exist (auto-create earlier failed) — returns a structured `warning` and continues. Idempotent (no-ops when current state already matches target). Called by σ3 trigger automation (BC-8752) on Linear status transitions, and by `/marketing:sync-campaign-status` for manual paused/killed triggers. Triggers on "update sf campaign status", "sync sf campaign status", "σ3 status sync", or direct `/revops:update-sf-campaign-status` invocation.
allowed-tools: Bash, mcp__plugin_revops_salesforce__run_soql_query
---

# /revops:update-sf-campaign-status

Implements σ3 SF Campaign status sync per [ADR-015](../../docs/decisions/015-gtm-sigma3-sf-campaign-sync.md). Replaces the originally-planned `mcp__plugin_revops_salesforce__update_sf_campaign_status` write tool (BC-8723 respec'd 2026-05-19) — the upstream `@salesforce/mcp` package is not Brite-owned, so the write surface lives here as a slash command instead. Sibling command: `/revops:create-sf-campaign` (BC-8717).

**Soft-fail contract** (load-bearing, per BC-8724 + BC-8752 designs): every error path exits 0 with a structured `{"error":"<kind>", ...}` or `{"warning":"<kind>", ...}` JSON object. Orchestrators detect failure by parsing the `error` / `warning` key, NOT by exit code. NEVER throw, NEVER exit non-zero, NEVER halt with prose.

**Single-line JSON on stdout.** No narration, no banners, no markdown. The caller pipes the output to `jq`. If you need to log diagnostic context, write it to stderr — stdout is reserved for the one JSON line.

## Input flags

Parse from the invocation (e.g. `/revops:update-sf-campaign-status --slug=... --linear-status=... ...`):

| Flag | Required | Notes |
|---|---|---|
| `--slug` | yes | Mirrors `Campaign.Name`. The slug uniquely identifies the SF Campaign created by `/revops:create-sf-campaign`. |
| `--linear-status` | yes | One of `planning` / `active` / `completed` / `killed`. Mirrors the Linear label set per O1. |
| `--linear-substatus` | no | Empty or `paused`. Only meaningful when `--linear-status=active`. Other combinations ignore this flag (mapping table treats it as `(any)`). |
| `--target-org` | no | Defaults to `brite-prod`. When supplied, validated against regex `^[a-zA-Z0-9._@-]+$` (SF org alias / username character set). Used as a shell argument to `sf` CLI — Phase 1's regex blocks shell-injection metacharacters. |
| `--dry-run` | no | Boolean. If present, print mapping + UPDATE preview JSON and exit without writing. |

If any required flag is missing, emit `{"error":"missing_required_flag","flag":"<name>"}` exit 0 and stop. Do NOT prompt the user — orchestrators expect non-interactive behavior.

## Mapping table (locked per O6.Q1)

| `linear-status` | `linear-substatus` | SF `Status` | SF `Substatus__c` |
|---|---|---|---|
| `planning` | (any) | `Planned` | (null) |
| `active` | (null/empty) | `In Progress` | (null) |
| `active` | `paused` | `In Progress` | `Paused` |
| `completed` | (any) | `Completed` | (null) |
| `killed` | (any) | `Aborted` | (null) |

## Phase 0 — Resolve target-org metadata (recommended optimization)

Run via the `Bash` tool ONCE per invocation (skip on `--dry-run`):

```bash
sf org display --target-org "<target-org>" --json
```

Cache from the response:

- `<sf-username>` = `.result.username` — required for Phase 2's MCP `run_soql_query` call (per `gotcha_sf_mcp_username_not_alias.md`, the upstream MCP rejects aliases).
- `<instance-url>` = `.result.instanceUrl` — reused by Phase 5 (noop) and Phase 7 (success URL construction); avoids a second `sf org display` round-trip.

If the call fails, do NOT emit a separate error — fall through to Phase 2 and let any downstream failure surface as the existing `sf_cli_error` / `instance_url_unknown` paths. This is a soft optimization, not a precondition.

## Phase 1 — Validate input

Check (in order; fail-fast on first mismatch):

- `--slug` matches regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`. Otherwise emit `{"error":"invalid_slug_format","slug":"<value>"}` exit 0. This is also a SOQL-injection guard — the slug flows into a SOQL string literal in Phase 2, and the regex character class disallows quotes / backslashes / whitespace.
- `--target-org` (if explicitly supplied) matches regex `^[a-zA-Z0-9._@-]+$` (SF org alias / username character set). Otherwise emit `{"error":"invalid_target_org","value":"<value>"}` exit 0. This is a shell-injection guard — the value is interpolated into `sf` CLI shell-outs in Phase 0/6/7.
- `--linear-status` ∈ `{planning, active, completed, killed}`. Otherwise emit `{"error":"invalid_status","flag":"--linear-status","value":"<value>"}` exit 0.
- `--linear-substatus` ∈ `{empty, paused}` (or omitted). Otherwise emit `{"error":"invalid_status","flag":"--linear-substatus","value":"<value>"}` exit 0.

The `flag` field on `invalid_status` disambiguates which of the two status flags failed validation — callers parse it to surface a precise diagnostic.

## Phase 2 — Campaign lookup + current-state read

Call `mcp__plugin_revops_salesforce__run_soql_query` with:

- `usernameOrAlias`: the `<sf-username>` cached from Phase 0 (literal username). See § Gotchas — `gotcha_sf_mcp_username_not_alias.md`; do NOT pass `DEFAULT_TARGET_ORG`, do NOT pass the raw `--target-org` alias.
- `query`: `SELECT Id, Status, Substatus__c, LastModifiedDate FROM Campaign WHERE Name = '<slug>' LIMIT 1`

`LastModifiedDate` is fetched in the same call so Phase 4's noop path can echo it as `updated_at` without an extra SOQL round-trip. Safe because Phase 1's slug regex rejects quote / backslash / whitespace characters — the only interpolation site is the `'<slug>'` literal.

If the result is empty (0 rows), emit and exit (soft-fail — auto-create earlier may have failed; operator must reconcile):

```json
{"warning":"campaign_not_found","slug":"<slug>"}
```

This is a `warning` (not `error`) because the underlying state (campaign missing) is not caller-correctable from the update path — the caller continues, logs a reconciliation reminder, and operators manually run `/revops:create-sf-campaign` later.

Capture the returned `Id`, `Status`, `Substatus__c`, `LastModifiedDate` as `<campaign-id>`, `<current-status>`, `<current-substatus>`, `<current-modified-at>` for subsequent phases.

## Phase 3 — Compute mapped target state

From the mapping table, derive `<mapped-status>` and `<mapped-substatus>`:

- `planning` → `Planned`, null
- `active` + (null/empty) → `In Progress`, null
- `active` + `paused` → `In Progress`, `Paused`
- `completed` → `Completed`, null
- `killed` → `Aborted`, null

## Phase 4 — Dry-run preview (conditional)

If `--dry-run` is present, emit the preview JSON and exit (NO UPDATE attempted) **regardless of current SF state**. Dry-run unconditionally wins over the Phase 5 noop short-circuit — orchestrators that pass `--dry-run` expect the `dry_run:true` shape, never the `noop:true` shape:

```json
{"dry_run":true,"mapping":{"linear_status":"<linear-status>","linear_substatus":"<linear-substatus-or-empty>","sf_status":"<mapped-status>","sf_substatus":"<mapped-substatus-or-empty>"},"command":"sf data update record --sobject Campaign --record-id <campaign-id> --values \"Status='<mapped-status>' Substatus__c='<mapped-substatus-or-empty>'\" --target-org \"<target-org>\" --json","payload":{"Status":"<mapped-status>","Substatus__c":"<mapped-substatus-or-empty>"},"target_org":"<target-org>"}
```

The embedded `command` string quotes `--target-org "<target-org>"` defensively (defense-in-depth against operator copy-paste even though Phase 1's regex guard already rejects shell metacharacters in `--target-org`). All interpolated values in the `command` string — `<slug>` (gated by `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`), `<mapped-status>` / `<mapped-substatus>` (closed-set lookup from the mapping table), `<campaign-id>` (SF record ID, matches `[a-zA-Z0-9]{15,18}`), `<target-org>` (gated by `^[a-zA-Z0-9._@-]+$`) — are regex-gated or closed-set upstream. The `command` field is documentation, not executable, but an operator copy-pasting it gets a safe template.

The preview proves the mapping + UPDATE assembly without mutating SF.

## Phase 5 — Idempotency no-op pre-check

If `<current-status> == <mapped-status>` AND `<current-substatus> == <mapped-substatus>` (treating SOQL-null and empty-string as equivalent — SF returns `null` for an unset Substatus__c, both flag-omitted and `--linear-substatus=` should compare equal to that), the campaign is already in the target state — return success immediately without issuing UPDATE:

```json
{"campaign_id":"<id>","campaign_url":"<url>","campaign_name":"<slug>","status":"<mapped-status>","substatus":"<mapped-substatus-or-empty>","updated_at":"<current-modified-at>","noop":true}
```

This mirrors BC-8717's `duplicate_slug` early-exit. Saves API calls + prevents `LastModifiedDate` churn on σ3 webhook re-fires.

The `<current-modified-at>` is the `LastModifiedDate` from Phase 2's SOQL — no extra round-trip needed. For `<url>`, reuse the `<instance-url>` cached from Phase 0 if available; otherwise fall through to Phase 7's `sf org display` path with the `instance_url_unknown` fallback. The noop path does NOT issue a fresh `sf org display` call when Phase 0's metadata is cached.

## Phase 6 — UPDATE via SF CLI

Run via the `Bash` tool:

```bash
sf data update record \
  --sobject Campaign \
  --record-id <campaign-id> \
  --values "Status='<mapped-status>' Substatus__c='<mapped-substatus-or-empty>'" \
  --target-org "<target-org>" \
  --json
```

`--target-org` is double-quoted defensively even though Phase 1's regex guard already rejects shell metacharacters — defense-in-depth against future relaxation of the regex.

When `<mapped-substatus>` is null, pass `Substatus__c=''` (empty string) — SF CLI v2.x interprets empty as clear-the-field. The shell-out must always include the `Substatus__c` segment so a `(active, paused) → (active, null)` transition correctly clears the overlay. **Verify in dry-run + throwaway-slug evidence**: if `Substatus__c=''` does NOT clear (post-UPDATE re-read still shows the old overlay), fall back to issuing the UPDATE via the SObject Composite REST API (`PATCH /services/data/vXX.X/sobjects/Campaign/<id>` with `{"Substatus__c": null}` body) — the SOQL re-read is the source of truth for this transition.

Parse the UPDATE `--json` response FIRST — before any re-read — so failed UPDATEs short-circuit cleanly without wasting an extra SOQL round-trip:

- Any shape other than `status === 0` with `result.id` present → emit and exit:

  ```json
  {"error":"sf_cli_error","detail":<raw upstream JSON>}
  ```

  Do NOT exit non-zero. The soft-fail contract requires exit 0 even on CLI failure.

- `status === 0` and `result.id` present → the UPDATE landed; run a follow-up SOQL via `mcp__plugin_revops_salesforce__run_soql_query` to capture the new `LastModifiedDate` (the `sf data update record --json` response does not include it):

  - `query`: `SELECT LastModifiedDate FROM Campaign WHERE Id = '<campaign-id>' LIMIT 1`

  Capture the returned timestamp as `<new-modified-at>` for Phase 8's `updated_at` field. If the re-read fails (transient SF error), fall back to `<new-modified-at> = ""` and add `"warning":"updated_at_unavailable"` to the Phase 8 payload.

## Phase 7 — Construct Campaign URL

If Phase 0's `<instance-url>` is cached, REUSE it — do NOT issue a second `sf org display` call. Otherwise (Phase 0 was skipped or failed), run via the `Bash` tool:

```bash
sf org display --target-org "<target-org>" --json
```

Parse `.result.instanceUrl` from the response (e.g. `https://britenites.lightning.force.com`). Construct:

```
<instanceUrl>/lightning/r/Campaign/<campaign-id>/view
```

If `sf org display` itself fails (auth expired, network) AND Phase 0's cache is empty, fall back to a deterministic instanceless URL and emit success with a degradation warning — the campaign WAS updated, the URL is convenience metadata:

```json
{"campaign_id":"<id>","campaign_url":"https://lightning.force.com/lightning/r/Campaign/<id>/view","campaign_name":"<slug>","status":"<mapped-status>","substatus":"<mapped-substatus-or-empty>","updated_at":"<new-modified-at>","warning":"instance_url_unknown"}
```

## Phase 8 — Success output

Emit a single-line JSON object on stdout (union of BC-8717's surface + BC-8723's confirmation fields):

```json
{"campaign_id":"<id>","campaign_url":"<url>","campaign_name":"<slug>","status":"<mapped-status>","substatus":"<mapped-substatus-or-empty>","updated_at":"<new-modified-at>"}
```

Orchestrators capture `status` + `substatus` for the portfolio rollup confirmation, `updated_at` for the σ3 event timeline, and the BC-8717-shape fields (`campaign_id` / `campaign_url` / `campaign_name`) for parser consistency with `/revops:create-sf-campaign`.

## Error / warning path catalog (all exit 0)

| key | When | Recovery |
|---|---|---|
| `error: missing_required_flag` | A required flag was omitted | Caller re-invokes with full flag set |
| `error: invalid_slug_format` | Phase 1 slug regex rejected the input | Caller normalizes slug (per ADR-012 + canonicals lint) — same regex as `/revops:create-sf-campaign` |
| `error: invalid_target_org` | Phase 1 `--target-org` regex rejected the input | Caller normalizes alias / username to the SF org alias character set; defense against shell injection into Phase 0/6/7 |
| `error: invalid_status` (with `flag` discriminator) | `--linear-status` ∉ {planning, active, completed, killed}, OR `--linear-substatus` ∉ {empty, paused}. Payload includes a `flag` field naming the offending flag | Caller normalizes to canonical value |
| `warning: campaign_not_found` | Phase 2 SOQL returned 0 rows | Caller treats as soft-fail; logs reconciliation reminder (operator manually runs `/revops:create-sf-campaign`); continues |
| `error: sf_cli_error` | Phase 6 returned non-zero status | Caller inspects `detail`; common causes: missing `Substatus__c` field deploy (BC-8713), permset gap, FLS on custom field, record-locked |
| `warning: instance_url_unknown` | Phase 7 `sf org display` failed AND Phase 0's cache was empty | Caller uses the instanceless URL fallback; UPDATE itself succeeded |
| `warning: updated_at_unavailable` | Post-UPDATE LastModifiedDate re-read failed | Caller treats UPDATE as successful; `updated_at` is empty string in payload |

## Gotchas

- **`usernameOrAlias` must be a literal username.** Per [`memory/gotcha_sf_mcp_username_not_alias.md`](../../../../memory/gotcha_sf_mcp_username_not_alias.md), the upstream `@salesforce/mcp` rejects `DEFAULT_TARGET_ORG` sentinels and alias values for `run_soql_query`. Resolve `--target-org` to a literal username before invoking the MCP tool (e.g., via `sf org display --target-org brite-prod --json | jq -r .result.username`).
- **Soft-fail is non-negotiable.** A non-zero exit will halt σ3 trigger automation (BC-8752) mid-orchestration. Every branch in this command emits exit 0.
- **One JSON object, one line.** No pretty-printing, no trailing newlines, no banners. The caller's `jq` pipeline does not expect garbage.
- **No `AskUserQuestion`.** This is an orchestrator-callable command. Missing flags are errors, not prompts.
- **`Substatus__c=''` clears the field.** SF CLI v2.x treats empty-string in `--values` as clear. The `(active, paused) → (active, null)` transition correctness depends on this — do NOT omit the `Substatus__c` segment when the mapped value is null.
- **Sibling soft-fail shape divergence is intentional.** BC-8717's `error: duplicate_slug` is caller-correctable (caller picks a fresh slug). BC-8723's `warning: campaign_not_found` is NOT caller-correctable from this code path (the campaign needs to be created upstream). Different keys signal that semantic distinction to orchestrators.
- **The σ3 webhook can fire repeatedly with the same target state.** Phase 5's idempotency no-op pre-check is what keeps `LastModifiedDate` stable and SF API rate-limit cheap.
- **Dry-run wins over noop.** Phase 4 (dry-run preview) is checked BEFORE Phase 5 (noop pre-check). A caller passing `--dry-run` always gets the `dry_run:true` shape — even when the campaign's current state already matches the mapped target. Re-ordering these would silently change the orchestrator-facing contract.
- **Phase 0 caches metadata; Phase 7 reuses it.** A single `sf org display` per invocation resolves both the literal username (for Phase 2's MCP `run_soql_query`) and the `instanceUrl` (for Phase 5 noop / Phase 7 success URL). Re-running `sf org display` in Phase 7 when Phase 0's cache is populated is a needless ~200ms round-trip per σ3 fire.
