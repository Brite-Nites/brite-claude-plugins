---
name: flow-journey-author
description: Per-domain journey doc authoring sub-skill for the flow-architecture plugin (implements CDR-023). Writes ONE markdown file at `docs/product/journeys/<domain>.md` per domain, conforming to the Q26 locked template (variable phase count per Q26 mod 5; ~290-450+ lines based on TEAM precedent). Hybrid authoring — programmatic substitution for 8 deterministic top-level YAML keys + 2 body items; single `Agent(general-purpose)` call for 7-9 narrative sections (single-agent preserves cross-phase narrative continuity). Runs AFTER `flow-doc-author` so story docs are available as authoring context. 1 agent per domain; parallel across domains for multi-domain scaffolds with a concurrency cap of ~10 to avoid Claude Code background-agent queueing. 0 synchronous gates in default mode. Per-domain footprint ~90s; wall time scales as `ceil(N/10) * ~90s` — N≤10 domains finish in ~90s, N=27 finishes in ~270s (3 batches under the cap).
user-invocable: false
disable-model-invocation: true
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q16, Q26"
  related-locks: "memory:126-145 (Q16 8 sub-decisions); Q15 (memory:108-124, upstream story-doc author); Q26 journey template; Q23 mod 2 L3 review summary (parent-issue body)"
---

# flow-journey-author

Per-domain journey doc authoring sub-skill. Writes ONE markdown file per domain conforming to the Q26 locked journey-doc template. Single `Agent(general-purpose)` per domain --- multi-agent staged authoring is parked for v1.1 if domain content bloats past context limits.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7).

**Ordering constraint.** Runs AFTER `flow-doc-author` (Q15). Even greenfield `NOT_STARTED` stubs confirm flow IDs + personas + related_flows for journey authoring. Uniform ordering simplifies the orchestrator --- the ~60s parallelism savings on greenfield doesn't justify conditional ordering against ~5min/gate human review time on retrofit.

The full design rationale lives in `docs/design-rationale/fda-plugin-interview.md` Q16 (memory:126-145). Q26 defines the journey-doc template; Q15 (memory:108-124) defines the upstream story-doc author this skill reads from.

---

## 1. Authoring strategy (Q16.1) --- hybrid

### Programmatic substitution (8 deterministic YAML keys + 2 body items)

| YAML key | Source |
|---|---|
| `domain` | inventory section |
| `milestone` | scaffold output (`BC-XXXX`) |
| `personas` | deduplicated from inventory rows OR `personas/INDEX.md` |
| `flow_ids_in_scope` | inventory domain section row IDs |
| `status` | `in-progress` initial (describes doc-authoring lifecycle, NOT delivery state) |
| `figma` | `TBD` |
| `last_reviewed` | current ISO-8601 |
| `intent` | `../intent.md` (per Q26 mod 1) |

Body deterministic items: H1 title `# <DOMAIN> --- <Display name>`; doc-type blockquote (~3 lines from template `:12-14`).

### Agent-authored sections

Single `Agent(general-purpose)` call writes 7-9 narrative sections:

- **7 always-required:**
  1. `## Actor / Persona`
  2. `## Scenario + Expectations`
  3. `## Journey phases` --- with N variable sub-phases
  4. `## Out of scope`
  5. `## Related domains and cross-scenario journeys`
  6. `## Open questions`
  7. `## See also`
- **1 sometimes-included:** `## Decision points` (skip if linear journey).
- **1 optional:** `## L2 review summary` (Q26 mod 2) --- populated only if L2 review ran for this domain per the meta-Q lock; captures CEO + Design perspectives.

### Per-phase structure

Each `## Phase N` entry contains:

- `*Persona:*` line
- `*Mindset:*` line
- 2-paragraph narrative
- `**Pain points:**` bullets
- `**Opportunities:**` bullets
- Job stories table referencing real flow IDs

**Single agent (not multi-agent staged)** is the locked dispatch mode --- preserves cross-phase narrative continuity. Multi-agent staged authoring is parked v1.1 if a domain bloats past the agent's context limit.

---

## 2. Dispatch pattern (Q16.2) --- 1 agent per domain; parallel across domains

| Invocation | Wall time |
|---|---|
| `/flow:add-domain` (1 domain) | ~60-90s |
| `/flow:start-project` (multi-domain) | `ceil(N/10) * ~90s` — N≤10 → ~90s; N=27 → ~270s (3 batches under ~10 concurrency cap) |
| `/flow:retrofit-project` (multi-domain) | same formula |

The agent runs in parallel across domains within a concurrency cap of ~10 (avoids Claude Code background-agent queueing), NOT in parallel within a domain (which would break cross-phase narrative continuity).

---

## 3. Idempotency (Q16.3) --- skip-if-exists + `--force`

Same as Q15.3. Pre-write check per `docs/product/journeys/<domain>.md`:

- **Default:** skip + summarize at end-of-run.
- **`--force`:** overwrite.
- **Interactive mode:** per-doc `AskUserQuestion`.

---

## 4. Fidelity-review (Q16.4) --- 2-layer

### Mechanical layer

`bash scripts/verify-docs.sh` once after the batch (same as Q15.4).

### Narrative layer

Per-doc background fidelity-review. **Journey-specific drift checks** added to the reviewer prompt:

- Phase count > 0.
- Each phase has the required sub-structure: persona + mindset + narrative + pain points + opportunities + job stories table.
- Job stories table references **real flow IDs** (no fabricated rows).
- Status values match the canonical taxonomy.
- Cross-scenario journey references resolve OR are explicitly `TBD`.

---

## 5. Failure recovery (Q16.5) --- log + continue

Same as Q15.5. Domain-failed-doc surfaces in the end-of-run summary; user re-runs the skill with `--force` (idempotent against the failure list).

---

## 6. User-confirmation gates (Q16.6) --- 0 synchronous gates

Filesystem write; git review is the implicit gate. Contributes 0 to Q10's 5/4 budget. Same rule as Q15.6.

---

## 7. Authoring context (Q16.7)

The per-domain agent prompt receives:

- Q26 template path.
- Inventory section block for the domain.
- **All N story docs at `docs/product/flows/<domain>/*.md`** (authored by `flow-doc-author` in the prior step).
- Persona doc(s) for in-scope personas.
- `PROJECT-INTENT.md`.
- Linear milestone description from scaffold output.
- Optional L2 review summary if `state.l2_review_<domain>` exists in the orchestrator's state object.

**Story-docs-as-context is what makes the journey synthesize across flows.** TEAM cut-1a -> cut-1b precedent --- the journey doc is a narrative consolidation, not an independent draft.

---

## 8. Ordering constraint (Q16.8)

Serial within a domain: `flow-linear-scaffold` -> `flow-doc-author` -> `flow-journey-author`. NOT in parallel.

Cross-domain: parallel (Section 2).

Even greenfield `NOT_STARTED` stubs confirm flow IDs + personas + related_flows for the journey author. Uniform ordering simplifies the orchestrator.

---

## L-review summary routing (clarified at Q16 lock time)

| L-scope | Target | Skill |
|---|---|---|
| L2 (domain) | journey doc `## L2 review summary` (Q26 mod 2) | flow-journey-author (this skill) |
| L3 (sub-flow) | parent issue body `## L3 review summary` (Q23 mod 2) | flow-linear-scaffold |
| L4 (discipline-child) | discipline child Plan section (single-discipline plan-X, NOT autoplan per meta-Q) | `/flow:plan-{discipline}` |

---

## Worked example

`/flow:start-project` greenfield, 5 domains:

1. Skill reads `state.scaffold_log` for all 5 domains -> 5 milestone BCs + N parent BCs + 5N children BCs.
2. Skill reads `docs/product/flows/<domain>/*.md` for all 5 domains -> ~31 story docs total (authored by Q15).
3. Skill fans out 5 background agents in parallel (all 5 fit in 1 batch under the ~10 concurrency cap per Section 2).
4. ~60-90s wall time (5 domains in a single batch; matches the per-domain footprint anchor — `ceil(5/10) * ~90s = ~90s`).
5. Mechanical layer: `bash scripts/verify-docs.sh` logs 0 errors.
6. Narrative layer: 5 fidelity-review agents; 4 PASS, 1 flagged for missing `## Open questions` section.
7. End-of-run summary: `flow-journey-author: 5/5 journeys authored, 1 narrative-drift flagged (tenancy missing Open questions).`

---

## See also

- `docs/design-rationale/fda-plugin-interview.md` Q16 --- canonical 8-sub-decision spec.
- `docs/design-rationale/fda-plugin-interview.md` Q26 --- journey-doc template.
- `docs/design-rationale/fda-plugin-interview.md` Q15 --- upstream story-doc author.
- `skills/flow-doc-author/SKILL.md` --- preceding sub-skill (provides story docs as authoring context).
- `skills/flow-linear-scaffold/SKILL.md` --- preceding sub-skill (provides milestone BC for the `milestone` front-matter field).
- `skills/flow-regen-index/SKILL.md` --- downstream sub-skill (consumes the journey doc's `milestone:` field for INDEX header).
