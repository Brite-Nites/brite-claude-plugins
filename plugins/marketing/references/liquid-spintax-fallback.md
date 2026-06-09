# Liquid + spintax for graceful per-lead fallback

Author-time reference for the `email-copywriting` skill (extracted from SKILL.md §3 per BC-12966 to keep the always-loaded skill body under the structural-lint advisory). Read this when authoring Liquid fallback patterns in base skeletons or per-vertical presets. The skill's SKILL.md § Liquid + spintax for graceful per-lead fallback carries the quick-reference summary and points here for the full pattern library.

Per-lead variables go missing. A 1000-row CSV will have rows with empty `RECENCY_ANCHOR`, missing `JOB_TITLE`, blank `CITY`. Email Bison's render engine substitutes empty strings silently — verified BC-6308 round-3 R-2b: a missing `{RECENCY_ANCHOR}` produced `"Saw the  at Acme Bob..."` with a visible double-space and orphan apostrophe-s. The fail-closed gate at `launch-campaign.md` Phase 1 step 5 prevents this by halting the launch when any variable lacks a non-empty default — safe but blunt. Liquid syntax provides per-lead graceful fallback inside the template body itself, so the launch proceeds and only the affected lead sees the fallback rendering. EB ships this capability natively. Authoritative reference: [EmailBison article 184](https://help.bisonsphere.com/en/articles/184-liquid-syntax-spintax-how-to-use-and-templates).

## Substitution order rule

Verbatim from EB docs: *"Bison replaces custom variables before parsing your liquid templates."*

Plain language: EB token substitution runs FIRST. Liquid runs SECOND. So Liquid sees the post-substitution result, not the raw `{TOKEN}`. A template like `{% assign x = '{FIRST_NAME}' %}` works because EB substitutes `{FIRST_NAME}` to the lead's name (or empty string) before Liquid evaluates the assign. Authors writing Liquid fallback patterns rely on this ordering — without it, the patterns wouldn't compose.

## Pattern A — assign + filter chain fallback

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

## Anti-pattern — naked default without `{% assign %}` wrapper

The seductive shape that **does not work** for per-lead fallback:

```
{{ recency_anchor | default: 'recently' }}
```

Every lead renders the fallback `'recently'` — the per-lead value never appears. Why: the lowercase identifier `recency_anchor` is a Liquid local that was never assigned via `{% assign %}`, so it is always `nil`, and `default:` always triggers. EB only substitutes the UPPERCASE `{TOKEN}` form (per the substitution-order rule above), and the naked shape above has no UPPERCASE token at all — only the lowercase Liquid local. Pattern A above is what binds a per-lead value to a Liquid local correctly: EB substitutes `{TOKEN}` inside the `'{TOKEN}'` single-quotes, the substituted value becomes a string literal, and `{% assign %}` binds it to the local.

The `launch-campaign.md` Phase 1 step 5 Path (5e)(a) gate hard-rejects copy containing this shape via the regex `\{%-?\s*assign\s+\w+\s*=\s*'\{[A-Z_]+\}'[^%]*default:\s*['"][^'"]+['"][^%]*-?%\}` — copy with the naked form halts pre-flight with a "Liquid fallback must use `{% assign %}` wrapper" error. Authors who hit this at gate-time should rewrite to Pattern A above before re-running. Origin: BC-6554 round-4 S-23 / BC-6782.

## Pattern B — conditional + spintax fallback

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

## Pattern C — keyword-branched value-prop

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

## Whitespace control

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

## Inline Liquid: do NOT use strip-hyphens (BC-7598)

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

## Liquid local variable naming rule

Liquid local variables (the names introduced by `{% assign %}`) MUST be lowercase, snake_case acceptable. Examples:

- Good: `{% assign name = ... %}`, `{% assign company_legal_name = ... %}`, `{% assign first_name = ... %}`
- Forbidden: `{% assign NAME = ... %}`, `{% assign FirstName = ... %}`, `{% assign Company = ... %}`

Why: the anti-slop rule (SKILL.md § Anti-Slop Guardrails) detects EB-token typos like `{{FIRST_NAME}}` and `{{ FIRST_NAME }}` (uppercase identifier, with or without internal whitespace) via the regex `\{\{\s*[A-Z_]+\s*\}\}`. Lowercase Liquid locals (rendered as `{{ name }}`, lowercase identifier) are unambiguously distinct from typos. Uppercase Liquid locals (e.g., `{{ NAME }}`) ARE caught by the typo regex — that's intentional. They're forbidden by both convention AND regex enforcement, so the typo-detection rule is unambiguous and safe to apply mechanically regardless of authoring whitespace.

## Authoring guidance — fallbacks are for data sparsity, not lazy authoring

Liquid fallbacks are a safety net for the 1-of-1000 lead with a missing per-lead value. They are not a substitute for per-lead research.

Rule: if a campaign expects ≥10% of leads to use the fallback (i.e., ≥10% have empty per-lead values for the wrapped variable), the CSV needs better enrichment, not a smarter fallback. Generic fallbacks signal vendor-who-didn't-research at the prospect-side; per-lead values are the quality lever. The fallback exists to prevent visible glitches, not to make low-research email feel personalized.

When choosing a fallback string, target "okay-ish if hit, signals nothing distinctive if not hit." A `RECENCY_ANCHOR` fallback like "a recent capital-plan announcement" reads as plausibly per-lead. A fallback like "your recent stuff" reads as obviously generic and is a quality drop. The former is acceptable for a rare-case safety net; the latter is not.

## Per-lead value safety — no Liquid metacharacters in CSV values

EmailBison's substitution-order rule means lead values are inlined into the body BEFORE Liquid parses. A CSV row whose `RECENCY_ANCHOR` (or any per-lead variable) contains Liquid metacharacters — `{{`, `}}`, `{%`, `%}` — would inject Liquid that runs at EB render time. Worst case: a lead value like `{% for i in (1..1000000) %}{% endfor %}` triggers a Liquid render-loop DoS against the EB sender, or a quote-breakout like `'; some_filter; '` smuggles arbitrary Liquid filter invocation into the assign string.

`/marketing:launch-campaign` enforces this at the input boundary via IV-10 (CSV row value Liquid-metacharacter rejection — see `plugins/marketing/commands/launch-campaign.md` § Input validation). Authors of campaign artifacts and per-lead enrichment pipelines should NOT manually defeat this check. Per-lead values should be plain text; if a campaign needs Liquid logic, it lives in the body template (authored by this skill), not in CSV cells. Threat model: enrichment-vendor data integrity boundary — Apollo, Clay, ZoomInfo, and similar paid sources have integrity guarantees, but the boundary is real and IV-10 is fail-closed.

## Available filters and conditionals

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

## Cross-reference

Vendor-fact reference for Liquid + spintax + whitespace: `plugins/marketing/tools/integrations/email-bison.md` § Liquid + spintax + whitespace.

Gate-relax accepting Liquid as a resolution path: `plugins/marketing/commands/launch-campaign.md` Phase 1 step 5 (5th resolution path) and Phase 1 step 6 (sanity checklist regex tightening).
