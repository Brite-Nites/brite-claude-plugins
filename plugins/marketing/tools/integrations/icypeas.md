# IcyPeas Integration

> Reference document. Connection details, auth, and CLI surface only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

IcyPeas is the **keyword-search layer** of the tam-map pipeline — a complement to AI Ark's firmographic discovery that returns companies matching free-text keywords against industry / descriptor fields. It is step 4 of the 9-step upstream pipeline (see `plugins/marketing/references/tam/UPSTREAM.md`). Used for overlap coverage where AI Ark's taxonomy is narrower than the vertical requires.

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` (BC-5832) — Phase 1.5 free-count keyword expansion + Phase 3c keyword search
- `plugins/marketing/scripts/tam-map/icypeas_client.py` — ported Python wrapper; not wrapped as an MCP server

## Auth

- **Credential type.** Raw API key, passed as `Authorization: <ICYPEAS_API_KEY>` (**no `Bearer` prefix** — this is a vendor quirk that trips implementers new to the API).
- **Where it comes from.** [icypeas.com](https://icypeas.com) → account dashboard → API keys.
- **Scopes.** Account-wide read + search.
- **Env var.** `ICYPEAS_API_KEY`.
- **Base URL.** `https://app.icypeas.com/api`.

## Registration

**N/A — no MCP server.** IcyPeas is called directly from `plugins/marketing/scripts/tam-map/icypeas_client.py` as a Python subprocess. `.env.example` entry:

```
# Keyword-based company search
ICYPEAS_API_KEY=
```

Invocation (CLI):

```bash
python plugins/marketing/scripts/tam-map/icypeas_client.py \
  --icp ./output/{slug}/icp.json \
  > ./output/{slug}/icypeas.jsonl
```

Skills that wrap this provider should shell out to the Python client (`Bash(python:*)` allowed-tool grant) rather than inventing a bespoke HTTP path.

**Promotion candidate.** IcyPeas is a reasonable candidate for a future stdio MCP wrapper following the `aiark-mcp.js` / `discolike-mcp.js` pattern. Not scoped for BC-5947 — file a follow-up issue if the Python-subprocess shape becomes frictional in tam-mapping execution.

## CLI surface

`scripts/tam-map/icypeas_client.py` exposes:

| Function | Signature | Purpose |
|---|---|---|
| `search(icp: dict) -> list[dict]` | Reads an ICP dict (`industries`, `geo.regions`), hits `POST /find-companies` paginated, dedupes by domain | Primary entry point |
| `main()` | CLI wrapper; reads `--icp <path>`, prints JSONL to stdout + summary to stderr | Invoked by `/marketing:tam-map` orchestration |

Endpoint internals (for skill authors writing direct HTTP instead of using the client):

| Endpoint | Method | Body | Response |
|---|---|---|---|
| `/find-companies` | POST | `{"keywords": str, "locations": [str], "limit": int<=100, "pagination": {"token": str}}` | `{"leads": [...], "pagination": {"token": str}, "total": int}` |

Response field names differ from ergonomic expectations — API returns `total` (not `count`) and `leads` (not `items` / `companies`). The wrapper normalizes these.

## Rate limits

Not explicitly documented by the vendor at pinned SHA. The upstream wrapper does not impose client-side throttling. Observed empirically stable at ~5 req/s sustained; pagination is serial by design (token-chained). Plan on seconds-per-industry-keyword, not millisecond-scale.

## Cost

IcyPeas bills per lead returned (credit-per-record). Standard tier targets SMB / agency pricing. See [icypeas.com/pricing](https://icypeas.com) — free tier is limited to ~100 leads/month; tam-map-scale runs need a paid plan. Multi-industry ICPs multiply cost linearly (one pagination run per industry keyword).

## Failure modes

- **Common terms return 0.** Keywords like `retail`, `ecommerce`, `fashion` return zero even against well-populated databases. Symptom: silent empty-`leads` response. Workaround: try synonyms (`retailer`, `online retail`, `apparel`) or fall back to AI Ark firmographic search.
- **Regions vs countries.** `locations` field accepts mixed-format region strings — `"US"`, `"Texas"`, `"Austin, TX"` all parse, but matching fidelity varies by region granularity. Symptom: fewer results than expected for narrow geo. Workaround: start with country-level, then narrow.
- **Authorization header format.** Passing `Authorization: Bearer <key>` (common convention) returns 401. IcyPeas requires the raw key with no prefix. Symptom: 401 on all calls. Workaround: double-check header format; the wrapper handles this correctly.
- **Pagination token expiry.** Tokens tie to the initial query + timestamp; stalling mid-pagination can 400 on next call. Workaround: drive pagination with a tight loop, not a manual loop with gaps.

## Retry

Treat 429 and 5xx as retryable with exponential backoff: base 2s, double per attempt, cap at 16s, 3 attempts max. 401 → rotate the key (and verify no accidental `Bearer` prefix). 400 on pagination → re-issue the root query and discard the pagination token.

## Brite usage

Invoked as **step 4** of `tam-mapping` Phase 3c (Labs path). Brite seeds IcyPeas from the per-vertical playbook file's `## Firmographics` and `## Geography` sections (`{vertical}.md`). For Brite Labs verticals, IcyPeas is a **coverage complement** to AI Ark — it catches companies that AI Ark missed due to taxonomy gaps, particularly for sub-verticals like "themed entertainment installers" or "boutique landscape-architecture firms" that don't map cleanly to any single firmographic code.

For the 6 Labs verticals, IcyPeas is most useful for Exploring-tier (casinos, hotels-resorts, ski-resorts, sports-stadiums) where the vendor's keyword database has meaningful coverage. Active-tier (zoos, aquariums) tend to be well-covered by AI Ark alone; IcyPeas adds little.

## Related skills

- **Primary consumers:** `tam-mapping` (BC-5832, Phase 1.5 keyword expansion + Phase 3c keyword search).
- **Upstream / downstream:** IcyPeas output merges with AI Ark and Discolike output at step-5 enrichment; deduplication by `domain` field.
- **Alternatives:** Clearbit Discovery (deprecated on vendor side), Crunchbase Data (rejected — weaker keyword matching, strong firmographic which AI Ark already covers), Clay (deprecated per `memory/project_clay_deprecated.md`).

## Last verified

2026-04-24 — CLI surface verified from upstream `scripts/icypeas_client.py` at commit `9f5c72e74b`. Not yet validated against live vendor API from a Brite install. Bump this date on first live validation.
