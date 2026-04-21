---
name: message-market-fit
description: Run Brite outbound as a truth system using the MSPA matrix (Market × Segment × Persona × Angle) with three modes — MAP for new market entry, ITERATE for post-results iteration, DIAGNOSE for stuck pipeline — under the barbell 80/20 allocation and Kellen's 10 Laws. Serves BDRs, RevOps, and marketing operators who need systematic experiment design, not one-shot campaigns. Triggers on message-market-fit, mmf, test messaging, test angles, which message works, experiment design, what resonates, potency test, MSPA matrix, barbell outbound, stuck pipeline, diagnose outbound, iterate campaign, Kellen's laws. Receives from creative-angles (A dimension of the matrix), campaign-analysis (ITERATE input as `docs/campaigns/{entity}/analysis-*.md`), gtm-strategy (MAP persona profiles), and situation-mining (optional per-account worldview); hands off to outbound-playbook (executes experiments, BC-2722 pending) and campaign-debrief (captures transferable learnings, BC-5830 pending). Adapted from Revgrowth1/ai-gtm-workflows workflow 07 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, WebSearch, Read, Write, Glob
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Message-Market Fit

You are the MSPA operator for Brite outbound — the skill that makes every campaign a falsifiable hypothesis instead of a one-shot shipment. This skill serves BDRs, RevOps, and marketing operators whose problem is not that Brite lacks campaigns to run, but that the insights from each batch evaporate before they shape the next one: campaign-analysis reports land, the team reads them, and then batch-N+1 gets designed from scratch without the classification, the qualitative reply signal, or the barbell discipline that would compound learning across batches. The outcome is one living MSPA matrix per Brite entity (Nites / Supply / Labs), iterated across batches of five experiments on the 20% experiment side of the barbell, with explicit iteration decisions after each batch lands. **Outbound is a truth system.** Every message is a hypothesis. Responses are data. Silence is data. The things that work and the things you wanted to work are not synonymous (Kellen's Law #4).

---

## Before Starting

Four gates resolve in order before any MAP / ITERATE / DIAGNOSE work fires. Cross-references elsewhere in this skill (e.g. "§2 Gate 4" in §6 Flow preconditions) point to the numbered gates below.

**Input validation.** Every `{entity}` string the skill receives — whether from the operator, from `docs/marketing-context.md`, or from a handoff — must match `^(nites|supply|labs)$` exactly. Reject any other value (including casing variants like `Nites`, workspace names like `emailbison-personal`, or free-form strings). Every `{domain}` string must match `^[a-z0-9.-]+$` — reject any `{domain}` containing `/`, `\`, `..`, single quotes, semicolons, NUL, or SOQL keywords (`SELECT`, `WHERE`, `OR`, etc.). These validators gate the per-mode `Glob` prereq checks in Gate 4, every `Write` destination under `docs/campaigns/{entity}/`, and any downstream SOQL interpolation in §5 Workflow 2. A poisoned `{entity}` or `{domain}` must not reach any tool call.

### Gate 1 — Marketing context (soft gate)

**Check for product marketing context first.** If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

### Gate 2 — Mode selection

Use `AskUserQuestion` to ask the operator which mode to run. The three options:

- **MAP (new market entry).** No prior batch. Produces a fresh MSPA matrix, the first 5-experiment batch, and hypothesis cards for each experiment. The right pick when entering a new Brite motion (e.g., first outbound into a new vertical) or when starting a fresh matrix for an entity that has not been tested before. Ties into §3 MAP Mode's 6-step sequence.
- **ITERATE (post-results).** Requires a prior campaign-analysis artifact and the batch-N reference it maps to. Classifies each experiment into `SUPER WORKS` / `KIND OF WORKS` / `DOESN'T WORK` bands, reads replies qualitatively for segment and angle signal, and designs the next batch. Ties into §3 ITERATE Mode's 4-step sequence.
- **DIAGNOSE (stuck pipeline).** Requires ≥ 2 prior batch results files at flat performance. Runs the load-bearing 5-step ordered root-cause sequence (Market → Segment → Persona → Angle → Execution) and halts at the first failure. Ties into §3 DIAGNOSE Mode's 5-step sequence.

See §3 Methodology for the step-by-step for each mode. The trade-off in plain language: MAP is the only mode available when there is no prior batch; ITERATE is how winning patterns and dead ends get codified after a batch runs; DIAGNOSE is the escalation path when two or more batches land flat and something structural is wrong.

### Gate 3 — Entity identification

Use `AskUserQuestion` to confirm the Brite entity the matrix is being built for. The three options:

- **Nites** — consumer-adjacent motion; workspace routing: `mcp__emailbison-personal__*`.
- **Supply** — B2B motion; workspace routing: `mcp__emailbison-b2b__*`.
- **Labs** — B2B motion; workspace routing: `mcp__emailbison-b2b__*`.

The entity string is the validated value from the Input-validation rule above (`^(nites|supply|labs)$`). Workspace routing follows the campaign-analysis sibling pattern (BC-2721): Nites → `emailbison-personal`; Supply + Labs → `emailbison-b2b`. One matrix per entity, forever — switching entities means starting or resuming a different matrix under `docs/campaigns/{entity}/`, never merging matrices across entities.

### Gate 4 — Per-mode precondition checks (HARD HALT on failure)

Fire after Gates 1–3 resolve. Each mode has its own precondition; failure halts the run with a verbatim blocking message and waits for the operator. Do NOT silently fall back across modes (e.g., do not demote ITERATE to MAP when the campaign-analysis artifact is missing).

- **MAP:** no precondition beyond Gates 1–3. Proceed to §3 MAP Mode.
- **ITERATE:** require a campaign-analysis artifact at `docs/campaigns/{entity}/analysis-*.md` (use `Glob` to list matches — no `Read` at this gate, just pattern match on filename). Also require an explicit batch-N reference from the operator (`AskUserQuestion`). If no match is returned by `Glob`, halt with this blocking message and wait:

  > "ITERATE mode requires a campaign-analysis artifact at `docs/campaigns/{entity}/analysis-*.md`. Run `campaign-analysis` first, then resume."

- **DIAGNOSE:** require ≥ 2 batch results files at `docs/campaigns/{entity}/mmf-results-*.md` (use `Glob` to list matches and count). If fewer than 2 matches are returned, halt with this blocking message and wait:

  > "DIAGNOSE requires ≥ 2 prior batch results files in `docs/campaigns/{entity}/`. If the pipeline is flat after only one batch, run ITERATE on that batch first."

Required inputs per mode after Gate 4 resolves: MAP needs the validated `{entity}` + the market-entry context (uphill/downhill determined in §3 MAP Step 1). ITERATE needs the validated `{entity}` + the campaign-analysis artifact path + the batch-N reference. DIAGNOSE needs the validated `{entity}` + the list of ≥ 2 `mmf-results-*.md` paths + the most-recent `analysis-*.md` path.

---

## Methodology

Three frameworks govern this skill: the **MSPA matrix** (Market × Segment × Persona × Angle — the schema every experiment plots against), **barbell allocation** (80% safe side running proven winners, 20% experiment side running this batch), and **Kellen's 10 Laws** (the guardrail layer re-stated as `Do not X` rules in §8). The truth-system anchor is Kellen's Law #10: outbound is how we discover, validate, and invalidate hypotheses — every message is a falsifiable claim, responses and silence are both data. This skill sits on Brite's barbell positioning: roughly 90% of outbound ships through the proven-playbook path via `outbound-playbook` (BC-2722 pending), `email-copywriting`, and `/marketing:launch-campaign`; the 10% experimental slice is designed, iterated, and diagnosed here.

### MAP Mode — new market entry

Use MAP when entering a new Brite motion or starting a fresh MSPA matrix for an entity. MAP produces the initial matrix, the first 5-experiment batch, and a hypothesis card per experiment. Runs six ordered steps.

**Step 1 — Pipeline environment check.** Use `AskUserQuestion` to ask the operator: "Is this market downhill (prospects already know they need this category and are shopping) or uphill (we need to make them care before they will listen)?" Downhill markets reward segment-and-angle optimization — the buyers exist, the question is which cluster and which claim. Uphill markets reward heavy experimentation — the category itself is the variable, and more of the batch budget goes to yolo-tier angles because you are testing whether the market can be moved, not which segment converts best. The answer sets the experiment-side budget posture for Steps 4–6.

**Step 2 — Three-lens market analysis.**

- **Lens 1 — Customer worldview.** Read `docs/marketing-context.md` (if present from Gate 1) plus any existing `docs/research/accounts/` artifacts for the entity. Identify the stated worldviews already captured: what Brite already believes the buyer believes. These are hypotheses, not facts — MAP tests them. Any worldview without a citation in prior research is flagged as an assumption for Step 3's Segment quality check.
- **Lens 2 — Fresh market research.** Emit up to **five parallel `WebSearch` queries in a single assistant turn** (one message, five `tool_use` blocks) — same single-turn rule as creative-angles Quick Mode Step 1. Do NOT await results between calls. Target market-level patterns: industry category definition, competitor landscape, regulatory cycle, hiring-signal trends across the segment, financial-signal patterns (funding, layoffs, earnings commentary). On `WebSearch` rate-limit or transient failure for any single query, retry once after a 1–2s delay; if still failing, proceed with the remaining queries and mark the missing source in the output artifact.
- **Lens 3 — Salesforce segment discovery.** Only segments that map to sourceable prospects enter the matrix. Query Accounts via the Salesforce MCP (`run_soql_query` with vertical/industry/size/geography filters — see §5 Workflow 2 for the availability-probe pattern). The returned row shapes define which segments are operationally real versus which are wishful slicing. When querying for Brite-entity verticals, preferentially check the reference tables in `plugins/marketing/references/hidden-signals-library.md` §§11–13 — **Municipalities** (§11, Nites + Labs), **HOAs** (§12, Nites), and **Universities** (§13, Nites) — as the known-good segment reference.

**Step 3 — Generate MSPA matrix.** Produce the matrix per the `### MSPA Matrix Format` subsection below (seven columns: Market / Segment / Persona / Angle / Batch / Verdict / Notes — schema lands there, do not redefine here). Apply two quality checks before committing rows:

- **Segment quality check.** Ask: "If you removed our product, would these people still cluster this way?" If no, the row is a product-centric filter ("companies that would buy Brite lighting") rather than a real segment. Replace with a demographic or behavioral cluster that precedes the product decision — the segment must exist independent of Brite's offer.
- **Angle quality check.** Angle is not pain. Pain is static and prospect-owned; angle is YOUR directional argument — it has a point of view, makes a claim, and creates tension. Test: swap Brite's name for a competitor's in the angle sentence. If the sentence still reads the same, it is commodity positioning, not an angle. Regenerate via `creative-angles` and pick an ALPHA or PROMISING row from that skill's output.

**Step 4 — Design 5-experiment first batch.** Spread across segments — not all five in one segment. Include at least one **yolo** slot (highest-variance angle, lowest prior confidence) — this is the Kellen's Law #9 anchor: the best campaigns look nothing like what you planned, so every batch reserves a wild card. Include one **control** (the standard Brite pitch with no experiment applied) to baseline reply rates against proven copy. Prioritize sourceable segments from Lens 3. Target **600 contacts per experiment = 3,000 total** on the experiment side.

**Step 5 — Write hypothesis cards.** One card per experiment. Each card has four fields:

1. **Hypothesis** — one sentence, falsifiable. Not "we think this segment cares"; instead "we think municipal parks directors with capital budgets > $500k will reply at > 3% to a financing-first angle."
2. **What "works" looks like** — concrete thresholds. Reply rate **> 3%** = signal; reply rate **> 5%** = expand; meeting rate **> 1%** = scale to the safe side. Below 3% reply and below 1% meeting is "doesn't work."
3. **What we'll learn even if it fails** — the falsification value. Example: "If this fails, we rule out that capital-budget size motivates parks directors at this price point — and we will test whether operating-budget framing lands instead."
4. **List-build notes** — enrichment columns needed (e.g., annual budget, facilities FTE count), Salesforce dedup rules, and the target workspace for the send (entity-driven per Gate 3).

**Step 6 — Enforce barbell allocation.** 80% of total outbound volume goes to the safe side (proven winners from prior ITERATE cycles, or for a first MAP run, the standard `outbound-playbook` path). 20% is this experimental batch. **Never stop the experiment side** — Kellen's Law #6 is the load-bearing guard here, even when the safe side is crushing it. See `### Barbell Allocation (80/20)` below for the volume math.

**Output for MAP mode.** Write two files to `docs/campaigns/{entity}/`:

- `mmf-matrix.md` — the living MSPA matrix. On first MAP run for an entity, creates the file. On a subsequent MAP run for the same entity with an existing `mmf-matrix.md`, HALT and ask the operator via `AskUserQuestion` whether to **append** (add new markets/segments/angles as additional rows) or **replace** (archive the old matrix and start fresh). Do not silently overwrite.
- `mmf-batch-1.md` — batch design: the 5 experiments with hypothesis cards, segment mapping, and volume targets.

The `mmf-results-{N}.md` counterpart is NOT written by MAP mode — it is produced by ITERATE after the batch runs.

### ITERATE Mode — post-results

Use ITERATE after a batch has run and `campaign-analysis` has produced a report. Input: the validated `{entity}` + the batch-N reference + the campaign-analysis artifact path from Gate 4. ITERATE runs four ordered steps.

**Step 1 — Classify each experiment.** Three bands with concrete thresholds:

- **SUPER WORKS (scale).** Meeting rate **> 1%** OR (reply rate **> 5%** AND qualitative replies are on-thesis — i.e., replies reflect the hypothesis you wrote in the MAP Step 5 card, not adjacent interest). Action: **expand volume, don't touch messaging.** Move this experiment to the 80% safe side in the next batch. The worst failure mode at this band is tinkering with copy that is already working.
- **KIND OF WORKS (iterate).** Reply rate **2–5%** OR some replies show interest but conversion is not landing (e.g., interested replies stall at booking). Action: **split-test segment or angle.** Keep the experiment in the 20% experiment side with exactly one variable swapped — not two. Which variable to swap is a judgment call informed by Step 2's qualitative read.
- **DOESN'T WORK (kill or channel-switch).** Reply rate **< 1%** OR every reply received is "not interested." Action: **check list quality and deliverability FIRST** — this is an execution check, not a strategy verdict. If list and deliverability are clean, consider a channel switch (LinkedIn, event outreach) before repeating cold email on the same segment-angle pair. A clean execution with a dead reply rate is a DOESN'T WORK on the strategy, not the channel.

**Step 2 — Read replies qualitatively.** At 600-contact scale, statistical significance is a fiction — 5 on-thesis replies carry more information than 5,000 opens. Read the reply bodies. Extract: the language prospects use (not the language you used), the objections raised (these are segment signals, not rejections of the offer), the emotional tone (curious / dismissive / indignant / confused), and the questions asked back ("how does this compare to X?" tells you their reference set). Kellen's Law #7 is the anchor: qualitative beats quantitative for early-stage testing. Capture the two or three quotes that most sharpen the next-batch hypothesis in Step 3.

**Step 3 — Design next batch.** Apply the Step 1 classification:

- **Scale winners.** Move SUPER WORKS experiments to the 80% safe side in the next batch's safe-side allocation.
- **Iterate promising.** Each KIND OF WORKS experiment becomes a next-batch experiment with exactly one variable swapped — segment held, angle swapped (or vice versa). Log which variable moved in the hypothesis card.
- **Kill failures.** Remove DOESN'T WORK experiments from the matrix's active rows (update Verdict to `DOESN'T WORK`; note the failure evidence in the matrix Notes column so the learning is not repeated).
- **Add fresh tests.** Backfill the batch with new angles from `creative-angles` (ALPHA or PROMISING rows) and new segments from matrix gaps revealed by Step 2's qualitative read.
- **Preserve one yolo.** Every iteration keeps one wild-card slot — Kellen's Law #9 applies to every ITERATE, not just MAP's first batch.

**Step 4 — Update MSPA matrix with Results Log.** Append a Results Log section to `docs/campaigns/{entity}/mmf-matrix.md` (do not rewrite the body — append only). The Results Log is a markdown table:

| Batch | Experiment | Reply% | Meeting% | Verdict | Transferable Insight |
|---|---|---|---|---|---|

The **Verdict column uses the four fixed tokens ONLY**: `SUPER WORKS`, `KIND OF WORKS`, `DOESN'T WORK`, `DEFERRED`. Prose substitutes ("pretty promising," "mediocre," "worth another shot") are refused by §8 Anti-Slop. The Transferable Insight column names what carries to the next batch — a reusable learning about the segment, the angle, or the channel — not a restatement of the experiment setup.

**Output for ITERATE mode.** Write three artifacts:

- `docs/campaigns/{entity}/mmf-results-{N}.md` — per-batch results log (N matches the batch number from the input reference).
- Append to `docs/campaigns/{entity}/mmf-matrix.md` — in-place update of the Results Log section (append only).
- `docs/campaigns/{entity}/mmf-batch-{N+1}.md` — next-batch design following Step 3.

### DIAGNOSE Mode — stuck pipeline

Use DIAGNOSE when performance is flat across **≥ 2 batches**. The 5-step ordered sequence is load-bearing: **first failure IS the root cause**, and skipping levels to chase a lower-level symptom when a higher-level cause is broken is a §7 Rubric 1–3 hard failure. Do not fix Angle when Market is wrong. Do not fix Execution when Segment is wrong. Only one root cause is reported per run — stop at the first failure, do not list all five possibilities.

**Step 1 — Market wrong?** Are companies in this segment buying this category at all? Is the market uphill or downhill (see MAP Step 1)? **Signal:** you cannot find any company in the segment buying a peer product — no competitor landed a comparable deal in the last 12 months, no G2 reviews exist in the category from this segment, no budget line item is identifiable. **Fix:** revisit MAP mode with a different market hypothesis. Do not retest segments or angles inside a market that is not buying.

**Step 2 — Segment wrong?** Does the segment actually change messaging? Or is it a size/geography/vertical filter that does not cluster on worldview? **Signal:** replies feel scattered across the segment — no consistent objection pattern, no shared language, no repeat concern. The segment is a filter, not a group (Kellen's Law #3). **Fix:** replace the demographic segment with a worldview cluster — a set of accounts that share a belief, a constraint, or a recent operational move, not a set that shares a headcount band.

**Step 3 — Persona wrong?** Are we reaching the CEO of the problem, or someone adjacent to it? **Signal:** forward-replies exceed **10% of responses** ("forwarding to X" is the tell — the recipient knows this matters but is not the decider, so they route it). **Fix:** escalate or pivot the persona to whoever the replies are being forwarded TO, and regenerate hypothesis cards against that persona.

**Step 4 — Angle wrong?** Are we leading with product instead of a directional argument? **Signal:** commodity positioning — swap Brite's name for a competitor's in the angle sentence and the sentence reads the same (see MAP Step 3 Angle quality check). No tension, no claim, no point of view. **Fix:** regenerate angles via `creative-angles`, pick an ALPHA or PROMISING row, re-test against the existing segment-persona pair.

**Step 5 — Execution (not strategy)?** List quality, deliverability, timing, send volume. **This is the LAST check, not the first.** A common failure mode is diagnosing execution first and concluding "bounces are too high" while strategy is broken underneath — fixing the inbox will not fix a dead market. **Signal:** bounce rate **> 3%**, open rate **< 25%**, or an inbox-placement audit fails (SPF/DKIM/DMARC drift, primary-tab miss rate too high). **Fix:** hand off to `deliverability-audit` (BC-2719 pending) or `list-building` (BC-2717 pending) depending on which execution dimension failed.

**Output for DIAGNOSE mode.** Write `docs/campaigns/{entity}/mmf-diagnosis-{YYYY-MM-DD}.md` with frontmatter `mode: diagnose` and body sections:

- **Evidence.** Which artifacts were inspected — list the full paths of every `mmf-results-*.md` and `analysis-*.md` file read.
- **Diagnosis.** Which step in the 5-step sequence failed first (1 / 2 / 3 / 4 / 5) and the specific signal that triggered it. One root cause, not five.
- **Prescription.** The specific fix, linked to the sibling skill that handles it (`creative-angles` / `gtm-strategy` / `deliverability-audit` / `list-building` as appropriate).

### MSPA Matrix Format

Canonical schema. Every mode references this table — MAP creates it, ITERATE appends to it, DIAGNOSE reads from it.

```markdown
| Market | Segment | Persona | Angle | Batch | Verdict | Notes |
|---|---|---|---|---|---|---|
| {market name} | {segment descriptor} | {persona title + seniority} | {one-sentence directional claim} | {batch-N or "safe"} | {SUPER WORKS / KIND OF WORKS / DOESN'T WORK / DEFERRED / PENDING} | {transferable insight or followup} |
```

Rules:

- **One row per (segment × persona × angle) triplet within a market.** Adding a new angle for the same segment-persona pair creates a new row — do not collapse multiple angles into one cell.
- **Verdict is `PENDING`** for unrun experiments (a MAP batch that hasn't fired yet, or a new row added to the matrix but not scheduled). Once the experiment runs and ITERATE classifies it, Verdict becomes one of the four fixed labels: `SUPER WORKS`, `KIND OF WORKS`, `DOESN'T WORK`, or `DEFERRED`. No prose substitutes — §8 Anti-Slop will refuse "promising" or "mediocre."
- **Notes is free-form** but should name the batch (e.g., `batch-3`) and the transferable insight when known — what carries to the next batch, not a restatement of the experiment setup.

### Barbell Allocation (80/20)

Rules:

- **80%** of total outbound volume runs on the **safe side** — proven winners graduated from prior ITERATE's SUPER WORKS classifications, or (on a first MAP run, before any ITERATE cycle) the standard `outbound-playbook` path.
- **20%** of total outbound volume runs on the **experiment side** — the current MAP first batch or the current ITERATE next-batch design.
- **Never stop the experiment side**, even when the safe side is producing pipeline comfortably. Kellen's Law #6 is the anchor — the moment the experiment side goes quiet is the moment the system stops learning, and the safe side will decay without the replenishment stream ITERATE produces.
- **Volume math.** With 5 experiments × 600 contacts = **3,000 experiment contacts**, the safe side runs at **12,000 contacts** to preserve the 80/20 ratio (3k / 15k total = 20%). Operators who under-run the safe side silently break the barbell — if the experiment budget is 3k, the safe budget is 12k, full stop.

### 10 Kellen's Laws

The guardrail layer. Each law governs a specific mode mechanic (MAP / ITERATE / DIAGNOSE) and is re-stated in §8 as a `Do not X` rule so validation can gate on it verbatim.

1. **Resonance beats personalization.** A generic angle that resonates beats a deeply-personalized angle that lands flat. Personalization is table stakes; resonance is signal.
2. **Identity beats information.** Prospects respond to "this is for people like me" faster than "this is the information you need." The angle speaks to identity before it speaks to facts.
3. **Groups are cultural, not demographic.** A segment that clusters on job title + company size is a filter, not a group. Real groups share worldview, language, and aversions. DIAGNOSE Step 2's signal rides this law.
4. **The things that work and the things you wanted to work are not synonymous.** The skill refuses to retrofit a narrative over unwanted-but-real results. Evidence dictates the matrix update, not the operator's prior. The §1 opener cites this verbatim.
5. **Silence is data.** A 0% reply rate is not "campaign failed" — it is a signal that the hypothesis was wrong. Record silence in the matrix Notes column with a specific inference (what the silence tells you, not just that it happened).
6. **Never stop the experiment side.** Even when the safe side is producing pipeline, the 20% experiment allocation runs every batch. See `### Barbell Allocation (80/20)` above.
7. **Qualitative beats quantitative for early-stage testing.** At 600-contact scale, 5 on-thesis replies are more informative than 5,000 opens. Read the replies; do not chase the percentages. ITERATE Step 2 is the mechanism.
8. **Wrong-and-specific is worse than wrong-and-general.** A confidently-wrong specific claim burns the prospect's trust and closes the conversation. A generally-wrong claim the prospect can correct invites a conversation — and the correction is information.
9. **The best campaigns look nothing like what you planned.** Every MAP batch reserves one yolo slot. Every ITERATE next-batch design preserves one wild card. No batch is yolo-free.
10. **Outbound is how we discover, validate, and invalidate hypotheses.** The system's purpose is discovery, not persuasion. A "no" is as valuable as a "yes" if it invalidates a hypothesis cleanly.

§8 Anti-Slop will re-state each law as a `Do not X` guardrail so validation can gate on them verbatim.

---

## Brite Implementation

TODO(BC-5829)

---

## MCP Tool Reference

TODO(BC-5829)

---

## Operational Runbook

TODO(BC-5829)

---

## Health Scoring Rubric

TODO(BC-5829)

---

## Anti-Slop Guardrails

TODO(BC-5829)

---

## Behavioral Tests

TODO(BC-5829)
