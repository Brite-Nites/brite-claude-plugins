# Design: FDA Journey/Story Template Re-Alignment

**Status**: Locked via grill-with-docs session (2026-05-30, session 4) — ready to implement
**Author**: holden + Claude
**Parent**: `docs/designs/fda-quality-enforcement.md` (epic BC-11983) — this is a **WS-E precursor**: it fixes the authoring templates before WS-E re-authors the remaining repos.
**Scope**: flow-architecture plugin only (agents + the templates the plugin seeds into consumers + a regression-lock). **No handbook PR** — the handbook templates are already canonical/correct.

---

## Problem

The FDA authoring agents (`journey-doc-author`, `story-doc-author`) emit a doc structure that has **drifted from the canonical handbook templates** (`about-handbook/style-guide/templates/{domain-journey,job-story}.md`). The canonical templates already encode BriteBase gold and align with external craft standards (NN/g journey-mapping 5-component model; Klement JTBD job stories; EARS constraint-spec for non-human actors; DITA/SSOT index-not-restate). The drift means generated docs lose rubric-scored sections the canonical provides.

### Root cause (two layers)

1. **Missing consumer template file.** Each author reads `template_path = docs/templates/<journey|job-story>.md` from the **consumer repo**. brite-sites has no such file (its `docs/templates/` holds only a `brite-nites` entry), so the author fell back to the agent's *prose* description of the template.
2. **Drifted agent prose.** The agents' own in-body description of the template ("Q26/Q27 mod" structure) has diverged from the canonical handbook template, so even the fallback is wrong.

### Observed drift (brite-sites docs, merged PR #32)

**Journey** — lost `Decision points`, journey-level `Out of scope`, `Open questions` (buried inside the FDA-only `L2 review summary`); replaced `Scenario + Expectations` with `Narrative shape`; *added* `Sub-flows`, a consolidated `Job stories` table, and **domain-level** `Pain points`/`Opportunities` that duplicate the per-phase content.

**Story** — dropped the rich frontmatter (`children:{}`, per-discipline `*_status`, `qa_status`, URLs), the `Preconditions` section, and the `QA history` table; buried `Out of scope` inside `Actor`. (It *added* two genuinely good things: `Status notes` for partial/drift, and an evidence-anchor `Status` section grounding claims in real `file:symbol` refs.)

The rubric (`quality-rubric.md`) already scores to the canonical — `J6` *is* "Decision points," `J8` *is* "Open questions" — yet the drifted template gives an author no home for them.

---

## Resolved model (grill decisions)

| # | Decision | Rationale |
|---|---|---|
| **D1** | **Canonical handbook template is the spine.** Re-align both authoring agents to it; adjudicate each agent deviation as fold-back-vs-discard. Keep only deviations that demonstrably improve on the canonical. | The canonical already encodes gold + NN/g + Klement; the rubric grades to it; BriteBase proves it at 28-domain scale. Drift is the bug-of-record. |
| **D2** | **Journey body collapses to canonical.** Per-phase pain/opps/job-story tables ONLY. Drop the standalone `Sub-flows`, the consolidated `Job stories` table, and domain-level `Pain points`/`Opportunities`. Restore `Scenario + Expectations`, nesting the Profile-D two-arc framing inside it. | Removes restate-duplication (DITA/SSOT: index once). Matches BriteBase/NN-g. |
| **D3** | **Story frontmatter = full canonical** (amended 2026-05-30 — see note). Adopt the complete canonical frontmatter incl. per-discipline `eng_status/design_status/docs_status/qa_status` + `children:{}` + `sandbox_url`/`staging_url`/`real_app_url`/`e2e_test` + `figma`. | The per-discipline status fields are **not idle duplication** — `regenerate-flow-index.mts` renders the `INDEX.md` delivery grid (`Eng/Design/QA/Docs/Live` columns) directly from them, and the audit grid reads `qa_status`. Omitting them silently blanks those dashboards to defaults. Linear stays the **orchestration** SoT; the frontmatter is the **published delivery-state mirror** the INDEX renders, refreshed at discipline-completion / `/flow:ship`. |

> **D3 amendment (2026-05-30, implementation-time).** Originally locked as "hybrid: omit volatile per-discipline/QA state." During implementation the gate map showed `regenerate-flow-index.mts` (`INDEX.md` grid) + the audit discipline grid read those exact fields from story-doc frontmatter, defaulting silently to `not-started`/`not-tested` when absent. Omitting them would gut the cross-domain delivery dashboard. Flipped to **full canonical frontmatter** with the mirror framing. Side effect: `normalize-fda-frontmatter.mjs`'s existing contract (which already carries these fields) needs no change.
| **D4** | **Story sections: restore `Preconditions` + `QA history`; promote `Out of scope / no-gos` to its own section; KEEP the FDA additions** (`Status notes` conditional, evidence-anchor `Status`). | Preconditions feed the Given clauses (BDD); QA history is the in-doc surface for D3's Linear-SoT QA state; the evidence-anchor section directly serves D10 (no-fabrication) + D5 (honest status). |
| **D5** | **Journey frontmatter = same hybrid** (derived from D3): adopt `domain`, `milestone: BC-XXXX`, `personas[]`, `flow_ids_in_scope[]`, `status` (doc-authoring lifecycle, NOT delivery), `figma`; keep FDA's `linear_project_id` + `intent`. | Stable refs in, volatile state out. |
| **D6** | **Sequence: template-first → re-pass brite-sites → the 6.** Ship the plugin fix (agent re-align + seed canonical templates into consumers + regression-lock) first; re-pass brite-sites (content already gold — mechanical reshape); then run the 6 remaining repos on the corrected template. | The template is the leverage point. brite-sites is the reference repo and must stay exemplary; leaving it the lone outlier is incoherent. |

**Kept agent deviations (improvements folded into the canonical):** (a) the Profile-D **two-arc narrative** (nested inside `Scenario + Expectations`); (b) the FDA-additive **`L2 review summary`** section (additive only — does *not* absorb `Open questions`, which returns to its own canonical section); (c) story-doc **`Status notes`** + **evidence-anchor `Status`** sections.

---

## Target structures

### Domain journey (`docs/product/journeys/<domain>.md`)

Frontmatter: `domain · milestone: BC-XXXX · personas[] · flow_ids_in_scope[] · status (authoring lifecycle) · figma · last_reviewed · linear_project_id · intent`

```
# <DOMAIN>: <Display name>
> Doc-type banner (1:1 with Linear milestone)
## Title + domain code
## Actor / Persona
## Scenario + Expectations          (Profile-D two-arc framing nested here)
## Journey phases                   (4–8, verb-led)
   ### Phase N — <verb-led name>
       *Persona* / *Mindset*
       narrative (~2 paragraphs)
       **Pain points** (root-caused)
       **Opportunities** (scoped: v1 vs deferred, tracked)
       | job-story table: id · title · status · 📄 link |
## Decision points                  (sometimes; J6)
## Out of scope
## Related domains and cross-scenario journeys   (J4)
## Open questions                   (J8 — own section, NOT inside L2 review)
## See also
## L2 review summary                (FDA-additive; Q46 writeback target)
```

### Sub-flow story doc (`docs/product/flows/<domain>/<flow-id>.md`)

Frontmatter (full canonical + FDA `intent`): `flow_id · domain · status · parent_issue · children:{story,eng,design,qa,docs} · personas[] · related_flows[] · figma · sandbox_url · staging_url · real_app_url · e2e_test · user_docs_url · qa_status · qa_last_signed_off · eng_status · design_status · docs_status · last_reviewed · intent`
— per-discipline + qa status are the **published delivery-state mirror** feeding `INDEX.md` (Linear = orchestration SoT). `children:{}` backfilled once `flow-linear-scaffold` creates the 5N issues.

```
# <DOMAIN-NN>: <Inventory title>
> one-line mechanical-contract summary (D8)
## Job story                        (human JTBD OR constraint-spec per D11/EARS)
## Status notes                     (FDA-additive; only when partial/drift)
## Actor
## Preconditions                    (≤3 bullets)
## Acceptance criteria              (3–5 Gherkin; grounded; NOT_BUILT labeled)
## Out of scope / no-gos            (own section; names owning flow IDs — D6)
## Status                           (FDA-additive: rollup verdict + file:symbol
                                     evidence anchors + per-flow open questions)
## Cross-references
## QA history                       (curated mirror; Linear QA child is SoT)
```

---

## The fix (plugin-side, one PR)

1. **Re-align agent prose** — rewrite the template-structure description in `agents/journey-doc-author.md` (step 1 + Conventions) and `agents/story-doc-author.md` (steps 1/6/7 + Conventions) to the canonical section sets above, so the fallback path is correct. Update the agent `description:` frontmatter to match.
2. **Seed the canonical templates into consumers** — ship `docs/templates/{domain-journey,job-story}.md` (structurally aligned to the handbook canonical **+ the approved FDA-additive sections** per the Target structures above — *not* byte-equal; the FDA template folds in `L2 review summary`, `Status notes`, the evidence-anchor `Status`, conditional `Cross-domain dependencies`, and inline rubric-citation guidance) via the plugin's `templates/` so retrofit/scaffold copies them into each consumer repo. Copy point: both orchestrators' Phase 1 templates-scaffold, alongside the `verify-docs.sh` ecosystem copy per Q58.
3. **Regression-lock** — a `validate.sh` section (clone the `2bN` lib+fixture pattern) asserting: journey template contains `## Decision points` + `## Open questions` as first-class sections; story template contains `## Preconditions` + `## QA history`; the agent prose enumerates the canonical section order (catchphrase + structural-clause + negative-case triad per `pattern-rubric-lock-grep-triad`). Two-surface awareness (`gotcha-fda-story-frame-gates-two-surfaces`): if `fidelity-reviewer` checks section *order*, its expected order list must be updated too.
4. **Cross-check the rubric** — confirm `quality-rubric.md` J6/J8/D-dims still describe sections that now exist in the template (they should — this *closes* the template↔rubric gap, not opens one).
5. **Same-commit version bump** — `plugins/flow-architecture/.claude-plugin/plugin.json` + the `marketplace.json` entry (CLAUDE.md cache-staleness gotcha).

**Q-record mapping (corrected during implementation):** this is **not** a Q26/Q27 amendment — Q16 sub-decision 1 + Q15 already lock the canonical section sets; the agents had *drifted from their own locks*. So it records as: (a) a **drift correction** restoring `journey-doc-author`/`story-doc-author` to the Q15/Q16 canonical-section order; (b) a **Q58 amendment 2** extending the templates-scaffold copy manifest 9 → 11 (seed the two doc templates into consumers — the missing-template-file root cause); (c) a small FDA-additive (the evidence-anchor `## Status` section, grill D4). Recorded in `docs/design-rationale/fda-plugin-interview.md` § Q58 amendment 2.

## Blast radius / sequencing (D6)

```
1. PLUGIN PR  — agent re-align + seed canonical docs/templates/ + regression-lock + version bump
2. RE-PASS brite-sites (37 docs) — structural reshape to canonical (content already gold)
3. WS-E ×6 repos — content re-author + canonical structure in one pass
   (brite-roster · brand-hub · brite-labs-site · brite-supply-react · brite-pim · brite-lseo;
    last two need the diagnosis sub-phase first)
```

## Open items (resolve at implementation)

- **`children:{}` backfill timing.** Story docs may be authored before `flow-linear-scaffold` creates the 5N children. Confirm the FDA phase order; if docs precede children, define the backfill step (or leave `children:` as `TBD` placeholders the scaffold fills).
- **`plan-story` fold** (inherited open question #1 from the parent design doc). With the WHAT fully front-loaded into the story doc, is `plan-story` left thin? Adjacent to this work; decide separately before WS-B B-3.
- **`Title + domain code` section** — canonical keeps it; it is near-redundant with the H1. Kept for fidelity-reviewer section-order fidelity; revisit if it adds noise.
