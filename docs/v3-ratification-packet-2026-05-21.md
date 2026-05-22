---
schema_version: 1
generated_at: 2026-05-21T18:00:00-07:00
ratification_target: BC-8729
items: 8
meeting_attendees: [Sarah Cullen, Kells, Holden Halford]
status: draft
source_dogfood: BC-8727 (Brite Labs × Hotels & Resorts × Director of Resort Experience × Holiday Anchor Audit × FY26-M02)
source_repo: britenites-claude-plugins @ holden/bc-8729-v3-prep-packet
---

# V3 Ratification Packet — GTM Campaign Orchestration v1.0

## TL;DR

Marketing is being asked to ratify eight architectural decisions that, taken together, lock GTM Campaign Orchestration v1.0. Seven of these are spec items pre-locked in BC-8729's description (canonicals shape, the 4-layer offer model, ICP/Segment vocabulary, the 3-verdict translation table, the discoveries.json category pattern, a hand-crafted T7-Q portfolio-snapshot dry-run packet against the BC-8727 dogfood, and the operator workflow shift from `active-campaigns.md` to a Salesforce list view). One item — BC-10653 / SF JWT auth — was added 2026-05-21 to ratify the fix that landed today and choose a monitoring cadence for the underlying refresh-token expiry risk.

The fork the meeting decides is M2 vs M3:

- **M2 (ratify the packet)** — five additional BCs ship as designed: `/marketing:portfolio-snapshot` (BC-8731), the Pipeline-by-Offer-Family Dashboard (BC-8716, already shipped), and four handbook PRs (BC-8732/33/34/35) — vocabulary canon, framework docs, active-campaigns nav refactor, how-we-operate cadence rows.
- **M3 (reject)** — those five BCs cascade to backlog. SF Performance Dashboard (BC-8715, shipped) + Coverage by Vertical view (BC-8714) still ship. Monthly + quarterly reviews degrade to SF-only with no qualitative merge.

This packet does **not** recommend M2 or M3. It surfaces each item structurally and names the daily-workflow consequence of ratify-vs-reject so Marketing can decide from concrete examples rather than abstract architecture.

## How to use this packet

Each of the eight items is structured identically:

1. **Content** — what the decision is, with code or examples cited from the codebase
2. **What changes if ratified** — concrete behavior locked in
3. **What changes if rejected** — fallback shape, which BCs cascade where
4. **Daily workflow impact** — what Sarah / Corinne / Kells actually do differently

Read each section, capture ratify / reject / modify in the outcome document (`docs/v3-ratification-outcome-2026-MM-DD.md`), and the meeting closes with one M2/M3 decision derived from the per-item dispositions.

The "Open ambiguities" section at the bottom collects everything that surfaced as fuzzy during drafting — those are candidate agenda items the meeting may want to address first.

---

## Item 1 — Canonicals YAML structure (T3-G output sample)

**Content.** Canonicals are plugin-side per [ADR-016](decisions/016-gtm-plugin-side-canonicals.md). One file per vertical at `plugins/marketing/data/canonicals/{vertical}.yaml`; an index at `_manifest.yaml` enumerates all 27 vertical slugs. The schema is thin per D7: `slug` + `display` + `personas[]` + `offers[]`. Persona shape is `slug` + `display` + `titles[]`. Offer shape is `slug` + `display` + `status (draft|active|retired)` + `posture (knowledge|free-asset|pilot|risk-reversal)` + optional `target_personas[]` / `target_postures[]` / `replaced_by` / `iterates_from` / `prose_path`.

Real sample — `plugins/marketing/data/canonicals/hotels-resorts.yaml` as it stands after BC-8727 patched it:

```yaml
slug: hotels-resorts
display: "Hotels & Resorts"
playbook_path: "marketing/go-to-market/verticals/hotels-resorts/README.md"
personas:
  - slug: director-of-resort-experience
    display: "Director of Resort Experience"
    titles:
      - "Director of Resort Experience"
      - "Director of Guest Experience"
      - "Director of Resort Activations"
      - "Director of Recreation & Resort Activations"
      - "Director of Guest Experiences"
      - "VP Resort Experience"
      - "VP Guest Experience"
offers:
  - slug: holiday-anchor-audit
    display: "Resort Holiday Anchor Audit"
    status: draft
    posture: free-asset
    target_personas:
      - director-of-resort-experience
    prose_path: "marketing/go-to-market/verticals/hotels-resorts/offers/holiday-anchor-audit.md"
```

ADR-016 chose plugin-side over handbook-side because skills read canonicals at runtime on every `/marketing:plan-campaign` invocation; handbook-side would have required `gh api` fetch + cache on each call, and handbook-PR cadence (1–2 weeks median) is too slow for operator-driven persona/offer additions. The thin schema (D7) — no ICP nesting, no service-type fields — is what BC-8727 actually exercised in the dogfood. Lint enforcement lives at `plugins/marketing/scripts/lint_canonicals.py`; the JSON Schema declaration is at `plugins/marketing/data/canonicals/schema.json`.

**What changes if ratified.** Canonicals stay where they are (plugin-side, thin schema). All 27 verticals get their `{slug}.yaml` file day-1 per D11 — Active verticals (7) populated, Exploring (8) and Future (12) skeleton (`personas: []`, `offers: []`) until promoted via `/marketing:new-persona` + `/marketing:new-offer` (BC-8725). Every campaign that scaffolds via `/marketing:plan-campaign` validates against these files at Step 2 — if the persona or offer slug isn't in the YAML, plan-campaign hard-fails and points the operator to the sibling bootstrap command. The persona/offer schema is locked: marketing-authored additions are 7–12-line YAML diffs, not handbook PRs.

**What changes if rejected.** This is the load-bearing taxonomy decision. Rejecting it forces a return to handbook-side canonicals (which means every skill picks up `gh api` auth + remote fetch) or to inferring slugs from handbook prose at runtime (fragile parsing, no enforcement). Both options were rejected in ADR-016's Alternatives section. A meaningful "reject" here would more likely take the form of "modify the schema" — e.g., re-introducing ICP nesting under personas, or moving `posture` to a separate file. Each modification cascades through `lint_canonicals.py`, `/marketing:plan-campaign` Step 2, and the BC-8718 backfill scope.

**Daily workflow impact.** Marketing adding a new persona for a vertical = a 7-line YAML diff committed to `britenites-claude-plugins` (PR review lightweight, no handbook ownership). New offer = ~10 lines. Today's BC-8727 cohort-1 walk added both with hand-edits (because BC-8725 hadn't shipped); the same operation lives a year from now as a single sibling command. Sarah and Kells do not author canonicals directly — Holden / the outbound operator does — but Marketing reviews each canonicals PR on a D8 cadence to approve `display` names and `titles[]` cascades.

---

## Item 2 — 4-layer offer model + Offer Posture rename rationale

**Content.** Per [ADR-017](decisions/017-gtm-offer-posture-rename.md), Brite's offer concept has four distinct layers, each with its own decision surface:

| Layer | Name | Cardinality | Owns | Decision surface |
|---|---|---|---|---|
| 1 | **Offer Family** | One per conceptual bundle | canonicals.yaml `offers[].slug`; SF Campaign Name root; EB Campaign Name root | Operator-stable across many campaigns |
| 2 | **Offer Posture** | Four values: `knowledge` / `free-asset` / `pilot` / `risk-reversal` | Handbook framework doc (BC-8733); copy artifact JSON `offer_posture` field | Per-entity-typical (Nites → `free-asset`; Labs → `pilot`; Supply → `pilot` + `risk-reversal`) |
| 3 | **Angle** | Many per offer family | MSPA matrix A column; creative-angles output; email-copywriting body framing | Per-experiment, per MSPA row |
| 4 | **Specific Offer Instance** | One per campaign | copy artifact `offer_summary` field; Linear milestone description | Per-campaign-copy |

Layer 2's four values are the Posture rename — old code → new slug:

| Old letter code | New descriptive slug | CTA shape |
|---|---|---|
| `T1` | `knowledge` | "Here's a resource, no reply needed." Lowest friction. |
| `T2` | `free-asset` | "We'll prepare a specific asset, no commitment." Most common Nites default. |
| `T3` | `pilot` | "Small paid pilot; success pays for itself." Use when signal HIGH + procurement strong. |
| `T4` | `risk-reversal` | "First phase on us if it doesn't hit X by Y." Large-spend / committee-heavy. |

ADR-017's rationale: the letter codes `T1/T2/T3/T4` collided with list-building's title cascade (where `T1` = C-suite, `T2` = VP, `T3` = Director — decision-maker seniority). Two skills, identical codes, completely different meanings. Title Tier is more entrenched (canonical in handbook prose + list-building for ~6 months pre-design), so the rename happens on the Offer side and the values move to descriptive slugs operators read naturally. BC-8720 was the implementation migration across `email-copywriting` + `creative-angles` + `launch-campaign` artifact references — **shipped 2026-05-22 ([PR #346](https://github.com/Brite-Nites/brite-claude-plugins/pull/346); ADR-017 graduated to canon)**. V3 ratification confirms the migration retroactively per V3's completion-ratification framing; rejection at this stage means rolling back PR #346 rather than blocking unshipped work.

**What changes if ratified.** The 4-layer model becomes the canonical offer-concept architecture. BC-8720's migration is in place across ~4 skills + the copy artifact JSON `offer_posture` field (PR #346, 2026-05-22); ratification confirms the direction. Handbook framework doc at `marketing/frameworks/offer-postures.md` (BC-8733) carries the universal classification. Per-entity-typical guidance lives in email-copywriting §3. canonicals.yaml `offers[].posture` enum is locked to those four values (already true in the JSON Schema at `plugins/marketing/data/canonicals/schema.json`).

**What changes if rejected.** Reject the **rename** specifically: roll back PR #346 (a real revert of merged work, heavier than a "don't ship" would have been); `offer_tier` letter codes return to copy artifacts; list-building Title Tier collision returns; operator mental-model load reverts to pre-design state. Reject the **4-layer model**: requires re-litigating which layer Angle lives on (was it the per-experiment thing, or the same as Posture?) — and that re-opens ADR-018 (3 verdict vocabularies, which is layer 3's home in the MSPA matrix). Modifications here are likely: rename a value (e.g., `risk-reversal` → `risk-reversed-pilot`), or add a fifth posture for a use case Marketing has in mind. Each value-rename is a ~6-touchpoint change (canonicals schema enum, lint, email-copywriting selection matrix, BC-8720 migration code, framework doc, this packet).

**Daily workflow impact.** When Sarah or Corinne reads a copy artifact JSON in PR review, they see `"offer_posture": "free-asset"` instead of `"offer_tier": "T2"`. When email-copywriting recommends a posture during artifact generation, the recommendation reads "Recommended: `free-asset` (Nites default)" instead of "Recommended: T2." When a list-building output cascade also surfaces "T1 titles" (C-suite), there's no longer ambiguity about whether `T1` means seniority or commitment-level. Today's BC-8727 canonicals entry already encodes `posture: free-asset` — the model is in use; only the cross-skill migration is pending.

---

## Item 3 — ICP=template / Segment=instance vocabulary (Identity Q1–Q2)

**Content.** Per `memory/project_marketing_vocabulary.md` § 1 (Identity terms, LOCKED), four identity terms were disambiguated:

- **Vertical** — Industry/market category from handbook taxonomy. The canonical "where in the market are we" identifier. Slug shape `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. 27 verticals in current handbook (7 Active + 8 Exploring + 12 Future). Owns: handbook taxonomy table at `verticals/README.md`; canonicals.yaml filename.

- **Market** — The broader market HYPOTHESIS being tested in a specific MSPA experiment row. *Not* the canonical taxonomy category. Per-experiment freeform text. Owns: MSPA matrix M column only. Example: "Luxury/upscale resorts with $1M+ outdoor programming budgets, post-Q4-2025-mortem, pre-FY27-capital-ask (6-8 weeks from FY27 commit deadlines), asking 'what's our version of Christmas at the Princess?'" That whole sentence lives in M; the `hotels-resorts` slug lives separately in V.

- **ICP** — The reusable firmographic + persona + worldview template that defines an ideal customer for a vertical. Stable definition; updated periodically based on experiment learning. Owns: handbook prose (vertical README `## ICPs` sections); tam-mapping JSON criteria files; handbook `templates/icp-persona-template.md`. *Not in canonicals* — canonicals is identity-only (slugs); ICP-as-grouping context lives in handbook prose.

- **Segment** — The specific sub-cluster of an ICP being tested in this experiment row. Per-experiment instance; disposable. Owns: MSPA matrix S column. Three relationships to ICP are valid: Segment = ICP exactly (testing if the ICP works at all); Segment ⊂ ICP (subset narrowing, e.g., "AZA zoos with $20M+ in Texas only"); Segment ⊃ multiple ICPs (rare — cross-ICP-boundary testing).

The crisp rule for ratification: **Vertical and ICP are templates; Market and Segment are instances**. Vertical is the canonical handbook taxonomy slug; ICP is the reusable template that wraps personas + firmographics for that taxonomy slug. Market and Segment exist only per-MSPA-row and only inside the `message-market-fit` skill. Skills outside MSPA never use the words Market or Segment.

When the discoveries.json system (item 5) emits `icp-refinement` signals, the human review flow promotes them via handbook PR (touching the ICP template, not the Market column of any MSPA matrix). When operators add a new persona for a vertical, the canonicals diff is plugin-side (no ICP template change). When MSPA picks a Segment for batch-1, the matrix author writes a narrowing descriptor into the S cell — Brite's matrix never points at the ICP template directly because the Segment IS the per-experiment lens.

**What changes if ratified.** The vocabulary lock graduates from `project_marketing_vocabulary.md` § 1 to `handbook/marketing/frameworks/vocabulary.md` via BC-8732. The four terms become the canonical glossary across all 14 marketing skills. SKILL.md updates are touch-light (vocabulary.md is the canonical source; skill files cite it rather than redefine it). ICP refinement signals flow `discoveries.json` → handbook PR; ICP definitions never move to canonicals.

**What changes if rejected.** Most likely failure mode is "modify": Marketing decides ICP should live in canonicals after all (e.g., to enable plan-campaign to fetch firmographics at scaffold time without a handbook read). That cascades through ADR-016 (canonicals schema expands), BC-8718 (backfill scope grows), and `/marketing:plan-campaign` Step 2 (adds firmographic checks). The full-reject path returns to pre-design state where ICP and Segment are used interchangeably across skills.

**Daily workflow impact.** When Sarah opens an MSPA matrix in the Labs entity (`docs/campaigns/labs/mmf-matrix.md`), she sees four columns — M / S / P / A — each filled with prose-shaped content scoped to one experiment row. When Corinne opens the handbook hotels-resorts README, she finds the ICP section as reusable template prose with persona profile shapes. The two never look the same. When BC-8727's debrief produces an `icp-refinement` discovery, the promotion path is "Marketing reviews the discoveries.json entry on a quarterly cadence → if accepted, opens a handbook PR updating the ICP section → ICP template now reflects experimental learning." The MSPA matrix row that surfaced the signal is unchanged; only the template gets touched.

---

## Item 4 — 3-verdict translation table (Angle / Experiment / Campaign Verdict)

**Content.** Per [ADR-018](decisions/018-gtm-verdict-vocabularies.md), three distinct verdict vocabularies trace the campaign lifecycle, each emitted by a different skill at a different decision gate:

| Gate | Skill | Parent label | Token set | Decides |
|---|---|---|---|---|
| 1 — Pre-experiment | `creative-angles` | **Angle Verdict** | `ALPHA` / `PROMISING` / `INTERESTING` / `COMMODITY` | "Is this angle worth testing?" |
| 2 — Post-batch | `message-market-fit` ITERATE | **Experiment Verdict** | `SUPER WORKS` / `KIND OF WORKS` / `DOESN'T WORK` / `DEFERRED` / `PENDING` | "How did this MSPA row perform?" |
| 3 — Post-campaign | `campaign-debrief` | **Campaign Verdict** | `SCALE` / `ITERATE` / `PAUSE` / `KILL` | "What action on this campaign overall?" |

Cross-vocabulary translation (informal, for understanding):

```
   Best case:    ALPHA      → SUPER WORKS    → SCALE
   Iterate:      PROMISING  → KIND OF WORKS  → ITERATE
   Drop:         PROMISING  → DOESN'T WORK   → KILL
   Pre-empt:     COMMODITY  (never enters matrix; never reaches Gate 2 or 3)
   Wait:         any        → DEFERRED       → PAUSE
```

The three vocabularies are kept distinct (not merged) because each gate consumes a different evidence base — Asymmetry Rubric (6 weighted dimensions / 8 = 0–10 score) vs. EB metrics + qualitative reply read vs. cross-campaign synthesis + numeric thresholds. Merging the tokens would mask the evidence-quality difference. BC-8721 was the implementation migration that renamed parent labels per skill (`creative-angles` "verdict" → "angle verdict"; `mmf` "verdict" → "experiment verdict"; `campaign-debrief` "verdict" → "campaign verdict") — **shipped 2026-05-22 ([PR #347](https://github.com/Brite-Nites/brite-claude-plugins/pull/347); ADR-018 graduated to canon)**. V3 ratification confirms the renames retroactively per V3's completion-ratification framing; rejection at this stage means rolling back PR #347 rather than blocking unshipped work. BC-8733 is the handbook framework doc `marketing/frameworks/verdicts-cross-reference.md` that carries the canonical translation table.

In the BC-8727 cohort-1 walk, the lifecycle plays out as:

1. `/marketing:creative-angles` (sub-issue #10) scored Angle A (FY27-Ammunition) at 7.2/10 = **PROMISING** Angle Verdict
2. `/marketing:message-market-fit` ITERATE will run post-send-window and emit an Experiment Verdict against the M02 MSPA matrix row currently sitting at **PENDING**
3. `/marketing:campaign-debrief` (sub-issue #8) emits a Campaign Verdict (SCALE / ITERATE / PAUSE / KILL) after Q3-of-the-debrief computes the numeric threshold cross

**What changes if ratified.** BC-8721's renames are in place across three SKILL.md files (PR #347, 2026-05-22); ratification confirms the direction. BC-8733 ships the handbook framework doc with the canonical translation table. `/marketing:portfolio-snapshot --quarterly` (BC-8731) reads all three vocabularies and surfaces them under separate sections of the markdown packet (see item 6 for what that looks like against BC-8727 dogfood data). The single word "verdict" never appears without one of the three modifiers in any operator-facing surface.

**What changes if rejected.** Most likely failure mode is "merge them anyway" — Marketing decides three vocabularies is one too many and asks for a single 4-value rubric across all three gates. That would now require rolling back PR #347 plus authoring a unified vocabulary migration; the merge would collapse the Asymmetry Rubric's `ALPHA/PROMISING/INTERESTING/COMMODITY` into the same shape as `SCALE/ITERATE/PAUSE/KILL`, which loses the pre-experiment Asymmetry-score nuance (COMMODITY is a pre-empt signal that never enters the matrix; SCALE is a post-campaign action). ADR-018's Alternatives section already rejected this. A partial-modify could be: keep three distinct vocabularies but use shorter parent labels (e.g., `AV` / `EV` / `CV` letter prefixes). That stays operator-opaque per ADR-018's letter-codes rejection.

**Daily workflow impact.** When Sarah or Corinne reads a copy artifact + situation-mining output, they see Angle Verdict tokens. When they review an MSPA matrix mid-quarter, they see Experiment Verdict tokens with the matrix's Results Log. When they read a learnings.md entry, they see Campaign Verdict tokens. When `/marketing:portfolio-snapshot --quarterly` runs, the markdown packet has three separately-headed sections: one for Angle Verdict distribution (from creative-angles outputs in window), one for Experiment Verdict transitions (from mmf-matrix.md Results Log), one for Campaign Verdict distribution (from learnings.md). No verdict is ever named without its gate modifier.

---

## Item 5 — discoveries.json category-tagged pattern

**Content.** Per BC-8722's spec body, every campaign's discoveries.json file emits category-tagged signals. Four categories are locked:

| Category | Emitted by | Promotes to | Promotion cadence |
|---|---|---|---|
| `title-discovery` | `list-building` | canonicals.yaml `personas[].titles[]` | Operator-driven (next plan-campaign run) |
| `icp-refinement` | `campaign-debrief` | handbook `verticals/{slug}/README.md` ICP section | Quarterly (strategic) + per-batch (tactical) |
| `offer-retirement` | `campaign-debrief` | canonicals.yaml `offers[].status = retired` + `replaced_by` pointer | Per-quarter review |
| `persona-discovery` | `campaign-debrief` (during sub-issue #8 verdict synthesis) + `situation-mining` (when new title patterns surface at prospects) | canonicals.yaml `personas[]` new entry | Operator-driven (next plan-campaign run) |

JSON Schema shape (from BC-8722 § Implementation Steps):

```json
{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-01-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": {
        "vertical": "hotels-resorts",
        "persona_slug": "director-of-resort-experience",
        "candidate_title": "Director of Resort & Recreation Programming",
        "source": "linkedin-sales-nav",
        "frequency_in_target_list": 7,
        "rationale": "Marriott + Hilton properties cluster this title under guest-experience umbrella; not yet in titles[] cascade"
      },
      "promotion_status": "pending"
    },
    {
      "category": "icp-refinement",
      "emitted_at": "2026-03-12T09:00:00Z",
      "emitted_by_skill": "campaign-debrief",
      "payload": {
        "vertical": "hotels-resorts",
        "icp_field": "firmographics.minimum_budget",
        "current_value": "$1M+ outdoor programming budget",
        "proposed_value": "$2M+ outdoor programming budget",
        "rationale": "Cohort-1 reply data showed <$2M properties consistently routed to wrong stakeholder (Director of Operations, not Director of Resort Experience); narrowing ICP would tighten the persona/title cascade"
      },
      "promotion_status": "pending"
    }
  ]
}
```

The pattern that makes this work: **skills emit, humans promote**. No skill mutates canonicals.yaml or the handbook directly. Every signal lands as a pending entry in `docs/campaigns/{entity}/{slug}/discoveries.json`. Marketing reviews on a hybrid cadence (per-batch tactical for `title-discovery`, per-quarter strategic for the other three categories) and opens a canonicals diff or handbook PR. The `promotion_status` field transitions `pending → promoted | rejected` when Marketing acts; the signal remains in the file as a permanent record. BC-8722 (the implementation BC) is currently post-V3 polish.

**What changes if ratified.** BC-8722 ships the schema + lint script (`plugins/marketing/scripts/lint_discoveries.py`) + SKILL.md additions to `list-building` and `campaign-debrief`. `/marketing:portfolio-snapshot --quarterly` reads cross-campaign discoveries.json files and surfaces pending signals as an "Action items" section in the markdown packet (see item 6). The four-category lock + emission pattern enters the handbook framework doc.

**What changes if rejected.** Without a category-tagged emission pattern, skills either (a) don't surface latent learnings at all (the pre-design state — operator memory loss) or (b) skills directly mutate canonicals/handbook (rejected because removes the human review gate). The most likely modification path: collapse `persona-discovery` into `title-discovery` (since both ultimately touch canonicals personas[]). That works but loses the distinction between "new title to add to existing persona" (title-discovery) and "new persona to author" (persona-discovery, which is heavier — needs a `display` + `titles[]` cascade). Another modification: add a fifth category for `vertical-discovery` (when a campaign surfaces a non-canonical vertical worth promoting from Future → Exploring → Active). That requires a corresponding handbook taxonomy change.

**Daily workflow impact.** Every cohort-1 campaign run produces a discoveries.json file alongside its manifest.json. When sub-issue #8 closes and `/marketing:campaign-debrief` writes its Campaign Verdict, the skill also appends any `icp-refinement` / `offer-retirement` / `persona-discovery` signals it generates. When `list-building` runs (sub-issue #2) and the operator notices a new title pattern in the target list, the operator can append a `title-discovery` signal during list review. When `/marketing:portfolio-snapshot --quarterly` runs, the Action Items section consolidates all pending signals across all campaigns in window — that becomes the Marketing review queue for the quarter.

In BC-8727's case (M02 launch, debrief lands T+35d = ~2026-03-10), the discoveries.json will likely contain at least one `title-discovery` signal (Marriott / Hilton title pattern variants discovered during sub-issue #2 target list build) and, depending on reply patterns, one `icp-refinement` signal (firmographic narrowing or persona-stakeholder mismatch). Both flow to Marketing's Q1 2026 review.

---

## Item 6 — T7-Q portfolio-snapshot dry-run packet against BC-8727 dogfood (LOAD-BEARING)

**Content.** This is the hand-crafted markdown that `/marketing:portfolio-snapshot --monthly` (BC-8731) would emit today, 2026-05-21, if it were running against the BC-8727 cohort-1 dogfood data. BC-8731 is not built — per V3 routing decisions (`project_gtm_v1_state_2026-05-21.md`), portfolio-snapshot is M2-conditional post-V3 execution. This packet shows the *shape* of the output the command will emit, so Marketing can ratify the structure before the command ships. Per BC-8731 § Implementation Steps 5, the five required sections are: Portfolio shape / Pipeline summary / Verdict distribution / Transferable insights / Action items.

> **SF Campaign row absent in this dry-run** — the BC-8727 manifest predates the BC-10653 fix (closed 2026-05-21T22:06:26Z), so `salesforce.campaign_id: null`. Future runs against post-2026-05-21 campaigns will have full SF rollup (Pipeline summary will populate from SOQL on `Campaign.AmountAllOpportunities` + `AmountWonOpportunities` + `NumberOfLeads`). This packet shows the gap honestly rather than fabricating SF figures.

The packet below is what BC-8731 emits when invoked as:

```bash
/marketing:portfolio-snapshot --monthly
# default window: previous calendar month = 2026-05-01 → 2026-05-31
# only campaign with StartDate in window: BC-8727 (M02 launch 2026-02-03 — outside window)
# expanded for this dry-run to year-to-date so the sample is non-empty:
# effective window: 2026-01-01 → 2026-05-21
```

### --- Portfolio Snapshot, generated_at 2026-05-21T18:00:00-07:00 ---

```markdown
---
schema_version: 1
generated_at: 2026-05-21T18:00:00-07:00
command_version: marketing@0.x.x (BC-8731 dry-run)
window:
  start: 2026-01-01
  end: 2026-05-21
  span: year-to-date (expanded from default --monthly window for non-empty dogfood preview)
---

# Portfolio Snapshot — 2026-01-01 → 2026-05-21 (YTD dry-run)

## 1. Portfolio shape

| Entity | Vertical | Persona | Offer | Posture | Status | Slug |
|---|---|---|---|---|---|---|
| labs | hotels-resorts | director-of-resort-experience | holiday-anchor-audit | free-asset | planning | hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02 |

**Totals:** 1 campaign in window · 1 entity (labs) · 1 vertical (hotels-resorts) · 1 persona · 1 offer · 1 posture (free-asset) · 1 status block (planning)

**By entity:** labs = 1 / supply = 0 / nites = 0 / cross-entity = 0
**By vertical:** hotels-resorts = 1 / all 26 others = 0
**By posture:** free-asset = 1 / knowledge = 0 / pilot = 0 / risk-reversal = 0
**By Linear status:** planning = 1 / active = 0 / completed = 0 / killed = 0 / paused = 0

Coverage gap: 26 of 27 canonical verticals have zero campaigns in window. Year-to-date portfolio depth = 1.

## 2. Pipeline summary

> ⚠ SF rollup section degraded — BC-8727 manifest carries `salesforce.campaign_id: null` (predates BC-10653 fix, 2026-05-21). Future runs against post-fix campaigns will populate from SOQL on `Campaign.AmountAllOpportunities` / `AmountWonOpportunities` / `NumberOfLeads`.

| Slug | SF Campaign | AmountAllOpportunities | AmountWonOpportunities | NumberOfLeads | EB campaign_id | Launched |
|---|---|---|---|---|---|---|
| hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02 | (absent) | n/a | n/a | n/a | (not launched) | no |

**Totals:** pipeline_value = unavailable (SF gap) · won_revenue = unavailable · target list build (sub-issue #2) = not yet executed · EB campaigns launched = 0.

The campaign sits in `status:planning` post-scaffold. BC-8727's deferred "≥1 EB campaign launched" AC will trip the brief → list → copy → SF reconciliation → QA → launch chain (sub-issues #1 → #6) before this section populates with real numbers.

## 3. Verdict distribution

### 3a. Angle Verdict (from creative-angles outputs in window)

Sub-issue #10 (Creative Angles) of BC-8727 has not yet executed — angle scoring was performed inline during the 2026-05-13 design session, not as a `/marketing:creative-angles` skill invocation. Captured per `project_gtm_cohort1_hotels_resorts.md`:

| Angle | Score (0–10) | Angle Verdict |
|---|---|---|
| A — FY27-Ammunition | 7.2 | PROMISING |
| B — Category-Benchmark-FOMO | 6.7 | PROMISING |
| C — Post-Mortem Rebound | 6.5 | PROMISING |
| D — Vendor-Tier-Gap | 5.8 | INTERESTING |
| E — Sponsor-Stack-Headstart | (discovered during scoring; rescore pending) | — |

Distribution: PROMISING = 3 / INTERESTING = 1 / ALPHA = 0 / COMMODITY = 0 / unscored = 1

### 3b. Experiment Verdict (from mmf-matrix.md Results Log)

Labs entity has no batched MSPA experiments in window. Cohort-1 MSPA row exists (M / S / P / A populated per spec; see `project_gtm_cohort1_hotels_resorts.md`) but Verdict column reads PENDING — populates only after sub-issue #8 debrief + mmf ITERATE post-T+40d.

Distribution: PENDING = 1 / SUPER WORKS = 0 / KIND OF WORKS = 0 / DOESN'T WORK = 0 / DEFERRED = 0

### 3c. Campaign Verdict (from learnings.md Summary stats)

Labs entity `docs/campaigns/labs/learnings.md` has no entries in window (cohort-1 debrief lands ~2026-03-10; this dry-run pre-dates it).

Distribution: SCALE = 0 / ITERATE = 0 / PAUSE = 0 / KILL = 0 / not-yet-debriefed = 1

## 4. Transferable insights

Source: `learnings.md` "What works" + "What doesn't" sections across campaigns in window. Pre-aggregated by `campaign-debrief`; NOT re-aggregated here per BC-8731 anti-creep guard.

No transferable insights available — BC-8727 has not yet reached sub-issue #8 (debrief). Future windows will surface:
- Cross-vertical angles that travel (e.g., from Angle E "Sponsor-Stack-Headstart" — if FY26-M02 surfaces it as outperforming, the Princess–BMW–Barrett-Jackson framing may travel to other luxury verticals)
- Cross-entity transferable_notes when present
- Reply-pattern observations that refine `icp-refinement` candidates downstream

## 5. Action items

Source: pending signals across all `discoveries.json` files in window + flagged items in analysis-\*.md outputs + open Linear sub-issues with blockers.

### 5a. Pending discoveries.json signals

(BC-8722 discoveries.json schema not yet implemented — once it lands, this subsection enumerates every `promotion_status: pending` entry across `docs/campaigns/*/*/discoveries.json` files in window. For 2026-05-21, this subsection is empty.)

### 5b. Operational follow-ups (manually collated from BC-8727 friction log)

| Item | Owner | Source | Status |
|---|---|---|---|
| BC-10653 (SF JWT auth) — completed 2026-05-21; verify σ3 path against fresh dogfood | Holden | BC-8727 F12 → BC-10653 | ✅ done |
| BC-8725 sibling commands (`/marketing:new-persona|new-offer|new-vertical`) — needed for next Path A dogfood; priority bump Low → High | unassigned | BC-8727 F1 | open |
| BC-8727 deferred AC: ≥1 EB campaign launched — needs brief (#1) → list (#2) → copy (#3) → SF reconciliation (#4) → QA (#5) → launch (#6) chain | unassigned | BC-8727 plan | open |
| Manifest schema v2 with `linear.sub_issues[]` array for downstream traceability | unassigned | BC-8727 F16 | V3-deferred |
| Linear MCP `save_issues_batch` feature request (cut 19 round-trips → 1) | upstream | BC-8727 F18 | V3-deferred |

### 5c. Coverage gaps

26 of 27 canonical verticals have zero campaigns in window. Quarterly snapshot (`--quarterly`) would call this out per BC-8731 § 5 sub-bullet "Coverage-gap callouts (verticals with 0 campaigns in window)."

---

End of packet.
```

### --- End portfolio-snapshot dry-run ---

What this preview demonstrates structurally (the load-bearing part of item 6 the meeting will scrutinize):

1. **Five sections, every section graceful-empty when data is sparse.** Today's dogfood has 1 campaign, no SF data, no debrief, no MSPA results. Each section degrades to "(absent)" or "0 / 0 / 0" rather than failing the packet.
2. **Pre-aggregation respected.** Section 4 reads `learnings.md` "What works" subsections directly; it never re-aggregates from Campaign log entries. Section 2 reads SOQL aggregates; it never recomputes pipeline value from line items. This is BC-8731's anti-creep guard.
3. **SF gap is surfaced honestly.** The manifest's `campaign_id: null` shows up as Section 2 ⚠ instead of being papered over with placeholder figures. Future runs against post-BC-10653-fix campaigns will populate.
4. **Three verdict vocabularies appear separately.** Section 3a/3b/3c renders Angle / Experiment / Campaign Verdict distributions independently per ADR-018. The single word "verdict" never appears unqualified.
5. **discoveries.json is plumbed but graceful-degrades.** Section 5a is empty because BC-8722 hasn't shipped; the subsection structure is already in place for when it does.

**What changes if ratified.** BC-8731 ships in this shape. `--monthly` produces the 5 sections; `--quarterly` adds 4 more (Cross-quarter MSPA transitions, Cumulative transferables, Per-offer-version aggregation, Coverage-gap callouts). Output writes to `docs/campaigns/_reviews/monthly-{YYYY-MM}.md` / `quarterly-{YYYY-Q}.md` per BC-8731 § Implementation Steps 6. The anti-creep guards (no `--weekly`, no `--forecast`, no `--charts`, no writes outside `_reviews/`, no re-aggregation) are locked.

**What changes if rejected.** This is the most likely M3 trigger. Reject = BC-8731 cascades to backlog; monthly/quarterly reviews use SF dashboards + Linear views directly with no qualitative merge. The reader's monthly review loses cross-campaign transferable insights and the discoveries-action-items consolidation. Quarterly loses Cross-quarter MSPA transitions (would live only in `mmf-matrix.md`, requires manual cross-quarter read) and Cumulative transferables (would live only scattered across `learnings.md` files, no aggregation surface).

Modify paths the meeting may want to consider: change the 5-section ordering (e.g., put Action items before Verdict distribution to make weekly review actionable-first); add a 6th section ("Recent shipments / merges" pulled from Linear); collapse Verdict distribution into a single block instead of three subsections; produce HTML instead of markdown (rejected per O6.Q5 — markdown-only).

**Daily workflow impact.** On the first Monday of each month, Sarah / Corinne / Kells get a `monthly-{YYYY-MM}.md` packet committed to `docs/campaigns/_reviews/`. They read it before the Monday GTM sync. Items in Section 5 become the week's prioritization queue. Section 3a/3b/3c gives the lifecycle health view at a glance. On the first Monday of each quarter, the `quarterly-{YYYY-Q}.md` packet supersedes — same structure plus the four cross-quarter sections — and feeds quarterly planning.

For BC-8727's actual lifecycle: when sub-issue #8 closes in March 2026, the next `monthly-2026-03.md` packet will be the first one with a non-empty Verdict distribution Section 3c (the cohort-1 Campaign Verdict), Section 4 (the cohort-1 transferable_note if surfaced), and Section 2 with real SF figures (assuming the campaign re-runs σ3 SF auto-create post-BC-10653-fix).

---

## Item 7 — Operator workflow shift (most behavior-changing item)

**Content.** Per `docs/designs/gtm-campaign-orchestration-design.md` § 7.8 ("the most operator-visible change in the Phase 2 design"), the portfolio rollup home moves from handbook `active-campaigns.md` (D6 reframed as a navigation pointer) to a **Salesforce list view**. ADR-014 carries the architectural rationale; the daily-workflow consequence is what V3 ratifies.

The shift:

| Old workflow (pre-Phase 2) | New workflow (Phase 2 ratified) |
|---|---|
| Sarah opens handbook `active-campaigns.md` Monday morning to see what's running | Sarah opens SF "Active Campaigns" default view (Status-grouped, 7 columns, filtered to `Status ∈ {Planned, In Progress}` and `Substatus__c ∈ {null, Paused}`) |
| Cross-campaign questions ("how many active by vertical?") = manual count from the handbook table | Cross-campaign questions = SF report grouped by `Vertical__c`; one click |
| Pipeline / revenue / meetings questions = unavailable (Linear has no pipeline value) | SF Performance Dashboard + Pipeline by Offer Family Dashboard answer directly |
| Sub-issue blocker questions = open Linear, drill into milestone, scan sub-issues | Sub-issue blocker questions = open Linear, drill into milestone, scan sub-issues (UNCHANGED) |
| Daily personal work queue | Linear "My Issues" (UNCHANGED) |

Per § 7.8's "Question routing" table, the split is sharp: **portfolio-scale questions go to SF; per-campaign drill-down stays in Linear; per-individual daily work stays in Linear "My Issues"**. The Monday GTM sync agenda starts in SF (inventory + funnel shape + launch calendar) and drills into Linear (specific blockers, sub-issue work). Audience split is clean — leadership (Kells + revenue stakeholders) already lives in SF for pipeline + revenue; marketing operators (Sarah, Corinne) drill into Linear for work-in-flight.

Why SF specifically (the ratification surface):

1. **σ3 already commits SF Campaign auto-create.** Every campaign auto-creates a SF row at scaffold (per ADR-015). Routing rollup elsewhere creates a parallel representation.
2. **SF is purpose-built for cross-record reporting.** List views, reports, dashboards, formula fields, scheduled snapshots — Linear's view editor cannot express pipeline-by-vertical aggregations or hierarchical rollups.
3. **SF has bottom-funnel data Linear never will** — pipeline value, closed-won revenue, meetings booked, conversion rates. Portfolio-level *performance* questions are mechanically impossible without SF.
4. **SF Campaign Hierarchies** enable offer-family-then-individual-campaigns-within-vertical grouping.

The handbook PR that operationalizes this (BC-8734) refactors `active-campaigns.md` from a tracking table to a navigation page that points at the SF list view URL as the primary live rollup, with a secondary pointer to the Linear "Brite GTM" project for drill-down. The page itself stops carrying state; it just routes.

**What changes if ratified.** BC-8734 ships the handbook refactor. BC-8735 ships the "how-we-operate" handbook PR adding cadence rows (Daily / Weekly / Monthly / Quarterly) that codify when each artifact is consulted. The Monday GTM sync agenda template gets a "Step 1: open Active Campaigns view in SF" line. SF Performance Dashboard (BC-8715, shipped) + Pipeline by Offer Family Dashboard (BC-8716, shipped) become the leadership review surfaces. ADR-014 graduates from advisory to canon.

**What changes if rejected.** This is the single highest-leverage ratification surface in the packet because rejection cascades through ADR-014 → BC-8734 (handbook refactor) → BC-8735 (cadence rows) → BC-8731 (portfolio-snapshot depends on SF as portfolio truth) → BC-8716 (Pipeline by Offer Family Dashboard becomes orphaned). Reject paths the meeting may consider:

- **Reject SF as portfolio home, keep handbook.** Means returning to Phase-1 design where handbook owns active-campaigns tracking — but Phase-1 found nobody maintains it (was empty pre-design). Implies a process commitment to maintain the table.
- **Reject SF, route portfolio to Linear native views.** Linear cannot express pipeline-value aggregations or cross-record rollups; this loses bottom-funnel visibility entirely.
- **Modify: SF primary + Linear synced view sidebar.** Adds an integration surface; was rejected as scope creep in the design session.

**Daily workflow impact.** This is the item Marketing day-to-day actually feels. Concrete differences for Sarah / Corinne / Kells:

- **Monday GTM sync (weekly)** — opens SF "Active Campaigns" default view as agenda Step 1 (sees BC-8727 cohort-1 in the `planning` block); opens SF "Launch Calendar" sibling view as Step 2 (sees the Feb 3 launch date); drills into Linear milestone `17450de2-...` for sub-issue blockers as Step 3. Time-to-portfolio-shape goes from ~5 min of handbook scrolling to ~10 seconds of SF view.
- **Monthly review (first Monday of month)** — opens SF Coverage by Vertical report (shows the 1-of-27 vertical gap); opens SF Performance Dashboard for the month; reads the `docs/campaigns/_reviews/monthly-{YYYY-MM}.md` packet (item 6 output) for qualitative merge.
- **Quarterly planning** — opens SF Pipeline by Offer Family Dashboard (shows holiday-anchor-audit Posture × pipeline view); reads quarterly packet; reviews brite-gtm pre-Linear ideation queue for Q+1 commits.
- **Sub-issue / blocker work (daily)** — Linear "My Issues" (UNCHANGED). Sarah's daily queue still lives in Linear.
- **Brief authoring** — Linear milestone description (UNCHANGED). Brief content never leaves Linear.

The shift is Monday-GTM-sync-shaped, not daily-work-shaped. Daily Linear use is preserved; what moves to SF is the cross-campaign rollup question that was unanswerable in pre-Phase-2 state.

---

## Item 8 — Ratify the BC-10653 fix + post-fix monitoring cadence

**Content.** [BC-10653](https://linear.app/brite-nites/issue/BC-10653) ("Fix SF JWT auth refresh failure blocking σ3 Campaign writes + EB launch") closed 2026-05-21T22:06:26Z (assignee Holden, status Done) with attachment `brite-salesforce` PR #249 "BC-10653: document sf-prod service-user auth rotation runbook." The fix surfaced as friction entry F12 during BC-8727 dogfood (2026-05-20) when `/revops:create-sf-campaign` Phase 2/3 SOQL calls failed against a stale brite-prod JWT. The soft-fail contract worked exactly as designed — plan-campaign continued, manifest got `salesforce.campaign_id: null`, no halt — but every plan-campaign run between 2026-05-20 and 2026-05-21T22:06Z produced a manifest with no SF row. ADR-014 portfolio rollup degraded silently.

This item is reframed from the original BC-8729 spec footing (which would have asked Marketing to choose "accept gap, fix in parallel" vs "gate V3 on the fix"). Both are moot — the fix landed today. What Marketing ratifies now is forward-looking:

**(a) The SF JWT auth runbook as the canonical re-auth path.**

The fix is documented at `brite-salesforce/docs/runbooks/sf-prod-jwt-auth-rotation.md` (per attachment to BC-10653). The runbook covers: what cert/key/connected-app backs the brite-prod JWT, the rotation procedure, the verification steps (`sf org display --target-org brite-prod --json` returns valid session), and the re-run path for `/revops:create-sf-campaign` against a throwaway slug to confirm SF write surfaces.

Marketing's ratification scope: this is the document Holden / RevOps follow whenever σ3 SF writes start soft-failing. No Marketing day-to-day touch surface — but the cadence question (b) below names when Marketing or RevOps proactively check the auth health.

**(b) Refresh-token expiry monitoring cadence.**

Refresh tokens expire silently. The pattern is now established: both [BC-10303](https://linear.app/brite-nites/issue/BC-10303) (CI `SFDX_AUTH_URL_DEVHUB` for scratch-org dry-runs) and BC-10653 (runtime `sf` CLI JWT against brite-prod) hit refresh-token expiry independently within 30 days of each other. Different auth surfaces, same failure mode. The next break is a question of when, not if.

Three monitoring options:

| Option | Cadence | Owner | Cost | Failure mode |
|---|---|---|---|---|
| **A. Per-quarter calendar check** | Every 3 months, RevOps runs `sf org display --target-org brite-prod --json` + verifies non-expired session | RevOps (Holden) | Low (5 min/quarter) | Up to 90 days of degraded σ3 writes between checks |
| **B. Weekly automated probe** | A `/revops:doctor` cron or CI job runs weekly; alerts on auth failure | RevOps (Holden) | Medium (one-time wire-up + weekly run) | ~7 days of degraded σ3 writes worst-case |
| **C. Accept-as-is + react when next break surfaces** | No proactive monitoring; rely on dogfood-style discovery + soft-fail signal | none | Zero | Indeterminate; depends on dogfood frequency |

Each option's tradeoff:

- **A** trades response-time for low overhead. If σ3 SF writes degrade between checks, every campaign scaffolded in that window writes `campaign_id: null` to its manifest. Portfolio rollup (item 6 Section 2) shows the gap honestly per BC-8731 design but loses pipeline visibility for affected campaigns until reconciled.
- **B** is the highest-confidence option but requires implementing the probe + alerting wiring. `/revops:doctor` exists and could carry the probe — wire-up cost is small. Alert routing (Slack? Linear issue? email?) is the additional decision.
- **C** is operationally cheapest but accepts that each break re-runs the F12 → BC-10653 cycle. Acceptable if dogfood cadence is high enough that breaks surface within days.

A fourth path the meeting may surface: **D. Calendar reminder one week before known rotation deadline.** Requires knowing the rotation deadline up-front — the runbook (a) should document this if cert/key has a fixed validity window.

**What changes if ratified.** The runbook (a) becomes the canonical re-auth procedure cited in plan-campaign + create-sf-campaign error messages on soft-fail. Whichever cadence option (b) is picked gets filed as a follow-up BC (Option A → calendar event + quarterly RevOps task; Option B → BC for `/revops:doctor` probe + alerting wire-up; Option C → no BC; Option D → calendar reminder + runbook update).

**What changes if rejected.** This is an unusual ratification surface — the fix is already in. "Reject" maps to two paths: reject the runbook as canonical (Marketing wants a different document or process — unlikely), or pick none of A/B/C/D and continue ad-hoc. Continuing ad-hoc is operationally what's been happening; the BC-10653/BC-10303 pattern argues it's not sustainable.

**Daily workflow impact.** Direct Marketing touch: minimal. The runbook is RevOps-facing. The cadence question affects how often Sarah / Corinne see `salesforce.campaign_id: null` in fresh manifests. If Option B is ratified, the probe surfaces breaks before they affect plan-campaign runs; Marketing never notices. If Option A or C, periodic windows of degraded σ3 writes are visible in `/marketing:portfolio-snapshot` Section 2 as ⚠ entries (per item 6 sample); Marketing notices when reviewing the monthly packet.

---

## Open ambiguities surfaced during drafting

Captured here for meeting agenda triage. Each is a candidate item that may need a quick decision before the per-item ratification walk.

1. **Item 8 cadence option default.** The packet presents A/B/C/D structurally without recommending. The meeting either picks now or this is the first agenda item. Suggested default: **B (weekly automated probe via `/revops:doctor`)** because the BC-10303 + BC-10653 pattern proves refresh-token expiry is silent + recurring; the wire-up cost is small relative to the cost of next 90-day degradation. Filing as recommendation, not lock.

2. **Item 6 dry-run window expansion.** The hand-crafted packet expanded the default `--monthly` window (May 2026) to year-to-date so the sample is non-empty. The real BC-8731 implementation defaults to "previous calendar month" — which against today's date (2026-05-21) would mean April 2026, where BC-8727 is also absent (Feb 2026 launch). Worth ratifying explicitly: does Marketing want `--monthly` to default to "previous calendar month" (strict per BC-8731 spec) or "month ending on today" (rolling 30-day)?

3. **Item 5 (discoveries.json) `vertical-discovery` fifth category.** Drafting surfaced this as a plausible fifth category (when a campaign surfaces a non-canonical vertical worth promoting from Future → Exploring → Active). BC-8722 currently locks at four categories. Worth confirming Marketing has no use case in mind for a fifth before BC-8722 ships.

4. **Item 7 SF list view default columns.** ADR-014 / § 7.8 locks 7 columns (Status / Slug / Vertical / Persona / Offer / Owner / StartDate). The actual BC-8714 implementation may have already deployed these (BC-8714 is in Backlog per current state). If column set differs from § 7.8, the ratification needs to reconcile.

5. **Item 1 schema modification scope.** If Marketing wants ICP nesting back into canonicals (rejected per ADR-016 but possible re-open), the cascade is BC-8718 backfill scope grows + `lint_canonicals.py` updates + plan-campaign Step 2 firmographic checks. Estimating: ~1 week additional work. Pre-decide cost appetite.

6. **Item 2 letter-codes deprecation window.** ADR-017 § Consequences specifies a "6-month deprecation window for `offer_tier` reads." Not load-bearing for V3 ratification but worth confirming the window with Marketing — shorter could accelerate BC-8720 cleanup; longer means longer artifact-cleanup tail.

7. **Item 4 BC-8721 timing relative to BC-8731.** BC-8731 (portfolio-snapshot) reads all three vocabularies. If BC-8721 (parent label renames) hasn't shipped yet when BC-8731 lands, the portfolio-snapshot output reads "verdict" three times instead of "angle verdict / experiment verdict / campaign verdict." Soft sequencing — BC-8721 before BC-8731 — should be confirmed.

8. **Item 3 vocabulary canon handbook path.** `project_marketing_vocabulary.md` targets `handbook/marketing/frameworks/vocabulary.md` as eventual destination per BC-8732. Worth confirming the handbook path is accepted (vs. e.g., `frameworks/marketing/vocabulary.md` or another nesting).

---

## References

- [BC-8729 Linear issue](https://linear.app/brite-nites/issue/BC-8729) — ratification target
- [BC-8727 Linear issue](https://linear.app/brite-nites/issue/BC-8727) — dogfood source
- [BC-8731 Linear issue](https://linear.app/brite-nites/issue/BC-8731) — portfolio-snapshot spec (item 6)
- [BC-10653 Linear issue](https://linear.app/brite-nites/issue/BC-10653) — SF JWT auth fix (item 8)
- [BC-8722 Linear issue](https://linear.app/brite-nites/issue/BC-8722) — discoveries.json schema spec (item 5)
- [ADR-014](decisions/014-gtm-salesforce-portfolio-rollup.md) — SF as portfolio home
- [ADR-016](decisions/016-gtm-plugin-side-canonicals.md) — plugin-side canonicals (item 1)
- [ADR-017](decisions/017-gtm-offer-posture-rename.md) — Offer Posture rename (item 2)
- [ADR-018](decisions/018-gtm-verdict-vocabularies.md) — 3-verdict vocabularies (item 4)
- [GTM master README](gtm-campaign-orchestration-README.md) — § 5 (M2/M3 callout) / § 7.8 (workflow shift) / § 3.6 (Path A worked example)
- [GTM v1 state snapshot](../.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-britenites-claude-plugins/memory/project_gtm_v1_state_2026-05-21.md) — current shipped/open state
- `plugins/marketing/data/canonicals/hotels-resorts.yaml` — canonicals sample (item 1)
- `docs/campaigns/labs/hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02/manifest.json` — dogfood manifest (item 6)
- `docs/plans/gtm-campaign-orchestration-friction-log.md` — 18 friction entries from BC-8727

