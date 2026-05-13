# 013. GTM 3-layer split (Handbook = HOW / Linear = orchestration / Plugin = WHAT)

**Status:** Accepted
**Date:** 2026-05-13
**Linear:** [BC-8712](https://linear.app/brite-nites/issue/BC-8712) (Task 0 umbrella)
**Related ADRs:** [ADR-012](012-gtm-campaign-unit.md), [ADR-014](014-gtm-salesforce-portfolio-rollup.md), [ADR-016](016-gtm-plugin-side-canonicals.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3, [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) Section 2 (D2 + Phase 2 reframe in §7.1)

## Context

Three Brite systems were partially overlapping in how they represented campaigns. Each pretended to own definitions OR state OR execution but actually mixed them. Result: drift, double-maintenance, and ambiguity about which system was canonical for what.

The Phase 2 architectural pivot (2026-05-11) sharpened the original D2 split (Handbook = reference; Linear = state; Plugin = execution) into a clearer functional decomposition.

## Decision Drivers

- **Each system has different update cadence + audit profile.** Handbook = PR-reviewed prose; Linear = real-time state; Plugin = code commits. Mixing them blurs governance.
- **Handbook PRs are heavyweight** (review + sign-off + reading-grade). Linear is lightweight (operator action). Plugin sits in between.
- **Live state cannot live in handbook prose.** active-campaigns.md was a perpetual decay attractor — nobody hand-maintains a state table.
- **Plugin owns artifacts that compound** (canonicals, MSPA matrix, learnings.md, manifest.json). These are operational entities, not handbook process.

## Decision

```
   HANDBOOK = HOW              (process, frameworks, standards, templates,
                                playbooks; mutated via PR)

   LINEAR   = ORCHESTRATION    (milestones + 8+2 sub-issues + status
                                labels + brief text in milestone desc +
                                audit trail; daily-changing)

   PLUGIN   = WHAT             (entities + state — canonicals, MSPA
                                matrix, learnings, manifest.json,
                                discoveries.json, performance.md;
                                operator-driven cadence)
```

Phase 2 sharpening: handbook is HOW (process), plugin is WHAT (entities + state). Handbook never holds live campaign state. Plugin never owns process definitions (it can reference them).

Salesforce sits beside this trio as the **reporting + attribution surface** (see ADR-014). The 3-layer model preserves; SF is the read-mostly downstream consumer of orchestration state.

## Consequences

- Handbook `active-campaigns.md` becomes a navigation doc pointing at SF list view URL + Linear project URL (per D6 / BC-8734).
- All canonical taxonomies (vocabulary canon, framework docs, vertical playbooks) live in handbook (per O14 / BC-8732/BC-8733).
- All operational state (canonicals.yaml, MSPA matrix, learnings, manifest, discoveries) lives in plugin (per Phase 2 7.2 + ADR-016).
- Linear is the orchestration layer; the "Brite GTM" project holds milestones + sub-issues; the "Brite Plugin Marketplace" project holds plugin engineering work.
- Cross-skill handoffs flow through plugin filesystem (e.g., `campaign-debrief` → `product-marketing-context` proposal via `discoveries.json` signals); skills never directly mutate handbook.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Single Linear-only system (drop handbook + plugin roles) | Loses handbook canonicality (vocabulary, frameworks, vertical playbooks); loses plugin execution surface (commands + skills) |
| Notion as state-of-record (existing Notion Campaign Manager) | Deprecated upstream; read-only access; not integrated with Linear MCP or revops MCP |
| Plugin owns canonicals AND framework docs (collapse handbook into plugin) | Handbook is the multi-team reference surface (Sales / CS / PMM read it); collapsing into plugin makes those teams pull from britenites-claude-plugins which they don't normally touch |
| Handbook owns canonicals (pre-Phase-2 original D2) | Skills calling canonicals at runtime would need gh auth + remote fetch + caching; plugin-side eliminates this (ADR-016) |

## Cross-references

- README §3 — 4-layer architecture diagram
- README §10 — artifact index showing where each layer's content lives
- Design doc Section 2 D2 — original lock
- Design doc §7.1 — Phase 2 architectural pivot
- ADR-014 — SF as the reporting surface beside this trio
- ADR-016 — canonicals plugin-side (subdecision)
