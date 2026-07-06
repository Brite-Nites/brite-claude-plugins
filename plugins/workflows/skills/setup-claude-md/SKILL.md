---
name: setup-claude-md
description: Generates a best-practices CLAUDE.md file for the project. Analyzes the codebase and applies Claude Code best practices for optimal agent performance. Use at project setup or after /create-issues.
user-invocable: false
allowed-tools: mcp__plugin_workflows_sequential-thinking__sequentialthinking, Read, Write, Bash(find:*), Bash(cat:*), Bash(ls:*), Glob, Grep
agent: claude-md-generator
context: fork
---

## Instructions

You are generating a comprehensive CLAUDE.md file that follows
Claude Code best practices.

### Input
- Read `.claude/skills/setup-claude-md/claude-code-best-practices.md`
  as your reference for what a great CLAUDE.md contains
- Analyze the current project structure, package.json / pyproject.toml /
  Cargo.toml / etc. for build commands, tech stack, etc.
- If `docs/project-plan-refined.md` exists, reference it for project
  context and architecture decisions

### Process
1. **Analyze the project** (like /init would):
   - Tech stack and language
   - Build, test, lint, and format commands
   - Project structure and key directories
   - Existing CI/CD configuration
   - Environment setup requirements

2. **Apply best practices from reference file** to produce a CLAUDE.md
   that includes all of the following sections:

   **Required Sections:**
   - **Project Overview**: 2-3 sentences on what this project is
   - **Bash Commands**: All build, test, lint, typecheck, and dev
     server commands. Include single-test commands for performance.
   - **Code Style**: Language-specific conventions (imports, naming,
     module system, formatting rules)
   - **Architecture**: Key patterns, state management, data flow,
     important directories and what they contain
   - **Workflow Rules**: Branch naming, commit conventions, PR process,
     CI requirements
   - **Testing Conventions**: Test framework, file naming, how to run
     individual tests, coverage expectations
   - **Environment Setup**: Required env vars, secrets handling,
     local dev dependencies
   - **Common Pitfalls**: Known gotchas, things that break easily,
     unexpected behaviors specific to this project
   - **Verification Checklist**: What to run before considering any
     task complete (typecheck, lint, test, build)

3. **Do NOT include**:
   - Generic advice that isn't specific to the project
   - Verbose explanations — keep entries concise and actionable
   - Anything that duplicates what's in other config files

### Output
- Write to `CLAUDE.md` in the project root
- If a CLAUDE.md already exists, read it first and merge
  (preserve any custom content, update/add missing sections)

### Validation Criteria
Reference `_shared/validation-pattern.md` and apply it.
Specific criteria for this skill:
- [ ] All required sections are present
- [ ] Bash commands are correct (test at least the build and lint
      commands by running them)
- [ ] Code style section matches what's actually in the codebase
      (check a few real files)
- [ ] No generic filler — every line is specific to this project
- [ ] File is concise (aim for under 100 lines; agents perform
      worse with bloated CLAUDE.md files)
