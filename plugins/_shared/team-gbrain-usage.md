# Team Brain Query Guidance (v1)

Brite runs a team gbrain — a Supabase-backed semantic index of the handbook, decision records, runbooks, and operational docs. Agents with gbrain-team tools should follow the brain-first pattern: **query the brain before external lookups** for anything Brite-specific.

## When to query

Query the team brain when the task involves Brite-specific context:

- **Naming and terminology** — entity names (Nites, Supply, Labs), internal tool names, acronyms
- **Processes and workflows** — how Brite ships, reviews, deploys; sprint cadence; PR conventions
- **Runbook procedures** — operational playbooks, incident response, secret rotation, deploy steps
- **Personas and ICPs** — customer segments, buyer personas, offer postures, vertical definitions
- **Tool conventions** — how Brite uses Linear, Salesforce, Email Bison, gbrain itself
- **Decision records** — past architectural decisions, ADRs, CDRs, rationale for current patterns
- **Team structure** — who owns what, CODEOWNERS, domain boundaries

## When to skip

Do NOT query the brain for obviously generic tasks:

- Vanilla code review on third-party code
- Generic formatting, linting, or syntax questions
- Standard library/framework documentation (use web search or vendor docs)
- Tasks with no Brite-specific dimension

## Tool routing

| Tool | Use when |
|------|----------|
| `query` | Semantic search — start here for most lookups. Pass a natural-language question. |
| `get_page` | Retrieve a specific page by slug when you already know what you want. |
| `list_pages` | Browse available pages — useful for discovery or verifying what content exists. |

## Example queries

```
query: "What is Brite's PR review process for workflow YAML changes?"
query: "How does the team gbrain secret rotation work?"
query: "What are the Nites residential customer personas?"
```

## When the brain doesn't have what you need

Be transparent. If you query the brain and get low-relevance results or no matches:

1. Say so: "I searched the team brain for X but didn't find relevant content."
2. Fall back to other sources (web search, asking the user).
3. This is expected — the brain covers handbook content, not everything.

Low-relevance queries are valuable signal for content gap detection during the observation cycle.
