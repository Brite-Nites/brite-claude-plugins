# Email Bison Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

Email Bison is Brite's cold email sequencing platform — the **sending layer** of the outbound pipeline. It rotates through thousands of managed inboxes, runs multi-step sequences, and emits events (sent, opened, replied, bounced, unsubscribed) that OutboundSync relays into Salesforce. Brite uses Email Bison exclusively; Smartlead and Instantly are market alternatives only, never Brite-active ([research WIP §2 corrected table](../../../../docs/research/outbound-pipeline-findings.md#2-handbook-drift)).

The official Email Bison MCP Server (Beta) exposes the full sending-layer API surface to Claude — validated in [research WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked).

## Consumed by

- _(none yet — see BC-2707, BC-2718, BC-2719, BC-2720 for the skills that will reference this)_

## Auth

**Credential type.** Email Bison API key per workspace. Passed as `Authorization: Bearer <key>` plus a mandatory `Instance-URL` header that routes the request to the correct vendor instance.

**Where it comes from.** Workspace UI → Settings → Integrations → EmailBison MCP. The workspace admin generates a key scoped to that workspace. The MCP endpoint itself is vendor-hosted and public; the key is what identifies the workspace ([research WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked)).

**Scopes.** Workspace-level full access. There is no documented sub-scoping — a key either has access to the workspace or it doesn't.

**Multi-workspace routing.** Brite runs two Email Bison instances, and the skill must pick the right one based on recipient type:

| Server name | Instance | Workspace | Used when | Workspace ID |
|---|---|---|---|---|
| `emailbison-b2b` | `send.outbase.so` | Brite Nites | Sending to business recipients | 52 |
| `emailbison-personal` | `personal.outbase.so` | BriteNites Team | Sending to consumer / personal recipients | 11 |

Both were verified live on 2026-04-10 ([research WIP §8 row 4](../../../../docs/research/outbound-pipeline-findings.md#1a-mcp-servers-8-checked)) and the current session's `get_active_workspace_info` calls (2026-04-11).

**Credential storage.** The marketing plugin's credential pattern is an open question owned by ADR 2a (BC-5041). Until that lands, keys live in the repo-root `.mcp.json` for dev convenience and are NOT distributed with the plugin. Do not commit real keys into `plugins/marketing/.mcp.json` — use `${ENV_VAR}` substitution once ADR 2a finalizes the pattern.

## Registration

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

**File location.** Today: repo-root `.mcp.json` (dev convenience). Target: `plugins/marketing/.mcp.json` once ADR 2a resolves credential storage.

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

Workspace-level configuration and metadata. Includes `get_active_workspace_info`, `set_active_workspace`, `reset_to_primary_workspace`, `validate_workspace_key`, `get_account_details` — the tools a skill uses to verify which workspace it's talking to before mutating anything.

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

### Discoverability (meta-tools)

Always reach for these before guessing at tool names:

- `discover_tools` — returns the full live tool catalog for the active workspace
- `search_api_spec` — keyword search across the API spec

If `discover_tools` returns a category or count that contradicts this document, trust `discover_tools` and update the "Last verified" date at the bottom.

## Common workflows

Canonical recipes that combine multiple tools in a required order. Skills should follow these sequences verbatim unless they have a reason to deviate documented in their own `## Operational Runbook`.

### Launch a campaign end-to-end (8 MCP calls)

Verified against the live API spec via `search_api_spec` on 2026-04-14. Order matters — several steps depend on IDs returned by prior steps, and some are gated by `draft` vs `queued` campaign state.

| # | Tool | Category | API path | What it does |
|---|---|---|---|---|
| 0 | `get_active_workspace_info` | workspace | `GET /api/workspaces/active` | Availability probe per ADR 2c — never skip |
| 1 | `bulk_create_leads` *(or `upsert_multiple_leads`, `bulk_create_leads_csv`)* | leads | `POST /api/leads` *(variants)* | Create lead records **before** the campaign exists. Max 500 per call — chunk larger lists. Response returns the lead IDs used in step 3. |
| 2 | `create_campaign` | campaigns | `POST /api/campaigns` | Create an empty campaign shell. No leads / senders / schedule / sequence yet. Returns a campaign ID. |
| 3 | `import_leads_to_campaign` | campaigns | `POST /api/campaigns/{id}/leads/attach-leads` | Attach the lead IDs from step 1 to the campaign from step 2. **Confirmation-gated** (see below). May fail with `allow_parallel_sending` prompt — see gotchas. |
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
| `import_leads_to_campaign` | campaigns | Attaches leads to a live campaign; may cascade `allow_parallel_sending` decision |
| `unsubscribe_lead` | leads | Unsubscribes lead from all campaign emails globally |
| `blacklist_lead` | leads | Adds lead to the workspace-level blacklist |
| `enable_warmup` | warmup | Starts warmup sends from the account |
| `remove_email_from_blocklist` | blocklist | Un-blocks an email that was explicitly suppressed |
| `remove_domain_from_blocklist` | blocklist | Un-blocks an entire domain |

This pattern is **stronger** than a skill-level "ask the user" step — the MCP itself gates the action, so bypassing it requires an explicit confirmation parameter. Skills should mirror the MCP's two-call shape in their Operational Runbook rather than introducing a parallel confirmation layer.

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
- **`import_leads_to_campaign` may fail with `allow_parallel_sending` prompt.** If a lead being attached is already in another campaign's active sequence, the tool refuses the attach and returns a prompt asking whether to enable parallel sending. **Never auto-enable this.** Surface the prompt to the user verbatim — parallel sending can over-contact a prospect across campaigns and is a deliverability risk. If the user declines, split the lead list and re-attach only the leads that aren't in other sequences.
- **Deprecated sequence endpoints still exist.** The API spec exposes both `/api/campaigns/{campaign_id}/sequence-steps` (marked `deprecated`) and `/api/campaigns/v1.1/{campaign_id}/sequence-steps`. Tool-name aliases on the MCP side may point either way depending on version. Skills should explicitly prefer v1.1 — check the path returned by `search_api_spec` before calling `create_sequence_steps` if tool-name stability matters to the skill.

## Related skills

**Primary consumers** *(not yet landed — tracked in Linear)*:

- `campaign-orchestration` (BC-2718) — sequence design, inbox rotation, warmup strategy
- `deliverability-audit` (BC-2719) — domain reputation, bounce rate analysis
- `reply-processing` (BC-2720) — pairs Email Bison blocklist with Master Inbox label actions
- `list-building` (BC-2717) — pipes enriched leads from `brite-data-platform` into Email Bison campaigns
- `campaign-analysis` (BC-2721) — pulls reply / open / bounce analytics

**Upstream integration (feeds into Email Bison):** Brite enrichment engine (`brite-data-platform`, custom Python CLI — see [WIP §1 Layer 1](../../../../docs/research/outbound-pipeline-findings.md#layer-1-list-building--enrichment)). No MCP server exists for the enrichment engine.

**Downstream integration (consumes Email Bison events):** OutboundSync webhooks → Salesforce Contacts → Master Inbox classification → Front for BDR handoff ([WIP §1 Layers 2–5](../../../../docs/research/outbound-pipeline-findings.md#layer-2-sending--sequencing)).

**Alternatives considered and rejected:** Smartlead (market alternative, never Brite-active), Instantly (same), community `Sirkunle001/email-bison-claude-mcp` (13 tools, superseded).

## Last verified

`2026-04-14` — Common workflows section, MCP confirmation-gate inventory, and new gotchas (parallel_sending, deprecated sequence endpoints) verified live via `discover_tools` on 11 categories + `search_api_spec` on `POST /api/campaigns/{id}/resume`, `POST /api/campaigns/{id}/attach-sender-emails`, `POST /api/campaigns/{id}/create-schedule-from-template`, and the v1.1 vs deprecated sequence-steps pair. Workspace connection re-verified via `get_active_workspace_info` (active workspace ID 52, `send.outbase.so`, primary).

Prior verification: `2026-04-11` — tool counts and categories copied from `docs/research/outbound-pipeline-findings.md` Phase 1 validation log (2026-04-09/10).

Run `discover_tools` on each server before shipping any skill that hard-codes a tool name from this document.
