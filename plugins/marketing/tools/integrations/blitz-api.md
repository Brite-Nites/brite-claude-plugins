# BlitzAPI Integration

> Reference document. Connection details, auth, and CLI surface only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

BlitzAPI is the **primary-enrichment layer** of the tam-map pipeline. Given a company domain, it returns an owner / decision-maker email + firmographic context. It is step 5 of the 9-step upstream pipeline — the primary stage of the enrichment waterfall (Prospeo step 6 is the fallback). See `plugins/marketing/references/tam/UPSTREAM.md`.

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` (BC-5832) — Phase 5 enrichment (default `blitz_waterfall` provider per ADR-008)
- `plugins/marketing/scripts/tam-map/enrich_waterfall.py` — ported Python wrapper (handles BlitzAPI primary + Prospeo fallback in one pass); not wrapped as an MCP server

## Auth

- **Credential type.** API key, passed as the `x-api-key: <BLITZAPI_KEY>` header (BC-12128 — was `Authorization: Bearer` before BlitzAPI's 2026-05 API redesign).
- **Where it comes from.** [blitz-api.ai](https://blitz-api.ai) → account dashboard → API keys.
- **Scopes.** Account-wide enrichment access. The key is **credit-metered** — `GET /v2/account/key-info` returns `remaining_credits` + `max_requests_per_seconds`.
- **Env var.** `BLITZAPI_KEY`.
- **Base URL.** `https://api.blitz-api.ai` (per-operation paths below; the old single `/v2/enrich` endpoint was removed). Live OpenAPI spec: `https://api.blitz-api.ai/openapi`.

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

**Promotion candidate.** Not currently a plan to wrap BlitzAPI as its own MCP server — it's an enrichment detail, not a user-facing tool. BC-6170 (the tam-mapping / list-building flip to the brite-enrichment MCP that BC-5538 builds) supersedes this provider under the Brite enrichment umbrella, swapping the `blitz_waterfall` enum value in `enrichment_provider` (per `docs/decisions/008-tam-mapping-enrichment-pluggability.md`).

## CLI surface

`scripts/tam-map/enrich_waterfall.py` exposes:

| Function | Signature | Purpose |
|---|---|---|
| `blitz_enrich(session, company: dict) -> dict \| None` | `async`; company dict (must have `domain`), returns `{"email", "source": "blitzapi", "person_name", "person_linkedin", "company_linkedin", "raw"}` on match, `None` on miss | Primary BlitzAPI **chain** (domain → company LinkedIn → decision-makers → work email) |
| `enrich_one(session, blitz_sem, prospeo_sem, company) -> dict` | `async`; runs BlitzAPI first, falls back to Prospeo, merges result into input company dict | Waterfall orchestrator |
| `run(companies: list[dict], outfile: str)` | Top-level async driver; writes JSONL incrementally; prints an end-of-run summary (+ loud banner on any BlitzAPI quota/credit/rate errors) | CLI entry point |

(`_blitz_post` centralizes `x-api-key` auth + the 5 req/s throttle + loud non-200/error logging; `_clean_domain` normalizes full-URL domain fields to a bare host.)

Endpoint internals — BC-12128: the one-shot `/v2/enrich` was removed; `blitz_enrich` now chains three operations (all `POST`, `x-api-key` auth):

| Step | Endpoint | Body | Response (fields used) |
|---|---|---|---|
| 1 | `/v2/enrichment/domain-to-linkedin` | `{"domain": "<bare host>"}` | `{"found", "company_linkedin_url"}` |
| 2 | `/v2/search/employee-finder` | `{"company_linkedin_url", "job_level": ["C-Team","VP","Director"], "max_results": 5}` | `{"results": [{"full_name", "linkedin_url", …}]}` |
| 3 | `/v2/enrichment/email` | `{"person_linkedin_url"}` | `{"found": bool, "email": str\|null, "all_emails": […]}` |

Step 3 is iterated over candidates (owner/C-level first) until one returns `found: true` with an `email`. Auth/credit probe: `GET /v2/account/key-info` → `{"valid", "remaining_credits", "max_requests_per_seconds"}`.

## Rate limits

**5 req/s hard, serialized single instance.** The wrapper enforces this with `asyncio.Semaphore(1)` serializing the chain + a per-call `await asyncio.sleep(0.21)` inside `_blitz_post` (BC-12128 — the throttle moved into the helper now that one enrichment is a multi-call chain). Parallelizing beyond a single concurrent request against BlitzAPI produces 429s and degrades throughput; the serial-with-sleep pattern is intentional.

## Cost

**Credit-metered (BC-12128 — was "unlimited" pre-redesign).** `GET /v2/account/key-info` reported **1000 remaining credits / 5 rps** on 2026-05-31 (resets periodically). Each company now costs **2–7 credits** (1 domain-to-linkedin + 1 employee-finder + up to 5 per-candidate email lookups), so a large TAM can exhaust the budget mid-run. `enrich_waterfall.py` counts BlitzAPI quota/credit/rate errors (HTTP 402/403/429) and prints a loud end-of-run banner, so an exhausted budget is distinguishable from a low hit-rate (misses fall through to Prospeo). Check `key-info` credits before a large run. **BC-6170** (brite-enrichment MCP) supersedes this provider.

For Brite: at 5 rps serialized with a 2–7 call chain, throughput is well below the old single-call ~200s/1000 estimate — plan tam-map runtime accordingly and watch the credit budget.

## Failure modes

- **Per-candidate email miss.** Each `/v2/enrichment/email` call returns `found: false` when that decision-maker has no findable work email; `blitz_enrich` iterates the next candidate and falls through to Prospeo only if all candidates miss. The first decision-maker frequently misses — expected, not a bug.
- **Credit/rate exhaustion.** Once the key's credits are spent, calls return non-200 (402/403) and `_blitz_post` logs a distinct `[blitz] ⚠ quota/credit/rate` line; `run()` surfaces a loud end-of-run banner. Distinguish this from a genuine low hit-rate before concluding the data is sparse.
- **Stale cache on recent domain changes.** BlitzAPI's contact data has cache TTL in the days-to-weeks range; recently-rebranded companies or fresh acquisitions may return outdated owner info. Symptom: email for a former owner. Workaround: manual verification on critical targets; accept as noise floor on bulk runs.
- **404-class domains.** Invalid or parked domains return non-200 responses. The wrapper's try/except catches + skips; no retry is productive.
- **Rate limit violation cascade.** If a parallel invocation (e.g., a second `tam-map` run) hits BlitzAPI simultaneously, both sessions trip 429. Symptom: `non-200` status on most calls. Workaround: serialize at the job level — one tam-map at a time against BlitzAPI credentials.

## Retry

Treat 5xx as retryable with exponential backoff: base 2s, double per attempt, cap at 16s, 3 attempts max. 429 → fall back to Prospeo immediately rather than retry (the wrapper's current design). 4xx other than 429 is terminal per-record; log and fall through. The upstream `enrich_waterfall.py` does not implement per-call retry — relies on semaphore throttling + Prospeo fallback; skills can add retry-on-5xx if needed.

## Brite usage

Invoked as **step 6 primary** of `/marketing:tam-map <vertical>`. Brite passes domains sourced from AI Ark + Discolike + IcyPeas (deduped by domain at step 5). BlitzAPI attempts owner-email enrichment first; Prospeo picks up misses where a LinkedIn URL was found during crawl.

For Brite Labs verticals, BlitzAPI hit rates vary: Active-tier venues (zoos, aquariums) with public-facing leadership typically hit 70–80%; Exploring-tier multi-property operators (hotel groups, casino operators) where the venue-level "owner" may be GM-level rather than C-suite hit 40–60%. The Prospeo fallback rescues most misses.

Per the Clay-deprecated amendment in `memory/project_clay_deprecated.md` (2026-04-24 addition from BC-5945): **BlitzAPI as a waterfall primary is a narrow exception** to the Clay-removal rule, scoped to tam-mapping only, sunset when BC-6170 flips tam-mapping to the brite-enrichment MCP (after BC-5538 reaches GA).

## Related skills

- **Primary consumers:** `tam-mapping` (BC-5832, Phase 5 default provider).
- **Upstream / downstream:** BlitzAPI consumes domains from AI Ark / Discolike / IcyPeas; fallback into Prospeo (see `prospeo.md`).
- **Alternatives:** Prospeo (documented as fallback, not alternative), Apollo.io (rejected — per-record credit model breaks waterfall economics), Clay (deprecated, broader rule supersedes).

## Last verified

2026-05-31 (BC-12128) — Live-validated against the **redesigned** vendor API via `bw-run.sh`: `x-api-key` auth, the 3-call chain, and credit metering verified against the OpenAPI spec at `api.blitz-api.ai/openapi`; an end-to-end run (`{"domain":"vercel.com"}`) returned a real owner email. The pre-redesign one-shot `/v2/enrich` + `Authorization: Bearer` + "unlimited credits" contract (2026-04-24, upstream `9f5c72e74b`) is retired.
