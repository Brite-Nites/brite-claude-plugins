---
description: Standardized bug reporting template that creates Linear issues with reproduction steps, severity, and environment details
---

# Bug Report

You are creating a standardized bug report and filing it as a Linear issue. Your job is to gather structured information from the developer, check for duplicates, and create a well-formatted issue with the `Bug` label.

`$ARGUMENTS` may contain a short bug title or description. If provided, use it as the starting point and skip asking for the title.

## Step 0: Verify Prerequisites

Confirm Linear MCP is reachable:

1. **Linear MCP** — Call `list_projects` (limit 1). This confirms auth and connectivity.

If it fails:
- Stop immediately: "Cannot reach Linear MCP. Run `/workflows:smoke-test` to diagnose."
- Do NOT proceed.

## Step 1: Gather Bug Details

Collect the following information from the developer. Use AskUserQuestion for structured inputs and direct conversation for free-form fields.

### 1a. Title

- If `$ARGUMENTS` contains a title/description, use it. Show the title on its own line and ask: "I'll use this as the bug title — is that right?" If the developer says no or suggests a change, ask for the preferred title.
- If `$ARGUMENTS` is empty, ask: "What's the bug? Give a short title."

### 1b. Description & Reproduction Steps

Ask the developer to describe the bug. Prompt for:

1. **What happened?** (actual behavior)
2. **What should have happened?** (expected behavior)
3. **Steps to reproduce** (numbered, specific)

If the developer provides a single paragraph, help structure it into these three sections.

### 1c. Severity Classification

Ask the developer to classify severity using AskUserQuestion:

| Severity | Description | Linear Priority |
|----------|-------------|-----------------|
| Critical | Service down, data loss, security breach — blocks all users | Urgent (1) |
| High | Major feature broken — significant user impact, no workaround | High (2) |
| Medium | Feature partially broken — workaround exists | Normal (3) |
| Low | Minor issue — cosmetic, edge case, or minor inconvenience | Low (4) |

### 1d. Additional Context (optional)

Ask: "Any additional context? (logs, error messages, screenshots, related issues — or skip)"

- If the developer provides log output or error messages, scan for potential secrets before including (patterns: `Bearer `, `password=`, `token=`, `sk-`, `AKIA`, `postgres://`, `ghp_`). Redact any matches with `[REDACTED]` and warn the developer: "I redacted a potential secret from your log output. Verify before submitting." Include the sanitized output in a code block in the issue description.
- If they mention related Linear issues (e.g., "BRI-123"), note them for the `relatedTo` field.
- Screenshots: note in the description that screenshots are available but were not attached. (File attachment support is out of scope for this command.)

## Step 2: Auto-detect Environment

Automatically gather environment details by running these checks. Present the results to the developer for confirmation.

1. **OS**: Run `sw_vers -productName -productVersion 2>/dev/null || uname -sr` to detect the OS
2. **Node.js version**: Run `node -v` (if available)
3. **Git branch**: Run `git branch --show-current`
4. **Project name**: Read from `package.json` `name` field, `pyproject.toml` `[project].name`, or fall back to the directory name
5. **App version**: Read from `package.json` `version` field or `pyproject.toml` `[project].version` (if available)

Present a summary: "Here's what I detected — correct anything that's wrong:"

```
- OS: [detected]
- Node: [detected or N/A]
- Branch: [detected]
- Project: [name] v[version]
```

If the bug is browser-related, ask: "Which browser and version? (e.g., Chrome 122, Safari 18)"

## Step 3: Check for Duplicates

Before creating the issue, search Linear for potential duplicates:

1. **Search by title keywords** — Extract 2-4 significant words from the bug title. Use `list_issues` with a `query` parameter containing these keywords. If a team is already known from project context, scope the search to that team; otherwise search across all teams. Limit to 10 results.
2. **Filter to open issues** — Only show issues that are not completed or cancelled.
3. **Present matches** (if any):

```
### Possible Duplicates Found

| # | ID | Title | Status | Assignee |
|---|------|-------|--------|----------|
| 1 | BRI-XX | Similar issue title | In Progress | Name |
| ...
```

4. **Ask the developer** using AskUserQuestion:
   - "Is this a duplicate of any of these issues?" with options for each match plus "None — create new issue"
   - If they select a duplicate: link to it, suggest adding a comment to the existing issue instead, and ask if they want to proceed. If they choose to comment, use `create_comment` on the existing issue with the new reproduction info, then display a confirmation:
     ```
     Comment added to [ISSUE-ID]: [title]
     Link: [issue URL]

     The reproduction details have been added to the existing issue.
     ```
     Then stop — do not proceed to issue creation.
   - If no matches or "None": proceed to Step 4.

If the search returns no results, skip the duplicate prompt and proceed directly.

## Step 4: Select Team & Project

Determine where to file the issue:

1. **Team** — If the project's CLAUDE.md or context makes the team obvious, suggest it. Otherwise, list available teams using `list_teams` and ask.
2. **Project** — Optional. If the developer is working within a known project context (e.g., "Brite Plugin Marketplace"), suggest it. Otherwise, ask if they want to assign it to a project or leave it unassigned.

## Step 5: Review Draft

Before creating, show the developer a preview of the issue that will be created:

```
## Bug Report Preview

**Title**: [title]
**Team**: [team name]
**Project**: [project or "None"]
**Priority**: [severity → priority mapping]
**Labels**: Bug

---

### Description

**Actual behavior:**
[what happened]

**Expected behavior:**
[what should have happened]

### Reproduction Steps

1. [step 1]
2. [step 2]
3. [step 3]

### Environment

| Detail | Value |
|--------|-------|
| OS | [os] |
| Node.js | [version] |
| Browser | [if applicable] |
| Branch | [branch] |
| Project | [name] v[version] |

### Additional Context

[logs, error messages, or "None"]
```

Ask for confirmation: "Create this issue in Linear?" with options:
- "Create it" — proceed to Step 6
- "Edit first" — ask what to change, update, and re-preview

## Step 6: Create Linear Issue

Create the issue using `save_issue` with:

- `title`: The bug title
- `team`: Selected team name
- `project`: Selected project (if any)
- `priority`: Mapped from severity (Critical→1, High→2, Medium→3, Low→4)
- `labels`: `["Bug"]`
- `description`: The full formatted markdown description (actual/expected, repro steps, environment table, additional context)
- `relatedTo`: Any related issue IDs mentioned by the developer

## Step 7: Confirmation

After the issue is created, display:

```
Bug report filed.

**[ISSUE-ID]**: [title]
**Link**: [issue URL]
**Priority**: [priority name]
**Team**: [team name]

The issue has the "Bug" label and is ready for triage.
```

If related issues were linked, mention: "Linked to: [list of related issue IDs]"

## Rules

- Never create an issue without the developer reviewing and confirming the draft first.
- Never skip the duplicate check — even if it finds no matches, the search must run.
- Map severity to Linear priority consistently: Critical→Urgent(1), High→High(2), Medium→Normal(3), Low→Low(4).
- Always apply the "Bug" label. The developer can add additional labels if they want.
- Structure free-form input — if the developer gives a wall of text, help break it into actual/expected/repro steps.
- Include auto-detected environment info in every bug report. Let the developer correct it, don't skip it.
- If the developer wants to add a comment to an existing duplicate instead of creating a new issue, respect that and use `create_comment`.
- Keep the tone professional and efficient. This is a workflow tool, not a conversation.
