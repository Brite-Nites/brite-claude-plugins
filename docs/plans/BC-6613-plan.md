# BC-6613 — Adopt Liquid syntax for graceful fallback in EmailBison templates

**Linear:** [BC-6613](https://linear.app/brite-nites/issue/BC-6613/adopt-liquid-syntax-for-graceful-fallback-in-emailbison-templates)
**Supersedes:** BC-6557 (canceled, PR #248 closed without merge)
**Verifies via:** BC-6554 round-4 dogfood walk
**Estimated effort:** 1-2 days, documentation + spec edits, no new infrastructure

---

## Plain-language summary

EmailBison's template engine already understands Liquid (a popular text-templating language) plus spintax. We discovered this during the prior research into a custom smart-merge layer (which we canceled once we found Liquid was already shipped natively). Liquid lets a template say "use the per-prospect value if it exists, otherwise use a sensible fallback" in one line — exactly the safety we were planning to build from scratch.

The current safety net (the fail-closed gate in the launch-campaign command's pre-flight phase) blocks the launch entirely if any variable lacks a non-empty default in the artifact. That's safe but blunt. With Liquid, a template can fall back gracefully per-lead without halting the whole launch when one row in a thousand has a blank cell.

**Scope is foundation work, not vertical content.** The 3 hand-coded preset files exist as Holden-authored scaffolds for the verticals; long-term they'll be replaced by a feature that syncs from handbook vertical pages. Editing those scaffold files now would be throwaway. Instead, the foundation work happens at the layers every campaign passes through:

1. The skill teaches the Liquid + spintax + whitespace pattern (variable-agnostic).
2. The skill's two canonical base skeletons (Skeleton A + Skeleton B) USE the pattern as their default form, so every preset author / future handbook-sync generator inherits Liquid by default.
3. The launch-campaign command accepts Liquid as a valid resolution path at the gate (variable-agnostic).
4. The anti-slop rules differentiate "EB-token typo `{{TOKEN}}`" (still forbidden) from "Liquid output `{{ local_var }}`" (now required).
5. The vendor-fact reference doc captures the canonical patterns from EmailBison's own docs + Shopify's whitespace doc.

This makes the work durable across all campaigns, all verticals, and survives the eventual handbook-sync rewrite of the preset files.

---

## Reconciliation table — issue body vs. ground truth

| Issue body claim | Ground truth | Plan resolution |
|---|---|---|
| Scope item 2 names "minimum 3 production presets" to update | The 3 preset files are Holden's hand-coded scaffolds; long-term replaced by a handbook-sync feature (not yet scoped). Editing them now is throwaway. | DROP heavy preset edits. Add an optional one-line "see SKILL.md § Liquid + spintax for graceful per-lead fallback" note in each preset for future-author discoverability — 5-second touch, not real authoring work. |
| Scope item 1 enumerates "high-risk variable types: recency anchors, proof points, friction signals..." | Brainstorm reframed: don't anchor on today's variables. Foundation move is updating the inline base skeletons that every preset / generator inherits from. | SKILL.md § Liquid + spintax for graceful per-lead fallback teaches the pattern variable-agnostically. Skeleton A and Skeleton B (the inline canonical bodies) USE the pattern on the keystone failure variable (`{RECENCY_ANCHOR}` per BC-6308 R-2b). |
| Scope item 4 marks Liquid-aware validator as "optional but recommended" | BC-6554 round-4 walks the patterns live before any mechanism is built. | Validator deferred to a follow-up issue, filed during ship. |
| AC: "Liquid `default` filter wrapping the variable" satisfies gate | EB also documents `{% if %}` truthy + `{% else %}` fallback as equivalent shape. Conditional + spintax composition is the most expressive pattern. | Gate-relax extends to: `{% assign %}` ending in `default:`, OR truthy `{% if local_var %}` with non-empty `{% else %}`, OR `{% if '{TOKEN}' contains '...' %}` keyword-branch with non-empty `{% else %}`. Variable-agnostic. |
| Issue body does not mention Phase 1 step 8 (lead spot-check) | Phase 1 step 8 substitutes tokens + renders for operator preview. Liquid blocks need handling decision. | Option (b): spot-check renders post-substitution body with raw Liquid blocks visible, plus clarifying note pointing to `--test-send` for full Liquid evaluation. No Liquid parser bundled into the spec. |
| Issue body does not mention whitespace control | Shopify Liquid docs: every uncontrolled `{% ... %}` line prints a blank line in the rendered output. Without `{%- -%}`, every `{% assign %}` at top of body adds a blank line before the greeting. | SKILL.md § Liquid + spintax for graceful per-lead fallback covers whitespace-control hyphens. Skeleton A + B use `{%- -%}` form. Critical to ship correctly. |
| Issue body does not mention spintax inside Liquid fallbacks | EB docs verbatim: `{% if city %}...{% else %}...in {your area\|the region}...{% endif %}` — spintax composes natively inside `{% else %}` clauses. | SKILL.md § Liquid + spintax for graceful per-lead fallback shows the conditional + spintax composition pattern verbatim from EB article 184. |
| Anti-slop rule "no `{{` double-brace anywhere" (currently in SKILL.md § Anti-Slop + launch-campaign.md Phase 1 step 6) | Rule was authored to catch typos like `{{FIRST_NAME}}`. Liquid render reference is also `{{ var }}` — current rule would hard-fail every Liquid template. | NEW foundation work: tighten the regex to `\{\{[A-Z_]+\}\}` (uppercase, no spaces — the canonical typo shape) so Liquid `{{ var }}` (lowercase, space-padded) is allowed. Add authoring rule: Liquid local variables must be lowercase. |

---

## Brainstorm decisions

| Decision | Choice | Rationale |
|---|---|---|
| Variable wrapping scope | Variable-agnostic — teach pattern, demonstrate on keystone variable in base skeletons | User reframe: anchoring on current variables couples spec decisions to variables that may change; foundation work happens at skeleton level, not preset level |
| Foundation surface | SKILL.md (pattern + skeletons + anti-slop rule) + launch-campaign.md (gate + sanity checklist + spot-check) + email-bison.md (reference) | These layers touch every campaign; preset files are scaffolds that future handbook-sync replaces |
| Validator scope | Defer to follow-up after BC-6554 round-4 | BC-6554 round-4 verifies the patterns work live; validator design follows |
| Gate-relax shape | Additive 5th resolution path in Phase 1 step 5 | Smallest reversible change; preserves existing 4 paths |
| Phase 1 step 8 (spot-check) | Option (b) — substitution-only preview, raw Liquid blocks visible, point to `--test-send` for full eval | Avoids bundling a Liquid parser into the spec; `--test-send` is the existing escape hatch for server-side render verification |
| Anti-slop `{{` rule | Tighten regex to allow Liquid `{{ var }}` while still catching `{{TOKEN}}` typos | Foundation gap — current rule blocks the pattern we're adopting |
| Preset file edits | DROP — replace with one-line "see SKILL.md § Liquid + spintax for graceful per-lead fallback" pointer | Holden's scaffolds; future handbook-sync replaces them; the pointer is for whoever opens those files in the meantime |
| Fallback-quality concern | Authoring rule in SKILL.md, not code | Liquid fallbacks are for data sparsity, not lazy authoring; honest guardrail belongs in prose |

---

## Source verification

### EmailBison article 184 (verbatim, fetched 2026-05-04)

**URL:** https://help.bisonsphere.com/en/articles/184-liquid-syntax-spintax-how-to-use-and-templates

**Substitution order (load-bearing):**

> "Bison replaces custom variables before parsing your liquid templates."

**Canonical assign + filter chain:**

```
{% assign name = '{FIRST_NAME}' | strip | default: 'there' | downcase | capitalize %}
```

**Conditional with quoted custom variable:**

```
{% if '{FIRST_NAME}' == 'Cody' %}
This is Cody
{% elsif '{FIRST_NAME}' == 'John' %}
This is John
{% else %}
This is not Cody or John
{% endif %}
```

**Conditional + spintax composition (the keystone pattern):**

```
{% assign city = '{CITY}' %}
{% if city %}
I'm helping several clients in {CITY} who need guidance with insurance.
{% else %}
I'm helping several clients in {your area|the region} who need guidance with insurance.
{% endif %}
```

**Title-keyword branching:**

```
{% if title contains "founder" or title contains "ceo" %}
I'll keep this brief given your schedule.
{% elsif title contains "sales" or title contains "revops" %}
Happy to share a quick pipeline impact summary.
{% else %}
I can tailor this to your team's priorities.
{% endif %}
```

**Documented filters:** `strip`, `downcase`, `capitalize`, `default`, `date`, `plus`, `contains` (in if-clauses).

**Documented gotcha:** "The downcase in the first line of code is used to make all text in the variable lower case as matching is case sensitive." Without `downcase`, "Founder" won't match "founder" in `contains` comparisons.

### Shopify whitespace doc (verbatim, fetched 2026-05-04)

**URL:** https://shopify.github.io/liquid/basics/whitespace/

**Rule:** "Any line of Liquid in your template will still print a blank line in your rendered HTML."

**Whitespace-stripping delimiters:**

- `{{-` strips whitespace from the left
- `-}}` strips whitespace from the right
- `{%-` strips whitespace from the left
- `-%}` strips whitespace from the right

**Canonical compact pattern:**

```
{% assign username = "John G. Chalmers-Smith" -%}
{%- if username and username.size > 10 -%}
  Wow, {{ username -}} , you have a long name!
{%- else -%}
  Hello there!
{%- endif %}
```

Output: `Wow, John G. Chalmers-Smith, you have a long name!` (no leading or trailing blank lines).

---

## Tasks

### Task 1 — Add § Liquid + spintax for graceful per-lead fallback section to email-copywriting/SKILL.md

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Insertion point:** Between § Methodology subsection "Lazy-load per-vertical overrides" (line 161-179 currently) and the `---` divider before § Brite Implementation (line 181). New subsection lives at the bottom of § Methodology so per-vertical preset authors find it next to the skeleton patterns they're authoring.
**Estimated time:** 30-40 min
**Implementation:**

1. Add new H3 subsection `### Liquid + spintax for graceful per-lead fallback`
2. Open with one paragraph naming the failure class (BC-6308 R-2b empty-render origin) and the canonical EB doc URL (article 184) as authoritative reference
3. Add subsection "Substitution order rule" — verbatim quote from EB doc: "Bison replaces custom variables before parsing your liquid templates." Explain in plain language: EB token substitution runs first, Liquid runs second — so Liquid sees the substituted result, not the raw `{TOKEN}`.
4. Add subsection "Pattern A — assign + filter chain fallback" with verbatim canonical pattern from EB doc:
   ```
   {%- assign name = '{FIRST_NAME}' | strip | default: 'there' | downcase | capitalize -%}
   ```
   Explain each filter: `strip` (whitespace-only values become empty), `default:` (empty triggers fallback), `downcase` + `capitalize` (case normalization). Show usage: `Hey {{ name }}, ...`. Note: `{%- -%}` whitespace stripping per Shopify doc.
5. Add subsection "Pattern B — conditional + spintax fallback" with verbatim EB pattern:
   ```
   {%- assign city = '{CITY}' -%}
   {%- if city -%}
   I'm helping several clients in {CITY} who need guidance with insurance.
   {%- else -%}
   I'm helping several clients in {your area|the region} who need guidance with insurance.
   {%- endif -%}
   ```
   Explain: truthy check on the assigned local. The `{% else %}` clause can contain spintax (`{your area|the region}`) which EB rotates per-send. Whole-clause swap, not just word swap.
6. Add subsection "Pattern C — keyword-branched value-prop" with verbatim title-keyword example. Note this is how to branch the Hormozi value-equation paragraph 1 by job title.
7. Add subsection "Whitespace control" referencing Shopify doc URL. Show before/after — without hyphens vs. with hyphens — to make the blank-line failure visible. Rule: every Liquid line in a body uses `{%- ... -%}` (or `{{- ... -}}` for output tags) unless the author explicitly wants a line break.
8. Add subsection "Liquid local variable naming rule" — Liquid local variables MUST be lowercase (snake_case acceptable). This is what makes the anti-slop typo regex unambiguous: `{{FIRST_NAME}}` (uppercase, no spaces) is a typo and gets caught; `{{ name }}` (lowercase, space-padded) is Liquid output and passes. Authors using Liquid MUST follow this convention.
9. Add subsection "Authoring guidance — fallbacks are for data sparsity, not lazy authoring". Rule: if a campaign expects ≥10% of leads to use the fallback (i.e., ≥10% have empty per-lead values), the CSV needs better enrichment, not a smarter fallback. Generic fallbacks signal vendor-who-didn't-research; per-lead values are the quality lever.
10. Add subsection "Available filters and conditionals" — reproduce EB's documented list: `strip`, `downcase`, `capitalize`, `default`, `date`, `plus`, `contains`. Note the case-sensitivity gotcha verbatim.
11. Close with a "Cross-reference" line pointing to `plugins/marketing/tools/integrations/email-bison.md` § Liquid + spintax + whitespace (Task 7).

**Verification:**
- `grep -c "{% assign" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥6 (canonical patterns reproduced)
- `grep -c "help.bisonsphere.com/en/articles/184" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥1
- `grep -c "shopify.github.io/liquid/basics/whitespace" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥1
- Section is variable-agnostic (does not enumerate "high-risk variables" by name) — content is pattern-focused
- Liquid local lowercase-naming rule explicitly stated

### Task 2 — Update Skeleton A + Skeleton B in SKILL.md to USE Liquid pattern

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Location:** § Methodology subsection "Base template skeletons (2, entity-agnostic, inline)" — Skeleton A at lines 121-139, Skeleton B at lines 141-159.
**Estimated time:** 25-35 min
**Implementation:**

1. **Skeleton A — list-building base.** Wrap `{RECENCY_ANCHOR}` with Pattern A (assign + filter chain) at the top of the body. The keystone failure mode (BC-6308 R-2b empty-render) is per-lead RECENCY_ANCHOR. Use whitespace-stripped `{%- -%}` form. Replace mid-body `{RECENCY_ANCHOR}` with `{{ recency }}`. Add a one-line comment in the spec prose above the skeleton: "The `{%- assign -%}` line at top demonstrates the canonical Liquid + filter-chain fallback for per-lead variables; preset authors and future generators inherit this pattern. Add additional `{%- assign -%}` lines for any other per-lead variable that needs graceful fallback. See § Liquid + spintax for graceful per-lead fallback for full pattern reference."

   Resulting Skeleton A (illustrative shape — author final form during execution):
   ```
   Subject: {Quick|Fast|30s} {question|check|idea}

   Body:
   {%- assign recency = '{RECENCY_ANCHOR}' | strip | default: 'recent activity at your organization' -%}
   Saw the {{ recency }} at {COMPANY} {FIRST_NAME}, and {it lined up|it tracked closely|it mapped well} with a pattern we've been watching across {VERTICAL_DESCRIPTOR}.<br><br>...
   ```

2. **Skeleton B — risk-reversal base.** Same treatment. Wrap `{RECENCY_ANCHOR}` with Pattern A. Whitespace-controlled. Replace body reference with `{{ recency }}`.

3. **Step 2 bumps for both skeletons.** The current Step 2 bumps don't reference `{RECENCY_ANCHOR}` directly, so no Liquid wrapping needed. Leave Step 2 bumps unchanged.

4. **Spec prose context.** In the prose above each skeleton (currently "Used for T1 / T2 framing..." and "Used for T4 framing..."), add a sentence: "The base skeleton uses Liquid + filter-chain fallback for the per-lead variable most likely to be empty (`{RECENCY_ANCHOR}`); see § Liquid + spintax for graceful per-lead fallback to extend the pattern to additional variables."

5. **No fallback-quality compromise.** The default fallback string for `{RECENCY_ANCHOR}` should NOT be an obvious quality-drop. "recent activity at your organization" is acceptable; "your recent stuff" is not. Author final string during execution; the goal is "okay-ish if hit, signals nothing if not hit."

**Verification:**
- `grep -c "{%- assign recency" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥2 (Skeleton A + Skeleton B)
- `grep -c "{{ recency }}" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥2
- Skeleton A + B still pass all other format rules (no em-dashes, no `<p>`, no `{FIRST_NAME}` in subject, exactly 2 steps each)
- Spec prose above each skeleton names the Liquid pattern usage and cross-references the new § Liquid + spintax for graceful per-lead fallback section

### Task 3 — Update SKILL.md § Anti-Slop `{{` rule to allow Liquid output

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Location:** § Anti-Slop Guardrails (around line 432-453), the bullet currently reading "Do not emit `{{variable}}` double-brace tokens."
**Estimated time:** 10-15 min
**Implementation:**

1. Replace the existing bullet with a tightened rule that catches the typo class but allows Liquid output:

   > **Do not emit `{{TOKEN}}` double-brace EB-token typos.** Email Bison requires single-brace uppercase variables (`{FIRST_NAME}`). The double-brace form `{{FIRST_NAME}}` (uppercase identifier, no internal spaces) is a typo — EB does NOT resolve it; it renders as literal text in delivery. Detection regex: `\{\{[A-Z_]+\}\}`. If a draft contains this pattern, self-correct to single-brace before emit. Hard failure if present in the written artifact.
   >
   > **Liquid output `{{ var }}` is allowed and required for the Liquid fallback patterns** (see § Liquid + spintax for graceful per-lead fallback). Liquid local variables MUST be lowercase (snake_case acceptable). The lowercase-required rule is what makes the typo regex unambiguous: `{{FIRST_NAME}}` (uppercase, no spaces) gets caught; `{{ name }}` (lowercase, space-padded) passes.

2. Add a corresponding rule clarifying the Liquid local naming: "Liquid local variable names MUST be lowercase (snake_case acceptable). Uppercase Liquid locals collide with the EB-token-typo detection regex and are forbidden in this codebase by convention."

**Verification:**
- `grep -c "{{TOKEN}}" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥1 (rule wording references the typo shape)
- `grep -c "Liquid output \`{{ var }}\` is allowed" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥1 (or equivalent prose)
- `grep -c "lowercase (snake_case" plugins/marketing/skills/email-copywriting/SKILL.md` returns ≥1
- Existing "self-correct to single-brace" prose preserved but scoped to the typo class only

### Task 4 — Relax launch-campaign Phase 1 step 5 with 5th resolution path

**File:** `plugins/marketing/commands/launch-campaign.md`
**Lines:** Step 5 currently spans line 212-217.
**Estimated time:** 25-35 min
**Implementation:**

1. After the existing 4th bullet (`{SENDER_*}` variable resolution path, line 216), add a 5th bullet: "OR the variable is referenced via Liquid in `step_1.body` or `step_2.body` with a documented fallback shape — specifically, one of: (a) wrapped in an `{% assign %}` block whose filter chain includes `default: '<non-empty-string>'` (e.g., `{%- assign name = '{TOKEN}' | strip | default: 'fallback' -%}`), (b) referenced inside a truthy `{% if local_var %}` block whose `{% else %}` clause is non-empty and contains either fallback prose or spintax, OR (c) referenced inside a `{% if '{TOKEN}' contains '...' %}` keyword-branch block whose `{% else %}` clause is non-empty."
2. Update the HALT prose (line 217) to acknowledge the 5th path: "**HALT** if any variable fails all five checks." Change "fail-closed behavior is the near-term backstop" to "fail-closed behavior is the safety net" (Liquid path is no longer "near-term," it's load-bearing).
3. Update the long-term-direction note: change "until the smart-merge formula layer (BC-6557) ships the deeper context-aware fallback" to "graceful per-lead fallback is now handled via Liquid syntax (BC-6613) — see `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback." Remove the BC-6557 reference (canceled, superseded by BC-6613).
4. Reference the canonical EB doc URL (article 184) inline as the authoritative source for the supported fallback shapes.
5. Cross-link to `plugins/marketing/tools/integrations/email-bison.md` § Liquid + spintax + whitespace (Task 7).
6. Per BC-6298 task-1 + BC-6544 task-1 plan-gate scope-expansion: search the rest of `launch-campaign.md` for other BC-6557 references; if found, surface as a scope-expansion question at execution time (not in this plan) — likely candidates: notes about smart-merge formula, deferred fallback work.

**Verification:**
- `grep -c "BC-6557" plugins/marketing/commands/launch-campaign.md` returns 0 in step 5 prose; if other locations exist, surface scope decision at execution time
- `grep -c "BC-6613" plugins/marketing/commands/launch-campaign.md` returns ≥1 in step 5 prose
- Step 5 prose lists exactly 5 numbered or bulleted resolution paths
- HALT message updated to "all five checks"

### Task 5 — Tighten Phase 1 step 6 messaging sanity checklist `{{` rule

**File:** `plugins/marketing/commands/launch-campaign.md`
**Lines:** Step 6 currently spans line 218-225 — specifically the bullet "No `{{variable}}` double-brace tokens anywhere in step_1 or step_2 subject/body."
**Estimated time:** 10-15 min
**Implementation:**

1. Replace the existing bullet with a tightened rule that mirrors Task 3's anti-slop fix:

   > No `{{TOKEN}}` double-brace EB-token typos in subject or body. Detection regex: `\{\{[A-Z_]+\}\}` (uppercase identifier, no internal spaces). Liquid output `{{ var }}` (lowercase identifier, space-padded) is allowed in body — required for the Liquid fallback patterns. Subjects MUST NOT contain Liquid output (existing convention: no merge variables in subject lines).

2. Cross-link to `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback so operators reading the sanity checklist can find the full pattern reference.

**Verification:**
- `grep -c "{{TOKEN}}" plugins/marketing/commands/launch-campaign.md` returns ≥1 (in step 6 prose)
- Step 6 prose explicitly allows Liquid output `{{ var }}` in body, forbids in subject
- Cross-link to SKILL.md § Liquid + spintax for graceful per-lead fallback section present

### Task 6 — Add option (b) clarifying note to launch-campaign Phase 1 step 8

**File:** `plugins/marketing/commands/launch-campaign.md`
**Lines:** Step 8 currently spans line 232.
**Estimated time:** 15-20 min
**Implementation:**

1. After the existing step 8 prose, append a clarifying note: "**Liquid blocks are not evaluated in the local spot-check.** EmailBison evaluates Liquid (`{% assign %}`, `{% if %}`, `{{ }}`) server-side at send time, after EB substitutes `{TOKEN}` references. The local spot-check renders only the EB-substitution layer — `{TOKEN}` references get replaced with CSV values, but Liquid blocks remain visible in the preview as raw text. To verify Liquid evaluation end-to-end, use `--test-send <your-email>` (Phase 10 Mode 2), which sends a real email through EB's render pipeline and lands in your inbox with the final rendered output."
2. Update the existing operator-facing call-out from "Spintax rendered with first-option pick for deterministic preview; actual sends will rotate options." to also include: "Liquid blocks visible in this preview will be evaluated by EmailBison at send time — use `--test-send` to verify Liquid output before activation."

**Verification:**
- `grep -c "Liquid blocks are not evaluated" plugins/marketing/commands/launch-campaign.md` returns ≥1
- `grep -c "test-send" plugins/marketing/commands/launch-campaign.md` returns ≥3 (existing references + new ones in step 8)
- Note explicitly references Phase 10 Mode 2 by name

### Task 7 — Add Liquid + spintax + whitespace section to email-bison.md

**File:** `plugins/marketing/tools/integrations/email-bison.md`
**Estimated time:** 30-40 min
**Implementation:**

1. Find a sensible insertion point in the file's structure (likely near § Known gotchas or § Tool inventory, since the section is reference content).
2. Add new H2 section `## Liquid + spintax + whitespace`
3. Open with one-paragraph context: EB's render engine supports Liquid templating + spintax. Per the substitution-order rule, EB token substitution runs FIRST, then Liquid evaluates. Authors writing per-lead fallback patterns rely on this ordering.
4. Subsection "Authoritative sources":
   - EmailBison article 184: https://help.bisonsphere.com/en/articles/184-liquid-syntax-spintax-how-to-use-and-templates
   - Shopify Liquid whitespace docs: https://shopify.github.io/liquid/basics/whitespace/
5. Subsection "Canonical patterns" — reproduce the four core EB patterns verbatim:
   - Pattern A (assign + filter chain fallback)
   - Pattern B (conditional + spintax composition)
   - Pattern C (keyword-branched value-prop)
   - Pattern D (whitespace-stripped compact form)
6. Subsection "Documented filters" — reproduce EB's filter list verbatim (`strip`, `downcase`, `capitalize`, `default`, `date`, `plus`, `contains`).
7. Subsection "Documented gotchas":
   - Substitution order: EB substitutes `{TOKEN}` before Liquid parses
   - Case-sensitivity: `contains` is case-sensitive — chain `downcase` before comparison
   - Whitespace: every uncontrolled `{% ... %}` line prints a blank line; use `{%- -%}`
   - `{% if '{TOKEN}' == 'value' %}` must quote the EB token; `{% if local_var %}` does not require quotes (truthy check on assigned local)
   - Liquid local variables in this codebase MUST be lowercase (snake_case acceptable) per anti-slop typo-detection convention — see SKILL.md § Anti-Slop Guardrails
8. Subsection "Cross-references":
   - `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback (Task 1)
   - `plugins/marketing/commands/launch-campaign.md` Phase 1 step 5 (gate-relax accepting Liquid fallback as resolution path, Task 4)

**Verification:**
- `grep -c "Liquid + spintax" plugins/marketing/tools/integrations/email-bison.md` returns ≥1
- `grep -c "help.bisonsphere.com/en/articles/184" plugins/marketing/tools/integrations/email-bison.md` returns ≥1
- `grep -c "shopify.github.io/liquid" plugins/marketing/tools/integrations/email-bison.md` returns ≥1
- All four canonical patterns reproduced
- Lowercase-Liquid-local convention named with cross-reference to SKILL.md

### Task 8 — Add discoverability pointer in 3 preset files (optional, 5-second touch)

**Files:**
- `plugins/marketing/skills/email-copywriting/presets/list-building-ski-resorts.md`
- `plugins/marketing/skills/email-copywriting/presets/list-building-casinos.md`
- `plugins/marketing/skills/email-copywriting/presets/risk-reversal-sports-stadiums.md`

**Estimated time:** 5 min total (3 files × 1 min each)
**Implementation:**

In each preset, add ONE line in the frontmatter or just below the H2 title — whichever lands cleanest in that preset's existing structure: `<!-- Liquid + spintax fallback patterns: see plugins/marketing/skills/email-copywriting/SKILL.md § Liquid + spintax for graceful per-lead fallback -->`

This is a discoverability aid only. The preset bodies are NOT being rewritten in this PR. Holden's hand-coded scaffolds stay as-is. Future authors editing these files (or the eventual handbook-sync feature inheriting their structure) find the pointer when they open the file.

**Verification:**
- `grep -l "Liquid + spintax fallback patterns" plugins/marketing/skills/email-copywriting/presets/*.md | wc -l` returns 3 (one per preset file)

### Task 9 — Bump marketing plugin version

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json` — bump `"version"` from `0.3.22` → `0.3.23`
- `.claude-plugin/marketplace.json` — bump marketing plugin row's `"version"` from `0.3.22` → `0.3.23`

**Estimated time:** 5 min
**Implementation:** Edit both files in same commit per BC-6000 cache-invariant rule. Patch bump is correct — this is additive scope (new section + new resolution path + relaxed regex), not a breaking schema change.

**Verification:**
- Both versions match `0.3.23` after edit
- `git diff` shows exactly two version-bump edits
- Bump rides in same commit as Tasks 1-8 (BC-6000 rule)

### Task 10 — Run validation scripts

**Estimated time:** 5-10 min
**Implementation:**

1. From repo root: `./scripts/validate.sh` — must exit 0
2. From repo root: `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — must exit 0
3. If either fails, fix the cited issue and re-run

**Verification:** Both scripts exit 0.

---

## Verification checklist (full PR)

- [ ] All 10 tasks complete
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0
- [ ] Marketing plugin version bumped in BOTH `plugins/marketing/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (BC-6000)
- [ ] SKILL.md § Liquid + spintax for graceful per-lead fallback is variable-agnostic — does not enumerate which specific tokens to wrap
- [ ] Skeleton A + Skeleton B in SKILL.md USE the Liquid + filter-chain pattern on `{RECENCY_ANCHOR}` with `{%- -%}` whitespace control
- [ ] SKILL.md § Anti-Slop `{{` rule allows Liquid `{{ var }}` (lowercase, space-padded) while still catching `{{TOKEN}}` typos (uppercase, no spaces)
- [ ] launch-campaign.md Phase 1 step 5 lists exactly 5 resolution paths
- [ ] launch-campaign.md Phase 1 step 6 sanity checklist `{{` rule mirrors anti-slop fix
- [ ] launch-campaign.md Phase 1 step 8 note explicitly points operators to `--test-send` for Liquid evaluation
- [ ] BC-6557 references in launch-campaign.md replaced with BC-6613 references in step 5 prose; other locations surfaced as scope-expansion questions if found
- [ ] email-bison.md cross-links exist in both directions (SKILL.md and launch-campaign.md)
- [ ] All 3 preset files have the one-line discoverability pointer comment
- [ ] No new MCP servers, no new dependencies, no new infrastructure

---

## Out of scope (deferred to follow-up issues)

- **Liquid-aware validator** (issue scope item 4) — defer until BC-6554 round-4 walks the patterns. File a follow-up issue at ship time naming the validator's expected shape based on dogfood findings.
- **Preset file body rewrites** — Holden's scaffolds will be replaced by the planned handbook-sync feature. Pattern is taught at the skeleton level instead.
- **Per-lead enrichment pipeline changes** — BC-5537 / BC-2727 territory.
- **Variable substitution-order changes** — current EB behavior is correct; leave alone.
- **Wrap-every-variable mechanical sweep** — variable-agnostic spec teaches the pattern; preset authors and future generators apply by judgment. If future presets need a sweep, it rides a separate issue.
- **Subject-line Liquid** — EB's existing rule is "no merge variables in subject lines." Liquid in subjects out of scope.
- **Handbook-sync feature for vertical content** — not yet scoped; long-term replacement for Holden's hand-coded scaffolds. Tracked separately.
