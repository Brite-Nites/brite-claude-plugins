# 032. GTM canonical Discovery ICP layer — per-vertical, segments-only, mandatory

**Status:** Accepted
**Date:** 2026-06-04
**Linear:** [BC-11163](https://linear.app/brite-nites/issue/BC-11163)
**Related ADRs:** [ADR-012](012-gtm-campaign-unit.md) (campaign unit + slug composition), [ADR-016](016-gtm-plugin-side-canonicals.md) (plugin-side canonicals), [ADR-020](020-gtm-campaign-manifest-schema-v2.md) (campaign manifest v2)
**Design session:** grilled 2026-06-04 (PR #432); glossary terms in repo-root `CONTEXT.md`

## Context

An ICP has two halves that the GTM stack consumed from different — and unequally
covered — homes:

- **Contact half** (personas + title cascades): `plugins/marketing/data/canonicals/{vertical}.yaml`.
  Covered for all 27 registered verticals.
- **Discovery half** (industries + geo + size band + signals + exclusions — "which
  companies are in this market?"): covered for only the **6 playbook verticals**
  (`references/vertical-playbooks/`). For the other 21, `tam-mapping` requires a
  hand-authored per-campaign `--criteria-file` ICP JSON, and nothing in
  `/marketing:plan-campaign` resolved this at scaffold time — operators discovered
  the gap weeks later when tam-mapping hard-stopped (observed on the
  flagship-retail / shopping-centers FY26-M07 campaign, BC-11163).

Per-campaign authoring also meant the discovery criteria for a vertical were
re-derived (or hand-copied, then drifted) on every subsequent campaign in that
vertical.

## Decision

1. **Per-vertical canonical home.** The Discovery ICP lives at
   `plugins/marketing/data/canonicals/icp/{vertical}.json`, sibling to
   `{vertical}.yaml`. Campaign-specific narrowing happens in a campaign-scoped
   copy, never upstream.

2. **Segments-only shape.** The file contains `segments: { "<name>": {block} }`
   and no base block. Each segment is a **self-contained** Discovery ICP (no
   inheritance/merge semantics) naming exactly one account universe, with a
   `persona` cross-reference to the contact cascade it pairs with. A
   single-audience vertical is the one-segment case. A campaign spanning two
   account universes uses two segments — two tam runs, two lists — never a
   unioned criteria block (disjoint firmographics cannot be scored together).

3. **Mandatory + lint-enforced.** Every vertical registered in `_manifest.yaml`
   MUST have an icp file (ERROR level in `lint_canonicals.py`). The stub form is
   structurally distinguishable from the ready form: empty `segments` ⇔
   non-empty `clarifications_needed` (enforced biconditional — no honor-system
   flags). Segment `persona` refs must resolve to a persona slug in the sibling
   `{vertical}.yaml`.

4. **Collapsed single-source resolution.** `/marketing:plan-campaign` resolves
   the ICP source from the vertical icp file only — reporting `ready` or
   `stub — author before list-build` — with no playbook branch, no MISSING
   state, and no campaign-level stub scaffolding. The 6 playbooks remain prose
   source material cited by their stubs; tam-mapping's playbook auto-load path
   stays as legacy for manual runs.

5. **Uniform per-segment campaign copies.** At scaffold, chosen segment blocks
   are flattened to the criteria-file root and copied to
   `docs/campaigns/{entity}/tam/{slug}/{segment}/icp.json` — per-segment subdir
   even for single-segment campaigns, so tam-mapping's file-existence resume
   detection works per segment unchanged. Chosen segments are recorded as an
   optional `segments[]` array in the campaign `manifest.json` (schema v2 is
   open at the top level; the property is added to `#/definitions/campaign_manifest`).

6. **Segment block schema.** The `icp-definition.md` keys verbatim
   (`industries`, `geo`, `size_band`, `tech_signals`, `intent_signals`,
   `exclusions` — so the flattened copy parses in the `tam-map/*_client.py`
   scripts without change) plus `display`, `persona`, and
   `seed_accounts: [{name, domain?}]`. Seed accounts are durable market
   knowledge and live at the vertical level; campaign copies may prune/extend.

7. **Renamed verticals resolve via aliases.** `flagship-retail` (merged into
   shopping-centers as a segment per Head of GTM, 2026-06-01) becomes
   `aliases: [flagship-retail]` on `shopping-centers.yaml`. The already-live
   FY26-M07 campaign keeps its lived slug across Linear/EB/SF; its manifest says
   `vertical: shopping-centers`. No external renames.

## Alternatives rejected

- **Per-campaign ICP home** (status quo formalized): every campaign in a
  vertical re-authors or hand-copies the criteria; segment knowledge evaporates
  after each campaign. Rejected for drift.
- **Base block + optional segment overrides:** dual shape forces two code paths
  in every consumer, and sparse-override merge semantics are where stdlib
  scripts grow deep-merge bugs. A "broad vertical" base for shopping-centers
  would also have required inventing a canonical persona that doesn't exist.
- **Optional icp files (WARN-level or campaign-triggered enforcement):**
  weakens the invariant; conditional lint complexity; the silent-failure class
  (dangling persona refs, missing criteria discovered at list-build time) is
  exactly what this repo's gotchas exist to prevent.
- **Playbook/criteria-file dual resolution order:** two sources for one fact;
  the 6 playbook verticals would never get structured criteria. Collapsing to
  one mandatory home makes "ready vs stub" the only state distinction.
- **Flat copy path when single-segment** (`tam/{slug}/icp.json`): two output
  shapes means every downstream glob branches. Uniform per-segment subdirs cost
  one documentation-line change in tam-mapping's SKILL.md.
- **Extending the icp.json parse schema to hold multiple audience blocks:**
  honest model for dual-universe campaigns but changes tam-mapping's parse
  contract and all three `tam-map/*_client.py` scripts. Segments + two runs
  achieve the same separation with zero script changes.

## Consequences

- This change ships 27 icp files: shopping-centers real (two segments:
  `flagship-brands` → `vp-marketing`, `destination-centers` →
  `center-owner-asset-manager`), 26 schema-valid stubs with `source` pointers
  and operator-fill `clarifications_needed`.
- `/marketing:new-vertical` scaffolds the stub icp file alongside the yaml
  (`canonicals_bootstrap.py vertical` → `_create_icp_stub`, shipped with this
  change; the lint presence check is the backstop).
- `docs/marketing-context.md` remains the one system-wide missing input
  (entity half) — tracked as a follow-up issue; plan-campaign WARNs per
  scaffold until it lands.
- After PR #429 (Clay lead-list spec) merges, its `lead-list.md` "ICP /
  account filters" section should render from the campaign's per-segment
  criteria-files (one drafting source, two renderings).
