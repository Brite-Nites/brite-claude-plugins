# Email Bison Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

Email Bison is Brite's cold email sequencing platform — the **sending layer** of the outbound pipeline. It rotates through thousands of managed inboxes, runs multi-step sequences, and emits events (sent, opened, replied, bounced, unsubscribed) that OutboundSync relays into Salesforce. Brite uses Email Bison exclusively; Smartlead and Instantly are market alternatives only, never Brite-active ([research WIP §2 corrected table](../../../../docs/research/outbound-pipeline-findings.md#2-handbook-drift)).

The official Email Bison MCP Server (Beta) exposes the full sending-layer API surface to Claude — validated in [research WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked).

## Consumed by

- `email-bison` (`plugins/marketing/skills/email-bison/`) — default entry point; owns the long tail (workspace, senders, tags, blocklist, webhooks, schedule templates, variables, quick stats) and routes to the specialized siblings below when intent matches.
- `email-copywriting` (`plugins/marketing/skills/email-copywriting/`) — generates EB-format subject + body step 1 + step 2 as a JSON artifact for `/marketing:launch-campaign` to consume. Does NOT call EB MCP tools — pure content generation.
- `campaign-orchestration` (`plugins/marketing/skills/campaign-orchestration/`) — sequence design, inbox rotation, warmup strategy, end-to-end campaign launch.
- `/marketing:launch-campaign` (`plugins/marketing/commands/launch-campaign.md`, BC-5826) — procedural 11-phase command that turns an enriched CSV + email-copywriting JSON artifact into an activated EB campaign. Owns every mutating phase (variables, upload, campaign create, lead+sender attach, schedule, sequence, activate) with two-call confirmation gates at each step. Default-off `--activate` flag; campaigns stop in Draft state unless explicit.
- `tam-mapping` (`plugins/marketing/skills/tam-mapping/`, BC-5832) — Phase 4.5 cross-workspace exclusion query. Read-only `list_leads` against BOTH `emailbison-b2b` AND `emailbison-personal` to filter already-contacted domains out of a freshly-built TAM before Phase 5 enrichment. HARD-FAILS if either workspace is unreachable.
- `list-building` (`plugins/marketing/skills/list-building/`, BC-2717) — Workflow 2 cross-workspace exclusion query for Sources 2 + 3 (dbt audience CSV, manual CSV). Read-only `list_leads` against BOTH `emailbison-b2b` AND `emailbison-personal` mirroring tam-mapping § 3 Phase 4.5 (kept in sync via cross-reference note in both files). Source 1 (tam-mapping output) SKIPS this — tam-mapping Phase 4.5 already ran the EB exclusion. HARD-FAILS if either workspace is unreachable when run.
- `reply-processing` (BC-2720 — not yet landed) — reply classification + OutboundSync CRM sync.
- `deliverability-audit` (BC-2719 — not yet landed) — SPF/DKIM/DMARC, domain reputation, bounce analysis.

## Auth

**Credential type.** Email Bison API token per workspace. Passed as `Authorization: Bearer <token>` plus a mandatory `Instance-URL` header that routes the request to the correct vendor instance. The vendor's canonical term is "API token" (see [authentication docs](https://docs.emailbison.com/get-started/authentication)) — not "API key", despite occasional interchangeable use in community posts.

**Where it comes from.** Workspace UI → Settings → Integrations → EmailBison MCP. The workspace admin generates a token scoped to that workspace. The MCP endpoint itself is vendor-hosted and public; the token is what identifies the workspace ([research WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked)).

**Scopes.** Workspace-level full access. There is no documented sub-scoping — a token either has access to the workspace or it doesn't.

**Multi-workspace routing.** Brite runs two Email Bison instances, and the skill must pick the right one based on recipient type:

| Server name | Instance | Workspace | Used when | Workspace ID |
|---|---|---|---|---|
| `emailbison-b2b` | `send.outbase.so` | Brite Nites | Sending to business recipients | 55 |
| `emailbison-personal` | `personal.outbase.so` | BriteNites Team | Sending to consumer / personal recipients | 13 |

Re-verified live via `get_active_workspace_info` on 2026-04-19 during BC-5551 post-merge onboarding smoke test. Prior BC-5040 record (2026-04-10) showed 52 / 11 — the numbers changed between then and now; current values are authoritative.

**Credential storage.** Raw tokens live in the Engineering Bitwarden collection, item **"Email Bison MCP — API tokens"**. Each dev pastes `export` lines from the Bitwarden item's Notes field into their shell profile, then the two HTTP MCP entries in the user-level `.mcp.json` reference `${EMAILBISON_B2B_TOKEN}` and `${EMAILBISON_PERSONAL_TOKEN}` via `${…}` substitution at load time. Raw tokens are never committed.

Plugin-scoped registration (`plugins/marketing/.mcp.json`) is **not viable today** — see § [Known Claude Code limitation](#known-claude-code-limitation). BC-5551 shipped the credential distribution (Bitwarden + shell profile) but left the MCP entries at user-level until the upstream bug is fixed.

### One-time per-dev onboarding

**Easy path — guided walkthrough:** run `/marketing:setup-email-bison` in Claude Code. The command detects current registration state, walks you through each step (Bitwarden retrieval, shell profile, `.mcp.json` edit, reload, verify), and asks for explicit confirmation at each checkpoint. See `plugins/marketing/commands/setup-email-bison.md` for the full script. Roughly 3 minutes end-to-end.

**Manual path (fallback if the command isn't available or you prefer step-by-step control):**

1. Retrieve the **"Email Bison MCP — API tokens"** item from the Engineering Bitwarden collection. The Notes field carries the exact `export EMAILBISON_B2B_TOKEN=…` / `export EMAILBISON_PERSONAL_TOKEN=…` lines, ready to paste.
2. Paste both `export` lines into your shell profile (`~/.zshrc` or `~/.bashrc`). Start a new shell so the vars are exported.
3. Register the two servers in your user-level MCP config. Simplest way is to add them to the gitignored repo-root `.mcp.json` using the shape in § Registration below. Alternative: `claude mcp add` from the CLI (project scope).
4. `/reload-plugins` in Claude Code (or restart if `/reload-plugins` doesn't pick the entries up).
5. Smoke-test: a skill allowed `mcp__emailbison-b2b__*` calls `get_active_workspace_info` — expect workspace ID `55`, domain `send.outbase.so`. Same for `-personal` → workspace ID `13`, `personal.outbase.so`.

**Fallback.** If the Bitwarden item is unreachable, re-issue tokens in the vendor UI (Workspace → Settings → Integrations → EmailBison MCP) and update the Bitwarden item after rotation.

## Registration

Today the servers live at user level (repo-root gitignored `.mcp.json` or equivalent user-scope config). The shape:

```json
{
  "mcpServers": {
    "emailbison-b2b": {
      "type": "http",
      "url": "https://mcp.emailbison.com/mcp",
      "headers": {
        "Authorization": "Bearer ${EMAILBISON_B2B_TOKEN}",
        "Instance-URL": "https://send.outbase.so"
      }
    },
    "emailbison-personal": {
      "type": "http",
      "url": "https://mcp.emailbison.com/mcp",
      "headers": {
        "Authorization": "Bearer ${EMAILBISON_PERSONAL_TOKEN}",
        "Instance-URL": "https://personal.outbase.so"
      }
    }
  }
}
```

**File location.** User-level (repo-root `.mcp.json`, gitignored via the `/` anchor — plugin-scoped `.mcp.json` files remain committable but don't house these entries). Env-var substitution happens at Claude Code's load-time resolution.

**Future state.** When the Claude Code bugs blocking plugin-scoped HTTP+env-var headers are fixed (see below), migrate these two entries to `plugins/marketing/.mcp.json` so teammates inherit them automatically without user-level setup. Track via Linear follow-up (TODO: link).

### Known Claude Code limitation

The plugin-scoped distribution originally scoped for BC-5551 could not ship because plugin-scoped `.mcp.json` does not correctly resolve `${ENV_VAR}` inside `headers` for HTTP-type servers in current Claude Code (v2.1.112). Multiple open bugs:

- [anthropics/claude-code#6204](https://github.com/anthropics/claude-code/issues/6204) — "MCP headers with environment variable substitution not being sent from .mcp.json" (closed but resurfaced)
- [anthropics/claude-code#9427](https://github.com/anthropics/claude-code/issues/9427) — explicitly notes plugin-scoped expansion fails where project-root works; still open
- [anthropics/claude-code#28293](https://github.com/anthropics/claude-code/issues/28293) — headers not forwarded on POST
- [anthropics/claude-code#14977](https://github.com/anthropics/claude-code/issues/14977) — custom headers not sent

Workarounds attempted in BC-5551 and rejected:

| Attempt | Why rejected |
|---|---|
| HTTP-type with `${VAR}` in `headers` | Bug class above — env var sent literally, vendor returns 401. |
| Stdio wrapper via `npx -y mcp-remote <URL> --header "..."` | `claude mcp list` still extracts the URL substring from args and classifies the server as HTTP-type, bypassing the stdio proxy. Handshake never completes. |
| `sh -c "npx -y mcp-remote ..."` to hide the URL | Same result — the URL is still inside the quoted arg string and Claude Code's substring match finds it. |
| HTTP-type with `${user_config.<key>}` in `headers` + `userConfig` block declaring the keys with `sensitive: true` | **Validated broken on 2026-04-19.** Direct curl with the stored keychain value against the vendor returns HTTP 200 and a valid MCP `initialize` response — so the token itself is good. Claude Code's plugin MCP client, configured with the same value via `${user_config.*}` substitution, shows `✗ Failed to connect` in `claude mcp list`. Evidence: token-via-curl = 200, same-token-via-Claude-Code = Failed. Same class of substitution bug as `${ENV_VAR}`, different mechanism. See upstream tracker (filed 2026-04-19, link forthcoming). |

**Secondary bug observed 2026-04-19:** when two HTTP MCP entries share the same `url` but differ only by header values (both emailbison-b2b and emailbison-personal point at `https://mcp.emailbison.com/mcp` with different `Instance-URL` headers), only one registers in `claude mcp list`. The second is silently deduped. Workaround: none known today; register one at a time under a URL-distinct wrapper if both are needed, or accept a single workspace until upstream ships a fix.

`mcp-remote@0.1.38` itself proxies Email Bison correctly when run from a shell, verified during BC-5551 investigation. The block is strictly in how Claude Code's plugin-scoped MCP loader handles the configuration, not in the vendor or proxy layers.

**If you retry this pattern:** be aware that `mcp-remote` prints the raw `Authorization` header on startup to stderr. If stderr gets captured (CI, some MCP client log buffers), the token leaks. File an upstream issue asking for a `--redact-headers` flag, or patch around it.

**Superseded alternatives** — do not adopt any of these:

- `laviefatigue/emailbison-mcp-server` — repository returns 404
- `Sirkunle001/email-bison-claude-mcp` — community repo with ~13 tools, last commit 2025-10; superseded by the official 141-tool server

Source: [research WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked).

## Tool inventory

The server exposes **141 tools across 16 categories** (23 core + 118 extended) per [research WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked). The 14 documented categories below cover 125 tools; the remaining 16 tools across 2 further categories are not enumerated in the research WIP — use `discover_tools` for the full live inventory.

### Campaigns (21 tools)

Full CRUD over cold-email campaigns including create, import leads, attach senders, pause/resume ([WIP §6 Q6](../../../../docs/research/outbound-pipeline-findings.md#6-open-design-questions)).

### Leads (15 tools)

Lead create, bulk create (up to 500 per call), upsert, blacklist. See rate limits below for the 500-per-call cap ([WIP §6 Q6](../../../../docs/research/outbound-pipeline-findings.md#6-open-design-questions)).

Lead-create responses (`POST /api/leads`, `POST /api/leads/multiple`) include both `id` (integer) and `uuid` (string) fields; use `id` for downstream API calls — every other EB endpoint that takes a lead reference accepts the integer form. The `uuid` field is forward-compatible additive (verified live 2026-05-01 — added in the ~3-day window between BC-5906 round-2 (2026-04-27) and BC-6308 round-3 (2026-04-30)).

### Inbox / replies (13 tools)

Send reply, mark interested, push to follow-up, reply analytics ([WIP §6 Q6](../../../../docs/research/outbound-pipeline-findings.md#6-open-design-questions)).

### Blocklist (8 tools)

Full CRUD for both email-level and domain-level block entries including bulk add/remove. Relevant to the `SUPPRESS` action in the reply-processing pipeline ([WIP §1 Layer 3 label-sync flow](../../../../docs/research/outbound-pipeline-findings.md#layer-3-reply-processing), [WIP §6 Q6](../../../../docs/research/outbound-pipeline-findings.md#6-open-design-questions)).

### Senders (11 tools)

Sender account management — attach, detach, rotate, list.

### Tags (9 tools)

Tag CRUD on campaigns / leads.

### Webhooks (7 tools)

Webhook subscription management for event delivery. Note: Brite's production reply pipeline consumes Email Bison events via OutboundSync, not directly — see [WIP §1 Layer 2](../../../../docs/research/outbound-pipeline-findings.md#layer-2-sending--sequencing).

### Schedules (6 tools)

Sending schedule configuration — send windows, cadence.

### Workspace (17 tools)

Workspace-level configuration and metadata. The active-workspace meta-tools (`get_active_workspace_info`, `set_active_workspace`, `reset_to_primary_workspace`, `validate_workspace_key`) are the tools a skill uses to verify which workspace it's talking to before mutating anything. The 17 tools returned by `discover_tools(category="workspace")` on 2026-04-20 are: `list_workspaces`, `get_workspace_details`, `create_workspace`, `update_workspace`, `switch_workspace`, **`get_workspace_stats`** (aggregate workspace-level stats — emails sent, opens, replies; this is the tool skills reach for a quick-stats rollup, NOT `list_workspace_stats` which does not exist despite occasional cross-references in sibling skills), `get_workspace_line_area_stats` (by-date breakdown for charts), `invite_team_member`, `accept_workspace_invitation`, `create_workspace_user`, `create_api_token`, `get_master_inbox_settings`, `update_master_inbox_settings`, `get_account_details` (core tier), `update_profile_picture`, `update_password`, `generate_headless_ui_token`.

### Warmup (5 tools)

Domain/inbox warmup controls — start, stop, status, configuration. Relevant for new domain onboarding.

### Sequences (4 tools)

Sequence-level CRUD (separate from campaigns — sequences are the step structure, campaigns are the runtime).

### Templates (4 tools)

Email template CRUD.

### Tracking (3 tools)

Open/click tracking configuration.

### Variables (2 tools)

Custom variable management for merge fields.

### Analytics (4 tools — top-level aggregators)

Not part of any of the 14 categories above — these are top-level summary aggregators that `discover_tools(search="analytics")` returns. Each returns pre-aggregated stats without flooding context with raw rows. Reach for these when the skill's goal is aggregate reporting (not per-record mutation).

- `get_leads_analytics` — aggregated stats across all leads (optionally filtered by campaign). Summary stats, engagement rates, top performers.
- `get_replies_analytics` — aggregated reply analytics. Returns total counts, breakdown by reply status (`interested` / `not interested` / `auto-reply`), top campaigns by engagement, and sample replies. **This is the reply-sentiment distribution tool** — reach for it instead of iterating `list_replies` when the goal is a sentiment breakdown.
- `get_campaign_analytics` — cross-campaign performance analytics. Aggregated stats across all campaigns, open/reply-rate comparison, top-performer identification.
- `bulk_export` — dual-mode export. `format="summary"` returns server-side counts + breakdowns + samples; `format="csv"` exports to a file. Supported resources: scheduled_emails, campaign_leads, sender_emails, campaign_sender_emails, blocklist, blocklist_domains, tags, webhooks, lead_replies.

Verified via `discover_tools(search="analytics")` on 2026-04-20.

### Discoverability (meta-tools)

Always reach for these before guessing at tool names:

- `discover_tools` — returns the full live tool catalog for the active workspace
- `search_api_spec` — keyword search across the API spec

If `discover_tools` returns a category or count that contradicts this document, trust `discover_tools` and update the "Last verified" date at the bottom.

## Common workflows

Canonical recipes that combine multiple tools in a required order. Skills should follow these sequences verbatim unless they have a reason to deviate documented in their own `## Operational Runbook`.

### Launch a campaign end-to-end (9 MCP calls)

Verified against the live API spec via `search_api_spec` on 2026-04-14 (step 2a added 2026-04-28 per BC-6306). Order matters — several steps depend on IDs returned by prior steps, and some are gated by `draft` vs `queued` campaign state.

| # | Tool | Category | API path | What it does |
|---|---|---|---|---|
| 0 | `get_active_workspace_info` | workspace | `GET /api/workspaces/active` | Availability probe per ADR 2c — never skip |
| 1 | `bulk_create_leads` *(or `upsert_multiple_leads`, `bulk_create_leads_csv`)* | leads | `POST /api/leads` *(variants)* | Create lead records **before** the campaign exists. Max 500 per call — chunk larger lists. Response returns the lead IDs used in step 3. |
| 2 | `create_campaign` | campaigns | `POST /api/campaigns` | Create an empty campaign shell. No leads / senders / schedule / sequence yet. Returns a campaign ID. |
| 2a | `update_campaign` | campaigns | `PATCH /api/campaigns/{id}/update` | Apply deliverability defaults for cold outreach — set `plain_text: true`. EB defaults `plain_text: false` (HTML mode), which carries tracking pixels + link rewrites that signal "automated marketing" to spam filters. Single PATCH per campaign — not on the two-call confirmation gate list. Idempotent on re-send (each PATCH must include every boolean to preserve — EB resets omitted booleans to `false` per API spec wording *"If nothing sent, false is assumed."*; verified BC-6544). |
| 3 | `import_leads_to_campaign` | campaigns | `POST /api/campaigns/{id}/leads/attach-leads` | Attach the lead IDs from step 1 to the campaign from step 2. **Confirmation-gated** (see below). Fires HTTP 422 with `allow_parallel_sending` conflict when any lead is already in another campaign (any status — verified BC-6545); see gotchas for path-specific response shape. |
| 4a | `list_sender_emails` | senders | `GET /api/sender-emails` | Enumerate connected sender accounts. Filter for `status == "connected"`. |
| 4b | `attach_sender_emails_to_campaign` | campaigns | `POST /api/campaigns/{id}/attach-sender-emails` | Attach the sender email IDs. Request body: `{"sender_email_ids": [1, 2, 3]}`. |
| 5 | `create_schedule_from_template` | schedules | `POST /api/campaigns/{id}/create-schedule-from-template` | Apply a reusable schedule template. Request body: `{"schedule_id": N}` where N is the template's ID (list templates via `get_schedule_templates`). |
| 6 | `create_sequence_steps` *(v1.1)* | sequences | `POST /api/campaigns/v1.1/{id}/sequence-steps` | Create the email sequence. Request body: `{"title": ..., "sequence_steps": [{"email_subject", "email_body", "wait_in_days", "order", "variant", "thread_reply"}, ...]}`. Prefer the v1.1 path — see gotchas for the deprecated variant. |
| 7 | `resume_campaign` | campaigns | `PATCH /api/campaigns/{id}/resume` | Transition `Draft` → `Queued`. **Confirmation-gated** — this is the tool that "STARTS SENDING REAL EMAILS" per the MCP description. |

**Optional prerequisite before step 1:** if the sequence or subject line references custom variables (e.g. `{SITUATION}`, `{HOOK}`), create them first via `create_custom_variable` (variables category) so `bulk_create_leads` can attach their values.

**Post-launch verification:** after step 7 succeeds, call `get_campaign_stats` to confirm `status: "Queued"` and to capture the initial counters for the skill's report back to the user.

### Warmup health check (3 MCP calls)

Used mid-launch as part of the sender-attach step, or standalone from `deliverability-audit`.

| # | Tool | What it returns |
|---|---|---|
| 1 | `list_warmup_stats` | Per-sender warmup stats for a date range |
| 2 | `get_warmup_details` | Deep warmup state for a single sender (reputation, caps, progression) |
| 3 | `get_sender_email` | Sender config — daily limit, signature, IMAP/SMTP status |

Use this pair before attaching senders to verify each is past warmup and within the 30–50/day industry guideline for per-mailbox volume.

## MCP confirmation gates

The vendor MCP enforces a two-call confirmation pattern on consequential tools. On the **first call** to any of these tools without the `confirmation` parameter, the MCP returns a confirmation prompt describing what will happen; the skill must relay the prompt to the user and only repeat the call with the confirmation parameter **after explicit user approval**. Never auto-confirm.

| Tool | Category | What requires confirmation |
|---|---|---|
| `resume_campaign` | campaigns | "STARTS SENDING REAL EMAILS" (vendor wording) |
| `archive_campaign` | campaigns | Campaign cannot be resumed after archive |
| `import_leads_to_campaign` | campaigns | Attaches leads to a campaign (any status); cascades `allow_parallel_sending` decision when any lead is already in another campaign (verified BC-6545) |
| `unsubscribe_lead` | leads | Unsubscribes lead from all campaign emails globally |
| `blacklist_lead` | leads | Adds lead to the workspace-level blacklist |
| `enable_warmup` | warmup | Starts warmup sends from the account |
| `remove_email_from_blocklist` | blocklist | Un-blocks an email that was explicitly suppressed |
| `remove_domain_from_blocklist` | blocklist | Un-blocks an entire domain |

This pattern is **stronger** than a skill-level "ask the user" step — when invoked through the MCP-tool-wrapper layer, the wrapper itself gates the action, so bypassing it requires an explicit `confirmation` parameter on call-2. Skills should mirror the MCP's two-call shape in their Operational Runbook rather than introducing a parallel confirmation layer.

**Caveat — extended-tier tools have no wrapper layer to enforce the gate** (Sx-9, BC-5906; BC-6439). The `confirmation` enforcement described above presumes a wrapper layer exists. For three extended-tier tools used by `/marketing:launch-campaign` — `resume_campaign`, `import_leads_to_campaign`, and `bulk_create_leads` — **no wrapper layer is implemented**. Verified BC-6439 (2026-04-29): none appear as direct callables in the `mcp__emailbison-personal__*` namespace; all surface only as `tier: extended` description strings in `discover_tools` with the explicit instruction to invoke via `search_api_spec` + `call_api`. The corresponding REST endpoints — `/api/leads/multiple` (POST), `/api/campaigns/{id}/leads/attach-leads` (POST), and `/api/campaigns/{id}/resume` (PATCH) — have no `confirmation` field in their request bodies (verified BC-5906 round-2 + BC-6439). The `confirmation` prose in those `discover_tools` descriptions is documentation aimed at the agent's planning loop, **not** a runtime-enforced gate at any layer. For these three tools the agent-side `AskUserQuestion` turn is the sole safeguard; BC-2707's turn-structure rationale still applies, just at the agent layer because no vendor layer exists. There is no migration path to wrapper-tool invocation for these tools — closure of BC-6439.

## Rate limits and quotas

- **Bulk lead import:** `bulk_create_leads` and `upsert_multiple_leads` both accept **500 leads per call** (verified against the live API spec on 2026-04-14 — note the exact tool name is `bulk_create_leads`, not `bulk_create`, despite the abbreviated reference in [WIP §6 Q6](../../../../docs/research/outbound-pipeline-findings.md#6-open-design-questions)). Skills doing larger imports must chunk.
- **Per-minute / per-hour rate limits:** not documented in the research WIP. UNVERIFIED — a skill author should check `discover_tools` output or vendor docs for the current API spec before doing any high-volume work.
- **Sending volume caps** (Gmail / Yahoo / Outlook post-2024 enforcement): not an Email Bison limit but a deliverability constraint — the `campaign-orchestration` skill owns caps like "30–50 emails/day per mailbox" per [WIP §7 Key Principles](../../../../docs/research/outbound-pipeline-findings.md#key-principles).

## Known gotchas

- **Two workspaces, two tool prefixes.** A skill that forgets to pick a server (`emailbison-b2b` vs `emailbison-personal`) will default to whichever the tool-loading order surfaced first. Always gate the first call on recipient type or on an explicit `get_active_workspace_info` check.
- **`Instance-URL` is mandatory.** Without it the MCP server cannot route the request — the vendor endpoint is a single URL that multiplexes instances via header.
- **Beta status.** The server is still in Beta as of 2026-04-10 ([WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked)). Tool surface may change without notice — re-verify before shipping a skill that depends on tool-name stability.
- **OutboundSync is the canonical sync path, not webhooks.** Don't have a skill subscribe to Email Bison webhooks directly — the OutboundSync layer owns that, and double-subscribing creates dedup headaches ([WIP §1 Layer 3 architectural rules](../../../../docs/research/outbound-pipeline-findings.md#layer-3-reply-processing)).
- **Community repos return stale inventories.** If an agent surfaces "25 tools (read-only)" from the old WIP or from `Sirkunle001/email-bison-claude-mcp`, that's pre-2026-04-10 and wrong. The official server has 141 tools with full CRUD.
- **`import_leads_to_campaign` fires `allow_parallel_sending` conflict on any-campaign attach (verified BC-6545, 2026-05-04).** If a lead being attached is already in another campaign — regardless of the other campaign's status (draft / active / paused / etc.) — the attach refuses with HTTP 422. Verified via `call_api` against `/api/campaigns/{id}/leads/attach-leads` in workspace 13 with two draft test campaigns. Through `call_api` the response body is stripped to `{error: HTTP 422 Error}` (Sx-8 wrapper limitation); the vendor-tool path (`import_leads_to_campaign` direct invocation) may surface the prompt body but was NOT verified this round. Override (`allow_parallel_sending: true` in the request body) succeeds in both paths — confirmed by re-attempting the same attach with the flag set. **Never auto-enable parallel sending.** Surface the conflict to the user verbatim if the path surfaces the prompt body; otherwise present the operator-side diagnostic (filter `list_leads` on `lead_campaign_status=in_sequence` and cross-reference against the lead IDs in the failing batch). Parallel sending can over-contact a prospect across campaigns and is a deliverability risk. If the user declines, split the lead list and re-attach only the leads that aren't in other campaigns.
- **Deprecated sequence endpoints still exist.** The API spec exposes both `/api/campaigns/{campaign_id}/sequence-steps` (marked `deprecated`) and `/api/campaigns/v1.1/{campaign_id}/sequence-steps`. Tool-name aliases on the MCP side may point either way depending on version. Skills should explicitly prefer v1.1 — check the path returned by `search_api_spec` before calling `create_sequence_steps` if tool-name stability matters to the skill.
- **`list_campaigns` has no server-side date-range filter.** The tool supports `status` and `search` filters only. Skills that need "campaigns in a date window" must pull the full list and filter client-side on `created_at` / `started_at`. The Campaigns category (21 tools) has no cross-campaign date-range enumerator — `get_campaign_stats_by_date` is per-campaign, not cross-campaign. Verified via `discover_tools(category="campaigns")` on 2026-04-20.
- **`plain_text` defaults to `false` on `create_campaign`.** EB sends in HTML mode by default; for cold outreach the spec follow-up is `update_campaign` with `plain_text: true` (single PATCH; idempotent on re-send only when the same body is repeated, see BC-6544 — `update_campaign` is NOT on the two-call confirmation gate list). The `/marketing:launch-campaign` command's Phase 5 applies this automatically (see § Common workflows step 2a above); any net-new spec doing cold outreach should mirror that pattern. HTML mode for cold-B2B carries tracking pixels + link rewrites that signal "automated marketing" to spam filters and degrade deliverability. Surfaced by BC-5906 round-2 dogfood (Sx-15); spec fix shipped in BC-6306. The "PATCH treats omitted booleans as `false`" gotcha was added 2026-05-01 (BC-6544); details under § Common workflows row 2a.
- **`search_api_spec` doesn't match natural-language phrases.** Phrases like "custom variable list", "create-schedule", "sequence-steps" return `not found`. Only URL-path queries (`/api/custom-variables`) or short keywords (`custom-variables`, `schedule template`, `variables`) work. Surfaced by BC-5906 round-2 (Sx-1); spec fix shipped in BC-6298.
- **API spec "required" fields are advisory.** `/api/leads` POST schema marks `{first_name, last_name, email}` as required; reality silently accepts requests without `last_name` (verified — lead created with `last_name: null`). Never trust required-vs-optional markings without a ground-truth test call. Surfaced by BC-5906 round-2 (Sx-5); spec fix shipped in BC-6298.
- **Bulk POST is all-or-nothing on validation failure.** A single bad row (duplicate email, invalid format) in a `bulk_create_leads` batch fails the whole batch with HTTP 422; valid rows are NOT created. The `call_api` wrapper exposes only `{"error": "HTTP 422 Error"}` — no per-lead detail. Recovery requires inspecting EB UI for the offending row(s). Skills cannot offer per-row diagnostics from the response alone. Surfaced by BC-5906 round-2 (Sx-8); spec fix shipped in BC-6298.
- **`?per_page=N` query param is silently ignored.** EB hardcodes `per_page: 15` regardless of the parameter. Pagination loops are N/15 pages and not operator-configurable — plan iteration counts accordingly (e.g., 500 senders ≈ 34 pages; 772 senders = 52 pages). Surfaced by BC-5906 round-2 (Sx-10); spec fix shipped in BC-6298.
- **Status filter is case-sensitive in a non-obvious direction.** `?status=connected` (lowercase) succeeds; `?status=Connected` (capitalized — matching the response `status: "Connected"` data field) returns 422. Operators reading the response payload and copying the value into a filter will hit 422 with no useful diagnostic. Always lowercase the filter value. Surfaced by BC-5906 round-2 (Sx-11); spec fix shipped in BC-6298.
- **Lead-body field names diverge from common-CSV-column names.** EB's `/api/leads/multiple` endpoint expects `title` (not `job_title`), `company` (not `company_name`), and has NO `company_domain` field at all. CSV columns named `job_title`/`company_name`/`company_domain` must be remapped at lead-body construction time: `csv.job_title → eb.title`, `csv.company_name → eb.company`, `csv.company_domain → custom_variable` (or drop). Sending the CSV-column names verbatim silently creates leads with `title: null` / `company: null` — data loss disguised as success. Surfaced by BC-5906 round-2 (Sx-6); spec fix shipped in BC-6300.
- **Custom variables have no `default` field at the API.** `POST /api/custom-variables` accepts only `{name}` (string, required). Response body is `{id, name, created_at, updated_at}` — no `default` field, ever. Workspace-level fallback text does NOT exist; defaults live per-lead via `bulk_create_leads`'s `custom_variables: [{name, value}]` array. The `/marketing:launch-campaign` command's Phase 4 step 2 consumes the artifact's `default` field as the per-lead fill-in when the CSV row lacks a column for that variable. Sending `default` to `POST /api/custom-variables` is silently ignored — no error, no warning. Surfaced by BC-5906 round-2 (Sx-2); spec fix shipped in BC-6299.
- **Custom variable names are silently lowercased on store.** Sent `RECENCY_ANCHOR` (uppercase, per the email-copywriting artifact convention); EB stores `recency_anchor` (lowercase). Same for all SCREAMING_SNAKE_CASE names. Per-lead `custom_variables` array values must use lowercase names to match EB's stored form (verified Phase 4 round-2 — uppercase per-lead names round-trip but match against EB's lowercase store). Render-engine case-sensitivity verified BC-6308 round-3 R-2a: UPPERCASE `{UPPERCASE_TOKEN}` resolves correctly against the lowercased store (case-insensitive match); lowercase `{lowercase_token}` does NOT resolve and renders as literal text — see token-case render gotcha below. Surfaced by BC-5906 round-2 (Sx-3); spec fix shipped in BC-6299.
- **Token render is UPPERCASE-only.** EB's render engine recognizes ONLY UPPERCASE `{TOKEN}` references as variable references (e.g., `{FIRST_NAME}`, `{RECENCY_ANCHOR}`). UPPERCASE tokens resolve via case-insensitive lookup against the lead's `custom_variables` (which EB stores with lowercased names per Sx-3). Lowercase or mixed-case tokens (`{first_name}`, `{First_Name}`) are NOT resolved — they render as literal text without braces (e.g., `{first_name}` becomes the string `first_name` in the delivered email). Always use UPPERCASE in copy artifacts. Verified BC-6308 round-3 R-2a Preview Body output (workspace 13 test campaigns ids 29 + 30, deleted at T14 cleanup). Surfaced by BC-6308 round-3 (R-2a); spec fix shipped in BC-6548.
- **No DELETE endpoint for `/api/custom-variables`.** `search_api_spec(method=DELETE)` against custom-variables paths returns no match. Custom variables persist workspace-scoped indefinitely; only the EB UI can remove them. Cleanup wording in any spec referencing `/api/custom-variables` should reframe as "vars persist; document the retained set" rather than "delete via API". Practical implication: workspaces accumulate custom variables across campaigns; duplicate-name `POST` returns 422 (idempotent enough to safely re-run a Phase 3 from scratch). Surfaced by BC-5906 round-2 (Sx-4); spec fix shipped in BC-6299.
- **`variant` field on sequence steps is BOOLEAN, not a string.** EB's `POST /api/campaigns/v1.1/{id}/sequence-steps` request body marks `variant` as boolean (`false` / `true`) — A/B variant flag, not a label. Sending `"A"` or `"B"` (string A/B label borrowed from other platforms' terminology) will silently coerce or 422; reliable contract is boolean. Non-variant steps send `false`. Surfaced by BC-5906 round-2 (Sx-13); spec fix shipped in BC-6301.
- **EB auto-prepends `Re: ` to subjects when `thread_reply: true`.** When a sequence step carries `thread_reply: true` (always the case for step 2 of a 2-step sequence), EB inserts `Re: ` at delivery regardless of whether the `email_subject` already starts with `Re:`. Sending `"Re: Quick question"` produces `"Re: Re: Quick question"` in the recipient's inbox — double-prefix, deliverability-degrading. Always send the BARE subject for `thread_reply: true` steps; let EB prepend. Surfaced by BC-5906 round-2 (Sx-14); spec fix shipped in BC-6301.

## Related skills

**Primary consumers:**

- `campaign-orchestration` (`plugins/marketing/skills/campaign-orchestration/`, BC-2718) — sequence design, inbox rotation, warmup strategy, end-to-end campaign launch
- `deliverability-audit` (BC-2719) — domain reputation, bounce rate analysis
- `email-copywriting` (`plugins/marketing/skills/email-copywriting/`, BC-5825) — content generation for campaign sequences; feeds `/marketing:launch-campaign` command
- `reply-processing` (BC-2720) — pairs Email Bison blocklist with Master Inbox label actions
- `list-building` (`plugins/marketing/skills/list-building/`, BC-2717) — Workflow 2 cross-workspace exclusion (dual `list_leads` against both b2b + personal workspaces) for Sources 2 + 3; emits `enriched_leads.csv` for `launch-campaign` / `campaign-orchestration` to consume
- `campaign-analysis` (BC-2721) — pulls reply / open / bounce analytics

**Upstream integration (feeds into Email Bison):** Brite enrichment engine (`brite-data-platform`, custom Python CLI — see [WIP §1 Layer 1](../../../../docs/research/outbound-pipeline-findings.md#layer-1-list-building--enrichment)). No MCP server exists for the enrichment engine.

**Downstream integration (consumes Email Bison events):** OutboundSync webhooks → Salesforce Contacts → Master Inbox classification → Front for BDR handoff ([WIP §1 Layers 2–5](../../../../docs/research/outbound-pipeline-findings.md#layer-2-sending--sequencing)).

**Adjacent integration:** [Salesforce](salesforce.md) — the CRM system of record. Email Bison is the sending runtime; Salesforce holds the authoritative lead/contact/reply state. Most outbound skills touch both: Salesforce for suppression reads + lifecycle stage, Email Bison for the send itself.

**Alternatives considered and rejected:** Smartlead (market alternative, never Brite-active), Instantly (same), community `Sirkunle001/email-bison-claude-mcp` (13 tools, superseded).

## Last verified

`2026-05-01` — BC-6515: appended forward-compat note to § Tool inventory § Leads (15 tools) flagging that lead-create responses now include both `id` (integer) and `uuid` (string) fields. Verified live via `POST /api/leads/multiple` against `emailbison-personal` workspace 13 (lead ID 14723 created + deleted; raw response captured in `docs/plans/BC-6515-plan.md`). API spec response schema (`search_api_spec(POST /api/leads/multiple)`) does NOT yet list `uuid` — runtime added it ahead of spec docs; spec-doc-lag observation logged but not promoted to a §Known gotchas bullet (issue scope tight per round-3 chain pattern).

Prior: `2026-04-29` — BC-6301: appended 2 §Known gotchas bullets (Sx-13 `variant` is boolean not string, Sx-14 EB auto-prepends `Re: ` when `thread_reply: true`) sourced from BC-5906 round-2 dogfood transcript Phase 9 + verbatim sequence-response evidence (campaign 22 step ID 7 stored `"Re: Re: ..."` from spec input `"Re: ..."`). Live API behavior verified during round-2; round-3 (BC-6308) will re-walk to confirm.

Prior: `2026-04-28` — BC-6300: appended §Known gotchas bullet (Sx-6 lead-body field-name divergence — `title`/`company`/no-`company_domain`) sourced from BC-5906 round-2 dogfood transcript + `search_api_spec` verification of `/api/leads/multiple` schema. Same-day stack with the BC-6298 entry below.

Prior: `2026-04-28` — BC-6298: appended 5 §Known gotchas bullets (Sx-1 search-format, Sx-5 advisory required-fields, Sx-8 bulk-POST all-or-nothing, Sx-10 hardcoded `per_page=15`, Sx-11 lowercase status filter) sourced from BC-5906 round-2 dogfood transcript. No live API re-verification — gotchas documented from round-2 evidence; round-3 (BC-6308) will re-walk and confirm.

Prior: `2026-04-20` — BC-2721 tasks 7 + 10 via `discover_tools` on `emailbison-b2b`:
- Task 7: added new §Analytics (4 tools — top-level aggregators) subsection documenting `get_leads_analytics`, `get_replies_analytics`, `get_campaign_analytics`, and `bulk_export` (not in the 14 documented categories — they're a top-level analytics group). Added §Known gotchas bullet: `list_campaigns` has no server-side date-range filter (client-side filter on `created_at` / `started_at` required).
- Task 10 BC-5797 factual-anchor audit: caught wrong tool name `list_workspace_stats` (does not exist) — actual name is `get_workspace_stats`. Fixed in `campaign-analysis/SKILL.md` + `evals.json`; sibling `email-bison/SKILL.md` has the same wrong name in 3 spots (lines 63/86/173) — tracked as a separate Linear issue alongside the BC-5903 sibling-skill namespace bug. Expanded Workspace (17 tools) section to enumerate all 17 tool names per `discover_tools(category="workspace")`.

Prior: `2026-04-17` — BC-5551 shipped credential centralization (Engineering Bitwarden item "Email Bison MCP — API tokens") + shell-profile onboarding + §Known Claude Code limitation documenting the plugin-scoped MCP blocker. Plugin-scoped MCP registration deferred until upstream Claude Code bugs [#6204](https://github.com/anthropics/claude-code/issues/6204)/[#9427](https://github.com/anthropics/claude-code/issues/9427) are resolved; servers continue to live at user level for now. Prose consistency fix: "API key" → "API token" throughout §Auth (vendor canonical term per `docs.emailbison.com/get-started/authentication`). Tokens rotated fresh during BC-5551 (the prior tokens were in a gitignored repo-root file that got cleared).

Prior: `2026-04-14` — Common workflows section, MCP confirmation-gate inventory, and new gotchas (parallel_sending, deprecated sequence endpoints) verified live via `discover_tools` on 11 categories + `search_api_spec` on `POST /api/campaigns/{id}/resume`, `POST /api/campaigns/{id}/attach-sender-emails`, `POST /api/campaigns/{id}/create-schedule-from-template`, and the v1.1 vs deprecated sequence-steps pair. Workspace connection re-verified via `get_active_workspace_info` (active workspace ID 52, `send.outbase.so`, primary).

Prior: `2026-04-11` — tool counts and categories copied from `docs/research/outbound-pipeline-findings.md` Phase 1 validation log (2026-04-09/10).

Run `discover_tools` on each server before shipping any skill that hard-codes a tool name from this document.
