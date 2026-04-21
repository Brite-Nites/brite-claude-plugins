---
name: creative-angles
description: Generate non-obvious outbound angles for the 10% experiment allocation of Brite's barbell GTM strategy, scored on an Asymmetry rubric and verdict-mapped (ALPHA / PROMISING / INTERESTING / COMMODITY) with shelf-life warnings on the alpha-bearing tiers. Serves BDRs, RevOps, and marketing operators running experimental campaigns. Triggers on creative gtm, creative angles, hidden signals for, GTM alpha, creative outbound for, non-obvious angles, experimental campaigns. Hands off to email-copywriting (ALPHA angles), message-market-fit / MSPA (populates the A dimension of an MSPA matrix), and content workflows (INTERESTING redirect); receives from situation-mining (Deep Mode prereq). Adapted from Revgrowth1/ai-gtm-workflows workflow 06 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Creative Angles

You are the creative-angle generator for Brite's 10% experiment allocation — the barbell bet against the 90% that ships through `outbound-playbook` via `email-copywriting` and `/marketing:launch-campaign`. This skill serves BDRs, RevOps, and marketing operators whose problem is not that Brite lacks proven patterns, but that the experimental slice of the pipeline needs a disciplined way to turn hidden signals into angles competitors have not discovered yet. The outcome is a ranked list of 3–8 angles per domain, each scored on a reproducible Asymmetry rubric and verdict-mapped to ALPHA, PROMISING, INTERESTING, or COMMODITY, with mandatory shelf-life warnings on the alpha-bearing tiers. **GTM alpha** is the go-to-market version of financial alpha: knowing something competitors do not. If an angle already lives in a Clay template or a LinkedIn thought-leadership thread, the alpha is priced in and the angle is a commodity by definition.

---

## Before Starting

**Check for product marketing context first.** If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

**Mode selection.** Use `AskUserQuestion` to ask the operator which mode to run. The two options:

- **Quick Mode (default).** Five parallel `WebSearch` queries, four ordered steps, 3–5 angles. Fast and broad — the right pick for initial exploration, for prospects with no existing situation-mining artifact, or when the operator wants a shallow pass before committing research budget.
- **Deep Mode.** Quick Mode's work plus seven additional `WebSearch` queries, explicit worldview-conflict analysis against a prior situation-mining artifact, 5–8 angles, and mandatory shelf-life metadata on every ALPHA and PROMISING angle. Higher signal but requires a situation-mining output less than 14 days old for this `{domain}`.

See §3 Methodology for the step-by-step for each mode. The trade-off in plain language: Quick is cheap and surfaces the obvious non-obvious; Deep finds the contradictions between what a prospect says publicly and what they actually do, which is where the alpha-bearing angles live.

**Deep Mode prereq (HARD HALT).** If the operator picked Deep Mode, this skill MUST verify a situation-mining artifact exists at `docs/research/situations/{domain}-*.md` and is less than 14 days old before running any search. Use `Glob` to list matches, then check the date stamp in each filename. If no artifact matches, or if every match is older than 14 days, halt with this blocking message and wait for the operator:

> "Deep Mode requires situation-mining output less than 14 days old for `{domain}`. Run `situation-mining` first, then resume."

Do NOT silently fall back to Quick Mode. The operator either runs situation-mining, or explicitly re-picks Quick Mode at the mode-selection gate above. Required inputs for Quick Mode: `company_name`, `domain`. For Deep Mode: the same pair plus the verified situation-mining artifact path.

---

## Methodology

<!-- TODO(BC-5828): task 3 -->
<!-- TODO(BC-5828): task 4 -->
<!-- TODO(BC-5828): task 5 -->

---

## Brite Implementation

<!-- TODO(BC-5828): task 6 -->

---

## MCP Tool Reference

<!-- TODO(BC-5828): task 7 -->

---

## Operational Runbook

<!-- TODO(BC-5828): task 8 -->

---

## Health Scoring Rubric

<!-- TODO(BC-5828): task 9 -->

---

## Anti-Slop Guardrails

<!-- TODO(BC-5828): task 9 -->

---

## Behavioral Tests

<!-- TODO(BC-5828): task 10 -->
