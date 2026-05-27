# Email-Copywriting Preset Library — Design + Roadmap

**Status:** Active. Spawned from BC-5879 on 2026-04-21 after session discovery that the original "fan out 10 preset files" scope was structurally wrong — each vertical needs research, offer design, and framework application before preset composition. This roadmap replaces the original BC-5879 scope.

**Session source:** This doc was produced in a single session with deep research (zoo/aquarium vendor landscape), offer-design framework application (Hormozi / Brunson / Abraham), and architecture decisions that now inform every spawned issue.

## Issue ID mapping

All 20 issues filed in Linear (team: Brite Company, milestone: Marketing Plugin v0.1 — GTM Workflows (Revgrowth)).

| Roadmap ID | Linear ID | Status |
|---|---|---|
| R-1 | BC-5917 | Filed |
| R-2 | BC-5918 | Filed |
| R-3 | BC-5919 | Filed |
| R-4 | BC-5920 | Filed |
| R-5 | BC-5929 | Filed |
| R-6 | BC-5930 | Filed |
| R-7 | BC-5921 | Filed |
| R-8 | BC-5922 | Filed |
| R-9 | BC-5923 | Filed |
| R-10 | BC-5932 | Filed |
| R-11 | BC-5933 | Filed |
| R-12 | BC-5934 | Filed |
| R-13 | BC-5935 | Filed |
| R-14 | BC-5936 | Filed |
| R-15 | BC-5937 | Filed |
| R-16 | BC-5938 | Filed |
| R-17 | BC-5939 | Filed |
| R-18 | BC-5940 | Filed |
| R-19 | BC-5941 | Filed |
| R-20 | BC-5942 | Filed |

## Background (why this roadmap exists)

BC-5879 was originally "fan out 10 Active-tier Nites preset files" following the BC-5825 skeleton/skin split. Session discovery invalidated that scope:

1. **Operator-driven vertical re-pick.** The 5 Active-tier Nites verticals were swapped for 5 Labs-experiential verticals (Zoos, Aquariums, Casinos, Hotels & Resorts, Ski Resorts, Sports Stadiums) based on actual pipeline warmth rather than handbook tier discipline.
2. **Vendor-landscape research reshaped the offer.** A deep-dive research agent surfaced Tianyu Arts & Culture as the dominant zoo/aquarium experiential-lighting incumbent (not S4 Lights or MK Illumination, as assumed). Brite Labs has zero indexed zoo work EXCEPT Hogle Zoo; Brite has a partnership with S4 Lights; the commercial model for a competitive wedge is substantially different than a traditional fee-for-service pitch.
3. **Framework application is non-optional.** Offer design without a Hormozi value-equation lens (and Brunson frontend/backend structure, Abraham risk-reversal) produces consultant-speak that reads as vendor-desperate. Every v1 preset needs an offer picked through these frameworks, not ad-hoc intuition.
4. **Research + frameworks belong in `references/`.** Session-scoped ledgers don't help future plugin work. `plugins/marketing/references/` is the durable home for distilled research and offer-design frameworks.
5. **Zoos and Aquariums are structurally different enough to warrant separate verticals.** Zoos = outdoor, million-LED trails, $20 family ticket, seasonal programs. Aquariums = indoor, tank overlays, $50+ 21+ tickets, summer Glow Nights or holiday events. Split decision 2026-04-21: combined vertical → two separate verticals (`zoos`, `aquariums`). Preset file count rises from 10 → 12 minimum (6 verticals × 2 preset types).

## Scope (authoritative decisions all issues inherit)

- **Verticals covered:** Zoos, Aquariums, Casinos, Hotels & Resorts, Ski Resorts, Sports Stadiums. All Labs entity.
- **Preset types:** `list-building` (T2-framed free asset) + `risk-reversal` (T4-framed guarantee). 2 preset types per offer.
- **Multi-offer variants per vertical:** allowed via filename convention `{preset}-{vertical}-{offer-slug}.md`. Default = `{preset}-{vertical}.md` = primary offer. Operator passes synthetic slug (e.g. `vertical: zoos-pilot-zone`) to select variant at runtime. Zero skill-code change required.
- **Offer design required per vertical.** Each vertical's playbook issue produces 2-4 offer candidates with Hormozi / frontend / backend evaluation. Operator picks v1 offers from the candidates.
- **Case studies:** Hogle Zoo is the named zoo case study. S4 partnership = component supply + future name-drop (pending customer-list retrieval). No other Brite case studies at zoos; aquariums case-study base is TBD per aquariums playbook.
- **Voice rule (operator-corrected):** Don't over-specify incumbent vendor type in body copy. Use "existing lighting vendor", "incumbent", "current seasonal-program vendor" — not "lantern vendor" / "projection vendor" / specific sub-category. Research-anchored specificity reads as regurgitation.
- **Cold outbound first-touch.** All presets optimized for first-contact email to prospect who's never heard of Brite. Not warm nurture. 2-step sequence format (step 1 + step 2 bump). US-only ICP for v1.

## Dependency graph

```
Phase 1 (foundations — parallel within phase):
  R-1 offer-design-frameworks.md  R-2 experiential-lighting-vendor-landscape.md
             \\                         /
              R-3 email-copywriting SKILL.md cross-link update

Phase 2 (vertical playbooks — all blockedBy R-3, parallel within phase):
  R-4 zoos playbook   R-5 aquariums playbook   R-6 casinos playbook
  R-7 hotels playbook R-8 ski playbook         R-9 stadiums playbook

Phase 4 (preset composition — each blockedBy its vertical's playbook):
  R-10 zoos presets (E + A)   R-11 aquariums presets   R-12 casinos presets
  R-13 hotels presets         R-14 ski presets         R-15 stadiums presets

Phase 5 (ship readiness — blockedBy all of Phase 4):
  R-16 anti-slop + validate.sh + check-guardrails + README manifest

Phase 6 (follow-ups — no blocking relationship, parallel to everything):
  R-17 S4 customer list   R-18 Hogle verification
  R-19 Facilities-VP motion confirmation   R-20 Multi-offer scope decision
```

## Standardized issue template (enforced across all 20 issues)

Every issue body uses this exact structure. Verification agent rejects any issue that deviates.

```markdown
## Goal
<one paragraph: what + why>

## Context
<background reproduced in-issue — no session-knowledge assumptions. Link to roadmap + references + ledgers.>

## Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read <exact file paths>. Check `CLAUDE.md` + `memory/MEMORY.md`.
2. **Plan** — Before any work, run `TaskCreate` with one task per numbered Task below. Update status in_progress / completed as you go.
3. **Execute** — Work tasks in order. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every item in Verification against objective pass/fail.

## Tasks
1. ...
2. ...

## Verification (objective pass/fail)
- [ ] <testable — file exists, grep returns X, validate.sh exits 0, field matches regex>
- [ ] ...

## Non-Goals
- ...

## Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap
- <other specific paths>
```

## Verification agent rubric (per-issue scoring)

7 categories, 0-10 each. Pass = all ≥ 7 AND overall average ≥ 8.5. Fail = revise + re-verify (max 3 attempts, then escalate to operator).

1. **Template compliance** — All 7 sections present and correctly formatted.
2. **Verification objectivity** — Every checkbox is testable (file exists / grep returns X / validate.sh exit 0 / field matches regex). Zero subjective checks.
3. **Execution Protocol rigor** — Explore step names exact files; Plan step requires `TaskCreate`; Execute tells agent to stop-and-ask on ambiguity; Verify references the checkbox list.
4. **Self-containment** — A fresh agent with zero session context could execute. Context section reproduces all relevant decisions; no "per our earlier discussion".
5. **Dependency correctness** — blockedBy and blocks fields match the roadmap graph; related-to used for non-blocking links.
6. **Scope discipline** — Single-purpose; one deliverable category; matches the roadmap slot.
7. **Source paths** — Every referenced file path resolves (exists on disk OR explicitly annotated "will be created by R-X").

---

## Phase 1 — Foundations

### R-1. Create `plugins/marketing/references/offer-design-frameworks.md`

**Phase:** 1
**Priority:** High
**Labels:** infrastructure
**blockedBy:** none
**blocks:** R-3, R-4, R-5, R-6, R-7, R-8, R-9

#### Goal
Create a reference file at `plugins/marketing/references/offer-design-frameworks.md` that captures Hormozi / Brunson / Abraham offer-design frameworks + B2B outbound frontend/backend characteristics. Vertical-agnostic. Read by every vertical playbook issue (Phase 2) and every preset composition issue (Phase 4) when designing or evaluating offers.

#### Context
Session discovery proved that offer design without a framework lens produces consultant-speak and gimmicky guarantees. Operator specifically requested frameworks be promoted from session-scope to plugin-scope via the `references/` directory. Content in this file informs every future marketing-skill decision about what to offer prospects.

Frameworks to capture:
- **Hormozi Value Equation:** `Value = (Dream Outcome × Perceived Likelihood) / (Time Delay × Effort + Sacrifice)`. Four guarantee types: conditional, unconditional, anti-guarantee, implied (performance / rev-share).
- **Brunson Value Ladder:** frontend (low-commitment bait) → mid-tier (workshop / diagnostic) → backend (high-ticket DFY). Frontend is about qualifying + acquiring, not making money on its own.
- **Abraham risk-reversal:** the more risk you take off the prospect, the higher the close rate.
- **Frontend-offer characteristics (B2B outbound lens):** named + specific deliverable, standalone value, low friction, qualifying, natural segue to backend, effortful-for-vendor (commitment bias).
- **Backend-guarantee characteristics:** quantified "doesn't work" definition, metric aligned with buyer's actual success criteria (not vanity), reasonable for vendor to underwrite, real urgency via performance alignment (not countdown-timer scarcity).

#### Execution Protocol
1. **Explore** — Read `plugins/marketing/references/README.md` for the references/ directory convention. Read `plugins/marketing/references/UPSTREAM.md` for content-origin expectations. Read existing references (`creative-thinking-models.md`, `shelf-life-patterns.md`) for shape / density / format precedent.
2. **Plan** — Run `TaskCreate` with one task per numbered Task below. Update status in_progress / completed as you go.
3. **Execute** — Work tasks in order. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox against objective pass/fail.

#### Tasks
1. Create `plugins/marketing/references/offer-design-frameworks.md`.
2. Add frontmatter (if convention used in peer references) — check existing files first.
3. Write § Hormozi Value Equation — formula, four guarantee types, worked example (Brite-flavored: Offer E production-finance applied to a generic zoo).
4. Write § Brunson Value Ladder — frontend / mid-tier / backend definitions applied to B2B outbound (frontend = email CTA, backend = full engagement).
5. Write § Abraham Risk-Reversal — principle + how it differs from Hormozi guarantees (Abraham is philosophical; Hormozi is structural).
6. Write § Frontend-Offer Characteristics (B2B outbound) — 6-item checklist with examples of "specific" vs "generic", "standalone value" vs "transactional", etc.
7. Write § Backend-Guarantee Characteristics — 4-item checklist with examples of good vs gimmicky guarantees (the "photo-share benchmark" failure is a worked example of gimmicky; "first-season-breakeven-or-no-pay" is a worked example of aligned).
8. Write § How to use this reference — note that this file is read by vertical playbooks (Phase 2) and preset composition issues (Phase 4) to evaluate and design offers.
9. Cross-reference in `plugins/marketing/references/README.md` index if one exists.
10. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/offer-design-frameworks.md` exists.
- [ ] File contains sections: Hormozi Value Equation, Brunson Value Ladder, Abraham Risk-Reversal, Frontend-Offer Characteristics, Backend-Guarantee Characteristics, How to use this reference.
- [ ] Hormozi Value Equation section defines all 4 inputs + 4 guarantee types.
- [ ] Frontend-Offer section has ≥ 6 characteristics with at least 1 specific example each.
- [ ] Backend-Guarantee section has ≥ 4 characteristics with at least 1 example of good + bad each.
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Don't restrict the content to zoos/aquariums. This is vertical-agnostic.
- Don't reproduce Hormozi's entire book. Cite source + extract the useful bits.
- Don't invent new frameworks — use Hormozi / Brunson / Abraham as-is.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this file)
- `docs/plans/BC-5879-zoos-ledger.md` — zoos session ledger (Offer-by-offer review section has framework-applied examples)
- Hormozi, "$100M Offers" (2021)
- Brunson, "DotCom Secrets" (Value Ladder)
- Abraham, various (risk-reversal principle)

---

### R-2. Create `plugins/marketing/references/experiential-lighting-vendor-landscape.md`

**Phase:** 1
**Priority:** High
**Labels:** infrastructure
**blockedBy:** none
**blocks:** R-3, R-4, R-5, R-6, R-7, R-8, R-9

#### Goal
Create a reference file at `plugins/marketing/references/experiential-lighting-vendor-landscape.md` distilled from the session's vendor-landscape research. Covers the four competitive archetypes (lantern festival producers, holiday specialty installers, projection / immersive studios, LED-retrofit vendors) with named companies, commercial models, and what each is / isn't competing on. Vertical-agnostic across experiential-lighting prospects (zoos, aquariums, casinos, hotels, ski, stadiums, theme parks, museums, botanical gardens, etc.).

#### Context
Session research found that Brite Labs' competitive landscape at zoos/aquariums was materially different than initial assumptions: S4 Lights and MK Illumination are NOT direct competitors (S4 = component manufacturer, MK Illumination = retail/urban). Tianyu Arts & Culture is the dominant lantern-festival incumbent; Illuminight covers mid-market holiday installs; Moment Factory / Limelight / Christie Digital cover projection / immersive tiers. LED-retrofit vendors (Goodlight, Orphek, EcoMedia) are adjacent, not competitive.

This reference enables any future marketing skill working on experiential-lighting prospects to understand the competitive frame without re-running the research.

#### Execution Protocol
1. **Explore** — Read `docs/plans/BC-5879-zoos-ledger.md` (the "Research grounding" section is the primary source). Read `plugins/marketing/references/README.md` for conventions.
2. **Plan** — Run `TaskCreate` with one task per numbered Task below.
3. **Execute** — Work tasks in order.
4. **Verify** — Tick every checkbox.

#### Tasks
1. Create `plugins/marketing/references/experiential-lighting-vendor-landscape.md`.
2. Write § Vendor archetypes — 4 categories: (a) Lantern festival producers, (b) Holiday specialty installers, (c) Projection / immersive studios, (d) LED-retrofit vendors.
3. Under each archetype, list named companies (Tianyu, Illuminight, Moment Factory, Limelight, Christie Digital, S4 Lights, MK Illumination, Goodlight, Orphek, EcoMedia), typical project scope, commercial model (fee-for-service / rev-share / subscription / product-sale), and what they serve vs don't.
4. Write § What Brite competes on (Brite's position within the archetype landscape — architectural commercial with programmable-media infrastructure + S4 component partnership + production-finance capability aspiration).
5. Write § When Brite wins vs loses (honest read: wins on architectural / gateway / ad-monetized programmable; loses on full-lantern-festival fabrication at scale).
6. Write § How to use this reference — note that this file is read by vertical playbooks (Phase 2) and preset composition issues (Phase 4) to avoid mis-framed competitive positioning.
7. Source every claim with a URL or an explicit "inferred from X" marker.
8. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/experiential-lighting-vendor-landscape.md` exists.
- [ ] File contains § Vendor archetypes with all 4 categories.
- [ ] Each archetype lists ≥ 2 named companies with scope / commercial model / served-vs-not.
- [ ] § What Brite competes on + § When Brite wins vs loses both present.
- [ ] Every numerical claim or vendor-specific fact has a source citation (URL or "inferred" marker).
- [ ] No mention of S4 Lights or MK Illumination as direct competitors (both are explicitly not).
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Don't rewrite the zoos-ledger research grounding verbatim. Distill.
- Don't include per-vertical program economics (that's the vertical playbook's job).
- Don't make recommendations about which offers Brite should pitch — that's the vertical playbooks and preset composition issues.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-2)
- `docs/plans/BC-5879-zoos-ledger.md` § Research grounding — primary vendor-landscape source material

---

### R-3. Update `plugins/marketing/skills/email-copywriting/SKILL.md` with cross-links to new references

**Phase:** 1
**Priority:** High
**Labels:** skill
**blockedBy:** R-1, R-2
**blocks:** R-4, R-5, R-6, R-7, R-8, R-9

#### Goal
Update `plugins/marketing/skills/email-copywriting/SKILL.md` to cross-reference the two new reference files (offer-design-frameworks.md + experiential-lighting-vendor-landscape.md + vertical-playbooks/) so the skill's methodology and MCP-tool-reference sections route readers to the framework + competitive-landscape + per-vertical content.

#### Context
The email-copywriting skill's § 3 Methodology currently explains offer tiers and the Hormozi value equation inline. With the new references in place, the skill should point to the external references rather than repeat them — keeping SKILL.md concise + making references authoritative.

#### Execution Protocol
1. **Explore** — Read `plugins/marketing/skills/email-copywriting/SKILL.md` in full. Identify sections that discuss offer design, Hormozi value equation, tier selection, and competitive positioning. Read the new references (`plugins/marketing/references/offer-design-frameworks.md` and `plugins/marketing/references/experiential-lighting-vendor-landscape.md`).
2. **Plan** — Run `TaskCreate` with one task per numbered Task below.
3. **Execute** — Work tasks in order.
4. **Verify** — Tick every checkbox.

#### Tasks
1. In § 3 Methodology, add a one-line pointer under "Hormozi value equation" subsection: "Full framework reference: `plugins/marketing/references/offer-design-frameworks.md`."
2. In § 3 Methodology, add a one-line pointer under "Offer tiers + entity-aware selection matrix" subsection: "Per-vertical offer guidance: `plugins/marketing/references/vertical-playbooks/{vertical}.md` (produced by Phase 2 issues)."
3. In § 4 Brite Implementation, add a note under "Cross-skill boundaries" referencing `plugins/marketing/references/experiential-lighting-vendor-landscape.md` as the source of competitive positioning (for skills working on experiential-lighting prospects).
4. Do NOT delete the inline Hormozi content from § 3 — leave as-is for skill self-containment; just add the pointer.
5. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `SKILL.md` contains the exact string `plugins/marketing/references/offer-design-frameworks.md` as a pointer.
- [ ] `SKILL.md` contains the exact string `plugins/marketing/references/vertical-playbooks/` as a pointer.
- [ ] `SKILL.md` contains the exact string `plugins/marketing/references/experiential-lighting-vendor-landscape.md` as a pointer.
- [ ] Existing inline Hormozi content in § 3 is preserved (not deleted).
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Do NOT rewrite or restructure SKILL.md. Minimal pointer additions only.
- Do NOT delete inline content — preserve skill self-containment.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md`
- `plugins/marketing/skills/email-copywriting/SKILL.md`

---

## Phase 2 — Vertical Playbooks

Each playbook issue produces `plugins/marketing/references/vertical-playbooks/{vertical}.md`. Contents: vendor landscape for that vertical (distilled), buyer personas, recency signals, program economics, good-vs-bad program taxonomy, offer candidates with Hormozi / frontend / backend evaluation, v1 offer picks for preset composition, voice rules, anti-slop rules.

Each playbook issue requires a fresh research-agent deep-dive for that vertical (except Zoos, which is ~80% complete from the session ledger — the Zoos playbook mostly distills existing material).

### R-4. Create `plugins/marketing/references/vertical-playbooks/zoos.md`

**Phase:** 2
**Priority:** High
**Labels:** skill
**blockedBy:** R-1, R-2, R-3
**blocks:** R-10

#### Goal
Create the zoos vertical playbook by distilling the session's zoos ledger (`docs/plans/BC-5879-zoos-ledger.md`) into the standardized playbook format. Output file: `plugins/marketing/references/vertical-playbooks/zoos.md`. This playbook is the authoritative source for all future zoos-vertical marketing work (not just email copywriting).

#### Context
The session produced a rich zoos ledger with research grounding, offer candidates (A/B/D/E), decisions (Offer A kept as tactical complement; Offer E as primary; D folded into E; B pending Facilities-VP confirmation per R-19), voice rules, and case-study anchors (Hogle Zoo; S4 partnership). This issue distills that ledger into a reusable playbook that lives in `references/` so future skills can read it.

Section structure (enforced):
1. Vendor landscape for zoos (sub-distilled from R-2, with zoo-specific lens)
2. Buyer personas (CEO / Exec Director / Dir. Corporate Partnerships / Marketing Director / Facilities VP — which for which offer)
3. Recency signals zoos leak publicly (program announcements, capital-plan votes, role changes, ticket-on-sale dates)
4. Program economics ($18-$31 adult ticket, $400K-$1M production cost, attendance benchmarks)
5. Good-vs-bad program taxonomy (static vs dynamic, crowd flow, value ceiling, animal-welfare integration)
6. Offer candidates with Hormozi / frontend / backend evaluation (A, B, D, E as analyzed in session)
7. V1 offer picks (E primary, A tactical complement, B pending R-19, D deferred)
8. Voice rules (no "lantern vendor" specification, don't name-drop enterprise venues like Disney, pitch to Operations not Marketing, etc.)
9. Anti-slop rules specific to zoos (no stadium/concert-rig language, no species name-dropping, etc.)

#### Execution Protocol
1. **Explore** — Read `docs/plans/BC-5879-zoos-ledger.md` in full. Read `plugins/marketing/references/offer-design-frameworks.md` (R-1 output) + `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (R-2 output).
2. **Plan** — Run `TaskCreate` with one task per numbered Task below.
3. **Execute** — Work tasks in order.
4. **Verify** — Tick every checkbox.

#### Tasks
1. Create `plugins/marketing/references/vertical-playbooks/` directory if it doesn't exist.
2. Create `plugins/marketing/references/vertical-playbooks/zoos.md`.
3. Write § Vendor landscape (zoos lens) — distill from R-2 + session research.
4. Write § Buyer personas — enumerate personas with which-offer-per-persona mapping.
5. Write § Recency signals — public-signal taxonomy.
6. Write § Program economics — ticket ranges, production cost, attendance benchmarks, sponsor economics.
7. Write § Good-vs-bad program taxonomy — distill from session ledger.
8. Write § Offer candidates — A, B, D, E with Hormozi / frontend / backend evaluation (copy from session ledger with minor polish).
9. Write § V1 offer picks — E primary, A tactical complement (with guarantee-metric fix noted), B pending R-19, D deferred.
10. Write § Voice rules — no "lantern vendor", no enterprise name-drops, role-targeting, etc.
11. Write § Anti-slop rules — zoo-specific.
12. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/vertical-playbooks/zoos.md` exists.
- [ ] All 9 sections present: Vendor landscape, Buyer personas, Recency signals, Program economics, Good-vs-bad taxonomy, Offer candidates, V1 offer picks, Voice rules, Anti-slop rules.
- [ ] § Offer candidates includes A, B, D, E each with Hormozi / frontend / backend evaluation.
- [ ] § V1 offer picks explicitly names E as primary + A as tactical complement + B as pending R-19 + D as deferred.
- [ ] Case-study anchor includes Hogle Zoo + S4 partnership (named).
- [ ] No usage of "lantern vendor" in the voice rules (uses "existing lighting vendor" or equivalent).
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Do NOT compose preset files in this issue. That's R-10.
- Do NOT modify the session zoos ledger. Leave it as session-artifact source.

#### Sources
- `docs/plans/BC-5879-zoos-ledger.md`
- `plugins/marketing/references/offer-design-frameworks.md` (R-1)
- `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (R-2)

---

### R-5. Create `plugins/marketing/references/vertical-playbooks/aquariums.md`

**Phase:** 2
**Priority:** High
**Labels:** skill
**blockedBy:** R-1, R-2, R-3
**blocks:** R-11

#### Goal
Create the aquariums vertical playbook. Requires fresh research-agent deep-dive — aquariums are structurally different from zoos (indoor, tank overlays, $50+ 21+ tickets, summer Glow Nights, thinner competitive vendor set). Output: `plugins/marketing/references/vertical-playbooks/aquariums.md`.

#### Context
Zoos and aquariums were split on 2026-04-21 per the roadmap decision. The session's zoos research briefly touched aquariums (Georgia Aquarium Glow Nights, Newport After Dark, Shedd Jellies permanent install by Lightswitch, Monterey Bay, National Aquarium Baltimore) but did not go deep on the aquarium competitive landscape or ad-monetization precedent for tank-gallery overlays. Fresh research required.

#### Execution Protocol
1. **Explore** — Read `plugins/marketing/references/offer-design-frameworks.md` + `plugins/marketing/references/experiential-lighting-vendor-landscape.md`. Read `docs/plans/BC-5879-zoos-ledger.md` for the aquarium snippets from the session research.
2. **Plan** — Run `TaskCreate` with one task per numbered Task below. Include a task for spinning up a research-agent deep-dive covering vendor landscape / popular programs / buyer motivations / good-vs-bad / content vocabulary / offer candidates for aquariums.
3. **Execute** — Research first, then compose playbook.
4. **Verify** — Tick every checkbox.

#### Tasks
1. Spin up a research-agent with brief covering: aquarium-specific vendor landscape (Lightswitch, Christie Digital, projection studios serving aquariums), popular aquarium programs (Georgia Glow Nights, Shedd Jellies, Newport After Dark, National Aquarium events, New England, Monterey Bay), buyer motivations (revenue diversification, adult after-hours market, summer programming, Glow-native content), good-vs-bad program taxonomy, content vocabulary (bioluminescence, coral glow, jelly tunnels, UV installations), offer candidates Hormozi-framed.
2. Integrate research output into playbook.
3-10. Same structural sections as R-4 (Vendor landscape, Buyer personas, Recency signals, Program economics, Good-vs-bad, Offer candidates, V1 offer picks, Voice rules, Anti-slop rules).
11. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/vertical-playbooks/aquariums.md` exists.
- [ ] All 9 sections present (same as R-4 structure).
- [ ] § Offer candidates includes ≥ 3 candidates, each with Hormozi / frontend / backend evaluation.
- [ ] § V1 offer picks names primary + any complements.
- [ ] Case-study anchors named (even if placeholder) with explicit "verify at composition time" if unverified.
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Do NOT compose preset files. That's R-11.
- Do NOT reuse zoo offer candidates blindly — aquarium context is structurally different.

#### Sources
- `docs/plans/BC-5879-zoos-ledger.md` (aquarium snippets)
- `plugins/marketing/references/offer-design-frameworks.md`
- `plugins/marketing/references/experiential-lighting-vendor-landscape.md`

---

### R-6. Create `plugins/marketing/references/vertical-playbooks/casinos.md`

**Phase:** 2
**Priority:** High
**Labels:** skill
**blockedBy:** R-1, R-2, R-3
**blocks:** R-12

#### Goal
Create the casinos vertical playbook. Fresh research required. Output: `plugins/marketing/references/vertical-playbooks/casinos.md`.

#### Context
Session research flagged non-gaming revenue expansion as the worldview driver for casino lighting spend. Regional / mid-market / tribal casinos are the ICP volume; Las Vegas flagship properties are enterprise procurement (different sale). No direct casino-lighting-vendor research surfaced in session; fresh research required.

#### Execution Protocol
1. **Explore** — Read the peer playbook structure (R-4 zoos playbook). Read R-1 + R-2 outputs.
2. **Plan** — TaskCreate with research + composition tasks.
3. **Execute** — Research first, then compose.
4. **Verify** — Checklist.

#### Tasks
1. Spin up research-agent with brief covering: casino experiential-lighting vendor landscape (Christie AV, Limelight, local integrators), popular casino lighting programs (non-gaming zone refreshes, restaurant / bar / lounge experiential, seasonal activations), buyer motivations (retention / attach rate / visitor-per-trip revenue), ICP differentiation (regional / tribal vs Vegas flagship), good-vs-bad taxonomy, content vocabulary (programmable scenes, retention zones, dwell time).
2. Integrate into playbook.
3-10. Same structural sections as R-4.
11. Run `./scripts/validate.sh`.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/vertical-playbooks/casinos.md` exists.
- [ ] All 9 sections present.
- [ ] § Buyer personas names specific casino roles (COO, VP Operations, VP Non-Gaming Revenue — not generic "marketing").
- [ ] § ICP differentiation explicitly calls out regional / tribal / mid-market vs Vegas flagship.
- [ ] § Offer candidates ≥ 3, Hormozi-framed.
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Do NOT compose presets. That's R-12.
- Do NOT assume Brite has pitched a casino. Research + framework application only.

#### Sources
- R-1, R-2, R-4 (for peer playbook shape)

---

### R-7. Create `plugins/marketing/references/vertical-playbooks/hotels-resorts.md`

**Phase:** 2
**Priority:** High
**Labels:** skill
**blockedBy:** R-1, R-2, R-3
**blocks:** R-13

#### Goal
Create the hotels & resorts playbook (Labs entity per session decision — mixed-entity canon resolved to Labs for this preset pair). Fresh research required. Output: `plugins/marketing/references/vertical-playbooks/hotels-resorts.md`.

#### Context
Session research flagged destination-experience / rate-premium framing as the core thesis for hotel lighting spend. Boutique and regional resorts are the ICP (enterprise flagships are procurement-heavy). Hard Rock Hollywood's 2M-LED, 24-acre install (Holiday Outdoor Décor) is a reference point for scale.

#### Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read `plugins/marketing/references/offer-design-frameworks.md` (R-1 output) + `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (R-2 output). Read R-4 zoos playbook for peer structural shape. Read `docs/plans/BC-5879-zoos-ledger.md` for any hotels snippets from session research.
2. **Plan** — Run `TaskCreate` with one task per numbered Task below. Update status in_progress / completed as you go.
3. **Execute** — Research first, then compose playbook. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox against objective pass/fail.

#### Tasks
1. Spin up a research-agent with brief covering: hotel/resort experiential-lighting vendor landscape (Holiday Outdoor Décor, MK Illumination's corporate arm, projection/immersive studios serving hospitality, AV integrators), popular hotel seasonal lighting programs (winter packages, "destination weekend" marketing, holiday overlays), buyer motivations (package-rate premium, booking-window extension, direct-channel booking mix shift, destination differentiation), ICP (boutique/regional/independent resort vs Marriott/Hilton enterprise), good-vs-bad taxonomy, content vocabulary.
2. Integrate research into playbook.
3. Write § Vendor landscape (hotels lens) — distill from R-2 + new research.
4. Write § Buyer personas — VP Revenue Management / VP Experience / GM / Director of Revenue (which for which offer).
5. Write § Recency signals — package-marketing launches, destination-weekend announcements, new GM appointments, renovation press.
6. Write § Program economics — room-rate ranges, seasonal-package revenue uplift, direct-channel booking mix.
7. Write § Good-vs-bad program taxonomy.
8. Write § Offer candidates — ≥ 3 with Hormozi / frontend / backend evaluation per R-1 reference.
9. Write § V1 offer picks — primary + complements.
10. Write § Voice rules — no enterprise-flagship name-drops, no "romantic" / "ambiance" buzzwords, pitch VP Revenue Management not GM.
11. Write § Anti-slop rules — no commodity "lighting upgrade" framing, no wedding-revenue-as-default-proof-point, no urgency.
12. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/vertical-playbooks/hotels-resorts.md` exists.
- [ ] All 9 sections present: Vendor landscape, Buyer personas, Recency signals, Program economics, Good-vs-bad taxonomy, Offer candidates, V1 offer picks, Voice rules, Anti-slop rules.
- [ ] § ICP explicitly differentiates boutique / regional / independent from Marriott/Hilton enterprise.
- [ ] § Offer candidates ≥ 3, each with Hormozi / frontend / backend evaluation.
- [ ] § V1 offer picks names primary + any complements with rationale.
- [ ] `grep -ci 'romantic\|ambiance' plugins/marketing/references/vertical-playbooks/hotels-resorts.md` returns matches only inside anti-slop "don't" bullets (not in framing or voice rules).
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Do NOT compose preset files. That's R-13.
- Do NOT reuse zoo offer candidates blindly — hotel context is structurally different.
- Do NOT target enterprise-flagship brands as default ICP.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-7)
- `plugins/marketing/references/offer-design-frameworks.md` (R-1 output; will be created by R-1 / BC-5917)
- `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (R-2 output; will be created by R-2 / BC-5918)
- R-4 zoos playbook (peer structural reference)
- `docs/plans/BC-5879-zoos-ledger.md` (session research grounding)

---

### R-8. Create `plugins/marketing/references/vertical-playbooks/ski-resorts.md`

**Phase:** 2
**Priority:** High
**Labels:** skill
**blockedBy:** R-1, R-2, R-3
**blocks:** R-14

#### Goal
Create the ski resorts playbook (Labs entity). Fresh research required.

#### Context
Session research flagged village-dwell / après-ski economics as the thesis. Village F&B tenancy is the second profit center. Mid-market regional ski resorts (Vermont / Michigan / Montana) are the ICP volume; Vail / Deer Valley / Aspen enterprise are slow procurement.

#### Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read R-1 + R-2 + R-4 outputs (frameworks / vendor-landscape / zoos peer playbook). Read `docs/plans/BC-5879-zoos-ledger.md` for any ski snippets from session research.
2. **Plan** — Run `TaskCreate` with one task per numbered Task below. Update status in_progress / completed as you go.
3. **Execute** — Research first, then compose playbook. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox against objective pass/fail.

#### Tasks
1. Spin up a research-agent with brief covering: ski-resort experiential-lighting vendor landscape (village AV integrators, theming specialists), popular programs (village programmable overlays, après-ski F&B ambiance, holiday opening weekends, spring festival), buyer motivations (village-dwell time, F&B tenant retention, post-lift-close revenue, destination branding), ICP (regional — Vermont / Michigan / Montana / NY / NH — vs enterprise — Vail / Deer Valley / Aspen), good-vs-bad taxonomy (village is Brite's zone, lift-line or mountain-ops is not), content vocabulary.
2. Integrate research into playbook.
3. Write § Vendor landscape (ski lens) — distill from R-2 + new research.
4. Write § Buyer personas — VP Village Operations, Director of Guest Services, F&B Director (explicitly NOT Lift Operations).
5. Write § Recency signals — village F&B tenancy announcements, après-ski programming launches, season-opening preparation cycles.
6. Write § Program economics — après-ski revenue-per-visitor benchmarks, village dwell-time targets, season-length seasonality.
7. Write § Good-vs-bad program taxonomy.
8. Write § Offer candidates — ≥ 3 with Hormozi / frontend / backend evaluation per R-1.
9. Write § V1 offer picks — primary + complements.
10. Write § Voice rules — don't pitch to Lift Ops, don't reference Colorado/Utah enterprise resorts as default, don't frame as holiday-only (season-long village is the motion), no "magical" / "winter wonderland" buzzwords.
11. Write § Anti-slop rules — ski-specific.
12. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/vertical-playbooks/ski-resorts.md` exists.
- [ ] All 9 sections present (Vendor landscape, Buyer personas, Recency signals, Program economics, Good-vs-bad, Offer candidates, V1 offer picks, Voice rules, Anti-slop).
- [ ] § Buyer personas explicitly names VP Village Operations / Director of Guest Services / F&B Director AND explicitly rules out Lift Operations as a target.
- [ ] § Offer candidates ≥ 3, each framework-evaluated.
- [ ] § V1 offer picks names primary + complements.
- [ ] `grep -ci 'magical\|winter wonderland' plugins/marketing/references/vertical-playbooks/ski-resorts.md` returns matches only in anti-slop "don't" bullets.
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Do NOT compose preset files. That's R-14.
- Do NOT target enterprise flagship resorts as default ICP.
- Do NOT pitch lift-line or on-mountain lighting (out of Brite's zone).

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-8)
- `plugins/marketing/references/offer-design-frameworks.md` (R-1 output)
- `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (R-2 output)
- R-4 zoos playbook (peer reference)
- `docs/plans/BC-5879-zoos-ledger.md`

---

### R-9. Create `plugins/marketing/references/vertical-playbooks/sports-stadiums.md`

**Phase:** 2
**Priority:** High
**Labels:** skill
**blockedBy:** R-1, R-2, R-3
**blocks:** R-15

#### Goal
Create the sports stadiums playbook (Labs entity). Fresh research required.

#### Context
Session research flagged off-season activation / non-game-day revenue as the thesis. Minor-league, college, MLS, multipurpose regional venues are ICP (pro stadium procurement is multi-year committee-heavy). Broadcast-spec lighting is pro-grade locked — Brite's zone is audience-experience programmable, not game-day rig.

#### Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read R-1 + R-2 + R-4 outputs. Read `docs/plans/BC-5879-zoos-ledger.md` for any stadiums snippets from session research.
2. **Plan** — Run `TaskCreate` with one task per numbered Task below. Update status in_progress / completed as you go.
3. **Execute** — Research first, then compose playbook. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox against objective pass/fail.

#### Tasks
1. Spin up a research-agent with brief covering: stadium experiential-lighting vendor landscape (broadcast AV integrators, projection studios, concert-rig vendors, multipurpose-venue lighting providers), popular off-season activation programs (concerts, family events, graduations, community events, food festivals), buyer motivations (off-season utilization, non-game-day booking rate, event differentiator, per-event revenue), ICP (minor league / college / MLS / multipurpose regional / amphitheater vs pro flagship), good-vs-bad taxonomy (off-season = Brite zone; broadcast-spec and game-day lighting are NOT), content vocabulary (programmable-zone, music-sync, show-calling, audience-experience).
2. Integrate research into playbook.
3. Write § Vendor landscape (stadium lens).
4. Write § Buyer personas — VP Bookings, VP Non-Game-Day Revenue, Director of Events (explicitly NOT Facilities or pro-team front-office).
5. Write § Recency signals — off-season calendar announcements, new booking VP appointments, event-series launches.
6. Write § Program economics — per-event revenue benchmarks, off-season utilization rates, per-date booking yield.
7. Write § Good-vs-bad program taxonomy.
8. Write § Offer candidates — ≥ 3 with Hormozi / frontend / backend evaluation.
9. Write § V1 offer picks — primary + complements.
10. Write § Voice rules — don't pitch game-day lighting, no broadcast-spec language, don't name-drop artists, don't reference pro-stadium brands as default.
11. Write § Anti-slop rules — stadium-specific.
12. Run `./scripts/validate.sh` — must exit 0.

#### Verification (objective pass/fail)
- [ ] `plugins/marketing/references/vertical-playbooks/sports-stadiums.md` exists.
- [ ] All 9 sections present.
- [ ] § Buyer personas explicitly names VP Bookings / VP Non-Game-Day Revenue / Director of Events AND explicitly rules out Facilities or pro-team front-office.
- [ ] § Offer candidates ≥ 3, each framework-evaluated.
- [ ] § V1 offer picks names primary + complements.
- [ ] `grep -ci 'broadcast\|game-day' plugins/marketing/references/vertical-playbooks/sports-stadiums.md` returns matches only in anti-slop "don't" bullets.
- [ ] `./scripts/validate.sh` exits 0.

#### Non-Goals
- Do NOT compose preset files. That's R-15.
- Do NOT target pro-stadium enterprise as default ICP.
- Do NOT pitch game-day or broadcast-spec lighting (out of Brite's zone).

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-9)
- `plugins/marketing/references/offer-design-frameworks.md` (R-1 output)
- `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (R-2 output)
- R-4 zoos playbook (peer reference)
- `docs/plans/BC-5879-zoos-ledger.md`

---

## Phase 4 — Preset Composition

Each preset composition issue produces 2-6 preset files for one vertical. File count depends on how many v1 offers the vertical's playbook picks (typically 2: primary offer + tactical complement = 4 files; sometimes 3 offers = 6 files). Uses filename convention: default primary = `{preset}-{vertical}.md`; variants = `{preset}-{vertical}-{offer-slug}.md`.

### R-10. Compose zoos preset files (Offer E + Offer A)

**Phase:** 4
**Priority:** High
**Labels:** skill
**blockedBy:** R-4
**blocks:** R-16

#### Goal
Compose 4 preset files for the zoos vertical: 2 for Offer E (primary, default filename) + 2 for Offer A (tactical complement, variant filename). Files live in `plugins/marketing/skills/email-copywriting/presets/`.

Files to produce:
- `list-building-zoos.md` (Offer E — custom economic-impact deck + sponsor-target shortlist)
- `risk-reversal-zoos.md` (Offer E — first-season-breakeven-or-no-pay guarantee)
- `list-building-zoos-pilot-zone.md` (Offer A — rendered concept board for specific venue area)
- `risk-reversal-zoos-pilot-zone.md` (Offer A — dwell-time / attendance-uplift / sponsor-impression benchmark guarantee; NOT photo-share)

#### Context
The zoos playbook (R-4) defines Offer E as primary and Offer A as tactical complement. Offer A required fixes before composition: (1) sharpen frontend deliverable to "rendered concept board", (2) swap backend guarantee from photo-share to venue-native metric, (3) reframe commercial structure as confident not supplicant. Offer B deferred pending R-19. Offer D folded into E.

Voice rule: don't use "lantern vendor" or any specific-vendor-type framing in body copy. Use "existing lighting vendor" / "incumbent" / "current seasonal-program vendor".

Case-study anchor: Hogle Zoo as named Brite reference. S4 Lights as component partnership (specific venues pending R-17).

#### Execution Protocol
1. **Explore** — Read `plugins/marketing/references/vertical-playbooks/zoos.md` (R-4 output). Read `plugins/marketing/skills/email-copywriting/SKILL.md` § 3 (template rules). Read the Municipalities seeds (`presets/list-building-municipalities.md` + `risk-reversal-municipalities.md`) as format precedent.
2. **Plan** — TaskCreate with one task per file + one task for validation.
3. **Execute** — Compose per playbook + SKILL.md §3 format rules.
4. **Verify** — Tick every checkbox against the full anti-slop + structural list.

#### Tasks
1. Compose `list-building-zoos.md` (Offer E T2): frontmatter (5 keys), H1, Hook section, Step 1 skeleton with subject + body + wait_in_days, Step 2 bump, Vertical anti-slop bullets. Target 55-65 lines. Use `{FREE_ASSET_NOUN}` default = "economic-impact deck" or "sponsor-target shortlist". Hogle Zoo as proof-point anchor.
2. Compose `risk-reversal-zoos.md` (Offer E T4): same shape. Guarantee framing: first-season-breakeven-or-no-pay.
3. Compose `list-building-zoos-pilot-zone.md` (Offer A T2): same shape. `{FREE_ASSET_NOUN}` = "rendered concept board for [specific area]". Frame for venues with incumbent vendor.
4. Compose `risk-reversal-zoos-pilot-zone.md` (Offer A T4): same shape. Guarantee metric: dwell-time / attendance-uplift / sponsor-visibility (pick one + specify metric name).
5. Verify all 4 files pass EB format: no `{{`, no `<p>`, no em-dash (`—`) in body, no `{FIRST_NAME}` in subject, exactly 2 steps, sign-off spintax.
6. Run `grep -c '—' *.md` — expect 0 em-dashes across all 4 files.
7. Run `./scripts/validate.sh`.
8. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md`.

#### Verification (objective pass/fail)
- [ ] All 4 files exist at correct paths.
- [ ] Each has 5-key frontmatter: preset, vertical, entity (brite-labs), when, situation_mining_row.
- [ ] Each has H1, Hook, Step 1, Step 2, Vertical anti-slop sections.
- [ ] `grep -c '{{' list-building-zoos.md risk-reversal-zoos.md list-building-zoos-pilot-zone.md risk-reversal-zoos-pilot-zone.md` returns 0 for each.
- [ ] `grep -c '<p>' [same 4 files]` returns 0 for each.
- [ ] `grep -c '—' [same 4 files]` returns 0 for each.
- [ ] No `{FIRST_NAME}` or other merge variable in any `**Subject:**` line across the 4 files.
- [ ] Each file contains either "Hogle Zoo" or `{LABS_PEER_VENUE}` placeholder referencing Hogle as proof-point.
- [ ] Each file contains reference to S4 partnership OR `{S4_PARTNER_VENUE}` placeholder.
- [ ] No usage of "lantern vendor" anywhere in body copy (may appear in anti-slop bullets as explicit "don't use").
- [ ] Line count 55-65 per file (±5 tolerance).
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

#### Non-Goals
- Do NOT compose Offer B variants. Deferred until R-19.
- Do NOT modify SKILL.md or Municipalities seeds.
- Do NOT file Linear issue for follow-up v2 refresh. That's R-17's job.

#### Sources
- `plugins/marketing/references/vertical-playbooks/zoos.md` (R-4)
- `plugins/marketing/skills/email-copywriting/SKILL.md` § 3
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` + `risk-reversal-municipalities.md`
- `docs/plans/BC-5879-zoos-ledger.md`

---

### R-11. Compose aquariums preset files (offer count TBD per R-5 playbook)

**Phase:** 4
**Priority:** High
**Labels:** skill
**blockedBy:** R-5
**blocks:** R-16

#### Goal
Compose preset files for the aquariums vertical. Offer count determined by the aquariums playbook (R-5). Files live in `plugins/marketing/skills/email-copywriting/presets/`.

Minimum files: 2 (primary offer list-building + risk-reversal). If multi-offer v1 picked in R-5, additional variant files.

#### Context
Aquariums vertical split from zoos on 2026-04-21. Structurally different motion (indoor, tank overlays, 21+ after-hours, $50+ tickets, summer Glow Nights). The aquariums playbook (R-5) designs the v1 offer set.

#### Execution Protocol
1. **Explore** — Read `plugins/marketing/references/vertical-playbooks/aquariums.md` (R-5 output). Read SKILL.md § 3. Read Municipalities seeds for format.
2. **Plan** — TaskCreate with one task per file (count = 2 × number of v1 offers picked in R-5).
3. **Execute** — Compose per playbook.
4. **Verify** — Objective checklist.

#### Tasks
1. Identify v1 offer set from R-5 playbook.
2-N. Compose each preset file.
N+1. Run anti-slop checks.
N+2. Run validate.sh + check-guardrails.sh.

#### Verification
- [ ] All preset files for the v1 offer set exist.
- [ ] Each has 5-key frontmatter with entity=brite-labs.
- [ ] Each has all sections per SKILL.md § 3 structure.
- [ ] No `{{`, no `<p>`, no `—` in body copy.
- [ ] No merge variable in subject lines.
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

#### Non-Goals
- Don't compose offers not picked by the playbook.

#### Sources
- R-5 playbook output, SKILL.md § 3, Municipalities seeds.

---

### R-12. Compose casinos preset files (offer count TBD per R-6)

**Phase:** 4
**Priority:** High
**Labels:** skill
**blockedBy:** R-6
**blocks:** R-16

#### Goal
Compose preset files for the casinos vertical per the v1 offer set picked in R-6 (casinos playbook). Minimum 2 files (primary offer list-building + risk-reversal); additional files if multi-offer v1 is picked. Files live in `plugins/marketing/skills/email-copywriting/presets/` using `{preset}-casinos[-{offer-slug}].md` naming convention.

#### Context
Casino lighting prospects: non-gaming revenue expansion is the thesis. Regional / tribal / mid-market operators are the ICP volume; Las Vegas flagship properties are enterprise procurement (out of scope for v1). "Retention infrastructure" framing is load-bearing — lighting as a visitor-retention multiplier, not a cosmetic upgrade. Buyer is operations-side: COO / VP Operations / VP Non-Gaming Revenue (not Marketing or Facilities).

#### Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read `plugins/marketing/references/vertical-playbooks/casinos.md` (R-6 output). Read SKILL.md § 3. Read Municipalities seeds for format precedent.
2. **Plan** — Run `TaskCreate` with one task per preset file (count = 2 × number of v1 offers picked in R-6) + verification tasks. Update status in_progress / completed as you go.
3. **Execute** — Compose per playbook. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox.

#### Tasks
1. Identify v1 offer set from R-6 playbook.
2. For each v1 offer, compose `list-building-casinos[-{offer-slug}].md` per SKILL.md § 3 template (frontmatter: preset / vertical / entity=brite-labs / when / situation_mining_row; Hook; Step 1 skeleton; Step 2 bump; Vertical anti-slop). "Retention infrastructure" framing in hook + body.
3. For each v1 offer, compose `risk-reversal-casinos[-{offer-slug}].md` per SKILL.md § 3 template. Phase-gate tied to retention metric.
4. Run anti-slop greps across all new casinos preset files (`{{`, `<p>`, `—`, merge variables in subject).
5. Verify no "Vegas" as default ICP in body copy; regional/tribal language throughout.
6. Run `./scripts/validate.sh` — must exit 0.
7. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — must exit 0.

#### Verification (objective pass/fail)
- [ ] All preset files for the v1 offer set exist under `plugins/marketing/skills/email-copywriting/presets/`.
- [ ] Each has 5-key frontmatter with `entity: brite-labs`.
- [ ] Each has all sections per SKILL.md § 3 structure (Hook / Step 1 / Step 2 / Vertical anti-slop).
- [ ] `grep -l '{{' [casinos preset files]` returns no files.
- [ ] `grep -l '<p>' [casinos preset files]` returns no files.
- [ ] `grep -l '—' [casinos preset files]` returns no files.
- [ ] No merge variable (`{FIRST_NAME}` or other) in any subject line.
- [ ] Body copy contains "retention" or "retention infrastructure" in hook or proof-point paragraph of at least one preset.
- [ ] `grep -ci 'Las Vegas\|vegas strip' [casinos preset files]` returns 0 in body copy (may appear in anti-slop "don't use" bullets).
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

#### Non-Goals
- Don't compose offers not picked by the playbook (R-6).
- Don't target Las Vegas flagship properties as default ICP.
- Don't use gaming-floor language or pit-specific framing.
- Don't use "experience" or "aesthetic upgrade" as standalone buzzwords.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-12)
- `plugins/marketing/references/vertical-playbooks/casinos.md` (R-6 output)
- `plugins/marketing/skills/email-copywriting/SKILL.md` § 3
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` + `risk-reversal-municipalities.md` (format precedent)

---

### R-13. Compose hotels & resorts preset files (offer count TBD per R-7)

**Phase:** 4
**Priority:** High
**Labels:** skill
**blockedBy:** R-7
**blocks:** R-16

#### Goal
Compose preset files for the hotels & resorts vertical per the v1 offer set picked in R-7 (hotels & resorts playbook). Minimum 2 files. Files live in `plugins/marketing/skills/email-copywriting/presets/` using `{preset}-hotels-resorts[-{offer-slug}].md` naming.

#### Context
Hotel lighting prospects: "rooms are commodity, destination is differentiation" worldview. Boutique / regional / independent resorts are the ICP (Marriott / Hilton enterprise is multi-year RFP territory — out of scope for v1). "Rate-premium driver" and "destination-experience" framings are load-bearing. Buyer is revenue-side: VP Revenue Management / VP Experience / Director of Revenue (not GM).

#### Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read `plugins/marketing/references/vertical-playbooks/hotels-resorts.md` (R-7 output). Read SKILL.md § 3. Read Municipalities seeds.
2. **Plan** — Run `TaskCreate` with one task per preset file + verification. Update status in_progress / completed as you go.
3. **Execute** — Compose per playbook. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox.

#### Tasks
1. Identify v1 offer set from R-7 playbook.
2. For each v1 offer, compose `list-building-hotels-resorts[-{offer-slug}].md` per SKILL.md § 3 template. "Rate-premium" or "destination-experience" framing in hook + body.
3. For each v1 offer, compose `risk-reversal-hotels-resorts[-{offer-slug}].md` per SKILL.md § 3 template. Phase-gate tied to package-revenue proof.
4. Run anti-slop greps across all new hotels preset files.
5. Verify no Marriott / Hilton / enterprise-flagship brand as default ICP in body copy.
6. Run `./scripts/validate.sh`.
7. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md`.

#### Verification (objective pass/fail)
- [ ] All preset files for the v1 offer set exist.
- [ ] Each has 5-key frontmatter with `entity: brite-labs`.
- [ ] Each has all sections per SKILL.md § 3.
- [ ] `grep -l '{{' [hotels preset files]` returns no files.
- [ ] `grep -l '<p>' [hotels preset files]` returns no files.
- [ ] `grep -l '—' [hotels preset files]` returns no files.
- [ ] No merge variable in subject lines.
- [ ] `grep -ci 'marriott\|hilton\|hyatt' [hotels preset files]` returns 0 in body copy (may appear in anti-slop "don't use" bullets).
- [ ] `grep -ci 'romantic\|ambiance' [hotels preset files]` returns 0 in body copy.
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

#### Non-Goals
- Don't compose offers not picked by R-7.
- Don't target Marriott / Hilton / Hyatt enterprise flagships.
- Don't use "romantic" / "ambiance" as promotional buzzwords.
- Don't pitch to GM — pitch to VP Revenue Management or VP Experience.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-13)
- `plugins/marketing/references/vertical-playbooks/hotels-resorts.md` (R-7 output)
- `plugins/marketing/skills/email-copywriting/SKILL.md` § 3
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` + `risk-reversal-municipalities.md`

---

### R-14. Compose ski resorts preset files (offer count TBD per R-8)

**Phase:** 4
**Priority:** High
**Labels:** skill
**blockedBy:** R-8
**blocks:** R-16

#### Goal
Compose preset files for the ski resorts vertical per the v1 offer set picked in R-8 (ski resorts playbook). Minimum 2 files. Files live in `plugins/marketing/skills/email-copywriting/presets/` using `{preset}-ski-resorts[-{offer-slug}].md` naming.

#### Context
Ski resort lighting prospects: village is the second profit center; après-ski economy needs ambiance to retain guests post-lift-close. Regional resorts (Vermont / Michigan / Montana / NY / NH) are the ICP; Vail / Deer Valley / Aspen enterprise is out of scope for v1. "Village-dwell" framing is load-bearing — the lever is post-lift-close dwell time in the village. Buyer is village-side: VP Village Operations / Director of Guest Services / F&B Director (explicitly NOT Lift Operations).

#### Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read `plugins/marketing/references/vertical-playbooks/ski-resorts.md` (R-8 output). Read SKILL.md § 3. Read Municipalities seeds.
2. **Plan** — Run `TaskCreate` with one task per preset file + verification. Update status in_progress / completed as you go.
3. **Execute** — Compose per playbook. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox.

#### Tasks
1. Identify v1 offer set from R-8 playbook.
2. For each v1 offer, compose `list-building-ski-resorts[-{offer-slug}].md` per SKILL.md § 3 template. "Village-dwell" framing in hook + body.
3. For each v1 offer, compose `risk-reversal-ski-resorts[-{offer-slug}].md` per SKILL.md § 3 template. Phase-gate tied to village-dwell metric.
4. Run anti-slop greps across all new ski-resorts preset files.
5. Verify no lift-line or on-mountain language in body copy; no "magical" / "winter wonderland" buzzwords.
6. Run `./scripts/validate.sh`.
7. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md`.

#### Verification (objective pass/fail)
- [ ] All preset files for the v1 offer set exist.
- [ ] Each has 5-key frontmatter with `entity: brite-labs`.
- [ ] Each has all sections per SKILL.md § 3.
- [ ] `grep -l '{{' [ski preset files]` returns no files.
- [ ] `grep -l '<p>' [ski preset files]` returns no files.
- [ ] `grep -l '—' [ski preset files]` returns no files.
- [ ] No merge variable in subject lines.
- [ ] `grep -ci 'lift.line\|mountain.ops\|on.mountain' [ski preset files]` returns 0 in body copy (may appear in anti-slop bullets).
- [ ] `grep -ci 'magical\|winter wonderland' [ski preset files]` returns 0 in body copy.
- [ ] `grep -ci 'vail\|deer valley\|aspen' [ski preset files]` returns 0 in body copy.
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

#### Non-Goals
- Don't compose offers not picked by R-8.
- Don't pitch lift-line / on-mountain lighting.
- Don't target enterprise flagship ski resorts.
- Don't pitch to Lift Operations — pitch to village-side roles.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-14)
- `plugins/marketing/references/vertical-playbooks/ski-resorts.md` (R-8 output)
- `plugins/marketing/skills/email-copywriting/SKILL.md` § 3
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` + `risk-reversal-municipalities.md`

---

### R-15. Compose sports stadiums preset files (offer count TBD per R-9)

**Phase:** 4
**Priority:** High
**Labels:** skill
**blockedBy:** R-9
**blocks:** R-16

#### Goal
Compose preset files for the sports stadiums vertical per the v1 offer set picked in R-9 (sports stadiums playbook). Minimum 2 files. Files live in `plugins/marketing/skills/email-copywriting/presets/` using `{preset}-sports-stadiums[-{offer-slug}].md` naming.

#### Context
Stadium lighting prospects: off-season utilization is the thesis — stadium revenue must exceed game-day economics. Minor-league / college / MLS / multipurpose regional venues are the ICP; pro-stadium flagship procurement is multi-year + committee-heavy + out of scope for v1. "Off-season activation" framing is load-bearing. Buyer is bookings-side: VP Bookings / VP Non-Game-Day Revenue / Director of Events (explicitly NOT Facilities or pro-team front-office).

#### Execution Protocol (for the AI agent picking this up)
1. **Explore** — Read `plugins/marketing/references/vertical-playbooks/sports-stadiums.md` (R-9 output). Read SKILL.md § 3. Read Municipalities seeds.
2. **Plan** — Run `TaskCreate` with one task per preset file + verification. Update status in_progress / completed as you go.
3. **Execute** — Compose per playbook. Stop and ask if anything is ambiguous.
4. **Verify** — Tick every checkbox.

#### Tasks
1. Identify v1 offer set from R-9 playbook.
2. For each v1 offer, compose `list-building-sports-stadiums[-{offer-slug}].md` per SKILL.md § 3 template. "Off-season activation" framing in hook + body.
3. For each v1 offer, compose `risk-reversal-sports-stadiums[-{offer-slug}].md` per SKILL.md § 3 template. Phase-gate tied to event-revenue or booking-yield metric.
4. Run anti-slop greps across all new stadiums preset files.
5. Verify no game-day / broadcast-spec / artist-name-drop language in body copy; no pro-stadium brand name-drops.
6. Run `./scripts/validate.sh`.
7. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md`.

#### Verification (objective pass/fail)
- [ ] All preset files for the v1 offer set exist.
- [ ] Each has 5-key frontmatter with `entity: brite-labs`.
- [ ] Each has all sections per SKILL.md § 3.
- [ ] `grep -l '{{' [stadiums preset files]` returns no files.
- [ ] `grep -l '<p>' [stadiums preset files]` returns no files.
- [ ] `grep -l '—' [stadiums preset files]` returns no files.
- [ ] No merge variable in subject lines.
- [ ] `grep -ci 'game.day\|broadcast' [stadiums preset files]` returns 0 in body copy (may appear in anti-slop bullets).
- [ ] `grep -ci 'nfl\|mlb\|nba\|nhl' [stadiums preset files]` returns 0 in body copy (no pro-league brand defaults).
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

#### Non-Goals
- Don't compose offers not picked by R-9.
- Don't target pro-stadium flagship venues.
- Don't pitch game-day or broadcast-spec lighting.
- Don't name-drop artists or specific events as default proof-points.
- Don't pitch to Facilities or pro-team front office.

#### Sources
- `docs/designs/email-copywriting-preset-roadmap.md` — master roadmap (this issue is R-15)
- `plugins/marketing/references/vertical-playbooks/sports-stadiums.md` (R-9 output)
- `plugins/marketing/skills/email-copywriting/SKILL.md` § 3
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` + `risk-reversal-municipalities.md`

---

## Phase 5 — Ship Readiness

### R-16. Preset library ship readiness — README manifest + anti-slop + validation

**Phase:** 5
**Priority:** High
**Labels:** skill
**blockedBy:** R-10, R-11, R-12, R-13, R-14, R-15
**blocks:** none

#### Goal
Update `presets/README.md` manifest with all new preset file paths, run global anti-slop grep verification across all new presets, run `./scripts/validate.sh` + `./scripts/check-guardrails.sh`. Green on all three is the ship signal.

#### Context
After R-10 through R-15 ship individual preset files, the manifest needs updating + final cross-file validation. This issue is the single "preset library is ready to ship" gate.

#### Execution Protocol
1. **Explore** — Read current `plugins/marketing/skills/email-copywriting/presets/README.md`. Enumerate all preset files on disk.
2. **Plan** — TaskCreate with tasks below.
3. **Execute** — Update manifest, run checks.
4. **Verify** — Tick checkboxes.

#### Tasks
1. Enumerate all preset files in `plugins/marketing/skills/email-copywriting/presets/` using `ls` or `glob`.
2. Update `README.md` manifest: replace any "Pending BC-5879" cells with ✅ + filename for files that now exist. Add a note explaining the scope pivot (Active-tier Nites displaced to follow-up issue; Labs-tier 6 verticals shipped).
3. Run global anti-slop grep: `grep -l '{{' *.md`, `grep -l '<p>' *.md`, `grep -l '—' *.md` — all must return no files.
4. Grep-verify no `{FIRST_NAME}` or merge variable in subject lines across all preset files: `grep -A 1 '^**Subject:**' *.md | grep -E '\{[A-Z_]+\}'` must return only legitimate variables (not `{FIRST_NAME}`).
5. Run `./scripts/validate.sh`.
6. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md`.

#### Verification (objective pass/fail)
- [ ] `grep -c 'Pending BC-5879' presets/README.md` returns 0 OR only returns for the Active-tier Nites row (displaced to follow-up).
- [ ] All files shipped by R-10 through R-15 appear in the manifest table with ✅.
- [ ] `grep -l '{{' presets/*.md` returns no files.
- [ ] `grep -l '<p>' presets/*.md` returns no files.
- [ ] `grep -l '—' presets/*.md` returns no files.
- [ ] `grep -l '{FIRST_NAME}' [extracted subject lines across all presets]` returns no files.
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

#### Non-Goals
- Don't modify individual preset files in this issue.
- Don't file new follow-up issues.

#### Sources
- All R-10 through R-15 outputs.
- `plugins/marketing/skills/email-copywriting/presets/README.md`.

---

## Phase 6 — Follow-ups (parallel, no blocking relationship)

### R-17. Retrieve S4 Lights customer list for name-drop credibility

**Phase:** 6
**Priority:** Medium
**Labels:** infrastructure
**blockedBy:** none
**blocks:** none (enables v2 refresh of zoos + aquariums preset proof-points)

#### Goal
Get the full list of S4 Lights' customer venues from Brite's partnership contact at S4. Store the list as a reference artifact. Blocks/unblocks v2 refresh of zoos / aquariums / other vertical presets that reference S4-partner venues.

#### Context
Brite Labs has a partnership with S4 Lights (DMX-pixel components supplier). The zoos preset v1 ships with generic "S4 partner venues" framing; v2 can specify named venues once the customer list is in hand. Similarly applies to aquariums + other verticals using S4 hardware.

#### Execution Protocol
1. **Explore** — Identify Brite's S4 partnership contact (internal).
2. **Plan** — TaskCreate for request + intake tasks.
3. **Execute** — Request list, intake, store.
4. **Verify** — Checklist.

#### Tasks
1. Identify the Brite stakeholder who owns the S4 relationship.
2. Request the customer list in a format that Brite can reference (venue name, venue category, project scope if available).
3. Store the list at `docs/research/s4-partner-venues.md` or similar with a frontmatter date-refreshed field.
4. Cross-link from `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (R-2) S4 section.

#### Verification
- [ ] Customer list exists on disk at a Brite-controlled path.
- [ ] List includes ≥ 5 named venues (threshold for meaningful proof-point breadth).
- [ ] List has a date-refreshed marker.
- [ ] R-2 vendor-landscape file cross-links the list.

#### Non-Goals
- Don't file separate Linear issues for each v2 refresh. Let this unblock them downstream.

#### Sources
- Internal S4 partnership contact.

---

### R-18. Verify Hogle Zoo case study specifics

**Phase:** 6
**Priority:** Medium
**Labels:** infrastructure
**blockedBy:** none
**blocks:** none (enables richer proof-point in zoos preset v2)

#### Goal
Confirm the specific program name, year, scope, and measurable outcomes of Brite Labs' Hogle Zoo engagement. Store specifics for preset refresh.

#### Context
Hogle Zoo is the named zoo case study in the zoos ledger. Session lacked specifics (program name, year, scope, metrics). v1 of zoos preset uses generic "a similar motion at Hogle Zoo" framing. v2 can specify the program name + outcome once verified.

#### Execution Protocol
1. Explore — ask the Brite internal stakeholder who owns the Hogle account.
2. Plan — TaskCreate for questions + intake.
3. Execute — collect, store.
4. Verify — checklist.

#### Tasks
1. Identify internal stakeholder for Hogle engagement.
2. Collect: program name, year(s) active, scope (what Brite installed), measurable outcome (attendance lift, sponsor-visibility metrics, dwell time, etc.).
3. Store at `docs/research/hogle-zoo-case-study.md` with frontmatter.
4. Cross-link from `plugins/marketing/references/vertical-playbooks/zoos.md` (R-4).

#### Verification
- [ ] File exists with the four specifics populated (program name, year, scope, outcome).
- [ ] R-4 playbook cross-links the file.

#### Non-Goals
- Don't compose new preset content. Preset refresh is a separate issue.

#### Sources
- Internal Hogle stakeholder.

---

### R-19. Confirm Brite's Facilities-VP sales motion at zoos (decides Offer B status)

**Phase:** 6
**Priority:** Low
**Labels:** infrastructure
**blockedBy:** none
**blocks:** (potentially) a new "compose Offer B zoos presets" issue if answer is positive

#### Goal
Answer the question: does Brite have a Facilities-VP sales motion at zoos today? The answer determines whether Offer B (Permanent Backbone) is a real v1 option or aspirational.

#### Context
Offer B was deferred in zoos v1 pending this confirmation. If Brite confirms a real motion, a new issue gets filed to compose the Offer B preset pair (list-building-zoos-permanent-backbone.md + risk-reversal-zoos-permanent-backbone.md). If aspirational, Offer B gets marked year-2 and no preset is filed.

#### Execution Protocol
1. **Explore** — review Brite's current sales motions at zoos via internal stakeholder.
2. **Plan** — TaskCreate for conversation + decision.
3. **Execute** — ask, decide.
4. **Verify** — decision is logged.

#### Tasks
1. Identify the Brite sales leader who knows current account motions.
2. Ask: does Brite currently sell to Facilities VPs at zoos? Any active deals / recent closes? Any permanent-install motion (not just seasonal)?
3. Log decision in `docs/plans/BC-5879-facilities-vp-decision.md` with date + rationale.
4. If positive, file new issue: compose Offer B zoos presets.
5. If negative, update `plugins/marketing/references/vertical-playbooks/zoos.md` to mark Offer B as "year-2 aspirational".

#### Verification
- [ ] Decision file exists with clear positive / negative answer + rationale.
- [ ] If positive: new issue filed.
- [ ] If negative: zoos playbook updated.

#### Non-Goals
- Don't compose any Offer B presets inside this issue. That's a separate spawn if the answer is positive.

#### Sources
- Internal Brite sales stakeholder.

---

### R-20. Multi-offer scope decision per vertical

**Phase:** 6
**Priority:** Low
**Labels:** infrastructure
**blockedBy:** R-4, R-5, R-6, R-7, R-8, R-9 (all playbooks)
**blocks:** none

#### Goal
After all 6 vertical playbooks land, review whether the multi-offer scope (multiple offer variants per vertical) is worth pursuing at each vertical. Decision feeds into how many presets each Phase 4 issue ships.

#### Context
The roadmap currently assumes 2 offers per vertical (primary + tactical complement = 4 files). Playbooks may surface additional viable offers; or may conclude one offer is enough. This issue consolidates the decision across all 6 verticals.

#### Execution Protocol
1. **Explore** — Read all 6 playbooks after they land.
2. **Plan** — TaskCreate for decision sessions per vertical.
3. **Execute** — Per vertical, decide v1 offer count.
4. **Verify** — Decisions logged.

#### Tasks
1. Review R-4 zoos playbook — confirm Offer E + A (± B pending R-19).
2. Review R-5 aquariums playbook — v1 offer count.
3-6. Same for R-6 / R-7 / R-8 / R-9.
7. Log decisions in `docs/plans/BC-5879-multi-offer-decisions.md`.
8. If decisions surface new preset composition needs beyond Phase 4 baseline, file new issues.

#### Verification
- [ ] Decision file exists with per-vertical v1 offer count + rationale.
- [ ] Any new preset composition issues filed + linked.

#### Non-Goals
- Don't compose presets. Decision-only.

#### Sources
- All 6 playbook outputs.

---

## Appendix — Preservation of session artifacts

The following session artifacts are preserved as source material for the spawned issues:

- `docs/plans/BC-5879-zoos-ledger.md` — the zoos decision ledger. Primary source for R-4 zoos playbook.
- `docs/plans/BC-5879-plan.md` — the original BC-5879 plan (now superseded; kept for traceability).

The following are left as UNTRACKED scratchpad in the worktree and NOT committed (selective `git add` excludes them at PR time):
- `plugins/marketing/skills/email-copywriting/presets/list-building-zoos-aquariums.md`
- `plugins/marketing/skills/email-copywriting/presets/risk-reversal-zoos-aquariums.md`

(Reason: security hook blocked `rm` during session. Files are untracked so exclusion at commit time is enough — they never ship.)

## Appendix — BC-5879 rescope note

BC-5879 original title: "Fan out email-copywriting Active-tier preset library (10 files)"

BC-5879 revised title: "Email-copywriting preset library program — roadmap + foundational issues" (or similar)

BC-5879 revised description: points to this roadmap doc + lists the 20 spawned issues + notes the Active-tier Nites scope displacement (captured as a new follow-up issue if/when Nites active-tier verticals become priority).

BC-5879 revised verification: all 20 spawned issues exist in Linear with correct dependencies; this roadmap doc is committed; Zoos ledger is preserved.

## Session completion checklist

- [x] Roadmap doc written (this file) ✅ (2026-04-21 session)
- [x] Zoos ledger preserved at `docs/plans/BC-5879-zoos-ledger.md` ✅
- [ ] Bad Zoos drafts (`list-building-zoos-aquariums.md` / `risk-reversal-zoos-aquariums.md`) — still untracked scratchpad in worktree; excluded from commits. Not shipping.
- [x] All 20 issues filed in Linear with correct blockedBy / blocks wiring ✅ (2026-04-21 — 7 in first session pass, 13 in second session pass)
- [x] BC-5879 rescoped (title prefix `[Superseded by roadmap]`; description + comment pending final push)
- [x] Task list updated with final state
- [ ] Commit + PR (PR #170 draft open; pending final commit with 13 new BC-IDs)
