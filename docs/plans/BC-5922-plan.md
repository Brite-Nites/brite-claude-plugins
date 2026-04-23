# BC-5922 — Create ski-resorts vertical playbook (R-8)

**Linear:** https://linear.app/brite-nites/issue/BC-5922
**Branch:** `holden/bc-5922-ski-resorts-playbook`
**Worktree:** `.claude/worktrees/bc-5922/`
**Output:** `plugins/marketing/references/vertical-playbooks/ski-resorts.md`
**Peer structural reference:** `plugins/marketing/references/vertical-playbooks/zoos.md` (BC-5920); hotels-resorts.md (BC-5921) also relevant — hospitality-adjacent.
**Pattern lineage:** R-4 zoos (BC-5920) → R-7 hotels-resorts (BC-5921) → **R-8 ski-resorts (this)** → R-3..R-6 aquariums/casinos/sports-stadiums.

## Goal

Compose the ski-resorts playbook (Labs entity, regional/mid-market ICP). Fresh research required — unlike zoos where a BC-5879 ledger pre-scoped Tier-A decisions, ski has no prior ledger. Output is a single new reference file read by BC-5936 (ski-resorts preset composition), BC-5946 tam-mapping when ported, and future situation-mining.

## Context (from issue body + peer playbooks)

- **Thesis:** village-dwell / après-ski economics are Brite's wedge. Village F&B tenancy is the second profit center. Mid-market regional (Vermont / Michigan / Montana / NY / NH) is ICP volume; Vail / Deer Valley / Aspen enterprise are slow procurement and not ICP. Brite's zone is the village — NOT lift-line or on-mountain operations.
- **Prescribed personas (issue directive):** VP Village Operations / Director of Guest Services / F&B Director; explicitly NOT Lift Operations.
- **Prescribed voice rules:** don't pitch to Lift Ops; don't reference Colorado/Utah enterprise resorts as default; don't frame as holiday-only (season-long village is the motion); no "magical" / "winter wonderland" buzzwords.
- **Prescribed verification:** `grep -ci 'magical\|winter wonderland'` must return matches only in anti-slop "don't" bullets (i.e., anti-slop rules MAY quote banned phrases; voice rules + other prose MUST NOT).

## Departures from peer pattern (gate-confirmed at pre-compose)

Track deviations from zoos.md / hotels-resorts.md shape here with reasoning. Required by BC-5921 precedent task-2 (research-grounded directive correction with pre-compose gate). Gate fired 2026-04-23 after T1 research; user approved research-backed personas + Moment Factory inversion.

- **Research provenance footer (§ Sources).** Research is fresh (no BC-5879-style ledger); playbook frontmatter cites "BC-5922 R-8 research grounding (2026-04-23)" as the source — matching hotels-resorts.md frontmatter shape (fresh research).
- **Persona directive correction (gate-confirmed).** Issue directive prescribed "VP Village Operations / Director of Guest Services / F&B Director." R-8 research confirmed "VP Village Operations" is enterprise-only (Park City, Purgatory — Vail/POWDR-tier). Regional independent ICP titles: GM + F&B Director + DOSM (or Dir Sales & Guest Services) + Owner-Operator, with optional Sr Director Base Area / Village Ops at 300K+ visit properties with dedicated village real estate. Pre-compose AskUserQuestion 2026-04-23; user gate-confirmed research-backed set. § Buyer personas preamble documents the correction; Lift Operations still explicitly named as non-target per AC. Matches BC-5921 task-2 precedent (hotels GM/Dir Revenue/DOSM/Owner-Operator correction).
- **Moment Factory cross-vertical inversion (gate-confirmed) — 2nd instance of BC-5921 task-1 pattern.** R-8 research surfaced Moment Factory as a primary ski-resort competitor with SAM-editorial endorsement and three named cases: Vallea Lumina (Whistler 2018), Alta Lumina (Les Gets), Tonga Lumina (Tremblant). Zoos framing ("projection/immersive — rare at zoos") is wrong for ski. Pre-compose AskUserQuestion 2026-04-23; user gate-confirmed primary-with-inversion-subsection approach. § Vendor landscape promotes Moment Factory to primary ski archetype; § Explicitly adjacent, not competitive (ski-specific) subsection names the inversion from zoos framing + notes Brite differentiator is form-factor (ambient village infrastructure) not capability (both compete for resort capital allocation). Files second instance of BC-5921 task-1 cross-vertical inversion pattern.
- **MK Illumination framing returns to adjacent-not-competitive.** R-8 research confirmed MK has deep European alpine-village precedent (Seefeld 2019, Austrian Railway partnership, 3km String Lite, 50K light points) but NO evidenced US ski-resort base-village practice. Unlike BC-5921 hotels inversion (MK is direct competitor at US hospitality), at US ski villages MK returns to zoos-style framing with an **active-watch flag** — if MK enters US ski-village market with a named account, reclassify. § Vendor landscape — Explicitly adjacent, not competitive (ski-specific) documents this reasoning; § How to use anti-pattern flag guards against silent lift of hotels inversion without US ski-village evidence.
- **No ski-unique vendor archetype added (BC-5921 task-3 test negative).** R-8 research tested torchlight-parade orchestration (in-house operator tradition, NOT a vendor archetype), winter-festival producers (Luminothérapie/LUMINO, Igloofest — IP exists but no US ski-resort deployment), ski-resort AV integrators (same pool as hotels per BC-5921 finding), ice/snow-sculpture teams (in-house or regional art commissions). None surfaced as a genuinely vertical-unique archetype warranting BC-5921-task-3 inline add. Playbook does not extend the shared vendor-landscape taxonomy at ski.
- **Lantern-festival "more decisively adjacent than at zoos" framing.** R-8 surfaced that lantern-festival pathway format is STRUCTURALLY incompatible with ski-resort village footprints (steep, irregular, snow-bound vs. flat parkable 6–8-week footprints). § Vendor landscape names this explicitly rather than lifting zoos' "Tianyu dominant at zoos" framing. Minor deviation from peer pattern, captured in prose not as a subsection.
- **"Ski-resort" entity canon.** Ski-resort is Labs (experiential-lighting motion) per issue body directive — aligns with Labs. No Nites/Labs scope gate needed.
- **Tianyu URL swap during AC sweep.** Original URL `tianyuculture.us/tianyu-lantern-festival-2024-2025-recap-a-magical-year-of-lantern-shows-across-the-u-s` contained "magical" in slug, violating the AC `grep -ci 'magical\|winter wonderland'`-matches-only-in-anti-slop-bullets check. Swapped to `tianyuculture.us/about-us/` + `prnewswire.com/.../tianyu-arts--culture...-dallas-...` pair, preserving the citation without the literal-grep trap. Files second instance of BC-5920 task-3 literal-grep-trap pattern (first was the "lantern vendor" rule body); here the trap is in a URL slug rather than the rule body. Worth a lightweight precedent note at compound-learnings time.

## Tasks

Task numbering follows the issue body. Each task has exact file paths, specific content outcomes, and verification.

### Task 1 — Research agent brief + run

**Goal:** Fresh research on ski-resort experiential-lighting landscape, Brite's village-dwell thesis, program economics, and voice guardrails.

**Agent:** `general-purpose` (WebSearch + WebFetch); ideally Haiku for speed, but Opus/Sonnet acceptable.

**Brief (paste into agent prompt verbatim):**

> You are researching the US mid-market ski-resort experiential-lighting landscape for a Brite-internal vertical playbook. Goals:
>
> 1. **Vendor landscape (ski lens).** Which experiential-lighting vendors have named ski-resort case studies? Explicitly test: (a) does the lantern-festival archetype (Tianyu Arts & Culture, Illuminight) appear at ski resorts — confirm / refute with case studies; (b) does the projection/immersive archetype (Moment Factory, Limelight, Christie) appear at ski-resort villages — confirm / refute; (c) holiday specialty installers — which regional ski-village installers exist and which resorts do they serve; (d) does MK Illumination have US or European ski-village positioning (hospitality arm extends to ski?); (e) are there ski-resort-unique vendor categories — winter-festival producers, torch-parade orchestrators, ice/snow-sculpture teams, AV integrators with ski-resort practices?
>
> 2. **Popular programs.** What seasonal programming runs at ski-resort villages (village holiday light overlays, après-ski F&B ambiance lighting, holiday opening weekends Thanksgiving/Christmas/New Year's Eve, spring festivals, mid-winter village programming)? Cite specific resorts, programs, and trade-press coverage where possible. Target mid-market regional properties: Vermont (Stowe, Stratton, Okemo, Killington), Michigan (Boyne, Crystal Mountain, Shanty Creek), Montana (Big Sky, Whitefish, Bridger Bowl), New York (Hunter, Windham, Gore, Belleayre), New Hampshire (Bretton Woods, Loon, Waterville Valley). Enterprise resorts (Vail, Deer Valley, Aspen, Park City) are reference-only — name them as ceiling references, not ICP.
>
> 3. **Buyer motivations (Brite's wedge).** Verify or refute the thesis: village-dwell-time extension, F&B tenant retention (village F&B operators pay rent; empty village → churn), post-lift-close revenue capture (après-ski 3pm–9pm), destination-branding for multi-season occupancy. Cite any public sources on ski-resort village economics (per-cap spend, dwell time, F&B share of resort revenue, tenant-retention benchmarks).
>
> 4. **ICP — who to target.** Confirm: regional mid-market independents and small-group operators are ICP; enterprise flagships (Vail Resorts, Alterra, Aspen Skiing Co) are NOT ICP because of multi-year procurement and corporate brand standards. Per-resort key-count analog: skier-visits/year or beds-in-village as the scale proxy. Cite NSAA (National Ski Areas Association) published data on mid-market vs enterprise operator counts where available.
>
> 5. **Buyer personas.** The BC-5922 issue body prescribes: VP Village Operations / Director of Guest Services / F&B Director, explicitly NOT Lift Operations. **CHALLENGE THIS:** test the actual titles that exist at 500-2,000-SAD regional ski-resort properties. Are VP-titled Village Operations roles enterprise-only? What are the actual independent / regional titles — GM? Director of Mountain Operations? Director of Hospitality? F&B Director? Director of Real Estate (where village is owned)? Cite public job listings, LinkedIn title patterns, NSAA workforce data, or Ski Area Management trade coverage where possible. **Output a research-grounded persona set if the issue's VP titles don't exist at the ICP.**
>
> 6. **Recency signals ski resorts leak publicly.** What signals are public — trade press (Ski Area Management, SAM Magazine, Powder, Ski Magazine), NSAA announcements, press releases on village F&B tenant signings / capital projects / new GMs / season-opening dates / snow-making investment? Decay windows per BC-5922 peer pattern.
>
> 7. **Program economics.** Lift ticket prices (single-day, season-pass, IKON/Epic parity for independents), village revenue per visitor, F&B share of resort EBITDA, skier-visits per season at mid-market vs enterprise, peak-week compression patterns (Christmas-to-New-Year, MLK, Presidents), shoulder-season programming attempts (mud-season April–May, summer), snow-making capex cycles.
>
> 8. **Good-vs-bad program taxonomy.** What compounds at ski resorts vs burns out — dynamic vs static installations, village flow patterns, après-ski activation windows, snow-sensitivity of installations, vendor-switch cost after one season learned-site.
>
> 9. **Voice vocabulary — positive and negative.** Words/phrases that resonate with ski-resort operators (per-cap / per-visit economics, après-ski, compression, village F&B, dwell time, snow-week programming). Words/phrases that signal vendor-speak: "magical", "winter wonderland", "enchanting snowscape", "holiday charm", "alpine wonderland". Confirm the BC-5922 issue-body banned list or extend it.
>
> 10. **Enterprise anchor references.** Name-drop evidence of high-budget ski-resort installations at enterprise flagships (Vail Resorts holiday programming, Deer Valley, Aspen, Park City, Whistler-Blackcomb, Beaver Creek) — for ceiling citations, NOT as ICP guidance.
>
> **Output format.** A structured research memo with numbered sections matching the 10 questions above. Cite URLs inline for every public claim. Where a claim is inferred (not public), mark "(inferred from [source type] — [brief reasoning])". Do not make up specific customer names or dollar figures. If the research surfaces a directive conflict with the BC-5922 issue body (most likely: persona titles), flag it at the top of the memo so the pre-compose gate can run.
>
> **Length target.** 2,000–3,500 words. Comprehensive enough to ground a playbook; focused enough to read in 10 minutes.

**Verify:** research memo written to `docs/research/bc-5922-ski-resorts-research.md` (or kept inline in the conversation — decide based on length). If directive conflict surfaces → Task 1.5 pre-compose gate.

**Estimate:** 8–15 minutes agent runtime + 5 minutes human skim.

### Task 1.5 — Pre-compose gate (conditional on Task 1 outcome)

**Triggers:**
- Research contradicts issue body's persona directive (VP Village Operations / Director of Guest Services / F&B Director).
- Research surfaces MK Illumination as a genuine ski-village competitor (inversion per BC-5921 task-1).
- Research surfaces a ski-unique vendor archetype worth inline add (per BC-5921 task-3).

**Gate mechanism:** Single AskUserQuestion, 1–3 questions max (per memory `feedback_one_question_at_a_time.md`: ask one at a time UNLESS the questions are affecting adjacent sections and batching saves round-trips — BC-5920 task-2 pattern). Each question offers 3 concrete options: (a) use research-backed, (b) keep issue directive, (c) hybrid.

**Verify:** user gate-confirm recorded before composition begins; Departures section updated.

**Estimate:** 1 round-trip (3–5 min human).

### Task 2 — Integrate research into playbook structure

**Goal:** Decide what the playbook includes vs. defers. Per issue body, all 9 sections are required.

**Action:** Write the playbook scaffold — frontmatter + preamble + 9 section H2s + "How to use this reference" footer — into `plugins/marketing/references/vertical-playbooks/ski-resorts.md`. Scaffold uses:
- Frontmatter: `source: BC-5922 R-8 research grounding (2026-04-23); public filings + trade press cited inline` + `license: Brite-originated; distilled from first-party session research, no upstream port`
- Preamble: purpose + consumer list + vertical scope (mid-market regional only; enterprise out of scope) + "brief comparison to zoos / hotels-resorts peer playbooks" (1–2 sentences per BC-5921 preamble pattern)
- 9 H2s in this order (matches zoos / hotels-resorts): Vendor landscape (ski lens) → Buyer personas → Recency signals ski resorts leak publicly → Program economics → Good-vs-bad program taxonomy → Offer candidates → V1 offer picks → Voice rules → Anti-slop rules → How to use this reference

**Verify:** file exists; 9 H2s present; frontmatter valid YAML.

**Estimate:** 5 minutes.

### Task 3 — Write § Vendor landscape (ski lens)

**Goal:** Filter the 4 shared archetypes through ski-specific evidence + add the per-vertical adjacent-not-competitive subsection (BC-5920 task-1 pattern).

**Shape (follow hotels-resorts.md § Vendor landscape pattern):**
- Preamble: "The experiential-lighting vendor archetypes defined in [`../experiential-lighting-vendor-landscape.md`](../experiential-lighting-vendor-landscape.md) apply to ski resorts with a vertical-specific weighting. [+ any per-vertical additions from research.]"
- 4 archetype paragraphs (lantern-festival / projection-immersive / holiday-installer / LED-retrofit) — each: dominant-at-ski / weaker / rare / adjacent, with ski-specific named case studies where research surfaced them.
- Ski-unique archetype paragraph IF research surfaced one (e.g., winter-festival producers, torch-parade orchestrators, ski-resort AV integrators) — add inline with BC-5921-task-3 justification.
- `### Explicitly adjacent, not competitive (ski-specific)` subsection — restate the S4 Lights + MK Illumination guard per BC-5920 task-1, adjusted for any MK inversion per BC-5921 task-1 findings.

**Verify:** 4+ archetype paragraphs present; S4 named as Brite partner; MK Illumination named (correct zoos-style OR inverted per research); ski-unique archetypes inline IF research surfaced any.

**Estimate:** 15 minutes.

### Task 4 — Write § Buyer personas

**Goal:** Persona set + offer-to-persona mapping + explicit non-target (Lift Ops).

**Shape:** 3–5 personas (3 if research collapses GM / Director of Guest Services / F&B Director into a tight trio; 5 if research breaks them apart). Each persona: title, remit, P&L authority, which Brite offer fits, offer-signing fears, decay-window / recency-signal alignment.

**Directive handling:** If pre-compose gate resolved to research-backed titles, open § Personas with preamble documenting the correction (matches hotels-resorts.md BC-5921-task-2 precedent). If resolved to keep-issue-directive, write as-prescribed and note in Departures.

**Non-target rule (mandatory per issue AC):** § Buyer personas must explicitly name Lift Operations as NOT a target (AC: "§ Buyer personas explicitly names VP Village Operations / Director of Guest Services / F&B Director AND explicitly rules out Lift Operations as a target"). If personas deviate from the issue directive, the "rules out Lift Operations" assertion remains — that's the vertical's Brite-zone guard.

**Verify:** each persona has offer mapping; Lift Operations explicitly named as non-target; if directive deviation, Departures section captures it.

**Estimate:** 15 minutes.

### Task 5 — Write § Recency signals ski resorts leak publicly

**Goal:** 5–6 signals with decay windows + surface (where to look).

**Mandatory signals (from issue body):**
- Village F&B tenancy announcements
- Après-ski programming launches
- Season-opening preparation cycles

**Extend with research (examples — refine per Task 1 output):**
- Role changes (new GM, new Director of Real Estate where village-owned, new F&B Director)
- Capital project press (snowmaking upgrades, lift replacements, village expansions)
- NSAA / Ski Area Management trade press coverage (season forecasts, compression date calendars, peak-week press)
- Season-pass announcements (Epic / IKON pricing, indie pass alliances)

**Shape:** paragraph per signal, with decay window (3–6 months / 6–12 / 12–24 / window-of-use / etc.) and cross-ref to `../shelf-life-patterns.md`.

**Verify:** ≥ 5 signals named; each has decay window.

**Estimate:** 10 minutes.

### Task 6 — Write § Program economics

**Goal:** Anchor numbers for ski-resort outbound.

**Coverage (per issue body):**
- Après-ski revenue-per-visitor benchmarks
- Village dwell-time targets
- Season-length seasonality (Thanksgiving–Easter standard; mud-season + summer programming are shoulder-season tests)

**Extend with research:**
- Lift ticket + season pass pricing (single-day, multi-day, season pass, IKON/Epic, indie pass)
- F&B share of resort EBITDA
- Skier-visits per season at mid-market vs enterprise (NSAA data where available)
- Village F&B rent benchmarks (if research surfaced)
- Peak compression: Christmas–NYE, MLK, Presidents, spring break
- Snow-dependency risk (snow-making capex, bad-season attendance decay)

**Shape:** bulleted + paragraph sub-sections matching zoos.md / hotels-resorts.md program-economics shape. Every number cited (URL) or marked "(inferred from BC-5922 research grounding)".

**Verify:** ≥ 4 anchor numbers; every number cited or marked inferred.

**Estimate:** 15 minutes.

### Task 7 — Write § Good-vs-bad program taxonomy

**Goal:** 4–5 dimensions that distinguish compounding programs from burning-out.

**Candidate dimensions (refine per research):**
- Dynamic vs static (animated / programmable vs static uplighting — zoos parallel)
- Village crowd-flow design (one-way loops vs uncontrolled flow — zoos parallel, may adapt to village geometry)
- Snow-dependency (installations that work in snow + no-snow years vs snow-only)
- Season-length vs holiday-only (long-horizon programming vs 6-week holiday-only burn)
- Vendor site-tenure (switching cost after one season-learned site — zoos parallel)
- Village F&B alignment (installations that activate F&B traffic vs "pretty" installations that don't move F&B per-cap)

**Shape:** 4–5 paragraphs; each dimension named with "good" vs "bad" framing, anchored where possible to research-surfaced examples.

**Verify:** ≥ 4 dimensions; each explicitly framed good vs bad.

**Estimate:** 10 minutes.

### Task 8 — Write § Offer candidates (≥3)

**Goal:** Hormozi-evaluated offers from R-1's `offer-design-frameworks.md`. Each offer: one-line statement + Hormozi mapping (Dream / Likelihood / Time Delay / Effort) + frontend deliverable + backend commitment + commercial structure + when-it-fits.

**Candidate offer shapes (adapt Zoos Offer A/B/E to ski):**
- **Offer A — Village Pilot Zone (tactical complement).** Single-zone programmable-media demonstration at a resort village with an incumbent installer; underwrite install for case-study rights + venue-native guarantee metric (village dwell-time / after-lift-close F&B per-cap / après-ski attendance delta — NOT photo-share).
- **Offer B — Permanent Village Backbone, Seasonal Dress (pending Brite Facilities sales-motion confirmation — matches Zoos Offer B pending R-19 pattern).** Year-round architectural programmable-media on village gateway / plaza / primary pathway, seasonal overlay included. Facilities / Director of Real Estate buyer.
- **Offer E — Village Production Finance (V1 primary).** Brite orchestrates multi-stream funding — local tourism-bureau partnership + F&B tenant co-marketing contribution + sponsor (regional beverage / outdoor apparel / bank) + ad revenue on DMX-pixel displays — designs composition, runs show, takes revenue-share on incremental village F&B / après-ski per-cap. Venue contributes near-zero capital.

**Extend with research IF it surfaces a ski-native offer angle:** e.g., a snow-compensated contingency offer (tied to snow-depth trigger), a multi-village bundle (independent operators in a regional alliance), a Board Room Cottage-industry play at family-owned boutiques, etc.

**AC bar:** ≥ 3 offers; each contains substrings "Hormozi", "frontend", "backend". Matches issue verification check.

**Verify:** grep-pass on "Hormozi" ≥ 3 in § Offer candidates; "frontend" ≥ 3; "backend" ≥ 3. Each offer has Hormozi-lever-named + frontend deliverable + backend commitment + when-it-fits.

**Estimate:** 25 minutes (largest section).

### Task 9 — Write § V1 offer picks

**Goal:** Primary + complements + pending + deferred labels.

**Shape (follow zoos.md / hotels-resorts.md pattern):**
- **Primary:** Offer E — Village Production Finance. Lead outbound with this unless account research surfaces an Offer-A-compatible fit.
- **Tactical complement:** Offer A — Village Pilot Zone. Use when prospect has long-tenured incumbent + decision-maker open to low-commitment test.
- **Pending (if applicable):** Offer B — Permanent Village Backbone. Pending Brite Facilities sales-motion confirmation (matches Zoos R-19 gate).
- **Deferred / folded (if applicable):** any Offer-D-style variant that research surfaces as structurally weaker; fold into E with reasoning (matches Zoos Offer D pattern).

**Verify:** primary named; ≥ 1 complement named; pending and deferred sections present even if empty (explicit "none at this stage" acceptable).

**Estimate:** 5 minutes.

### Task 10 — Write § Voice rules

**Goal:** 4–6 voice disciplines directly anchored to research + issue body.

**Mandatory rules (from issue body):**
1. Don't pitch to Lift Operations (the zone guard).
2. Don't reference Colorado/Utah enterprise resorts as default (Vail / Deer Valley / Aspen / Park City are ceiling references only, NOT ICP anchors).
3. Don't frame as holiday-only (season-long village is the motion).
4. No "magical" / "winter wonderland" buzzwords — but handle this one in § Anti-slop rules for the literal-grep-trap reasons (BC-5920 task-3 precedent). Voice rules may reference the discipline without quoting the banned phrases.

**Extend with research (examples):**
- Lead with village economics (per-cap, dwell, F&B), not aesthetic outcome (BC-5879 zoos-precedent generalization).
- Use "program" not "event" (zoos precedent transfers — season-long programming vs one-off event framing).
- Don't name-drop enterprise hospitality operators (Disney, Universal — hotels BC-5921 voice #2 transfers).

**Verify:** ≥ 4 rules; each anchored to a source (issue body / BC-5920 / BC-5921 / BC-5922 research); rule phrasing does NOT quote banned phrases from AC grep check (rules about "magical" / "winter wonderland" should describe the anti-slop discipline without quoting the phrases).

**Estimate:** 12 minutes.

### Task 11 — Write § Anti-slop rules (ski-specific)

**Goal:** 4–6 rules with the "magical / winter wonderland" literal-grep-passing construction.

**Mandatory coverage:**
- "No 'magical' / 'winter wonderland' / 'enchanting' / 'alpine wonderland' adjectives" — explicitly quote the banned phrases (AC allows matches in anti-slop "don't" bullets).
- No stadium / concert-rig language (zoos BC-5920 anti-slop #1 transfers — ski resorts aren't concert venues).
- No ski-technical jargon mis-use ("fall-line", "catch an edge", "bluebird day") — signals vendor trying too hard.
- No generic "ROI uplift" without named ski-specific metric (F&B per-cap, village dwell-time, après-ski attendance, compression-week booking lift).
- Lead with economic outcome; "magic of the mountains" / mission-speak framing lives in paragraph 2+ if at all (zoos BC-5920 anti-slop #5 transfers).

**Verify:** each rule explicitly phrased; `grep -ci 'magical\|winter wonderland' ski-resorts.md` returns matches ONLY in anti-slop section (not in voice rules, not in preamble, not elsewhere).

**Estimate:** 10 minutes.

### Task 12 — Write § How to use this reference + add README entry

**Goal:** Downstream-consumer map + anti-pattern flag.

**Shape (follow zoos.md / hotels-resorts.md):** three consumer categories (email-copywriting presets / tam-mapping / situation-mining) with which sections each reads. Anti-pattern flag for S4 / MK misframing.

**README update (per BC-5920 pattern):** add entry for `ski-resorts.md` in `plugins/marketing/references/README.md` under "## Contents" (`vertical-playbooks/` entries line — add `ski-resorts.md (BC-5922)` alongside zoos + hotels-resorts) AND under "## Expected consumers" (the `email-copywriting` preset composition entry — append ski-resorts to the BC-5932 / BC-5935 list as BC-5936).

**Verify:** § How to use present; README.md updated in both places.

**Estimate:** 5 minutes.

### Task 13 — Validate + verify AC

**Action:** Run validate + the issue's objective grep checks + PR-shape final sweep.

```bash
./scripts/validate.sh  # must exit 0 (baseline: 0 errors / 16 warnings)
grep -ci 'magical\|winter wonderland' plugins/marketing/references/vertical-playbooks/ski-resorts.md
# Expect matches ONLY in § Anti-slop rules "don't" bullets.
grep -c 'Hormozi' plugins/marketing/references/vertical-playbooks/ski-resorts.md  # ≥ 3
grep -c 'frontend' plugins/marketing/references/vertical-playbooks/ski-resorts.md  # ≥ 3
grep -c 'backend' plugins/marketing/references/vertical-playbooks/ski-resorts.md  # ≥ 3
grep -c '^## ' plugins/marketing/references/vertical-playbooks/ski-resorts.md  # ≥ 9
grep -E '(Lift Ops|Lift Operations)' plugins/marketing/references/vertical-playbooks/ski-resorts.md  # must match as non-target
```

**AC tick-pass (from issue):**
- [ ] File exists.
- [ ] All 9 sections present.
- [ ] § Buyer personas names VP Village Operations / Director of Guest Services / F&B Director (or research-backed equivalents if pre-compose gate triggered deviation) AND explicitly rules out Lift Operations.
- [ ] § Offer candidates ≥ 3; each contains "Hormozi", "frontend", "backend".
- [ ] § V1 offer picks names primary + complements.
- [ ] `grep -ci 'magical\|winter wonderland'` returns matches ONLY in anti-slop "don't" bullets.
- [ ] `./scripts/validate.sh` exits 0.

**Verify:** all 7 AC checkboxes tick.

**Estimate:** 5 minutes.

## Non-Goals

- Do NOT compose preset files — that's R-14 / BC-5936.
- Do NOT target enterprise flagship resorts (Vail / Deer Valley / Aspen / Park City) as default ICP.
- Do NOT pitch lift-line or on-mountain lighting (out of Brite's zone).
- Do NOT upstream ski-unique vendor archetypes to `experiential-lighting-vendor-landscape.md` (per BC-5921 task-3 — vertical-unique goes in the per-vertical file).

## Ship checklist

1. Single PR via `/workflows:ship`, assignee-rename per ship protocol.
2. PR title: `BC-5922: ski resorts vertical playbook (R-8 of email-copywriting preset roadmap)`.
3. PR body references: BC-5922 + peer BC-5920 / BC-5921 + blocks BC-5936 + BC-5926 + BC-5942.
4. Post-merge: compound learnings — file at least one precedent (research-grounded persona deviation IF gate fired; or first-time patterns if research surfaced them).

## Time budget

- Task 1 research: 10–20 min
- Task 1.5 gate (conditional): 3–5 min
- Tasks 2–12 composition: ~2 hours total
- Task 13 validation: 5 min
- /workflows:review: 10–15 min
- /workflows:ship: 5 min

**Total: 2.5–3 hours** from plan approval to merge. Matches BC-5920 / BC-5921 cadence.
