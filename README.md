# Brite Claude Plugins

A **Process + Org** plugin for Claude Code. Superpowers methodology + compound engineering + Linear integration — structured workflow (brainstorm → plan → worktree → execute → review → compound → audit) with Linear woven into every step.

**Versions:** per-plugin — see [marketplace.json](.claude-plugin/marketplace.json) | [Changelog](CHANGELOG.md) | [Roadmap](ROADMAP.md)

## Philosophy

This plugin teaches *how* to work, not *what* to know about specific technologies:

```
session-start → brainstorm → plan → [worktree] → execute (subagent + TDD) → review → ship (compound + audit)
       ↑                                                                                         |
       └───────────────────── scope (creative discovery) ←───────────────────────────────────────┘
```

- **Process**: Superpowers' full workflow with TDD, subagent-per-task execution, and compound knowledge
- **Org**: Linear integration at every step, security hooks, team conventions
- **Domain skills are separate plugins** — tech-stack knowledge lives in dedicated domain plugins

Influenced by [superpowers](https://github.com/obra/superpowers) and [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin). See the [Roadmap](ROADMAP.md) for what's coming next.

## Vision: Brite Agent Platform

This plugin is evolving into a four-layer platform for universal project routing, domain-specific knowledge, structured workflows, and autonomous execution.

| Layer | Milestone | What it delivers |
|-------|-----------|-----------------|
| Knowledge | Company Knowledge Layer | Handbook repo as company brain — CDRs, context, precedents |
| Routing | Project-Start Redesign | Trait-based classification routes any project type |
| Traces | Decision Trace Architecture | Structured reasoning traces compound into searchable precedents |
| Plugins | Plugin Ecosystem | Domain plugins (marketing, engineering, design, sales, product) |
| Refresh | Context Refresh Pipeline | Automated BigQuery + Salesforce → handbook context |
| Autonomous | Symphony Execution | Agents execute Linear issues autonomously |
| Governance | Context Governance | Quality dashboards, CDR governance, flywheel monitoring |

See the [Platform Design Document](docs/designs/brite-agent-platform.md) for the full PRD.

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- Node.js 18+ (for MCP servers)

## Quick Start

Register the marketplace, then install the plugin you want:

```bash
claude plugin marketplace add Brite-Nites/brite-claude-plugins
claude plugin install workflows@brite-claude-plugins
```

The other plugins in this repo (`marketing`, `revops`, `cadence`, `flow-architecture`, `brite-core`) install the same way — swap the name before `@`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full install and configuration reference.

Verify installation by typing `/workflows:` in Claude Code — you should see the available commands in the slash menu.

## Plugins in this repo

This is a multi-plugin bundle. `workflows` is the primary Process + Org plugin (its commands are listed below); the others are domain plugins that install the same way. Versions are per-plugin — see [marketplace.json](.claude-plugin/marketplace.json).

| Plugin | Purpose |
|--------|---------|
| `workflows` | Process + Org — structured workflow methodology with Linear integration |
| `marketing` | Brand-aware marketing skills (GTM, campaigns, TAM mapping, outbound) |
| `revops` | Salesforce development + CRM data skills (Brite customizations on Jaganpro/sf-skills) |
| `cadence` | Weekly planning cadence — audit, scope, housekeep, narrate |
| `flow-architecture` | Flow-Driven Architecture — scaffolds Linear domain milestones + repo flow docs |
| `brite-core` | Cross-cutting brain-first hooks (SessionStart/SubagentStart) + centralized security/quality hooks |

## Available Commands

The commands below belong to the `workflows` plugin.

**Core workflow (the inner loop):**

| Command | Description |
|---------|-------------|
| `/workflows:session-start` | Start a work session — pick a Linear issue, brainstorm, plan, execute |
| `/workflows:review` | Run review agents in parallel, fix P1s, report findings |
| `/workflows:ship` | Create PR, update Linear, compound learnings, best-practices audit |

**Direction-setting:**

| Command | Description |
|---------|-------------|
| `/workflows:scope` | Collaborative scoping session — discover what to build, create Linear issues |
| `/workflows:project-start` | Start a new project with a guided interview |
| `/workflows:sprint-planning` | Plan sprint and assign issues to a cycle |
| `/workflows:retrospective` | Sprint retrospective with status update |

**Utilities:**

| Command | Description |
|---------|-------------|
| `/workflows:code-review` | Standardized code review for Brite projects |
| `/workflows:security-audit` | Comprehensive project security audit |
| `/workflows:raise-a-ticket` | Report a bug or idea/feedback on a Brite product — routes to the right Linear team/project, files as `needs-triage` |
| `/workflows:bug-report` | _Deprecated — use `/workflows:raise-a-ticket`_ |
| `/workflows:deployment-checklist` | Pre-deployment validation checklist |
| `/workflows:tech-stack` | Display the Brite technology stack |
| `/workflows:onboarding-checklist` | Guide for setting up a new dev environment |
| `/workflows:setup-claude-md` | Generate best-practices CLAUDE.md for a project |
| `/workflows:architecture-decision` | Generate Architecture Decision Records |
| `/workflows:create-plugin` | Scaffold a new domain plugin from template |
| `/workflows:smoke-test` | Diagnostic checks on plugin environment |
| `/workflows:report-issue` | Report the agent tooling itself misbehaving — a skill, command, or hook that misfired (not a Brite product bug) |

**Quality:**

| Command | Description |
|---------|-------------|
| `/workflows:fact-check` | Verify factual accuracy of a document against the codebase |

**Compound knowledge & governance:**

| Command | Description |
|---------|-------------|
| `/workflows:analytics` | Show plugin usage analytics — command frequency, success rates, and duration trends |
| `/workflows:audit-trail` | Query the full context picture for any issue — what context was used and its staleness |
| `/workflows:flywheel-metrics` | Compute and display the 5 compound-knowledge flywheel metrics from decision traces |
| `/workflows:promote-precedent` | Review and promote flagged decision traces from project precedents to the org handbook |

## Skill Coverage Matrix

Skills activate automatically when Claude detects relevant context.

**Inner Loop skills** (auto-activate in sequence):

| Skill | Category | Trigger |
|-------|----------|---------|
| `brainstorming` | Discovery | Non-trivial issue, before planning |
| `writing-plans` | Planning | Multi-step task, before coding |
| `git-worktrees` | Setup | After plan approval, before coding |
| `executing-plans` | Execution | Given an approved plan to implement |
| `verification-before-completion` | Quality | Task checkpoints during execution |
| `compound-learnings` | Knowledge | After completing work (via ship) |
| `best-practices-audit` | Quality | After compound learnings (via ship) |
| `systematic-debugging` | Debugging | Bug investigation (anytime) |

**Design, backend & quality skills** (shipped):

| Skill | Category | Trigger |
|-------|----------|---------|
| `react-best-practices` | Frontend | Writing, reviewing, or optimizing React components |
| `python-best-practices` | Backend | Writing, reviewing, or refactoring FastAPI/Python code |
| `frontend-design` | Frontend | Building web components, pages, dashboards |
| `ui-ux-pro-max` | Design | Design tasks across 50 styles, 9 frameworks, 21 palettes |
| `web-design-guidelines` | Design | Reviewing UI code for best practices and accessibility |
| `code-quality` | Quality | ESLint, Prettier, Ruff, TypeScript strict enforcement |
| `testing-strategy` | Quality | Testing patterns for Vitest, RTL, MSW, and Playwright |
| `agent-browser` | Automation | Navigating websites, filling forms, taking screenshots |
| `find-skills` | Discovery | Looking for new skills or capabilities to install |

## Review Agents

`/workflows:review` runs up to 9 specialized review agents in parallel:

| Tier | Agents | Activation |
|------|--------|------------|
| 1 (always) | code-reviewer, security-reviewer, performance-reviewer | Every review |
| 2 (stack) | typescript-reviewer, python-reviewer, data-reviewer | Auto-detected from project files |
| 3 (opt-in) | architecture-reviewer, accessibility-reviewer, test-quality-reviewer | Large projects or CLAUDE.md include |

Depth modes: `fast` (Tier 1 only), `thorough` (default, Tier 1+2), `comprehensive` (all tiers).
All agents run on Opus. A Haiku-powered diff-triage agent gates trivial diffs.

**Workflow skills** (shipped):

| Skill | Category | Trigger |
|-------|----------|---------|
| `post-plan-setup` | Workflow | After `/workflows:project-start` produces a v1 plan (orchestrates 3 phases) |
| `refine-plan` | Workflow | Decomposes v1 plans into agent-ready tasks (internal) |
| `create-issues` | Workflow | Creates Linear issues from refined plans (internal) |
| `setup-claude-md` | Workflow | Generates best-practices CLAUDE.md for a project (internal) |

## MCP Servers

The `workflows` plugin configures three MCP servers automatically:

| Server | Transport | Purpose |
|--------|-----------|---------|
| `sequential-thinking` | stdio | Structured reasoning via `@modelcontextprotocol/server-sequential-thinking` |
| `linear-server` | HTTP | Linear project management integration |
| `gbrain-team` | stdio | Team knowledge base — gbrain broker (`scripts/gbrain-team-broker.sh`) to a Railway HTTP endpoint |

The Linear MCP server provides tools for managing issues, projects, milestones, and documentation directly from Claude Code.

`gbrain-team` needs `GBRAIN_CLIENT_ID` and `GBRAIN_CLIENT_SECRET` exported in your shell profile before you launch Claude Code, and `GBRAIN_WRITE_CLIENT_ID` / `GBRAIN_WRITE_CLIENT_SECRET` as well if you have write access. Setup steps are in [CONTRIBUTING.md § Team gbrain credentials](CONTRIBUTING.md#team-gbrain-credentials); the reasoning is [ADR-045](docs/decisions/045-gbrain-broker-env-oauth-client.md).

---

## Plugin Development Guide

### Repository Structure

```
.claude-plugin/
  marketplace.json          # Plugin registry (required for bundles)
plugins/
  workflows/
    .claude-plugin/
      plugin.json           # Plugin metadata
    commands/               # Slash commands
    skills/                 # Model-invoked skills
    agents/                 # Specialized subagents
    hooks/                  # Event handlers
    .mcp.json               # MCP server configurations
```

### Plugin Manifest (plugin.json)

Each plugin requires `.claude-plugin/plugin.json`:

```json
{
  "name": "workflows",
  "description": "Process + Org plugin — structured workflow methodology with Linear integration",
  "version": "3.24.0",
  "author": { "name": "Brite" },
  "homepage": "https://github.com/brite-nites/brite-claude-plugins",
  "repository": "https://github.com/brite-nites/brite-claude-plugins",
  "license": "MIT",
  "keywords": ["claude-code", "plugin", "process", "workflow", "linear"],
  "commands": "./commands/",
  "skills": "./skills/"
}
```

---

## Adding Commands

Commands are slash commands that users invoke directly. Create a markdown file in `commands/`.

### File Structure

```
commands/
  my-command.md      # Becomes /workflows:my-command
```

### Command Format

```markdown
---
description: Brief description shown in slash menu
---

Instructions for Claude on how to handle this command.

Use $ARGUMENTS for the full user input after the command.
Use $1, $2, etc. for positional arguments.
```

### Example: Deploy Command

`commands/deploy.md`:

```markdown
---
description: Deploy the current project to production
---

You are deploying the user's project. Follow these steps:

1. Run all tests to ensure the build is stable
2. Build the production bundle
3. Deploy using the configured deployment method

The user specified: $ARGUMENTS
```

---

## Adding Skills

Skills are model-invoked capabilities that Claude uses automatically based on context. Unlike commands, users don't invoke skills directly — Claude decides when to use them.

### File Structure

```
skills/
  code-review/
    SKILL.md           # Required: Skill definition
    templates/         # Optional: Supporting files
  security-scan/
    SKILL.md
```

### SKILL.md Format

```markdown
---
name: code-review
description: When to use this skill - Claude reads this to decide
allowed-tools: Read, Grep, Glob
user-invocable: true
---

# Code Review Skill

Detailed instructions for how Claude should perform this skill.

## When to Activate
- User asks for code review
- PR review is requested
- Code quality assessment needed

## Process
1. First step...
2. Second step...
```

### Frontmatter Options

| Field | Description |
|-------|-------------|
| `name` | Skill identifier (required) |
| `description` | When/why Claude should use this skill (required) |
| `allowed-tools` | Tools Claude can use without asking permission |
| `model` | Specific model to use (e.g., `haiku`, `sonnet`) |
| `context: fork` | Run in isolated sub-agent |
| `agent` | Agent type when using `context: fork` |
| `user-invocable` | Show in slash menu (default: `true`) |

---

## Adding MCP Server Configurations

MCP (Model Context Protocol) servers connect Claude to external tools, APIs, and databases.

### File Location

Create `.mcp.json` at the plugin root:

```
plugins/
  workflows/
    .mcp.json           # MCP configuration
```

### Configuration Format

```json
{
  "mcpServers": {
    "database": {
      "command": "npx",
      "args": ["@brite/mcp-database"],
      "env": {
        "DB_PATH": "${CLAUDE_PLUGIN_ROOT}/data"
      }
    },
    "api-client": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/api-server.js",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"]
    }
  }
}
```

### Path Variables

| Variable | Description |
|----------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin directory |

### Transport Types

**stdio (default)**:
```json
{
  "mcpServers": {
    "local-server": {
      "command": "./server.js",
      "args": []
    }
  }
}
```

**HTTP/SSE**:
```json
{
  "mcpServers": {
    "remote-server": {
      "url": "https://api.example.com/mcp",
      "transport": "sse"
    }
  }
}
```

---

## Adding Hooks

Hooks respond to Claude Code events automatically (formatting, validation, notifications).

### File Location

Create `hooks/hooks.json` or define inline in `plugin.json`:

```
plugins/
  workflows/
    hooks/
      hooks.json
```

### Hook Events

| Event | When it fires |
|-------|---------------|
| `PreToolUse` | Before Claude uses any tool |
| `PostToolUse` | After tool execution |
| `PostToolUseFailure` | After a tool fails |
| `UserPromptSubmit` | When user submits a prompt |
| `Stop` | When Claude attempts to stop |
| `SessionStart` | When a session begins |
| `SessionEnd` | When a session ends |

### Configuration Format

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh $CLAUDE_FILE_PATH"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Verify this command is safe to run"
          }
        ]
      }
    ]
  }
}
```

### Hook Types

| Type | Description |
|------|-------------|
| `command` | Execute a shell command/script |
| `prompt` | LLM-based evaluation (uses Haiku) |
| `agent` | Full agent with tool access |

---

## Adding Agents

Agents are specialized subagents that Claude can delegate tasks to.

### File Structure

```
agents/
  security-reviewer.md
  performance-tester.md
```

### Agent Format

```markdown
---
description: What this agent specializes in
capabilities:
  - security analysis
  - vulnerability detection
  - compliance checking
skills: security-scan, code-review
---

# Security Reviewer Agent

You are a security specialist. When delegated tasks:

1. Review code for security vulnerabilities
2. Check for OWASP Top 10 issues
3. Validate input sanitization
4. Report findings with severity levels
```

---

## Adding Output Styles

Output styles customize Claude's response format and behavior.

### File Structure

```
styles/
  concise.md
  verbose.md
```

### Style Format

```markdown
---
name: Concise Mode
description: Short, direct responses
keep-coding-instructions: true
---

Respond concisely. Use bullet points. Avoid lengthy explanations.
Maximum 3 sentences per response unless more detail is explicitly requested.
```

---

## Marketplace Configuration

The root `marketplace.json` registers plugins for distribution:

```json
{
  "name": "brite-claude-plugins",
  "owner": {
    "name": "Brite"
  },
  "metadata": {
    "description": "Claude Code plugins for the Brite organization"
  },
  "plugins": [
    {
      "name": "workflows",
      "source": "./plugins/workflows",
      "description": "Process + Org plugin — structured workflow methodology with Linear integration",
      "version": "3.24.0"
    }
  ]
}
```

To add a new plugin to the bundle, create the plugin directory and add it to the `plugins` array.

---

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System diagrams, runtime flow, skill routing, design decisions |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to add commands, skills, agents, hooks; branch and PR conventions |
| [docs/getting-started.md](docs/getting-started.md) | Developer setup for working on this repo |
| [docs/workflow-guide.md](docs/workflow-guide.md) | Full workflow walkthrough, skill reference, visual features |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common issues and solutions |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [ROADMAP.md](ROADMAP.md) | Development plan and lifecycle vision |
| [CLAUDE.md](CLAUDE.md) | Instructions for Claude Code when working in this repo |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contributor guide, including:
- Step-by-step instructions for adding commands, skills, agents, and hooks
- SKILL.md frontmatter standard
- Branch naming and commit message conventions
- CI checks and local testing

## License

MIT

## Issue Tracking

Issues for this project are tracked in [Brite Skill Packs](https://linear.app/brite-nites/project/brite-skill-packs-402b57908532) (Layer C). Sibling Linear projects under the same initiative: [Brite Orchestration Layer](https://linear.app/brite-nites/project/brite-orchestration-layer-d46d5338fa95), [Brite Knowledge Layer](https://linear.app/brite-nites/project/brite-knowledge-layer-b47f7155b42e), [Brite Runtime & Harness](https://linear.app/brite-nites/project/brite-runtime-andamp-harness-0cd1bad14ad1).
