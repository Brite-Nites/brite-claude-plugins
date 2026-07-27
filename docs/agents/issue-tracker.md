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

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single Linear issue with native **sub-issues** as
tickets. Every primitive maps onto a Linear native — no body-convention fallbacks.

- **Map**: one issue labelled `wayfinder:map` in the *Brite Skill Packs* project, holding
  the Destination / Notes / Decisions-so-far / Not-yet-specified / Out-of-scope body.
  `save_issue` with `team: "Brite Company"`, `project: "Brite Skill Packs"`,
  `labels: ["wayfinder:map"]`.
- **Child ticket**: a native sub-issue — `save_issue` with `parentId` = the map's
  identifier. Label `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`).
  Create missing labels with `create_issue_label` (check `list_issue_labels` first).
- **Blocking**: Linear's **native** blocked-by relations — `save_issue` with
  `blockedBy: ["BC-…"]` (append-only; `removeBlockedBy` to unwire). Create tickets first,
  wire edges in a second pass (issues need identifiers before they can reference each
  other). A ticket is unblocked when every blocker is **closed** — `statusType` in
  `completed` / `canceled` / `duplicate`. Key on the **type**, never the state *name*:
  this team has a `Duplicate` state whose type is neither `completed` nor `canceled`, so
  a name-based "Done or Canceled" test leaves dependents blocked forever.
- **Frontier query**: `list_issues({ parentId: <map>, assignee: "null", orderBy: "createdAt", limit: 50 })`
  (`assignee: "null"` is the documented unassigned filter; pass a `limit` and follow
  `hasNextPage`/`cursor` — a large map otherwise overflows the tool-result cap). Keep open
  states — drop `statusType` `completed`/`canceled`/**`duplicate`** (a closed ticket is never
  claimable, and assignment writes succeed *silently* on one). Then
  `get_issue(id, { includeRelations: true })` per candidate — `list_issues` does not return
  `blockedBy` — and drop any with an open blocker. **Oldest-created survivor wins**, but
  `orderBy: "createdAt"` returns **newest-first**, so sort ascending yourself — don't take
  the first row. A ticket the user named by key wins outright over the frontier pick.
- **Claim**: `save_issue({ id, assignee: "me" })` — the session's first write, before any work.
- **Resolve**: `save_comment` with the answer as the resolution comment,
  `save_issue({ id, state: "Done" })`, then append a context pointer (gist + link) to the
  map's Decisions-so-far. The map body is updated by `save_issue` on the map with the full
  revised `description` — read it first via `get_issue`; `description` replaces, it
  doesn't merge.
- **Rule out of scope**: close as **Canceled**, not Done — `save_issue({ id, state: "Canceled" })` —
  and add the one-line gist + link to the map's Out-of-scope section. Done means "resolved
  on the route"; Canceled means "off the route entirely".

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
