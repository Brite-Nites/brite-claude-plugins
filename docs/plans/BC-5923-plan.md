# Plan: BC-5923 sports-stadiums vertical playbook (R-9 of email-copywriting preset roadmap)

**Issue**: BC-5923 — Create `plugins/marketing/references/vertical-playbooks/sports-stadiums.md`
**Branch**: `holden/bc-5923-create-pluginsmarketingreferencesvertical-playbookssports`
**Worktree**: `.claude/worktrees/bc-5923/`
**Tasks**: 12 (grouped into 3 phases — research / pre-compose gate / compose-and-verify)
**Milestone**: Marketing Plugin v0.1 — GTM Workflows (Revgrowth)

## Prerequisites

All blockers Done:

- BC-5917 `offer-design-frameworks.md` — Done (Hormozi / frontend / backend evaluation taxonomy)
- BC-5918 `experiential-lighting-vendor-landscape.md` — Done (vendor landscape)
- BC-5919 `email-copywriting/SKILL.md` cross-links — Done

**Precedent alignment** (peer reference files produced by the same rhythm, used as structural template):

- `plugins/marketing/references/vertical-playbooks/zoos.md` (BC-5920 output) — R-4 peer; baseline 9-section shape + ICP vs flagship split
- `plugins/marketing/references/vertical-playbooks/hotels-resorts.md` (BC-5921 output) — R-7 peer; first cross-vertical inversion instance
- `plugins/marketing/references/vertical-playbooks/ski-resorts.md` (BC-5922 output) — R-8 peer; 2nd inversion instance + pre-compose persona gate 2nd instance

**Standing recipes to apply** (from prior precedents):

1. **Pre-compose persona gate** — BC-5921 task-2 (hotels: VP Revenue → GM swap) and BC-5922 task-2 (ski: VP Village Ops → GM + DOSM swap) established: before composing § Buyer personas, run AskUserQuestion to confirm the issue-directive persona set matches fresh research. For BC-5923 the issue directive is **VP Bookings / VP Non-Game-Day Revenue / Director of Events** (explicitly rules out Facilities + pro-team front-office). Research must confirm these roles exist at US regional / minor-league / college / MLS / multipurpose regional venues — if research finds GM / COO / VP Operations / Director of Private Events as the actual volume-ICP pattern, flag departures at the gate before writing.
2. **Cross-vertical vendor-framing audit** — BC-5921 task-1 (MK Illumination: zoos-adjacent → hotels-primary-competitor-w/-inversion) + BC-5922 task-1 (Moment Factory: ski-primary-competitor-w/-inversion) established: any vendor named in `experiential-lighting-vendor-landscape.md` must be audited per-vertical. For stadiums, specifically audit: broadcast AV integrators (Christie Digital, Barco, Anolis), projection studios (Moment Factory, Obscura, ESI Design), concert-rig vendors (PRG, Clair Global, VER), multipurpose-venue lighting specialists. Flag any that flip from adjacent to primary-competitor-w/-inversion.
3. **AC literal-grep defensive scrub** — BC-5920 task-3 (Tianyu URL slug miss) + BC-5922 task-3 (Tianyu URL slug + PRNewswire Dallas pair) established: the AC `grep -ci 'broadcast\|game-day'` scans the WHOLE file, not just rule sections. Any content passing that grep — URL slugs, footnote titles, citation anchors, metadata, bullet lists — must be scrubbed at compose time. Broadcast and game-day are the MOST-likely-leaked stadium words because legitimate research cites them constantly. Apply defense during compose, re-grep at verify.

**Risks / notes**:

- **Context7 unavailable** (monthly quota exceeded): handbook + library docs cannot be cross-checked this session. Research leans on WebSearch + issue body + peer playbooks only. No handbook entity-canon check available — flag any Brite-entity ambiguity explicitly in the gate rather than assuming.
- **Stadiums are Labs entity** (audience-experience programming), NOT Nites (holiday residential) or Supply (hospitality-SaaS). Issue body confirms.

## Tasks

### Phase 1 — Research (task 1 from issue)

#### Task 1: Spin up research-agent

**Files**: none written yet; research output lands in context for the compose phase
**Why**: Fresh research required — session priors do not cover stadium-specific vendor landscape, off-season program economics, or buyer motivations

**Research brief** (hand to Explore agent, thoroughness = "very thorough"):

- Stadium experiential-lighting vendor landscape (broadcast AV integrators, projection studios, concert-rig vendors, multipurpose-venue lighting providers) — who actually wins US regional / minor-league / college / MLS / multipurpose bids
- Off-season activation programs: concerts, family events, graduations, community events, food festivals, beer/wine fests, Christmas markets, movie nights, light trails at stadium footprints
- Buyer motivations: off-season utilization rate, non-game-day booking rate, per-event revenue, event differentiation, comp-set pressure
- ICP differentiation: minor league baseball (MiLB) / college football / MLS / multipurpose regional / amphitheater venues vs pro flagship (NFL / MLB / NBA / NHL) — WHY flagship is enterprise-committee-slow
- Good-vs-bad program taxonomy: off-season audience-experience = Brite zone; broadcast-spec / game-day / field-lighting = NOT Brite's
- Content vocabulary: programmable-zone, music-sync, show-calling, audience-experience, concourse, club-level, plaza activations
- Named anchor deployments (any stadium currently running an off-season activation with named vendor + year + scope) — ≥3 strong anchors needed for § Vendor landscape and § Recency signals
- Ownership transitions 2022-2026 (MiLB consolidations, college FBS venues, MLS expansion) — capital-planning recency signals
- Personas: verify VP Bookings / VP Non-Game-Day Revenue / Director of Events actually exist as titled roles at ICP tier; or identify the actual volume roles (GM / COO / Director of Private Events / Director of Event Sales)

**Output**: structured research brief in context — ≥3 inline citations per claim, explicit flag on any persona-title gap

**Verify**: research agent returns with ≥30 inline citations across all 7 dimensions; at least 3 named US regional/minor-league/college deployments with vendor + year + scope

---

### Phase 2 — Pre-compose gate (task 2 from issue, plus standing-recipe gate)

#### Task 2a: Integrate research + fill ledger

**Files**: none persisted (in-context); findings folded into compose phase
**Why**: Compose phase needs consolidated anchors, personas, vendor frames before drafting

**Implementation**:

1. Consolidate research into: (a) vendor-landscape draft (primary competitors + adjacent-not-competitive + out-of-zone), (b) 3–5 named deployment anchors with year/vendor/scope, (c) persona set (research-backed vs issue-directive diff), (d) 5–7 recency-signal buckets with named examples, (e) program-economics numerical anchors with citation, (f) ≥3 offer candidates framework-evaluated

**Verify**: all 6 inputs ready; any gaps explicitly flagged (not papered over)

#### Task 2b: Pre-compose AskUserQuestion gate — persona + vendor-framing departures

**Files**: none (gate conversation)
**Why**: BC-5921/5922 precedent — surface research-vs-directive mismatches BEFORE writing so the user can confirm, not review-and-revise

**Gate checks** (one AskUserQuestion with 2–4 questions; skip any question where research exactly matches directive):

1. **Persona set**: does research confirm VP Bookings / VP Non-Game-Day Revenue / Director of Events as ICP-volume roles? If research finds different titles at the volume tier, present swap options.
2. **Primary competitor inversion**: did the audit of MK Illumination / Moment Factory / Christie Digital / Tianyu / S4 Lights surface any primary-competitor-w/-inversion for stadiums? (If yes, confirm the inversion angle before writing § Vendor landscape.)
3. **ICP tier boundary**: is the volume-ICP pro-tier-AAA MiLB / FBS college / MLS, or narrower (only MiLB + MLS, excluding college)? Confirm the tier band.
4. **Offer frontend form-factor**: rendered concept board (hotels/ski precedent) vs site-walk audit (zoos precedent) vs paid pilot-zone install (zoos Offer A precedent) — which fits stadium buyer decision shape best?

**Verify**: user confirms or redirects each question; decisions captured in compose phase

---

### Phase 3 — Compose & verify (tasks 3–12 from issue)

#### Task 3: Compose § Vendor landscape

**Files**: `plugins/marketing/references/vertical-playbooks/sports-stadiums.md`
**Why**: Grounds all later sections — determines who Brite competes with, who Brite partners with, who Brite is not

**Implementation**:

- Distill from BC-5918 landscape + fresh research
- Structure: Primary competitors (with inversion subsection if audit surfaced one) / Adjacent-not-competitive / Out-of-Brite-zone
- Apply cross-vertical vendor-framing audit outcomes from Task 2b
- Cite ≥5 named deployments with year, vendor, scope

**Verify**: ≥5 inline citations; primary vs adjacent vs out-of-zone split explicit; any inversion written with explicit "Brite differentiator is [X]" statement

#### Task 4: Compose § Buyer personas

**Why**: AC: explicitly names VP Bookings / VP Non-Game-Day Revenue / Director of Events AND rules out Facilities + pro-team front-office; with which-offer-per-persona mapping per BC-5920/5921/5922 shape

**Implementation**:

- Apply persona set confirmed at Task 2b gate (directive or research-backed swap)
- For each persona: title, reporting line, budget authority, KPI they own, which offer fits
- Explicit rule-out bullets for Facilities + pro-team front-office with reason

**Verify**: AC-2 compliance (3 personas named) + AC-3 rule-out (Facilities + front-office named in a "NOT the target" bullet)

#### Task 5: Compose § Recency signals

**Why**: Outbound triggers — what public signals stadiums leak that indicate a buying window

**Implementation**:

- 5–7 buckets: off-season calendar announcements, new booking-VP appointments, event-series launches, capital-plan filings, ownership transitions, MLS/MiLB expansion signals, amphitheater calendar refreshes
- Each bucket: ≥1 named example with year

**Verify**: ≥5 buckets; each has a named example

#### Task 6: Compose § Program economics

**Why**: Numerical anchors for offer economics — per-event revenue, off-season utilization rate, per-date booking yield

**Implementation**:

- 3–5 numerical anchors with citation (MiLB per-date rental benchmarks, FBS college off-season booking rates, MLS plaza-activation per-event revenue, summer concert gross anchors)
- Explicit "good range vs bad range" framing where possible

**Verify**: ≥3 cited numerical anchors; citations resolve

#### Task 7: Compose § Good-vs-bad program taxonomy

**Why**: Sharpens the Brite zone vs out-of-zone line — prevents offer drift toward broadcast / game-day

**Implementation**:

- 2-column table or explicit "Brite zone" / "NOT Brite zone" lists
- Off-season programmable zones / plaza / concourse / club-level activations = Brite zone
- Broadcast-spec / game-day field rigs / sport-specific fixture lighting / code-compliance emergency = NOT Brite zone
- Address the ESPN/broadcast-lit confusion head-on

**Verify**: taxonomy explicit; both sides populated; broadcast / game-day appear only inside "NOT Brite zone" framing

#### Task 8: Compose § Offer candidates

**Why**: AC: ≥3 candidates each Hormozi/frontend/backend evaluated

**Implementation**:

- ≥3 candidates — likely: (1) rendered concept board frontend + per-event-revenue guarantee backend, (2) paid pilot-zone install frontend + off-season utilization guarantee backend, (3) site-walk audit frontend + programmable-zone roadmap backend
- Each candidate gets: name, frontend form-factor, backend economics, Hormozi value-equation take (dream outcome × perceived likelihood ÷ time delay ÷ effort/sacrifice), why-it-fits-stadiums rationale
- Apply Task 2b Question 4 decision on default frontend

**Verify**: AC-4 compliance (each candidate contains "Hormozi", "frontend", "backend" substrings); ≥3 candidates

#### Task 9: Compose § V1 offer picks

**Why**: Narrows ≥3 candidates to primary + optional tactical complement

**Implementation**:

- Primary pick + rationale (why-it-wins-volume)
- Optional complement + rationale (why-it-wins-specific-ICP-subset)
- Explicit tie to downstream preset composition BC-5937 (don't compose preset files here)

**Verify**: AC-5 compliance (primary + complements named with rationale)

#### Task 10: Compose § Voice rules

**Why**: Per-vertical voice guardrails for downstream preset composers

**Implementation**:

- No game-day lighting pitches
- No broadcast-spec language
- No artist name-drops (concert framing without specific artists)
- No pro-stadium brand defaults (no Yankees / Cowboys / Lakers as default reference — pro is out-of-ICP)
- Pitch to VP Bookings / VP Non-Game-Day Revenue, not Marketing or Facilities
- 5–8 bullets, each an imperative

**Verify**: 5+ bullets; each an imperative; pro-brand name-drop explicitly disallowed

#### Task 11: Compose § Anti-slop rules

**Why**: Stadium-specific anti-slop, complements voice rules

**Implementation**:

- No "iconic venue" / "legendary" / "hallowed ground" buzzwords
- No sport-specific fandom framing ("the roar of the crowd")
- No pro-stadium cosmetic upgrade pitches (pro is enterprise, not ICP)
- No game-day field-rig claims; no emergency-lighting code-compliance adjacency
- Any broadcast / game-day appearance must be in a "don't" bullet (defense against the AC grep)
- 5–8 bullets

**Verify**: 5+ bullets; broadcast / game-day appear only in explicit "don't" framing

#### Task 12: Run validate.sh + AC literal-grep scrub

**Files**: none changed; verification only
**Why**: AC exit gate

**Implementation**:

1. `grep -ci 'broadcast\|game-day' plugins/marketing/references/vertical-playbooks/sports-stadiums.md` — every match reviewed; any non-"don't" match rewritten
2. `./scripts/validate.sh` — must exit 0
3. Walk the 7 AC checkboxes manually

**Verify**: all AC ticked; validate.sh exits 0; grep scrub clean

## Task Dependencies

- Task 1 must complete before Task 2a (research-before-integrate)
- Task 2b gate must complete before Tasks 3–11 (gate-before-compose)
- Tasks 3–11 sequential within the single file (composing one document top-to-bottom)
- Task 12 last (verification exit gate)

## Verification Checklist (from issue AC)

- [ ] `plugins/marketing/references/vertical-playbooks/sports-stadiums.md` exists
- [ ] All 9 sections present: Vendor landscape, Buyer personas, Recency signals, Program economics, Good-vs-bad taxonomy, Offer candidates, V1 offer picks, Voice rules, Anti-slop rules
- [ ] § Buyer personas explicitly names VP Bookings / VP Non-Game-Day Revenue / Director of Events AND explicitly rules out Facilities or pro-team front-office
- [ ] § Offer candidates ≥ 3, each framework-evaluated (contains "Hormozi", "frontend", "backend" substrings)
- [ ] § V1 offer picks names primary + complements
- [ ] `grep -ci 'broadcast\|game-day' plugins/marketing/references/vertical-playbooks/sports-stadiums.md` returns matches only in anti-slop "don't" bullets
- [ ] `./scripts/validate.sh` exits 0

## Non-Goals (from issue)

- Do NOT compose preset files — that's R-15 / BC-5937
- Do NOT target pro-stadium enterprise as default ICP
- Do NOT pitch game-day or broadcast-spec lighting (out of Brite's zone)

## Ship readiness gate

After Task 12, hand off to `/workflows:review` then `/workflows:ship`. Ship step will compound learnings per any precedents that surface (expect: 3rd instance of cross-vertical vendor inversion audit — elevates to *standing recipe*; 3rd instance of pre-compose persona gate — elevates to *architecture* level).
