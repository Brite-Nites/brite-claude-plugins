# 012. GTM Campaign unit of analysis (Vertical × Persona × Offer × Month)

**Status:** Accepted
**Date:** 2026-05-13
**Linear:** [BC-8712](https://linear.app/brite-nites/issue/BC-8712) (Task 0 umbrella) / [BC-8724](https://linear.app/brite-nites/issue/BC-8724) (T4-I, the orchestrator that implements this)
**Related ADRs:** [ADR-013](013-gtm-three-layer-split.md), [ADR-014](014-gtm-salesforce-portfolio-rollup.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3 + §3.6, [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) Section 2 (D1)

## Context

Before this decision, three parallel Brite systems each defined "a campaign" differently:

- `brite-gtm/docs/campaign-portfolio.md` — Vertical × Offer × Quarter (44 planning-tier entries)
- `handbook/marketing/go-to-market/active-campaigns.md` — empty tracking table with no enforced unit
- Plugin `docs/campaigns/{entity}/{slug}/` — per-EB-launch artifact bundles, post-BC-6514 multiplicative segmentation could produce N EB campaigns per "effort"

No cross-system queries were possible. Slugs disagreed. Statuses disagreed. "Wave" handling (one effort → multiple persona-targetings under one umbrella) was ambiguous.

## Decision Drivers

- **Persona-targeting carries different copy, different cadence, and different verdict.** Aggregating across personas hides per-persona signal.
- **1:1 mapping** between Linear milestone, EB campaign, SF Campaign, and debrief entry is required for clean attribution.
- **Calendar month** is operator-natural (matches handbook quarterly review + Marketing monthly rhythm).
- **MSPA matrix rows** are typically per-Persona; mapping a matrix row to one campaign means the slug encodes the experiment unit.
- **Volume tractable**: ~150-250 milestones/year across active verticals/personas/offers — manageable for Linear; meaningless for any coarser unit.

## Decision

**Campaign = one Vertical × one Persona × one Offer × one calendar Month.**

- Each persona-targeting is a first-class Linear milestone, NOT a wave under a coarser umbrella.
- Slug rule: `{vertical}-{persona}-{offer}-fy{YY}-m{MM}`. Validates as `^[a-z0-9-]{1,80}$`. (Cross-entity exception: `cross-entity-{theme}-fy{YY}-m{MM}`.)
- FY prefix is calendar year (FY26 = 2026). Month numbering M01 = January … M12 = December.
- 1:1 mapping: Linear milestone ↔ Email Bison campaign ↔ Salesforce Campaign ↔ campaign-debrief entry in `learnings.md`.
- Same-month + new copy = `-v2` suffix (per O5). New month = new milestone, no suffix needed.

## Consequences

- Persona becomes a first-class slug component. Canonicals (ADR-016) must enumerate persona slugs.
- "Wave" concept dissolves. Same-month-multiple-personas = N separate campaigns scaffolded by N invocations of `/marketing:plan-campaign`.
- Volume scales linearly with persona surface — when Brite adds a new persona to a vertical, expected campaign count per vertical roughly doubles.
- `/marketing:plan-campaign` (BC-8724) cannot scaffold a campaign without resolving all 4 dimensions; missing canonicals = hard-fail with pointer to `new-vertical`/`new-offer`/`new-persona` commands.
- Entity is NOT in the slug (it's a Linear label + path prefix); single-entity verticals get auto-detected.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Vertical × Offer × Quarter (44-entry brite-gtm portfolio shape) | Hides persona-level signal; quarterly granularity loses month-by-month rhythm; multi-persona "waves" become an ambiguous sub-unit |
| Vertical × Offer × Persona × **Quarter** | Aligns with persona-as-first-class but loses the monthly Marketing review rhythm |
| Vertical × Persona × Month (drop Offer) | Same persona may run different offers in same month; collapsing loses copy-level experiment isolation |
| One Linear milestone per FY (campaigns as sub-issues only) | Doesn't compose with the 8+2 sub-issue template per milestone (D4); per-campaign artifacts (`manifest.json`, debrief) need their own anchor |

## Cross-references

- README §3 — Campaign unit definition + ASCII diagram
- README §3.6 — Worked example showing the unit in operation (Municipalities × Public Works Director × Free ROP Audit × M05)
- Design doc Section 2 D1 — full rationale
- BC-8724 (T4-I `/marketing:plan-campaign`) — implements the unit
