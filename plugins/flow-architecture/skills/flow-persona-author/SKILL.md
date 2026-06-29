---
name: flow-persona-author
description: Per-persona behavioral persona-doc authoring sub-skill for the flow-architecture plugin (BC-14018; implements the persona half of CDR-023's doc set). Writes ONE markdown file at `docs/product/personas/<slug>.md` per behavioral persona the project serves, conforming to the canonical persona template (5 FLOOR depth-spine sections, scored against quality-rubric P1–P5). Whole-file authoring — UNLIKE flow-doc-author / flow-journey-author there is NO deterministic frontmatter builder: a persona's front-matter (`role`/`device`/`linear_label`/`last_reviewed`) carries no Linear-children fields, so `Agent(persona-doc-author)` returns the WHOLE file (front-matter + body) and only `last_reviewed` is dispatcher-supplied. Runs AFTER `flow-journey-author` so the per-domain journey docs (the persona's richest behavioral source) and the story docs (the `personas:` slug source) both exist. 1 agent per unique persona slug; parallel across personas with a concurrency cap of ~10 to avoid Claude Code background-agent queueing. 0 synchronous gates in default mode.
user-invocable: false
disable-model-invocation: true
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "BC-14018; mirrors Q16 (flow-journey-author) dispatch contract"
  related-locks: "BC-12905 C2 (persona-doc-author agent + canonical template + rubric P1–P5); BC-12573 (persona-exists floor); ADR-041 (personas: = behavioral slugs only); Q16 (flow-journey-author, the mirror sub-skill)"
---

# flow-persona-author

Per-persona behavioral persona-doc authoring sub-skill. Writes ONE markdown file per persona at `docs/product/personas/<slug>.md`, conforming to the canonical persona template. Single `Agent(persona-doc-author)` per persona slug.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7). The orchestrators (`/flow:start-project`, `/flow:add-domain`) dispatch it by name; `flow-doc-author` and `flow-journey-author` are its siblings.

**Ordering constraint.** Runs AFTER `flow-journey-author` (which runs after `flow-doc-author`). Both upstream sets must exist before a persona is authored: the **story docs** are the source of the `personas:` slug set this skill enumerates, and the **journey docs** are the persona-doc-author agent's richest behavioral source (their per-phase persona mindset lines, pain points, and decision points). Authoring a persona before its journeys exist would starve the agent of exactly the material that lifts a persona above the generic-block P5 floor.

The persona subsystem this skill completes: existence floor (`flow_persona_lint.py` / persona-exists, BC-12573, deterministic) → depth grader (`quality-reviewer` `doc_kind: persona_doc`, rubric P1–P5, LLM) → **author (`persona-doc-author`, dispatched here)**. ADR-041 fixes the field's meaning: `personas:` is behavioral persona-doc slugs only, never RBAC/access roles.

---

## 1. Authoring strategy — whole-file agent, NO builder

Unlike `flow-doc-author` (story) and `flow-journey-author` (journey), there is **no `build_*_frontmatter.py` step**. Those skills stamp front-matter deterministically because it carries Linear `children: [BC-…]` / `parent_issue` / a milestone UUID the agent cannot know. A persona's front-matter is `role` / `device` / `linear_label` / `last_reviewed` — all derivable from this skill's inputs, none from Linear — so `Agent(persona-doc-author)` writes the front-matter itself and returns the **whole file**. The one field the agent does not invent is `last_reviewed`: it stamps the dispatcher-supplied `today`.

The skill's only post-processing on the returned markdown:

1. **Strip HTML comments** — the agent cites a load-bearing source inline as an `<!-- … -->` comment (and may emit `<!-- TODO: <field> -->` for a genuinely-unknown specific); strip whole-line and inline HTML comments before writing.
2. **Catch the error sentinel** — if the agent returns a single `<!-- PERSONA-DOC-AUTHOR-ERROR: <reason> -->` (missing required input), do NOT write the file; surface it in the end-of-run summary and continue (Section 5).
3. **Write** `docs/product/personas/<slug>.md`.

The agent contract (inputs, steps, output) is `agents/persona-doc-author.md`. The substance bar is `skills/_shared/quality-rubric.md` **P1–P5** scored by `quality-reviewer` (`doc_kind: persona_doc`); the structural floor is the separate persona-exists gate.

---

## 2. The persona set — reconciled union of story slugs ∪ inventory column

The set of personas to author is the **union** of:

- **Story-doc `personas:` slugs** — walk every `docs/product/flows/<domain>/*.md` story doc, collect each non-empty `personas:` front-matter slug (the same parse as `flow_persona_lint.py`: strip a trailing `(qualifier)`, split on `,` and `;`). This is the authoritative set — it is exactly what the persona-exists floor checks.
- **Inventory persona column / intent `## Target users`** — the `master-flow-inventory.md` persona column and `intent.md` `## Target users` may name a persona the stories also reference; reconcile (dedup by slug) so the authored set matches the slugs in play.

**minus honest-empty** — a story with `personas: []` / absent contributes nothing (ADR-029 honest-empty canon; presence, not non-emptiness). A pure-automation flow that names no behavioral persona adds no row.

Authoring the reconciled union — rather than the inventory column alone — is what makes the dispatch test's "every produced persona resolves its own existence check" true **by construction**: the set this skill authors is exactly the set the floor lints.

Per slug, the dispatcher gathers the `persona-doc-author` inputs:

| Input | Source |
|---|---|
| `slug` | the reconciled `personas:` slug (kebab-case = filename = `role:`) |
| `display_name` | inventory persona-column display, or a derived `<Title> (<one-clause role>)` |
| `device` | inventory/intent if present, else `<!-- TODO: device -->` for the agent to infer from journeys |
| `repo_root` | the consumer repo absolute path |
| `template_path` | `docs/templates/persona.md` (seeded into the consumer at Phase 1 templates-scaffold) |
| `intent_path` | `docs/product/intent.md` |
| `journey_paths` | every `docs/product/journeys/<domain>.md` whose `personas:` aggregate includes this slug — the agent's richest source |
| `served_flows` | the flow IDs whose story `personas:` include this slug (for `## Touchpoints` + scope shape) |
| `partial_state` | any interview note / existing thin persona to enrich / failure-they-can't-absorb hint |
| `today` | the run's ISO date for `last_reviewed` |

---

## 3. Dispatch pattern — 1 agent per persona; parallel across personas

| Invocation | Wall time |
|---|---|
| `/flow:add-domain` (1 domain) | the new domain's persona set is usually 1–3 slugs → ~60-90s (parallel) |
| `/flow:start-project` (multi-domain) | the project-wide reconciled union, often ~3–7 slugs → `ceil(K/10) * ~90s`; K≤10 → ~90s |

`K` = number of **unique** persona slugs across the project (NOT domains — a persona is authored once and cross-linked from every story/journey that serves it, so a 7-persona project is 7 agents regardless of domain count). Parallel across personas within a ~10 concurrency cap; never split one persona across agents (a single agent preserves the doc's internal voice + the P5 no-byte-reuse-across-siblings property).

---

## 4. Idempotency — skip-if-exists + `--force`

Same contract as Q15.3 / Q16.3. Pre-write check per `docs/product/personas/<slug>.md`:

- **Default:** skip an existing persona doc (do not clobber a hand-authored or already-reviewed persona) + summarize the skip at end-of-run.
- **`--force`:** overwrite.
- **Interactive mode:** per-doc `AskUserQuestion`.

A persona that already exists and passes is the common case on `/flow:add-domain` (a new domain often reuses an existing persona); skip-if-exists keeps the new domain's stories cross-linking to the existing doc rather than rewriting it.

---

## 5. Failure recovery — log + continue

Same as Q15.5 / Q16.5. A persona whose agent returned the `PERSONA-DOC-AUTHOR-ERROR` sentinel (or whose write failed) surfaces in the end-of-run summary; the user re-runs the skill with `--force` (idempotent against the already-written set). One failed persona never aborts the batch.

---

## 6. INDEX — author/refresh `docs/product/personas/INDEX.md`

After the batch, ensure `docs/product/personas/INDEX.md` exists and carries a row per authored persona (the canonical INDEX schema: `| Persona | Device | Status | File |`, Status ∈ {Drafted, Reviewed}). A freshly-authored persona lands as `Drafted` — it is promoted to `Reviewed` only after `quality-reviewer` passes it (the human-certifies-not-the-agent rule; this skill does not self-certify). If an INDEX already exists, add missing rows; do not downgrade an existing `Reviewed` row.

---

## 7. Fidelity / mechanical layer

`bash scripts/verify-docs.sh` once after the batch (front-matter presence, link resolution, freshness — same as Q15.4 / Q16.4). The substance review (`quality-reviewer` `doc_kind: persona_doc`, P1–P5) and the existence floor (persona-exists) are **separate gates**, not part of this skill — this skill authors; the gates certify.

---

## 8. User-confirmation gates — 0 synchronous gates

Filesystem write; git review is the implicit gate. Contributes 0 to the orchestrator's gate budget. Same rule as Q15.6 / Q16.6.

---

## Ordering constraint (recap)

Serial across the doc layers: `flow-linear-scaffold` → `flow-doc-author` → `flow-journey-author` → **`flow-persona-author`**. The persona is authored last among the doc authors because it is the synthesis layer — it reads the stories (its slug source) and the journeys (its behavioral source) and cross-links back to both. The story `## Actor` and journey persona-section links to the persona doc are forward references that resolve at the end-of-run link-resolution check (deterministic `docs/product/personas/<slug>.md` paths).

`/flow:retrofit-project` is a follow-on (BC-14018 scopes `/flow:start-project` + `/flow:add-domain` only); a retrofit run authors personas the same way once wired.

---

## Worked example

`/flow:start-project` greenfield, 5 domains, 3 unique personas across them:

1. Skill walks `docs/product/flows/<domain>/*.md` across all 5 domains → collects the union of non-empty `personas:` slugs → 3 unique (`operator`, `dispatcher`, `client`), reconciled against the inventory column.
2. Per slug, gathers inputs: `journey_paths` = the journeys whose aggregate `personas:` includes the slug; `served_flows` = the flows whose `personas:` includes it.
3. Skip-if-exists: 0 of 3 exist → fans out 3 background `Agent(persona-doc-author)` calls in parallel (1 batch under the ~10 cap).
4. Each agent returns the whole file; skill strips HTML comments and writes `docs/product/personas/{operator,dispatcher,client}.md`. ~90s wall.
5. Authors `docs/product/personas/INDEX.md` with 3 `Drafted` rows.
6. Mechanical layer: `bash scripts/verify-docs.sh` → 0 errors (every story `## Actor` link + journey persona link now resolves).
7. End-of-run summary: `flow-persona-author: 3/3 personas authored (Drafted), 0 skipped, 0 failed. Run quality-reviewer doc_kind: persona_doc to promote to Reviewed.`

---

## See also

- `agents/persona-doc-author.md` — the per-persona agent contract (inputs, steps, whole-file output) this skill dispatches.
- `templates/docs/templates/persona.md` — the canonical persona template (5 FLOOR sections) the agent conforms to; seeded into the consumer at Phase 1.
- `skills/flow-journey-author/SKILL.md` — the mirror sub-skill + immediate predecessor (provides the journey docs as the agent's behavioral source).
- `skills/flow-doc-author/SKILL.md` — upstream sub-skill (provides the story docs whose `personas:` this skill enumerates).
- `skills/_shared/quality-rubric.md` — persona dimensions **P1–P5**, the substance bar `quality-reviewer` scores against.
- `scripts/lib/flow_persona_lint.py` — the persona-exists floor (BC-12573); the set this skill authors is exactly the set this lint checks.
- `docs/decisions/041-fda-personas-behavioral-slugs-only.md` — `personas:` = behavioral persona-doc slugs only (the convention this skill's set-enumeration assumes).
