---
flow_id: seo-02
title: Per-domain sitemap and robots
domain: seo
status: BUILT
parent_issue: BC-9102
personas: SEO operator accountable for every published page being crawl-discoverable
intent: ../../intent.md
---

# seo-02 — Per-domain sitemap and robots

> A request resolving to a published domain must enumerate that domain's live page set for crawlers.

## Job story

> **When** Google's crawler reaches a published Brite Sites domain, **I want to** read a sitemap.xml that enumerates every published page in the matrix, **so I can** index the full page set per domain.

## Actor

Search-engine crawler. See `docs/personas/seo-operator.md`.

## Preconditions

- The host resolves to a live tenant site.

## Acceptance criteria

Scenario: Published pages are enumerated for a live domain
  Given a domain with 412 published pages
  When a request hits /sitemap.xml for that domain
  Then the response is 200 with 412 <loc> entries.

Scenario: Draft pages are excluded
  Given a page with status = draft
  When the sitemap is generated
  Then the draft page does not appear in the urlset.

Scenario: robots.txt references the per-domain sitemap
  Given a request to /robots.txt on a live domain
  When the handler responds
  Then the body contains a Sitemap: directive with that domain's /sitemap.xml URL.

## Out of scope

- Google Search Console submission (tracked under seo-04).

## QA history

| Date | Result | Notes |
|---|---|---|
| — | — | initial |
