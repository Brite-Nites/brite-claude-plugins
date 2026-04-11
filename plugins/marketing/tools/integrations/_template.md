# {Tool Name} Integration

> **Template.** Copy this file to `plugins/marketing/tools/integrations/<tool>.md` and fill in each section. Delete this blockquote and any section that genuinely does not apply (rare — prefer "N/A — reason" over deletion so reviewers can see the thought).
>
> **Golden rule:** this file documents *how to connect* and *what tools exist*. It does NOT document *when to call them, in what order, or why*. That's the consuming skill's job. See `docs/guides/skill-tool-integration-pattern.md` for the split.

## Purpose

One or two sentences. What is this tool, and why does the marketing plugin need it? Reference the canonical outbound pipeline layer (list building / sequencing / reply processing / CRM / analytics) when applicable.

## Consumed by

List the skill files that reference this integration. Keep this list current — it's the only way future maintainers know whether the integration can be retired.

- `plugins/marketing/skills/<skill>/SKILL.md`
- (add more as skills land)

## Auth

Where credentials live and how they reach the MCP server at runtime. Cover:

- **Credential type** — API key, OAuth bearer, OIDC token, workspace-scoped token, etc.
- **Where it comes from** — vendor UI path (Settings → Integrations → ...), Vercel env var, or ADR 2a's credential pattern once that's decided.
- **Scopes / permissions needed** — minimum scope for the workflows this integration supports. Note anything that requires elevated scope explicitly.
- **Multi-tenant / multi-workspace routing**, if applicable — how the skill picks between workspaces (example: Email Bison has a B2B workspace and a personal workspace; the skill decides which to call based on recipient type).

**Do not commit credentials.** If a `.mcp.json` example shows a bearer token, it must be `${ENV_VAR_NAME}` placeholder, never a real value.

## Registration

Exact `.mcp.json` snippet to register the server. Should be copy-pasteable:

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "http",
      "url": "https://...",
      "headers": {
        "Authorization": "Bearer ${<ENV_VAR>}",
        "X-Custom-Header": "..."
      }
    }
  }
}
```

Note which file it goes in:

- Dev convenience: repo-root `.mcp.json` (project-scoped, not distributed)
- Plugin-distributed: `plugins/marketing/.mcp.json` (follows ADR 2a credential pattern once merged)

If both instances need to be registered (e.g. two workspaces on the same vendor), show both entries.

## Tool inventory

The full list of MCP tools this server exposes, grouped by category. Use a table per category; keep it dense. This section is the *reference* the skill authors grep when deciding which tool to call.

### {Category name — e.g. "Campaigns"}

| Tool | Purpose | Notes |
|---|---|---|
| `create_campaign` | ... | ... |
| `list_campaigns` | ... | ... |

### {Next category}

... etc.

**Discoverability escape hatches.** If the server exposes meta-tools like `discover_tools` or `search_api_spec`, document them in a final "Discoverability" sub-section so skills know to fall through to them rather than guessing.

## Rate limits and quotas

- Per-minute / per-hour limits the caller must respect
- Bulk operation caps (e.g. "`bulk_add_leads` accepts 500 leads per call")
- Anything that gets throttled silently
- Retry / backoff guidance (but NOT the procedural retry loop — that's skill logic)

## Known gotchas

Behaviors that will bite a skill author who hasn't used the tool before. Examples:

- Fields that *look* free-form but are actually enums
- Side effects that fire on seemingly-read operations
- Deprecated tools still shown in the inventory
- Workspace scoping surprises
- Silent failure modes

Each entry: one-line symptom + one-line cause + one-line workaround. Don't turn this into a troubleshooting runbook.

## Related skills

Cross-links to skills that use this integration, and to other integrations in the same workflow layer.

- **Primary consumers:** (skills that call this tool directly)
- **Upstream / downstream:** (integrations that feed into or out of this one)
- **Alternatives:** (integrations that could replace this one, and the tradeoff)

## Last verified

`YYYY-MM-DD` — bump this whenever you re-validate the tool inventory against the live vendor API. Stale inventories are the most common failure mode for integration guides, so explicit dating is mandatory.
