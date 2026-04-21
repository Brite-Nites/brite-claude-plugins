---
name: account-research
description: Thin orchestrator that dispatches a validated company fact sheet by mode. Serves BDRs, RevOps, and marketing operators doing pre-outreach research who need structured company and people facts without inference, angle generation, or copy. Twelve modes cover 9 single-process invocations (profiles, competitors, growth, hiring, reviews, news, negativity, founders, c-suite) plus 3 composites (full, deep, people), each dispatching to one or more `find-*.md` process files under `plugins/marketing/references/research-processes/`. Triggers on research, research [company], deep research, find info on, company research, people research. Account-research outputs FACTS grouped by dimension (who, what, where, when); situation-mining outputs INFERRED WORLDVIEWS plus angle hypotheses; creative-angles Deep Mode extracts signal clusters into scored angles. Hands off to situation-mining (worldview inference) and creative-angles Deep Mode (signal-cluster extraction); receives from user invocation or situation-mining's fact-gathering subroutine. Adapted from Revgrowth1/ai-gtm-workflows workflow 01 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Account Research

You are the account researcher for Brite's outbound motion. This skill serves BDRs, RevOps, and marketing operators whose problem is not that Brite lacks research capacity, but that today's outbound guesses at company facts with no structured research layer between list-building and per-prospect situation-mining. Operators burn WebSearch budget on ad-hoc queries that ignore stop conditions and kill lists, and downstream skills inherit fuzzy inputs. The outcome is a validated company fact sheet, written to a predictable artifact path, that situation-mining and creative-angles consume as raw evidence. Facts-only discipline applies throughout: no worldview inference, no angle generation, no copy. That work lives downstream in skills built for it.

---

## Before Starting

Four gates resolve in order before any `WebSearch` fires. Cross-references elsewhere in this skill (e.g. "§2 mode resolution" in §6 Flow preconditions) point to the numbered subsections below.

**Input validation.** Every `{domain}` string the skill receives — whether from the operator or from a handoff — must match `^[a-z0-9.-]+$`. Reject any `{domain}` containing `/`, `\`, `..`, single quotes, semicolons, NUL, or SOQL keywords (`SELECT`, `WHERE`, `OR`, etc.). This validator gates the §4 `Write` destinations and §5 Workflow 2 SOQL interpolation — a poisoned `{domain}` must not reach any tool call.

### Gate 1 — Marketing context (soft gate)

Check for product marketing context first. If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: 'Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.' Then continue using only user-provided information.

### Gate 2 — Mode resolution

Account-research has 12 modes, which overflows `AskUserQuestion`'s 4-option cap. Resolution proceeds in three cases:

1. **Operator supplied a `mode` argument.** Validate it against the 12-mode allowlist: `profiles`, `competitors`, `growth`, `hiring`, `reviews`, `news`, `negativity`, `founders`, `c-suite`, `full`, `deep`, `people`. Reject anything outside the list; surface the full allowlist in the rejection message.
2. **Operator did not supply a `mode`.** Default to `profiles`. The 3–6-query profile sheet is the cheapest useful baseline and matches the most common "just tell me about this company" operator intent.
3. **Operator explicitly asks "which mode?"** Surface an `AskUserQuestion` with 4 options — the composite-tier representatives: `profiles` (quick overview), `full` (profiles + competitors + growth + hiring), `deep` (all 9 company processes), `people` (7 people processes). Note in the question body that the 8 single-mode options (`competitors`, `growth`, `hiring`, `reviews`, `news`, `negativity`, `founders`, `c-suite`) remain available by direct argument on a subsequent invocation. Do NOT surface a 12-option `AskUserQuestion` — overflow.

### Gate 3 — Existing-Salesforce-account detection (soft gate)

This gate decides whether §4's output artifact includes an `## Internal Signals (Salesforce)` section. It does NOT halt on failure. Sequence:

1. **Availability probe** — call `run_soql_query` with `SELECT Id FROM User LIMIT 1`. This is the verified liveness check per BC-5534 findings §Q1; `get_username` is NOT a valid probe because it reads the local SFDX auth store without contacting Salesforce. Cache the reachable / unreachable result for the rest of the run.
2. **Account lookup** — on availability success, call `run_soql_query` with `SELECT Id, Name FROM Account WHERE Website LIKE '%{domain}%' LIMIT 5`. Before interpolation, confirm `{domain}` passed the Input validation rule above — single quotes, semicolons, or SOQL keywords in `{domain}` must not reach SOQL.
3. **Degrade policy** — on availability failure, mark `sf_enriched: false` in the output artifact frontmatter and continue. On zero Account matches, also mark `sf_enriched: false`. On one or more matches, proceed to §6 Flow 5 (existing-SF-account augmented path) and carry the `Account.Id` forward for §5 Workflow 2's Activity and Opportunity enrichment queries.

### Gate 4 — Disambiguation (soft gate)

If the supplied `company_name` is common (e.g. "Apex", "Summit", "Pinnacle") and `domain` does not unambiguously resolve to one entity, PAUSE and ask the operator for clarification. Do not burn the research budget on a guess. If `domain` is supplied and unambiguous, proceed without the pause.

---

## Methodology

TODO(BC-5827)

---

## Brite Implementation

TODO(BC-5827)

---

## MCP Tool Reference

TODO(BC-5827)

---

## Operational Runbook

TODO(BC-5827)

---

## Health Scoring Rubric

TODO(BC-5827)

---

## Anti-Slop Guardrails

TODO(BC-5827)

---

## Behavioral Tests

TODO(BC-5827)
