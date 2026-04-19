---
description: Guided Email Bison MCP setup. Detects current registration state and walks the developer through getting tokens from Bitwarden, adding env-var exports to their shell profile, and registering the two EB MCP servers at user level. Use when EB MCP tools are missing, a skill errors with "tool not found" for an emailbison-* tool, or on first-time Brite dev onboarding.
allowed-tools: Bash, Read, AskUserQuestion
---

# /marketing:setup-email-bison

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered checkpoint so the user explicitly acknowledges each step before moving on. If they answer anything other than the "proceed" option, halt and help with their blocker before re-asking.

Context for why this is user-level rather than plugin-scoped: `plugins/marketing/tools/integrations/email-bison.md` § Known Claude Code limitation.

---

## Phase 1 — Detect current state

Run:

```bash
claude mcp list 2>&1 | grep -E "emailbison-b2b|emailbison-personal" || echo "NONE_REGISTERED"
```

Interpret the output:

- Two lines, both showing `✓ Connected` → print `✓ Email Bison is already set up on this machine.` and **exit**. Do not continue.
- `NONE_REGISTERED` → proceed to Phase 2 (full setup).
- One entry present or either line shows `✗ Failed to connect` / `✗ Needs authentication` → proceed to Phase 2; mention at the start of Phase 2 that only the missing/broken side needs work, but walk through the steps for completeness.

## Phase 2 — Bitwarden access

Tell the user (paraphrase fine):

> You'll need your Email Bison tokens. They live in the Engineering collection of Bitwarden, in an item called **Email Bison MCP — API tokens**. Open your Bitwarden client and find that item — its Notes field has two `export` lines ready to copy.

Ask via `AskUserQuestion`:
- Question: "Bitwarden item open and tokens visible?"
- Options: "Yes, I see it" / "I don't have access"

If "I don't have access" → halt. Tell the user: *"Request Engineering-collection access from your Brite admin or IT, then re-run `/marketing:setup-email-bison`."* Exit.

## Phase 3 — Shell profile

Tell the user:

> Copy both `export` lines from the Bitwarden Notes field. Paste them into `~/.zshrc` (or `~/.bashrc` if you use bash). Save the file. Then either run `source ~/.zshrc` in a terminal *outside* Claude Code, or open a fresh terminal.

Ask:
- Question: "Exports pasted and shell re-sourced?"
- Options: "Yes" / "Not yet"

Wait for "Yes" before proceeding.

## Phase 4 — Register the two MCP entries

Tell the user:

> Open the repo-root `.mcp.json` file (at the top of `britenites-claude-plugins` — it's already in `.gitignore`, so raw values never get committed). Add these two entries to the `mcpServers` object (keep any existing keys like `salesforce`):

Then print this fenced JSON block:

```json
"emailbison-b2b": {
  "type": "remote",
  "url": "https://mcp.emailbison.com/mcp",
  "headers": {
    "Authorization": "Bearer ${EMAILBISON_B2B_TOKEN}",
    "Instance-URL": "https://send.outbase.so"
  }
},
"emailbison-personal": {
  "type": "remote",
  "url": "https://mcp.emailbison.com/mcp",
  "headers": {
    "Authorization": "Bearer ${EMAILBISON_PERSONAL_TOKEN}",
    "Instance-URL": "https://personal.outbase.so"
  }
}
```

Ask:
- Question: "Entries added and file saved?"
- Options: "Yes" / "I can't find the file"

If "I can't find the file" → get the repo root via `git rev-parse --show-toplevel` and tell the user the exact path is `<root>/.mcp.json`. Offer to open it: `open -t <path>`. Then re-ask.

## Phase 5 — Reload plugins

Tell the user:

> Run `/reload-plugins` in Claude Code. If you just updated your shell profile, a full Claude Code restart is more reliable than `/reload-plugins` alone — the plugin loader needs to inherit the new env vars from the shell that launched Claude Code.

Ask:
- Question: "Plugins reloaded (or Claude Code restarted)?"
- Options: "Yes, done" / "Not yet"

## Phase 6 — Verify end-to-end

After the user confirms reload, run:

```bash
claude mcp list 2>&1 | grep -E "emailbison-b2b|emailbison-personal"
```

Branching:

- Both entries show `✓ Connected` → call `mcp__plugin_marketing_emailbison-b2b__get_active_workspace_info` (expect workspace ID `52`, domain `send.outbase.so`) and `mcp__plugin_marketing_emailbison-personal__get_active_workspace_info` (expect workspace ID `11`, domain `personal.outbase.so`). If both return correctly, print `✓ Email Bison setup complete. Both workspaces reachable.` and jump to Phase 7.

- One or both show `✗ Failed to connect` → troubleshooting loop:
  1. Ask user to open a fresh terminal and run `echo ${EMAILBISON_B2B_TOKEN:+set}` — expect output `set`.
  2. If not `set` → env var didn't reach the shell that launched Claude Code. Tell user to restart Claude Code fully (not just `/reload-plugins`) from the freshly-sourced shell, then re-run this command from Phase 6.
  3. If `set` but still failing → likely token mismatch between Bitwarden and the vendor. Suggest: log into the EB UI, verify the two tokens are active, rotate if needed, update Bitwarden + shell profile, restart.
  4. If only `emailbison-personal` is missing from `claude mcp list` output (not merely failed) → known Claude Code bug where two MCP entries with the same URL can collide; workaround is to restart Claude Code fully. File upstream issue if it persists.

## Phase 7 — Completion message

Tell the user:

> Email Bison MCP is now registered at user level. This is the working pattern until Claude Code's plugin-scoped HTTP header substitution bugs are fixed upstream (tracked in `plugins/marketing/tools/integrations/email-bison.md` § Known Claude Code limitation). When the fix lands, a future marketing-plugin version bump will auto-migrate to plugin-scoped registration — no manual re-setup required on your end.

Exit.
