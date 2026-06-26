---
flow_id: SHIP-02
title: Ship rollback
status: shipped
qa_status: signed-off
qa_last_signed_off: 2026-05-09T16:30:00Z
figma: https://figma.com/file/abcdef123456/Ship?node-id=11%3A2
user_docs_url: https://docs.example.com/ship/rollback
last_reviewed: 2026-05-10
children:
  story: BC-2002
  engineering: BC-2201
  design: BC-2202
  qa: BC-2203
  docs: BC-2204
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

# SHIP-02 — Ship rollback

> **When** a deploy goes wrong, **I want to** roll back to the prior release with one click, **so I can** restore service quickly without paging the on-call.

## Acceptance criteria

Scenario: Engineer initiates a rollback
  Given a recent deploy that introduced a regression
  When the engineer clicks Rollback on the deploy detail page
  Then the previous release is re-promoted to production

Scenario: Rollback is recorded in the audit log
  Given a rollback has just completed
  When the audit log is opened
  Then a row records the rollback timestamp + actor

Scenario: Rollback fails when no prior release exists
  Given the first-ever deploy
  When the engineer clicks Rollback
  Then a clear no-prior-release error is shown

## QA history

| Date | Outcome | Reviewer |
|---|---|---|
| 2026-05-09 | signed-off | qa-fixture |
