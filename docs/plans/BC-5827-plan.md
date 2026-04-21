# Plan: BC-5827 — Create marketing skill: account-research

**Issue**: [BC-5827](https://linear.app/brite-nites/issue/BC-5827) — Create marketing skill: account-research (thin orchestrator over references/research-processes/)
**Branch**: `corinne/bc-5827-create-marketing-skill-account-research-thin-orchestrator`
**Tasks**: 12 (estimated 90–110 min focused, subagent-per-task)

## Prerequisites

- **Reference library exists** (shipped in BC-5823): 16 `plugins/marketing/references/research-processes/find-*.md` files verified present via Glob. The issue-named modes map cleanly to these files (verification below).
- **Template**: `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — 9-section scaffold.
- **Sibling pattern anchors**: `plugins/marketing/skills/creative-angles/SKILL.md` (BC-5828, shipped 2026-04-21 — scaffolding source: input validation, gates, SF conditional workflow, output artifact YAML) and `plugins/marketing/skills/situation-mining/SKILL.md` (BC-5824, shipped 2026-04-20 — content-table source: §3 research-processes table format, §6 Flow structure, cross-skill boundary format).
- **Target directory absent**: `plugins/marketing/skills/account-research/` does not exist — this is a net-new skill, no prior content to preserve.
- **SF integration guide**: `plugins/marketing/tools/integrations/salesforce.md` ships canonical availability probe (`SELECT Id FROM User LIMIT 1`) and §Consumed by section — already lists situation-mining + list-building; this plan appends `account-research`.
- **Scoping doc**: `docs/plans/marketing-gtm-expansion.md` §1 confirms account-research sits above situation-mining and below the references layer in the dependency graph.
- **Soft-dep on `docs/marketing-context.md`**: file does not exist in this repo at plan time. Account-research's §2 marketing-context gate degrades gracefully — skill ships today with the reduced-context path; when `docs/marketing-context.md` lands (via `/marketing:product-marketing-context`), no code change is needed. Happy path auto-engages.

### Plan-gate live-read (BC-5828 check #6 — factual-anchor recipe)

**Live-read outcome.** All 16 process files under `plugins/marketing/references/research-processes/` were read to verify the mode-to-file dispatch the issue specifies. Mode mapping is clean for the 9 single-process modes; two files are **not explicitly mapped** by the issue's mode list and need an implementation-time scope decision:

| File | Fits mode(s) | Ambiguity |
|---|---|---|
| `find-profiles.md` | `profiles`, `full`, `deep` | Clean — company-level, no role argument. |
| `find-competitors.md` | `competitors`, `full`, `deep` | Clean. |
| `find-growth-signals.md` | `growth`, `full`, `deep` | Clean. |
| `find-hiring.md` | `hiring`, `full`, `deep` | Clean. |
| `find-reviews.md` | `reviews`, `deep` | Clean. |
| `find-news.md` | `news`, `deep` | Clean. |
| `find-negativity.md` | `negativity`, `deep` | Clean. |
| `find-founders.md` | `founders`, `people` | Clean. |
| `find-c-suite.md` | `c-suite`, `people` | Clean. |
| `find-vp-leadership.md` | `people` | Clean. |
| `find-directors.md` | `people` | Clean. |
| `find-department-heads.md` | `people` | Clean. |
| `find-specialist-roles.md` | `people` | Clean. |
| `find-people-creative.md` | `people` | Clean. |
| `find-pr-releases.md` | **?** (no explicit mode in issue) | Company-level — good fit for `deep`. Proposal: include in `deep` composite, not a standalone mode. |
| `find-job-role-insights.md` | **?** (no explicit mode in issue) | Requires `{{role_title}}` argument — cannot be invoked by a domain-only mode dispatch. Proposal: **omit from all composite modes**; expose only via direct invocation when operator supplies `role_title`. |

**Plan decision (not issue-authoritative — surface to operator in Task 3 if needed)**: mode `deep` = 9 processes = {profiles, competitors, growth, hiring, reviews, news, negativity, pr-releases, founders}. `find-job-role-insights` is addressable only when the operator passes `role_title` — the skill does NOT invoke it as part of `deep` because the argument the issue's mode-dispatch surface doesn't carry. If the operator wants role-specific JD intelligence, they run `find-hiring` first (mode `hiring`) then supply the role and the skill routes through `find-job-role-insights` as a follow-up.

### Precedent alignment

- Aligns with **BC-5828** (creative-angles scaffolding — input-validation regex, Gate 1 marketing-context, SF conditional workflow, output artifact YAML, 9-section ordering). Direct pattern-match for every structural element.
- Aligns with **BC-5824** (situation-mining content tables — §3 research-processes dispatch table format, §6 Flow structure keyed to path/existing-SF/thin-data, cross-skill boundary format).
- Aligns with **BC-5797** (factual-anchor recipe — every process-file name, mode label, and cross-skill reference is verified against the canonical source file before committing). Applied above in the Plan-gate live-read.
- Aligns with **BC-5828 precedent** (plan-inherited factual-anchor drift is a distinct subtype — live-read at Plan gate, recipe check #6). The mode-to-file dispatch was live-verified above; the issue body's "9 company processes" phrase was resolved against the actual file count.
- Aligns with **BC-5825** (skeleton-vs-skin split only when fan-out dominates — single skill, no fan-out; keep bundled in one PR).

## Tasks

### Task 1: Create skill directory and scaffold SKILL.md frontmatter + §1 Opener + stub section headers

**Files**: `plugins/marketing/skills/account-research/SKILL.md` (new), `plugins/marketing/skills/account-research/evals/` (new dir)
**Why**: Lands the file Claude's skill-resolver picks up. Frontmatter and §1 Opener set skill identity, trigger phrases, and user-facing purpose. Stub headers satisfy section-order validator from the start.

**Implementation**:
1. Create `plugins/marketing/skills/account-research/` and `plugins/marketing/skills/account-research/evals/`.
2. Write `SKILL.md` frontmatter:
   - `name: account-research`
   - `description:` — single paragraph covering the thin-orchestrator concept, triggers ("research", "research [company]", "deep research", "find info on", "company research", "people research"), cross-skill note (hands off to situation-mining for worldview inference and creative-angles Deep Mode for signal-cluster extraction; receives from user invocation or situation-mining's fact-gathering subroutine). Distinguish explicitly from situation-mining: "Account-research outputs FACTS grouped by dimension (who, what, where, when). Situation-mining outputs INFERRED WORLDVIEWS + angle hypotheses." Upstream attribution: `Adapted from Revgrowth1/ai-gtm-workflows workflow 01 (MIT).`
   - `user-invocable: true`
   - `allowed-tools: mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob`
   - `metadata: { version: 0.1.0, upstream: Revgrowth1/ai-gtm-workflows, category: Outbound Lead Gen }`
3. Write `# Account Research` title.
4. Write §1 opener (1 paragraph, sibling-pattern length ~80–120 words): audience (BDR / RevOps / marketing operators doing pre-outreach research), business problem (Brite outbound today guesses at company facts — no structured research layer between list-building and per-prospect situation-mining; operators burn WebSearch budget on ad-hoc queries that don't follow stop conditions or kill lists), outcome (a validated company fact sheet written to `docs/research/accounts/{domain}-{YYYY-MM-DD}.md` that situation-mining and creative-angles consume). State the facts-only discipline: no worldview inference, no angle generation, no copy — that work lives downstream. Do NOT list tool names or repo paths here (those live in §4 and §5 per template guidance).
5. Add stub section headers (§2 through §9) with a single `TODO(BC-5827)` line each so section-order validator passes from the first commit.

**Test**:
- Run: `./scripts/validate.sh 2>&1 | head -40`
- Expected: validator picks up the new skill directory; frontmatter parses (no unknown keys); no section-order errors.

**Verify**: File exists at `plugins/marketing/skills/account-research/SKILL.md`. Frontmatter has all 6 required keys. §1 opener is a single paragraph, does not mention tool names. All 9 sections have at least a stub header.

---

### Task 2: Write §2 Before Starting — input validation + marketing-context + mode resolution + SF-account detection

**Files**: `plugins/marketing/skills/account-research/SKILL.md`
**Why**: §2 is the gate layer. Input validation (lifted verbatim from BC-5828 creative-angles) is required because `{domain}` interpolates into both `Write` paths (`docs/research/accounts/{domain}-...`) and SOQL (`WHERE Website LIKE '%{domain}%'`) — identical risk surface to creative-angles Workflow 4.

**Implementation**:
1. Write the verbatim sibling marketing-context soft gate: "Check for product marketing context first. If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: 'Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it.' Then continue using only user-provided information."
2. Write the **Input validation** rule, lifted from creative-angles §2: "Every `{domain}` string the skill receives — whether from the operator or from a handoff — must match `^[a-z0-9.-]+$`. Reject any `{domain}` containing `/`, `\`, `..`, single quotes, semicolons, NUL, or SOQL keywords (`SELECT`, `WHERE`, `OR`, etc.). This validator gates the §4 `Write` destinations and §5 Workflow 2 SOQL interpolation — a poisoned `{domain}` must not reach any tool call."
3. Write the **Mode resolution** gate. Because account-research has 12 modes (overflow AskUserQuestion's 4-option cap), the pattern is: (a) if operator supplied `mode` argument, validate it against the 12-mode allowlist; (b) if unsupplied, default to `profiles`; (c) if the operator explicitly asks "which mode?", surface a 4-option `AskUserQuestion` with {`profiles` (quick overview), `full` (profiles + competitors + growth + hiring), `deep` (all 9 company processes), `people` (7 people processes)} and note the 8 other single-mode options are available by direct argument. Document the allowlist: `profiles`, `competitors`, `growth`, `hiring`, `reviews`, `news`, `negativity`, `founders`, `c-suite`, `full`, `deep`, `people`.
4. Write the **Existing-SF-account detection** soft gate (no halt — sets whether §4 output artifact includes `## Internal Signals (Salesforce)` section). Sequence: availability probe (`run_soql_query` with `SELECT Id FROM User LIMIT 1` per BC-5534 findings §Q1), then Account lookup (`SELECT Id, Name FROM Account WHERE Website LIKE '%{domain}%' LIMIT 5`). On availability failure, mark `sf_enriched: false` in artifact and continue — do NOT halt. On zero matches, also `sf_enriched: false`. On match, proceed to §6 existing-SF-account augmented flow.
5. Write **Disambiguation** soft gate (pattern from situation-mining §2): if `company_name` is common (e.g. "Apex", "Summit", "Pinnacle") and `domain` doesn't unambiguously resolve to one entity, PAUSE and ask for clarification — do NOT burn the research budget on a guess. If domain is supplied and unambiguous, proceed.

**Test**:
- Read the section. Verify four gate subsections (marketing-context, input validation, mode resolution, SF-account detection).
- Grep for the input-validation regex verbatim: `grep -F "^[a-z0-9.-]+$" plugins/marketing/skills/account-research/SKILL.md` — must match.
- Grep for SF availability probe: `grep -F "SELECT Id FROM User LIMIT 1" plugins/marketing/skills/account-research/SKILL.md` — must match.
- Run: `./scripts/validate.sh 2>&1 | grep -i "account-research"` → no new errors.

**Verify**: §2 has exactly four gates. Input-validation regex matches creative-angles verbatim. SF detection is soft (no halt). Disambiguation pause is the sibling situation-mining pattern, not creative-angles' hard halt.

---

### Task 3: Write §3 Methodology part 1 — intro + mode × process-file dispatch table (9 single-mode rows)

**Files**: `plugins/marketing/skills/account-research/SKILL.md`
**Why**: §3 is the structural centerpiece of account-research. The mode-to-process dispatch table is unique to this skill — no prior skill has mode dispatch at cardinality 12. Table format borrows from situation-mining's research-processes table.

**Implementation**:
1. Write §3 heading: `## Methodology`.
2. Intro paragraph (~80 words): three frameworks govern this skill — **mode-dispatched per-process invocation** (12 modes, each dispatching to 1–9 `find-*.md` process files from `plugins/marketing/references/research-processes/`), **stop-condition + kill-list discipline** (every process file has "stop searching when..." and "do not search..." sections — respect them literally), **facts-only output** (evidence chain with inline source URLs per data point, no inference, no angles, no copy). Cite BC-5824 situation-mining for the hand-off contract: account-research produces the facts situation-mining converts into worldview hypotheses.
3. Write `### Single-process modes — 9 direct invocations` subheading. Table with 9 rows matching the issue's mode list:

   | Mode | Process file | PRIMARY query | Search-count range | What you're looking for |
   |---|---|---|---|---|
   | `profiles` | `find-profiles.md` | `{{company_name}} {{category}} company overview` | 3–6 | Industry, size, funding, HQ, founded, platform list |
   | `competitors` | `find-competitors.md` | `{{company_name}} competitors` | 2–5 | Market position, alternatives, differentiation |
   | `growth` | `find-growth-signals.md` | `site:{{domain}} blog OR pricing OR newsletter OR demo OR "free trial" OR "book a call"` | 3–8 | Content investment, lead capture, marketing maturity |
   | `hiring` | `find-hiring.md` | `{{company_name}} careers` | 2–4 | Which roles are they hiring? Which are conspicuously absent? |
   | `reviews` | `find-reviews.md` | (see process file) | 3–6 | G2 / Trustpilot / Capterra sentiment |
   | `news` | `find-news.md` | (see process file) | 2–5 | Recent announcements, product launches |
   | `negativity` | `find-negativity.md` | `{{company_name}} {{category}} complaints OR "negative reviews" OR problems OR issues` | 3–6 | Public pain points, customer friction |
   | `founders` | `find-founders.md` | `{{company_name}} CEO OR founder interview OR podcast` | 2–4 | Posting frequency, narrative, worldview cues |
   | `c-suite` | `find-c-suite.md` | (see process file) | 3–6 | CFO / CMO / CRO / CTO names, tenure, recent moves |

   Note: for each row, state "Take the PRIMARY query verbatim from the process file, substitute `{{company_name}}`, `{{domain}}`, `{{category}}`, `{{current_year}}` as applicable. Do NOT invent queries — every query pattern comes from the referenced process file per BC-5824 precedent and §8 Anti-Slop."

4. Write `### Stop conditions + kill lists` subsection: "Each process file has two discipline blocks — stop conditions (skip remaining queries when signal is sufficient) and kill lists (never run queries marked 'do not search' — e.g. `site:apollo.io`, `{{company_name}} annual report`, `site:youtube.com`). These are load-bearing; §8 Anti-Slop drops any run that violates them to §7 1–3 band."

5. Write `### WebSearch, not Serper` note (verbatim per issue non-goal): "Every query is executed via `WebSearch` — Brite's built-in surface. Do NOT reference Serper, Apollo, or any other third-party search API. `WebSearch` needs no availability check — it is always on."

**Test**:
- Count mode-dispatch rows: exactly 9 single-process rows.
- Grep for each of the 9 process file names — all must appear linked to their mode label.
- Grep: `grep -F "Do NOT invent queries" plugins/marketing/skills/account-research/SKILL.md` — must appear.
- Grep: `grep -iE "serper|apollo" plugins/marketing/skills/account-research/SKILL.md` — zero matches (outside the explicit "do not use" call-outs in §3/§8 allowed — but no positive references).

**Verify**: §3 Methodology part 1 has the intro paragraph + single-process mode table (9 rows) + stop-condition/kill-list subsection + WebSearch-not-Serper note. File names match the `references/research-processes/` directory exactly (factual-anchor rule per BC-5797).

---

### Task 4: Write §3 Methodology part 2 — composite modes (full / deep / people) + parallel execution + confidence discipline

**Files**: `plugins/marketing/skills/account-research/SKILL.md`
**Why**: Composite modes are the other half of the dispatch story. Each composite expands to a set of process files from Task 3's table. Per Plan-gate live-read, `deep` definition needs an explicit decision captured in the draft.

**Implementation**:
1. Write `### Composite modes — 3 fan-out invocations` subheading. Table with 3 rows:

   | Mode | Process files fanned out | Search-count range | When to pick |
   |---|---|---|---|
   | `full` | `find-profiles` + `find-competitors` + `find-growth-signals` + `find-hiring` | 10–23 | Unfamiliar company — quick 4-process baseline |
   | `deep` | All 9 company processes: `find-profiles` + `find-competitors` + `find-growth-signals` + `find-hiring` + `find-reviews` + `find-news` + `find-negativity` + `find-pr-releases` + `find-founders` | 25–50 | High-value target warranting broad company-level depth |
   | `people` | 7 people processes: `find-founders` + `find-c-suite` + `find-vp-leadership` + `find-directors` + `find-department-heads` + `find-specialist-roles` + `find-people-creative` | 20–40 | Org-chart build for ABM or enterprise account planning |

2. Add a **Plan-gate scope note** subsection: "`find-pr-releases.md` is included in the `deep` composite (company-level process, no argument dependency). `find-job-role-insights.md` is NOT included in any composite because it requires `{{role_title}}` input that a mode-level dispatch cannot supply; it is addressable only via a direct invocation that passes `role_title` alongside `mode=hiring` — see §6 Operational Runbook Flow 4 for the role-specific follow-up path."

3. Write `### Parallel execution` subsection: "All searches within a single mode MUST fire as parallel `WebSearch` tool calls in a single assistant turn (one message, N `tool_use` blocks). Sequential execution is N× the wall-clock. On rate-limit or transient failure of any single query, retry once with a 1–2s delay. If still failing, proceed with the remaining queries and mark the missing source in the output artifact — per §8 Anti-Slop, cite what's missing rather than fabricate the signal."

4. Write `### Confidence discipline` subsection (adapted from BC-5824 situation-mining §3): "Every data point in the output artifact carries an inline source URL. Facts-only discipline — do NOT infer worldview, do NOT generate angles, do NOT write copy. If a process file returns < 2 usable data points per dimension, note 'thin signal' inline; downstream skills (situation-mining, creative-angles) decide what to make of it."

**Test**:
- Grep for "find-pr-releases" in §3 — must appear in the `deep` row.
- Grep for "find-job-role-insights" — must appear only in the Plan-gate scope note subsection, NOT in any composite mode row.
- Count parallel-execution mandate: `grep -F "single assistant turn" plugins/marketing/skills/account-research/SKILL.md` — at least 1 match.
- Grep for "facts-only" — must appear at least twice (§1 opener + §3 confidence discipline).

**Verify**: §3 Methodology part 2 has composite mode table (3 rows) + Plan-gate scope note (pr-releases and job-role-insights) + parallel-execution rule + confidence discipline. Sum of process files across all composites + single modes = 16 files accounted for (9 company + 7 people). The `find-pr-releases` inclusion in `deep` and the `find-job-role-insights` exclusion is documented explicitly — no silent drops.

---

### Task 5: Write §4 Brite Implementation — tool table + SF enrichment conditional + cross-skill boundaries + output artifact YAML

**Files**: `plugins/marketing/skills/account-research/SKILL.md`
**Why**: §4 translates portable methodology into Brite's concrete stack. The conditional SF enrichment workflow is the Brite differential — when the prospect is an existing SF Account, append internal-signal context to the artifact.

**Implementation**:
1. `### Tools this skill calls` subheading — table with 6 rows:

   | What the skill needs to do | MCP / tool | Reaches | Reason (ADR / source) |
   |---|---|---|---|
   | Mode-dispatched per-process research | `WebSearch` | Public web | §3 Methodology — one query per `references/research-processes/find-*.md` PRIMARY pattern; no availability check needed |
   | Deep-read a single page when snippet is insufficient | `WebFetch` | Public web | Backup only; use sparingly to avoid burning context |
   | Existing-SF-account lookup on the prospect domain | Salesforce MCP (`run_soql_query`) | `brite-salesforce` prod org | ADR 2a — SF is CRM SoR; `salesforce.md` §Common workflows |
   | Fetch internal signals for existing accounts | Salesforce MCP (`run_soql_query` on Activity history, Opportunity history, `Account_Notes__c`, `Lifecycle_Stage_History__c`) | `brite-salesforce` prod org | Internal-signal enrichment path; §6 Flow 5 |
   | Read reference process files | `Read` | Local `plugins/marketing/references/research-processes/` | §3 Methodology — every PRIMARY query originates here |
   | Emit output artifact | `Write` | Local `docs/research/accounts/{domain}-{YYYY-MM-DD}.md` | §6 Runbook output artifact shape |

   Note: "The wildcard form `mcp__plugin_marketing_salesforce__*` in `allowed-tools` is used per ADR 2c because the SF enrichment path reads across multiple SOQL object types (Account, Activity, Opportunity, Account_Notes__c, Lifecycle_Stage_History__c). Narrower cherry-picking would couple the frontmatter to a SOQL object taxonomy that will evolve."

2. `### Architectural rules that apply` — 5 bullets:
   - **Every query pattern comes from `references/research-processes/`** — no invented queries. Source: §3 Methodology; enforced by §8 Anti-Slop.
   - **Respect stop conditions + kill lists literally** — each process file's discipline blocks are load-bearing. Source: §3 Methodology + BC-5824 precedent.
   - **Cite source URL inline on every data point** — facts-only discipline requires evidence trail. Source: §3 Confidence discipline.
   - **Salesforce is the CRM SoR — never cache SF data in the artifact beyond `generated_at`** — always re-query on artifact refresh. Source: ADR 2a + `salesforce.md` §Auth.
   - **SF enrichment degrades gracefully — never halts the skill** — on availability failure, mark `sf_enriched: false` and proceed with public-only artifact. Source: ADR 2c degradation policy.

3. `### Cross-skill boundaries` subsection:
   - **Hands off to:**
     - [BC-5824](https://linear.app/brite-nites/issue/BC-5824) `situation-mining` — consumes the artifact for worldview inference. The facts this skill produces are the raw input to situation-mining's §Situations block.
     - [BC-5828](https://linear.app/brite-nites/issue/BC-5828) `creative-angles` Deep Mode — consumes the artifact for signal-cluster extraction. Account-research facts feed the 2+-data-points-per-cluster rule downstream.
   - **Receives from:**
     - User invocation (primary) with `{company_name, domain, mode, optional category}`.
     - `situation-mining` (optional) — when situation-mining needs fresh fact-gathering mid-run, it calls account-research as a subroutine and consumes the returned artifact path.
   - **Does not own:**
     - Worldview inference (that's situation-mining).
     - Angle generation (that's creative-angles).
     - Copy generation (that's email-copywriting — BC-5825).
     - List assembly (that's list-building — BC-2717).

4. `### Output artifact` subsection. Path: `docs/research/accounts/{domain}-{YYYY-MM-DD}.md`. Schema:
   ```yaml
   ---
   company: Example Co
   domain: example.com
   category: "coffee roaster"   # optional — omit if unknown
   mode: profiles | competitors | growth | hiring | reviews | news | negativity | founders | c-suite | full | deep | people
   generated_at: 2026-04-21T14:30:00Z
   source_count: 12             # total usable data points across all queries
   sf_enriched: true | false
   sf_account_id: "0011a00000xyz"  # omit if sf_enriched: false
   process_files_invoked: [find-profiles, find-competitors]  # per mode dispatch
   ---
   ```
   Body sections (in order, conditional on mode):
   1. **Company Facts** — one section per process file invoked, grouped by dimension (who / what / where / when). Each bullet cites source URL inline.
   2. **Internal Signals (Salesforce)** — only present when `sf_enriched: true`. Lists Activity summary, Opportunity summary, `Account_Notes__c` excerpts, `Lifecycle_Stage_History__c` entries with SF object IDs.
   3. **Thin-signal flags** — if any invoked process returned < 2 usable data points, note which dimensions are thin. Downstream skills use this to calibrate confidence.
   4. **Handoff pointers** — a short note like "Hand off to `situation-mining` for worldview inference or `creative-angles` Deep Mode for signal-cluster extraction."

**Test**:
- Run `./scripts/validate.sh` — no new errors.
- Grep cross-skill boundaries — must name BC-5824, BC-5828, BC-5825, BC-2717 explicitly with Linear URL format.
- Grep SF availability note in §4 architectural rules — must mention "degrades gracefully" or "never halts".
- Grep output artifact frontmatter — 7 required keys (`company`, `domain`, `mode`, `generated_at`, `source_count`, `sf_enriched`, `process_files_invoked`) + 2 conditional (`category`, `sf_account_id`).

**Verify**: §4 has 4 subsections (tool table, architectural rules, cross-skill boundaries, output artifact). Output path is exactly `docs/research/accounts/{domain}-{YYYY-MM-DD}.md`. All 12 mode labels enumerated in the frontmatter `mode` field.

---

### Task 6: Write §5 MCP Tool Reference — Workflow 1 (WebSearch per-process) + Workflow 2 (SF enrichment conditional) + Workflow 3 (WebFetch backup)

**Files**: `plugins/marketing/skills/account-research/SKILL.md`
**Why**: §5 is WHEN tools are called — grouped by workflow, not by server. Three workflows: per-process WebSearch dispatch (always runs), SF enrichment (conditional), WebFetch deep-read (backup).

**Implementation**:
1. `### Workflow 1 — Mode-dispatched parallel WebSearch (always runs)` — no availability check (WebSearch always on). Sequence: (a) resolve mode to process-file set per §3 tables; (b) for each process file, read the PRIMARY query pattern verbatim; (c) substitute `{{company_name}}`, `{{domain}}`, `{{category}}`, `{{current_year}}` as applicable; (d) emit all N queries as parallel `WebSearch` tool calls in a single assistant turn; (e) on rate-limit or transient failure of any single query, retry once with a 1–2s delay; (f) if still failing, proceed with remaining queries and mark missing source in artifact. Cross-link: `plugins/marketing/references/research-processes/find-{mode}.md` for the canonical PRIMARY query + stop conditions + kill list.

2. `### Workflow 2 — Existing-Salesforce-account enrichment (conditional)` — runs only when §2 SF-account detection matched. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) §MCP Tool Reference for auth, tool names, SOQL gotchas. Sequence:
   - **Availability probe (once per invocation)**: `run_soql_query` with `SELECT Id FROM User LIMIT 1`. Verified liveness check per BC-5534 findings §Q1. `get_username` is NOT valid — it reads the local SFDX auth store without contacting Salesforce. Cache result for the remainder of the run.
   - **On availability failure**: skip enrichment silently. Mark `sf_enriched: false` in artifact frontmatter. Do NOT halt the skill. Do NOT re-probe.
   - **On availability success + Account match in §2**:
     1. **Activity history**: `run_soql_query` with `SELECT Id, ActivityDate, Subject, Description FROM ActivityHistory WHERE AccountId = '{accountId}' ORDER BY ActivityDate DESC LIMIT 20`. Before interpolating `{accountId}`, confirm it passed §2 input-validation against the SF ID format.
     2. **Opportunity history**: `run_soql_query` with `SELECT Id, Name, StageName, CloseDate, Amount FROM Opportunity WHERE AccountId = '{accountId}' ORDER BY CloseDate DESC LIMIT 10`.
     3. **Lifecycle + notes**: pulled in §2 Account lookup via `Account_Notes__c` + `Lifecycle_Stage_History__c` fields. No extra SOQL call needed — reuse the cached result.
   - All SF calls are read-only; no MCP confirmation gates needed.

3. `### Workflow 3 — WebFetch deep-read (backup, optional)` — when a `WebSearch` snippet is insufficient to ground a specific data point, call `WebFetch` on the specific URL. Do NOT use WebFetch as default. Scope each fetch to one URL with a concrete data point in mind — do not pre-fetch opportunistically.

**Test**:
- Grep workflow count: 3 workflows.
- Grep SF availability check pattern: `grep -F "SELECT Id FROM User LIMIT 1" plugins/marketing/skills/account-research/SKILL.md` — must match.
- Confirm no invented tool names — only `WebSearch`, `WebFetch`, `run_soql_query` should appear in §5.

**Verify**: §5 has exactly 3 workflows. Workflow 2 uses the BC-5534-verified availability probe and has a silent-degrade path. No `get_username` references anywhere in §5 (it is NOT a valid liveness check).

---

### Task 7: Write §6 Operational Runbook — 5 flows (profiles quick-run, full unfamiliar, deep high-value, people org-chart, existing-SF augmented)

**Files**: `plugins/marketing/skills/account-research/SKILL.md`
**Why**: §6 is the step-by-step procedural layer. Issue Tasks §8 names 5 runbook scenarios. Each flow is a concrete path operators actually run, with preconditions + steps + expected output + error handling + handoff.

**Implementation**:
1. `### Flow 1 — Profiles mode quick-run (default)` — preconditions (§2 gates resolved, mode defaulted or set to `profiles`), steps (Run §5 Workflow 1 with `find-profiles.md` → extract company facts per process-file output template → write artifact to `docs/research/accounts/{domain}-{YYYY-MM-DD}.md` with `mode: profiles` → offer handoff to situation-mining if operator wants worldview inference), expected output (3–6-query profile sheet: industry, size, funding, HQ, founded year, third-party platform list), error handling (per §5 Workflow 1), handoff (situation-mining or creative-angles Deep Mode).

2. `### Flow 2 — Full mode for unfamiliar company` — preconditions (§2 gates, mode = `full`, company is new to Brite), steps (Run §5 Workflow 1 with 4 processes: profiles + competitors + growth + hiring → compose 4-dimension fact sheet → artifact with `mode: full`), expected output (10–23-query baseline covering who/what/where/market-position/content-investment/hiring-signals).

3. `### Flow 3 — Deep mode for high-value target` — preconditions (§2 gates, mode = `deep`, high-ACV account or strategic interest), steps (Run §5 Workflow 1 with 9 company processes per §3 composite table → artifact with `mode: deep`), expected output (25–50-query comprehensive company dossier; `Company Facts` section has 9 subsections, one per process file).

4. `### Flow 4 — People mode for org-chart build` — preconditions (§2 gates, mode = `people`, ABM or enterprise-motion context), steps (Run §5 Workflow 1 with 7 people processes per §3 composite table → artifact with `mode: people`), expected output (20–40-query people sheet; `Company Facts` section shows founders / c-suite / VP / directors / department-heads / specialist-roles / people-creative subsections). Note: operators wanting role-specific JD intelligence follow up with a direct `find-job-role-insights` invocation passing `role_title` (per §3 Plan-gate scope note).

5. `### Flow 5 — Existing-SF-account augmented path` — preconditions (§2 SF detection matched, mode = any), steps (Run §5 Workflow 1 per chosen mode → run §5 Workflow 2 SF enrichment → compose artifact with both public facts AND `## Internal Signals (Salesforce)` section AND `sf_enriched: true`), expected output (public fact sheet + SF-sourced Activity summary + Opportunity summary + Account_Notes__c excerpts + Lifecycle_Stage_History__c entries). Error handling: on SF availability failure mid-run, degrade to public-only artifact with `sf_enriched: false` and a one-line warning to the operator. Never halt.

**Test**:
- Count flows: exactly 5.
- Grep Flow 5 for "degrade" or "never halt" — must be present.
- Grep Flow 4 for "`find-job-role-insights`" — must appear with the "direct invocation passing role_title" framing.

**Verify**: §6 has exactly 5 flows. Each flow has preconditions + steps + expected output + error handling + handoff. Flow 5's SF enrichment is never a hard halt (matches §4 architectural rule).

---

### Task 8: Write §7 Health Scoring Rubric + §8 Anti-Slop Guardrails

**Files**: `plugins/marketing/skills/account-research/SKILL.md`
**Why**: §7 is the reviewer rubric (4 bands). §8 is 4 base guardrails + 4+ skill-specific per issue verification line. Both feed the validation review agents run.

**Implementation §7**:
1. `## Health Scoring Rubric` section. 4 bands with skill-specific criteria:
   - **10:** Correct mode dispatch — requested mode resolves to the exact process-file set per §3 tables; all queries executed in parallel (single assistant turn); every PRIMARY query sourced verbatim from the corresponding `find-*.md` process file; every data point in `Company Facts` carries an inline source URL; stop conditions + kill lists from each process file respected literally; if `sf_enriched: true`, §Internal Signals section lists the SF object IDs that grounded the claims; artifact frontmatter has all 7 required keys + 2 conditional (per §4 schema); artifact written to exact path `docs/research/accounts/{domain}-{YYYY-MM-DD}.md`; when mode is `full` / `deep` / `people`, composite expansion matches §3 table (4 / 9 / 7 processes respectively); handoff pointer to situation-mining or creative-angles Deep Mode included.
   - **7–9:** Mostly excellent with one gap — e.g. one process file cited by name but the PRIMARY query slightly paraphrased; one data point missing an inline URL but the rest have it; mode expansion correct but one composite omitted; `source_count` frontmatter value is off by 1–2.
   - **4–6:** Functional but missing structural elements — e.g. mode dispatch invoked sequentially instead of in parallel (N× wall-clock penalty); one process file's kill list violated (a "do not search" query executed); `sf_enriched: false` written despite §2 detection finding an Account; thin-signal flags missing on clearly thin dimensions; artifact written to wrong path (date stamp missing, pluralized filename, outside `docs/research/accounts/`).
   - **1–3:** Hard failure — any ONE of: invented query pattern not in the referenced process file; kill-list violation fabricated data (invented SF record, invented URL); single data point cited without source URL; mode dispatch ran the wrong process-file set (e.g. `deep` ran 5 processes instead of 9); `sf_enriched: true` written when SF availability probe failed; output produced worldview inference or angles (out of scope — that's situation-mining / creative-angles).

**Implementation §8**:
1. `## Anti-Slop Guardrails` section.
2. 4 base guardrails (verbatim from template):
   - Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
   - Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
   - Do not produce output that ignores `docs/marketing-context.md`.
   - Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).
3. Skill-specific guardrails (per issue verification line, expanded for factual-anchor rigor):
   - **Do not invent a process that's not in `references/research-processes/`.** Every PRIMARY query pattern originates in a `find-*.md` file in that directory. Adding a new process file is out of scope for this skill — raise a separate issue against the references library.
   - **Respect kill lists literally.** Each process file's "do not search" section is load-bearing. Running a kill-listed query drops the run to §7 1–3.
   - **Cite source URL for every data point.** Facts-only discipline requires the evidence trail. A Company Facts bullet without an inline URL is slop and fails §7.
   - **Tier-aware — don't chase data that doesn't exist for T3/T4 companies.** Per process-file validation notes (T1/T2 high signal, T3/T4 low signal), calibrate queries to company size; emitting 10 retry queries on a micro-company that has no public presence wastes budget.
   - **Never emit worldview inference or angle generation.** That's situation-mining's and creative-angles' job. Account-research outputs FACTS grouped by dimension — no "This suggests…", no "Test this hypothesis…", no angle scoring.
   - **Never conflate `sf_enriched: true` with SF availability failure.** If the availability probe fails, set `sf_enriched: false` and proceed. Fabricating a §Internal Signals section when SF wasn't actually reached is a hard failure.

**Test**:
- Grep §7 rubric band 10 for "mode dispatch", "process-file set", "parallel", "kill lists" — all must appear.
- Grep §8 for "invent a process" — must appear.
- Grep §8 for "kill list" — must appear.
- Grep §8 base count: exactly 4 base. Skill-specific: ≥ 4 (issue verification line mandates 4 specific ones). Total ≥ 8.

**Verify**: §7 has all 4 bands with skill-specific criteria. §8 has exactly 4 base + 6 skill-specific (total 10) guardrails. No em-dashes in anti-slop body text.

---

### Task 9: Write §9 Behavioral Tests + create `evals/evals.json` with 6+ scenarios

**Files**: `plugins/marketing/skills/account-research/SKILL.md`, `plugins/marketing/skills/account-research/evals/evals.json` (new)
**Why**: §9 in SKILL.md lists scenarios in prose; evals.json has structured assertions. Both must have ≥ 6 scenarios per issue verification line.

**Implementation §9 (SKILL.md)**:
1. `## Behavioral Tests` section with Tier 1 + Tier 2 split.
2. Tier 1 (no tool calls needed) — 4 scenarios:
   - `profiles-mode-happy-path` — Given `company_name: "Denver Parks & Rec"`, `domain: "denvergov.org"`, `mode: profiles`, the skill runs 3–6 parallel `WebSearch` calls (all in single turn), writes artifact to `docs/research/accounts/denvergov.org-{today}.md` with `mode: profiles` in frontmatter, `Company Facts` section has bullets with inline source URLs, no `## Internal Signals` section (SF not matched), no inference or angle content.
   - `mode-dispatch-distinct-for-each-mode` — Given three runs on the same domain with `mode=profiles`, `mode=full`, `mode=deep`, each artifact has distinct `process_files_invoked` frontmatter values matching §3 tables: `[find-profiles]`, `[find-profiles, find-competitors, find-growth-signals, find-hiring]`, and all 9 company processes respectively.
   - `kill-list-respect` — Given a process file's "do not search" section listing `site:apollo.io`, the skill never executes a `WebSearch` with that pattern. Search-history audit confirms zero kill-listed queries.
   - `thin-signal-flagging` — Given a micro-company with < 2 usable data points in 2+ dimensions, artifact contains explicit `## Thin-signal flags` section naming the weak dimensions. No fabricated data fills the gap.

3. Tier 2 (tool-assisted / file-read) — 2 scenarios:
   - `existing-sf-account-augmented` — Given a domain matching a Brite SF Account with a lapsed Opportunity, artifact has `sf_enriched: true`, `sf_account_id` populated, `## Internal Signals (Salesforce)` section lists at least one Opportunity/Activity entry with the SF object ID inline. Requires `run_soql_query` tool call on Account + ActivityHistory + Opportunity.
   - `sf-unavailable-graceful-degrade` — Given SF MCP unavailable at probe time, the skill completes the artifact with `sf_enriched: false` in frontmatter, logs a one-line warning to the operator, and does NOT halt. Artifact still contains the public-source fact sheet derived from the chosen mode.

**Implementation `evals.json`**:
1. JSON schema matches sibling `plugins/marketing/skills/creative-angles/evals/evals.json`: `{ skill, version, scenarios: [...] }`.
2. Each scenario: `id, tier, description, input, assertions[]`.
3. Populate 6 scenarios matching §9 (1:1 by `id`). Ensure `input` objects include `mocked_marketing_context`, `mocked_filesystem`, or `mocked_sf_response` fields where scenarios depend on them.

**Test**:
- Validate JSON: `python3 -c "import json; json.load(open('plugins/marketing/skills/account-research/evals/evals.json'))"` → exit 0.
- Count scenarios: count entries in the `scenarios` array → 6.
- Grep §9 scenario IDs against `evals.json` — each ID appears exactly once in SKILL.md §9 and exactly once in evals.json.

**Verify**: §9 has ≥ 6 scenarios with a Tier 1 / Tier 2 split. evals.json parses as JSON, has 6 scenarios with IDs matching §9 verbatim.

---

### Task 10: Cross-link §Consumers in `salesforce.md` + `research-processes/README.md`

**Files**: `plugins/marketing/tools/integrations/salesforce.md`, `plugins/marketing/references/research-processes/README.md` (may need creation if absent)
**Why**: Issue verification line: "`salesforce.md` §Consumers lists this skill" and Task #14: "Cross-link from `references/research-processes/README.md` (if created, add §Consumers)". Keeps the reverse-index discoverable.

**Implementation**:
1. Open `plugins/marketing/tools/integrations/salesforce.md`. Locate `## Consumed by` section. Append a bullet naming `account-research` (BC-5827) with a brief how-used note: "existing-SF-account enrichment conditional via `run_soql_query` on Account, Activity history, Opportunity history, `Account_Notes__c`, `Lifecycle_Stage_History__c` to augment public-source fact sheets with internal signals."
2. Check if `plugins/marketing/references/research-processes/README.md` exists. If yes, append a §Consumers section (or append to existing) naming account-research as "thin orchestrator dispatching per-mode to these process files; 12 modes total (9 single-process + full + deep + people)". If the README doesn't exist, skip silently per issue wording: "(if created, add §Consumers)".

**Test**:
- Grep `salesforce.md`: `grep -c "account-research" plugins/marketing/tools/integrations/salesforce.md` → ≥ 1.
- If README exists: `grep -c "account-research" plugins/marketing/references/research-processes/README.md` → ≥ 1.
- Run `./scripts/validate.sh 2>&1 | grep -i "account-research"` → skill is discovered.

**Verify**: `salesforce.md` §Consumed by section has `account-research` entry with a brief how-used note. If `research-processes/README.md` exists, it also links to the skill. Validator lists the skill as registered.

---

### Task 11: Validate directory auto-discovery + section ordering

**Files**: No edits unless validation fails.
**Why**: Skill registration is via the plugin.json skills glob — no explicit registration needed. Confirm by running the validator and checking output.

**Implementation**:
1. Run `./scripts/validate.sh 2>&1 | tee /tmp/validate-bc-5827.log`.
2. Confirm `account-research` appears in the marketing plugin's skill list in the validator output.
3. Confirm no section-order errors, no frontmatter errors, no orphan stub-headers from Task 1.
4. If any issue surfaces, read the error, fix the underlying content in SKILL.md, and re-run.

**Test**:
- Command: `./scripts/validate.sh 2>&1 | grep -i "account-research"` → shows the skill is registered.
- Command: `./scripts/validate.sh; echo "exit=$?"` → `exit=0`.

**Verify**: Validator exit 0; skill is discoverable; no leftover TODO stubs.

---

### Task 12: Run full validation — `./scripts/validate.sh` + `./scripts/check-guardrails.sh`

**Files**: No edits unless validation fails.
**Why**: Final verification that the skill ships clean through the CI-equivalent local checks.

**Implementation**:
1. Run `./scripts/validate.sh` — exit 0 required per issue verification line.
2. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — exit 0 required.
3. If either fails, read the error output, fix the underlying issue in SKILL.md / evals.json / reference files, and re-run.

**Test**:
- Command: `./scripts/validate.sh && echo "VALIDATE OK" && ./scripts/check-guardrails.sh --claude-md CLAUDE.md && echo "GUARDRAILS OK"`
- Expected: both `OK` lines print; exit 0.

**Verify**: Both scripts exit 0. No warnings tied to `account-research`.

---

## Task Dependencies

- Tasks 1–9 are strictly sequential — each builds on the prior section of SKILL.md.
- Task 10 (cross-links in `salesforce.md` + optional `research-processes/README.md`) depends on Task 1 (skill exists so the link target is valid) and Task 5 (§4 published — §Consumed by entries describe how the skill calls SF MCP).
- Tasks 11–12 (validation) depend on Tasks 1–10 — nothing to validate before content is in place.
- **No parallelizable tasks.** Sequential subagent-per-task execution fits this plan — same as BC-5828.

## Verification Checklist

- [ ] `plugins/marketing/skills/account-research/SKILL.md` exists with frontmatter containing all 6 required keys, no unknown keys
- [ ] File contains all 9 sections in required order (Frontmatter → H1 → Before Starting → Methodology → Brite Implementation → MCP Tool Reference → Operational Runbook → Health Scoring Rubric → Anti-Slop Guardrails → Behavioral Tests)
- [ ] `allowed-tools` exactly matches issue Tool Surface: `mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob` — no Serper, no Apollo, no extra servers
- [ ] `grep -rE "Serper|serper" plugins/marketing/skills/account-research/` returns no positive references (allowed only in explicit "do not use" call-outs in §3/§8)
- [ ] §3 Methodology documents all 12 modes (9 single + 3 composite) with per-mode search-count ranges and process-file sets
- [ ] §3 Methodology cites `references/research-processes/` as the source for all query patterns
- [ ] §3 Methodology documents Plan-gate scope decision on `find-pr-releases.md` (included in `deep`) and `find-job-role-insights.md` (excluded from composites; direct invocation only)
- [ ] §4 Brite Implementation documents the SF enrichment conditional (when domain matches existing Account, fetch 5 fields via SOQL)
- [ ] §4 Output artifact path documented as `docs/research/accounts/{domain}-{YYYY-MM-DD}.md` with YAML frontmatter schema (7 required + 2 conditional keys)
- [ ] §6 Operational Runbook has ≥ 4 distinct workflows including existing-SF-account path
- [ ] §8 Anti-Slop Guardrails has ≥ 4 skill-specific rules including "never invent a process", "respect kill lists literally", "cite source URL", "tier-aware"
- [ ] §9 Behavioral Tests has ≥ 6 scenarios covering at least 3 distinct modes + kill-list-respect scenario + SF augmented path
- [ ] `plugins/marketing/skills/account-research/evals/evals.json` parses as valid JSON and has ≥ 6 scenarios with IDs matching §9
- [ ] Output artifact YAML schema documented (company, domain, category, mode, generated_at, source_count, sf_enriched, process_files_invoked, sf_account_id)
- [ ] `salesforce.md` §Consumed by section lists `account-research` with a brief how-used note
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0
