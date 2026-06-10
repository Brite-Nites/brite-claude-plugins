---
description: Audit and refactor a project's CLAUDE.md against best practices
---

<!-- eval-waiver: The artifact is a refactored or generated CLAUDE.md authored by the claude-md-generator agent from project structure and a best-practices reference, applied to local disk on approval; the generated prose has no single correct form to assert against. -->

# Setup CLAUDE.md

You are auditing and improving the project's CLAUDE.md file against Claude Code best practices. This command can be used at project setup or anytime to ensure the CLAUDE.md stays optimal.

## Process

### Step 1: Check Current State

1. Check if a `CLAUDE.md` exists in the current project root
2. If it exists, read it and note its current sections and content
3. If it doesn't exist, note that you'll be generating one from scratch

### Step 2: Load Best Practices Reference

Read the best practices reference file:

```
plugins/workflows/skills/setup-claude-md/claude-code-best-practices.md
```

This contains the full reference for what a great CLAUDE.md includes.

### Step 3: Run Analysis

Launch the `workflows:claude-md-generator` agent via the Task tool to:

1. Analyze the current project structure, package.json, tech stack, build commands
2. Compare existing CLAUDE.md (if any) against the best practices reference
3. Generate an improved CLAUDE.md with all required sections:
   - Project Overview
   - Bash Commands (build, test, lint, typecheck, dev)
   - Code Style
   - Architecture
   - Workflow Rules
   - Testing Conventions
   - Environment Setup
   - Common Pitfalls
   - Verification Checklist

### Step 4: Present Changes

If a CLAUDE.md already existed:
- Show a clear diff of what changed and why
- Highlight added sections, removed filler, and corrected commands

If creating from scratch:
- Present the full generated file
- Highlight key sections the developer should review

### Step 5: Apply with Approval

Ask the developer: "Apply these changes to CLAUDE.md?"

- If approved, write the file
- If the developer wants modifications, apply them first
- Verify the final file by reading it back

The user specified: $ARGUMENTS
