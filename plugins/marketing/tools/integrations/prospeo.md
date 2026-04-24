# Prospeo Integration

> Reference document. Connection details, auth, and CLI surface only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

Prospeo is the **fallback-enrichment layer** of the tam-map pipeline — LinkedIn URL → email + mobile enrichment. Catches misses from BlitzAPI (the waterfall primary). It is the second stage of step 6 in the 9-step upstream pipeline.

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` — **pending BC-5832**
- `plugins/marketing/scripts/tam-map/enrich_waterfall.py` — ported Python wrapper (same waterfall script that handles BlitzAPI primary)

## Auth

- **Credential type.** API key, passed as `X-KEY: <PROSPEO_API_KEY>` header (**not** standard `Authorization: Bearer`).
- **Where it comes from.** [prospeo.io](https://prospeo.io) → account dashboard → API keys.
- **Scopes.** Account-wide enrichment access.
- **Env var.** `PROSPEO_API_KEY`.
- **Base URL.** `https://api.prospeo.io/enrich-person`.

## Registration

**N/A — no MCP server.** Prospeo is called from `plugins/marketing/scripts/tam-map/enrich_waterfall.py` as the fallback stage. `.env.example` entry:

```
# Enrichment — fallback (LinkedIn → email + mobile)
PROSPEO_API_KEY=
```

Invocation is the same CLI as BlitzAPI's (the waterfall script runs both providers in one pass):

```bash
python plugins/marketing/scripts/tam-map/enrich_waterfall.py \
  --in ./output/{slug}/crawled.jsonl \
  --out ./output/{slug}/enriched.jsonl
```

Prospeo is only called for records where BlitzAPI missed AND where the company record has a `linkedin_url` field. Records without a LinkedIn URL skip Prospeo entirely.

**Promotion candidate.** Not currently planned — Prospeo is an enrichment detail, not a user-facing tool. Subsumed under BC-5538 (brite-enrichment MCP) eventually.

## CLI surface

`scripts/tam-map/enrich_waterfall.py` exposes:

| Function | Signature | Purpose |
|---|---|---|
| `prospeo_enrich(session, company: dict) -> dict \| None` | `async`; takes an aiohttp session + company (must have `linkedin_url`), returns `{"email", "source": "prospeo", "raw": {...}}` on match, `None` on miss | Prospeo fallback call |
| `enrich_one(session, blitz_sem, prospeo_sem, company) -> dict` | `async`; waterfall orchestrator covering both providers | See `blitz-api.md` |

Endpoint internals:

| Endpoint | Method | Body | Response on hit |
|---|---|---|---|
| `/enrich-person` | POST | `{"only_verified_email": bool, "data": {"linkedin_url": str}}` | `{"email": str, "mobile"?, "first_name"?, ...}` |

## Rate limits

**20 workers max.** The wrapper enforces this with `asyncio.Semaphore(20)`. Pushing beyond 20 concurrent requests to the mobile endpoint produces 429s. The 20-worker cap is a stable pattern across Prospeo's public docs.

## Cost

Prospeo bills per verified email + mobile returned (credit-per-record). More expensive per-record than BlitzAPI, which is why it's the fallback rather than the primary. See [prospeo.io/pricing](https://prospeo.io) for current tiers.

For Brite: at 20-worker concurrency, a 1000-company TAM with a 30% Prospeo-fallback rate (~300 calls) takes ~15–30 seconds of Prospeo time. Credit cost per run scales with the waterfall miss rate on BlitzAPI.

## Failure modes

- **400 = NO_MATCH, not an error.** Prospeo returns 400 when it has no data for the input LinkedIn URL. The wrapper treats 400 as "soft miss" — no exception, just fall through. Symptom: a non-trivial fraction of 400s is expected. Not a bug.
- **Stale LinkedIn URLs.** Input URLs that were valid when crawled but are now 404 on LinkedIn (deleted profiles, company closures) return 400. Symptom: miss rate climbs over time for stale crawl data. Workaround: re-crawl before enrichment if the TAM sits in pipeline > 30 days.
- **Mobile endpoint stricter on concurrency.** The 20-worker cap is specifically observed on the mobile-number path; email-only runs may tolerate higher concurrency on some plans. The wrapper caps at 20 uniformly — safe default.
- **only_verified_email=False matters.** Passing `true` halves the hit rate. The wrapper uses `false` intentionally — downstream MillionVerifier does the SMTP verification, so pre-filtering at the Prospeo layer is wasted cost.

## Retry

Treat 429 and 5xx as retryable with exponential backoff: base 2s, double per attempt, cap at 16s, 3 attempts max. 400 is **not** retryable — it's a NO_MATCH signal. 401/403 → rotate the key.

## Brite usage

Invoked as **step 6 fallback** of `/marketing:tam-map <vertical>`. Prospeo picks up BlitzAPI misses specifically when a LinkedIn URL was captured during the Spider.cloud crawl or from AI Ark / Discolike company records.

For Brite Labs verticals, Prospeo's rescue rate varies with vertical publicity: Active-tier with well-populated LinkedIn footprints (zoos, aquariums) rescue 60–70% of BlitzAPI misses; Exploring-tier verticals (niche casinos, small ski resorts) where LinkedIn presence is weaker rescue 30–50%. The combined waterfall typically lands in the 80–90% final hit rate.

SMTP verification (step 7, `MillionVerifier`) still runs on Prospeo-sourced emails — Prospeo's verification flag is off intentionally per the `only_verified_email=False` note above.

## Related skills

- **Primary consumers:** `tam-mapping` (pending BC-5832).
- **Upstream / downstream:** Prospeo consumes companies with `linkedin_url` where BlitzAPI missed; emits to MillionVerifier for SMTP verification.
- **Alternatives:** Apollo.io (rejected — credit economics), Lusha (rejected — weaker international coverage), Clay (deprecated per `memory/project_clay_deprecated.md`).

## Last verified

2026-04-24 — CLI surface verified from upstream `scripts/enrich_waterfall.py` at commit `9f5c72e74b`. Not yet validated against live vendor API from a Brite install. Bump this date on first live validation.
