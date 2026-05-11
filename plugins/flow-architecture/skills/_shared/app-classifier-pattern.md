# App-Classifier Interview Pattern

A short shared interview that two FDA inventory sub-skills run before they diverge — `flow-inventory-codebase-scan` (retrofit, Q11) and `flow-inventory-interview` (greenfield, Q19). The classifier produces a structured signal about the app — framework, app category, primary persona shape, scale — that both consumers feed into pattern-catalog candidate generation downstream. The interview prompts, the structured output shape, and the user-confirmation gate are shared; the middle of each consumer's pipeline differs.

## Why

Q11 (`docs/design-rationale/project_fda_plugin_interview.md:68`) and Q19 (`:208`) both need the same prelude. Q19 explicitly states "shares Phases 0/1/2/5 verbatim via `_shared/app-classifier-pattern.md` shared utility" (`:208`). Holding the shared shape in one file keeps the two consumers from drifting on the base interview, and keeps the Phase-0 intent read, the Phase-2 pattern-catalog selectors, and the Phase-5 confirmation surface uniform across retrofit and greenfield.

## Shared phases

Both consumers run these four phases verbatim:

- **Phase 0 — Intent read.** Load `docs/product/intent.md` as the priority filter for downstream candidate generation. The intent sets the bar for "what counts as relevant" for this project.
- **Phase 1 — Classifier interview.** Four base questions, one at a time per the project's one-question-at-a-time rule: framework (Q11 lock: Next.js for v1), app category (SaaS / CRM / ops / agency / marketplace / installation), primary persona shape (single / dual / multi-tenant N-persona), scale (small ≤5 flows-per-domain / standard 5-10 / heavy 10+). Consumers may layer follow-ups after Phase 1 — Q19 adds four greenfield-only follow-ups (domain envisioning, flow-density-per-domain, MVP sequencing, persona density) defined in the consumer skill body, NOT here.
- **Phase 2 — Pattern-driven candidate generation.** Use Phase 1 answers as selectors against a pattern catalog of common app archetypes (CRM, installation business, multi-tenant SaaS, etc.), augmented by `WebSearch` for less-canonical categories.
- **Phase 5 — User confirmation.** Render the proposed inventory and gate via `AskUserQuestion` (Approve / Edit inline / Reject). Slug overrides are user-final per Q11 pushback (`:68`). This is one of Q10's 5 retrofit / 4 greenfield orchestrator gates.

## Consumers

- **`flow-inventory-codebase-scan`** (retrofit, Q11) — inserts Phase 3 (deterministic Glob/Grep/Read code scan against Next.js App Router targets) and Phase 4 (status taxonomy synthesis with `implemented` / `partially-implemented` / `missing-but-recommended` / `implemented-no-pattern-match` tags) between Phase 2 and Phase 5. See `code-evidence-collector.md` for the Phase 3 deterministic scan.
- **`flow-inventory-interview`** (greenfield, Q19) — skips Phase 3 entirely (no codebase) and uses a 3-tag scope-priority taxonomy (`mvp` / `nice-to-have` / `post-launch`) in Phase 4 (`:214`). Skip is logged with rationale per Q19 sub-decision 1.

Both consumers own their non-shared phases in their own SKILL.md bodies. Adding a Phase 3 / Phase 4 here would couple the two consumers in a direction the locks deliberately avoid.

## References

- `docs/design-rationale/project_fda_plugin_interview.md:68` — Q11 `/flow:inventory` 6-phase architecture (shared phase set).
- `docs/design-rationale/project_fda_plugin_interview.md:208` — Q19 `flow-inventory-interview` internals; names this file as the shared utility.
- `docs/design-rationale/project_fda_plugin_interview.md:212` — Q19 greenfield-only Phase 1 follow-ups (live in consumer skill body).
- `docs/design-rationale/project_fda_plugin_interview.md:214` — Q19 Phase 4 3-tag scope-priority taxonomy.
- `docs/design-rationale/project_fda_plugin_interview.md:292` — Q30.2 file-location lock at `skills/_shared/app-classifier-pattern.md`.
