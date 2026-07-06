# Workflow Specification

Machine-parseable specification of the Brite Workflows plugin. Structured data for downstream automation (trigger registry, step-sequence validation, contract enforcement).

## Purpose

This file is the single source of truth for:
- **Trigger conditions** — when each skill activates, with keywords, preconditions, and precedence
- **Step sequences** — ordered steps for each orchestrator command, with skip/fail semantics
- **Cross-skill contracts** — what each skill provides and requires from the chain
- **Error handling contracts** — failure points and recovery actions per skill and command

### Format Contract

Structured data is embedded in fenced YAML blocks preceded by an HTML comment anchor:

```
<!-- spec:section-name:identifier -->
```

Downstream scripts extract blocks with:

```bash
# Validate ANCHOR against safe character class first
if ! [[ "$ANCHOR" =~ ^[a-zA-Z0-9:_-]+$ ]]; then
  echo "Invalid ANCHOR: $ANCHOR" >&2; exit 1
fi
sed -n "/<!-- spec:${ANCHOR} -->/,/^\`\`\`$/{ /^<!--/d; /^\`\`\`/d; p; }" docs/workflow-spec.md
```

Each block is independently parseable YAML. Adding or removing a skill touches one block.

**Anchor segments**: The middle segment is one of: `trigger`, `steps`, `contract`, `errors`. The third segment is the skill or command name.

**Constraint**: YAML values must not contain a line that is exactly three backticks (`` ``` ``), as this would prematurely terminate the extraction range.

---

## 1. Trigger Conditions

### 1a. Inner Loop Skills

<!-- spec:trigger:brainstorming -->
```yaml
name: brainstorming
tier: inner-loop
user-invocable: false
position: 1
keywords:
  - "2+ modules or directories"
  - "4+ tasks"
  - "2+ viable implementation approaches"
  - "new pattern, integration, or architectural component"
negative-keywords:
  - "single-module change (1-2 files)"
  - "clear single approach"
  - "under 3 implementation steps"
  - "no new patterns or integrations"
activation-rule: "ANY keyword match activates; ALL negative keywords must be true to skip"
objective-criteria:
  modules: 2
  tasks: 4
  approaches: 2
  new-patterns: 1
preconditions:
  - "Issue ID available from session-start or conversation context"
  - "Issue readable via Linear MCP or description provided directly"
output-artifacts:
  - path: "docs/designs/<issue-id>-<slug>.md"
    type: file
    optional: false
handoff:
  next: writing-plans
  marker: "**Brainstorming complete.**"
```

<!-- spec:trigger:writing-plans -->
```yaml
name: writing-plans
tier: inner-loop
user-invocable: false
position: 2
keywords:
  - "multi-step task needs planning"
  - "after brainstorming approval"
  - "after issue selection for straightforward work"
negative-keywords:
  - "single atomic change"
activation-rule: "ANY keyword match activates; ALL negative keywords must be true to skip"
objective-criteria: null
preconditions:
  - "Design doc exists if brainstorming criteria were met (glob docs/designs/<issue-id>-*.md)"
  - "Issue ID available from session-start or $ARGUMENTS"
optional-inputs:
  - source: "CDR INDEX via Context7 (handbook-library from ## Company Context)"
    condition: "## Company Context exists in CLAUDE.md and Context7 is available"
    on-unavailable: "Skip CDR check, log reason, proceed"
output-artifacts:
  - path: "docs/plans/<issue-id>-plan.md"
    type: file
    optional: false
handoff:
  next: git-worktrees
  marker: "**Planning complete.**"
```

<!-- spec:trigger:git-worktrees -->
```yaml
name: git-worktrees
tier: inner-loop
user-invocable: false
position: 3
keywords:
  - "after a plan is approved"
  - "before execution begins"
  - "work in isolation"
negative-keywords:
  - "single-file changes"
  - "documentation-only updates"
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Plan file exists at docs/plans/<issue-id>-plan.md"
  - "Issue ID matches ^[A-Z]+-[0-9]+$"
output-artifacts:
  - path: ".claude/worktrees/<issue-id>/"
    type: code
    optional: false
handoff:
  next: executing-plans
  marker: "**Worktree setup complete.**"
```

<!-- spec:trigger:executing-plans -->
```yaml
name: executing-plans
tier: inner-loop
user-invocable: false
position: 4
keywords:
  - "approved plan to implement"
  - "plan file exists"
negative-keywords:
  - "ad-hoc changes without a plan"
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Plan file readable at docs/plans/<issue-id>-plan.md"
  - "Clean working state (git status --porcelain empty)"
output-artifacts:
  - path: "implemented code + tests"
    type: code
    optional: false
  - path: "execution trace YAML blocks (conversation context)"
    type: context
    optional: false
handoff:
  next: "/workflows:review"
  marker: "**Execution complete.**"
```

<!-- spec:trigger:verification-before-completion -->
```yaml
name: verification-before-completion
tier: inner-loop
user-invocable: false
position: null
keywords:
  - "task checkpoint during plan execution"
  - "before marking a Linear issue as done"
  - "after fixing a bug"
  - "before shipping"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Invoked directly by executing-plans at each task checkpoint"
output-artifacts:
  - path: "verification report (inline)"
    type: context
    optional: false
handoff: null
```

<!-- spec:trigger:compound-learnings -->
```yaml
name: compound-learnings
tier: inner-loop
user-invocable: false
position: 5
keywords:
  - "ship phase after PR creation"
  - "after significant work session"
negative-keywords:
  - "trivial changes (typos, version bumps, single-line fixes)"
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Diff exists (git log base..HEAD --oneline non-empty)"
  - "CLAUDE.md exists at project root"
output-artifacts:
  - path: "CLAUDE.md (updated)"
    type: file
    optional: false
  - path: "auto-memory session summary"
    type: file
    optional: false
  - path: "docs/ updates"
    type: file
    optional: true
  - path: "docs/precedents/<ISSUE-ID>.md"
    type: file
    optional: true
  - path: "docs/precedents/INDEX.md"
    type: file
    optional: true
handoff:
  next: best-practices-audit
  marker: "**Compound learnings complete.**"
```

<!-- spec:trigger:best-practices-audit -->
```yaml
name: best-practices-audit
tier: inner-loop
user-invocable: false
position: 6
keywords:
  - "ship phase after compound-learnings"
  - "after significant CLAUDE.md changes"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "CLAUDE.md exists at project root"
output-artifacts:
  - path: "CLAUDE.md (auto-fixed)"
    type: file
    optional: false
handoff:
  next: "/workflows:ship"
  marker: "**Best-practices audit complete.**"
```

<!-- spec:trigger:systematic-debugging -->
```yaml
name: systematic-debugging
tier: inner-loop
user-invocable: true
position: null
keywords:
  - "bug reports or unexpected behavior"
  - "failing tests that shouldn't be failing"
  - "production issues or error reports"
  - "it works on my machine"
  - "cause isn't immediately obvious"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions: []
output-artifacts:
  - path: "regression test file"
    type: code
    optional: false
  - path: "fix + defense-in-depth"
    type: code
    optional: false
handoff:
  next: null
  marker: "**Debugging complete.**"
```

### 1b. Design Skills

<!-- spec:trigger:frontend-design -->
```yaml
name: frontend-design
tier: design
user-invocable: true
position: null
keywords:
  - "code"
  - "build"
  - "create"
  - "implement"
  - "web components"
  - "pages"
  - "layouts"
  - "dashboards"
  - "applications"
negative-keywords:
  - "design system planning"
  - "palette selection"
  - "style exploration"
activation-rule: ANY
objective-criteria: null
preconditions:
  - "User provides frontend requirements"
output-artifacts:
  - path: "production-grade HTML/CSS/JS/React code"
    type: code
    optional: false
handoff: null
```

<!-- spec:trigger:ui-ux-pro-max -->
```yaml
name: ui-ux-pro-max
tier: design
user-invocable: true
position: null
keywords:
  - "choose palette"
  - "select fonts"
  - "design system"
  - "plan visual direction"
  - "explore UI styles"
negative-keywords:
  - "building/coding UI"
  - "implementation"
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Python 3 installed (setup step with guided remediation, not a hard blocker)"
  - "skills/ui-ux-pro-max/scripts/search.py available"
output-artifacts:
  - path: "design-system/MASTER.md"
    type: file
    optional: true
  - path: "design-system/pages/<page-name>.md"
    type: file
    optional: true
handoff: null
```

<!-- spec:trigger:web-design-guidelines -->
```yaml
name: web-design-guidelines
tier: design
user-invocable: true
position: null
keywords:
  - "review my UI"
  - "check accessibility"
  - "audit design"
  - "review UX"
  - "check my site against best practices"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Fetch guidelines from vercel-labs/web-interface-guidelines via WebFetch"
  - "User provides file or pattern argument"
output-artifacts:
  - path: "findings in file:line format (inline)"
    type: context
    optional: false
handoff: null
```

### 1c. Backend & Quality Skills

<!-- spec:trigger:react-best-practices -->
```yaml
name: react-best-practices
tier: backend-quality
user-invocable: true
position: null
keywords:
  - "writing React components"
  - "Next.js pages"
  - "data fetching"
  - "reviewing code for performance"
  - "refactoring React/Next.js"
  - "bundle optimization"
  - "load times"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions: []
output-artifacts:
  - path: "advisory output (inline)"
    type: context
    optional: false
handoff: null
```

<!-- spec:trigger:python-best-practices -->
```yaml
name: python-best-practices
tier: backend-quality
user-invocable: true
position: null
keywords:
  - "FastAPI endpoints or routers"
  - "Pydantic models"
  - "SQLAlchemy queries or sessions"
  - "async Python code"
  - "Python API architecture"
negative-keywords:
  - "Ruff, mypy, Black configuration (use code-quality)"
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Target: Python 3.11+, FastAPI 0.104+, Pydantic 2.x, SQLAlchemy 2.0+"
output-artifacts:
  - path: "advisory output (inline)"
    type: context
    optional: false
handoff: null
```

<!-- spec:trigger:testing-strategy -->
```yaml
name: testing-strategy
tier: backend-quality
user-invocable: true
position: null
keywords:
  - "writing test files or test cases"
  - "reviewing test code"
  - "what to mock"
  - "test infrastructure (MSW, factories, fixtures)"
  - "coverage thresholds"
  - "flaky or brittle tests"
  - "Playwright E2E"
  - "pytest fixtures"
  - "conftest.py"
negative-keywords:
  - "FastAPI-specific test patterns (use python-best-practices)"
  - "ESLint test plugins (use code-quality)"
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Target: Vitest 3.x, RTL 16.x, MSW 2.x, Playwright 1.45+, pytest 8.x"
output-artifacts:
  - path: "advisory output (inline)"
    type: context
    optional: false
handoff: null
```

<!-- spec:trigger:code-quality -->
```yaml
name: code-quality
tier: backend-quality
user-invocable: true
position: null
keywords:
  - "setting up linting and formatting"
  - "reviewing code quality configs"
  - "generating ESLint, Prettier, Ruff, or mypy configs"
  - "lint/format steps to CI"
  - "linter not catching issues"
  - "migrating from legacy tooling (TSLint, Black/flake8/isort)"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Auto-detect stack via package.json, tsconfig.json, pyproject.toml"
output-artifacts:
  - path: "eslint.config.mjs"
    type: file
    optional: true
  - path: ".prettierrc"
    type: file
    optional: true
  - path: "pyproject.toml (Ruff/mypy sections)"
    type: file
    optional: true
  - path: ".github/workflows/lint.yml"
    type: file
    optional: true
handoff: null
```

### 1d. Utility Skills

<!-- spec:trigger:agent-browser -->
```yaml
name: agent-browser
tier: utility
user-invocable: true
position: null
keywords:
  - "navigate websites"
  - "interact with web pages"
  - "fill forms"
  - "take screenshots"
  - "test web applications"
  - "extract information from web pages"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "agent-browser CLI installed and in PATH"
output-artifacts:
  - path: "screenshots, PDFs, video recordings, trace files"
    type: file
    optional: true
handoff: null
```

<!-- spec:trigger:find-skills -->
```yaml
name: find-skills
tier: utility
user-invocable: true
position: null
keywords:
  - "how do I do X"
  - "find a skill for X"
  - "is there a skill for X"
  - "can you do X"
  - "extending agent capabilities"
  - "search for tools, templates, or workflows"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "npx available for running skills CLI"
output-artifacts:
  - path: "conversational output with install commands"
    type: context
    optional: false
handoff: null
```

### 1e. Post-Plan Skills

<!-- spec:trigger:post-plan-setup -->
```yaml
name: post-plan-setup
tier: post-plan
user-invocable: true
position: null
keywords:
  - "after /plan-project produces a v1 plan"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "v1 plan file exists"
  - "Linear MCP available"
  - "Sequential thinking MCP available"
output-artifacts:
  - path: "docs/project-plan-refined.md"
    type: file
    optional: false
  - path: "docs/linear-issues-created.md"
    type: file
    optional: false
  - path: "CLAUDE.md"
    type: file
    optional: false
handoff: null
```

<!-- spec:trigger:refine-plan -->
```yaml
name: refine-plan
tier: post-plan
user-invocable: false
position: null
keywords:
  - "invoked by post-plan-setup orchestrator"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "v1 plan file exists"
  - "_shared/validation-pattern.md readable"
output-artifacts:
  - path: "docs/project-plan-refined.md"
    type: file
    optional: false
handoff:
  next: create-issues
  marker: null
```

<!-- spec:trigger:create-issues -->
```yaml
name: create-issues
tier: post-plan
user-invocable: false
position: null
keywords:
  - "invoked by post-plan-setup after refine-plan"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - "Refined plan exists at docs/project-plan-refined.md"
  - "Linear MCP available"
  - "_shared/validation-pattern.md readable"
output-artifacts:
  - path: "Linear issues (created via MCP)"
    type: context
    optional: false
  - path: "docs/project-plan-refined.md (updated with issue IDs)"
    type: file
    optional: false
  - path: "docs/linear-issues-created.md"
    type: file
    optional: false
handoff:
  next: setup-claude-md
  marker: null
```

<!-- spec:trigger:setup-claude-md -->
```yaml
name: setup-claude-md
tier: post-plan
user-invocable: false
position: null
keywords:
  - "invoked by post-plan-setup after create-issues"
  - "project setup"
negative-keywords: []
activation-rule: ANY
objective-criteria: null
preconditions:
  - ".claude/skills/setup-claude-md/claude-code-best-practices.md readable"
  - "Project files for analysis (package.json, pyproject.toml, etc.)"
output-artifacts:
  - path: "CLAUDE.md"
    type: file
    optional: false
handoff: null
```

### 1f. Precedence Rules

<!-- spec:trigger:precedence -->
```yaml
precedence-rules:
  - rule: "frontend-design vs ui-ux-pro-max"
    condition: "If request involves building/coding, use frontend-design. If planning/exploring design direction, use ui-ux-pro-max."
    winner-keywords: ["build", "create", "implement", "code"]
    loser-keywords: ["choose palette", "design system", "plan visual direction"]

  - rule: "frontend-design vs web-design-guidelines"
    condition: "If request involves building new UI, use frontend-design. If reviewing/auditing existing UI, use web-design-guidelines."
    winner-keywords: ["build", "create", "implement"]
    loser-keywords: ["review", "audit", "check"]

  - rule: "python-best-practices vs code-quality"
    condition: "Architectural patterns use python-best-practices. Tooling config (Ruff, mypy, Black) uses code-quality."

  - rule: "testing-strategy vs python-best-practices"
    condition: "General test patterns use testing-strategy. FastAPI-specific test patterns (async clients, dependency overrides) use python-best-practices."

  - rule: "testing-strategy vs code-quality"
    condition: "Test code patterns use testing-strategy. ESLint test plugins and tooling use code-quality."

  - rule: "inner-loop chain order"
    condition: "Inner loop skills activate in strict sequence: brainstorming(1) → writing-plans(2) → git-worktrees(3) → executing-plans(4) → [review command] → compound-learnings(5) → best-practices-audit(6)"

  - rule: "systematic-debugging is standalone"
    condition: "systematic-debugging can activate anytime — not tied to inner loop sequence position."

  - rule: "verification-before-completion is a sub-skill"
    condition: "Only invoked by executing-plans at task checkpoints. Never activates independently."
```

---

## 2. Step Sequences

### 2a. session-start

<!-- spec:steps:session-start -->
```yaml
command: session-start
prereqs:
  - "Linear MCP — list projects (1 result) confirms auth"
  - "Sequential-thinking MCP — trivial thought confirms running"
  - "Context7 MCP — resolve-library-id('react') confirms running (non-blocking)"
steps:
  - id: 0
    name: "Verify Prerequisites"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: STOP
    activates-skill: null

  - id: 1
    name: "Environment Setup"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Company Context"
    required: false
    skip-condition: "CLAUDE.md has ## Company Context section or <!-- no-company-context --> marker"
    skip-target: 3
    jump-on-fail: null
    activates-skill: null

    note: "Runs Company Context Interview from commands/_shared/company-context-template.md. Produces: company-context block in CLAUDE.md."
  - id: 3
    name: "Query Linear for Open Issues"
    required: true
    skip-condition: "$ARGUMENTS contains an issue ID or URL"
    skip-target: 4
    jump-on-fail: null
    activates-skill: null

  - id: 4
    name: "Read Issue Details"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 5
    name: "Brainstorm (Objective Complexity Check)"
    required: true
    skip-condition: "ALL negative criteria true (single-module, single-approach, <3 steps, no new patterns)"
    skip-target: 6
    jump-on-fail: null
    activates-skill: brainstorming

  - id: 6
    name: "Write Plan"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: writing-plans

  - id: 7
    name: "Set Up Worktree"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: git-worktrees

  - id: 8
    name: "Execute"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: executing-plans

```

### 2b. review

<!-- spec:steps:review -->
```yaml
command: review
prereqs:
  - "Task tool dispatch — trivial agent returns 'pong'"
steps:
  - id: 0
    name: "Verify Agent Dispatch"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: STOP
    activates-skill: null

  - id: 1
    name: "Self-Verification"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Diff Triage"
    required: false
    skip-condition: "$ARGUMENTS contains 'skip triage' or 'no triage'"
    skip-target: 3
    jump-on-fail: null
    activates-skill: null

    note: "Haiku agent classifies diff as trivial/non-trivial. skip-target (3) applies to user skip only. TRIVIAL verdict jumps to Step 8 (abbreviated report, skipping Steps 3-7). Provides: TRIAGE_VERDICT."
  - id: 3
    name: "Simplify Pass"
    required: false
    skip-condition: "$ARGUMENTS contains 'skip simplify' or 'no simplify'"
    skip-target: 4
    jump-on-fail: null
    activates-skill: null

  - id: 4
    name: "Select & Launch Review Agents"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

    note: "Depth mode from $ARGUMENTS: fast (Tier 1 only), thorough (Tier 1+2, default), comprehensive (all tiers). Unrecognized depth defaults to thorough. All review agents run on Opus."
  - id: 5
    name: "Collect & Classify Findings"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

    note: "Confidence threshold filtering: >= 7 included, low-confidence P2/P3 filtered, borderline P1s marked for human review. Missing confidence defaults to 5."
  - id: 6
    name: "Validate Findings"
    required: false
    skip-condition: "$ARGUMENTS contains 'skip validation' or 'no validation'; in fast mode, P2/P3 validation skipped (P1s still validated)"
    skip-target: 7
    jump-on-fail: null
    activates-skill: null

    note: "Per-finding verification: Opus subagent per P1, Sonnet subagent per P2/P3. Max 20 subagents. P1 verifiers: 10 turns, P2/P3 verifiers: 5 turns. In fast mode, only P1s validated. Provides: VALIDATED_FINDINGS."
  - id: 7
    name: "Fix Loop (P1s Only)"
    required: false
    skip-condition: "No auto-fixable P1 findings (confidence >= 7)"
    skip-target: 8
    jump-on-fail: null
    activates-skill: null

  - id: 8
    name: "Final Report"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

```

### 2c. ship

<!-- spec:steps:ship -->
```yaml
command: ship
prereqs:
  - "gh auth status succeeds"
  - "gh repo view --json name succeeds"
steps:
  - id: 0
    name: "Verify GitHub CLI"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: STOP
    activates-skill: null

  - id: 1
    name: "Pre-Ship Checks"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Create Pull Request"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 3
    name: "Update Linear"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 4
    name: "Compound Learnings"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: compound-learnings

  - id: 5
    name: "Best Practices Audit"
    required: false
    skip-condition: "compound-learnings reported no CLAUDE.md changes of any kind (no entries added, updated, pruned, and no stale claims auto-removed or flagged)"
    skip-target: 6
    jump-on-fail: null
    activates-skill: best-practices-audit

  - id: 6
    name: "Worktree Cleanup"
    required: false
    skip-condition: "Not working in a git worktree"
    skip-target: 7
    jump-on-fail: null
    activates-skill: null

  - id: 7
    name: "Session Close"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

```

### 2d. sprint-planning

<!-- spec:steps:sprint-planning -->
```yaml
command: sprint-planning
prereqs:
  - "Linear MCP — list projects (1 result) confirms auth"
  - "Sequential-thinking MCP — trivial thought confirms running"
steps:
  - id: 0
    name: "Verify Prerequisites"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: STOP
    activates-skill: null

  - id: 1
    name: "Resolve Context"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Current State Assessment"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 3
    name: "Pull & Display Backlog"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 4
    name: "Interactive Planning"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 5
    name: "Assign to Cycle"
    required: false
    skip-condition: "Prioritization-only mode (no cycles exist)"
    skip-target: 6
    jump-on-fail: null
    activates-skill: null

  - id: 6
    name: "Summary"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

```

### 2e. retrospective

<!-- spec:steps:retrospective -->
```yaml
command: retrospective
prereqs:
  - "Linear MCP — list projects (1 result) confirms auth"
  - "Sequential-thinking MCP — trivial thought confirms running"
steps:
  - id: 0
    name: "Verify Prerequisites"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: STOP
    activates-skill: null

  - id: 1
    name: "Resolve Context"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Delivery Summary"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 3
    name: "Retrospective Discussion"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 4
    name: "Post Status Update"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 5
    name: "Create Follow-up Issues"
    required: false
    skip-condition: "No action items marked 'Create Issue? = Yes'"
    skip-target: 6
    jump-on-fail: null
    activates-skill: null

  - id: 6
    name: "Summary"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

```

### 2f. scope

<!-- spec:steps:scope -->
```yaml
command: scope
prereqs:
  - "Linear MCP — list projects (1 result) confirms auth"
  - "Sequential-thinking MCP — trivial thought confirms running"
steps:
  - id: 0
    name: "Verify Prerequisites"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: STOP
    activates-skill: null

  - id: 1
    name: "Interview Phase"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Context Gathering"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 3
    name: "Collaborative Ideation"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 4
    name: "Issue Creation"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 5
    name: "Prioritization"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 6
    name: "Session Summary"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

```

### 2g. architecture-decision

<!-- spec:steps:architecture-decision -->
```yaml
command: architecture-decision
prereqs:
  - "Sequential-thinking MCP — trivial thought confirms running"
steps:
  - id: 0
    name: "Verify Prerequisites"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: STOP
    activates-skill: null

  - id: 1
    name: "Identify the Decision"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Explore Context"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 3
    name: "Analyze Options"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 4
    name: "Confirm the Decision"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 5
    name: "Document Consequences"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 6
    name: "Determine Status"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 7
    name: "Write the ADR"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 8
    name: "Update CLAUDE.md"
    required: true
    skip-condition: "No project CLAUDE.md exists"
    skip-target: 9
    jump-on-fail: null
    activates-skill: null

  - id: 9
    name: "Summary"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

```

### 2h. project-start

<!-- spec:steps:project-start -->
```yaml
command: project-start
note: "Step ordering reflects the V1 implementation delivered across BC-2124 through BC-2131. Trait classification, conditional doc scaffolding, trait labels, and infrastructure dispatch are all implemented."
prereqs:
  - "None — project-start initializes from scratch"
steps:
  - id: 0
    name: "Determine Technical Level"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 1
    name: "Conduct Interview"
    required: true
    skip-condition: "Express mode accepted (traits detected from file markers and confirmed by user)"
    skip-target: 3
    jump-on-fail: null
    activates-skill: null

  - id: 2
    name: "Classify Project Traits"
    required: true
    skip-condition: "Express mode accepted (traits already confirmed during express flow)"
    skip-target: 3
    jump-on-fail: null
    activates-skill: null

  - id: 3
    name: "Git Repository Setup"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

    note: "Baseline (git init, minimal .gitignore) is unconditional. Tech-stack .gitignore extensions and GitHub remote prompt gated on produces-code. CI/CD flag gated on produces-code + automation."
  - id: 4
    name: "Scaffold Trait-Conditional Documentation"
    required: false
    skip-condition: "0 active traits after classification (baseline dirs docs/ and docs/decisions/ are always created regardless of skip)"
    skip-target: 5
    jump-on-fail: null
    activates-skill: null

    note: "Sub-step 4b: Trait-to-Infrastructure Dispatch (infrastructure gating defined in Step 3 note). Sub-step 4c: MCP Verification (BC-1949). Verifies global + trait-gated MCP connectivity. All failures non-blocking (WARN)."
  - id: 5
    name: "Generate CLAUDE.md"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 6
    name: "Create Linear Project"
    required: false
    skip-condition: "Linear MCP inaccessible"
    skip-target: 7
    jump-on-fail: null
    activates-skill: null

    note: "Sub-step 6b: Create Trait Labels. For each active trait, creates trait:<name> labels under a Trait label group. Labels are created in parallel. Idempotent — skips existing labels silently."
  - id: 7
    name: "Write Project Plan"
    required: true
    skip-condition: null
    skip-target: null
    jump-on-fail: null
    activates-skill: null

  - id: 8
    name: "Generate ADRs"
    required: false
    skip-condition: "requires-decisions not active AND (produces-code not active OR interview produced fewer than 2 major technical decisions)"
    skip-target: null
    jump-on-fail: null
    activates-skill: null

```

---

## 3. Cross-Skill Contracts

### 3a. Inner Loop Chain

<!-- spec:contract:inner-loop-chain -->
```yaml
chain: inner-loop
sequence:
  - from: session-start
    to: brainstorming
    provides:
      - "Issue ID"
      - "Issue details (description, acceptance criteria)"
      - "CLAUDE.md context"
      - "Auto-memory context"
    requires: []

  - from: brainstorming
    to: writing-plans
    provides:
      - "Design document at docs/designs/<issue-id>-<slug>.md"
      - "Key decisions summary"
      - "Scope boundaries"
    requires:
      - "Issue ID"
      - "Issue readable via Linear or provided directly"

  - from: writing-plans
    to: git-worktrees
    provides:
      - "Plan file at docs/plans/<issue-id>-plan.md"
      - "Task count and dependency graph"
    requires:
      - "Issue ID"
      - "Design doc (if brainstorming ran)"

  - from: git-worktrees
    to: executing-plans
    provides:
      - "Worktree path at .claude/worktrees/<issue-id>/"
      - "Branch name (<issue-id>/<description>)"
      - "Base commit hash"
      - "Baseline test/build/lint status"
    requires:
      - "Plan file at docs/plans/<issue-id>-plan.md"
      - "Valid issue ID matching ^[A-Z]+-[0-9]+$"

  - from: executing-plans
    to: "/workflows:review"
    provides:
      - "Implemented code and tests"
      - "Commit history on branch"
      - "Per-task verification reports"
      - "Per-task execution trace YAML blocks (consumed by compound-learnings via conversation context)"
    requires:
      - "Plan file at docs/plans/<issue-id>-plan.md"
      - "Design doc at docs/designs/<issue-id>-*.md (if brainstorming ran)"
      - "Clean working state"

  - from: "/workflows:review"
    to: "/workflows:ship"
    provides:
      - "TRIAGE_VERDICT (trivial/non-trivial from diff-triage agent)"
      - "Agent selection results (tier, agent list, activation reasons, depth mode)"
      - "Simplify pass results (applied/suggestions/reverted)"
      - "Review findings (P1/P2/P3) with confidence scores"
      - "VALIDATED_FINDINGS (confirmed/downgraded/dismissed from per-finding verification)"
      - "P1 fixes applied (auto-fixable, confidence >= 7)"
      - "Borderline P1s for human review (confidence < 7)"
      - "Filtered finding count (low-confidence P2/P3s)"
      - "Verdict (ready/needs-input/blocked/has-borderline-p1s)"
    requires:
      - "Task tool dispatch working"

  - from: "/workflows:ship"
    to: compound-learnings
    provides:
      - "PR URL"
      - "Linear issue status update"
    requires:
      - "gh CLI authenticated"
      - "Tests and build passing"

  - from: compound-learnings
    to: best-practices-audit
    provides:
      - "CLAUDE.md updates (entries added/updated/pruned)"
      - "Fact-check results"
      - "Session summary in auto-memory"
      - "Decision traces written to docs/precedents/<ISSUE-ID>.md"
      - "Precedent INDEX updated at docs/precedents/INDEX.md"
    requires:
      - "Diff exists on branch"
      - "CLAUDE.md exists"

  # Return handoff: best-practices-audit completes and returns control to ship
  - from: best-practices-audit
    to: "/workflows:ship"
    provides:
      - "CLAUDE.md auto-fixes"
      - "Flagged items for developer"
    requires:
      - "CLAUDE.md exists"
```

### 3b. Artifact Registry

<!-- spec:contract:artifact-registry -->
```yaml
artifacts:
  - id: design-doc
    path: "docs/designs/<issue-id>-<slug>.md"
    producer: brainstorming
    consumers: [writing-plans, git-worktrees, executing-plans, compound-learnings]
    persistence: permanent

  - id: plan-file
    path: "docs/plans/<issue-id>-plan.md"
    producer: writing-plans
    consumers: [git-worktrees, executing-plans, compound-learnings]
    persistence: permanent

  - id: worktree
    path: ".claude/worktrees/<issue-id>/"
    producer: git-worktrees
    consumers: [executing-plans, "ship (command)"]
    persistence: temporary

  - id: claude-md
    path: "CLAUDE.md"
    producer: compound-learnings
    consumers: [best-practices-audit, session-start, writing-plans]
    persistence: permanent

  - id: session-summary
    path: "auto-memory directory"
    producer: compound-learnings
    consumers: [session-start, scope]
    persistence: permanent

  - id: adr-file
    path: "docs/decisions/NNN-<slug>.md"
    producer: "architecture-decision (command)"
    consumers: ["session-start (via CLAUDE.md @import)"]
    persistence: permanent

  - id: company-context
    path: "CLAUDE.md (## Company Context section)"
    producer: "session-start (command, Step 2)"
    consumers: [brainstorming, writing-plans, executing-plans, compound-learnings]
    persistence: permanent
    schema:
      fields:
        - name: initiative
          type: string
          source: "Linear MCP (get_project)"
          sanitization: "[a-zA-Z0-9 _.,/-], max 120 chars"
        - name: goal
          type: string
          source: "developer input (AskUserQuestion)"
        - name: team
          type: string
          source: "Linear MCP (get_project)"
          sanitization: "[a-zA-Z0-9 _.,/-], max 120 chars"
        - name: lead
          type: string
          source: "Linear MCP (get_project)"
          sanitization: "[a-zA-Z0-9 _.,/-], max 120 chars"
        - name: related-projects
          type: "string[]"
          source: "Linear MCP + developer input"
          sanitization: "[a-zA-Z0-9 _.,/-], max 120 chars each"
        - name: handbook-library
          type: string
          source: "hardcoded (/brite-nites/handbook)"
        - name: handbook-topics
          type: "string[]"
          source: "developer input (AskUserQuestion)"
          sanitization: "[a-zA-Z0-9 _-], max 40 chars each"

  - id: refined-plan
    path: "docs/project-plan-refined.md"
    producer: refine-plan
    consumers: [create-issues]
    persistence: permanent

  - id: issues-created-log
    path: "docs/linear-issues-created.md"
    producer: create-issues
    consumers: []
    persistence: permanent

  - id: project-traits
    path: "CLAUDE.md (## Project Traits section)"
    producer: "project-start (command)"
    consumers: ["BC-1944 (trait-conditional doc scaffolding)", "BC-1945 (dynamic @imports)", "BC-1966 (context-skill standard)"]
    persistence: permanent

  - id: v1-plan
    path: "docs/project-plan-v1.md"
    producer: "project-start (command)"
    consumers: [post-plan-setup, refine-plan]
    persistence: permanent

  - id: trait-conditional-docs
    path: "docs/<trait-specific>.md"
    producer: "project-start (command)"
    consumers: ["session-start (via @import)", "BC-1945 (dynamic @imports)"]
    persistence: permanent

  - id: execution-trace
    path: "conversation context (fenced YAML blocks with # execution-trace-v1 marker)"
    producer: executing-plans
    consumers: [compound-learnings]
    persistence: session

  - id: precedent-file
    path: "docs/precedents/<ISSUE-ID>.md"
    producer: compound-learnings
    consumers: ["precedent-search (skill)", "brainstorming"]
    persistence: permanent

  - id: precedent-index
    path: "docs/precedents/INDEX.md"
    producer: compound-learnings
    consumers: ["precedent-search (skill)", "brainstorming", "writing-plans"]
    persistence: permanent
```

### 3c. Post-Plan Chain

<!-- spec:contract:post-plan-chain -->
```yaml
chain: post-plan
sequence:
  - from: post-plan-setup
    to: refine-plan
    provides:
      - "v1 plan file path"
    requires:
      - "v1 plan file exists"
      - "Linear MCP available"
      - "Sequential thinking MCP available"

  - from: refine-plan
    to: create-issues
    provides:
      - "Refined plan at docs/project-plan-refined.md"
      - "Task dependency graph"
      - "Per-task context, steps, validation, complexity"
    requires:
      - "v1 plan file"

  - from: create-issues
    to: setup-claude-md
    provides:
      - "Linear issues created and linked"
      - "Updated docs/project-plan-refined.md with issue IDs"
      - "docs/linear-issues-created.md"
    requires:
      - "Refined plan at docs/project-plan-refined.md"
      - "Linear MCP available"

  - from: setup-claude-md
    to: null
    provides:
      - "CLAUDE.md in project root"
    requires:
      - "claude-code-best-practices.md reference readable"
```

### 3d. Project-Start Chain

<!-- spec:contract:project-start-chain -->
```yaml
chain: project-start
trait-interface:
  format:
    active: "comma-space separated trait names on a single line"
    autonomy: "A or B"
    evidence: "one line per active trait in ### Trait Evidence"
  valid-traits:
    - produces-code
    - produces-documents
    - involves-data
    - requires-decisions
    - has-external-users
    - client-facing
    - needs-design
    - needs-marketing
    - needs-sales
    - cross-team
    - automation
  consumers:
    - "BC-1944 (trait-conditional doc scaffolding): reads active traits to scaffold trait-doc templates"
    - "BC-1945 (dynamic @imports): reads active traits to resolve trait-conditional @imports"
    - "BC-1966 (context-skill standard): defines the contract format that domain context-skills must follow"
  invariants:
    - "active: is always a single line"
    - "Trait names are kebab-case from the fixed set of 11"
    - "Delimiter is always comma-space (, )"
    - "Every active trait has an evidence line"
    - "autonomy: is always A or B"
```

### 3e. Context-Skill Standard

<!-- spec:contract:context-skill-standard -->
```yaml
contract: context-skill-standard
issue: BC-1966
spec: docs/designs/BC-1966-context-skill-standard.md

context-doc-frontmatter:
  required:
    - name: domain
      type: string
      values: [engineering, marketing, design, sales, data]  # product planned but no trait yet
    - name: trait
      type: string
      values: [produces-code, needs-marketing, needs-design, needs-sales, involves-data]  # subset: domain-linked traits only (5 of 11)
    - name: last_refreshed
      type: string
      format: "YYYY-MM-DD (ISO 8601)"
      note: "CRITICAL: must be last_refreshed, not last_generated — session-start line 39 parses this exact key"
    - name: refresh_cadence
      type: string
      values: [quarterly, monthly, weekly, on-change]
      default: quarterly
    - name: generated_by
      type: string
      pattern: "^[a-z][a-z0-9-]*$"
      description: "Name of the context-skill that produced this file. Must be valid kebab-case."

trait-to-domain:
  produces-code: engineering
  needs-marketing: marketing
  needs-design: design
  needs-sales: sales
  involves-data: data

trait-to-context-doc:
  produces-code: docs/engineering-context.md
  needs-marketing: docs/marketing-context.md
  needs-design: docs/design-context.md
  needs-sales: docs/sales-context.md
  involves-data: docs/data-context.md

sor-fallback-tiers:
  - tier: full-enrichment
    available: "MCP + SoR access + interview data"
    experience: "Complete context doc with SoR-sourced data"
  - tier: partial-enrichment
    available: "MCP available but SoR query fails or times out"
    experience: "Interview data + <!-- needs-enrichment --> markers"
  - tier: interview-only
    available: "No MCP available"
    experience: "All content from project-start interview data"
  - tier: no-sor-dependency
    available: "Domain has no relevant SoR"
    experience: "Context doc from interview data; no SoR Sources section"

budget: "~80-200 lines per context doc (Tier 2)"
```

### 3f. Decision Trace Standard

<!-- spec:contract:decision-trace -->
```yaml
contract: decision-trace
issue: BC-1955
spec: docs/designs/BC-1955-decision-trace-spec.md

decision-trace-markdown:
  heading: "## Trace — <ISSUE-ID>/task-<N> — <YYYY-MM-DD>"
  fields:
    - name: Decision
      type: string
      max-length: 120
      required: true
    - name: Category
      type: enum
      values: [architecture, library-selection, pattern-choice, trade-off, bug-resolution, scope-change]
      required: true
    - name: Confidence
      type: integer
      range: [1, 10]
      required: true
    - name: Inputs
      type: bullet-list
      min-items: 1
      max-item-length: 200
      required: true
    - name: Alternatives Considered
      type: numbered-list
      min-items: 2
      required: true
      note: "Exactly 1 chosen + at least 1 rejected"
    - name: Precedent Referenced
      type: bullet-list
      max-item-length: 200
      required: true
      note: "'None' allowed as single item"
    - name: "Outcome: Files changed"
      type: string-list
      max-items: 20
      required: true
      note: "Relative paths only"
    - name: "Outcome: Tests"
      type: string
      required: true
      note: "Format: '<N> added, <N> passed, <N> failed' or 'N/A'"
    - name: "Outcome: Approved by"
      type: enum
      values: [PR review, human checkpoint, auto-verified]
      required: true

execution-trace-yaml:
  task-pattern: "^[A-Z]+-[0-9]+/task-[0-9]+$"
  required-keys: [task, agent, timestamp, duration, context_used, files_changed, tests, verification]
  decisions-made-entry:
    required: [type, chose, over, reason, confidence]
    type-values: [architecture, library-selection, pattern-choice, trade-off, bug-resolution, scope-change]
    confidence-range: [1, 10]

storage:
  project-level: "docs/precedents/<ISSUE-ID>.md"
  org-level: "handbook/precedents/<ISSUE-ID>.md"
  index: "docs/precedents/INDEX.md"

thresholds:
  storage-confidence: 6
  promotion-confidence: 8
  max-traces-per-task: 3

limits:
  per-trace-lines: 30
  per-issue-traces: 15
  decision-chars: 120
  bullet-item-chars: 200
  outcome-files-max: 20
  tags-per-entry: 5

integration:
  emitter: executing-plans
  consumer: compound-learnings
  transport: "conversation context (fenced YAML block)"
  trigger: "task checkpoint, after task completion"
  extraction: "compound-learnings scans for fenced YAML starting with # execution-trace-v1 marker and task: as second key"
  promotion: "Linear issue with label precedent-promotion; never auto-promoted"

index:
  path: "docs/precedents/INDEX.md"
  archive-path: "docs/precedents/INDEX-archive.md"
  columns: [Issue, Decision, Category, Date, Tags]
  archive-threshold: 200
  archive-age: "6 months"
  sort: chronological-by-insertion
  dedup-key: "Issue + Decision text"
  tag-derivation: "category as tag-1, key nouns from Decision as tags 2-5"
  tag-format: "^[a-z0-9]+(-[a-z0-9]+)*$"
  tag-max-length: 30
  tag-max-count: 5
```

---

## 4. Error Handling Contracts

### 4a. Inner Loop Skills

<!-- spec:errors:brainstorming -->
```yaml
skill: brainstorming
error-handling:
  - failure-point: "Issue ID missing"
    action: escalate
    detail: "Ask developer for issue ID via AskUserQuestion"
  - failure-point: "Linear inaccessible"
    action: degrade
    detail: "Proceed with whatever context is available"
  - failure-point: "Approval fails after 3 iterations"
    action: escalate
    detail: "AskUserQuestion: Approve as-is / Continue iterating / Stop and proceed to planning"
  - failure-point: "Design doc file write verification fails"
    action: retry
    detail: "Retry once. If still fails, report error and do not print completion marker"
```

<!-- spec:errors:writing-plans -->
```yaml
skill: writing-plans
error-handling:
  - failure-point: "Design doc missing when brainstorming should have run"
    action: escalate
    detail: "AskUserQuestion: Run brainstorming first / Provide doc path / Proceed without one"
  - failure-point: "Issue ID missing"
    action: escalate
    detail: "Ask developer for issue ID"
  - failure-point: "CDR INDEX unavailable (no Company Context, Context7 down, or no results)"
    action: skip
    detail: "Log reason in Decision Log format, proceed with planning without CDR awareness"
  - failure-point: "Plan file cannot be read for task count"
    action: degrade
    detail: "Fall back to counting tasks from plan text in context window, note discrepancy"
  - failure-point: "Plan-review reveals blocking issues after 3 iterations"
    action: escalate
    detail: "AskUserQuestion: Approve plan as-is / Continue iterating / Stop and revisit design"
```

<!-- spec:errors:git-worktrees -->
```yaml
skill: git-worktrees
error-handling:
  - failure-point: "Plan file does not exist"
    action: STOP
    detail: "No plan file found. Run planning first."
  - failure-point: "Issue ID invalid"
    action: STOP
    detail: "Stop and ask developer for valid issue ID"
  - failure-point: "Working directory dirty"
    action: escalate
    detail: "AskUserQuestion: Stash changes / Commit changes first / Abort worktree setup"
  - failure-point: "Baseline tests fail"
    action: escalate
    detail: "AskUserQuestion: Proceed with known failures / Investigate baseline failures / Stop and fix main first"
```

<!-- spec:errors:executing-plans -->
```yaml
skill: executing-plans
error-handling:
  - failure-point: "Plan file does not exist"
    action: STOP
    detail: "No plan file found. Run planning first."
  - failure-point: "Working directory dirty"
    action: STOP
    detail: "Commit or stash changes before executing"
  - failure-point: "Task stuck (3+ consecutive tool calls without progress)"
    action: escalate
    detail: "AskUserQuestion: Retry with different approach / Skip this task / Stop execution"
  - failure-point: "Skip requested but dependent tasks exist"
    action: escalate
    detail: "Warn user about dependents, treat as Stop unless explicitly confirmed"
  - failure-point: "Verification BLOCKED after 3 retries"
    action: escalate
    detail: "AskUserQuestion: Retry with different approach / Skip task and continue / Stop execution"
```

<!-- spec:errors:verification-before-completion -->
```yaml
skill: verification-before-completion
error-handling:
  - failure-point: "Level 1 (build) fails"
    action: STOP
    detail: "Task is NOT complete. Stop and fix."
  - failure-point: "Any verification level fails"
    action: retry
    detail: "Analyze root cause, fix, re-verify from Level 1"
  - failure-point: "Max 3 retries exhausted"
    action: escalate
    detail: "AskUserQuestion: Retry from Level 1 with different approach / Skip this level / Stop for manual review"
```

<!-- spec:errors:compound-learnings -->
```yaml
skill: compound-learnings
error-handling:
  - failure-point: "No commits on branch"
    action: skip
    detail: "Skip compounding: No commits on branch. Nothing to compound."
  - failure-point: "CLAUDE.md missing"
    action: escalate
    detail: "AskUserQuestion: Create one with /workflows:setup-claude-md / Skip compounding"
  - failure-point: "CLAUDE.md write fails"
    action: escalate
    detail: "AskUserQuestion: Retry write / Skip CLAUDE.md updates / Stop compounding"
  - failure-point: "No execution traces in conversation"
    action: skip
    detail: "Phase 2 skipped: No execution traces found — skipping trace extraction"
  - failure-point: "Context7 MCP unavailable for CDR cross-reference"
    action: degrade
    detail: "CDR cross-reference skipped; traces written without CDR lookup"
  - failure-point: "Linear MCP unavailable for promotion flagging"
    action: degrade
    detail: "Promotion candidates logged in report but not created as Linear issues"
  - failure-point: "Precedent file write fails"
    action: escalate
    detail: "AskUserQuestion: Retry write / Skip trace storage / Stop compounding"
```

<!-- spec:errors:best-practices-audit -->
```yaml
skill: best-practices-audit
error-handling:
  - failure-point: "CLAUDE.md missing"
    action: STOP
    detail: "No CLAUDE.md found. Use /workflows:setup-claude-md to create one."
  - failure-point: "Best-practices reference not accessible"
    action: degrade
    detail: "Use built-in audit checklist as authoritative guide"
```

<!-- spec:errors:systematic-debugging -->
```yaml
skill: systematic-debugging
error-handling:
  - failure-point: "Cannot reproduce bug"
    action: escalate
    detail: "AskUserQuestion: Add more logging and retry / Get more info from reporter / Proceed with best guess (risky)"
```

### 4b. Commands

<!-- spec:errors:session-start -->
```yaml
command: session-start
error-handling:
  - failure-point: "Linear MCP unavailable"
    action: STOP
    detail: "Cannot reach Linear. Run /workflows:smoke-test to diagnose."
  - failure-point: "Sequential-thinking MCP unavailable"
    action: STOP
    detail: "Cannot reach sequential-thinking. Run /workflows:smoke-test to diagnose."
  - failure-point: "Context7 MCP unavailable (Step 0)"
    action: degrade
    detail: "WARN — library docs and handbook context unavailable. Continue session."
  - failure-point: "Handbook not found on Context7 (Step 0)"
    action: degrade
    detail: "WARN — handbook not indexed. Company context interview skips handbook validation."
  - failure-point: "Working directory dirty (Step 1)"
    action: escalate
    detail: "Warn and ask how to proceed"
  - failure-point: "Company context interview skipped by user (Step 2)"
    action: skip
    detail: "Write <!-- no-company-context --> marker, proceed to Step 3"
  - failure-point: "No Linear project configured"
    action: escalate
    detail: "Warn and ask user for project name manually"
  - failure-point: "No open issues found"
    action: escalate
    detail: "AskUserQuestion: Create a new issue?"
  - failure-point: "No @imported files have freshness frontmatter (Step 1)"
    action: skip
    detail: "Silent pass — no warnings, proceed normally"
  - failure-point: "@imported file has stale freshness (Step 1)"
    action: degrade
    detail: "Advisory warning per tier (Aging/Stale/Very stale). Do not stop."
```

<!-- spec:errors:review -->
```yaml
command: review
error-handling:
  - failure-point: "Agent dispatch fails (Step 0)"
    action: STOP
    detail: "Agent dispatch failed. Cannot run review agents."
  - failure-point: "Diff triage agent fails (Step 2)"
    action: degrade
    detail: "Assume NON-TRIVIAL, proceed to Step 3"
  - failure-point: "Simplify agent fails to dispatch (Step 3)"
    action: degrade
    detail: "Skip simplify pass, proceed to Step 4"
  - failure-point: "No test suite detected (Step 3 auto-fix)"
    action: degrade
    detail: "Report all simplify findings as suggestions only, skip auto-fix"
    note: "Branch condition within Step 3, not a step-level failure"
  - failure-point: "Review agent fails to dispatch (Step 4)"
    action: escalate
    detail: "AskUserQuestion: Retry failed agent / Continue with available results / Stop review"
  - failure-point: "Unrecognized depth mode in $ARGUMENTS (Step 4)"
    action: degrade
    detail: "Default to thorough (Tier 1 + Tier 2)"
  - failure-point: "Stack detection fails (Step 4)"
    action: degrade
    detail: "Proceed with Tier 1 agents only (code-reviewer, security-reviewer, performance-reviewer)"
  - failure-point: "CLAUDE.md override parse fails (Step 4)"
    action: degrade
    detail: "Ignore overrides, proceed with agents selected from Tiers 1-2"
  - failure-point: "Missing confidence score on finding (Step 5)"
    action: degrade
    detail: "Default to confidence 5. P2/P3 filtered, P1 routed to human review."
  - failure-point: "Validation subagent fails (Step 6)"
    action: degrade
    detail: "Treat finding as CONFIRMED, proceed with remaining validations"
  - failure-point: "Validation subagent cap exceeded (Step 6)"
    action: degrade
    detail: "Batch remaining P3s into a single Sonnet subagent"
  - failure-point: "P1 persists after 3 fix attempts (Step 7)"
    action: escalate
    detail: "Flag for human review with full context on what was tried"
```

<!-- spec:errors:ship -->
```yaml
command: ship
error-handling:
  - failure-point: "gh not authenticated (Step 0)"
    action: STOP
    detail: "GitHub CLI not authenticated. Run gh auth login first."
  - failure-point: "Not in GitHub-connected repo (Step 0)"
    action: STOP
    detail: "Not in a GitHub-connected repository."
  - failure-point: "Pre-ship check fails (Step 1)"
    action: escalate
    detail: "AskUserQuestion: Fix the failing check / Skip (requires double confirmation) / Stop"
  - failure-point: "PR creation fails (Step 2)"
    action: escalate
    detail: "AskUserQuestion: Retry push and PR creation / Create PR manually / Stop"
  - failure-point: "Linear MCP inaccessible (Step 3)"
    action: degrade
    detail: "Provide manual steps"
```

<!-- spec:errors:sprint-planning -->
```yaml
command: sprint-planning
error-handling:
  - failure-point: "Linear MCP unavailable (Step 0)"
    action: STOP
    detail: "Cannot reach Linear. Run /workflows:smoke-test to diagnose."
  - failure-point: "Sequential-thinking MCP unavailable (Step 0)"
    action: STOP
    detail: "Cannot reach sequential-thinking. Run /workflows:smoke-test to diagnose."
  - failure-point: "No Linear project configured (Step 1)"
    action: escalate
    detail: "Warn and ask user for project name manually"
  - failure-point: "Unrecognised $ARGUMENTS (Step 1)"
    action: escalate
    detail: "Warn and AskUserQuestion: Next cycle / Current cycle review / Specific cycle number"
  - failure-point: "No cycles exist (Step 1)"
    action: degrade
    detail: "Enter prioritization-only mode: skip Steps 2c and 5"
  - failure-point: "Individual issue assignment fails (Step 5)"
    action: degrade
    detail: "Continue with remaining assignments, report failures"
```

<!-- spec:errors:retrospective -->
```yaml
command: retrospective
error-handling:
  - failure-point: "Linear MCP unavailable (Step 0)"
    action: STOP
    detail: "Cannot reach Linear. Run /workflows:smoke-test to diagnose."
  - failure-point: "Sequential-thinking MCP unavailable (Step 0)"
    action: STOP
    detail: "Cannot reach sequential-thinking. Run /workflows:smoke-test to diagnose."
  - failure-point: "No cycles exist (Step 1)"
    action: STOP
    detail: "No cycles found. Create a cycle in Linear first."
  - failure-point: "Individual issue creation fails (Step 5)"
    action: degrade
    detail: "Continue with remaining issues, report failures"
```

<!-- spec:errors:scope -->
```yaml
command: scope
error-handling:
  - failure-point: "Linear MCP unavailable (Step 0)"
    action: STOP
    detail: "Cannot reach Linear. Run /workflows:smoke-test to diagnose."
  - failure-point: "Sequential-thinking MCP unavailable (Step 0)"
    action: STOP
    detail: "Cannot reach sequential-thinking. Run /workflows:smoke-test to diagnose."
```

<!-- spec:errors:architecture-decision -->
```yaml
command: architecture-decision
error-handling:
  - failure-point: "Sequential-thinking MCP unavailable (Step 0)"
    action: STOP
    detail: "Cannot reach sequential-thinking. Run /workflows:smoke-test to diagnose."
  - failure-point: "$ARGUMENTS validation fails (Step 1)"
    action: degrade
    detail: "Treat as empty, ask user for topic manually"
  - failure-point: "Context fact-check finds inaccuracies (Step 7d)"
    action: escalate
    detail: "Present corrections to developer, incorporate accepted changes"
  - failure-point: "No project CLAUDE.md (Step 8)"
    action: skip
    detail: "Skip CLAUDE.md update, note: add @import when CLAUDE.md is created"
```

<!-- spec:errors:project-start -->
```yaml
command: project-start
error-handling:
  - failure-point: "Technical level question unanswered (Step 0)"
    action: escalate
    detail: "Re-ask with simplified options. Default to Autonomy A if no response after 2 attempts."
  - failure-point: "Interview stalls or user disengages (Step 1)"
    action: degrade
    detail: "Summarize what's been gathered, confirm it's enough to proceed, skip remaining questions."
  - failure-point: "0 traits detected after interview (Step 2)"
    action: escalate
    detail: "Suggest 2-3 plausible Low-confidence traits based on conversation. AskUserQuestion to confirm."
  - failure-point: "Git init fails (Step 3)"
    action: escalate
    detail: "AskUserQuestion: Retry / Skip git setup and proceed with file creation / Stop"
  - failure-point: "Trait-conditional doc write fails (Step 4)"
    action: degrade
    detail: "Log failed file, continue with remaining docs. Note missing doc in manifest."
  - failure-point: "Linear MCP inaccessible (Step 6)"
    action: skip
    detail: "Skip Linear project creation. Note: user should create project manually."
  - failure-point: "Trait label creation fails (Step 6)"
    action: degrade
    detail: "Label creation is best-effort. Skip failed labels silently, continue with remaining traits. Note missing labels for manual creation."
  - failure-point: "MCP verification fails (Sub-step 4c)"
    action: degrade
    detail: "All MCP failures are non-blocking. Record status, present WARN table, continue. Missing MCPs noted in generated CLAUDE.md."
  - failure-point: "ADR trait gate not met (Step 8)"
    action: skip
    detail: "ADR generation skipped. Show: Run /workflows:architecture-decision later."
  - failure-point: "Express mode: 0 file markers found but $ARGUMENTS = 'express'"
    action: degrade
    detail: "Show empty detection with all traits under 'Not detected'. Let user manually add traits or select 'Run full interview instead.'"
  - failure-point: "Express mode: user adjustment exceeds 3 rounds"
    action: escalate
    detail: "After 3 adjustment rounds, confirm current trait set or offer 'Run full interview instead.'"
  - failure-point: "Brownfield: existing CLAUDE.md conflicts with detected conventions"
    action: escalate
    detail: "Present both sources side-by-side via AskUserQuestion. Ask user which is current. Use their answer for doc pre-fill."
  - failure-point: "Brownfield: Context7 unavailable for CDR reconciliation"
    action: skip
    detail: "Skip CDR reconciliation. Note: 'Company decision record check skipped — Context7 unavailable.'"
  - failure-point: "Brownfield: README unreadable or binary"
    action: skip
    detail: "Skip README import. Note: 'README could not be parsed. Proceeding without README context.'"
```

## 5. Context Loading Cascade

Authoritative specification for when context loads during the inner loop. Governs what each stage should load and at what tier. See `docs/designs/BRI-2006-context-loading-cascade.md` for rationale and design decisions.

### 5a. Loading Table

<!-- spec:cascade:loading-table -->
```yaml
principle: "Load context at the narrowest scope that still informs the decision"
stages:
  - stage: project-start
    skill: project-start.md
    what-loads: "Trait classification, trait-conditional infrastructure, CLAUDE.md generation with @imports"
    how: "Interview + write + trait dispatch"
    tier: [1, 2]
    status: implemented
    note: "Infrastructure gates: .gitignore extensions (produces-code), GitHub remote (produces-code), CI/CD flag (produces-code + automation), data warehouse MCP verification (involves-data), deployment flag (has-external-users), ADR generation (requires-decisions or produces-code with 2+ decisions)"

  - stage: session-start
    skill: session-start.md
    what-loads: "CLAUDE.md (Tier 1+2), auto-memory, Company Context check, @import freshness check, Linear issues"
    how: "Read + MCP queries"
    tier: [1, 2]
    status: implemented

  - stage: brainstorm
    skill: brainstorming/SKILL.md
    what-loads: "Linear issue, CLAUDE.md, auto-memory, relevant source code, precedent INDEX search"
    how: "Read + Linear MCP + Read INDEX + Context7 MCP"
    tier: [1, 2, 3]
    status: implemented
    implemented:
      - what: "Precedent search results from INDEX + Context7"
        issue: BC-1961
        tier: 3

  - stage: plan
    skill: writing-plans/SKILL.md
    what-loads: "Design doc, Linear issue, CDR INDEX via Context7 (Tier 3 on-demand), source code, test patterns"
    how: "Read + Context7 MCP"
    tier: [1, 2, 3]
    status: implemented
    note: "CDR INDEX is the only Tier 3 load; queried on-demand, not pre-loaded"

  - stage: execute
    skill: executing-plans/SKILL.md
    what-loads: "Design doc + plan file (parent); task desc + relevant files + conventions (subagent)"
    how: "Read; subagent gets narrowest scope"
    tier: [1, 5]
    status: implemented
    planned:
      - what: "Per-task context filtering (task-level, not project-level)"
        issue: null

  - stage: review
    skill: review.md
    what-loads: "Diff stat, changed files; review agents read files themselves"
    how: "git diff + agent dispatch"
    tier: [5]
    status: implemented
    planned:
      - what: "CDR compliance check"
        issue: null

  - stage: ship
    skill: "ship.md + compound-learnings/SKILL.md"
    what-loads: "CLAUDE.md, diff, commit history; captures learnings back"
    how: "Read + write"
    tier: [1, 4]
    status: implemented
```

### 5b. Context Layers

<!-- spec:cascade:context-layers -->
```yaml
layers:
  - layer: company
    tier: 1
    scope: organization-wide
    examples: "CDR INDEX, org structure, brand guidelines"
    loaded-at: session-start
    refresh: quarterly
    status: partial
    note: "Company Context pointers implemented; @imports planned in BRI-1945"

  - layer: precedent
    tier: 3
    scope: all-projects
    examples: "Past ADRs, decision traces, search results"
    loaded-at: "brainstorm, plan"
    refresh: continuous
    status: specified
    spec: docs/designs/BC-1955-decision-trace-spec.md
    issue: BRI-1960

  - layer: domain
    tier: 2
    scope: plugin-specific
    examples: "engineering-context.md, design-context.md"
    loaded-at: project-start
    refresh: per-context-skill-standard
    status: specified
    spec: docs/designs/BC-1966-context-skill-standard.md
    issue: BC-1966

  - layer: project
    tier: 1
    scope: one-project
    examples: "CLAUDE.md, docs/, architecture decisions"
    loaded-at: session-start
    refresh: every-session
    status: implemented

  - layer: task
    tier: 5
    scope: one-task
    examples: "Relevant files, test results, Linear issue"
    loaded-at: execute
    refresh: every-task
    status: implemented
```

### 5c. Tier Definitions

<!-- spec:cascade:tiers -->
```yaml
tiers:
  - tier: 1
    name: always
    description: "Loaded at session start for every session"
    examples: "Project CLAUDE.md, auto-memory"
    budget: "~50-100 lines"

  - tier: 2
    name: per-project
    description: "Loaded at session start via @imports based on project traits"
    examples: "Company Context pointers, domain context docs"
    budget: "~80-200 lines per doc"

  - tier: 3
    name: on-demand
    description: "Agent reads when task requires it; not pre-loaded"
    examples: "Full CDR documents, precedent traces, analytical metrics"
    budget: variable

  - tier: 5
    name: task-scoped
    description: "Loaded per-subagent during execution; narrowest scope"
    examples: "Task-relevant files, test results, specific code"
    budget: variable
```

### 5d. Budget Guards

<!-- spec:cascade:budget-guards -->
```yaml
budget-principle: "Tier 1+2 context should consume <5% of context window (~100-300 lines total)"

guards:
  - stage: project-start
    guard: "Generated CLAUDE.md should stay under ~100 lines; extract detail to docs/ via @import"
    enforcement: advisory
    status: delivered
    issue: BC-2003

  - stage: session-start
    guard: "After loading CLAUDE.md + auto-memory, warn if CLAUDE.md exceeds ~120 lines"
    enforcement: advisory
    status: delivered
    issue: BC-2003

  - stage: session-start
    guard: "Compute staleness_ratio for @imported files with last_refreshed/refresh_cadence frontmatter; warn on ratio >1.0"
    enforcement: advisory
    status: delivered
    issue: BC-1938

  - stage: plan
    guard: "CDR INDEX query is on-demand (Tier 3); full CDRs lazy-loaded only on conflict"
    enforcement: behavioral
    status: delivered
    issue: BRI-1939

  - stage: execute
    guard: "Per-task context selection — classify by file paths, inject only task-relevant CLAUDE.md sections"
    enforcement: behavioral
    status: delivered
    issue: BC-2003

  - stage: review
    guard: "Review agents read files themselves; parent provides only diff stat and changed file list"
    enforcement: behavioral
    status: delivered
    issue: null

  - stage: ship
    guard: "best-practices-audit enforces CLAUDE.md conciseness and @import extraction"
    enforcement: behavioral
    status: delivered
    issue: null

offloading-strategy:
  in-context:
    - "Project CLAUDE.md (Tier 1, <100 lines)"
    - "Auto-memory session summaries (Tier 1, ~20-40 lines)"
    - "Company Context pointers (Tier 2, ~3-5 lines)"
    - "Build & test commands (Tier 1, always injected per-task)"

  in-filesystem:
    - "Full CDR documents — loaded on-demand via Context7 during plan stage"
    - "Precedent search results — implemented (BC-1961), INDEX at docs/precedents/INDEX.md + org-level via Context7"
    - "Design docs — loaded per-task by executing-plans parent agent"
    - "Domain context docs — @imported at session-start (Tier 2), not inlined"
    - "Architecture Decision Records — @imported via CLAUDE.md, not inlined"
    - "Analytical metrics — loaded on-demand for data tasks only"

progressive-disclosure:
  - pattern: "CDR INDEX → full CDR"
    status: implemented
    issue: BRI-1939
    description: "writing-plans queries CDR INDEX via Context7; lazy-loads full CDR only on conflict"

  - pattern: "Precedent INDEX → full trace"
    status: implemented
    issue: BC-1961
    description: "Brainstorm/plan query precedent INDEX; full traces lazy-loaded on match"

  - pattern: "Metric definitions → metric values"
    status: planned
    issue: null
    description: "Data tasks will load metric definitions; actual values queried on-demand from analytics"

measurement:
  method: "Manual line-count audit per release"
  target: "Tier 1+2 < 5% of context window (~100-300 lines)"
  baseline:
    tier-1: "~80-140 lines (CLAUDE.md + auto-memory)"
    tier-2: "~3-5 lines (Company Context pointers)"
    total: "~103-145 lines — within 5% target"
```
