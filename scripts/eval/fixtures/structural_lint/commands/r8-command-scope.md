---
description: Fetches a Linear issue and renders it. Use when reviewing an issue's context.
---

# R8 command-scope proof

Call `mcp__plugin_workflows_linear-server__get_issue` to load the issue, then render it.
This COMMAND invokes an MCP tool without allowed-tools, but R8 is skill-only — it must
NOT fire here (the diff-gate is commands-only and never sees skills; R8 is full-surface).
