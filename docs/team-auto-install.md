# Team Auto-Install

Add the Brite plugin marketplace to any project repo so team members get auto-prompted to install it when they trust the project.

## Setup

Add this to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": [
    "https://github.com/brite-nites/brite-claude-plugins"
  ]
}
```

Commit this file to the repo. When a team member opens Claude Code in the project and trusts it, they'll be prompted to install the Brite plugin if they don't already have it.

## What Team Members Get

After installing, the plugin provides:

| Type | Count | Highlights |
|------|-------|-----------|
| Commands | 7 | `session-start`, `review`, `ship`, `code-review`, `project-start`, `tech-stack`, `onboarding-checklist` |
| Agents | 7 | `code-reviewer`, `security-reviewer`, `typescript-reviewer`, `claude-md-generator`, `issue-creator`, `plan-refiner`, `post-plan-orchestrator` |
| Skills | 10 | Design, React/Next.js, browser automation, project planning, workflow |
| Hooks | 4 | Bash security, write security, auto-lint, session context |
| MCP Servers | 3 | Linear, Context7, sequential-thinking |

## Avoiding Duplicates

If a team member already has Linear, Context7, or sequential-thinking configured standalone, the plugin versions take precedence. To avoid duplicates:

- Remove `linear` from `~/.claude/mcp-settings.json` if present
- Remove `context7` from `~/.claude/mcp-settings.json` if present (the plugin now bundles it)
- Disable the standalone `sequential-thinking` plugin in `~/.claude/settings.json` if present
- Keep `bigquery` standalone (the plugin doesn't bundle it)
