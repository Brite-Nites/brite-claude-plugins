# BC-5789 Plan — Scaffold `plugins/revops/` via Jaganpro subtree + filter

**Issue:** [BC-5789](https://linear.app/brite-nites/issue/BC-5789)
**Milestone:** RevOps Plugin
**Priority:** Medium (gateway — unblocks 14 sibling issues)
**Branch:** `bc-5789-revops-scaffold` (worktree)

## Context

Create the `plugins/revops/` plugin via `git subtree` import of `Jaganpro/sf-skills` (MIT, CTA-authored, 36 skills + 7 agents + LSP loops + scoring rubrics). Subtree is flat — `plugins/revops/` IS the subtree. Filter to 14 retained skill directories (13 customizable + sf-diagram-mermaid deferred), delete 22 skipped skills + all 7 consulting agents. Author plugin metadata + plugin-scoped MCP server registration + upstream attribution. Preserve MIT LICENSE.

This is the single longest issue in the RevOps milestone. Plan for multiple in-execute check-in gates because steps touch git history (subtree add) and bulk-delete directories.

## Locked decisions (no re-litigation)

All architectural decisions are locked in:
- **ADR-007** (`docs/decisions/007-revops-plugin-design.md`) — subtree-vs-fork, naming, MCP scope, skill filter, augment-not-replace
- **Master plan** (`docs/plans/revops-plugin-master-plan.md` §3 + §7 Issue 1.2) — exact filter list, plugin.json shape, .mcp.json args

**ADR-007 §3.6 override (memorialize):** master plan §3.6 said "rename `sf-*` → `brite-*`," but ADR-007 §3.6 (locked 2026-04-19, supersedes plan) says **keep upstream skill names**. BC-5789 itself has no renames in scope (deferred to Phase 3 per-skill issues), so no execution change here — but Phase 3 issue titles like "Customize sf-deploy → brite-deploy" (BC-5793) contradict the locked ADR. **Out of BC-5789 scope; surface to user for decision when Phase 3 starts.**

## Out of scope

- Customizing any skill content (Phase 3 per-skill issues)
- Renaming any skill directory (deferred per ADR-007 §3.7)
- Building any `/revops:*` commands (Phase 2 — BC-5790/5791/5792)
- SessionStart hooks (Phase 4 — BC-5806)
- Publishing or releasing v0.1.0 externally (internal only)

---

## Tasks (atomic — TaskCreate as we go)

### Task 1 — Explore

**Goal:** Verify upstream state matches the master plan §3.5 filter list (36 skills + 7 agents). Pin the current `Jaganpro/sf-skills` main commit SHA for UPSTREAM.md.

**Steps:**
1. `gh api repos/Jaganpro/sf-skills/branches/main --jq '.commit.sha'` — pin SHA
2. `gh api repos/Jaganpro/sf-skills/contents/skills --jq '[.[] | .name] | sort'` — confirm exact 36 skill directory names
3. `gh api repos/Jaganpro/sf-skills/contents/agents --jq '[.[] | .name] | sort'` — confirm 7 agents
4. `gh api repos/Jaganpro/sf-skills/contents/ --jq '[.[] | {name, type}]'` — list top-level entries (LICENSE, README, install.sh, pyproject.toml, etc.)

**Verification:** Skill directory names from step 2 must include all 13 KEEP names + sf-diagram-mermaid + the 22 SKIP names exactly. If any name differs, STOP and check in.

### Task 2 — Plan (check-in gate 1)

**Goal:** Confirm upstream state with user; surface any discrepancy from the locked filter list before any history-touching action.

**Output:** Inline summary to user containing:
- Pinned SHA (4-byte short hash + full SHA)
- Confirmed/discrepancy table for KEEP/DEFER/DELETE per master plan §3.5
- Top-level files we'll inherit (LICENSE, README, pyproject.toml, install.sh, etc.) — for awareness, not action

**Gate:** ONE user question — "Upstream state confirmed. OK to proceed to subtree add?"

### Task 3 — Execute Step 1: `git subtree add` (gate 2)

**Goal:** Import the Jaganpro tree into `plugins/revops/`.

**Steps:**
1. Verify clean working tree: `git status --short` (should show only the new plan file)
2. Stage + commit the plan file first so subtree add starts from a clean tree
3. `git subtree add --prefix=plugins/revops https://github.com/Jaganpro/sf-skills main --squash`
4. `ls plugins/revops/` — confirm contents
5. `./scripts/validate.sh` — note: may fail because `.claude-plugin/plugin.json` doesn't exist yet (fixed in Task 5)

**Gate (check-in gate 2):** Paste `ls plugins/revops/` output. ONE question: "Subtree imported cleanly. OK to proceed to bulk deletion?"

### Task 4 — Execute Step 2: bulk-delete 22 skills + 7 agents (gate 3)

**Goal:** Filter to the 14 retained skill directories; remove all 7 consulting agents.

**Steps:**
1. `rm -rf plugins/revops/skills/sf-ai-*` (5 skills)
2. `rm -rf plugins/revops/skills/sf-datacloud*` (7 skills)
3. `rm -rf plugins/revops/skills/sf-industry-*` (7 skills)
4. `rm -rf plugins/revops/skills/sf-vlocity-*` (1 skill)
5. `rm -rf plugins/revops/skills/sf-flex-estimator` (1 skill)
6. `rm -rf plugins/revops/skills/sf-diagram-nanobananapro` (1 skill)
7. `rm -rf plugins/revops/agents` (7 agents)

**Verification:** `ls plugins/revops/skills/ | wc -l` → exactly 14. Then `ls plugins/revops/skills/` lists exactly: sf-apex, sf-flow, sf-lwc, sf-soql, sf-testing, sf-debug, sf-metadata, sf-data, sf-docs, sf-permissions, sf-connected-apps, sf-integration, sf-deploy, sf-diagram-mermaid.

**Gate (check-in gate 3):** Paste skills list. ONE question: "Filter complete. OK to author config files?"

### Task 5 — Execute Step 3: author plugin.json

**File:** `plugins/revops/.claude-plugin/plugin.json`

**Content** (locked, ADR-007 §3.4 + master plan §7 Issue 1.2):

```json
{
  "name": "revops",
  "description": "Revenue operations plugin — Salesforce development + CRM data skills with Brite customizations on top of Jaganpro/sf-skills (MIT)",
  "author": {"name": "Brite"},
  "version": "0.1.0",
  "homepage": "https://github.com/Brite-Nites/britenites-claude-plugins",
  "repository": "https://github.com/Brite-Nites/britenites-claude-plugins",
  "license": "MIT",
  "keywords": ["claude-code", "plugin", "salesforce", "sfdx", "revops", "brite"],
  "skills": "./skills/",
  "commands": "./commands/"
}
```

**Verification:** `python3 -c "import json; print(json.load(open('plugins/revops/.claude-plugin/plugin.json')))"` loads. All keys are in the strict allowlist (name, description, author, version, homepage, repository, license, keywords, commands, skills — all present; no agents/hooks/mcpServers-as-string).

**Note:** No `commands/` directory exists yet (Phase 2 issues build it). The frontmatter `"commands": "./commands/"` is forward-declared. If the auto-discovery requires the directory to exist, create empty `plugins/revops/commands/` with a `.gitkeep`.

### Task 6 — Execute Step 4: author .mcp.json

**File:** `plugins/revops/.mcp.json`

**Content** (locked, ADR-007 §3.4):

```json
{
  "mcpServers": {
    "salesforce": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@salesforce/mcp@0.30.5",
        "--orgs", "DEFAULT_TARGET_ORG",
        "--toolsets", "data,metadata,testing",
        "--no-telemetry"
      ]
    }
  }
}
```

### Task 7 — Execute Step 5: author UPSTREAM.md + preserve LICENSE

**File:** `plugins/revops/UPSTREAM.md`

**Content:** Source repo URL, pinned SHA from Task 1, MIT attribution, sync model ("fork-by-default; `git subtree pull` available"), update command.

**LICENSE:** Verify `plugins/revops/LICENSE` arrived from subtree (Jaganpro's MIT). If missing, copy from upstream.

### Task 8 — Execute Step 6: register the plugin

**Files:**
- `.claude-plugin/marketplace.json` — append revops entry (mirror cadence entry shape)
- `CLAUDE.md` — add `revops/` to Repository Structure tree

### Task 9 — Validate

**Commands:**
- `./scripts/validate.sh` — exit 0
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — pass

If either fails, fix root cause (don't bypass).

### Task 10 — Verify (objective table)

Run all 15 tests from BC-5789's verify table. Capture for PR body.

| # | Command / Action | Pass criteria |
|---|---|---|
| T1 | `ls plugins/revops/` | `.claude-plugin/`, `skills/`, `LICENSE`, `UPSTREAM.md`, plus inherited (README, pyproject.toml, etc.) |
| T2 | `ls plugins/revops/skills/ \| wc -l` | 14 |
| T3 | `ls plugins/revops/skills/` | sf-apex, sf-flow, sf-lwc, sf-soql, sf-testing, sf-debug, sf-metadata, sf-data, sf-docs, sf-permissions, sf-connected-apps, sf-integration, sf-deploy, sf-diagram-mermaid |
| T4 | `ls plugins/revops/agents` | error (no such directory) |
| T5 | `python3 -c "import json; json.load(open('plugins/revops/.claude-plugin/plugin.json'))"` | loads, allowlist only |
| T6 | `./scripts/validate.sh` | exit 0 |
| T7 | `./scripts/check-guardrails.sh --claude-md CLAUDE.md` | pass |
| T8 | `grep "revops" .claude-plugin/marketplace.json` | match |
| T9 | `grep "revops" CLAUDE.md` | match |
| T10 | `claude mcp list` (fresh session, separately verified by user) | `plugin:revops:salesforce` ✓ Connected |
| T11 | brite-salesforce session | revops loads, no errors |
| T12 | brite-gtm session | revops loads, no banner noise |
| T13 | `git log --oneline -- plugins/revops \| head -3` | squashed subtree commit visible |
| T14 | `grep -E "[a-f0-9]{7,}" plugins/revops/UPSTREAM.md` | SHA recorded |
| T15 | `cat plugins/revops/LICENSE` | MIT, Copyright Jaganpro retained |

T10/T11/T12 require a fresh Claude Code session — note in PR body and ask user to verify post-merge.

### Task 11 — Commit + push (gate 4)

Single clean commit: `BC-5789: scaffold plugins/revops/ via Jaganpro subtree + filter`.

If subtree add created its own commit, the result is 2 commits (subtree merge + this). Do NOT squash — subtree's commit needs to stay distinct so future `subtree pull` works.

**Gate:** Final user check-in before push: paste verify table results, ONE question: "Verify clean. OK to push + open PR?"

### Task 12 — PR + Linear update

- `gh pr create` with verify table in body, link ADR-007, link master plan §7 Issue 1.2
- Move BC-5789 to "In Review" with comment containing AC evidence

---

## Risk register

| Risk | Mitigation |
|---|---|
| Subtree add creates merge commit on `main` (we're on a worktree branch, so OK) | Confirm working dir is on `bc-5789-revops-scaffold` worktree branch, not main |
| Jaganpro tree contains skill names different from master plan §3.5 | Task 1 verifies exact names; Task 2 gate flags discrepancy before subtree add |
| `commands/` field in plugin.json points to non-existent dir | Create empty `plugins/revops/commands/` with `.gitkeep` if validate.sh complains |
| Bulk `rm -rf` accidentally matches more than intended | Use specific glob patterns from Task 4; verify count matches 14 after each step |
| `validate.sh` enforces a CLAUDE.md per plugin and revops doesn't have one | If validate fails on this, add minimal `plugins/revops/CLAUDE.md` (~20 lines) with subtree-origin note |
| Security hook flags `git subtree add` as destructive | If it does, surface to user; subtree add is non-destructive (only adds files) |
| `./scripts/check-guardrails.sh` flags inherited Jaganpro markdown | Per ADR-007 we treat the subtree as our code; if guardrails fail on inherited files, exclude `plugins/revops/skills/` from guardrails or fix the offending content (decide at run time) |

---

## Worktree

Use `EnterWorktree` with name `bc-5789-revops-scaffold` after plan approval.
