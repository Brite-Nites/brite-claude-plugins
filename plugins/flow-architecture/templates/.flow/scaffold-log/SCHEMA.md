---
flow_index: skip
last_reviewed: 2026-05-22
---

# .flow/scaffold-log/&lt;domain&gt;.md — frontmatter schema

Per-domain scaffold logs written by `flow-linear-scaffold` (Q13) during `/flow:retrofit-project` Phase 5.3 (per-domain executor) and `/flow:add-domain` Phase 4. One file per domain.

Provenance: shipped by `flow-architecture` plugin templates (BC-11029). This `SCHEMA.md` is documentation only; the orchestrator-produced log files live alongside it in `.flow/scaffold-log/`.

## Frontmatter fields (7 — all required)

| Field | Type | Example | Notes |
|---|---|---|---|
| `domain` | string | `secure-file-ingestion` | Folder-slug form (kebab-lowercase) of the domain. |
| `domain_code` | string | `SFI` | 3-letter UPPERCASE domain code matching `docs/product/master-flow-inventory.md`. |
| `linear_milestone_id` | UUID | `096d3fc3-beed-4370-ad23-bf514efd6978` | Linear milestone UUID. |
| `linear_milestone_name` | string | `Secure File Ingestion` | Display name; useful for human readers. |
| `created_at` | ISO-8601 | `2026-05-20T16:00:00Z` | Timestamp when scaffold ran. |
| `created_via` | string | `/flow-architecture:retrofit-project Phase 5.3 (per-domain executor agent)` | Free-form provenance string. |
| `total_writes` | integer | `31` | Total Linear writes executed: 1 milestone + N parents + 5N children. |

## Body shape

Three markdown tables in the following canonical order:

1. **Milestone (1 row)** — `# | Type | Linear identifier | Name | Result`
2. **Parents (N rows)** — `# | Sub-flow | Linear identifier | Result`
3. **Discipline children (5N rows, organized one row per sub-flow with 5 child columns)** — `Sub-flow | Story | Engineering | Design | QA | Docs | Result`

The `Result` column values: `executed` | `skipped-idempotent` | `failed` (per Q13.5 atomic-recovery taxonomy).

## Idempotency notes

- Re-running `/flow:retrofit-project` against an already-scaffolded domain rewrites the corresponding `.flow/scaffold-log/<domain>.md` file in place per Q13.5.
- `/flow:audit` consumes these files to verify the `scaffold-complete` per-domain gate (per Q29 `scaffold-complete` gate at audit.md:130).
- Hand-edits to existing scaffold logs are NOT preserved across re-runs — these files are run-artifacts, NOT design surface.

## Example

The first sub-section of a populated scaffold log:

```markdown
---
domain: secure-file-ingestion
domain_code: SFI
linear_milestone_id: 096d3fc3-beed-4370-ad23-bf514efd6978
linear_milestone_name: Secure File Ingestion
created_at: 2026-05-20T16:00:00Z
created_via: /flow-architecture:retrofit-project Phase 5.3 (per-domain executor agent)
total_writes: 31
---

# Scaffold log — secure-file-ingestion

31 Linear writes executed during Phase 5.3 on 2026-05-20: 1 milestone + 5 parents + 25 discipline children.

## Milestone (1 × executed)

| # | Type | Linear identifier | Name | Result |
|---|---|---|---|---|
| 1 | milestone | `096d3fc3-...` | Secure File Ingestion | executed |
```

(See the rest of the canonical body shape above.)
