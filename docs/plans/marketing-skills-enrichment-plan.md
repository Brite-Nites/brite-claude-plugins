# Marketing Skills Plugin — Issue Enrichment & Re-tier Plan

**Scope:** Rethink, enrich, and re-prioritize all Linear issues in the Marketing Skills Plugin milestone so they are agent-executable.
**Upstream:** [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) (MIT licensed)
**Milestone:** Marketing Skills Plugin (Linear)

---

## Context

The upstream repo has 32 high-quality marketing skills totaling ~23,000 lines of content. Our current 33 skill issues and 10 tool issues have correct scope but insufficient detail for agent execution — each has a 1-sentence description and a boilerplate checklist. This plan enriches every issue with content inventories, key frameworks, Brite-specific adaptation notes, and priority tiers.

## Execution Rules

1. **Generate a task list** at the start using TaskCreate. Update status as each task completes.
2. **Check in with Holden** after every phase (marked with `🔲 CHECKPOINT`). Do not proceed to the next phase until Holden approves.
3. Read the upstream skill files via GitHub API (`gh api repos/coreyhaines31/marketingskills/contents/...`) to generate accurate content inventories.
4. Use `save_issue` MCP tool to update existing issues. Do NOT create new issues unless the plan explicitly says to.

---

## Phase 0: Close deprecated issues

Before enriching anything, close out issues that are superseded or no longer relevant.

### Task 0.1: Cancel BC-1725 and BC-1726 (if not already canceled)

These bulk issues ("Port 32 marketing skills" and "Port marketing CLI tools") were superseded by the individual per-skill/per-tool issues. Verify they are already Canceled in Linear. If not, cancel them with a comment explaining they were broken into individual issues (BC-2580–BC-2612 for skills, BC-2613–BC-2709 for tools).

### Task 0.2: Cancel BC-2709 (Framer tool)

Framer is not in Brite's validated tool stack. Cancel with comment: "Framer not in Brite's marketing tool stack — see 2026-03-31 tool inventory cleanup."

### Task 0.3: Verify content-strategy and social-media-strategy stub skills

We have stub skills in `plugins/marketing/skills/` for `content-strategy` and `social-media-strategy`. The port issues (BC-2611 for content-strategy) should note these stubs exist and need to be REPLACED (not created fresh) during porting.

### 🔲 CHECKPOINT: Confirm deprecated issues are closed. Show Holden the list of what was closed/verified.

---

## Phase 1: Write the porting guide

Create a reusable porting guide so the mechanical steps aren't repeated in 33 issues.

### Task 1.1: Create `docs/guides/marketing-skill-porting.md`

This document covers the standard steps for porting any upstream skill. Contents:

#### Section 1: Reading the upstream
- How to fetch upstream files: `gh api "repos/coreyhaines31/marketingskills/contents/skills/{name}/SKILL.md" --jq '.content' | base64 -d`
- Always fetch SKILL.md + all files in `references/` directory + `evals/evals.json`

#### Section 2: File mapping
```
Upstream                                    → Brite plugin
skills/{name}/SKILL.md                      → plugins/marketing/skills/{name}/SKILL.md
skills/{name}/references/*.md               → plugins/marketing/skills/{name}/references/*.md
skills/{name}/evals/evals.json              → plugins/marketing/skills/{name}/evals/evals.json
```

#### Section 3: Required modifications to SKILL.md
1. **Frontmatter**: Add `metadata.filePattern` and `metadata.bashPattern` for Brite plugin skill injection
2. **Context path**: Replace `.agents/product-marketing-context.md` with `docs/marketing-context.md` (Brite's path)
3. **Cross-skill references**: Update paths from `../other-skill/SKILL.md` to Brite plugin paths
4. **Add Brite plugin sections** (if not in upstream):
   - Health scoring rubric section
   - Anti-slop guardrails section
   - Behavioral test spec (minimum Tier 1 free assertions)
5. **Register** in `plugins/marketing/.claude-plugin/plugin.json`

#### Section 4: Reference files
- Copy all `references/*.md` files as-is (they contain frameworks, templates, examples)
- No modifications needed unless they reference tools Brite doesn't use

#### Section 5: Evals
- Port `evals/evals.json` to the skill directory
- Evals are behavioral test specs — keep them intact

#### Section 6: Quality checklist (per skill)
- [ ] SKILL.md follows Brite plugin template format
- [ ] All reference files ported
- [ ] Evals ported
- [ ] Health scoring rubric section included
- [ ] Anti-slop guardrails section included
- [ ] Cross-skill references use Brite plugin paths
- [ ] Context path points to `docs/marketing-context.md`
- [ ] Registered in `plugin.json`
- [ ] Skill description matches upstream (preserves trigger phrases)

### 🔲 CHECKPOINT: Show Holden the porting guide for review before proceeding to issue enrichment.

---

## Phase 2: Re-tier priorities and enrich skill issues

Update all 33 skill issues with content inventories, key frameworks, Brite adaptation notes, and priority tiers.

### Priority tier assignments

**Urgent (6 skills) — set priority to "Urgent":**

| Issue | Skill | Lines | Why Urgent |
|-------|-------|------:|------------|
| BC-2586 | copywriting | 868 | Foundation for all marketing copy. Headline formulas, CTA frameworks, page structure templates, 344-line copy-frameworks reference |
| BC-2611 | content-strategy | 559 | Drives what content gets created. Searchable vs shareable framework, content pillars, topic clusters |
| BC-2606 | customer-research | 614 | Voice-of-customer informs everything. Two modes: analyze existing assets + digital watering hole research |
| BC-2607 | launch-strategy | 353 | ORB framework, 5-phase launch approach, Product Hunt playbook. Brite ships features regularly |
| BC-2589 | email-sequence | 1,107 | Welcome/nurture/re-engagement flows. Rich sequence templates, copy guidelines, timing frameworks |
| BC-2591 | seo-audit | 612 | Technical + on-page audit framework. Foundation for all SEO work. AI writing detection reference |

**High (6 skills) — set priority to "High":**

| Issue | Skill | Lines | Why High |
|-------|-------|------:|----------|
| BC-2588 | cold-email | 544 | B2B outreach frameworks, subject line data, follow-up sequences, personalization system |
| BC-2608 | pricing-strategy | 615 | Van Westendorp method, value metrics, tier structure, research methods. Every SaaS needs this |
| BC-2609 | revops | 1,363 | Lead lifecycle, MQL/SQL, scoring models, routing rules. NEEDS Brite adaptation (Salesforce migration) |
| BC-2610 | sales-enablement | 1,455 | RICHEST skill. Deck frameworks, demo scripts, objection library, one-pager templates |
| BC-2595 | competitor-alternatives | 750 | 4 page formats (alt, vs, alts, competitor-vs-competitor). Content architecture for competitor data |
| BC-2601 | churn-prevention | 1,148 | Cancel flow design, dynamic save offers, dunning playbook, payment recovery |

**Medium (8 skills) — keep as "Medium":**

| Issue | Skill | Lines | Notes |
|-------|-------|------:|-------|
| BC-2580 | page-cro | 430 | CRO analysis framework, 8-dimension audit |
| BC-2592 | ai-seo | 835 | AI search optimization — emerging, high-value. Platform ranking factors reference |
| BC-2599 | analytics-tracking | 1,259 | Rich but needs Brite stack adaptation (Snowflake, not GA4-only) |
| BC-2598 | ad-creative | 1,212 | Platform specs, iteration from performance data, angle rotation |
| BC-2597 | paid-ads | 1,042 | Campaign structure, platform selection, naming conventions |
| BC-2590 | social-content | 820 | Platform strategies, hook formulas, content pillars, post templates |
| BC-2604 | marketing-ideas | 533 | 139 ideas library with stage/budget/timeline filtering |
| BC-2605 | marketing-psychology | 455 | Mental models, cognitive biases, ethical persuasion. Unique content |

**Low (13 skills) — set priority to "Low":**

| Issue | Skill | Lines | Notes |
|-------|-------|------:|-------|
| BC-2587 | copy-editing | 841 | Seven Sweeps framework. Secondary to copywriting |
| BC-2593 | programmatic-seo | 546 | 12 playbooks for pages at scale |
| BC-2596 | schema-markup | 577 | JSON-LD examples, schema types |
| BC-2594 | site-architecture | 1,171 | Mermaid templates, navigation patterns |
| BC-2600 | ab-test-setup | 806 | Hypothesis framework, sample size, test types |
| BC-2581 | signup-flow-cro | 359 | Field-by-field optimization |
| BC-2582 | onboarding-cro | 478 | Activation metrics, checklist pattern |
| BC-2583 | form-cro | 429 | Field optimization, multi-step forms |
| BC-2584 | popup-cro | 454 | Trigger strategies, timing |
| BC-2585 | paywall-upgrade-cro | 391 | In-app upgrade screens |
| BC-2602 | free-tool-strategy | 396 | Engineering-as-marketing, tool types |
| BC-2603 | referral-program | 567 | Referral vs affiliate, program design |
| BC-2612 | lead-magnets | 635 | Format guide, benchmarks |

### Task 2.1: Generate enrichment content for each skill

For each of the 33 skill issues, prepare an updated description with this template:

```markdown
## Goal

Port the `{name}` skill from [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) into `plugins/marketing/skills/{name}/`.

**Category:** {category}
**Priority tier:** {Urgent|High|Medium|Low}
**Upstream content:** {total_lines} lines across {file_count} files

## Content Inventory

| File | Lines | Description |
|------|------:|-------------|
| `SKILL.md` | {n} | {brief description} |
| `references/{name}.md` | {n} | {brief description} |
| `evals/evals.json` | {n} | Behavioral test spec |

## Key Frameworks & Value

- {Framework 1}: {what it is and why it matters}
- {Framework 2}: {what it is and why it matters}
- {Framework 3 if applicable}

## Brite-Specific Adaptation Notes

{Any Brite-specific changes needed beyond standard porting, OR "Standard port — no Brite-specific adaptations needed beyond path updates. Product-marketing-context integration handles brand adaptation at runtime."}

## Porting Instructions

Follow [marketing-skill-porting.md](docs/guides/marketing-skill-porting.md) for standard steps.

{Any skill-specific porting notes}

## Quality Requirements

- [ ] SKILL.md follows template format
- [ ] All reference files ported ({list files})
- [ ] Evals ported
- [ ] Health scoring rubric section included
- [ ] Behavioral test spec (minimum Tier 1 free assertions)
- [ ] Anti-slop guardrails section included
- [ ] Cross-skill references updated to Brite plugin paths
- [ ] Depends on `product-marketing-context` foundation skill
- [ ] Registered in `plugins/marketing/.claude-plugin/plugin.json`

## Related Skills

{cross-references from upstream}
```

### Task 2.2: Update Urgent tier issues (6 issues)

Update BC-2586, BC-2611, BC-2606, BC-2607, BC-2589, BC-2591 with enriched descriptions and Urgent priority.

### 🔲 CHECKPOINT: Show Holden the first batch of enriched Urgent issues. Confirm the format and depth before continuing with the remaining 27.

### Task 2.3: Update High tier issues (6 issues)

Update BC-2588, BC-2608, BC-2609, BC-2610, BC-2595, BC-2601.

Skills needing Brite-specific adaptation notes:
- **BC-2609 (revops)**: Brite is migrating HubSpot → Salesforce. Upstream references HubSpot heavily in examples and tool links. Adaptation: update CRM references to Salesforce, note migration context, link to Salesforce CLI tool issue (BC-2655).
- **BC-2601 (churn-prevention)**: Note Brite's billing provider (Stripe) in adaptation notes.

### Task 2.4: Update Medium tier issues (8 issues)

Update BC-2580, BC-2592, BC-2599, BC-2598, BC-2597, BC-2590, BC-2604, BC-2605.

Skills needing Brite-specific adaptation notes:
- **BC-2599 (analytics-tracking)**: Brite uses Snowflake for analytics (not BigQuery — per memory correction). Upstream focuses on GA4/GTM. Adaptation: note Snowflake as data warehouse, keep GA4/GTM content for web analytics layer but add note about Brite's analytics stack.

### Task 2.5: Update Low tier issues (13 issues)

Update BC-2587, BC-2593, BC-2596, BC-2594, BC-2600, BC-2581, BC-2582, BC-2583, BC-2584, BC-2585, BC-2602, BC-2603, BC-2612.

### 🔲 CHECKPOINT: Confirm all 33 skill issues are enriched. Show Holden a summary of all changes made.

---

## Phase 3: Enrich tool issues

### Task 3.1: Enrich 9 remaining tool issues

For each tool issue, update description with:
- What the CLI tool does (key commands)
- What API it wraps
- Connection to parent skill
- Whether it has MCP support in upstream

Tool issues to update:
| Issue | Tool | Parent Skill | MCP in upstream |
|-------|------|-------------|:---:|
| BC-2613 | GA4 | analytics-tracking | ✓ |
| BC-2625 | Resend | email-sequence | ✓ |
| BC-2645 | Semrush | seo-audit | - |
| BC-2653 | Strapi | content-strategy | - |
| BC-2655 | Salesforce | revops | - |
| BC-2664 | Clay | customer-research | ✓ |
| BC-2665 | Stripe | churn-prevention/paywall | ✓ |
| BC-2667 | Calendly | signup-flow-cro | - |
| BC-2683 | Zapier | (standalone) | ✓ |

### 🔲 CHECKPOINT: Show Holden the enriched tool issues. Ask if any tools should be added or removed.

---

## Phase 4: Final verification

### Task 4.1: Generate summary report

Produce a summary showing:
- Total issues: kept, canceled, enriched
- Issues by priority tier
- Issues with Brite-specific adaptation notes
- Any remaining gaps or concerns

### Task 4.2: Update memory

Save a memory entry updating the Marketing Skills Plugin status to reflect the enrichment work.

### 🔲 CHECKPOINT: Final review with Holden. Confirm all work is complete.

---

## Out of scope

- Actually porting any skills (that's the work the enriched issues describe)
- Creating new skill issues (the 33 existing ones cover all 32 upstream skills + product-marketing-context already done)
- Tool stack re-evaluation (done last session — 2026-03-31)
- Writing the actual porting guide content for Brite plugin metadata (filePattern/bashPattern) — that requires understanding the Brite plugin skill injection system, which is documented elsewhere
