# Outbound Pipeline Research — Working Document

**Issue:** BC-2714 (paused — needs system design first)
**Status:** Research complete, architecture design needed before findings doc
**Date:** 2026-04-01

---

## 1. Pipeline Layers (Current State)

### Layer 1: List Building / Enrichment
**Repo:** `Brite-Nites/brite-data-platform`
**Stack:** Snowflake + dbt + Python (Prefect flows + Pydantic) [CORRECTED 2026-04-09: full stack is Snowflake + Fivetran + Airbyte Cloud + dbt Cloud + custom Python pipelines (CLAUDE.md). Prefect confirmed via flow files in services/enrichment/flows/. Pydantic confirmed via services/enrichment/models/schemas.py]

- **Acquisition:** Serper Places API (Google Places scraping for lead discovery) [VERIFIED 2026-04-09: services/enrichment/loaders/serper_places_loader.py + RAW.PIPELINE_SERPER schema]
- **People Discovery:** Apollo People Search API [VERIFIED 2026-04-09: services/enrichment/providers/apollo_person_enrich.py + services/enrichment/flows/people_discovery.py]
- **Email Waterfall (built):** IcyPeas ($0.01) → Prospeo ($0.02) → LeadMagic ($0.03) [VERIFIED 2026-04-09: services/enrichment/recipes/work_email_waterfall.yml — exact order, exact prices, stop-at-first-success]
- **Verification (built):** BounceBan (deliverability) + EmailGuard (ESP detection) [VERIFIED 2026-04-09: services/enrichment/providers/bounceban.py + emailguard.py, both with tests]
- **Golden Records:** `dim_people` + `dim_companies` in Snowflake with field-level survivorship + 10-point quality scoring [VERIFIED 2026-04-09: models/marts/dim_people.sql + dim_companies.sql; data_quality_score column confirmed]
- **Audience Views:** Planned but not yet built (filtered golden records for campaign targeting) [VERIFIED 2026-04-09: no audience_view models in dbt; CLAUDE.md data-flow diagram shows "quality gate (audience views)" as future step]
- **Cost:** ~$0.045/contact for full enrichment [DEFERRED: figure not found in CLAUDE.md or recipe files; recipe cost_cap is $0.10 per waterfall run; $0.045 may be an estimated average but is not documented]
- **Architecture:** Single-writer gold pattern (Python → RAW, dbt → ANALYTICS) [VERIFIED 2026-04-09: exact phrase in CLAUDE.md and docs/enrichment-recipes.md — "Python → RAW.PIPELINE_ENRICHMENT (staging only), dbt → dim_people/dim_companies (production). Python NEVER writes to production."]
- **CLI:** `python -m enrichment.cli` (run-recipe, ingest-people, discover-people, check-spend) [CORRECTED 2026-04-09: CLI has 9 commands, not 4. Full list: run-recipe, ingest-people, ingest-companies, ingest-company-csv, discover-people, check-spend, list-recipes, validate-recipes, consolidate-clay. File path: services/enrichment/cli.py (module invocation `python -m enrichment.cli` is correct)]

> **[NEW 2026-04-09]** WIP listed 5 enrichment providers (IcyPeas, Prospeo, LeadMagic, BounceBan, EmailGuard). Actual count: **14 real providers** in services/enrichment/providers/: apollo_person_enrich, bounceban, clearbit, company_url_finder, datagma, emailguard, findymail, icypeas, leadmagic, openmart, pdl_person_enrich, prospeo, serper_domain, snovio, twilio. CLAUDE.md says "12 providers" — the 14 file count includes serper_domain (also a loader) and company_url_finder (utility). The 5-provider view in this WIP only covers the email waterfall + verification subset.

### Layer 2: Sending / Sequencing
**Tool:** Email Bison (only — Smartlead references in handbook are stale) [CORRECTED 2026-04-09: Email Bison is the sole sequencer (verified). However "Smartlead references in handbook are stale" is misleading — handbook mentions Smartlead only as a market alternative ("alternatives: Instantly, Smartlead, Lemlist"), never as a Brite-active tool. Smartlead was never used by Brite.]
**Sync:** OutboundSync webhooks for event tracking (delivery, opens, replies, bounces, unsubscribes) [VERIFIED 2026-04-09: handbook tools-and-tech-stack.md confirms 7 event types]

- Multi-mailbox rotation, staggered sending
- OutboundSync creates Contact records in Salesforce (not Leads — intentional for outbound) [VERIFIED 2026-04-09: production audit BC-2705 (2026-03-31) confirms 6,235 Contacts, 0 Leads created by OutboundSync. CF lookup order: Contact by email first → Lead by email (fallback)]
- Campaigns loaded manually from golden records into Email Bison

### Layer 3: Reply Processing
**Repo:** `Brite-Nites/outbound-sales-ops`
**Stack:** TypeScript on Vercel Serverless + Supabase Postgres [VERIFIED 2026-04-09: Node 20+, ESM ("type": "module"), TypeScript strict, Vitest, vercel.json + api/ directory structure]

- **Master Inbox:** Aggregates replies from all sender accounts, AI classifies into 11 labels [VERIFIED 2026-04-09: docs/architecture.md has full 11-label → 8-action mapping table with MI label strings]
- **3 Cloud Functions:**
  - `label-sync` — classification → SF sync → Email Bison block list → Slack → MI list routing [CORRECTED 2026-04-09: full flow is: priority resolution → dedup (5s window, keyed on winning label) → SF write → single-label enforcement in MI → action side effects → list routing. Block list is a side effect of SUPPRESS action only; Slack is a side effect of SPEED_TO_LEAD only. Not a universal chain.]
  - `reply-notification` — Speed to Lead → Slack #positive-replies (<30s SLA) [VERIFIED 2026-04-09: flow matches (filter SPEED_TO_LEAD → SF lookup for BDR owner → Slack Block Kit). UNCERTAIN: <30s SLA not stated in repo; BDR Tier 1 Hot SLA is ~5 min for human response, not CF processing latency]
  - `message-router` — BDR reply tracking (Connected, Follow-Up) [VERIFIED 2026-04-09: docs/bdr-triage-workflow.md confirms: BDR reply → Connected, prospect re-reply → Follow-Up]
- **Priority Resolution:** Suppress > Escalate > Speed to Lead > Redirect > Archive > Deferred > Triage > No Action [VERIFIED 2026-04-09: docs/architecture.md §"8 Reply Actions" — identical 8-action priority order 1-8. Note: Escalate is "deferred from MVP" — architecture shows it but code doesn't implement the Slack #escalations path yet]
- **Architectural Rules:**
  - No tool-to-tool writes — all CF-mediated [VERIFIED 2026-04-09: architecture.md Rules 1-2. Rule 2 adds: "Cloud Functions are the only writers" to SF, MI, EB block list, and Slack]
  - Single-label enforcement in Master Inbox [VERIFIED 2026-04-09: confirmed as step in label-sync flow per architecture.md]
  - Upgrade-only lifecycle transitions [CORRECTED 2026-04-09: not a universal rule — applies specifically to Lifecycle_Stage__c and Lead_Status__c fields only (docs/salesforce-field-model.md:92). Other CF-owned fields update on every write. Guarded in both label-sync and message-router code]
- **5 Cron Jobs:** replay-pending, error-rate-monitor, canary, send-count-reconciliation, lifecycle-check [CORRECTED 2026-04-09: actually 6 crons — adds validate-sf-schema (daily at 6am UTC). Full list with schedules: replay-pending (*/5), error-rate-monitor (*/15), canary (*/15), send-count-reconciliation (0 */6), lifecycle-check (30 */6), validate-sf-schema (0 6 * * *)]
- **BDR Workflow:** 6 Master Inbox lists (Hot, Pending Action, Needs Triage, Connected, Follow-Up, Archived) [VERIFIED 2026-04-09: docs/bdr-triage-workflow.md §3 — all 6 lists with inbox_type_ids 6337-6342, detailed routing rules per label and per message direction]

> **[NEW 2026-04-09]** Additional architecture details not in WIP: (1) Supabase schema has 4 tables: dedup_cache, event_log, outbase_blocklist_entries, dead_letter. (2) Architecture rules 3-4: "MI classifies; SF owns lifecycle" and "Reply labels are not lifecycle stages" — equally important as the no-writes rule for agent skill design. (3) Dead-letter + replay: handleNoSfProspect() dead-letters webhooks when SF Contact not found; replay-pending cron auto-retries every 5min (max 3 attempts). (4) Two OutboundSync workspaces connected: send.outbase.so and personal.outbase.so.

### Layer 4: CRM
**Repo:** `Brite-Nites/brite-salesforce`
**Stack:** Salesforce Enterprise Edition (SFDX source-driven, Apex-first) [VERIFIED 2026-04-09: force-app/main/default/ structure confirms SFDX; ADRs confirm Enterprise Edition + SFDX]

- **3 Business Lines:** Brite Nites (residential), Brite Labs (commercial), Brite Supply (SaaS) [CORRECTED 2026-04-09: Brite Nites is "holiday + exterior lighting installation" serving BOTH residential and commercial, not residential-only. Brite Labs is "commercial/experiential production". Brite Supply is "B2B marketplace + Brite Base SaaS".]
- **Lead Lifecycle:** Cold_Prospect → Lead → MQL → SQL → Active Opp → Active Customer → Pending Renewal → Inactive Customer [CORRECTED 2026-04-09: GlobalValueSet has 12 values, not 8. The 8 happy-path stages listed are correct, but omit 4 critical edge states: Lost, Disqualified, Do_Not_Prospect, Subscriber. Do_Not_Prospect and Disqualified are written by label-sync on SUPPRESS — material for ADR 2d. Full source: force-app/main/default/globalValueSets/Lifecycle_Stage.globalValueSet-meta.xml]
- **Custom Objects:** Territory__c, Lifecycle_Stage_History__c (audit trail) [VERIFIED 2026-04-09: both exist. Territory__c has fields: Boundary_Tool_ID__c, Is_Active__c, Parent_Territory__c, Territory_Manager__c + validation rule. Also a lookup field on Account and Lead. Lifecycle_Stage_History__c fields: Account__c, Contact__c, Lead__c, Direction__c, Previous_Stage__c]
- **7 Opportunity Record Types** with business-specific stage sequences [CORRECTED 2026-04-09: actually 10 record types: Acquisition, Brite_Labs_CST_Renewal, Brite_Labs_Design_Renewal, Brite_Labs_New_Client, Brite_Nites_CST_Renewal, Brite_Nites_Design_Renewal, Brite_Nites_New_Client, Brite_Supply_New_Subscription, Brite_Supply_Subscription_Renewal, Partner_Fulfillment]
- **Migration:** HubSpot → Salesforce (in progress, data quality issues — 26/50 accounts validated) [CORRECTED 2026-04-09: migration is COMPLETE. Per docs/artifacts/migration-reconciliation.md: loaded ~13.4K accounts, ~35.8K contacts, ~4.3K leads, ~4.9K opportunities, ~96.5K activities, ~5.1K contact roles into production. "26/50 passed" was a spot-check (BRI-1713, 90% threshold). Salesforce is the SoR. HubSpot stays read-only for 90 days as reference.]
- **Integration Points:** Brite Base (ops app), Aircall, web forms, NetSuite, Snowflake/Fivetran [CORRECTED 2026-04-09: full integration map has 13 systems (docs/integration-map.md). The 5 listed are correct + Google Workspace, Slack, Calendly, LinkedIn Sales Nav, Stripe, Campaign Manager, Shopify, Social platforms. Aircall is marked "Live" via CTI managed package v3.]

### Layer 5: Engagement
- Slack alerts (#positive-replies, #system-health) [VERIFIED 2026-04-09]
- Aircall → Dialpad (migration in progress) for phone [CORRECTED 2026-04-09: Aircall is LIVE — in all 3 production repos, handbook how-we-work/tools.md, and the outbound flow diagram. Dialpad appears once in handbook as a planned future tool ("AI cloud phone system with native Front integration, 5-10 seats"). User confirmed 2026-04-09: "We are moving to Dialpad even though we are in Aircall right now." Correct framing: Aircall → Dialpad (planned, not started)]
- Calendly for meeting scheduling [VERIFIED 2026-04-09: in handbook flow + integration map]
- Front for ongoing dialog after first reply [VERIFIED 2026-04-09: docs/bdr-triage-workflow.md confirms CC-based handoff from MI to Front]
- HeyReach for LinkedIn (not yet integrated) [CORRECTED 2026-04-09: handbook outbound flow diagram shows HeyReach receiving LinkedIn data from Clay — partially active, not "not yet integrated". However, it's not integrated into the reply-processing pipeline (label-sync/message-router don't touch HeyReach)]
- SMS (not yet integrated) [VERIFIED 2026-04-09: planned via Twilio (env vars in outbound-sales-ops CLAUDE.md), not yet implemented]

---

## 2. Handbook Drift

| Layer | Handbook says | Current (2026-04) | Status |
|-------|-------------|-------------------|--------|
| Sequencer | Email Bison + Smartlead | Email Bison only | Stale (Smartlead refs) |
| CRM | HubSpot | Salesforce (migrating) | Active migration |
| Phone | Aircall | Dialpad (migrating) | Active migration |
| LinkedIn | HeyReach | Not integrated | Accurate |
| SMS | Not integrated | Not integrated | Accurate |

> **[CORRECTED 2026-04-09] — This entire table needs revision:**
>
> | Layer | Handbook says | Current (2026-04-09) | Status |
> |-------|-------------|----------------------|--------|
> | Sequencer | Email Bison (Smartlead listed as market alternative only) | Email Bison only | **Accurate** — Smartlead was never Brite-active |
> | CRM | Salesforce (HubSpot migration ETL scripts in brite-salesforce) | Salesforce (migration **complete**) | **Accurate** — Salesforce is SoR |
> | Phone | Aircall (live, listed in tools.md) | Aircall (Dialpad planned, not started) | **Accurate** — Aircall is live |
> | LinkedIn | HeyReach (in outbound flow diagram via Clay) | HeyReach (partially active, not in reply pipeline) | **Partially accurate** — HeyReach is active for outreach but not reply processing |
> | SMS | Not integrated (Twilio env vars planned) | Not integrated | **Accurate** |

---

## 3. MCP Server Landscape

### Available (can adopt now)
| Tool | MCP Server | Author | Tools |
|------|-----------|--------|-------|
| Salesforce | `@salesforce/mcp` | Salesforce (official) | SOQL, CRUD, metadata, deploy |
| Apollo | `apolloio/apollo-mcp-plugin` | Apollo (official) | Enrich, prospect, sequence-load, analytics |
| Smartlead | `LeadMagic/smartlead-mcp-server` | Community | 116+ tools |
| Email Bison | `emailbison-mcp-server` | Community | 25 tools (read-only) |
| Resend | `resend/resend-mcp` | Resend (official) | Send, audiences, domains |

> **[Phase 1 Validation — MCP Servers, 2026-04-09]:**
>
> | Tool | MCP Server | Status | Tool Count | Auth | Stars | Last Commit | Notes |
> |------|-----------|--------|------------|------|-------|-------------|-------|
> | Salesforce | `@salesforce/mcp` | VERIFIED | 120+ (14 toolsets incl. orgs, metadata, data, users) | SFDX CLI auth | 348 | 2026-04-03 | Many tools non-GA (need `--allow-non-ga-tools`) |
> | Apollo | `apolloio/apollo-mcp-plugin` | VERIFIED | **4** (not broad API) | OAuth 2.0 | 8 | 2026-04-03 | Only 4 tools: enrich-lead, prospect, sequence-load, analytics. Early stage |
> | Smartlead | `LeadMagic/smartlead-mcp-server` | VERIFIED | ~112 (116+ credible) | API key | 16 | 2025-07-02 | LeadMagic is partner, not Smartlead itself. 9 months since last commit |
> | Email Bison | **Official: `mcp.emailbison.com/mcp` (Beta)** | **CORRECTED — OFFICIAL MCP EXISTS** | **141 tools** (23 core + 118 extended) across 16 categories | API key + Instance-URL headers | n/a (vendor-hosted) | n/a (live service) | **MAJOR DISCOVERY (2026-04-10):** Email Bison has an official first-party MCP server (Beta), accessed via Settings > Integrations > EmailBison MCP in the workspace UI. NOT published on GitHub/npm — vendor-hosted at `https://mcp.emailbison.com/mcp`. Full CRUD: campaigns (21 tools), leads (15), inbox/replies (13), blocklist (8 — includes `add_email_to_blocklist`, `bulk_add_emails_to_blocklist`, `add_domain_to_blocklist`), senders (11), tags (9), webhooks (7), schedules (6), warmup (5), sequences (4), templates (4), tracking (3), variables (2), workspace (17). Both Brite workspaces connected and verified: `send.outbase.so` (Brite Nites, ID 52) + `personal.outbase.so` (BriteNites Team, ID 11). Community repos (laviefatigue 404, Sirkunle001 13 tools) are superseded. |
> | Resend | `resend/resend-mcp` | VERIFIED (1 correction) | 10+ categories | API key | 492 | 2026-04-09 | No separate "agent skills" product (original claim incorrect) |
> | OutboundSync | — | CONFIRMED ABSENT | n/a | n/a | n/a | n/a | Native webhooks + HubSpot Marketplace connector only |
> | Master Inbox | — | CONFIRMED ABSENT | n/a | n/a | n/a | n/a | No MCP server; only generic inbox (IMAP/Gmail) MCPs exist |
> | Discovery | — | NO NEW since 2026-04-01 | n/a | n/a | n/a | n/a | Notable updates: attio-mcp v1.5.0 (Attio CRM, 2026-04-09), mcp-linkedin-ads v1.0.14 (LinkedIn Campaign Manager, 2026-04-09) |

### Gaps (need to build or wait)
| Tool | Status | Priority |
|------|--------|----------|
| OutboundSync | No MCP server exists | High — core sync layer |
| Master Inbox | No MCP server exists | High — reply processing hub |
| Brite enrichment engine | Custom CLI exists, no MCP | Medium — complex pipeline |
| Clay | Limited community MCP | Low — Brite has own enrichment engine |

[VERIFIED 2026-04-09: OutboundSync and Master Inbox gaps confirmed. Brite enrichment CLI at services/enrichment/cli.py with 9 commands (14 providers). Clay gap still accurate.]

---

## 4. Pain Points (User-Identified)

All four layers have friction:
1. **List building → sequencer handoff** — Getting enriched prospects from Snowflake golden records into Email Bison campaigns is manual
2. **Reply processing → BDR workflow** — Master Inbox classification works but BDR follow-up and handoff to Front has friction
3. **CRM sync / data integrity** — Salesforce migration incomplete, OutboundSync creates Contacts not Leads, lifecycle inconsistencies [CORRECTED 2026-04-09: "migration incomplete" is wrong — migration is complete. Reframe as: "migration data quality issues (26/50 spot-check), OutboundSync Contact-only pattern creates lifecycle tracking complexity"]
4. **Multi-channel gaps** — Email-only isn't enough. LinkedIn, phone, SMS not integrated into orchestrated flow [CORRECTED 2026-04-09: LinkedIn (HeyReach) IS partially integrated via Clay for outreach; phone (Aircall) is live but not in the automation pipeline; SMS planned via Twilio]

---

## 5. Skill Design Discovery

### Upstream Pattern (coreyhaines31/marketingskills)
Three-layer architecture:
- **Skills** (`skills/`) — Knowledge documents that make Claude an expert advisor
- **CLI wrappers** (`tools/clis/`) — Zero-dep Node.js scripts wrapping APIs
- **Integration guides** (`tools/integrations/`) — How-to docs for each tool

### Brite Adaptation Question (UNRESOLVED)
The 5 planned outbound skills (list-building, campaign-orchestration, deliverability-audit, reply-processing, campaign-analysis) are net-new, not ports. They need to:
1. Teach methodology (best practices, frameworks — like upstream)
2. Know Brite's architecture (which repo, which tool, which rules apply)
3. Orchestrate existing MCP servers + custom tools

**Key insight:** MCP servers replace CLI wrappers for most tools. Skills become the orchestration layer that teaches Claude when and how to use MCP servers together.

### Proposed Architecture
```
Skills (knowledge + orchestration)
  ↓ references ↓
MCP Servers (API connectivity)
  ├── @salesforce/mcp (official)
  ├── apolloio/apollo-mcp-plugin (official)
  ├── emailbison-mcp-server (community)
  ├── custom: outboundsync-mcp (build)
  ├── custom: master-inbox-mcp (build)
  └── brite enrichment CLI (existing)
```

[CORRECTED 2026-04-09: emailbison-mcp-server should be Sirkunle001/email-bison-claude-mcp. outboundsync-mcp and master-inbox-mcp are "build" options but Phase 2 ADR 2b evaluates 5 alternatives including using existing CFs as integration layer]

---

## 6. Open Design Questions

1. **MCP server strategy:** Which MCP servers to adopt? How to configure them in the plugin's `.mcp.json`? How do they interact with the plugin architecture?
2. **Custom MCP servers:** Should we build MCP servers for OutboundSync and Master Inbox? What scope? Or use CLI wrappers?
3. ~~**Skill design pattern:** How much operational detail goes in the skill vs. in the MCP server? How do skills reference MCP tools?~~ **RESOLVED (2026-04-11):** Answered by [`docs/guides/skill-tool-integration-pattern.md`](../guides/skill-tool-integration-pattern.md). Three-layer rule: context → skill (when/which/why) → connectivity (.mcp.json + `tools/integrations/<tool>.md`, auth + inventory). Skills declare `allowed-tools: mcp__plugin_<plugin>_<server>__*` in frontmatter and call tools by semantic name in the body — zero connection details. Canonical example: `plugins/workflows/skills/create-issues/SKILL.md`. First marketing-plugin instance: [`plugins/marketing/tools/integrations/email-bison.md`](../../plugins/marketing/tools/integrations/email-bison.md).
4. **Cross-repo agents:** When an agent in `brite-salesforce` needs enrichment data, how does it access the enrichment engine in `brite-data-platform`?
5. **Audience views:** The golden records exist but audience filtering doesn't. Where does this logic live?
6. **Email Bison MCP completeness:** Community MCP is read-only. Is that sufficient or do we need write access (load campaigns, manage block lists)? [CORRECTED 2026-04-09: Sirkunle001 repo HAS write operations. FURTHER CORRECTED 2026-04-10: **Official Email Bison MCP Server (Beta) discovered** — 141 tools including full blocklist CRUD (8 tools: add/remove/bulk-add emails AND domains), campaign management (21 tools: create, import leads, attach senders, pause/resume), lead management (15 tools: create, bulk-create 500/req, upsert, blacklist), inbox/reply management (13 tools: send reply, mark interested, push to followup). Question is now fully answered — the vendor's own MCP has comprehensive write access. No custom MCP needed.]

---

## 7. Industry Best Practices (from research agent)

### Modern B2B Outbound Stack (2025-2026)
```
ICP Definition + Intent Signals
  → Enrichment (Clay/Apollo/ZoomInfo waterfalls)
    → Email Verification (ZeroBounce/NeverBounce/MillionVerifier)
      → Sequencer (Smartlead/Instantly/Email Bison)
        → CRM Sync (OutboundSync)
          → AI Reply Agents (classification + auto-response)
            → Meeting Booking (Calendly/Cal.com)
```

### Key Benchmarks
| Metric | Average | Good | Top |
|--------|---------|------|-----|
| Reply rate | 3.43% | 5-10% | 10-15%+ |
| Positive reply rate | 1-2% | 3-5% | 5-8% |
| Meeting booked rate | 0.5-1% | 1-2% | 2-3%+ |
| Bounce rate | <2% | <1% | <0.5% |

### Key Principles
- Volume without quality is dead (Gmail/Yahoo/Outlook enforcement since 2024-2025)
- Dedicated outbound domains (never primary corporate domain)
- 30-50 emails/day per mailbox max
- 4-6 week warmup for new domains
- Multi-channel (email + LinkedIn + phone) = 40% higher engagement
- Speed to lead: respond within 5 minutes (21x more likely to qualify)

---

## 8. Phase 1 Validation Log (2026-04-09)

**Issue:** BC-5040 (Phase 1 of outbound agent architecture — supersedes BC-2736)
**Validated by:** Claude Opus 4.6 + Holden Halford
**Method:** Read-only validation against `origin/main` of 3 Brite repos (fetched 2026-04-09), handbook local clone, and 8 parallel Explore subagents for MCP servers
**Access pattern:** `git show origin/main:<path>` (read-only, no branch switching, no external repo modifications)

### 1a. MCP Servers (8 checked)

| # | Target | Result | Key Finding |
|---|--------|--------|-------------|
| 1 | `@salesforce/mcp` | VERIFIED | 120+ tools, 14 toolsets, 348 stars, official. Many non-GA tools. SFDX CLI auth |
| 2 | `apolloio/apollo-mcp-plugin` | VERIFIED | 4 tools only (enrich-lead, prospect, sequence-load, analytics). OAuth 2.0. 8 stars, early stage |
| 3 | `LeadMagic/smartlead-mcp-server` | VERIFIED | ~112 tools (116+ credible). LeadMagic is partner, not Smartlead. API key. Last commit 2025-07-02 (9 months stale) |
| 4 | Email Bison MCP | **CORRECTED — OFFICIAL MCP EXISTS** | Original `laviefatigue` repo returns 404. Community `Sirkunle001` has ~13 tools. But **Email Bison has an official first-party MCP server (Beta)** at `mcp.emailbison.com/mcp` with **141 tools** (23 core + 118 extended) across 16 categories including blocklist management (8 tools with bulk add/remove for emails AND domains). Vendor-hosted, not on GitHub/npm. Both Brite workspaces verified: send.outbase.so + personal.outbase.so. This supersedes all community repos and eliminates the "read-only" / "need custom MCP" concern entirely. |
| 5 | `resend/resend-mcp` | VERIFIED | 10+ tool categories, 492 stars, official. No "agent skills" product (original claim wrong) |
| 6 | OutboundSync MCP | CONFIRMED ABSENT | Native webhooks + HubSpot connector only. No MCP on GitHub/npm/registry |
| 7 | Master Inbox MCP | CONFIRMED ABSENT | No MCP server. Only generic inbox MCPs exist (IMAP/Gmail — don't match) |
| 8 | Discovery (new since 2026-04-01) | NO NEW SERVERS | Notable updates: attio-mcp v1.5.0 (Attio CRM), mcp-linkedin-ads v1.0.14, @snokam/mcp-salesforce v1.20.1 |

### 1b. Brite Repos (3 checked)

**brite-data-platform** (origin/main: 7653736, 2026-04-07):
- CLI: CORRECTED — 9 commands not 4, path services/enrichment/cli.py
- Providers: CORRECTED — 14 real providers not 5 (WIP listed email waterfall + verification subset only)
- Golden records: VERIFIED (dim_people.sql, dim_companies.sql, data_quality_score column)
- Audience views: VERIFIED absent
- Email waterfall: VERIFIED (exact order + prices in work_email_waterfall.yml)
- Verification stack: VERIFIED (bounceban.py + emailguard.py)
- Single-writer gold: VERIFIED (exact phrase in CLAUDE.md)
- Cost $0.045: DEFERRED — not documented in repo
- Stack: CORRECTED — includes Fivetran + Airbyte Cloud (not in WIP)

**outbound-sales-ops** (origin/main: 82169c1, 2026-04-09):
- 3 CFs: VERIFIED (label-sync.ts, reply-notification.ts, message-router.ts)
- Priority order: VERIFIED (8-action table in docs/architecture.md — exact match)
- label-sync flow: CORRECTED — more steps than WIP stated (dedup, single-label enforcement)
- reply-notification: VERIFIED; <30s SLA UNCERTAIN (not in repo)
- message-router: VERIFIED (Connected/Follow-Up routing)
- Architectural rules: CORRECTED — upgrade-only is field-specific, not universal
- Cron jobs: CORRECTED — 6 not 5 (adds validate-sf-schema)
- BDR lists: VERIFIED — exact 6 names with inbox_type_ids

**brite-salesforce** (origin/main: e8995a0, 2026-04-09):
- Stack: VERIFIED (SFDX source-driven, EE)
- Business lines: CORRECTED — Brite Nites is residential + commercial, not residential-only
- Lifecycle: CORRECTED — 12 values not 8 (adds Lost, Disqualified, Do_Not_Prospect, Subscriber)
- Custom objects: VERIFIED (Territory__c + Lifecycle_Stage_History__c)
- Opp record types: CORRECTED — 10 not 7
- Migration: CORRECTED — complete, not in progress; 26/50 was spot-check
- Integrations: CORRECTED — 13 systems not 5

### 1c. Tool Stack (4 checked via automated discovery)

1. **Email Bison sole sequencer:** VERIFIED — handbook describes Smartlead as market alternative only, never Brite-active. No Smartlead references in outbound-sales-ops code
2. **Aircall → Dialpad:** CORRECTED — Aircall is live (all 3 repos + handbook tools.md). Dialpad is planned, not started (1 handbook mention as future tool). User confirmed 2026-04-09: "We are moving to Dialpad even though we are in Aircall right now"
3. **HubSpot → Salesforce:** CORRECTED — migration complete (13.4K accounts loaded). 26/50 was a spot-check. Salesforce is SoR
4. **New tools since 2026-04-01:** none in the outbound/marketing space. Deputy and Airbyte Cloud are data platform integrations from other workstreams

### Open questions for Phase 2 (BC-5041)

1. ~~**Email Bison MCP adoption:** Which repo to adopt?~~ **RESOLVED (2026-04-10):** Official Email Bison MCP Server (Beta) exists at `mcp.emailbison.com/mcp`. 141 tools including full blocklist management (8 tools), campaign CRUD (21 tools), lead import (15 tools). Both Brite workspaces connected and verified. Community repos (laviefatigue, Sirkunle001) are superseded. ADR 2a should recommend the official MCP; ADR 2b's "custom MCP for Email Bison" question is answered — no custom MCP needed.
2. **Apollo MCP scope:** Only 4 tools — how much of the prospecting pipeline can it automate?
3. **Salesforce MCP non-GA tools:** Which non-GA toolsets are needed for outbound? What's the risk of depending on non-GA?
4. **Smartlead MCP relevance:** If Brite never used Smartlead, should the MCP be adopted (for Email Bison migration future-proofing) or skipped?
5. **Cost claim validation:** The ~$0.045/contact figure needs a source or should be dropped from the findings doc
6. **Reply-notification <30s SLA:** Is this a real requirement? Where does it come from?
7. **14 vs 12 providers:** CLAUDE.md says 12, code has 14 — which count is authoritative for external-facing docs?
