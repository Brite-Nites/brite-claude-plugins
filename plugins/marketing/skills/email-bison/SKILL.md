---
name: email-bison
description: Default entry point for Email Bison work. Triggers on Email Bison, cold email, outbound campaign, lead import, sender inbox, warmup, blocklist, unsubscribe, workspace, tag, webhook, template, variable, schedule. Routes to campaign-orchestration (sequence design), reply-processing (inbox classification), or deliverability-audit (SPF/DKIM/DMARC) when the user's intent matches their scope; otherwise handles the long tail inline.
user-invocable: true
allowed-tools: mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob, Grep
metadata:
  version: 0.1.0
  category: Outbound Lead Gen
---

# Email Bison

You are the default operator for Brite's Email Bison work. This skill serves RevOps, BDRs, and marketing operators who need to touch Email Bison directly — managing the workspace, senders, inboxes, tags, blocklist, webhooks, schedule templates, variables, or pulling quick stats — and routes deeper work to specialized sibling skills when intent matches their scope. The outcome: one entry point for the 141-tool Email Bison MCP surface, with a workspace-confirmation guard that prevents cross-contamination between the b2b and personal instances.

---

## Before Starting

**Check for product marketing context first.** If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

**Confirm the target workspace before any mutating MCP call.** Brite runs two Email Bison instances (`emailbison-b2b` for business recipients, `emailbison-personal` for consumer recipients) — see `plugins/marketing/tools/integrations/email-bison.md` §Auth for the canonical server/instance/workspace-id table. Disambiguate by recipient characteristics first (business email domain + company name → b2b; personal email domain like gmail.com/yahoo.com → personal). Fall back to explicit user confirmation if the signal is ambiguous. Read-only calls (`get_active_workspace_info`, `list_campaigns`, `get_campaign_stats`) do not require confirmation, but announce which server they target.

**Read `docs/designs/outbound-agent-architecture.md`** for cross-cutting architectural context (MCP servers, cross-repo access, audience view ownership). ADR 2a establishes Email Bison as Brite's sole sequencer — never reference Smartlead, Instantly, or Apollo as tools this skill calls.

---

## Methodology

Non-Brite-specific best practices for running a cold-email sequencer at scale. Apply these frameworks regardless of which sequencer the skill happens to drive.

### Sequencer fundamentals

A cold-email sequencer is a three-part system: a **sending layer** (rotates mailboxes, respects per-mailbox caps), a **sequence engine** (multi-step branching, timing, content variants), and an **event layer** (opens, replies, bounces, unsubscribes). Skills touching any of these layers should know which layer they're operating on — mutations in one layer can silently corrupt state in another (e.g. attaching a sender to a live campaign bypasses warmup gating).

### Inbox rotation theory

Per-mailbox volume caps emerged after Gmail/Yahoo/Outlook's 2024 bulk-sender enforcement. Industry guideline: **30–50 emails per day per mailbox**, ramping from ≤10/day during the first 30 days of domain age. A 500-lead campaign needs ~10–17 connected senders to clear in one day without tripping throttles; stretching it across 2–3 days is safer. The rotation algorithm matters less than the volume ceiling — round-robin is fine, randomization is fine, as long as each mailbox stays under cap.

### Warmup timelines

New sending domains need **4–6 weeks of warmup** before real send volume. New IP on an aged domain: 2 weeks. Warmup services run synthetic reply exchanges with a peer network to build sender reputation; the `warmup` category tools (5 tools — `enable_warmup`, `list_warmup_stats`, `get_warmup_details`, etc.) manage this. Do not skip warmup on fresh domains; the bounce-rate spike on day 1 of real send tanks the domain for weeks.

### Blocklist hygiene

Every outbound program accumulates two kinds of suppressions: **explicit** (unsubscribes, spam complaints, bounces) and **implicit** (competitors, current customers, legal no-contact lists). Email Bison exposes both email-level and domain-level blocklist endpoints (8 tools in the `blocklist` category). A clean blocklist is the cheapest deliverability investment — a fortune-500 domain that slipped through enrichment and got a bulk mailer treatment is a manual 30-minute cleanup; blocking the root domain before it happens is a single MCP call. Audit the blocklist monthly: any unsubscribe > 90 days old is safe to retain; any bulk-added entry without a recorded reason is a candidate for review.

---

## Brite Implementation

This section translates the methodology into Brite's concrete stack. Every rule cites its source.

### Tools this skill calls

| What the skill needs to do | MCP server / tool | Reaches | Source |
|---|---|---|---|
| Pick and verify the target workspace | `emailbison-b2b` or `emailbison-personal` (`get_active_workspace_info`) | Email Bison workspace 55 or 13 | ADR 2a — sole sequencer; `email-bison.md` §Auth |
| Inspect or rotate sender inboxes | `emailbison-{b2b,personal}` (`list_sender_emails`, `get_sender_email`, `attach_sender_emails_to_campaign`, `detach_sender_emails_from_campaign`) | Active workspace | `email-bison.md` §Tool inventory → Senders |
| Manage email-level and domain-level blocklist | `emailbison-{b2b,personal}` (`add_email_to_blocklist`, `add_domain_to_blocklist`, `bulk_add_to_blocklist`, `remove_email_from_blocklist`, `remove_domain_from_blocklist`) | Active workspace | `email-bison.md` §Tool inventory → Blocklist |
| Tag operations on leads or campaigns | `emailbison-{b2b,personal}` (tags category) | Active workspace | `email-bison.md` §Tool inventory → Tags |
| Webhook subscription management | `emailbison-{b2b,personal}` (webhooks category) | Active workspace | `email-bison.md` §Tool inventory → Webhooks |
| Schedule templates and variable management | `emailbison-{b2b,personal}` (schedules + variables categories) | Active workspace | `email-bison.md` §Tool inventory |
| Pull quick stats (not full analytics — hand off to `campaign-analysis` for depth) | `emailbison-{b2b,personal}` (`get_campaign_stats`, `get_leads_analytics`, `get_workspace_stats`) | Active workspace | `email-bison.md` §Common workflows |

**Wildcard form per ADR 2c** — `allowed-tools` uses `mcp__plugin_marketing_emailbison-{b2b,personal}__*` because the skill exercises tools across most of the 141-tool surface. Narrower cherry-picking would require enumerating dozens of tool names and updating the list every time the vendor adds one.

### Architectural rules that apply

- **Email Bison is Brite's sole sequencer** — never reference or call Smartlead, Instantly, Apollo, or community `Sirkunle001/email-bison-claude-mcp` (superseded, 13 tools). ADR 2a; `email-bison.md` §Registration.
- **Workspace disambiguation gates every mutating call** — b2b vs personal are distinct data domains with distinct recipient sets; cross-posting leaks personal contacts into business campaigns or vice versa. `email-bison.md` §Auth.
- **OutboundSync owns the event sync to Salesforce** — do not have this skill subscribe to Email Bison webhooks for CRM syncing. The skill manages webhook CRUD for one-off notifiers (Slack alerts, internal dashboards) only. `email-bison.md` §Known gotchas bullet 4.
- **The MCP itself gates 8 consequential tools** — mirror the two-call confirmation pattern in the Operational Runbook; do not introduce a parallel skill-level confirmation layer. `email-bison.md` §MCP confirmation gates.
- **Bulk lead imports cap at 500 per call** — `bulk_create_leads` and `upsert_multiple_leads` are documented bulk tools with a 500-lead-per-call cap (`email-bison.md` §Rate limits). This skill does not run bulk imports end-to-end (that's `list-building`'s scope), but when helping with any tool whose name starts with `bulk_`, check `email-bison.md` or `discover_tools` for the documented cap before sending larger requests. Single-lead, confirmation-gated tools like `blacklist_lead` have no chunking concept — each call requires a separate user approval cycle; never loop them unattended.

### Cross-skill boundaries

**Owns (handled inline):**

- Workspace operations (verify, switch, list workspace details)
- Sender and inbox ops (list connected senders, attach/detach from campaigns, get per-sender config)
- Blocklist ops (email-level and domain-level CRUD, including bulk operations)
- Tag ops (CRUD on campaign and lead tags)
- Webhook configuration (for non-OutboundSync consumers only)
- Schedule template CRUD (reusable send-window definitions)
- Variable management (custom merge fields)
- Quick stats lookups (pass-through `get_campaign_stats` / `get_workspace_stats`)

**Hands off to:**

| Sibling skill | Trigger phrases | Why |
|---|---|---|
| `campaign-orchestration` (BC-2718) | "design a sequence", "sequence steps", "inbox rotation strategy", "warmup schedule", "how many touches", "content variants" | Campaign design depth — step timing, A/B content, domain-spread planning. |
| `reply-processing` (BC-2720) | "classify replies", "positive reply", "negative reply", "OutboundSync", "inbox triage", "interested lead handoff", "CRM sync" | Reply classification + CRM writeback live there. |
| `deliverability-audit` (BC-2719) | "deliverability audit", "SPF", "DKIM", "DMARC", "domain reputation", "bounce rate", "Google Postmaster", "spam folder" | Domain-level health diagnostics. |

**Does not own:**

- Sequence design depth → `campaign-orchestration`
- Reply triage rules or CRM sync → `reply-processing`
- Deliverability diagnostics → `deliverability-audit`
- Full campaign analytics (beyond quick stats) → `campaign-analysis` (BC-2721)
- Lead enrichment or prospect-list building → `list-building` (BC-2717)

If a user request spans this skill's domain and a sibling's, confirm the workspace here, then route to the sibling with the workspace context carried forward.

---

## MCP Tool Reference

Grouped by workflow, not by server — the skill picks `emailbison-b2b` or `emailbison-personal` after the workspace check, and the server prefix is implied. Tool names below are bare semantic names; the `allowed-tools` frontmatter establishes the server prefix. See `plugins/marketing/tools/integrations/email-bison.md` §Tool inventory for the canonical 141-tool catalog and §Common workflows for end-to-end recipes.

**Every mutating workflow starts with `get_active_workspace_info`** as the availability probe per ADR 2c. On failure, stop and report the server name plus a suggestion to check credentials (point to `/marketing:setup-email-bison`).

### Workflow 1: Verify or switch the active workspace

Use before any mutating call or as a standalone "am I pointing at the right place" check.

1. Call `get_active_workspace_info` on the server you intend to mutate.
2. Compare the returned `workspace_id` against the expected (55 for b2b, 13 for personal). If mismatched, call `set_active_workspace` with the intended workspace ID.
3. If the user hasn't named the workspace yet, ask them — do not default silently.

### Workflow 2: Rotate or attach sender inboxes

1. Availability check — `get_active_workspace_info`. On failure, stop.
2. `list_sender_emails` with `status: "connected"`. Filter out any in warmup ramp under day-14. Cache this result — it is the "before" state.
3. For a campaign rotate: `detach_sender_emails_from_campaign` with the IDs being pulled, then `attach_sender_emails_to_campaign` with the new set.
4. Report the before/after sender IDs and daily-cap totals from the cached step-2 result and the intended new set. Do not re-call `list_sender_emails` — the attach response and the step-2 cache are sufficient.

### Workflow 3: Add to the blocklist (email-level)

1. Availability check — `get_active_workspace_info`.
2. Call `add_email_to_blocklist` with the email address. If the list is large, batch via `bulk_add_to_blocklist` — check `email-bison.md` §Rate limits or call `discover_tools` for the vendor-documented per-call cap before sending; do not assume 500.
3. Verify via the blocklist category's read tool (run `discover_tools` in the `blocklist` category once to pin the canonical read-tool name; it is not explicitly enumerated in the current `email-bison.md` §Tool inventory). Report count added.

### Workflow 4: Remove from the blocklist — **MCP confirmation gate**

The `remove_email_from_blocklist` and `remove_domain_from_blocklist` tools are gated by the vendor MCP. Two-call pattern required:

1. Availability check — `get_active_workspace_info`.
2. **First call (no confirmation parameter):** `remove_email_from_blocklist` with the target email. The MCP returns a confirmation prompt describing what will happen ("Un-blocks an email that was explicitly suppressed").
3. Relay the prompt verbatim to the user. Do not paraphrase, do not summarize, do not auto-confirm.
4. The user responds. If the response is clear affirmative consent scoped to this operation ("yes", "approved", "go ahead", "proceed", "do it"), make the **second call** with the confirmation parameter set. If the response is ambiguous ("maybe", "what are my options", silence, or a response that doesn't address the operation), stop and re-ask with clearer context. The anti-pattern this gate blocks is the skill issuing both calls in the same turn without a real user response between them — not the wording of the affirmative.
5. Report the result and the audit trail (who approved, when, which entry).

The same pattern applies to every gated tool listed in `email-bison.md` §MCP confirmation gates (currently 8 tools; that table is the single source of truth and will grow as the vendor adds gates).

### Workflow 5: Tag CRUD on leads or campaigns

1. Availability check — `get_active_workspace_info`.
2. `list_tags` to find existing tags; `create_tag` if the label doesn't exist yet.
3. `attach_tag_to_lead` / `attach_tag_to_campaign` with IDs.
4. Verify via the relevant list tool.

### Workflow 6: Webhook subscription management (non-OutboundSync)

1. Availability check — `get_active_workspace_info`.
2. Confirm the consumer is NOT OutboundSync (OutboundSync owns the CRM-sync webhooks; see Architectural rules).
3. `list_webhooks` to see existing subscriptions.
4. `create_webhook` or `update_webhook` with the target URL and event selection.
5. `test_webhook` (if available) to emit a test payload.

### Workflow 7: Schedule template + variable ops

1. Availability check — `get_active_workspace_info`.
2. Templates: `list_schedule_templates`, `create_schedule_template`, `update_schedule_template` for reusable send-window definitions.
3. Variables: `list_custom_variables`, `create_custom_variable` for merge-field support.
4. No MCP gate on these — they're configuration, not send-triggering.

### Workflow 8: Quick stats pass-through

1. Availability check — `get_active_workspace_info`.
2. `get_campaign_stats` for a campaign's current counters.
3. `get_workspace_stats` for workspace-level rollups.
4. If the user asks for trend analysis, A/B variant comparison, or reply-quality breakdown, hand off to `campaign-analysis`.

---

## Operational Runbook

Complete procedures for the long-tail ops that do not route to a sibling skill. Each task states preconditions, steps (referencing Workflow N above), expected output, error handling, and any handoff condition.

### Task 1: Block an email domain across both workspaces

**Preconditions:**

- User has a concrete domain to block (e.g. competitor domain, abusive sender).
- User is aware this applies independently per workspace — b2b and personal maintain separate blocklists.

**Steps:**

1. Confirm with user: "Block this domain on b2b, personal, or both?"
2. For each selected workspace, run Workflow 1 (verify/switch).
3. Run Workflow 3, substituting `add_domain_to_blocklist` for `add_email_to_blocklist` in step 2 and the blocklist category's domain-level read tool for the email-level verify call in step 3 (run `discover_tools` in the `blocklist` category to pin the canonical domain-level read-tool name).
4. Report count added per workspace.

**Expected output:** bullet list per workspace with the domain blocked and the timestamp.

**Error handling:**

- Availability check failure → stop, name the server that failed, suggest `/marketing:setup-email-bison`.
- Vendor returns "already blocked" → report as success (idempotent).

**Handoff:** if the user asks about deliverability impact or domain reputation, offer to hand off to `deliverability-audit`.

### Task 2: Rotate senders on a live campaign

**Preconditions:**

- Campaign ID is known.
- At least 3 connected sender emails are past warmup day 14.

**Steps:**

1. Run Workflow 1 for the campaign's workspace.
2. Run Workflow 2 end-to-end.
3. Pause for user review of the proposed before/after sender list before the detach/attach calls.

**Expected output:** table of senders attached to the campaign, their daily cap, warmup age, and last-send timestamp.

**Error handling:**

- If fewer than 3 past-day-14 senders are available, warn and offer to hand off to `campaign-orchestration` for a warmup plan.

**Handoff:** `campaign-orchestration` for sequence-design implications of a large rotation; `deliverability-audit` if recent bounce rate is the reason for the rotation.

### Task 3: Register a Slack-alert webhook for a campaign milestone

**Preconditions:**

- User has a Slack incoming-webhook URL.
- The webhook consumer is NOT OutboundSync (OutboundSync owns the canonical CRM-sync path — see Architectural rules).

**Steps:**

1. Run Workflow 1 for the target workspace.
2. Run Workflow 6.
3. If `test_webhook` is available, fire a test event and ask the user to confirm receipt in Slack.

**Expected output:** webhook ID, target URL (masked), event filter, last-test timestamp.

**Error handling:**

- If the user's URL looks like an OutboundSync endpoint, stop and warn about the double-subscription gotcha (`email-bison.md` §Known gotchas bullet 4).

**Handoff:** none — this is a local ops task.

### Task 4: Create a reusable schedule template for a campaign type

**Preconditions:**

- User has a send-window policy in mind (e.g. "Tue–Thu 8am–5pm local").

**Steps:**

1. Run Workflow 1.
2. Run Workflow 7 (templates branch).
3. Report from the `create_schedule_template` response (which returns the created template with `days`, `start_time`, `end_time`) — do not re-list.

**Expected output:** template ID, days, window, timezone, and a human-readable summary.

**Error handling:**

- Vendor rejects overlapping windows → surface the error and ask the user to refine.

**Handoff:** `campaign-orchestration` if the user wants to apply this template to an in-flight campaign as part of a broader sequence redesign.

### Task 5: Manage custom variables for merge fields

**Preconditions:**

- User knows the variable name(s) they want (e.g. `HOOK`, `SITUATION`, `ICP_SEGMENT`).
- If the variable will carry PII beyond what's already in lead records, confirm with user — this skill does not own PII policy.

**Steps:**

1. Run Workflow 1.
2. Run Workflow 7 (variables branch).
3. Report from the `create_custom_variable` response — do not re-list.

**Expected output:** variable name, ID, associated default, and a reminder that leads must carry the variable value before a sequence references it (see `email-bison.md` §Common workflows prerequisite note).

**Error handling:**

- Variable name collision with a built-in merge field → surface the error and propose a rename.

**Handoff:** `campaign-orchestration` if the user wants to wire these into a sequence design.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | Confirms target workspace (b2b vs personal) before any mutating call; every mutating workflow starts with `get_active_workspace_info`; gated tools use the two-call confirmation pattern verbatim; routes to the correct sibling skill with explicit handoff context (workspace, user intent); cites `email-bison.md` sections for tool-inventory claims; respects the "OutboundSync owns webhooks for CRM sync" rule. |
| 7-9 | Workspace confirmation happens but disambiguation logic is weaker than the b2b-vs-personal decision tree in §2; one or two gated tools use a single-call shortcut ("I confirmed on the user's behalf") instead of the two-call pattern; routing happens but without carrying workspace context forward. |
| 4-6 | Calls MCP tools without an availability check; names tools that aren't in the 141-tool surface (e.g. "I'll use `get_lead_activity`" when that's not an actual tool); confuses which sibling owns which concern; references Brite stack but not the ADRs that decided it. |
| 1-3 | Auto-confirms a gated tool ("Done — I unblocked that address"); references Smartlead, Instantly, or Apollo as interchangeable sequencers; subscribes to Email Bison webhooks for CRM syncing; leaks b2b contacts into a personal workspace or vice versa; fabricates an Email Bison tool name or API path. |

---

## Anti-Slop Guardrails

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).
- **Do not auto-confirm MCP confirmation gates.** Every gated tool requires two calls with explicit user approval between them; relay the vendor prompt verbatim.
- **Do not call a mutating MCP tool without `get_active_workspace_info` first.** The availability check is the ADR 2c contract; skipping it is the most common way a skill mutates the wrong workspace.
- **Do not reference Smartlead, Instantly, or Apollo as sequencers this skill calls** — Email Bison is Brite's sole sequencer per ADR 2a.
- **Do not subscribe to Email Bison webhooks for CRM synchronization** — that's OutboundSync's job; double-subscribing creates dedup headaches.
- **Do not invent tool names.** If a tool isn't in `plugins/marketing/tools/integrations/email-bison.md` §Tool inventory, run `discover_tools` live; do not guess from naming patterns.

---

## Behavioral Tests

Structured eval scenarios with assertions and expected outputs are in `evals/evals.json`. This section defines quick-check assertions for inline validation.

### Tier 1 — Free assertions

- Given a request to mutate (block an email, rotate senders, create a webhook), output must identify the target workspace (b2b or personal) before the first MCP call.
- Given a request that clearly belongs to a sibling skill ("design a 5-step sequence with A/B content"), output must name the sibling and hand off rather than attempting the work inline.
- Output must not contain the strings "Smartlead", "Instantly", or "Apollo" as sequencer recommendations.
- Given any tool listed in `email-bison.md` §MCP confirmation gates, output must describe the two-call pattern and relay the vendor's confirmation prompt — not auto-confirm.
- Output must reference `plugins/marketing/tools/integrations/email-bison.md` when describing tool categories, workspace auth, or common workflows — not duplicate that content inline.
- Given a webhook-creation request with a target URL that pattern-matches OutboundSync, output must warn about the double-subscription gotcha before proceeding.

### Tier 2 — Tool-assisted

- If `docs/marketing-context.md` exists, output must reference brand context (ICP, Brite entity, voice) from that file when the request implies audience segmentation.
- Given a request to check active workspace, output must call `get_active_workspace_info` (not list_workspaces or get_account_details) and report the returned `workspace_id`.
- Given a request to block a domain on both workspaces, output must run `get_active_workspace_info` twice (once per server) and report per-workspace confirmation — not assume a single call covers both.
