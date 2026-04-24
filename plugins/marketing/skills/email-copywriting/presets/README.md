# Email Copywriting Preset Library — Lazy-Load Index

Presets are loaded on demand by the `email-copywriting` skill when the operator supplies both a `preset` (`list-building` | `risk-reversal`) and a `vertical` matching a handbook-canonical taxonomy entry. The skill reads exactly ONE preset file per invocation — the remaining 45 files stay on disk and never touch the runtime context window — so runtime context cost is bounded regardless of how many presets the library grows to over time.

## Usage

The skill reads `plugins/marketing/skills/email-copywriting/presets/{preset}-{vertical-slug}.md` where `{preset}` is one of `list-building` or `risk-reversal` and `{vertical-slug}` is the kebab-case vertical identifier from the handbook 23-vertical taxonomy (see situation-mining SKILL.md §3 Brite-adaptation rows for the canonical list). When the vertical file is missing — which is the expected state for all 22 non-Municipalities verticals until BC-5879/5880/5881 ship — the skill falls back to the base inline skeleton in SKILL.md §3 plus the entity tone sourced from `docs/marketing-context.md`.

## Preset manifest (46 files)

### Active tier — 12 files (BC-5879, Municipalities seeded in BC-5825)

| Vertical | Entity | list-building | risk-reversal |
|---|---|---|---|
| Municipalities | Labs | `list-building-municipalities.md` ✅ | `risk-reversal-municipalities.md` ✅ |
| HOAs | Nites | Pending BC-5879 | Pending BC-5879 |
| Landscape Lighting | Nites | Pending BC-5879 | Pending BC-5879 |
| Landscape Architects | Nites | Pending BC-5879 | Pending BC-5879 |
| Builders & Developers | Nites | Pending BC-5879 | Pending BC-5879 |
| Universities | Nites | Pending BC-5879 | Pending BC-5879 |

### Exploring tier — 16 files (BC-5880)

| Vertical | Entity | list-building | risk-reversal |
|---|---|---|---|
| Casinos | Labs | Pending BC-5880 | Pending BC-5880 |
| Hotels & Resorts | Nites / Labs | Pending BC-5880 | Pending BC-5880 |
| Bars & Restaurants | Labs | Pending BC-5880 | Pending BC-5880 |
| Event Venues | Labs | Pending BC-5880 | Pending BC-5880 |
| Auto Dealerships | Labs / Nites | Pending BC-5880 | Pending BC-5880 |
| Ski Resorts | Labs | `list-building-ski-resorts.md` ✅ (+ `-pilot-zone` variant) | `risk-reversal-ski-resorts.md` ✅ (+ `-pilot-zone` variant) |
| Country Clubs / Golf Courses | Nites / Labs | Pending BC-5880 | Pending BC-5880 |
| Corporate Campuses | Nites / Labs | Pending BC-5880 | Pending BC-5880 |

### Future tier — 18 files (BC-5881)

| Vertical | Entity | list-building | risk-reversal |
|---|---|---|---|
| Theme Parks / Amusement Parks | Labs | Pending BC-5881 | Pending BC-5881 |
| Sports Stadiums | Labs | Pending BC-5881 | Pending BC-5881 |
| Zoos / Aquariums | Labs | Pending BC-5881 | Pending BC-5881 |
| Botanical Gardens / Arboretums | Labs | Pending BC-5881 | Pending BC-5881 |
| Historic Sites / Landmarks | Labs | Pending BC-5881 | Pending BC-5881 |
| Shopping Centers / Malls | Nites / Labs | Pending BC-5881 | Pending BC-5881 |
| Wineries / Vineyards / Breweries | Labs / Nites | Pending BC-5881 | Pending BC-5881 |
| Churches / Houses of Worship | Nites | Pending BC-5881 | Pending BC-5881 |
| Hospitals / Healthcare | Nites | Pending BC-5881 | Pending BC-5881 |

## Preset file shape

Every preset file follows the canonical template documented in SKILL.md §3: frontmatter block with 5 required keys (`preset`, `vertical`, `entity`, `when`, `situation_mining_row`), then a Hook section (recency-waterfall-anchored), then a Step 1 skeleton (greeting-merged first sentence, 2–3 paragraphs separated by `<br><br>`, spintaxed subject of 1–3 words, sign-off block), then a Step 2 bump (short `Re: {subject}` reinforcement), then a Vertical anti-slop block (vertical-specific "don'ts" layered on top of the 7 skill-wide anti-slop guardrails). See SKILL.md §3 for the canonical template and the authoritative list of required frontmatter keys.

## Seeding status

- The check-mark cell (shown on the two Municipalities rows in the Active-tier table above) marks a preset that has been shipped in BC-5825 as the seed proof-of-pattern for the lazy-load infrastructure.
- A "Pending" cell with a fan-out issue ID means the preset has not yet been shipped; the skill falls back to the base inline skeleton in SKILL.md §3 plus the entity tone from `docs/marketing-context.md` when the operator requests that vertical. A one-line warning is logged citing the fan-out issue that will ship the preset.
