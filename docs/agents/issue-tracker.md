# Issue tracker: Linear

Issues and PRDs for this repo live in **Linear**, not GitHub Issues — even though the repo
has a GitHub remote (`Brite-Nites/brite-claude-plugins`). Don't run `gh issue …` for issue work.

- **Team:** Brite Company (issue prefix `BC-`, *not* `BRI-`)
- **Project:** Brite Skill Packs (default; sibling projects in the same team — *Brite Orchestration Layer*, *Brite Knowledge Layer*, *Brite Runtime & Harness* — per the 2026-05-27 4-layer re-org)
- **Access:** the Linear MCP server bundled with the `workflows` plugin
  (`mcp__plugin_workflows_linear-server__*`)

## Conventions

- **Create an issue**: `save_issue` with `title`, `description` (markdown body), `team: "Brite Company"`,
  and `project: "Brite Skill Packs"`. Set `labels` for triage state (see `triage-labels.md`).
- **Read an issue**: `get_issue(<BC-NNNN>)`; `list_comments(<issue>)` for the discussion thread.
- **List issues**: `list_issues` filtered by `team`, `project`, `assignee`, `state`, or `label`.
- **Comment**: `save_comment(<issue>, body)`.
- **Change triage state**: `save_issue(<issue>, labels: [...])` for labels; `save_issue(<issue>, state: "…")`
  for workflow states (Linear has built-in **Triage** and **Canceled** states).
- **Close**: `save_issue(<issue>, state: "Done")` (or `Canceled` for wontfix).

## When a skill says "publish to the issue tracker"

Create a Linear issue with `save_issue` in the Brite Company team / Brite Skill Packs project.

## When a skill says "fetch the relevant ticket"

`get_issue(<BC-NNNN>)` plus `list_comments` for the thread. The user normally passes the `BC-` key directly.

## Gotchas

- `save_issue` with only `milestone:` silently no-ops unless the issue is already in the milestone's
  parent project — pass `project:` + `milestone:` together.
- `save_comment` that mentions another `BC-NNNN` in plaintext bumps that issue's `updatedAt` via backlink
  (no state change). When verifying "issue X unchanged," check `status`/`completedAt`, not `updatedAt`.

## See also

**Which intake command do I use?** The full **intake & triage map** is canonical in the handbook
(brain-queryable): handbook → [`revops-data-engineering/ai-tools/intake-triage-map.md`](https://github.com/Brite-Nites/handbook/blob/main/revops-data-engineering/ai-tools/intake-triage-map.md).
It routes a product bug/idea **or** an agent-tooling issue to `/workflows:raise-a-ticket` (the single
front door), a GTM offer/concept to `/marketing:capture-idea`, and processing an existing ticket to
`/triage` — and notes the `bug-report` (deprecated, forwards) + `report-issue` (expert alias) status.
