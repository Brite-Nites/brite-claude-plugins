# 023. Anti-Spam Guardrails Consolidation

**Status:** Proposed
**Date:** 2026-05-28
**Linear:** [BC-11924](https://linear.app/brite-nites/issue/BC-11924)
**Enforcement:** `prospect-temporal-gate` skill ([BC-10190](https://linear.app/brite-nites/issue/BC-10190) — registered as v1 in [BC-11930](https://linear.app/brite-nites/issue/BC-11930))
**Supersedes (in part):** [`handbook/marketing/go-to-market/campaign-lifecycle.md`](https://github.com/Brite-Nites/handbook/blob/main/marketing/go-to-market/campaign-lifecycle.md) § 2 — Touchpoint Frequency (handbook-side back-pointer to land via follow-up PR)
**Related ADRs:** [ADR-008](008-tam-mapping-enrichment-pluggability.md), [ADR-013](013-gtm-three-layer-split.md), [ADR-016](016-gtm-plugin-side-canonicals.md), [ADR-017](017-gtm-offer-posture-rename.md)
**Related issues:** [BC-10191](https://linear.app/brite-nites/issue/BC-10191), [BC-10192](https://linear.app/brite-nites/issue/BC-10192), [BC-10198](https://linear.app/brite-nites/issue/BC-10198)

> **Brite fiscal year = calendar year.** Q1 = Jan-Mar, Q2 = Apr-Jun, Q3 = Jul-Sep, Q4 = Oct-Dec. Rules 3 and 4 reference Q2 (Apr-Jun) and Q1-Q2 (Jan-Jun) under this convention.

## Context

Brite Labs operates a milestone-driven outbound model (`Brite GTM` Linear project, ~25 vertical × offer × month campaigns per fiscal year). The rules that protect the TAM from over-saturation — preventing the same prospect, persona, or vertical from being hit too many times in any window — are real and operator-enforced, but split across three surfaces with inconsistent precision:

- **Handbook** — [`handbook/marketing/go-to-market/campaign-lifecycle.md`](https://github.com/Brite-Nites/handbook/blob/main/marketing/go-to-market/campaign-lifecycle.md) § 2 (Touchpoint Frequency) is the closest existing canonical source. It states: *"No prospect receives more than two cycles per year, regardless of vertical or offer mix... Cycle-to-cycle gap defaults to roughly six months."* It also defines an exception: *"a once-in-a-decade external moment... may justify a third cycle for the affected cohort in that year only."* The handbook is operator-facing; it does not specify enforcement, suppression mechanics, or per-vertical exception schemas.
- **`prospect-temporal-gate` skill** (`plugins/marketing/skills/prospect-temporal-gate/SKILL.md`, published v0.3.22 as DRAFT) — encodes Rules 1-4 below in Phase 5 suppression logic + Phase 7 halt gates. The skill is the enforcement layer but it predates the handbook reconciliation; its rule text and the handbook's drift.
- **Operator memory** — the calendar-year vertical offer-rotation discipline (Rule 5) lives only in planning conversations. The handbook does not address per-vertical offer rotation; it addresses per-prospect touchpoint count.
- **A planned-but-not-yet-written** `handbook/marketing/go-to-market/campaign-rules.md` — referenced from BC-10192 (`campaign-calendar` skill) as a future consolidated rules page. **This file does not currently exist in the handbook repo** (`gh api repos/Brite-Nites/handbook/contents/marketing/go-to-market/campaign-rules.md` returns 404 as of 2026-05-28). This ADR is the **precondition** for that page — once accepted, a follow-up handbook PR creates `campaign-rules.md` as a back-pointer to ADR-023.

Three failure modes follow:

1. **Skill drift.** [BC-10191](https://linear.app/brite-nites/issue/BC-10191) (`offer-catalog`) and [BC-10192](https://linear.app/brite-nites/issue/BC-10192) (`campaign-calendar`) will re-implement subsets of these rules without a single source of truth.
2. **No CI-readable contract.** New campaigns can violate the rules at `/marketing:plan-campaign` time with no automated check pointing at the precise rule that broke. The skill catches it at launch, but planning gets to "ready" without the check.
3. **Calendar-year drift.** The unwritten vertical-rotation rule is the easiest to silently violate as Brite grows past 27 verticals × 4+ offers per vertical. M4→M5 already showed strain (Shopping Centers, Ski Resorts, Casinos, Sports Stadiums hit ~30 days apart under different offer names).

[BC-10198](https://linear.app/brite-nites/issue/BC-10198) (SF↔EB attribution, shipped 2026-05-18) now provides `CampaignMember` history that makes rules 1–2 enforceable with higher accuracy than the prior Activity-Task pattern-match. The skill needs to consume this, but won't until the rules are agreed.

## Decision Drivers

- **Single source of truth.** One document referenced by every downstream consumer (skill, future skills, handbook, operator training).
- **Rule-statement parity.** Each rule has: a precise statement, scope, exceptions, and the enforcement layer that owns it.
- **Calendar-year discipline written down.** The fifth rule must move out of operator memory before the TAM gets large enough to make it unenforceable in heads.
- **No re-litigation.** When a downstream skill adds a per-vertical exception, it cites the ADR not its own logic.
- **Schema stability for the enforcement layer.** The `prospect-temporal-gate` skill ships against this ADR. Rule edits require an ADR amendment + skill version bump.

## Decision

Five rules apply to all outbound generated by the marketing plugin. Each is owned by the `prospect-temporal-gate` skill ([BC-11930](https://linear.app/brite-nites/issue/BC-11930) graduates it from DRAFT to v1) and re-affirmed at every `/marketing:plan-campaign` invocation.

### Rule 1 — 180-day non-repeat (prospect-level)

**Statement.** A given prospect (`email`) MUST NOT receive outbound from any Brite entity within 180 days of the most recent prior touch. Reconciles to the handbook's "roughly six months" cycle-to-cycle gap (`campaign-lifecycle.md` § 2) — the ADR pins the floor at 180 days for machine enforcement.

**Scope.** All EB workspaces (currently 55 + 13). All SF `CampaignMember` records (post-[BC-10198](https://linear.app/brite-nites/issue/BC-10198) attribution layer) and all SF `Task` Activity records of type `Email | Outbound | Sequence` (pre-BC-10198 fallback).

**Exceptions.** A vertical may publish a per-vertical exception file with `lookback_override_days: <int>` and an expiry date. Default is conservative — the 180-day floor wins unless an exception is explicitly declared. Per-vertical exception files do not yet exist in the handbook repo; the schema is introduced by this ADR for the future `handbook/marketing/go-to-market/verticals/<slug>/exceptions.md` location ([BC-10192](https://linear.app/brite-nites/issue/BC-10192) tracks the handbook backfill).

**Enforcement.** `prospect-temporal-gate` Phase 5 step 1 (email-level match → suppress). HARD-FAIL on overflow at Phase 7.

### Rule 2 — 2-cycle/year (org × persona)

**Statement.** The same `(domain, persona_class)` pair MUST NOT receive more than 2 distinct outbound cycles per fiscal year, regardless of offer naming. Reconciles to handbook `campaign-lifecycle.md` § 2: *"No prospect receives more than two cycles per year, regardless of vertical or offer mix."* This ADR refines the handbook's prospect-level rule to the operationally measurable `(domain, persona_class)` shape — a single prospect cannot be touched > 2× per year, and prospects in the same persona class at the same org are treated as the same touchable surface for the purposes of the cycle count.

**Scope.** All EB workspaces + all SF `CampaignMember` records. `persona_class` is the canonical persona slug from `plugins/marketing/data/canonicals/<vertical>.yaml` (per [ADR-016](016-gtm-plugin-side-canonicals.md) / [BC-8722](https://linear.app/brite-nites/issue/BC-8722)).

**Exceptions.**

1. **`--same-org-different-persona` flag** — permits NEW individuals at a `domain` where prior individuals were contacted, when the campaign is targeting a deliberately different buying committee. The skill flags affected rows with `same_org_new_persona = true` in `enriched_leads.csv` for audit. Use this only when the persona class differs canonically — not when it's the same persona under a different title alias.
2. **Once-in-a-decade external moment** (preserved from handbook `campaign-lifecycle.md` § 2). A national anniversary, a one-time partnership opening, or a unique market window may justify a third cycle for the affected cohort in that year only. Enforcement: the operator passes `--external-moment-override=<text>` describing the moment + the cohort's vertical/persona scope. The override is written to the suppression report and to the cohort's offer page; it expires at FY end and reverts to 2-cycle/year the next year. Without `--external-moment-override`, a third cycle HARD-FAILS at Phase 7 as before.

**Enforcement.** `prospect-temporal-gate` Phase 5 step 2/3. HARD-FAIL when neither exception flag is passed.

### Rule 3 — Enterprise-commercial-post-Q2 cutoff

**Statement.** Outbound to enterprise-commercial verticals MUST be suppressed after **June 30** of the fiscal year. The next eligible window is Q1 of the next fiscal year.

**Scope.** Enterprise-commercial = Corporate Campuses (F1000), Shopping Centers (REITs), and the chain-corporate tiers of Hotels, Casinos, Bars, Restaurants, Theme Parks. Locked corporate fiscal budgets after Q2 make these sends a guaranteed waste of sender heat.

**Not affected.** Sports Stadiums (multi-year procurement cycles — post-Q2 is the correct FY27-capex window), Auto Dealerships (SMB tier — not subject to enterprise FP&A cycle).

**Exceptions.** `--enterprise-commercial-filter=off` with `--override-reason=<text>` written to the suppression report. Operator-level override only.

**Enforcement.** `prospect-temporal-gate` Phase 5 step 5. Auto-enabled when `current_month > 6` AND the vertical resolves to the enterprise-commercial set. HARD-FAIL at Phase 7 if triggered without `--override-reason`.

### Rule 4 — Tier-1 Q1-Q2 launch window

**Statement.** Tier-1 offers (those with `tier: 1` frontmatter in the canonical offer page) MUST launch in Q1 or Q2 of the fiscal year. Any Tier-1 offer scheduled for M7–M12 is a planning error.

**Scope.** All Brite entities, all verticals. Brite Labs revenue is install-driven; Tier-1 campaigns require Q1–Q2 launch to capture the summer (Jun–Sep) install season or the Q4 holiday (Nov–Dec) season.

**Exceptions.** None. To override, the operator must either reschedule to Q1–Q2 of the next FY, or edit the offer's `tier:` frontmatter to a lower tier (which is a separate handbook PR with rationale).

**Enforcement.** `prospect-temporal-gate` Phase 5 step 6. CANNOT BE DISABLED. HARD-FAIL at Phase 7 with the offer-page path quoted.

### Rule 5 — Calendar-year vertical offer rotation (new policy)

**Statement.** A given vertical MUST NOT receive more than **N = 4** distinct offers per fiscal year across all Brite entities combined, where each offer is identified by canonical offer-slug from `plugins/marketing/data/canonicals/<vertical>.yaml`.

**Scope.** All EB workspaces + all SF `CampaignMember` records. Offers from sibling entities (Nites + Supply + Labs) count toward the same vertical's annual budget — a Botanical Garden contacted by Labs in M2 and Nites in M5 has consumed 2 of 4.

**Why N = 4.** Aligns with the 2-cycle/year rule (Rule 2) at the persona level: 2 personas × 2 cycles = 4 offer-touches max. Higher N would silently allow a single persona to receive 4 distinct offers in one FY (saturation); lower N would foreclose legitimate cross-entity coordination.

This metric is **distinct from** the handbook's "four touchpoints per prospect per year" upper bound (`campaign-lifecycle.md` § 2). The handbook counts *email touchpoints* (2 cycles × 2-email sequence per Rule § 1 in the handbook = 4 emails per prospect). This ADR's Rule 5 counts *distinct offers* per vertical, which is a higher-level unit. The two values coincidentally both equal 4 but measure different things — do not conflate.

**Exceptions.** A vertical may publish a per-vertical exception file (future `handbook/marketing/go-to-market/verticals/<slug>/exceptions.md`, same location as Rule 1 exceptions) with `annual_offer_budget: <int>` and an expiry date. The exception cap MUST be ≤ 6. Per-vertical exception files do not yet exist in the handbook repo; backfill is tracked by [BC-10192](https://linear.app/brite-nites/issue/BC-10192).

**Enforcement.** `prospect-temporal-gate` Phase 5 step 4.5 (NEW — added in [BC-11930](https://linear.app/brite-nites/issue/BC-11930)). Counts distinct `Campaign.Offer__c` values per `(domain, fiscal_year)` against the budget. HARD-FAIL at Phase 7 when budget exceeded.

> **This rule is new policy introduced by ADR-023.** Operator review must explicitly ratify the `N = 4` default before merge; downstream skills ([BC-10191](https://linear.app/brite-nites/issue/BC-10191) `offer-catalog`, [BC-10192](https://linear.app/brite-nites/issue/BC-10192) `campaign-calendar`) consume it as canonical.

## Consequences

**Positive.**

- Five rules in one place. Downstream skills cite this ADR, not each other or operator memory.
- The `CampaignMember` history from [BC-10198](https://linear.app/brite-nites/issue/BC-10198) becomes the primary data source for rules 1, 2, and 5 (the Activity-Task pattern-match becomes a pre-BC-10198 legacy fallback).
- `/marketing:plan-campaign` can now lint candidate campaigns against the rules at planning time, not just launch time — the rule statements are precise enough to mechanize.
- Calendar-year rotation moves out of operator memory before TAM growth makes it unenforceable in heads.

**Negative.**

- The `N = 4` default in Rule 5 is a judgment call. Verticals with multi-buyer-committee complexity may need an exception within the first FY. Per-vertical exception mechanism mitigates but doesn't eliminate this.
- Rules 1 and 2 partially overlap (a prospect blocked by Rule 1 is also blocked by Rule 2). The skill applies them in order; this ADR documents both because they have different scopes and different override mechanisms.
- Enforcement consolidation creates a single point of fragility: `prospect-temporal-gate` must run on every launch. The skill's HARD-FAIL discipline (Phase 7) is what protects this; degrading to advisory would re-open the gap.

**Future work.**

- **Land handbook back-pointer** — Create `handbook/marketing/go-to-market/campaign-rules.md` as a back-pointer to ADR-023. Update `campaign-lifecycle.md` § 2 (Touchpoint Frequency) to cite ADR-023 as the canonical machine-enforced statement, keeping the operator-facing prose but linking to the ADR for the precise rule text + exceptions. Handbook PR separate from this work.
- **Backfill per-vertical exception schema** — Per-vertical exception files (Rule 1 `lookback_override_days`, Rule 5 `annual_offer_budget`) referenced in this ADR do not exist in the handbook today. [BC-10192](https://linear.app/brite-nites/issue/BC-10192) (`campaign-calendar` skill) ships the schema + first verticals.
- **Planning-time enforcement** — Extend [BC-10191](https://linear.app/brite-nites/issue/BC-10191) (`offer-catalog`) and [BC-10192](https://linear.app/brite-nites/issue/BC-10192) (`campaign-calendar`) to surface ADR-023 violations at planning time, not just launch time.
- **Revisit N = 4 in Rule 5** — After one full FY of enforcement data. Adjust if per-vertical exception traffic exceeds 30% of verticals OR if the exception cap of 6 proves insufficient (both first-FY estimates).

## Alternatives Considered

**Handbook-only consolidation.** Write the rules into `campaign-rules.md` without an ADR. Rejected: handbook prose is operator-readable but not machine-citable, and the skill body would still drift over time without an immutable decision record. ADRs are append-only; handbook pages get rewritten.

**Per-skill ownership.** Let each downstream skill (`offer-catalog`, `campaign-calendar`, `prospect-temporal-gate`) own a subset of the rules. Rejected: three implementations is exactly the failure mode this ADR exists to prevent. Skills consume; this ADR specifies.

**Defer Rule 5 until violation observed.** Ship the four existing rules now, write Rule 5 when a vertical actually exceeds budget. Rejected: the absence of a budget is what makes violations invisible. M4→M5 already strained the implicit rule; an explicit budget makes the violation legible.
