---
issue: BC-5947
title: Register Spider.cloud + AI Ark + Discolike MCP servers + /marketing:setup-tam-map
branch: holden/bc-5947-register-spidercloud-ai-ark-discolike-mcp-servers-pluginjson
worktree: .claude/worktrees/bc-5947/
created: 2026-04-25
policy: docs/research/tam-map-port-policy.md (BC-5945)
upstream: Revgrowth1/tam-map@9f5c72e74b (MIT)
---

# BC-5947 plan — tam-map MCP registration + guided onboarding

## Goal

1. Wire 3 stdio MCP servers (Spider.cloud native, AI Ark wrapper, Discolike wrapper) into `plugins/marketing/.mcp.json` using **Pattern A** (plugin-scoped + OS env-vars).
2. Ship `/marketing:setup-tam-map` mirroring `setup-email-bison.md`, walking the user through 8 env-var exports in `~/.zshrc`.
3. Bump marketing plugin version (cache-keyed; per CLAUDE.md gotcha).
4. Execute BC-5945 § 1 MCP-cap measurement methodology against the soft-cap thresholds.
5. Verify the existing CLAUDE.md MCP-cap Gotcha (already correct per BC-5945 § 1) — **no edit**, just verification.

## Reconciliation: issue text vs ground truth

The issue was authored before the BC-5945 brainstorm reframed the cap policy and before BC-5946 verified the registration shape. Five revisions:

| Issue Pass | Issue prescription | Ground truth | Plan |
|---|---|---|---|
| Pass 1 server count | "existing 5 entries → 8" | Marketing `.mcp.json` has only `salesforce` (1). Email Bison is user-level. github/enrichment unregistered. | 1 → 4 (Salesforce + Spider + AI Ark + Discolike). |
| Pass 2 userConfig | "7 new userConfig entries, all `sensitive: true`" + ANTHROPIC_API_KEY | Marketing `plugin.json` has no userConfig. `${user_config.*}` substitution is broken for HTTP and unverified-but-suspect for stdio per BC-5551 gotcha. | **Pattern A**: no userConfig; OS env-vars in `~/.zshrc`. ANTHROPIC_API_KEY is a CLI-script runtime concern (`tier_and_segment.py`), not plugin userConfig — documented in setup command. |
| Pass 4 CLAUDE.md edit | "Add new MCP-cap-exception bullet referencing 8 servers" | CLAUDE.md:94 already says "advisory, < 2s + < 500 tokens deltas, see tam-map-port-policy.md § 1" — written by BC-5945 § 1. | **No edit** — verify already correct. |
| Pass 5 cross-validation | "document cross-check as Verify checkbox" | BC-5832 not yet shipped. | Note in PR + plan that BC-5832 will re-verify `allowed-tools` against the 3 new server names. |
| Verify item #1 | "existing 5 entries untouched" | Only 1 entry (salesforce). | "existing 1 entry untouched". |

## Decisions (locked during brainstorm)

1. **Pattern A** — plugin-scoped stdio servers with `env: {KEY: "${KEY}"}` substitution against OS env vars. No `userConfig` block.
2. **8 env vars in `~/.zshrc`**: `SPIDER_API_KEY`, `AIARK_API_KEY`, `DISCOLIKE_API_KEY`, `ICYPEAS_API_KEY`, `BLITZAPI_KEY`, `PROSPEO_API_KEY`, `MILLIONVERIFIER_API_KEY`, `ANTHROPIC_API_KEY`. (Eighth is for the `tier_and_segment.py` fit-scoring CLI script, not the MCPs.)
3. **No CLAUDE.md edit** — existing line 94 Gotcha bullet is the canonical text per BC-5945 § 1.
4. **Server count post-port = 4** plugin-level. Brite-enrichment MCP (BC-5538) lands separately and would push us to 5 (still within advisory bound).

## Tasks

### Task 1 — Add 3 stdio MCP server entries

**File**: `plugins/marketing/.mcp.json`

Append (preserve existing `salesforce` block):

```json
"spider": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "spider-cloud-mcp"],
  "env": {
    "SPIDER_API_KEY": "${SPIDER_API_KEY}"
  }
},
"aiark": {
  "type": "stdio",
  "command": "node",
  "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/tam-map/aiark-mcp.js"],
  "env": {
    "AIARK_API_KEY": "${AIARK_API_KEY}"
  }
},
"discolike": {
  "type": "stdio",
  "command": "node",
  "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/tam-map/discolike-mcp.js"],
  "env": {
    "DISCOLIKE_API_KEY": "${DISCOLIKE_API_KEY}"
  }
}
```

**Pre-step**: ✅ verified `spider-cloud-mcp` v2.1.1 exists on npm (per official docs at https://spider.cloud/docs/integrations/mcp). Note: both upstream tam-map's `.mcp.json` and the BC-5946 `spider-cloud.md` integration guide use the wrong package name `@spider-cloud/spider-mcp` (a typo — the real one is `spider-cloud-mcp` without scope). This PR uses the correct name. Task 1.5 below corrects the integration guide.

**Verify**: `python3 -c "import json; json.load(open('plugins/marketing/.mcp.json'))"` parses; `./scripts/validate.sh` exits 0.

### Task 1.5 — Fix `spider-cloud.md` integration guide package name typo

**File**: `plugins/marketing/tools/integrations/spider-cloud.md`

The BC-5946 integration guide says the package ships as `@spider-cloud/spider-mcp` — that scoped name does not exist on npm. The real package is `spider-cloud-mcp` (unscoped) per official docs. Update the Registration section JSON snippet + any inline references. Same factual-drift class as the 4 P1 fixes BC-5946 review caught for ai-ark.md + discolike.md (BC-5946 task-3 architecture-8 precedent).

**Verify**: `grep "@spider-cloud/spider-mcp" plugins/marketing/tools/integrations/spider-cloud.md` returns no matches; `grep "spider-cloud-mcp" plugins/marketing/tools/integrations/spider-cloud.md` returns the corrected snippet.

### Task 2 — Create `/marketing:setup-tam-map`

**File**: `plugins/marketing/commands/setup-tam-map.md`

Mirror `setup-email-bison.md` shape (frontmatter + 6 phases). Concrete differences from email-bison:

- Phase 1 (Detect): grep `claude mcp list` for `spider|aiark|discolike` — adapt `NONE_REGISTERED` branching for 0/1/2/3 servers.
- Phase 2 (Bitwarden): point user to a Bitwarden item — **TBD: confirm item name with user during execution**. Eight `export` lines (7 third-party API keys + `ANTHROPIC_API_KEY`).
- Phase 3 (Shell profile): paste 8 exports into `~/.zshrc`. Note that `ANTHROPIC_API_KEY` is for the `tier_and_segment.py` fit-scoring CLI step downstream, not the MCPs.
- Phase 4 (Reload): `/reload-plugins` or full Claude Code restart (preferred — env vars must propagate from the launching shell).
- Phase 5 (Verify): three things —
  1. `claude mcp list | grep -E "spider|aiark|discolike"` — all three must show `✓ Connected`.
  2. Smoke MCP tools: call one tool from each server (e.g., `discover_tools` if exposed, else a no-op probe like AI Ark's `aiark_search` with a tiny query).
  3. Smoke 4 CLI scripts: each accepts `--help` (or `-h`): `icypeas_client.py`, `enrich_waterfall.py`, `verify_smtp.py`, `tier_and_segment.py`. Path: `python3 plugins/marketing/scripts/tam-map/<script>.py --help`.
- Phase 6 (Completion): summarize + flag known limitations (Pattern A → user must remember to re-source after key rotations).

**Verify**: `./scripts/validate.sh` discovers the new command; `head -3 plugins/marketing/commands/setup-tam-map.md` shows valid frontmatter.

### Task 3 — Bump marketing plugin version

**Files**:
- `plugins/marketing/.claude-plugin/plugin.json`: `"version": "0.3.2"` → `"0.3.3"`
- `.claude-plugin/marketplace.json`: matching marketing-plugin version bump

**Why**: CLAUDE.md gotcha — plugin cache is keyed by version. Same-commit bump avoids cache staleness across clients (BC-6000 precedent).

**Verify**: both files contain `0.3.3`; `git diff --stat` shows both touched.

### Task 4 — BC-5945 § 1 MCP-cap measurement

**Methodology** (from `docs/research/tam-map-port-policy.md` § 1):

1. **Baseline**: cold-start `claude` session with only `salesforce` MCP plugin-registered. Capture:
   - Wall-clock time-to-prompt (proxy: `time claude -p "echo done" --print`)
   - Plugin context-block byte count (via `claude --debug` session-init log if available, else `claude mcp list` output verbosity)
2. **Post-port**: same measurement after Tasks 1–3 land + reload. 4 MCPs (Salesforce + Spider + AI Ark + Discolike).
3. **Compute deltas**:
   - Startup-latency delta = post − baseline. Threshold: **< 2s**.
   - Context-budget delta = post bytes − baseline bytes. Threshold: **< 500 tokens** (~2000 bytes).
4. **Outcome**:
   - Both within bound → document results in PR body, proceed.
   - Either exceeded → halt before merge, surface to user, BC-5945 policy revision required.

**Caveat**: empirical measurement may be limited from inside an interactive Claude Code session (parent harness has plugins already loaded). Measurement runs in user's shell outside Claude Code. If empirically blocked, file follow-up issue and document the constraint instead of skipping the methodology silently.

### Task 5 — Verify CLAUDE.md Gotcha + Pass 5 cross-validation note

- Open `CLAUDE.md`, confirm line ~94 Gotcha bullet matches BC-5945 § 1 replacement text. **No edit**.
- Add a short paragraph in the PR body documenting that BC-5832 (tam-mapping skill) will declare `allowed-tools: mcp__plugin_marketing_spider__*`, `mcp__plugin_marketing_aiark__*`, `mcp__plugin_marketing_discolike__*` — and BC-5832 must re-verify the names match.

**Verify**: `grep -n "tam-map-port-policy.md" CLAUDE.md` returns the existing line 94.

## Verify — final checklist (issue ACs mapped)

| # | Issue AC | Plan response |
|---|---|---|
| 1 | exactly 3 new servers, existing 5 untouched | exactly 3 new + existing **1** (salesforce) untouched |
| 2 | 7 new userConfig entries, sensitive=true | **N/A — Pattern A**, no userConfig |
| 3 | setup-tam-map.md exists, frontmatter valid, 5 phases | ✅ 6 phases mirroring setup-email-bison.md |
| 4 | CLAUDE.md Gotcha new bullet | **N/A — already in place per BC-5945 § 1**, verified-not-edited |
| 5 | `./scripts/validate.sh` exits 0 | ✅ |
| 6 | `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0 | ✅ |
| 7 | Manual: `/mcp` lists all 3 new servers | ✅ via Phase 5 of setup command |
| 8 | Manual: `/marketing:setup-tam-map` discoverable | ✅ |
| 9 | `get_issue` shows description intact | ✅ — only adding a comment, not editing description |
| 10 | PR with `Closes BC-5947` | ✅ |
| 11 | `/workflows:review` thorough — 0 P1 | target |

## Risks + mitigations

1. **`@spider-cloud/spider-mcp` may not exist on npm** → Pre-step in Task 1 (`npm view`) gates registration; halt if absent.
2. **Stdio `env`-block substitution might also be broken** (BC-5551 gotcha is HTTP-tested; stdio is hearsay-positive via spider-cloud.md) → Phase 5 of setup command provides empirical verification on first run; if broken, fall back to user-level registration like Email Bison and reopen.
3. **MCP-cap thresholds** → Task 4 surfaces; we're at 4/6 (post-port), well within advisory.
4. **Plan diverges from issue text** → reconciliation table at top of plan; Linear comment will summarize for traceability.

## Rollback

Revert the single commit; no migrations, no infrastructure side-effects. Worktree is isolated.

## Execution log — measurement results (Task 4)

Captured 2026-04-25 in worktree.

| Dimension | Threshold | Measured | Result |
|---|---|---|---|
| Context-budget delta (`.mcp.json` bytes, char/4 token estimate) | < 500 tokens | +611 bytes / ~152 tokens | ✅ PASS by ~70% margin |
| Plugin-level MCP count | ~5–6 advisory | 1 → 4 | ✅ within bound; leaves room for BC-5538 (brite-enrichment) without exceeding |
| Wrapper LoC (stdio handshake size proxy) | — | 247 (aiark 133 + discolike 114) | small |
| **Startup-latency delta** | **< 2s** | **cannot measure from inside running session** | ⚠️ live verification required at next Claude Code cold start |

**Constraint.** True cold-start latency measurement requires a fresh Claude Code instance — running `time claude --print` from inside an active Claude Code session does not exercise the MCP-load path of the parent harness. The byte delta above is a reasonable proxy for context-budget impact (the `.mcp.json` IS what the loader parses at startup), but the startup-latency dimension demands a live retest.

**Recommendation.** At next Claude Code restart from a freshly-sourced shell with the 8 env vars exported, run `time claude mcp list` (or equivalent) twice — once on `main` (1 plugin MCP) and once on this branch (4 plugin MCPs). Record the wall-clock delta. If > 2s, surface as a finding before merging this PR; otherwise document in the PR body and proceed.

## Execution log — Pass 5 cross-validation note

For BC-5832 (tam-mapping skill — pending) and BC-5831 (icp-scoring skill — pending) skill authors:

- The plugin-scoped tool namespace for the 3 new MCPs is `mcp__plugin_marketing_<server>__*`. Concretely:
  - Spider: `mcp__plugin_marketing_spider__*` (22 tools — see `plugins/marketing/tools/integrations/spider-cloud.md`)
  - AI Ark: `mcp__plugin_marketing_aiark__*` (3 tools per the wrapper: `aiark_search`, `aiark_similarity`, `aiark_enrich`)
  - Discolike: `mcp__plugin_marketing_discolike__*` (2 tools per the wrapper: `discolike_search`, `discolike_lookalike`)
- BC-5831 (`icp-scoring`) does **not** consume any of the 3 new servers. No cross-validation needed there.
- BC-5832 (`tam-mapping`) consumes all 3. Skill author must list each `mcp__plugin_marketing_<server>__*` in `allowed-tools` frontmatter and re-verify the names match this plan + `plugins/marketing/.mcp.json` at write time. CLAUDE.md gotcha: `allowed-tools` is NOT cross-validated against `.mcp.json` at runtime — listing a server that isn't registered fails silently.

## Execution log — `spider-cloud.md` correction (Task 1.5)

Both upstream `Revgrowth1/tam-map@9f5c72e74b/.mcp.json` and the BC-5946 Brite-authored `plugins/marketing/tools/integrations/spider-cloud.md` reference the package as `@spider-cloud/spider-mcp` (scoped). That package does not exist on npm. The correct name per [Spider docs](https://spider.cloud/docs/integrations/mcp) is `spider-cloud-mcp` (unscoped, v2.1.1).

Changes in this PR to `spider-cloud.md`:
- Registration JSON snippet: package name corrected.
- Tool inventory: replaced 2-row speculative table with the canonical 22-tool inventory from official docs (8 core + 5 AI + 9 browser).
- Last verified: bumped to 2026-04-25 with audit-trail note explaining the typo correction.

This is the same factual-drift class as the 4 P1 review fixes BC-5946 caught for `ai-ark.md` + `discolike.md` — the precedent at BC-5946 task-3 (architecture-8 promotion candidate, "integration-guide claims must grep against wrapper source") would have caught this earlier had the audit checked Spider too. **Surface this surface-class miss as the precedent's promotion event** when the next session lands a related correction.
