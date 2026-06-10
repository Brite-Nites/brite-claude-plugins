---
flow_id: team-03
title: Change teammate role
domain: team
status: BUILT
parent_issue: BC-9003
personas: Workspace owner adjusting a teammate's permissions
intent: ../../intent.md
---

# team-03 — Change teammate role

> A workspace owner needs to promote or demote a teammate's role.

## Job story

> **When** a teammate's responsibilities change, **I want to** update their role from the members screen, **so I can** keep permissions aligned with their actual work.

## Actor

Workspace owner (RBAC: `workspace.admin`).

## Preconditions

- The target member already belongs to the workspace.

## Acceptance criteria

Scenario: Owner promotes an editor to admin
  Given a workspace owner viewing an editor
  When they change the role to "Admin"
  Then the outcome described in the job story holds true.

Scenario: Owner demotes an admin to viewer
  Given a workspace owner viewing an admin
  When they change the role to "Viewer"
  Then the outcome described in the job story holds true.

Scenario: Role change is reflected immediately in the member's session
  Given a member with an active session
  When their role is changed
  Then the outcome described in the job story holds true.

## Out of scope

- Custom roles.

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
