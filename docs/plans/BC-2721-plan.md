# Plan: Create marketing skill: campaign-analysis

**Issue**: BC-2721 — Create marketing skill: campaign-analysis
**Branch**: `corinne/bc-2721-create-marketing-skill-campaign-analysis`
**Tasks**: 10 (estimated ~3h authoring + ~3h review-loop budget)

## Prerequisites

- `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` exists (confirmed, 350 lines)
- `plugins/marketing/tools/integrations/email-bison.md` exists for MCP Tool Reference grounding (confirmed)
- Sibling skills shipped and usable as pattern references: `email-copywriting`, `gtm-strategy`, `situation-mining`, `campaign-orchestration`
- `docs/marketing-context.md` — not required for authoring the skill itself, only at runtime
- **CDR check skipped**: Context7 quota exceeded this session. Handbook CDRs not consultable. Aligned with default marketing-plugin conventions.
- **Precedent alignment**:
  - **BC-5761 + BC-5762** (iteration budget) — budget 4-5 review iterations; Task 10 caps at iter 5
  - **BC-5797** (factual-anchor recipe) — verify Revgrowth 11 citations + benchmark numbers + EB MCP tool names pre-merge
  - **BC-5795** (revert-reship on post-merge P1s) — review factual anchors during fix loop, not after
  - **BC-5823** (handbook canon wins) — multi-entity b2c/b2b benchmark split is canon; do not bolt on Supply
  - **BC-5760** (state-schema drift) — every §3 Methodology term (variable name, verdict label, benchmark) must resolve in §4, §6, §8, §9

## Tasks

### Task 1: Scaffold skill directory + frontmatter
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`, `plugins/marketing/skills/campaign-analysis/evals/.gitkeep`
**Why**: Establishes the directory, copies the template, and locks frontmatter (triggers, allowed-tools, category, version) so validate.sh accepts the scaffold from here on.

**Implementation**:
1. `mkdir -p plugins/marketing/skills/campaign-analysis/evals`
2. Copy `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` → `plugins/marketing/skills/campaign-analysis/SKILL.md`
3. Delete the template's top comment block (lines 12-44) and all inline `<!-- ... -->` guidance comments (they live in the template, not in shipped skills — confirmed by reading `email-copywriting/SKILL.md` and `gtm-strategy/SKILL.md`)
4. Replace frontmatter with exactly:
   ```yaml
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
   ```
5. Replace `# {Skill Title}` with `# Campaign Analysis`
6. Clear section bodies to placeholder `TBD` markers so validate.sh's section-order check passes

**Test**:
- Run: `./scripts/validate.sh`
- Expected: Scaffold passes section-order + frontmatter checks (contents may still be TBD)

**Verify**: `git status` shows new directory; validate.sh exit 0.

---

### Task 2: §1 Opener + §2 Before Starting
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`
**Why**: Establishes audience, problem, outcome, and the preconditions (marketing-context gate, workspace detect, time-range prompt, benchmark set) before any analysis runs.

**Implementation**:
1. Replace §1 opener with one paragraph: audience (RevOps, BDR lead, marketing operator post-campaign), problem ("analysis drifts into narrative without a tight framework"), outcome (6-section report in `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md` with verdict-mapped recommendations, mandatory handoff to campaign-debrief).
2. Write §2 Before Starting with three gates:
   - **Marketing-context gate** (copy the BC-5824 precedent message verbatim from `email-copywriting/SKILL.md` §2 — "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.")
   - **Workspace + entity detection** — pick `emailbison-b2b` (Brite Supply + Labs b2b) or `emailbison-personal` (Brite Nites b2c). Never guess from domain.
   - **Time-range prompt** — default 7-14 day window; ask user via AskUserQuestion; reject windows <7 days as insufficient for statistical significance.
   - **Benchmark set selection** — b2c vs b2b benchmark table (names only here; table goes in §3).

**Test**:
- Run: `./scripts/check-guardrails.sh --claude-md CLAUDE.md`
- Expected: No anti-slop violations (no jargon, no fabrications)

**Verify**: §1 and §2 each have concrete, non-TBD content; AskUserQuestion usage matches sibling pattern (single field per question per BC-5761 feedback).

---

### Task 3: §3 Methodology — 5 Core Variables + 4-phase flow
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`
**Why**: Establishes the diagnostic framework + analysis sequence with Hypothesis-first rule. All of §4/§6/§8/§9 references these names; this task locks the vocabulary.

**Implementation**:
1. Add §3.1 "5 Core Variables" subsection. Each variable gets: name, one-line definition, key question. Exact names (verification check enforces these): `Offer`, `Message`, `Segment`, `Infrastructure`, `Timing`.
2. Add §3.2 "4-phase analysis flow". Each phase gets its own subsection: `Phase 1 Hypothesis`, `Phase 2 Data Collection`, `Phase 3 Analysis`, `Phase 4 Recommendations`. State Hypothesis-before-analysis rule explicitly: "Never begin Phase 3 before Phase 1 is written down. This bans narrative retrofitting."
3. In Phase 2, name the EB MCP tools used (placeholder — concrete tool names resolved in Task 6 from `email-bison.md`).
4. In Phase 3, name the statistical-significance floor: min 500 sent AND 7+ days; below either → verdict auto-maps to `TEST MORE`.

**Test**:
- Grep check: `grep -c 'Offer\|Message\|Segment\|Infrastructure\|Timing' SKILL.md` — at least 5 occurrences
- Grep check: `grep -c 'Hypothesis\|Data Collection\|Analysis\|Recommendations' SKILL.md` — at least 4 occurrences

**Verify**: All 5 variables named with key questions; all 4 phases named in order; Hypothesis-first rule stated verbatim.

---

### Task 4: §3 Methodology — Benchmarks + 6-section report + verdict mapping
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`
**Why**: Closes the Methodology section with the concrete tables (benchmarks, verdict thresholds, report structure) that verification matrices will audit pre-merge.

**Implementation**:
1. Add §3.3 "Benchmarks" with two tables (b2c personal vs b2b workspace) — Reply Rate (>1% Healthy / 0.5-1% Attention / <0.5% Critical), Interested Rate (>25% of replies Healthy), Bounce Rate (<3% Healthy / 3-5% Attention / >5% Critical). Use exact wording from issue description — this is a BC-5797 factual anchor.
2. Add §3.4 "6-section report structure". Each section gets: number, name, one-line purpose. Exact names (verification enforces): `1. Quick Health Check`, `2. Segment Performance Ranking`, `3. Infrastructure Analysis`, `4. Reply Sentiment Analysis`, `5. Attribution Analysis`, `6. Next Iteration Recommendations`.
3. Add §3.5 "Verdict mapping". 5-verdict table with thresholds. Exact labels (verification enforces): `TOP PERFORMER`, `SCALE`, `TEST MORE`, `MONITOR`, `UNDERPERFORM`. Each row names the metric threshold.
4. Cross-reference: state that every row in Section 2 ranking and every cell in Section 5 attribution table MUST resolve to one of these 5 verdicts.

**Test**:
- Regex check: `grep -E '\b(TOP PERFORMER|SCALE|TEST MORE|MONITOR|UNDERPERFORM)\b' SKILL.md | wc -l` — ≥5 occurrences (one per label minimum)
- Numeric check: `grep -E '(1%|25%|3%|500|7)' SKILL.md` — benchmark numbers present

**Verify**: All benchmark numbers exact from issue description; all 5 verdict labels present with thresholds; all 6 report sections named in order.

---

### Task 5: §4 Brite Implementation
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`
**Why**: Translates generic methodology to Brite's stack — tool table, entity-keyed benchmark sets, and the two handoff rules that wire this skill into the broader outbound motion.

**Implementation**:
1. Write "Tools this skill calls" table: rows for (a) pull campaign analytics → EB MCP `get_campaign_stats` → Email Bison workspace, (b) pull per-lead delivery → EB MCP `get_leads_analytics`, (c) pull replies → EB MCP `get_replies_analytics`, (d) pipeline attribution → SF MCP `run_soql_query` on `Opportunity WHERE Campaign_Source__c`. Source column cites ADR 2a.
2. Write "Entity-keyed benchmark sets" subsection naming the two workspaces: `emailbison-personal` (Brite Nites b2c — softer benchmarks, longer decision cycles) and `emailbison-b2b` (Brite Supply + Labs b2b — the benchmarks in §3.3 apply directly). Do not invent Supply-specific benchmarks (BC-5823 canon).
3. Write "Architectural rules that apply" subsection — pull from `email-bison.md` and outbound-sales-ops: Hypothesis-before-Analysis (from §3.2), min-500-sent-per-7-days statistical floor, no subjective verdict language.
4. Write "Cross-skill boundaries" with exactly three handoff clauses:
   - **Mandatory post-analysis → BC-5830 campaign-debrief**. Quote: "Analysis complete. To capture these learnings so they compound into future campaigns, run the campaign debrief workflow." State: this is the loop-closer.
   - **Conditional → BC-2719 deliverability-audit** when Infrastructure variable is suspect (bounce spike OR Google-vs-Microsoft 2x+ disparity OR spam-complaint signals).
   - **On-request → BC-5829 MSPA ITERATE mode** when user asks "what should we test next?"
5. Add "Does not own" clause: reply sentiment classification is BC-2720; test design is MSPA; learning capture is BC-5830.

**Test**:
- Grep: `grep -E 'BC-(5830|2719|5829|2720)' SKILL.md | wc -l` — all four BCs referenced
- Grep: `grep 'MANDATORY\|CONDITIONAL' SKILL.md` — both handoff types named

**Verify**: Tool table has ≥3 rows with source citations; all 4 cross-skill references resolve; handoff wording matches issue description.

---

### Task 6: §5 MCP Tool Reference
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`
**Why**: Names exact EB MCP tool names per analysis phase so a fresh subagent can call them without inventing names. BC-5797 factual-anchor recipe: cross-check every tool name against `email-bison.md` before commit.

**Implementation**:
1. Ground-truth tool names from `plugins/marketing/tools/integrations/email-bison.md`. The primary tools for analytics: `get_campaign_stats`, `get_leads_analytics`, `get_replies_analytics`, `list_campaigns`, `list_sender_emails`. Availability check: `get_active_workspace_info`.
2. Write §5 grouped by the 4 phases (NOT by server — template §MCP Tool Reference guidance):
   - **Phase 1 Hypothesis** — no tool calls; pure operator-facing prompt.
   - **Phase 2 Data Collection** — availability check → `get_active_workspace_info`; list campaigns in range → `list_campaigns`; pull stats → `get_campaign_stats` per campaign; pull per-lead → `get_leads_analytics`; pull replies → `get_replies_analytics`.
   - **Phase 3 Analysis** — no new MCP calls; synthesis only.
   - **Phase 4 Recommendations** — optional pipeline attribution via SF MCP `run_soql_query` on `Opportunity WHERE Campaign_Source__c = :campaign_name`.
3. For each tool: name it semantically, link to `email-bison.md` anchor if present, note any limits (sample-size floor, page-size cap).
4. Do NOT list a tool the skill will not call (pattern-guide anti-pattern #4).

**Test**:
- Cross-check: for each tool name in §5, confirm `grep <tool_name> plugins/marketing/tools/integrations/email-bison.md` returns at least one match
- Frontmatter cross-check: every server in `allowed-tools` is referenced in §5

**Verify**: No invented tool names; every allowed-tools server has ≥1 reference in §5.

---

### Task 7: §6 Operational Runbook
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`
**Why**: Gives 4+ concrete procedures with preconditions, steps, error handling, and handoffs — what a subagent follows end-to-end.

**Implementation**:
1. Task 1: "Standard post-campaign analysis run" — 7 steps from availability check through writing the report artifact to mandatory debrief handoff.
2. Task 2: "Infrastructure-triggered deliverability-audit handoff" — preconditions: bounce spike OR 2x Google/Microsoft gap; steps: surface Infrastructure variable; prompt user; hand off to BC-2719.
3. Task 3: "MSPA ITERATE-mode trigger on request" — preconditions: user asks "what next?"; steps: pass analysis output as MSPA input; hand off to BC-5829.
4. Task 4: "Per-entity benchmark switch" — preconditions: workspace detected; steps: select b2c or b2b benchmark row set; apply to §3.3 comparison.
5. Each task ends with explicit error handling (availability failure → stop and report; <500 sent → TEST MORE verdict; missing `Campaign_Source__c` → skip pipeline attribution, note in report).

**Test**:
- Count: `grep -E '^### Task [0-9]+:' SKILL.md | wc -l` — ≥4
- Each task has "Preconditions:", "Steps:", "Error handling:" lines

**Verify**: ≥4 tasks; every task has preconditions + steps + error handling + (where applicable) handoff.

---

### Task 8: §7 Rubric + §8 Anti-Slop + §9 Behavioral Tests
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`
**Why**: Closes the skill body with the review-rubric review agents use, the anti-patterns this skill must not emit, and the Tier 1/2 behavioral test matrix.

**Implementation**:
1. §7 Health Scoring Rubric — 10/7-9/4-6/1-3 bands. 10 = cites all 5 Variables, all 4 phases, hypothesis before data, exact benchmark thresholds, 6 named report sections, mandatory debrief handoff, availability check before EB calls, workspace-keyed benchmarks. 1-3 = subjective verdicts, skipped hypothesis, invented tool names, missing debrief handoff.
2. §8 Anti-Slop — 4 base rules from template, plus 5 skill-specific:
   - Never skip the Hypothesis phase (narrative retrofit ban)
   - Never use subjective verdict language (SCALE / TEST MORE are numeric thresholds, not opinions)
   - Never skip the mandatory campaign-debrief handoff at end
   - Never run analysis on <500 sent OR <7 days — auto-map to TEST MORE
   - Never invent benchmark numbers (the `>1%`, `>25%`, `<3%` values are fixed anchors)
3. §9 Behavioral Tests — 6+ scenarios split Tier 1 / Tier 2:
   - T1: Hypothesis-first — given a campaign result scenario, output must state hypothesis BEFORE data
   - T1: Infrastructure handoff — given 2x Google/Microsoft gap, output must surface BC-2719 handoff
   - T1: Segment ranking — output Section 2 must rank all campaigns by Interested Rate with verdict per row
   - T1: Reply sentiment — given high replies + low interested, output must flag "wrong audience"
   - T1: Small-sample → TEST MORE — given 300 sent over 3 days, output verdict must be TEST MORE
   - T1: Debrief handoff — output must end with the BC-5830 handoff prompt
   - T2 (read): Output must reference workspace from `docs/marketing-context.md`
   - T2 (MCP): Output must begin with `get_active_workspace_info` availability check

**Test**:
- Grep: `grep -c '^- ' <anti-slop section>` — ≥9 bullets (4 base + 5 skill-specific)
- Grep: `grep -E '(Tier 1|Tier 2)' SKILL.md | wc -l` — both tiers present
- Count: ≥6 behavioral scenarios

**Verify**: Rubric distinguishes 1-3 from 10 concretely; 5 skill-specific anti-slop rules; ≥6 behavioral scenarios across both tiers.

---

### Task 9: evals/evals.json with 6+ scenarios
**Files**: `plugins/marketing/skills/campaign-analysis/evals/evals.json`
**Why**: Structured eval scenarios that mirror §9 behavioral tests and feed the automated eval runner. Pattern matches `plugins/marketing/skills/email-copywriting/evals/evals.json`.

**Implementation**:
1. Read `plugins/marketing/skills/email-copywriting/evals/evals.json` for the canonical schema (scenario id, trigger prompt, expected assertions, optional fixtures).
2. Write 6+ scenarios, one per §9 behavioral test. Each has:
   - `id`: short snake_case (e.g., `hypothesis_first`, `infra_handoff_trigger`, `small_sample_verdict`)
   - `prompt`: the trigger utterance
   - `assertions`: list of substring-match or regex checks against output
3. Mirror the Tier 1 / Tier 2 split with an explicit `tier` field per scenario.

**Test**:
- JSON valid: `python -c "import json; json.load(open('plugins/marketing/skills/campaign-analysis/evals/evals.json'))"`
- Count: 6+ scenarios

**Verify**: JSON parses; assertions align with §9; eval runner (if wired) accepts the file.

---

### Task 10: Cross-links + validate + review loop
**Files**: `plugins/marketing/skills/campaign-analysis/SKILL.md`, `plugins/marketing/skills/deliverability-audit/SKILL.md` (if exists — TBD check), `plugins/marketing/skills/campaign-orchestration/SKILL.md`, `plugins/marketing/skills/message-market-fit/SKILL.md` (if exists), `plugins/marketing/skills/campaign-debrief/SKILL.md` (if exists)
**Why**: Wires the skill into the sibling graph's `§Consumers` / `§Feeds Into` tables so future skill readers find the handoff contract from either side. Runs the validator and check-guardrails. Budgets the review-loop per BC-5761 precedent.

**Implementation**:
1. For each sibling skill that EXISTS (check with `ls plugins/marketing/skills/`): append a `### Feeds Into` or `### Consumers` bullet naming `campaign-analysis` and the handoff condition. Skip siblings not yet built (BC-5830, BC-5829, BC-2719 may be Todo).
2. For siblings not yet built, leave the cross-link work as a follow-up note in the PR description — the sibling issues' own execution will wire the link from their side.
3. Run `./scripts/validate.sh` — fix any violations
4. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — fix any violations
5. **Review loop (BC-5761 precedent)**: after self-check, run `/workflows:review` in parallel. Budget 4-5 iterations. Iter 1 finds initial drift; iter 2-4 surface drift introduced by fixes; iter 5 converges. Cap at iter 5.
6. Pre-ship factual-anchor audit (BC-5797 recipe): manually verify (a) Revgrowth 11 URL resolves; (b) benchmarks match issue description exactly; (c) every tool name in §5 greps in `email-bison.md`; (d) every BC-NNNN reference resolves to an existing Linear issue.

**Test**:
- `./scripts/validate.sh` → exit 0
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` → exit 0
- Review-loop convergence: iter ≤5 reaches 0 P1 + ≤1 P2

**Verify**: Both scripts exit 0; review agents return 0 P1; PR description notes any deferred cross-links to Todo siblings.

---

## Task Dependencies

- Tasks 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 are sequential by default (each builds on the preceding section's vocabulary per BC-5760 cross-section consistency)
- **Parallelizable pairs**: Task 6 (MCP Tool Reference) and Task 9 (evals.json) can run in parallel after Task 5 — neither touches the other's surface
- **Parallelizable within**: §7/§8/§9 in Task 8 can be split into three parallel subtasks if agent bandwidth allows

## Verification Checklist

- [ ] `plugins/marketing/skills/campaign-analysis/SKILL.md` exists with required frontmatter
- [ ] All 9 sections present in required order (template order enforced by validate.sh)
- [ ] `allowed-tools` matches Tool Surface: `mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_emailbison-b2b__*, mcp__plugin_marketing_emailbison-personal__*, Read, Write, Glob`
- [ ] §3 names all 5 Core Variables (Offer / Message / Segment / Infrastructure / Timing)
- [ ] §3 names all 4 phases with Hypothesis-before-Analysis rule
- [ ] §3 benchmarks: Reply >1%, Interested >25%, Bounce <3%
- [ ] §3 names all 5 verdicts: TOP PERFORMER / SCALE / TEST MORE / MONITOR / UNDERPERFORM
- [ ] §3 describes all 6 report sections
- [ ] §4 documents MANDATORY → BC-5830 and CONDITIONAL → BC-2719 handoffs
- [ ] §4 documents entity-keyed benchmark sets (b2c personal vs b2b workspace)
- [ ] §6 has ≥4 workflows including infrastructure-triggered handoff
- [ ] §8 includes Hypothesis-first + specific-threshold-verdict + always-hand-off-to-debrief rules
- [ ] §9 has ≥6 scenarios
- [ ] `evals/evals.json` has ≥6 scenarios and parses as valid JSON
- [ ] Report artifact path `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md` documented
- [ ] Cross-links added to existing siblings (deferred siblings noted in PR body)
- [ ] `./scripts/validate.sh` → exit 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` → exit 0
- [ ] Review-loop converged within 5 iterations with 0 P1 / ≤1 P2
