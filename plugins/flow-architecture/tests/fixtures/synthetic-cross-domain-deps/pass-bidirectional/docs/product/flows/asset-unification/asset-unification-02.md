---
flow_id: asset-unification-02
title: Empty-state CTAs
domain: asset-unification
status: not-built
parent_issue: BC-10360
intent: ../../intent.md
---

# asset-unification-02 — Empty-state CTAs

> When a typed library route returns zero results, render a creative-request CTA pre-filled with the active filter context so the rep's dead-end becomes an entry point to creative ops.

## Cross-domain dependencies

- asset-unification-02 blockedBy creative-operations-01 — empty-state CTA targets the intake form
- asset-unification-02 blockedBy creative-operations-02 — pre-fill payload contract requires CreativeRequests collection

## Job story

When a typed library route returns zero results, I want a pre-filled creative-request CTA, so I can request an asset without context-switching.
