# Outbound Agent Architecture

**Issue:** BC-5042 (Phase 3 — design doc, skill template, findings)
**Status:** Draft — human review at PR
**Date:** 2026-04-14
**Depends on:** BC-5040 (Phase 1 research validation, PR #115), BC-5041 (Phase 2 ADRs, PR #118)
**Completes:** BC-2714 (research findings doc)
**Blocks:** BC-2717–2722 (6 outbound marketing skills: 5 Outbound Lead Gen + 1 Demand Gen)

---

## Context

Brite's outbound pipeline spans four repos and dozens of external tools:

- `britenites-claude-plugins` — this repo; skills orchestrate
- `outbound-sales-ops` — reply-processing Cloud Functions
- `brite-data-platform` — Snowflake + dbt + enrichment
- `brite-salesforce` — the CRM system of record (SoR)

Before any outbound *skill* can be authored, three questions had to be answered: which MCP servers does the plugin adopt, how do skills access data across repos, and what shape does an "outbound skill" actually take.

This document assembles the answers into a single design. It does not re-open any decision. Validated facts come from BC-5040 (read-only audit against `origin/main` of all three sibling repos + handbook). Architecture decisions come from BC-5041 (6 ADRs covering MCP adoption, custom servers, skill-to-MCP pattern, cross-repo access, audience views, and the skill template spec). This phase produces `outbound-agent-architecture.md` (this design doc), `OUTBOUND-SKILL-TEMPLATE.md` (the skill scaffold), and `outbound-pipeline-findings.md` (the promoted research doc).

---

## Validated facts

Summarized from BC-5040 §1–8 and the research findings doc. Full evidence links in [Links](#links).

**Layer 1 — List Building / Enrichment (`brite-data-platform`)** — Snowflake + dbt Cloud + Fivetran + Airbyte Cloud + custom Python pipelines (Prefect flows + Pydantic). Acquisition via Serper Places; people discovery via Apollo. Email waterfall is built: IcyPeas → Prospeo → LeadMagic (verified exact order and prices in `services/enrichment/recipes/work_email_waterfall.yml`). Verification via BounceBan (deliverability) + EmailGuard (ESP detection). Golden records (`dim_people`, `dim_companies`) in Snowflake with field-level survivorship and a 10-point `data_quality_score`. CLI is `python -m enrichment.cli` with 9 commands (not 4 as the WIP originally stated); the provider directory contains 14 real providers (not 5). Architecture rule: single-writer gold — Python writes to `RAW.PIPELINE_ENRICHMENT`, dbt writes to `dim_*` marts, Python never writes production. **Audience views are not yet built** — the first outbound skill creates them per ADR 2e.

**Layer 2 — Sending / Sequencing (Email Bison)** — Email Bison is the sole sequencer. Smartlead appears in the handbook only as a market alternative, never Brite-active. OutboundSync webhooks handle 7 event types (delivery, opens, replies, bounces, unsubscribes, plus send + reply). OutboundSync creates Salesforce *Contacts*, not Leads — a deliberate pattern (BC-2705 production audit: 6,235 Contacts, 0 Leads). Master Inbox (MI) — Email Bison's aggregated reply inbox — is the upstream of the reply-processing layer (Layer 3). Campaign loading from golden records is currently manual — this handoff is the primary pain point addressed by the `list-building` + `campaign-orchestration` skills (ADR 2e).

**Layer 3 — Reply Processing (`outbound-sales-ops`)** — TypeScript on Vercel Serverless + Supabase Postgres. MI aggregates replies across sender accounts and AI-classifies into 11 labels mapped to 8 actions (full table in `docs/architecture.md`). Three Cloud Functions: `label-sync` runs a 5-step pipeline (priority resolution, dedup, SF sync, MI routing, action side effects); `reply-notification` pushes Speed-to-Lead alerts to Slack; `message-router` handles BDR reply tracking. Six cron jobs including `validate-sf-schema` daily. Priority resolution order is strict (Suppress > Escalate > Speed-to-Lead > Redirect > Archive > Deferred > Triage > No Action). Architectural rules: no tool-to-tool writes (CFs are the only writers), single-label enforcement in MI, upgrade-only transitions on `Lifecycle_Stage__c` and `Lead_Status__c` (field-specific, not universal). BDR workflow uses 6 MI lists (Hot, Pending Action, Needs Triage, Connected, Follow-Up, Archived).

**Layer 4 — CRM (`brite-salesforce`)** — Salesforce Enterprise Edition, SFDX source-driven. HubSpot migration is **complete** (13.4K accounts, 35.8K contacts, 4.3K leads, 4.9K opportunities loaded). Three business lines: Brite Nites (holiday + exterior lighting, residential *and* commercial), Brite Labs (commercial/experiential), Brite Supply (B2B marketplace + Brite Base SaaS). Lifecycle has 12 `Lifecycle_Stage__c` values (not 8 — the 4 edge states Lost, Disqualified, Do_Not_Prospect, Subscriber matter for reply-processing). Ten Opportunity record types. Custom objects: `Territory__c`, `Lifecycle_Stage_History__c`. 13 integration endpoints including Aircall (live via CTI managed package v3).

**Layer 5 — Engagement** — Slack for alerts (#positive-replies, #system-health). Aircall is **live**; Dialpad is planned, not started (confirmed by user on 2026-04-09: "we are moving to Dialpad even though we are in Aircall right now"). Calendly for scheduling. Front for post-reply dialog (email-CC-based handoff from MI — MI adds the BDR's Front address to the reply thread). HeyReach partially active for LinkedIn outreach via Clay, but not in the reply pipeline. SMS planned via Twilio (env vars present), not implemented.

**MCP landscape** — 8 servers evaluated. Email Bison has an **official vendor-hosted MCP (Beta) at `mcp.emailbison.com/mcp` with 141 tools across 16 categories** — discovered 2026-04-10, supersedes all community Email Bison repos. Both Brite workspaces connected (`send.outbase.so` B2B, `personal.outbase.so`). Salesforce official MCP has 120+ tools across 14 toolsets. Apollo MCP has only 4 tools. Smartlead community MCP has ~112 tools but Brite has never used Smartlead. Resend has 10+ categories. No MCP exists (or will exist) for OutboundSync or Master Inbox — OutboundSync is a Brite-built webhook receiver with no external vendor, and Master Inbox is an Email Bison feature already covered by Email Bison's MCP.

---

## Decisions

Six ADRs from [`outbound-agent-architecture-adrs.md`](outbound-agent-architecture-adrs.md) (PR #118). Each section below restates the Decision line and the 2–3 sentence rationale; full alternatives analysis and review notes live in the linked ADR.

### ADR 2a — MCP server adoption

**Decision:** Adopt Email Bison (both workspaces) and Salesforce MCP servers. Defer Apollo and Resend. Skip Smartlead. `${ENV_VAR}` substitution in committed `.mcp.json`.

**Rationale:** Email Bison + Salesforce together cover the sending layer and the CRM layer — the two layers every outbound skill must touch. Together they consume 3 of the plugin's ~5–6 MCP slots (`emailbison-b2b` + `emailbison-personal` + `salesforce`; per-plugin soft cap documented in `CLAUDE.md`), leaving room for GitHub MCP (ADR 2d) and future additions. Apollo has only 4 tools and Brite uses Apollo's REST API directly in `brite-data-platform`; Resend has no current consumer; Smartlead was never a Brite tool. Deferring unused servers preserves startup latency and context budget.

See [ADR 2a](outbound-agent-architecture-adrs.md#adr-2a-mcp-server-adoption-strategy).

### ADR 2b — Custom MCP server strategy

**Decision:** Do not build custom MCP servers for OutboundSync or Master Inbox. Use existing Cloud Functions as the OutboundSync integration layer. Use the official Email Bison MCP for Master Inbox. Defer enrichment MCP ownership to `brite-data-platform`.

**Rationale:** OutboundSync is a webhook receiver, not a queryable service — wrapping it in an MCP means building a new API layer in front of existing CFs. The CFs already mediate all writes ("Cloud Functions are the only writers" — outbound-sales-ops architecture rule 2), so a skill that needs CRM sync trusts the webhook pipeline. Master Inbox is an Email Bison feature whose `list_replies`, `search_replies`, `send_reply`, and `get_replies_analytics` tools cover the read/write surface. Known limitation: skills cannot force an on-demand re-sync; the 5-minute `replay-pending` cron handles retries.

See [ADR 2b](outbound-agent-architecture-adrs.md#adr-2b-custom-mcp-server-strategy).

### ADR 2c — Skill-to-MCP orchestration pattern

**Decision:** Ratify the three-layer pattern from [`skill-tool-integration-pattern.md`](../guides/skill-tool-integration-pattern.md) (PR #116) as the architecture standard for all tool-using skills. Add a degradation policy: skills call a lightweight read-only probe (the specific tool per server is documented in that server's integration guide) as an availability check before mutating; on failure, the skill stops and reports — no fallback to `Bash(curl)` or direct API calls.

**Rationale:** The pattern was merged and validated before BC-5041 began (4 post-plan skills + 1 marketing integration guide already use it). This ADR formally blesses it and closes the one gap the guide didn't cover — what happens when a server is unreachable. Never bypassing `allowed-tools` preserves the three-layer boundary; per-server escape hatches belong in integration guides, not policy.

See [ADR 2c](outbound-agent-architecture-adrs.md#adr-2c-skill-to-mcp-orchestration-pattern).

### ADR 2d — Cross-repo agent pattern

**Decision:** Domain MCP servers for runtime data. GitHub MCP (`@modelcontextprotocol/server-github`) for cross-repo file reads. Context7 for semantic search. No local clone dependency. Never build a custom MCP just to bridge two repos.

**Rationale:** Skills need three distinct kinds of cross-repo access — structured runtime queries, specific file reads, and semantic search over docs. Each tier exists and serves a distinct need; together they eliminate the local-clone setup burden. Legacy skills using `gh api` via Bash (`handbook-drift-check`, `promote-precedent`) keep working; new skills should prefer the GitHub MCP. Register GitHub MCP in `plugins/marketing/.mcp.json` alongside the first consuming skill, bringing the plugin to 4 of ~5–6 MCP slots (3 from ADR 2a + GitHub MCP).

See [ADR 2d](outbound-agent-architecture-adrs.md#adr-2d-cross-repo-agent-pattern).

### ADR 2e — Audience view architecture

**Decision:** Reusable audience segments are dbt models in `brite-data-platform` (`audience_view_*` in `models/marts/audience_views/`). Campaign-specific prospect lists are loaded into Email Bison via MCP (`bulk_create`, 500 per chunk). Skills orchestrate the handoff. Audience views are built alongside the first consuming skill using the interface contract pattern.

**Rationale:** dbt for the *who* (governed, testable, version-controlled segments drawing from golden records); Email Bison for the *how* (runtime campaign state, sender rotation, send schedules); skills for the *when* (orchestrate the import + configuration handoff). Ad-hoc filtering is acceptable for one-off test campaigns — promote to a dbt model on the second use. Separate issues in `brite-data-platform` own audience view implementation; consuming skills are blocked by them.

See [ADR 2e](outbound-agent-architecture-adrs.md#adr-2e-audience-view-architecture).

### ADR 2f — Skill design pattern for outbound

**Decision:** Outbound skills follow a 9-section template extending the upstream marketing-skill structure. Sections 4–6 (Brite Implementation, MCP Tool Reference, Operational Runbook) are required for tool-calling skills and omitted for methodology-only upstream ports. One template, one checklist, one review agent rule.

**Rationale:** Upstream skills are methodology-only; the 6 tool-calling outbound marketing skills (5 Outbound Lead Gen + the Demand Gen `outbound-playbook`) need to orchestrate Email Bison + Salesforce + cross-repo data — the upstream shape has no place for those layers. Forking into two templates doubles the maintenance surface without improving the outcome. Extending with three clearly-marked "tool-calling skills only" sections keeps one template usable by both outbound skills (fill all 9) and upstream ports (ignore 4–6). BC-5042 produces the template file; ADR 2f is the spec.

See [ADR 2f](outbound-agent-architecture-adrs.md#adr-2f-skill-design-pattern-for-outbound).

---

## Architecture diagram

```
                              ┌─────────────────────────────────────┐
                              │  britenites-claude-plugins          │
                              │  (this repo — skills orchestrate)   │
                              │                                     │
                              │  plugins/marketing/skills/          │
                              │    list-building/                   │
                              │    campaign-orchestration/          │
                              │    deliverability-audit/            │
                              │    reply-processing/                │
                              │    campaign-analysis/               │
                              │    outbound-playbook/  ← conductor  │
                              └──────────────────┬──────────────────┘
                                                 │
                       ┌─────────────────────────┼─────────────────────────┐
                       │                         │                         │
               domain MCPs                 GitHub MCP                 Context7
               (runtime data)              (file reads)           (semantic search)
                       │                         │                         │
      ┌────────────┬───┴──┬───────────┐          │             ┌───────────┴───────────┐
      ▼            ▼      ▼           ▼          │             ▼                       ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐      │    brite-nites/handbook       sibling repos
│ EB b2b   │ │ EB pers. │ │  Salesforce  │      │    (architecture,            (dbt models,
│ send.    │ │ personal.│ │  (SOQL, CRUD,│      │     coding standards,         architecture
│ outbase  │ │ outbase  │ │   metadata,  │      │     onboarding)               docs, CLAUDE.md)
│ .so      │ │ .so      │ │   lifecycle) │      │
│ 141 tools│ │ 141 tools│ │  120+ tools  │      ▼
└──────────┘ └──────────┘ └──────────────┘  ┌─────────────────────────────────────┐
                                            │  Brite-Nites GitHub org             │
                                            │                                     │
                                            │  brite-data-platform                │
                                            │    Snowflake + dbt + Python         │
                                            │    dim_people, dim_companies,       │
                                            │    audience_view_*  (not yet built) │
                                            │    services/enrichment/cli.py       │
                                            │                                     │
                                            │  outbound-sales-ops                 │
                                            │    label-sync, reply-notification,  │
                                            │    message-router (Cloud Functions) │
                                            │    6 crons, Supabase state          │
                                            │                                     │
                                            │  brite-salesforce                   │
                                            │    SFDX source (Apex, objects,      │
                                            │    lifecycle GlobalValueSets,       │
                                            │    validation rules)                │
                                            └─────────────────────────────────────┘

Ambient sync (no skill-initiated writes below this line):

  Email Bison ──(webhook: sent/opened/replied/bounced/…)──▶ OutboundSync
                                                                 │
                                                                 ▼
                                                         label-sync CF
                                                                 │
                                                ┌────────────────┼─────────────────┐
                                                ▼                ▼                 ▼
                                          Salesforce        MI list          Email Bison
                                          (Contact +        routing          blocklist
                                          lifecycle)        (6 lists)        (on SUPPRESS)
                                                │
                                                └─▶ reply-notification CF ──▶ Slack #positive-replies
                                                                                 (Speed to Lead)
```

Key relationships:

- **Skills never call vendor APIs directly.** All external I/O goes through an MCP server declared in `allowed-tools` (ADR 2c). The only exceptions are legacy `gh api` usage in existing workflows skills.
- **Skills never assume sibling repos are cloned.** Cross-repo file reads use GitHub MCP; runtime queries use domain MCPs (ADR 2d).
- **Writes to Salesforce flow through OutboundSync CFs**, not directly from skills. A skill can *read* Salesforce via the Salesforce MCP, but any write that should propagate to Email Bison, MI, or Slack happens via the webhook pipeline (ADR 2b).
- **The dbt project is the source of truth for audience segmentation.** Skills generating ad-hoc SQL is acceptable for test campaigns; reusable segments promote to `audience_view_*` dbt models (ADR 2e).

---

## Worked end-to-end example

**Scenario:** An agent helps a BDR launch a new outbound campaign for Brite Nites targeting SMB property managers with high enrichment quality. The BDR invokes the `list-building` skill, which hands off to `campaign-orchestration` to configure sending.

This scenario exercises all four cross-repo access tiers (domain MCP, GitHub MCP, Context7, and the OutboundSync webhook pipeline as ambient infrastructure). Step numbers correspond to conversational turns. Email Bison tool names below are the authoritative names verified live via `discover_tools` + `search_api_spec` — the full campaign-launch recipe (8 MCP calls) also lives in [`plugins/marketing/tools/integrations/email-bison.md`](../../plugins/marketing/tools/integrations/email-bison.md#common-workflows) as the single source of truth for skill authors.

**Step 1 — Skill activation + context load.** BDR runs a prompt matching `list-building`'s triggers. The skill activates. Per ADR 2f §2 (Before Starting), the skill reads `docs/marketing-context.md` from the current repo to pick up Brite Nites ICP, voice, and brand context. If the file is missing, the skill warns and proceeds with reduced context.

**Step 2 — Audience view discovery.** The skill uses **GitHub MCP** (`mcp__plugin_marketing_github__get_file_contents`) to read `brite-data-platform/models/marts/audience_views/` directory listing. This is a tier-2 cross-repo access per ADR 2d — specific file reads, no local clone required. If `audience_view_smb_property_managers.sql` exists, the skill reads its column list and filter criteria. If no matching audience view exists, the skill engages the BDR in defining one (interface contract pattern, ADR 2e) and blocks campaign launch until a dbt issue is opened in `brite-data-platform`.

**Step 3 — CRM de-duplication query.** Before importing leads, the skill queries **Salesforce MCP** (`mcp__plugin_marketing_salesforce__run_soql`) for existing `Contact` records matching the segment criteria to avoid re-emailing known prospects. SOQL roughly: `SELECT Email FROM Contact WHERE Lifecycle_Stage__c IN ('Active_Customer', 'Do_Not_Prospect', 'Subscriber') AND Email != NULL`. Per ADR 2c degradation policy, the skill first calls a lightweight Salesforce metadata read as an availability check; on failure, the skill stops and reports "Salesforce MCP unreachable" — it does not fall back to `Bash(curl)`.

**Step 4 — Email Bison availability check.** Per ADR 2c, before any Email Bison mutation, the skill calls `mcp__plugin_marketing_emailbison-b2b__get_active_workspace_info` as a read-only availability probe. Success confirms the `send.outbase.so` workspace is reachable; failure stops the skill. No fallback.

**Step 5 — Create leads (chunked).** Leads must exist in Email Bison **before** the campaign is created. The skill calls `mcp__plugin_marketing_emailbison-b2b__bulk_create_leads` with lead data from the audience view, chunked at 500 leads per call (the API cap). For a 2,300-lead segment that's 5 calls. Response includes Email Bison lead IDs — the skill stores them for Step 7.

**Step 6 — Create campaign shell.** The skill calls `mcp__plugin_marketing_emailbison-b2b__create_campaign` with the campaign name, daily-volume caps, and tracking options. This creates an empty campaign — no leads, no senders, no schedule, no sequence yet. Email Bison returns a campaign ID; the skill stores it for the remaining calls.

**Step 7 — Attach leads to campaign.** The skill calls `mcp__plugin_marketing_emailbison-b2b__import_leads_to_campaign` with the lead IDs from Step 5 and the campaign ID from Step 6. **MCP-level confirmation gate**: the first call returns a confirmation prompt; the skill relays it to the BDR and only proceeds with the confirmation parameter after explicit user approval. If any lead is already in another campaign's sequence, the call fails with an `allow_parallel_sending` prompt — the skill surfaces this to the user and never auto-enables (see Email Bison integration guide §Known gotchas).

**Step 8 — Attach senders + warmup check.** The skill calls `list_sender_emails` to enumerate connected sender accounts, filters for `status: "connected"`, then calls `attach_sender_emails_to_campaign` with the array of sender IDs. It then calls `get_warmup_details` (or `list_warmup_stats` for a range query) per sender to confirm each is past warmup and within the 30–50/day industry guideline for per-mailbox send volume (findings §7 Industry Best Practices). If a sender is still warming, the skill flags it and asks the BDR to confirm or swap.

**Step 9 — Create schedule + sequence.** Two separate calls: first `create_schedule_from_template` with a `schedule_id` selects a reusable schedule template (business hours, BDR timezone, weekdays-only); then `create_sequence_steps` (v1.1 endpoint — the legacy `/api/campaigns/{id}/sequence-steps` is deprecated in the spec) creates the email sequence with `title`, `email_subject`, `email_body`, `wait_in_days`, `variant`, `thread_reply` per step.

**Step 10 — Activate (resume_campaign, MCP-gated).** The skill calls `resume_campaign` to transition the campaign from `Draft` to `Queued`. **This is the only step that starts sending real emails.** Email Bison's MCP enforces a confirmation gate on this call (the description says verbatim "STARTS SENDING REAL EMAILS") — the skill must not pass the confirmation parameter on the first call; it relays the prompt to the BDR, waits for explicit approval, and only then repeats the call with confirmation. After activation, the skill reports the campaign URL, lead count imported, senders attached, schedule, sequence step count, and status.

**Step 11 — Handoff to `campaign-orchestration` skill.** If the BDR wants deeper sequence design (step count, timing, subject variants, A/B variants via `variant_from_step_id`), `list-building` hands off to `campaign-orchestration` — a cross-skill handoff documented in each skill's Operational Runbook (ADR 2f §6).

**Step 12 — Ambient reply-processing activation.** Once the campaign sends, every reply flows through the ambient pipeline: Email Bison webhook → OutboundSync → `label-sync` CF → SF Contact update + MI list routing + (on SUPPRESS) Email Bison blocklist write + (on SPEED_TO_LEAD) Slack notification. No skill involvement. This is the "CFs are the only writers" invariant (ADR 2b) — the skill's job ends once the campaign is activated; the infrastructure handles everything downstream.

Cross-repo access summary for this scenario: 1 × GitHub MCP (Step 2), 1 × Salesforce MCP (Step 3), 8 × Email Bison MCP (Steps 4–10 across 7 tool names), 0 × Context7 (this scenario doesn't need semantic search — a `deliverability-audit` scenario would), 0 × local clones.

---

## Open questions

Carried forward from BC-5040 (Phase 1 deferred items) and BC-5041 (review notes not resolved during review). These are not blockers for the 6 downstream skill issues, but they should be tracked.

**From BC-5040:**

- The ~$0.045/contact enrichment cost figure has no documented source. Either find a source or drop it from the findings doc when cited. [Phase 1 deferred — `docs/research/outbound-pipeline-findings.md` §1 Layer 1]
- The `reply-notification` <30s SLA is not stated anywhere in the `outbound-sales-ops` repo. The only documented SLA is the BDR's ~5 min response target for Tier 1 Hot (human SLA, not CF processing latency). Verify whether the <30s figure is real before citing it in skill content.
- CLAUDE.md says 12 enrichment providers, the provider directory has 14 files. Reconcile the canonical count for external-facing documentation.

**From BC-5041 review notes (open):**

- **Credential pattern (ADR 2a):** `${ENV_VAR}` substitution in committed `.mcp.json` works today. If Claude Code ships native secret management or project-scoped `.env` support, evaluate upgrading.
- **Salesforce MCP non-GA tools (ADR 2a):** Many Salesforce MCP tools require `--allow-non-ga-tools`. Decide whether to pin to GA-only toolsets or accept the non-GA risk — likely revisited when writing the Salesforce integration guide alongside the first consuming skill (BC-2720 reply-processing).
- **Email Bison Beta versioning (ADR 2a):** Email Bison's MCP is in Beta. Tool names may change. Consider a version-pinning or tool-name audit strategy.
- **OutboundSync on-demand trigger (ADR 2b):** If a future skill needs to force a re-sync rather than waiting for the `replay-pending` cron, the `outbound-sales-ops` repo would need an on-demand trigger endpoint. Not blocked by this milestone.
- **Degradation clause in the pattern guide (ADR 2c):** Should the guide grow by ~10 lines to include the degradation policy, or keep it ADR-only? Defer until the pattern has one more real-world use.
- **GitHub MCP plugin location (ADR 2d):** Register GitHub MCP in the marketing plugin (primary consumer) vs. the workflows plugin (existing cross-repo consumers). Defer to first consuming skill.
- **GitHub PAT scope (ADR 2d):** Personal per-developer PAT vs. machine PAT stored as org secret. Defer until the first GitHub MCP consumer ships.
- **Audience view naming convention (ADR 2e):** `audience_view_*` is defined here; decide whether a detailed spec belongs in `brite-data-platform`'s CLAUDE.md when the first audience view lands.
- **500-lead `bulk_create` limit (ADR 2e):** Email Bison's chunk limit. Not a real constraint for Brite's volumes, but document in the integration guide.
- **Template category enforcement (ADR 2f):** Should `scripts/validate.sh` enforce that `category` is one of three values, or trust skill authors?
- **Operational Runbook placement (ADR 2f):** Inline in SKILL.md vs. a `references/` subdirectory. Defer until the first runbook drift complaint.
- **Brite Implementation section for generic skills (ADR 2f):** `deliverability-audit` is mostly generic methodology with a tiny Brite footprint. Does it need a 2-line Brite Implementation section or can it be omitted? Defer to the skill author at authoring time.

---

## Links

- **BC-5040** — Phase 1 validation (PR #115, merged 2026-04-09)
- **BC-5041** — Phase 2 ADRs (PR #118, merged 2026-04-12)
- **BC-5042** — this phase (Phase 3, draft PR pending merge)
- [ADRs document](outbound-agent-architecture-adrs.md) — full alternatives analysis and review notes for all 6 decisions
- [Research findings](../research/outbound-pipeline-findings.md) — validated layer-by-layer pipeline mapping (completes BC-2714)
- [Skill-tool integration pattern guide](../guides/skill-tool-integration-pattern.md) — canonical pattern ratified by ADR 2c (PR #116)
- [Marketing skill porting guide](../guides/marketing-skill-porting.md) — upstream → Brite conventions
- [Email Bison integration guide](../../plugins/marketing/tools/integrations/email-bison.md) — first real instance of the skill↔tool pattern
- [Outbound skill template](../../plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md) — scaffold produced by this phase, implementing ADR 2f
