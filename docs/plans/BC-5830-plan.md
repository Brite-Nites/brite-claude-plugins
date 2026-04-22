# Plan: BC-5830 — Create marketing skill: campaign-debrief

**Issue**: [BC-5830](https://linear.app/brite-nites/issue/BC-5830) — Create marketing skill: campaign-debrief (5-question learning capture + entity-keyed learnings.md)
**Branch**: `corinne/bc-5830-create-marketing-skill-campaign-debrief-5-question-learning`
**Tasks**: 10 task-batches (est. 90–110 min focused, subagent-per-batch) mapping to the 16 issue-body steps

## Objective

Ship a net-new `campaign-debrief` skill at `plugins/marketing/skills/campaign-debrief/SKILL.md` (350–450 lines) plus an `evals/evals.json` (150–200 lines, 6+ scenarios). Skill runs a structured 5-question debrief (Q1–Q5) after campaign-analysis (primary input) or standalone, assigns one of four objective verdicts (SCALE / ITERATE / PAUSE / KILL) against concrete thresholds, tags each entry with `#entity` / `#vertical` / `#persona` / `#angle`, and appends the entry to `docs/campaigns/{entity}/learnings.md` (creating on missing from a template). Flags transferable insights and proposes updates to `docs/marketing-context.md` or raises a handbook-drift issue. **Does NOT** run campaign analysis itself, execute campaigns, design next experiments (MSPA owns that), or overwrite learnings.md. BC-2721 body is **not** edited here (handoff clause already live at campaign-analysis line 173); BC-5829 MSPA body is **not** edited either (cross-link already present at MSPA line 259). Cross-links are additive-only in BC-5830's own SKILL.md.

## Prerequisites

- **Template** (verified): `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — 9-section scaffold with stub header order. Marketing-context soft gate is a hard requirement per template line 63.
- **Sibling exemplars** (all shipped within the last 7 days, in ascending recency):
  - `plugins/marketing/skills/account-research/SKILL.md` (BC-5827, 346 lines) — **structural exemplar** for tool table format, evals.json shape, §2 gate structure.
  - `plugins/marketing/skills/creative-angles/SKILL.md` (BC-5828, 394 lines) — input-validation regex pattern, `{entity}` validator.
  - `plugins/marketing/skills/campaign-analysis/SKILL.md` (BC-2721, 383 lines) — **PRIMARY UPSTREAM** — campaign-debrief consumes its `analysis-*.md` artifact. Workspace routing pattern (emailbison-b2b vs emailbison-personal by entity). Reply/Interested/Bounce benchmark schema. Handoff clause at line 173.
  - `plugins/marketing/skills/message-market-fit/SKILL.md` (BC-5829, 482 lines) — **PRIMARY DOWNSTREAM** — MSPA's ITERATE handoff consumes campaign-debrief's output. Verdict-label discipline pattern. Append-only artifact pattern. Cross-link at line 259 already reads `BC-5830 pending`.
- **Tool surface registered** (verified in this session):
  - `mcp__emailbison-b2b__*` (SHORT form, repo-root-scoped) — all 29 tools present.
  - `mcp__emailbison-personal__*` (SHORT form, repo-root-scoped) — verified.
  - `mcp__plugin_marketing_salesforce__*` — verified via sibling allowed-tools.
  - Read, Write, Glob — always on.
- **Target directory absent** (verified): `plugins/marketing/skills/campaign-debrief/` does not exist — net-new skill.
- **`docs/marketing-context.md` ABSENT** (verified 2026-04-22): no such file. Skill must test + ship with the reduced-context degraded path as an explicit behavioral scenario (per issue verification item; per account-research precedent at `sf-unavailable-graceful-degrade`).
- **`docs/campaigns/` may not exist**: BC-5829 MSPA was "first to produce" to that path. Skill must create-on-missing for the entity subdirectory and for the learnings.md file.
- **Precedents INDEX** (verified): `docs/precedents/INDEX.md` exists; BC-5828 (plan-gate live-read check #6) and BC-5829 (cross-skill schema contract check #7) establish the factual-anchor recipe that THIS plan follows. Cross-link from skill body per issue Task 1's "engineering-side parallel".
- **Validation commands** (per CLAUDE.md Quick Start): `./scripts/validate.sh` and `./scripts/check-guardrails.sh --claude-md CLAUDE.md`. Both verified.
- **Memory stale-deferral check**: memory `project_session_BC-2721.md` deferred BC-5830 "pending marketing-context decision" on 2026-04-21; however BC-1727 product-marketing-context skill (2026-03-31) and BC-5829 MSPA (2026-04-21) both shipped with marketing-context as a **soft gate with reduced-context degrade path**. The deferral is stale — proceed, and use the sibling degrade pattern.

## Plan-gate live-read (BC-5828 check #6 + BC-5829 check #7)

**Files read at Plan gate:**

1. `plugins/marketing/skills/campaign-analysis/SKILL.md` (all 384 lines) — extracted upstream artifact contract.
2. `plugins/marketing/skills/message-market-fit/SKILL.md` (all 483 lines) — extracted downstream consumer contract.
3. `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` (all 350 lines) — 9-section scaffold order confirmed.
4. `plugins/marketing/skills/account-research/SKILL.md` (all 347 lines) — structural exemplar confirmed.
5. `plugins/marketing/skills/account-research/evals/evals.json` (133 lines, 6 scenarios) — evals shape confirmed.
6. `docs/plans/marketing-gtm-expansion.md` §2.4 — scoping rationale confirmed. No constraints beyond Linear issue body.
7. `docs/precedents/INDEX.md` — engineering-parallel decision-trace pattern confirmed; skill body cross-links INDEX as parallel.
8. Filesystem probes: `docs/marketing-context.md` ABSENT; `plugins/marketing/skills/campaign-debrief/` ABSENT.

**Decisions resolved:**

- **Marketing-context gate** → soft gate, reduced-context degrade path (sibling pattern, 4 existing skills use it). Deferral in memory is stale.
- **Workspace routing** → entity-driven, matches campaign-analysis §4 and MSPA Gate 3: Nites → `emailbison-personal`; Supply + Labs → `emailbison-b2b`.
- **Verdict thresholds** → anchor numerics to campaign-analysis §3.3 b2b benchmark table (Reply >1% Healthy, Interested >25% Healthy, Bounce <3% Healthy) and §4 b2c softer set (Reply >0.5%, Interested >15%). Verdict assignment:
  - `SCALE`: Reply Rate Healthy AND Interested Rate Healthy (per entity-specific benchmark set).
  - `ITERATE`: Mixed — one metric Healthy, one Attention, no Critical.
  - `PAUSE`: Sub-floor run (<500 sent OR <7 days) OR Bounce Rate Attention band OR mixed-Attention where deliverability is suspect.
  - `KILL`: Reply Rate Critical (<0.5% b2b / <0.25% b2c) with 500+ sent AND 7+ days.
- **Append-only invariant** → echoes MSPA's matrix append-only rule. Never rewrite learnings.md body.
- **5-question format** → suggest answers from campaign-analysis data first (Q1 from `§5 Attribution Analysis`; Q2 from §2 ranked-row verdict; Q3 from §5 top-2; Q4/Q5 operator-authored). Under-5-minute constraint is load-bearing.
- **Tag casing** → all lowercase hyphenated; `#entity/brite-nites|brite-supply|brite-labs` (three-word slugs, distinct from MSPA's short-entity validator — deliberate divergence, see Risks).

**Ambiguities surfaced** (see Risks section): entity slug divergence between MSPA and BC-5830 tags; verdict-token collision across three sibling skills.

## Cross-skill schema contract

**Upstream — campaign-analysis → campaign-debrief (PRIMARY INPUT):**

Input: `docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md`, produced by campaign-analysis Procedure 1 step 7.

Canonical field names (verbatim from campaign-analysis §3.3 and §3.4):

- `Reply Rate` (not `reply_rate`, not `positive_reply_rate`) — replies ÷ sent.
- `Interested Rate` — interested-replies ÷ replies, from `get_replies_analytics`.
- `Bounce Rate` — bounces ÷ sent.
- Campaigns identified by name (`{campaign-name}` is a filename token), not `campaign_id` or `campaign_uuid`.
- 6 report sections in fixed order: §1 Quick Health Check, §2 Segment Performance Ranking, §3 Infrastructure Analysis, §4 Reply Sentiment Analysis, §5 Attribution Analysis, §6 Next Iteration Recommendations.
- Verdict tokens on each ranked row in §2: `TOP PERFORMER` / `SCALE` / `TEST MORE` / `MONITOR` / `UNDERPERFORM`.
- §5 Attribution Analysis rows carry exactly one of 5 Core Variables: `Offer` / `Message` / `Segment` / `Infrastructure` / `Timing`.
- Sub-floor flag: reports below 500 sent OR 7 days carry an explicit sub-floor header; every verdict in the ranked table is `TEST MORE`.

Campaign-debrief reads this artifact in Procedure 1 step 1. Q1 suggestion drawn from §5 Attribution row; Q2 suggestion drawn from §2 ranked row's verdict label; Q3 drawn from §5 top-2 rows; Q4 operator-authored; Q5 drawn from §6 Next Iteration Recommendations.

**Downstream — campaign-debrief → learnings.md (PRIMARY OUTPUT):**

Output: `docs/campaigns/{entity}/learnings.md` — append-only, create-on-missing from template.

Entry schema (per issue §Scope — Output; Revgrowth 12 format + Brite entity tag):

```yaml
---
campaign: {campaign-name}
analyzed_at: {YYYY-MM-DD}
debrief_at: {YYYY-MM-DD}
source_analysis: docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md
verdict: SCALE | ITERATE | PAUSE | KILL
metrics:
  reply_rate: 0.012   # decimal, matches campaign-analysis numeric form
  interested_rate: 0.28
  bounce_rate: 0.024
  sent: 1200
  days: 14
tags:
  - "#entity/brite-supply"
  - "#vertical/commercial-real-estate"
  - "#persona/facilities-director"
  - "#angle/capital-expenditure-timing"
transferable: true | false
transferable_note: {one-line note if transferable: true, else omit}
---

## Q1 — Hypothesis
{operator-confirmed sentence, format: "We hypothesized that {angle/segment/timing} would {expected outcome} because {reasoning}."}

## Q2 — Result
{CONFIRMED | PARTIAL | REJECTED} — {one-line summary with key metric}

## Q3 — What worked, what didn't
**Worked**: {1–3 bullets, signal}
**Didn't**: {1–3 bullets, noise or failure}

## Q4 — What surprised us
{1–3 bullets, unexpected findings}

## Q5 — Transferable insight
{sentence or "entity-specific only" if not transferable}
```

**Downstream — campaign-debrief → MSPA matrix update:**

MSPA ITERATE reads `docs/campaigns/{entity}/mmf-results-{N}.md` per its Step 4 Results Log schema. Campaign-debrief does NOT write to `mmf-results-*.md` — that is MSPA Step 4's artifact. The feedback loop (MSPA §4 "Receives from" line 267): transferable-insight notes in learnings.md flow back into MSPA's Notes column on the next ITERATE run. Contract: MSPA Notes column receives one free-form sentence per row, sourced from learnings.md `transferable_note` YAML field when `transferable: true`. Campaign-debrief writes the field; MSPA reads it.

**Downstream — campaign-debrief → marketing-context.md proposal (conditional):**

When `transferable: true` AND the insight applies cross-entity, campaign-debrief proposes an edit to `docs/marketing-context.md`. The proposal is surfaced to the operator via `AskUserQuestion` — campaign-debrief does NOT write to marketing-context.md directly. On operator confirmation, hand off to `/marketing:product-marketing-context` skill.

**Downstream — campaign-debrief → handbook-drift (conditional):**

When `transferable: true` AND the insight contradicts documented handbook content, raise a handbook-drift issue via `/workflows:handbook-drift-check`. Campaign-debrief does NOT edit handbook content directly.

## Tasks (10 batches mapped to 16 issue-body steps)

### Batch A — Skeleton and frontmatter (issue Tasks 1–2)

**Files**: `plugins/marketing/skills/campaign-debrief/` (new dir), `SKILL.md` (new), `evals/` (new dir).

**Implementation**:

1. Create directory and empty evals subdir.
2. Write frontmatter: `name: campaign-debrief`, single-paragraph `description` covering 5-question structure + 4-verdict rubric + entity-keyed learnings + transferable flagging + primary-input-from-campaign-analysis. Triggers: `"debrief"`, `"campaign debrief"`, `"retro"`, `"log campaign"`, `"capture learnings"`. `user-invocable: true`, `allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob` (verbatim from issue §Tool Surface; EB SHORT form). `metadata: { version: 0.1.0, upstream: Revgrowth1/ai-gtm-workflows, category: Outbound Lead Gen }`.
3. Write `# Campaign Debrief` title.
4. Stub H2 headers for §2–§9 with `TODO(BC-5830)` so validator passes from first commit.

**Verify**: `./scripts/validate.sh` — frontmatter parses, all 6 required keys, `allowed-tools` exact match, EB SHORT form.

---

### Batch B — §1 Opener (issue Task 3)

**Files**: `SKILL.md` (§1 body).

**Implementation**: ~90–130 word opener paragraph.
- Audience: BDR leads, RevOps, marketing operators running Brite outbound.
- Problem (keystone positioning): campaign-analysis reports land, insights evaporate before shaping the next campaign. Engineering has decision-traces + precedents INDEX + compound-learnings; marketing had no parallel — this skill fills that gap.
- Outcome: one append-only `docs/campaigns/{entity}/learnings.md` per entity, entries carrying one of four objective verdicts, entity/vertical/persona/angle tags, transferable-insight flag that routes cross-entity patterns to marketing-context proposals or handbook-drift issues.
- Anchor phrase: "Under 5 minutes. Data suggests answers; operator confirms. Append-only, forever."
- NO tool names, repo paths, or MCP servers (those live in §4–§5).

---

### Batch C — §2 Before Starting (issue Task 4)

**Files**: `SKILL.md` (§2 body).

**Implementation**: Four gates + input-validation preamble.

1. **Input validation** (lift from creative-angles §2): `{entity}` matches `^(brite-nites|brite-supply|brite-labs)$`. `{campaign-name}` matches `^[a-z0-9-]+$`. Reject anything else before Write-path interpolation.
2. **Gate 1 — Marketing context (soft gate)**. Verbatim sibling string: "Check for product marketing context first. If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: 'Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.' Then continue using only user-provided information."
3. **Gate 2 — Campaign analysis data availability**. Glob `docs/campaigns/{entity}/analysis-*.md`: ≥1 match → post-analysis path (Procedure 1); zero → retroactive path (Procedure 2). Do NOT halt.
4. **Gate 3 — Entity identification**. `AskUserQuestion` to confirm Brite entity. Workspace routing: Nites → `emailbison-personal`; Supply + Labs → `emailbison-b2b`.
5. **Gate 4 — Campaign focus selection**. `AskUserQuestion` to identify which campaign. Post-analysis path: default to the most recent `analysis-*.md`. Retroactive path: operator supplies campaign name as free text.

---

### Batch D — §3 Methodology (issue Task 5, largest section)

**Files**: `SKILL.md` (§3 body).

**Implementation**: Subsections in order.

1. **§3 intro** (~70 words): three frameworks — 5-question debrief + 4-verdict rubric + append-only tagged learnings. Under-5-minute operator time is load-bearing. Suggest from data; operator confirms.
2. **### 5-question debrief format** — Q1 (hypothesis with format template), Q2 (CONFIRMED/PARTIAL/REJECTED + summary), Q3 (worked/didn't), Q4 (surprise, operator-authored), Q5 (transferable).
3. **### 4-verdict rubric** — concrete-threshold table, entity-scoped (b2b vs b2c), pulling from campaign-analysis §3.3 + §4:

| Verdict | b2b rule (Supply/Labs) | b2c rule (Nites) | Action |
|---|---|---|---|
| `SCALE` | Reply Rate >1% AND Interested >25% AND sent ≥500 | Reply Rate >0.5% AND Interested >15% AND sent ≥500 | Expand volume + senders |
| `ITERATE` | Mixed — one Healthy, one Attention, no Critical | Same (softer thresholds) | Swap one variable |
| `PAUSE` | Bounce Rate Attention (3–5%) OR sub-floor (<500 OR <7d) | Same | Wait + re-measure |
| `KILL` | Reply Rate <0.5% AND sent ≥500 AND days ≥7 | Reply Rate <0.25% AND sent ≥500 AND days ≥7 | Remove from matrix |

Objective — every cell resolves against numeric rules. Subjective phrasing ("okay", "meh") refused by §8.

4. **### Tag scheme** — four families, all lowercase-hyphenated: `#entity/{brite-nites|brite-supply|brite-labs}`, `#vertical/{v}`, `#persona/{p}`, `#angle/{a}`. All required per entry.
5. **### Transferable-insight flagging** — `transferable: true` triggers proposal to marketing-context.md OR handbook-drift flag. **Never edit marketing-context.md or handbook content directly** — proposal/signal only.
6. **### Append-only invariant** — learnings.md is append-only, forever. Later debrief contradicting earlier is a new entry. Summary stats / what-works / what-doesn't sections regenerate in place; Campaign log is strict-append.
7. **### Vocabulary mapping across sibling skills** — explicit table mapping this skill's 4 verdicts against campaign-analysis's 5 labels and MSPA's 5 labels. Three vocabularies exist because each skill owns a different decision surface.

---

### Batch E — §4 Brite Implementation + §5 MCP Tool Reference (issue Tasks 6–7, 13)

**Files**: `SKILL.md` (§4 and §5 bodies).

**§4 Implementation**:

1. **### Tools this skill calls** — 5-row table:
   - Read campaign-analysis artifact → `Read` + `Glob` → local `docs/campaigns/{entity}/analysis-*.md`
   - Pull Opportunity outcomes → SF MCP `run_soql_query` → brite-salesforce prod (ADR 2a)
   - Pull campaign metrics standalone → EB MCP (`get_active_workspace_info`, `get_campaign_stats`, `get_replies_analytics`) → entity-routed workspace
   - Read prior learnings.md (cross-entity) → `Read` + `Glob` → local `docs/campaigns/{*}/learnings.md`
   - Append/create learnings.md → `Write` → local
   
   **EB SHORT-form note** (load-bearing): all EB calls use `mcp__emailbison-b2b__*` / `mcp__emailbison-personal__*` — NOT `mcp__plugin_marketing_emailbison-*__*` (matches campaign-analysis line 5, MSPA line 5). `list_campaigns` needs client-side date filter (no server-side). `get_replies_analytics` (not `list_replies`) is the reply-sentiment tool.
2. **### Entity-keyed output paths** — `docs/campaigns/{entity}/learnings.md` where `{entity}` is long-form slug. Directory created on first write.
3. **### learnings.md file template (create-on-missing)** — full markdown template: `# Campaign Learnings — {entity}`, Summary stats, What works, What doesn't, Campaign log sections. Summary/what-works/what-doesn't regenerate in place on each append; Campaign log is strict-append.
4. **### Architectural rules that apply** — append-only (source §3); entity-driven workspace routing (source BC-2721, BC-5829); numeric-not-prose verdicts (source §3); under-5-minute constraint (source issue §Non-Goals); EB SHORT-form (source sibling allowed-tools); proposal-not-direct-write for marketing-context (source issue §Scope).
5. **### Cross-skill boundaries**:
   - **Receives from:** BC-2721 campaign-analysis (primary) via analysis-*.md. Handoff already live at campaign-analysis line 173. Operator directly (retroactive path).
   - **Hands off to:** BC-5829 MSPA (transferable_note flows to Notes column). BC-1727 product-marketing-context (conditional, on transferable flag). Handbook-drift workflow (conditional, on contradiction signal).
   - **Does not own:** Campaign analysis (BC-2721). Campaign execution (BC-2722). Next-experiment design (BC-5829). Marketing-context editing (BC-1727).
   - **Engineering-side parallel:** `docs/precedents/INDEX.md` decision-trace pattern — campaign-debrief is the marketing-flywheel cognate.

**§5 Implementation** (MCP Tool Reference):

1. **Workflow 1 — Read upstream analysis artifact (post-analysis path):** `Read` on Gate-2-globbed file. No availability probe.
2. **Workflow 2 — Standalone EB metrics fetch (retroactive path):** availability probe `get_active_workspace_info`; on failure halt and point to `/marketing:setup-email-bison`; on success `get_campaign_stats` + `get_replies_analytics` for operator-named campaign. Apply client-side date filter if `list_campaigns` involved.
3. **Workflow 3 — Salesforce Opportunity attribution (optional):** availability probe `SELECT Id FROM User LIMIT 1` (per BC-5534 §Q1); on success `run_soql_query` for `Campaign_Source__c`. Preflight: confirm field exists via FieldDefinition metadata query (BC-5797 factual-anchor rule). If missing, skip — do not fabricate.
4. **Workflow 4 — Append to learnings.md:** Glob-then-Write. On miss, Write with §4 template + first entry. On hit, Read → append new entry (regenerate summary stats / what-works / what-doesn't) → Write.
5. **Confirmation-gate note:** all calls are reads except final learnings.md Write. No MCP confirmation gates apply.

---

### Batch F — §6 Operational Runbook (issue Task 8, ≥4 workflows)

**Files**: `SKILL.md` (§6 body).

**Implementation**: 4 procedures, each with Preconditions / Steps / Expected output / Error handling / Handoff.

1. **Procedure 1 — Post-analysis debrief (happy path).** Preconditions: Gate 2 found ≥1 analysis-*.md; Gate 3/4 entity+campaign confirmed. Steps: read artifact → auto-suggest Q1 from §5 Attribution + Q2 from §2 verdict + Q3 from §5 top-2 → present 5 questions via `AskUserQuestion` (one per field per BC-5761 rule) → compute verdict from numeric thresholds → assemble tags (propose from artifact; operator confirms) → append to learnings.md (create if missing). Handoff: MSPA Notes-column feedback on transferable flag.
2. **Procedure 2 — Retroactive debrief (no analysis artifact).** Preconditions: Gate 2 empty; operator supplies campaign name. Steps: EB probe → `get_campaign_stats` + `get_replies_analytics` → derive metrics → 5-question flow. Error: on EB probe failure, halt and point to `/marketing:setup-email-bison`.
3. **Procedure 3 — Transferable-insight cross-entity propagation.** Preconditions: P1/P2 done; `transferable: true`. Steps: Glob other entities' learnings.md → if novel, `AskUserQuestion` proposing marketing-context update → on Yes, hand off to `/marketing:product-marketing-context` with payload; on No, note skip. Error: marketing-context skill unavailable → write proposal to `docs/campaigns/proposed-context-updates.md` (append-only) and note deferral.
4. **Procedure 4 — Handbook-drift flag.** Preconditions: P1/P2 done; insight contradicts handbook. Steps: `AskUserQuestion` confirming contradiction → on Yes, hand off to `/workflows:handbook-drift-check` with entry path + anchor; on No, note operator justification. Error: drift-check unavailable → create Linear issue via `mcp__linear__save_issue`.

---

### Batch G — §7 Rubric + §8 Anti-Slop (issue Tasks 9–10)

**Files**: `SKILL.md` (§7 and §8 bodies).

**§7 (Health Scoring Rubric, 4-tier):**

- **10**: All 5 questions asked + recorded verbatim; verdict from numeric thresholds with exact metrics cited; all 4 tag families lowercase-hyphenated; entry appended (never overwrite); transferable flag correct; debrief under 5 minutes; Q1/Q2/Q3 suggestions verbatim from artifact when present; retroactive probe on entity-matched workspace (never cross-workspace); marketing-context/handbook-drift proposal surfaced when transferable (not auto-written).
- **7–9**: One gap — e.g. 4 of 5 questions; verdict correct but threshold not cited; 3 of 4 tag families; 5–7 min.
- **4–6**: Functional but structural gaps — verdict without threshold check; TitleCase tags; missing `source_analysis` frontmatter; summary stats drifted (not regenerated).
- **1–3**: Hard failure — subjective verdict; learnings.md overwritten; auto-wrote to marketing-context/handbook without confirmation; skipped a gate; invented tag family; under-5-minute violated without operator scope extension.

**§8 (Anti-Slop Guardrails):**

- **Base (4):** no generic jargon; no fabricated stats; respect marketing-context.md; no hallucinated tools.
- **Skill-specific (5 required by issue §Verification):**
  - **Do not exceed 5 minutes of operator time.** Suggest answers from data first; one question at a time only when auto-suggest fails; no re-prompting already-answered fields.
  - **Do not overwrite learnings.md entries.** Append-only, strict. Summary/what-works/what-doesn't regenerate in place; Campaign log is strict-append.
  - **Do not skip data-first suggestion.** When analysis-*.md or EB metrics available, Q1/Q2/Q3 must auto-suggest.
  - **Do not use non-lowercase-hyphenated tags.** `#Entity/BriteNites`, spaces, underscores refused.
  - **Do not use subjective verdicts.** Only `SCALE`, `ITERATE`, `PAUSE`, `KILL`. Must trace to §3 threshold table.

---

### Batch H — §9 Behavioral Tests (issue Task 11, 6+ scenarios)

**Files**: `SKILL.md` (§9 body).

**Implementation**: Tier 1 + Tier 2 scenarios with deterministic assertions matching evals.json 1:1.

- **Tier 1 (6):**
  - `post-analysis-happy-path` — Nites analysis-*.md with Reply 1.4%, Interested 28%, Bounce 2%, sent=1200, days=14 → verdict SCALE, 4 tag families lowercase-hyphenated, one entry appended (creating file from template), handoff to marketing-context proposal if transferable.
  - `retroactive-manual-stats` — no analysis-*.md, operator-supplied name, EB probe succeeds, get_campaign_stats returns Reply 0.3%/Interested 12%/sent 800/days 10 → verdict KILL against b2b thresholds.
  - `subjective-verdict-refused` — operator-drafted entry with "pretty good"/"meh" → self-correct to numeric verdict.
  - `append-only-refuses-overwrite` — existing entry for same campaign-name → append new entry (debrief_at today), prior entry untouched.
  - `under-5-minute-autosuggest` — analysis-*.md present → Q1/Q2/Q3 auto-suggested (verified by absence of AskUserQuestion for hypothesis when §5 Attribution provides it); operator confirms with one tap each; Q4+Q5 prompt once each.
  - `tag-format-hyphenated` — operator says "Commercial Real Estate" → skill writes `#vertical/commercial-real-estate`.
- **Tier 2 (3):**
  - `transferable-cross-entity-flag` — transferable insight on brite-supply not in brite-labs/learnings.md → AskUserQuestion proposes marketing-context update; on Yes, hand off with payload; on No, note skip.
  - `missing-context-degraded-mode` — `docs/marketing-context.md` absent → warn with verbatim Gate 1 string, proceed, learnings.md written correctly, entry frontmatter carries no marketing-context reference.
  - `eb-short-form-namespace` — retroactive path → every EB call uses `mcp__emailbison-*__*` (short form); zero calls to `mcp__plugin_marketing_emailbison-*`.

---

### Batch I — `evals/evals.json` (issue Task 12, 6+ scenarios)

**Files**: `plugins/marketing/skills/campaign-debrief/evals/evals.json` (new).

**Implementation**: Match account-research/evals/evals.json shape. Top-level: `skill`, `version`, `scenarios`. Each scenario: `id` (matching §9), `tier`, `description`, `input` (with `mocked_*` fields), `assertions` (plain-English, grep-able). Target 150–200 lines.

Scenarios (9, IDs match §9 1:1):
1. `post-analysis-happy-path` (T1) — 10 assertions.
2. `retroactive-manual-stats` (T1) — 8 assertions.
3. `subjective-verdict-refused` (T1) — 6 assertions.
4. `append-only-refuses-overwrite` (T1) — 7 assertions.
5. `under-5-minute-autosuggest` (T1) — 6 assertions.
6. `tag-format-hyphenated` (T1) — 5 assertions.
7. `transferable-cross-entity-flag` (T2) — 8 assertions.
8. `missing-context-degraded-mode` (T2) — 6 assertions.
9. `eb-short-form-namespace` (T2) — 5 assertions.

---

### Batch J — Cross-links, registration, validation (issue Tasks 14–16)

**Files**: `plugins/marketing/skills/campaign-debrief/SKILL.md` final touches. No other edits.

**Implementation**:

1. **Task 14 — Cross-link verification (additive-only).** Confirm BC-2721 campaign-analysis line 173 already cites BC-5830 (live-read confirms). Confirm BC-5829 MSPA line 259 already cites BC-5830 pending (live-read confirms). **Do NOT edit BC-2721 or BC-5829 SKILL.md.** In campaign-debrief §4 Cross-skill boundaries, add reciprocal links. BC-2722 outbound-playbook pending → cite with `(BC-2722 pending)` label.
2. **Task 15 — Directory auto-discovery.** No explicit registration. Verify `./scripts/validate.sh` lists `campaign-debrief`.
3. **Task 16 — Final validation:**
   - `./scripts/validate.sh` → exit 0.
   - `./scripts/check-guardrails.sh --claude-md CLAUDE.md` → exit 0.

---

## Verification matrix (issue §Verification items → tasks)

| Issue verification item | Task batch |
|---|---|
| `SKILL.md` exists with required frontmatter | A |
| All 9 sections in required order | A (stubs) + B–H (fill) |
| `allowed-tools` matches Tool Surface exactly | A |
| §3 documents all 5 debrief questions with format templates | D |
| §3 documents all 4 verdicts with concrete thresholds | D |
| §3 documents tag scheme | D |
| §4 documents entity-keyed output path | E |
| §4 documents learnings.md template for create-on-missing | E |
| §6 has ≥4 workflows including retroactive + transferable | F |
| §8 Anti-Slop includes 5 required skill-specific rules | G |
| §9 Behavioral Tests has 6+ scenarios | H |
| `evals/evals.json` has 6+ scenarios | I |
| Entry format matches Revgrowth 12 + Brite entity tag | E (§4.3) + D (§3 tags) |
| Cross-links to BC-2721, BC-2722, MSPA | J |
| `./scripts/validate.sh` exits 0 | J |
| `./scripts/check-guardrails.sh` exits 0 | J |

## Risks + open questions

1. **Entity slug divergence.** Issue body specifies `#entity/{brite-nites|brite-supply|brite-labs}`. MSPA (BC-5829) uses `nites/supply/labs` as workspace validator. Plan ships with issue-authoritative long-form tags, documents divergence in §4. **No fix — issue is authoritative.** If Plan-gate reviewer disagrees, raise before Batch C.
2. **Verdict-vocabulary collision across siblings.** Three vocabularies: campaign-analysis (5 labels), MSPA (5 labels), campaign-debrief (4 labels). Only `SCALE` overlaps intentionally. Mitigation: §3 Vocabulary-mapping subsection.
3. **BC-2721 campaign-analysis handoff already live.** Line 173 refers to BC-5830 as mandatory handoff. If BC-5830 ships with any deviation from that clause's expected interface, campaign-analysis hands off to wrong shape. **Mitigation:** Batch J re-reads campaign-analysis §4 line 173 to confirm handoff shape matches what campaign-debrief accepts. No edit.
4. **BC-5829 MSPA reciprocity.** Line 259 cites "transferable learnings flow back into Notes column on next ITERATE". Implies MSPA reads `transferable_note` from learnings.md. MSPA Step 4 (line 131) does NOT currently document that read. **Surface during Batch F:** flag as BC-5829 follow-up issue — do not edit MSPA inline.
5. **Memory stale-deferral trap.** `project_session_BC-2721.md` deferral was 1 day old on plan authorship. If the deferral reflects a decision that wasn't captured elsewhere, proceeding may conflict. **Recommend operator confirm** before Batch A kickoff.
6. **`docs/marketing-context.md` absent at plan time.** The degraded-mode behavioral scenario is the load-bearing test. If `/marketing:product-marketing-context` runs between plan and execution, the test needs the mock path not real.
7. **EB MCP tool naming — `list_campaigns` + `get_replies_analytics`.** `list_campaigns` has no server-side date filter. `get_replies_analytics` (not `list_replies`). Plan §5 Workflow 2 anchors the call pattern.
