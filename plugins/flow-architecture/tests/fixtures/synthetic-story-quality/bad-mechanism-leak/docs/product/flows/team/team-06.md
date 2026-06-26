---
flow_id: team-06
title: Revoke teammate access
domain: team
status: BUILT
parent_issue: BC-9006
personas: Workspace owner offboarding a departing teammate
intent: ../../intent.md
---

# team-06 — Revoke teammate access

> A workspace owner needs to cut off a departing teammate's access the moment they leave, without waiting on support.

## Job story

> **When** a teammate leaves the company, **I want to** revoke their workspace access from the members screen, **so I can** close the security gap before they walk out the door.

## Actor

Workspace owner (RBAC: `workspace.admin`). The revoke request is gated in `middleware.ts` before it reaches the members screen. See `docs/personas/workspace-owner.md`.

## Preconditions

- The inviter holds the `workspace.admin` role.
- The target teammate currently has an active seat.

## Acceptance criteria

Scenario: Owner revokes an active teammate
  Given a workspace owner on the members screen
  When they choose "Remove" on an active teammate
  Then the teammate's seat is released and their session is invalidated.

Scenario: Revoking the last owner is blocked
  Given a workspace with a single remaining owner
  When that owner attempts to remove themselves
  Then the removal is rejected and an at-least-one-owner warning is shown.

Scenario: Re-revoking an already-removed teammate is idempotent
  Given a teammate who was already removed
  When the owner issues a second remove on the same teammate
  Then no change is applied and no duplicate audit row is written.

## Out of scope

- Bulk offboarding by CSV (tracked under team-08).

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
