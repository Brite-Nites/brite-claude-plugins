---
name: flow-inventory-codebase-scan
description: Retrofit-mode inventory generator for the flow-architecture plugin (implements CDR-023). Mines code signals (routes, server actions, dialogs, menu items, API endpoints) from an existing Next.js App Router codebase and synthesizes the proposed inventory. Six phases — Phase 0 (PROJECT-INTENT priority filter) -> Phase 1 (app-classifier interview, shared with Q19 greenfield) -> Phase 2 (pattern-driven candidates, shared) -> Phase 3 (deterministic code scan, retrofit-only) -> Phase 4 (synthesis with 4-tag implementation-status taxonomy + value-priority) -> Phase 5 (user confirmation, shared). Framework locked to Next.js App Router for v1. Triggered by `/flow:retrofit-project` when `flow-preflight` mode classifier returns `retrofit`.
user-invocable: false
disable-model-invocation: true
allowed-tools: WebSearch, AskUserQuestion, Read, Write, Bash, Glob, Grep
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q11"
  related-locks: "memory:68 (Q11 6-phase architecture); Q19 (memory:208) shares Phase 0/1/2/5 via _shared/app-classifier-pattern.md; Q25 master-inventory schema"
---

# flow-inventory-codebase-scan

Retrofit-mode inventory generator. Code-evidence-driven --- mines an existing Next.js App Router codebase for routes, server actions, dialogs, menu items, and API endpoints; cross-references against a pattern catalog; synthesizes a proposed inventory with 4-tag implementation-status taxonomy and value-priority.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7). The user-facing wrapper is `/flow:retrofit-project`; preflight gates this skill's invocation on `MODE=retrofit`.

**Framework locked to Next.js App Router for v1.** Other frameworks (React Router, Remix, Tanstack Start, Vue/Nuxt) are parking-lot candidates --- this skill's code-scan phase encodes Next.js-specific filesystem conventions (`src/app/(...)`, `route.ts`, server actions). Cross-framework support is v1.1+.

**Critical relationship to Q19.** Shares Phases 0, 1, 2, 5 verbatim with `flow-inventory-interview` via `_shared/app-classifier-pattern.md` (BC-6955 deliverable). Differs in:

- Phase 3 (deterministic code scan) --- retrofit-only.
- Phase 4 status taxonomy (4-tag implementation-status for retrofit vs. 3-tag scope-priority for greenfield).
- Phase 1 interview is lighter --- code signals dominate.

The full design rationale lives in `docs/design-rationale/fda-plugin-interview.md` Q11 (memory:68). Q19 (memory:208) is the greenfield twin.

---

## 1. Phase sequence --- 6 phases

| Phase | Source | Description |
|---|---|---|
| 0 | shared | PROJECT-INTENT.md priority filter |
| 1 | shared | app-classifier interview |
| 2 | shared | pattern-driven candidate generation (WebSearch + pattern catalogs + agent SaaS knowledge) |
| **3** | retrofit-specific | deterministic code scan (Glob/Grep/Read for routes, server actions, dialogs, menu items, API endpoints) |
| 4 | retrofit-specific | synthesis with 4-tag implementation-status + value-priority |
| 5 | shared | user confirmation |

---

## 2. Phase 0 --- PROJECT-INTENT priority filter

Read `docs/product/intent.md` if present. Extract:

- Priority verbs ("self-serve", "automate", "audit").
- Domain emphasis (which domains intent calls out by name).
- Explicit scope-out flags ("v1 does not include", "post-launch").

Feed to Phase 4 synthesis as ranking inputs --- domains/flows aligned with intent get higher value-priority; explicit scope-outs are tagged `out-of-scope` regardless of code-evidence.

If `intent.md` is missing -> warn but continue; downstream `/flow:office-hours` (Q42) is the authoring path.

---

## 3. Phase 1 --- app-classifier interview (shared)

Owns the base questions via `_shared/app-classifier-pattern.md`:

- Framework (locked to Next.js for v1 --- this skill rejects non-Next.js with a clear message).
- App category (CRM / ops / docs / commerce / ...).
- Primary persona shape.
- Scale (multi-tenant? RBAC depth? data volume?).

**Phase 1 is lighter in retrofit mode** --- code-evidence dominates Phase 4 synthesis, so Phase 1 just orients the agent on app shape. No greenfield-style follow-ups (Q19.2).

---

## 4. Phase 2 --- pattern-driven candidate generation (shared)

WebSearch + agent SaaS knowledge + pattern catalogs (e.g., Pragmatic Engineer's "SaaS pattern library"). Produces a candidate flow list for the app category from Phase 1. Same utility consumed by Q19; output is mode-agnostic.

---

## 5. Phase 3 --- deterministic code scan (retrofit-only)

Glob/Grep/Read over the Next.js App Router conventions:

| Signal | Glob target | Mining rule |
|---|---|---|
| Routes (pages + layouts) | `src/app/**/page.tsx`, `src/app/**/layout.tsx` | Each route -> candidate flow; route segment -> domain hint |
| Server actions | `src/app/**/actions.ts`, `src/lib/actions/**` | Each exported async function -> candidate flow (action verb) |
| Dialogs / modals | `src/components/**/dialog.tsx`, `**/modal.tsx`, `**/*-dialog.tsx` | Dialog name -> candidate flow |
| Menu items | `src/components/sandbox/sandbox-nav.tsx`, sidebar configs | Menu item -> candidate flow (existing FDA shape if sandbox is wired up) |
| API endpoints | `src/app/api/**/route.ts`, `src/pages/api/**/*.ts` (legacy) | Endpoint -> candidate flow if user-facing |

**Pushback resolutions** locked at Q11:

- **Framework = Next.js for v1.** Cross-framework support parked v1.1.
- **Evidence-anchors per candidate.** Each Phase 3 candidate carries the source file path (e.g., `src/app/(frontend)/(app)/customers/page.tsx`) in the Notes column.
- **Agent-proposes-but-user-overrides slugs.** Slugs (`<DOMAIN-NN>`) are agent-proposed during Phase 4; user overrides at Phase 5.
- **Fewer-larger-flows bias.** Multiple routes/actions on a single feature -> ONE flow with multiple AC scenarios, not N flows.
- **Thin-code fallback redundant.** When code signals are thin, Phase 2 pattern catalogs fill gaps --- no need for a separate fallback path.

---

## 6. Phase 4 --- synthesis (retrofit-specific)

### 4-tag implementation-status taxonomy

| Tag | Definition |
|---|---|
| `implemented` (check) | Code exists + tests exist + sandbox URL exists. |
| `partially-implemented` (warning) | Code exists but incomplete (no tests OR no sandbox). |
| `missing-but-recommended` (X) | No code, but pattern catalog says the flow is expected for this app shape. |
| `implemented-no-pattern-match` (question) | Code exists but doesn't match any pattern catalog entry --- novel flow specific to this product. |

Tag is rendered in the **Notes column** (NOT in Status column, which stays blank per `master-flow-inventory.md:18` lock).

### Value-priority

Each candidate ranked High / Medium / Low based on:

- Phase 0 intent alignment (priority verbs hit).
- Phase 3 code-evidence weight (heavy code presence = high; thin = lower).
- Phase 2 pattern-catalog signal (universally-expected SaaS flow = high; advanced = low).

Value-priority is rendered as a tag in Notes alongside the status tag.

### Status column policy

Stays blank in the inventory. `flow-doc-author` (Q15.7) sets the per-flow `status:` front-matter in story docs from code-evidence at doc-authoring time; the inventory is the foreign-key registry, not the implementation tracker.

---

## 7. Phase 5 --- user confirmation (shared)

Preview proposed inventory rendered as output markdown. User picks:

- **Approve as-is.**
- **Edit inline** --- slug overrides, drop flows, re-tag, re-order.
- **Reject** --- exit cleanly; user refines intent and re-runs.

---

## 8. Idempotency --- skip / interactive merge / `--force` (same as Q19.5)

Three scenarios mirror Q19.5: no existing inventory -> create; existing -> Skip/Merge/Force prompt; `--force` -> bypass.

**Merge is natural for retrofit too** --- second pass discovers new code signals after the first pass.

---

## 9. Failure recovery --- max 2 retries per Phase 1 question; thin-code -> defer to Phase 2

Same pattern as Q19.6 with one addition: Phase 3 scan returning zero signals across all 5 mining rules -> defer entirely to Phase 2 pattern catalogs; flag the surprise in Phase 5 preview (`"Code scan found 0 user-facing flows --- inventory derived from pattern catalog only"`).

---

## Worked example

BriteBase retrofit (28-domain consumer with ~400 candidate flows already present):

1. **Phase 0.** `intent.md` exists -> priority verbs ("crew dispatch", "client portal", "quote-to-cash") feed into Phase 4 ranking.
2. **Phase 1.** App-classifier interview confirms: Next.js App Router, ops + commerce hybrid, multi-tenant, role-rich.
3. **Phase 2.** Pattern catalog proposes ~80 candidate flows (CRM + dispatch + commerce patterns).
4. **Phase 3.** Code scan walks `src/app/(frontend)/(app)/**/page.tsx` (138 routes), server actions (94 exports), dialogs (42 modals), sandbox nav (61 entries). Cross-references against Phase 2 candidates.
5. **Phase 4.** Synthesis tags: 142 `implemented`, 38 `partially-implemented`, 17 `missing-but-recommended`, 23 `implemented-no-pattern-match`. Value-priority: 47 High, 89 Medium, 84 Low.
6. **Phase 5.** User reviews; corrects 6 slugs; drops 4 "implemented-no-pattern-match" candidates that turn out to be legacy admin tooling; approves.
7. Skill writes `docs/product/master-flow-inventory.md`. Sets `state.inventory_complete=true`.

---

## See also

- `docs/design-rationale/fda-plugin-interview.md` Q11 --- canonical 6-phase architecture spec.
- `docs/design-rationale/fda-plugin-interview.md` Q19 --- greenfield twin (`flow-inventory-interview`).
- `docs/design-rationale/fda-plugin-interview.md` Q25 --- master-inventory schema this skill writes.
- `skills/_shared/app-classifier-pattern.md` --- BC-6955 shared utility (Phases 0/1/2/5).
- `skills/_shared/code-evidence-collector.md` --- BC-6955 helper consumed by Phase 3 + Q15.7.
- `skills/flow-inventory-interview/SKILL.md` --- greenfield twin.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; `MODE=retrofit` gates this skill's invocation.
- `skills/flow-legacy-cross-reference/SKILL.md` --- sibling retrofit-only sub-skill (cross-references the inventory rows this skill writes against legacy Linear milestones).
