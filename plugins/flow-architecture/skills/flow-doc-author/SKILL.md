---
name: flow-doc-author
description: Per-domain story doc authoring sub-skill for the flow-architecture plugin (implements CDR-023). Writes N markdown files at `docs/product/flows/<domain>/<flow-id>.md`, one per sub-flow under a domain, conforming to the Q27 locked template + Q27 amendment 1 (mod 4: optional `## Cross-domain dependencies` section). Hybrid authoring — programmatic substitution for 17 deterministic top-level YAML keys + 2 deterministic body items (`children` is one top-level key with 5 nested fields); parallel background `Agent(general-purpose)` dispatch for up to 9 narrative sections (the 9th — `## Cross-domain dependencies` — is OPTIONAL per Q27 amendment 1 and authored only when the sub-flow has cross-domain build-order or gating relations). Runs AFTER `flow-linear-scaffold` so parent + children BC numbers + sibling `blockedBy` relations are available for 1:1 mirror. 2-layer fidelity-review (mechanical `verify-docs.sh` + per-doc narrative drift check). 0 synchronous gates in default mode (filesystem writes; git review is the implicit gate). Per-domain authoring wall ~60s greenfield, ~90s retrofit; the second-wave fidelity-review fan-out adds ~30-60s, which can be overlapped with downstream `flow-journey-author`.
user-invocable: false
disable-model-invocation: true
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q15, Q27"
  related-locks: "memory:108-124 (Q15 7 sub-decisions); Q13.3 fidelity-review pattern (memory:86); Q27 story-doc template"
---

# flow-doc-author

Per-domain story doc authoring sub-skill. Writes one markdown file per sub-flow conforming to the Q27 locked story-doc template. Authors N files in parallel via background agents; collects at sub-flow boundary.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7).

**Ordering constraint.** Runs AFTER `flow-linear-scaffold` (Q13) so the parent + children BC numbers are available for substitution. The orchestrator owns this ordering; this skill assumes scaffold-log output is available in the run state.

The full design rationale lives in `docs/design-rationale/fda-plugin-interview.md` Q15 (memory:108-124). Q27 defines the story-doc template; Q13 (memory:80) defines the upstream scaffold; Q22-Q28 define the substitution sources.

---

## 1. Authoring strategy (Q15.1) --- hybrid

### Programmatic substitution (17 deterministic top-level YAML keys + 2 body items)

`children.*` is one top-level key with 5 nested fields — counted as 1 of 17 in the top-level tally; expanded into 5 rows in the table below for readability.

The skill substitutes the following without LLM dispatch:

| YAML key | Source |
|---|---|
| `flow_id` | inventory row |
| `domain` | flow_id prefix |
| `status` | inventory column OR Q15.7 code-evidence (capped at BUILT) |
| `parent_issue` | scaffold output |
| `children.story` | scaffold output |
| `children.engineering` | scaffold output |
| `children.design` | scaffold output |
| `children.qa` | scaffold output |
| `children.docs` | scaffold output |
| `personas` | inventory row |
| `related_flows` | inventory adjacency |
| `figma` | `TBD` |
| `sandbox_url` | Q15.7 code-evidence scan when status > NOT_STARTED, else `TBD` --- **NOT inventory Notes column**, which holds component names like `edit-role-dialog` |
| `staging_url` | `TBD` |
| `real_app_url` | `TBD` |
| `e2e_test` | `TBD` |
| `user_docs_url` | `TBD` |
| `qa_status` | `not-tested` |
| `qa_last_signed_off` | `null` |
| `last_reviewed` | current ISO-8601 |
| `intent` | `../../intent.md` (per Q27 mod 1) |

Body deterministic items: H1 title `<DOMAIN-NN>: <Inventory title>`; doc-type-warning blockquote from template boilerplate.

### Agent-authored (up to 9 narrative sections; the 9th is optional per Q27 amendment 1)

One `Agent(general-purpose, run_in_background: true)` per sub-flow. Each agent fills:

1. one-line summary blockquote
2. optional `## Status notes` (Q27 mod 2 --- include only when status drift OR retrofit code-evidence flag)
3. optional `## Cross-domain dependencies` (**Q27 amendment 1 mod 4** --- include only when the sub-flow has cross-domain build-order or gating relations. Bullet list of `<this-flow-id> blockedBy <other-flow-id>` and/or `<this-flow-id> gates <other-flow-id>` lines, each with a one-line reason. 1:1 mirror of Linear `blockedBy` relations on the sub-flow parent issue --- enforced by Q29 amendment 2 `cross-domain-deps-bidirectional` gate. Same-domain sibling deps go in `related_flows` front-matter, NOT here.)
4. `## Job story` --- When/I want/So I can JTBD format
5. `## Actor` --- RBAC + persona doc cross-link
6. `## Preconditions` --- max 3 bullets
7. `## Acceptance criteria` --- 3-5 Gherkin `Scenario:` blocks
8. `## Out of scope`
9. `## QA history` --- initial empty row

---

## 2. Dispatch pattern (Q15.2) --- parallel background

One `Agent(general-purpose, run_in_background: true)` per sub-flow. Skill collects all agents at sub-flow completion.

**Wall time:** ~30-60s for any N (vs ~4-8 min serial for N=8). Each agent receives:

- Skeleton with `TBD` markers for narrative fields.
- Q27 template path (incl. Q27 amendment 1 mod 4 `## Cross-domain dependencies` section).
- Persona doc(s) for the personas that act in THIS sub-flow specifically — resolved from the sub-flow's inventory `personas` field (Section 1 substitution table), not the project-wide persona set. For each role named in that field, resolve `docs/product/personas/<role>.md`; if the standalone doc is absent, fall back to that role's persona block in the parent journey's per-phase persona lines (or the intent.md `## Target users` cross-link). Embed the resolved subset in `partial_state` so each agent gets the individuated persona(s) for its flow, never a single project-wide default.
- Journey doc (if already authored --- in greenfield this skill runs before journey-author, so usually unavailable).
- Inventory row.
- Code-evidence summary (if status > NOT_STARTED --- Section 7).
- Cross-domain blockedBy snapshot for this sub-flow parent issue (from `flow-linear-scaffold` scaffold-log output --- list of `<other-flow-id, blocker-bc>` pairs; empty list = no cross-domain deps; agent omits the `## Cross-domain dependencies` section in that case).

---

## 3. Idempotency (Q15.3) --- skip-if-exists + `--force`

Pre-write check per sub-flow path. If `docs/product/flows/<domain>/<flow-id>.md` exists:

- **Default:** skip + summarize at end-of-run.
- **`--force`:** overwrite.
- **Interactive mode:** per-doc `AskUserQuestion` --- Overwrite / Skip / Cancel.

---

## 4. Fidelity-review (Q15.4) --- 2-layer

### Mechanical layer

`bash scripts/verify-docs.sh` once after the batch (logs to stdout but does NOT block). Catches mechanical issues --- broken internal links, malformed front-matter, stale `last_reviewed`.

### Narrative layer

Per-doc background fidelity-review agent. Each agent diffs the authored doc against:

- Q27 template structure.
- Persona doc(s).
- Journey doc (if available).
- Inventory row.
- Code-evidence (if collected).

Returns either `PASS` or the top-3 narrative drift findings, capped at 100 words. Same pattern as Q13.3 (per-issue fidelity review in `flow-linear-scaffold`). FAILs surface in the run summary; user can `--force` regen targeted at the failed doc.

---

## 5. Failure recovery (Q15.5) --- log + continue

Story docs are independent --- an agent failure on doc #3 doesn't cascade to docs #4-N. Failed-doc surfaces in the end-of-run summary; user re-runs the skill with `--force` (idempotent against the failure list). Same pattern as Q14.5 in `flow-legacy-cross-reference`.

---

## 6. User-confirmation gates (Q15.6) --- 0 synchronous gates

Filesystem mutations are reviewable post-hoc via `git diff` + `verify-docs.sh` + commit/PR review. Linear writes (Q13) need synchronous gates because the world sees them immediately; markdown files in a branch are pre-publication.

**Pattern rule:** Linear writes -> synchronous gate; filesystem writes -> git review gate.

Contributes 0 to Q10's 5/4 retrofit/greenfield gate budget.

---

## 7. Retrofit code-evidence (Q15.7) --- deterministic per-sub-flow scan

Trigger: inventory status > NOT_STARTED.

Glob/Grep/Read targeted at feature folders:

- `src/components/<domain>/`
- `src/app/(frontend)/(app)/<route>/`
- `src/payload/collections/<collection>.ts`

Extract:

- Existing AC scenarios from `*.test.ts` files -> feed to the narrative agent as `## Acceptance criteria` candidates.
- Component file paths -> populate `<sandbox_url>` heuristic.
- Sandbox URL from `src/components/sandbox/sandbox-nav.tsx`.

### Status mapping caps at BUILT

| Code state | Mapped status |
|---|---|
| code-exists + tests + sandbox-URL | BUILT |
| code-exists but incomplete | IN_PROGRESS |
| no code | NOT_STARTED |

**Cannot promote to QA_SIGNED_OFF** --- requires the Linear QA child's sign-off (workflow event, not codebase state).
**Cannot promote to SHIPPED** --- requires customer-doc filesystem signal at `docs/product/customer-docs/<domain>/<flow-id>.md` (scoped out of code-evidence; v1.1 candidate).

### Status drift handling

If the inventory says NOT_STARTED but code-evidence shows BUILT (or vice versa), the skill flags the drift in the doc's `## Status notes` section --- NOT a silent overwrite:

> BUILT --- code-evidence cited; inventory marked NOT_STARTED --- recommend reconcile.

BriteBase Cut 1a "BUILT --- code-evidence cited" pattern (TEAM-01..06 precedent).

### Status taxonomy

`NOT_STARTED -> IN_PROGRESS -> BUILT -> QA_SIGNED_OFF -> SHIPPED` + `BLOCKED` orthogonal. No `PARTIALLY_BUILT` state. Verified against `master-flow-inventory.md:22-27`, `flows/INDEX.md:15-20`, `docs/templates/job-story.md:4`.

---

## Worked example

Greenfield `/flow:start-project` for the AUTH domain with N=8 sub-flows after Q13 scaffold has written 8 parents + 40 children:

1. Skill reads `state.scaffold_log.auth` -> 8 parent BCs + 40 children BCs.
2. Skill walks `master-flow-inventory.md` AUTH section -> 8 inventory rows.
3. Skill fans out 8 background agents in parallel; each writes one story doc to `docs/product/flows/auth/auth-NN.md`.
4. ~50s wall time for all 8 agents to return.
5. Mechanical layer: `bash scripts/verify-docs.sh` logs 0 errors.
6. Narrative layer: 8 fidelity-review agents return; 7 PASS, 1 flagged for missing `## Out of scope` section.
7. End-of-run summary: `flow-doc-author: 8/8 docs authored, 1 narrative-drift flagged (auth-04 missing Out of scope).` User can re-run with `--force=auth-04` to regen.

---

## See also

- `docs/design-rationale/fda-plugin-interview.md` Q15 --- canonical 7-sub-decision spec.
- `docs/design-rationale/fda-plugin-interview.md` Q27 --- story-doc template.
- `docs/design-rationale/fda-plugin-interview.md` Q13 --- upstream scaffold (provides parent + children BCs).
- `skills/flow-linear-scaffold/SKILL.md` --- preceding sub-skill.
- `skills/flow-journey-author/SKILL.md` --- downstream sub-skill that consumes these story docs as authoring context.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; preamble's `MODE` signal drives whether Q15.7 code-evidence fires (retrofit) or skips (greenfield).
