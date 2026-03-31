# marketing

Marketing domain plugin — brand-aware marketing skills ported from [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) (MIT licensed).

## Setup

This plugin is part of the [britenites-claude-plugins](https://github.com/Brite-Nites/britenites-claude-plugins) marketplace.

### Install via marketplace

```bash
claude install-plugin https://github.com/Brite-Nites/britenites-claude-plugins
# Then enable this plugin in the marketplace selector
```

### Local development

```bash
claude --plugin-dir ./plugins/marketing
```

## Structure

```
.claude-plugin/plugin.json   # Plugin metadata (strict schema)
skills/*/SKILL.md             # Auto-activated skills
tools/
  clis/                       # CLI tool wrappers
  integrations/               # Integration guides
  REGISTRY.md                 # Master tool index
hooks/hooks.json              # Lifecycle hooks (SessionStart only — see note)
.mcp.json                     # MCP server configurations
```

## Context-Skill Pattern

This plugin uses the **context-skill pattern** defined in `docs/designs/BC-1966-context-skill-standard.md`.

### How it works

```
project-start (trait: needs-marketing)
  └─> product-marketing-context (foundational skill)
        └─> writes docs/marketing-context.md in target project
              └─> ALL domain skills read this context before acting
```

The foundational skill `product-marketing-context` creates `docs/marketing-context.md` in the target project. This context doc:

- Is triggered by `project-start` when the `needs-marketing` trait is detected
- Contains project-specific marketing knowledge (brand positioning, ICP, messaging pillars, voice/tone)
- Is read by ALL other skills in this plugin before they act
- Includes `last_refreshed` / `refresh_cadence` frontmatter for staleness tracking
- Enriched from the Brite Handbook via Context7 MCP (`/brite-nites/handbook`)

### Adding new domain skills

New skills should follow this pattern:

1. Create `skills/<skill-name>/SKILL.md` with standard frontmatter
2. Include an instruction to read `docs/marketing-context.md` before acting
3. Reference the context-skill standard for trait-to-SoR mapping

## Upstream Attribution

Skills and tools are ported from [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills), licensed under MIT. Ported skills will credit the upstream source in their SKILL.md.

## Conventions

### plugin.json

Only these fields are allowed (unrecognized fields silently break the plugin):

`name`, `description`, `author`, `version`, `homepage`, `repository`, `license`, `keywords`, `commands`, `skills`, `mcpServers` (inline object only)

**Never add:** `agents`, `hooks`, or `mcpServers` as a string path — these are auto-discovered.

### SKILL.md frontmatter

```yaml
---
name: skill-name              # Must match the directory name
description: When to use...   # Plain YAML string (no quotes)
user-invocable: true           # Always explicit true or false
---
```

### Hooks

Only `SessionStart` hooks fire from plugins today. `PreToolUse` and `PostToolUse` are blocked by upstream bug ([#6305](https://github.com/anthropics/claude-code/issues/6305)).

## Validation

```bash
# From the repo root
bash scripts/validate.sh
```
