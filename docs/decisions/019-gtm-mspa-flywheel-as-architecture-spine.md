# 019. GTM MSPA matrix as architecture spine (experiment-to-campaign flywheel)

**Status:** Accepted
**Date:** 2026-05-13
**Linear:** [BC-8721](https://linear.app/brite-nites/issue/BC-8721) (verdict label renames), [BC-8722](https://linear.app/brite-nites/issue/BC-8722) (discoveries.json category schema), [BC-8728](https://linear.app/brite-nites/issue/BC-8728) (per-offer-version aggregation), [BC-8731](https://linear.app/brite-nites/issue/BC-8731) (portfolio-snapshot reads MSPA transitions), [BC-8733](https://linear.app/brite-nites/issue/BC-8733) (handbook framework doc)
**Related ADRs:** [ADR-013](013-gtm-three-layer-split.md), [ADR-016](016-gtm-plugin-side-canonicals.md), [ADR-018](018-gtm-verdict-vocabularies.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3.5, `plugins/marketing/skills/message-market-fit/SKILL.md`

## Context

The 6 prior ADRs (012-018) describe the SHAPE of the campaign system. This ADR captures the FLYWHEEL — the experiment-design framework that drives which campaigns get scaffolded and what they're testing. Without this ADR, a reader of the other 6 might think the plugin layer is a CRUD system for campaign artifacts. It isn't — campaigns are experiment rows whose verdicts feed back into the MSPA matrix, which drives the next batch.

The MSPA framework (Market × Segment × Persona × Angle) was already canonical in `message-market-fit` SKILL.md before this design effort. What this design changes: the FLYWHEEL is now ARCHITECTURALLY LOAD-BEARING for the plugin layer (canonicals + learnings.md + manifest.json + discoveries.json compounding), not just one skill's internal framework.

## Decision Drivers

- **The plugin layer compounds.** Each campaign isn't a one-off — it's an experiment row whose verdict trains the next batch. Append-only `mmf-matrix.md` + `learnings.md` are the compounding surface.
- **MSPA dimensions map directly to campaign slug components.** Persona is a slug component; Angle drives copy framing; Market/Segment are context. The flywheel and the unit-of-analysis (ADR-012) are isomorphic.
- **Verdicts trace the lifecycle** (per ADR-018). Pre-experiment (Angle Verdict from `creative-angles`) → post-batch (Experiment Verdict from `mmf` ITERATE) → post-campaign (Campaign Verdict from `campaign-debrief`). Each verdict gate has different evidence + decision surface.
- **discoveries.json category-tagged signal pattern** lets skills emit signals (title-discovery / icp-refinement / offer-retirement / persona-discovery) without directly mutating canonicals or handbook — humans promote via PR.
- **portfolio-snapshot --quarterly** (BC-8731) explicitly reads cross-quarter MSPA matrix transitions as a section of the markdown packet — the architecture commits to MSPA being a top-level rollup dimension.

## Decision

**The MSPA matrix is the architectural spine of the plugin layer's compounding behavior.**

### The flywheel (one entity, one MSPA matrix, append-only forever)

```
   MAP mode (first time for an entity)
     → mmf-matrix.md created with 5 hypotheses (5 rows)
     → mmf-batch-1.md designed
     → Verdict column starts at PENDING

   Each MSPA row → 1+ campaigns
     → /marketing:plan-campaign scaffolds
     → /marketing:launch-campaign fires EB

   After EB send window closes
     → /marketing:campaign-analysis emits analysis-*.md (5-verdict)
     → /marketing:campaign-debrief writes learnings.md (4-verdict)

   ITERATE mode (after batch completes)
     → mmf-results-{N}.md per batch
     → Verdict column populated
     → Step 3.5 reads transferable_notes back into matrix
     → mmf-batch-{N+1}.md designed
     → Barbell 80/20 + Kellen's 10 Laws enforced

   DIAGNOSE mode (when pipeline is stuck after ≥2 batches)
     → 5-level root-cause sequence (Market → Segment → Persona →
       Angle → Execution)
     → mmf-diagnosis-{YYYY-MM-DD}.md with single root cause
```

### MSPA dimension ↔ campaign slug translation

| MSPA dimension | Campaign translation |
|---|---|
| Market | Hypothesis context driving vertical+offer selection (NOT in slug) |
| Segment | Vertical narrowing or super-set (NOT in slug) |
| Persona | Slug component: `{vertical}-{PERSONA}-{offer}-fy{YY}-m{MM}` |
| Angle | Copy framing in email-copywriting body / subject (NOT in slug) |

### Compounding surfaces

- `docs/campaigns/{entity}/mmf-matrix.md` — append-only forever
- `docs/campaigns/{entity}/mmf-results-{N}.md` — per-batch
- `docs/campaigns/{entity}/mmf-diagnosis-{YYYY-MM-DD}.md` — per-DIAGNOSE-run
- `docs/campaigns/{entity}/learnings.md` — append-only verdict registry; transferable_note field flows back to matrix
- `docs/campaigns/{entity}/{slug}/discoveries.json` — category-tagged signals awaiting promotion (title-discovery / icp-refinement / offer-retirement / persona-discovery)
- `docs/campaigns/{entity}/offers/{slug}/{version}/performance.md` — per-offer-version aggregation (BC-8728)

### Governing frameworks (canonical in handbook per BC-8732/BC-8733)

- MSPA matrix (4 dimensions)
- Barbell 80/20 (allocate 80% to known winners; 20% to bets)
- Kellen's 10 Laws (iteration discipline; e.g., "Things that work and things you wanted to work are not synonymous")
- MAP / ITERATE / DIAGNOSE modes (entry rules per mode)
- Asymmetry Rubric (creative-angles upstream; 0-10 score driving Angle Verdict)
- Hormozi Value Equation (offer construction; orthogonal to MSPA layer)
- Recency Waterfall (6-level signal hierarchy in email copy)

## Consequences

- `portfolio-snapshot --quarterly` reads MSPA Results Log for cross-quarter verdict transitions — quarterly review's most operator-valuable section.
- canonicals.yaml's `personas[]` (ADR-016) feed the MSPA Persona dimension at scaffold time.
- `/marketing:plan-campaign` (BC-8724) validates Persona against canonicals (cross-checked against the operator's MSPA matrix row).
- `discoveries.json` category schema (BC-8722) is the runtime signal-emission surface; humans promote via PR — skills NEVER directly mutate canonicals or handbook.
- mmf `ITERATE` Step 3.5 cross-skill read of `learnings.md` `transferable_note` closes the feedback loop.
- BC-8728 (`/marketing:offer-performance`) surfaces compounding across MSPA rows that share an Offer Family.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Each campaign is a one-off; no cross-campaign feedback loop | Loses compounding; same-mistake-twice failure mode |
| MSPA matrix as a Salesforce custom object | SF Status field can't represent the 5-verdict matrix vocabulary; reporting tools don't compose with append-only invariant |
| Generic "experiment tracking" tool (Productboard, Notion, Linear) | None compose with EB workspace routing + entity-specific append-only matrices; mmf SKILL.md is the right home |
| MSPA dimensions all become slug components | Slug becomes unwieldy + Market/Segment/Angle are per-experiment-row context, not per-campaign identity |

## Cross-references

- README §3.5 — MSPA flywheel + ASCII diagram + governing frameworks list
- README §3.6 Step 0 — worked example shows MSPA row driving the campaign
- `plugins/marketing/skills/message-market-fit/SKILL.md` — canonical MSPA framework definition
- ADR-018 — verdict vocabularies that trace the lifecycle
- ADR-016 — canonicals plugin-side feeds the Persona dimension
- BC-8731 — portfolio-snapshot reads MSPA transitions
- BC-8733 — handbook framework docs (mspa-flywheel.md + kellens-laws.md + barbell + asymmetry-rubric.md)
