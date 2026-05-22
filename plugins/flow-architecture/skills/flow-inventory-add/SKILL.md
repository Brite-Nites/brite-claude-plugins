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

The full design rationale lives in `docs/design-rationale/project_fda_plugin_interview.md` Q20 (memory:224-238). Q19 (memory:208-222) defines the parent 5-phase greenfield interview. `domain-add` mode invokes the Q19-mini subset — Phases 1+4+5, scoped to one domain — sourced from two layers:

| Phase | Sourced from | Content |
|---|---|---|
| 1 (base classifier) | `_shared/app-classifier-pattern.md` | framework / app category / persona shape / scale |
| 1 (greenfield follow-ups) | `flow-inventory-interview/SKILL.md` body, Section 2 | the 4 Q19.2 follow-up questions (domain envisioning, density, MVP sequencing, persona density) |
| 4 (synthesis) | `flow-inventory-interview/SKILL.md` body, Section 3 | 3-tag scope-priority taxonomy, but scoped to one domain |
| 5 (user confirmation) | `_shared/app-classifier-pattern.md` | preview rendering + Approve/Edit/Reject |

`_shared/app-classifier-pattern.md` owns Phases 0/1/2/5 generically; this skill's Q19-mini reuses Phases 1 (base) + 5 from that utility and Phases 1 (greenfield follow-ups) + 4 from `flow-inventory-interview`'s body. Skipping Phases 0 (no PROJECT-INTENT scope filter for single-domain add) and 2 (no pattern-catalog candidate generation — the user is naming the domain directly).

---

## 1. Modes dispatched by caller (Q20.1)

| Mode | Caller | Inputs | Output | Writes? |
|---|---|---|---|---|
| `sub-flow-add` | `/flow:add-sub-flow` | target `<DOMAIN>`, optional `flow_id` (auto-suggested), `title`, `primary persona`, `related_flows`, Notes | one new row appended to the domain section | yes |
| `domain-add` | `/flow:add-domain` (Branch A) | proposed `<DOMAIN>` code + display name | new domain section appended under the appropriate grouping | yes |
| `inventory-read` (Q20 amendment 1, BC-9971) | `/flow:add-domain` (Branch B) | existing `<DOMAIN>` code already present in inventory | structured H3-section metadata returned to caller (display name, sub-flow rows with `id` / `title` / `primary persona` / `Notes` / status tag, top-level grouping) | **no** |

Mode is determined by the caller. If the skill is somehow invoked standalone without mode context, present an `AskUserQuestion` to pick between the three; do not infer.

The `inventory-read` mode preserves Q47 sub-decision 4's boundary (the orchestrator never edits — and never re-parses — inventory directly): when `/flow:add-domain` Phase 2 routes to Branch B per Q20 amendment 1, the orchestrator dispatches this skill in `inventory-read` mode rather than implementing its own H3-section parser. Q20.5 failure recovery applies identically (parse failure → abort + surface line number; do NOT auto-repair).

---

## 2. Flow ID auto-suggestion (sub-flow-add) (Q20.2)

Parse the target domain section rows. Find the highest existing `<DOMAIN>-NN`. Propose `<DOMAIN>-(N+1)` zero-padded to 2 digits (matches `TEAM-08`, `AUTH-11` precedent).

**Split-suffix support** per CLAUDE.md: if the user indicates "split of existing flow", offer `<DOMAIN>-NN-a` / `-b` instead of the next sequential. The suggested ID is rendered in the confirmation prompt; user can override.

---

## 3. Append mechanics (Q20.3)

### Sub-flow-add

1. Regex-locate the target domain section by H3 header: `^### \`?<DOMAIN>\`? — .* \(\d+ flows\)$`. Per Q20 amendment 2 (BC-10352, 2026-05-22): em-dash `—` is the canonical separator (matches Q20.3 memory + Brand Hub iter-2 reality); backtick-wrap around `<DOMAIN>` is optional; `<DOMAIN>` is lowercase kebab-case (`^[a-z][a-z0-9-]*$`).
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

### Inventory-read (Q20 amendment 1, BC-9971)

1. Regex-locate the target domain section by H3 header: `^### \`?<DOMAIN>\`?[[:space:]]` (whitespace boundary, backtick-wrap optional; matches the canonical `### \`<DOMAIN>\` — <display> (N flows)` form per Q20 amendment 2 (BC-10352, 2026-05-22) AND tolerates the bare-no-backtick variant Brand Hub iter-2 occasionally used).
2. Parse the H3 line to extract `display` (the ` — <display>` portion, em-dash canonical) and the flow count (`(N flows)`).
3. Parse the table immediately following the H3 row-by-row: each row yields `{id, title, primary_persona, notes_or_status_tag}`. Determine the top-level grouping by walking BACKWARD from the H3 line to the nearest `^## ` heading.
4. Return the structured metadata to the caller — do NOT write. The Q20.4 hard-reject does NOT fire in this mode (the H3 IS expected to exist).
5. Q20.5 parse-failure semantics apply: malformed table / missing column header / sub-flow ID not matching `<DOMAIN>-NN` → abort + surface line number; do NOT auto-repair.

Return shape (consumed by `/flow:add-domain` § 2.B Step 2):

```
{
  "slug":          "<DOMAIN>",                 // echoed from input for round-trip safety
  "display":       "<display name>",           // parsed from ` — <display>` portion of H3 (em-dash canonical per Q20 amendment 2)
  "grouping":      "<PLATFORM FOUNDATIONS|CORE WORKFLOWS|OPERATIONS|...>",  // backward-walk from H3 to nearest `^## ` heading
  "flow_count":    <integer>,                  // parsed from `(N flows)`; orchestrator may cross-check against `len(sub_flows)`
  "sub_flows":     [                            // one entry per table row, insertion order preserved
    { "id": "<DOMAIN>-01", "title": "...", "primary_persona": "...", "notes_or_status_tag": "..." },
    ...
  ]
}
```

The `grouping` field is returned for forward-compatibility with v1.1 Q19.4-driven routing (e.g., if Phase 3 needs the top-level group for milestone-description population per Q22 schema); v1 orchestrator may discard it.

This mode is purely read-only and reuses Section 3 sub-flow-add's grammar predicates (H3 regex, table-terminator detection, ID-pattern check) — the same parser is the single source of truth across all three modes.

---

## 4. Idempotency --- hard-reject on duplicate (Q20.4)

- **Sub-flow-add.** Proposed `<DOMAIN>-NN` already exists -> reject with a clear error citing the line number, suggest the split-suffix or next-sequential alternative, abort. No silent overwrite.
- **Domain-add.** Proposed `<DOMAIN>` code already has a section -> reject with `"<DOMAIN> already exists; use /flow:add-sub-flow instead"`, abort.

Re-run safety: a same-input re-run aborts identically. No half-state ever lands on disk.

### Caller-side guard (Q20 amendment 1, BC-9971)

`/flow:add-domain` Phase 2 now runs a pre-dispatch classifier (`plugins/flow-architecture/scripts/flow-classify-domain-state.sh` + Linear `list_milestones` overlay) BEFORE calling this skill. The classifier returns one of `absent` / `inventory-only` / `journey-exists` / `fully-scaffolded-fs`; routing per outcome:

- `absent` → orchestrator dispatches this skill in `domain-add` mode (the binary Q20.4-applies case).
- `inventory-only` → orchestrator dispatches this skill in `inventory-read` mode (the new read-only mode in Section 1 above; Q20.4 hard-reject is suppressed in this mode because the H3 IS expected to exist).
- `journey-exists` / `fully-scaffolded-fs` → orchestrator surfaces an `AskUserQuestion` and does not dispatch this skill at all in v1; user choice may re-route to `inventory-read` + `--force` propagation in subsequent phases.

The Q20.4 hard-reject text above remains the binding safety net for any caller that bypasses the classifier and invokes `domain-add` directly against an already-inventoried `<DOMAIN>` — direct standalone invocation, third-party orchestrators in v1.1+, etc. The Q20.4 contract on `domain-add` mode is unchanged. Cross-link: `commands/add-domain.md` § Phase 2 carries the orchestrator-side implementation; `docs/design-rationale/project_fda_plugin_interview.md` § "Q20 amendment 1" carries the canonical rationale + four-outcome table.

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

### Inventory-read (0 within-skill confirmations)

Inventory-read is a pure read — no Q20.6 gate fires inside the skill. The caller (`/flow:add-domain` Branch B) owns the Q20.6 confirmation surface using the returned structured metadata as the preview content (see `commands/add-domain.md` § 2.B Step 4). This keeps Q47 sub-decision 4's boundary intact: the orchestrator does not parse inventory, but it does own caller-side UX for read-only flows.

**Gate-budget accounting.** Incremental-add mode is outside Q10's 5/4 retrofit/greenfield gate budget per Q12 mode classification. Q47 governs whether the orchestrator adds gates beyond Q20's.

---

## 7. Downstream regen trigger (Q20.7)

Q20 ends at the master-inventory edit. Per Q18's v1 surface, the `flow-regen-index` skill is auto-invoked at the END of `/flow:add-domain` and `/flow:add-sub-flow` — that's the **orchestrator's** responsibility, not this skill's.

This skill sets a `state.inventory_changed = true` flag in the orchestrator's state object after a successful `sub-flow-add` or `domain-add` write, so downstream `flow-regen-index` (and `flow-linear-scaffold`, if applicable) can dispatch. The orchestrator owns the dispatch decision; this skill owns only the write semantics.

In `inventory-read` mode (Q20 amendment 1), the skill sets `state.inventory_changed = false` because no write occurred — the existing inventory section is consumed verbatim. The orchestrator's Branch B (`commands/add-domain.md` § 2.B) reads this flag to suppress the redundant Phase 6 INDEX-regen trigger that would otherwise fire on `state.inventory_changed = true`.

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
