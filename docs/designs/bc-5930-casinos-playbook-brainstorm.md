## Design: BC-5930 casinos vertical playbook

**Issue**: BC-5930 — Create plugins/marketing/references/vertical-playbooks/casinos.md
**Date**: 2026-04-23

### Problem

Casinos are the 4th vertical playbook (R-6 of email-copywriting preset roadmap). Fresh research required: no prior Brite casino deployments, no casino-specific vendor landscape in the session record. The casino vertical is structurally wider than zoos/hotels/ski because it spans 4 sub-types with distinct buyers, economics, and regulatory surfaces. Must not collapse them into a single generic playbook.

### Approach

Apply the proven reference-file pattern (zoos.md peer template) with three casino-specific expansions: (1) 4-way ICP breakdown with parallel primary personas per sub-type, (2) widest-possible non-gaming zone scope (F&B + hotel-attached + entertainment venues + convention + retail arcades + arrival zones), (3) 4 offer candidates, one per worldview driver (attach / visitor-per-trip / comp-rate / retention) to maximize outbound-angle test surface.

### Key Decisions

1. **ICP scope = 4 sub-types in** — tribal Class III, regional commercial, racinos, riverboat/cruise-ship. Vegas Strip + Wynn/MGM flagship out.
2. **Buyer personas = 4 parallel primaries, one per ICP sub-type** — COO/VP Ops (regional commercial), Tribal Casino GM + Tribal Council capex-gate (tribal Class III), Director of Casino Operations (racinos, excluding racing-side), Regional VP Operations (riverboat/multi-property). Director of F&B = shared secondary. VP Non-Gaming Revenue named only where title exists (Hard Rock, Penn, Boyd regional tier) — NOT default primary. Marketing + Facilities excluded per issue body.
3. **Correct issue body's over-specified buyer list** — flag as departure per BC-5922 task-2 pre-compose gate precedent (3rd instance; elevates pattern to architecture 9/10).
4. **Good zone = widest possible non-gaming footprint** — F&B + hotel-attached + in-house entertainment venues + convention space + retail arcades + arrival/parking structures all IN. Bad zone = gaming floor / pit / compliance-regulated surveillance-critical lighting.
5. **Hotels-resorts.md cross-reference** — if prospect is hotel-first with casino attached, hotels-resorts.md drives; casino-first with hotel attached, this playbook drives. Inline note in § Good-vs-bad taxonomy.
6. **Retail arcades nuance** — MK Illumination territory for shopping-corridor zones; treat MK as adjacent-competitive in retail-arcade zone specifically, adjacent-not-competitive elsewhere.
7. **4 offer candidates, each anchored to one worldview driver** — Offer A (Pilot Zone, attach-rate guarantee), Offer B (Retention Infrastructure Subscription, retention-anchor, year-round), Offer E (Production Finance, visitor-per-trip multi-zone orchestration), Offer F (new — Comp-Multiplier revenue-share on comp-budget-offset). § V1 offer picks lands the primary + tactical complement after research surfaces evidence.
8. **Mandatory MK Illumination + Moment Factory per-vertical audit** — per BC-5921 task-1 (3rd instance, elevates to architecture 9/10). Inline inversion justification in § Vendor landscape.
9. **Tribal Council capex-gate = vertical-unique archetype** — per BC-5921 task-3 precedent, document in casinos.md with inline justification (above $250K–$1M threshold varies by tribe). Do not upstream to shared vendor-landscape.md.

### Alternatives Considered

- **Single primary buyer (VP Non-Gaming Revenue per issue body)** — rejected; title is flagship-only, mis-targets 3 of 4 ICP sub-types.
- **Narrow zone scope (F&B only)** — rejected; user chose widest scope, lets research surface which zones have strongest offer fit.
- **Single offer hypothesis entering research** — rejected; user wants all 4 drivers as offer variants to test traction breadth.

### Risks & Mitigations

- **Regulatory surface in "bad zone"** — gaming-floor lighting is state-regulator / NIGC / tribal-compact-regulated. Voice rules must explicitly avoid claims adjacent to regulated surfaces. → Anti-slop rule on compliance-adjacent language.
- **Tribal sovereignty in outbound** — tribal casinos have distinct procurement protocols; cold outbound to Tribal Council is inappropriate. → Voice rule: Tribal Casino GM is primary touch; Tribal Council appears only in § Buyer personas as deal-gate context, never as outbound target.
- **4-offer surface may dilute preset composition** (BC-5934 downstream) — risk that 4-offer playbook generates too many preset variants. → Preset composition decision lives in BC-5934; playbook surfaces candidates, doesn't lock preset count.
- **Hotels-overlap edge confuses preset composition** — hotel-attached casinos vs casino-attached hotels is a gray zone. → Cross-reference note in § Good-vs-bad taxonomy; preset composition routes by prospect's self-identification (property class on 10-K, trade-press framing).
- **4-way ICP may not cleanly hold in research** — some operators span sub-types (Hard Rock = regional commercial AND tribal branding; Mohegan Sun has casino + hotel + convention; Seminole owns Hard Rock). → § ICP section explicitly flags portfolio-tier operators as multi-sub-type and defers to per-property buyer research.

### Scope Boundaries

**In scope:**
- Single new file: `plugins/marketing/references/vertical-playbooks/casinos.md`
- 9 content sections + inline citations + "How to use" footer
- MK + Moment Factory per-vertical audit with inline inversion justification
- 4 offer candidates with Hormozi / frontend / backend evaluation
- § V1 offer picks: primary + tactical complement + pending markers
- Voice rules + anti-slop rules casino-specific

**Out of scope:**
- Preset composition (BC-5934, R-12; do NOT compose casino preset files in this issue)
- Vegas Strip / Wynn / MGM-tier flagship research
- Gaming-floor / pit / compliance-regulated lighting pitches
- Marketing + Facilities as default buyer personas
- Upstreaming casino-unique archetypes to shared vendor-landscape.md (per BC-5921 task-3)
- Offer F (Comp-Multiplier) productization — playbook surfaces as candidate only; validation / legal / revenue-share accounting is separate work

### Open Questions

None. All prescribed by issue body + brainstorm checkpoints + banked precedents.
