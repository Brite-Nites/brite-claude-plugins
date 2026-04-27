---
description: Orchestrate the tam-mapping skill (BC-5832) through 8 phases with explicit two-call confirmation gates between each. Reads ICP arg, resolves entity (default labs), invokes the skill scoped to one phase per gate, surfaces cost estimates before Phase 5 enrichment, and routes to /marketing:launch-campaign or BC-2717 list-building at HANDOFF. Mirrors BC-5826 /marketing:launch-campaign pattern.
argument-hint: <icp-string> [--entity <brite-nites|brite-supply|brite-labs>] [--vertical <slug>] [--criteria-file <path>] [--output-dir <path>] [--enrichment-provider <id>] [--max-records N] [--preview]
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_spider__*, mcp__plugin_marketing_aiark__*, mcp__plugin_marketing_discolike__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, WebSearch, WebFetch, Read, Write, Glob, Grep, Bash, AskUserQuestion
---

# /marketing:tam-map

Execute the 8 phases below sequentially. Use `AskUserQuestion` at every numbered user gate — the user must explicitly approve before you proceed. If they answer anything other than the "proceed" option, halt the phase and help resolve the blocker before re-asking. This command **orchestrates** the BC-5832 `tam-mapping` skill via per-phase invocation; it does not re-implement any skill phase. Each gate sits between two skill invocations scoped via `--stop-at-phase <N>`.

**Inputs:**

- **ICP string** — positional argument. Free-form short phrase (e.g., `"Denver downtown lighting installers 50-200 emp"`). Phase 0 sanitizes; Phase 1 SCOPE feeds it to the skill's manifest pass.
- **Entity** — `--entity <id>`. One of `brite-nites`, `brite-supply`, `brite-labs`. Defaults to auto-detect via `docs/marketing-context.md`; falls through to `brite-labs` when no signal. Routing differs by entity (see §Phase entity routing below).
- **Vertical** — `--vertical <slug>` (optional). Constrains source taxonomy to a specific vertical from `Brite-Nites/handbook@main:marketing/go-to-market/verticals/README.md` (23-vertical taxonomy; 6 Active including Municipalities, HOAs, Landscape Lighting, Landscape Architects, Builders, Universities).
- **Criteria file** — `--criteria-file <path>` (optional). Path to a prior TAMConfig JSON or ICP-criteria YAML. Phase 1 SCOPE reads and feeds verbatim to the skill so the operator does not re-author keyword/geo lists.
- **Output dir** — `--output-dir <path>` (optional). Defaults per skill convention (`docs/campaigns/<entity>/tam/<slug>/`). The skill's file-existence resume mechanism reads from this dir; the command does NOT write a separate progress file.

**Outputs:**

- **Skill artifacts** at `--output-dir` — written progressively by the tam-mapping skill (`manifest.json`, `tam-config.json`, `companies.jsonl` / `businesses.csv`, `crawled.jsonl` Labs only, `all_sources_deduped.csv`, `excluded.jsonl` + `companies-net-new.jsonl` Labs / `net_new_leads.csv` Nites|Supply, `enriched.jsonl`, `verified.jsonl` Labs only, `verified-flat.csv` Labs only, `tier-{a,b,c}.csv` + `catch-all.csv` Labs only). Phase 7 HANDOFF references these by name.
- **Operator-handoff invocation string** — Phase 7 prints (does NOT auto-invoke) the next-command string for `/marketing:launch-campaign` or BC-2717 list-building.

**Precedent + upstream sources:**

- `plugins/marketing/skills/tam-mapping/SKILL.md` — BC-5832, the 7-phase skill being orchestrated. Source of truth for source taxonomy, entity routing, exclusion rules, enrichment provider resolution.
- `plugins/marketing/commands/launch-campaign.md` — <issue id="BC-5826">BC-5826</issue> 11-phase command, the per-phase-gate precedent this command mirrors.
- `docs/precedents/BC-2707.md` — two-call MCP confirmation-gate semantics (turn structure, not vocabulary).
- `plugins/cadence/skills/_shared/gate-respect.md` — <issue id="BC-5866">BC-5866</issue> gate-respect contract; option selected = option executed.
- `docs/decisions/008-tam-mapping-enrichment-pluggability.md` — ADR-008, `enrichment_provider` resolution order (flag → userConfig → auto-detect probe chain).
- [Revgrowth1/tam-map@9f5c72e74b](https://github.com/Revgrowth1/tam-map) (MIT) — upstream `/tam-map` user-facing entry-point shape. Brite-adapts via two-call gate (BC-2707), cost-estimate display (BC-5826), gate-respect contract (BC-5866), 8th HANDOFF phase for Brite downstream routing.

**Ground-truthing rule.** Before every mutating MCP call to a non-core-tier tool in any phase, run `search_api_spec` (Email Bison) or the equivalent tool-discovery primitive to confirm the live tool name and request-body shape. The skill's per-phase invocations themselves carry their own ground-truthing internally; this rule applies only to direct MCP calls this command makes (Phase 0 PRE-FLIGHT MCP probes, Phase 7 HANDOFF if a route fires a verification call). The vendor MCPs are in Beta; tool surface may drift.

---

## Gate-respect

This command renders multi-option `AskUserQuestion` calls at every phase gate (Phase 0 through Phase 7). Per `plugins/cadence/skills/_shared/gate-respect.md` § Application: once the operator picks an option, the command runs exactly that behavior. If, during a phase, the command would deviate to a different option than the one selected, it MUST pause and re-prompt via a new `AskUserQuestion`. Logging to a notes file or a metadata artifact is NOT permission to deviate. Tripwires from gate-respect § Tripwires apply (no "pragmatic condensed pattern", no "context-pressure escape hatch", no "for efficiency I'll batch" in command body). The call-site reminder comment `<!-- gate-respect: honor user pick; re-prompt before any behavior change -->` appears once at the top of every phase that renders a multi-option `AskUserQuestion`.

---

## Phase entity routing

The tam-mapping skill is entity-routed (Nites Phase 3a Google Maps, Supply Phase 3b SAM.gov + Houzz, Labs Phase 3c parallel-provider crawl). This command mirrors that routing with **8 phases for Labs** and **6 phases for Nites/Supply**:

| Phase | Labs | Nites | Supply |
|---|---|---|---|
| 0 PRE-FLIGHT | yes | yes | yes |
| 1 SCOPE | yes | yes | yes |
| 2 DISCOVER | yes (`--stop-at-phase 3-discover`) | yes (`--stop-at-phase 3`) | yes (`--stop-at-phase 3`) |
| 3 CRAWL | yes (`--stop-at-phase 3-crawl`) | **skipped** | **skipped** |
| 4 EXCLUDE | yes (`--stop-at-phase 4.5`) | yes | yes |
| 5 ENRICH | yes (`--stop-at-phase 5 --no-cost-gate`) | yes | yes |
| 6 VERIFY+TIER | yes (`--stop-at-phase 7`) | **skipped** | **skipped** |
| 7 HANDOFF | yes | yes | yes |

Skip notes are repeated inline at the top of Phase 3 CRAWL and Phase 6 VERIFY+TIER. The skip rule is also restated in §Invariants. Document the entity-conditional gate count: Labs maximum is 16 `AskUserQuestion` calls (2 per phase × 8 phases); Nites/Supply minimum is 12 (2 per phase × 6 phases). The grep-test threshold of ≥16 reflects the Labs maximum — the verbatim count adapts per entity at runtime.

---

## Argument parsing and defaults

| Arg / flag | Required | Default | What it does |
|---|---|---|---|
| `<icp-string>` | yes | — | Positional. Free-form short phrase describing the TAM target. Phase 0 IV-4 sanitizes; Phase 1 feeds verbatim to the skill manifest. |
| `--entity <id>` | no | auto-detect | `brite-nites`, `brite-supply`, or `brite-labs`. Auto-detect reads `docs/marketing-context.md` § entity; falls through to `brite-labs` when absent. Brite Supply maps to the Supply skill route (Phase 3b SAM.gov + Houzz; Phase 3 CRAWL + Phase 6 VERIFY+TIER deliberately skipped today — see §Phase entity routing). |
| `--vertical <slug>` | no | — | Constrains source taxonomy to a vertical slug. Pass-through to skill Phase 1. |
| `--criteria-file <path>` | no | — | Path to prior TAMConfig JSON / ICP-criteria YAML. Pass-through to skill Phase 1. **Note:** there is intentionally no `--reference-tam` flag — `--criteria-file` covers safe ICP cloning, and cloning a full `tam-config.json` would pin stale free-count caches (per BC-5950 brainstorm Q4). |
| `--output-dir <path>` | no | `docs/campaigns/<entity>/tam/<slug>/` | Skill output directory. Skill's file-existence resume reads from this; command piggybacks (no separate progress file). |
| `--enrichment-provider <id>` | no | auto-detect | One of `blitz_waterfall`, `brite_cli`, `brite_mcp`, `skip`. Pass-through to skill Phase 5. Resolution order per ADR-008: `--enrichment-provider` flag → `${user_config.enrichment_provider}` → auto-detect probe chain (`brite_mcp` → `brite_cli` → `blitz_waterfall`). |
| `--max-records N` | no | — | Optional cap on per-phase record processing. Pass-through to skill (skill enforces; command surfaces cost-impact in Phase 5). |
| `--preview` | no | off | Full dry-run. Phase 0 + Phase 1 SCOPE only. No collection, no exclusion, no enrichment. Useful for query/manifest validation. |

**Non-goals** (explicit — do NOT do these):

- Do NOT expand TAM scope mid-run. Once Phase 1 SCOPE locks the TAMConfig at gate 2, subsequent phases must consume that scope verbatim. Re-scoping requires aborting and re-running with a new `--criteria-file`.
- Do NOT skip Phase 4 EXCLUDE EB cross-workspace exclusion. The skill HARD-FAILS on either workspace unreachable; the command surfaces that failure clearly and does NOT offer a fallback path. Exclusion before enrichment saves real money ($0.05/record at typical Labs scale).
- Do NOT auto-enable parallel sending in HANDOFF. Phase 7 prints a next-command invocation string; if that command later requires `allow_parallel_sending`, the operator handles it inside that command's gate (per BC-5826 Phase 6).
- Do NOT proceed past the Phase 5 cost gate without explicit `yes`. Re-prompt on anything other than `yes` (single recommended option per gate-respect contract).
- Do NOT auto-chain to `/marketing:launch-campaign`. Phase 7 HANDOFF prints the invocation string for the operator to copy/run. Auto-invocation would defeat the operator-intent contract that separates TAM construction from campaign activation.

---

## Input validation

Run this block before Phase 0. Every input that flows into `Bash`, the skill's `--criteria-file` reader, or any MCP call must pass the checks below. Halt with a clear error on any failure. No operator gate — these are mechanical safety invariants that fail closed.

**IV-1. `--criteria-file` path — reject unsafe characters.** Before any `Bash` invocation that reads or hashes the criteria file, validate the path is composed of `[A-Za-z0-9._/-]` only. Reject anything containing shell-metacharacters, quotes, whitespace, or backslashes. Subsequent Bash calls single-quote the path; this is defense-in-depth against interpolation escape. No auto-sanitization — if the path fails the check, the operator resubmits.

**IV-2. `--criteria-file` and `--output-dir` paths — normalize and confine to repo root.** Resolve each path via `realpath` (or `readlink -f`). The resolved path MUST begin with the output of `git rev-parse --show-toplevel`. This rejects any path that resolves outside the current repository via relative segments. Halt on any resolution mismatch.

**IV-3. Dogfood-path detection.** Match the normalized `--output-dir` from IV-2 against `<repo-root>/.claude/worktrees/<worktree-name>/` followed by any sub-path, where `<worktree-name>` matches `[a-z0-9._-]+`. On match, set the dogfood-mode flag in scratch state and override the metadata write dir to `<repo-root>/.claude/worktrees/<worktree-name>/dogfood/` (gitignored). The skill's artifacts under `--output-dir` are unchanged; only the surrounding command-side metadata (Phase 7 HANDOFF history note) lands in the dogfood path. Detection is structured pattern-matching, not substring. Mirrors BC-5826 IV-3.

**IV-4. ICP-string sanitization.** Before passing the positional ICP string to any `Bash` echo / `WebSearch` query / SOQL interpolation in Phase 0 or Phase 1, validate against regex `^[A-Za-z0-9 .,&/_+\-]+$`. Reject backticks, dollar signs, semicolons, pipes, redirection characters, quotes, parens, newlines. The skill's manifest pass treats the string as a literal phrase; rejecting shell-metacharacters here means downstream Bash `printf "%s" "$ICP"` invocations cannot inject. Halt on regex failure with an actionable message ("ICP string must be alphanumeric + space + `.,&/_+-` only").

**IV-5. `--enrichment-provider` enum validation.** If the flag is set, validate it equals one of `blitz_waterfall`, `brite_cli`, `brite_mcp`, `skip`. Halt on any other value. The 4-value enum is canonical per ADR-008; any drift is a typo or stale doc reference. **Do NOT specify a default at the command layer** — leaving the flag unset triggers the skill's userConfig + auto-detect probe chain per ADR-008's "unset → auto-detect" resolution order. Specifying a default here would silently make the auto-detect path unreachable.

---

## Phase 0 — PRE-FLIGHT

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Purpose.** Validate every input + tool registration before any external state is touched. This phase is read-only — no MCP mutations, no skill invocation. Catch missing API keys, unregistered MCPs, sanitizer failures, and entity/workspace mismatches before the skill spends its first Bash cycle.

**Steps:**

1. **Resolve entity.** If `--entity` is set, use it. Else read `docs/marketing-context.md` and extract the entity declaration (typically under `## Entity` or `entity:` frontmatter); fall through to `brite-labs` if absent. Record the resolved entity + source-of-resolution in scratch state (`entity-source: "flag" | "marketing-context" | "default-labs"`). Mirror the tam-mapping skill's entity-detection logic verbatim — the routing must agree end-to-end.

2. **Verify all 3 plugin MCPs registered + 5 CLI scripts on PATH.** Run:

   ```bash
   claude mcp list 2>&1 | grep -E "spider|aiark|discolike" || echo "NONE_REGISTERED"
   ```

   Interpret per `plugins/marketing/commands/setup-tam-map.md` Phase 1 detect logic:
   - All three lines show `✓ Connected` → continue. (Note: this command is Labs-critical for `spider`/`aiark`/`discolike`. Nites/Supply paths do not depend on these MCPs and may proceed even with `NONE_REGISTERED`, but flag the gap so the operator knows.)
   - `NONE_REGISTERED` AND entity is `brite-labs` → halt with "Run `/marketing:setup-tam-map` first — Labs path requires spider/aiark/discolike MCPs."
   - `NONE_REGISTERED` AND entity is `brite-nites` or `brite-supply` → warn but proceed (Nites uses Google Maps via WebSearch; Supply uses SAM.gov + Houzz via WebFetch).
   - Any line shows `✗ Failed to connect` → halt and surface the failing MCP. Operator runs `/marketing:setup-tam-map` Phase 6 troubleshooting.

   Then verify CLI scripts on PATH (Labs only):

   ```bash
   REPO=$(git rev-parse --show-toplevel) && \
   for script in icypeas_client.py spider_crawl.py enrich_waterfall.py verify_smtp.py tier_and_segment.py; do
     python3 "$REPO/plugins/marketing/scripts/tam-map/${script}" --help >/dev/null 2>&1 \
       && echo "OK: ${script}" \
       || echo "MISSING: ${script}"
   done
   ```

   The 5 scripts here mirror `setup-tam-map.md` Phase 6c verbatim — `enrich_waterfall.py` is the BlitzAPI→Prospeo waterfall (Prospeo is invoked from inside, not a standalone client); `spider_crawl.py` is the Spider.cloud entry point. `--help` doubles as an importability check (catches missing Python deps that `test -x` would miss). Halt with a clear list if any print `MISSING:` — operator runs `/marketing:setup-tam-map` Phase 4.

3. **Cost-aware `--max-records` validation.** If `--max-records` is set AND `< 100`, warn the operator that Phase 1 SCOPE source-discovery typically needs ≥100 records to produce a representative TAM (skill rule per BC-5832 §Behavioral Tests). Render the warning but do NOT halt — the cap applies to per-phase processing, not absolute scope. The operator's gate 1 acknowledges.

4. **Dry-run preview of Phase 1 discovery queries.** Construct (but do NOT invoke) the Phase 1 manifest queries. For Labs path: `WebSearch` queries against `${vertical} venue partnership 2024`, IcyPeas `free-count` queries for the top 5 keyword candidates, AI Ark + Discolike anchor-domain probes. For Nites: `WebSearch` Google-Maps-ZIP queries by metro from the ICP geo signal. For Supply: `WebFetch` SAM.gov + Houzz + state-license-db URL list. Render the enumerated query list to the operator — no API calls fire here.

5. **Workspace cross-mapping flag.** Labs entity normally routes Phase 4.5 EXCLUDE through `emailbison-b2b` AND `emailbison-personal` (skill enforces both — HARD-FAIL on either unreachable). Nites is `emailbison-b2b` only. Supply is `emailbison-b2b` only. The command itself does not pass a `--workspace` flag (the skill auto-routes), but if the operator's terminal `EMAILBISON_*` env mirrors a different default, surface the difference here for acknowledgment. This is the BC-5826 F2 cross-mapping pattern adapted.

6. **Open-tracking-OFF reminder.** Render the verbatim string:

   > `OPEN-TRACKING DISABLED — sender-reputation rule, see plugins/marketing/skills/tam-mapping/SKILL.md §Brite Implementation → Architectural rules`

   This is informational — Phase 5 enrichment + downstream campaign launch must propagate this rule. The skill emits the same string in its Phase 1 manifest output; the command pre-emits it here as a defense-in-depth reminder before any external state is touched.

7. **Write progress hint.** Inform the operator that the skill writes incrementally to `--output-dir` and that the command observes file existence (per skill §Resume detection ladder) to know phase progress. There is intentionally NO command-side progress file — the skill's output dir IS the breadcrumb. Re-running the command after a halt resumes from the next missing artifact.

**User gate 1 (single end-of-Phase-0 gate).** Ask via `AskUserQuestion`:

> Pre-flight complete. Entity: `{entity}` (source: `{entity-source}`). MCPs: {mcp-status}. CLI scripts: {cli-status}. Output dir: `{output-dir}`. Open-tracking-OFF reminder rendered above. Proceed to Phase 1 SCOPE?
>
> - Yes, proceed to Phase 1 SCOPE (Recommended)
> - Re-run pre-flight with adjusted args
> - Abort

**If Phase 0 fails:** the skill has not been invoked. No external state has changed. Fix the missing input (run `/marketing:setup-tam-map`, set the env var, install the script) and re-run from scratch. Phase 0 is fully idempotent — re-running just re-checks the same conditions.

---

## Phase 1 — SCOPE

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Purpose.** Run the skill's Phase 1 (Source Discovery) + Phase 1.5 (Keyword Expansion) + Phase 2 (Config Generation). Produces `manifest.json`, expanded keyword set with IcyPeas free-count rankings, and the locked `tam-config.json` that downstream phases consume verbatim. Read-mostly — IcyPeas free-count queries don't burn credits.

**Steps:**

1. **Build skill invocation.** Construct the tam-mapping skill invocation:

   ```
   tam-mapping --icp "${ICP}" --entity ${ENTITY} \
     ${VERTICAL:+--vertical $VERTICAL} \
     ${CRITERIA_FILE:+--criteria-file $CRITERIA_FILE} \
     --output-dir "${OUTPUT_DIR}" \
     ${MAX_RECORDS:+--max-records $MAX_RECORDS} \
     --stop-at-phase 2
   ```

   `--stop-at-phase 2` halts after `tam-config.json` lands on disk and BEFORE any Phase 3 collection tool fires. Per skill §Resume detection → Interaction with `--stop-at-phase`.

2. **Invoke skill (single call, no two-call gate at the command layer).** The skill itself runs Phase 1 → 1.5 → 2 internally with no operator-gate (read-only / cheap). On exit, it emits:

   > `[tam-mapping] halted at end of Phase 2 per --stop-at-phase`

3. **Read skill outputs.** From `--output-dir`:
   - `manifest.json` — count of source categories, top 5 keywords with their IcyPeas free-counts.
   - `tam-config.json` — locked TAMConfig (vertical, geo, employee bands, target signals, enrichment provider resolution).

4. **Render scope summary to operator.**

   > Phase 1 SCOPE complete.
   >
   > - Manifest: {N} source categories surfaced (Labs: AI Ark + Discolike + IcyPeas + Spider + WebSearch; Nites: Google Maps ZIPs across {M} metros; Supply: SAM.gov + Houzz + {K} state license DBs).
   > - Top 5 keywords (by IcyPeas free-count, descending): {kw1} ({c1}), {kw2} ({c2}), {kw3} ({c3}), {kw4} ({c4}), {kw5} ({c5}).
   > - TAMConfig: vertical=`{vertical}`, geo=`{geo}`, employee bands=`{bands}`, target signals=`{signals}`, enrichment_provider=`{resolved-provider}`.

5. **Spot-check keyword adjacency.** Surface the top-5 keywords + their adjacency to the primary ICP phrase. The operator can re-run Phase 1 with an adjusted seed if any keyword reads off-target.

**User gate 2.** Ask via `AskUserQuestion`:

> Approve TAMConfig above? Locking it here is binding — Phases 2–7 consume `tam-config.json` verbatim and re-scoping requires aborting and re-running with a new `--criteria-file`.
>
> - Yes, approve TAMConfig and proceed to Phase 2 DISCOVER (Recommended)
> - Re-prompt for keyword adjustment — abort + re-run with `--criteria-file <patched>`
> - Abort

**If Phase 1 fails:** the skill halts with a specific error (missing manifest source, IcyPeas auth failure, malformed `--criteria-file`). The skill does NOT write a partial `tam-config.json` — `--stop-at-phase 2` requires Phase 2's output file to exist before halting. Operator fixes the underlying issue and re-runs from scratch (Phase 0 + Phase 1 are both fully idempotent).

---

## Phase 2 — DISCOVER

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Purpose.** Run the skill's Phase 3 collection. Entity-routed: Labs runs Phase 3c parallel discovery (AI Ark + Discolike + IcyPeas + Spider crawl seed); Nites runs Phase 3a Google Maps ZIP scraping; Supply runs Phase 3b SAM.gov + Houzz + state-license-DB pulls. Output is `companies.jsonl` (Labs) or `businesses.csv` (Nites/Supply).

**Entity-conditional skill invocation:**

- **Labs path:** invoke skill with `--stop-at-phase 3-discover`. Halts after Phase 3c parallel discovery merges to `companies.jsonl`, BEFORE Spider crawl. The Spider crawl runs as the separate Phase 3 CRAWL gate (skill sub-step `3-crawl`). Per skill §Resume detection → Interaction with `--stop-at-phase` Labs sub-step values.

- **Nites path:** invoke skill with `--stop-at-phase 3`. Halts after Phase 3a Google Maps ZIP scraping completes and `businesses.csv` lands on disk. Phase 3 CRAWL is Labs-only and skipped entirely.

- **Supply path:** invoke skill with `--stop-at-phase 3`. Halts after Phase 3b SAM.gov + Houzz + state-license-DB pulls complete and `businesses.csv` lands on disk. Phase 3 CRAWL is Labs-only and skipped entirely.

**Steps:**

1. **Construct invocation.** Same flag set as Phase 1 SCOPE, with `--stop-at-phase 3-discover` (Labs) or `--stop-at-phase 3` (Nites/Supply). All other args (`--icp`, `--entity`, `--vertical`, `--criteria-file`, `--output-dir`, `--max-records`) carry through verbatim.

2. **Invoke skill.** Skill runs the entity-correct collection with internal source-level retries. On exit:

   > `[tam-mapping] halted at end of Phase 3-discover per --stop-at-phase` (Labs)
   > `[tam-mapping] halted at end of Phase 3 per --stop-at-phase` (Nites/Supply)

3. **Read skill outputs.** From `--output-dir`:
   - Labs: `companies.jsonl` — merged + per-domain-deduped firmographic records.
   - Nites/Supply: `businesses.csv` — flat row-per-business CSV.

4. **Render discovery summary to operator.**

   > Phase 2 DISCOVER complete.
   >
   > - Total rows: {N} (Labs `companies.jsonl` / Nites|Supply `businesses.csv`).
   > - Top 10 domains (by frequency, descending): {d1}, {d2}, … {d10}.
   > - Source distribution: {source-counts breakdown — e.g., AI Ark 412 / Discolike 287 / IcyPeas 156 for Labs, or per-metro counts for Nites, or per-source-DB counts for Supply}.

5. **Operator inspection cue.** Surface a 5-row sample for the operator to eyeball — catches obvious miscategorization (wrong vertical, wrong geo, off-target firmographic).

**User gate 3.** Ask via `AskUserQuestion`:

> Approve discovered companies above? Next phase is {next-phase-name} ({next-phase-purpose}).
>
> - Yes, proceed to next phase (Recommended)
> - Re-run Phase 2 with adjusted scope — abort + re-run with `--criteria-file <patched>`
> - Abort

Where `{next-phase-name}` = `Phase 3 CRAWL` (Labs) / `Phase 4 EXCLUDE` (Nites/Supply); `{next-phase-purpose}` = `Spider.cloud crawl over discovered company homepages` (Labs) / `cross-workspace EB exclusion + SF dedup` (Nites/Supply).

**If Phase 2 fails:** the skill halts with a specific error (provider auth failure, empty merged result, schema validation drift). Source-level retries already ran 3× internally before the halt. The skill writes whatever did land before the failure as a partial file — operator inspects, decides whether to delete + re-run from Phase 1 or re-run from Phase 2 (skill's resume detection handles either case).

---

## Phase 3 — CRAWL (Labs only)

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Skipped for Nites/Supply.** Phase 3 CRAWL runs Spider.cloud against discovered company homepages — Labs-only today (file Linear follow-up to extend to Supply, see §Change history). Nites/Supply paths jump directly from Phase 2 DISCOVER to Phase 4 EXCLUDE; no skill invocation, no operator gate, no `AskUserQuestion` calls fire for non-Labs entities at this phase.

**Purpose (Labs only).** Run Spider.cloud crawl over `companies.jsonl` from Phase 2. Produces `crawled.jsonl` with extracted tech signals, employee proxies (Wappalyzer-equivalent inference), and homepage-scraped firmographic enrichment. This is the most expensive read-only phase per the upstream tam-map cost model — Spider.cloud charges per page; the per-domain crawl is bounded to homepage + 2 hops.

**Steps:**

1. **Construct invocation (Labs only).** Same flag set as Phase 2 DISCOVER, with `--stop-at-phase 3-crawl`. The skill detects `companies.jsonl` exists from Phase 2's halt and runs Phase 3c Spider crawl over it.

2. **Invoke skill.** Skill runs Spider.cloud with internal rate-limit handling (5 req/s default). On exit:

   > `[tam-mapping] halted at end of Phase 3-crawl per --stop-at-phase`

3. **Read skill outputs.** From `--output-dir`:
   - `crawled.jsonl` — per-company crawled content + extracted signals.

4. **Render crawl summary to operator.**

   > Phase 3 CRAWL complete (Labs).
   >
   > - Crawl success rate: {N-success}/{N-total} ({pct}%).
   > - Sample tech signals (5 random domains):
   >   - `{domain1}` → tech: {signals1}, employee proxy: {proxy1}.
   >   - `{domain2}` → tech: {signals2}, employee proxy: {proxy2}.
   >   - …
   > - Failures: {N-failed} (typically: rate-limit timeouts, robots.txt blocks, 404 homepages).

5. **Operator inspection cue.** Surface the failure breakdown. A success rate <70% suggests Spider.cloud throttling or a stale company-domain set from Phase 2 — operator decides whether to proceed with the partial signal or re-run.

**User gate 4 (Labs only).** Ask via `AskUserQuestion`:

> Approve crawl output above? Next phase is Phase 4 EXCLUDE (cross-workspace EB exclusion + SF dedup; HARD-FAIL on either EB workspace unreachable).
>
> - Yes, proceed to Phase 4 EXCLUDE (Recommended)
> - Re-run Phase 3 CRAWL with adjusted rate-limit / scope
> - Abort

**If Phase 3 fails (Labs):** the skill halts. Partial `crawled.jsonl` may exist with a subset of domains crawled. Operator inspects, decides whether to delete + re-crawl (re-running Phase 3 CRAWL detects the partial file via §Resume detection) or proceed with the partial signal by jumping to Phase 4 (re-run with `--stop-at-phase 4.5` and the skill picks up).

---

## Phase 4 — EXCLUDE

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Purpose.** Run skill's Phase 4 (3-tier dedup) + Phase 4.5 (cross-workspace EB exclusion + SF Contact + Lead union SOQL exclusion). HARD-FAIL on either Email Bison workspace unreachable (skill enforces; command surfaces the failure clearly). This is the **last stop before enrichment spend** — exclusion BEFORE Phase 5 ENRICH saves real money at $0.05/record at typical Labs scale.

**CRITICAL note on HARD-FAIL behavior:** the tam-mapping skill HARD-FAILS on either `emailbison-b2b` or `emailbison-personal` workspace unreachable (auth failure, network timeout after 3 retries, missing token). The skill does NOT silent-skip and does NOT proceed to Phase 5. The command does NOT offer a fallback path — running enrichment on already-contacted leads wastes credits and pollutes downstream campaigns. Operator must resolve the EB auth failure (re-pair workspace token, run `/marketing:setup-email-bison`) and re-run.

**Steps:**

1. **Construct invocation.** Same flag set as prior phases, with `--stop-at-phase 4.5`. Skill detects the prior phase's output file (Labs `crawled.jsonl` / Nites|Supply `businesses.csv`) and runs Phase 4 dedup + Phase 4.5 exclusion.

2. **Invoke skill.** Skill runs:
   - Phase 4 — 3-tier dedup (domain-exact → domain-fuzzy → company-name-fuzzy) over the input file.
   - Phase 4.5 — three-probe availability check (`emailbison-b2b list_leads`, `emailbison-personal list_leads`, `mcp__plugin_marketing_salesforce__run_soql_query`); HARD-FAILS on any probe failure. On success, dual-workspace `list_leads` pagination + SF Contact + Lead union SOQL; merges hits; writes either `excluded.jsonl` + `companies-net-new.jsonl` (Labs) or `net_new_leads.csv` (Nites/Supply); writes `exclusion_stats.json`.

   On exit:

   > `[tam-mapping] halted at end of Phase 4.5 per --stop-at-phase`

3. **Read skill outputs.** From `--output-dir`:
   - `dedup_stats.json` — per-tier dedup match counts.
   - `exclusion_stats.json` — EB-b2b matches, EB-personal matches, SF matches, total excluded, surviving-net-new count.
   - Labs: `excluded.jsonl` + `companies-net-new.jsonl`. Nites/Supply: `net_new_leads.csv`.

4. **Render exclusion summary + cost-savings estimate.**

   > Phase 4 EXCLUDE complete.
   >
   > - Dedup stats: tier 1 (domain-exact) {n1} matches, tier 2 (domain-fuzzy) {n2} matches, tier 3 (company-name-fuzzy) {n3} matches. Total deduped: {N-deduped} → {N-post-dedup} surviving rows.
   > - Exclusion stats: EB-b2b {eb1} matches, EB-personal {eb2} matches, SF Contact+Lead {sf} matches. Total excluded: {N-excluded}.
   > - Surviving net-new: {N-net-new} companies.
   > - **Cost-savings estimate at $0.05/record enrichment:** {N-excluded} × $0.05 = **${cost-savings}** saved by excluding these from Phase 5 ENRICH spend.

5. **Circuit breaker A — discovery=0.** If `all_sources_deduped.csv` (or its Labs equivalent post-dedup row count) has **0 rows**, HALT with diagnostic. Suspect cause: ICP string yielded no manifest sources (Phase 1 failure that propagated silently), or all providers auth-failed and the skill swallowed the error. Render:

   > **Circuit breaker A tripped: discovery=0.** Phase 4 dedup output has 0 surviving rows. Suspect ICP string mismatch or provider auth failure across all sources. Inspect `manifest.json` + per-source logs; do NOT proceed to enrichment (no records to enrich).

   Do NOT advance to user gate 5. The breaker overrides the gate.

6. **Circuit breaker B — EB exclusion=0.** If `exclusion_stats.json` shows **0 matches** across BOTH EB workspaces (eb1 + eb2 = 0), HALT with diagnostic. Suspect cause: EB auth failure that didn't trip the HARD-FAIL probe (typical exclusion rate is 20–40% per skill at any non-trivial TAM scale; 0% is a red flag). Render:

   > **Circuit breaker B tripped: EB exclusion=0.** Both Email Bison workspaces returned 0 matches. Typical exclusion rate is 20–40%. Suspect EB auth failure or stale workspace token. Inspect `exclusion_stats.json`, re-validate workspace keys via `/marketing:setup-email-bison`, do NOT proceed to enrichment.

   Do NOT advance to user gate 5. The breaker overrides the gate.

**User gate 5 (HARD STOP framing).** Ask via `AskUserQuestion`:

> Approve excluded set above? **This is the final stop before enrichment spend** — proceeding will invoke Phase 5 ENRICH, which costs real money at $0.05/record. {N-net-new} companies will be enriched at ~${enrichment-cost-estimate}. Cost-savings already realized by exclusion: ${cost-savings}.
>
> **HARD STOP if you decline.** Re-running with adjusted exclusion criteria requires a manual `--criteria-file` patch.
>
> - Yes, approve and proceed to Phase 5 ENRICH (Recommended)
> - Decline — HARD STOP. Inspect `exclusion_stats.json` and re-run with adjusted criteria
> - Abort

**If Phase 4 fails:** typical failure is EB-workspace HARD-FAIL (skill halts before writing exclusion outputs). Skill emits a clear `[tam-mapping] HARD-FAIL: emailbison-{b2b|personal} workspace unreachable` message. Operator resolves auth, re-runs from Phase 4 (skill's resume detection picks up the prior phase's output and re-runs Phase 4 + Phase 4.5).

---

## Phase 5 — ENRICH

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Purpose.** Run skill's Phase 5 enrichment via the resolved provider (per ADR-008: `--enrichment-provider` flag → `${user_config.enrichment_provider}` → auto-detect probe chain). **Cost-gate-bearing phase** — operator's last say before enrichment spend. The command's gate 6 is the operator-intent surface; the skill is invoked with `--no-cost-gate` to suppress the skill's internal cost-gate (per BC-5950 brainstorm decision: command-side cost gate is authoritative).

**Steps:**

1. **Resolve enrichment provider.** Apply ADR-008 priority order:
   1. `--enrichment-provider` flag (validated by IV-5 to one of `blitz_waterfall`, `brite_cli`, `brite_mcp`, `skip`).
   2. `${user_config.enrichment_provider}` from plugin.json userConfig (no default — unset triggers step 3).
   3. Auto-detect probe chain: `brite_mcp` → `brite_cli` → `blitz_waterfall`. Probe `brite_mcp` (`mcp__plugin_marketing_enrichment__*` registered?), then `brite_cli` (`services/enrichment/cli.py` reachable in `brite-data-platform` repo?), then default to `blitz_waterfall` (always available — production-ready per skill §Phase 5 enum).

   Log the resolution:

   > `[tam-map] enrichment_provider=${RESOLVED} (source: flag | userConfig | auto-detect-probe-{1|2|3})`

2. **Render verbatim cost-estimate string.** Read `companies-net-new.jsonl` (Labs) or `net_new_leads.csv` (Nites/Supply) row count from Phase 4. Compute per-provider unit costs:
   - `blitz_waterfall`: BlitzAPI $0.02/record + Prospeo fallback $0.03/record (typical 60/40 split) + MillionVerifier $0.005/SMTP-verified record (Phase 6, Labs only) → ~$0.05/record blended at Labs scale.
   - `brite_cli`: free at runtime (internal infra) — render `$0.00` but flag the brite-data-platform credit consumption.
   - `brite_mcp`: free at runtime (same as `brite_cli`).
   - `skip`: render `$0.00`, no enrichment runs.

   Emit the verbatim string (grep target — per BC-5832 §Behavioral Tests scenario 12 + this command's verification):

   > `estimated enrichment cost: $X.XX for N records (BlitzAPI: $A, Prospeo: $B, MillionVerifier: $C)`

   Where X.XX = per-record cost × N records, A/B/C = per-provider line items. For `brite_cli`/`brite_mcp`/`skip`, render `$0.00` for all line items but keep the verbatim string format.

3. **Operator-intent surface.** Render the spend summary above the gate:

   > Phase 5 ENRICH spend summary:
   >
   > - Records to enrich: {N-net-new}
   > - Resolved provider: `{RESOLVED}` (source: `{source}`)
   > - Estimated cost: ${X.XX}
   > - Per-provider breakdown: BlitzAPI ${A}, Prospeo ${B}, MillionVerifier ${C}
   > - This is the **command-layer cost gate**. The skill is invoked with `--no-cost-gate` so its internal prompt is suppressed. The verbatim cost-estimate string (above) is still emitted by the skill on invocation per `--no-cost-gate` semantics.

**User gate 6 (single recommended option — `yes` required).** Ask via `AskUserQuestion`:

> Spend ${X.XX} on enriching {N-net-new} records via `{RESOLVED}`? Re-prompt on anything other than `yes`.
>
> - yes — proceed with enrichment spend (single Recommended option)
> - Abort — no enrichment fires; metadata reflects Phase 4 as last completed

If the operator answers anything other than `yes` (including unrelated text, a counter-question, "maybe", silence), HALT and re-prompt. The gate is the structure — single explicit affirmative — not the vocabulary.

4. **Construct skill invocation.** Same flag set as prior phases, with `--stop-at-phase 5 --no-cost-gate`. The `--no-cost-gate` flag suppresses the skill's internal `AskUserQuestion` cost-gate (the verbatim cost-estimate string is still emitted by the skill — grep tests still pass per BC-5832 SKILL.md §Phase 5 step 3 + scenario 14).

5. **Invoke skill.** Skill runs Phase 5 enrichment via the resolved provider. On exit:

   > `[tam-mapping] halted at end of Phase 5 per --stop-at-phase`

6. **Read skill outputs.** From `--output-dir`:
   - `enriched.jsonl` — per-record enrichment results (email, phone, employee count, tech stack).

7. **Render enrichment summary.**

   > Phase 5 ENRICH complete.
   >
   > - Records processed: {N-net-new}
   > - Records successfully enriched: {N-success} ({pct}%)
   > - Records dropped (no email found): {N-drop}
   > - Total spend (actual, from provider invoice): ${actual-spend}

8. **Circuit breaker C — enrichment success rate <10%.** Parse skill's reported success rate from `enriched.jsonl` line count vs input record count. If success rate **<10%**, HALT with diagnostic. Suspect cause: provider API outage, rate-limit cascade failure, malformed input from Phase 4. Render:

   > **Circuit breaker C tripped: enrichment success rate <10%.** Got {pct}% success (typical: 40–70%). Suspect provider API outage. Inspect provider's status page; refund credits per provider's policy (BlitzAPI: contact support; Prospeo: API-side automatic refund per their TOS for batch failures); do NOT proceed to Phase 6 VERIFY+TIER.

   Do NOT advance to user gate (no Phase 5 close-out gate beyond gate 6 — circuit breaker C IS the gate when tripped). Operator decides whether to abort + re-run or accept the partial enrichment and proceed with explicit override (re-run skipping Phase 5 by patching `enriched.jsonl` manually).

**If Phase 5 fails:** the most common case is Circuit breaker C tripping. The skill writes a partial `enriched.jsonl` reflecting whatever did succeed before the failure. Operator can either delete the partial file and re-run (skill picks up at Phase 5) or splice it manually for the records that did enrich.

---

## Phase 6 — VERIFY+TIER (Labs only)

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Skipped for Nites/Supply.** Phase 6 VERIFY+TIER is Labs-only today (downstream consumers BC-2717 list-building / BC-5826 launch-campaign handle SMTP verify for Nites/Supply on their own schedule). File Linear follow-up to extend to Supply (per BC-5950 brainstorm Q6). Nites/Supply paths jump directly from Phase 5 ENRICH to Phase 7 HANDOFF; no skill invocation, no operator gate, no `AskUserQuestion` calls fire for non-Labs entities at this phase.

**Purpose (Labs only).** Run skill's Phase 6 (MillionVerifier SMTP verify with catch-all isolation) + Phase 7 (icp-scoring `--rubric abc` tier delegation). Phase 7 produces `verified-flat.csv` (the JSONL→CSV reshape per icp-scoring's `abc` delegation contract — caller owns flatten of `smtp.catch_all` to top-level `catch_all`), then `tier-{a,b,c}.csv` + `catch-all.csv`. Free-email rows (gmail/yahoo/hotmail/outlook/icloud) are routed to `personal-contacts.csv` and excluded from `verified-flat.csv` (Operational rule 1 per skill §Architectural rules).

**Steps:**

1. **Construct invocation (Labs only).** Same flag set as prior phases, with `--stop-at-phase 7`. Skill runs Phase 6 SMTP verify + Phase 7 icp-scoring delegation.

2. **Invoke skill.** Skill runs:
   - Phase 6 — `Bash` → `python plugins/marketing/scripts/tam-map/verify_smtp.py --in enriched.jsonl --out verified.jsonl`. Catch-all isolation: code 2 rows kept with `catch_all=true` flag.
   - Phase 7 — JSONL→CSV reshape (`verified-flat.csv` with top-level `catch_all` column, free-email rows routed to `personal-contacts.csv`); then delegation to icp-scoring skill via `--rubric abc`.

   On exit:

   > `[tam-mapping] halted at end of Phase 7 per --stop-at-phase`

3. **Read skill outputs.** From `--output-dir`:
   - `verified.jsonl` — SMTP-verified records with `catch_all` boolean.
   - `verified-flat.csv` — flat CSV input to icp-scoring.
   - `tier-a.csv`, `tier-b.csv`, `tier-c.csv` — strong/medium/weak fit prospects.
   - `catch-all.csv` — `catch_all=true` rows scored separately (per icp-scoring abc mode).
   - `personal-contacts.csv` — free-email rows (Labs-only routing).
   - `report.md` — skill's Phase 7 summary.

4. **Render tier summary.**

   > Phase 6 VERIFY+TIER complete (Labs).
   >
   > - SMTP verify: {N-verified} valid / {N-catch-all} catch-all / {N-invalid} dropped (input was {N-input}).
   > - Free-email routed: {N-personal} rows → `personal-contacts.csv` (excluded from tier scoring).
   > - Tier breakdown:
   >   - `tier-a.csv` — {a-count} strong-fit
   >   - `tier-b.csv` — {b-count} medium-fit
   >   - `tier-c.csv` — {c-count} weak-fit
   >   - `catch-all.csv` — {ca-count} catch-all (scored separately)
   > - Report: see `{output-dir}/report.md` for narrative summary.

**User gate 7 (Labs only).** Ask via `AskUserQuestion`:

> Approve tier output above? Phase 7 HANDOFF will route to a downstream command based on entity.
>
> - Yes, proceed to Phase 7 HANDOFF (Recommended)
> - Re-run Phase 6 with adjusted scoring rubric — abort + re-run with patched icp-scoring rubric
> - Abort

**If Phase 6 fails (Labs):** typical failure is MillionVerifier rate-limit or icp-scoring rubric drift. Partial `verified.jsonl` may exist. Operator inspects, decides whether to delete + re-run or splice + proceed.

---

## Phase 7 — HANDOFF

<!-- gate-respect: honor user pick; re-prompt before any behavior change -->

**Purpose.** Final phase. Routes operator to the next command based on entity. **Does NOT auto-chain** — prints the next-command invocation string for the operator to copy/run. Auto-invocation would defeat the operator-intent contract that separates TAM construction from campaign activation (per BC-5950 brainstorm decision).

**Entity-conditional 3-option menu.** Phase 7 always renders exactly 3 options via `AskUserQuestion`. Option content varies by entity:

### Labs path

The output of Phase 6 is `tier-a.csv` (+ `tier-b.csv`, `tier-c.csv`, `catch-all.csv`). The default downstream command is `/marketing:launch-campaign` against `tier-a.csv` (highest-fit cohort first; tier-b/tier-c become later cohorts).

**User gate 8 (Labs).** Ask via `AskUserQuestion`:

> Phase 6 VERIFY+TIER complete. {a-count} tier-A leads ready. Where do you want to go next?
>
> - Upload `tier-a.csv` to `/marketing:launch-campaign` — print the invocation string below for copy/run
> - Send to BC-2717 list-building — for further audience-view-style enrichment via dbt (if a `brite-data-platform` view exists for this vertical)
> - Stop here — print final output dir tree + summary; no downstream invocation

**On Option 1 (Labs):** print verbatim:

```
/marketing:launch-campaign \
  --csv {output-dir}/tier-a.csv \
  --workspace emailbison-b2b \
  --copy-artifact <path-to-bc5825-copy-artifact> \
  --campaign-name "{slug}-tier-a" \
  --entity brite-labs
```

Operator copies, replaces `<path-to-bc5825-copy-artifact>` with the actual copy artifact path, and runs in a fresh prompt. Refer them to `plugins/marketing/commands/launch-campaign.md` § Argument parsing for the full flag list.

**On Option 2 (Labs):** print:

> Send to BC-2717 list-building. Path: invoke the `list-building` skill with `--audience-view-name <vertical-slug>` (assumes a `brite-data-platform` dbt view exists for this vertical). See `plugins/marketing/skills/list-building/SKILL.md` for the full audience-view contract.

**On Option 3 (Labs):** print final output dir tree:

```
{output-dir}/
├── manifest.json
├── tam-config.json
├── companies.jsonl
├── crawled.jsonl
├── all_sources_deduped.csv
├── excluded.jsonl
├── companies-net-new.jsonl
├── enriched.jsonl
├── verified.jsonl
├── verified-flat.csv
├── tier-a.csv ({a-count} rows)
├── tier-b.csv ({b-count} rows)
├── tier-c.csv ({c-count} rows)
├── catch-all.csv ({ca-count} rows)
├── personal-contacts.csv ({pc-count} rows)
├── exclusion_stats.json
├── dedup_stats.json
└── report.md
```

Plus a 3-line summary of total spend, total surviving rows, and tier-A count.

### Nites path

The output of Phase 5 is `enriched.jsonl`. Nites does NOT have a tier-A/B/C split (Phase 6 is Labs-only). Downstream `/marketing:launch-campaign` requires CSV input — operator runs a JSONL→CSV reshape inline. There is no dedicated reshape primitive script today (`tier_and_segment.py` is the LLM-scoring step used in Labs Phase 7 — its required args are `--in / --icp / --out-dir`, it needs `ANTHROPIC_API_KEY`, and it filters on `record.smtp.keep` which Nites's enriched.jsonl never populates because Phase 6 SMTP verify is Labs-only). The reshape printed below is a stdlib `python -c` one-liner that works against any `enriched.jsonl` shape without external dependencies.

**User gate 8 (Nites).** Ask via `AskUserQuestion`:

> Phase 5 ENRICH complete. {N-success} enriched leads ready. Where do you want to go next?
>
> - Reshape `enriched.jsonl` → CSV and pass to `/marketing:launch-campaign` — print reshape one-liner + invocation string below
> - Send to BC-2717 list-building — for audience-view-style routing
> - Stop here — print final output dir tree + summary

**On Option 1 (Nites):** print verbatim:

```bash
# JSONL → CSV reshape (Nites — no tier split, no external deps)
python3 -c '
import json, csv, sys
in_path = "{output-dir}/enriched.jsonl"
out_path = "{output-dir}/leads.csv"
rows = [json.loads(line) for line in open(in_path) if line.strip()]
if not rows:
    sys.exit("no enriched rows; aborting")
fields = ["email", "first_name", "last_name", "company_name", "company_domain", "job_title"]
with open(out_path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
print(f"wrote {len(rows)} rows to {out_path}")
'
```

```
# Then invoke launch-campaign
/marketing:launch-campaign \
  --csv {output-dir}/leads.csv \
  --workspace emailbison-b2b \
  --copy-artifact <path-to-bc5825-copy-artifact> \
  --campaign-name "{slug}" \
  --entity brite-nites
```

The reshape one-liner pulls the canonical `email + first_name + last_name + company_name + company_domain + job_title` columns required by `/marketing:launch-campaign` Phase 1 step 1 CSV schema validation. Adapt the `fields` list if the enrichment provider produced a different shape — the JSONL→CSV transform stays the same.

**On Option 2 (Nites):** same as Labs Option 2 with vertical-slug context.

**On Option 3 (Nites):** print output dir tree (no `crawled.jsonl`, no `verified.jsonl`, no `tier-*.csv`, no `catch-all.csv`, no `personal-contacts.csv` — Nites path is shorter).

### Supply path

Mirrors the Nites path on every option — same 3-option menu, same JSONL→CSV reshape one-liner shape, same `/marketing:launch-campaign` invocation with `--entity brite-supply`. The `--workspace` defaults to `emailbison-b2b` (Supply does not run on `emailbison-personal`).

### General

After printing the invocation string (or output tree), the command exits. No further state mutation. The metadata trail lives entirely in `--output-dir` (skill artifacts) — there is no command-side state file to clean up.

---

## Invariants

The following invariants are load-bearing. Violations are hard failures; the command MUST halt rather than ship a violation.

1. **Two-call confirmation gate between every phase (per <issue id="BC-2707">BC-2707</issue>).** Each phase's mutating gate uses the BC-2707 turn-structure pattern: command-side operator-intent gate via `AskUserQuestion` BEFORE invoking the skill for that phase. The skill's internal phases that invoke EB MCPs already have their own two-call gates within the skill itself; this command's gates sit at the per-phase boundary, not the per-MCP-tool boundary. Anti-pattern blocked: the command issuing two skill invocations across one phase boundary in the same turn without an `AskUserQuestion` between them.

2. **OPEN-TRACKING DISABLED reminder emitted in Phase 0 PRE-FLIGHT.** Verbatim string `OPEN-TRACKING DISABLED — sender-reputation rule, see plugins/marketing/skills/tam-mapping/SKILL.md §Brite Implementation → Architectural rules`. The skill emits the same string in its Phase 1 manifest output as defense-in-depth; both surfaces are non-negotiable.

3. **Cost estimate shown before Phase 5 ENRICH (grep target: `estimated enrichment cost`).** Verbatim string `estimated enrichment cost: $X.XX for N records (BlitzAPI: $A, Prospeo: $B, MillionVerifier: $C)`. Rendered before the operator-intent gate (gate 6). The skill is invoked with `--no-cost-gate` to suppress the skill's internal prompt; the cost-estimate verbatim string is still emitted by the skill per `--no-cost-gate` semantics.

4. **3 circuit breakers — A discovery=0, B EB-exclusion=0, C enrichment success rate <10%.** Each breaker HALTs the phase before its operator gate; the breaker overrides the gate. Diagnostic message format is fixed (per the verbatim renders in Phase 4 + Phase 5 above). No circuit breaker is silently catchable — re-running requires the operator to inspect the diagnostic and adjust inputs.

5. **File location:** `plugins/marketing/commands/tam-map.md`. The skill it orchestrates is `plugins/marketing/skills/tam-mapping/SKILL.md`. The userConfig key consumed for enrichment provider resolution is `enrichment_provider` per ADR-008 (no command-layer default).

6. **Gate-respect contract per <issue id="BC-5866">BC-5866</issue>: option selected = option executed.** Once the operator picks an option at any of the 8 user gates, the command runs exactly that behavior. Mid-execution deviation requires a new `AskUserQuestion`. Logging to a notes file or skill output dir is NOT permission to deviate. The call-site reminder comment appears at the top of every phase that renders an `AskUserQuestion`. Tripwires from gate-respect § Tripwires apply.

7. **Entity-conditional gate count.** Labs maximum is 16 `AskUserQuestion` calls (2 per phase × 8 phases including HANDOFF's 3-option menu). Nites/Supply minimum is 12 (2 per phase × 6 phases — Phase 3 CRAWL + Phase 6 VERIFY+TIER skipped). The grep-test threshold of ≥16 reflects the Labs maximum. Skip notes are repeated inline at the top of Phase 3 CRAWL and Phase 6 VERIFY+TIER.

8. **HANDOFF prints, does not chain.** Phase 7 renders the next-command invocation string for the operator to copy/run. Auto-invocation of `/marketing:launch-campaign` or list-building would defeat the operator-intent contract. Per BC-5950 brainstorm Q7: print, don't chain.

---

## Change history

- **2026-04-27** — Created per <issue id="BC-5950">BC-5950</issue>. 8-phase orchestrator over the BC-5832 tam-mapping skill. Mirrors the BC-5826 11-phase `/marketing:launch-campaign` per-phase-gate pattern; entity-routes (Labs full 8 phases, Nites/Supply 6 phases skipping CRAWL + VERIFY+TIER); enforces 3 circuit breakers (discovery=0, EB-exclusion=0, enrichment <10%); renders the cost-estimate verbatim string before Phase 5; prints (does not chain) the next-command invocation string at HANDOFF. Plugin version bumped `marketing` 0.3.7 → 0.3.8 in the same commit per CLAUDE.md gotcha "bump plugin version in the SAME commit as any edit under `plugins/<plugin>/{commands,...}/**`".

- **Post-merge follow-up** — File Linear issue: "Extend tam-mapping Phase 3 CRAWL + Phase 6 VERIFY+TIER to Brite Supply (mirror Labs entity routing)". Captures the BC-5950 brainstorm Q6 surface — Supply is B2B with company-level prospects and could benefit from Spider.cloud crawl + MillionVerifier SMTP + tier-a/b/c prioritization; current skill groups Supply with Nites for legacy reasons; would unblock unified 8-phase command flow for both B2B entities.

---

## Attribution

- **Source upstream:** [Revgrowth1/tam-map@9f5c72e74b](https://github.com/Revgrowth1/tam-map) (MIT) — `/tam-map` user-facing entry point shape. Brite-adapts via:
  - **Two-call gate (<issue id="BC-2707">BC-2707</issue>)** — turn structure between every phase invocation, not just at MCP boundaries.
  - **Cost-estimate display (<issue id="BC-5826">BC-5826</issue>)** — verbatim `estimated enrichment cost:` string + operator-intent surface before Phase 5 ENRICH.
  - **Gate-respect contract (<issue id="BC-5866">BC-5866</issue>)** — option selected = option executed; re-prompt before any behavior change.
  - **8th HANDOFF phase (<issue id="BC-5950">BC-5950</issue> design)** — entity-conditional 3-option menu routing to `/marketing:launch-campaign` or BC-2717 list-building or stop. Print, do not chain.
- **Skill orchestrated:** `plugins/marketing/skills/tam-mapping/SKILL.md` — BC-5832, 7-phase TAM construction skill with `--stop-at-phase <N>` + `--no-cost-gate` flags added in BC-5950 T2 to enable per-phase orchestration.
- **Precedent command:** `plugins/marketing/commands/launch-campaign.md` — BC-5826, 11-phase command. Per-phase-gate pattern, two-call MCP gate idiom, IV-1..IV-7 input validation block, operator-intent gating shape.
- **ADR:** `docs/decisions/008-tam-mapping-enrichment-pluggability.md` — provider resolution order (`--enrichment-provider` flag → `${user_config.enrichment_provider}` → auto-detect probe chain). Command's IV-5 enforces enum; Phase 5 step 1 walks the resolution.
- **Setup precedent:** `plugins/marketing/commands/setup-tam-map.md` — Phase 1 detect logic for MCP/CLI verification (reused verbatim in this command's Phase 0 step 2).
