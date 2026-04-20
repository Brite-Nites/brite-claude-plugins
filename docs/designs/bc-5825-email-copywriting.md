---
issue: BC-5825
status: approved
drafted: 2026-04-20
author: Holden Halford (brainstorm w/ Claude)
precedent-touched: BC-5824 (inline methodology pattern — extended here with lazy-load per-vertical override files)
follow-ups: BC-5879 (Active fan-out), BC-5880 (Exploring fan-out), BC-5881 (Future fan-out)
---

# BC-5825 Email Copywriting — Design Doc

## Context

Create `plugins/marketing/skills/email-copywriting/SKILL.md` — generates Email Bison-formatted subject + body for step 1 + step 2 from a situation-mining output + offer tier + optional messaging pillars. Emits a JSON artifact consumed by `/marketing:launch-campaign` (BC-5826). Upstream: [Revgrowth1/ai-gtm-workflows workflow 10](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/10-campaign-launch) (MIT).

The BC-5825 issue body specifies Scope, Tool Surface, Cross-Skill Boundaries, JSON schema, 10 tasks (was 9; Task 4 for `presets/README.md` was added during this brainstorm). This design doc captures the **4 decisions not in the issue body** + the preset fan-out split rationale.

## Decisions

### D1. Entity fallback is a hard gate, not a silent default

**Choice:** When `docs/marketing-context.md` is missing or does not identify the Brite entity, the skill PAUSES and asks the operator for explicit entity input. No default entity.

**Why:** Copy quality degrades sharply without entity tone (Nites residential vs Supply commercial vs Labs experiential). Defaulting to one entity silently produces emails that read as entity-mismatched to prospects — worse than a visible pause. Matches situation-mining's ambiguous-name pause pattern: "do not burn the budget on a guess." In this case the budget is copy credibility.

**Implication for plan:** §2 Before Starting documents the marketing-context.md read + gracious-degrade message + entity-input prompt as a hard gate. §6 Operational Runbook includes a dedicated "thin-context fallback" flow that handles the pause.

**Implication for verification:** One Tier-1 behavioral test: "Missing marketing-context.md → skill warns and asks operator for entity explicitly — does NOT silently default."

### D2. Offer-tier selection is recommend + confirm, not auto-select

**Choice:** The skill reads entity + situation confidence + HIGH/MED/LOW signal density, then RECOMMENDS a tier using the issue's entity-aware matrix (Nites→T2, Supply→T3/T4, Labs→T3/T4). Operator confirms or overrides via AskUserQuestion. No auto-select.

**Why:** Offer tier drives the entire email architecture — CTA, proof-point, risk-reversal vs. asset exchange. Wrong tier = wrong email regardless of copy quality. Auto-select removes the operator checkpoint where expertise lives; pure menu-pick shifts cognitive load to every run. Recommend + confirm lets the skill do the pattern-match work while keeping the operator as the decider. Same pattern situation-mining uses for HIGH/MED/LOW confidence assignment.

**Implication for plan:** §3 Methodology encodes the entity-aware tier matrix as a decision rule (inputs → recommended tier). §6 Operational Runbook documents the confirm gate before any drafting begins. §9 Behavioral Tests includes "skill prompts operator before drafting, doesn't default."

### D3. Preset structure = inline base skeletons + lazy-load per-vertical overrides

**Choice:** The 2 base template skeletons (list-building + risk-reversal) live inline in SKILL.md §3 Methodology as entity-agnostic reference shapes. Per-vertical overrides live as separate files under `plugins/marketing/skills/email-copywriting/presets/{preset}-{vertical}.md`. At runtime, the skill reads ONE preset file per invocation (the one matching the operator's supplied vertical). If the file is missing or vertical isn't supplied, skill falls back to base inline + entity tone.

**Why:** Two forces pull opposite ways — (a) inline is the BC-5823/5824 pattern (don't pre-DRY; scope content to the skill that owns it); (b) per-vertical variants are load-bearing for copy tone, and 46 of them inline would bloat SKILL.md past readable. The lazy-load pattern honors BC-5824 D1 (content inline if skill owns it) while bounding runtime context cost — because only ONE preset file loads per invocation, the 46-file library is a disk-space question, not a context-window question. Matches how BC-5823 ports references/research-processes/ as separate files the consumers lazy-load on demand.

**Implication for plan:** §3 Methodology has both base skeletons inline + a "Per-vertical overrides" subsection describing the lazy-load pattern + file path convention. §4 Brite Implementation documents the preset path + fallback behavior. `presets/README.md` is the lazy-load index (all 46 future files listed with Available/Pending status).

**Implication for verification:** One Tier-1 behavioral test: "Unknown vertical → skill falls back to base template + entity tone without halting."

### D4. v0.1 ships 2 seed Municipalities presets; per-vertical fan-out splits into 3 tier-based follow-up issues

**Choice:** BC-5825 ships the skill skeleton + lazy-load infrastructure + `presets/README.md` index + 2 seed preset files (`list-building-municipalities.md`, `risk-reversal-municipalities.md`). The remaining 44 preset files ship in:

- **BC-5879** (High priority) — Active-tier fan-out: 10 files (5 verticals × 2 presets). Created 2026-04-20, blockedBy BC-5825.
- **BC-5880** (Medium priority) — Exploring-tier fan-out: 16 files (8 verticals × 2 presets). Created 2026-04-20, blockedBy BC-5825.
- **BC-5881** (Low priority) — Future-tier fan-out: 18 files (9 verticals × 2 presets). Created 2026-04-20, blockedBy BC-5825.

**Why (tier split):** Tier-based split matches Brite's own GTM confidence levels — Active = mature motion, Future = hypothesis. Within a tier, verticals share activation signals (mature verticals have well-understood recency patterns; speculative verticals share experimental framing). Bundling both preset types per tier lets the author learn the vertical once and write both variants. Each fan-out issue fits the ≤12-task budget: Active = 7 tasks (10 files, 2 files/task + validation), Exploring = 9, Future = 10.

**Why (seed choice):** Municipalities seeds. Reasons: (a) situation-mining already has full worldview + adjacent-offering row for Municipalities — lowest draft burden since source material is already researched, (b) Labs entity anchor lets evals test Labs tone end-to-end, (c) same vertical for both preset types keeps the symmetric "one list-building + one risk-reversal" test pattern clean, (d) BC-5879 then starts with HOAs (Nites entity) to prove entity switching works in the fan-out.

**Why (infrastructure separation):** BC-5826 launch-campaign is blocked by BC-5825's JSON artifact shape, NOT by preset coverage. Once the skill emits valid EB-format JSON with the 2 seed presets, BC-5826 can proceed. Coupling launch-campaign to the full 46-file fan-out would block tonight-critical progress for weeks of preset drafting.

**Why (compound engineering):** BC-5825 is *skeleton* (high-design, low-repetition work); BC-5879/5880/5881 are *skin* (pattern repetition, low inter-dependency — ideal for parallel agent execution per feedback_atomic_issues_for_agents.md). Shipping skeleton + pattern proof (2 seeds) together validates the pattern before fan-out agents replicate it 44 times.

**Implication for plan:** 10 tasks total (see Architecture below). Preset file content lives in a short skeleton-per-file format: frontmatter + Hook + Step 1 + Step 2 + Vertical anti-slop = ~40-60 lines per file.

**Implication for verification:** `presets/README.md` MUST list all 46 future preset files with status ("Available" for the 2 seeds, "Pending BC-5879|BC-5880|BC-5881" for the 44). This gives BC-5879/5880/5881 agents a manifest to check off against.

## Architecture

Standard 9-section template per ADR 2f. Section roles keyed to BC-5825 tasks:

1. **Opener** — "From situation to sent email" framing; one-line outcome for the operator.
2. **Before Starting** — marketing-context check + entity pause (D1) + value-equation input interview when inputs missing + existing situation artifact detection.
3. **Methodology** — EB format rules (non-negotiable), Hormozi value equation, offer tiers + entity-aware selection matrix (D2), recency waterfall, 2 base inline preset skeletons (list-building + risk-reversal), lazy-load pattern for per-vertical overrides (D3).
4. **Brite Implementation** — entity-aware tone conventions, cross-skill boundaries, JSON artifact schema + save path, preset file path convention + fallback behavior.
5. **MCP Tool Reference** — SF MCP availability check pattern (only for `{SENDER_*}` lookup when marketing-context.md doesn't include sender data); Read/Write for artifact + preset reads.
6. **Operational Runbook** — 6 flows: happy path (situation + offer + vertical → copy using preset), scratch path (no situation, value-equation interview), existing-preset path (operator picks base template manually), seed-vertical demo path (Municipalities end-to-end, for docs/dogfood), thin-context fallback (no marketing-context.md, hard gate pause), unknown-vertical fallback (preset file missing, degrade to base + entity tone).
7. **Health Scoring Rubric** — 10 anchored to EB-format compliance + framework application (Hormozi + tier matrix + recency waterfall) + entity-correct tone + source citation on every claim.
8. **Anti-Slop Guardrails** — 4 base + ≥5 skill-specific hard failures: `{{variable}}` ban, `<p>` tag ban, em-dash ban, 2-step-max, `{FIRST_NAME}`-in-subject ban, fact-claim framing ban (inherit from situation-mining).
9. **Behavioral Tests** — ≥6 scenarios covering happy path, scratch path, format violation detection, em-dash detection, entity switching, missing offer tier, missing marketing-context hard gate, unknown-vertical fallback.

## Preset file shape

Every `presets/{preset}-{vertical}.md` file follows this structure (~40-60 lines):

```markdown
---
preset: list-building | risk-reversal
vertical: <handbook-vertical-slug>
entity: brite-nites | brite-labs
when: <one-line trigger: the recency-waterfall signal or RFP keyword that makes this preset fit>
situation_mining_row: <cite SKILL.md §3 row from situation-mining: "Municipalities — RFP mentions smart city" etc>
---

# {preset} | {Vertical} | {Entity}

## Hook (vertical-specific recency waterfall)
<1-2 sentence template with {VARIABLE} slots; spintax where deliverability cadence applies>

## Step 1 skeleton
<Greeting merged with first sentence. Uses {FIRST_NAME_INLINE} not a separate "Hi X,".
Paragraph structure uses <br><br>.
Spintax every 3-5 words where grammar allows.
Body includes: hook + 1 proof-point + 1 {VARIABLE}-driven situation line + CTA.>

## Step 2 bump
<"Re:" prefix subject. Body references step 1 without summarizing it.
Shorter: 1 paragraph typical.
Reinforces offer without repeating pitch.>

## Vertical anti-slop
- <3-5 bullets specific to the vertical — patterns to avoid, buzzwords that would mark the email as generic, entity-mismatched pitches>
```

## Output artifact shape

Per issue body — `docs/campaigns/{entity}/copy-{campaign-name}-{YYYY-MM-DD}.json`. Full JSON schema documented in §4. Key fields:

- `schema_version: "1.0"`
- `entity`: Nites | Supply | Labs
- `template_preset`: list-building | risk-reversal | custom
- `vertical`: nullable — present when a per-vertical preset was used, null when base template
- `offer_tier`: 1–4
- `custom_variables`: array of `{name, default}` for EB `create_custom_variable` downstream
- `step_1` + `step_2`: each with `subject`, `body`, `wait_in_days`
- `situation_mining_source`: path to the input artifact (when present)
- `generated_at`: ISO-8601 timestamp

BC-5826 launch-campaign reads this file directly to produce the EB `sequence_steps` payload.

## Anti-slop gotchas specific to this skill

Beyond the 4 base guardrails, the load-bearing format rules from EB must be hard failures:

1. **`{{variable}}` ban** — uppercase single braces only. If draft contains `{{`, self-correct before emit.
2. **`<p>` tag ban** — body uses `<br><br>` between paragraphs. HTML parsers that eat `<p>` corrupt the greeting-merged pattern.
3. **em-dash ban** — known EB spam trigger. Use commas, periods, hyphens. Self-replace in draft.
4. **2-step max** — sequence arrays with length > 2 are a hard failure.
5. **`{FIRST_NAME}` in subject ban** — subjects are the highest-impact spam signal; merge-field personalization in subjects is worse than generic.
6. **Fact-claim framing (inherit from situation-mining)** — do NOT emit body text that reads as fact when it's a hypothesis. Use hypothesis framing phrases from situation-mining's §3 rule when incorporating inferred signals.

## Open questions carried to the plan

- Spintax generation depth: should the skill emit `{option1|option2|option3}` automatically every 3-5 words, or leave spintax insertion to the operator-review pass? Decide in §3 Methodology.
- `{SENDER_*}` lookup priority: marketing-context.md first or SF MCP first? Probably marketing-context.md since it's the canonical entity data source. Decide in §2 Before Starting.
- How strict should the em-dash auto-replacement be at draft time? Replace all — → commas? Or prompt the operator per occurrence? Decide in §3 anti-slop subsection.

These are local SKILL.md authoring decisions — document the choice in the relevant section when writing. Not blocking for the plan.

## References

- BC-5825 Linear issue (narrowed scope as of 2026-04-20)
- BC-5879, BC-5880, BC-5881 Linear issues (preset fan-out follow-ups)
- `docs/plans/marketing-gtm-expansion.md` §1.3
- `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — 9-section scaffold (ADR 2f)
- `plugins/marketing/skills/situation-mining/SKILL.md` — shipped BC-5824 exemplar + input artifact shape
- `plugins/marketing/skills/campaign-orchestration/SKILL.md` — shipped BC-2718 sequence-mechanics context
- `plugins/marketing/tools/integrations/email-bison.md` — EB-format rules source
- `docs/precedents/BC-5824.md` — handbook-canon-first + inline methodology precedents
- [Revgrowth1/ai-gtm-workflows workflow 10](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/10-campaign-launch) (MIT) — upstream messaging framework
- `memory/MEMORY.md` — Brite entity canon, EB format precedents
