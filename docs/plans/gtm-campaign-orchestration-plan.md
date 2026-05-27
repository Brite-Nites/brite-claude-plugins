# GTM Campaign Orchestration — Implementation Plan

> **Start here for orientation**: `docs/gtm-campaign-orchestration-README.md` — master entry point. Use this plan for the tiered roadmap + per-BC sketches; use the README for orientation, glossary, decision log, and onboarding.

**Status**: Filed — design phase closed 2026-05-12; refined and filed as Linear BC-8712 through BC-8735 + BC-8752 (audit-fix). See `docs/project-plan-refined.md` for refined tasks and `docs/linear-issues-created.md` for the BC table.
**Source design doc**: `docs/designs/gtm-campaign-orchestration-design.md`
**Companion memories**: `memory/project_gtm_campaign_architecture.md`, `memory/project_marketing_vocabulary.md`, `memory/session_2026_05_11_gtm_campaign_design.md`
**Linear project (this plan's BCs)**: Brite Skill Packs (plugin engineering work)
**Linear project (campaigns themselves, downstream)**: Brite GTM (per D2 + O7)
**Cross-repo**: brite-salesforce (SF metadata), brite-nites/handbook (PRs for O14)

---

## 1. Scope — what's locked

This plan converts ~50 locked design decisions into implementation surface. The locks are exhaustively narrated at `docs/designs/gtm-campaign-orchestration-design.md`. Summary:

### Phase 1 locks (foundational)

| ID | Decision |
|---|---|
| D1 | Campaign unit = Vertical × Persona × Offer × Month (M01-M12 calendar; FY=calendar year) |
| D2 | 3-layer split — Handbook=reference/process; Linear=orchestration/state; Plugin=execution/artifacts |
| D3 | Sub-issues = stand-up work (not waves) |
| D4 | 7+2 sub-issue template (Brief / List / Copy / SF / QA / Launch / Active mgmt / Debrief + optional Situation mining / Creative angles) |
| D5 | Filled brief lives in Linear milestone description |
| D6 | Handbook = navigation; doesn't host instance state |
| O1 | Status labels — `planning` / `active` / `completed` / `killed` (primary) + `paused` (overlay) |
| O2 | Slug rule `{vertical}-{persona}-{offer}-fy{YY}-m{MM}` ; manifest.json at `docs/campaigns/{entity}/{slug}/manifest.json` is canonical machine-readable cross-reference |

### Phase 2 architectural pivots

| ID | Decision |
|---|---|
| Reframe | Handbook = HOW (process / frameworks / templates / playbooks); Plugin = WHAT (entities + state — canonicals, MSPA matrix, learnings, manifest.json, discoveries.json, performance.md) |
| D7 | Final thin canonicals schema — `slug` + `display` + `personas[]` + `offers[]` + optional `aliases`/`playbook_path`; flat personas; per-offer `status` only |
| D9 | Single-repo plugin-owned schema versioning |
| D10 | DROPPED — `--handbook-ref` flag unnecessary (canonicals plugin-local) |
| D11 | All 27 verticals backfilled day-1 |
| O5 | Same-month + new copy = `-v2` slug suffix |
| O7 | brite-gtm = pre-Linear ideation queue (🟢🟡⚪ candidates graduate to Linear) |
| O11/σ3 | KEEP D2; auto-create SF Campaign via new revops:salesforce MCP write tool during plan-campaign Step 7b |

### Vocabulary canon (5 categories — all LOCKED)

- **Identity**: Vertical (handbook canon identity) + Market (MSPA hypothesis context) — both kept; ICP=template / Segment=instance; 4-layer offer model (Family > Posture > Angle > Specific Instance); persona schema = slug+display+titles[]; **Offer Tier → Offer Posture** (renamed; values `knowledge` / `free-asset` / `pilot` / `risk-reversal`).
- **State**: 3 verdict vocabularies kept distinct — Angle Verdict (creative-angles) / Experiment Verdict (mmf) / Campaign Verdict (debrief).
- **Artifact**: Entity slug normalized to short-form under `docs/campaigns/{entity}/`.
- **Process/Framework** + **Metric**: no decisions; canonical sources locked.

### discoveries.json + signal promotion

Skills emit category-tagged signals to `docs/campaigns/{entity}/{slug}/discoveries.json`; humans promote via handbook PR. Categories: `title-discovery` / `icp-refinement` / `offer-retirement` / `persona-discovery`. ICP refinement uses hybrid cadence (per-batch tactical + per-quarter strategic).

### O6 portfolio rollup (entire question chain LOCKED)

| ID | Decision |
|---|---|
| O6.Q1 | Portfolio rollup home = Salesforce list view (primary); Linear = per-campaign drill-down. σ3 scope expanded to include `update_sf_campaign_status` |
| O6.Q2 | Default "Active Campaigns" view spec — Status grouping; 7 columns; filter Status ∈ {Planned, In Progress} + Substatus ∈ {null, Paused}; sort StartDate ASC; 4 saved views; 4 new SF custom fields |
| O6.Q3 row 1 | Daily — no portfolio rollup |
| O6.Q3 row 2 | Weekly GTM sync — Active Campaigns default + Launch Calendar sibling; no plugin command |
| O6.Q3 row 3 | Monthly review — Coverage by Vertical + NEW Performance Dashboard + `/marketing:portfolio-snapshot --monthly` |
| O6.Q3 row 4 | Quarterly planning — Coverage by Vertical (FY) + Performance Dashboard (FY) + NEW Pipeline by Offer Family Dashboard + `/marketing:portfolio-snapshot --quarterly` + brite-gtm campaign-portfolio.md |
| O6.Q4 | Retro rhythm subsumed by D4 + Q3 |
| O6.Q5 | portfolio-snapshot ships with `--monthly` \| `--quarterly` flags only; V3-gated |

---

## 2. Tiered roadmap (~21 BCs + dependencies)

```
   TIER 1: brite-salesforce metadata foundation         (4 BCs)
   ─────────────────────────────────────────────────────────────
     T1-A  4 custom Campaign fields (Persona__c, Offer__c,
           Entity__c, Substatus__c)
     T1-B  4 saved list views (Active Campaigns default,
           Coverage by Vertical, Launch Calendar, Owner Load)
     T1-C  Performance Dashboard (vertical × month)
     T1-D  Pipeline by Offer Family Dashboard (offer × quarter)

   TIER 2: revops:salesforce MCP code                   (2 BCs)
   ─────────────────────────────────────────────────────────────
     T2-E  create_sf_campaign write tool         deps: T1-A
     T2-F  update_sf_campaign_status write tool  deps: T1-A

   TIER 3: canonicals data layer (plugin-side)          (2 BCs)
   ─────────────────────────────────────────────────────────────
     T3-G  plugins/marketing/data/canonicals/
           _manifest.yaml + 27 {vertical}.yaml (D11)
     T3-H  D8 persona authorship process documented     deps: V3

   TIER 4: plan-campaign scaffolding                    (1 BC)
   ─────────────────────────────────────────────────────────────
     T4-I  /marketing:plan-campaign command (Steps 1-10;
           closes O3)                deps: T1-A, T1-B, T2-E, T3-G

   TIER 5: migration cleanups                           (4 BCs)
   ─────────────────────────────────────────────────────────────
     T5-K  O15 entity slug short-form migration
           (campaign-debrief learnings.md path normalize)
     T5-L  O12 cross-skill — offer-tier → offer-posture rename
           (email-copywriting + downstream consumers)
     T5-M  O12 cross-skill — 3-verdict parent labels
           (Angle / Experiment / Campaign Verdict)
     T5-N  O12 cross-skill — discoveries.json category schema

   TIER 6: dogfood + V3 gate                            (2 BCs)
   ─────────────────────────────────────────────────────────────
     T6-O  O9 first dogfood campaign (manual plan-campaign
           run; iterate template based on friction)  deps: T4-I
     T6-P  V3 Marketing buy-in (against populated dogfood
           snapshot; ratifies M2 vs M3)              deps: T6-O

   TIER 7: portfolio-snapshot                           (1 BC)
   ─────────────────────────────────────────────────────────────
     T7-Q  /marketing:portfolio-snapshot --monthly | --quarterly
           command            deps: T1-C, T1-D, T2-E, T2-F, T5-K,
                                    T6-O, T6-P (V3 must not reject)

   TIER 8: handbook PRs                                 (4 BCs)
   ─────────────────────────────────────────────────────────────
     T8-R  O14 vocabulary canon (handbook/marketing/frameworks/
           vocabulary.md)                            deps: T6-P
     T8-S  O14 framework docs (8 files)              deps: T6-P
     T8-T  O8 handbook nav refactor — active-campaigns.md
           repoint to SF + Linear                    deps: T6-P
     T8-U  O14 how-we-operate.md cadence rows pin to SF view
           URLs + plugin commands                    deps: T6-P

   TIER 9: optional commands (defer or file as backlog) (3 BCs)
   ─────────────────────────────────────────────────────────────
     T9-V  /marketing:offer-performance command
           (per O13; reads manifest.json glob + EB + SF;
           emits performance.md per offer-version)   deps: T2-F
     T9-W  /marketing:new-vertical / new-offer / new-persona
           sibling commands (canonicality additions)
     T9-X  /marketing:icp-refinement-review command
           (promoting discoveries.json signals)
```

**TOTAL**: 21 new BCs in this plan. Plus 4 already-filed in backlog (BC-2720 reply-processing, BC-2725 lead-routing, BC-2722 outbound-playbook, BC-5537/5538 enrichment MCP).

---

## 3. Per-BC spec sketches

Format per BC: title, one-line description, 3-5 acceptance criteria, deps, effort (S/M/L), repo. **These are sketches for `/workflows:refine-plan` to expand** — they are not final issue specs.

### T1-A — Deploy 4 Campaign custom fields to brite-salesforce

- **Title**: Deploy Persona__c / Offer__c / Entity__c / Substatus__c custom fields to brite-salesforce Campaign object
- **Description**: 4 new custom fields enable σ3 writeback + saved list views + dashboards. Per O6.Q2 lock.
- **ACs**:
  - Persona__c (text 64) deployed
  - Offer__c (text 64) deployed
  - Entity__c (picklist {nites, supply, labs, cross-entity}) deployed
  - Substatus__c (picklist {null, Paused}) deployed
  - All 4 visible on Campaign Detail layout
  - All 4 reportable + filterable in list views
- **Deps**: none (Tier 1 foundation)
- **Effort**: S
- **Repo**: brite-salesforce (deploy via revops:salesforce MCP `deploy_metadata` once T2 ships, or via SF CLI directly)

### T1-B — Deploy 4 saved Campaign list views

- **Title**: Deploy Active Campaigns / Coverage by Vertical / Launch Calendar / Owner Load saved list views
- **Description**: Per O6.Q2 lock. Active Campaigns is the default (Status-grouped, 7 columns, default filter excludes Completed + Killed); 3 siblings cover quarterly/launch/load axes.
- **ACs**:
  - Active Campaigns: Status-grouped, sort StartDate ASC, 7 columns (Name / Vertical / Owner / Launch / Pipeline / Leads / Linear), filter Status ∈ {Planned, In Progress} + Substatus ∈ {null, Paused}
  - Coverage by Vertical: Vertical-grouped, filter Status ≠ Killed (includes Completed)
  - Launch Calendar: Month-grouped (StartDate), filter Status ∈ {Planned, In Progress} AND StartDate ≥ TODAY-30d
  - Owner Load: Owner-grouped, same filter as Active Campaigns default
  - All 4 visible to GTM team Sharing settings
- **Deps**: T1-A (fields populated)
- **Effort**: S
- **Repo**: brite-salesforce

### T1-C — Deploy Performance Dashboard

- **Title**: Deploy SF Performance Dashboard (vertical × month — monthly review use case)
- **Description**: Per O6.Q3 row 3 lock. One canonical dashboard combining pipeline-by-vertical + leads-by-month + conversion-funnel + verdict-distribution charts.
- **ACs**:
  - Dashboard contains 4 chart components:
    1. Pipeline by Vertical (bar — AmountAllOpportunities grouped by Vertical__c, last 6 months)
    2. Leads by Month (line — NumberOfLeads grouped by StartDate month, current FY)
    3. Conversion Funnel (funnel — Leads → Replies → Meetings → Closed-Won, current month)
    4. Verdict Distribution (donut — Status grouped, current month)
  - Visible to GTM + leadership users
  - Auto-refresh on view
- **Deps**: T1-A (Vertical__c populated)
- **Effort**: M
- **Repo**: brite-salesforce

### T1-D — Deploy Pipeline by Offer Family Dashboard

- **Title**: Deploy SF Pipeline by Offer Family Dashboard (offer × quarter — quarterly planning use case)
- **Description**: Per O6.Q3 row 4 lock. Different granularity from T1-C — offer-family × quarter answers "which offers compound vs decay" across multiple campaigns.
- **ACs**:
  - Dashboard contains 3 chart components:
    1. Pipeline per Offer Family (bar — AmountAllOpportunities grouped by Offer__c, current FY)
    2. Revenue per Offer Posture (bar — AmountWonOpportunities grouped by Offer Posture custom field [Substatus__c is not the right field — needs a derived field OR captured in posture-specific picklist; refine during implementation])
    3. Verdict Distribution per Offer Family across quarters (matrix — Status grouped by Offer__c, quarterly trailing 4)
  - Visible to GTM + leadership users
- **Deps**: T1-A (Offer__c populated). **Refinement note**: Offer Posture isn't yet a SF field; needs decision during refinement on whether to add `OfferPosture__c` (text or picklist) to canonical fields.
- **Effort**: M
- **Repo**: brite-salesforce

### T2-E — Add create_sf_campaign write tool to revops:salesforce MCP

- **Title**: revops:salesforce MCP — implement create_sf_campaign write tool (σ3)
- **Description**: Per σ3 / O11 lock. revops:salesforce MCP today is read-heavy + metadata-deploy; this adds the first per-record write path. Called by `/marketing:plan-campaign` Step 7b at scaffold time.
- **ACs**:
  - Tool signature: `create_sf_campaign(slug, entity, vertical, persona, offer, year, month, owner_email, launch_date)`
  - Creates Campaign record with Name=slug, Vertical__c=vertical, Persona__c=persona, Offer__c=offer, Entity__c=entity, StartDate=launch_date, OwnerId from owner_email lookup, Status="Planned"
  - Returns SF Campaign ID + Campaign URL on success
  - Soft-fail path: if create fails, return error; do NOT halt plan-campaign (Step 7b proceeds, manifest.json gets `salesforce.campaign_id: null` and operator manually creates)
  - Idempotency: rejects create when slug already exists in SF as Campaign Name (prevents dupes on re-run)
- **Deps**: T1-A (custom fields exist to write to)
- **Effort**: M
- **Repo**: revops:salesforce MCP code (plugins/revops/ or wherever the MCP lives)

### T2-F — Add update_sf_campaign_status write tool to revops:salesforce MCP

- **Title**: revops:salesforce MCP — implement update_sf_campaign_status write tool (σ3 scope expansion)
- **Description**: Per O6.Q1 σ3 scope expansion. Triggered on Linear status transitions to keep SF Campaign Status in sync.
- **ACs**:
  - Tool signature: `update_sf_campaign_status(slug, linear_status, linear_substatus)`
  - Looks up SF Campaign by Name=slug
  - Maps Linear status → SF Campaign Status per Q1 lock table:
    - `planning` → `Planned`
    - `active` → `In Progress` (Substatus__c=null)
    - `active` + `paused` → `In Progress` (Substatus__c=`Paused`)
    - `completed` → `Completed`
    - `killed` → `Aborted`
  - Returns updated SF Campaign record on success
  - Soft-fail: log warning + continue if SF Campaign not found (allows plan-campaign to scaffold even if SF auto-create failed earlier)
- **Deps**: T1-A, T2-E
- **Effort**: S
- **Repo**: revops:salesforce MCP code

### T3-G — Backfill canonicals.yaml for 27 verticals

- **Title**: Build plugins/marketing/data/canonicals/_manifest.yaml + 27 {vertical}.yaml files (D11)
- **Description**: Per D7 + D11 locks. Thin schema: `slug` + `display` + `personas[]` + `offers[]` + optional aliases/playbook_path. All 27 verticals backfilled day-1 (per D11) but per-vertical content depth varies — personas may be empty initially (graduates via D8 + handbook review).
- **ACs**:
  - `_manifest.yaml` contains all 27 vertical slugs (alphabetized) + schema_version=1
  - Each `{vertical}.yaml` validates against schema (slug + display + personas[] + offers[])
  - At least 7 Active verticals have ≥1 persona + ≥1 offer populated (Municipalities, HOAs, Landscape Lighting, Landscape Architects, Builders, Universities, Hospitals)
  - Exploring + Future verticals can be skeleton (just slug + display)
  - All offer entries have status ∈ {draft, active, retired}
  - Lint: no duplicate slugs across verticals
  - Lint: every persona slug is kebab-case
- **Deps**: D8 (persona authorship process) ideally precedes — but skeleton entries are fine without
- **Effort**: M (mostly data entry; cross-reference handbook prose)
- **Repo**: britenites-claude-plugins / `plugins/marketing/data/canonicals/`

### T3-H — D8 persona authorship process documented

- **Title**: Document persona authorship process for canonicals.yaml (D8)
- **Description**: Per D8 + V3. Marketing decides who authors slugs+titles[] for 27 verticals, when personas graduate from "named in handbook ICP prose" to "in canonicals.yaml with titles[]", cadence + ownership.
- **ACs**:
  - Decision documented in handbook/marketing/standards/canonicals-authorship.md (or similar)
  - Cadence defined (quarterly review? per-vertical-revisit?)
  - Owner named (Sarah Cullen? Kells? Marketing collective?)
  - Promotion criteria explicit (when does a candidate persona become a canonicals entry)
  - Discoveries.json `persona-discovery` signal → promotion workflow documented
- **Deps**: V3 (Marketing buy-in on canonicals structure)
- **Effort**: S (document only; no code)
- **Repo**: brite-nites/handbook (PR)

### T4-I — /marketing:plan-campaign command (O3)

- **Title**: Implement /marketing:plan-campaign command — 10-step scaffolding (closes O3)
- **Description**: Per O3 + D2 + D4 locks. Hybrid flag-or-prompt mode. Scaffolds one Vertical × Persona × Offer × Month campaign across all 4 layers (Linear milestone + 7+2 sub-issues + plugin dir + manifest.json + SF Campaign via σ3 + EB workspace assignment).
- **ACs**:
  - Command at `plugins/marketing/commands/plan-campaign.md`
  - Step 1 (operator invocation): flag-or-prompt for `--vertical` / `--persona` / `--offer` (required); auto-detect `--month` / `--year` / `--entity` for single-entity verticals; optional `--launch-date` / `--situation-mining` / `--creative-angles` / `--dry-run`
  - Step 2 (handbook canonicality validation): hard-fail on missing canonicals entry with pointer to T9-W (new-vertical / new-offer / new-persona commands)
  - Step 3 (collision check): -v2 suffix logic per O5
  - Step 4 (dry-run preview): operator-readable plan output
  - Step 5 (two-call confirm): per BC-2707 precedent
  - Step 6 (plugin dir + manifest.json): creates `docs/campaigns/{entity}/{slug}/manifest.json` with manifest schema per O2
  - Step 7a (Linear milestone): creates milestone in "Brite GTM" project with brief template per D5 + slug + entity + vertical + persona + offer + year + month + status:planning labels
  - Step 7b (SF Campaign): calls T2-E create_sf_campaign; soft-fails if MCP unavailable
  - Step 8 (sub-issues): creates 7 standard sub-issues per D4 with descriptions + blocked-by chains
  - Step 9 (optional sub-issues): adds Situation Mining (Labs only) + Creative Angles if flagged
  - Step 10 (summary output): prints milestone URL + slug + manifest path + sub-issue count + IDs
- **Deps**: T1-A, T1-B, T2-E, T3-G
- **Effort**: L
- **Repo**: britenites-claude-plugins / `plugins/marketing/commands/`

### T5-K — O15 entity slug short-form migration

- **Title**: Normalize entity slug under docs/campaigns/{entity}/ to short-form (O15)
- **Description**: Per Artifact Q1 vocab lock. campaign-debrief migrates from `brite-{entity}/` to `{entity}/`. One-release-cycle backward-compat window.
- **ACs**:
  - Update campaign-debrief SKILL.md Gate 1 entity validator to accept BOTH `^(brite-nites|brite-supply|brite-labs)$` AND `^(nites|supply|labs)$` for one cycle
  - Update default Write path to short-form
  - Update mmf SKILL.md §3 ITERATE Step 3.5 cross-skill read path (drop `brite-` prefixing)
  - Backward-compat: read from both paths; prefer short-form; log warning on long-form read
  - Linter: scan all SKILL.md for hardcoded `brite-{entity}/` paths; flag for migration
  - Migration script: rename existing `docs/campaigns/brite-{entity}/` to `docs/campaigns/{entity}/` (when artifacts exist; at design-time, nothing on disk yet)
- **Deps**: none (preparation for portfolio-snapshot per dependency graph)
- **Effort**: S (mostly path-string changes + one-cycle compat shim)
- **Repo**: britenites-claude-plugins

### T5-L — O12 cross-skill migration — offer-tier → offer-posture rename

- **Title**: Rename Offer Tier → Offer Posture across email-copywriting + downstream (O12 Identity Q5)
- **Description**: Per ID Q5 vocab lock. Letter codes T1/T2/T3/T4 collided with list-building's title cascade T1/T2/T3. Rename concept to Offer Posture; values to descriptive slugs `knowledge` / `free-asset` / `pilot` / `risk-reversal`.
- **ACs**:
  - email-copywriting SKILL.md §3 — rename `offer_tier` field → `offer_posture`; rename value tokens
  - copy artifact JSON schema — emit new `offer_posture` field; backward-compat reader accepts old `offer_tier` for one release cycle
  - launch-campaign command — consume new `offer_posture` field
  - Tests/evals updated
- **Deps**: none
- **Effort**: M (touches multiple files; cross-skill consistency)
- **Repo**: britenites-claude-plugins

### T5-M — O12 cross-skill migration — 3-verdict parent labels

- **Title**: Rename 3 verdict parent labels per skill (O12 State Q1)
- **Description**: Per State Q1 vocab lock. Verdicts stay distinct (different decision surfaces); parent labels renamed for clarity — Angle Verdict (creative-angles, pre-experiment) / Experiment Verdict (mmf, post-batch) / Campaign Verdict (debrief, post-campaign).
- **ACs**:
  - creative-angles SKILL.md — rename "verdict" → "angle verdict" in all section headers + output rows
  - mmf SKILL.md — rename "verdict" → "experiment verdict" similarly
  - campaign-debrief SKILL.md — rename "verdict" → "campaign verdict" similarly
  - Cross-skill translation table (per State Q1) added to each skill's "Cross-skill boundaries" section
- **Deps**: none
- **Effort**: S
- **Repo**: britenites-claude-plugins

### T5-N — O12 cross-skill — discoveries.json category schema

- **Title**: Implement discoveries.json category-tagged signal schema (O12 + Phase 2 7.4)
- **Description**: Per Phase 2 architectural pivot — skills emit category-tagged signals; humans promote via PR. Categories: title-discovery (list-building) / icp-refinement (campaign-debrief) / offer-retirement (campaign-debrief) / persona-discovery (campaign-debrief).
- **ACs**:
  - Schema defined in plugins/marketing/data/discoveries-schema.json (or similar)
  - list-building emits title-discovery signals to `docs/campaigns/{entity}/{slug}/discoveries.json`
  - campaign-debrief emits icp-refinement / offer-retirement / persona-discovery signals on operator confirmation
  - Schema-validation lint in CI
- **Deps**: none (independent of T5-L/M)
- **Effort**: M
- **Repo**: britenites-claude-plugins

### T6-O — O9 first dogfood campaign

- **Title**: Run first dogfood campaign through /marketing:plan-campaign + iterate template based on friction (O9)
- **Description**: Pick one campaign from brite-gtm portfolio (likely Brite Labs — Zoos or similar), instantiate manually as dogfood, iterate template.
- **ACs**:
  - One campaign milestone created in Linear "Brite GTM" project
  - All 7+2 sub-issues populated with handbook-cited descriptions
  - SF Campaign auto-created via T2-E
  - manifest.json + plugin dir created
  - 1 EB campaign launched
  - 1 debrief executed (eventually; could be future-state for full validation)
  - Friction log committed to docs/plans/gtm-campaign-orchestration-plan.md as appendix (or separate friction-log.md)
- **Deps**: T4-I
- **Effort**: M (real campaign run + friction capture)

### T6-P — V3 Marketing buy-in (against populated dogfood)

- **Title**: V3 Marketing ratification of canonicals + vocab + portfolio-snapshot packet
- **Description**: Per V3. Marketing (Sarah Cullen + Kells) reviews canonicals.yaml + framework docs + portfolio-snapshot markdown output (against the dogfood from T6-O). M2 vs M3 gate.
- **ACs**:
  - 4-layer offer model + Offer Posture rename: ratified or rejected
  - ICP=template / Segment=instance: ratified or rejected
  - 3 verdict vocabularies kept distinct: ratified or rejected
  - canonicals.yaml structure: ratified or rejected
  - discoveries.json category-tagged pattern: ratified or rejected
  - **portfolio-snapshot markdown packet (M2)**: ratified, rejected, or modified — V3 OUTPUT determines whether T7-Q ships as-designed (M2), downgrades to M3, or ships with modifications
- **Deps**: T6-O (populated dogfood for V3 to review against)
- **Effort**: S (review meeting + sign-off)

### T7-Q — /marketing:portfolio-snapshot command

- **Title**: Implement /marketing:portfolio-snapshot --monthly | --quarterly command (O6.Q3 rows 3+4 / O6.Q5)
- **Description**: Per O6.Q5 lock. Read-only synthesis orchestrator merging SF quantitative + plugin-side qualitative. Emits one markdown packet per invocation.
- **ACs**:
  - Command at `plugins/marketing/commands/portfolio-snapshot.md`
  - Two flags only: `--monthly` | `--quarterly` (no `--weekly` / `--custom-window` / `--forecast` / `--charts`)
  - Reads from: SF Campaign records via `run_soql_query`, Linear milestones via `list_issues`/`get_issue`, plugin filesystem (`learnings.md` Summary/What-works/What-doesn't sections + `mmf-matrix.md` Results Log + `analysis-*.md` verdict tokens + manifest.json glob)
  - Writes one output: `docs/campaigns/_reviews/monthly-{YYYY-MM}.md` OR `docs/campaigns/_reviews/quarterly-{YYYY-Q}.md`
  - Output sections (--monthly): Portfolio shape / Pipeline summary / Verdict distribution / Transferable insights / Action items
  - Output sections (--quarterly): same as monthly + Cross-quarter MSPA transitions + Cumulative transferables + Per-offer-version aggregation (graceful empty if T9-V hasn't shipped) + Coverage-gap callouts
  - Anti-creep guards documented: never mutates source data; never re-implements campaign-debrief regen; markdown-only output; no new metric definitions
  - Output format frontmatter: `schema_version: 1` + `generated_at` + `window` + `command_version`
- **Deps**: T1-C, T1-D, T2-E, T2-F, T5-K, T6-O, T6-P (V3 must not reject)
- **Effort**: L
- **Repo**: britenites-claude-plugins / `plugins/marketing/commands/`

### T8-R — O14 vocabulary canon handbook PR

- **Title**: Handbook PR — marketing/frameworks/vocabulary.md (O14)
- **Description**: Promote `memory/project_marketing_vocabulary.md` content to handbook canon.
- **ACs**:
  - File created at `handbook/marketing/frameworks/vocabulary.md`
  - Contents = full disambiguation of 5 vocabulary categories (Identity / State / Process / Artifact / Metric)
  - Cross-linked from existing handbook docs (campaign-lifecycle.md, campaign-planning.md, vertical READMEs)
  - PR opened against brite-nites/handbook
- **Deps**: T6-P (V3 ratification)
- **Effort**: M
- **Repo**: brite-nites/handbook (PR)

### T8-S — O14 framework docs handbook PR

- **Title**: Handbook PR — marketing/frameworks/{mspa-flywheel, kellens-laws, asymmetry-rubric, offer-postures, value-equation, recency-waterfall, verdicts-cross-reference}.md (O14)
- **Description**: 7 additional framework docs (vocabulary.md is T8-R). Promote framework content currently lodged inside SKILL.md files to handbook canon (skills cross-reference handbook instead of duplicating).
- **ACs**: 7 framework docs created with content, each cross-referenced from the SKILL.md file that previously owned the content. Plugin SKILL.md files updated to point at handbook instead of carrying canonical text.
- **Deps**: T6-P, T8-R (vocabulary.md first)
- **Effort**: L (substantial writing)
- **Repo**: brite-nites/handbook (PR) + britenites-claude-plugins (SKILL.md cross-references)

### T8-T — O8 handbook nav refactor (active-campaigns.md)

- **Title**: Handbook PR — refactor active-campaigns.md to nav-pointer (O8)
- **Description**: Per D6 + O6.Q1 lock. active-campaigns.md becomes "How to find active campaigns" pointing at SF list view URL (primary) + Linear project URL (secondary drill-down). No live state in handbook.
- **ACs**:
  - active-campaigns.md re-written as 1-page nav doc with both URLs
  - All inbound links from other handbook docs updated
- **Deps**: T6-P (V3 ratification)
- **Effort**: S
- **Repo**: brite-nites/handbook (PR)

### T8-U — O14 how-we-operate.md cadence rows

- **Title**: Handbook PR — pin how-we-operate.md cadence rows to specific SF view URLs + plugin commands (O14)
- **Description**: Per O6.Q3 cadence-to-view mapping lock. Each cadence row (daily / weekly GTM sync / monthly review / quarterly planning) references the specific view + command from Q3.
- **ACs**:
  - how-we-operate.md cadence section updated with table per Q3 lock
  - SF list view + dashboard URLs filled in (post-deploy)
  - Plugin command names + flags referenced
- **Deps**: T1-B, T1-C, T1-D (SF artifacts deployed so URLs exist), T6-P (V3 ratification)
- **Effort**: S
- **Repo**: brite-nites/handbook (PR)

### T9-V — /marketing:offer-performance command (O13)

- **Title**: Implement /marketing:offer-performance command (O13)
- **Description**: Per O13. Reads manifest.json glob + EB + SF; emits per-offer-version performance.md at `docs/campaigns/{entity}/offers/{slug}/{version}/performance.md`. Feeds back into mmf ITERATE Step 3.6.
- **ACs**: Per O13 spec.
- **Deps**: T2-F (status sync ensures live data), T3-G (canonicals knows offer slugs)
- **Effort**: M
- **Repo**: britenites-claude-plugins

### T9-W — Canonicality sibling commands

- **Title**: Implement /marketing:new-vertical / new-offer / new-persona sibling commands (per O3 Step 2 / O10)
- **Description**: When plan-campaign Step 2 hard-fails on missing canonicals entry, these commands bootstrap the canonicality addition. Each creates a canonicals.yaml entry + handbook PR draft for review.
- **ACs**:
  - Three commands created
  - Each takes minimal arguments (slug + display + 1-2 fields)
  - Each emits a plan-campaign-resumable canonicals diff + handbook PR draft
- **Deps**: T3-G (canonicals exists)
- **Effort**: M
- **Repo**: britenites-claude-plugins

### T9-X — /marketing:icp-refinement-review command

- **Title**: Implement /marketing:icp-refinement-review command (per discoveries.json promotion pattern)
- **Description**: Reads pending icp-refinement signals from discoveries.json files across all campaigns; presents to operator for promotion decision; emits handbook PR draft.
- **ACs**: TBD during refinement.
- **Deps**: T5-N (discoveries.json schema)
- **Effort**: M
- **Repo**: britenites-claude-plugins

---

## 4. Dependency graph (visual)

```
   T1-A (4 SF fields)
     ├─→ T1-B (4 saved views)
     ├─→ T1-C (Performance Dashboard)
     ├─→ T1-D (Pipeline-by-Offer-Family Dashboard)
     ├─→ T2-E (create_sf_campaign MCP) ──→ T2-F (update_sf_campaign_status)
     └─→ (used by T4-I)

   T3-G (canonicals backfill) ──→ T4-I (plan-campaign)
   T3-H (D8 authorship)        ──→ blocked by V3 (T6-P); soft

   T1-A + T1-B + T2-E + T3-G ──→ T4-I (plan-campaign)

   T4-I ──→ T6-O (dogfood) ──→ T6-P (V3 ratification)

   T5-K (entity slug migration) ──→ T7-Q
   T5-L (tier→posture)          ──→ independent
   T5-M (verdict labels)        ──→ independent
   T5-N (discoveries.json)      ──→ T9-X

   T1-C + T1-D + T2-E + T2-F + T5-K + T6-O + T6-P ──→ T7-Q (portfolio-snapshot)

   T6-P ──→ T8-R / T8-S / T8-T / T8-U (handbook PRs)
   T1-B + T1-C + T1-D ──→ T8-U (cadence URLs filled in)

   T9-V (offer-performance) depends on T2-F + T3-G
   T9-W (sibling commands) depends on T3-G
   T9-X (icp-refinement-review) depends on T5-N
```

Critical path (longest dependency chain): **T1-A → T2-E → T4-I → T6-O → T6-P → T7-Q**. ~6 BCs in sequence; rough effort sum: S+M+L+M+S+L ≈ ~5-6 weeks at single-developer pace, or compressible if Tier 1 runs in parallel.

Parallelizable: Tier 5 migrations (T5-K/L/M/N) can land in parallel with Tier 1/2 work. T1-A/B/C/D can all land in parallel once T1-A's fields exist (B/C/D depend on A).

---

## 5. V3 gate position

V3 (Marketing buy-in) is the load-bearing decision gate for:
- M2 vs M3 fallback on portfolio-snapshot (T7-Q ship or degrade)
- Pipeline-by-Offer-Family Dashboard (T1-D ship or defer)
- Handbook PRs (T8-R/S/T/U all gated on ratification)
- Persona authorship process (T3-H — soft gate; can proceed without but better with)

V3 happens **against a populated dogfood snapshot**, not an empty hypothetical. Sequence:
1. T1 + T2 + T3 deploy (foundation exists)
2. T4 ships (plan-campaign live)
3. T6-O runs (dogfood populates artifacts)
4. T7-Q ships in dry-run mode (emits snapshot against dogfood — operator can SEE the markdown packet)
5. T6-P ratification meeting — V3 reviews the actual snapshot against actual data
6. Decision: ship M2 fully (T7-Q + T1-D + T8-R/S/T/U) OR downgrade to M3 (drop T7-Q + T1-D; keep T1-C + saved views)

Implication: T7-Q ships in two phases — Phase 1 dry-run dogfood snapshot for V3 review; Phase 2 production ship after V3 pass. Plan accordingly.

---

## 6. Sequencing rationale

**Why Tier 1 first**: foundation. Everything else depends on either custom fields (T1-A) or saved views (T1-B) or dashboards (T1-C/D). Until T1 lands, no SF-side artifact has somewhere to live.

**Why Tier 2 in parallel with Tier 1**: MCP code changes (T2-E/F) don't need fields to exist to land in code review; they need fields to exist to *test* against. Code lands before deploy; deploy after T1-A.

**Why Tier 3 (canonicals) in parallel with Tier 1/2**: plugin-side; independent of SF. Can ship while T1/T2 are in-flight.

**Why Tier 4 (plan-campaign) waits**: depends on T1+T2+T3 all being usable. Plan-campaign IS the orchestrator that uses everything.

**Why Tier 5 migrations can run anytime**: independent of σ3 + plan-campaign. Can be done before, during, or after Tier 1-4. Recommendation: do T5-L (tier→posture) early because it touches email-copywriting which is already production; do T5-K (entity slug) before Tier 7 (portfolio-snapshot depends on normalized paths).

**Why Tier 6 (dogfood + V3) is mid-sequence**: must come after T4 ships (plan-campaign live), must come before T7-Q production ship and Tier 8 handbook PRs.

**Why Tier 7 (portfolio-snapshot) is late**: depends on dashboards (T1-C/D) + MCP tools (T2-E/F) + migrations (T5-K) + V3 ratification.

**Why Tier 8 (handbook PRs) is last**: V3-gated. Can't ship handbook content that documents process before Marketing ratifies it.

**Why Tier 9 (optional commands) is deferrable**: T9-V/W/X are nice-to-haves; main loop functions without them. File as backlog; revisit after Tier 7 ships.

---

## 7. Open items NOT in this plan

These remain unresolved in the design phase but don't block implementation:

- **O3 Steps 2.4-10 Socratic walkthrough** — paused at Step 2 sub-chunk 4 (content extraction); Steps 3-10 unwalked. **Resolution**: design inline during T4-I implementation. The plan-campaign spec sketch above lists Steps 1-10 ACs; refining the inner details is a code-design activity, not a fresh Socratic interview.
- **D8 persona authorship process** — Marketing decision pending. Filed as T3-H but resolvable inline with T3-G canonicals backfill (skeleton entries work without D8 decision).
- **V1 gh CLI auth audit** — out of scope for this plan. Cross-tool consumer concern; can be addressed independently.
- **V2 handbook parsing-conflict audit** — partial; do during T8-R/S handbook PR drafting. Grep handbook for vocabulary collisions as part of vocabulary.md PR review.
- **O4 post-launch metric writeback Linear ← plugin** — campaign-analysis weekly post pattern. Out of scope for this plan; resolvable later when first dogfood campaign reaches active management.

---

## 8. Already-filed backlog (no new BCs needed)

- **BC-2720** reply-processing (post-launch reply handling)
- **BC-2725** lead-routing (handoff to BDR routing)
- **BC-2722** outbound-playbook (umbrella skill)
- **BC-5537 / BC-5538** enrichment MCP (custom enrichment)

These intersect with implementation but don't require new BCs from this plan. Sequence relative to this plan's BCs is operator judgment at backlog-grooming time.

---

## 9. Next steps

1. **Refine this plan** via `/workflows:refine-plan` — expand each BC sketch into agent-ready issue spec with full ACs + research notes + validation criteria
2. **Create issues** via `/workflows:create-issues` — file the 21 BCs in Linear "Brite Skill Packs" project with cross-linked dependencies
3. **Execute Tier 1 first** — parallelize T1-A through T1-D once T1-A lands
4. **Status check at end of Tier 4** — confirm plan-campaign is operator-usable before committing to Tier 5+
5. **V3 ratification at Tier 6** — load-bearing M2/M3 decision

This plan supersedes the implicit "next-up" enumeration in the design doc's open-items list. Until BCs are filed, the design doc Section 7.8 remains the source of truth for what's locked; this plan is the source of truth for what's implementable.
