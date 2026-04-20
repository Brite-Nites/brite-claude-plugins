# Precedent Index

<!-- INDEX format (BC-1955 Section 6):
  - Issue: Issue ID, links to docs/precedents/<ISSUE-ID>.md
  - Decision: Max 120 chars, single line — from the trace's Decision field
  - Category: architecture | library-selection | pattern-choice | trade-off | bug-resolution | scope-change
  - Date: YYYY-MM-DD — from the trace heading
  - Tags: Max 5, comma-separated, lowercase kebab-case, max 30 chars each
  Auto-updated by compound-learnings during /workflows:ship.
  Archive to INDEX-archive.md when rows exceed 200 (entries older than 6 months).
  See README.md in this directory for full conventions.
-->

| Issue | Decision | Category | Date | Tags |
|-------|----------|----------|------|------|
| [BC-2693](BC-2693.md) | Handbook (Context7) as Tier 1 universal SoR for all context-skills, domain MCP as Tier 2 | architecture | 2026-03-31 | context-skills, handbook, context7, sor-architecture, tiered-fallback |
| [BC-5758](BC-5758.md) | Later-locked research decision supersedes earlier-issue scope wording; flag at Plan, approve, commit/PR trail | scope-change | 2026-04-19 | scope-change, superseded-scope, mcp-registration, plan-checkpoint, cadence |
| [BC-2707](BC-2707.md) | Two-call MCP confirmation gate blocks same-turn auto-confirm, not affirmative vocabulary | pattern-choice | 2026-04-20 | confirmation-gate, two-call-pattern, turn-structure, mcp-orchestration, email-bison |
| [BC-5789](BC-5789.md) | Per-item audit at filter time can rescue items the locked plan would have lost; file follow-up for rescued items | pattern-choice | 2026-04-20 | pattern-choice, plugin-import, subtree, per-item-audit, scope-rescue |
| [BC-5793](BC-5793.md) | First-of-N session locks the template; update shared convention files (UPSTREAM.md) in same PR, don't defer | pattern-choice | 2026-04-20 | pattern-choice, first-of-n, shared-convention, plan-gate, revops-phase-3 |
| [BC-5760](BC-5760.md) | Canonical state-object schema lives in entry command; every phase PR updates it alongside skill body | architecture | 2026-04-20 | architecture, multi-phase, state-schema, cross-phase-drift, cadence |
| [BC-5794](BC-5794.md) | Sibling-one is the inflection point for first-of-N template validation; apply overrides verbatim or amend the precedent | pattern-choice | 2026-04-20 | pattern-choice, sibling-one, template-validation, revops-phase-3, cdr-coverage |
| [BC-5761](BC-5761.md) | Fix-review loops for markdown-spec PRs converge in 4-5 iterations; budget accordingly, cap at 5 | pattern-choice | 2026-04-20 | pattern-choice, review-loop, iteration-budget, markdown-spec, schema-drift |
| [BC-5823](BC-5823.md) | Handbook canon wins over issue-body scope for vertical/ICP/persona decisions; swap + document departure with user approval | pattern-choice | 2026-04-20 | pattern-choice, handbook-canon, scope-override, vertical-selection, marketing-plugin |
| [BC-5795](BC-5795.md) | Revert+reship beats forward-fix when post-merge review confirms P1 factual errors in agent-invoked skill | pattern-choice | 2026-04-20 | pattern-choice, post-merge-review, revert-reship, agent-invoked-skill, factual-errors |
