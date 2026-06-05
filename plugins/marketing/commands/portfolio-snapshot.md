---
description: Read-only monthly / quarterly GTM portfolio rollup. Synthesizes Salesforce Campaign quantitative + Linear orchestration + plugin-filesystem qualitative (learnings.md / mmf-matrix.md / analysis-*.md / manifest.json glob) into one markdown packet per invocation at `docs/campaigns/_reviews/`. Strict-previous-calendar-month default (--monthly) or strict-previous-calendar-quarter default (--quarterly). Inherits metric definitions from `campaign-analysis` §3.3 — does NOT define new metrics. Triggers on "portfolio snapshot", "monthly review packet", "quarterly review packet", "gtm rollup", or direct `/marketing:portfolio-snapshot` invocation.
argument-hint: --monthly | --quarterly [--target-org <alias>]
allowed-tools: mcp__plugin_revops_salesforce__run_soql_query, mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, mcp__plugin_workflows_linear-server__list_milestones, Read, Glob, Bash, Write
---

# /marketing:portfolio-snapshot

Read-only synthesis orchestrator for the GTM Campaign Orchestration v1.0 monthly / quarterly review cadence.

**Ratified at V3 (2026-05-22).** See [`docs/v3-ratification-outcome-2026-05-22.md`](../../../docs/v3-ratification-outcome-2026-05-22.md) item 6 for the 5-section structure, the strict-previous-calendar-month --monthly window decision, and the load-bearing anti-creep guards. M2 cluster downstream; BC-8735 (handbook how-we-operate cadence rows) cites this command's name + flags.

**Read-only contract** (load-bearing): never mutates source artifacts; never re-runs campaign-debrief logic; reads pre-aggregated `learnings.md` Summary / What works / What doesn't sections verbatim; emits ONE markdown packet per invocation under `docs/campaigns/_reviews/`. No new metric definitions — every numeric formula inherits from `campaign-analysis` §3.3 (b2b) or §4 (b2c).

**Soft-fail philosophy.** SF + Linear are downstream best-effort surfaces. When SF auth fails or Linear MCP is unreachable, the affected output section degrades to a ⚠ banner explaining the gap; the rest of the packet still emits. Plugin-filesystem reads (manifest.json + learnings.md + mmf-matrix.md + analysis-*.md) are the source of truth; if the filesystem read fails, halt with a clear error.

## Input flags

| Flag | Required | Notes |
|---|---|---|
| `--monthly` | one-of | Strict previous calendar month. Mutually exclusive with `--quarterly`. |
| `--quarterly` | one-of | Strict previous calendar quarter (e.g., invoked 2026-05-26 → Q1 2026 = 2026-01-01 → 2026-03-31). Mutually exclusive with `--monthly`. |
| `--target-org` | no | Default `brite-prod`. SF org alias for the SOQL Campaign pull. Validated against `^[a-zA-Z0-9._@-]+$` — shell-injection guard. |

Exactly one of `--monthly` / `--quarterly` MUST be provided. If both are present, hard-fail (exit non-zero) with: `ERROR: --monthly and --quarterly are mutually exclusive. Pick one.` If neither is present, hard-fail with: `ERROR: must provide one of --monthly or --quarterly. See V3 outcome doc item 6 — anti-creep guard against unbounded windows.`

### Explicitly rejected flags (anti-creep)

Each of the four flags below is rejected at parse time with a non-zero exit and an explicit citation of the V3 outcome doc. These rejections are LOAD-BEARING per V3 item 6 ratification.

<!-- BC-8731-rejected-flags-anchor: Do not edit this comment or the table below without updating `plugins/marketing/scripts/test_portfolio_snapshot.sh` Scenario E. The harness locks both the anchor and the per-row table shape per [[pattern-rubric-lock-grep-triad]]. -->

| Flag | Reject message |
|---|---|
| `--weekly` | `ERROR: --weekly rejected. Monthly + quarterly are the only windows per V3 outcome (docs/v3-ratification-outcome-2026-05-22.md item 6). Weekly cadence is served by the SF list view (item 7), not by a review packet.` |
| `--custom-window` | `ERROR: --custom-window rejected. Strict calendar-aligned windows only per V3 outcome (docs/v3-ratification-outcome-2026-05-22.md item 6, ambiguity #2 resolution). Reproducibility + SF closed-won alignment + first-Monday review cadence depend on the default window.` |
| `--forecast` | `ERROR: --forecast rejected. Portfolio snapshot is retrospective only per V3 outcome (docs/v3-ratification-outcome-2026-05-22.md item 6). Forecasting belongs in SF dashboards (item 7), not in the review packet.` |
| `--charts` | `ERROR: --charts rejected. Markdown-only output per V3 outcome (docs/v3-ratification-outcome-2026-05-22.md item 6). Visualization belongs in SF dashboards (BC-8715 / BC-8716), not in the review packet.` |

Any other unknown flag also hard-fails with: `ERROR: unknown flag '<flag>'. Supported flags: --monthly, --quarterly, --target-org. See V3 outcome doc item 6 for anti-creep posture.`

## Anti-creep guards (load-bearing per V3 outcome item 6)

These are runtime invariants. Procedural enforcement appears in the Phase steps below; the guards are summarized here so a reader can audit the command in one place:

1. **No writes outside `docs/campaigns/_reviews/`.** The ONLY `Write` tool call in this command targets `docs/campaigns/_reviews/monthly-{YYYY-MM}.md` or `docs/campaigns/_reviews/quarterly-{YYYY-Q}.md`. No other path. No edits to manifest.json, learnings.md, mmf-matrix.md, analysis-*.md, canonicals YAML, or anything else. The output directory is created with `mkdir -p` on first run.
2. **No re-runs of campaign-debrief logic.** The skill READS `learnings.md` Summary / What works / What doesn't sections (which `campaign-debrief` regenerates in place on each append per its §3 Append-only invariant — see [`plugins/marketing/skills/campaign-debrief/SKILL.md`](../skills/campaign-debrief/SKILL.md)). The skill does NOT re-aggregate from the `## Campaign log` entries. The pre-aggregation is the load-bearing simplification.
3. **No new metric formulas.** Every metric in the output traces back to either (a) a pre-computed SF Campaign field (`AmountAllOpportunities`, `AmountWonOpportunities`, `NumberOfLeads`) or (b) a pre-aggregated section of `learnings.md` / `mmf-matrix.md` / `analysis-*.md`. The canonical metric source is [`campaign-analysis` §3.3 (b2b) + §4 (b2c)](../skills/campaign-analysis/SKILL.md). Cite when in doubt; do NOT invent.
4. **Read-only on source artifacts.** `manifest.json`, `learnings.md`, `mmf-matrix.md`, `analysis-*.md`, `canonicals/*.yaml` — all `Read`-only. The command issues exactly one `Write` (the output packet); any other `Write` call is a bug.

## Window resolution

Run via the `Bash` tool ONCE per invocation, before any data fetch. The current date is the only input; the window is computed from it.

```bash
# Monthly window — strict previous calendar month
# Today 2026-05-26 → window = 2026-04-01 .. 2026-04-30
today_iso=$(date -u +%Y-%m-%d)
this_month_first=$(date -u +%Y-%m-01)
window_end=$(date -u -j -v-1d -f "%Y-%m-%d" "$this_month_first" +%Y-%m-%d 2>/dev/null || date -u -d "$this_month_first - 1 day" +%Y-%m-%d)
window_start=$(date -u -j -f "%Y-%m-%d" "$window_end" "+%Y-%m-01" 2>/dev/null || date -u -d "$window_end" +%Y-%m-01)
window_label="$(date -u -j -f "%Y-%m-%d" "$window_start" "+%Y-%m" 2>/dev/null || date -u -d "$window_start" +%Y-%m)"
output_path="docs/campaigns/_reviews/monthly-${window_label}.md"

# Quarterly window — strict previous calendar quarter
# Today 2026-05-26 (in Q2) → window = Q1 = 2026-01-01 .. 2026-03-31
# Today 2026-08-15 (in Q3) → window = Q2 = 2026-04-01 .. 2026-06-30
this_year=$(date -u +%Y)
this_month_num=$(date -u +%m)  # 01-12, zero-padded
case "$this_month_num" in
  01|02|03)  pq_year=$((this_year - 1)); pq_num=4 ;;
  04|05|06)  pq_year=$this_year;          pq_num=1 ;;
  07|08|09)  pq_year=$this_year;          pq_num=2 ;;
  10|11|12)  pq_year=$this_year;          pq_num=3 ;;
esac
case "$pq_num" in
  1) window_start="${pq_year}-01-01"; window_end="${pq_year}-03-31" ;;
  2) window_start="${pq_year}-04-01"; window_end="${pq_year}-06-30" ;;
  3) window_start="${pq_year}-07-01"; window_end="${pq_year}-09-30" ;;
  4) window_start="${pq_year}-10-01"; window_end="${pq_year}-12-31" ;;
esac
window_label="${pq_year}-Q${pq_num}"
output_path="docs/campaigns/_reviews/quarterly-${window_label}.md"
```

The output path is deterministic given today's date + the chosen flag. Re-runs against the same window OVERWRITE the same file — the packet is regenerated, not appended (mirrors `campaign-debrief`'s Summary-section regenerate-in-place carve-out, but for the whole packet since it has no append-log semantics).

## Phases

### Phase 0 — Resolve SF target-org metadata (soft optimization)

Run via the `Bash` tool ONCE per invocation (skip if `--target-org` was provided and matches the cached default `brite-prod` AND the cache has already been resolved earlier in this session):

```bash
sf org display --target-org "<target-org>" --json
```

Cache from the response:
- `<sf-username>` = `.result.username` — required for Phase 3's MCP `run_soql_query` call (per `gotcha_sf_mcp_username_not_alias.md`, the upstream MCP rejects aliases + `DEFAULT_TARGET_ORG` sentinels).

If `sf org display` fails (auth expired, network), do NOT halt. Set `sf_unavailable=true` and proceed to Phase 1. Phase 3 (SF Campaign pull) will degrade to a ⚠ banner in Section 2 (Pipeline summary) rather than halting the whole packet — the filesystem + Linear paths still produce a usable rollup.

Mirrors the Phase 0 metadata caching in [`/revops:create-sf-campaign`](../../revops/commands/create-sf-campaign.md) and [`/revops:update-sf-campaign-status`](../../revops/commands/update-sf-campaign-status.md).

### Phase 1 — Validate input

After window resolution + Phase 0:

1. Reject illegal flag combinations per the Input flags section above (`--monthly` + `--quarterly`; neither; explicitly-rejected `--weekly` / `--custom-window` / `--forecast` / `--charts`; unknown flags).
2. Validate `--target-org` (if explicitly supplied) against regex `^[a-zA-Z0-9._@-]+$`. On mismatch, hard-fail (exit non-zero) with: `ERROR: --target-org failed regex (^[a-zA-Z0-9._@-]+$); got '<value-truncated-to-80-chars-with-control-bytes-stripped>'.` (Truncate echoed value to 80 chars and strip ASCII control bytes 0x00–0x1F + 0x7F.) Defense against shell injection into Phase 0's `sf` CLI shell-out.
3. Compute the output path per Window resolution above. If the output file already exists, that's fine — the packet regenerates in place.

### Phase 2 — Read plugin filesystem (source of truth)

Filesystem reads are the load-bearing data source. SF + Linear are best-effort enrichment.

1. **Glob `docs/campaigns/*/*/manifest.json`** — picks up every campaign scaffold under `docs/campaigns/<short-entity>/<slug>/` per BC-8719 (entity-slug short-form migration). Per `gotcha_lint_marker_token_collides_with_worktree_dirname.md`, anchor paths from `REPO_ROOT` (typically the CWD when the command runs) rather than from absolute paths to keep downstream filters robust.

2. **Filter manifests to in-window** — three-clause priority per the helper's `filter_in_window` contract:
   - **(1)** If `created_at` parses successfully as ISO-8601, the timestamp DECIDES (in-window or out-of-window). Slug suffix is ignored even if it disagrees — a campaign re-scheduled away from its slug-encoded launch month is fit by the actual launch event, not the intended one. A manifest is in-window if `window_start <= created_at <= window_end T23:59:59Z`.
   - **(2)** If `created_at` is missing OR unparseable (malformed string / non-string type), fall back to deriving the launch month from the slug's `fy{YY}-m{MM}` suffix:
     - `fy{YY}` = fiscal year suffix → `2000 + YY` (Brite GTM uses calendar-aligned fiscal years per ADR-012).
     - `m{MM}` = month number (01-12).
     - Derived launch month start = `{2000+YY}-{MM}-01`. A manifest with a slug-derived launch month INSIDE the window counts.
   - **(3)** If BOTH paths fail (no `created_at` AND slug has no valid `fy/m` suffix), the manifest is EXCLUDED and the helper emits a `[BC-8731]` stderr warning so an operator notices the corrupted manifest. Silent drop would mask data loss; an explicit warning lets the operator triage.

3. **For each in-window manifest**, read:
   - The manifest itself (slug + entity + vertical + persona + offer + year + month + salesforce.campaign_id + email_bison.workspace + email_bison.campaigns[] in v2 / email_bison.campaign_id + email_bison.launched_at in v1 — the Section 2 renderer is shape-aware per BC-11852: when `email_bison.campaigns[]` is present, each EB record's `campaign_id` + `launched_at` is aggregated for the row's display; otherwise the v1 singular fields are used as a graceful-fallback path during the one-cycle transition window).
   - The sibling `learnings.md` at `docs/campaigns/<short-entity>/learnings.md` (one file per entity, NOT per campaign per `campaign-debrief` §4). Extract:
     - `## Summary stats` block (Total debriefs, verdict counts SCALE/ITERATE/PAUSE/KILL, Last debrief).
     - `## What works` bullets.
     - `## What doesn't` bullets.
     - The latest `verdict:` frontmatter on entries inside the campaign log that match the focal campaign's slug.
   - Optional siblings under `docs/campaigns/<short-entity>/<slug>/`:
     - `mmf-matrix.md` (if present) — Results Log table, Verdict column.
     - `analysis-*.md` files (any) — §2 Segment Performance Ranking verdict tokens (TOP PERFORMER / SCALE / TEST MORE / MONITOR / UNDERPERFORM).
     - `discoveries.json` — `signals[]` with `promotion_status: pending`.

4. **Read the canonicals manifest** at `plugins/marketing/data/canonicals/_manifest.yaml` to enumerate the canonical vertical list (for Section 5c coverage-gap callouts). This is a Read-only operation — the canonicals are NEVER mutated by this command.

If the filesystem reads fail entirely (e.g., no `docs/campaigns/` directory), halt with: `ERROR: docs/campaigns/ directory not found at <cwd>. /marketing:portfolio-snapshot must run from the britenites-claude-plugins repo root.`

### Phase 3 — Read SF Campaign data (best-effort)

If Phase 0 set `sf_unavailable=true`, skip this phase entirely and set `sf_section_status=degraded_auth`.

Otherwise, call `mcp__plugin_revops_salesforce__run_soql_query` with:

- `usernameOrAlias`: the `<sf-username>` cached from Phase 0 (literal username).
- `query`:
  ```sql
  SELECT Id, Name, Vertical__c, Offer__c, Persona__c, Entity__c,
         Status, Substatus__c, StartDate, EndDate,
         AmountAllOpportunities, AmountWonOpportunities, NumberOfLeads
  FROM Campaign
  WHERE StartDate >= <window_start> AND StartDate <= <window_end>
  ORDER BY StartDate DESC
  LIMIT 500
  ```

Interpolate `<window_start>` and `<window_end>` as SOQL date literals (no quotes — SOQL date literals are unquoted YYYY-MM-DD). The window dates come from Phase 1; they are deterministic and not operator-controlled, so no injection guard is needed (V3 outcome anti-creep guard removes `--custom-window` upstream).

If the SOQL call itself fails (auth refresh, network, permset), set `sf_section_status=degraded_query` and capture the error message for the ⚠ banner in Section 2. Do NOT halt — the rest of the packet still emits.

If the SOQL call returns 0 records, set `sf_section_status=empty` (legitimate empty result; no SF Campaigns in window). Section 2 will render with "0 campaigns; AmountAllOpportunities sum = $0" rather than a degraded banner.

### Phase 4 — Read Linear milestones (best-effort)

The Linear MCP `list_milestones` and `list_issues` shape gaps documented in `gotcha_linear_mcp_milestone_url_filter.md` apply here:

1. Call `mcp__plugin_workflows_linear-server__list_milestones` with `project: "Brite GTM"`. This may return a large dump (~70 milestones at scale); filter the response client-side by name pattern matching the in-window slugs (intersect with Phase 2's manifest set — Linear is enrichment, not source of truth).

2. For each in-window milestone, call `mcp__plugin_workflows_linear-server__get_issue` on the milestone ID to capture status + sub-issue counts. (Avoid `list_issues` with `milestone:` param — per `gotcha_linear_list_issues_milestone_filter.md` it returns issues from multiple milestones unreliably.)

3. **If Linear MCP is unreachable** (tool call errors, timeout), set `linear_section_status=degraded` and capture the error for the Section 1 + Section 3 banner. Do NOT halt — Phase 2's manifest data carries the campaign list; Linear adds milestone status + sub-issue progress only.

### Phase 5 — Invoke section composer (`plugins/marketing/scripts/portfolio_snapshot.py`)

Section composition logic — including all filesystem reads, table rollups, verdict tallies, transferable-insight extraction, action-item collation, and (when `--quarterly`) the cross-quarter transitions / cumulative transferables / per-offer-version / coverage-gap sections — lives in `plugins/marketing/scripts/portfolio_snapshot.py`. The Python helper is the testable surface (regression harness at `plugins/marketing/scripts/test_portfolio_snapshot.sh`).

Construct two temp JSON files from Phase 3 + Phase 4 results, then invoke the helper:

```bash
# Save SF Campaign records (Phase 3 output) — null/empty array allowed
sf_tmp="$(mktemp -t portfolio-snapshot-sf.XXXXXX.json)"
printf '%s' '<phase-3-soql-result-as-json>' > "$sf_tmp"

# Save Linear milestone + sub-issue counts (Phase 4 output) — null/empty object allowed
linear_tmp="$(mktemp -t portfolio-snapshot-linear.XXXXXX.json)"
printf '%s' '<phase-4-linear-result-as-json>' > "$linear_tmp"

# Invoke the helper
python3 plugins/marketing/scripts/portfolio_snapshot.py \
  --span <monthly|quarterly> \
  --window-start <window_start> \
  --window-end <window_end> \
  --campaigns-dir docs/campaigns \
  --canonicals-dir plugins/marketing/data/canonicals \
  --sf-json "$sf_tmp" \
  --sf-status <ok|degraded_auth|degraded_query|empty> \
  --linear-json "$linear_tmp" \
  --linear-status <ok|degraded> \
  --command-version "marketing@$(python3 -c 'import json; print(json.load(open("plugins/marketing/.claude-plugin/plugin.json"))["version"])')" \
  --out "$output_path"
```

After the helper writes, clean up the temp files (`rm -f "$sf_tmp" "$linear_tmp"`) and proceed to Phase 7 (output validation + stdout summary).

If the helper exits non-zero, surface stderr verbatim and exit with the helper's exit code. The helper has its own argument validation, fixture-input parsing, and section-composition logic — it is the executable contract.

### Phase 5-detail — Section shapes (informational, helper-implemented)

The five monthly sections (and four additional quarterly sections) are described below for reader reference; the canonical implementation is in the Python helper. Output mismatches between this description and the helper's actual output should be reported as bugs against the helper — the markdown description here is normative only insofar as the helper agrees with it.

#### Section 1 — Portfolio shape

A single table listing every in-window manifest, one row per campaign:

```markdown
## 1. Portfolio shape

| Entity | Vertical | Persona | Offer | Posture | Status | Slug |
|---|---|---|---|---|---|---|
| <entity> | <vertical> | <persona> | <offer> | <posture-from-manifest-or-canonicals> | <linear-status-from-Phase4-or-"unknown"> | <slug> |
| ... | ... | ... | ... | ... | ... | ... |

**Totals:** {N} campaigns in window · {entity-set-size} entities · {vertical-set-size} verticals · {persona-set-size} personas · {offer-set-size} offers · {posture-set-size} postures

**By entity:** labs = {n} / supply = {n} / nites = {n} / cross-entity = {n}
**By vertical:** {top-N vertical breakdown, others summarized}
**By posture:** free-asset = {n} / knowledge = {n} / pilot = {n} / risk-reversal = {n}
**By Linear status:** planning = {n} / active = {n} / completed = {n} / killed = {n} / paused = {n}

{If linear_section_status=degraded: append a ⚠ note}
```

Posture comes from the manifest's `offer_posture` field if present; otherwise look up the offer slug in `plugins/marketing/data/canonicals/<vertical>.yaml` and read the `offers[].posture` field. If unresolvable, render `(unknown)`.

#### Section 2 — Pipeline summary

```markdown
## 2. Pipeline summary

{If sf_section_status=degraded_auth: ⚠ banner "SF rollup section degraded — auth probe failed at Phase 0. Run `sf org display --target-org <target> --json` manually to diagnose, then re-run. Filesystem + Linear sections below are unaffected."}

{If sf_section_status=degraded_query: ⚠ banner "SF rollup section degraded — SOQL call failed at Phase 3 with: <error message>. Filesystem + Linear sections below are unaffected."}

{Otherwise — render the table}

| Slug | SF Campaign | AmountAllOpportunities | AmountWonOpportunities | NumberOfLeads | EB campaign_id | Launched |
|---|---|---|---|---|---|---|
| <slug> | <Campaign.Id or "(absent)"> | <Amount or "n/a"> | <Amount or "n/a"> | <count or "n/a"> | <eb_campaign_id from manifest or "(not launched)"> | <yes/no from manifest.email_bison.launched_at> |
| ... | ... | ... | ... | ... | ... | ... |

**Totals:**
- pipeline_value (sum AmountAllOpportunities) = ${total}
- won_revenue (sum AmountWonOpportunities) = ${total}
- leads_total (sum NumberOfLeads) = {total}
- EB campaigns launched in window = {count}
```

Sums skip null fields silently. If every row has null SF data, render "Totals: pipeline_value = unavailable (no in-window SF Campaigns matched)" rather than a numerical zero — null-vs-zero distinction matters.

#### Section 3 — Verdict distribution

Three subsections, one per verdict vocabulary (per V3 outcome item 4 — three distinct vocabularies at separate decision surfaces). Read PRE-AGGREGATED counts; do NOT re-aggregate from individual entries.

```markdown
## 3. Verdict distribution

### 3a. Angle Verdict (from creative-angles outputs in window)

{Currently no canonical artifact — render: "Sub-issue #10 (Creative Angles) is the upstream surface; per-campaign angle scores live in manifest.angles[] when /marketing:creative-angles emits them. Window's angle scores not aggregated until /marketing:creative-angles ships its output-artifact contract."}

OR, if any manifest has an `angles[]` field with scored entries:

Distribution: ALPHA = {n} / PROMISING = {n} / INTERESTING = {n} / COMMODITY = {n} / unscored = {n}

### 3b. Experiment Verdict (from mmf-matrix.md Results Log)

For each in-window campaign with a sibling `docs/campaigns/<short-entity>/<slug>/mmf-matrix.md`:
- Read the `## Results Log` table.
- Tally the `Verdict` column values.

Distribution: SUPER WORKS = {n} / KIND OF WORKS = {n} / DEFERRED = {n} / DOESN'T WORK = {n} / PENDING = {n}

If no mmf-matrix.md exists for any in-window campaign, render: "No mmf-matrix.md present for any in-window campaign — MSPA experiments not yet batched."

### 3c. Campaign Verdict (from learnings.md Summary stats)

For each entity with an in-window campaign that has a debrief entry in `docs/campaigns/<short-entity>/learnings.md`:
- Read the `## Summary stats` section verbatim.
- Sum the "Campaign verdicts: SCALE={s}, ITERATE={i}, PAUSE={p}, KILL={k}" line ACROSS entities — these are pre-aggregated, do NOT re-aggregate from `## Campaign log` entries.

Distribution: SCALE = {sum-s} / ITERATE = {sum-i} / PAUSE = {sum-p} / KILL = {sum-k} / not-yet-debriefed = {N - sum-of-debriefs}
```

If a learnings.md doesn't yet exist for an entity, that entity's campaigns count toward `not-yet-debriefed`. If the Summary stats block is malformed (regex no-match), log a stderr warning `[BC-8731] Skipping malformed Summary stats in docs/campaigns/<short-entity>/learnings.md` and treat the entity as zero-debriefed for this run.

#### Section 4 — Transferable insights

```markdown
## 4. Transferable insights

Source: `learnings.md` "What works" + "What doesn't" sections across campaigns in window. Pre-aggregated by `campaign-debrief`; NOT re-aggregated here per BC-8731 anti-creep guard.

**What works (across debrief'd campaigns):**

- {verbatim bullet from learnings.md ## What works}
- {verbatim bullet}
- ...

**What doesn't (across debrief'd campaigns):**

- {verbatim bullet from learnings.md ## What doesn't}
- ...
```

Iterate every entity's learnings.md. For each, extract the `## What works` and `## What doesn't` sub-bullets verbatim. Do NOT paraphrase, summarize, or re-rank — the upstream `campaign-debrief` skill curates these on every append.

If no learnings.md has either section populated (zero in-window debriefs), render: "No transferable insights available — no in-window campaigns have reached the campaign-debrief step (sub-issue #8) yet."

#### Section 5 — Action items

```markdown
## 5. Action items

### 5a. Pending discoveries.json signals

For each in-window manifest, read sibling `discoveries.json` (file-not-found is OK, branches to empty). Filter `signals[]` where `promotion_status == "pending"`. For each:

- Category: {category}
- Slug: {slug derived from the discoveries.json path}
- Emitted by: {emitted_by_skill}
- Summary: {one-line description from payload.observed_pattern or payload.refinement_proposal or payload.recommended_replacement or category-appropriate field}

### 5b. Operational follow-ups (from analysis-*.md flagged items)

For each in-window manifest with sibling `analysis-*.md`, scan the §6 Next Iteration Recommendations block for action-tagged bullets (any bullet containing "TODO:", "ACTION:", "FOLLOW-UP:", or rendered as a `SCALE` / `UNDERPERFORM` priority row). Surface each verbatim with the source campaign + analysis-*.md filename.

If no analysis-*.md files exist in window: "No analysis-\*.md artifacts in window — campaign-analysis (BC-2721) has not run on any in-window campaign yet."
```

### Phase 6 — Quarterly extras (sections 6–9, --quarterly only — helper-implemented)

When `--quarterly` was specified, append these four additional sections AFTER the five monthly sections.

#### Section 6 — Cross-quarter MSPA transitions

```markdown
## 6. Cross-quarter MSPA transitions

For each in-window mmf-matrix.md, scan the Results Log for rows where the verdict changed since the prior quarter (e.g., DEFERRED → SUPER WORKS, or KIND OF WORKS → DOESN'T WORK). MSPA tracks per-experiment verdicts append-only, so a "transition" is identified by:

- Same experiment slug across two quarters' Results Log entries.
- Different Verdict tokens.

| Experiment | Prior quarter verdict | This quarter verdict | Source |
|---|---|---|---|
| <slug> | <prior> | <current> | docs/campaigns/<short-entity>/<slug>/mmf-matrix.md |
| ... | ... | ... | ... |
```

If no MSPA matrices exist or no transitions are detected, render: "No cross-quarter MSPA transitions detected in window."

#### Section 7 — Cumulative transferables

```markdown
## 7. Cumulative transferables

Quarterly-only: aggregate the Section 4 transferables across all entities + all in-quarter campaigns, then deduplicate identical bullets that appeared in multiple entities' learnings.md (a duplicate is signal — surface as "appeared in N entities" rather than collapsing). Note: `learnings.md` is one file per entity per [`campaign-debrief` §4](../skills/campaign-debrief/SKILL.md), so the de-dup unit is the entity, not the campaign.

- {bullet} (appeared in N entities)
- {bullet} (appeared in 1 entity)
- ...
```

#### Section 8 — Per-offer-version aggregation

```markdown
## 8. Per-offer-version aggregation

For each in-window manifest, derive offer version from the slug suffix (`-v2`, `-v3`, etc.; absent = v1 implicit). Group manifests by `{vertical}/{persona}/{offer}` and within each group rank versions by Section 2's pipeline metrics.

| Vertical | Persona | Offer | Version | AmountAll | AmountWon | Leads |
|---|---|---|---|---|---|---|
| <v> | <p> | <o> | v1 | $X | $Y | N |
| <v> | <p> | <o> | v2 | $X' | $Y' | N' |
| ... | ... | ... | ... | ... | ... | ... |
```

If no offer-version suffixes are present (the `-v{N}` convention has not yet been used in any in-window manifest), render: "No offer-version aggregation available — no in-window slug uses the `-v{N}` suffix convention. T9-V (offer-versioning) has not yet shipped, or no campaign has needed a v2+ iteration in window."

#### Section 9 — Coverage-gap callouts

```markdown
## 9. Coverage-gap callouts

Source: `plugins/marketing/data/canonicals/_manifest.yaml` enumerates the canonical verticals; this section flags verticals with zero in-window campaigns.

**Verticals with 0 in-window campaigns:** {N of 27 canonical verticals}

- {vertical-1}
- {vertical-2}
- ...

(N of 27 is structural — count canonicals at `_manifest.yaml` `verticals[]` per [ADR-016 / BC-8718](../../../docs/decisions/016-gtm-plugin-side-canonicals.md). Numbers reflect runtime state — do NOT hardcode "27".)
```

### Phase 7 — Validate output + emit stdout summary

The helper has already written the output file at Phase 5. Verify the write succeeded via a `Read` on `output_path`, then emit a one-line stdout summary.

The output file's frontmatter (composed by the helper) has the following shape:

```yaml
---
schema_version: 1
generated_at: <ISO-8601 UTC timestamp at command-start time>
window:
  start: <window_start>
  end: <window_end>
  span: <"monthly" | "quarterly">
command_version: marketing@<plugin-version-from-plugin.json>
sources:
  sf: <"ok" | "degraded_auth" | "degraded_query" | "empty">
  linear: <"ok" | "degraded">
  filesystem: ok
---

# Portfolio Snapshot — {window_start} → {window_end} ({window_label})

[Sections 1–5 monthly + 6–9 quarterly if applicable]

---

End of packet.
```

The `command_version` field is passed into the helper from Phase 5's `--command-version` flag — the markdown command reads `plugins/marketing/.claude-plugin/plugin.json` `.version` at runtime and constructs the helper invocation.

**ASSERTION (anti-creep guard 1):** the ONLY `Write` tool call in this entire procedure targets `output_path` (computed in Window resolution; always under `docs/campaigns/_reviews/`). The helper enforces this internally — it refuses to write outside `_reviews/`. If you find yourself about to issue any other `Write` from the markdown command, stop — it's a bug. The directory `docs/campaigns/_reviews/` is created with `mkdir -p` (via `Bash` tool) before the helper invocation if it doesn't exist.

After the helper writes successfully, emit to stdout (NOT to the packet file):

```
OK: portfolio-snapshot written → docs/campaigns/_reviews/<filename>.md
    window: <window_start> → <window_end> (<span>)
    sources: sf=<status>, linear=<status>, filesystem=ok
    campaigns_in_window: <N>
```

Exit 0 on success.

## Output frontmatter contract

Schema (consumed by future downstream tools; pinned at `schema_version: 1`):

| Field | Type | Notes |
|---|---|---|
| `schema_version` | int | Always `1` for this command version. Bump on breaking change. |
| `generated_at` | ISO-8601 string | UTC. Captured at command-start, NOT at write-time. |
| `window.start` | YYYY-MM-DD | Inclusive. |
| `window.end` | YYYY-MM-DD | Inclusive. |
| `window.span` | `"monthly"` or `"quarterly"` | Drives downstream consumers. |
| `command_version` | string | `marketing@<semver>` from plugin.json. |
| `sources.sf` | string enum | `"ok"`, `"degraded_auth"`, `"degraded_query"`, `"empty"`. |
| `sources.linear` | string enum | `"ok"`, `"degraded"`. |
| `sources.filesystem` | string | Always `"ok"` (if filesystem fails, the command halts before reaching Phase 7). |

## Idempotency

Re-running with the same flags + same calendar date OVERWRITES the same output file. The packet is a snapshot, not an append log — there's no append semantic, mirroring SF dashboards (`/marketing:portfolio-snapshot --monthly` is the markdown sibling of an SF dashboard view, per V3 outcome item 7). If the operator wants to preserve a snapshot, they commit the output file before re-running.

## Examples

```
/marketing:portfolio-snapshot --monthly
# → docs/campaigns/_reviews/monthly-2026-04.md (assuming today is 2026-05-26)

/marketing:portfolio-snapshot --quarterly
# → docs/campaigns/_reviews/quarterly-2026-Q1.md (assuming today is 2026-05-26)

/marketing:portfolio-snapshot --monthly --target-org brite-prod-sandbox
# → docs/campaigns/_reviews/monthly-2026-04.md (against brite-prod-sandbox SF org)

/marketing:portfolio-snapshot --weekly
# → ERROR: --weekly rejected. Monthly + quarterly are the only windows per V3 outcome doc item 6. Weekly cadence served by SF list view (item 7), not by a review packet.

/marketing:portfolio-snapshot
# → ERROR: must provide one of --monthly or --quarterly.

/marketing:portfolio-snapshot --monthly --quarterly
# → ERROR: --monthly and --quarterly are mutually exclusive. Pick one.
```

## When to run this command

Per V3 outcome doc item 7 (SF list view + handbook how-we-operate cadence, BC-8735 codifies):

| Cadence | Trigger | Command |
|---|---|---|
| Monthly | First Monday of each month (calendar) | `/marketing:portfolio-snapshot --monthly` |
| Quarterly | First Monday of each calendar quarter (Jan / Apr / Jul / Oct) | `/marketing:portfolio-snapshot --quarterly` |
| Ad-hoc | Any time — output is deterministic given today + flag | Either flag, as needed |

The output file is the deliverable for the Monday GTM sync (item 7) — operators paste it into the meeting agenda OR link to the file path in the team channel. The command does NOT auto-publish.

## Gotchas

- **No `--weekly`, `--custom-window`, `--forecast`, `--charts` flags.** All four are rejected at parse time per V3 outcome doc item 6. Anti-creep guard. The error messages cite the V3 doc explicitly so future operators don't re-litigate.
- **SF `usernameOrAlias` must be a literal username.** Per `memory/gotcha_sf_mcp_username_not_alias.md` — Phase 0 resolves it once via `sf org display --json`, caches `.result.username`, and reuses it for Phase 3's SOQL call. Never pass `DEFAULT_TARGET_ORG` or a raw alias to `run_soql_query`.
- **Linear `list_issues` `milestone:` param is unreliable.** Per `memory/gotcha_linear_list_issues_milestone_filter.md` — use `list_milestones` + per-milestone `get_issue` instead. Same gotcha applies to `list_issues` `project:` param (per `memory/gotcha_linear_list_issues_project_filter.md`).
- **Manifest glob picks up SHORT-form entity slugs.** Per BC-8719 (O15 migration shipped PR #361), `docs/campaigns/labs/...` not `docs/campaigns/brite-labs/...`. The glob pattern `docs/campaigns/*/*/manifest.json` works for both; the read-shim is one release cycle (retires when all entities are confirmed short-form on disk).
- **Manifest schema v1 vs v2 (BC-11852 / ADR-020).** The reader handles both shapes — v1 manifests with singular `email_bison.campaign_id` + `launched_at` AND v2 manifests with `email_bison.campaigns[]` array of records. Section 2's `EB campaign_id` column shows the first record's id with a `(+N more)` suffix when multiple EB records exist; `Launched` is `yes` when ≥1 record has `launched_at`. The v1 fallback is a one-cycle transition shim (post-BC-11852 ship) — once every manifest on disk is v2 (run `python3 plugins/marketing/scripts/migrate_manifest_v1_to_v2.py` to convert any stragglers), the v1 branch in `eb_render_fields()` is dead code and can be dropped.
- **`learnings.md` is one file per entity, not per campaign.** Per `campaign-debrief` §4 Implementation — `docs/campaigns/<short-entity>/learnings.md`, single file, append-only Campaign log + regenerate-in-place summary sections. This command reads ONLY the regenerated summary sections (`## Summary stats`, `## What works`, `## What doesn't`), never the per-entry `## Campaign log` block.
- **Output file regenerates, doesn't append.** Re-running against the same window overwrites. Operators who want to preserve a snapshot commit the file before re-running. This matches the SF dashboard semantic (item 7): the output IS the rollup view, not a log.
- **`sf data query` is NOT used here.** The σ3 sibling commands (`/revops:create-sf-campaign`, `/revops:update-sf-campaign-status`) use a mix of `sf data create` CLI calls + `run_soql_query` MCP calls. This command is pure read — uses `run_soql_query` only. No `Bash sf data` shell-outs for SF data fetching.

## References

- BC-8731 — this command's parent issue (M2 cluster — load-bearing for V3 ratified portfolio-snapshot output shape)
- BC-8729 — V3 ratification (item 6 ratified the 5-section structure + strict previous-calendar-month window)
- BC-8727 — first dogfood campaign (cohort-1 Hotels & Resorts × Anchor Audit; current sole in-`docs/campaigns/` artifact set for manual smoke-test)
- BC-8719 — entity-slug short-form migration (shipped PR #361; this command's glob pattern depends on the post-migration layout)
- BC-8728 — `/marketing:offer-performance --quarterly` (sibling future command; Rule-of-Two extraction candidate to `_shared/` once it ships)
- BC-8735 — handbook how-we-operate cadence rows (cites this command's name + flags; cheapest M2 follow-up)
- [ADR-014](../../../docs/decisions/014-gtm-salesforce-portfolio-rollup.md) — SF as portfolio rollup home (V3 outcome item 7 ratifies)
- [ADR-016](../../../docs/decisions/016-gtm-plugin-side-canonicals.md) — plugin-side canonicals (Section 9 coverage-gap callouts read `_manifest.yaml`)
- [ADR-018](../../../docs/decisions/018-gtm-verdict-vocabularies.md) — 3-verdict vocabularies (Section 3 subsections 3a/3b/3c)
- [V3 ratification outcome doc](../../../docs/v3-ratification-outcome-2026-05-22.md) — item 6 is this command's design spec; cited verbatim in `--weekly` / `--custom-window` / `--forecast` / `--charts` reject messages
- [`campaign-analysis` SKILL.md §3.3 + §4](../skills/campaign-analysis/SKILL.md) — canonical metric definitions; this command inherits, does NOT define
- [`campaign-debrief` SKILL.md §3](../skills/campaign-debrief/SKILL.md) — learnings.md append-only invariant + regenerate-in-place carve-out; this command reads the regenerated summary sections
- `memory/gotcha_sf_mcp_username_not_alias.md` — Phase 0 username caching pattern
- `memory/gotcha_linear_list_issues_milestone_filter.md` + `gotcha_linear_list_issues_project_filter.md` — Linear MCP filter unreliability; Phase 4 mitigation
- `memory/gotcha_linear_mcp_milestone_url_filter.md` — Linear `list_milestones` no-filter dump pattern
