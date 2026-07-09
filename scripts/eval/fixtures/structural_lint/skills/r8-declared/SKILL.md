---
name: r8-declared
description: Fetches a Linear issue and renders it. Use when reviewing an issue's context.
allowed-tools: mcp__plugin_workflows_linear-server__get_issue, Read
user-invocable: true
---

# R8 declared allowed-tools

Call `mcp__plugin_workflows_linear-server__get_issue` to load the issue, then render it.
This skill invokes an MCP tool AND declares a least-privilege allowed-tools — compliant.
