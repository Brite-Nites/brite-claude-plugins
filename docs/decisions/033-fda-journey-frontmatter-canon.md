# 033. FDA journey-doc frontmatter canon

**Status:** Accepted
**Date:** 2026-06-11
**Linear:** [BC-13028](https://linear.app/brite-nites/issue/BC-13028) (journey deterministic-stamp residual) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** [029](029-fda-canonical-flow-doc-key.md) (the story-side canonical-key sibling — whose "template wins, real docs converge" outcome this ADR consciously **inverts** for the `milestone` field).

## Context

FDA journey docs (`docs/product/journeys/<domain>.md`) carry front-matter consumed by `flow-regen-index` (milestone → INDEX section-header link, per Q18.1) and gated by `fidelity-reviewer` (required fields derived from the template). Before a deterministic stamper could be extracted (the journey half of BC-13028 #4; the story half shipped in BC-13168), the schema itself had to be pinned — three sources disagreed:

| Source | `milestone` shape | `domain` form | Notable |
|---|---|---|---|
| `flow-journey-author` §1 | `milestone: BC-XXXX` ("scaffold output") | unspecified | no `linear_project_id`; `intent: ../intent.md` |
| `domain-journey.md` template | `milestone: BC-XXXX` | `<DOMAIN>` uppercase | declares `linear_project_id`; `intent: ../../intent.md` |
| Real brite-roster docs (7, the only populated examples) | `linear_milestone: {name, id: UUID}` | kebab + `display_name` | extras: `l2_reviewed`, `related_domains`, primary/secondary persona split |

A Linear milestone is identified by a UUID — it **cannot** carry a BC number (the scaffold-log's milestone row records the UUID as its identifier). `milestone: BC-XXXX` and `intent: ../../intent.md` are copy-paste artifacts from the story-doc template (story docs sit two directory levels under `docs/product/`; journeys sit one). And the INDEX consumer constructs a milestone **URL**, which requires the UUID. For these fields the real docs are the fix, not the deviation — the inverse of ADR-029's situation, where the template was canonical and the real-doc reshapes were drift.

## Decision

The canonical journey front-matter schema is **9 keys, in this exact order**:

```yaml
---
domain: identity-directory
display_name: Identity & Directory
linear_milestone:
  name: Identity & Directory
  id: 3484e0d9-ce7c-41ae-b639-ff068778ba96
personas: [operator, tm]
flow_ids_in_scope: [IDN-01, IDN-02]
status: in-progress
figma: TBD
intent: ../intent.md
last_reviewed: 2026-06-11
---
```

Field rulings:

- **`linear_milestone: {name, id}`** — the nested real-doc shape, `name` before `id`. The UUID is what the INDEX milestone-link construction needs; the key name says *Linear* milestone.
- **`linear_project_id` is dropped.** Zero consumers read it from the journey doc; the sole would-be consumer (`flow-regen-index`) reads `.flow/config.json` directly. Duplicating config state into N docs is N drift surfaces.
- **`domain` is the kebab folder-slug + `display_name` carries the human name.** The slug is the journey's join key (frontmatter == filename stem == scaffold-log name == `related_domains` cross-refs, mechanically lintable); the uppercase code is a *flow-namespace* concept that is derivable from `flow_ids_in_scope` and stays the story-doc convention per ADR-029. The two doc types have different primary identities; matching their `domain:` value-forms would be surface consistency over a semantic mismatch.
- **`personas` / `flow_ids_in_scope` are aggregated deterministically from the domain's story-doc front-matter** (standardized since BC-13168; the journey author runs after `flow-doc-author` per Q16.8, so the docs always exist): `flow_ids_in_scope` = the story docs' `flow_id` values natural-sorted by numeric suffix; `personas` = first-seen dedup walking that order. Zero story docs → exit 2 (an ordering-contract violation fails loud, never stamps honest-empties).
- **`status` is the doc-authoring lifecycle** (`not-started | in-progress | shipped`, initial `in-progress`) — deliberately NOT the story-doc build taxonomy (`NOT_STARTED`…). Do not "fix" it to uppercase.
- **`intent: ../intent.md`** — journeys are one level under `docs/product/`.

Stamped by `scripts/build_journey_frontmatter.py` — a **separate, self-contained** builder (the story builder's core is scaffold-log *table* parsing; the journey's is scaffold-log *front-matter* + story-doc aggregation — they share no parsing core, so a `--kind` union was rejected). Locked by `tests/run-journey-frontmatter-vslice.sh` (golden + populated-key assertions). `journey-doc-author` is body-only; the skill stamps front-matter via the builder and concatenates.

## Consequences

- `flow-regen-index` reads `linear_milestone.id` (+ `.flow/config.json` project id) for the INDEX section-header milestone-link; its SKILL §1/§4 and the `fda-plugin-interview.md` Q18.1 source line are updated in this change (the surgical lock-edit this ADR authorizes). The `start-project`/`retrofit-project` Phase-1 templates-scaffold parentheticals and the Q58 lock prose — which claimed the journey template's `linear_project_id` was the sed pass's one substituted token — are reconciled in the same change.
- The `domain-journey.md` template front-matter block becomes the canon above; `fidelity-reviewer` follows the template automatically.
- The GOLD-doc extras (`l2_reviewed`, `related_domains`, the `primary_persona`/`secondary_personas` split) are **tolerated out-of-plugin extensions**, not canon — they require editorial judgment a deterministic builder cannot make; converging them is BC-13152-class work, out of scope.
- A fresh scaffold now emits populated journey front-matter (real milestone UUID, real personas/flow lists) instead of LLM-side placeholders — the journey-side close of the BC-13028 #4 silent-return family.

## Rejected alternatives

- **`milestone: BC-XXXX` (template):** structurally impossible — a Linear milestone has no BC number, and the INDEX link needs the UUID.
- **Flat `linear_milestone_id`/`linear_milestone_name` pair (scaffold-log key mirror):** diverges from all 7 real docs (instant schema drift) and nothing keeps the pair traveling together.
- **Keep `linear_project_id`:** a field with zero consumers, maintained forever.
- **Uppercase `domain:` on journeys:** matches the story convention but mismatches every real doc, the filename, the scaffold-log, and the cross-reference form — and loses the display name.
- **Caller-param `--personas`/`--flow-ids` (the story-builder pattern):** leaves the aggregation as unlocked LLM judgment — the exact silent-placeholder class #4 exists to kill. The story builder's params rationale (unstandardized inventory) does not apply: the journey's source is the now-standardized story docs.
