# BC-5879 Plan — Fan-out email-copywriting Labs-tier preset library (10 files)

**Linear:** https://linear.app/brite-nites/issue/BC-5879 (scope pivoted from Active-tier Nites → Labs experiential — see "Scope pivot" below)
**Branch:** `holden/bc-5879-fan-out-email-copywriting-active-tier-preset-library-10` (branch name kept; no mid-session rename)
**Worktree:** `.claude/worktrees/bc-5879`
**Blocked by:** BC-5825 (shipped as PR #157)
**Blocks:** none — pure content fan-out

## Scope pivot (2026-04-21)

Original BC-5879 scope: 5 Active-tier Nites verticals (HOAs, Landscape Lighting, Landscape Architects, Builders & Developers, Universities).

**Revised scope this session:** 5 Labs-experiential verticals selected by operator based on actual pipeline warmth rather than handbook tier discipline. Active-tier Nites verticals deferred to a follow-up issue (admin settled at commit time — BC-5879 comment + new issue for displaced Nites verticals OR scope-amendment to BC-5880).

**The 5:**

| # | Vertical | Slug | Entity | Tier (canonical) | situation-mining §3 rows |
|---|----------|------|--------|------------------|---|
| 1 | Zoos / Aquariums | `zoos-aquariums` | Labs | Future | worldview row 129, adjacent-offering row 187 |
| 2 | Casinos | `casinos` | Labs | Exploring | worldview row 114, adjacent-offering row 172 |
| 3 | Hotels & Resorts | `hotels-resorts` | Labs (picked from mixed Nites/Labs canon) | Exploring | worldview row 115, adjacent-offering row 173 |
| 4 | Ski Resorts | `ski-resorts` | Labs (picked from mixed Labs/Nites canon) | Exploring | worldview row 119, adjacent-offering row 177 |
| 5 | Sports Stadiums | `sports-stadiums` | Labs | Future | worldview row 128, adjacent-offering row 186 |

All 5 are Labs-entity. Homogeneous entity means consistent tone floor: experiential, permanent/capital, commercial-commitment-aware, higher-ticket than Nites seasonal. Labs tier in §3 matrix: T3 default, T4 when multi-year spend / committee-heavy.

**Depth decision (carried from prior planning):** deeper vertical voice, ~55–65 lines per preset, multi-anchor Hook, vertical-specific spintax, extended anti-slop. Lazy-load keeps runtime context cost flat regardless of preset length.

**Authoring strategy:** per-vertical sequential, with a mandatory **check-in gate after each task** — operator reviews the authored files before I start the next task. No blow-through.

## Per-task check-in gate (uniform across all tasks)

After every task I will:
1. Announce: "Task N complete — [files authored]".
2. List the exact file paths written and their line counts.
3. Briefly summarize the design choices that went into the task (hook anchor selection, CTA framing, any anti-slop additions unique to the vertical).
4. **Pause** and wait for operator review / approval before starting the next task.
5. If operator flags changes, fix in place before moving on.

No parallel subagents. Main thread, one task at a time.

## Context anchors (already read in Step 4)

- `plugins/marketing/skills/email-copywriting/SKILL.md` — §3 Methodology (EB format rules, Hormozi value equation, Labs-tier matrix rows, recency waterfall, base skeletons A/B, lazy-load pattern), §8 anti-slop.
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` — Labs T2 seed (proof-of-pattern for skeleton A, Labs entity).
- `plugins/marketing/skills/email-copywriting/presets/risk-reversal-municipalities.md` — Labs T4 seed (proof-of-pattern for skeleton B, Labs entity). Note: Municipalities is also a Labs-tier experiential vertical, so its seeds are the nearest-neighbor template for all 5 of tonight's verticals.
- `plugins/marketing/skills/email-copywriting/presets/README.md` — manifest table.
- `plugins/marketing/skills/situation-mining/SKILL.md` §3 rows 114 / 115 / 119 / 128 / 129 (worldview matrix) + rows 172 / 173 / 177 / 186 / 187 (adjacent-offering) — citation sources.
- `docs/precedents/BC-5825.md` — skeleton/skin split precedent.
- `docs/precedents/BC-5824.md` — handbook-canon-first (Supply out-of-scope).

## File shape (inherited from BC-5825 §3, identical for all 10 files)

```yaml
---
preset: list-building | risk-reversal
vertical: <kebab-slug>
entity: brite-labs   # all 5 tonight — Labs homogeneous
when: <one-line trigger, typically a recency-waterfall signal or booking-calendar keyword>
situation_mining_row: <cite situation-mining SKILL.md §3 rows by number + description>
---

# {preset} | {Vertical Display} | Brite Labs

## Hook (vertical-specific recency waterfall)
<2–3 sentences: primary recency anchor + fallback + greeting-merge guidance. Labs tone: experiential-aware, capital-commitment-aware, not vendor-desperate.>

## Step 1 skeleton
**Subject:** `{1-3 word spintax, no {FIRST_NAME}}`
**Body:**
<greeting-merged first sentence with recency anchor + worldview hypothesis
<br><br>proof-point paragraph with {PROOF_POINT_COMPANY} / {PROOF_POINT_NUMBER}
<br><br>CTA paragraph with {FREE_ASSET_NOUN} (T3 default) or {GUARANTEE_TERMS} (T4)
<br>{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}>
**wait_in_days:** 1

## Step 2 bump
**Subject:** `Re: {subject}`
**Body:** <short reinforcement, 1 paragraph, references step 1 without summarizing>
**wait_in_days:** 3

## Vertical anti-slop
- 5–7 vertical-specific "don't" bullets on top of §8 skill-wide guardrails.
```

## Per-vertical content anchors (Labs tone, all 5)

**Labs tone markers** (carry across all 5 verticals): experiential-infrastructure language (never "lighting package"), commercial-commitment-respectful ("we understand a capital ask deserves care"), outcome-specific (not buzzword-heavy — no "smart venue", no "world-class"), peer-project proof-points from Labs case-study library (reference `docs/marketing-context.md` — the fact-checker on these must be the operator at review time).

### 1. Zoos / Aquariums (`zoos-aquariums`)

- **Signal (worldview row 129):** announces night-open seasonal event (Boo at the Zoo, Wild Lights, glow-night).
- **Worldview inference:** night events = incremental revenue; education-entertainment blur — venues look for revenue diversification beyond day-ticket.
- **Directional argument:** pitch **animal-safe** programmable lighting + visitor-journey design, not stadium-style rigs. "Animal-safe" is load-bearing and differentiating — must appear in hook or proof-point, and must be real (Labs case-study-backed, not invented).
- **T2 list-building CTA:** free night-event lighting concept / visitor-journey mock-up for a specific exhibit. `{FREE_ASSET_NOUN}` = "night-event concept" or "visitor-journey mock-up".
- **T4 risk-reversal guarantee:** pilot-exhibit phase-gate — "one exhibit programmed for opening weekend of {SEASONAL_EVENT}; if it doesn't hit {DWELL_TIME_METRIC} or {TICKET_ATTACH_METRIC}, the rest of the run isn't billed."
- **Vertical anti-slop (draft):**
  - Don't use stadium or concert-rig language — animal welfare is the headline.
  - Don't over-promise ticket-revenue lift (attribution is hard; cite peer-venue dwell time or attach rate instead).
  - Don't reference Nites seasonal motion — this is a Labs permanent-overlay pitch.
  - Don't use "wow" / "magical" / "immersive" buzzwords — reads as promotional; use outcome-specific language (dwell time, repeat visits, tickets-per-visit).
  - Don't reference zoo animals by species in hook (reads as formulaic); cite the exhibit's event / seasonal package name.
  - Don't pitch to marketing — pitch to Operations or Guest Experience; marketing decides promos, operations owns the rig.
  - Don't use urgency — seasonal-event planning runs ~6 months ahead.

### 2. Casinos (`casinos`)

- **Signal (worldview row 114):** announces main-floor renovation or new restaurant / entertainment tenants.
- **Worldview inference:** gaming-floor refresh drives visitor-retention KPIs; non-gaming revenue is the new growth vector.
- **Directional argument:** position programmable lighting as a **retention multiplier**, not a cosmetic upgrade. Label it "retention infrastructure" explicitly.
- **T2 list-building CTA:** free programmable-scene concept for the newly-announced tenant zone (restaurant, bar, entertainment lounge). `{FREE_ASSET_NOUN}` = "programmable-scene concept" or "retention-zone lighting spec".
- **T4 risk-reversal guarantee:** pilot-scene phase-gate — "one programmable zone tied to the {TENANT_NAME} opening; if it doesn't hit {DWELL_TIME_METRIC} or {REVENUE_PER_VISIT_METRIC} vs the pre-install baseline within 90 days, remaining zones aren't billed."
- **Vertical anti-slop (draft):**
  - Don't use gaming-floor / pit-specific language — the pitch is non-gaming entertainment infrastructure.
  - Don't reference Las Vegas as the default — regional-market casinos (Oklahoma, Mississippi, tribal ops) are the volume ICP; use case studies from those markets where available.
  - Don't over-use "experience" — it's a tell. Use "retention", "attach rate", "revenue per visit".
  - Don't pitch to Facilities — pitch to COO, VP Operations, or VP Non-Gaming Revenue; Facilities executes, Operations decides.
  - Don't frame as "aesthetic upgrade" — reads as expense, not investment.
  - Don't use urgency.
  - Don't reference slot-machine-specific lighting (not Brite's zone).

### 3. Hotels & Resorts (`hotels-resorts`)

- **Signal (worldview row 115):** property markets a seasonal holiday or "winter lights" package (or summer equivalent — "Light + Lodge", etc.).
- **Worldview inference:** rooms are commodity; differentiation is destination experience. Package pricing supports CAPEX that per-room economics don't.
- **Directional argument:** pitch seasonal / programmable lighting as a **rate-premium driver**, with photo-driven revenue proof (package revenue before/after, booking-window extension, direct-channel booking mix shift). Labs frame = programmable permanent rig, not holiday-overlay-only.
- **T2 list-building CTA:** free programmable-lighting concept for the property's winter-package or destination-experience rollout. `{FREE_ASSET_NOUN}` = "destination-experience concept" or "programmable-rig spec for {PACKAGE_NAME}".
- **T4 risk-reversal guarantee:** phase-gate on package-revenue proof — "programmable rig installed before the {PACKAGE_SEASON} launch; if package bookings don't exceed {PREVIOUS_SEASON_BASELINE} by {THRESHOLD}, phase 2 isn't billed."
- **Vertical anti-slop (draft):**
  - Don't pitch commodity "lighting upgrade" — pitch destination-experience / rate-premium infrastructure.
  - Don't over-use "romantic" / "ambiance" — reads as promotional; use concrete booking / rate metrics.
  - Don't reference Nites-side seasonal installs as precedent (H&R is Labs in this preset).
  - Don't pitch to GM — pitch to VP Revenue Management or VP Experience; GM executes.
  - Don't cite wedding revenue as default proof-point (too narrow); cite package-season / destination-weekend revenue where possible.
  - Don't use urgency.
  - Don't pitch flagship brands as default ICP (Marriott / Hilton enterprise procurement is slow); cite independent / boutique / regional resort brands.

### 4. Ski Resorts (`ski-resorts`)

- **Signal (worldview row 119):** opens or expands village retail / dining district; invests in village F&B tenancy.
- **Worldview inference:** village is the second profit center; après-ski economy needs ambiance to retain guests post-lift-close.
- **Directional argument:** pitch experiential lighting + seasonal overlays as a **revenue-per-visitor lever** — the lever is "village dwell time after 4pm".
- **T2 list-building CTA:** free village-ambiance concept for the retail / dining district, tied to a specific après-ski window. `{FREE_ASSET_NOUN}` = "village-dwell concept" or "après-ski ambiance spec".
- **T4 risk-reversal guarantee:** phase-gate on village-dwell metric — "one block of village programmed by {SEASON_OPENING_DATE}; if post-lift-close dwell time in the programmed zone doesn't exceed {BASELINE_MINUTES}, remaining blocks aren't billed."
- **Vertical anti-slop (draft):**
  - Don't pitch lift-line / on-mountain lighting — Brite's zone is village, not mountain ops.
  - Don't reference Colorado / Utah resorts as default ICP (enterprise procurement is slow); cite mid-market regional resorts (Vermont, Michigan, Montana).
  - Don't frame as holiday-only — the motion is season-long village economics.
  - Don't use "magical" / "winter wonderland" language — reads as promotional.
  - Don't pitch to Lift Operations — pitch to VP Village Operations, Director of Guest Services, or F&B Director.
  - Don't use urgency.
  - Don't reference destination weddings — off-theme for the village-dwell thesis.

### 5. Sports Stadiums (`sports-stadiums`)

- **Signal (worldview row 128):** adds off-season concert or family-event calendar.
- **Worldview inference:** stadium utilization must exceed game-day economics; off-season calendar is the activation play.
- **Directional argument:** pitch programmable lighting as **concert / event differentiator** — the lever is "event revenue per off-season weekend" or "non-game-day booking rate".
- **T2 list-building CTA:** free programmable-rig concept for one off-season event category (concert, family-show, graduation, community event). `{FREE_ASSET_NOUN}` = "off-season rig concept" or "event-category lighting spec".
- **T4 risk-reversal guarantee:** phase-gate on event-differentiator proof — "programmable rig installed before the {OFF_SEASON_EVENT_SERIES}; if event bookings don't exceed {BASELINE_COUNT} over {TIMEFRAME}, rig expansion to the full bowl isn't billed."
- **Vertical anti-slop (draft):**
  - Don't pitch game-day lighting — game-day systems are broadcast-spec and locked; Brite's zone is off-season activation.
  - Don't reference pro-team brands as default ICP (pro stadium procurement is multi-year and committee-heavy); cite minor-league parks, college stadiums, MLS venues, or multipurpose regional venues.
  - Don't use broadcast-lighting language (lux ratings, camera-spec CRI) — off-theme; use audience-experience language (zone programming, show-calling, music-sync).
  - Don't pitch to Facilities — pitch to VP Bookings or VP Non-Game-Day Revenue.
  - Don't reference specific artists in case-study framing — reads as name-dropping.
  - Don't use urgency.
  - Don't over-promise attendance lift — cite repeat-booking or event-revenue-per-date metrics instead.

## Tasks

**Each task ends with a mandatory operator check-in gate** (per pacing commitment above). I will NOT start task N+1 until the operator confirms task N.

### Task 1 — Zoos / Aquariums pair

**Files:** `plugins/marketing/skills/email-copywriting/presets/list-building-zoos-aquariums.md` + `risk-reversal-zoos-aquariums.md`
**Cites:** situation-mining §3 worldview row 129 + adjacent-offering row 187.
**Entity:** `brite-labs`.
**Verification:** 5-key frontmatter, `<br><br>` breaks, no `<p>` / `{{` / em-dash, no `{FIRST_NAME}` in subject, ≥5 anti-slop bullets, 55–65 lines total, Labs tone markers present (experiential + capital-aware), animal-safe language load-bearing.
**Gate:** pause for operator review before Task 2.

### Task 2 — Casinos pair

**Files:** `list-building-casinos.md` + `risk-reversal-casinos.md`
**Cites:** rows 114 + 172.
**Entity:** `brite-labs`.
**Verification:** same 8-item checklist + "retention infrastructure" framing load-bearing, zero gaming-floor language in body copy.
**Gate:** pause.

### Task 3 — Hotels & Resorts pair

**Files:** `list-building-hotels-resorts.md` + `risk-reversal-hotels-resorts.md`
**Cites:** rows 115 + 173.
**Entity:** `brite-labs` (picked from mixed Nites/Labs canon per session decision).
**Verification:** same checklist + "rate-premium" or "destination-experience" framing load-bearing, zero flagship-brand name-drop in body copy.
**Gate:** pause.

### Task 4 — Ski Resorts pair

**Files:** `list-building-ski-resorts.md` + `risk-reversal-ski-resorts.md`
**Cites:** rows 119 + 177.
**Entity:** `brite-labs` (picked from mixed Labs/Nites canon per session decision).
**Verification:** same checklist + "village-dwell" framing load-bearing, zero lift-line / on-mountain language.
**Gate:** pause.

### Task 5 — Sports Stadiums pair

**Files:** `list-building-sports-stadiums.md` + `risk-reversal-sports-stadiums.md`
**Cites:** rows 128 + 186.
**Entity:** `brite-labs`.
**Verification:** same checklist + "off-season activation" framing load-bearing, zero game-day lighting / broadcast-spec language.
**Gate:** pause.

### Task 6 — Update `presets/README.md`

**Edits:** amend the manifest table rows for the 5 shipped verticals to ✅ with the new filenames. Because all 5 are from Exploring/Future tiers (not Active), the Active-tier section rows stay `Pending BC-5879` — but since BC-5879 is pivoting off Active-tier this session, add a note row citing the pivot ("Active-tier Nites fan-out — follow-up issue TBD post-session").
**Verification:** grep for the 5 new filenames; spot-check that Municipalities rows stay ✅.
**Gate:** pause.

### Task 7 — Anti-slop grep verification

**Run (from `plugins/marketing/skills/email-copywriting/presets`):**

```bash
# Zero matches expected:
grep -l '{{' list-building-zoos-aquariums.md risk-reversal-zoos-aquariums.md list-building-casinos.md risk-reversal-casinos.md list-building-hotels-resorts.md risk-reversal-hotels-resorts.md list-building-ski-resorts.md risk-reversal-ski-resorts.md list-building-sports-stadiums.md risk-reversal-sports-stadiums.md
grep -l '<p>' list-building-zoos-aquariums.md risk-reversal-zoos-aquariums.md list-building-casinos.md risk-reversal-casinos.md list-building-hotels-resorts.md risk-reversal-hotels-resorts.md list-building-ski-resorts.md risk-reversal-ski-resorts.md list-building-sports-stadiums.md risk-reversal-sports-stadiums.md
grep -l $'—' list-building-zoos-aquariums.md risk-reversal-zoos-aquariums.md list-building-casinos.md risk-reversal-casinos.md list-building-hotels-resorts.md risk-reversal-hotels-resorts.md list-building-ski-resorts.md risk-reversal-ski-resorts.md list-building-sports-stadiums.md risk-reversal-sports-stadiums.md
```

Plus manual review:
- Subject-line scan for `{FIRST_NAME}` or any merge variable in any of the 10 files' `**Subject:**` lines.
- Supply-vertical trigger scan: `grep -iE 'installer|property manag' *.md` — matches must only appear in anti-slop "don't" bullets.

**Verification:** all three grep checks return zero; subject-line and Supply-trigger checks clean.
**Gate:** pause.

### Task 8 — `validate.sh` + `check-guardrails.sh`

**Commands (from worktree root):**

```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

**Expected:** both exit `0`. Warning delta from BC-5826 baseline (17 warnings) should be 0; any new warning gets surfaced + explained.
**Gate:** final — confirm results with operator, then hand off to `/workflows:review` → `/workflows:ship` (and handle BC-5879 scope-pivot admin at commit / PR description time).

## Quality gates (applied across all tasks)

Per BC-5825 §8 anti-slop hard failures:

- No `{{` double-brace tokens in body or subject.
- No `<p>` or `</p>` tags.
- No em-dashes (`—`) in body copy. (Preset file template discussion can mention them in prose, but body copy and subject lines must not.)
- No merge variables in subject lines.
- Exactly 2 steps (step 1 + step 2 bump).
- `situation_mining_row:` citation present, non-empty, and references a real row number in situation-mining §3.
- Hypothesis framing — "we noticed X and thought Y" not "you are X".
- No Supply-vertical triggers in body copy.
- All `{VARIABLE}` tokens in body + subject must be present in the preset's implied custom_variables set (the preset itself doesn't emit a JSON artifact, but the skill that reads the preset will — so variable names must match the skill's §4 JSON schema convention: uppercase snake-case).

## Non-goals (per BC-5879 issue body — still binding after scope pivot)

- Do NOT modify `SKILL.md` or the Municipalities seeds.
- Do NOT add entity-variant fan-out (one preset per `{preset}-{vertical}`, not per `{preset}-{vertical}-{entity}`). Honored by picking single canonical entity for Hotels & Resorts and Ski Resorts.
- Do NOT bump plugin version.
- Do NOT touch Exploring tier rows that aren't in tonight's 5 (Bars & Restaurants, Event Venues, Auto Dealerships, Country Clubs, Corporate Campuses) or Future tier rows that aren't in tonight's 5 (Theme Parks, Botanical Gardens, Historic Sites, Shopping Centers, Wineries, Churches, Hospitals).

## Open questions / deferred admin

- **BC-5879 scope-pivot administration.** Linear issue title/description still reads "Active-tier". Decision deferred to PR / commit time — options: (a) rename + rewrite BC-5879 description to Labs-tier + create a follow-up issue for the displaced Active-tier Nites scope, (b) add a Linear comment noting the pivot and leave admin to a future session. Pick at review stage.
- **Case-study verification.** Each preset references Labs case studies generically (`{PROOF_POINT_COMPANY}`, `{PROOF_POINT_NUMBER}`). Operator must confirm at review that real Labs case studies exist in `docs/marketing-context.md` or internal references for each vertical. If they don't, the preset still ships (operator fills `{PROOF_POINT_*}` at campaign time), but we should surface the coverage gap.

## Completion signal

When Task 8 passes, commit with message `BC-5879: fan out email-copywriting Labs-tier presets (10 files — Zoos, Casinos, Hotels, Ski, Stadiums)`. Then hand off to `/workflows:review` → `/workflows:ship`, and handle the BC-5879 scope-pivot admin (Linear comment + follow-up issue for displaced Active-tier Nites fan-out) at PR description stage.
