---
description: Fixture proving R6 exempts structurally-fake placeholder usernames. Use only in the structural-lint self-test.
allowed-tools: Read
---

# R6 placeholder paths (must-pass)

These are prohibition-prose mentions, not hardcoded paths — each placeholder
username is structurally impossible as a real account name, so R6 must stay silent.

- dot-ellipsis: `/Users/...`
- unicode ellipsis: `/Users/…`
- angle placeholder: `/Users/<username>/config.json`
- shell var: `/Users/$USER/config.json`
- prefix generality: `/home/...`
- windows placeholder: `C:\...`
- the live false-positive shape, verbatim: must be relative (no `/Users/...`, no `~/...`, no `..` segments)
