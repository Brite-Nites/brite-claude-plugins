# Repository Structure

Multi-plugin monorepo layout. (Extracted from `CLAUDE.md` for line-budget headroom — BC-16375; see also [ARCHITECTURE.md](../ARCHITECTURE.md).)

Multi-plugin monorepo. Each plugin under `plugins/<domain>/` follows the same structure.

```
.claude-plugin/marketplace.json    # Plugin registry (lists all plugins)
plugins/
  workflows/                       # Process + org plugin (primary)
    .claude-plugin/plugin.json     # Plugin metadata
    commands/*.md                  # Slash commands
    skills/*/SKILL.md              # Auto-invoked skills (+ _shared/ utilities)
    agents/*.md                    # Review and utility agents
    hooks/hooks.json               # SessionStart hooks (auto-loaded)
    .mcp.json                      # MCP server configurations
  marketing/                       # Marketing domain plugin
    skills/*/SKILL.md              # Domain skills (context-skill pattern)
    tools/integrations/*.md        # Tool integration guides (see pattern)
    references/                    # Shared reference content read by skills (MIT upstream port, see UPSTREAM.md)
    data/canonicals/               # GTM canonicals (slug+display+personas+offers per ADR-016; lint at plugins/marketing/scripts/lint_canonicals.py)
    scripts/                       # Plugin-owned scripts (bw-run.sh secret broker, tam-map/, lint_canonicals.py)
    hooks/hooks.json
    .mcp.json
  revops/                          # SF dev + CRM data (subtree from Jaganpro/sf-skills, MIT — see UPSTREAM.md)
    skills/                        # 14 retained SF skills (filtered from upstream 36)
    .mcp.json                      # plugin:revops:salesforce
  cadence/                         # Weekly planning cadence (commands/weekly.md — 5 phases, 3 gates, resume breadcrumb; agents/narrative-writer.md drives Phase 4)
```
