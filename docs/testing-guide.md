# Comprehensive Testing Guide

Complete testing reference for the Brite Claude Code plugin. Covers automated validation, interactive skill/command testing, end-to-end flows, hooks, and agent dispatch.

Use this guide when working on the plugin itself or when verifying behavior after changes.

## Prerequisites

- Fresh terminal (not inside Claude)
- Plugin installed or loaded via `--plugin-dir`
- A test Linear project with at least 1 open issue
- GitHub CLI authenticated (`gh auth status`)
- A test project directory for commands that write files (e.g., `/tmp/test-project`)

## Quick Smoke Subset (~10 min)

For fast validation after changes, run only these:

1. T0.1 + T0.2 + T0.6 — automated scripts pass
2. T1.1 + T1.2 — plugin loads, SessionStart fires
3. T1.3 — smoke-test command
4. T2.1 + T2.7 + T2.9 — one skill from each category triggers
5. T3.1 — tech-stack renders
6. T3.6 — code-review quick mode on a diff

---

## Layer 0: Automated Validation (~2 min)

Run these outside Claude, from a regular terminal or CI.

| Test | Command | Expected |
|------|---------|----------|
| T0.1 Structural validation | `bash scripts/validate.sh` | 0 errors, 0 warnings |
| T0.2 Hook regex tests | `bash scripts/test-hooks.sh` | 37/37 pass |
| T0.3 Prerequisites check | `bash scripts/check-prereqs.sh` | All PASS (or explained SKIPs) |
| T0.4 Command registration | `bash scripts/test-plugin-load.sh` | All 21 commands found |
| T0.5 CI workflow | Push to branch, check GitHub Actions | All steps green |
| T0.6 Scenario validation | `bash scripts/test-scenarios.sh` | 225/225 pass (60 scenarios + 12 FP regressions + 6 express mode, 7 categories) |

---

## Tier 2+3: Behavioral Tests

> **Naming note:** "Layer 0" above corresponds to "Tier 1" in the [research framework](../research/behavioral-testing-evaluation.md) — free, structural, offline tests. Tiers 2 and 3 below add runtime behavioral validation that requires Claude invocations and LLM-as-judge scoring.

### Tier 2: Behavioral Tests (~15-25 min, ~$2-5)

Runtime behavioral tests that validate skill activation and output quality via `claude -p` subprocess invocations. These cost money — guarded by `EVALS=1`.

**Research:** `docs/research/behavioral-testing-evaluation.md` (BC-2458)

### Running

```bash
# List all test cases
EVALS=1 bash scripts/test-behavioral.sh --list

# Dry run — parse fixtures, no Claude invocations
EVALS=1 bash scripts/test-behavioral.sh --dry-run

# Run a single test case
EVALS=1 bash scripts/test-behavioral.sh --filter B01

# Run all tests
EVALS=1 bash scripts/test-behavioral.sh

# Run with multiple trials for non-determinism
EVALS=1 EVALS_TRIALS=5 bash scripts/test-behavioral.sh
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `EVALS` | (none) | Must be `1` to run. Safety guard. |
| `EVALS_MODEL` | `claude-sonnet-4-6` | Model for test invocations |
| `EVALS_TRIALS` | `1` | Trials per test (use 5 for reliable results) |
| `EVALS_TIMEOUT` | `120` | Timeout per invocation in seconds |

### Test Cases

10 seed test cases in `tests/fixtures/behavioral-registry.json`:

| ID | Type | Tests |
|----|------|-------|
| B01 | Activation | Brainstorming triggers on multi-module redesign |
| B02 | Non-activation | Brainstorming does NOT trigger on trivial change |
| B03 | Activation | Systematic debugging triggers on bug report |
| B04 | Activation | frontend-design triggers on build/create UI task |
| B05 | Activation | ui-ux-pro-max triggers on design planning task |
| B06 | Activation | web-design-guidelines triggers on review/audit task |
| B07 | Precedence | Debugging beats brainstorming when bug is present |
| B08 | Activation | code-quality triggers on linting setup |
| B09 | Non-activation | No skill fires for irrelevant prompt |
| B10 | Quality | Brainstorming output meets clarity/completeness threshold |

### Adding Test Cases

Add entries to `tests/fixtures/behavioral-registry.json`. Schema:

```json
{
  "id": "B11",
  "description": "Human-readable test purpose",
  "tier": 2,
  "prompt": "The exact prompt sent to claude -p",
  "expected_skill": "skill-name or null",
  "expected_markers": ["strings that MUST appear in output"],
  "not_expected_markers": ["strings that must NOT appear"],
  "not_expected_skills": ["skills that should NOT activate"],
  "judge_rubric": { "clarity": 4, "completeness": 4, "actionability": 4 },
  "estimated_cost": "$0.30",
  "notes": "Why this test exists"
}
```

Set `judge_rubric` to `null` if the test case doesn't need LLM-as-judge scoring.

### Results

Results are written to `tests/evals/behavioral-{timestamp}.json`. CI uploads these as artifacts for regression comparison.

---

### Tier 3: LLM-as-Judge Scoring (~30s, ~$0.10-0.20)

Scores Tier 2 outputs using Haiku as a judge model. Uses **per-skill rubric files** when available (4 dimensions), with fallback to hardcoded 3-dimension scoring.

### Running

```bash
# Pipeline scoring (reads behavioral test results)
ANTHROPIC_API_KEY=sk-... bash scripts/score-behavioral.sh
ANTHROPIC_API_KEY=sk-... bash scripts/score-behavioral.sh tests/evals/behavioral-20260327-120000.json

# Ad-hoc scoring (score any skill output against its rubric)
ANTHROPIC_API_KEY=sk-... bash scripts/score-skill-output.sh --skill brainstorming --input output.txt
ANTHROPIC_API_KEY=sk-... bash scripts/score-skill-output.sh --skill writing-plans --input - --format json
bash scripts/score-skill-output.sh --list  # list available rubrics
```

### Dimensions

Per-skill rubric files (`tests/rubrics/{skill-name}.md`) define 4 dimensions:

| Dimension | Scale | What it measures |
|-----------|-------|------------------|
| Clarity | 1-5 | Well-organized, easy to follow, free of confusion |
| Completeness | 1-5 | Addresses all aspects of the task, no gaps |
| Actionability | 1-5 | User can take concrete next steps from the output |
| Adherence | 1-5 | Follows the skill's defined protocol and conventions |

Each rubric includes skill-specific anchor tables and criteria checklists. Pass criteria: per-dimension threshold met AND weighted average >= `pass_threshold` (default 3.0/5.0).

Test cases without a matching rubric file fall back to the original 3-dimension scoring (clarity, completeness, actionability) with thresholds from `judge_rubric` in the test registry.

See `docs/skill-rubrics.md` for the full rubric system documentation.

### CI Integration

Behavioral tests run via `.github/workflows/behavioral-tests.yml`:
- **Schedule:** Mon + Thu at 6am UTC
- **Manual:** `workflow_dispatch` with optional `filter` and `trials` inputs
- **Budget:** ~$2-5 per run, ~$33-53/month at 2x/week cadence

---

## Layer 1: Plugin Loading & Environment (~3 min)

| Test | Steps | Expected |
|------|-------|----------|
| T1.1 Plugin loads | Start `claude --plugin-dir ./plugins/workflows`, type `/workflows:` | 21 commands in autocomplete: `architecture-decision`, `audit-trail`, `bug-report`, `code-review`, `create-plugin`, `deployment-checklist`, `fact-check`, `flywheel-metrics`, `onboarding-checklist`, `project-start`, `promote-precedent`, `retrospective`, `review`, `scope`, `security-audit`, `session-start`, `setup-claude-md`, `ship`, `smoke-test`, `sprint-planning`, `tech-stack` |
| T1.2 SessionStart hook | Observe session start output | Environment banner with git/node/gh/npx status + key commands listed |
| T1.3 Smoke test | Run `/workflows:smoke-test` | Summary table with PASS/FAIL/SKIP/KNOWN ISSUE for 8 checks (env, MCP, hooks, agents) |

---

## Layer 2: Skill Trigger Tests (~10 min)

Test that saying specific phrases activates the correct skill. Verify by observing which skill name appears in the response context.

### Inner Loop Skills

| Test | Say this | Expected skill |
|------|----------|----------------|
| T2.1 | "I need to plan a new feature for user onboarding" | `brainstorming` |
| T2.2 | "I have a bug that's hard to reproduce" | `systematic-debugging` |
| T2.3 | (after brainstorming) Plan is presented | `writing-plans` |
| T2.4 | (after plan approval) Worktree setup begins | `git-worktrees` |
| T2.5 | (after worktree) Execution begins | `executing-plans` |
| T2.6 | (during execution) Checkpoint verification | `verification-before-completion` |

Note: T2.3–T2.6 are sequential — they trigger as part of the inner loop flow and are also tested in Layer 4 (T4.1).

### Design Skills

| Test | Say this | Expected skill |
|------|----------|----------------|
| T2.7 | "Build a login form with email and password" | `frontend-design` |
| T2.8 | "Choose a color palette for a SaaS dashboard" | `ui-ux-pro-max` |
| T2.9 | "Review my UI for accessibility issues" | `web-design-guidelines` |

### Quality / Reference Skills

| Test | Say this | Expected skill |
|------|----------|----------------|
| T2.10 | "Review this React component for performance" | `react-best-practices` |
| T2.11 | "Set up ESLint and Prettier for this project" | `code-quality` |
| T2.12 | "Find a skill for database migrations" | `find-skills` |

---

## Layer 3: Individual Command Tests (~20 min)

### Safe / Read-Only

| Test | Command | Steps | Expected |
|------|---------|-------|----------|
| T3.1 | `/workflows:tech-stack` | Run it | Technology stack tables displayed (no external deps) |
| T3.2 | `/workflows:onboarding-checklist` | Run, answer first 2 prompts, then abort | Interactive checklist with `[x]` tracking |

### Requires Linear MCP

| Test | Command | Steps | Expected |
|------|---------|-------|----------|
| T3.3 | `/workflows:session-start` | Run → Step 0 passes → issue table shows → select issue → plan generated | Abort after plan is presented (before worktree/execution). Verify: MCP check passes, issues load, plan has tasks with file paths |
| T3.4 | `/workflows:scope` | Run → Step 0 passes → answer 2-3 interview questions → themes presented | Abort after themes. Verify: MCP check passes, Socratic questions asked via AskUserQuestion, themes use sequential-thinking |
| T3.5 | `/workflows:bug-report` | Run with a test bug title → fill in details → approve draft | Verify: Linear issue created with Bug label, structured description, environment table. **Cleanup:** delete the test issue in Linear |
| T3.16 | `/workflows:sprint-planning` | Run → Step 0 passes → project resolved → velocity shown → backlog displayed → select issues via sequential-thinking | Abort after selection. Verify: MCP prereqs pass, cycle data loads, backlog shows Todo + Backlog issues, velocity calculation uses completed cycles only |
| T3.17 | `/workflows:retrospective` | Run → Step 0 passes → cycle resolved → delivery summary shown → retro discussion flows → status update draft presented | Abort before posting. Verify: MCP prereqs pass, cycle data loads, completed/carried-over tables render, sequential-thinking drives discussion, health indicator suggested |
| T3.25 | `/workflows:project-start` MCP verification | Run → interview mentions data/analytics → confirm `involves-data` trait → observe MCP verification | Verify: table shows global MCPs + data warehouse status. Non-blocking — continues after WARN. |

### Requires Changes on a Branch

| Test | Command | Setup | Steps | Expected |
|------|---------|-------|-------|----------|
| T3.6 | `/workflows:code-review` | Make a small code change | Run without args | Quick review with P1/P2/P3 findings on current diff |
| T3.7 | `/workflows:code-review --deep` | Same branch | Run with `--deep` | Review agents dynamically selected and dispatched in parallel, merged report |
| T3.8 | `/workflows:review` | Same branch | Run → Step 0 agent dispatch check → self-verify → dynamic agent selection → report | Full review report with verdict |
| T3.9 | `/workflows:security-audit` | Any project | Run | Automated checks (deps, secrets, env) + agent review + health grade (A–F) |
| T3.10 | `/workflows:security-audit --quick` | Any project | Run with `--quick` | Automated checks only (no agent dispatch), faster |

### Requires gh CLI + Committed Changes

| Test | Command | Setup | Steps | Expected |
|------|---------|-------|-------|----------|
| T3.11 | `/workflows:ship` | Committed changes on a branch | Run → gh auth check → pre-ship checks → PR created → Linear updated → compound learnings → session summary | PR URL returned, Linear issue moved to "In Review". **Cleanup:** delete test PR |
| T3.12 | `/workflows:deployment-checklist` | Any project with package.json | Run | Deployment Confidence Report table with READY/CAUTION/BLOCKED |

### Creates Files (use temp directory)

| Test | Command | Setup | Steps | Expected |
|------|---------|-------|-------|----------|
| T3.13 | `/workflows:create-plugin` | In the plugin repo | Run with `test-plugin` → provide description → scaffold created → validate.sh passes | Verify: `plugins/test-plugin/` created, marketplace.json updated, validation passes. **Cleanup:** remove `plugins/test-plugin/`, revert marketplace.json |
| T3.14 | `/workflows:project-start` | `mkdir /tmp/test-project && cd /tmp/test-project` | Run → select "Technical collaborator" → answer 2-3 questions about building an API | Abort after trait confirmation. Verify: autonomy set to B, `produces-code` detected (High), trait confirmation prompt shown |
| T3.14a | `/workflows:project-start` (code-heavy) | `mkdir /tmp/test-api && cd /tmp/test-api` | Run → describe "Build an internal API with scheduled jobs" → complete interview → confirm traits | Verify: traits = `produces-code` (High), `automation` (Medium). Git: baseline + tech-stack .gitignore + CI/CD flag. Docs: `docs/engineering-context.md`, `docs/automation-patterns.md`. CLAUDE.md: Always-include (6) + Engineering Standards + Automation Patterns. Labels: `trait:produces-code`, `trait:automation`. ADR gate: met. **Cleanup:** `rm -rf /tmp/test-api` |
| T3.14b | `/workflows:project-start` (doc-heavy) | `mkdir /tmp/test-marketing && cd /tmp/test-marketing` | Run → describe "Write a marketing plan for product launch" → complete interview → confirm traits | Verify: traits = `produces-documents` (High), `needs-marketing` (High). Git: baseline only (no tech-stack extensions). Docs: `docs/brief.md`, `docs/outline.md`, `docs/marketing-context.md`. CLAUDE.md: Always-include (6) + Document Structure + Marketing Context, NO Engineering Standards. Labels: `trait:produces-documents`, `trait:needs-marketing`. ADR gate: NOT met — skipped. **Cleanup:** `rm -rf /tmp/test-marketing` |
| T3.14c | `/workflows:project-start` (multi-trait) | `mkdir /tmp/test-portal && cd /tmp/test-portal` | Run → describe "Build a customer portal with brand design" → complete interview → confirm traits | Verify: traits = `produces-code` (High), `has-external-users` (High), `needs-design` (Medium+). `client-facing` NOT auto-detected. Git: baseline + tech-stack .gitignore. Docs: `docs/engineering-context.md`, `docs/user-requirements.md`, `docs/design-context.md`. CLAUDE.md: Always-include (6) + Engineering Standards + User-Facing Requirements + Design Approach. Labels: `trait:produces-code`, `trait:has-external-users`, `trait:needs-design`. **Cleanup:** `rm -rf /tmp/test-portal` |
| T3.14d | `/workflows:project-start express` (explicit) | `mkdir /tmp/test-express && cd /tmp/test-express && npm init -y && touch tsconfig.json` | Run with `express` argument | Verify: express mode activates immediately (no offer prompt), `produces-code` detected (High) from package.json + tsconfig.json, trait confirmation shown with file evidence, after confirm skips directly to Git Repository Setup. **Cleanup:** `rm -rf /tmp/test-express` |
| T3.14e | `/workflows:project-start` (express auto-detected) | `mkdir /tmp/test-auto && cd /tmp/test-auto && npm init -y` | Run without `express` argument | Verify: express mode offered via AskUserQuestion (file markers detected), select "Yes" triggers file marker scan, `produces-code` detected (High). **Cleanup:** `rm -rf /tmp/test-auto` |
| T3.14f | `/workflows:project-start express` (trait adjustment) | `mkdir /tmp/test-adjust && cd /tmp/test-adjust && npm init -y && mkdir prisma` | Run with `express` argument | Verify: `produces-code` (High) + `involves-data` (High) detected, select "Let me adjust", add `automation`, re-presented list shows 3 traits with `automation` marked "User-added". **Cleanup:** `rm -rf /tmp/test-adjust` |
| T3.14g | `/workflows:project-start` (express declined) | `mkdir /tmp/test-decline && cd /tmp/test-decline && npm init -y` | Run without `express` argument | Verify: express mode offered, select "No, run full interview", proceeds to Interview Behavioral Guidelines and Phase 1. **Cleanup:** `rm -rf /tmp/test-decline` |
| T3.14h | `/workflows:project-start express` (brownfield + express) | `mkdir /tmp/test-bf && cd /tmp/test-bf && npm init -y && touch tsconfig.json && printf '# My Project\n\nA Next.js dashboard for analytics.\n\n## Tech Stack\n\nNext.js, TypeScript, Prisma, Tailwind CSS\n\n## Setup\n\nnpm install && npm run dev\n\n## Architecture\n\nMonorepo with turborepo.\n\n%.0s\n' {1..40} > README.md` | Run with `express` argument, accept brownfield when offered | Verify: express activates first (traits detected), then brownfield offered, context imported from README (project name, tech stack, setup), conventions detected, brownfield summary shown before Git Setup. **Cleanup:** `rm -rf /tmp/test-bf` |
| T3.14i | `/workflows:project-start` (brownfield without express) | `mkdir /tmp/test-bf2 && cd /tmp/test-bf2 && mkdir -p docs && for f in arch api design; do echo "# $f" > docs/$f.md; done && printf '# Existing Project\n%.0s\n' {1..60} > README.md` | Run without `express`, decline express if offered, accept brownfield | Verify: brownfield offered (README + docs/ detected), context imported, doc inventory shown (3 docs found), proceeds to full interview with seeded context. **Cleanup:** `rm -rf /tmp/test-bf2` |
| T3.14j | `/workflows:project-start express` (brownfield CDR reconciliation) | Existing TypeScript project with non-standard conventions (4-space indent, no linting config) | Run with `express`, accept brownfield | Verify: CDR reconciliation runs (or skips gracefully if Context7 unavailable), any conflicts/alignments shown in brownfield summary. **Cleanup:** remove temp dir |
| T3.14k | `/workflows:project-start` (brownfield declined) | `mkdir /tmp/test-bf3 && cd /tmp/test-bf3 && printf '# Project\n%.0s\n' {1..60} > README.md` | Run, accept or skip express, decline brownfield ("No, start fresh") | Verify: proceeds to interview (or Git Setup) with no brownfield context, no pre-filling of docs. **Cleanup:** `rm -rf /tmp/test-bf3` |
| T3.15 | `/workflows:setup-claude-md` | Any project | Run | CLAUDE.md generated/updated with required sections. Agent dispatched |

### Standalone Commands

| Test | Command | Steps | Expected |
|------|---------|-------|----------|
| T3.21 | `/workflows:fact-check` | Point at a generated file in the project directory | Claims extracted, verified against code/git, corrections applied in-place, verification summary added |

### Freshness Tracking (session-start Step 1)

| Test | Setup | Expected |
|------|-------|----------|
| T3.25a | @imported file with `last_refreshed` = today, `refresh_cadence: quarterly` | No freshness output (ratio ~0, Fresh) |
| T3.25b | @imported file with `last_refreshed` = 100 days ago, `refresh_cadence: quarterly` | "Note: ... approaching refresh date" (ratio ~1.1, Aging) |
| T3.25c | @imported file with `last_refreshed` = 150 days ago, `refresh_cadence: quarterly` | "Warning: ... overdue for refresh" (ratio ~1.67, Stale) |
| T3.25d | @imported file with `last_refreshed` = 200 days ago, `refresh_cadence: quarterly` | "WARNING: ... significantly overdue" (ratio ~2.2, Very stale) |
| T3.25e | @imported file with no YAML frontmatter | No freshness output (skip silently) |
| T3.25f | @imported file with `refresh_cadence: on-change` | No freshness output (skip) |
| T3.25g | No @imported files in CLAUDE.md | No freshness output (silent pass) |

### Decision Trace Tests (requires full inner loop)

| Test | What | Expected |
|------|------|----------|
| T3.26a | Inner loop on architecture issue → ship → check `docs/precedents/` | Precedent file created at `docs/precedents/<ISSUE-ID>.md`, INDEX.md updated, trace matches markdown template (H2 heading, Decision, Category, Confidence, Inputs, Alternatives, Precedent Referenced, Outcome) |
| T3.26b | Inner loop on trivial issue (single-file rename) → ship | No precedent file created (no qualifying decisions emitted) |
| T3.26c | Issue with 5+ decisions (mix of confidence >= 6 and < 6) → ship | Traces with confidence >= 6 present in precedent file (max 3 per task); decisions with confidence < 6 absent from file but visible in checkpoint output |
| T3.26d | Trace with confidence >= 8, category `architecture`, establishes reusable pattern | Flagged for org-level promotion: Linear issue created with `precedent-promotion` label |

---

## Layer 4: End-to-End Flow Tests (~30+ min each)

### T4.1: Inner Loop (full cycle)

**Prerequisites:** Linear project with an open issue, gh authenticated, test repo

1. `/workflows:session-start` → select an issue
2. Observe `brainstorming` activates (if non-trivial) → approve design doc
3. Observe `writing-plans` activates → review plan with tasks → approve
4. Observe `git-worktrees` activates → worktree created with issue ID branch
5. Observe `executing-plans` activates → subagents dispatched per task → TDD enforced
6. Observe `verification-before-completion` runs at checkpoints
7. `/workflows:review` → dynamic agent selection → agents run in parallel → P1s fixed → verdict
8. `/workflows:ship` → PR created → Linear updated → `compound-learnings` runs → `best-practices-audit` runs (if CLAUDE.md changed) → session summary

**Cleanup:** Delete test PR, remove worktree, clean up generated files.

### T4.2: Greenfield Flow

**Prerequisites:** Empty directory, Linear MCP

1. `/workflows:project-start` → complete full interview
2. Verify trait classification and scaffolding:
   - Trait classification shown with confidence levels (High/Medium/Low)
   - `## Project Traits` section in CLAUDE.md with active trait list, autonomy level, and per-trait evidence
   - Trait-conditional docs scaffolded per trait-to-doc mapping (e.g., `docs/engineering-context.md` for `produces-code`)
   - Linear `trait:<name>` labels created for each active trait
   - CLAUDE.md structure: always-include sections (6) + trait-conditional sections + autonomy-conditional sections (Technical Vision only if Autonomy B)
   - `docs/project-plan-v1.md` created, Linear project created
3. `/workflows:post-plan-setup` → refine-plan runs → approve → create-issues runs → approve → setup-claude-md runs → approve
4. Verify: `docs/project-plan-refined.md` exists, Linear issues created with dependencies, CLAUDE.md updated

**Cleanup:** Delete test Linear project and issues.

### T4.3: Scoping Flow

**Prerequisites:** Linear project with existing issues

1. `/workflows:scope` → answer interview questions → themes generated → select items → issues created → prioritization table
2. Verify: Linear issues created with acceptance criteria, relationships set, deferred ideas in memory

**Cleanup:** Delete test issues.

### T4.4: Standalone Debugging

**Prerequisites:** A project with a reproducible bug (or simulate one)

1. Say "I have a bug: [description]"
2. Observe `systematic-debugging` activates
3. Walk through: Phase 1 (reproduce) → Phase 2 (isolate) → Phase 3 (analyze) → Phase 4 (fix)
4. Verify: Regression test written, debugging report generated

---

## Layer 5: Hook Tests (~5 min)

**Note:** PreToolUse/PostToolUse hooks don't fire from plugins due to upstream bug ([#6305](https://github.com/anthropics/claude-code/issues/6305)). These tests verify the hook *definitions* are correct and will work once the bug is fixed. SessionStart is the only hook that fires today.

| Test | Hook | Steps | Expected |
|------|------|-------|----------|
| T5.1 | SessionStart | Start a new session | Environment banner displayed with git/node/gh/npx status |
| T5.2 | Bash security (automated) | Already covered by `scripts/test-hooks.sh` | 37/37 pass |
| T5.3 | Write/Edit security (manual) | Try to write a file containing `sk-proj-AAAAAAAAAAAAAAAAAAA` | Should be blocked (if hooks fire — KNOWN ISSUE if not) |
| T5.4 | PostToolUse linter (manual) | Edit a `.ts` file with a lint error | Auto-linter should run (if hooks fire — KNOWN ISSUE if not) |

---

## Layer 6: Agent Dispatch Tests (~10 min)

| Test | Agent | How to trigger | Expected output |
|------|-------|----------------|-----------------|
| T6.1 | `code-reviewer` | `/workflows:review` or `/workflows:code-review --deep` | P1/P2/P3 findings with file:line references |
| T6.2 | `security-reviewer` | `/workflows:review` or `/workflows:security-audit` | Security findings with Attack/Impact/Fix + Risk Level |
| T6.3 | `typescript-reviewer` | `/workflows:review` | TypeScript/React/Next.js findings |
| T6.4 | `claude-md-generator` | `/workflows:setup-claude-md` | CLAUDE.md generated with required sections |
| T6.5 | `plan-refiner` | `/workflows:post-plan-setup` Phase 1 | Refined plan with agent-ready tasks |
| T6.6 | `issue-creator` | `/workflows:post-plan-setup` Phase 2 | Linear issues created with structured descriptions |
| T6.7 | `post-plan-orchestrator` | `/workflows:post-plan-setup` | Orchestrates phases 1–3 with review gates |
| T6.8 | `performance-reviewer` | `/workflows:review` (always selected) | Performance findings with complexity/impact analysis |
| T6.9 | `python-reviewer` | `/workflows:review` (when `pyproject.toml` exists) | Python/FastAPI findings with type/async analysis |
| T6.10 | `data-reviewer` | `/workflows:review` (when `prisma/` or `migrations/` exists) | Migration safety and query pattern findings |
| T6.11 | `architecture-reviewer` | `/workflows:review` (when diff touches 5+ dirs, CLAUDE.md enables, or `comprehensive` depth) | Coupling, SOLID, boundary violation findings |
| T6.12 | `accessibility-reviewer` | `/workflows:review` (when CLAUDE.md enables or `comprehensive` depth) | WCAG compliance findings with success criterion references |
| T6.13 | Confidence filtering | `/workflows:review` on a branch with changes | Each finding has `Confidence: N/10`, Step 5 narration shows filtered count, low-confidence P2/P3s absent from report but counted, borderline P1s show "Needs Human Review", HTML report shows confidence pills, "show all" shows all findings |
| T6.14 | Depth modes | `/workflows:review fast`, `/workflows:review comprehensive` | `fast`: only 3 Tier 1 agents selected, Tier 2/3 skipped. `comprehensive`: all agents selected regardless of stack or CLAUDE.md overrides, narration shows override bypass. Default (no keyword): `thorough` behavior unchanged. Combined flags work: `fast skip simplify skip validation show all`. Whole-word matching: "fast-path" does not trigger `fast` mode |
| T6.15 | `test-quality-reviewer` | `/workflows:review` (when diff includes test files or CLAUDE.md enables) | Test quality findings: coverage gaps, behavior vs implementation, flakiness risk, edge cases, test structure |
| T6.16 | Diff triage — trivial | `/workflows:review` on a branch with only comment/doc changes (< 50 lines) | Step 2 narrates "Trivial diff detected", Steps 3-7 skipped, abbreviated visual report generated, verdict is "Trivial change — no review agents needed" |
| T6.17 | Diff triage — non-trivial | `/workflows:review` on a branch with logic changes | Step 2 narrates "Non-trivial diff", proceeds to Step 3 (simplify pass) and full review pipeline |
| T6.18 | Diff triage — skip flag | `/workflows:review skip triage` | Step 2 narrates "Diff triage skipped (user request)", proceeds directly to Step 3 |
| T6.19 | Validation — P1 confirmed | `/workflows:review` on a branch with a real bug | Step 6 dispatches Opus subagent for P1, verdict is CONFIRMED, finding remains in report |
| T6.20 | Validation — P1 downgraded | `/workflows:review` on a branch with a borderline P1 | Step 6 Opus subagent returns DOWNGRADED, finding reclassified to P2/P3 with "[Downgraded from P1]" note |
| T6.21 | Validation — finding dismissed | `/workflows:review` on a branch with false-positive-prone patterns | Step 6 subagent returns DISMISSED, finding removed from main report and added to "Dismissed by validation" appendix |
| T6.22 | Validation cap | `/workflows:review` on a branch with 25+ findings | Step 6 caps at 20 subagents, remaining P3s batched into single Sonnet subagent, all P1s validated individually |
| T6.23 | Validation — skip flag | `/workflows:review skip validation` | Step 6 narrates "Validation skipped (user request)", proceeds directly to Step 7 |
| T6.24 | Validation — fast mode P2/P3 skip | `/workflows:review fast` with P2/P3 findings but no P1s | Step 6 narrates "Validation skipped (fast mode, no P1s)", proceeds to Step 7 without dispatching subagents |
| T6.25 | Validation — fast mode P1 only | `/workflows:review fast` with P1 findings | Step 6 narrates "Validating P1s only (fast mode)", dispatches Opus subagents for P1s only, skips P2/P3 verification |
| T6.26 | `cdr-compliance-reviewer` | `/workflows:review` (when project CLAUDE.md has `## Company Context` with `handbook-library`, CLAUDE.md enables, or `comprehensive` depth) | CDR compliance findings with CDR ID references (e.g., CDR-001), Why/Fix fields, compliance verdict (`Compliant` / `Violation Found` / `Review Needed`), CDRs Checked count. When Context7 unavailable: graceful skip with `CDR Compliance: N/A (CDR INDEX unavailable)`. When no handbook-library: skip with `CDR Compliance: N/A (no handbook configured)`. |

---

## Coverage Summary

| Component | Count | Covered by |
|-----------|-------|------------|
| Commands | 21 | T1.1, T3.1–T3.25g |
| Skills (Inner Loop) | 8 | T2.1–T2.6, T4.1 |
| Skills (Design) | 3 | T2.7–T2.9 |
| Skills (Quality/Ref) | 3 | T2.10–T2.12 |
| Skills (Post-plan) | 4 | T4.2 (refine-plan, create-issues, setup-claude-md, post-plan-setup) |
| Skills (Browser) | 1 | Not directly tested (requires browser MCP) |
| Agents | 26 | T6.1–T6.26 |
| Hooks | 4 types | T5.1–T5.4, T0.2 |
| Scripts | 5 + 2 | T0.1–T0.4, T0.6 + Tier 2 (test-behavioral.sh) + Tier 3 (score-behavioral.sh) |
| Scenarios | 60 + 12 FP + 6 EM | T0.6 |
| Behavioral tests | 10 seed cases | Tier 2 (B01–B10) |

---

## Results Template

```
Date:       ____-__-__
Version:    ____
Tester:     ____
Environment: macOS / Linux / WSL

Layer 0 (Automated):  __/6
Tier 2 (Behavioral):  __/10
Tier 3 (Scoring):     __/6 (cases with rubrics)
Layer 1 (Loading):    __/3
Layer 2 (Skills):     __/12
Layer 3 (Commands):   __/41
Layer 4 (E2E):        __/4
Layer 5 (Hooks):      __/4
Layer 6 (Agents):     __/26

Total:  __/112
Notes:  ____
```
