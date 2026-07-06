# BC-5936 — Ski Resorts Preset Composition (R-14)

Compose 4 preset files for the ski resorts vertical per the R-8 playbook V1 offer set (Offer E primary + Offer A tactical complement). Pattern reuse from zoos R-10; all offer gates, voice rules, and anti-slop discipline sourced from `plugins/marketing/references/vertical-playbooks/ski-resorts.md`.

## Issue

[BC-5936](https://linear.app/brite-nites/issue/BC-5936) · High · Marketing Plugin: GTM Workflows milestone · R-14 of email-copywriting preset roadmap · unblocks BC-5940+.

## Approach

Four preset files under `plugins/marketing/skills/email-copywriting/presets/` using ski-specific playbook slot fills against the two canonical skeletons (A list-building / B risk-reversal). Primary Offer E = base filename (no suffix, matches zoos convention). Tactical Offer A = `-pilot-zone` suffix (matches zoos).

**V1 offer picks (from ski playbook § V1 offer picks):**
- **Offer E — Village Production Finance** (primary) — lead outbound; multi-stream funding + revenue-share on incremental village ancillary
- **Offer A — Village Pilot Zone** (tactical complement) — single-zone demonstration with 3 ledger-fix discipline (rendered concept board, village-native guarantee metric, confident underwrite)
- **Offer B deferred** — blocked on Facilities-VP sales-motion gate (do NOT compose)
- **Offer D deferred** — folded into E

**Load-bearing playbook gates (must surface in body copy or anti-slop):**
1. Brite zone = **village**, NOT lift-line / on-mountain / mountain-ops / ski patrol — wrong-persona fail
2. Persona = **GM primary + F&B Director secondary + DOSM influencer + Owner-Operator at family-owned**; optional Sr Director Base Area at 300K+ visit properties. NOT "VP Village Operations" (enterprise-only title)
3. Moment Factory = **primary competitor at ski (inverted from zoos framing)** — Vallea/Alta/Tonga Lumina + SAM editorial endorsement. Brite wedge = ambient village-integrated programmable infrastructure; MF wedge = ticketed destination-pathway attraction. Distinguish explicitly or prospect defaults to "we already talked to MF"
4. MK Illumination = **adjacent-not-competitive at US ski villages** (different from hotels where MK is inverted). European Seefeld precedent only; no US ski base-village book of business
5. S4 Lights = supply-chain partner, never competitor
6. Don't anchor on Vail / Deer Valley / Aspen / Breckenridge / Park City / Whistler-Blackcomb as standalone framing — ceiling refs only, always paired with Eastern/Midwestern mid-market ICP
7. Don't frame holiday-only — Nov–April baseline + shoulder/summer amortization
8. Anti-slop hard list: magical / winter wonderland / alpine wonderland / enchanting snowscape / holiday charm (§ Anti-slop rule 1); no ski-technical consumer vocab (powder day / bluebird / fall-line / catch an edge / corduroy — § rule 2); no stadium-concert language (ring of steel / truss / FOH / mothership — § rule 3); no generic "ROI" without named ski-specific metric (§ rule 4); lead ancillary-per-visit economics before destination-branding (§ rule 5)
9. Credibility anchors: **Boyne SkyBridge Lights in the Sky** (200K individually-controllable LEDs, Nov–April, MI) = strongest US mid-market precedent; **Killington $3B 25-year village** = Brite-ICP-perfect outbound target (local-investor owned 2024, 45 acres dedicated village, actively building programmable-ready infrastructure); **S4 Lights partnership** = hardware supply secured

## Files

All paths are **relative to the worktree root** (worktree will be created at `.claude/worktrees/bc-5936/`).

| # | File | Offer | Skeleton | Filename convention |
|---|---|---|---|---|
| 1 | `plugins/marketing/skills/email-copywriting/presets/list-building-ski-resorts.md` | E primary | A (list-building T2) | base (no suffix) |
| 2 | `plugins/marketing/skills/email-copywriting/presets/risk-reversal-ski-resorts.md` | E primary | B (risk-reversal T4) | base (no suffix) |
| 3 | `plugins/marketing/skills/email-copywriting/presets/list-building-ski-resorts-pilot-zone.md` | A tactical | A (T2) + Offer-A 3-fix discipline | `-pilot-zone` suffix |
| 4 | `plugins/marketing/skills/email-copywriting/presets/risk-reversal-ski-resorts-pilot-zone.md` | A tactical | B (T4) + Offer-A 3-fix discipline | `-pilot-zone` suffix |

## Tasks

### T1 — Create worktree + branch (baseline clean)

- **Why**: User explicitly requested worktree isolation (two other workstreams active concurrently).
- **Steps**:
  1. `git worktree add -b holden/bc-5936-ski-resorts-presets .claude/worktrees/bc-5936 main`
  2. `cd .claude/worktrees/bc-5936 && ./scripts/validate.sh` — baseline must exit 0 (expected 0 errors / 16 warnings per session history)
  3. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — baseline must exit 0
- **Verify**: Worktree at `.claude/worktrees/bc-5936/`, on branch `holden/bc-5936-ski-resorts-presets`, both scripts pass.
- **Blocker**: If validate.sh reports >0 errors or warnings climb above 16 baseline, stop and report. (Session memory: gotcha_write_tool_worktree_path — Write absolute paths MUST include `.claude/worktrees/bc-5936/` prefix or files land in primary checkout.)

### T2 — Compose `list-building-ski-resorts.md` (Offer E primary, T2)

- **Why**: Primary outbound preset — operators pick this by default unless prospect research surfaces an Offer-A-compatible incumbent.
- **Frontmatter** (5 keys per SKILL.md § 3):
  - `preset: list-building`
  - `vertical: ski-resorts`
  - `entity: brite-labs`
  - `when`: ownership-transition (12–24mo, strongest first 6) OR new GM appointment (6–12mo audit cycle) OR village-expansion / base-lodge press (3–6mo) OR bad-snow-year ancillary-decline press OR compression-week programming press OR Director of F&B / DOSM role change within 90d OR Indy Pass member resort without prior village-programming program
  - `situation_mining_row`: Ski Resorts, Exploring tier Offer E primary (SKILL.md §3 Brite-adaptation; email-copywriting preset roadmap R-14)
- **Hook**: greeting-merged first sentence; recency waterfall top-tier = ownership-transition + capital-plan window / new-GM + audit window / village-expansion press. Template: `"{saw|noticed} {COMPANY}'s {RECENCY_ANCHOR}"`. Lead ancillary-per-visit economics; destination-branding beat lives in paragraph 2+, not hook (voice rule 6 / anti-slop rule 5).
- **Step 1 body** (3 paragraphs, `<br><br>` separators; greeting inline; zero em-dashes; word-level spintax every 3–5 words):
  - Paragraph 1: `{saw|noticed|caught}` {COMPANY}'s {RECENCY_ANCHOR} — reach out before season sets / audit window closes
  - Paragraph 2: Peer proof — `{LABS_PEER_VENUE}` default **Boyne SkyBridge** (200K LEDs Nov–April, MI); `{S4_PARTNER}` fills `"S4 Lights"` as DMX-pixel hardware supply (supply-chain credibility, not competitor). Production-finance shape: Brite orchestrates tourism / DMO partnership + anchor F&B tenant co-marketing + regional sponsor + ad revenue on DMX-pixel village displays. Capital outlay "nets near zero / stays near zero / lands near zero". Snow-independent hedge against bad-snow-year F&B decline (−15.9% YoY ancillary at Vail-owned 2024-25 early season, lift rising) as the quantitatively-defensible GM rationale.
  - Paragraph 3: `{FREE_ASSET_NOUN}` default = "village-economic-impact deck" OR "sponsor-target shortlist" — both Offer-E-native, tied to multi-party close work, not design work. Low-commitment CTA.
  - Sign-off: `{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}`
- **Subject** (1–3 words, spintax, no `{FIRST_NAME}`): `{Quick thought|Quick note|Thought}` (matches zoos primary Offer E cadence)
- **wait_in_days**: `1`
- **Step 2 bump**: matter-of-fact continuation; scoping flexibility on which revenue stream is most load-bearing (tourism-bureau close, F&B tenant co-marketing, regional sponsor, ad inventory). Tone-match zoos Offer E risk-reversal step 2.
- **Step 2 subject**: `Re: {Quick thought|Quick note|Thought}`
- **Step 2 wait_in_days**: `3`
- **Vertical anti-slop** (12–14 bullets, ski-specific):
  1. Don't pitch Lift Ops / Mountain Ops / Ski Patrol / Skier Services / Mountain Manager — Brite zone is village
  2. Use "General Manager" / "F&B Director" / "Director of Sales & Marketing" / "Owner-Operator" salutations; do NOT use "VP Village Operations" (enterprise-only title)
  3. Don't anchor on Vail / Deer Valley / Aspen / Park City / Breckenridge / Whistler-Blackcomb as standalone framing; ceiling-ref only when paired with mid-market ICP
  4. Don't frame holiday-only — use "season-long programming" / "Nov–April multi-season" / "shoulder-season amortization"
  5. No `{list of adjectives}`: magical / magic of the mountains / winter wonderland / alpine wonderland / enchanting snowscape / winter paradise / holiday charm / holiday magic (rule 1 literal-list is the one place allowed to quote banned phrases, per BC-5920 task-3 precedent)
  6. No ski-technical consumer vocab: fall-line / catch an edge / bluebird day / powder day / freshies / gnarly / carving / corduroy
  7. No stadium / concert-rig language: ring of steel / truss and rig / FOH tower / mothership
  8. No generic "ROI uplift" — use named ski-specific metric: ancillary-per-visit, F&B tenant retention rate, village dwell time, post-lift-close foot traffic, compression-week premium, shoulder-season amortization ratio, bad-snow-year ancillary-decline delta
  9. Lead ancillary-per-visit economics; destination-branding lives paragraph 2+
  10. Frame Moment Factory as primary competitor with distinct wedge (MF ticketed-pathway ≠ Brite ambient village-integrated); don't lift zoos "rare at zoos" framing
  11. Frame MK Illumination as adjacent-not-competitive (European Seefeld only; no US ski-village book); don't lift hotels "direct competitor" framing
  12. Frame S4 Lights as Brite's partner (supply-chain), never competitor
  13. Don't use urgency tactics — ski capital runs on multi-month / multi-year cycles
  14. Don't cite Brite Nites seasonal residential case studies — Labs experiential/capital only

### T3 — Compose `risk-reversal-ski-resorts.md` (Offer E primary, T4)

- **Why**: T4 variant for procurement-weight signals — large multi-stream commitment with committee-heavy procurement.
- **Frontmatter**: same 5 keys; `preset: risk-reversal`; `when` = large multi-stream capital commitment + ownership-transition + local-investor-owned board-visible decision + Sr Director Base Area / Owner-Operator requesting performance underwrite.
- **Hook**: procurement-weight signal — $3B-scale village expansion (Killington tentpole), multi-year capital-plan vote, post-acquisition 3–12 month window with new ownership running audit. Tone: less playful, committee-safe; names the board-visibility.
- **Step 1 body** (3 paragraphs): Guarantee shape = **first-season-breakeven-or-no-pay**. Production-finance fee not billed until program breaks even against baseline in year one. `{BASELINE_TERMS}` operator-filled naming the revenue streams: compression-week ancillary-per-visit + F&B tenant paid commitments + regional sponsor pre-commits + ad-revenue pre-commits on DMX-pixel village displays, measured vs prior-year same-compression-window attach + per-cap baseline. `{LABS_PEER_VENUE}` default **Boyne SkyBridge** (inferred high-six-figure to low-seven-figure install at 200K LED scale). `{S4_PARTNER}` = "S4 Lights". Near-zero resort capital, near-zero execution risk framing.
- **Subject**: `{Season guarantee|Program underwrite|Break-even terms}`
- **wait_in_days**: `1`
- **Step 2 bump**: specificity as credibility — name the line items counting toward breakeven (gate-scan / compression-week per-cap / F&B POS vs prior-year baseline; sponsor paid commitments; ad-revenue pre-commits). If math doesn't land, fee isn't billed. Tone-match zoos risk-reversal step 2.
- **Step 2 subject**: `Re: {Season guarantee|Program underwrite|Break-even terms}`
- **Step 2 wait_in_days**: `3`
- **Vertical anti-slop** (add 2 T4-specific bullets on top of T2 list):
  - Avoid guarantee language that triggers resort finance / ownership legal review ("refund in full", "money-back", "zero-cost until delivered") — use outcome-gated framing ("fee not billed until breakeven")
  - Don't over-promise metrics beyond Labs' documented precedents (Boyne SkyBridge + Killington scale + S4 venue-list) — guarantee is credible only if Labs can defend the specific threshold

### T4 — Compose `list-building-ski-resorts-pilot-zone.md` (Offer A tactical, T2)

- **Why**: Tactical when prospect research shows long-tenured incumbent (Colorado Christmas Lights / Above All Holiday Lighting / regional installer) + decision-maker (GM or F&B Director) open to low-commitment test.
- **Frontmatter**: `when` = venue has long-tenured existing lighting vendor AND decision-maker open to low-commitment narrow-scope test; full-village replacement from cold outbound not on table. `situation_mining_row`: Ski Resorts, Offer A tactical complement.
- **Hook**: recency signal suggesting incumbent has bounded blind spot — new village F&B tenant opening without lighting scope, après-ski plaza refresh the holiday installer didn't touch, single-attraction sponsor-visibility gap, new GM / F&B Director / DOSM role change within 90d. Tone: conversational and specific, not pitching replacement.
- **Step 1 body** (3 paragraphs): Apply all 3 Offer A ledger fixes from BC-5879 zoos ledger (load-bearing per playbook § Offer A):
  - Fix 1: frontend deliverable = **rendered concept board (24"×36")** — tangible artifact, NOT "visualization" / "3D walkthrough" / "simulation"
  - Fix 2: backend guarantee metric is **village-native** — village dwell-time in pilot zone (sensor / head-count), après-ski F&B per-cap lift in pilot-adjacent F&B operations, or post-lift-close foot traffic in programmed hours. **NEVER photo-share** (gimmicky, disconnected)
  - Fix 3: confident commercial phrasing — "We'll underwrite the install cost. In exchange, we use the results (footage, metrics, resort name) in our sales material." NOT supplicant case-study ask.
  - `{PILOT_ZONE_AREA}` operator-filled (e.g., "the base-lodge courtyard", "the après-ski plaza near {F&B_TENANT}", "the village plaza"). `{LABS_PEER_VENUE}` default **Boyne SkyBridge** as specialist add-on. `{S4_PARTNER}` = "S4 Lights". One zone, one season, complementary to incumbent.
- **Subject**: `{One zone|Pilot zone|Short note}`
- **wait_in_days**: `1`
- **Step 2 bump**: reinforce narrow scope — one zone, one season, complementary. If pilot earns its keep, incumbent stays lead on full program, next-zone scope together. Tone-match zoos pilot-zone step 2.
- **Step 2 subject**: `Re: {One zone|Pilot zone|Short note}`
- **Step 2 wait_in_days**: `3`
- **Vertical anti-slop** (add Offer-A-specific discipline on top of ski-vertical list):
  - Don't frame pilot as incumbent replacement — "specialist add-on" / "complementary zone"
  - Don't over-specify incumbent vendor type ("holiday-lighting vendor" / "existing lighting vendor" / "incumbent" — NOT "lantern vendor" / "projection vendor")
  - Deliverable is rendered concept board (tangible 24"×36" artifact), NOT "visualization" or "3D walkthrough"
  - Pilot-zone metric is village-native (dwell / F&B per-cap / post-lift-close traffic) — NEVER photo-share (BC-5879 fix #2 discipline)
  - Frame commercial structure confidently, not supplicantly — Brite underwrites install cost, case-study rights = exchange, not favor

### T5 — Compose `risk-reversal-ski-resorts-pilot-zone.md` (Offer A tactical, T4)

- **Why**: T4 variant of pilot-zone — decision-maker wants performance underwrite before committing budget or scope expansion.
- **Frontmatter**: `when` = pilot-zone scope where decision-maker wants performance underwrite before committing budget; decision-maker open to low-commitment test but under committee or incumbent-relationship scrutiny.
- **Hook**: budget-risk-sensitivity signal — new village F&B tenant with tight opening window, sponsor-visibility commitment already promised on one attraction, board-level ancillary target on specific zone, Marketing or F&B role change within 90d. Tone: specific and committee-safe.
- **Step 1 body** (3 paragraphs): Guarantee shape = ONE named village-native metric and threshold. Pick dwell OR F&B per-cap OR post-lift-close foot traffic. Default = dwell time (`{DWELL_THRESHOLD}` operator-filled, e.g. "15 minutes average"). NEVER photo-share. Measurement = pressure-sensor mat / head-count / computer-vision on existing camera feeds OR POS delta on pilot-adjacent F&B operations vs comparable zone prior season same hours. If threshold not hit, case-study rights clause voids; venue walks with install + no obligation. `{LABS_PEER_VENUE}` / `{PILOT_ZONE_AREA}` / `{S4_PARTNER}` as above. One season, specialist add-on, complementary to incumbent.
- **Subject**: `{Pilot guarantee|Zone underwrite|On us}`
- **wait_in_days**: `1`
- **Step 2 bump**: specificity on measurement method — sensor/head-count vs POS delta vs CV-on-cam; baselined against comparable zone same hours prior season for apples-to-apples. Tone-match zoos pilot-zone risk-reversal step 2.
- **Step 2 subject**: `Re: {Pilot guarantee|Zone underwrite|On us}`
- **Step 2 wait_in_days**: `3`
- **Vertical anti-slop**: combine T4 discipline (no legal-review-triggering language, no over-promise) + Offer-A discipline (no replacement framing, no photo-share, rendered concept board, confident underwrite) + ski-vertical base list.

### T6 — Verification + validation

- **Why**: Lock in objective pass/fail per issue AC.
- **Steps** (from worktree root):
  1. `grep -l '{{' plugins/marketing/skills/email-copywriting/presets/list-building-ski-resorts*.md plugins/marketing/skills/email-copywriting/presets/risk-reversal-ski-resorts*.md` — expect zero matches
  2. `grep -l '<p>' plugins/marketing/skills/email-copywriting/presets/*ski-resorts*.md` — expect zero matches
  3. `grep -l '—' plugins/marketing/skills/email-copywriting/presets/*ski-resorts*.md` — expect zero matches (em-dash is hard failure in body per SKILL.md §8; `—` is allowed in frontmatter `when:` lines ONLY if unavoidable — prefer commas)
  4. `grep -l '{FIRST_NAME}' plugins/marketing/skills/email-copywriting/presets/*ski-resorts*.md` — MUST not appear in any `**Subject:**` line (manual inspection — subjects are on `**Subject:**` lines, `{FIRST_NAME_INLINE}` or similar greeting merges are fine in body)
  5. `grep -cEi 'lift.line|mountain.ops|on.mountain|ski.patrol' plugins/marketing/skills/email-copywriting/presets/*ski-resorts*.md` — MUST be 0 in body copy; occurrences in "Vertical anti-slop" `don't` bullets are allowed (literal-list per BC-5920 task-3)
  6. `grep -cEi 'magical|winter wonderland|alpine wonderland|enchanting snowscape|holiday charm' plugins/marketing/skills/email-copywriting/presets/*ski-resorts*.md` — same rule: 0 in body, allowed in anti-slop bullets
  7. `grep -cEi '\bvail\b|deer valley|\baspen\b|breckenridge|park city|whistler' plugins/marketing/skills/email-copywriting/presets/*ski-resorts*.md` — 0 in body; allowed in anti-slop bullets
  8. `grep -cEi 'fall.line|catch an edge|bluebird day|powder day|freshies|gnarly|corduroy' plugins/marketing/skills/email-copywriting/presets/*ski-resorts*.md` — 0 in body; allowed in anti-slop
  9. Manual check: each file has exactly 2 body sections (`## Step 1 skeleton` + `## Step 2 bump`), each has sign-off with `{Best|Cheers|Thanks}` spintax, no em-dash before sender name
  10. `./scripts/validate.sh` — MUST exit 0; baseline = 0 errors / 16 warnings (preserve)
  11. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — MUST exit 0
- **Verify**: Every issue-AC checkbox passes.

### T7 — Update `presets/README.md` manifest

- **Why**: Move Ski Resorts row from "Pending BC-5880" to "✅ Shipped in BC-5936" in the Exploring tier table.
- **Steps**: Edit `plugins/marketing/skills/email-copywriting/presets/README.md` — replace the Ski Resorts row's `Pending BC-5880` cells with `list-building-ski-resorts.md ✅ (+ pilot-zone variant)` / `risk-reversal-ski-resorts.md ✅ (+ pilot-zone variant)` to match the zoos-row convention from R-10.
- **Verify**: re-run `./scripts/validate.sh` — 0 errors / ≤16 warnings preserved.

## Verification (objective pass/fail — from issue AC)

- [ ] All 4 preset files exist at `plugins/marketing/skills/email-copywriting/presets/{list-building,risk-reversal}-ski-resorts[-pilot-zone].md`
- [ ] Each has 5-key frontmatter with `vertical: ski-resorts` and `entity: brite-labs`
- [ ] Each has Hook / Step 1 / Step 2 / Vertical anti-slop sections per SKILL.md §3
- [ ] `grep -l '{{'` returns no files
- [ ] `grep -l '<p>'` returns no files
- [ ] `grep -l '—'` returns no files (body copy)
- [ ] No merge variable in `**Subject:**` lines
- [ ] `grep -cEi 'lift.line|mountain.ops|on.mountain'` = 0 in body (allowed in anti-slop bullets)
- [ ] `grep -cEi 'magical|winter wonderland'` = 0 in body (allowed in anti-slop bullets)
- [ ] `grep -cEi '\bvail\b|deer valley|\baspen\b'` = 0 in body (allowed in anti-slop bullets)
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0
- [ ] `presets/README.md` Ski Resorts row updated

## Non-goals

- Don't compose Offer B (Permanent Village Backbone) — blocked on Facilities-VP sales-motion gate per playbook § V1 offer picks
- Don't re-propose Offer D as separate offer (folded into E)
- Don't pitch Lift Ops / Mountain Ops / Ski Patrol (wrong persona)
- Don't anchor on Vail / Deer Valley / Aspen enterprise (wrong ICP)
- Don't compose pre-R-8 (R-8 is the research feeder — already shipped via BC-5922 PR #188)

## Sources

- `plugins/marketing/references/vertical-playbooks/ski-resorts.md` (R-8 output, BC-5922)
- `plugins/marketing/skills/email-copywriting/SKILL.md` §3 Methodology + §8 Anti-slop
- `plugins/marketing/skills/email-copywriting/presets/list-building-zoos.md` + `risk-reversal-zoos.md` + `-pilot-zone` variants (format precedent — R-10, BC-5921 ledger)
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` + `risk-reversal-municipalities.md` (seed precedent — BC-5825)
- `docs/designs/email-copywriting-preset-roadmap.md` (R-14 entry)
- `docs/precedents/BC-5921.md` (task-1 MK inversion mechanism) + `docs/precedents/BC-5922.md` (ski persona gate + Moment Factory inversion at ski)
