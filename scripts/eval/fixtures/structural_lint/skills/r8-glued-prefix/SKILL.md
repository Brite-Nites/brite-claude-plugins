---
name: r8-glued-prefix
description: Explains a naming scheme. Use when documenting identifier conventions.
user-invocable: false
---

# R8 glued-prefix (no invocation)

This reference skill mentions the identifier `dumpmcp__foo__bar` and a URL like
`https://example.com/docs/mcp__foo__bar`, where an `mcp__…` shape is glued into a larger
token. Neither is a tool invocation, so R8 must NOT fire (the left-boundary lookbehind).
