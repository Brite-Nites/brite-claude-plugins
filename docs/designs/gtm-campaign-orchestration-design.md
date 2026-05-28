# GTM Campaign Orchestration Design

> **Start here for orientation**: `docs/gtm-campaign-orchestration-README.md` — master entry point with TL;DR, glossary, decision log, audit narrative, and per-audience onboarding paths. This design doc is the long-form rationale; the README is the navigation surface.

**Status**: CLOSED 2026-05-12 (design phase complete; 23 Linear issues filed; pre-implementation audit complete; ready for execution).
**Author**: Holden Halford + Claude (Opus 4.7)
**Companion memory**: `memory/project_gtm_campaign_architecture.md` (canonical conventions), `memory/session_2026_05_11_gtm_campaign_design.md` (session trajectory)

---

## 1. Problem statement

Before this design, three separate "campaign" systems ran in parallel with three different definitions of what a campaign IS:

1. **`brite-gtm/docs/campaign-portfolio.md`** — 44 enumerated Vertical × Offer × Quarter entries (planning unit). Edited inline 2026-05-11 with timestamped decision rows. References a "Brite GTM" Linear project with 44 planned milestones.
2. **`handbook/marketing/go-to-market/active-campaigns.md`** — empty tracking table (intended for BDR-maintained status). Naming convention `[Vertical] + [Offer] + [Quarter]`.
3. **Plugin's `docs/campaigns/{entity}/{slug}/`** — per-launch artifact bundles. After BC-6514 multiplicative segmentation, one effort can spawn N Email Bison campaigns.

None of these were integrated. Slugs, statuses, phase models (handbook's 7-step build vs brite-gtm's 8-phase outline vs plugin's 11-phase launch flow), and lifecycle stages were all inconsistent. There was no shared vocabulary, no single source-of-truth for live state, and no automated cross-system queries.

The design session resolves the seam and produces a canonical architecture.

---

## 2. Locked decisions

### D1 — Campaign unit of analysis

**Campaign = one Vertical × one Persona × one Offer × one Month.**

Calendar month numbering (M01 = January … M12 = December). FY prefix is calendar year (FY26 = 2026). Each persona-targeting is a first-class Linear milestone, not a wave under a coarser umbrella. 1:1 mapping Linear milestone ↔ Email Bison campaign ↔ debrief entry.

Volume implication: ~150-250 milestones/year realistic across active verticals/personas/offers.

> The "Wave" concept that briefly existed in earlier turns (when D1 was Vertical × Offer × Quarter) dissolved when persona moved into the slug. Each launch is now a single first-class campaign with one EB campaign and one debrief.

### D2 — 3-layer role split

```
HANDBOOK     →  reference / standards / conventions / templates
                (mutated via PR; SOP for what a campaign IS)

LINEAR       →  orchestration / state / work-to-do
                ("Brite GTM" project; milestones per campaign; sub-issues per work item)

PLUGIN       →  execution / artifacts / external-system I/O
                (commands per sub-issue; emitted files; EB/SF/Spider/MV calls)
```

Each system has one job. No overlap. The handbook never holds live instance state; Linear never stores execution artifacts; the plugin never owns definitions.

### D3 — Sub-issues represent stand-up work, not waves

Linear sub-issues under a Campaign milestone capture the WORK needed to stand up + close that campaign. Plugin per-launch artifacts (date-suffixed JSONs under `docs/campaigns/{entity}/`) are NOT first-class Linear records — they live on disk and are referenced in sub-issue comments.

### D4 — Standard sub-issue template (7 standard + 2 optional)

Faithful to handbook `campaign-planning.md` (the 7-step build) + `campaign-lifecycle.md` Workflow B (the brief-approval gate):

| # | Sub-issue | Handbook source | Plugin command (today) | Owner | When |
|---|---|---|---|---|---|
| 1 | Brief approved (gate) | campaign-lifecycle.md Workflow B + campaign-brief-template.md | None — manual review today | GTM proposes; Marketing reviews | T-21d |
| 2 | Target list built | campaign-planning.md Step 1 | `/marketing:tam-map` + `icp-scoring abc` (Labs) OR `list-building` (Nites/Supply) | Corinne | T-21d → T-14d |
| 3 | Copy written + approved | campaign-planning.md Step 2 | `email-copywriting` + optional `creative-angles` / `situation-mining` upstream | Sarah Cullen writes; Corinne loads | T-14d → T-7d |
| 4 | Salesforce setup | campaign-planning.md Step 3 | None yet (manual today; candidate for `/marketing:setup-sf-campaign`) | Corinne | T-7d |
| 5 | Pre-launch QA | campaign-planning.md Step 4 | Partial — `launch-campaign` Phase 1-3 validates copy/CSV; deliverability is manual | Corinne | T-3d |
| 6 | Launch executed | campaign-planning.md Step 5 | `/marketing:launch-campaign` (single EB campaign — no waves) | Corinne | T+0 |
| 7 | Active management — weekly reviews | campaign-planning.md Step 6 | `campaign-analysis` (run weekly) | Corinne + Kells | T+7, T+14, … |
| 8 | Campaign closed + debrief | campaign-planning.md Step 7 + campaign-lifecycle.md Workflow C | `campaign-debrief` + handbook PR for transferable insights | GTM | T+close |

Optional: **Situation mining** (Labs / high-value); **Creative angles** (new offer / iterating copy).

### D5 — Brief lives in Linear milestone description

The filled-in campaign brief lives as the Linear milestone description, populated from handbook's `campaign-brief-template.md` (8 sections: Overview, Goals, Audience, Messaging, Channels, Assets, Budget, Success Metrics). Handbook owns the blank template; Linear owns the per-campaign instance. Brite-gtm holds the pre-Linear planning view (its long-term role is O7, still open).

### D6 — Handbook role refactor — navigation, not source-of-truth

Handbook pages that try to be live indexes (`active-campaigns.md`, etc.) become navigation docs: "here is how to find active campaigns in Linear, here is the view link, here is what statuses mean." The handbook STILL owns: definitions, SOPs, blank templates, conventions, vertical playbooks, offer pages, copy standards, metrics definitions. The handbook does NOT own: per-campaign instance state.

---

## 3. Canonical conventions

### Status labels (Linear milestone-level)

**Primary states** (mutually exclusive): `status:planning`, `status:active`, `status:completed`, `status:killed`
**Overlay** (stackable): `status:paused`

Linear milestones have no native state field — encoded as labels. Sub-issues use Linear's default states (Backlog / Todo / In Progress / In Review / Done / Canceled).

```
   [milestone created]
          │
          ▼
   ┌──────────────┐
   │   Planning   │ <─── 7 standard sub-issues open; brief, list, copy,
   └──────┬───────┘      SF, QA work in flight
          │
          │ (sub-issue 6 "Launch executed" closes)
          ▼
   ┌──────────────┐         ┌──────────┐
   │    Active    │ <──────>│  Paused  │  (transient overlay; returns
   └──────┬───────┘         └──────────┘   to Active when sends resume)
          │
          │ (sub-issue 8 "Campaign closed + debrief" closes)
          ▼
   ┌──────────────┐
   │  Completed   │
   └──────────────┘

   * Killed: any state → Killed (manual; campaign abandoned)
```

### Slug rule (universal identifier)

```
{vertical-slug}-{persona-slug}-{offer-slug}-fy{YY}-m{MM}
```

| Component | Source |
|---|---|
| `vertical-slug` | Handbook directory name under `marketing/go-to-market/verticals/` |
| `persona-slug` | Kebab-case of a documented persona name within the vertical's ICP definitions |
| `offer-slug` | Filename under `verticals/{vertical}/offers/{file}.md` (minus `.md`) |
| `fy{YY}` | Calendar year prefix (FY26 = 2026) |
| `m{MM}` | Calendar month, zero-padded (M01 = January, M12 = December) |

Validates as `^[a-z0-9-]{1,80}$` per plugin BC-5826 IV-8.

**Worked examples**:
- `zoos-facility-directors-zoo-lights-rev-share-fy26-m04`
- `municipalities-parks-directors-permanent-lighting-fy26-m03`
- `hoas-community-managers-preferred-vendor-partnership-fy26-m07`

**Entity is NOT in the slug** — captured as a Linear label (`entity:brite-labs`) and a plugin path prefix (`docs/campaigns/brite-labs/`).

**Handbook-PR gate**: new verticals require handbook `campaign-lifecycle.md` Workflow A; new offers require Workflow B; new personas require an update to the vertical's README. Plugin's `/marketing:plan-campaign` refuses to scaffold when any slug component fails handbook canonicality validation.

**Edge cases**:
- **Multi-vertical campaigns** (e.g., America 250 cross-entity) → use `cross-entity-{theme}-fy{YY}-m{MM}` exception; document in handbook navigation doc; rare (~3-5 of brite-gtm's 44 entries).
- **Collision** (same vertical × persona × offer × month) → append `-v2`, `-v3`; operator-explicit, not auto-incremented.
- **Offer doesn't exist in handbook** → hard fail with pointer to Workflow B.

### Cross-system identity threading

The slug is the **universal search anchor** — appears verbatim in all four systems:

| System | Identifier | Value |
|---|---|---|
| Plugin artifact dir | path | `docs/campaigns/{entity}/{slug}/` |
| Linear milestone | name + label | name: human-readable; label `slug:{slug}` for grep |
| Email Bison campaign | Name field | `{slug}` verbatim |
| Salesforce Campaign | Name field | `{slug}` verbatim |

**Manifest.json** at `docs/campaigns/{entity}/{slug}/manifest.json` is the machine-readable canonical cross-reference:

```json
{
  "slug": "zoos-facility-directors-zoo-lights-rev-share-fy26-m04",
  "entity": "brite-labs",
  "vertical": "zoos",
  "persona": "facility-directors",
  "offer": "zoo-lights-rev-share",
  "year": 2026,
  "month": 4,
  "linear": {
    "milestone_id": "abc-123-def",
    "milestone_url": "https://linear.app/brite-nites/...",
    "project": "Brite GTM"
  },
  "salesforce": {
    "campaign_id": "701...",          // populated when sub-issue 4 closes
    "campaign_name": "{slug}"
  },
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_id": 12345,              // populated when sub-issue 6 closes
    "campaign_name": "{slug}",
    "launched_at": "2026-04-15T14:00:00Z"
  },
  "created_at": "2026-03-15T10:00:00Z",
  "scaffolded_by": "/marketing:plan-campaign"
}
```

Linear sub-issue comments are the human-readable mirror — each comment captures the external ID as it lands (sub-issue 4 → SF Campaign URL; sub-issue 6 → EB campaign URL + lead count). When Linear and manifest.json diverge, **manifest.json wins** for machine operations. Renaming a Linear milestone does NOT propagate to the slug — the slug is immutable for the campaign's life.

### Linear project structure

A separate Linear project, "Brite GTM" (`brite-gtm-fa8fc238ef28` per brite-gtm repo references), holds the campaign portfolio. This is distinct from the existing "Brite Skill Packs" project (which holds plugin engineering work).

Labels applied per milestone at scaffold time:
- `slug:{slug}` (universal anchor for search)
- `entity:{brite-nites|brite-supply|brite-labs}` (or `cross-entity` for multi)
- `vertical:{vertical}`
- `persona:{persona}`
- `offer:{offer}`
- `year:{YYYY}`
- `month:{MM}`
- `status:planning` (initial)

### Scaffolding command — `/marketing:plan-campaign`

10-step walkthrough framework:

| Step | Status |
|---|---|
| 1. Operator invocation | LOCKED |
| 2. Handbook canonicality validation | IN PROGRESS |
| 3. Collision check | not yet |
| 4. Dry-run preview | not yet |
| 5. Two-call confirm | not yet |
| 6. Plugin dir + manifest.json creation | not yet |
| 7. Linear milestone creation + labels + brief template | not yet |
| 8. Standard sub-issue creation | not yet |
| 9. Optional sub-issues | not yet |
| 10. Summary output | not yet |

#### Step 1 — Operator invocation (LOCKED)

**Hybrid flag-or-prompt mode**: every input is either a CLI flag (power-user path) or a sequential `AskUserQuestion` prompt (guided path).

**Required (flag-or-prompt)**:
- `--vertical` — validated against `handbook/marketing/go-to-market/verticals/{vertical}/README.md`
- `--persona` — validated against the vertical's documented ICP personas
- `--offer` — validated against `verticals/{vertical}/offers/{offer}.md`

**Auto-detect (flag-overridable)**:
- `--month` — defaults to current calendar month; prompt offers "this month / next / pick" if guided
- `--year` — silent default to current calendar year
- `--entity` — auto-inferred for single-entity verticals (zoos → brite-labs); explicit `--entity` required for dual-entity (Municipalities, HOAs, Hospitals) or silently fails to prompt in guided mode

**Optional flags**:
- `--launch-date YYYY-MM-DD` — sets sub-issue 6 due-date; back-fills 1-5 working backwards (~T-21d brief, T-14d list, T-10d copy, T-7d SF, T-3d QA)
- `--situation-mining` — adds optional sub-issue 9 (Labs only — auto-skipped for Nites/Supply)
- `--creative-angles` — adds optional sub-issue 10
- `--dry-run` — flag-only; print plan, create nothing

**Two-call gate** per BC-2707 precedent: first call shows dry-run preview; operator confirms in a second call to execute.

**Persona is single-valued** — running 3 personas = running the command 3 times. Each persona = own milestone per D1.

#### Step 2 — Handbook canonicality validation (IN PROGRESS)

User wants this step broken into smaller sub-chunks per `feedback_interview_chunking.md`. Sub-chunks to walk:

1. **Validation behavior on flag-mode mismatch** (hard-fail with pointer to handbook workflow; what does the error message look like; should it suggest closest-match for typos?)
2. **Validation behavior in prompt-mode "Other..." selection** (back-to-picker vs cancel-with-PR-instructions?)
3. **Handbook path resolution** (sibling `../handbook/` default; `$BRITE_HANDBOOK_PATH` env override; remote `gh api` opt-in via `--remote-handbook` flag, no silent fallback)
4. **Validation also extracts content for later steps** (ICP criteria + persona definitions go into brief template; offer page content goes into copy sub-issue description)
5. **Pointer-and-exit vs bootstrap-the-PR** (recommendation: pointer-and-exit; keep plan-campaign read-only against handbook; handbook PR bootstrapping is a separate `/marketing:new-vertical` / `/marketing:new-offer` skill if worth automating)

Each sub-chunk = one question turn with my recommended answer.

#### Steps 3-10 (not yet walked)

- **3. Collision check** — what if milestone with this slug exists; what if artifact dir exists; should collision be auto-resolved (e.g., `-v2` suffix) or hard-fail; how does this interact with the two-call gate?
- **4. Dry-run preview** — exact format of the dry-run output; what gets printed; what's elided; how operator can spot errors before confirming
- **5. Two-call confirm** — confirmation prompt UX; should it require typing CONFIRM or just yes/no; what happens on partial failure (atomic rollback or best-effort)
- **6. Plugin dir + manifest.json creation** — directory permissions; initial manifest fields; what's populated immediately vs left null
- **7. Linear milestone creation** — title format (human-readable vs slug); description content (brief template + Plugin artifacts pointer); label application order
- **8. Standard sub-issue creation** — per sub-issue: description template, owner assignment, due-date back-fill, blocked-by relationships (sub-issues 2-8 blocked by sub-issue 1 closing); link to plugin command in description
- **9. Optional sub-issues** — when each is offered (Labs gate on situation-mining); how operator confirms in prompt mode
- **10. Summary output** — what's printed (milestone URL, slug, manifest path, sub-issue count + IDs); optional browser open

### Cross-campaign rollup (O6 — Q1 LOCKED; Q2-Q5 open)

Q1 (portfolio rollup home) LOCKED → **Salesforce list view as primary live rollup**; Linear for per-campaign drill-down. See Section 7.8 for full lock rationale + σ3 scope expansion (status sync via `update_sf_campaign_status`).

Remaining open sub-questions:
- Q2: Default SF list view shape — grouping (status / vertical / month / owner?), columns, filters
- Q3: Cadence map — daily / weekly GTM sync / monthly review / quarterly planning each resolve to which SF view URL + plugin command (if any)
- Q4: Retrospective rhythm — campaign-debrief timing, cycle retros, quarterly synthesis
- Q5: Periodic snapshot exports — whether to ship `/marketing:portfolio-snapshot` for monthly/quarterly frozen packets

### brite-gtm repo future role (O7 — open)

Today brite-gtm's `campaign-portfolio.md` is the closest thing to a portfolio source-of-truth. With Linear becoming canonical for live state per D2:
- (a) **Hand-maintained pre-Linear planning queue** — campaigns live here as 🟢🟡⚪ entries; graduate to Linear milestones when actually pursued; the repo never sees live state. Current lean.
- (b) **Regenerated from Linear nightly** as a snapshot.
- (c) **Retired entirely**; portfolio view lives only in Linear.

### Migration path / first dogfood (O9 — open)

How do we get from current state (zero campaigns in Linear under this template; brite-gtm portfolio as planning artifact; handbook active-campaigns.md empty) to running campaigns in the new shape?
- Pick one campaign from brite-gtm portfolio (likely a Brite Labs one given the plugin's Labs maturity)
- Manually scaffold it as the dogfood for `/marketing:plan-campaign`
- Iterate template based on friction
- Bulk-instantiate the rest

### Plugin skill gaps (O10 — open)

The 7-sub-issue template surfaces gaps:
- Sub-issue 4 (SF setup) has no plugin command — candidate `/marketing:setup-sf-campaign`
- Post-reply skills BC-2720 (`reply-processing`), BC-2725 (`lead-routing`) — already in backlog; both relevant to "what happens after launch"
- BC-2722 (`outbound-playbook`) umbrella skill — pending
- Decide priority given dogfood plan from O9

---

## 4. Communication preferences (for future sessions)

- **One question at a time.** Per `feedback_one_question_at_a_time.md` + `feedback_interview_chunking.md`. Do NOT bundle 2-3 sub-questions in a single turn.
- **Recommend an answer.** Each question turn includes my recommended answer + brief rationale. User can confirm, refine, or reject.
- **Walk dependency tree.** Foundational decisions first (unit of analysis → status vocab → slug rule → manifest shape → command UX → sub-issue template details).
- **ASCII diagrams welcome.** Multi-layer architecture, state machines, navigation tables — diagrams help. Multi-sub-question text blocks hurt.
- **Auto mode active.** User happy to be progressed autonomously between substantive decisions; only pause when an actual choice needs their input.
- **No emojis** per `feedback_no_emojis_in_generated_content.md`.

---

## 5. Appendix A — Task list reconstruction

Re-create the design-tree task list in the new session by issuing these 16 `TaskCreate` calls (in any order), then `TaskUpdate` 9 of them to `completed` and 1 to `in_progress`. The numeric IDs assigned by the runtime will differ from this session's; that's fine — the content + status are what matter.

### TaskCreate calls (verbatim — subject + description + activeForm):

1. **D1: Define unit of analysis for "campaign"** — `DECIDED. Campaign = Vertical × Persona × Offer × Month (calendar month; M01=Jan, M12=Dec; FY prefix = calendar year). Each persona-targeting is a first-class Linear milestone — the Wave concept dissolves. 1:1 mapping Linear milestone ↔ EB campaign ↔ debrief entry. ~150-250 milestones/year realistic.` (activeForm: Defining campaign unit)

2. **D2: 3-layer role split (Handbook / Linear / Plugin)** — `DECIDED. Handbook = reference + standards + conventions. Linear = orchestration + state + work-to-do ("Brite GTM" project). Plugin = execution + artifacts + external-system I/O. Each system has one job; no overlap.` (activeForm: Defining 3-layer split)

3. **D3: Sub-issues represent stand-up work, not waves** — `DECIDED. Linear sub-issues capture the WORK to stand up + close a campaign. Plugin per-launch artifacts (date-suffixed JSONs) live on disk; referenced in sub-issue comments.` (activeForm: Confirming sub-issue scope)

4. **D4: Standard sub-issue template (7 standard + 2 optional)** — `DECIDED. Standard: (1) Brief approved, (2) Target list, (3) Copy written, (4) SF setup, (5) Pre-launch QA, (6) Launch executed (single EB campaign per D1), (7) Active mgmt weekly reviews, (8) Campaign closed + debrief. Optional: Situation mining (Labs); Creative angles (new offer / copy iteration). Faithful to handbook campaign-planning.md.` (activeForm: Locking sub-issue template)

5. **D5: Brief lives in Linear milestone description** — `DECIDED. Filled brief = Linear milestone description, populated from handbook's campaign-brief-template.md 8 sections. Handbook owns blank template; Linear owns per-campaign instance.` (activeForm: Locking brief location)

6. **D6: Handbook role refactor — navigation, not source-of-truth** — `DECIDED. Handbook pages that try to be live indexes (active-campaigns.md, etc.) become navigation docs pointing at Linear views. Handbook still owns definitions, SOPs, templates, conventions, playbooks. Concrete handbook PR list is O8.` (activeForm: Locking handbook role)

7. **O1: Milestone + sub-issue status vocabulary** — `DECIDED. 4 primary milestone labels (status:planning / active / completed / killed) + status:paused as stackable overlay (not primary state). Encoded as Linear labels (milestones have no native state). Sub-issues use Linear default states. Transitions: sub-issue 6 close → planning→active; sub-issue 8 close → active→completed.` (activeForm: Defining status vocabulary)  → Mark `completed`.

8. **O2: Slug derivation + cross-system identity threading** — `DECIDED. (a) Slug = {vertical-slug}-{persona-slug}-{offer-slug}-fy{YY}-m{MM} — derived from handbook canonicals; ^[a-z0-9-]{1,80}$. Entity not in slug (label + path prefix). New verticals/personas/offers require handbook PR first. (b) Slug is universal anchor (plugin path / EB Name / SF Name / Linear slug: label). manifest.json at docs/campaigns/{entity}/{slug}/manifest.json is canonical machine-readable store. Linear comments are human-readable mirror. Manifest wins on divergence. Renaming Linear milestone doesn't propagate.` (activeForm: Defining slug + ID threading)  → Mark `completed`.

9. **O3: Scaffolding command — /marketing:plan-campaign** — `IN PROGRESS. Name locked: /marketing:plan-campaign. 10-step walkthrough: (1) operator invocation [LOCKED — hybrid flag-or-prompt; required vertical/persona/offer prompt-or-flag; auto-detect entity for single-entity + year; --dry-run flag-only], (2) handbook canonicality validation [IN PROGRESS — break into smaller chunks per feedback_interview_chunking.md], (3) collision check, (4) dry-run preview, (5) two-call confirm, (6) plugin dir + manifest.json creation, (7) Linear milestone + labels + brief template, (8) standard sub-issue creation, (9) optional sub-issues, (10) summary output.` (activeForm: Designing scaffolding command)  → Mark `in_progress`.

10. **O4: Post-launch metric writeback Linear ← plugin** — `OPEN. After /marketing:launch-campaign runs and EB sends produce data, how do campaign-analysis emissions flow back into Linear? Options: (a) campaign-analysis posts Linear comment on Active Mgmt sub-issue per weekly run, (b) campaign-analysis writes structured field in milestone description, (c) plugin emits static report; separate cadence command posts summary to Linear. Dependencies: O1, O2.` (activeForm: Defining metric writeback)

11. **O5: Multi-wave handling refinement** — `MOSTLY DISSOLVED by D1 revision (waves no longer exist as a concept — each persona is its own milestone). Narrow remaining question: when iterated copy is "same milestone re-launch" vs "new milestone with -v2 slug suffix." Convention: new month = new milestone. Same month + different copy = -v2 suffix.` (activeForm: Refining multi-wave handling)

12. **O6: Cross-campaign rollup view + retrospective rhythm** — `OPEN. How does "all active campaigns at once" view work (replaces handbook active-campaigns.md table)? Options: Linear project view filtered by status:active, custom Linear view, brite-gtm regenerated from Linear nightly, plugin-emitted aggregate report. Also: how does weekly GTM sync / monthly review / quarterly planning each map to a Linear view + cadence command? Dependencies: O1, O2.` (activeForm: Designing rollup + rhythm)

13. **O7: brite-gtm repo future role** — `OPEN. Linear becomes source-of-truth for live state; what does brite-gtm do? (a) hand-maintained pre-Linear planning queue (current lean), (b) regenerated from Linear nightly as snapshot, (c) retire. brite-gtm's other docs (outline.md, stakeholders.md, sales-context.md) keep their roles regardless.` (activeForm: Resolving brite-gtm role)

14. **O8: Handbook navigation refactor — which docs change** — `OPEN. Concrete handbook PR list: active-campaigns.md becomes "How to find active campaigns" (points at Linear view URL). campaign-lifecycle.md adds explicit "your brief lives in Linear milestone description" line. campaign-planning.md adds 7-sub-issue template as canonical work breakdown. how-we-operate.md cadence rows reference Linear views. Any other docs that name campaign tracking need their references updated.` (activeForm: Listing handbook refactor PRs)

15. **O9: Migration path — first dogfood campaign** — `OPEN. How to go from current state to running campaigns in the new shape: pick one campaign from brite-gtm portfolio (likely a Brite Labs one), instantiate manually as the dogfood for /marketing:plan-campaign, iterate template based on friction, then bulk-instantiate the rest. Dependencies: O1, O2, O3, O8.` (activeForm: Planning migration + dogfood)

16. **O10: Plugin skill gaps — what to build** — `OPEN. Inventory plugin gaps surfaced by 7-sub-issue template: (a) sub-issue 4 "SF setup" has no plugin command (candidate /marketing:setup-sf-campaign), (b) BC-2720 reply-processing + BC-2725 lead-routing in backlog and directly relevant, (c) BC-2722 outbound-playbook still pending. Decide priority given dogfood plan from O9.` (activeForm: Inventorying plugin skill gaps)

### After creation, mark these completed (decided):

Tasks D1 / D2 / D3 / D4 / D5 / D6 / O1 / O2 → status `completed`

### Mark this in_progress:

Task O3 → status `in_progress` (mid-Step-2 of the 10-step walkthrough)

### Leave pending:

O4, O5, O6, O7, O8, O9, O10

---

## 6. Appendix B — Handoff prompt (DEPRECATED — superseded by Section 8 Phase 2 handoff)

The original handoff prompt below was for resuming Phase 1 mid-Step-2. A continuation session has happened since (Phase 2) and the architecture has been reshaped substantially. Use Section 8 Phase 2 handoff for any new-session resume.

---

## 7. Phase 2 architectural pivot (2026-05-11 continuation)

Same calendar day as Phase 1, new conversation. The work in Section 1-5 above (D1-D6, O1, O2, O3 step 1, O3 step 2 sub-chunks 1-3) is still LOCKED, but the architecture has been substantially reshaped since.

### 7.1 Architectural pivot — Handbook = HOW, Plugin = WHAT

**Handbook owns PROCESS** (frameworks, templates, standards, playbooks, process docs). Specifically:
- `marketing/frameworks/{mspa-flywheel, kellens-laws, asymmetry-rubric, offer-postures, value-equation, recency-waterfall, verdicts-cross-reference, vocabulary}.md`
- `marketing/templates/{campaign-brief-template, icp-persona-template, messaging-template, ...}.md`
- `marketing/standards/{cold-outbound-copy-standards, metrics-definitions}.md`
- `marketing/playbooks/verticals/{vertical}/README.md` (narrative reference for Sales/CS/PMM)
- `marketing/go-to-market/{campaign-lifecycle, campaign-planning, how-we-operate}.md`

**Plugin owns ENTITIES + STATE** (operational data):
- `plugins/marketing/data/canonicals/_manifest.yaml + {vertical}.yaml` (slug taxonomy — NEW location, plugin-side)
- `docs/campaigns/{entity}/mmf-matrix.md, mmf-batch-{N}.md, mmf-results-{N}.md, mmf-diagnosis-*.md` (MSPA artifacts)
- `docs/campaigns/{entity}/learnings.md` (verdict registry; entity slug short-form per Artifact Q1)
- `docs/campaigns/{entity}/analysis-*.md, copy-*.json` (per-campaign artifacts)
- `docs/campaigns/{entity}/{slug}/manifest.json, discoveries.json` (per-campaign identity + signals)
- `docs/campaigns/{entity}/offers/{slug}/{version}/performance.md` (per-version aggregation, per O13)

### 7.2 canonicals.yaml lives PLUGIN-side (not handbook)

**Path**: `plugins/marketing/data/canonicals/`. Operator-driven cadence (plugin PR not handbook PR for routine additions). Cross-tool consumers (brite-data-platform, brite-salesforce) read from britenites-claude-plugins repo.

**Final thin schema** (after D7 re-walk):

```yaml
# _manifest.yaml
schema_version: 1
last_updated: 2026-05-11
verticals: [alphabetized list of all 27]

# {vertical}.yaml
slug: zoos
display: "Zoos"
personas:                                # FLAT, no ICP nesting (per ID Q2)
  - slug: events-director
    display: "Director of Events / Programming"
    titles: ["Director of Events", "VP Events", ...]   # required ≥1
offers:
  - slug: zoolights-experience
    display: "ZooLights-Style Experience"
    status: active                       # draft|active|retired
    target_personas: [events-director, ceo]  # optional
    replaced_by: <slug>                  # optional (forward pointer, retired offer)
    iterates_from: <slug>                # rare (family-level evolution, backward)
    prose_path: ...                      # optional override
aliases: [old-slug]                      # optional, for vertical renames
playbook_path: ...                       # optional override
```

**Dropped from canonicals** (vs original D7 walks): vertical `status` (handbook taxonomy table owns), `business_units` (handbook taxonomy owns), `service_types` (YAGNI), `icps[]` nesting (per ID Q2 — ICP=template, Segment=instance), `consolidates`/`consolidated_into` (aquariums got own vertical per Q-D7.10).

### 7.3 Vocabulary canon (5 categories LOCKED)

Full disambiguation at `memory/project_marketing_vocabulary.md`. Key locks:

**Identity (Q1-Q5)**:
- Q1: **Vertical** (handbook canon identity) + **Market** (MSPA matrix hypothesis context) — BOTH KEPT
- Q2: **ICP = template** (handbook prose + tam-mapping JSON criteria); **Segment = instance** (MSPA matrix per-experiment); canonicals personas FLAT per vertical
- Q3: **4-layer offer model** — Offer Family > Offer Posture > Angle > Specific Offer Instance
- Q4: Persona schema = `slug` + `display` + `titles[]` (≥1 required)
- Q5: **Offer Tier → Offer Posture** (rename); values `knowledge / free-asset / pilot / risk-reversal` (was T1-T4 letter codes — collided with list-building title cascade)

**State (Q1)**:
- 3 verdict vocabularies kept distinct, parent labels renamed per skill — **Angle Verdict** (creative-angles, pre-experiment), **Experiment Verdict** (mmf, post-batch), **Campaign Verdict** (debrief, post-campaign). Cross-skill translation in handbook framework doc per O14.

**Artifact (Q1)**:
- Entity slug normalize to **short-form** under `docs/campaigns/{entity}/`. campaign-debrief migrates from `brite-{entity}/` to `{entity}/`. Long-form stays in Linear labels + manifest.json `entity` field + --entity flag values + plugin ENTITY_MAP.

**Process/Framework + Metric**: no decisions; canonical sources locked.

### 7.4 discoveries.json category-tagged signal pattern

Skills EMIT signals; humans PROMOTE via handbook PR. Skills NEVER directly mutate canonicals or handbook.

```json
{
  "campaign_slug": "...",
  "discoveries": [
    { "category": "title-discovery", "persona_slug": "...", "candidate_titles": [...] },
    { "category": "icp-refinement", "icp_slug": "...", "signal": "...", "proposed_action": "...", "evidence_strength": "high|medium|low" },
    { "category": "offer-retirement", "offer_slug": "...", "signal": "...", "proposed_replacement": "..." },
    { "category": "persona-discovery", "vertical_slug": "...", "signal": "...", "proposed_action": "..." }
  ]
}
```

**ICP refinement hybrid cadence**: per-batch tactical refinements (firmographic threshold tweaks, new candidate persona); per-quarter strategic redefinitions (splitting ICP into two, redefining worldview).

### 7.5 σ3 from O11 (Salesforce vs Linear)

**KEEP D2** — Linear=orchestration, SF Campaign=attribution, Plugin=execution. Auto-create SF Campaign via NEW revops:salesforce MCP write tool during /marketing:plan-campaign scaffold (Step 7b). Closes O10's sub-issue 4 gap. No D2 re-opening.

Grounded findings: brite-salesforce has Campaign object with custom fields (`Vertical__c`, `Outbase_Campaign_ID__c`, `External_Campaign_URL__c`) — already used for attribution. revops:salesforce MCP today is read-heavy + metadata-deploy; needs new write tool for Campaign create (Apex anonymous wrapper OR new typed tool). Soft-fail path if MCP write unavailable.

**σ3 scope expanded by Section 7.8** (O6.Q1 LOCKED): revops MCP write tool exposes BOTH `create_sf_campaign` AND `update_sf_campaign_status`. Status-sync triggers are detailed in 7.8.

### 7.6 Per-offer-version metric aggregation (O13)

Per-version performance at `docs/campaigns/{entity}/offers/{slug}/{version}/performance.md`. New `/marketing:offer-performance` command mechanically aggregates EB + SF metrics from manifest.json glob. Feeds back into mmf ITERATE Step 3.6 (new) — quantitative companion to learnings.md's qualitative patterns.

Offer versioning: NOT in canonicals. Versions are CAMPAIGN-LEVEL attributes (slug fragment + Linear label `offer-version:{v}` + manifest.json `offer_version` field). Major family evolutions (rare) get new canonicals entry with `iterates_from` pointer.

### 7.7 Other Phase 2 locks

- **D9** (schema versioning): single-repo plugin-owned; major bump migrates files in same PR; deprecated fields soft-warn one release cycle. No cross-repo coordination.
- **D10** (--handbook-ref flag): DROPPED. Canonicals plugin-side; no remote fetch needed.
- **D11** (backfill scope): All 27 verticals backfilled day-1 (light schema).
- **O5** (multi-wave): same-month + new copy = `-v2` slug suffix (operator-explicit).
- **O7** (brite-gtm role): pre-Linear planning queue (campaign-portfolio.md is informal ideation tier 🟢🟡⚪; promotes to Linear when committed).
- **O11** (SF vs Linear): σ3 (see 7.5).

### 7.8 Portfolio rollup home — Salesforce primary (O6.Q1 LOCKED; σ3 scope expansion)

The cross-campaign rollup view — the single-page answer to "what's the state of the entire campaign portfolio right now?" — lives in **Salesforce**, not Linear. Linear remains the home for per-campaign drill-down (sub-issue work, brief, comments, audit trail). This split sharpens D2 without re-opening it: D2's *reporting* half resolves to Salesforce; the *orchestration* half stays Linear.

**Question routing**:

| Question class | Home | Concrete example |
|---|---|---|
| Portfolio inventory | SF list view | "How many active campaigns by vertical?" |
| Launch calendar | SF list view sorted by StartDate | "What launches in the next 7 days?" |
| Owner load-balancing | SF list view grouped by Owner | "Who has 5 campaigns running?" |
| Pipeline / revenue / meetings | SF report or dashboard | "Pipeline value per offer family?" |
| Coverage gap analysis | SF report grouped by Vertical__c | "0 HOA campaigns last quarter, why?" |
| Sub-issue progress | Linear milestone | "Is copy approved for X?" |
| Brief content | Linear milestone description | "What's the messaging plan?" |
| Active-mgmt weekly notes | Linear sub-issue 7 comments | "What did Corinne note this week?" |
| Audit trail | Linear comments | "Who approved the brief?" |

**Why Salesforce (not Linear) for portfolio rollup**:

1. **σ3 already commits to writing campaign data into SF.** Every campaign auto-creates a SF Campaign at scaffold per σ3. Using SF for rollup leverages infrastructure already committed; routing rollup elsewhere creates a parallel representation.
2. **SF is purpose-built for cross-record reporting.** List views, reports, dashboards, formula fields, scheduled snapshots — Linear's view editor cannot express pipeline-value-by-vertical aggregations, conversion-funnel charts, or hierarchical rollups.
3. **SF has bottom-funnel data Linear never will** — pipeline value, closed-won revenue, meetings booked, conversion rates. Portfolio-level *performance* questions are mechanically impossible without SF.
4. **SF Campaign Hierarchies** enable natural grouping (offer family → individual campaigns within a vertical) for portfolio shape views.
5. **Audience split is clean.** Leadership audience (Kells + revenue stakeholders) already lives in SF for revenue + pipeline. Marketing operators (Sarah, Corinne) drill into Linear for work-in-flight. The questions split along the same line as the people asking them.

**σ3 scope expansion**:

σ3 (LOCKED in 7.5) committed the revops:salesforce MCP to gain a `create_sf_campaign` write tool. O6.Q1 lock expands σ3 scope: the same MCP also exposes `update_sf_campaign_status`. Triggers:

- Sub-issue 6 ("Launch executed") closes → set SF Campaign Status to mirror Linear `status:active`
- Sub-issue 8 ("Campaign closed + debrief") closes → set SF Campaign Status to mirror Linear `status:completed`
- `status:paused` label added/removed on Linear milestone → reflect on SF Campaign (`Substatus__c` custom field; main `Status` stays `In Progress`)
- `status:killed` manual transition → SF Campaign Status set to `Aborted` (or equivalent picklist)

**Linear status → SF Campaign Status mapping** (provisional; finalize during BC implementation):

| Linear label | SF Campaign Status | SF Substatus__c |
|---|---|---|
| `status:planning` | Planned | — |
| `status:active` | In Progress | — |
| `status:active` + `status:paused` | In Progress | Paused |
| `status:completed` | Completed | — |
| `status:killed` | Aborted | — |

The `Substatus__c` custom field is **NEW** to brite-salesforce and lives in O10's plugin-skill-gap enumeration alongside the σ3 create tool. SF Campaign Status is single-valued (standard picklist), so the `status:paused` overlay (stackable on `status:active` per O1) cannot use Status alone — Substatus carries the pause overlay.

**D6 handbook refactor adjustment**:

The handbook page that used to be `active-campaigns.md` (per D6 reframed to a navigation pointer) now points at the **SF list view URL** as the primary live rollup, with a secondary pointer to the Linear "Brite GTM" project for drill-down. Both pointers stay in the navigation doc; the primary handle is the SF list view.

**What's NOT moving to SF** (stays Linear / plugin):

- Brief content (Linear milestone description — never duplicated to SF)
- Sub-issue work-in-flight (Linear sub-issue tree)
- Weekly active-mgmt comments (Linear sub-issue 7 comments — O4 still open on writeback shape)
- Audit trail / who-approved-what (Linear comments)
- Plugin emission artifacts (plugin filesystem under `docs/campaigns/{entity}/`)
- canonicals.yaml (plugin-side per 7.2)
- mmf-matrix.md, discoveries.json, learnings.md (plugin-side per 7.1)

**Operator workflow shift to verify with V3 (Marketing buy-in)**:

Sarah / Corinne / Kells currently live in Linear for campaign work. Routing the *portfolio rollup* question to SF means the Monday GTM sync agenda starts in SF (inventory) and drills into Linear (specific blockers). This is the most operator-visible change in the Phase 2 design; V3 ratification is essential before O14 handbook PRs commit to it.

**Periodic snapshot exports** (separate from live rollup):

For monthly campaign review packets or quarterly retros that need a frozen point-in-time snapshot, a plugin command (provisional name `/marketing:portfolio-snapshot`) could emit a markdown report from SF + Linear + plugin data. Not the primary rollup mechanism — the SF list view stays primary — but worth keeping the option open. Tracked as O6 sub-question (Q5).

**Q2 LOCKED — Default "Active Campaigns" view spec**:

- **Grouping**: by `Status` (primary; one block per status value visible in the default filter).
- **Default filter**:
  - `Status ∈ {Planned, In Progress}` (excludes Completed + Aborted/Killed).
  - `Substatus__c ∈ {null, Paused}` (Paused visible — not excluded).
  - No date-window filter (Status filter naturally bounds visible records; stale-Active surfaces as visible "should have been debriefed" reminder).
  - No Owner filter (portfolio view is everyone's; per-owner triage = sibling saved view).
  - No Entity filter (entity-only views = siblings).
- **Sort**: `StartDate ASC` within each Status group (most-urgent / nearest launch at top of each block).
- **Columns** (7, in order):
  1. `Name` (slug — primary identifier, clickable)
  2. `Vertical` (`Vertical__c`)
  3. `Owner`
  4. `Launch` (`StartDate`)
  5. `Pipeline` (`AmountAllOpportunities`)
  6. `Leads` (`NumberOfLeads`)
  7. `Linear` (`External_Campaign_URL__c`)
- **Deliberately NOT in default columns** (available via "Edit Columns"): Persona, Offer, Closed-Won revenue, Substatus, EB campaign ID, Entity. Slug `Name` already encodes 4 dimensions; lean column count protects scan-density at the Monday GTM sync.

**Q2-implied new SF custom fields** (added to O10's plugin-skill-gaps enumeration alongside `Substatus__c` from earlier in this section; all populated by the σ3 MCP write tool at scaffold):

| Field | Type | Purpose |
|---|---|---|
| `Persona__c` | Text (64) | Kebab-case persona slug (e.g., "events-director") |
| `Offer__c` | Text (64) | Kebab-case offer slug (e.g., "zoolights-experience") |
| `Entity__c` | Picklist | `{nites, supply, labs, cross-entity}` |
| `Substatus__c` | Picklist | `{null, Paused}` (status:paused overlay carrier per Q1) |

`Month` and `FY` derive from `StartDate` — no separate fields. `Vertical__c` and `External_Campaign_URL__c` already exist in brite-salesforce (per σ3 grounded findings).

**Four sibling saved views** ship alongside the default (all populated automatically by σ3's writeback; no manual maintenance):

| View name | Grouping | Filter delta vs default | Purpose | Cadence |
|---|---|---|---|---|
| **Active Campaigns** (default) | Status | — | Weekly GTM sync, daily check-ins | daily / weekly |
| Coverage by Vertical | Vertical | `Status ≠ Killed` (include Completed for coverage history) | Quarterly gap analysis | monthly / quarterly |
| Launch Calendar | Month (from StartDate) | `Status ∈ {Planned, In Progress}` AND `StartDate ≥ TODAY - 30d` | Forward-look on upcoming launches | weekly / monthly |
| Owner Load | Owner | Same as default | Load balancing, staffing | weekly |

Cadence-row → view-URL mapping is locked in Q3 below.

**Q3 LOCKED — Cadence-to-view mapping** (all 4 rows):

| Cadence | View / artifact | Plugin command |
|---|---|---|
| Daily | (no portfolio rollup — per-individual Linear "My Issues") | none |
| Weekly GTM sync (Mon) | Active Campaigns default + Launch Calendar sibling | none |
| Monthly campaign review | Coverage by Vertical (current-month filter) + NEW Performance Dashboard + portfolio-snapshot | `/marketing:portfolio-snapshot --monthly` |
| Quarterly planning | Coverage by Vertical (FY filter) + Performance Dashboard (FY filter) + NEW Pipeline by Offer Family Dashboard + portfolio-snapshot + brite-gtm campaign-portfolio.md | `/marketing:portfolio-snapshot --quarterly` |

**Row 1 (Daily) rationale**: daily ops are per-person, not portfolio shape. Operators open Linear "My Issues" filtered to their assignee. Status transitions surface via Linear notifications. A "5-second SF glance" ritual either gets skipped (dead weight) or bloats standup; the rollup earns its keep at weekly+ cadences only.

**Row 2 (Weekly GTM sync) rationale**: Monday agenda's two highest-frequency questions are status-shape ("what's running, anything stuck?") and launch-calendar ("what launches this week/next?"). Status-shape resolves cleanly in the Active Campaigns default view (Status grouping). Launch-calendar resolves better in the Month-grouped sibling than via column-sort in the default. Owner Load is a *when-needed* view (load issues surface from operators flagging them, not weekly view scanning). Two URLs in the meeting doc as standing links. No plugin command — SF + Linear drill-down is sufficient at weekly cadence.

**Row 3 (Monthly campaign review) rationale** — load-bearing for the portfolio-snapshot command:

The monthly review needs three classes of data: portfolio shape (SF can see), performance aggregates (SF can see), and qualitative outputs (debrief verdicts, transferable_notes, mmf-matrix verdict transitions, cross-entry pattern bullets from learnings.md — plugin-side, SF cannot see). Three artifacts open at the meeting:

1. **SF Coverage by Vertical** (existing sibling saved view, populated by σ3) — portfolio shape including completed campaigns.
2. **NEW SF Performance Dashboard** — pipeline-by-vertical + leads-by-month + conversion-funnel + verdict-distribution charts. Built on σ3 custom fields. Deployed to brite-salesforce as canonical metadata (NOT operator-customized).
3. **NEW plugin command `/marketing:portfolio-snapshot --monthly`** — read-only synthesis orchestrator merging SF quantitative + plugin-side qualitative; emits one committable markdown packet per invocation.

**Row 3 — Sharpened `/marketing:portfolio-snapshot` scope** (anti-creep guards):

- **Read-only**. Never mutates source data (canonicals, learnings.md, mmf-matrix.md, SF Campaign records).
- **One output per invocation**: `docs/campaigns/_reviews/monthly-{YYYY-MM}.md` OR `docs/campaigns/_reviews/quarterly-{YYYY-Q}.md`.
- **Two flags only**: `--monthly` | `--quarterly`. No `--weekly` (row 2 lock: weekly is SF-only). No `--custom-window`. No `--forecast` (FUT). No `--charts` (markdown only; charts live in SF Dashboard).
- **Inherits all metric definitions** from `campaign-analysis` §3.3. Never defines new metrics.
- **Reads pre-aggregated outputs**, never re-implements them. `campaign-debrief`'s `learnings.md` Summary stats / What works / What doesn't sections already auto-regenerate per entity; portfolio-snapshot READS those sections directly across all 3 entities — it does NOT re-aggregate from `## Campaign log` entries.
- **Inputs**: 50-200 SF records via `run_soql_query`; 50-200 Linear milestones via `list_issues`/`get_issue`; ~3 learnings.md + ~3 mmf-matrix.md + ~20-50 analysis-*.md + ~50-200 manifest.json files via filesystem `Read`.
- **No new MCP tools required** — uses existing read tools on revops:salesforce (`run_soql_query`) + plugin_workflows_linear-server (`list_issues`/`get_issue`/`list_milestones`). σ3's new write tools (`create_sf_campaign` + `update_sf_campaign_status`) are for plan-campaign scaffold, not portfolio-snapshot.

**Row 3 — Dependency graph** (portfolio-snapshot ships LATE in implementation order):

```
   canonicals          plan-campaign       O15 entity-slug
   backfilled  ──┐     command live  ──┐   normalized  ──┐
   (D11)         │     (O3)            │   (Artifact Q1) │
                 ▼                     ▼                 ▼
         ┌───────────────────────────────────────────┐
         │  σ3 MCP write tools live                  │
         │  + 4 custom SF fields deployed            │
         │  + 4 saved views deployed                 │
         │  + Performance Dashboard deployed         │
         └────────────────────┬──────────────────────┘
                              │
                              ▼
            ┌─────────────────────────────────────┐
            │  ≥1 dogfood campaign emitted        │
            │  (artifacts on disk to aggregate)   │
            └────────────────┬────────────────────┘
                             │
                             ▼
            ┌─────────────────────────────────────┐
            │  /marketing:portfolio-snapshot       │
            │  ships                               │
            └─────────────────────────────────────┘
```

Dashboards + saved views ship earlier and provide value at monthly review even before the packet exists.

**Row 3 — V3 downgrade gate**:

If Marketing (V3 ratification) rejects the markdown packet ("we live in SF + Slack; don't need another file"), M2 degrades to **M3** (SF Dashboard + Coverage view only, no plugin command). Q5 cascades to NO; row 4 (quarterly) loses the quarterly packet; O14 handbook PR for `how-we-operate.md` cadence rows adjusts accordingly. **Tractable rebound — not a blocker.** V3 ratification happens against a *populated* dogfood snapshot, not an empty hypothetical.

**Row 3 — brite-salesforce metadata vs plugin code separation** (added to O10 inventory):

| Artifact | Repo / location | Deployment path |
|---|---|---|
| 4 custom SF fields (Persona__c, Offer__c, Entity__c, Substatus__c) | brite-salesforce | revops:salesforce MCP `deploy_metadata` |
| 4 saved list views (Active Campaigns default + 3 siblings) | brite-salesforce | revops:salesforce MCP `deploy_metadata` |
| 1 Performance Dashboard | brite-salesforce | revops:salesforce MCP `deploy_metadata` |
| `create_sf_campaign` + `update_sf_campaign_status` MCP write tools | revops:salesforce MCP code | Plugin PR + new MCP tool methods |
| `/marketing:portfolio-snapshot` command | plugins/marketing/commands/ | Plugin PR |

**Row 4 (Quarterly planning) rationale** — Option Q-B locked:

Quarterly planning is strategic horizon — retrospective on the prior quarter + commitment for the next. Four data classes are needed (different emphasis from monthly): prior-quarter portfolio shape + offer-family ROI granularity + cross-quarter learnings synthesis + ideation queue for next quarter. Five artifacts open at quarterly review:

1. **SF Coverage by Vertical** (FY filter) — same sibling saved view from Q2/Q3 row 3, with date filter widened to FY-scope. No new SF artifact.
2. **SF Performance Dashboard** (FY filter) — same dashboard from row 3, FY-windowed. Vertical × month aggregations (reused).
3. **NEW SF Pipeline by Offer Family Dashboard** — different granularity from monthly. Charts: pipeline per Offer Family, revenue per Offer Posture, verdict distribution per Offer Family across quarters. Answers "which offers compound, which decay." Built on σ3 custom fields (Offer__c already locked in Q2; no additional field surface). Deployed to brite-salesforce as canonical metadata (NOT operator-customized).
4. **`/marketing:portfolio-snapshot --quarterly`** — same command as row 3, different flag, different section emphasis: cross-quarter MSPA matrix transitions, cumulative transferable_notes synthesis, per-offer-version aggregation (reads O13's `docs/campaigns/{entity}/offers/{slug}/{version}/performance.md` if shipped; section gracefully empty/omitted if O13 hasn't shipped), coverage-gap callouts per vertical × persona.
5. **brite-gtm `campaign-portfolio.md`** (pre-Linear ideation queue per O7) — quarterly is the natural graduation gate. 🟢🟡⚪ ideations get reviewed; committed ones promote to Linear milestones for next quarter.

**Row 4 — Why one command (not two)**: `--monthly` vs `--quarterly` flags branch within the same command on window-selection + section-rendering logic. Same inputs, same anti-creep guards, same output directory pattern (`docs/campaigns/_reviews/monthly-{YYYY-MM}.md` vs `_reviews/quarterly-{YYYY-Q}.md`). Avoids two near-duplicate commands.

**Row 4 — Forecast command stays FUT**: quarterly review is retrospective + commitment, not predictive modeling. Forecasting is statistical modeling, a different discipline; pulling it into this design would scope-creep portfolio-snapshot into territory it isn't built for. Tracked as a future skill in O10 if it ever becomes load-bearing — not in this design.

**Row 4 — Q5 cascades**: row 4's `--quarterly` flag is the second implicit-YES vote for portfolio-snapshot. V3 downgrade gate from row 3 applies identically here — if Marketing rejects the packet at V3, BOTH `--monthly` and `--quarterly` cascade to NO; Q5 lands as NO; row 4 degrades to "Coverage by Vertical + Dashboard + brite-gtm only" (no plugin command, no markdown packet).

**Row 4 — brite-salesforce metadata additions** (extends Row 3 table):

| Artifact | Repo / location | Deployment path |
|---|---|---|
| NEW Pipeline by Offer Family Dashboard | brite-salesforce | revops:salesforce MCP `deploy_metadata` |

**Q4 LOCKED — Retrospective rhythm subsumed by D4 + Q3** (no additional retro layer needed):

Three retro layers already exist after Q3:
1. **Per-campaign** — `campaign-debrief` skill at sub-issue 8 close (D4), async per-campaign. The granular learning unit (sub-campaign doesn't exist per D1; super-campaign aggregation lives in monthly/quarterly).
2. **Monthly** — Q3 row 3's monthly campaign review IS a retro. "Renew / scale / retire" decisions are inherently retrospective; bundling reflection + forward-looking decisions in one meeting avoids meeting bloat.
3. **Quarterly** — Q3 row 4's quarterly planning IS a retro. Cross-quarter synthesis = retro lens; next-quarter commit = planning lens. One meeting covers both. (Engineering separates retro from planning because cycles are short and event-bounded; marketing campaigns aren't cycle-bounded so synthesis happens at planning time anyway.)

Sibling cross-skill handoffs close retrospective loops without operator-driven meetings:
- `campaign-debrief` → `product-marketing-context` (cross-entity propagation proposals when `transferable: true`)
- `campaign-debrief` → `/workflows:handbook-drift-check` (handbook-contradiction signals)
- `message-market-fit` ITERATE Step 3.5 → reads `learnings.md` `transferable_note` values back into next batch's Results Log

**Explicit not-in-scope** decisions (rejected push-backs):
- No weekly retro (weekly GTM sync per Q3 row 2 is operational, not reflective)
- No annual retro (quarterly × 4 covers FY-equivalent ground; FY transition can degrade into a "quarterly + expanded window" version of Q3 row 4 if leadership later wants it)
- No per-vertical retro (Coverage by Vertical view drilling within quarterly covers per-vertical signal)
- No cycle retro for marketing (cycles don't exist as a marketing unit; campaigns + quarterly are the granularities)

**Q5 LOCKED — /marketing:portfolio-snapshot ships** (subject to V3 gate):

Q3 rows 3+4 both depend on portfolio-snapshot. Q5 is the explicit lock that the command is in-scope. Two flags only: `--monthly` | `--quarterly`. Read-only synthesis orchestrator per Row 3 sharpened scope. Anti-creep guards apply.

**V3 gate**: V3 ratification (Marketing buy-in on the markdown packet) happens against a populated dogfood snapshot. If V3 rejects, BOTH `--monthly` and `--quarterly` cascade to NO; M2 → M3 for both rows; tractable rebound (drop command + Pipeline-by-Offer-Family Dashboard becomes optional; Coverage view + Performance Dashboard still ship; monthly + quarterly meetings degrade to SF-only).

**O6 FULLY LOCKED** — Q1 + Q2 + Q3 (all 4 rows) + Q4 + Q5 all locked. Implementation surface enumerated in O10. V3 gate enumerated in V3 task.

---

### 7.9 Phase 2 still open

- O3 Socratic walkthrough — paused at Step 2 sub-chunk 4 (content extraction); Steps 3-10 unwalked. Step 7b now references 7.8's expanded σ3 scope.
- D8 — persona authorship process (Marketing decision).
- O6 Q2-Q5 — list view shape, cadence map, retro rhythm, periodic snapshot exports (Q1 LOCKED at 7.8).
- O8 — handbook navigation refactor (partially subsumed by O14; 7.8 updates the active-campaigns.md pointer).
- O9 — migration / dogfood (depends on O3 + O8 + O14).
- O10 — plugin skill gaps enumeration (concretely listable now; +Substatus__c SF field, +update_sf_campaign_status MCP tool).
- O12 — cross-skill alignment migration plan (drafted; review vs locked vocab).
- O13 — per-version aggregation skill (detailed; ready for plan refinement).
- O14 — handbook PR drafting (depends on V3; updated 7.8 implication on active-campaigns.md).
- O15 — entity slug migration (cleanup).
- V1, V2, V3 — validation homework (V3 ratification specifically essential for 7.8 operator workflow shift).

---

## 8. Appendix C — Phase 2 handoff prompt (use this for new sessions)

```
GTM campaign orchestration design — RESUME SESSION (Phase 2 continuation)

Read these files end-to-end before responding:
  1. docs/designs/gtm-campaign-orchestration-design.md (primary — read
     Section 7 carefully; Sections 1-6 are Phase 1 context)
  2. memory/project_marketing_vocabulary.md (5-category vocabulary canon — LOCKED)
  3. memory/project_gtm_campaign_architecture.md (D1-D6 + O1 + O2 +
     Phase 2 architectural pivot)
  4. memory/session_2026_05_11_gtm_campaign_design.md (full trajectory
     including Phase 2 continuation section)
  5. memory/feedback_interview_chunking.md (interview mode rule — CRITICAL,
     one question per turn, no batched sub-questions)
  6. memory/reference_brite_gtm_repo.md
  7. memory/reference_handbook_campaign_docs.md

Re-create the design-tree task list per Appendix A of the design doc,
extended with Phase 2 tasks. The task IDs from the prior session are gone
(fresh runtime); recreate based on the content below. Mark completed /
in_progress / pending per the state table at the end of this prompt.

DO NOT re-litigate any of these LOCKED decisions:
  Phase 1:  D1-D6, O1, O2, O3 step 1, O3 step 2 sub-chunks 1-3
  Phase 2 architectural pivots:
    - Handbook = HOW (process); Plugin = WHAT (entities + state)
    - canonicals lives plugin-side at plugins/marketing/data/canonicals/
    - discoveries.json category-tagged signal pattern
    - σ3 from O11 (keep D2; auto-create SF Campaign)
  Phase 2 vocabulary canon (5 categories complete):
    Identity Q1-Q5; State Q1; Artifact Q1
    See project_marketing_vocabulary.md for full disambiguation
  Phase 2 D7 re-walk:
    Final thin schema (slug + display + personas[] + offers[]);
    flat personas; per-offer status only; optional aliases/playbook_path
  Phase 2 closes:
    D9 (single-repo versioning), D10 (dropped), D11 (all 27 day-1),
    O5 (-v2 suffix), O7 (pre-Linear queue), O11 (σ3)

If you genuinely want to push back on a locked decision, surface it
explicitly and re-prompt the user — never silently drift.

RESUME POINT — three options the user can pick from:
  (A) Walk O6 (cross-campaign rollup view + retrospective rhythm)
      — Real Socratic interview; depends on O1+O2 (locked).
      Feeds into O8 + O14 + handbook process docs.
  (B) Resume O3 Socratic walkthrough at Step 2 sub-chunk 4 (content
      extraction into brief template + sub-issue descriptions),
      then Steps 3-10. Note: Step 2 simpler now that canonicals
      lives plugin-side (handbook canonicality validation is a local
      filesystem read, not remote gh api).
  (C) Blitz cleanup — enumerate O10 (plugin skill gaps); review O12
      (cross-skill migration plan) against locked vocab; close out O8
      (handbook nav refactor remaining items). Faster path to "done"
      if no major interview decisions remain.

  Default recommendation if user says "continue": option (A) — O6 is
  highest-leverage; cleanup is mechanical and can follow.

COMMUNICATION MODE:
  - Socratic interview, ONE assumption per question turn
  - For each question, recommend an answer + brief rationale
  - Walk dependency tree (foundational decisions first)
  - ASCII diagrams welcome; multi-sub-question text blocks forbidden
  - Auto mode active — progress autonomously between substantive decisions
  - No emojis (per feedback_no_emojis_in_generated_content.md)
  - When user asks "ultrathink" — actually use sequential-thinking and
    deep reasoning; don't return shallow answers

THINGS THE NEW SESSION SHOULD CHECK BEFORE FIRST INTERVIEW QUESTION:
  - Verify canonicals.yaml architectural pivot is understood (look at the
    new path: plugins/marketing/data/canonicals/, NOT handbook)
  - Verify 4-layer offer model is understood (Family > Posture > Angle >
    Specific Instance)
  - Verify ICP=template / Segment=instance distinction is understood
  - Verify the 3 verdict vocabularies are kept distinct (Angle / Experiment
    / Campaign Verdict)
  - Verify discoveries.json category-tagged pattern is understood
  - Verify σ3 from O11 (keep D2, auto-create SF Campaign) is understood

LOCAL CONTEXT:
  - brite-gtm repo:  /Users/holdenhalford/projects/work/brite-nites/brite-gtm/
  - handbook repo:   /Users/holdenhalford/projects/work/brite-nites/handbook/
    (read from sibling paths; do NOT clone or fetch)
  - Plugin repo:     /Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins/
  - SF metadata:     /Users/holdenhalford/projects/work/brite-nites/brite-salesforce/
                     (Campaign object active; revops MCP is read-heavy)

═══════════════════════════════════════════════════════════════════════════
TASK LIST STATE (recreate via TaskCreate; mark per below):
═══════════════════════════════════════════════════════════════════════════

COMPLETED (Phase 1 + Phase 2):
  D1   — Campaign unit (Vertical × Persona × Offer × Month)
  D2   — 3-layer split (Handbook / Linear / Plugin) [REFRAMED Phase 2:
          Handbook=HOW; Plugin=WHAT — but D2 itself stays locked]
  D3   — Sub-issues = stand-up work
  D4   — 7+2 sub-issue template
  D5   — Brief in Linear milestone description
  D6   — Handbook role refactor (navigation, not state)
  D7   — Final thin canonicals schema (plugin-side)
  D9   — Single-repo schema versioning contract
  D10  — DROPPED (--handbook-ref flag unnecessary)
  D11  — All 27 verticals backfilled day-1 (revised scope)
  O1   — Status labels (planning/active/completed/killed + paused overlay)
  O2   — Slug rule + manifest.json cross-system identity
  O5   — Multi-wave: same-month + new copy = -v2 suffix
  O7   — brite-gtm = pre-Linear planning queue
  O11  — σ3 (keep D2 + auto-create SF Campaign via new revops MCP write tool)

IN PROGRESS:
  O3   — /marketing:plan-campaign scaffolding command (paused mid-Step 2
          sub-chunk 4; Steps 3-10 unwalked)
          BLOCKED BY: O10 (informs Step 8 sub-issue creation), O13
          (informs Step 6 manifest.json schema), O11 (Step 7b SF auto-
          create — now locked, so unblocked)

PENDING (Socratic walk needed):
  D8   — Persona authorship process (who authors slugs+titles for 27
          verticals; Marketing decision + light walk)
  O6   — Cross-campaign rollup view + retrospective rhythm
          (DEPENDS ON: O1, O2 — both locked; ready to walk)

PENDING (cleanup / enumeration):
  O8   — Handbook navigation refactor (partially subsumed by O14;
          quick close-out remaining)
  O10  — Plugin skill gaps enumeration (now concretely listable:
          /marketing:offer-performance per O13; /marketing:new-vertical
          / new-offer / new-persona per Q-Step2.2 sibling commands;
          /marketing:icp-refinement-review for promoting discoveries;
          revops:salesforce create_campaign MCP write tool per σ3;
          BC-2720 reply-processing + BC-2725 lead-routing + BC-2722
          outbound-playbook already in backlog)
  O12  — Cross-skill alignment migration plan (drafted; needs review
          vs locked vocab canon)

PENDING (already detailed; ready for plan refinement):
  O13  — Per-offer-version metric aggregation skill (per-version
          performance.md + /marketing:offer-performance command +
          mmf ITERATE Step 3.6 quantitative feedback)
  O14  — Handbook PR drafting (vocabulary canon + framework docs;
          depends on V3 Marketing buy-in)
  O15  — Entity slug short-form migration (campaign-debrief learnings.md
          path; low-priority cleanup)

PENDING (user offline / validation homework):
  V1   — gh CLI auth audit (still relevant for cross-tool consumers
          reading canonicals from britenites-claude-plugins repo;
          lower priority than original framing since canonicals is
          plugin-local for skills now)
  V2   — Handbook parsing-conflict audit (grep handbook + sibling
          repos; partial inline-doable)
  V3   — Marketing buy-in on canonicals + framework docs (essential
          before O14 handbook PR drafts)

PENDING (downstream — wait for upstream decisions):
  O9   — Migration / dogfood (depends on O3 complete + O8 + O14)

═══════════════════════════════════════════════════════════════════════════

After reading the files, ask the user which resume option (A / B / C)
they want to walk. Default to (A) if they say "continue."
```
