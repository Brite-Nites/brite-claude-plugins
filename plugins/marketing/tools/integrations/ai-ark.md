# AI Ark Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

AI Ark is the **company-discovery layer** of the tam-map pipeline. Given a firmographic ICP (industry codes, employee band, geography), it returns a list of matching companies with website + LinkedIn + basic firmographics. It is step 1 of the 9-step upstream pipeline (see `plugins/marketing/references/tam/UPSTREAM.md`).

> **Verified 2026-05-11 (BC-7011); `account` sub-schema verified 2026-05-31 (BC-7157).** Endpoint surface and auth confirmed against `docs.ai-ark.com/reference/company-search-1` and `docs.ai-ark.com/docs/authentication`. The pre-BC-7011 wrapper was a "conventional-guess" port that returned nginx 404 in production (BC-6906 Stage 2b); paths, auth header, and request shape were corrected in `plugins/marketing/scripts/tam-map/aiark-mcp.js`. BC-7157 then mapped the `account` filter interior: each `AccountFilter` field is an `all`/`any` → `include`/`exclude` **object** tree (sourced from the OpenAPI spec embedded in `…/company-search-1.md`), so bare `string[]`/scalars 400 as "request not readable". Unknown sub-field *names* are still silently ignored (return the unfiltered default).

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` (BC-5832) — Phase 3c Labs collection (firmographic discovery)
- `plugins/marketing/scripts/tam-map/aiark_client.py` — ported Python wrapper
- `plugins/marketing/scripts/tam-map/aiark-mcp.js` — ported stdio MCP wrapper over the same API

## Auth

- **Credential type.** API key, passed as `X-TOKEN: <AIARK_API_KEY>` (no `Bearer` prefix) per `docs.ai-ark.com/docs/authentication`.
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

The wrapper registers two tools (see `plugins/marketing/scripts/tam-map/aiark-mcp.js`). Both hit `POST https://api.ai-ark.com/api/developer-portal/v1/companies`; the lookalike behavior is driven by which body field is populated.

| Tool | Purpose | Required args | Optional args | Upstream endpoint (verified 2026-05-11) |
|---|---|---|---|---|
| `aiark_search` | Firmographic search (industry / geo / size-band) → list of companies | — | `industries[]`, `regions[]`, `employee_min`, `employee_max`, `limit` (default 100, max 100) | `POST /api/developer-portal/v1/companies` — body `{account, page, size}`. Wrapper maps (BC-7157): `industries[]`→`account.industries.any.include={mode:"WORD",content:[…]}`; `regions[]`→`account.location.any.include=[…]`; `employee_min/max`→`account.employeeSize={type:"RANGE",range:[{start,end}]}` |
| `aiark_similarity` | Lookalike expansion from a seed list of up to 5 domains | `seed_domains[]` (≤5) | `limit` (default 100, max 100) | `POST /api/developer-portal/v1/companies` — body `{lookalikeDomains, page, size}` |

`aiark_enrich` was removed in BC-7011: AI Ark has no domain-keyed enrich endpoint as of 2026-05-11 (verified against `docs.ai-ark.com/reference` and `help.ai-ark.com/en/articles/112`). The closest documented surface is Reverse People Lookup (email→person, not domain→company). Re-add if upstream ships a real endpoint.

No `search_companies` or `get_company` tool exists — earlier drafts of this guide listed those names; they were incorrect.

## Rate limits

Vendor default: undocumented at the pinned SHA. The upstream wrapper does not impose client-side throttling; callers should treat 429 as the backpressure signal. Observed empirically at ~10 req/s on standard-tier accounts — verify against your plan on first use.

## Cost

AI Ark bills per company returned (credit-per-record model). Free-tier monthly caps are tight; production TAM runs (1000+ companies) require a paid plan. See [ai-ark.com/pricing](https://ai-ark.com) for current tiers. A single tam-map invocation at 1000-company TAM consumes ~1000 credits at the standard rate.

## Failure modes

- **Use exact taxonomy phrases for `industries`, not loose keywords.** The filter sends `industries.any.include` with `mode: "WORD"`, matched against AI Ark's own industry taxonomy. Pass the exact phrase the API returns in a record's `summary.industry` / `industries[]` (e.g. `"software development"`, `"it services and it consulting"`) — a loose single word can over- or under-match. Verified BC-7157: `["software development"]` → 2,236,141 software-development companies; AI Ark's taxonomy is narrower than NAICS, so generic terms like `"retail"` or `"technology"` may under-return. Workaround: seed filter values from a prior unfiltered/lookalike response's `summary.industry` field, or the vendor's taxonomy browser.
- **Geo is the `location` field, matched by name (not ISO-2 codes).** Pass full country/region names via `regions[]`, e.g. `["United States"]` or `["Texas"]`; the wrapper sends `account.location.any.include=[…]`. Verified BC-7157 — the OpenAPI example uses `"United States"`/`"Texas"`/`"Canada"` as `location` values. (A pre-BC-7157 note here claimed ISO-2 country codes and a `{country, regions}` object — that was upstream guesswork, contradicted by the verified `AccountFilter` schema.)
- **Pagination token expiry.** Tokens are bound to the initial query and may expire within 10 minutes. Symptom: mid-pagination 400 error. Workaround: issue pagination calls immediately after the initial call; don't stall.

## Retry

Treat 429 and 5xx as retryable with exponential backoff: base 2s, double per attempt, cap at 16s, 3 attempts max. For 400 on pagination (token expiry), abandon pagination and re-issue the root query. 401/403 is terminal — rotate the key.

## Brite usage

Invoked as **step 1** of `tam-mapping` Phase 3c (Labs path). Brite passes firmographic filters sourced from the per-vertical playbook file (`plugins/marketing/references/vertical-playbooks/{vertical}.md`), which contains industry codes + employee band + geography + persona seed titles. The response feeds step 2 (Spider.cloud crawl) and step 3 (Discolike lookalike expansion).

For Brite Labs verticals, Active-tier ones (zoos, aquariums) typically return 50–300 companies per ICP; Exploring-tier (casinos, hotels-resorts, ski-resorts, sports-stadiums) return 200–800. Expect pagination in all cases.

## Related skills

- **Primary consumers:** `tam-mapping` (BC-5832), `list-building` (pending BC-2717; would compose over tam-mapping).
- **Upstream / downstream:** AI Ark output feeds Spider.cloud (crawl), Discolike (lookalike expansion), IcyPeas (keyword search for overlapping coverage).
- **Alternatives:** Apollo.io (rejected — heavier, more expensive at discovery-phase volumes), Crunchbase Data (rejected — weaker firmographic filters), Clay (deprecated per `memory/project_clay_deprecated.md`).

## Last verified

- **2026-05-31 (BC-7157)** — `aiark_search` `account` filter sub-schema verified against the OpenAPI spec embedded in `docs.ai-ark.com/reference/company-search-1.md` and confirmed live via `bw-run.sh`: `industries`→`industries.any.include.{mode,content}`, `regions`→`location.any.include[]`, `employee_min/max`→`employeeSize.{type:RANGE,range[{start,end}]}`. A filtered `industries:["software development"]` query returned 2,236,141 software-development companies (vs. 70,841,359 unfiltered); `aiark_similarity` regression intact. Smoke captured in the BC-7157 PR.
- **2026-05-11 (BC-7011)** — Endpoint paths, base URL, auth header, request body shape, and tool surface verified against `docs.ai-ark.com/reference/company-search-1`, `docs.ai-ark.com/docs/authentication`, and `help.ai-ark.com/en/articles/112-how-does-the-api-work`. Live MCP smoke captured in PR description.
