# BC-6960 — Implement 12 named flow-architecture agents

**Issue:** [BC-6960](https://linear.app/brite-nites/issue/BC-6960/flow-architecture-implement-12-named-agents-parent)
**Milestone:** Flow-Driven Architecture Plugin v1.0
**Branch:** `holden/bc-6960-flow-architecture-12-agents`
**Worktree:** `.claude/worktrees/bc-6960/`

## Source-of-truth references

- **Q21 lock** — `~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md:452-485` — 12-agent spec (per-agent: model, tools, invokers, return shape).
- **Q21 amendment 1** — same file `:1236-1273` — adds scope-axis fields (`mode` + `expansions[]` / `reductions[]` / `rigor_focus[]` / `rationale[]`) to **7 of 12** four-mode reviewer agents.
- **Q32 tool-scope audit** — same file `:344` — only `fidelity-reviewer` + `inventory-author` need network/MCP tools.
- **Q30.2 file-location** — same file `:283` — `plugins/flow-architecture/agents/<name>.md`, exactly 12 files.
- **Four-mode contract** — `plugins/flow-architecture/skills/_shared/four-mode-framework.md` — interface signature, mode-specific field rules, founder-mode framing (cribbed verbatim from gstack).
- **Plugin CLAUDE.md agent dispatch MATRIX** — `plugins/flow-architecture/CLAUDE.md` § Surface map → Agent dispatch MATRIX — invoker + return-shape + L-scope per agent.
- **Frontmatter precedents** — `plugins/cadence/agents/{narrative-writer,project-audit,project-enricher,housekeeping-preflight}.md` (4-field frontmatter: `name` + `description` + `model` + `tools`).

## Acceptance criteria (from issue)

- `ls plugins/flow-architecture/agents/*.md | wc -l` → `12`
- `grep -lE "^mode: " plugins/flow-architecture/agents/*.md | wc -l` → `7`
- 5 separate `grep -L "^mode: "` checks confirming the 5 excluded agents lack the field: `inventory-author`, `codebase-inferrer`, `story-doc-author`, `journey-doc-author`, `fidelity-reviewer`
- `grep -lE "^model: haiku" plugins/flow-architecture/agents/*.md` matches at minimum `fidelity-reviewer` + `codebase-inferrer`
- `grep -q "result.*PASS\|FAIL" plugins/flow-architecture/agents/fidelity-reviewer.md` (distinct return shape)

## Out of scope

- Sub-skill internals (P1)
- Orchestrator dispatch wiring (consumers reference these agents but the orchestrators don't change here)
- v1.1 design-consult agent (Q45)

## Per-agent spec table

| # | Agent | Model | Frontmatter `mode:` field? | Tools | Return shape | Primary L-scope invokers |
|---|---|---|---|---|---|---|
| 1 | `inventory-author` | sonnet | NO (excluded) | Read, Glob, Grep, WebSearch, WebFetch | inventory rows (markdown blob, BriteBase schema) | `flow-inventory-codebase-scan` P4 + `flow-inventory-interview` P4 + `flow-inventory-add` |
| 2 | `codebase-inferrer` | haiku | NO (excluded) | Read, Glob, Grep, Bash | structured JSON `{flow_id: {found, files, tests, sandbox_url, status_inferred}}` | `flow-inventory-codebase-scan` P3 + `flow-doc-author` (Q15.7) + `flow-sandbox-scaffold` (Q17.2) |
| 3 | `story-doc-author` | sonnet | NO (excluded) | Read, Glob, Grep | filled story-doc markdown (Q27 conformant) | `flow-doc-author` (Q15) |
| 4 | `journey-doc-author` | sonnet | NO (excluded) | Read, Glob, Grep | filled journey-doc markdown (Q26 conformant) | `flow-journey-author` (Q16) |
| 5 | `fidelity-reviewer` | haiku | NO (excluded) | Read, Glob, Grep, mcp__plugin_workflows_linear-server__get_issue | `{result: PASS\|FAIL, findings: [string≤5], cosmetic_ignored: [string]}` <150 words | `flow-linear-scaffold` Q13.3 (per-issue) + `flow-doc-author` (per-doc) + `flow-journey-author` (per-doc) |
| 6 | `plan-story-reviewer` | sonnet | YES | Read, Glob, Grep | four-mode (`mode` + `headline` + mode-specific fields + `adjustments[]`) | `flow-linear-scaffold` (L3) + `/flow:plan-story` (L4) |
| 7 | `plan-eng-reviewer` | sonnet | YES | Read, Glob, Grep | four-mode | `/flow:office-hours` (L1) + `flow-linear-scaffold` (L3) + `/flow:plan-eng` (L4) |
| 8 | `plan-design-reviewer` | sonnet | YES | Read, Glob, Grep | four-mode | `/flow:office-hours` (L1) + inventory (L2) + `flow-linear-scaffold` (L3) + `/flow:plan-design` (L4) |
| 9 | `plan-qa-reviewer` | sonnet | YES | Read, Glob, Grep | four-mode | `flow-linear-scaffold` (L3) + `/flow:plan-qa` (L4) |
| 10 | `plan-docs-reviewer` | sonnet | YES | Read, Glob, Grep | four-mode | `flow-linear-scaffold` (L3) + `/flow:plan-docs` (L4) |
| 11 | `plan-ceo-reviewer` | sonnet | YES | Read, Glob, Grep | four-mode + `strategic_concerns[]` | `/flow:office-hours` (L1) + inventory interview (L2) |
| 12 | `plan-devex-reviewer` | sonnet | YES | Read, Glob, Grep | four-mode + `ergonomic_concerns[]` | `/flow:office-hours` (L1 only) |

**Total**: 12 files. **`mode:` field**: 7 (rows 6-12). **`model: haiku`**: 2 (rows 2 + 5).

## Execution tasks

### T1 — Worktree setup + clean baseline

- `EnterWorktree` with `name: bc-6960` (per user request to use a worktree).
- Verify clean state: `ls plugins/flow-architecture/agents/ 2>/dev/null` → no directory yet.
- Verify `four-mode-framework.md` is readable from the worktree.

**Verify**: worktree at `.claude/worktrees/bc-6960/`; current branch ends with `bc-6960`; baseline `validate.sh` passes (or known-failing items unrelated to agent dir).

### T2 — Mkdir + author 5 excluded-from-amendment agents (no `mode:` field)

Create `plugins/flow-architecture/agents/` and author 5 files in parallel:

1. `inventory-author.md` — sonnet; `tools: Read, Glob, Grep, WebSearch, WebFetch`. Returns BriteBase-schema inventory markdown (consumer = `flow-inventory-codebase-scan` P4 / `flow-inventory-interview` P4 / `flow-inventory-add`). Output shape: markdown blob with one row per discovered/proposed flow per master-flow-inventory format.
2. `codebase-inferrer.md` — haiku; `tools: Read, Glob, Grep, Bash`. Returns structured JSON. Bash usage limited (per Q21:392 "limited"). Drives Q11 P3 code-evidence collection + Q15.7 / Q17.2.
3. `story-doc-author.md` — sonnet; `tools: Read, Glob, Grep`. Returns filled markdown conforming to Q27 job-story template (validated by `verify-docs.sh`).
4. `journey-doc-author.md` — sonnet; `tools: Read, Glob, Grep`. Returns filled markdown conforming to Q26 8-section journey template.
5. `fidelity-reviewer.md` — haiku; `tools: Read, Glob, Grep, mcp__plugin_workflows_linear-server__get_issue`. Returns `{result: PASS|FAIL, findings: [string≤5], cosmetic_ignored: [string]}` <150 words. Cross-cutting consumer.

Each file MUST have:
- 4-field frontmatter (`name` / `description` / `model` / `tools`) — cadence convention verified against `narrative-writer.md`.
- Body sections: Inputs / Steps or Protocol / Output (single block) / Conventions.
- NO `mode:` field anywhere — AC #2 grep counts only the 7 reviewers; AC #3 explicitly enumerates these 5 must lack it.

**Verify**:
- `ls plugins/flow-architecture/agents/*.md | wc -l` → `5`
- `grep -L "^mode: " plugins/flow-architecture/agents/{inventory-author,codebase-inferrer,story-doc-author,journey-doc-author,fidelity-reviewer}.md | wc -l` → `5`
- `grep -lE "^model: haiku" plugins/flow-architecture/agents/*.md | sort` → `codebase-inferrer.md`, `fidelity-reviewer.md`
- `grep -q "result.*PASS\|FAIL" plugins/flow-architecture/agents/fidelity-reviewer.md`

### T3 — Author 5 plan-X-reviewer agents (Story / Eng / Design / QA / Docs)

5 sibling files sharing the same scaffold (four-mode contract) with discipline-specific perspective framing in description + system prompt:

1. `plan-story-reviewer.md` — perspective = `story`. Scopes: L3 (per sub-flow during scaffold) + L4 (`/flow:plan-story`).
2. `plan-eng-reviewer.md` — perspective = `eng`. Scopes: L1 + L3 + L4.
3. `plan-design-reviewer.md` — perspective = `design`. Scopes: L1 + L2 + L3 + L4.
4. `plan-qa-reviewer.md` — perspective = `qa`. Scopes: L3 + L4.
5. `plan-docs-reviewer.md` — perspective = `docs`. Scopes: L3 + L4.

Each MUST have frontmatter:
```yaml
---
name: plan-<discipline>-reviewer
description: <discipline-specific one-liner ending with scope-axis taxonomy reference>
model: sonnet
mode: four-mode
tools: Read, Glob, Grep
---
```

Body sections (shared template):
- **Contract** — pointer to `skills/_shared/four-mode-framework.md` (do not duplicate the spec).
- **Perspective** — what this discipline prioritizes (1 paragraph).
- **Inputs** — `subject`, `perspective`, `scope_level`, `context` per the four-mode interface signature.
- **Mode classification guidance** — the four-mode taxonomy applied to this perspective (one bullet per mode).
- **Output** — JSON object matching the `review_output` shape; `headline` <50 words soft-warn.
- **Conventions** — never invent numbers; founder-mode framing applies; embed questions in `rationale[]` not as blocking CLARIFY.

**Verify**:
- `ls plugins/flow-architecture/agents/plan-{story,eng,design,qa,docs}-reviewer.md | wc -l` → `5`
- `grep -lE "^mode: " plugins/flow-architecture/agents/*.md | wc -l` → `5` (so far; T4 brings to 7)
- All 5 cite `skills/_shared/four-mode-framework.md` by relative path

### T4 — Author 2 perspective-specific reviewer agents (CEO + DevEx)

1. `plan-ceo-reviewer.md` — sonnet; `mode: four-mode`. Founder-mode framing (cribbed verbatim from gstack via `four-mode-framework.md` §"Founder-mode framing"). Adds `strategic_concerns: string[]` to return alongside scope-axis fields. Scopes: L1 + L2.
2. `plan-devex-reviewer.md` — sonnet; `mode: four-mode`. Adds `ergonomic_concerns: string[]`. **Description includes early "is this developer-facing?" check** — non-developer-facing projects (Brand Hub, BriteBase, internal tools) → returns minimal "not applicable for this project type" headline + skips deep analysis. Scopes: L1 only.

**Verify**:
- `ls plugins/flow-architecture/agents/plan-{ceo,devex}-reviewer.md | wc -l` → `2`
- `grep -lE "^mode: " plugins/flow-architecture/agents/*.md | wc -l` → `7` ← matches AC #2
- `grep -q "founder-mode\|10-star product" plugins/flow-architecture/agents/plan-ceo-reviewer.md` (verbatim phrase preserved per Q48 sub-decision 6)
- `grep -q "developer-facing\|not applicable for this project type" plugins/flow-architecture/agents/plan-devex-reviewer.md`

### T5 — Run full AC verification + plugin/marketplace version bump

Run all issue ACs sequentially:

```bash
ls plugins/flow-architecture/agents/*.md | wc -l    # → 12
grep -lE "^mode: " plugins/flow-architecture/agents/*.md | wc -l    # → 7
for a in inventory-author codebase-inferrer story-doc-author journey-doc-author fidelity-reviewer; do
  grep -L "^mode: " plugins/flow-architecture/agents/${a}.md
done    # → 5 lines, one per excluded agent
grep -lE "^model: haiku" plugins/flow-architecture/agents/*.md    # contains fidelity-reviewer + codebase-inferrer
grep -q "result.*PASS\|FAIL" plugins/flow-architecture/agents/fidelity-reviewer.md && echo OK
```

Bump versions per BC-6000 same-commit rule (29th consecutive bump for this plugin):
- `plugins/flow-architecture/.claude-plugin/plugin.json`: `0.2.8` → `0.2.9`
- `.claude-plugin/marketplace.json` flow-architecture entry: `0.2.8` → `0.2.9`

Run `./scripts/validate.sh` at root to confirm no plugin-config drift, no hook-model violations, no skill frontmatter drift.

**Verify**: all 5 ACs pass; `validate.sh` exit 0.

### T6 — Commit + ready for /workflows:review

Stage:
- `plugins/flow-architecture/agents/*.md` (12 new files)
- `plugins/flow-architecture/.claude-plugin/plugin.json` (version bump)
- `.claude-plugin/marketplace.json` (version bump)
- `docs/plans/BC-6960-plan.md` (this file)

Single commit per the FDA precedent established by BC-6957 / BC-6962 / BC-6963 / BC-6965 (all single-commit fold-ins).

Commit subject: `BC-6960: implement 12 named flow-architecture agents`.

## Dependencies

- BC-6955 (`skills/_shared/four-mode-framework.md`) — required for T3/T4 reviewers; **already shipped** (verified at `plugins/flow-architecture/skills/_shared/four-mode-framework.md` 108 lines).

## Risks

- **R1 (low):** Reviewer agents reference consumer skills (`flow-doc-author`, `/flow:plan-story`, etc.) that don't exist yet. Mitigation: descriptions name them by future-state; no runtime dispatch from these agents to those consumers.
- **R2 (low):** `headline <50 words` is a soft-warn discipline (not a hard validation). Documented in agent body; enforcement is consumer-side per Q41 sub-decision 6.
- **R3 (low):** ACs use `grep` patterns — frontmatter MUST be exactly `mode: four-mode` (not `mode:four-mode`, not `Mode:`). T3/T4 templates lock the exact form.

## Notes for executor

- All agents are **filesystem-only except** `fidelity-reviewer` (Linear MCP `get_issue`) and `inventory-author` (WebSearch/WebFetch). Per Q32 tool-scoping audit at memory:344.
- Cadence convention: 4-field frontmatter (`name` / `description` / `model` / `tools`). The 7 four-mode reviewers add a 5th field: `mode: four-mode`. This is the AC #2 grep target.
- Do not duplicate the four-mode interface signature inside agent bodies — every reviewer points back to `skills/_shared/four-mode-framework.md` per Q48 sub-decision 7 ("framework is a contract, not code; consumers parse, agents implement").
- Cross-link the `## Q21 lock + amendment 1` references inside each agent body (one line at top): `_Spec: Q21 (memory:452) + Q21 amendment 1 (memory:1236)._` — preserves audit trail per schema-discipline amendment pattern.
