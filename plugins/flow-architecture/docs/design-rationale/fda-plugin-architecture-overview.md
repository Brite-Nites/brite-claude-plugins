# FDA Plugin (`flow-architecture`) — Architecture Overview & Design Synthesis

**Date:** 2026-05-08 (D session-end; design phase officially closed)
**Status:** Design phase COMPLETE — 54 Q-locks + 6 amendments; 0 pending
**Source-of-truth:** `~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md` (2,110 lines)
**Snapshot backup:** `docs/plans/fda-plugin-interview.md` (sibling file; 2,110 lines as of D session-end)

This document is a **synthesized architecture overview** of the multi-session design interview. It is not the canonical source — the memory file is. This is a reading aid: someone walking in cold should be able to read this and understand what we're building, why, and what's left to decide.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [How This Was Designed — Multi-Session Interview Pattern](#2-how-this-was-designed)
3. [The Architecture — FDA Plugin v1](#3-the-architecture)
   - 3a. [The 4-Tier FDA Hierarchy](#3a-the-4-tier-fda-hierarchy)
   - 3b. [Cross-Substrate Mapping (Linear ↔ Repo)](#3b-cross-substrate-mapping)
   - 3c. [Plugin Command Surface (~17 commands)](#3c-plugin-command-surface)
   - 3d. [Sub-Skill Dependency Graph](#3d-sub-skill-dependency-graph)
   - 3e. [Greenfield Orchestrator Phase Flow](#3e-greenfield-orchestrator-phase-flow)
   - 3f. [Retrofit Orchestrator Phase Flow](#3f-retrofit-orchestrator-phase-flow)
   - 3g. [Multi-Perspective L-Review Pattern](#3g-multi-perspective-l-review-pattern)
   - 3h. [Quality Gate Stack (36 gates post-Q29 amendment 2)](#3h-quality-gate-stack)
   - 3i. [State Substrates — Where Things Live](#3i-state-substrates)
4. [Locked Decisions Summary](#4-locked-decisions-summary)
5. [Pending Decisions](#5-pending-decisions)
6. [Methodology — Validation-First Multi-Session Pattern](#6-methodology)
7. [The Plan Forward — 6 Phases](#7-the-plan-forward)
8. [Migration Map — Where Artifacts Eventually Live](#8-migration-map)
9. [Parking Lot — v1.1+ Candidates (55 items at D session-end)](#9-parking-lot)
10. [Appendix A — ASCII Diagram Index](#appendix-a-ascii-diagram-index)
11. [Appendix B — Q-Lock Cross-Reference](#appendix-b-q-lock-cross-reference)

---

## 1. Executive Summary

The **flow-architecture** Claude Code plugin codifies **CDR-023 — Flow-Driven Architecture** for UI-bearing software builds at Brite. It generalizes the ad-hoc patterns BriteBase developed manually (28 domains, ~397 sub-flows, 5-discipline children per parent) into reusable plugin tooling.

### What the plugin produces

For any UI-bearing project (web app, mobile app, internal tool with user-facing UI), the plugin scaffolds:

- **Linear hierarchy:** Milestones (= Domains) + parent issues (= Sub-flows) + 5-discipline children per parent (`[Story]` / `[Eng]` / `[Design]` / `[QA]` / `[Docs]`)
- **Repo hierarchy:** `docs/product/intent.md` (project anchor) → `master-flow-inventory.md` (FK registry) → `journeys/<domain>.md` (per-domain narrative) → `flows/<domain>/<flow-id>.md` (per-sub-flow story doc) → `INDEX.md` (cross-reference table, auto-regenerated)
- **Cross-org artifacts:** templates promoted to `Brite-Nites/handbook/about-handbook/style-guide/templates/`; CDR-023 + amendment to CDR-014 + operating-standards page in `Brite-Nites/handbook/`

### v1 surface (~17 slash commands)

- **4 orchestrators:** `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`
- **6 inner-loop utilities:** `/flow:audit`, `/flow:office-hours`, `/flow:retro`, `/flow:session-start`, `/flow:review`, `/flow:ship`
- **5 plan-X suite:** `/flow:plan-{story,eng,design,qa,docs}`
- **2 deferred to v1.1:** `/flow:design-consult`, `/flow:journey-refresh`

### v1 acceptance gate (Q8)

First successful **Brand Hub** retrofit using `/flow:retrofit-project`. v1.0 ships when this passes.

### Current design state (D session-end 2026-05-08 — DESIGN PHASE COMPLETE)

- **54 active Q-numbers all locked** (Q1-Q55 minus deleted Q39 = 54). D-session locks: Q55 (plugin CLAUDE.md content), Q40 (production readiness), Q45 (`/flow:design-consult` v1.1 deferral, tracking-only), Q49 (canonical design-system v2+ tracking, tracking-only).
- **0 Qs pending** — design phase officially closed 2026-05-08.
- **16 amendments locked**: Q21 amend 1 (scope-axis fields per Q48), Q24 amend 1 (Plan-section markers per Q43), Q31 amend 1 (office_hours_state per Q42), Q31 amend 2 (linear_writeback_state per Q46), Q50 amend 1 (step count + step-swap-location per Q51 catch), Q50 amend 2 (TRANSITIVE REUSE classification per Q53 catch), **Q33 amend 1 / Q34 amend 1 / Q35 amend 1** (CDR-022 → CDR-023 renumber per Step 2.A pre-flight catch 2026-05-08; handbook collision with `CDR-022-asset-taxonomy.md`), **Q2 amend 1 / Q22 amend 1 / Q28 amend 1 / Q41 amend 1 / Q33 amend 2 / Q34 amend 2 / Q49 amend 1** (about-handbook subdir path correction + brite-design-system already-exists per Step 2.B pre-flight catch 2026-05-10; about-handbook is subdirectory of handbook repo, not separate repo; brite-design-system created 2026-02-03 invalidates Q49 v2+ "future canonical" framing). C handoff arithmetic error ("5 amendments") corrected at memory:1884 per drafter D Q40 R5 catch.
- **55 parking-lot v1.1+ candidates** with explicit trigger criteria. D session added #52-#55 (test-surface candidates per Q40 R3 user lock). Numbering disorder (#32/#33/#34) corrected per Step 1.A triage.
- **Phase H + Phase J + Phase I all complete** — interview design phase closed. Phase 1 close housekeeping (parking-lot triage + sibling-artifact regen) in progress; Phase 2 PR landing next.

---

## 2. How This Was Designed

This plugin's architecture wasn't designed in a single session. It evolved through a **multi-session validation-first interview** spanning weeks of conversation across 3 distinct Claude sessions, mediated by the user (Holden) as clipboard bus + lock signaler.

### Three-role pattern

```
                  ╔══════════════════════════════════╗
                  ║              USER                ║
                  ║   (clipboard bus + lock signal)  ║
                  ╚════╤═══════════════════════╤═════╝
                       │                       │
            paste C ──→│                       │←── paste me
                       ↓                       ↑
        ┌──────────────────────┐    ┌──────────────────────┐
        │   ORCHESTRATOR       │    │     DRAFTER          │
        │   session (me)       │    │   B → C → ...        │
        │                      │    │                      │
        │  • evaluates draft   │    │  • reads memory 1st  │
        │  • drafts refinements│    │  • drafts per-Q      │
        │  • pushes back       │    │  • validates against │
        │  • recommends reply  │    │    file (catches my  │
        │                      │    │    stale recall)     │
        └──────────┬───────────┘    └──────────┬───────────┘
                   │ recall claims             │ writes / reads
                   │ (fallible)                │ (canonical)
                   ↓                           ↓
        ┌──────────────────────────────────────────────────┐
        │         AUTO-MEMORY FILE (source of truth)       │
        │                                                  │
        │  ~/.../memory/project_fda_plugin_interview.md    │
        │  ~1,000+ lines                                   │
        │  ┌────────────────────────────────────────────┐  │
        │  │  Q1 → Q47 lock entries (final content)     │  │
        │  │  Parking lot (~34 v1.1+ items)             │  │
        │  │  Validated handbook conventions            │  │
        │  │  Refinement audit trails per Q             │  │
        │  │  Cross-session handoff notes               │  │
        │  └────────────────────────────────────────────┘  │
        │  Survives compaction. Single source when         │
        │  sessions disagree.                              │
        └──────────────────────────────────────────────────┘
```

**Why three roles:**

- **User** = clipboard bus + final authority on locks. Pastes outputs between sessions, signals "lock this" when ready.
- **Orchestrator session (Claude A, me)** = second-pair-of-eyes review. Evaluates drafts, suggests refinements, pushes back on weak reasoning. My TaskList went stale early; my recall is fallible.
- **Drafter session (B, then C)** = primary design author. Drafts per-Q designs, validates orchestrator-pasted suggestions against the memory file + actual lock entries. Pushes back when orchestrator is wrong. Writes Q-locks + audit trails to memory after user signals approval.

### The validation-first cycle

```
   ╭──── Validation-first loop (per Q) ───────────────────╮
   │                                                      │
   │   1. Drafter outputs Q-design                        │
   │             ↓ user pastes                            │
   │   2. Orchestrator evaluates, drafts N refinements    │
   │             ↓ user pastes                            │
   │   3. Drafter VERIFIES each against memory + files    │
   │        ✓ holds       → apply                         │
   │        ✗ wrong       → push back w/ line citation    │
   │        ⚠ user-call   → AskUserQuestion              │
   │             ↓                                        │
   │   4. User locks                                      │
   │             ↓                                        │
   │   5. Drafter writes memory entry + audit trail       │
   │             ↓                                        │
   │   6. Loop → next Q                                   │
   │                                                      │
   ╰──────────────────────────────────────────────────────╯
```

**Why validation-first:** orchestrator session recall is imperfect across compactions and long contexts. If drafter accepted orchestrator suggestions as authoritative, errors would propagate. Instead, drafter treats orchestrator suggestions as **hypotheses to verify** — checks them against the canonical memory file or actual source files (handbook repo via `gh` API, brite-base via Read tool, sub-skill lock entries via grep). When drafter finds the orchestrator wrong, drafter pushes back with line citations.

This pattern has caught real errors:

- **Q34 Refinement 6:** Orchestrator suggested softening the `## FDA migration` cross-reference mechanism, citing "may be inventing detail." Drafter verified Q9:46 + Q14.2:80 had twice-locked the mechanism. Push-back accepted; design preserved correctly.
- **Q47 Refinement 2:** Orchestrator's gate-count claim for `/flow:add-sub-flow` was 1; drafter verified Q13.4 fires regardless of N, so actual count is 2. Correction applied.
- **Q46 Refinement 2:** Orchestrator caught drafter's hyphenation inconsistency — Q14.2 uses `<!-- FDA-MIGRATION-START -->` (hyphenated) but drafter's Q46 marker draft used space-separated. Real namespace inconsistency caught before lock.

### Session rollover mechanism

When a drafter session's context fills, two tasks before rolloff:

```
   ╭──── Session rollover (when drafter context fills) ───╮
   │                                                      │
   │  Drafter detects context pressure                    │
   │       ↓                                              │
   │  Comprehensive memory commit (everything not in     │
   │  file yet — locks, validation findings, parking lot) │
   │       ↓                                              │
   │  Drafts continuation prompt for fresh session        │
   │  (validation-first framing; "trust the file over     │
   │  orchestrator's recall when they conflict")          │
   │       ↓                                              │
   │  User pastes prompt → fresh Claude bootstraps        │
   │  from memory (read-first; build TaskList; await msg) │
   │       ↓                                              │
   │  Continue at the in-flight Q                         │
   │                                                      │
   ╰──────────────────────────────────────────────────────╯
```

This pattern was developed mid-design when Drafter B's context filled near Q33 evaluation. The user's specific request to "make the prompt validate what you say instead of making everything authoritative truth" became the load-bearing instruction in continuation prompts.

### Q-numbering scheme

Questions are numbered sequentially in the order they were asked, **not** by phase. Phases are an organizational gloss (Phase A = sub-skill internals, Phase B = agents, Phase C = templates, Phase D = quality gates, Phase E = plugin meta, Phase F = content drafts, Phase G = orchestrators + audit, Phase H = incremental ops, Phase I = tracking, Phase J = gstack-cribbed surfaces). Some Qs span phases or amend earlier locks.

---

## 3. The Architecture

### 3a. The 4-Tier FDA Hierarchy

The core domain model. Every UI-bearing project decomposes into:

```
   ╔═════════════════════════════════════════════════════════════╗
   ║      4-TIER FDA HIERARCHY (the domain model)                ║
   ╠═════════════════════════════════════════════════════════════╣
   ║                                                             ║
   ║      project-intent.md           (1× project anchor)        ║
   ║              │                                              ║
   ║              ↓ anchors                                      ║
   ║      master-flow-inventory.md    (canonical FK registry)    ║
   ║              │                                              ║
   ║              ↓ scaffolds                                    ║
   ║                                                             ║
   ║    LINEAR side       ←────────→     REPO side               ║
   ║    ─────────────                    ─────────────           ║
   ║                                                             ║
   ║    Milestone                        journeys/<domain>.md    ║
   ║    (= Domain)                              ↑                ║  TIER 1
   ║         │                            L2 review summary      ║  Domain
   ║         │                                                   ║
   ║    Parent issue                     flows/<dom>/<id>.md     ║
   ║    (= Sub-flow)                            ↑                ║  TIER 2
   ║         │                            L3 review summary      ║  Sub-flow
   ║         │                                                   ║
   ║    5 children per parent            5 discipline artifacts  ║
   ║    [Story][Eng][Design][QA][Docs]   - sandbox harness       ║  TIER 3
   ║         │                           - Figma frame           ║  Disciplines
   ║    blockedBy chain:                 - test plan / runs      ║
   ║    Story → (Design ‖ Eng) →         - customer how-to       ║
   ║      QA → Docs                                              ║
   ║                                                             ║
   ║    ─────────────────────────────────────────────────        ║
   ║                                                             ║
   ║    INDEX.md (one row per sub-flow; auto-regenerated)        ║  TIER 4
   ║                                                             ║  Index
   ╚═════════════════════════════════════════════════════════════╝
```

**Tier 1 — Domain.** Linear milestone (named `<DOMAIN>: <Display name>`, e.g., `TEAM: Team Management`) + per-domain user-journey doc at `docs/product/journeys/<domain>.md`. BriteBase has 28 domains.

**Tier 2 — Sub-flow.** Linear parent issue (named `<DOMAIN-NN>: <Inventory title>`, e.g., `TEAM-04: Edit user role`) + per-sub-flow job-story doc at `docs/product/flows/<domain>/<flow-id>.md`. One per atomic user action. BriteBase has ~397 sub-flows (TEAM has 8, QUO has 43, etc.).

**Tier 3 — Disciplines.** Strict 5 child issues per parent: `[Story]` / `[Eng]` / `[Design]` / `[QA]` / `[Docs]`. Each child has a clear DRI, EPEV-format issue body (Explore / Plan / Execute / Verify), and a discipline-specific artifact. The blockedBy chain enforces ordering: `[Story]` is foundational (sets the contract); `[Design]` and `[Eng]` run parallel under Story; `[QA]` blocks until both complete; `[Docs]` runs last after QA signs off.

**Tier 4 — Index.** `docs/product/flows/INDEX.md` aggregates the cross-reference table — one row per sub-flow showing 5-discipline status with linked artifacts. Auto-regenerated by `flow-regen-index` (Q18); never hand-edited.

### 3b. Cross-Substrate Mapping (Linear ↔ Repo)

The architecture is **bicephalic** — work happens in two substrates, neither subordinate:

| Substrate | Owns                                              | Audience                       |
|-----------|---------------------------------------------------|--------------------------------|
| **Linear** | Workflow state (status, assignee, blockedBy)      | Team-stakeholders, async       |
| **Repo**   | Authoritative content (intent, narrative, specs)  | Engineers, AI agents, future-self |

Stable foreign keys (e.g., `QUO-17`) bind them. Once published, flow IDs **never** change. If a flow splits, append (`QUO-17a`, `QUO-17b`). If deprecated, mark `[DEPRECATED]`, don't delete.

```
   Project anchor                        Project anchor
   ──────────────                        ──────────────
   Linear Project Brief                  docs/product/intent.md
   (CDR-013, Pitch-shaped,               (Q41, anchor-doc shaped,
    ~500-1000 words,                      ~200-500 words,
    audience: stakeholders)               audience: FDA skills + flow authors)

      Q42 /flow:office-hours bridges these — interview pre-fills from
      CDR-013 if shaped (Problem → Problem-we're-solving;
      Outcome → Success-criteria; Scope-Out → Out-of-scope;
      Risks → Constraints), gap-fills the rest by interview.

   Domain milestone                      Per-domain journey doc
   <DOMAIN>: <Display name>              docs/product/journeys/<domain>.md
   (Q22 description template:            (Q26 template; ~5 pages;
    eyebrow link block + per-phase        L2 review summary section;
    job stories + scope decisions)        per-phase narrative)

   Sub-flow parent issue                 Per-sub-flow story doc
   <DOMAIN-NN>: <title>                  docs/product/flows/<domain>/<id>.md
   (Q23 template; EPEV body;             (Q27 template; ~1 page;
    L3 review summary section;            17 front-matter fields;
    children-summary comment)             intent + persona + AC + states)

   5 discipline children                 5 discipline outputs
   [Story]/[Eng]/[Design]/[QA]/[Docs]    - sandbox harness (sandbox/<flow-id>/)
   (Q24 templates per discipline;        - Figma frame (linked from issue)
    EPEV bodies; AC count 3-5;           - test plan + run logs
    blockedBy chain enforced)            - customer how-to
                                           (docs/product/customer-docs/...)

   INDEX.md row per sub-flow             (read from front-matter; regenerated
   ID / Status / 5 emoji disciplines     by flow-regen-index — Q18)
   / Figma link / Live URL
```

### 3c. Plugin Command Surface

```
                  FLOW-ARCHITECTURE PLUGIN (v1)
   ═══════════════════════════════════════════════════════════════
                  ~17 user-invocable slash commands
   ═══════════════════════════════════════════════════════════════


   ORCHESTRATORS (4)              INNER-LOOP UTILITIES (~6)
   ─────────────────              ─────────────────────────
   /flow:start-project            /flow:audit          (Q38)
   /flow:retrofit-project         /flow:office-hours   (Q42)
   /flow:add-domain               /flow:retro          (Q44)
   /flow:add-sub-flow             /flow:session-start  (Q51 cloned)
                                  /flow:review         (Q52 cloned)
   (Q37, Q47)                     /flow:ship           (Q53 cloned)


   L4 PLAN-X SUITE (5)            v1.1+ DEFERRED
   ──────────────────             ──────────────
   /flow:plan-story               /flow:design-consult  (Q45 v1.1)
   /flow:plan-eng                 /flow:journey-refresh (Q19 v1.1)
   /flow:plan-design
   /flow:plan-qa
   /flow:plan-docs
                                  Cloned from compound-engineering's
   (Q43)                          lfg + ce-optimize patterns
                                  (gstack inspiration)
```

### 3d. Sub-Skill Dependency Graph

Sub-skills are **not user-invocable** (per Q7 lock — they're internal `disable-model-invocation: true` skills called by orchestrators). They form a DAG:

```
   FOUNDATION
   ──────────
   _shared/ utilities (Q46 linear-writeback, Q48 four-mode-framework,
                        checkpoint-pattern, artifact-gate-pattern)
   scripts/ bash helpers (Q30.6 — flow-context-load.sh, etc.)
                       │
                       ↓
   flow-preflight (Q12 + Q36 embedded bootstrap)
                       │
                       ↓
   ┌─────────────────────────────────────────────────────────┐
   │  SUB-SKILLS (~9; not user-invocable)                    │
   │                                                         │
   │  flow-inventory-interview      (Q19 — greenfield)       │
   │  flow-inventory-codebase-scan  (Q11 — retrofit)         │
   │  flow-inventory-add            (Q20 — incremental)      │
   │  flow-legacy-cross-reference   (Q14 — retrofit only)    │
   │  flow-linear-scaffold          (Q13)                    │
   │  flow-doc-author               (Q15)                    │
   │  flow-journey-author           (Q16)                    │
   │  flow-sandbox-scaffold         (Q17)                    │
   │  flow-regen-index              (Q18)                    │
   └─────────────────────────────────────────────────────────┘
                       │
                       ↓
   AGENTS (Q21 — ~12 named)
   ────────────────────────
   plan-ceo-reviewer       \
   plan-design-reviewer    │  L1 reviewers (project intent)
   plan-eng-reviewer       │  L2 reviewers (per-domain journey)
   plan-devex-reviewer     /  L3 reviewers (per-sub-flow)
   plan-{story,eng,design,qa,docs}-reviewer  (L4 — per-discipline child)
   story-doc-author
   journey-doc-author
   fidelity-reviewer       (per-issue scaffold review; Q13.3)
                       │
                       ↓
   ORCHESTRATORS (4)
   ─────────────────
   /flow:start-project    (Q37 — 8 phases / 4 gates)
   /flow:retrofit-project (Q37 — 9 phases / 5 gates)
   /flow:add-domain       (Q47 — 6 phases / 2 gates)
   /flow:add-sub-flow     (Q47 — 5 phases / 2 gates)
                       │
                       ↓
   UTILITIES + CLONED COMMANDS
   ───────────────────────────
   /flow:audit            (Q38)
   /flow:office-hours     (Q42)
   /flow:plan-{discipline}(Q43)
   /flow:retro            (Q44)
   /flow:session-start    (Q51 cloned)
   /flow:review           (Q52 cloned)
   /flow:ship             (Q53 cloned)
```

### 3e. Greenfield Orchestrator Phase Flow

`/flow:start-project` runs **8 phases / 4 user-confirmation gates**, with **hybrid control flow** (per Q37 lock):

```
  /flow:start-project (greenfield) — 8 phases / 4 gates
  ═══════════════════════════════════════════════════════════════════

   ┌─ Phase 1 ─┐ G1 ┌─ Phase 2 ─┐ G2 ┌─ Phase 3 ─┐ G3 ┌─ Phase 4 ─┐
   │ preflight │───►│  office-  │───►│ inventory │───►│  linear-  │
   │ bootstrap │    │   hours   │    │ interview │    │  scaffold │
   │   (Q12)   │    │   (Q42)   │    │   (Q19)   │    │   (Q13)   │
   └───────────┘    └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
                          │                │                │
                          ↓ L1 review      ↓ L2 review      ↓ L3 review
                          → intent.md      → journey doc    → parent issue
                          (CEO+Des+        (CEO+Des per     (5 disciplines
                           Eng+DX           domain)          per sub-flow)
                           parallel)
                          [phase produces  [phase produces   [G4 fires here:
                          intent.md +       inventory +       per-domain
                          ## L1 review      L2 stash for      pre-scaffold
                          summary section]  journey author]   batch preview]


   ┌─ Phase 4 ─┐ G4 ┌─ Phase 5 ─┐    ┌─ Phase 6 ─┐    ┌─ Phase 7 ─┐
   │  linear-  │───►│  doc-     │───►│  journey- │───►│  regen-   │
   │  scaffold │    │  author   │    │   author  │    │   index   │
   │   (Q13)   │    │   (Q15)   │    │   (Q16)   │    │   (Q18)   │
   └───────────┘    └───────────┘    └───────────┘    └─────┬─────┘
   per-domain       globally         globally               │
   inner loop       batched          batched                │
   (preserves       (Q15.2 internal  (Q16.2 internal        ↓
   Q13.5 atomic     parallelism      parallelism      ┌─ Phase 8 ─┐
   recovery)        applies broadly) applies broadly) │ complete  │
                                                      │           │
   ╔═══════════════════════════════════════════╗      └───────────┘
   ║ HYBRID CONTROL FLOW (Q37 user lock):      ║      status:
   ║ - Phase 4 per-domain inner loop           ║      completed
   ║   (preserves G4 + Q13.5 atomic recovery)  ║      written to
   ║ - Phases 5+6 globally batched             ║      breadcrumb
   ║   (activates Q15.2 + Q16.2 parallelism)   ║
   ║ - Wall: ~22-70 min Brand Hub-shape        ║
   ╚═══════════════════════════════════════════╝
```

**The 4 user gates:**

- **G1 (1→2):** bootstrap completed; `.flow/config.json` written
- **G2 (2→3):** PROJECT-INTENT.md content review (post-office-hours, L1-vetted)
- **G3 (3→4):** `master-flow-inventory.md` content review (post-inventory-interview, L2-vetted per domain)
- **G4 (3→4):** pre-scaffold batch preview covering ALL domains (consolidates Q13.4's per-skill gate; NOT 28 separate gates)

Phases 5/6/7 run without additional orchestrator gates — Q15.6/Q16.6/Q18.8 lock 0 sync gates each.

### 3f. Retrofit Orchestrator Phase Flow

`/flow:retrofit-project` adds one phase (legacy-cross-reference) and one gate (cross-reference review). Otherwise mirrors greenfield:

```
  /flow:retrofit-project — 9 phases / 5 gates
  ═══════════════════════════════════════════════════════════════════

   Phase 1: preflight + bootstrap
        ↓ G1
   Phase 2: office-hours (conditional — only if intent.md absent)
        ↓ G2
   Phase 3: legacy-cross-reference (Q14 — adds ## FDA migration
                                          section to legacy milestones
                                          via FDA-MIGRATION-* HTML markers)
        ↓ G3 (cross-reference review document gate per Q14.6)
   Phase 4: flow-inventory-codebase-scan (Q11 — scans existing code
                                          for flow signal)
        ↓ G4
   Phase 5: linear-scaffold (per-domain inner loop)
        ↓ G5 (pre-scaffold batch preview)
   Phase 6: doc-author (globally batched)
   Phase 7: journey-author (globally batched)
   Phase 8: regen-index
   Phase 9: complete

  Greenfield SKIPS phase 3 (no legacy to cross-reference).
  Retrofit cutover: existing in-flight legacy work continues in
  Phase Pattern shape; new work after retrofit goes in FDA shape.
  Cutover timestamp recorded in .flow-phase-state.json.
```

### 3g. Multi-Perspective L-Review Pattern

Per Q54 (meta-Q): every artifact gets multi-perspective AI review at appropriate scope. Reviews fire in parallel within scope, populate target docs, never block (informational + auditable).

```
   L-REVIEW SCOPING (Q54 lock)
   ═══════════════════════════════════════════════════════════

   L1 — Project scope
   ───────────────────
   Reviewers: CEO + Design + Eng + Developer-experience (4 agents parallel)
   Target:    docs/product/intent.md  ## L1 review summary section
   Fires:     Q42 /flow:office-hours phase 2 (greenfield/retrofit)
   Wall:      ~30-60s parallel

   L2 — Domain scope
   ──────────────────
   Reviewers: CEO + Design (2 agents parallel)
   Target:    docs/product/journeys/<domain>.md  ## L2 review summary
   Fires:     Q37 phase 3 inventory (one per domain)
   Stash:     orchestrator in-memory state.l2_review_<domain>;
              hand-off to flow-journey-author in phase 6
   Wall:      ~30-60s parallel × N domains

   L3 — Sub-flow scope
   ───────────────────
   Reviewers: 5 disciplines (Story + Eng + Design + QA + Docs)
   Target:    Linear parent issue body  ## L3 review summary section
   Fires:     Q13 linear-scaffold phase 4 (one per sub-flow)
   Wall:      ~30-60s parallel × ~397 sub-flows
              (with batch parallelism, ~22 min wall total Brand Hub-shape)

   L4 — Discipline-child scope
   ────────────────────────────
   Reviewer:  Single discipline reviewer (per-discipline plan-X-reviewer)
   Target:    JIT during /flow:session-start step 5 (NOT orchestrator-driven)
   Fires:     On-demand when /flow:plan-{discipline} runs


   FIRE-AND-WRITE FLOW
   ═══════════════════════════════════════════════════════════
   Reviews fire on draft content
            ↓
   Each agent returns {headline, perspective_specific_concerns}
            ↓
   Headlines populate target doc's review summary section
            ↓
   Concerns persist to docs/plans/l1-concerns-<timestamp>.md
   (transient run-artifact; v1.1 candidate to route via Q46
    Linear writeback per parking lot)
            ↓
   User reviews concerns before next gate (G2/G3/G4 etc.)
   Gate is informational-only; user can advance even with concerns.
```

### 3h. Quality Gate Stack

Per Q29 lock + Q29 amendment 2 (LOCKED 2026-05-26 per BC-10729) — **36 gates** across 3 categories:

```
   QUALITY GATE STACK (Q29 + amendment 2) — 36 gates total
   ═══════════════════════════════════════════════════════════

   ┌────────────────────────────────────────────────────────────┐
   │  PHASE-TRANSITION GATES (8)                                │
   │  Block downstream phase until artifact-existence verified  │
   │                                                            │
   │  intent-exists, inventory-exists, scaffold-complete,       │
   │  story-docs-complete, journey-docs-complete,               │
   │  index-complete, retrofit-cross-reference-complete (R),    │
   │  bootstrap-complete                                        │
   │                                                            │
   │  Hard (block) gates fire at phase boundaries.              │
   └────────────────────────────────────────────────────────────┘

   ┌────────────────────────────────────────────────────────────┐
   │  PER-FLOW DISCIPLINE-CHILD GATES (~22)                     │
   │  Vary per discipline:                                      │
   │   Story = 5 (frontmatter; AC count 3-5; sandbox URL;       │
   │             intent cross-link; persona reference)          │
   │   Eng   = 4 (sandbox harness exists; tests pass;           │
   │             type-check pass; CDR compliance)               │
   │   Design= 3 (Figma frame linked; design-system audit;      │
   │             accessibility check)                           │
   │   QA    = 5 (qa_status=signed-off; test plan; runs logged; │
   │             regressions checked; sign-off comment)         │
   │   Docs  = 5 (customer how-to drafted; voice check;         │
   │             screenshots; reviewed; published trigger)      │
   │                                                            │
   │  Each gate runs against a single sub-flow's discipline     │
   │  child. Hard vs soft per Q29.4 classification.             │
   └────────────────────────────────────────────────────────────┘

   ┌────────────────────────────────────────────────────────────┐
   │  CROSS-CUTTING CONSISTENCY GATES (6 post-Q29 amendment 2)  │
   │  Detect inter-substrate drift                              │
   │  (Canonical names per Q29.3 + artifact-gate-pattern.md)    │
   │                                                            │
   │  inventory-story-doc-id-match (every story_doc flow_id     │
   │    appears as row in master-flow-inventory.md)             │
   │  index-story-doc-status-match (INDEX.md Status col matches │
   │    story-doc front-matter status)                          │
   │  linear-children-match (story-doc children.* BCs match     │
   │    actual Linear parentId chain)                           │
   │  parent-l3-summary-populated (Linear parent body carries   │
   │    `## L3 review summary` with 5 discipline headlines)     │
   │  milestone-subflows-table-match (Q22 milestone Sub-flows   │
   │    table matches actual children of that milestone)        │
   │  cross-domain-deps-bidirectional (Q27 amendment 1 mod 4    │
   │    ↔ Linear blockedBy 1:1 mirror; BC-10729)                │
   └────────────────────────────────────────────────────────────┘

   RUNNER: /flow:audit (Q38)
   ─────────────────────────
   Three-phase execution:
   - Phase A: bash scripts/verify-docs.sh (mechanical layer:
              build / lint / test / links / orphan flow IDs)
   - Phase B: deterministic filesystem gates (Q29.2)
   - Phase C: Linear MCP gates (Q29.3 + Q29.2 [Eng]/[Design]/[Docs])

   If Phase A fails → Phase B/C marked skipped.
   Output: stdout markdown (default) + --json flag.
   Auto-invoked by: /flow:ship + /flow:plan-{discipline} (NOT orchestrators).
   Override flow: AskUserQuestion (Fix/Override/Halt) on hard-gate fail.
```

### 3i. State Substrates

Where state lives:

```
   STATE SUBSTRATES
   ═══════════════════════════════════════════════════════════════

   PER-PROJECT (.flow/)
   ────────────────────
   .flow/config.json              Q12 + Q36 — project setup
                                  Fields: linear_project_id, name,
                                  team_key, fda_first_setup_at,
                                  fda_plugin_version

   .flow/phase-state.json         Q31 — orchestrator breadcrumb
   (per-run resume support)       Fields: version, mode, status,
                                  run_started_at, last_updated,
                                  current_phase, completed_phases,
                                  in_flight_artifacts, domains[],
                                  overrides[], config_snapshot

                                  Q31 amendment 1: office_hours_state
                                  (Q42 sub-decision 6) — Mission
                                  /Target users/Problem/etc. answers
                                  + linear_brief_snapshot + l1_review_*

                                  Q31 amendment 2: linear_writeback_state
                                  (Q46 sub-decision 7) — comment_ids[]
                                  + written_pairs[] + warnings[]


   REPO docs/product/
   ──────────────────
   intent.md                      Q41 template — project anchor
                                  (~200-500 words; 7 sections + L1)

   master-flow-inventory.md       Canonical FK registry
                                  (28 domains for BriteBase)

   journeys/<domain>.md           Q26 template — per-domain narrative
                                  (28 files; L2 review summary section)

   flows/<domain>/<flow-id>.md    Q27 template — per-sub-flow story doc
                                  (~397 files; 17 front-matter fields)

   flows/INDEX.md                 Q25 schema — auto-regenerated by Q18

   templates/                     Local incubation; Q22-Q28 + Q41
                                  promoted to about-handbook per Q2

   ../plans/.flow-phase-state.json  Lives at docs/plans/ (NOT .flow/!)
                                    per Q31.4 — orchestrator breadcrumb
                                    is a transient run-artifact


   LINEAR
   ──────
   Milestones                     Domains (e.g., TEAM, QUO)
   Parent issues                  Sub-flows (TEAM-04, QUO-17, etc.)
   5N children                    Discipline children per parent
   Labels                         domain:* / type:* / discipline:* /
                                  status:*


   CROSS-ORG (Brite-Nites/)
   ────────────────────────
   handbook/decisions/CDR-023     Q33 — Flow-Driven Architecture CDR
   handbook/decisions/CDR-014     Q35 — amended (Phase Pattern scope)
   handbook/how-we-work/          Q34 — operating-standards FDA page
     operating-standards/         Q35 — milestones.md companion amendment
       flow-driven-architecture.md
       milestones.md (amended)

   about-handbook/                Q22-Q28 + Q41 templates promoted here
     style-guide/templates/       (11 template files total)
```

---

## 4. Locked Decisions Summary

By topic cluster (not strict phase ordering — phases are organizational gloss):

### Foundation + Plugin Meta (Q1-Q12, Q30-Q32, Q36)

| Q   | Topic                                  | Lock summary                                                           |
|-----|----------------------------------------|------------------------------------------------------------------------|
| Q1  | Plugin name + repo                     | `flow-architecture` plugin in `Brite-Nites/brite-claude-plugins`       |
| Q2  | Template promotion path                | Local incubation in BriteBase → promoted to `about-handbook`           |
| Q7  | Orchestrator-as-skill pattern          | Cribbed from compound-engineering's lfg + ce-optimize                  |
| Q8  | v1 acceptance gate                     | First successful Brand Hub retrofit                                    |
| Q9  | CDR-023 migration policy               | Additive-only; cross-reference appendices on legacy milestones         |
| Q10 | User-confirmation gate budget          | 5 retrofit / 4 greenfield (silent on incremental-add)                  |
| Q12 | flow-preflight responsibilities        | 5 responsibilities; 4 modes (greenfield/retrofit/resume/incremental)   |
| Q30 | Plugin manifest + directory structure  | 17 commands / ~9 sub-skills / ~12 agents / 6 _shared utils / 4 scripts |
| Q31 | Resume breadcrumb schema               | `.flow-phase-state.json` at `docs/plans/`; 11 fields; 2 amendments     |
| Q32 | MCP and dependency requirements        | Linear MCP via workflows plugin; sequential-thinking MCP; jq + python3 |
| Q36 | Plugin bootstrap shape                 | Per-project first-run inside flow-preflight; per-org parked v1.1       |

### Sub-Skills (Q11, Q13-Q20)

| Q   | Topic                                | Lock summary                                                               |
|-----|--------------------------------------|----------------------------------------------------------------------------|
| Q11 | flow-inventory-codebase-scan         | Retrofit-only; 5 phases; intent.md as priority filter                      |
| Q13 | flow-linear-scaffold                 | 2+7N writes per domain; per-sub-flow execution unit; Q13.5 atomic recovery |
| Q14 | flow-legacy-cross-reference          | Retrofit-only; HTML markers `<!-- FDA-MIGRATION-START -->`                 |
| Q15 | flow-doc-author                      | Per-sub-flow parallel agents within invocation; ~30-60s wall              |
| Q16 | flow-journey-author                  | Per-domain parallel within invocation; reads L2 stash from orchestrator   |
| Q17 | flow-sandbox-scaffold                | Per-flow sandbox harness creation                                          |
| Q18 | flow-regen-index                     | Auto-regenerated INDEX.md from story-doc front-matter                      |
| Q19 | flow-inventory-interview             | Greenfield; 5 phases skip Phase 3 (no codebase scan)                       |
| Q20 | flow-inventory-add                   | Incremental; 2 modes (sub-flow-add + domain-add); state.inventory_changed  |

### Agents (Q21)

12 named agents per Option C expanded:
- L1-L3 reviewers: `plan-ceo-reviewer`, `plan-design-reviewer`, `plan-eng-reviewer`, `plan-devex-reviewer`
- L4 plan-X reviewers: `plan-{story,eng,design,qa,docs}-reviewer` (5 agents)
- Authors: `story-doc-author`, `journey-doc-author`
- Other: `fidelity-reviewer` (per-issue scaffold review)

### Templates (Q22-Q28 + Q41)

| Q   | Template                          | Output path                                                  |
|-----|-----------------------------------|--------------------------------------------------------------|
| Q22 | Domain-as-milestone description   | Linear milestone description body (eyebrow link block)       |
| Q23 | Sub-flow parent issue             | Linear parent issue body (EPEV; L3 review summary section)   |
| Q24 | 5 discipline-child issue templates | `[Story]/[Eng]/[Design]/[QA]/[Docs]` issue bodies           |
| Q25 | Flow INDEX.md schema              | `docs/product/flows/INDEX.md` 11-column schema               |
| Q26 | Per-domain user journey doc       | `docs/product/journeys/<domain>.md` (~5 pages, 9 sections)   |
| Q27 | Job story doc                     | `docs/product/flows/<domain>/<id>.md` (~1 page, 17 FM fields)|
| Q28 | Customer how-to                   | `docs/product/customer-docs/<domain>/<id>.md`                |
| Q41 | PROJECT-INTENT.md                 | `docs/product/intent.md` (~200-500 words; 7 sections + L1)   |

### Quality Gates + Audit (Q29, Q38)

| Q   | Topic                            | Lock summary                                                             |
|-----|----------------------------------|--------------------------------------------------------------------------|
| Q29 | Quality-gate stack enumeration   | 36 gates post-Q29 amendment 2 (8 phase-transition + 22 per-flow + 6 cross-cutting incl. `cross-domain-deps-bidirectional`); 3-section report; Override flow per Q29.5 |
| Q38 | /flow:audit shape                | 7 sub-decisions; --gate filter; inline batched list_issues; auto-invoked from /flow:ship + /flow:plan-X; stdout-only by default |

### Content Drafts (Q33-Q35)

| Q   | Drafted                                        | Target path                                                  |
|-----|------------------------------------------------|--------------------------------------------------------------|
| Q33 | CDR-023 — Flow-Driven Architecture CDR         | `handbook/decisions/CDR-023-flow-driven-architecture.md`     |
| Q34 | Operating-standards FDA page                   | `handbook/how-we-work/operating-standards/flow-driven-architecture.md` |
| Q35 | CDR-014 amendment (in-place edits + companion) | `handbook/decisions/CDR-014-milestone-standards.md` (+ milestones.md companion) |

### Orchestrators (Q37, Q47)

| Q   | Topic                            | Lock summary                                                                  |
|-----|----------------------------------|-------------------------------------------------------------------------------|
| Q37 | Greenfield orchestrator          | 8 phases / 4 gates; hybrid control flow (phase 4 per-domain, 5+6 batched)     |
| Q47 | /flow:add split                  | Two distinct commands; per-consumer; 5/6 phases for sub-flow/domain         |

### Other (Q42-Q44, Q46, Q47, Q48, Q50-Q53, Q54)

| Q   | Topic                                | Lock summary                                                                 |
|-----|--------------------------------------|------------------------------------------------------------------------------|
| Q42 | /flow:office-hours skill             | Hybrid CDR-013 input (4 pre-fill pairs); sequential interview; parallel L1; Q31 amend 1 |
| Q43 | /flow:plan-{discipline} suite        | 5 distinct commands; lightweight 4-phase ~30-90s; L4 single-perspective; Q24 amend 1 |
| Q44 | /flow:retro skill                    | Manual-only trigger; single-domain scope; comment-surface; AI-only synthesis; gstack 5 verbatim section headers |
| Q46 | Linear writeback adaptation          | Post-scaffold writes only; FDA-WRITEBACK-<type>-START/END markers; Q31 amend 2 |
| Q47 | /flow:add split (add-domain/sub-flow)| Two distinct commands; mode-classifier hard-require; Q47/Q20 boundary; 2 gates per command; journey-staleness warning |
| Q48 | Four-mode scope-review framework     | gstack-faithful SCOPE_EXPANSION/SELECTIVE_EXPANSION/HOLD_SCOPE/SCOPE_REDUCTION; Q21 amend 1 |
| Q50 | Clone-and-swap scope from workflows  | workflows v3.29.4 verified; CLONE 3 / DIRECT REUSE 6 / TRANSITIVE REUSE (3 skills + 15 agents per amend 2); Q50 amend 1 + amend 2 |
| Q51 | /flow:session-start (cloned)         | workflows v3.29.4 cloned; 9-step structure; Step 6 L4 plan-X dispatch (NOT Step 5 — caught Q50 amend 1) |
| Q52 | /flow:review (cloned)                | Lighter swap (3 of 9 steps); Step 1 PASSIVE-context augment + Step 4 PLAN-CONTEXT augment + Step 8 ship-link; independent of /flow:audit |
| Q53 | /flow:ship (cloned)                  | Heaviest swap (7 of 9 steps); convergence — Q38 audit pre-flight + Q46 ship-summary + Q43 plan-X verify + Q44 retro soft-notification; caught Q50 amend 2 |
| Q54 | Multi-perspective L-review meta      | L1/L2/L3/L4 scoping; informational-only; populates target review-summary sections |

### Phase I + Deferral Tracking (Q40, Q45, Q49, Q55) — D session locks

| Q   | Topic                                | Lock summary                                                              |
|-----|--------------------------------------|---------------------------------------------------------------------------|
| Q40 | Production readiness checklist       | 7 sub-decisions; static doc at `plugins/flow-architecture/docs/production-readiness.md`; 12 criteria / 4 categories; Q8 "successful" gap-fill; no test surface for v1; dual-event triage distinction; v1.0 release sequence (9 steps) |
| Q45 | `/flow:design-consult` v1.1 deferral | TRACKING-ONLY. Confirms Q1 deferral. 3 promotion criteria; cross-refs to Q1 / Q42 sub-decision 7 / Q21 plan-design-reviewer / parking lot #9 |
| Q49 | Canonical Brite design-system repo   | TRACKING-ONLY. v2+ scope; elevates parking lot #9. 3 pre-conditions (Brand Hub retrofit succeeds; Brand Hub design-system stabilizes; second product stabilizes) + 2 promotion criteria |
| Q55 | Plugin CLAUDE.md content design      | 7 sub-decisions; 13 H2 sections; both maintainer + LLM-context audience; ~15-25K bytes target; 5 cross-cutting documentation requirements + Q30.5 base scope + 6 misc per-Q callbacks; methodology preservation included |

### Amendments (16 locked across C+D sessions; full audit trails in memory)

| Amendment       | Origin Q | Target Q | Summary                                                                  |
|-----------------|----------|----------|--------------------------------------------------------------------------|
| Q31 amend 1     | Q42      | Q31      | office_hours_state schema slot                                           |
| Q31 amend 2     | Q46      | Q31      | linear_writeback_state schema slot (comment_ids[] + written_pairs[] + warnings[]) |
| Q24 amend 1     | Q43      | Q24      | Plan-section Q46 markers in 5 discipline-child templates                  |
| Q21 amend 1     | Q48      | Q21      | mode field + scope-axis fields on 7 of 12 reviewer agents                |
| Q50 amend 1     | Q51      | Q50      | "8 steps" → "9 steps"; Step 5 → Step 6 swap location                     |
| Q50 amend 2     | Q53      | Q50      | TRANSITIVE REUSE category for 3 skills + 15 agents                        |
| Q33 amend 1     | Step 2.A pre-flight | Q33 | CDR-022 → CDR-023 renumber (handbook collision with `CDR-022-asset-taxonomy.md`); canonical full audit-trail rationale |
| Q34 amend 1     | Step 2.A pre-flight | Q34 | CDR-022 → CDR-023 cross-reference renumber (companion to Q33 amend 1)    |
| Q35 amend 1     | Step 2.A pre-flight | Q35 | CDR-022 → CDR-023 cross-reference renumber in CDR-014 amendment + companion milestones.md (companion to Q33 amend 1) |
| Q2 amend 1      | Step 2.B pre-flight | Q2  | about-handbook subdir path correction; canonical full audit-trail rationale |
| Q22 amend 1     | Step 2.B pre-flight | Q22 | "Lives at" path correction (companion to Q2 amend 1)                     |
| Q28 amend 1     | Step 2.B pre-flight | Q28 | "Lives at" path correction (companion to Q2 amend 1)                     |
| Q41 amend 1     | Step 2.B pre-flight | Q41 | "Lives at" path correction + CDR-013 templates path (companion to Q2 amend 1) |
| Q33 amend 2     | Step 2.B pre-flight | Q33 | sub-decision 3 path + sub-decision 6 URL correction (cascading to PR #513 fix-commit) |
| Q34 amend 2     | Step 2.B pre-flight | Q34 | sub-decision 5 cross-reference path correction (companion to Q2 amend 1) |
| Q49 amend 1     | Step 2.B pre-flight | Q49 | `Brite-Nites/brite-design-system` repo already exists (created 2026-02-03); v2+ framing partially obsolete; status remains v2+ tracking (pre-conditions still gate) |

---

## 5. Pending Decisions (D session-end 2026-05-08 — ALL CLOSED)

**0 Qs remaining.** Design phase officially closed 2026-05-08 with all 54 active Q-numbers locked.

**Locked-in-D-session:** Q55 (plugin CLAUDE.md content) → Q40 (production readiness checklist) → Q45 (`/flow:design-consult` v1.1 deferral, tracking-only) → Q49 (canonical Brite design-system v2+ tracking, tracking-only).

**Locked-in-C-session (preserved for handoff history):** Q41 (intent.md template) → Q42 (office-hours) → Q43 (plan-X suite + Q24 amend 1) → Q44 (retro) → Q46 (Linear writeback + Q31 amend 2) → Q47 (add-split) → Q48 (four-mode framework + Q21 amend 1) → Q50 (clone-and-swap scope + Q50 amend 1 [via Q51] + Q50 amend 2 [via Q53]) → Q51 (session-start) → Q52 (review) → Q53 (ship).

Implementation phase begins next. Phase 1 close housekeeping (this artifact regen + parking-lot triage) in progress; Phase 2 PR landing (handbook + about-handbook) next.

---

## 6. Methodology — Validation-First Multi-Session Pattern

Beyond the architecture itself, this design effort surfaced a methodology worth documenting. Three patterns proved load-bearing:

### Pattern 1: Auto-memory file as canonical store

The auto-memory file (`~/.claude/.../memory/project_fda_plugin_interview.md`) was treated as **the single source of truth** across all sessions. Every Q-lock, every parking-lot item, every validated convention persisted to this file. Sessions read it on bootstrap; sessions wrote to it after each lock.

This worked because:

- **File survives compaction.** Ephemeral conversation context vanishes on session rolloff; file persists.
- **Read-first discipline.** Continuation prompts hard-instructed fresh sessions to read the file before drafting anything.
- **Validation-first reads.** When orchestrator and drafter disagreed on what was locked, drafter checked the file and pushed back with line citations.

The file currently lives in a single non-git-tracked location. Mitigation: snapshot to brite-base/docs/plans/ (this directory) periodically. Eventual migration: archive at `plugins/flow-architecture/docs/design-rationale.md` post-v1.0.

### Pattern 2: Three-role separation (user / orchestrator / drafter)

Not a Claude Code feature — emergent from how the user organized the work. The user ran two parallel Claude sessions:

- **Orchestrator session (me):** evaluator. Saw drafter's output through user's clipboard; drafted refinements; recommended replies.
- **Drafter session (B → C):** primary author. Did the validation against memory + actual files; pushed back when orchestrator was wrong; wrote locks.

Why this worked:

- **Orchestrator doesn't directly write the canonical store.** Reduces noise; orchestrator can be wrong without polluting truth.
- **Drafter has the highest stake in fidelity.** Drafter writes the lock; drafter caught orchestrator errors via grep before they landed.
- **User is the arbiter.** When drafter and orchestrator disagree, user's "lock this" signal resolves.

### Pattern 3: Validation-first error correction

The most counterintuitive pattern. When orchestrator suggested a refinement, drafter did NOT take it as authoritative. Drafter:

1. Verified each cited lock against memory + actual files
2. Pushed back with line citations when orchestrator was wrong
3. Applied refinements only when verified, with explicit "verified Q<N> at memory:<line>" annotations in audit trails

This caught real errors:

- **Q34 R6** (orchestrator wrong): "may be inventing detail" → drafter found Q9:46 + Q14.2:80; mechanism twice-locked; push-back accepted
- **Q47 R2** (orchestrator partly wrong): gate-count claim 1 → drafter found Q13.4 fires regardless of N; corrected to 2
- **Q46 R2** (orchestrator caught real drift): drafter's marker format space-separated vs Q14.2's hyphenated → orchestrator caught; corrected before lock

Counter-direction: drafter wasn't always right either. Orchestrator caught drafter inflating claims (Q37 R1 "clarification not structural" reframed as real architectural choice; Q38 R3 "DRY of Q18.3" overstated since pattern is inline not extracted utility). Validation-first goes both ways.

**D-session extension (2026-05-08): bidirectional + transitive.** Validation-first applies not only between drafter ↔ orchestrator but also to **drafter → drafter's-own-prior-work** (re-verification at downstream lock) and **drafter → inherited-error-from-prior-handoff** (catching errors propagated through artifact chains). Three D-session catches demonstrate the pattern:

- **Q51 caught Q50 sub-decision 5 errors via re-verification at downstream lock** (parking-lot-#39 extension): "8 steps" → 9 steps; "Step 5 swap" → Step 6 swap. Q50 amend 1 written.
- **Q53 caught Q50 sub-decision 2 TRANSITIVE REUSE classification gap** at downstream lock — same parking-lot-#39 extension methodology, second time at downstream consumer drafting. Q50 amend 2 written. Both catches confirm: heavily-cited foundation locks accumulate errors that surface during downstream consumer drafting.
- **Q40 R5 caught C handoff arithmetic error inherited into orchestrator's R5 framing**: "5 amendments" → 6 amendments. Drafter D `grep -c` verified 6 amendment lock-entry headers exist in memory; explicit list immediately following the intro count had 6 entries. C handoff text corrected at memory:1884 with audit-trail note preserving the catch.
- **Step 2.A pre-flight caught CDR-022 namespace collision** (FIRST execution-phase application): handbook already had `CDR-022-asset-taxonomy.md` (Accepted 2026-05-06, drake-mooneyham, same-day-lock as Q33). Drafter D `gh api repos/Brite-Nites/handbook/contents/decisions` enumeration surfaced collision before PR composition; resulted in Q33/Q34/Q35 amendments 1 renumbering FDA CDR to CDR-023 + 24 cross-reference updates throughout memory + parking lot #39 namespace-extension lesson.
- **Step 2.B pre-flight caught about-handbook subdirectory + brite-design-system existence** (SECOND execution-phase application): `gh api repos/Brite-Nites/about-handbook` returned 404; subsequent `gh api orgs/Brite-Nites/repos --paginate` confirmed about-handbook is a subdirectory of handbook (not a separate org-level repo) AND surfaced `Brite-Nites/brite-design-system` already exists (created 2026-02-03; invalidates Q49's v2+ "future canonical" framing). Resulted in 7 new amendments (Q2 amend 1 + Q22 amend 1 + Q28 amend 1 + Q41 amend 1 + Q33 amend 2 + Q34 amend 2 + Q49 amend 1) + parking-lot #33 inline correction + parking-lot #39 second extension lesson + bulk path/URL renames in memory + cascading PR #513 fix-commit for in-flight URLs.

**Methodology lesson reinforced:** validation-first is bidirectional + transitive. **Inherited errors propagate through refinement chains until someone re-counts at the source artifact.** Re-verification AT EACH consumer lock is the discipline; this applies to internal-process artifacts (the memory file itself), not just external cribbing. **Parking-lot-#39 extension (D session 2026-05-08): pre-flight verification at draft time MUST include namespace-collision checks against authoritative org artifacts** (CDR numbers, template paths, file paths in shared repos) — same-day or parallel-session collisions are real risk for high-frequency artifact namespaces. Codified in Q55 plugin CLAUDE.md methodology section per refinement 2 user lock for v1.1+ Q-locks.

### Pattern 4: AskUserQuestion for genuine architectural choices

Refinements that were factual ("verify Q14.2 marker format") got drafter-resolved. Refinements that were architectural choices ("per-domain inner loop vs global batching vs hybrid?") got escalated to user via AskUserQuestion. This kept user as decision-maker for genuinely-load-bearing choices without burdening them with every minor refinement.

---

## 7. The Plan Forward — 6 Phases

Captured in the orchestrator-side TaskList (#45-#59):

```
   ╔═══════════════════════════════════════════════════════════════╗
   ║  PHASE 1 — Close FDA design phase            (in progress)   ║
   ║  ─────────────────────────────────────                       ║
   ║  Lock remaining ~11 Qs: Q43, Q44, Q45, Q46 (in flight),      ║
   ║  Q48, Q40, Q49, Q50-Q53, Q55                                 ║
   ║  Triage parking lot at design close                          ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║  PHASE 2 — Land org-level PRs    (parallel-able with Phase 1)║
   ║  ─────────────────────────────────────                       ║
   ║  handbook PR: CDR-023 + CDR-014 amend + ops-standards FDA    ║
   ║  about-handbook PR: 11 templates                             ║
   ║                                                               ║
   ║  These can land NOW — drafts complete in memory.             ║
   ║  Doesn't block continuing design work.                       ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║  PHASE 3 — Linear scoping  (COMPLETE 2026-05-10)             ║
   ║  ─────────────────────────────────────                       ║
   ║  Per Q1 amendment 1 (LOCKED 2026-05-10): Phase Pattern       ║
   ║  applies — plugin infra is non-UI-bearing per Q1 scope test. ║
   ║  Single milestone "Flow-Driven Architecture Plugin v1.0"     ║
   ║  under existing Brite Plugin Marketplace project; 21 flat    ║
   ║  capability-grouped issues (3 parents + 18 standalones)      ║
   ║  matching Cadence Plugin precedent (BC-5757/BC-5758 era).    ║
   ║                                                               ║
   ║  Real FDA dogfood deferred to Phase 5 Brand Hub retrofit     ║
   ║  (Q8 v1.0 acceptance gate / BC-6998) where work IS UI-       ║
   ║  bearing per Q1 scope test.                                  ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║  PHASE 4 — Plugin implementation (bottom-up)                 ║
   ║  ─────────────────────────────────────                       ║
   ║  4a: Foundation (_shared utils + scripts + flow-preflight)   ║
   ║  4b: Sub-skills + agents (Q11-Q21)                           ║
   ║  4c: Orchestrators (Q37, Q47)                                ║
   ║  4d: Utility commands (Q38, Q42, Q43, Q44, Q53)              ║
   ║  4e: Clone-and-swap from workflows (Q50-Q53)                 ║
   ║  4f: Plugin CLAUDE.md (Q55) + design-rationale prep          ║
   ║                                                               ║
   ║  Implement in vertical slices — get one orchestrator end-to- ║
   ║  end working before adding depth.                            ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║  PHASE 5 — Brand Hub dogfood (Q8 v1 acceptance gate)         ║
   ║  ─────────────────────────────────────                       ║
   ║  Run /flow:retrofit-project on Brand Hub                     ║
   ║  Iterate on dogfood findings until first clean retrofit      ║
   ║  Promote parking-lot items revealed by dogfood               ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║  PHASE 6 — Release v1.0                                      ║
   ║  ─────────────────────────────────────                       ║
   ║  Tag plugin v1.0                                             ║
   ║  Bump CDR-023 status: Proposed → Accepted                    ║
   ║  Archive memory file as plugin design-rationale.md           ║
   ║  Re-triage parking lot for v1.1 backlog                      ║
   ╚═══════════════════════════════════════════════════════════════╝
```

**Estimated timeline (rough):**

- Phase 1: 2-3 more sessions at current pace
- Phase 2: 1-2 days once started (~3 PRs, all standalone)
- Phase 3: 1-2 days (~50 Linear issues to scope manually)
- Phase 4: 2-3 weeks of focused implementation
- Phase 5: 1-2 weeks of dogfood + iteration
- Phase 6: 1 day

Total to v1.0: ~6-8 weeks if paced steadily.

---

## 8. Migration Map

Where each design artifact eventually lives. The memory file is **temporary scaffolding** — nothing in it stays there long-term.

```
   MIGRATION MAP — Design → Production homes
   ═══════════════════════════════════════════════════════════════════

   MEMORY FILE                  CANONICAL HOME (eventual)
   ────────────                 ─────────────────────────

   Q1, Q7, Q8, Q9               → CDR-023 in handbook/decisions/
   Q22-Q28 templates            → handbook/about-handbook/style-guide/templates/
   Q33 CDR-023 draft            → handbook/decisions/CDR-023-...md
   Q34 ops-standards draft      → handbook/how-we-work/operating-standards/
                                   flow-driven-architecture.md
   Q35 CDR-014 amendment        → handbook/decisions/CDR-014-...md (in-place)
   Q35 milestones.md companion  → handbook/how-we-work/operating-standards/
                                   milestones.md (in-place)
   Q41 intent.md template       → handbook/about-handbook/style-guide/templates/

   Q11, Q13-Q20 sub-skills      → brite-claude-plugins/plugins/flow-
                                   architecture/skills/flow-*/SKILL.md
   Q21 agents                   → brite-claude-plugins/plugins/flow-
                                   architecture/agents/*.md
   Q29 quality gates            → brite-claude-plugins/plugins/flow-
                                   architecture/skills/flow-audit/
                                   (gate enumeration code)
   Q30 plugin manifest          → brite-claude-plugins/plugins/flow-
                                   architecture/.claude-plugin/plugin.json
   Q31 breadcrumb schema        → embedded in orchestrator skills
   Q32 MCP/dep requirements     → brite-claude-plugins/plugins/flow-
                                   architecture/.mcp.json
   Q36 bootstrap (per-project)  → embedded in flow-preflight skill
   Q37, Q47 orchestrators       → brite-claude-plugins/plugins/flow-
                                   architecture/commands/flow-*.md
   Q38, Q42-Q44, Q53 utilities  → brite-claude-plugins/plugins/flow-
                                   architecture/commands/flow-*.md
   Q46 writeback layer          → brite-claude-plugins/plugins/flow-
                                   architecture/_shared/linear-writeback-
                                   pattern.md + skill code
   Q48 four-mode framework      → brite-claude-plugins/plugins/flow-
                                   architecture/_shared/four-mode-
                                   framework.md
   Q50-Q53 cloned commands      → brite-claude-plugins/plugins/flow-
                                   architecture/commands/flow-*.md
   Q55 plugin CLAUDE.md         → brite-claude-plugins/plugins/flow-
                                   architecture/CLAUDE.md

   Validation findings + audit  → brite-claude-plugins/plugins/flow-
   trails + parking-lot           architecture/docs/design-rationale.md
   rationale + handoff notes      (archive home for memory file content
                                   that doesn't fit the above)

   RUNTIME OUTPUT (not migrated; produced by plugin at runtime)
   ────────────────────────────────────────────────────────────
   docs/product/intent.md       Created by /flow:office-hours
   docs/product/master-flow-    Created by /flow:start-project or
     inventory.md                 /flow:retrofit-project
   docs/product/journeys/       Created by flow-journey-author per domain
   docs/product/flows/          Created by flow-doc-author per sub-flow
   docs/product/flows/INDEX.md  Created by flow-regen-index
   .flow/config.json            Created by flow-preflight
   .flow/phase-state.json       Created by orchestrators (resume support)
   Linear milestones + parents  Created by flow-linear-scaffold
     + 5-discipline children
```

### Phase 2 (org-level PRs) can land NOW

Drafts are complete:

- **Q33 CDR-023** — locked, content in memory
- **Q34 operating-standards page** — locked, content in memory
- **Q35 CDR-014 amendment + milestones.md companion** — locked, content in memory
- **Q22-Q28 + Q41 templates** — locked, structure spec'd in memory

These don't depend on plugin code. The team can adopt FDA patterns from handbook + about-handbook even before the plugin exists. Recommend landing these first — preserves org-level decisions immediately.

---

## 9. Parking Lot — v1.1+ Candidates

**55 items at D session-end** deferred to v1.1+ or v2+. Numbering disorder (#32/#33/#34) corrected per Step 1.A triage 2026-05-08. **Q49 promoted from parking lot #9 to its own Q-lock entry** at D session 2026-05-08 — parking lot #9 preserved as origin reference; Q49 lock is the canonical formalization. Grouped thematically:

### Plugin behavior tweaks

- **Cross-skill notification rate-limiter** (Q46 sub-decision 5) — if Brand Hub dogfood reveals comment spam from concurrent /flow:* invocations
- **Fail-and-prompt clobber detection** (Q46 sub-decision 4 alternative) — if dogfood reveals real edit-loss incidents inside Q46 markers
- **--strict flag for /flow:audit** (Q38 sub-decision 6 alternative) — fail CI on any overrides present
- **--linear-surface flag for /flow:audit** (Q38 deferred → v1.1) — opt-in routing to Linear via Q46
- **L1 concerns Linear routing** (Q42 sub-decision 4) — currently docs/plans/ only; v1.1 promotes to Q46 writeback
- **Cross-domain parallelism** (Q37 sub-decision 2) — lift Q15/Q16 to multi-domain dispatch for ~15-30 min wall savings

### New v1.1+ commands

- **/flow:journey-refresh** (Q19 v1.1; Q47 sub-decision 2 dependency) — selective re-author for journey docs after add-sub-flow
- **/flow:design-consult** (Q45 deferred per Q1) — design-consultation interview branches from gstack
- **Per-org bootstrap orchestrator** (Q36 sub-decision 7) — auto-create handbook + about-handbook PRs at first FDA org adoption

### Schema evolution

- **Selective re-author mode** (parking lot #19) — flow-doc-author + flow-journey-author preserve body content, refresh deterministic front-matter only
- **L-review state in breadcrumb** (parking lot #31) — extend phase_status with review_status; currently L-reviews re-run on resume (acceptable per locked v1)
- **Hybrid greenfield-with-code mode** — Q19 currently strict greenfield; if Brand Hub or other dogfood reveals real gap with partial scaffold code

### Tooling extraction

- **_shared/linear-batched-list-pattern.md** (parking lot #27) — extract Q18.3's inline pattern to shared utility if Q43/Q53/Q46 also need batched list_issues (3+ callers)
- **stale_ok front-matter marker** (Q47 sub-decision 2 alternative) — per-domain control of journey-refresh after add-sub-flow

### v2+ candidates

- **Q49 canonical Brite design-system repo** — LOCKED 2026-05-08 as v2+ deferral-tracking; 3 pre-conditions + 2 promotion criteria
- **Plugin-on-plugin recursion** — apply FDA scaffolding to brite-claude-plugins itself; chicken-and-egg deferred

### Parking lot additions in C session (entries #35-#51)

**Plugin behavior tweaks (extends section above):**
- `--audit-preflight` flag for /flow:review (Q52 sub-decision 4 alternative; v1.1 if dogfood wants bundled coverage) — parking lot #48
- Auto-trigger /flow:retro from /flow:ship hook (Q44 sub-decision 2 alternative) — parking lot #40
- Cross-domain comparison via --cross-domain time-window flag for /flow:retro (Q44 sub-decision 3 alternative) — parking lot #41
- Plan-context augment retire if dogfood reveals reviewers don't benefit (Q52 sub-decision 6 REVERSE path) — parking lot #50

**New v1.1+ commands (extends section above):**
- flow-brainstorming clone if dogfood reveals FDA-context miscalibration (Q50 sub-decision 3 alternative) — parking lot #46
- flow-writing-plans clone if dogfood reveals format-specificity gap (Q50 sub-decision 3 alternative) — parking lot #47

**Schema evolution (extends section above):**
- Q22 amendment 1 retro-summary body marker (Q44 sub-decision 4 alternative) — parking lot #42
- Q46 amendment 3 + Q52 amendment 1 review-summary upgrade path (Q52 sub-decision 5 v1.1 sequenced) — parking lot #49
- Q29 amendment 1 plan-X-section discipline-completion gate (Q53 sub-decision 6 v1.1) — parking lot #51

**Tooling extraction (extends section above):**
- Drift-detection for cloned commands (Q50 sub-decision 6 v1.1; gh API hash check vs source SHA) — parking lot #45

**Cross-skill features (NEW category):**
- "Plan Completion" cross-skill-state mining for Q44 retros (consume Q46 written_pairs[] from prior runs) — parking lot #43
- Team retro facilitation features (multi-participant input collection; voting; synthesis) — parking lot #44

**Methodology / Process (NEW category):**
- **Parking lot #39:** Cribbed-content lock-prerequisite — verify source via gh API or repo read BEFORE drafting. Established Q48 lock; extended Q51 lock to require re-verification at EACH cribbed-content lock (not inheritance).

### Parking lot additions in D session (entries #52-#55) — test surface candidates

Per Q40 R3 user lock 2026-05-08: v1.0 ships with no test surface (Brand Hub dogfood = integration test); 4 specific bash + schema validation items added to parking lot v1.1 candidates with explicit promotion criteria. Promotion criteria (shared by all 4): any v1.x release introduces schema regression OR adds 3+ new skills/agents/utilities (which increases edit frequency on schemas).

- **#52 plugin.json schema validation** — CI check that `plugin.json` parses as valid JSON + has all required fields per Claude Code plugin schema (~10-20 lines of CI)
- **#53 SKILL.md frontmatter validation** — CI check that all 10 sub-skills' SKILL.md files have required frontmatter fields (~20-40 lines of CI bash + python3 YAML parse)
- **#54 Bash unit tests for 4 helper scripts** — `flow-detect-mode.sh` + `flow-detect-fda-shape.sh` + `flow-resume-breadcrumb.sh` + `flow-context-load.sh` (Q30.6 helpers). Test framework: bash 3.2-compatible per parking lot #32 constraint (`bats-core` or hand-rolled). ~100-200 lines of test code + CI integration. Q30.6 explicitly cited helpers as "testable in isolation" — v1.1 candidate fulfills that promise.
- **#55 Smoke tests for command trigger resolution** — verify each `commands/*.md` file has well-formed frontmatter + description triggers expected slash command resolution. Lower priority than #52-#54 because trigger resolution failures surface immediately on user invocation. ~50-100 lines of CI.

---

## Appendix A — ASCII Diagram Index

Diagrams in this document, in order of appearance:

1. **Multi-session interview pattern** (§2) — three roles + memory file as canonical store
2. **Validation-first loop** (§2) — per-Q error correction cycle
3. **Session rollover mechanism** (§2) — context-fill handoff to fresh session
4. **4-tier FDA hierarchy** (§3a) — Domain → Sub-flow → Disciplines → INDEX
5. **Plugin command surface** (§3c) — ~17 slash commands organized by role
6. **Sub-skill dependency graph** (§3d) — foundation → sub-skills → agents → orchestrators → utilities
7. **Greenfield orchestrator phase flow** (§3e) — 8 phases / 4 gates with hybrid control flow
8. **Retrofit orchestrator phase flow** (§3f) — 9 phases / 5 gates with Q14 cross-reference
9. **L-review scoping** (§3g) — L1/L2/L3/L4 scopes + fire-and-write flow
10. **Quality gate stack** (§3h) — 8 + 22 + 6 = 36 gates post-Q29 amendment 2 + audit runner
11. **State substrates** (§3i) — per-project + repo + Linear + cross-org
12. **Plan forward — 6 phases** (§7) — design → org migration → scoping → implementation → dogfood → release
13. **Migration map** (§8) — memory file → canonical homes

---

## Appendix B — Q-Lock Cross-Reference

For navigation within the source-of-truth memory file:

```
Q1   Plugin name + repo                          — handbook section
Q2   Template promotion path                     — Q22-Q28+Q41 dependency
Q7   Orchestrator-as-skill pattern               — Q37/Q47 foundation
Q8   v1 acceptance gate                          — Brand Hub retrofit
Q9   CDR-023 migration policy                    — additive-only
Q10  User-confirmation gate budget               — 5/4 retrofit/greenfield
Q11  flow-inventory-codebase-scan                — retrofit only
Q12  flow-preflight                              — 5 responsibilities
Q13  flow-linear-scaffold                        — Q13.4 gate, Q13.5 atomic
Q14  flow-legacy-cross-reference                 — retrofit only; Q14.2 markers
Q15  flow-doc-author                             — Q15.2 parallel, Q15.8 ordering
Q16  flow-journey-author                         — Q16.2 parallel, Q16.7 L2 read
Q17  flow-sandbox-scaffold                       — per-flow harness
Q18  flow-regen-index                            — Q18.3 batched list_issues
Q19  flow-inventory-interview (greenfield)       — strict greenfield; Q19.6 retry
Q20  flow-inventory-add (incremental)            — 2 modes; Q20.6 within-skill gate
Q21  Agent definitions                           — 12 named agents (Option C)
Q22  Domain-as-milestone description template    — eyebrow link block
Q23  Sub-flow parent issue template              — Q23 mod 2: L3 review summary
Q24  Five discipline-child issue templates       — strict 5; blockedBy chain
Q25  Flow INDEX.md schema                        — 11 columns
Q26  Per-domain user journey doc template        — Q26 mod 2: L2 review summary
Q27  Job story doc template                      — 17 front-matter fields
Q28  Customer-facing how-to template             — voice-bound
Q29  Quality-gate stack enumeration              — 36 gates post-amendment 2 (8+22+6)
Q30  Plugin manifest + directory structure       — Q30.2 17 commands enum
Q31  Resume breadcrumb schema                    — Q31.1 schema; 2 amendments
Q32  MCP and dependency requirements             — Linear MCP; jq + python3
Q33  CDR-023 content draft                       — Status: Proposed at first commit
Q34  Operating-standards page content draft      — Q34 sister to milestones.md
Q35  CDR-014 amendment content                   — in-place edits + milestones.md
Q36  Plugin bootstrap shape                      — per-project; per-org parked
Q37  Greenfield orchestrator phase sequence      — 8 phases / 4 gates / hybrid
Q38  /flow:audit shape                           — 7 sub-decisions; 36-gate runner (post-Q29 amendment 2)
Q40  Production readiness checklist              — LOCKED 2026-05-08; static doc; v1.0 release gate; 12 criteria
Q41  PROJECT-INTENT.md template                  — LOCKED; 6 FM fields + 7 sections + L1
Q42  /flow:office-hours skill design             — LOCKED; 7 sub-decisions; Q31 amendment 1
Q43  /flow:plan-{discipline} skill suite         — LOCKED; 5 commands; Q24 amendment 1
Q44  /flow:retro skill design                    — LOCKED; manual-only; single-domain; comment surface
Q45  /flow:design-consult skill design           — LOCKED 2026-05-08 DEFERRAL-TRACKING; v1.1 deferral confirmed
Q46  Linear-aware adaptation layer               — LOCKED; Q31 amendment 2; type registry
Q47  /flow:add split (add-domain vs add-sub-flow)— LOCKED; 7 sub-decisions; 2 commands
Q48  Four-mode scope-review framework            — LOCKED; gstack-faithful taxonomy; Q21 amendment 1
Q49  Canonical Brite design-system repo          — LOCKED 2026-05-08 DEFERRAL-TRACKING; v2+ deferral confirmed
Q50  Clone-and-swap scope from workflows         — LOCKED; 3-way taxonomy; Q50 amend 1+2
Q51  /flow:session-start (cloned)                — LOCKED; 9 steps; Step 6 plan-X dispatch
Q52  /flow:review (cloned)                       — LOCKED; lighter swap; PASSIVE+PLAN context augments
Q53  /flow:ship (cloned)                         — LOCKED; heaviest swap; primary Q46 consumer
Q54  Multi-perspective L-review pattern (META)   — LOCKED; L1/L2/L3/L4 scoping
Q55  Plugin CLAUDE.md content design             — LOCKED 2026-05-08; 13 H2 sections; methodology preservation
```

---

## Closing notes

This artifact is a **point-in-time synthesis**, not a replacement for the canonical memory file. When the memory file and this document conflict, **trust the memory file**. This document is for orientation; the file is for authority.

If you're picking this up cold:

1. **Read the memory file** at `~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md` (or its snapshot at `docs/plans/fda-plugin-interview.md`)
2. **Apply validation-first when continuing** — verify any cited lock against the file before relying on it
3. **Lock only with user signal** — never lock unilaterally; always wait for explicit "lock this" affirmation
4. **Push parking-lot scope creep back** — design discipline matters; v1 vs v1.1 distinction is load-bearing

The plugin will ship. The hard work of design has been done. Implementation phase is next.
