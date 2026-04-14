# Demand Gen Research — Findings

**Issue:** [BC-2715](https://linear.app/brite-nites/issue/BC-2715) (Urgent, research)
**Status:** v2 — open questions resolved with product/GTM owner
**Drafted:** 2026-04-14 (v1); updated 2026-04-14 (v2)
**Blocks:** [BC-2722](https://linear.app/brite-nites/issue/BC-2722) outbound-playbook · [BC-2723](https://linear.app/brite-nites/issue/BC-2723) linkedin-outreach · [BC-2724](https://linear.app/brite-nites/issue/BC-2724) event-marketing
**Companion:** [`outbound-pipeline-findings.md`](outbound-pipeline-findings.md) (cold email / outbound infra — do not duplicate here)

> Scope: **net-new channels only** — LinkedIn outreach, events, partnerships, warm calling, PLG, YouTube, press. Cold email/outbound infrastructure is covered in the companion findings doc and is cross-linked, not re-litigated.

---

## Verification tag legend

Same vocabulary as the outbound findings doc:

- `[VERIFIED 2026-04-14]` — confirmed against handbook or repo this session
- `[CORRECTED 2026-04-14: ...]` — WIP / Linear-issue assertion is wrong; correction follows
- `[DEFERRED: ...]` — evidence not found; flagged for follow-up
- `[UNCERTAIN]` — partial evidence; stated as uncertain in the doc

External-source claims carry inline citations with publish dates.

---

## 1. TL;DR

1. **The handbook cannot carry these three skills.** Inbound/lifecycle maturity is "Early" or "Roadmap", and the three most relevant `lead-playbooks/*.md` (events/partnerships/social) are 39-line unanswered-question stubs. **Skills will be ~80% external best-practices + ~20% Brite-specific anchors** (Lead_Source picklist, Campaign architecture, verticals, outbound infra integration points). [VERIFIED 2026-04-14]
2. **Entity framing in Linear issue is slightly off from handbook canon.** Handbook uses 3 entities (Brite Nites, Brite Labs, Brite Supply) with Brite Base as a SaaS product inside Brite Supply [VERIFIED 2026-04-14: handbook `CLAUDE.md` Mermaid standards §Entity colors; confirmed by [outbound-pipeline-findings.md §4 correction](outbound-pipeline-findings.md#layer-4-crm)]. Per direction, this doc uses the Linear issue's 4-entity framing (Nites / Supply / Base / Labs) but explicitly notes Base's motion differs from Supply's marketplace motion.
3. **LinkedIn at Brite today = enrichment data source, not an outreach channel.** `Brite-Nites/brite-data-platform` has 77 `LinkedIn` hits, all in enrichment recipes (`work_email_linkedin.yml`, `company_linkedin_enrichment.yml`, `person_linkedin_enrichment.yml`) [VERIFIED 2026-04-14 via GitHub code search]. HeyReach: 2 hits in `Brite-Nites/outbound-sales-ops` (README + old plan doc) — **aspirational, not integrated** [VERIFIED 2026-04-14]. LinkedIn is **not** a Salesforce `Lead_Source` value [VERIFIED 2026-04-14].
4. **Events have Salesforce infrastructure but no operational program.** `Lead_Source` picklist includes `Trade Show`, `Webinar`, `Customer Event`, `Networking` [VERIFIED 2026-04-14]. Inbound events page: "Ad hoc — participated but no repeatable program. Owner: TBD" [VERIFIED 2026-04-14].
5. **Partnerships don't fit the three blocked skills.** Handbook has one stub (`referrals-partner-introductions.md`) and Salesforce has `Partner` / `External Referral` / `Employee Referral` / `Referral` as Lead_Source values, but no proactive partnership-development playbook exists. **Recommendation: flag a new `partnerships` skill issue** (not in current scope).
6. **PLG (Brite Base) is absent from the handbook.** No PLG content found in handbook demand-gen, go-to-market, or tool docs [VERIFIED 2026-04-14]. Brite Base's PLG motion must be built ground-up in BC-2722 outbound-playbook or in a dedicated future skill.

---

## 2. Entity × Channel Matrix

Discovered from handbook + repos, then compared against the Linear issue's assertions.

| Entity        | Active channels (evidence)                                                                                             | Planned / aspirational                          | Not relevant                 |
|---------------|------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|------------------------------|
| **Brite Nites**   | Inbound web (mature per GTM README); referrals (Lead_Source: `Referral`, `Customer Event`); local community events (ad hoc); organic social (IG/FB, ad-hoc posting) | Home shows, seasonal activations (no calendar), LinkedIn for commercial-adjacent | Dedicated LinkedIn outbound; PLG |
| **Brite Labs**    | Cold email (mature; see outbound findings); warm calling (Aircall); referrals; attended trade shows (ad hoc)              | CAI / BOMA / NAIOP / municipal / university trade shows (handbook lists as targets, no calendar); LinkedIn outreach (channel mentioned in GTM README); venue / municipality partnerships | Residential-targeted channels |
| **Brite Supply**  | Cold email (shared with Labs outbound motion); enrichment-driven list-building                                            | Trade shows, industry influencer programs, YouTube product demos — **all aspirational** [CONFIRMED 2026-04-14 with product owner] | Local community events       |
| **Brite Base**    | Cold email (shared with Supply outbound)                                                                                 | PLG (freemium / trial / self-serve signup) — **entirely aspirational; no motion today** [CONFIRMED 2026-04-14]; LinkedIn outbound; content-led growth | Trade shows; local events    |

> **Comparison to Linear issue assertions** — scored cell-by-cell:
>
> | Assertion in BC-2715 description                                 | Evidence-based verdict |
> |-------------------------------------------------------------------|------------------------|
> | Nites → local events, home shows, seasonal campaigns              | **MATCHES** (handbook events page lists "home shows, holiday activations"; `Customer Event` in Lead_Source) [VERIFIED 2026-04-14] |
> | Supply → trade shows, industry influencers, YouTube demos         | **ASPIRATIONAL** — all three are planned, none active today [CONFIRMED 2026-04-14]. Supply demand-gen today is shared with Labs outbound (cold email via Email Bison + enrichment-driven list-building). |
> | Base → product-led growth + outbound email + LinkedIn             | **PARTIAL-ASPIRATIONAL** — outbound email is shared with Supply; PLG and LinkedIn outreach are both aspirational, no active motion today [CONFIRMED 2026-04-14]. |
> | Labs → venue partnerships, municipality announcements, press      | **PARTIAL** — handbook events page names "municipal conferences, university facilities" as Labs-targeted; `Partner` Lead_Source exists for partner-sourced leads; **press / PR is aspirational** [CONFIRMED 2026-04-14: no active PR motion]. |

---

## 3. Per-channel findings

Each channel: **Internal state** (handbook + repos) → **External benchmark anchors** (3+ sources with publish dates) → **Skill implication**.

### 3.1 LinkedIn outreach

**Internal state:**
- Handbook: [`marketing/demand-generation/inbound/social-media.md`](https://github.com/Brite-Nites/handbook/blob/main/marketing/demand-generation/inbound/social-media.md) — LinkedIn listed as active account, "Commercial buyers, B2B — Minimal activity" [VERIFIED 2026-04-14].
- No LinkedIn-specific playbook; `social-media-dms-engagements.md` is a 39-line stub covering LI/IG/FB combined [VERIFIED 2026-04-14].
- GTM README mentions "LinkedIn outreach" as a campaign channel alongside cold email + warm calls [VERIFIED 2026-04-14 `marketing/go-to-market/README.md`].
- `brite-data-platform`: 77 `LinkedIn` hits, **all enrichment** (person/company URL → email/firmographics), not outbound [VERIFIED 2026-04-14].
- `outbound-sales-ops`: 2 `HeyReach` hits, README + old plan doc — **on roadmap, not yet scheduled** [CONFIRMED 2026-04-14 with product owner]. Named as the leading candidate LinkedIn outreach tool but no active adoption issue exists yet.
- Salesforce Lead_Source: no `LinkedIn` value [VERIFIED 2026-04-14 `LeadSource.standardValueSet-meta.xml`].

**External benchmarks (2025):**

| Metric                               | Value / range                              | Source                                                                 |
|--------------------------------------|--------------------------------------------|------------------------------------------------------------------------|
| Connection request acceptance        | 27–45% (well-targeted 40–50%)              | [Alsona (2025)](https://www.alsona.com/blog/linkedin-connection-request-benchmarks-healthy-acceptance-rate-in-2025), [Expandi H1 2025](https://expandi.io/blog/state-of-li-outreach-h1-2025/), [Botdog 16k-invite study](https://www.botdog.co/blog-posts/linkedin-acceptance-rates) |
| Reply rate after connection          | 10–15% avg; top 19.98%                     | [Expandi H1 2025](https://expandi.io/blog/state-of-li-outreach-h1-2025/), [Outreaches.ai 2025 Benchmarks](https://outreaches.ai/blog/cold-outreach-benchmarks) |
| Personalized note lift               | 9.36% reply vs 5.44% without               | [Botdog](https://www.botdog.co/blog-posts/linkedin-acceptance-rates)   |
| Acceptance timing                    | 63% within 24h, 88% within 7 days          | [Botdog](https://www.botdog.co/blog-posts/linkedin-acceptance-rates)   |
| Multi-action (profile visit + DM)    | Reply up to 11.87%                         | [Expandi H1 2025](https://expandi.io/blog/state-of-li-outreach-h1-2025/) |

**Skill implication (BC-2723):** Since Brite has no active LinkedIn outbound program, the skill effectively *defines* the playbook. Must cover (a) targeting via enrichment data (LinkedIn URL → Salesforce Contact match), (b) connection request frameworks (personalization, mutual context), (c) DM-to-meeting sequences, (d) content-to-DM funnels, (e) **HeyReach named as the leading candidate tool** (on roadmap per Q3) — skill documents HeyReach usage patterns but stays usable if adoption slips or the tool changes, (f) Lead_Source attribution: **recommend adding `LinkedIn` to the Salesforce picklist** (per Q6) — skill flags the infra ticket; not in skill scope to execute.

### 3.2 Events (trade shows / webinars / conferences / local)

**Internal state:**
- Handbook: [`marketing/demand-generation/inbound/events.md`](https://github.com/Brite-Nites/handbook/blob/main/marketing/demand-generation/inbound/events.md) — "Ad hoc — have participated in events but no repeatable program. Owner: TBD" [VERIFIED 2026-04-14].
- Handbook lists target events by track: **Brite Labs** → CAI (HOA), BOMA/NAIOP (commercial RE), municipal conferences, university facilities; **Brite Nites** → home shows, HOA community events, holiday-season activations [VERIFIED 2026-04-14].
- `lead-playbooks/events-webinars-trade-shows.md` — 39-line stub, entirely unanswered questions [VERIFIED 2026-04-14].
- Salesforce `Lead_Source`: `Trade Show`, `Webinar`, `Customer Event`, `Networking` values exist [VERIFIED 2026-04-14].
- Salesforce `Campaign` object: full architecture approved 2026-03-30 (3-level hierarchy Vertical → Offer → Execution; 15-value Campaign.Type; 6-value Vertical__c picklist) [VERIFIED 2026-04-14 `brite-salesforce/docs/artifacts/campaign-architecture.md`].

**External benchmarks (2025):**

| Metric                     | Value                                                 | Source                                                                 |
|----------------------------|-------------------------------------------------------|------------------------------------------------------------------------|
| Trade show CPL             | $112–$840 (avg ~$811)                                 | [Sopro B2B CPL Benchmarks 2025](https://sopro.io/resources/blog/b2b-cost-per-lead-benchmarks/), [Wave Connect Trade Show Stats 2025](https://wavecnct.com/blogs/news/tradeshow-statistics) |
| Trade show ROI (12 months) | 300–500%                                              | [Wave Connect](https://wavecnct.com/blogs/news/tradeshow-statistics)    |
| Meeting cost               | $142 at show vs $250 at prospect office (38% lower)   | [Wave Connect](https://wavecnct.com/blogs/news/how-to-measure-trade-show-roi) |
| Attendee buying power      | 81% have purchasing decision authority                 | [Wave Connect](https://wavecnct.com/blogs/news/tradeshow-statistics)   |
| New-prospect rate          | 67% of attendees are new contacts                     | [Wave Connect](https://wavecnct.com/blogs/news/tradeshow-statistics)   |
| Lift post-meeting          | Attendees 72% more likely to buy from exhibitors met  | [Wave Connect](https://wavecnct.com/blogs/news/tradeshow-statistics)   |

**Skill implication (BC-2724):** Like LinkedIn, the skill defines a program Brite doesn't yet run. Must cover (a) event-selection scoring rubric (ICP concentration / competitive presence / CPL vs channel mix / geographic fit — scaffolding already in handbook events.md), (b) pre-event outreach (attendee list → Apollo enrichment → cold email sequence tied to event), (c) on-site capture (badge scan / business card → Salesforce with `Trade Show`/`Customer Event` source + Campaign ID), (d) post-event follow-up sequence, (e) Campaign architecture usage (Vertical → Offer → Execution hierarchy), (f) webinar execution (topic, promotion, registration, follow-up). **Two-track split** per handbook: commercial (Labs) vs community (Nites).

### 3.3 Partnerships — **not covered by any blocked skill**

**Internal state:**
- Handbook: `referrals-partner-introductions.md` is a 39-line stub covering *inbound referrals only* [VERIFIED 2026-04-14].
- Salesforce Lead_Source: `Partner`, `External Referral`, `Employee Referral`, `Referral` values exist [VERIFIED 2026-04-14].
- No proactive partnership-development playbook anywhere (handbook or repos) [DEFERRED: confirm with stakeholder whether any off-handbook program exists].
- Handbook events page names "venue partnerships, municipal/university facility associations" as Labs-targeted, but these are treated as event relationships, not a partnership program.

**External benchmarks (2025):**

| Metric                              | Value                                       | Source                                                                                   |
|-------------------------------------|---------------------------------------------|------------------------------------------------------------------------------------------|
| Partner-involved close-rate lift    | 53% more likely to close                    | [PartnerStack Enterprise KPIs](https://partnerstack.com/articles/enterprise-kpis-saas-partnerships), [Partner2B Partner-Led Revolution](https://www.partner2b.com/post/the-partner-led-revolution-13-b2b-trends-driving-ecosystem-growth-sales-in-2025) |
| Partner deal speed                  | 46% faster                                  | [PartnerStack](https://partnerstack.com/articles/enterprise-kpis-saas-partnerships)      |
| Partner AOV lift                    | 40% higher                                  | [Partner2B](https://www.partner2b.com/post/the-partner-led-revolution-13-b2b-trends-driving-ecosystem-growth-sales-in-2025) |
| Referral conversion rate            | 24.7%                                       | [Referral Rock B2B Stats 2025](https://referralrock.com/blog/b2b-referral-marketing-statistics/) |
| Partner-sourced revenue (top SaaS)  | 15–30%                                      | [Partner2B Playbook](https://partner2b.com/post/the-partner-led-growth-playbook-kpis-metrics-and-signals-that-prove-it-s-working) |

**Skill gap recommendation:** A `partnerships` skill is strongly implied. Proposed scope: **(a)** partner ICP and tiering (venue / municipality / designer / landscape-architect / agency), **(b)** partner recruitment playbook (outreach frameworks, pitch decks, MOU/referral-agreement templates), **(c)** enablement and co-marketing (joint events, content swap), **(d)** incentives and tracking (attribution via `Partner` Lead_Source + Salesforce Campaign hierarchy), **(e)** partner-sourced pipeline metrics (qualified referrals / quarter, partner-sourced ARR share). **Do not create the Linear issue in this PR** — surface the gap to the user first; rename only happens after explicit approval.

### 3.4 Warm calling (Aircall → Dialpad transition)

**Internal state:**
- Handbook: [`marketing/business-development/warm-call-script.md`](https://github.com/Brite-Nites/handbook/blob/main/marketing/business-development/warm-call-script.md) — 261-line script, mature content [VERIFIED 2026-04-14].
- Tool: Aircall is listed in `marketing/tools.md` as the active phone tool [VERIFIED 2026-04-14]. Dialpad is planned per prior research [CORRECTED 2026-04-14: handbook has not yet been updated — Dialpad is a future-state tool per user confirmation in BC-5040].
- Use case: post-positive-reply warm calling (after cold email gets a positive reply). Also `positive-reply-call-script.md` covers this explicitly [VERIFIED 2026-04-14].
- BD team runs the 13 lead-playbook set and warm-call-back workflow [VERIFIED 2026-04-14 `marketing/business-development/README.md`].

**External benchmarks (2025):**

| Metric                                   | Value                                     | Source                                                                 |
|------------------------------------------|-------------------------------------------|------------------------------------------------------------------------|
| Cold call connect rate                   | 3–10% (≈18+ dials/live prospect)          | [SalesHive B2B 2025](https://saleshive.com/blog/b2b-sales-cold-calling-benchmarks-teams-2025/), [Instantly 2025](https://instantly.ai/blog/the-truth-about-b2b-cold-calling-in-2025-statistics-and-success-rates/) |
| Cold call → meeting conversion           | 2.5% avg; 5–8% top performers             | [SalesHive](https://saleshive.com/blog/b2b-sales-cold-calling-benchmarks-teams-2025/), [Optif.ai](https://optif.ai/learn/questions/cold-call-to-meeting-conversion-rate/) |
| Warm-intro / referral → meeting          | 15–25%                                    | [SalesHive](https://saleshive.com/blog/b2b-sales-cold-calling-benchmarks-teams-2025/) |
| SDR qualified meetings/month (top 25%)   | 12–15                                     | [SalesHive](https://saleshive.com/blog/b2b-sales-cold-calling-benchmarks-teams-2025/), [Gradient Works](https://www.gradient.works/blog/benchmarks-for-metrics-that-matter-to-sales-development) |

**Skill implication:** Warm calling is already documented in the handbook. The `outbound-playbook` (BC-2722) **conductor** skill should orchestrate cold email → warm call handoff. No dedicated warm-calling skill needed — existing handbook scripts + the conductor skill cover it.

### 3.5 Product-Led Growth (Brite Base)

**Internal state:**
- No PLG content in handbook demand-gen, go-to-market, or tools [VERIFIED 2026-04-14: searched marketing/ tree + demand-generation/ READMEs].
- Brite Base = SaaS product inside Brite Supply [VERIFIED 2026-04-14 via outbound-pipeline-findings §4 correction + absence from handbook entity list].
- **PLG is entirely aspirational today** — no freemium, no trial, no self-serve signup, no conversion instrumentation [CONFIRMED 2026-04-14 with product owner].

**External benchmarks (2025):**

| Metric                                  | Value                             | Source                                                                                    |
|-----------------------------------------|-----------------------------------|-------------------------------------------------------------------------------------------|
| Freemium free → paid                    | 2–5% avg; 15–25% best in class    | [ProductLed Benchmarks](https://productled.com/blog/product-led-growth-benchmarks), [Userpilot SaaS Conversion 2025](https://userpilot.com/blog/saas-average-conversion-rate/) |
| Free trial (opt-in, no CC)              | 10–15%                            | [Userpilot](https://userpilot.com/blog/saas-average-conversion-rate/)                      |
| Free trial (opt-out, CC required)       | 25–40%                            | [Userpilot](https://userpilot.com/blog/saas-average-conversion-rate/)                      |
| PQL lift                                | ~3× non-PQL conversion; ~25% avg  | [ProductLed Metrics](https://www.productled.org/foundations/product-led-growth-metrics)   |
| $1K–$5K ACV median conversion           | 10% (freemium)                    | [OpenView Product Benchmarks](https://openviewpartners.com/2022-product-benchmarks/)       |

**Skill implication:** PLG for Brite Base is entirely aspirational. **BC-2722 outbound-playbook covers PLG at a high level only** — one short section noting the future-state motion and how it'd slot into the conductor. Do **not** build detailed PLG prescriptions into any of the three blocked skills; a dedicated `plg` skill should be scoped when Brite Base stands up a real signup flow / freemium tier.

### 3.6 YouTube / video demos, press, and other channels

**Internal state:**
- YouTube: not in handbook demand-gen or tools.md [VERIFIED 2026-04-14]. **Aspirational** — not active for Brite Supply today [CONFIRMED 2026-04-14].
- Press / PR: not in handbook [VERIFIED 2026-04-14]. **Aspirational** — no PR firm, no media list, no active press motion for Labs [CONFIRMED 2026-04-14]. Dropped from demand-gen skill scope.
- Direct mail: handbook has [`demand-generation/inbound/direct-mail.md`](https://github.com/Brite-Nites/handbook/blob/main/marketing/demand-generation/inbound/direct-mail.md) (fetched but not read in depth this pass; relevant for Labs/Nites high-value verticals).
- Content marketing: handbook has `demand-generation/inbound/content-marketing.md` (Early maturity).

**Skill implication:** These channels are minor surface. Fold brief mentions into BC-2722 outbound-playbook or BC-2724 event-marketing (press releases often pair with events). Don't scope dedicated skills until Brite has active programs.

---

## 4. Handbook Coverage table

| Skill                          | Handbook coverage                                                                                                                             | Gaps                                                                                                      | Notes                              |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|------------------------------------|
| **BC-2722 outbound-playbook**   | Rich: full `cold-outreach-playbook/` tree, GTM README with revenue motion, `cold-outbound-copy-standards.md`, campaign-lifecycle.md           | Cross-channel orchestration logic (how email/LinkedIn/calls/events feed each other) not documented        | Skill authors can cite handbook heavily |
| **BC-2723 linkedin-outreach**   | Almost none: `social-media.md` mentions LinkedIn as low-activity account; `social-media-dms-engagements.md` is a 39-line stub                | No connection-request frameworks, no content-to-DM flow, no platform-specific copy standards, no HeyReach integration | Skill is effectively external-best-practices-driven |
| **BC-2724 event-marketing**     | Partial: inbound/events.md names target events by track (Labs/Nites) with selection criteria; `lead-playbooks/events-webinars-trade-shows.md` is a stub | Event calendar, pre/post playbooks, lead-capture tooling, webinar execution, measurement                  | Skill defines the program; cites Salesforce Campaign architecture + Lead_Source picklist as infra anchors |
| **Partnerships (gap)**          | `referrals-partner-introductions.md` is a stub; no proactive partnership-dev content                                                          | Everything                                                                                                 | Recommend new skill issue         |

---

## 5. Cross-channel orchestration

The handbook doesn't document orchestration and, per Q5, **no infra path is locked in across channels — each skill decides at build time.** BC-2722 outbound-playbook defines the *logical* flow (below); the physical path (CF vs native integration vs new service) is a per-channel infra gate each downstream skill resolves when it ships.

Minimum viable logical handoffs:

```
Target list (Apollo + enrichment waterfall)
      │
      ▼
Cold email sequence (Email Bison, mature)  ◄────┐
      │                                          │
      ├─── Positive reply ──► Warm call (Aircall, BD team, <5min SLA)
      ├─── LinkedIn fallback (aspirational) ──► Connection → DM → meeting
      └─── No reply after N steps ──► Suppress or re-sequence
                                                 │
Event capture (trade show / webinar / local)     │
      │                                          │
      ▼                                          │
Salesforce Campaign (Vertical → Offer → Execution) + Lead_Source tag ──┘
      │
      ▼
Partner-sourced referral (inbound) ──► Warm path, faster SLA
```

**Orchestration infra is deferred per channel** [CONFIRMED 2026-04-14]. When BC-2723 (LinkedIn) ships, its authors choose between: (a) reuse the outbound-sales-ops CF pattern (consistent with the 4 architecture principles — "no tool-to-tool writes", "CFs are the only writers"), (b) let HeyReach write directly to Salesforce (faster but breaks the rules), or (c) stand up a new orchestration service (heaviest; defer until volumes justify). Same choice applies to BC-2724 (events) and a future partnerships skill.

---

## 6. Skill boundary recommendations

### BC-2722 outbound-playbook (the **conductor**)
**In scope:** Cross-channel orchestration; motion design per entity (Labs commercial-outbound, Nites inbound-driven with outbound for underpenetrated segments, Supply shares Labs outbound, Base outbound-shared + brief PLG future-state callout); cold email → warm call handoff; pause/resume across channels; Campaign architecture usage (Vertical → Offer → Execution); Lead_Source tagging conventions; a short "future PLG motion for Brite Base" placeholder section (one page or less; real PLG skill deferred per Q2).
**Out of scope:** Per-channel tactics (delegate to linkedin-outreach, event-marketing, future partnerships skill; delegate cold-email-campaign design to campaign-orchestration BC-2718 and email-bison BC-2707); detailed PLG prescriptions (no active Base motion).
**Handbook anchors:** GTM README revenue motion, campaign-lifecycle.md, cold-outbound-copy-standards.md.
**External anchors:** Warm-call conversion benchmarks (§3.4), partnership-lift benchmarks (§3.3); PLG benchmarks (§3.5) cited only in the future-state placeholder.

### BC-2723 linkedin-outreach
**In scope:** Connection request frameworks (personalization, mutual context, value-first); content-to-DM funnels (post engagement → DM → meeting); LinkedIn engagement strategy (commenting, posting, Sales Navigator); **HeyReach-first** integration patterns (HeyReach is the roadmapped tool per Q3 — the skill documents its usage patterns) while staying usable if the tool changes; cross-reference to enrichment (LinkedIn URL → dim_people match in data platform).
**Out of scope:** LinkedIn paid ads (that's paid-advertising skill / inbound); organic social-media content strategy (that lives in content-strategy marketing skill); orchestration infra choice (deferred per Q5 — skill flags the decision but doesn't pick a path).
**Handbook anchors:** GTM README (LinkedIn mentioned); minimal.
**External anchors:** All five tables in §3.1 (connection acceptance, reply rates, timing, personalization lift, multi-action).
**Infra flags (not in skill scope):** (a) **Add `LinkedIn` to Salesforce `Lead_Source` picklist** per Q6; (b) schedule HeyReach adoption so BC-2723 has a concrete tool when it ships; (c) pick orchestration infra path (CF vs native vs new service) when skill is implemented.

### BC-2724 event-marketing
**In scope:** Two tracks (commercial trade shows for Labs; community/local events for Nites); event selection rubric; pre-event outreach (attendee enrichment, cold email with event anchor); on-site lead capture (badge scan / business card → Salesforce with `Trade Show`/`Customer Event` source + Campaign); post-event follow-up sequences; webinar execution (topic, promotion, registration, follow-up); conference presence playbook; measurement (CPL, ROI, meeting cost).
**Out of scope:** Sponsorship strategy for non-lead-gen events (brand awareness plays); event *planning* operations (that's ops, not marketing-gen).
**Handbook anchors:** inbound/events.md (selection criteria, target events by track), Salesforce Campaign architecture, Lead_Source picklist.
**External anchors:** §3.2 benchmarks (CPL, ROI, attendee buying power, new-prospect rate).

### Partnerships (proposed — NEW SKILL)
**Scope (proposed):** Partner ICP/tiering; recruitment playbook; enablement / co-marketing; incentives + attribution (`Partner` Lead_Source + Campaign hierarchy); partner-sourced pipeline KPIs.
**Rationale:** No existing skill owns this, Salesforce infra is ready (`Partner`, `External Referral`, `Employee Referral` Lead_Sources + Campaign object), and external benchmarks (53% close lift, 46% faster close, 40% AOV lift) justify a dedicated skill.
**Action:** Surface to user for approval before opening a Linear issue.

---

## 7. Open questions (resolved in v2)

All six v1 open questions were resolved with the product/GTM owner on 2026-04-14.

| # | Question                                                                           | Resolution                                                                                                                        |
|---|-------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| 1 | Brite Supply GTM motion                                                             | All Linear-issue-asserted channels (trade shows, influencers, YouTube) are **aspirational**. Today Supply shares Labs outbound.  |
| 2 | Brite Base PLG motion                                                               | **Entirely aspirational** — no signup / trial / freemium today. BC-2722 references at a high level only.                         |
| 3 | HeyReach adoption                                                                   | **On roadmap, not scheduled.** BC-2723 treats HeyReach as the leading candidate; stays usable if tool slips.                     |
| 4 | Press / PR motion                                                                   | **Aspirational** — no active PR motion. Dropped from demand-gen skill scope.                                                     |
| 5 | Cross-channel orchestration infra                                                   | **Deferred per channel** — each downstream skill picks its infra path at build time.                                             |
| 6 | Salesforce `LinkedIn` Lead_Source                                                   | **Recommend adding.** BC-2723 flags a separate infra ticket; do not auto-create.                                                 |

No residual blockers for BC-2722 / BC-2723 / BC-2724.

---

## 8. Handbook drift list (for `/workflows:ship` handbook-drift-check)

1. **`marketing/tools.md`** — lists Aircall; Dialpad is the planned replacement per BC-5040 user confirmation. Consider updating tools page or adding a note.
2. **`marketing/business-development/managing-leads/lead-playbooks/events-webinars-trade-shows.md`** — 39-line stub of unanswered questions. Answers to many of those questions now live in Salesforce infrastructure (`Lead_Source`: `Trade Show`/`Webinar`/`Customer Event`; Campaign object). Consider filling the stub.
3. **`marketing/business-development/managing-leads/lead-playbooks/referrals-partner-introductions.md`** — same as above, for referrals.
4. **`marketing/business-development/managing-leads/lead-playbooks/social-media-dms-engagements.md`** — same as above, for social DMs.
5. **`marketing/content/distribution/channel-strategy.md`** — "under construction"; useful scaffolding for BC-2722 conductor skill if filled.
6. **`marketing/demand-generation/inbound/events.md`** — "Owner: TBD". If BC-2724 is built and adopted, designate an owner and update this page.

---

## 9. Next actions

1. **User review of this doc** — confirm entity decisions, partnerships gap handling, and any open-question resolutions that don't need external validation.
2. **Create new `partnerships` skill issue** (pending user approval from §6).
3. **Unblock BC-2722 / BC-2723 / BC-2724** — each skill should anchor its "Research foundation" section to this findings doc and the companion outbound findings.
4. **Infra follow-ups** (flagged here; each is a separate Linear issue, not in any skill's execution scope):
   - **Add `LinkedIn` to Salesforce `Lead_Source` picklist** + update `docs/artifacts/web-to-lead-mapping.md` — lightweight metadata PR.
   - **HeyReach adoption issue** — on roadmap per Q3; schedule when BC-2723 is ready to ship so the skill has a concrete tool target.
   - **Future `plg` skill** — scope when Brite Base stands up a real signup / freemium motion.
   - **Future `partnerships` skill** — see §6; awaiting user approval to open the issue.

---

## 10. Links

- **Companion:** [`outbound-pipeline-findings.md`](outbound-pipeline-findings.md)
- **Blocked skills:** [BC-2722](https://linear.app/brite-nites/issue/BC-2722) · [BC-2723](https://linear.app/brite-nites/issue/BC-2723) · [BC-2724](https://linear.app/brite-nites/issue/BC-2724)
- **Design doc (outbound conductor):** [`docs/designs/outbound-agent-architecture.md`](../designs/outbound-agent-architecture.md)
- **Skill template:** [`plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md`](../../plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md)
- **Salesforce artifacts (private):** `Brite-Nites/brite-salesforce/docs/artifacts/campaign-architecture.md`, `force-app/.../LeadSource.standardValueSet-meta.xml`
