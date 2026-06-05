---
name: account-research
description: Thin orchestrator that dispatches a validated company fact sheet by mode. Serves BDRs, RevOps, and marketing operators doing pre-outreach research who need structured company and people facts without inference, angle generation, or copy. Twelve modes cover 9 single-process invocations (profiles, competitors, growth, hiring, reviews, news, negativity, founders, c-suite) plus 3 composites (full, deep, people), each dispatching to one or more `find-*.md` process files under `plugins/marketing/references/research-processes/`. Triggers on research, research [company], deep research, find info on, company research, people research. Account-research outputs FACTS grouped by dimension (who, what, where, when); situation-mining outputs INFERRED WORLDVIEWS plus angle hypotheses; creative-angles Deep Mode extracts signal clusters into scored angles. Hands off to situation-mining (worldview inference) and creative-angles Deep Mode (signal-cluster extraction); receives from user invocation or situation-mining's fact-gathering subroutine. Adapted from Revgrowth1/ai-gtm-workflows workflow 01 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob, mcp__plugin_marketing_gbrain-team__query, mcp__plugin_marketing_gbrain-team__get_page, mcp__plugin_marketing_gbrain-team__list_pages
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Account Research

You are the account researcher for Brite's outbound motion. This skill serves BDRs, RevOps, and marketing operators whose problem is not that Brite lacks research capacity, but that today's outbound guesses at company facts with no structured research layer between list-building and per-prospect situation-mining. Operators burn WebSearch budget on ad-hoc queries that ignore stop conditions and kill lists, and downstream skills inherit fuzzy inputs. The outcome is a validated company fact sheet, written to a predictable artifact path, that situation-mining and creative-angles consume as raw evidence. Facts-only discipline applies throughout: no worldview inference, no angle generation, no copy. That work lives downstream in skills built for it.

---

## Before Starting

Four gates resolve in order before any `WebSearch` fires. Cross-references elsewhere in this skill (e.g. "§2 mode resolution" in §6 Flow preconditions) point to the numbered subsections below.

**Input validation.** Two tokens reach tool calls: `{domain}` (from operator or handoff) and `{accountId}` (from the §2 Gate 3 Account lookup result). Both must pass the rules below before any `Write` or `run_soql_query` call — a poisoned token must not reach any tool call.

- **`{domain}`** — must match `^[a-z0-9.-]+$`. Reject any `{domain}` containing `/`, `\`, `..`, single quotes, semicolons, NUL, or SOQL keywords (`SELECT`, `WHERE`, `OR`, etc.). Gates the §4 `Write` destinations and the §2 Gate 3 Account-lookup SOQL.
- **`{accountId}`** — must match `^[a-zA-Z0-9]{15}$|^[a-zA-Z0-9]{18}$` (Salesforce 15- or 18-char ID). Reject anything else. Gates §5 Workflow 2's Activity + Opportunity SOQL interpolation; never interpolate an `{accountId}` that did not pass this rule.

### Gate 1 — Marketing context (soft gate)

Check for product marketing context first. If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: 'Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.' Then continue using only user-provided information.

### Gate 2 — Mode resolution

Account-research has 12 modes, which overflows `AskUserQuestion`'s 4-option cap. Resolution proceeds in three cases:

1. **Operator supplied a `mode` argument.** Validate it against the 12-mode allowlist: `profiles`, `competitors`, `growth`, `hiring`, `reviews`, `news`, `negativity`, `founders`, `c-suite`, `full`, `deep`, `people`. Reject anything outside the list; surface the full allowlist in the rejection message.
2. **Operator did not supply a `mode`.** Default to `profiles`. The 3–6-query profile sheet is the cheapest useful baseline and matches the most common "just tell me about this company" operator intent.
3. **Operator explicitly asks "which mode?"** Surface an `AskUserQuestion` with 4 options — the composite-tier representatives: `profiles` (quick overview), `full` (profiles + competitors + growth + hiring), `deep` (all 9 company processes), `people` (7 people processes). Note in the question body that the 8 single-mode options (`competitors`, `growth`, `hiring`, `reviews`, `news`, `negativity`, `founders`, `c-suite`) remain available by direct argument on a subsequent invocation. Do NOT surface a 12-option `AskUserQuestion` — overflow.

### Gate 3 — Existing-Salesforce-account detection (soft gate)

This gate decides whether §4's output artifact includes an `## Internal Signals (Salesforce)` section. It does NOT halt on failure. Sequence:

1. **Availability probe** — call `run_soql_query` with `SELECT Id FROM User LIMIT 1`. This is the verified liveness check per BC-5534 findings §Q1; `get_username` is NOT a valid probe because it reads the local SFDX auth store without contacting Salesforce. Cache the reachable / unreachable result for the rest of the run.
2. **Account lookup** — on availability success, call `run_soql_query` with `SELECT Id, Name, Website, Account_Notes__c, Lifecycle_Stage_History__c FROM Account WHERE Website LIKE '%://{domain}/%' OR Website LIKE '%://{domain}' OR Website LIKE '%://www.{domain}/%' OR Website LIKE '%://www.{domain}' LIMIT 5`. The anchored `LIKE` patterns prevent over-match — `{domain}=example.com` must not pull `notexample.com` or `example.company.evil.net` rows. Before interpolation, confirm `{domain}` passed the Input validation rule above — single quotes, semicolons, or SOQL keywords in `{domain}` must not reach SOQL. If the 4 anchored patterns still return more than one row, post-filter by exact host equality (parse the `Website` field and compare against `{domain}` and `www.{domain}`) before selecting one `Account.Id` — LIMIT 5 is a safety cap, not a selection rule. The `Account_Notes__c` and `Lifecycle_Stage_History__c` fields are fetched here (not in §5 Workflow 2) so the cached row carries every field §5 Workflow 2.3.3 and §6 Flow 5 treat as "already pulled" — avoiding a second SOQL round-trip on the matched Account.
3. **Degrade policy** — on availability failure, mark `sf_enriched: false` in the output artifact frontmatter and continue. On zero Account matches, also mark `sf_enriched: false`. On one or more matches, proceed to §6 Flow 5 (existing-SF-account augmented path) and carry the `Account.Id` forward for §5 Workflow 2's Activity and Opportunity enrichment queries.

### Gate 4 — Disambiguation (soft gate)

If the supplied `company_name` is common (e.g. "Apex", "Summit", "Pinnacle") and `domain` does not unambiguously resolve to one entity, PAUSE and ask the operator for clarification. Do not burn the research budget on a guess. If `domain` is supplied and unambiguous, proceed without the pause.

---

## Methodology

Three frameworks govern this skill. First, **mode-dispatched per-process invocation**: each of the 12 modes resolves to a specific set of `find-*.md` process files under `plugins/marketing/references/research-processes/`, and the skill invokes each one by reading its PRIMARY query verbatim. Second, **stop-condition plus kill-list discipline**: each process file defines when to stop searching and which query shapes are banned; both are load-bearing. Third, **facts-only output**: every data point cites an inline source URL, grouped by dimension. Worldview inference is out of scope. [BC-5824](https://linear.app/brite-nites/issue/BC-5824) `situation-mining` is the downstream consumer that converts these facts into worldview hypotheses.

### Single-process modes, 9 direct invocations

| Mode | Process file | PRIMARY query | Search-count range | What you're looking for |
|---|---|---|---|---|
| `profiles` | `find-profiles.md` | `{{company_name}} {{category}} company overview` | 3–6 | Industry, size, funding, HQ, founded, platform list |
| `competitors` | `find-competitors.md` | `{{company_name}} competitors` | 2–5 | Market position, alternatives, differentiation |
| `growth` | `find-growth-signals.md` | `site:{{domain}} blog OR pricing OR newsletter OR demo OR "free trial" OR "book a call"` | 3–8 | Content investment, lead capture, marketing maturity |
| `hiring` | `find-hiring.md` | `{{company_name}} careers` | 2–4 | Which roles are they hiring? Which are conspicuously absent? |
| `reviews` | `find-reviews.md` | `{{company_name}} {{category}} review` | 3–6 | G2 / Trustpilot / Capterra sentiment |
| `news` | `find-news.md` | `{{company_name}} {{category}} recent news` | 2–5 | Recent announcements, product launches |
| `negativity` | `find-negativity.md` | `{{company_name}} {{category}} complaints OR "negative reviews" OR problems OR issues` | 3–6 | Public pain points, customer friction |
| `founders` | `find-founders.md` | `{{company_name}} CEO OR founder interview OR podcast` | 2–4 | Posting frequency, narrative, worldview cues |
| `c-suite` | `find-c-suite.md` | `{{company_name}} "chief technology" OR "chief product" OR "chief security" -jobs -careers` | 3–6 | CFO / CMO / CRO / CTO names, tenure, recent moves |

Take the PRIMARY query verbatim from the process file. Substitute `{{company_name}}`, `{{domain}}`, `{{category}}`, `{{current_year}}` as applicable. Do NOT invent queries; every query pattern comes from the referenced process file per BC-5824 precedent and §8 Anti-Slop.

### Stop conditions + kill lists

Each process file carries two discipline blocks. **Stop conditions** tell the runner when the signal is sufficient and remaining queries should be skipped (e.g. "stop if you found 5+ distinct reviews with clear sentiment"). **Kill lists** mark queries that must never run, usually because validation showed they return zero results or platform-specific spam (e.g. `site:apollo.io`, `{{company_name}} annual report`, `site:youtube.com`, `site:reddit.com` variants in `find-reviews.md`). Both are load-bearing. §8 Anti-Slop drops any run that violates a kill list to §7's 1–3 band.

### WebSearch, not Serper

Every query is executed via `WebSearch`, Brite's built-in surface. Do NOT reference Serper or Apollo, nor any other third-party search API. `WebSearch` needs no availability check; it is always on.

### Composite modes, 3 fan-out invocations

| Mode | Process files fanned out | Search-count range | When to pick |
|---|---|---|---|
| `full` | `find-profiles.md` + `find-competitors.md` + `find-growth-signals.md` + `find-hiring.md` | 10–23 | Unfamiliar company, quick 4-process baseline |
| `deep` | All 9 company processes: `find-profiles.md` + `find-competitors.md` + `find-growth-signals.md` + `find-hiring.md` + `find-reviews.md` + `find-news.md` + `find-negativity.md` + `find-pr-releases.md` + `find-founders.md` | 25–50 | High-value target warranting broad company-level depth |
| `people` | 7 people processes: `find-founders.md` + `find-c-suite.md` + `find-vp-leadership.md` + `find-directors.md` + `find-department-heads.md` + `find-specialist-roles.md` + `find-people-creative.md` | 20–40 | Org-chart build for ABM or enterprise account planning |

### Plan-gate scope note

`find-pr-releases.md` is included in the `deep` composite (company-level process, no argument dependency). `find-job-role-insights.md` is NOT included in any composite because it requires `{{role_title}}` input that a mode-level dispatch cannot supply; it is addressable only via a direct invocation that passes `role_title` alongside `mode=hiring`. See §6 Operational Runbook Flow 4 for the role-specific follow-up path.

### Parallel execution

All searches within a single mode MUST fire as parallel `WebSearch` tool calls in a single assistant turn (one message, N `tool_use` blocks). Sequential execution multiplies wall-clock by N. On rate-limit or transient failure of a single query, retry once with a 1–2 second delay. If the query still fails, proceed with the remaining queries and mark the missing source in the output artifact per §8 Anti-Slop: cite what's missing, do not fabricate.

### Confidence discipline

Every data point in the output artifact carries an inline source URL. Facts-only discipline: do NOT infer worldview, do NOT generate angles, do NOT write copy. If a process file returns fewer than 2 usable data points for a given dimension, note `thin signal` inline; downstream skills (situation-mining, creative-angles) calibrate confidence from that marker.

---

## Brite Implementation

This section translates §3 Methodology into Brite's concrete stack, which MCP server, which tool, which rule, which repo. Every rule cites its source (ADR, integration guide, or sibling skill) so a skill reader can trace the claim.

### Tools this skill calls

| What the skill needs to do | MCP / tool | Reaches | Reason (ADR / source) |
|---|---|---|---|
| Mode-dispatched per-process research | `WebSearch` | Public web | §3 Methodology, one query per `references/research-processes/find-*.md` PRIMARY pattern; no availability check needed |
| Deep-read a single page when snippet is insufficient | `WebFetch` | Public web | Backup only; use sparingly to avoid burning context |
| Existing-SF-account lookup on the prospect domain | Salesforce MCP (`run_soql_query`) | `brite-salesforce` prod org | ADR 2a, SF is CRM SoR; `salesforce.md` §Common workflows |
| Fetch internal signals for existing accounts | Salesforce MCP (`run_soql_query` on Activity history, Opportunity history, `Account_Notes__c`, `Lifecycle_Stage_History__c`) | `brite-salesforce` prod org | Internal-signal enrichment path; §6 Flow 5 |
| Read reference process files | `Read` | Local `plugins/marketing/references/research-processes/` | §3 Methodology, every PRIMARY query originates here |
| Emit output artifact | `Write` | Local `docs/research/accounts/{domain}-{YYYY-MM-DD}.md` | §6 Runbook output artifact shape |

The wildcard form `mcp__plugin_marketing_salesforce__*` in `allowed-tools` is used per ADR 2c because the SF enrichment path reads across multiple SOQL object types (Account, Activity, Opportunity, `Account_Notes__c`, `Lifecycle_Stage_History__c`). Narrower cherry-picking would couple the frontmatter to a SOQL object taxonomy that will evolve. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) §MCP Tool Reference for the availability probe pattern, SOQL gotchas, and the canonical `run_soql_query` tool name.

### Architectural rules that apply

- **Every query pattern comes from `references/research-processes/`**, no invented queries. Source: §3 Methodology; enforced by §8 Anti-Slop.
- **Respect stop conditions + kill lists literally.** Each process file's discipline blocks are load-bearing. Source: §3 Methodology + [BC-5824](https://linear.app/brite-nites/issue/BC-5824) precedent.
- **Cite source URL inline on every data point.** Facts-only discipline requires the evidence trail. Source: §3 Confidence discipline.
- **Salesforce is the CRM SoR, never cache SF data in the artifact beyond `generated_at`.** Always re-query on artifact refresh. Source: ADR 2a + `salesforce.md` §Auth.
- **SF enrichment degrades gracefully, never halts the skill.** On availability failure, mark `sf_enriched: false` and proceed with a public-only artifact. Source: ADR 2c degradation policy.

### Cross-skill boundaries

**Hands off to:**

- **[BC-5824](https://linear.app/brite-nites/issue/BC-5824) `situation-mining`**, consumes the artifact for worldview inference. The facts this skill produces are the raw input to situation-mining's §Situations block. This is also the canonical path to reach `creative-angles` Deep Mode — see next bullet.
- **[BC-5828](https://linear.app/brite-nites/issue/BC-5828) `creative-angles` Quick Mode (direct) or Deep Mode (transitive via situation-mining)**. Direct handoff to `creative-angles` **Quick Mode** works with only an account-research artifact in context. `creative-angles` **Deep Mode** has a hard prereq on a `docs/research/situations/{domain}-*.md` artifact less than 14 days old (see creative-angles §2 Gate 3) — route through `situation-mining` first, then chain to `creative-angles` Deep Mode. Never offer direct handoff to Deep Mode from account-research; the operator will hit a blocking message.

**Receives from:**

- **User invocation (primary)** with `{company_name, domain, mode, optional category}`.
- **`situation-mining` (subroutine case)**, when situation-mining needs fresh fact-gathering mid-run, it calls account-research as a subroutine and consumes the returned artifact path.

**Does not own:**

- Worldview inference (that's `situation-mining`, [BC-5824](https://linear.app/brite-nites/issue/BC-5824)).
- Angle generation (that's `creative-angles`, [BC-5828](https://linear.app/brite-nites/issue/BC-5828)).
- Copy generation (that's `email-copywriting`, [BC-5825](https://linear.app/brite-nites/issue/BC-5825)).
- List assembly (that's `list-building`, [BC-2717](https://linear.app/brite-nites/issue/BC-2717)).

### Output artifact

Every run writes one artifact to `docs/research/accounts/{domain}-{YYYY-MM-DD}.md`. Frontmatter shape:

```yaml
---
company: Example Co
domain: example.com
category: "coffee roaster"           # optional, omit if unknown
mode: profiles | competitors | growth | hiring | reviews | news | negativity | founders | c-suite | full | deep | people
generated_at: 2026-04-21T14:30:00Z
source_count: 12                     # total usable data points across all queries
sf_enriched: true | false
sf_account_id: "0011a00000xyz"       # omit if sf_enriched: false
process_files_invoked: [find-profiles, find-competitors]   # per mode dispatch
---
```

Seven keys are required (`company`, `domain`, `mode`, `generated_at`, `source_count`, `sf_enriched`, `process_files_invoked`) and two are conditional (`category` when the operator supplied or the research surfaced one; `sf_account_id` only when `sf_enriched: true`).

Body sections (in order, conditional on mode):

1. **Company Facts.** One subsection per process file invoked, grouped by dimension (who / what / where / when). Each bullet cites source URL inline.
2. **Internal Signals (Salesforce).** Only present when `sf_enriched: true`. Lists Activity summary, Opportunity summary, `Account_Notes__c` excerpts, and `Lifecycle_Stage_History__c` entries with SF object IDs.
3. **Thin-signal flags.** If any invoked process returned fewer than 2 usable data points for a dimension, note which dimensions are thin. Downstream skills use this to calibrate confidence.
4. **Handoff pointers.** A short note like "Hand off to `situation-mining` for worldview inference (also the path to `creative-angles` Deep Mode, which requires a situation artifact), or to `creative-angles` Quick Mode for pattern-based angles that need no situation artifact."

---

## MCP Tool Reference

§4 declared WHAT tools this skill uses; §5 says WHEN, which workflow, in what order. Grouping is by what the skill actually does, not by server. Connection details live in the Brite integration guides; this section names tools semantically. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) §MCP Tool Reference for SF auth, SOQL gotchas, and the canonical availability probe pattern.

### Workflow 1 — Mode-dispatched parallel WebSearch (always runs)

No availability check needed, `WebSearch` is always on. Sequence:

1. **Resolve the mode to a process-file set** per §3 Single-process and Composite tables. For a single-process mode this is one file; for `full` it is 4; for `deep` it is 9; for `people` it is 7.
2. **Read the PRIMARY query pattern verbatim** from each resolved `plugins/marketing/references/research-processes/find-*.md` file. Do NOT paraphrase; the canonical pattern is load-bearing per §8 Anti-Slop.
3. **Substitute** `{{company_name}}`, `{{domain}}`, `{{category}}`, `{{current_year}}` as applicable before executing. Any unresolved substitution variable is a configuration error, halt and surface it.
4. **Emit all N queries as parallel `WebSearch` tool calls in a single assistant turn** (one message, N `tool_use` blocks). Sequential execution multiplies wall-clock by N.
5. **On rate-limit or transient failure of a single query**, retry once with a 1–2 second delay. If still failing, proceed with remaining queries and mark the missing source in the output artifact. Per §8 Anti-Slop, cite what's missing rather than fabricate the signal.

Cross-link: each process file at `plugins/marketing/references/research-processes/find-{mode}.md` carries the canonical PRIMARY query plus its stop conditions and kill list. Read the file once per mode dispatch; do not re-read on every substitution.

### Workflow 2 — Existing-Salesforce-account enrichment (conditional)

Runs only when §2 Gate 3 SF-account detection matched an existing Account. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) §MCP Tool Reference for auth, tool names, and SOQL gotchas.

1. **Availability probe (once per invocation).** Call `run_soql_query` with `SELECT Id FROM User LIMIT 1`. This is the verified liveness check per BC-5534 findings §Q1. `get_username` is NOT a valid probe because it reads the local SFDX auth store without contacting Salesforce. Cache the reachable / unreachable result for the remainder of the run; do NOT re-probe.
2. **On availability failure.** Skip enrichment silently. Mark `sf_enriched: false` in the artifact frontmatter and continue. Do NOT halt the skill.
3. **On availability success plus Account match from §2.**
   1. **Activity history.** `run_soql_query` with `SELECT Id, ActivityDate, Subject, Description FROM ActivityHistory WHERE AccountId = '{accountId}' ORDER BY ActivityDate DESC LIMIT 20`. Before interpolating `{accountId}`, confirm it passed §2 input validation against the SF ID format.
   2. **Opportunity history.** `run_soql_query` with `SELECT Id, Name, StageName, CloseDate, Amount FROM Opportunity WHERE AccountId = '{accountId}' ORDER BY CloseDate DESC LIMIT 10`.
   3. **Lifecycle plus notes.** Already pulled in §2 Account lookup via `Account_Notes__c` and `Lifecycle_Stage_History__c` fields on the Account. No extra SOQL call; reuse the cached result.

All SF calls are read-only, no MCP confirmation gates needed. The Activity LIMIT of 20 and Opportunity LIMIT of 10 bound the internal-signal surface to the highest-recency slice; do not raise the caps without an explicit operator request.

### Workflow 3 — WebFetch deep-read (backup, optional)

When a `WebSearch` snippet is insufficient to ground a specific data point, call `WebFetch` on the specific URL. Do NOT use `WebFetch` as a default, snippet analysis is usually enough and `WebFetch` burns context fast. Scope each fetch to one URL with a concrete data point in mind; do not pre-fetch opportunistically.

---

## Operational Runbook

This section turns §3 Methodology plus §5 MCP Tool Reference into five concrete flows that a subagent follows end-to-end. Preconditions, steps, expected output, error handling, and handoff are explicit on every flow so a fresh agent can execute any of them without re-reading the rest of the skill.

### Flow 1 — Profiles mode quick-run (default)

**Preconditions:** §2 Gates 1–4 resolved; mode defaulted or explicitly set to `profiles`; no existing-SF-account match required.

**Steps:**

1. Run §5 Workflow 1 with `find-profiles.md` as the sole resolved process file.
2. Extract company facts per the process file's output template (industry, size, funding, HQ, founded year, third-party platform list), citing source URLs inline.
3. Write the output artifact to `docs/research/accounts/{domain}-{YYYY-MM-DD}.md` with `mode: profiles` in frontmatter and `process_files_invoked: [find-profiles]`.
4. Offer handoff to `situation-mining` for worldview inference (also the only path to `creative-angles` Deep Mode, which requires a situation artifact), or to `creative-angles` Quick Mode for pattern-based angles without a situation artifact.

**Expected output:** a 3–6-query profile sheet with `Company Facts` populated across the 6 canonical dimensions, `sf_enriched: false` (unless §2 Gate 3 matched separately), no `Internal Signals` section.

**Error handling:** per §5 Workflow 1, per-query retry once on rate-limit; proceed with remaining queries on persistent failure and mark the missing source. Never fabricate.

**Handoff:** `situation-mining` (BC-5824) — canonical path for worldview inference, and the only route to `creative-angles` Deep Mode (BC-5828) which hard-halts without a situation artifact. Direct handoff to `creative-angles` Quick Mode (BC-5828) works with just the account-research artifact in context — use that path when Deep Mode is not needed.

### Flow 2 — Full mode for unfamiliar company

**Preconditions:** §2 Gates 1–4 resolved; mode = `full`; company is new to Brite and the operator wants a quick 4-process baseline.

**Steps:**

1. Run §5 Workflow 1 with the 4 `full` composite processes: `find-profiles.md` + `find-competitors.md` + `find-growth-signals.md` + `find-hiring.md`, fired as parallel `WebSearch` calls in a single assistant turn.
2. Compose a 4-dimension fact sheet (who / what / market-position / hiring-signals).
3. Write artifact with `mode: full` and `process_files_invoked: [find-profiles, find-competitors, find-growth-signals, find-hiring]`.
4. Offer handoff to `situation-mining` (also the path to `creative-angles` Deep Mode) or to `creative-angles` Quick Mode.

**Expected output:** a 10–23-query baseline artifact with four `Company Facts` subsections, each citing source URLs inline.

**Error handling:** per §5 Workflow 1. Partial failure is acceptable, note missing dimensions in `Thin-signal flags`.

**Handoff:** `situation-mining` (BC-5824) — canonical path for worldview inference, and the only route to `creative-angles` Deep Mode (BC-5828) which hard-halts without a situation artifact. Direct handoff to `creative-angles` Quick Mode (BC-5828) works with just the account-research artifact in context — use that path when Deep Mode is not needed.

### Flow 3 — Deep mode for high-value target

**Preconditions:** §2 Gates 1–4 resolved; mode = `deep`; high-ACV account or strategic interest justifies the broader research budget.

**Steps:**

1. Run §5 Workflow 1 with the 9 `deep` composite processes per §3 Composite mode table: `find-profiles` + `find-competitors` + `find-growth-signals` + `find-hiring` + `find-reviews` + `find-news` + `find-negativity` + `find-pr-releases` + `find-founders`.
2. Write artifact with `mode: deep` and `process_files_invoked` listing all 9 files.

**Expected output:** a 25–50-query comprehensive company dossier; the `Company Facts` body has 9 subsections, one per process file.

**Error handling:** per §5 Workflow 1. When a single process's queries all fail, note the process as thin in `Thin-signal flags` and continue; do not retry the whole composite.

**Handoff:** `situation-mining` (BC-5824) — canonical path for worldview inference, and the only route to `creative-angles` Deep Mode (BC-5828) which hard-halts without a situation artifact. Direct handoff to `creative-angles` Quick Mode (BC-5828) works with just the account-research artifact in context — use that path when Deep Mode is not needed.

### Flow 4 — People mode for org-chart build

**Preconditions:** §2 Gates 1–4 resolved; mode = `people`; ABM or enterprise-motion context where the operator needs an org-chart layer.

**Steps:**

1. Run §5 Workflow 1 with the 7 `people` composite processes per §3 Composite mode table: `find-founders` + `find-c-suite` + `find-vp-leadership` + `find-directors` + `find-department-heads` + `find-specialist-roles` + `find-people-creative`.
2. Write artifact with `mode: people` and `process_files_invoked` listing all 7 files.

**Expected output:** a 20–40-query people sheet; the `Company Facts` body shows subsections for founders, c-suite, VP leadership, directors, department heads, specialist roles, and people-creative.

**Error handling:** per §5 Workflow 1.

**Role-specific follow-up:** operators wanting role-specific JD intelligence follow up with a direct `find-job-role-insights` invocation passing `role_title` (per §3 Plan-gate scope note). The people mode does NOT dispatch `find-job-role-insights` automatically because the mode surface cannot carry the `role_title` argument.

**Handoff:** `situation-mining` (BC-5824) — canonical path for worldview inference, and the only route to `creative-angles` Deep Mode (BC-5828) which hard-halts without a situation artifact. Direct handoff to `creative-angles` Quick Mode (BC-5828) works with just the account-research artifact in context — use that path when Deep Mode is not needed.

### Flow 5 — Existing-SF-account augmented path

**Preconditions:** §2 Gate 3 SF-account detection matched an existing Brite Account for the prospect `domain`; mode = any (profiles, any single-process, full, deep, or people).

**Steps:**

1. Run §5 Workflow 1 per the chosen mode (dispatch table per §3).
2. Run §5 Workflow 2 SF enrichment (availability probe, then Activity history SOQL at LIMIT 20, then Opportunity history SOQL at LIMIT 10, then reuse the §2 cached Account lookup for lifecycle and notes).
3. Compose the artifact with both public facts AND an `## Internal Signals (Salesforce)` body section AND `sf_enriched: true` in frontmatter. Populate `sf_account_id` from the §2 Account lookup result.

**Expected output:** public fact sheet per chosen mode PLUS SF-sourced Activity summary, Opportunity summary, `Account_Notes__c` excerpts, and `Lifecycle_Stage_History__c` entries, each with their SF object ID inline.

**Error handling:** on SF availability failure mid-run, degrade to a public-only artifact with `sf_enriched: false` and emit a one-line warning to the operator ("Salesforce MCP unavailable, proceeding with public-source facts only"). Never halt. Do not fabricate an `Internal Signals` section.

**Handoff:** `situation-mining` (BC-5824) — canonical path for worldview inference, and the only route to `creative-angles` Deep Mode (BC-5828) which hard-halts without a situation artifact. Direct handoff to `creative-angles` Quick Mode (BC-5828) works with just the account-research artifact in context — use that path when Deep Mode is not needed. Downstream skills read `sf_enriched: true` and weight internal signals accordingly.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | Mode dispatch is correct — the requested mode resolves to the exact process-file set per §3 Single-process and Composite tables (single-mode → 1 file, `full` → 4, `deep` → 9 company processes, `people` → 7 people processes); all queries fire as parallel `WebSearch` calls in a single assistant turn (one message, N `tool_use` blocks); every PRIMARY query is sourced verbatim from the referenced `find-*.md` process file, with `{{company_name}}`, `{{domain}}`, `{{category}}`, `{{current_year}}` substituted only where applicable; every data point in `Company Facts` carries an inline source URL; each process file's stop conditions and kill lists are respected literally (no kill-listed query executed, no query run past a satisfied stop condition); when `sf_enriched: true`, the `## Internal Signals (Salesforce)` section lists Activity, Opportunity, `Account_Notes__c`, and `Lifecycle_Stage_History__c` entries with the SF object IDs that grounded the claims; the artifact frontmatter carries all 7 required keys (`company`, `domain`, `mode`, `generated_at`, `source_count`, `sf_enriched`, `process_files_invoked`) plus the 2 conditional keys when applicable (`category` when supplied or discovered; `sf_account_id` only when `sf_enriched: true`); the artifact is written to the exact path `docs/research/accounts/{domain}-{YYYY-MM-DD}.md`; for composite modes, `process_files_invoked` matches the §3 tables exactly (4 for `full`, 9 for `deep`, 7 for `people`); the handoff pointer to `situation-mining` (BC-5824, canonical path and the only route to Deep Mode) or `creative-angles` Quick Mode (BC-5828, direct) is present, and does not advertise direct handoff to `creative-angles` Deep Mode. |
| 7-9 | Mostly excellent with one gap — e.g. one process file cited by name but its PRIMARY query slightly paraphrased rather than taken verbatim; one data point missing its inline source URL while the rest carry one; the mode expansion matches §3 but `process_files_invoked` lists the files in a different order than the table; `source_count` frontmatter value is off by 1–2; the handoff pointer names one downstream skill instead of both options; one composite process returned only a single usable data point and the run didn't emit an explicit `Thin-signal flags` entry for it. |
| 4-6 | Functional but missing structural elements — mode dispatch invoked sequentially rather than in parallel (N× wall-clock penalty); one process file's kill list violated (a "do not search" query executed); `sf_enriched: false` written despite §2 Gate 3 having found an Account match; thin-signal flags missing on dimensions that are clearly thin; artifact written to the wrong path (missing or malformed date stamp, pluralized filename, outside `docs/research/accounts/`); output artifact frontmatter missing one of the 7 required keys; `Internal Signals (Salesforce)` section written with Activity or Opportunity rows but omitting the SF object IDs. |
| 1-3 | Hard failure — any ONE of these drops the run to 1-3: invented query pattern not present in the referenced `find-*.md` process file; kill-list violation that fabricated a data point (invented SF record, invented URL, or invented Activity entry); a `Company Facts` bullet cited without any inline source URL; mode dispatch executed the wrong process-file set (e.g. `deep` ran 5 processes instead of 9, or `people` pulled in `find-job-role-insights` without an explicit `role_title`); `sf_enriched: true` written when the §5 Workflow 2 availability probe failed; output produced worldview inference, angle generation, or copy (out of scope — that work lives in `situation-mining` and `creative-angles`). |

---

## Anti-Slop Guardrails

Base guardrails (shared across marketing plugin) + skill-specific hard failures. Skill-specific rules are phrased as "Do not X" because they are enforced as validation gates, not style preferences — each one drops the run to §7 1-3 band when violated.

**Base guardrails:**

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).

**Skill-specific hard failures (validation-gated — drop the run to §7 1-3 band):**

- **Do not invent a process that is not in `references/research-processes/`.** Every PRIMARY query pattern originates in a `find-*.md` file in that directory. Adding a new process file is out of scope for this skill — raise a separate issue against the references library and land the new process there first, then update §3.
- **Respect kill lists literally.** Each process file's "do not search" section is load-bearing. Running a kill-listed query (e.g. `site:apollo.io`, `{{company_name}} annual report`, `site:youtube.com` where the process file bans it) drops the run to §7 1-3 regardless of what the query returned.
- **Cite a source URL for every data point.** Facts-only discipline requires the evidence trail. A `Company Facts` bullet without an inline URL is slop — no "reportedly", no "per industry chatter", no paraphrased synthesis without an anchor. Missing URL → §7 1-3.
- **Be tier-aware — do not chase data that does not exist for T3 / T4 companies.** Per process-file validation notes (T1 / T2 have high signal, T3 / T4 have low signal), calibrate query count and retry budget to company size. Emitting 10 retry queries against a micro-company that has no public presence wastes budget and produces thin artifacts.
- **Never emit worldview inference or angle generation.** That is `situation-mining`'s and `creative-angles`' job. Account-research outputs FACTS grouped by dimension — no "This suggests…", no "Test this hypothesis…", no angle scoring, no shelf-life metadata, no verdict labels. Any inference content drops the run to §7 1-3.
- **Never conflate `sf_enriched: true` with an SF availability probe failure.** If the §5 Workflow 2 probe fails, set `sf_enriched: false` and proceed with the public-only artifact. Fabricating an `## Internal Signals (Salesforce)` section when the probe never reached Salesforce is a hard failure — it invents CRM state.

---

## Behavioral Tests

Six scenarios covering the core paths. Structured assertions + fixtures live in `evals/evals.json` alongside this file. Scenario IDs match the `evals.json` entries for 1:1 traceability. Tier 1 scenarios assert on free output — no tool calls required. Tier 2 scenarios require file reads or MCP calls to verify.

### Tier 1 — Free assertions (no tool calls needed)

- **`profiles-mode-happy-path`** — Given `company_name: "Denver Parks & Rec"`, `domain: "denvergov.org"`, `mode: profiles`, the skill runs 3–6 parallel `WebSearch` calls in a single assistant turn, writes the artifact to `docs/research/accounts/denvergov.org-{today}.md` with `mode: profiles` in frontmatter and `process_files_invoked: [find-profiles]`, the `Company Facts` section has bullets that each carry an inline source URL, no `## Internal Signals (Salesforce)` section is present (SF not matched in §2 Gate 3), and no inference or angle content appears anywhere in the artifact.
- **`mode-dispatch-distinct-for-each-mode`** — Given three runs on the same `{domain}` with `mode=profiles`, `mode=full`, and `mode=deep`, each artifact has a distinct `process_files_invoked` frontmatter value matching §3 tables: `[find-profiles]` for `profiles`; `[find-profiles, find-competitors, find-growth-signals, find-hiring]` for `full`; and all 9 company processes `[find-profiles, find-competitors, find-growth-signals, find-hiring, find-reviews, find-news, find-negativity, find-pr-releases, find-founders]` for `deep`. No composite run drops or adds a process file relative to the §3 Composite table.
- **`kill-list-respect`** — Given a process file's "do not search" section listing `site:apollo.io` (or equivalent banned patterns), the skill never executes a `WebSearch` with that pattern. A search-history audit of every `WebSearch` call fired during the run finds zero kill-listed queries. A kill-list violation during the run fails the scenario, regardless of whether the violating query returned usable data.
- **`thin-signal-flagging`** — Given a micro-company with fewer than 2 usable data points in 2 or more dimensions after the chosen mode runs, the artifact contains an explicit `## Thin-signal flags` section that names each weak dimension. No fabricated data fills the gaps, and downstream `Handoff pointers` note the thinness so `situation-mining` and `creative-angles` can calibrate confidence accordingly.

### Tier 2 — Tool-assisted (requires file read or MCP call)

- **`existing-sf-account-augmented`** — Given a `{domain}` that matches an existing Brite Salesforce Account with a lapsed Opportunity, the artifact has `sf_enriched: true` in frontmatter, `sf_account_id` populated from the §2 Gate 3 Account lookup, and an `## Internal Signals (Salesforce)` body section that lists at least one Activity or Opportunity entry with its SF object ID inline. The run fires `run_soql_query` calls against Account, ActivityHistory, and Opportunity per §5 Workflow 2. The `Account_Notes__c` and `Lifecycle_Stage_History__c` content is sourced from the cached §2 Account lookup, not a fresh SOQL call.
- **`sf-unavailable-graceful-degrade`** — Given the Salesforce MCP unavailable at probe time (the `SELECT Id FROM User LIMIT 1` call fails or times out), the skill completes the artifact with `sf_enriched: false` in frontmatter, emits a one-line warning to the operator ("Salesforce MCP unavailable, proceeding with public-source facts only"), and does NOT halt. The artifact still contains the public-source fact sheet derived from the chosen mode, and no `## Internal Signals (Salesforce)` section is present. The `sf_account_id` frontmatter key is omitted.
