---
description: Fixture proving R6 rescans past an exempted placeholder to a real path on the same line. Use only in the structural-lint self-test.
allowed-tools: Read
---

# R6 placeholder-then-real (must-flag)

A placeholder must not give the rest of the line a free pass:

write paths relative (no `/Users/...`) — never `/Users/holden/secrets.txt`
