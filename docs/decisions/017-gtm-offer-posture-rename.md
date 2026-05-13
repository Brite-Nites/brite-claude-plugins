# 017. GTM Offer Tier → Offer Posture rename + 4-layer offer model

**Status:** Accepted
**Date:** 2026-05-13
**Linear:** [BC-8720](https://linear.app/brite-nites/issue/BC-8720) (T5-L — rename migration across email-copywriting + downstream)
**Related ADRs:** [ADR-013](013-gtm-three-layer-split.md), [ADR-018](018-gtm-verdict-vocabularies.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §6 (Offer terms in glossary), [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) §7.3 (vocabulary canon), [`memory/project_marketing_vocabulary.md`](../../../.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-britenites-claude-plugins/memory/project_marketing_vocabulary.md) (full disambiguation)

## Context

The 14 marketing skills used "Offer Tier" with letter codes (T1/T2/T3/T4) to classify CTA architecture / commitment level (T1 = lowest friction; T4 = highest commitment). Separately, `list-building` used "Title Tier" with the same letter codes (T1 = C-suite; T2 = VP; T3 = Director) for decision-maker seniority cascade.

The collision was real: operators encountered "T1" in two different skills with two completely different meanings. Mental-model load was high. Surfaced in the 2026-05-11 vocabulary disambiguation walkthrough (Identity Q5).

## Decision Drivers

- **T1/T2/T3/T4 collided in operator mental model.** Two different concepts in two skills using identical codes.
- **Title Tier is more entrenched** (list-building's title cascade has been canonical for ~6 months in `verticals/{vertical}/README.md` ICP sections).
- **Smaller touch surface to rename the Offer side.** Offer Tier appears in ~4 skills (email-copywriting, creative-angles, launch-campaign artifacts, gtm-strategy); Title Tier appears in handbook prose + list-building + downstream tam-mapping.
- **Descriptive slugs are operator-friendlier than letter codes.** "free-asset" reads better than "T2"; "pilot" reads better than "T3"; "risk-reversal" reads better than "T4".
- **The 4-layer offer model needed sharper labels for each layer.** Family / Tier / Angle / Specific Instance was the prior shape; Tier was the ambiguous middle layer.

## Decision

### Rename Offer Tier → Offer Posture

Values rename to descriptive slugs:

| Old code | New slug | Meaning |
|---|---|---|
| T1 | `knowledge` | CTA = "here's a resource, no reply needed." Lowest friction. |
| T2 | `free-asset` | CTA = "we'll prepare a specific asset, no commitment." Most common Nites default. |
| T3 | `pilot` | CTA = "small paid pilot; success pays for itself." Use when signal HIGH + procurement strong. |
| T4 | `risk-reversal` | CTA = "first phase on us if it doesn't hit X by Y." Use for large-spend / committee-heavy. |

### 4-layer offer model (locked)

```
   Layer 1  Offer Family          (canonicals slug — e.g., "zoolights-experience")
   Layer 2  Offer Posture         (knowledge / free-asset / pilot / risk-reversal)
   Layer 3  Angle                 (per-experiment framing in MSPA matrix)
   Layer 4  Specific Offer Instance  (one-line operator-readable summary)
```

Each layer has a different decision surface:
- Family is operator-stable (canonicals slug)
- Posture is per-entity-typical (Nites → free-asset typical; Labs → pilot typical; Supply → pilot default + risk-reversal when enterprise committee visible)
- Angle is per-experiment per-row in MSPA matrix
- Specific Instance is per-campaign-copy

### Title Tier (list-building) stays as T1/T2/T3

Smaller change-surface; more entrenched. No rename.

## Consequences

- `email-copywriting` SKILL.md §3 + copy artifact JSON: `offer_tier` field renamed to `offer_posture`; old `offer_tier` is backward-compat read for one release cycle.
- `creative-angles` + `gtm-strategy` + `launch-campaign` artifact references: same field rename.
- New handbook framework doc proposal: `marketing/frameworks/offer-postures.md` (per O14 / BC-8733).
- canonicals.yaml's `offers[]` entries optionally specify `target_postures: [...]` (advisory; per-campaign posture can override).
- `/marketing:plan-campaign` (BC-8724) and `/marketing:launch-campaign` consume `offer_posture` from copy artifact.
- Operator training: 6-month deprecation window for `offer_tier` reads; warn on use.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Keep Offer Tier with T1/T2/T3/T4 letter codes | Collides with Title Tier; operator confusion persisted from pre-design state |
| Rename Title Tier → Decision-Maker Tier (let Offer keep T1-T4) | Title Tier is more entrenched in handbook prose + list-building; bigger renaming surface |
| Rename Offer Tier → "Offer Commitment Level" with values L1-L4 | Letter codes still semantically opaque; "knowledge/free-asset/pilot/risk-reversal" are operator-natural |
| Rename Offer Tier → "Offer Type" with values knowledge/free-asset/pilot/risk-reversal | "Type" suggests taxonomy (which is Offer Family's job); "Posture" suggests stance (which is the actual concept) |

## Cross-references

- README §6 — Offer Family / Offer Posture / Angle / Specific Instance glossary entries
- README §3.5 — 4-layer offer model in MSPA flywheel context
- Memory `project_marketing_vocabulary.md` §1 (Identity terms) — full disambiguation
- Design doc §7.3 — Identity Q5 lock
- BC-8720 — migration implementation
- ADR-018 — sibling vocabulary rename (verdict labels)
