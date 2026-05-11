---
name: flow-inventory-add
description: Lightweight inventory append sub-skill for the flow-architecture plugin (implements CDR-023). Two modes — sub-flow-add (append one new flow row under an existing domain) and domain-add (append a fresh domain section via Q19-mini interview). Append-only semantics; never rewrites existing rows; never renames IDs. Triggered by `/flow:add-sub-flow` and `/flow:add-domain`. Sub-flow-add ~30s, domain-add ~5-10 min (interview-paced). Hard-rejects duplicates; sets a state flag for downstream regen-index dispatch.
user-invocable: false
disable-model-invocation: true
allowed-tools: AskUserQuestion, Bash, Read, Write
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q20"
  related-locks: "memory:224-238 (Q20 7 sub-decisions); memory:208-222 (Q19 — `domain-add` reuses Q19-mini subset: Phases 1+4+5)"
---

# flow-inventory-add

Append-only sub-skill that adds one row OR one section to `docs/product/master-flow-inventory.md`. Two modes are dispatched by the calling orchestrator; this skill is the shared inventory-write layer that `/flow:add-sub-flow` and `/flow:add-domain` call into.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7).

**Append-only contract.** Existing rows are never rewritten. Existing IDs are never renamed (CLAUDE.md "never rename existing IDs" guardrail + master-flow-inventory.md schema lock). Silent overwrites are not a v1 behaviour — duplicate IDs hard-reject.

The full design rationale lives in `docs/design-rationale/project_fda_plugin_interview.md` Q20 (memory:224-238). Q19 (memory:208-222) defines the parent 5-phase greenfield interview; `domain-add` mode invokes the Q19-mini subset (Phases 1+4+5 — interview, synthesis for one domain only, user confirmation) via `_shared/app-classifier-pattern.md`. (`_shared/app-classifier-pattern.md` itself owns Phases 0/1/2/5; the 1+4+5 subset here is the orchestration-level slice Q20.1 invokes for single-domain authoring.)

---

## 1. Two modes dispatched by caller (Q20.1)

| Mode | Caller | Inputs | Output |
|---|---|---|---|
| `sub-flow-add` | `/flow:add-sub-flow` | target `<DOMAIN>`, optional `flow_id` (auto-suggested), `title`, `primary persona`, `related_flows`, Notes | one new row appended to the domain section |
| `domain-add` | `/flow:add-domain` | proposed `<DOMAIN>` code + display name | new domain section appended under the appropriate grouping |

Mode is determined by the caller. If the skill is somehow invoked standalone without mode context, present an `AskUserQuestion` to pick between the two; do not infer.

---

## 2. Flow ID auto-suggestion (sub-flow-add) (Q20.2)

Parse the target domain section rows. Find the highest existing `<DOMAIN>-NN`. Propose `<DOMAIN>-(N+1)` zero-padded to 2 digits (matches `TEAM-08`, `AUTH-11` precedent).

**Split-suffix support** per CLAUDE.md: if the user indicates "split of existing flow", offer `<DOMAIN>-NN-a` / `-b` instead of the next sequential. The suggested ID is rendered in the confirmation prompt; user can override.

---

## 3. Append mechanics (Q20.3)

### Sub-flow-add

1. Regex-locate the target domain section by H3 header: `^### <DOMAIN> ---.* \(\d+ flows\)$`.
2. Locate the table by column-header signature.
3. Find the table terminator: next `### ` heading OR `---` boundary OR EOF.
4. Insert the new row immediately before the terminator.
5. Update the H3 heading's flow-count parenthetical (`(N flows)` -> `(N+1 flows)`).

All unrelated content is preserved verbatim.

### Domain-add

1. Run a Q19-mini interview (shared utility): Phases 1 (app-classifier interview) + 4 (synthesis for one domain only) + 5 (user confirmation).
2. Produce a new domain block: H3 header + metadata line + flow table.
3. Determine the top-level grouping per Q19.4 derivation (PLATFORM FOUNDATIONS / CORE WORKFLOWS / OPERATIONS / single-group fallback).
4. Insert the new domain block at the end of its grouping (before the next `## ` heading OR `---`).

---

## 4. Idempotency --- hard-reject on duplicate (Q20.4)

- **Sub-flow-add.** Proposed `<DOMAIN>-NN` already exists -> reject with a clear error citing the line number, suggest the split-suffix or next-sequential alternative, abort. No silent overwrite.
- **Domain-add.** Proposed `<DOMAIN>` code already has a section -> reject with `"<DOMAIN> already exists; use /flow:add-sub-flow instead"`, abort.

Re-run safety: a same-input re-run aborts identically. No half-state ever lands on disk.

---

## 5. Failure recovery (Q20.5)

- Inventory parse failure -> abort + surface the line number; do NOT auto-repair (would risk silent data loss).
- User cancels at confirmation -> no write; clean exit.
- Domain-add interview clarification failures -> max 2 retries per question (Q19.6 pattern); on third unclear answer, flag the question as `skipped/needs-revisit` and continue.

Single-output skill: a failure means that single output didn't land. The orchestrator decides next steps.

---

## 6. User-confirmation gates (Q20.6)

### Sub-flow-add (1 within-skill confirmation)

```
Add <DOMAIN-NN>: <title> under <DOMAIN> section as flow #<N>?
Notes: <notes>
  - Approve
  - Edit (slug / title / notes)
  - Cancel
```

### Domain-add (1 within-skill confirmation)

Matches Q19 Phase 5 surface — preview the proposed section + flows; user picks `Approve as-is` / `Edit inline` (slug overrides per Q11 pushback) / `Reject` (exit; user refines intent).

**Gate-budget accounting.** Incremental-add mode is outside Q10's 5/4 retrofit/greenfield gate budget per Q12 mode classification. Q47 governs whether the orchestrator adds gates beyond Q20's.

---

## 7. Downstream regen trigger (Q20.7)

Q20 ends at the master-inventory edit. Per Q18's v1 surface, the `flow-regen-index` skill is auto-invoked at the END of `/flow:add-domain` and `/flow:add-sub-flow` — that's the **orchestrator's** responsibility, not this skill's.

This skill sets a `state.inventory_changed = true` flag in the orchestrator's state object so downstream `flow-regen-index` (and `flow-linear-scaffold`, if applicable) can dispatch. The orchestrator owns the dispatch decision; this skill owns only the write semantics.

---

## Worked example

`/flow:add-sub-flow` invocation against a Brand-Hub-shaped project with the AUTH domain at 11 flows:

1. Caller passes mode=`sub-flow-add`, target=`AUTH`, title="Login with SAML SSO", primary_persona="Tenant admin".
2. Skill parses the AUTH section, finds highest existing ID `AUTH-11`, proposes `AUTH-12`.
3. `AskUserQuestion` confirmation surfaces the proposed row; user Approves.
4. Skill regex-locates the AUTH H3 (`### AUTH --- Authentication & Tenancy (11 flows)`), inserts the new row before the table terminator, updates the H3 to `(12 flows)`.
5. Skill emits `state.inventory_changed = true`; orchestrator dispatches `flow-regen-index` next.

If the same call re-fires (user re-runs `/flow:add-sub-flow` with identical inputs), Q20.4's pre-write check catches `AUTH-12` already exists and aborts with the duplicate-rejection message. No half-state.

---

## See also

- `docs/design-rationale/project_fda_plugin_interview.md` Q20 --- canonical 7-sub-decision spec.
- `docs/design-rationale/project_fda_plugin_interview.md` Q19 --- parent 5-phase greenfield interview; `domain-add` invokes the Phases 1+4+5 Q19-mini subset.
- `skills/_shared/app-classifier-pattern.md` --- the shared interview utility (BC-6955 deliverable) consumed by `domain-add`.
- `skills/flow-regen-index/SKILL.md` --- downstream auto-dispatched by the orchestrator after this skill emits `inventory_changed=true`.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; emits the structured preamble this skill's caller passes through.
