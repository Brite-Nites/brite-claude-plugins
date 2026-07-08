---
name: r8-block-array
description: Fetches a Linear issue and renders it. Use when reviewing an issue's context.
user-invocable: true
allowed-tools:
  - mcp__plugin_workflows_linear-server__get_issue
  - Read
---

# R8 block-array allowed-tools

Call `mcp__plugin_workflows_linear-server__get_issue` to load the issue, then render it.
This skill declares allowed-tools as a YAML block sequence (non-canonical, but a genuine
declaration) — R8 must NOT fire, since least-privilege tools ARE declared.
