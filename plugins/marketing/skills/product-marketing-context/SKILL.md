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

## Brite Brand Context

Use the following as source material when generating `docs/marketing-context.md`. This is the authoritative brand knowledge for all marketing skill outputs.

### Company Overview

The Brite Company is the parent entity operating four interconnected brands in the lighting and entertainment industry:

- **Brite Nites** — Holiday and seasonal lighting installation services for high-end residential clients. 30 years of field intelligence. The operational backbone and original brand.
- **Brite Supply** — Products and marketplace for professional holiday lighting installers. Every product exists because a Brite Nites crew discovered a problem on a jobsite.
- **Brite Base** — Field Service Management (FSM) SaaS platform for holiday lighting companies. Dogfooded by Brite Nites and Brite Labs internally.
- **Brite Labs** — Custom creative productions and large-scale commercial lighting installations (venues, municipalities, entertainment properties). High-value projects like Gaylord Hotel installations that elevate the entire brand.

### The Flywheel

The entities feed each other in a compounding loop:

- Brite Nites → Brite Supply: Field intelligence becomes products
- Brite Supply → Brite Nites: Brite Base software runs operations; better software → more efficient ops → more intelligence
- Brite Nites → Brite Labs: Residential reputation opens doors to commercial work
- Brite Labs → Brite Supply: Commercial projects surface needs for specialized hardware
- Brite Supply → Brite Labs: Brite Base manages large-scale productions too

### ICP by Entity

| Entity | Primary Audience | Qualifying Criteria |
|--------|-----------------|-------------------|
| Brite Nites | High-end residential homeowners | Home value $2M+, budget $3K+, property suitable for custom lighting |
| Brite Supply | Professional holiday lighting installers | Active business, 10+ jobs/season, not DIY hobbyists |
| Brite Base | Holiday lighting companies needing FSM | 5+ employees, managing scheduling/estimates/crews |
| Brite Labs | Commercial venues, municipalities, entertainment properties | Project budget $50K+, need experiential or large-scale lighting |

### Value Propositions & Messaging Pillars

**Core positioning:** The Brite Company occupies a unique multi-category position — few competitors span installation services, product marketplace, SaaS platform, and creative production simultaneously.

**Messaging pillars by entity:**

**Brite Nites:**
- Premium custom design, not catalog installations
- Full-scope project management (design through removal)
- 30 years of field expertise backing every installation
- Win pattern: clients who value craftsmanship over commodity pricing

**Brite Supply:**
- Products born from real jobsite problems, not theoretical R&D
- Built by installers, for installers
- Integrated with Brite Base for seamless operations

**Brite Base:**
- The only FSM software dogfooded by a 30-year lighting operation
- Scheduling, estimates, crew management purpose-built for the industry
- Better software → more efficient operations (the compounding loop)

**Brite Labs:**
- Turn slow months into high-revenue events with immersive experiences
- Park-scale and venue-scale installations that drive attendance and social media buzz
- Full-scope management so client teams focus on guest experience

### Voice & Tone Guidelines

The brand voice is grounded in five core values:

| Value | Voice Expression | Do | Don't |
|-------|-----------------|-----|-------|
| Excellence | Premium, polished, specific | Use concrete proof points (portfolio examples, credentials) | Use vague superlatives ("industry-leading", "best-in-class") |
| Transformation | Outcome-focused | Focus on customer outcomes and ROI | Describe internal processes |
| Trusted Care | Reliable, responsive, client-first | Emphasize reliability and responsiveness | Sound transactional or impersonal |
| Expression | Creative design partner | Position as collaborative creative partner | Sound like a commodity vendor |
| Personal Touch | Warm, individualized | Be conversational and specific to the client | Sound like mass-market boilerplate |

**Language rules:**
- Say "holiday lighting" or "seasonal displays", not "Christmas lights" (inclusivity + year-round positioning)
- Say "installations" or "displays", not "decorations" (professional, engineered)
- Frame pricing as "cost-effectiveness" and "ROI", not "affordability" (value, not discount)
- Avoid superlatives — use specific proof points instead

### Competitive Positioning

The competitive landscape is broader than "holiday lighting" — Brite competes across multiple categories simultaneously:

- **Direct (installations):** Local/regional lighting contractors, franchise operations
- **Direct (supply):** Holiday lighting product distributors, wholesale suppliers
- **Direct (SaaS):** General FSM platforms (ServiceTitan, Jobber) that lack industry-specific features
- **Win pattern:** Multi-category integration. Competitors occupy one category; Brite's flywheel spans all four, creating compounding advantages competitors can't replicate.
- **Key differentiator:** 30 years of field intelligence feeding product development and software — no pure-play SaaS or marketplace competitor has this operational foundation.

### Channel Strategy

- **Primary:** Direct sales team (Brite Nites, Labs), online marketplace (Supply), product-led growth (Base)
- **Content:** Developer/operator blog, case studies, portfolio showcases
- **Events:** Industry trade shows, conference presence
- **Digital:** LinkedIn thought leadership, targeted outreach to ICP segments

## SoR Integration

If a relevant MCP tool is available (see spec for trait-to-SoR mapping), query it to enrich the context doc:

1. Check MCP availability (HubSpot MCP or Salesforce MCP)
2. Query SoR for: contact segments (ICP match), deal stages, campaign performance, pipeline data
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
