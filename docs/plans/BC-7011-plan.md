# BC-7011 — Fix AI Ark endpoint drift in `aiark-mcp.js`

**Linear:** https://linear.app/brite-nites/issue/BC-7011
**Branch:** `holden/bc-7011-aiark-endpoint-drift`
**Worktree:** `.claude/worktrees/bc-7011/`

## Context (one paragraph)

`plugins/marketing/scripts/tam-map/aiark-mcp.js` was ported verbatim from upstream tam-map@`9f5c72e74b` with an explicit `!! VERIFY BEFORE USING !!` warning admitting the endpoint paths, field names, and auth header form were "conventional guesses." BC-6906 Stage 2b live validation (2026-05-10) confirmed `aiark_search` returns nginx 404 — credential plumbing works, the wrapper's path is wrong. This issue closes that gap.

## What docs.ai-ark.com says (verified 2026-05-11)

Discovered by traversing `docs.ai-ark.com/{reference,docs}` and `help.ai-ark.com/en/articles/112`. Endpoints + auth:

| Concern | Wrapper today | Verified upstream |
|---|---|---|
| Base URL | `https://api.ai-ark.com/v1` | `https://api.ai-ark.com/api/developer-portal/v1` |
| Company search path | `POST /search` | `POST /companies` |
| Auth header | `Authorization: Bearer <key>` | `X-TOKEN: <key>` (no prefix) |
| Request top-level keys | `{filters, limit}` | `{account, lookalikeDomains, lists, page, size}` |
| Pagination | `page_token` (cursor) | `page` (integer, zero-based) + `size` (0–100) |
| Lookalike endpoint | `POST /similarity` | Same `/companies` endpoint via `lookalikeDomains: [...]` (≤5) |
| Enrich-by-domain endpoint | `POST /enrich` | Not documented anywhere on docs.ai-ark.com or help.ai-ark.com. Closest documented surface is `Reverse People Lookup` (email→person, not domain→company). |

**Sources** (for the PR description):
- `https://docs.ai-ark.com/reference/company-search-1` — `POST https://api.ai-ark.com/api/developer-portal/v1/companies`, body `{account, lookalikeDomains, lists, page, size}`, rate-limited 5 rps / 300 rpm / 18 000 rph.
- `https://docs.ai-ark.com/docs/authentication` — `X-TOKEN` header, no Bearer prefix.
- `https://help.ai-ark.com/en/articles/112-how-does-the-api-work` — confirms four products (Company Search, People Search, Reverse People Lookup, Mobile Finder); no enrich-by-domain surface.

## Downstream caller audit (already done in planning phase)

`grep -rn "aiark_enrich\|aiark_similarity\|aiark_search" plugins/ docs/` shows:
- Only `plugins/marketing/scripts/tam-map/aiark-mcp.js` defines them.
- `plugins/marketing/commands/setup-tam-map.md:203` calls `aiark_search` for a 1-result probe — stays compatible.
- `plugins/marketing/tools/integrations/ai-ark.md` documents all three tools — needs update (T6).
- `docs/plans/BC-5947-plan.md` and `docs/precedents/BC-5946.md` reference tool names in prose — no runtime impact; left alone.
- No runtime caller of `aiark_enrich` or `aiark_similarity` exists. Removing `aiark_enrich` is safe.

## Plan

### T1 — Repo recon for Discolike audit baseline

**Goal**: confirm current Discolike API URL + auth scheme before touching the wrapper.

**Steps**:
1. WebFetch `https://api.discolike.com/v1/docs/api/endpoints/discover/` (the URL the wrapper's inline comment cites).
2. Capture: base URL, method, auth header (verify `x-discolike-key` still correct), the documented query-param names (`icp_text`, `country`, `category`, `employee_range`, `min_digital_footprint`, `max_records`, `offset`, `phrase_match`, `domain`).
3. Note any drift in a scratch comment block at the top of the plan (this section).

**Verify**: produced a written list of "matches upstream wrapper" vs "drifted." Stage 2b smoke ran green for `discolike_search`, so expectation is mostly-matches.

**Files touched**: none (research only).

### T2 — Rewrite `aiark-mcp.js`: base URL + path + auth header + request shape

**Goal**: fix the four causes of the 404/auth-mismatch chain.

**Steps** (single Edit, atomic):
1. `BASE_URL` constant: change `https://api.ai-ark.com/v1` → `https://api.ai-ark.com/api/developer-portal/v1`.
2. Auth header in `aiarkPost`: `Authorization: Bearer ${AIARK_API_KEY}` → `X-TOKEN: ${AIARK_API_KEY}` (delete Bearer prefix; rename key).
3. `aiark_search` handler: switch path to `/companies`, restructure body to `{account, page, size}`. Map user inputs:
   - `industries[]`, `regions[]`, `employee_min`, `employee_max` → pass through as `account.{industries,regions,employee_min,employee_max}`. (The `account` sub-schema is not fully published; pass these as documented best-effort and surface any 400-body schema error to the caller. Conservative — fields the server doesn't recognize are typically ignored, not 400'd.)
   - `limit` (number, default 100) → top-level `size` (clamped to 0–100 because docs cap there). Add `page: 0`.
4. `aiark_similarity` handler: switch path to `/companies`, body `{lookalikeDomains: args.seed_domains, page: 0, size: clamp(args.limit ?? 100, 0, 100)}`. Document in tool description: "lookalike via Company Search API; max 5 seed domains per request."
5. Cap `aiark_similarity.inputSchema.properties.seed_domains.maxItems = 5` (docs constraint).
6. Cap `size` clients-side; surface a friendly error if `limit > 100`.

**Verify**: re-read the diff; confirm both handler branches POST to `/companies` and pass the new top-level body shape.

**Files touched**: `plugins/marketing/scripts/tam-map/aiark-mcp.js`.

### T3 — Remove `aiark_enrich` tool

**Goal**: the endpoint doesn't exist upstream; preserve port shape only where the upstream surface exists.

**Steps**:
1. Delete the `aiark_enrich` entry from the `ListToolsRequestSchema` handler.
2. Delete the `aiark_enrich` branch in the `CallToolRequestSchema` handler.
3. In the file's docstring (the `Tools:` block), drop the `aiark_enrich` line and add an explicit `// Not exposed:` comment naming the removed tool and the reason ("AI Ark has no domain-keyed enrich endpoint as of docs.ai-ark.com verified 2026-05-11; closest documented surface is Reverse People Lookup which is email-keyed").

**Verify**: `grep -n "aiark_enrich" plugins/marketing/scripts/tam-map/aiark-mcp.js` returns only the `Not exposed:` doc comment.

**Files touched**: `plugins/marketing/scripts/tam-map/aiark-mcp.js`.

### T4 — Rewrite the `!! VERIFY BEFORE USING !!` warning block

**Goal**: replace the upstream warning with a verified-against-docs note. The acceptance criterion explicitly requires resolving this warning.

**Steps**:
1. Replace the 14-line `!! VERIFY BEFORE USING !!` block (lines 14–22 in the current file) with a `Verified` block stating:
   - Verified against `docs.ai-ark.com/reference/company-search-1` + `docs.ai-ark.com/docs/authentication` on 2026-05-11.
   - Base URL, auth header, two endpoints (search + lookalike) — listed.
   - One open caveat: `account` sub-schema is partially documented; passing unknown sub-fields is server-side ignored, not 400'd. A future doc release may rename them.
2. Update the `Tools:` listing inside the docstring to reflect the two remaining tools.

**Verify**: `grep -n "VERIFY BEFORE USING" plugins/marketing/scripts/tam-map/aiark-mcp.js` returns no matches.

**Files touched**: `plugins/marketing/scripts/tam-map/aiark-mcp.js`.

### T5 — Audit `discolike-mcp.js` against current Discolike API (depends on T1)

**Goal**: per issue scope, audit Discolike for the same drift class. Stage 2b returned 200 — expectation is no change.

**Steps**:
1. Diff the T1 findings against the wrapper's current values: `BASE_URL = "https://api.discolike.com/v1/discover"`, header `x-discolike-key`, GET, params `icp_text/country/category/employee_range/min_digital_footprint/max_records/offset/phrase_match/domain`.
2. If T1 confirms zero drift: leave wrapper untouched. Add a one-line comment at top of `discolike-mcp.js`: `// Verified against docs 2026-05-11 (BC-7011). No drift.`
3. If T1 found drift: apply edits parallel to T2's structure.

**Verify**: produced explicit confirm-or-edit decision tied to the T1 evidence.

**Files touched**: `plugins/marketing/scripts/tam-map/discolike-mcp.js` (header-comment update at minimum; full edits only if drift found).

### T6 — Update `plugins/marketing/tools/integrations/ai-ark.md`

**Goal**: doc parity with the verified wrapper. The current file has a `⚠ Unverified upstream endpoint schema` paragraph (lines around 9–11) and a tools table (lines 59–61) listing the three old tools with old paths.

**Steps**:
1. Replace the `⚠ Unverified upstream endpoint schema` paragraph with a `Verified 2026-05-11` block citing BC-7011 and the docs URLs.
2. Update the tools table:
   - `aiark_search` → `POST /api/developer-portal/v1/companies` (firmographic via `account` body)
   - `aiark_similarity` → same path with `lookalikeDomains` array (≤5)
   - Drop the `aiark_enrich` row; add a note: "Not exposed — AI Ark has no domain-keyed enrich endpoint."
3. Auth section: `X-TOKEN` header, no prefix.

**Verify**: re-read the file end-to-end; the doc no longer contradicts the wrapper.

**Files touched**: `plugins/marketing/tools/integrations/ai-ark.md`.

### T7 — Update `references/tam/UPSTREAM.md` local-deviations section

**Goal**: this is now a non-trivial fork-from-upstream — must be recorded in the `§ Local deviations from upstream 9f5c72e74b` section (which already houses the BC-7051 Python fixes).

**Steps**:
1. Add a new sub-heading: `### aiark-mcp.js — endpoint drift fixes (BC-7011)`.
2. Body: explain the four classes of drift (base URL, path, auth, request shape) and the `aiark_enrich` removal. Cite the docs URLs.
3. Re-port action: `if a future upstream pull at a newer SHA includes the same path/auth fixes, drop this local diff. If upstream restores aiark_enrich because a new endpoint shipped, restore that handler.`

**Verify**: the manifest still says "Verbatim port" for `aiark-mcp.js` in the per-file manifest table — leave that "Verbatim" claim alone but add an `(with local deviations — see §)` suffix to the row.

**Files touched**: `plugins/marketing/references/tam/UPSTREAM.md`.

### T8 — Bump plugin version (BC-6000 same-commit rule)

**Goal**: client plugin-cache invalidation. Must be in the SAME commit as the wrapper edits.

**Steps**:
1. `plugins/marketing/.claude-plugin/plugin.json`: bump `version` — patch level (current `0.3.31` → `0.3.32`).
2. `.claude-plugin/marketplace.json`: bump the `marketing` plugin entry to the same version.
3. Stage both files together with T2/T3/T4/T5/T6/T7 edits.

**Verify**: `git diff --stat` shows both `.json` files changed; versions match.

**Files touched**: `plugins/marketing/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.

### T9 — Smoke-test all surviving tools live (user-authorized)

**Goal**: acceptance criterion — capture call+response evidence for the PR.

**Note**: Auto-mode classifier blocks raw `curl + bw-resolved-key` patterns. Smoke runs through the MCP wrapper itself (production path) instead, which means:
1. Restart Claude Code OR `/reload-plugins` so the new wrapper version loads.
2. Call `mcp__plugin_marketing_aiark__aiark_search` with `{industries: ["software"], limit: 1}` — capture response.
3. Call `mcp__plugin_marketing_aiark__aiark_similarity` with `{seed_domains: ["stripe.com"], limit: 1}` — capture response.
4. Call `mcp__plugin_marketing_discolike__discolike_search` with `{icp_text: "stripe.com", max_records: 1}` — capture response.
5. Call `mcp__plugin_marketing_discolike__discolike_lookalike` with `{domain: ["stripe.com"], max_records: 1}` — capture response.

**Failure modes** (and what we do):
- HTTP 200 with body — record verbatim for PR description, criterion met.
- HTTP 400 with schema-validation body — refine T2 `account` sub-schema mapping, re-run.
- HTTP 401 — auth header still wrong, re-investigate T2 step 2.
- HTTP 404 — path still wrong, re-investigate T2 step 1.

**Verify**: PR description carries one successful call+response per tool, plus the response status code.

**Files touched**: none directly; may iterate on T2 if 400 surfaces a schema gap.

### T10 — Commit + push + open PR

**Goal**: ship the work.

**Steps**:
1. Single commit: all of T2–T8 edits.
2. Push branch `holden/bc-7011-aiark-endpoint-drift`.
3. Open PR with body that includes the four-row "what changed" table from above and the T9 smoke evidence.
4. Skip `/workflows:review` until after smoke evidence is captured (T9 may iterate).

**Verify**: PR URL captured; Linear issue auto-linked via GitHub-integration on the PR description.

**Files touched**: none — git operation only.

## Out-of-scope (explicit, from issue body)

- Re-architecting `aiark-mcp.js` or `discolike-mcp.js` (preserve port shape).
- Migrating to a different vendor.
- Credential management (BC-6906 territory).
- Adopting AI Ark's official upstream MCP server — separate decision; would require an `/workflows:scope` session and ADR (the surface footprint is different, and the wrapper is wired into `bw-run.sh` + `setup-tam-map.md` Phase 6 troubleshooting).

## Risk register

- **`account` sub-schema partially documented.** Mitigation: pass-through user input + surface 400 body to caller. Worst case: smoke iteration in T9 refines mapping.
- **Removing `aiark_enrich` is API-breaking for any caller.** Mitigation: grep already confirmed no callers exist (planning step above).
- **Plugin cache.** Mitigation: T8 enforces the same-commit version bump.
