# Plan: BC-5930 casinos vertical playbook

**Issue**: BC-5930 — Create `plugins/marketing/references/vertical-playbooks/casinos.md`
**Branch**: `holden/bc-5930-casinos-playbook`
**Worktree**: `.claude/worktrees/bc-5930/`
**Tasks**: 11 (estimated 90–120 min, excluding research-agent wall time)

## Prerequisites

- Worktree exists at `.claude/worktrees/bc-5930/` on branch `holden/bc-5930-casinos-playbook` (already created).
- Design doc at `.claude/worktrees/bc-5930/docs/designs/bc-5930-casinos-playbook-brainstorm.md` (approved 2026-04-23).
- Peer templates: `plugins/marketing/references/vertical-playbooks/zoos.md` (primary), `hotels-resorts.md`, `ski-resorts.md`.
- Upstream references: `plugins/marketing/references/offer-design-frameworks.md` (BC-5917), `experiential-lighting-vendor-landscape.md` (BC-5918), `shelf-life-patterns.md`, `hidden-signals-library.md`.
- **CDR alignment**: CDR check skipped — Context7 quota exceeded; handbook access degraded. Not blocking.
- **Precedent alignment**:
  - **BC-5823** — Handbook canon wins for vertical/ICP/persona scope decisions; not directly applicable (no handbook canon for casinos yet) but frame informs the issue-body departure decisions.
  - **BC-5921 task-1 / BC-5922 task-1** — Mandatory MK Illumination + Moment Factory per-vertical audit with inline inversion justification. **Casinos is 3rd instance → elevates pattern to architecture 9/10.**
  - **BC-5921 task-3** — Vertical-unique archetypes documented inline in playbook, not upstreamed to shared vendor-landscape.md. Applied to Tribal Council capex-gate + any casino-unique vendor surface surfaced in research.
  - **BC-5922 task-2** — Pre-compose persona gate at distinct vertical + distinct persona surface. **Casinos is 3rd instance → elevates to architecture 9/10.** Applied via Task 9 gate.
- **Gotcha guards**:
  - `gotcha_write_tool_worktree_path`: all Write/Edit paths must include `.claude/worktrees/bc-5930/` prefix.
  - `gotcha_linear_markdown_mangling`: at PR-body / Linear-comment time, use prose-with-bold-label paragraphs for new `##` sections, not numbered lists.

## Tasks

### Task 1: Load peer context + precedent files

**Files (read-only)**:
- `plugins/marketing/references/vertical-playbooks/zoos.md`
- `plugins/marketing/references/vertical-playbooks/hotels-resorts.md`
- `plugins/marketing/references/vertical-playbooks/ski-resorts.md`
- `plugins/marketing/references/offer-design-frameworks.md`
- `plugins/marketing/references/experiential-lighting-vendor-landscape.md`
- `plugins/marketing/references/shelf-life-patterns.md`
- `docs/precedents/BC-5921.md`
- `docs/precedents/BC-5922.md`
- `docs/precedents/BC-5932.md`

**Why**: Anchor composition to peer structural shape; re-load the 4 load-bearing precedents so every section draft can cite the applicable precedent inline.

**Implementation**:
1. Read all 9 files into session context.
2. Extract from peers: section ordering, citation style (inline with "(inferred from …)" or "(cited in …)"), word-count band per section (zoos = ~240 lines; ski = ~252 lines; hotels = ~similar), frontmatter format.
3. Extract from precedents: exact wording of MK + Moment Factory audit (zoos = adjacent-not-competitive; ski = Moment Factory inverted to primary; hotels = MK inverted per BC-5921 task-1), wording of pre-compose gate trigger.

**Verify**: Confirm peer line-count band = 200–260 lines; note casino playbook will likely be 240–280 given 4-way ICP × 4 offers expansion.

---

### Task 2: Dispatch research-agent with comprehensive brief

**Files (write)**:
- `.claude/worktrees/bc-5930/docs/research/bc-5930-casinos-research.md` (agent output)

**Why**: Fresh research is the foundation for all 9 content sections. Must cover vendor landscape, 4-way ICP sub-types, 4 parallel personas, 4 offer-candidate economic anchors, 4 worldview drivers, compliance-regulated "bad zone" boundary, and mandatory MK + Moment Factory per-vertical audit.

**Implementation**:
1. Spin up a general-purpose research agent with explicit brief covering:
   - **Vendor landscape (non-gaming zones only)**: Christie Digital, Limelight Art, regional AV integrators, theming specialists, lantern-festival producers (rare at casinos — confirm), Moment Factory casino installs (Foxwoods / Mohegan Sun / tribal resorts / Las Vegas — confirm with citations), MK Illumination casino retail-arcade deployments (confirm with citations). Exclude gaming-floor surveillance AV.
   - **ICP 4-way sub-types**: regional commercial (Penn, Boyd, Eldorado, Full House, Monarch, Century, Golden), tribal Class III (NIGC compact basics; Foxwoods / Mohegan / Pechanga / Seminole examples), racinos (Harrah's Philadelphia / Yonkers / Meadowlands / Canterbury Park — casino-side only), riverboat/cruise-ship (Boyd Ameristar, IL/IA/MO/MS riverboat properties).
   - **Buyer personas per sub-type** (4 primaries + F&B secondary): operator-title prevalence data. Confirm VP Non-Gaming Revenue as flagship-only. Confirm Tribal Casino GM + Tribal Council capex-gate dynamic.
   - **Recency signals**: trade press (Casino Journal, Global Gaming Business, Tribal Government Gaming, CDC Gaming Reports), non-gaming expansion announcements, F&B concept launches, new COO/VP Ops hires, tribal-council capital-plan approvals, 10-Q non-gaming revenue segment disclosures.
   - **Program economics anchors**: F&B attach rate benchmarks, visitor-per-trip non-gaming revenue share (typically 35–50% at modern regional casinos), comp-budget % of non-gaming revenue (30–45%), average F&B per-cap by property tier.
   - **Offer-fit evidence per worldview driver**: attach-rate programs (confirm any Brite or competitor case studies), visitor-per-trip production-finance analogs (tribal tourism-bureau grants; state Indian Gaming Regulatory Act revenue-sharing channels; multi-stream non-gaming monetization), comp-multiplier precedent (any operator publicly sharing comp-rate reduction via experiential programs), retention-subscription analogs (year-round architectural lighting programs at casinos, if any).
   - **Named outbound targets**: ≥5 regional commercial prospects, ≥5 tribal Class III prospects, ≥3 racino prospects, ≥3 riverboat prospects — all with specific property / operator names + recent trade-press signals.
   - **Mandatory per-vertical framing audit**: MK Illumination framing at casinos (competitive in retail-arcade zone per design doc hypothesis? adjacent elsewhere?); Moment Factory framing (inverted primary competitor, adjacent at regional, or rare?).
2. Agent returns citations inline with URLs; no invented sources.
3. Save agent output to worktree research file.

**Verify**: Research file exists, is ≥1500 words, has ≥20 inline citations, covers all 4 ICP sub-types + 4 offer-drivers + MK/Moment Factory audit. Spot-check 3 citations for accuracy.

---

### Task 3: Draft frontmatter + § header + § Vendor landscape (casinos lens)

**Files**:
- `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md` (new)

**Why**: Vendor landscape is foundational — establishes which vendors are competitive, adjacent, or irrelevant, which filters all downstream sections.

**Implementation**:
1. Write frontmatter: `source: BC-5930 research (2026-04-23); public filings + trade press cited inline`, `license: Brite-originated; distilled from fresh research, no upstream port`.
2. Write # title + opening paragraph (role of this playbook, ICP scope = 4 sub-types land-based, Vegas Strip flagships excluded, cross-reference to hotels-resorts.md for hotel-first properties).
3. Write § Vendor landscape (casinos lens) with these sub-sections:
   - Overview paragraph linking to shared `experiential-lighting-vendor-landscape.md`.
   - Named archetype-by-archetype breakdown from research: Christie Digital + Limelight + regional AV integrators (competitive in non-gaming experiential); lantern-festival producers (rare — confirm); theming specialists.
   - **Per-vertical framing audit** (BC-5921 task-1 3rd instance) — two subsections:
     - **MK Illumination** — inline justification of framing at casinos. Hypothesis: competitive in retail-arcade / shopping-corridor zone; adjacent elsewhere. Confirm or invert based on research.
     - **Moment Factory** — inline justification. Hypothesis: inverted primary competitor at tribal resort / regional flagship permanent installs (if research confirms presence); adjacent if presence not found.
   - **Vertical-unique archetype** subsection (BC-5921 task-3) if research surfaces casino-specific vendor type not in shared landscape (e.g., casino surveillance-AV integrators that also do non-gaming experiential; tribal-casino-specialist operators).

**Test**: `grep -c 'MK Illumination\|Moment Factory' casinos.md` returns ≥2.
**Verify**: Section is 40–60 lines; framing audit subsections present; inline citations from research.

---

### Task 4: Draft § Buyer personas (4 parallel primaries + F&B secondary)

**Files**:
- `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md` (append)

**Why**: 4 parallel primaries enforces the 4-way ICP design. Name the issue-body departure from VP Non-Gaming Revenue over-specification per BC-5922 task-2.

**Implementation**:
1. Intro paragraph: 4-way ICP = 4 parallel primary personas, one per sub-type. Director of F&B = shared secondary. Marketing + Facilities = explicitly excluded (per issue body).
2. **Primary 1: COO / VP Operations (regional commercial)** — P&L authority, named operators (Penn, Boyd, Eldorado), offer-fit primary mapping.
3. **Primary 2: Casino GM + Tribal Council capex-gate (tribal Class III)** — GM is operator decision; Tribal Council is deal-gate above $250K–$1M (confirm threshold from research); sovereignty + procurement-protocol caveat. **Vertical-unique archetype** per BC-5921 task-3.
4. **Primary 3: Director of Casino Operations (racinos)** — casino-side specifically; racing-side excluded as different P&L and buyer.
5. **Primary 4: Regional VP of Operations (riverboat / multi-property)** — portfolio role at Boyd, Penn, Eldorado regionals; shared across multiple properties.
6. **Secondary: Director of F&B** — owns F&B experiential P&L; strongest fit with Offer A pilot-zone pitches.
7. **Flagged departure subsection** — per BC-5922 task-2 pre-compose gate precedent (3rd instance), write: "Issue body names VP Non-Gaming Revenue as one of the prescribed primary personas. Research confirmed this title is Vegas-flagship-tier (Caesars-origin ~2015, adopted at MGM/Wynn, trickled to Hard Rock / Penn / Boyd regional-VP tier but not below). At mid-market regional + tribal + racino + riverboat, non-gaming P&L sits with COO / VP Operations. Playbook names VP Non-Gaming Revenue as secondary where title exists; primary is sub-type-dependent per above. Departure approved at brainstorm 2026-04-23 per BC-5922 task-2 precedent."

**Test**: `grep -c 'Tribal Council\|Casino GM\|Director of Casino Operations\|Regional VP' casinos.md` returns ≥4. `grep -c 'VP Non-Gaming Revenue' casinos.md` returns ≥2 (one mention, one flagship-tier caveat).
**Verify**: Section is 50–70 lines; flagged departure subsection present; each primary has offer-fit mapping.

---

### Task 5: Draft § Recency signals + § Program economics

**Files**:
- `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md` (append)

**Why**: Research-dense sections. Recency signals feeds TAM-mapping / account-research consumers; program economics feeds offer-fit math.

**Implementation**:
1. **§ Recency signals** — 5–6 signals with decay windows (reference `shelf-life-patterns.md`):
   - Non-gaming expansion announcements (decay: 6–12 months)
   - F&B concept launches + executive chef hires (decay: 3–6 months)
   - New COO / VP Ops / GM hires (decay: 6–12 months — audit-cycle window months 3–9)
   - Tribal Council capital-plan approvals + 10-K/10-Q non-gaming revenue segment disclosures (decay: 12–24 months)
   - State tourism-bureau partnership announcements (decay: 12+ months)
   - Trade-press program coverage (Casino Journal, Global Gaming Business, CDC Gaming Reports) — decay: window-of-use.
2. **§ Program economics** — anchor numbers from research:
   - F&B attach-rate benchmarks (regional mid-market: typically X% per visit — confirm)
   - Visitor-per-trip non-gaming revenue share (typically 35–50% at modern regional casinos — confirm)
   - Comp-budget % of non-gaming cost (30–45% — confirm)
   - Average F&B per-cap by property tier (regional vs tribal vs racino — confirm)
   - Named named outbound target property revenue profile citations (5+ operators) — use operator 10-K / annual-report citations.

**Test**: `grep -c 'attach rate\|visitor-per-trip\|comp' casinos.md` returns ≥6 combined across both sections.
**Verify**: Both sections cumulative 50–80 lines; numbers have source citations; no invented stats.

---

### Task 6: Draft § Good-vs-bad program taxonomy

**Files**:
- `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md` (append)

**Why**: Separates Brite's zone from adjacent / regulated / out-of-scope zones. Anchor for voice + anti-slop rules and preset composition (BC-5934).

**Implementation**:
1. Intro paragraph: 5-dimension taxonomy (mirroring zoos structural shape).
2. **Dimension 1: Good zone (IN) = widest non-gaming footprint** — F&B + hotel-attached + in-house entertainment venues + convention space + retail arcades + arrival/parking structures. Per each zone:
   - F&B (restaurants, bars, lounges, buffets): primary Brite zone.
   - Hotel-attached (lobby, pool deck, spa, hallways): IN with hotels-resorts.md cross-reference. Decision rule: casino-first property → this playbook; hotel-first property → hotels-resorts.md.
   - In-house entertainment venues (theaters, concert halls, nightclubs): IN but **Offer A only** (single-venue pilot) — Moment Factory / AV integrator incumbents block Offer E full-property orchestration here.
   - Convention / conference space: IN with AV-integrator-adjacency caveat — event-specific AV incumbents often serve this well; Brite plays where the venue has programmable-media ambition beyond event-by-event.
   - Retail arcades + arrival/parking structures: IN. Retail = MK-Illumination-adjacency caveat (streetscape/retail per BC-5921); arrival zones = native Brite fit.
3. **Dimension 2: Bad zone (OUT)** — gaming floor / pit / count room / cage / compliance-regulated surveillance-critical lighting. State-regulator + NIGC + tribal-compact sovereignty constraints. Zero Brite pitch in these zones.
4. **Dimension 3: Static vs dynamic programming** — uplit decor ages poorly; programmable kinetic installations compound. (Shared discipline from zoos/hotels/ski.)
5. **Dimension 4: Program sequencing cadence** — daily / weekly / seasonal refresh. Different from zoos (seasonal-only); casinos benefit from daily content refresh cycles matching player-rewards tier promotions.
6. **Dimension 5: Compliance-adjacency discipline** — voice rule preview: any gaming-floor-proximal program must route through NIGC + state-gaming-commission review. Brite's pitch lives outside that regulatory surface; playbook never speaks to gaming-floor lighting.

**Test**: `grep -c 'gaming floor\|NIGC\|compliance' casinos.md` returns ≥3.
**Verify**: Section is 45–65 lines; 5 dimensions present; zone-by-zone breakdown inside Dimension 1 covers all 6 non-gaming zones from design doc.

---

### Task 7: Draft § Offer candidates (4 candidates)

**Files**:
- `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md` (append)

**Why**: 4 offer candidates is the load-bearing differentiator for casinos playbook — user wants all 4 worldview drivers tested as offers.

**Implementation**:
Each candidate gets: One-line statement + Hormozi mapping (4 axes) + Frontend deliverable + Backend commitment + Commercial structure + When it fits + Worldview-driver anchor (inline).

1. **Offer A — Pilot Zone (attach-rate-anchored)**. Tactical complement. Brite underwrites single F&B zone install; guarantee metric = attach-rate lift over named baseline period; backend = rendered concept board + pilot-zone install with sensor-based measurement. Best fit: Director of F&B + Casino GM at tribal / regional properties with single F&B concept ready for refresh. Worldview: attach rate.
2. **Offer B — Retention Infrastructure Subscription (retention-anchored)**. Year-round programmable-media subscription tied to player-loyalty program tier promotions + daily/weekly content refresh. Backend: multi-year subscription, Brite retains infrastructure, venue licenses use. Best fit: COO / VP Ops with capital-planning cycle + loyalty program already integrated. Worldview: retention infrastructure.
3. **Offer E — Production Finance (visitor-per-trip-anchored)**. Multi-stream finance: tribal economic-development grants + state tourism-bureau partnerships + ad revenue on DMX-pixel surfaces + comp-budget-offset. Brite orchestrates, takes revenue-share. Best fit: Casino GM + Tribal Council (or regional COO) at properties with active non-gaming expansion capital plan. Worldview: visitor-per-trip non-gaming revenue.
4. **Offer F — Comp-Multiplier (comp-rate-reduction-anchored, casino-native)**. **New offer type not in shared offer-design-frameworks.md.** Revenue-share on measurable comp-budget-offset: Brite installs programmable-media; comp-rate reduction is tracked via player-loyalty-tier telemetry; Brite's fee is a % of the comp-budget savings. Backend: installation + integration with player-loyalty telemetry + shared measurement infrastructure. Best fit: regional commercial COO + CFO at property with transparent comp-budget accounting. Worldview: comp-rate reduction. **Note open risks**: comp-data is operator-sensitive; integration with player-loyalty telemetry requires technical partnership; legal / accounting / revenue-share structure needs validation. **Productization out of scope of this playbook** (explicit note) — playbook surfaces as candidate only.

For each of 4: include the substrings **"Hormozi"**, **"frontend"**, **"backend"** in the section text (per AC check).

**Test**: `grep -c 'Hormozi' casinos.md` returns ≥4. `grep -c 'frontend' casinos.md` returns ≥4. `grep -c 'backend' casinos.md` returns ≥4.
**Verify**: Section is 70–100 lines; 4 candidates clearly delineated; each has all 4 Hormozi axes named.

---

### Task 8: Draft § V1 offer picks + § Voice rules + § Anti-slop rules + "How to use" footer

**Files**:
- `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md` (append)

**Why**: V1 picks lands the decision from research + operator judgment. Voice / anti-slop rules enforce framing discipline for downstream preset composition (BC-5934). Footer directs downstream consumers.

**Implementation**:
1. **§ V1 offer picks** — per design doc, enter with all 4 candidates visible; land V1 based on research evidence:
   - **Primary V1**: lands based on research (likely Offer A pilot-zone or Offer E production-finance depending on which has the strongest casino-sector evidence). Name and justify.
   - **Tactical complement**: second-pick offer with justification.
   - **Pending / deferred**: mark Offer F (Comp-Multiplier) as "candidate, productization pending" regardless of research outcome (design-doc constraint). If Offer B has weak evidence, mark as pending/deferred.
2. **§ Voice rules** — 5 rules cumulative from issue body + brainstorm:
   - No Vegas-flagship name-drops (Caesars Palace, Bellagio, Wynn, MGM Grand — forbidden in body copy).
   - No "luxury" / "opulent" buzzwords.
   - No gaming-floor language (pit, floor, house edge, comp-out, hold percentage) in body copy.
   - Lead with COO / VP Operations / VP Non-Gaming Revenue / Casino GM / Regional VP / Director of Casino Operations — never Marketing, never Facilities.
   - Zone-specific framing: F&B = attach-rate; hotel-attached = cross-ref hotels-resorts playbook; entertainment venue = Offer A only; convention = Brite fit limited; retail arcade = MK-Illumination-adjacent caveat.
3. **§ Anti-slop rules** — 5 rules casino-specific:
   - No pit-specific framing (compliance-adjacent).
   - No "experience upgrade" standalone buzzword.
   - No compliance-adjacent gaming-floor claims (surveillance, pit lighting, cage area).
   - No Vegas-flagship precedent analogs (wrong-tier for mid-market ICP).
   - No tribal-sovereignty minimizing language (tribal-council capex-gate is real; pitch Casino GM, let GM navigate).
4. **§ How to use this reference** — 3–4 downstream-consumer subsections (mirror zoos footer):
   - **email-copywriting preset composition (BC-5934)** — reads § Offer candidates + § V1 offer picks + § Voice + § Anti-slop.
   - **tam-mapping (when ported)** — reads § Recency signals + § Program economics + § Buyer personas.
   - **situation-mining (when ported)** — reads § Recency signals + § Good-vs-bad taxonomy.
   - **Anti-pattern flag** — if future casino-vertical skill / preset / playbook frames MK Illumination or Moment Factory outside their casinos-specific framing, send back.

**Test**: `grep -ci 'las vegas\|vegas strip\|luxury\|opulent' casinos.md` returns matches only inside "don't" / anti-slop bullets (no positive-framing occurrences).
**Verify**: 4 sections total cumulative 60–90 lines; V1 picks explicit; voice + anti-slop rules casino-specific.

---

### Task 9: Pre-compose gate + AC literal-grep sweep + inline citation audit

**Files (read)**: `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md`

**Why**: BC-5922 task-2 pre-compose gate (3rd instance). BC-5920 task-3 AC literal-grep trap extends to URL slugs + section-header exact phrasing — must literal-grep every AC checkbox before claiming pass. Inline citation audit prevents invented sources.

**Implementation**:
1. **Pre-compose gate**: re-confirm persona correction is documented in § Buyer personas (VP Non-Gaming Revenue flagship-tier-only + 4 parallel primaries). Ensure the flagged-departure subsection is present and worded as "Departure approved at brainstorm 2026-04-23 per BC-5922 task-2 precedent."
2. **AC literal-grep sweep** — run every issue-body AC check verbatim:
   - `grep -c '## Vendor landscape' casinos.md` ≥ 1
   - `grep -c '## Buyer personas' casinos.md` ≥ 1
   - `grep -c '## Recency signals' casinos.md` ≥ 1
   - `grep -c '## Program economics' casinos.md` ≥ 1
   - `grep -c '## Good-vs-bad program taxonomy' casinos.md` ≥ 1
   - `grep -c '## Offer candidates' casinos.md` ≥ 1
   - `grep -c '## V1 offer picks' casinos.md` ≥ 1
   - `grep -c '## Voice rules' casinos.md` ≥ 1
   - `grep -c '## Anti-slop rules' casinos.md` ≥ 1
   - `grep -c 'COO\|VP Operations\|VP Non-Gaming Revenue' casinos.md` ≥ 3
   - `grep -c 'Marketing\|Facilities' casinos.md` appears only in rule-out context (manual verification)
   - `grep -c 'regional\|tribal\|mid-market' casinos.md` ≥ 3
   - `grep -c 'Vegas\|flagship' casinos.md` appears only in exclusion context (manual verification)
   - `grep -c 'Hormozi' casinos.md` ≥ 3 (AC requires ≥3 offers each with Hormozi/frontend/backend; we have 4)
   - `grep -c 'frontend' casinos.md` ≥ 3
   - `grep -c 'backend' casinos.md` ≥ 3
   - `grep -ci 'las vegas\|vegas strip\|luxury\|opulent' casinos.md` — all matches must be inside anti-slop "don't" bullets (manual verification)
3. **Inline citation audit**: spot-check 5 citations for accurate source. Invented-source check: any "(per <source>)" citation must match a real public source from the research output.
4. **Line-count sanity**: total file 200–280 lines (band established by peer playbooks + 4-way ICP × 4-offer expansion).

**Verify**: All AC greps pass; flagged-departure subsection present; inline citations audit-clean; line count in band.

---

### Task 10: Run validate.sh + check-guardrails.sh

**Files (read)**: `.claude/worktrees/bc-5930/plugins/marketing/references/vertical-playbooks/casinos.md`

**Why**: CI-equivalent validation before PR. Must pass 0 errors; warnings baseline is 16 (per recent ship pattern).

**Implementation**:
1. `cd .claude/worktrees/bc-5930 && ./scripts/validate.sh` — must exit 0.
2. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — must exit 0 if run (CLAUDE.md unchanged).
3. If warnings count > 16, investigate + document in PR body; if errors > 0, fix and re-run.

**Verify**: validate.sh exits 0; warning count ≤ 16.

---

### Task 11: Stage commit + file precedent + draft PR body + push

**Files**:
- `.claude/worktrees/bc-5930/docs/precedents/BC-5930.md` (new — only if genuinely new pattern surfaces; BC-5921/5922 3rd-instance promotions go here)
- Git commit + push

**Why**: Close the ship loop.

**Implementation**:
1. **Precedent filing decision** — per memory pattern from BC-5935 ("7th consecutive TRIVIAL triage"): only file a precedent if genuinely new pattern. Candidates:
   - **BC-5921 task-1 3rd instance** (MK + Moment Factory audit at casinos) → promote to architecture 9/10. **File promotion note** in `docs/precedents/BC-5930.md` task-1 entry citing "3rd instance elevates BC-5921 task-1 to architecture 9/10."
   - **BC-5922 task-2 3rd instance** (pre-compose persona gate at casinos) → promote to architecture 9/10. **File promotion note** in `docs/precedents/BC-5930.md` task-2 entry citing "3rd instance elevates BC-5922 task-2 to architecture 9/10."
   - **Offer F (Comp-Multiplier) as casino-native offer not in shared offer-design-frameworks.md** → candidate for new pattern-choice precedent ("casino-native offer types added inline in playbook without upstreaming until productized") — apply BC-5921 task-3 pattern. File as task-3 entry.
2. Write `docs/precedents/BC-5930.md` with 2–3 task entries (promotion task-1 + task-2 + optional task-3).
3. Update `docs/precedents/INDEX.md` with 2–3 rows for BC-5930.
4. Commit: `git add -A && git commit -m "BC-5930: casinos vertical playbook (R-6 of email-copywriting preset roadmap)"` + Co-Authored-By.
5. Push: `git push -u origin holden/bc-5930-casinos-playbook`.
6. Draft PR body: summary + scope + flagged departures + precedent promotions + AC checklist + validate.sh status.

**Verify**: Commit on branch; push succeeds; PR body draft ready for `gh pr create` on operator command.

---

## Task Dependencies

- **T1 → T2 → T3**: sequential (T2 research blocks all composition).
- **T3 → T4 → T5 → T6 → T7 → T8**: sequential (single-file composition; cannot parallelize writes).
- **T9 → T10 → T11**: sequential (AC gate → validate → commit/push).

All tasks are sequential. No parallelization inside this plan. Parallelism is at the 3-worktree-outer-level (BC-5929 + BC-5930 + one more running in parallel worktrees).

## Verification Checklist

- [ ] Peer + precedent context loaded (T1)
- [ ] Research file exists with ≥20 inline citations (T2)
- [ ] All 9 sections present in casinos.md (T3–T8)
- [ ] § Vendor landscape includes MK + Moment Factory per-vertical audit (T3)
- [ ] § Buyer personas has 4 parallel primaries + F&B secondary + flagged-departure subsection (T4)
- [ ] § Offer candidates has 4 candidates each with "Hormozi" + "frontend" + "backend" substrings (T7)
- [ ] § V1 offer picks lands primary + tactical complement + pending markers (T8)
- [ ] § Voice rules + § Anti-slop rules casino-specific, zone-aware (T8)
- [ ] Pre-compose gate wording documented in § Buyer personas (T9)
- [ ] All AC literal-greps pass (T9)
- [ ] Line count 200–280 (T9)
- [ ] `./scripts/validate.sh` exits 0, warnings ≤ 16 (T10)
- [ ] `grep -ci 'las vegas\|vegas strip\|luxury\|opulent' casinos.md` matches only in anti-slop "don't" bullets (T9 manual verification)
- [ ] Precedent file `docs/precedents/BC-5930.md` written with task-1 + task-2 promotion notes (T11)
- [ ] `docs/precedents/INDEX.md` updated (T11)
- [ ] Branch pushed; PR body drafted (T11)
