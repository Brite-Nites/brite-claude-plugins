---
name: flow-journey-author
description: Per-domain journey doc authoring sub-skill for the flow-architecture plugin (implements CDR-023). Writes ONE markdown file at `docs/product/journeys/<domain>.md` per domain, conforming to the Q26 locked template (variable phase count per Q26 mod 5; ~290-450+ lines based on TEAM precedent). Hybrid authoring — deterministic frontmatter stamping via the extracted `scripts/build_journey_frontmatter.py` builder (scaffold-log frontmatter + story-doc aggregation per ADR-033, fixture-locked); single body-only `Agent(journey-doc-author)` call for 7-9 narrative sections (single-agent preserves cross-phase narrative continuity). Runs AFTER `flow-doc-author` so story docs are available as authoring context AND as the personas/flow_ids aggregation source. 1 agent per domain; parallel across domains for multi-domain scaffolds with a concurrency cap of ~10 to avoid Claude Code background-agent queueing. 0 synchronous gates in default mode. Per-domain footprint ~90s; wall time scales as `ceil(N/10) * ~90s` — N≤10 domains finish in ~90s, N=27 finishes in ~270s (3 batches under the cap).
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

Per-domain journey doc authoring sub-skill. Writes ONE markdown file per domain conforming to the Q26 locked journey-doc template. Single `Agent(journey-doc-author)` per domain --- multi-agent staged authoring is parked for v1.1 if domain content bloats past context limits.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7).

**Ordering constraint.** Runs AFTER `flow-doc-author` (Q15). Even greenfield `NOT_STARTED` stubs confirm flow IDs + personas + related_flows for journey authoring. Uniform ordering simplifies the orchestrator --- the ~60s parallelism savings on greenfield doesn't justify conditional ordering against ~5min/gate human review time on retrofit.

The full design rationale lives in `docs/design-rationale/fda-plugin-interview.md` Q16 (memory:126-145). Q26 defines the journey-doc template; Q15 (memory:108-124) defines the upstream story-doc author this skill reads from.

---

## 1. Authoring strategy (Q16.1) --- hybrid

### Deterministic stamping --- the `build_journey_frontmatter.py` builder (BC-13028, ADR-033)

The frontmatter is stamped by an **extracted deterministic builder**, not LLM prose, so it is fixture-lockable and cannot silently regress to empty placeholders (the journey half of BC-13028 #4; the story half is `build_story_frontmatter.py` per BC-13168 — a deliberately SEPARATE script, since the two share no parsing core). The skill shells out to `scripts/build_journey_frontmatter.py`, which reads exactly two standardized inputs — the per-domain scaffold-log's **frontmatter** (`templates/.flow/scaffold-log/SCHEMA.md`; the body tables are never parsed) and the domain's **story-doc frontmatter** (deterministically stamped since BC-13168) — and emits the ADR-033 canonical 9-key block:

```
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/build_journey_frontmatter.py \
  --scaffold-log <repo>/.flow/scaffold-log/<domain>.md \
  --flows-dir <repo>/docs/product/flows/<domain> --as-of <today>
```

| YAML key | Source |
|---|---|
| `domain` | scaffold-log frontmatter `domain` (kebab folder-slug per ADR-033) |
| `display_name` | scaffold-log frontmatter `linear_milestone_name` |
| `linear_milestone.{name,id}` | scaffold-log frontmatter `linear_milestone_name` + `linear_milestone_id` (UUID — a milestone has no BC number) |
| `personas` | story-doc frontmatter aggregation: first-seen dedup walking flow_id order (builder-derived; the unstandardized inventory is NOT read) |
| `flow_ids_in_scope` | story-doc frontmatter `flow_id` values, natural-sorted by numeric suffix |
| `status` | constant `in-progress` initial (describes doc-authoring lifecycle, NOT delivery state) |
| `figma` | constant `TBD` |
| `intent` | constant `../intent.md` (per Q26 mod 1) |
| `last_reviewed` | `--as-of` (current ISO-8601; injected so the builder stays golden-stable) |

Degrade contract: junk/missing scaffold-log values → `TBD` (never malformed YAML); a YAML-unsafe milestone name is emitted double-quoted; story docs without a valid `flow_id` are skipped whole; **zero valid story docs → exit 2** (the Q16.8 ordering contract was violated — fail loud, never stamp honest-empties). The lock is `tests/run-journey-frontmatter-vslice.sh` (golden + populated-key assertions). Schema canon: `docs/decisions/033-fda-journey-frontmatter-canon.md`.

The H1 title (`# <DOMAIN>: <Display name>`) and doc-type blockquote are **body** items authored by the agent (body-only contract below).

### Agent-authored sections (body-only contract)

Single `Agent(journey-doc-author)` call authors the **body only** --- the H1 title `# <DOMAIN>: <Display name>`, the doc-type blockquote, and 7-9 narrative sections --- and returns it as markdown. The skill prepends the builder-stamped frontmatter and writes the file. The agent **never emits frontmatter**: it is filesystem-only, so it cannot know the milestone UUID --- that contradiction was the proximate cause of the placeholder frontmatter (BC-13028 #4). Sections:

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

1. Skill reads `state.scaffold_log` for all 5 domains -> 5 milestone UUIDs + N parent BCs + 5N children BCs.
2. Skill reads `docs/product/flows/<domain>/*.md` for all 5 domains -> ~31 story docs total (authored by Q15).
3. Skill stamps 5 frontmatter blocks via `build_journey_frontmatter.py` (scaffold-log frontmatter + story-doc aggregation, Section 1), then fans out 5 background body-only agents in parallel (all 5 fit in 1 batch under the ~10 concurrency cap per Section 2) and prepends each stamped block to its returned body at collection.
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
- `skills/flow-linear-scaffold/SKILL.md` --- preceding sub-skill (writes the scaffold-log whose frontmatter sources the `linear_milestone` field).
- `skills/flow-regen-index/SKILL.md` --- downstream sub-skill (consumes the journey doc's `linear_milestone.id` for the INDEX header milestone link, per ADR-033).
- `docs/decisions/033-fda-journey-frontmatter-canon.md` (repo root) --- the journey frontmatter schema canon this skill stamps.
