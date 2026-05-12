---
flow_id: TEAM-01
title: Team onboarding
status: shipped
qa_status: signed-off
qa_last_signed_off: 2026-05-09T14:00:00Z
figma: https://figma.com/file/abcdef123456/Team?node-id=1%3A2
user_docs_url: https://docs.example.com/team/onboarding
last_reviewed: 2026-05-10
children:
  story: BC-1001
  engineering: BC-1101
  design: BC-1102
  qa: BC-1103
  docs: BC-1104
---

# TEAM-01 — Team onboarding

> **When** a new team admin signs in for the first time, **I want to** be walked through team setup, **so I can** invite my teammates without contacting support.

## Acceptance criteria

Scenario: First-time team admin sees the welcome step
  Given an admin signing in for the first time
  When the dashboard loads
  Then a welcome step is displayed

Scenario: Admin completes the team name step
  Given the welcome step has been seen
  When the admin enters a team name and clicks Next
  Then the team name is saved

Scenario: Admin can invite teammates from the onboarding flow
  Given the team name has been saved
  When the admin adds an invite email and clicks Send
  Then an invite is queued for that email

## QA history

| Date | Outcome | Reviewer |
|---|---|---|
| 2026-05-09 | signed-off | qa-fixture |
