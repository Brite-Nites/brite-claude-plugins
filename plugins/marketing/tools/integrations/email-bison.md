# Email Bison Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

Email Bison is Brite's cold email sequencing platform — the **sending layer** of the outbound pipeline. It rotates through thousands of managed inboxes, runs multi-step sequences, and emits events (sent, opened, replied, bounced, unsubscribed) that OutboundSync relays into Salesforce. Brite uses Email Bison exclusively; Smartlead and Instantly are market alternatives only, never Brite-active ([research WIP §2 corrected table](../../../../docs/research/outbound-pipeline-research-wip.md#2-handbook-drift)).

The official Email Bison MCP Server (Beta) exposes the full sending-layer API surface to Claude — validated in [research WIP §8 row 4](../../../../docs/research/outbound-pipeline-research-wip.md#1a-mcp-servers-8-checked).

## Consumed by

- _(none yet — see BC-2707, BC-2718, BC-2719, BC-2720 for the skills that will reference this)_

## Auth

**Credential type.** Email Bison API key per workspace. Passed as `Authorization: Bearer <key>` plus a mandatory `Instance-URL` header that routes the request to the correct vendor instance.

**Where it comes from.** Workspace UI → Settings → Integrations → EmailBison MCP. The workspace admin generates a key scoped to that workspace. The MCP endpoint itself is vendor-hosted and public; the key is what identifies the workspace ([research WIP §8 row 4](../../../../docs/research/outbound-pipeline-research-wip.md#1a-mcp-servers-8-checked)).

**Scopes.** Workspace-level full access. There is no documented sub-scoping — a key either has access to the workspace or it doesn't.

**Multi-workspace routing.** Brite runs two Email Bison instances, and the skill must pick the right one based on recipient type:

| Server name | Instance | Workspace | Used when | Workspace ID |
|---|---|---|---|---|
| `emailbison-b2b` | `send.outbase.so` | Brite Nites | Sending to business recipients | 52 |
| `emailbison-personal` | `personal.outbase.so` | BriteNites Team | Sending to consumer / personal recipients | 11 |

Both were verified live on 2026-04-10 ([research WIP §8 row 4](../../../../docs/research/outbound-pipeline-research-wip.md#1a-mcp-servers-8-checked)) and the current session's `get_active_workspace_info` calls (2026-04-11).

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

Source: [research WIP §8 row 4](../../../../docs/research/outbound-pipeline-research-wip.md#1a-mcp-servers-8-checked).

## Tool inventory

The server exposes **141 tools across 16 categories** (23 core + 118 extended) per [research WIP §8 row 4](../../../../docs/research/outbound-pipeline-research-wip.md#1a-mcp-servers-8-checked). The 14 documented categories below cover ~125 tools; the remaining ~16 tools across 2 further categories are not enumerated in the research WIP — use `discover_tools` for the full live inventory.

### Campaigns (21 tools)

Full CRUD over cold-email campaigns including create, import leads, attach senders, pause/resume ([WIP §6 Q6](../../../../docs/research/outbound-pipeline-research-wip.md#6-open-design-questions)).

### Leads (15 tools)

Lead create, bulk create (up to 500 per call), upsert, blacklist. See rate limits below for the 500-per-call cap ([WIP §6 Q6](../../../../docs/research/outbound-pipeline-research-wip.md#6-open-design-questions)).

### Inbox / replies (13 tools)

Send reply, mark interested, push to follow-up, reply analytics ([WIP §6 Q6](../../../../docs/research/outbound-pipeline-research-wip.md#6-open-design-questions)).

### Blocklist (8 tools)

Full CRUD for both email-level and domain-level block entries including bulk add/remove. Relevant to the `SUPPRESS` action in the reply-processing pipeline ([WIP §1 Layer 3 label-sync flow](../../../../docs/research/outbound-pipeline-research-wip.md#layer-3-reply-processing), [WIP §6 Q6](../../../../docs/research/outbound-pipeline-research-wip.md#6-open-design-questions)).

### Senders (11 tools)

Sender account management — attach, detach, rotate, list.

### Tags (9 tools)

Tag CRUD on campaigns / leads.

### Webhooks (7 tools)

Webhook subscription management for event delivery. Note: Brite's production reply pipeline consumes Email Bison events via OutboundSync, not directly — see [WIP §1 Layer 2](../../../../docs/research/outbound-pipeline-research-wip.md#layer-2-sending--sequencing).

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

## Rate limits and quotas

- **Bulk lead import:** `bulk_create` accepts **500 leads per call** ([WIP §6 Q6](../../../../docs/research/outbound-pipeline-research-wip.md#6-open-design-questions)). Skills doing larger imports must chunk.
- **Per-minute / per-hour rate limits:** not documented in the research WIP. UNVERIFIED — a skill author should check `discover_tools` output or vendor docs for the current API spec before doing any high-volume work.
- **Sending volume caps** (Gmail / Yahoo / Outlook post-2024 enforcement): not an Email Bison limit but a deliverability constraint — the `campaign-orchestration` skill owns caps like "30–50 emails/day per mailbox" per [WIP §7 Key Principles](../../../../docs/research/outbound-pipeline-research-wip.md#key-principles).

## Known gotchas

- **Two workspaces, two tool prefixes.** A skill that forgets to pick a server (`emailbison-b2b` vs `emailbison-personal`) will default to whichever the tool-loading order surfaced first. Always gate the first call on recipient type or on an explicit `get_active_workspace_info` check.
- **`Instance-URL` is mandatory.** Without it the MCP server cannot route the request — the vendor endpoint is a single URL that multiplexes instances via header.
- **Beta status.** The server is still in Beta as of 2026-04-10 ([WIP §8 row 4](../../../../docs/research/outbound-pipeline-research-wip.md#1a-mcp-servers-8-checked)). Tool surface may change without notice — re-verify before shipping a skill that depends on tool-name stability.
- **OutboundSync is the canonical sync path, not webhooks.** Don't have a skill subscribe to Email Bison webhooks directly — the OutboundSync layer owns that, and double-subscribing creates dedup headaches ([WIP §1 Layer 3 architectural rules](../../../../docs/research/outbound-pipeline-research-wip.md#layer-3-reply-processing)).
- **Community repos return stale inventories.** If an agent surfaces "25 tools (read-only)" from the old WIP or from `Sirkunle001/email-bison-claude-mcp`, that's pre-2026-04-10 and wrong. The official server has 141 tools with full CRUD.

## Related skills

**Primary consumers** *(not yet landed — tracked in Linear)*:

- `campaign-orchestration` (BC-2718) — sequence design, inbox rotation, warmup strategy
- `deliverability-audit` (BC-2719) — domain reputation, bounce rate analysis
- `reply-processing` (BC-2720) — pairs Email Bison blocklist with Master Inbox label actions
- `list-building` (BC-2717) — pipes enriched leads from `brite-data-platform` into Email Bison campaigns
- `campaign-analysis` (BC-2721) — pulls reply / open / bounce analytics

**Upstream integration (feeds into Email Bison):** Brite enrichment engine (`brite-data-platform`, custom Python CLI — see [WIP §1 Layer 1](../../../../docs/research/outbound-pipeline-research-wip.md#layer-1-list-building--enrichment)). No MCP server exists for the enrichment engine.

**Downstream integration (consumes Email Bison events):** OutboundSync webhooks → Salesforce Contacts → Master Inbox classification → Front for BDR handoff ([WIP §1 Layers 2–5](../../../../docs/research/outbound-pipeline-research-wip.md#layer-2-sending--sequencing)).

**Alternatives considered and rejected:** Smartlead (market alternative, never Brite-active), Instantly (same), community `Sirkunle001/email-bison-claude-mcp` (13 tools, superseded).

## Last verified

`2026-04-11` — tool counts and categories copied from `docs/research/outbound-pipeline-research-wip.md` Phase 1 validation log (2026-04-09/10). Both workspace connections re-verified live via `get_active_workspace_info` on 2026-04-11. Run `discover_tools` on each server before shipping any skill that hard-codes a tool name from this document.
