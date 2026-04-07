# Outbound Pipeline Research — Working Document

**Issue:** BC-2714 (paused — needs system design first)
**Status:** Research complete, architecture design needed before findings doc
**Date:** 2026-04-01

---

## 1. Pipeline Layers (Current State)

### Layer 1: List Building / Enrichment
**Repo:** `Brite-Nites/brite-data-platform`
**Stack:** Snowflake + dbt + Python (Prefect flows + Pydantic)

- **Acquisition:** Serper Places API (Google Places scraping for lead discovery)
- **People Discovery:** Apollo People Search API
- **Email Waterfall (built):** IcyPeas ($0.01) → Prospeo ($0.02) → LeadMagic ($0.03)
- **Verification (built):** BounceBan (deliverability) + EmailGuard (ESP detection)
- **Golden Records:** `dim_people` + `dim_companies` in Snowflake with field-level survivorship + 10-point quality scoring
- **Audience Views:** Planned but not yet built (filtered golden records for campaign targeting)
- **Cost:** ~$0.045/contact for full enrichment
- **Architecture:** Single-writer gold pattern (Python → RAW, dbt → ANALYTICS)
- **CLI:** `python -m enrichment.cli` (run-recipe, ingest-people, discover-people, check-spend)

### Layer 2: Sending / Sequencing
**Tool:** Email Bison (only — Smartlead references in handbook are stale)
**Sync:** OutboundSync webhooks for event tracking (delivery, opens, replies, bounces, unsubscribes)

- Multi-mailbox rotation, staggered sending
- OutboundSync creates Contact records in Salesforce (not Leads — intentional for outbound)
- Campaigns loaded manually from golden records into Email Bison

### Layer 3: Reply Processing
**Repo:** `Brite-Nites/outbound-sales-ops`
**Stack:** TypeScript on Vercel Serverless + Supabase Postgres

- **Master Inbox:** Aggregates replies from all sender accounts, AI classifies into 11 labels
- **3 Cloud Functions:**
  - `label-sync` — classification → SF sync → Email Bison block list → Slack → MI list routing
  - `reply-notification` — Speed to Lead → Slack #positive-replies (<30s SLA)
  - `message-router` — BDR reply tracking (Connected, Follow-Up)
- **Priority Resolution:** Suppress > Escalate > Speed to Lead > Redirect > Archive > Deferred > Triage > No Action
- **Architectural Rules:**
  - No tool-to-tool writes — all CF-mediated
  - Single-label enforcement in Master Inbox
  - Upgrade-only lifecycle transitions
- **5 Cron Jobs:** replay-pending, error-rate-monitor, canary, send-count-reconciliation, lifecycle-check
- **BDR Workflow:** 6 Master Inbox lists (Hot, Pending Action, Needs Triage, Connected, Follow-Up, Archived)

### Layer 4: CRM
**Repo:** `Brite-Nites/brite-salesforce`
**Stack:** Salesforce Enterprise Edition (SFDX source-driven, Apex-first)

- **3 Business Lines:** Brite Nites (residential), Brite Labs (commercial), Brite Supply (SaaS)
- **Lead Lifecycle:** Cold_Prospect → Lead → MQL → SQL → Active Opp → Active Customer → Pending Renewal → Inactive Customer
- **Custom Objects:** Territory__c, Lifecycle_Stage_History__c (audit trail)
- **7 Opportunity Record Types** with business-specific stage sequences
- **Migration:** HubSpot → Salesforce (in progress, data quality issues — 26/50 accounts validated)
- **Integration Points:** Brite Base (ops app), Aircall, web forms, NetSuite, Snowflake/Fivetran

### Layer 5: Engagement
- Slack alerts (#positive-replies, #system-health)
- Aircall → Dialpad (migration in progress) for phone
- Calendly for meeting scheduling
- Front for ongoing dialog after first reply
- HeyReach for LinkedIn (not yet integrated)
- SMS (not yet integrated)

---

## 2. Handbook Drift

| Layer | Handbook says | Current (2026-04) | Status |
|-------|-------------|-------------------|--------|
| Sequencer | Email Bison + Smartlead | Email Bison only | Stale (Smartlead refs) |
| CRM | HubSpot | Salesforce (migrating) | Active migration |
| Phone | Aircall | Dialpad (migrating) | Active migration |
| LinkedIn | HeyReach | Not integrated | Accurate |
| SMS | Not integrated | Not integrated | Accurate |

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

### Gaps (need to build or wait)
| Tool | Status | Priority |
|------|--------|----------|
| OutboundSync | No MCP server exists | High — core sync layer |
| Master Inbox | No MCP server exists | High — reply processing hub |
| Brite enrichment engine | Custom CLI exists, no MCP | Medium — complex pipeline |
| Clay | Limited community MCP | Low — Brite has own enrichment engine |

---

## 4. Pain Points (User-Identified)

All four layers have friction:
1. **List building → sequencer handoff** — Getting enriched prospects from Snowflake golden records into Email Bison campaigns is manual
2. **Reply processing → BDR workflow** — Master Inbox classification works but BDR follow-up and handoff to Front has friction
3. **CRM sync / data integrity** — Salesforce migration incomplete, OutboundSync creates Contacts not Leads, lifecycle inconsistencies
4. **Multi-channel gaps** — Email-only isn't enough. LinkedIn, phone, SMS not integrated into orchestrated flow

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

---

## 6. Open Design Questions

1. **MCP server strategy:** Which MCP servers to adopt? How to configure them in the plugin's `.mcp.json`? How do they interact with the plugin architecture?
2. **Custom MCP servers:** Should we build MCP servers for OutboundSync and Master Inbox? What scope? Or use CLI wrappers?
3. **Skill design pattern:** How much operational detail goes in the skill vs. in the MCP server? How do skills reference MCP tools?
4. **Cross-repo agents:** When an agent in `brite-salesforce` needs enrichment data, how does it access the enrichment engine in `brite-data-platform`?
5. **Audience views:** The golden records exist but audience filtering doesn't. Where does this logic live?
6. **Email Bison MCP completeness:** Community MCP is read-only. Is that sufficient or do we need write access (load campaigns, manage block lists)?

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
