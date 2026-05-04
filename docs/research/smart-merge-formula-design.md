---
issue: BC-6557
title: Smart-merge formula layer for content variables — research/design
status: research/design
date: 2026-05-04
related_issues:
  - BC-6549  # original framing, superseded by BC-6556 + BC-6557
  - BC-6556  # near-term backstop (fail-closed gate at launch)
  - BC-6308  # round-3 dogfood walk where empty-render finding (R-2b) surfaced
  - BC-5537  # Brite enrichment MCP scaffold (per-lead raw value source)
  - BC-2717  # list-building skill (consumer of enrichment outputs)
  - BC-2727  # data-enrichment skill (per-lead value producer)
---

# Smart-merge formula layer — research/design

## Context

In the BC-6308 round-3 launch-campaign dogfood walk (2026-04-30), test finding R-2b confirmed that Email Bison's render engine substitutes any unresolved or null content variable token as an empty string — silently. A campaign with a custom variable like `{RECENCY_ANCHOR}` whose default is unset and whose per-lead value is null sends the email with that token rendered as nothing at all, producing visible double-spaces, orphan punctuation, and broken sentence flow. EB does not error, warn, or surface the missing data anywhere in the campaign UI.

The near-term backstop shipped in [BC-6556](https://linear.app/brite-nites/issue/BC-6556): a fail-closed validation gate at launch time. If any custom variable in a copy artifact has an empty `default` field, the launch halts. This guarantees that *something* always renders in place of the token, but it forces the operator to write a single campaign-level fallback string per variable — the same string for every lead in the campaign, regardless of context. (The fail-closed gate's spec at `plugins/marketing/commands/launch-campaign.md` line 217 already names this issue, BC-6557, as the deeper context-aware fallback that supersedes the gate.)

The long-term direction came from a 2026-05-01 conversation with Holden during BC-6549 analysis: each custom variable should support a small per-lead **formula** that produces a clean rendered string even when that lead's raw value is missing. Conceptually similar to a Clay-style merge column — if the raw value exists for this lead, use it; if not, evaluate a fallback expression that produces something contextually appropriate. The formula evaluates per lead at upload time, before EB ever sees the value, so EB itself stays unchanged.

This document is the **research/design deliverable** for that formula layer. The scope is intentionally bounded to **design + prototype, not build**: a Python prototype demonstrates the formula language works against sample lead data, but production wiring into the launch-campaign code path is a separate follow-up issue, deferred until this design is reviewed.

## Architecture

The formula layer has two distinct parts that live in different places, owned by different skills, and only need to agree on a shared schema: where the formula **runs**, and where the formula **gets written**.

**Formula execution — `launch-campaign` Phase 4.** The formula has to evaluate per lead, just before the lead's payload is uploaded to Email Bison via `bulk_create_leads`. That's the only point in the codebase that has both (a) the lead's per-row data and (b) the EB upload boundary. Evaluating earlier means we don't yet have the per-lead context; evaluating later means EB already sees the unrendered token. Phase 4 is the only structurally correct home for the engine.

**Formula definition — copy artifact JSON, authored by `email-copywriting`.** The fallback string's quality depends overwhelmingly on the variable's surrounding sentence ("Hey there," works because of the leading `Hey ` and trailing `,`; "a similar team" works because it sits after `was {PROOF_POINT_COMPANY}`). Only the template author has full visibility into that surrounding context. The `email-copywriting` skill already produces the copy artifact JSON with a `custom_variables[]` array; the formula extends that same array as a new optional field per variable. Authoring lives where the template lives.

These two parts are independent. The execution engine doesn't care who wrote the formula; the authoring skill doesn't care when or how the formula is evaluated. They share only the schema (defined in the next section).

### Data flow

```
lead row (CSV)             copy artifact (JSON)
       │                          │
       ▼                          ▼
  raw value | null   ─┬─►   formula definition
                      │
                      ▼
            ┌─────────────────────┐
            │  formula evaluator  │   ← runs in launch-campaign Phase 4
            │  (use_raw / fallback)│     just before bulk_create_leads
            └─────────┬───────────┘
                      ▼
              rendered string
                      │
                      ▼
        custom_variables[].value (per-lead)
                      │
                      ▼
                 EB upload  ─►  EB render at send time
```

EB itself never sees a formula. Every per-lead value it receives is already a fully rendered string. EB's job stays unchanged — it substitutes the value into the template body the same way it does today.

### Out of scope: raw-column population

Producing the per-lead raw value in the first place is a separate concern. Today, lead lists usually arrive without per-lead values for variables like `{RECENCY_ANCHOR}` — operators hand-type one campaign-level default that applies to every lead. In the future world Holden's enrichment work ([BC-5537](https://linear.app/brite-nites/issue/BC-5537), [BC-2727](https://linear.app/brite-nites/issue/BC-2727)) builds toward, an enrichment pipeline produces per-lead raw values where it can and emits null where it can't.

This document does not specify how those raw values are produced or normalized. Smart-merge **consumes** raw values; it does not **produce** them. The boundary is clean: enrichment fills the column (or leaves it null); the formula handles whatever it gets.

### Rejected alternative homes

We considered four alternatives to email-copywriting as the authoring location and rejected each:

- **`list-building` skill** ([BC-2717](https://linear.app/brite-nites/issue/BC-2717)) — owns the lead list, knows the raw values it produces. But doesn't see the template, so can't pick fallback strings that fit a specific sentence position. **Wrong layer.**
- **`campaign-orchestration` skill** ([BC-2718](https://linear.app/brite-nites/issue/BC-2718)) — campaign-level decisions, not template-level. Formulas are template-tied. **Wrong layer.**
- **`launch-campaign` runtime authoring** — the launch command generates fallbacks at execution time. Pushes authoring into execution, where it should be reviewable + stable beforehand. **Wrong stage.**
- **A new dedicated formula-authoring skill** — decouples formula authoring from template authoring, which means templates can drift from formulas (someone updates a sentence, formula's surrounding-context assumption goes stale). **Adds drift risk for no benefit.**

A fifth option survives as a refinement, not an alternative: **preset files extend to carry suggested formulas per vertical.** When `email-copywriting` generates an artifact for a list-building / ski-resorts campaign, it consults the preset for vertical-tuned fallback suggestions. The skill remains the authoring authority; the preset is a starter library.

## Formula language

A formula is a small object attached to a custom variable's definition. It tells the evaluator what to do when computing that variable's per-lead rendered value. v1 supports three operations.

### Operations

**1. `use_raw` — implicit, always applies first.**

If the lead has a non-null, non-empty value for this variable in their per-lead data, use that value as-is. This is the universal first step of every formula evaluation; authors don't write it explicitly.

Example: lead has `RECENCY_ANCHOR = "Q3 capital plan announcement"` → rendered string is `Q3 capital plan announcement`.

**2. `substitute_static` — fallback string when raw is missing.**

When `use_raw` doesn't apply (raw is null, empty, or fails the `valid_if` predicate below), the formula's `if_missing` field provides a fallback string. The string can contain references to other variables (subject to the no-cascading rule below); those references resolve through the existing render engine before the rendered value is finalized.

Example: variable `RECENCY_ANCHOR` has formula `{ "if_missing": "{VERTICAL_DESCRIPTOR} programming" }`. Lead has `RECENCY_ANCHOR = null`, campaign has `VERTICAL_DESCRIPTOR = "village"` → rendered string is `village programming`.

Example with literal-only fallback (no variable references): variable `FIRST_NAME` has formula `{ "if_missing": "there" }`. Lead has `FIRST_NAME = null` → rendered string is `there`.

**3. `valid_if` — optional quality predicate.**

A predicate that decides whether the raw value is "good enough" to use. If the predicate returns false, the formula treats raw as missing and falls through to `if_missing`. Defaults to "raw is non-null and non-empty," which is the implicit baseline; authors only write `valid_if` when they need stricter validation.

Example: variable `PROOF_POINT_COMPANY` has formula `{ "if_missing": "a similar team", "valid_if": "raw not in ['LLC', 'Inc', 'Corp']" }`. Lead has `PROOF_POINT_COMPANY = "LLC"` → predicate fails → rendered string is `a similar team`.

The exact predicate language is a v1-prototype design decision. The prototype implements `valid_if` as a small allowlist of safe operations (membership check, length check, regex match) rather than arbitrary code, so that copy artifacts stay declarative and reviewable.

### Rules

**The no-cascading rule.** Fallback strings in a formula's `if_missing` field can reference campaign-level variables (which BC-6556's launch-time gate guarantees are non-empty) and built-in CSV-row variables (`{COMPANY}`, `{FIRST_NAME}`, `{LAST_NAME}`, `{JOB_TITLE}`, `{EMAIL}`, populated from the lead's row), but they MUST NOT reference other per-lead variables that have their own formulas.

The rule exists to avoid two failure modes: (1) cascading empty-render — formula A's fallback references variable B, which is also null, leaving the empty-render bug unfixed one level deeper; (2) the need for cycle detection in the evaluator — if A's fallback references B and B's fallback references A, we'd need runtime cycle detection. The simpler rule sidesteps both. v2 may lift the rule once recursive evaluation is designed and a cycle-detection strategy is in place.

**The belt-and-suspenders rule.** The variable's `default` field MUST remain non-empty even when a `formula` is also present. Both fields coexist; the formula wins at evaluation time, but the `default` is the rollback path: disabling the formula engine at any future point causes every variable to fall back to its `default`, with no campaign breakage.

This rule is enforceable at copy-artifact-validation time (the same place BC-6556's gate already runs). Authors writing a formula are still required to write a sensible `default`; the formula simply produces a richer rendered string when the engine is active.

### Render-order pseudocode

For each `(variable, lead)` pair at evaluation time:

```
def render_value(variable, lead, campaign):
    raw = lead.custom_values.get(variable.name)            # may be None or ""
    formula = variable.formula                              # may be None

    # Step 1 — check raw against valid_if (default predicate: non-null and non-empty)
    valid = (raw is not None and raw != "")
    if formula and formula.valid_if:
        valid = valid and evaluate_predicate(formula.valid_if, raw)

    if valid:
        return raw                                          # use_raw path

    # Step 2 — formula's if_missing fallback (variable-references resolved through render engine)
    if formula and formula.if_missing:
        return render_string(formula.if_missing, lead, campaign)

    # Step 3 — bare default (always present per belt-and-suspenders rule)
    return variable.default
```

Three guarantees follow from this order: (a) raw value wins when available and valid; (b) formula's fallback wins over `default` when raw is missing or invalid; (c) `default` is the always-present floor — the engine never returns null or empty.

## Schema

The smart-merge layer extends the existing `custom_variables[]` array in the copy artifact JSON. The change is purely additive: a new optional `formula` field per variable, alongside the existing `default` field. Existing copy artifacts continue to work without modification.

### Today (BC-6556 baseline)

```json
{
  "custom_variables": [
    {
      "name": "RECENCY_ANCHOR",
      "default": "downtown master-plan announcement"
    },
    {
      "name": "PROOF_POINT_COMPANY",
      "default": "Boulder Pearl Street"
    }
  ]
}
```

Each variable has exactly two fields: `name` and `default`. BC-6556's launch-time gate enforces that `default` is non-empty. EB renders the value of `default` for every lead in the campaign — the same string for everyone.

### Tomorrow (BC-6557 + BC-6556)

```json
{
  "custom_variables": [
    {
      "name": "RECENCY_ANCHOR",
      "default": "recent activity",
      "formula": {
        "if_missing": "{VERTICAL_DESCRIPTOR} programming"
      }
    },
    {
      "name": "PROOF_POINT_COMPANY",
      "default": "a similar team",
      "formula": {
        "if_missing": "{LABS_PEER_VENUE}",
        "valid_if": "raw not in ['LLC', 'Inc', 'Corp']"
      }
    },
    {
      "name": "FREE_ASSET_NOUN",
      "default": "production-finance deck"
    }
  ]
}
```

Each variable still has `name` and `default`. A new optional `formula` object may be present. When the formula engine is active and a variable has a `formula`, the engine evaluates per lead per the render-order pseudocode in the previous section. When the formula is absent (e.g., `FREE_ASSET_NOUN` above), evaluation reduces to today's behavior — use raw if present, otherwise `default`.

### Field reference

| Field | Required | Allowed types | Notes |
|---|---|---|---|
| `name` | Yes | string | Uppercase token name (e.g., `RECENCY_ANCHOR`). Same as today. |
| `default` | **Yes — must be non-empty** | string | Rollback floor. Used when neither raw nor formula resolves to a value. Belt-and-suspenders rule. |
| `formula` | No | object | Optional. When present, engine evaluates it before falling through to `default`. |
| `formula.if_missing` | If `formula` present | string | Fallback string. May reference campaign-level variables and built-in CSV-row variables; may NOT reference other per-lead variables with formulas (no-cascading rule). |
| `formula.valid_if` | No | string predicate | Optional quality check on raw. Defaults to "non-null and non-empty." Stricter checks use the prototype's allowlist (membership, length, regex). |

### Migration

The change is **additive and non-breaking**. No existing copy artifact requires modification. An artifact written under today's BC-6556 schema parses identically under tomorrow's schema; the formula engine simply has nothing to evaluate (no `formula` field present) and falls through to `default`, which is exactly today's behavior.

When the email-copywriting skill is updated (separate ticket) to author formulas, new artifacts gain `formula` fields. Old artifacts shipped before that update continue to work indefinitely without any rewrite.

The required-non-empty-`default` rule already exists today (BC-6556). The smart-merge layer simply preserves it — never relaxes it. An author writing a richly-specified formula is still required to write a sensible `default` as the rollback floor.

## Examples

Worked examples for the four priority variables. For each, we show: the variable's real template position (citing the preset file where applicable), what empty-render looks like today, the recommended formula in schema form, and the rendered output for two cases — when the lead has a per-lead raw value, and when raw is null.

Two of the four are **forward-looking** — they don't currently appear as per-lead variables in production presets, but they're plausible in a per-lead enrichment world (which is BC-6557's design horizon). Those are noted inline.

### Example 1 — `RECENCY_ANCHOR`

**Template position** (`plugins/marketing/skills/email-copywriting/presets/list-building-ski-resorts.md`, step 1 body opener):

> Hey {FIRST_NAME}, saw {COMPANY}'s {RECENCY_ANCHOR} and figured I'd reach out before the season sets.

**Empty-render today:** `Hey Sam, saw Acme's  and figured I'd reach out before the season sets.` (visible double-space + broken sentence flow.)

**Recommended formula:**

```json
{
  "name": "RECENCY_ANCHOR",
  "default": "recent activity",
  "formula": {
    "if_missing": "{VERTICAL_DESCRIPTOR} programming"
  }
}
```

**Renders:**

| Lead state | Rendered string | Final email opener |
|---|---|---|
| `RECENCY_ANCHOR = "village expansion announcement"` | `village expansion announcement` | `Hey Sam, saw Acme's village expansion announcement and figured I'd reach out before the season sets.` |
| `RECENCY_ANCHOR = null`, `VERTICAL_DESCRIPTOR = "village"` | `village programming` | `Hey Sam, saw Acme's village programming and figured I'd reach out before the season sets.` |

The fallback references `VERTICAL_DESCRIPTOR`, a campaign-level variable guaranteed non-empty by BC-6556. This is a clean per-lead → campaign-level fallback path. The reader gets a coherent sentence in both cases.

### Example 2 — `PROOF_POINT_COMPANY` (forward-looking)

**Note:** This variable is **not present in current production presets.** Real presets use `{LABS_PEER_VENUE}` as a single campaign-level proof variable. `PROOF_POINT_COMPANY` appears in the BC-6308 dogfood test template and is plausible in a future per-lead enriched world where each lead gets a vertical-tuned proof venue chosen at enrichment time. The example below is forward-looking design.

**Template position (forward-looking):**

> ...one that solved it was {PROOF_POINT_COMPANY}, who saw a meaningful lift.

**Empty-render today (forward-looking):** `...one that solved it was , who saw a meaningful lift.`

**Recommended formula:**

```json
{
  "name": "PROOF_POINT_COMPANY",
  "default": "a similar team",
  "formula": {
    "if_missing": "{LABS_PEER_VENUE}",
    "valid_if": "raw not in ['LLC', 'Inc', 'Corp', 'Co']"
  }
}
```

**Renders:**

| Lead state | Rendered string | Final clause |
|---|---|---|
| `PROOF_POINT_COMPANY = "Yaamava Casino"` | `Yaamava Casino` | `...one that solved it was Yaamava Casino, who saw a meaningful lift.` |
| `PROOF_POINT_COMPANY = "LLC"` (fails `valid_if`) → falls through to formula | `Boyne SkyBridge` (campaign-level `LABS_PEER_VENUE`) | `...one that solved it was Boyne SkyBridge, who saw a meaningful lift.` |
| `PROOF_POINT_COMPANY = null` | `Boyne SkyBridge` | `...one that solved it was Boyne SkyBridge, who saw a meaningful lift.` |

This example exercises both `if_missing` and `valid_if`: a corrupted-looking raw ("LLC") gets caught by the predicate and falls through to the same fallback as a null. The fallback references `LABS_PEER_VENUE`, a campaign-level variable that's always populated.

### Example 3 — `SPECIFIC_FRICTION` (forward-looking)

**Note:** Same forward-looking caveat as Example 2 — `SPECIFIC_FRICTION` appears in the BC-6308 dogfood template, not in current production presets. Plausible in a per-lead enriched world where enrichment finds an industry- or company-specific friction signal per lead.

**Template position (forward-looking):**

> Most {VERTICAL_DESCRIPTOR} teams we work with run into {SPECIFIC_FRICTION}, and one that solved it was...

**Empty-render today (forward-looking):** `Most ski-resort teams we work with run into , and one that solved it was...`

**Recommended formula:**

```json
{
  "name": "SPECIFIC_FRICTION",
  "default": "the same operational ceiling",
  "formula": {
    "if_missing": "the {VERTICAL_DESCRIPTOR} ancillary-revenue ceiling"
  }
}
```

**Renders:**

| Lead state | Rendered string | Final clause |
|---|---|---|
| `SPECIFIC_FRICTION = "F&B tenant retention"` | `F&B tenant retention` | `Most ski-resort teams we work with run into F&B tenant retention, and one that solved it was...` |
| `SPECIFIC_FRICTION = null`, `VERTICAL_DESCRIPTOR = "ski-resort"` | `the ski-resort ancillary-revenue ceiling` | `Most ski-resort teams we work with run into the ski-resort ancillary-revenue ceiling, and one that solved it was...` |

The fallback composes the campaign-level `VERTICAL_DESCRIPTOR` into a phrase that reads naturally in the friction position.

### Example 4 — `FIRST_NAME`

**Template position** (all production presets — appears in the greeting of every step 1 body):

> Hey {FIRST_NAME}, ...

**Empty-render today:** `Hey , ...` (empty space + comma — visibly broken greeting.)

**Note:** `FIRST_NAME` is an EB built-in variable populated from the lead's CSV row `first_name` column, not a per-lead custom variable. It doesn't strictly need a formula — it has different resolution rules (per `launch-campaign.md` § Variable-presence check). But for completeness, designing the formula schema to support it gives a uniform fallback shape across all variables and future-proofs the system if `FIRST_NAME` is ever surfaced via custom variables (e.g., for a campaign that imports leads from a non-CSV source).

**Recommended formula:**

```json
{
  "name": "FIRST_NAME",
  "default": "there",
  "formula": {
    "if_missing": "there"
  }
}
```

**Renders:**

| Lead state | Rendered string | Final greeting |
|---|---|---|
| `first_name = "Sam"` (CSV row) | `Sam` | `Hey Sam, ...` |
| `first_name = ""` or null | `there` | `Hey there, ...` |

The fallback is a literal-only `there` — no variable references needed. This is the simplest formula shape and covers the most common per-lead empty case (incomplete lead lists). The renderer never produces "Hey , ..."

### Summary across the 4 examples

| Variable | Fallback type | References other variables | Quality predicate |
|---|---|---|---|
| `RECENCY_ANCHOR` | Variable-referencing | `{VERTICAL_DESCRIPTOR}` (campaign-level) | No |
| `PROOF_POINT_COMPANY` | Variable-referencing + predicate | `{LABS_PEER_VENUE}` (campaign-level) | Yes (allowlist filter) |
| `SPECIFIC_FRICTION` | Variable-referencing | `{VERTICAL_DESCRIPTOR}` (campaign-level) | No |
| `FIRST_NAME` | Literal-only | None | No |

All four exercise the no-cascading rule cleanly — every fallback either references a campaign-level variable (always non-empty) or is a literal string. None reference another per-lead variable with its own formula.

### Prototype evidence

A working Python prototype (`docs/research/smart-merge-prototype.py`) implements the render-order pseudocode and exercises every formula behavior against sample data. Inputs:

- `docs/research/smart-merge-sample-leads.csv` — 5 leads spanning every fallback path (full-data, single-variable null, multi-variable null, `valid_if`-fail with corrupted raw, mostly-null lead)
- `docs/research/smart-merge-sample-variables.json` — variable definitions for the 4 priority variables, exercising all 3 verbs

Run command:

```bash
python3 docs/research/smart-merge-prototype.py \
  --leads docs/research/smart-merge-sample-leads.csv \
  --variables docs/research/smart-merge-sample-variables.json
```

Two leads from the rendered output, showing raw-present vs. raw-missing cases:

**Lead 1 — all per-lead values populated (raw path):**

```
--- Lead 1: sam@killington.com ---
Hey Sam, saw Killington Resort's $3B village master plan and figured I'd reach out before the season sets.
Most ski-resort teams we work with run into F&B tenant retention, and one that solved it was Killington Village.
Best,
Amanuel
```

Every variable used its raw per-lead value. No formula path fired.

**Lead 4 — `PROOF_POINT_COMPANY = "LLC"` (fails `valid_if`) and `SPECIFIC_FRICTION = null`:**

```
--- Lead 4: taylor@chamonix.com ---
Hey Taylor, saw Chamonix Casino's $600M Sky Tower and figured I'd reach out before the season sets.
Most ski-resort teams we work with run into the ski-resort ancillary-revenue ceiling, and one that solved it was Boyne SkyBridge.
Best,
Amanuel
```

`PROOF_POINT_COMPANY = "LLC"` failed the predicate `raw not in ['LLC', 'Inc', 'Corp', 'Co']` and fell through to the formula's `if_missing`, which references the campaign-level `{LABS_PEER_VENUE}` ("Boyne SkyBridge"). `SPECIFIC_FRICTION = null` fell through to its own variable-referencing fallback, "the {VERTICAL_DESCRIPTOR} ancillary-revenue ceiling," resolving to "the ski-resort ancillary-revenue ceiling." Both fallback paths produce a coherent sentence; neither re-introduces an empty token.

**What the prototype demonstrates:** the 3-verb formula language plus variable-referencing fallbacks produces clean rendered emails for both raw-present and raw-missing cases. The `valid_if` predicate catches data-quality issues (raw is non-null but bad — "LLC" as a company name) and routes them through the same fallback path as a true null. The belt-and-suspenders rule (every variable has a non-empty `default` even alongside a richer `formula`) is enforced at evaluation time — any variable missing a `default` raises a `ValueError` rather than rendering blank.

The prototype also surfaced one real implementation insight worth carrying into the production engine: the order of precedence in the final template substitution must be **resolved formula values > built-in CSV-row fields > campaign-level variables.** Overlaying raw CSV columns after formula resolution would silently clobber the resolved fallback (a custom variable's raw value would overwrite the formula's resolved output). The prototype's `render_lead` function documents and enforces this precedence; the production engine should do the same.

## Migration

The smart-merge layer ships with **no flag day, no breaking change, and no required action on existing campaigns.** Schema-level migration details live in the previous § Schema § Migration; the broader operational story is:

- **Existing copy artifacts** continue to work unchanged. An artifact written today (BC-6556 schema, just `name` + `default`) parses identically tomorrow under the BC-6557 schema. The formula engine has nothing to evaluate (no `formula` field present) and falls through to `default`, which is exactly today's behavior.
- **Currently-running campaigns** are not impacted. Campaigns already in EB are upstream of the formula engine — the engine only runs at upload time during a fresh launch. Live campaigns continue sending whatever they were authored to send.
- **email-copywriting skill changes** are a separate ticket, not part of BC-6557. The skill begins authoring formulas only after that ticket lands. New artifacts produced post-change get formulas; old artifacts continue working without rewrite.
- **List-building / enrichment changes** are also out of scope for BC-6557. Per-lead raw values arrive however the upstream pipeline produces them. Smart-merge consumes whatever shape arrives.

The migration is best framed as: this design adds a new optional capability that activates only when authors opt in by writing a `formula` field. Until that opt-in happens, every campaign behaves exactly as it does under BC-6556 today.

## Rollback

Almost every decision in this design is reversible without breaking anything. The table below maps each design choice to its rollback path.

| Design decision | Rollback path | Reversibility |
|---|---|---|
| The `formula` field added to copy artifact schema | Stop writing `formula` fields; engine ignores any present; campaigns fall back to `default`. No data migration required. | High — purely additive |
| Two verbs (`use_raw` + `substitute_static`) | Adding more verbs later is non-breaking (forward-compatible schema). Removing a verb after authors started using it is harder, but the engine can gracefully ignore unknown verbs and fall through to `default`. | High — schema is additive |
| Optional `valid_if` quality predicate | Defaults to "non-null and non-empty." If we drop it from the schema, formulas that didn't use it keep working unchanged. | High — invisible by default |
| The no-cascading rule (constraint, not behavior) | Lifting the rule (allowing recursive formula evaluation) is a v2 enhancement; existing formulas that obeyed it keep working. The rule is a constraint that only excludes certain authoring patterns; lifting it is non-breaking. | High — lifting a constraint is non-breaking |
| Presets carry suggested formulas | Pure convention layer. If preset suggestions don't get adopted, just stop adding formula sections to presets. No code commitment. | High — documentation/convention only |
| email-copywriting as sole author | If we need to split authorship later (e.g., enrichment side owns `valid_if`), schema extends additively; existing formulas keep working. | High — additive |
| The whole formula approach turns out wrong | Stop writing `formula` fields globally; engine ignores; campaigns fall back to `default` (which is required non-empty per the belt-and-suspenders rule). Same behavior as today's BC-6556 baseline. | High — design-level off-switch |

### Big-picture rollback path

If at any future point smart-merge formulas turn out to be the wrong direction, the rollback recipe is:

1. **Stop writing `formula` fields** in new copy artifacts (single change to the email-copywriting skill).
2. **Disable the formula engine** in launch-campaign Phase 4 (single feature-flag-style change to the engine: short-circuit the formula path and always use `default`).
3. **Old artifacts with `formula` fields keep working** — the engine ignores them; the variable's `default` (required non-empty per belt-and-suspenders) is the rendered value.
4. **No data migration. No campaign breakage. No required rewrite of existing artifacts.**

This rollback path is bulletproof precisely because of the belt-and-suspenders rule: every variable has a non-empty `default`, regardless of whether it also has a `formula`. The `default` is the rollback floor.

### What ISN'T reversible

The one thing rollback can't undo: **time and effort spent building the engine + prototype + email-copywriting skill changes.** Sunk-cost lives with the implementation team. This document and its prototype are cheap, so the bounded cost of pursuing this design through the research/design phase is low. The full implementation cost is gated by the deferred follow-up ticket (which is the explicit point at which "should we actually build this?" gets answered with knowledge of the full design).

## Out of scope

The following capabilities are explicitly excluded from v1 to keep the formula language tight and shippable. Each item has a concrete revisit trigger — a measurable condition that, when observed in production, justifies promoting the item to the v2 design discussion.

**1. Drop-neighborhood verb** — cut the variable AND specified surrounding chars (e.g., `Hey {FIRST_NAME},` → `Hey,` when FIRST_NAME is empty).
*Revisit when:* substitute_static fallbacks consistently produce awkward results that would read better with a deletion-style fix, AND a concrete production template demonstrates the substitute path can't recover. Holden's "remove the space and put a comma" framing is the canonical case.

**2. Drop-clause verb** — cut the entire surrounding clause when the variable is empty.
*Revisit when:* a production template surfaces with multiple correlated per-lead variables in a single clause where every-variable-substituted reads worse than dropping the clause entirely. The BC-6308 dogfood test template's 3-variable proof-point sentence is the prototype case, but it's not in current production.

**3. Conditional logic across variables** — formula reads other variables' raw values to decide its own output (e.g., "if FIRST_NAME is null AND COMPANY is null, use 'Hi there'; else use 'the COMPANY team'").
*Revisit when:* substitute fallbacks for two or more variables in the same template repeatedly produce inconsistent renderings that would benefit from coordinated logic. v1 keeps each variable's formula independent.

**4. Multi-tier fallback** — formula tries multiple fallback strategies in order (try variable-reference → try static → try a third option).
*Revisit when:* a single fallback per variable proves insufficient AND a clear waterfall pattern emerges across multiple variables. v1 collapses to a single `if_missing` path; multi-tier becomes a structured array if/when needed.

**5. Recursive formula evaluation** — fallback strings reference other per-lead variables with their own formulas, evaluated recursively with cycle detection.
*Revisit when:* the no-cascading rule's restriction (fallbacks can't reference other per-lead variables with formulas) consistently blocks valuable authoring patterns. Adding recursion requires a cycle-detection design that v1 deliberately doesn't include.

**6. Format transformations** — apply text transforms to raw or rendered values (capitalize, lowercase, truncate, regex replace).
*Revisit when:* the upstream enrichment / list-building pipeline produces values that need standardization at the merge step rather than at the source. v1's stance: enrichment normalizes upstream; smart-merge consumes already-normalized values.

## Open questions

The following decisions are surfaced explicitly for **Holden's review** before this design progresses to implementation. Each question identifies an architectural choice where alternative answers would change the design materially.

**1. Does the home pick (formula execution at `launch-campaign` Phase 4, formula definition in copy artifact JSON authored by `email-copywriting`) match the intent you had in mind?**

The Architecture section walks the alternatives and rejects them, but the home pick is the single biggest architectural decision in this design. If you'd prefer the formula engine to live elsewhere — e.g., as a feature of the Brite enrichment MCP ([BC-5537](https://linear.app/brite-nites/issue/BC-5537)) so that per-lead raw value production and per-lead fallback evaluation happen in the same layer — that flips much of the architecture. The current pick assumes enrichment produces raw values, smart-merge consumes them; an MCP-side formula layer would couple the two.

**2. Is the no-cascading rule acceptable for v1, or do you want recursive formula evaluation from day one?**

v1 forbids fallback strings from referencing other per-lead variables with their own formulas. That sidesteps cycle detection and prevents cascading empty-render. Recursive evaluation is more expressive (a fallback can fall back to another formula's fallback) but requires cycle-detection infrastructure that v1 deliberately doesn't include. If you want recursion as a first-class feature, the v1 verb count grows and the engine pseudocode adds a recursion-with-cycle-detection layer.

**3. Should `valid_if` be authored by `email-copywriting` alone (v1 plan), or split with the enrichment side?**

`valid_if` is about data quality (is this raw value good enough to use?) — that knowledge plausibly belongs upstream with whoever produces the value, not downstream with whoever frames it in a sentence. v1's stance is unified authorship for simplicity (`email-copywriting` writes the whole formula including `valid_if`, drawing from preset suggestions for known bad-data patterns). Splitting authorship — enrichment owns `valid_if`, email-copywriting owns `if_missing` — gets more right-people-knowing-right-things but adds schema-merge logic and authoring coordination.

**4. Implementation issue spawn is deferred pending your review.**

The acceptance criteria for BC-6557 list "Implementation issue filed (separate ticket) with concrete tasks based on the deliverable." That AC is **deferred** for this session, by design — filing the implementation ticket before you've reviewed the design risks locking in details (home pick, verb set, schema shape) that you may want changed. The expected sequence: review this design → adjust if needed → file the implementation ticket with the agreed-upon details. The ticket itself should be quick to file once the design is settled (~10 minutes), so the deferral is low-cost.

## Sources

<!-- Task 12 — to be written (Linear URLs + production preset paths + dogfood evidence) -->
