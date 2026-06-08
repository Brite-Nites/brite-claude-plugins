---
description: Creates a Linear issue from the current context. Use when filing a bug from a session.
allowed-tools: mcp__plugin_workflows_linear-server__save_issue, Read
---

# File a ticket

This command runs `gh pr create` and calls the Linear save tool to file an issue.
It mutates external state, so the model must not fire it unprompted.
