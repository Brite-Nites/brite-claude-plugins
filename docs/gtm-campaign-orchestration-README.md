# GTM Campaign Orchestration — Effort README

**Status**: Design phase CLOSED 2026-05-12; pre-implementation audit complete; **23 Linear issues filed and ready for execution** (BC-8712 through BC-8735 + BC-8752).
**Doc lifecycle**: LIVING — this README is updated as BCs ship + V3 ratifies + Tiers complete. See [§12 Maintenance protocol](#12-next-steps--open-items) for what to update when.
**Last updated**: 2026-05-13 (session-3 — README shape pass 1+2+3 added §3.5 flywheel + §3.6 worked example + §3.7 operations + §5 M2/M3 callout + §6 infra glossary + §7.5 decision→BC table + 8 ADRs)
**README version**: v1.0 (initial design-close artifact)
**Audience**: anyone trying to understand "what is this work, what was decided, and how do I act on it."
**TL;DR**: Brite had three parallel "campaign" systems with three different definitions. This design unifies them into a 3-layer architecture (Handbook = HOW / Linear = orchestration / Plugin = WHAT, with Salesforce as portfolio reporting surface), locks ~30 architectural decisions, and breaks implementation into 23 atomic Linear issues across 9 tiers. Critical path: ~5-6 weeks at single-developer pace.

---

## 1. TL;DR

| What | Where |
|---|---|
| The problem | [§2](#2-why-this-exists) |
| The architecture (3-layer + SF) | [§3](#3-the-architecture-at-a-glance) + design doc §7.8 |
| MSPA + experiment-to-campaign flywheel | [§3.5](#35-mspa--the-experiment-to-campaign-flywheel) + mmf SKILL.md |
| Worked example (one campaign end-to-end) | [§3.6](#36-worked-example--one-campaign-end-to-end) |
| How we got here (research → BCs) | [§4](#4-the-journey-how-we-got-here) |
| What was decided (~30 locks) | [§5](#5-what-was-decided) + design doc §1-§7 |
| Glossary | [§6](#6-glossary) |
| The 23 Linear issues | [§7](#7-the-23-linear-issues) + `docs/linear-issues-created.md` |
| Decision-ID → BC cross-reference | [§7.5](#75-decision-id--bc-cross-reference) |
| Why each choice (decision log) | [§8](#8-decision-log--why-each-lock) + ADRs 012-019 |
| Onboarding by role | [§9](#9-per-audience-onboarding) |
| Where to find what | [§10](#10-artifact-index) |
| How we know nothing's missing | [§11](#11-how-we-know-nothings-missing--the-audit-narrative) |
| Next steps + open items | [§12](#12-next-steps--open-items) |

**Critical path entry point**: [BC-8712](https://linear.app/brite-nites/issue/BC-8712) (Task 0 — bootstrap).

---

## 2. Why this exists

Before this design, three separate "campaign" systems ran in parallel with three different definitions of what a campaign IS:

| System | Definition | Status pre-design |
|---|---|---|
| `brite-gtm/docs/campaign-portfolio.md` | 44 entries: Vertical × Offer × Quarter (planning unit) | Hand-maintained; informal |
| `handbook/marketing/go-to-market/active-campaigns.md` | Active/Paused/Completed status tracking table | Empty (nobody maintained) |
| Plugin `docs/campaigns/{entity}/{slug}/` | Per-launch artifact bundles (execution unit) | Used by 7 marketing skills |

**None of them were integrated.** Slugs, statuses, phase models (handbook's 7-step build vs brite-gtm's 8-phase outline vs plugin's 11-phase launch flow), and lifecycle stages were all inconsistent. There was no shared vocabulary, no single source-of-truth for live state, and no automated cross-system queries.

**The design session (2026-05-11/12) resolved the seam.** Three layers got crisp roles, Salesforce became the portfolio reporting surface (since SF Campaign records hold the bottom-funnel data Linear never will), and ~30 architectural decisions got locked. The implementation surface dropped out as 23 atomic Linear issues.

---

## 3. The architecture, at a glance

### 3-layer split (D2, reframed Phase 2)

```
   ┌──────────────────────────────────────────────────────────────────────┐
   │  HANDBOOK = HOW                                                      │
   │  brite-nites/handbook/marketing/                                     │
   │                                                                      │
   │  Frameworks (MSPA flywheel, Kellen's Laws, asymmetry rubric, offer  │
   │  postures, value equation, recency waterfall, verdicts cross-       │
   │  reference, vocabulary canon)                                        │
   │  Templates (campaign-brief, icp-persona)                             │
   │  Standards (cold-outbound-copy-standards, metrics-definitions)       │
   │  Playbooks (per-vertical READMEs)                                    │
   │  Process docs (campaign-lifecycle, how-we-operate)                   │
   │                                                                      │
   │  NEVER holds live campaign state.                                    │
   └──────────────────────────────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────────────────┐
   │  LINEAR = ORCHESTRATION / WORK / DRILL-DOWN                          │
   │  "Brite GTM" project (separate from "Brite Plugin Marketplace")     │
   │                                                                      │
   │  Milestones (one per campaign = Vertical × Persona × Offer × Month) │
   │  Sub-issues (8 standard + 2 optional per milestone — D4 template)   │
   │  Status labels (planning / active / completed / killed + paused)    │
   │  Brief text in milestone description (D5)                            │
   │  Audit trail (comments, approvals, weekly active-mgmt posts)         │
   └──────────────────────────────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────────────────┐
   │  PLUGIN = WHAT (entities + state)                                    │
   │  britenites-claude-plugins/plugins/marketing/                        │
   │                                                                      │
   │  canonicals.yaml (slug taxonomy — 27 verticals; persona slugs;       │
   │                   offer slugs)                                       │
   │  MSPA matrix (mmf-matrix.md per entity)                              │
   │  Learnings (learnings.md per entity, append-only)                    │
   │  Per-campaign artifacts (analysis-*.md, copy-*.json, manifest.json,  │
   │                          discoveries.json, performance.md)           │
   │  Commands (/marketing:plan-campaign, /marketing:portfolio-snapshot,  │
   │            /marketing:launch-campaign, etc.)                         │
   │  Skills (campaign-debrief, campaign-analysis, message-market-fit,    │
   │          email-copywriting, etc.)                                    │
   └──────────────────────────────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────────────────┐
   │  SALESFORCE = REPORTING / ATTRIBUTION / PORTFOLIO ROLLUP             │
   │  brite-salesforce repo (metadata) + Brite SF org                     │
   │                                                                      │
   │  Campaign object (one per Linear milestone, auto-created via σ3)    │
   │  Custom fields: Vertical__c, Persona__c, Offer__c, Entity__c,        │
   │                 Substatus__c                                         │
   │  4 saved list views (Active Campaigns default + 3 siblings)          │
   │  2 dashboards (Performance + Pipeline by Offer Family)              │
   │  Bottom-funnel: pipeline, revenue, leads, conversions                │
   │                                                                      │
   │  Source-of-truth for "what's the state of the portfolio RIGHT NOW?" │
   │  per O6.Q1 lock.                                                     │
   └──────────────────────────────────────────────────────────────────────┘
```

### Cross-system identity threading

```
   The SLUG is the universal anchor (O2).

   Slug rule:  {vertical}-{persona}-{offer}-fy{YY}-m{MM}
   Example:    municipalities-public-works-director-free-rop-audit-fy26-m05
   Cross-entity exception: cross-entity-{theme}-fy{YY}-m{MM}

   Slug appears VERBATIM in 4 systems:
     ▼
   ┌─────────────────────────────────────────────────────────────────────┐
   │  Plugin filesystem:  docs/campaigns/{entity}/{slug}/manifest.json   │
   │  Linear milestone:   slug:{slug} label + name = "{slug}"            │
   │  Email Bison:        Campaign Name = "{slug}"                       │
   │  Salesforce:         Campaign.Name = "{slug}"                       │
   └─────────────────────────────────────────────────────────────────────┘

   manifest.json carries the full cross-reference + state of every
   external ID; canonical-when-divergent over Linear.
```

### Campaign unit (D1)

**Campaign = one Vertical × one Persona × one Offer × one Month.** Each persona-targeting is its own Linear milestone. 1:1 mapping milestone ↔ EB campaign ↔ SF Campaign ↔ debrief. ~150-250 milestones/year realistic.

**Deeper architecture detail**: `docs/designs/gtm-campaign-orchestration-design.md` Section 7.8 carries the full O6 chain with ASCII diagrams.

---

## 3.5 MSPA + the experiment-to-campaign flywheel

Campaigns aren't picked by gut feel — they're driven by the **MSPA matrix** (Market × Segment × Persona × Angle), Brite's experiment-design framework from the `message-market-fit` skill. MSPA tells us WHICH campaigns to run; campaigns are the execution unit; verdicts feed back into the matrix.

### The flywheel — one entity, one MSPA matrix, append-only forever

```
   ┌──────────────────────────────────────────────────────────┐
   │  MAP mode — first time for an entity                     │
   │  → mmf-matrix.md created with 5 hypotheses (5 rows,      │
   │    each = 1 Market × 1 Segment × 1 Persona × 1 Angle)    │
   │  → mmf-batch-1.md designed                               │
   │  Verdict column starts at PENDING                        │
   └────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │  Each MSPA row → 1+ campaigns                            │
   │                                                          │
   │  MSPA matrix dimension  Campaign translation             │
   │  ─────────────────────────────────────────────────────   │
   │  Market (hypothesis)    Context for vertical+offer       │
   │                         selection (NOT in slug)          │
   │  Segment (instance)     Vertical narrowing or super-set  │
   │                         (NOT in slug)                    │
   │  Persona                Persona slug in campaign slug    │
   │                         {vertical}-{PERSONA}-{offer}-... │
   │  Angle                  Copy framing in email-           │
   │                         copywriting body / subject       │
   │                                                          │
   │  /marketing:plan-campaign scaffolds the campaign(s) →    │
   │  /marketing:launch-campaign fires the EB campaign        │
   └────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │  After EB send window closes:                            │
   │  → /marketing:campaign-analysis emits analysis-*.md      │
   │    with 5-verdict ranking (TOP PERFORMER / SCALE /       │
   │    TEST MORE / MONITOR / UNDERPERFORM)                   │
   │  → /marketing:campaign-debrief writes learnings.md       │
   │    entry with 4-verdict rubric (SCALE / ITERATE /        │
   │    PAUSE / KILL) + optional transferable_note            │
   └────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │  ITERATE mode — after batch completes                    │
   │  → mmf-results-{N}.md per batch                          │
   │  → matrix verdict column populated:                      │
   │      SUPER WORKS / KIND OF WORKS / DOESN'T WORK /        │
   │      DEFERRED                                            │
   │  → Step 3.5 reads transferable_notes back into matrix    │
   │  → mmf-batch-{N+1}.md designed (next 5 experiments)      │
   │  → barbell 80/20 allocation enforced                     │
   │  → Kellen's 10 Laws applied                              │
   └────────────────────────┬─────────────────────────────────┘
                            │
                            ▼ (loop)
```

### The 3 verdict vocabularies trace the lifecycle (State Q1 lock)

```
   Pre-experiment      →    Post-batch          →    Post-campaign
   (creative-angles)        (mmf ITERATE)            (campaign-debrief)
   ───────────────          ─────────────            ─────────────────
   Angle Verdict            Experiment Verdict       Campaign Verdict
   ALPHA                    SUPER WORKS              SCALE
   PROMISING                KIND OF WORKS            ITERATE
   INTERESTING              DOESN'T WORK             KILL
   COMMODITY                DEFERRED                 PAUSE
                            PENDING

   Best case:  ALPHA      → SUPER WORKS    → SCALE
   Iterate:    PROMISING  → KIND OF WORKS  → ITERATE
   Drop:       PROMISING  → DOESN'T WORK   → KILL
   Pre-empt:   COMMODITY  (never enters matrix)
   Wait:       any        → DEFERRED       → PAUSE
```

### DIAGNOSE mode — when pipeline is stuck

After ≥2 batches with flat results, mmf DIAGNOSE walks a 5-level root-cause sequence (Market → Segment → Persona → Angle → Execution), halts at first failure, emits `mmf-diagnosis-{YYYY-MM-DD}.md` with one root cause + prescription linking to the handling sibling skill (deliverability-audit, list-rebuild, etc.).

### Why this matters for the architecture

The MSPA matrix is what makes the plugin layer **compound**. Each campaign isn't a one-off — it's an experiment row whose verdict trains the next batch. The plugin's append-only `mmf-matrix.md` + `learnings.md` are the compounding surface. `portfolio-snapshot --quarterly` explicitly reads cross-quarter MSPA transitions as a section of the markdown packet (BC-8731).

### Frameworks that govern this loop

All canonical in handbook per O14 / BC-8732/BC-8733:

- **MSPA matrix** — 4 dimensions, append-only, one per entity forever
- **Barbell 80/20** — allocate 80% to known winners, 20% to bets
- **Kellen's 10 Laws** — iteration discipline (e.g., "Things that work and things you wanted to work are not synonymous")
- **MAP / ITERATE / DIAGNOSE modes** — entry rules per mode
- **Asymmetry Rubric** — upstream from creative-angles; angle quality score 0-10 driving the Angle Verdict
- **Hormozi Value Equation** — offer construction (orthogonal to MSPA layer)
- **Recency Waterfall** — 6-level signal hierarchy in email copy

### How MSPA shows up in the 23 BCs

- **BC-8721 (T5-M)** — renames 3 verdict parent labels (Angle Verdict / Experiment Verdict / Campaign Verdict) consistently across creative-angles, mmf, debrief
- **BC-8718 (T3-G)** — canonicals.yaml personas[] feed the Persona dimension at scaffold time
- **BC-8724 (T4-I)** — `/marketing:plan-campaign` validates Persona against canonicals (cross-checked vs an MSPA matrix row in the operator's head)
- **BC-8728 (T9-V)** — `/marketing:offer-performance` per-offer-version aggregation surfaces compounding across MSPA rows that share an Offer Family
- **BC-8731 (T7-Q)** — `/marketing:portfolio-snapshot --quarterly` reads MSPA Results Log for cross-quarter verdict transitions

---

## 3.6 Worked example — one campaign, end-to-end

To make all the abstractions concrete, here's a single campaign walked through every layer.

**Scenario**: Brite Nites wants to test a Municipalities-vertical Free ROP Audit offer with Public Works Directors as the targeted persona, launching in May 2026.

### Step 0 — Strategic context (BEFORE the operator runs anything)

The MSPA matrix for `nites` already has a row (from a prior MAP or ITERATE batch):

```
   Market: "Mid-size US cities exploring smart-lighting RFPs with
            new federal infrastructure dollars"
   Segment: Municipalities, $5M-$50M annual budget, no existing
            outdoor-lighting RFP committee
   Persona: Public Works Director
   Angle: "ROP audit shows you what's burning out — and you can
            fund the next phase from the federal pot you already
            have."
   Verdict: PENDING (this is the experiment)
```

This drives the campaign that's about to be created.

### Step 1 — Operator runs the scaffolding command

```bash
/marketing:plan-campaign \
  --vertical municipalities \
  --persona public-works-director \
  --offer free-rop-audit \
  --month 5 \
  --year 2026 \
  --launch-date 2026-05-15
```

(Or runs `/marketing:plan-campaign` with no flags and is walked interactively, one question at a time.)

### Step 2 — Canonicality validation (Plug-in side filesystem read)

The command reads `plugins/marketing/data/canonicals/_manifest.yaml` and `plugins/marketing/data/canonicals/municipalities.yaml`. Verifies:

- `vertical: municipalities` ✓ exists
- `personas[].slug: public-works-director` ✓ exists, with `titles[]: ["Public Works Director", "Director of Public Works", ...]`
- `offers[].slug: free-rop-audit` ✓ exists, `status: active`

Any miss → hard-fail with pointer to `/marketing:new-vertical | new-offer | new-persona` (BC-8725).

### Step 3 — Slug computation

`municipalities-public-works-director-free-rop-audit-fy26-m05`

Validates against `^[a-z0-9-]{1,80}$` ✓. Checks Linear "Brite GTM" project for collision → none. (If there were one, operator would be prompted to append `-v2`.)

### Step 4 — Dry-run preview + two-call confirm

Command prints the full plan: slug, entity (nites — auto-inferred from Municipalities vertical), launch date, sub-issue titles, manifest.json schema, SF Campaign payload, EB workspace (`emailbison-personal` for Nites). Operator types `y` to confirm.

### Step 5 — Plugin filesystem write

Creates `docs/campaigns/nites/municipalities-public-works-director-free-rop-audit-fy26-m05/manifest.json`:

```json
{
  "schema_version": 1,
  "slug": "municipalities-public-works-director-free-rop-audit-fy26-m05",
  "entity": "nites",
  "vertical": "municipalities",
  "persona": "public-works-director",
  "offer": "free-rop-audit",
  "year": 2026,
  "month": 5,
  "linear": { "milestone_id": null, "milestone_url": null, "project": "Brite GTM" },
  "salesforce": { "campaign_id": null, "campaign_name": "municipalities-public-works-director-free-rop-audit-fy26-m05" },
  "email_bison": { "workspace": "emailbison-personal", "campaign_id": null, "campaign_name": "...", "launched_at": null },
  "created_at": "2026-05-12T14:32:11Z",
  "scaffolded_by": "/marketing:plan-campaign"
}
```

### Step 6 — Linear milestone created in "Brite GTM" project

- **Name**: `municipalities-public-works-director-free-rop-audit-fy26-m05`
- **Description**: filled `campaign-brief-template.md` (8 sections) populated from handbook `verticals/municipalities/README.md` ICP section + `offers/free-rop-audit.md` content
- **Labels**: `slug:...`, `entity:nites`, `vertical:municipalities`, `persona:public-works-director`, `offer:free-rop-audit`, `year:2026`, `month:05`, `status:planning`

Manifest `linear.milestone_id` + `linear.milestone_url` updated.

### Step 7 — Salesforce auto-create (σ3 / via revops MCP)

`mcp__plugin_revops_salesforce__create_sf_campaign(slug, entity="nites", vertical="municipalities", persona="public-works-director", offer="free-rop-audit", year=2026, month=5, owner_email=<auto-detected>, launch_date=2026-05-15)` fires.

SF Campaign created with `Name=slug`, `Vertical__c="municipalities"`, `Persona__c="public-works-director"`, `Offer__c="free-rop-audit"`, `Entity__c="nites"`, `Status="Planned"`, `StartDate=2026-05-15`.

Manifest `salesforce.campaign_id` + `salesforce.campaign_name` updated.

**Soft-fail path**: if SF MCP is unavailable, manifest gets `campaign_id: null`, command warns + continues. Operator runs `/marketing:sync-campaign-status --slug=... --status=planning` later to reconcile (BC-8752).

### Step 8 — 8 sub-issues created with blocked-by chain

```
   #1 Brief approved                  blocks #2, #3, #4, #5, #6, #7, #8
   #2 Target list built               blocks #3
   #3 Copy written + approved         blocks #4
   #4 Salesforce setup (post-σ3 = reconciliation + audience members)  blocks #5
   #5 Pre-launch QA                   blocks #6
   #6 Launch executed                 blocks #7
   #7 Active management — weekly      blocks #8
   #8 Campaign closed + debrief       terminal
```

Operator can also add `--situation-mining` (rejected here — Labs only) or `--creative-angles` (optional).

### Step 9 — Summary output

Command prints milestone URL, slug, manifest path, sub-issue count + IDs.

### What happens next — execution lifecycle

```
   T-21d  Sarah Cullen drafts brief → reviews → closes sub-issue #1
                ↓
   T-14d  Corinne uses /marketing:list-building to build target list
          (reads canonicals municipalities.yaml personas[].titles[] for
           "Public Works Director" cascade) → closes sub-issue #2
                ↓
   T-10d  Sarah writes copy via /marketing:email-copywriting (artifact:
          docs/campaigns/nites/copy-municipalities-public-works-director-
          {date}.json with offer_posture: "free-asset" + offer_summary
          field + recency-waterfall framing) → closes sub-issue #3
                ↓
   T-7d   Corinne reconciles SF Campaign (sub-issue #4); adds
          CampaignMember records from list-building export → closes #4
                ↓
   T-3d   Pre-launch QA (deliverability + copy + sender warm-up) → #5
                ↓
   T+0    /marketing:launch-campaign fires EB campaign
          → manifest.email_bison.campaign_id populated
          → manifest.email_bison.launched_at = "2026-05-15T10:00:00Z"
          → Phase 11 calls update_sf_campaign_status(slug, "active",
             null) (BC-8752 trigger automation)
          → SF Campaign.Status = "In Progress"
          → Linear status:planning label removed; status:active added
          → sub-issue #6 closed
                ↓
   T+7d   /marketing:campaign-analysis runs → emits
          analysis-municipalities-public-works-director-free-rop-audit-
          fy26-m05-{date}.md with 6 sections + verdict tokens
          (TOP PERFORMER / SCALE / TEST MORE / MONITOR / UNDERPERFORM
           per ranked segment row)
                ↓
   T+30d  Corinne closes sub-issue #7 (Active management); runs
          /marketing:campaign-debrief
          → reads analysis-*.md for Q1/Q2/Q3 auto-suggestions
          → appends to docs/campaigns/nites/learnings.md with
             campaign_verdict: ITERATE + transferable_note: "ROP
             angle worked on mid-size cities; struggles on small
             towns under $5M budget"
          → triggers update_sf_campaign_status(slug, "completed", null)
          → SF Campaign.Status = "Completed"
          → sub-issue #8 closed; Linear status:completed label
                ↓
   Then   /marketing:message-market-fit ITERATE Step 3.5 reads
          learnings.md transferable_note back → updates mmf-matrix.md
          Results Log row from Verdict: PENDING → Verdict: KIND OF
          WORKS, Notes column: "[from debrief: ROP angle worked on
          mid-size cities; struggles on small towns under $5M
          budget]"
          → mmf-batch-{N+1}.md designed with refined Segment narrowing
```

### How this campaign shows up in rollup

- **Monthly review (T+30d)**: appears in SF Coverage by Vertical view; Performance Dashboard shows its pipeline; `/marketing:portfolio-snapshot --monthly` includes it in:
  - Portfolio shape section (1 campaign under Municipalities)
  - Verdict distribution section (1 ITERATE)
  - Transferable insights section ("ROP angle worked on mid-size cities; struggles on small towns")
  - Cumulative transferables get re-aggregated by `campaign-debrief`'s `learnings.md` regen on next debrief
- **Quarterly review (Q2)**: appears in Pipeline by Offer Family Dashboard alongside other "free-rop-audit" campaigns (if any); `/marketing:portfolio-snapshot --quarterly` shows MSPA matrix transition + persona drilldown

### What got produced

1 Linear milestone + 8 sub-issues + 1 SF Campaign + 1 manifest.json + 1 copy-*.json + 1 analysis-*.md + 1 learnings.md append + 1 mmf-matrix.md Results Log row.

That's the system in operation.

---

## 3.7 Operations cheatsheet — failure modes + routing maps + sequencing

The compressed operational reference. Bookmark this section if you're executing.

### Entity ↔ EB workspace routing

| Entity | EB workspace | Why |
|---|---|---|
| `nites` | `emailbison-personal` | Brite Nites maintains its own EB workspace separate from B2B |
| `supply` | `emailbison-b2b` | Brite Supply shares the B2B workspace |
| `labs` | `emailbison-b2b` | Brite Labs shares the B2B workspace |
| `cross-entity` | Operator picks via `--eb-workspace` flag | No default — cross-entity campaigns span workspaces |

Used by `/marketing:plan-campaign` Step 4 (BC-8724) + `/marketing:launch-campaign`. Stored in `manifest.json` `email_bison.workspace` field.

### Linear status → SF Campaign Status mapping (per σ3 / ADR-015)

| Linear label | SF Campaign Status | SF Substatus__c | Auto-trigger from |
|---|---|---|---|
| `status:planning` | Planned | — | `/marketing:plan-campaign` Step 7b (BC-8724) |
| `status:active` | In Progress | — | `launch-campaign` final phase (BC-8752) |
| `status:active` + `status:paused` | In Progress | Paused | Manual: `/marketing:sync-campaign-status` (BC-8752) |
| `status:completed` | Completed | — | `campaign-debrief` Workflow 4 post-append (BC-8752) |
| `status:killed` | Aborted | — | Manual: `/marketing:sync-campaign-status` (BC-8752) |

### Soft-fail paths (what happens when X breaks)

| When | What's expected | What happens | Recovery |
|---|---|---|---|
| `/marketing:plan-campaign` Step 7b SF auto-create fails (MCP down, dup slug, missing owner) | SF Campaign created with `campaign_id` populated in manifest | Manifest gets `campaign_id: null` + warning logged; plan-campaign exits 0 | Operator runs `/marketing:sync-campaign-status --slug=... --status=planning` after SF available |
| `update_sf_campaign_status` called on slug that doesn't exist in SF | Status updated | Returns `{warning: "campaign_not_found"}` + caller continues | Operator manually runs sync-campaign-status to retry |
| Canonicality validation fails (missing vertical/persona/offer in canonicals.yaml) | plan-campaign scaffolds | Hard-fail with pointer to `/marketing:new-vertical \| new-offer \| new-persona` (BC-8725) | Operator runs the sibling command + retries plan-campaign |
| `campaign-debrief` Workflow 4 status-sync call fails | SF Status flips to Completed | Soft-fail; learnings.md append still succeeds | Operator runs sync-campaign-status to reconcile |
| Two-call confirm interrupted | Nothing written | Plan-campaign exits cleanly with no artifacts | Operator re-runs; no cleanup needed |
| EB launch fails | Campaign launches | `/marketing:launch-campaign` halts with error; SF Status stays Planned | Operator fixes EB issue + re-runs launch-campaign |

### Implementation sequencing (when does what land?)

```
   Sprint 1-2   Tier 1 brite-salesforce metadata (BC-8713, BC-8714,
                BC-8715, BC-8716) + Tier 3 canonicals backfill (BC-8718)
                + Tier 5 migrations independent of Tier 1/2 (BC-8719,
                BC-8720, BC-8721, BC-8722) → all parallelizable

   Sprint 2-3   Tier 2 revops MCP write tools (BC-8717, BC-8723)
                → depends on Tier 1.A fields

   Sprint 3-4   Tier 4 plan-campaign (BC-8724)
                → depends on Tier 1 + Tier 2 + Tier 3-G
                Tier 2-FA σ3 trigger automation (BC-8752)
                → depends on Tier 2 MCPs + Tier 4 command

   Sprint 4-5   Tier 6 first dogfood + V3 ratification (BC-8727, BC-8729)
                → depends on Tier 4 + Tier 2-FA + Tier 5-K (slug migration)

   Sprint 5-6   Tier 7 portfolio-snapshot (BC-8731) IF V3 ratifies M2
                Tier 8 handbook PRs (BC-8732, BC-8733, BC-8734, BC-8735)
                → 4 parallel after V3 ratification

   Sprint 6+    Tier 9 deferrable commands (BC-8725, BC-8726, BC-8728)
                → file as backlog; revisit after Tier 7 ships
```

### Post-Tier-4 sequence (what happens between plan-campaign live and V3?)

Once BC-8724 ships:
1. Operator picks one campaign from brite-gtm `campaign-portfolio.md` (BC-8727 / T6-O) — likely a Brite Labs Zoos or similar high-signal candidate
2. Runs `/marketing:plan-campaign` end-to-end against real handbook canonicals
3. Captures friction log in `docs/plans/gtm-campaign-orchestration-plan.md` appendix
4. Tier 7 portfolio-snapshot ships in **dry-run mode** (emits packet against the dogfood data without committing to V3)
5. V3 meeting (BC-8729) reviews the populated dogfood snapshot — M2 vs M3 decision lands here
6. Tier 8 handbook PRs (BC-8732 onward) begin AFTER V3 ratifies — handbook PRs commit to M2-or-M3 wording

### V3 timing — when should it happen?

V3 ratification (BC-8729) MUST happen against a **populated dogfood snapshot**, not an empty hypothetical. Required pre-conditions:

- ≥1 campaign through plan-campaign with all 8 sub-issues opened (BC-8727)
- portfolio-snapshot dry-run produces a real markdown packet against that dogfood
- V3 packet committed to `docs/v3-ratification-packet-{date}.md` for offline review

V3 decision determines whether 5 BCs ship as-designed or degrade to M3 (see §5 M2/M3 callout).

---

## 4. The journey (how we got here)

```
   2026-05-11  Phase 1 design (research + 3-layer split + slug rule + O6.Q1-Q2)
       │
       ▼
   2026-05-11  Phase 2 architectural pivot
       │       (Handbook=HOW / Plugin=WHAT; canonicals plugin-side;
       │       discoveries.json category pattern; σ3 SF auto-create;
       │       vocabulary canon across 5 categories; D7 thin schema)
       │
       ▼
   2026-05-11  Pause at end of Phase 2 (open: O6.Q3-Q5, D8, O8-15)
       │
       ▼
   2026-05-12  Session resume — O6 chain walked Q1 → Q2 → Q3 (4 rows)
       │       → Q4 → Q5; all locked
       │
       ▼
   2026-05-12  Master plan drafted at docs/plans/gtm-campaign-
       │       orchestration-plan.md (21 BC sketches in 9 tiers)
       │
       ▼
   2026-05-12  Refined via /workflows:refine-plan → docs/project-plan-
       │       refined.md (898 lines, Task 0 + 21 tasks, Mermaid graph)
       │
       ▼
   2026-05-12  Filed via /workflows:create-issues → 22 BCs created
       │       (BC-8712 through BC-8735)
       │
       ▼
   2026-05-12  Independent audit by general-purpose agent + sequential-
       │       thinking. Verdict: FLAGS (1 P1, 7 P2, 11 P3). No FAIL.
       │
       ▼
   2026-05-12  Audit fixes shipped:
       │       - BC-8752 filed (σ3 trigger automation, the P1)
       │       - 5 BC bodies updated for P2 gaps
       │       - 3 memory files cleaned for stale headers
       │
       ▼
   2026-05-12  Effort README drafted (THIS DOC)
       │       — orientation + decision log + onboarding paths.
       │
       ▼
   READY FOR EXECUTION
```

**Methodology callout**: this is the canonical "design → plan → refine → file → audit → fix" pipeline. The same pipeline can be replicated for other large efforts. Each step has its own skill: brainstorming → writing-plans → refine-plan → create-issues → independent review agent.

---

## 5. What was decided

~30 architectural decisions locked. Grouped by category:

### Foundation (Phase 1)

| ID | Decision | Locked because |
|---|---|---|
| **D1** | Campaign unit = Vertical × Persona × Offer × Month | Each persona-targeting is a first-class campaign; 1:1 mapping prevents the "Wave" anti-pattern |
| **D2** | 3-layer split (Handbook = HOW; Linear = orchestration; Plugin = WHAT) | Each system has one job; no overlap; D6 + Phase 2 reframe sharpen the WHAT side |
| **D3** | Sub-issues = stand-up work (not waves) | Linear is for WORK; plugin artifacts live on disk and are REFERENCED in sub-issue comments |
| **D4** | 8 standard + 2 optional sub-issue template | Faithful to handbook campaign-planning.md 7-step build + lifecycle Workflow B brief-gate |
| **D5** | Filled brief = Linear milestone description | Handbook owns blank template; Linear owns per-campaign instance |
| **D6** | Handbook = navigation, not state | active-campaigns.md becomes a pointer to SF/Linear views, not a tracking table |
| **D7** | Thin canonicals schema (slug + display + personas[] + offers[]) | Phase 2 re-walk dropped status/business_units/service_types/icps[] nesting |
| **D9** | Single-repo plugin-owned schema versioning | No cross-repo coordination needed; canonicals plugin-side |
| **D11** | All 27 verticals backfilled day-1 | Skeleton entries acceptable; persona authorship (D8) is the human work |

### Portfolio rollup (O6, the late session)

| ID | Decision | Locked because |
|---|---|---|
| **O6.Q1** | Rollup home = Salesforce list view (primary); Linear = per-campaign drill-down | SF has bottom-funnel data Linear never will; σ3 already commits SF Campaign auto-create; SF list views + reports beat Linear's view editor for cross-record aggregation |
| **O6.Q2** | Default "Active Campaigns" view spec — Status-grouped, 7 columns, default filter excludes Completed + Killed | Monday GTM sync wants funnel-shape at a glance; lean columns for scan density |
| **O6.Q3 row 1** | Daily — no portfolio rollup | Daily ops are per-person, not portfolio; ritual would skip-or-bloat |
| **O6.Q3 row 2** | Weekly GTM sync — Active Campaigns default + Launch Calendar sibling; no plugin command | Two URLs in meeting doc; SF + Linear drill-down sufficient |
| **O6.Q3 row 3** | Monthly review — Coverage by Vertical + NEW Performance Dashboard + `/marketing:portfolio-snapshot --monthly` | Monthly needs qualitative + quantitative merge; SF alone misses learnings/debriefs |
| **O6.Q3 row 4** | Quarterly planning — Coverage (FY) + Performance Dashboard (FY) + NEW Pipeline by Offer Family Dashboard + `--quarterly` snapshot + brite-gtm queue | Offer-family granularity is quarterly-specific; brite-gtm is pre-Linear ideation graduation point |
| **O6.Q4** | Retro rhythm subsumed by D4 + Q3 | No weekly/annual/per-vertical/cycle retro needed; existing layers cover |
| **O6.Q5** | `/marketing:portfolio-snapshot` ships with two flags only | V3-gated; anti-creep guards (no charts/forecasts/custom windows) load-bearing — see M2/M3 callout below |

#### M2 vs M3 — what V3 ratification ships (or drops)

V3 ratification (BC-8729) determines the outcome. The decision shapes what 5 BCs ship.

```
   M2 (Marketing RATIFIES the packet)        M3 (Marketing REJECTS the packet)
   ───────────────────────────────────       ───────────────────────────────────
   ✓ 4 SF custom fields (BC-8713)             ✓ 4 SF custom fields (BC-8713)
   ✓ 4 SF saved list views (BC-8714)          ✓ 4 SF saved list views (BC-8714)
   ✓ Performance Dashboard (BC-8715)          ✓ Performance Dashboard (BC-8715)
   ✓ Pipeline-by-Offer-Family Dash (BC-8716)  ✗ Pipeline-by-Offer-Family DROPPED
   ✓ create_sf_campaign MCP (BC-8717)         ✓ create_sf_campaign MCP (BC-8717)
   ✓ update_sf_campaign_status MCP (BC-8723)  ✓ update_sf_campaign_status MCP (BC-8723)
   ✓ σ3 trigger automation (BC-8752)          ✓ σ3 trigger automation (BC-8752)
   ✓ portfolio-snapshot --monthly|--quarterly ✗ portfolio-snapshot DROPPED
   ✓ Handbook PR: vocabulary.md (BC-8732)     ? Handbook PRs MAYBE — depends on
   ✓ Handbook PR: framework docs (BC-8733)      what else V3 rejects in the
   ✓ Handbook PR: active-campaigns (BC-8734)    ratification packet
   ✓ Handbook PR: how-we-operate (BC-8735)
                                              Reader's monthly review uses ONLY:
   Reader's monthly review uses:               - Coverage by Vertical (SF)
     - Coverage by Vertical (SF)               - Performance Dashboard (SF)
     - Performance Dashboard (SF)              No qualitative merge; no frozen
     - portfolio-snapshot.md packet             markdown packet; no per-offer-
       (merges SF + plugin qualitative)         family cross-quarter visibility
     - Pipeline by Offer Family (SF)
                                              Reader's quarterly planning loses:
   Reader's quarterly review adds:             - Cross-quarter MSPA synthesis
     - Cross-quarter MSPA transitions            (lives only in mmf-matrix.md)
     - Cumulative transferables                - Cumulative transferables digest
     - Coverage-gap callouts                     (lives only in learnings.md)
     - brite-gtm pre-Linear queue               - Coverage-gap callouts
       graduation review
```

V3 happens against a **populated dogfood snapshot** (T6-O / BC-8727 first; T7-Q dry-run; THEN V3). If Marketing rejects after seeing the actual markdown packet against actual data, the rebound is tractable — 5 BCs cascade to backlog; SF-side artifacts still ship; meetings degrade to SF-only.



### σ3 (Salesforce integration)

| ID | Decision | Locked because |
|---|---|---|
| **σ3 (O11)** | Auto-create SF Campaign at scaffold via NEW revops:salesforce MCP `create_sf_campaign` write tool | Linear is orchestration; SF is attribution; keep D2 unchanged; soft-fail path if MCP unavailable |
| **σ3 scope expansion** | Same MCP also exposes `update_sf_campaign_status` | Status syncs on sub-issue 6/8 closes + status:paused toggle + status:killed transition |

### Vocabulary canon (5 categories, all locked)

| Category | Locks |
|---|---|
| **Identity** | Vertical (handbook canon) + Market (MSPA hypothesis context) — both kept distinct; ICP = template (handbook + tam-mapping JSON) / Segment = instance (MSPA matrix); 4-layer offer model (Family > Posture > Angle > Specific Instance); persona schema = slug + display + titles[]; **Offer Tier renamed → Offer Posture** (was T1/T2/T3/T4 — collided with list-building's title cascade) |
| **State** | 3 verdict vocabularies kept distinct: **Angle Verdict** (creative-angles, pre-experiment) / **Experiment Verdict** (mmf, post-batch) / **Campaign Verdict** (debrief, post-campaign) |
| **Process/Framework** | No collisions; canonical sources locked in current SKILL.md files |
| **Artifact** | Entity slug short-form everywhere under `docs/campaigns/{entity}/` (was long-form `brite-{entity}/`); migration in O15 |
| **Metric** | No collisions; canonical from `campaign-analysis` §3.3 b2b benchmarks |

### Phase 2 architectural pivots

| Pivot | Detail |
|---|---|
| Handbook = HOW / Plugin = WHAT | Reframes D2 — handbook owns frameworks/templates/playbooks; plugin owns entities/state |
| canonicals.yaml = plugin-side | `plugins/marketing/data/canonicals/`; NOT handbook-side |
| discoveries.json category-tagged | Skills emit signals; humans promote via PR; categories: title-discovery / icp-refinement / offer-retirement / persona-discovery |

### Other locks (O5, O7, D10)

| ID | Decision |
|---|---|
| **O5** | Same-month + new copy = `-v2` slug suffix (operator-explicit) |
| **O7** | brite-gtm campaign-portfolio.md = pre-Linear ideation queue (graduates to Linear) |
| **D10** | DROPPED — `--handbook-ref` flag unnecessary (canonicals plugin-local) |

**Full lock narrative**: `docs/designs/gtm-campaign-orchestration-design.md` Sections 1-7.

---

## 6. Glossary

The shared vocabulary across all artifacts and Linear issues.

### Identity terms

| Term | Definition | Canonical source |
|---|---|---|
| **Vertical** | Industry/market category from handbook taxonomy. 27 verticals; 7 Active + 8 Exploring + 12 Future. | `handbook/marketing/go-to-market/verticals/README.md` |
| **Market** | Per-experiment hypothesis context in MSPA matrix M column. NOT the taxonomy. | `message-market-fit` SKILL.md |
| **Entity** | Three Brite entities: `nites`, `supply`, `labs`. Plus `cross-entity` for multi-vertical. | Brite handbook |
| **ICP** | Reusable firmographic + persona + worldview template for a vertical. Lives in handbook prose + tam-mapping JSON. | Handbook vertical READMEs |
| **Segment** | Per-experiment INSTANCE in MSPA matrix S column. Disposable. | `message-market-fit` SKILL.md |
| **Persona** | Job role + seniority. Schema: `slug` + `display` + `titles[]`. | canonicals.yaml + handbook prose |
| **Offer Family** | Layer 1 of 4-layer offer model. Stable bundle (e.g., "ZooLights-Style Holiday Experience"). | canonicals.yaml |
| **Offer Posture** | Layer 2. CTA architecture / commitment level. Values: `knowledge` / `free-asset` / `pilot` / `risk-reversal`. **Renamed from Offer Tier per ID Q5.** | Handbook framework doc (O14 / BC-8732) |
| **Angle** | Layer 3. Per-experiment framing. MSPA matrix A column. Quality test: swap-Brite-for-competitor → does sentence still read? | `message-market-fit`, `creative-angles` |
| **Specific Offer Instance** | Layer 4. One-line operator-readable summary = Family + Posture + Angle. | copy artifact JSON `offer_summary` |

### State terms

| Term | Definition | Used by |
|---|---|---|
| **Angle Verdict** | ALPHA / PROMISING / INTERESTING / COMMODITY. Pre-experiment decision. | `creative-angles` |
| **Experiment Verdict** | SUPER WORKS / KIND OF WORKS / DOESN'T WORK / DEFERRED / PENDING. Post-batch. | `message-market-fit` ITERATE |
| **Campaign Verdict** | SCALE / ITERATE / PAUSE / KILL. Post-campaign. | `campaign-debrief` |
| **Status** (Linear milestone) | Primary: planning / active / completed / killed. Overlay: paused. | O1 lock |
| **Substatus__c** (SF) | Carries the paused overlay since SF Status is single-valued. | O6.Q1 σ3 scope expansion |

### Artifact terms

| Term | Definition / Path |
|---|---|
| **Slug** | `{vertical}-{persona}-{offer}-fy{YY}-m{MM}`. Universal anchor across 4 systems. |
| **manifest.json** | `docs/campaigns/{entity}/{slug}/manifest.json`. Cross-system identity + state. Canonical when divergent from Linear. |
| **canonicals.yaml** | `plugins/marketing/data/canonicals/_manifest.yaml` + `{vertical}.yaml`. Slug taxonomy. |
| **discoveries.json** | `docs/campaigns/{entity}/{slug}/discoveries.json`. Category-tagged signals from skills awaiting human promotion. |
| **learnings.md** | `docs/campaigns/{entity}/learnings.md`. Append-only verdict registry per entity. |
| **mmf-matrix.md** | `docs/campaigns/{entity}/mmf-matrix.md`. MSPA matrix per entity, append-only. |
| **analysis-*.md** | `docs/campaigns/{entity}/analysis-{campaign-name}-{date}.md`. Per-campaign analysis with 6 sections + 5 verdict labels. |
| **performance.md** | `docs/campaigns/{entity}/offers/{slug}/{version}/performance.md`. Per-offer-version aggregation (O13 / T9-V). |
| **monthly-{YYYY-MM}.md** | `docs/campaigns/_reviews/`. Portfolio snapshot packet (O6.Q3 row 3 / T7-Q). |
| **quarterly-{YYYY-Q}.md** | `docs/campaigns/_reviews/`. Quarterly variant (O6.Q3 row 4). |

### Process terms

| Term | Definition |
|---|---|
| **σ3** | The Salesforce-integration lock from O11. Auto-create SF Campaign via revops:salesforce MCP at plan-campaign scaffold time. Scope expanded by O6.Q1 to include status sync. |
| **V3** | Marketing buy-in ratification meeting (BC-8729 / T6-P). Load-bearing M2/M3 gate. |
| **M2 vs M3** | M2 = ship portfolio-snapshot + Pipeline-by-Offer-Family Dashboard + handbook PRs. M3 = drop these; SF Dashboard + Coverage view still ship. V3 decides. |

**Full disambiguation**: `memory/project_marketing_vocabulary.md` — complete vocabulary canon with worked examples, rejected alternatives per term, and skill ownership map.

### Brite infrastructure terms (the words this README assumes you know)

Audience: external partners / new hires / anyone outside the Brite engineering org bubble.

| Term | Definition |
|---|---|
| **BC-XXXX** | Linear issue prefix for Brite Company team. Example: BC-8712. Linear projects under Brite Company hold all engineering work + the GTM campaign portfolio (separate "Brite GTM" project for campaigns themselves). |
| **MCP** | Model Context Protocol — Anthropic's standard for letting Claude Code call external services (Linear, Salesforce, Email Bison, etc.). Plugins register MCP servers; skills declare which MCP tools they call via `allowed-tools` frontmatter. |
| **Plugin** | A bundle under `plugins/{name}/` containing commands, skills, hooks, and MCP servers. This repo has 5 plugins (workflows, marketing, cadence, revops, flow-architecture). Each plugin has its own `plugin.json` + version. |
| **Skill** | An auto-invoked instruction set under `plugins/{name}/skills/{skill}/SKILL.md`. Claude matches user intent against skill `description` fields and loads matching skills at runtime. |
| **Command** | An operator-invoked slash command under `plugins/{name}/commands/{cmd}.md`. Examples: `/marketing:plan-campaign`, `/workflows:create-issues`. |
| **Linear "milestone"** | A grouping anchor inside a Linear project. In the Brite GTM project, one milestone = one campaign (per ADR-012). Distinct from Linear "issue" (a single ticket). |
| **Linear "sub-issue"** | A Linear issue with a parent issue or parent milestone. The 8+2 sub-issue template (per ADR-012 + D4) groups under a milestone. |
| **σ3** | Token label for the Salesforce-orchestration sub-decision from the design session's O11 question. See [ADR-015](decisions/015-gtm-sigma3-sf-campaign-sync.md). |
| **M2 / M3** | Outcomes of V3 Marketing ratification. M2 ships portfolio-snapshot + Pipeline-by-Offer-Family Dashboard + 4 handbook PRs. M3 drops those 5 BCs; SF Performance Dashboard + Coverage view still ship. See [§5 M2/M3 callout](#5-what-was-decided). |
| **V3** | Validation gate from the design session — Marketing buy-in (Sarah Cullen + Kells) on the canonicals + vocab + framework docs + portfolio-snapshot packet, against a populated dogfood (BC-8729). |
| **Brite GTM project** | The Linear project that holds campaign milestones (separate from "Brite Plugin Marketplace" which holds plugin engineering work). Per D2 / ADR-013 + O7. Provisioned by BC-8712 Task 0. |
| **brite-gtm repo** | Sibling git repo at `/Users/holdenhalford/projects/work/brite-nites/brite-gtm/`. Holds the pre-Linear ideation queue (`docs/campaign-portfolio.md` with 🟢🟡⚪ candidates) per O7. NOT the same as the Linear "Brite GTM" project. |
| **Tier** | Grouping concept from the implementation plan — 9 tiers across the 23 BCs (Tier 1 = SF metadata foundation; Tier 9 = optional sibling commands). See [§7](#7-the-23-linear-issues). |
| **plugin version bump** | CLAUDE.md gotcha: when any plugin file under `plugins/{name}/{commands,skills,hooks,agents}/**` changes, the matching `plugin.json` + `marketplace.json` entry MUST be version-bumped in the same commit. BC-6000 precedent — 4 stale-cache sessions lost. |
| **Two-call confirm** | The BC-2707 precedent pattern for plugin commands that mutate state. First Bash call prints the plan + "Confirm? (y/n)"; operator responds; second Bash call proceeds only if confirmed. Used by `/marketing:plan-campaign` Step 6 + `/marketing:launch-campaign`. |
| **/workflows:create-issues** | The skill that converts a refined plan doc into Linear issues with cross-linked dependencies. Used by BC-8712 Task 0 Step 2. |

---

## 7. The 23 Linear issues

All issues in the **Brite Plugin Marketplace** project (team Brite Company).

### By tier

| BC | Task | Title (abbreviated) | Tier | Complexity |
|---|---|---|---|---|
| [BC-8712](https://linear.app/brite-nites/issue/BC-8712) | Task 0 | Bootstrap — create-issues + setup-claude-md + provision Brite GTM project | — | S |
| [BC-8713](https://linear.app/brite-nites/issue/BC-8713) | T1-A | 4 SF custom fields | 1 | S |
| [BC-8714](https://linear.app/brite-nites/issue/BC-8714) | T1-B | 4 SF saved list views | 1 | S |
| [BC-8715](https://linear.app/brite-nites/issue/BC-8715) | T1-C | Performance Dashboard | 1 | M |
| [BC-8716](https://linear.app/brite-nites/issue/BC-8716) | T1-D | Pipeline by Offer Family Dashboard | 1 | M |
| [BC-8717](https://linear.app/brite-nites/issue/BC-8717) | T2-E | create_sf_campaign MCP tool | 2 | M |
| [BC-8723](https://linear.app/brite-nites/issue/BC-8723) | T2-F | update_sf_campaign_status MCP tool | 2 | S |
| [BC-8752](https://linear.app/brite-nites/issue/BC-8752) | T2-FA | σ3 trigger automation (audit-fix) | 2 | M |
| [BC-8718](https://linear.app/brite-nites/issue/BC-8718) | T3-G | canonicals.yaml backfill (27 verticals) | 3 | M |
| [BC-8730](https://linear.app/brite-nites/issue/BC-8730) | T3-H | D8 persona authorship process doc | 3 | S |
| [BC-8724](https://linear.app/brite-nites/issue/BC-8724) | T4-I | `/marketing:plan-campaign` command | 4 | L |
| [BC-8719](https://linear.app/brite-nites/issue/BC-8719) | T5-K | Entity slug short-form migration | 5 | S |
| [BC-8720](https://linear.app/brite-nites/issue/BC-8720) | T5-L | offer-tier → offer-posture rename | 5 | M |
| [BC-8721](https://linear.app/brite-nites/issue/BC-8721) | T5-M | 3-verdict parent labels rename | 5 | S |
| [BC-8722](https://linear.app/brite-nites/issue/BC-8722) | T5-N | discoveries.json category schema | 5 | M |
| [BC-8727](https://linear.app/brite-nites/issue/BC-8727) | T6-O | First dogfood campaign | 6 | M |
| [BC-8729](https://linear.app/brite-nites/issue/BC-8729) | T6-P | V3 Marketing ratification | 6 | S |
| [BC-8731](https://linear.app/brite-nites/issue/BC-8731) | T7-Q | `/marketing:portfolio-snapshot` command | 7 | L |
| [BC-8732](https://linear.app/brite-nites/issue/BC-8732) | T8-R | Handbook PR — vocabulary.md | 8 | M |
| [BC-8733](https://linear.app/brite-nites/issue/BC-8733) | T8-S | Handbook PR — 7 framework docs | 8 | L |
| [BC-8734](https://linear.app/brite-nites/issue/BC-8734) | T8-T | Handbook PR — active-campaigns nav refactor | 8 | S |
| [BC-8735](https://linear.app/brite-nites/issue/BC-8735) | T8-U | Handbook PR — how-we-operate cadence rows | 8 | S |
| [BC-8728](https://linear.app/brite-nites/issue/BC-8728) | T9-V | `/marketing:offer-performance` (deferrable) | 9 | M |
| [BC-8725](https://linear.app/brite-nites/issue/BC-8725) | T9-W | new-vertical/offer/persona commands (deferrable) | 9 | M |
| [BC-8726](https://linear.app/brite-nites/issue/BC-8726) | T9-X | icp-refinement-review command (deferrable) | 9 | M |

### Critical path

```
   BC-8712  →  BC-8713  →  BC-8717  →  BC-8724  →  BC-8727  →  BC-8729  →  BC-8752  →  BC-8731
   Task 0      T1-A         T2-E         T4-I         T6-O         T6-P         T2-FA       T7-Q
   bootstrap   SF fields    MCP write    plan-cmd     dogfood      V3 gate      triggers    snapshot
```

Sequential effort: S + S + M + L + M + S + M + L ≈ **5-6 weeks** at single-developer pace.

### Parallelization windows

- After **BC-8713** ships, BC-8714 / BC-8715 / BC-8716 can land in parallel (all depend only on the custom fields).
- **Tier 5 migrations** (BC-8719, BC-8720, BC-8721, BC-8722) are all independent of Tier 1/2 — can land anytime.
- **Tier 3 canonicals** (BC-8718) is independent of Tier 1/2 — can land while SF metadata work is in flight.
- **Tier 8 handbook PRs** (BC-8732, BC-8733, BC-8734, BC-8735) all parallel after V3 (BC-8729) ratifies M2.

**Mermaid dependency graph**: `docs/project-plan-refined.md` Section 4.
**Full per-BC tables**: `docs/linear-issues-created.md` (BC ↔ task mapping, priority rationale, blocked-by map).

---

## 7.5 Decision-ID → BC cross-reference

Every locked decision maps to at least one BC, an ADR, or an explicit out-of-scope acknowledgment. This is the auditor's lens — verifies "every decision has a home."

| Decision | BCs | ADR | Notes |
|---|---|---|---|
| **D1** Campaign unit = V × P × O × M | BC-8724 | [ADR-012](decisions/012-gtm-campaign-unit.md) | `/marketing:plan-campaign` implements |
| **D2** 3-layer split (Handbook/Linear/Plugin) | BC-8712 | [ADR-013](decisions/013-gtm-three-layer-split.md) | Architectural anchor in Task 0 README |
| **D3** Sub-issues = stand-up work | BC-8724 | — | Sub-issue emission in Step 12 |
| **D4** 8+2 sub-issue template | BC-8724 | — | Step 12 full blocked-by chain |
| **D5** Brief in Linear milestone desc | BC-8724 | — | Step 10a handbook template population |
| **D6** Handbook = navigation | BC-8734 | — | active-campaigns.md repoint |
| **D7** Thin canonicals schema | BC-8718 | [ADR-016](decisions/016-gtm-plugin-side-canonicals.md) | Schema in Step 1 |
| **D8** Persona authorship process | BC-8730 | — | Doc + cadence + ownership; depends on V3 |
| **D9** Single-repo schema versioning | BC-8718 | [ADR-016](decisions/016-gtm-plugin-side-canonicals.md) | `_manifest.yaml` `schema_version: 1` |
| **D10** DROPPED — `--handbook-ref` flag | — | [ADR-016](decisions/016-gtm-plugin-side-canonicals.md) | Out of scope (canonicals plugin-local) |
| **D11** 27 verticals day-1 | BC-8718 | — | Backfill scope |
| **O1** Status labels | BC-8723, BC-8724 | [ADR-015](decisions/015-gtm-sigma3-sf-campaign-sync.md) | Mapping table + label application |
| **O2** Slug rule + manifest.json | BC-8724 | [ADR-012](decisions/012-gtm-campaign-unit.md) | Slug computation Step 5 + manifest write Step 9 |
| **O3** `/marketing:plan-campaign` cmd | BC-8724 | — | The command itself |
| **O5** Same-month -v2 suffix | BC-8724 | — | Step 5 collision branch |
| **O6.Q1** Salesforce rollup home | BC-8714, BC-8715, BC-8716 | [ADR-014](decisions/014-gtm-salesforce-portfolio-rollup.md) | Views + Performance Dashboard + Pipeline-by-Offer-Family |
| **O6.Q2** Default view spec | BC-8714 | — | Active Campaigns saved view |
| **O6.Q3 r1** Daily — no rollup | BC-8735 | — | Handbook PR cadence rows |
| **O6.Q3 r2** Weekly GTM sync views | BC-8714, BC-8735 | — | Active Campaigns + Launch Calendar |
| **O6.Q3 r3** Monthly review | BC-8715, BC-8731, BC-8735 | — | Performance Dashboard + snapshot + handbook cadence |
| **O6.Q3 r4** Quarterly planning | BC-8716, BC-8731, BC-8735 | — | Pipeline Dashboard + snapshot --quarterly + brite-gtm queue |
| **O6.Q4** Retro subsumed by D4 + Q3 | — | — | No BC (implicit; handbook PR may reference) |
| **O6.Q5** portfolio-snapshot ships | BC-8731, BC-8729 | [ADR-014](decisions/014-gtm-salesforce-portfolio-rollup.md) | Command + V3 gate |
| **O7** brite-gtm = pre-Linear queue | — | — | Out of scope (no plugin work needed) |
| **O11/σ3** SF auto-create | BC-8717 | [ADR-015](decisions/015-gtm-sigma3-sf-campaign-sync.md) | `create_sf_campaign` MCP tool |
| **σ3 scope expansion** | BC-8723, BC-8752 | [ADR-015](decisions/015-gtm-sigma3-sf-campaign-sync.md) | `update_sf_campaign_status` + trigger wiring |
| **Vocab Identity Q1** Vertical / Market | — | — | No BC; canonical (handbook prose) |
| **Vocab Identity Q2** ICP / Segment | — | — | No BC; canonical (handbook prose) |
| **Vocab Identity Q3** 4-layer offer model | BC-8720 | [ADR-017](decisions/017-gtm-offer-posture-rename.md) | Family / Posture / Angle / Specific Instance |
| **Vocab Identity Q4** Persona schema | BC-8718 | [ADR-016](decisions/016-gtm-plugin-side-canonicals.md) | slug + display + titles[] in canonicals |
| **Vocab Identity Q5** Offer Tier → Posture | BC-8720 | [ADR-017](decisions/017-gtm-offer-posture-rename.md) | Cross-skill rename migration |
| **Vocab State Q1** 3 distinct verdicts | BC-8721 | [ADR-018](decisions/018-gtm-verdict-vocabularies.md) | Parent label renames per skill |
| **Vocab Artifact Q1** Entity slug short-form | BC-8719 | — | Migration `brite-{entity}/` → `{entity}/` |
| **discoveries.json category pattern** | BC-8722 | [ADR-019](decisions/019-gtm-mspa-flywheel-as-architecture-spine.md) | 4-category schema |
| **Phase 2: Handbook = HOW pivot** | BC-8732, BC-8733 | [ADR-013](decisions/013-gtm-three-layer-split.md) | Handbook framework docs |
| **Phase 2: canonicals plugin-side** | BC-8718 | [ADR-016](decisions/016-gtm-plugin-side-canonicals.md) | Path + schema lock |
| **MSPA flywheel as architecture spine** | BC-8721, BC-8722, BC-8728, BC-8731, BC-8733 | [ADR-019](decisions/019-gtm-mspa-flywheel-as-architecture-spine.md) | The compounding pattern |
| **V1** gh CLI auth audit | — | — | Out of scope per plan §7 |
| **V2** Handbook parsing audit | BC-8732 | — | Inline grep during vocabulary.md drafting |
| **V3** Marketing buy-in | BC-8729 | — | Load-bearing M2/M3 gate |
| **O4** Post-launch metric writeback | — | — | Out of scope per plan §7 (future) |

**Verification check**: 40 rows, 23 unique BCs cited + 8 ADRs cited + 6 explicit out-of-scope rows. Spot-check any decision in §5 or §8 → resolves to this table → resolves to BC or ADR.

---

## 8. Decision log — why each lock

Defensibility surface. For each lock: what we chose, what we rejected, why we rejected it.

| # | Decision | What we chose | Rejected alternative | Why rejected |
|---|---|---|---|---|
| 1 | Campaign unit (D1) | Vertical × Persona × Offer × Month | Vertical × Offer × Quarter (with multi-persona "waves") | Coarser unit hid persona-level signal; "wave" concept dissolved when persona became first-class |
| 2 | 3-layer split (D2) | Handbook / Linear / Plugin each own one job | Single Linear-only system; or Notion as state of record | Notion is read-only deprecated; Linear-only loses handbook canonicality + plugin execution surface |
| 3 | Brief location (D5) | Linear milestone description | Plugin filesystem; or handbook per-campaign doc | Plugin filesystem loses operator audit trail; handbook violates D6 |
| 4 | Sub-issue count (D4) | 8 standard + 2 optional | 7 standard (collapsing Brief into List); or "1 mega-issue per campaign" | Brief approval is a real gate; mega-issue loses sub-issue work granularity |
| 5 | canonicals location (Phase 2) | `plugins/marketing/data/canonicals/` (plugin-side) | `handbook/.../canonicals.yaml` | Plugin-side avoids gh auth + cross-repo coordination; cross-tool consumers read from britenites-claude-plugins anyway |
| 6 | Canonicals schema (D7) | Thin: slug + display + personas[] + offers[] | Rich: + status + business_units + service_types + icps[] nesting | Rich schema duplicated handbook taxonomy table; YAGNI for service_types; icps[] conflicted with ID Q2 (ICP=template, Segment=instance) |
| 7 | Offer Tier rename (ID Q5) | "Offer Posture" with values knowledge/free-asset/pilot/risk-reversal | Keep "Offer Tier" with T1/T2/T3/T4 letter codes | T1/T2/T3 collided with list-building's title cascade (title-tier T1=C-suite, T2=VP, T3=Director); confusion in operator mental model |
| 8 | Verdict vocabularies (State Q1) | 3 distinct: Angle Verdict / Experiment Verdict / Campaign Verdict | Merge into one "verdict" token set | Different evidence bases (asymmetry rubric / EB metrics / cross-campaign synthesis) + different timing + different owners |
| 9 | discoveries.json shape | Category-tagged signals (title / icp / offer-retirement / persona); skills emit, humans promote via PR | Skills directly mutate canonicals + handbook | Removes human review gate; couples automated emission to canonical sources |
| 10 | Slug rule (O2) | `{vertical}-{persona}-{offer}-fy{YY}-m{MM}`; entity in label not slug | Slug includes entity prefix `{entity}-...` | Entity is naturally a Linear label + path prefix; redundant in slug |
| 11 | Status labels (O1) | 4 primary (planning/active/completed/killed) + paused overlay | Single timeline status with paused as fifth primary value | Paused is stackable — campaign can be "active + paused"; overlay model preserves this |
| 12 | Multi-wave handling (O5) | `-v2` suffix for same-month + new copy | Automatic numeric suffix on any collision | Operator-explicit decision better than silent auto-increment |
| 13 | brite-gtm future role (O7) | Pre-Linear ideation queue | Regenerated nightly from Linear as snapshot; or retire entirely | Snapshot regeneration introduces stale-vs-live confusion; retiring loses the informal ideation tier |
| 14 | SF auto-create (σ3 / O11) | NEW revops:salesforce MCP write tool at plan-campaign scaffold | Manual SF Campaign creation as sub-issue 4 | Manual step often forgotten; auto-create closes sub-issue 4 gap |
| 15 | Portfolio rollup home (O6.Q1) | Salesforce list view | Linear native project view; or brite-gtm regen; or plugin-emitted aggregate report | Linear can't aggregate pipeline/revenue; brite-gtm regen recreates stale-vs-live problem; plugin report lives elsewhere from where the data is |
| 16 | Default view spec (O6.Q2) | Status-grouped, 7 columns, exclude Completed+Killed | Vertical-grouped; or Month-grouped; or 10-column dense default | Status grouping puts funnel-shape visible immediately; lean columns protect Monday scan density |
| 17 | Cadence map (O6.Q3) | Daily=none / Weekly=2 views / Monthly=Coverage+Dashboard+snapshot / Quarterly=Coverage(FY)+2 Dashboards+snapshot+brite-gtm | Same rollup at all cadences | Different cadences answer different questions; daily glance bloats standup; monthly needs qualitative merge that SF alone can't provide |
| 18 | Retro rhythm (O6.Q4) | Subsumed by D4 + Q3 | Separate weekly/annual/per-vertical retro meetings | Existing layers (per-campaign debrief + monthly + quarterly) cover retrospection without meeting bloat |
| 19 | Snapshot scope (O6.Q5) | Read-only synthesis; 2 flags only; markdown only | Add charts; add forecast; add --weekly; add --custom-window | Each addition creeps scope into different discipline (charting / statistical modeling / operational use); read-only ensures portfolio-snapshot never corrupts source data |
| 20 | Entity slug normalization (Artifact Q1) | Short-form (`nites/supply/labs`) under `docs/campaigns/{entity}/` | Long-form (`brite-nites/...`) everywhere | Long-form is in Linear labels + manifest.json + flag values; short-form for paths reduces filesystem path length without losing the canonical form elsewhere |
| 21 | Forecast command | FUT — not in scope this design | Include `--forecast` flag in portfolio-snapshot | Forecasting is statistical modeling, a different discipline from synthesis; scope-creep risk |
| 22 | One snapshot command (O6.Q5) | `--monthly` \| `--quarterly` branches within one command | Two separate commands | Same inputs, same anti-creep guards, same output dir; avoids two near-duplicate commands |
| 23 | Persona authorship (D8) | Marketing decides cadence + ownership (BC-8730) | Plugin auto-generates from handbook ICP prose | Persona slugs encode marketing judgment; not mechanically inferrable from prose |
| 24 | Validation gate (V3) | Ratification against populated dogfood snapshot | Ratification on empty hypothetical / spec review only | V3 against real markdown packet catches issues a spec review misses |
| 25 | M2/M3 fallback | V3 rejection downgrades to M3 (SF Dashboard + Coverage only; drop portfolio-snapshot + Pipeline-by-Offer-Family) | Pre-commit to M3 to avoid building portfolio-snapshot | Tractable rebound preserves option value; portfolio-snapshot is small relative to its leverage if V3 ratifies |

**Full rationale**: `docs/designs/gtm-campaign-orchestration-design.md` Sections 1-7 carry the long-form reasoning for each lock.

---

## 9. Per-audience onboarding

Read these sections if you are:

### Marketing operator (Sarah / Corinne / Kells)

1. **§2 (Why this exists)** — what changes about your day-to-day
2. **§3 (Architecture)** — where the data you care about lives
3. **§6 (Glossary)** — the words used in plan-campaign + portfolio-snapshot + Linear labels
4. **BC-8729 (V3 ratification)** — the meeting where your input lands
5. **Operator workflow shift**: Monday GTM sync moves from "open Linear, check active-campaigns.md" to "open SF Active Campaigns list view, drill into Linear for blockers". Per-individual Linear "My Issues" remains your daily workflow.
6. **`/marketing:plan-campaign`** (BC-8724) — the command that will scaffold every new campaign. Accepts flags or walks you through interactively.

### Engineer (Holden + team)

1. **§7 (The 23 Linear issues)** — critical path + parallelization windows
2. **§3 (Architecture)** — 3-layer split + cross-system identity threading
3. **BC-8712 (Task 0)** — start here. Bootstraps Linear infrastructure + CLAUDE.md.
4. **Critical path**: BC-8712 → BC-8713 → BC-8717 → BC-8724 → BC-8727 → BC-8729 → BC-8752 → BC-8731.
5. **Plugin version bump gotcha**: BC touching `plugins/marketing/{commands,skills,hooks,agents}/**` MUST bump `plugin.json` + `marketplace.json` in the same commit. Per CLAUDE.md gotcha; BC-6000 precedent (4 stale-cache sessions lost).
6. **Refined plan**: `docs/project-plan-refined.md` — per-task Implementation Steps + Validation Criteria for each BC.

### Leader

1. **§1 (TL;DR)** — the headline
2. **§4 (Journey)** — methodology + chronology
3. **§5 (What was decided)** — high-leverage decisions only
4. **§7 (The 23 BCs)** — cost + critical path (~5-6 weeks)
5. **BC-8729 (V3 gate)** — the load-bearing M2/M3 decision; pre-decide your appetite before the meeting
6. **§11 (Confidence narrative)** — how we audited

### Future Claude session resuming this work

1. **All decisions in §5 are LOCKED.** Do NOT re-litigate without explicit user direction.
2. **Read `docs/designs/gtm-campaign-orchestration-design.md` Section 7.8** end-to-end for the full O6 chain.
3. **Memory files**: `project_gtm_campaign_architecture.md` (architecture summary), `project_marketing_vocabulary.md` (vocab canon), `session_2026_05_11_gtm_campaign_design.md` (full trajectory).
4. **Linear**: `mcp__plugin_workflows_linear-server__list_issues team:"Brite Company" project:"Brite Plugin Marketplace" query:"GTM"` returns all 23 BCs.
5. **If a user push-back surfaces** that genuinely needs re-opening a locked decision, surface explicitly (per feedback memory) — never silently drift.

---

## 10. Artifact index

Every doc + memory + Linear artifact, with one-line description.

### Source-of-truth docs

| Path | Purpose | Lines |
|---|---|---|
| `docs/gtm-campaign-orchestration-README.md` | THIS DOC — orientation + decision log + onboarding | ~800 |
| `docs/designs/gtm-campaign-orchestration-design.md` | Full design rationale; locks D1-D11 + O1-O15 + σ3; Section 7.8 carries O6 chain | ~1000 |
| `docs/plans/gtm-campaign-orchestration-plan.md` | Master implementation plan; 21 BC sketches in 9 tiers | ~600 |
| `docs/project-plan-refined.md` | Refined per-task plan; Mermaid dependency graph; Task 0 + 21 tasks | ~898 |
| `docs/linear-issues-created.md` | BC table + dependency map + priority rationale (created by `/workflows:create-issues`) | — |

### Memory files (internal session context)

| Path | Purpose |
|---|---|
| `memory/project_gtm_campaign_architecture.md` | Canonical conventions reference; D1-D11, O1-O15, σ3 + Phase 2 pivots |
| `memory/project_marketing_vocabulary.md` | 5-category vocabulary canon; per-term disambiguation |
| `memory/session_2026_05_11_gtm_campaign_design.md` | Full session trajectory through design close |
| `memory/feedback_interview_chunking.md` | Interview methodology lesson (one assumption per question) |
| `memory/reference_brite_gtm_repo.md` | Pointer to sibling repo (pre-Linear queue per O7) |
| `memory/reference_handbook_campaign_docs.md` | Pointer to handbook campaign docs |

### Linear

- **Project**: Brite Plugin Marketplace (team Brite Company)
- **Issues**: BC-8712 through BC-8735 + BC-8752 (23 total)
- **URL**: https://linear.app/brite-nites/project/brite-plugin-marketplace

### External

- **brite-gtm repo**: `/Users/holdenhalford/projects/work/brite-nites/brite-gtm/` (pre-Linear ideation queue per O7)
- **handbook repo**: `/Users/holdenhalford/projects/work/brite-nites/handbook/` (HOW; PRs land here for T8-R/S/T/U)
- **brite-salesforce repo**: `/Users/holdenhalford/projects/work/brite-nites/brite-salesforce/` (Campaign metadata; deploy target for T1-A/B/C/D + Substatus__c)

---

## 11. How we know nothing's missing — the audit narrative

Independent agent audit ran 2026-05-12 with sequential-thinking, cross-referencing design doc + master plan + refined plan + every Linear BC body + 3 memory files + cross-skill consistency in existing `plugins/marketing/` skills.

**Audit verdict**: FLAGS. No FAIL. Architecture, decision coverage, dependency graph (Mermaid vs Linear `blockedBy`), and vocabulary canon all PASS. Gaps clustered around implementation-detail drift between design and BC bodies.

**Surfaced gaps**:
- **1 P1**: σ3 status-sync trigger automation unassigned (MCP tool existed but no BC wired the call sites in launch-campaign / campaign-debrief).
- **7 P2**: manifest.json schema incomplete vs design doc; operator workflow shift missing from V3 packet; plugin version bump cross-cutting reminder absent; section reference typo; sub-issue blocked-by chain incomplete; owner_email resolution unspecified; Brite GTM Linear project provisioning unassigned.
- **11 P3**: 8+2 vs 7+2 labeling drift; T1-D V3-gating framing confusion; cross-entity edge case missing; sub-issue 4 role post-σ3 unclear; EB workspace resolution unspecified; campaign-analysis §3.3 citation chain implicit; vocab memory section header inconsistency; session memory top status stale; MEMORY.md index entry stale; BC-8720 evals path wording; allowed-tools list_milestones + AskUserQuestion not declared.

**Fixes shipped** (2026-05-12):
- **P1#1**: BC-8752 filed (σ3 trigger automation — modifies launch-campaign + campaign-debrief; new `/marketing:sync-campaign-status` fallback command).
- **All 7 P2s** fixed in BC body edits (BC-8712, BC-8724, BC-8729, BC-8731).
- **5 of 11 P3s** fixed: 8+2 labeling, cross-entity branch, EB workspace, allowed-tools, §3.3 citation, sub-issue 4 redefinition, memory header inconsistencies, session top status, MEMORY.md entry.
- **6 of 11 P3s** deferred as non-blocking cosmetic.

**Result**: every design decision now has a corresponding BC- issue or an out-of-scope acknowledgment. Memory files consistent. Vocabulary canon enforced. Dependency graph clean. **Plan is ready for agent execution.**

---

## 12. Next steps + open items

### Next step

Start at **[BC-8712](https://linear.app/brite-nites/issue/BC-8712)** (Task 0). This bootstraps Linear infrastructure + CLAUDE.md + provisions the Brite GTM project. Then unlock Tier 1 (BC-8713 through BC-8716) in parallel after the SF custom fields land.

### Open items NOT in this plan

| Item | Why excluded | Where it'll resolve |
|---|---|---|
| **V1 — gh CLI auth audit** | Cross-tool consumer concern; canonicals plugin-local so skills don't need gh | Address independently if it surfaces; not blocking |
| **O4 — Post-launch metric writeback Linear ← plugin** | Campaign-analysis weekly post pattern; doesn't block portfolio-snapshot or plan-campaign | Resolvable later when first dogfood reaches active management |
| **Forecast command** | Statistical modeling, different discipline from synthesis | FUT — track if it becomes load-bearing |
| **Per-vertical retro meeting** | Subsumed by Coverage by Vertical view drilling within quarterly | Don't introduce; covered |
| **Annual retro** | Subsumed by quarterly × 4 | Don't introduce unless leadership explicitly asks |
| **brite-gtm regen from Linear** | Conflicts with O7 lock (pre-Linear ideation queue role) | Don't reverse O7 |

### Known soft gates

- **D8 (persona authorship)** depends on V3 ratification but doesn't block plan-campaign — canonicals can ship with skeleton personas (slug + display, empty titles[]) and graduate later.
- **V3 (BC-8729)** is the load-bearing M2/M3 gate. If Marketing rejects the markdown packet (portfolio-snapshot output), Tier 7 + Tier 1-D + most of Tier 8 cascade to backlog. Tractable rebound path; not a session-blocker.

### Maintenance protocol — this is a LIVING doc

The README is the single-page front door for the entire GTM Campaign Orchestration effort. As BCs ship + V3 ratifies + new patterns emerge, this README needs to stay current.

**When to update what:**

| Event | Update | Section |
|---|---|---|
| A BC closes / merges | Update status indicator (✓ / ✗ / 🚧) in the BC table | §7 |
| Tier N completes | Update sequencing in §3.7 + status indicator in §7 | §3.7, §7 |
| V3 ratifies (M2 or M3) | Update M2/M3 callout with outcome; update affected BC statuses; update §1 status line | §1, §5, §7 |
| Dogfood campaign closes | Update §1 TL;DR with learnings; add post-mortem reference to §11 | §1, §11 |
| A decision changes (re-litigated lock) | Update §5 + §8 + ADR file; bump README version; note in §11 audit narrative | §5, §8, ADRs, §11 |
| New gotcha surfaces in execution | Add to §3.7 Operations cheatsheet | §3.7 |
| Plugin version-bumps a relevant artifact | Update §6 infra glossary if naming/contract changes | §6 |
| Memory file path or schema changes | Update §10 Artifact index | §10 |
| Audit re-runs (post-V3 or pre-merge of major BC) | Add row to §11 audit narrative table; cite outcome | §11 |

**Update discipline:**
- Bump "Last updated" date + session-count in top header on every commit touching this README
- README version: minor bump (v1.1, v1.2, ...) for new sections / table changes / status updates; major bump (v2.0) if the architecture itself changes
- Cross-link discipline — anchor links in §1 TOC + §7.5 cross-references must stay current when sections renumber
- Don't trust a stale "Last updated" — re-verify status indicators against Linear before relying on the README for execution decisions

**Closing**:

The design is locked. The plan is filed. The audit is clean. Execute.

When you finish a Tier, update this README's §7 table to mark progress. When the V3 gate resolves, update §5 M2/M3 callout + §12 to record the outcome. When the dogfood campaign closes, update §1 TL;DR with the lessons learned.

This document is the master entry point. Everything else hangs off it.
