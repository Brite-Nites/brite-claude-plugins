---
flow_id: TEAM-03
title: Team invitations
status: shipped
qa_status: signed-off
qa_last_signed_off: 2026-05-09T15:00:00Z
figma: https://figma.com/file/abcdef123456/Team?node-id=3%3A4
user_docs_url: https://docs.example.com/team/invitations
last_reviewed: 2026-05-10
children:
  story: BC-1003
  engineering: BC-1301
  design: BC-1302
  qa: BC-1303
  docs: BC-1304
---

# TEAM-03 — Team invitations

> **When** a team admin wants to grow the team, **I want to** send and revoke invite emails inline, **so I can** manage roster changes without leaving the app.

## Acceptance criteria

Scenario: Admin sends a new invite
  Given an admin on the invitations screen
  When the admin enters an email and clicks Invite
  Then the invite is queued and the recipient receives an email

Scenario: Admin revokes a pending invite
  Given a pending invite for someone@example.com
  When the admin clicks Revoke on that invite
  Then the invite is marked revoked and the link stops working

Scenario: Invited user accepts the invite
  Given a pending invite link
  When the recipient clicks the link and signs in
  Then the recipient joins the team as a member

## QA history

| Date | Outcome | Reviewer |
|---|---|---|
| 2026-05-09 | signed-off | qa-fixture |
