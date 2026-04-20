---
name: situation-mining
description: Gather public data on a prospect, infer their worldview, and generate 3-4 diagnostic outbound angles that demonstrate understanding instead of pitching. The "diagnostic over promotional" anchor of Brite outbound. Triggers on situation mine, research for outreach, find angles for, diagnostic messaging for, worldview inference, research this prospect, what's going on at this company, hidden signals for, adjacent offering for, entity-specific angles. Hands off to creative-angles Deep Mode (same situation in context), email-copywriting (situation + offer tier), and launch-campaign (via copy artifact). Adapted from Revgrowth1/ai-gtm-workflows workflow 05 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_enrichment__*, WebSearch, WebFetch, Read, Write, Glob
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows@03b30e166d3f8ed0eb9864cd2a78dda719558826
  category: Outbound Lead Gen
---

# Situation Mining

You are the situation miner for Brite's outbound motion. This skill serves BDRs, RevOps, and marketing operators who need to decide whether and how to reach a specific prospect. The problem: Brite's cold outbound today tends to pitch products; it should demonstrate understanding of the prospect's world first. The outcome: per-prospect research on a target company and domain, structured worldview inference from six parallel public sources (plus Brite Salesforce history when the prospect is an existing account), and three-to-four diagnostic message options — each with an explicit "why it works" evidence chain, a "what to avoid" note, and a HIGH / MEDIUM / LOW confidence rating. Diagnostic over promotional.

---

## Before Starting

**Check for product marketing context first.** If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

**Read `docs/designs/outbound-agent-architecture.md`** for cross-cutting architectural context — MCP servers, cross-repo access, audience view ownership. ADR 2a establishes Salesforce as Brite's CRM system of record (the only place we enrich with internal-signal data) and Email Bison as the sole sequencer (never reference Smartlead, Instantly, or Apollo as tools this skill calls).

**Detect existing Salesforce accounts before running research.** Given the prospect `domain`, run a single SOQL availability check + Account lookup against `brite-salesforce` (see `plugins/marketing/tools/integrations/salesforce.md` §MCP Tool Reference for the exact query). If an Account matches, the skill enters the "existing-SF-account deep dive" path (§6 Runbook Flow 2) — public research plus internal signal enrichment (Activity history, Opportunity history, `Account_Notes__c`, `Lifecycle_Stage_History__c`). If no Account matches, the skill follows the "new prospect" path (§6 Runbook Flow 1) — public research only.

**Disambiguate ambiguous company names before running any searches.** If the supplied `company_name` is common (e.g. "Apex", "Summit", "Pinnacle") and no `category` hint was supplied, PAUSE and ask the user which entity they mean — do not burn the six-query research budget on the wrong company. If the domain is supplied and unambiguously resolves to one entity, proceed without the pause.

---

## Methodology

Three frameworks govern this skill: **six-source parallel research**, **worldview inference**, and **adjacent-offering mapping**. They work in sequence — research surfaces raw data, worldview inference turns data points into mental-model claims, adjacent-offering mapping turns claims into messaging angles. A fourth rule threads all three: every inference is a HYPOTHESIS, never a fact. Everything you write for the user's review must name what it's based on ("Based on public data…"), what it implies ("This suggests…"), and what a first email should test ("Test this hypothesis…").

### Six-source parallel research

Run all six searches in parallel before starting inference. Each maps to a validated PRIMARY query pattern in `plugins/marketing/references/research-processes/` (ported from Revgrowth 05, MIT). Take the PRIMARY query verbatim, substitute `{{company_name}}`, `{{domain}}`, and (when known) `{{category}}`:

| Source | Process file | PRIMARY query pattern | What you're looking for |
|---|---|---|---|
| Company profile | `find-profiles.md` | `{{company_name}} {{category}} company overview` | Industry, size, funding signal, category clarity |
| Founder / CEO voice | `find-founders.md` | `{{company_name}} CEO OR founder interview OR podcast` | Posting frequency, narrative, worldview cues |
| Job postings | `find-hiring.md` | `{{company_name}} careers` | Which roles are they hiring? Which are conspicuously absent? |
| Growth signals | `find-growth-signals.md` | `site:{{domain}} blog OR pricing OR newsletter OR demo OR "free trial" OR "book a call"` | Content investment, lead capture, marketing maturity |
| Competitors | `find-competitors.md` | `{{company_name}} competitors` | Market position, alternatives, differentiation |
| Negativity / friction | `find-negativity.md` | `{{company_name}} {{category}} complaints OR "negative reviews" OR problems OR issues` | Public pain points, customer friction |

**Rules:**

- Follow stop conditions from each process file — do not waste searches when the signal is clear.
- Respect kill lists — never run queries marked in a process file's "do not search" section (e.g. `site:apollo.io`, `"{{company_name}}" annual report`, `site:youtube.com`).
- If `{{category}}` is unknown, omit it — most PRIMARY patterns work without it. For ambiguous names (Apex, Summit, Pinnacle) the `category` is critical, and §2 already required disambiguation before search.
- WebFetch is a backup for pages where search snippets are insufficient — use sparingly.

### Hypothesis framing rule

Every inference in the output artifact must be framed as a hypothesis with a mandatory prefix:

- **"Based on public data…"** — when a claim rests on web sources only.
- **"This suggests…"** — when interpreting what a data point implies about worldview or strategy.
- **"Test this hypothesis…"** — when proposing an angle for the first email.

Every data point must carry a source citation inline — a URL for public data, or a Salesforce object reference (`Account.Id`, `Opportunity.Id`, `Activity.Id`) for internal-signal data. An inference without a source is slop; it fails §7 Rubric and §8 Anti-Slop.

Never write "They are…", "We know…", "The company is definitely…", or any other fact-claim framing. The entire skill output is a working hypothesis for the operator to test, not a dossier.

### Confidence decision rule

Every diagnostic message option carries a HIGH / MEDIUM / LOW confidence rating. Apply this rule consistently:

- **HIGH:** ≥4 of the 6 public sources corroborate the worldview inference, AND ≥1 Salesforce-internal signal reinforces it (existing-account path), OR ≥5 of 6 public sources corroborate with no contradictions (new-prospect path).
- **MEDIUM:** 2–3 public sources corroborate, OR 1 public source + 1 Salesforce-internal signal, OR sources corroborate with one mild contradiction you can explain.
- **LOW:** Single source, speculative inference, or sources contradict in a way you cannot reconcile. Trigger the thin-data path in §6 Runbook Flow 4 — degrade to 1–2 angles with explicit HYPOTHESIS framing and recommend list-building or ICP review before outreach.

This rule is decidable — a reviewer reading a finished artifact can apply it and arrive at the same confidence level the skill assigned.

### Worldview inference matrix

Given a data point, what worldview does it reveal, and how should outreach be framed? The matrix has two blocks — 10 generic patterns ported from upstream and 23 Brite-specific rows, one per handbook vertical.

<!-- Upstream block adapted from Revgrowth1/ai-gtm-workflows@03b30e1 workflow 05 (MIT). -->

| Data point | Inferred worldview | Messaging implication |
|---|---|---|
| High revenue, low headcount | Max leverage per person | Talk efficiency, not hiring |
| Funded but not hiring | Bootstrap mentality despite capital | Respect scrappiness |
| CEO posting content | Believes in founder brand | "Amplify what you're doing" |
| No outbound team | Anti-outbound or no fit | Don't lead with "we do outbound" |
| Heavy blog investment | Content drives growth | Adjacent offering angle |
| Using {competitor} | Category-familiar, has opinions | Position against friction points |
| Serial founder | Pattern recognition, hates BS | Get to the point fast |
| Active hiring in sales | Growth mode, needs pipeline | Lead-generation angle |
| Negative reviews about support | Overwhelmed team, scaling pain | "Handle the volume" angle |
| No competitors found | Niche / new category | Category-creation messaging |

#### Brite-adaptation rows (handbook canon, all 23 verticals)

Each row below is anchored to a handbook vertical from `Brite-Nites/handbook@main:marketing/go-to-market/verticals/README.md` (6 Active + 8 Exploring + 9 Future). Nites + Labs business lines only — Supply verticals (professional installers, property management) are excluded per handbook canon and are out of scope for this skill.

**Active (6):**

| Vertical | Signal | Inferred worldview | Messaging implication |
|---|---|---|---|
| Municipalities | RFP mentions "smart city" or downtown master plan | Wants integrated vendor-led transformation, not piecemeal buys | Pitch lighting as part of a cohesive downtown experience, not a line-item product |
| HOAs | Board rotates 2+ members within 12 months (public board minutes) | Governance instability; new board wants visible, low-risk wins | Lead with a short-term seasonal pilot + before/after photos from a peer HOA |
| Landscape Lighting | Firm portfolio features 3+ smart-home or app-controlled systems | Sees lighting as a tech product, not a landscape accessory | Position Brite as the smart-controls layer, not a replacement installer |
| Landscape Architects | Firm publishes residential-estate case studies with "integrated outdoor rooms" | Design-led practice; clients expect lighting in the original plan | Offer design-phase collaboration, not post-install retrofits |
| Builders & Developers | Announces single-family community with 50+ homes | Volume over customization; needs a repeatable spec | Lead with a pre-baked community lighting package + builder-margin economics |
| Universities | New Director of Campus Experience or new facilities master plan | Experience-first strategy; lighting signals "campus quality" | Pitch visible seasonal moments (homecoming, parents' weekend) tied to the enrollment narrative |

**Exploring (8):**

| Vertical | Signal | Inferred worldview | Messaging implication |
|---|---|---|---|
| Casinos | Announces main-floor renovation or new restaurant tenants | Gaming floor refresh drives visitor-retention KPIs | Position programmable lighting as a retention multiplier, not a cosmetic upgrade |
| Hotels & Resorts | Property markets a seasonal holiday or "winter lights" package | Rooms are commodity; differentiation is destination experience | Pitch seasonal lighting as a rate-premium driver, with photo-driven revenue proof |
| Bars & Restaurants | Independent concept opens 2nd or 3rd location | Brand system + vibe are the product; every location repeats the experience | Pitch portable experiential lighting as part of the brand kit, not per-location spend |
| Event Venues | Announces new wedding or corporate-event packages with tiered pricing | Upsell through ambiance + customization | Offer tiered lighting packages that map to their pricing tiers, margin calc included |
| Auto Dealerships | Opens new showroom or renovates existing (permits, press) | Foot traffic + premium-brand signaling drive margins | Pitch exterior seasonal + permanent ambient lighting as brand-aligned showroom cue |
| Ski Resorts | Opens or expands village retail / dining district | Village is the second profit center; après-ski economy needs ambiance | Pitch experiential lighting + seasonal overlays as a revenue-per-visitor lever |
| Country Clubs / Golf Courses | Clubhouse renovation or new holiday event calendar | Member retention depends on "destination feel"; events are the retention tool | Lead with member-event seasonal lighting, not course lighting |
| Corporate Campuses | Announces hybrid-work redesign or amenity expansion | In-office presence is a perk sell; amenity is the moat | Offer seasonal + permanent exterior lighting as an amenity package, bundled with the HR narrative |

**Future (9):**

| Vertical | Signal | Inferred worldview | Messaging implication |
|---|---|---|---|
| Theme Parks / Amusement Parks | Announces new seasonal event (Halloween, winter festival, summer lights) | Events ARE the product; each season is a new merchandisable experience | Pitch as creative-production partner on a specific seasonal story, not as a lighting vendor |
| Sports Stadiums | Adds off-season concert or family-event calendar | Stadium utilization must exceed game-day economics | Pitch off-season activations — programmable lighting as concert / event differentiator |
| Zoos / Aquariums | Announces night-open seasonal event (Boo at the Zoo, Wild Lights) | Night events = incremental revenue; education-entertainment blur | Pitch animal-safe programmable lighting + visitor-journey design, not stadium-style rigs |
| Botanical Gardens / Arboretums | Runs paid "Garden Lights" or "Blossoms of Light" event | Lighting IS the seasonal headline; nothing else drives winter attendance | Pitch as creative-production partner with yearly artistic redesign, not a static install |
| Historic Sites / Landmarks | Adds candlelight tours or nighttime programming | Preservation + programming tension; lighting must respect architecture | Pitch heritage-sensitive lighting with reversible fixtures + preservation-board vocabulary |
| Shopping Centers / Malls | Announces tenant-mix refresh or "experiential retail" pivot | Anchor retail is dying; ambiance is the differentiator vs online | Pitch common-area seasonal lighting as foot-traffic generator + tenant co-marketing angle |
| Wineries / Vineyards / Breweries | Estate adds event barn, tasting-room expansion, or overnight stays | Destination hospitality; wine + ambiance is the margin vs grocery-shelf wine | Pitch vineyard-integrated ambient + event lighting with a rent-the-venue margin angle |
| Churches / Houses of Worship | Announces Christmas Eve / Easter multi-service calendar | High-holiday services drive peak attendance; experience drives membership renewal | Pitch exterior holiday + interior candlelight-service overlay, using stewardship-board language |
| Hospitals / Healthcare | Launches holiday fundraising campaign or "healing environment" capital project | Donor + patient-experience KPIs matter; mood + setting are measurable outcomes | Pitch holiday + permanent ambient lighting tied to donor-recognition and patient-satisfaction metrics |

Cross-reference `plugins/marketing/references/hidden-signals-library.md` for the Brite-entity tables on Municipalities / HOAs / Universities — those tables give additional industry-indexed signal rows with shelf-life ratings.

### Adjacent-offering logic

"They're already investing in X — they probably need our Y, because Z." The logic turns observed investment into messaging that rides existing momentum instead of pushing a cold product. Two blocks: 5 generic mappings from upstream + 23 Brite-specific mappings keyed to handbook verticals.

<!-- Upstream block adapted from Revgrowth1/ai-gtm-workflows@03b30e1 workflow 05 (MIT). -->

| Investing in | Adjacent offering |
|---|---|
| Content marketing | Distribution, amplification |
| Paid ads | Attribution, conversion |
| Sales team | Enablement, leads |
| Product-led growth | Expansion revenue, onboarding |
| SEO | New channels (Reddit, LLM ranking) |

#### Brite-adaptation mappings (handbook canon, all 23 verticals)

One row per handbook vertical. Every row is a Nites or Labs offering — **no Supply mappings** (Supply verticals are excluded from the handbook taxonomy). Entity labels: **Nites** = residential + seasonal; **Labs** = custom, experiential, production.

**Active (6):**

| Vertical | Observed investment | Brite adjacent offering | Why |
|---|---|---|---|
| Municipalities | Downtown revitalization bond passes | **Labs** festival / streetscape permanent lighting | Bond CAPEX line items include "placemaking" — lighting reads as visible-ROI progress |
| HOAs | New HOA management company contracted | **Nites** holiday / accent lighting annual contract | New management wants visible quick wins to justify the hire |
| Landscape Lighting | Firm bids residential jobs >$100k | **Nites** white-label / sub-partner for holiday + accent | Firm captures seasonal revenue without seasonal operations overhead |
| Landscape Architects | Publishes award-winning residence case study | **Nites** design-integrated permanent lighting | Architect retains design control; Brite handles spec + install |
| Builders & Developers | Launches amenity center or community clubhouse | **Nites** community-amenity lighting package | Amenity becomes a marketable feature for the sales office |
| Universities | Expands homecoming / reunion weekend infrastructure | **Nites** seasonal campus lighting overlay | Event budget is typically underspent on ambiance |

**Exploring (8):**

| Vertical | Observed investment | Brite adjacent offering | Why |
|---|---|---|---|
| Casinos | Expands non-gaming entertainment revenue | **Labs** event lighting + programmable shows | Non-gaming is the new growth vector in Vegas + regional markets |
| Hotels & Resorts | Launches winter or "hotel as destination" package | **Nites** seasonal + **Labs** programmable | Package price supports the lighting CAPEX without per-room economics |
| Bars & Restaurants | Wins press for "design-forward" atmosphere | **Labs** experiential custom lighting | Press positions them to defend premium rates; lighting is the moat |
| Event Venues | Adds wedding-season capacity or peak-date inventory | **Labs** customizable event-lighting package | Couples buy photos, not chairs — lighting is what photographs |
| Auto Dealerships | Expands service bays or adds EV charging | **Labs** bold exterior + **Nites** holiday lighting | Visible investment = brand confidence signal for the lot |
| Ski Resorts | Invests in village retail or F&B tenancy | **Labs** après-ski ambient + **Nites** seasonal façade | Village is the retention play beyond lift-ticket revenue |
| Country Clubs / Golf Courses | Builds wedding / event hosting business | **Nites** seasonal + **Labs** event lighting | Member-event calendar needs a yearly refresh; lighting is the cheapest swap |
| Corporate Campuses | Launches hybrid-work amenity refresh | **Nites** exterior seasonal + **Labs** experiential interior | Perk parity vs WFH — amenity must photograph well |

**Future (9):**

| Vertical | Observed investment | Brite adjacent offering | Why |
|---|---|---|---|
| Theme Parks / Amusement Parks | Adds after-dark ticketed event | **Labs** creative-production partnership | The event IS the headline; lighting is the event |
| Sports Stadiums | Launches off-season event calendar | **Labs** programmable lighting rig | Off-season economics need event differentiation to move tickets |
| Zoos / Aquariums | Runs ticketed night event | **Labs** animal-safe programmable lighting | Night event is incremental revenue; lighting is the merchandisable product |
| Botanical Gardens / Arboretums | Launches annual light festival | **Labs** creative-direction + programmable install | Festival headline = lighting spectacle; redesign yearly |
| Historic Sites / Landmarks | Runs seasonal nighttime programming | **Labs** heritage-sensitive lighting | Programming requires reversible, preservation-board-approvable fixtures |
| Shopping Centers / Malls | Invests in "experiential retail" anchor replacement | **Nites** common-area seasonal + **Labs** anchor-tenant customization | Foot traffic is the KPI; ambiance is the differentiator |
| Wineries / Vineyards / Breweries | Adds overnight stays or event venue | **Labs** estate-integrated ambient + **Nites** seasonal | Hospitality revenue requires ambiance; wine commodity economics require it |
| Churches / Houses of Worship | Capital campaign for outreach / community visibility | **Nites** exterior seasonal + interior candlelight overlay | Stewardship goal is visible community presence; lighting reads as investment |
| Hospitals / Healthcare | Capital campaign for patient-experience or healing-environment | **Nites** permanent ambient + seasonal donor recognition | Donor campaign is the budget lever; patient-experience KPIs reward mood design |

---

## Brite Implementation

This section translates the three methodology frameworks into Brite's concrete stack — which MCP, which rule, which repo. Every rule cites its source (ADR, integration guide, or design doc) so a skill reader can trace the claim.

### Tools this skill calls

| What the skill needs to do | MCP / tool | Reaches | Reason (ADR / source) |
|---|---|---|---|
| Salesforce availability check before any SF mutation or read | Salesforce MCP (`run_soql_query` — `SELECT Id FROM User LIMIT 1`) | `brite-salesforce` | ADR 2c — availability probe; `salesforce.md` §MCP Tool Reference; BC-5534 findings Q1 |
| Existing-account lookup on the prospect domain | Salesforce MCP (`run_soql_query` on Account by website domain match) | `brite-salesforce` | ADR 2a — SF is CRM SoR; `salesforce.md` §Common workflows → account lookup |
| Fetch internal signals for existing accounts | Salesforce MCP (`run_soql_query` on Activity history, Opportunity history, `Account_Notes__c`, `Lifecycle_Stage_History__c`) | `brite-salesforce` | Internal-signal enrichment path; BC-5824 issue body §Scope |
| Six parallel public research queries | `WebSearch` | Public web | §3 Methodology — one query per `references/research-processes/find-*.md` PRIMARY pattern |
| Deep-read a single page when snippet is insufficient | `WebFetch` | Public web | Backup only; use sparingly to avoid burning context |
| Firmographic fallback (size / funding / tech-stack) | Brite enrichment MCP (`mcp__plugin_marketing_enrichment__*`) | Brite enrichment service | Tertiary — availability check first; **skip block if MCP unavailable** (BC-5538 ships the integration guide; until then, degrade gracefully) |
| Write the output artifact | `Write` | `docs/research/situations/{domain}-{YYYY-MM-DD}.md` | §6 Runbook output artifact shape |

**Wildcard form per ADR 2c** — `allowed-tools` uses `mcp__plugin_marketing_salesforce__*` and `mcp__plugin_marketing_enrichment__*` because the skill reads across multiple SOQL object types (Account, Activity, Opportunity, Account_Notes__c, Lifecycle_Stage_History__c) and would call multiple enrichment tools depending on what's missing. Narrower cherry-picking would couple the frontmatter to SOQL and enrichment-tool taxonomies that will evolve.

**TODO(BC-5538):** once `plugins/marketing/tools/integrations/brite-enrichment.md` ships, cross-link this skill as a consumer and replace "until then, degrade gracefully" with a pointer to the enrichment availability-check section.

### Architectural rules that apply

- **Salesforce is the CRM system of record** — never cache SF data in the output artifact beyond the `generated_at` timestamp; always re-query on artifact refresh (ADR 2a; `salesforce.md` §Auth).
- **Enrichment is tertiary** — availability check before any enrichment call; if unavailable, the skill continues without enrichment rather than halting (ADR 2c degradation policy; D2 in `docs/designs/bc-5824-situation-mining.md`).
- **Research queries are the PRIMARY surface** — never invent queries. Use only the PRIMARY patterns from `plugins/marketing/references/research-processes/find-*.md`. Respect the "do not search" kill list in each file (ADR 2d; `references/research-processes/README.md`).
- **Hypothesis framing is non-negotiable** — output labels every inference with HYPOTHESIS framing, never with fact-claim framing. Source citation on every data point, inline (§3 Methodology; §8 Anti-Slop).
- **Handbook canon governs vertical / ICP / persona decisions** — never infer outside the 23-vertical taxonomy (6 Active + 8 Exploring + 9 Future, Nites + Labs only). Supply verticals are out of scope per handbook (BC-5823 precedent; D4 in `docs/designs/bc-5824-situation-mining.md`).

### Cross-skill boundaries

- **Hands off to `creative-angles` Deep Mode** when the operator wants pattern-based angles on top of the diagnostic per-prospect angles — the situation artifact stays in the conversation context so `creative-angles` can read it without re-query.
- **Hands off to `email-copywriting`** when the operator has chosen an offer tier and wants Email-Bison-formatted subject + body — pass the situation artifact plus the tier selection; `email-copywriting` emits the JSON artifact that `/marketing:launch-campaign` consumes.
- **Receives from `list-building`** (optional) — the operator can invoke this skill on one domain from a list output; also invoked directly with `company_name` + `domain`.
- **Does not own list-level operations** (that's `list-building`), **does not own pattern-based reusable angles** (that's `creative-angles`), **does not own email copy** (that's `email-copywriting`), **does not own launch execution** (that's the `/marketing:launch-campaign` command).

---

## MCP Tool Reference

"When you need to X, call `tool_name`." Grouped by workflow, not by server. Connection details live in the integration guides — this section names tools semantically.

### Workflow 1 — Six-source parallel research (always runs)

No MCP availability check needed — `WebSearch` is always available.

Run all six queries in parallel (single turn, six `WebSearch` tool calls). Each uses the PRIMARY query pattern from the corresponding `plugins/marketing/references/research-processes/find-*.md` file. Substitute `{{company_name}}`, `{{domain}}`, and (when known) `{{category}}` before executing.

1. `find-profiles.md` — `{{company_name}} {{category}} company overview`
2. `find-founders.md` — `{{company_name}} CEO OR founder interview OR podcast`
3. `find-hiring.md` — `{{company_name}} careers`
4. `find-growth-signals.md` — `site:{{domain}} blog OR pricing OR newsletter OR demo OR "free trial" OR "book a call"`
5. `find-competitors.md` — `{{company_name}} competitors`
6. `find-negativity.md` — `{{company_name}} {{category}} complaints OR "negative reviews" OR problems OR issues`

On `WebSearch` rate-limit or transient failure for any single query, retry once with exponential backoff. If still failing, proceed with the remaining queries and mark the missing source in the output artifact — degrade to MEDIUM or LOW confidence per §3 Confidence decision rule.

When a search snippet is insufficient and a full page is the primary source for a claim, call `WebFetch` on the specific URL. Do not use `WebFetch` as a default — snippet analysis is usually enough.

### Workflow 2 — Existing-account Salesforce enrichment (conditional)

Runs **only** when §2 Before Starting detected an existing Account for the prospect `domain`. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) for auth, tool names, and SOQL gotchas.

1. **Availability check:** call `run_soql_query` with `SELECT Id FROM User LIMIT 1`. On failure, HALT this workflow — do NOT fabricate internal-signal data. Fall back to Workflow 1 output only; flag in the artifact as `sf_enriched: false` and note the MCP failure. (Per BC-5534 findings §Q1, this query is the verified liveness check; `get_username` is NOT valid.)
2. **Account lookup:** call `run_soql_query` with `SELECT Id, Name, Lifecycle_Stage_History__c, Account_Notes__c FROM Account WHERE Website LIKE '%{{domain}}%' LIMIT 5`. If zero results, the skill's §2 detection was stale — abort enrichment and mark `sf_enriched: false`.
3. **Activity history:** for the matched Account ID, call `run_soql_query` with `SELECT Id, ActivityDate, Subject, Description FROM ActivityHistory WHERE AccountId = '{{accountId}}' ORDER BY ActivityDate DESC LIMIT 20`. Use to ground outreach recency.
4. **Opportunity history:** call `run_soql_query` with `SELECT Id, Name, StageName, CloseDate, Amount FROM Opportunity WHERE AccountId = '{{accountId}}' ORDER BY CloseDate DESC LIMIT 10`. Surfaces lapsed deals, territory changes, and past commitment levels.
5. **Lifecycle + notes:** already in step 2 via `Account_Notes__c` + `Lifecycle_Stage_History__c` on the Account. Pass these text fields to §3 inference as **internal signals** alongside the public-source data points.

All SF calls are read-only — no MCP confirmation gates needed.

### Workflow 3 — Firmographic fallback (tertiary, graceful degradation)

Runs when Workflow 1 leaves firmographic gaps (company size, funding, tech stack) that affect inference quality and the operator has asked for higher confidence.

1. **Availability check:** pre-flight the enrichment MCP with the canonical liveness probe from `brite-enrichment.md` — currently pending BC-5538; until then, treat any `mcp__plugin_marketing_enrichment__*` error as "MCP unavailable" rather than a crash. **TODO(BC-5538):** replace this paragraph with a pointer to `brite-enrichment.md` §Availability check once the guide ships.
2. **On MCP unavailable:** SKIP this workflow entirely. Log a single-line warning to the user ("Enrichment MCP unavailable — proceeding with public-source inference only"). Do NOT halt the skill. Mark `enrichment_used: false` in the output artifact frontmatter.
3. **On MCP available:** call the relevant enrichment tool(s) per `brite-enrichment.md` (once shipped). Pass firmographic results to §3 inference as additional data points, each labeled with `source: enrichment` inline.

The skill MUST continue producing a complete artifact with or without Workflow 3 — enrichment is additive, never a blocker.

---

## Operational Runbook

Five flows — the common paths operators actually run. Each flow states preconditions, steps (referencing §5 Workflows by name), expected output, error handling, and cross-skill handoff. The output artifact shape is shared across flows and documented at the end of this section.

### Flow 1 — Standard prospect research (new prospect, no Salesforce match)

**Preconditions:**
- `docs/marketing-context.md` exists and identifies the Brite entity.
- §2 Before Starting ran and found no existing Account for the prospect `domain`.
- `company_name` and `domain` are both supplied; name is unambiguous.

**Steps:**
1. Run §5 Workflow 1 — six-source parallel research.
2. (Optional) Run §5 Workflow 3 — firmographic fallback, if public sources leave gaps and the operator wants higher confidence. Skip on MCP unavailable.
3. Apply §3 worldview inference matrix to data points — for each matched signal, record the inferred worldview + messaging implication with source citation.
4. Apply §3 adjacent-offering logic — for each observed investment matching the handbook verticals, record the Brite adjacent offering.
5. Generate 3–4 diagnostic message options, each with (a) "why it works" evidence chain citing specific data points by source, (b) "what to avoid," (c) HIGH / MEDIUM / LOW confidence per §3 rule.
6. Write the output artifact to `docs/research/situations/{domain}-{YYYY-MM-DD}.md` using the artifact shape below.
7. Offer handoff to `creative-angles` Deep Mode or `email-copywriting`.

**Expected output:** completed artifact with 3–4 message options, confidence ratings, source URLs on every claim. `sf_enriched: false`.

**Error handling:** see §5 for per-workflow degradation. If fewer than 3 sources yield usable data, drop to Flow 4 (thin-data).

**Handoff:** `creative-angles` Deep Mode or `email-copywriting`.

### Flow 2 — Existing-Salesforce-account deep dive

**Preconditions:**
- §2 Before Starting matched the prospect `domain` to a Salesforce Account.
- `docs/marketing-context.md` exists.

**Steps:**
1. Run §5 Workflow 1 — six-source parallel research (public signals).
2. Run §5 Workflow 2 — existing-account Salesforce enrichment (internal signals: Activity, Opportunity, notes, lifecycle).
3. Apply §3 worldview inference matrix. **Internal signals carry higher weight** — an Opportunity lapsed 6 months ago beats a LinkedIn job posting for recency.
4. Apply §3 adjacent-offering logic. Reference lapsed opportunities, territory changes, or note-recorded objections explicitly in angle selection.
5. Generate 3–4 diagnostic messages, each anchored to at least one public + one internal signal where possible. Use internal-signal angles (e.g. "Reference the lapsed Q3 opportunity on {Account_Notes__c mention}") at HIGH confidence.
6. Write artifact with `sf_enriched: true` plus an `internal_signals` frontmatter block listing which SF object IDs grounded the inference.
7. Offer handoff.

**Expected output:** artifact with internal-signal-grounded angles at HIGH confidence; public-only angles at MEDIUM-LOW.

**Error handling:** if Workflow 2 availability check fails, degrade to Flow 1 with a warning — do NOT fabricate internal-signal data.

**Handoff:** `creative-angles` Deep Mode or `email-copywriting`.

### Flow 3 — Ambiguous company name clarification

**Preconditions:**
- `company_name` is common (e.g. "Apex", "Summit", "Pinnacle", single-word generic terms) AND no `category` hint supplied AND `domain` does not unambiguously disambiguate.

**Steps:**
1. PAUSE before any searches. Report to user: "The name '{company_name}' could refer to multiple entities. Supply a `category` hint (e.g. 'municipal lighting consultancy', 'hospitality group') or a more specific identifier."
2. If user supplies clarification, return to Flow 1 or Flow 2 with the disambiguated inputs.
3. If user declines clarification, abort with a clear message — do NOT burn the six-query budget on a guess.

**Expected output:** no artifact written; skill reports the ambiguity and awaits clarification.

**Error handling:** none — this is a precondition-violation path, not a failure path.

**Handoff:** none; the skill resumes Flow 1 / Flow 2 after disambiguation.

### Flow 4 — Thin-data / low-signal fallback

**Preconditions:**
- Flow 1 (and optionally Flow 3 firmographic enrichment) completed, but <2 sources returned usable data. Common for small private companies, new entities, or verticals with limited public presence.

**Steps:**
1. Write artifact with confidence: LOW in frontmatter.
2. Generate 1–2 angle options (not 3–4), each with HYPOTHESIS framing explicitly labeled.
3. Add a §Recommendations section noting: "Thin public signal — before running outreach, revisit ICP fit, run list-building against handbook-canon verticals, or deprioritize this prospect."
4. Flag in the artifact that a manual operator pass is advised before any send.

**Expected output:** artifact with 1–2 speculative angles at LOW confidence + an explicit ICP-review recommendation.

**Error handling:** if even 1 source fails, abort with "insufficient data to produce actionable diagnostic output."

**Handoff:** skip handoff to `email-copywriting` — offer `list-building` instead.

### Flow 5 — Hand off to downstream skills

**Preconditions:**
- A completed artifact from Flow 1 or Flow 2 exists in conversation context.

**Steps:**
1. Present the two handoff options to the operator:
   - **To `creative-angles` Deep Mode** — for pattern-based angles (inversion, adjacent transfer, timing arbitrage, specificity escalator, ecosystem gap) layered on top of these diagnostic angles. Situation artifact stays in context; `creative-angles` reads it and produces an Asymmetry-Scored angle list.
   - **To `email-copywriting`** — for Email-Bison-formatted subject + body sequences. Pair the situation artifact with an offer tier (T1 Knowledge / T2 Free Asset / T3 DFY Trial / T4 Risk Reversal); `email-copywriting` emits the JSON artifact that `/marketing:launch-campaign` consumes.
2. If neither fits, the operator can save the artifact and invoke a downstream skill later — the file path is stable.

**Expected output:** a one-sentence summary to the operator ("Situation artifact saved to {path}; handoff options are creative-angles Deep Mode or email-copywriting").

**Error handling:** none — this is a pure control-flow flow.

**Handoff:** per operator's choice.

### Output artifact shape

Every flow that produces an artifact writes to `docs/research/situations/{domain}-{YYYY-MM-DD}.md`. Frontmatter:

```yaml
---
domain: example.com
company_name: "Example Co"
generated_at: 2026-04-20T14:30:00Z
entity: brite-nites | brite-labs  # Nites or Labs only; Supply excluded per handbook
vertical: municipalities | hoas | ... | hospitals-healthcare  # from handbook 23-vertical list
confidence: HIGH | MEDIUM | LOW
sf_enriched: true | false
enrichment_used: true | false
research_sources: [find-profiles, find-founders, find-hiring, find-growth-signals, find-competitors, find-negativity]
internal_signals: [ "Account:0011a00000xyz", "Opportunity:0061b00000abc" ]  # omit if sf_enriched: false
---
```

Body sections (in order):

1. **Raw Data** — one bullet per source (public + internal). Each bullet cites source URL or SF object ID inline.
2. **Situations** — 2–5 worldview inferences. Each inference names the matched §3 matrix row + supporting evidence.
3. **Diagnostic Messages** — 3–4 options (or 1–2 in Flow 4). Each includes Subject concept, Body concept, Why it works, What to avoid, Confidence.
4. **Recommendations** — best-angle pick, avoid list, hypothesis-to-test, personalization hook, next actions (handoff or manual step).

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | Artifact applies all three §3 frameworks (six-source research, worldview inference, adjacent-offering); every inference is HYPOTHESIS-framed with mandatory prefix; every data point carries a source URL or SF object ID inline; HIGH / MEDIUM / LOW confidence picked per the §3 Confidence decision rule and is reproducible by a reviewer; if Salesforce Account matched the domain, Workflow 2 ran and internal signals appear in the `internal_signals` frontmatter list; if no match, artifact is explicit with `sf_enriched: false`; entity + vertical in frontmatter are from the handbook canon; all 3–4 angles (or 1–2 in thin-data) include "why it works" + "what to avoid." |
| 7-9 | Mostly excellent but one gap — e.g. one angle lacks an explicit "what to avoid" note, or one data point cites source correctly but the chain-of-inference framing is weak; confidence is plausible but could be argued one notch in either direction; entity/vertical match handbook but the match is a stretch. |
| 4-6 | Functional but missing structural elements — e.g. applies §3 matrices but skips framing phrases on 30%+ of inferences, OR cites sources inconsistently, OR produces 5+ angles instead of 3–4 (over-generation), OR forgets the SF availability check when an Account existed, OR writes confidence levels that cannot be derived from the §3 rule. |
| 1-3 | Fact-claim framing instead of hypothesis ("They are…"), fabricated evidence not in any source, generic B2B copy ignoring handbook verticals, Supply-vertical triggers (installers / property mgmt), Serper or Apollo tool references, or halt on enrichment-unavailable instead of degrading. |

---

## Anti-Slop Guardrails

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).
- **Do not frame inferences as facts.** Every inference MUST carry one of the three framing phrases: "Based on public data…", "This suggests…", or "Test this hypothesis…". Fact-claim framing ("They are…", "We know…", "The company is definitely…") is a hard failure — §7 Rubric 1–3 band.
- **Do not produce a data point without a source.** Every claim in the Raw Data, Situations, and Diagnostic Messages sections carries an inline source — URL for public data, SF object ID for internal. An uncited claim is slop and fails §7.
- **Do not manufacture evidence research didn't surface.** If the six searches returned thin data, drop to Flow 4 (thin-data fallback) with LOW confidence and 1–2 angles — do NOT invent the missing signal to produce a complete-looking artifact.
- **Do not invent research queries.** Use ONLY the PRIMARY query patterns from `plugins/marketing/references/research-processes/find-*.md`. Making up a new query is out of scope for this skill and raises a separate issue against the references library.
- **Do not skip the Salesforce existence check.** When a `domain` is supplied, always run the Workflow 2 availability + Account lookup first. Skipping it means the existing-account enrichment path gets silently lost.
- **Do not infer outside the handbook 23-vertical taxonomy.** Never key messaging to Brite Supply triggers (professional installers, property management) — Supply is out of scope per handbook. Never introduce a vertical not in the handbook 6 Active + 8 Exploring + 9 Future set.
- **Do not halt on enrichment-MCP unavailability.** Workflow 3 degrades gracefully — log warning, continue, mark `enrichment_used: false`. Halting produces no artifact and is worse than a MEDIUM-confidence artifact.

---

## Behavioral Tests

Six scenarios covering the core paths. Structured assertions + expected-output details live in `evals/evals.json` alongside this file.

### Tier 1 — Free assertions (no tool calls needed)

- **Happy path (new prospect, dense signal).** Given `company_name: "Denver Parks & Rec"`, `domain: "denvergov.org"`, `category: "municipalities"`, the skill output contains a §Diagnostic Messages section with 3–4 options; every inference in §Situations is prefixed with one of "Based on public data…", "This suggests…", or "Test this hypothesis…"; confidence in frontmatter is HIGH or MEDIUM and references the §3 Confidence decision rule.
- **Thin-data / low-signal fallback.** Given a small private prospect with minimal public presence, the skill output contains confidence: LOW in frontmatter, 1–2 message options (not 3–4), and a §Recommendations section that advises ICP review / list-building before outreach.
- **Ambiguous name — skill pauses.** Given `company_name: "Apex"` with no `category` and a domain that resolves to multiple entities, the skill's first response does NOT include any `WebSearch` tool calls — it reports the ambiguity and asks the operator for a category hint.
- **Anti-slop compliance.** Given any input, the output does NOT contain em-dashes in diagnostic message body text (deliverability trigger), does NOT contain "synergy" / "leverage" / "best-in-class", does NOT reference Serper or Apollo, and does NOT key any message to installer-hiring, property-management, or other Supply triggers.

### Tier 2 — Tool-assisted (requires file read or MCP call)

- **Existing Salesforce account — internal signals surface.** Given a prospect whose domain matches a Brite Salesforce Account with a lapsed Opportunity, the skill's output artifact has `sf_enriched: true`, `internal_signals` lists at least one `Opportunity:` ID, and at least one diagnostic message in §Diagnostic Messages references the lapsed-Opportunity evidence chain at HIGH confidence.
- **Enrichment MCP unavailable — graceful degradation.** Given a prospect and an enrichment MCP that returns an error on availability check, the skill completes the artifact with `enrichment_used: false` in frontmatter, logs a one-line warning to the operator, and does NOT halt — output still contains 3 or 4 message options derived from public sources alone.

---

<!--
Section ordering validator hint (for future use by scripts/validate.sh):
  Required sections in this order:
    1. Frontmatter
    2. {Skill Title} (H1)
    3. Before Starting (H2)
    4. Methodology (H2)
    5. Brite Implementation (H2) — required if `allowed-tools` present
    6. MCP Tool Reference (H2) — required if `allowed-tools` present
    7. Operational Runbook (H2) — required if `allowed-tools` present
    8. Health Scoring Rubric (H2)
    9. Anti-Slop Guardrails (H2)
   10. Behavioral Tests (H2)

  Sections 5, 6, 7 may be omitted only when `allowed-tools` is absent from frontmatter
  (methodology-only upstream ports).
-->
