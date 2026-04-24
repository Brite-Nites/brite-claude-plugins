# AI Ark Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

AI Ark is the **company-discovery layer** of the tam-map pipeline. Given a firmographic ICP (industry codes, employee band, geography), it returns a list of matching companies with website + LinkedIn + basic firmographics. It is step 1 of the 9-step upstream pipeline (see `plugins/marketing/references/tam/UPSTREAM.md`).

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` — **pending BC-5832**
- `plugins/marketing/scripts/tam-map/aiark_client.py` — ported Python wrapper
- `plugins/marketing/scripts/tam-map/aiark-mcp.js` — ported stdio MCP wrapper over the same API

## Auth

- **Credential type.** API key, passed as `Authorization: Bearer <AIARK_API_KEY>` by the upstream stdio wrapper.
- **Where it comes from.** [ai-ark.com](https://ai-ark.com) → account dashboard → API keys.
- **Scopes.** Account-wide read + search; no sub-scoping documented.
- **Env var.** `AIARK_API_KEY`.

**Do not commit credentials.** The `.mcp.json` snippet below uses `${AIARK_API_KEY}` as placeholder.

## Registration

AI Ark has no vendor MCP server. The upstream port ships a Node stdio wrapper (`scripts/tam-map/aiark-mcp.js`, ~4KB) that translates MCP calls into HTTP requests against the vendor API. Registration snippet — belongs in `plugins/marketing/.mcp.json` (pending BC-5947):

```json
{
  "mcpServers": {
    "aiark": {
      "command": "node",
      "args": ["./plugins/marketing/scripts/tam-map/aiark-mcp.js"],
      "env": {
        "AIARK_API_KEY": "${AIARK_API_KEY}"
      }
    }
  }
}
```

`.env.example` entry:

```
# Company discovery
AIARK_API_KEY=
```

The stdio transport + `env` block avoids the `${user_config.*}` header-substitution bug documented in `memory/gotcha_http_mcp_substitution_broken.md`.

## Tool inventory

The wrapper exposes a focused surface matching the tam-map pipeline need. Live inventory via `discover_tools` at runtime; at pinned commit `9f5c72e74b` the wrapper surfaces:

| Tool | Purpose | Notes |
|---|---|---|
| `search_companies` | Firmographic search (industries, employee band, geo) → list of companies | Primary call; paginated |
| `get_company` | Fetch full detail on one company by ID | Secondary; used for deep-dive lookups |

The wrapper's full surface may change with upstream syncs — re-run `discover_tools` after any pull.

## Rate limits

Vendor default: undocumented at the pinned SHA. The upstream wrapper does not impose client-side throttling; callers should treat 429 as the backpressure signal. Observed empirically at ~10 req/s on standard-tier accounts — verify against your plan on first use.

## Cost

AI Ark bills per company returned (credit-per-record model). Free-tier monthly caps are tight; production TAM runs (1000+ companies) require a paid plan. See [ai-ark.com/pricing](https://ai-ark.com) for current tiers. A single tam-map invocation at 1000-company TAM consumes ~1000 credits at the standard rate.

## Failure modes

- **Overly broad industry codes return 0 results.** AI Ark's taxonomy is narrower than NAICS — generic codes like "retail" or "technology" under-return. Symptom: empty company list despite wide firmographic aperture. Workaround: use the vendor's taxonomy browser (linked in dashboard) to find the exact code that maps to your vertical.
- **Geo filters require ISO-2 country codes, not names.** `"location": "Texas"` returns 0; `"location": {"country": "US", "regions": ["TX"]}` works. Symptom: silent zero-result. Workaround: always pass structured geo.
- **Pagination token expiry.** Tokens are bound to the initial query and may expire within 10 minutes. Symptom: mid-pagination 400 error. Workaround: issue pagination calls immediately after the initial call; don't stall.

## Retry

Treat 429 and 5xx as retryable with exponential backoff: base 2s, double per attempt, cap at 16s, 3 attempts max. For 400 on pagination (token expiry), abandon pagination and re-issue the root query. 401/403 is terminal — rotate the key.

## Brite usage

Invoked as **step 1** of `/marketing:tam-map <vertical>`. Brite passes firmographic filters sourced from the per-vertical ICP file (`plugins/marketing/references/vertical-playbooks/{vertical}-icp.md` — pending BC-5832), which contains industry codes + employee band + geography + persona seed titles. The response feeds step 2 (Spider.cloud crawl) and step 3 (Discolike lookalike expansion).

For Brite Labs verticals, Active-tier ones (zoos, aquariums) typically return 50–300 companies per ICP; Exploring-tier (casinos, hotels-resorts, ski-resorts, sports-stadiums) return 200–800. Expect pagination in all cases.

## Related skills

- **Primary consumers:** `tam-mapping` (pending BC-5832), `list-building` (pending BC-2717; would compose over tam-mapping).
- **Upstream / downstream:** AI Ark output feeds Spider.cloud (crawl), Discolike (lookalike expansion), IcyPeas (keyword search for overlapping coverage).
- **Alternatives:** Apollo.io (rejected — heavier, more expensive at discovery-phase volumes), Crunchbase Data (rejected — weaker firmographic filters), Clay (deprecated per `memory/project_clay_deprecated.md`).

## Last verified

2026-04-24 — Tool inventory verified from upstream `scripts/aiark-mcp.js` + `aiark_client.py` at commit `9f5c72e74b`. Not yet validated against live vendor API from a Brite install (blocked on BC-5947). Bump this date on first live validation.
