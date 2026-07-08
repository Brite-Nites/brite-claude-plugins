---
name: r8-empty-override
description: Fetches a Linear issue and renders it. Use when reviewing an issue's context.
user-invocable: true
---

<!-- lint:no-mcp-invocation -->

# R8 empty override

Call `mcp__plugin_workflows_linear-server__get_issue` to load the issue, then render it.
The override marker above carries no reason, so it is a silent-bypass attempt and does
NOT suppress the gate — R8 still fires, plus an advisory that the marker is ignored.
