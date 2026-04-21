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
