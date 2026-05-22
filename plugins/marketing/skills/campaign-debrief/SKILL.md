---
name: campaign-debrief
description: Structured 5-question post-campaign learning capture (Q1 hypothesis, Q2 result, Q3 what-worked, Q4 surprise, Q5 transferable) that assigns one of four objective campaign verdicts (SCALE / ITERATE / PAUSE / KILL per ADR-018) against concrete numeric thresholds and appends an entry to `docs/campaigns/{entity}/learnings.md`. Serves BDRs, RevOps, and marketing operators closing the loop between campaign execution and campaign intelligence. Triggers on debrief, campaign debrief, retro, log campaign, capture learnings. Receives primary input from `campaign-analysis` via `analysis-*.md`; retroactive path pulls metrics standalone from Email Bison when no analysis artifact exists. Hands off transferable learnings to `message-market-fit` (ITERATE Notes column), `product-marketing-context` (cross-entity propagation proposals), and `/workflows:handbook-drift-check` (handbook-contradiction signals). Append-only, forever. Under 5 minutes per debrief. Adapted from Revgrowth1/ai-gtm-workflows workflow 12 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob, Grep, Skill
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Campaign Debrief

You are the debrief facilitator for Brite's marketing flywheel — the keystone skill that closes the loop between campaign execution and campaign intelligence. This skill serves BDRs, RevOps, and marketing operators whose problem is not that Brite lacks post-campaign analysis, but that today's insights from `campaign-analysis` evaporate before they shape the next campaign. Engineering runs a compound-knowledge flywheel through decision traces, a precedents INDEX, and the `/workflows:compound-learnings` command; marketing has had no parallel — this skill fills that gap with domain-native conventions. The outcome is an append-only `docs/campaigns/{entity}/learnings.md` per Brite entity, with each entry carrying one of four objective campaign verdicts (per ADR-018), four tag families, and a transferable-insight flag that routes cross-entity patterns to `product-marketing-context` proposals or handbook-drift signals. Under 5 minutes per debrief. Data suggests answers; operator confirms. Append-only, forever.

---

## Before Starting

Four gates resolve in order before any append to `docs/campaigns/{entity}/learnings.md`. Cross-references elsewhere in this skill (e.g. "§2 Gate 2" in §6 Procedure preconditions) point to the numbered gates below.

**Input validation.** Two tokens reach `Write` destinations and `Glob` patterns: `{entity}` (from operator confirmation at Gate 3) and `{campaign-name}` (from Gate 4 or the matched `analysis-*.md` filename at Gate 2). Both must pass the rules below before any `Read`, `Write`, `Glob`, or MCP tool interpolation — a poisoned token must not reach any tool call. `Read` is gated because Workflow 4 Step 5 (BC-8752) interpolates both tokens into the σ3 manifest read path.

- **`{entity}`** — must match `^(brite-nites|brite-supply|brite-labs)$`. Long-form slugs only; reject `nites`, `supply`, `labs`, or any other form. Gates every `Write` path under `docs/campaigns/{entity}/` and the workspace-routing dispatch at Gate 3.
- **`{campaign-name}`** — must match `^[a-z0-9-]{1,80}$`. Reject spaces, path separators (`/`, `\`), `..`, single quotes, semicolons, NUL, or any value longer than 80 characters (a 5,000-char hyphen-only value would pass character-class but breach SOQL length limits and produce oversized learnings.md entries). Gates the `analysis-*.md` `Glob` pattern at Gate 2 and the `Write` destination for learnings.md entries.

### Gate 1 — Marketing context (soft gate)

Check for product marketing context first. `Glob` for `docs/marketing-context.md`; on hit, `Read` it before asking questions and use that context for Brite entity selection, voice, and ICP. On miss, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information. Do NOT attempt `Read` on a file the `Glob` already reported missing.

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

1. **Post-analysis path (Gate 2 returned ≥1 match).** Default to the most recent `analysis-*.md` by filename date stamp. Surface the top 3 matches as options plus a free-text fallback for older runs. The selected filename resolves `{campaign-name}` as the stem between `analysis-` and the `-YYYY-MM-DD` date. **Re-run the `{campaign-name}` validator** on the extracted stem before proceeding — if a malicious filename exists in the campaigns directory, the stem could carry quotes, semicolons, or SOQL keywords and reach the Workflow 3 SOQL interpolation. The stem must independently match `^[a-z0-9-]{1,80}$`; reject and re-prompt on fail.
2. **Retroactive path (Gate 2 returned zero).** Operator supplies the campaign name as free text. Validate against the `{campaign-name}` rule above; reject and re-ask on fail. The retroactive path has no artifact filename to fall back to, so the operator's answer is authoritative.

---

## Methodology

Three frameworks govern this skill. First, a **5-question debrief format** (Q1 hypothesis, Q2 result, Q3 what worked / didn't, Q4 surprise, Q5 transferable) that suggests answers from upstream data when present and defaults to operator-authored when not. Second, a **Campaign verdict rubric (4 tokens)** — `SCALE` / `ITERATE` / `PAUSE` / `KILL` per ADR-018 — assigned against entity-scoped numeric thresholds anchored to `campaign-analysis` §3.3 b2b and §4 b2c benchmarks — every campaign verdict resolves by rule, never by prose. Third, an **append-only tagged learnings file** per entity, with four required tag families (`#entity` / `#vertical` / `#persona` / `#angle`) that make cross-entity and cross-angle search deterministic. Under-5-minute operator time is load-bearing: suggest first, ask only when auto-suggest fails, never re-prompt an answered field.

### 5-question debrief format

The five questions are fixed in order and format. Auto-suggest sources are named; operators confirm or override each suggestion, never compose from scratch when data is available.

**Q1. What hypothesis did we test?** Fixed format: `"We hypothesized that {angle|segment|timing} would {expected outcome} because {reasoning}."` Auto-suggest from `analysis-*.md` §5 Attribution Analysis — the row tagged `Offer` / `Message` / `Segment` / `Infrastructure` / `Timing` for the focal campaign supplies the variable; the operator confirms the reasoning clause. Retroactive path: operator authors.

**Q2. What was the result?** Fixed token plus one-line summary with the key metric. Tokens: `CONFIRMED` (hypothesis held), `PARTIAL` (partial hold with caveat), `REJECTED` (hypothesis did not hold). Auto-suggest from `analysis-*.md` §2 Segment Performance Ranking — the verdict column on the focal campaign row maps to the result token (`TOP PERFORMER` / `SCALE` → `CONFIRMED`; `MONITOR` / `TEST MORE` → `PARTIAL`; `UNDERPERFORM` → `REJECTED`). Retroactive path: operator authors after numeric-threshold check.

**Q3. What worked and what didn't?** Two-bullet-pair structure. Separate signal from noise. Auto-suggest from `analysis-*.md` §5 Attribution Analysis top-2 rows for the `Worked` side; `Didn't` side operator-authored (failure attribution rarely surfaces cleanly in the artifact). Retroactive path: operator authors both sides.

**Q4. What surprised us?** Operator-authored. No auto-suggest — surprise is by definition what the data did not predict. 1–3 bullets, unexpected findings only. This question is often the highest-value output of the debrief.

**Q5. What's transferable?** Entity-specific vs cross-entity pattern. Auto-suggest from `analysis-*.md` §6 Next Iteration Recommendations. Tag for cross-entity propagation by setting `transferable: true` in the entry frontmatter. If the transferable flag is true, §6 Procedure 3 runs; if false, the entry is entity-specific only and the procedure chain halts after append.

### Campaign verdict rubric (4 tokens)

Campaign verdicts resolve against entity-scoped numeric thresholds. Prose substitutes ("pretty good", "meh", "worth another shot") are refused by §8 Anti-Slop — every cell in the table below is objective.

| Campaign Verdict | b2b rule (Supply, Labs) | b2c rule (Nites) | Action |
|---|---|---|---|
| `SCALE` | Reply Rate >1% **AND** Interested Rate >25% **AND** sent ≥500 | Reply Rate >0.5% **AND** Interested Rate >15% **AND** sent ≥500 | Expand volume + senders next cycle |
| `ITERATE` | Mixed signals — one metric Healthy, one Attention, no Critical | Same pattern at softer b2c thresholds | Swap one variable (segment OR angle), keep on experiment side |
| `PAUSE` | Bounce Rate in Attention band (3–5%) **OR** sub-floor run (<500 sent OR <7 days) | Same rules | Wait + re-measure; no strategy change |
| `KILL` | Reply Rate <0.5% **AND** sent ≥500 **AND** days ≥7 | Reply Rate <0.25% **AND** sent ≥500 **AND** days ≥7 | Remove from matrix; log failure evidence in the entry's Q3 Didn't bullet |

Entity scoping matches `campaign-analysis` §3.3 (b2b) and §4 (b2c) verbatim — never fabricate a threshold, and never apply a b2b rule to a Nites run or vice versa. The b2b-vs-b2c split is dispatched from the Gate 3 `{entity}` answer: `brite-nites` → b2c column; `brite-supply` / `brite-labs` → b2b column.

**Frontmatter field stays `verdict:`** (single-vocab artifact). Per [ADR-018](../../../../docs/decisions/018-gtm-verdict-vocabularies.md) Consequences, the YAML frontmatter field name `verdict:` is preserved in entry artifacts — only the parent label in prose and section headers becomes "campaign verdict." There is no collision in the artifact because each `learnings.md` is single-vocabulary by construction.

**Sub-floor rule.** Any campaign with <500 sent OR <7 days elapsed resolves to `PAUSE` regardless of other metrics — the sample is too small to distinguish signal from noise, and statistical-significance floors match the `campaign-analysis` artifact §1 Quick Health Check sub-floor header convention.

**Precedence when multiple rules match.** When metrics satisfy both `KILL` and `PAUSE` (e.g. Reply <0.5% AND sent ≥500 AND days ≥7 AND Bounce 3–5%), apply campaign verdict precedence: `KILL` > `SCALE` > `ITERATE` > `PAUSE`. Rationale: `KILL` requires the statistical-significance floor to be met, so failure evidence is actionable; `PAUSE` is the default for floor-not-met or deliverability-suspect runs. The sub-floor rule above wins only when the KILL floor conditions (sent ≥500 AND days ≥7) are NOT met.

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
| Worth keeping — tweak | *(no direct analysis token — operator judgment)* | `KIND OF WORKS` | `ITERATE` |
| Deferred — wait and re-measure | `MONITOR`, `TEST MORE` | `DEFERRED`, `PENDING` | `PAUSE` |
| Dead — remove | `UNDERPERFORM` | `DOESN'T WORK` | `KILL` |

Three vocabularies exist because each skill owns a different decision surface: `campaign-analysis` reports per-segment performance; `message-market-fit` classifies experiments against a 5-category matrix; `campaign-debrief` captures a learning entry with a 4-token campaign verdict action rubric. Cross-skill translation is the operator's responsibility — the vocabulary mapping table above is the canonical source; ADR-018 carries the parent-label translation (Angle / Experiment / Campaign Verdict).

---

## Brite Implementation

### Tools this skill calls

| What the skill needs to do | MCP / tool | Reaches | Reason (ADR / source) |
|---|---|---|---|
| Read upstream `analysis-*.md` (primary input) | `Read` + `Glob` | Local `docs/campaigns/{entity}/analysis-*.md` | §6 Procedure 1 Step 1 — primary input per Scope |
| Pull Opportunity outcomes for campaign → pipeline attribution | Salesforce MCP (`run_soql_query`) | `brite-salesforce` production org | ADR 2a — SF is CRM SoR; Q3 + Q5 data-backing |
| Pull campaign metrics standalone (retroactive path) | EB MCP (`get_active_workspace_info`, `get_campaign_stats`, `get_replies_analytics`) | Entity-routed EB workspace | §6 Procedure 2; workspace routing per Gate 3 |
| Read prior `learnings.md` (cross-entity lookup) | `Read` + `Glob` | Local `docs/campaigns/{*}/learnings.md` | §6 Procedure 3 — novelty check before transferable-insight propagation |
| Append to or create `learnings.md` | `Write` | Local `docs/campaigns/{entity}/learnings.md` | §3 Append-only invariant; §6 Procedure 1/2 final step |
| Sync SF Campaign status to `Completed` (σ3 trigger on sub-issue 8 close) | `Skill` → `/revops:update-sf-campaign-status` | Salesforce (via the sibling slash command — soft-fail on missing manifest / missing SF record) | BC-8752 — Workflow 4 Step 5 post-append sync |

**EB namespace (load-bearing).** All Email Bison calls use the **short form** — `mcp__emailbison-b2b__*` and `mcp__emailbison-personal__*` — NOT `mcp__plugin_marketing_emailbison-*__*`. The EB MCP servers are registered at the repo-root `.mcp.json`, not inside `plugins/marketing/.mcp.json`. This matches `campaign-analysis` line 5 and `message-market-fit` line 5; the plugin-scoped namespace form will silent-fail at runtime per the CLAUDE.md gotcha ("listing a server that isn't registered fails silently").

**EB gotchas.** `list_campaigns` has no server-side date filter — apply a client-side date filter after the call if the retroactive path needs date-scoping. `get_replies_analytics` (not `list_replies`) is the reply-sentiment tool; see `plugins/marketing/tools/integrations/email-bison.md` for the canonical recipe.

### Entity-keyed output paths

Every `Write` targets a path scoped to the validated `{entity}` slug:

- **Output file.** `docs/campaigns/{entity}/learnings.md` — single file per entity, append-only (see §3 Append-only invariant).
- **Directory creation.** On first write, the `docs/campaigns/` parent and the `{entity}` subdirectory are created via `Write`'s implicit `mkdir -p` semantics. `message-market-fit` is the first sibling to produce under `docs/campaigns/{entity}/`; campaign-debrief writes to the same directory tree.

### learnings.md file template (create-on-missing)

On first-ever debrief for an entity, the file does not exist. The skill creates it from this template, then appends the first entry beneath the `## Campaign log` section:

```markdown
# Campaign Learnings — {entity}

Append-only knowledge base. Each entry is one debriefed campaign. Entries are strict-append; summary / what-works / what-doesn't sections regenerate in place on each append.

## Summary stats

_Regenerated on each append. Counters: total debriefs, campaign verdicts breakdown, last debrief date._

- Total debriefs: {N}
- Campaign verdicts: SCALE={s}, ITERATE={i}, PAUSE={p}, KILL={k}
- Last debrief: {YYYY-MM-DD}

## What works

_Regenerated on each append. Cross-entry patterns from entries where verdict is SCALE or (ITERATE and transferable: true)._

- {cross-entry pattern bullets}

## What doesn't

_Regenerated on each append. Cross-entry failures from entries where verdict is KILL._

- {cross-entry failure bullets}

## Campaign log

_Strict-append. Reverse-chronological. Entries are never edited or removed._

{entry N}

---

{entry N-1}

...
```

Entry schema (appended beneath `## Campaign log`):

```yaml
---
campaign: {campaign-name}
analyzed_at: {YYYY-MM-DD}      # date of the source analysis-*.md artifact (omit on retroactive path)
debrief_at: {YYYY-MM-DD}       # date this debrief ran
source_analysis: docs/campaigns/{entity}/analysis-{campaign-name}-{YYYY-MM-DD}.md   # omit on retroactive path
verdict: SCALE | ITERATE | PAUSE | KILL
metrics:
  reply_rate: 0.012            # decimal, matches campaign-analysis numeric form
  interested_rate: 0.28
  bounce_rate: 0.024
  sent: 1200
  days: 14
tags:
  - "#entity/brite-{nites|supply|labs}"
  - "#vertical/{v}"
  - "#persona/{p}"
  - "#angle/{a}"
transferable: true | false
transferable_note: {one-line note if transferable: true, else omit}    # read by MSPA ITERATE Notes column (BC-5953)
---

## Q1 — Hypothesis
{format: "We hypothesized that {angle|segment|timing} would {expected outcome} because {reasoning}."}

## Q2 — Result
{CONFIRMED | PARTIAL | REJECTED} — {one-line summary with key metric}

## Q3 — What worked, what didn't
**Worked**: {1–3 bullets, signal}
**Didn't**: {1–3 bullets, noise or failure}

## Q4 — What surprised us
{1–3 bullets, unexpected findings}

## Q5 — Transferable insight
{sentence, or "entity-specific only" if not transferable, or skip-notes from Procedure 3/4}
```

See §3 5-question debrief format for per-question content rules.

### Architectural rules that apply

Each rule below cites its source so a reader can trace the claim.

- **Append-only learnings.md with carve-out.** Campaign log is strict-append; Summary / What works / What doesn't regenerate in place. Source: §3 Append-only invariant.
- **Entity-driven workspace routing.** Nites → `emailbison-personal`; Supply + Labs → `emailbison-b2b`. Source: `campaign-analysis` §4 canonical pattern; `message-market-fit` Gate 3.
- **Campaign verdicts are numeric, not prose.** `SCALE`/`ITERATE`/`PAUSE`/`KILL` only; thresholds from §3 rubric table. Source: §3 Campaign verdict rubric; enforced by §8.
- **Under-5-minute operator constraint.** Data suggests first, ask only when auto-suggest fails, never re-prompt. Source: issue Non-Goals; enforced by §8.
- **EB MCP is short-form.** `mcp__emailbison-b2b__*` and `mcp__emailbison-personal__*` — not the plugin-scoped form. Source: sibling allowed-tools frontmatter; CLAUDE.md gotcha about unregistered-server silent-fail.
- **Marketing-context and handbook edits go through proposal, not direct write.** Skill calls `AskUserQuestion` and hands off to `/marketing:product-marketing-context` or `/workflows:handbook-drift-check` on confirmation. Source: issue Scope — Transferable insight flow.

### Cross-skill boundaries

**Receives from:**

- **[BC-2721](https://linear.app/brite-nites/issue/BC-2721) `campaign-analysis`** (primary) — `docs/campaigns/{entity}/analysis-*.md` is the §6 Procedure 1 input and the Q1/Q2/Q3 auto-suggest source. Handoff already live at campaign-analysis §4 Cross-skill boundaries (the MANDATORY clause pointing to this skill).
- **Operator directly** (retroactive path) — §6 Procedure 2 runs when no `analysis-*.md` exists; operator supplies campaign name; metrics pull standalone from Email Bison.

**Hands off to:**

- **[BC-5829](https://linear.app/brite-nites/issue/BC-5829) `message-market-fit`** — transferable-insight `transferable_note` YAML field flows back into the MSPA matrix's Notes column on the next ITERATE run. The read-step implementation in MSPA is tracked at [BC-5953](https://linear.app/brite-nites/issue/BC-5953). Cross-link already live at MSPA §4 line 267 (pending marker).
- **[BC-1727](https://linear.app/brite-nites/issue/BC-1727) `product-marketing-context`** (conditional, on `transferable: true`) — §6 Procedure 3 hands off with the proposal payload after operator confirmation. This skill never writes `docs/marketing-context.md` directly.
- **`/workflows:handbook-drift-check`** (conditional, on handbook-contradiction signal) — §6 Procedure 4 hands off with the learnings.md entry path plus the offending handbook anchor. This skill never edits handbook content directly.
- **[BC-2722](https://linear.app/brite-nites/issue/BC-2722) `outbound-playbook`** (pending) — once shipped, outbound-playbook will invoke this skill as the post-campaign step of its conductor loop.

**Does not own:**

- Campaign analysis itself (`campaign-analysis`).
- Campaign execution (`outbound-playbook` + `/marketing:launch-campaign`, both pending or separate).
- Next-experiment design (`message-market-fit` owns the matrix and batch-design).
- Marketing-context editing (`product-marketing-context` owns the file and its freshness cadence).

**Known cross-skill asymmetry — entity-slug divergence with MSPA.** This skill writes to `docs/campaigns/{entity}/learnings.md` where `{entity}` is long-form (`brite-nites` / `brite-supply` / `brite-labs`, enforced by the Gate 3 validator). Sibling `message-market-fit` (BC-5829) writes to `docs/campaigns/{entity}/mmf-*.md` with SHORT-form entity (`nites` / `supply` / `labs`). Result: the two sibling skills write to parallel directories (`docs/campaigns/brite-nites/` vs `docs/campaigns/nites/`) that do NOT overlap on disk. Procedure 3 Step 1's cross-entity novelty `Grep` pattern must glob `docs/campaigns/*/learnings.md` (both forms) to catch cross-form matches, or explicitly restrict to long-form. The issue-body canonical form is long-form; MSPA short-form will be normalized in a follow-up per BC-5830 plan Risks §1. Until then: do NOT assume MSPA artifacts share this skill's directory.

**Engineering-side parallel.** `docs/precedents/INDEX.md` is the engineering-side decision-trace pattern; this skill is the marketing-flywheel cognate. Each debrief is a marketing-domain decision trace. The two indexes are structurally analogous: append-only, tag-keyed, cross-run searchable.

**Three-verdict translation table (per [ADR-018](../../../../docs/decisions/018-gtm-verdict-vocabularies.md)).** Three sibling skills emit verdicts at different lifecycle gates. Parent labels are renamed so each gating semantic is explicit at the source — vocabularies stay distinct, decision surfaces stay separate.

| Term | Source skill | Decision surface | Timing |
|---|---|---|---|
| Angle Verdict | creative-angles | pre-experiment | before mmf |
| Experiment Verdict | message-market-fit | post-batch | during campaign |
| Campaign Verdict | campaign-debrief | post-campaign | after campaign closes |

This skill owns the **Campaign Verdict** (Gate 3, post-campaign — `SCALE` / `ITERATE` / `PAUSE` / `KILL`). The §3 vocabulary mapping table above translates token-by-token across `campaign-analysis` / `message-market-fit` / `campaign-debrief`; the handbook framework doc `marketing/frameworks/verdicts-cross-reference.md` (BC-8733) carries the canonical cross-vocabulary reference once shipped.

---

## Discoveries — icp-refinement / offer-retirement / persona-discovery signals

The post-campaign retro is the single richest moment for surfacing handbook-canonicals drift: ICP rules that no longer fit, offers that have aged out of the lineup, and entirely new personas that the campaign exposed. This skill emits three discovery categories to `docs/campaigns/{entity}/{slug}/discoveries.json` (per Phase 2 architectural pivot) so BC-8726 (`/marketing:icp-refinement-review`) and humans can later promote them to handbook canonicals + prose via PR. See [`plugins/marketing/references/discoveries-promotion.md`](../../references/discoveries-promotion.md) for the full signal → review → handbook PR flow; the schema lives at [`plugins/marketing/data/discoveries-schema.json`](../../data/discoveries-schema.json) and is enforced by `plugins/marketing/scripts/lint_discoveries.py` (wired into `scripts/validate.sh`).

The list-building skill emits the fourth category (`title-discovery`) at contact-discovery time; the campaign-debrief skill owns the post-campaign three.

**Common confirm gate** (one `AskUserQuestion` + one `Write` per category). All three categories use the same pattern: the skill surfaces the candidate via `AskUserQuestion`; on `Yes` it `Read`s `docs/campaigns/{entity}/{slug}/discoveries.json` (file-not-found branches to a fresh `{schema_version: 1, signals: []}` shape — mirrors the §5 Workflow 4 Step 1 file-not-found pattern; do NOT use `Glob` first), appends a single signal to `signals[]`, and `Write`s the file back. Per-category payload shapes are spelled out below; `payload` is held open at the schema layer (`type: object`) so downstream consumers can evolve per category. `promotion_status` defaults to `"pending"` at emit time.

The discovery-emission gates fire from **Procedure 1 step 10 / Procedure 2 step 8** — after Workflow 4 completes (learnings.md written) and independent of Procedure 3's transferable-insight dispatch. Discoveries route to handbook-canonicals refinement; Procedure 3 routes to `docs/marketing-context.md`. The two flows can both fire on the same debrief.

### Category 1 — icp-refinement

**When to emit.** The campaign's actual responders diverge from the segment / firmographic profile the ICP-template targeted. Examples: targeted "facility directors at 50k+ enrolment universities" but the responders were almost exclusively "ops directors at 10-30k enrolment" (firmographic mismatch); the persona slug + titles match canon but Reply Rate splits sharply along a sub-segment the ICP doesn't carve (e.g., Catholic vs. secular hospitals, or coastal vs. interior resorts).

**Payload shape.**

```jsonc
{
  "category": "icp-refinement",
  "emitted_at": "<ISO-8601 datetime>",
  "emitted_by_skill": "campaign-debrief",
  "payload": {
    "vertical": "<vertical-slug from #vertical/ tag>",
    "persona": "<persona-slug from #persona/ tag>",
    "current_icp_summary": "<one-line description of the ICP template the campaign used>",
    "observed_pattern": "<one-line description of who actually responded / converted>",
    "evidence_metric": "<numeric backing — e.g. 'Reply Rate 1.9% on N=480 sub-segment vs 0.4% on N=720 non-sub-segment'>",
    "refinement_proposal": "<short prose — operator's proposed ICP carve, e.g. 'split persona into hoa-board-president-active-amenity vs hoa-board-president-passive-amenity'>"
  },
  "promotion_status": "pending"
}
```

**Gate prompt.** "This campaign's responders diverged from the ICP template (`{summary}`). Log an `icp-refinement` signal for handbook review?" Options: `Yes, log refinement proposal` / `No, skip — within ICP noise` / `No, defer — need more campaigns before refining`.

### Category 2 — offer-retirement

**When to emit.** The campaign's offer earned a `KILL` campaign verdict, AND the same offer has earned `KILL` or `PAUSE` in at least one prior debrief on `docs/campaigns/{entity}/learnings.md` (cross-run pattern, not single-run noise). The signal recommends moving the offer from `status: active` to `status: retired` in `plugins/marketing/data/canonicals/{vertical}.yaml`.

**Payload shape.**

```jsonc
{
  "category": "offer-retirement",
  "emitted_at": "<ISO-8601 datetime>",
  "emitted_by_skill": "campaign-debrief",
  "payload": {
    "vertical": "<vertical-slug>",
    "offer_slug": "<offer-slug from canonicals/{vertical}.yaml>",
    "kill_count": <integer — count of KILL verdicts across learnings.md entries for this offer>,
    "pause_count": <integer — count of PAUSE verdicts across learnings.md entries for this offer>,
    "last_kill_at": "<YYYY-MM-DD — debrief_at of the most recent KILL>",
    "recommended_replacement": "<optional offer-slug to set on canonicals replaced_by:; omit when no successor is ready>",
    "rationale": "<one-line summary — e.g. 'asymmetric-anchor angle stalled; venue-partnerships pivot replaces value capture'>"
  },
  "promotion_status": "pending"
}
```

**Gate prompt.** "Offer `{offer_slug}` has earned KILL on this debrief and {kill_count - 1} prior KILL(s) + {pause_count} PAUSE(s) on `docs/campaigns/{entity}/learnings.md`. Log an `offer-retirement` signal recommending `status: retired` for the handbook canonicals PR?" Options: `Yes, log retirement proposal` / `Yes, log with a proposed replacement (operator fills it in)` / `No, keep active — this run was an outlier`.

### Category 3 — persona-discovery

**When to emit.** The campaign exposed a buying contact whose title and decision authority do not fit any persona currently in `plugins/marketing/data/canonicals/{vertical}.yaml` for the vertical — and the pattern is not a title-discovery (which would be list-building's category, handling title aliases inside an existing persona). The signal proposes adding a NEW persona to canonicals.

**When NOT to emit.** If the new title belongs inside an existing persona's `titles[]` array (e.g., "Director of Event Operations" added to an existing `venue-operations-manager` persona), that's a `title-discovery` signal at list-building time, not a `persona-discovery` here. Only emit `persona-discovery` when the decision authority is structurally different (e.g., a CFO-tier signoff layer that wasn't represented in any existing persona for the vertical).

**Payload shape.**

```jsonc
{
  "category": "persona-discovery",
  "emitted_at": "<ISO-8601 datetime>",
  "emitted_by_skill": "campaign-debrief",
  "payload": {
    "vertical": "<vertical-slug>",
    "proposed_persona_slug": "<kebab-case slug for the new persona>",
    "proposed_display_name": "<human-readable display name>",
    "observed_titles": ["<title-1>", "<title-2>"],
    "decision_authority": "<one-line description of what this persona controls — e.g. 'capex sign-off for installations >$50k'>",
    "evidence_metric": "<numeric backing — e.g. 'Opportunity attribution: 3 of 4 Closed Won this cycle attributed to contacts in this role'>",
    "differs_from_existing": "<one-line — name the closest existing persona and explain why this one isn't a sub-role of it>"
  },
  "promotion_status": "pending"
}
```

**Gate prompt.** "This debrief surfaced a buying role that doesn't map to any persona in `canonicals/{vertical}.yaml` (`{proposed_display_name}` — controls `{decision_authority}`). Log a `persona-discovery` signal for handbook review?" Options: `Yes, log new persona proposal` / `No — this is a title variant of an existing persona (route to list-building's title-discovery instead)` / `No, skip — insufficient data`.

### Where these signals land

All three categories collect in the per-campaign-run `discoveries.json` under `docs/campaigns/{entity}/{slug}/`. Downstream, BC-8726 (`/marketing:icp-refinement-review`) reads signals across runs by category, groups them per `{vertical}/{persona}`, surfaces them as PR candidates, and produces the handbook-canonicals PR. Until BC-8726 ships, signals accumulate in `pending` status; the discoveries-promotion reference doc carries the full lifecycle.

---

## MCP Tool Reference

"When you need to X, call `tool_name`." Grouped by workflow, not by server. All calls are reads except the final learnings.md `Write` — no MCP confirmation gates apply to this skill.

### Workflow 1 — Read upstream analysis artifact (post-analysis path)

1. `Read` the `analysis-*.md` file resolved at Gate 2 / Gate 4. No availability probe — file read only.
2. Parse the analysis artifact (the `analysis-*.md` file, which has 6 sections per `campaign-analysis` §6 Report Spec): artifact §2 Segment Performance Ranking for the focal campaign's verdict token (→ Q2 auto-suggest); artifact §5 Attribution Analysis for the focal row (→ Q1 auto-suggest) and top-2 rows (→ Q3 auto-suggest Worked side); artifact §6 Next Iteration Recommendations (→ Q5 auto-suggest).
3. Extract numeric metrics from artifact §1 Quick Health Check (aggregate `Reply Rate`, `Interested Rate`, `Bounce Rate`, plus the run-window header for `sent` count and `days` elapsed) and artifact §2 Segment Performance Ranking (per-campaign rates on the focal row when segment-level granularity is needed). These feed this skill's §3 Campaign verdict rubric. *Note: do NOT pull metrics from artifact §3 Infrastructure Analysis — that section holds cohort comparisons (Google vs Microsoft senders), not headline rates.*

### Workflow 2 — Standalone EB metrics fetch (retroactive path)

See [`plugins/marketing/tools/integrations/email-bison.md` §Common Workflows](../../tools/integrations/email-bison.md#common-workflows) for the canonical recipe.

1. **Availability probe** — call `get_active_workspace_info` on the workspace dispatched from Gate 3 (Nites → `mcp__emailbison-personal__*`; Supply / Labs → `mcp__emailbison-b2b__*`). On failure, halt and point the operator to `/marketing:setup-email-bison` — do NOT fall through to a cross-workspace probe.
2. **Resolve campaign** — call `list_campaigns`. `list_campaigns` has no server-side date filter, so apply a client-side filter on `created_at` or `updated_at` if the operator's campaign name is ambiguous across time (e.g. "spring-promo" ran in 2025 and 2026). Match `{campaign-name}` against the result list; if multiple matches, re-prompt with dates.
3. **Fetch stats** — call `get_campaign_stats` on the resolved campaign ID for `sent`, `bounce_rate`, and raw reply count.
4. **Fetch reply sentiment** — call `get_replies_analytics` (NOT `list_replies`) on the same campaign ID for `interested_rate` / positive-reply count. `get_replies_analytics` is the canonical reply-sentiment tool; `list_replies` returns reply bodies, not sentiment aggregates.
5. Derive `days` elapsed from campaign `created_at` to `today`. Apply the §3 Campaign verdict rubric against the entity-scoped threshold column.

### Workflow 3 — Salesforce Opportunity attribution (optional)

Runs when the operator wants to correlate the campaign with downstream pipeline. Soft gate — skips cleanly on SF unavailability.

**Parallelization note.** When both the retroactive path (Workflow 2) and SF attribution (Workflow 3) are in scope on the same run, fire the EB `get_active_workspace_info` probe AND the SF `SELECT Id FROM User LIMIT 1` probe as parallel tool calls in a single assistant turn — they target different MCP servers and do not depend on each other's results. Sequential probes across two servers wastes round-trip latency on an already-tight 5-minute budget.

1. **Availability probe** — call `run_soql_query` with `SELECT Id FROM User LIMIT 1`. This is the verified liveness check per BC-5534 findings §Q1 (`get_username` is NOT a valid probe — it reads the local SFDX auth store without contacting Salesforce). On failure, skip attribution and note the skip in the entry — do NOT fabricate Opportunity data.
2. **FieldDefinition preflight** — before running the attribution query, confirm the `Campaign_Source__c` custom field exists on Opportunity via `SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Opportunity' AND QualifiedApiName = 'Campaign_Source__c'`. This preflight matches the BC-5797 factual-anchor recipe — fabrication of field names is a common failure mode. If the field is missing, skip attribution.
3. **Attribution query** — (a) re-verify `{campaign-name}` still matches `^[a-z0-9-]{1,80}$` immediately before the SOQL call; on fail, halt attribution and note the skip in the entry (sink-side defense-in-depth — do NOT trust that the upstream §2 gate alone will hold across a long procedure). (b) Only then interpolate into `SELECT Id, Name, StageName, Amount FROM Opportunity WHERE Campaign_Source__c = '{campaign-name}' LIMIT 50`. Single quotes, semicolons, or SOQL keywords in `{campaign-name}` must not reach SOQL.
4. Append the opportunity count and stage distribution to Q3's Worked side if any are `Closed Won` or `Negotiation` — this is attribution evidence, not hypothesis evidence.

### Workflow 4 — Append to learnings.md

The final mutating step of every debrief run. Both create-on-missing and append-to-existing flow through this workflow.

1. **Attempt Read** — `Read` `docs/campaigns/{entity}/learnings.md`. On file-not-found, branch to create-from-template: Write the §4 template plus the first entry, done. On Read success, proceed to step 2. (No separate `Glob` probe — `Read`'s not-found branch is cheaper than the Glob+Read pair.)
2. **Regenerate summary sections** — rewrite `## Summary stats` counters; re-extract `## What works` bullets from entries where `verdict: SCALE` or `verdict: ITERATE` AND `transferable: true`; re-extract `## What doesn't` bullets from entries where `verdict: KILL`.
3. **Append new entry** — insert the new entry at the TOP of the `## Campaign log` section (reverse-chronological), with the existing entries below.
4. **Write full file** — single `Write` call overwrites the file with the regenerated summary sections plus the full Campaign log. The regenerate-in-place carve-out (§3 Append-only invariant) makes this a single-Write operation — no separate mutation call per section.
5. **Sync Salesforce Campaign status to `Completed` (BC-8752, soft-fail).** After the learnings.md append succeeds, mirror the closed state into SF via the σ3 trigger per the BC-8752 design (Linear sub-issue 8 close → SF `Completed`). Fires on every successful append — repeated debriefs against the same campaign land on the underlying `/revops:update-sf-campaign-status` Phase 5 idempotency noop, so re-runs are cheap.
   1. **Resolve the GTM slug from the manifest.** `/marketing:plan-campaign` writes manifest at `docs/campaigns/<short-entity>/<slug>/manifest.json` using the SHORT-form entity slug it accepts (`nites` / `supply` / `labs` / `cross-entity`), while this skill's Gate-3 `{entity}` is the LONG-form slug (`brite-nites` / `brite-supply` / `brite-labs`). This is the same long-vs-short asymmetry documented at § Known cross-skill asymmetry below. Normalize at read time: derive `<short-entity>` by stripping the `brite-` prefix from `{entity}` (`brite-nites` → `nites`, `brite-supply` → `supply`, `brite-labs` → `labs`; this skill's Gate-3 set does not include cross-entity, so the normalization is total). Then try `Read` `docs/campaigns/<short-entity>/{campaign-name}/manifest.json`. Both path segments are safe: `<short-entity>` is the mechanically-stripped form of the Gate-3-validated `{entity}` enum (containment proof identical to the original); `{campaign-name}` is regex-gated by the Before-Starting Input-validation block (matches `^[a-z0-9-]{1,80}$`, blocking `..` / `/` / `\` traversal). If the file does not exist OR JSON parse fails OR `.slug` is absent, log to stderr `[BC-8752] No GTM manifest at "docs/campaigns/<short-entity>/{campaign-name}/manifest.json"; skipping σ3 SF sync. If /marketing:plan-campaign was used to scaffold, {campaign-name} must equal the strict-kebab slug it produced. Otherwise this is a retroactive debrief — expected.` and exit Workflow 4 normally. The learnings.md append already landed — that's the marketing-flywheel source of truth; SF mirroring is downstream cosmetic state.
   2. **Re-validate the manifest slug** (defense-in-depth against manifest tampering). After extracting `<slug>` from `manifest.slug`, check it against the canonical regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$` (same regex as `/revops:update-sf-campaign-status` Phase 1 and ADR-012 canonicals lint). Apply the regex without the multiline (`m`) flag — `^` and `$` must match input boundaries, not line boundaries; a manifest slug containing an embedded newline must FAIL the check. On regex mismatch, log `[BC-8752] Manifest slug failed canonical regex — refusing σ3 SF sync. Manifest at "docs/campaigns/<short-entity>/{campaign-name}/manifest.json" may be tampered or out-of-date.` (the slug VALUE is intentionally omitted from this log to avoid echoing potentially poisoned content into the agent context) and exit Workflow 4 normally. Without this guard a whitespace-bearing manifest slug could inject an extra `--linear-status` flag into the args string constructed in step 3.
   3. **Invoke the sibling slash command** (BC-8717 / BC-8723 respec pattern):

      ```
      Skill(
        skill: "revops:update-sf-campaign-status",
        args: "--slug=<manifest.slug> --linear-status=completed"
      )
      ```

   4. **Parse the single-line JSON response.** Branch in this exact order — the first matching case wins (mirrors `/marketing:launch-campaign` Phase 11 step 7 fan-out for consistency):
      - **`error: <kind>`** (any `error` key) → log `[BC-8752] σ3 SF sync soft-fail: <kind>. Detail: <stringified error>. Debrief succeeded; SF status is stale until reconciliation.`
      - **`warning: campaign_not_found`** (warning key, no `campaign_id`) → log `[BC-8752] SF Campaign for slug "<slug>" not found — σ3 auto-create at plan-campaign Step 8b may have failed. Reconcile manually via /revops:create-sf-campaign + /marketing:sync-campaign-status --slug=<slug> --status=completed.`
      - **Success with degradation** (`campaign_id` AND `warning` key both present — typically `warning: "instance_url_unknown"` or `warning: "updated_at_unavailable"` per the underlying command's Phase 7 / Phase 6 fall-through) → log `[BC-8752] SF Campaign synced with degradation: <slug> → Completed (campaign_id=<id>, warning=<kind>).`
      - **Success or noop** (`campaign_id` present, no `warning` key) → log `[BC-8752] SF Campaign synced: <slug> → Completed (campaign_id=<id>).`
   5. **Soft-fail invariant.** No SF response halts the debrief. The learnings.md entry IS the marketing flywheel's source of truth; SF mirroring is downstream effect. This matches the philosophy in `/marketing:launch-campaign` Phase 11 step 7 and `/marketing:plan-campaign` Step 8b.

---

## Operational Runbook

### Procedure 1 — Post-analysis debrief (happy path)

**Preconditions:**
- §2 Gate 2 matched ≥1 `analysis-*.md` for the selected `{entity}`.
- §2 Gate 3 confirmed `{entity}`; §2 Gate 4 confirmed `{campaign-name}`.
- `docs/marketing-context.md` read or reduced-context warning emitted (Gate 1).

**Steps:**
1. Run §5 Workflow 1 to read the analysis artifact and extract auto-suggest material for Q1/Q2/Q3/Q5.
2. Present Q1 via `AskUserQuestion` with the auto-suggested hypothesis text as the first option and "Edit" as a second option. Operator confirms or edits.
3. Present Q2 via `AskUserQuestion` with the auto-suggested result token (`CONFIRMED`/`PARTIAL`/`REJECTED`) plus one-line summary pulled from §2 ranked row's metrics. Confirms or edits.
4. Present Q3 via `AskUserQuestion` with the auto-suggested Worked bullets from §5 top-2 rows; operator authors the Didn't side in free text.
5. Present Q4 via `AskUserQuestion` with free-text input only (no auto-suggest — surprise is operator-authored).
6. Present Q5 via `AskUserQuestion` with the auto-suggested transferable insight from §6 Next Iteration Recommendations plus a Yes/No for the `transferable:` flag.
7. Assemble tags: `#entity/{entity}` from Gate 3; `#vertical/` proposed from the focal campaign's segment dimension (operator confirms); `#persona/` proposed from the gtm-strategy persona rollup (operator confirms); `#angle/` proposed from the creative-angles slug if seeded, else operator slugs.
8. Compute campaign verdict from §3 Campaign verdict rubric using the Workflow 1 metrics. Echo the computed campaign verdict to the operator for sanity-check (optional `AskUserQuestion` override only if the computed campaign verdict contradicts operator's gut-read).
9. Run §5 Workflow 4 to append the entry.
10. Run § Discoveries gates for each of the three categories (`icp-refinement` / `offer-retirement` / `persona-discovery`) — fire each gate only when its per-category When-to-emit conditions hold. Each emit appends one signal to `docs/campaigns/{entity}/{slug}/discoveries.json`; on operator decline, no write. Independent of step 11 below.
11. On `transferable: true`, dispatch §6 Procedure 3.

**Expected output:** One new entry appended to `docs/campaigns/{entity}/learnings.md` with the `## Campaign log` section starting with this entry and the prior entries below. Summary stats / What works / What doesn't sections regenerated. Debrief completed in under 5 minutes of operator time. Zero or more signals appended to `docs/campaigns/{entity}/{slug}/discoveries.json` per § Discoveries gates (only categories whose When-to-emit conditions hold and that the operator confirmed).

**Error handling:**
- `analysis-*.md` parse failure (unexpected section headers or missing §2/§5/§6) → fall through to Procedure 2 (retroactive path) and note the artifact-corruption in the entry Q4 bullets.
- `AskUserQuestion` skipped (operator presses through) → fill with auto-suggested value; never write an entry with an empty question field.

**Handoff:** §6 Procedure 3 (transferable-insight propagation) on `transferable: true`. MSPA Notes-column feedback on next ITERATE (via BC-5953 once implemented).

### Procedure 2 — Retroactive debrief (no analysis artifact)

**Preconditions:**
- §2 Gate 2 matched zero `analysis-*.md` for `{entity}`.
- Operator supplied `{campaign-name}` at Gate 4.
- EB MCP credentials valid for the entity-routed workspace.

**Steps:**
1. Run §5 Workflow 2 to pull metrics from Email Bison. On availability failure, halt with operator message and route to `/marketing:setup-email-bison`.
2. Apply §3 Campaign verdict rubric against pulled metrics to pre-compute campaign verdict.
3. Present Q1 via `AskUserQuestion` — operator authors the hypothesis from memory (no auto-suggest for retroactive path's Q1).
4. Present Q2 via `AskUserQuestion` with auto-suggested result token derived from the pre-computed campaign verdict (`SCALE`/`ITERATE` → `CONFIRMED`; `PAUSE` → `PARTIAL`; `KILL` → `REJECTED`). Operator confirms or overrides.
5. Present Q3 / Q4 / Q5 via `AskUserQuestion` — all operator-authored (retroactive path has no §5 Attribution rows to seed).
6. Assemble tags as in Procedure 1 step 7. Operator confirms all four families.
7. Run §5 Workflow 4 to append the entry.
8. Run § Discoveries gates for each of the three categories (`icp-refinement` / `offer-retirement` / `persona-discovery`) — fire each gate only when its per-category When-to-emit conditions hold. Same emit-path as Procedure 1 step 10. Independent of step 9 below.
9. On `transferable: true`, dispatch §6 Procedure 3.

**Expected output:** Same as Procedure 1 — one appended entry plus zero or more discoveries.json signals per § Discoveries gates. Retroactive paths typically take longer (5–8 minutes) because Q3–Q5 lack auto-suggest; operator-authored in full.

**Error handling:**
- EB availability probe failure → halt with setup pointer, do not fall through to a fabricated-metrics path.
- `list_campaigns` no-match for `{campaign-name}` → re-prompt with Gate 4 and suggest the operator paste a dated name (e.g. `spring-promo-2026-04`) to disambiguate.

**Handoff:** Same as Procedure 1.

### Procedure 3 — Transferable-insight cross-entity propagation

**Preconditions:**
- Procedure 1 or 2 completed.
- New entry's `transferable:` flag is `true`.

**Ordering:** Steps 1 and 2 run BEFORE Procedure 1 Step 9 / Procedure 2 Step 7 (the final `Write`), so the `transferable:` flag and Q5 body are finalized pre-Write — this preserves the §3 Append-only invariant. Steps 3–5 may run before or after the Write.

**Steps:**
1. `Grep` for cross-entity matches — run a single `Grep` with pattern `#angle/{a}` and `glob: "docs/campaigns/*/learnings.md"` (where `{a}` is the just-assembled angle-slug). In post-processing, filter out any match line whose path contains `/{entity}/` to exclude the current entity. A single `Grep` call replaces an N+1 `Glob`+`Read` loop over growing `learnings.md` files.
2. If Grep returns ≥1 match whose entry also carries the same `#vertical/` + `#persona/` combination, the insight is not novel cross-entity — set `transferable: false` in the entry YAML and rewrite Q5 body to "pattern already logged in `docs/campaigns/{other-entity}/learnings.md`" BEFORE the Write in Procedure 1 Step 9 / Procedure 2 Step 7. This is a pre-Write revision of the entry content, not a post-Write mutation.
3. On novel insight (zero matches, or matches lacking the full tag triple), `AskUserQuestion`: "This insight may apply cross-entity (e.g. from `{entity}` to `{other-entity}`). Propose an update to `docs/marketing-context.md`?" with options `Yes, propose update` / `No, skip propagation` / `No, keep entity-specific`.
4. On `Yes`, hand off to `/marketing:product-marketing-context` with the proposal payload: `{ entity_pair: [entity, other-entity], transferable_note: "...", source_entry: "docs/campaigns/{entity}/learnings.md#entry-{N}" }`.
5. On `No`, skip propagation and note the skip in the entry's Q5 free-text ("operator declined cross-entity propagation").

**Expected output:** Either a `product-marketing-context` invocation or a skip-note in the entry. No write to `docs/marketing-context.md` from this skill.

**Error handling:**
- `/marketing:product-marketing-context` unavailable → append the proposal payload to `docs/campaigns/proposed-context-updates.md` (append-only) and note the deferral in the entry Q5.

**Handoff:** `/marketing:product-marketing-context` on Yes; self-contained on No.

### Procedure 4 — Handbook-drift flag

**Preconditions:**
- Procedure 1 or 2 completed.
- Transferable insight contradicts or supersedes documented handbook content (operator judgment call).

**Steps:**
1. `AskUserQuestion` confirming the contradiction: "This insight appears to contradict the handbook at `{anchor}`. Raise a handbook-drift issue?" Include the handbook anchor URL in the question body for operator review.
2. On `Yes`, hand off to `/workflows:handbook-drift-check` with the payload `{ entry_path: "docs/campaigns/{entity}/learnings.md#entry-{N}", handbook_anchor: "{anchor}", contradiction_summary: "..." }`.
3. On `No`, note the operator's justification in the entry Q5 free-text ("operator declined handbook-drift issue: {reason}") — parallel to Procedure 3 Step 5's skip-note routing. Q4 is reserved for genuine surprise findings, not post-hoc justifications.

**Expected output:** Either a drift-check invocation or a notation in the entry. No direct handbook edits.

**Error handling:**
- `/workflows:handbook-drift-check` unavailable → create a Linear issue via `mcp__linear__save_issue` with title "Handbook drift — {anchor}" and body containing the entry path and contradiction summary; link the Linear URL in the entry Q5.

**Handoff:** `/workflows:handbook-drift-check` on Yes; Linear issue on fallback.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | All 5 questions asked, answered, and recorded in the entry body verbatim (Q1 in fixed-format sentence, Q2 as token+summary, Q3 as worked/didn't pair, Q4 as 1–3 surprise bullets, Q5 as sentence-or-"entity-specific"). Campaign verdict computed from the §3 Campaign verdict rubric with exact numeric metrics cited in the entry frontmatter (`metrics.reply_rate`, `metrics.interested_rate`, `metrics.bounce_rate`, `metrics.sent`, `metrics.days` populated). All four tag families present, all lowercase-hyphenated. Entry appended to `docs/campaigns/{entity}/learnings.md` (never overwritten); `## Summary stats`, `## What works`, `## What doesn't` sections regenerated in place; `## Campaign log` strict-append with new entry at top. `transferable:` flag set correctly (true when cross-entity pattern evident; false otherwise). Debrief conversation under 5 minutes of operator time. Q1/Q2/Q3 auto-suggestions drawn verbatim from the `analysis-*.md` artifact when Gate 2 matched. Retroactive path EB availability probe hit the correct entity-routed workspace (never cross-workspace). On `transferable: true`, `product-marketing-context` or `handbook-drift-check` proposal surfaced via `AskUserQuestion` — never auto-written. |
| 7–9 | One gap from the 10-tier list. Examples: 4 of 5 questions recorded (Q4 skipped); campaign verdict numerically correct but the threshold rule not cited in the entry frontmatter; 3 of 4 tag families present (missing `#angle/`); conversation ran 5–7 minutes (still acceptable, but exceeded target). `transferable:` flag set but the cross-entity novelty check (§6 Procedure 3 Step 1–2) was skipped. |
| 4–6 | Functional but missing structural elements. Campaign verdict assigned without citing the numeric threshold check (operator read the table but no metrics in `metrics:` frontmatter). Tags written in TitleCase or with spaces ("Commercial Real Estate" instead of `commercial-real-estate`) — entry would fail the §8 lowercase-hyphenated gate on re-check. Entry written without the `source_analysis` frontmatter field on post-analysis path. `## Summary stats` section drifted (last debrief date not updated). `list_campaigns` client-side date filter skipped on an ambiguous retroactive match (operator picked wrong year's campaign). |
| 1–3 | Hard failure — any ONE drops the run. Subjective campaign verdict ("pretty good" instead of `SCALE`/`ITERATE`/`PAUSE`/`KILL`). Learnings.md entry overwritten rather than appended (a prior entry's body mutated). Auto-wrote to `docs/marketing-context.md` or handbook content without `AskUserQuestion` confirmation. Skipped a §2 gate (e.g. no entity confirmation before the `Write`). Invented a tag family outside the 4-family scheme (e.g. `#channel/`, `#cycle/`). Under-5-minute constraint violated AND operator did not approve a scope extension. Retroactive-path EB call hit the wrong workspace (Supply campaign probed on `emailbison-personal`). Fabricated `Campaign_Source__c` Opportunity data without running the §5 Workflow 3 FieldDefinition preflight. |

---

## Anti-Slop Guardrails

Base guardrails (every marketing skill ships these four; do not remove):

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md` when it exists.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).

Skill-specific hard failures (each drops to §7 Rubric 1–3 band):

- **Do not exceed 5 minutes of operator time on a single debrief.** Under-5-minute constraint is load-bearing. Suggest answers from `analysis-*.md` §5 / §2 / §6 first; ask one question at a time only when auto-suggest fails; never re-prompt a field the operator already answered. The retroactive path has a 5–8-minute allowance because Q3/Q4/Q5 lack auto-suggest; above 8 minutes is the failure boundary even on retroactive.
- **Do not overwrite `learnings.md` entries.** Append-only, strict. Re-running a debrief on the same `{campaign-name}` with a new `debrief_at` date produces a new entry — the prior entry's body stays untouched. The three summary sections (`## Summary stats`, `## What works`, `## What doesn't`) regenerate in place; the `## Campaign log` section is strict-append. Mutating a past Campaign-log entry's body is the worst-case failure mode for this skill because it rewrites organizational memory silently.
- **Do not skip data-first suggestion.** When `analysis-*.md` exists at Gate 2, Q1 must auto-suggest from §5 Attribution, Q2 from §2 Segment Ranking verdict, Q3 Worked side from §5 top-2 rows, Q5 from §6 Next Iteration Recommendations. Hand-cranking questions without suggestion when the artifact exists wastes operator time and violates the under-5-minute constraint. Retroactive path is exempt because no artifact exists.
- **Do not use non-lowercase-hyphenated tags.** `#Entity/BriteNites`, `#vertical/Commercial Real Estate`, `#angle/CapEx_Timing`, `#persona/facilitiesDirector` are all refused. Tag values are lowercase-hyphenated slugs matching `^[a-z0-9-]+$`. The four tag families are the ONLY permitted keys: `#entity/`, `#vertical/`, `#persona/`, `#angle/`. Inventing a fifth family (e.g. `#channel/`, `#cycle/`, `#cohort/`) is refused.
- **Do not use subjective campaign verdicts.** The four campaign verdict tokens (`SCALE`, `ITERATE`, `PAUSE`, `KILL`) are the only permitted `verdict:` frontmatter values (the frontmatter field name stays `verdict:` per ADR-018 Consequences — single-vocab artifact). Prose substitutes ("pretty good", "meh", "worth another shot", "solid", "looking promising") are refused. Every campaign verdict must trace to the §3 Campaign verdict rubric — if the metrics don't clearly resolve to one cell, the default is `PAUSE` (sub-floor / ambiguous signal) until more data arrives, never a prose token.
- **Do not `Write` to any path other than the two allowlisted destinations.** This skill's `Write` allowlist is exactly two paths: `docs/campaigns/{entity}/learnings.md` (primary output, §6 Procedure 1/2) and `docs/campaigns/proposed-context-updates.md` (Procedure 3 error-fallback only). Any other `Write` destination — especially `docs/marketing-context.md`, handbook content, Linear issue descriptions via any path other than `mcp__linear__save_issue`, or another skill's artifacts — is a §7 Rubric 1–3 hard failure. The marketing-context and handbook-drift procedures route through `AskUserQuestion` confirmation + skill/workflow handoff, never direct Write.

---

## Behavioral Tests

Nine scenarios across Tier 1 (free assertions, no tool calls required) and Tier 2 (tool-assisted, requires a file read or MCP call). Each scenario ID matches one in `evals/evals.json` 1:1.

### Tier 1 — Free assertions

- **`post-analysis-happy-path`** — Given a Nites analysis artifact at `docs/campaigns/brite-nites/analysis-spring-promo-2026-04-15.md` reporting Reply Rate 1.4%, Interested Rate 28%, Bounce Rate 2%, sent=1200, days=14, the skill proposes campaign verdict `SCALE` against the b2c column (sub-1% threshold exceeded) and writes an entry to `docs/campaigns/brite-nites/learnings.md`. Output must contain: all 5 Q-sections populated, all 4 tag families lowercase-hyphenated, `metrics:` frontmatter with the five numeric fields from Workflow 1, `source_analysis:` pointing to the consumed artifact, `verdict: SCALE`, and a handoff prompt to marketing-context-proposal when `transferable: true`.
- **`retroactive-manual-stats`** — Given zero `analysis-*.md` matches for `brite-supply`, operator-supplied `{campaign-name}` of `summer-installer-2026-03`, EB availability probe on `emailbison-b2b` succeeds, `get_campaign_stats` returns sent=800 / bounce_rate=0.04, `get_replies_analytics` returns interested_rate=0.12 / reply_rate=0.003, days elapsed=10. Output must assign campaign verdict `KILL` (Reply Rate <0.5% AND sent ≥500 AND days ≥7 against b2b column), with `metrics:` frontmatter populated from the standalone pulls, `source_analysis:` omitted (retroactive path has no artifact), and no auto-suggest source cited in Q1/Q3/Q4/Q5 bodies.
- **`subjective-verdict-refused`** — Given an operator-drafted entry body containing `verdict: "pretty good"` or `verdict: "meh"` or any other non-token value in the frontmatter, the skill refuses to `Write` and responds with the four permitted campaign verdict tokens plus the §3 Campaign verdict rubric. Output must show: §8 guardrail invoked, entry not appended to `learnings.md`, retry prompt offering a numeric-resolved token.
- **`append-only-refuses-overwrite`** — Given an existing entry for `{campaign-name}: spring-promo` already in `docs/campaigns/brite-nites/learnings.md` with `debrief_at: 2026-04-15`, and a fresh debrief invocation on the same campaign with `debrief_at: 2026-04-22`, the skill appends a new entry with the 2026-04-22 date and leaves the prior 2026-04-15 entry body unchanged. Output must show: two entries visible in `## Campaign log` after the second debrief, both with identical `campaign:` frontmatter but different `debrief_at:` dates, neither body mutated.
- **`under-5-minute-autosuggest`** — Given `analysis-*.md` present and well-formed, the skill must NOT call `AskUserQuestion` for Q1 hypothesis free-text when the §5 Attribution row provides it — instead, it calls `AskUserQuestion` with the auto-suggested text as the first option and "Edit" as the second option. Operator can confirm with one tap per question. Output trace must show: 5 `AskUserQuestion` calls total (one per question), each with an auto-suggested option as the first choice for Q1/Q2/Q3/Q5, and a free-text option as the first choice for Q4.
- **`tag-format-hyphenated`** — Given operator typing "Commercial Real Estate" into a `#vertical/` tag prompt, the skill normalizes before append: the written tag is `#vertical/commercial-real-estate`. Similarly, "Facilities Director" becomes `#persona/facilities-director`, "CapEx_Timing" becomes `#angle/capex-timing` (mechanical normalization only: lowercase + whitespace-and-underscore to hyphen). The skill does NOT expand abbreviations semantically — if the operator wants `capital-expenditure-timing`, they type `Capital Expenditure Timing`. Output must show: no tag in the entry frontmatter contains spaces, underscores, capitals, or punctuation other than `/` and `-`.

### Tier 2 — Tool-assisted

- **`transferable-cross-entity-flag`** — Given a new debrief entry on `brite-supply` with `transferable: true` and `#angle/capital-expenditure-timing`, when §6 Procedure 3 Step 1 globs `docs/campaigns/brite-labs/learnings.md` and that file either doesn't exist or contains no matching `#angle/capital-expenditure-timing` entry, the skill surfaces an `AskUserQuestion` proposing a marketing-context update with the three-option response set (Yes propose / No skip propagation / No keep entity-specific). On "Yes", the skill must emit a handoff payload naming `product-marketing-context` as the target, with `entity_pair: [brite-supply, brite-labs]`, `transferable_note`, and `source_entry` fields populated. On "No skip", the entry's Q5 body must include the explicit skip note "operator declined cross-entity propagation".
- **`missing-context-degraded-mode`** — Given `docs/marketing-context.md` absent (verified by `Glob` at Gate 1), the skill warns with the verbatim Gate 1 string ("Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.") and continues with operator-only context. `learnings.md` is still written correctly with all required fields. Output must show: warning emitted once at Gate 1; no `Read` attempt on `docs/marketing-context.md`; entry frontmatter populated without any `marketing_context_version:` or equivalent reference.
- **`eb-short-form-namespace`** — Given the retroactive path (Procedure 2) for a Nites campaign, every EB tool call in the resulting trace uses the SHORT form `mcp__emailbison-personal__*` (short form for Nites per workspace routing). Zero calls to `mcp__plugin_marketing_emailbison-*__*`. If the skill mistakenly uses the plugin-scoped form, the availability probe silent-fails per the CLAUDE.md gotcha and the skill should halt with the setup pointer — NOT continue with a fabricated-metrics path.
