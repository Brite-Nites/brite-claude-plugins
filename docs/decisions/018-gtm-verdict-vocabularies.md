# 018. GTM 3 verdict vocabularies kept distinct (Angle / Experiment / Campaign Verdict)

**Status:** Accepted
**Date:** 2026-05-13
**Linear:** [BC-8721](https://linear.app/brite-nites/issue/BC-8721) (T5-M — rename parent labels per skill), [BC-8733](https://linear.app/brite-nites/issue/BC-8733) (T8-S — handbook framework doc `verdicts-cross-reference.md`)
**Related ADRs:** [ADR-013](013-gtm-three-layer-split.md), [ADR-017](017-gtm-offer-posture-rename.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3.5 (lifecycle diagram), [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) §7.3 (State Q1)

## Context

Three marketing skills emit "verdicts" at different points in the campaign lifecycle:

- **`creative-angles`** (pre-experiment): Asymmetry-rubric output. Tokens: `ALPHA` / `PROMISING` / `INTERESTING` / `COMMODITY`. Decides "is this angle worth testing?"
- **`message-market-fit` ITERATE** (post-batch): per MSPA matrix row. Tokens: `SUPER WORKS` / `KIND OF WORKS` / `DOESN'T WORK` / `DEFERRED` / `PENDING`. Decides "how did this batch row perform?"
- **`campaign-debrief`** (post-campaign): 4-verdict objective rubric. Tokens: `SCALE` / `ITERATE` / `PAUSE` / `KILL`. Decides "what action on this campaign overall?"

All three were called "verdict" in their respective SKILL.md files. Operators carrying a campaign through the lifecycle encountered the same word with three different meanings.

## Decision Drivers

- **Different evidence bases per gate.** Asymmetry rubric (6 weighted dimensions / 8 = 0-10 score) vs EB metrics + qualitative reply read vs cross-campaign synthesis + numeric thresholds. Merging the vocabularies would mask the evidence-quality difference.
- **Different decision surfaces.** Enter matrix? / iterate matrix row? / take campaign action? Three distinct decisions, three distinct vocabularies preserve the routing semantics.
- **Different timing.** Pre-launch / post-batch / post-campaign-close. Lifecycle stages.
- **Different owners.** Anyone designing experiments / mmf operator / campaign closer. Different roles emit different verdicts.
- **Cross-vocabulary translation is the operator's responsibility.** Skills shouldn't hide the gating semantics; explicit translation table lets operators reason about the lifecycle.

## Decision

**Keep all 3 verdict vocabularies distinct. Rename parent labels per skill** so the gating semantic is explicit at the source:

| Gate | Skill | Parent label | Token set |
|---|---|---|---|
| 1 — Pre-experiment | `creative-angles` | **Angle Verdict** | ALPHA / PROMISING / INTERESTING / COMMODITY |
| 2 — Post-batch | `message-market-fit` ITERATE | **Experiment Verdict** | SUPER WORKS / KIND OF WORKS / DOESN'T WORK / DEFERRED / PENDING |
| 3 — Post-campaign | `campaign-debrief` | **Campaign Verdict** | SCALE / ITERATE / PAUSE / KILL |

### Cross-vocabulary translation (informal, for understanding)

```
   Best case:    ALPHA      → SUPER WORKS    → SCALE
   Iterate:      PROMISING  → KIND OF WORKS  → ITERATE
   Drop:         PROMISING  → DOESN'T WORK   → KILL
   Pre-empt:     COMMODITY  (never enters matrix; never reaches Gate 2 or 3)
   Wait:         any        → DEFERRED       → PAUSE
```

Formalize in handbook `marketing/frameworks/verdicts-cross-reference.md` (BC-8733 / T8-S).

## Consequences

- `creative-angles` SKILL.md headers + output rows: "verdict" → "angle verdict".
- `message-market-fit` SKILL.md: "verdict" → "experiment verdict" (matrix column header stays "Verdict" in the table for column-width but section header renamed).
- `campaign-debrief` SKILL.md: "verdict" → "campaign verdict"; `learnings.md` entry frontmatter `verdict:` field stays (single-vocab context; no collision in artifact).
- `portfolio-snapshot --quarterly` (BC-8731) reads all three vocabularies and surfaces them under separate sections.
- Handbook framework doc (BC-8733) carries the canonical translation table.
- No data migration required — vocabulary tokens within each skill's output were already correct; only the parent labels rename.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Merge into one unified verdict vocabulary | Different evidence bases (asymmetry / EB metrics / synthesis); merging masks evidence-quality + decision-gate distinction |
| Keep parent labels generic ("verdict") + rely on context | Operator confusion persisted from pre-design; cross-skill flow ambiguous |
| Use numeric tiers (V1/V2/V3) for parent labels | Letter/number codes are operator-opaque; descriptive labels carry the gating semantic |
| Use lifecycle-stage labels (pre-exp / mid-exp / post-exp) | Lifecycle-stage is implicit in the skill that emits; explicit "Angle/Experiment/Campaign" labels are clearer |

## Cross-references

- README §3.5 — MSPA flywheel + 3-verdict lifecycle diagram
- README §6 — State terms in glossary
- Design doc §7.3 — State Q1 lock
- Memory `project_marketing_vocabulary.md` §2 (State terms) — full disambiguation + Why 3 distinct vocabularies
- BC-8721 — implementation (parent label renames)
- BC-8733 — handbook framework doc with translation table
- ADR-017 — sibling vocabulary rename (Offer Tier → Offer Posture)
