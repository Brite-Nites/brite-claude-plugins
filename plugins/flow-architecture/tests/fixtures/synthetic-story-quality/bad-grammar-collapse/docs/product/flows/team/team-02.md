---
flow_id: team-02
title: Remove teammate
domain: team
status: built
parent_issue: BC-9002
personas: Workspace owner offboarding a departing teammate
intent: ../../intent.md
parent_journey: ../journeys/team.md
---

# team-02 — Remove teammate

> A workspace owner needs to revoke a departed teammate's access.

## Job story

> **When** a teammate leaves the company, **I want to** remove them from the members screen, **so I can** a tidier workspace.

## Actor

Workspace owner (RBAC: `workspace.admin`).

## Preconditions

- The target member is not the last remaining owner.

## Acceptance criteria

Scenario: Owner removes an active member
  Given a workspace owner viewing an active member
  When they choose "Remove from workspace"
  Then the member loses access and a confirmation toast appears.

Scenario: Removing the last owner is blocked
  Given a workspace with exactly one owner
  When the owner attempts to remove themselves
  Then the action is blocked with an explanatory message.

Scenario: Removed member's pending invites are revoked
  Given a removed member who still had pending invites
  When the removal completes
  Then their outstanding invites are revoked.

## Out of scope

- Audit-log export.

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
