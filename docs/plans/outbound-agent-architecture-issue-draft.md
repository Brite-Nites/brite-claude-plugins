# Linear Issue Draft: Outbound Agent Architecture Design

**Title:** Design: Outbound agent architecture — MCP servers, skill orchestration, cross-repo patterns
**Priority:** Urgent
**Labels:** skill, architecture
**Milestone:** Marketing Skills Plugin
**Blocks:** BC-2714, BC-2717, BC-2718, BC-2719, BC-2720, BC-2721, BC-2722

---

## Goal

Design the integration architecture for outbound sales agent skills before building them. A prior research session (2026-04-01) mapped Brite's outbound pipeline across 3 repos and discovered that the skill design depends on unresolved architecture questions about MCP servers, tool access patterns, and cross-repo orchestration. This issue resolves those questions.

**Output:** `docs/designs/outbound-agent-architecture.md`

**Starting context (requires independent validation):** `docs/research/outbound-pipeline-research-wip.md` — contains pipeline layer mapping, MCP server landscape, pain points, and open design questions from the prior session. **Do not take this document at face value.** Phase 1 of this issue independently validates every claim.

---

## Why This Blocks Everything

The 5 planned outbound skills (list-building, campaign-orchestration, deliverability-audit, reply-processing, campaign-analysis) and the outbound-playbook conductor skill all need to orchestrate multiple external tools across 3 repos. Without a settled architecture for how skills access tools, each skill would make ad-hoc integration decisions that conflict.

Specifically:
- Skills need to invoke MCP tools — but which MCP servers are adopted, and how are they configured?
- Two critical tools (OutboundSync, Master Inbox) have no MCP servers — do we build them, use CLI wrappers, or find alternatives?
- Agents working in `outbound-sales-ops` need Salesforce data from `brite-salesforce` and enrichment data from `brite-data-platform` — what's the cross-repo access pattern?
- The upstream skill pattern (coreyhaines31/marketingskills) uses CLI wrappers; the modern ecosystem uses MCP servers. Which pattern does Brite adopt?

---

## Phase 1: Validate Prior Research

The prior session's findings need independent verification. For each item below, read the actual source and confirm or correct.

### 1a. Verify MCP server availability
For each MCP server listed in the research WIP:
- [ ] **Salesforce DX** (`@salesforce/mcp`): Verify it exists on npm/GitHub. Read its README. Confirm toolsets (orgs, metadata, data, users). Test installation: `npx -y @salesforce/mcp --help` or equivalent.
- [ ] **Apollo** (`apolloio/apollo-mcp-plugin`): Verify GitHub repo. Read README. Confirm capabilities (enrich, prospect, sequence-load, analytics). Check auth requirements (OAuth? API key?).
- [ ] **Email Bison** (`emailbison-mcp-server`): Verify it exists. Read source. Confirm it's read-only. Check if write capabilities exist or are planned.
- [ ] **Smartlead** (`LeadMagic/smartlead-mcp-server`): Verify GitHub repo. Confirm 116+ tools claim. Read tool list.
- [ ] **Resend** (`resend/resend-mcp`): Verify GitHub repo. Read capabilities.
- [ ] **OutboundSync**: Confirm no MCP server exists. Check their docs/API for what's available.
- [ ] **Master Inbox**: Confirm no MCP server exists. Check their docs/API.
- [ ] Search for any NEW MCP servers that appeared since the research (search GitHub, skills.sh, npm for `mcp-server-*` related to outbound sales tools).

### 1b. Verify repo architectures
For each Brite repo, confirm the claims in the research WIP by reading key files:
- [ ] `brite-data-platform`: Confirm enrichment CLI interface, golden record schema, audience view status
- [ ] `outbound-sales-ops`: Confirm CF architecture, Master Inbox integration, architectural rules
- [ ] `brite-salesforce`: Confirm lifecycle stages, Territory__c, integration points

### 1c. Verify tool stack
- [ ] Confirm Email Bison is the only sequencer (Smartlead fully deprecated?)
- [ ] Confirm Aircall → Dialpad migration status
- [ ] Confirm HubSpot → Salesforce migration status and current blockers
- [ ] Check if any new tools have been adopted since the research

---

## Phase 2: Design Decisions

For each question, evaluate options, document tradeoffs, and recommend a path. Use the ADR format (Decision / Context / Alternatives / Outcome).

### 2a. MCP Server Adoption Strategy
**Question:** Which MCP servers does the marketing plugin adopt? How are they configured?

Consider:
- Which are mature enough for production use?
- How do they authenticate? (API keys, OAuth, JWT)
- Where do credentials live? (env vars, Vercel secrets, plugin config)
- How are they declared in the plugin's `.mcp.json`?
- What happens when a MCP server is unavailable? (graceful degradation)

### 2b. Custom MCP Server Strategy
**Question:** For tools without MCP servers (OutboundSync, Master Inbox), what do we build?

Options to evaluate:
1. Build custom MCP servers (TypeScript, following the MCP spec)
2. Build CLI wrappers (following upstream marketingskills pattern)
3. Use the existing Cloud Functions in outbound-sales-ops as the integration layer
4. Wait for vendors to build official MCP servers
5. Hybrid — CLI wrapper now, MCP server later

Consider: API surface of each tool, auth patterns, read vs write needs, maintenance burden.

### 2c. Skill-to-MCP Orchestration Pattern
**Question:** How do skills reference and invoke MCP server tools?

The upstream marketingskills pattern: skills have a "Tool Integrations" table pointing to CLI wrappers. Skills advise; tools execute. What's the equivalent for MCP?

Consider:
- Can SKILL.md files declare MCP tool dependencies?
- How does a skill instruct Claude to call a specific MCP tool?
- How do skills handle tool unavailability (MCP not configured)?
- Should skills embed tool-specific instructions or reference external integration guides?

### 2d. Cross-Repo Agent Patterns
**Question:** When an agent working in repo A needs data from repo B, what's the pattern?

Scenarios:
- Agent in `outbound-sales-ops` needs to check Salesforce lifecycle stage → uses SF MCP
- Agent in `brite-data-platform` needs to update Email Bison block list → uses EB MCP? Or calls outbound-sales-ops CF?
- Agent in plugins repo building a skill needs to understand all three repos

Consider: MCP servers as the universal access layer vs. repo-specific CLIs vs. API calls.

### 2e. Audience View Architecture
**Question:** Where does campaign targeting/filtering logic live?

The golden records (dim_people, dim_companies) exist in Snowflake but audience views (filtered subsets for specific campaigns) are planned but not built. Where should this logic live?

Options:
1. dbt models in brite-data-platform (SQL views in Snowflake)
2. Skill-generated queries (skill teaches Claude to write the right SQL)
3. Email Bison list management (filtering happens in the sequencer)
4. Hybrid — dbt for standard audiences, skill-generated for ad-hoc

### 2f. Skill Design Pattern for Outbound
**Question:** What's the template for an outbound skill?

Based on decisions 2a-2e, define the standard structure:
- Frontmatter (name, description, MCP dependencies?)
- Methodology section (best practices, frameworks — portable knowledge)
- Brite Implementation section (specific tools, repos, architectural rules)
- MCP tool reference section (which tools to call, when)
- Operational runbook section (step-by-step for common tasks)
- Health scoring rubric + anti-slop guardrails (per upstream pattern)

---

## Phase 3: Document

### 3a. Write the design doc
- [ ] Write `docs/designs/outbound-agent-architecture.md` with all decisions from Phase 2
- [ ] Include architecture diagram (text-based, showing skill → MCP → API → repo relationships)
- [ ] Include a worked example: walk through "agent builds a prospect list and loads it into Email Bison" end-to-end, showing which skills activate, which MCP tools get called, and which repos are involved

### 3b. Update dependent artifacts
- [ ] Update `docs/research/outbound-pipeline-research-wip.md` with any corrections from Phase 1 validation, then rename to `outbound-pipeline-findings.md` (completing BC-2714's output)
- [ ] Update BC-2714 acceptance criteria if scope changed
- [ ] Create a skill template file at `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` based on the pattern from 2f

---

## Acceptance Criteria

- [ ] Every MCP server claim from the research WIP independently verified (installed or tested where possible)
- [ ] Every repo architecture claim spot-checked against current code
- [ ] Design decisions documented for all 6 questions (2a-2f) with ADR format
- [ ] Architecture design doc written at `docs/designs/outbound-agent-architecture.md`
- [ ] Worked end-to-end example included
- [ ] Outbound skill template created
- [ ] Research WIP promoted to final findings doc (completing BC-2714)
