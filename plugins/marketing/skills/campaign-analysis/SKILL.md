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

**Benchmark set selection.** The workspace → benchmark table mapping happens automatically from Gate 2 (b2c vs b2b), so no independent operator choice is required for the default path. As the final §2 gate, confirm the selected benchmark set with the operator via AskUserQuestion — surface the Gate 2 workspace name and the numeric thresholds (from §3.3) in the confirmation prompt so the operator sees exactly what will be applied. If the operator overrides a threshold for a justified reason (e.g., a known seasonal dip, a deliverability incident window, a freshly-warmed inbox pool), record the override — threshold name, new value, operator's stated reason — so the report-writing step (Procedure 1 step 7) can include the override in the final report's §6 §1 Quick Health Check. All four §2 gates resolve before Procedure 1 begins; Procedure 4 is pure mechanical lookup against the Gate 4 output with no runtime operator prompt. Blank overrides are rejected here in §2 (prompt the operator for a reason via AskUserQuestion) — the reason is what lets the next analysis run calibrate.

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

This section turns the §3 Methodology + §5 MCP Tool Reference into four concrete procedures that a subagent follows end-to-end. Procedure 1 is the happy path — every analysis run starts here. Procedures 2 and 3 are conditional side-effects triggered by what Procedure 1 surfaces. Procedure 4 is a mechanical lookup every run performs before Phase 3 resolves verdicts. Preconditions, steps, and error handling are explicit on every procedure so a fresh agent can execute any of them without re-reading the rest of the skill. Report-section cross-references use the established `§6 §N [section name]` style — `§6 §1 Quick Health Check` means the report's first section as defined in §3.4, not a subsection of this Operational Runbook itself.

### Procedure 1: Standard post-campaign analysis run

**When:** operator invokes the skill and the §2 gates (marketing-context check, workspace + entity detection, time-range confirmation, benchmark set confirmation) have all resolved. This is the entry point for every run.

**Preconditions:** all four §2 gates satisfied. `get_active_workspace_info` has not yet been called — Procedure 1 owns that availability probe.

**Steps:**

1. **Availability check.** Call `get_active_workspace_info` on the §2 Gate 2 workspace (per §5 Phase 2 step 1). If the response workspace ID does not match the Gate 2 operator answer, stop and surface the mismatch verbatim — do NOT attempt partial analysis against the wrong workspace, and do NOT mutate workspace state (no `set_active_workspace` call). The operator fixes the pointer out-of-band and re-runs.
2. **Phase 1 Hypothesis.** Prompt the operator via `AskUserQuestion` for 1–3 expectations, one question per expectation (BC-5761 one-question-per-field rule). Record verbatim so Phase 3 can label each CONFIRMED / PARTIAL / REJECTED against actual data. If the operator skips this step, refuse to continue — §3.2 Phase 1 is a hard gate with no degrade path.
3. **Run Procedure 4** to lock the benchmark set (b2b vs b2c per workspace) before Phase 3. Procedure 4 must complete before step 5 begins.
4. **Phase 2 Data Collection.** Execute §5 Phase 2 steps 2–7 in sequence — step 1 of §5 Phase 2 is the same `get_active_workspace_info` availability probe Procedure 1 step 1 already ran, and the skill guarantees no workspace mutation between them, so re-calling is deterministically redundant. Order: `list_workspace_stats` → `list_campaigns` + client-side date filter → `get_campaign_stats` per campaign → `get_leads_analytics` → `list_sender_emails` → `get_replies_analytics`. Apply the §3.2 Phase 2 statistical-significance floor: if the window returns < 500 sent OR < 7 days, flag the run as sub-floor and proceed — every Phase 4 verdict will auto-map to `TEST MORE` regardless of raw metric values.
5. **Phase 3 Analysis.** Rank all Phase-2-returned campaigns by Interested Rate descending. Compute per-variable attribution for the top 2 and bottom 2 using the §3.1 5 Core Variables (orthogonality rule applies — each attribution resolves to exactly one variable). Build the Google-vs-Microsoft, weekday-vs-weekend, and title-seniority cohort comparisons. Flag any 2x+ differential with comparable volume as a hard signal. Label each Phase 1 hypothesis CONFIRMED / PARTIAL / REJECTED against the data. If any Phase 3 finding meets the Procedure 2 trigger criteria, run Procedure 2 before step 6.
6. **Phase 4 Recommendations.** Assign each campaign a §3.5 verdict (`TOP PERFORMER`, `SCALE`, `TEST MORE`, `MONITOR`, `UNDERPERFORM`) via the assignment key. If the run is sub-floor (per step 4), force all verdicts to `TEST MORE`. Optionally run Salesforce `run_soql_query` for pipeline attribution per §5 Phase 4 step 2 — skip if the Salesforce MCP is unavailable or if `Campaign_Source__c` is missing from the org schema (note "attribution skipped" in the report).
7. **Write the report artifact.** Render all 6 §3.4 sections to `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md`. Use `{entity}` = `brite-nites` | `brite-supply` | `brite-labs` per §2 Gate 2. Use today's UTC date for `{YYYY-MM-DD}`. Do not omit any of the 6 sections unless the run was sub-floor (in which case degrade to a `TEST MORE` stub per §3.4).
8. **Mandatory campaign-debrief handoff.** End the run with the §4 Cross-skill boundaries handoff clause verbatim: *"Analysis complete. To capture these learnings so they compound into future campaigns, run the campaign debrief workflow."* The run is not complete until the operator confirms the handoff.

**Error handling:**

- **Step 1 availability failure** → stop and report the server name + a pointer to `/marketing:setup-email-bison`. Do not attempt partial analysis.
- **Step 1 workspace mismatch** → stop and surface to operator. Procedure 1 does NOT mutate workspace state; operator fixes the pointer out-of-band and re-runs.
- **Step 2 hypothesis skip** → refuse to continue. No degrade path per §3.2 Phase 1 hard gate. This is the single hardest gate in the skill.
- **Step 4 sub-floor (< 500 sent OR < 7 days)** → proceed with the run, flag as sub-floor in the report header, force all Phase 4 verdicts to `TEST MORE`. Do not refuse; small samples are analyzable, just not verdict-definitive.
- **Step 4 Phase 2 mid-iteration failure** (permission error, empty campaign list) → stop and report; do not attempt Phase 3 on partial data.
- **Step 6 Salesforce unavailable** → skip pipeline attribution, note "attribution skipped — SF unavailable" in §6 §6 Next Iteration Recommendations.
- **Step 6 `Campaign_Source__c` missing** → skip pipeline attribution, note "attribution skipped — custom field missing" in the report (BC-5797 factual-anchor rule: verify field existence before running a query that assumes it).
- **Step 8 operator declines handoff** → note declination in the run log and exit; the report artifact itself is still valid and readable.

**Handoff:** MANDATORY → BC-5830 campaign-debrief (step 8). On operator confirmation, the skill transitions to campaign-debrief with the report path as input. Phase 4 — and Procedure 1 — is not complete until handoff is confirmed.

### Procedure 2: Infrastructure-triggered deliverability-audit handoff

**When:** during Procedure 1 Phase 3 Analysis (step 5), the Infrastructure variable surfaces as the dominant attribution for at least one underperformer. The signal cluster is specific.

**Preconditions:** Procedure 1 has completed at least through step 5. At least one of the following Infrastructure signals must be present:

- Bounce Rate in the §3.3 Critical band (> 5%) for any ranked campaign, OR
- A 2x+ differential between Google Workspace senders and Microsoft 365 senders on Reply Rate with comparable volume (both cohorts ≥ 100 sent), OR
- Spam-complaint signals surfaced in §6 §3 Infrastructure Analysis (any non-zero spam-complaint count).

**Steps:**

1. **Surface the Infrastructure attribution** explicitly in the report's §6 §3 Infrastructure Analysis and §6 §5 Attribution Analysis — name the triggering signal verbatim (e.g., "Bounce Rate 7.2% — Critical band" or "Google cohort 2.4x Microsoft on Reply Rate, comparable volume ≥ 100 sent each").
2. **Prompt the operator** via `AskUserQuestion`: *"Infrastructure signal detected: {triggering signal}. This looks like a deliverability issue. Hand off to deliverability-audit (BC-2719) for SPF/DKIM/DMARC + reputation investigation?"* Offer two options: "Yes, hand off" / "No, continue without".
3. **On operator confirmation,** hand off to BC-2719 with the triggering signal + affected sender IDs + the bounce/reply cohort data as input.
4. **On operator decline,** continue Procedure 1 normally from step 6. Note the declination + the signal in the run log so the next analysis run has precedent.

**Error handling:**

- **No Infrastructure signal detected** → Procedure 2 does not fire. This is the correct no-op path, not an error.
- **Multiple Infrastructure signals simultaneously** → surface all of them in step 1; a single handoff prompt covers all signals.
- **BC-2719 skill not installed** → note "deliverability-audit skill not installed — manual deliverability review recommended" in the report's §6 §6 Next Iteration Recommendations, continue Procedure 1 normally.

**Handoff:** CONDITIONAL → BC-2719 deliverability-audit (step 3). Fires at most once per analysis run.

### Procedure 3: MSPA ITERATE-mode trigger on request

**When:** after Procedure 1 completes (report artifact written, handoff prompt delivered), the operator asks a follow-up question about what to test next within the same session.

**Preconditions:** Procedure 1 has completed through step 8. The operator asks a variant of "what should we test next?" / "what's the next hypothesis?" / "what should we iterate on?"

**Steps:**

1. **Confirm the report is non-sub-floor.** If the Procedure 1 run was sub-floor (all verdicts forced to `TEST MORE`), tell the operator: *"The analysis window didn't reach the statistical-significance floor (500 sent AND 7 days). Run a longer window before iterating — MSPA needs non-`TEST MORE` verdicts to feed ITERATE mode."* Refuse handoff.
2. **Extract the §6 §6 Next Iteration Recommendations block as-is** from the Procedure 1 report artifact, preserving verdict labels (`TOP PERFORMER` / `SCALE` / `TEST MORE` / `MONITOR` / `UNDERPERFORM`) and the §3.5 priority ordering. MSPA ITERATE reads the verdict labels and applies its own filter logic — observational rows (`TOP PERFORMER` / `MONITOR`) are typically skipped, `UNDERPERFORM` rows are kill decisions (not iterations), and the actionable hypotheses are the `SCALE` + `TEST MORE` rows. Procedure 3 does not pre-filter; §4's contract specifies "the §6 §6 block" as the full input.
3. **Hand off to BC-5829 in ITERATE mode** with the full §6 §6 block as input. MSPA ITERATE owns test design from here; this skill does NOT design tests.

**Error handling:**

- **Sub-floor run (step 1 refuses)** → tell operator to re-run analysis with a larger window first. Do not proceed to handoff.
- **Block contains no actionable iteration hypotheses** (pre-handoff UX guardrail: all rows are `TOP PERFORMER` / `MONITOR` observational or `UNDERPERFORM` kill decisions, no `SCALE` / `TEST MORE`) → refuse handoff and tell operator: *"No iteration hypotheses in this run — top performers need no change, underperformers need kill decisions via `campaign-orchestration`, not test iteration. Wait for a run that produces at least one `SCALE` or `TEST MORE` verdict before iterating."* The §4 contract still says "pass the full block," but passing a block MSPA can't act on wastes the operator's time.
- **BC-5829 skill not installed** → surface the full §6 §6 block verbatim in chat, tell operator to run MSPA manually when the skill is available.

**Handoff:** ON-REQUEST → BC-5829 message-market-fit (step 3), ITERATE mode only.

### Procedure 4: Per-entity benchmark switch

**When:** Procedure 1 step 3, after all four §2 gates have accepted (including Gate 4's benchmark confirmation with any operator overrides + stated reasons captured). Runs before Phase 3 Analysis so verdict mapping in Procedure 1 step 6 has a locked scoreboard.

**Preconditions:** All four §2 gates resolved. Gate 4 output is available — either the workspace-keyed default benchmark set OR an operator-overridden variant with the override reason recorded during §2.

**Steps:**

1. **Read the locked benchmark set** from Gate 4's output. If the workspace is `emailbison-b2b`, the default is §3.3's b2b table (Reply > 1% Healthy / Interested > 25% of replies Healthy / Bounce < 3% Healthy). If the workspace is `emailbison-personal`, the default is §4's b2c table (Reply > 0.5% / Interested > 15% of replies / Bounce < 3%). Any overrides captured in §2 replace the corresponding default thresholds.
2. **Lock the benchmark set** as the read-only scoreboard for the rest of Procedure 1. Every §3.3 comparison and every §3.5 verdict assignment in Procedure 1 step 6 reads from this locked set. No further operator interaction in Procedure 4 — the confirmation already happened in §2.
3. **If the workspace is `emailbison-personal`,** attach the "b2c benchmarks uncalibrated — initial targets" footer to the report's §6 §1 Quick Health Check per §4's calibration caveat. Procedure 4 owns attaching this footer; the report template does not add it automatically.

**Error handling:**

- **Gate 4 output missing (§2 did not complete normally)** → Procedure 1 should not have reached step 3 in this state; this is a skill-state bug. Stop and report.
- **Workspace mismatch between Gate 2 and Gate 4** (shouldn't happen — both are captured in the same §2 pass) → stop and re-invoke §2. The skill analyzes ONE workspace per run (per §2's "workspace + entity detection" rule).

**Handoff:** internal to Procedure 1. Not a cross-skill handoff.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | All four §2 gates resolved before Procedure 1 begins (marketing-context check → workspace/entity → time-range → benchmark set + any overrides with stated reasons); Phase 1 Hypothesis captured (1–3 expectations) before any Phase 2 data pull; availability check runs once at Procedure 1 step 1 and is not redundantly re-called in Phase 2; report written to `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md` with all 6 §3.4 sections rendered; every ranked row in §6 §2 carries exactly one §3.5 verdict label from the fixed 5; every attribution row in §6 §5 resolves to exactly one §3.1 Core Variable (orthogonality holds); exact §3.3 / §4 benchmark thresholds applied (no rounding); statistical-significance floor enforced (sub-floor runs auto-map every verdict to `TEST MORE`); Infrastructure signals (bounce > 5% OR 2x+ Google/Microsoft disparity OR spam-complaints) correctly trigger Procedure 2's BC-2719 handoff prompt; Procedure 1 ends with the verbatim mandatory BC-5830 debrief handoff clause. |
| 7-9 | Mostly excellent with one gap — e.g. Phase 1 captured but only 1 expectation on record; cohort analysis missing one dimension (weekday split absent but Google/Microsoft present); §6 §4 sentiment table present but `interested` sub-count absent; benchmark override recorded in §2 but not propagated into §6 §1 Quick Health Check at report-write time; availability check runs once but `set_active_workspace` mutation occurred despite Procedure 1 step 1's explicit rule; a 1.7x cohort differential flagged as "hard signal" (threshold is 2x+, this is noise per §3.2 Phase 3). |
| 4-6 | Functional but missing structural elements — e.g. §2 Gate 4 surfaced but operator confirmation not recorded; verdict assigned to a ranked row but attribution variable absent from §6 §5; b2c run (`emailbison-personal`) emitted without the "b2c benchmarks uncalibrated — initial targets" footer per §4 calibration caveat; report written to wrong path (missing entity prefix, wrong date format, or pluralized filename); Phase 1 hypotheses captured but not labeled CONFIRMED / PARTIAL / REJECTED in §6 §5 against actual data; sub-floor run proceeded but report header did not flag sub-floor status. |
| 1-3 | Hard failure — any ONE of these drops the run to 1-3: Phase 1 Hypothesis skipped (narrative-retrofit ban violated per §3.2 Phase 1 hard gate); subjective verdict language ("okay", "solid", "meh", "needs work") in place of the five §3.5 labels; invented tool name not present in `email-bison.md` Tool inventory; mandatory BC-5830 debrief handoff missing from Procedure 1 step 8; benchmark numbers invented, rounded, or altered without a recorded §2 override reason (§3.3 / §4 anchors violated); orthogonality rule violated (observation attributes to 2+ variables on one row instead of being split); sub-floor run produced any verdict other than `TEST MORE`; availability probe skipped entirely (Procedure 1 step 1 never ran); `set_active_workspace` mutation called by the skill (Procedure 1 step 1 explicitly bans this). |

---

## Anti-Slop Guardrails

Base guardrails (shared across marketing plugin) + skill-specific hard failures. Skill-specific rules are phrased as "Do not X" because they are enforced as validation gates, not style preferences.

**Base guardrails:**

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class", "game-changing", "cutting-edge") in the report narrative sections (§6 §3 Infrastructure Analysis narrative, §6 §4 Reply Sentiment Analysis narrative, §6 §6 Next Iteration Recommendations rationale).
- Do not fabricate statistics, case studies, testimonials, or proof points — every number in the report must trace to a Phase 2 data-collection tool call. If the Phase 2 pull was empty for a metric, report "no data" rather than invent a value.
- Do not ignore `docs/marketing-context.md` — entity, workspace, and benchmark set all derive from it before any operator input per §2 Gate 1.
- Do not recommend tools the plugin does not have access to — §5 MCP Tool Reference is the authoritative scope; no hallucinated EB tool names, no SF tools outside `run_soql_query`.

**Skill-specific hard failures (validation-gated — drop the run to §7 1-3 band):**

- **Do not skip the Phase 1 Hypothesis.** §3.2 Phase 1 is a hard gate with no degrade path. If the operator does not submit 1–3 expectations before Phase 2 begins, refuse to continue. Running Phase 3 Analysis against data without prior hypotheses is narrative retrofit — the single failure mode this skill exists to prevent.
- **Do not use subjective verdict language.** The five §3.5 labels (`TOP PERFORMER`, `SCALE`, `TEST MORE`, `MONITOR`, `UNDERPERFORM`) are the only permitted verdict tokens in §6 §2 and §6 §5. Words like "okay", "solid", "meh", "pretty good", "needs work", "strong", "weak" are hard failures in those sections — they produce the narrative drift the verdict taxonomy exists to replace.
- **Do not skip the mandatory BC-5830 campaign-debrief handoff.** Procedure 1 is not complete until the operator confirms the handoff. The per-campaign report artifact is disposable; durable learnings belong in the compounding knowledge base, and `campaign-debrief` is the skill that promotes them there. A run that writes a report and ends without the handoff prompt has broken the loop.
- **Do not emit a non-`TEST MORE` verdict on a sub-floor run.** Below 500 sent OR below 7 days elapsed, every §3.5 verdict auto-maps to `TEST MORE` regardless of how the raw numbers look. Small samples lie; the skill's job is to refuse to pretend otherwise. Per §3.2 Phase 2 and §4 architectural rule 2.
- **Do not attribute an observation to two or more §3.1 Core Variables on a single row.** The orthogonality rule: every observation in §6 §2 and §6 §5 resolves to exactly one of `Offer` / `Message` / `Segment` / `Infrastructure` / `Timing`. If an observation appears to span two (e.g., "low replies on Fridays from senior titles"), split it into two separate rows — one attribution to Timing, one to Segment. Mixed attributions are a narrative slip; §7 1-3 band.

---

## Behavioral Tests

Eight scenarios covering the core paths. Structured assertions + fixtures live in `evals/evals.json` alongside this file. Scenario IDs match the `evals.json` entries for 1:1 traceability. Tier 1 scenarios assert on free output — no tool calls required. Tier 2 scenarios require file reads or MCP calls to verify.

### Tier 1 — Free assertions (no tool calls needed)

- **`hypothesis-first-gate`** — Given an operator invocation with workspace + time-range selected but no hypothesis submitted, the skill's first response asks for 1–3 expectations via AskUserQuestion before any Phase 2 tool call fires. No `list_workspace_stats` or other data-collection call is made until the operator answers at least one hypothesis. If the operator explicitly declines to submit, the skill refuses to continue (per §8 skill-specific hard failure).
- **`sub-floor-auto-test-more`** — Given a Phase 2 pull returning 300 sent over 3 days, every verdict in the rendered §6 §2 Segment Performance Ranking resolves to `TEST MORE` regardless of Reply Rate / Interested Rate / Bounce Rate values. Report header carries a "sub-floor run" flag in §6 §1 Quick Health Check.
- **`subjective-verdict-self-correct`** — Given a draft §6 §2 row containing "solid performance, keep running" (subjective phrasing), the skill self-corrects to a §3.5 label (`SCALE` or `MONITOR` depending on benchmark comparison) before report write. Output `§6 §2` contains zero non-§3.5-label verdict tokens.
- **`debrief-handoff-required`** — Given a successful Procedure 1 run through Phase 4, the skill's final response contains the verbatim BC-5830 handoff clause: *"Analysis complete. To capture these learnings so they compound into future campaigns, run the campaign debrief workflow."* The run is not marked complete until the operator confirms the handoff.
- **`orthogonality-split`** — Given a Phase 3 finding worded as "low replies on Fridays from senior titles" (spans Timing + Segment), the rendered §6 §5 Attribution Analysis contains two separate rows — one attributing to `Timing`, one attributing to `Segment` — not a single combined row. §8 orthogonality guardrail.
- **`invented-tool-name-refused`** — Given operator pressure to call a non-existent EB tool (e.g., "use `list_campaigns_by_date` with these dates"), the skill refuses and points to `list_campaigns` + client-side filter per §4.1 table + `email-bison.md` §Known gotchas. No `call_api` with a fabricated tool name.

### Tier 2 — Tool-assisted (requires file read or MCP call)

- **`marketing-context-entity-routing`** — Given `docs/marketing-context.md` specifying `primary_entity: brite-supply`, the skill picks `emailbison-b2b` as the workspace (not `emailbison-personal`), applies the §3.3 b2b benchmark table, and does NOT attach the "b2c benchmarks uncalibrated" footer to §6 §1. If the doc is absent, the skill warns with the BC-5824 precedent message + surfaces the entity prompt via AskUserQuestion. Read tool call on `docs/marketing-context.md` fires during Gate 1.
- **`availability-probe-first`** — Given Procedure 1 invocation, the first MCP call is `get_active_workspace_info` on the Gate-2-detected workspace — before any `list_workspace_stats`, `list_campaigns`, or other data-collection tool. If the probe returns a workspace ID that does not match the Gate 2 operator answer, the skill stops and reports the mismatch without calling any further EB tools.
