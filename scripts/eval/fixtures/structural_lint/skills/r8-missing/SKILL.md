---
name: r8-missing
description: Fetches a Linear issue and renders it. Use when reviewing an issue's context.
user-invocable: true
---

# R8 missing allowed-tools

Call `mcp__plugin_workflows_linear-server__get_issue` to load the issue, then render it.
This skill invokes an MCP tool but declares no allowed-tools — the R8 gap.
