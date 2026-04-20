# BC-5788 Plan — ADR-007: RevOps plugin design decisions

**Issue:** [BC-5788](https://linear.app/brite-nites/issue/BC-5788)
**Milestone:** RevOps Plugin
**Priority:** Medium
**Scope:** Write `docs/decisions/007-revops-plugin-design.md` capturing the 7 locked decisions from master plan §3. Update top-level `CLAUDE.md` to reference the new ADR.

## Context

Formalizes architectural decisions from the 2026-04-19 scoping session so future contributors don't re-litigate. Unblocks BC-5789 (plugins/revops/ scaffold + subtree import) per master plan §4 issue chain.

**Session-scope override to memorialize in this ADR:** decision #7 is being reframed from "rename `sf-*` → `brite-*`" to **"keep upstream skill names"**. The `revops/` plugin namespace + in-file attribution header already signal Brite-ownership; preserving upstream names keeps `git subtree pull` as a clean future option.

## Tasks

### Task 1 — Draft the ADR

**File:** `docs/decisions/007-revops-plugin-design.md`
**Format:** Match `docs/decisions/003-plugin-distribution-architecture.md` (Context → Options Considered → Decision → Consequences → Reversibility).
**Target:** ~120 lines, matching existing ADR cadence.

**Sections:**

1. **Context** — Why a new plugin, why separate from `marketing` and `workflows`. References BC-5534 (SF MCP adoption findings) and the gap where `workflows:ship` knows nothing about Brite SF deploy discipline.

2. **Decision Drivers** — Jaganpro/sf-skills availability, Brite-specific conventions in `brite-salesforce/CLAUDE.md`, need to augment not replace workflows.

3. **Decisions (7)** — each as a distinct subsection:
   - 3.1 Plugin name: `revops` (vs `salesforce`, `sfdx`, `sf-tools`)
   - 3.2 Adoption method: `git subtree` with `--squash` (vs fork, vs user-level install)
   - 3.3 Workflow integration: augment, don't replace
   - 3.4 MCP scope: `--toolsets data,metadata,testing --no-telemetry`, GA-only
   - 3.5 Skill filter: 13 keep, 22 skip, 7 agents skip
   - 3.6 Naming convention: **keep upstream skill names** (override of master plan §3.6). Rationale: plugin namespace already signals Brite, attribution header carries provenance, upstream-sync path stays clean.
   - 3.7 Renames deferred to per-skill Phase 3 issues — but after this ADR, the default for each Phase 3 issue is "no rename unless skill-specific reason justifies it."

4. **Rejected Alternatives** — per decision:
   - Pure fork (loses `subtree pull` optionality)
   - User-level Jaganpro install (can't layer Brite conventions)
   - `salesforce`-named plugin (too narrow; blocks dbt/Outreach/Gong expansion)
   - Extending `workflows` plugin (SF knowledge is domain, not process)

5. **Consequences**
   - Positive: upstream sync remains mechanical; fork-behavior by default.
   - Negative: drift from Jaganpro accumulates over time; periodic reconciliation needed if we ever do `subtree pull`.
   - Neutral: naming convention mirrors upstream — a small documentation burden ("this is Brite's `sf-deploy`, not Jaganpro's") falls on the attribution header inside each skill.

### Task 2 — Update top-level CLAUDE.md reference

**File:** `CLAUDE.md`
**Section:** `## Architecture Decisions`
**Edit:** Add one bullet:

```markdown
- [ADR-007: RevOps plugin design decisions](docs/decisions/007-revops-plugin-design.md) — naming, subtree, augment-not-replace, skill filter, MCP scope
```

### Task 3 — Verify + commit

Per the issue's objective test table:

| # | Command | Pass |
|---|---------|------|
| T1 | `ls docs/decisions/007-*.md` | File exists |
| T2 | `grep -E "Plugin name|Adoption method|Workflow integration|MCP scope|Skill filter|Naming convention|Renames deferred" docs/decisions/007-revops-plugin-design.md` | All 7 decisions present |
| T3 | `grep "Rejected Alternatives" docs/decisions/007-revops-plugin-design.md` | Section exists, ≥4 alternatives |
| T4 | `grep "007" CLAUDE.md` | ADR referenced in top-level CLAUDE.md |
| T5 | `./scripts/check-guardrails.sh --claude-md CLAUDE.md` | Pass |
| T6 | `./scripts/validate.sh` | Exit 0 |

**Commit:** `ADR-007: RevOps plugin design decisions`

## Out of scope

- Any work on `plugins/revops/` itself (that's BC-5789)
- Revisiting any decision except the naming convention override
- Changes to existing ADRs 001–003

## Worktree

Branch: `holden/bc-5788-adr-007-revops-plugin-design` (or equivalent). Given this is a 2-file change with no tests to baseline, a simple branch is sufficient — no need for a full isolated worktree.
