# Marketing GTM Expansion — Scoping Plan

Consolidates the 12 Revgrowth1/ai-gtm-workflows workflows against Brite's existing marketing skill inventory and produces a prioritized list of Linear issues (creates + updates + skips) to close the gap between Brite's current execution-heavy surface and the strategic/discovery layer Revgrowth covers.

**Upstream source:** [Revgrowth1/ai-gtm-workflows](https://github.com/Revgrowth1/ai-gtm-workflows) (MIT). 12 SKILL.md workflows + 3 high-leverage reference documents (creative-thinking-models, hidden-signals-library, shelf-life-patterns) + research-processes directory. `pushed_at: 2026-04-10`.

**Current Brite state (as of 2026-04-20):**
- DONE: BC-2707 email-bison meta-orch (PR #139), BC-2718 campaign-orchestration (PR #142)
- PENDING: BC-2717 list-building, BC-2719 deliverability-audit, BC-2720 reply-processing, BC-2721 campaign-analysis, BC-2722 outbound-playbook, BC-2723 linkedin-outreach, BC-2724 event-marketing, BC-2725 lead-routing, BC-2726 marketing-automation, BC-2727 data-enrichment, BC-2728 crm-hygiene
- GAP: zero strategic/discovery skills (no market research, TAM, ICP scoring, GTM strategy, situation-mining, creative angles, MSPA, copywriting, launch glue, debrief)

Revgrowth fills exactly the gap. This plan ports + Brite-adapts their 12 workflows as 10 new Linear issues + 3 updates + 1 fold-in (local-enrichment into tam-mapping). Tools: swap Serper → WebSearch/WebFetch, generic enrichment → brite-enrichment MCP, generic email platform → Email Bison MCPs, generic CRM → Salesforce MCP (`plugin:marketing:salesforce`).

Dependency graph:

```
references (BLOCKS)
  ├─▶ account-research
  │     └─▶ situation-mining ──▶ creative-angles
  │                                     │
  │                                     ▼
  │                             message-market-fit (MSPA)
  │                                     ▲
  │                                     │
  └─▶ tam-mapping ──▶ BC-2717 (update) ─┘
                          ▲
                          │
icp-scoring ◀─ gtm-strategy ──▶ BC-2722 (update)
                  │                     │
                  ▼                     │
       email-copywriting ◀──────────────┘
                  │
                  ▼
       /marketing:launch-campaign (command)
                  │
                  ▼
       (campaigns run)
                  │
                  ▼
       BC-2721 (update, 5-Variables)
                  │
                  ▼
       campaign-debrief ──▶ feeds back into MSPA + references
```

---

## Tier 1 — Tonight-critical infrastructure (ship this week)

Minimum path to "launch a campaign end-to-end with reusable tooling."

### 1.1 NEW: Port marketing references from Revgrowth1/ai-gtm-workflows

**Priority:** High · **Milestone:** Marketing Skills Plugin · **Labels:** `infrastructure`, `content` · **Type:** Content port (no skill/command)

**Goal:** Land `plugins/marketing/references/` with 4 foundational content documents that account-research, situation-mining, creative-angles, tam-mapping, and campaign-debrief all depend on.

**Scope:**
- `references/research-processes/` — port 16 per-dimension validated query files (find-profiles, find-competitors, find-growth-signals, find-hiring, find-news, find-negativity, find-reviews, find-pr-releases, find-founders, find-c-suite, find-vp-leadership, find-directors, find-department-heads, find-specialist-roles, find-people-creative, find-job-role-insights). Replace Serper-specific syntax with WebSearch-agnostic patterns. Preserve stop conditions, kill lists, tier awareness (T1-T4 by company size).
- `references/creative-thinking-models.md` — port 5 forcing functions (Inversion, Adjacent Transfer, Timing Arbitrage, Specificity Escalator, Ecosystem Gap Analysis) with Brite-adapted worked examples.
- `references/hidden-signals-library.md` — port 7 industry tables (SaaS, E-Commerce, Healthcare, FinTech, Manufacturing, Food Service, Real Estate) + add ≥3 Brite-entity-specific extensions (Entertainment Venues for Brite Labs, Landscape/Hardscape Contractors for Brite Supply, HOAs/Property Management for Brite Supply/Nites cross-motion).
- `references/shelf-life-patterns.md` — port 5 decay categories + research-steps-to-discover estimation method verbatim.
- `references/UPSTREAM.md` — MIT attribution per-file + consolidated license note, citing commit SHA of Revgrowth1/ai-gtm-workflows at fetch time.

**Blocks:** All of Tier 1 situation-mining + email-copywriting + Tier 2 account-research/creative-angles/campaign-debrief + Tier 3 tam-mapping (Phase 1 source discovery references find-profiles / find-growth-signals).

**Tool surface:** Bash (gh api fetch), Read, Write, Glob.

**Verification:**
- [ ] ≥16 `research-processes/*.md` files present
- [ ] All 4 top-level reference docs exist with frontmatter: `source: Revgrowth1/ai-gtm-workflows@<sha>`
- [ ] `hidden-signals-library.md` has ≥7 industries + ≥3 Brite-entity extensions
- [ ] UPSTREAM.md lists every ported file + commit SHA + license
- [ ] `./scripts/validate.sh` exits 0

---

### 1.2 NEW: Create marketing skill — situation-mining

**Priority:** High · **Milestone:** Marketing Skills Plugin · **Labels:** `skill` · **Depends on:** 1.1 (references)

**Goal:** Gather public data on a prospect + infer worldview + generate 3-4 diagnostic messaging angles. The "diagnostic over promotional" philosophical anchor of Brite outbound.

**Scope:**
- 6 parallel research searches using PRIMARY query patterns from `references/research-processes/` (find-profiles, find-founders, find-hiring, find-growth-signals, find-competitors, find-negativity)
- Worldview inference matrix: 10 data-point patterns → messaging implications (from Revgrowth 05)
- Adjacent offering logic: 5 "investing in → adjacent offering" mappings
- Output: 3-4 diagnostic messages, each with (a) why it works, (b) what to avoid

**Brite differential:**
- When prospect is an existing SF account, enrich with SF-known data (touches, opportunities, Account_Notes__c) via `mcp__plugin_marketing_salesforce__*`
- Entity-aware output: messaging angles tailored to Brite Nites / Supply / Labs ICPs

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
mcp__plugin_marketing_enrichment__*
WebSearch
WebFetch
Read
Write
Glob
```

**Template:** 9-section outbound skill template (ADR 2f). Behavioral tests ≥6 scenarios. Evals ≥6.

**Handoff interface:** output markdown saved to `docs/research/situations/{domain}-{YYYY-MM-DD}.md` with structured sections (Raw Data / Situations / Diagnostic Messages / Recommendations). Consumed by creative-angles (Deep Mode) and email-copywriting.

**Blocks:** creative-angles Deep Mode, email-copywriting (upstream angle input).

---

### 1.3 NEW: Create marketing skill — email-copywriting

**Priority:** High · **Milestone:** Marketing Skills Plugin · **Labels:** `skill` · **Depends on:** 1.2 (situation-mining), BC-2718 (done, context for sequence mechanics)

**Goal:** Generate Email Bison-formatted subject + body for step 1 + step 2 from a situation-mine output + offer tier selection + optional GTM messaging pillars.

**Scope — EB API format rules (non-negotiable, cite Revgrowth 10):**
- `{VARIABLE}` uppercase single braces — NEVER `{{variable}}` or lowercase
- `<br><br>` between paragraphs — NEVER `<p>` tags
- Single `<br>` before sign-off: `{Best|Cheers},<br>{SENDER_FIRST_NAME}`
- Greeting merged with first sentence (no separate "Hi Name,")
- Spintax `{option1|option2|option3}` every 3-5 words
- 2-step sequence MAX
- First step `wait_in_days: 1` minimum (NOT `wait_days`)
- NO em-dashes (use commas / periods / hyphens)
- Subject line: 1-3 words, 3 spintax options, no `{FIRST_NAME}` in subjects

**Scope — messaging frameworks:**
- Hormozi value equation: `Value = (Dream Outcome × Perceived Likelihood) / (Time Delay × Effort/Sacrifice)`
- Offer tiers: T1 Knowledge/Audit, T2 Free Asset, T3 DFY Trial, T4 Risk Reversal
- Offer selection by client type matrix
- Recency Waterfall: New job > LinkedIn post > Company news > CEO podcast > Company post > Fallback
- Before writing: What to GIVE free / Best case study w/ numbers / What guarantee / Time-to-value

**Brite differential:** entity-aware (Nites residential vs Supply commercial vs Labs venue partnership tone differs). Loads entity copy conventions from `docs/marketing-context.md`.

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
Read
Write
Glob
Grep
```
(Explicitly NO EB MCP tools — pure copy generation, no external state mutation.)

**Handoff interface:** emits JSON artifact:
```json
{
  "step_1": {"subject": "...", "body": "...", "wait_in_days": 1},
  "step_2": {"subject": "...", "body": "...", "wait_in_days": 3},
  "custom_variables": [{"name": "HOOK", "default": "..."}],
  "offer_tier": 3,
  "template_ref": "list-building|risk-reversal|custom"
}
```
Consumed directly by `/marketing:launch-campaign` command.

**Blocks:** `/marketing:launch-campaign` command (feeds copy artifact).

---

### 1.4 NEW: Build /marketing:launch-campaign command

**Priority:** High · **Milestone:** Marketing Skills Plugin · **Labels:** `command`, `infrastructure` · **Depends on:** 1.3 (email-copywriting artifact), BC-2707 (done, gate-semantics precedent)

**Goal:** The missing glue between BC-2718 (platform config) and "emails actually send." Command (not skill) because it mutates external state, orchestrates a procedural flow, and needs explicit user confirmation at each gate.

**Scope — 11-phase flow, each phase a user gate per BC-2707 two-call MCP confirmation-gate precedent:**
1. PRE-FLIGHT: CSV schema validation (email + first_name + company_domain required), row count, workspace selection (`emailbison-b2b` or `emailbison-personal`), dry-run preview
2. HOST LOOKUP: tag leads by ESP (Google / Microsoft / Proofpoint / Mimecast / Custom / Unknown), show segmentation plan
3. VARIABLES: `POST /api/custom-variables` — show what will be created
4. UPLOAD: `bulk_create_leads` with `custom_variables` array — two-call confirmation gate
5. CAMPAIGN CREATE: per-segment `create_campaign` — show naming (e.g. `{Niche} | {Target} | {Source} | {Region} | {Size} | {Offer}`)
6. ATTACH LEADS: `attach-leads` endpoint, show counts
7. ATTACH SENDERS: **CRITICAL — paginate sender list, attach ALL connected senders to ALL campaigns, VERIFY count match post-attach. Never split/chunk senders across campaigns.**
8. SCHEDULE: `create-schedule-from-template` — show schedule (default Mon-Fri 08:00-17:00 local)
9. SEQUENCE: `sequence-steps` from email-copywriting artifact (2 steps)
10. PREVIEW: pull one lead preview email from EB, show to user for sanity
11. ACTIVATE (optional): `PATCH /resume` — explicit double-confirm gate (sends emails)

**Invariants encoded as guardrails:**
- Pre-launch validation: extract all `{VARIABLE}` from copy, verify lead fields populated
- Messaging sanity checklist: value first? specific outcome? risk reversal? social proof? clear CTA? spintax balanced?
- Lead spot check: sample 3-5 rows before proceeding to UPLOAD
- Unique-per-lead variables: auto for <500 leads (Josh Braun framework)

**Tool surface:**
```
mcp__emailbison-b2b__*
mcp__emailbison-personal__*
mcp__plugin_marketing_salesforce__*
Read
Write
Glob
Grep
Bash
```

**File location:** `plugins/marketing/commands/launch-campaign.md` (NOT skills/). Follow existing command patterns (e.g. `/marketing:setup-email-bison`).

**Handoff interface:** on successful activate, writes campaign metadata to `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json` for later debrief consumption.

**Blocks:** campaign-debrief (consumes launch metadata).

---

### 1.5 UPDATE: BC-2722 outbound-playbook — de-Clay + align to GTM-strategy

**Priority:** Existing (High) · **Touch:** Low

**Changes:**
- Remove `Clay` references — Clay deprecated 2026-04-14 per `memory/project_clay_deprecated.md`. Replace with "brite-enrichment MCP + brite-data-platform audience views."
- Clarify consumption relationship: "BC-2722 CONSUMES gtm-strategy output (segments/personas/messaging pillars), does not produce it from scratch."
- Add cross-links to MSPA (message-market-fit) for the barbell 80/20 allocation philosophy and to creative-angles for the 20% experiment allocation.
- Update Tool Integration block to replace `Clay, Email Bison, Dialpad, OutboundSync, Master Inbox, Salesforce` with `Brite enrichment MCP, Email Bison MCPs (b2b + personal), Dialpad (manual), OutboundSync, Master Inbox, Salesforce MCP`.

**Implementation:** Linear description edit + comment noting rationale.

---

## Tier 2 — Compound-value (ship next 2 weeks)

### 2.1 NEW: Create marketing skill — account-research

**Priority:** High · **Depends on:** 1.1 (references)

**Goal:** Thin orchestrator over `references/research-processes/` — runs validated search patterns in configurable modes (profiles / full / deep / people / growth / hiring / reviews / negativity), produces structured company intelligence.

**Distinct from situation-mining:** account-research outputs FACTS grouped by dimension (who/what/where/when). situation-mining outputs INFERRED WORLDVIEWS + angle hypotheses.

**Input:** `company_name` (required), `domain` (required), `category` (optional), `mode` (default `profiles`).

**Modes:** match Revgrowth 01 (profiles / competitors / growth / hiring / reviews / news / negativity / founders / c-suite / full / deep / people).

**Brite differential:** when prospect is existing SF account, enrich with SF-known data before running web searches. Output saved to `docs/research/accounts/{domain}-{YYYY-MM-DD}.md`.

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
WebSearch
WebFetch
Read
Write
Glob
```

**Template:** 9-section outbound skill template.

---

### 2.2 NEW: Create marketing skill — creative-angles

**Priority:** Medium-High · **Depends on:** 1.1 (references), 1.2 (situation-mining for Deep Mode)

**Goal:** Generate ranked creative outbound angles from hidden signals using lateral thinking. The "right-brain" complement to standard campaign ideation. 10% experiment allocation per barbell strategy.

**Scope — Quick Mode:**
- 5 parallel research searches (blog, reviews/complaints, competitors, regulation, hiring)
- Signal cluster extraction (≥2 data points per cluster, combined inference = non-obvious takeaway)
- Apply 5 forcing functions from `references/creative-thinking-models.md`
- 3-5 angles with Asymmetry Score

**Scope — Deep Mode:**
- Requires situation-mining output for the domain (<14 days old)
- 7 additional research searches (G2/Trustpilot, events, regulation deep, partnerships, senior hiring, financial signals, Reddit/HN)
- Worldview conflict analysis (stated worldview vs contradicting signal = the richest angles)
- Cross-reference `references/hidden-signals-library.md`
- 5-8 angles with Asymmetry Score + mandatory shelf-life warning on ALPHA/PROMISING

**Asymmetry Score formula:** `(Novelty×2 + Evidence×2 + Timing×1.5 + Simplicity×1 + ShelfLife×1 + Downside×0.5) / 8`
- Verdicts: ALPHA (8.0+) → test immediately, PROMISING (6.0-7.9) → refine, INTERESTING (4.0-5.9) → redirect to content, COMMODITY (<4.0) → discard

**Brite differential:** hidden-signals-library extended with Brite-entity rows. Output references Brite campaign infra for "Data Collection Methodology" per angle (TAM source, enrichment strategy, EB workspace).

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
WebSearch
WebFetch
Read
Write
Glob
```

---

### 2.3 NEW: Create marketing skill — message-market-fit (MSPA)

**Priority:** Medium-High · **Depends on:** 2.4 gtm-strategy (Tier 3, for MAP mode input) + BC-2721 update (Tier 2.5, for ITERATE mode input)

**Goal:** Systematic experiment design + iteration + diagnosis framework. Kellen Casebeer MSPA methodology (Market × Segment × Persona × Angle). Barbell 80/20 allocation.

**3 modes:**
- **MAP** (new market entry): pipeline environment check → 3-lens analysis → MSPA matrix → first 5-experiment batch → hypothesis cards → barbell allocation
- **ITERATE** (post-results): classify each experiment SCALE / ITERATE / KILL → read replies qualitatively → design next batch
- **DIAGNOSE** (stuck pipeline): run Market → Segment → Persona → Angle → Execution diagnostic sequence → root cause + prescription

**Output files:** `docs/campaigns/{entity}/mmf-matrix.md`, `docs/campaigns/{entity}/mmf-batch-{N}.md`, `docs/campaigns/{entity}/mmf-results-{N}.md`.

**Kellen's Laws (encoded as guardrails):** resonance beats personalization; identity beats information; groups are cultural not demographic; silence is data; never stop the experiment side; qualitative > quantitative for early-stage testing.

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
mcp__emailbison-b2b__*
mcp__emailbison-personal__*
WebSearch
Read
Write
Glob
```

---

### 2.4 NEW: Create marketing skill — campaign-debrief

**Priority:** Medium · **Depends on:** BC-2721 update (Tier 2.5)

**Goal:** Structured 5-question post-campaign learning capture that closes the loop between execution and intelligence. Marketing-specific parallel to the workflows plugin's decision-trace / compound-learnings pattern.

**5-question debrief (≤5 minutes to complete, suggested answers from data, user confirms/overrides):**
1. What hypothesis did we test?
2. What was the result? (CONFIRMED / PARTIAL / REJECTED)
3. What worked and what didn't?
4. What surprised us?
5. What's transferable? (entity-specific vs universal pattern)

**Verdict:** SCALE / ITERATE / PAUSE / KILL based on concrete criteria.

**Append to:** `docs/campaigns/{entity}/learnings.md` (entity-keyed, append-only).

**Tags:** `#entity/{e}`, `#vertical/{v}`, `#persona/{p}`, `#angle/{a}`.

**Transferable insight flow:** when tagged transferable, propose update to `docs/marketing-context.md` or flag for handbook update. Integrates with future BC-1993 flywheel monitoring (emits same YAML schema as decision traces so marketing campaigns count in the flywheel too).

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
mcp__emailbison-b2b__*
mcp__emailbison-personal__*
Read
Write
Glob
```

---

### 2.5 UPDATE: BC-2721 campaign-analysis — add 5-Variables framework

**Priority:** Existing (raise to High from Medium) · **Touch:** Medium

**Changes:**
- Add 5 Core Variables framework (Offer / Message / Segment / Infrastructure / Timing) as primary diagnostic lens
- Add 4-phase analysis structure (Hypothesis → Data Collection → Analysis → Recommendations)
- Add 6-section report structure (Health Check / Segment Ranking / Infrastructure / Reply Sentiment / Attribution / Next Iteration)
- Add concrete benchmarks: `>1% reply = Healthy, 0.5-1% = Attention, <0.5% = Critical`; `>25% interested rate = Healthy`; `<3% bounce = Healthy`
- Add verdict mapping: TOP PERFORMER / SCALE / TEST MORE / MONITOR / UNDERPERFORM with specific criteria
- Add mandatory post-analysis handoff to campaign-debrief (Tier 2.4)
- Add conditional handoff to BC-2719 deliverability-audit when Infrastructure variable is suspect (bounce spike, Google vs Microsoft disparity)
- Keep existing scope (attribution, funnel, cohort) — no removal

**Implementation:** Linear description edit + rationale comment citing Revgrowth 11 as reference.

---

## Tier 3 — Strategic upstream (ship over 2-3 weeks)

### 3.1 NEW: Create marketing skill — icp-scoring

**Priority:** Medium · **Depends on:** `docs/marketing-context.md` (exists)

**Goal:** Score prospect lists 0-100 against ICP criteria. Pre-outreach prioritization layer. Distinct from BC-2725 lead-routing (which is post-reply SF assignment).

**Scoring rubric:** 80-100 Strong Match, 60-79 Likely Match, 40-59 Partial Match, 0-39 Poor Match. Configurable threshold (default 70) splits qualified/disqualified output.

**ICP criteria sources:** (1) `docs/marketing-context.md` per entity, (2) inline CLI arg, (3) JSON file. Entity-specific criteria supported.

**Flow:** read CSV → load ICP criteria → pre-filter by known columns → parallel-research unknowns (WebSearch + SF MCP + enrichment MCP) → score 0-100 with reasoning → split qualified/disqualified CSVs with added columns `icp_score`, `icp_label`, `icp_reasoning`, `company_summary`.

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
mcp__plugin_marketing_enrichment__*
WebSearch
WebFetch
Read
Write
Glob
Bash
```

---

### 3.2 NEW: Create marketing skill — tam-mapping (absorbs local-enrichment)

**Priority:** Medium · **Depends on:** 1.1 (references Phase 1 source discovery)

**Goal:** Build TAM databases for any Brite motion using Revgrowth's 7-phase methodology. Optimized for Brite Nites (residential/local), Brite Supply (installer/landscape), Brite Labs (venue partnerships). B2B Brite motions already have brite-data-platform dbt audience views — tam-mapping is for verticals dbt doesn't cover.

**7 phases:**
1. Source Discovery (16-category taxonomy)
2. Keyword Expansion (free-count queries before pulling)
3. Config Generation (TAMConfig JSON)
4. Collection (scrapers per source, unified businesses.csv schema)
5. Deduplication (3-tier: domain → name+state → phone)
6. **MANDATORY** Exclusion (against EB workspace lead lists — saves 31.7% of enrichment spend)
7. Enrichment Hand-off (to list-building or directly to email-copywriting)

**Local-enrichment absorbed as Phase 3 source type:** Google Maps ZIP scraping for residential/SMB verticals. Brite uses WebSearch-based maps queries (no Serper).

**Brite differential:** Phase 6 exclusion queries BOTH `emailbison-b2b` AND `emailbison-personal` workspace lead lists. Phase 7 hand-off supports entity-specific downstream path (Nites → launch directly, Supply/Labs → list-building for additional enrichment).

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
mcp__emailbison-b2b__*
mcp__emailbison-personal__*
mcp__plugin_marketing_github__*
mcp__plugin_marketing_enrichment__*
WebSearch
WebFetch
Read
Write
Glob
Bash
```

---

### 3.3 NEW: Create marketing skill — gtm-strategy

**Priority:** Medium · **Depends on:** `docs/marketing-context.md` (exists), ideally 2.1 account-research

**Goal:** 5-phase pipeline producing segments/personas/messaging pillars/offer recommendations for any net-new Brite motion. Distinct from launch-strategy (product launches) and content-strategy (content marketing).

**5 phases:**
1. Research (delegates to account-research for company + competitor intel)
2. TAM Segments — 3-10 segments with weighted scoring: `Size(1x) + Fit(2x) + SalesCycle(1x) + DealValue(1x) + Education(1x)`
3. Deep Dive — 3 personas per segment, PQS rubric, data-sourceability per segment
4. Messaging Pillars (NOT copy) — 2-3 pillars per segment + offer tier recommendation + PQS triggers. Copy generation delegated to email-copywriting (Tier 1.3).
5. Output — `docs/strategy/{entity}-gtm-{YYYY-MM-DD}.md` + proposed updates to marketing-context.md

**Brite differential:** entity-aware. Outputs entity-specific sections when multiple entities share a motion (e.g. cross-sell play between Brite Nites residential and Brite Supply commercial).

**Tool surface:**
```
mcp__plugin_marketing_salesforce__*
mcp__plugin_marketing_github__*
WebSearch
WebFetch
Read
Write
Glob
```

---

### 3.4 UPDATE: BC-2717 list-building — contact-discovery methodology addition

**Priority:** Existing (High) · **Touch:** Low

**Changes:**
- Add "Contact Discovery 3-Step Pipeline" to Methodology section:
  - Step 1: Domain → LinkedIn Company URL
  - Step 2: Waterfall ICP search → decision-maker contacts
  - Step 3: Email waterfall (enrichment MCP → LinkedIn → keyword search fallback)
- Add ICP Title Cascade table with entity-specific adaptations:
  - T1 (default): CEO, Founder, Owner, President, Co-Founder
  - T2: VP Marketing/Sales/Growth, CMO, CRO
  - T3: Marketing/Sales Director, Director of Growth
  - Brite Nites adaptation: Owner, GM (residential) — skip VP cascade
  - Brite Labs adaptation: Venue Director, Events Director, Marketing Manager
  - Brite Supply adaptation: Procurement, VP Ops, Buyer
- Add `max-N-contacts-per-company` heuristic (default 3, configurable)
- Reference cite: Revgrowth1 08-contact-discovery for canonical 3-step shape

**Also:** add upstream reference to tam-mapping (Tier 3.2) — "BC-2717 consumes a TAM output (from tam-mapping or existing dbt audience views) and produces a suppressed + enriched campaign-ready list."

**Implementation:** Linear description edit.

---

## Skipped

- **Revgrowth 09 local-enrichment as standalone skill.** Folded into tam-mapping (Tier 3.2) as Phase 3 source type. If scope later diverges, split out then.

---

## Execution Plan

**Linear mutation count:** 10 new issues + 3 updates = 13 Linear ops.

**Recommended ordering (respects dependency graph):**
1. Create Tier 1.1 references issue (BLOCKER)
2. Create Tier 1.2 situation-mining, Tier 1.3 email-copywriting, Tier 1.4 launch-campaign command
3. Update Tier 1.5 BC-2722
4. Create Tier 2.1 account-research, Tier 2.2 creative-angles, Tier 2.3 MSPA, Tier 2.4 campaign-debrief
5. Update Tier 2.5 BC-2721
6. Create Tier 3.1 icp-scoring, Tier 3.2 tam-mapping, Tier 3.3 gtm-strategy
7. Update Tier 3.4 BC-2717

**Milestone:** All go into "Marketing Skills Plugin" for simplicity. User can re-milestone later if bundle size becomes unwieldy.

**Attribution:** every new issue that ports Revgrowth content cites upstream in its description: `Source: Revgrowth1/ai-gtm-workflows (MIT) workflow NN` + commit SHA.

**Worktree strategy:** each issue gets its own worktree at execution time per standard Brite convention. This scoping doc is the shared reference they all read against.
