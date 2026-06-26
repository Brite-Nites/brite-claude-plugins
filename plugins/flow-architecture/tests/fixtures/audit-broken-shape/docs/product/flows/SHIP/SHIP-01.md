---
flow_id: SHIP-01
title: Ship readiness
status: shipped
qa_status: signed-off
qa_last_signed_off: 2026-05-09T16:00:00Z
figma: https://figma.com/file/abcdef123456/Ship?node-id=10%3A1
user_docs_url: https://docs.example.com/ship/readiness
last_reviewed: 2026-05-10
children:
  story: BC-2001
  design: BC-2102
  qa: BC-2103
  docs: BC-2104
domain: SHIP
parent_issue: BC-1
personas: []
related_flows: []
sandbox_url: TBD
staging_url: TBD
real_app_url: TBD
e2e_test: TBD
eng_status: done
design_status: done
docs_status: done
intent: ../../intent.md
---

# SHIP-01 — Ship readiness

> **When** an engineer is about to ship a change, **I want to** see a single readiness verdict, **so I can** decide whether to proceed without scanning multiple dashboards.

## Acceptance criteria

Scenario: Readiness check passes
  Given a branch with all checks green
  When the engineer opens the readiness panel
  Then a single PASS verdict is displayed

Scenario: Readiness check surfaces a failing gate
  Given a branch with a failing audit gate
  When the engineer opens the readiness panel
  Then the failing gate is named with a fix link

Scenario: Readiness check loads under 2 seconds
  Given a typical branch
  When the readiness panel is opened
  Then the verdict renders within 2 seconds

## QA history

| Date | Outcome | Reviewer |
|---|---|---|
| 2026-05-09 | signed-off | qa-fixture |
