---
description: Fetches a Linear issue and renders it. Use when reviewing an issue's context.
---

# R8 command-surface proof

Call `mcp__plugin_workflows_linear-server__get_issue` to load the issue, then render it.
This COMMAND invokes an MCP tool and declares no allowed-tools, so R8 MUST fire here —
the mandate covers commands as well as skills (BC-16865). The finding's message must name
the `command` surface, not "skill".
