# Brite Enrichment Integration

> **Status — production, 5-tool surface.** The enrichment MCP exposes five tools:
> `check_enrichment_health`, `enrich_contacts`, `query_entity`, `ingest_enriched_contacts`
> (governed write-back, BC-12078), and `verify_emails` (BC-5538). The original
> "3-tool scaffold" (BC-5537) and "full 9-command surface" framings are retired — bulk
> enrichment and team-wide distribution are a **separate REST track** (BC-5264 / BC-5296),
> not in-MCP tools. Design rationale: `docs/research/brite-enrichment-mcp-findings.md`
> (BC-5536); write path + run-model governance: ADR-012 in `brite-data-platform`.
>
> **"Production" today = a single operator running the MCP locally with local credentials**
> (ADR-012 Addendum 2). The plugin-distributed install carries **no Snowflake credentials**,
> so only `check_enrichment_health` works there — see § Run model.

## Purpose

The enrichment MCP is the marketing plugin's surface onto Brite's own enrichment engine
(the Clay-style waterfall in
[`brite-data-platform`](https://github.com/Brite-Nites/brite-data-platform)). It lets a
skill discover decision-makers at a company and enrich them with a work email + phone,
**persist** what it found into the inventory, **verify** an email address it already has,
and read back what the golden records (`dim_companies` / `dim_people`) already know —
without shelling out to `python cli.py` or `snow sql`.

It is **not** "a finder that writes nothing." The real invariant is that **every staging
writer routes through the matcher** (BC-11907): `enrich_contacts` finds and returns
without writing; `ingest_enriched_contacts` is the *sanctioned* write-back that persists
finder output through `EntityMatcher` (so a contact we already hold is reused, not
duplicated) and stamps `entity_id_minted_by = enrichment_mcp/EntityMatcher`. `verify_emails`
judges a given address and persists no entity (it only logs a spend receipt). `query_entity`
reads golden records.

The MCP source is **co-located with the engine** at
`brite-data-platform/tools/enrichment-mcp/server.py` and imports the engine's ADR-008
contract types directly (`enrichment.contracts` / `enrichment.errors`).

## Consumed by

Skills/commands pre-wired to reference `mcp__plugin_marketing_enrichment__*`
(BC-5536 RQ9 audit). Listing an unregistered server causes silent runtime failure, so each
consumer adds the wildcard to its own `allowed-tools` as part of its activation issue.

| Consumer | Activation issue | Tools used | Satisfied today? |
|---|---|---|---|
| `situation-mining` | none — already declares the wildcard | `check_enrichment_health` + `query_entity` (firmographic fallback) | **Yes** |
| `list-building` | [BC-6170](https://linear.app/brite-nites/issue/BC-6170) | `check_enrichment_health` + `enrich_contacts` | Interactive only — **bulk waits on the REST batch door** (BC-5296) |
| `tam-mapping` | [BC-6170](https://linear.app/brite-nites/issue/BC-6170) | `check_enrichment_health` + `enrich_contacts` | Interactive only — bulk waits on BC-5296 |
| `icp-scoring` | [BC-8174](https://linear.app/brite-nites/issue/BC-8174) | `query_entity` (industry / employees / geo) | **Yes** (tool exists; consumer activates whenever) |
| `launch-campaign` | [BC-8173](https://linear.app/brite-nites/issue/BC-8173) | `verify_emails` (`is_deliverable` / `is_role` / `is_free` / `esp`) | **Yes — `verify_emails` shipped (BC-5538)** |

## Tool inventory (5 tools, production)

| Tool | Spend | Writes? | Call-time approval gate |
|---|---|---|---|
| `check_enrichment_health` | $0 | no | no |
| `query_entity` | $0 | no | no |
| `enrich_contacts` | provider $ | no (finder) | no (budget-gated) |
| `verify_emails` | provider $ | spend-receipt only | no (budget-gated) |
| `ingest_enriched_contacts` | $0 | **yes — staging** | **yes — never auto-allowlist** |

### `check_enrichment_health()` → dict

Availability probe (ADR 2c). Read-only, **$0** — makes no provider API calls. One cheap
Snowflake `SELECT 1` plus a recipe/provider/budget inventory. **Never raises** — reports
`snowflake_reachable: false` instead of throwing. Call once per session before any
spending or writing tool.

Returns: `ok` (true iff Snowflake reachable AND ≥1 recipe AND ≥1 provider configured),
`snowflake_reachable`, `recipes` / `recipe_count`, `providers_configured`, `budget`
(`daily_spend_usd`, `daily_budget_usd`, `remaining_usd`, `used_pct`, `block_new_enrichments`),
`mcp_version`, `engine_version`.

> `ok` does **not** reflect budget — budget exhaustion is recoverable and `query_entity`
> still works while it's blown. Inspect `budget.block_new_enrichments` separately (with
> null-safety: `budget` is `null` if the budget read failed).

### `enrich_contacts(domain, company_name, linkedin_url=None, title_seed=None, titles=None, geo=None, city=None, state=None)` → list[dict]

Discover decision-makers at a company and enrich each with a work email (+ best-effort
phone). One company per call. Returns one ADR-008 `EnrichmentOutput` (as a dict) per
candidate that yielded an email; empty list when none found. Each item has at least `email`
(str), `confidence_score` (float 0.0–1.0), `source` (str); optional `first_name` /
`last_name` / `mobile` / `phone` / `title` / `linkedin_url` / `provider_raw`. **Spends
provider credit.** Does **not** persist — pair with `ingest_enriched_contacts` to keep what
you found.

- **`titles`** (BC-12405) is the preferred targeting input: a **ranked list** of target
  roles, highest priority first. Both discovery providers receive the list, but **consume it
  differently** — Prospeo OR-matches the array (`match_mode: CONTAINS`), while OpenMart takes
  a single concise semantic title hint built from the highest-ranked entries, **not** a
  boolean OR. So a long multi-title list is fully OR-matched only by Prospeo; OpenMart leans
  on the top of the ranked list (see § Per-provider gotchas). **`title_seed`** is the legacy
  single-title form.
  Omit both to fall back to category defaults.
- **`city` / `state`** (BC-12405) scope discovery to a locality. (`geo` country is currently
  inert — BC-12420.)
- The per-company contact cap + ranking-sort are skill-layer concerns.

Raises `EnrichmentQuotaExceededError` (daily budget blown — raised *before* any provider
call), or `EnrichmentAuthError` / `EnrichmentNetworkError` from provider adapters (ADR-008).

### `verify_emails(email)` → dict

Verify a single email address you **already have**: deliverability + role/free + ESP. Wraps
two recipes — `email_validation` (BounceBan → deliverability + `is_role`/`is_free`) and
`email_provider` (EmailGuard → ESP). This **judges a given address**; it does not discover
new contacts (that's `enrich_contacts`) and persists no entity. **Spends ~$0.003/call**
(BounceBan ~$0.001 + EmailGuard ~$0.002).

Returns a flat dict:

```
{email, is_deliverable, is_role, is_free, esp, confidence_score, source}
```

- **`null` = unknown, `false` = a real negative verdict.** `is_deliverable` is `true` only
  for an exact `"deliverable"` verdict, `false` only for `"undeliverable"`, and `null` for
  anything else (risky / catch-all / unknown / no verdict). `is_role` / `is_free` are
  concrete booleans whenever BounceBan answered, else `null`. `esp` is `null` when EmailGuard
  finds no host.
- **Both providers always run.** A `NO_DATA` return from either yields a partial dict (its
  fields `null`), never a raise. `confidence_score` is BounceBan's deliverability confidence
  (0–1), `null` if no verdict. `source` is `"brite-enrichment:bounceban"`.
- **Input guard:** an address without a `local@domain` shape raises `ValueError` **before**
  any spend. **No call-time approval gate** (single-email validation is not Bison-class) —
  but the daily budget gate still applies.
- Spend is logged to `ENRICHMENT_ATTEMPTS` under a domain-only `mcp_verify::<domain>`
  placeholder (PII-safe; the attempts table is a spend log, never a matching key) so the
  budget gate sees validation spend.

Raises `EnrichmentQuotaExceededError`, or `EnrichmentAuthError` / `EnrichmentNetworkError`
from provider adapters (ADR-008).

### `query_entity(domain=None, entity_id=None, include_persons=True)` → dict | None

Look up a canonical company golden record + linked person rows. Read-only, **$0** — reads
`dim_companies` (+ `dim_people` when `include_persons`) from the marts. Provide exactly one
of `domain` or `entity_id`. Returns the entity dict or `None` if no company matches; raises
`ValueError` if neither or both identifiers are given. People are linked by `domain`
(BC-12041), so shared chain/franchise domains return all contacts at that domain.

> Reads the marts, which dbt rebuilds on the **nightly** schedule — so a contact you just
> persisted via `ingest_enriched_contacts` does **not** appear here until the next build (see
> § Freshness).

### `ingest_enriched_contacts(domain, company_name, contacts)` → dict

The governed **write-back** (BC-12078): persist the `enrich_contacts` output into the
golden-record inventory. Each contact is routed through `EntityMatcher` (a contact we already
hold reuses its `entity_id` instead of duplicating) and stamped
`entity_id_minted_by = enrichment_mcp/EntityMatcher`. Persisting also records the result so
the same contact isn't paid-for again. **$0 provider cost** — the spend already happened in
`enrich_contacts`. Persists EVERYTHING handed to it (no deliverability filter — campaign
readiness is the audience-view layer's job). Returns `{persisted, skipped, total}`.

Raises `pydantic.ValidationError` (a contact missing the required `email`), or
`MatcherHydrationError` (the per-domain matcher cache failed to load — fail-loud, never
dedups against an empty cache).

#### Write-back governance — *referenced, locked elsewhere; do not re-decide here*

- **Call-time human approval (required).** `ingest_enriched_contacts` must hit Claude Code's
  native tool-permission prompt on every call — **never add it to an auto-approve
  allowlist** (ADR-012 Decision 5). This is the confused-deputy / prompt-injection guard. The
  read/finder/verify tools stay freely callable.
- **Provenance-stamped + matcher-governed.** Writes are not arbitrary — matcher-routed,
  `entity_id_minted_by`-stamped (BC-11907 provenance allowlist warn-test).
- **Staging, not the golden record.** Writes land in `RAW.PIPELINE_ENRICHMENT` staging;
  `dim_*` are re-derived by dbt with its own governance.
- **Detectable + recoverable.** Soft-delete, snapshots, dedup detectors, provenance test.
- **Least-privilege + independently revocable** identity (`ENRICHMENT_MCP_WRITER`).

## Run model (credentials)

There are **three** configurations; only the **local-creds v1** is fully functional today.

### 1. v1 — single-operator local run (the working config; ADR-012 Addendum 2)

The fully-working setup: a **locally-run `server.py`** (not the plugin-installed
distribution) driven by a Claude Code session, with credentials in
`brite-data-platform/tools/enrichment-mcp/.env.local`:

- **Provider API keys** (sourced from `brite-data-platform/services/.env`).
- **The `ENRICHMENT_MCP` Snowflake identity** — key-pair auth, private key local at
  `~/.snowflake/enrichment_mcp_keys/rsa_key.p8` (chmod 600), role `ENRICHMENT_MCP_WRITER`.
- **`MARTS_DATABASE=ANALYTICS`** (the config default is `DEV`, which reads empty marts and
  looks broken) + `USE_MOCK_PROVIDERS=false`.

This is acceptable **only** for the single operator who is already `ACCOUNTADMIN`
(strictly more power than `ENRICHMENT_MCP_WRITER`: INSERT/UPDATE on three staging tables, no
DDL/DELETE/mart-write). **No** Bitwarden item, **no** `bw-run.sh` key injection, **no** plugin
`.mcp.json` `SNOWFLAKE_*` wiring.

### 2. Plugin-distributed install — health-only until REST

The plugin ships an `enrichment` entry in `plugins/marketing/.mcp.json` that fetches the
engine via `uvx` from a pinned SHA and injects only the **7 provider keys** via `bw-run.sh`
(the broker the tam-map servers use). It carries **no Snowflake credentials** — so every
Snowflake-touching tool (`query_entity`, the budget gate inside `enrich_contacts`/`verify_emails`,
and `ingest_enriched_contacts`) cannot run there; only `check_enrichment_health` works (it
reports `snowflake_reachable: false`). Putting a production write key on every laptop was
**withdrawn** (ADR-012 Addendum 1) — do not wire `SNOWFLAKE_*` into `.mcp.json`.

| Env var | Bitwarden item | Provider role |
|---|---|---|
| `OPENMART_API_KEY` | `enrichment-openmart-api-key` | people discovery |
| `PROSPEO_API_KEY` | `enrichment-prospeo-api-key` | discovery + email + phone |
| `ICYPEAS_API_KEY` | `enrichment-icypeas-api-key` | work-email waterfall |
| `LEADMAGIC_API_KEY` | `enrichment-leadmagic-api-key` | email + phone |
| `DATAGMA_API_KEY` | `enrichment-datagma-api-key` | phone fallback |
| `BOUNCEBAN_API_KEY` | `enrichment-bounceban-api-key` | email deliverability (`verify_emails`) |
| `EMAILGUARD_API_KEY` | `enrichment-emailguard-api-key` | ESP detection (`verify_emails`) |

### 3. End state — server-side REST custody (BC-5264)

The one Snowflake write credential moves to a single server-side service (the REST
enrichment surface, `POST /enrich/contact` + `/enrich/batch`); the MCP becomes a thin client
holding **no** DB key. **Flip-triggers that make this mandatory** (ADR-012 Addendum 2): a
second operator, any deployed/hosted/unattended run, any multi-user surface, or the
plugin-installed distribution carrying the write key. Until one fires, v1 local creds are
fine.

## Confirmation gates

- **`ingest_enriched_contacts`** — call-time human approval, always (above). Never
  auto-allowlist.
- **`enrich_contacts` / `verify_emails`** — no per-call approval (no Bison-class batch
  multiplier; one visible tool call each). Guarded by the **engine daily budget gate**: each
  calls `check_enrichment_budget()` first and raises `EnrichmentQuotaExceededError` (with
  `daily_spend_usd` / `daily_budget_usd`) before touching any provider once the daily budget
  is exhausted. Surface that as "daily enrichment budget exhausted ($X/$Y) — increase budget
  or retry tomorrow."
- **`check_enrichment_health` / `query_entity`** — free, no gate.

Bulk (a real batch multiplier) is the REST track (BC-5296), not an in-MCP tool.

## Common workflows

### Find → keep (enrich then persist)

1. `check_enrichment_health()` → if `ok: false`, fall back to the skill's non-MCP path; if
   `budget.block_new_enrichments: true`, warn and pause.
2. `enrich_contacts(domain="example.com", company_name="Example Co", titles=["Director of Facilities", "Owner"], city="Austin", state="TX")` → list of contacts.
3. **Approve the write prompt**, then `ingest_enriched_contacts(domain="example.com", company_name="Example Co", contacts=<the list from step 2>)` → `{persisted, skipped, total}`.

### Validate an address before outreach

`verify_emails("info@example.com")` → `{is_deliverable, is_role, is_free, esp, …}`. Gate a
send on `is_deliverable is true` and (for personalized outreach) `is_role is false`; treat
`null` as "unknown — don't assume deliverable."

### Read what we already know

`query_entity(domain="example.com")` → existing canonical company + linked people (by
domain). $0.

## Rate limits and quotas

- `enrich_contacts` — **typical ~$0.20/company, worst case ~$0.50** (5 candidates, every
  waterfall falls through): people discovery (Openmart, ≤5) ~$0.10; per candidate email
  waterfall (IcyPeas $0.01 → Prospeo $0.02 → LeadMagic $0.03) + phone (LeadMagic $0.03 →
  Prospeo $0.02 → Datagma $0.05).
- `verify_emails` — **~$0.003/call** (BounceBan ~$0.001 + EmailGuard ~$0.002).
- `check_enrichment_health` / `query_entity` / `ingest_enriched_contacts` — **$0**.
- Daily ceiling: the engine's `enrichment_daily_budget_usd` (default $50), enforced by the
  budget gate.

## Freshness (eventually-consistent marts)

`ingest_enriched_contacts` writes **staging** (`RAW.PIPELINE_ENRICHMENT`); `query_entity`
reads the **marts** (`dim_companies` / `dim_people`), which dbt rebuilds on the nightly
schedule. So a freshly-persisted contact does **not** appear in `query_entity` until the next
build — the golden record lags staging. The MCP does **not** trigger a dbt build (v1 accepts
the lag). Verify a just-written contact at the staging layer, not via `query_entity`.

## Per-provider gotchas

| Provider | Used by | Gotcha |
|---|---|---|
| **BounceBan** | `verify_emails` (`email_validation`) | Returns `result` ∈ `deliverable`/`undeliverable`/risky/etc. `verify_emails` maps only exact `deliverable`/`undeliverable` to `true`/`false`; everything else → `null`. A disposable address comes back `undeliverable`. `score` (0–100) → `confidence_score` (÷100). |
| **EmailGuard** | `verify_emails` (`email_provider`) | Returns only the ESP host; emits **no confidence** (deterministic from MX). Returns `NO_DATA` (→ `esp: null`) when it can't resolve a host — still bills. |
| **OpenMart** | `enrich_contacts` (people discovery) | SMB-oriented; takes a **single semantic title string** (no boolean OR) — the engine builds it from the highest-ranked `titles`, so a long list is not fully OR-matched here (it is by Prospeo). Returns name + email + phone in one call (the email short-circuits the work-email waterfall). |
| **Prospeo** | `enrich_contacts` (discovery + email + phone) | `person_job_title.include` is an OR-array (use `match_mode: CONTAINS`). **Never hardcode a `person_seniority` filter** — it AND-combines with title and silently drops matches (BC-12405). |
| **IcyPeas / LeadMagic / Datagma** | `enrich_contacts` (email/phone waterfall) | Waterfall stops at first hit; a provider left unconfigured is skipped (not a failure) so a partial roster still enriches. A runtime 401 from a *configured* provider propagates. |

## Known gotchas

- **Stale engine wheel on a local run.** A local `uvx --from tools/enrichment-mcp` (or the
  MCP venv) can serve a **stale wheel** missing recent engine code → add
  `--reinstall-package brite-data-services` (or `uv sync --reinstall-package brite-data-services`
  in `tools/enrichment-mcp`) after pulling engine changes; pre-flight with
  `python -c "import server"`.
- **`MARTS_DATABASE=ANALYTICS`.** The config default is `DEV`, which reads empty marts and
  makes `query_entity` look broken. The local run must set `ANALYTICS`.
- **Bumping the pinned SHA (distributed plugin).** `.mcp.json` pins the engine to a git SHA,
  so engine fixes don't auto-propagate; update `@<pinned-sha>`, bump the plugin version, and
  fully restart Claude Code. (Not relevant to the v1 local run, which uses the live source.)
- **`bw-run.sh` fails closed.** One missing/misspelled vault item = the whole MCP won't start
  (exit 3), not a graceful per-provider skip. Confirm a vault item exists before adding its row.
- **Restart, don't `/reload-plugins`.** MCP server processes keep the previous version's
  env/path until a full Claude Code restart.

## Related skills

- `situation-mining` — tertiary firmographic fallback (already declares the wildcard).
- `list-building` / `tam-mapping` — `enrich_contacts` interactively; bulk awaits the REST
  batch door ([BC-6170](https://linear.app/brite-nites/issue/BC-6170) / BC-5296).
- `icp-scoring` — `query_entity` for firmographic lookup
  ([BC-8174](https://linear.app/brite-nites/issue/BC-8174)).
- `launch-campaign` — uses `verify_emails` for per-email validation
  ([BC-8173](https://linear.app/brite-nites/issue/BC-8173)).

## Last verified

- **2026-06-05 (BC-5538)** — `verify_emails` shipped + smoke-tested live (local-creds v1,
  `USE_MOCK_PROVIDERS=false`): a role inbox → `is_role: true`, `esp` set, `confidence: 0.99`;
  a free-provider address → `is_free: true`, `esp: "Google"`; malformed inputs rejected before
  spend; spend receipts landed in `ENRICHMENT_ATTEMPTS` under `mcp_verify::<domain>`. Engine
  PR [#209](https://github.com/Brite-Nites/brite-data-platform/pull/209).
- **2026-06-04** — Full v1 round-trip proven end-to-end through the locally-run server
  (`check_enrichment_health` → `enrich_contacts` → `ingest_enriched_contacts` →
  `query_entity`) as `ENRICHMENT_MCP` / `ENRICHMENT_MCP_WRITER` (ADR-012 Addendum 2).
- **2026-05-29** — Scaffold registration landed (BC-5537). The plugin-distributed install
  runs `check_enrichment_health` only (no Snowflake creds by design).
