---
name: flow-sandbox-scaffold
description: Per-flow sandbox harness scaffolding sub-skill for the flow-architecture plugin (implements CDR-023). L4 scope — invoked from inside the [Eng] discipline child workflow via `/flow:plan-eng`, or by `/flow:plan-qa` pre-flight if `/sandbox/<flow>` doesn't exist when QA starts. Three modes determined by code-evidence scan — EXTRACT (refactor Page → View + harness), WRAP (harness around existing View), STUB (placeholder for NOT_STARTED greenfield flows). Outputs functional code, not markdown — verification is `npm run build && npm run lint && npm test`. 1 conditional user-gate (EXTRACT mode only). Per-flow footprint: STUB ~5s, WRAP ~10-30s, EXTRACT ~30-90s + user gate review.
user-invocable: false
disable-model-invocation: true
allowed-tools: Agent, AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q17"
  related-locks: "memory:146-177 (Q17 10 sub-decisions); Q15.7 status taxonomy (memory:122); _shared/code-evidence-collector.md (BC-6955)"
---

# flow-sandbox-scaffold

Per-flow sandbox harness scaffolder. Creates functional code (TSX page + nav entry + harness wrapper) so a flow can be exercised in isolation against seed data before the real app integration lands. Mode is chosen by inspecting existing app code:

- **EXTRACT** — `<FeaturePage>` exists but no extractable `<FeatureView>` yet. Refactor Page into `View + Page-wrapper`, then create a sandbox harness wrapping the View.
- **WRAP** — `<FeatureView>` already exists. Just create the harness; no app-code mutation.
- **STUB** — no app code yet (NOT_STARTED). Create a placeholder page + nav entry referencing the [Eng] Linear child.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7). L4 scope — invoked from inside `/flow:plan-eng` or as `/flow:plan-qa` pre-flight; outside the orchestrator gate budget (Q10).

**Boundary clarification (per Q17 lock).** The existing `/backend-handoff`, `/frontend-handoff`, `/handoff-audit` slash commands cover sandbox <-> app **Linear-issue creation**. This skill is the **harness-code creator** --- different scope. Don't conflate.

The full design rationale lives in `docs/design-rationale/project_fda_plugin_interview.md` Q17 (memory:146-177). Q15.7 (memory:122) defines the status taxonomy the mode mapping consumes.

---

## 1. Invocation context (Q17.1)

L4 scope, per-flow. Two trigger paths:

- **`/flow:plan-eng`** invokes this skill mid-workflow when the engineer needs the harness to start work.
- **`/flow:plan-qa`** pre-flight invokes this skill if `/sandbox/<flow>` doesn't exist when QA picks up the flow.

NOT per-domain at scaffold time. NOT invoked from `/flow:start-project`, `/flow:retrofit-project`, or `/flow:add-domain` --- those are per-domain orchestrators that produce inventory + scaffold-log + story docs + journey docs only.

---

## 2. Three modes determined by code-evidence scan (Q17.2)

Reuses `_shared/code-evidence-collector.md` (BC-6955 deliverable). Decision table:

| Code state | Status hint | Mode |
|---|---|---|
| `<FeaturePage>` at `src/app/(frontend)/(app)/<route>/page.tsx` exists AND no `<FeatureView>` at `src/components/<feature>/` | BUILT or IN_PROGRESS without View | **EXTRACT** |
| `<FeatureView>` already exists at `src/components/<feature>/<feature>-view.tsx` | BUILT or IN_PROGRESS with View | **WRAP** |
| No app code exists for the feature | NOT_STARTED (greenfield) | **STUB** |

Status taxonomy maps per Q15.7:

- BUILT/IN_PROGRESS + View -> **WRAP**
- BUILT/IN_PROGRESS without View -> **EXTRACT**
- NOT_STARTED -> **STUB**

---

## 3. Component extraction (EXTRACT mode only) (Q17.3) --- 1 sync gate

Single `Agent(general-purpose)` call + mandatory pre-extraction sync gate.

**Workflow:**

1. Agent reads `<feature>-page.tsx`, identifies presentation vs. handler logic, computes an extraction plan.
2. **Sync gate via `AskUserQuestion`** (the only user-gate in this skill):
   ```
   Refactor <FeaturePage> into <FeatureView> + Page-wrapper before creating sandbox harness?
   Plan: <agent-emitted summary>
     - Approve refactor (Recommended)
     - Skip --- fall through to STUB
     - Cancel
   ```
3. On approve: agent writes new `<FeatureView>` and rewrites Page as a wrapper. Matches BriteBase TEAM-04 / `UserListView` precedent per the consumer project's CLAUDE.md "Sandbox flows import existing pages" convention.
4. **Post-refactor `npm run build`.** On fail, surface error verbatim + roll back via `git stash` (the skill assumes a dirty-tree-friendly workflow; clean tree is the caller's pre-condition).

---

## 4. Sandbox harness shape (Q17.4) --- three templates

### WRAP / EXTRACT-after-refactor template

```tsx
"use client";

import { useState } from "react";
import { toast } from "sonner"; // or project-canonical toast lib
import { <FeatureView> } from "@/components/<domain>/<feature>-view";
import { seedSample } from "@/mocks/seed";

const initialState = {
  // ...seeded from seedSample.<...>
};

export default function <Feature>Sandbox() {
  const [state, setState] = useState(initialState);

  const handleAction = (input: ActionInput) => {
    toast.info(`Sandbox --- ${input.action}`);
    setState((s) => mutateLocalState(s, input));
  };

  return <<FeatureView> {...state} onAction={handleAction} />;
}
```

Each handler `toast.info`s `"Sandbox --- <action>"` AND mutates local state. This mirrors server-side guards so the UI exercise is honest without hitting the real backend.

### STUB template

```tsx
export default function <Feature>SandboxStub() {
  return (
    <div className="sandbox-stub">
      <h1>TBD per [Eng] child <a href="<linear-url>">BC-XXXX</a></h1>
    </div>
  );
}
```

Linear URL pulled from the story doc's `children.engineering` front-matter field + `.flow/config.json` workspace.

### Optional View-as selector sub-template

Added when role-based AC requires it. Detected by:

- Scanning AC scenarios in the story doc for role-conditional language (`When I am a <role>`, `As a <role>`); OR
- Handler logic in the existing app for role-gated branches.

TEAM-04 cut-3 precedent for shape.

---

## 5. Seed-gap policy (Q17.5) --- `requireSeedField()` LOUD signal

Skill compares the View's prop shape (TypeScript types) against the seed constant's shape. For each gap, auto-generates a `requireSeedField()` call at the top of the harness body:

```tsx
function requireSeedField<T>(value: T | undefined, field: string): T {
  if (value === undefined) {
    throw new Error(
      `Seed gap: ${field} missing from @/mocks/seed. Extend the seed schema before this harness can render.`
    );
  }
  return value;
}

const requiredCustomerName = requireSeedField(seedSample.customer?.name, "Customer.name");
```

**Throws at route-render** if the seed schema regresses. Survives optional View prop types (compiles cleanly, lint passes, runtime throws). Skill summarizes all seed-gap assertions at end of run so they're visible.

**Does NOT auto-extend the seed.** Schema is a cross-domain decision; `requireSeedField()` calls block runtime until a human decides + extends.

---

## 6. Sandbox-nav update (Q17.6)

Auto-append entry to `src/components/sandbox/sandbox-nav.tsx`:

```ts
{
  id: "<feature-id>",
  label: "<Feature display name>",
  href: "/sandbox/<feature-route>",
  icon: <BestMatchPhosphorIcon />, // or <Square /> default
  subgroup: "<auto-detected or new>",
}
```

Best-match Phosphor icon: scan `@phosphor-icons/react/dist/ssr` for an icon name matching the feature semantics (heuristic substring match against the feature name); default to `<Square>` if no good match.

Auto-detect `SidebarSubgroup` by domain:

- `screens/<lowercase-domain>` exists -> use that subgroup.
- Else -> create a new subgroup named after the domain.

Idempotent on re-run via `id` match (skip if entry with matching id already exists).

---

## 7. Idempotency (Q17.7)

Skip-if-exists + `--force`. Pre-write checks:

- Page file path (`src/app/(frontend)/(sandbox)/<feature>/page.tsx`).
- Nav-entry id in `sandbox-nav.tsx`.

If both exist, skip with summary. `--force` overwrites both; per-flow `AskUserQuestion` in interactive mode.

---

## 8. Verification (Q17.8)

Run `npm run build && npm run lint && npm test` after harness creation.

**Skip the per-doc fidelity-review agent** (which Q15.4 and Q16.4 specify for story/journey docs). Harness is **code**, not narrative. Drift modes --- compile fails, type errors, lint failures, test regressions --- are all caught by the build pipeline. Per-doc fidelity-review here would be overkill.

---

## 9. Failure recovery (Q17.9)

Per-flow log + continue.

- **EXTRACT-mode failure** (Page logic too intertwined to cleanly split) -> fall through to STUB mode + flag for manual; flag captured in the scaffold log.
- **Build-failure on EXTRACT mode** -> trigger `git-stash` rollback BEFORE the user-gate result is committed. Surface the build error verbatim.

---

## 10. User-confirmation gates (Q17.10)

1 conditional gate (**EXTRACT mode only** --- Section 3); 0 gates for WRAP / STUB.

L4 scope --- doesn't count against Q10's 5/4 orchestrator gate budget.

---

## Worked example

`/flow:plan-eng BC-7XXX` for a sub-flow with status=IN_PROGRESS, existing app page but no extracted View:

1. Skill probes code -> finds `src/app/(frontend)/(app)/customer-list/page.tsx`, no `<CustomerListView>`. Mode = **EXTRACT**.
2. `Agent(general-purpose)` reads the page, emits an extraction plan ("Move 3 useState hooks + 2 effects into `CustomerListView`; rewrite page.tsx as a 5-line wrapper").
3. `AskUserQuestion` gate fires; user picks "Approve refactor".
4. Agent writes `src/components/customer/customer-list-view.tsx` (new); rewrites `page.tsx` to import + render the View.
5. `npm run build` -> success.
6. Skill writes `src/app/(frontend)/(sandbox)/customer-list/page.tsx` using the WRAP template + 2 `requireSeedField()` calls (seed schema missing `customer.metadata` and `customer.relationships`).
7. Skill appends to `sandbox-nav.tsx` with `id: "customer-list"`, `label: "Customer List"`, `href: "/sandbox/customer-list"`, subgroup `screens/customer`.
8. Skill runs `npm run build && npm run lint && npm test` -> all pass.
9. Summary: `flow-sandbox-scaffold: mode=EXTRACT, refactor=executed, harness=created, nav-entry=appended, seed-gaps=2 (Customer.metadata, Customer.relationships).`

---

## See also

- `docs/design-rationale/project_fda_plugin_interview.md` Q17 --- canonical 10-sub-decision spec.
- `docs/design-rationale/project_fda_plugin_interview.md` Q15.7 --- status taxonomy this skill's mode-mapping consumes.
- `skills/_shared/code-evidence-collector.md` --- BC-6955 helper this skill reuses for code-evidence scans.
- `skills/flow-doc-author/SKILL.md` --- sibling sub-skill that authors the story doc this skill reads for AC role-conditionals + Linear children refs.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; preamble's mode signal is consumed by the L4 caller, not this skill directly.
