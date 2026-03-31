---
name: {{DOMAIN}}-context
description: Creates docs/{{DOMAIN}}-context.md with foundational {{PLUGIN_NAME}} context for this project. Triggered by the {{TRAIT}} trait. Read by all other {{PLUGIN_NAME}} skills before they act.
user-invocable: true
---

# {{PLUGIN_NAME}} Context Skill

This is the foundational context-skill for the {{PLUGIN_NAME}} domain plugin. It creates and maintains the project-specific context document that all other skills in this plugin read before acting.

## When This Activates

- **Auto-triggered** by `project-start` when the `{{TRAIT}}` trait is detected and this plugin is installed
- **Manually invocable** via `/{{PLUGIN_SLUG}}:domain-context` to refresh the context doc

## What It Produces

**Output file:** `docs/{{DOMAIN}}-context.md`

The context doc contains foundational {{PLUGIN_NAME}} knowledge specific to this project:
- Project-specific domain context gathered during the project-start interview
- SoR-enriched data (if MCP tools are available)
- Frontmatter with `last_refreshed` and `refresh_cadence` for staleness tracking

### Context Doc Frontmatter

```yaml
---
domain: {{DOMAIN}}
trait: {{TRAIT}}
last_refreshed: YYYY-MM-DD
refresh_cadence: quarterly
generated_by: {{SKILL_NAME}}
---
```

**CRITICAL:** Use `last_refreshed`, not `last_generated` — session-start parses this exact key.

## SoR Integration

Context-skills query two tiers of Systems of Record to enrich the context doc:

### Tier 1 — Handbook (Universal, query first)

The Brite Handbook on Context7 (`/brite-nites/handbook`) is a universal SoR available to all context-skills. It provides company-wide knowledge: brand guidelines, ICP definitions, coding standards, competitive positioning, org structure.

1. Call `resolve-library-id("brite-nites handbook")` to get the Context7 library ID
2. Call `query-docs` with domain-relevant topics (see spec § Handbook Query Pattern for recommended topics per domain)
3. Extract relevant context for this domain and project
4. If Context7 is unavailable, log a warning and continue without handbook context

### Tier 2 — Domain MCP (query second, if available)

If a domain-specific MCP tool is available (see spec for trait-to-SoR mapping), query it for live data:

1. Check domain MCP availability
2. Query domain SoR for domain-relevant data
3. **MANDATORY: Follow Data Safety rules** before writing any SoR data — see `docs/designs/BC-1966-context-skill-standard.md` § Data Safety for: newline stripping, character allowlist, field/list caps, frontmatter exclusion, blockquote wrapping
4. Write enriched sections to context doc
5. Record query metadata in `## SoR Sources`

### Fallback behavior

- **Both available:** Full enrichment — handbook + domain SoR + interview data
- **Handbook only:** Handbook-enriched context, `<!-- needs-enrichment -->` on domain SoR sections
- **Domain SoR only:** SoR-enriched but missing handbook company context
- **Neither available:** Interview data only

## How Sibling Skills Use This

All other skills in this plugin MUST read `docs/{{DOMAIN}}-context.md` at the start of their execution. If the file doesn't exist, warn and proceed with reduced context — never hard-fail.

## Specification

See `docs/designs/BC-1966-context-skill-standard.md` for the full context-skill standard, including:
- Required frontmatter schema
- Content format and budget (~80-200 lines)
- SoR query pattern and fallback tiers
- Cross-plugin reference table
