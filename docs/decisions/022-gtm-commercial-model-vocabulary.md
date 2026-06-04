# 022. GTM `commercial-model` — campaign-level economic-axis vocabulary

**Status:** Accepted
**Date:** 2026-06-04
**Linear:** [BC-12392](https://linear.app/brite-nites/issue/BC-12392) (originated in a `/grill-with-docs` design session, 2026-06-04)
**Related ADRs:** [ADR-017](017-gtm-offer-posture-rename.md) (offer-posture — the *orthogonal* economic axis), [ADR-016](016-gtm-plugin-side-canonicals.md) (plugin-side canonicals), [ADR-015](015-gtm-sigma3-sf-campaign-sync.md) (σ3 SF Campaign sync), [ADR-014](014-gtm-salesforce-portfolio-rollup.md) (SF Campaign portfolio rollup)
**Companion docs:** `handbook:marketing/go-to-market/templates/concept-library-issue-template.md` (canonical concept template — defines the field), `handbook:marketing/go-to-market/templates/milestone-description-template.md` (the at-promotion home — *Commercial model* header field), [`plugins/marketing/commands/capture-idea.md`](../../plugins/marketing/commands/capture-idea.md)

## Context

`/marketing:capture-idea` (BC-12391) introduced a 6-value **commercial-model** axis — how money would change hands for a concept (`install-fee` / `rev-share` / `ticketed` / `sponsor` / `co-invest` / `hybrid`) — as a free-text, concept-tier **guess**. It is orthogonal to **offer-posture** (ADR-017): posture is *offer-intrinsic* (how we frame the ask — knowledge / free-asset / pilot / risk-reversal); commercial-model is *how the deal is monetized*, which can vary per campaign for the **same** offer (a lighting install can be `install-fee` for one client and `rev-share` for another).

Two gaps surfaced (the second flagged P3 by the cdr-compliance reviewer during BC-12391's review, 2026-06-02):

1. **No decision record defines the vocabulary.** When a concept promotes and the economics harden into a canonical / Salesforce field, there is no ADR/CDR fixing the values, their canonical spelling, or the mapping target. Promotion tooling would otherwise consume an undefined vocabulary.
2. **Spelling had drifted across surfaces** — a live bug. The command flag (and brite-gtm's `milestone-template.md`) used `ticketed` / `rev-share`; the `[CONCEPT LIBRARY]` milestone description and the handbook `concept-library.md` page used `ticket` / `rev share`. A reader copying `--commercial-model ticket` off the page passes an **invalid** flag value.

## Decision Drivers

- **Spelling drift was a real defect** (an invalid flag value reachable by copy-paste). The canon must be one set, and it must be what the tooling already accepts.
- **The two GTM economic axes should share one decision system.** offer-posture lives as ADR-017; verdict vocabularies as ADR-018. commercial-model is the sibling economic axis — co-locating it keeps the two axes discoverable together. The handbook's CDRs are broad org/Linear standards; this is GTM-operational vocabulary closer to the plugins-side canon.
- **It's a distinct axis from offer-posture and must be recorded as such** to prevent future conflation.
- **It will harden into a canonical/SF field at promotion** — the target must be declared before tooling consumes it, but not built before anything reads it.

## Decision

### 1 — The six canonical values + spelling

| Canonical slug | Display | Meaning |
|---|---|---|
| `install-fee` | Install fee | Fixed install fee (Brite Nites default; often *+ annual renewal* — a descriptive elaboration, **not** a separate value) |
| `rev-share` | Rev-share | Revenue split with the venue / partner |
| `ticketed` | Ticketed | Per-ticket / per-use revenue (kiosks, walkthroughs, micro-attractions) |
| `sponsor` | Sponsor | Brand-sponsorship funded |
| `co-invest` | Co-invest | Shared capital investment (Brite Labs default, per Canyons deck p17) |
| `hybrid` | Hybrid | A mix of the above |

The **kebab-case slug** is canonical: it is both the `/marketing:capture-idea --commercial-model <value>` flag form **and** the future Salesforce picklist API name. The **display** form (title-case) is for prose/templates. Only the **slug** is normative across bound surfaces; display capitalization and prose hyphenation are surface-local (e.g. `/marketing:capture-idea` renders the field lowercase in its parsed-body output). This resolves the drift: **`ticket` → `ticketed`** and **`rev share` → `rev-share`** (the two outliers move to what the flag already accepts; the command and brite-gtm's doc were already correct).

### 2 — Scope: a campaign-level economic axis (≠ offer-posture)

- **Concept tier** — a free-text guess (capture-idea field #7); blank is allowed (it drives `[Sketch]` status).
- **Promotion** — hardens into a **decision**: the *Commercial model* header field of the tier-2 `milestone-description-template.md` (and one of the five promotion criteria, "Commercial model decided").
- It is **not** an offer-canonical attribute like offer-posture. The same canonical offer can carry different commercial models across campaigns, so it is recorded per **campaign/milestone**, not on the offer.

### 3 — Mapping target (DECLARED, not built)

The eventual hardened home is a **Salesforce Campaign picklist** (e.g. `Commercial_Model__c`) whose API names are the six kebab slugs above. This ADR **declares** that target; it does **not** provision it. Provisioning is gated on real promotion-tooling need — there is **no consumer today** (capture-idea writes free text; nothing reads an SF commercial-model field). When built, it follows the σ3 SF Campaign sync pattern (ADR-015) over the plugin-side-canonical source model (ADR-016): the canonical value flows concept → milestone → SF Campaign. Until then, the field lives as free text at concept tier and as the *Commercial model* header field at milestone tier.

### 4 — Bound surfaces (kept in slug-lockstep with this ADR; display rendering is surface-local)

`capture-idea.md` (flag enum + body) · handbook `concept-library-issue-template.md` (canonical) + `concept-library.md` page · handbook `milestone-description-template.md` *Commercial model* field · the `[CONCEPT LIBRARY]` milestone description · (future) the SF Campaign picklist. Any value add/rename updates this ADR first.

## Consequences

- The `[CONCEPT LIBRARY]` milestone description + handbook `concept-library.md` page spellings are corrected (`ticket` → `ticketed`, `rev share` → `rev-share`) in the BC-12392 handbook PR.
- The handbook tier-2 `milestone-description-template.md` gains a **Commercial model** header field — the at-promotion home this ADR's mapping story depends on.
- `capture-idea.md` cross-cites this ADR; **no behavior change** (it already emitted the canonical spelling).
- When promotion tooling needs the SF field, a follow-up provisions `Commercial_Model__c` per §3 (separate ticket; no Salesforce metadata changes in BC-12392).
- `multi` / `unsure` **brand-fit** is a *separate* axis (brand fit, not commercial-model); it is handled in the same BC-12392 work but is **not** governed by this ADR.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| A CDR in the handbook instead of a plugins ADR | Splits it from its sibling offer-posture ADR (017) and the SF-mapping ADRs (014/015); hurts discoverability of the two economic axes together. Handbook CDRs are broad org/Linear standards, not GTM-operational vocabulary. |
| Canonicalize on `ticket` / `rev share` (the page spelling) | Would force a change to the working `--commercial-model` flag and the brite-gtm doc; `ticket` reads as a noun (a single ticket) vs. the others being model-descriptors. |
| Build the SF `Commercial_Model__c` picklist now | Speculative — nothing consumes it yet; pulls in the brite-salesforce repo + a sandbox→prod deploy; the exact field shape (single-select, record-type scoping) is best decided by whoever builds promotion tooling. |
| Model commercial-model as an offer-canonical attribute (like offer-posture) | Wrong altitude — it is deal-level, not offer-intrinsic. The same offer carries different commercial models across campaigns, so it belongs on the campaign/milestone, not the offer. |

## Cross-references

- ADR-017 — offer-posture: the orthogonal, **offer-intrinsic** economic axis (knowledge / free-asset / pilot / risk-reversal)
- ADR-016 — plugin-side canonicals: the source-of-truth model the future SF sync rides
- ADR-015 — σ3 SF Campaign sync: the eventual mapping mechanism
- `handbook:marketing/go-to-market/templates/concept-library-issue-template.md` — canonical concept template (the field's source of truth)
- `handbook:marketing/go-to-market/templates/milestone-description-template.md` — *Commercial model* header field (at-promotion home)
- BC-12392 — this ADR's originating ticket (canonical concept template + brief-template reconcile + this vocabulary)
- BC-12391 — `/marketing:capture-idea` (introduced the vocabulary)
