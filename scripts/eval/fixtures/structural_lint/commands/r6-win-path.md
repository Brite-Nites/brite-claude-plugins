---
description: Fixture proving R6 flags a real hardcoded Windows drive-letter path. Use only in the structural-lint self-test.
allowed-tools: Read
---

# R6 Windows path (must-flag)

Reads `C:\Users\holden\config.json` directly instead of `${CLAUDE_PLUGIN_ROOT}\config.json`.
