# 029. Canonical FDA flow-doc identity key is `flow_id`/`DOMAIN-NN`

**Status:** Accepted
**Date:** 2026-06-10
**Linear:** [BC-13028](https://linear.app/brite-nites/issue/BC-13028) (Tier-0 status/frontmatter cluster) · [BC-13152](https://linear.app/brite-nites/issue/BC-13152) (kebab→canonical convergence) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** none (FDA-internal convention). Supersedes the unshipped `020-fda-central-doc-templates` draft, which never landed — see Consequences.

## Context

FDA story docs (`docs/product/flows/<domain>/<flow-id>.md`) carry a front-matter identity key. The tooling reads it to build `INDEX.md` (`templates/scripts/regenerate-flow-index.mts`) and to resolve Linear references (`templates/scripts/verify-linear-references.mts`). Two conventions exist in the wild:

| Convention | Key fields | ID style | Repos (flow docs) |
|---|---|---|---|
| **Canonical** | `flow_id` + `parent_issue` | `DOMAIN-NN` (e.g. `PROD-08`) | brite-base (427), brite-roster (41) |
| Deviation | `sub_flow_id` + `linear_parent_issue` | kebab (e.g. `lead-capture-02`) | brite-supply-react (32), brite-labs (22) |

The canonical doc template (`templates/docs/templates/job-story.md`), brite-base GOLD, and the regen reader all key on `flow_id`/`parent_issue`. The kebab `sub_flow_id` form arose in two WS-E consumer repos authored against a divergent convention.

A 2026-06-10 re-baseline (during the BC-11997 step-away generator-fixes workstream) considered teaching the tooling to read `sub_flow_id ?? flow_id` (a convention-agnostic bridge — the premise of BC-13082) so the deviation repos' INDEX regen would pass. That would have entrenched two parallel naming conventions inside the canonical plugin.

## Decision

**`flow_id`/`DOMAIN-NN` (with `parent_issue`) is the single canonical FDA flow-doc identity convention.** The plugin tooling reads `flow_id`/`parent_issue` only — it is **not** made bilingual.

- The doc template, the authoring agents, the regen, and `verify-linear-references` all key on `flow_id`/`parent_issue`.
- The two kebab/`sub_flow_id` deviation repos (brite-supply-react, brite-labs) **converge** to canonical (tracked in BC-13152) — rather than the tooling accommodating them.
- `normalize-fda-frontmatter.mjs` stays a documented no-op skeleton in the plugin (not a live bridge); it is the natural starting point for the convergence migration.

## Consequences

- The plugin stays single-convention — no `??` fallback, no two-dialect tooling to maintain.
- A fresh scaffold produces `flow_id`/`DOMAIN-NN` docs that the regen reads correctly with no INDEX-drift gap, so the "6th/7th WS-E repo regenerates the gap" concern does not apply to the identity key.
- BC-13082 (teach the regen `sub_flow_id`) is **canceled** as wrong-direction.
- Until BC-13152 runs, brite-supply-react + brite-labs keep hand-maintaining their `INDEX.md` (their existing workaround); the canonical tooling does not regress them — it simply does not index their kebab docs.
- **Template distribution (related):** the unshipped `020-fda-central-doc-templates` draft (centralize templates + drop the per-repo seed) is **shelved/superseded.** The templates already auto-seed into consumers on plugin ≥ 1.2.13, which solves the original "repos hand-seed" problem without the central-repoint complexity (which carried a real risk: filesystem-only authoring agents cannot expand `${CLAUDE_PLUGIN_ROOT}` themselves). That draft never landed in `docs/decisions/`, and the integer `020` is held by an unrelated GTM ADR. Recorded here for the avoidance of doubt; disposition tracked in BC-13028.

## Rejected alternatives

- **Convention-agnostic reader (`sub_flow_id ?? flow_id`, `linear_parent_issue ?? parent_issue`):** tolerates two naming dialects indefinitely and entrenches the deviation in the canonical plugin. Rejected — the deviation repos converge instead (BC-13152).
- **Hard-switch the canonical to kebab `sub_flow_id`:** would break brite-base (427 docs) + brite-roster (41) + every existing `flow_id` consumer. Rejected.
- **Populate `normalize-fda-frontmatter.mjs` as a live bridge in the scaffold path:** adds a build step + a silent-failure surface; unnecessary once the canonical convention is enforced. Rejected — it stays a no-op migration aid.
