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

<!-- Task 6 — to be written; prototype evidence appended in Task 11 -->

## Migration

<!-- Task 7 — to be written -->

## Rollback

<!-- Task 7 — to be written -->

## Out of scope

<!-- Task 8 — to be written (with revisit triggers per item) -->

## Open questions

<!-- Task 8 — to be written (Holden as named reviewer) -->

## Sources

<!-- Task 12 — to be written (Linear URLs + production preset paths + dogfood evidence) -->
