# {{PLUGIN_NAME}}

{{PLUGIN_DESCRIPTION}}

## Setup

This plugin is part of the [brite-claude-plugins](https://github.com/brite-nites/brite-claude-plugins) marketplace. It was scaffolded with `/workflows:create-plugin`.

### Install via marketplace

```bash
claude install-plugin https://github.com/brite-nites/brite-claude-plugins
# Then enable this plugin in the marketplace selector
```

### Local development

```bash
claude --plugin-dir ./plugins/{{PLUGIN_NAME}}
```

## Structure

```
.claude-plugin/plugin.json   # Plugin metadata (strict schema)
commands/*.md                 # Slash commands
skills/*/SKILL.md             # Auto-activated skills
hooks/hooks.json              # Lifecycle hooks (SessionStart only — see note)
.mcp.json                     # MCP server configurations
```

## Context-Skill Pattern

Every domain plugin has a foundational **context-skill** that creates `docs/<domain>-context.md` in the target project. This context doc:

- Is triggered by `project-start` when the plugin's trait is detected
- Contains project-specific domain knowledge enriched by SoR queries (if available)
- Is read by ALL other skills in this plugin before they act
- Includes `last_refreshed` / `refresh_cadence` frontmatter for staleness tracking

The template at `skills/domain-context/SKILL.md` provides the starting skeleton. See `docs/designs/BC-1966-context-skill-standard.md` for the full specification.

## Conventions

### plugin.json

Only these fields are allowed (unrecognized fields silently break the plugin):

`name`, `description`, `author`, `version`, `homepage`, `repository`, `license`, `keywords`, `commands`, `skills`, `mcpServers` (inline object only), `userConfig` (inline object; use `sensitive: true` for keychain-stored secrets)

**Never add:** `agents`, `hooks`, or `mcpServers` as a string path — these are auto-discovered.

### SKILL.md frontmatter

```yaml
---
name: skill-name              # Must match the directory name
description: When to use...   # Plain YAML string (no quotes)
user-invocable: true           # Always explicit true or false
---
```

### Commands

```yaml
---
description: Short description
---
```

### Hooks

Only `SessionStart` hooks fire from plugins today. `PreToolUse` and `PostToolUse` are blocked by upstream bug ([#6305](https://github.com/anthropics/claude-code/issues/6305)).

## Validation

```bash
# From the repo root
bash scripts/validate.sh
```
