# 001. Cross-Repo @Import Solution: Context7

**Status:** Accepted
**Date:** 2026-03-13

## Context

CLAUDE.md `@import` resolves relative to the importing file — no cross-repo support exists. The Brite Handbook (`Brite-Nites/handbook`, 659 markdown files) is a separate private repo containing company knowledge: strategy, values, entities, engineering processes, team structure, tools, operations, sales, marketing, and training. Project repos need this knowledge in their agent context so Claude Code can make decisions informed by company conventions and institutional memory.

This is the #1 technical blocker for the Brite Agent Platform (PRD Q25). Without cross-repo context, agents operating in project repos have no awareness of company-level decisions, org structure, or established patterns.

**Upstream features with no ETA:**
- [Org-wide CLAUDE.md (#14467)](https://github.com/anthropics/claude-code/issues/14467) — would allow a shared CLAUDE.md across all repos in an org
- [URL imports (#29072)](https://github.com/anthropics/claude-code/issues/29072) — would allow `@https://...` imports from any URL

**Constraints:**
- Solution must work today (no upstream feature dependency)
- Handbook is private (ruled out public-only tools)
- Must be team-adoptable (low per-developer friction)
- Data locality preferred but not required
- Must not permanently consume large context windows

## Options Considered

### Option 1: Context7 (Hosted Documentation Index)

Cloud-hosted service that indexes documentation from Git repos and exposes it via MCP tools (`resolve-library-id` → `query-docs`).

- **Pros**: Zero local resource usage, automatic freshness, MCP integration exists, SOC 2 compliance available
- **Cons**: Requires paid plan (Pro/Enterprise) for private repos — cost unknown, untestable without subscription. Data leaves the company. Designed for library documentation lookup, not company knowledge bases. No control over indexing or ranking. `resolve-library-id` flow is optimized for "which library is this" not "what does the company know about X"

### Option 2: QMD (Local Hybrid Search)

Local CLI tool that indexes markdown files using BM25 keyword search + vector embeddings + LLM-based query expansion and reranking. Built-in MCP server.

- **Pros**: Fully local (data never leaves machine), fast (0.2s keyword / 2.6s hybrid), GPU-accelerated on Apple Silicon, built-in MCP server, `qmd update --pull` for freshness, context annotations for tuning, converges with BRI-1960 (precedent search)
- **Cons**: 2.1GB disk for models (one-time), first-run downloads ~2GB, search quality has semantic drift (returns topically adjacent but wrong results ~40% of the time), each developer must install and index independently, Node.js runtime required

### Option 3: Copy-on-Setup (@imports via file copying)

Shell script copies essential handbook files (~10 files, ~1,100 lines) into the project directory. Files are @imported in CLAUDE.md and gitignored.

- **Pros**: Zero latency (always in context), zero runtime dependencies, simple to understand, excellent for operational context ("who are we", "how do we work"), gitignore-able
- **Cons**: ~25-30K tokens consumed per session permanently, doesn't scale beyond ~15 files, fails on any query not in the curated essentials, manual curation required, staleness risk (only refreshes when script re-runs), per-project copy script maintenance

### Option 4: Git Submodule

Mount the handbook repo as a submodule at `handbook/` in each project repo.

- **Pros**: Git-native, always available, @import works directly, version-pinnable
- **Cons**: Submodule UX is notoriously poor — stale HEADs, forgotten updates, CI complexity. Every clone must also clone 659 files. Cannot selectively import — all or nothing. Would need to @import individual files anyway (directory imports not supported)

### Option 5: Symlink

Symlink `~/handbook` into the project directory.

- **Pros**: Zero-copy, always fresh, simple
- **Cons**: Claude Code does not follow symlinks for @import resolution. Machine-specific paths break portability. CI/CD environments can't use this. Every developer must have handbook at the same path

## Decision

**Context7 Pro** as the sole cross-repo context mechanism. The Brite Handbook is indexed as a private library on Context7 and queried on-demand via MCP tools (`resolve-library-id` → `query-docs`).

- **Library ID:** `/brite-nites/handbook`
- **Indexed:** 659 files, 2,789 snippets
- **Cost:** $10/seat/month + $25/1M tokens for indexing
- **Setup per developer:** `npx ctx7 setup --claude`

**Rationale:** Context7 scored highest of all prototypes evaluated (7.3/10 weighted, 3.0/5 avg relevance). It found named reference clients, specific tech decisions, and integration patterns that the other approaches missed. Zero local resource usage, automatic freshness, and one-command setup make it the simplest to adopt across the team.

The handbook is documentation-structured content (GitBook markdown) — exactly what Context7 is optimized for. The `resolve-library-id` → `query-docs` flow maps naturally to "what does the company know about X" queries.

**Why not QMD?** QMD scored 2.1/5 avg relevance (vs Context7's 3.0/5). Requires 2.1GB model download, per-developer indexing, and has semantic drift on ~40% of queries. Data locality is its only advantage, which is not a concern for us.

**Why not Copy-on-Setup?** Adds ~25-30K tokens of permanent context cost per session, requires manual curation of "essential" files, and fails on any query not in the curated set. Context7's on-demand search handles all query types without permanent context cost.

**Why not submodule or symlink?** Submodules have well-known UX problems. Symlinks don't work with Claude Code's @import resolution.

## Consequences

### Positive

- Agents in every project repo gain on-demand handbook search via MCP
- Best search quality of all prototypes (3.0/5 avg relevance)
- Zero local resource usage — no models, no GPU, no per-developer indexing
- One-command setup per developer: `npx ctx7 setup --claude`
- Automatic freshness — dashboard refresh re-indexes changed content
- Unblocks BRI-1941 (implementation) and BRI-2013 (platform decision)

### Negative

- $10/seat/month for Context7 Pro plan
- Company handbook data is hosted on Context7's servers (mitigated: Enterprise plan offers self-hosted option)
- Returns tangential results when content truly doesn't exist (no "no results" signal)
- Adds ~2-4s latency per handbook query (API round-trip)

## Reversibility

1. Remove the handbook from Context7 dashboard
2. Remove `context7` MCP server from `~/.claude.json`
3. Remove `~/.claude/rules/context7.md` and `~/.claude/skills/context7-mcp/`
4. Cancel Pro plan

**Migrate to upstream feature:** When Claude Code ships org-wide CLAUDE.md (#14467) or URL imports (#29072), evaluate whether the upstream mechanism replaces or complements Context7. Search is orthogonal to static imports — both may coexist.

## Migration Path

1. Ensure all developers have Context7 Pro access (org admin adds seats)
2. Each developer runs: `npx ctx7 setup --claude --api-key <key>`
3. Handbook already indexed at `/brite-nites/handbook` (2,789 snippets)
4. Add to onboarding checklist in handbook: "Run `npx ctx7 setup --claude` for company knowledge search"
5. Additional private repos can be added to Context7 as needed (same dashboard flow)
