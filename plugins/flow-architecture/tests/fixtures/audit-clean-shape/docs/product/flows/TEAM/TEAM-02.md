---
flow_id: TEAM-02
title: Team settings
status: shipped
qa_status: signed-off
qa_last_signed_off: 2026-05-09T14:30:00Z
figma: https://figma.com/file/abcdef123456/Team?node-id=2%3A3
user_docs_url: https://docs.example.com/team/settings
last_reviewed: 2026-05-10
children:
  story: BC-1002
  engineering: BC-1201
  design: BC-1202
  qa: BC-1203
  docs: BC-1204
---

# TEAM-02 — Team settings

> **When** a team admin needs to update billing or display preferences, **I want to** edit settings in one screen, **so I can** keep configuration consistent without filing a ticket.

## Acceptance criteria

Scenario: Admin updates the team display name
  Given an admin on the settings screen
  When the admin changes the display name and clicks Save
  Then the new display name is persisted

Scenario: Admin updates the billing email
  Given an admin on the settings screen
  When the admin changes the billing email and clicks Save
  Then billing notifications route to the new email

Scenario: Non-admin cannot access settings
  Given a non-admin teammate
  When the settings URL is requested directly
  Then access is denied

## QA history

| Date | Outcome | Reviewer |
|---|---|---|
| 2026-05-09 | signed-off | qa-fixture |
