---
issue: BC-6557
title: Smart-merge formula layer for content variables — research/design
status: research/design
date: 2026-05-04
related_issues:
  - BC-6549  # original framing, superseded by BC-6556 + BC-6557
  - BC-6556  # near-term backstop (fail-closed gate at launch)
  - BC-6308  # round-3 dogfood walk where empty-render finding (R-2b) surfaced
  - BC-5537  # Brite enrichment MCP scaffold (per-lead raw value source)
  - BC-2717  # list-building skill (consumer of enrichment outputs)
  - BC-2727  # data-enrichment skill (per-lead value producer)
---

# Smart-merge formula layer — research/design

## Context

In the BC-6308 round-3 launch-campaign dogfood walk (2026-04-30), test finding R-2b confirmed that Email Bison's render engine substitutes any unresolved or null content variable token as an empty string — silently. A campaign with a custom variable like `{RECENCY_ANCHOR}` whose default is unset and whose per-lead value is null sends the email with that token rendered as nothing at all, producing visible double-spaces, orphan punctuation, and broken sentence flow. EB does not error, warn, or surface the missing data anywhere in the campaign UI.

The near-term backstop shipped in [BC-6556](https://linear.app/brite-nites/issue/BC-6556): a fail-closed validation gate at launch time. If any custom variable in a copy artifact has an empty `default` field, the launch halts. This guarantees that *something* always renders in place of the token, but it forces the operator to write a single campaign-level fallback string per variable — the same string for every lead in the campaign, regardless of context. (The fail-closed gate's spec at `plugins/marketing/commands/launch-campaign.md` line 217 already names this issue, BC-6557, as the deeper context-aware fallback that supersedes the gate.)

The long-term direction came from a 2026-05-01 conversation with Holden during BC-6549 analysis: each custom variable should support a small per-lead **formula** that produces a clean rendered string even when that lead's raw value is missing. Conceptually similar to a Clay-style merge column — if the raw value exists for this lead, use it; if not, evaluate a fallback expression that produces something contextually appropriate. The formula evaluates per lead at upload time, before EB ever sees the value, so EB itself stays unchanged.

This document is the **research/design deliverable** for that formula layer. The scope is intentionally bounded to **design + prototype, not build**: a Python prototype demonstrates the formula language works against sample lead data, but production wiring into the launch-campaign code path is a separate follow-up issue, deferred until this design is reviewed.

## Architecture

<!-- Task 3 — to be written -->

## Formula language

<!-- Task 4 — to be written -->

## Schema

<!-- Task 5 — to be written -->

## Examples

<!-- Task 6 — to be written; prototype evidence appended in Task 11 -->

## Migration

<!-- Task 7 — to be written -->

## Rollback

<!-- Task 7 — to be written -->

## Out of scope

<!-- Task 8 — to be written (with revisit triggers per item) -->

## Open questions

<!-- Task 8 — to be written (Holden as named reviewer) -->

## Sources

<!-- Task 12 — to be written (Linear URLs + production preset paths + dogfood evidence) -->
