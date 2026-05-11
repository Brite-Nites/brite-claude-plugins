# Code-Evidence Collector

Deterministic code-scan contract shared by three locks: Q11 Phase 3 (retrofit inventory code scan), Q15.7 (`flow-doc-author` status assignment), and Q17.2 (`flow-sandbox-scaffold` mode determination). One scan, two derived outputs — a status tag and a sandbox mode — both grounded in filesystem evidence rather than LLM self-report. Consolidates parking-lot #18 (DRY across three Q-locks).

## What it scans

`Glob/Grep/Read` against Next.js App Router conventions, targeted at feature folders:

- `src/components/<domain>/` — feature components and their `<FeatureView>` exports.
- `src/app/(frontend)/(app)/<route>/page.tsx` — page entry points.
- `src/payload/collections/<collection>.ts` — server-side collections.
- `*.test.ts` files co-located with the components — AC scenarios already encoded.
- `src/components/sandbox/sandbox-nav.tsx` — sandbox URL discovery.

## Status taxonomy (Q15.7 verbatim)

Per Q15.7 sub-decision 7, the canonical status mapping caps at BUILT:

- `code-exists+tests+sandbox-URL → BUILT`
- `code-exists-but-incomplete → IN_PROGRESS`
- `no-code → NOT_STARTED`

**Cap at BUILT.** Code-evidence MUST NOT promote a flow to `QA_SIGNED_OFF` (workflow event — requires Linear QA child sign-off) or `SHIPPED` (requires customer-doc filesystem signal at `docs/product/customer-docs/<domain>/<flow-id>.md`; scoped out of code-evidence; v1.1 candidate).

Drift surfacing: when code-evidence disagrees with the inventory row, the collector flags this in a `## Status notes` section in the target doc — for example `"BUILT — code-evidence cited; inventory marked NOT_STARTED — recommend reconcile"` — rather than silently overwriting. BriteBase Cut-1a TEAM-01..06 precedent.

## Sandbox mode determination (Q17.2 verbatim)

Per Q17.2 sub-decision 2, code-evidence drives the `flow-sandbox-scaffold` three-mode pick:

- **EXTRACT** — `<FeaturePage>` exists at `src/app/(frontend)/(app)/<route>/page.tsx` AND no `<FeatureView>` at `src/components/<feature>/`. The collector recommends refactoring Page into a View + Page-wrapper before harness creation. Requires a synchronous user gate per Q17.3.
- **WRAP** — `<FeatureView>` already exists. The collector recommends creating a sandbox harness that imports the existing View; no app-code mutation.
- **STUB** — no app code exists yet. The collector recommends a placeholder page + nav entry tagged "TBD per [Eng] child BC-XXXX".

The mapping from status to mode:

- BUILT or IN_PROGRESS with `<FeatureView>` → WRAP
- BUILT or IN_PROGRESS without `<FeatureView>` → EXTRACT
- NOT_STARTED → STUB

## Consumers

- `flow-inventory-codebase-scan` (Q11 Phase 3) — runs the scan to seed retrofit inventory.
- `flow-doc-author` (Q15.7) — reads the scan output for status assignment in story-doc front matter.
- `flow-sandbox-scaffold` (Q17.2) — reads the scan output to pick EXTRACT / WRAP / STUB.

## References

- Q11 — `docs/design-rationale/project_fda_plugin_interview.md` line 68 (6-phase architecture; Phase 3 is the code scan).
- Q15.7 — line 122 (status taxonomy with the BUILT cap).
- Q17.2 — line 150 (EXTRACT/WRAP/STUB mode determination).
- Q30.2 — file location locked at `skills/_shared/code-evidence-collector.md` (line 281).
- Status taxonomy cross-verified at `docs/product/master-flow-inventory.md:22-27`, `docs/product/flows/INDEX.md:15-20`, `docs/templates/job-story.md:4` in consumer projects.
