# 008. tam-mapping Enrichment Pluggability

**Status:** Accepted
**Date:** 2026-04-24
**Research:** `docs/research/tam-map-port-policy.md` § 3
**Linear:** [BC-5945](https://linear.app/brite-nites/issue/BC-5945)
**Blocks:** BC-5946, BC-5947, BC-5538

## Context

The tam-mapping skill (Tier 3.2, `plugins/marketing/skills/tam-mapping/`) performs a multi-phase TAM-construction pipeline. Phase 5–6 of the pipeline is an **enrichment waterfall** — given a discovered company, look up decision-maker contacts (email, mobile, title). Upstream Revgrowth1/tam-map ships this as a `BlitzAPI → Prospeo` direct waterfall using stdio MCP wrappers.

Brite has its own enrichment layer: a custom Python CLI at `services/enrichment/cli.py` in `brite-data-platform` wrapping 14 providers (Leadmagic, Prospeo, IcyPeas, BounceBan, and others). A dedicated MCP wrapper is tracked in BC-5537 (scaffold) / BC-5538 (production).

Three realities must coexist:

1. **Today:** brite-enrichment MCP does not exist. The CLI works.
2. **Near-term:** BC-5537 ships a minimal MCP wrapper.
3. **Mid-term:** BC-5538 ships the full 9-command MCP surface.

And one more:

4. **Always-optional:** upstream BlitzAPI waterfall may be preferred for verticals Brite's CLI under-serves, or as a fallback when Brite services are unavailable.

Without a pluggable interface, each transition (today → BC-5537 → BC-5538) risks re-litigating the enrichment contract. The tam-mapping skill also needs to work in mixed-repo setups where brite-enrichment may or may not be installed.

## Decision Drivers

- **No re-litigation.** The ADR locks the interface shape so downstream work can ship against a stable contract.
- **Swap without skill rewrite.** Switching providers should be a config change, not a code change.
- **Works pre-GA.** The interface must have a viable today-state (blitz waterfall) and a path to the preferred future state (brite-enrichment MCP).
- **Schema stability.** Downstream consumers (BC-2717 list-building, campaign-activation) must be able to trust the output record shape across provider swaps.
- **Explicit over implicit.** Selection mechanism should be discoverable in onboarding, not hidden in env-var sprawl.

## Decision

The tam-mapping skill selects its enrichment provider via a **`plugin.json` userConfig field** on the marketing plugin. All providers implement a shared **input/output record schema**. Provider-specific implementation details (API keys, rate limits, retry logic) live inside each provider's implementation and are not part of the interface contract.

### 1. Selection mechanism

Add to `plugins/marketing/plugin.json`:

```json
{
  "userConfig": {
    "enrichment_provider": {
      "type": "string",
      "enum": ["blitz_waterfall", "brite_cli", "brite_mcp", "skip"],
      "description": "Which enrichment provider tam-mapping uses. Unset → auto-detect."
    }
  }
}
```

**Enum semantics:**

| Value | Implementation |
|-------|---------------|
| `blitz_waterfall` | Upstream Revgrowth1/tam-map default. BlitzAPI → Prospeo via stdio MCP wrappers registered in `plugins/marketing/.mcp.json`. |
| `brite_cli` | Shell out to `services/enrichment/cli.py` in `brite-data-platform`. Requires `BRITE_DATA_PLATFORM` env var pointing to the repo checkout. Works today. |
| `brite_mcp` | Route the candidate list through the brite-enrichment MCP `bulk_enrich` bulk door (→ REST `/enrich/batch`, per ADR-017 in brite-data-platform) — never a per-company loop. Operative opt-in: the published `plugin_marketing_enrichment` server is pinned to a `bulk_enrich` SHA on Railway (BC-5316 / BC-13016, registered in `plugins/marketing/.mcp.json`) and granted in the `list-building` + `tam-mapping` `allowed-tools` (BC-13165). |
| `skip` | Pass candidate companies through unenriched. Downstream tools (BC-2717 list-building) handle enrichment separately. |

**Unset resolution order** (when `enrichment_provider` not configured):

1. Check for brite-enrichment MCP registration → use `brite_mcp`
2. Else check for brite-enrichment CLI at `$BRITE_DATA_PLATFORM/services/enrichment/cli.py` → use `brite_cli`
3. Else fall through to `blitz_waterfall`
4. `skip` is never auto-selected; it must be explicit.

> **Interim deviation (BC-6170 → BC-13165, choice-now-default-later).** The order above is the **target** end-state. `brite_mcp` is now an **operative opt-in** (granted in both skills' `allowed-tools`, BC-13165) but is still **removed from auto-detect** — reachable only by explicit flag / `userConfig`; auto-detect resolves to `brite_cli` (if present) else `blitz_waterfall`. Restoring step 1 (auto-selecting `brite_mcp` as the default) is the **default-flip**, deferred pending an engine-maturity sign-off. See Future Work below.

The resolved provider is logged at skill invocation so the user sees which path ran.

### 2. Input schema

All providers accept a list of records matching:

```typescript
interface EnrichmentInput {
  domain: string;              // required; canonical company domain
  company_name: string;        // required; display name
  linkedin_url?: string;       // optional; company or person LinkedIn URL if available
  title_seed?: string;         // optional; target role (e.g., "CEO", "Facilities Director") — used by providers that support title-targeted lookup
  geo?: string;                // optional; country or region filter
}
```

**Notes:**
- `domain` is canonical (no scheme, no www). Providers that receive a non-canonical domain must normalize before lookup.
- `title_seed` is a hint, not a filter. Providers may return the closest match even if the exact title isn't found.
- `geo` follows ISO 3166-1 alpha-2 when a country is intended (e.g., `"US"`, `"GB"`). Regional values use unambiguous shorthand (`"EU"`, `"APAC"`).

### 3. Output schema

All providers emit a list of records matching:

```typescript
interface EnrichmentOutput {
  email: string;               // required; lowercase, trimmed
  mobile?: string;             // optional; E.164 format preferred
  phone?: string;              // optional; office/landline; E.164 format preferred
  title?: string;              // optional; actual title returned by provider (may differ from title_seed)
  linkedin_url?: string;       // optional; LinkedIn URL for the contact
  confidence_score: number;    // required; 0.0 to 1.0 float
  source: string;              // required; provider identifier (e.g., "blitz_waterfall:prospeo", "brite_cli:icypeas")
  provider_raw?: object;       // optional; raw provider response for debug/audit
}
```

**Notes:**
- `confidence_score` is numeric (0.0–1.0 float). Providers that emit categorical confidence must map to numeric (e.g., provider "high" → 0.9, "medium" → 0.6, "low" → 0.3).
- `source` follows `<provider>:<sub-provider>` convention. The `<sub-provider>` tail is optional for single-provider implementations.
- `provider_raw` is never consumed by downstream tools; it exists for human debug and audit logs only.

### 4. Failure modes

Providers must handle these cases consistently:

- **No match found:** return an empty list for that input record. Do not throw.
- **API quota exceeded:** raise a typed error `EnrichmentQuotaExceededError`; the skill surfaces this to the user and offers to retry with a different provider.
- **API auth failure:** raise `EnrichmentAuthError`; the skill directs the user to the relevant onboarding doc.
- **Network timeout:** retry up to 3× with exponential backoff; after 3 failures, raise `EnrichmentNetworkError` with the last exception as `cause`.
- **Schema violation in provider response:** log a warning, drop the record, continue; do not fail the whole batch.

### 5. Smoke-test shape

Each provider implementation must ship a smoke test at `plugins/marketing/tests/enrichment/test_<provider>_smoke.py`. The smoke test:

1. Inputs one canonical record: `{ domain: "example.com", company_name: "Example Inc" }`.
2. Calls the provider with a mock or recorded fixture.
3. Asserts the output validates against the `EnrichmentOutput` schema.
4. Asserts `confidence_score` is a float in `[0.0, 1.0]`.
5. Asserts `source` starts with the provider's canonical identifier.

Smoke tests run in CI and on every `./scripts/validate.sh` invocation.

## Consequences

**Positive.**
- Swap path is explicit: change one userConfig value, no code change.
- Downstream consumers (BC-2717, campaign-activation) depend only on the output schema, not the provider.
- Schema extensions are gated behind this ADR, preventing drift.
- Missing-provider case (auto-detect → fall-through) keeps the skill usable in mixed-repo setups.

**Negative.**
- Provider-specific features (BlitzAPI's 5 req/s serialized rate limit, brite-cli's 14-provider internal waterfall) are hidden behind the interface; power-user access to provider internals requires dropping down to the underlying tool.
- The auto-detect resolution order adds implicit behavior that may surprise in edge cases (e.g., user has brite-cli installed but wants to test blitz_waterfall). Override via explicit userConfig is documented.
- `confidence_score` numeric precision is lossy for providers that emit categorical confidence (mapping "medium" → 0.6 is arbitrary). Users who need provider-native confidence should inspect `provider_raw`.

**Future work.**
- ~~When BC-5538 ships, flip the auto-detect order so `brite_mcp` is preferred and the CLI fallback is removed from auto-detect (but remains available as explicit config).~~ **Shipped as an operative opt-in (BC-6170 → BC-13165):** `brite_mcp` is now a **working selectable opt-in** in both `list-building` and `tam-mapping`, routed through the `bulk_enrich` bulk door (ADR-017, never a single-call loop). The **config-invariant pair is now satisfied:** (1) the published `plugin_marketing_enrichment` server is pinned to a `bulk_enrich` SHA on Railway (BC-5316 / BC-13016), and (2) the skills' `allowed-tools` grant landed (BC-13165) — keep the two in lockstep going forward (rolling the pin back to a SHA without `bulk_enrich` silently disables the opt-in; it degrades to the `blitz_waterfall` fall-through, not an error). **Still deferred — the auto-detect default-flip:** restoring step 1 of the Unset resolution order so `brite_mcp` is auto-preferred. It is gated on an **engine-maturity sign-off** (bulk-path robustness BC-13096 + throughput BC-6322). At the flip: restore step 1 and drop the interim-deviation note (the grant + server pin are already in place). (Gate re-pointed BC-5538 → BC-5316 → engine-maturity sign-off.)
- Schema amendment for intent signals (e.g., tech stack, funding round) can be added as optional output fields without breaking consumers.
- Extending to B2C/residential enrichment (for Brite Nites verticals) may require a separate ADR since the record shape differs (person-first vs company-first).
