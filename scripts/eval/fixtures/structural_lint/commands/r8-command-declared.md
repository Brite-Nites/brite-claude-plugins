---
description: Fetches a Linear issue and renders it. Use when reviewing an issue's context.
allowed-tools: mcp__plugin_workflows_linear-server__get_issue, Read
---

# R8 command declared

Call `mcp__plugin_workflows_linear-server__get_issue` to load the issue, then render it.
This command invokes an MCP tool AND declares a least-privilege `allowed-tools`, which is
the compliant shape — R8 must not fire.
