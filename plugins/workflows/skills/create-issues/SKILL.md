---
name: create-issues
description: Creates Linear issues from a refined project plan. Validates issues were created correctly with sufficient context for agent execution. Use after /refine-plan.
user-invocable: false
allowed-tools: mcp__plugin_workflows_sequential-thinking__sequentialthinking, mcp__plugin_workflows_linear-server__*, Read, Write, Glob, Grep
agent: issue-creator
context: fork
---

## Instructions

You are creating Linear issues from a refined project plan.

### Input
- The refined plan file path is passed as $ARGUMENTS
- If no argument provided, look for `docs/project-plan-refined.md`

### Process

#### Step 0: Linear Project Setup

Before creating any issues, you must determine the target team and project.

1. **Detect team**:
   - Call `list_teams` to get all teams in the workspace
   - If exactly 1 team exists, auto-select it and inform the user:
     "I'll create issues in team '[name]'."
   - If multiple teams exist, ask the user to pick one using
     AskUserQuestion with the team names as options
   - If 0 teams exist, stop and tell the user to create a team
     in Linear first

2. **Find or create project**:
   - Extract the project name from the plan file heading (the
     `# [Project Name]` at the top of the refined plan)
   - Search for existing projects in the selected team using
     `list_projects` with that name as a query
   - **Exact match found**: Ask the user — "I found an existing
     project called '[name]'. Should I add issues there, or
     create a new project?"
   - **Multiple partial matches**: Show the matches and ask the
     user to pick one or create a new project
   - **No match found**: Tell the user — "I'll create a new
     Linear project called '[name]'. Want a different name?"
     Wait for confirmation, then create the project using
     `create_project`

3. **Confirm and proceed**: Summarize the setup —
   "Creating issues in team '[team]', project '[project]'."
   Then continue to issue creation below.

#### Step 1: Create Issues

1. **Read the refined plan** and parse all tasks

2. **For each task, create a Linear issue** with:
   - **Team**: The team selected in Step 0
   - **Project**: The project confirmed/created in Step 0
   - **Title**: From the task title
   - **Description**: Combine the Context, Steps, and Validation
     sections into a well-structured issue body. Format it so that
     an AI agent receiving this issue has everything it needs:
     - "## Context" — background and architectural decisions
     - "## Implementation Steps" — the numbered steps
     - "## Validation Criteria" — how to verify completion
     - "## Dependencies" — links to dependent issues (add after
       all issues are created)
   - **Labels**: Add complexity label (S/M/L)
   - **Priority**: Derive from dependency order (earlier = higher)

3. **After all issues are created**:
   - Go back and update dependency references to use actual Linear
     issue IDs/links
   - Set parent/sub-issue relationships where appropriate

4. **Update the refined plan file**:
   - Add the Linear issue ID next to each task title
   - Add a "Linear Project" link at the top of the document

### Output
- Linear issues created and linked
- Updated `docs/project-plan-refined.md` with issue IDs
- Write a summary to `docs/linear-issues-created.md` containing:
  - Total issues created
  - Issue ID → Task title mapping
  - Any issues that needed special handling

### Validation Criteria
Reference `_shared/validation-pattern.md` and apply it.
Specific criteria for this skill:
- [ ] Every task in the refined plan has a corresponding Linear issue
- [ ] Each issue's description contains Context, Implementation Steps,
      and Validation Criteria sections
- [ ] Read each issue back from Linear via MCP and verify the content
      matches what was intended
- [ ] Dependencies are correctly linked between issues
- [ ] An agent picking up any single issue would have enough context
      to: understand the task, complete the work, and validate the result
- [ ] The refined plan file has been updated with issue IDs
