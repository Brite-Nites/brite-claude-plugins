---
flow_id: seo-09
title: Crawl-budget sitemap fetch
domain: seo
status: built
parent_issue: BC-9109
personas: SEO operator accountable for crawl budget
intent: ../../intent.md
---

# seo-09 — Crawl-budget sitemap fetch

> A search-engine crawler reaching a published domain must read the sitemap to enqueue every canonical URL.

## Job story

> **When** I'm a search-engine crawler reaching a published Brite Sites domain, **I want to** fetch a sitemap.xml that enumerates every live page, **so I can** enqueue the full canonical URL set for indexing.

## Actor

Search-engine crawler. (First-person `When I'm a crawler …` framing — the D11 infra-misfit this fixture locks; the constraint-spec frame is the correct shape for a non-human actor.)

## Acceptance criteria

Scenario: Sitemap served for a live domain
  Given a published page set
  When the crawler requests /sitemap.xml
  Then a 200 response with a <urlset> enumerating every published canonical URL is returned

Scenario: Robots references the sitemap
  Given a live tenant site
  When the crawler reads /robots.txt
  Then a Sitemap: directive points at the per-domain sitemap.xml

Scenario: Canonical resolves for duplicate URLs
  Given two URLs resolving to the same page
  When the crawler fetches either
  Then a rel=canonical link identifies the single indexable URL
