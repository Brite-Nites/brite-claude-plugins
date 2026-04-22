---
issue: BC-5920
title: Create plugins/marketing/references/vertical-playbooks/zoos.md
milestone: Marketing Plugin: GTM Workflows
precedent: BC-5918 (reference-file docs-only execution collapse + adjacent-not-competitive defensive guard + inline inferred-marker citations)
---

# BC-5920 — Zoos Vertical Playbook

## Goal

Distill the BC-5879 zoos ledger + BC-5918 vendor-landscape file + research grounding into `plugins/marketing/references/vertical-playbooks/zoos.md` — the authoritative reference consumed by future zoos-vertical marketing skills (email copywriting presets, vertical-targeted situation mining, creative-angle generation, TAM mapping). This playbook supersedes the zoos content embedded in the BC-5879 session ledger; the ledger stays as session artifact.

## Context & constraints

- **Precedent BC-5918 (docs-only execution collapse, 8/10)**: Sequential prose sections of one markdown file collapse into ONE Write call, not nine subagents. File-state contention + prose coherence + token efficiency all require the single-pass approach.
- **Precedent BC-5918 (adjacent-not-competitive, 9/10)**: The playbook MUST explicitly name S4 Lights (Brite partner) and MK Illumination (retail/urban, wrong buyer) as adjacent-not-competitive. Silent omission fails the fresh-reader test. This anchors the § Vendor landscape section.
- **Precedent BC-5918 (inline inferred-marker, 8/10)**: Every non-public claim gets `(inferred from BC-5879 session research)` or `(synthesized from BC-5879 zoos-ledger § X)`. Every public-source claim gets inline URL or publication name.
- **Precedent BC-5917 (frontmatter convention)**: Brite-originated reference files carry `source:` + `license:` frontmatter.
- **Linear gotcha (MEMORY.md)**: Linear Prosemirror save mangles lists inserted mid-document. Writing `.md` to disk is unaffected — mangling only applies to Linear issue bodies.
- **Ledger incompleteness**: Tiers B/C/D/F are "Pending" in `docs/plans/BC-5879-zoos-ledger.md`. This plan handles the gap at explicit check-in gates (T4 before voice, T5 before anti-slop), asking the operator for confirmation rather than inventing content.

## Departures from pattern

None anticipated. If execution surfaces a departure, log it inline in the final § Departures block of this plan before ship.

## Tasks

### T0. Pre-flight (sanity check, 1 min)

- Confirm current branch: `git branch --show-current` → should be `main` on entry; worktree will carry `bc-5920/zoos-playbook` after Step 7.
- Confirm source files exist at: `docs/plans/BC-5879-zoos-ledger.md`, `plugins/marketing/references/offer-design-frameworks.md`, `plugins/marketing/references/experiential-lighting-vendor-landscape.md`.
- Confirm target dir `plugins/marketing/references/vertical-playbooks/` does NOT yet exist (so T1 creates it).

### T1. Create vertical-playbooks directory

- `mkdir -p plugins/marketing/references/vertical-playbooks`
- No .gitkeep — the file created in T2 will populate the dir.

**Verify**: dir exists, is empty.

### T2. Draft zoos.md skeleton — frontmatter + H1 intro + 9 section headers

Per BC-5918 collapse precedent, this task sets up the **single Write call structure** but the actual prose sections are drafted in T3–T11 conceptually (implemented in a single Write at T11-end). Structure:

```
---
source: BC-5879 session deep-research findings (2026-04-21); BC-5879 zoos-ledger (2026-04-21); public filings + trade press cited inline
license: Brite-originated; distilled from first-party session research, no upstream port
---

# Zoos vertical playbook

<intro paragraph: what this playbook is, who reads it, what supersedes/doesn't supersede>

---

## Vendor landscape (zoos lens)
## Buyer personas
## Recency signals zoos leak publicly
## Program economics
## Good-vs-bad program taxonomy
## Offer candidates
## V1 offer picks
## Voice rules
## Anti-slop rules

---

## How to use this reference
```

Add `## Explicitly adjacent, not competitive` as a sub-section anchor inside § Vendor landscape (not a top-level H2, because the per-vertical file scopes the defensive guard to zoos specifically — S4 + MK framing already lives in the vendor-landscape file as a top-level H2).

### T3. Write § Vendor landscape (zoos lens)

Distill BC-5918 `experiential-lighting-vendor-landscape.md` through a zoos-specific filter. Content anchors:

- **Lantern festival producers** — Tianyu dominant at zoos (named zoo clients: Tulsa, Potawatomi, Maryland, Memphis, Saint Louis, Nashville, Dallas, Columbus, Woodland Park, Franklin Park). Production cost $400K–$1M+. (Citation: BC-5879 zoos-ledger § Research grounding.) Illuminight — Lincoln Park ZooLights 22 years.
- **Projection studios** — Moment Factory, Limelight, Christie Digital. Six- to low-seven-figure per install. Less common at zoos; more at aquariums and flagship museums. (Citation: BC-5879 session research.)
- **Holiday specialty installers** — regional fragmented vendor base; deploy–uplight–takedown. Mid-market budgets.
- **LED-retrofit vendors** — Goodlight, Orphek, EcoMedia. Wrong buyer (Facilities VP) + wrong motion at zoos (adjacent, not competitive).
- **Sub-section: § Explicitly adjacent (zoos-specific)** — Restate S4 Lights (Brite partner) + MK Illumination (retail/urban streetscape, wrong motion at zoos) in one-paragraph each.

**Verify**: no "lantern vendor" or "projection vendor" shorthand in body text (matches Voice rule from ledger §124). All named vendors have an inline citation or inferred-marker.

### T4. Write § Buyer personas — CHECK-IN GATE

Five personas the issue body explicitly names. Structure each as: **title + department** → **typical remit** → **which offer fits this persona** → **what they fear signing**.

- **CEO / President** — board-facing, cares about mission + attendance + sponsor pipeline. Signs Offer E when the production-finance deck lands with a title-sponsor pledge.
- **Executive Director** (smaller AZA-accredited zoos) — operates as CEO. Same shape as above.
- **Director of Corporate Partnerships** — sponsor-inventory buyer. Cares about title-sponsor precedent (Invesco QQQ, ComEd, CPS Energy). Offer E's sponsor-finance story lands here.
- **Marketing Director** — event-attendance funnel buyer. Cares about hotel-room-nights + membership-acquisition uplift + press-worthy imagery. Not the right buyer for Offer E directly (wrong P&L authority) but the coalition-builder who gets E in front of the CEO.
- **Facilities VP / Director of Operations** — Offer B (Permanent Backbone, Seasonal Dress) buyer when the zoo has year-round architectural lighting ambitions. Pending R-19 confirmation on whether Brite's Facilities-VP sales motion is funded.

⛔ **CHECK-IN GATE 1**: Before writing § Buyer personas, confirm with the operator:
- (a) Is the five-persona list above complete, or is one missing?
- (b) Is the Marketing Director framing (coalition-builder, not direct buyer) correct?
- (c) Is it safe to cite named title sponsors (Invesco QQQ, ComEd, CPS Energy) in a REFERENCE file that will be read by skills that compose outbound email?

### T5. Write § Recency signals zoos leak publicly

Issue body hints at: program announcements, capital-plan votes, role changes, ticket-on-sale dates. Expand to a taxonomy. Content anchors (from BC-5879 research grounding):

- **Program announcements** — trade press pickups (Blooloop, IAAPA), zoo PR releases announcing Nov–Jan holiday light programs or Jul–Sep summer variants.
- **Capital-plan votes** — city council agenda items approving zoo capital expansion (decay: 12–24 months; multi-year planning cycle).
- **Role changes** — new Director of Corporate Partnerships or new CEO hire (decay: 6–12 months; new hires run audit cycles).
- **Ticket-on-sale dates** — public announcement of pricing + dates tells you the program cost + scale.
- **Economic-impact study publication** — rare but high-signal (Denver Zoo, LA Zoo both publish); tells you the zoo has a tourism-bureau partnership angle already open.
- **Sponsor-pipeline announcements** — corporate-donor newsletters listing zoo as a funded partner (decay: 6 months).

**Verify**: each signal has a decay window or timing-of-use note. Cross-link to `shelf-life-patterns.md` for the decay framework.

### T6. Write § Program economics

Direct-lift from BC-5879 research grounding. Content:

- Outdoor zoo lights ticket: $18–$31 adult, $15–$22 child.
- Program length: ~30 nights, Nov–Jan standard; Jul–Sep warm-climate variants (Cleveland).
- Production cost range: $400K–$1M+ for Tianyu-tier; mid-market regional installers deliver at $150K–$400K.
- Attendance ceilings observed: 170K (LA Zoo month), 105K (Cleveland summer), 77K (Lincoln Children's winter).
- Program longevity: Columbus Zoo 37 years, Lincoln Park 30 years, Cleveland 1M+ cumulative attendees.
- Sponsor economics: 5–7 figure title-sponsor commitments (Invesco QQQ, CPS Energy, TXU Energy, ComEd, Meijer precedents).
- Family-of-four value ceiling observed: ~$100.
- Economic-impact anchor: Denver Zoo 85.1% net-new economic activity; 16,502 hotel-room-nights/yr attributable.

Cite BC-5879 session research inline. Cite public precedents (Denver Zoo study) by name.

### T7. Write § Good-vs-bad program taxonomy

Direct-lift from BC-5879 research grounding § Good-vs-bad:

- **Static vs dynamic** — uplit trees = bad; animation/kinetics/narrative = good.
- **Crowd flow** — one-way loops = good; two-way paths = disaster (cited via TripAdvisor complaints, BC-5879 session research).
- **Value ceiling** — $100 family-of-4 is the observed cap.
- **Animal-welfare integration** — communicated upfront (Dallas Illuminature, Columbus, Nashville Zoolumination all do this).
- **Year-over-year refresh > raw scale** — longevity compounds (Columbus 37 years).

### T8. Write § Offer candidates — A, B, D, E with Hormozi / frontend / backend evaluation

Each offer gets: **one-line offer statement → Hormozi mapping (Dream Outcome, Perceived Likelihood, Time Delay, Effort+Sacrifice) → Frontend deliverable → Backend commitment → Status note**.

- **Offer A — Pilot Zone** (tactical complement per ledger § A1 decision). Rendered concept board for a specific pilot area. Backend guarantee: dwell-time or attendance-uplift metric (not photo-share). Brite underwrites install cost for case-study rights.
- **Offer B — Permanent Backbone, Seasonal Dress** (pending R-19). Year-round architectural infrastructure on gateway/plaza that doubles as seasonal entry. Facilities-VP buyer. Subscription model.
- **Offer D — Superseded by E.** Original D was a variant of E without sponsor-finance orchestration; ledger decision folded it into E. Keep a one-paragraph entry naming the fold-in so future readers understand why D doesn't appear as a live offer.
- **Offer E — Production Finance** (V1 primary per ledger § A1 decision). Brite orchestrates title sponsor + city economic-dev + zoo-side sponsors + ad revenue. Venue near-zero capital. Rev-share on net. Tech stack: DMX-pixel curtains + pixel trees (S4 supply chain).

**Verify**: substrings "Hormozi", "frontend", "backend" all appear in this section (AC check).

### T9. Write § V1 offer picks

Direct-lift from ledger § A1 decision:
- **Primary: Offer E** — production-finance orchestration.
- **Tactical complement: Offer A** — pilot zone, with guarantee-metric fix (dwell-time or attendance-uplift, not photo-share).
- **Pending: Offer B** — blocked on R-19 (Brite Facilities-VP sales motion confirmation).
- **Deferred: Offer D** — folded into E.

**Verify**: all four letters (A, B, D, E) mentioned by letter in this section. Status words ("primary", "tactical complement", "pending R-19", "deferred") present verbatim.

### T10. Write § Voice rules — CHECK-IN GATE

Ledger gives one rule verbatim (§124): "Don't over-specify incumbent vendor type in body copy." Issue body adds: "don't name-drop enterprise venues like Disney, pitch to Operations not Marketing."

Proposed five rules for this section:

1. **Don't over-specify incumbent vendor type.** "Existing lighting vendor" / "incumbent" — not "lantern vendor" / "projection vendor". (Source: ledger §124.)
2. **Don't name-drop enterprise entertainment venues** (Disney, Universal) as analogs. Zoos read those as different category; the analog falls flat. Stay within zoo-precedent (Lincoln Park, Columbus, Nashville Zoolumination, Hogle Zoo).
3. **Pitch to Operations / Development, not Marketing** as first touch. Marketing Directors don't own the Offer E P&L authority. (Inferred from BC-5879 buyer-motivation analysis.)
4. **Use "program" not "event" or "activation"** — zoos operate on multi-season programs with YoY refresh logic, not one-offs.
5. **Lead with economic outcome** (hotel-room-nights, sponsor pipeline, attendance), not aesthetic outcome (light quality, design).

⛔ **CHECK-IN GATE 2**: Before finalizing § Voice rules:
- (a) Is rule #3 (Operations/Development-first, not Marketing) accurate for Brite's real sales motion? The ledger's buyer-motivation analysis names Marketing Director as one of five personas but the rule says "don't pitch them first."
- (b) Is rule #4 ("program" not "event") a real Brite voice discipline or my projection?
- (c) Any voice rule the operator wants to add from unrecorded zoos-vertical conversations?

### T11. Write § Anti-slop rules — CHECK-IN GATE

Issue body hints at: "no stadium/concert-rig language, no species name-dropping."

Proposed five rules:

1. **No stadium/concert-rig language.** "Ring of steel", "truss and rig", "FOH tower" — zoos aren't concert venues; this framing positions Brite as wrong-vendor-type. (From issue body.)
2. **No species name-dropping.** Don't pepper prose with "tigers", "elephants", "giraffes" — reads as trying too hard to be on-topic. Zoo directors know what lives at their zoo. (From issue body.)
3. **No "magical" / "wondrous" / "enchanting"** — consultant-speak that zeros out credibility on an attention-economy / economic-outcome buyer.
4. **No generic "ROI uplift"** without named metric. Zoo economics are specific (hotel-room-nights, membership conversion, per-cap spend) — use those.
5. **No AZA / conservation framing as opener** unless the rest of the email substantively supports it. Zoo directors read mission-framing from a vendor as performative.

⛔ **CHECK-IN GATE 3**: Before finalizing § Anti-slop rules:
- (a) Rule #3 (banned adjectives list) — does Brite have a canonical banned-word list elsewhere I should cross-link to rather than duplicate?
- (b) Rule #5 (AZA / conservation framing) — too strict? Some of Brite's real customer conversations may open with mission.
- (c) Any anti-slop rule from lived Hogle Zoo / S4 conversations the operator wants captured?

### T12. Write § How to use this reference (closer)

Mirror the closer section in `offer-design-frameworks.md` and `experiential-lighting-vendor-landscape.md`. Name the three downstream consumers:

- **email-copywriting preset composition** (BC-5932) — reads § Offer candidates + § V1 picks + § Voice rules + § Anti-slop rules.
- **tam-mapping** when/if ported (BC-5946 / BC-5950) — reads § Recency signals + § Program economics.
- **situation-mining** when ported — reads § Recency signals + § Good-vs-bad taxonomy.

### T13. Update `plugins/marketing/references/README.md`

Add a one-line entry under `## Contents` listing `vertical-playbooks/` with zoos as the first file. Update `## Expected consumers` to mention the email-copywriting composition consumer explicitly.

### T14. Run `./scripts/validate.sh`

Must exit 0. If it fails, capture the error, diagnose, do not proceed to AC verification.

### T15. AC verification — objective tick-pass

Run each check in order; all must pass:

1. `test -f plugins/marketing/references/vertical-playbooks/zoos.md && echo OK`
2. `for s in "Vendor landscape" "Buyer personas" "Recency signals" "Program economics" "Good-vs-bad" "Offer candidates" "V1 offer picks" "Voice rules" "Anti-slop"; do grep -q "## $s" plugins/marketing/references/vertical-playbooks/zoos.md || echo MISSING: $s; done`
3. `grep -E "Offer [ABDE]" plugins/marketing/references/vertical-playbooks/zoos.md | head -20` — must see A, B, D, E each cited by letter within § Offer candidates.
4. `grep -E "Hormozi|frontend|backend" plugins/marketing/references/vertical-playbooks/zoos.md | head -5` — all three substrings must appear.
5. `grep -E "primary|tactical complement|pending R-19|deferred" plugins/marketing/references/vertical-playbooks/zoos.md` — all four status words must appear in § V1 offer picks.
6. `grep -iE "Hogle Zoo|S4" plugins/marketing/references/vertical-playbooks/zoos.md` — both Hogle Zoo and S4 named.
7. `! grep -q "lantern vendor" plugins/marketing/references/vertical-playbooks/zoos.md` — negative check.
8. `./scripts/validate.sh` — exit 0.

## File-by-file change manifest

| File | Change | Net lines |
|------|--------|-----------|
| `plugins/marketing/references/vertical-playbooks/` | new dir | — |
| `plugins/marketing/references/vertical-playbooks/zoos.md` | NEW | +~250–330 |
| `plugins/marketing/references/README.md` | edit (add Contents + Expected consumers line) | +3 |

## Verification commands (inline, once per task)

- After T1: `test -d plugins/marketing/references/vertical-playbooks`
- After T14: `./scripts/validate.sh`
- After T15: all 8 grep checks pass

## Risks

- **Ledger-gap drift.** Writing T4/T10/T11 without the operator's check-in risks inventing zoos-vertical voice/anti-slop content that isn't research-grounded. Mitigation: explicit check-in gates before each of those three tasks.
- **Citation density.** BC-5918 set a ~15 inline-citation-marker precedent for the vendor-landscape file (110 lines). Zoos playbook will be 2–3× longer with more vertical-specific claims; expect 25–40 inline citations/inferred-markers. Don't skimp.
- **README drift.** Adding `vertical-playbooks/` to the contents table risks outdating the per-skill consumer list. Update § Expected consumers in the same edit.

## Departures from pattern

_(To be filled during execution if any surface.)_

## Rollback

`git checkout main && git worktree remove <worktree-path>` — no migrations, no infra, no external state.

## Estimated time

35–50 minutes including three check-in gates.
