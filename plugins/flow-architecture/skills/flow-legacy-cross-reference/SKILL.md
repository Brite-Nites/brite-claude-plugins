---
name: flow-legacy-cross-reference
description: Retrofit-only sub-skill for the flow-architecture plugin (implements CDR-023). NEVER invoked from greenfield. Satisfies Q9's additive-only "cross-reference annotations" lock by appending an HTML-comment-bracketed `## FDA migration` section to every legacy Linear milestone description, mapping it to one or more FDA domains. Three-tier mapping cascade (flow-ID histogram -> title-fuzzy -> LLM semantic), marker-based idempotency, two-pass execution (generate review doc -> user edits + bumps `last_reviewed` -> re-invoke executes). End-to-end wall for M=27 legacy milestones: ~14s Tier 1 batched-body reads (Tier-1 budget assumes Linear MCP's `list_issues({milestone})` filter is reliable — see Section 1 caveat) + ~5-15s Tier 3 LLM fall-throughs (when 5-10 milestones don't hit Tier 2) + ~40.5s Pass 2 writes (3 calls/milestone) ≈ **~60-70s** when filter behaves; significantly more if the milestone-filter gotcha forces a per-child `get_issue` fallback.
user-invocable: false
disable-model-invocation: true
allowed-tools: mcp__plugin_workflows_linear-server__list_milestones, mcp__plugin_workflows_linear-server__get_milestone, mcp__plugin_workflows_linear-server__save_milestone, mcp__plugin_workflows_linear-server__list_issues, mcp__plugin_workflows_linear-server__get_issue, Agent, AskUserQuestion, Bash, Read, Write
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q9, Q14"
  related-locks: "memory:94-106 (Q14 6 sub-decisions); Q13.5 retry pattern (memory:90); Q22 milestone schema"
---

# flow-legacy-cross-reference

Retrofit-only sub-skill. Walks the consumer project's existing Linear milestones, proposes 1-N FDA domain mappings per milestone, lets the user review the proposal in a markdown file, then writes an HTML-comment-bracketed `## FDA migration` appendix to each milestone's description.

**This skill MUST NOT be invoked from greenfield.** It satisfies Q9's additive-only contract for retrofits — legacy work stays in its legacy milestones; the appendix is a cross-reference annotation, not a state migration. The dispatching orchestrator (`/flow:retrofit-project`) is responsible for the upstream check; this skill assumes retrofit mode.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7).

The full design rationale lives in `docs/design-rationale/fda-plugin-interview.md` Q14 (memory:94-106). Q9 (the additive-only lock) and Q22 (milestone schema) are upstream constraints this skill honors.

---

## 1. Mapping determination (Q14.1) --- 3-tier cascade

Per legacy milestone, walk three tiers in order. Stop at the first tier producing a confident match.

### Tier 1 --- flow-ID histogram

Parse each legacy issue body under the milestone for `\b[A-Z]{2,5}-\d{2,3}\b` flow-ID tokens. Cross-check against `docs/product/master-flow-inventory.md`. Take the top 1-3 domains by frequency. **Threshold:** 0.6 of identified flow IDs must agree on a domain for the tier to "fire".

**Degenerate on v1 retrofits** like Brand Hub (no FDA flow-IDs yet exist in legacy bodies). Kept for future-state retrofits where the project has partially adopted FDA before invoking the skill.

### Tier 2 --- title-fuzzy match

Levenshtein and token-overlap match the legacy milestone title against the inventory's domain display names. **Threshold:** 0.6 combined score. This is the dominant signal source on most v1 retrofits.

### Tier 3 --- LLM semantic-mapping fallback

`Agent(general-purpose, parallel)` over unmatched milestones. Each agent receives the legacy milestone title + description + ~3 child-issue titles. Returns a JSON blob:

```json
{"domains": ["AUTH", "TENANCY"], "confidence": 0.75, "rationale": "..."}
```

Or `null` when nothing maps. **Tier 3 is NOT authoritative** --- its output seeds the Q14.6 review doc; the user is the final arbiter.

### Tier 1 read budget (Pass-1 only)

Each milestone needs its child-issue bodies parsed for flow-ID tokens. Use **batched `list_issues({milestone: <id>, includeBody: true})`** — one call per milestone — NOT per-child `get_issue` (which would be 5-10x more calls per milestone). 27 milestones * ~500ms ~= ~14s for the read phase, regardless of Tier outcomes. Tier 1 fires its histogram against the returned bodies in-memory; no additional Linear calls.

**Filter-reliability caveat.** Per `memory/gotcha_linear_list_issues_milestone_filter.md`, the `list_issues({milestone:})` filter can return cross-milestone bleed-through on some Linear MCP versions. At Pass-1 start, probe one milestone's `list_issues({milestone, includeBody})` and verify all returned issues have the expected `milestone:` field. If bleed-through is detected, fall back to per-child `get_issue` — re-budget Tier 1 at `M_children * ~500ms` ≈ **~67-135s for 27 milestones * 5-10 children**, pushing end-to-end from ~60-70s to ~110-175s. Surface the fallback wall-time bump to the user before continuing.

### Wall-time estimate (Pass-1 mapping only)

Theoretical max for the LLM tier = ~27 parallel calls * ~5-10s ~= ~10s assuming unlimited concurrency. Realistic fan-out 6-10 concurrent -> 20-50s for all 27. Most milestones hit Tier 2; Tier 3 realistically fires for 5-10 fall-throughs only --- **~5-15s actual** for Brand-Hub-shaped retrofit, ON TOP of the ~14s Tier 1 read phase above. Re-measure once the skill is built (parking lot).

The review-doc's `Source signal` column shows which tier produced each proposal so the user can spot Tier-3 fallbacks first.

---

## 2. Appendix format (Q14.2)

HTML-comment-bracketed `## FDA migration` section. Marker pair:

```html
<!-- FDA-MIGRATION-START -->
## FDA migration

<content here>

<!-- FDA-MIGRATION-END -->
```

Markers are the idempotency mechanism. Re-runs rewrite content between markers; content outside is never touched.

### Section contents

1. **CDR-023 + operating-standards links** as **absolute GitHub URLs** (`https://github.com/Brite-Nites/handbook/blob/main/...`). Relative paths don't resolve when Linear renders a milestone description in a different repo context.
2. **Coverage table.** Columns: FDA domain -> one-line summary -> Linear milestone link.
3. **Policy (a) callout** --- legacy work proceeds in its legacy milestone; FDA milestones are net-new.
4. `Generated by flow-legacy-cross-reference on <ISO-8601>` footer.

### Format gotchas

- Numbered/bullet **hybrid** (not pure bullets). Avoids the Linear MCP markdown bullet-truncation gotcha documented in `memory/gotcha_linear_markdown_mangling.md`.
- Template includes a `<!-- TODO: GitBook migration --->` comment for the future-state when the handbook moves to a public docs site.
- **Post-write spot-check.** `get_milestone(id)` after each `save_milestone` to detect Prosemirror mangling (per Q13.5 pattern). On detected drift, log and continue (no auto-retry; Q14.5 governs).

---

## 3. Mutation order (Q14.3) --- preview -> review-doc gate -> execute serial

No parallelism. **3 Linear calls per milestone in Pass 2**: pre-write `get_milestone` + `save_milestone` + post-write `get_milestone` spot-check (per Q13.5 pattern in Section 2). 27 milestones * 3 calls * ~500ms ~= **~40.5s for Pass-2 writes**. Each milestone is independent (no chains). Tier 1 reads from Pass-1 (Section 1) are NOT re-fetched.

Sequence:

1. Generate the review doc (`docs/plans/<retrofit-slug>-cross-reference.md`). Skill exits.
2. User reviews + edits inline; bumps front-matter `last_reviewed: TBD` to an ISO-8601 date.
3. User re-invokes the orchestrator -> skill detects the date bump -> executes.

---

## 4. Idempotency (Q14.4) --- marker-based; NO scaffold-log analog

Pre-write `get_milestone(id)` per legacy milestone:

- `<!-- FDA-MIGRATION-START -->` present -> **rewrite content between markers** (replace section).
- Markers absent -> **append section** to end of description.

**Linear-side state IS the persistence layer.** Unlike `flow-linear-scaffold` (Q13), this skill does NOT write an append-only log under `.flow/scaffold-log/`. 27 milestones * 3 MCP calls * ~500ms ~= ~40.5s overhead is acceptable; the marker contract is the single source of truth.

---

## 5. Failure recovery (Q14.5) --- cadence "log + continue" pattern

Each `save_milestone` is independent (no chains; legacy milestones aren't dependency-graph-shaped). On error:

- **Transient** (timeout, rate-limit) -> 1 retry + 2s backoff.
- **Permanent** (invalid markdown, auth, missing project membership) -> log + continue to next milestone.

End-of-run summary surfaces errored rows. User can re-run the skill (idempotent per Section 4) to retry just the failures.

NO sub-flow-atomic semantics — independent rows, not a dependency chain.

---

## 6. User-confirmation gate (Q14.6) --- literal markdown review document

The gate is a **filesystem artifact**, not a chat ack.

### Two-pass execution

**Pass 1 --- generate.** Skill writes `docs/plans/<retrofit-slug>-cross-reference.md`. Front-matter:

```yaml
---
generated_by: flow-legacy-cross-reference@<version>
generated_at: <ISO-8601>
last_reviewed: TBD
---
```

Body: a table per legacy milestone (Milestone | Proposed FDA domain(s) | Source signal | Notes) + freeform edit space. Skill exits.

**Pass 2 --- execute.** User reviews + edits inline; bumps `last_reviewed:` to an ISO-8601 date. User re-invokes the orchestrator. Skill re-reads the (possibly user-edited) review doc as the **source of truth** for the mapping. If `last_reviewed: TBD` still present, skill refuses to execute with: `"Review doc still has last_reviewed: TBD. Edit docs/plans/<slug>-cross-reference.md, bump the date, and re-run."`

This makes review completion an **unambiguous filesystem check**, not a chat-ack. The doc is one of the 5 Q10 retrofit gates ("terse cross-reference review document"). It is deletable post-retrofit (a `docs/plans/` artifact).

---

## Worked example

Brand Hub retrofit, M=27 legacy milestones:

1. **Pass 1.** Orchestrator dispatches; skill enumerates 27 milestones via `list_milestones`.
2. Tier 1 fires for 0/27 (Brand Hub has no FDA flow-IDs in legacy issue bodies).
3. Tier 2 fires for 22/27 (title-fuzzy hits domain display names cleanly).
4. Tier 3 fires for 5/27 fall-throughs; ~3 agents parallel -> ~10s wall.
5. Skill writes `docs/plans/brand-hub-retrofit-cross-reference.md` with `last_reviewed: TBD`. Exits.
6. User reviews; corrects 2 of the Tier-3 proposals; bumps `last_reviewed: 2026-05-15`. Re-invokes orchestrator.
7. **Pass 2.** Skill re-reads the doc; serially executes 27 milestones with 3 Linear calls each (pre-write `get_milestone` + `save_milestone` + post-write spot-check `get_milestone`) at ~500ms each. Total ~40.5s.
8. 1 milestone hits a transient timeout; retried after 2s + succeeds. 0 permanent failures.
9. Skill exits cleanly with summary: `flow-legacy-cross-reference: 27/27 milestones updated, 1 transient retried, 0 permanent failures.`

---

## See also

- `docs/design-rationale/fda-plugin-interview.md` Q14 --- canonical 6-sub-decision spec.
- `docs/design-rationale/fda-plugin-interview.md` Q9 --- additive-only retrofit lock.
- `docs/design-rationale/fda-plugin-interview.md` Q22 --- milestone schema (Sub-flows table this skill does NOT touch).
- `memory/gotcha_linear_markdown_mangling.md` --- Prosemirror mangling patterns this skill spot-checks against.
- `skills/flow-linear-scaffold/SKILL.md` --- sibling sub-skill that creates net-new FDA milestones; runs after this skill in retrofit mode.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; preamble's `MODE=retrofit` gates this skill's invocation.
