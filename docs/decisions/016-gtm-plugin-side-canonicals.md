# 016. GTM canonicals.yaml — plugin-side (over handbook-side)

**Status:** Accepted
**Date:** 2026-05-13
**Linear:** [BC-8718](https://linear.app/brite-nites/issue/BC-8718) (T3-G — backfill all 27 verticals)
**Related ADRs:** [ADR-001](001-cross-repo-import-solution.md), [ADR-012](012-gtm-campaign-unit.md), [ADR-013](013-gtm-three-layer-split.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3 + §6 (Vertical/Persona/Offer Family glossary entries), [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) §7.2 (Phase 2 pivot)

## Context

Per ADR-012, the campaign slug `{vertical}-{persona}-{offer}-fy{YY}-m{MM}` requires every component to be a canonical slug. Three options for where canonicals live:

- **Handbook-side**: `handbook/marketing/canonicals/_manifest.yaml` + per-vertical YAML
- **Plugin-side**: `plugins/marketing/data/canonicals/_manifest.yaml` + per-vertical YAML
- **Inferred from handbook prose** at runtime (e.g., scan vertical READMEs for persona definitions)

The original Phase 1 design defaulted to handbook-side. The Phase 2 architectural pivot reversed this.

## Decision Drivers

- **Skills need to read canonicals at runtime** (every `/marketing:plan-campaign` invocation, every `list-building`/`tam-mapping`/`launch-campaign` call). Handbook-side requires gh auth + remote fetch + caching for every skill call.
- **Handbook PRs are heavyweight.** Adding a new persona slug (one-line YAML diff) shouldn't require handbook PR review + merge cycle.
- **Operator-driven cadence.** Marketing adds candidate personas weekly via list-building discoveries; canonicals.yaml updates lag this by 1-2 days. Handbook-PR cadence (1-2 weeks median) creates excess lag.
- **CLAUDE.md ≤100-line soft budget (per BC-5832 / ADR-010 line-budget discipline).** Cross-tool consumers reading canonicals don't need a long onboarding section; a plugin filesystem read is one-line.
- **Phase 2 architectural pivot** sharpened the role split: handbook = HOW (process); plugin = WHAT (entities + state). Canonicals are entities, not process — they belong on the plugin side.

## Decision

**Canonicals live at `plugins/marketing/data/canonicals/`:**

```
   plugins/marketing/data/canonicals/
   ├── _manifest.yaml           # schema_version + verticals[] alphabetized
   ├── municipalities.yaml      # slug + display + personas[] + offers[]
   ├── hoas.yaml
   ├── landscape-lighting.yaml
   ├── ... (27 total)
```

### Schema (thin per D7 re-walk)

```yaml
# {vertical}.yaml
slug: municipalities          # required, kebab-case
display: "Municipalities"     # required
personas:                     # required, flat (no ICP nesting)
  - slug: public-works-director
    display: "Public Works Director"
    titles:                   # required ≥1 (drives list-building cascade)
      - "Public Works Director"
      - "Director of Public Works"
offers:                       # required
  - slug: free-rop-audit
    display: "Free ROP Audit"
    status: active            # draft|active|retired
    target_personas: [public-works-director]   # optional
    replaced_by: <slug>       # optional forward-pointer
    iterates_from: <slug>     # rare family-level evolution
    prose_path: ...           # optional override
aliases: [old-slug]           # optional, for vertical renames
playbook_path: ...            # optional override
```

### Cross-tool consumers

brite-data-platform, brite-salesforce, brite-gtm read canonicals from britenites-claude-plugins repo via `gh api` or local clone (cross-tool consumers are read-heavy and don't need the runtime-frequency that skills do).

### Day-1 scope

All 27 verticals get canonicals entries day-1 (per D11). Active verticals (7) have populated personas + offers; Exploring (8) + Future (12) can be skeleton (slug + display only) and graduate via `/marketing:new-persona` / `/marketing:new-offer` (BC-8725).

## Consequences

- `/marketing:plan-campaign` (BC-8724) Step 2 is a local filesystem read (cheap), not a remote gh api call.
- `/marketing:new-vertical` / `/new-offer` / `/new-persona` sibling commands (BC-8725) emit a canonicals diff + optional handbook PR draft (for visibility, not for canonicality enforcement).
- D10 (`--handbook-ref` flag) becomes unnecessary and is dropped — no remote handbook fetch needed.
- Cross-tool consumers (brite-data-platform, brite-salesforce) read from plugin repo; gh auth audit (V1) becomes lower-priority since skills don't need it.
- Schema versioning per D9 lives in `_manifest.yaml` (`schema_version: 1`); major bumps migrate `{vertical}.yaml` files in the same PR.
- D8 (persona authorship process) becomes: Marketing authors slugs+titles[] in plugin PRs at operator-driven cadence; discoveries.json category-tagged signals from skills propose new entries for human promotion.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Handbook-side canonicals (original Phase 1 default) | Requires gh auth + remote fetch every skill call; handbook PR cadence too slow for operator-driven cadence |
| Inferred from handbook prose at runtime | Fragile parsing; handbook prose isn't structured for runtime extraction; YAGNI |
| brite-gtm repo as canonicals home | brite-gtm is pre-Linear ideation queue per O7; conflating ideation + canonicals creates two-purpose problem |
| Salesforce custom metadata as canonicals | Requires SF MCP read at every plan-campaign invocation; high latency; misaligned with plugin's filesystem-first idiom |

## Cross-references

- README §3 — Plugin box in 4-layer architecture (canonicals listed)
- README §6 — glossary entries for Vertical / Persona / Offer Family
- README §3.6 — worked example Step 2 (canonicality validation)
- Design doc §7.2 — Phase 2 pivot rationale
- Design doc §7.3 — vocabulary canon (persona schema)
- ADR-001 — cross-repo import solution context
- BC-8718 — implementation
