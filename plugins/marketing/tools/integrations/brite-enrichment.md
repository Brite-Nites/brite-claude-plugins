# Brite Enrichment Integration

> **SCAFFOLD SCOPE (BC-5537).** This is the 3-tool MVP surface — `check_enrichment_health`,
> `enrich_contacts`, `query_entity`. The full 9-command surface (per-email validation,
> bulk enrichment, raw recipe runs, audience-view reads) is deferred to
> [BC-5538](https://linear.app/brite-nites/issue/BC-5538). Design rationale for every
> decision below lives in `docs/research/brite-enrichment-mcp-findings.md` (BC-5536).

## Purpose

The enrichment MCP is the marketing plugin's read/finder surface onto Brite's own
enrichment engine (the Clay-style waterfall that lives in
[`brite-data-platform`](https://github.com/Brite-Nites/brite-data-platform)). It lets a
skill discover decision-makers at a company and enrich them with a work email + phone,
and read back what the golden records (`dim_companies` / `dim_people`) already know —
without shelling out to `python cli.py` or `snow sql`.

It is a **stateless finder**: `enrich_contacts` discovers and returns contacts;
`query_entity` reads existing records. Neither writes to the enrichment inventory —
growing the golden record stays the job of the CSV ingest pipeline, which owns
matcher/dedup. That separation is deliberate (BC-5536 RQ6).

The MCP source is **co-located with the engine** at
`brite-data-platform/tools/enrichment-mcp/server.py` and imports the engine's ADR-008
contract types directly (`enrichment.contracts` / `enrichment.errors`). The plugin ships
only the `.mcp.json` entry that fetches and runs it via `uvx` from a pinned git SHA — see
§ Registration.

## Consumed by

Five skills/commands are pre-wired to reference `mcp__plugin_marketing_enrichment__*`
(BC-5536 RQ9 audit). Only `situation-mining` declares the wildcard in `allowed-tools`
today; the other four add it as part of their own activation issue, because listing an
unregistered server causes silent runtime failure.

| Consumer | Activation issue | Day-1 tools used | Satisfied by MVP? |
|---|---|---|---|
| `situation-mining` | none — already declares the wildcard | `check_enrichment_health` + `query_entity` (firmographic fallback) | **Yes** |
| `list-building` | [BC-6170](https://linear.app/brite-nites/issue/BC-6170) | `check_enrichment_health` + `enrich_contacts` (replaces `blitz_waterfall`) | **Yes** |
| `tam-mapping` | [BC-6170](https://linear.app/brite-nites/issue/BC-6170) | `check_enrichment_health` + `enrich_contacts` | **Yes** |
| `icp-scoring` | [BC-8174](https://linear.app/brite-nites/issue/BC-8174) | `query_entity` (industry / employees / geo) | **Yes** (tool exists; consumer activates whenever) |
| `launch-campaign` | [BC-8173](https://linear.app/brite-nites/issue/BC-8173) | per-email `is_role` / `is_free` validation | **No — waits on BC-5538** (by design) |

## Auth

**Two credential tiers, two different sources** (BC-5536 RQ5):

1. **Provider API keys (7) — Bitwarden broker.** The `.mcp.json` `command` is
   `${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh`, the same broker the tam-map servers
   (spider / aiark / discolike) use. Each `KEY=vault-item` arg before the `--` tells the
   broker to fetch that Bitwarden item and export it under that env-var name. Items live
   in the Engineering collection:

   | Env var | Bitwarden item | Provider role |
   |---|---|---|
   | `OPENMART_API_KEY` | `enrichment-openmart-api-key` | people discovery |
   | `PROSPEO_API_KEY` | `enrichment-prospeo-api-key` | discovery + email + phone |
   | `ICYPEAS_API_KEY` | `enrichment-icypeas-api-key` | work-email waterfall |
   | `LEADMAGIC_API_KEY` | `enrichment-leadmagic-api-key` | email + phone |
   | `DATAGMA_API_KEY` | `enrichment-datagma-api-key` | phone fallback |
   | `BOUNCEBAN_API_KEY` | `enrichment-bounceban-api-key` | email deliverability |
   | `EMAILGUARD_API_KEY` | `enrichment-emailguard-api-key` | ESP / provider detection |

   The vault items must be Bitwarden **Login** type with the key in the **password**
   field — `bw-run.sh` reads `.login.password` and rejects other item types.

2. **Snowflake login — your shell profile.** The engine reads `SNOWFLAKE_*` env vars
   (via Pydantic Settings) to reach the warehouse. The MCP runs from an arbitrary cwd,
   so it does **not** read `brite-data-platform/services/.env` — those vars must be in
   the environment Claude Code itself launches from. `bw-run.sh` preserves the
   surrounding shell env, so anything exported in `~/.zshrc` flows through. Required:

   ```sh
   export SNOWFLAKE_ACCOUNT=...            # VKTQGEV-JBB38319
   export SNOWFLAKE_USER=...               # your engine Snowflake user
   export SNOWFLAKE_ROLE=...               # e.g. DATA_ENGINEER
   export SNOWFLAKE_WAREHOUSE=...          # e.g. TRANSFORMING_WH / REPORTING_WH
   export SNOWFLAKE_PRIVATE_KEY_PATH=...   # key-pair auth (preferred); OR
   # export SNOWFLAKE_PASSWORD=...         # password auth fallback
   ```

   The exact values mirror what's already in `brite-data-platform/services/.env`.

**Per-provider toolset gating (BC-5536 RQ5).** A provider is "enabled" only when its
key is present and non-empty; `check_enrichment_health` reports `providers_configured`
so a skill can see what's live. A missing key degrades that one provider gracefully —
**but only if it was left off the broker list.** If you list a `KEY=vault-item` whose
vault item does not exist, `bw-run.sh` fails closed and the whole MCP won't start (see
§ Known gotchas). That's why the scaffold lists exactly the 7 keys we've confirmed in the
vault; add more only after confirming each item exists.

### One-time per-dev onboarding

1. **Bitwarden CLI + session.** Install (`brew install bitwarden-cli` or
   `npm install -g @bitwarden/cli`), `bw login`, then `bw unlock` and export the
   printed `BW_SESSION` in the shell you launch Claude Code from. (Known issue: very
   recent CLI builds can fail `bw unlock` with a `bitwarden_crypto` "decryption
   operation failed" error even when the password is correct — pin an older build, e.g.
   `npm install -g @bitwarden/cli@2025.7.0`, and re-`bw login`.)
2. **Vault items.** Confirm the 7 `enrichment-*-api-key` Login items exist in the
   Engineering collection (`bw list items --search "enrichment-" | jq -r '.[].name'`).
3. **Snowflake env.** Add the `SNOWFLAKE_*` exports above to your shell profile.
4. **`uv`.** Already a Brite dev prereq; `uvx` resolves the engine package on first run.
5. **Reload.** Fully restart Claude Code (not `/reload-plugins`) so the MCP process
   spawns with the new env, then approve the `enrichment` server when prompted.

## Registration

Plugin-scoped in `plugins/marketing/.mcp.json` (the stdio + broker pattern works
plugin-scoped — the BC-5551 Email Bison limitation only affected *HTTP*-type servers
with env-vars in headers). The server key MUST be literally `enrichment` so tools resolve
to `mcp__plugin_marketing_enrichment__*`.

```json
"enrichment": {
  "type": "stdio",
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh",
  "args": [
    "OPENMART_API_KEY=enrichment-openmart-api-key",
    "PROSPEO_API_KEY=enrichment-prospeo-api-key",
    "ICYPEAS_API_KEY=enrichment-icypeas-api-key",
    "LEADMAGIC_API_KEY=enrichment-leadmagic-api-key",
    "DATAGMA_API_KEY=enrichment-datagma-api-key",
    "BOUNCEBAN_API_KEY=enrichment-bounceban-api-key",
    "EMAILGUARD_API_KEY=enrichment-emailguard-api-key",
    "--",
    "uvx", "--from",
    "git+https://github.com/Brite-Nites/brite-data-platform@<pinned-sha>#subdirectory=tools/enrichment-mcp",
    "brite-enrichment-mcp"
  ],
  "env": {
    "USE_MOCK_PROVIDERS": "False",
    "MARTS_DATABASE": "ANALYTICS",
    "MARTS_SCHEMA": "MARTS"
  }
}
```

The `env` block carries the three **non-secret** settings that are identical for every
dev: real providers (not mocks) and the production marts location for `query_entity`.

## Tool inventory

**SCAFFOLD scope — 3 tools.** Full surface deferred to
[BC-5538](https://linear.app/brite-nites/issue/BC-5538).

### `check_enrichment_health()` → dict

Availability probe (ADR 2c). Read-only, **$0** — makes no provider API calls. One cheap
Snowflake `SELECT 1` round-trip plus a recipe/provider/budget inventory. **Never raises**
— reports `snowflake_reachable: false` instead of throwing. Call once per session before
any mutating tool.

Returns: `ok` (true iff Snowflake reachable AND ≥1 recipe AND ≥1 provider configured),
`snowflake_reachable`, `recipes` / `recipe_count`, `providers_configured`, `budget`
(`daily_spend_usd`, `daily_budget_usd`, `remaining_usd`, `used_pct`,
`block_new_enrichments`), `mcp_version`, `engine_version`.

> `ok` does **not** reflect budget — budget exhaustion is recoverable and `query_entity`
> still works while it's blown. Inspect `budget.block_new_enrichments` separately (with
> null-safety: `budget` is `null` if the budget read failed).

### `enrich_contacts(domain, company_name, linkedin_url=None, title_seed=None, geo=None)` → list[dict]

Discover decision-makers at a company and enrich each with a work email (+ best-effort
phone). One company per call — a skill enriching N companies calls it N times. Returns
one ADR-008 `EnrichmentOutput` (as a dict) per candidate that yielded an email; empty
list when none found. Each item has at least `email` (str), `confidence_score` (float
0.0–1.0), `source` (str); optional `first_name` / `last_name` (carried from discovery
when the provider returns them) / `mobile` / `phone` / `title` / `linkedin_url` /
`provider_raw`. **Spends provider credit** — see § Rate limits.

`title_seed` filters discovery to the role you want (e.g. `"Director of Facilities"`).
The title cascade + per-company contact cap are skill-layer concerns, not engine features.

Raises `EnrichmentQuotaExceededError` (daily budget blown — raised *before* any provider
call), or `EnrichmentAuthError` / `EnrichmentNetworkError` from provider adapters
(ADR-008).

### `query_entity(domain=None, entity_id=None, include_persons=True)` → dict | None

Look up a canonical company golden record + linked person rows. Read-only, **$0** — reads
`dim_companies` (+ `dim_people` when `include_persons`) from the marts. Provide exactly
one of `domain` or `entity_id`. Returns the entity dict or `None` if no company matches;
raises `ValueError` if neither or both identifiers are given.

> MVP returns what `dim_companies` surfaces today. The `icp_fit` / `persona_fit` /
> `business_vertical` columns that icp-scoring's full activation wants are a separate M49
> follow-up, not an MVP blocker.

## Common workflows

### Enrich a single company end-to-end (3 MCP calls)

1. **Probe.** `check_enrichment_health()` → if `ok: false` or it raises, fall back to the
   skill's non-MCP path (e.g. list-building's `blitz_waterfall`); if
   `budget.block_new_enrichments: true`, warn the operator and pause before step 2.
2. **Enrich.** `enrich_contacts(domain="example.com", company_name="Example Co",
   title_seed="Director of Facilities")` → list of contacts, each with `email` +
   `confidence_score`.
3. **Confirm against golden record (optional).**
   `query_entity(domain="example.com")` → existing canonical company + known people, to
   dedup or enrich what you just found.

## MCP confirmation gates

**None in the MVP** (BC-5536 RQ8). `enrich_contacts` is one-company-per-call with no
batch multiplier, so there's no Bison-class runaway risk; every call is one visible tool
call in the session log. The real floor is the **engine-level daily budget gate**:
`enrich_contacts` calls `check_enrichment_budget()` first and raises
`EnrichmentQuotaExceededError` (with `daily_spend_usd` / `daily_budget_usd`) before
touching any provider once the daily budget is exhausted. Surface that to the operator as
"daily enrichment budget exhausted ($X/$Y) — increase budget or retry tomorrow."

When BC-5538 adds `bulk_enrich_contacts` (a real batch multiplier) it will need the
two-call Bison-style gate + `estimate_recipe_cost`.

## Rate limits and quotas

`enrich_contacts` is the only billable tool. Worst-case-cost per single-company call
(BC-5536 RQ8), default `people_discovery` → `work_email_waterfall` → `phone_discovery`:

- people discovery (Openmart, ≤5 candidates): ~$0.10
- per candidate: email waterfall (IcyPeas $0.01 → Prospeo $0.02 → LeadMagic $0.03, stops
  at first hit) + phone waterfall (LeadMagic $0.03 → Prospeo $0.02 → Datagma $0.05)
- **typical ~$0.20/company; worst case ~$0.50/company** (5 candidates, every waterfall
  falls through)

`check_enrichment_health` and `query_entity` are **$0**. The daily ceiling is the engine's
`enrichment_daily_budget_usd` (default $50), enforced via the budget gate above.

## Known gotchas

- **Bumping the pinned SHA.** The `.mcp.json` pins the engine to a git SHA, so engine
  fixes do **not** auto-propagate. When an engine PR the MCP depends on merges, update
  the `@<pinned-sha>` in `plugins/marketing/.mcp.json`, bump the plugin version, and have
  devs fully restart Claude Code. This is intentional — deterministic, auditable, no
  silent contract drift.
- **`bw-run.sh` fails closed.** One missing/misspelled vault item = the entire MCP won't
  start (exit 3), not a graceful per-provider skip. Graceful degradation only applies to
  providers left *off* the broker list. Confirm a vault item exists before adding its row.
- **Snowflake env, not `.env`.** The MCP runs from a `uvx` temp dir and never reads
  `services/.env`. `SNOWFLAKE_*` must be exported in the shell Claude Code launches from,
  or `check_enrichment_health` reports `snowflake_reachable: false` and `query_entity`
  fails.
- **First-launch latency.** The first `uvx` run for a given SHA clones the repo and builds
  the package (tens of seconds). Subsequent launches use the uv cache.
- **`load_all_recipes` is all-or-nothing.** The health tool loads recipes individually and
  skips non-recipe YAML (e.g. `title_mapping.yml`) on purpose — the engine's
  `load_all_recipes` raises on the first non-recipe file. (Tracked engine-side.)
- **Restart, don't `/reload-plugins`.** MCP server processes keep the previous version's
  env/path until a full Claude Code restart.

## Related skills

- `situation-mining` — tertiary firmographic fallback (already declares the wildcard).
- `list-building` / `tam-mapping` — swap `blitz_waterfall` → `enrich_contacts` on
  activation ([BC-6170](https://linear.app/brite-nites/issue/BC-6170)).
- `icp-scoring` — `query_entity` for firmographic lookup on activation
  ([BC-8174](https://linear.app/brite-nites/issue/BC-8174)).
- `launch-campaign` — per-email validation swap waits on BC-5538
  ([BC-8173](https://linear.app/brite-nites/issue/BC-8173)).

## Last verified

- **2026-05-29** — Scaffold registration landed (BC-5537 plugins-side). Engine half:
  `brite-data-platform` PR #181, pinned SHA `6854446`. All three tools smoke-tested live
  against real Snowflake + providers (`USE_MOCK_PROVIDERS=False`):
  - `check_enrichment_health` → `ok=true`, Snowflake reachable, 13 recipes, providers
    configured, budget $0/$50.
  - `query_entity` → correct BC-10202 shape + linked people on a single-company domain
    (chain/shared-domain people-linking under-reports — tracked at BC-12041).
  - `enrich_contacts` → live discovery + email/phone waterfall returned ADR-008-shaped
    contacts (`email: str`, `confidence_score: float`, `source: str`) via openmart +
    leadmagic.
  - Vault → broker path verified: `bw-run.sh` delivered all 7 provider keys.
  - `uvx` build from the pinned SHA confirmed resolvable on a clean checkout.

  The functional smoke ran the registered command directly (broker + `uvx` + engine).
  In-session tool resolution (`mcp__plugin_marketing_enrichment__*`) verifies once the
  plugin update lands on `main` and Claude Code reloads.
