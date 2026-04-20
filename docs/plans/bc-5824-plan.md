---
issue: BC-5824
design-doc: docs/designs/bc-5824-situation-mining.md
branch: holden/bc-5824-situation-mining
worktree: .claude/worktrees/bc-5824
task-count: 12
---

# BC-5824 Plan — situation-mining skill

End-state: `plugins/marketing/skills/situation-mining/SKILL.md` + `evals/evals.json` ship with 9 canonical sections, ~46 Brite-adaptation rows for all 23 handbook verticals, graceful-degradation enrichment block, cross-links from `salesforce.md`, a new precedent entry, and a clarifying note on BC-5823's precedent.

Project commands referenced by this plan:

- `./scripts/validate.sh` — plugin validation (CI-equivalent). Runs in <10s.
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — CLAUDE.md size + anti-slop check.
- `./scripts/validate-single.sh <check>` — single-check subset (hooks, etc.).

## Tasks

### Task 1 — Scaffold + context fetch

**Files:**
- `plugins/marketing/skills/situation-mining/SKILL.md` (create, skeleton only)
- `plugins/marketing/skills/situation-mining/evals/evals.json` (create, empty scaffold `{"scenarios": []}`)
- `/tmp/bc-5824-verticals.md` (scratch — gh api output)
- `/tmp/bc-5824-revgrowth-05.md` (scratch — upstream content)

**Steps:**
1. Copy `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` to `plugins/marketing/skills/situation-mining/SKILL.md` as the skeleton.
2. Update frontmatter only: `name: situation-mining`, `description` with triggers per issue body, `user-invocable: true`, `allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_enrichment__*, WebSearch, WebFetch, Read, Write, Glob`, `metadata.version: 0.1.0`, `metadata.category: Outbound Lead Gen`.
3. Parallel: `gh api repos/Brite-Nites/handbook/contents/marketing/go-to-market/verticals/README.md --jq '.content' | base64 -d > /tmp/bc-5824-verticals.md` (per `reference_handbook_access.md`).
4. Parallel: WebFetch `https://raw.githubusercontent.com/Revgrowth1/ai-gtm-workflows/03b30e1/workflows/05-situation-mining/workflow.md` → save to `/tmp/bc-5824-revgrowth-05.md`.
5. Create `evals/` subdirectory and empty `evals.json` scaffold.

**Verification:**
- `plugins/marketing/skills/situation-mining/SKILL.md` exists with updated frontmatter (placeholders from template still present in body, that's expected).
- `/tmp/bc-5824-verticals.md` contains a list of 23 verticals (Active + Exploring + Future sections).
- `/tmp/bc-5824-revgrowth-05.md` contains the 10-pattern worldview matrix + 5-mapping adjacent-offering logic.

### Task 2 — §1 Opener + §2 Before Starting

**File:** `plugins/marketing/skills/situation-mining/SKILL.md`

**Steps:**
1. Replace §1 placeholder with a one-paragraph opener anchored to "diagnostic over promotional" for Brite outbound — audience (BDR, RevOps), problem (Brite emails today pitch; should demonstrate understanding), outcome (per-prospect worldview + 3-4 diagnostic angles).
2. Replace §2 with: (a) marketing-context check (copy pattern from `campaign-orchestration/SKILL.md` §Before Starting); (b) read `docs/designs/outbound-agent-architecture.md` cue; (c) existing-SF-account detection rule — "if domain matches an existing Account in brite-salesforce, fetch Activity history + Opportunity history + Account_Notes__c + Lifecycle_Stage_History__c before inference"; (d) ambiguous-name disambiguation — "if `company_name` is ambiguous and `category` is not provided, ask user to disambiguate BEFORE running research."

**Verification:**
- §1 references audience, problem, one-line outcome — no tool names or repo paths.
- §2 has exactly 4 bullets: marketing-context, outbound-architecture read, SF-account detection, ambiguous-name rule.

### Task 3 — §3 Methodology part A (framing + 6-research-source + confidence rule)

**File:** `plugins/marketing/skills/situation-mining/SKILL.md` §3

**Steps:**
1. Write §3 intro paragraph — "Three frameworks govern this skill: six-source research, worldview inference, adjacent-offering mapping. All inferences are hypotheses."
2. Write `### Six-source research pattern` subsection — list the 6 PRIMARY query patterns with one-line purpose each: `find-profiles` (org structure), `find-founders` (narrative + voice), `find-hiring` (investment signals), `find-growth-signals` (expansion signals), `find-competitors` (frame of reference), `find-negativity` (friction points). Each cites `plugins/marketing/references/research-processes/<file>.md`. Note the parallel-execution pattern + stop conditions + kill-list enforcement.
3. Write `### Hypothesis framing rule` — mandatory framings: "Based on public data...", "This suggests...", "Test this hypothesis..." — never "We know" / "They are". Source-citation rule on every data point.
4. Write `### Confidence decision rule` — HIGH = ≥4 sources corroborate + ≥1 SF-internal signal; MEDIUM = 2–3 sources corroborate or ≥1 SF signal with ≥1 public signal; LOW = single source or speculative inference. Document the rule inline so the skill applies it consistently.

**Verification:**
- §3 intro names the three frameworks in order.
- Six-source subsection names all 6 research-processes files with the correct spelling.
- Hypothesis framing rule has ≥3 mandatory phrasings.
- Confidence rule is decidable — anyone reading the skill can pick HIGH/MEDIUM/LOW from a research output.

### Task 4 — §3 Methodology part B (worldview inference matrix)

**File:** `plugins/marketing/skills/situation-mining/SKILL.md` §3

**Steps:**
1. Add `### Worldview inference matrix` subsection.
2. Port 10 upstream patterns from `/tmp/bc-5824-revgrowth-05.md` as a markdown table: Signal | Worldview inference | Messaging implication. Cite attribution header per BC-5793 UPSTREAM convention.
3. Append 23 Brite-adaptation rows — one per handbook vertical from `/tmp/bc-5824-verticals.md` (6 Active + 8 Exploring + 9 Future, including Supply-deferred installers + property management per D4). Each row:
   - Signal: concrete, observable (job posting, permit filing, press release, board change).
   - Worldview inference: one sentence; anchored to the vertical's procurement / budget / persona pattern documented in handbook.
   - Messaging implication: one sentence on how to frame outreach.
4. Prefix the Brite block with `#### Brite-adaptation rows (handbook-canon, all 23 verticals)` and a callout: "Each row references a handbook trigger. Coverage reversal from BC-5823 Supply-deferred scope — see `docs/designs/bc-5824-situation-mining.md` D4 and `docs/precedents/BC-5824.md`."

**Verification:**
- 10 upstream rows present with attribution header.
- 23 Brite-adaptation rows — one per handbook vertical. Spot-check: Municipalities row cites procurement cycle; HOA row cites board composition; Universities row cites academic-year cycle; Supply installer row cites training/certification need.
- Each Brite row cites a specific handbook trigger (no generic "B2B commercial" rows).

### Task 5 — §3 Methodology part C (adjacent-offering logic)

**File:** `plugins/marketing/skills/situation-mining/SKILL.md` §3

**Steps:**
1. Add `### Adjacent-offering logic` subsection.
2. Port 5 upstream mappings from `/tmp/bc-5824-revgrowth-05.md`. Attribution header.
3. Append 23 Brite-adaptation mappings — one per handbook vertical (Nites + Labs only; Supply excluded per handbook canon). Each row: Observed investment | Brite adjacent offering | Why (budget / persona / timing reasoning). Anchor each to a Brite entity: Nites (residential + seasonal) or Labs (experiential + custom).
4. Entity-per-row mapping examples to validate against during drafting (all Nites or Labs; NO Supply triggers):
   - Municipality approves revitalization bond → Labs festival / streetscape lighting (Why: bond CAPEX has visible-ROI line items)
   - HOA board rotation + landscape refresh → Nites holiday / accent lighting annual contract (Why: new boards want visible quick wins)
   - University builds student center → Labs athletic / event lighting + Nites seasonal permanent (Why: CAPEX project has lighting sub-budget)
   - Landscape Architect lands estate project → Nites landscape lighting (Why: architect's client expects integrated lighting design)
   - Casino renovates main floor → Labs experiential / programmable lighting (Why: gaming floor refreshes drive visitor retention)
   - Ski Resort opens village retail → Labs experiential lighting + Nites seasonal exterior (Why: village retail competes on ambiance)

**Verification:**
- 5 upstream rows + 23 Brite rows covering all 6 Active + 8 Exploring + 9 Future.
- Each Brite row assigns Nites or Labs — NO rows assigned to Supply.
- No generic rows — each cites a specific trigger + offering.
- No rows for installer hiring, property management, or other Supply-flavored triggers.

### Task 6 — §4 Brite Implementation

**File:** `plugins/marketing/skills/situation-mining/SKILL.md` §4

**Steps:**
1. Write "Tools this skill calls" table — mirror `campaign-orchestration/SKILL.md` shape. Rows:
   - Availability check | `salesforce` (`run_soql_query` LIMIT 1) | Brite Salesforce | ADR 2c
   - Existing-account lookup | `salesforce` (`run_soql_query` on Account + Activity + Opportunity + Account_Notes__c + Lifecycle_Stage_History__c) | Brite Salesforce | ADR 2a, `salesforce.md`
   - Parallel web research (6 queries) | `WebSearch` | public web | `references/research-processes/` — 6 PRIMARY patterns
   - Deep-read single page | `WebFetch` | public web | when research surfaces a primary-source URL worth full extraction
   - Firmographic fallback | `enrichment` (`mcp__plugin_marketing_enrichment__*`) | Brite enrichment MCP | BC-5538 (pending); **graceful degradation** — skip block if MCP unavailable
   - Artifact write | `Write` | `docs/research/situations/{domain}-{YYYY-MM-DD}.md` | D3
2. Write "Architectural rules that apply":
   - Salesforce is CRM SoR — never cache SF data in the artifact beyond `generated_at` timestamp (ADR 2a).
   - Enrichment is tertiary — availability check first; degrade gracefully (D2, ADR 2c).
   - Research-processes queries are the PRIMARY surface — never invent queries (`references/research-processes/README.md`).
   - Hypothesis framing is non-negotiable — output labeled HYPOTHESIS not FACT (Anti-Slop §8).
3. Write "Cross-skill boundaries":
   - **Hands off to:** `creative-angles` Deep Mode (situation output in conversation context); `email-copywriting` (situation + offer tier → EB copy).
   - **Receives from:** `list-building` (optional — single-domain invocation from a list); direct user invocation.
   - **Does not own:** list-level operations (`list-building`), reusable pattern-based angles (`creative-angles`), email copy (`email-copywriting`), launch execution (`/marketing:launch-campaign`).

**Verification:**
- Tool table has ≥6 rows, each with ADR or source citation.
- Architectural rules include enrichment degradation + hypothesis framing.
- Cross-skill boundaries explicit on hands-off-to, receives-from, does-not-own.

### Task 7 — §5 MCP Tool Reference

**File:** `plugins/marketing/skills/situation-mining/SKILL.md` §5

**Steps:**
1. Structure as 3 workflow blocks (research / SF lookup / enrichment fallback).
2. **Workflow 1 — Six-source parallel research:** list 6 WebSearch invocations with the exact query seed per `references/research-processes/find-*.md`. Note stop conditions + kill-list. No availability check needed for WebSearch (always available).
3. **Workflow 2 — Existing-account SF enrichment:** (a) availability check `run_soql_query SELECT Id FROM User LIMIT 1` per BC-5534 findings; (b) `run_soql_query` on Account with domain match; (c) conditional SOQL on Activity, Opportunity, Account_Notes__c, Lifecycle_Stage_History__c; (d) pass results to inference as "internal signals". Cite `salesforce.md` §MCP Tool Reference for exact tool names.
4. **Workflow 3 — Firmographic fallback:** (a) availability check — `list_tools` or canonical MCP-level probe (pending BC-5538 ships integration guide); (b) on unavailable, log warning and SKIP this workflow; (c) on available, invoke enrichment tools documented in `brite-enrichment.md` (pending). Explicit: "skill continues without enrichment — does NOT halt."

**Verification:**
- 3 workflow blocks, each starting with availability check (or note for WebSearch).
- SF workflow cites `salesforce.md`.
- Enrichment workflow documents graceful degradation (D2).

### Task 8 — §6 Operational Runbook (5 flows)

**File:** `plugins/marketing/skills/situation-mining/SKILL.md` §6

**Steps:**
Write 5 flows. Each has Preconditions / Steps / Expected output / Error handling / Handoff.

1. **Flow 1 — Standard prospect research (new prospect, no SF match).** 6 parallel WebSearches → worldview inference → 3-4 diagnostic messages → artifact write.
2. **Flow 2 — Existing-SF-account deep dive.** SF account detected at §2 → 6 searches + SF enrichment SOQL → inference uses both public + internal signals → "internal-signal-driven" diagnostic messages (e.g. "Reference the lapsed opportunity from 2025-Q3" — confidence HIGH).
3. **Flow 3 — Ambiguous-name clarification.** Input name matches multiple entities → skill PAUSES and asks user for `category` hint BEFORE running any searches (per Anti-Slop: don't burn searches on wrong entity).
4. **Flow 4 — Thin-data / T4 company fallback.** Research surfaces <2 data points → skill acknowledges confidence LOW → generates 1-2 angles with HYPOTHESIS framing rather than 3-4 → suggests ICP/list-building review rather than premature outreach.
5. **Flow 5 — Handoff to creative-angles Deep or email-copywriting.** Skill completes situation artifact → offers two handoffs: (a) "invoke creative-angles Deep with this situation in context" (b) "invoke email-copywriting with this situation + offer tier".

**Verification:**
- 5 distinct flows — Flow 3 blocks research until disambiguated; Flow 4 caps output at 1-2 angles + LOW confidence.
- Each flow names the cross-skill handoff when applicable.

### Task 9 — §7 Health Scoring Rubric + §8 Anti-Slop Guardrails

**File:** `plugins/marketing/skills/situation-mining/SKILL.md` §§7–8

**Steps:**
1. §7 Rubric — 10 / 7–9 / 4–6 / 1–3 bands. Anchor 10 to: "applies all 3 frameworks + hypothesis framing on every inference + source citation on every data point + HIGH/MEDIUM/LOW confidence decided per §3 rule + existing-SF-account path taken when applicable."
2. §8 Anti-Slop — 4 base guardrails (from template) + ≥3 skill-specific:
   - "Do not frame inferences as facts — every inference labeled HYPOTHESIS with framing phrase."
   - "Do not produce a data point without a source URL or SF object reference."
   - "Do not manufacture evidence the research didn't surface — if thin data, say so + degrade to confidence LOW."
   - "Do not invent research queries — use only patterns from `references/research-processes/`."
   - "Do not skip the SF-account existence check when a domain is provided — always attempt Account lookup first."

**Verification:**
- Rubric 10-band references all 3 frameworks.
- Anti-Slop has 4 base + 5 skill-specific (meets ≥3 requirement with margin).

### Task 10 — §9 Behavioral Tests + evals.json

**Files:**
- `plugins/marketing/skills/situation-mining/SKILL.md` §9
- `plugins/marketing/skills/situation-mining/evals/evals.json`

**Steps:**
1. §9 — 6 scenarios split Tier 1 / Tier 2:
   - T1: Happy path (new prospect, 6 searches executed, worldview inferred, 3 angles, HIGH confidence)
   - T1: Thin data (output confidence LOW, 1-2 angles, HYPOTHESIS framing)
   - T1: Ambiguous name (skill pauses for category before searches)
   - T2: Existing SF account (skill calls Account + Activity SOQL, uses internal signals in inference)
   - T2: Enrichment MCP unavailable (skill logs warning, skips enrichment workflow, completes without halting)
   - T2: Missing marketing-context.md (skill warns per §2, degrades to user-provided context)
2. `evals.json` — same 6 scenarios with assertions:
   ```json
   {
     "scenarios": [
       {"id": "happy-path", "tier": 1, "input": "...", "assertions": ["output contains '## Diagnostic Messages' with ≥3 items", "all inferences prefixed with one of: Based on public data | This suggests | Test this hypothesis"]},
       ...
     ]
   }
   ```

**Verification:**
- §9 has exactly 6 scenarios (≥6 per spec).
- `evals.json` parses as valid JSON.
- Each scenario has `id`, `tier`, `input`, `assertions` keys.

### Task 11 — Cross-links + precedent

**Files:**
- `plugins/marketing/tools/integrations/salesforce.md` (§Consumers section)
- `docs/precedents/BC-5824.md` (new precedent — skeleton)
- `docs/precedents/INDEX.md` (new row)

**Steps:**
1. Add `situation-mining` to `salesforce.md` §Consumers (find section via Grep, append bullet with skill path + one-line purpose).
2. Create `docs/precedents/BC-5824.md` with skeleton (Decision, Category: pattern-choice, Confidence, Precedent Referenced: BC-5823, tags). Core decision: "Fetch handbook canon at brainstorm/design time, not execution time — else scope assumptions solidify wrong and cost a re-draft." Full contents populated during /workflows:ship compound-learnings.
3. Add row to `docs/precedents/INDEX.md`: `| [BC-5824](BC-5824.md) | Fetch handbook canon during brainstorm, not execution; scope assumptions made without the source will need re-drafting mid-implementation | pattern-choice | 2026-04-20 | pattern-choice, handbook-canon, brainstorm-timing, scope-assumption, process-improvement |`.

**Verification:**
- `salesforce.md` §Consumers includes situation-mining.
- BC-5824 precedent file exists with valid YAML frontmatter matching BC-1955 Section 6 convention (Confidence, Category, Tags).
- INDEX has new row.
- BC-5823 precedent is NOT modified (no clarification note needed — handbook excludes Supply, so BC-5823 holds unchanged).

**Note:** Do NOT add `brite-enrichment.md` cross-link — that file is BC-5538 scope. Leave a `TODO(BC-5538): add brite-enrichment.md consumer cross-link` comment next to the skill's enrichment tool reference in §5.

### Task 12 — Validation + final lint

**Steps:**
1. `./scripts/validate.sh` — must exit 0. Fix any schema / frontmatter / section-ordering violations reported.
2. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — must exit 0. If CLAUDE.md exceeds size guardrail after BC-5823 compound-learnings update, defer guardrail fix to a follow-up (flag, don't fix here).
3. Grep for scope violations: `grep -rE "Serper|serper" plugins/marketing/skills/situation-mining/` → expect no matches.
4. Grep for allowed-tools sanity: `grep -E "^allowed-tools:" plugins/marketing/skills/situation-mining/SKILL.md` → expect exactly the 6 entries from Task 1.
5. Visual section-order check: §1 Opener → §2 Before Starting → §3 Methodology → §4 Brite Implementation → §5 MCP Tool Reference → §6 Operational Runbook → §7 Health Scoring Rubric → §8 Anti-Slop Guardrails → §9 Behavioral Tests.

**Verification:**
- Both validation scripts exit 0.
- No Serper matches.
- allowed-tools matches the 6 entries.
- Section ordering correct.

## Parallelization

- **Serial chain:** 1 → 2 → 3 → (4, 5 in parallel after 3) → 6 → 7 → 8 → 9 → 10 → 11 → 12.
- Tasks 4 and 5 can run in parallel (both write to §3 but to distinct subsections). All others are serial.

## Out of scope for this PR

- `brite-enrichment.md` integration guide (BC-5538).
- `account-research` skill (BC-5827).
- `creative-angles` Deep Mode implementation (BC-5828).
- Reference extraction of worldview matrix + adjacent-offering logic (future refactor if other skills need them).
- Dogfood situation-mining on a real prospect (post-ship acceptance).
