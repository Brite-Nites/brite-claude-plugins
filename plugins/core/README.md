# brite-core

**Layer 2 of Brite's three-layer agent architecture.** The home for cross-cutting wiring that would otherwise have to be duplicated across all five domain plugins.

```
Layer 0  Claude Code platform ......... plugins, hooks lifecycle, MCP, agent dispatch
Layer 1  gstack (per-developer) ....... preamble, learnings, brain-sync
Layer 2  brite-core  (THIS PLUGIN) .... brain-first hooks, shared security/quality hooks, team-gbrain MCP
Layer 3  domain plugins .............. workflows, marketing, cadence, revops, flow-architecture
```

## What it provides

1. **Brain-first guidance injection** (`hooks/hooks.json` + `team-gbrain-usage.md`)
   - **SessionStart** emits the guidance as plain text (becomes `additionalContext` per the SessionStart contract).
   - **SubagentStart** emits the *same* guidance wrapped in the required JSON envelope —
     `{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":<file>}}`.
     Plain stdout from a SubagentStart hook goes to the debug log and never reaches the
     subagent (this was the silent failure of PR #385); the envelope is the fix.
2. **Centralized security + quality hooks** — the destructive-command regex, secret-scan
   regex, pre-commit advisory, and post-edit linter that were previously copy-pasted into
   each domain plugin now live here once.
3. **Team-gbrain MCP registration** (`.mcp.json`) — the `gbrain-team` server, registered
   once for the whole marketplace via the shared `scripts/gbrain-team-broker.sh` broker.
   The broker reads its OAuth client from `GBRAIN_CLIENT_ID` / `GBRAIN_CLIENT_SECRET`
   in your shell profile (ADR-045) — no vault session, no `bw unlock`. Setup steps:
   [CONTRIBUTING.md § Team gbrain credentials](../../CONTRIBUTING.md#team-gbrain-credentials).
   This plugin owns the canonical copy of the broker; the other five plugins carry
   byte-identical clones, enforced by `validate.sh` §2b-gbrain.

## Why a separate plugin

The 5-plugin model had no home for cross-cutting concerns, so every change touched five
plugins. brite-core gives them one home and frees an MCP slot in each domain plugin
(per the ~5–6-server soft cap).

## Required for all Brite team members

- **v0.1 (now): strongly recommended.** Enable it alongside your domain plugins.
- **v0.2 (planned, BC-11757): enforced** via a PreToolUse block if it isn't enabled.

Enable it:

```
/plugin install brite-core@brite-claude-plugins
```

## Migration status (BC-11741 sprint)

This plugin ships **additively**. The brain-first guidance still also lives in domain-plugin
pointer lines + per-plugin hooks during the overlap window. The subtractive cleanup —
removing the 36 pointer lines (BC-11750) and de-duplicating the domain-plugin hooks + MCP
registrations (BC-11753) — lands only **after** these hooks are validated firing in real
sessions, per the design's overlap-then-cleanup sequencing (Q16b).

## Constraints

- `team-gbrain-usage.md` is hard-capped at **≤2 KB** (`tests/test_size_cap.sh`). It
  auto-loads into every subagent's context — including subagents holding Bash/Write/admin
  tools — so it is both a context-cost and a blast-radius control. **CODEOWNERS review on
  this file is the load-bearing control; the size cap is the backstop.**
- `plugin.json` carries only strict-schema-allowlisted keys (`hooks/`, `.mcp.json` are
  auto-discovered, never declared).
