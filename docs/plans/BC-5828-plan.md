# Plan: BC-5828 — Create marketing skill: creative-angles

**Issue**: [BC-5828](https://linear.app/brite-nites/issue/BC-5828) — Create marketing skill: creative-angles (Quick + Deep modes, Asymmetry Score for GTM alpha)
**Branch**: `corinne/bc-5828-create-marketing-skill-creative-angles-quick-deep-modes`
**Tasks**: 12 (estimated 90–110 min focused, subagent-per-task)

## Prerequisites

- **Reference files exist** (shipped in BC-5823): `plugins/marketing/references/creative-thinking-models.md`, `hidden-signals-library.md`, `shelf-life-patterns.md`. Verified present.
- **Deep Mode prereq skill exists**: `plugins/marketing/skills/situation-mining/SKILL.md` (BC-5824). Verified present — this plan will cite it for the Deep Mode handoff contract.
- **Template**: `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — 9-section scaffold.
- **Sibling pattern anchors**: `plugins/marketing/skills/campaign-analysis/SKILL.md` (BC-2721) and `plugins/marketing/skills/situation-mining/SKILL.md` (BC-5824) have shipped against the same 9-section template — use both as reference for section depth, tone, and evals.json shape.
- **Target directory absent**: `plugins/marketing/skills/creative-angles/` does not exist — this is a net-new skill, no prior content to preserve.
- **CDR alignment**: CDR INDEX check skipped — Context7 handbook library was not resolved at session start (no CDR source to query). Proceeding per writing-plans skill's advisory-only rule.
- **Precedent alignment**:
  - Aligns with **BC-2721** (sequential-thinking for multi-axis runbook design; `discover_tools` at Plan gate to prevent tool-name drift — applied to reference-file names here since this skill calls no MCP tools).
  - Aligns with **BC-5824** (fetch canon during brainstorm/design, not execution — reference files are read during planning, cited by path in the skill, not re-fetched at runtime).
  - Aligns with **BC-5797** (factual-anchor recipe — every forcing function name, shelf-life decay category, and cross-skill reference is verified against the canonical source file before committing).
  - Aligns with **BC-5825** (skeleton-vs-skin split only when fan-out dominates — single skill, no fan-out; keep bundled in one PR).

## Tasks

### Task 1: Create skill directory and scaffold SKILL.md frontmatter + §1 Opener

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md` (new), `plugins/marketing/skills/creative-angles/evals/` (new dir, placeholder)
**Why**: Lands the file Claude's skill-resolver picks up. Frontmatter and §1 Opener set skill identity, trigger phrases, and user-facing purpose.

**Implementation**:
1. Create `plugins/marketing/skills/creative-angles/` and `plugins/marketing/skills/creative-angles/evals/`.
2. Write `SKILL.md` frontmatter:
   - `name: creative-angles`
   - `description:` — single paragraph covering the GTM alpha concept, triggers ("creative gtm", "creative angles", "hidden signals for", "GTM alpha", "creative outbound for", "non-obvious angles", "experimental campaigns"), and a one-line hands-off note to email-copywriting (ALPHA angles) / MSPA (populates A dimension) / content workflows (INTERESTING redirect). Upstream attribution: `Adapted from Revgrowth1/ai-gtm-workflows workflow 06 (MIT).`
   - `user-invocable: true`
   - `allowed-tools: mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob`
   - `metadata: { version: 0.1.0, upstream: Revgrowth1/ai-gtm-workflows, category: Outbound Lead Gen }`
3. Write `# Creative Angles` title.
4. Write §1 opener (1 paragraph, sibling-pattern length ~80–120 words): audience (BDR / RevOps / marketing operators running experimental campaigns), business problem (Brite outbound drifts toward proven playbooks; the 20% experiment allocation in the barbell strategy needs a disciplined way to generate non-obvious angles from hidden signals), outcome (ranked Asymmetry-Scored angles with ALPHA / PROMISING / INTERESTING / COMMODITY verdicts). Explain GTM alpha inline: knowing something competitors don't, like financial alpha — if it appears in a Clay template it's priced in. Do NOT list tool names or repo paths here (those live in §4 and §5 per template guidance).

**Test**:
- Run: `./scripts/validate.sh 2>&1 | head -40`
- Expected: validator picks up the new skill directory; frontmatter parses (no unknown keys); no section-order errors yet (sections 2–9 arrive in subsequent tasks — acceptable per incremental task convention, but if validator is strict about presence, add stub headers `## Before Starting` through `## Behavioral Tests` with a single `TODO(BC-5828)` line each so order is valid from the start).

**Verify**: File exists at `plugins/marketing/skills/creative-angles/SKILL.md`. Frontmatter has all 6 required keys. §1 opener is a single paragraph, does not mention tool names.

---

### Task 2: Write §2 Before Starting — marketing-context check, mode selection, Deep Mode prereq gate

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: §2 is the gate layer. Three gates must resolve before Quick Mode or Deep Mode runs. This is where sibling precedent BC-5824 (soft-gate marketing-context) and issue's Deep Mode 14-day prereq live.

**Implementation**:
1. Write the verbatim sibling marketing-context soft gate: "Check for product marketing context first. If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: 'Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.' Then continue using only user-provided information."
2. Write the **Mode selection gate** — `AskUserQuestion` for Quick Mode (default) vs Deep Mode. Explain that Quick Mode = 5 parallel WebSearches + 4 steps + 3–5 angles, Deep Mode = Quick Mode + 7 additional WebSearches + worldview-conflict analysis + 5–8 angles + mandatory shelf-life on ALPHA/PROMISING. Cite §3 for the methodology details.
3. Write the **Deep Mode prereq gate** — if user picked Deep Mode, skill MUST check for `docs/research/situations/{domain}-{YYYY-MM-DD}.md` file less than 14 days old. Glob pattern: `docs/research/situations/{domain}-*.md`. If missing or stale (> 14 days), halt with blocking message: "Deep Mode requires situation-mining output less than 14 days old for `{domain}`. Run `situation-mining` first, then resume." Do NOT silently fall back to Quick Mode — halt and wait for operator.
4. Write the **Disambiguation / input gate** — require `domain` and (for Deep Mode only) the situation-mining file path. For Quick Mode, `company_name` and `domain` are enough.

**Test**:
- Read the section. Verify three gates render (marketing-context soft gate, mode selection `AskUserQuestion`, Deep Mode 14-day staleness check with blocking message).
- Run: `./scripts/validate.sh 2>&1 | grep -i "creative-angles"`
- Expected: no new validation errors.

**Verify**: §2 has exactly three gate subsections. Deep Mode prereq check is BLOCKING, not graceful-degrade. Marketing-context check is the verbatim BC-5824 sibling string.

---

### Task 3: Write §3 Methodology part 1 — Quick Mode (4 steps, 5 parallel searches)

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: Quick Mode is the default path. Needs exact 5 search patterns, 4 ordered steps, reference to the 5 forcing functions (fully detailed in Task 5), and output contract (3–5 angles scored via Asymmetry Score).

**Implementation**:
1. Write §3 heading: `## Methodology`.
2. Intro paragraph (~80 words): three frameworks govern this skill — **5 forcing functions** (lateral thinking from creative-thinking-models.md), **Asymmetry Score** (6-dimension verdict rubric), **shelf-life decay** (alpha expiration rules). State the barbell positioning: 90% via `outbound-playbook`, 10% experiments via this skill.
3. `### Quick Mode — default path` subheading. State: "Lightweight research, fast output. Best for initial exploration or when situation-mining output is unavailable."
4. **Step 1: Five parallel WebSearch queries** — enumerate verbatim per issue scope:
   - Blog content: `site:{{domain}} blog`
   - Reviews / complaints: `{{company_name}} reviews OR complaints OR problems`
   - Competitors: `{{company_name}} competitors OR alternatives`
   - Regulation / compliance: `{{company_name}} {{industry}} regulation OR compliance OR deadline`
   - Hiring: `{{company_name}} careers OR hiring`
5. **Step 2: Extract signal clusters.** Define: each cluster is 2+ independent data points that together reveal something non-obvious. Single data points are noise, not signals. Minimum 2 per cluster is a hard rule — Anti-Slop §8 will enforce.
6. **Step 3: Apply 5 forcing functions.** Cross-reference `plugins/marketing/references/creative-thinking-models.md` for full worked examples. Names must match the reference file exactly: **Inversion (Munger)**, **Adjacent Transfer**, **Timing Arbitrage**, **Specificity Escalator**, **Ecosystem Gap Analysis**. Add a sentence per function summarizing what it does (≤ 25 words each).
7. **Step 4: Generate 3–5 angles total, score each with Asymmetry Score, output via §4 Campaign Strategy template.**

**Test**:
- Grep SKILL.md for each of the 5 forcing-function names — must match creative-thinking-models.md exactly (no "Munger Inversion", "Adjacent Industry Transfer", etc.).
- Command: `grep -E "(Inversion \(Munger\)|Adjacent Transfer|Timing Arbitrage|Specificity Escalator|Ecosystem Gap Analysis)" plugins/marketing/skills/creative-angles/SKILL.md | wc -l`
- Expected: ≥ 5 (each name appears at least once in §3 Quick Mode).

**Verify**: Quick Mode has exactly 4 numbered steps. 5 search patterns are enumerated. All 5 forcing-function names are cited verbatim and spelled identically to creative-thinking-models.md §1–§5 headings.

---

### Task 4: Write §3 Methodology part 2 — Deep Mode (6 steps, 7 additional searches, worldview-conflict analysis)

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: Deep Mode is the higher-signal path. Distinct from Quick Mode in depth (12 total searches), prereq dependency (situation-mining < 14 days), and mandatory worldview-conflict analysis step.

**Implementation**:
1. `### Deep Mode — requires situation-mining output less than 14 days old` subheading.
2. Reference §2 Deep Mode prereq gate. State: situation-mining must be in conversation context or the skill halted in §2.
3. **Step 1: Load situation-mining output** from `docs/research/situations/{domain}-{YYYY-MM-DD}.md`.
4. **Step 2: Run 7 additional WebSearch queries** — enumerate verbatim per issue scope:
   - G2 / Trustpilot reviews: `{{company_name}} site:g2.com OR site:trustpilot.com`
   - Events / conferences: `{{company_name}} speaking OR keynote OR conference`
   - Regulation deep: `{{industry}} regulation {{year}} deadline OR rule OR enforcement`
   - Partnerships: `{{company_name}} partnership OR integration OR alliance`
   - Senior hiring: `{{company_name}} "VP" OR "Chief" OR "Head of" LinkedIn`
   - Financial signals: `{{company_name}} funding OR revenue OR layoff OR earnings`
   - Reddit / HN sentiment: `{{company_name}} site:reddit.com OR site:news.ycombinator.com`
5. **Step 3: Worldview conflict analysis.** Cross-reference situation-mining's stated worldviews with deep signals. The richest angles live in contradictions (stated "AI-first" while hiring 50 manual data entry roles = a gap you can address). **Minimum 1 worldview conflict per Deep Mode output.** Never weaponize contradictions — frame as curiosity, not gotcha.
6. **Step 4: Cross-reference `plugins/marketing/references/hidden-signals-library.md`** for known signal patterns in prospect's industry. Cite the Brite-entity signal rows (Municipalities, HOAs, Universities — per issue's Brite differential claim) as primary lookup targets for Nites/Labs prospects.
7. **Step 5: Generate 5–8 angles** using all 5 forcing functions plus worldview conflicts.
8. **Step 6: Score with Asymmetry Score, mandatory shelf-life warning on ALPHA and PROMISING angles.** Cross-reference §3 Asymmetry Score subsection (Task 5) and `plugins/marketing/references/shelf-life-patterns.md` for decay categories.

**Test**:
- Count search patterns: Deep Mode must list exactly 7 additional queries (not 5, not 8). `grep -c "^[0-9]*\. " <(sed -n '/### Deep Mode/,/### [A-Z]/p' plugins/marketing/skills/creative-angles/SKILL.md)` — manual count is fine.
- Grep for "worldview conflict" — minimum 1 occurrence, and the "never weaponize" guardrail must be present in §3 (will also be repeated in §8 Anti-Slop).

**Verify**: Deep Mode has exactly 6 numbered steps. 7 search patterns enumerated (verbatim from issue). Worldview-conflict analysis is mandatory (minimum 1 per run). "Never weaponize" framing is present.

---

### Task 5: Write §3 Methodology part 3 — Asymmetry Score formula, verdict mapping, shelf-life requirements

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: The scoring rubric, verdict taxonomy, and shelf-life rules are the load-bearing outputs of every angle. Must be reproducible — a reviewer reading a finished artifact can recompute the score and arrive at the same verdict.

**Implementation**:
1. `### Asymmetry Score` subheading.
2. Write the formula verbatim (code block):
   ```
   Score = (Novelty*2 + Evidence*2 + Timing*1.5 + Simplicity*1 + ShelfLife*1 + Downside*0.5) / 8
   ```
3. Per-dimension rubric — 6 dimensions, each with Low (1–3) / Medium (4–6) / High (7–10) bands per issue scope. Verbatim content:
   - **Novelty (2x):** Low = angle appears in Clay templates / common playbooks. Medium = uncommon but discoverable. High = no one is using this angle.
   - **Evidence Density (2x):** Low = single data point, high speculation. Medium = 2–3 data points, moderate inference. High = 4+ data points, strong inference chain.
   - **Timing Urgency (1.5x):** Low = evergreen, no time pressure. Medium = seasonal / cyclical. High = deadline-driven, narrow window.
   - **Execution Simplicity (1x):** Low = custom tooling needed. Medium = manual research. High = build list in under 1 hour.
   - **Shelf Life (1x):** Low = under 1 month. Medium = 3–6 months. High = 6+ months.
   - **Downside Cap (0.5x):** Low = risk of negative brand perception. Medium = neutral worst case. High = worst case = they ignore the email.
4. `### Verdict mapping` subheading. Four tiers (issue-verbatim):
   - **Score 8.0+ → ALPHA.** Test immediately. Small batch (50–100 prospects). Measure response rate before scaling.
   - **Score 6.0–7.9 → PROMISING.** Refine evidence density or timing, then test.
   - **Score 4.0–5.9 → INTERESTING.** Too creative for cold outbound. Redirect to content as thought leadership.
   - **Score < 4.0 → COMMODITY.** Discard entirely. Use standard campaign ideation instead.
5. `### Shelf-life requirements` subheading. State: every ALPHA and PROMISING angle MUST include (a) shelf life estimate citing a decay category from `plugins/marketing/references/shelf-life-patterns.md`, (b) decay trigger — what would kill this angle, (c) refresh date — when to re-evaluate. Missing any of the three = Anti-Slop §8 violation (drops Rubric to 1–3 band).

**Test**:
- Grep formula: `grep -F "Score = (Novelty*2 + Evidence*2 + Timing*1.5 + Simplicity*1 + ShelfLife*1 + Downside*0.5) / 8" plugins/marketing/skills/creative-angles/SKILL.md` — must match verbatim.
- Grep verdicts: `grep -E "^(.*\*\*)?ALPHA(.*\*\*)?$" plugins/marketing/skills/creative-angles/SKILL.md` — all 4 labels (ALPHA, PROMISING, INTERESTING, COMMODITY) must appear in §3.
- Verify score boundaries: 8.0+, 6.0–7.9, 4.0–5.9, below 4.0 — all 4 ranges present.

**Verify**: Formula matches issue spec exactly. 4 verdict tiers have exactly the score bounds from the issue. Shelf-life requirements name 3 mandatory sub-fields (estimate, decay trigger, refresh date).

---

### Task 6: Write §4 Brite Implementation — tool table, cross-skill boundaries, Brite-entity signals, output path

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: §4 translates portable methodology into Brite's concrete stack. Cross-skill boundaries are especially important — the skill hands off to 3 downstream skills (email-copywriting, MSPA, content) and receives from 3 upstream (situation-mining, ICP-scoring, campaign-analysis/debrief).

**Implementation**:
1. `### Tools this skill calls` subheading — table with 4 rows:
   - WebSearch — public web — §3 Quick Mode Step 1 + Deep Mode Step 2 — Primary signal research, no availability check needed.
   - WebFetch — public web — §3 Quick/Deep when search snippets are insufficient — Backup; use sparingly.
   - Salesforce MCP (`run_soql_query`) — `brite-salesforce` prod org — Optional, §6 ALPHA-cross-check runbook — ADR 2a: SF is CRM SoR. Availability check first (`SELECT Id FROM User LIMIT 1`); degrade gracefully if unavailable.
   - Read — local — load situation-mining artifact in Deep Mode, load reference files.
   - Write — local — emit `docs/research/angles/{domain}-{YYYY-MM-DD}.md` artifact.
2. `### Brite-entity signal-library additions` subsection. State: per hidden-signals-library.md, Brite adds 3 industry tables (Entertainment Venues for Labs, Landscape/Hardscape Contractors for Supply-boundary, HOAs/Property Management for Nites) on top of the 7 upstream industries. Deep Mode Step 4 preferentially queries these Brite tables for Nites/Labs prospects. Cite the handbook 23-vertical taxonomy (6 Active + 8 Exploring + 9 Future, Nites + Labs only — Supply verticals excluded per BC-5823 precedent).
3. `### Architectural rules that apply` — 5 bullets:
   - **Every angle requires a signal cluster (2+ data points).** Single data points are noise. §8 Anti-Slop enforces.
   - **Every score requires a cited evidence chain.** Asymmetry Score is derived from named data points with URLs — score-without-evidence is slop.
   - **Worldview contradictions are framing tools, not gotchas.** Never weaponize contradictions against the prospect.
   - **ALPHA and PROMISING angles carry mandatory shelf-life metadata.** 3 sub-fields (estimate, decay trigger, refresh date).
   - **Deep Mode halts on stale situation-mining.** No graceful degrade to Quick Mode — the operator picks or situation-mining runs.
4. `### Cross-skill boundaries` subsection:
   - **Hands off to:**
     - `email-copywriting` (BC-5825) when the operator selects an ALPHA angle + offer tier → copy generation.
     - `message-market-fit` / MSPA (BC-5829) when the operator wants to populate the A dimension of an MSPA experiment matrix.
     - Content workflows (out-of-scope for Brite today — surface as "Save INTERESTING angles to `docs/content/ideas/` for thought-leadership redirect per §6 runbook").
   - **Receives from:**
     - `situation-mining` (BC-5824) — Deep Mode prereq, same-turn context.
     - `icp-scoring` (BC-5831, optional, future) — segment context for angle generation.
     - `campaign-analysis` / `campaign-debrief` (BC-2721 / BC-5830, optional) — avoid repeating tested angles.
   - **Does not own:**
     - Per-prospect research (that's situation-mining).
     - Copy generation (that's email-copywriting).
     - Launch mechanics (that's `/marketing:launch-campaign`).
     - Test design or next-batch experimentation (that's MSPA).
5. `### Output artifact` subsection. Path: `docs/research/angles/{domain}-{YYYY-MM-DD}.md`. Schema:
   ```yaml
   ---
   domain: example.com
   mode: quick | deep
   angles_count: 3-8
   alpha_count: 0-N
   generated_at: 2026-04-21T14:30:00Z
   situation_mining_source: docs/research/situations/example.com-2026-04-15.md  # deep mode only
   ---
   ```
   Body sections: **1. Signal Clusters** (2+ data points each, with source URLs inline). **2. Generated Angles** (3–8 rows with forcing function attributed, Asymmetry Score computed, verdict assigned). **3. ALPHA / PROMISING shelf-life block** (estimate, decay trigger, refresh date per mandatory angle). **4. Worldview Conflicts** (Deep Mode only). **5. Handoff block** (for ALPHA → email-copywriting; INTERESTING → content).

**Test**:
- Run `./scripts/validate.sh` — no new errors.
- Grep cross-skill boundaries — must name BC-5824, BC-5825, BC-5829 explicitly with Linear URL format.
- Grep architectural rules — must have 5 bullets.

**Verify**: §4 has 4 subsections (tool table, Brite-entity signal-library additions, architectural rules, cross-skill boundaries, output artifact). Output path is exactly `docs/research/angles/{domain}-{YYYY-MM-DD}.md`. Frontmatter schema has 5 required keys (domain, mode, angles_count, alpha_count, generated_at) + 1 conditional (situation_mining_source).

---

### Task 7: Write §5 MCP Tool Reference — WebSearch workflows + optional SF MCP

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: §5 is WHEN tools are called — grouped by workflow, not by server. Three workflows: Quick Mode 5-search batch, Deep Mode 7-search batch, optional SF ALPHA-cross-check.

**Implementation**:
1. `### Workflow 1 — Quick Mode parallel search (always runs)` — 5 parallel `WebSearch` calls in single turn with the 5 substitution patterns from §3 Task 3. No availability check (WebSearch is always available). On rate-limit or transient failure of any single query, retry once with exponential backoff; if still failing, proceed with remaining queries and drop the affected angle's Evidence dimension.
2. `### Workflow 2 — Deep Mode 7-query batch (runs after Workspace 1)` — 7 parallel `WebSearch` calls in single turn with the 7 patterns from §3 Task 4. Same retry/degrade policy.
3. `### Workflow 3 — WebFetch deep-read (backup)` — when a search snippet is insufficient to ground a claim, call `WebFetch` on the specific URL. Do NOT use WebFetch as default.
4. `### Workflow 4 — Salesforce ALPHA cross-check (optional)` — only when a generated ALPHA angle targets an existing Brite Salesforce Account. Sequence: (a) availability check `run_soql_query` with `SELECT Id FROM User LIMIT 1` (verified probe per BC-5534 findings §Q1), (b) Account lookup on domain, (c) pull Activity history / Opportunity history as additional Evidence data points to strengthen the angle's score. On SF unavailable or no Account match, skip silently — do not halt.

**Test**:
- Grep workflow count: 4 workflows.
- Grep SF availability check pattern: `SELECT Id FROM User LIMIT 1` — must match sibling situation-mining's verified probe.
- Confirm no invented tool names — only `WebSearch`, `WebFetch`, `run_soql_query` should appear in §5.

**Verify**: §5 has exactly 4 workflows. Every workflow names its exact tool(s). Workflow 4 has a no-halt degrade path.

---

### Task 8: Write §6 Operational Runbook — 5 flows (Quick default, Deep with situation-mining, missing-prereq halt, ALPHA handoff, INTERESTING-to-content redirect)

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: §6 is the step-by-step procedural layer that a fresh subagent follows. 4–8 flows per template; issue scope §Execution Protocol names 4–8 runbook tasks. Pick 5 that cover the happy paths and critical failure modes.

**Implementation**:
1. `### Flow 1 — Quick Mode standard run (default path)` — preconditions (§2 gates resolved, mode = Quick), steps (Run §5 Workflow 1 → extract signal clusters → apply 5 forcing functions → score → verdict-map → write artifact to `docs/research/angles/{domain}-{YYYY-MM-DD}.md` → offer handoff), expected output (3–5 angles with verdicts; ALPHA/PROMISING carry shelf-life metadata), error handling, handoff.
2. `### Flow 2 — Deep Mode with situation-mining handoff` — preconditions (§2 gates, mode = Deep, situation-mining artifact < 14 days in context), steps (Load situation-mining → Run §5 Workflow 1 + Workflow 2 → worldview-conflict analysis against situation-mining's stated worldviews → cross-reference hidden-signals-library for Brite-entity industry rows → apply all 5 forcing functions + worldview conflicts → score → verdict-map → write artifact → offer handoff), expected output (5–8 angles with minimum 1 worldview conflict).
3. `### Flow 3 — Deep Mode missing-prereq halt` — preconditions (§2 Deep Mode gate failed — no situation-mining < 14 days), steps (Halt before any WebSearch → surface blocking message: "Deep Mode requires situation-mining output less than 14 days old for `{domain}`. Run `situation-mining` first, then resume.") — do NOT silently fall back to Quick Mode. Operator explicitly picks one.
4. `### Flow 4 — ALPHA-to-email-copywriting handoff` — preconditions (≥1 ALPHA angle generated), steps (present ALPHA angle with its Asymmetry Score + shelf-life block → ask operator to select offer tier → hand off to `email-copywriting` with {angle, situation-mining-artifact-if-deep, offer-tier} tuple).
5. `### Flow 5 — INTERESTING-to-content redirect` — preconditions (≥1 INTERESTING angle generated), steps (collect all INTERESTING angles → write to `docs/content/ideas/{domain}-{YYYY-MM-DD}.md` → surface to operator: "Too creative for cold outbound. Saved N angles for thought-leadership redirect."). No cross-skill handoff today (content workflows not yet implemented); the artifact is the hand-back.

**Test**:
- Count flows: exactly 5.
- Grep Flow 3 for "Halt" or "halt" — must be present and explicit.
- Grep Flow 4 for "email-copywriting" and Flow 5 for INTERESTING redirect path `docs/content/ideas/`.

**Verify**: §6 has exactly 5 flows. Each flow has preconditions + steps + expected output + error handling + handoff fields. Flow 3 (missing-prereq) is a hard halt, not graceful degrade.

---

### Task 9: Write §7 Health Scoring Rubric + §8 Anti-Slop Guardrails

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`
**Why**: §7 is the reviewer rubric (4 bands: 10 / 7–9 / 4–6 / 1–3). §8 is 4 base guardrails + 4+ skill-specific. Both feed the validation that reviews agents run against output.

**Implementation §7**:
1. `## Health Scoring Rubric` section. 4 bands with skill-specific criteria:
   - **10:** Both modes correct (Quick = 4 steps + 5 searches / Deep = 6 steps + 7 searches); all 5 forcing functions named verbatim per creative-thinking-models.md; Asymmetry Score formula applied with all 6 dimensions weighted correctly; verdict assignment exactly matches the 4 score bounds (8.0+, 6.0–7.9, 4.0–5.9, <4.0); every ALPHA and PROMISING angle has shelf-life metadata (estimate + decay trigger + refresh date) citing shelf-life-patterns.md decay category; every cluster has ≥ 2 data points with source URLs; worldview-conflict analysis runs in Deep Mode and names ≥ 1 conflict; Brite-entity signals from hidden-signals-library.md are cited when the prospect is Nites/Labs; cross-skill handoff (ALPHA → email-copywriting, INTERESTING → content) surfaced per §6.
   - **7–9:** Mostly excellent with one gap — e.g. one forcing function applied but spelled as "Munger Inversion" instead of "Inversion (Munger)"; one ALPHA angle missing refresh date but has estimate + decay trigger; shelf-life cites decay category but not a specific row in shelf-life-patterns.md.
   - **4–6:** Functional but missing structural elements — e.g. Quick Mode ran with 4 searches instead of 5; Asymmetry Score computed but one dimension (e.g. Downside Cap) weighted at 1.0 instead of 0.5; INTERESTING angles pitched into cold outbound instead of redirected to content.
   - **1–3:** Hard failure — any ONE of: angle generated from a single data point (violates cluster rule); angle score without cited evidence chain; worldview contradiction weaponized against prospect; ALPHA or PROMISING angle missing shelf-life metadata; Deep Mode ran without situation-mining prereq (graceful-degrade violation); invented forcing function name not in creative-thinking-models.md; invented shelf-life category not in shelf-life-patterns.md.

**Implementation §8**:
1. `## Anti-Slop Guardrails` section.
2. 4 base guardrails (verbatim from template):
   - Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
   - Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
   - Do not produce output that ignores `docs/marketing-context.md`.
   - Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).
3. 5 skill-specific guardrails (per issue non-goals + Task 5 §3 rules):
   - **Do not generate angles without signal-cluster evidence.** Single data points are noise. Minimum 2 independent data points per cluster is a hard rule.
   - **Do not run Deep Mode without situation-mining < 14 days.** Halt and instruct the operator to run situation-mining first — no silent fall-back to Quick Mode.
   - **Do not score without citing the evidence chain.** Every Asymmetry Score dimension is defended by named data points with source URLs. Score-without-evidence is a §7 1–3 hard failure.
   - **Do not skip shelf-life on ALPHA or PROMISING angles.** 3 sub-fields required (estimate citing shelf-life-patterns.md decay category, decay trigger, refresh date). Missing any → §7 1–3.
   - **Do not weaponize worldview contradictions.** Frame contradictions as curiosity openings ("Noticed you say X while hiring for Y — how are you thinking about that bridge?"), never as gotchas.
   - **Do not manufacture fake urgency for Timing Arbitrage.** Urgency must be real — public deadline, regulatory cycle, known competitive move. Fabricated urgency is deliverability poison and §7 1–3.

**Test**:
- Grep rubric band 10 for "forcing functions", "Asymmetry Score", "shelf-life" — all must appear.
- Grep §8 for base count: exactly 4 base guardrails. Skill-specific: ≥ 4 (issue verification line). Total ≥ 8.
- Grep for the 5 forcing-function names in the rubric — all 5 must appear.

**Verify**: §7 has all 4 bands. §8 has exactly 4 base + 5 skill-specific (total 9) guardrails. No em-dashes in anti-slop body text (sibling pattern check).

---

### Task 10: Write §9 Behavioral Tests + create evals/evals.json with 6+ scenarios

**Files**: `plugins/marketing/skills/creative-angles/SKILL.md`, `plugins/marketing/skills/creative-angles/evals/evals.json` (new)
**Why**: §9 in SKILL.md lists scenarios in prose; evals.json has structured assertions for automated runs. Both must have ≥ 6 scenarios per issue verification.

**Implementation §9 (SKILL.md)**:
1. `## Behavioral Tests` section with Tier 1 + Tier 2 split (sibling pattern).
2. Tier 1 (no tool calls needed) — 4 scenarios:
   - `quick-mode-happy-path` — Given `company_name: "Denver Parks & Rec"`, `domain: "denvergov.org"`, mode = Quick, the skill runs 5 parallel WebSearch calls, extracts ≥ 2 signal clusters, applies all 5 forcing functions, generates 3–5 angles, and each angle carries a computed Asymmetry Score + verdict label.
   - `deep-mode-missing-prereq-halt` — Given mode = Deep and no situation-mining artifact under `docs/research/situations/` less than 14 days old, the skill's first response is the verbatim halt message "Deep Mode requires situation-mining output less than 14 days old for `{domain}`. Run `situation-mining` first, then resume." — no WebSearch calls fire.
   - `shelf-life-mandate` — Given a generated ALPHA angle, the output artifact's ALPHA block contains 3 sub-fields (estimate citing a decay category from shelf-life-patterns.md, decay trigger, refresh date). Missing any → fail.
   - `commodity-discard` — Given a scored angle below 4.0, the output artifact shows verdict `COMMODITY` with action "Discard entirely. Use standard campaign ideation instead." — the angle is NOT carried forward to §4 Campaign Strategy output.
3. Tier 2 (tool-assisted / file-read) — 2 scenarios:
   - `deep-mode-worldview-conflict` — Given a valid situation-mining artifact + mode = Deep, the output §3 Worldview Conflicts block contains ≥ 1 conflict with the framing pattern "Stated: {worldview A}. Evidence: {conflicting data point}. Curiosity opening: {question}." — and the framing is NOT gotcha-style.
   - `reference-file-name-anchor` — Given any run, all 5 forcing-function names appear verbatim per creative-thinking-models.md §1–§5 (Inversion (Munger), Adjacent Transfer, Timing Arbitrage, Specificity Escalator, Ecosystem Gap Analysis). No invented aliases.

**Implementation evals.json**:
1. JSON schema matches sibling campaign-analysis/evals/evals.json: `{ skill, version, scenarios: [...] }`.
2. Each scenario: `id, tier, description, input, assertions[]`.
3. Populate 6 scenarios matching §9 (1:1 by `id`).

**Test**:
- Validate JSON: `python3 -c "import json; json.load(open('plugins/marketing/skills/creative-angles/evals/evals.json'))"` → exit 0.
- Count scenarios: `jq '.scenarios | length' plugins/marketing/skills/creative-angles/evals/evals.json` → 6.
- Grep §9 scenario IDs in evals.json — each ID appears exactly once in SKILL.md §9 and exactly once in evals.json.

**Verify**: §9 has ≥ 6 scenarios with a Tier 1 / Tier 2 split. evals.json parses as JSON, has 6 scenarios with IDs matching §9.

---

### Task 11: Cross-link §Consumers in the 3 reference files + verify directory auto-discovery

**Files**: `plugins/marketing/references/creative-thinking-models.md`, `plugins/marketing/references/hidden-signals-library.md`, `plugins/marketing/references/shelf-life-patterns.md`
**Why**: Issue verification line: "All 3 reference files list this skill in §Consumers." Keeps the reverse-index discoverable — a future skill author browsing shelf-life-patterns.md sees that creative-angles consumes it.

**Implementation**:
1. Open each of the 3 reference files. Locate (or create) `## Consumers` section near the bottom.
2. Append: `- [creative-angles](../skills/creative-angles/SKILL.md) — [brief description of how this skill uses this reference: e.g., "applies the 5 forcing functions in Quick Mode Step 3 and Deep Mode Step 5"]`.
3. If a §Consumers section doesn't exist in a file, add it with one entry (situation-mining if already consuming) + creative-angles.
4. Verify directory auto-discovery: the skill registration is via the plugin.json skills glob — no explicit registration needed. Confirm by running `./scripts/validate.sh` and checking the output lists `creative-angles` among the marketing plugin's skills.

**Test**:
- Grep each reference file: `grep -c "creative-angles" plugins/marketing/references/{creative-thinking-models,hidden-signals-library,shelf-life-patterns}.md` → ≥ 1 per file.
- Run `./scripts/validate.sh 2>&1 | grep -i creative-angles` → skill is discovered.

**Verify**: All 3 reference files have creative-angles in their §Consumers section. Validator lists the skill as registered.

---

### Task 12: Run full validation — `./scripts/validate.sh` + `./scripts/check-guardrails.sh`

**Files**: No edits unless validation fails.
**Why**: Final verification that the skill ships clean through the CI-equivalent local checks.

**Implementation**:
1. Run `./scripts/validate.sh` — exit 0 required per issue verification line.
2. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — exit 0 required. This enforces CLAUDE.md size + anti-slop on files the plugin ships.
3. If either fails, read the error output, fix the underlying issue in SKILL.md / evals.json / reference files, and re-run.

**Test**:
- Command: `./scripts/validate.sh && echo "VALIDATE OK" && ./scripts/check-guardrails.sh --claude-md CLAUDE.md && echo "GUARDRAILS OK"`
- Expected: both `OK` lines print; exit 0.

**Verify**: Both scripts exit 0. No warnings tied to `creative-angles`.

---

## Task Dependencies

- Tasks 1–10 are strictly sequential — each builds on the prior section of SKILL.md.
- Task 11 (cross-links in reference files) depends on Task 1 (skill exists so the link target is valid) and Task 6 (§4 published — reference file §Consumers entries describe how the skill uses the reference).
- Task 12 (full validation) depends on Tasks 1–11 — nothing to validate before the content is in place.
- **No parallelizable tasks.** Sequential subagent-per-task execution is the right fit for this plan.

## Verification Checklist

- [ ] `plugins/marketing/skills/creative-angles/SKILL.md` exists with frontmatter containing all 6 required keys, no unknown keys
- [ ] File contains all 9 sections in required order (Frontmatter → H1 → Before Starting → Methodology → Brite Implementation → MCP Tool Reference → Operational Runbook → Health Scoring Rubric → Anti-Slop Guardrails → Behavioral Tests)
- [ ] `allowed-tools` exactly matches issue Tool Surface: `mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob` — no Serper, no Apollo, no extra servers
- [ ] §3 Methodology documents Quick Mode (5 searches + 4 steps) AND Deep Mode (7 searches + 6 steps with situation-mining prereq)
- [ ] §3 Methodology names all 5 forcing functions verbatim per creative-thinking-models.md: `Inversion (Munger)`, `Adjacent Transfer`, `Timing Arbitrage`, `Specificity Escalator`, `Ecosystem Gap Analysis`
- [ ] §3 Methodology documents exact Asymmetry Score formula with all 6 dimensions and weights: `Score = (Novelty*2 + Evidence*2 + Timing*1.5 + Simplicity*1 + ShelfLife*1 + Downside*0.5) / 8`
- [ ] §3 Methodology documents all 4 verdict tiers with exact score bounds (ALPHA 8.0+, PROMISING 6.0–7.9, INTERESTING 4.0–5.9, COMMODITY < 4.0) + action per tier
- [ ] §3 Methodology mandates shelf-life warning on every ALPHA and PROMISING angle (estimate + decay trigger + refresh date), citing shelf-life-patterns.md decay categories
- [ ] §4 Brite Implementation documents cross-skill boundaries (receives from situation-mining; hands off to email-copywriting, MSPA, content workflows)
- [ ] §4 Output artifact path documented as `docs/research/angles/{domain}-{YYYY-MM-DD}.md` with YAML frontmatter schema
- [ ] §6 Operational Runbook has ≥ 4 distinct flows including Deep Mode missing-prereq halt
- [ ] §8 Anti-Slop Guardrails has ≥ 4 skill-specific rules including "single data points are noise" and "never weaponize contradictions"
- [ ] §9 Behavioral Tests has ≥ 6 scenarios including Deep Mode missing-prereq halt + COMMODITY-discard + shelf-life-mandate
- [ ] `plugins/marketing/skills/creative-angles/evals/evals.json` parses as valid JSON and has ≥ 6 scenarios with IDs matching §9
- [ ] All 3 reference files (`creative-thinking-models.md`, `hidden-signals-library.md`, `shelf-life-patterns.md`) list `creative-angles` in §Consumers
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0
