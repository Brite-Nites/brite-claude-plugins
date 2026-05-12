---
flow_id: SHIP-03
title: Ship telemetry
status: shipped
qa_status: signed-off
qa_last_signed_off: 2026-05-09T17:00:00Z
figma: https://figma.com/file/abcdef123456/Ship?node-id=12%3A3
user_docs_url: https://docs.example.com/ship/telemetry
last_reviewed: 2026-05-10
children:
  story: BC-2003
  engineering: BC-2301
  design: BC-2302
  qa: BC-2303
  docs: BC-2304
---

# SHIP-03 — Ship telemetry

> **When** an engineer wants to verify a release in production, **I want to** see live telemetry attached to the deploy, **so I can** confirm health without leaving the ship workflow.

## Acceptance criteria

Scenario: Telemetry panel shows live metrics
  Given a successful deploy 5 minutes ago
  When the engineer opens the telemetry panel
  Then live error-rate and latency metrics are shown

Scenario: Telemetry panel handles missing metrics gracefully
  Given a deploy to a service without telemetry instrumentation
  When the engineer opens the telemetry panel
  Then a clear "no metrics yet" placeholder is shown

Scenario: Telemetry panel links to the dashboard
  Given the panel is open
  When the engineer clicks the dashboard link
  Then the full dashboard opens in a new tab

## QA history

| Date | Outcome | Reviewer |
|---|---|---|
| 2026-05-09 | signed-off | qa-fixture |
