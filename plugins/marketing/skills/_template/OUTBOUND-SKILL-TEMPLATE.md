---
name: {skill-name}
description: {trigger phrases that activate this skill. If ported from upstream, keep the original description and add Brite-relevant triggers. Avoid vague triggers that collide with other skills.}
user-invocable: true
allowed-tools: mcp__plugin_marketing_emailbison-b2b__*, Read, Write, Glob, Grep
metadata:
  version: 0.1.0
  upstream: {coreyhaines31/marketingskills — if ported; omit this key entirely if net-new}
  category: {Outbound Lead Gen | Demand Generation | Marketing Ops}
---

<!--
OUTBOUND SKILL TEMPLATE — delete this comment block after you copy this file

This file is a scaffold, not a working skill. It implements the 9-section template from ADR 2f
(docs/designs/outbound-agent-architecture-adrs.md). Applies to any marketing skill that declares
`allowed-tools` in its frontmatter, regardless of category. Upstream methodology-only ports omit
sections 4, 5, 6 — see docs/guides/marketing-skill-porting.md — AND remove `allowed-tools` from
the frontmatter entirely.

To use:
  1. Copy this file to plugins/marketing/skills/<skill-name>/SKILL.md.
  2. Replace every {placeholder} and instructional HTML comment with real content.
  3. Edit `allowed-tools` to list ONLY the servers this skill actually calls. The default
     scaffolding shows one Email Bison server; the other adopted servers (add as needed) are:
       - mcp__plugin_marketing_emailbison-personal__*   (personal.outbase.so workspace)
       - mcp__plugin_marketing_salesforce__*            (Salesforce MCP — CRM runtime)
       - mcp__plugin_marketing_github__*                (GitHub MCP — cross-repo file reads)
     Do NOT list servers the skill will not call — that violates pattern guide anti-pattern #4.
  4. Delete this entire comment block and any "tool-calling skills only" sections your skill
     does not need.

Reference reading:
  - docs/designs/outbound-agent-architecture.md (Context, Decisions, Architecture diagram)
  - docs/designs/outbound-agent-architecture-adrs.md (ADR 2f for the section-by-section rationale)
  - docs/guides/skill-tool-integration-pattern.md (three-layer pattern, PR checklist)
  - docs/guides/marketing-skill-porting.md (upstream → Brite conventions)
  - plugins/marketing/tools/integrations/email-bison.md (first real instance)

Frontmatter notes:
  - `allowed-tools` uses the wildcard form (`mcp__plugin_marketing_<server>__*`) per ADR 2c.
  - `category` must be one of the three Brite-native categories. May be enforced by the validator
    if category gating lands (ADR 2f review note).
-->

# {Skill Title}

{One-paragraph opening: who this skill helps, what problem it solves, the one-line purpose statement. This is what a developer sees when deciding whether to invoke the skill.}

<!--
Skill opener guidance:
  - State the audience (BDR, RevOps, Marketing, "anyone launching a campaign").
  - State the problem in business terms ("manual handoff from Snowflake to Email Bison").
  - End with the one-line outcome ("...by generating a governed audience list and an Email Bison
    campaign configuration in a single flow").
  - Do NOT list tool names, MCP servers, or repo paths here. Those belong in sections 4 and 5.
-->

---

## Before Starting

**Check for product marketing context first.** If `docs/marketing-context.md` exists, read it before asking questions and use that context for Brite entity selection, voice, and ICP. If the file does not exist, warn the user: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." Then continue using only user-provided information.

<!--
Before Starting section guidance:
  - The marketing-context check is a hard requirement for every marketing skill. Do not remove it.
  - If the skill also depends on the outbound architecture design doc or the research findings,
    add a second bullet: "Read docs/designs/outbound-agent-architecture.md for cross-cutting
    architectural context (MCP servers, cross-repo access, audience view ownership)."
  - Do NOT duplicate ADR content here — link to the design doc instead.
-->

---

## Methodology

{Portable, non-Brite-specific best practices, frameworks, benchmarks. This section is what makes the skill valuable to anyone running outbound, not just Brite.}

<!--
Methodology section guidance:
  - This is the "teach Claude the domain expertise" section. Think of it as the chapter you'd
    write if this were a public marketing skill.
  - For upstream ports, this is the ported content from coreyhaines31/marketingskills.
  - For net-new skills, structure around frameworks (e.g. ICP → enrichment → waterfall →
    verification → send) and name specific benchmarks (reply rate, bounce rate, positive reply
    rate) from the research findings §7.
  - Include at least one named framework or rubric so the skill has something concrete to apply.
  - Do NOT reference Brite tools, repos, or MCP servers in this section — that content belongs
    in section 4 (Brite Implementation).
-->

### {Framework or concept 1}

{Explain the framework, include an example, tie to an industry benchmark where available.}

### {Framework or concept 2}

{...}

---

## Brite Implementation *(tool-calling skills only — omit for methodology-only upstream ports)*

{Translates the generic methodology into Brite's concrete stack: which repo, which tool, which architectural rule. Cross-links to other skills for boundary clarity.}

<!--
Brite Implementation section guidance:
  - Draw from:
    * Research findings §1 (pipeline layers) for repo/tool mapping
    * ADR 2d (cross-repo pattern) for access methods
    * ADR 2e (audience views) for targeting conventions
    * Architectural rules from outbound-sales-ops: no tool-to-tool writes, single-label
      enforcement, upgrade-only lifecycle transitions
  - Structure this section as a table or as "For X, do Y because Z (rule from ADR N)".
  - Always cite the source of each rule — an ADR number, a repo path, or a research findings
    section — so a skill reader can trace the claim.
  - Include a "Cross-skill boundaries" subsection if the skill hands off to another skill
    (e.g. list-building → campaign-orchestration).
-->

### Tools this skill calls

Organized tool-first because that's how a skill author thinks: "what does my skill need to do?" before "where does the data live?" This matches Section 5 (MCP Tool Reference) which is also tool-first.

| What the skill needs to do | MCP server / tool | Repo or system it reaches | Reason (ADR / source) |
|---|---|---|---|
| {e.g. Read audience view definition} | GitHub MCP (`get_file_contents`) | `brite-data-platform` | ADR 2d — no local clone dependency |
| {e.g. Dedup against known prospects} | Salesforce MCP (`run_soql`) | `brite-salesforce` (production org) | ADR 2a — Salesforce is CRM SoR |
| {e.g. Import leads + create campaign} | Email Bison MCP (`emailbison-b2b`) | Email Bison workspace 52 (`send.outbase.so`) | ADR 2a — sole sequencer |
| {...} | {...} | {...} | {...} |

### Architectural rules that apply

- {Rule 1 from outbound-sales-ops, brite-data-platform, or brite-salesforce, with source citation.}
- {Rule 2.}
- {...}

### Cross-skill boundaries

- **Hands off to:** {other-skill} when {condition}. See {other-skill}'s Operational Runbook for the continuation.
- **Receives from:** {other-skill} when {condition}.
- **Does not own:** {concern outside this skill's scope — point to the skill that does}.

---

## MCP Tool Reference *(tool-calling skills only — omit for methodology-only upstream ports)*

"When you need to X, call `tool_name`." Grouped by workflow, not by server. Connection details live in the integration guides — this section names tools semantically.

<!--
MCP Tool Reference section guidance:
  - Group by workflow (import, configure, analyze, clean up), NOT by server. A skill author
    thinks in tasks; don't make them cross-reference server groupings.
  - Name tools by their bare semantic name (e.g. `create_campaign`, not the full
    `mcp__plugin_marketing_emailbison-b2b__create_campaign` — the `allowed-tools` frontmatter
    already establishes the server prefix).
  - Every mutating workflow must start with an availability check (ADR 2c degradation policy):
    a lightweight read-only tool call. On failure, stop.
  - Availability-check tool names by server:
      - Email Bison: `get_active_workspace_info` (verified).
      - Salesforce: TBD — confirm with the Salesforce integration guide when it lands alongside
        the first Salesforce-consuming skill (ADR 2c review note).
      - GitHub MCP: a low-cost repo-metadata read (e.g. `get_repository`) pending integration
        guide publication.
  - Link to the integration guide at the top of each workflow block for deeper reference — it
    holds the canonical workflow recipes.
  - For each workflow, note any Email Bison limits (e.g. `bulk_create_leads` max 500 leads per
    call), Salesforce gotchas (non-GA tools, governor limits), or cross-repo prerequisites.
  - If a tool has an MCP-level confirmation gate (e.g. `resume_campaign`, `import_leads_to_campaign`,
    `archive_campaign`, `unsubscribe_lead`, `blacklist_lead`, `enable_warmup`, `remove_email_from_blocklist`,
    `remove_domain_from_blocklist`), call it WITHOUT the confirmation parameter first, relay the
    returned prompt to the user, then repeat with confirmation only after explicit approval. Do
    not auto-confirm.
-->

### {Workflow 1: e.g. Launch a campaign end-to-end}

See [`plugins/marketing/tools/integrations/email-bison.md` §Common Workflows](../../../tools/integrations/email-bison.md#common-workflows) for the canonical 8-step recipe, API paths, and request body shapes.

1. Availability check: call `get_active_workspace_info`. On failure, stop and report.
2. Call `bulk_create_leads` (or `upsert_multiple_leads`) with lead data — max 500 per call, chunk larger lists. Store the returned lead IDs.
3. Call `create_campaign` with `{name, max_emails_per_day, max_new_leads_per_day, tracking options}`. Store the returned campaign ID.
4. Call `import_leads_to_campaign` with the lead IDs from step 2 — **MCP confirmation gate**. Do not auto-confirm. If the response flags leads already in another campaign, surface the `allow_parallel_sending` prompt to the user; never enable without explicit approval.
5. Call `list_sender_emails`, filter `status: "connected"`, then call `attach_sender_emails_to_campaign` with the ID array.
6. Call `create_schedule_from_template` with a `schedule_id`.
7. Call `create_sequence_steps` (v1.1 endpoint — avoid the deprecated path) with `title` and the `sequence_steps` array.
8. Call `resume_campaign` to start sending — **MCP confirmation gate**: this tool's description says "STARTS SENDING REAL EMAILS." First call returns a prompt; relay it verbatim; only repeat with confirmation after user approval.

### {Workflow 2: e.g. Check campaign health}

1. Call `get_campaign_stats` for open/reply/bounce rates.
2. Call `get_leads_analytics` for per-lead delivery status.

### {Workflow 3: ...}

{...}

---

## Operational Runbook *(tool-calling skills only — omit for methodology-only upstream ports)*

4–8 step-by-step common tasks. Each task is a complete workflow with preconditions, steps, expected output, and error handling. More detailed than the MCP Tool Reference — this is the *procedure*, including user confirmations and cross-skill handoffs.

<!--
Operational Runbook section guidance:
  - Target 4-8 tasks. Fewer than 4 means the skill probably doesn't need this section (consider
    folding into MCP Tool Reference). More than 8 means split the skill.
  - Each task:
    * States preconditions (what must be true before starting)
    * Lists the steps, which reference section 5 workflows by name
    * Describes expected output (what the skill reports back to the user)
    * Notes error handling (what happens when a step fails — especially the degradation policy)
  - User confirmations: explicitly mark steps where the skill pauses for user input. Don't
    auto-launch campaigns, auto-suppress prospects, or auto-anything with external side effects.
  - Cross-skill handoffs: name the other skill and the condition that triggers the handoff.
-->

### Task 1: {e.g. Launch a new outbound campaign}

**Preconditions:**
- `docs/marketing-context.md` exists and identifies the Brite entity.
- Audience view exists in `brite-data-platform` (or the skill helps create an interface contract — see section 4).

**Steps:**
1. Confirm segment and Brite entity with user.
2. Run Workflow {N}: Audience view discovery.
3. Run Workflow {N}: CRM de-duplication query.
4. Run Workflow {N}: Import leads into a campaign.
5. Pause for user to review imported lead count and confirm campaign name.
6. Run Workflow {N}: Attach senders and verify warmup.
7. Report campaign URL, lead count, senders attached, scheduled start time.

**Error handling:**
- Any MCP availability check failure → stop and report server name + suggestion to check credentials.
- `bulk_create` chunk failure → retry once; on second failure, stop and report which chunk failed.

**Handoff:**
- If user wants sequence design depth, hand off to `campaign-orchestration`.

### Task 2: {...}

{...}

### Task 3: {...}

{...}

### Task 4: {...}

{...}

---

## Health Scoring Rubric

10-point rubric tailored to this skill's output. Review agents use this rubric; keep it specific enough to distinguish good from mediocre output.

<!--
Health Scoring guidance:
  - Every marketing skill must have a rubric. This is unchanged from the upstream convention.
  - Criteria must be skill-specific, not generic ("follows best practices" is too vague).
  - Anchor the top score (10) to concrete, observable behaviors — "applies Framework X with
    specific data from docs/marketing-context.md", not "does a great job".
  - The 1-3 band should describe what "slop" looks like for this skill specifically.
-->

| Score | Criteria |
|------:|----------|
| 10 | {Skill-specific excellence criteria — uses all named frameworks, cites specific benchmarks, respects cross-skill boundaries, no hallucinated tool names, every MCP call preceded by availability check where required.} |
| 7-9 | {Good output with minor gaps — applies frameworks but skips one benchmark, or misses one cross-skill handoff opportunity.} |
| 4-6 | {Functional but missing key elements — correct tool calls but no methodology framing, or generic framework application without Brite specifics.} |
| 1-3 | {Poor output — generic marketing advice, hallucinated tool names or repo paths, ignores product-marketing-context, or uses a framework this skill explicitly rejects in its Anti-Slop list.} |

---

## Anti-Slop Guardrails

Skill-specific guardrails plus the standard base. These are what the skill must *not* do — the guardrails against common failure modes.

<!--
Anti-Slop guidance:
  - The four standard base guardrails below apply to every marketing skill. Do not remove them.
  - Add 3-6 skill-specific guardrails that reflect how THIS skill can go wrong.
  - Prefer "Do not X" over "Always Y" — negative rules are clearer constraints.
  - Draw skill-specific guardrails from: past mistakes the skill author has seen, anti-patterns
    documented in the research findings or ADRs, domain-specific traps (e.g. "do not recommend
    domains that have been part of a Gmail/Yahoo block").
-->

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class").
- Do not fabricate statistics, case studies, or testimonials — always attribute to a source.
- Do not produce output that ignores `docs/marketing-context.md`.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no assumed local clones).
- {Skill-specific guardrail 1}
- {Skill-specific guardrail 2}
- {Skill-specific guardrail 3}

---

## Behavioral Tests

Tier 1 (free assertions, no tool calls needed) + Tier 2 (tool-assisted, requires file read or MCP call). Minimum 6 scenarios.

<!--
Behavioral Tests guidance:
  - Tier 1: assertions that can be evaluated from the skill's text response alone. Examples:
    "output references Framework X", "output includes a checklist", "output does not contain
    jargon from the Anti-Slop list".
  - Tier 2: assertions that require the skill to have read a specific file or called a specific
    MCP tool. Examples: "output references Brite entity from docs/marketing-context.md",
    "output includes results from Salesforce SOQL query".
  - Minimum 6 scenarios across both tiers combined (per ADR 2f §9). More is fine.
  - Structured eval scenarios with full assertions and expected outputs go in
    `evals/evals.json` alongside the skill (not in this file).
-->

### Tier 1 — Free assertions

- Given {scenario A}, output must reference {Framework or rubric from section 3}.
- Given {scenario B}, output must include {expected section or checklist}.
- Output must not contain {anti-slop item 1}.
- Given {Product Hunt-equivalent question for this skill}, output must cover {expected topics}.
- Given {edge-case scenario}, output must {handle the edge case} before prescribing tactics.

### Tier 2 — Tool-assisted

- If `docs/marketing-context.md` exists, output must reference brand context (ICP, channels, voice) from that file.
- {Additional Tier 2 scenarios specific to this skill's MCP calls}.

---

<!--
Section ordering validator hint (for future use by scripts/validate.sh):
  Required sections in this order:
    1. Frontmatter
    2. {Skill Title} (H1)
    3. Before Starting (H2)
    4. Methodology (H2)
    5. Brite Implementation (H2) — required if `allowed-tools` present
    6. MCP Tool Reference (H2) — required if `allowed-tools` present
    7. Operational Runbook (H2) — required if `allowed-tools` present
    8. Health Scoring Rubric (H2)
    9. Anti-Slop Guardrails (H2)
   10. Behavioral Tests (H2)

  Sections 5, 6, 7 may be omitted only when `allowed-tools` is absent from frontmatter
  (methodology-only upstream ports).
-->
