# Spider.cloud Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

Spider.cloud is the **web-crawl layer** of the tam-map pipeline. Given a list of company domains, it fetches landing pages + sub-pages and extracts tech stack signals, content, and intent keywords — the raw input the fit-scoring prompt grades. It is step 2 of the 9-step upstream pipeline (see `plugins/marketing/references/tam/UPSTREAM.md`).

## Consumed by

- `plugins/marketing/skills/tam-mapping/SKILL.md` — **pending BC-5832**
- `plugins/marketing/scripts/tam-map/spider_crawl.py` — ported wrapper, calls the vendor API directly for non-MCP contexts

## Auth

- **Credential type.** API key, passed as `Authorization: Bearer <SPIDER_API_KEY>` by the vendor's own MCP server.
- **Where it comes from.** [spider.cloud](https://spider.cloud) → account dashboard → API keys.
- **Scopes.** Account-wide read + crawl; no sub-scoping documented.
- **Env var.** `SPIDER_API_KEY`.

**Do not commit credentials.** The `.mcp.json` snippet below uses `${SPIDER_API_KEY}` as placeholder.

## Registration

Spider ships a native MCP server. Two transports are available — stdio (recommended) and HTTP. The stdio entry is registered in `plugins/marketing/.mcp.json`:

```json
{
  "mcpServers": {
    "spider": {
      "command": "npx",
      "args": ["-y", "spider-cloud-mcp"],
      "env": {
        "SPIDER_API_KEY": "${SPIDER_API_KEY}"
      }
    }
  }
}
```

The npm package is `spider-cloud-mcp` (unscoped). HTTP transport is also documented at `https://mcp.spider.cloud/mcp` with `Authorization: Bearer <key>`, but stdio is preferred here because it sidesteps the `${user_config.*}` substitution bug that affects HTTP-header registrations.

`.env.example` entry:

```
# Web crawl
SPIDER_API_KEY=
```

Because the server reads its key from the process `env` block (stdio, not HTTP headers), this registration is unaffected by the `${user_config.*}` substitution bug documented in `memory/gotcha_http_mcp_substitution_broken.md` — env-var substitution into stdio server `env` maps works today.

## Tool inventory

`spider-cloud-mcp` v2.1.1 exposes **22 tools** in three groups (per [Spider docs](https://spider.cloud/docs/integrations/mcp), 2026-04-25). The authoritative inventory is whatever the installed package version ships — call `ListTools` at runtime if precise tool surface matters.

| Group | Count | Tools |
|---|---|---|
| Core (pay-per-use) | 8 | `spider_crawl`, `spider_scrape`, `spider_search`, `spider_links`, `spider_screenshot`, `spider_unblocker`, `spider_transform`, `spider_get_credits` |
| AI (subscription) | 5 | `spider_ai_crawl`, `spider_ai_scrape`, `spider_ai_search`, `spider_ai_browser`, `spider_ai_links` |
| Browser (interactive) | 9 | `spider_browser_open`, `spider_browser_navigate`, `spider_browser_click`, `spider_browser_fill`, `spider_browser_screenshot`, `spider_browser_content`, `spider_browser_evaluate`, `spider_browser_wait_for`, `spider_browser_close` |

For tam-mapping the primary calls are `spider_crawl` (multi-page extraction) and `spider_scrape` (single-URL fast path). `spider_get_credits` is useful for pre-flight cost checks before large TAM runs.

## Rate limits

Vendor default plan: burst-tolerant, per-minute throttles enforced server-side. The upstream wrapper (`spider_crawl.py`) does not impose client-side rate limiting — it relies on the server's 429 responses to pace the client. Paid tiers lift the cap; see [spider.cloud/pricing](https://spider.cloud/pricing).

## Cost

Spider bills by credits per crawl-page. Exact price varies by plan — see [spider.cloud/pricing](https://spider.cloud/pricing). A TAM of 1000 domains at ~3 pages deep averages roughly 3000 credits per run; plan accordingly. No free tier for production volumes.

## Failure modes

- **JavaScript-heavy sites return empty content.** Spider's default renderer is static-HTML; pages that require a JS bundle to hydrate body content come back as shell-only. Symptom: `crawl` returns a page with near-empty `extracted_text`. Workaround: opt into the server's headless-chrome mode (see vendor docs) — costs more credits.
- **Robots.txt blocks silently.** Spider respects robots.txt by default; blocked URLs return success with empty content. Symptom: 0 pages indexed for a whitelisted domain. Workaround: verify the target's robots.txt allows the crawler UA before scoping the TAM.
- **Large-page truncation.** Pages above a vendor-side body-size cap (undocumented at pinned SHA) come back truncated. Not a hard failure — downstream fit-scoring may see less content than expected.

## Retry

Treat 429 and 5xx as retryable with exponential backoff: base 1s, double per attempt, cap at 8s, 3 attempts max. 4xx other than 429 is terminal — log and skip the URL. The upstream `spider_crawl.py` does not implement retry (relies on caller); skills that wrap it should add the backoff loop.

## Brite usage

Invoked in the **step-2 crawl stage** of `/marketing:tam-map <vertical>`. Brite runs this against company lists generated by AI Ark (step 1) + Discolike (step 3) + IcyPeas (step 4) — the merged, deduped discovery set. Enrichment (BlitzAPI step 5, Prospeo step 6) runs downstream against the crawl output, not alongside it. For Brite Labs verticals (zoos, aquariums, casinos, hotels-resorts, ski-resorts, sports-stadiums), the crawl depth defaults to 3 pages — enough to capture About / Projects / Experience pages that carry the intent signals fit-scoring grades.

Skill authors: do not call Spider from Brite Nites Supply-vertical workflows without confirming the persona is at a public corporate site. Supply personas are often on private portals where Spider returns shells.

## Related skills

- **Primary consumers:** `tam-mapping` (pending BC-5832), `icp-scoring` (pending BC-5831).
- **Upstream / downstream:** Spider consumes domain lists from AI Ark / IcyPeas / Discolike; emits crawl output to the fit-scoring prompt via `tier_and_segment.py`.
- **Alternatives:** Apify (considered, heavier footprint), Firecrawl (comparable, rejected pre-tam-map due to earlier Brite experience). Spider is the standing choice.

## Last verified

2026-04-25 — Package name + 22-tool inventory verified against [Spider docs](https://spider.cloud/docs/integrations/mcp). Live MCP validation pending the first session-restart with `SPIDER_API_KEY` exported. Bump this date on first live validation.
