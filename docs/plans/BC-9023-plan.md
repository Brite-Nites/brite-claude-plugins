# BC-9023 — flow-architecture P0: agents fail to register as dispatchable subagent types

## Root cause (confirmed pre-plan)

**flow-architecture@brite-claude-plugins was never installed via `claude plugin install` (or `/plugin install`).** The plugin existed in the marketplace registry (`.claude-plugin/marketplace.json` at v0.2.24) and in source under `plugins/flow-architecture/`, but was absent from `~/.claude/plugins/installed_plugins.json` and `~/.claude/plugins/cache/brite-claude-plugins/` — so Claude Code never enumerated its commands, skills, or agents.

**Verification trail (2026-05-13, session-start for BC-9023):**

1. `claude plugin list` before fix → 6 plugins, no flow-architecture. (cadence, claude-md-management, marketing, revops, vercel, workflows.)
2. `ls ~/.claude/plugins/cache/brite-claude-plugins/` before fix → 4 directories: cadence, marketing, revops, workflows. No flow-architecture.
3. `~/.claude/plugins/installed_plugins.json` before fix → 6 entries; no `flow-architecture@brite-claude-plugins` key.
4. `claude plugin install flow-architecture@brite-claude-plugins` → `Successfully installed plugin: flow-architecture@brite-claude-plugins (scope: user)`.
5. `claude plugin list` after fix → 7 plugins, flow-architecture@brite-claude-plugins v0.2.24 enabled.
6. `ls ~/.claude/plugins/cache/brite-claude-plugins/flow-architecture/0.2.24/agents/` after fix → 12 agent files present.

The "6 plugins · 39 skills · 28 agents" count BC-6998 iter 1's dogfood operator quoted from `/reload-plugins` was the count **without** flow-architecture. They misread that as "plugin loads but agents broken." The plugin was never loading.

## Why PR #314 fix attempts were red herrings (but defensible cleanup)

1. **Strip `mode: four-mode` from 7 reviewer agents** — defensible cleanup (the field was outside Claude Code's documented frontmatter allowlist) but did not address the root cause (plugin wasn't installed; loader never saw the field).
2. **Remove `agents/.gitkeep`** — defensible cleanup (placeholder no longer needed with 12 real `.md` files) but did not address the root cause.

Both stay merged. Both are correct hygiene independent of BC-9023's root cause.

## Acceptance criteria

1. Findings doc `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` corrected — replace the "Narrowed hypothesis (high-confidence)" assertion (which named `mode: four-mode` as the cause) with the confirmed root cause + verification trail.
2. Memory file `memory/project_bc_9023_fda_agent_registration.md` updated — mark BC-9023 resolved, document the install-discipline gotcha.
3. Project CLAUDE.md adds a Gotcha row in the Gotchas section: "Plugin in `.claude-plugin/marketplace.json` is not auto-installed — `claude plugin install <name>@<marketplace>` must run explicitly. Symptom: `claude plugin list` is the source of truth for what loads, not the marketplace registry."
4. `scripts/validate.sh` extended with a new section that cross-checks every plugin listed in `.claude-plugin/marketplace.json` against `claude plugin list` output and warns when a registered plugin isn't installed locally. Surfaces as `WARN` (not `FAIL`) because validate.sh is meant to run on fresh checkouts where no plugins are installed yet.
5. P1, P2, P3 sibling findings from BC-6998 iter 1 each get their own BC-issue (they are independent of BC-9023's root cause; the install fix doesn't address them). Filed as separate Linear issues with `flow-architecture` label and brief one-line disposition recorded as comments on BC-9023.
6. BC-9023 Linear issue updated with resolution comment + flipped to `In Review` (Status will auto-flip to `Done` on PR merge via `Closes BC-9023`).

## Tasks

### Task 1 — Correct findings doc

**File:** `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md`

**Changes:**

1. The P0 row in the `## Bugs surfaced` table — the long cell ending with the "Narrowed hypothesis (high-confidence)" claim. Replace that final paragraph (everything from "Narrowed hypothesis" through "similar to CLAUDE.md's documented plugin.json strict-schema gotcha — 'Any unrecognized field causes silent hard failure with no error'.") with:

   > **Resolved 2026-05-13 (BC-9023):** Root cause was **flow-architecture@brite-claude-plugins never installed via `claude plugin install`**. `installed_plugins.json` + `~/.claude/plugins/cache/brite-claude-plugins/` both omitted flow-architecture before the install command ran; the 6-plugin / 28-agent counts iter 1 saw were the totals WITHOUT flow-architecture. The four fix attempts in PR #314 (strip `mode: four-mode`, remove `agents/.gitkeep`) were red-herrings but defensible hygiene. Iter 2 unblocks the moment the operator runs `claude plugin install flow-architecture@brite-claude-plugins` (or the slash-command equivalent) — no source-code change required for agent registration.

2. The "Iter-2 fix sequence" numbered list (1-5) — replace with:

   > **Iter-2 fix sequence:**
   >
   > 1. Run `claude plugin install flow-architecture@brite-claude-plugins` (one-time, scope: user).
   > 2. `/reload-plugins` → confirm `claude plugin list` shows flow-architecture@brite-claude-plugins enabled at v0.2.24, and that agent count grows by 12 to reflect flow-architecture's contributions.
   > 3. Re-invoke `/flow:retrofit-project` against Brand Hub. Phase 1 resumes from the breadcrumb at `current_phase: 2` (intact on disk); Phase 2 office-hours lifts the captured 6-section intent draft from this doc's § "Captured but unwritten Phase 2 intent draft" → save into `breadcrumb.office_hours_state.section_answers` before resume so the orchestrator skips re-prompting.

3. The "Iteration 1 outcome summary" paragraph — append a closing sentence:

   > **Iter 1 outcome corrected (2026-05-13):** the surfaced "blocker" was an install gap, not a plugin bug. PR #314's two fix-attempts ship as defensible cleanup. The actual install + iter-2 dogfood are tracked under BC-9023 + BC-6998 respectively.

**Verification:**

```bash
grep -c "Resolved 2026-05-13 (BC-9023)" plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md  # → 1
grep -c "Narrowed hypothesis" plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md  # → 0
```

### Task 2 — Update memory file

**File:** `memory/project_bc_9023_fda_agent_registration.md`

Rewrite to lead with the resolved root cause (install-discipline) + verification trail. Keep the historical hypothesis trail compressed to one paragraph for posterity. Update the `description` frontmatter field. Mark cross-reference to BC-6998 as "BC-6998 iter 2 ready after install."

**Verification:**

```bash
grep -c "Resolved 2026-05-13" memory/project_bc_9023_fda_agent_registration.md  # → ≥1
grep -c "claude plugin install" memory/project_bc_9023_fda_agent_registration.md  # → ≥1
```

### Task 3 — CLAUDE.md gotcha row

**File:** `CLAUDE.md`

Add a Gotcha bullet immediately before the existing "MCP server soft cap" bullet (sequence-relevant: install discipline is the most-upstream gotcha — most loader-related issues collapse to it):

> - **`.claude-plugin/marketplace.json` registers a plugin; it does not install it.** A plugin can be in the marketplace registry, on disk under `plugins/<name>/`, and pass `scripts/validate.sh` while never appearing in `claude plugin list` — that's "registered but uninstalled." Symptom: commands, skills, AND agents are all absent from the dispatchable list (not just one of the three). Source of truth: `claude plugin list` output. Fix: `claude plugin install <name>@<marketplace>` (or slash-command equivalent) once per scope (user or project). Costly precedent: BC-9023 — BC-6998 iter 1 burned a full session diagnosing a "plugin loader bug" that was actually an uninstalled plugin; the 6-plugin / 28-agent counts /reload-plugins kept printing were the totals WITHOUT flow-architecture, which iter 1's operator read as evidence the plugin was loading-but-broken.

**Verification:**

```bash
grep -c "registers a plugin; it does not install it" CLAUDE.md  # → 1
./scripts/check-guardrails.sh --claude-md CLAUDE.md  # no new errors
```

### Task 4 — validate.sh install-status check

**File:** `scripts/validate.sh`

Add a new section that, for each plugin listed in `.claude-plugin/marketplace.json`, checks whether `claude plugin list` reports it as installed at the matching version. Emit `WARN` (not `FAIL`) for any plugin in the registry but not installed locally — surfaces install-gap without breaking CI on fresh checkouts.

Pseudocode shape (final form to be written in `bash` consistent with the existing helpers):

```bash
section "N. Plugin install-status (cross-check with claude CLI)"

if ! command -v claude &>/dev/null; then
  warn "claude CLI not found — install-status check skipped"
else
  # Capture once
  CLAUDE_PLUGIN_LIST="$(claude plugin list 2>/dev/null || true)"
  # For each name in marketplace.json
  python3 -c '<extract names + versions>' | while IFS=$'\t' read -r pname pver; do
    if echo "$CLAUDE_PLUGIN_LIST" | grep -q "$pname@"; then
      pass "$pname installed"
    else
      warn "$pname (v$pver) is in marketplace.json but NOT in 'claude plugin list' — run 'claude plugin install $pname@brite-claude-plugins'"
    fi
  done
fi
```

**Verification:**

```bash
./scripts/validate.sh 2>&1 | grep "Plugin install-status"  # section appears
./scripts/validate.sh 2>&1 | grep -E "(WARN|PASS).*flow-architecture"  # check fires for flow-architecture
```

### Task 5 — File sibling findings P1, P2, P3

For each of the 3 sibling findings (documented in `brand-hub-dogfood-findings.md` § "Bugs surfaced"):

- P1: list_issues project filter — Linear MCP `list_issues` `project:` param hits known gotcha; orchestrator pre-preflight at `commands/retrofit-project.md:218-222` needs the documented `team + query` workaround inlined.
- P2: security hook blocks python-heredoc-piped-to-helper — orchestrator at `retrofit-project.md:253-269` uses a pattern the workflows-side security hook rejects.
- P3: Q42 free-text interview vs AskUserQuestion multi-choice mismatch — `commands/office-hours.md:145`.

Create one Linear issue per finding via `mcp__plugin_workflows_linear-server__save_issue`. Each gets:

- Title prefixed with "flow-architecture —"
- Project: Brite Skill Packs
- Milestone: Flow-Driven Architecture Plugin v1.0
- Label: `flow-architecture`
- Body lifted from the sibling-findings paragraph in BC-9023's body (already structured + actionable)
- Priority: P1 → High, P2 → Medium, P3 → Medium

After save, post a comment on BC-9023 with the 3 new issue IDs + one-line disposition.

**Verification:**

```bash
# After creation:
mcp__plugin_workflows_linear-server__list_issues --label flow-architecture --created-by me  # ≥3 new entries
```

### Task 6 — Update Linear BC-9023

After tasks 1-5 are committed + PR opened:

1. Comment on BC-9023 with:
   - Root cause sentence.
   - Verification trail (the 6-step sequence above).
   - Link to PR.
   - Three new sibling-finding issue IDs.
2. Set BC-9023 state to `In Review`. The `Closes BC-9023` in the PR description will auto-flip to `Done` on merge per [[gotcha_github_auto_close_linear_state]].

## Out of scope

- BC-6998 iter 2 retrofit run — that's BC-6998's job. This PR makes it possible by getting flow-architecture installed.
- Refactoring the orchestrator's `list_issues`-style preflight (P1 sibling finding) — gets its own BC-issue.
- workflows security-hook allowlist update (P2 sibling finding) — gets its own BC-issue.
- Q42 interview-shape amendment (P3 sibling finding) — gets its own BC-issue.

## Cross-reference

- BC-9023 (this issue).
- BC-6998 (blocked by this; resumes from breadcrumb after install).
- BC-6999 (v1.0 release tag; transitively unblocked).
- PR #314 (BC-6998 iter 1 dogfood — squash commit `e5e65e7`); two PR-#314 fix attempts (`mode:` strip + `.gitkeep` removal) stay merged as defensible cleanup independent of this root cause.
