# Marketing Tools Registry

Master index of CLI tools and integration guides for the marketing plugin.

> Ported from [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) (MIT licensed).

**Before adding an entry here, read [`docs/guides/skill-tool-integration-pattern.md`](../../../docs/guides/skill-tool-integration-pattern.md).** That guide defines how skills reference tools and what goes in an integration guide vs. a skill body. Use [`integrations/_template.md`](integrations/_template.md) as the starting point for any new integration guide.

## CLI Tools

Tools are organized in `tools/clis/` — each is a standalone CLI wrapper or automation script. Per the MCP-first default in the pattern guide, only add a CLI wrapper when you can name a concrete non-Claude caller (CI job, cron, deployment script). Empty stubs are worse than no stub.

| Tool | Description | Status |
|------|-------------|--------|
| _Populated by individual tool port issues (BC-2580+)_ | | |

## Integration Guides

Integration guides live in `tools/integrations/` — each documents how to connect a third-party service. One guide per MCP server or service; procedural logic belongs in the consuming skill, not here.

| Integration | Description | Status |
|-------------|-------------|--------|
| [email-bison](integrations/email-bison.md) | Cold email sequencer (official MCP server, 141 tools, two workspaces) | Active — dev-scoped .mcp.json |
| _Populated by individual tool port issues (BC-2580+)_ | | |

## Standalone Tools

Five tools not mapped to any skill — tracked as standalone issues:

| Tool | Description | Status |
|------|-------------|--------|
| zapier | Zapier automation workflows | Backlog |
| crossbeam | Partner ecosystem intelligence | Backlog |
| introw | Warm intro automation | Backlog |
| shopify | E-commerce integration | Backlog |
| composio | Composable integration platform | Backlog |
