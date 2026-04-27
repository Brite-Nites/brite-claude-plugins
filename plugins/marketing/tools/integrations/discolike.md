# Discolike Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

Discolike is the **lookalike-expansion layer** of the tam-map pipeline. Given a seed list of peer-venue domains, it returns similar companies via domain similarity search — the mechanism tam-mapping uses to widen a narrow ICP into a full vertical TAM. It is step 3 of the 9-step upstream pipeline (see `plugins/marketing/references/tam/UPSTREAM.md`).

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` (BC-5832) — Phase 3c Labs collection (lookalike expansion)
- `plugins/marketing/scripts/tam-map/discolike_client.py` — ported Python wrapper
- `plugins/marketing/scripts/tam-map/discolike-mcp.js` — ported stdio MCP wrapper

## Auth

- **Credential type.** API key, passed by the upstream stdio wrapper as a custom header: `x-discolike-key: <DISCOLIKE_API_KEY>` (**not** `Authorization: Bearer`).
- **Where it comes from.** [discolike.com](https://discolike.com) → account dashboard → API keys.
- **Scopes.** Account-wide read + search; no sub-scoping documented.
- **Env var.** `DISCOLIKE_API_KEY`.
- **Base URL (for direct HTTP, not via MCP).** `https://api.discolike.com/v1/discover` — GET-only.

**Do not commit credentials.** The `.mcp.json` snippet below uses `${DISCOLIKE_API_KEY}` as placeholder.

## Registration

Discolike has no vendor MCP server. The upstream port ships a Node stdio wrapper (`scripts/tam-map/discolike-mcp.js`, ~4KB). Registration snippet — belongs in `plugins/marketing/.mcp.json` (pending BC-5947):

```json
{
  "mcpServers": {
    "discolike": {
      "command": "node",
      "args": ["./plugins/marketing/scripts/tam-map/discolike-mcp.js"],
      "env": {
        "DISCOLIKE_API_KEY": "${DISCOLIKE_API_KEY}"
      }
    }
  }
}
```

`.env.example` entry:

```
# Lookalike expansion
DISCOLIKE_API_KEY=
```

The stdio transport + `env` block avoids the `${user_config.*}` header-substitution bug documented in `memory/gotcha_http_mcp_substitution_broken.md`.

## Tool inventory

The wrapper registers two tools (see `plugins/marketing/scripts/tam-map/discolike-mcp.js` lines 62–92 at pinned commit `9f5c72e74b`):

| Tool | Purpose | Required args | Optional args |
|---|---|---|---|
| `discolike_search` | Natural-language ICP search across Discolike's 65M+ domain index | `icp_text` (string) | `country[]` (ISO-2), `category[]` (industry), `employee_range` ("min,max"), `min_digital_footprint` (0–800), `max_records` (default 100, range 5–10000), `offset` (default 0), `phrase_match[]` (up to 20 exact fragments) |
| `discolike_lookalike` | Find similar domains from a seed list | `domain[]` (up to 10 seeds) | `country[]`, `max_records` (default 100), `offset` (default 0) |

Discolike's matching is trained on web-content + hiring + firmographic signals, not purely industry-code taxonomy — output will include semantic peers that AI Ark misses (and vice versa). No `get_similarity` or pairwise-score tool exists at the pinned commit.

## Rate limits

Vendor default: undocumented at the pinned SHA. Observed empirically at ~5 req/s on standard-tier accounts. Lookalike queries are more expensive server-side than firmographic search (AI Ark), so aggressive concurrency is not productive.

## Cost

Discolike bills per lookalike returned (credit-per-record model). Pricing tiers vary by monthly volume — see [discolike.com/pricing](https://discolike.com). A typical tam-map invocation expands a 10-seed peer list into 100–300 lookalikes, consuming ~100–300 credits per run.

## Failure modes

- **Single-seed expansion degrades quickly after N=50.** Lookalike quality drops beyond the first 30–50 results per seed; the tail contains increasingly-loose matches. Symptom: late-pagination records have visibly-irrelevant domains. Workaround: cap lookalike expansion at N=30 per seed and provide 5–10 diverse seeds instead.
- **Private / small-footprint domains return empty.** Discolike's training data favors companies with meaningful public web footprints. Symptom: well-known but low-web-presence targets (private equity, niche B2B) yield near-empty lookalike sets. Workaround: fall back to AI Ark firmographic search for these verticals.
- **Domain-aliasing mis-merges.** Parent-child domains (e.g., `siemens.com` vs `siemens-energy.com`) may be treated as aliases server-side and collapse into one result. Symptom: expected subsidiary not in output. Workaround: query the subsidiary domain directly as a second seed.

## Retry

Treat 429 and 5xx as retryable with exponential backoff: base 2s, double per attempt, cap at 16s, 3 attempts max. 400 on unknown-domain seeds is terminal — log and skip the seed.

## Brite usage

Invoked as **step 3** of `tam-mapping` Phase 3c (Labs path). Brite seeds Discolike from the per-vertical playbook file (`{vertical}.md` § Peer-venue seeds), which contains 5–10 canonical venue domains curated from the vertical playbook peer-venue lists. The response merges with AI Ark (step 1) output, deduplicated by domain.

For Brite Labs Active-tier verticals (zoos, aquariums), 5–10 flagship venue seeds (e.g., Woodland Park Zoo, Georgia Aquarium) produce dense lookalike output covering 80%+ of the sub-vertical TAM. For Exploring-tier (casinos, hotels-resorts), seed diversity matters more — single-brand seeds (one Vegas casino) under-return; multi-brand seeds (Vegas + regional + tribal casinos) cover the vertical.

## Related skills

- **Primary consumers:** `tam-mapping` (BC-5832, Phase 3c lookalike expansion).
- **Upstream / downstream:** Discolike consumes peer-venue seeds from `{vertical}.md`; output merges with AI Ark at the step-4 enrichment stage.
- **Alternatives:** 6sense (rejected — enterprise pricing tier, not tam-map-scale), Similarweb API (rejected — traffic-signal overlap, weaker firmographic output), Clay (deprecated per `memory/project_clay_deprecated.md`).

## Last verified

2026-04-24 — Tool inventory verified from upstream `scripts/discolike-mcp.js` + `discolike_client.py` at commit `9f5c72e74b`. Not yet validated against live vendor API from a Brite install (blocked on BC-5947). Bump this date on first live validation.
