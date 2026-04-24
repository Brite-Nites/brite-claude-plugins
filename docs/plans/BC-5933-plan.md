---
issue: BC-5933
title: Compose aquariums preset files (v1 offer set per aquariums playbook)
roadmap-slot: R-11 of email-copywriting preset roadmap
worktree: .claude/worktrees/bc-5933/
branch: holden/bc-5933-compose-aquariums-preset-files
blocks: BC-5938 (preset library ship readiness)
blockedBy: BC-5929 (aquariums vertical playbook — shipped PR #191)
---

# Plan — aquariums preset composition (R-11)

## V1 offer set (from `aquariums.md` § V1 offer picks)

- **Primary: Offer 1 — Glow-Native 21+ Revenue-Share.** Every first-touch cold email for aquariums uses Offer 1 as default.
- **Tactical-secondary: Offer 2 — Production Finance E-analog.** Use when prospect research shows Director of Corporate Partnerships + city/CVB relationship + published economic-impact study (strongest fits: SC Aquarium / National Aquarium Baltimore / Virginia Aquarium / Great Lakes Aquarium).
- **Deferred: Offer 3 — Permanent Canvas.** Blocked on R-19; do NOT compose.

## 4 files to produce

Naming follows zoos + hotels precedent: primary = no offer slug, secondary = `-{offer-slug}`.

| # | Path | Offer | Shape |
|---|---|---|---|
| 1 | `plugins/marketing/skills/email-copywriting/presets/list-building-aquariums.md` | Offer 1 primary | Skeleton A — diagnostic hook + proof + free-asset CTA |
| 2 | `plugins/marketing/skills/email-copywriting/presets/risk-reversal-aquariums.md` | Offer 1 primary | Skeleton B — 21+ revenue-native breakeven guarantee |
| 3 | `plugins/marketing/skills/email-copywriting/presets/list-building-aquariums-production-finance.md` | Offer 2 secondary | Skeleton A — multi-stream funding + sponsor-precedent proof |
| 4 | `plugins/marketing/skills/email-copywriting/presets/risk-reversal-aquariums-production-finance.md` | Offer 2 secondary | Skeleton B — season-breakeven against sponsor + CVB + ad + ticket stack |

Each file: 5-key frontmatter → H1 → Hook → Step 1 skeleton (subject + body + wait_in_days) → Step 2 bump → Vertical anti-slop. Target 55–65 lines per SKILL.md § 3.

## Slot-fill defaults (from playbook + SKILL.md § 3)

- **`entity:`** `brite-labs` (aquariums are a Labs motion — architectural-gallery programmable-media overlay).
- **`vertical:`** `aquariums`.
- **Peer-venue defaults (`{LABS_PEER_VENUE}`):** mid-market anchors only — Newport KY, Aquarium of the Pacific (Long Beach), Adventure Aquarium NJ, Oregon Coast, SC Aquarium, Audubon New Orleans, Virginia Aquarium, Maritime Aquarium at Norwalk. NEVER enterprise flagships (Georgia / Monterey Bay / Shedd / New England / Seattle) in body copy — they may appear in anti-slop bullets only.
- **`{S4_PARTNER}`** = "S4 Lights" (supply-chain credibility per playbook § Vendor landscape, not competitor framing).
- **`{FREE_ASSET_NOUN}` candidates:** Offer 1 → "concept board for your 21+ zone" / "12-month programming calendar overlay"; Offer 2 → "production-finance deck" / "sponsor-target shortlist" / "economic-impact deck".
- **Recency anchors for hooks:** ticket-on-sale announcement, named title-sponsor pledge, published economic-impact study, new ED/CEO/Marketing & Admissions Revenue/Corporate Partnerships role change within 90 days.
- **Risk-reversal guarantee metric:** Offer 1 → incremental 21+ ticket revenue over prior-year baseline (aquarium ticketing-system report is cleanest data source). Offer 2 → season-breakeven against title-sponsor + CVB + ad-inventory + 21+ ticket + F&B/bar attach. First-season-breakeven-or-no-pay framing per BC-5932 task-2 pattern.
- **`{PILOT_ZONE_AREA}` examples** (Offer 1 variants): tank-fronting gallery wash, lobby architecture, gallery-ceiling overlay, reef-gallery facade, mezzanine programmable-media. Never tank-interior (husbandry line).

## Voice rules enforced in every file (playbook § Voice rules 1–5)

1. No enterprise flagships as body-copy analogs (rule 1).
2. No VP titles in salutations; use Executive Director / CEO / Director of Marketing & Admissions Revenue / Director of Corporate Partnerships / Director of Operations / Director of Guest Experience (rule 2).
3. Lead with revenue-diversification + economic-impact vocabulary, not aesthetic (rule 3).
4. No tank-engineering or husbandry-controlled lighting pitch (rule 4 — hard compliance line).
5. Use aquarium-native content vocabulary (bioluminescence / UV-reactive / jelly gallery / kelp-forest gallery / architectural lobby wash / gallery-ceiling overlay / mezzanine programmable-media), not consumer copy (rule 5).

## Anti-slop rules enforced in every file (playbook § Anti-slop rules 1–5)

Each preset's "Vertical anti-slop" section restates these as bullets, keyed to the offer:

- No banned consumer adjectives (`magical undersea`, `immersive wonder`, `dive into`, `dazzling`, `mesmerizing`, `enchanting`, `shimmering`, `breathtaking`, `captivating depths`, `ocean magic`, `sea of wonder`, `under the sea`).
- No species name-dropping (sharks / jellies / octopuses / seahorses / specific tank names). Use "your collection", "your flagship gallery", "your tank galleries", or named public-program.
- No tank-interior or husbandry-controlled pitch (chroma-match coral, circadian-match jelly tanks) — architectural-gallery overlay only.
- No "dive-into" / "sea of" / "tides of" / "swimming in" metaphors. Replace with operator-native verbs (install, program, underwrite, measure, amortize).
- No generic "ROI uplift" without named aquarium metric — use 21+ ticket revenue / F&B / bar attach per-cap / membership conversion / regional economic-impact share / sponsor-inventory sell-through.
- Plus EB-format anti-slop inherited from SKILL.md § 8 (no `{{`, no `<p>`, no em-dash in body, no `{FIRST_NAME}` in subject, exactly 2 steps, sign-off spintax).

Cross-vertical guard (from playbook § Explicitly adjacent, not competitive): NOT as bullets in body anti-slop, BUT enforced at compose-time — do not frame Moment Factory / MK / Tianyu as Brite competitors at aquariums. Moment Factory = absent at US aquariums (4th-instance inversion, first demotion direction). MK = adjacent (matches zoos framing, not hotels). Tianyu = mechanically excluded (humidity / footprint / portfolio evidence).

## Persona gate (playbook § Buyer personas)

Primary decision-maker: **Executive Director / President & CEO** (often dual-hatted as "VP & Executive Director" at mid-market — Newport KY + Adventure NJ pattern). Co-primary (numerate buyer for Offer 1): **Director of Marketing & Admissions Revenue**. Sponsor-inventory buyer (lead for Offer 2): **Director of Corporate Partnerships**. Do NOT address "VP Revenue" or "Director of Adult Programs" — those are enterprise-only / don't exist at mid-market.

## File-by-file slot plan

### File 1 — `list-building-aquariums.md` (Offer 1 primary, Skeleton A)

- `when:` After-hours program season window (Jun–Aug summer Glow Nights, year-round 21+ Night Dive / After Dark cadence, Nov–Jan holiday overlay), ticket-on-sale announcement, named title-sponsor pledge, published economic-impact study, or new ED/CEO/Marketing & Admissions Revenue/Corporate Partnerships role change within 90 days.
- `situation_mining_row:` Aquariums, Active tier fan-out row (SKILL.md §3 Brite-adaptation; email-copywriting preset roadmap R-11).
- Hook waterfall: (1) named title-sponsor pledge (GEICO / UPMC / Abita precedents cite), (2) ticket-on-sale announcement ($39.95–$59.99 range), (3) published economic-impact study, (4) role change within 90 days. Open with revenue outcome; conservation/mission framing lives in paragraph 2+ (mirror BC-5920 zoos gate).
- Step 1 skeleton: Skeleton A adaptation with Offer 1 slot fills. `{RECENCY_ANCHOR}` / `{PILOT_ZONE_AREA}` / `{LABS_PEER_VENUE}` / `{S4_PARTNER}` / `{FREE_ASSET_NOUN}`. Commercial structure: Brite underwrites install against 3–5 year programmable-media lease + revenue-share on incremental 21+ revenue.
- Step 2 bump: offer stands, scope around whichever revenue-stream is most load-bearing — 21+ ticket lift, F&B/bar attach, or membership-uplift conversion.
- Vertical anti-slop: 10–12 bullets per playbook § Anti-slop + peer zoos/hotels pattern.

### File 2 — `risk-reversal-aquariums.md` (Offer 1 primary, Skeleton B)

- `when:` Committee-heavy procurement, large multi-stream revenue-share commitment, or aquarium leadership requesting a performance underwrite before Year 1 sign.
- `situation_mining_row:` Aquariums, Active tier fan-out row T4 variant.
- Guarantee metric: first-season incremental 21+ ticket revenue over prior-year baseline, measured via aquarium ticketing-system report. Follows BC-5932 task-2 first-season-breakeven-or-no-pay pattern. Install fee not billed until 21+ revenue baseline is met.
- `{BASELINE_TERMS}` operator-filled at draft time — names the revenue streams counted toward breakeven (21+ ticket revenue, F&B/bar attach, membership conversion uplift).
- Step 2 bump: specificity as credibility — names which line items count toward breakeven (gate-scan 21+ ticket revenue + F&B/bar paid commitments + membership conversion measured against install fee at season close).

### File 3 — `list-building-aquariums-production-finance.md` (Offer 2 secondary, Skeleton A)

- `when:` Aquarium has existing Director of Corporate Partnerships + city/CVB relationship + published economic-impact study (strongest fits: SC / National Baltimore / Virginia / Great Lakes / Audubon / Florida Aquarium). NOT when sponsor-pipeline is early-stage (6–9 month close cycle is too long for first-install trust).
- `situation_mining_row:` Aquariums, Offer 2 (production-finance E-analog) tactical complement (SKILL.md §3 Brite-adaptation; email-copywriting preset roadmap R-11).
- Hook waterfall: (1) named title sponsor already running at peer aquarium (GEICO/YuleTides + UPMC/Wild Illuminations + Abita/Scales & Ales), (2) published economic-impact figure (National Baltimore $430M / SC $378M / Virginia $250M / Great Lakes $30M city-anchored), (3) CVB partnership press or city-council cultural-initiative vote, (4) Director of Corporate Partnerships role change.
- Step 1: production-finance orchestration framing — Brite runs title sponsor close + city/CVB partnership + ad revenue on DMX-pixel inventory, aquarium contributes near-zero capital. Cite named sponsor precedent verbatim (GEICO / UPMC / Abita) + matching impact-study number for the aquarium's own city.
- Step 2: scope around which revenue stream is most load-bearing — title-sponsor close, city-partnership underwrite, or ad inventory on pixel stack.
- `{FREE_ASSET_NOUN}`: "production-finance deck" / "economic-impact deck" / "sponsor-target shortlist".

### File 4 — `risk-reversal-aquariums-production-finance.md` (Offer 2 secondary, Skeleton B)

- `when:` Multi-stream production-finance commitment with sponsor + city/CVB + ad stack, committee-heavy procurement, or aquarium leadership requesting performance underwrite before signing Year 1.
- `situation_mining_row:` Aquariums, Offer 2 fan-out row T4 variant.
- Guarantee metric: first-season-breakeven against title-sponsor + CVB co-funding + ad-inventory pre-commits + incremental 21+ ticket revenue + F&B/bar attach + membership-conversion uplift, measured at season close.
- `{BASELINE_TERMS}` names the full line-item stack — sponsor paid commitments, CVB public-dollar partnership, ad-inventory pre-commits, 21+ ticket revenue, F&B attach.
- Step 2: specificity of line items as credibility (mirror zoos risk-reversal T4 tone).

## Tasks (checkpoints)

1. File 1 compose → self-check 5 frontmatter keys, `<br><br>` breaks, no `{{`, no `<p>`, no `—` in body, no `{FIRST_NAME}` in subject, 2 steps only, sign-off spintax, 10+ anti-slop bullets, peer venues mid-market only.
2. File 2 compose → same self-check + guarantee metric is 21+ ticket revenue not vanity.
3. File 3 compose → same self-check + sponsor precedents cited by name.
4. File 4 compose → same self-check + guarantee covers full multi-stream stack.
5. Anti-slop grep pass across all 4 files (no `{{`, no `<p>`, no em-dash in body, no `{FIRST_NAME}` in subject, no banned adjectives, no enterprise-flagship as body-copy default ICP).
6. `./scripts/validate.sh` exit 0 + `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exit 0.

## Precedent flags (for `/workflows:ship` compound-learnings pass)

- If Offer 2 tactical-secondary composes without dogfooding friction AND Offer 1 primary composes cleanly → potential 2nd-instance precedent on the "primary-offer-no-slug + tactical-offer-slug" naming convention (zoos/hotels/aquariums = 3 instances → eligible for architecture promotion).
- If the persona-set pre-compose gate from the playbook (ED + Marketing & Admissions Revenue + Corporate Partnerships, NOT VP titles) survives unchanged through preset composition → extends BC-5921 task-1 (hotels) / BC-5922 task-2 (ski) / BC-5923 task-1 (stadiums) / BC-5930 task-2 (casinos) persona-gate chain. Would be 5th-instance confirmation at preset-composition surface (vs research-playbook surface) — pattern-class extension candidate.
- If Moment Factory demotion framing (absent-at-aquariums vs rare-at-zoos/hotels, primary-at-ski) shows up cleanly in anti-slop bullets → 5th-instance extension of BC-5921 task-1 cross-vertical vendor-landscape pattern (hotels promote → ski promote → stadiums novel-native → casinos no-inversion → aquariums demote). First quantitative test of the "demotion direction" added in BC-5929.
