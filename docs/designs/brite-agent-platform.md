# Brite Agent Platform — Design Document

**Status:** Superseded (2026-05-27) — see `docs/history/prd-m5-m8-archive.md`
**Author:** Holden Halford + Claude
**Date:** 2026-03-12
**Supersedes:** BRI-1337 (Improve project-start with framework templates)
**Superseded by:** 4-layer architecture re-org (Layer A Orchestration / Layer B Runtime / Layer C Skill Packs / Layer D Knowledge). PRD M5-M8 milestones were cancelled 2026-05-27. M1-M4 outcomes delivered as Linear milestones whose naming expanded beyond this doc's canonical M-numbering (both PRD-canonical names and operational labels coexist in the Linear historical-milestone list — see `docs/history/prd-m5-m8-archive.md` for detail). The Linear projects "Brite Skill Packs" (Layer C, renamed from "Brite Skill Packs"), "Brite Orchestration Layer", "Brite Knowledge Layer", and "Brite Runtime & Harness" replace the original 8-milestone single-project framing. Sections below remain as historical context.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Origin & Evolution](#2-origin--evolution)
3. [Research Foundation](#3-research-foundation)
4. [Platform Architecture](#4-platform-architecture)
5. [Knowledge Architecture](#5-knowledge-architecture)
   - The Problem
   - The Solution: Handbook as Company Brain
   - Handbook Repo Structure
   - Two-Layer Context Model (operational vs analytical)
   - Temporal Context
   - Operational Context Foundation (identity, ownership)
   - Materialized Context Pattern
   - Company Decision Records (CDRs)
   - Decision Trace Architecture
   - Precedent Database
   - Agent Memory Instrumentation
   - Context Governance
   - The Context Flywheel
   - Context Loading Cascade
   - Updated Full-Loop Flow Diagram
6. [Layer 1: Project-Start Redesign](#6-layer-1-project-start-redesign)
7. [Layer 2: Domain Plugin Ecosystem](#7-layer-2-domain-plugin-ecosystem)
8. [Layer 3: Workflows Plugin](#8-layer-3-workflows-plugin)
9. [Layer 4: Symphony Autonomous Execution](#9-layer-4-symphony-autonomous-execution)
10. [End-to-End Scenarios](#10-end-to-end-scenarios)
11. [Epic Structure & Milestones](#11-epic-structure--milestones) (8 milestones)
12. [Open Questions](#12-open-questions) (28 questions across 6 categories)
13. [Appendix A: Reference Implementations](#appendix-a-reference-implementations) (incl. Context Graphs sources)
14. [Appendix B: Interview Methodology Sources](#appendix-b-interview-methodology-sources)
15. [Appendix C: 50 Project Scenarios](#appendix-c-50-project-scenarios)
16. [Appendix D: Agency-Agents Taxonomy](#appendix-d-agency-agents-taxonomy)

---

## 1. Executive Summary

Transform Brite's `/workflows:project-start` from a code-project setup wizard into a **universal project router** that works for ANY kind of work — software, marketing campaigns, hiring plans, conference talks, vendor evaluations, brand redesigns, ML pipelines, and more.

The core insight: project-start isn't "set up a codebase." It's the front door to a platform where **structured discovery routes work to the right domain plugins**, and autonomous agents execute from a Linear board while teams manage outcomes.

**What this means concretely:**

1. A **structured interview** (JTBD + Motivational Interviewing + SPIN composite) replaces the current binary "technical/non-technical" question
2. **Trait-based classification** replaces fixed project archetypes — projects have traits like `produces-code`, `needs-marketing`, `requires-decisions` that combine freely
3. **Domain plugins** (Marketing, Engineering, Design, Sales, Product) activate based on detected traits, each with a foundational context-skill that creates project-specific domain knowledge
4. The **company handbook** becomes the organizational knowledge layer — with Company Decision Records (CDRs), materialized context from SoRs (Salesforce, BigQuery), and structured @imports into project CLAUDE.md files
5. A **decision trace architecture** (inspired by Foundation Capital's Context Graphs thesis) captures not just WHAT agents decide, but WHY — building a searchable precedent database that makes every future decision better
6. **Symphony-style autonomous execution** lets teams manage work on Linear while agents execute in isolated workspaces, with Brite's review agents as quality gates

---

## 2. Origin & Evolution

### Starting Point: BRI-1337

The original issue was narrow: "add 4 framework templates to project-start" (Next.js, FastAPI, Data pipeline, Shopify theme). During brainstorming, three problems emerged:

1. **Fixed templates don't compose** — a project that's "Next.js + marketing site + needs accessibility" can't be captured by picking one template
2. **Project-start only handles code** — but Brite works on marketing campaigns, hiring plans, process improvements, and strategic decisions that also need structured kickoff
3. **No connection to company knowledge** — project-start creates a project in isolation, with no awareness of company decisions, customer context, or organizational constraints

### Key Pivots

**Pivot 1: Templates → Convention Specs → Traits**
"Even the fact you're recommending something as specific as a 'shopify theme' makes me think this is a bad idea." Fixed templates were replaced with convention specifications, which evolved into trait-based classification — a composable system where any combination of traits produces the right setup.

**Pivot 2: Code Projects → All Projects**
"I'm imagining Project Start as being something that's used for both coding projects and also non-coding projects." The interview was redesigned for universal applicability — a hiring plan and a CLI tool both go through the same discovery process, with different traits activating different plugins.

**Pivot 3: Isolated Projects → Platform with Company Knowledge**
"We are trying to keep all of our business context between a handful of systems of record." Projects shouldn't start from zero — they should inherit company context, respect existing decisions, and connect to live business data.

**Pivot 4: Interactive Only → Autonomous Execution**
OpenAI Symphony's model showed how teams can manage work on Linear while agents execute autonomously. This became Layer 4 of the platform.

**Pivot 5: Static Knowledge → Context Flywheel**
Foundation Capital's Context Graphs thesis revealed that capturing decision traces (the WHY behind decisions, not just the WHAT) creates a compounding knowledge asset. Every agent execution should emit structured reasoning traces that become searchable precedent for future agents. The platform becomes smarter with every task it completes.

---

## 3. Research Foundation

### Landscape Scan

| Source | Stars | Agents | Selection | Key Takeaway |
|--------|-------|--------|-----------|-------------|
| **Superpowers** | 78k | — | — | No project-start. Workflow discipline only. Brainstorming is the entry point. Validates: don't over-engineer setup, let discovery drive. |
| **Compound Engineering** | 10.3k | — | — | Lightweight setup. Knowledge compounds via `docs/solutions/`. `learnings-researcher` agent retrieves past solutions. Validates: compound knowledge pattern. |
| **agency-agents** (msitarzewski) | — | 120+ | Division-based | 12 business divisions (engineering, design, marketing, paid media, sales, product, PM, testing, support, spatial computing, game dev, specialized). NEXUS 7-phase orchestration. Validates: division/domain taxonomy for agents. |
| **marketingskills** (coreyhaines31) | — | 32 skills | — | **Context-skill pattern**: `product-marketing-context` creates foundational context all others read. 68 CLI tools. Validates: context-skill as plugin standard. |
| **OpenAI Symphony** | — | Daemon | Linear-driven | Poll-Dispatch-Resolve-Land cycle. WORKFLOW.md as contract. Harness engineering: 3-7 engineers, ~1M LOC, ~1,500 PRs. Teams manage work, not agents. Validates: autonomous execution from project management tool. |
| **AGENTS.md** | 60k+ repos | — | — | Universal cross-tool standard. Linux Foundation. Validates: standardized agent configuration is emerging. |
| **Anthropic `code-review`** | Official | 4 | Static | 9-step pipeline, model tiering, aggressive false-positive filtering. Validates: our review agent architecture. |
| **Anthropic `pr-review-toolkit`** | Official | 6 | Opt-in | comment-analyzer, test-analyzer, silent-failure-hunter, type-design, code-reviewer, simplifier. Validates: specialized review agents. |
| **Compound Engineering** | 10.3k | 15 | Dynamic (setup skill) | Stack defaults + config file, `compound-engineering.local.md`. Validates: project-level config for agent selection. |
| **HAMY (community)** | — | 9 | Static | Most comprehensive, ~75% useful rate. Includes dependency/deployment safety. |
| **Qodo PR-Agent** | — | 15+ | Dynamic (orchestrator) | Judge agent for dedup, recommendation agent with PR history. |
| **CodeRabbit** | — | Multi-dim | Profile-based | 40 integrated static analyzers, "Chill" vs "Assertive" modes. |
| **claude-review-loop** | — | 4 | Conditional | Project-type file detection (Next.js config → Next.js agent). |
| **Foundation Capital — Context Graphs** | — | — | — | Next trillion-dollar opportunity: systems that capture *decision traces* (why decisions were made), not just current state. Orchestration layers have structural advantage — they witness full decision context at execution time. Three startup paths: full replacement, module replacement, new systems of record. |
| **Metadata Weekly — Context Graph Response** | — | — | — | Counters Foundation Capital: *integrators* beat vertical agents because context is global (spans Salesforce + Zendesk + Slack + Snowflake). Distinguishes operational context (SOPs, identity) from analytical context (metric definitions). Customer-owned context platforms beat vendor-locked silos. Six requirements: cross-system connectivity, operational context synthesis, analytical context management, inference-time delivery, feedback loops, governance. |
| **Graphlit — Context Layer for Agents** | — | — | — | Two-layer architecture: operational context foundation (identity resolution, ownership mapping, temporal state) underneath decision context layer (policy versions, exceptions, precedent). MCP for agent interoperability. Schema.org/JSON-LD for entity modeling. Key insight: RAG fails because it treats knowledge as documents to embed, not as a temporal relational graph. |
| **QMD** (tobi/Shopify) | — | — | MCP server | On-device search engine: BM25 + vector semantic search + LLM re-ranking. All local (node-llama-cpp, GGUF models, SQLite). MCP server for Claude Code integration. Hierarchical context (parent-child document relationships). Potential search backbone for our precedent database — indexes markdown, supports hybrid query expansion. **Research task: evaluate for precedent search.** |
| **"Anatomy of an Agent Harness"** (LangChain / Trivedy) | — | — | Framework | Agent = Model + Harness. Harness = everything that isn't the model (prompts, tools, MCPs, orchestration, hooks, infrastructure). Derives harness features from desired behavior: filesystems for durable state, bash for general-purpose execution, sandboxes for safety, memory/search for continual learning, compaction/progressive-disclosure for context rot, Ralph Loops for long-horizon continuation. Future: agents analyzing their own traces to fix harness failures, dynamic JIT context assembly. Our plugin system IS a harness. |

### Key Findings

1. **Industry standard is 6-15 agents with dynamic selection** — our current 9 review agents with tiered selection is well-positioned
2. **Every successful implementation uses parallel dispatch** — already implemented in `/workflows:review`
3. **Confidence scoring is the primary false-positive reduction mechanism** — implemented in BRI-1816
4. **Stack-specific agents are universally conditional** — implemented in BRI-1627 (Tier 2/3 selection)
5. **Context-skill pattern is the standard for multi-domain plugins** — foundational context created once, read by all skills
6. **Best tools auto-detect first, ask minimally, accumulate knowledge organically** — this should inform project-start's interview design
7. **Autonomous execution requires harness engineering** — engineers design environments and review boundaries, agents write code
8. **Context graphs capture decision traces, not just state** — the next generation of enterprise platforms will be built by those who capture the reasoning behind decisions, not just the outcomes (Foundation Capital thesis)
9. **Orchestration layers have structural advantage for context capture** — whoever sits in the execution path witnesses full decision context and can persist it as searchable precedent
10. **Integrators beat vertical agents in heterogeneous environments** — context is global (spans many systems), not local to one workflow. The universal context layer wins over siloed agents.
11. **Operational and analytical context are distinct layers** — operational context (SOPs, identity, ownership) is foundational; analytical context (metric definitions, calculations) sits on top. Both are needed.

### Interview Methodology Research

Nine methodologies were evaluated for AI-driven project discovery:

| Methodology | Strength | Weakness for AI |
|-------------|----------|-----------------|
| **Jobs-to-Be-Done (JTBD)** | Reveals true motivation via trigger/forces | Requires follow-up skill to probe forces |
| **Motivational Interviewing (MI)** | OARS framework (Open questions, Affirmations, Reflective listening, Summaries) builds trust | Reflection is hard for AI to get right |
| **SPIN Selling** | Situation→Problem→Implication→Need-payoff reveals priority naturally | "Selling" framing may feel manipulative |
| **Design Thinking** | Story-based ("Walk me through...") extracts rich context | Open-ended, hard to scope |
| **Impact Mapping** | Goal→Actors→Impacts→Deliverables gives structure | Assumes clear goals upfront |
| **Story Mapping** | "What happens first? Then what?" maps user journeys | Only works for user-facing products |
| **Lean Canvas** | Forces focus: "Top 3 problems. Rank them." | Too structured for early discovery |
| **Five Whys** | Drills from solution to root cause | Can feel interrogative |
| **Appreciative Inquiry** | "What's working today?" preserves existing value | Doesn't work for greenfield |

**Conclusion:** No single methodology works alone. The composite approach uses each methodology's strength at the right phase of discovery.

---

## 4. Platform Architecture

### Four-Layer Model

```
┌──────────────────────────────────────────────────────────────────┐
│  Layer 1: PROJECT-START (Discovery + Routing)                     │
│                                                                   │
│  Structured interview (JTBD + MI + SPIN)                          │
│  → Trait-based classification                                     │
│  → Plugin discovery + MCP verification                            │
│  → Infrastructure setup (CLAUDE.md, docs, Linear, GitHub)         │
│  → Domain context-skill activation                                │
└───────────────────────────┬──────────────────────────────────────┘
                            │ activates
         ┌──────────────────┼──────────────────────┐
         ↓                  ↓                      ↓
  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐
  │ Engineering  │  │  Marketing   │  │  Design / Sales  │  ... more
  │   Plugin     │  │   Plugin     │  │  / Product / PM  │
  │              │  │              │  │                   │
  │ context:     │  │ context:     │  │ context:          │
  │ stack, arch, │  │ ICP, voice,  │  │ brand, tokens,    │
  │ conventions  │  │ competitors  │  │ accessibility     │
  │              │  │              │  │                   │
  │ skills +     │  │ 32 skills +  │  │ skills + agents   │
  │ agents       │  │ 68 tools     │  │                   │
  └─────────────┘  └──────────────┘  └──────────────────┘
         ↑                  ↑                      ↑
  Layer 2: DOMAIN PLUGINS (Specialized Knowledge)
         │                  │                      │
  ┌──────┴──────────────────┴──────────────────────┴───────────────┐
  │  Layer 3: WORKFLOWS PLUGIN (Process Orchestration)              │
  │                                                                 │
  │  brainstorm → plan → execute → review → ship                    │
  │  (domain-agnostic inner loop)                                   │
  │  Multi-agent review (9 agents, tiered, confidence scoring)      │
  │  Compound knowledge (learnings → CLAUDE.md + docs)              │
  │  Verification gates                                             │
  └─────────────────────────┬──────────────────────────────────────┘
                            │ autonomous execution
  ┌─────────────────────────┴──────────────────────────────────────┐
  │  Layer 4: SYMPHONY-STYLE DAEMON (Autonomous Execution)          │
  │                                                                 │
  │  Polls Linear → dispatches agents → isolated workspaces         │
  │  Proof of work: CI, PR review, workpad, videos                  │
  │  Human review at PR boundaries                                  │
  │  Brite review agents as quality gates                           │
  │  Teams manage Linear board, not agent sessions                  │
  └────────────────────────────────────────────────────────────────┘
```

### How the Layers Interact

1. **Project-start** creates the harness: CLAUDE.md, domain contexts, Linear project, GitHub repo, tool configuration
2. **Domain plugins** provide specialized knowledge for each business function
3. **Workflows plugin** orchestrates the process (brainstorm → ship) — works interactively OR feeds the daemon
4. **Symphony daemon** executes issues autonomously from the Linear board, using domain plugin skills and workflows process

The **Linear board** is the control plane. Humans create issues, prioritize, and review outcomes. Agents execute.

### Layer Interaction: Concrete Example

A marketing site project flows like this:

1. **Project-start** interviews → detects `produces-code` + `needs-design` + `needs-marketing` + `has-external-users` → activates Engineering + Design + Marketing plugins → creates CLAUDE.md with @imports → creates GitHub repo + Linear project
2. **Engineering plugin** context-skill writes `docs/engineering-context.md` (stack: Next.js, Vercel, Supabase)
3. **Design plugin** context-skill writes `docs/design-context.md` (brand tokens, palette, typography)
4. **Marketing plugin** context-skill writes `docs/marketing-context.md` (ICP, positioning, messaging)
5. **Workflows plugin** inner loop: brainstorm reads all three context docs → plan produces tasks → execute builds the site → review runs Tier 1 + typescript-reviewer + accessibility-reviewer
6. If Symphony is configured, issues from the Linear board are dispatched to autonomous agents who read the same context docs

---

## 5. Knowledge Architecture

### The Problem

Agents make decisions in isolation. A project-start creates a CLAUDE.md, but it has no awareness of:
- Company decisions ("we use Supabase for all new databases")
- Customer context ("our ICP is B2B SaaS, 50-500 employees")
- Business metrics ("MRR is $X, churn is Y%")
- Organizational constraints ("merge freeze starts Thursday")
- Existing processes ("our code review process requires 2 approvals")

This knowledge lives across multiple Systems of Record (SoRs):
- **Salesforce** — customer data, deals, pipeline, account history
- **BigQuery** — analytics, metrics, usage data, business intelligence
- **Handbook** (GitHub repo) — company policies, processes, culture, org structure
- **Linear** — project management, issues, milestones, team capacity
- **Obsidian** — personal knowledge management

### The Solution: Handbook as Company Brain

The handbook repo becomes the canonical cache layer between live SoRs and agent context.

```
SYSTEMS OF RECORD (live data)
┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────┐
│  Salesforce  │  │   BigQuery   │  │   Linear   │  │  GitHub  │
│  (customers) │  │  (analytics) │  │  (projects) │  │ (code +  │
│              │  │              │  │             │  │ handbook)│
└──────┬───────┘  └──────┬───────┘  └──────┬──────┘  └────┬─────┘
       │                 │                 │               │
       ▼                 ▼                 │               │
  ┌─────────────────────────────┐          │               │
  │  CONTEXT REFRESH            │          │               │
  │  (GitHub Action, weekly)    │          │               │
  │  Queries → Markdown → PR    │          │               │
  └──────────────┬──────────────┘          │               │
                 ▼                         │               │
  ┌──────────────────────────────┐         │               │
  │  HANDBOOK REPO               │         │               │
  │  (company brain)             │◄────────┼───────────────┘
  │                              │         │
  │  context/                    │         │  (handbook IS a GitHub repo)
  │    customers.md  ← Salesforce│         │
  │    metrics.md    ← BigQuery  │         │
  │    tech-stack.md             │         │
  │    brand.md                  │         │
  │  decisions/                  │         │
  │    INDEX.md                  │         │
  │    engineering/CDR-*.md      │         │
  │    business/CDR-*.md         │         │
  │    legal/CDR-*.md            │         │
  │  policies/                   │         │
  │  processes/                  │         │
  │  org/                        │         │
  └──────────────┬───────────────┘         │
                 │                         │
                 │  @import at             │
                 │  project-start          │
                 ▼                         ▼
  ┌──────────────────────────────────────────────┐
  │  PROJECT CLAUDE.md                            │
  │                                               │
  │  @handbook/context/company-profile.md         │
  │  @handbook/decisions/INDEX.md                  │
  │  @handbook/decisions/engineering/CDR-001.md    │  ← trait: produces-code
  │  @handbook/context/customers.md                │  ← trait: needs-marketing
  │  @docs/engineering-context.md                  │  ← from engineering plugin
  │  @docs/marketing-context.md                    │  ← from marketing plugin
  │  @docs/decisions/001-use-nextjs.md             │  ← project ADR
  └──────────────────────┬────────────────────────┘
                         │
                         │  loaded every session
                         ▼
  ┌──────────────────────────────────────────────┐
  │  AGENT SESSION                                │
  │                                               │
  │  Company context (from handbook @imports)      │
  │  + Domain context (from plugin context-skills) │
  │  + Project context (CLAUDE.md + project docs)  │
  │  + Task context (Linear issue + code files)    │
  │                                               │
  │  On-demand: MCP queries to SoRs for           │
  │  specific data points                          │
  └────────────────────────────────────────────────┘
```

### Handbook Repo Structure

```
handbook/
├── CLAUDE.md                          # How agents should use this repo
├── context/                           # Materialized context snapshots (from SoRs)
│   ├── company-profile.md             # Who we are, mission, values, team size
│   ├── customers.md                   # ICP, key accounts (← Salesforce, weekly)
│   ├── metrics.md                     # Key business metrics (← BigQuery, daily/weekly)
│   ├── tech-stack.md                  # Canonical tech decisions
│   └── brand.md                       # Voice, visual identity, guidelines
├── decisions/                         # Company Decision Records (CDRs)
│   ├── INDEX.md                       # Lightweight manifest — titles + statuses
│   ├── engineering/
│   │   ├── CDR-001-use-supabase.md
│   │   ├── CDR-002-vercel-deployment.md
│   │   └── CDR-003-no-microservices.md
│   ├── business/
│   │   ├── CDR-010-linear-for-pm.md
│   │   └── CDR-011-quarterly-planning.md
│   └── legal/
│       ├── CDR-020-data-retention.md
│       └── CDR-021-accessibility-compliance.md
├── policies/                          # Traditional handbook content
│   ├── hiring.md
│   ├── compensation.md
│   └── remote-work.md
├── processes/                         # How we do things
│   ├── code-review.md
│   ├── incident-response.md
│   └── sprint-cadence.md
└── org/                               # Organizational structure
    ├── teams.md
    ├── roles.md
    └── stakeholders.md
```

### Materialized Context Pattern

Context files from SoRs include source tracking in frontmatter:

```markdown
---
source: salesforce
last_refreshed: 2026-03-10T14:00:00Z
refresh_cadence: weekly
---

# Customer Context

## ICP
- B2B SaaS companies, 50-500 employees, US-based
- Primary buyer: VP Engineering or CTO

## Top Accounts
- Acme Corp (Enterprise, $120k ARR, renewed Q1)
- ...

## Churn Signals
- 3 accounts flagged for low usage this month
```

**Context Refresh** is a GitHub Action that:
1. Authenticates to Salesforce + BigQuery
2. Runs predefined queries (curated, not raw dumps)
3. Formats results into structured markdown
4. Commits to `handbook/context/`
5. Opens a PR if changes are significant (for human review)

This gives human oversight over what enters the company knowledge base while automating the refresh.

### Company Decision Records (CDRs)

CDRs are ADRs lifted to the organizational level. They capture decisions that span ALL projects, not just one.

**Examples:**
- "We use Supabase for all new databases" (engineering)
- "All client-facing apps must meet WCAG AA" (legal/compliance)
- "We use Linear, not Jira" (business/tooling)
- "No microservices until 50+ engineers" (engineering/architecture)
- "90-day PII data retention" (legal)
- "Deploy frontend to Vercel" (engineering/infrastructure)

**CDR Format:**
```markdown
# CDR-001. Use Supabase for All New Databases

**Status:** Active | Superseded | Deprecated
**Date:** 2025-06-15
**Superseded by:** (if applicable)

## Context
[The organizational need that drove this decision]

## Decision
[What was decided and why]

## Consequences
[What this means for all projects going forward]

## Exceptions
[When it's acceptable to deviate, and the approval process]
```

**INDEX.md** provides lazy loading — agents read the lightweight index first, then load full CDRs only when relevant:

```markdown
# Company Decision Records

## Engineering
| ID | Title | Status | Date |
|----|-------|--------|------|
| CDR-001 | Use Supabase for all new databases | Active | 2025-06-15 |
| CDR-002 | Deploy frontend to Vercel | Active | 2025-07-01 |
| CDR-003 | No microservices until 50+ engineers | Active | 2025-08-20 |

## Business
| CDR-010 | Use Linear for project management | Active | 2025-05-01 |

## Legal
| CDR-020 | 90-day PII data retention | Active | 2025-09-01 |
| CDR-021 | WCAG AA for client-facing apps | Active | 2025-09-15 |
```

**CDR-Check Pattern:** Before an agent creates a project-level ADR, it reads the CDR INDEX and checks for conflicts:
- If covered by existing CDR → reference the CDR instead of creating a new ADR
- If conflicts with a CDR → flag to user: "This would contradict CDR-042. Override?"

### Two-Layer Context Model

Inspired by the Foundation Capital / Metadata Weekly / Graphlit analysis of context graphs, we distinguish two fundamentally different types of context. They have different sources, different refresh cadences, and different governance models.

**Operational Context** — How the organization works. Stable, changes quarterly.
- Company profile (who we are, mission, values, team size)
- Tech stack (what tools and technologies we use)
- Brand (voice, visual identity, guidelines)
- Processes (how we do code review, incident response, sprint cadence)
- Org structure (teams, roles, stakeholders)
- Identity map (cross-system identity resolution)
- Ownership map (who owns which repos, services, accounts, domains)

**Analytical Context** — What metrics mean and how to reason about them. Dynamic, changes weekly/daily.
- Metric definitions ("ARR" means X at Brite, calculated as Y)
- Customer data (ICP, key accounts, churn signals — from Salesforce)
- Business metrics (MRR, active users, churn rate — from BigQuery)
- Trends and deltas (not just current values, but trajectories)

The distinction matters for three reasons:
1. **Different refresh cadences** — operational context is hand-maintained or refreshed quarterly; analytical context needs automated weekly/daily refresh
2. **Different governance** — operational context changes via PR review (like code); analytical context changes via automated pipelines with human oversight
3. **Different failure modes** — stale operational context leads to wrong processes; stale analytical context leads to wrong decisions

**Updated handbook structure:**

```
handbook/
├── CLAUDE.md
├── context/
│   ├── operational/
│   │   ├── company-profile.md       # Who we are, mission, values
│   │   ├── tech-stack.md            # Canonical tech decisions
│   │   ├── brand.md                 # Voice, visual identity
│   │   └── processes.md             # How we work (code review, sprints, etc.)
│   └── analytical/
│       ├── metric-definitions.md    # What "ARR", "churn", "active user" mean
│       ├── customers.md             # ICP, accounts, churn signals (← Salesforce)
│       └── business-metrics.md      # KPIs + trends (← BigQuery)
├── decisions/
│   ├── INDEX.md
│   ├── engineering/CDR-*.md
│   ├── business/CDR-*.md
│   └── legal/CDR-*.md
├── precedents/                      # Decision trace archive (see below)
│   ├── INDEX.md
│   └── *.md
├── policies/
├── processes/
└── org/
    ├── teams.md
    ├── roles.md
    ├── stakeholders.md
    ├── ownership.md                 # Who owns what (repos, services, accounts)
    └── identity-map.md              # Cross-system identity resolution
```

### Temporal Context (Not Just Snapshots)

Current context docs are point-in-time snapshots. Agents need temporal understanding — how things changed over time — because decisions depend on trajectories, not just current state.

**Pattern:** Analytical context docs include trend data alongside current values:

```markdown
---
source: bigquery
last_refreshed: 2026-03-10T14:00:00Z
refresh_cadence: weekly
---

# Business Metrics

## MRR
- **Current:** $450k (as of 2026-03-10)
- **30d change:** +4.2%
- **90d change:** +12.8%
- **Notable:** Acme Corp upgraded from Growth to Enterprise in February

## Active Users (DAU)
- **Current:** 2,340
- **30d change:** -1.8%
- **90d change:** +15.2%
- **Notable:** DAU dipped after v3.2 deploy; recovering after hotfix

## Churn Rate
- **Current:** 3.1% monthly
- **30d change:** -0.4pp (improving)
- **90d trend:** Steady improvement since onboarding redesign
- **At-risk accounts:** 3 flagged (see customers.md)
```

The context refresh GitHub Action computes deltas by comparing the new snapshot against the previous committed version. This means git history of context docs IS the temporal record — `git log handbook/context/analytical/business-metrics.md` shows how metrics evolved.

### Operational Context Foundation

The Graphlit research identifies a layer BENEATH decision context that most AI platforms miss: the operational foundation. Without it, agents can't resolve basic organizational questions.

**Identity Resolution** — `org/identity-map.md`

The same person appears differently across systems. Agents need a map:

```markdown
# Identity Map

| Person | GitHub | Linear | Slack | Salesforce | Email |
|--------|--------|--------|-------|------------|-------|
| Holden Halford | @holdenhalford | Holden H. | @holden | holden@britenites.com | holden@britenites.com |
| ... | ... | ... | ... | ... | ... |
```

Use cases: "Who should review this PR?" → look up owner in ownership.md → resolve their GitHub handle from identity-map.md → assign. "Tag the account owner in Linear" → look up Salesforce account owner → resolve their Linear identity.

**Ownership Mapping** — `org/ownership.md`

```markdown
# Ownership Map

## Repositories
| Repo | Owner | Team | Description |
|------|-------|------|-------------|
| britenites-app | Holden | Platform | Main application |
| britenites-claude-plugins | Holden | Platform | Agent plugin system |
| handbook | Holden | Company | Company knowledge base |

## Services
| Service | Owner | On-call | SLA |
|---------|-------|---------|-----|
| API | Platform team | @holden | 99.9% |
| Auth | Platform team | @holden | 99.99% |

## Domains / Accounts
| Domain | Owner | Vendor |
|--------|-------|--------|
| britenites.com | Holden | Vercel |
| Salesforce | Sales team | — |
```

Use cases: "This PR touches the auth service — who needs to review?" → ownership.md → Platform team, @holden. "We need to update DNS — who owns the domain?" → ownership.md → Holden, Vercel.

### Decision Trace Architecture

This is the most significant addition from the Context Graphs research. The Foundation Capital thesis argues that the next trillion-dollar platforms will be built by capturing *decision traces* — not just what was decided, but HOW and WHY, with full context about inputs, alternatives, precedent, and approvals.

**Our structural advantage:** The workflows plugin sits in the execution path of every brainstorm → plan → execute → review → ship cycle. We witness every decision an agent makes. We can capture those traces automatically.

#### What Are Decision Traces?

Decision traces are structured records of reasoning emitted during agent execution. They're lighter than ADRs (which are formal, point-in-time documents) but richer than commit messages (which describe WHAT, not WHY).

**The hierarchy:**
- **CDRs** (Company Decision Records) — org-level, long-lived, formal. "We use Supabase for all new databases."
- **ADRs** (Architecture Decision Records) — project-level, long-lived, formal. "We chose Next.js App Router for this project."
- **Decision Traces** — task-level, continuous, lightweight. "For task BRI-1234/3, I chose row-level security over app-level filtering because CDR-001 mandates Supabase and RLS is database-enforced."

CDRs and ADRs are written deliberately by humans or agents at decision points. Decision traces are **emitted automatically** during execution.

#### Decision Trace Format

```markdown
## Trace — [Issue-ID]/[Task-N] — [Date]

**Decision:** [One-line summary of what was decided]
**Category:** architecture | library-selection | pattern-choice | trade-off | bug-resolution | scope-change
**Confidence:** N/10

### Inputs
- [What information was available when the decision was made]
- [Which context docs were read]
- [What code was examined]

### Alternatives Considered
1. **[Chosen option]** — [why chosen]
2. **[Rejected option]** — [why rejected]
3. **[Rejected option]** — [why rejected]

### Precedent Referenced
- [CDR-XXX, ADR-YYY, or previous decision trace that influenced this decision]
- [Or "None — first time encountering this pattern"]

### Outcome
- **Files changed:** [list]
- **Tests:** [pass/fail, count]
- **Approved by:** [PR review / human checkpoint / auto-verified]
```

#### When Traces Are Emitted

Not every micro-decision needs a trace. Traces are emitted when:

1. **Architecture or design choice** — choosing between approaches, patterns, or structures
2. **Library or tool selection** — picking a dependency, especially when alternatives exist
3. **Trade-off resolution** — explicitly choosing between competing concerns (performance vs readability, etc.)
4. **CDR/ADR deviation** — any decision that bends or overrides an existing decision record
5. **Bug root cause** — when debugging reveals the root cause and fix approach
6. **Scope change** — when the implementation diverges from the plan

Routine decisions (variable naming, formatting, standard patterns) do NOT get traces.

#### Where Traces Live

**During execution:** Traces are emitted as structured comments in the executing-plans skill's checkpoint output. They're part of the task completion record.

**After execution:** The compound-learnings skill (during `/workflows:ship`) extracts decision traces from the session and:
1. Writes significant traces to `docs/precedents/[issue-id].md` in the project repo
2. Cross-references against CDR INDEX — if a trace established a new pattern, suggest promoting to an ADR
3. For traces with high reuse potential, copies to `handbook/precedents/` for cross-project searchability

**Precedent accumulation flow:**

```
Agent executes task
  → Emits decision trace at checkpoint
    → compound-learnings extracts traces during /ship
      → Writes to docs/precedents/ (project-level)
        → High-value traces promoted to handbook/precedents/ (org-level)
          → Future agents search precedents during brainstorm
```

### Precedent Database

The precedent database is the accumulated collection of decision traces, searchable by future agents. It answers: "Have we solved a problem like this before? What worked?"

**Project-level precedents:** `docs/precedents/[issue-id].md`
- Contains all decision traces from a specific issue
- Automatically generated by compound-learnings during /ship
- Searchable within the project

**Org-level precedents:** `handbook/precedents/`
- Contains high-value decision traces promoted from projects
- Searchable across ALL projects
- Indexed in `handbook/precedents/INDEX.md`

**Precedent INDEX format:**

```markdown
# Precedent Index

| Issue | Decision | Category | Date | Tags |
|-------|----------|----------|------|------|
| BRI-1234 | Row-level security for multi-tenancy | architecture | 2026-03-10 | multi-tenant, supabase, rls |
| BRI-1189 | Chose Resend over SendGrid for transactional email | library-selection | 2026-02-28 | email, transactional |
| BRI-1156 | Parallel agent dispatch with timeout | pattern-choice | 2026-02-15 | agents, concurrency, timeout |
```

**Precedent Search Skill** (new skill: `precedent-search`)

A skill that agents invoke during brainstorming or planning:
1. Reads the project's `docs/precedents/INDEX.md` and `handbook/precedents/INDEX.md`
2. Searches by tags, categories, or natural language similarity
3. Returns relevant past decisions with full context
4. Agent incorporates precedent into current decision-making

Example flow:
> **Agent (during brainstorm):** "The issue involves multi-tenancy. Searching precedents..."
> **Precedent search result:** "Found 1 relevant precedent: BRI-1234 chose row-level security over app-level filtering for multi-tenancy (2026-03-10). Reason: CDR-001 mandates Supabase, RLS is database-enforced. Outcome: Successful, no security incidents."
> **Agent:** "Based on precedent BRI-1234, I recommend row-level security. Here's why it applies to our case..."

This is the **compound knowledge flywheel** in action: past decisions inform future decisions, and the quality of decisions improves over time.

### Agent Memory Instrumentation

The executing-plans skill already runs subagent-per-task. Each subagent should emit a structured execution trace at completion that captures not just what was done, but what context was used and what reasoning drove decisions.

**Execution Trace Format:**

```yaml
task: BRI-1234/task-3
agent: execute-subagent
timestamp: 2026-03-10T14:32:00Z
duration: 4m 22s

context_used:
  - docs/engineering-context.md
  - handbook/decisions/engineering/CDR-001.md
  - src/middleware/auth.ts (read, 145 lines)

decisions_made:
  - type: library-selection
    chose: "@supabase/ssr"
    over: ["next-auth", "custom-jwt"]
    reason: "CDR-001 mandates Supabase; SSR package integrates with App Router"
    confidence: 9
  - type: architecture
    chose: "row-level-security"
    over: ["app-level-filtering"]
    reason: "Database-enforced is more secure for multi-tenant; precedent BRI-1234"
    confidence: 8

files_changed:
  - src/middleware/auth.ts (modified, +42 -8)
  - prisma/schema.prisma (modified, +12 -0)
  - src/lib/supabase.ts (new, +28)

tests:
  added: 3
  passed: 3
  failed: 0

verification:
  build: pass
  tests: pass
  acceptance_criteria: pass
  integration: pass
```

This is richer than git commit messages. It captures:
- **What context was loaded** — which docs/files influenced the decision
- **What alternatives were rejected** — and why
- **What precedent was referenced** — connecting current decisions to past ones
- **Confidence level** — how certain the agent was

Over time, execution traces become the raw material for:
- Decision trace extraction (compound-learnings pulls the `decisions_made` entries)
- Agent performance analysis (which context docs lead to better outcomes?)
- Process improvement (which types of decisions have low confidence?)

### Context Governance

Context is strategic intellectual property. The Metadata Weekly analysis emphasizes that enterprises should own their context, not have it locked in vendor silos. Our handbook-as-company-brain approach ensures Brite owns all context in its own GitHub repo. But ownership requires governance.

**CDR Governance:**

| Action | Authority | Process |
|--------|-----------|---------|
| Create CDR | Engineering lead, CTO, or department head | PR to handbook repo, requires 1 approval |
| Modify active CDR | Original author or engineering lead | PR with rationale for change |
| Supersede CDR | Engineering lead or CTO | New CDR with `Superseded by:` link, PR with migration plan |
| Override CDR (project-level) | Project lead | ADR in project documenting the deviation + rationale |
| Emergency override | Anyone, with post-hoc review | Flag in Linear, ADR within 48 hours |

**Context Quality:**

| Signal | Meaning | Action |
|--------|---------|--------|
| Context doc `last_refreshed` > 2x `refresh_cadence` | Stale data | Session-start warns; agents treat as low-confidence |
| CDR with no `Exceptions` section | Unclear when deviation is OK | Flag for author to add exceptions |
| Precedent with confidence < 5 | Uncertain decision | Don't auto-reference; present as "uncertain precedent" |
| Conflicting CDRs | Organizational ambiguity | Flag for engineering lead; block agent decision until resolved |

**Audit Trail:**

Every agent session should be auditable: "What context did this agent use to make this decision?" The execution trace (see Agent Memory Instrumentation above) provides this. The `context_used` field is the audit trail — it lists every document the agent read before deciding.

This matters for:
- **Compliance** — "Why did the system make this recommendation?" → trace shows inputs + reasoning
- **Debugging** — "Why did the agent choose the wrong library?" → trace shows stale context doc or missing CDR
- **Improvement** — "Which context docs are most/least useful?" → trace frequency analysis

### The Context Flywheel

The Foundation Capital thesis describes a compounding loop: accuracy → trust → adoption → feedback → accuracy. Our platform has this flywheel built in, but it can be made more explicit.

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│   ┌─────────┐    ┌─────────┐    ┌──────────┐            │
│   │ Context │───→│ Agent   │───→│ Decision │            │
│   │ (input) │    │ Execute │    │ Traces   │            │
│   └─────────┘    └─────────┘    └────┬─────┘            │
│        ↑                             │                   │
│        │                             ▼                   │
│   ┌────┴──────┐              ┌──────────────┐           │
│   │ Precedent │◄─────────────│  Compound    │           │
│   │ Database  │              │  Learnings   │           │
│   └───────────┘              └──────────────┘           │
│                                                          │
│   The more agents execute, the more traces accumulate,   │
│   the better future context becomes, the better future   │
│   decisions become.                                      │
└──────────────────────────────────────────────────────────┘
```

**Flywheel stages:**

1. **Context** — Agent reads company context (CDRs, operational context, analytical context) + domain context (plugin context-skills) + project context (CLAUDE.md, ADRs) + precedents
2. **Execution** — Agent makes decisions and writes code/documents. Emits execution traces capturing what context was used and what decisions were made.
3. **Decision traces** — Structured records of reasoning extracted from execution traces.
4. **Compound learnings** — The `/workflows:ship` command runs compound-learnings, which: updates CLAUDE.md with new patterns/gotchas, writes decision traces to `docs/precedents/`, promotes high-value traces to `handbook/precedents/`
5. **Precedent database** — Accumulated decision traces become searchable by future agents
6. **Better context** → Better decisions → More traces → Better precedent → Even better context

**Measuring the flywheel:**
- **Precedent hit rate** — % of brainstorm sessions that find relevant precedent (target: >50% after 6 months)
- **Decision confidence trend** — average confidence score across all traces (should increase over time)
- **CDR coverage** — % of agent decisions that have a relevant CDR (indicates organizational decision maturity)
- **Context freshness** — % of context docs within their refresh cadence
- **Override rate** — % of decisions that override a CDR (high rate = CDRs need updating)

### Harness Self-Improvement

The LangChain "Anatomy of an Agent Harness" article identifies a frontier capability: **agents that analyze their own traces to identify and fix harness-level failure modes.** This extends our flywheel from improving DECISIONS to improving the HARNESS ITSELF.

**Current flywheel:** Context → Execute → Traces → Compound Learnings → Better Context → Better Decisions

**Extended flywheel:** + Trace Analysis → Harness Improvements → Better Agent Performance

A periodic `harness-health-check` skill (or scheduled job) analyzes accumulated decision traces and identifies:

| Pattern | Signal | Harness Fix |
|---------|--------|-------------|
| Context doc X is never referenced in traces | Wasted context budget | Remove from Tier 1/2 @imports, move to Tier 3 |
| CDR-001 is overridden in 40% of decisions | CDR needs updating or is too rigid | Flag for CDR author to review exceptions |
| Decisions in category "library-selection" average confidence 4/10 | Insufficient context for this decision type | Add library-evaluation precedents or a new CDR |
| Agents consistently fail tasks that span >3 files | Harness doesn't provide enough cross-file context | Improve executing-plans to inject more project structure |
| Same error pattern recurs across 5 projects | Systemic harness issue | Promote to a CDR or add a review agent check |

This is the **meta-feedback loop** — the harness observes its own effectiveness through the traces it collects and improves itself. It's the difference between a system that gets smarter at making decisions and a system that gets smarter at HELPING agents make decisions.

**Implementation approach:** Start simple. After Milestone 3 (Decision Traces) has been running for a month, manually analyze traces for patterns. Codify the most useful analyses into a skill. Eventually, automate as a periodic job.

### The Brite Plugin System as a Harness

The "Agent = Model + Harness" framework from LangChain provides a clean lens for understanding what we're building. Our entire plugin system IS a harness:

| Harness Component | Brite Implementation |
|-------------------|---------------------|
| System prompts | CLAUDE.md + @imports to handbook + domain context docs |
| Tools + descriptions | Skills (progressive disclosure via frontmatter), commands |
| MCP servers | Linear, Sequential Thinking, BigQuery, QMD (planned) |
| Orchestration logic | executing-plans (subagent-per-task), review agents (parallel dispatch), Symphony daemon |
| Hooks/middleware | Security hooks (PreToolUse), quality hooks (pre-commit), linting hooks (PostToolUse) |
| Memory + search | compound-learnings, precedent database, auto-memory, QMD |
| Sandboxed execution | git-worktrees (isolated branches), Symphony workspaces |
| Verification loops | verification-before-completion (4-level), review agents (9-agent tiered) |
| Context rot mitigation | Context budget management (tiering, per-task selection, progressive disclosure) |
| Long-horizon continuation | executing-plans (fresh context per task), Symphony (workpad + continuation) |

This framing is useful for two reasons:
1. **Gap analysis** — for each desired agent behavior, ask "what harness feature enables it?" Missing features = gaps in our platform.
2. **Evolution tracking** — as Claude models improve, some harness complexity can be removed. Skills that exist to compensate for model weaknesses (e.g., explicit planning prompts) may become unnecessary. Track which harness features are compensating vs amplifying.

### Context Budget Management

Our knowledge architecture adds significant context to every agent session. The "harness engineering" perspective (from LangChain's "Anatomy of an Agent Harness") forces us to treat context as a **finite budget** — every line of company context, CDR, or precedent result consumes space that could be used for actual task work.

**The budget problem:** If a project has company profile (50 lines) + CDR INDEX (30 lines) + 3 CDR details (150 lines) + engineering context (80 lines) + marketing context (80 lines) + project CLAUDE.md (100 lines) + precedent search results (200 lines) = ~690 lines of context before any code loads. That's 10-15% of a context window, and it grows as more CDRs and precedents accumulate.

**Strategy 1: Context Tiering**

Not all context is equally important. Tier it:

| Tier | What | When Loaded | Budget |
|------|------|-------------|--------|
| **Tier 1** (always) | Company profile, CDR INDEX (titles only), project CLAUDE.md | Session start | ~100 lines |
| **Tier 2** (per-project) | Domain context docs (engineering, marketing, etc.) | Session start via @imports | ~80-200 lines per doc |
| **Tier 3** (on-demand) | Full CDR documents, precedent search results, analytical context | Agent reads when needed | Variable |

Tier 1 and 2 are pre-loaded. Tier 3 stays in the filesystem — agents read specific files when their task requires it.

**Strategy 2: Per-Task Context Selection**

Our current design loads context at the PROJECT level (traits determine @imports). But different tasks within a project need different context. A CSS styling task doesn't need the CDR INDEX or BigQuery metrics, even if the project has those traits.

Enhancement for `executing-plans`: when spawning a subagent for a task, select which context docs to inject based on the TASK, not just the project. A database migration task gets CDRs + data context. A frontend component task gets design context. This reduces per-task context consumption significantly.

**Strategy 3: Progressive Disclosure**

Don't dump everything into context at session start. Use the pattern from Claude Code's skill system — load lightweight summaries first, full content on demand:
- CDR INDEX (summaries) → full CDR (loaded when agent needs details)
- Precedent INDEX (summaries) → full precedent trace (loaded on match)
- Metric definitions (what exists) → metric values (loaded for data tasks)

**Strategy 4: Context Offloading**

Large outputs (full precedent traces, long analytical context, detailed ownership maps) should live in the filesystem, not in context. Agents read them when needed. The QMD MCP approach is ideal for this — agents query QMD for relevant content instead of having it pre-loaded.

### Context Loading Cascade

The critical question: **when does what load?**

Principle: **Load context at the narrowest scope that still informs the decision.**

| When | What Loads | How | Why |
|------|-----------|-----|-----|
| **Project-start** | Trait classification → selects relevant CDR categories + context docs → writes @imports into CLAUDE.md | Trait-based selection from handbook | One-time setup; determines what's available for all future sessions |
| **Session-start** | CLAUDE.md @imports resolve automatically. Freshness check on context docs. | Built-in @import resolution | Every session gets project + company context automatically |
| **Brainstorm** | Domain context docs read by skill. CDR INDEX scanned for constraints. | Skill reads @imported docs | Discovery phase needs broad context to avoid bad directions |
| **Plan** | Before proposing architecture, check CDR INDEX for conflicts. Reference CDRs in plan rationale. | Writing-plans skill pattern | Decisions must respect organizational constraints |
| **Execute** | Task-specific live MCP queries (specific Salesforce account, BigQuery metric) | Agent discretion via MCP | Only fresh data needed for the specific task at hand |
| **Review** | CDR compliance check — "does this PR violate any active CDRs?" | Review agent pattern (potential new agent) | Catch violations before they ship |
| **Ship** | Compound learnings may update domain context docs | Compound-learnings skill | Knowledge flows back into the system |

**Five context layers, from broadest to narrowest:**

| Layer | Scope | Examples | Loaded | Refresh |
|-------|-------|---------|--------|---------|
| **Company** | All projects | Company profile, CDR INDEX, tech-stack.md, identity-map.md | Always via CLAUDE.md @imports | Quarterly (operational), weekly (analytical) |
| **Precedent** | All projects | handbook/precedents/INDEX.md, past decision traces | Searched during brainstorm/plan | Grows continuously via /ship |
| **Domain** | Projects with matching traits | engineering-context.md, marketing-context.md | Per-trait at project-start | Updated by domain plugin context-skills |
| **Project** | One project | CLAUDE.md, project ADRs, docs/precedents/ | Always for the project | Updated every /ship cycle |
| **Task** | One task | Linear issue, code files, test results, execution traces | Per-session, per-task | Ephemeral |

### Updated Full-Loop Flow Diagram

The complete knowledge flow, including decision traces and the feedback loop:

```
SYSTEMS OF RECORD (live data)
┌─────────────┐ ┌──────────────┐ ┌────────────┐ ┌──────────┐
│  Salesforce  │ │   BigQuery   │ │   Linear   │ │  GitHub  │
└──────┬───────┘ └──────┬───────┘ └──────┬──────┘ └────┬─────┘
       │                │                │              │
       ▼                ▼                │              │
  ┌────────────────────────────┐         │              │
  │  CONTEXT REFRESH           │         │              │
  │  (GitHub Action)           │         │              │
  │  Weekly: analytical        │         │              │
  │  Quarterly: operational    │         │              │
  └────────────┬───────────────┘         │              │
               ▼                         │              │
  ┌────────────────────────────┐         │              │
  │  HANDBOOK REPO             │◄────────┼──────────────┘
  │  (company brain)           │         │
  │                            │         │
  │  context/operational/      │         │
  │  context/analytical/       │         │
  │  decisions/ (CDRs)         │         │
  │  precedents/ ◄─────────────┼─────────┼──── (5) promoted traces
  │  org/ (identity, ownership)│         │
  └────────────┬───────────────┘         │
               │ @import                 │
               ▼                         ▼
  ┌──────────────────────────────────────────────┐
  │  PROJECT CLAUDE.md                            │
  │  (1) Company + domain + project context       │
  └──────────────────────┬────────────────────────┘
                         │ loaded every session
                         ▼
  ┌──────────────────────────────────────────────┐
  │  (2) AGENT SESSION                            │
  │  Reads context → searches precedents →        │
  │  makes decisions → emits execution traces     │
  └──────────────────────┬────────────────────────┘
                         │
                         ▼
  ┌──────────────────────────────────────────────┐
  │  (3) EXECUTION TRACES                         │
  │  Structured records of reasoning:             │
  │  context_used, decisions_made, alternatives,  │
  │  precedent_referenced, confidence             │
  └──────────────────────┬────────────────────────┘
                         │ during /ship
                         ▼
  ┌──────────────────────────────────────────────┐
  │  (4) COMPOUND LEARNINGS                       │
  │  Extracts decision traces →                   │
  │  Writes to docs/precedents/ (project) →       │
  │  Updates CLAUDE.md with patterns/gotchas →     │
  │  Promotes high-value traces to handbook (5)    │
  └────────────────────────────────────────────────┘
```

The loop closes: agents read context (1) → execute and trace (2-3) → compound learnings extract and promote (4-5) → future agents read better context and precedent (back to 1).

---

## 6. Layer 1: Project-Start Redesign

### Current State

The current `project-start.md` (415 lines) follows this flow:
1. **Step 1**: Binary question — "Are you technical or not?"
2. **Shared Interview**: About them, about what they want, about look and feel
3. **Path A (Non-technical)**: Full decision-making authority to Claude
4. **Path B (Technical)**: Collaborative decision-making
5. **Generate CLAUDE.md**: 8-section template per path
6. **Git setup**: `git init` if needed
7. **Linear project**: Create in Linear
8. **V1 project plan**: Full plan document
9. **ADR generation**: Architecture Decision Records for all tech decisions

### What Changes

| Current | New | Reason |
|---------|-----|--------|
| Binary technical/non-technical | Trait-based classification | Projects aren't binary; a hiring plan needs different setup than a CLI tool |
| Fixed interview questions | Three-phase methodology (JTBD + MI + SPIN) | Structured discovery reveals true needs, not just stated requirements |
| Code-only setup | Universal project setup | Any project type, not just code |
| Isolated project | Connected to company knowledge | @imports from handbook, CDR awareness |
| V1 plan generated inline | V1 plan still generated, reordered to after CLAUDE.md | Plan created at setup; refined later by `/workflows:post-plan-setup` |
| ADRs generated unconditionally | ADRs gated on `produces-code` or `requires-decisions` | Only generate ADRs when project has real technical decisions |
| `git init` only | GitHub repo in Brite-Nites org | Full repo setup, not just local git |
| No plugin awareness | Plugin discovery + activation | Right domain plugins activate based on traits |
| No MCP verification | Dynamic MCP verification | Confirm required tools are connected before proceeding |

### Interview Methodology: Three-Phase Composite

**Phase 1: Understand (JTBD + MI + Design Thinking)**

Purpose: Understand the person and the real problem. Don't classify yet — just listen.

Techniques:
- **MI's OARS** as conversational backbone:
  - **Open questions**: "Tell me about..." / "What does... look like?"
  - **Affirmations**: Acknowledge what they've already done/thought through
  - **Reflective listening**: Mirror back what you heard: "So the core issue is..."
  - **Summaries**: Recap before transitioning to next phase
- **JTBD trigger question**: "What happened that made you decide to do this now?" — reveals the triggering event and forces (push, pull, anxiety, habit) that drive the real need
- **Design Thinking stories**: "Walk me through the last time you dealt with this" — situations reveal more than opinions
- **Five Whys** drill-down: When someone states a solution instead of a problem, ask "why" 2-3 times to find the root cause
- **Appreciative Inquiry**: "What's working today that we should keep?" — preserves existing value, especially for brownfield projects

**Phase 2: Define (SPIN + Impact Mapping + Story Mapping)**

Purpose: Scope, prioritize, and structure what was discovered in Phase 1.

Techniques:
- **SPIN Implication**: "What happens if this isn't solved?" / "What's the impact of not doing this?" — reveals true priority (if the answer is "nothing much," it's low priority)
- **Impact Mapping**: Goal → Actors → Impacts → Deliverables hierarchy — ensures work connects to outcomes
- **Story Mapping**: "What does the user do first? Then what?" — maps the user journey and defines MVP scope
- **Lean Canvas**: "Top 3 problems. Rank them." — forces focus when scope is expansive

**Phase 3: Classify + Configure (Structured Intake)**

Purpose: Set up the right infrastructure based on what was learned.

This phase is largely automated — Claude classifies traits from the conversation, discovers plugins, verifies MCP connections, and creates infrastructure. The user confirms but doesn't need to answer technical questions.

Techniques:
- **Trait classification** from interview answers (see next section)
- **Plugin discovery** — which domain plugins are needed?
- **MCP verification** — which tools need to be connected?
- Timeline, constraints, existing artifacts inventory

### Interview Design Principles

1. **Reflect before advancing** — after every substantive answer, mirror it back (MI). "So what you're saying is..." before asking the next question.
2. **Ask about situations, not opinions** — "Walk me through..." beats "What do you think?" (Design Thinking). Situations reveal real behavior; opinions reveal aspirations.
3. **Drill when someone states a solution** — "We need a React app" → "What problem does the React app solve?" → 2-3 "why" layers to find root cause (Five Whys).
4. **Use implications to reveal priority** — "What happens if this isn't solved?" (SPIN). If the answer is "compliance violation" vs "mild inconvenience," you know the priority.
5. **Walk the user journey for scope** — "What happens first? Then what?" (Story Mapping). This naturally defines MVP.
6. **Summarize at transitions** — recap before moving between phases (MI). "Before we move on, let me make sure I understand..."
7. **Classify late, not early** — understand before categorizing. Don't ask "is this a code project?" — let the conversation reveal it.
8. **Cap at 3** — top 3 problems, success criteria, constraints (Lean Canvas). Prevents scope explosion.

### Trait-Based Classification

After the interview, Claude classifies the project into **traits** that combine freely. A project can have any combination of traits. Traits determine all downstream setup: plugins, documentation, infrastructure, review agents.

<!-- Canonical detection signals: plugins/workflows/commands/project-start.md § Trait Definitions. This table is a design-time snapshot. -->
| Trait | Detection Signals | What It Activates |
|-------|-------------------|-------------------|
| `produces-code` | "build an app", "create a tool", "implement", programming languages mentioned | Git + GitHub repo (Brite-Nites org), CI, CLAUDE.md coding conventions, pre-commit, .vscode |
| `produces-documents` | "write a plan", "create docs", "report", "proposal" | docs/ scaffold, markdown structure, @imports, brief.md + outline.md templates |
| `involves-data` | "analyze", "data warehouse", "Snowflake", "BigQuery", "Redshift", "Databricks", "dashboard"; "metrics" only with data infrastructure co-terms | Snowflake MCP verification, data source configuration, data context in CLAUDE.md |
| `requires-decisions` | "evaluate", "choose between", "build vs buy", multiple options discussed | docs/decisions/ + ADR template, CDR INDEX @import for conflict checking |
| `has-external-users` | "customers", "users", "public-facing", "sign up" | Deployment config, monitoring, accessibility requirements, performance budgets |
| `client-facing` | "client", "client deliverable", "external stakeholder", "SOW", "client relationship" (NOT triggered by internal deadlines or stakeholders) | Communication cadence, deliverable milestones in Linear, status update templates |
| `needs-design` | "brand", "look and feel", "visual", "colors", "palette" | Design plugin activation, `design-context` skill, brand/token context |
| `needs-marketing` | "launch", "campaign", "audience", "positioning", "landing page" | Marketing plugin activation, `product-marketing-context` skill, ICP/voice context |
| `needs-sales` | "pricing", "sales deck", "objections", "demo", "proposal" | Sales plugin activation, `sales-context` skill, ICP/competitors context |
| `cross-team` | "multiple teams", "stakeholders", "org-wide", "cross-functional" | Stakeholder map, broader Linear labels, org structure @import |
| `automation` | "scheduled", "cron", "pipeline" (as data/automation pipeline), "bot", "CI/CD" only when it's the project's core purpose | Script structure, scheduler config, integration testing patterns |

### What Project-Start Generates

**Always created (regardless of traits):**
- `CLAUDE.md` with @imports to handbook + domain context docs
- Linear project with description from interview
- `docs/decisions/` directory (empty — ADRs generated organically during development)

**Created per trait:**

| Trait | Infrastructure | Documentation | Plugins |
|-------|---------------|---------------|---------|
| `produces-code` | GitHub repo in Brite-Nites org, `.gitignore`, pre-commit hook, `.vscode/` | `docs/engineering-context.md` | Engineering plugin |
| `produces-documents` | — | `docs/brief.md`, `docs/outline.md` scaffold | — |
| `involves-data` | Snowflake MCP verified | `docs/data-context.md` | — |
| `requires-decisions` | — | CDR INDEX @imported for conflict checking | — |
| `has-external-users` | Deployment scaffold | Accessibility requirements noted | — |
| `client-facing` | — | Communication cadence in CLAUDE.md | — |
| `needs-design` | — | `docs/design-context.md` | Design plugin |
| `needs-marketing` | — | `docs/marketing-context.md` | Marketing plugin |
| `needs-sales` | — | `docs/sales-context.md` | Sales plugin |
| `cross-team` | — | `docs/stakeholders.md` @imported | — |
| `automation` | — | Script/scheduler patterns in CLAUDE.md | — |

**Moved OUT of project-start:**
- Look-and-feel details → design plugin's context-skill handles this

**Reordered within project-start:**
- V1 project plan → still generated, but after CLAUDE.md and Linear setup (consumed by `/workflows:post-plan-setup`)
- ADRs → gated on `produces-code` or `requires-decisions` with 2+ major decisions (not generated unconditionally)

### Express Mode

For experienced users or brownfield projects, an express mode auto-detects traits without a full interview:
1. Scan current directory for file markers (package.json, pyproject.toml, prisma/, etc.)
2. Read existing CLAUDE.md if present
3. Check for GitHub remote
4. Classify traits from codebase signals
5. Ask: "Detected: `produces-code`, `involves-data`. Correct? Anything to add?"
6. Proceed with setup

### Brownfield Support

For existing projects being onboarded:
1. Import existing context from README, CLAUDE.md, docs/
2. Detect existing conventions from codebase
3. Fill context docs from what exists rather than asking
4. Reconcile with CDRs — flag any existing decisions that conflict with company standards

---

## 7. Layer 2: Domain Plugin Ecosystem

### Context-Skill Standard

Every domain plugin MUST have one foundational context-skill. This is the standard:

**Requirements:**
1. Creates `docs/<domain>-context.md` in the project
2. Triggered by project-start during setup (based on trait activation)
3. Read by ALL other skills in the domain before they act
4. Contains foundational context specific to that domain + this project
5. May query SoRs via MCP to populate context (e.g., Salesforce for customer data)
6. Includes a `last_refreshed` timestamp for freshness tracking

**Context-skill invocation pattern:**
```
project-start detects trait → activates plugin → calls context-skill → context-skill interviews (if needed) → writes docs/<domain>-context.md → project-start @imports it into CLAUDE.md
```

### Plugin Roster

| Domain Plugin | Context Skill | Context Sections | Source | Status |
|--------------|--------------|-----------------|--------|--------|
| **Workflows** (process) | — (process, not domain) | — | Built in-house | v3.24.0, Active |
| **Marketing** | `product-marketing-context` | ICP, voice/tone, competitors, positioning, proof points, content strategy | coreyhaines31/marketingskills | Backlog (BRI-1724-1728) |
| **Engineering** | `engineering-context` | Architecture, stack, conventions, patterns, testing strategy, CI/CD | Extract from workflows + new | Planned |
| **Design** | `design-context` | Brand tokens, color palette, typography, component library, accessibility requirements | Extract from workflows + new | Planned |
| **Sales** | `sales-context` | ICP, objection handling, pricing strategy, competitors, sales process | New | Future |
| **Product** | `product-context` | Vision, user personas, metrics/KPIs, roadmap, experiment framework | New | Future |

### Marketing Plugin (BRI-1724-1728)

Source: [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills)

Existing backlog issues:
- **BRI-1724**: Marketing plugin scaffold
- **BRI-1725**: Port 32 marketing skills
- **BRI-1726**: Port 68 CLI tools
- **BRI-1727**: Create `product-marketing-context` (Brite-adapted)
- **BRI-1728**: CI/docs update for multi-plugin support

The marketing plugin demonstrates the context-skill pattern:
1. `product-marketing-context` skill runs first — creates comprehensive marketing context
2. All 32 other skills read this context before acting
3. Skills are organized by function: content, social, email, SEO, analytics, strategy
4. 68 CLI tools provide data enrichment (competitor analysis, keyword research, etc.)

### Engineering Plugin (Planned)

Skills to extract from workflows:
- `react-best-practices` → Engineering plugin
- `python-best-practices` → Engineering plugin
- `testing-strategy` → Engineering plugin
- `code-quality` → Engineering plugin

New skills to build:
- `engineering-context` (foundational context-skill)
- Stack selection advisor
- CI/CD configuration
- Dependency management patterns

### Design Plugin (Planned)

Skills to extract from workflows:
- `frontend-design` → Design plugin
- `ui-ux-pro-max` → Design plugin
- `web-design-guidelines` → Design plugin

New skills to build:
- `design-context` (foundational context-skill)
- Component library scaffolding
- Design token management
- Accessibility audit + remediation

### Plugin Discovery & Installation

Project-start uses trait classification to determine which plugins are needed, then:

1. **Check installed plugins** — scan `plugins/` directory or plugin registry
2. **If missing** → suggest installation: "This project needs the Marketing plugin. Install it?"
   - Or use `find-skills` to discover community plugins
3. **If installed** → trigger context-skill to set up domain context
4. **Report status** to user: "Activated: Engineering, Design. Missing: Marketing (install with ...)"

### Plugin Cross-References

Domain plugins can reference each other's context docs:
- Marketing plugin reads `docs/design-context.md` for brand voice alignment
- Design plugin reads `docs/marketing-context.md` for audience understanding
- Engineering plugin reads both for implementation constraints

This cross-referencing is natural through @imports in CLAUDE.md — all context docs are available to all skills.

---

## 8. Layer 3: Workflows Plugin

### What Stays in Workflows

The workflows plugin is the process layer — domain-agnostic orchestration:

**Process Skills (inner loop):**
- `brainstorming` — Socratic discovery before planning
- `writing-plans` — Bite-sized task breakdown
- `git-worktrees` — Isolated workspace setup
- `executing-plans` — Subagent-per-task with TDD
- `verification-before-completion` — 4-level verification
- `compound-learnings` — Knowledge capture after work
- `best-practices-audit` — CLAUDE.md audit + auto-fix
- `systematic-debugging` — 4-phase root cause analysis

**Review Infrastructure:**
- 9 review agents (code, security, performance, typescript, python, data, architecture, accessibility, test-quality)
- `diff-triage` gating agent
- Confidence scoring, cross-agent dedup, tiered selection

**Commands:**
- `session-start`, `review`, `ship` (inner loop)
- `project-start`, `scope`, `sprint-planning`, `retrospective` (management)
- Visual commands (generate-web-diagram, generate-slides, etc.)

**Hooks:**
- Security (PreToolUse)
- Quality (pre-commit)
- Linting (PostToolUse)
- Context (SessionStart)

### What Moves to Domain Plugins

| Skill | Current Location | New Location | Reason |
|-------|-----------------|-------------|--------|
| `react-best-practices` | workflows | Engineering plugin | Framework-specific, not process |
| `python-best-practices` | workflows | Engineering plugin | Language-specific, not process |
| `testing-strategy` | workflows | Engineering plugin | Testing is engineering domain |
| `code-quality` | workflows | Engineering plugin | Linting/formatting is engineering domain |
| `frontend-design` | workflows | Design plugin | UI implementation is design domain |
| `ui-ux-pro-max` | workflows | Design plugin | Design planning is design domain |
| `web-design-guidelines` | workflows | Design plugin | Design review is design domain |

**Migration strategy:** Skills continue to work from workflows during transition. Domain plugins re-export them with enhanced context-awareness. Once domain plugins are stable, workflows removes the originals.

### The Inner Loop is Universal

The key architectural insight: the inner loop (`brainstorm → plan → execute → review → ship`) works identically regardless of project type. A hiring plan and a CLI tool both go through the same process — what changes is the domain context, not the process.

```
session-start → brainstorm → plan → execute → review → ship
                    ↑                   ↑          ↑
                    │                   │          │
              domain context      domain skills  domain agents
              (from plugins)      (from plugins) (from plugins)
```

---

## 9. Layer 4: Symphony Autonomous Execution

### What OpenAI Symphony Provides

Symphony (https://github.com/openai/symphony) is an Elixir/OTP application that enables autonomous code execution:

- **WORKFLOW.md** as a single contract: prompt instructions + config + runtime settings, all in one file
- **Poll-Dispatch-Resolve-Land** cycle:
  1. Daemon polls Linear for ready issues (respects blocked/dependency status)
  2. Dispatches to isolated workspaces (one per issue)
  3. Agent executes using WORKFLOW.md instructions
  4. Agent creates PR with proof of work
  5. Human reviews PR, approves or sends back
- **Harness engineering**: Engineers (3-7 per team) design environments and review boundaries. Agents write code. The team manages ~1M LOC and ~1,500 PRs.
- **Proof of work**: CI status, PR review, workpad comments on Linear issues, walkthrough videos
- **Blocker awareness**: Won't dispatch issues with unresolved blockers
- **Concurrency**: Elixir/BEAM enables up to hundreds of simultaneous agent sessions

### Integration with Brite Platform

| Symphony Feature | Brite Enhancement |
|-----------------|-------------------|
| Basic "Codex Review" | Brite's 9-agent tiered review with confidence scoring |
| WORKFLOW.md (prompt only) | WORKFLOW.md + domain plugin skills + company context |
| Prompt-enforced proof of work | System-enforced via `verification-before-completion` skill |
| No knowledge persistence | `compound-learnings` captures knowledge from autonomous runs |
| Fixed agent configuration | Dynamic agent selection based on project traits |
| No organizational context | Handbook @imports, CDR compliance checking |

### Custom Linear States

Symphony introduces Linear states beyond the defaults. Proposed adoption:

| State | Meaning | Who Transitions |
|-------|---------|----------------|
| **Backlog** | Not yet prioritized | Human |
| **Todo** | Prioritized, ready for work | Human |
| **In Progress** | Agent is actively working | Daemon (auto) |
| **Human Review** | PR created, awaiting review | Daemon (auto) |
| **Rework** | Changes requested on PR | Human |
| **Merging** | Approved, being merged | Daemon (auto) |
| **Done** | Merged and verified | Daemon (auto) |

### Workpad Pattern

Symphony uses "workpad" comments on Linear issues for structured progress tracking:

```markdown
## Workpad — BRI-1234

### Approach
[Agent's understanding of the task and planned approach]

### Progress
- [x] Set up worktree
- [x] Implemented auth middleware
- [ ] Write tests
- [ ] Verify against acceptance criteria

### Blockers
- None

### Files Changed
- src/middleware/auth.ts (new)
- src/routes/api.ts (modified)

### PR
https://github.com/Brite-Nites/repo/pull/42
```

This gives the team visibility into autonomous execution without watching agent logs.

### Long-Horizon Continuation Patterns

Autonomous agents working on complex issues may exceed a single context window. The "Ralph Loop" pattern (from LangChain's harness engineering research) addresses this:

1. Agent approaches context limit during a task
2. Harness detects the limit (via token count or compaction trigger)
3. Agent saves work-in-progress to filesystem (workpad comment + intermediate files)
4. Harness starts a fresh context window
5. Fresh context loads: original task prompt + workpad state + relevant files + plan progress
6. Agent continues from where it left off

Our `executing-plans` already implements a version of this via **subagent-per-task** — each task gets a fresh context with only its relevant state. But for tasks that are themselves too large for a single context window (e.g., a complex database migration), the daemon needs an explicit continuation strategy.

**Implementation for Symphony:**
- Workpad pattern captures progress after each significant step
- If an agent's context approaches 80% capacity, trigger a checkpoint
- Save checkpoint: files changed, tests passed, decisions made, remaining work
- Spawn continuation agent with checkpoint state
- Continuation agent reads the checkpoint and continues

This is critical for Milestone 7 (Symphony) where agents run unattended for hours.

### Fork/Adapt Strategy

Symphony is Elixir/OTP and Codex-first. Three options:

| Option | Effort | Pros | Cons |
|--------|--------|------|------|
| **Fork and adapt** | M | Keep Elixir's concurrency model (BEAM), proven architecture | Team needs Elixir expertise, Codex→Claude Code swap needed |
| **Reimplement in TypeScript** | L | Team knows TS, can integrate with existing tooling | Lose BEAM concurrency advantages, more work |
| **Hybrid** | S | Use Symphony daemon as-is for scheduling, launch Claude Code sessions instead of Codex | Minimal changes, but coupling to Elixir runtime |

**Open question:** Which approach depends on the team's Elixir comfort and the importance of high-concurrency agent execution.

---

## 10. End-to-End Scenarios

These scenarios show how the platform handles diverse project types using the same architecture.

### Scenario 1: Marketing Site for a New Product Launch

**Interview (abbreviated):**
> **Claude**: What happened that made you decide to do this now?
> **User**: We're launching a new product line in Q3 and need a landing page with waitlist signup.
> **Claude**: Walk me through how someone would discover this product today.
> **User**: They can't — it doesn't exist yet. We have a pitch deck and some brand guidelines.
> **Claude**: What does success look like?
> **User**: 500 waitlist signups before launch day. Clean, on-brand page that feels premium.
> **Claude**: What happens if the page isn't ready by Q3?
> **User**: We miss the launch window. Marketing is already buying ads pointing to a URL.

**Trait Detection:**

| Signal | Trait |
|--------|-------|
| "landing page" + "waitlist signup" | `produces-code` |
| "brand guidelines", "feels premium" | `needs-design` |
| "buying ads", "product launch" | `needs-marketing` |
| "waitlist signups" (public) | `has-external-users` |
| Q3 deadline | `client-facing` |

**Plugin Activation:**
- **Workflows** (always) — process orchestration
- **Engineering** — `produces-code` → stack selection, conventions, CI
- **Design** — `needs-design` → `design-context` skill: brand tokens, palette, typography
- **Marketing** — `needs-marketing` → `product-marketing-context` skill: ICP, positioning, messaging

**What Gets Created:**
```
project-root/
├── CLAUDE.md                          # @imports to handbook + domain contexts
├── docs/
│   ├── engineering-context.md         # Stack: Next.js, Vercel, Supabase (waitlist DB)
│   ├── design-context.md             # Brand tokens, palette, typography from guidelines
│   ├── marketing-context.md          # ICP, positioning, launch messaging
│   └── decisions/                     # Empty — ADRs generated organically
├── .github/                           # CI scaffold
└── .gitignore
```

Plus: GitHub repo in `Brite-Nites` org, Linear project with milestone "Q3 Launch".

**Inner Loop:**
1. **Brainstorm** reads `marketing-context.md` for positioning, `design-context.md` for brand → design doc for page structure, hero messaging, waitlist flow
2. **Plan** produces tasks: hero section, features grid, waitlist form + Supabase integration, OG/meta tags, analytics
3. **Execute** — subagent-per-task, each reads all three context docs
4. **Review** — Tier 1 (code, security, performance) + `typescript-reviewer` (tsconfig detected) + `accessibility-reviewer` (JSX + `has-external-users`)

### Scenario 2: Internal Documentation Site

**Interview:**
> **Claude**: What problem are you trying to solve?
> **User**: Our engineering docs are scattered across Notion, Google Docs, and random READMEs. Nobody can find anything.
> **Claude**: Walk me through the last time someone needed to find a doc and couldn't.
> **User**: New engineer spent 3 days setting up their dev environment because the onboarding doc was in a private Notion page from 2023.

**Traits:** `produces-code`, `produces-documents`
**Plugins:** Workflows + Engineering only (no design/marketing — functional is fine)

**Created:**
```
project-root/
├── CLAUDE.md
├── docs/
│   ├── engineering-context.md         # Stack: Docusaurus/Nextra, MDX, search
│   └── decisions/
└── .gitignore
```

**Inner Loop:** Brainstorm focuses on information architecture + migration strategy from Notion/Gdocs. Review: Tier 1 + `typescript-reviewer`. Lean and fast.

### Scenario 3: Hiring Plan for Engineering Team Expansion

**Interview:**
> **Claude**: What happened that made you decide to do this now?
> **User**: We just closed our Series A. Need to go from 5 to 15 engineers in 6 months.
> **Claude**: What's working today that we should keep?
> **User**: Our interview loop is solid — 4 stages, calibrated rubrics. But we have no sourcing strategy, no leveling framework, and our job descriptions are from 2 years ago.
> **Claude**: What happens if hiring doesn't hit targets by month 6?
> **User**: We miss our product roadmap commitments to the board.

**Traits:** `produces-documents`, `cross-team`, `client-facing`, `requires-decisions`
**Plugins:** Workflows only — this isn't a code project.

**Created:**
```
project-root/
├── CLAUDE.md                          # Lean — no domain plugin @imports
├── docs/
│   ├── decisions/                     # For leveling decisions, comp philosophy
│   ├── brief.md                       # Project brief: goals, constraints, timeline
│   └── outline.md                     # Document structure scaffold
└── .gitignore
```

Plus: Linear project "Engineering Hiring Plan" with milestones mapped to monthly targets.

**Inner Loop:** Brainstorm → leveling framework options, sourcing channels, timeline feasibility. Plan → tasks are document-focused: draft leveling framework, rewrite JDs, design sourcing funnel, build scorecard template. Execute → subagents produce markdown, not code. Review → only Tier 1 (structural review of documents).

**Key insight:** The inner loop works identically for non-code projects. Same brainstorm → plan → execute → review. Different outputs.

### Scenario 4: Conference Talk Preparation

**Traits:** `produces-code` (demo app), `produces-documents` (talk, slides), `has-external-users` (audience), `client-facing` (deadline)
**Plugins:** Workflows + Engineering

**Created:**
```
project-root/
├── CLAUDE.md
├── docs/
│   ├── engineering-context.md         # Demo app stack
│   ├── brief.md                       # Talk abstract, audience, key messages
│   └── outline.md                     # Talk structure
├── slides/                            # Deck scaffold
├── demo/                              # Demo app scaffold
└── .gitignore
```

**Inner Loop:** Plan interleaves doc tasks (write talk sections) with code tasks (build demo features). Unique because it produces both documents and code in the same project.

### Scenario 5: Plugin Development (Meta)

**Traits:** `produces-code`, `produces-documents`, `requires-decisions`, `automation`
**Plugins:** Workflows + Engineering

**Created:**
```
project-root/
├── CLAUDE.md                          # Plugin philosophy, skill routing table
├── docs/
│   ├── engineering-context.md         # Plugin structure conventions
│   ├── decisions/
│   └── brief.md                       # Plugin scope, target skills
├── plugins/
│   design/
│   ├── .claude-plugin/plugin.json
│   ├── commands/
│   ├── skills/
│   │   └── design-context/SKILL.md    # Foundational context-skill
│   └── agents/
└── .gitignore
```

Uses the `templates/domain-plugin/` scaffold. Project-start knows this is a plugin project and applies the plugin conventions.

### Scenario 6: Brand Identity Development

**Traits:** `produces-documents`, `needs-design`, `needs-marketing`, `requires-decisions`
**Plugins:** Workflows + Design + Marketing

**Created:**
```
project-root/
├── CLAUDE.md
├── docs/
│   ├── design-context.md              # Current brand → target brand, moodboard refs
│   ├── marketing-context.md           # Voice/tone guidelines, audience segments
│   ├── decisions/                     # Color system CDR, typography CDR
│   └── brief.md                       # Rebrand scope, constraints
└── .gitignore
```

No GitHub repo (no code). No CI. Linear project tracks deliverables. Design and Marketing plugins both activate — cross-referencing each other's context for alignment.

### Scenario 7: CLI Tool

**Traits:** `produces-code`, `automation`
**Plugins:** Workflows + Engineering

**Created:**
```
project-root/
├── CLAUDE.md
├── docs/engineering-context.md        # Node.js, commander/yargs, chokidar
├── src/
├── package.json
└── tsconfig.json
```

Lean setup. Engineering context-skill picks the stack. Pure code execution — no design, no marketing.

### Scenario 8: ML Pipeline

**Traits:** `produces-code`, `involves-data`, `automation`
**Plugins:** Workflows + Engineering

**Created:**
```
project-root/
├── CLAUDE.md
├── docs/
│   ├── engineering-context.md         # Python, FastAPI, BigQuery, sklearn/transformers
│   └── decisions/
├── pyproject.toml
├── src/
│   ├── pipeline/
│   └── api/
└── .gitignore
```

**Key difference:** `involves-data` triggers Snowflake MCP verification during setup. Project-start confirms the MCP connection works, identifies relevant datasets, notes them in `engineering-context.md`. Review agents: Tier 1 + `python-reviewer` + `data-reviewer` + `performance-reviewer`.

### Scenario 9: Database Migration

**Traits:** `produces-code`, `requires-decisions`, `involves-data`
**Plugins:** Workflows + Engineering

**Created:**
```
project-root/
├── CLAUDE.md
├── docs/
│   ├── engineering-context.md         # Existing stack, Prisma, migration strategy
│   ├── decisions/                     # Multi-tenancy approach ADR
│   └── brief.md                       # Scope, rollback plan, zero-downtime
└── .gitignore
```

**Inner Loop emphasis:** `data-reviewer` is critical — catches missing tenant scoping, unsafe migrations. `security-reviewer` flags queries without tenant filtering. Plan tasks carefully ordered with explicit rollback steps.

### Scenario 10: Vendor Evaluation (Build vs Buy)

**Traits:** `requires-decisions`, `involves-data`
**Plugins:** Workflows only — no code, no design, no marketing.

**Created:**
```
project-root/
├── CLAUDE.md
├── docs/
│   ├── decisions/                     # Will contain the build-vs-buy ADR
│   ├── brief.md                       # Evaluation criteria, stakeholders
│   └── outline.md                     # Evaluation framework
└── .gitignore
```

Purest "no code" scenario. Brainstorm produces evaluation framework. Plan tasks: research vendors, build lightweight POC, score against criteria, draft recommendation. Execute produces comparison documents. The platform handles it identically to a code project — same loop, different outputs.

### The Pattern Across All Scenarios

```
Interview (3 phases)
  → Trait classification (automatic)
    → Plugin activation (automatic)
      → Context-skill execution (automatic, per plugin)
        → Documentation scaffold (trait-conditional)
          → Infrastructure (GitHub, Linear, MCP verification)
            → Inner Loop (brainstorm → plan → execute → review → ship)
```

**What changes per scenario:**
1. Which plugins activate — determined by traits
2. What documentation is created — context docs per active plugin + trait-conditional scaffolds
3. Which review agents run — stack detection + CLAUDE.md overrides
4. What "execute" produces — code, documents, or both

**What stays the same:**
1. Interview methodology — JTBD + MI + SPIN composite, adapted in language but not structure
2. Process — brainstorm → plan → execute → review → ship
3. Infrastructure — CLAUDE.md with @imports, Linear project, git
4. Knowledge compounding — learnings feed back into CLAUDE.md and domain context docs

---

## 11. Epic Structure & Milestones

### Epic: Brite Agent Platform

**Milestone 1: Company Knowledge Layer** (M — Medium)

*Everything else depends on this. Build the knowledge foundation first.*

| # | Task | Description |
|---|------|-------------|
| 1 | Handbook repo restructure | Create `context/operational/`, `context/analytical/`, `decisions/`, `precedents/`, `org/` directories |
| 2 | Handbook CLAUDE.md | Write instructions for how agents read the handbook: file authority, CDR status meanings, context freshness rules |
| 3 | CDR format + INDEX.md | Define CDR format with Status/Context/Decision/Consequences/Exceptions. Create INDEX manifest |
| 4 | Seed initial CDRs | Document existing company decisions: Supabase, Vercel, Linear, TypeScript strict, Prisma, Tailwind, etc. |
| 5 | Operational context docs | Write `company-profile.md`, `tech-stack.md`, `brand.md`, `processes.md` |
| 6 | Org structure docs | Write `teams.md`, `roles.md`, `stakeholders.md`, `ownership.md`, `identity-map.md` |
| 7 | Analytical context: metric definitions | Write `metric-definitions.md` — what "ARR", "churn", "active user", etc. mean at Brite |
| 8 | Context refresh GitHub Action (v1) | BigQuery → `business-metrics.md` with trends/deltas. Start with BigQuery only (simpler auth). |
| 9 | Freshness tracking | Frontmatter `source`, `last_refreshed`, `refresh_cadence`. Session-start warns if stale. |
| 10 | CDR-check pattern in writing-plans | Before proposing architecture, check CDR INDEX for conflicts |
| 11 | Cross-repo @import solution | Solve how project CLAUDE.md @imports from handbook repo (submodule, symlink, copy-on-setup, or MCP) |

**Milestone 2: Project-Start Redesign** (L — Large)

*Depends on Milestone 1 — project-start needs the knowledge layer to route against.*

| # | Task | Description |
|---|------|-------------|
| 1 | Trait classification system | Define trait enum, detection signals, activation rules |
| 2 | Three-phase interview rewrite | Replace binary technical/non-technical with JTBD + MI + SPIN composite |
| 3 | Trait-conditional documentation scaffold | Generate different docs based on detected traits |
| 4 | CLAUDE.md with dynamic @imports | @imports to handbook (company context, CDRs) + domain contexts based on traits |
| 5 | GitHub repo creation | Create repo in Brite-Nites org based on `produces-code` trait |
| 6 | Plugin discovery & activation | Check installed plugins, suggest missing, trigger context-skills |
| 7 | Remove premature plan + ADR generation | Defer to brainstorm → plan flow |
| 8 | Dynamic MCP verification | Check required MCPs per trait, warn if missing |
| 9 | Express mode | Auto-detect traits from existing codebase, minimal questions |
| 10 | Brownfield support | Import existing context, reconcile with CDRs |
| 11 | Post-setup verification + smoke test | Verify all created resources are accessible and correctly configured |
| 12 | Update workflow-spec.md, workflow-guide.md, testing-guide.md | Docs alignment |
| 13 | Validation + CI | Update validate.sh for new project-start structure |

**Milestone 3: Decision Trace Architecture** (M — Medium)

*Depends on Milestone 1 (precedent database lives in handbook) and benefits from Milestone 2 (project-start creates the @import structure). Can be built incrementally alongside Milestone 4.*

| # | Task | Description |
|---|------|-------------|
| 1 | Decision trace format spec | Define the structured format for traces (decision, category, inputs, alternatives, precedent, confidence) |
| 2 | Execution trace emission | Modify executing-plans to emit structured execution traces at task checkpoints |
| 3 | Trace extraction in compound-learnings | Update compound-learnings to extract decision traces and write to `docs/precedents/` |
| 4 | Precedent promotion | Logic for promoting high-value project traces to `handbook/precedents/` |
| 5 | Precedent INDEX format | Define INDEX.md format for both project-level and org-level precedents |
| 6 | QMD evaluation for precedent search | Evaluate tobi/qmd as search backbone: index handbook + precedents, test query quality, measure latency, assess hierarchical context for CDR→trace relationships |
| 7 | `precedent-search` skill | New skill: search precedents via QMD MCP (if eval passes) or INDEX-based fallback during brainstorm/plan |
| 8 | Agent memory instrumentation | Full execution trace format (context_used, decisions_made, files_changed, verification) |
| 9 | CDR compliance review agent | New review agent (or extension of code-reviewer) that checks for CDR violations |
| 10 | Context audit trail | Ensure execution traces record what context docs were read before each decision |
| 11 | Flywheel metrics | Implement precedent hit rate, decision confidence trend, CDR coverage tracking |

**Milestone 4: Plugin Ecosystem Foundation** (L — Large)

*Can begin in parallel with Milestone 3. Depends on Milestone 2 for project-start integration.*

| # | Task | Description |
|---|------|-------------|
| 1 | Context-skill standard specification | Formal spec for how domain plugins provide context |
| 2 | Marketing plugin scaffold | BRI-1724 |
| 3 | Marketing skills port | BRI-1725 — adapt 32 skills for Brite plugin format |
| 4 | Marketing CLI tools port | BRI-1726 — adapt 68 CLI tools |
| 5 | Brite marketing context | BRI-1727 — `product-marketing-context` adapted for Brite |
| 6 | CI/docs update for multi-plugin | BRI-1728 |
| 7 | Plugin discovery in project-start | Check installed, suggest missing, install from registry |

**Milestone 5: Domain Plugin Expansion** (M per plugin)

*Each plugin is independent. Can be parallelized. Depends on Milestone 4 for the context-skill standard.*

| # | Task | Description |
|---|------|-------------|
| 1 | Engineering plugin | Extract skills from workflows, add `engineering-context`, stack advisor |
| 2 | Design plugin | Extract skills from workflows, add `design-context`, component library scaffolding |
| 3 | Sales plugin | New — `sales-context`, ICP/objection handling, proposal generation |
| 4 | Product plugin | New — `product-context`, user personas, metrics, experiment framework |

**Milestone 6: Context Refresh Pipeline** (M — Medium)

*Depends on Milestone 1 (handbook structure). Can be built after the knowledge layer is stable.*

| # | Task | Description |
|---|------|-------------|
| 1 | Salesforce MCP evaluation | Evaluate existing Salesforce MCPs or build connector |
| 2 | Context refresh: Salesforce → customers.md | Automated pipeline with trend computation |
| 3 | Context refresh: BigQuery → business-metrics.md | Enhance v1 action with full trend/delta computation |
| 4 | Temporal diff computation | Compare new snapshot against previous committed version for delta tracking |
| 5 | Refresh PR workflow | Automated PRs for significant changes, auto-merge for minor updates |
| 6 | PII handling | Implement anonymization or access controls for sensitive context |

**Milestone 7: Symphony Autonomous Execution** (XL — Extra Large)

*The capstone. Depends on Milestones 1-5 being stable. This is where teams manage Linear, agents execute.*

| # | Task | Description |
|---|------|-------------|
| 1 | Fork/adapt decision | Evaluate Elixir fork vs TS reimplement vs hybrid |
| 2 | WORKFLOW.md standard | Define for Brite repos, referencing domain plugin skills + context docs |
| 3 | Poll-Dispatch-Resolve-Land cycle | Core daemon implementation |
| 4 | Integration with Brite review agents | Replace Codex Review with tiered multi-agent review |
| 5 | Workpad pattern | Structured progress comments on Linear issues |
| 6 | Custom Linear states | Human Review, Rework, Merging states |
| 7 | Proof of work system | CI + PR + workpad + verification-before-completion |
| 8 | Decision trace emission in autonomous mode | Ensure autonomous agents emit traces same as interactive |
| 9 | Concurrency management | Multiple simultaneous agent sessions |
| 10 | Cost management + budgeting | Per-issue caps, total budget limits, model selection rules |
| 11 | Failure mode handling | Timeout, blocker detection, human escalation |
| 12 | compound-learnings integration | Knowledge capture from autonomous runs feeds back to handbook |

**Milestone 8: Context Governance & Observability** (S — Small)

*Cross-cutting. Can be incrementally added once Milestones 1-3 are working.*

| # | Task | Description |
|---|------|-------------|
| 1 | CDR governance model | Authority levels, PR process, conflict resolution |
| 2 | Context quality dashboard | Freshness tracking, CDR coverage, precedent hit rate |
| 3 | Flywheel monitoring | Decision confidence trends, override rates, context usage analytics |
| 4 | Context governance review agent | Agent that audits context quality and flags drift |

### What Happens to BRI-1337

**Close BRI-1337 as superseded.** Create the new epic with Milestone 1 as the first set of issues. The framework template concept from BRI-1337 is subsumed by:
- Convention specs → domain plugin context-skills
- Environment setup → project-start's trait-conditional configuration
- The interview redesign → far beyond what BRI-1337 scoped

---

## 12. Open Questions

### Architecture

1. **Symphony runtime**: Fork Elixir, reimplement in TS/Python, or hybrid? Depends on team's Elixir comfort and concurrency requirements. Need to evaluate: how many simultaneous agents does Brite realistically need?

2. **Skill migration strategy**: When extracting skills from workflows to domain plugins, how to handle the transition? Options: (a) domain plugins re-export from workflows during transition, (b) workflows keeps copies until domain plugins are stable, (c) breaking change with migration guide.

3. **AGENTS.md**: Should project-start generate AGENTS.md alongside CLAUDE.md for cross-tool compatibility? The standard is adopted by 60k+ repos (Linux Foundation backed), but it's still maturing. Could be a quick win for projects that use multiple AI tools.

4. ~~**Plugin marketplace vs monorepo**~~: **Resolved** — Monorepo marketplace. See [ADR-003](../decisions/003-plugin-distribution-architecture.md). Matches Anthropic's official distribution model; existing infrastructure already supports multi-plugin. Community plugins use separate repos/marketplaces.

5. **Handbook repo cross-references**: How do @imports work cross-repo? CLAUDE.md @imports resolve relative to the project. Handbook lives in a separate repo. Options: (a) git submodule, (b) symlink, (c) copy-on-setup script, (d) MCP-based fetch.

### Interview & Classification

6. **Interview length**: The three-phase methodology could take 15-20 minutes for a complex project. Is there a "quick start" that captures essentials in 3 minutes? Express mode covers brownfield, but what about greenfield projects where the user is in a hurry?

7. **Trait granularity**: Are 11 traits the right number? Too few = can't differentiate. Too many = classification noise. Should traits have sub-traits (e.g., `produces-code:frontend` vs `produces-code:backend`)?

8. **Non-obvious trait combinations**: Some trait combinations are unexpected (e.g., `involves-data` + `needs-sales` for a data-driven sales tool). Do we need trait-interaction rules, or can plugins handle edge cases independently?

9. **Trait evolution**: Projects change over time. A "documentation site" might gain `produces-code` when someone adds interactive features. How does the platform handle trait changes mid-project? Re-run classification? Manual override?

### Knowledge Architecture

10. **Salesforce MCP**: Does a reliable Salesforce MCP exist for the context refresh pipeline? If not, do we build one or use the Salesforce API directly from the GitHub Action?

11. **CDR governance**: Who can create/modify CDRs? Is it an ADR-style PR process, or do only specific roles (engineering lead, CTO) have authority? How are CDR conflicts between decisions resolved? (Partially addressed in Context Governance section — needs finalization.)

12. **Context freshness enforcement**: If a context doc is stale (past its refresh cadence), should session-start block or just warn? Blocking is safer but annoying. Warning might be ignored.

13. **Handbook CLAUDE.md**: What goes in the handbook's own CLAUDE.md? It needs to instruct agents on how to read the handbook — which files are authoritative, how to interpret CDR statuses, what "Active" vs "Superseded" means.

14. **PII in materialized context**: The `customers.md` file (from Salesforce) could contain customer names, contract values, etc. How do we handle PII in the handbook? Options: (a) anonymize in the refresh pipeline, (b) separate private context that's not committed, (c) rely on private repo access controls.

### Decision Traces & Context Graphs

15. **Decision trace volume**: Agents make dozens of decisions per session. If we trace all of them, the precedent database grows fast. What's the filtering threshold? Only trace decisions above a certain confidence? Only certain categories?

16. **Precedent search quality**: Searching past decisions by similarity is fundamentally an embedding/RAG problem. We don't have vector search infrastructure. Options: (a) keyword/tag-based search via INDEX.md (simple, limited), (b) agent reads INDEX and judges similarity (uses context window but works today), (c) use QMD (see below) for local hybrid search via MCP, (d) build custom vector search later. **Research task: Evaluate QMD** (https://github.com/tobi/qmd) — Tobi Lutke's (Shopify) on-device search engine. QMD combines BM25 full-text + vector semantic search + LLM re-ranking, all running locally via node-llama-cpp with GGUF models. Critically, it exposes an **MCP server** (`query`, `get`, `multi_get`, `status` tools) — meaning Claude Code can query it natively. It supports hierarchical context (parent-child relationships between documents), which maps perfectly to CDRs → decision traces. Evaluation should cover: (1) index the handbook + precedents into QMD, (2) test query quality for precedent search ("find decisions about multi-tenancy"), (3) measure latency and resource usage, (4) assess whether QMD's hierarchical context model can represent CDR → ADR → decision trace relationships. If QMD works, it replaces the need for custom vector search infrastructure entirely and becomes the search backbone for the precedent database.

17. **Trace promotion criteria**: When should a project-level precedent be promoted to the org-level handbook? Options: (a) manual curation during /ship, (b) automatic if confidence >= 8 and category is architecture/library-selection, (c) human review via PR to handbook.

18. **Cross-project trace deduplication**: Multiple projects may solve the same problem differently. How do we handle conflicting precedents? Latest wins? Highest confidence wins? Present all and let the agent choose?

19. **Operational vs analytical context split**: Is this distinction actually useful in practice, or is it premature abstraction? Could we start with a flat `context/` directory and split later if needed?

20. **Identity map maintenance**: Who keeps the cross-system identity map (`org/identity-map.md`) up to date? Manual maintenance is error-prone. Could this be auto-generated from HR system or GitHub org?

### Autonomous Execution

21. **Trust boundaries**: In Symphony's model, agents create PRs that humans review. But what about non-code outputs (documents, decisions, plans)? Do those also go through a review gate? Or can agents autonomously ship documents?

22. **Cost management**: Autonomous agents running Opus-level models on hundreds of simultaneous issues could be expensive. What's the cost model? Per-issue caps? Total budget limits?

23. **Failure modes**: What happens when an autonomous agent gets stuck? Symphony has a "blocker" concept, but what about agents that spin without progress? Timeout? Human escalation?

24. **Context window pressure**: Autonomous agents running complex tasks may hit context limits. If we @import company context + domain context + project context + CDR INDEX, we could eat 30-50% of context before any code is loaded. How does the daemon handle context compression or task splitting?

### Cross-Cutting Concerns

25. **Cross-repo @imports (BLOCKER)**: CLAUDE.md @imports resolve relative to the project. The handbook is a separate repo. This is a real technical blocker. Options: (a) git submodule pointing to handbook, (b) symlink from project to local handbook clone, (c) copy-on-setup script that pulls relevant handbook files into the project, (d) MCP server that serves handbook content. Need to prototype and evaluate.

26. **The "too much context" problem**: More context isn't always better. An agent drowning in company context + domain context + CDR INDEX + precedent search results might perform worse than one with just the task description. Need to measure: does adding context actually improve decision quality? At what point does it degrade?

27. **Chicken-and-egg with plugins**: Project-start routes to plugins, but plugins don't exist yet (except workflows). Need to build project-start with graceful degradation: works with zero domain plugins (just workflows), progressively better as plugins are added.

28. **Handbook maintenance burden**: If the handbook is not maintained, agents read stale/wrong context and make bad decisions — potentially worse than no context at all. Who owns handbook maintenance? How do we make it low-friction enough that it actually gets done?

---

## Appendix A: Reference Implementations

### Superpowers (78k stars)
- **Repo**: https://github.com/obra/superpowers
- **Key pattern**: No project-start at all. Brainstorming is the entry point. Workflow discipline over setup ceremony.
- **Relevance**: Validates our decision to defer V1 plans to the brainstorm flow rather than generating them in project-start.

### Compound Engineering (10.3k stars)
- **Repo**: https://github.com/EveryInc/compound-engineering-plugin
- **Key pattern**: Lightweight setup. Knowledge compounds via `docs/solutions/`. `learnings-researcher` agent retrieves past solutions before starting new work.
- **Relevance**: Validates our compound-learnings skill and the knowledge-compounding philosophy. The `learnings-researcher` pattern could inform how session-start pulls from previous sessions.

### Agency-Agents (msitarzewski)
- **Repo**: https://github.com/msitarzewski/agency-agents
- **Key pattern**: 120+ agents organized by 12 business divisions. NEXUS 7-phase orchestration. Division-as-directory taxonomy.
- **Relevance**: Validates the multi-domain plugin architecture. Their division taxonomy (engineering, design, marketing, paid media, sales, product, PM, testing, support, spatial computing, game dev, specialized) is broader than our current 6 plugins — indicates room for expansion.
- **Divisions**: Engineering, Design, Marketing, Paid Media, Sales, Product, Project Management, Testing/QA, Customer Support, Spatial Computing, Game Dev, Specialized

### Marketingskills (coreyhaines31)
- **Repo**: https://github.com/coreyhaines31/marketingskills
- **Key pattern**: 32 skills + 68 CLI tools. `product-marketing-context` creates foundational context all other skills read.
- **Relevance**: Direct source for the Marketing plugin (BRI-1724-1728). The context-skill pattern is the standard we're adopting for ALL domain plugins.

### OpenAI Symphony
- **Repo**: https://github.com/openai/symphony
- **Key pattern**: Elixir/OTP daemon. WORKFLOW.md contract. Poll-Dispatch-Resolve-Land cycle. Harness engineering (~3-7 engineers, ~1M LOC, ~1,500 PRs).
- **Relevance**: Blueprint for Layer 4 (autonomous execution). Their WORKFLOW.md concept maps to our CLAUDE.md + domain context docs. Their proof-of-work system maps to our verification-before-completion skill.

### AGENTS.md
- **Adoption**: 60k+ repos
- **Standard**: Universal cross-tool agent configuration file backed by Linux Foundation
- **Relevance**: Potential supplement to CLAUDE.md for cross-tool compatibility.

### QMD — On-Device Search Engine (tobi/Shopify)
- **Repo**: https://github.com/tobi/qmd
- **Author**: Tobi Lutke (Shopify CEO)
- **What it is**: An on-device search engine that combines three complementary search mechanisms: BM25 full-text search (fast keyword matching), vector semantic search (embedding-based similarity), and LLM re-ranking (quality-based ordering). All components run locally via node-llama-cpp with GGUF models — no external API dependencies.
- **MCP Integration**: Exposes an MCP server with tools: `query` (hybrid search with typed sub-queries and reranking), `get` (document retrieval by path/ID), `multi_get` (batch retrieval via glob patterns), `status` (index health). Claude Code can query it natively via MCP.
- **Hierarchical Context**: Documents have parent-child relationships. When a sub-document matches, its parent context is automatically returned. This maps directly to CDR → ADR → decision trace relationships.
- **Technical details**: SQLite backend, embeddings cached to avoid recomputation, query expansion (natural language → typed sub-queries via LLM → reciprocal rank fusion). Available as npm package (`@tobilu/qmd`) for programmatic use.
- **Relevance**: Could be the search backbone for our precedent database. Instead of building custom vector search infrastructure, index the handbook (CDRs, precedents, context docs) into QMD and query via MCP during brainstorm/plan phases. The hierarchical context model is a particularly good fit — a CDR is the parent context for the decision traces that reference it.
- **Research task**: Evaluate by (1) indexing handbook + precedents, (2) testing query quality for precedent search, (3) measuring latency/resource usage, (4) assessing hierarchical context for CDR → trace relationships.

### Foundation Capital — Context Graphs Thesis (Dec 2025)
- **Source**: https://foundationcapital.com/ideas/context-graphs-ais-trillion-dollar-opportunity
- **Authors**: Jaya Gupta, Ashu Garg (Foundation Capital)
- **Key thesis**: The next trillion-dollar enterprise platforms will be built by those who capture *decision traces* — the reasoning behind decisions, not just the outcomes. They call this accumulated structure a "context graph" — a living record of decision traces stitched across entities and time, where precedent becomes searchable.
- **Three startup paths**: (1) Full replacement — AI-native systems replacing legacy platforms (e.g., Regie in sales), (2) Module replacement — automating specific workflows while syncing to incumbents (e.g., Maximor in finance), (3) New systems of record — capturing decision lineage as entirely new source of truth (e.g., PlayerZero in production engineering).
- **Key distinction**: Rules ("use official ARR for reporting") vs Decision traces ("we used X definition, under policy v3.2, with a VP exception, based on precedent Z").
- **Why incumbents can't build this**: They store current state only (losing historical decision context), remain siloed within single systems, and are read-path (warehouses) rather than execution-path positioned.
- **Our structural advantage**: The workflows plugin is in the execution path. We witness every decision.
- **Relevance**: Directly inspired our Decision Trace Architecture, Precedent Database, and Context Flywheel concepts. Validates the CDR pattern. Provides the theoretical framework for why context compounding is a moat.
- **Engagement**: 17,000+ bookmarks, most-discussed AI enterprise thesis of 2025.

### Metadata Weekly — "Who Actually Captures It?" (Response to Foundation Capital)
- **Source**: https://metadataweekly.substack.com/p/context-graphs-are-a-trillion-dollar
- **Author**: Prukalpa (Metadata Weekly / Atlan)
- **Counter-thesis**: Foundation Capital is right about context graphs being valuable but wrong about WHO captures them. Vertical agents (sales agent, support agent) only see their workflow's execution path. Context is GLOBAL — a single renewal decision spans PagerDuty, Zendesk, Slack, Salesforce, Snowflake.
- **Key framework**: Operational context (SOPs, identity resolution, ownership) vs Analytical context (metric definitions, calculations). Both needed, both distinct.
- **Six requirements**: Cross-system connectivity, operational context synthesis, analytical context management, inference-time delivery, feedback loops, governance.
- **Customer-owned architecture**: Enterprises learned from cloud warehouses that ceding control of strategic assets (data, decision-making logic) to vendors creates lock-in. Context platforms must be customer-owned, open, federated.
- **Relevance**: Directly inspired our operational/analytical context split, identity resolution, ownership mapping, and the principle that Brite owns its context (handbook repo) rather than locking it in vendor silos.

### Graphlit — "The Context Layer AI Agents Actually Need"
- **Source**: https://www.graphlit.com/blog/context-layer-ai-agents-need
- **Key insight**: Two-layer architecture — operational context foundation (identity resolution, ownership mapping, temporal state tracking, cross-system synthesis) UNDERNEATH decision context layer (policy versions, exceptions, approver chains, precedent references).
- **Technical patterns**: Schema.org + JSON-LD for entity modeling. MCP for agent interoperability. CRM as entity spine for organizing multimodal content.
- **Core criticism of current approaches**: RAG and basic AI memory fail because they treat organizational knowledge as documents to embed or chat transcripts to recall, rather than as a temporal, relational graph.
- **Relevance**: Inspired our temporal context pattern (trends/deltas instead of snapshots), agent memory instrumentation, and the distinction between operational and decision context layers.

---

## Appendix B: Interview Methodology Sources

| Methodology | Origin | Key Concept | Best For |
|-------------|--------|-------------|----------|
| **Jobs-to-Be-Done** | Clayton Christensen (Harvard) | "What job did you hire this product to do?" + trigger/forces model | Understanding true motivation |
| **Motivational Interviewing** | Miller & Rollnick (1991) | OARS: Open questions, Affirmations, Reflective listening, Summaries | Building trust, reducing resistance |
| **SPIN Selling** | Neil Rackham (1988) | Situation → Problem → Implication → Need-payoff | Revealing priority through consequences |
| **Design Thinking** | Stanford d.school / IDEO | Empathize → Define → Ideate → Prototype → Test | Story-based context extraction |
| **Impact Mapping** | Gojko Adzic (2012) | Goal → Actors → Impacts → Deliverables | Connecting work to outcomes |
| **Story Mapping** | Jeff Patton (2014) | User activities → tasks → details (walking skeleton) | Defining MVP and scope |
| **Lean Canvas** | Ash Maurya (2012) | 1-page business model: problem, solution, key metrics, unfair advantage | Forcing focus and prioritization |
| **Five Whys** | Sakichi Toyoda (Toyota) | Ask "why" 5 times to find root cause | Drilling from solution to problem |
| **Appreciative Inquiry** | Cooperrider & Srivastva (1987) | Discover → Dream → Design → Destiny (focus on what works) | Preserving existing value |

---

## Appendix C: 50 Project Scenarios

During brainstorming, 50 project scenarios were identified across 9 categories. Each demonstrates a unique trait combination that project-start must handle.

### Software Development (12)
1. Marketing/landing site — `produces-code`, `needs-design`, `needs-marketing`, `has-external-users`
2. Internal tool (admin dashboard) — `produces-code`, `involves-data`
3. API/backend service — `produces-code`, `automation`
4. Mobile app — `produces-code`, `needs-design`, `has-external-users`
5. CLI tool — `produces-code`, `automation`
6. Browser extension — `produces-code`, `has-external-users`
7. Data pipeline — `produces-code`, `involves-data`, `automation`
8. ML model/service — `produces-code`, `involves-data`, `automation`
9. E-commerce store — `produces-code`, `needs-design`, `needs-marketing`, `needs-sales`, `has-external-users`
10. Documentation site — `produces-code`, `produces-documents`
11. Design system/component library — `produces-code`, `needs-design`
12. Plugin/extension development — `produces-code`, `produces-documents`, `requires-decisions`

### Content & Communication (7)
13. Blog/content strategy — `produces-documents`, `needs-marketing`
14. Newsletter launch — `produces-documents`, `needs-marketing`, `has-external-users`
15. Conference talk — `produces-documents`, `produces-code` (demo), `has-external-users`
16. Podcast launch — `produces-documents`, `needs-marketing`
17. Technical writing — `produces-documents`
18. Training/course material — `produces-documents`, `has-external-users`
19. Case study — `produces-documents`, `needs-marketing`, `needs-sales`

### Business Strategy (6)
20. Vendor evaluation (build vs buy) — `requires-decisions`, `involves-data`
21. Pricing strategy — `requires-decisions`, `needs-sales`, `involves-data`
22. Market entry analysis — `requires-decisions`, `needs-marketing`, `involves-data`
23. Partnership evaluation — `requires-decisions`, `needs-sales`
24. Budget planning — `requires-decisions`, `involves-data`, `cross-team`
25. OKR setting — `requires-decisions`, `cross-team`

### Process Improvement (5)
26. Workflow optimization — `requires-decisions`, `cross-team`
27. Incident response process — `produces-documents`, `cross-team`
28. Code review process — `produces-documents`
29. Onboarding improvement — `produces-documents`, `cross-team`
30. Sprint/agile process — `produces-documents`, `cross-team`

### Product (6)
31. Feature specification — `produces-documents`, `requires-decisions`
32. User research — `produces-documents`, `involves-data`, `has-external-users`
33. A/B test design — `involves-data`, `produces-code`, `has-external-users`
34. Product roadmap — `produces-documents`, `requires-decisions`, `cross-team`
35. Competitive analysis — `produces-documents`, `needs-marketing`, `involves-data`
36. Customer feedback synthesis — `produces-documents`, `involves-data`

### Data & Analytics (5)
37. Dashboard/report — `involves-data`, `produces-code`
38. Data warehouse modeling — `involves-data`, `produces-code`
39. Analytics implementation — `involves-data`, `produces-code`, `has-external-users`
40. Data migration — `involves-data`, `produces-code`, `requires-decisions`
41. Metric definition — `involves-data`, `produces-documents`, `cross-team`

### Organizational (4)
42. Hiring plan — `produces-documents`, `cross-team`, `client-facing`, `requires-decisions`
43. Team restructuring — `requires-decisions`, `cross-team`
44. Role/leveling framework — `produces-documents`, `requires-decisions`, `cross-team`
45. Compensation review — `requires-decisions`, `involves-data`, `cross-team`

### Client-Facing (3)
46. Client proposal — `produces-documents`, `needs-sales`, `client-facing`
47. Client onboarding — `produces-documents`, `client-facing`
48. SOW/contract — `produces-documents`, `client-facing`, `requires-decisions`

### Meta/Platform (2)
49. Plugin development — `produces-code`, `produces-documents`, `requires-decisions`, `automation`
50. Platform migration — `produces-code`, `involves-data`, `requires-decisions`, `cross-team`

---

## Appendix D: Agency-Agents Taxonomy

From [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — 120+ agents across 12 business divisions. This taxonomy validates the multi-domain plugin architecture and indicates potential expansion areas beyond our initial 6 plugins.

| Division | Agent Count | Example Agents | Maps to Brite Plugin |
|----------|-------------|---------------|---------------------|
| Engineering | 15+ | architect, code-reviewer, devops, security, performance | Engineering |
| Design | 10+ | ui-designer, ux-researcher, brand-designer, motion-designer | Design |
| Marketing | 12+ | content-strategist, social-media, email-marketer, seo-specialist | Marketing |
| Paid Media | 8+ | google-ads, meta-ads, programmatic, attribution | Marketing (sub-domain) |
| Sales | 10+ | outbound, demo-prep, proposal-writer, negotiation | Sales |
| Product | 8+ | product-manager, feature-prioritizer, roadmap-planner | Product |
| Project Management | 6+ | sprint-planner, retrospective, risk-assessor | Workflows (process) |
| Testing/QA | 8+ | test-planner, automation-engineer, accessibility-tester | Engineering (sub-domain) |
| Customer Support | 5+ | ticket-triager, knowledge-base, escalation | Future plugin |
| Spatial Computing | 4+ | ar-developer, 3d-modeler | Niche — unlikely for Brite |
| Game Dev | 5+ | game-designer, level-designer | Niche — unlikely for Brite |
| Specialized | 10+ | legal-reviewer, compliance, finance | Future plugins |

**Key insight from this taxonomy:** The agent-per-division model maps directly to our plugin-per-domain model. Each division is a plugin with its own context-skill and specialized agents. The NEXUS 7-phase orchestration is analogous to our inner loop.

**Divisions we should consider adding:**
- **Customer Support** — ticket triage, knowledge base, escalation procedures
- **Legal/Compliance** — contract review, compliance checking, policy writing
- **Finance** — budget analysis, forecasting, expense review

These could be future Milestone 4+ plugins as Brite's needs grow.
