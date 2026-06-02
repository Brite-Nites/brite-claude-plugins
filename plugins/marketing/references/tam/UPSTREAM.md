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
| `examples/roofing-contractors-tx.md` | `examples/roofing-contractors-tx.md` | Adapted (frontmatter + BC-6907 § 6 skill-delegation + BC-12130 § 3 note) — see § Local deviations |

## Per-file manifest — scripts

| Target path (under `plugins/marketing/scripts/tam-map/`) | Upstream path | Verbatim vs adapted |
|----------------------------------------------------------|---------------|---------------------|
| `aiark_client.py` | `scripts/aiark_client.py` | **Removed** per BC-12130 — see § Local deviations |
| `discolike_client.py` | `scripts/discolike_client.py` | **Removed** per BC-12130 — see § Local deviations |
| `icypeas_client.py` | `scripts/icypeas_client.py` | Verbatim (+ 5-line `#` header after shebang) |
| `spider_crawl.py` | `scripts/spider_crawl.py` | Verbatim (+ 5-line `#` header) + local fix (BC-7050) — see § Local deviations |
| `enrich_waterfall.py` | `scripts/enrich_waterfall.py` | Verbatim (+ 5-line `#` header) + local fixes (BC-7051 async/sync split; BC-12128 BlitzAPI redesign re-application) — see § Local deviations |
| `verify_smtp.py` | `scripts/verify_smtp.py` | Verbatim (+ 5-line `#` header) + local fix (BC-7051) — see § Local deviations |
| `tier_and_segment.py` | `scripts/tier_and_segment.py` | **Removed** per BC-6907 — see § Local deviations |
| `aiark-mcp.js` | `scripts/aiark-mcp.js` | Verbatim (+ 5-line `//` header) + endpoint-drift fixes (BC-7011) + `aiark_search` account-filter sub-schema (BC-7157) — see § Local deviations |
| `discolike-mcp.js` | `scripts/discolike-mcp.js` | Verbatim (+ 5-line `//` header + verification comment for BC-7011 — no functional drift) |
| `package.json` | `scripts/package.json` | Verbatim (+ top-level `_source` + `_license` + `_ported` JSON fields — see § JSON attribution exception) |
| `requirements.txt` | `scripts/requirements.txt` | Verbatim (+ 5-line `#` header) + local change (BC-6907) — see § Local deviations |

## JSON attribution exception

`package.json` cannot carry comment-style headers (strict JSON). Attribution lives at the top of the file as three new string fields — `_source`, `_license`, `_ported` — following the OSS convention of underscore-prefixed extension fields that `npm` ignores. This manifest row is the canonical attribution; the `_source` field is the machine-readable counterpart.

## Sync model

**Fork-by-default.** We treat `plugins/marketing/scripts/tam-map/` and `plugins/marketing/references/tam/` as Brite content going forward. **No automatic upstream pulls.**

If upstream improvements are ever pulled, the operation is manual:

1. Diff the target file against the pinned SHA (e.g., `git show 9f5c72e74b:scripts/spider_crawl.py` against the local file, ignoring the Brite attribution header).
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

### `aiark_client.py` + `discolike_client.py` — removed (dead ported clients, never wired) (BC-12130)

Upstream ships `scripts/aiark_client.py` and `scripts/discolike_client.py` as standalone Python CLI discovery wrappers. Brite never wired either into its pipeline: the live AI Ark and Discolike integrations are the stdio MCP wrappers (`aiark-mcp.js`, `discolike-mcp.js`), which the `tam-mapping` skill and `/marketing:setup-tam-map` actually use. The two `*_client.py` files sat as verbatim ports carrying stale, pre-drift API shapes — e.g. `aiark_client.py` still POSTed `/v1/search` with `Authorization: Bearer` and a `filters{}` body, wrong on every axis vs the BC-7011 / BC-7157-verified contract (`POST /companies`, `X-TOKEN`, `account`/`page`/`size`). Beyond dead weight, the divergent `aiark_client.py` shape actively obscured the 2026-05-31 aiark diagnosis. Confirmed zero runtime callers (no Python `import`, no skill/command invocation) before removal.

**Net effect:**

- `plugins/marketing/scripts/tam-map/aiark_client.py` deleted.
- `plugins/marketing/scripts/tam-map/discolike_client.py` deleted.
- Per-file manifest rows above marked **Removed**.
- Active references updated to the surviving MCP wrappers: `skills/tam-mapping/SKILL.md` provider table (drops the `*_client.py` halves, keeps `aiark-mcp.js` / `discolike-mcp.js`); `tools/integrations/ai-ark.md` + `discolike.md` "Consumed by" lists (drop the `*_client.py` bullets).
- `icypeas_client.py` is **untouched** — it shares the `_client.py` suffix but is an **active** CLI script (SKILL.md provider table + the env-var table).
- The example `references/tam/examples/roofing-contractors-tx.md` (§ "3. Discovery") still shows upstream's `python scripts/aiark_client.py` / `discolike_client.py` invocations. A **Brite note** was added inline at that block pointing to the MCP wrappers (Brite's actual aiark/discolike path) and to **BC-12278** (full example rewrite). That example was **already** Brite-adapted — BC-6907 reworked § 6 to the in-session `icp-scoring` skill delegation — so its manifest row above is corrected here from "Verbatim" to **Adapted** (the label had been stale since BC-6907). The `icypeas_client.py` invocation in the same block remains valid (icypeas is still a CLI script). A faithful end-to-end rewrite — command name (§ 1 `/marketing:tam-map`), MCP-driven discovery (§ 3), and the JSONL data-flow contract — is tracked in **BC-12278**.

**Re-port action:** if a future upstream pull at a newer SHA still ships `scripts/aiark_client.py` / `scripts/discolike_client.py`, do **not** re-introduce them — the MCP wrappers (`aiark-mcp.js`, `discolike-mcp.js`) are the Brite integrations. Treat any aiark/discolike API-shape drift as a wrapper (`*-mcp.js`) fix, per BC-7011 / BC-7157.

### `aiark-mcp.js` — endpoint drift fixes (BC-7011)

Upstream shipped this wrapper with an explicit `!! VERIFY BEFORE USING !!` warning admitting its endpoint paths, field names, and auth header form were "conventional guesses." BC-6906 Stage 2b live validation (2026-05-10) confirmed the wrapper returned nginx 404 in production — credential plumbing worked, the paths were wrong. BC-7011 verified the current API surface against `docs.ai-ark.com` (Company Search reference, Authentication doc, and `help.ai-ark.com/en/articles/112-how-does-the-api-work`) on 2026-05-11.

Four classes of drift fixed (full per-line detail in the wrapper source — `plugins/marketing/scripts/tam-map/aiark-mcp.js`):

1. **Base URL path component** updated to match the documented developer-portal namespace.
2. **Endpoint paths** `/search` and `/similarity` both collapse to a single canonical endpoint; the lookalike variant is driven by a request-body field rather than a separate URL.
3. **Auth header** updated to the documented form. See the wrapper source for the exact header name; `tools/integrations/ai-ark.md` § Auth carries the consumer-facing reference.
4. **Request body** shape rewritten to the documented top-level keys; pagination cursor swapped for integer-indexed pages with a server-capped page size.

One tool removed: `aiark_enrich` — AI Ark has no domain-keyed enrich endpoint on the developer portal as of 2026-05-11. The wrapper's pre-BC-7011 stub POSTed to a guessed path and returned 404 in production. The closest documented surface is Reverse People Lookup (email→person), which doesn't satisfy the domain→company-data shape the tool was named for.

**Validated:** live MCP smoke through `bw-run.sh` + the reloaded plugin (captured in the BC-7011 PR description).

**Re-port action:** if a future upstream pull at a newer SHA includes the same path/auth fixes, drop this local diff. If upstream restores an `aiark_enrich` tool because a new endpoint shipped, restore that handler. The `account` sub-schema (firmographic filter field names) was the one remaining "unknown" — resolved in BC-7157 (see next section).

### `aiark-mcp.js` — `aiark_search` account-filter sub-schema (BC-7157)

BC-7011 corrected AI Ark's envelope (base URL, `POST /companies`, `X-TOKEN`, top-level `{account, lookalikeDomains, page, size}`) but left the `account` **interior** unmapped — the wrapper passed `account.industries`/`regions` as bare `string[]` and `employee_min/max` as scalars. Three of four smoke calls were green; `aiark_search` with any real filter returned `400 "request not readable"`. BC-7011 knowingly deferred this gap to BC-7157.

**Root cause (verified live 2026-05-31):** the backend is Spring Boot and every `AccountFilter` field is an `all`/`any` → `include`/`exclude` **object** tree, not a list. A bare `string[]`/scalar (even an empty `[]`) can't bind to the target POJO, so Jackson raises `HttpMessageNotReadableException` → `400 "request not readable"`. Unknown field **names** are still silently ignored — which is why earlier guesses (`sectors`, `naics_codes`, …) returned the unfiltered default rather than 400ing, and why the diagnosis was non-obvious.

**Schema source:** the public reference page renders `account` only as "object", but ReadMe's markdown export at `docs.ai-ark.com/reference/company-search-1.md` embeds the full OpenAPI spec (request example + `#/components/schemas/AccountFilter`). The springdoc/swagger endpoints under `…/developer-portal/v1/` return `401` to the `X-TOKEN` API key (they are web-session-gated), so the `.md` export — not a live spec endpoint — is the obtainable source.

**Mapping applied to `aiark_search`** (the three surfaced filters):

| wrapper input | AI Ark `account` field | shape sent |
|---|---|---|
| `industries: string[]` | `industries` | `{ any: { include: { mode: "WORD", content: [...] } } }` |
| `regions: string[]` | `location` (note: **not** `regions`) | `{ any: { include: [...] } }` — plain string list of country/region names ("United States", "Texas") |
| `employee_min` / `employee_max` | `employeeSize` | `{ type: "RANGE", range: [{ start, end }] }` — half-open ranges accepted |

The wrapper builds `account` conditionally — only populating sub-fields the caller filtered on; an empty `account {}` remains a valid unfiltered search. `mode` is fixed to `WORD` (the docs' industries example default; `STRICT` returned identical results in verification). Input-schema param names (`industries`, `regions`, `employee_min`, `employee_max`, `limit`) are unchanged for consumer compatibility; `regions` maps onto the `location` field.

**Validated (live, via `bw-run.sh`, captured in the BC-7157 PR):** driving the freshly-spawned wrapper over stdio — `industries:["software development"]` → 200, `totalElements` 2,236,141 (was 70,841,359 unfiltered), all results `software development` (Amazon, Google, Microsoft…); combined `software + United States + 50–500 employees` → 200, `totalElements` 9,925, all software; `aiark_similarity` regression (`stripe.com`) → 200 with records. Pre-fix the same calls returned `400 "request not readable"`.

**Re-port action:** if a future upstream pull at a newer SHA maps the `account` interior the same way, drop this local diff. If AI Ark changes the `AccountFilter` shape, re-map against the then-current `…/reference/company-search-1.md` export.

### `enrich_waterfall.py` — BlitzAPI redesign re-application (BC-12128)

The wrapper used BlitzAPI as the primary owner-discovery provider via a single call `POST https://api.blitz-api.ai/v2/enrich {website}` → `{email}` with `Authorization: Bearer`. As of **2026-05-31** that endpoint returns an auth-independent `railway-edge 404`: BlitzAPI **redesigned its API** (now served by ElysiaJS) — a vendor redesign, not endpoint drift.

**New contract (verified live 2026-05-31 against the OpenAPI spec at `api.blitz-api.ai/openapi`):**
- **Auth:** `x-api-key: <key>` header (was `Authorization: Bearer`). The key is credit-metered (1000/period, 5 req/s observed) — the prior "unlimited credits" assumption no longer holds.
- **The one-shot `/v2/enrich` is gone.** Enrichment is decomposed into granular `/v2/enrichment/*` endpoints plus people search under `/v2/search/*`.

**Re-application (preserves the `blitz_enrich(company) → {email}|None` contract + the Blitz→Prospeo→(MillionVerifier) waterfall + JSONL I/O + the BC-7051 async/sync fix):** `blitz_enrich` is rewritten internally as a 3-call chain:
1. `POST /v2/enrichment/domain-to-linkedin` `{domain}` → `company_linkedin_url`
2. `POST /v2/search/employee-finder` `{company_linkedin_url, job_level:["C-Team","VP","Director"], max_results:5}` → decision-makers (owner/C-level first)
3. `POST /v2/enrichment/email` `{person_linkedin_url}` → work email — iterated over candidates until one resolves.

A new `_blitz_post` helper centralizes `x-api-key` auth + a 5 req/s throttle and **logs every non-200/error to stderr** (the pre-BC-12128 code swallowed non-200s silently with a bare `return None` — which is how this endpoint death went unnoticed). A `_clean_domain` helper normalizes full-URL domain fields to a bare host. Owner-email hit-rate is company-dependent (the first decision-maker often has no findable email); misses fall through to the unchanged Prospeo path.

**Validated (live, via `bw-run.sh`, captured in the BC-12128 PR):** `enrich_waterfall.py` on one record `{"domain":"vercel.com"}` → `{"email":"behzod.sirjani@vercel.com","source":"blitzapi","person_name":"Behzod Sirjani"}`. Loud-logging confirmed (a non-resolving domain prints `[blitz] no company LinkedIn for …` to stderr instead of failing silently). The Prospeo fallback path and `verify_smtp.py` (MillionVerifier) are unchanged (0 diff); Prospeo confirmed live (HTTP 200).

**Re-port action:** Brite-owned (upstream `Revgrowth1/tam-map` never advanced past its scaffold). **BC-6170** (brite-enrichment MCP, 14-provider) supersedes this interim shell-script waterfall — when it lands, this chain can be retired for `brite_mcp` enrichment. If BlitzAPI changes its surface again, re-map against the then-current `api.blitz-api.ai/openapi` spec.

## Relationship to the broader marketing plugin

This is the second reference port into the marketing plugin. The first is `plugins/marketing/references/` (BC-5823, Revgrowth1/ai-gtm-workflows@`03b30e1`). The two ports are independent — different upstream repos, different pinned commits, different consumers — so they have separate `UPSTREAM.md` files. A future third reference port would follow the same pattern.

## Downstream consumers

- **Not yet landed.** BC-5947 wires the three MCP servers (Spider.cloud, AI Ark, Discolike) referenced by the ported scripts. BC-5832 (tam-mapping skill) and BC-5831 (icp-scoring skill) consume these references. BC-5950 adds the `/marketing:tam-map` orchestration command.
- **Policy grounding.** `docs/research/tam-map-port-policy.md` (BC-5945) locks the five policy decisions every downstream tam-map issue depends on — including enrichment pluggability, Labs vertical priors, and the MCP-cap reframe.
