# Plan: BC-5929 aquariums vertical playbook

**Issue**: BC-5929 — Create `plugins/marketing/references/vertical-playbooks/aquariums.md`
**Branch**: `holden/bc-5929-aquariums-playbook`
**Worktree**: `.claude/worktrees/bc-5929/`
**Tasks**: 9 (estimated 60–90 min total; research-agent dispatch is longest single step)

## Prerequisites
- Worktree at `.claude/worktrees/bc-5929/` on branch `holden/bc-5929-aquariums-playbook` (already set up, clean tree, main-parity at `79b7ec2`)
- Blockers BC-5917 (offer-design-frameworks.md) + BC-5918 (experiential-lighting-vendor-landscape.md) + BC-5919 (SKILL.md cross-links) — all shipped; files read during explore phase
- Design doc: `docs/designs/BC-5929-aquariums-playbook.md` (approved 2026-04-23)
- **Precedent alignment**: BC-5921 task-1/2/3, BC-5922 task-1/2/3, BC-5918 task-2 (docs-only single-pass collapse), BC-5920 task-2 (check-in-gate scaffolding), BC-5918 task-3 (inline parenthetical citation style)
- **CDR check**: skipped — Context7 quota exceeded this session
- Peer playbooks on disk for structural reference: `zoos.md`, `hotels-resorts.md`, `ski-resorts.md`

## Departures (to document in compound-learnings if they survive review)
- **Task 1 research brief includes aquarium-specific vendor archetypes** (Lightswitch / Christie Digital / Available Light / humidity-rated architectural firms) not in zoos/ski research scope — driven by issue Task 1 explicit callout; confirmed 5th archetype warranted.
- **Task 2 batched 3 gate questions** (BC-5922 task-2 established precedent for 2-question batch; extending to 3 questions — personas + Moment Factory framing + primary offer pick). Gate confirmed 2026-04-23 — user selected all 3 recommended options.

### Task 2 pre-compose gate outcomes (2026-04-23)

1. **Personas: research-backed set** — Executive Director / President & CEO (dual-hatted VP & Exec Director pattern per Newport KY + Adventure Aquarium NJ) / Director of Marketing & Admissions Revenue / Director of Operations / Director of Guest Experience / Director of Corporate Partnerships / Director of Development. Research confirmed: VP Revenue + Director of Adult Programs are enterprise-only; Director of Operations + Director of Guest Experience ARE real at mid-market (Newport KY confirmed). 3rd instance of BC-5921 task-2 pre-compose gate at distinct vertical + distinct persona surface.

2. **Moment Factory: full inversion → architecture 9/10 promotion.** Research found ZERO named US aquarium deployments — OdySea was misattributed (correct credit: Malvern Entertainment creative + Christie Digital tech + CCS integrator). Only Moment Factory aquarium-adjacent work globally is Aquascope at Futuroscope France (water-park, not aquarium). Dedicated § Explicitly adjacent, not competitive (aquariums-specific) subsection with 4-vertical inversion table (zoos: rare / hotels: rare-but-real / ski: primary / aquariums: absent). 3rd instance of BC-5921 task-1 elevates precedent to architecture 9/10 + standing recipe check in reference-file-pattern playbook. Also document OdySea misattribution correction inline for future authors.

3. **Primary offer: Glow-Native 21+ primary; Production-Finance tactical-secondary; Permanent Canvas deferred R-19.** Matches research ranking. Glow-Native has proven format (Newport $59.99 / AotP $44.95 / Audubon Scales & Ales $1.4M raised since 2010). Production-Finance stronger-than-expected warrant — aquariums have GEICO/YuleTides (Florida Aquarium), UPMC/Wild Illuminations (Pittsburgh), Abita/Scales & Ales (Audubon) named title-sponsor precedents.

### Mechanical applications (no gate needed — research strongly supports)

4. **5th archetype: architectural-lighting-design firms (aquariums-unique).** Lightswitch (Shedd Jellies + 4 others) + Fisher Marantz Stone (Georgia all 5 galleries) + CD+M (Georgia 4D theater / lantern wall / plaza / ballroom) + HLB (Seattle Aquarium Ocean Pavilion 2024, 50K sq ft LEED Gold) + Available Light (museum specialist since 1992). Stronger evidence than AV integrators had at hotels (BC-5921 task-3 1st instance). BC-5921 task-3 2nd instance — confirms pattern generalizes.

5. **Fact correction (Aquarium of the Pacific location).** Issue body and prior session context referenced "Aquarium of the Pacific, Newport Beach." Correct location: **Long Beach, CA.** Separate facility from Newport Aquarium (KY). Correct in playbook; do not carry the error forward.

6. **Tianyu exclusion mechanism (not just outcome).** State the mechanism explicitly: (a) high humidity in tank galleries degrades fabric/paper lantern substrates, (b) enclosed tank-room footprints don't accommodate sprawling outdoor lantern paths, (c) Tianyu's own portfolio shows zero aquarium deployments. Mechanism-explicit framing prevents future authors from re-proposing Tianyu at aquariums.

## Tasks

### Task 1: Dispatch research agent with aquarium-specific brief
**Files**: (none edited; research output captured in conversation + summarized inline at Task 3)
**Why**: Issue Task 1 explicitly requires a research-agent deep-dive. Without it, playbook §§ Vendor landscape / Buyer personas / Program economics / Offer candidates are hypothesis, not evidence.

**Implementation**:
1. Spawn `general-purpose` subagent (Agent tool) with this brief (verbatim — covers all issue Task 1 scope):
   - Aquarium-specific vendor landscape — named companies (Lightswitch with Shedd Jellies; Christie Digital; Available Light; Horton Lees Brogden; BK Lighting; Moment Factory at OdySea; AVI-SPL / Diversified experiential at aquariums). Project scope + commercial model per archetype. Humidity-rated architectural-lighting-design-firm archetype as possible vertical-unique.
   - Moment Factory aquarium portfolio audit — OdySea confirmed? Any other named US aquarium deployments? Compare frequency vs ski-resort (3 Lumina deployments) and zoos (rare).
   - MK Illumination aquarium portfolio audit — any named US aquarium work? (Expected: none; confirming adjacent-not-competitive framing per zoos, not inversion per hotels.)
   - Popular aquarium programs — Georgia Glow Nights (40-ft tree + twinkle overlay); Shedd Jellies (Lightswitch permanent install); Newport After Dark (Aquarium of the Pacific $59.99 21+); National Aquarium Baltimore; New England Aquarium; Monterey Bay Aquarium (ceiling reference only — enterprise); Adventure Aquarium; Oregon Coast Aquarium; Texas State Aquarium; North Carolina aquariums.
   - Buyer motivations — revenue diversification off seasonal $50–$60 21+ event revenue; adult after-hours market dynamics; summer programming vs holiday overlay; Glow-Native bioluminescence content positioning.
   - Buyer personas — challenge issue directive "VP Revenue / Director of Adult Programs / Director of Operations / Director of Guest Experience." Research: what titles exist at mid-market / independent US aquariums ($10M–$80M op budget, 200K–1M annual visitors)? Enterprise (Georgia / Monterey / Shedd) has VP-titles; mid-market likely runs Executive Director / CEO / Director of Corporate Partnerships / Director of Programs / Director of Membership.
   - Good-vs-bad program taxonomy — static vs dynamic tank overlays; one-way vs two-way crowd flow (aquariums are narrower paths than zoos); Glow-native vs retrofitted-holiday framing; tank-husbandry-respecting schedules.
   - Content vocabulary — bioluminescence, coral glow, jelly tunnels, UV installations, rippled tank-gallery washes (source: aquarium marketing copy + trade press).
   - Offer candidates Hormozi-framed — evaluate THREE candidates: (a) Glow-Native 21+ After-Hours, (b) Production-Finance E-analog (zoos-style sponsor orchestration), (c) Permanent Canvas Offer-B-analog. Each with Hormozi Dream Outcome / Perceived Likelihood / Time Delay / Effort+Sacrifice mapping + recommended backend guarantee metric.
2. Ask agent to cite all non-inferred facts with URLs (per BC-5918 task-3 citation style).
3. Ask agent to explicitly flag directive conflicts between issue body and research evidence (personas, vendor framing, offer shape).
4. Ask agent to return under 2000 words with inline URL citations.

**Verify**: Research-agent output returned; directive conflicts flagged explicitly; 3 offer candidates each Hormozi-framed; vendor-landscape evidence cited for Moment Factory aquarium portfolio + MK Illumination aquarium portfolio + aquarium-specific architectural-lighting-design firms.

---

### Task 2: Pre-compose gate — batched AskUserQuestion for persona + Moment Factory + primary offer
**Files**: (none edited; decisions captured inline; recorded in § Departures of this plan after user response)
**Why**: BC-5921/BC-5922 task-2 established the pre-compose gate pattern: when research contradicts issue directive, the only-right-checkpoint is research-in-hand + composition-not-yet-started. Batching is the BC-5922 extension — cheaper than sequential single-question gates and user has confirmed preference for batched at this complexity tier. 3rd instance of BC-5921 task-2 at a distinct persona surface elevates precedent confidence toward architecture-class 8/10 on its own axis.

**Implementation**:
1. After Task 1 returns, synthesize the directive conflicts (likely: persona set has VP-title tell; Moment Factory framing depends on OdySea portfolio depth; primary offer pick depends on Glow-Native vs Production-Finance vs Permanent-Canvas evidence).
2. Call AskUserQuestion with 3 questions (all single-select):
   - **Personas** — research-backed set (Exec Director / CEO / Dir. Corporate Partnerships / Dir. Programs / Dir. Membership likely) vs issue-body set (VP Revenue / Dir. Adult Programs / Dir. Ops / Dir. Guest Experience) vs hybrid by ICP tier.
   - **Moment Factory framing** — primary-with-inversion (3rd-instance BC-5921 task-1, elevates to architecture 9/10) vs peer-paragraph (moderate evidence) vs rare-at-aquariums (if OdySea is thin / one-off).
   - **Primary offer pick for V1** — Glow-Native 21+ After-Hours / Production-Finance E-analog / Permanent Canvas (Offer B, pending R-19) / defer-to-compose-time.
3. Record user response + one-line rationale per question to `docs/plans/BC-5929-plan.md` § Departures (append to this file).

**Verify**: User response captured; § Departures updated with 3 one-line rationale notes; composition proceeds with user-gate-confirmed decisions only.

---

### Task 3: Compose § Vendor landscape + § Buyer personas + § Recency signals + § Program economics + § Good-vs-bad taxonomy
**Files**: `plugins/marketing/references/vertical-playbooks/aquariums.md` (new)
**Why**: Foundational sections — shape inherited from zoos.md / hotels-resorts.md / ski-resorts.md; vertical-specific lens applied. BC-5918 task-2 (docs-only single-pass collapse) — composing 5 structurally-similar sections in a single pass is more coherent than 5 subagent-dispatched tasks.

**Implementation**:
1. Create file with frontmatter matching peer playbooks (`source:`, `license:` per BC-5917 convention).
2. Write § Vendor landscape (aquariums lens):
   - Filter the 4 vendor-landscape archetypes per aquarium-specific evidence from Task 1 research.
   - Tianyu — explicitly excluded per issue Non-Goal / humidity constraint; state inline with citation.
   - Moment Factory — place per Task 2 gate decision (primary-with-inversion OR peer-paragraph OR rare); if inversion, add `### Explicitly adjacent, not competitive (aquariums-specific)` subsection naming the inversion per BC-5921 task-1 pattern.
   - MK Illumination — place per Task 2 research (likely adjacent-not-competitive, matching zoos not hotels).
   - If research surfaces aquarium-unique architectural-lighting-design-firm archetype (Lightswitch / Available Light / etc.) — add as 5th archetype with inline justification per BC-5921 task-3 pattern.
3. Write § Buyer personas per Task 2 gate decision. Preamble documents any directive correction explicitly per BC-5921 task-2 pattern. 3–5 personas; each with which-offer-per-persona mapping.
4. Write § Recency signals — 5–6 public-signal categories with decay windows; cross-reference `shelf-life-patterns.md` like peer playbooks.
5. Write § Program economics — $50–$60 21+ ticket anchor (Newport $59.99 verified); summer Glow Nights vs holiday overlay windows; attendance benchmarks from Task 1 research; production-cost ranges per archetype.
6. Write § Good-vs-bad program taxonomy — 5 dimensions per peer-playbook structure; aquarium-specific dimensions include humidity-appropriate vs not + tank-welfare-respecting schedule vs not.

**Test**:
- Run: `grep -c '^## ' plugins/marketing/references/vertical-playbooks/aquariums.md`
- Expected: ≥5 matches from this task (will be 9 total after Task 4 + 5).

**Verify**: All 5 sections written; Tianyu explicit exclusion cited; Moment Factory placed per gate decision with inversion subsection if applicable; MK Illumination placed per research; citations inline per BC-5918 task-3 style.

---

### Task 4: Compose § Offer candidates + § V1 offer picks + § Voice rules
**Files**: `plugins/marketing/references/vertical-playbooks/aquariums.md` (append)
**Why**: Decision-dependent sections — downstream of Task 2 gate primary-offer pick. Offer-candidates section needs ≥3 candidates per AC; each with full Hormozi frontend/backend evaluation.

**Implementation**:
1. Write § Offer candidates — write all 3 candidates from Task 1 research (Glow-Native 21+ / Production-Finance / Permanent Canvas) with:
   - One-line statement, Hormozi mapping (Dream Outcome / Perceived Likelihood / Time Delay / Effort+Sacrifice), Frontend deliverable, Backend commitment, Commercial structure, When it fits.
   - Each candidate section MUST contain substrings `Hormozi`, `frontend`, `backend` (AC requirement).
   - Offer B explicitly marked `(pending R-19 parallel)` matching zoos + hotels playbook convention — do NOT compose Offer B presets until BC-5941 closes.
2. Write § V1 offer picks per Task 2 gate primary-offer decision. Explicit statements: Primary: X, Tactical complement: Y, Pending R-19: Z.
3. Write § Voice rules — 5 rules cumulative from BC-5879 zoos-ledger + research-grounded corrections. Required rules:
   - No enterprise-aquarium name-drops (Georgia / Monterey Bay / Shedd / New England as default); use mid-market peer anchors (Newport / Adventure / Oregon Coast / National Aquarium Baltimore) per issue Task 10 + peer-playbook pattern.
   - No "magical undersea" / "immersive wonder" adjectives (per issue AC grep — these may appear ONLY in § Anti-slop rules section).
   - Pitch to persona set from Task 2 gate, not Marketing.
   - Do NOT pitch tank-engineering lighting (husbandry-controlled — per issue Non-Goal #3; hard rule mirrored in § Anti-slop).
   - One more voice rule emerging from Task 1 research (likely: program-window-specific language vs generic "holiday" vocabulary).

**Test**:
- Run: `awk '/## Offer candidates/,/## V1 offer picks/' plugins/marketing/references/vertical-playbooks/aquariums.md | grep -cE 'Hormozi|frontend|backend'`
- Expected: ≥9 matches (3 candidates × 3 substring types).

**Verify**: 3 offer candidates each with Hormozi + frontend + backend substrings; V1 primary matches Task 2 gate decision; 5 voice rules including husbandry-exclusion + enterprise-name-drop rule + banned-adjective rule (content in § Anti-slop, not body of voice rules).

---

### Task 5: Compose § Anti-slop rules + § How to use this reference
**Files**: `plugins/marketing/references/vertical-playbooks/aquariums.md` (append)
**Why**: Final two sections. § Anti-slop is the permitted section for banned phrases per AC literal-grep pattern. § How to use signals which downstream skills consume which sections.

**Implementation**:
1. Write § Anti-slop rules — 5 rules cumulative. Required content:
   - "Don't use 'magical undersea' / 'immersive wonder' / 'dive into' / 'dazzling' / 'mesmerizing' adjectives" — this is the ONLY section where banned phrases may appear per AC grep constraint.
   - No species name-dropping ("sharks", "jellies", "octopuses", specific tank names) — aquarium directors know their collection; vendor name-drops signal trying too hard.
   - No "dive-into" / "sea of"/ "tides of" metaphors.
   - Do NOT pitch tank-engineering lighting (husbandry-controlled) — mirror the voice rule as anti-slop discipline.
   - Generic "ROI uplift" without named aquarium-metric is banned — use per-cap spend / F&B attach / membership conversion / 21+ event revenue specifically.
2. Write § How to use this reference — 3 downstream consumer patterns (email-copywriting preset composition BC-5933; tam-mapping BC-5946/5950; situation-mining) matching zoos + hotels + ski playbook pattern. End with anti-pattern flag directing future authors to send back playbooks that mis-frame S4 / MK / Moment Factory per aquarium-specific framing established in § Vendor landscape.

**Test**:
- Run: `grep -c '^## ' plugins/marketing/references/vertical-playbooks/aquariums.md`
- Expected: exactly 9 matches (9 sections per AC).
- Run: `grep -ci 'magical undersea\|immersive wonder' plugins/marketing/references/vertical-playbooks/aquariums.md` — note line numbers.
- Expected: matches only inside § Anti-slop rules section (not § Voice rules, not § Vendor landscape prose, not URLs).

**Verify**: 9 section headers total; banned phrases appear only in § Anti-slop section; husbandry-exclusion rule mirrored in both § Voice rules and § Anti-slop.

---

### Task 6: AC literal-grep sweep including URL slugs (BC-5922 task-3 defensive discipline)
**Files**: `plugins/marketing/references/vertical-playbooks/aquariums.md` (edits if sweep trips)
**Why**: BC-5922 task-3 established that AC literal-grep traps extend beyond rule body to URL slugs, anchor fragments, inline citations, link titles. A Tianyu URL containing "magical" broke ski-resorts.md on first sweep. Preventive discipline: grep every AC-banned substring across the ENTIRE file (not just rule bodies) before AC check.

**Implementation**:
1. Run URL-slug grep: `grep -niE 'magical|immersive|undersea|wonder' plugins/marketing/references/vertical-playbooks/aquariums.md`
2. Review each match:
   - Matches inside § Anti-slop rules (expected) → leave.
   - Matches anywhere else (URLs / prose / citations) → swap citation or rephrase.
3. Run full AC checks:
   - File exists: `test -f plugins/marketing/references/vertical-playbooks/aquariums.md && echo PASS`
   - Section count: `[[ $(grep -c '^## ' plugins/marketing/references/vertical-playbooks/aquariums.md) -eq 9 ]] && echo PASS`
   - 9 section names match per issue AC: `grep -cE '^## (Vendor landscape|Buyer personas|Recency signals|Program economics|Good-vs-bad|Offer candidates|V1 offer picks|Voice rules|Anti-slop|How to use)' plugins/marketing/references/vertical-playbooks/aquariums.md` (expect ≥9).
   - Tianyu exclusion: `grep -c 'Tianyu' plugins/marketing/references/vertical-playbooks/aquariums.md` (expect ≥1 in § Vendor landscape).
   - Offer candidates substrings: see Task 4 test (expect ≥9).
   - V1 picks named: `grep -cE 'Primary:|Tactical complement:|Pending R-19:' plugins/marketing/references/vertical-playbooks/aquariums.md` (expect ≥3).
   - Program economics ticket range: `grep -cE '\$5[0-9]|\$60' plugins/marketing/references/vertical-playbooks/aquariums.md` (expect ≥1 in § Program economics).
   - Case-study anchors named: `grep -ciE 'Newport|Shedd|Hogle|Aquarium of' plugins/marketing/references/vertical-playbooks/aquariums.md` (expect ≥2 with at least one explicit "verify at composition time" marker if sources unconfirmed).

**Test**:
- Run: `./scripts/validate.sh`
- Expected: `0 errors / 16 warnings` (baseline from main).

**Verify**: All 8 AC check commands pass; validate.sh returns 0 errors / 16 warnings; any URL swaps captured inline in § Departures.

---

### Task 7: Write precedent file `docs/precedents/BC-5929.md` with 1–2 promotion entries
**Files**: `docs/precedents/BC-5929.md` (new)
**Why**: Design Key Decision #2 targets 1–2 precedent promotions. Candidate promotions:
- **BC-5921 task-1 3rd instance** (→ elevate to architecture 9/10) if Moment Factory inverted at aquariums via OdySea precedent, OR if Lightswitch-tier 5th archetype added and it counts as task-3 2nd instance.
- **BC-5921 task-2 3rd instance** if persona directive corrected via pre-compose gate.
- **BC-5921 task-3 2nd instance** if aquarium-unique architectural-lighting-design-firm archetype added as vertical-unique.
Apply BC-5918 task-2 (single-pass docs write) — compose as coherent narrative, not task-per-subsection.

**Implementation**:
1. Use anchor IDs + trace format matching recent precedent files (BC-5920, BC-5921, BC-5922 as structural templates — read for format, not content).
2. For each promotion entry, include:
   - Category + Confidence score
   - Inputs — prior precedent referenced + evidence from this session
   - Alternatives Considered — 3–4 numbered options with CHOSEN + reasoning
   - Outcome — files changed, tests, approved-by
   - Precedent Referenced — explicit link + instance count + promotion criterion met (if architecture-class)
   - Tags — ≤5 kebab-case
3. Write 2–3 entries (one per Task 2 gate decision that confirms an inversion / archetype / persona correction). Minimum 1 entry (Moment Factory or Lightswitch, whichever research supports).

**Test**:
- Run: `grep -c '^## BC-5929' docs/precedents/BC-5929.md`
- Expected: 1–3 matches (one per precedent task).
- Run: `grep -c 'Confidence:' docs/precedents/BC-5929.md`
- Expected: same count as section count.

**Verify**: 1–3 precedent entries; each with Category + Confidence + Inputs + Alternatives + Outcome + Tags; architecture-class promotion (if achieved) explicitly names the promotion criterion met (e.g., "3rd instance at distinct vendor × vertical").

---

### Task 8: Update `docs/precedents/INDEX.md` with BC-5929 rows
**Files**: `docs/precedents/INDEX.md` (append rows)
**Why**: INDEX.md is the searchable row-per-precedent registry. Each precedent file entry needs a matching INDEX row per repo convention (BC-5920/5921/5922 precedent).

**Implementation**:
1. Read current INDEX.md (will already be read into context from Task 3 during plan-writing).
2. Append 1–3 rows (one per precedent from Task 7) formatted as:
   ```
   | [BC-5929](BC-5929.md#BC-5929-task-N) | <decision, ≤120 chars> | <category> | 2026-04-23 | <tag1>, <tag2>, <tag3>, <tag4>, <tag5> |
   ```
3. Match category values to the precedent file's category field.
4. Ensure tags are kebab-case + ≤30 chars each + ≤5 total per row.

**Test**:
- Run: `grep -c '| \[BC-5929\]' docs/precedents/INDEX.md`
- Expected: matches Task 7 precedent-entry count.
- Run: `awk -F'|' '/\| \[BC-5929\]/ {gsub(/^ +| +$/, "", $3); print $3}' docs/precedents/INDEX.md | awk '{ if (length($0) > 120) print "BAD:", length($0), $0 }'`
- Expected: no BAD lines (all decisions ≤120 chars).

**Verify**: INDEX rows match precedent-entry count; decisions ≤120 chars; categories match; tags ≤5 kebab-case per row.

---

### Task 9: Final verification + handoff to review
**Files**: (read-only — no edits expected at this stage)
**Why**: Objective pass/fail on all issue AC checkboxes before ship-readiness. Catches any AC-violation that slipped through Tasks 3-6 before moving to `/workflows:review`.

**Implementation**:
1. Run full issue AC checklist:
   - [ ] `plugins/marketing/references/vertical-playbooks/aquariums.md` exists.
   - [ ] All 9 sections present.
   - [ ] § Vendor landscape explicitly excludes Tianyu (grep for "Tianyu" inside § Vendor landscape).
   - [ ] § Offer candidates has ≥3 candidates each with substrings `Hormozi`, `frontend`, `backend`.
   - [ ] § V1 offer picks names primary + any complements with rationale.
   - [ ] § Program economics cites $50-$60 adult 21+ after-hours ticket.
   - [ ] Case-study anchors named (or explicit "verify at composition time" if unverified).
   - [ ] `grep -ci 'magical undersea\|immersive wonder' aquariums.md` → matches only in anti-slop "don't" bullets.
   - [ ] `./scripts/validate.sh` exits 0.
2. Re-read `docs/plans/BC-5929-plan.md` § Departures and confirm every documented departure has a corresponding trace in the PR description (for future handoff to `/workflows:ship`).
3. Confirm precedent INDEX row count matches precedent file task count.

**Test**:
- Run: `./scripts/validate.sh && echo "VALIDATE: PASS" || echo "VALIDATE: FAIL"`
- Run: `./scripts/check-guardrails.sh --claude-md CLAUDE.md && echo "GUARDRAILS: PASS" || echo "GUARDRAILS: FAIL"`
- Expected: both PASS.

**Verify**: All 9 AC checkboxes green; validate.sh 0 errors / 16 warnings baseline preserved; plan § Departures complete; ready for `/workflows:review` and `/workflows:ship`.

---

## Task Dependencies
- Task 2 depends on Task 1 (needs research output)
- Task 3 + Task 4 + Task 5 depend on Task 2 (composition needs gate decisions) — can be written in Tasks 3/4/5 order but must not start before gate
- Task 6 depends on Tasks 3-5 (sweep runs against composed file)
- Task 7 depends on Tasks 1-6 (precedent writeup references gate decisions + final sections)
- Task 8 depends on Task 7 (INDEX rows reflect precedent file entries)
- Task 9 depends on Tasks 3-8 (final verification)
- **No parallelizable tasks** — this is a sequential composition pipeline; docs-only work doesn't benefit from parallelism (BC-5918 task-2)

## Verification Checklist
- [ ] `plugins/marketing/references/vertical-playbooks/aquariums.md` exists + 9 sections
- [ ] Tianyu exclusion explicit in § Vendor landscape
- [ ] § Offer candidates ≥3 with Hormozi + frontend + backend substrings
- [ ] § V1 offer picks primary + complements named
- [ ] § Program economics cites $50-$60 21+ ticket range
- [ ] Case-study anchors named (or "verify at composition time")
- [ ] AC grep trap check passes for `magical undersea|immersive wonder` (matches only § Anti-slop)
- [ ] URL slug sweep per BC-5922 task-3 passes (no AC-banned substrings in URLs/prose)
- [ ] `./scripts/validate.sh` exits 0 / 16 warnings
- [ ] `docs/precedents/BC-5929.md` contains 1-3 entries with Category + Confidence + Alternatives + Outcome + Tags
- [ ] `docs/precedents/INDEX.md` rows match precedent entries, decisions ≤120 chars, tags ≤5 kebab-case
- [ ] `docs/plans/BC-5929-plan.md` § Departures complete for all gate decisions
