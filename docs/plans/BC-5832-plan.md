# BC-5832 Plan — `tam-mapping` marketing skill

**Issue:** [BC-5832](https://linear.app/brite-nites/issue/BC-5832) — Create marketing skill: tam-mapping (7-phase TAM database construction, absorbs local-enrichment + tam-map 8-provider stack)
**Branch:** `holden/bc-5832-create-marketing-skill-tam-mapping-7-phase-tam-database` (Linear-canonical) → shortened to `holden/bc-5832-tam-mapping` for worktree readability
**Worktree:** `.claude/worktrees/bc-5832-tam-mapping/`
**Plugin under change:** `plugins/marketing/`
**Version bump:** marketing 0.3.4 → 0.3.5 (BC-6000 same-commit rule)

---

## Brainstorm decisions (locked from session-start Step 5)

1. **Tool surface drops 2 unregistered MCPs.** Issue body's `mcp__plugin_marketing_enrichment__*` (pending BC-5538 GA) and `mcp__plugin_marketing_github__*` (no github MCP for marketing plugin) both removed from `allowed-tools` per CLAUDE.md silent-fail gotcha. Phase 5 invokes scripts via `Bash`. Cross-repo handbook reads via `gh api` via `Bash` per `reference_handbook_access.md`.
2. **`plugin.json` userConfig added in this PR.** New field `enrichment_provider` with enum `blitz_waterfall | brite_cli | brite_mcp | skip` (default `blitz_waterfall`). Same-commit version bump.
3. **Enum naming `blitz_waterfall`** (NOT `blitz_prospeo_waterfall` from issue body). ADR-008 + tam-map-port-policy.md are authoritative.
4. **Vertical playbook lazy-load** uses `plugins/marketing/references/vertical-playbooks/{vertical}.md` (matches what's on disk: `zoos.md`, `aquariums.md`, `casinos.md`, `hotels-resorts.md`, `ski-resorts.md`, `sports-stadiums.md` — 6 files, ~30–60KB each).
5. **Phase numbering 1–7 unified.** Phases 1–5 run for all entities; Phases 6 & 7 marked Labs-only in §3 with explicit applicability notes.

## Issue-vs-ground-truth amendments table

| # | Issue body says | Ground truth | Resolution in this PR |
|---|---|---|---|
| 1 | Tool Surface: `mcp__plugin_marketing_enrichment__*` | Not registered (BC-5537/5538 pending) | Drop from `allowed-tools`; document swap path in §4 |
| 2 | Tool Surface: `mcp__plugin_marketing_github__*` | Not registered for marketing plugin | Drop; use `gh api` via `Bash` |
| 3 | Default `enrichment_provider` = `blitz_prospeo_waterfall` | ADR-008 enum is `blitz_waterfall` | Use `blitz_waterfall` |
| 4 | Vertical ICP files at `{vertical}-icp.md` | Files on disk are `{vertical}.md` | Use `{vertical}.md` |
| 5 | "8 MCPs consciously" (addendum §Guardrails 5) | Marketing plugin has 4 registered (within ~5–6 cap) | Reference current count + cite tam-map-port-policy.md §1 measurement methodology |

---

## Tasks

### T1: Create skill directory and inventory dependencies

**Files:**
- Create `plugins/marketing/skills/tam-mapping/` (mkdir)
- Create `plugins/marketing/skills/tam-mapping/evals/` (mkdir)

**Verification:**
- `ls plugins/marketing/skills/tam-mapping/` → empty dir exists
- Confirm presence of all 9 dependency artifacts (read-only sanity check):
  - `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md`
  - `plugins/marketing/skills/icp-scoring/SKILL.md`
  - `plugins/marketing/references/tam/{UPSTREAM,fit-scoring,icp-definition,segment-routing}.md`
  - `plugins/marketing/references/vertical-playbooks/{zoos,aquariums,casinos,hotels-resorts,ski-resorts,sports-stadiums}.md` (6 files)
  - `plugins/marketing/scripts/tam-map/{aiark_client,discolike_client,icypeas_client,spider_crawl,enrich_waterfall,verify_smtp,tier_and_segment}.py` (7 files)
  - `plugins/marketing/tools/integrations/{ai-ark,blitz-api,discolike,email-bison,icypeas,millionverifier,prospeo,salesforce,spider-cloud}.md` (9 files)
  - `plugins/marketing/.mcp.json` (4 servers: salesforce + spider + aiark + discolike)
  - `docs/decisions/008-tam-mapping-enrichment-pluggability.md`
  - `docs/research/tam-map-port-policy.md`

---

### T2: Write SKILL.md frontmatter

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (NEW)

**Content:**
```yaml
---
name: tam-mapping
description: Build TAM databases from scratch using a 7-phase methodology (Source Discovery → Keyword Expansion → Config → Collection → Dedup → Exclusion → Enrichment hand-off). Triggers "tam map", "build tam", "total addressable market", "scrape industry", "map the market", "build a lead database", "venue partnerships tam", "labs tam", "residential tam", "installer tam". Entity-routed: Nites residential (Google Maps ZIP), Supply installer (SAM.gov + Houzz + state license dbs), Labs venue partnerships (Spider.cloud + AI Ark + Discolike + IcyPeas + BlitzAPI + Prospeo + MillionVerifier). MANDATORY Phase 4.5 cross-workspace EB exclusion. Pluggable Phase 5 enrichment per ADR-008. Distinct from `list-building` (BC-2717 — assumes TAM already exists via dbt audience views).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_spider__*, mcp__plugin_marketing_aiark__*, mcp__plugin_marketing_discolike__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, WebSearch, WebFetch, Read, Write, Glob, Bash
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows + Revgrowth1/tam-map@9f5c72e74b
  category: Outbound Lead Gen
---
```

**Reference checks:**
- `description` field includes `tam-mapping` triggers but does NOT collide with `list-building` triggers (the explicit-distinction sentence helps the matcher disambiguate).
- `allowed-tools` cross-validated against `plugins/marketing/.mcp.json` — every `mcp__plugin_marketing_*` entry maps to a registered server (per CLAUDE.md gotcha line 96).
- `mcp__emailbison-b2b__*` and `mcp__emailbison-personal__*` are user-level registrations, not plugin-level — they pass cross-validation by virtue of the user-level `.mcp.json` documented in `marketing/setup-email-bison`.

**Verification:**
- `head -15 plugins/marketing/skills/tam-mapping/SKILL.md` shows YAML frontmatter wrapped in `---`.
- `python -c "import yaml; yaml.safe_load(open('plugins/marketing/skills/tam-mapping/SKILL.md').read().split('---')[1])"` parses without error.
- Every server in `allowed-tools` appears in either `plugins/marketing/.mcp.json` mcpServers OR is a user-level emailbison registration.

---

### T3: Write H1 + §1 Opener

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**
- `# TAM Mapping`
- One opening paragraph naming the audience (BDR/RevOps/Marketing constructing a TAM from scratch when no `brite-data-platform` dbt audience view exists), the problem (manual scraping → 30-60% market miss + 20-40% wasted enrichment on already-contacted leads), and the one-line outcome (a deduped, exclusion-filtered, optionally enriched/tiered TAM CSV ready for `list-building` or `launch-campaign`).
- Reference-build calibration sentence: "Upstream Revgrowth 02 reference builds — roofing TAM 20K sendable at $15, coffee shop TAM 11K sendable. Use as Nites/Supply calibration anchors."
- Entity-routing one-sentence summary: "Three entity routes — Nites (residential, Google Maps ZIP via WebSearch), Supply (installer, SAM.gov + Houzz + state license dbs), Labs (venue partnerships, full 8-provider stack from upstream `Revgrowth1/tam-map`)."
- Mode hint: "**Distinct from `list-building` (BC-2717):** that skill consumes a TAM. This skill *constructs* one when no dbt audience view exists."

**Verification:**
- Opener is one paragraph + one calibration line + one routing line + one distinction line. No tool names, no MCP servers, no repo paths in §1 (template rule).

---

### T4: Write §2 Before Starting

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

- **`docs/marketing-context.md` check** (boilerplate — copy from icp-scoring §Before Starting). On missing, fall through to a 3-option fallback (exit + run `/marketing:product-marketing-context`; pick entity inline; cancel) — NOT in-session pause-and-resume per `feedback_no_condensed_shortcuts_in_skill_specs.md`.

- **Entity detection** (table form, mirror icp-scoring §Before Starting):
  - `--entity` flag explicit → bypass detection.
  - `marketing-context.md` populated for one entity → use it.
  - `marketing-context.md` populated for multiple → `AskUserQuestion`.

- **Vertical detection** (Labs-only):
  - `--vertical` flag explicit → check if `plugins/marketing/references/vertical-playbooks/{vertical}.md` exists. If yes → lazy-load. If no → treat as custom vertical, prompt for ICP via inline `--criteria-file` or interactive entry.
  - 6 pre-loaded verticals: `zoos`, `aquariums`, `casinos`, `hotels-resorts`, `ski-resorts`, `sports-stadiums`.

- **Source manifest location:** `docs/research/tam/{vertical}-{YYYY-MM-DD}/manifest.json` (Nites/Supply) or `docs/campaigns/labs/tam/{slug}/icp.json` (Labs). Skill writes; user reads.

- **TAMConfig location:** Same dir as manifest. Schema includes `vertical_name`, `keywords`, `naics_codes`, `sources` array, `output_dir`, **`enrichment_provider`** (read from `${user_config.enrichment_provider}` per ADR-008; default `blitz_waterfall`).

- **Enrichment-provider selection** (Labs path):
  - Read from plugin.json `userConfig.enrichment_provider`. Enum: `blitz_waterfall | brite_cli | brite_mcp | skip`.
  - Resolution order at invocation (default behavior): if `brite_mcp` selected and MCP unavailable → emit "pending BC-5537/5538 GA" message + fall through to `blitz_waterfall`. Logged.

- **Resume:** Per Operational rule 2, the skill detects which phase outputs exist on disk and resumes from the next incomplete phase. File-existence check order: `icp.json` → `companies.jsonl` → `crawled.jsonl` → `excluded.jsonl` → `enriched.jsonl` → `verified.jsonl` → `tier-{a,b,c}.csv`. First missing file marks resume point.

**Verification:**
- §2 explicitly cites ADR-008 for enrichment_provider userConfig.
- §2 explicitly enumerates the 6 pre-loaded vertical playbooks by filename.
- §2 documents resume order matching upstream tam-map output convention.

---

### T5: Write §3 Methodology — Phases 1, 1.5, 2

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

`## Methodology` H2 + opening paragraph: "Adapted from Revgrowth1/ai-gtm-workflows workflow 02 (MIT) for the 7-phase scaffolding, workflow 09 (MIT) for Phase 3 Google Maps ZIP scraping, and Revgrowth1/tam-map@`9f5c72e74b` (MIT) for the Labs-path 8-provider stack. Brite departures annotated inline as `# Brite departure: ...`."

#### Phase 1 — Source Discovery
- 16-category source taxonomy (literal list in order): Government/regulatory, Federal contracts (SAM.gov), Industry associations, Manufacturer/vendor directories, Company databases (IcyPeas), Local/maps, Review platforms, Social platforms, Business directories, Awards/rankings, Job boards, Events/conferences, Investor/funding, Open data, Marketplace/aggregator, Academic/research.
- Output: `manifest.json` listing every researched source.
- **Entity routing in this phase:**
  - **Nites/Supply:** Use Revgrowth 02 taxonomy + `plugins/marketing/references/research-processes/` (BC-5823) for source-discovery queries.
  - **Labs:** Adds AI Ark + Discolike + IcyPeas to the taxonomy (their MCPs feed directly into Phase 3 collection).
- **Open-tracking-OFF reminder** emitted in Phase 1 output (verbatim string: `OPEN-TRACKING DISABLED — sender-reputation rule, see Operational rules §guardrails`). Tested by Verify checklist grep.

#### Phase 1.5 — Keyword Expansion
- Discover adjacent keywords sharing the same TAM. Primary keyword alone often misses 30-60% of market.
- **MANDATORY:** Use IcyPeas `free-count` queries before pulling. Counts free, pulls cost credits.
- Cross-keyword dedup happens later in Phase 4; this phase only expands the keyword set.

#### Phase 2 — Config Generation
- Build `TAMConfig` JSON from `manifest.json`. Schema:
  ```jsonc
  {
    "vertical_name": "<string>",
    "entity": "brite-nites | brite-supply | brite-labs",
    "keywords": ["string", "..."],
    "naics_codes": ["6-digit-string", "..."],
    "sources": [{ "name": "...", "type": "...", "config": {...} }],
    "output_dir": "<string>",
    "enrichment_provider": "blitz_waterfall | brite_cli | brite_mcp | skip"  // ADR-008
  }
  ```
- `enrichment_provider` default reads from `${user_config.enrichment_provider}` (ADR-008 §swap-path mechanics). Skill never hardcodes the value.

**Verification:**
- §3 Phase 1 lists all 16 categories in order (grep test).
- §3 Phase 1.5 explicitly says "use IcyPeas free-count queries before pulling".
- §3 Phase 2 TAMConfig schema includes `enrichment_provider` field with the 4-value enum.
- Open-tracking-OFF verbatim string appears in §3 Phase 1.

---

### T6: Write §3 Methodology — Phase 3 Collection (entity-routed)

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

#### Phase 3 — Collection (entity-routed)

Three sub-routes:

1. **Nites residential — Google Maps ZIP scraping** (absorbs Revgrowth workflow 09).
   - WebSearch-based (NOT Serper — cost reason; WebSearch is included in `allowed-tools`).
   - Initial implementation: 100–500 priority ZIPs per campaign (acceptable trade-off vs full 40K-ZIP traversal; split out if needed).
   - Output: `{output_dir}/{source}/businesses.csv` per source.

2. **Supply installer** — SAM.gov federal contracts + Houzz + state license databases.
   - Mix of WebSearch + WebFetch for federated reads.
   - Output: same unified `businesses.csv` schema.

3. **Labs venue partnerships** — full tam-map 4-provider parallel discovery:
   - **Spider.cloud MCP** (`mcp__plugin_marketing_spider__*`) — web crawl + tech-signal extraction (homepage + `/about` + `/contact`). Reference: `plugins/marketing/scripts/tam-map/spider_crawl.py`.
   - **AI Ark MCP** (`mcp__plugin_marketing_aiark__*`) — firmographic company discovery (paginated). Reference: `plugins/marketing/scripts/tam-map/aiark_client.py` + `aiark-mcp.js`.
   - **Discolike MCP** (`mcp__plugin_marketing_discolike__*`) — lookalike expansion (offset pagination, X-Total-Count header). Reference: `plugins/marketing/scripts/tam-map/discolike_client.py` + `discolike-mcp.js`.
   - **IcyPeas via `Bash`** — `python plugins/marketing/scripts/tam-map/icypeas_client.py --icp ./output/{slug}/icp.json`. Keyword-based search (max 100/page).
   - All four run in parallel; merged + deduped by domain.
   - Output: `companies.jsonl` (Labs path), with `crawled.jsonl` overlay from Spider runs.

**Unified `businesses.csv` schema (Nites/Supply path):**
- Columns: `domain`, `company_name`, `address`, `city`, `state`, `zip`, `phone`, `email?`, `industry?`, `employees?`, `source` (which scraper produced this row), `source_url?`. Empty cells allowed; `domain` + `company_name` + `state` are minimum required.

**Labs path JSONL schema:**
- `{ "domain": "...", "company_name": "...", "linkedin_url": "...", "geo": "...", "tech_signals": [...], "source": "...", ... }`. Per-provider columns vary; merger normalizes to common keys.

**Verification:**
- §3 Phase 3 lists all 4 Labs providers with explicit MCP names + script references.
- `businesses.csv` schema is enumerated for Nites/Supply.
- Labs `companies.jsonl` schema is enumerated.

---

### T7: Write §3 Methodology — Phase 4 Dedup + Phase 4.5 Exclusion (MANDATORY)

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

#### Phase 4 — Dedup
- 3-tier algorithm (in order):
  - **Tier 1 — domain match.** Exact match on normalized domain (lowercase, strip `www.`, strip trailing `/`).
  - **Tier 2 — company name + state.** Token-set Jaccard ≥ 0.85 on company name + exact state match. Catches DBA aliases.
  - **Tier 3 — phone match.** Normalized phone (strip non-digits, last 10 digits). Catches franchise locations.
- Output: `all_sources_deduped.csv` + `dedup_stats.json` (tier-by-tier reduction counts).

#### Phase 4.5 — Exclusion (**MANDATORY — never skipped**)

> **HARD-FAIL rule:** if either Email Bison workspace is unreachable (auth failure, network timeout after 3 retries, missing token), the skill HALTS and reports which workspace failed. Does NOT silent-skip and DOES NOT proceed to Phase 5. Reason: Phase 5 enrichment costs real money (BlitzAPI + Prospeo per-record); running it on already-contacted leads wastes credits.

Steps:
1. Query `mcp__emailbison-b2b__list_leads` AND `mcp__emailbison-personal__list_leads` (BOTH workspaces) — bulk pagination.
2. Query Salesforce via `mcp__plugin_marketing_salesforce__run_soql_query` for `SELECT Id, Email, Domain__c FROM Contact WHERE Domain__c IN (...) UNION Lead WHERE Domain__c IN (...)`.
3. Merge into a domain-level exclusion set.
4. Filter `all_sources_deduped.csv` against exclusion set.
5. Output: `net_new_leads.csv` + `exclusion_stats.json` (per-source exclusion counts).

Typical exclusion rate: 20–40% (scoping doc cites 31.7% average).

**Verification:**
- §3 Phase 4 lists all 3 dedup tiers in order.
- §3 Phase 4.5 explicitly says **MANDATORY — never skipped** in bold.
- §3 Phase 4.5 documents the HARD-FAIL rule (both workspaces).
- §3 Phase 4.5 names both `mcp__emailbison-b2b__list_leads` AND `mcp__emailbison-personal__list_leads`.

---

### T8: Write §3 Methodology — Phase 5 Pluggable Enrichment (per ADR-008)

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

#### Phase 5 — Enrichment Hand-off (pluggable)

Pluggable per [ADR-008](../../../../docs/decisions/008-tam-mapping-enrichment-pluggability.md). Selection via `${user_config.enrichment_provider}`:

| `enrichment_provider` | Implementation | Status |
|---|---|---|
| `blitz_waterfall` | Shells to `python plugins/marketing/scripts/tam-map/enrich_waterfall.py --in crawled.jsonl --out enriched.jsonl` (BlitzAPI 5 req/s serialized, Prospeo fallback max 20 workers) | **Default. Production-ready.** |
| `brite_cli` | Shells to `services/enrichment/cli.py` in brite-data-platform | Pending brite-data-platform repo wiring |
| `brite_mcp` | Calls `mcp__plugin_marketing_enrichment__*` (brite-enrichment MCP) | **Pending BC-5537/5538 GA.** Falls through to `blitz_waterfall` with `pending GA` message if invoked before MCP registers. |
| `skip` | No enrichment — pass through unenriched | Opt-in for testing |

Pre-flight (all providers):
1. Email-verification credit check (MillionVerifier balance).
2. Volume-vs-budget cost estimate (BlitzAPI + Prospeo + MillionVerifier per-record × record count).
3. **Cost gate:** emit `estimated enrichment cost: $X.XX for N records (BlitzAPI: $A, Prospeo: $B, MillionVerifier: $C)` BEFORE any enrichment call. Use `AskUserQuestion` if cost > $20 (configurable threshold).
4. API availability — read-only ping to each provider's auth endpoint.

Adaptive email waterfall (within `blitz_waterfall`):
- Sample 100–200 records. Run BlitzAPI → Prospeo waterfall on the sample. Measure hit rate.
- If hit rate < 30%, skill warns and asks user to confirm before committing the full waterfall.

Post-enrichment verification:
- Keep `valid` + `catch_all` flags; drop `unknown`, `error`, `disposable`, `invalid`.
- Output: `enriched.jsonl`.

Entity routing:
- **Nites/Supply:** After Phase 5, hand off to BC-2717 list-building (when further enrichment needed) or directly to launch-campaign. Phase 5 is the final phase for these entities.
- **Labs:** Continue to Phase 6.

**Verification:**
- §3 Phase 5 enumerates all 4 enum values with status notes.
- §3 Phase 5 explicitly cites ADR-008 with relative link.
- §3 Phase 5 documents cost-gate verbatim string `estimated enrichment cost`.
- §3 Phase 5 documents the `pending GA` graceful-degrade message.

---

### T9: Write §3 Methodology — Phases 6 & 7 (Labs-only)

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

#### Phase 6 — SMTP Verify (**Labs only**)

> Nites/Supply paths skip this phase. Downstream consumers (BC-2717 list-building or launch-campaign) handle SMTP verification.

- Tool: MillionVerifier via `python plugins/marketing/scripts/tam-map/verify_smtp.py --in enriched.jsonl --out verified.jsonl`.
- Throughput: 160 req/sec.
- Filter to result codes 1 (`valid`) + 2 (`catch_all`); drop 3–6 (`unknown`, `error`, `disposable`, `invalid`).
- Output: `verified.jsonl` with explicit `catch_all` boolean column.

**Catch-all isolation rule (non-negotiable):** The `catch_all=true` rows are kept in `verified.jsonl` so Phase 7 can route them to a separate output file. They are NEVER mixed into the tier-A/B/C CSVs.

#### Phase 7 — Tier + Segment delegation (**Labs only**)

> Delegates to `icp-scoring` (BC-5831) with `--rubric abc`. tam-mapping does NOT run a classifier itself.

- Invocation: `icp-scoring --rubric abc --max-records <N> --output-dir docs/campaigns/labs/tam/{slug}/ --criteria-file docs/campaigns/labs/tam/{slug}/icp.json` reading from `verified.jsonl`.
- Lazy-loaded ICP for pre-loaded verticals: `plugins/marketing/references/vertical-playbooks/{vertical}.md` (6 files: `zoos`, `aquariums`, `casinos`, `hotels-resorts`, `ski-resorts`, `sports-stadiums`). For custom verticals, the user provides `--criteria-file`.
- Returns: `tier-a.csv`, `tier-b.csv`, `tier-c.csv`, `catch-all.csv`. Per icp-scoring `abc` mode contract — A/B/C only, catch-all separate.

**Operational rule 1 — No free-email providers in B2B output (enforced at Phase 7 boundary).** Before Phase 7 writes tier CSVs, filter rows where the email domain is `gmail.com` / `yahoo.com` / `hotmail.com` / `outlook.com` / `icloud.com`. Route them to `personal-contacts.csv` for manual outreach. NEVER include them in tier-A/B/C CSVs.

**Verification:**
- §3 Phase 6 explicitly says "Labs only".
- §3 Phase 7 explicitly says "delegates to icp-scoring with --rubric abc".
- §3 Phase 7 documents the 5-domain free-email filter list.
- §3 Phase 7 explicitly cites the catch-all isolation rule.

---

### T10: Write §4 Brite Implementation

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

`## Brite Implementation` H2 + tool-mapping table:

| What the skill needs to do | MCP server / tool | Repo or system | Reason (ADR / source) |
|---|---|---|---|
| Phase 3 Nites — scrape Google Maps ZIP | `WebSearch` | Public | Revgrowth 09 + cost (no Serper) |
| Phase 3 Supply — federal contracts | `WebFetch` (SAM.gov) | Public | Revgrowth 02 |
| Phase 3 Labs — web crawl | `mcp__plugin_marketing_spider__*` | Spider.cloud | tam-map upstream + BC-5947 |
| Phase 3 Labs — firmographic discovery | `mcp__plugin_marketing_aiark__*` | AI Ark | tam-map upstream + BC-5947 |
| Phase 3 Labs — lookalike expansion | `mcp__plugin_marketing_discolike__*` | Discolike | tam-map upstream + BC-5947 |
| Phase 3 Labs — keyword search | `Bash` → `icypeas_client.py` | IcyPeas | BC-5946 (script-only, no MCP) |
| Phase 4.5 — workspace 1 exclusion | `mcp__emailbison-b2b__list_leads` | Email Bison b2b | ADR 2a (sole sequencer) |
| Phase 4.5 — workspace 2 exclusion | `mcp__emailbison-personal__list_leads` | Email Bison personal | ADR 2a (sole sequencer) — two-workspace requirement |
| Phase 4.5 — SF exclusion | `mcp__plugin_marketing_salesforce__run_soql_query` | brite-salesforce (production org) | ADR 2a (CRM SoR) |
| Phase 5 — enrichment (default) | `Bash` → `enrich_waterfall.py` | BlitzAPI + Prospeo | ADR-008 default |
| Phase 5 — enrichment (future swap) | `mcp__plugin_marketing_enrichment__*` | brite-enrichment | ADR-008 + BC-5537/5538 (pending) |
| Phase 6 — SMTP verify (Labs) | `Bash` → `verify_smtp.py` | MillionVerifier | tam-map upstream |
| Phase 7 — tier delegation (Labs) | invoke `icp-scoring` skill | n/a (in-plugin delegation) | BC-5831 + tam-map-port-policy.md §4 |
| Cross-repo handbook reads | `Bash` → `gh api repos/Brite-Nites/handbook/contents/...` | Brite-Nites/handbook | `reference_handbook_access.md` (Context7 doesn't resolve private repo) |

`### Architectural rules that apply` — list:
- **MCP-cap exception ratified.** Marketing plugin runs 4 plugin-level MCPs (within ~5–6 advisory). Per BC-5945 §1, measurement methodology applies on each addition. Don't remove MCPs to "fix" perceived capacity issues.
- **Open tracking OFF.** Per upstream tam-map self-check: trackers trash sender reputation. Reminder emitted in Phase 1 output.
- **Phase 4.5 exclusion HARD-FAILS** if either workspace unreachable (see §3 Phase 4.5).
- **Catch-all isolation non-negotiable** (Labs path): catch-all.csv is ALWAYS separate from tier-A/B/C.csv.
- **No free-email providers in B2B output** (Operational rule 1; Labs path).
- **Incremental saves + resume from last completed phase** (Operational rule 2).

`### Cross-skill boundaries`:
- **Owns:** TAM database construction, source discovery, keyword expansion, 3-tier dedup, cross-workspace exclusion, Phase 5 hand-off orchestration, entity-aware routing.
- **Receives from:** User invocation with `--vertical` + `--entity`. Optional `gtm-strategy` output for segment/ICP inputs.
- **Hands off to (entity-specific):**
  - **Nites/Supply** → BC-2717 list-building (when further enrichment needed) or directly to launch-campaign (BC-5826).
  - **Labs** → BC-5831 icp-scoring (Phase 7 delegation, `--rubric abc`) → BC-5826 launch-campaign or BC-2717 list-building.
- **Does not own:** Audience-view design in dbt (brite-data-platform). Per-prospect enrichment beyond waterfall coverage (BC-2727). List-to-campaign config (launch-campaign). ICP scoring itself (delegated to BC-5831).

**Verification:**
- §4 tool table has every MCP entry cross-validated against `.mcp.json` (no unregistered servers).
- §4 documents both EB workspace queries explicitly (HARD-FAIL rationale).
- §4 names ADR-008 + BC-5538 for the future MCP swap path.

---

### T11: Write §5 MCP Tool Reference (grouped by phase)

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

`## MCP Tool Reference` H2. Workflows grouped by phase, NOT by server.

Five workflows:

#### Workflow 1: Phase 3 — Labs collection (parallel discovery)
1. **Availability checks** (in parallel):
   - `mcp__plugin_marketing_spider__*` → call a low-cost tool (e.g., `spider_get_credits`).
   - `mcp__plugin_marketing_aiark__*` → call MCP equivalent of liveness ping.
   - `mcp__plugin_marketing_discolike__*` → call MCP equivalent of liveness ping.
   - `Bash` → `python plugins/marketing/scripts/tam-map/icypeas_client.py --healthcheck`.
2. On any failure, stop and report which provider failed.
3. Run all 4 providers in parallel; merge + dedup by domain.

#### Workflow 2: Phase 4.5 — Cross-workspace + SF exclusion
1. **Availability checks (BOTH MUST PASS — HARD-FAIL):**
   - `mcp__emailbison-b2b__get_active_workspace_info`.
   - `mcp__emailbison-personal__get_active_workspace_info`.
   - `mcp__plugin_marketing_salesforce__run_soql_query` with `SELECT Id FROM User LIMIT 1` (per `salesforce.md` integration guide — `get_username` is NOT a valid liveness check).
2. Bulk pagination via `list_leads` on both workspaces.
3. SF SOQL union query against Contact + Lead.
4. Merge → exclusion domain set → filter `all_sources_deduped.csv`.

#### Workflow 3: Phase 5 — Enrichment (provider-routed via Bash)
1. Read `${user_config.enrichment_provider}` from plugin.json userConfig.
2. Switch on enum:
   - `blitz_waterfall` → `python plugins/marketing/scripts/tam-map/enrich_waterfall.py`.
   - `brite_cli` → `python services/enrichment/cli.py` in brite-data-platform (cross-repo via `gh api` for read-only; for runtime, requires repo clone — flag if not present).
   - `brite_mcp` → `mcp__plugin_marketing_enrichment__*` (currently NOT in `allowed-tools`; falls through to default with `pending GA` message).
   - `skip` → pass through.
3. Cost gate before invocation (see §3 Phase 5).

#### Workflow 4: Phase 6 — SMTP verify (Labs)
1. `python plugins/marketing/scripts/tam-map/verify_smtp.py`.
2. Filter codes 1 + 2.

#### Workflow 5: Phase 7 — Tier delegation (Labs)
1. Invoke `icp-scoring` with `--rubric abc --max-records <N> --output-dir <slug-dir>`.
2. Per icp-scoring §Methodology, the prompt template is read verbatim from `plugins/marketing/references/tam/fit-scoring.md`.

**MCP confirmation gates** noted explicitly:
- Email Bison `import_leads_to_campaign`, `resume_campaign` — gates exist but tam-mapping NEVER calls these (handed off to launch-campaign). Mention only as "out-of-scope".
- IcyPeas free-count vs paid `find-companies` — operationally enforced in script, not MCP-level.

**Verification:**
- §5 has 5 workflows in order.
- Every MCP-tool name used is one that exists in `allowed-tools`.
- Phase 4.5 availability check uses `run_soql_query` with `SELECT Id FROM User LIMIT 1` (not `get_username`).

---

### T12: Write §6 Operational Runbook (4 workflows)

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

`## Operational Runbook` H2. 4 task workflows.

#### Task 1: Brite Nites residential TAM build
- Preconditions: `marketing-context.md` exists with Nites entity populated. Vertical = `residential` (or specific ZIP-bucket like `municipalities`). Output dir = `docs/research/tam/{vertical}-{YYYY-MM-DD}/`.
- Steps (run Phases 1 → 5):
  1. Phase 1 source discovery → `manifest.json`.
  2. Phase 1.5 IcyPeas free-count expansion.
  3. Phase 2 TAMConfig generation.
  4. Phase 3 Google Maps ZIP scraping via WebSearch → per-source `businesses.csv`.
  5. Phase 4 dedup → `all_sources_deduped.csv`.
  6. **Phase 4.5 exclusion (MANDATORY — both workspaces + SF) → `net_new_leads.csv`.**
  7. Phase 5 enrichment via `${user_config.enrichment_provider}` → enriched leads.
  8. Hand off to BC-2717 list-building OR directly to BC-5826 launch-campaign.
- Expected output: `docs/research/tam/{vertical}-{YYYY-MM-DD}/{manifest.json, all_sources_deduped.csv, net_new_leads.csv, dedup_stats.json, exclusion_stats.json, enriched.jsonl?}`.
- Error handling: any MCP availability failure halts. EB workspace unreachable → HARD-FAIL.

#### Task 2: Brite Supply installer TAM build
- Mirrors Task 1 but Phase 3 swaps Google Maps for SAM.gov + Houzz + state license dbs.
- Same Phases 4, 4.5, 5 boilerplate.

#### Task 3: Brite Labs venue partnerships TAM build (full tam-map path, all 7 phases)
- Preconditions: `--vertical` matches one of the 6 pre-loaded playbooks OR user provides `--criteria-file`. Output dir = `docs/campaigns/labs/tam/{slug}/`.
- Steps:
  1. Phase 1 source discovery (Labs taxonomy adds AI Ark + Discolike + IcyPeas).
  2. Phase 1.5 keyword expansion.
  3. Phase 2 TAMConfig generation (writes `icp.json` from playbook).
  4. Phase 3 parallel discovery (Spider + AI Ark + Discolike + IcyPeas) → `companies.jsonl` + `crawled.jsonl`.
  5. Phase 4 dedup.
  6. **Phase 4.5 exclusion (MANDATORY) → `excluded.jsonl`.**
  7. Phase 5 enrichment → `enriched.jsonl` (cost gate before invocation).
  8. Phase 6 SMTP verify → `verified.jsonl`.
  9. **Free-email filter** (Operational rule 1) → `personal-contacts.csv` separated.
  10. Phase 7 tier delegation to icp-scoring `--rubric abc` → `tier-a.csv`, `tier-b.csv`, `tier-c.csv`, `catch-all.csv`, `report.md`.
  11. Hand off to BC-5826 launch-campaign or BC-2717 list-building.
- Expected output: `docs/campaigns/labs/tam/{slug}/{icp.json, companies.jsonl, crawled.jsonl, excluded.jsonl, enriched.jsonl, verified.jsonl, tier-a.csv, tier-b.csv, tier-c.csv, catch-all.csv, personal-contacts.csv, report.md}`.

#### Task 4: Resume an interrupted run
- Preconditions: previous run's output directory exists with partial files.
- Steps:
  1. Skill detects which phase outputs exist on disk (Operational rule 2 file-existence check order).
  2. Resume from first missing file's phase.
  3. NEVER restart from Phase 1.
- Expected output: pipeline continues; no duplicate work.

**Verification:**
- §6 has 4 task workflows.
- Task 3 (Labs) lists all 7 phases plus the Operational rule 1 free-email filter step.
- Task 4 (Resume) explicitly says "NEVER restart from Phase 1".

---

### T13: Write §7 Health Scoring Rubric

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

`## Health Scoring Rubric` H2. 10-point skill-specific rubric.

| Score | Criteria |
|------:|----------|
| 10 | Runs the entity-correct phase route end-to-end. Cites all 16 source categories in Phase 1 manifest. Phase 4.5 exclusion runs against BOTH EB workspaces + SF, HARD-FAILS on missing token. Cost gate fires before Phase 5. Open-tracking-OFF reminder emitted. Catch-all isolation enforced (Labs). Free-email filter applied (Labs). Resume detection works. References ADR-008 for enrichment pluggability. |
| 7-9 | Same as 10 but skips one verification (e.g. forgets Open-tracking reminder, OR skips cost gate, OR runs Phase 4.5 single-workspace). |
| 4-6 | Runs the phases but skips Phase 4.5 entirely OR mixes catch-all into tier CSVs OR uses pattern-based email recovery on single-location businesses. |
| 1-3 | Hallucinates source taxonomy. Calls unregistered MCP servers. Skips IcyPeas free-count and pulls credits blind. Restarts from Phase 1 on resume. Outputs gmail/yahoo addresses in tier CSVs. |

**Verification:**
- §7 is exactly one 4-row table with the 10 / 7-9 / 4-6 / 1-3 bands.
- Top score band names every Brite-specific architectural rule (MANDATORY exclusion, cost gate, open tracking, catch-all isolation, free-email filter, resume).

---

### T14: Write §8 Anti-Slop Guardrails

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

`## Anti-Slop Guardrails` H2. 4 base + 7 skill-specific.

Base 4 (boilerplate):
- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).

Skill-specific 7:
1. **Always run Phase 4.5 exclusion (BOTH EB workspaces + SF).** Never skip — costs real money to enrich already-contacted leads.
2. **Always run IcyPeas free-count before pulling.** Counts free, pulls cost credits.
3. **Always emit unified `businesses.csv` schema from every Phase 3 scraper.** Schema variance breaks Phase 4 dedup.
4. **Always dedup before enrichment.** Never enrich pre-dedup TAM.
5. **Never use pattern-based email recovery (`info@`, `contact@`) on single-location businesses.** Upstream tested 10 patterns × 15,934 domains = 0 hits.
6. **Never mix catch-all rows into tier-A/B/C.csv (Labs path).** Catch-all isolation non-negotiable per user requirement.
7. **Never include free-email-provider rows (`gmail`, `yahoo`, `hotmail`, `outlook`, `icloud`) in tier-A/B/C.csv (Labs path).** Sender reputation rule — see Operational rule 1. Route to `personal-contacts.csv` instead.

**Verification:**
- §8 has 11 bullets total (4 base + 7 skill-specific).
- Bullets 6 and 7 are both present (catch-all + free-email).

---

### T15: Write §9 Behavioral Tests

**File:** `plugins/marketing/skills/tam-mapping/SKILL.md` (append)

**Content shape:**

`## Behavioral Tests` H2. Tier 1 + Tier 2, ≥ 10 scenarios.

#### Tier 1 — Free assertions (5)

1. Given user invokes "build a TAM for Nites residential in the Austin metro", output must walk through all 7 phases (1, 1.5, 2, 3, 4, 4.5, 5) and skip Phases 6 + 7 (Labs-only).
2. Given user invokes "build a Labs zoos TAM", output must walk all 7 phases and explicitly cite the lazy-load `plugins/marketing/references/vertical-playbooks/zoos.md` step.
3. Output must NOT contain free-email domains (`gmail.com`, `yahoo.com`, `hotmail.com`, `outlook.com`, `icloud.com`) in any sample tier-A/B/C row.
4. Given a vertical with no playbook (e.g., "build a Labs TAM for breweries"), output must accept `--criteria-file` or interactive ICP entry as fallback — NOT silently fail.
5. Given resume scenario ("the last run died at Phase 5"), output must detect the resume point from file-existence check and NOT restart from Phase 1.

#### Tier 2 — Tool-assisted (5+)

6. If `docs/marketing-context.md` exists, output must reference Brite entity from that file in the Phase 1 manifest.
7. If `mcp__emailbison-b2b__get_active_workspace_info` returns auth failure, skill HARD-FAILS at Phase 4.5 — does NOT proceed to Phase 5.
8. If `mcp__emailbison-personal__get_active_workspace_info` returns auth failure (with b2b OK), skill STILL HARD-FAILS at Phase 4.5 — both must succeed.
9. If `${user_config.enrichment_provider}` is `brite_mcp` and the MCP is unavailable, output emits "pending BC-5537/5538 GA" message and falls through to `blitz_waterfall`.
10. If `${user_config.enrichment_provider}` is `skip`, Phase 5 short-circuits; downstream Phases 6+7 still run for Labs.
11. Open-tracking-OFF reminder appears as a verbatim string in Phase 1 output (grep test in evals).
12. Cost-estimate string `estimated enrichment cost:` appears in output before any Phase 5 enrichment call (grep test in evals).

**Verification:**
- §9 has ≥ 10 scenarios across Tier 1 + Tier 2.
- Every scenario maps to an `evals/evals.json` entry (T16).

---

### T16: Write `evals/evals.json` (10+ scenarios)

**File:** `plugins/marketing/skills/tam-mapping/evals/evals.json` (NEW)

**Content shape:**
```jsonc
{
  "skill": "tam-mapping",
  "scenarios": [
    {
      "id": "nites-residential-7-phase-walk",
      "input": { "user_message": "Build a TAM for Brite Nites residential in the Austin metro." },
      "assertions": [
        { "type": "contains", "value": "Phase 1" },
        { "type": "contains", "value": "Phase 4.5" },
        { "type": "not_contains", "value": "Phase 6" },
        { "type": "not_contains", "value": "Phase 7" }
      ]
    },
    { "id": "labs-zoos-vertical-playbook-load", "...": "..." },
    { "id": "free-email-filter-applied", "...": "..." },
    { "id": "custom-vertical-fallback", "...": "..." },
    { "id": "resume-from-phase-5", "...": "..." },
    { "id": "marketing-context-reference", "...": "..." },
    { "id": "phase-4.5-hard-fail-b2b", "...": "..." },
    { "id": "phase-4.5-hard-fail-personal", "...": "..." },
    { "id": "brite-mcp-pending-fallback", "...": "..." },
    { "id": "skip-provider-short-circuit", "...": "..." },
    { "id": "open-tracking-off-reminder", "...": "..." },
    { "id": "cost-estimate-emitted", "...": "..." }
  ]
}
```

**Verification:**
- File parses as JSON (`jq . evals/evals.json`).
- Has ≥ 10 scenarios with `id`, `input`, `assertions` fields.
- Every §9 scenario has a matching evals entry.

---

### T17: Plugin metadata — add userConfig + version bump

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json` (the matching `marketing` entry)

**Edit 1 — `plugins/marketing/.claude-plugin/plugin.json`:**
- Add new top-level field `userConfig`:
  ```json
  "userConfig": {
    "enrichment_provider": {
      "type": "string",
      "enum": ["blitz_waterfall", "brite_cli", "brite_mcp", "skip"],
      "default": "blitz_waterfall",
      "description": "Phase 5 enrichment provider for tam-mapping. See ADR-008 (docs/decisions/008-tam-mapping-enrichment-pluggability.md) for swap-path mechanics. blitz_waterfall = BlitzAPI → Prospeo via scripts/tam-map/enrich_waterfall.py (default, production-ready). brite_cli = brite-data-platform services/enrichment/cli.py (pending wiring). brite_mcp = mcp__plugin_marketing_enrichment__* (pending BC-5537/5538 GA — falls through to blitz_waterfall if unavailable). skip = pass through unenriched (testing only)."
    }
  }
  ```
- Bump `"version"` from `"0.3.4"` to `"0.3.5"`.

**Edit 2 — `.claude-plugin/marketplace.json`:**
- Find the `marketing` plugin entry; bump its `version` field to `"0.3.5"`.

**Verification:**
- `jq .userConfig.enrichment_provider plugins/marketing/.claude-plugin/plugin.json` returns the new object.
- `jq .version plugins/marketing/.claude-plugin/plugin.json` returns `"0.3.5"`.
- `jq '.plugins[] | select(.name == "marketing") | .version' .claude-plugin/marketplace.json` returns `"0.3.5"`.
- `./scripts/validate.sh` exits 0 (strict-schema check confirms `userConfig` is allowlisted).

---

### T18: Cross-link backreferences

**Files (read-modify-write):**
- `plugins/marketing/skills/icp-scoring/SKILL.md` — add `tam-mapping` to "Consumed by" section.
- `plugins/marketing/tools/integrations/email-bison.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/salesforce.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/spider-cloud.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/ai-ark.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/discolike.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/icypeas.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/blitz-api.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/prospeo.md` — add tam-mapping to §Consumers.
- `plugins/marketing/tools/integrations/millionverifier.md` — add tam-mapping to §Consumers.

**Strategy:** Open each file. Find `## Consumers` (or `## Consumed by` — match exact heading style of the existing file). Append a new bullet:
- `- **tam-mapping** (BC-5832) — uses {tool} for {phase}. See [SKILL.md](../../skills/tam-mapping/SKILL.md).`

If no `## Consumers` section exists, add one above `## References` or at end of file before any closing markers.

**Verification:**
- `grep -l "tam-mapping" plugins/marketing/tools/integrations/*.md` returns all 9 integration files (excluding `_template.md`).
- `grep "tam-mapping" plugins/marketing/skills/icp-scoring/SKILL.md` returns ≥ 1 hit.

---

### T19: Validation gates

**Commands (in order):**
1. `./scripts/validate.sh` — must exit 0.
2. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — must exit 0.
3. Cross-validation grep:
   - `grep "mcp__plugin_marketing_enrichment\|mcp__plugin_marketing_github" plugins/marketing/skills/tam-mapping/SKILL.md` returns 0 hits in `allowed-tools` line (it WILL appear in §4 swap-path narrative — that's expected; check the frontmatter line specifically).
4. Linear update: if PR created in Step 8, `gh pr view <num>` and `mcp__plugin_workflows_linear-server__save_issue` to update BC-5832 status → In Progress.

**Verification:**
- All 3 commands exit 0.
- No silent-fail tools in frontmatter.

---

## Acceptance criteria mapping

This plan satisfies every checkbox in BC-5832 §Verification:

| Issue checklist item | Task |
|---|---|
| `SKILL.md` exists with required frontmatter | T1 + T2 |
| All 9 sections in required order | T3–T15 |
| `allowed-tools` matches Tool Surface (excluding the 2 unregistered MCPs per amendment row 1+2) | T2 |
| `allowed-tools` cross-validated against `.mcp.json` | T2 + T19 |
| §3 Methodology — all 7 phases | T5–T9 |
| §3 Methodology — 16 source categories | T5 |
| §3 Methodology — 3-tier dedup | T7 |
| §3 Methodology — Phase 4.5 MANDATORY + two-workspace + HARD-FAIL | T7 |
| §3 Methodology — entity-aware Phase 3 routing | T6 |
| §3 Methodology — entity-aware Phase 5 routing | T8 |
| §3 Methodology — Phase 5 enrichment pluggability per ADR-008 | T8 |
| §4 Brite Implementation cites ADRs + entity-specific hand-off paths | T10 |
| §6 Operational Runbook ≥ 4 workflows | T12 |
| §8 Anti-Slop covers all 7 skill-specific rules | T14 |
| §9 Behavioral Tests ≥ 6 scenarios | T15 |
| `evals/evals.json` ≥ 6 scenarios | T16 |
| Output artifact paths documented for both Nites/Supply AND Labs | T9 + T12 |
| Cross-links to BC-2717, BC-5826, BC-5831 + 7 integration guides | T18 |
| Catch-all isolation binary test | T15 + T16 |
| Free-email exclusion binary test | T15 + T16 |
| Incremental-save resume test | T15 + T16 |
| Phase 4.5 hard-fail test | T15 + T16 |
| `enrichment_provider` graceful-degrade test | T15 + T16 |
| Open-tracking-OFF reminder grep test | T15 + T16 |
| Cost estimate emitted before Phase 5 grep test | T15 + T16 |
| `./scripts/validate.sh` exits 0 | T19 |
| `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0 | T19 |

---

## Risks + mitigations

1. **Plan size (19 tasks).** Above the session-start "split if > 12" guideline. Not splittable: shipping a partial 7-phase skill (e.g., Phases 1–4 only) would leave consumers (BC-2717, BC-5826) unable to integrate. Issue body explicitly anticipates ~25 tasks; this plan is consolidated. Mitigation: discrete §-by-§ task scope so any agent can pick up one task in isolation.
2. **plugin.json strict schema.** Adding `userConfig` is allowlisted per CLAUDE.md gotcha line 93. Verify in T17 that validate.sh does NOT silent-fail.
3. **emailbison-b2b vs emailbison-personal availability.** User-level registration; if user hasn't run `marketing/setup-email-bison`, Phase 4.5 HARD-FAILS by design. Document in §6 Task 3 preconditions.
4. **Linear Prosemirror mangling on description edits.** Per `gotcha_linear_markdown_mangling.md` — if BC-5832 description is edited mid-session, verify via `get_issue` after every save. This plan does NOT edit Linear descriptions; only PR body + status.
5. **BC-6000 cache rule.** plugin.json + marketplace.json BOTH bumped in T17 same-commit. Don't defer.

---

## Post-execution

- `/workflows:review` — thorough mode (5 agents) per recent session pattern.
- `/workflows:ship` — captures compound learnings, opens PR, links BC-5832.
- Precedent candidates:
  - **task-1 architecture:** First Brite skill that absorbs an entire upstream pipeline (Revgrowth1/tam-map). Sets template for future "absorb-entire-upstream" ports.
  - **task-2 pattern-choice:** ADR-008 pluggability lets a skill ship before its primary MCP backend exists. Validates the "ship now, swap later" architectural pattern.
  - **task-3 bug-resolution:** Issue-vs-ground-truth amendment table (5 rows) handles forward-looking issue body when reality lags. Reuse pattern from BC-5947 (sibling).
