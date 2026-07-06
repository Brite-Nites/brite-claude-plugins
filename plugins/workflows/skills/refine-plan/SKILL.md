---
name: refine-plan
description: Refines a v1 project plan into agent-ready tasks with clear context, implementation steps, and validation criteria. Use after /plan-project has produced a v1 plan.
user-invocable: false
allowed-tools: mcp__plugin_workflows_sequential-thinking__sequentialthinking, Read, Write, Glob, Grep
agent: plan-refiner
context: fork
---

## Instructions

You are refining a v1 project plan into agent-ready tasks.

### Input
- Read the v1 plan. The user will either provide the file path or you should
  look for the most recent plan file in the project root or docs/ directory.

### Process
1. **Analyze the plan** using sequential-thinking MCP:
   - Identify all distinct pieces of work
   - Determine dependencies between them
   - Identify the optimal execution order
   - Flag any ambiguities or gaps in the v1 plan

2. **For each task, produce**:
   - **Title**: Clear, action-oriented (e.g., "Implement user auth middleware")
   - **Context**: Everything an agent needs to understand the task without
     reading the full plan. Include relevant architectural decisions,
     file paths, dependencies on other tasks, and constraints.
   - **Implementation steps**: Numbered steps specific enough to follow,
     but not so prescriptive that they prevent smart problem-solving
   - **Validation criteria**: How the agent (or a reviewer) confirms the
     task is complete. Should include at minimum:
     - What to test / run
     - Expected output or behavior
     - Edge cases to verify
   - **Estimated complexity**: S / M / L
   - **Dependencies**: List of task IDs this depends on

3. **Add a "Task 0"** at the top of the plan:
   - Title: "Generate Linear issues and update CLAUDE.md"
   - Description: Instructions to run `/create-issues` followed by
     `/setup-claude-md`
   - This ensures the first thing an engineer does is set up the
     project infrastructure

### Output
- Write the refined plan to `docs/project-plan-refined.md`
- Use a consistent markdown structure (template below)

### Output Template

```
# [Project Name] — Refined Plan

## Summary
[1-2 sentence summary of the project]

## Task Dependency Graph
[Mermaid diagram showing task dependencies]

## Tasks

### Task 0: Generate Linear Issues and Update CLAUDE.md
- **Context**: [...]
- **Steps**: Run `/create-issues docs/project-plan-refined.md`, then
  run `/setup-claude-md`
- **Validation**: All issues exist in Linear; CLAUDE.md passes best
  practices checklist

### Task 1: [Title]
- **Context**: [...]
- **Steps**: [...]
- **Validation**: [...]
- **Complexity**: [S/M/L]
- **Dependencies**: [None | Task IDs]

[...repeat for all tasks]
```

### Validation Criteria
Reference `_shared/validation-pattern.md` and apply it.
Specific criteria for this skill:
- [ ] Every task has all required fields filled in (title, context,
      steps, validation, complexity, dependencies)
- [ ] An agent reading any single task would have enough context to
      start working without asking clarifying questions
- [ ] Dependencies form a valid DAG (no circular dependencies)
- [ ] Task 0 is present and correctly references the next skills
- [ ] The refined plan covers all work items from the v1 plan
      (nothing dropped)
