# Team Brain — query first for Brite-specific context

Brite runs a team gbrain: a Supabase-backed semantic index of the handbook, decision records, runbooks, and operational docs. If you hold `gbrain-team` tools, **query the brain before external lookups** for anything Brite-specific, and **save durable findings back**.

## Query when the task touches
- Naming/terminology (Nites, Supply, Labs; internal tool names; acronyms)
- Processes (how Brite ships/reviews/deploys; sprint cadence; PR conventions)
- Runbooks (incident response, secret rotation, deploy steps)
- Personas/ICPs, offer postures, vertical definitions
- Tool conventions (Linear, Salesforce, Email Bison, gbrain)
- Decision records (ADRs, CDRs) and team structure / CODEOWNERS

## Skip for generic tasks
Vanilla third-party code review, formatting/lint/syntax, standard framework docs, anything with no Brite dimension.

## Tools
- `query` — semantic search; start here. Natural-language question.
- `get_page` — fetch a known page by slug.
- `list_pages` — browse/verify what content exists.
- `put_page` — save durable findings (reviews, releases, learnings).

## When the brain lacks it
Say so ("searched the team brain for X, no relevant content"), then fall back to other sources. Low-relevance results are useful content-gap signal — expected, not a failure.
