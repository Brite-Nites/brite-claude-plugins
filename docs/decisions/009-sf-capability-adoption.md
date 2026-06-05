# 009. Salesforce Capability Adoption Framework

**Status:** Accepted
**Date:** 2026-04-26
**Linear:** [BC-5786](https://linear.app/brite-nites/issue/BC-5786)
**Origin:** `docs/plans/revops-plugin-master-plan.md` §6 Issue 0.3
**Related:** [ADR-007](007-revops-plugin-design.md), [ADR-023](023-sf-capability-adoption-artifact-class.md) (extends this framework with a per-class reading for non-MCP artifacts — CLI plugins, skill libraries), [BC-5534](https://linear.app/brite-nites/issue/BC-5534), [BC-5787](https://linear.app/brite-nites/issue/BC-5787), [BC-5789](https://linear.app/brite-nites/issue/BC-5789), [`salesforce-mcp-findings.md`](../research/salesforce-mcp-findings.md), [`tam-map-port-policy.md` §1](../research/tam-map-port-policy.md)

## Context

Salesforce ships major capability announcements (Headless 360 in April 2026, Data 360 prior, Agentforce before that) and each one triggers an ad-hoc "is this relevant to Brite?" derivation from scratch. The reasoning involves cross-cutting concerns — runtime model, license, plugin-budget, context-budget, GA posture, domain fit — that are easy to forget when a particular announcement is generating noise. Without a framework we risk both adopting capabilities we shouldn't (license/runtime mismatch) and missing capabilities we should (no standing monitor for GA gating).

## Decision Drivers

- **Recurring evaluation cost** — three SF capability decisions (Headless 360, ADLC fork, @salesforce/mcp 0.31+) each re-derived adoption logic from scratch
- **Plugin-budget and context-budget are first-class concerns** — soft cap of ~5–6 MCP servers per plugin (advisory) needs explicit measurement
- **Brite's GA-only posture ([BC-5534](https://linear.app/brite-nites/issue/BC-5534) Q2: Non-GA gating)** — must apply consistently across plugins

## The Six Checks

### 1. Runtime Model check

**Question:** Is this capability built for agents running INSIDE Salesforce's Agentforce runtime, or for external MCP consumers like us?

**Pass:** External-MCP-consumer-friendly (e.g., `@salesforce/mcp` data/metadata/testing toolsets).

**Fail:** Agentforce-runtime-only (capabilities that assume Apex callouts, server-side prompt templates, or in-platform agent execution).

### 2. License check

**Question:** Is the artifact commercial-safe for Brite's use?

**Pass:** MIT, Apache 2.0, BSD, ISC, CC0.

**Fail:** CC BY-NC, GPL with copyleft concerns, proprietary EULA, custom non-commercial.

### 3. Plugin Slot check

**Question:** Do we have MCP-server budget for this in the target plugin?

**Constraint:** Soft cap ~5–6 servers per plugin (advisory). User-level registrations don't count toward the cap.

**Method:** Measure startup-latency Δ (`< 2s`) and context-budget Δ (`< 500 tokens`) against a clean-session baseline before merge. Methodology in `docs/research/tam-map-port-policy.md` § 1.

### 4. Toolset Breadth check

**Question:** What's the tool-schema context cost of adding this toolset?

**Method:** Count tools × average schema size; compare to existing toolsets registered in the plugin's `.mcp.json`.

**Reject signal:** A toolset that doubles the plugin's tool count for marginal value, or whose addition would push the plugin's whole-MCP-server context-budget delta past the `< 500 tokens` threshold from check 3 (schemas + init + boilerplate combined, not schemas alone).

### 5. GA Gate check

**Question:** Is the capability Generally Available, or beta/pilot/closed-preview?

**Brite posture ([BC-5534](https://linear.app/brite-nites/issue/BC-5534) Q2 — Non-GA gating):** GA-only. Reject beta/pilot adoption even when the feature is compelling.

**Allowed exception:** Standing monitoring (e.g., BC-5787) for capabilities expected to land in upcoming GA releases — monitor without adopting until GA.

### 6. Domain Fit check

**Question:** Is this SF *development* tooling or SF *data consumption* tooling, and does that match Brite's actual work?

**Brite SF work today:** primarily SF development (metadata, Apex, Flows, deploys, testing) in `brite-salesforce`, with a thin data-consumption surface (audience views, lead enrichment) exposed via the marketing plugin.

**Reject signal:** A capability that solves a problem Brite doesn't have (e.g., Industries Cloud verticalization, Vlocity integration, Data Cloud customer-360 features outside our enrichment pipeline).

## Worked Examples

### Example 1 — Headless 360 announcement (TDX 2026, 2026-04-15) → REJECTED via Runtime Model

Salesforce announced "60+ new MCP tools + 30+ preconfigured coding skills" for Agentforce at TDX 2026. The coding skills run inside SF's Agentforce runtime (Apex callouts, server-side execution), not via external MCP. Check 1 (Runtime Model) fails: Brite's agents are external MCP consumers via `@salesforce/mcp`. Decision: skip Headless 360 server-side coding skills entirely. Standing monitor (BC-5787) tracks landing of any toolsets that DO expose tools to external consumers; those are re-evaluated against the framework when they land.

### Example 2 — Jaganpro/sf-skills ADLC variant → REJECTED via License

The ADLC fork of sf-skills offered a richer skill set than the MIT main branch but was licensed CC BY-NC (non-commercial). Check 2 (License) fails: Brite is a commercial entity. Decision: ported from main branch (MIT) only — 13 retained skills, 22 out of scope, 7 consulting agents out of scope. Captured in BC-5789 audit decisions and ADR-007 § 3.5.

### Example 3 — @salesforce/mcp 0.31+ adoption → GATED via GA

The Headless 360 announcement (TDX 2026-04-15) promised tools landing in `@salesforce/mcp` 0.31+. Per BC-5534 Appendix A and master-plan §2.1, the latest npm release at framework filing was 0.30.5. Check 5 (GA Gate): we don't auto-adopt on version bump. Standing monitor (BC-5787) re-runs the BC-5534 Appendix A inventory diff when a new GA version lands; if new tools pass checks 1–4 and 6, they're adopted. Decision: pinned at 0.30.5; revisit on landing.

## Consequences

**Positive**

- Future SF capability announcements get evaluated against a fixed checklist instead of ad-hoc reasoning each time
- Plugin-budget and context-budget concerns become first-class checks rather than afterthoughts that surface in code review
- GA-only posture is enforced consistently, not selectively
- Worked examples make the framework usable for any team member (not just the engineer who happened to derive it)

**Negative / mitigations**

- Rigid framework risks rejecting genuinely valuable capabilities — mitigated by treating it as a structured prompt, not a hard gate; any check that fails should produce an explicit override note rather than silent skip
- Worked examples may age as SF's product taxonomy evolves — refresh when an example is materially superseded (e.g., if Agentforce runtime opens to external consumers, Example 1 needs revisiting)
- Six checks may be incomplete — add a seventh check via a follow-up ADR rather than amending this one in place

