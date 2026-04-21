---
name: campaign-analysis
description: Diagnose cold email campaign performance via 5 Core Variables (Offer / Message / Segment / Infrastructure / Timing), 4-phase analysis flow, and 6-section report with verdict-mapped recommendations. Mandatory handoff to campaign-debrief. Triggers on analyze campaign, campaign performance, what's working, review campaign, reply rate analysis, performance analysis. Adapted from Revgrowth1/ai-gtm-workflows workflow 11 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob
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

### Benchmarks

These benchmarks are Brite-specific targets for b2b campaigns running in the `emailbison-b2b` workspace (Brite Supply and Brite Labs). b2c campaigns in the `emailbison-personal` workspace (Brite Nites) use softer targets documented in the §4 Brite Implementation table — do not duplicate them here. The numbers below are the scoreboard against which the §3.4 report's §1 Quick Health Check runs and the §3.5 verdict mapping resolves each ranked row; every Phase 3 comparison and Phase 4 verdict traces back to this table.

**b2b benchmark targets (emailbison-b2b workspace — Brite Supply + Labs):**

| Metric | Healthy | Attention | Critical |
|--------|---------|-----------|----------|
| Reply Rate | above 1% | 0.5% – 1% | below 0.5% |
| Interested Rate | above 25% of replies | 15% – 25% of replies | below 15% of replies |
| Bounce Rate | below 3% | 3% – 5% | above 5% |

Reply Rate measures (replies ÷ sent), Interested Rate measures (interested-replies ÷ replies), and Bounce Rate measures (bounces ÷ sent). Interested replies are EB MCP's reply-sentiment classification — see §5 for the exact tool call. Below the statistical-significance floor stated in §3.2 Phase 2 (500 sent AND 7 days), none of these benchmarks apply — all verdicts auto-map to `TEST MORE` regardless of how the raw numbers look.

b2c (emailbison-personal, Brite Nites) benchmarks live in §4 Brite Implementation and shift each Healthy threshold downward by roughly half — residential cold email runs longer decision cycles and softer response rates than b2b commercial.

### 6-section report structure

Every analysis run emits one report artifact at `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md` (per §1) containing the full 6-section template below. Sections are omitted ONLY when the data floor was not met and the whole report degrades to a `TEST MORE` stub; in every other case all six sections render, even when one section is brief. The section order is load-bearing — health check precedes ranking precedes attribution precedes recommendations — and downstream readers (including `campaign-debrief`) expect that ordering.

1. **Quick Health Check.** Purpose: snapshot the campaign against the §3.3 benchmarks. Output: a three-row comparison table (Reply Rate / Interested Rate / Bounce Rate — actual vs Healthy / Attention / Critical band, with a one-word verdict per row). Also surfaces any benchmark overrides the operator recorded during Gate 4 of §2.
2. **Segment Performance Ranking.** Purpose: rank every campaign in the analysis window by Interested Rate (desc) with a per-row verdict drawn from §3.5. Output: a ranked table with columns Campaign / Sends / Reply Rate / Interested Rate / Verdict.
3. **Infrastructure Analysis.** Purpose: compare sender infrastructure cohorts (Google Workspace vs Microsoft 365 domains; warmup-complete vs warmup-in-progress; by-domain deliverability). Output: a cohort comparison table plus a narrative paragraph calling out any 2x+ cohort differential (per §3.2 Phase 3's anomaly rule).
4. **Reply Sentiment Analysis.** Purpose: break down reply-sentiment distribution (Interested / Not Interested / Information / Out of Office / Objection) across the ranked campaigns. Output: a distribution table plus a narrative on the two dominant non-Interested sentiments (which usually diagnose Message or Segment problems).
5. **Attribution Analysis.** Purpose: attribute the top 2 winners and bottom 2 underperformers to exactly one of the 5 Core Variables each (orthogonality rule from §3.1). Output: a four-row table with columns Campaign / Performance Band / Attributed Variable / Evidence (1-2 sentences).
6. **Next Iteration Recommendations.** Purpose: convert every finding into an actionable recommendation prioritized by verdict (`SCALE` first, `UNDERPERFORM` second, `TEST MORE` third, `MONITOR` / `TOP PERFORMER` observational). Output: a prioritized action list plus the mandatory campaign-debrief handoff prompt.

Every recommendation in §6 must trace back to at least one §5 Attribution row — a recommendation without an attribution is a narrative slip and §8 anti-slop will flag it.

### Verdict mapping

Verdict mapping runs in Phase 4 after all §3.3 benchmark comparisons and §3.4 attributions are complete. Every campaign that appears in the §3.4 Segment Performance Ranking table gets exactly one verdict; the table below is the authoritative assignment key. The verdict labels are fixed — they are the exact strings the operator sees in the rendered report and the exact tokens §8 anti-slop and §9 behavioral tests match against.

| Verdict | Assignment rule | Priority in §6 |
|---------|-----------------|----------------|
| `TOP PERFORMER` | Reply Rate Healthy AND Interested Rate Healthy AND sends ≥ 500 over ≥ 7 days | Observational — record template, do not touch |
| `SCALE` | Reply Rate Healthy OR (Interested Rate Healthy AND Reply Rate Attention) AND Bounce Rate not Critical | Priority 1 — expand senders / volume next campaign |
| `TEST MORE` | Sends < 500 OR days < 7 OR every verdict-critical metric in Attention band with insufficient cohort data | Priority 3 — allocate small follow-up budget, re-analyze after floor met |
| `MONITOR` | Mixed signals — some metrics Healthy, some Attention, no clear Infrastructure or Segment attribution | Priority 4 — observational, re-check in 7 days |
| `UNDERPERFORM` | Reply Rate Critical OR Bounce Rate Critical OR (Interested Rate Critical AND sends ≥ 500) | Priority 2 — kill the campaign, attribute the failure variable, feed into next hypothesis |

Verdicts are attributed at the campaign level, not the reply level. A single unusual reply does not promote `UNDERPERFORM` to `MONITOR`. The priority ordering in §6 — `SCALE` first (wins compound), `UNDERPERFORM` second (bleeds stop), `TEST MORE` third (experiments seed future hypotheses), `MONITOR` and `TOP PERFORMER` observational — is fixed by §3.2 Phase 4. Do NOT reorder the priorities in the report.

---

## Brite Implementation

This section translates §3 Methodology into Brite's concrete stack — which MCP server, which tool, which repo, which architectural rule. The skill calls two MCP servers: one Email Bison workspace (`emailbison-b2b` for Brite Supply + Labs, `emailbison-personal` for Brite Nites — only ONE per run, picked via the §2 Gate 2 detection rule) for campaign performance data, and the Salesforce MCP for downstream pipeline attribution. Every run writes exactly one artifact to `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md` (path per §1). Every recommendation the report surfaces in its §6 Next Iteration block MUST resolve to one of the five §3.5 verdict labels (`TOP PERFORMER`, `SCALE`, `TEST MORE`, `MONITOR`, `UNDERPERFORM`) — no free-form narrative recommendations, no hedged prose substitutes.

### Tools this skill calls

| What the skill needs to do | MCP server | Tool(s) | Reaches | Reason |
|---|---|---|---|---|
| Availability check before any EB call | `emailbison-b2b` or `emailbison-personal` (Gate-2 detected) | `get_active_workspace_info` | Email Bison workspace | ADR 2c degradation policy — lightweight read-only liveness probe |
| Pull workspace-level rollup for the §6 §1 Quick Health Check header | same EB MCP | `list_workspace_stats` | same workspace | Verified in sibling `email-bison` skill (§4 quick-stats row); gives the aggregate Reply / Interested / Bounce rates before per-campaign breakdown |
| Enumerate campaigns in the §2 time window | same EB MCP | `list_campaigns` + client-side filter | same workspace | Feeds §6 §2 Segment Performance Ranking. The Campaigns category has no server-side date-range filter (verified 2026-04-20 via `discover_tools` — see `email-bison.md` §Known gotchas); pull the full list and filter client-side on `created_at` / `started_at` |
| Pull per-campaign performance (sends / opens / replies / bounces / interested count) | same EB MCP | `get_campaign_stats` | same workspace | §3.2 Phase 2 primary per-campaign signal; feeds §6 §2 Segment Performance Ranking |
| Pull per-lead delivery status for Infrastructure + Timing cohort analysis | same EB MCP | `get_leads_analytics` | same workspace | Verified in sibling `email-bison` skill (§4 quick-stats row); §6 §3 Infrastructure + §6 §4 Reply Sentiment need per-lead delivery rows |
| Enumerate senders to cohort Infrastructure by Google Workspace vs Microsoft 365 | same EB MCP | `list_sender_emails` | same workspace | §6 §3 Infrastructure Analysis needs the sender-domain split — tool verified in `email-bison.md` §Common workflows |
| Pull aggregated reply-sentiment distribution for §6 §4 | same EB MCP | `get_replies_analytics` | same workspace | Core-tier aggregator (top-level analytics group, not inbox category — verified 2026-04-20 via `discover_tools`); returns total counts broken down by `interested` / `not interested` / `auto-reply` plus per-campaign engagement rollup — the exact shape §6 §4 needs |
| Pipeline attribution: did any replies become Opportunities? | Salesforce MCP | `run_soql_query` | `brite-salesforce` production org | §6 §6 Next Iteration needs downstream conversion signal; ADR 2a — SF is CRM system of record |

Do not list tools the skill will not call — this table is the authoritative scope per the skill-tool-integration pattern's anti-pattern #4. All seven EB tools above (`get_active_workspace_info`, `list_workspace_stats`, `list_campaigns`, `get_campaign_stats`, `get_leads_analytics`, `list_sender_emails`, `get_replies_analytics`) are verified against `email-bison.md` — the two formerly runtime-discovered names (`list_campaigns` for campaigns-in-window and `get_replies_analytics` for reply sentiment) were confirmed live via `discover_tools` on 2026-04-20 and added to `email-bison.md` §Analytics + §Known gotchas. No runtime `discover_tools` / `search_api_spec` calls needed at skill runtime.

### Entity-keyed benchmark sets

The §3.3 benchmark table applies to the b2b workspace (`emailbison-b2b`, Brite Supply + Labs). The b2c workspace (`emailbison-personal`, Brite Nites) has softer thresholds on Reply Rate and Interested Rate — residential outbound runs longer decision cycles and softer response rates than b2b commercial. Thresholds on Bounce Rate are identical across both sets: bounces are an infrastructure signal, not an audience-fit signal, and the underlying threshold doesn't shift with motion type.

**b2c benchmark targets (emailbison-personal workspace — Brite Nites):**

| Metric | Healthy | Attention | Critical |
|--------|---------|-----------|----------|
| Reply Rate | above 0.5% | 0.25% – 0.5% | below 0.25% |
| Interested Rate | above 15% of replies | 10% – 15% of replies | below 10% of replies |
| Bounce Rate | below 3% | 3% – 5% | above 5% |

> **Calibration caveat.** These b2c thresholds are initial targets, not calibrated. Brite Nites residential outbound is newer than the Supply/Labs b2b motion and the thresholds should be re-derived from real data after 3+ completed b2c campaigns reach the §3.2 Phase 2 statistical-significance floor (500 sent AND 7 days). File the calibration follow-up as a new Linear issue blocking BC-2721 sign-off. Until recalibration, report output must carry a visible "b2c benchmarks uncalibrated — initial targets" footer in §1 Quick Health Check.

No Brite Supply-specific benchmark set exists — Supply uses the b2b table per handbook canon (BC-5823 precedent). Do not bolt on a third set.

### Architectural rules that apply

- **Hypothesis-before-Analysis.** Phase 1 MUST be written down before Phase 3 begins. No degrade path. Source: §3.2 Phase 1.
- **Statistical-significance floor.** Below 500 sent OR below 7 days elapsed, every verdict auto-maps to `TEST MORE` regardless of how the raw numbers look. Source: §3.2 Phase 2.
- **Orthogonal attribution.** Every §6 report observation resolves to exactly one of the 5 Core Variables (Offer / Message / Segment / Infrastructure / Timing). Mixed attributions are a §8 slop flag. Source: §3.1 orthogonality rule.
- **Objective verdict language.** All recommendations use one of the five §3.5 verdict labels (`TOP PERFORMER`, `SCALE`, `TEST MORE`, `MONITOR`, `UNDERPERFORM`). No subjective phrasing ("solid", "okay", "meh"). Source: §3.5.
- **Availability check before first EB call.** `get_active_workspace_info` runs once at the start of Phase 2; on failure the skill stops and reports — it does not attempt partial analysis against a degraded workspace. Source: ADR 2c degradation policy (referenced in `plugins/marketing/tools/integrations/email-bison.md`).
- **Mandatory campaign-debrief handoff.** Phase 4 is not complete until the operator confirms the handoff to `campaign-debrief`. Source: issue description §Scope — Handoffs, §3.2 Phase 4.

### Cross-skill boundaries

**Hands off to:**

- **[BC-5830](https://linear.app/brite-nites/issue/BC-5830) campaign-debrief — MANDATORY.** Fires at end of Phase 4, every run. Prompt the operator verbatim: *"Analysis complete. To capture these learnings so they compound into future campaigns, run the campaign debrief workflow."* This is the loop-closer; Phase 4 is not complete until the operator confirms.
- **[BC-2719](https://linear.app/brite-nites/issue/BC-2719) deliverability-audit — CONDITIONAL.** Fires when Infrastructure variable is the suspected root cause: bounce-rate spike into §3.3 Critical band, OR Google-vs-Microsoft 2x+ cohort disparity on Reply Rate with comparable volume, OR spam-complaint signals surfaced in §6 §3 Infrastructure Analysis. Surface the handoff with the triggering signal named explicitly.
- **[BC-5829](https://linear.app/brite-nites/issue/BC-5829) message-market-fit MSPA — ON-REQUEST, ITERATE mode.** Fires when the operator asks "what should we test next?" after Phase 4 renders. The §6 §6 Next Iteration Recommendations block becomes MSPA ITERATE's input hypotheses.

**Receives from:**

- The operator directly (post-campaign invocation).
- [BC-2722](https://linear.app/brite-nites/issue/BC-2722) outbound-playbook during the campaign-monitoring phase of an active playbook run.
- [BC-5829](https://linear.app/brite-nites/issue/BC-5829) MSPA DIAGNOSE mode when a stuck pipeline needs performance root-causing.

**Does not own:**

- Per-reply sentiment classification at runtime — that's [BC-2720](https://linear.app/brite-nites/issue/BC-2720) reply-processing. This skill reads the sentiment tags EB already produced; it doesn't classify new replies.
- Test design or next-batch experimentation — that's BC-5829 MSPA.
- Learning capture, transferable-insight flagging, entity-keyed learnings file — that's BC-5830 campaign-debrief.
- Launching, pausing, or modifying the campaign itself — that's `campaign-orchestration`. This skill is analytical, not operational.

---

## MCP Tool Reference

§4 declared WHAT tools this skill uses; §5 says WHEN — which phase, in what order. Grouping is by phase (Hypothesis → Data Collection → Analysis → Recommendations), not by server, because the skill author thinks in phases. Every mutating workflow starts with the `get_active_workspace_info` availability probe per the ADR 2c degradation policy — on failure the skill stops and reports rather than attempting partial work. See [`plugins/marketing/tools/integrations/email-bison.md`](../../../tools/integrations/email-bison.md) for canonical EB tool-name anchors and the 141-tool category map, and [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) for SF auth, SOQL gotchas, and field-existence preflight patterns.

### Phase 1: Hypothesis

No MCP calls. The skill prompts the operator via AskUserQuestion to write down 1-3 expectations — what they expect to see in the data, grounded in prior campaigns or the `campaign-orchestration` deliverability assumptions (e.g. "Google senders will beat Microsoft on Reply Rate by 1.5-2x"). Ask one expectation per question per the BC-5761 one-question-per-field rule. The phase ends when the operator submits the hypotheses; the skill records them verbatim in the §6 §5 Attribution Analysis block so Phase 3 can check each hypothesis against actual data. If the operator skips Phase 1, the skill refuses to continue — there is no degrade path, per §4.3 Hypothesis-before-Analysis rule.

### Phase 2: Data Collection

Order matters: availability check → workspace rollup → campaign enumeration → per-campaign breakdown → per-lead drill → sender cohort → reply-sentiment aggregate. Run the steps in sequence; do not parallelize — step 3's filtered campaign-ID list feeds step 4's iteration set.

1. **`get_active_workspace_info`** — availability check. Confirms which workspace the EB MCP is currently pointed at (`emailbison-b2b` or `emailbison-personal`). If this call fails, the skill stops and reports the server name plus a pointer to `/marketing:setup-email-bison` — Phase 2 does not attempt partial data collection against a degraded workspace. Compare the returned workspace against the §2 Gate 2 operator answer; if they differ, surface the mismatch to the operator and stop. The skill does NOT mutate workspace state (no `set_active_workspace` call) — the operator fixes the pointer out-of-band and re-runs.
2. **`list_workspace_stats`** — pull workspace-level rollup for the §2 time window. Populates the header of §6 §1 Quick Health Check (aggregate Reply Rate / Interested Rate / Bounce Rate for the window).
3. **`list_campaigns` + client-side date filter** — pull the full campaign list, then filter client-side on `created_at` / `started_at` against the §2 start / end dates. The Campaigns category has no server-side date-range filter (per `email-bison.md` §Known gotchas — verified 2026-04-20 via `discover_tools`); filtering in-memory after the list call is the canonical pattern. Produces the campaign-ID set that feeds step 4.
4. **`get_campaign_stats`** — iterate the campaign IDs from step 3; pull per-campaign sends / opens / replies / bounces / interested counts. Feeds §6 §2 Segment Performance Ranking.
5. **`get_leads_analytics`** — per-lead delivery status. Feeds §6 §3 Infrastructure Analysis (per-lead rows bucketed by sender domain) and §6 §4 Reply Sentiment Analysis (per-lead reply tags).
6. **`list_sender_emails`** — enumerate senders in the workspace. Filter by `status == "connected"`. Group by domain provider (Google Workspace vs Microsoft 365 vs other) to build the §6 §3 Infrastructure cohort comparison.
7. **`get_replies_analytics`** — aggregated reply-sentiment distribution for the §2 time window. Returns total reply counts broken down by `interested` / `not interested` / `auto-reply` plus a per-campaign engagement rollup. Lives in the top-level analytics group (not the inbox category — per `email-bison.md` §Analytics). Feeds §6 §4 Reply Sentiment Analysis directly; no iteration of individual replies required.

If Phase 2 completes but sends < 500 OR days < 7, record "sub-floor run" in the report header and auto-map every Phase 4 verdict to `TEST MORE` per §4.3 architectural rule 2 (statistical-significance floor). If Phase 2 fails for any OTHER reason — availability failure at step 1, permission error mid-iteration, empty campaign list from step 3 — the skill stops and reports; it does not attempt Phase 3 analysis against partial data.

### Phase 3: Analysis

No new MCP calls — this phase is pure synthesis against the Phase 2 data. Rank all campaigns in the window by Interested Rate descending. Compute per-variable attribution for the top 2 and bottom 2 using the §3.1 5 Core Variables (Offer / Message / Segment / Infrastructure / Timing) with the orthogonality rule applied — each ranked row attributes to exactly one variable. Build cohort comparisons: Google Workspace vs Microsoft 365 senders (from step 6's grouping), weekday vs weekend sends, b2c vs b2b if the window spans both workspaces (though Gate 2 normally scopes to one). Flag any 2x+ cohort differential with comparable volume as a hard signal worth a §6 §6 recommendation; sub-1.5x is noise unless it repeats across multiple campaigns. Check each operator hypothesis from Phase 1 against the actual data and label each one CONFIRMED / PARTIAL / REJECTED — one-line result per hypothesis, recorded in §6 §5. If no Phase 1 hypotheses are on record, stop and refuse to continue per §4.3 architectural rule 1 (Hypothesis-before-Analysis).

### Phase 4: Recommendations

Map Phase 3 findings to verdicts, then optionally cross-check downstream conversion signal in Salesforce — only when the window produced any interested replies.

1. **For each campaign in the ranked table, assign the §3.5 verdict** (`TOP PERFORMER`, `SCALE`, `TEST MORE`, `MONITOR`, `UNDERPERFORM`) per the assignment rules. Record campaign ID / verdict / attribution variable in §6 §5 Attribution Analysis. No free-form narrative verdicts — use the five fixed labels only.
2. **`run_soql_query` (optional)** — only if §6 §6 Next Iteration needs downstream conversion signal AND the campaign produced interested replies. SOQL shape:

   ```
   SELECT Id, StageName, Campaign_Source__c FROM Opportunity WHERE Campaign_Source__c = :campaign_name AND CreatedDate >= :phase2_start
   ```

   Preflight: before running the attribution SOQL, verify the custom field exists on the Opportunity sObject via a FieldDefinition metadata query. If Campaign_Source__c is absent from the org schema, skip the attribution query and note "attribution skipped — custom field missing" in the report (BC-5797 factual-anchor rule: verify field existence before running a query that assumes it). If the Salesforce MCP is unavailable, skip entirely — Phase 4 does not block on SF.
3. **Order §6 §6 recommendations by verdict priority**: `SCALE` first, `UNDERPERFORM` second, `TEST MORE` third, `MONITOR` fourth, `TOP PERFORMER` observational last. The priority order is fixed by §3.5 — do NOT reorder.
4. **End Phase 4 with the mandatory campaign-debrief handoff prompt** (verbatim per §4.4): *"Analysis complete. To capture these learnings so they compound into future campaigns, run the campaign debrief workflow."* Phase 4 is not complete until the operator confirms the handoff.

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
