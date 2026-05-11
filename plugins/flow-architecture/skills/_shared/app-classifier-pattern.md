# App-Classifier Interview Pattern

The shared Socratic interview that produces an app-classifier signal — what kind of UI-bearing application this is, which user types matter, and which feature areas exist — feeding both the retrofit and greenfield inventory flows. Two sub-skills consume the same contract: `flow-inventory-codebase-scan` (retrofit, Q11) and `flow-inventory-interview` (greenfield, Q19). They share Phases 0/1/2/5 verbatim via this utility; only the middle of the pipeline diverges.

## Shared phases

| Phase | What it does |
|---|---|
| 0 — Intent read | Read `docs/product/intent.md` as priority filter. Inventory is shaped by what the project says it is for, not by raw code archaeology. |
| 1 — Classifier interview | Socratic questions about app type (CRM, marketplace, dashboard, …), primary user types, and high-level feature areas. Output is the seed for Phase 2 candidate generation. |
| 2 — Pattern-driven candidate generation | `WebSearch` + internal pattern catalogs + agent SaaS knowledge produce a candidate flow list keyed by the Phase 1 signal. |
| 5 — User confirmation | Present synthesised inventory; user accepts, rejects, renames, or adds rows. Slug overrides honored. |

## What each consumer adds in the middle

- `flow-inventory-codebase-scan` (retrofit, Q11) inserts **Phase 3** (deterministic code scan via `Glob/Grep/Read` against Next.js App Router conventions) and **Phase 4** (synthesis with the canonical status taxonomy — see `code-evidence-collector.md`).
- `flow-inventory-interview` (greenfield, Q19) skips Phase 3 entirely (no code exists yet) and replaces Phase 4 with a heavier Phase 1 interview that elicits the same flow set without code archaeology.

## Why this is a shared utility, not a sub-skill

The interview itself is a contract — same prompts, same structured output, same Phase-5 confirmation — but the two consumers wrap it in different end-to-end orchestrations. Promoting the interview to a sub-skill would force one orchestration to win; keeping it as a `_shared/` reference lets both sub-skills cite the same phases without coupling.

## References

- Q11 — `/flow:inventory` 6-phase architecture: `docs/design-rationale/project_fda_plugin_interview.md` line 68.
- Q19 — `flow-inventory-interview` internals (lines 208-237) explicitly cites this file as the shared utility.
- Q30.2 — Plugin directory structure locks this file at `skills/_shared/app-classifier-pattern.md` (memory:281).
