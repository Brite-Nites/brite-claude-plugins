# 014. GTM Salesforce as portfolio rollup home (over Linear-native)

**Status:** Accepted
**Date:** 2026-05-13
**Linear:** [BC-8714](https://linear.app/brite-nites/issue/BC-8714), [BC-8715](https://linear.app/brite-nites/issue/BC-8715), [BC-8716](https://linear.app/brite-nites/issue/BC-8716), [BC-8731](https://linear.app/brite-nites/issue/BC-8731) (T1-B/C/D + T7-Q)
**Related ADRs:** [ADR-013](013-gtm-three-layer-split.md), [ADR-015](015-gtm-sigma3-sf-campaign-sync.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3 (Salesforce box) + §5 (M2/M3 callout), [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) §7.8 (O6 chain Q1)

## Context

After the 3-layer split (ADR-013), the question remained: **where does the "all active campaigns at once" rollup live?** Four candidates were considered:

- Linear native project view (filtered by `status:active` label)
- Custom Linear view + saved filter
- brite-gtm `campaign-portfolio.md` regenerated nightly from Linear
- Plugin-emitted aggregate markdown report

The initial recommendation was Linear-native (D2 says Linear is the orchestration layer; rollup should sit there too). Holden pushed back: **Salesforce already has all the sending data + attribution; using Linear for portfolio rollup creates two representations.**

## Decision Drivers

- **Bottom-funnel data lives ONLY in SF.** Pipeline value, closed-won revenue, conversion rates, lead counts, meeting bookings. Linear has none of this. Portfolio-level performance is mechanically impossible without SF.
- **σ3 already commits SF Campaign auto-create** (ADR-015). The data is forming in SF whether we use it for rollup or not.
- **SF list views + reports + dashboards are purpose-built** for cross-record aggregation. Linear's view editor cannot express pipeline-by-vertical or revenue-per-offer-family charts.
- **SF Campaign Hierarchies** enable natural grouping (offer family → individual campaigns within a vertical).
- **Audience split is clean.** Leadership (Kells + revenue stakeholders) already lives in SF. Marketing operators drill into Linear for work-in-flight. The questions split along the same line as the people asking them.

## Decision

**Portfolio rollup lives in Salesforce list views + dashboards. Linear is per-campaign drill-down.**

D2 stays unchanged — D2's "reporting" half resolves to SF; the "orchestration" half stays Linear. Question routing:

| Question class | Home |
|---|---|
| Portfolio inventory / launch calendar / owner load | SF list view |
| Pipeline / revenue / meetings | SF report or dashboard |
| Coverage gap analysis | SF report grouped by Vertical__c |
| Sub-issue progress / brief content | Linear milestone |
| Audit trail / weekly active-mgmt comments | Linear comments |

Concrete artifacts shipped to brite-salesforce (BC-8713 through BC-8716):

- 4 new Campaign custom fields: `Persona__c`, `Offer__c`, `Entity__c`, `Substatus__c`
- 4 saved list views: Active Campaigns (default), Coverage by Vertical, Launch Calendar, Owner Load
- 2 dashboards: Performance Dashboard (vertical × month), Pipeline by Offer Family Dashboard (offer × quarter)

Plugin-emitted markdown packet (`/marketing:portfolio-snapshot --monthly|--quarterly`, BC-8731) supplements with qualitative content (verdicts, transferable_notes, MSPA transitions) that SF can't see.

## Consequences

- D6 handbook refactor adjusts: `active-campaigns.md` pointer becomes SF list view URL (primary) + Linear project URL (secondary).
- σ3 scope expands to include `update_sf_campaign_status` so SF Status mirrors Linear status:planning/active/completed/killed and Substatus__c carries the paused overlay (ADR-015).
- **Operator workflow shift** — Sarah/Corinne/Kells start GTM sync in SF (Active Campaigns view), drill into Linear for blockers. This is the most behavior-changing item for Marketing day-to-day; V3 ratification (BC-8729) is the gate.
- V3 outcome may downgrade to M3 (drop portfolio-snapshot + Pipeline-by-Offer-Family Dashboard). SF Coverage + Performance Dashboard always ship.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Linear native project view (`status:active` filter) | Linear can't aggregate pipeline/revenue across campaigns; no chart components |
| Custom Linear view + saved filter | Same limitation as native; better grouping/filtering but still no pipeline aggregation |
| brite-gtm `campaign-portfolio.md` regen from Linear nightly | Snapshot regeneration introduces stale-vs-live confusion; conflicts with O7 lock (brite-gtm is pre-Linear ideation queue) |
| Plugin-emitted aggregate markdown report | Lives elsewhere from where the data is; SF dashboards are cheaper to maintain than a plugin reporter |

## Cross-references

- README §3 — Salesforce role in 4-layer architecture
- README §5 — M2/M3 fallback table
- README §7 — T1-B/C/D BCs for SF metadata; T7-Q BC for snapshot
- Design doc §7.8 — full Q1 lock narrative
- ADR-015 — σ3 SF Campaign auto-create + status sync (the upstream mechanism)
