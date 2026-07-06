# Brite Agent Platform — Linear Issue Catalog

> **PRD**: `docs/designs/brite-agent-platform.md`
> **Status**: Draft — review before creating in Linear
> **Project**: Brite Plugin Marketplace
> **Total**: ~64 new issues + 9 moves + 1 close across 8 milestones

## Table of Contents

- [Enhanced Issue Template](#enhanced-issue-template)
- [Milestone Descriptions](#milestone-descriptions)
- [Cleanup Actions](#cleanup-actions)
- [Milestone 1: Company Knowledge Layer](#milestone-1-company-knowledge-layer) (12 issues)
- [Milestone 2: Project-Start Redesign](#milestone-2-project-start-redesign) (13 issues)
- [Milestone 3: Decision Trace Architecture](#milestone-3-decision-trace-architecture) (11 issues)
- [Milestone 4: Plugin Ecosystem Foundation](#milestone-4-plugin-ecosystem-foundation) (7 issues, 5 existing)
- [Milestone 5: Domain Plugin Expansion](#milestone-5-domain-plugin-expansion) (6 issues, 2 existing)
- [Milestone 6: Context Refresh Pipeline](#milestone-6-context-refresh-pipeline) (6 issues)
- [Milestone 7: Symphony Autonomous Execution](#milestone-7-symphony-autonomous-execution) (12 issues)
- [Milestone 8: Context Governance & Observability](#milestone-8-context-governance--observability) (4 issues)
- [Dependency Graph](#dependency-graph)
- [Summary Table](#summary-table)

---

## Enhanced Issue Template

Every issue is structured so an AI agent can pick it up atomically and resolve it without human input. The issue IS the plan — no separate plan file needed.

```markdown
## Goal
[1-2 sentences: what capability this delivers and why it matters to the platform]

## System Context
[How the piece being modified fits into the larger architecture]
- What system/component is being created or modified?
- What will READ from the output of this work? (downstream consumers)
- What FEEDS INTO this work? (upstream dependencies)
- Where does this sit in the 4-layer platform? (Project-Start / Domain Plugins / Workflows / Symphony)
[Brief ASCII diagram if the relationships are non-obvious]

## Background
- Milestone position (e.g., "Milestone 1, Task 3 of 12")
- Why this exists NOW (what dependency unlocked it, what it unblocks)
- PRD section reference: `docs/designs/brite-agent-platform.md` Section X, lines Y-Z
- Research/prior art that informed the design decisions

## Explore (Do this BEFORE writing any code)
Numbered list — each item names a specific file and what to look for:
1. **Read** `exact/path/to/file.md` — look for [specific pattern, section, or convention]
2. **Read** `exact/path/to/other.md` — understand how [specific mechanism] works
3. **Research** [external topic] — find [specific information]
4. **Key questions to answer before proceeding:**
   - [Question 1 — what you need to know]
   - [Question 2 — what you need to decide]

## Plan

### Architecture
[How this fits the system — diagram or structured description showing relationships]
[What existing pattern this follows — name the file and the specific pattern]

### Decisions Already Made (DO NOT reconsider these)
- [Decision 1 — source: PRD Section X / prior issue BRI-XXXX]
- [Decision 2 — source]

### Open Decisions (Agent decides with guidance)
- **[Decision name]**: [Options with tradeoffs]. Recommendation: [X] because [Y].

### File Manifest
| Action | File | Purpose |
|--------|------|---------|
| Create | `exact/path/to/new-file.md` | What this file does |
| Modify | `exact/path/to/existing.md` | What changes and why |

## Execute

### Task 1: [Name] (~X min)
- **File**: `exact/path`
- **Do**:
  1. [Concrete step 1]
  2. [Concrete step 2]
- **Content** (what to write — actual content, not a description of content):
  ```markdown
  [The actual content the file should contain, or a detailed structural spec
   with enough detail that the agent doesn't need to make design decisions]
  ```
- **Pattern**: Follow the structure in `existing/reference/file.md` — specifically [aspect to copy]
- **Verify**: [Per-task check to run before moving to next task]

### Task 2: [Name] (~X min)
- **File**: `exact/path`
- ...

### Edge Cases
[Specific scenarios the implementation MUST handle]
- **[Scenario]**: What if [X happens]? → Handle by [Y]
- **[Scenario]**: What if [Z is missing]? → Degrade gracefully: [how]

### Anti-Patterns
[Specific mistakes to avoid — each with WHY it's wrong]
- Do NOT [mistake] — because [consequence]
- Do NOT [mistake] — because [consequence]

### Known Pitfalls (from past sessions)
[Learnings from session memory that apply to this specific issue]
- **[Pitfall]**: [What went wrong before → what to do instead]

## Testing Scenarios
[Concrete scenarios to verify — do X, expect Y]
1. **Scenario**: [Specific action to take]
   **Expected**: [Specific observable outcome]
2. **Scenario**: [Another action]
   **Expected**: [Another outcome]
3. **Scenario**: [Edge case to test]
   **Expected**: [How it should be handled]

## Definition of Done
Single checklist — ALL must be true before marking this issue complete:
- [ ] [Functional criterion 1]
- [ ] [Functional criterion 2]
- [ ] **Automated**: `scripts/validate.sh` passes (all sections)
- [ ] **Automated**: `scripts/test-hooks.sh` 37/37 pass (if hooks changed)
- [ ] **Automated**: `scripts/test-skill-triggers.sh` 38/38 pass (if triggers changed)
- [ ] **Cross-ref**: [specific file] updated to reflect changes
- [ ] **No regressions**: [specific existing check] still passes
- [ ] **Version**: Bump to X.Y.Z in plugin.json + marketplace.json (if applicable)

## If Stuck
[Fallback paths and escalation]
- If [common blocker]: try [alternative approach]
- If [dependency not ready]: [what to do — skip, scaffold, mock]
- If [external system unavailable]: [degrade gracefully by...]
```

### Template Rules

1. **Content over description**: Execute tasks should contain ACTUAL content (code blocks, full file specs), not descriptions like "write a file that does X." The agent should copy-paste-modify, not design from scratch.
2. **Per-task verification**: Every task gets a Verify step. Don't batch all verification to the end — catch problems early.
3. **Specific file references**: Never say "read the relevant file." Always name the exact path.
4. **Known Pitfalls are mandatory**: Check session memory for learnings that apply. Past sessions had patterns of agents repeating known mistakes (e.g., substring matching instead of standalone-token matching for flags, stale step numbers after renumbering).
5. **Edge Cases are mandatory**: The happy path is obvious. The edge cases are where agents fail.
6. **If Stuck is mandatory**: Agents waste time spinning when blocked. Give them exit ramps.

---

## Milestone Descriptions

### Milestone 1: Company Knowledge Layer

**Size**: M (Medium) — 12 issues
**Goal**: Establish the handbook repo as the single source of truth for company context. Every project gets automatic access to company decisions (CDRs), org structure, and business metrics via structured markdown that agents can read.

**Success criteria**:
- Handbook repo has `context/operational/`, `context/analytical/`, `decisions/`, `precedents/`, `org/` directories with populated content
- CDR format is defined with INDEX.md manifest containing 8+ seeded CDRs covering all major tech stack decisions
- An agent running `session-start` can read company context via @import and warn about stale docs
- `writing-plans` checks CDR INDEX before proposing architecture that conflicts with company decisions
- Cross-repo @import solution is prototyped, chosen, and implemented

**Dependencies**: None — this is the foundation layer. Everything else builds on it.
**Key risks**: Cross-repo @import is a technical blocker (PRD Open Question #25). Handbook maintenance burden (Open Question #28).

### Milestone 2: Project-Start Redesign

**Size**: L (Large) — 13 issues
**Goal**: Transform `/workflows:project-start` from a binary technical/non-technical interview into a universal project router. Trait-based classification detects what KIND of project this is (from 50+ possible scenarios) and activates the right plugins, documentation scaffolds, and infrastructure automatically.

**Success criteria**:
- Running `/project-start` for 5+ different project types (SaaS app, marketing campaign, vendor evaluation, data pipeline, mobile app) produces correctly differentiated outputs
- Trait classification correctly identifies combinations from the 11-trait system
- Interview uses JTBD + MI + SPIN methodology (not a form — a conversation)
- Express mode auto-detects traits from existing codebases
- Brownfield mode imports existing context and reconciles with CDRs
- All outputs verified by post-setup smoke test

**Dependencies**: Milestone 1 (needs handbook for @imports and CDR checks)
**Key risks**: Interview quality is subjective and hard to test. Trait classification accuracy across 50 scenarios.

### Milestone 3: Decision Trace Architecture

**Size**: M (Medium) — 11 issues
**Goal**: Agents emit structured decision traces during execution. Traces compound into a searchable precedent database. Future agents can find "how did we solve this before?" during brainstorm/plan phases, creating a compounding knowledge flywheel.

**Success criteria**:
- `executing-plans` emits structured traces at each task checkpoint
- `compound-learnings` extracts traces to `docs/precedents/` and identifies org-level promotion candidates
- `precedent-search` skill finds relevant precedents during brainstorm/plan
- CDR compliance review agent catches CDR violations in code changes
- Flywheel metrics (precedent hit rate, confidence trends) are tracked

**Dependencies**: Milestone 1 (precedent storage lives in handbook). Benefits from Milestone 2.
**Key risks**: Trace volume management. Search quality without vector infrastructure. QMD evaluation outcome determines search approach.

### Milestone 4: Plugin Ecosystem Foundation

**Size**: L (Large) — 7 issues (5 are existing BRI-1724-1728)
**Goal**: Establish the context-skill standard and prove it with the first domain plugin (Marketing). Any business function can be packaged as a plugin with a context-skill, domain skills, and CLI tools.

**Success criteria**:
- Context-skill standard is formally specified
- Marketing plugin is installed and functional (32 skills, context-skill)
- Project-start detects `needs-marketing` trait and activates marketing plugin
- Plugin discovery suggests missing plugins during project-start

**Dependencies**: Milestone 2 (project-start integration for plugin discovery/activation)

### Milestone 5: Domain Plugin Expansion

**Size**: M per plugin — 6 issues (2 existing: BRI-1343, BRI-1347)
**Goal**: Extract engineering/design skills from workflows into dedicated plugins. Create new sales/product plugins. Each follows the context-skill standard.

**Success criteria**:
- 4 domain plugins (engineering, design, sales, product) each have a functioning context-skill
- Skills correctly extracted from workflows without breaking existing functionality
- Project-start activates the right combination of plugins per project type

**Dependencies**: Milestone 4 (context-skill standard)

### Milestone 6: Context Refresh Pipeline

**Size**: M (Medium) — 6 issues
**Goal**: Automated pipelines keep handbook context fresh. BigQuery metrics and Salesforce customer data flow into structured markdown with temporal trends (not just snapshots — agents see trajectory).

**Success criteria**:
- GitHub Action runs weekly, queries BigQuery, computes deltas vs previous snapshot
- Salesforce data flows into anonymized `customers.md`
- Automated PRs for significant changes, auto-merge for minor updates
- PII handling implemented

**Dependencies**: Milestone 1 (handbook structure must be stable)

### Milestone 7: Symphony Autonomous Execution

**Size**: XL (Extra Large) — 12 issues
**Goal**: A daemon polls Linear for ready issues, dispatches agents to isolated workspaces, executes using Brite domain plugins and workflows, and lands PRs. Teams manage the Linear board; agents execute autonomously.

**Success criteria**:
- Create a Linear issue → mark "Ready" → agent picks up → executes → creates PR → moves to "Human Review"
- Brite review agents serve as quality gates
- Decision traces emitted in autonomous mode same as interactive
- Cost management and failure handling are robust

**Dependencies**: Milestones 1-5 must be stable
**Key risks**: Runtime decision (Elixir fork vs TS). Cost at scale. Agent failure modes.

### Milestone 8: Context Governance & Observability

**Size**: S (Small) — 4 issues
**Goal**: Dashboards and review agents ensure context quality over time. CDR governance prevents conflicting decisions. Flywheel metrics prove the system is improving.

**Success criteria**:
- CDR governance model defines authority levels and conflict resolution
- Context quality dashboard tracks freshness, CDR coverage, precedent hit rate
- Context governance review agent flags stale/conflicting context

**Dependencies**: Milestones 1-3 working

---

## Cleanup Actions

Before creating new milestones, resolve these existing issues:

| Action | Issue | Details |
|--------|-------|---------|
| **Close** | BRI-1337 | "Improve project-start with framework templates" — superseded by M2 (Project-Start Redesign). Comment: "Superseded by Brite Agent Platform epic. Framework templates → trait-based classification + domain plugin context-skills." |
| **Move → M4** | BRI-1724 | Scaffold marketing plugin structure |
| **Move → M4** | BRI-1725 | Port 32 marketing skills to plugin format |
| **Move → M4** | BRI-1726 | Port marketing CLI tools and integration guides |
| **Move → M4** | BRI-1727 | Create Brite product-marketing-context skill |
| **Move → M4** | BRI-1728 | Update CI and docs for marketing plugin |
| **Move → M5** | BRI-1343 | Create API design skill → Engineering plugin |
| **Move → M5** | BRI-1347 | Enhance frontend-design with design tokens → Design plugin |
| **Move → M7** | BRI-1352 | Create onboarding agent → Symphony |
| **Move → M8** | BRI-1782 | Behavioral test framework → Governance |

---

## Milestone 1: Company Knowledge Layer

### M1-1: Restructure handbook repo directory layout

**Priority**: High | **Size**: S | **Labels**: `handbook`, `foundation`

#### Goal

Create the directory structure in the handbook repo that supports the two-layer context model (operational + analytical), company decision records, precedent database, and org identity mapping. This is the physical foundation that all other knowledge layer work builds on.

#### System Context

```
Handbook Repo (Brite-Nites/handbook)
├── context/
│   ├── operational/    ← M1-5 populates (stable company context)
│   └── analytical/     ← M1-7, M1-8 populate (dynamic metrics)
├── decisions/          ← M1-3 defines format, M1-4 seeds CDRs
├── precedents/         ← M3-4 promotes traces here
├── org/                ← M1-6 populates (identity, ownership)
├── templates/          ← M1-3 creates CDR template
├── CLAUDE.md           ← M1-2 creates (agent reading instructions)
└── README.md           ← This issue creates
```

- **Downstream consumers**: Every subsequent M1 issue writes into these directories. M1-11 (@import solution) makes this content available to project repos. All agents that @import company context read from here.
- **Upstream dependencies**: None — this is the first issue.
- **Platform layer**: Knowledge Layer (Layer 0 — foundation for everything)

#### Background

- Milestone 1, Task 1 of 12 (first issue in the entire epic)
- This unblocks ALL other M1 issues — nothing can populate the handbook until the structure exists
- PRD reference: `docs/designs/brite-agent-platform.md` Section 5 (Knowledge Architecture), Section 5.3 (Operational Context Foundation)
- The handbook repo (`Brite-Nites/handbook`) currently has minimal or no structure. The platform vision uses it as the "company brain" — structured knowledge that agents @import into project CLAUDE.md files.

#### Explore

1. **Read** the current handbook repo — `git clone Brite-Nites/handbook && ls -la` — understand what already exists. Are there existing files that need to be moved? Is there already a README?
2. **Read** `docs/designs/brite-agent-platform.md` lines 200-280 (Section 5, Knowledge Architecture) — understand the two-layer context model and why operational and analytical are separated
3. **Read** `docs/designs/brite-agent-platform.md` lines 280-350 (Section 5.3, Operational Context Foundation) — understand what goes in each directory
4. **Key questions to answer before proceeding:**
   - Does the handbook repo already exist? If not, create it first.
   - Are there existing files that should be relocated into the new structure?
   - Does the repo have branch protection? (We should work on a branch, not direct to main)

#### Plan

##### Architecture

```
handbook/                          ← Repo root
├── CLAUDE.md                      ← M1-2 (NOT this issue)
├── README.md                      ← Created by this issue
├── context/
│   ├── operational/
│   │   ├── README.md              ← Brief: "Stable company context. Refreshes quarterly."
│   │   └── .gitkeep
│   └── analytical/
│       ├── README.md              ← Brief: "Dynamic business metrics. Refreshes weekly."
│       └── .gitkeep
├── decisions/
│   ├── README.md                  ← Brief: "Company Decision Records (CDRs). See INDEX.md."
│   └── .gitkeep
├── precedents/
│   ├── README.md                  ← Brief: "Org-level decision traces promoted from projects."
│   └── .gitkeep
├── org/
│   ├── README.md                  ← Brief: "Identity resolution, teams, ownership."
│   └── .gitkeep
└── templates/
    ├── README.md                  ← Brief: "Templates for CDRs and context docs."
    └── .gitkeep
```

##### Decisions Already Made (DO NOT reconsider)
- Two top-level context directories: `context/operational/` and `context/analytical/` (PRD Section 5.3-5.4)
- Operational refreshes quarterly, analytical refreshes weekly (PRD Section 5.3)
- `decisions/` for CDRs, `precedents/` for promoted traces, `org/` for identity (PRD Section 5)
- `templates/` for CDR and context doc templates (PRD Section 5.2)

##### Open Decisions
- **Existing content relocation**: If the handbook has existing files, they should be moved into the appropriate new directory. If no clear mapping exists, leave them at the root and note in the PR. Agent decides based on file content.
- **README depth**: Each directory README should be 3-5 lines max — just enough to orient someone browsing on GitHub. Don't over-document.

##### File Manifest
| Action | File | Purpose |
|--------|------|---------|
| Create | `README.md` | Handbook overview with directory map |
| Create | `context/operational/README.md` | Directory purpose + refresh cadence |
| Create | `context/operational/.gitkeep` | Track empty directory |
| Create | `context/analytical/README.md` | Directory purpose + refresh cadence |
| Create | `context/analytical/.gitkeep` | Track empty directory |
| Create | `decisions/README.md` | CDR directory purpose |
| Create | `decisions/.gitkeep` | Track empty directory |
| Create | `precedents/README.md` | Precedent directory purpose |
| Create | `precedents/.gitkeep` | Track empty directory |
| Create | `org/README.md` | Org structure directory purpose |
| Create | `org/.gitkeep` | Track empty directory |
| Create | `templates/README.md` | Templates directory purpose |
| Create | `templates/.gitkeep` | Track empty directory |

#### Execute

##### Task 1: Create top-level README.md (~5 min)
- **File**: `README.md`
- **Do**:
  1. Create the file at repo root
  2. Write the handbook overview
- **Content**:
  ```markdown
  # Brite Handbook

  The company knowledge base for AI-assisted work. Agents @import from this repo
  to access company decisions, context, and precedents during project work.

  ## Directory Structure

  | Directory | What lives here | Refresh cadence |
  |-----------|----------------|-----------------|
  | `context/operational/` | Company profile, tech stack, brand, processes | Quarterly |
  | `context/analytical/` | Business metrics, trends, customer data | Weekly |
  | `decisions/` | Company Decision Records (CDRs) — org-wide architectural and policy decisions | As needed |
  | `precedents/` | Decision traces promoted from project work — searchable prior art | Continuous |
  | `org/` | Team structure, roles, ownership mapping, cross-system identity resolution | Quarterly |
  | `templates/` | Templates for CDRs and context documents | As needed |

  ## How Agents Use This

  1. Project CLAUDE.md files @import handbook content via [cross-repo mechanism]
  2. `session-start` checks context freshness and warns if documents are stale
  3. `writing-plans` checks CDR INDEX before proposing architecture decisions
  4. `brainstorming` searches precedents for relevant prior art
  5. `compound-learnings` promotes valuable decision traces back here

  ## How Humans Maintain This

  - **Operational context**: Review and update quarterly (or when company direction changes)
  - **Analytical context**: Automated via GitHub Actions (BigQuery, Salesforce pipelines)
  - **CDRs**: Created via PR when new company-wide decisions are made
  - **Precedents**: Promoted automatically from projects, reviewed via PR

  See `CLAUDE.md` for agent-specific reading instructions.
  ```
- **Verify**: README renders correctly — check with `gh repo view` or preview on GitHub

##### Task 2: Create directory structure with README files (~5 min)
- **File**: All subdirectory READMEs
- **Do**: Create each directory with a `.gitkeep` and a brief README.md
- **Content for each README** (3-5 lines each):

  `context/operational/README.md`:
  ```markdown
  # Operational Context

  Stable company context that changes infrequently. Refreshes quarterly.

  Files: `company-profile.md`, `tech-stack.md`, `brand.md`, `processes.md`
  ```

  `context/analytical/README.md`:
  ```markdown
  # Analytical Context

  Dynamic business metrics with temporal trends. Refreshes weekly via GitHub Action.

  Files: `business-metrics.md`, `metric-definitions.md`, `customers.md`
  ```

  `decisions/README.md`:
  ```markdown
  # Company Decision Records (CDRs)

  Org-wide decisions that apply across all Brite projects. See `INDEX.md` for the manifest.

  Format: `CDR-NNN-kebab-title.md`. Statuses: Active, Superseded, Deprecated, Under Review.
  ```

  `precedents/README.md`:
  ```markdown
  # Precedents

  Decision traces promoted from project work. Searchable prior art for future agents.

  See `INDEX.md` for the searchable manifest.
  ```

  `org/README.md`:
  ```markdown
  # Organization

  Team structure, roles, ownership mapping, and cross-system identity resolution.

  Files: `teams.md`, `roles.md`, `stakeholders.md`, `ownership.md`, `identity-map.md`
  ```

  `templates/README.md`:
  ```markdown
  # Templates

  Templates for creating new CDRs and context documents.

  Files: `CDR-TEMPLATE.md`, `context-doc-template.md`
  ```

- **Verify**: `find . -type d | sort` shows all expected directories

##### Task 3: Relocate existing content (if any) (~3 min)
- **Do**: If the handbook repo has existing files beyond `.git`, evaluate each:
  - If it clearly belongs in a new directory → `git mv` it there
  - If unclear → leave in place and note in the PR description
  - Preserve git history with `git mv` (never delete + create)
- **Verify**: `git status` shows only additions and renames, no deletions of content

##### Edge Cases
- **Handbook repo doesn't exist yet**: Create it first with `gh repo create Brite-Nites/handbook --private`. Then proceed.
- **Repo has branch protection on main**: Create a feature branch `holden/handbook-restructure` and open a PR.
- **Existing files conflict with new structure**: Don't delete anything. Move what maps clearly, leave the rest, document in PR.

##### Anti-Patterns
- Do NOT create content files (CDRs, context docs, etc.) — those are separate issues (M1-3 through M1-7). This issue creates ONLY the directory structure and READMEs.
- Do NOT create the CLAUDE.md — that's M1-2. The CLAUDE.md needs the directory structure to reference, so this must come first.
- Do NOT over-document the READMEs — 3-5 lines each. They're signposts, not essays.
- Do NOT use deeply nested directories — the flat structure is intentional for easy @import paths.

##### Known Pitfalls (from past sessions)
- **Cross-repo work**: This issue works in the HANDBOOK repo, not the plugins repo. Make sure you're in the right directory before making changes.

#### Testing Scenarios

1. **Scenario**: Clone a fresh copy of the handbook repo after this PR merges
   **Expected**: `ls` shows `context/`, `decisions/`, `precedents/`, `org/`, `templates/`, `README.md`. Each directory has a `README.md` and `.gitkeep`.

2. **Scenario**: Open the repo on GitHub and click through directories
   **Expected**: Each directory shows its README rendered, explaining purpose and refresh cadence.

3. **Scenario**: Run `find . -name README.md | wc -l` from repo root
   **Expected**: 7 (root + 6 subdirectories: operational, analytical, decisions, precedents, org, templates)

#### Definition of Done

- [ ] Handbook repo exists in `Brite-Nites` org
- [ ] All 6 directories created: `context/operational/`, `context/analytical/`, `decisions/`, `precedents/`, `org/`, `templates/`
- [ ] Each directory has a `README.md` (3-5 lines) and `.gitkeep`
- [ ] Top-level `README.md` has directory map table and usage overview
- [ ] Any existing content relocated (not orphaned or deleted)
- [ ] PR opened (not merged directly to main)
- [ ] Directory names match PRD exactly (lowercase, no variations)

#### If Stuck

- If handbook repo doesn't exist: create with `gh repo create Brite-Nites/handbook --private --description "Brite company knowledge base for AI-assisted work"`
- If `gh` auth fails: ask user to authenticate with `gh auth login`
- If existing content is ambiguous: leave in place, document in PR, ask user to review

---

### M1-2: Write handbook CLAUDE.md for agent consumption

**Priority**: High | **Size**: M | **Labels**: `handbook`, `foundation`

#### Goal

Write a CLAUDE.md for the handbook repo that teaches AI agents how to read, navigate, and use handbook content correctly. This is the instruction manual agents receive when they @import company context — it tells them what's authoritative, how to interpret CDR statuses, how to check freshness, and when to escalate decisions vs decide autonomously.

#### System Context

```
Project CLAUDE.md ──@import──→ Handbook CLAUDE.md
                                    │
                                    ├── Teaches agent: "How to read CDRs"
                                    ├── Teaches agent: "What freshness means"
                                    ├── Teaches agent: "How to check for conflicts"
                                    └── Teaches agent: "What NOT to do with handbook content"

All agents in every project that @imports handbook content
will read this CLAUDE.md as context instructions.
```

- **Downstream consumers**: Every agent in every Brite project that @imports handbook content. This is the most-read file in the entire knowledge layer.
- **Upstream dependencies**: M1-1 (directory structure must exist to reference)
- **Platform layer**: Knowledge Layer — the meta-instruction layer

#### Background

- Milestone 1, Task 2 of 12
- Unblocks: M1-9 (freshness tracking in session-start implements the rules defined here), M1-10 (CDR-check in writing-plans follows the conflict handling defined here)
- PRD reference: `docs/designs/brite-agent-platform.md` Section 5 (Knowledge Architecture), Section 5.2 (CDR governance), Section 5.3 (Operational Context), Section 5.4 (Analytical Context)
- Every repo in the Brite org gets a CLAUDE.md that guides agent behavior. The handbook's CLAUDE.md is unique — it doesn't guide agents BUILDING the handbook; it guides agents READING the handbook from other projects via @import.

#### Explore

1. **Read** `~/.claude/CLAUDE.md` (Holden's global preferences) — understand the style, conciseness level, and section structure that Holden uses for agent instructions
2. **Read** `britenites-claude-plugins/CLAUDE.md` — study the structure of a comprehensive project CLAUDE.md. Note: sections like "Plugin Philosophy", "Skill Routing", "Review Agents" — each teaches agents specific behaviors. The handbook CLAUDE.md needs the same specificity for reading behaviors.
3. **Read** `docs/designs/brite-agent-platform.md` Section 5.2 — CDR status definitions (Active, Superseded, Deprecated, Under Review), governance rules, conflict handling
4. **Read** `docs/designs/brite-agent-platform.md` Section 5.3 — Operational context: file authority, refresh cadence (quarterly), what each file contains
5. **Read** `docs/designs/brite-agent-platform.md` Section 5.4 — Analytical context: freshness rules, temporal patterns (trends + deltas, not just snapshots), refresh cadence (weekly)
6. **Key questions to answer before proceeding:**
   - How long is the plugins repo CLAUDE.md? (Aim for similar length or shorter — agents parse this quickly alongside project context)
   - What's the most critical behavior to teach? (CDR conflict detection — prevents agents from violating company decisions)

#### Plan

##### Architecture

```
Agent Context Window (during any session):
┌─────────────────────────────────┐
│ Project CLAUDE.md               │
│   @import handbook/CLAUDE.md ───┤──→ THIS FILE
│   @import handbook/decisions/   │     Teaches:
│   @import handbook/context/     │     1. How to read CDRs
│   ...                           │     2. Freshness rules
│ Project code context            │     3. Conflict handling
│ Task description                │     4. What NOT to do
└─────────────────────────────────┘
```

##### Decisions Already Made (DO NOT reconsider)
- CDR statuses: Active, Superseded, Deprecated, Under Review (PRD Section 5.2)
- Operational context refreshes quarterly; analytical refreshes weekly (PRD Section 5.3-5.4)
- Freshness soft warning at 1.5x cadence overdue; hard warning at 2x (PRD Section 5.4)
- Agents must check CDR INDEX before proposing conflicting architecture (PRD Section 5.2)
- CDR conflicts surface to user — agents never silently override (PRD Section 5.2)
- Context docs have frontmatter: `source`, `last_refreshed`, `refresh_cadence` (PRD Section 5.4)

##### Open Decisions
- **Behavioral examples**: Include 2-3 examples of correct vs incorrect agent behavior? Recommendation: YES — examples calibrate judgment better than rules alone.
- **File length target**: Aim for 80-120 lines. Shorter = more likely to be fully read in context. The plugins CLAUDE.md is ~90 lines.

##### File Manifest
| Action | File | Purpose |
|--------|------|---------|
| Create | `CLAUDE.md` (in handbook repo root) | Agent reading instructions |

#### Execute

##### Task 1: Write the CLAUDE.md (~15 min)
- **File**: `CLAUDE.md` (handbook repo root)
- **Content**:

```markdown
# Brite Handbook — Agent Instructions

This repo is the Brite company knowledge base. You are reading it because a project
CLAUDE.md @imported handbook content. Follow these rules when consuming handbook data.

## Directory Guide

| Directory | Contents | Refresh | Authority |
|-----------|----------|---------|-----------|
| `context/operational/` | Company profile, tech stack, brand, processes | Quarterly | Stable — treat as ground truth |
| `context/analytical/` | Business metrics, trends, customer data | Weekly | Dynamic — check freshness before relying |
| `decisions/` | Company Decision Records (CDRs) | As needed | Authoritative — CDRs override project-level preferences |
| `precedents/` | Promoted decision traces from project work | Continuous | Informational — precedents guide, they don't mandate |
| `org/` | Teams, roles, ownership, identity map | Quarterly | Reference — use for escalation and ownership questions |

## Reading Company Decisions (CDRs)

CDRs are org-wide decisions that apply to ALL Brite projects. They live in `decisions/`
with a manifest at `decisions/INDEX.md`.

**Before proposing architecture**: Read `decisions/INDEX.md`. Scan for CDRs in the
relevant category (tech-stack, process, policy, security, data, vendor). If your
proposed approach conflicts with an Active CDR, you MUST surface the conflict.

**CDR Statuses**:
- **Active** — Follow this decision. Do not contradict it without user approval.
- **Superseded** — Replaced by another CDR (check `Superseded by` field). Read the replacement.
- **Deprecated** — Being phased out. May still apply to existing code but don't use for new work.
- **Under Review** — Decision is being reconsidered. Don't depend on it — it may change.

**When you find a conflict**:
1. State the conflict explicitly: "This approach would conflict with CDR-NNN ([title])"
2. Quote the CDR's decision statement
3. Present options: (a) comply with CDR, (b) request CDR exception, (c) proceed with documented override
4. Do NOT silently ignore the conflict

**CDR Exceptions**: Some CDRs list exception conditions and required authority.
Check the Exceptions section before flagging a conflict — your case may already be covered.

## Reading Context Documents

Context docs have YAML frontmatter with freshness metadata:

```yaml
---
source: bigquery | salesforce | manual
last_refreshed: 2026-03-01
refresh_cadence: quarterly | monthly | weekly
---
```

**Freshness rules**:
- Compute staleness: `days_since_refresh / cadence_in_days`
- **Ratio ≤ 1.0**: Fresh. Use without comment.
- **Ratio 1.0–1.5**: Aging. Use normally but note in narration: "Note: [file] is approaching refresh date"
- **Ratio 1.5–2.0**: Stale. Warn: "Warning: [file] is overdue for refresh (last: [date], cadence: [cadence])"
- **Ratio > 2.0**: Very stale. Warn prominently: "⚠ [file] is significantly overdue. Verify critical data before relying on it."
- If frontmatter is missing: treat as `source: manual`, assume quarterly cadence, skip freshness check

**Cadence mapping**: quarterly = 90 days, monthly = 30 days, weekly = 7 days

## Reading Analytical Context (Metrics & Trends)

Analytical docs contain temporal data — not just current values, but trends and deltas:
- **↑ / ↓ / →**: Direction indicators show movement since last refresh
- **Delta percentages**: Show magnitude of change
- Use trends to inform recommendations: "ARR is trending ↑12% — this supports investing in [X]"
- Don't treat single-point values as ground truth — look at the trend

## Reading Org Structure

- `org/identity-map.md` — Maps people across systems: GitHub handle ↔ Linear user ↔ email ↔ Salesforce contact
- `org/ownership.md` — Maps code, systems, and domains to responsible people
- Use identity map when you need to correlate data across systems
- Use ownership map when you need to know who to ask or who to notify

## Reading Precedents

- `precedents/INDEX.md` — Searchable manifest of promoted decision traces
- Precedents are INFORMATIONAL, not prescriptive — they show what was done, not what must be done
- Search precedents during brainstorm/planning: "Has anyone solved a similar problem before?"
- If a precedent exists but you diverge from it, document WHY in your decision trace

## What NOT to Do

- Do NOT modify handbook content during regular project work — handbook changes go through PRs to this repo
- Do NOT treat analytical context as ground truth without checking freshness
- Do NOT silently ignore CDR conflicts — always surface them
- Do NOT treat precedents as mandates — they inform, they don't constrain
- Do NOT load the entire handbook into context — use INDEX files to find what's relevant, then read specific files
```

- **Pattern**: Follow the structure in `britenites-claude-plugins/CLAUDE.md` — specifically the table-based routing (like "Skill Routing") and the explicit do/don't rules
- **Verify**: File is under 120 lines. All directory names match M1-1. CDR statuses match PRD Section 5.2.

##### Edge Cases
- **Handbook has no content yet (only directories from M1-1)**: That's fine — the CLAUDE.md references future files. Agents encountering missing files should skip them gracefully.
- **Project doesn't @import handbook**: CLAUDE.md still exists for direct handbook repo work (maintenance, CDR creation).

##### Anti-Patterns
- Do NOT include project-specific instructions — this CLAUDE.md serves ALL projects, not any specific one
- Do NOT duplicate content from handbook files — reference them by path
- Do NOT make this longer than 120 lines — agents need to parse this quickly alongside other context
- Do NOT use vague freshness language ("check if it seems stale") — use specific numeric thresholds

##### Known Pitfalls (from past sessions)
- **Overly long CLAUDE.md**: The plugins CLAUDE.md is ~90 lines and works well. Aim for similar. Agents skip long instructions.
- **Rules that contradict later steps**: In BRI-1819, "Never suppress a P1" contradicted the validation step. Ensure the CDR conflict rules don't contradict the CDR exception rules — they should work together coherently.

#### Testing Scenarios

1. **Scenario**: An agent reads this CLAUDE.md and encounters `context/analytical/business-metrics.md` with `last_refreshed: 2026-01-15` and `refresh_cadence: weekly` on 2026-03-12
   **Expected**: Staleness ratio = 56/7 = 8.0 (>2.0). Agent warns: "⚠ business-metrics.md is significantly overdue."

2. **Scenario**: An agent proposes using MongoDB for a new service. CDR-001 mandates PostgreSQL via Supabase (Status: Active).
   **Expected**: Agent surfaces the conflict, quotes CDR-001's decision, presents 3 options (comply, exception, override). Does NOT silently proceed with MongoDB.

3. **Scenario**: An agent searches precedents during brainstorming and finds a relevant trace.
   **Expected**: Agent presents the precedent as informational context: "A similar problem was solved in [project] using [approach] (confidence: 8/10)." Does NOT mandate following it.

4. **Scenario**: Agent reads a context doc with no frontmatter.
   **Expected**: Assumes `source: manual`, quarterly cadence, skips freshness check. No error.

#### Definition of Done

- [ ] `CLAUDE.md` exists at handbook repo root
- [ ] File is under 120 lines
- [ ] Directory guide table references all 5 directories from M1-1 with correct names
- [ ] CDR status definitions match PRD: Active, Superseded, Deprecated, Under Review
- [ ] Freshness thresholds are numeric: 1.0 (fresh), 1.5 (stale warning), 2.0 (very stale)
- [ ] Cadence mapping defined: quarterly=90d, monthly=30d, weekly=7d
- [ ] CDR conflict handling is explicit: surface, don't override, 3 options
- [ ] "What NOT to Do" section has at least 5 rules
- [ ] At least 2 behavioral patterns shown (CDR conflict handling, freshness checking)
- [ ] No project-specific instructions (this serves all projects)

#### If Stuck

- If unsure about a freshness threshold: use the PRD values (1.5x soft, 2x hard). Don't overthink it.
- If CLAUDE.md exceeds 120 lines: cut the Org Structure and Precedents sections to 2 lines each — those are less critical than CDR and freshness rules.
- If handbook repo doesn't exist yet: M1-1 should have created it. If it wasn't done, create the repo first.

---

### M1-3: Define CDR format specification and INDEX.md manifest

**Priority**: High | **Size**: M | **Labels**: `handbook`, `foundation`

#### Goal

Establish the Company Decision Record (CDR) format — a structured document type for recording org-wide decisions (tech stack, process, policy, security, data, vendor). Create the INDEX.md manifest that agents lazy-load during planning to detect conflicts. CDRs are the org-level equivalent of project ADRs, with additional fields for exceptions, compliance enforcement, and category taxonomy.

#### System Context

```
writing-plans skill ──reads──→ decisions/INDEX.md ──lazy-loads──→ individual CDRs
                                     │
                                     │  INDEX.md is a lightweight manifest.
                                     │  Agents scan the INDEX, then fetch
                                     │  specific CDRs only when relevant.
                                     │
CDR-compliance-reviewer (M3-9) ──reads──→ individual CDRs
compound-learnings (M3-3) ──references──→ CDRs as parent context for decision traces
QMD search (M3-6) ──indexes──→ CDRs as parent docs (hierarchical context)
```

- **Downstream consumers**: writing-plans (conflict check via INDEX), CDR-compliance-reviewer agent (detailed checks), compound-learnings (references when promoting traces), QMD search (hierarchical indexing), M1-4 (seeds CDRs using this format)
- **Upstream dependencies**: M1-1 (directory structure — `decisions/` and `templates/` must exist)
- **Platform layer**: Knowledge Layer — the decision authority system

#### Background

- Milestone 1, Task 3 of 12
- Blocks M1-4 (Seed initial CDRs) — can't create CDRs without the format
- PRD reference: `docs/designs/brite-agent-platform.md` Section 5.2 (Company Decision Records)
- CDRs differ from ADRs in: scope (org-wide vs project), governance (higher authority), fields (exception tracking, compliance enforcement, category taxonomy), and consumption (INDEX-based lazy-loading, cross-repo @import)
- The existing ADR format (`plugins/workflows/commands/architecture-decision.md`) is the baseline that CDRs extend

#### Explore

1. **Read** `britenites-claude-plugins/plugins/workflows/commands/architecture-decision.md` — study the existing ADR format. CDRs extend this with: Exceptions, Compliance, Category, Author, Related CDRs. Note the template structure and field ordering.
2. **Read** `docs/designs/brite-agent-platform.md` Section 5.2 (lines ~220-260) — CDR requirements: statuses, governance, when they're created, how they relate to project ADRs
3. **Read** `docs/designs/brite-agent-platform.md` Section 5.5 (Decision Trace Architecture) — understand how CDRs serve as "parent context" for decision traces. QMD's hierarchical search indexes CDRs as parents of the traces that reference them.
4. **Research** ADR formats: adr.github.io (Nygard's original), Nat Pryce's adr-tools format, MADR (Markdown Any Decision Records) — understand field conventions across the ecosystem
5. **Key questions to answer before proceeding:**
   - What makes a decision CDR-worthy vs just a project ADR? (Answer: applies across ALL Brite projects, not just one)
   - How will INDEX.md be consumed? (Answer: `writing-plans` reads it with a simple grep to find CDRs in relevant categories, then reads specific CDR files if a potential conflict is detected)
   - What categories exist? (Answer: derived from the kinds of decisions Brite makes — tech-stack, process, policy, security, data, vendor at minimum)

#### Plan

##### Architecture

```
decisions/
├── INDEX.md              ← Manifest table: #, Title, Status, Category, Date, Summary
├── CDR-001-xxx.md        ← Individual CDR files (created by M1-4)
├── CDR-002-xxx.md
└── ...

templates/
└── CDR-TEMPLATE.md       ← Copy-paste template for new CDRs

docs/
└── cdr-format-spec.md    ← Formal spec document (for humans and agents writing CDRs)
```

Pattern to follow: The `architecture-decision.md` command generates ADRs with a consistent format. CDRs follow the same structural approach but add org-level fields.

##### Decisions Already Made (DO NOT reconsider)
- CDR fields include: Status, Context, Decision, Consequences, Exceptions (PRD Section 5.2)
- Status values: Active, Superseded, Deprecated, Under Review (PRD Section 5.2)
- CDRs live in `decisions/` directory in handbook repo (PRD Section 5)
- INDEX.md is a lightweight manifest — NOT the full CDR content (PRD Section 5.2)
- CDRs use numbered kebab-case filenames: `CDR-NNN-kebab-title.md` (following ADR convention)
- Three-digit zero-padded numbering starting at CDR-001

##### Open Decisions
- **Category taxonomy**: At minimum: `tech-stack`, `process`, `policy`, `security`, `data`, `vendor`. Recommendation: add `architecture` as a 7th category for high-level structural decisions (monolith vs microservices, API style, etc.) that don't fit neatly into `tech-stack`.
- **INDEX.md format**: Markdown table with pipe-delimited columns (grep-parseable AND GitHub-renderable). Recommendation: `| # | Title | Status | Category | Date | Summary |`
- **Exception format structure**: Recommendation: structured list with Condition, Authority, and Process fields (not freeform text).
- **Compliance enforcement levels**: Recommendation: define 4 levels: `automated` (CI/linter), `review` (code review checklist), `manual` (periodic audit), `convention` (documented, unenforced).

##### File Manifest
| Action | File | Purpose |
|--------|------|---------|
| Create | `docs/cdr-format-spec.md` | Formal specification of CDR format, fields, lifecycle, categories |
| Create | `templates/CDR-TEMPLATE.md` | Copy-paste template for creating new CDRs |
| Create | `decisions/INDEX.md` | Manifest table (initially empty, ready for M1-4 to populate) |

#### Execute

##### Task 1: Write CDR format specification (~10 min)
- **File**: `docs/cdr-format-spec.md` (in handbook repo)
- **Do**:
  1. Create the formal spec document
  2. Define every field with required/optional markers
  3. Define status lifecycle with valid transitions
  4. Define category taxonomy with descriptions
  5. Define exception and compliance formats
  6. Include examples of well-written field values
- **Content**:

```markdown
# CDR Format Specification

Company Decision Records (CDRs) document org-wide decisions that apply across all
Brite projects. CDRs are the org-level equivalent of project ADRs.

## When to Create a CDR

A CDR is needed when:
- A technology, vendor, or tool is chosen as a company standard
- A process or policy applies across all teams/projects
- A security or data handling requirement is established
- An architectural pattern is mandated org-wide

A CDR is NOT needed for:
- Project-specific decisions (use project ADRs)
- Temporary or experimental choices
- Individual preference (unless it becomes a standard)

## File Naming

`CDR-NNN-kebab-title.md` where NNN is zero-padded (001, 002, ...).
Title should be descriptive but concise: `CDR-001-postgresql-via-supabase.md`

## Required Fields

| Field | Format | Description |
|-------|--------|-------------|
| `Status` | Enum | Current status: Active, Superseded, Deprecated, Under Review |
| `Category` | Enum | Decision category (see taxonomy below) |
| `Date` | YYYY-MM-DD | Date the decision was made or recorded |
| `Author` | Name | Person who authored or championed this decision |
| Context | Markdown | What situation or need drove this decision |
| Decision | Markdown | The decision itself — clear, concise, actionable |
| Alternatives Considered | Markdown | At least 2 alternatives with pros/cons/rejection reason |
| Consequences | Markdown | Positive and negative consequences |
| Exceptions | Structured | When this decision can be overridden (see format below) |
| Compliance | Structured | How this decision is enforced (see format below) |

## Optional Fields

| Field | Format | Description |
|-------|--------|-------------|
| `Supersedes` | CDR-NNN | Which CDR this replaces (when Status is Active) |
| `Superseded by` | CDR-NNN | What replaced this CDR (when Status is Superseded) |
| `Related` | CDR-NNN list | Other CDRs that relate to this decision |

## Status Lifecycle

```
Under Review ──→ Active ──→ Superseded
                   │
                   └──→ Deprecated
```

- **Under Review → Active**: Decision is approved and in effect
- **Active → Superseded**: A new CDR replaces this one (set `Superseded by` field)
- **Active → Deprecated**: Decision is being phased out (no replacement yet)
- Invalid transitions: Superseded → Active (create a new CDR instead), Deprecated → Active (create a new CDR)

## Category Taxonomy

| Category | Description | Examples |
|----------|-------------|---------|
| `tech-stack` | Technology, framework, or language choices | PostgreSQL, TypeScript, Next.js |
| `architecture` | High-level structural decisions | Monolith vs microservices, API style |
| `process` | Team workflows and practices | Git branching, code review, deployment |
| `policy` | Organizational rules and standards | Naming conventions, documentation requirements |
| `security` | Security and access control decisions | Auth method, secrets management, PII handling |
| `data` | Data storage, processing, and privacy | Data retention, backup strategy, analytics |
| `vendor` | Third-party tool and service selections | Supabase, Vercel, Linear, Figma |

## Exception Format

```markdown
## Exceptions

- **Condition**: [When this exception applies]
  **Authority**: [Who can grant — e.g., "Engineering Lead", "CTO"]
  **Process**: [How to request — e.g., "Comment on CDR PR with justification"]

- **Condition**: [Another exception case]
  **Authority**: [Who can grant]
  **Process**: [How to request]

If no exceptions: "No exceptions. This decision applies universally."
```

## Compliance Format

```markdown
## Compliance

**Enforcement**: [automated | review | manual | convention]
**Mechanism**: [Specific tool or process — e.g., "ESLint rule `no-any`", "PR review checklist item #3"]
**Audit frequency**: [How often compliance is checked — e.g., "Every PR", "Quarterly audit"]
```

Enforcement levels:
- `automated` — CI check, linter rule, pre-commit hook (strongest)
- `review` — Code review checklist item (requires reviewer attention)
- `manual` — Periodic audit (weakest active enforcement)
- `convention` — Documented standard, no active enforcement (weakest)

## INDEX.md Format

The INDEX is a markdown table manifest. It must be:
1. Renderable on GitHub as a clean table
2. Parseable by grep/awk for automated conflict checking
3. Sorted by CDR number

```markdown
| # | Title | Status | Category | Date | Summary |
|---|-------|--------|----------|------|---------|
| CDR-001 | PostgreSQL via Supabase | Active | tech-stack | 2026-03-12 | All databases use PostgreSQL via Supabase |
```
```

- **Pattern**: Follow the structure of `britenites-claude-plugins/docs/workflow-spec.md` — machine-parseable, table-heavy, with clear field definitions
- **Verify**: Spec covers all fields from the PRD. Status lifecycle has no invalid paths. Category taxonomy has 7 categories.

##### Task 2: Create CDR template (~5 min)
- **File**: `templates/CDR-TEMPLATE.md` (in handbook repo)
- **Content**:

```markdown
# CDR-NNN. [Decision Title]

**Status:** [Active | Superseded | Deprecated | Under Review]
**Category:** [tech-stack | architecture | process | policy | security | data | vendor]
**Date:** YYYY-MM-DD
**Author:** [Name]
**Supersedes:** [CDR-NNN if applicable, otherwise remove this line]
**Superseded by:** [CDR-NNN if applicable, otherwise remove this line]
**Related:** [CDR-NNN, CDR-NNN if applicable, otherwise remove this line]

## Context

[What situation, need, or problem drove this decision? What constraints exist?
Include the business context, not just the technical one. 2-4 paragraphs.]

## Decision

[The decision itself, stated clearly and concisely. Must be actionable —
a developer reading this should know exactly what to do. One paragraph maximum.]

## Alternatives Considered

### [Alternative 1 — the chosen approach]

[Brief description]

- **Pros**: [List]
- **Cons**: [List]

### [Alternative 2]

[Brief description]

- **Pros**: [List]
- **Cons**: [List]
- **Why not**: [Specific reason this was rejected]

### [Alternative 3]

[Brief description]

- **Pros**: [List]
- **Cons**: [List]
- **Why not**: [Specific reason this was rejected]

## Consequences

### Positive

- [What this enables or improves]
- [Another benefit]

### Negative

- [What tradeoffs were accepted]
- [Another cost]

## Exceptions

- **Condition**: [When this exception applies]
  **Authority**: [Who can grant the exception]
  **Process**: [How to request the exception]

[Or: "No exceptions. This decision applies universally."]

## Compliance

**Enforcement**: [automated | review | manual | convention]
**Mechanism**: [Specific tool, rule, or process]
**Audit frequency**: [How often compliance is checked]
```

- **Verify**: Template contains all required fields from the spec. Copy-paste it, fill it in — it should produce a valid CDR.

##### Task 3: Create INDEX.md manifest (~3 min)
- **File**: `decisions/INDEX.md` (in handbook repo)
- **Content**:

```markdown
# Company Decision Records — INDEX

Manifest of all Company Decision Records. Agents read this during planning to check
for conflicts before proposing new architecture.

**How agents use this INDEX:**
1. Read the table below during `writing-plans`
2. Filter by Category relevant to the current task
3. If a proposed approach might conflict with an Active CDR, read the full CDR file
4. Surface any conflicts to the user (see CLAUDE.md for conflict handling rules)

**How humans use this INDEX:**
- Scan to find existing decisions before proposing new ones
- Check for Superseded/Deprecated decisions that may affect your work

| # | Title | Status | Category | Date | Summary |
|---|-------|--------|----------|------|---------|
<!-- CDR entries will be added by M1-4 (Seed initial CDRs) -->
```

- **Verify**: Table renders correctly on GitHub. Headers match the spec exactly.

##### Edge Cases
- **Someone creates a CDR without updating INDEX**: The spec should note that INDEX updates are mandatory. But the system should also handle this gracefully — a CDR not in the INDEX is invisible to automated checks but still valid as a document.
- **Category doesn't fit the taxonomy**: Use the closest match. If truly novel, add a new category to the taxonomy (via PR to the spec).
- **Two CDRs conflict with each other**: The newer CDR should Supersede the older one. If both should remain Active, they're not actually conflicting — they cover different scopes.

##### Anti-Patterns
- Do NOT put full CDR content in INDEX.md — it's a manifest for quick scanning, not a database. Each row should have a one-line summary only.
- Do NOT use JSON or YAML for INDEX — it must render as a readable table on GitHub AND be parseable by grep.
- Do NOT create actual CDRs — that's M1-4. This issue creates the FORMAT and TEMPLATE only.
- Do NOT skip the spec document — without a formal spec, CDRs will drift in format over time.
- Do NOT invent categories that don't have at least one real CDR to fill them. The 7 categories above all have real Brite decisions.

##### Known Pitfalls (from past sessions)
- **Shared format files drift from implementations**: In BRI-1818, `output-formats.md` had drifted from agent implementations. The CDR spec is the single source of truth — M1-4 (seed CDRs) must follow it exactly, and any format changes must update the spec first.
- **Substring matching issues**: If `writing-plans` uses grep to scan INDEX for conflicts, ensure Category values don't have substring overlap (e.g., `data` is a substring of `data-engineering`). The 7 categories above are distinct.

#### Testing Scenarios

1. **Scenario**: Copy `CDR-TEMPLATE.md`, fill in all fields for a hypothetical decision, save as `CDR-999-test-decision.md`
   **Expected**: Valid CDR with all required fields populated. No empty sections. Reads naturally.

2. **Scenario**: Run `grep "Active" decisions/INDEX.md` on a populated INDEX (after M1-4)
   **Expected**: Returns only Active CDR rows, cleanly formatted with pipe delimiters.

3. **Scenario**: Run `grep "tech-stack" decisions/INDEX.md`
   **Expected**: Returns only tech-stack category CDRs. No false matches from other columns.

4. **Scenario**: Read the format spec as an agent about to create a new CDR
   **Expected**: Spec provides enough detail to create a valid CDR without any additional guidance. All fields are defined, all enums are listed, examples are provided.

5. **Scenario**: An agent encounters a CDR with Status "Superseded"
   **Expected**: Agent follows the `Superseded by` field to the replacement CDR. Does not treat the superseded CDR as authoritative.

#### Definition of Done

- [ ] `docs/cdr-format-spec.md` exists with complete field definitions, status lifecycle, and category taxonomy
- [ ] `templates/CDR-TEMPLATE.md` exists and is copy-paste-ready (all fields, inline guidance)
- [ ] `decisions/INDEX.md` exists with correct table headers and usage instructions
- [ ] CDR format is a documented superset of project ADRs (adds: Exceptions, Compliance, Category, Author, Related)
- [ ] Status lifecycle has valid transitions documented (including what's invalid)
- [ ] Category taxonomy has 7 categories: tech-stack, architecture, process, policy, security, data, vendor
- [ ] Exception format is structured (Condition + Authority + Process), not freeform
- [ ] Compliance format has 4 enforcement levels: automated, review, manual, convention
- [ ] INDEX.md table is grep-parseable (consistent pipe-delimited columns)
- [ ] Spec is detailed enough for an agent to create a CDR without additional guidance
- [ ] No actual CDRs created (that's M1-4)

#### If Stuck

- If unsure about a category name: check if existing Brite decisions would fit. Every category should have at least 2 real CDRs.
- If the spec is getting too long: cap at 150 lines. Move examples to an appendix or separate file.
- If INDEX format debates arise: go with the simplest format that's both GitHub-renderable and grep-parseable. Markdown tables are the standard.

---

> **Note**: The remaining issues (M1-4 through M1-11b, M2-1 through M2-13, M3-1 through M3-11, and M4-M8) will be written at this same detail level once the template is approved. The 3 issues above (M1-1, M1-2, M1-3) are representative examples of the enhanced format.

---

## Cleanup Actions

Before creating new milestones, resolve these existing issues:

| Action | Issue | Details |
|--------|-------|---------|
| **Close** | BRI-1337 | "Improve project-start with framework templates" — superseded by M2 (Project-Start Redesign). Comment: "Superseded by Brite Agent Platform epic. Framework templates → trait-based classification + domain plugin context-skills." |
| **Move → M4** | BRI-1724 | Scaffold marketing plugin structure |
| **Move → M4** | BRI-1725 | Port 32 marketing skills to plugin format |
| **Move → M4** | BRI-1726 | Port marketing CLI tools and integration guides |
| **Move → M4** | BRI-1727 | Create Brite product-marketing-context skill |
| **Move → M4** | BRI-1728 | Update CI and docs for marketing plugin |
| **Move → M5** | BRI-1343 | Create API design skill → Engineering plugin |
| **Move → M5** | BRI-1347 | Enhance frontend-design with design tokens → Design plugin |
| **Move → M7** | BRI-1352 | Create onboarding agent → Symphony |
| **Move → M8** | BRI-1782 | Behavioral test framework → Governance |

---

## Dependency Graph

```
M1-1 (Handbook structure)
├── M1-2 (Handbook CLAUDE.md)
├── M1-3 (CDR format) ──→ M1-4 (Seed CDRs)
├── M1-5 (Operational context)
├── M1-6 (Org structure)
├── M1-7 (Metric definitions) ──→ M1-8 (GitHub Action v1)
├── M1-9 (Freshness tracking) ── depends on M1-2
├── M1-10 (CDR-check in plans) ── depends on M1-3, M1-4
└── M1-11a (Cross-repo research) ──→ M1-11b (Cross-repo implement)

M2-1 (Trait classification) ── depends on M1 complete
├── M2-2 (Interview rewrite) ── depends on M2-1
├── M2-3 (Doc scaffolding) ── depends on M2-1
├── M2-4 (Dynamic @imports) ── depends on M1-11b, M2-1
├── M2-5 (GitHub repo) ── depends on M2-1
├── M2-6 (Plugin discovery) ── depends on M2-1
├── M2-7 (Remove premature gen) ── standalone
├── M2-8 (MCP verification) ── depends on M2-1
├── M2-9 (Express mode) ── depends on M2-1
├── M2-10 (Brownfield) ── depends on M2-1, M2-9
├── M2-11 (Post-setup verify) ── standalone
├── M2-12 (Docs update) ── depends on M2-1 through M2-11
└── M2-13 (Validation + CI) ── depends on M2-12

M3-1 (Trace format)
├── M3-2 (Trace emission) ── depends on M3-1
├── M3-3 (Compound extraction) ── depends on M3-1, M3-2
├── M3-4 (Promotion workflow) ── depends on M3-3
├── M3-5 (Precedent INDEX) ── depends on M3-1
├── M3-6 (QMD evaluation) ── standalone research spike
├── M3-7 (Precedent search skill) ── depends on M3-5, M3-6
├── M3-8 (Memory instrumentation) ── depends on M3-1
├── M3-9 (CDR compliance agent) ── depends on M1-4
├── M3-10 (Context audit trail) ── depends on M3-8
└── M3-11 (Flywheel metrics) ── depends on M3-2, M3-7

M4-1 (Context-skill standard) ── depends on M2 complete
├── M4-2–M4-6 (Marketing plugin) ── existing BRI-1724-1728
└── M4-7 (Plugin discovery) ── depends on M2-6, M4-1

M5-1 through M5-4 ── each depends on M4-1

M6-1 through M6-6 ── depends on M1 (handbook structure)

M7-1 through M7-12 ── depends on M1-M5

M8-1 through M8-4 ── depends on M1-M3
```

---

## Summary Table

| Issue | Title | Milestone | Priority | Size | Repo |
|-------|-------|-----------|----------|------|------|
| M1-1 | Restructure handbook repo directory layout | 1 | High | S | handbook |
| M1-2 | Write handbook CLAUDE.md for agent consumption | 1 | High | M | handbook |
| M1-3 | Define CDR format specification and INDEX.md | 1 | High | M | handbook |
| M1-4 | Seed initial CDRs from existing conventions | 1 | Medium | L | handbook |
| M1-5 | Write operational context documents | 1 | Medium | M | handbook |
| M1-6 | Create org structure documents | 1 | Low | M | handbook |
| M1-7 | Create analytical context scaffold | 1 | Medium | S | handbook |
| M1-8 | Build context refresh GitHub Action (v1) | 1 | Medium | L | handbook |
| M1-9 | Implement freshness tracking in session-start | 1 | Medium | M | plugins |
| M1-10 | Add CDR-check pattern to writing-plans | 1 | Medium | M | plugins |
| M1-11a | Research cross-repo @import solutions | 1 | Urgent | M | plugins |
| M1-11b | Implement chosen cross-repo @import solution | 1 | High | M | plugins |
| M2-1 | Implement trait-based classification system | 2 | High | L | plugins |
| M2-2 | Rewrite interview with JTBD + MI + SPIN | 2 | High | XL | plugins |
| M2-3 | Implement trait-conditional doc scaffolding | 2 | Medium | M | plugins |
| M2-4 | Implement CLAUDE.md with dynamic @imports | 2 | High | M | plugins |
| M2-5 | Implement GitHub repo creation | 2 | Medium | S | plugins |
| M2-6 | Implement plugin discovery and activation | 2 | Medium | M | plugins |
| M2-7 | Remove premature plan + ADR generation | 2 | Medium | S | plugins |
| M2-8 | Implement dynamic MCP verification | 2 | Medium | S | plugins |
| M2-9 | Implement express mode | 2 | Medium | M | plugins |
| M2-10 | Implement brownfield support | 2 | Low | M | plugins |
| M2-11 | Implement post-setup verification | 2 | Medium | S | plugins |
| M2-12 | Update workflow-spec, guide, testing docs | 2 | Medium | M | plugins |
| M2-13 | Update validate.sh and CI | 2 | Medium | S | plugins |
| M3-1 | Define decision trace format specification | 3 | High | M | plugins |
| M3-2 | Implement trace emission in executing-plans | 3 | High | M | plugins |
| M3-3 | Update compound-learnings for trace extraction | 3 | High | M | plugins |
| M3-4 | Implement precedent promotion workflow | 3 | Medium | M | plugins |
| M3-5 | Define precedent INDEX format | 3 | Medium | S | plugins |
| M3-6 | Evaluate QMD for precedent search | 3 | High | L | plugins |
| M3-7 | Build precedent-search skill | 3 | Medium | M | plugins |
| M3-8 | Implement agent memory instrumentation | 3 | Medium | M | plugins |
| M3-9 | Build CDR compliance review agent | 3 | Medium | M | plugins |
| M3-10 | Implement context audit trail | 3 | Low | S | plugins |
| M3-11 | Implement flywheel metrics | 3 | Low | M | plugins |
| M4-1 | Define context-skill standard specification | 4 | High | M | plugins |
| M4-2 | Scaffold marketing plugin (BRI-1724) | 4 | High | M | plugins |
| M4-3 | Port marketing skills (BRI-1725) | 4 | High | L | plugins |
| M4-4 | Port marketing CLI tools (BRI-1726) | 4 | Medium | L | plugins |
| M4-5 | Create marketing context skill (BRI-1727) | 4 | Medium | M | plugins |
| M4-6 | Update CI for multi-plugin (BRI-1728) | 4 | Medium | M | plugins |
| M4-7 | Implement plugin discovery in project-start | 4 | Medium | M | plugins |
| M5-1 | Create engineering domain plugin | 5 | Medium | L | plugins |
| M5-2 | Create design domain plugin | 5 | Medium | L | plugins |
| M5-3 | Create sales domain plugin | 5 | Low | M | plugins |
| M5-4 | Create product domain plugin | 5 | Low | M | plugins |
| M5-5 | Migrate API design skill (BRI-1343) | 5 | Medium | S | plugins |
| M5-6 | Migrate design tokens (BRI-1347) | 5 | Medium | S | plugins |
| M6-1 | Evaluate Salesforce MCP options | 6 | Medium | M | research |
| M6-2 | Build Salesforce → customers.md pipeline | 6 | Medium | L | handbook |
| M6-3 | Enhance BigQuery → business-metrics.md (v2) | 6 | Medium | M | handbook |
| M6-4 | Implement temporal diff computation library | 6 | Medium | M | handbook |
| M6-5 | Build refresh PR workflow | 6 | Medium | M | handbook |
| M6-6 | Implement PII handling | 6 | High | M | handbook |
| M7-1 | Evaluate Symphony runtime approach | 7 | High | L | research |
| M7-2 | Define WORKFLOW.md standard | 7 | High | M | plugins |
| M7-3 | Implement Poll-Dispatch-Resolve-Land daemon | 7 | High | XL | new repo |
| M7-4 | Integrate Brite review agents | 7 | Medium | M | plugins |
| M7-5 | Implement workpad pattern | 7 | Medium | M | plugins |
| M7-6 | Add custom Linear states | 7 | Medium | S | Linear |
| M7-7 | Build proof of work system | 7 | Medium | L | plugins |
| M7-8 | Decision trace emission in autonomous mode | 7 | Medium | S | plugins |
| M7-9 | Implement concurrency management | 7 | Medium | L | new repo |
| M7-10 | Implement cost management | 7 | Medium | M | new repo |
| M7-11 | Implement failure mode handling | 7 | High | M | new repo |
| M7-12 | Integrate compound-learnings autonomous | 7 | Medium | M | plugins |
| M8-1 | Define CDR governance model | 8 | Medium | M | handbook |
| M8-2 | Build context quality dashboard | 8 | Medium | L | TBD |
| M8-3 | Implement flywheel monitoring | 8 | Low | M | plugins |
| M8-4 | Build context governance review agent | 8 | Low | M | plugins |
