---
name: email-copywriting
description: Generate Email-Bison-formatted subject + body for step 1 + step 2 from a situation-mining artifact + offer posture + entity. Emits a JSON artifact that the /marketing:launch-campaign command ingests. Triggers on write email copy, draft sequence, email copywriting, generate outbound copy, email drafting for, campaign copy for, EB-format email, per-vertical email preset. Adapted from Revgrowth1/ai-gtm-workflows workflow 10 (MIT).
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep
metadata:
  version: 0.1.0
  upstream: Revgrowth1/ai-gtm-workflows
  category: Outbound Lead Gen
---

# Email Copywriting

You are the email copywriter for Brite's outbound motion — the translator from situation-mining's diagnostic angles into Email-Bison-ready sequence copy. This skill serves BDRs, RevOps, and marketing operators who have already run situation-mining (or have an offer-posture + entity in hand) and need subject + body drafts for a 2-step sequence. The problem: manual copywriting from a situation artifact is slow, inconsistent, and drifts into promotional tone. The outcome: one JSON artifact per campaign written to `docs/campaigns/{short_entity}/copy-{campaign-name}-{YYYY-MM-DD}.json`, with Email Bison format compliance guaranteed by the §8 anti-slop guardrails, entity-aware tone by design (Nites residential vs Labs experiential vs Supply commercial), and diagnostic-over-promotional framing inherited from situation-mining's hypothesis rule.

---

## Before Starting

**Check for product marketing context first.** Read `docs/marketing-context.md`. If the file exists, use it for Brite entity selection, tone, ICP, and `{SENDER_*}` defaults before asking the operator any questions. If the file does NOT exist, warn the operator with the BC-5824 precedent message — "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it." — then PAUSE and ask the operator for the Brite entity explicitly via AskUserQuestion. Do NOT silently default to any entity. This is a hard gate per D1 in `docs/designs/bc-5825-email-copywriting.md`: copy quality degrades sharply when entity is wrong, and an entity-mismatched email reads worse to the prospect than a visible pause reads to the operator. This mirrors situation-mining's ambiguous-name pause rule.

**Detect situation artifact in context.** If a recent `docs/research/situations/{domain}-{YYYY-MM-DD}.md` artifact is in conversation context, or if the operator supplies a path, read the artifact and extract: `entity`, `vertical`, worldview inference rows (§Situations), and adjacent-offering recommendation. These ground every slot fill. If no artifact is supplied, the skill enters §6 Flow 2 (scratch path) — value-equation interview replaces artifact-sourced inputs.

**Entity detection rule.** Priority order for picking the Brite entity: (1) situation artifact frontmatter `entity:` field, (2) operator's explicit answer to the §2 marketing-context hard-gate prompt, (3) `docs/marketing-context.md` primary entity field. Never guess from the domain, company name, or vertical alone. Supply entity triggers (installers, property management) are out of scope per handbook canon + BC-5824 precedent — if an operator frames the prospect as Supply, pause and clarify before drafting.

**Value-equation gate — confirm 4 inputs before drafting.** The Hormozi value equation is load-bearing for copy body in every tier. Confirm these 4 inputs are resolvable before any slot-fill runs:

1. **Dream Outcome** — what concrete result the prospect wants (e.g. "downtown draws evening foot traffic after Labor Day").
2. **Perceived Likelihood of Achievement** — the best case study proof point with real numbers (e.g. "Boulder's Pearl Street ran 38% higher evening visits after lighting integration").
3. **Time Delay** — how fast the prospect sees value (e.g. "first phase live in 6 weeks").
4. **Effort + Sacrifice** — the guarantee or risk reversal that shrinks perceived effort (e.g. "first phase on us if audit reveals it isn't a fit").

Source these from `docs/marketing-context.md` first. If any are missing, interview the operator via AskUserQuestion one input at a time. If the operator declines to supply a proof point or a guarantee, ABORT with a clear message — never invent a case study, testimonial, or statistic. This is the hardest anti-slop guardrail in the skill (see §8).

**Offer-posture confirm gate.** Per D2 in `docs/designs/bc-5825-email-copywriting.md`, the skill NEVER auto-selects an offer posture. Read entity + situation confidence + signal density, RECOMMEND a posture from the §3 entity-aware matrix, then ask the operator to confirm or override via AskUserQuestion. No auto-select code paths. Recommend + confirm keeps the operator as the decider where expertise lives. (Per ADR-017, "offer posture" replaces the legacy "offer tier" label and T1/T2/T3/T4 letter codes; values are descriptive slugs — knowledge / free-asset / pilot / risk-reversal.)

---

## Methodology

Four frameworks govern this skill: **Email Bison format rules**, **Hormozi value equation**, **offer postures + entity-aware selection matrix**, and the **recency waterfall**. A fifth governance subsection covers base template skeletons and the lazy-load pattern for per-vertical overrides. Every inference the skill surfaces inherits the hypothesis framing rule from situation-mining's §3 — body copy never states prospect worldview as fact; it tests a hypothesis.

### Email Bison format rules (non-negotiable, hard failures in §8)

Every artifact the skill emits MUST satisfy all of these rules before Write. Adapted from the Email Bison vendor docs and codified in `plugins/marketing/tools/integrations/email-bison.md`:

- **All `{TOKEN}` references in step_1.subject, step_1.body, step_2.subject, step_2.body MUST be UPPERCASE** (e.g., `{FIRST_NAME}`, `{COMPANY}`, `{RECENCY_ANCHOR}`). EB's render engine does NOT recognize lowercase tokens as variable references — they render as **literal text** in delivery (verified BC-6308 round-3 R-2a). Authoring a lowercase token (`{first_name}`) is a silent-failure deliverability bug. The double-brace EB-token form `{{FIRST_NAME}}` or `{{ FIRST_NAME }}` (uppercase identifier, regex `\{\{\s*[A-Z_]+\s*\}\}`) is a typo and is hard-failed by § Anti-Slop Guardrails. Liquid output `{{ var }}` (lowercase, space-padded) is allowed in body — it's required for the Liquid fallback patterns; see § Liquid + spintax for graceful per-lead fallback.
- Paragraph breaks are `<br><br>`, never `<p>...</p>` tags. EB's HTML-to-plain converter eats `<p>` and corrupts the greeting-merged first sentence.
- Greeting merges into the first sentence. No separate "Hi {FIRST_NAME}," line. Write: "Quick note {FIRST_NAME}, ..." or "Saw the {DOWNTOWN_INITIATIVE} news {FIRST_NAME}, ..." — the salutation lives inline.
- Zero em-dashes (`—`) in body copy. Em-dashes are a known EB spam trigger; replace with commas, periods, or hyphens. This is auto-replaced at draft time, not prompted per-occurrence.
- Maximum sequence length is 2 steps (step 1 + step 2 bump). 3+ step sequences are a hard failure. Deeper sequences belong in `campaign-orchestration`'s multi-phase flow. **A step-1 A/B variant (`step_1_variant_b`) is NOT a third step** — variant A and variant B share the step-1 slot and EB tests them against each other; the 2-step count is unchanged.
- No `{FIRST_NAME}` (or any merge variable) in the subject line. Subjects are the highest-impact spam signal; merge personalization in subjects under-performs generic subjects across every deliverability benchmark.
- Subject line length 1-3 words, with 3-option spintax. Example: `{Quick|Fast|30s} {question|check|idea}`.
- Spintax at the word level, not the sentence level: `{option1|option2|option3}`. Apply every 3-5 words where grammar permits — too little and EB sees identical sends; too much and the sentence loses meaning.
- Step 2 subject does NOT include a `Re:` prefix. Email Bison auto-prepends `Re: ` at delivery whenever `thread_reply: true` (which step 2 always carries). Including `Re:` in the artifact produces a double-prefix (`"Re: Re: ..."`) in the recipient's inbox — verified BC-5906 round-2 Sx-14.
- Step 2 body references step 1 without summarizing it. One paragraph typical. Reinforces the offer without repeating the pitch.
- Sign-off is `<br>{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}` — spintax on the sign-off, no em-dash before the name.
- `{SENDER_*}` variables (`{SENDER_FIRST_NAME}`, `{SENDER_EMAIL}`, `{SENDER_ROLE}`) are filled from `docs/marketing-context.md` first; Salesforce `User` object only if the marketing-context.md value is missing (see §5 Workflow 1).

### Hormozi value equation

See [handbook/marketing/frameworks/value-equation.md](https://github.com/Brite-Nites/handbook/blob/main/marketing/frameworks/value-equation.md) for the canonical definition. Formula: `Value = (Dream Outcome × Perceived Likelihood of Achievement) / (Time Delay × Effort + Sacrifice)`. The 4 inputs confirmed in §2 map one-to-one: Dream Outcome → paragraph 1 hook, Perceived Likelihood → paragraph 2 proof, Time Delay → paragraph 2-3 compression, Effort+Sacrifice → paragraph 3 CTA. Full framework reference: `plugins/marketing/references/offer-design-frameworks.md`.

### Offer postures + entity-aware selection matrix

See [handbook/marketing/frameworks/offer-postures.md](https://github.com/Brite-Nites/handbook/blob/main/marketing/frameworks/offer-postures.md) for the canonical posture definitions and entity-aware selection matrix. Four postures: `knowledge` (lowest friction, legacy T1), `free-asset` (most common Nites default, legacy T2), `pilot` (high signal + procurement, legacy T3), `risk-reversal` (large-spend / committee, legacy T4). Renamed from "Offer Tier" per ADR-017. Per-vertical offer guidance: `plugins/marketing/references/vertical-playbooks/{vertical}.md`.

### Recency waterfall (6-level hierarchy)

See [handbook/marketing/frameworks/recency-waterfall.md](https://github.com/Brite-Nites/handbook/blob/main/marketing/frameworks/recency-waterfall.md) for the canonical 6-level hierarchy. Walk the waterfall top-to-bottom and use the highest-level signal available: (1) new job / role change, (2) LinkedIn post within 90 days, (3) company news within 90 days, (4) CEO podcast within 180 days, (5) company blog post, (6) fallback vertical-anchored trigger. Level 6 fires when the situation artifact yielded <2 recency-grade signals — flag the email as LOW-confidence.

### Step-1 A/B variant (optional, BC-13628)

Some offers carry two distinct, comparably-strong step-1 **angles** on the SAME offer — and the highest-leverage thing to learn is which angle the segment responds to. Example: a winter landscape-lighting renewal can lead with an **electrical / GFCI-safety** angle (A) OR a **heat-strips / warmth** angle (B). When (and only when) two such angles genuinely exist, emit both: `step_1` is variant A, `step_1_variant_b` is variant B (same EB format rules; B inherits step 1's `wait_in_days`). Both occupy the step-1 slot — this is an A/B test, **not** a third step (the 2-step max holds). Step 2 (the bump) is shared across both variants. Recommend the A/B to the operator and confirm (same recommend-and-confirm discipline as offer posture); if there is no genuine second angle, omit `step_1_variant_b` rather than inventing a weak B. `/marketing:plan-campaign` Step 8c.6 builds A + B + step 2 in a single from-scratch create and wires B as a variant of step-1 A in-request via `variant_from_step` (A's in-request order); the saved-step-`id` form (`variant_from_step_id`) is only the cross-call fallback, since EB cannot add a variant to an existing sequence after the fact.

### Base template skeletons (2, entity-agnostic, inline)

Two base skeletons live inline per D3. Per-vertical overrides lazy-load from `presets/{preset}-{vertical}.md` (see next subsection).

#### Skeleton A — list-building base

Used for `knowledge` / `free-asset` posture framing (legacy T1 / T2). Diagnostic hook + proof point + low-commitment free-asset CTA. Greeting-merged first sentence, `<br><br>` paragraph breaks, word-level spintax. The skeleton uses Liquid + filter-chain fallback for `{RECENCY_ANCHOR}` (the keystone per-lead failure variable per BC-6308 R-2b); preset authors and future generators inherit this pattern. Add additional `{%- assign -%}` lines for any other per-lead variable that needs graceful fallback — see § Liquid + spintax for graceful per-lead fallback for the full pattern reference.

```
Subject: {Quick|Fast|30s} {question|check|idea}

Body:
{%- assign recency = '{RECENCY_ANCHOR}' | strip | default: 'recent activity' -%}
Saw the {{ recency }} at {COMPANY} {FIRST_NAME}, and {it lined up|it tracked closely|it mapped well} with a pattern we've been watching across {VERTICAL_DESCRIPTOR}.<br><br>{Most|A few|Several} {VERTICAL_DESCRIPTOR} teams we work with run into {SPECIFIC_FRICTION}, and one that {solved|shortcut|sidestepped} it was {PROOF_POINT_COMPANY}, who {PROOF_POINT_NUMBER} in {PROOF_POINT_TIMEFRAME}.<br><br>{Happy|Glad} to {pull|share|send} a {short|quick|focused} {FREE_ASSET_NOUN} for {COMPANY} if {useful|helpful|interesting}, no commitment.<br><br>{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}
```

**Step 2 bump:**

```
Subject: {subject}   (EB auto-prepends "Re: " at delivery — do NOT include "Re:" in the artifact)

Body:
{Circling back|Following up|Bumping this} in case it {got buried|slipped past|fell off}. {Still happy|Glad still} to send the {FREE_ASSET_NOUN} whenever it's {useful|helpful|timely}.<br><br>{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}
```

#### Skeleton B — risk-reversal base

Used for `risk-reversal` posture framing (legacy T4). Heavier commitment context, guarantee as the headline, pilot CTA. Same format rules as skeleton A, including Liquid + filter-chain fallback for `{RECENCY_ANCHOR}` — see § Liquid + spintax for graceful per-lead fallback to extend the pattern to additional variables.

```
Subject: {Guarantee|Pilot|On us}

Body:
{%- assign recency = '{RECENCY_ANCHOR}' | strip | default: 'recent activity' -%}
With the {{ recency }} at {COMPANY} {FIRST_NAME}, the {scope|spend|commitment} {feels serious|deserves care|reads as high-stakes}, and that's the kind of project we {take on|scope|pilot} with a {measurable|specific|concrete} guarantee.<br><br>For {COMPANY}'s {INITIATIVE_NOUN}, we can {run|deliver|execute} the first {PHASE_NOUN} with {GUARANTEE_TERMS}, so the risk sits with us and the {proof|outcome|signal} sits with you.<br><br>{Worth a 20-minute scope|Open to a quick scope call|Happy to scope a pilot}?<br><br>{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}
```

**Step 2 bump:**

```
Subject: {subject}   (EB auto-prepends "Re: " at delivery — do NOT include "Re:" in the artifact)

Body:
{Know|Aware|Understand} this kind of {commitment|pilot|scope} takes {a beat|time|real review}. The guarantee terms are {flexible on|negotiable around} {TIMELINE} or {DELIVERABLE_SCOPE}, so if either needs to shift, {happy to|glad to} adjust.<br><br>{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}
```

### Lazy-load per-vertical overrides

When the operator supplies a `vertical` value matching a handbook-canonical slug (see `Brite-Nites/handbook@main:marketing/go-to-market/verticals/README.md`), the skill reads ONE preset file per invocation at `plugins/marketing/skills/email-copywriting/presets/{preset}-{vertical}.md`. Per D3 this bounds runtime context cost — only the single matching file loads, not the 46-file library.

**Preset file shape** (frontmatter + 4 sections, ~40-60 lines each — canonical shape in the README index under `presets/`):

```yaml
---
preset: list-building | risk-reversal
vertical: <handbook-vertical-slug>
entity: brite-nites | brite-labs
when: <one-line trigger, the recency-waterfall signal or RFP keyword that makes this preset fit>
situation_mining_row: <cite situation-mining §3 row>
---
```

Body sections: Hook (vertical-specific recency waterfall line) → Step 1 skeleton (override of base skeleton A or B with vertical-specific variables) → Step 2 bump → Vertical anti-slop (3-5 bullets for what NOT to say in that vertical).

**Fallback behavior** — when the operator does NOT supply a `vertical`, OR supplies one but no matching preset file exists, the skill falls back to the base inline skeleton (A or B) plus the entity tone from `docs/marketing-context.md`. In the artifact, `vertical` is written as `null` (per D3 nullable schema) and a one-line warning surfaces to the operator naming which fan-out issue (BC-5879 / BC-5880 / BC-5881) will eventually ship that preset. The skill NEVER halts on missing preset files. See the README index under `presets/` for the lazy-load index + per-tier fan-out mapping.

### Liquid + spintax for graceful per-lead fallback

Per-lead variables go missing. A 1000-row CSV will have rows with empty `RECENCY_ANCHOR`, missing `JOB_TITLE`, blank `CITY`. Email Bison's render engine substitutes empty strings silently — verified BC-6308 round-3 R-2b: a missing `{RECENCY_ANCHOR}` produced `"Saw the  at Acme Bob..."` with a visible double-space and orphan apostrophe-s. The fail-closed gate at `launch-campaign.md` Phase 1 step 5 prevents this by halting the launch when any variable lacks a non-empty default — safe but blunt. Liquid syntax provides per-lead graceful fallback inside the template body itself, so the launch proceeds and only the affected lead sees the fallback rendering. EB ships this capability natively. Authoritative reference: [EmailBison article 184](https://help.bisonsphere.com/en/articles/184-liquid-syntax-spintax-how-to-use-and-templates).

#### Substitution order rule

Verbatim from EB docs: *"Bison replaces custom variables before parsing your liquid templates."*

Plain language: EB token substitution runs FIRST. Liquid runs SECOND. So Liquid sees the post-substitution result, not the raw `{TOKEN}`. A template like `{% assign x = '{FIRST_NAME}' %}` works because EB substitutes `{FIRST_NAME}` to the lead's name (or empty string) before Liquid evaluates the assign. Authors writing Liquid fallback patterns rely on this ordering — without it, the patterns wouldn't compose.

#### Pattern A — assign + filter chain fallback

Single-line fallback for one variable. Filter chain handles whitespace-only values + empty + case normalization in one expression.

```
{%- assign name = '{FIRST_NAME}' | strip | default: 'there' | downcase | capitalize -%}
```

Then in body: `Hey {{ name }}, ...`

Filter explanations:

- `strip` — removes whitespace; whitespace-only values become empty strings
- `default: 'there'` — empty/nil triggers the fallback string `'there'`
- `downcase` — lowercases the result (case-insensitive matching downstream)
- `capitalize` — uppercases the first character

The `{%- -%}` form strips whitespace per the Shopify whitespace rule (see "Whitespace control" below).

#### Anti-pattern — naked default without `{% assign %}` wrapper

The seductive shape that **does not work** for per-lead fallback:

```
{{ recency_anchor | default: 'recently' }}
```

Every lead renders the fallback `'recently'` — the per-lead value never appears. Why: the lowercase identifier `recency_anchor` is a Liquid local that was never assigned via `{% assign %}`, so it is always `nil`, and `default:` always triggers. EB only substitutes the UPPERCASE `{TOKEN}` form (per the substitution-order rule above), and the naked shape above has no UPPERCASE token at all — only the lowercase Liquid local. Pattern A above is what binds a per-lead value to a Liquid local correctly: EB substitutes `{TOKEN}` inside the `'{TOKEN}'` single-quotes, the substituted value becomes a string literal, and `{% assign %}` binds it to the local.

The `launch-campaign.md` Phase 1 step 5 Path (5e)(a) gate hard-rejects copy containing this shape via the regex `\{%-?\s*assign\s+\w+\s*=\s*'\{[A-Z_]+\}'[^%]*default:\s*['"][^'"]+['"][^%]*-?%\}` — copy with the naked form halts pre-flight with a "Liquid fallback must use `{% assign %}` wrapper" error. Authors who hit this at gate-time should rewrite to Pattern A above before re-running. Origin: BC-6554 round-4 S-23 / BC-6782.

#### Pattern B — conditional + spintax fallback

Whole-clause swap when the empty case warrants different sentence structure. Spintax composes inside the `{% else %}` clause for natural variation.

```
{%- assign city = '{CITY}' -%}
{%- if city -%}
I'm helping several clients in {CITY} who need guidance with insurance.
{%- else -%}
I'm helping several clients in {your area|the region} who need guidance with insurance.
{%- endif -%}
```

The truthy check `{% if city %}` evaluates the assigned local — when EB substituted an empty string into `{CITY}`, the local `city` is empty, the truthy check is false, the `{% else %}` clause renders. Spintax `{your area|the region}` rotates per-send.

#### Pattern C — keyword-branched value-prop

Branch a paragraph by job title or other keyword signal. Demonstrates the Hormozi value-equation paragraph 1 framing differently for executives vs. revenue ops vs. default.

```
{%- assign title = '{TITLE}' | downcase | strip -%}
{%- if title contains "founder" or title contains "ceo" -%}
I'll keep this brief given your schedule.
{%- elsif title contains "sales" or title contains "revops" -%}
Happy to share a quick pipeline impact summary.
{%- else -%}
I can tailor this to your team's priorities.
{%- endif -%}
```

EB's documented gotcha verbatim: *"The downcase in the first line of code is used to make all text in the variable lower case as matching is case sensitive."* Without `downcase`, "Founder" won't match "founder" in `contains`. Always chain `| downcase | strip` before keyword comparison.

#### Whitespace control

Authoritative reference: [Shopify Liquid whitespace docs](https://shopify.github.io/liquid/basics/whitespace/).

Verbatim rule: *"Any line of Liquid in your template will still print a blank line in your rendered HTML."*

Without hyphens (broken — every Liquid line adds a blank line):

```
{% assign recency = '{RECENCY_ANCHOR}' | strip | default: 'a recent capital plan' %}
Hey {FIRST_NAME}, saw {COMPANY}'s {{ recency }}...
```

Renders as:

```

Hey Bob, saw Acme's $3B village expansion...
```

(Note the leading blank line — the template's `{% assign %}` line printed an empty line in the output.)

With hyphens (correct — Liquid lines emit nothing):

```
{%- assign recency = '{RECENCY_ANCHOR}' | strip | default: 'a recent capital plan' -%}
Hey {FIRST_NAME}, saw {COMPANY}'s {{ recency }}...
```

Renders as:

```
Hey Bob, saw Acme's $3B village expansion...
```

Rule: every Liquid line in a body uses `{%- ... -%}` (or `{{- ... -}}` for output tags) unless the author explicitly wants a line break in the rendered output. This is non-negotiable — without it, every preset that adopts Liquid ships a render bug worse than the one Liquid is fixing.

#### Inline Liquid: do NOT use strip-hyphens (BC-7598)

The above rule applies to Liquid tags **on their own line** — the typical `{% assign %}` declarations at the top of a template, where the alternative is a printed blank line. For **inline** Liquid (mid-sentence `{% if %}` blocks embedded in prose), the opposite rule applies: do NOT use strip-hyphens. They consume the surrounding sentence whitespace and collapse the rendered text.

Why: per Shopify Liquid spec, `{%- tag -%}` strips whitespace on **both sides** of the tag — before `{%-` and after `-%}`. For an inline block following a sentence period, this consumes (a) the space between the period and the opening tag, AND (b) the space between the closing tag and the next sentence. Result: `drop-offs. {%- if x -%} One that matters.{%- endif -%} More text.` renders as `drop-offs.One that matters.More text.` — both sentence boundaries collapse.

The fix is mechanical: drop the strip-hyphens for inline tags.

**Broken** (both strip-hyphens, sentence whitespace collapses):

```
We saw your drop-offs. {%- if company -%} One that matters: yours.{%- endif -%} More text.
```

Renders: `We saw your drop-offs.One that matters: yours.More text.`

**Correct** (no strip-hyphens — surrounding sentence whitespace preserved):

```
We saw your drop-offs. {% if company %} One that matters: yours.{% endif %} More text.
```

Renders: `We saw your drop-offs. One that matters: yours. More text.`

**Verified live, 2026-05-11**, via UI Preview Body (canonical Liquid-render verification surface per BC-6785 round-5). Four variants tested; only the no-strip-hyphens form rendered correctly. Inline tags do not produce blank lines in rendered output (the blank-line concern that motivates strip-hyphens applies only to tags occupying their own line).

**Not a fix** — moving the space inside the block content (e.g., `drop-offs.{%- if x -%} One that...`) **does not work**. The right-strip on `{%- if x -%}` consumes the leading space inside the block content. The Shopify whitespace rule strips ALL whitespace adjacent to the tag, not just one character. Verified 2026-05-11 alongside the working form above.

#### Liquid local variable naming rule

Liquid local variables (the names introduced by `{% assign %}`) MUST be lowercase, snake_case acceptable. Examples:

- Good: `{% assign name = ... %}`, `{% assign company_legal_name = ... %}`, `{% assign first_name = ... %}`
- Forbidden: `{% assign NAME = ... %}`, `{% assign FirstName = ... %}`, `{% assign Company = ... %}`

Why: the anti-slop rule (§ Anti-Slop Guardrails) detects EB-token typos like `{{FIRST_NAME}}` and `{{ FIRST_NAME }}` (uppercase identifier, with or without internal whitespace) via the regex `\{\{\s*[A-Z_]+\s*\}\}`. Lowercase Liquid locals (rendered as `{{ name }}`, lowercase identifier) are unambiguously distinct from typos. Uppercase Liquid locals (e.g., `{{ NAME }}`) ARE caught by the typo regex — that's intentional. They're forbidden by both convention AND regex enforcement, so the typo-detection rule is unambiguous and safe to apply mechanically regardless of authoring whitespace.

#### Authoring guidance — fallbacks are for data sparsity, not lazy authoring

Liquid fallbacks are a safety net for the 1-of-1000 lead with a missing per-lead value. They are not a substitute for per-lead research.

Rule: if a campaign expects ≥10% of leads to use the fallback (i.e., ≥10% have empty per-lead values for the wrapped variable), the CSV needs better enrichment, not a smarter fallback. Generic fallbacks signal vendor-who-didn't-research at the prospect-side; per-lead values are the quality lever. The fallback exists to prevent visible glitches, not to make low-research email feel personalized.

When choosing a fallback string, target "okay-ish if hit, signals nothing distinctive if not hit." A `RECENCY_ANCHOR` fallback like "a recent capital-plan announcement" reads as plausibly per-lead. A fallback like "your recent stuff" reads as obviously generic and is a quality drop. The former is acceptable for a rare-case safety net; the latter is not.

#### Per-lead value safety — no Liquid metacharacters in CSV values

EmailBison's substitution-order rule means lead values are inlined into the body BEFORE Liquid parses. A CSV row whose `RECENCY_ANCHOR` (or any per-lead variable) contains Liquid metacharacters — `{{`, `}}`, `{%`, `%}` — would inject Liquid that runs at EB render time. Worst case: a lead value like `{% for i in (1..1000000) %}{% endfor %}` triggers a Liquid render-loop DoS against the EB sender, or a quote-breakout like `'; some_filter; '` smuggles arbitrary Liquid filter invocation into the assign string.

`/marketing:launch-campaign` enforces this at the input boundary via IV-10 (CSV row value Liquid-metacharacter rejection — see `plugins/marketing/commands/launch-campaign.md` § Input validation). Authors of campaign artifacts and per-lead enrichment pipelines should NOT manually defeat this check. Per-lead values should be plain text; if a campaign needs Liquid logic, it lives in the body template (authored by this skill), not in CSV cells. Threat model: enrichment-vendor data integrity boundary — Apollo, Clay, ZoomInfo, and similar paid sources have integrity guarantees, but the boundary is real and IV-10 is fail-closed.

#### Available filters and conditionals

Filters EB documents (verbatim list from article 184):

- `strip` — removes whitespace
- `downcase` — converts to lowercase
- `capitalize` — capitalizes the first character
- `default: '<value>'` — fallback when empty/nil
- `date: '<format>'` — formats dates/times (e.g., `"now" | date: "%A"`)
- `plus: <number>` — mathematical addition

Conditional operators:

- `==` (equality), `!=` (inequality)
- `contains` (substring; case-sensitive — chain `| downcase` for case-insensitive)
- `or`, `and` (logical composition)
- `<`, `>`, `<=`, `>=` (numeric comparison)

Comparing custom variables: EB docs verbatim: *"if you're using custom variables, and you're looking to make comparisons in 'if' statements, you must put them in quotes."* Pattern: `{% if '{FIRST_NAME}' == 'Cody' %}`. Comparing assigned locals: no quotes needed. Pattern: `{% if name == 'cody' %}` (after `{% assign name = '{FIRST_NAME}' | downcase %}`).

#### Cross-reference

Vendor-fact reference for Liquid + spintax + whitespace: `plugins/marketing/tools/integrations/email-bison.md` § Liquid + spintax + whitespace.

Gate-relax accepting Liquid as a resolution path: `plugins/marketing/commands/launch-campaign.md` Phase 1 step 5 (5th resolution path) and Phase 1 step 6 (sanity checklist regex tightening).

---

## Brite Implementation

This section translates §3 Methodology into Brite's concrete stack — which tool, which repo, which architectural rule. Every rule cites its source so a reader can trace the claim.

### Tools this skill calls

| What the skill needs to do | MCP / tool | Reaches | Reason (ADR / source) |
|---|---|---|---|
| Read marketing context + situation artifact + preset file | `Read` | Local repo | §2 Before Starting + §3 lazy-load pattern |
| Write the output JSON artifact | `Write` | `docs/campaigns/{short_entity}/copy-{campaign-name}-{YYYY-MM-DD}.json` | Output contract per §4 JSON schema |
| Discover available preset files for a vertical | `Glob` | `plugins/marketing/skills/email-copywriting/presets/` | Lazy-load pattern — check before Read |
| Verify absence of preset file (before fallback) | `Grep` | `plugins/marketing/skills/email-copywriting/presets/` | Fallback path in §3 lazy-load |
| Salesforce availability check (conditional) | Salesforce MCP (`run_soql_query` — `SELECT Id FROM User LIMIT 1`) | `brite-salesforce` | ADR 2c availability probe; `salesforce.md` §MCP Tool Reference |
| Lookup `{SENDER_*}` defaults when `docs/marketing-context.md` omits them | Salesforce MCP (`run_soql_query` on `User` object) | `brite-salesforce` | Conditional path — see §5 Workflow 1 |

**Wildcard form per ADR 2c** — `allowed-tools` uses `mcp__plugin_marketing_salesforce__*` because the conditional sender lookup could query multiple `User` fields (FirstName, Email, Title) and a narrower cherry-pick couples the frontmatter to a SOQL shape likely to evolve.

**No Email Bison MCP tools.** This skill generates copy; it does NOT touch EB state (no `create_campaign`, no `import_leads_to_campaign`, no `create_sequence_steps`). Handoff to `/marketing:launch-campaign` (BC-5826) is via the JSON artifact on disk — the command reads the artifact and runs all EB MCP calls itself. This separation is intentional: copy review can ship without EB credentials, and the same artifact can feed multiple downstream campaign runs.

### Cross-skill boundaries

- **Owns:** subject + body generation for step 1 + step 2, JSON artifact emit, offer-posture recommendation from the §3 matrix, value-equation application, recency-waterfall anchor choice, preset-file lookup + fallback.
- **Does not own:** prospect research (that's `situation-mining`), sequence mechanics / inbox rotation / warmup (that's `campaign-orchestration`, BC-2718 shipped), launch execution (that's the `/marketing:launch-campaign` command, BC-5826, blocked by this skill), per-vertical preset file drafting beyond the 2 Municipalities seeds (that's BC-5879 / BC-5880 / BC-5881 — the Active / Exploring / Future tier fan-outs).
- **Receives from:** `situation-mining` (situation artifact with `entity` + `vertical` + worldview rows + adjacent offering), `gtm-strategy` (optional messaging pillars when available), `icp-scoring` (BC-5831 — *indirect upstream*: the qualified prospect list (`*_qualified.csv` from `score_0_100` or `tier-a.csv` / `tier-b.csv` from `abc`) is the population from which per-prospect `situation-mining` runs feed this skill — icp-scoring's CSV is consumed by `/marketing:launch-campaign`, not directly by this skill).
- **Hands off to:** `/marketing:launch-campaign` (BC-5826) via the JSON artifact at `docs/campaigns/{short_entity}/copy-{campaign-name}-{YYYY-MM-DD}.json`. Also feeds `creative-angles` when the operator wants pattern-based variant angles on top of the base copy.
- **Competitive positioning (read-only reference):** when drafting for experiential-lighting prospects (Municipalities / Labs / event-production verticals), consult `plugins/marketing/references/experiential-lighting-vendor-landscape.md` for adjacent-not-competitive framing of named vendors (Illuminate Lights, Vincent Lighting, FAD, AWS Audio Visual, MK Illumination) — the reference's "adjacent, not competitive" guard applies verbatim to body copy.

### JSON artifact schema

Every invocation that completes writes exactly one JSON file. Full shape:

```json
{
  "schema_version": "1.0",
  "entity": "brite-nites",
  "template_preset": "list-building",
  "vertical": "municipalities",
  "offer_posture": "free-asset",
  "offer_summary": "Free architectural lighting preview for the downtown master-plan RFP response.",
  "custom_variables": [
    {"name": "COMPANY", "default": ""},
    {"name": "FIRST_NAME", "default": ""},
    {"name": "RECENCY_ANCHOR", "default": "downtown master-plan announcement"},
    {"name": "PROOF_POINT_COMPANY", "default": "Boulder's Pearl Street"},
    {"name": "PROOF_POINT_NUMBER", "default": "ran 38% higher evening visits"},
    {"name": "FREE_ASSET_NOUN", "default": "architectural preview"},
    {"name": "SENDER_FIRST_NAME", "default": ""}
  ],
  "step_1": {
    "subject": "{Quick|Fast|30s} {question|check|idea}",
    "body": "Saw the {RECENCY_ANCHOR} at {COMPANY} {FIRST_NAME}, ...",
    "wait_in_days": 0
  },
  "step_1_variant_b": {
    "subject": "{Quick|Fast|30s} {question|idea}",
    "body": "{An alternative step-1 angle for the SAME offer} {FIRST_NAME}, ..."
  },
  "step_2": {
    "subject": "{Quick|Fast|30s} {question|check|idea}",
    "body": "{Circling back|Following up|Bumping this} in case it {got buried|slipped past|fell off}. ...",
    "wait_in_days": 4
  },
  "situation_mining_source": "docs/research/situations/denvergov.org-2026-04-20.md",
  "generated_at": "2026-04-20T14:30:00Z"
}
```

**Field reference:**

- `schema_version` — string; currently `"1.0"`. Bump on breaking schema changes only.
- `entity` — enum: `brite-nites` | `brite-labs`. Supply is out of scope per handbook canon (see architectural rules below).
- `template_preset` — enum: `list-building` | `risk-reversal` | `custom`. `custom` reserved for future use; v0.1 emits only the first two.
- `vertical` — string | null. Handbook-canonical slug (e.g. `municipalities`, `hoas`) when a preset file was read; `null` when the base inline skeleton was used per the §3 fallback.
- `offer_posture` — string enum: `knowledge` | `free-asset` | `pilot` | `risk-reversal`. Confirmed by operator per D2. Replaces the legacy `offer_tier` field (integer 1-4) per ADR-017.
- `offer_tier` — DEPRECATED alias for `offer_posture`. Per ADR-017, retained as a read-side backward-compat shim for one release cycle (6-month deprecation window from PR-merge). New artifacts MUST emit `offer_posture`; consumers reading old artifacts MAY fall back to `offer_tier` and map T1→knowledge, T2→free-asset, T3→pilot, T4→risk-reversal (also accepts integers 1-4 with the same mapping). Emit a deprecation warning on fallback. To be removed in a future release; remove this field from new emits but keep the read-side mapping until the deprecation window closes.
- `offer_summary` — one-sentence operator-readable summary of the offer (for `/marketing:launch-campaign` to echo in its preflight confirmation).
- `custom_variables` — array of `{name, default}` objects. The `/marketing:launch-campaign` command feeds this array into `create_custom_variable` before `bulk_create_leads` runs.
- `step_1` + `step_2` — each has `subject` (EB format rules), `body` (EB format rules + spintax + `<br><br>`), `wait_in_days` (integer, 0 for step 1, typically 3-5 for step 2).
- `step_1_variant_b` — **OPTIONAL** (BC-13628). When the offer has two distinct, comparably-strong step-1 **angles** worth A/B-testing (e.g. an electrical/GFCI-safety angle vs a heat-strips/warmth angle for the same winter-renewal offer), emit the B angle here as `{subject, body}` (same EB format rules as `step_1`; NO `wait_in_days` — a variant inherits step 1's wait). `step_1` is the A variant; this is B. **A step-1 A/B variant is NOT a third step** — both A and B occupy the step-1 slot; the 2-step max still holds (step_1[A/B] + step_2). Omit the field entirely (or `null`) when there is no second angle worth testing — do NOT invent a weak B just to fill it. `/marketing:plan-campaign` Step 8c.6 wires B as an EB sequence-step variant of step-1 A in the single from-scratch create, via `variant_from_step` (A's in-request order); `variant_from_step_id` (by saved step id) is only the cross-call fallback.
- `situation_mining_source` — path to the input artifact when this campaign flowed from `situation-mining`. Omitted / empty when §6 Flow 2 (scratch path) ran.
- `generated_at` — ISO-8601 timestamp. `/marketing:launch-campaign` checks this against a staleness threshold before launching.

**Save path convention** — `docs/campaigns/{short_entity}/copy-{campaign-name}-{YYYY-MM-DD}.json` (short-form canonical post-[BC-8719](https://linear.app/brite-nites/issue/BC-8719) / O15 migration). Operator supplies `{campaign-name}`; the skill slugifies it (lowercase, hyphen-separated). `{short_entity}` is derived by stripping the `brite-` prefix from the artifact's `entity` field for path purposes only — `brite-nites` → `nites`, `brite-labs` → `labs`. The `entity` field in the JSON artifact itself remains the long-form slug (downstream `/marketing:launch-campaign` `--entity` consumer relies on the long-form enum).

### Architectural rules that apply

- **`docs/marketing-context.md` is the entity-canon source.** Never hard-code an entity default in this skill. If marketing-context is missing and the operator declines to answer, ABORT — do not guess (D1).
- **Offer posture is always recommend + confirm.** No auto-select code path. Even with HIGH signal density, surface the recommendation to the operator and wait for confirmation before drafting (D2).
- **Preset files are lazy-loaded.** One preset file read per invocation, not the whole library. Use `Glob` + `Grep` to check existence before `Read`; on missing, fall back to base inline skeleton without halting (D3).
- **Supply vertical triggers are out of scope.** The handbook 23-vertical taxonomy excludes professional installers + property management (see `Brite-Nites/handbook@main:marketing/go-to-market/verticals/README.md`). If an operator supplies a Supply-framed prospect, pause and clarify — do not produce a Supply-tone email. Inherited from BC-5824 precedent.
- **Hypothesis framing is non-negotiable.** Inherited from situation-mining §3 — body copy never states worldview as fact. When incorporating inferred signals from the situation artifact, the copy must read as "we noticed X and thought {HYPOTHESIS}" — never "you are X."
- **Content-variable defaults must be non-empty (BC-6556 fail-closed gate).** Email Bison's render engine substitutes any unresolved `{TOKEN}` with empty string — silent, no error (verified BC-6308 round-3 R-2b: `{RECENCY_ANCHOR}` with null value rendered as `""`, producing `"Saw the  at Acme Bob..."` with double-space). To prevent this in production: every content variable referenced in `step_1` / `step_2` subject + body MUST have a non-empty `custom_variables[].default` in the artifact. Per-lead variables (`{COMPANY}`, `{FIRST_NAME}`) and sender variables (`{SENDER_*}`) are exceptions — they're resolved via per-lead CSV values and the §5 Workflow 1 priority chain respectively, not via campaign-level defaults. Enforced fail-closed by `launch-campaign.md` Phase 1 step 5. Defaults are a **safety net** for prospects with thin per-lead data, not a substitute for good per-lead values — for high-personalization campaigns, populate the per-lead value via the CSV. Graceful per-lead fallback (per-lead empty without campaign-level halt) is now handled via Liquid syntax in the template body — see § Liquid + spintax for graceful per-lead fallback (BC-6613, supersedes the canceled smart-merge formula approach).

---

## MCP Tool Reference

"When you need to X, call `tool_name`." Grouped by workflow. This skill has exactly one MCP workflow — a conditional Salesforce lookup for sender defaults. All other work is local `Read` / `Write` / `Glob` / `Grep`.

### Workflow 1 — Sender-info lookup (conditional)

Runs **only** when `docs/marketing-context.md` is missing the `{SENDER_*}` defaults AND the operator has not supplied them explicitly. See [`plugins/marketing/tools/integrations/salesforce.md`](../../../tools/integrations/salesforce.md) for auth, tool names, and SOQL gotchas.

1. **Availability check:** call `run_soql_query` with `SELECT Id FROM User LIMIT 1`. On failure, HALT this workflow — do NOT fabricate sender info. Fall back to asking the operator directly for `{SENDER_FIRST_NAME}`, `{SENDER_EMAIL}`, `{SENDER_ROLE}`. Per BC-5534 findings §Q1, this query is the verified liveness check; `get_username` is NOT a valid liveness check.
2. **User lookup:** call `run_soql_query` with `SELECT Id, FirstName, Email, Title FROM User WHERE Email = '{operator_email}' LIMIT 1`. Use the returned `FirstName` / `Email` / `Title` to fill `{SENDER_FIRST_NAME}`, `{SENDER_EMAIL}`, `{SENDER_ROLE}` in the custom_variables array.
3. **On zero results:** the operator's email doesn't match a Salesforce User — prompt the operator for the sender values directly via AskUserQuestion. Do not halt.

All SF calls are read-only; no MCP confirmation gates apply. This skill has NO mutating workflows — it never touches EB state, never writes to Salesforce, never modifies anything outside the local `docs/campaigns/` directory.

---

## Operational Runbook

Six flows — the common paths operators actually run. Each flow states preconditions, steps (referencing §5 Workflow 1 where applicable), expected output, error handling, and cross-skill handoff.

### Flow 1 — Happy path (situation artifact + offer posture + vertical → copy using preset)

**Preconditions:**
- `docs/marketing-context.md` exists and identifies the Brite entity.
- A situation-mining artifact is in conversation context (path supplied by operator or auto-detected from recent `docs/research/situations/*.md`).
- Operator has identified the `vertical` in the situation artifact (or the skill extracts it from the artifact frontmatter).

**Steps:**
1. Read the situation artifact; extract `entity`, `vertical`, worldview row, adjacent offering.
2. Apply §3 entity-aware posture matrix to recommend an offer posture. Surface the recommendation + one-line rationale to the operator. Wait for confirmation (D2 confirm gate).
3. Run §2 value-equation gate — confirm the 4 inputs resolve from marketing-context.md + situation artifact. If any missing, interview the operator one input at a time.
4. `Glob` check `presets/{template_preset}-{vertical}.md`. If it exists, `Read` it. If not, flag the fallback path (Flow 6).
5. Fill slots: `{RECENCY_ANCHOR}` from the situation artifact's top waterfall signal, `{PROOF_POINT_*}` from marketing-context.md case studies, `{SENDER_*}` from marketing-context.md or §5 Workflow 1 fallback, `{FREE_ASSET_NOUN}` / `{INITIATIVE_NOUN}` / `{GUARANTEE_TERMS}` from value-equation inputs.
6. Validate draft against §8 anti-slop guardrails — auto-replace em-dashes, check for `{{TOKEN}}` EB-token typos (regex `\{\{\s*[A-Z_]+\s*\}\}`; Liquid output `{{ var }}` is allowed), check for `<p>` tags, confirm subject has no `{FIRST_NAME}`, confirm step count is exactly 2.
7. Build the `custom_variables` array (every `{VARIABLE}` in body or subject must be declared).
8. `Write` the JSON artifact to `docs/campaigns/{short_entity}/copy-{campaign-name}-{YYYY-MM-DD}.json`.
9. Report the artifact path + offer summary + tier + preset used to the operator.

**Expected output:** artifact written; one-line summary like "Wrote copy-denver-downtown-2026-04-20.json — free-asset posture, list-building Municipalities preset, 7 custom variables."

**Error handling:** if §2 hard gate fails at step 3, abort with an operator-facing message naming the missing input. If §6 preset file missing, degrade to Flow 6 without halting.

**Handoff:** operator can then run `/marketing:launch-campaign` (BC-5826) to execute the sequence.

### Flow 2 — Scratch path (no situation artifact, value-equation interview)

**Preconditions:**
- No situation artifact in conversation context.
- Operator has supplied entity + a target description (company name, vertical, rough offer idea).

**Steps:**
1. Ask the operator for entity (if not resolvable from marketing-context.md), vertical (optional), and campaign name.
2. Interview the operator for the 4 §2 value-equation inputs — one question at a time. Do not batch.
3. Recommend an offer posture from the §3 matrix based on the operator's answers + entity. Confirm per D2.
4. Pick base skeleton (A = list-building if `knowledge` / `free-asset`, B = risk-reversal if `risk-reversal`; `pilot` defaults to B with softer guarantee language).
5. Fill slots from operator-supplied inputs. `{RECENCY_ANCHOR}` defaults to the level-6 waterfall fallback ("most {VERTICAL_DESCRIPTOR} teams we work with are scoping ...") since no situation artifact was read.
6. Validate per §8 anti-slop.
7. `Write` artifact with `situation_mining_source: ""` (empty string, per schema).
8. Report path + summary + warning: "No situation artifact used — recency anchor is fallback tier; consider running situation-mining before send."

**Expected output:** artifact written with level-6 fallback hook; operator-facing warning about the missing recency anchor.

**Error handling:** if the operator declines to supply any of the 4 value-equation inputs, abort with a clear message and do NOT write the artifact.

**Handoff:** same as Flow 1.

### Flow 3 — Existing-preset path (operator picks base template manually)

**Preconditions:**
- Operator explicitly wants `list-building` or `risk-reversal` base template with NO vertical override.
- Inputs may be partial — operator has entity + proof point but not a full situation.

**Steps:**
1. Confirm entity + offer posture per D2.
2. Skip the `Glob` preset-file check — operator requested base template explicitly.
3. Load base skeleton (A or B) from §3 directly.
4. Fill slots from operator-supplied inputs; any missing `{VARIABLE}` stays as a placeholder in the body and lands in the `custom_variables` array with empty `default`.
5. Validate per §8.
6. `Write` artifact with `vertical: null` (nullable per schema).
7. Report: "Base `list-building` template, no vertical override — 5 custom variables remain unfilled for operator review."

**Expected output:** artifact with base-template copy; `vertical: null` in schema.

**Error handling:** same as Flow 1.

**Handoff:** same as Flow 1.

### Flow 4 — Seed-vertical demo (Municipalities end-to-end dogfood)

**Preconditions:**
- Operator runs "demo Municipalities list-building" or equivalent dogfood prompt.
- Intended for smoke-testing the lazy-load path after changes to the seed preset or base skeleton.

**Steps:**
1. Load `docs/research/situations/denvergov.org-sample.md` (or any Municipalities-vertical sample artifact) if available; if not, use in-memory demo values for Denver Parks & Rec.
2. Recommend `free-asset` per §3 entity-aware matrix (Labs for Municipalities, `pilot` also reasonable — operator picks).
3. `Read` `presets/list-building-municipalities.md` — this is the seeded preset from this skill's shipping commit (BC-5825).
4. Fill slots with demo values; confirm value-equation inputs are non-empty.
5. Validate per §8.
6. `Write` artifact to a demo path: `docs/campaigns/labs/copy-demo-municipalities-{YYYY-MM-DD}.json` (short-form canonical per BC-8719).
7. Report path + note that this is a dogfood / demo run.

**Expected output:** artifact written; operator can inspect and grep for format compliance.

**Error handling:** if the seed preset file is missing from disk, the skill SHOULD NOT silently fall back — this is a dogfood run specifically intended to exercise the preset load path. Report the missing file as a regression signal.

**Handoff:** none — this is a smoke test.

### Flow 5 — Thin-context fallback (no marketing-context.md — hard gate pause)

**Preconditions:**
- `docs/marketing-context.md` is missing OR does not identify the Brite entity.

**Steps:**
1. Warn the operator with the BC-5824 precedent message: "Marketing context doc not found — proceeding with reduced context. Run `/marketing:product-marketing-context` to generate it."
2. PAUSE. Ask the operator for the Brite entity explicitly via AskUserQuestion. Do NOT proceed to drafting with a silent default (D1).
3. If the operator supplies entity, continue into Flow 1 / 2 / 3 with that entity as the authoritative source.
4. If the operator declines to supply entity, ABORT — do not write any artifact. Report: "Entity is required; cannot generate copy without it."

**Expected output:** no artifact written until operator confirms entity.

**Error handling:** none — this is a precondition-violation path, not a failure path.

**Handoff:** skill resumes Flow 1 / 2 / 3 after the operator answers the entity prompt.

### Flow 6 — Unknown-vertical fallback (preset file missing)

**Preconditions:**
- Operator supplies a `vertical` value.
- No matching `presets/{template_preset}-{vertical}.md` file exists. This is expected behavior for every vertical EXCEPT `municipalities` until BC-5879 / BC-5880 / BC-5881 ship the fan-out preset files.

**Steps:**
1. `Glob` `presets/{template_preset}-{vertical}.md` returns no matches.
2. Log a one-line warning to the operator naming the relevant fan-out issue. Example for HOAs: "Preset `list-building-hoas.md` not found — falling back to base skeleton A + Nites tone. The HOAs preset is tracked in BC-5879 (Active-tier fan-out)." For Exploring-tier verticals reference BC-5880; for Future-tier verticals reference BC-5881.
3. Load base skeleton (A or B) from §3.
4. Pull entity tone from `docs/marketing-context.md` — specifically the tone markers in `§Voice` or equivalent.
5. Fill slots; `{RECENCY_ANCHOR}` uses the situation artifact's top waterfall signal if present, else level-6 fallback.
6. Validate per §8.
7. `Write` artifact with `vertical: null` (the skill did not use a vertical preset — the operator's intent is recorded but the output is base-template tone).
8. Report the fallback + the fan-out issue reference.

**Expected output:** artifact written with base-template + entity tone; `vertical: null` in schema; operator-facing log line naming BC-5879 / BC-5880 / BC-5881 as applicable.

**Error handling:** if the operator's supplied vertical is NOT in the handbook 23-vertical taxonomy (e.g. "installers", "property management"), pause per §4 architectural rules and clarify — do not produce a Supply-tone email. This is a §8 hard failure path.

**Handoff:** same as Flow 1.

---

## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | Artifact is EB-format-compliant (no `{{TOKEN}}` EB-token typos per regex `\{\{\s*[A-Z_]+\s*\}\}`; Liquid output `{{ var }}` is allowed in body for fallback patterns; no `<p>`, no em-dashes in body, no `{FIRST_NAME}` in subject, exactly 2 steps, sign-off spintax correct); Hormozi value equation visible in body copy (all 4 inputs map to specific paragraphs); entity-aware tier from the §3 matrix is picked and confirmed by operator; recency-waterfall anchor appears in the hook and cites the waterfall level; every `{VARIABLE}` in body + subject is declared in `custom_variables`; base or per-vertical preset is cited in the artifact; `situation_mining_source` cited when applicable; all §8 anti-slop guardrails pass validation. |
| 7-9 | Mostly excellent with one gap — e.g. recency anchor cites a level but the signal is weak; one custom variable in the body is missing from the array; spintax is word-level but less dense than the 3-5 word guideline; sign-off is correct but not spintax-expanded. |
| 4-6 | Functional but missing structural elements — e.g. value equation applied but proof point is generic (no numbers), or step 2 bump summarizes step 1 instead of referencing it, or tier was recommended but not confirmed with operator (D2 bypassed), or `vertical: null` without a valid fallback reason, or the preset file exists but wasn't read. |
| 1-3 | Format violations (any one: `{{TOKEN}}` EB-token typo present per regex `\{\{\s*[A-Z_]+\s*\}\}` — note Liquid output `{{ var }}` is allowed and not a violation, `<p>` tag present, em-dash in body, `{FIRST_NAME}` in subject, >2 steps, Supply-vertical trigger like "installers" or "property mgmt" in body); OR `docs/marketing-context.md` was ignored (silent entity default); OR fact-claim framing ("you are X" instead of "we noticed X and thought Y"); OR fabricated proof point / statistic / case study not in marketing-context.md or operator input. |

---

## Anti-Slop Guardrails

Base guardrails (shared across marketing plugin) + skill-specific hard failures. Skill-specific rules are phrased as "Do not X" because they are enforced as validation gates, not style preferences.

**Base guardrails:**

- Do not generate generic marketing jargon ("synergy", "leverage", "best-in-class", "game-changing", "cutting-edge").
- Do not fabricate statistics, case studies, testimonials, or proof points — always attribute to a source in `docs/marketing-context.md` or operator input. If a proof point is missing, ABORT per §2 value-equation gate.
- Do not produce output that ignores `docs/marketing-context.md`. Entity, tone, ICP, and sender info all derive from marketing-context before any operator input.
- Do not recommend tools the plugin does not have access to (no hallucinated MCP servers, no EB tool calls in this skill — this skill generates copy only).

**Skill-specific hard failures (validation-gated — fail the artifact emit):**

- **Do not emit `{{TOKEN}}` double-brace EB-token typos.** Email Bison requires single-brace uppercase variables (`{FIRST_NAME}`). The double-brace form `{{FIRST_NAME}}` or `{{ FIRST_NAME }}` (uppercase identifier, with or without internal whitespace) is a typo — EB does NOT resolve it; it renders as literal text in delivery. Detection regex: `\{\{\s*[A-Z_]+\s*\}\}` (uppercase letters or underscores only; internal whitespace allowed but the identifier itself must be uppercase). If a draft contains this pattern, self-correct to single-brace before emit. Hard failure if present in the written artifact.

  **Liquid output `{{ var }}` is allowed and required for the Liquid fallback patterns** (see § Liquid + spintax for graceful per-lead fallback). Liquid local variables MUST be lowercase (snake_case acceptable, e.g., `{{ name }}`, `{{ first_name }}`, `{{ recency }}`). The lowercase-required rule is what makes the typo regex unambiguous and safe to apply mechanically: `{{FIRST_NAME}}` (uppercase, no spaces) gets caught as a typo; `{{ name }}` (lowercase, space-padded) passes as Liquid output. Uppercase Liquid locals (e.g., `{{ NAME }}`) are forbidden by convention because they collide with the typo regex.
- **Do not emit lowercase or mixed-case `{token}` references in subjects or bodies.** EB's render engine ONLY resolves UPPERCASE tokens (e.g., `{FIRST_NAME}`); lowercase or mixed-case tokens (`{first_name}`, `{First_Name}`) render as literal text in delivery — verified BC-6308 round-3 R-2a Preview Body output. If a draft contains any `{[a-z][A-Za-z_]*}` pattern, self-correct to UPPERCASE before emit. Hard failure if present in the written artifact.
- **Do not emit `<p>` or `</p>` tags in body copy.** EB's HTML-to-plain converter eats `<p>` and corrupts the greeting-merged first sentence. Use `<br><br>` for paragraph breaks. Hard failure if present.
- **Do not emit em-dashes (`—`) in body copy.** Known EB spam trigger. Auto-replace with commas, periods, or hyphens at draft time. Hard failure if present in the written artifact. (Em-dashes in this SKILL.md spec prose are OK where explaining the rule; the rule applies only to body template examples and generated artifact text.)
- **Do not emit sequences with more than 2 steps.** This skill supports step 1 + step 2 only. Longer sequences belong in `campaign-orchestration`'s multi-phase flow. Hard failure on 3+ steps. **Exception (BC-13628): an optional step-1 A/B variant (`step_1_variant_b`) is allowed and is NOT a third step** — both variants occupy the step-1 slot. Hard failure only if a `step_2_variant`/`step_3` or any beyond-step-2 content appears.
- **Do not emit `{FIRST_NAME}` (or any merge variable) in the subject line.** Subjects are the highest-impact spam signal; merge variables under-perform generic subjects across every deliverability benchmark. Hard failure.
- **Do not frame inferences as facts.** Inherited from situation-mining §3 — body copy MUST read as hypothesis when referencing a prospect worldview or inferred signal. Write "we noticed the {INITIATIVE} announcement and thought it might line up with how your team is scoping {VERTICAL_DESCRIPTOR}" — never "your team is scoping {VERTICAL_DESCRIPTOR}." Fact-claim framing is a hard failure; §7 1-3 band.
- **Do not emit Supply-vertical triggers in body copy.** The handbook 23-vertical taxonomy excludes professional installers + property management. Body copy that keys to installer hiring, PM company onboarding, or other Supply signals is a hard failure per handbook canon + BC-5824 precedent. If an operator supplies a Supply-framed prospect, pause and clarify per §6 Flow 6 error handling.

---

## Behavioral Tests

Eight scenarios covering the core paths. Structured assertions + expected-output details live in `evals/evals.json` alongside this file. Scenario IDs match the `evals.json` entries for 1:1 traceability.

### Tier 1 — Free assertions (no tool calls needed)

- **`scratch-path-value-equation`** — Given no situation artifact and an entity-only input, the skill's first response asks for the 4 §2 value-equation inputs (Dream Outcome, Perceived Likelihood, Time Delay, Effort + Sacrifice) before any drafting. No JSON artifact is emitted until the operator answers.
- **`format-violation-self-correct`** — Given a draft (operator-supplied template or mid-generation text) containing `{{FIRST_NAME}}` (uppercase double-brace EB-token typo, matches regex `\{\{\s*[A-Z_]+\s*\}\}`), the skill self-corrects to `{FIRST_NAME}` before artifact emit. Output artifact body contains zero `\{\{\s*[A-Z_]+\s*\}\}` typo matches; lowercase Liquid output `{{ var }}` (e.g., `{{ recency }}` from a Liquid fallback assign) is allowed and preserved.
- **`em-dash-auto-replace`** — Given operator-supplied proof-point text containing em-dashes, the skill auto-replaces all em-dashes with commas, periods, or hyphens before artifact emit. Output artifact body contains zero `—` characters.
- **`unknown-vertical-fallback`** — Given `vertical: hoas` (preset file not yet shipped — expected pre-BC-5879), the skill falls back to base skeleton A + Nites tone and logs a one-line warning citing BC-5879. Output artifact has `vertical: null` and body matches base-template shape, not a vertical-override shape.
- **`missing-offer-posture-gate`** — Given no `offer_posture` input (and no legacy `offer_tier` fallback), the skill's first response recommends a posture from the §3 matrix with one-line rationale AND asks for operator confirmation via AskUserQuestion. No JSON artifact is emitted until the operator confirms or overrides.

### Tier 2 — Tool-assisted (requires file read or MCP call)

- **`happy-path-municipalities-seed`** — Given a situation artifact for Denver Parks & Rec at `docs/research/situations/denvergov.org-2026-04-20.md` + `vertical: municipalities` + `offer_posture: free-asset` + entity confirmed, the output JSON artifact (a) exists at the expected path, (b) has `template_preset == "list-building"`, (c) has `vertical == "municipalities"`, (d) has `situation_mining_source` populated, (e) body contains `<br><br>` paragraph breaks, (f) body contains zero `—` characters, (g) subject contains zero `{FIRST_NAME}` tokens. Preset file `list-building-municipalities.md` was `Read` during the flow.
- **`entity-switching`** — Given the same situation artifact, run once with `entity: brite-nites` and once with `entity: brite-labs`. The two artifacts differ in (a) `offer_posture` (Nites → `free-asset` typical, Labs → `pilot` or `risk-reversal` typical per §3 matrix), (b) subject line word choices (Nites warmer / seasonal, Labs more capital / experiential), (c) CTA framing (Nites "free preview" vs Labs "scope a pilot"). Entity tone is sourced from `docs/marketing-context.md`.
- **`missing-marketing-context-hard-gate`** — With `docs/marketing-context.md` absent from disk, the skill's first response does NOT contain any JSON artifact text and does NOT contain any "## Recommendations" section. It DOES contain the BC-5824 precedent warning message AND an entity prompt via AskUserQuestion. No Write tool call fires until the operator answers. (D1 hard gate.)

---
