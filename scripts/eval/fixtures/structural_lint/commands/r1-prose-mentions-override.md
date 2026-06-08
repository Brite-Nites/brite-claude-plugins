---
description: Files a ticket in Linear from the current context. Use when capturing a bug.
allowed-tools: mcp__plugin_workflows_linear-server__create_issue, Read
---

# File a ticket

Creates a Linear issue. To suppress a false positive you would add a
`lint:not-side-effecting <reason>` comment — but this command has no such comment
marker (only this prose mention), so R1 must still fire as a gate.
