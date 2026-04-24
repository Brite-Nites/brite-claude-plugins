---
issue: BC-5946
title: Port tam-map references + CLI wrapper scripts + tool integration guides to plugins/marketing/
branch: holden/bc-5946-port-tam-map-references-cli-wrappers
worktree: .claude/worktrees/bc-5946
upstream: Revgrowth1/tam-map@9f5c72e74b (MIT)
blockedBy: BC-5945 (merged as PR #199)
blocks: BC-5832, BC-5831, BC-5947
status: draft — awaiting user approval
date: 2026-04-24
---

# BC-5946 Plan — tam-map port

## Goal

Physically port 9 wrapper scripts (7 `.py` + 2 `.js`) + 2 metadata files (`package.json`, `requirements.txt`) + 3 prompt templates + 1 worked example + 7 per-provider integration guides from `Revgrowth1/tam-map@9f5c72e74b` (MIT) into the marketing plugin. Pure port — no Brite-specific edits, no skill creation, no MCP wiring. BC-5947 wires MCPs; BC-5832 layers Brite adaptation.

## Complexity decision

**Skipping extended brainstorming after 4 clarification questions.** The issue has a full Explore → Plan → Execute → Verify spec; only 4 open questions existed (header strategy, non-MCP surface, JSON attribution, LICENSE). Decisions locked below.

## Locked decisions (from brainstorm)

1. **Integration-guide structure** — 12 sections per guide. 9 from `_template.md` + 3 new (`Cost`, `Retry`, `Brite usage`). Two renames: `Rate limits and quotas` → `Rate limits`; `Known gotchas` → `Failure modes`. All 6 grep targets in Verify #6 (`Auth`, `Rate Limits`, `Cost`, `Failure Modes`, `Retry`, `Brite Usage`) appear as H2 headers.
2. **Non-MCP providers** (IcyPeas, BlitzAPI, Prospeo, MillionVerifier) — document env-var + CLI surface. `Registration` lists required env var + `.env.example` entry. `Tool inventory` enumerates Python wrapper functions with parameters.
3. **package.json attribution** — JSON can't carry comments. Add `"_source": "Revgrowth1/tam-map@9f5c72e74b"` and `"_license": "MIT"` fields at top level; explicit Verify exception for `.json` files. All other files use `#` or `//` header comments.
4. **LICENSE** — URL-link from UPSTREAM.md, do not copy in-tree. Matches BC-5823 precedent.

## Source manifest (upstream → target)

### Scripts (`plugins/marketing/scripts/tam-map/` — new directory)

| # | Upstream path | Target path | Attribution mode |
|---|---|---|---|
| 1 | `scripts/aiark_client.py` | `plugins/marketing/scripts/tam-map/aiark_client.py` | 5-line `#` header |
| 2 | `scripts/discolike_client.py` | `plugins/marketing/scripts/tam-map/discolike_client.py` | 5-line `#` header |
| 3 | `scripts/icypeas_client.py` | `plugins/marketing/scripts/tam-map/icypeas_client.py` | 5-line `#` header |
| 4 | `scripts/spider_crawl.py` | `plugins/marketing/scripts/tam-map/spider_crawl.py` | 5-line `#` header |
| 5 | `scripts/enrich_waterfall.py` | `plugins/marketing/scripts/tam-map/enrich_waterfall.py` | 5-line `#` header |
| 6 | `scripts/verify_smtp.py` | `plugins/marketing/scripts/tam-map/verify_smtp.py` | 5-line `#` header |
| 7 | `scripts/tier_and_segment.py` | `plugins/marketing/scripts/tam-map/tier_and_segment.py` | 5-line `#` header |
| 8 | `scripts/aiark-mcp.js` | `plugins/marketing/scripts/tam-map/aiark-mcp.js` | 5-line `//` header |
| 9 | `scripts/discolike-mcp.js` | `plugins/marketing/scripts/tam-map/discolike-mcp.js` | 5-line `//` header |
| 10 | `scripts/package.json` | `plugins/marketing/scripts/tam-map/package.json` | `_source` + `_license` fields |
| 11 | `scripts/requirements.txt` | `plugins/marketing/scripts/tam-map/requirements.txt` | 5-line `#` header |

**Header template (Python / JS / txt):**

```
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/<filename>
# Changes: verbatim port, no functional edits
```

(Use `//` for `.js` files.)

### References (`plugins/marketing/references/tam/` — new directory)

| # | Upstream path | Target path | Attribution mode |
|---|---|---|---|
| 12 | `prompts/icp-definition.md` | `plugins/marketing/references/tam/icp-definition.md` | Verbatim — YAML frontmatter naming upstream path + license |
| 13 | `prompts/fit-scoring.md` | `plugins/marketing/references/tam/fit-scoring.md` | Verbatim + frontmatter |
| 14 | `prompts/segment-routing.md` | `plugins/marketing/references/tam/segment-routing.md` | Verbatim + frontmatter |
| 15 | `examples/roofing-contractors-tx.md` | `plugins/marketing/references/tam/examples/roofing-contractors-tx.md` | Verbatim + frontmatter |
| 16 | — | `plugins/marketing/references/tam/UPSTREAM.md` | New Brite attribution file |

**Frontmatter template (added to each verbatim markdown file):**

```yaml
---
source: Revgrowth1/tam-map@9f5c72e74b
upstream_path: prompts/<filename>
license: MIT
ported: 2026-04-24
---
```

**`plugins/marketing/references/tam/UPSTREAM.md` shape** — matches `plugins/marketing/references/UPSTREAM.md`:

- `# Upstream provenance` heading
- Pinned commit (SHA `9f5c72e74b`, short `9f5c72e7`)
- License (MIT) with permalinked URL to upstream LICENSE at commit
- Per-file manifest table (4 verbatim files listed)
- Sync model (fork-by-default, no automatic pulls)
- Attribution convention (`source:` frontmatter block)

### Integration guides (`plugins/marketing/tools/integrations/` — 7 new files)

| # | File | Category | MCP? |
|---|---|---|---|
| 17 | `spider-cloud.md` | Web crawl / content extraction | Yes (native HTTP MCP) |
| 18 | `ai-ark.md` | Company discovery (keyword → firmographic) | Yes (stdio wrapper) |
| 19 | `discolike.md` | Lookalike expansion from peer-venue seeds | Yes (stdio wrapper) |
| 20 | `icypeas.md` | Email verification (fast, partial) | No — Python client |
| 21 | `blitz-api.md` | Owner discovery at unlimited credits, 5 req/s | No — Python client |
| 22 | `prospeo.md` | Email enrichment fallback | No — Python client |
| 23 | `millionverifier.md` | Bulk email verification (high-volume) | No — Python client |

**Each guide's 12-section shape (new structure):**

1. `## Purpose`
2. `## Consumed by`
3. `## Auth` ← grep target
4. `## Registration`
5. `## Tool inventory` (MCP) **or** `## CLI surface` (non-MCP, with note)
6. `## Rate limits` ← grep target (renamed from `Rate limits and quotas`)
7. `## Cost` ← grep target (NEW — credits / per-call pricing / free tier)
8. `## Failure modes` ← grep target (renamed from `Known gotchas`)
9. `## Retry` ← grep target (NEW — backoff guidance at guide level, not procedural skill logic)
10. `## Brite usage` ← grep target (NEW — Brite-specific invocation + which scripts wrap it)
11. `## Related skills`
12. `## Last verified`

## Task list

### Pre-flight (already done in Explore phase)

- [x] Read `docs/research/tam-map-port-policy.md` (BC-5945 locked policy)
- [x] Read `plugins/marketing/references/UPSTREAM.md` (template)
- [x] Read `plugins/marketing/tools/integrations/_template.md`
- [x] Read `plugins/marketing/tools/integrations/email-bison.md` (reference impl)
- [x] Read `docs/guides/skill-tool-integration-pattern.md` (6-item PR checklist)
- [x] Inventory upstream commit `9f5c72e74b` via `gh api repos/Revgrowth1/tam-map/contents/...`
- [x] Worktree created at `.claude/worktrees/bc-5946`, branch `holden/bc-5946-port-tam-map-references-cli-wrappers`, baseline `validate.sh` → 0 errors / 16 warnings

### Pass 1 — Scripts port (11 files)

1. `mkdir -p plugins/marketing/scripts/tam-map/`
2. Fetch each of 11 upstream files at SHA `9f5c72e74b` via `gh api repos/Revgrowth1/tam-map/contents/scripts/<filename>?ref=9f5c72e74b` with `Accept: application/vnd.github.raw`. Write verbatim to target + prepend header comment (or JSON `_source`/`_license` fields for `package.json`).
3. Verify file count == 11; verify `grep -l "Revgrowth1/tam-map@9f5c72e74b" plugins/marketing/scripts/tam-map/*.py plugins/marketing/scripts/tam-map/*.js plugins/marketing/scripts/tam-map/requirements.txt` returns 10 files (JSON excluded).
4. Verify `jq '._source' plugins/marketing/scripts/tam-map/package.json` returns `"Revgrowth1/tam-map@9f5c72e74b"`.

### Pass 2 — References port (5 files)

5. `mkdir -p plugins/marketing/references/tam/examples/`
6. Fetch 4 markdown files (3 prompts + 1 example) verbatim; prepend YAML frontmatter (source, upstream_path, license, ported).
7. Author `plugins/marketing/references/tam/UPSTREAM.md` matching `plugins/marketing/references/UPSTREAM.md` shape.
8. Verify file count == 5; verify UPSTREAM.md cites SHA `9f5c72e74b`; verify each of 4 ported markdown files has frontmatter `source: Revgrowth1/tam-map@9f5c72e74b`.

### Pass 3 — Integration guides (7 files)

9. Author `spider-cloud.md` (MCP, native HTTP). Registration block includes `.env.example` env var.
10. Author `ai-ark.md` (MCP, stdio wrapper). Registration block references `scripts/tam-map/aiark-mcp.js` + env vars consumed.
11. Author `discolike.md` (MCP, stdio wrapper). Registration references `scripts/tam-map/discolike-mcp.js`.
12. Author `icypeas.md` (non-MCP). `## Registration` → `N/A — called from scripts/tam-map/icypeas_client.py; requires env var ICYPEAS_API_KEY`. `## Tool inventory` → Python functions.
13. Author `blitz-api.md` (non-MCP). Same shape as icypeas.md.
14. Author `prospeo.md` (non-MCP). Same shape.
15. Author `millionverifier.md` (non-MCP). Same shape. Consumed-by: `scripts/tam-map/verify_smtp.py`.
16. Verify each of 7 files has all 6 grep-target headers:
    ```bash
    for f in spider-cloud ai-ark discolike icypeas blitz-api prospeo millionverifier; do
      for h in "^## Auth$" "^## Rate limits$" "^## Cost$" "^## Failure modes$" "^## Retry$" "^## Brite usage$"; do
        grep -c -E "$h" plugins/marketing/tools/integrations/$f.md || echo "MISS: $f / $h"
      done
    done
    ```

### Pass 4 — No-op (REGISTRY.md doesn't exist)

17. Skipped — `plugins/marketing/tools/integrations/REGISTRY.md` does not exist. Issue's Pass 4 was a conditional ("assuming it lists integrations"). Condition false.

### Final verification

18. Run `./scripts/validate.sh` — expect 0 errors. Warning count baseline == 16; any increase must be explained.
19. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — expect exit 0.
20. Cross-check issue Verify items 1–11 against shipped state (item 12 = `/workflows:review` runs in ship phase).

## Verification mapping to issue's Verify checklist

| # | Issue Verify criterion | Satisfied by |
|---|---|---|
| 1 | `plugins/marketing/scripts/tam-map/` contains exactly 11 files (7 .py, 2 .js, 1 json, 1 txt) | Pass 1 step 3 |
| 2 | Every ported script file has `# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)` header | Pass 1 step 3 (plus JSON exception in locked decision #3) |
| 3 | `plugins/marketing/references/tam/` contains exactly 5 files | Pass 2 step 8 |
| 4 | `UPSTREAM.md` cites `9f5c72e74b` + MIT + per-file table | Pass 2 step 7 |
| 5 | 7 integration guides exist matching `_template.md` shape | Pass 3 steps 9–15 |
| 6 | Each integration guide has 6 required H2 headers (Auth / Rate Limits / Cost / Failure Modes / Retry / Brite Usage) | Pass 3 step 16 |
| 7 | No Brite-specific imports in ported files | Verbatim policy enforced by port process |
| 8 | `./scripts/validate.sh` exits 0 | Final step 18 |
| 9 | `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0 | Final step 19 |
| 10 | PR opened, `Closes BC-5946` | `/workflows:ship` phase |
| 11 | `get_issue` after save shows description intact | `/workflows:ship` phase |
| 12 | `/workflows:review` thorough mode, 0 P1 findings | Review phase pre-ship |

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| `gh api` rate limits block 15+ raw-content fetches | Serial, not parallel fetches; cached via local files; total 15 files comfortably under 5000/hr authenticated limit |
| Upstream SHA drift between port and review | Plan pins `9f5c72e74b`; every Verify step re-cites the SHA; `UPSTREAM.md` owns the truth |
| Header comment on `requirements.txt` breaks `pip install` | pip allows `#` comments; safe. Verified by spec. |
| Non-MCP guide `Registration: N/A` may fail review agents expecting Registration detail | Locked decision #2 — document env-var + CLI surface instead of bare N/A |
| `_template.md` drift post-port (BC-5946 adds 3 new sections; template has 9) | Out of scope — noted in plan; follow-up issue if template canonicalization desired |
| `package.json` `_source`/`_license` fields may confuse `npm install` | `npm` ignores unknown top-level fields; safe. Existing OSS precedent (many packages). |

## Scope guardrails

Per `feedback_atomic_issues_for_agents.md` — this issue is atomic. Out of scope:

- MCP registration in `plugins/marketing/.mcp.json` → BC-5947
- `plugin.json` userConfig additions → BC-5947
- `/marketing:setup-tam-map` command → BC-5947
- `icp-scoring` skill authoring → BC-5831
- `tam-mapping` skill authoring → BC-5832
- Brite-adapted `{vertical}-icp.md` files → spun off or part of BC-5832
- `memory/MCP_cap_advisory.md` reframe → already shipped in BC-5945
- Clay-deprecated memory amendment → already shipped in BC-5945

## Rollback

The worktree is disposable. If the port needs to be abandoned:

1. `git -C /Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins worktree remove --force .claude/worktrees/bc-5946`
2. `git -C /Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins branch -D holden/bc-5946-port-tam-map-references-cli-wrappers`

No main-repo state mutated until `/workflows:ship` pushes.

## Next

Awaiting user plan approval. On approval, begin Pass 1.
