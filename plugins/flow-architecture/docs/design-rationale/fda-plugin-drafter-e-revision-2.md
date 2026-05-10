# FDA Plugin v1.0 — Phase 3 Linear scoping — Revision 2 drafts

Drafter E's revision 2 of the 21 issue drafts after orchestrator dispatched a corrective memo addressing ~50 SEV-1/SEV-2/SEV-3 findings from Round 1 review. This file holds the drafts for verification-agent review against the corrective memo.

---

## P1 — flow-architecture — implement 9 sub-skills (parent)

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md lines 68 / 80 / 94 / 108 / 126 / 146 / 179 / 208 / 224 (Q11/Q13-Q20). Handbook: CDR-023, ops-standards FDA page, parent-issue template. Architecture overview: docs/plans/fda-plugin-architecture-overview.md §3a + §3d.

### Context

FDA plugin v1.0 needs 9 internal sub-skills (`disable-model-invocation: true` per Q7) that orchestrators dispatch. Each is bounded, single-purpose, and has its own locked Q internals. Children of this parent are created lazily as work begins on each sub-skill (Q3 hybrid granularity).

### Goal

Stand up the 9-sub-skill layer that Q37/Q47 orchestrators dispatch and `/flow:audit` enforces.

### What

**Convention anchor (CC4 from corrective memo):** per Q30.2 (memory:281), `_shared/` lives at `skills/_shared/` (NESTED inside skills/), NOT at plugin top-level. Sub-skills implemented at `plugins/flow-architecture/skills/<skill-name>/SKILL.md`:

1. flow-inventory-interview (Q19, memory:208)
2. flow-inventory-codebase-scan (Q11, memory:68)
3. flow-inventory-add (Q20, memory:224)
4. flow-legacy-cross-reference (Q14, memory:94) — retrofit-only
5. flow-linear-scaffold (Q13, memory:80) — heaviest mutator (2+7N writes/domain)
6. flow-doc-author (Q15, memory:108)
7. flow-journey-author (Q16, memory:126)
8. flow-sandbox-scaffold (Q17, memory:146)
9. flow-regen-index (Q18, memory:179) — deterministic, no LLM dispatch

Each child issue body cribs the relevant Q-lock sub-decisions verbatim. flow-preflight is tracked separately as Standalone #4 (foundational, not in this 9-count).

### Acceptance criteria

- `find plugins/flow-architecture/skills -mindepth 1 -maxdepth 1 -type d -not -name '_shared' | wc -l` returns 10 (9 sub-skills + flow-preflight)
- `test -d plugins/flow-architecture/skills/_shared` succeeds (NOT `plugins/flow-architecture/_shared`)
- 9 separate `test -f` checks for each `plugins/flow-architecture/skills/<name>/SKILL.md` file
- `grep -L "disable-model-invocation: true" plugins/flow-architecture/skills/*/SKILL.md` returns empty
- `mcp__plugin_workflows_linear-server__list_issues parentId=<P1-issue-id>` returns count == 9 (children created in Linear under this parent)

### Out of scope

Orchestrator wiring (Standalones #5-8); plan-X commands (P3); v1.1 `/flow:design-consult` per Q45 deferral (parking lot #9).

### Dependencies

Standalone #2 (`skills/_shared/` utility kit) and #3 (scripts/) — foundation utilities the sub-skills consume.

### Re-address before starting

Re-read the per-skill Q-lock entry in memory before implementing each child. Parking-lot-#39 discipline: re-verify any cited workflows-plugin source via `gh api` at child-implementation time, not via Q-lock inheritance.

---

## P2 — flow-architecture — implement 12 named agents (parent)

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 452 (Q21) + line 1236 (Q21 amendment 1). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3d agent layer.

### Context

Q21 expanded the agent roster from 9 → 12 at lock time (added plan-ceo-reviewer + plan-devex-reviewer for L1/L2 Q54 coverage; promoted fidelity-reviewer; split doc-author → story-doc-author + journey-doc-author; dropped index-regenerator per Q18 deterministic). Q21 amendment 1 (memory:1236) adds scope-axis fields (`mode` required + `expansions[]` / `reductions[]` / `rigor_focus[]` / `rationale[]` mode-specific) to 7 of 12 four-mode reviewer agents per Q48 lock.

### Goal

Implement the 12 named agents that orchestrators + plan-X commands dispatch.

### What

Author 12 agent definitions at `plugins/flow-architecture/agents/<agent-name>.md` per Q30.2 (memory:283). Per-agent reference:

**7 INCLUDED in Q21 amendment 1 (scope-axis fields):**
- plan-story-reviewer, plan-eng-reviewer, plan-design-reviewer, plan-qa-reviewer, plan-docs-reviewer (5 plan-X-reviewers, sonnet)
- plan-ceo-reviewer (sonnet)
- plan-devex-reviewer (sonnet)

**5 EXCLUDED from amendment (memory:1242):**
- inventory-author (sonnet) — distinct return shape
- codebase-inferrer (haiku) — distinct return shape
- story-doc-author (sonnet)
- journey-doc-author (sonnet; opus optional v1.1)
- fidelity-reviewer (haiku) — `{result: PASS|FAIL, findings, cosmetic_ignored}` shape

Tools scoping per Q32 audit (memory:344): only fidelity-reviewer + inventory-author need network/MCP; the 7 plan-X-reviewers + codebase-inferrer + 2 doc-authors are filesystem-only.

### Acceptance criteria

- `ls plugins/flow-architecture/agents/*.md | wc -l` returns 12
- `grep -lE "^mode: " plugins/flow-architecture/agents/*.md | wc -l` returns 7 (the 7 four-mode reviewers; case-correct field — does NOT match `model:`)
- 5 separate `grep -L "^mode: "` checks confirming the 5 excluded agents lack the field: inventory-author, codebase-inferrer, story-doc-author, journey-doc-author, fidelity-reviewer
- `grep -lE "^model: haiku" plugins/flow-architecture/agents/*.md` matches at minimum fidelity-reviewer + codebase-inferrer
- `grep -q "result.*PASS\|FAIL" plugins/flow-architecture/agents/fidelity-reviewer.md` (distinct return shape)

### Out of scope

Sub-skill internals (P1); orchestrator dispatch wiring; v1.1 design-consult agent per Q45.

### Dependencies

Standalone #2 (`skills/_shared/four-mode-framework.md` consumed by 7 reviewers per Q48 sub-decision 5).

### Re-address before starting

Re-read Q21 (memory:452) AND Q21 amendment 1 (memory:1236) before drafting each agent. Q48's verdict-axis-vs-scope-axis catch (2026-05-07) was caught via `gh api` verification of gstack source — apply the same rigor here.

---

## P3 — flow-architecture — implement 5 /flow:plan-X commands (parent)

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1063 (Q43) + line 1133 (Q24 amendment 1). Handbook: CDR-023, ops-standards FDA page, discipline-child templates (story.md / engineering.md / design.md / qa.md / docs.md). Architecture overview: §3c + §3g.

### Context

Q43 locks the L4 plan-suite — five distinct slash entries that consume Q46 linear-writeback to fill Q24 EPEV "Plan" sub-sections in discipline child bodies. Heavy consumer of Q21's plan-X-reviewer agents at L4 single-perspective scope (per Q54 meta-Q at memory:413-414). Q24 amendment 1 (memory:1133) is a Q43 prerequisite — Q24 templates pre-populate empty Q46 markers so Q46's first-write doesn't append at body end. Phase 4 cannot proceed without templates pre-populating markers.

### What

Five command files at `plugins/flow-architecture/commands/plan-<discipline>.md`:
1. /flow:plan-story → plan-story-reviewer
2. /flow:plan-eng → plan-eng-reviewer
3. /flow:plan-design → plan-design-reviewer
4. /flow:plan-qa → plan-qa-reviewer
5. /flow:plan-docs → plan-docs-reviewer

Per Q43 sub-decisions:
- **Sub-decision 1:** positional `<discipline-child-issue-id>` + `--refresh` flag
- **Sub-decision 3:** 4-tier issue resolution priority cascade (positional → breadcrumb `domains[N].current_sub_flow` → git branch BC-XXXX → AskUserQuestion fallback)
- **Sub-decision 4:** L4 = SINGLE discipline only per meta-Q lock; NOT autoplan (NOT all-5)
- **Sub-decision 6 double-layer safety:** (a) Q43 caller-side reads body via `get_issue` and errors-if-populated when `Plan not yet generated` substring (memory:1106) is absent AND `--refresh` not passed; (b) `--refresh` bypasses Q43 layer → Q46 clobber-with-warning fires
- **Sub-decision 7:** Q43 → Q51 dependency direction (Q43 lands first; Q51 cribs invocation contract)

**Marker convention (CC5 — kebab-case lowercase per Q46 sub-decision 2 / memory:993-994):** `<!-- FDA-WRITEBACK-plan-<discipline>-section-START -->` / `<!-- FDA-WRITEBACK-plan-<discipline>-section-END -->`. Type values lowercase: `plan-story-section`, `plan-eng-section`, `plan-design-section`, `plan-qa-section`, `plan-docs-section`.

### Acceptance criteria

- `ls plugins/flow-architecture/commands/plan-*.md | wc -l` returns 5
- `grep -c "FDA-WRITEBACK-plan-" plugins/flow-architecture/commands/plan-*.md | awk -F: '{s+=$2} END{print s}'` returns >= 10 (one START + END pair per file; lowercase)
- 5 separate greps confirm each file references its corresponding plan-X-reviewer agent
- `grep -q -- "--refresh" plugins/flow-architecture/commands/plan-*.md` succeeds in each file
- `grep -q "Plan not yet generated" plugins/flow-architecture/commands/plan-*.md` succeeds in each file (Q43 sub-decision 6 caller-side detection substring)

### Out of scope

Q45 /flow:design-consult (v1.1 deferral, parking lot #9); Linear surfacing for audit-concerns (parking lot per Q38 sub-decision 4).

### Dependencies

P1 (sub-skill outputs), P2 (plan-X-reviewer agents), Standalone #2 (`skills/_shared/linear-writeback-pattern.md`), Standalone #9 (/flow:audit); Q24 amendment 1 templates landed (PR #514 merged 2026-05-10).

### Re-address before starting

Re-read Q43 sub-decisions (memory:1063) AND Q46 marker convention (memory:993-994) before drafting each command. Verify FDA-WRITEBACK-* marker syntax matches Q14.2 hyphenated form (memory:80) and Q46 kebab-lowercase type values.

---

## 1 — flow-architecture — scaffold plugin skeleton + cross-cutting docs

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 274 (Q30) + line 344 (Q32) + line 62 (Q8). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3i state substrates.

### Context

First-commit work for the plugin slot in `Brite-Nites/brite-claude-plugins/plugins/flow-architecture/`. Q30 locks the directory layout and manifest; Q32 locks the dependency surface (workflows Linear MCP only, bash 3.2+ / python3 3.6+ / git 2.x+ / gh soft). Q8 defines v1 MVP scope (full surface, no v1.0/v1.1 split). Per Q40 release sequence, ROADMAP/README/repo-CLAUDE.md/ARCHITECTURE.md/CONTRIBUTING.md edits couple to this scaffold commit.

### Goal

Land the plugin skeleton: directory tree, `.claude-plugin/plugin.json` (v0.1.0), `.mcp.json`, README + 3 cross-cutting docs.

### What

Create directory tree per Q30.2 (memory:278-284) — note `_shared/` is NESTED inside `skills/`, NOT top-level (CC4):

```
plugins/flow-architecture/
  .claude-plugin/plugin.json   (Q30.3, memory:286)
  .mcp.json                    (Q30.4, memory:288)
  README.md                    (Q30.7, memory:294)
  LICENSE                      (MIT)
  agents/
  commands/
  scripts/
  skills/
    _shared/                   (Q30.2, memory:281 — 6 utilities)
  docs/design-rationale/       (memory archive destination at Phase 6)
```

Plus 3 cross-cutting docs at the plugin root: `ROADMAP.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`. (CLAUDE.md is Standalone #15 per Q55, not this commit.)

`plugin.json` at `.claude-plugin/plugin.json` per Q30.3: name=flow-architecture, version=0.1.0, declares workflows-plugin dependency, fields per cadence schema.

`.mcp.json` content per Q30.4: `{"mcpServers": {}}` — reuses workflows' Linear MCP per cadence precedent (BC-5810 § 4 / BC-5811 § 4.2).

Existing dormant marketplace milestones (Plugin Ecosystem Foundation, etc.) left untouched per Q8.

### Acceptance criteria

- `cat plugins/flow-architecture/.claude-plugin/plugin.json | jq -r .version` returns `0.1.0`
- `cat plugins/flow-architecture/.mcp.json` returns exactly `{"mcpServers": {}}`
- 5 separate `test -f` checks: README.md, LICENSE, ROADMAP.md, ARCHITECTURE.md, CONTRIBUTING.md
- 3 separate `test -d` checks: skills/_shared, docs/design-rationale, .claude-plugin
- `grep -q '"name": "flow-architecture"' plugins/flow-architecture/.claude-plugin/plugin.json`

### Out of scope

Plugin CLAUDE.md (Standalone #15 per Q55); sub-skill / agent / command implementation; dormant marketplace milestones.

### Dependencies

None (first commit).

### Re-address before starting

Re-read Q30 sub-decisions (memory:274-298) + Q32 dependency surface (memory:344) before scaffolding. Verify cadence directory structure via `gh api repos/Brite-Nites/brite-claude-plugins/contents/plugins/cadence` immediately before drafting (parking-lot-#39 discipline).

---

## 2 — flow-architecture — implement skills/_shared/ utility kit

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 281 (Q30.2 6-utility list) + line 986 (Q46) + line 1163 (Q48) + line 1190-1216 (Q48 interface signature) + line 122 (Q15.7 status taxonomy) + line 150 (Q17.2 mode determination) + line 286-310 (Q31 amendments 1+2). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3d foundation + §3i state substrates.

### Context

The `skills/_shared/` utility kit (CC4: nested inside `skills/`, per Q30.2 memory:281) is the FDA plugin's cross-cutting layer. Q30.2 locks **6 utilities** (corrected from 5 at lock time):

### What

Six markdown files at `plugins/flow-architecture/skills/_shared/`:

1. **app-classifier-pattern.md** — Q11/Q19 shared Phases 0/1/2/5 (app-classifier interview pattern)
2. **code-evidence-collector.md** — DRY for Q11 Phase 3 + Q15.7 + Q17.2 (parking lot #18 consolidator). Embeds:
   - Status taxonomy verbatim mappings per Q15.7 (memory:122): code-exists+tests+sandbox-URL → BUILT; code-exists-but-incomplete → IN_PROGRESS; no-code → NOT_STARTED. Cap at BUILT — no QA_SIGNED_OFF or SHIPPED promotion (those need workflow events / customer-doc filesystem signals)
   - Q17.2 EXTRACT/WRAP/STUB mode determination (memory:150)
3. **linear-writeback-pattern.md** — Q46 (memory:986). Embeds: kebab-case lowercase marker convention (`<!-- FDA-WRITEBACK-<type>-START -->` per Q46 sub-decision 2 / memory:993-994); v1 type registry verbatim enum: `ship-summary`, `retro-summary`, `plan-story-section`, `plan-eng-section`, `plan-design-section`, `plan-qa-section`, `plan-docs-section`, `audit-concerns` (registered but UNUSED v1); `linear_writeback({issue_id, type, surface, content, signature?, breadcrumb_path, warn_on_clobber?})` interface
4. **four-mode-framework.md** — Q48 (memory:1163). Embeds: gstack-verbatim taxonomy `SCOPE_EXPANSION` / `SELECTIVE_EXPANSION` / `HOLD_SCOPE` / `SCOPE_REDUCTION`; verbatim founder-mode framing ("CEO/founder-mode plan review. Rethink the problem, find the 10-star product, challenge premises, expand scope when it creates a better product."); interface signature per memory:1190-1216 — DO NOT re-derive
5. **checkpoint-pattern.md** — orchestrator breadcrumb schema cross-link to Q31.1 + Q31 amendments 1 (office_hours_state) + 2 (linear_writeback_state) at memory:286-310. Cite range; DO NOT re-derive schema
6. **artifact-gate-pattern.md** — Q7 + Q29 filesystem-artifact-existence gate contract reference

### Acceptance criteria

- `ls plugins/flow-architecture/skills/_shared/*.md | wc -l` returns 6
- 6 separate `test -f` checks for each named file
- `grep -q "SCOPE_EXPANSION" plugins/flow-architecture/skills/_shared/four-mode-framework.md` AND `grep -q "SELECTIVE_EXPANSION"` AND `grep -q "HOLD_SCOPE"` AND `grep -q "SCOPE_REDUCTION"` (4 separate greps; verbatim taxonomy)
- `grep -q "founder-mode" plugins/flow-architecture/skills/_shared/four-mode-framework.md`
- `grep -q "FDA-WRITEBACK-" plugins/flow-architecture/skills/_shared/linear-writeback-pattern.md`
- 8 separate greps for each v1 enum type in linear-writeback-pattern.md (lowercase: ship-summary, retro-summary, plan-story-section, plan-eng-section, plan-design-section, plan-qa-section, plan-docs-section, audit-concerns)
- `grep -q "BUILT" plugins/flow-architecture/skills/_shared/code-evidence-collector.md` AND `grep -q "EXTRACT\|WRAP\|STUB"`

### Out of scope

Consumer wiring (P1 / P2 / P3 / orchestrators); v1.1 audit-concerns Linear surface per Q38 sub-decision 4.

### Dependencies

Standalone #1 (skeleton).

### Re-address before starting

Re-verify gstack `plan-ceo-review/SKILL.md` via `gh api` IMMEDIATELY before drafting `four-mode-framework.md` — Q48 was locked 2026-05-07 with a verdict-axis-vs-scope-axis fabrication that the orchestrator caught. Parking-lot-#39 extension applies: re-verify at consumer-implementation time, not via inheritance.

---

## 3 — flow-architecture — implement scripts/ bash helpers

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 292 (Q30.6 4 locked script names) + line 76 (Q12.5 structured preamble contract) + line 344 (Q32 dep surface). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3d foundation + §3i state substrates.

### Context

Q30.6 (memory:292) locks 4 specific bash helper script names. Skill bash preambles invoke via `source $CLAUDE_PLUGIN_ROOT/scripts/<helper>.sh` (gstack pattern). Q32 (memory:344) locks bash 3.2+ compatibility — no associative arrays, no mapfile, no `${var,,}` lowercase, no other bash-4-only features. Python3 3.6+ handles JSON; no jq.

### Goal

Implement the 4 locked bash helper scripts that sub-skills + orchestrators invoke.

### What

Four scripts at `plugins/flow-architecture/scripts/` per Q30.6 (verbatim names from memory:292 — DO NOT re-derive):

1. **flow-detect-mode.sh** — outputs `greenfield|retrofit|incremental-add|resume` per Q12 mode classification (memory:74)
2. **flow-detect-fda-shape.sh** — outputs presence flags for FDA artifacts (intent.md / inventory / flows / journeys / breadcrumb)
3. **flow-resume-breadcrumb.sh** — reads `.flow-phase-state.json` with stale check (Q31.3); also wraps every breadcrumb write per Q31.5 atomic-rename + parse-verify
4. **flow-context-load.sh** — invokes the above 3 + emits Q12.5 structured preamble (memory:76) verbatim:
   ```
   MODE / LINEAR_PROJECT_ID / LINEAR_PROJECT_NAME / REPO_ROOT /
   INTENT_EXISTS / INVENTORY_EXISTS / FLOWS_DIR_EXISTS /
   BREADCRUMB_EXISTS / GH_AUTH / LINEAR_MCP
   ```

Downstream sub-skills depend on this preamble shape per Q12.5.

### Acceptance criteria

- 4 separate `test -f` checks: flow-detect-mode.sh, flow-detect-fda-shape.sh, flow-resume-breadcrumb.sh, flow-context-load.sh
- `ls plugins/flow-architecture/scripts/*.sh | wc -l` returns exactly 4 (no extra/fabricated scripts)
- `grep -lE "(declare -A|mapfile|\\\$\\{[a-zA-Z_]+,,)" plugins/flow-architecture/scripts/*.sh` returns empty (no bash-4-only features)
- 10 separate greps in flow-context-load.sh for each preamble field: MODE, LINEAR_PROJECT_ID, LINEAR_PROJECT_NAME, REPO_ROOT, INTENT_EXISTS, INVENTORY_EXISTS, FLOWS_DIR_EXISTS, BREADCRUMB_EXISTS, GH_AUTH, LINEAR_MCP
- 4 separate greps for mode values in flow-detect-mode.sh: greenfield, retrofit, incremental-add, resume
- All scripts have `#!/usr/bin/env bash` + `set -euo pipefail`

### Out of scope

Bash unit tests (parking lot #54, v1.1); smoke tests for command trigger resolution (parking lot #55, v1.1); helper invocations from consumers; a defensive `verify-bash-compat.sh` is NOT in Q30.6 lock — if needed, flag explicitly as extension to Q30.6, not from Q-lock content.

### Dependencies

Standalone #1 (skeleton).

### Re-address before starting

Run `bash --version` on macOS target to confirm 3.2+ posture. Spot-check a cadence script via `gh api` to confirm Brite's bash-style convention is consistent (parking-lot-#39 discipline).

---

## 4 — flow-architecture — implement flow-preflight skill

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 70 (Q12 5 responsibilities, memory:70-78 verbatim) + line 346 (Q36 7-step bootstrap) + line 310 (Q31.5 atomic-rename) + line 344 (Q32 amend at Q12). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3d foundation.

### Context

flow-preflight is the foundation sub-skill consumed by every orchestrator. Q12 (memory:70-78) locks its 5 responsibilities. Q36 (memory:346) locks per-project first-run bootstrap embedded in flow-preflight (per-org bootstrap parked, #33). User explicitly confirmed embedded-over-dedicated-skill via AskUserQuestion. Q12 amended at Q32 lock 2026-05-06 (memory:344): env-checks expanded to include explicit bash 3.2+ / python3 3.6+ / git 2.x+ version requirements.

### Goal

Implement flow-preflight with embedded first-run bootstrap.

### What

`plugins/flow-architecture/skills/flow-preflight/SKILL.md` with `disable-model-invocation: true` (Q7). Five responsibilities verbatim per Q12 (memory:70-78 — DO NOT re-derive):

1. **Environment checks (fail-closed):** Linear MCP reachable (`list_projects limit:1`), repo root detected, `docs/product/` exists or offer to bootstrap, `gh auth` soft-warn. Includes Q32 explicit version requirements (bash 3.2+ / python3 3.6+ / git 2.x+).
2. **FDA-artifact discovery (read-only):** scans `docs/product/intent.md`, `master-flow-inventory.md`, `flows/INDEX.md`, `flows/<domain>/*.md`, `journeys/<domain>.md`, `docs/plans/.flow-phase-state.json`.
3. **Mode classification — 4 modes:** `greenfield` / `retrofit` / `incremental-add` / `resume`. Edge: intent + inventory + zero-domains-with-full-FDA → `retrofit`. Stale breadcrumb (>7 days or completed) → offer discard, fall through.
4. **Linear scope confirmation + persisted `.flow/config.json`:** read if exists → skip user gate; else AskUserQuestion → write on success. v1 fields: `linear_project_id`, `linear_project_name`, `linear_team_key`, `fda_first_setup_at`, `fda_plugin_version`. Q31.5 atomic-rename pattern for write.
5. **Output structured preamble (Q12.5):** echoed into LLM context — MODE / LINEAR_PROJECT_ID / LINEAR_PROJECT_NAME / REPO_ROOT / INTENT_EXISTS / INVENTORY_EXISTS / FLOWS_DIR_EXISTS / BREADCRUMB_EXISTS / GH_AUTH / LINEAR_MCP.

Q36.3 7-step bootstrap flow embedded (memory locks user-paced steps including 3a/3b Linear `team_key` resolution split — see memory:346+ for verbatim sequence — DO NOT re-derive).

Read-only EXCEPT `.flow/config.json` write on first successful confirmation.

### Acceptance criteria

- `test -f plugins/flow-architecture/skills/flow-preflight/SKILL.md` succeeds
- `grep -q "disable-model-invocation: true" plugins/flow-architecture/skills/flow-preflight/SKILL.md`
- `grep -qE "(greenfield|retrofit|incremental-add|resume)" plugins/flow-architecture/skills/flow-preflight/SKILL.md` (note `incremental-add` with hyphen, NOT `incremental`)
- 4 separate greps for each mode: greenfield, retrofit, incremental-add, resume
- 5 separate greps for the 5 responsibilities by anchor: "Environment checks", "FDA-artifact discovery", "Mode classification", "Linear scope confirmation", "structured preamble"
- 10 separate greps for preamble fields (MODE / LINEAR_PROJECT_ID / etc.)
- `grep -q "fda_first_setup_at" plugins/flow-architecture/skills/flow-preflight/SKILL.md`
- `grep -q "atomic-rename\|atomic_rename\|tmp.*mv" plugins/flow-architecture/skills/flow-preflight/SKILL.md` (Q31.5)

### Out of scope

Per-org bootstrap (parking lot #33, v1.1); dedicated-skill bootstrap shape (Q36 rejected this path); orchestrator dispatch wiring.

### Dependencies

Standalone #3 (`scripts/flow-context-load.sh`).

### Re-address before starting

Re-read Q12 (memory:70-78) + Q36 (memory:346) + Q36 refinement audit trail (memory:370). Critical lesson: Q36 had 6 orchestrator-recall refinements that were already resolved at lock time — do not re-litigate.

---

## 5 — flow-architecture — implement /flow:start-project orchestrator

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 671 (Q37). Handbook: CDR-023, ops-standards FDA page, intent.md template. Architecture overview: §3e greenfield orchestrator phase flow.

### Context

Greenfield orchestrator runs 8 phases / 4 user-confirmation gates per Q37 lock + hybrid control flow: Phase 4 = per-domain inner loop (preserves Q13.5 atomic recovery); Phases 5+6 = globally batched (activates Q15.2 + Q16.2 parallelism). Wall ≈ 22-70 min on Brand Hub-shape projects.

### Goal

Implement /flow:start-project end-to-end greenfield orchestrator.

### What

`plugins/flow-architecture/commands/start-project.md` orchestrating 8 phases:

1. flow-preflight (Q12)
2. /flow:office-hours (Q42) — produces intent.md + L1 review
3. flow-inventory-interview (Q19) — produces master-flow-inventory.md + L2 stash
4. flow-linear-scaffold (Q13) — per-domain inner loop
5. flow-doc-author (Q15) — globally batched
6. flow-journey-author (Q16) — globally batched
7. flow-regen-index (Q18)
8. complete (writes breadcrumb)

Four gates: G1 (bootstrap), G2 (intent review), G3 (inventory review), G4 (pre-scaffold batch preview consolidating ALL domains — NOT 28 separate gates).

Q37 sub-decision 4 L-review embedding routing: L1 fires in Phase 2 (4 reviewers parallel via Q42); L2 fires in Phase 3 (per domain via state stash); L3 fires inside Phase 4 scaffold BEFORE preview gate so headlines populate parent's `## L3 review summary`.

Q37 sub-decision 6 per-phase failure handling matrix — see memory:671+ verbatim per-phase matrix; DO NOT re-derive.

Breadcrumb path per Q31.4 lock: `docs/plans/.flow-phase-state.json` (NOT `.flow/phase-state.json`).

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/start-project.md` succeeds
- 4 separate greps for each gate: G1, G2, G3, G4
- `grep -q "docs/plans/.flow-phase-state.json" plugins/flow-architecture/commands/start-project.md` (canonical breadcrumb path with leading dot in filename)
- `grep -q "per-domain inner loop" plugins/flow-architecture/commands/start-project.md` (Phase 4)
- `grep -q "globally batched" plugins/flow-architecture/commands/start-project.md` (Phases 5+6)
- 3 separate greps for L-review routing anchors: L1 review, L2 review, L3 review

### Out of scope

Retrofit orchestrator (Standalone #6); add-domain/add-sub-flow (Standalones #7/#8); v1.1 journey-refresh per parking-lot #19.

### Dependencies

P1 (the 9 sub-skills in P1 — flow-preflight is Standalone #4, NOT in P1 enumeration), Standalone #4 (flow-preflight), Standalone #10 (/flow:office-hours).

### Re-address before starting

Re-read Q37 (memory:671) + Q37 refinement audit trail (memory:687) before drafting. Confirm Q15.6/Q16.6/Q18.8 lock 0 sync gates each (Phases 5/6/7 run without additional orchestrator gates).

---

## 6 — flow-architecture — implement /flow:retrofit-project orchestrator

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 671 (Q37) + line 94 (Q14 single-marker pair) + line 106 (Q14.6 review-doc gate) + line 887 (Q42 sub-decision 1 conditional). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3f retrofit orchestrator phase flow.

### Context

Retrofit orchestrator runs 9 phases / 5 gates per Q37 lock. Differs from greenfield by adding Phase 3 (flow-legacy-cross-reference, Q14, retrofit-only) + G3 (cross-reference review per Q14.6) + using flow-inventory-codebase-scan (Q11) instead of flow-inventory-interview (Q19). Q42 office-hours is CONDITIONAL in retrofit (auto-invoked when intent.md absent per Q37 sub-decision 7), not always-on. Q9 (memory:64) policy: "in-flight work follows: finish where you are, new work in new structure" — POLICY only; no breadcrumb cutover-timestamp persistence.

### Goal

Implement /flow:retrofit-project end-to-end retrofit orchestrator. v1.0 acceptance gate target per Q8 — must run cleanly against Brand Hub.

### What

`plugins/flow-architecture/commands/retrofit-project.md` orchestrating 9 explicit phases:

1. flow-preflight (Q12)
2. /flow:office-hours (Q42) — conditional per Q42 sub-decision 1 + Q37 sub-decision 7 (only if intent.md absent)
3. flow-legacy-cross-reference (Q14)
4. flow-inventory-codebase-scan (Q11)
5. flow-linear-scaffold (Q13) — per-domain inner loop
6. flow-doc-author (Q15) — globally batched
7. flow-journey-author (Q16) — globally batched
8. flow-regen-index (Q18)
9. complete

Five gates: G1 bootstrap, G2 intent review (conditional), G3 cross-reference review per Q14.6, G4 inventory review, G5 pre-scaffold batch preview.

**Marker conventions (TWO DISTINCT FAMILIES — do not conflate):**
- **Q14 markers (memory:98):** single section type, NO `<type>` slot — `<!-- FDA-MIGRATION-START -->` / `<!-- FDA-MIGRATION-END -->`
- **Q46 markers (memory:993-994):** typed kebab-lowercase — `<!-- FDA-WRITEBACK-<type>-START -->`

These are SEPARATE marker namespaces; do not collide.

G3 mechanic (Q14.6, memory:106): skill REFUSES to execute until user bumps `last_reviewed: TBD` to ISO-8601 in `docs/plans/<retrofit>-cross-reference.md`. Unambiguous filesystem check, NOT chat-ack. Two-pass: (1) skill generates doc with proposed mapping; (2) user reviews + edits inline; (3) user re-invokes skill to execute.

Cutover semantics per Q9 are POLICY only — no `.flow-phase-state.json` cutover-timestamp field is locked.

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/retrofit-project.md` succeeds
- 5 separate greps for each gate: G1, G2, G3, G4, G5
- 9 separate phase anchors documented (1 through 9)
- `grep -q "FDA-MIGRATION-START" plugins/flow-architecture/commands/retrofit-project.md` (Q14 marker, NO `<type>` slot)
- `grep -q "FDA-MIGRATION-END" plugins/flow-architecture/commands/retrofit-project.md`
- `grep -vq "FDA-MIGRATION-<type>" plugins/flow-architecture/commands/retrofit-project.md` (no spurious `<type>` insertion)
- `grep -q "last_reviewed" plugins/flow-architecture/commands/retrofit-project.md` AND `grep -q "TBD" ...` (Q14.6 review-doc gate)
- `grep -q "conditional\|absent" plugins/flow-architecture/commands/retrofit-project.md` (Q42 conditional invocation)

### Out of scope

Greenfield orchestrator (Standalone #5); Brand Hub dogfood execution itself (Standalone #17 — cross-link).

### Dependencies

P1 (sub-skills, esp. Q11 + Q14), Standalone #4 (flow-preflight), Standalone #10 (/flow:office-hours).

### Re-address before starting

Re-read Q37 (memory:671) + Q14 (memory:94-106) before drafting. Verify Q14.2 hyphenated marker form `FDA-MIGRATION-START/END` (NO `<type>` slot, NOT `FDA-MIGRATION-<type>-START` — that would conflate with Q46's typed family).

---

## 7 — flow-architecture — implement /flow:add-domain orchestrator

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 732 (Q47) + line 758 (Q47 sub-decision 5 Q20.6 + Q13.4 gates) + lines 746-749 (Q47 sub-decision 3 4 error-redirects) + line 751 (--force-incremental-add) + line 224 (Q20). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3c command surface.

### Context

/flow:add-domain is the orchestrator-layer above Q20's flow-inventory-add for the domain-add mode. Q47 locks 6 phases / 2 gates. Heavier than /flow:add-sub-flow. Wall ~10-30 min depending on N sub-flows per Q47 sub-decision 2 (memory:741).

### What

`plugins/flow-architecture/commands/add-domain.md` orchestrating 6 phases (memory:742):

1. flow-preflight (Q12)
2. flow-inventory-add (Q20 domain-mode, Q19-mini interview)
3. flow-linear-scaffold per-domain (1 milestone + N parents + 5N children = 2+7N writes)
4. flow-doc-author per-domain (N story docs, Q15.2 internal parallelism)
5. flow-journey-author (1 journey doc, Q16)
6. flow-regen-index (Q18)

**Two gates per Q47 sub-decision 5 (memory:758) — labeled by their underlying sub-skill locks, NOT G1/G2:**
- **Q20.6** within-skill confirmation gate (inventory append review)
- **Q13.4** pre-scaffold preview gate (Linear writes review per memory:70 — fires regardless of N; no trivial-preview suppression)

These do NOT collapse — different review purposes (inventory content vs Linear scaffold preview); user can edit between them.

**Q47 sub-decision 3 mode-classifier integration (memory:745-749) — hard-require `incremental-add` mode; 4 error-redirect strings verbatim:**
- `greenfield` (no FDA artifacts) → "Project not yet initialized. Use /flow:start-project first."
- `retrofit` (FDA artifacts absent + ≥10 Linear issues) → "Project has legacy work. Use /flow:retrofit-project to retrofit FDA shape, then /flow:add-* for incremental additions."
- `resume` → "Existing orchestrator run in flight at `docs/plans/.flow-phase-state.json`. Options: (a) resume via re-invocation; (b) manually discard by deleting the breadcrumb file; (c) wait for >7-day auto-stale."
- `incremental-add` → proceed.

`--force-incremental-add` flag (memory:751) — bypasses mode check; surfaces warning + audit-log entry.

Q47 sub-decision 4 boundary (memory:756): Q47 NEVER edits inventory directly — always delegates to Q20.

Q47 sub-decision 7 failure-recovery (memory:767): breadcrumb-on-hard-reject + abandoned-status pattern. Phase 1 hard-reject (Q20.4 duplicate) → write breadcrumb at phase 1 entry → on hard-reject mark `status: abandoned` with `reason: 'duplicate detected (Q20.4)'`.

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/add-domain.md` succeeds
- `grep -q "Q20.6" plugins/flow-architecture/commands/add-domain.md` AND `grep -q "Q13.4"` (gate labels per Q47 lock; NOT G1/G2)
- `grep -q "flow-inventory-add" plugins/flow-architecture/commands/add-domain.md`
- `grep -q "flow-regen-index" plugins/flow-architecture/commands/add-domain.md`
- 4 separate greps for the error-redirect anchor strings: `Project not yet initialized`, `Project has legacy work`, `Existing orchestrator run in flight`, `incremental-add`
- `grep -q -- "--force-incremental-add" plugins/flow-architecture/commands/add-domain.md`
- `grep -q "abandoned" plugins/flow-architecture/commands/add-domain.md` (failure recovery breadcrumb status)
- `grep -q "delegates to Q20\|never edits inventory" plugins/flow-architecture/commands/add-domain.md` (boundary)

### Out of scope

Sub-flow-add orchestrator (Standalone #8); full retrofit (Standalone #6); full greenfield (Standalone #5).

### Dependencies

P1 (Q20 sub-skill primarily), Standalone #4 (flow-preflight).

### Re-address before starting

Re-read Q47 (memory:732) + Q47 refinement audit trail (memory:769) — note refinement 2 was locked specifically to fix the G1/G2-vs-Q20.6/Q13.4 gate-labeling mistake the FIRST time. Don't reproduce it.

---

## 8 — flow-architecture — implement /flow:add-sub-flow orchestrator

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 732 (Q47) + line 735 (Q47 positional-arg 3 forms) + line 758 (Q20.6 + Q13.4 gates) + line 760 (Q47 sub-decision 5.5 journey-staleness warning verbatim). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3c command surface.

### Context

/flow:add-sub-flow is the lightest orchestrator — single new sub-flow under existing domain. Q47 locks 5 phases / 2 gates. Wall ≈ 3-5 min. Skips flow-journey-author per user lock 2026-05-07 (sub-decision 5.5).

### What

`plugins/flow-architecture/commands/add-sub-flow.md` orchestrating 5 phases (memory:741):

1. flow-preflight
2. flow-inventory-add (sub-flow-mode, Q20)
3. flow-linear-scaffold per-sub-flow (1 parent + 5 children + 1 children-summary comment + milestone description refresh = 7 writes)
4. flow-doc-author (1 story doc, Q15)
5. flow-regen-index (Q18)

Skips flow-journey-author — journey-staleness warning emitted instead.

**Two gates per Q47 sub-decision 5 (memory:758) — labeled by sub-skill locks:**
- **Q20.6** within-skill confirmation
- **Q13.4** pre-scaffold preview

**Positional-arg parsing (3 forms per memory:735):**
- no positional → Q20 prompts for domain interactively + auto-suggests flow_id
- `TEAM` → pre-fills domain; Q20.2 auto-suggests flow_id
- `TEAM-09` → pre-fills both; Q20.4 hard-rejects if duplicate

**Q47 sub-decision 5.5 journey-staleness warning (memory:760-763 — emit VERBATIM at completion):**

> "Sub-flow `<DOMAIN-NN>` added. Journey doc at `docs/product/journeys/<domain>.md` may need narrative refresh — the new sub-flow is in inventory + Linear + story doc but not yet woven into the journey narrative. Run `flow-journey-author --force` when ready (will regenerate from scratch; back up hand-edits first), or wait for v1.1 selective-re-author mode (parking lot #19)."

This is THE substantive differentiator from /flow:add-domain.

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/add-sub-flow.md` succeeds
- `grep -q "Q20.6" plugins/flow-architecture/commands/add-sub-flow.md` AND `grep -q "Q13.4"` (gate labels per Q47; NOT G1/G2)
- `grep -q "flow-inventory-add" plugins/flow-architecture/commands/add-sub-flow.md`
- 5 separate greps for the verbatim journey-staleness warning sentence anchors: `Journey doc at`, `narrative refresh`, `inventory + Linear + story doc`, `flow-journey-author --force`, `parking lot #19`
- Does NOT include flow-journey-author invocation (skip per Q47): `grep -vq "invoke flow-journey-author\|dispatch flow-journey-author" plugins/flow-architecture/commands/add-sub-flow.md`
- 3 separate greps for positional forms: `no-arg` / `TEAM` / `TEAM-09` documentation anchors

### Out of scope

Domain-add (Standalone #7); selective re-author / journey-refresh (parking lot #19, v1.1); full retrofit / greenfield orchestrators.

### Dependencies

P1 (Q20 primarily), Standalone #4 (flow-preflight).

### Re-address before starting

Re-read Q47 (memory:732) + Q20 (memory:224). The journey-staleness warning text is user-locked verbatim — preserve word-for-word.

---

## 9 — flow-architecture — implement /flow:audit

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 700 (Q38) + line 702 (Q38 sub-decision 1 args) + line 706 (Q38 sub-decision 3 batching) + line 712 (Q38 sub-decision 6 exit codes) + line 714 (Q38 sub-decision 7 stale-override) + line 730 (Q38 sub-decision 4 deferred-resolution). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3h quality gate stack.

### Context

/flow:audit is the runner for Q29's 35-gate stack. Q38 fills runner gaps: three-phase execution (Phase A verify-docs.sh → Phase B deterministic filesystem gates → Phase C Linear MCP gates), stdout markdown default + `--json` flag, auto-invoked by /flow:ship + /flow:plan-{discipline} (NOT orchestrators), override via AskUserQuestion on hard-gate fail. Q38 sub-decision 4 resolved: stays strictly local in v1; audit-concerns marker reserved in Q46 enum but UNUSED in v1.

### What

`plugins/flow-architecture/commands/audit.md` invoking the three-phase pipeline.

**Q38 sub-decision 1 — full arg list (memory:702):**
- `--domain=<CODE>` (filter to one domain's gates)
- `--flow=<DOMAIN-NN>` (one flow)
- `--discipline={story|eng|design|qa|docs}` (one discipline child)
- `--gate=<id>` (re-run one gate by stable ID)
- `--json` (machine-readable for CI)
- `--no-verify-docs` (skip Phase A; debugging only)

**Q38 sub-decision 3 Linear MCP batching (memory:706):** batched `list_issues({labels: ["domain:<slug>"]})` per domain inline — ~14s on 28-domain project vs ~125s if naive per-child get_issue. Without batching, 50-flow project audit takes ~125s instead of ~14s.

**Q38 sub-decision 6 exit codes (memory:712):**
- `0` = all hard gates pass (overrides counted as pass per Q29.5)
- `1` = any unoverridden hard gate fails
- `2` = verify-docs.sh failed (Phase B+C skipped)
- `64` = invalid args (`os.EX_USAGE` convention)

**Q38 sub-decision 7 stale-override detection (memory:714):** scan breadcrumb's `overrides[]` for entries with timestamp older than 30 days OR where the underlying gate condition has changed; surface in audit Overrides section as "Stale overrides — re-evaluate" subsection.

**Q38 sub-decision 4 v1 resolution (memory:730):** stdout markdown + `--json` only; no Linear writeback. `audit-concerns` marker registered in Q46 enum but UNUSED in v1; reserved for v1.1 `--linear-surface[=parent|milestone]` flag promotion.

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/audit.md` succeeds
- 3 separate greps for each phase: `Phase A`, `Phase B`, `Phase C`
- 6 separate greps for each arg flag: `--domain`, `--flow`, `--discipline`, `--gate`, `--json`, `--no-verify-docs`
- 4 separate greps for exit codes: `exit 0`, `exit 1`, `exit 2`, `exit 64`
- `grep -q "verify-docs.sh" plugins/flow-architecture/commands/audit.md`
- `grep -q "list_issues.*domain:" plugins/flow-architecture/commands/audit.md` (batching pattern)
- `grep -q "30.day\|30-day" plugins/flow-architecture/commands/audit.md` (stale-override threshold)
- `grep -q "audit-concerns marker reserved" plugins/flow-architecture/commands/audit.md`
- `grep -q "v1.1 only\|v1.1 promotion" plugins/flow-architecture/commands/audit.md`

### Out of scope

Linear writeback for audit-concerns (v1.1, parking lot per Q38 sub-decision 4 resolution); `--linear-surface[=parent|milestone]` flag (v1.1, Q38 amendment territory); `--strict` flag (v1.1 parking lot).

### Dependencies

Standalone #2 (`skills/_shared/linear-writeback-pattern.md` registers audit-concerns marker as reserved/unused in v1).

### Re-address before starting

Re-read Q38 (memory:700) + Q38 sub-decision 4 resolution (memory:730).

---

## 10 — flow-architecture — implement /flow:office-hours

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 885 (Q42) + line 889-899 (Q42 sub-decision 1 7-state defaults tree) + line 914 (Q42 sub-decision 3 per-section validation) + line 936 (Q42 sub-decision 5 atomic-write reasoning) + line 318 (Q31 amendment 1 office_hours_state). Handbook: CDR-023, ops-standards FDA page, intent.md template (Q41). Architecture overview: §3g L1 review pattern.

### Context

/flow:office-hours produces `docs/product/intent.md` (Q41 template) + L1 multi-perspective review. Q42 hybrid input: pre-fills from CDR-013 Linear Build Brief if present; gap-fills the rest by interview. 4 L1 reviewer agents parallel (CEO + Design + Eng + DevEx per Q54). Q31 amendment 1 reserves `office_hours_state` in phase-state.json for resume.

### What

`plugins/flow-architecture/commands/office-hours.md`.

**Q42 sub-decision 1 — flags + 7-state defaults decision tree (memory:889-899 — embed verbatim or cite range; DO NOT re-derive):**

Flags: `--linear-context={auto|skip|force}` + `--refresh`.

**Defaults table (7 states):** see memory:889-899 verbatim (intent.md absent + no `--refresh` → full interview + L1; intent.md absent + `--refresh` → error; intent.md exists, L1 placeholder, no `--refresh` → full interview + L1; intent.md exists, real L1, no `--refresh` → no-op skip; intent.md exists, any L1 state, `--refresh` → skip interview + re-run 4 perspective agents; `--linear-context=force` AND Linear Brief absent/non-CDR-013-shape → error; Breadcrumb mode=resume → Q31.3 stale check fires + preflight handles resume).

**Q42 sub-decision 3 per-section validation (memory:914):** sequential AskUserQuestion, one section at a time. Per-section soft-warn pattern when input doesn't meet shape guidance; user retains final call. Final-review step after all 6 sections complete: AskUserQuestion "Approve / Edit specific section / Cancel". Edit option re-prompts that section's input with current value pre-filled.

**Q42 sub-decision 5 atomic-write reasoning (memory:936-938):** final-atomic-write only, NOT incremental. Q11/Q19 read intent.md as priority filter — if Q42 wrote incrementally, those skills would see placeholders mid-interview. Single atomic write per Q31.5 pattern (write to `<path>.tmp` → atomic mv → parse-verify) AFTER all sections complete + final-review approved + L1 review fires + L1 headlines populate.

**L1 dispatch:** 4 perspective agents (plan-ceo-reviewer, plan-design-reviewer, plan-eng-reviewer, plan-devex-reviewer) via Agent tool with `run_in_background: true`. Concerns persist to `docs/plans/l1-concerns-<ISO-8601>.md` (4 H2 sections).

**CDR-013 pre-fill mappings (memory:902-906):** Problem → Problem we're solving; Outcome → Success criteria; Scope (Out) → Out of scope; Risks → Constraints. Other Q41 sections gap-filled by interview.

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/office-hours.md` succeeds
- `grep -q "intent.md" plugins/flow-architecture/commands/office-hours.md`
- `grep -q "L1 review summary" plugins/flow-architecture/commands/office-hours.md`
- 4 separate greps for each L1 reviewer: plan-ceo-reviewer, plan-design-reviewer, plan-eng-reviewer, plan-devex-reviewer
- 2 separate greps for flags: `--linear-context`, `--refresh`
- `grep -q "final-atomic-write\|atomic.write\|tmp.*mv" plugins/flow-architecture/commands/office-hours.md` (Q42 sub-decision 5)
- `grep -q "Approve\|Edit\|Cancel" plugins/flow-architecture/commands/office-hours.md` (per-section + final-review pattern)
- `grep -qE "auto|skip|force" plugins/flow-architecture/commands/office-hours.md` (3 linear-context modes)

### Out of scope

v1.1 routing L1 concerns to Linear via Q46 writeback (parking lot per Q42 sub-decision 4); /flow:design-consult (Q45 v1.1 deferral); gstack design-consultation interview branches (Q42 sub-decision 7 NOT-transferred).

### Dependencies

P2 (4 L1 reviewer agents), Standalone #2 (`skills/_shared/four-mode-framework.md`), Standalone #4 (flow-preflight).

### Re-address before starting

Re-read Q42 (memory:885) + Q42 refinement audit trail (memory:970). Verify CDR-013 pre-fill mapping against latest CDR-013 doc via `gh api` before drafting.

---

## 11 — flow-architecture — implement /flow:retro

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1297 (Q44) + line 1300 (sub-decision 1 positional fallback) + line 1322-1340 (sub-decision 6 8 sections + 7 NOT-transferred) + line 1346-1361 (sub-decision 7 Q46 single-write call signature). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3c command surface.

### Context

Q44 locks /flow:retro as per-domain retrospective skill — scope-bounded, NOT time-windowed/commit-based like gstack's retro/SKILL.md (partial inspirational transfer only per parking-lot-#39 verification 2026-05-07; gstack source verified via `gh api`). Output: `docs/retros/<domain>-<YYYY-MM-DD>.md` (canonical filesystem) + Linear comment via Q46 retro-summary marker (kebab-lowercase per CC5).

### What

`plugins/flow-architecture/commands/retro.md`.

**Q44 sub-decision 1 positional-arg-resolution fallback (memory:1300):** /flow:retro [<DOMAIN>] — positional optional; falls through to "most-recently-completed domain" detection (Linear: milestone with newest `state.type=completed` transition) → AskUserQuestion fallback if ambiguous (multiple domains closed back-to-back).

**Q44 sub-decision 6 verbatim section structure (memory:1322-1332) — 8 sections enumerated for implementer:**

Cribbed verbatim from gstack:
- `## Summary`
- `## Trends vs Prior Retros`
- `## Focus & Highlights`
- `## What worked`
- `## Where to level up`

FDA-specific (NOT in gstack):
- `## Per-discipline highlights`
- `## Cross-references`
- `## Open questions`

**7 NOT transferred from gstack (memory:1334-1340) — do not re-introduce:** Tweetable summary, Time & Session Patterns, Shipping Velocity, Code Quality Signals + Test Health, Plan Completion mining /ship JSONL logs, Your Week / Team Breakdown.

**Q44 sub-decision 7 Q46 single-write call signature (memory:1346-1361 — exact shape, kebab-lowercase per CC5):**
```
linear_writeback({
  issue_id: <milestone_id>,
  type: 'retro-summary',
  surface: 'comment',
  content: <executive-summary + link to docs/retros/<domain>-<YYYY-MM-DD>.md>,
  signature: '_Generated by /flow:retro for <DOMAIN> milestone on <ISO-8601>_',
  breadcrumb_path: <breadcrumb_path>,
  warn_on_clobber: true
})
```

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/retro.md` succeeds
- `grep -q "docs/retros/" plugins/flow-architecture/commands/retro.md`
- `grep -q "FDA-WRITEBACK-retro-summary-" plugins/flow-architecture/commands/retro.md` (Q46 marker, lowercase kebab per CC5)
- 8 separate greps for each section header: `## Summary`, `## Trends vs Prior Retros`, `## Focus & Highlights`, `## What worked`, `## Where to level up`, `## Per-discipline highlights`, `## Cross-references`, `## Open questions`
- `grep -q "type: 'retro-summary'" plugins/flow-architecture/commands/retro.md` (lowercase Q46 type value)
- `grep -q "_Generated by /flow:retro for" plugins/flow-architecture/commands/retro.md` (signature line format)
- `grep -vq "Tweetable summary\|Shipping Velocity\|Code Quality Signals\|Your Week" plugins/flow-architecture/commands/retro.md` (NOT-transferred-from-gstack patterns absent)
- `grep -q "most-recently-completed" plugins/flow-architecture/commands/retro.md` (positional fallback)

### Out of scope

Time-windowed engineering retros (gstack-inspired, rejected per Q44 scope lock); per-org or cross-domain retros (parking lots #41 + #44, v1.1); body-surface retro (parking lot #42); team retro facilitation (parking lot #44).

### Dependencies

Standalone #2 (`skills/_shared/linear-writeback-pattern.md` — retro-summary marker).

### Re-address before starting

Re-read Q44 (memory:1297) + Q44 refinement audit trail (memory:1363). Re-verify gstack `retro/SKILL.md` via `gh api` if any new sub-decisions emerge — Q44 was inspirational-only, NOT verbatim crib for the metric machinery.

---

## 12 — flow-architecture — clone + FDA-swap /flow:session-start

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1470 (Q51) + line 1481-1491 (Q51 sub-decision 3 per-step swap table — 9-row locked table; DO NOT re-derive) + line 1452 (Q50 amendment 1) + line 1473-1475 (HTML-comment header verbatim format). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3c cloned commands.

### Context

Q51 clones /flow:session-start from workflows v3.29.4 commands/session-start.md and applies Q50 sub-decision 5's 7-axis FDA-swap framework. Q50 amendment 1 corrected step count (9 not 8) + step-swap location (Step 6 not Step 5) at Q51 lock time. Drift-detection baseline: capture workflows v3.29.4 SHA at clone time per parking lot #45.

### What

`plugins/flow-architecture/commands/session-start.md`.

**Q51 sub-decision 1 — HTML-comment header verbatim format (memory:1473-1475):**
```
<!-- Cloned from workflows v3.29.4 (commands/session-start.md) on 2026-05-07. Drift-detection per parking lot #45. -->
```

**Q51 sub-decision 2 — 9-step structure preservation (Step 0 through Step 8).** Per Q50 amendment 1: NOT 8 steps.

**Q51 sub-decision 3 — per-step FDA-swap classification.** See memory:1481-1491 for locked 9-row table — DO NOT re-derive from Q50's 7 axes. Summary anchors: Step 0 (Verify Prerequisites — Preserved + augment with flow-preflight); Step 1 (Environment Setup — Preserved + augment with intent.md + breadcrumb read); Step 2 (Company Context — Preserved verbatim); Step 3 (Query Linear — FDA-swap with `type:story|eng|design|qa|docs` + `domain:<slug>` filters per Q24 mod 3); Step 4 (Read Issue Details — FDA-swap, additionally reads parent + story doc + journey doc); Step 5 (Brainstorm — Preserved verbatim REUSED per Q50 sub-decision 3); **Step 6 (Write Plan — FDA-swap site, dispatches /flow:plan-{discipline} per Q24 mod 2 — NOT Step 5 per Q50 amendment 1)**; Step 7 (Set Up Worktree — Preserved verbatim REUSED); Step 8 (Execute — Preserved verbatim).

**Q50 sub-decision 3 DIRECT REUSE rationale:** brainstorming + writing-plans + git-worktrees skills REUSED transparently (NOT cloned). Cross-reference parking lot #46 (flow-brainstorming clone deferral) and #47 (flow-writing-plans clone deferral) in out-of-scope.

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/session-start.md` succeeds
- `grep -q "Cloned from workflows v3.29.4" plugins/flow-architecture/commands/session-start.md` AND `grep -q "Drift-detection per parking lot #45"` (header verbatim)
- `grep -c "^## Step [0-9]" plugins/flow-architecture/commands/session-start.md` returns 9 (9-step preservation per Q51 sub-decision 2 / Q50 amendment 1)
- `grep -A5 "## Step 6" plugins/flow-architecture/commands/session-start.md | grep -q "/flow:plan-"` (Step 6 = FDA-swap site for plan dispatch per Q50 amendment 1)
- `grep -A10 "## Step 5" plugins/flow-architecture/commands/session-start.md | grep -qi "brainstorm"` && `grep -A10 "## Step 5" ... | grep -q "REUSED\|preserved verbatim"` (Step 5 = Brainstorm preserved verbatim)
- 3 separate greps confirming DIRECT REUSE skills referenced: brainstorming, writing-plans, git-worktrees

### Out of scope

Workflows-plugin upstream changes after v3.29.4 (parking-lot #45); design-consult cloning (Q45 v1.1); flow-brainstorming clone (parking lot #46, v1.1); flow-writing-plans clone (parking lot #47, v1.1).

### Dependencies

P1 (relevant sub-skills referenced), Standalone #2 (`skills/_shared/`), workflows plugin dep.

### Re-address before starting

Re-verify workflows v3.29.4 commands/session-start.md via `gh api` IMMEDIATELY before cloning. Per Q50 amendment 1: do NOT trust Q50's step-count/step-swap claims — re-grep at consumer-implementation time. Drafter C self-catch (memory:1518-1522) caught Q50 errors via this discipline.

---

## 13 — flow-architecture — clone + FDA-swap /flow:review

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1524 (Q52) + line 1538-1545 (Q52 sub-decision 3 per-step classification — 9-row locked table; DO NOT re-derive) + line 1559 (Q52 sub-decision 5 NO Q46 in v1) + line 1577-1581 (Q52 → Q53 dependency) + line 1598 (Q50 amendment 2 TRANSITIVE REUSE). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3c cloned commands.

### Context

Q52 clones /flow:review from workflows v3.29.4 commands/review.md. 354 lines; 9-step structure (Step 0-8). Lighter FDA-swap profile than Q51 — workflows review is workflow-generic; FDA-process-compliance is /flow:audit's job (Q38), not /flow:review's. Q52 → Q53 dependency direction (memory:1577-1581): Q52 must land BEFORE Q53. Q50 amendment 2 (memory:1598) classifies Step 4's 15 workflows agents as TRANSITIVE REUSE.

### What

`plugins/flow-architecture/commands/review.md`.

**HTML-comment header (Q52 sub-decision 1 / memory:1526-1529):**
```
<!-- Cloned from workflows v3.29.4 (commands/review.md) on 2026-05-07. Drift-detection per parking lot #45. -->
```

**Q52 sub-decision 3 — per-step FDA-swap classification.** See memory:1538-1545 for locked 9-row table — DO NOT re-derive. Summary:

- Step 0 (Verify Agent Dispatch) — Preserved verbatim
- **Step 1 (Self-Verification) — Preserved + PASSIVE-context augment per refinement 4:** additionally reads intent.md + story doc (Q27) + parent issue body (with `## L3 review summary`); provides as PASSIVE context. Q52 does NOT enforce alignment between diff and AC/success-criteria — that overlaps with /flow:audit
- Step 2 (Diff Triage), Step 3 (Simplify Pass) — Preserved verbatim
- **Step 4 (Select & Launch Review Agents) — Preserved + PLAN-CONTEXT augment per refinement 2 user lock 2026-05-07.** TRANSITIVE REUSE of 15 workflows agents per Q50 amendment 2 — invoked verbatim via Step 4 preserved content. FDA augment: reviewer-agent prompts include plan-X-section content read from discipline-child issue body via Q46 markers (READ pattern); reviewers see "Plan context (what was planned for this discipline child): . Diff: git diff BASE...HEAD". ~10 lines per agent prompt (Tier 1 always: code-reviewer, security-reviewer, performance-reviewer; Tier 2 stack-conditional; Tier 3 opt-in)
- Steps 5-7 — Preserved verbatim
- **Step 8 (Final Report) — Preserved + ship-link swap:** /workflows:ship → /flow:ship

**3 FDA-touched steps (1, 4, 8) out of 9.**

**Q52 sub-decision 5 — Q46 NONE in v1 (memory:1559):** Q46 type registry NOT extended (v1 enum stays at 8 types per Q46 sub-decision 2). review-summary reserved for v1.1 promotion (parking lot #49).

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/review.md` succeeds
- `grep -q "Cloned from workflows v3.29.4" plugins/flow-architecture/commands/review.md`
- `grep -c "^## Step [0-9]" plugins/flow-architecture/commands/review.md` returns 9
- `grep -q "Plan context (what was planned" plugins/flow-architecture/commands/review.md` (Step 4 PLAN-CONTEXT augment)
- `grep -q "PASSIVE.context\|PASSIVE context" plugins/flow-architecture/commands/review.md` (Step 1 augment)
- 3 separate greps for Tier 1 always-on agents: code-reviewer, security-reviewer, performance-reviewer
- `grep -A5 "## Step 8" plugins/flow-architecture/commands/review.md | grep -q "/flow:ship"` (ship-link swap)
- `grep -vq "FDA-process-compliance" plugins/flow-architecture/commands/review.md` (process-compliance is /flow:audit's job per Q52 sub-decision 4)
- `grep -vq "review-summary" plugins/flow-architecture/commands/review.md` OR explicit "v1.1 only" comment around it

### Out of scope

FDA process-compliance checking (lives in /flow:audit per Q38 + Q52 sub-decision 4 boundary); workflows agent re-implementation (TRANSITIVE REUSE per Q50 amendment 2); v1.1 deflections: parking lot #48 (--audit-preflight), #49 (review-summary writeback v1.1 sequence), #50 (plan-context augment retire if no signal).

### Dependencies

Workflows plugin v3.29.4 dependency declared in Standalone #1 plugin.json; P2 if any FDA-specific reviewers slot into Step 4.

### Re-address before starting

Re-read Q52 (memory:1524) + Q50 amendment 2 (memory:1598). Re-verify workflows v3.29.4 review.md via `gh api` at clone time — Q52 re-verification 2026-05-07 was a separate event from Q50 verification; same discipline applies here.

---

## 14 — flow-architecture — clone + FDA-swap /flow:ship  ← HIGHEST PRIORITY REVISION

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1621 (Q53) + line 1622-1646 (Q53 sub-decision 3 per-step classification — 9-row locked table identifying 7 FDA-touched steps; DO NOT re-derive) + line 1641 (Q46 ship-summary call signature) + line 1654 (Q53 sub-decision 7 retro soft-notification) + line 1662 (telemetry strip per Q50 axis 7) + line 1639 (Q38 audit pre-flight exit-code handling) + line 1598 (Q50 amendment 2). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3c cloned commands + §3h gate stack.

### Context

Q53 clones /flow:ship from workflows v3.29.4 commands/ship.md. **Heaviest swap profile of the 3 cloned commands — 7 of 9 steps FDA-touched** per Q53 sub-decision 3 (Steps 0, 7 verbatim; Steps 1, 2, 3, 4, 5, 6, 8 FDA-touched). Convergence point — touches Q38 audit pre-flight + Q46 ship-summary writeback (PRIMARY consumer) + Q43 plan completion + Q44 retro coordination + Q42 L1 concerns + Q22-Q27 narrative artifacts.

### What

`plugins/flow-architecture/commands/ship.md`.

**HTML-comment header (memory:1627-1630):**
```
<!-- Cloned from workflows v3.29.4 (commands/ship.md) on 2026-05-07. Drift-detection per parking lot #45. -->
```

**Q53 sub-decision 3 — per-step FDA-swap classification (memory:1636-1646 — see locked 9-row table; DO NOT re-derive):**

- Step 0 (Verify GitHub CLI) — Preserved verbatim
- **Step 1 (Pre-Ship Checks) — Preserved + AUDIT pre-flight (Q38) + PLAN-X verification augments.** Invokes `/flow:audit --domain=<DOMAIN>` (scope-filtered via Q24 mod 3 label parse); halts on Q38 exit 1 (unoverridden hard fail) or exit 2 (verify-docs fail) per Q38 sub-decision 6; soft-gate warnings surface but don't halt. Plan-X verification: regex check for `Plan not yet generated` stable substring; halt with redirect to `/flow:plan-<discipline>` if still placeholder
- **Step 2 (Create Pull Request) — Preserved + FDA-swap (PR description content):** PR description references FDA-shaped milestone (Q22) + sub-flow parent (Q23) + 5 discipline children (Q24); links to story doc (Q27) + journey doc (Q26) + intent.md (Q41). PR title format remains workflows-faithful (concise imperative under 70 chars)
- **Step 3 (Update Linear) — FDA-swap (Q46 routing) — PRIMARY ship-summary consumer.** Single Q46 write per invocation:
  ```
  linear_writeback({
    issue_id: <discipline-child-id>,
    type: 'ship-summary',
    surface: 'comment',
    content: <PR-link + summary>,
    signature: '_Generated by /flow:ship for <issue-id> on <ISO-8601>_',
    breadcrumb_path: <breadcrumb_path>,
    warn_on_clobber: true
  })
  ```
  Status move + PR attachment NOT Q46-routed (direct Linear MCP per workflows pattern).
- Step 4 (Compound Learnings) — Preserved verbatim (TRANSITIVE REUSE of compound-learnings per Q50 amendment 2)
- Step 5 (Best Practices Audit) — Preserved verbatim (TRANSITIVE REUSE of best-practices-audit per Q50 amendment 2)
- Step 6 (Handbook Drift Check) — Preserved verbatim (TRANSITIVE REUSE of handbook-drift-check per Q50 amendment 2)
- Step 7 (Worktree Cleanup) — Preserved verbatim
- **Step 8 (Session Close) — Preserved + RETRO-NOTIFICATION augment per Q53 sub-decision 7 user lock (memory:1654):** detect "is this the last sub-flow in domain?" via Linear query (all sibling sub-flows in milestone completed?); if yes, append soft notification: "This shipped the last sub-flow in `<DOMAIN>`. Consider running `/flow:retro <DOMAIN>` when ready." Preserves Q44 manual-only lock per parking lot #40.

**Telemetry strip per Q50 axis 7 (memory:1662):** workflows ship.md has telemetry-log.sh hooks at start + Step 8 end — FDA-clone STRIPS them.

**Plan completion data emission for Q44 (memory:1660):** Q53 emits plan-X-section read state into `linear_writeback_state.written_pairs[]` (Q31 amendment 2). v1.1 promotion of Q44 cross-skill-state mining (parking lot #43) consumes this.

### Acceptance criteria

- `test -f plugins/flow-architecture/commands/ship.md` succeeds
- `grep -q "Cloned from workflows v3.29.4" plugins/flow-architecture/commands/ship.md`
- `grep -c "^## Step [0-9]" plugins/flow-architecture/commands/ship.md` returns 9
- `grep -q "/flow:audit" plugins/flow-architecture/commands/ship.md` (Step 1 audit pre-flight)
- 4 separate greps for Q38 exit-code handling: `exit 1`, `exit 2`, `halt`, `soft.gate`
- `grep -q "Plan not yet generated" plugins/flow-architecture/commands/ship.md` (Step 1 plan-X verification)
- `grep -q "FDA-shaped PR description\|FDA-shaped" plugins/flow-architecture/commands/ship.md` (Step 2)
- `grep -q "FDA-WRITEBACK-ship-summary-" plugins/flow-architecture/commands/ship.md` (Step 3 Q46 marker, lowercase per CC5)
- `grep -q "type: 'ship-summary'" plugins/flow-architecture/commands/ship.md` (lowercase Q46 type value)
- `grep -q "_Generated by /flow:ship for" plugins/flow-architecture/commands/ship.md` (signature)
- 3 separate greps for TRANSITIVE REUSE skills (Steps 4/5/6): compound-learnings, best-practices-audit, handbook-drift-check
- `grep -qE "Consider running.*\/flow:retro" plugins/flow-architecture/commands/ship.md` (Step 8 retro soft-notification)
- `grep -vq "telemetry-log.sh" plugins/flow-architecture/commands/ship.md` (telemetry stripped per Q50 axis 7)

### Out of scope

v1.1 handbook-drift-check FDA-customization; workflows skill reimplementation (TRANSITIVE REUSE); Q53-specific gate v1.1 promotion to extend Q29 with plan-X-section discipline-completion gate (parking-lot candidate, forward-looking).

### Dependencies

Standalone #9 (/flow:audit pre-flight), Standalone #2 (`skills/_shared/linear-writeback-pattern.md`), workflows plugin dep, Standalone #11 (/flow:retro for Step 8 soft-notification target).

### Re-address before starting

Re-read Q53 (memory:1621) + Q50 amendment 2 (memory:1598) + Q53 refinement audit trail (memory:1664). Re-verify workflows v3.29.4 ship.md via `gh api` at clone time — Q53 caught Q50 sub-decision 2 classification gap via this discipline.

---

## 15 — flow-architecture — author plugin CLAUDE.md

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1680 (Q55) + line 1684-1697 (sub-decision 2 13-section enumeration verbatim; DO NOT re-derive) + line 1701 (sub-decision 3 length target) + line 1703-1708 (sub-decision 4 drift-tolerant MAP/MATRIX) + line 1710-1714 (sub-decision 5 cross-ref hybrid) + line 1715-1721 (sub-decision 6 4 disciplines) + line 1725-1730 (sub-decision 7 5 cross-cutting requirements). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §3c through §3i (full surface).

### Context

Q55 locks plugin CLAUDE.md content design. FDA-native synthesis from locked Qs — no external cribbing. Sibling-precedent verification: cadence CLAUDE.md exists (14257 bytes / 7 H2 sections via `gh api` 2026-05-08); workflows has none (404).

### What

Author `plugins/flow-architecture/CLAUDE.md` per Q55.

**Q55 sub-decision 2 — 13 H2 sections (locked order, memory:1684-1697 — DO NOT re-derive):**
1. Plugin overview — what FDA is + plugin's role + Brand Hub dogfood context (Q8)
2. Surface map — commands by role + sub-skills + agents + _shared utilities (drift-tolerant per sub-decision 4)
3. Workflows plugin dependency — REQUIRED prerequisite + 3-channel mechanism (Q50 sub-decisions 4-6)
4. MCP + dependencies — workflows linear-server + bash 3.x+ + python3 3.6+ + git 2.x+ + gh soft (Q32 + parking lot #29)
5. Bootstrap + first-run — flow-preflight embedded bootstrap (Q36) + `.flow/config.json` schema + per-org prerequisite (parking lot #33)
6. Quality gate stack reference — Q29 35-gate stack overview + override mechanics + override-counts-as-pass (Q38 sub-decision 6)
7. L-review pattern — L1/L2/L3/L4 scoping (Q54) + four-mode framework outcome contract (Q48; cross-cutting requirement #3)
8. Boundaries — /flow:audit vs /flow:review (Q52 sub-decision 4; cross-cutting requirement #5) + orchestrators vs utilities vs cloned commands + office-hours vs retro + sandbox-scaffold vs handoff agents
9. Q46 writeback layer — type registry + idempotency markers + double-layer safety (Q43 caller-side + Q46 executor-side; cross-cutting requirement #2) + batching convention (Q46 sub-decision 5; cross-cutting requirement #1)
10. Concurrency caveat — single-orchestrator-at-a-time (Q31.6 lock memory:298)
11. Methodology notes ("How this plugin evolves") — validation-first cycle + parking-lot-#39 + extension + three-way cribbing taxonomy (Q50 sub-decision 7; cross-cutting requirement #4) + schema-discipline amendment pattern
12. Pre-existing-vs-FDA-output mapping — what artifacts FDA creates vs already exists in BriteBase/Brand Hub repos
13. See also — pointers to CDR-023 + operating-standards FDA page + templates + parking lot reference

**Q55 sub-decision 3 length target (memory:1701):** ~15000-25000 bytes (~2700-4500 words target window for v1.0 acceptance); soft warn at >20000; HARD stop-loss >25000 with extraction paths: (a) extract section 11 → `plugins/flow-architecture/docs/methodology.md`; (b) per-area split (CLAUDE.md / DEPENDENCIES.md / METHODOLOGY.md).

**Q55 sub-decision 4 drift-tolerant MAP/MATRIX (memory:1703-1708):** "Slash command MAP" + "Sub-skill orchestration MAP" (categorical prose); "Agent dispatch MATRIX" (literal 2D table — rows=agents × columns=L-scope+invoker+return-shape). DON'T assert "FDA has 17 commands" (drifts); use categories with examples + source-of-truth pointers.

**Q55 sub-decision 5 cross-reference hybrid (memory:1710-1714):** absolute GitHub URLs cross-repo + relative paths same-repo + GitBook TODO comment (`<!-- TODO: when handbook migrates to public GitBook docs site, replace absolute GitHub URLs with GitBook canonical URLs. -->`).

**Q55 sub-decision 6 — 4 operational disciplines (memory:1715-1721):** validation-first cycle / parking-lot-#39 + extension / three-way cribbing taxonomy (FDA-native / gstack-inspired / workflows-cloned with locked examples) / schema-discipline amendment pattern. Cite the 4 disciplines.

**Q55 sub-decision 7 — 5 cross-cutting documentation requirements (memory:1725-1730):**
1. Q46 batching convention → section 9
2. Q43 double-layer safety → section 9
3. Q48 four-mode taxonomy → section 7
4. Q50 three-way cribbing taxonomy → section 11
5. Q52 /flow:audit vs /flow:review boundary → section 8

### Acceptance criteria

- `test -f plugins/flow-architecture/CLAUDE.md` succeeds
- 6 distinctive section greps: `^## Plugin overview`, `^## Surface map`, `^## Workflows plugin dependency`, `^## Q46 writeback layer`, `^## Concurrency caveat`, `^## Pre-existing-vs-FDA-output mapping`, `^## See also` (sample of 7 distinctive section names)
- Total H2 count: `grep -c "^## " plugins/flow-architecture/CLAUDE.md` returns exactly 13
- Length: `wc -c plugins/flow-architecture/CLAUDE.md | awk '{print $1}'` between 15000 and 25000
- 4 separate greps for Q48 four-mode taxonomy verbatim: SCOPE_EXPANSION, SELECTIVE_EXPANSION, HOLD_SCOPE, SCOPE_REDUCTION (cross-cutting #3)
- 3 separate greps for Q50 three-way taxonomy: FDA-native, gstack-inspired, workflows-cloned (cross-cutting #4)
- `grep -q "double-layer safety" plugins/flow-architecture/CLAUDE.md` (cross-cutting #2)
- `grep -q "batching" plugins/flow-architecture/CLAUDE.md` (cross-cutting #1)
- `grep -q "/flow:audit" plugins/flow-architecture/CLAUDE.md` AND `grep -q "/flow:review"` (cross-cutting #5)
- 4 separate greps for the 4 disciplines (sub-decision 6): `validation-first`, `parking.lot.#39`, `three-way cribbing`, `schema-discipline`
- `grep -q "MATRIX" plugins/flow-architecture/CLAUDE.md` (drift-tolerant agent dispatch table per sub-decision 4)
- `grep -q "GitBook" plugins/flow-architecture/CLAUDE.md` (sub-decision 5 TODO)

### Out of scope

Customer-facing user docs (separate concern); README install instructions (Standalone #1).

### Dependencies

Standalone #1 (skeleton), P1 / P2 / P3 / Standalones #2-14 (content the CLAUDE.md describes).

### Re-address before starting

Re-read Q55 (memory:1680) + Q55 refinement audit trail (memory:1746). Verify cadence CLAUDE.md current shape via `gh api` immediately before drafting (parking-lot-#39 R4 lesson). NOT a verbatim crib (FDA-native synthesis), but cadence anchors the H2-section convention.

---

## 16 — flow-architecture — production readiness checklist (v1.0 release gate)

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1769 (Q40) + line 1777-1795 (sub-decision 3 12 criteria across 4 categories — verbatim category names; DO NOT re-derive) + line 1803-1818 (Q8 7 sub-criteria) + line 1828-1844 (sub-decision 5 release sequence + ordering rationales) + line 1846 (sub-decision 6 v1.0/v1.1 boundary) + line 1854 (drift-detection verification command) + line 1862 (6 amendments correctly enumerated). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §7 plan forward.

### Context

Q40 locks the v1.0 production readiness checklist filling Q8's "successful Brand Hub retrofit" gap. Static doc form factor; no test surface for v1 (parking-lot #52-#55 capture test-surface candidates per Q40 R3 user lock). Dual-event triage distinction: **Triage Event #1** (pre-implementation, Phase 1 close — already done 2026-05-08, OUTSIDE Q40 release sequence) vs **Triage Event #2** (post-v1.0 re-triage, Category D item 12, INSIDE Q40 release sequence).

### What

Author `plugins/flow-architecture/docs/production-readiness.md` per Q40 sub-decisions.

**Q40 sub-decision 3 — 12 criteria across 4 categories (memory:1777-1795 — verbatim category names; DO NOT paraphrase):**

**Category A: Design phase complete (closes interview) — 2 criteria**
1. All 54 active Q-numbers (Q1-Q55 minus deleted Q39) have lock entries in memory, including 6 locked amendments (Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2 — count corrected from C handoff arithmetic error per drafter D R5 catch at memory:1862, 1873)
2. Memory file archived to `plugins/flow-architecture/docs/design-rationale.md`

**Category B: Implementation complete (plugin code shipped per locked specs) — 3 criteria**
3. Plugin manifest + directory structure per Q30 (commands, skills, agents, scripts, LICENSE, README, CLAUDE.md)
4. CLAUDE.md authored per Q55 spec — 13 H2 sections; 5 cross-cutting requirements have headings; 15000-25000 bytes
5. README.md authored per Q30.7

**Category C: Org prerequisites landed (handbook + about-handbook PRs) — 2 criteria**
6. handbook PR merged: CDR-023 (Q33) + CDR-014 amendment (Q35) + operating-standards FDA page (Q34)
7. about-handbook PR merged: Q22-Q28 promoted templates + Q41 PROJECT-INTENT.md template

**Category D: Dogfood + version flip (closes v1.0) — 5 criteria**
8. Brand Hub retrofit dogfood succeeds per Q8 (concrete sub-decision 4 definition)
9. Drift-detection baseline recorded — workflows v3.29.4 SHAs in HTML-comment headers
10. Plugin version bump 0.1.0 → 1.0.0 in plugin.json
11. CDR-023 status flip Proposed → Accepted (handbook PR amendment with Status section notation per Q35 pattern)
12. Post-v1.0 re-triage of parking lot (**Triage Event #2**; distinct from Triage Event #1 at Phase 1 close)

**Q8 "successful" 7 sub-criteria (memory:1803-1818)** — define dogfood success that Standalone #17 consumes: see verbatim in Standalone #17 spec.

**Q40 sub-decision 5 release sequence ordering rationales (memory:1839-1844):** 5 rationales — handbook + about-handbook PRs land BEFORE plugin code (live URLs); plugin code BEFORE dogfood; dogfood BEFORE version flip; version flip BEFORE CDR-023 Accepted; memory archive + post-v1.0 re-triage LAST.

**Q40 sub-decision 6 v1.0/v1.1 boundary (memory:1846):** if Triage Event #2 reveals a v1.0 blocker missed, escalate via NEW Q-lock (Q56+) rather than silently bypass — preserves design-rationale audit trail per schema-discipline pattern.

**Q40 sub-decision 7 drift-detection verification command (memory:1854):**
```
grep -l "Cloned from workflows v3.29.4" plugins/flow-architecture/commands/*.md
```
Must return 3 files (session-start, review, ship); other commands FDA-native (no header).

### Acceptance criteria

- `test -f plugins/flow-architecture/docs/production-readiness.md` succeeds
- `grep -c "^- \[ \]" plugins/flow-architecture/docs/production-readiness.md` returns exactly 12
- 4 separate greps for verbatim category names: `Design phase complete (closes interview)`, `Implementation complete (plugin code shipped per locked specs)`, `Org prerequisites landed (handbook + about-handbook PRs)`, `Dogfood + version flip (closes v1.0)`
- `grep -q "Triage Event #1" plugins/flow-architecture/docs/production-readiness.md` AND `grep -q "Triage Event #2"` (dual-event distinction explicit)
- 6 separate greps for the 6 amendments: `Q31 amend 1`, `Q31 amend 2`, `Q24 amend 1`, `Q21 amend 1`, `Q50 amend 1`, `Q50 amend 2`
- `grep -q "Q1-Q55 minus deleted Q39" plugins/flow-architecture/docs/production-readiness.md`
- `grep -q "grep -l \"Cloned from workflows v3.29.4\"" plugins/flow-architecture/docs/production-readiness.md` (drift-detection command per sub-decision 7)
- `grep -q "0.1.0.*1.0.0" plugins/flow-architecture/docs/production-readiness.md` (version bump)

### Out of scope

Test-surface implementation (parking-lot #52-#55, v1.1); CDR-023 status flip execution (Standalone #18); v1.1 release-readiness checklist (separate concern).

### Dependencies

None for authoring; executes against Standalones #1-15 + P1-P3 deliverables.

### Re-address before starting

Re-read Q40 (memory:1769) + Q40 refinement audit trail (memory:1856). Apply report-time arithmetic verification discipline (drafter D self-catch 2026-05-10): when this checklist is later marked off, reconcile actual file counts against `wc -l` / `ls -1 | wc -l` output captured in the same report.

---

## 17 — flow-architecture — Brand Hub dogfood (outer-loop Phase 6 / Q40 release sequence step 5; Q8 v1 acceptance gate)

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 62 (Q8) + line 1803-1818 (Q8 7 sub-criteria verbatim — embed; DO NOT re-derive) + line 1769 (Q40 sub-decision 4) + line 1810 (Brand Hub determines its own FDA-domain count at runtime — NOT 27 legacy-milestone-count). Handbook: CDR-023, ops-standards FDA page. Architecture overview: §7 (this is outer-loop Phase 6 / Q40 release sequence step 5).

### Context

**Phase naming clarification:** Q40 release sequence step 5 = Brand Hub dogfood. Architecture overview §7 outer-loop labels are Phase 5 = Implementation, Phase 6 = Production / Brand Hub dogfood. To avoid collision with /flow:start-project Phase 5 (doc-author) and Q40 release sequence step naming, this issue is titled "Brand Hub dogfood" with explicit "outer-loop Phase 6 / Q40 release sequence step 5" qualifier.

Q8 (memory:62) locks Brand Hub as the v1.0 acceptance test: /flow:retrofit-project end-to-end against Brand Hub must complete cleanly. Q40 sub-decision 4 sequences the dogfood inside the release sequence (step 5). Brand Hub legacy-milestone-count is 27 pre-FDA; FDA-domain count is determined at runtime by /flow:retrofit-project (NOT 27 — drafter B catch).

### Goal

Run /flow:retrofit-project end-to-end against Brand Hub, iterate to clean retrofit, surface parking-lot promotions revealed by dogfood.

### What

Execute /flow:retrofit-project against Brand Hub repo. Capture per-phase failures + iterate fixes. Verify clean run end-to-end. Surface dogfood findings.

**Q8 7 sub-criteria for "successful" (memory:1803-1818 — verbatim goal-state; DO NOT re-derive):**

A Brand Hub /flow:retrofit-project run is SUCCESSFUL when:
1. All 9 retrofit phases complete without unrecovered failures (Q37 retrofit phase sequence with legacy-cross-reference per Q14)
2. 5 user-confirmation gates fire as expected (Q10 retrofit gate budget)
3. Outputs match locked schemas:
   - `docs/product/intent.md` per Q41 template
   - `docs/product/master-flow-inventory.md` per Q11 codebase-scan output (Brand Hub determines its own FDA-domain count at runtime — NOT pinned to BriteBase's 28 nor legacy-milestone count of 27)
   - `docs/product/flows/<domain>/<flow-id>.md` per Q27
   - `docs/product/journeys/<domain>.md` per Q26
   - `docs/product/flows/INDEX.md` per Q25
   - Linear milestones + parents + 5N children chain per Q22-Q24 + Q13
   - Cross-reference appendices on legacy milestones per Q14 + Q9
4. /flow:audit against retrofitted Brand Hub returns exit 0
5. `npm run build && npm run lint && npm test` pass on Brand Hub repo
6. Linear FDA-shaped milestones + 5N discipline children created cleanly
7. Failure modes documented at design-rationale path (subdirectory file: `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md`)

**Path coordination with Standalone #18:** subdirectory `docs/design-rationale/` for multi-file artifacts (dogfood findings here; memory archive at #18). Standalone #18 archives memory file to `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` to coexist with this dogfood-findings file.

**In-flight bug-fix issue protocol:** dogfood is iterative; bug-fix issues created in plugin repo Linear during dogfood are OUT OF SCOPE for this milestone but listed in dogfood findings doc.

### Acceptance criteria (one per Q8 sub-criterion)

- 5 separate `test -f` checks against Brand Hub repo: `docs/product/intent.md`, `docs/product/master-flow-inventory.md`, `docs/product/flows/INDEX.md`; plus `find docs/product/flows -mindepth 2 -name "*.md" | head -1` returns at least one per-sub-flow story doc; plus `find docs/product/journeys -name "*.md" | head -1` returns at least one journey doc
- /flow:audit against Brand Hub repo exits 0 (criterion 4)
- `cd brand-hub && npm run build && npm run lint && npm test` all exit 0 (criterion 5)
- Linear MCP query confirms FDA-shaped milestones (`<DOMAIN>:` prefix) + parents (`<DOMAIN-NN>:` titles) + 5N discipline children (criterion 6)
- `test -f plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` succeeds (criterion 7)
- `git log` brand-hub-repo shows commit landing FDA artifacts

### Out of scope

v1.0 release tag + CDR-023 status flip (Standalone #18 outer-loop Phase 6+); v1.1 backlog grooming (post-v1.0 re-triage).

### Dependencies

ALL P1/P2/P3 + Standalones #1-15 (full plugin v1.0 surface implemented first).

### Re-address before starting

Re-read Q8 (memory:62) + Q40 sub-decision 4 (memory:1803-1818). Critical lesson: do NOT confuse Brand Hub's 27 pre-FDA legacy milestones with the FDA-domain count (catch from drafter B). The runtime count emerges from flow-inventory-codebase-scan (Q11).

---

## 18 — flow-architecture — release v1.0 (tag + CDR-023 Accepted + memory archive + Triage Event #2)

> Memory: ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md line 1769 (Q40) + line 1828-1844 (Q40 sub-decision 5 release sequence steps 7-9) + line 1779 (Category A item 2 archive path) + line 1846 (sub-decision 6 v1.0/v1.1 boundary policy). Handbook: CDR-023 (status flips Proposed → Accepted at this issue), ops-standards FDA page. Architecture overview: §7 release v1.0.

### Context

Q40 release sequence steps 7-9 + memory archive: (7) plugin version bump 0.1.0 → 1.0.0; (8) handbook PR amendment flipping CDR-023 status Proposed → Accepted per Q35 amendment pattern; (9) post-v1.0 re-triage (Triage Event #2). Memory archive (Category A item 2): brite-base path-keyed memory becomes historical; design-rationale at `plugins/flow-architecture/docs/design-rationale/` becomes canonical. **Note this is the FIRST archive at v1.0 release** (drafter D windup said "already migrated" — that was the in-flight working archive at Phase 3 trigger; v1.0 is the canonical post-dogfood archive).

### Goal

Cut v1.0 release: bump version, flip CDR-023 status, archive memory file, re-triage parking lot.

### What

1. Bump `plugins/flow-architecture/.claude-plugin/plugin.json` version 0.1.0 → 1.0.0
2. Open **SECOND** handbook PR (CDR-023 already shipped via PR #513 merged 2026-05-10; status flip is an amendment to the existing file, NOT a new file create) flipping `Status: Proposed` → `Status: Accepted` per Q35 amendment-with-audit-trail pattern: **preserve original `Status: Proposed` text in HTML comment audit-trail BEFORE flipping** (schema-discipline; do not silently overwrite — 16 amendments precedent across interview)
3. Archive memory file to `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` (subdirectory coordination with Standalone #17 dogfood findings) AND verify integrity post-archive via bit-for-bit diff
4. Run **Triage Event #2** (post-v1.0 re-triage per Q40 sub-decision 5 step 9): walk all parking-lot entries, promote v1.1 candidates to Linear backlog, retire obsolete entries, escalate any newly-discovered v1.0 blockers via NEW Q-lock (Q56+) per Q40 sub-decision 6 boundary policy rather than silently bypassing
5. Tag `flow-architecture@v1.0.0` in `Brite-Nites/brite-claude-plugins` — flagged as **"org convention beyond Q40-locked release sequence; included for marketplace consumer discoverability"**

### Acceptance criteria

- `cat plugins/flow-architecture/.claude-plugin/plugin.json | jq -r .version` returns `1.0.0`
- `gh api repos/Brite-Nites/handbook/contents/decisions/CDR-023-flow-driven-architecture.md | jq -r .content | base64 -d | grep -q "Status: Accepted"` succeeds
- AND `gh api repos/Brite-Nites/handbook/contents/decisions/CDR-023-flow-driven-architecture.md | jq -r .content | base64 -d | grep -qE "<!--.*Status: Proposed|^Status: Proposed.*archived"` succeeds (audit-trail comment preserves original)
- `test -f plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` succeeds
- `diff -q ~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` returns no output (bit-for-bit verification)
- `git tag -l "flow-architecture@v1.0.0"` shows the tag
- Triage Event #2 produces output artifact: `test -f plugins/flow-architecture/docs/design-rationale/triage-event-2-<YYYY-MM-DD>.md` (parking-lot re-triage outcome captured)

### Out of scope

v1.1 implementation work (separate milestone, created post-Triage Event #2); v1.0+ amendments to CDR-023 (separate handbook PRs).

### Dependencies

Standalone #17 (Brand Hub dogfood clean run) — must be complete.

### Re-address before starting

Re-read Q40 sub-decision 5 (memory:1828-1844) + sub-decision 6 v1.0/v1.1 boundary (memory:1846). Critical: schema-discipline amendment pattern (16 amendments precedent across interview) for CDR-023 status flip — preserve original `Status: Proposed` text in audit-trail comment, do not silently overwrite.
