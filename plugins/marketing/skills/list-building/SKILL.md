---
name: list-building
description: ICP-targeted outbound list assembly. Consumes a TAM source (tam-mapping output, dbt audience CSV, or manual CSV), runs cross-workspace EB exclusion + SF Lead suppression where needed, enriches via the resolved provider, SMTP-verifies, and emits enriched_leads.csv for launch-campaign or campaign-orchestration. Triggers "build list", "list building", "outbound list", "enrich list", "suppress dedup", "ICP list", "decision-maker list", "contact discovery".
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_spider__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, WebSearch, WebFetch, Read, Write, Bash, Glob, Grep
metadata:
  version: 0.1.0
  category: Outbound Lead Gen
---

# List Building

A BDR, RevOps operator, or marketing lead with a TAM in hand has two failure modes: hand-stitch the audience-to-campaign handoff (slow, error-prone, ICP drift) or skip suppression and burn EB workspace reputation on already-contacted leads. This skill is the third option — it consumes any of three TAM sources, runs cross-workspace EB exclusion + SF Lead suppression where the source needs it, enriches to verified contact-level via the resolved enrichment provider, SMTP-verifies, applies the free-email filter, and emits a single `enriched_leads.csv` ready for `launch-campaign` or `campaign-orchestration`.

---

## Before Starting

**Check for product marketing context first.** If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

### Input-source detection

The skill consumes ONE of three input sources per invocation. Detection logic when source-mode flags are not passed: call `AskUserQuestion` listing the 3 source modes with brief descriptions. NEVER silently default.

**Source 1 — tam-mapping output.** Detect by directory pattern: `--input-dir docs/campaigns/labs/tam/<slug>/` (Labs path) or `docs/research/tam/<vertical>-<YYYY-MM-DD>/` (Nites/Supply path). Skill reads the appropriate output file in stable order: `tier-a.csv` → `tier-b.csv` → `tier-c.csv` (Labs) OR `enriched.jsonl` → `net_new_leads.csv` (Nites/Supply). **Skips Workflow 2 (EB-exclusion)** — tam-mapping Phase 4.5 already ran exclusion against both EB workspaces + SF; re-running wastes EB API calls and may misclassify leads if EB state shifted between runs. **Staleness gate:** check the validated `--input-dir`'s mtime via `python3 -c 'import os, sys, time; print(time.time() - os.path.getmtime(sys.argv[1]))' "$INPUT_DIR"` (argv-passed; no shell interpolation — `--input-dir` was already path-validated at Workflow 1 step 0). If age > 7 days, fire `AskUserQuestion` with TWO options: (1) **Skip Workflow 2 (default — preserves the per-source routing rule).** Default action; output proceeds with stale-but-honored upstream exclusion. (2) **Override and re-run Workflow 2.** Explicit user opt-in to re-run cross-workspace EB + SF exclusion against fresh state. Default = (1) so the routing-table contract holds; only an explicit user choice activates the override path documented in § Methodology > Per-source EB-exclusion routing. Never silently skip the staleness check itself.

**Source 2 — dbt audience CSV.** User passes `--audience-csv <path>` + `--audience-view-name <name>`. Skill reads CSV via `Read`. Skill reads the dbt model definition via `Bash` → `gh api repos/Brite-Nites/brite-data-platform/contents/models/marts/<view>.sql` for column-shape reference + audit logging only — does NOT execute the model (no Snowflake MCP exists; the dbt models materialize in Snowflake out-of-band). **Runs Workflow 2 (EB-exclusion)** before enrichment.

**Source 3 — manual CSV.** User passes `--input-csv <path>`. Skill validates required columns (`domain` + `company_name` minimum). **Runs Workflow 2 (EB-exclusion)** before enrichment.

### Invocation flags

| Flag | Default | Notes |
|---|---|---|
| `--input-dir <path>` | (Source 1 mode) | Path to a tam-mapping output directory. Mutually exclusive with `--audience-csv` and `--input-csv`. |
| `--audience-csv <path>` | (Source 2 mode) | Path to a pre-exported dbt audience CSV. Requires `--audience-view-name`. |
| `--audience-view-name <name>` | (required with `--audience-csv`) | dbt model name (e.g., `audience_active_municipalities`). MUST match `^[a-z0-9_]+$` (no slashes, dots, semicolons, query strings) — halt with validation error otherwise; this value flows into a `gh api` URL constructed via Bash interpolation, so unvalidated input is a path-traversal + shell-injection vector. Used to read model definition via `gh api` for column-shape + audit. |
| `--input-csv <path>` | (Source 3 mode) | Path to a user-provided CSV. Required columns: `domain`, `company_name`. Optional columns flow through to enrichment unchanged. |
| `--criteria-file <path>` | (optional) | JSON file with per-vertical ICP override (custom title cascade, max-contacts override, free-text title hints). Schema mirrors tam-mapping's `--criteria-file` for consistency. When absent, the entity-default ICP title cascade in § Methodology applies. |
| `--output-dir <path>` | `docs/research/lists/<entity>-<YYYY-MM-DD>/` (auto-derived) | Path-traversal segments (`..`) and absolute paths outside the worktree root are rejected. |
| `--enrichment-provider <id>` | (read from `${user_config.enrichment_provider}`) | Override per-run. Enum: `blitz_waterfall \| brite_cli \| brite_mcp \| skip` per [ADR-008](../../../../docs/decisions/008-tam-mapping-enrichment-pluggability.md). |
| `--max-contacts-per-company N` | 3 | Per Revgrowth 08 heuristic — beyond 3, marginal contact acquisition cost outweighs list-quality value. |
| `--max-records N` | (unset → cost gate fires) | Cost-gate pre-approval. When set and `N >= record count`, gate is skipped (caller pre-approved cost). When `N < record count`, skill stops and reports overflow — does NOT silently truncate. (Mirrors tam-mapping semantics.) |
| `--sfdx-project-dir <path>` | (auto-detect via `pwd` if it contains `sfdx-project.json`, else error) | Required for SF MCP `directory` parameter. Per `salesforce.md` § Known gotchas → directory parameter trap, calls from `britenites-claude-plugins/` cwd reject without this. |
| `--resume` | (off) | Force resume even when state is ambiguous (e.g., partial JSONL writes — validates the last record line and resumes from the next). Default behavior (no flag) auto-detects from file existence per § Resume detection. |

### Enrichment-provider selection

Read in priority order (per [ADR-008](../../../../docs/decisions/008-tam-mapping-enrichment-pluggability.md) § Unset resolution order):

1. `--enrichment-provider <id>` flag if passed.
2. `${user_config.enrichment_provider}` from plugin.json `userConfig` if explicitly set.
3. **Auto-detect** (when both above are unset):
   1. Check for brite-enrichment CLI at `$BRITE_DATA_PLATFORM/services/enrichment/cli.py` → use `brite_cli`.
   2. Else fall through to `blitz_waterfall`.
4. `skip` is never auto-selected; it must be passed explicitly.

`brite_mcp` is **opt-in only** during the choice-now-default-later interim (BC-6170) — it is **not** auto-selected even when the brite-enrichment MCP is registered. Reach it via the `--enrichment-provider brite_mcp` flag or `${user_config.enrichment_provider}`. It is intentionally **not** in this skill's `allowed-tools` yet — an explicit opt-in that finds `bulk_enrich` absent in-session falls through to `blitz_waterfall`. **Two prerequisites must land together (a config-invariant pair): the BC-5316 redeploy of the published server with `bulk_enrich` AND this skill's `allowed-tools` grant — shipping one without the other leaves the opt-in silently inoperative.** When both land (plus an engine-maturity sign-off), ADR-008's Future Work flip moves `brite_mcp` to the front of this cascade as the default.

The resolved provider is logged at skill invocation so the user sees which path ran (e.g., `[list-building] enrichment_provider=blitz_waterfall (auto-detected; brite-enrichment MCP not registered, $BRITE_DATA_PLATFORM unset)`). The 4-row enum table is the canonical source — see [tam-mapping § 3 Phase 5](../tam-mapping/SKILL.md) for per-value implementation and fallback messages (single source of truth across both skills per ADR-008).

### Resume detection

Per Operational Runbook Task D, if `--output-dir` already exists with partial output, the skill detects the resume point via file existence in this stable order:

0. **First read `<output-dir>/source.json` to determine the active source.** If `source.json` is missing, treat as a fresh run (resume from Workflow 1). The `source` field drives the branching at slot 2 below.
1. `source.json` (Workflow 1 — input source manifest)
2. `suppression_set.json` (Workflow 2 — **only checked when `source.json.source` ∈ {`dbt-view`, `manual-csv`}**; SKIPPED entirely for `tam-output` source per the per-source EB-exclusion routing rule — checking it would force a Workflow 2 re-run that the routing table forbids)
3. `enriched.jsonl` (Workflow 3)
4. `verified.jsonl` (Workflow 4)
5. `enriched_leads.csv` (Workflow 5 — terminal)

The skill NEVER restarts from Workflow 1 when resume state exists. Stop the file-existence loop at the first missing file; do not check subsequent entries. **For `tam-output` source, slot 2 is skipped entirely — the loop checks slots 1 → 3 → 4 → 5.**

---

## Methodology

Adapted from [Revgrowth1/ai-gtm-workflows workflow 08 (MIT)](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/08-contact-discovery) for the contact-discovery 3-step pipeline + max-contacts heuristic, and from [Revgrowth1/ai-gtm-workflows workflow 02 (MIT)](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/02-tam-mapping) for the dual-source suppression pattern.

### ICP framing

An Ideal Customer Profile (ICP) is the firmographic + decision-maker shape of the company most likely to convert. Outbound list assembly fails when the ICP is too loose (waste credits enriching the wrong companies) or too narrow (artificially small TAM, overspend on enrichment that returns 0 hits). The cleanest framing is the **decision-maker title cascade**: T1 (most-senior, smallest pool, highest reply weight), T2 (mid-senior, larger pool, balanced reply weight), T3 (operator-level, largest pool, lowest reply weight). Different verticals invert the cascade — for owner-operator categories (residential service, small contractor) T1 is "Owner" and T2/T3 collapse; for enterprise categories T2 is the largest reply-weighted pool. Cite Revgrowth 08 as canonical shape.

### Contact-discovery 3-step pipeline

The conceptual pipeline matches Revgrowth 08:

**Step 1 — Domain → LinkedIn Company URL.** Given a domain, resolve to canonical LinkedIn company URL. Frequently a no-op when input data already includes the URL (most TAM sources and dbt audience views do).

**Step 2 — Company URL → ICP decision-maker contacts.** Cascade search for prospects matching entity-specific title tiers. Cap at `max-contacts-per-company` (default 3) per Revgrowth 08 heuristic.

**Step 3 — Contact → verified work email.** Waterfall via the resolved enrichment provider, then SMTP-verify the result. Drop unverified records.

### Suppression theory

Two-source suppression catches more than either alone. **Campaign-tool suppression** (the sequencer's lead store — both b2b and personal workspaces in this skill's case) catches "leads we've already touched in any active or recent campaign." **CRM suppression** (the system-of-record's Lead/Contact store) catches "leads tied to existing accounts, opportunities, or sales motions." Either alone leaks: campaign-tool only misses prospects in long-running SF deals; CRM-only misses fresh outbound in flight. Skipping suppression entirely burns sender reputation (replies of "we've talked to your team three times already") and wastes per-record enrichment credits.

### Contact count heuristic

`max-contacts-per-company` defaults to 3 per Revgrowth 08. Beyond 3 contacts per company, marginal contact acquisition cost outweighs list-quality value — the additional contacts are typically lower-tier roles with lower reply weight, while enrichment credits scale linearly with contact count.

### ICP title cascade — entity-specific

Entity-specific title tier defaults for the 3 Brite entities. Use these as priors; override per-vertical via `--criteria-file` or per-invocation prompts.

| Tier | Default | Brite Nites adaptation | Brite Labs adaptation | Brite Supply adaptation |
|---|---|---|---|---|
| T1 | CEO, Founder, Owner, President, Co-Founder | Owner, GM (residential — skip VP cascade) | Venue Director, Events Director | Procurement |
| T2 | VP Marketing, VP Sales, VP Growth, CMO, CRO | (skipped — Owner is the decision-maker) | Marketing Manager | VP Ops, Buyer |
| T3 | Marketing Director, Sales Director, Director of Growth | (skipped) | Catering Director, F&B Director | Buyer |

### Per-source EB-exclusion routing

Whether Workflow 2 (EB-exclusion) runs depends on whether the upstream source already ran it.

| Source | Upstream EB-exclusion? | This skill runs EB-exclusion? |
|---|---|---|
| tam-mapping output (`--input-dir`), input-dir mtime ≤ 7 days | Yes (tam-mapping Phase 4.5) | **No — skip** (default routing rule) |
| tam-mapping output (`--input-dir`), input-dir mtime > 7 days | Yes (tam-mapping Phase 4.5) — but stale | **No by default; user-explicit override path runs Workflow 2** (per Source 1 staleness gate at § Before Starting → Input-source detection) |
| dbt audience CSV (`--audience-csv`) | No | **Yes** |
| Manual CSV (`--input-csv`) | No | **Yes** |

---

## Brite Implementation

### Tools this skill calls

Organized by phase + reason. Every row cites an ADR or a source file.

| What the skill needs to do | MCP server / tool | Repo or system | Reason (ADR / source) |
|---|---|---|---|
| Read tam-mapping output (Source 1) | `Read` + `Glob` | local worktree | tam-mapping `--output-dir` contract |
| Read dbt audience CSV (Source 2) | `Read` | local filesystem | user-provided path |
| Read dbt model definition for audit (Source 2) | `Bash` → `gh api repos/Brite-Nites/brite-data-platform/contents/models/marts/<view>.sql` | brite-data-platform (cross-repo) | ADR 2d (no local clones); `reference_handbook_access.md` pattern |
| Validate manual CSV columns (Source 3) | `Read` | local filesystem | user-provided path |
| EB-exclusion availability check (Sources 2/3) | `mcp__emailbison-b2b__get_active_workspace_info` + `mcp__emailbison-personal__get_active_workspace_info` + `mcp__plugin_marketing_salesforce__run_soql_query` (`SELECT Id FROM User LIMIT 1`) | EB workspaces 55/13 + brite-salesforce prod | ADR 2a (Salesforce CRM SoR; EB sole sequencer); 3-probe parallel batch mirrors tam-mapping § 3 Phase 4.5 |
| EB-exclusion bulk pagination (Sources 2/3) | `mcp__emailbison-b2b__list_leads` + `mcp__emailbison-personal__list_leads` | both EB workspaces | ADR 2a (two-workspace requirement) |
| SF Lead suppression read (Sources 2/3) | `mcp__plugin_marketing_salesforce__run_soql_query` with `SELECT Id, Email, Status FROM Lead WHERE Email IN (:emails) LIMIT 2000` | brite-salesforce prod | `salesforce.md` § Common workflows → Lead suppression read |
| Contact-discovery enrichment (provider-routed) | `Bash` → `plugins/marketing/scripts/bw-run.sh BLITZAPI_KEY=tam-map-blitzapi-key PROSPEO_API_KEY=tam-map-prospeo-api-key -- python plugins/marketing/scripts/tam-map/enrich_waterfall.py` (default) OR `mcp__plugin_marketing_enrichment__bulk_enrich` (opt-in `brite_mcp`; routes the list through the bulk door, pending BC-5316 redeploy) | BlitzAPI + Prospeo (default) OR brite-enrichment bulk door (opt-in) | [ADR-008](../../../../docs/decisions/008-tam-mapping-enrichment-pluggability.md) + ADR-017 enrichment pluggability |
| SMTP verify | `Bash` → `plugins/marketing/scripts/bw-run.sh MILLIONVERIFIER_API_KEY=tam-map-millionverifier-api-key -- python plugins/marketing/scripts/tam-map/verify_smtp.py` | MillionVerifier | Same script as tam-mapping § 3 Phase 6 (single source of truth) |
| Contact-context augmentation (Step 1 fallback when enrichment provider returns no LinkedIn URL) | `mcp__plugin_marketing_spider__*` | Spider.cloud | Crawl homepage + `/about` + `/contact` for an inline LinkedIn link; only invoked when enrichment provider misses Step 1 |

### Architectural rules that apply

- **MCP-cap exception ratified.** Marketing plugin runs 4 plugin-level MCPs today (`salesforce`, `spider`, `aiark`, `discolike`) — within the ~5–6 advisory cap. No new MCPs added by this skill. (CLAUDE.md `MCP_cap_advisory.md` + [`docs/research/tam-map-port-policy.md`](../../../../docs/research/tam-map-port-policy.md) § 1.)
- **EB-exclusion is HARD-FAIL when run** (Sources 2 + 3). If either EB workspace OR SF unreachable, skill HALTS — does NOT silent-skip and does NOT proceed to enrichment. Reason: enrichment costs real money. (Mirrors [tam-mapping § 3 Phase 4.5](../tam-mapping/SKILL.md) HARD-FAIL rule.)
- **EB-exclusion is SKIPPED when source is tam-mapping output** (Source 1). tam-mapping Phase 4.5 already ran exclusion; running it again wastes EB API calls and may misclassify net-new leads as suppressed if EB state shifted between runs. (Per-source EB-exclusion routing table in § Methodology > Per-source EB-exclusion routing.)
- **SF MCP `directory` parameter trap.** Skill MUST pass `directory` pointing at a local `brite-salesforce/` checkout OR the skill MUST assert `pwd` contains an `sfdx-project.json` before calling. Calls from `britenites-claude-plugins/` cwd reject with path-not-found. (`salesforce.md` § Known gotchas → directory parameter trap.)
- **`run_soql_query` `usernameOrAlias` must be the literal username**, not the alias or the `DEFAULT_TARGET_ORG` sentinel. Pass the service user's literal username (Bitwarden Notes field). (`salesforce.md` § Known gotchas; `gotcha_sf_mcp_username_not_alias.md`.)
- **Contact-discovery Step 1 is conditional.** Skip when input row already has `linkedin_url`. Most input sources (tam-mapping output, many dbt audience CSVs) include it; unconditional Step-1 calls waste credits.
- **SMTP-verify pattern matches tam-mapping Phase 6 verbatim.** Use the same `verify_smtp.py` script (single source of truth). Filter result codes 1 + 2 (`catch_all` flagged); drop 3+ (forward-compatible against future MillionVerifier code additions).
- **No free-email providers in B2B output.** Filter `gmail.com`/`yahoo.com`/`hotmail.com`/`outlook.com`/`icloud.com` rows to `personal-contacts.csv` before final `enriched_leads.csv` write. (Same rule as tam-mapping Operational rule 1.)

### Cross-skill boundaries

- **Owns:** Input-source detection (tam-output / dbt-CSV / manual-CSV). Path-flag validation for all 6 path inputs (Workflow 1 step 0). Per-source EB-exclusion routing. Source-aware resume detection (reads `source.json` first; skips slot 2 for tam-output). Source-1 staleness detection (gates re-run via explicit user override). SF Lead suppression. Contact-discovery enrichment orchestration (provider-routed). SMTP verify. Free-email filter. `enriched_leads.csv` emission.
- **Receives from:**
  - `tam-mapping` (BC-5832) — Source 1 directly via `--input-dir <tam-output-dir>`. EB-exclusion ALREADY done; this skill skips it.
  - User invocation — Sources 2/3 with `--audience-csv` + `--audience-view-name` or `--input-csv`.
  - **Indirect upstream:** if a dbt audience CSV (Source 2) is built from a brite-data-platform model that itself ingests prior outbound state, the audit trail still shows dbt → CSV → list-building, not tam-mapping. The two upstream paths do not collide.
- **Hands off to:**
  - `campaign-orchestration` (BC-2718) when sequence design / multi-touch orchestration is needed. Handoff artifact: single `enriched_leads.csv` (schema in § MCP Tool Reference Workflow 5).
  - `launch-campaign` (BC-5826) for direct CSV → EB campaign activation. Same handoff artifact.
  - `icp-scoring` (BC-5831) **optionally** — if ABC tiering is desired, the caller invokes `icp-scoring --rubric abc` on `enriched_leads.csv`. list-building does NOT delegate this itself; ICP scoring is the caller's choice, not list-building's responsibility.
- **Does not own:**
  - TAM construction → `tam-mapping` (BC-5832).
  - ABC tiering / ICP scoring → `icp-scoring` (BC-5831).
  - Sequence design + EB campaign activation → `campaign-orchestration` (BC-2718) + `launch-campaign` (BC-5826).
  - dbt model design + Snowflake materialization → `brite-data-platform`.
  - Enrichment provider implementation → `services/enrichment/cli.py` in brite-data-platform (or the brite-enrichment `bulk_enrich` door → REST `/enrich/batch`, pending BC-5316).

---

## Discoveries — title-discovery signals

This skill's contact-discovery pipeline (Workflow 3, Step 2) routinely surfaces decision-maker titles that are not in the entity's ICP title cascade (§ Methodology → ICP title cascade) — a venue with a "Director of Guest Experience" instead of the expected "Events Director", or a hotel chain that puts the buying decision under "Director of F&B Operations" rather than "Catering Director". These observations are signal: they should flow back into the handbook's title cascades + canonicals so the next campaign in the same vertical/persona stops missing the pattern.

The skill emits these observations as **`title-discovery`** signals to `docs/campaigns/{entity}/{slug}/discoveries.json` so BC-8726 (`/marketing:icp-refinement-review`) and humans can later promote them to `plugins/marketing/data/canonicals/{vertical}.yaml` via PR. See [`plugins/marketing/references/discoveries-promotion.md`](../../references/discoveries-promotion.md) for the full signal → review → handbook PR flow; the schema lives at [`plugins/marketing/data/discoveries-schema.json`](../../data/discoveries-schema.json) and is enforced by `plugins/marketing/scripts/lint_discoveries.py` (wired into `scripts/validate.sh`).

### When to emit

Emit a `title-discovery` signal when ALL three conditions hold for a contact-discovery hit:

1. The returned `contact_title` does NOT appear in the entity's ICP title cascade (default cascade OR the cascade supplied by `--criteria-file`).
2. The contact still ranked highly enough to land in `enriched_leads.csv` (i.e., the title is operationally useful even though it isn't canonical yet — operator already accepted the contact, the title pattern is the value).
3. The pattern recurs at ≥2 distinct companies in the same run (one-off junior-title spelling variants are noise; cross-company repetition is the signal).

Do NOT emit a signal for: simple alias variations the title-normalization layer should catch (`VP of Marketing` ↔ `VP Marketing`); titles inside an already-active canonical alias chain; or single occurrences that read as one-off labelling quirks.

### Confirm gate (one `AskUserQuestion` + one `Write`)

The emit path is operator-confirmed, never automatic. Mirror the gate `campaign-debrief` uses for transferable-insight propagation (§3 Transferable-insight flagging there).

1. **Surface the candidate.** After Workflow 5 emits `enriched_leads.csv`, scan the output for titles meeting the § When to emit conditions. Group by `{vertical}/{persona}` (operator-confirmed at invocation or inferred from `--criteria-file`). For each grouping with ≥2 distinct-company occurrences, fire `AskUserQuestion`:
   > "The run surfaced N contacts with title `{contact_title}` at {company_1}, {company_2}, … under vertical `{vertical}` + persona `{persona}` — this title is not in the canonical cascade. Log a `title-discovery` signal for human review?"
   With options: `Yes, log it` / `No, skip` / `No — title is alias of existing canonical entry (operator notes which)`.
2. **Append the signal on `Yes`.** Read `docs/campaigns/{entity}/{slug}/discoveries.json` (file-not-found branches to a fresh `{schema_version: 1, signals: []}` shape; do NOT use `Glob` first — a single `Read` is cheaper). Append one signal to `signals[]` with this payload shape:

   ```jsonc
   {
     "category": "title-discovery",
     "emitted_at": "<ISO-8601 datetime — Z or +00:00 normalized>",
     "emitted_by_skill": "list-building",
     "payload": {
       "vertical": "<vertical-slug>",
       "persona": "<persona-slug>",
       "candidate_title": "<contact_title-as-returned>",
       "occurrences": <integer ≥2>,
       "example_companies": ["company_1", "company_2"],
       "notes": "<optional operator-supplied note from the AskUserQuestion fallback>"
     },
     "promotion_status": "pending"
   }
   ```

   Write the file back with a single `Write` call. The `payload` keys above are the convention this skill uses; the [`discoveries-schema.json`](../../data/discoveries-schema.json) deliberately holds `payload` open (`type: object`) so downstream `/marketing:icp-refinement-review` (BC-8726) can evolve the shape per category. **No other path is allowed to mutate `discoveries.json`** — neither this skill nor any sibling writes to the file outside the confirmed-emit gate.

3. **On `No, skip` or `No — alias of canonical`**, do NOT write to `discoveries.json`. The operator's alias note (when supplied) should be surfaced to the operator at the end of the run as a reminder to file a handbook-canonicals follow-up if appropriate — list-building does NOT create that PR itself.

### Where this lands

Emitted signals collect in the per-campaign-run `discoveries.json`. Downstream, BC-8726 (`/marketing:icp-refinement-review`) reads all `category: "title-discovery"` signals across runs, presents them as candidates for promotion into `plugins/marketing/data/canonicals/{vertical}.yaml` `personas[].titles[]`, and produces the canonicals PR. The discoveries-promotion reference doc carries the canonical flow.

---

## MCP Tool Reference

Workflows grouped by phase, not by server. Bare semantic tool names; the `allowed-tools` frontmatter establishes the server prefix. See [`plugins/marketing/tools/integrations/`](../../tools/integrations/) for the per-provider integration guides.

### Workflow 1 — Input source detection + read

0. **Validate ALL path-bearing flags before any Bash interpolation.** This step is the canonical enforcement point for the path-validation guarantees asserted in the flag table at § Before Starting → Invocation flags. Apply to every set flag in `{--output-dir, --input-dir, --input-csv, --audience-csv, --criteria-file, --sfdx-project-dir}`:
   - **Determine safe-root.** Try `git rev-parse --show-toplevel`. On non-zero exit (cwd is not a git checkout), fall back to `$PWD`. Treat the resolved value as the prefix that all path flags must stay under.
   - **Resolve to absolute + reject escapes.** Use Python (portable across BSD/GNU `realpath`) — `python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$FLAG_VALUE"` — passing the flag via `argv` (no shell interpolation). For `--output-dir`, use `os.path.realpath` with `strict=False` so the dir need not exist yet; for input flags, the file/dir MUST exist — refuse if missing. If the resolved path contains `..` literal-segments after resolution, OR does not start with the safe-root prefix, HALT with `<flag> validation failed: <resolved-path> escapes safe-root <safe-root>`.
   - **Symlink defense.** When `<output-dir>` already exists (resume mode or repeat run), refuse to write into pre-existing symlink targets — re-resolve every `Write <output-dir>/<filename>` via Python `os.path.realpath` immediately before write and re-prefix-check. A pre-existing symlink under `<output-dir>` pointing outside safe-root is rejected at the per-write check, not just at step 0.
   - **`$BRITE_DATA_PLATFORM` validation** (only when `enrichment_provider` resolves to `brite_cli`, i.e., per § Before Starting → Enrichment-provider selection): require `$BRITE_DATA_PLATFORM` non-empty AND begins with `/` AND matches `^[A-Za-z0-9_/.-]+$`. On validation failure, fall through to `blitz_waterfall` AND log the validation reason (do NOT silently suppress — see Anti-Slop Bash-validation guardrail).
   - **`--criteria-file` content sanitize** (only when set): after path validation, parse the JSON; reject titles containing `$`, backticks, `;`, `|`, `&`, single quotes, double quotes, or newlines. This is the workflow-step binding for the Anti-Slop title-validation rule.

   These checks run in one batch before any source detection. Failure of any check HALTs the skill at this step.
1. **If `--input-dir` set:** Source 1 (tam-mapping output). Use `Glob` to find the canonical output file in stable order — `tier-a.csv` → `tier-b.csv` → `tier-c.csv` (Labs path) OR `enriched.jsonl` → `net_new_leads.csv` (Nites/Supply path). Read with `Read`. Write `<output-dir>/source.json` with `{source: "tam-output", input_dir, files_found}`. **Skip Workflow 2.**
2. **If `--audience-csv` set:** Source 2 (dbt audience CSV). Read CSV via `Read`. Validate `--audience-view-name` matches `^[a-z0-9_]+$` (halt with validation error if not — never string-interpolate unvalidated input into Bash). Read dbt model definition via `Bash` → `gh api repos/Brite-Nites/brite-data-platform/contents/models/marts/<view>.sql` for audit log. **Do NOT suffix `2>/dev/null`** — let stderr flow so `gh` auth failures, 404s, and rate-limits surface; on non-zero exit, HALT with the stderr message rather than silently writing an empty `dbt_model_sha`. Write `<output-dir>/source.json` with `{source: "dbt-view", audience_csv, audience_view_name, dbt_model_sha}`. **Continue to Workflow 2.**
3. **If `--input-csv` set:** Source 3 (manual CSV). Read CSV via `Read`. Validate required columns (`domain`, `company_name`); halt with column-validation message if missing. Write `<output-dir>/source.json` with `{source: "manual-csv", input_csv, columns_present}`. **Continue to Workflow 2.**
4. **If no source-mode flag set:** call `AskUserQuestion` listing the 3 modes; never silently default.

### Workflow 2 — EB-exclusion (Sources 2 + 3 only — SKIP for Source 1)

> **Procedure mirrors [tam-mapping § 3 Phase 4.5](../tam-mapping/SKILL.md). Keep in sync — when one changes, audit the other.**

1. **Availability checks — issue all 3 in ONE assistant turn as a single message containing 3 parallel tool calls. Do not serialize. ALL THREE MUST PASS — HARD-FAIL on any failure:**
   - `mcp__emailbison-b2b__get_active_workspace_info`.
   - `mcp__emailbison-personal__get_active_workspace_info`.
   - `mcp__plugin_marketing_salesforce__run_soql_query` with `SELECT Id FROM User LIMIT 1` (per `salesforce.md` — `get_username` is NOT a valid liveness check).
2. Bulk pagination via `mcp__emailbison-b2b__list_leads` AND `mcp__emailbison-personal__list_leads`. Both workspaces.
3. Salesforce Lead suppression query (per `salesforce.md` § Common workflows → Lead suppression read):
   ```sql
   SELECT Id, Email, Status FROM Lead WHERE Email IN (:emails) LIMIT 2000
   ```
   Bind variable (`:emails`); never string-interpolate (SOQL injection prevention). **Chunking:** SOQL `IN ()` supports up to 4000 bind values per query and the `LIMIT 2000` caps result rows (not the bind list). For input lists where > 1500 emails could plausibly match SF Leads, chunk the input to ≤ 1500 emails per query and union the result sets locally — guards against silent suppression-set truncation when match count exceeds the result-row LIMIT.
4. Merge into a domain-level + email-level exclusion set.
5. Filter input rows against exclusion set. Write `<output-dir>/suppression_set.json` recording which rows were excluded + by which source (`eb_b2b` / `eb_personal` / `sf_lead`):
   ```jsonc
   {
     "input_rows": 4200,
     "eb_b2b_excluded": 850,
     "eb_personal_excluded": 120,
     "sf_lead_excluded": 310,
     "total_excluded": 1280,
     "output_rows": 2920,
     "exclusion_rate_pct": 30.5
   }
   ```

Typical exclusion rate: 20–40% (matches tam-mapping § 3 Phase 4.5 cited average).

### Workflow 3 — Contact-discovery enrichment (provider-routed via Bash)

1. Resolve `enrichment_provider` per § Before Starting → Enrichment-provider selection (priority: `--enrichment-provider` flag → `${user_config.enrichment_provider}` → auto-detect cascade).
2. **Cost gate** before invocation: read MillionVerifier balance; compute `estimated enrichment cost: $X.XX for N records (BlitzAPI: $A, Prospeo: $B, MillionVerifier: $C)`. This verbatim string MUST appear in output before any enrichment call (grep test in evals). Then apply the gate per `--max-records` state (defined in § Before Starting → Invocation flags): if `--max-records` is set and `N >= record_count`, gate is skipped (caller pre-approved); if `--max-records` is set and `N < record_count`, HALT with overflow report (no silent truncation); if `--max-records` is unset and `estimated cost > $20`, fire `AskUserQuestion` confirmation; if `--max-records` is unset and `estimated cost <= $20`, proceed.
3. Switch on `enrichment_provider` enum. The 4-row enum table is the canonical source — see [tam-mapping § 3 Phase 5](../tam-mapping/SKILL.md) for per-value invocation, fallback message, and status. Quick reference:
   - `blitz_waterfall` (default): `Bash` → `plugins/marketing/scripts/bw-run.sh BLITZAPI_KEY=tam-map-blitzapi-key PROSPEO_API_KEY=tam-map-prospeo-api-key -- python plugins/marketing/scripts/tam-map/enrich_waterfall.py --in <input.jsonl> --out enriched.jsonl`. The script accepts only `--in` + `--out` (verify against the script's argparse before invocation). Title-tier filtering and `--max-contacts-per-company` are **skill-layer concerns**: pre-filter the input JSONL to drop non-target titles before invoking the script, and post-filter `enriched.jsonl` to dedup by `domain` keeping the top-N entries by tier rank (T1 > T2 > T3).
   - `brite_cli`: `Bash` → shell to `$BRITE_DATA_PLATFORM/services/enrichment/cli.py` (subcommand and flags TBD per ADR-008 — verify against the actual `cli.py` argparse surface before invocation; falls through to `blitz_waterfall` if `$BRITE_DATA_PLATFORM` unset).
   - `brite_mcp` (opt-in): route the ENTIRE candidate list through the `bulk_enrich` bulk door (→ REST `/enrich/batch`, per [ADR-017](https://github.com/Brite-Nites/brite-data-platform/blob/main/docs/decisions/017-bulk-enrichment-door.md)) — **never** a per-company loop of single `enrich_contacts` calls. If `bulk_enrich` is unavailable in-session (distributed installs until BC-5316 redeploys the plugin server with it), log `brite_mcp selected but bulk_enrich unavailable — using blitz_waterfall (pending BC-5316)` and run `blitz_waterfall`.
   - `skip`: pass-through unenriched (testing only).
4. **Step 1 conditionally** at the skill layer: skip per-record if `linkedin_url` already present in input row. When Step 1 is needed and the enrichment provider misses (returns no LinkedIn URL), fall back to Spider crawl of homepage + `/about` + `/contact` for an inline LinkedIn link.

### Workflow 4 — SMTP verify

1. `Bash` → `plugins/marketing/scripts/bw-run.sh MILLIONVERIFIER_API_KEY=tam-map-millionverifier-api-key -- python plugins/marketing/scripts/tam-map/verify_smtp.py --in enriched.jsonl --out verified.jsonl` (same script tam-mapping Phase 6 uses — single source of truth).
2. Keep result codes 1 + 2 (with `catch_all` flag preserved); drop 3+ (`unknown`, `error`, `disposable`, `invalid`, and any future codes — forward-compatible).

### Workflow 5 — Free-email filter + final emission

1. **Filter free-email rows.** Rows whose email domain is `gmail.com` / `yahoo.com` / `hotmail.com` / `outlook.com` / `icloud.com` → write to `<output-dir>/personal-contacts.csv` for separate manual outreach. NEVER include in `enriched_leads.csv`. (Same rule as tam-mapping Operational rule 1.)
2. **Emit `enriched_leads.csv`.** Reshape remaining `verified.jsonl` rows to `<output-dir>/enriched_leads.csv` with these 16 columns (final handoff schema). The `catch_all` column is **flattened from nested `record.smtp.catch_all`** in `verified.jsonl` (mirrors tam-mapping § 3 Phase 7's JSONL→flat-CSV reshape — the column MUST be top-level + literally named `catch_all` so callers can invoke `icp-scoring --rubric abc` on `enriched_leads.csv` without the contract-break that `missing required column 'catch_all' for --rubric abc` produces). The 3 firmographic columns (`industry`, `employees`, `geography`) are pass-through — list-building does NOT enrich firmographics on its own; they exist to feed icp-scoring's pre-filter optimization (per icp-scoring SKILL.md "expects `industry` + `employees` populated where possible"). **Note on the two icp-scoring upstream feeders.** `enriched_leads.csv` (16 cols, this file) and tam-mapping's `verified-flat.csv` (6 cols — `domain`, `company_name`, `industry`, `employees`, `geography`, `catch_all`) are deliberately different shapes. list-building emits the *fully-enriched* feeder (contact-level columns); tam-mapping emits the *tier-classification-only* feeder. Both satisfy icp-scoring's required column set; downstream consumers needing contact-level fields (e.g., `launch-campaign`'s post-icp-scoring step) MUST consume from `enriched_leads.csv`, not from `verified-flat.csv`. Cross-cite tam-mapping § 3 Phase 7 for the symmetric note on its side.

   | Column | Type | Notes |
   |---|---|---|
   | `domain` | string | normalized lowercase, `www.` stripped |
   | `company_name` | string | from input source |
   | `contact_email` | string | verified, lowercase |
   | `contact_first_name` | string | |
   | `contact_last_name` | string | |
   | `contact_title` | string | actual title returned by provider |
   | `contact_linkedin_url` | string | when available |
   | `industry` | string | optional pass-through from input source or enrichment provider; blank when unavailable; enables icp-scoring `--rubric abc` pre-filter cost optimization |
   | `employees` | integer | optional pass-through; blank when unavailable; same pre-filter optimization |
   | `geography` | string | optional pass-through; blank when unavailable; same pre-filter optimization |
   | `source` | enum | `tam-output` \| `dbt-view` \| `manual-csv` |
   | `source_provenance` | string | tam-mapping output dir, dbt view name, or manual CSV path |
   | `suppression_status` | enum | `eligible` \| `sf_suppressed` \| `eb_b2b_suppressed` \| `eb_personal_suppressed` (ALL rows in `enriched_leads.csv` should be `eligible`; column exists for downstream audit confidence) |
   | `enrichment_provider` | string | resolved provider identifier |
   | `confidence_score` | float | 0.0–1.0 from enrichment provider (per ADR-008 output schema) |
   | `catch_all` | boolean | flattened from `record.smtp.catch_all` in `verified.jsonl` (top-level per icp-scoring `abc` contract) |

3. **Write `<output-dir>/list_stats.json`** with input/output row counts + per-source suppression counts + enrichment-provider used + cost actually spent + any provider failures.

**MCP confirmation gates (out-of-scope reminders):**

- Email Bison `import_leads_to_campaign`, `resume_campaign`, `unsubscribe_lead`, `blacklist_lead`, `archive_campaign`, `enable_warmup`, `remove_email_from_blocklist`, `remove_domain_from_blocklist` — these all have MCP-level confirmation gates per the Email Bison integration guide. **list-building does NOT call these** (handed off to `launch-campaign` / `campaign-orchestration`).

---

## Operational Runbook

### Task A — Build a list from a tam-mapping Labs output (Source 1)

**Preconditions:**

- `docs/marketing-context.md` exists and identifies entity `brite-labs` (or another entity if invoking against Nites/Supply tam-mapping output).
- tam-mapping has run and produced output at `--input-dir`.
- `--input-dir` points at a tam-mapping output directory containing `tier-a.csv` (Labs) or `enriched.jsonl` / `net_new_leads.csv` (Nites/Supply).

**Steps:**

1. Workflow 1 (Source 1 detection + read; **skip Workflow 2**).
2. Workflow 3 (enrichment, provider-routed, cost-gated).
3. Workflow 4 (SMTP verify).
4. Workflow 5 (free-email filter + `enriched_leads.csv` emission).
5. Run § Discoveries title-discovery gate against the emitted `enriched_leads.csv` per § When to emit conditions (≥2 distinct-company occurrences of a non-canonical title). Each operator-confirmed emit appends one signal to `docs/campaigns/{entity}/{slug}/discoveries.json`; on operator decline, no write.

**Expected output dir contents:**

```
<output-dir>/
├── source.json
├── enriched.jsonl
├── verified.jsonl
├── personal-contacts.csv
├── enriched_leads.csv
└── list_stats.json
```

(Zero or more `title-discovery` signals may also be appended to `docs/campaigns/{entity}/{slug}/discoveries.json` per § Discoveries; the file lives outside this output-dir tree per the discoveries-promotion contract.)

**Error handling:**

- Any availability check failure halts.
- Cost > $20 fires `AskUserQuestion`.

**Handoff:** `launch-campaign` (BC-5826) or `campaign-orchestration` (BC-2718). Optional: `icp-scoring --rubric abc` on `enriched_leads.csv` for ABC tiering.

### Task B — Build a list from a dbt audience CSV (Source 2)

**Preconditions:**

- `docs/marketing-context.md` exists.
- User has run dbt model + exported the result to CSV externally.
- `--audience-csv <path>` + `--audience-view-name <name>` provided.

**Steps:**

1. Workflow 1 (Source 2 detection + read CSV + audit-log dbt model via `gh api`).
2. Workflow 2 (EB-exclusion HARD-FAIL guard — both EB workspaces + SF).
3. Workflow 3 (enrichment).
4. Workflow 4 (SMTP verify).
5. Workflow 5 (free-email filter + emission).
6. Run § Discoveries title-discovery gate (same as Task A step 5).

**Expected output dir contents:**

```
<output-dir>/
├── source.json
├── suppression_set.json
├── enriched.jsonl
├── verified.jsonl
├── personal-contacts.csv
├── enriched_leads.csv
└── list_stats.json
```

(Zero or more `title-discovery` signals to `docs/campaigns/{entity}/{slug}/discoveries.json` per § Discoveries — same as Task A.)

**Error handling:** same as Task A + Workflow 2 HARD-FAIL on any unreachable EB workspace or SF.

**Handoff:** same as Task A.

### Task C — Build a list from a manual CSV (Source 3)

**Preconditions:**

- `docs/marketing-context.md` exists.
- `--input-csv <path>` provided.
- CSV has `domain` + `company_name` columns minimum.

**Steps:**

1. Workflow 1 (Source 3 detection + column validation; halt with column-validation message if required columns missing).
2. Workflow 2 (EB-exclusion).
3. Workflow 3 (enrichment).
4. Workflow 4 (SMTP verify).
5. Workflow 5 (free-email filter + emission).
6. Run § Discoveries title-discovery gate (same as Task A step 5).

**Expected output dir contents:** same as Task B.

**Error handling:** same as Task B + halt with column-validation message if `domain` or `company_name` missing.

**Handoff:** same as Task A.

### Task D — Resume an interrupted run

**Preconditions:**

- A previous run's `--output-dir` exists with partial output.

**Steps:**

1. Skill reads `<output-dir>/source.json` first to determine the active source. Then runs the file-existence check in stable order (per § Before Starting → Resume detection), skipping slot 2 (`suppression_set.json`) when `source.source == "tam-output"`.
2. Resume from the first missing file's workflow.
3. **NEVER restart from Workflow 1** when resume state exists.
4. If `--resume` flag is passed, force resume even when state could be ambiguous (e.g., partial JSONL writes — the skill validates the last record line and resumes from the next).

**Expected output:** pipeline continues; no duplicate work; final output dir matches Task A/B/C expectations for the active source.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | Detects input source correctly (auto from flag or via `AskUserQuestion`). Runs/skips Workflow 2 per the source-routing table (skip Source 1, run Sources 2/3). Cost gate fires before Workflow 3 with the verbatim `estimated enrichment cost:` string. Workflow 4 uses the shared `verify_smtp.py` script. Free-email filter applied (rows routed to `personal-contacts.csv`, never in `enriched_leads.csv`). References ADR-008 for enrichment pluggability. Cross-links to BC-5832 / BC-5826 / BC-5831 / BC-2718 are present. SF MCP `directory` param handled (auto-detect or `--sfdx-project-dir`). Resume detection works without restarting from Workflow 1. |
| 7-9 | Functional but skips one verification — e.g. forgets the cost-gate verbatim string, OR skips the free-email filter, OR runs Workflow 2 against only one EB workspace. Output is functional but missing one architectural rule. |
| 4-6 | Runs the workflows but mixes free-email rows into `enriched_leads.csv` OR skips Workflow 2 when source is dbt-CSV/manual-CSV OR uses pattern-based email recovery (`info@`, `contact@`, `hello@`) on single-location businesses OR restarts from Workflow 1 on resume. Functional but violates a core rule. |
| 1-3 | Hallucinates input-source detection. Calls unregistered MCP tools (e.g., `mcp__plugin_marketing_enrichment__bulk_enrich` before it exists on the published server — pending BC-5316 — instead of falling through to `blitz_waterfall`). Skips Workflow 2 cost protection — pulls enrichment credits blind. Outputs `gmail`/`yahoo` addresses in `enriched_leads.csv`. Hard-fails silently. |

---

## Anti-Slop Guardrails

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).
- **Always run Workflow 2 EB-exclusion when source ∈ {dbt-CSV, manual-CSV}.** Never silent-skip. HARD-FAIL on any unreachable EB workspace or SF — costs real money to enrich already-contacted leads.
- **Always SKIP Workflow 2 when source is tam-mapping output (default routing rule).** tam-mapping Phase 4.5 already ran exclusion; re-running wastes EB API calls and may misclassify net-new leads as suppressed if EB state shifted between runs. **Sole exception:** the Source-1 staleness gate (§ Before Starting → Input-source detection) detects an input-dir > 7 days old AND the user explicitly chooses the override option — only then may Workflow 2 run for a tam-output source. Default in that gate is also skip; the override path requires explicit user input via `AskUserQuestion`. Never auto-override.
- **Never use pattern-based email recovery (`info@`, `contact@`, `hello@`) on single-location businesses.** Upstream tested 10 patterns × 15,934 domains = 0 hits. (Same anti-rule as tam-mapping § 3 Phase 5.)
- **Never include free-email-provider rows (`gmail.com`/`yahoo.com`/`hotmail.com`/`outlook.com`/`icloud.com`) in `enriched_leads.csv`.** Route to `personal-contacts.csv`. Sender-reputation rule.
- **Never auto-confirm cost gates.** Per Workflow 3 step 2: when `--max-records` is unset and `estimated cost > $20`, `AskUserQuestion` MUST fire; when `--max-records` is set and `N < record_count`, HALT with overflow report (no silent truncation). Never auto-proceed past either case.
- **Validate inputs before Bash interpolation.** `--audience-view-name` MUST match `^[a-z0-9_]+$` (also enforced at Workflow 1 step 2). Title strings sourced from `--criteria-file` or `marketing-context.md` MUST NOT contain `$`, backticks, `;`, `|`, `&`, single quotes, or newlines — validate at criteria-file load time. `$BRITE_DATA_PLATFORM` MUST resolve to an absolute path before invocation; reject empty or relative values. Never blindly interpolate user-controlled or env-controlled values into Bash command strings.

---

## Behavioral Tests

### Tier 1 — Free assertions

1. Given user invokes "build a list from `docs/campaigns/labs/tam/zoos/` tam-output", output must walk Workflow 1 (Source 1) → Workflow 3 → 4 → 5 and **explicitly skip Workflow 2** with a "tam-mapping Phase 4.5 already ran exclusion" note.
2. Given user invokes "build a list from `audiences/active-municipalities.csv`" without `--audience-view-name`, output must halt with a missing-required-flag message.
3. Output sample `enriched_leads.csv` rows must NOT contain free-email domains.
4. Given a manual CSV missing `domain` column, output must halt with a column-validation message.
5. Given a resume scenario ("the last run died at Workflow 4"), output must detect resume from `enriched.jsonl` existence and NOT restart from Workflow 1.

### Tier 2 — Tool-assisted

6. If `docs/marketing-context.md` exists, output must reference Brite entity from that file when applying the ICP title cascade.
7. If `mcp__emailbison-b2b__get_active_workspace_info` returns auth failure with source ∈ {dbt-CSV, manual-CSV}, skill HARD-FAILS at Workflow 2 — does NOT proceed to Workflow 3.
8. If source is tam-mapping output AND `mcp__emailbison-b2b__get_active_workspace_info` is auth-failed, skill PROCEEDS (Workflow 2 skipped per source routing — exclusion already ran upstream).
9. If `${user_config.enrichment_provider}` is `brite_mcp` and `bulk_enrich` is unavailable in-session, output emits `brite_mcp selected but bulk_enrich unavailable — using blitz_waterfall (pending BC-5316)` and falls through to `blitz_waterfall`.
