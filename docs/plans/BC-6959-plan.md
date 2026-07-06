---
issue: BC-6959
title: flow-architecture — implement 9 sub-skills (parent)
status: planned
last_reviewed: 2026-05-11
plan_version: 1
---

# BC-6959 Execution Plan

## Scope decision

BC-6959 is a coordination shell. Per its own body, children are created lazily as work begins. Two execution paths exist:

- **(A) Implement all 9 sub-skills in one PR.** Unblocks all 3 existing orchestrators (`/flow:start-project`, `/flow:retrofit-project`, `/flow:add-sub-flow`) and BC-6998 Brand Hub dogfood (target 2026-05-19). Big PR, but Q-canon already locked.
- **(B) Implement 1-3 simplest first, lazy-create rest across sessions.** Matches "lazy creation" spec letter; fragments work, orchestrators stay broken until cluster lands.

**Committed: Option A** — 9 sub-skills in one PR under a worktree. Each cribs locked Q-canon verbatim from `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` (Q11 / Q13 / Q14 / Q15 / Q16 / Q17 / Q18 / Q19 / Q20). Children created lazily after each sub-skill lands (Linear writes batched per BC-6000 same-commit discipline).

## Constraints

- Plugin version bump in same commit (BC-6000): `plugins/flow-architecture/.claude-plugin/plugin.json` 0.2.8 → 0.2.9 + matching `.claude-plugin/marketplace.json` entry.
- Skills must declare `disable-model-invocation: true` (Q7 / BC-6959 AC).
- `_shared/` lives at `plugins/flow-architecture/skills/_shared/` (Q30.2 / CC4 corrective memo) — already present (6 files).
- `scripts/` (BC-6956) already present (4 helper bash scripts).
- bash 3.2+ compatibility (macOS default; Q32).
- Python 3.6+ stdlib only — no PyYAML, no requests (Q32).
- Each SKILL.md ≈ 200-500 lines, modeled on `flow-preflight/SKILL.md` (396 lines).
- ASCII text only — no emojis in generated content per user memory.

## Task list

### T1 — Worktree setup
- EnterWorktree with name `bc-6959-fda-sub-skills`
- Verify clean baseline: `./scripts/validate.sh`
- Verify no flow-architecture skill dirs beyond `_shared/` and `flow-preflight/`

### T2 — Q-canon read pass
Read the 9 Q-lock sections from `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md`:
- Q11 (line ~68): flow-inventory-codebase-scan
- Q13 (line ~80): flow-linear-scaffold
- Q14 (line ~94): flow-legacy-cross-reference
- Q15 (line ~108): flow-doc-author
- Q16 (line ~126): flow-journey-author
- Q17 (line ~146): flow-sandbox-scaffold
- Q18 (line ~179): flow-regen-index
- Q19 (line ~208): flow-inventory-interview
- Q20 (line ~224): flow-inventory-add

### T3 — Implement 9 SKILL.md files (parallelizable)

Each follows the flow-preflight template shape:
1. Frontmatter: `name`, `description`, `user-invocable: false`, `disable-model-invocation: true`, `allowed-tools` (scoped per Q-canon), `license: MIT`, `metadata.version: "0.1.0"`, `metadata.q-locks`, `metadata.related-locks` (memory: refs).
2. Body section 1: 1-paragraph purpose statement.
3. Body section 2: Scope / contract / pre-conditions.
4. Body sections 3+: Q-canon sub-decisions verbatim (numbered to match memory).
5. Helper scripts table (where applicable).
6. Worked example (input → output).
7. `See also` footer.

Per-skill scope:

- **T3.1 `flow-regen-index` (Q18, simplest, no LLM dispatch)** — deterministic 11-column INDEX.md rebuild, idempotency via diff-aware no-op detection.
- **T3.2 `flow-inventory-add` (Q20)** — append-only sub-flow-add + domain-add modes.
- **T3.3 `flow-legacy-cross-reference` (Q14, retrofit-only)** — `## FDA migration` appendix on legacy milestones.
- **T3.4 `flow-sandbox-scaffold` (Q17)** — 3-mode STUB/WRAP/EXTRACT sandbox harness.
- **T3.5 `flow-doc-author` (Q15)** — per-sub-flow story-doc author + L3 review fanout.
- **T3.6 `flow-journey-author` (Q16)** — per-domain journey-doc author + L2 review fanout.
- **T3.7 `flow-inventory-interview` (Q19, greenfield)** — Socratic 5-phase inventory generator.
- **T3.8 `flow-inventory-codebase-scan` (Q11, retrofit)** — code-signal mining 5-phase inventory generator.
- **T3.9 `flow-linear-scaffold` (Q13, heaviest)** — milestone + parent + 5N children writeback; 2+7N writes/domain.

### T4 — Plugin version bump (BC-6000 same-commit)
- `plugins/flow-architecture/.claude-plugin/plugin.json`: 0.2.8 → 0.2.9
- `.claude-plugin/marketplace.json`: matching entry for flow-architecture

### T5 — Validation
- `./scripts/validate.sh` — all plugins
- `./scripts/check-guardrails.sh --claude-md plugins/flow-architecture/CLAUDE.md`
- Manual AC checks:
  - `find plugins/flow-architecture/skills -mindepth 1 -maxdepth 1 -type d -not -name '_shared' | wc -l` → `10`
  - `grep -L "disable-model-invocation: true" plugins/flow-architecture/skills/*/SKILL.md` → empty
  - All 9 `test -f plugins/flow-architecture/skills/<name>/SKILL.md` pass

### T6 — Lazy Linear child issues (Q3 hybrid granularity)
After all 9 SKILL.md files land + validation passes, create 9 child issues under BC-6959 via `save_issue` (one per sub-skill) with:
- Title: `flow-architecture — <skill-name> SKILL.md (sub-skill)`
- parentId: BC-6959 UUID (`c5dfd1a6-2efe-4dad-8ef9-fad28de14ed5`)
- projectId: Brite Plugin Marketplace (`941dbf85-b812-428a-a54e-1c688bdfb3ed`)
- state: Done (since work just landed; or In Progress if PR still open at creation time)
- Body: pointer to SKILL.md + Q-lock memory ref
- Label: `flow-architecture`, `skill`

### T7 — /workflows:review (thorough mode)
Loop until clean (per BC-6965 precedent: 3 iterations typical):
- Iter 1: review-fix-fold per /workflows:review
- Iter 2: review again, fix introduced regressions
- Iter 3: confirm clean across 4 agents (code, security, performance, simplify)

### T8 — /workflows:ship
- PR creation, BC-6959 status → In Review on PR open
- 9 child issues auto-attach via parentId
- compound-learnings: precedent traces for sub-skill cribbing pattern

## Risks

- **R1**: Q-canon at memory line ranges may have moved during recent edits. Verify line numbers via grep on `^\*\*Q<NN>` headings before cribbing.
- **R2**: 9 SKILL.md × ~400 LOC = ~3,600 LOC PR. Reviewers may push back on size. Mitigation: each file is independent; reviewer can scope per-skill.
- **R3**: Linear `save_issue` rate-limit when creating 9 children in T6. Mitigation: sequential creation, 1s gap between calls.
- **R4**: Plugin version bump cache propagation (BC-6000). Bump both files in same commit; verify both lines present in the merged diff.

## Out of scope

- Orchestrator wiring fixes (Standalones #5-8 / BC-6962/6963/6964/6965) — already done.
- `/flow:design-consult` v1.1 per Q45 deferral.
- Agents at `plugins/flow-architecture/agents/` (separate parent issue per MATRIX in plugin CLAUDE.md).
- `/flow:plan-X` discipline commands (P3).

## Next

T1 — worktree setup.
