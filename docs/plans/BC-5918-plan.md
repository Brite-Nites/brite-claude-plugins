# BC-5918 — Plan

**Issue:** [BC-5918](https://linear.app/brite-nites/issue/BC-5918) — Create `plugins/marketing/references/experiential-lighting-vendor-landscape.md`
**Branch:** `holden/bc-5918-experiential-lighting-vendor-landscape`
**Worktree:** `.claude/worktrees/bc-5918/`
**Priority:** High
**Parent roadmap:** R-2 of the 20-issue email-copywriting preset library rollout (master: `docs/designs/email-copywriting-preset-roadmap.md`). Blocks R-3 (BC-5919 SKILL cross-links) and R-4..R-9 (6 vertical-playbook issues BC-5920..5923, 5929, 5930) — same downstream cone as BC-5917.

## Goal

Create a vertical-agnostic competitive-landscape reference distilled from the BC-5879 session's deep-research findings. Covers the four experiential-lighting vendor archetypes (lantern festival producers, holiday specialty installers, projection / immersive studios, LED-retrofit vendors) with named companies, commercial models, and what each is / isn't competing on. Read by every vertical playbook (Phase 2) and every preset-composition issue (Phase 4) to avoid mis-framed competitive positioning.

## Scope

**In-scope**
- New file: `plugins/marketing/references/experiential-lighting-vendor-landscape.md`
- Cross-reference entry in `plugins/marketing/references/README.md` § Contents
- Expected-consumer entry in README.md § Expected consumers (already lists vertical-playbooks + preset-composition — extend if needed)

**Out of scope (non-goals from issue)**
- Per-vertical program economics (ticket prices, attendance — belongs in vertical playbooks)
- Offer recommendations / Brite pitch plays (belongs in vertical playbooks + preset composition)
- Verbatim copy of the zoos-ledger research-grounding block (must distill, not duplicate)
- UPSTREAM.md manifest update (this is Brite-originated, not a Revgrowth port)
- SKILL.md cross-links (that's R-3 / BC-5919)

## Design decisions

**D1. Frontmatter shape (reuse BC-5917 precedent).**
Apply the Brite-originated-reference frontmatter convention established by BC-5917 (PR #175, just-merged sibling R-1 issue):
```yaml
---
source: BC-5879 session deep-research findings (2026-04-21); public filings + trade press cited inline
license: Brite-originated; distilled from first-party session research, no upstream port
---
```
No `upstream_path:` (not a Revgrowth port). No HTML attribution comment on line 1 (reserved for Revgrowth-ported files per UPSTREAM.md convention).

**D2. No UPSTREAM.md manifest update.**
UPSTREAM.md's per-file manifest is specifically for Revgrowth1/ai-gtm-workflows ports. This file is Brite-originated, so it belongs in README.md only — same call as BC-5917.

**D3. Source citation convention.**
Issue's Task 7 requires "every numerical claim or vendor-specific fact has a source citation (URL or `inferred from X` marker)." Apply this as inline parenthetical citations in prose, not a footnote block — matches peer references' style (hidden-signals-library uses inline URLs, creative-thinking-models uses inline parentheticals). Primary source is `docs/plans/BC-5879-zoos-ledger.md § Research grounding` which cites zoo-specific examples (Denver Zoo economic-impact study, LA Zoo attendance, etc.); for claims where the ledger cites a public source (e.g. Newport $59.99 adult ticket), cite that public source; for claims inferred from the research agent without a public URL, mark `(inferred from BC-5879 session research)`.

**D4. Stated-not-competitor section.**
Issue verification explicitly demands: "No mention of S4 Lights or MK Illumination as direct competitors (both are explicitly not)." The positive framing (archetype table) is insufficient on its own — add a brief § "Explicitly adjacent, not competitive" paragraph naming S4 Lights (component manufacturer, Brite *partner* per Hogle Zoo decision) and MK Illumination (retail/urban, wrong buyer) with the structural reason each sits off the competitive map. This guards against a future skill author mis-reading the archetype table and re-adding them.

**D5. Brite-position section sourcing.**
§ "What Brite competes on" and § "When Brite wins vs loses" are synthesis — pulling from the zoos ledger § A1 Offer E decision ("Brite's edge isn't fabrication; it's production-finance orchestration + ad-monetized programmable-media infrastructure") and § Research grounding's Brite-capability-gap paragraph. Mark both sections with `(synthesized from BC-5879 zoos ledger § A1 + § Research grounding)` to trace the synthesis source.

## Tasks

Tasks are ordered by dependency. Each is ≈2-5 min.

### T1 — Create file skeleton with frontmatter + intro

- **File:** `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (new)
- **Action:** Write frontmatter (per D1) + H1 + intro paragraph.
- **H1:** `# Experiential lighting vendor landscape`
- **Intro (≤3 sentences):** Brite-originated competitive reference for outbound marketing skills working on experiential-lighting prospects across verticals (zoos, aquariums, casinos, hotels, resorts, ski resorts, stadiums, theme parks, museums, botanical gardens). Enumerates four vendor archetypes with named companies, typical project scope, commercial model, and what each does / doesn't compete on. Consumed by vertical playbooks (Phase 2 / R-4..R-9) and preset composition issues (Phase 4 / R-10..R-15) so future skill authors don't re-run the research.
- **Verify:** File exists. Frontmatter valid YAML.

### T2 — § Vendor archetypes — header + archetype 1 (Lantern festival producers)

- **Section heading:** `## Vendor archetypes`
- **Sub-heading:** `### Lantern festival producers`
- **Content:**
  - Named companies: **Tianyu Arts & Culture** (dominant incumbent; Chinese-lantern festival producers, turnkey design-build-staff with rev-share / seasonal lease), **Illuminight Lighting** (Chicago; Lincoln Park ZooLights vendor of record, 22 yrs).
  - Typical project scope: full-venue seasonal trail (Nov–Jan standard; summer Jul–Sep variants exist), animated lantern sculptures, custom fabrication, on-site crew.
  - Commercial model: Tianyu = rev-share or seasonal-lease (turnkey, vendor-owns-IP). Illuminight = mid-market fee-for-service with commercial LED strings + animated sculptures + arches/pole trees.
  - Served vs not: serves venues wanting a *ready-made narrative attraction*. Does NOT serve venues wanting programmable-media infrastructure, permanent architectural lighting, or ad-monetization-compatible installs (static lanterns can't carry ad inventory).
  - Client examples cited: Tulsa Zoo, Potawatomi Zoo, Maryland Zoo, Memphis Zoo, Saint Louis Zoo (Animals Aglow), Nashville Zoo (Zoolumination), Dallas Zoo (Illuminature), Columbus Zoo, Woodland Park (WildLanterns), Franklin Park (Boston Lights). Illuminight: Lincoln Park ZooLights.
  - Production cost anchor: ~$400K–$1M+ per season for Tianyu-tier ([inferred from Oakland Glowfari's $100K tariff hit reported in trade press] via BC-5879 session research).
- **Verify:** Section names ≥2 companies; scope + commercial model + served-vs-not all present.

### T3 — § Vendor archetypes — archetype 2 (Projection / immersive studios)

- **Sub-heading:** `### Projection / immersive studios`
- **Content:**
  - Named companies: **Moment Factory**, **Limelight Art**, **Christie Digital**.
  - Typical project scope: projection-mapping, large-scale immersive installations, narrative-driven media experiences. IALD-award territory.
  - Commercial model: fee-for-service at six- to low seven-figure per installation.
  - Served vs not: serves venues wanting *flagship storytelling attractions* that register as cultural events (Singapore Rainforest Lumina, OdySea Aquarium 360° lobby). Does NOT serve mid-market budgets, operational-lighting needs, or venues needing year-round architectural infrastructure.
  - Client examples cited: Gardens by the Bay Rainforest Lumina (Moment Factory), OdySea Aquarium 360° lobby (citation from BC-5879 session research).
- **Verify:** Section names ≥2 companies; scope + commercial model + served-vs-not all present.

### T4 — § Vendor archetypes — archetype 3 (Holiday specialty installers)

- **Sub-heading:** `### Holiday specialty installers`
- **Content:**
  - Named companies: regional commercial holiday-lighting installers (mid-market, often year-round in commercial-landscape-lighting with a seasonal pivot). Illuminight Lighting (Chicago) straddles this + lantern-festival archetype with its Lincoln Park ZooLights work — cited in both. (Generic category; specific national-brand names not surfaced by research agent — mark `(inferred category from BC-5879 session research)`.)
  - Typical project scope: deploy-uplight-takedown, string lights and LED nets, lobby displays, exterior façade washes. Seasonal footprint (Nov–early Jan), light crew.
  - Commercial model: per-event fee-for-service, install + remove + store. Low barrier to entry, fragmented regional vendor base.
  - Served vs not: serves venues wanting a *dependable seasonal refresh* at mid-market cost. Does NOT serve venues wanting narrative / animated / programmable / ad-monetized experiences, or venues that already have an incumbent holiday vendor (stickiness is high once a vendor has a season of site-access knowledge).
- **Verify:** Section names the archetype + commercial model + served-vs-not; marks categorical-level claim as inferred.

### T5 — § Vendor archetypes — archetype 4 (LED-retrofit vendors)

- **Sub-heading:** `### LED-retrofit vendors`
- **Content:**
  - Named companies: **Goodlight** (UK), **Orphek**, **EcoMedia**.
  - Typical project scope: back-of-house habitat lighting, functional LED conversion (energy efficiency), fixture replacement. Spec-driven.
  - Commercial model: product-sale (fixtures + retrofit services) with utility-rebate underwriting common. Different buyer (Facilities VP / energy manager) from the experiential-lighting buyer (Marketing / Development / Events).
  - Served vs not: serves venues on energy-reduction / capital-replacement cycles. Does NOT serve experiential-attraction budgets, narrative-driven events, or any public-facing entertainment programming.
  - **Marker:** adjacent, not competitive — included here so that skill authors understand why these vendor names surface in general research but should NOT be treated as competitors to Brite's experiential-lighting motion.
- **Verify:** Section names ≥2 companies; explicitly marks the adjacent-not-competitive framing.

### T6 — § Explicitly adjacent, not competitive (S4 / MK Illumination guard — per D4)

- **Section heading:** `## Explicitly adjacent, not competitive`
- **Content (2 paragraphs):**
  - **S4 Lights.** Component manufacturer — makes DMX-pixel light curtains, pixel trees, and programmable commercial-grade LED products. Not a vendor competitor; in fact a *Brite partnership* (per BC-5879 zoos-ledger § A3 case studies: "Brite is a partner with S4 (the DMX-pixel tree + light-curtain component manufacturer surfaced in the research)"). Brite sources from S4 when composing Offer E installations. Any future skill treating S4 as a competitor is reading the map upside-down.
  - **MK Illumination.** Retail- / urban-streetscape decorative lighting specialist. Wrong buyer and wrong motion — serves city BIDs and shopping-center operators, not experiential-venue Marketing / Development / Events teams. Surfaces in general searches for "decorative lighting at scale" but does not overlap with Brite's experiential-venue motion.
- **Verify:** Section explicitly names both S4 and MK Illumination with the structural reason each is off the competitive map.

### T7 — § What Brite competes on (per D5)

- **Section heading:** `## What Brite competes on`
- **Content (1 short paragraph + 1 bulleted list of differentiators):**
  - Opening sentence: Brite's position within this landscape is **programmable-media infrastructure + production-finance orchestration**, not fabrication scale.
  - 3 bullets:
    - **Architectural commercial programmable-media.** Color-controllable, ad-compatible, pixel-mapped installations (DMX-pixel trees + light curtains via S4 supply). Static lanterns can't carry ad inventory; retrofit LEDs can't do narrative. Brite's tech stack is built for both at once.
    - **Production-finance orchestration.** Brite can finance installation against multi-stream pipeline revenue (title sponsor + economic-dev + ad pre-commits) — capital model Tianyu can't match (turnkey-lease ties vendor to hardware depreciation, not upside) and that fee-for-service vendors structurally won't offer.
    - **Architectural commercial partnership (Hogle Zoo precedent + S4 supply).** Execution capability proven at an AZA-accredited zoo (Hogle) + component supply secured via S4 partnership + name-drop rights across S4's venue portfolio.
- **Verify:** Section names ≥3 differentiators; sourced synthesis marker present.

### T8 — § When Brite wins vs loses (per D5)

- **Section heading:** `## When Brite wins vs loses`
- **Content (2 sub-lists):**
  - **Wins when:** (a) the venue wants architectural / gateway / permanent infrastructure that earns back across multiple uses (seasonal + year-round); (b) ad-monetized programmable-media is part of the value prop; (c) production-finance relieves a capex-committee bottleneck; (d) the venue values net-revenue partnership over turnkey-expense-line vendor.
  - **Loses when:** (a) the venue wants full-venue lantern-festival fabrication scale (Tianyu's lane — Brite shouldn't chase); (b) the venue already has a deeply entrenched multi-year incumbent holiday installer + short decision window (Offer A "$25K Pilot Zone" tactical complement may still apply — flag for vertical playbook); (c) the budget is strictly energy-retrofit / facilities-driven (LED-retrofit lane, wrong buyer); (d) projection-mapping narrative-studio budget levels (Moment Factory / Christie lane, different capability tree).
  - Closing sentence: honest read — Brite wins on differentiated *commercial model + tech-stack*, loses on *fabrication-scale + narrative-studio prestige*.
- **Verify:** Section has Wins + Loses sub-lists with ≥3 items each.

### T9 — § How to use this reference

- **Section heading:** `## How to use this reference`
- **Content (2 short paragraphs):**
  - **For vertical playbooks (Phase 2 / R-4..R-9):** vertical playbooks distill this landscape against a specific venue type (zoos lens, aquariums lens, etc.). When a playbook composes § Vendor landscape for its vertical, it *pulls from* this reference and layers in per-vertical specificity (e.g., zoos-specific incumbent concentration around Tianyu; aquariums lean away from outdoor lanterns entirely). Do NOT copy-paste this reference into a playbook — distill + re-frame against the venue type.
  - **For preset composition (Phase 4 / R-10..R-15):** when composing a preset file, cite the archetype the prospect's current vendor (if any) sits in, and frame Brite's positioning against that specific archetype. If the prospect has a Tianyu-tier incumbent, Offer E production-finance is the wedge; if the prospect has a holiday-installer-only incumbent, Offer A pilot-zone may apply; if the prospect has no current experiential-lighting vendor (greenfield), Offer E fits with minimal friction.
- **Verify:** Section names both consumer contexts (playbooks + presets) with one concrete directive per.

### T10 — Cross-reference in README.md

- **File:** `plugins/marketing/references/README.md` (edit)
- **Actions (two edits in the same file):**
  1. § Contents — insert bullet alphabetically between existing entries. Current order: research-processes, creative-thinking-models, hidden-signals-library, offer-design-frameworks, shelf-life-patterns. Insert **after `hidden-signals-library.md`**:
     ```
     - `experiential-lighting-vendor-landscape.md` — Four experiential-lighting vendor archetypes (lantern festival, projection/immersive, holiday installers, LED-retrofit) with named companies, commercial models, and Brite's competitive position. Brite-originated; distilled from BC-5879 session research.
     ```
     (Insert position chosen to keep BC-5917's offer-design-frameworks entry adjacent to shelf-life-patterns rather than strictly-alphabetical — matches current doc rhythm. If user prefers strict alpha, insert after `creative-thinking-models.md` instead; confirmed at approval.)
  2. § Expected consumers — the existing line `vertical-playbooks/*.md + email-copywriting/presets/* — offer-design-frameworks` already covers this file's consumers; extend the existing bullet to include this file rather than adding a new bullet:
     ```
     - `vertical-playbooks/*.md` + `email-copywriting/presets/*` — offer-design-frameworks + experiential-lighting-vendor-landscape (apply frontend/backend checklists when proposing or composing offers; apply vendor-archetype frame when positioning Brite against the prospect's incumbent)
     ```
- **Verify:** both edits present; README still parses as valid markdown.

### T11 — Validation

- **Run:** `./scripts/validate.sh` from repo root (worktree root).
- **Expect:** exit 0. Baseline at `eab9c15` = 0 errors / 16 warnings — match it.
- **Run:** `./scripts/check-guardrails.sh --claude-md CLAUDE.md`
- **Expect:** exit 0.
- **Verify:** Both pass. If validate.sh reports new errors traceable to this PR, debug before marking T11 complete.

### T12 — Verification against issue acceptance criteria

Manual tick pass against BC-5918 verification block:
- [ ] `plugins/marketing/references/experiential-lighting-vendor-landscape.md` exists
- [ ] File contains § Vendor archetypes with all 4 categories (lantern / projection / holiday-installers / LED-retrofit)
- [ ] Each archetype lists ≥ 2 named companies with scope / commercial model / served-vs-not
- [ ] § What Brite competes on + § When Brite wins vs loses both present
- [ ] Every numerical claim or vendor-specific fact has a source citation (URL or `inferred` marker)
- [ ] No mention of S4 Lights or MK Illumination as direct competitors (both explicitly flagged as adjacent, not competitive)
- [ ] `./scripts/validate.sh` exits 0

## Verification commands (copy/paste)

```bash
cd /Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins/.claude/worktrees/bc-5918

# File exists
test -f plugins/marketing/references/experiential-lighting-vendor-landscape.md && echo OK

# All 4 archetypes present
grep -E "^### (Lantern festival producers|Projection / immersive studios|Holiday specialty installers|LED-retrofit vendors)" plugins/marketing/references/experiential-lighting-vendor-landscape.md | wc -l
# Expect: 4

# Top-level sections
grep -E "^## (Vendor archetypes|Explicitly adjacent, not competitive|What Brite competes on|When Brite wins vs loses|How to use this reference)" plugins/marketing/references/experiential-lighting-vendor-landscape.md | wc -l
# Expect: 5

# S4 / MK explicitly-not-competitive guard
grep -E "S4 Lights.*partner|MK Illumination.*(retail|urban|wrong buyer)" plugins/marketing/references/experiential-lighting-vendor-landscape.md | wc -l
# Expect: >= 2

# Full validation
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

## Non-goals + tripwires

- Do NOT include per-vertical program economics (ticket prices, attendance benchmarks — those live in vertical playbooks, not this landscape reference).
- Do NOT make offer recommendations or Brite pitch plays (those live in vertical playbooks + preset composition).
- Do NOT copy the BC-5879 zoos-ledger § Research grounding block verbatim — distill into archetype structure.
- Do NOT add to UPSTREAM.md's per-file manifest (Revgrowth-port only).
- Do NOT treat S4 Lights or MK Illumination as competitors anywhere in the file — § "Explicitly adjacent, not competitive" exists specifically to lock this in.
- Do NOT update `email-copywriting/SKILL.md` — that's BC-5919 / R-3.
- **Worktree absolute-path discipline (memory gotcha_write_tool_worktree_path):** every Write/Edit MUST use `/Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins/.claude/worktrees/bc-5918/...` — never the primary checkout path.

## Dependencies + follow-ups

- Unblocks on merge: BC-5919 (SKILL cross-links — now has both of its reference-file blockers satisfied), BC-5920-5923, BC-5929, BC-5930 (6 vertical playbooks — now have both R-1 and R-2 available for reference).
- Sibling (parallel R-1, already shipped): BC-5917 offer-design-frameworks.md (PR #175, merged eab9c15).
- Follow-up (not in this PR): once S4 customer list arrives (BC-5939 R-17), revisit the S4-partnership framing in § Explicitly adjacent, not competitive to replace generic "S4's venue portfolio" with specific named venues.
