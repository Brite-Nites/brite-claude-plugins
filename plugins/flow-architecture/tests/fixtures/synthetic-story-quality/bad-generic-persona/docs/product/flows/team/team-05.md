---
flow_id: team-05
title: Leave workspace
domain: team
status: BUILT
parent_issue: BC-9005
personas: the user
intent: ../../intent.md
---

# team-05 — Leave workspace

> A member needs to remove themselves from a workspace they no longer belong to.

## Job story

> **When** a member no longer works on a project, **I want to** leave its workspace from my account settings, **so I can** stop receiving its notifications and seeing it in my switcher.

## Actor

Workspace member (RBAC: `workspace.member`).

## Preconditions

- The member is not the workspace's last remaining owner.

## Acceptance criteria

Scenario: Member leaves a workspace they belong to
  Given a member viewing the workspace list
  When they choose "Leave workspace" and confirm
  Then they lose access and the workspace disappears from their switcher.

Scenario: Last owner cannot leave without transferring ownership
  Given a workspace where the member is the sole owner
  When they attempt to leave
  Then they are prompted to transfer ownership first.

Scenario: Leaving revokes the member's pending tasks assignments
  Given a member with assigned open tasks
  When they leave the workspace
  Then their assignments are unassigned and flagged for reassignment.

## Out of scope

- Deleting the workspace entirely.

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
