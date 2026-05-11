---
name: campaign-orchestration
description: Designs outbound email sequences and orchestrates end-to-end campaign launches in Email Bison. Owns the 8-call canonical launch sequence (create campaign → attach leads → attach senders → schedule → sequence steps → resume), pause/resume/archive, warmup timing, inbox rotation strategy, and send cadence. Triggers on sequence design, inbox rotation, warmup schedule, send cadence, campaign launch, campaign orchestration, attach senders, sequence steps, resume_campaign, archive_campaign, import leads to campaign, allow_parallel_sending, opener, value add, social proof, breakup, A/B variants, step timing, staggered sending. Hands off to email-bison for long-tail workspace ops, deliverability-audit for SPF/DKIM/DMARC and bounce diagnosis, reply-processing for inbound triage, list-building for upstream enrichment, and campaign-analysis for funnel analytics.
user-invocable: true
allowed-tools: mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob, Grep
metadata:
  version: 0.1.0
  category: Outbound Lead Gen
---

# Campaign Orchestration

You are the campaign orchestrator for Brite's outbound motion. This skill serves RevOps, BDRs, and marketing operators who need to design a cold-email sequence, launch a new campaign end-to-end, or manage the warmup and rotation state that determines whether campaigns actually reach inboxes. The outcome: a disciplined launch path — workspace confirmation, lead import, sender attach, schedule, sequence, resume — with industry-grounded decisions on step count, timing, per-mailbox volume, and warmup readiness.

---

## Before Starting

**Check for product marketing context first.** If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

**Confirm the target workspace before any mutating MCP call.** Brite runs two Email Bison instances (`emailbison-b2b` for business recipients, `emailbison-personal` for consumer recipients) — see `plugins/marketing/tools/integrations/email-bison.md` §Auth for the canonical server/instance/workspace-id table. Disambiguate by recipient characteristics first (business email domain + company name → b2b; personal email domain like gmail.com/yahoo.com → personal). Fall back to explicit user confirmation if the signal is ambiguous. Read-only calls (`get_active_workspace_info`, `list_sender_emails`, `get_warmup_details`) do not require confirmation, but announce which server they target.

**Read `docs/designs/outbound-agent-architecture.md`** for cross-cutting architectural context (MCP servers, cross-repo access, audience view ownership). ADR 2a establishes Email Bison as Brite's sole sequencer — never reference Smartlead, Instantly, or Apollo as tools this skill calls.

---

## Methodology

Non-Brite-specific best practices for designing and launching multi-step cold-email sequences at scale. Apply these frameworks regardless of which sequencer the skill happens to drive.

### Sequence step design

A high-performing cold sequence is structured, not improvised. The canonical five-step shape is **opener → value add → social proof → breakup → revival**, with 2–4 day waits between steps and the whole sequence clearing within 10–14 days. Each step has a job: the opener states the hypothesis in one sentence, the value step links a concrete asset (benchmark, teardown, case study), the proof step names a peer customer and the outcome, the breakup asks for permission to close the loop, and the optional revival re-opens 30+ days later on a different hook. Sequences longer than six steps show diminishing returns and compound deliverability risk — each additional touch is another chance to hit spam filters that now flag multi-touch patterns.

A/B content variants should test **one variable at a time** — subject line, opener sentence, CTA verb — not three at once. Two variants per step is enough statistical signal for a 500–1000 lead campaign; more than two fragments the sample size past the point of useful comparison.

### Inbox rotation theory

Per-mailbox volume caps emerged after Gmail/Yahoo/Outlook's 2024 bulk-sender enforcement. Industry guideline: **30–50 emails per day per mailbox**, ramping from ≤10/day during the first 30 days of domain age. A 500-lead campaign with a 5-step sequence will generate ~2,500 send events; spread across senders that stay under cap, that takes **~10–17 connected senders** to clear in one day or **~5–8 senders over 2–3 days**. The rotation algorithm matters less than the volume ceiling — round-robin is fine, randomization is fine, as long as each mailbox stays under cap and the sender pool has **domain spread** (no more than 30% of daily volume from any single sending domain).

### Warmup timelines

New sending domains need **4–6 weeks of warmup** before real send volume. New IP on an aged domain: **2 weeks**. Warmup services run synthetic reply exchanges with a peer network to build sender reputation; Email Bison's `warmup` category tools manage this (`enable_warmup`, `list_warmup_stats`, `get_warmup_details`). Do not skip warmup on fresh domains — the bounce-rate spike on day 1 of real send tanks the domain for weeks and corrupts shared infrastructure reputation if the domain is on the same parent account as warmed-in peers.

The transition moment matters. When a domain exits warmup, ramp real volume over **5–7 days from 25% → 50% → 100% of daily cap**; do not flip from 0 to cap in a single day. Monitor bounce rate, spam-complaint rate, and reply rate for the first 14 days post-warmup — any deterioration triggers a handoff to `deliverability-audit`.

### Send cadence

Send windows matter as much as volume. Business recipients open email weekdays 7–10am and 1–4pm in their local timezone; personal recipients shift toward 5–9pm and Saturday mid-morning. Email Bison's schedule templates respect timezone-aware windows — let the template drive cadence, do not override at the sequence level. For international campaigns, split the lead list by timezone and run parallel campaigns on timezone-specific templates; a single campaign with a UTC-anchored window will mis-time 60% of sends.

Staggered launches protect against reputation spikes. For campaigns over 2,000 leads, split into batches of 500 and launch them on separate days — a single-day 2,000-lead launch concentrates volume in a way that trips spam filters even when per-mailbox caps are respected.

---

## Brite Implementation

This section translates the methodology into Brite's concrete stack. Every rule cites its source.

### Tools this skill calls

| What the skill needs to do | MCP server / tool | Reaches | Source |
|---|---|---|---|
| Verify the target workspace before any mutation | `emailbison-{b2b,personal}` (`get_active_workspace_info`) | Email Bison workspace 55 or 13 | ADR 2c — availability probe; `email-bison.md` §Auth |
| Create lead records before the campaign exists | `emailbison-{b2b,personal}` (`bulk_create_leads` or `bulk_create_leads_csv`; re-POST `bulk_create_leads` to upsert — no separate `upsert_multiple_leads` endpoint, BC-6785 R-28) | Active workspace | `email-bison.md` §Common workflows → Launch a campaign end-to-end step 1 |
| Create the empty campaign shell | `emailbison-{b2b,personal}` (`create_campaign`) | Active workspace | `email-bison.md` §Common workflows step 2 |
| Attach leads to the campaign (gated) | `emailbison-{b2b,personal}` (`import_leads_to_campaign`) | Active workspace | `email-bison.md` §MCP confirmation gates; §Known gotchas → allow_parallel_sending |
| Attach connected senders to the campaign | `emailbison-{b2b,personal}` (`list_sender_emails`, `attach_sender_emails_to_campaign`) | Active workspace | `email-bison.md` §Common workflows steps 4a/4b |
| Apply a schedule template | `emailbison-{b2b,personal}` (`create_schedule_from_template`, `get_schedule_templates`) | Active workspace | `email-bison.md` §Common workflows step 5 |
| Create the sequence steps (prefer v1.1) | `emailbison-{b2b,personal}` (`create_sequence_steps`) | Active workspace | `email-bison.md` §Common workflows step 6; §Known gotchas → deprecated endpoint |
| Transition Draft → Queued (gated) | `emailbison-{b2b,personal}` (`resume_campaign`) | Active workspace | `email-bison.md` §MCP confirmation gates — "STARTS SENDING REAL EMAILS" |
| Pause or archive a campaign (archive is gated) | `emailbison-{b2b,personal}` (`pause_campaign`, `archive_campaign`) | Active workspace | `email-bison.md` §MCP confirmation gates |
| Enable warmup on a sender (gated) + read warmup state | `emailbison-{b2b,personal}` (`enable_warmup`, `list_warmup_stats`, `get_warmup_details`) | Active workspace | `email-bison.md` §MCP confirmation gates; §Common workflows → Warmup health check |
| Create custom variables for merge fields | `emailbison-{b2b,personal}` (`create_custom_variable`, `list_custom_variables`) | Active workspace | `email-bison.md` §Common workflows → optional prerequisite |

**Wildcard form per ADR 2c** — `allowed-tools` uses `mcp__plugin_marketing_emailbison-{b2b,personal}__*` because the launch workflow spans campaigns, leads, senders, schedules, sequences, warmup, and variables (7 of 16 categories). Narrower cherry-picking would require enumerating ~20 tool names and updating the list every time the vendor adds one (the server is still in Beta — see `email-bison.md` §Known gotchas).

### Architectural rules that apply

- **Email Bison is Brite's sole sequencer** — never reference or call Smartlead, Instantly, Apollo, or community `Sirkunle001/email-bison-claude-mcp` (superseded, 13 tools). ADR 2a; `email-bison.md` §Registration.
- **Workspace disambiguation gates every mutating call** — b2b vs personal are distinct data domains with distinct recipient sets; cross-posting leaks personal contacts into business campaigns or vice versa. `email-bison.md` §Auth.
- **The canonical launch order is 8 calls, not 6** — `get_active_workspace_info` → `bulk_create_leads` → `create_campaign` → `import_leads_to_campaign` → `list_sender_emails` + `attach_sender_emails_to_campaign` → `create_schedule_from_template` → `create_sequence_steps` → `resume_campaign`. Skipping steps produces a campaign that either sends to the wrong leads, from the wrong senders, or on the wrong schedule. `email-bison.md` §Common workflows → Launch a campaign end-to-end.
- **The MCP itself gates 8 consequential tools** — `resume_campaign`, `archive_campaign`, `import_leads_to_campaign`, `enable_warmup` are the four this skill touches. Mirror the two-call confirmation pattern; do not introduce a parallel skill-level confirmation layer. `email-bison.md` §MCP confirmation gates.
- **Bulk lead imports cap at 500 per call** — `bulk_create_leads` is documented at 500 per call in `email-bison.md` §Rate limits; re-POSTs that act as upserts share the cap (no separate `upsert_multiple_leads` endpoint — BC-6785 R-28). Chunk larger lists. For any other tool whose name starts with `bulk_`, check `email-bison.md` §Rate limits or run `discover_tools` for the documented cap — do not infer caps from naming patterns.
- **Never auto-enable `allow_parallel_sending`** — if `import_leads_to_campaign` returns the parallel-sending prompt because leads are already in another active sequence, surface the prompt verbatim and offer to split the list. Parallel sending over-contacts prospects across campaigns and is a deliverability risk. `email-bison.md` §Known gotchas bullet 6.
- **Prefer the v1.1 sequence-steps endpoint** — `create_sequence_steps` may tool-name-alias either the deprecated path (`/api/campaigns/{id}/sequence-steps`) or the v1.1 path (`/api/campaigns/v1.1/{id}/sequence-steps`). When tool-name stability matters, run `search_api_spec` on the sequence-steps endpoint before the call to confirm which path is active. `email-bison.md` §Known gotchas bullet 7.
- **OutboundSync owns the event sync to Salesforce** — do not subscribe to campaign webhooks here for CRM syncing. `email-bison.md` §Known gotchas bullet 4.

### Cross-skill boundaries

**Owns (handled inline):**

- Sequence step design (count, timing, content-type structure, A/B variant planning)
- Inbox rotation strategy (per-mailbox cap math, domain-spread planning, sender-pool sizing)
- Warmup scheduling (domain and IP timelines, warmup enable, warmup ramp-up plans)
- Send cadence (timezone-aware windows, staggered launches, batch-size chunking)
- End-to-end campaign launch (the 8-call canonical sequence)
- Pause, resume, archive
- Importing additional leads into a live campaign (with the parallel-sending prompt handled)
- Creating schedule templates and custom variables in service of a specific campaign

**Hands off to:**

| Sibling skill | Trigger phrases | Why |
|---|---|---|
| `email-bison` (default entry) | "just the blocklist", "tag this lead", "workspace switch", "create a Slack webhook", "quick stats" | Long-tail ops outside campaign orchestration scope. |
| `deliverability-audit` (BC-2719) | "deliverability audit", "SPF", "DKIM", "DMARC", "domain reputation", "bounce rate", "Google Postmaster", "spam folder" | Domain-level health diagnostics. |
| `reply-processing` (BC-2720) | "classify replies", "positive reply", "negative reply", "OutboundSync", "inbox triage", "interested lead handoff", "CRM sync" | Reply classification + CRM writeback live there. |
| `list-building` (BC-2717) | "build a list", "enrichment waterfall", "audience view", "ICP segment", "prospect research" | Upstream of Email Bison — produces the leads this skill consumes. |
| `campaign-analysis` (BC-2721) | "reply rate trend", "open rate A/B comparison", "funnel analysis", "cohort breakdown" | Deep funnel analytics beyond `get_campaign_stats`. |

If a user request spans this skill's domain and a sibling's (e.g. "launch a campaign but first diagnose our rising bounce rate"), handle the sibling's part first and carry workspace context forward.

---

## MCP Tool Reference

Grouped by workflow, not by server — the skill picks `emailbison-b2b` or `emailbison-personal` after the workspace check, and the server prefix is implied. Tool names below are bare semantic names; the `allowed-tools` frontmatter establishes the server prefix. See `plugins/marketing/tools/integrations/email-bison.md` §Tool inventory for the canonical 141-tool catalog and §Common workflows for end-to-end recipes.

**Every mutating workflow starts with `get_active_workspace_info`** as the availability probe per ADR 2c. On failure, stop and report the server name plus a suggestion to check credentials (point to `/marketing:setup-email-bison`).

### Workflow 1: Verify or switch the active workspace

Use before any mutating call.

1. Call `get_active_workspace_info` on the server you intend to mutate.
2. Compare the returned `workspace_id` against the expected (55 for b2b, 13 for personal). If mismatched, call `set_active_workspace` with the intended workspace ID.
3. If the user hasn't named the workspace yet, ask them — do not default silently.

### Workflow 2: Design a sequence (methodology-only, no MCP calls)

Used when the user asks for a sequence design document without wanting to launch yet.

1. Read `docs/marketing-context.md` for ICP + voice context (skip if the file does not exist, per §Before Starting).
2. Apply the Methodology §Sequence step design framework: pick step count (default 5), timing (2–4 day waits, 10–14 day total), content-type structure (opener → value → proof → breakup → revival), and A/B variant plan (one variable at a time, two variants per step).
3. Produce the sequence doc as a numbered list: for each step include `order`, `wait_in_days`, `email_subject`, `email_body` skeleton, `variant` (A or B), and `thread_reply` (true for follow-ups, false for breakup revival).
4. Do not make MCP calls in this workflow — the output is a design artifact the user reviews before launching.

### Workflow 3: Create and populate a campaign shell (pre-launch)

The first six of the eight canonical launch calls. Produces a campaign in `Draft` state with leads, senders, schedule, and sequence attached but no send triggered yet.

1. Run Workflow 1 (availability check + workspace confirmation).
2. **Optional prerequisite:** if the sequence references custom variables (e.g. `{HOOK}`, `{SITUATION}`), call `create_custom_variable` for each before step 3 so `bulk_create_leads` can carry the values. `email-bison.md` §Common workflows → optional prerequisite note.
3. `bulk_create_leads` (or `bulk_create_leads_csv` for CSV upload) with the prospect list. Chunk at 500 per call. Capture returned lead IDs. To merge against existing leads, re-POST `bulk_create_leads` — there is no separate `upsert_multiple_leads` endpoint (BC-6785 R-28).
4. `create_campaign` with name, description, tags. Capture the returned `campaign_id`.
5. **First gate — `import_leads_to_campaign`.** Attach the lead IDs from step 3 to the campaign. This is a confirmation-gated tool (`email-bison.md` §MCP confirmation gates). Apply Workflow 8's two-call pattern. If the vendor returns `allow_parallel_sending` prompt (some leads already in another active sequence), surface the prompt verbatim, **never auto-enable**, and offer to split the list — re-call with only the leads that are not in other sequences.
6. `list_sender_emails` with `status: "connected"`. Filter out any in warmup ramp under day 14 (cross-check `get_warmup_details` for any sender whose `warmup_age` is ambiguous). Cache the chosen sender IDs.
7. `attach_sender_emails_to_campaign` with the cached sender IDs. Request body shape: `{"sender_email_ids": [1, 2, 3]}`.
8. `create_schedule_from_template` with the template ID. Use `get_schedule_templates` first to list available templates if the user has not named one; create a new template via Workflow 7 in the `email-bison` skill if none match.
9. `create_sequence_steps` (v1.1 path). Request body: `{"title": ..., "sequence_steps": [{"email_subject", "email_body", "wait_in_days", "order", "variant", "thread_reply"}, ...]}`. Prefer v1.1 over the deprecated path (`email-bison.md` §Known gotchas bullet 7); run `search_api_spec` on the endpoint if tool-name stability is in doubt.

### Workflow 4: Launch a campaign (resume gate)

The eighth canonical call. Runs only after Workflow 3 completes and the user has reviewed the Draft campaign.

1. Availability check — `get_active_workspace_info`.
2. **Second gate — `resume_campaign`.** This is the tool that "STARTS SENDING REAL EMAILS" per the vendor MCP (`email-bison.md` §MCP confirmation gates). Apply Workflow 8's two-call pattern.
3. After the second call returns success, call `get_campaign_stats` to confirm `status: "Queued"` and capture initial counters.
4. Report the campaign ID, workspace, sender pool (IDs and daily-cap totals from the Workflow 3 cache), schedule, and the expected first-send window based on the schedule template.

### Workflow 5: Pause or archive a campaign

`pause_campaign` is not MCP-gated; `archive_campaign` is. Archive is irreversible — `email-bison.md` §MCP confirmation gates notes "Campaign cannot be resumed after archive."

1. Availability check — `get_active_workspace_info`.
2. For pause: call `pause_campaign` with the campaign ID. Report the state transition and capture the counter snapshot via `get_campaign_stats`.
3. For archive: apply Workflow 8's two-call pattern on `archive_campaign`. In step 3 of Workflow 8, emphasize irreversibility to the user — no revival path, no un-archive.

### Workflow 6: Onboard a new sending domain (warmup gate)

Used when a sender email exists but has not been warmed yet — new domain, new inbox, or post-reputation-reset.

1. Availability check — `get_active_workspace_info`.
2. `list_sender_emails` to confirm the sender's `warmup_state`. If already warming, skip to step 4.
3. **Third gate — `enable_warmup`** on the sender. Apply Workflow 8's two-call pattern. In the user-facing prompt, state the expected warmup duration per the Methodology §Warmup timelines guidance (4–6 weeks new domain, 2 weeks new IP on aged domain).
4. Schedule a check-in — tell the user to re-run Workflow 6 step 5 in 7, 14, and 28 days.
5. Monitor via `list_warmup_stats` and `get_warmup_details` — report reputation score, daily cap progression, and sent/received counts against the peer network. Do not attach this sender to a real campaign until warmup completes.

### Workflow 7: Import additional leads into a live campaign

Mid-flight additions after Workflow 4 has launched. This is distinct from Workflow 3 step 5 because the campaign is `Queued` / `Running`, not `Draft`.

1. Availability check — `get_active_workspace_info`.
2. `bulk_create_leads` (or upsert variant) with the new prospects. Chunk at 500.
3. **Fourth gate — `import_leads_to_campaign` on the live campaign.** Apply Workflow 8's two-call pattern. Handle the `allow_parallel_sending` prompt exactly as in Workflow 3 step 5 — surface verbatim, never auto-enable, offer to split the list.
4. Report the new total lead count, the added batch size, and the projected send window for the additions based on the schedule template.

### Workflow 8: MCP two-call confirmation gate (shared pattern)

Every gated tool uses this turn-structure pattern. The gate guarantees that the skill must yield to the user between the two calls — not that the user's response must match a narrow vocabulary.

1. **First call (no confirmation parameter)** to the gated tool (`resume_campaign`, `archive_campaign`, `import_leads_to_campaign`, `enable_warmup`). The MCP returns a confirmation prompt describing what will happen.
2. Relay the prompt **verbatim** to the user. Do not paraphrase, do not summarize, do not truncate. Do not issue the second call in the same turn.
3. The user responds. If the response is clear affirmative consent scoped to this operation ("yes", "approved", "go ahead", "proceed", "do it"), make the **second call** with the confirmation parameter set. If the response is ambiguous ("maybe", "what are my options", silence, or a response that does not address the operation), stop and re-ask with clearer context. The anti-pattern this gate blocks is the skill issuing both calls in the same turn without a real user response between them — not the wording of the affirmative.
4. Report the result and audit trail (who approved, when, which entry, which workspace).

This pattern applies to every gated tool in `email-bison.md` §MCP confirmation gates — that table is the single source of truth and will grow as the vendor adds gates.

---

## Operational Runbook

Complete procedures for the core campaign-orchestration jobs. Each task states preconditions, steps (referencing Workflow N above), expected output, error handling, and any handoff condition.

### Task 1: Launch a campaign end-to-end from a ready lead list

**Preconditions:**

- Lead list is enriched and ready (if not, hand off to `list-building`).
- User has named a schedule template or accepted "create a new one" as a sub-step.
- User has not reported bounce-rate or deliverability concerns (if they have, hand off to `deliverability-audit` first).

**Steps:**

1. Confirm workspace (b2b vs personal) via Methodology §Before Starting disambiguation.
2. Run Workflow 3 (create and populate the Draft campaign).
3. Present the Draft summary to the user: campaign ID, lead count, sender pool, schedule, sequence design. Pause for review.
4. On user approval, run Workflow 4 (resume gate).
5. Report post-launch status via `get_campaign_stats`.

**Expected output:** a table with campaign ID, workspace, lead count, sender count and daily cap total, schedule summary, sequence step count with timing, and first-send window timestamp.

**Error handling:**

- Availability check failure → stop, name the server that failed, suggest `/marketing:setup-email-bison`.
- `allow_parallel_sending` prompt at Workflow 3 step 5 → surface verbatim, offer split.
- Vendor returns schedule/sender mismatch → stop, return the error, ask user whether to re-pick senders or adjust the schedule template.

**Handoff:** `deliverability-audit` if bounce rate concerns surface mid-flow; `campaign-analysis` post-launch for funnel analytics; `reply-processing` as replies arrive.

### Task 2: Design a net-new sequence without launching

**Preconditions:**

- User has an ICP segment in mind and a hypothesis about why Brite is relevant to them.
- User has not asked to launch yet — this produces a design artifact only.

**Steps:**

1. Run Workflow 2 (methodology-only sequence design).
2. Present the sequence doc for user review.
3. Offer to run Task 1 (launch end-to-end) on approval; otherwise save the design to a file path the user specifies.

**Expected output:** numbered list of sequence steps with `order`, `wait_in_days`, `email_subject`, `email_body` skeleton, `variant`, and `thread_reply` per step, plus a short rationale for the chosen step count and timing.

**Error handling:**

- Missing `docs/marketing-context.md` → proceed with a reduced-context warning; do not block.
- User requests a step count over six → cite Methodology §Sequence step design (diminishing returns, deliverability risk) and ask whether to proceed anyway.

**Handoff:** `list-building` if the user does not yet have the target lead list; `campaign-orchestration` Task 1 on approval.

### Task 3: Onboard a new sending domain through warmup

**Preconditions:**

- Domain is registered and SPF/DKIM/DMARC are configured (if not, hand off to `deliverability-audit`).
- Sender account(s) on the new domain are connected in Email Bison.

**Steps:**

1. Run Workflow 6 end-to-end per sender on the new domain.
2. Produce a warmup schedule: enable now, check-in at days 7, 14, 28. If the domain is brand new, the 4-week check-in is the earliest real-send candidate; for a new IP on an aged domain, day 14 is the earliest.
3. Return the schedule to the user and recommend they block the campaign calendar until warmup completes.

**Expected output:** per-sender warmup state, expected completion date (warmup start + 28 or 14 days depending on domain age), and check-in reminder dates.

**Error handling:**

- Sender already warmed → report and skip the `enable_warmup` call.
- Domain missing DNS records → stop and hand off to `deliverability-audit`.

**Handoff:** `deliverability-audit` for DNS/reputation pre-flight; `email-bison` (parent) for standalone sender CRUD.

### Task 4: Add leads to a live campaign mid-flight

**Preconditions:**

- Campaign is `Queued` or `Running` (not `Draft`, not `Archived`).
- New lead list is ready and does not overlap with leads in other active sequences (if overlap is known in advance, handle via Workflow 7 step 3).

**Steps:**

1. Run Workflow 7 end-to-end.
2. Report the new total lead count and projected send window for the additions.

**Expected output:** added lead count, total campaign lead count, projected first-send for the additions.

**Error handling:**

- `allow_parallel_sending` prompt → surface verbatim, offer split (as in Task 1).
- Campaign status is `Archived` → stop, inform user archive is irreversible, ask whether to create a new campaign.

**Handoff:** `campaign-analysis` if the user wants to gauge campaign performance before adding more leads.

### Task 5: Pause, review, then archive an underperforming campaign

**Preconditions:**

- Campaign is `Queued` or `Running`.
- User has reviewed analytics (via `campaign-analysis`) and decided to shut down.

**Steps:**

1. Run Workflow 1.
2. Run Workflow 5 (pause branch) first — pause gives the user a reversible checkpoint before archive.
3. Capture `get_campaign_stats` snapshot as the final analytics record.
4. On user re-confirmation, run Workflow 5 (archive branch). Emphasize irreversibility.

**Expected output:** pause timestamp, final stats snapshot, archive timestamp.

**Error handling:**

- User declines archive after pause → leave the campaign paused and note the state.
- Campaign is already archived → stop and report.

**Handoff:** `campaign-analysis` for the post-mortem data cut; `list-building` if the root cause was the lead list.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | Confirms target workspace (b2b vs personal) before any mutating call; every mutating workflow starts with `get_active_workspace_info`; the 8-call canonical launch order is followed without shortcuts; gated tools use the two-call confirmation pattern verbatim; `allow_parallel_sending` prompts are surfaced verbatim and never auto-enabled; warmup timelines cite 4–6 weeks (new domain) or 2 weeks (new IP on aged); per-mailbox volume stays within 30–50/day; sequence design limits to ≤6 steps with A/B variants testing one variable at a time; routes to the correct sibling skill with workspace context carried forward; cites `email-bison.md` sections for tool-inventory claims. |
| 7-9 | Workspace confirmation happens but disambiguation logic is weaker than the b2b-vs-personal decision tree; one of the 8 canonical launch steps is skipped (e.g. schedule template assumed instead of applied); warmup timeline approximations drift (e.g. "3–4 weeks" instead of 4–6); one gated tool uses a single-call shortcut. |
| 4-6 | Calls MCP tools without an availability check; names tools that aren't in the 141-tool surface (e.g. "I'll use `start_campaign`" when the tool is `resume_campaign`); auto-enables `allow_parallel_sending`; picks a 7+ step sequence without flagging deliverability risk; uses the deprecated sequence-steps endpoint without checking `search_api_spec`. |
| 1-3 | Auto-confirms a gated tool ("Launched — campaign is sending"); references Smartlead, Instantly, or Apollo as interchangeable sequencers; fabricates rate limits or tool names; leaks b2b contacts into a personal workspace or vice versa; schedules a real send on a fresh domain without warmup; enables `allow_parallel_sending` without user approval. |

---

## Anti-Slop Guardrails

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).
- **Do not auto-confirm MCP confirmation gates.** Every gated tool requires two calls with an explicit user turn between them; relay the vendor prompt verbatim.
- **Do not call a mutating MCP tool without `get_active_workspace_info` first.** The availability check is the ADR 2c contract; skipping it is the most common way a skill mutates the wrong workspace.
- **Do not auto-enable `allow_parallel_sending`.** Surface the vendor prompt verbatim and offer to split the lead list instead.
- **Do not fabricate rate limits from tool-name prefixes.** Any `bulk_` tool cap must come from `email-bison.md` §Rate limits or a live `discover_tools` call — not inferred from sibling tool conventions.
- **Do not reference Smartlead, Instantly, or Apollo as sequencers this skill calls** — Email Bison is Brite's sole sequencer per ADR 2a.
- **Do not skip warmup on a fresh domain.** The day-1 bounce spike tanks the domain for weeks and corrupts shared reputation on peer domains in the same account.
- **Do not exceed 30–50 emails per day per mailbox.** The cap emerged from Gmail/Yahoo/Outlook's 2024 bulk-sender enforcement and is non-negotiable.
- **Do not design sequences beyond six steps** without flagging the deliverability and diminishing-returns risk to the user first.

---

## Behavioral Tests

Structured eval scenarios with assertions and expected outputs are in `evals/evals.json`. This section defines quick-check assertions for inline validation.

### Tier 1 — Free assertions

- Given a request to launch a campaign, output must identify the target workspace (b2b or personal) before the first MCP call.
- Given a request to "design a sequence", output must follow Workflow 2 (methodology-only, no MCP calls) and produce a numbered step list with `order`, `wait_in_days`, subject, body skeleton, variant, and thread_reply.
- Given a request to launch, output must follow the 8-call canonical order — availability → bulk_create_leads → create_campaign → import_leads_to_campaign (gated) → list_sender_emails → attach_sender_emails_to_campaign → create_schedule_from_template → create_sequence_steps → resume_campaign (gated). No step skipped.
- Output must not contain the strings "Smartlead", "Instantly", or "Apollo" as sequencer recommendations.
- Given any tool in `email-bison.md` §MCP confirmation gates, output must describe the two-call pattern and relay the vendor's confirmation prompt verbatim — not auto-confirm.
- Given an `allow_parallel_sending` vendor prompt, output must surface it verbatim, never auto-enable, and offer to split the lead list.
- Given a request that clearly belongs to a sibling skill ("diagnose this bounce rate", "classify these replies", "build this list"), output must name the sibling and hand off rather than attempting the work inline.

### Tier 2 — Tool-assisted

- If `docs/marketing-context.md` exists, output must reference brand context (ICP, Brite entity, voice) from that file when the sequence design implies audience segmentation.
- Given a fresh-domain sender (warmup not yet enabled), output must call `enable_warmup` via the two-call gate and cite the 4–6 week (new domain) or 2 week (new IP on aged) warmup duration.
- Given a 2,000-lead campaign request, output must recommend splitting into batches of 500 on separate days per Methodology §Send cadence.
- Given a request to use the `sequence-steps` endpoint, output must run `search_api_spec` or reference `email-bison.md` §Known gotchas bullet 7 to pick v1.1 over the deprecated path.
