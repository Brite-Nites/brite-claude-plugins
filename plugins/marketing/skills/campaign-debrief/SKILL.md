---
name: campaign-debrief
description: Structured 5-question post-campaign learning capture (Q1 hypothesis, Q2 result, Q3 what-worked, Q4 surprise, Q5 transferable) that assigns one of four objective verdicts (SCALE / ITERATE / PAUSE / KILL) against concrete numeric thresholds and appends an entry to `docs/campaigns/{entity}/learnings.md`. Serves BDRs, RevOps, and marketing operators closing the loop between campaign execution and campaign intelligence. Triggers on debrief, campaign debrief, retro, log campaign, capture learnings. Receives primary input from `campaign-analysis` via `analysis-*.md`; retroactive path pulls metrics standalone from Email Bison when no analysis artifact exists. Hands off transferable learnings to `message-market-fit` (ITERATE Notes column), `product-marketing-context` (cross-entity propagation proposals), and `/workflows:handbook-drift-check` (handbook-contradiction signals). Append-only, forever. Under 5 minutes per debrief. Adapted from Revgrowth1/ai-gtm-workflows workflow 12 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Campaign Debrief

<!-- TODO(BC-5830) §1 Opener — Batch B. Audience, problem (keystone positioning), outcome, under-5-minute anchor. ~90-130 words. No tool names, repo paths, or MCP servers. -->

---

## Before Starting

<!-- TODO(BC-5830) §2 — Batch C. Input validation preamble + 4 gates: Gate 1 marketing-context soft gate (verbatim sibling string); Gate 2 analysis-*.md availability (≥1 match → Procedure 1, zero → Procedure 2, never halt); Gate 3 entity identification with workspace routing note (Nites → personal, Supply+Labs → b2b); Gate 4 campaign focus selection. -->

---

## Methodology

<!-- TODO(BC-5830) §3 — Batch D (largest section). Subsections: §3 intro; 5-question debrief format with templates; 4-verdict rubric with entity-scoped threshold table (b2b vs b2c); tag scheme (4 families, lowercase-hyphenated); transferable-insight flagging (proposal-not-direct-write); append-only invariant (with carve-out for summary stats / what-works / what-doesn't sections that regenerate in place); vocabulary mapping across sibling skills. -->

---

## Brite Implementation

<!-- TODO(BC-5830) §4 — Batch E. Tools-this-skill-calls table (5 rows) with EB SHORT-form note; entity-keyed output paths; learnings.md file template (create-on-missing); architectural rules that apply (6 cited rules); cross-skill boundaries (receives from, hands off to, does not own, engineering-side parallel). -->

---

## MCP Tool Reference

<!-- TODO(BC-5830) §5 — Batch E. Four workflows: W1 read upstream analysis artifact; W2 standalone EB metrics fetch (retroactive path) with get_active_workspace_info probe, get_campaign_stats, get_replies_analytics, client-side list_campaigns filter note; W3 Salesforce Opportunity attribution (optional) with FieldDefinition preflight; W4 append-to-learnings.md glob-then-write. Confirmation-gate note: no gates apply. -->

---

## Operational Runbook

<!-- TODO(BC-5830) §6 — Batch F. Four procedures with Preconditions / Steps / Expected output / Error handling / Handoff. P1 post-analysis debrief (happy path); P2 retroactive debrief (no artifact); P3 transferable-insight cross-entity propagation; P4 handbook-drift flag. -->

---

## Health Scoring Rubric

<!-- TODO(BC-5830) §7 — Batch G. Four-tier rubric: 10 (excellence), 7-9 (minor gaps), 4-6 (structural gaps), 1-3 (hard failure). Named criteria anchored to observable behaviors. -->

---

## Anti-Slop Guardrails

<!-- TODO(BC-5830) §8 — Batch G. Four base guardrails (jargon, fabricated stats, marketing-context.md, hallucinated tools) + 5 skill-specific hard failures: under-5-minute, append-only, data-first suggestion, lowercase-hyphenated tags, only-4-verdict-tokens. -->

---

## Behavioral Tests

<!-- TODO(BC-5830) §9 — Batch H. Tier 1 (6 scenarios): post-analysis-happy-path, retroactive-manual-stats, subjective-verdict-refused, append-only-refuses-overwrite, under-5-minute-autosuggest, tag-format-hyphenated. Tier 2 (3 scenarios): transferable-cross-entity-flag, missing-context-degraded-mode, eb-short-form-namespace. IDs match evals.json 1:1. -->
