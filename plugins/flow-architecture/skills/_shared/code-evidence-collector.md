# Code-Evidence Collector

Deterministic code-scan contract shared by three FDA locks — Q11 Phase 3 (retrofit inventory code scan), Q15.7 (`flow-doc-author` status assignment), and Q17.2 (`flow-sandbox-scaffold` mode determination). One scan, two derived outputs — a status tag and a sandbox mode — both grounded in filesystem evidence rather than LLM self-report. Consolidates parking-lot #18 (DRY across three Q-locks).

## Why

Three different sub-skills used to ask "what does the code say?" through three slightly different prompts. That triple authorship invited drift — three definitions of "BUILT", three guesses at the sandbox URL, three opinions on whether `<FeaturePage>` exists. Q15.7 (`docs/design-rationale/project_fda_plugin_interview.md:122`) and Q17.2 (`:150`) both lock onto the same evidence vocabulary; this file is the single derivation point. A change to the status taxonomy or mode-determination rule lands here once and propagates to all three consumers.

## What it scans

`Glob` / `Grep` / `Read` against Next.js App Router conventions, targeted at feature folders:

- `src/components/<domain>/` — feature components and their `<FeatureView>` exports.
- `src/app/(frontend)/(app)/<route>/page.tsx` — page entry points.
- `src/payload/collections/<collection>.ts` — server-side collections.
- `*.test.ts` files co-located with components — AC scenarios already encoded.
- `src/components/sandbox/sandbox-nav.tsx` — sandbox URL discovery.

## Status taxonomy (Q15.7 verbatim, capped at BUILT)

Per Q15.7 sub-decision 7 (`:122`):

- `code-exists+tests+sandbox-URL → BUILT`
- `code-exists-but-incomplete → IN_PROGRESS`
- `no-code → NOT_STARTED`

The collector MUST NOT promote a flow past BUILT. `QA_SIGNED_OFF` requires a Linear QA child sign-off — a workflow event, not codebase state. `SHIPPED` requires a customer-doc filesystem signal at `docs/product/customer-docs/<domain>/<flow-id>.md` — scoped out of code-evidence; v1.1 candidate. Promoting past BUILT here would silently overwrite real workflow state.

Drift handling: when code-evidence disagrees with the inventory row, the collector surfaces the disagreement in a `## Status notes` section in the target doc — e.g. `"BUILT — code-evidence cited; inventory marked NOT_STARTED — recommend reconcile"` — rather than silently overwriting. BriteBase Cut-1a `TEAM-01..06` precedent.

## Sandbox-mode determination (Q17.2 verbatim — EXTRACT / WRAP / STUB)

Per Q17.2 sub-decision 2 (`:150`), the same scan drives `flow-sandbox-scaffold`'s three-mode pick:

- **EXTRACT** — `<FeaturePage>` exists at `src/app/(frontend)/(app)/<route>/page.tsx` AND no `<FeatureView>` at `src/components/<feature>/`. Recommends refactoring Page into a View + Page-wrapper before harness creation. Requires a synchronous user gate per Q17.3.
- **WRAP** — `<FeatureView>` already exists. Recommends creating a sandbox harness that imports the existing View; no app-code mutation.
- **STUB** — no app code exists. Recommends a placeholder page + nav entry tagged "TBD per [Eng] child BC-XXXX".

Status-to-mode mapping:

- BUILT or IN_PROGRESS with a `<FeatureView>` → WRAP.
- BUILT or IN_PROGRESS without a `<FeatureView>` → EXTRACT.
- NOT_STARTED → STUB.

## Consumers

- `flow-inventory-codebase-scan` (Q11 Phase 3) — runs the scan to seed retrofit inventory rows.
- `flow-doc-author` (Q15.7) — reads the scan output for the story-doc front-matter `status` field and the `sandbox_url` substitution.
- `flow-sandbox-scaffold` (Q17.2) — reads the scan output to pick EXTRACT / WRAP / STUB.

## References

- `docs/design-rationale/project_fda_plugin_interview.md:68` — Q11 `/flow:inventory` 6-phase architecture; Phase 3 is the deterministic code scan.
- `docs/design-rationale/project_fda_plugin_interview.md:122` — Q15.7 status taxonomy with the BUILT cap (verbatim source).
- `docs/design-rationale/project_fda_plugin_interview.md:150` — Q17.2 EXTRACT / WRAP / STUB mode determination (verbatim source).
- `docs/design-rationale/project_fda_plugin_interview.md:292` — Q30.2 file-location lock.
- Cross-verified in consumer projects at `docs/product/master-flow-inventory.md:22-27`, `docs/product/flows/INDEX.md:15-20`, `docs/templates/job-story.md:4` (all five canonical states + BLOCKED orthogonal; no `PARTIALLY_BUILT`).
