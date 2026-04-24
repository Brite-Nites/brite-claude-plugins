# MillionVerifier Integration

> Reference document. Connection details, auth, and CLI surface only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

MillionVerifier is the **SMTP-verification layer** of the tam-map pipeline. Takes enriched emails from the BlitzAPI → Prospeo waterfall and validates deliverability via real-time SMTP handshake, flagging catch-all domains separately. It is step 7 of the 9-step upstream pipeline — the final quality gate before fit-scoring + export.

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` — **pending BC-5832**
- `plugins/marketing/scripts/tam-map/verify_smtp.py` — ported Python wrapper; not wrapped as an MCP server

## Auth

- **Credential type.** API key, passed as `api` query parameter (**not** a header — vendor quirk).
- **Where it comes from.** [millionverifier.com](https://millionverifier.com) → account dashboard → API key.
- **Scopes.** Account-wide verification access.
- **Env var.** `MILLIONVERIFIER_API_KEY`.
- **Base URL.** `https://api.millionverifier.com/api/v3/`.
- **Required header.** `User-Agent: tam-map/1.0` (or any non-empty UA) — MillionVerifier rejects requests with no UA.

## Registration

**N/A — no MCP server.** MillionVerifier is called from `plugins/marketing/scripts/tam-map/verify_smtp.py` as the final pipeline stage. `.env.example` entry:

```
# Email verification (SMTP)
MILLIONVERIFIER_API_KEY=
```

Invocation (CLI):

```bash
python plugins/marketing/scripts/tam-map/verify_smtp.py \
  --in ./output/{slug}/enriched.jsonl \
  --out ./output/{slug}/verified.jsonl
```

Skills that wrap this provider should shell out to the Python client.

**Promotion candidate.** Marginal — the bulk-verification API shape is well-served by a Python subprocess, and the result-code interpretation is tam-map-specific. Not planned for MCP promotion.

## CLI surface

`scripts/tam-map/verify_smtp.py` exposes:

| Function | Signature | Purpose |
|---|---|---|
| `verify_one(session, record: dict) -> dict` | `async`; takes an aiohttp session + enriched record (`email` field required), returns record enriched with `smtp: {result, result_code, catch_all, keep}` | Primary verification call |
| `run(records, outfile)` | Top-level async driver; writes JSONL incrementally with 150-worker concurrency | CLI entry point |

Endpoint internals:

| Endpoint | Method | Query | Response |
|---|---|---|---|
| `/api/v3/` | GET | `api=<key>&email=<addr>&timeout=10` | `{"result": "valid"\|"catch_all"\|"invalid"\|..., "resultcode": int, "quality": str, ...}` |

**Result code interpretation** (vendor-defined):

| `resultcode` | Meaning | Wrapper behavior |
|---|---|---|
| `1` | Valid | Keep + non-catch-all |
| `2` | Catch-all | Keep + flag catch-all (route separately downstream) |
| `3` | Invalid | Drop |
| `4` | Unknown / SMTP timeout | Drop |
| `5` | Disposable | Drop |
| `6` | Role-based / suppressed | Drop |

The wrapper keeps codes 1 + 2 (`keep: true`), drops 3–6.

## Rate limits

**160 req/sec.** Vendor-documented hard ceiling. The wrapper runs at `CONCURRENCY = 150` (async semaphore) to stay under the cap with headroom for in-flight latency variation. Pushing to 160 exactly produces sporadic 429s in practice.

## Cost

MillionVerifier bills per verification (credit-per-email). Bulk pricing drops sharply at 10K/100K/1M tiers. See [millionverifier.com/pricing](https://millionverifier.com) for current rates.

For Brite: a 1000-record TAM with a 90% waterfall hit rate (~900 emails to verify) takes ~6 seconds at 150 concurrency and ~$0.40–$1.00 at standard bulk rates (plan-dependent). Catch-all flagging is free — no separate charge for the catch-all-specific logic.

## Failure modes

- **Catch-all ≠ deliverable.** `resultcode: 2` (catch-all) means the domain accepts any local-part, not that the specific address exists. Isolating catch-alls into a separate campaign (per the wrapper's `catch_all` flag) is mandatory — mixing them with verified addresses in the main campaign tanks sender reputation. Symptom: delivery rate drop 2–4 weeks after including catch-all in primary campaigns. Workaround: respect the flag downstream.
- **Timeout-as-unknown.** `resultcode: 4` can mean the target SMTP server timed out, not that the address is invalid. Some enterprise mail servers (Microsoft-hosted, aggressive anti-spam) are slow or rate-limit verification probes. Symptom: unexpected 4s for large-company targets. Workaround: for high-value targets scoring a 4, retry 24+ hours later or accept as noise.
- **Missing User-Agent.** Requests without a UA header return 400. The wrapper sets `tam-map/1.0` — skills bypassing the wrapper must set a UA.
- **Free-email aggregation.** MillionVerifier returns `valid` for Gmail / Outlook / Yahoo addresses if syntax + MX checks pass, even when the specific mailbox doesn't exist (providers don't allow verification probing). Symptom: Gmail addresses in the final list that bounce at delivery. Workaround: filter free-email domains out before tam-map export, or tag them as soft-valid in the downstream campaign.

## Retry

Treat 429 and 5xx as retryable with exponential backoff: base 1s, double per attempt, cap at 8s, 3 attempts max. Timeout / `resultcode: 4` is **not** retryable in the same run — it's a signal about the target server, not transport. Queue for out-of-band retry 24h later if the record is high-value.

## Brite usage

Invoked as **step 7** of `/marketing:tam-map <vertical>`. The output JSONL has one row per original record with an added `smtp` sub-object; downstream `tier_and_segment.py` (step 8) reads `smtp.keep` + `smtp.catch_all` to route into `tier-a.csv` / `tier-b.csv` / `catch-all.csv`.

For Brite Labs verticals, catch-all rates vary sharply: Active-tier venues (zoos, aquariums) running on mainstream mail providers have catch-all rates of 5–10%; Exploring-tier with corporate IT-heavy targets (hotel groups, stadium operators) can hit 30–40%. Plan campaign volume accordingly — the catch-all segment is real volume that requires its own sequence.

## Related skills

- **Primary consumers:** `tam-mapping` (pending BC-5832).
- **Upstream / downstream:** MillionVerifier consumes the enriched output from the BlitzAPI → Prospeo waterfall; emits to `tier_and_segment.py` for final routing.
- **Alternatives:** Kickbox (rejected — 3× cost at Brite volumes), ZeroBounce (rejected — weaker catch-all detection), NeverBounce (reasonable alternative, parity pricing — retained as a hot swap if vendor quality drifts).

## Last verified

2026-04-24 — CLI surface verified from upstream `scripts/verify_smtp.py` at commit `9f5c72e74b`. Not yet validated against live vendor API from a Brite install. Bump this date on first live validation.
