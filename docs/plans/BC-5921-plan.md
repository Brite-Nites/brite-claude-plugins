# BC-5921 — Hotels & Resorts Vertical Playbook

Single-file reference at `plugins/marketing/references/vertical-playbooks/hotels-resorts.md`. R-7 of the email-copywriting preset roadmap. Fresh research required; hotels structurally differ from zoos.

**Issue:** [BC-5921](https://linear.app/brite-nites/issue/BC-5921) · **Priority:** High · **Milestone:** Marketing Plugin: GTM Workflows · **Parent roadmap:** `docs/designs/email-copywriting-preset-roadmap.md`

**Peer precedent:** BC-5920 zoos.md (PR #184, 240 lines, 9 sections, 25 inline citations). Use as structural template; do not reuse offer candidates or ICP priors blindly — hotel context is different.

**Blockers (all done):** BC-5917 offer-design-frameworks.md · BC-5918 experiential-lighting-vendor-landscape.md · BC-5919 email-copywriting skill cross-links · BC-5879 roadmap (superseded parent).

**Unblocks:** BC-5935 (compose hotels presets) · BC-5942 (multi-offer scope decision) · BC-5926 (roadmap completion).

## Execution plan

Ten tasks. T1 dispatches research; T2–T10 compose the file section-by-section in reader order, then validate.

### T1 — Dispatch research-agent for hotels & resorts vertical

- **Subagent:** `general-purpose` (with WebSearch + WebFetch in its toolset).
- **Brief scope:** hotel/resort experiential-lighting vendor landscape, popular hotel seasonal lighting programs, buyer motivations, ICP segmentation, good-vs-bad program taxonomy, content vocabulary — see T1 brief block in § Subagent briefs below.
- **Output:** inline research findings returned in the agent result. Do NOT save to a new docs/research/ file unless the findings are >2K words worth preserving separately — for this issue the findings flow straight into the playbook. If the agent's output is unusually thin (< ~800 words of usable material), stop and ask the user before composing.
- **Verify:** research output names ≥ 3 specific hotel lighting vendors (beyond Holiday Outdoor Décor), ≥ 3 named seasonal programs with scale/economics, ≥ 2 buyer-motivation threads distinct from zoos (rate premium, booking-window extension, direct-channel mix shift, destination differentiation).

### T2 — Frontmatter + preamble + cross-links

- Write the YAML frontmatter (`source:` cites T1 research + issue body + peer zoos.md; `license: Brite-originated`).
- Write the preamble paragraph (mirror zoos.md lines 6–12 structure: what the file is, vertical scope = hotels & resorts, downstream consumers).
- Preamble must name downstream consumers: BC-5935 preset composition, tam-mapping, situation-mining.
- Cite the Labs-entity resolution decision ("mixed Nites/Labs canon resolved to Labs for v1 preset" — from issue body).

### T3 — § Vendor landscape (hotels lens)

- Filter the four vendor archetypes from `experiential-lighting-vendor-landscape.md` through a hotel-specific lens (which archetypes dominate, which are rare).
- Name specific vendors surfaced in T1 research; cite inline as "(inferred from BC-5921 research grounding)" for un-sourced claims and "(per [trade press / filing / URL])" for sourced claims.
- Include a `### Explicitly adjacent, not competitive (hotels-specific)` sub-section — mirror the zoos.md lines 28–34 pattern. MK Illumination's retail/streetscape motion may surface more in hotels context; S4 Lights partnership framing applies.
- Per issue AC: § ICP explicitly differentiates boutique / regional / independent from Marriott/Hilton enterprise — place this in the vendor-landscape opening paragraph or early in § Buyer personas (wherever it reads most natural).

### T4 — § Buyer personas

- ≥ 4 personas. Per issue Task 4 naming: VP Revenue Management, VP Experience, GM, Director of Revenue. Evaluate whether to include additional personas from T1 research (Director of Marketing? Director of F&B? Owner-operator at boutique?).
- Per-persona: remit, P&L authority, what they care about, which offer they sign, fear-of-signing.
- Offer-to-persona mapping takes priority over titles — small hotels collapse roles, enterprise fragments further.
- Voice rule preview: "pitch VP Revenue Management not GM" (per issue Task 10) — set this up here in the persona framing, enforce in § Voice rules.

### T5 — § Recency signals

- 4–6 recency signals with decay windows. Per issue Task 5: package-marketing launches, destination-weekend announcements, new GM appointments, renovation press.
- Also consider T1 findings: loyalty program pushes, booking-mix reports, direct-channel investments, renovation completions, new F&B concept launches, ADR/RevPAR moves.
- Each signal: where it leaks publicly (trade press sources — Skift, Hotel News Now, STR; LinkedIn role alerts; press releases), decay window, why it matters for Brite outbound timing.

### T6 — § Program economics

- Anchor numbers: room-rate ranges (boutique $200–$500 ADR cited in issue), seasonal-package revenue uplift, direct-channel booking mix.
- From T1 research: Hard Rock Hollywood 2M-LED 24-acre 2025 install (Holiday Outdoor Décor-executed) as scale ceiling reference.
- Include at least one public-source economic anchor if research surfaces one (STR data, destination-marketing studies, hotel REIT filings).
- Every number either public-source-cited or marked "(inferred from BC-5921 research grounding)".

### T7 — § Good-vs-bad program taxonomy

- 4–5 dimensions distinguishing compounding hotel programs from burnout programs. Mirror zoos.md shape; dimensions may differ (e.g., hotels may trade "crowd flow" for "guest-vs-public mixing policy" and "animal-welfare integration" for "brand-aesthetic coherence").
- Each dimension: good pattern vs bad pattern, source citation or inferred-marker.

### T8 — § Offer candidates

- ≥ 3 offers (issue AC). Each with Hormozi / frontend / backend / commercial-structure / when-it-fits evaluation per R-1 framework.
- Do NOT reuse zoo Offer A/B/D/E verbatim (issue non-goal). The hotel offers may rhyme with zoos (e.g., pilot-zone analog, production-finance analog) but must be re-grounded in hotel economics and buyer motivations (room-rate lift, booking-window extension, direct-channel mix).
- Per issue context: destination-experience / rate-premium framing is the core worldview driver — this shapes the Offer A and the equivalent-of-Offer-E choices.

### T9 — § V1 offer picks

- Primary + complements with rationale. Minimum: name the primary offer and at least one complement OR explicit "deferred/pending" status for specific candidates.
- Rationale must cite Hormozi-denominator improvement or Abraham risk-reversal mechanism — not just "seems like a good fit."

### T10 — § Voice rules + § Anti-slop rules + validate

- **§ Voice rules:** ≥ 4 rules per issue Task 10. Mandatory rules from issue: (a) no enterprise-flagship name-drops (i.e., don't use Marriott Marquis / Waldorf as analogs — pitch fits boutique/regional), (b) no "romantic" / "ambiance" buzzwords in framing or voice rules (AC grep check), (c) pitch VP Revenue Management not GM.
- **§ Anti-slop rules:** ≥ 4 rules per issue Task 11. Mandatory from issue: (a) no commodity "lighting upgrade" framing, (b) no wedding-revenue-as-default-proof-point, (c) no urgency language.
- **AC trap (from BC-5920 task-3 precedent):** voice/anti-slop rules CAN cite banned phrases for illustration IF inside an explicit "don't" bullet. The zoos "lantern vendor" AC failure came from citing the banned phrase in the body of a voice rule, not inside a don't-bullet. Structure each rule as "**Don't [banned pattern].** [one-sentence why.]" to avoid this trap.
- Run `./scripts/validate.sh` — must exit 0 with 0 errors. Warning count should equal the 16-warning baseline; +1 warning is acceptable for a new file, investigate anything beyond that.
- Run the grep check from issue AC: `grep -ci 'romantic\|ambiance' plugins/marketing/references/vertical-playbooks/hotels-resorts.md` — all matches must be inside explicit don't-bullets in § Anti-slop rules or § Voice rules.

## Subagent briefs

### T1 research-agent brief (inline for reference)

```
Research the experiential-lighting vendor landscape for hotels and resorts, with emphasis on independent / boutique / regional properties (not enterprise Marriott/Hilton RFP procurement). Distinct from zoos: destination-experience thesis, rate-premium framing, booking-window extension as economic driver.

Specifically produce:

1. Vendor landscape (≥ 3 specific named vendors beyond Holiday Outdoor Décor that serve hotel experiential lighting): lantern-festival producers active in hotel vertical, projection/immersive studios hotels hire, AV integrators with hotel-focused practices, MK Illumination's corporate arm positioning in hospitality, any hotel-specific specialty installers.

2. Named seasonal programs with scale/economics (≥ 3): winter light packages, destination-weekend programs, holiday overlays at specific named properties. Include Hard Rock Hollywood 2M-LED install as a scale ceiling anchor. Cite specific trade press (Skift, Hotel News Now, Hospitality Net, local trade) where possible.

3. Buyer motivation threads (≥ 2 distinct from zoos):
   - Package-rate premium on seasonal weekends
   - Booking-window extension (getting Q4 bookings earlier)
   - Direct-channel booking mix shift (reducing OTA commissions)
   - Destination differentiation vs competing properties
   - Rate-premium / ADR uplift attributable to lighting programming
   Plus any others that surface.

4. ICP segmentation: boutique / regional / independent vs Marriott/Hilton enterprise. Characterize procurement speed, decision-surface size, relationship vs cold-outbound viability.

5. Good-vs-bad program taxonomy: what distinguishes hotel lighting programs that compound (YoY refresh, direct bookings, rate premium) from those that burn out (guest-complaint-driven, one-and-done, brand-incoherent).

6. Voice vocabulary: the language hotel revenue and operations leaders actually use. Which industry-insider phrasings signal "done the homework" vs which signal vendor-speak. Pay attention to STR metrics (ADR, RevPAR, occupancy), loyalty vocabulary, direct-channel terminology.

7. Anti-patterns observed: common vendor pitches hotels reject (generic "lighting upgrade," wedding-focused sales pitches pitched to rate/operations leaders, "romantic ambiance" language).

Cite sources inline as URLs where available. Flag inferred-from-research claims that don't have a specific source. Keep findings focused and actionable — I'll compose these into a Brite-voice playbook, so name names, give me numbers, avoid generic claims.
```

## Verification

Maps directly to the issue AC checklist. All items must clear before PR open.

- [ ] `plugins/marketing/references/vertical-playbooks/hotels-resorts.md` exists.
- [ ] All 9 sections present (Vendor landscape, Buyer personas, Recency signals, Program economics, Good-vs-bad taxonomy, Offer candidates, V1 offer picks, Voice rules, Anti-slop rules) — plus preamble and "How to use this reference" terminal section (mirror zoos.md).
- [ ] § ICP explicitly differentiates boutique / regional / independent from Marriott/Hilton enterprise.
- [ ] § Offer candidates ≥ 3, each with Hormozi / frontend / backend evaluation.
- [ ] § V1 offer picks names primary + any complements with rationale.
- [ ] `grep -ci 'romantic\|ambiance' plugins/marketing/references/vertical-playbooks/hotels-resorts.md` — matches only inside anti-slop / voice "don't" bullets.
- [ ] `./scripts/validate.sh` exits 0 (baseline: 16 warnings; ≤17 acceptable for new file).
- [ ] README.md `plugins/marketing/references/README.md` updated to list the new file under § Contents and relevant § Expected consumers line.

## Non-goals

- Do NOT compose preset files (`list-building-hotels-resorts.md`, `risk-reversal-hotels-resorts.md`). That's BC-5935.
- Do NOT reuse zoo offer candidates (A/B/D/E) verbatim. Hotel context is structurally different — destination-experience thesis, room-rate economics, boutique/regional ICP.
- Do NOT target enterprise-flagship brands (Marriott, Hilton, Waldorf, Ritz-Carlton) as default ICP. They are multi-year RFP procurement — wrong motion for cold outbound.
- Do NOT create a net-new docs/research/ hotel-ledger file unless T1 research exceeds ~2K words of preservation-worthy material (follow BC-5920 precedent — research flows straight into playbook, ledger only exists for foundational programs).

## Departures

Capture exec-time + review-time deviations from this plan here. Update retroactively per BC-5872 second sub-learning (plan-drift spans both exec-time AND review-time).

- **Persona set departed from issue Task 4 directive (exec-time, R-7 research grounding).** Issue specified VP Revenue Management / VP Experience / GM / Director of Revenue. Research established that VP-titled Revenue Management and Experience roles are enterprise-only; they do not exist at the 100–400-key independent ICP. Replaced with GM (primary) + Director of Revenue (co-primary where role exists) + DOSM (influencer) + Owner-Operator (primary at family/private-ownership). User gate-confirmed 2026-04-22. Playbook documents the correction in § Buyer personas preamble so future readers see the reasoning. Related: the "pitch VP Revenue Management not GM" voice-rule directive was converted to "Don't use enterprise-VP titles in outbound salutations" (voice rule #2) — same intent, updated title set.
- **Offer count locked at 3 (exec-time).** Issue AC requires ≥ 3 offers; plan T8 left offer count at author discretion. Composed A (tactical) / B (pending) / E (primary) mirroring zoos structural pattern. Offer D ("fee-for-service design director") considered and cut — doesn't match Brite's production-finance edge and would add noise without changing V1 picks.
- **Fifth vendor archetype added to § Vendor landscape (exec-time).** Zoos landscape covers 4 archetypes (lantern festivals / projection / holiday installers / LED-retrofit). Hotels surfaced a 5th — AV integrators with experiential practices (AVI-SPL XTG) — that is genuinely hospitality-unique and does not exist at zoos. Called out inline with the reasoning so future readers understand the delta vs zoos structural shape.
- **MK Illumination framing inverted for hotels context (exec-time).** Zoos playbook places MK in "Explicitly adjacent, not competitive" (retail/streetscape motion, wrong buyer for zoos). Hotels research shows MK runs hospitality-positioned campaigns with US + UK hospitality-specific pages and competes directly with Holiday Outdoor Décor-class installers. Hotels playbook moves MK INTO the primary vendor-landscape archetype list and adds a hotels-specific "Explicitly adjacent, not competitive" sub-section guarding against future lifts of the zoos-context framing.

## Precedents to watch for

- **BC-5920 task-1 (pattern-application, 7/10):** per-vertical adjacent-not-competitive restatement. T3 includes the `### Explicitly adjacent, not competitive (hotels-specific)` sub-section per this precedent.
- **BC-5920 task-3 (bug-resolution, 6/10):** AC literal-string trap — voice/anti-slop rules must structure banned-phrase citations inside explicit "don't" bullets, not in rule-body prose. T10 calls this out.
- **BC-5918 task-1 (architecture, 9/10, promotion-eligible):** adjacent-not-competitive defensive guard pattern. Mirrored by T3.
- **BC-5918 task-2 (pattern-choice, 8/10):** docs-only execution collapse — this plan has no code changes, no tests, no subagent review; validate.sh + grep AC + structural 9-section check are the only objective gates.
- **BC-5872 (pattern-application, 7/10):** plan-drift capture in review-loop tidy-up. § Departures above will receive review-time additions.
