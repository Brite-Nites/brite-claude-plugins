# BC-5534 — Salesforce MCP adoption research

**Issue:** [BC-5534](https://linear.app/brite-nites/issue/BC-5534/research-salesforce-mcp-adoption-availability-check-non-ga-gating-auth)
**Branch:** `holden/bc-5534-research-salesforce-mcp-adoption-availability-check-non-ga`
**Deliverable:** `docs/research/salesforce-mcp-findings.md` (findings + prescriptive decision memo + ADR 2c amendment draft)
**Gates:** BC-5535 adoption → BC-2717 / 2720 / 2725 / 2727 / 2728 skills

## Brainstorm outcomes

- Memo style: **prescriptive** — one concrete choice per question
- Research depth: **upstream-first** — deep on `@salesforce/mcp` npm + GitHub; shallow pass on `brite-salesforce` for object/field coverage
- Q6 prod org: **discover via brite-salesforce repo**, confirm with Holden before finalizing
- Scope additions: **Q7 upgrade cadence**, **Q8 MCP confirmation gates inventory** (patterns after BC-5042 addendum)

## Execution directives for the AI agent

1. **Create a TaskCreate list** at the start of execution — one task per T0–T8 below. Mark `in_progress` when starting, `completed` when the task's "Verify" block passes. This keeps progress visible to Holden.
2. **Respect the four check-in gates** (🛑 markers below). After each gate, pause execution and surface the decision/finding so Holden can redirect before downstream work builds on it. Use AskUserQuestion with one question at a time (per `feedback_one_question_at_a_time.md`).
3. **Cite every answer.** Any claim in the findings doc must link to npm, a GitHub permalink (pin commit SHA), an ADR path, or a handbook section. No uncited assertions.
4. **Ground-truth before asserting.** If a tool name, toolset group, or env var is cited, verify it exists in the `@salesforce/mcp` source before writing the claim (per BC-5042 learning).

## Tasks

### T0 — Research framing + validation (~6 min) — 🛑 **Check-in gate #1 after this task**

**Objective:** Before going deep, confirm the research frame is right and surface any stale-context risks early.

- Read `docs/designs/outbound-agent-architecture-adrs.md` — ADR 2a (MCP adoption) and ADR 2c (the TBD this research resolves). Quote the exact TBD text.
- Read `memory/reference_outbound_mcp_servers.md` — note `last refreshed: 2026-04-12`. Mark any claim touching `@salesforce/mcp` as "verify before citing."
- Read `memory/project_salesforce_mcp_adopt.md` — note it calls for adoption "during BC-2717" (stale; BC-5534 supersedes).
- Read the full BC-5534 issue body — confirm the 6 research questions + 6 verification checkboxes are still the shape we're answering.
- Scan `plugins/marketing/.mcp.json` (current state) — confirm no `@salesforce/mcp` entry yet (read-only; no edits).
- Produce a one-paragraph "research frame" summary in the conversation (NOT the findings doc): what we're answering, what we're not, what assumptions might be stale.

🛑 **Check-in gate #1:** Present the research frame + flag any surprises (e.g. ADR already answered, memory file conflicts, .mcp.json already has SF entry). Ask Holden: "Frame good, go deep on T1?"

**Verify:** Research frame paragraph posted. Holden approves or redirects. No findings-doc writes yet.

### T1 — Upstream inventory (`@salesforce/mcp`) (~8 min)

**Objective:** Build the tool/toolset reference table that Q1-Q8 cite back to.

- Fetch `https://www.npmjs.com/package/@salesforce/mcp` via WebFetch — record latest version + publish date + repository URL.
- Resolve the GitHub repo via WebSearch if npm page doesn't link directly.
- Fetch README + tool source listing via github MCP (if registered; else WebFetch of raw GitHub URLs with pinned commit SHA).
- Inventory:
  - All tool names + their toolset grouping
  - Which tools are flagged non-GA (`--allow-non-ga-tools`)
  - Auth options supported (SFDX CLI, OAuth client-credentials, JWT)
  - Env vars the MCP reads
- Write the inventory as an **appendix** in `docs/research/salesforce-mcp-findings.md` so later Q/A blocks can cite it by row.

**Verify:** Tool inventory has ≥10 tools listed. Each tool has toolset group + GA/non-GA flag. Every entry cites a pinned GitHub URL or npm docs URL.

### T2 — Brite-side scan (`Brite-Nites/brite-salesforce`) (~6 min) — 🛑 **Check-in gate #2 after this task**

**Objective:** Confirm prod org config shape + enumerate SF objects/fields the 5 downstream skills touch.

- Read via github MCP (or WebFetch of raw.githubusercontent.com with pinned SHA):
  - Root README
  - `.env.example` or similar config scaffold
  - Any auth/connected-app docs
  - Top-level object list (Lead, Contact, Account, Opportunity, Campaign, Case, custom `Brite__*` objects)
- Map to 5 skills (BC-2717 list-building, 2720 reply-processing, 2725 lead-routing, 2727 data-enrichment, 2728 crm-hygiene): minimum object/field surface each needs.
- Capture prod org URL + service user name if present; otherwise mark as "<pending Holden confirmation>".

🛑 **Check-in gate #2:** Show the per-skill object/field table + what was found for Q6 (prod org URL + service user). Ask Holden to confirm or supply missing values before T4 locks in the Q6 answer.

**Verify:** 5-row table with objects/fields. Q6 data has citations or an explicit pending-confirmation block.

### T3 — Answer Q1-Q3 (availability, non-GA, auth) (~10 min)

- **Q1 availability-check tool:** Compare `sf_org_list_auth_files`, `sf_user_get_current`, trivial SOQL via `sf_data_query`. Pick one; justify with latency + failure-mode reasoning. Cite upstream.
- **Q2 non-GA gating:** List all non-GA tools. Map each to the 5 skills. State default posture (GA-only or opt-in) and named exceptions.
- **Q3 auth strategy:** SFDX CLI token refresh vs OAuth client-credentials vs Connected App JWT. Three-row comparison table (dev workstation, CI, least-privilege). Pick one.

Write `## Q1`, `## Q2`, `## Q3` blocks in findings doc.

**Verify:** Each block has ≥1 citation. Each names a single prescriptive answer. No hedge words.

### T4 — Answer Q4-Q6 (creds, toolsets, prod org) (~10 min)

- **Q4 credential storage:** Env vars the MCP reads (verified against source), `.mcp.json` dollar-brace shape, where a new dev gets creds (1Password? Doppler? handbook?).
- **Q5 toolset scoping:** Default-enabled toolsets for the marketing plugin. Per-skill minimum toolset set (5-row table).
- **Q6 production org scope:** Cite values confirmed at gate #2. Sandboxes explicitly out of scope (ADR 2a).

**Verify:** Q4 env var list is exhaustive against upstream source. Q5 table has no empty cells. Q6 has concrete values (or a Holden-approved pending marker).

### T5 — Answer Q7-Q8 (scope additions) (~6 min) — 🛑 **Check-in gate #3 after this task**

- **Q7 upgrade cadence:** Current version, cadence observed in npm release history (last 3 releases + dates), how a bump surfaces (lockfile diff? manual?), what changes typically break.
- **Q8 MCP confirmation gates inventory:** Which `@salesforce/mcp` tools require user confirmation gates? Two-call pattern candidates. Pattern after BC-5042's Email Bison section.

🛑 **Check-in gate #3:** Present all 8 Q/A blocks to Holden as a compact summary (one-line prescriptive answer per Q). Ask for redirects before writing the decision memo.

**Verify:** Q7 cites ≥3 release dates. Q8 names ≥3 confirmation-gate tools OR states definitively none exist with citation.

### T6 — Decision memo + ADR 2c amendment draft (~8 min) — 🛑 **Check-in gate #4 after this task**

**Objective:** The actionable payload BC-5535 will execute against.

- Decision Memo section. Prescriptive — concrete values, no "TBD", no "depends":
  - Availability-check tool
  - Auth strategy
  - Default toolsets
  - Env var list (named)
  - Non-GA posture
  - Upgrade tracking approach
  - Confirmation-gate policy
- ADR 2c amendment draft (appendix — NOT a commit to the ADR file, per non-goals). Drop-in replacement for the existing TBD paragraph.

🛑 **Check-in gate #4:** Present the decision memo + ADR draft. Ask Holden to confirm before T7 finalization.

**Verify:** Memo has 7 bullets with concrete values. No hedge words. ADR draft reads as a drop-in replacement.

### T7 — Verification pass + memory update (~5 min)

- Run through the 6 verification checkboxes in the issue body against the findings doc.
- Spot-check ≥3 tool/toolset names against `@salesforce/mcp` source (grep).
- Update `memory/project_salesforce_mcp_adopt.md` — supersede the stale "adopt during BC-2717" guidance with a pointer to this findings doc + BC-5535.
- Do NOT commit `.mcp.json` edits or ADR file changes (non-goals).

**Verify:** All 6 issue checkboxes pass. Memory updated with supersession note. No out-of-scope writes.

### T8 — Review + ship (~handoff)

- Run `/workflows:review` on the findings doc + memory update.
- Address P1 findings inline.
- Hand off to `/workflows:ship` for PR creation + Linear update.

## Check-in gate summary

| Gate | After | Purpose |
|------|-------|---------|
| #1 | T0 | Research frame sanity — redirect before going deep |
| #2 | T2 | Q6 prod org values + per-skill object table — confirm before Q4-Q6 lock in |
| #3 | T5 | 8 prescriptive one-liners — redirect before memo |
| #4 | T6 | Final memo + ADR draft — sign-off before ship |

## Out of scope (from issue non-goals)

- No code, no `.mcp.json` edits, no SFDX calls — read-only research.
- No decision on Brite enrichment MCP (that's BC-5536).
- No commit of ADR 2c amendment — BC-5535 commits it.

## Test / review commands

- `./scripts/validate.sh` — sanity (no plugin changes expected).
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — no CLAUDE.md changes expected.
- `/workflows:review` after T7 — review agents on findings doc + memory update.

## Plan size

9 tasks (T0–T8), 4 check-in gates, ~59 min estimated. Well under the 12-task split threshold.
