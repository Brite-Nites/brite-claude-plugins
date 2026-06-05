# 029. Per-Account Reply-Triggered Creative Assets

**Status:** Accepted
**Date:** 2026-05-29
**Linear:** [BC-11972](https://linear.app/brite-nites/issue/BC-11972)
**Origin:** Scoping session 2026-05-28
**Related:** ADR-013 (handbook — 3-layer split: Handbook=HOW / Linear=orchestration / Plugin=WHAT), [BC-11973](https://linear.app/brite-nites/issue/BC-11973) (`creative-asset-brief` skill), [BC-11974](https://linear.app/brite-nites/issue/BC-11974) (escalation queue + n8n→Linear contract), [BC-11106](https://linear.app/brite-nites/issue/BC-11106) (Churches LP — `IndustryPageTemplate` precedent), [DRO-486](https://linear.app/brite-nites/issue/DRO-486) (Droidor storefront co-branded-PDF — related-but-distinct, NOT GTM collateral)

## Context

Brite's outbound GTM already produces **per-vertical** creative collateral through the Brite GTM project's standard campaign lifecycle — Phase 5 "GTM Asset Development" (landing pages, decks, flipbooks, email templates, one-pagers, case studies) and Phase 6 "Landing Page(s)" — tracked as milestone-scoped Linear issues (e.g. BC-7482 Bars, BC-7495 Corporate Buyers, BC-4654 Casinos LP, BC-11106 Churches LP) and owned by the Brite Labs creative team (Sarah Cullen / Max Brengle).

What has had **no** home is the **per-account, reply-triggered** asset: when a prospect sends a positive reply to a cold-outbound campaign, that specific account warrants a bespoke deliverable. Nothing in the marketing plugin or Linear scaffolds this today — `email-copywriting` emits copy-only JSON, `campaign-orchestration` is a sequencer, and the campaign `manifest.json` has no asset slot.

This ADR fixes the **policy**: what gets produced for whom, where each layer's responsibility sits, and where the artifacts live. It does **not** build the generation pipeline — that is the reply-processing-layer track (n8n), tracked separately.

## Decision Drivers

- **Designer bandwidth is the binding constraint.** Brite Labs designers (Sarah Cullen) are bandwidth-limited. Any new asset ritual must clear the bar: **"saves more designer time than it costs."**
- **Milestone-driven GTM.** Brite runs ~25 campaigns/year, one campaign per Linear milestone in the Brite GTM project. New work must hook into that model, not sit beside it.
- **ADR-013 layer discipline.** Coordination is orchestration (Linear), know-how is the Handbook, and only the reusable transform is plugin code (WHAT). Asset *generation* is neither plugin nor Linear — it is automation.
- **Reuse over rebuild.** The enterprise landing-page path is a per-company instance of the existing per-vertical `IndustryPageTemplate` (proven by BC-11106), not a new system.

## Decision

### 3.1 Routing rule

A **positive reply** to a cold-outbound campaign triggers a per-account asset, routed by segment:

| Segment | Asset | Definition |
|---|---|---|
| **Commercial** | Custom **3–5 page PDF** | Mid-market / commercial accounts — the default outbound segment. |
| **Enterprise** | Custom **landing page** | Named enterprise / strategic accounts warranting a bespoke web destination. |

Segment is carried on the lead/reply and surfaced in the `creative-asset-brief` output; it is the sole routing key.

### 3.2 Target-path convention (enterprise landing pages)

Enterprise landing pages are published on `britelabs.io` at:

```
/industry/[vertical]/[company]/[offer]
```

These instantiate the existing `IndustryPageTemplate` — the same template that backs the per-vertical pages (e.g. `/industry/churches`, BC-11106) — now parameterized **per company**. This is reuse of a proven pattern, not a new page type.

### 3.3 Escalation tiers — "auto-draft, escalate by value"

The reply-processing layer **auto-drafts** every asset. Escalation to a designer is **by value**, never by default:

- **Commercial PDF** → auto-drafted, **operator-reviewed**, shipped with **no designer touch**. Only an operator-**rejected** draft escalates to the designer queue.
- **Enterprise landing page** → auto-drafted, then **always escalates** to the designer queue (high-value, bespoke, worth designer time).

Basic commercial eye-catchers therefore never consume designer time — which is what clears the "saves more designer time than it costs" bar. The human-in-the-loop touchpoint is preserved exactly where it pays for itself.

### 3.4 Layer assignment (per ADR-013)

| Concern | Layer | Home |
|---|---|---|
| Asset **generation** | reply-processing (automation) | n8n — `brite-nites/n8n-automations` |
| **Brief contract** (copy + offer + persona + account → structured brief) | Plugin (WHAT) | `creative-asset-brief` skill, [BC-11973](https://linear.app/brite-nites/issue/BC-11973) |
| **Queue / approval / designer handoff** | Linear (orchestration) | Sub-issue under the campaign milestone, [BC-11974](https://linear.app/brite-nites/issue/BC-11974) |
| Asset **templates** (source) | brand repo | `brand.britenites` (alongside the DAM) |
| Generated asset **output** (rendered PDFs / pages) | DAM | **Brand Hub** — the canonical GTM asset library |
| **Standards / playbook** (what makes a good per-account asset) | Handbook (HOW) | handbook repo |

The marketing plugin's entire surface in this workflow is the **brief contract**. It does not generate, store, or route assets.

### 3.5 Generation approach (informative — non-binding)

The n8n track owns the generation mechanism; the following is guidance, not policy:

- **Layout stays deterministic.** A branded template is designed **once per campaign/offer** by the creative team; per reply, only *content* is personalized into it. This is the bandwidth model — designers own templates, not per-account output.
- **AI personalizes content, not design.** The `creative-asset-brief` JSON (`outline`, `copy_hooks`, `cta`, `brand_kit_refs`) is the generation input. A generative image model (e.g. Gemini 2.5 Flash Image) may produce the **eye-catcher visual only**, constrained by brand-kit reference images. Full AI-generated *design* is explicitly discouraged — it breaks brand consistency and defeats the zero-designer-touch bar.
- **Render + store.** n8n renders template→PDF (or instantiates the LP), uploads the output to the **Brand Hub**, and links the resulting shareable URL back into the Email Bison reply and (on escalation) the Linear issue. Generated outputs are **not** git-committed — they are high-volume, per-reply DAM entries.

## Phase-numbering reconciliation

The Brite GTM project description numbers creative work as **Phase 5 = "GTM Asset Development"** and **Phase 6 = "Landing Page(s)"**. However, several in-issue descriptions number themselves one step ahead (calling asset development "Phase 6"). **Canonical numbering for all new work is the project-description numbering** (Phase 5 = GTM Asset Development, Phase 6 = Landing Pages). Per-account reply-triggered assets defined here are a distinct, post-launch motion and are **not** a new lifecycle phase.

## Consequences

**Positive**

- One reusable brief contract serves both segments and both layers (plugin emits, n8n consumes) — no per-asset bespoke glue.
- Designer bandwidth is protected by construction: commercial eye-catchers are zero-touch; only enterprise + rejected drafts reach the queue.
- The layer boundary is explicit — generation lives in automation, the plugin stays a pure transform, Linear stays orchestration — so future contributors don't smear responsibilities.
- Enterprise LPs reuse `IndustryPageTemplate` instead of inventing a new page type.

**Negative / mitigations**

- **Cross-repo coordination.** Generation lives in `brite-nites/n8n-automations`, templates in `brand.britenites`, outputs in Brand Hub, orchestration in Linear. Mitigation: the brief contract (BC-11973) and the n8n→Linear contract (BC-11974) are the two stable interfaces that decouple these repos.
- **Per-account LP volume.** Unbounded enterprise LPs could sprawl on `britelabs.io`. Mitigation: the escalation gate (3.3) and the named-enterprise segment definition bound the volume; LPs are only created on a positive enterprise reply.
- **Generation approach may age.** The Gemini/template guidance (3.5) is informative; if the n8n track chooses differently, update 3.5 rather than amending the policy sections.
