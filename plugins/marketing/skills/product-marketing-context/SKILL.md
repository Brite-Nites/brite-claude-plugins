---
name: product-marketing-context
description: Creates docs/marketing-context.md with foundational marketing context for this project. Triggered by the needs-marketing trait. Read by all other marketing skills before they act.
user-invocable: true
---

# Marketing Context Skill

This is the foundational context-skill for the marketing domain plugin. It creates and maintains the project-specific context document that all other skills in this plugin read before acting.

## When This Activates

- **Auto-triggered** by `project-start` when the `needs-marketing` trait is detected and this plugin is installed
- **Manually invocable** via `/marketing:product-marketing-context` to refresh the context doc

## What It Produces

**Output file:** `docs/marketing-context.md`

The context doc contains foundational marketing knowledge specific to this project:
- Project-specific domain context gathered during the project-start interview
- SoR-enriched data (if MCP tools are available)
- Frontmatter with `last_refreshed` and `refresh_cadence` for staleness tracking

### Context Doc Frontmatter

```yaml
---
domain: marketing
trait: needs-marketing
last_refreshed: YYYY-MM-DD
refresh_cadence: quarterly
generated_by: product-marketing-context
---
```

**CRITICAL:** Use `last_refreshed`, not `last_generated` — session-start parses this exact key.

## SoR Integration

If a relevant MCP tool is available (see spec for trait-to-SoR mapping), query it to enrich the context doc:

1. Check MCP availability
2. Query SoR for domain-relevant data
3. **MANDATORY: Follow Data Safety rules** before writing any SoR data — see `docs/designs/BC-1966-context-skill-standard.md` for: newline stripping, character allowlist, field/list caps, frontmatter exclusion, blockquote wrapping
4. Write enriched sections to context doc
5. Record query metadata in `## SoR Sources`

If MCP is unavailable, create the context doc from interview data only and mark SoR sections with `<!-- needs-enrichment -->`.

## How Sibling Skills Use This

All other skills in this plugin MUST read `docs/marketing-context.md` at the start of their execution. If the file doesn't exist, warn and proceed with reduced context — never hard-fail.

## Specification

See `docs/designs/BC-1966-context-skill-standard.md` for the full context-skill standard, including:
- Required frontmatter schema
- Content format and budget (~80-200 lines)
- SoR query pattern and fallback tiers
- Cross-plugin reference table
