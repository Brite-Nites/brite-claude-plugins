# BC-11972 — Author ADR-021: per-account reply-triggered creative-asset policy

**Issue:** [BC-11972](https://linear.app/brite-nites/issue/BC-11972) (High, Brite Skill Packs)
**Type:** Documentation / decision record. No code, no MCP, no version bump (ADR doc + CLAUDE.md index line only).
**Source:** Scoping session 2026-05-28. All policy decisions already settled — this transcribes them into the ADR format.

## Scope

Author one ADR (`docs/decisions/021-per-account-reply-triggered-creative-assets.md`) and add its index line to `CLAUDE.md`. Modeled on ADR-009/008 format (ADR-020 not yet on disk).

## Tasks

### Task 1 — Write `docs/decisions/021-per-account-reply-triggered-creative-assets.md`

Header block (per ADR-009 format):
- `# 021. Per-Account Reply-Triggered Creative Assets`
- **Status:** Accepted · **Date:** 2026-05-29 · **Linear:** BC-11972
- **Origin:** scoping session 2026-05-28
- **Related:** ADR-013 (handbook — 3-layer split), BC-11973 (creative-asset-brief skill), BC-11974 (escalation queue + n8n contract), BC-11106 (Churches LP / IndustryPageTemplate precedent), DRO-486 (Droidor co-branded-PDF — related-but-distinct)

Body sections:
1. **Context** — per-vertical collateral already scoped (Brite GTM Phase 5/6, BC-7482/4654/11106…); the gap is per-**account**, reply-triggered assets. Generation lives at the n8n reply-processing layer, not the plugin.
2. **Decision Drivers** — bandwidth-constrained Brite Labs designers (Sarah Cullen); "saves more designer time than it costs" bar; milestone-driven GTM model (~25 campaigns/yr); ADR-013 layer discipline.
3. **The Decision** — four sub-parts:
   - **3.1 Routing rule** — commercial positive reply → custom 3–5pg PDF; enterprise positive reply → custom landing page. Define commercial vs enterprise segment.
   - **3.2 Target-path convention** — enterprise LP at `/industry/[vertical]/[company]/[offer]` on britelabs.io, reusing `IndustryPageTemplate` (per-vertical pattern from BC-11106, now per-company).
   - **3.3 Escalation tiers ("auto-draft, escalate by value")** — n8n auto-drafts; commercial eye-catchers ship operator-reviewed with NO designer touch; only enterprise LPs + operator-rejected commercial drafts enter Sarah's Linear queue (HITL gate).
   - **3.4 ADR-013 layer-assignment table** —
     | Concern | Layer | Home |
     |---|---|---|
     | Asset generation | reply-processing | n8n (brite-nites/n8n-automations) |
     | Brief contract | Plugin (WHAT) | creative-asset-brief skill (BC-11973) |
     | Queue / approval | Linear (orchestration) | sub-issue under campaign milestone (BC-11974) |
     | Standards / playbook | Handbook (HOW) | handbook repo |
4. **Phase-numbering reconciliation** — canonical: Brite GTM Phase 5 = "GTM Asset Development", Phase 6 = "Landing Page(s)"; in-issue descriptions number one step ahead — document canonical numbering.
5. **Consequences** — Positive (reusable brief contract, designer bandwidth protected, clear layer boundary) / Negative + mitigations (n8n track is separate repo coordination; per-account LP volume risk → escalation gate bounds it).

### Task 2 — Add ADR-021 index line to `CLAUDE.md`

Insert after line 40 (the ADR-009 entry) in the `## Architecture Decisions` list:
`- [ADR-021: Per-account reply-triggered creative assets](docs/decisions/021-per-account-reply-triggered-creative-assets.md) — commercial→PDF / enterprise→LP routing, auto-draft-vs-escalate tiers, ADR-013 layer split`

### Task 3 — Verify

- `./scripts/validate.sh` passes.
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` passes (CLAUDE.md size/anti-slop).
- Confirm the new ADR's relative links resolve and the CLAUDE.md line renders.

## Acceptance Criteria (from BC-11972)

- [ ] `docs/decisions/021-*.md` exists in ADR format.
- [ ] Routing rule stated unambiguously with segment definitions.
- [ ] Target-path convention documented, cross-referencing IndustryPageTemplate + BC-11106.
- [ ] Escalation tiers documented with the "saves more designer time than it costs" bar as the criterion.
- [ ] ADR-013 layer-assignment table included.
- [ ] Phase 5/6 numbering reconciliation captured.
- [ ] CLAUDE.md Architecture Decisions list cites ADR-021.

## Out of scope

n8n automation, PDF/LP generation, britelabs deploy (reply-processing-layer track — brite-nites/n8n-automations). The creative-asset-brief skill (BC-11973) and the queue (BC-11974) are separate issues.
