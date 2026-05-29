---
flow_id: team-01
title: Invite teammate
domain: team
status: built
parent_issue: BC-9001
personas: Workspace owner onboarding a new hire
intent: ../../intent.md
parent_journey: ../journeys/team.md
---

# team-01 — Invite teammate

> A workspace owner needs to bring a colleague into their workspace without leaving the members screen.

## Job story

> **When** a workspace owner is staffing up a new project, **I want to** send a scoped invite from the members screen, **so I can** get a teammate productive before the kickoff meeting.

## Actor

Workspace owner (RBAC: `workspace.admin`). See `docs/personas/workspace-owner.md`.

## Preconditions

- The inviter holds the `workspace.admin` role.
- The workspace seat count is below the plan limit.

## Acceptance criteria

Scenario: Owner invites a teammate by email
  Given a workspace owner on the members screen
  When they enter a colleague's email and choose the "Editor" role
  Then a pending-invite row appears and an invite email is queued.

Scenario: Invite to a seat-capped workspace is blocked
  Given a workspace at its plan seat limit
  When the owner attempts to send an invite
  Then the invite is rejected with an upgrade prompt and no email is queued.

Scenario: Re-inviting an already-pending email is idempotent
  Given an email with an existing pending invite
  When the owner sends a second invite to the same email
  Then the existing pending-invite row is reused and no duplicate email is queued.

## Out of scope

- Bulk CSV invite import (tracked under team-07).

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
