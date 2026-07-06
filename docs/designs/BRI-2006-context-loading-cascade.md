## Design: Define context loading cascade architecture

**Issue**: BRI-2006 — Define context loading cascade architecture
**Date**: 2026-03-16

### Problem
Context loading logic is scattered across 4+ skills with no unified reference. An implementer building a new skill has no single source for "what should my skill load and when?" — leading to inconsistent context loading and risk of bloating early stages with Tier 3 content.

### Approach
Write a standalone spec doc with the authoritative 7-stage loading table and 5-layer context model, audited against actual skill code. Add machine-parseable YAML blocks to workflow-spec.md. Add lightweight reference comments to the 4 inner-loop skills that load context. Descriptive for current state, prescriptive for the "narrowest scope" principle, "planned" markers for unbuilt capabilities.

### Key Decisions
1. **Spec doc + workflow-spec.md** (not just one) — Design doc captures narrative rationale and the cascade tables; workflow-spec.md gets YAML blocks for machine consumption and validation.
2. **Descriptive current + prescriptive principle** — Audit actual skill code to document what loads today. Mark future capabilities (CDR compliance at review, precedent search at brainstorm, per-task context filtering) as "planned" with issue refs. The "load at narrowest scope" rule is the prescriptive contract.
3. **Convention-enforced, not structurally enforced** — Skills get a reference comment pointing to the spec. No shared template extraction (markdown skills can't import shared logic). Future: validate.sh could check that context-loading skills reference the spec.
4. **Plugin repo, not handbook** — The cascade governs how the workflows plugin loads context. Domain plugins would define their own loading patterns.

### Alternatives Considered
- **Runtime context router** — Agent reads the spec at runtime to decide what to load. Rejected: over-engineering for now, belongs to BRI-2003/BRI-1966 territory.
- **Fully prescriptive spec** — Codify the full PRD vision as target state. Rejected: risks committing to designs for unbuilt features (precedent search, CDR compliance agent) we haven't validated.
- **Handbook-only location** — Rejected: cascade is plugin-specific, not company-wide.

### Risks & Mitigations
- **Spec drift** — Skills evolve but spec doesn't update. Mitigation: reference comments in skills create a breadcrumb trail; validate.sh could enforce cross-references.
- **Over-specification** — Spec constrains future designs unnecessarily. Mitigation: "planned" markers are advisory, not contractual.

### Scope Boundaries
- **In scope**: Spec doc at `docs/designs/BRI-2006-context-loading-cascade.md`, YAML blocks in workflow-spec.md, reference comments in session-start/writing-plans/executing-plans/brainstorming, audit current skills against cascade, update Linear cross-references on BRI-1938/BRI-1945/BRI-1939/BRI-2003
- **Out of scope**: Runtime context router, behavioral changes to existing skills, CDR compliance review agent, precedent search implementation, validate.sh enforcement check

### Open Questions
- None

---

## Authoritative Specification

### Governing Principle

> **Load context at the narrowest scope that still informs the decision.**

Tier 3 content (full CDR documents, precedent traces, analytical metrics) is NOT loaded at session-start. It waits for the stage where it's actually needed (brainstorm, plan, execute). Pre-loading broad context wastes budget and adds noise.

### Context Tiers

| Tier | What | When loaded | Budget |
|------|------|-------------|--------|
| **Tier 1** (always) | Project CLAUDE.md, auto-memory | Session start | ~50-100 lines |
| **Tier 2** (per-project) | Company Context pointers, domain context docs via @imports | Session start | ~80-200 lines per doc |
| **Tier 3** (on-demand) | Full CDR documents, precedent search results, analytical context, live MCP queries | Agent reads when task requires it | Variable |

### 7-Stage Loading Table

| Stage | Skill/Command | What loads today | How | Status |
|-------|--------------|-----------------|-----|--------|
| **project-start** | `project-start.md` | Trait classification, CLAUDE.md generation with @imports | Interview + write | Implemented |
| **session-start** | `session-start.md` | CLAUDE.md (Tier 1+2), auto-memory, Company Context check, @import freshness check, Linear issues | Read + MCP queries | Implemented |
| **brainstorm** | `brainstorming/SKILL.md` | Linear issue, CLAUDE.md, auto-memory, relevant source code, precedent INDEX search | Read + Linear MCP + Read INDEX + Context7 MCP | Implemented |
| **plan** | `writing-plans/SKILL.md` | Design doc, Linear issue, CDR INDEX via Context7, precedent INDEX (Tier 3 on-demand), source code, test patterns | Read + Context7 MCP + Read INDEX | Implemented |
| **execute** | `executing-plans/SKILL.md` | Design doc + plan file (parent); task description + relevant files + conventions (subagent) | Read; subagent gets narrowest scope | Implemented |
| **review** | `review.md` | Diff stat, changed files; review agents read files themselves | git diff + agent dispatch | Implemented |
| **ship** | `ship.md` + `compound-learnings/SKILL.md` | CLAUDE.md, diff, commit history; captures learnings back | Read + write | Implemented |

**Planned additions** (not yet implemented):

| Stage | What will load | Issue |
|-------|---------------|-------|
| plan | CDR conflict check with full CDR lazy-load | BRI-1939 (partial — CDR INDEX query implemented, full conflict flow planned) |
| execute | Per-task context filtering (task-level, not project-level) | BC-2003 (delivered) |
| review | CDR compliance check ("does this PR violate active CDRs?") | No issue yet |
| session-start | Freshness tracking on @imported context docs | BC-1938 (delivered) |

### 5-Layer Context Model

| Layer | Scope | Examples | Loaded at | Refresh | Status |
|-------|-------|---------|-----------|---------|--------|
| **Company** | Organization-wide | CDR INDEX, org structure, brand guidelines | session-start (via CLAUDE.md @imports) | Quarterly | Partially implemented (Company Context pointers; @imports planned in BRI-1945) |
| **Precedent** | Historical decisions | Past ADRs, decision traces, search results | brainstorm, plan | Continuous | Implemented (BC-1961) |
| **Domain** | Plugin-specific | engineering-context.md, design-context.md | project-start (plugin activation) | Per context-skill standard | Planned (BRI-1966) |
| **Project** | This project | CLAUDE.md, docs/, architecture decisions | session-start | Every session | Implemented |
| **Task** | Current task | Relevant files, test results, Linear issue | execute (per subagent) | Every task | Implemented |

### Cross-References

This spec is referenced by:
- `plugins/workflows/commands/session-start.md` — Tier 1+2 loading
- `plugins/workflows/skills/brainstorming/SKILL.md` — Tier 1+2 loading
- `plugins/workflows/skills/writing-plans/SKILL.md` — Tier 1+2 + Tier 3 CDR on-demand
- `plugins/workflows/skills/executing-plans/SKILL.md` — Task-scoped (Tier 5) loading
- `plugins/workflows/skills/precedent-search/SKILL.md` — Precedent search algorithm (Tier 3 on-demand)

Related issues:
- BRI-1938 — Freshness tracking in session-start
- BRI-1945 — CLAUDE.md with dynamic @imports
- BRI-1939 — CDR-check pattern in writing-plans
- BC-2003 — Context budget management strategy

### Budget Enforcement

Budget guards and per-task context selection are defined in:
- **Design doc**: `docs/designs/BC-2003-context-budget-management.md` — strategies, measurement baseline, offloading table
- **Machine-parseable spec**: `docs/workflow-spec.md` Section 6d (`<!-- spec:cascade:budget-guards -->`) — guards, offloading strategy, progressive disclosure patterns
