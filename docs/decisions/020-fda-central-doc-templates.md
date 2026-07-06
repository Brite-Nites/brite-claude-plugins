# ADR-020: FDA doc templates are centralized in the plugin (single source of truth)

- **Status:** Proposed (2026-06-09)
- **Deciders:** Holden Halford
- **Context origin:** BC-11997 (WS-E brite-labs-site remediation) step-away. Rescopes BC-13028 finding #3.

## Context

FDA consumer repos (brite-base + the 7 WS-E repos) author flow / journey / persona docs against three canonical templates — `job-story.md`, `domain-journey.md`, `persona.md`. The original design had the scaffold **seed** these into each consumer repo at `docs/templates/`, and the plugin's authoring agents (`story-doc-author`, `journey-doc-author`, `inventory-author`) + reviewers (`fidelity-reviewer`, `quality-reviewer`) read them from that per-repo path ("Template is law … read it every invocation").

That produced the worst of both worlds:
- The templates were never actually shipped into the plugin's Phase-1 copy array (BC-13028 #3) → each repo hand-seeded them (brite-supply-react reconciled 3 by hand; brite-labs-site authored against brite-base's copies).
- N per-repo copies → drift, plus a plugin-version cache-keyed resync burden.

Two facts make the per-repo copy unnecessary:
1. **The doc templates are INVARIANT across consumer repos** — a job-story doc has the same structure everywhere; nothing is customized per-repo (unlike, e.g., issue-tracker config, which genuinely varies).
2. **`verify-docs.sh` — the only thing that runs in a consumer repo's CI — does NOT read the templates** (it excludes `docs/templates/` and does link / frontmatter / flow-ID / freshness checks only). Template *fidelity* is enforced by AGENTS (`fidelity-reviewer`, `quality-reviewer`), which always have the plugin installed. So there is **no hard dependency** forcing a per-repo template copy.

(Pattern reference: Matt Pocock's `skills` repo keeps seed templates centrally and materializes only repo-*specific* config; his ADR-0001 splits skills into hard- vs soft-dependency. Our doc templates are invariant where his config is variant, so we can go further — reference-only, no materialization.)

## Decision

1. The canonical FDA doc templates live **once, in the plugin**: `plugins/flow-architecture/templates/docs/{job-story,domain-journey,persona}.md` (+ `issues/*`, `customer-how-to.md`). This is the single source of truth.
2. Authoring agents + reviewers reference the templates at the **plugin path** (`${CLAUDE_PLUGIN_ROOT}/templates/docs/…`), not `docs/templates/<x>.md` in the consumer repo.
3. The scaffold does **not** seed `docs/templates/` into consumer repos. At most, leave a one-line pointer ("FDA doc templates are canonical in the flow-architecture plugin").
4. Drift / enforcement stays an **agent** job (fidelity / quality reviewers). If CI-level structural enforcement is ever wanted, that is the one place a per-repo copy or plugin-in-CI would matter (the hard-dependency tier) — deferred; not needed today.

## Consequences

- Drift becomes impossible — one copy.
- Consumer repos are not fully self-contained (a human browsing the repo can't see the template inline) — accepted; replaced by a pointer + the plugin as canonical home.
- **BC-13028 finding #3 is rescoped** from "seed per-repo" → "centralize + repoint + drop seed."
- Requires repointing the **6** skill/agent references from `docs/templates/<x>.md` to the plugin path.
- Does **not** by itself fix the `flow_id` vs `sub_flow_id` regen-key mismatch (separate finding) — but centralizing the template is the natural moment to settle the canonical key.

## Rejected alternatives

- **Per-repo seed (status quo / original BC-13028 #3):** N drifting copies, resync burden, no value (templates are invariant + not read by CI).
- **Per-repo copy, stamped + version-pinned + drift-checked:** viable only if CI-level offline template-fidelity checks become required; deferred behind a prompt-driven "verify mode" (Matt Pocock's pattern) rather than a sibling tool.
- **Migrate consumer docs to a new convention:** out of scope.
