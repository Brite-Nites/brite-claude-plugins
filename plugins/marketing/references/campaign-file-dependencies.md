# Campaign file-dependency map

What `/marketing:plan-campaign` → `tam-mapping` → `list-building` actually read,
per ADR-024. Three inputs back any campaign; this table says which file backs
each, who creates it, and whether it already exists for your vertical.

## The 3 inputs → their backing files

| Input | Backing file(s) | Scope | Created by |
|---|---|---|---|
| 1. Entity | `docs/marketing-context.md` | One file, shared by every campaign | `/marketing:product-marketing-context` (once) — or pass `--entity` per run |
| 2. Vertical — registry | `plugins/marketing/data/canonicals/_manifest.yaml` | One file; lists all valid slugs | `/marketing:new-vertical` appends |
| 2. Vertical — contact half | `plugins/marketing/data/canonicals/{vertical}.yaml` | One per vertical (personas + title cascades + offers) | `/marketing:new-vertical` / `new-persona` / `new-offer` |
| 3. ICP — discovery half | `plugins/marketing/data/canonicals/icp/{vertical}.json` | One per vertical, **mandatory** (lint-enforced) | Hand-authored; stubs scaffolded at vertical creation |

**The two halves are complementary, never substitutes** (ADR-024): the
canonical `{vertical}.yaml` answers *"who at those companies?"* (contact
cascade); the icp file answers *"which companies are in this market?"*
(Discovery ICP — industries, geo, size band, signals, exclusions). A vertical
always has both files; what varies is whether the icp file is **ready** or a
**stub**.

## Ready vs stub — the only state distinction

Every registered vertical has `icp/{vertical}.json` (`lint_canonicals.py`
ERRORs otherwise). There is no "missing" state and no playbook fallback branch:

- **Ready** — `segments` has ≥1 named block. plan-campaign Step 2.5 resolves
  the segment(s) (`--segment`, auto-pick when single, multiSelect prompt when
  several) and Step 7 copies each chosen block to
  `docs/campaigns/{entity}/tam/{slug}/{segment}/icp.json`. tam-mapping runs
  once per segment with that subdir as `--output-dir`.
- **Stub** — `segments` is empty and `clarifications_needed` lists what an
  operator must author. plan-campaign scaffolds the campaign anyway but flags
  `ICP source: STUB` in the dry-run preview, the Target-list sub-issue, and
  the § 11.3 handoff — author the segments before list-build starts.

The 6 playbook verticals (aquariums, casinos, hotels-resorts, ski-resorts,
sports-stadiums, zoos) have prose playbooks at
`references/vertical-playbooks/{vertical}.md` — those are **source material**
for authoring their icp segments (each stub's `source` points there), not an
alternate resolution path. tam-mapping's own playbook auto-load remains as
legacy for manual runs only.

## Segments

A **segment** is a named, self-contained Discovery ICP block — one account
universe, paired with exactly one persona via its `persona` cross-ref
(lint-validated against the sibling yaml). No base block, no inheritance: a
single-audience vertical is just the one-segment case.

A campaign targeting two account universes uses two segments — two criteria
copies, two tam runs, two lists — never a unioned criteria block (disjoint
firmographics can't be fit-scored together). Worked example:
`icp/shopping-centers.json` carries `flagship-brands` (→ `vp-marketing`) and
`destination-centers` (→ `center-owner-asset-manager`); the FY26-M07
custom-illuminated-artwork campaign scaffolds both.

Campaign-specific narrowing (pruning a seed account mid-deal, tightening geo)
is edited in the **campaign copy**, never upstream in the canonical file.

## Practical checklist for a new campaign

1. `docs/marketing-context.md` exists? If not, plan-campaign WARNs — run
   `/marketing:product-marketing-context` once, or pass `--entity`.
2. Vertical registered + canonical yaml has your persona? If not:
   `/marketing:new-vertical` / `/marketing:new-persona`.
3. `icp/{vertical}.json` ready? If stub: author its segments (the
   `clarifications_needed` list is the authoring checklist; `source` points at
   the prose research). Then scaffold.
