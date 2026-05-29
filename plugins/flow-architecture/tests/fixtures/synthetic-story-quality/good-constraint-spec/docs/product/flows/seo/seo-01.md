---
flow_id: seo-01
title: Per-domain sitemap and robots
domain: seo
status: built
parent_issue: BC-9101
personas: SEO operator accountable for every published page being crawl-discoverable
intent: ../../intent.md
parent_journey: ../journeys/seo.md
---

# seo-01 — Per-domain sitemap and robots

> A request resolving to a published domain must enumerate that domain's live page set for crawlers without leaking draft pages.

## Job story

> **Given** a request resolves to a published Brite Sites domain, the system **MUST** serve a `sitemap.xml` enumerating every published page in that domain's matrix plus a `robots.txt` pointing to it, **so that** the full page set is crawl-discoverable per domain while unpublished pages stay hidden.

## Actor

The per-domain `sitemap.xml` and `robots.txt` route handlers (system actors), serving search-engine traffic on behalf of the SEO operator who owns crawl coverage. See `docs/personas/seo-operator.md`.

## Preconditions

- The host resolves to a live tenant site.
- At least one page in the domain's matrix has `status = published`.

## Acceptance criteria

Scenario: Published pages are enumerated for a live domain
  Given a domain with 412 published pages and 30 draft pages
  When a request hits /sitemap.xml for that domain
  Then the response is 200 with a urlset of exactly 412 <loc> entries
  And every entry resolves to a published page on that domain.

Scenario: Draft and noindex pages are excluded
  Given a page with status = draft and a separate page carrying a noindex directive
  When the sitemap is generated
  Then neither page appears in the urlset
  And the noindex page is absent even if it was previously published.

Scenario: robots.txt references the per-domain sitemap
  Given a request to /robots.txt on a live domain
  When the handler responds
  Then the body contains a Sitemap: directive with that domain's absolute /sitemap.xml URL
  And no published path is disallowed.

Scenario: An unresolved host returns no sitemap
  Given a host that does not resolve to a tenant site
  When /sitemap.xml is requested
  Then the response is 404 and no urlset is emitted.

## Out of scope

- Google Search Console submission and coverage monitoring (tracked under seo-04).

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
