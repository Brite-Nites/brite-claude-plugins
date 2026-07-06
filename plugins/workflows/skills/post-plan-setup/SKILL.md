---
name: post-plan-setup
description: Runs the full post-plan workflow. Refine plan, create Linear issues, setup CLAUDE.md. Use after /plan-project produces a v1 plan. Pauses between phases for optional review.
user-invocable: true
allowed-tools: mcp__plugin_workflows_sequential-thinking__sequentialthinking, mcp__plugin_workflows_linear-server__*, Read, Write, Bash(find:*), Bash(cat:*), Bash(ls:*), Glob, Grep
agent: post-plan-orchestrator
---

## Instructions

You are orchestrating the full post-plan setup workflow. This runs
three phases in sequence, pausing between each for human review.

### Input
- The v1 plan file path is passed as $ARGUMENTS
- If no argument provided, look for the most recent plan file in the
  project root or docs/ directory

### Phase 1: Refine Plan
1. Invoke the `/refine-plan` skill with the v1 plan
2. Wait for completion
3. Present a summary of the refined plan to the user:
   - Total number of tasks created
   - Task dependency overview
   - Any flags or ambiguities found
4. **Ask the user**: "The refined plan is ready at
   `docs/project-plan-refined.md`. Would you like to review and
   make changes before I create Linear issues, or should I continue?"
5. If the user wants changes, apply them and re-validate
6. If the user approves (or says continue), proceed to Phase 2

### Phase 2: Create Linear Issues
1. Invoke the `/create-issues` skill with the refined plan
2. Wait for completion
3. Present a summary to the user:
   - Number of issues created
   - Link to the Linear project/view
   - Any issues that needed special handling
4. **Ask the user**: "All Linear issues are created. Would you like
   to review them before I set up CLAUDE.md, or should I continue?"
5. If the user wants changes, apply them via the Linear MCP
6. If the user approves, proceed to Phase 3

### Phase 3: Setup CLAUDE.md
1. Invoke the `/setup-claude-md` skill
2. Wait for completion
3. Present the generated CLAUDE.md to the user for review
4. **Ask the user**: "CLAUDE.md is ready. Would you like any changes?"
5. Apply any requested changes

### Completion
Once all three phases are done, present a final summary:
- Refined plan location and task count
- Linear issues created with project link
- CLAUDE.md location and section overview
- Suggested next step: "Pick up Task 1 from the refined plan or
  assign issues to your team"

### Error Handling
- If any phase fails validation after retries, stop the workflow
- Present what succeeded and what failed
- Suggest the user run the failed skill individually with
  `/refine-plan`, `/create-issues`, or `/setup-claude-md` after
  fixing the issue
