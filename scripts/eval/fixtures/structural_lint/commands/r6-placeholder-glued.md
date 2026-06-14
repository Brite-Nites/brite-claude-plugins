---
description: Fixture proving a real path with a fake-looking ellipsis lead still flags. Use only in the structural-lint self-test.
allowed-tools: Read
---

# R6 placeholder-glued (must-flag)

An ellipsis exemption must be a complete token — a real username glued behind it
is not a placeholder and must still flag:

Reads /Users/...holden/secrets.txt directly.
