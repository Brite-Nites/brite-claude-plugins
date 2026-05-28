# Getting Started

Developer setup for working on the Brite Claude Plugins repo itself.

> **Not what you're looking for?** If you want to set up a project that *uses* these plugins, run `/workflows:onboarding-checklist` instead. This guide is for people modifying the plugin bundle.

## Prerequisites

| Tool | Version | Why |
|------|---------|-----|
| [Claude Code](https://claude.ai/code) CLI | Latest | Required to run and test plugins |
| Git | 2.x+ | Version control |
| [gh CLI](https://cli.github.com/) | Latest | PR creation and GitHub operations |
| Node.js | 18+ | Required for `sequential-thinking` MCP server (via npx) |
| Python | 3.11+ | Required for CI validation scripts and Ruff linter hook |
| Brite-Nites GitHub org access | — | To push branches and open PRs |

## Clone and Setup

```bash
git clone https://github.com/Brite-Nites/brite-claude-plugins.git
cd brite-claude-plugins
```

That's it. There is no `npm install`, no build step, no dependencies to install. The plugin is pure markdown and JSON.

## Install the Plugin Locally

### Method 1: Direct install (recommended)

```bash
claude plugins add ./
```

### Method 2: Manual settings.json

Add to `~/.claude/settings.json`:

```json
{
  "plugins": [
    {
      "source": "/absolute/path/to/brite-claude-plugins",
      "plugins": ["workflows"]
    }
  ]
}
```

## Verify It Works

1. **Start a Claude Code session** in any directory:

   ```bash
   claude
   ```

2. **Check commands**: Type `/workflows:` — you should see:
   - `session-start` — pick a Linear issue and plan the work
   - `review` — run review agents and fix P1s
   - `ship` — create PR, update Linear, compound learnings
   - `project-start` — guided project inception interview
   - `code-review` — quick or deep code review
   - `tech-stack` — display established tech stack
   - `onboarding-checklist` — new dev setup guide
   - `setup-claude-md` — generate a CLAUDE.md for the current project
   - `smoke-test` — run in-session diagnostics (env, MCP, hooks, agents)

3. **Check SessionStart hook**: On session start, you should see "Loading Brite context..." as a status message.

4. **Test a command**: Run `/workflows:tech-stack` and verify it responds with the Brite tech stack.

## MCP Server Verification

### sequential-thinking

Requires `npx` (comes with Node.js). Verify:

```bash
npx -y @modelcontextprotocol/server-sequential-thinking --help
```

If this fails, ensure Node.js 18+ is installed and `npx` is on your PATH.

### linear-server

Connects to `https://mcp.linear.app/mcp` over HTTP. Requires Linear authentication — you'll be prompted to authorize on first use in Claude Code.

If the Linear server isn't connecting, check that you have a Linear account and have authorized the MCP integration.

## Testing Changes

1. **Edit** any markdown or JSON file in `plugins/workflows/`
2. **Restart** your Claude Code session (changes are loaded at session start)
3. **Verify** the change took effect:
   - Commands: check the slash menu
   - Skills: describe a relevant task to trigger them
   - Hooks: edit a JS/TS/Python file to trigger the PostToolUse linter
   - Agents: invoke the parent skill that delegates to them

### Validate JSON locally

```bash
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null
python3 -m json.tool plugins/workflows/.claude-plugin/plugin.json > /dev/null
python3 -m json.tool plugins/workflows/hooks/hooks.json > /dev/null
```

### Run validation scripts

```bash
bash scripts/validate.sh       # Full structural validation
bash scripts/test-hooks.sh     # Security regex pattern tests
bash scripts/check-prereqs.sh  # Runtime prerequisites
```

## Project Structure

```
.claude-plugin/marketplace.json    # Plugin registry
plugins/workflows/
  .claude-plugin/plugin.json       # Plugin metadata (name, version, author)
  commands/*.md                    # 9 slash commands
  skills/*/SKILL.md                # 10 skills (6 user-invocable, 4 internal)
  skills/_shared/                  # Shared validation + output format templates
  agents/*.md                      # 7 specialized agents
  hooks/hooks.json                 # Security, lint, and session hooks
  .mcp.json                        # MCP server configurations
```

For the full architecture, see [ARCHITECTURE.md](../ARCHITECTURE.md).
