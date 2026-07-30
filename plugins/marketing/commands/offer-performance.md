---
description: Per-offer-version performance synthesis. Reads manifest.json glob + EB campaign stats + SF Campaign data; emits per-version performance.md under docs/campaigns/{entity}/offers/{slug}/{version}/. Inherits metric definitions from campaign-analysis §3.3 per handbook/marketing/frameworks/vocabulary.md Section 5. See docs/v3-ratification-outcome-2026-05-22.md for anti-creep guards ratified at V3. Triggers on "offer performance", "offer metrics", "how is this offer doing", or direct /marketing:offer-performance invocation.
argument-hint: --offer-slug <slug> [--version <N>] [--entity <entity>] [--target-org <alias>]
allowed-tools: mcp__plugin_revops_salesforce__run_soql_query, mcp__emailbison-b2b__get_campaign_stats, mcp__emailbison-personal__get_campaign_stats, Read, Glob, Bash, Write
---

# /marketing:offer-performance

Per-offer-version performance synthesis for GTM Campaign Orchestration v1.0.

**Read-only contract** (load-bearing): never mutates source artifacts (manifest.json, learnings.md, mmf-matrix.md, canonicals/*.yaml). Writes ONLY to `docs/campaigns/{entity}/offers/{slug}/{version}/performance.md`. No new metric definitions — inherits from `campaign-analysis` §3.3 per `handbook/marketing/frameworks/vocabulary.md` Section 5.

**No automated retirement decisions.** Flags retirement candidates when N consecutive versions show declining reply rates; operator decides via `discoveries.json` offer-retirement signal (BC-8722 schema).

## Input flags

| Flag | Required | Notes |
|---|---|---|
| `--offer-slug` | yes | The offer slug from canonicals (e.g., `holiday-anchor-audit`). Validated against canonicals. |
| `--version` | no | Specific version number to analyze. Default: all versions across the offer's lifetime. |
| `--entity` | no | Entity short slug (e.g., `labs`). Auto-detected from manifest.json or canonicals if absent. |
| `--target-org` | no | Default `brite-prod`. SF org alias for the SOQL Campaign pull. Validated against `^[a-zA-Z0-9._@-]+$`. |

## Phases

### Phase 0 — Resolve SF target-org metadata

<!-- guard:target-org -->
**First, validate `--target-org` — before the metadata shell-out below (its earliest sink).** If `--target-org` was explicitly supplied, validate it against regex `^[a-zA-Z0-9._@-]+$`. On mismatch, **hard-fail (exit non-zero)** with: `ERROR: --target-org failed regex (^[a-zA-Z0-9._@-]+$); got '<value-truncated-to-80-chars-with-control-bytes-stripped>'.` (Truncate the echoed value to 80 chars and strip ASCII control bytes 0x00–0x1F + 0x7F.) The shell-out below interpolates `--target-org` into a double-quoted `sf` argument, which blocks bare metacharacters but **not** `$(...)` / backtick command substitution — so this regex (which excludes `$`, `(`, `)`, backticks, whitespace) MUST run **before** that interpolation (guard-precedes-sink; BC-12638). Keep the regex byte-identical to `/marketing:portfolio-snapshot` and the revops σ3 siblings — the consolidating lint (`scripts/_lib/lint_target_org_guard.py`) enforces both the byte-identity and that this `<!-- guard:target-org -->` marker precedes the sink.

Then mirror the BC-8717/BC-8723/BC-8731 metadata cache pattern:

```bash
sf org display --target-org "<target-org>" --json
```

Cache `<sf-username>` = `.result.username` for Phase 3's MCP call (per `gotcha_sf_mcp_username_not_alias.md`).

If `sf org display` fails, set `sf_unavailable=true` and proceed. Phase 3 degrades to a banner.

### Phase 1 — Validate inputs

1. Validate `--offer-slug` against canonicals using the shared `canonicals_reader.validate_canonical_ref`. On mismatch, hard-fail with a clear error.
2. Auto-detect `--entity` if absent: look up from matching manifest.json or from canonicals.
3. `--target-org` is validated earlier, in **Phase 0** (its earliest sink) — see there; the `^[a-zA-Z0-9._@-]+$` shell-injection guard runs before the value reaches the `sf` CLI shell-out.

### Phase 2 — Read plugin filesystem

1. Glob `docs/campaigns/{entity}/*/manifest.json` filtered by offer slug using `manifest_loader.glob_manifests_by_offer`.
2. If `--version` provided, further filter to manifests whose slug contains `-v{N}` (or implicit v1).
3. For each matching manifest: read sibling artifacts (learnings.md, mmf-matrix.md, analysis-*.md, discoveries.json) via `manifest_loader.read_sibling_artifacts`.

### Phase 3 — Read SF Campaign data (best-effort)

If Phase 0 set `sf_unavailable=true`, skip and set `sf_status=degraded_auth`.

Otherwise, call `mcp__plugin_revops_salesforce__run_soql_query` with:

- `usernameOrAlias`: the literal `<sf-username>` from Phase 0.
- `query`: `SELECT Id, Name, AmountAllOpportunities, AmountWonOpportunities, NumberOfLeads FROM Campaign WHERE Name LIKE '%<offer-slug>%' ORDER BY StartDate DESC LIMIT 100`

### Phase 4 — Read EB campaign stats (best-effort)

For each manifest with an `email_bison.campaign_id`, call `mcp__emailbison-b2b__get_campaign_stats` (or `mcp__emailbison-personal__get_campaign_stats` per the workspace field in the manifest). If EB is unreachable, set `eb_status=degraded`.

### Phase 5 — Invoke section composer

Save Phase 3 + Phase 4 results to temp JSON, then invoke the helper:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/offer_performance.py" \
  --offer-slug <offer_slug> \
  --campaigns-dir docs/campaigns \
  --canonicals-dir "${CLAUDE_PLUGIN_ROOT}/data/canonicals" \
  --eb-json "$eb_tmp" \
  --eb-status <ok|degraded> \
  --sf-json "$sf_tmp" \
  --sf-status <ok|degraded_auth|degraded_query|empty> \
  --command-version "marketing@$(python3 -c 'import json; print(json.load(open("plugins/marketing/.claude-plugin/plugin.json"))["version"])')"
```

### Phase 6 — Validate output

Assert the ONLY Write targets paths inside `docs/campaigns/{entity}/offers/{slug}/{version}/`. Emit stdout summary.

## Output shape

```markdown
---
schema_version: 1
generated_at: <ISO-8601 UTC>
command_version: marketing@<semver>
offer_slug: <slug>
entity: <entity>
vertical: <vertical>
posture: <posture>
versions_analyzed: <N>
---

# Offer Performance — <offer_slug>

## 1. Per-version metrics
| Version | Slug | Reply Rate | Meeting Rate | ... |

## 2. Cross-version comparison
(latest vs previous, with directional arrows)

## 3. Pipeline contribution
(sum AmountAllOpportunities + sum AmountWonOpportunities)

## 4. Retirement signal
(flag if N consecutive versions degrade; operator-only decision)
```

## Anti-creep guards

1. **No writes outside `docs/campaigns/{entity}/offers/{slug}/{version}/`.** The helper enforces this at runtime.
2. **No new metric definitions.** Every metric traces to campaign-analysis §3.3 or a pre-computed SF/EB field.
3. **No automated retirement decisions.** Flag only; operator decides.
4. **No cross-tenant rollup.** Single-entity per invocation (ADR-014).
5. **No forecast/chart sections.** Same boundary as BC-8731.

## Gotchas

- **SF `usernameOrAlias` must be a literal username.** Per `memory/gotcha_sf_mcp_username_not_alias.md`.
- **EB workspace per manifest.** Check `manifest.email_bison.workspace` to decide b2b vs personal.
- **BC-8719 short-entity-slug convention.** Use `labs/` not `brite-labs/`.

## References

- BC-8728 — this command's parent issue (T9-V)
- BC-8731 — `/marketing:portfolio-snapshot` (structural sibling; anti-creep pattern source)
- [V3 ratification outcome](../../../docs/v3-ratification-outcome-2026-05-22.md) — anti-creep guards
- [ADR-014](../../../docs/decisions/014-gtm-salesforce-portfolio-rollup.md) — SF as portfolio rollup home
- [vocabulary.md Section 5](handbook/marketing/frameworks/vocabulary.md) — canonical metric sources
