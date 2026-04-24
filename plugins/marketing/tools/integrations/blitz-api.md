# BlitzAPI Integration

> Reference document. Connection details, auth, and CLI surface only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

BlitzAPI is the **primary-enrichment layer** of the tam-map pipeline. Given a company domain, it returns an owner / decision-maker email + firmographic context. It is step 5 of the 9-step upstream pipeline — the primary stage of the enrichment waterfall (Prospeo step 6 is the fallback). See `plugins/marketing/references/tam/UPSTREAM.md`.

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` — **pending BC-5832**
- `plugins/marketing/scripts/tam-map/enrich_waterfall.py` — ported Python wrapper (handles BlitzAPI primary + Prospeo fallback in one pass); not wrapped as an MCP server

## Auth

- **Credential type.** API key, passed as `Authorization: Bearer <BLITZAPI_KEY>`.
- **Where it comes from.** [blitz-api.ai](https://blitz-api.ai) → account dashboard → API keys.
- **Scopes.** Account-wide enrichment access.
- **Env var.** `BLITZAPI_KEY`.
- **Base URL.** `https://api.blitz-api.ai/v2/enrich`.

## Registration

**N/A — no MCP server.** BlitzAPI is called from `plugins/marketing/scripts/tam-map/enrich_waterfall.py` (async, aiohttp-based waterfall). `.env.example` entry:

```
# Enrichment — primary (owner discovery)
BLITZAPI_KEY=
```

Invocation (CLI):

```bash
python plugins/marketing/scripts/tam-map/enrich_waterfall.py \
  --in ./output/{slug}/crawled.jsonl \
  --out ./output/{slug}/enriched.jsonl
```

The same script handles Prospeo fallback — see `prospeo.md`. Skills that wrap this provider should shell out to the Python client.

**Promotion candidate.** Not currently a plan to wrap BlitzAPI as its own MCP server — it's an enrichment detail, not a user-facing tool. BC-5538 (brite-enrichment MCP) may eventually subsume this provider under the Brite enrichment umbrella with the `blitz_waterfall` enum value in `enrichment_provider` (per `docs/decisions/008-tam-mapping-enrichment-pluggability.md`).

## CLI surface

`scripts/tam-map/enrich_waterfall.py` exposes:

| Function | Signature | Purpose |
|---|---|---|
| `blitz_enrich(session, company: dict) -> dict \| None` | `async`; takes an aiohttp session + company dict (must have `domain`), returns `{"email", "source": "blitzapi", "raw": {...}}` on match, `None` on miss | Primary BlitzAPI call |
| `enrich_one(session, blitz_sem, prospeo_sem, company) -> dict` | `async`; runs BlitzAPI first, falls back to Prospeo, merges result into input company dict | Waterfall orchestrator |
| `run(companies: list[dict], outfile: str)` | Top-level async driver; writes JSONL incrementally | CLI entry point |

Endpoint internals:

| Endpoint | Method | Body | Response on hit |
|---|---|---|---|
| `/v2/enrich` | POST | `{"website": domain}` | `{"email": str, "first_name"?, "last_name"?, "title"?, "linkedin_url"?, ...}` |

## Rate limits

**5 req/s hard, serialized single instance.** The wrapper enforces this with `asyncio.Semaphore(1)` + `await asyncio.sleep(0.2)` between calls. Parallelizing beyond a single concurrent request against BlitzAPI produces 429s and degrades throughput; the serial-with-sleep pattern is intentional.

## Cost

**Unlimited credits on the standard plan** (verified at pinned SHA; re-confirm on first Brite paid-account use). This is the main reason BlitzAPI is the waterfall primary — fixed monthly fee, not credit-per-record, so there's no incentive to pre-filter before calling. See [blitz-api.ai/pricing](https://blitz-api.ai) for current tiering.

For Brite: at 5 req/s serialized, a 1000-company TAM takes ~200 seconds of BlitzAPI time. Plan tam-map session runtime accordingly.

## Failure modes

- **Empty email on match.** A 200 response with `email: null` or missing is a soft miss — BlitzAPI knows the domain but couldn't surface an owner email. Symptom: no exception, but the waterfall falls through to Prospeo. Behavior: not a bug; it's the waterfall working as designed.
- **Stale cache on recent domain changes.** BlitzAPI's contact data has cache TTL in the days-to-weeks range; recently-rebranded companies or fresh acquisitions may return outdated owner info. Symptom: email for a former owner. Workaround: manual verification on critical targets; accept as noise floor on bulk runs.
- **404-class domains.** Invalid or parked domains return non-200 responses. The wrapper's try/except catches + skips; no retry is productive.
- **Rate limit violation cascade.** If a parallel invocation (e.g., a second `tam-map` run) hits BlitzAPI simultaneously, both sessions trip 429. Symptom: `non-200` status on most calls. Workaround: serialize at the job level — one tam-map at a time against BlitzAPI credentials.

## Retry

Treat 5xx as retryable with exponential backoff: base 2s, double per attempt, cap at 16s, 3 attempts max. 429 → fall back to Prospeo immediately rather than retry (the wrapper's current design). 4xx other than 429 is terminal per-record; log and fall through. The upstream `enrich_waterfall.py` does not implement per-call retry — relies on semaphore throttling + Prospeo fallback; skills can add retry-on-5xx if needed.

## Brite usage

Invoked as **step 6 primary** of `/marketing:tam-map <vertical>`. Brite passes domains sourced from AI Ark + Discolike + IcyPeas (deduped by domain at step 5). BlitzAPI attempts owner-email enrichment first; Prospeo picks up misses where a LinkedIn URL was found during crawl.

For Brite Labs verticals, BlitzAPI hit rates vary: Active-tier venues (zoos, aquariums) with public-facing leadership typically hit 70–80%; Exploring-tier multi-property operators (hotel groups, casino operators) where the venue-level "owner" may be GM-level rather than C-suite hit 40–60%. The Prospeo fallback rescues most misses.

Per the Clay-deprecated amendment in `memory/project_clay_deprecated.md` (2026-04-24 addition from BC-5945): **BlitzAPI as a waterfall primary is a narrow exception** to the Clay-removal rule, scoped to tam-mapping only, sunset when BC-5538 (brite-enrichment MCP) reaches GA.

## Related skills

- **Primary consumers:** `tam-mapping` (pending BC-5832).
- **Upstream / downstream:** BlitzAPI consumes domains from AI Ark / Discolike / IcyPeas; fallback into Prospeo (see `prospeo.md`).
- **Alternatives:** Prospeo (documented as fallback, not alternative), Apollo.io (rejected — per-record credit model breaks waterfall economics), Clay (deprecated, broader rule supersedes).

## Last verified

2026-04-24 — CLI surface verified from upstream `scripts/enrich_waterfall.py` at commit `9f5c72e74b`. Not yet validated against live vendor API from a Brite install. Bump this date on first live validation.
