---
name: flow-inventory-interview
description: Greenfield Socratic inventory generator for the flow-architecture plugin (implements CDR-023). Output `docs/product/master-flow-inventory.md` populated with proposed domains + flows. Triggered by `/flow:start-project` (or standalone `/flow:inventory`) when `flow-preflight` mode classifier returns `greenfield`. Five phases — Phase 0 (PROJECT-INTENT priority filter) -> Phase 1 (app-classifier interview, shared with Q11 retrofit) -> Phase 2 (pattern-driven candidate generation, shared) -> skip Phase 3 (no code) -> Phase 4 (greenfield synthesis with 3-tag scope-priority) -> Phase 5 (user confirmation, shared). Per-run footprint ~10-30 min end-to-end (mostly user time).
user-invocable: false
disable-model-invocation: true
allowed-tools: WebSearch, AskUserQuestion, Read, Write, Bash
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q19, Q10, Q11"
  related-locks: "memory:208-222 (Q19 7 sub-decisions); Q11 (memory:68) shares Phase 0/1/2/5 via _shared/app-classifier-pattern.md; Q25 master-inventory schema"
---

# flow-inventory-interview

Greenfield Socratic inventory generator. Produces `docs/product/master-flow-inventory.md` with proposed domains + flows + 3-tag scope-priority taxonomy, derived from a 5-phase user interview + pattern-catalog synthesis.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7). The user-facing wrapper is `/flow:inventory`; `/flow:start-project` dispatches to this skill when `flow-preflight` classifies the project as greenfield.

**Critical relationship to Q11.** Shares Phases 0, 1, 2, 5 verbatim with `flow-inventory-codebase-scan` via `_shared/app-classifier-pattern.md` (BC-6955 deliverable). Differs in:

- Skipping Phase 3 (no codebase to scan).
- Phase 4 status taxonomy (3-tag scope-priority for greenfield vs. 4-tag implementation status for retrofit).
- Heavier Phase 1 interview (4 greenfield-only follow-up questions).

The full design rationale lives in `docs/design-rationale/project_fda_plugin_interview.md` Q19 (memory:208-222). Q11 (memory:68) is the retrofit twin; Q25 defines the master-inventory schema this skill writes.

---

## 1. Phase sequence (Q19.1) --- 5 phases

| Phase | Source | Description |
|---|---|---|
| 0 | shared | PROJECT-INTENT.md priority filter |
| 1 | shared | app-classifier interview (extended with 4 greenfield follow-ups) |
| 2 | shared | pattern-driven candidate generation |
| **3** | --- | **SKIPPED** (no codebase) |
| 4 | greenfield-specific | synthesis with 3-tag scope-priority |
| 5 | shared | user confirmation |

Skill explicitly logs the Phase 3 skip with rationale for audit trail:

```
Greenfield mode: no codebase to scan; proceeding to synthesis from interview + pattern signals.
```

---

## 2. Phase 1 Socratic depth (Q19.2)

The shared `_shared/app-classifier-pattern.md` utility owns the base questions (framework, app category, primary persona shape, scale) --- used by both Q11 and Q19.

Q19 adds **4 greenfield-only follow-ups** defined in this skill's body (NOT in `_shared/` --- they're Q19-specific):

### (a) Domain envisioning

> "What top-level domains do you imagine? Examples: SaaS CRM = Contacts/Deals/Pipeline/Reports; installation business = Quotes/Properties/Crew/Routing/Billing."

### (b) Flow-density-per-domain

> "Which domains will have heavy UI investment (10+ atomic actions) vs admin-only (less than 5)?"

### (c) MVP sequencing

> "Which 2-3 domains are MVP-essential vs post-launch?"

### (d) Persona density

> "How many distinct personas access this app? small SaaS = 1-2; multi-tenant CRM = 4-8; complex ops = 10+."

Phase 1 depth is the **dominant signal source** for Q19 (vs. Q11 where code-evidence dominates).

---

## 3. Phase 4 synthesis (Q19.3) --- 3-tag scope-priority taxonomy

Per-flow tag:

| Tag | Definition |
|---|---|
| `mvp` | Must-have for v1; user flagged the domain MVP-essential + flow is core to the domain's primary user task. |
| `nice-to-have` | Plausible v1 inclusion if scope permits; pattern-catalog-suggested but not user-flagged. |
| `post-launch` | Out of v1 scope; user flagged the domain post-launch OR pattern catalog flags as advanced. |

Rendered in the **Notes column** alongside any pattern context (no new column needed; Status column stays blank per `master-flow-inventory.md:18` lock).

### Deliberate divergence from Q11 on Notes-column content type

Verified against BriteBase `master-flow-inventory.md` AUTH section `:42-52`:

- **Q11 (retrofit)** uses Notes for **code-evidence anchors** --- route paths (`/login`), component names (`User-nav dropdown`), scope references (`Droidor scope (BC-5988)`).
- **Q19 (greenfield)** uses Notes for **scope-priority tags** because no code-evidence anchor exists yet.

Both modes' Notes carry mode-appropriate context, but the content type **differs by design**.

---

## 4. Output format (Q19.4)

Produces `docs/product/master-flow-inventory.md` matching the BriteBase schema:

- Front-matter `last_reviewed: <ISO-8601>` + status block.
- Top-level groupings.
- Domain sections.
- Per-domain table with columns `# / Flow / Status / Notes`.

`<PROJECT_NAME>` substituted from `.flow/config.json` `linear_project_name`.

Status column **left blank** per existing schema. `Status map: TBD` and `Journey: TBD` are populated later by `flow-linear-scaffold`.

### Top-level groupings derivation

Agent infers groupings during Phase 4 synthesis from domain semantics + pattern-catalog conventions:

- `auth` / `tenancy` / `team` -> `PLATFORM FOUNDATIONS`
- primary product domains -> `CORE WORKFLOWS`
- admin / reporting -> `OPERATIONS`

Defaults are **agent-proposed**; user reviews + edits during Phase 5 confirmation.

### Single-grouping fallback

If user declines all proposed groupings (small project), emit a single `## CORE` grouping containing all domains.

---

## 5. Idempotency (Q19.5) --- skip / interactive merge / `--force` overwrite

Three scenarios:

| Scenario | Behavior |
|---|---|
| No existing inventory | Create from scratch (greenfield common case). |
| Existing inventory + skill re-run | `AskUserQuestion` with 3 options: **Skip** (preserve existing) / **Merge** (add only newly-proposed flows under existing domains; preserve existing rows + Status column values) / **Force overwrite** (regenerate from scratch --- destructive, requires confirmation). |
| `--force` flag | Bypasses the interactive prompt; overwrites. |

**Merge is natural for iterative greenfield discovery** --- Phase 1 reveals a new domain after the initial pass.

---

## 6. Failure recovery (Q19.6)

| Failure | Behavior |
|---|---|
| Phase 1 interview-loop on clarification failures | Max 2 retries per question. On third unclear answer, flag the question as `skipped/needs-revisit` + continue. |
| Phase 4 synthesis: insufficient signal to tag a flow | Tag `nice-to-have` with Notes annotation `(unclear from interview --- revisit at user confirmation)`. |
| Phase 5 reject | Skill exits cleanly; user re-runs after refining intent. |

Do NOT auto-iterate forever.

---

## 7. User-confirmation gates (Q19.7) --- Phase 5 = 1 of Q10's 4 greenfield gates

Within-Phase-1-interview `AskUserQuestion`s are **interview-cadence** interactions, NOT high-stakes orchestrator gates --- they don't count against Q10's budget.

### Phase 5 surface (matches Q11)

Preview the proposed inventory rendered as output markdown. User picks:

- **Approve as-is.**
- **Edit inline** --- slug overrides per Q11 pushback / move flows between mvp/nice-to-have/post-launch / drop flows.
- **Reject** --- exit; user refines intent and re-runs.

---

## Worked example

Brand Hub greenfield (runtime-determined domain count per Q34 disambiguation; ~5-7 in this example, NOT pinned to BriteBase's 28 nor the legacy-milestone count):

1. **Phase 0.** Read `docs/product/intent.md` --- pull out priority verbs ("self-serve brand asset reuse", "agency tenancy", "audit trail").
2. **Phase 1.** App-classifier interview via `_shared/app-classifier-pattern.md` + 4 greenfield follow-ups. User responds: framework=Next.js, persona-density=multi-tenant (4-8), MVP-essential=brand/library/admin, post-launch=integrations/analytics.
3. **Phase 2.** Pattern-catalog generation (WebSearch + agent SaaS knowledge) -> proposes ~31 candidate flows across ~5-7 domains.
4. **Phase 3.** SKIPPED with audit-trail log.
5. **Phase 4.** Synthesis assigns 3-tag scope-priority: 11 `mvp`, 9 `nice-to-have`, 11 `post-launch`. Top-level groupings: PLATFORM FOUNDATIONS (auth + tenancy), CORE WORKFLOWS (brand + library + admin), OPERATIONS (audit + reporting).
6. **Phase 5.** Render proposed inventory; user moves 2 flows from `nice-to-have` to `mvp`, drops 1 `post-launch` flow, approves.
7. Skill writes `docs/product/master-flow-inventory.md`. Status column blank; `last_reviewed: 2026-05-15`. Sets `state.inventory_complete=true` for orchestrator dispatch.

---

## See also

- `docs/design-rationale/project_fda_plugin_interview.md` Q19 --- canonical 7-sub-decision spec.
- `docs/design-rationale/project_fda_plugin_interview.md` Q11 --- retrofit twin (`flow-inventory-codebase-scan`).
- `docs/design-rationale/project_fda_plugin_interview.md` Q25 --- master-inventory schema this skill writes.
- `skills/_shared/app-classifier-pattern.md` --- BC-6955 shared utility (Phases 0/1/2/5).
- `skills/flow-inventory-codebase-scan/SKILL.md` --- retrofit twin.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; `MODE=greenfield` gates this skill's invocation.
- `skills/flow-linear-scaffold/SKILL.md` --- downstream sub-skill that consumes the inventory rows.
