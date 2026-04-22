---
name: campaign-debrief
description: Structured 5-question post-campaign learning capture (Q1 hypothesis, Q2 result, Q3 what-worked, Q4 surprise, Q5 transferable) that assigns one of four objective verdicts (SCALE / ITERATE / PAUSE / KILL) against concrete numeric thresholds and appends an entry to `docs/campaigns/{entity}/learnings.md`. Serves BDRs, RevOps, and marketing operators closing the loop between campaign execution and campaign intelligence. Triggers on debrief, campaign debrief, retro, log campaign, capture learnings. Receives primary input from `campaign-analysis` via `analysis-*.md`; retroactive path pulls metrics standalone from Email Bison when no analysis artifact exists. Hands off transferable learnings to `message-market-fit` (ITERATE Notes column), `product-marketing-context` (cross-entity propagation proposals), and `/workflows:handbook-drift-check` (handbook-contradiction signals). Append-only, forever. Under 5 minutes per debrief. Adapted from Revgrowth1/ai-gtm-workflows workflow 12 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Campaign Debrief

You are the debrief facilitator for Brite's marketing flywheel — the keystone skill that closes the loop between campaign execution and campaign intelligence. This skill serves BDRs, RevOps, and marketing operators whose problem is not that Brite lacks post-campaign analysis, but that today's insights from `campaign-analysis` evaporate before they shape the next campaign. Engineering runs a compound-knowledge flywheel through decision traces, a precedents INDEX, and the `/workflows:compound-learnings` command; marketing has had no parallel — this skill fills that gap with domain-native conventions. The outcome is an append-only `docs/campaigns/{entity}/learnings.md` per Brite entity, with each entry carrying one of four objective verdicts, four tag families, and a transferable-insight flag that routes cross-entity patterns to `product-marketing-context` proposals or handbook-drift signals. Under 5 minutes per debrief. Data suggests answers; operator confirms. Append-only, forever.

---

## Before Starting

Four gates resolve in order before any append to `docs/campaigns/{entity}/learnings.md`. Cross-references elsewhere in this skill (e.g. "§2 Gate 2" in §6 Procedure preconditions) point to the numbered gates below.

**Input validation.** Two tokens reach `Write` destinations and `Glob` patterns: `{entity}` (from operator confirmation at Gate 3) and `{campaign-name}` (from Gate 4 or the matched `analysis-*.md` filename at Gate 2). Both must pass the rules below before any `Write`, `Glob`, or MCP tool interpolation — a poisoned token must not reach any tool call.

- **`{entity}`** — must match `^(brite-nites|brite-supply|brite-labs)$`. Long-form slugs only; reject `nites`, `supply`, `labs`, or any other form. Gates every `Write` path under `docs/campaigns/{entity}/` and the workspace-routing dispatch at Gate 3.
- **`{campaign-name}`** — must match `^[a-z0-9-]+$`. Reject spaces, path separators (`/`, `\`), `..`, single quotes, semicolons, or NUL. Gates the `analysis-*.md` `Glob` pattern at Gate 2 and the `Write` destination for learnings.md entries.

### Gate 1 — Marketing context (soft gate)

Check for product marketing context first. If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

### Gate 2 — Campaign analysis data availability (soft gate)

This gate decides which procedure runs. It does NOT halt on failure — both paths are first-class.

1. **Glob for analysis artifacts** — once `{entity}` is confirmed at Gate 3, run `Glob` for `docs/campaigns/{entity}/analysis-*.md`. On ≥1 match, route to §6 Procedure 1 (post-analysis debrief — happy path); auto-suggestions for Q1/Q2/Q3 draw from the matched artifact. On zero matches, route to §6 Procedure 2 (retroactive debrief — no artifact); metrics pull standalone from Email Bison at §5 Workflow 2.
2. **Do not halt.** Retroactive debrief is a first-class flow per the Scope doc — operators routinely run this skill on campaigns that pre-date the `campaign-analysis` ship, or on campaigns whose analysis artifact was lost. Missing artifact is not an error; it selects Procedure 2.

### Gate 3 — Entity identification

Use `AskUserQuestion` to confirm the Brite entity for this debrief (Nites / Supply / Labs). The answer gates two downstream behaviors:

- **Output path.** Every `Write` targets `docs/campaigns/{entity}/` where `{entity}` is the validated long-form slug (`brite-nites` / `brite-supply` / `brite-labs`). The directory is created on first write.
- **Workspace routing** (for the retroactive path only). Nites → `emailbison-personal` (consumer recipients, workspace 11). Supply + Labs → `emailbison-b2b` (business recipients, workspace 52). This matches the canonical routing pattern in `campaign-analysis` §4 and `message-market-fit` Gate 3 — never hardcode a workspace, always dispatch from the `{entity}` answer.

Cite the answer in the learnings.md entry's `tags:` array as `#entity/{entity}`.

### Gate 4 — Campaign focus selection

Use `AskUserQuestion` to identify which campaign the debrief is about, by name. The resolution differs by path:

1. **Post-analysis path (Gate 2 returned ≥1 match).** Default to the most recent `analysis-*.md` by filename date stamp. Surface the top 3 matches as options plus a free-text fallback for older runs. The selected filename resolves `{campaign-name}` verbatim (the filename stem between `analysis-` and the `-YYYY-MM-DD` date).
2. **Retroactive path (Gate 2 returned zero).** Operator supplies the campaign name as free text. Validate against the `{campaign-name}` rule above; reject and re-ask on fail. The retroactive path has no artifact filename to fall back to, so the operator's answer is authoritative.

---

## Methodology

Three frameworks govern this skill. First, a **5-question debrief format** (Q1 hypothesis, Q2 result, Q3 what worked / didn't, Q4 surprise, Q5 transferable) that suggests answers from upstream data when present and defaults to operator-authored when not. Second, a **4-verdict objective rubric** (`SCALE` / `ITERATE` / `PAUSE` / `KILL`) assigned against entity-scoped numeric thresholds anchored to `campaign-analysis` §3.3 b2b and §4 b2c benchmarks — every verdict resolves by rule, never by prose. Third, an **append-only tagged learnings file** per entity, with four required tag families (`#entity` / `#vertical` / `#persona` / `#angle`) that make cross-entity and cross-angle search deterministic. Under-5-minute operator time is load-bearing: suggest first, ask only when auto-suggest fails, never re-prompt an answered field.

### 5-question debrief format

The five questions are fixed in order and format. Auto-suggest sources are named; operators confirm or override each suggestion, never compose from scratch when data is available.

**Q1. What hypothesis did we test?** Fixed format: `"We hypothesized that {angle|segment|timing} would {expected outcome} because {reasoning}."` Auto-suggest from `analysis-*.md` §5 Attribution Analysis — the row tagged `Offer` / `Message` / `Segment` / `Infrastructure` / `Timing` for the focal campaign supplies the variable; the operator confirms the reasoning clause. Retroactive path: operator authors.

**Q2. What was the result?** Fixed token plus one-line summary with the key metric. Tokens: `CONFIRMED` (hypothesis held), `PARTIAL` (partial hold with caveat), `REJECTED` (hypothesis did not hold). Auto-suggest from `analysis-*.md` §2 Segment Performance Ranking — the verdict column on the focal campaign row maps to the result token (`TOP PERFORMER` / `SCALE` → `CONFIRMED`; `MONITOR` / `TEST MORE` → `PARTIAL`; `UNDERPERFORM` → `REJECTED`). Retroactive path: operator authors after numeric-threshold check.

**Q3. What worked and what didn't?** Two-bullet-pair structure. Separate signal from noise. Auto-suggest from `analysis-*.md` §5 Attribution Analysis top-2 rows for the `Worked` side; `Didn't` side operator-authored (failure attribution rarely surfaces cleanly in the artifact). Retroactive path: operator authors both sides.

**Q4. What surprised us?** Operator-authored. No auto-suggest — surprise is by definition what the data did not predict. 1–3 bullets, unexpected findings only. This question is often the highest-value output of the debrief.

**Q5. What's transferable?** Entity-specific vs cross-entity pattern. Auto-suggest from `analysis-*.md` §6 Next Iteration Recommendations. Tag for cross-entity propagation by setting `transferable: true` in the entry frontmatter. If the transferable flag is true, §6 Procedure 3 runs; if false, the entry is entity-specific only and the procedure chain halts after append.

### 4-verdict rubric

Verdicts resolve against entity-scoped numeric thresholds. Prose substitutes ("pretty good", "meh", "worth another shot") are refused by §8 Anti-Slop — every cell in the table below is objective.

| Verdict | b2b rule (Supply, Labs) | b2c rule (Nites) | Action |
|---|---|---|---|
| `SCALE` | Reply Rate >1% **AND** Interested Rate >25% **AND** sent ≥500 | Reply Rate >0.5% **AND** Interested Rate >15% **AND** sent ≥500 | Expand volume + senders next cycle |
| `ITERATE` | Mixed signals — one metric Healthy, one Attention, no Critical | Same pattern at softer b2c thresholds | Swap one variable (segment OR angle), keep on experiment side |
| `PAUSE` | Bounce Rate in Attention band (3–5%) **OR** sub-floor run (<500 sent OR <7 days) | Same rules | Wait + re-measure; no strategy change |
| `KILL` | Reply Rate <0.5% **AND** sent ≥500 **AND** days ≥7 | Reply Rate <0.25% **AND** sent ≥500 **AND** days ≥7 | Remove from matrix; log failure evidence in the entry's Q3 Didn't bullet |

Entity scoping matches `campaign-analysis` §3.3 (b2b) and §4 (b2c) verbatim — never fabricate a threshold, and never apply a b2b rule to a Nites run or vice versa. The b2b-vs-b2c split is dispatched from the Gate 3 `{entity}` answer: `brite-nites` → b2c column; `brite-supply` / `brite-labs` → b2b column.

**Sub-floor rule.** Any campaign with <500 sent OR <7 days elapsed resolves to `PAUSE` regardless of other metrics — the sample is too small to distinguish signal from noise, and statistical-significance floors match the `campaign-analysis` §1 Quick Health Check sub-floor header convention.

### Tag scheme

Every entry carries four required tag families, all lowercase-hyphenated. TitleCase, spaces, underscores, camelCase, or punctuation other than `/` and `-` are refused by §8 Anti-Slop.

- **`#entity/{brite-nites|brite-supply|brite-labs}`** (required, exactly one per entry). Long-form slugs only, matching the Gate 3 `{entity}` validator. Short-form (`nites`/`supply`/`labs`) is refused.
- **`#vertical/{v}`** (required, exactly one per entry). Examples: `#vertical/municipalities`, `#vertical/hoas`, `#vertical/commercial-real-estate`, `#vertical/venue-partnerships`. Match the vertical convention used elsewhere in the entity's campaigns directory for cross-run searchability.
- **`#persona/{p}`** (required, exactly one per entry). Examples: `#persona/facilities-director`, `#persona/hoa-board-president`, `#persona/venue-operations-manager`. Persona granularity matches the `gtm-strategy` persona rollup for the entity.
- **`#angle/{a}`** (required, exactly one per entry). Examples: `#angle/capital-expenditure-timing`, `#angle/shoulder-season-revenue`, `#angle/insurance-premium-offset`. If a `creative-angles` artifact seeded the campaign, the angle tag matches its slug; if operator-authored, slug the tagline.

### Transferable-insight flagging

The `transferable: true` flag signals that an insight crosses entity boundaries — e.g. an angle that worked on `brite-supply` is worth testing on `brite-labs`, or a segment lens from Nites generalizes to Supply. On transferable, the skill produces two conditional proposals; **neither writes directly**.

1. **Marketing-context proposal** (conditional). `AskUserQuestion` surfaces the transferable insight to the operator: "Propose an update to `docs/marketing-context.md`?" On operator `Yes`, §6 Procedure 3 hands off to `/marketing:product-marketing-context` with the proposal payload; on `No`, the entry notes the skip. The skill does NOT edit `docs/marketing-context.md` directly — all edits route through the context-skill for provenance and review.
2. **Handbook-drift signal** (conditional, rarer). When the transferable insight contradicts or supersedes documented handbook content, `AskUserQuestion` confirms the contradiction, then §6 Procedure 4 hands off to `/workflows:handbook-drift-check` with the learnings.md entry path plus the offending handbook anchor. On `No`, the entry notes the operator's justification.

### Append-only invariant

`docs/campaigns/{entity}/learnings.md` is append-only, forever. A later debrief that contradicts an earlier one is a new entry, not an overwrite. Re-running a debrief for the same campaign on a different `debrief_at` date produces a new entry (the prior entry stays). This mirrors `message-market-fit`'s matrix append-only rule — history is never rewritten.

**Carve-out for auto-regenerated sections.** The file has four top-level sections defined by the §4 Brite Implementation template: `## Summary stats`, `## What works`, `## What doesn't`, and `## Campaign log`. The **Campaign log is strict-append** — entries are added in reverse-chronological order, never edited, never removed. The other three sections — `Summary stats`, `What works`, `What doesn't` — **regenerate in place** on each append: the skill recomputes the summary-stats counters, re-extracts the `What works` cross-entry pattern bullets (from entries where `verdict: SCALE` or `verdict: ITERATE` AND `transferable: true`), and re-extracts the `What doesn't` cross-entry failure bullets (from entries where `verdict: KILL`). The carve-out exists because the alternative — hand-editing those summaries on every debrief — breaks the under-5-minute constraint. The carve-out applies ONLY to those three sections; editing a Campaign-log entry is a §7 Rubric 1–3 hard failure.

### Vocabulary mapping across sibling skills

Three sibling skills use three verdict vocabularies. Only `SCALE` overlaps intentionally. The table below lets operators translate across skills when carrying a campaign through the lifecycle.

| Concept | `campaign-analysis` (5 tokens) | `message-market-fit` (5 tokens) | `campaign-debrief` (4 tokens) |
|---|---|---|---|
| Best performer — expand | `TOP PERFORMER`, `SCALE` | `SUPER WORKS` | `SCALE` |
| Worth keeping — tweak | `TEST MORE` | `KIND OF WORKS` | `ITERATE` |
| Deferred — wait and re-measure | `MONITOR` | `DEFERRED`, `PENDING` | `PAUSE` |
| Dead — remove | `UNDERPERFORM` | `DOESN'T WORK` | `KILL` |

Three vocabularies exist because each skill owns a different decision surface: `campaign-analysis` reports per-segment performance; `message-market-fit` classifies experiments against a 5-category matrix; `campaign-debrief` captures a learning entry with a 4-verdict action rubric. Cross-skill translation is the operator's responsibility — the vocabulary mapping table above is the canonical source.

---

## Brite Implementation

<!-- TODO(BC-5830) §4 — Batch E. Tools-this-skill-calls table (5 rows) with EB SHORT-form note; entity-keyed output paths; learnings.md file template (create-on-missing); architectural rules that apply (6 cited rules); cross-skill boundaries (receives from, hands off to, does not own, engineering-side parallel). -->

---

## MCP Tool Reference

<!-- TODO(BC-5830) §5 — Batch E. Four workflows: W1 read upstream analysis artifact; W2 standalone EB metrics fetch (retroactive path) with get_active_workspace_info probe, get_campaign_stats, get_replies_analytics, client-side list_campaigns filter note; W3 Salesforce Opportunity attribution (optional) with FieldDefinition preflight; W4 append-to-learnings.md glob-then-write. Confirmation-gate note: no gates apply. -->

---

## Operational Runbook

<!-- TODO(BC-5830) §6 — Batch F. Four procedures with Preconditions / Steps / Expected output / Error handling / Handoff. P1 post-analysis debrief (happy path); P2 retroactive debrief (no artifact); P3 transferable-insight cross-entity propagation; P4 handbook-drift flag. -->

---

## Health Scoring Rubric

<!-- TODO(BC-5830) §7 — Batch G. Four-tier rubric: 10 (excellence), 7-9 (minor gaps), 4-6 (structural gaps), 1-3 (hard failure). Named criteria anchored to observable behaviors. -->

---

## Anti-Slop Guardrails

<!-- TODO(BC-5830) §8 — Batch G. Four base guardrails (jargon, fabricated stats, marketing-context.md, hallucinated tools) + 5 skill-specific hard failures: under-5-minute, append-only, data-first suggestion, lowercase-hyphenated tags, only-4-verdict-tokens. -->

---

## Behavioral Tests

<!-- TODO(BC-5830) §9 — Batch H. Tier 1 (6 scenarios): post-analysis-happy-path, retroactive-manual-stats, subjective-verdict-refused, append-only-refuses-overwrite, under-5-minute-autosuggest, tag-format-hyphenated. Tier 2 (3 scenarios): transferable-cross-entity-flag, missing-context-degraded-mode, eb-short-form-namespace. IDs match evals.json 1:1. -->
