---
flow_id: asset-unification-02
title: Empty-state CTAs
domain: asset-unification
status: not-built
parent_issue: BC-10360
intent: ../../intent.md
---

# asset-unification-02 — Empty-state CTAs

> When a typed library route returns zero results, render a creative-request CTA.

## Cross-domain dependencies

- asset-unification-02 blockedBy ops-hardening-99 — synthetic orphan block (no matching Linear relation)

## Job story

When a typed library route returns zero results, I want a pre-filled creative-request CTA.

<!-- FAIL_BOTH fixture: doc has an orphan bullet (ops-hardening-99 → no Linear match) AND the Linear mock has a separate blockedBy (creative-operations-01) with no matching doc bullet. Both halves of the bidirectional check fail simultaneously. -->
