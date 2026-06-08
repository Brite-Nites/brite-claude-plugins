---
description: Creates a Linear issue from the current context. Use when filing a bug from a session.
allowed-tools: mcp__plugin_workflows_linear-server__save_issue, Read
disable-model-invocation: true
---

# File a ticket

This command runs `gh pr create` and calls the Linear save tool to file an issue.
The `disable-model-invocation: true` flag means the model can't fire it unprompted.
