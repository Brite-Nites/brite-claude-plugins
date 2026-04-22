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

<!-- TODO(BC-5830) §3 — Batch D (largest section). Subsections: §3 intro; 5-question debrief format with templates; 4-verdict rubric with entity-scoped threshold table (b2b vs b2c); tag scheme (4 families, lowercase-hyphenated); transferable-insight flagging (proposal-not-direct-write); append-only invariant (with carve-out for summary stats / what-works / what-doesn't sections that regenerate in place); vocabulary mapping across sibling skills. -->

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
