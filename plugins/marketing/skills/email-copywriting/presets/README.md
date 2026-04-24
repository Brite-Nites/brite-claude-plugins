# Email Copywriting Preset Library - Lazy-Load Index

Presets are loaded on demand by the `email-copywriting` skill when the operator supplies both a `preset` (`list-building` | `risk-reversal`) and a `vertical` matching a handbook-canonical taxonomy entry. The skill reads exactly ONE preset file per invocation - the remaining files stay on disk and never touch the runtime context window - so runtime context cost is bounded regardless of how many presets the library grows to over time.

## Usage

The skill reads `plugins/marketing/skills/email-copywriting/presets/{preset}-{vertical-slug}.md` where `{preset}` is one of `list-building` or `risk-reversal` and `{vertical-slug}` is the kebab-case vertical identifier from the handbook 23-vertical taxonomy (see situation-mining SKILL.md §3 Brite-adaptation rows for the canonical list). Multi-offer variants per vertical use the extended filename `{preset}-{vertical}-{offer-slug}.md` and are selected at runtime when the operator passes a synthetic slug (e.g. `vertical: zoos-pilot-zone`). When the vertical file is missing, the skill falls back to the base inline skeleton in SKILL.md §3 plus the entity tone sourced from `docs/marketing-context.md`, and logs a one-line warning citing the fan-out issue that will ship the preset.

## Preset manifest

### 2026-04-21 scope pivot

The original BC-5879 scope was "fan out 10 Active-tier Nites preset files" (HOAs, Landscape Lighting, Landscape Architects, Builders, Universities). On 2026-04-21 the roadmap (`docs/designs/email-copywriting-preset-roadmap.md`) pivoted to 6 Labs-tier verticals (zoos, aquariums, casinos, hotels-resorts, ski-resorts, sports-stadiums) based on actual pipeline warmth rather than handbook tier discipline. Those 6 Labs verticals shipped via R-10..R-15 (BC-5932 / BC-5933 / BC-5934 / BC-5935 / BC-5936 / BC-5937). Active-tier Nites displaced work is tracked under [BC-6004](https://linear.app/brite-nites/issue/BC-6004). Exploring-tier and Future-tier fan-outs remain scoped under BC-5880 and BC-5881 respectively.

### Shipped (28 files across 7 verticals)

| Vertical | Entity | Primary list-building | Primary risk-reversal | Variants |
|---|---|---|---|---|
| Municipalities (BC-5825 seed) | Labs | `list-building-municipalities.md` ✅ | `risk-reversal-municipalities.md` ✅ | - |
| Zoos (R-10 BC-5932) | Labs | `list-building-zoos.md` ✅ | `risk-reversal-zoos.md` ✅ | `list-building-zoos-pilot-zone.md` ✅, `risk-reversal-zoos-pilot-zone.md` ✅ |
| Aquariums (R-11 BC-5933) | Labs | `list-building-aquariums.md` ✅ | `risk-reversal-aquariums.md` ✅ | `list-building-aquariums-production-finance.md` ✅, `risk-reversal-aquariums-production-finance.md` ✅ |
| Casinos (R-12 BC-5934) | Labs | `list-building-casinos.md` ✅ | `risk-reversal-casinos.md` ✅ | `list-building-casinos-pilot-zone.md` ✅, `risk-reversal-casinos-pilot-zone.md` ✅, `list-building-casinos-retention-subscription.md` ✅, `risk-reversal-casinos-retention-subscription.md` ✅ |
| Hotels & Resorts (R-13 BC-5935) | Labs | `list-building-hotels-resorts.md` ✅ | `risk-reversal-hotels-resorts.md` ✅ | `list-building-hotels-resorts-rate-premium.md` ✅, `risk-reversal-hotels-resorts-rate-premium.md` ✅ |
| Ski Resorts (R-14 BC-5936) | Labs | `list-building-ski-resorts.md` ✅ | `risk-reversal-ski-resorts.md` ✅ | `list-building-ski-resorts-pilot-zone.md` ✅, `risk-reversal-ski-resorts-pilot-zone.md` ✅ |
| Sports Stadiums (R-15 BC-5937) | Labs | `list-building-sports-stadiums.md` ✅ | `risk-reversal-sports-stadiums.md` ✅ | `list-building-sports-stadiums-plaza-pilot-zone.md` ✅, `risk-reversal-sports-stadiums-plaza-pilot-zone.md` ✅ |

### Displaced / deferred

| Tier | Verticals | Tracking issue | Target files |
|---|---|---|---|
| Active-tier Nites (displaced from BC-5879) | HOAs, Landscape Lighting, Landscape Architects, Builders & Developers, Universities | [BC-6004](https://linear.app/brite-nites/issue/BC-6004) | 10 (5 verticals × 2 preset types) |
| Exploring-tier | Bars & Restaurants, Event Venues, Auto Dealerships, Country Clubs / Golf Courses, Corporate Campuses | [BC-5880](https://linear.app/brite-nites/issue/BC-5880) | 10 remaining (original 16 scope minus Casinos / Hotels / Ski which shipped under R-10..R-15) |
| Future-tier | Theme Parks / Amusement Parks, Botanical Gardens / Arboretums, Historic Sites / Landmarks, Shopping Centers / Malls, Wineries / Vineyards / Breweries, Churches / Houses of Worship, Hospitals / Healthcare | [BC-5881](https://linear.app/brite-nites/issue/BC-5881) | 14 remaining (original 18 scope minus Sports Stadiums / Zoos & Aquariums which shipped under R-10..R-15) |

## Preset file shape

Every preset file follows the canonical template documented in SKILL.md §3: frontmatter block with 5 required keys (`preset`, `vertical`, `entity`, `when`, `situation_mining_row`), then a Hook section (recency-waterfall-anchored), then a Step 1 skeleton (greeting-merged first sentence, 2-3 paragraphs separated by `<br><br>`, spintaxed subject of 1-3 words with NO merge variables, sign-off block), then a Step 2 bump (short `Re: {subject}` reinforcement), then a Vertical anti-slop block (vertical-specific "don'ts" layered on top of the skill-wide anti-slop guardrails; use hyphens not em-dashes per BC-5936 task-1 precedent). See SKILL.md §3 for the canonical template and the authoritative list of required frontmatter keys.

## Seeding status

- The check-mark cell in the Shipped table marks a preset file that exists on disk and is operator-ready.
- Displaced and deferred verticals fall back to the base inline skeleton in SKILL.md §3 plus the entity tone from `docs/marketing-context.md` when the operator requests that vertical; a one-line warning is logged citing the fan-out issue that will ship the preset.
