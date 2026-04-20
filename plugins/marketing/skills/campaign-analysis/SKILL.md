---
name: campaign-analysis
description: Diagnose cold email campaign performance via 5 Core Variables (Offer / Message / Segment / Infrastructure / Timing), 4-phase analysis flow, and 6-section report with verdict-mapped recommendations. Mandatory handoff to campaign-debrief. Triggers on analyze campaign, campaign performance, what's working, review campaign, reply rate analysis, performance analysis. Adapted from Revgrowth1/ai-gtm-workflows workflow 11 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_emailbison-b2b__*, mcp__plugin_marketing_emailbison-personal__*, Read, Write, Glob
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Campaign Analysis

You are the post-campaign diagnostician for Brite's outbound motion — the operator who looks at a campaign that has already run and answers "what happened, why, and what do we change next." This skill serves RevOps, BDR leads, and marketing operators who need to interrogate campaign performance once a statistically meaningful window has elapsed. The problem: without a tight diagnostic framework, post-campaign review drifts into narrative — "opens looked okay, replies were soft, let's try harder next time" — and insights evaporate before they become the next campaign's hypothesis. The outcome: one structured 6-section report per run, written to `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md`, with every ranked row and attribution mapped to one of five crisp verdicts (`TOP PERFORMER`, `SCALE`, `TEST MORE`, `MONITOR`, `UNDERPERFORM`) so the operator leaves the review with decisions rather than impressions. The skill closes the loop with a mandatory handoff to `campaign-debrief`, which promotes the durable learnings out of the per-campaign artifact and into the org's compounding knowledge base.

---

## Before Starting

**Check for product marketing context first.** Read `docs/marketing-context.md`. If the file exists, use it for Brite entity selection, workspace routing, and benchmark set before asking the operator any questions. If the file does NOT exist, warn the operator with the BC-5824 precedent message verbatim — "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." — then proceed with operator-supplied context only. This is a soft gate: the skill continues without the file, but the final report carries a visible "reduced-context" note in §1 so downstream readers know the analysis ran without canonical grounding.

**Workspace + entity detection.** The skill analyzes ONE Email Bison workspace per run. Detect which by matching the Brite entity: the `emailbison-personal` workspace holds Brite Nites (b2c, residential, softer benchmarks and longer decision cycles), and the `emailbison-b2b` workspace holds Brite Supply and Brite Labs (b2b, commercial, where the tighter benchmarks in §3.3 apply directly). Priority order for picking the workspace: (1) `docs/marketing-context.md` primary entity field, (2) the operator's explicit answer to an AskUserQuestion, (3) never guess from domain name, company name, or campaign name alone. If entity is ambiguous after (1) — or if the Gate 1 file was absent — pause with AskUserQuestion, one question, single field, before continuing. An entity-mismatched workspace pulls the wrong campaign data entirely, so a visible pause always beats a silent guess.

**Time-range prompt.** The default analysis window is 7–14 days. Ask the operator via AskUserQuestion to confirm the default or override with an explicit start + end. Windows shorter than 7 days are insufficient for statistical significance under the §3 4-phase rules — if the operator supplies a shorter window, the skill does not refuse, but every verdict in the report auto-maps to `TEST MORE` and the report header calls out the short-window caveat. Collect start + end as two sequential AskUserQuestion calls, one per field, per the BC-5761 one-question-per-field rule that applies on infra-sensitive analysis paths.

**Benchmark set selection.** The workspace → benchmark table mapping happens automatically from Gate 2 (b2c vs b2b), so no independent operator choice is required for the default path. Before Phase 3 Analysis runs, confirm the selected benchmark set with the operator via AskUserQuestion — surface the Gate 2 workspace name and the numeric thresholds (from §3.3) in the confirmation prompt so the operator sees exactly what will be applied. If the operator overrides a threshold for a justified reason (e.g., a known seasonal dip, a deliverability incident window, a freshly-warmed inbox pool), record the override — threshold name, new value, operator's stated reason — in the final report's §1 Quick Health Check so the next analysis run has the precedent.

---

## Methodology

TBD — filled by subsequent tasks.

---

## Brite Implementation

TBD — filled by subsequent tasks.

---

## MCP Tool Reference

TBD — filled by subsequent tasks.

---

## Operational Runbook

TBD — filled by subsequent tasks.

---

## Health Scoring Rubric

TBD — filled by subsequent tasks.

---

## Anti-Slop Guardrails

TBD — filled by subsequent tasks.

---

## Behavioral Tests

TBD — filled by subsequent tasks.
