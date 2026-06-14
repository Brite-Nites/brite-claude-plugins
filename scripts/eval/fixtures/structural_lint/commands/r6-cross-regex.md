---
description: Fixture proving R6 falls through an exempted ABS placeholder to a real WIN path. Use only in the structural-lint self-test.
allowed-tools: Read
---

# R6 cross-regex fall-through (must-flag)

An exempted ABS placeholder must not stop the scan before the WIN regex sees a real
path later on the same line (the documented ABS-before-WIN ordering):

write paths relative (no `/Users/...`) — never `C:\Users\holden\config.json`
