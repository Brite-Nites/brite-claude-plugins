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
| `spider_crawl.py` | `scripts/spider_crawl.py` | Verbatim (+ 5-line `#` header after shebang) |
| `enrich_waterfall.py` | `scripts/enrich_waterfall.py` | Verbatim (+ 5-line `#` header) + local fix (BC-7051) — see § Local deviations |
| `verify_smtp.py` | `scripts/verify_smtp.py` | Verbatim (+ 5-line `#` header) + local fix (BC-7051) — see § Local deviations |
| `tier_and_segment.py` | `scripts/tier_and_segment.py` | Verbatim (+ 5-line `#` header after shebang) |
| `aiark-mcp.js` | `scripts/aiark-mcp.js` | Verbatim (+ 5-line `//` header) + endpoint-drift fixes (BC-7011) — see § Local deviations |
| `discolike-mcp.js` | `scripts/discolike-mcp.js` | Verbatim (+ 5-line `//` header + verification comment for BC-7011 — no functional drift) |
| `package.json` | `scripts/package.json` | Verbatim (+ top-level `_source` + `_license` + `_ported` JSON fields — see § JSON attribution exception) |
| `requirements.txt` | `scripts/requirements.txt` | Verbatim (+ 5-line `#` header prepended) |

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
