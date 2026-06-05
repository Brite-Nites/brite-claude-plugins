---
flow_id: ops-01
title: Review crawl-coverage gaps
domain: ops
status: built
parent_issue: BC-9201
personas: SEO operator triaging which pages search crawlers failed to fetch
intent: ../../intent.md
---

# ops-01 — Review crawl-coverage gaps

> An SEO operator opens the coverage dashboard, sees which published pages the crawler last failed to fetch, and requeues them before the next crawl window.

## Job story

> **When** an SEO operator opens the coverage dashboard, **I want to** see which published pages the crawler last failed to fetch, **so I can** requeue them before the next crawl window closes.

## Actor

SEO operator (RBAC: `seo.operator`). See `docs/personas/seo-operator.md`. The crawler and the sitemap pipeline are domain objects this operator inspects — they are not the actor here.

## Preconditions

- The operator holds the `seo.operator` role.
- At least one crawl run has completed and recorded per-page fetch status.

## Acceptance criteria

Scenario: Operator sees failed-fetch pages from the last crawl
  Given a completed crawl run with 9 pages marked fetch-failed
  When the operator opens the coverage dashboard
  Then the 9 failed-fetch pages are listed with their last HTTP status and timestamp.

Scenario: Requeue is scoped to the operator's own tenant
  Given an operator scoped to tenant A
  When they requeue a failed page
  Then only tenant A's crawl queue is affected and tenant B's coverage is untouched.

Scenario: Requeue with an empty selection is rejected
  Given the operator has selected zero pages
  When they click Requeue
  Then the action is blocked with an "Select at least one page" message and no queue entry is created.

## Out of scope

- Generating the sitemap the crawler reads (owned by seo-01).

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
