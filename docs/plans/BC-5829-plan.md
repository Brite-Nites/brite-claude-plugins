# Plan: BC-5829 — Create marketing skill: message-market-fit (MSPA)

**Issue**: [BC-5829](https://linear.app/brite-nites/issue/BC-5829) — Create marketing skill: message-market-fit (MSPA experiment design / iterate / diagnose engine)
**Branch**: `corinne/bc-5829-create-marketing-skill-message-market-fit-mspa-experiment`
**Tasks**: 16 (estimated 100–120 min focused, subagent-per-phase)

## Locked design choices (from brainstorm)

1. **Kellen's Laws — primary in §3, echoed in §8.** The 10 laws get a dedicated subsection in §3 Methodology (with explanation + the MAP/ITERATE/DIAGNOSE context each law governs). §8 Anti-Slop re-states each as a `Do not X` guardrail so validation can gate on them verbatim. Mirrors the creative-angles pattern for shelf-life rules (BC-5828).
2. **MSPA matrix schema — subsection in §3 Methodology.** `### MSPA Matrix Format` subsection in §3 defines the markdown-table schema (columns: Market / Segment / Persona / Angle / Batch / Verdict / Notes). §4 "Brite Implementation" then ties entity-keyed output paths to the schema without redefining columns. Mirrors creative-angles' "Asymmetry Score" subsection pattern.
3. **Mode selection — §2 Gate 2 via AskUserQuestion.** Single gate asking the operator to pick MAP / ITERATE / DIAGNOSE, exactly like creative-angles' Quick/Deep gate. Per-mode precondition checks then fire as downstream gates (ITERATE needs batch reference; DIAGNOSE needs ≥ 2 prior campaign artifacts).
4. **BC-5830 cross-link — simple `(BC-5830 pending)` pattern.** Matches creative-angles lines 178 and 185 exactly. Zero rework when BC-5830 ships — just remove the `(pending)` label. No conditional-future hedging.

## Prerequisites

- **Template exists**: `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — 9-section scaffold, verified.
- **Sibling pattern anchors** (shipped, use for tone + depth):
  - `plugins/marketing/skills/creative-angles/SKILL.md` (BC-5828, 394 lines) — direct pattern-match sibling (3-mode structure, §2 gates with AskUserQuestion, §3 methodology with named frameworks, §4 entity-keyed output paths, cross-skill boundaries block). **Highest-weight reference.**
  - `plugins/marketing/skills/campaign-analysis/SKILL.md` (BC-2721) — workspace-aware pattern (emailbison-b2b vs emailbison-personal routing by entity), 5 Core Variables diagnostic is the cognate structure for DIAGNOSE mode's 5-step sequence.
  - `plugins/marketing/skills/situation-mining/SKILL.md` (BC-5824) — 6-query parallel WebSearch pattern; MAP mode's Lens 2 research uses the same emit-all-in-one-turn rule.
- **Reference files** (live-read verified, per BC-5828 check #6):
  - `plugins/marketing/references/creative-thinking-models.md` §§1–5 forcing-function names verified: `Inversion (Munger)`, `Adjacent Transfer`, `Timing Arbitrage`, `Specificity Escalator`, `Ecosystem Gap Analysis`. MAP mode Step 3 will cite these names verbatim.
  - `plugins/marketing/references/hidden-signals-library.md` §§11–13 — Brite-entity tables confirmed as **Municipalities** (§11, Nites+Labs), **HOAs** (§12, Nites), **Universities** (§13, Nites) per the 2026-04-20 provenance note at line 148. MAP mode Step 2 Lens 3 will cite these names.
- **Cross-link target existence** (verified for the §4 Cross-skill boundaries block):
  - ✅ `creative-angles/` (BC-5828) — feeds ALPHA angles to MSPA's A dimension
  - ✅ `campaign-analysis/` (BC-2721) — feeds ITERATE input at `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md`
  - ✅ `gtm-strategy/` — feeds MAP mode persona profiles
  - ✅ `situation-mining/` (BC-5824) — feeds per-account worldview inferences
  - ⚠️ `campaign-debrief/` (BC-5830) — **pending**; cross-link uses `(BC-5830 pending)` label
  - ⚠️ `outbound-playbook/` (BC-2722) — **pending**; cross-link uses `(BC-2722 pending)` label
  - ⚠️ `icp-scoring/` (BC-5831) — **pending**; referenced only as an optional future consumer
- **Target directory absent**: `plugins/marketing/skills/message-market-fit/` does not exist — net-new skill.
- **Output-dir absent**: `docs/campaigns/` directory does not yet exist on disk. BC-5829 will be the first skill to produce to `docs/campaigns/{entity}/mmf-*.md`. The skill body must document that the directory is created on first write; no pre-existence assumption.
- **Kellen's Laws count verified**: 10 laws in the issue body §Scope — Kellen's Laws. Numbered list preserved below for Task 6 anchor:
  1. Resonance beats personalization.
  2. Identity beats information.
  3. Groups are cultural, not demographic.
  4. The things that work and the things you wanted to work are not synonymous.
  5. Silence is data.
  6. Never stop the experiment side.
  7. Qualitative beats quantitative for early-stage testing.
  8. Wrong-and-specific is worse than wrong-and-general.
  9. The best campaigns look nothing like what you planned.
  10. Outbound is how we discover, validate, and invalidate hypotheses.
- **CDR alignment**: CDR INDEX check skipped — Context7 handbook library was not resolved at session start. Proceeding per writing-plans advisory-only rule.
- **Precedent alignment**:
  - Aligns with **BC-5828** (factual-anchor check #6 — live-read reference-file bodies at Plan gate; this plan did that for hidden-signals-library + creative-thinking-models + campaign-analysis output schema).
  - Aligns with **BC-5824** (soft-gate marketing-context pattern — reused verbatim in §2 Gate 1).
  - Aligns with **BC-5825** (skeleton-vs-skin split only when fan-out dominates — single skill + evals.json, no fan-out; keep bundled in one PR).
  - Aligns with **BC-5797** (factual-anchor recipe — every forcing function name, industry table name, Kellen's Law, and cross-skill reference is verified against its canonical source before Task-level commits).
  - Aligns with **BC-2721** (sequential-thinking for multi-axis runbook design; three-mode structure is exactly the kind of multi-axis problem that benefits).

## Tasks

### Task 1: Create skill directory and scaffold SKILL.md frontmatter + §1 Opener

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md` (new), `plugins/marketing/skills/message-market-fit/evals/` (new dir, placeholder for Task 13)

**Why**: Lands the file the skill-resolver picks up. Frontmatter defines identity + trigger phrases + allowed tools. §1 Opener sets audience, problem, outcome.

**Implementation**:
1. Create `plugins/marketing/skills/message-market-fit/` and `plugins/marketing/skills/message-market-fit/evals/`.
2. Write `SKILL.md` frontmatter:
   - `name: message-market-fit`
   - `description:` — single paragraph covering MSPA as a systematic truth-system for outbound, the three modes (MAP / ITERATE / DIAGNOSE), the barbell 80/20 allocation rule, the Kellen's Laws anchor, and triggers: "message-market-fit", "mmf", "test messaging", "test angles", "which message works", "experiment design", "what resonates", "potency test". End with handoff notes: receives from creative-angles (A dimension) + campaign-analysis (ITERATE input) + gtm-strategy (MAP input); hands off to outbound-playbook (executes experiments, BC-2722 pending) + campaign-debrief (captures results, BC-5830 pending). Cite upstream: "Adapted from Revgrowth1/ai-gtm-workflows workflow 07 (MIT)."
   - `user-invocable: true`
   - `allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, WebSearch, Read, Write, Glob`
   - `metadata: { version: 0.1.0, upstream: Revgrowth1/ai-gtm-workflows, category: Outbound Lead Gen }`
3. Write `# Message-Market Fit` title (H1).
4. Write §1 opener (single paragraph, ~90–130 words, mirrors creative-angles opener length):
   - Audience: BDR leads, RevOps, marketing operators running Brite outbound experiments.
   - Problem: Brite outbound today has no systematic iteration framework — campaigns ship as one-shots and the feedback from campaign-analysis does not flow back into next-batch design. Insights evaporate.
   - Outcome: one MSPA matrix per Brite entity (Nites / Supply / Labs), kept living across batches, producing 5-experiment batches on the 20% experiment side of the barbell and iteration decisions after each batch lands.
   - Anchor phrase: "Outbound is a truth system. Every message is a hypothesis. Responses are data. Silence is data. The things that work and the things you wanted to work are not synonymous." (Kellen's Law #4, foreshadows §3 Methodology.)
   - Do NOT list tool names or repo paths in §1 — those live in §4 and §5 per template guidance.

**Test**: `./scripts/validate.sh 2>&1 | head -40` — expect frontmatter parses, no unknown keys. Stub headers for §2–§9 are OK per incremental convention; add `## Before Starting` through `## Behavioral Tests` stub headers with a single `TODO(BC-5829)` line each so section-order validation passes from the start.

**Verify**: File exists. Frontmatter has all 6 required keys. §1 opener is a single paragraph, no tool names. `allowed-tools` matches issue §Tool Surface exactly.

---

### Task 2: Write §2 Before Starting — input validation + 4 gates (marketing-context, mode selection, entity, per-mode prereqs)

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: §2 is the gate layer. Four gates resolve before MAP / ITERATE / DIAGNOSE runs. This is where the marketing-context soft gate (BC-5824 pattern), the 3-mode AskUserQuestion gate, and the per-mode precondition checks live. Centralized input validation (BC-5828 pattern) prevents poisoned `{entity}` and `{domain}` strings from reaching tool surfaces.

**Implementation**:
1. Write the **Input validation rule** at the top of §2 (before gates): every `{entity}` string must match `^(nites|supply|labs)$` exactly — reject any other value; every `{domain}` string must match `^[a-z0-9.-]+$` (reject `/`, `\`, `..`, quotes, semicolons, NUL, SOQL keywords). This validator gates the per-mode Glob / Read calls and any future Write destinations under `docs/campaigns/{entity}/`. Copy the validation block pattern from creative-angles §2.
2. **Gate 1 — Marketing context (soft gate).** Verbatim BC-5824 sibling string: "Check for product marketing context first. If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: 'Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.' Then continue using only user-provided information."
3. **Gate 2 — Mode selection.** Use `AskUserQuestion` to ask which mode to run:
   - **MAP (new market entry)** — no prior batch. Produces an MSPA matrix + first 5-experiment batch + hypothesis cards. Best when entering a new Brite motion (e.g., first outbound into a new vertical) or when starting a fresh matrix for an entity.
   - **ITERATE (post-results)** — requires a prior campaign-analysis artifact and the batch reference it maps to. Classifies each experiment (SUPER WORKS / KIND OF WORKS / DOESN'T WORK) and designs the next batch.
   - **DIAGNOSE (stuck pipeline)** — requires ≥ 2 prior batch-N results files at flat performance. Runs the 5-step ordered root-cause sequence (Market → Segment → Persona → Angle → Execution).
4. **Gate 3 — Entity identification.** Use `AskUserQuestion` to confirm Brite entity (Nites / Supply / Labs). Workspace routing follows: Nites → `emailbison-personal`, Supply + Labs → `emailbison-b2b`. Cite the campaign-analysis sibling for the routing rule (BC-2721).
5. **Gate 4 — Per-mode precondition checks (HARD HALT on failure):**
   - **MAP:** no precondition beyond Gate 1–3. Fresh run.
   - **ITERATE:** require a campaign-analysis artifact at `docs/campaigns/{entity}/analysis-*.md` (use Glob) and an explicit batch-N reference from the operator (`AskUserQuestion`). If no campaign-analysis artifact exists, halt with: "ITERATE mode requires a campaign-analysis artifact at `docs/campaigns/{entity}/analysis-*.md`. Run `campaign-analysis` first, then resume."
   - **DIAGNOSE:** require ≥ 2 batch-N results files at `docs/campaigns/{entity}/mmf-results-*.md`. If fewer, halt with: "DIAGNOSE requires ≥ 2 prior batch results files in `docs/campaigns/{entity}/`. If the pipeline is flat after only one batch, run ITERATE on that batch first."
   - Do NOT silently fall back across modes. Halt verbatim and wait for operator.

**Test**: Read section back. Verify 4 gate subsections render. Verify input validation block is upfront. Verify per-mode blocking messages are verbatim.

**Verify**: §2 has exactly 4 gate subsections + an input-validation preamble. All per-mode halts are HARD, not graceful-degrade. Gate 1 is the verbatim BC-5824 sibling string.

---

### Task 3: Write §3 Methodology intro + MAP mode (6 steps)

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: MAP is the new-entry mode. Most complex of the three — 6 steps, 3-lens research, MSPA matrix generation, 5-experiment first batch, hypothesis cards, barbell allocation. Must be self-contained enough that a fresh subagent can execute.

**Implementation**:
1. Write §3 heading + intro (~90 words): three frameworks govern this skill — **MSPA matrix** (Market × Segment × Persona × Angle), **barbell allocation** (80% safe / 20% experiment), **Kellen's Laws** (10 guardrails). State the truth-system anchor: outbound is how we discover and validate and invalidate hypotheses. Connect to barbell positioning: 90% through outbound-playbook, 10% experiments through this skill.
2. `### MAP Mode — new market entry` subheading. State: "Use MAP when entering a new Brite motion or starting a fresh MSPA matrix for an entity."
3. **Step 1 — Pipeline environment check.** Ask operator via `AskUserQuestion`: "Is this market downhill (prospects know they need this category) or uphill (we need to make them care)?" — explain that uphill requires heavy experimentation, downhill requires segment/angle optimization. This question determines the experiment budget.
4. **Step 2 — Three-lens market analysis.**
   - **Lens 1 — Customer worldview.** Read `docs/marketing-context.md` if present + any existing `docs/research/accounts/` artifacts for the entity. Identify stated worldviews.
   - **Lens 2 — Fresh research.** Emit up to 5 parallel `WebSearch` queries in a single assistant turn (one message, five `tool_use` blocks) for market-level patterns: industry category, competitor landscape, regulatory cycle, hiring signals, financial signals. Cite the "emit all searches in one turn" rule from creative-angles Quick Mode Step 1.
   - **Lens 3 — Data-driven segmentation.** Identify sourceable segments via Salesforce MCP (`run_soql_query` on Account with vertical/industry/size filters) and enrichment MCP. Only segments that map to sourceable prospects enter the matrix.
5. **Step 3 — Generate MSPA matrix.** Produce a markdown table with columns Market / Segment / Persona / Angle / Batch / Verdict / Notes (reference `### MSPA Matrix Format` subsection — Task 6). Apply two quality checks:
   - **Segment quality check**: "If you removed our product, would these people still cluster this way?" If no, it's a product-centric filter (e.g., "companies that would buy lighting"), not a real segment. Replace with demographic/behavioral cluster that precedes the product decision.
   - **Angle quality check**: angle is not the same as pain. Pain is static + prospect-owned. Angle is YOUR directional argument — has a point of view, makes a claim, creates tension. Test: could you swap Brite's name for a competitor and the angle still read the same? If yes, it's commodity positioning, not an angle.
6. **Step 4 — Design experiment batch of 5.** Spread across segments (not all in one). Include at least one low-confidence "yolo" test (highest-variance angle). Prioritize sourceable segments (Lens 3). Include one "obvious" control (standard Brite pitch, no experiment) to baseline reply rates. Target 600 contacts per experiment = 3,000 total. Cite Kellen's Law #9 — the best campaigns look nothing like what you planned — as the rationale for the yolo slot.
7. **Step 5 — Write hypothesis cards** per experiment. Each card has:
   - Hypothesis (one sentence, falsifiable).
   - What "works" looks like (reply rate > 3% = signal; > 5% = expand; meeting rate > 1% = scale).
   - What we'll learn even if it fails (e.g., "we rule out that pain X motivates segment Y at this price point").
   - List-build notes (enrichment columns needed, SF dedup rules).
8. **Step 6 — Enforce barbell allocation.** 80% of volume goes to proven winners (the safe side, from prior ITERATE cycles). 20% of volume is this batch (the experiment side). Never stop the experiment side. Kellen's Law #6 is the load-bearing guard here.
9. **Output for MAP mode.** Write two files to `docs/campaigns/{entity}/`:
   - `mmf-matrix.md` — the living MSPA matrix (on first run, creates the file; on subsequent MAP runs for the same entity, warns about collision and asks whether to append or replace).
   - `mmf-batch-1.md` — batch design (5 experiments with hypothesis cards).
   - The `mmf-results-N.md` counterpart is NOT written by MAP mode; it's produced by ITERATE mode after the batch runs.

**Test**: Read section back. Verify all 6 steps present in order. Verify Lens 2 cites the single-turn emit rule. Verify Step 6 cites Kellen's Law #6 verbatim.

**Verify**: §3 intro + MAP subsection present. 6 steps present in numbered order. Matrix columns referenced (schema definition lands in Task 6). Output paths under `docs/campaigns/{entity}/`.

---

### Task 4: §3 Methodology — ITERATE mode (4 steps)

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: ITERATE is the post-results mode. Consumes a campaign-analysis artifact + batch-N reference, classifies experiments, designs next batch. The feedback loop closure.

**Implementation**:
1. `### ITERATE Mode — post-results` subheading. State: "Use ITERATE after a batch has run and campaign-analysis has produced a report. Input: the batch-N reference + the campaign-analysis artifact path."
2. **Step 1 — Classify each experiment.** Three bands with concrete thresholds (borrowed from the issue body):
   - **SUPER WORKS (scale)** — meeting rate > 1% OR (reply rate > 5% AND qualitative replies are on-thesis). Action: expand volume, don't touch messaging. Move to the 80% safe side in the next batch.
   - **KIND OF WORKS (iterate)** — reply rate 2–5% OR some interested replies but conversion is not landing. Action: split-test segment or angle. Keep in the 20% experiment side with one variable changed.
   - **DOESN'T WORK (kill or channel-switch)** — reply rate < 1% OR all replies are "not interested." Action: first check list quality + deliverability (execution, not strategy); if those are clean, consider channel switch (LinkedIn, event) rather than repeating cold email.
3. **Step 2 — Read replies qualitatively.** Extract language prospects use, objections (segment signals), emotional tone, questions asked. Cite Kellen's Law #7 — qualitative beats quantitative for early-stage testing — and explain: at 600-contact scale, statistical significance is a fiction. The information is in what a handful of prospects actually said.
4. **Step 3 — Design next batch.** Apply the classification from Step 1:
   - Scale winners (move SUPER WORKS to safe side).
   - Iterate promising (KIND OF WORKS → one variable swap).
   - Kill failures (DOESN'T WORK → remove from matrix; note the failure in the matrix Notes column).
   - Add fresh tests (new angles from creative-angles, new segments from matrix gaps).
   - Include one yolo wild card (Kellen's Law #9 anchor, preserved across every iteration).
5. **Step 4 — Update MSPA matrix with results log.** Append a Results Log section to `docs/campaigns/{entity}/mmf-matrix.md`:
   - Markdown table: Batch / Experiment / Reply% / Meeting% / Verdict / Transferable Insight.
   - Verdict column uses the four fixed labels (`SUPER WORKS`, `KIND OF WORKS`, `DOESN'T WORK`, `DEFERRED`) — no prose substitutes. §8 Anti-Slop will refuse subjective verdicts.
6. **Output for ITERATE mode.** Write:
   - `docs/campaigns/{entity}/mmf-results-{N}.md` — per-batch results log (N matches the batch number from the input reference).
   - Append to `docs/campaigns/{entity}/mmf-matrix.md` (in-place update of the Results Log section).
   - `docs/campaigns/{entity}/mmf-batch-{N+1}.md` — next batch design (follows Step 3).

**Test**: Verify the three classification thresholds match the issue body. Verify Step 2 cites Kellen's Law #7. Verify verdict labels are the four fixed tokens.

**Verify**: ITERATE subsection present with 4 numbered steps. Thresholds match issue body. Verdict labels are `SUPER WORKS` / `KIND OF WORKS` / `DOESN'T WORK` / `DEFERRED` exactly. Output paths under `docs/campaigns/{entity}/`.

---

### Task 5: §3 Methodology — DIAGNOSE mode (5-step ordered sequence)

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: DIAGNOSE is the stuck-pipeline mode. When flat results span ≥ 2 batches, something is structurally wrong. 5-step ordered sequence locates the root cause at the highest level of the stack so the fix is upstream.

**Implementation**:
1. `### DIAGNOSE Mode — stuck pipeline` subheading. State: "Use DIAGNOSE when performance is flat across ≥ 2 batches. First failure in the ordered sequence IS the root cause — do not skip levels."
2. **The 5-step sequence is load-bearing and must run in order.** Fixing a lower-level cause when a higher-level cause is broken is wasted motion.
   1. **Market wrong?** Are these companies buying this category at all? Is the market uphill or downhill? Signal: if you cannot find any company in the segment buying a peer product, the market itself is wrong. Fix: revisit MAP mode with a different market hypothesis.
   2. **Segment wrong?** Does the segment actually change messaging? Or is it a size/geography filter that does not cluster on worldview? Signal: replies feel "scattered" — no consistent objection pattern across the segment. Fix: replace demographic segment with worldview cluster.
   3. **Persona wrong?** Are we reaching the CEO of the problem, or someone adjacent? Replies saying "forward to X" are the tell. Signal: forward-replies > 10% of responses. Fix: escalate or pivot to the persona replies are forwarding TO.
   4. **Angle wrong?** Are we leading with product instead of a directional argument? Could swap Brite's name for a competitor and the copy still read the same? Signal: "commodity positioning" from the Step 3 Angle quality check (MAP Step 3) — no tension, no claim. Fix: generate fresh angles via creative-angles, pick one ALPHA or PROMISING, re-test.
   5. **Execution (not strategy)?** List quality, deliverability, timing, volume. This is the LAST check, not the first — a common failure mode is to check execution first and conclude "bounces are too high" without noticing that strategy is broken. Signal: bounce rate > 3%, open rate < 25%, or inbox placement audit fails. Fix: hand off to deliverability-audit (BC-2719 pending) or list-building (BC-2717 pending).
3. **Output for DIAGNOSE mode.** Write `docs/campaigns/{entity}/mmf-diagnosis-{YYYY-MM-DD}.md` with frontmatter `mode: diagnose` and body sections:
   - Evidence: which artifacts were inspected (list the `mmf-results-*.md` and `analysis-*.md` files).
   - Diagnosis: which step in the 5-step sequence failed first (1, 2, 3, 4, or 5) + the signal that triggered it.
   - Prescription: the specific fix, linked to the sibling skill that handles it.
4. **Important constraint**: DIAGNOSE never skips ahead. If Market is clean, check Segment. If Segment is clean, check Persona. Only one root cause is reported per run — "we found the first failure" is the correct reporting mode, not "here are all five possibilities."

**Test**: Verify 5 steps present in order with signals + fixes. Verify output path. Verify Step 5 (Execution) explicitly notes it is LAST, not first.

**Verify**: DIAGNOSE subsection present with ordered 5-step sequence. Each step has a signal + a fix. Output frontmatter specifies `mode: diagnose`. No silent step-skipping.

---

### Task 6: §3 Methodology — MSPA Matrix Format + Barbell Rule + 10 Kellen's Laws

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: Three structural subsections that anchor MAP / ITERATE / DIAGNOSE. Matrix schema is load-bearing — every mode references it. Barbell is the cross-mode invariant. Kellen's Laws are the guardrail layer §8 will gate on.

**Implementation**:
1. `### MSPA Matrix Format` subsection. Canonical schema:
   ```markdown
   | Market | Segment | Persona | Angle | Batch | Verdict | Notes |
   |---|---|---|---|---|---|---|
   | {market name} | {segment descriptor} | {persona title + seniority} | {one-sentence directional claim} | {batch-N or "safe"} | {SUPER WORKS / KIND OF WORKS / DOESN'T WORK / DEFERRED / PENDING} | {transferable insight or followup} |
   ```
   - Rules: one row per (segment × persona × angle) triplet within a market. Adding a new angle for the same segment/persona creates a new row. Verdict is `PENDING` for unrun experiments, one of the four fixed labels otherwise. Notes is free-form but should name the batch and the transferable insight when known.
2. `### Barbell Allocation (80/20)` subsection. Rules:
   - 80% of total outbound volume goes to the safe side (proven winners from ITERATE's SUPER WORKS).
   - 20% of total outbound volume goes to the experiment side (current batch — MAP first batch or ITERATE's next batch).
   - **Never stop the experiment side**, even when the safe side is crushing it. Kellen's Law #6 is the anchor.
   - Volume math: at 3,000 experiment contacts (5 × 600), the safe side runs at 12,000 to preserve the 80/20 ratio. Cite this math so operators do not silently break the barbell by under-running the safe side.
3. `### 10 Kellen's Laws` subsection. Numbered list, each with a short gloss:
   1. **Resonance beats personalization.** A generic angle that resonates beats a deeply-personalized angle that lands flat. Personalization is table stakes; resonance is signal.
   2. **Identity beats information.** Prospects respond to "this is for people like me" faster than "this is the information you need." The angle speaks to identity before it speaks to facts.
   3. **Groups are cultural, not demographic.** A segment that clusters on job title + company size is a filter, not a group. Real groups share worldview, language, and aversions.
   4. **The things that work and the things you wanted to work are not synonymous.** The skill refuses to retrofit a narrative over unwanted-but-real results. Evidence dictates the matrix update, not the operator's prior.
   5. **Silence is data.** A 0% reply rate is not "campaign failed" — it is a signal that the hypothesis was wrong. Record silence in the matrix Notes column with a specific inference.
   6. **Never stop the experiment side.** Even when the safe side is producing pipeline, the 20% experiment allocation runs every batch. See `### Barbell Allocation`.
   7. **Qualitative beats quantitative for early-stage testing.** At 600-contact scale, 5 replies are more informative than 5000 opens. Read the replies; do not chase the percentages.
   8. **Wrong-and-specific is worse than wrong-and-general.** A confidently-wrong specific claim burns the prospect's trust. A generally-wrong claim they can correct invites conversation.
   9. **The best campaigns look nothing like what you planned.** Every MAP batch reserves one yolo slot. Every ITERATE next-batch design preserves one wild card.
   10. **Outbound is how we discover, validate, and invalidate hypotheses.** The system's purpose is discovery, not persuasion. A "no" is as valuable as a "yes" if it invalidates a hypothesis cleanly.
4. Cross-reference note: §8 Anti-Slop will re-state each law as a `Do not X` guardrail so validation can gate on them verbatim.

**Test**: Verify matrix schema is a markdown table with 7 columns. Verify barbell cites Kellen's Law #6. Verify all 10 laws present and numbered 1–10.

**Verify**: Three subsections present. Matrix columns: Market / Segment / Persona / Angle / Batch / Verdict / Notes. Barbell math cited (3k experiment → 12k safe). 10 laws numbered.

---

### Task 7: §4 Brite Implementation — tool table + entity-keyed output paths + cross-skill boundaries

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: §4 translates §3 methodology into Brite's concrete stack. Which MCP, which output path, which handoff. The architectural surface for the skill.

**Implementation**:
1. `### Tools this skill calls` subsection with a tool table modeled on creative-angles §4 (semantic columns: What / MCP / Reaches / Reason). Cover WebSearch (MAP Lens 2), Salesforce MCP (MAP Lens 3 + DIAGNOSE Step 5 Activity probe), Email Bison MCP split by workspace (ITERATE `get_campaign_stats` + qualitative reply read), Read (campaign-analysis input + prior matrix/results/batch files), Glob (prereq checks in §2 Gate 4), Write (four output-file types). Cite availability-probe patterns: SF `SELECT Id FROM User LIMIT 1` per BC-5534; EB `get_active_workspace_info`.
2. `### Entity-keyed output paths` subsection listing the 4 file types:
   - `docs/campaigns/{entity}/mmf-matrix.md` — living matrix (one per entity, forever). Append-only in ITERATE's Results Log section; MAP on an existing matrix halts and asks whether to append or replace.
   - `docs/campaigns/{entity}/mmf-batch-{N}.md` — per-batch design (N starts at 1 and increments per ITERATE run).
   - `docs/campaigns/{entity}/mmf-results-{N}.md` — per-batch results log (ITERATE only).
   - `docs/campaigns/{entity}/mmf-diagnosis-{YYYY-MM-DD}.md` — per-DIAGNOSE-run root-cause report.
   - Note: the `docs/campaigns/{entity}/` directory is created on first write — the skill must not assume pre-existence.
3. `### Architectural rules that apply` subsection:
   - **Barbell is a hard invariant.** 80/20 preserved across every batch; §3 Barbell Allocation is the source.
   - **Verdict labels are fixed tokens.** `SUPER WORKS`, `KIND OF WORKS`, `DOESN'T WORK`, `DEFERRED`, `PENDING` — no prose substitutes, enforced by §8.
   - **DIAGNOSE never skips levels.** First failure in the ordered 5-step sequence IS the root cause. Skipping is a §7 Rubric 1–3 failure.
   - **Workspace routing is entity-driven.** Nites → `emailbison-personal`; Supply + Labs → `emailbison-b2b`. Cite BC-2721 campaign-analysis for the pattern.
   - **Matrix is append-only in steady state.** MAP creates; ITERATE appends Results Log rows; DIAGNOSE reads. Do not rewrite history.
4. `### Cross-skill boundaries` subsection:
   - **Hands off to:**
     - **[BC-2722](https://linear.app/brite-nites/issue/BC-2722) `outbound-playbook` (BC-2722 pending)** — receives the MSPA matrix + current batch design, executes the experiments via `launch-campaign`.
     - **[BC-5830](https://linear.app/brite-nites/issue/BC-5830) `campaign-debrief` (BC-5830 pending)** — receives the results log from ITERATE, captures transferable learnings in `docs/campaigns/{entity}/learnings.md`.
   - **Receives from:**
     - **[BC-5828](https://linear.app/brite-nites/issue/BC-5828) `creative-angles`** — feeds the A (angle) dimension of the MSPA matrix. ALPHA and PROMISING angles enter the experiment side.
     - **[BC-2721](https://linear.app/brite-nites/issue/BC-2721) `campaign-analysis`** — feeds the ITERATE input as `docs/campaigns/{entity}/analysis-*.md`.
     - **`gtm-strategy`** — feeds MAP mode persona profiles + initial market research.
     - **[BC-5824](https://linear.app/brite-nites/issue/BC-5824) `situation-mining`** (optional) — per-account worldview inferences can seed Lens 1 for an account-specific MAP run.
     - **[BC-5830](https://linear.app/brite-nites/issue/BC-5830) `campaign-debrief` (BC-5830 pending)** — feedback loop: when campaign-debrief ships, the transferable learnings it produces update matrix Notes columns.
   - **Does not own:**
     - Campaign execution (that's `outbound-playbook` + `launch-campaign`).
     - Copy generation (that's `email-copywriting`).
     - Angle generation (that's `creative-angles`; MSPA only consumes angles and tracks their performance).
     - Per-prospect research (that's `situation-mining`).
     - Deliverability audits (DIAGNOSE Step 5 hands off to `deliverability-audit` BC-2719 pending).

**Test**: Verify tool table has ≥ 5 rows. Verify output-path subsection lists 4 file types. Verify cross-skill boundaries has Hands-off-to / Receives-from / Does-not-own blocks with `(BC-NNNN pending)` labels on the right targets.

**Verify**: §4 has 4 subsections (Tools table / Output paths / Architectural rules / Cross-skill boundaries). BC-5830 and BC-2722 cross-links both carry `(pending)` labels.

---

### Task 8: §5 MCP Tool Reference — grouped by mode (MAP research / ITERATE EB metrics / DIAGNOSE deliverability)

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: §4 declared WHAT tools; §5 says WHEN — which workflow, in what order. Grouped by mode (not by server) because that's how the skill thinks about tool sequencing.

**Implementation**:
1. Intro paragraph referencing [`plugins/marketing/tools/integrations/email-bison.md`](../../../tools/integrations/email-bison.md) + [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) for connection details + availability probe patterns.
2. `### Workflow 1 — MAP Lens 2 parallel WebSearch (MAP mode)`: emit up to 5 `WebSearch` calls in a single assistant turn. Same retry/degrade policy as creative-angles Quick Mode Step 1 — retry once on rate-limit, then proceed with remaining queries and mark missing sources in the output artifact.
3. `### Workflow 2 — MAP Lens 3 Salesforce segment discovery (MAP mode)`: availability probe with `SELECT Id FROM User LIMIT 1`. On failure, halt MAP Lens 3 and mark Lens 3 coverage as "unavailable" in the matrix; continue MAP with Lens 1 + Lens 2 alone. Query Accounts with vertical/size/geography filters; returned rows define sourceable segments for the matrix.
4. `### Workflow 3 — ITERATE Email Bison metrics fetch (ITERATE mode)`: availability probe with `get_active_workspace_info` on the entity-routed workspace. Then `get_campaign_stats` for the batch-N campaign(s) for reply/meeting/bounce rates. Then `search_replies` + `get_replies_analytics` for qualitative Step 2.
5. `### Workflow 4 — DIAGNOSE Step 5 execution probe (DIAGNOSE mode)`: only when steps 1–4 all came up clean. Calls `get_campaign_stats` (bounce, open, reply trend) across the last N campaigns + Salesforce ActivityHistory query for Activity delivery patterns. If bounce > 3% or open < 25%, flag as execution-level root cause and hand off to `deliverability-audit` (BC-2719 pending).
6. Confirmation-gate note: none of the MCP calls this skill makes are in the MCP confirmation-gate list (no `resume_campaign`, `import_leads_to_campaign`, `archive_campaign`, etc.). All reads. No two-call gates needed — but cite the pattern for future contributors in case a write-path is added later.

**Test**: Verify 4 workflows, one per mode (MAP has two — Lens 2 and Lens 3; ITERATE has one; DIAGNOSE has one). Verify each workflow names its availability probe. Verify no confirmation gates are fabricated.

**Verify**: §5 has 4 workflow subsections. Availability probes named correctly (`SELECT Id FROM User LIMIT 1` for SF, `get_active_workspace_info` for EB). No invented confirmation gates.

---

### Task 9: §6 Operational Runbook — 5 flows (MAP happy path, ITERATE happy path, DIAGNOSE happy path, entity-switch matrix fork, ITERATE missing-prereq halt)

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: §6 turns §3 methodology + §5 tool sequencing into flows a subagent can follow end-to-end. Target 5 flows covering all 3 modes + entity-switch + precondition-halt per issue verification.

**Implementation**:
1. `### Flow 1 — MAP mode happy path` with Preconditions / Steps / Expected output / Error handling / Handoff blocks. Steps cite §5 Workflow 1 + 2, §3 MAP 6 steps, §4 output-path subsection.
2. `### Flow 2 — ITERATE mode happy path` with the same structure. Steps read the campaign-analysis input (§3 ITERATE Step 1 input), call §5 Workflow 3, classify/iterate/design-next, write matrix + batch + results.
3. `### Flow 3 — DIAGNOSE mode happy path`. Read evidence artifacts (≥ 2 results files + most-recent analysis artifact), run §3 DIAGNOSE 5-step sequence, write diagnosis file, halt at first failure level.
4. `### Flow 4 — Entity-switch matrix fork`. When operator switches from (say) Nites to Supply mid-session, the skill must fork: each entity has its own `docs/campaigns/{entity}/` directory + its own matrix. Explain the invariant: one matrix per entity, forever. Switching entities means starting or resuming a different matrix, never merging.
5. `### Flow 5 — ITERATE missing-prereq halt`. When operator picked ITERATE at Gate 2 but no `campaign-analysis` artifact exists, halt with the verbatim blocking message from Gate 4, zero tool calls fire, no artifact written. Operator runs campaign-analysis and re-invokes.
6. Each flow has Expected-output + Error-handling + Handoff subsections. Cite the sibling `(BC-NNNN pending)` targets in Handoff blocks where relevant.

**Test**: Verify 5 flows, each with the required subsection structure. Verify Flow 5 fires zero tool calls and writes zero artifacts.

**Verify**: §6 has exactly 5 flows. All 3 modes covered. Entity-switch is explicit. Missing-prereq halt is BLOCKING, not graceful-degrade.

---

### Task 10: §7 Health Scoring Rubric — 4-band rubric specific to MSPA output quality

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: Every marketing skill needs a rubric. Reviewers and evals gate on it. Must be skill-specific (not generic) and anchored to concrete observable behaviors.

**Implementation**:
1. 4-band rubric (10 / 7–9 / 4–6 / 1–3) mirroring creative-angles §7 structure.
2. **Score 10** criteria — all observable:
   - All 3 modes ran correctly when invoked (MAP 6 steps ordered, ITERATE 4 steps ordered, DIAGNOSE 5 steps in strict order with no skipping).
   - MSPA matrix rendered with all 7 columns exactly (Market / Segment / Persona / Angle / Batch / Verdict / Notes).
   - Barbell 80/20 preserved (experiment side never dropped, safe side sized at 4× experiment side).
   - All 10 Kellen's Laws present in §3 and §8.
   - Verdict labels are the five fixed tokens (`SUPER WORKS`, `KIND OF WORKS`, `DOESN'T WORK`, `DEFERRED`, `PENDING`) — no prose substitutes.
   - DIAGNOSE never skipped a level.
   - Output paths all under `docs/campaigns/{entity}/` with the correct filename templates.
   - Cross-skill handoffs fired at the right moments (ITERATE → campaign-debrief when the transferable-insight field is populated; DIAGNOSE Step 5 failure → deliverability-audit).
3. **Score 7–9** — mostly-excellent with one gap. Examples: matrix missing Notes column on one row; verdict label rendered as `"kind of works"` lowercase instead of `KIND OF WORKS`; one of the 10 laws missing from §8 but present in §3.
4. **Score 4–6** — functional but missing structural elements. Examples: DIAGNOSE skipped Step 2 (Segment) and went straight to Step 4 (Angle); barbell dropped to 90/10 without note; ITERATE output missing the Results Log section.
5. **Score 1–3** — hard failures. Any ONE drops the run:
   - DIAGNOSE skipped a level in the ordered sequence.
   - Experiment side stopped (Kellen's Law #6 violation).
   - Verdict label fabricated (prose substitute like "pretty promising").
   - Matrix row generated without evidence (e.g., a segment with no sourceable proof from Lens 3).
   - Prose narrative retrofit over unwanted results (Kellen's Law #4 violation).
   - Fabricated MCP tool name or hallucinated workspace routing.

**Test**: Read rubric back. Verify each band has ≥ 3 concrete criteria. Verify 1–3 band has "any ONE of these" phrasing so it's a hard-failure gate.

**Verify**: §7 has 4 bands. Score 10 references all 7 matrix columns. Score 1–3 lists ≥ 5 hard failures, each keyed to a §3 or §4 rule.

---

### Task 11: §8 Anti-Slop Guardrails — 4 base + 10 Kellen's Laws as `Do not X` + 3 skill-specific hard failures

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: §8 is the validation surface. 10 Kellen's Laws get re-stated here as negative rules so validation gates can match them verbatim. Mirrors creative-angles' shelf-life-as-hard-failures pattern.

**Implementation**:
1. `**Base guardrails**:` — verbatim from template (4 rules: no generic jargon, no fabricated stats, don't ignore marketing-context, no hallucinated MCP servers).
2. `**Kellen's Laws as hard failures** (each drops the run to §7 1–3 band):` — 10 `Do not X` rules, one per law:
   1. Do not personalize a generic angle — resonance beats personalization (Law #1).
   2. Do not lead with information when identity is available — identity beats information (Law #2).
   3. Do not treat a demographic filter as a segment — groups are cultural, not demographic (Law #3).
   4. Do not retrofit a narrative over unwanted results — the things that work and the things you wanted to work are not synonymous (Law #4).
   5. Do not dismiss silence — silence is data (Law #5). Matrix Notes must record the inference for any 0% reply rate.
   6. Do not stop the experiment side (Law #6). Even when the safe side crushes, the 20% runs.
   7. Do not chase percentages at 600-contact scale — qualitative beats quantitative (Law #7). Read the replies.
   8. Do not make a wrong-and-specific claim — wrong-and-specific is worse than wrong-and-general (Law #8).
   9. Do not plan the yolo slot away — the best campaigns look nothing like what you planned (Law #9). Every batch preserves one wild card.
   10. Do not treat outbound as persuasion — outbound is discovery and hypothesis validation (Law #10). "No" is valid data.
3. `**Skill-specific hard failures** (validation-gated):`
   - **Do not skip levels in the DIAGNOSE 5-step sequence.** First failure IS the root cause. Going straight to Execution (Step 5) when Market (Step 1) is broken is a §7 1–3.
   - **Do not fabricate verdict labels.** Only `SUPER WORKS`, `KIND OF WORKS`, `DOESN'T WORK`, `DEFERRED`, `PENDING` are allowed in the matrix Verdict column. Prose substitutes ("promising", "mediocre", "worth another shot") are refused.
   - **Do not stop the experiment side** — echoes Law #6 for emphasis; this is the single most-violated rule in practice.

**Test**: Verify 4 base + 10 law-derived + 3 skill-specific = 17 total guardrails. Verify each Kellen's Law has a numeric reference back to §3.

**Verify**: §8 has 3 subsections. Law count is exactly 10. Each `Do not` line cites the law number it derives from.

---

### Task 12: §9 Behavioral Tests — 8 scenarios covering all 3 modes + halt + verdict-label + Kellen's-Law paths

**Files**: `plugins/marketing/skills/message-market-fit/SKILL.md`

**Why**: Behavioral tests are the eval-scenario specifications. 6+ scenarios required by issue Verification. 8 chosen for coverage margin.

**Implementation**: 8 scenarios across Tier 1 (free assertions) + Tier 2 (tool-assisted):

Tier 1:
- `map-mode-happy-path` — MAP for Nites uphill market. Output: 2 files (mmf-matrix.md, mmf-batch-1.md). Matrix has 7 columns. 5 experiments in batch-1 with hypothesis cards. Barbell note cites 3k experiment / 12k safe.
- `iterate-missing-prereq-halt` — ITERATE selected, no campaign-analysis artifact. First response = verbatim halt message. Zero tool calls. No artifact written.
- `diagnose-first-failure-wins` — DIAGNOSE with 2 batches flat. Step 1 clean, Step 2 fails. Diagnosis names Segment as root cause, does NOT continue to Steps 3/4/5. Prescription hands off to creative-angles.
- `verdict-labels-only` — Matrix contains only the 5 fixed tokens across modes. Scenario fails on any prose substitute.
- `barbell-invariant` — Across MAP + ITERATE pair, experiment side never zeroes out. Scenario fails if 20% allocation drops in any batch design.

Tier 2:
- `kellens-law-anchor` — All 10 laws appear verbatim in §3 AND as `Do not X` in §8. Requires Read of SKILL.md.
- `entity-routing` — MAP for Nites routes EB to `mcp__emailbison-personal__*`; for Supply/Labs to `mcp__emailbison-b2b__*`. Inspect tool-call trace.
- `matrix-append-not-replace` — ITERATE on existing matrix appends Results Log rows, does NOT rewrite body. Before/after diff check.

Each scenario has a one-paragraph description in SKILL.md; full assertions + fixtures live in evals.json (Task 13).

**Test**: 8 scenarios present (≥ 6 minimum). All 3 modes covered. Tier 1 + Tier 2 split present.

**Verify**: §9 has 8 scenarios. Scenario IDs match Task 13 evals.json entries.

---

### Task 13: Write evals/evals.json — 8 scenarios matching §9

**Files**: `plugins/marketing/skills/message-market-fit/evals/evals.json` (new)

**Why**: Structured eval scenarios complement §9. JSON format enables automated eval runs.

**Implementation**:
1. Mirror creative-angles `evals/evals.json` shape: array of scenario objects, each with `id`, `description`, `tier`, `preconditions`, `prompt`, `expected_assertions`.
2. Write 8 entries matching the 8 §9 scenarios. Scenario IDs match exactly.
3. Each assertion concrete and grep-able (e.g., `output_contains: "DIAGNOSE requires ≥ 2 prior batch results files"`).
4. Validate JSON with `python3 -m json.tool`.

**Test**: `python3 -m json.tool plugins/marketing/skills/message-market-fit/evals/evals.json` exits 0.

**Verify**: File exists, 8 scenarios, valid JSON, scenario IDs match §9.

---

### Task 14: Cross-link from sibling skills

**Files**:
- `plugins/marketing/skills/creative-angles/SKILL.md` — already references MSPA at line 178; flip `(BC-5829 pending)` labels to plain cross-link once BC-5829 SKILL.md exists
- `plugins/marketing/skills/campaign-analysis/SKILL.md` — add Consumers/Feeds-Into block pointing at MSPA ITERATE mode
- `plugins/marketing/skills/gtm-strategy/SKILL.md` — add hands-off-to pointer at MSPA MAP mode
- `plugins/marketing/skills/situation-mining/SKILL.md` — add optional feeds-into pointer at MSPA MAP Lens 1

**Why**: Cross-skill discoverability. When an operator invokes campaign-analysis, they should see "next step is MSPA ITERATE" in the Consumers block.

**Implementation**:
1. Read each sibling SKILL.md. Find §4 Cross-skill boundaries or equivalent `### Consumers` / `### Feeds Into` section.
2. `creative-angles/SKILL.md`: at the existing BC-5829 references, remove any `(pending)` label since BC-5829 now ships in this PR.
3. `campaign-analysis/SKILL.md`: add Consumers row pointing at MSPA ITERATE with the artifact-path contract (`docs/campaigns/{entity}/analysis-*.md` is the input).
4. `gtm-strategy/SKILL.md`: add hands-off-to pointing at MSPA MAP.
5. `situation-mining/SKILL.md`: add optional feeds-into pointing at MSPA MAP Lens 1.

**Test**: `grep -rn "message-market-fit\|BC-5829" plugins/marketing/skills/ --include=SKILL.md` shows cross-links from all 4 sibling skills.

**Verify**: 4 sibling files edited. Each cross-link uses the canonical `[BC-5829](url) `message-market-fit`` format. No `(pending)` label on BC-5829.

---

### Task 15: Validate — `./scripts/validate.sh` + `./scripts/check-guardrails.sh`

**Files**: none; validation only.

**Why**: Final validator run. Confirms auto-discovery, section order, frontmatter, CLAUDE.md guardrails.

**Implementation**:
1. `./scripts/validate.sh 2>&1 | tee /tmp/bc-5829-validate.log` — expect exit 0; `message-market-fit` in skill enumeration.
2. `./scripts/check-guardrails.sh --claude-md CLAUDE.md 2>&1 | tee /tmp/bc-5829-guardrails.log` — expect exit 0.
3. If either fails, diagnose (section-order, unknown keys, CLAUDE.md creep) and re-run until both pass.

**Test**: Both scripts exit 0.

**Verify**: No red output. `message-market-fit` counted.

---

### Task 16: Commit, push, move issue to In Progress

**Files**: git + Linear ops.

**Implementation**:
1. `git status` — review changes.
2. `git add plugins/marketing/skills/message-market-fit/ plugins/marketing/skills/creative-angles/SKILL.md plugins/marketing/skills/campaign-analysis/SKILL.md plugins/marketing/skills/gtm-strategy/SKILL.md plugins/marketing/skills/situation-mining/SKILL.md docs/plans/BC-5829-plan.md`.
3. Commit with message citing the issue + 3-mode structure + 10 Kellen's Laws + cross-link edits.
4. `git push origin corinne/bc-5829-...`.
5. Move BC-5829 → In Progress in Linear.
6. Hand off to `/workflows:review`.

**Verify**: Commit lands. Branch pushed. Linear status updated.

---

## Task dependency notes

- Tasks 1–2 sequential (file must exist before gates land).
- Tasks 3–6 sequential (all edit §3 in order — MAP → ITERATE → DIAGNOSE → Matrix/Barbell/Laws).
- Tasks 7–9 sequential (§4 → §5 → §6 reference each other).
- Tasks 10–13 parallelizable after Task 9 (§7, §8, §9, evals.json don't depend on each other).
- Task 14 (cross-links) after Tasks 1–9 so MSPA is stable before siblings link to it.
- Task 15 (validate) last before Task 16 (ship).

## Checkpointing (per pacing memory)

Natural commit checkpoints:
- **After Task 2** — skeleton + voice. Commit: "skeleton + §1 opener + §2 gates."
- **After Task 6** — §3 complete. Commit: "§3 methodology — MAP/ITERATE/DIAGNOSE + matrix + barbell + 10 laws."
- **After Task 9** — §4 + §5 + §6. Commit: "§4 implementation + §5 tool reference + §6 runbook."
- **After Task 13** — §7 + §8 + §9 + evals. Commit: "§7 rubric + §8 anti-slop + §9 tests + evals.json."
- **After Task 14** — cross-links. Commit: "cross-links from 4 sibling skills."
- **After Task 15** — validation fixes if any.
- **Task 16** — push + Linear.

## Subagent dispatch strategy (per BC-5828 precedent)

Batched (not per-task): 4 subagents matching the 4 methodology-phase commits.

- **Subagent A (voice):** Tasks 1 + 2. Scaffold + §2 gates.
- **Subagent B (methodology):** Tasks 3 + 4 + 5 + 6. §3 complete.
- **Subagent C (implementation):** Tasks 7 + 8 + 9. §4 + §5 + §6.
- **Subagent D (validation surface):** Tasks 10 + 11 + 12 + 13. §7 + §8 + §9 + evals.json.
- **Parent agent:** Tasks 14 + 15 + 16 directly.

Not applicable: per-task dispatch (16 fresh-context subagents would re-read the in-progress SKILL.md 16 times).

## Risks

1. **Pattern drift from creative-angles.** Lower risk — sibling in context + Plan-gate check.
2. **Kellen's Law count regression.** Lower risk — verified 10 laws in Prerequisites; Task 6 + Task 11 both enumerate 1–10 with cross-refs.
3. **Output-path collision on MAP re-run.** Specific risk — MAP on an entity with an existing `mmf-matrix.md` halts and asks whether to append or replace. Tasks 3 + 9 Flow 1 cover this.
4. **Cross-skill cross-link drift** when BC-5830 or BC-2722 eventually ship. Mitigated by consistent `(BC-NNNN pending)` so a single grep finds all stale references.
5. **Subagent stream-timeout** (BC-5828 precedent). Mitigation: parent-agent recovery protocol — grep for landed content, validate evals.json with `python3 -m json.tool`, complete residuals via direct Edit.

## Verification matrix (pre-merge)

| Check | How | Source |
|---|---|---|
| SKILL.md has 9 required sections in order | Read; section-order regex grep | Issue §Verification |
| `allowed-tools` matches Tool Surface exactly | Read frontmatter | Issue §Tool Surface |
| §3 documents MAP (6 steps), ITERATE (4 steps), DIAGNOSE (5-step ordered) | Read + count | Issue §Verification |
| §3 documents MSPA matrix format (Market/Segment/Persona/Angle columns) | Read + grep column names | Issue §Verification |
| §3 documents barbell 80/20 rule | grep `80/20\|80%\|20%` | Issue §Verification |
| §3 encodes all 10 Kellen's Laws | Count enumerated laws | Issue §Verification |
| §4 documents entity-keyed matrix output paths | grep `docs/campaigns/{entity}` | Issue §Verification |
| §4 Cross-skill boundaries complete | grep 4 receives-from + 2 hands-off-to | Issue §Verification |
| §6 has ≥ 4 flows covering all 3 modes + entity-switch | Count subsection headings | Issue §Verification |
| §8 has ≥ 8 of 10 laws as `Do not X` | grep `Do not` + count | Issue §Verification |
| §9 has ≥ 6 scenarios covering all 3 modes | Count scenario IDs | Issue §Verification |
| `evals.json` has ≥ 6 scenarios | `jq '. \| length'` | Issue §Verification |
| Output paths documented (matrix/batch/results/diagnosis) all under `docs/campaigns/{entity}/` | grep paths | Issue §Verification |
| Cross-links from creative-angles + campaign-analysis + gtm-strategy + situation-mining | grep `message-market-fit\|BC-5829` in sibling SKILL.md files | Issue §Verification |
| `./scripts/validate.sh` exits 0 | Run | Issue §Verification |
| `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0 | Run | Issue §Verification |

## Acceptance

When all 16 tasks complete and the verification matrix shows 16 green rows, move BC-5829 to In Review, open PR, run `/workflows:review`, address any P1s, merge.
