---
flow_id: team-04
title: Resend pending invite
domain: team
status: built
parent_issue: BC-9004
personas: Workspace owner chasing an unaccepted invite
intent: ../../intent.md
parent_journey: ../journeys/team.md
---

# team-04 — Resend pending invite

> A workspace owner needs to re-send an invite a teammate never accepted.

## Job story

> **When** an invite has gone unaccepted for days, **I want to** resend it from the pending-invites list, **so I can** nudge the teammate to join without re-typing their email.

## Actor

Workspace owner (RBAC: `workspace.admin`).

## Preconditions

- A pending invite exists for the target email.

## Acceptance criteria

Scenario: Owner resends a pending invite
  Given a workspace owner viewing a pending invite
  When they choose "Resend"
  Then a fresh invite email is queued and the timestamp updates.

Scenario: Resend is rate-limited
  Given a pending invite resent within the last minute
  When the owner chooses "Resend" again
  Then the action is blocked with a cooldown message.

## Out of scope

- Editing the invited role on resend.

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
