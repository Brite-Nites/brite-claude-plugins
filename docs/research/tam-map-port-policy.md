---
title: tam-map port policy — locked policy decisions for BC-5946 + BC-5947
status: locked
date: 2026-04-24
issue: BC-5945
blocks: [BC-5946, BC-5947]
upstream: Revgrowth1/tam-map@9f5c72e74b (MIT)
---

# tam-map port policy

This research locks the five policy decisions every downstream tam-map port issue (BC-5946 port files, BC-5947 MCP registration) depends on. Without these locks, BC-5946 would have to guess at the enrichment pluggability contract, BC-5947 would have to guess at the MCP-cap messaging in `CLAUDE.md`, and the downstream icp-scoring / tam-mapping skills would have to guess at the 0-100 vs A/B/C rubric choice.

Decisions were made during a Socratic brainstorm session (2026-04-24) against the issue's proposed defaults. Two decisions stand as issue-proposed; three were pressure-tested and revised.

---

## § 1 — MCP-cap advisory (reframed)

**Decision.** The `plugins/marketing/.mcp.json` grows from 1 plugin-level MCP server (Salesforce only) to **5** after BC-5947 lands the three tam-map servers (Spider.cloud native, AI Ark stdio wrapper, Discolike stdio wrapper) and BC-5538 lands the brite-enrichment MCP. This is **at** the CLAUDE.md soft-cap threshold of "~5–6 per plugin", not over it. The Gotcha reframes the cap as advisory-with-measurement rather than an absolute ceiling requiring an exception.

**Rationale.** The issue's original framing ("MCP-cap exception formalization") conflated plugin-level and user-level MCP registrations. The Email Bison MCPs are registered at user-level per `gotcha_http_mcp_substitution_broken.md`; they do not count against the plugin-level cap. The actual plugin-level count post-port is 5, which is within advisory bounds.

The purpose of the soft cap is to protect context budget and startup latency. Those are measurable properties, not a hard-coded number. The reframed Gotcha asks plugin authors to **measure** both dimensions against a clean-session baseline and demonstrate acceptable impact, rather than requesting an exception purely on count.

**Measurement methodology (to be executed inline in BC-5947 worktree):**
1. Baseline: `claude --version` cold start with only Salesforce MCP registered. Record wall-clock seconds and the plugin context-block size (grep MCP-related lines in the session init log).
2. Post-port: same measurement with all 5 plugin MCPs registered (Salesforce + Spider + AI Ark + Discolike + brite-enrichment).
3. Delta thresholds (placeholder, adjust post-measurement):
   - Startup-latency delta: **< 2s**
   - Context-budget delta: **< 500 tokens** per session init
4. If either threshold is exceeded, BC-5947 surfaces the finding and this policy is revised before merge.

**CLAUDE.md Gotcha replacement text:**
> **MCP server soft cap ~5–6 per plugin.** The cap is advisory, scoped per-plugin (user-level registrations — e.g., Email Bison — do not count). The cap protects startup latency and context budget, which are measurable: a plugin at or near the cap must demonstrate a startup-latency delta < 2s and a context-budget delta < 500 tokens against a clean-session baseline. See `docs/research/tam-map-port-policy.md` § 1 for the measurement methodology.

**Links:** See also `memory/MCP_cap_advisory.md` for the memory-side summary.

---

## § 2 — Clay-stance update (additive)

**Decision.** The existing rule in `memory/project_clay_deprecated.md` ("Clay is no longer part of Brite's marketing stack; use brite-enrichment CLI + brite-data-platform audience views") stands verbatim. An **additive amendment** documents a narrow exception inside the tam-mapping workflow: during the BlitzAPI → Prospeo waterfall shipped by upstream tam-map (pending brite-enrichment MCP GA in BC-5538), tam-mapping calls BlitzAPI directly as a new (15th) enrichment provider.

**Verified fact.** Upstream tam-map has **zero mentions of Clay**. The BlitzAPI → Prospeo waterfall is a direct third-party API composition, not Clay-mediated. Therefore adopting it does not violate the Clay-deprecation rule. It does, however, introduce BlitzAPI as a new provider, and the user accepted this trade-off explicitly during brainstorm.

**Amendment text to append to `memory/project_clay_deprecated.md`:**

> ## 2026-04-24 amendment — tam-mapping exception (BC-5945)
>
> tam-mapping (Tier 3.2 skill) uses the upstream `BlitzAPI → Prospeo` enrichment waterfall directly until brite-enrichment MCP (BC-5537/5538) reaches GA. This **is not** a re-adoption of Clay. BlitzAPI is a new third-party provider (owner-discovery at unlimited credits, 5 req/s serialized); Prospeo is already on the brite-enrichment CLI 14-provider list.
>
> Swap path: see `docs/decisions/008-tam-mapping-enrichment-pluggability.md`. Selection mechanism: `enrichment_provider` field in `plugins/marketing/plugin.json` userConfig. Valid values: `blitz_waterfall`, `brite_cli`, `brite_mcp`, `skip`.

**Why the amendment is additive, not a revision:** the original Clay rule applies broadly to all GTM skills (list-building, data-enrichment, etc.). The tam-mapping exception is narrow — one skill, one waterfall, a documented sunset path. Revising the broader rule risks re-opening the Clay question for skills the amendment was never about.

---

## § 3 — Enrichment pluggability (summary; full spec in ADR 008)

**Decision.** tam-mapping's enrichment layer is pluggable via a `plugin.json` userConfig field `enrichment_provider` with enum values `blitz_waterfall | brite_cli | brite_mcp | skip`. The input/output record schema is shared across providers; providers differ only in implementation.

This section summarizes the contract. The canonical spec lives in `docs/decisions/008-tam-mapping-enrichment-pluggability.md`. Any future schema extension requires an ADR amendment.

**Selection mechanism summary:**
- `blitz_waterfall` — upstream tam-map default, BlitzAPI → Prospeo via stdio wrappers
- `brite_cli` — shell out to `services/enrichment/cli.py` in brite-data-platform (available today, pre-MCP)
- `brite_mcp` — call brite-enrichment MCP once BC-5538 ships
- `skip` — pass through unenriched (downstream tools like BC-2717 list-building handle enrichment)

**Schema summary (full detail in ADR 008):**
- Input: `{domain, company_name, linkedin_url?, title_seed?, geo?}`
- Output: `{email, mobile?, phone?, title?, linkedin_url?, confidence_score (0-1 float), source, provider_raw?}`

**Default resolution order** (if `enrichment_provider` unset): check BC-5538 status → if GA use `brite_mcp`; else check brite-enrichment CLI presence → if found use `brite_cli`; else fall through to `blitz_waterfall`. `skip` is opt-in only.

---

## § 4 — icp-scoring dual-mode

**Decision.** The `icp-scoring` skill and the tam-mapping-embedded fit-scoring step share a dual-mode rubric: `rubric: "abc" | "score_0_100"`. Consumer-specific defaults:

| Consumer | Default rubric | Model | Cost/1k records | Threshold |
|----------|---------------|-------|-----------------|-----------|
| tam-mapping (Phase 8 fit-scoring) | `abc` | Claude Haiku 4.5 | ~$0.05 | — |
| standalone icp-scoring skill | `score_0_100` | Claude Sonnet 4.6 | ~$0.50 | warn at 1000+ records |

**Rationale.** The two consumers have different volume profiles and quality needs. tam-mapping hits discovery-phase volumes (hundreds to thousands of candidate companies) and needs cheap, fast classification; A/B/C on Haiku is the right price-performance point. Standalone icp-scoring is invoked on curated lists (tens to low hundreds) where quality and reasoning matter; 0–100 on Sonnet with reasoning text is appropriate. A single-rubric design would either overspend (Sonnet everywhere) or underspec (A/B/C everywhere).

**Warning behavior.** When `score_0_100` is selected and the input list exceeds 1000 records, the skill emits a user-facing warning with the estimated cost (`$0.50 × N/1000`) and prompts for explicit confirmation before proceeding. This protects against accidentally running Sonnet-scale costs on tam-mapping-scale volumes.

**Overrides.** Users can override the default rubric per invocation. tam-mapping with `--rubric=score_0_100` works but hits the warning threshold almost immediately.

---

## § 5 — Labs vertical priors (REFRAMED — reference-lazy architecture)

**Decision.** The tam-mapping skill resolves per-vertical ICP priors via **lazy-loaded companion files** at `plugins/marketing/references/vertical-playbooks/{vertical}-icp.md`, not by inlining ICP prompts in `SKILL.md`. `SKILL.md` contains a ~10-line resolver that checks for a `{vertical}-icp.md` file matching the user's vertical argument and falls through to custom-ICP-text mode if no match.

**Why this reframes the issue's "pick 2–3 verticals" question.** The issue asked which 2–3 of the 6 Brite Labs playbooks to pre-load ICP prompts for. That question presupposes **inline** pre-loading. Under the reframed architecture, the question evaporates: lazy-loaded 30-line files cost effectively zero per unused vertical, so v1 ships ICP files for **all 6** Labs playbooks (zoos, aquariums, casinos, hotels-resorts, ski-resorts, sports-stadiums) plus the custom-mode fallback.

**Architectural rationale.** The shipped playbooks are 230–290 lines each, prose-heavy, and email-copy-authorship focused (buyer persona narratives, offer archetypes, voice rules, anti-slop rules, peer venue lists). tam-mapping needs structured **firmographic filters** (employee bands, geographic distribution, industry codes, persona titles, exclusion criteria) in a shape AI Ark's discovery API consumes. The two artifacts serve different consumers, so duplicating ICP filter shape into `SKILL.md` would (a) bloat every skill activation with unused vertical data, (b) drift against the canonical playbook, and (c) cap at whatever count fits in a skill file.

Co-locating `{vertical}-icp.md` alongside `{vertical}.md` keeps both artifacts discoverable, avoids duplication (each file serves its own consumer), and scales to arbitrary vertical count with zero skill-side churn.

**`{vertical}-icp.md` file shape (~30 lines):**
- Frontmatter: `vertical`, `version`, `sourced_from` (playbook path)
- `## Firmographics` — industry codes, employee band, revenue range, entity structure (501(c)(3), municipal, LLC, etc.)
- `## Geography` — country, regional clustering, market size criteria
- `## Persona titles` — seed titles for enrichment `title_seed` field
- `## Peer-venue seeds` — ~5–10 canonical venue names for Discolike lookalike expansion
- `## Exclusion criteria` — compliance lines (e.g., "NOT tank-interior lighting for aquariums"), size thresholds, category exclusions
- `## Intent signals` — trade-press keywords, capital-plan keywords, role-change keywords

**Resolver logic in `SKILL.md` (sketch):**
```
When user invokes /marketing:tam-map <arg>:
  1. If <arg> matches a filename at references/vertical-playbooks/{arg}-icp.md → Read that file. Use its firmographics, personas, peer-venues, exclusions, intent signals to construct the AI Ark discovery query and subsequent pipeline inputs.
  2. Else → Treat <arg> as a free-text ICP description. Proceed in custom mode.
  3. If no arg → List available verticals (`ls references/vertical-playbooks/*-icp.md`) + prompt for custom mode.
```

**ICP-file authoring scope.** Authoring the 6 `{vertical}-icp.md` files (~180 lines total) is **not** part of BC-5945. It folds into BC-5946 (port tam-map references + scripts + guides) as an additional task group, or spins off as its own R-issue. The BC-5945 deliverable is the policy + shape specification only.

**Future extension.** A 7th vertical (or a Nites / Supply entity vertical) is added by authoring a new `{vertical}-icp.md` file. No `SKILL.md` change required. No plugin re-release required (ICP files are read at runtime).
