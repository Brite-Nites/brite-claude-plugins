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

Three frameworks govern this skill: the **5 Core Variables diagnostic** (Offer / Message / Segment / Infrastructure / Timing), the **4-phase analysis flow** (Hypothesis → Data Collection → Analysis → Recommendations), and **benchmark-based verdict mapping** that converts ranked metrics into decision labels. The 5 Variables are orthogonal by design — every observation the skill surfaces in the §6 report resolves to exactly one of the five, never two. Phase 1 (Hypothesis) MUST precede Phase 3 (Analysis): writing down expectations before touching data is the skill's single load-bearing guard against narrative retrofit, where the operator reads the numbers first and then invents a story that explains them.

### 5 Core Variables

Every campaign performance observation — ranked-row table entries, anomalies, recommendations — attributes to one of these five variables. Treat them as mutually exclusive diagnostic buckets.

### Offer

The value proposition itself — what the prospect gets if they reply, and whether it is worth replying for. Offer sits upstream of every other variable: if the offer is wrong for the audience, no amount of copy polish, list refinement, or send-time optimization saves the campaign. *Key question: is the offer compelling? Does it solve a real pain the prospect would pay to solve?*

### Message

Subject line, body copy, CTA construction, tone, paragraph structure, spintax density. Message problems masquerade as Segment problems when diagnosed shallowly — "nobody is replying" reads as "wrong list" when it is actually "the hook is generic." *Key question: is the message clear? Does the tone match the audience? Does the CTA invite the right next step?*

### Segment

Who the campaign targeted — titles, verticals, company size, geography, ICP fit, list freshness. A perfect offer mismatched to the audience returns silence, or worse, confused-reply noise that wastes BDR triage hours. *Key question: are we reaching the right ICP? Are the titles accurate? Is the list fresh?*

### Infrastructure

The email sending stack itself — Google Workspace vs Microsoft 365 sender domains, sender warmup status, IP reputation, SPF / DKIM / DMARC posture, bounce handling, inbox rotation. Infrastructure problems show up as bounce-rate spikes, sudden reply-rate cliffs mid-campaign, or sharp Google-vs-Microsoft disparities that have nothing to do with the offer or message. *Key question: are we landing in the inbox or in spam? Is sender reputation healthy?*

### Timing

Send day-of-week, time-of-day, sequence step spacing, overall cadence, campaign start date relative to the prospect's seasonality. Timing problems are the subtlest of the five and often only surface in cohort analysis — a Tuesday-Thursday split, a morning-vs-afternoon split, a pre-holiday vs post-holiday split. *Key question: when are opens and replies actually happening? Is the cadence right for this audience?*

**Orthogonality rule.** Every observation in the §6 report must attribute to exactly one of the 5 variables. If an observation appears to span two (e.g., "low replies on Fridays from senior titles"), split it into two observations — one attribution to Timing, one to Segment — and report them on separate ranked rows. Mixed attributions are a slop signal; §8 anti-slop guardrails will call them out and the report will not pass the §7 rubric if they remain.

### 4-phase analysis flow

The four phases run strictly in sequence — each completes before the next begins. Phase 1 ALWAYS precedes Phase 3; this is the narrative-retrofit guard and is enforced as a hard gate, not a soft convention. Phase 2 feeds Phase 3's inputs; Phase 4 consumes Phase 3's findings; no phase reads ahead.

#### Phase 1 — Hypothesis

State what you expect to see BEFORE pulling any data. Example operator phrasing: "I expect Google infrastructure to outperform Microsoft on reply rate by 1.5-2x, based on the campaign-orchestration ADR's deliverability assumptions." The skill prompts the operator via AskUserQuestion to write down 1-3 specific expectations before proceeding — one question per expectation, per the BC-5761 one-question-per-field rule. The purpose is to prevent narrative retrofitting in Phase 3: an operator who has not written down their prior beliefs will read any Phase 3 data as confirming whichever story is most convenient. If the operator skips this, the skill MUST refuse to continue — there is no "degrade gracefully" path for Phase 1. This is the single hardest gate in the skill.

#### Phase 2 — Data Collection

Pull campaign performance from the Gate-2-detected Email Bison workspace. The exact tool calls live in §5 MCP Tool Reference; the outputs Phase 2 produces are per-campaign stats (sends, opens, replies, bounces, interested replies), per-lead delivery status, and reply-by-reply sentiment hints. Phase 2 also applies the statistical-significance floor: a campaign must have sent at least 500 emails AND run for at least 7 days before Phase 3 can produce any verdict stronger than `TEST MORE`. Below either threshold, every verdict in Phases 3-4 auto-maps to `TEST MORE` regardless of what the numbers look like — small samples lie, and the skill will not pretend otherwise.

#### Phase 3 — Analysis

Apply the 5 Variables orthogonally to the Phase 2 data. Rank all campaigns in the analysis window by Interested Rate. Compute per-variable attribution for the top 2 and bottom 2 performers — for each, name which of the 5 Variables most plausibly explains the performance. Do cohort analysis by bucketing on each variable: Infrastructure (Google senders vs Microsoft senders), Timing (Tuesday sends vs Thursday sends, morning vs afternoon), Segment (title seniority, vertical, company size tier), and so on. Flag statistical anomalies: a 2x+ differential between cohorts of comparable volume is a hard signal worth a recommendation; sub-1.5x is noise unless it repeats across multiple campaigns. Do NOT begin Phase 3 before Phase 1 is written down — this is the Hypothesis-before-Analysis rule, and skipping it is a §8 anti-slop violation.

#### Phase 4 — Recommendations

Map every Phase 3 finding to a specific action via the §3.5 verdict table. Prioritize actions in this order: `SCALE` winners first (they produce the next campaign's budget), `UNDERPERFORM` kills second (they stop the bleed on senders, domains, and list spend), `TEST MORE` experiments third (they feed future hypotheses and seed the next Phase 1). End the phase with the mandatory handoff prompt to `campaign-debrief` — the skill does not consider Phase 4 complete until the operator confirms the handoff. Per-campaign analysis artifacts are disposable; the durable learnings belong in the org's compounding knowledge base, and `campaign-debrief` is the skill that promotes them there.

<!-- TASK 4: §3.3 benchmarks + §3.4 report sections + §3.5 verdict mapping go here -->

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
