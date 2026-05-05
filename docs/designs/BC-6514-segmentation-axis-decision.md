# Design: BC-6514 — Segmentation-axis architectural decision

**Issue:** BC-6514 (BC-6308 round-3 follow-up; blocks BC-6554 round-4)
**Date:** 2026-05-05
**Decision maker:** Holden Halford (project lead)

## What this document is

The architectural call for how `/marketing:launch-campaign` splits a prospect list into separate Email Bison campaigns. **Decision only** — the actual spec rewrite, metadata schema migration, and naming-convention change happen in scoped follow-up issues filed alongside this memo.

## The decision

**Default segmentation = multiplicative (ESP × email-type) on every launch.** Up to 9 campaigns per invocation (3 ESPs × 3 email-types), with the existing F12 empty-bucket prune handling sparse cells automatically.

Single opt-out flag retained: `--no-host-lookup` for tiny test launches that want one combined campaign.

## Why this call

### What changes vs today

Today's spec encodes ESP as the segmentation axis with email-type as a pre-filter (BC-6307 shipped this in PR #237). Production reality (workspace 13 screenshots, 2026-04-30) uses email-type as the axis with all ESPs lumped together. Operator's stated ideal during BC-6308 round-3 gate-2 was the multiplicative grid:

> "in a perfect world we would want to be able to do all of the above of like yes we want to segment each campaign by both ESP and email type."

### Rationale Holden cited

1. **Cleanest per-cell metrics.** Mixing email-types or ESPs within one campaign pollutes the per-segment deliverability and engagement data. The multiplicative grid isolates every combination.
2. **EmailBison takes no platform stance** ([docs.emailbison.com/campaigns/overview](https://docs.emailbison.com/campaigns/overview)): *"EmailBison takes an unopinionated approach to ESP matching. It is left to the user to decide if ESP matching or mis-matching is better for their deliverability."* The vendor leaves it to the operator; we choose maximum isolation.
3. **Multiplicative aligns with operator intent.** No tradeoff is being made against a stated preference; this is what the operator said they wanted.

### Costs accepted

- **3x setup overhead per launch.** Each campaign needs senders attached (Phase 8), a schedule (Phase 7), and a sequence (Phase 9). Multiplicative ~9 campaigns vs current ~3 means 3x of those operations.
- **More gate-2 friction.** Operator sees a 9-cell preview instead of a 3-bucket preview. Mitigation: F12 prune drops empty cells before they reach the operator.
- **More custom-variable upload churn** (Phase 3). Variables attach per campaign. 9 campaigns means 9 attach calls vs 3 today.

These costs were weighed against the metric-isolation benefit and the operator-stated ideal; the call is to absorb them.

## Alternatives considered (and explicitly rejected)

| Model | Rejected because |
|---|---|
| **Email-type axis only** (~6 per suite — matches current Brite practice in workspace 13) | Gives up ESP isolation; mixes Google + Microsoft + Other recipients per campaign. Current practice is best read as "default-via-inertia" — no marketing-team decision rejected ESP segmentation, the campaigns just got built that way. |
| **ESP axis only** (~9 per suite — current spec, Revgrowth-10 inheritance) | Gives up email-type isolation; mixes Professional + Role + Personal targets per campaign. BC-6307 added email-type as a pre-filter precisely because mixing types hurts metrics — but a pre-filter only drops leads, it doesn't isolate metrics per type. |
| **Operator picks at gate-2** (per-launch interactive choice across all three models) | Adds operator decision burden every launch; default-only with one escape hatch is leaner. The escape hatch covers the legitimate "I don't want segmentation today" case without requiring an axis-pick conversation every time. |
| **Three opt-out flags** (`--no-segment` for ESP-off, new flag for email-type-off, `--no-host-lookup` for both-off) | Belt-and-suspenders insurance considered. Two of those opt-outs would let operators silently bypass the multiplicative call into models that were rejected as defaults. Cost (more spec branches, more test scenarios, downstream-skill audit handles more cases) outweighs unforeseen-scenario insurance. |

## Supersedes BC-6307 "Alternatives Considered #2"

[BC-6307's design memo](BC-6307-phase-2-email-type-segmentation.md#alternatives-considered) explicitly considered and rejected this exact approach:

> "**Augment ESP × email-type → up to 9 buckets.** Rejected — combinatorial explosion on small lists; most segments empty in practice."

Two reasons that rejection no longer holds:

1. **F12 prune already addresses the "most segments empty" concern.** Empty buckets are dropped before campaign-create runs (launch-campaign.md Phase 2 step 4b). The operator never sees a campaign for a (Casinos, Microsoft, Personal) cell that has zero leads. The "combinatorial explosion" is bounded by the actual lead distribution, not the 9-cell ceiling.
2. **Operator preference is now explicit.** BC-6307 was reasoning under "no operator stated ideal yet" — the multiplicative model was rejected as theoretical overkill. Round-3 gate-2 reversed that: the operator stated the multiplicative grid is what they want.

This memo supersedes that BC-6307 reasoning.

## Opt-out flag set

| Flag | Behavior under multiplicative default | Status |
|---|---|---|
| (no flags) | Multiplicative — up to 9 campaigns per invocation | Default |
| `--no-host-lookup` | Skip Phase 2 entirely; 1 combined campaign | **Kept** |
| `--no-segment` | (Today: ESP off, keep email-type filter) | **Removed** — opting into a rejected model |

`--no-host-lookup` stays because tiny test launches are different work, not a different segmentation philosophy. The "30-lead one-off test" case shouldn't produce 9 mostly-empty campaigns; one combined campaign is the right shape for that work.

`--no-segment` goes away because keeping it would silently let operators bypass the multiplicative call into the rejected email-type-only model. F12 already handles the "small CSV produces some empty cells" case automatically; no manual axis-drop flag is needed.

## Naming convention preview

Current short form: `{campaign-name-base} | {ESP}` (e.g., `Denver Downtown Lighting | Google`).

Multiplicative shape: `{campaign-name-base} | {Email-type} | {ESP}` (e.g., `FY25 M11 | Casinos | Professional | Google`).

Per-axis order is email-type-then-ESP. Rationale: matches the existing workspace 13 naming pattern (`FY25 M11 | Casinos | Professional Emails | All ESPs` — email-type before ESP), so per-vertical campaign rosters in the EB campaign list group by email-type first, which is how the marketing team already reads them.

The campaign-name-base remains operator-controlled via `--campaign-name`; vertical is the operator's responsibility to bake into the base (e.g., `--campaign-name "FY25 M11 | Casinos"`). One-CSV-per-vertical convention preserved.

## Vertical handling — out of scope

Production screenshots show vertical (Casinos / Restaurants / Car Washes) as a prefix axis in campaign names. The operator pre-splits CSVs per vertical and runs `/marketing:launch-campaign` once per vertical; vertical is part of `--campaign-name`. No spec change needed.

If operators later want vertical-as-axis built into the command (one CSV with a vertical column, command auto-splits), that's a separate scoping conversation — file under "vertical-as-axis follow-up" if the need surfaces. Not in scope for the BC-6514 follow-up chain.

## Downstream skill impact summary

- **`email-copywriting`.** Today authors one body per skeleton (A or B) per offer-tier. Under multiplicative, role/personal addresses get their own campaigns — does that warrant per-email-type body variants? Likely yes for role addresses (greeting can't use FIRST_NAME for `info@` / `sales@`). Personal addresses may need lighter-handed copy. Decision deferred to the downstream-skill review follow-up issue.
- **`tam-mapping`.** Operational rule 1 already drops free-mail and role addresses before the CSV reaches launch-campaign. Under multiplicative, we may want tam-mapping to *keep* role/personal in the output and let launch-campaign Phase 2 do the bucketing — otherwise multiplicative campaigns for those email-types start empty. Decision deferred to the downstream-skill review follow-up.
- **Reporting tooling.** Per-cell roll-ups (vertical × ESP × email-type) become possible and meaningful. Out of scope for this chain; the metadata schema rewrite produces the data, downstream reporting consumes it.

## Round-4 dogfood (BC-6554) implications

Round-4's R-9 was partially-validated under the ESP-axis spec. The R-9 procedure needs a redesign to validate the multiplicative model end-to-end against workspace 13. The spec rewrite has to land before BC-6554 can run; BC-6554 is no longer blocked on architectural unknown, only on implementation.

## Scope of this branch

**This issue's deliverable:**

1. This decision memo (the call + rationale + recorded alternatives).
2. Linear follow-up issues filed for the implementation work, with scoped tasks each.
3. BC-6554 unblock-comment + relations update.

**Not in this branch:**

- The launch-campaign.md spec rewrite (Phase 2 + Phase 5 logic; lives in spec-rewrite follow-up).
- Metadata JSON schema migration (lives in metadata-migration follow-up).
- Naming-convention apply across existing eval scenarios + plan files (lives with spec-rewrite).
- email-copywriting / tam-mapping audit + any downstream changes (lives in downstream-skill review follow-up).
- R-9 round-4 procedure rewrite (lives in BC-6554 procedure update OR a dedicated R-9 follow-up).

## Precedents referenced

- **BC-6307 (PR #237)** — design memo's "Alternatives Considered #2" rejected the multiplicative model. This memo supersedes that rejection with explicit reasoning (F12 prune addresses combinatorial concern; operator preference is now stated).
- **BC-2717 task-3** — cross-skill keep-in-sync annotation. Applies to the launch-campaign ↔ tam-mapping audit deferred to the downstream-skill follow-up.
- **User delegation memory (feedback_user_delegation_scope)** — project-level architecture decisions out of operator scope; surface to project lead. Holden's call drove the decision.

## Open questions

None. Holden's directive is the call; alternatives and costs are documented; follow-ups are scoped below.
