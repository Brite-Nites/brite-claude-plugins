# Upstream provenance — tam-map

`plugins/marketing/references/tam/` and `plugins/marketing/scripts/tam-map/` were imported from [Revgrowth1/tam-map](https://github.com/Revgrowth1/tam-map) (MIT) as a content + code port on **2026-04-24**. No subtree, no automatic sync — these are static assets consumed by Brite marketing skills (tam-mapping, icp-scoring) and orchestration commands (`/marketing:tam-map`, pending BC-5947 + BC-5950).

## Pinned commit

- **Source repo:** https://github.com/Revgrowth1/tam-map
- **Branch:** `main`
- **Commit SHA:** `9f5c72e74b`
- **Short SHA:** `9f5c72e7`

## License

MIT. See upstream [LICENSE](https://github.com/Revgrowth1/tam-map/blob/9f5c72e74b/LICENSE). Original work © Revgrowth1 and contributors.

## Per-file manifest — references

| Target path (under `plugins/marketing/references/tam/`) | Upstream path | Verbatim vs adapted |
|---------------------------------------------------------|---------------|---------------------|
| `icp-definition.md` | `prompts/icp-definition.md` | Verbatim (+ frontmatter) |
| `fit-scoring.md` | `prompts/fit-scoring.md` | Verbatim (+ frontmatter) |
| `segment-routing.md` | `prompts/segment-routing.md` | Verbatim (+ frontmatter) |
| `examples/roofing-contractors-tx.md` | `examples/roofing-contractors-tx.md` | Verbatim (+ frontmatter) |

## Per-file manifest — scripts

| Target path (under `plugins/marketing/scripts/tam-map/`) | Upstream path | Verbatim vs adapted |
|----------------------------------------------------------|---------------|---------------------|
| `aiark_client.py` | `scripts/aiark_client.py` | Verbatim (+ 5-line `#` header after shebang) |
| `discolike_client.py` | `scripts/discolike_client.py` | Verbatim (+ 5-line `#` header after shebang) |
| `icypeas_client.py` | `scripts/icypeas_client.py` | Verbatim (+ 5-line `#` header after shebang) |
| `spider_crawl.py` | `scripts/spider_crawl.py` | Verbatim (+ 5-line `#` header) + local fix (BC-7050) — see § Local deviations |
| `enrich_waterfall.py` | `scripts/enrich_waterfall.py` | Verbatim (+ 5-line `#` header) + local fix (BC-7051) — see § Local deviations |
| `verify_smtp.py` | `scripts/verify_smtp.py` | Verbatim (+ 5-line `#` header) + local fix (BC-7051) — see § Local deviations |
| `tier_and_segment.py` | `scripts/tier_and_segment.py` | **Removed** per BC-6907 — see § Local deviations |
| `aiark-mcp.js` | `scripts/aiark-mcp.js` | Verbatim (+ 5-line `//` header) + endpoint-drift fixes (BC-7011) — see § Local deviations |
| `discolike-mcp.js` | `scripts/discolike-mcp.js` | Verbatim (+ 5-line `//` header + verification comment for BC-7011 — no functional drift) |
| `package.json` | `scripts/package.json` | Verbatim (+ top-level `_source` + `_license` + `_ported` JSON fields — see § JSON attribution exception) |
| `requirements.txt` | `scripts/requirements.txt` | Verbatim (+ 5-line `#` header) + local change (BC-6907) — see § Local deviations |

## JSON attribution exception

`package.json` cannot carry comment-style headers (strict JSON). Attribution lives at the top of the file as three new string fields — `_source`, `_license`, `_ported` — following the OSS convention of underscore-prefixed extension fields that `npm` ignores. This manifest row is the canonical attribution; the `_source` field is the machine-readable counterpart.

## Sync model

**Fork-by-default.** We treat `plugins/marketing/scripts/tam-map/` and `plugins/marketing/references/tam/` as Brite content going forward. **No automatic upstream pulls.**

If upstream improvements are ever pulled, the operation is manual:

1. Diff the target file against the pinned SHA (e.g., `git show 9f5c72e74b:scripts/aiark_client.py` against the local file, ignoring the Brite attribution header).
2. Re-apply Brite additions (`_source` JSON fields, adaptations from future R-4/R-5 issues) on top of the new upstream body.
3. Bump the SHA references in this manifest + the per-file headers.
4. Re-run `./scripts/validate.sh` + `./scripts/check-guardrails.sh --claude-md CLAUDE.md`.

## Attribution convention

- **Script files** (`.py`, `.js`, `.txt`): carry a 5-line comment header immediately after the shebang (if any), naming upstream path, license, commit, and port date.
- **JSON** (`package.json`): carries top-level `_source`, `_license`, `_ported` fields in lieu of a comment header.
- **Markdown reference files** (`*.md`): carry YAML frontmatter naming upstream path, source, license, port date.

## Local deviations from upstream `9f5c72e74b`

### `enrich_waterfall.py:99` and `verify_smtp.py:68` — split async/sync context managers (BC-7051)

Upstream uses `async with aiohttp.ClientSession() as session, open(outfile, "w") as f:`. This shape crashes with `TypeError: '_io.TextIOWrapper' object does not support the asynchronous context manager protocol` on every Python version since async/await landed — `async with X, Y:` desugars to `async with X: async with Y:` and both items must implement `__aexit__`. `open()` returns a sync `TextIOWrapper` that only implements `__exit__`.

Brite ships the minimal fix: outer sync `with open(outfile, "w") as f:` wrapping inner `async with aiohttp.ClientSession() as session:`, with the task loop body re-indented under both. No dependency added (rejects `aiofiles`).

**Validated:** Python 3.13.11 + 3.14.3, both scripts, with real vendor round-trips (BlitzAPI, Prospeo, MillionVerifier). MillionVerifier returned `result_code: 2` (catch_all) — definitive vendor-side evidence.

**Re-port action:** if a future upstream pull at a newer SHA includes the same (or equivalent) split, drop this local diff and remove this section. If upstream's fix differs structurally, re-apply this section's split shape on top of the new upstream body — the diff is two functions, one line each.

### `spider_crawl.py:34,44,51-52` — REST endpoint + JSONL streaming shape (BC-7050)

Upstream calls `https://api.spider.cloud/v1/crawl` with `Content-Type: application/json` and parses the response with `await r.json()` as a single JSON object/list. BC-6906 Stage 2b live validation (2026-05-10) confirmed the wrapper returned `status 401` against the live Spider REST API, despite the credential being independently validated as correct via the Spider MCP path (which returned a valid 302,500-credit balance using the same env-var key).

BC-7050 verified the canonical request shape against the npm-distributed `spider-cloud-mcp@2.1.1` package (`dist/api.js` and `dist/server.js`, fetched via `npm pack`). Three classes of drift were fixed:

1. **Endpoint path** — `https://api.spider.cloud/v1/crawl` → `https://api.spider.cloud/crawl`. The MCP's `API_BASE` is `https://api.spider.cloud` (no `/v1` prefix) and `spider_crawl` posts to `/crawl` directly (`dist/server.js:318`).
2. **Content-Type** — `application/json` → `application/jsonl`. The MCP sets `application/jsonl` whenever the call uses `stream: true`, which is the default for `crawl`/`scrape`/`search`/`links`/`screenshot`/`unblocker`/`transform` (`dist/api.js:74`, `dist/server.js:318`).
3. **Response parsing** — `await r.json()` (single JSON parse) → JSONL stream parse via `text.splitlines()` + per-line `json.loads`. The MCP's `parseJsonlStream` is a chunk-level reader; the equivalent shape for the script's already-buffered `await r.text()` path is line-split-and-parse, mirroring the BC-7051 verbatim-port-with-minimal-diff discipline.

Auth header (`Authorization: Bearer ${SPIDER_API_KEY}`) is unchanged — the MCP uses the same shape (`dist/api.js:73`), so the original 401 was an endpoint-path rejection, not an auth-header rejection. The 401 (vs 404) on a stale path is consistent with Spider's auth middleware running before path routing.

**Validated:** live round-trip through `bw-run.sh` against `https://stripe.com` returned `EXIT=0`, `1/1 crawled in 3.2s`, `crawl.pages=5`, 8000-char markdown payload (output truncated by the script's existing `[:8000]` slice). Pre-fix the same invocation returned `0/1 crawled` + `crawl_error: status 401`.

**Re-port action:** if a future upstream pull at a newer SHA includes the same `/crawl` + `application/jsonl` + JSONL-parse shape, drop this local diff and remove this section. If upstream still uses `/v1/crawl` + single-JSON parsing, re-apply this section's three line changes on top of the new upstream body.

### `tier_and_segment.py` — removed in favor of in-session skill (BC-6907)

Upstream ships `scripts/tier_and_segment.py` as a Python CLI that calls Anthropic Haiku directly to classify each verified record into tier A/B/C and split catch-all into a separate segment. The script is the only piece of the tam-map port whose runtime credential is an Anthropic credential rather than a third-party vendor credential — and it runs inside a Claude Code session where Claude is already executing, so spawning a subprocess to call Claude through a separate credential is architecturally redundant.

Per Anthropic Agent SDK semantics, CLI subprocesses do not inherit the parent Claude Code session's auth, and there is no documented session-reuse pattern. The blessed pattern is to run work that needs Claude as a **skill** in the parent agent context.

Brite removes the script and folds its responsibility into the existing `icp-scoring` skill's `abc` rubric (already implemented at `plugins/marketing/skills/icp-scoring/SKILL.md` §Methodology dual-mode rubric → `abc`). `tam-mapping` Phase 7 invokes `icp-scoring --rubric abc` against the same `verified-flat.csv` input the script consumed, with the same `tier-{a,b,c}.csv` + `catch-all.csv` output contract. The Haiku prompt template (`fit-scoring.md`) is unchanged — it is the canonical source the skill reads at runtime.

**Net effect:**

- `plugins/marketing/scripts/tam-map/tier_and_segment.py` deleted.
- `anthropic>=0.40.0` dropped from `requirements.txt` (header `Changes:` line updated accordingly — see the file).
- `plugins/marketing/scripts/tam-map/spider_crawl.py` line 32 dead `ANTHROPIC_API_KEY = os.getenv(...)` removed alongside; module docstring updated to drop the stale "summarizes via Claude Haiku" claim the file never actually implemented. Header `Changes:` line records both BC-7050 + BC-6907.
- The eighth Brite tam-map runtime credential is eliminated; only the seven vendor credentials remain. Vault cleanup is an admin step documented in the BC-6907 PR description.

**Re-port action:** if a future upstream pull at a newer SHA still ships `scripts/tier_and_segment.py`, do not re-introduce the script — let it stay in upstream and continue absorbing its body into `icp-scoring` `abc` mode (prompt-only changes re-port to `fit-scoring.md`).

### `aiark-mcp.js` — endpoint drift fixes (BC-7011)

Upstream shipped this wrapper with an explicit `!! VERIFY BEFORE USING !!` warning admitting its endpoint paths, field names, and auth header form were "conventional guesses." BC-6906 Stage 2b live validation (2026-05-10) confirmed the wrapper returned nginx 404 in production — credential plumbing worked, the paths were wrong. BC-7011 verified the current API surface against `docs.ai-ark.com` (Company Search reference, Authentication doc, and `help.ai-ark.com/en/articles/112-how-does-the-api-work`) on 2026-05-11.

Four classes of drift fixed (full per-line detail in the wrapper source — `plugins/marketing/scripts/tam-map/aiark-mcp.js`):

1. **Base URL path component** updated to match the documented developer-portal namespace.
2. **Endpoint paths** `/search` and `/similarity` both collapse to a single canonical endpoint; the lookalike variant is driven by a request-body field rather than a separate URL.
3. **Auth header** updated to the documented form. See the wrapper source for the exact header name; `tools/integrations/ai-ark.md` § Auth carries the consumer-facing reference.
4. **Request body** shape rewritten to the documented top-level keys; pagination cursor swapped for integer-indexed pages with a server-capped page size.

One tool removed: `aiark_enrich` — AI Ark has no domain-keyed enrich endpoint on the developer portal as of 2026-05-11. The wrapper's pre-BC-7011 stub POSTed to a guessed path and returned 404 in production. The closest documented surface is Reverse People Lookup (email→person), which doesn't satisfy the domain→company-data shape the tool was named for.

**Validated:** live MCP smoke through `bw-run.sh` + the reloaded plugin (captured in the BC-7011 PR description).

**Re-port action:** if a future upstream pull at a newer SHA includes the same path/auth fixes, drop this local diff. If upstream restores an `aiark_enrich` tool because a new endpoint shipped, restore that handler. The `account` sub-schema (firmographic filter field names) is the one remaining "unknown" — if AI Ark publishes the full shape, re-map this wrapper's pass-through fields to match.

## Relationship to the broader marketing plugin

This is the second reference port into the marketing plugin. The first is `plugins/marketing/references/` (BC-5823, Revgrowth1/ai-gtm-workflows@`03b30e1`). The two ports are independent — different upstream repos, different pinned commits, different consumers — so they have separate `UPSTREAM.md` files. A future third reference port would follow the same pattern.

## Downstream consumers

- **Not yet landed.** BC-5947 wires the three MCP servers (Spider.cloud, AI Ark, Discolike) referenced by the ported scripts. BC-5832 (tam-mapping skill) and BC-5831 (icp-scoring skill) consume these references. BC-5950 adds the `/marketing:tam-map` orchestration command.
- **Policy grounding.** `docs/research/tam-map-port-policy.md` (BC-5945) locks the five policy decisions every downstream tam-map issue depends on — including enrichment pluggability, Labs vertical priors, and the MCP-cap reframe.
