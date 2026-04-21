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

Three frameworks govern this skill: the **5 forcing functions** (lateral-thinking prompts from `plugins/marketing/references/creative-thinking-models.md`), the **Asymmetry Score** (a weighted 6-dimension rubric that turns an angle into a reproducible number), and **shelf-life decay** (every creative angle has a half-life, and the alpha disappears the moment a competitor sees the same signal). The skill sits on Brite's barbell positioning: roughly 90% of outbound ships through proven patterns via `outbound-playbook`, `email-copywriting`, and `/marketing:launch-campaign`; the 10% experimental slice runs here. Commodity angles belong in the 90%, not this skill.

### Quick Mode — default path

Quick Mode runs four ordered steps, produces 3–5 angles, and takes roughly one research turn plus synthesis. It is the right pick for initial exploration, for prospects without a situation-mining artifact, and for operators who want a shallow pass before committing research budget.

**Step 1 — Five parallel `WebSearch` queries.** Single turn, five tool calls, substitute `{{company_name}}`, `{{domain}}`, and (when known) `{{industry}}` before executing:

1. Blog content — `site:{{domain}} blog`
2. Reviews / complaints — `{{company_name}} reviews OR complaints OR problems`
3. Competitors — `{{company_name}} competitors OR alternatives`
4. Regulation / compliance — `{{company_name}} {{industry}} regulation OR compliance OR deadline`
5. Hiring — `{{company_name}} careers OR hiring`

On `WebSearch` rate-limit or transient failure for any single query, retry once with exponential backoff. If still failing, proceed with the remaining queries and mark the missing source in the output artifact — the missing signal degrades Evidence Density scoring in §3 Asymmetry Score.

**Step 2 — Extract signal clusters.** A signal cluster is 2+ independent data points that together reveal something non-obvious. **Single data points are noise, not signals.** The 2-point minimum is a hard rule — §8 Anti-Slop will flag any cluster containing only one data point, and the Evidence Density dimension bottoms out at Low. Data points inside a cluster must come from different sources (a blog post and a job posting count as two; two blog posts on the same site count as one).

**Step 3 — Apply the 5 forcing functions** from `plugins/marketing/references/creative-thinking-models.md`. Use the exact names from that file's §1–§5 headings — no paraphrases, no reordering, no drift. Each function takes a signal cluster as input and produces a candidate angle as output; not every function yields a winner for every cluster, and that is expected.

1. **Inversion (Munger).** Ask what would guarantee this prospect never buys, then invert each failure mode into an angle.
2. **Adjacent Transfer.** Identify a different industry that solved the same underlying problem and transfer the mechanism — not the surface tactic.
3. **Timing Arbitrage.** Surface a future event the prospect will feel urgency about in 1–6 months using public data that predicts it.
4. **Specificity Escalator.** Take an initial angle and escalate through 4 levels (Generic → Segment → Specific → Hyper-Specific) until it feels uncomfortably personal.
5. **Ecosystem Gap Analysis.** Map the prospect's tech stack, find handoff points between tools, and pitch the pain that lives in the seams.

See `plugins/marketing/references/creative-thinking-models.md` for worked examples, common mistakes, and the "combining functions" table (the most powerful angles use 2+ functions). The names above are load-bearing — BC-5797's factual-anchor rule applies, and any drift from these exact strings (e.g. "Munger Inversion" instead of "Inversion (Munger)") is a §8 Anti-Slop violation.

**Step 4 — Generate 3–5 angles, score each with the §3 Asymmetry Score, and emit via the §4 output artifact shape.** Every angle attributes to at least one forcing function; angles that cite 2+ functions are more likely to land in the ALPHA or PROMISING band per §3 Verdict mapping.

### Deep Mode — requires situation-mining output less than 14 days old

Requires a situation-mining artifact at `docs/research/situations/{domain}-{YYYY-MM-DD}.md` less than 14 days old. §2 Gate 3 already halted if this prereq was not met — do not re-probe here. Deep Mode supplements Quick Mode's signal base with seven additional queries, adds worldview-conflict analysis against the situation-mining artifact, and produces 5–8 angles with mandatory shelf-life metadata on every ALPHA and PROMISING row.

**Step 1 — Load the situation-mining artifact** from `docs/research/situations/{domain}-{YYYY-MM-DD}.md`. Parse the frontmatter (entity, vertical, confidence, `sf_enriched`, `internal_signals`) and the body's §Raw Data, §Situations, and §Diagnostic Messages sections. The worldview inferences in §Situations are the input to Step 3's conflict analysis — do not skip them.

**Step 2 — Run seven additional `WebSearch` queries.** These supplement Quick Mode's five for 12 total. Substitute `{{company_name}}`, `{{domain}}`, `{{industry}}`, and `{{year}}` before executing:

1. G2 / Trustpilot reviews — `{{company_name}} site:g2.com OR site:trustpilot.com`
2. Events / conferences — `{{company_name}} speaking OR keynote OR conference`
3. Regulation deep — `{{industry}} regulation {{year}} deadline OR rule OR enforcement`
4. Partnerships — `{{company_name}} partnership OR integration OR alliance`
5. Senior hiring — `{{company_name}} "VP" OR "Chief" OR "Head of" LinkedIn`
6. Financial signals — `{{company_name}} funding OR revenue OR layoff OR earnings`
7. Reddit / HN sentiment — `{{company_name}} site:reddit.com OR site:news.ycombinator.com`

**Step 3 — Worldview conflict analysis.** Cross-reference the situation-mining §Situations inferences with the deep signals pulled in Step 2. The richest angles live in contradictions: a company publicly claims "AI-first" while actively hiring 50 manual data-entry roles; a founder posts thought-leadership on work-life balance while the careers page lists "scrappy, hours-agnostic" as a cultural must; a CEO pitches sustainability while the partnerships page just added a petrochemical integration. Each contradiction is a gap you can address — but frame as a curiosity opening ("Noticed you say X while hiring for Y — how are you thinking about that bridge?"), never as a gotcha. **Minimum 1 worldview conflict per Deep Mode output.** **Never weaponize contradictions** — the operator's job is to extend curiosity, not expose inconsistency.

**Step 4 — Cross-reference `plugins/marketing/references/hidden-signals-library.md`** for known signal patterns in the prospect's industry. For Nites or Labs prospects, preferentially query the Brite-entity tables (Entertainment Venues, Landscape/Hardscape Contractors, HOAs/Property Management — added on top of the 7 upstream industries per BC-5823 port). The library names shelf-life ratings per signal; use those ratings as the starting estimate for Step 6's shelf-life metadata before refining.

**Step 5 — Generate 5–8 angles** using all 5 forcing functions from Quick Mode Step 3 plus the worldview conflicts surfaced in Step 3. Angles combining 2+ forcing functions are preferred; angles combining a forcing function with a worldview conflict are the highest-asymmetry candidates. Attribute each angle to its contributing functions and (where applicable) the specific contradiction it rides.

**Step 6 — Score every angle with the §3 Asymmetry Score** and attach mandatory shelf-life metadata on every ALPHA and PROMISING row. Shelf-life metadata has three sub-fields (estimate, decay trigger, refresh date) per the §3 Shelf-life requirements subsection below. A score without shelf-life on an ALPHA or PROMISING angle is a hard failure — §8 Anti-Slop will refuse the artifact.

### Asymmetry Score

Every angle gets a reproducible number. The score weights Novelty and Evidence Density highest because they are the two dimensions that most often separate alpha from noise; Timing matters less only because the other five already constrain it; Downside carries the lowest weight because the worst case for a well-framed creative angle is usually "they ignore the email." Formula:

```
Score = (Novelty*2 + Evidence*2 + Timing*1.5 + Simplicity*1 + ShelfLife*1 + Downside*0.5) / 8
```

Each dimension scores on a 1–10 band using the per-dimension rubric below.

- **Novelty (2x weight).** Low (1–3) = angle appears in Clay templates or common playbooks. Medium (4–6) = uncommon but discoverable. High (7–10) = no one is using this angle.
- **Evidence Density (2x weight).** Low (1–3) = single data point, high speculation. Medium (4–6) = 2–3 data points, moderate inference. High (7–10) = 4+ data points, strong inference chain.
- **Timing Urgency (1.5x weight).** Low (1–3) = evergreen, no time pressure. Medium (4–6) = seasonal or cyclical. High (7–10) = deadline-driven, narrow window.
- **Execution Simplicity (1x weight).** Low (1–3) = custom tooling needed. Medium (4–6) = manual research. High (7–10) = build list in under 1 hour.
- **Shelf Life (1x weight).** Low (1–3) = under 1 month. Medium (4–6) = 3–6 months. High (7–10) = 6+ months.
- **Downside Cap (0.5x weight).** Low (1–3) = risk of negative brand perception. Medium (4–6) = neutral worst case. High (7–10) = worst case = they ignore the email.

A reviewer reading a finished artifact can apply this rubric and arrive at the same score the skill assigned — that is the decidability guarantee. If two reviewers disagree by more than 1.0 on a total score, the angle's evidence chain is underspecified and §7 Rubric drops the run a band.

### Verdict mapping

Every scored angle maps to exactly one verdict tier. The bounds are fixed — do not round, do not split a band.

- **Score 8.0+ → ALPHA.** Test immediately. Small batch (50–100 prospects). Measure response rate before scaling.
- **Score 6.0–7.9 → PROMISING.** Refine evidence density or timing, then test.
- **Score 4.0–5.9 → INTERESTING.** Too creative for cold outbound. Redirect to content as a thought-leadership piece.
- **Score below 4.0 → COMMODITY.** Discard entirely. Use standard campaign ideation via `outbound-playbook` instead.

The verdict labels (`ALPHA`, `PROMISING`, `INTERESTING`, `COMMODITY`) are the only permitted tokens in the output artifact's verdict column — no "pretty strong," no "maybe worth a shot," no hedged prose substitutes. §8 Anti-Slop will refuse subjective verdicts.

### Shelf-life requirements

Every **ALPHA** and **PROMISING** angle MUST include three sub-fields. Missing any of the three drops the run to §7 Rubric 1–3 band; a scored ALPHA or PROMISING row without shelf-life metadata is a hard failure.

1. **Shelf life estimate** — cite a decay category from `plugins/marketing/references/shelf-life-patterns.md`. The five categories are **Regulatory / Deadline**, **Competitive Move**, **Data Insight**, **Industry Pattern**, and **Structural**. Use the category's typical shelf-life band as the starting estimate, then adjust based on the cross-check section of that reference (Clay templates, LinkedIn thought-leaders, conference talks, blog posts, competitor outreach).
2. **Decay trigger** — one sentence naming the specific event that would kill this angle. Examples: "when the first competitor blog post on SimilarWeb+tariff correlations publishes" or "when CMS finalizes the Q3 2026 rate update" or "when a Clay template for food-service permit monitoring ships." A generic trigger ("when it becomes common knowledge") is insufficient — name the event.
3. **Refresh date** — a specific ISO date to re-evaluate the angle. Default: generation date + 90 days, or shelf-life expiry, whichever is sooner. Example: `2026-07-01`. Round to the nearest quarter-end only when the decay category is Structural (12+ months).

INTERESTING and COMMODITY verdicts do NOT require shelf-life metadata — they are either redirected to content workflows (INTERESTING) or discarded (COMMODITY), so shelf-life is irrelevant to the decision. Only the alpha-bearing tiers carry the metadata burden, because only the alpha-bearing tiers produce angles the operator will ship.

---

## Brite Implementation

This section translates §3 Methodology into Brite's concrete stack — which MCP server, which tool, which rule, which repo. Every rule cites its source (ADR, integration guide, or sibling skill) so a skill reader can trace the claim.

### Tools this skill calls

| What the skill needs to do | MCP / tool | Reaches | Reason |
|---|---|---|---|
| Signal research (5 Quick + 7 Deep queries) | `WebSearch` | Public web | §3 Quick/Deep query patterns; no availability check — `WebSearch` is always on |
| Deep-read a single page when the search snippet is insufficient | `WebFetch` | Public web | Backup only; use sparingly to avoid burning context |
| Optional ALPHA cross-check on an existing Salesforce Account | Salesforce MCP (`run_soql_query`) | `brite-salesforce` production org | ADR 2a — SF is CRM system of record; fires only when a generated ALPHA angle targets a domain that may already exist as an Account. Availability probe first |
| Load situation-mining artifact (Deep Mode prereq) | `Read` + `Glob` | Local `docs/research/situations/` | §2 Gate 3 verified the artifact exists and is < 14 days old; Deep Mode Step 1 re-reads it for use |
| Emit output artifact | `Write` | Local `docs/research/angles/{domain}-{YYYY-MM-DD}.md` | §6 runbook output shape |

The wildcard form `mcp__plugin_marketing_salesforce__*` in `allowed-tools` is used because the optional SF cross-check would call `run_soql_query` against multiple SOQL object types (User for the probe, Account for domain lookup, ActivityHistory or Opportunity for evidence enrichment) depending on what the angle targets — narrower cherry-picking would couple the frontmatter to a SOQL object taxonomy that will evolve. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) §MCP Tool Reference for the availability probe pattern — the canonical check is `run_soql_query` with `SELECT Id FROM User LIMIT 1` (verified per BC-5534 findings §Q1; `get_username` is NOT a valid liveness check because it reads the local auth store without contacting Salesforce).

### Brite-entity signal-library additions

Per [`plugins/marketing/references/hidden-signals-library.md`](../../../references/hidden-signals-library.md), Brite adds industry tables on top of the 7 upstream SaaS-heavy industries — **Entertainment Venues** (Labs), **Landscape / Hardscape Contractors** (Supply boundary), and **HOAs / Property Management** (Nites) — each keyed to handbook-canon verticals with shelf-life ratings per signal. Deep Mode Step 4 preferentially queries these Brite-entity tables for Nites/Labs prospects rather than leaning on the upstream SaaS rows. The handbook 23-vertical taxonomy (6 Active + 8 Exploring + 9 Future, Nites + Labs only) governs which rows are in scope; Supply verticals are excluded per BC-5823 precedent and the handbook-canon rule that Supply is out of scope for outbound skills.

### Architectural rules that apply

- **Every angle requires a signal cluster (2+ data points).** Single data points are noise, not signals. Source: §3 Quick Mode Step 2; enforced by §8 Anti-Slop.
- **Every score requires a cited evidence chain.** The Asymmetry Score is derived from named data points with source URLs. Score-without-evidence is a §7 Rubric 1–3 hard failure. Source: §3 Asymmetry Score subsection.
- **Worldview contradictions are framing tools, not gotchas.** Never weaponize a contradiction against the prospect — the operator's job is to extend curiosity, not expose inconsistency. Source: §3 Deep Mode Step 3; enforced by §8 Anti-Slop.
- **ALPHA and PROMISING angles carry mandatory shelf-life metadata.** Three sub-fields (estimate, decay trigger, refresh date), each cited against `plugins/marketing/references/shelf-life-patterns.md`. Source: §3 Shelf-life requirements.
- **Deep Mode halts on stale situation-mining — no graceful degrade.** §2 Gate 3 is the hard halt; this skill never silently falls back to Quick Mode when Deep Mode's prereq fails. Source: §2 Gate 3.

### Cross-skill boundaries

**Hands off to:**

- **[BC-5825](https://linear.app/brite-nites/issue/BC-5825) `email-copywriting`** — fires when the operator selects an ALPHA angle plus an offer tier. `email-copywriting` receives the tuple `{angle, situation-mining-artifact-if-deep, offer-tier}` and emits the Email-Bison-formatted subject + body that `/marketing:launch-campaign` consumes.
- **[BC-5829](https://linear.app/brite-nites/issue/BC-5829) `message-market-fit` / MSPA** — fires when the operator wants to populate the A (angle) dimension of an MSPA experiment matrix. The verdict-mapped angle list is the input.
- **Content workflows (no skill yet)** — fires for INTERESTING angles. Brite does not have a content-workflow skill today; save INTERESTING angles to `docs/content/ideas/{domain}-{YYYY-MM-DD}.md` per §6 Flow 5 and hand back to the operator.

**Receives from:**

- **[BC-5824](https://linear.app/brite-nites/issue/BC-5824) `situation-mining`** — hard prereq for Deep Mode. The artifact stays in conversation context so Deep Mode can read it without re-query.
- **[BC-5831](https://linear.app/brite-nites/issue/BC-5831) `icp-scoring`** (optional future) — segment-level context that informs angle generation when the operator is running against a scored ICP slice.
- **[BC-2721](https://linear.app/brite-nites/issue/BC-2721) `campaign-analysis` / [BC-5830](https://linear.app/brite-nites/issue/BC-5830) `campaign-debrief`** (optional) — feedback on previously-tested angles so this skill can avoid re-proposing angles that have already been commoditized by a prior run.

**Does not own:**

- Per-prospect research (that's `situation-mining`).
- Copy generation (that's `email-copywriting`).
- Launch mechanics (that's `/marketing:launch-campaign`).
- Test design or next-batch experimentation (that's MSPA).

### Output artifact

Every run writes one artifact to `docs/research/angles/{domain}-{YYYY-MM-DD}.md`. Frontmatter shape:

```yaml
---
domain: example.com
mode: quick | deep
angles_count: 3
alpha_count: 0
promising_count: 1
generated_at: 2026-04-21T14:30:00Z
situation_mining_source: docs/research/situations/example.com-2026-04-15.md  # deep mode only; omit for quick
---
```

Body sections (in order):

1. **Signal Clusters** — one entry per cluster, each with 2+ data points and source URLs inline.
2. **Generated Angles** — 3–8 rows. Each row lists the angle (one sentence), the forcing function(s) attributed, the Asymmetry Score (total plus the per-dimension breakdown), and the verdict label.
3. **Shelf-Life Block** — ALPHA and PROMISING angles only. Three sub-fields per angle: estimate (citing a `shelf-life-patterns.md` decay category), decay trigger, refresh date.
4. **Worldview Conflicts** — Deep Mode only. Minimum 1 conflict; each framed as a curiosity opening, not a gotcha.
5. **Handoff Block** — ALPHA angles → pointer to `email-copywriting`; INTERESTING angles → saved to `docs/content/ideas/`; COMMODITY angles → discarded (named only, not carried forward).

---

## MCP Tool Reference

§4 declared WHAT tools this skill uses; §5 says WHEN — which workflow, in what order. Grouping is by what the skill actually does, not by server. Connection details live in the Brite integration guides; this section names tools semantically. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) for SF auth, SOQL gotchas, and the canonical availability probe pattern.

### Workflow 1 — Quick Mode parallel search (always runs)

No availability check needed — `WebSearch` is always on. Single turn, five parallel `WebSearch` calls using the five Quick Mode patterns from §3 (blog content, reviews / complaints, competitors, regulation / compliance, hiring). Substitute `{{company_name}}`, `{{domain}}`, and (when known) `{{industry}}` before executing.

On rate-limit or transient failure for any single query, retry once with exponential backoff. If still failing, proceed with the remaining queries and drop the affected cluster's Evidence-dimension score by one band in the §3 Asymmetry Score. Do NOT halt the run on a single-query failure — partial signal is still scorable.

### Workflow 2 — Deep Mode 7-query batch (runs after Workflow 1)

Runs only after §2 Gate 3 has cleared and Workflow 1 has completed. Single turn, seven parallel `WebSearch` calls using the seven Deep Mode patterns from §3 (G2 / Trustpilot, events / conferences, regulation deep, partnerships, senior hiring, financial signals, Reddit / HN sentiment). Same substitution rules as Workflow 1.

Same retry / degrade policy as Workflow 1: one retry with backoff, then proceed on partial signal and drop the affected cluster's Evidence band by one. Deep Mode is supplementary to Quick Mode — the 12-query total is the full signal base, but the skill continues to produce an artifact even when a subset fails.

### Workflow 3 — `WebFetch` deep-read (backup)

When a `WebSearch` snippet is insufficient to ground a specific data point, call `WebFetch` on the specific URL. Do NOT use `WebFetch` as a default — snippet analysis is usually enough, and `WebFetch` burns context fast. Scope each fetch to a single URL with a concrete data point in mind; do not pre-fetch opportunistically.

### Workflow 4 — Salesforce ALPHA cross-check (optional, conditional)

Fires only when a generated ALPHA angle targets a domain that may already exist as a Brite Salesforce Account — the cross-check surfaces lapsed-opportunity or Activity-history evidence that strengthens the angle's Evidence dimension. Sequence:

1. **Availability probe.** Call `run_soql_query` with `SELECT Id FROM User LIMIT 1`. This is the verified liveness check per BC-5534 findings §Q1 — `get_username` is NOT valid because it reads the local auth store without contacting Salesforce. On failure, skip the rest of this workflow silently; do NOT halt the skill.
2. **Account lookup.** Call `run_soql_query` with `SELECT Id, Name FROM Account WHERE Website LIKE '%{{domain}}%' LIMIT 5`. If zero results, the angle's prospect is not an existing Account — skip the rest of this workflow silently.
3. **Evidence enrichment.** For the matched Account ID, call `run_soql_query` against ActivityHistory or Opportunity history only if the returned rows would add data points to the angle's Evidence dimension. On any SF error or empty result, note the attempt inline in the output artifact and proceed — this skill does not block on Salesforce.

All SF calls are read-only — no MCP confirmation gates needed. The skill MUST continue producing a complete artifact with or without Workflow 4; SF enrichment is additive, never a blocker.

---

## Operational Runbook

This section turns §3 Methodology + §5 MCP Tool Reference into five concrete flows that a subagent follows end-to-end. Flow 1 is the default path (Quick Mode). Flow 2 is the Deep Mode happy path. Flow 3 is the precondition-halt path when Deep Mode's prereq is unmet. Flows 4 and 5 are conditional handoff paths triggered by what Flows 1 / 2 produced. Preconditions, steps, expected output, error handling, and handoff are explicit on every flow so a fresh agent can execute any of them without re-reading the rest of the skill.

### Flow 1 — Quick Mode standard run (default path)

**Preconditions:** §2 Gates 1, 2, 3 resolved; operator picked Quick Mode at Gate 2.

**Steps:**

1. Run §5 Workflow 1 — five parallel `WebSearch` queries.
2. Extract signal clusters per §3 Quick Mode Step 2 (2+ data points per cluster, sources diverse).
3. Apply the 5 forcing functions per §3 Quick Mode Step 3 (Inversion, Adjacent Transfer, Timing Arbitrage, Specificity Escalator, Ecosystem Gap Analysis).
4. Score each candidate angle per §3 Asymmetry Score; verdict-map per §3 Verdict mapping (ALPHA / PROMISING / INTERESTING / COMMODITY).
5. Attach shelf-life metadata to every ALPHA and PROMISING angle per §3 Shelf-life requirements (estimate, decay trigger, refresh date).
6. Write the output artifact to `docs/research/angles/{domain}-{YYYY-MM-DD}.md` per the §4 Output artifact shape.
7. Offer handoff per Flow 4 (ALPHA → `email-copywriting`) and Flow 5 (INTERESTING → content), conditional on the verdict mix in the artifact.

**Expected output:** artifact with 3–5 angles, verdict-mapped, shelf-life metadata populated on every alpha-tier row, no `situation_mining_source` frontmatter.

**Error handling:** `WebSearch` rate-limit → retry once with backoff, then degrade the affected cluster's Evidence band per §5 Workflow 1. No hard halt on partial query failure — partial signal is still scorable.

**Handoff:** per Flow 4 / Flow 5, conditional on verdict mix.

### Flow 2 — Deep Mode with situation-mining

**Preconditions:** §2 Gate 3 satisfied (situation-mining artifact < 14 days old on disk for the `{domain}`); Quick Mode work is included because Deep Mode is additive, not a replacement.

**Steps:**

1. Load the situation-mining artifact from `docs/research/situations/{domain}-*.md` (newest match that satisfied §2 Gate 3).
2. Run §5 Workflow 1, then §5 Workflow 2 (12 queries total).
3. Run the §3 Deep Mode Step 3 worldview-conflict analysis against the stated worldviews in the situation-mining §Situations section. Minimum 1 conflict surfaced, framed as a curiosity opening.
4. Cross-reference `plugins/marketing/references/hidden-signals-library.md` Brite-entity tables when the prospect is Nites or Labs (Entertainment Venues, Landscape / Hardscape Contractors, HOAs / Property Management).
5. Apply all 5 forcing functions plus the worldview conflicts to generate 5–8 angles. Angles combining 2+ forcing functions — or a forcing function plus a worldview conflict — are the highest-asymmetry candidates.
6. Score every angle per §3 Asymmetry Score, verdict-map, and attach shelf-life metadata to every ALPHA and PROMISING row.
7. Write the output artifact with the `situation_mining_source` frontmatter field populated.
8. Offer handoff per Flow 4 / Flow 5.

**Expected output:** artifact with 5–8 angles, at least 1 worldview conflict surfaced, shelf-life metadata on every alpha-tier row, `situation_mining_source` populated in frontmatter.

**Error handling:** same as Flow 1 for query-level failures; additionally, if Workflow 2's 7-query batch fully fails, the run degrades to Flow 1 output plus the worldview-conflict content sourced from the situation-mining artifact alone — angle count caps at 5.

**Handoff:** per Flow 4 / Flow 5.

### Flow 3 — Deep Mode missing-prereq halt

**Preconditions:** §2 Gate 2 → operator picked Deep Mode; §2 Gate 3 → no situation-mining artifact < 14 days old for `{domain}`.

**Steps:**

1. Halt before any `WebSearch` call fires.
2. Surface the blocking message verbatim to the operator:

   > "Deep Mode requires situation-mining output less than 14 days old for `{domain}`. Run `situation-mining` first, then resume."

3. Do NOT silently fall back to Quick Mode. The operator either runs `situation-mining` and re-invokes this skill, or explicitly re-picks Quick Mode at Gate 2 on a fresh invocation.

**Expected output:** the blocking message and zero `WebSearch` calls. No artifact written.

**Error handling:** none — this is a precondition-violation path, not a failure path.

**Handoff:** none; the skill resumes Flow 1 or Flow 2 on a subsequent invocation once the operator has acted.

### Flow 4 — ALPHA-to-email-copywriting handoff

**Preconditions:** Flow 1 or Flow 2 has completed and written an artifact; at least 1 angle in the artifact has verdict = ALPHA.

**Steps:**

1. Present each ALPHA angle to the operator with its Asymmetry Score per-dimension breakdown and its shelf-life metadata.
2. Use `AskUserQuestion` to ask the operator (a) which ALPHA angle to ship first and (b) which offer tier to pair it with (T1 Knowledge / T2 Free Asset / T3 DFY Trial / T4 Risk Reversal). One question per field per the BC-5761 one-question-per-field rule.
3. On operator selection, hand off to `email-copywriting` (BC-5825) with the tuple `{angle, situation-mining-artifact-if-deep, offer-tier}`. `email-copywriting` owns copy generation from here.
4. If the operator declines (wants to sit on the angle before committing), save the artifact and record the declination in the run log.

**Expected output:** one ALPHA angle plus one offer tier selected, and the handoff to `email-copywriting` fires.

**Error handling:** if no ALPHA angle exists in the artifact (only PROMISING or below), skip this flow entirely and offer Flow 5 or no handoff.

**Handoff:** `email-copywriting` (BC-5825).

### Flow 5 — INTERESTING-to-content redirect

**Preconditions:** Flow 1 or Flow 2 has completed and written an artifact; at least 1 angle in the artifact has verdict = INTERESTING.

**Steps:**

1. Collect every INTERESTING angle from the output artifact.
2. Write to `docs/content/ideas/{domain}-{YYYY-MM-DD}.md`, preserving the angle text, the forcing function attribution, and the Asymmetry Score. INTERESTING angles do NOT carry shelf-life metadata — they will run as content, not cold outbound, and shelf-life is irrelevant to that decision.
3. Surface to the operator: "Saved N INTERESTING angles to `docs/content/ideas/` for thought-leadership redirect. Too creative for cold outbound — run them as content instead."

**Expected output:** content file written at `docs/content/ideas/{domain}-{YYYY-MM-DD}.md` and the operator is notified.

**Error handling:** none — the write is local and non-blocking.

**Handoff:** no cross-skill handoff. Brite does not have a content-workflow skill yet; the artifact itself is the hand-back to the operator.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | Both modes correct — Quick Mode ran 4 ordered steps with all 5 parallel `WebSearch` queries; Deep Mode ran 6 ordered steps with all 7 additional `WebSearch` queries on top of Quick's 5; all 5 forcing functions named verbatim per `creative-thinking-models.md` §1–§5 (`Inversion (Munger)`, `Adjacent Transfer`, `Timing Arbitrage`, `Specificity Escalator`, `Ecosystem Gap Analysis`); Asymmetry Score formula applied with all 6 dimensions at the correct weights (Novelty 2x, Evidence 2x, Timing 1.5x, Simplicity 1x, ShelfLife 1x, Downside 0.5x, divided by 8); verdict assignment matches the 4 score bounds exactly (ALPHA 8.0+, PROMISING 6.0–7.9, INTERESTING 4.0–5.9, COMMODITY below 4.0); every ALPHA and PROMISING angle has all three shelf-life sub-fields (estimate citing a `shelf-life-patterns.md` decay category, decay trigger, refresh date); every signal cluster has ≥ 2 data points each with a source URL; Deep Mode worldview-conflict analysis ran and names ≥ 1 conflict framed as a curiosity opening; Brite-entity signals from `hidden-signals-library.md` cited when the prospect is Nites/Labs (Entertainment Venues / Landscape-Hardscape / HOAs tables); Flow 4 (ALPHA → `email-copywriting`) or Flow 5 (INTERESTING → content) handoff surfaced per §6. |
| 7-9 | Mostly excellent with one gap — e.g. one forcing function applied but referenced as "Munger Inversion" instead of the exact "Inversion (Munger)"; one ALPHA angle missing the refresh date but has estimate + decay trigger; shelf-life cites a decay category but not a specific row in `shelf-life-patterns.md`; handoff block names the target skill but not the offer-tier prompt; Deep Mode ran 6 of 7 additional queries and degraded one cluster's Evidence band accordingly; worldview conflict surfaced but framed as a generic observation rather than the three-part "Stated / Evidence / Curiosity opening" pattern. |
| 4-6 | Functional but missing structural elements — e.g. Quick Mode ran with 4 searches instead of 5; Asymmetry Score computed but one dimension (e.g. Downside Cap) weighted at 1.0 instead of 0.5; INTERESTING angles pitched into cold outbound instead of redirected to content per Flow 5; missing the `situation_mining_source` frontmatter key on a Deep Mode run; worldview-conflict analysis produced a conflict but framed it as a gotcha instead of a curiosity opening; artifact written to the wrong path (missing date stamp, pluralized filename, or outside `docs/research/angles/`); signal cluster documented but sources not inline URLs. |
| 1-3 | Hard failure — any ONE of these drops the run to 1-3: angle generated from a single data point (violates the 2+ cluster rule); angle score emitted without a cited evidence chain; worldview contradiction weaponized against the prospect (gotcha framing); ALPHA or PROMISING angle missing shelf-life metadata; Deep Mode ran after §2 Gate 3 failed (graceful-degrade violation — §2 is a hard halt with no fall-back to Quick Mode); invented forcing function name not in `creative-thinking-models.md` §1–§5; invented shelf-life decay category not in `shelf-life-patterns.md` (the five are Regulatory / Deadline, Competitive Move, Data Insight, Industry Pattern, Structural); subjective verdict language ("pretty strong", "maybe worth a shot", "looks interesting") in place of the four fixed verdict labels. |

---

## Anti-Slop Guardrails

Base guardrails (shared across marketing plugin) + skill-specific hard failures. Skill-specific rules are phrased as "Do not X" because they are enforced as validation gates, not style preferences — each one drops the run to §7 1-3 band when violated.

**Base guardrails:**

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).

**Skill-specific hard failures (validation-gated — drop the run to §7 1-3 band):**

- **Do not generate angles without signal-cluster evidence.** Single data points are noise, not signals. The 2+ data points per cluster rule is the load-bearing guard against speculative angles; any cluster of size 1 drops the run to §7 1-3. Data points inside a cluster must come from different sources — a blog post and a job posting count as two, two blog posts on the same site count as one.
- **Do not run Deep Mode without situation-mining less than 14 days old.** §2 Gate 3 is a hard halt — surface the verbatim blocking message ("Deep Mode requires situation-mining output less than 14 days old for `{domain}`. Run `situation-mining` first, then resume.") and wait for the operator. No silent fall-back to Quick Mode.
- **Do not score an angle without citing the evidence chain.** Every Asymmetry Score is derived from named data points with source URLs. A score without a traceable evidence chain is §7 1-3 — a reviewer must be able to apply the §3 rubric to the same data points and reproduce the score within 1.0.
- **Do not skip shelf-life metadata on ALPHA or PROMISING angles.** Three sub-fields required: estimate citing a `shelf-life-patterns.md` decay category (one of Regulatory / Deadline, Competitive Move, Data Insight, Industry Pattern, Structural), decay trigger (one-sentence specific event), refresh date (specific ISO date). Missing any of the three → §7 1-3.
- **Do not weaponize worldview contradictions.** Contradictions are curiosity openings, never gotchas. Required framing pattern: "Noticed you say X while hiring for Y — how are you thinking about that bridge?" — aggressive framing ("caught you", "you claim X but actually Y") is §7 1-3. The operator's job is to extend curiosity, not expose inconsistency.
- **Do not manufacture fake urgency for Timing Arbitrage.** Urgency must be real — a public deadline, a regulatory cycle, a known competitive move. Fabricated urgency ("act before the window closes" with no named window) is deliverability poison and §7 1-3.

---

## Behavioral Tests

Six scenarios covering the core paths. Structured assertions + fixtures live in `evals/evals.json` alongside this file. Scenario IDs match the `evals.json` entries for 1:1 traceability. Tier 1 scenarios assert on free output — no tool calls required. Tier 2 scenarios require file reads or MCP calls to verify.

### Tier 1 — Free assertions (no tool calls needed)

- **`quick-mode-happy-path`** — Given a dense-signal prospect with `company_name` and `domain` supplied and Quick Mode selected at §2 Gate 2, the output artifact contains 3–5 angles in §Generated Angles; every angle has one of the four §3 verdict labels (`ALPHA` / `PROMISING` / `INTERESTING` / `COMMODITY`); every angle attributes to at least one §3 forcing function; every signal cluster in §Signal Clusters has ≥ 2 data points each with an inline source URL; every ALPHA and PROMISING row carries a §Shelf-Life Block entry with all three sub-fields.
- **`deep-mode-missing-prereq-halt`** — Given Deep Mode selected at §2 Gate 2 but no `docs/research/situations/{domain}-*.md` file < 14 days old on disk, the skill's first response is the verbatim halt message ("Deep Mode requires situation-mining output less than 14 days old for `{domain}`. Run `situation-mining` first, then resume.") and zero `WebSearch` calls fire. The skill does NOT silently fall back to Quick Mode; no artifact is written.
- **`shelf-life-mandate`** — Given a completed run producing at least one ALPHA angle, every ALPHA row has all three shelf-life sub-fields: (a) an estimate citing one of the five `shelf-life-patterns.md` decay categories (Regulatory / Deadline, Competitive Move, Data Insight, Industry Pattern, Structural), (b) a one-sentence decay trigger naming a specific event, (c) a specific ISO refresh date. Missing any sub-field on any ALPHA row fails the scenario. Same rule applies to every PROMISING row.
- **`commodity-discard`** — Given an angle whose Asymmetry Score computes below 4.0, the verdict column in §Generated Angles reads `COMMODITY`; the recommended action is "Discard entirely" (per §3 Verdict mapping); the angle is listed by name in §Handoff Block as "discarded" but is NOT carried forward to any downstream output (no entry in §Shelf-Life Block, no handoff to `email-copywriting`, no save to `docs/content/ideas/`).

### Tier 2 — Tool-assisted (requires file read or MCP call)

- **`deep-mode-worldview-conflict`** — Given Deep Mode invoked with a valid situation-mining artifact < 14 days old in context, the output artifact's §Worldview Conflicts block contains ≥ 1 conflict framed as a curiosity opening, not a gotcha. Required framing pattern per row: "Stated: {worldview}. Evidence: {contradicting signal}. Curiosity opening: {question}." Rows that frame contradictions as gotchas ("caught you saying X while actually doing Y") fail the scenario. Requires a `Read` tool call on the situation-mining artifact path.
- **`reference-file-name-anchor`** — Given any run (Quick or Deep), all 5 forcing-function names appear in the output artifact exactly as spelled in `creative-thinking-models.md` §1–§5 headings: `Inversion (Munger)`, `Adjacent Transfer`, `Timing Arbitrage`, `Specificity Escalator`, `Ecosystem Gap Analysis`. Invented aliases ("Munger Inversion", "Adjacent Industry Transfer", "Timing Window", "Specificity Ladder", "Ecosystem Analysis") fail the scenario. Requires a `Read` tool call on `plugins/marketing/references/creative-thinking-models.md` to cross-check spelling.
