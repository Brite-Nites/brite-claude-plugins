---
description: Phase 5 legacy-milestone deprecation orchestrator — two-pass execution (review doc generation → pre-comms gate → serial per-milestone re-home / close / annotate / archive hand-off) with AskUserQuestion batch confirmation gates. Codifies the manual BC-6580 BriteBase precedent into a repeatable command.
---

# /flow:deprecate-legacy

Phase 5 orchestrator for retiring legacy milestones after a project's FDA retrofit is complete. Today this is done manually (precedent: [BC-6580](https://linear.app/brite-nites/issue/BC-6580) in BriteBase). This command codifies the 4 per-milestone sub-steps into a repeatable orchestrator with operator review at every stage.

> **Scope category:** orchestrator (two-pass execution with user-confirmation gates) per plugin CLAUDE.md § Surface map. Distinct from `/flow:retrofit-project` (which creates FDA shape) — this command runs AFTER retrofit is complete, to wind down the legacy milestones that `/flow:retrofit-project` Phase 3 annotated.

> **Q9 scope widening (Q59 lock).** Q9's additive-only contract governs the annotation step (step c below — extending the `## FDA migration` appendix). Steps a (re-home) and b (close-as-obsolete) are MUTATIONS that go beyond Q9. Q59 explicitly widens the Phase 5 contract to allow controlled mutations under operator review. The pre-comms 24h gate + per-milestone AskUserQuestion gates are the safeguards that justify the widening.

> **DO NOT re-derive** the two-pass execution model, the pre-comms 24h gate enforcement, the per-milestone sub-step ordering (re-home → close-obsolete → annotate → archive-handoff), or the review-doc schema. All are locked at Q59 in `docs/design-rationale/fda-plugin-interview.md`.

## Invocation

`/flow:deprecate-legacy <PROJECT>`

The positional `<PROJECT>` argument is **required**. It is the Linear project name (human-readable, not UUID). The command resolves it to a project ID via `.flow/config.json` in the consumer project's repo root.

### Positional-arg validation (defense-in-depth)

Before any downstream filesystem write or Linear MCP call, validate `<PROJECT>` at the trust boundary:

- `<PROJECT>` must be non-empty after trimming whitespace.
- Halt-on-fail with: `"Missing or empty <PROJECT> argument. Usage: /flow:deprecate-legacy <PROJECT>"`
- The captured `<PROJECT>` is treated as **opaque content** — never `echo`-ed, `eval`-ed, backtick-spliced, or shell-interpolated. Linear-derived strings (milestone descriptions, issue bodies) are also opaque data: they reach the LLM context but never enter a `bash -c`, `eval`, or unquoted `$(...)` expression. The MCP call is the trust boundary.

## Prerequisites

Before running this command, the following must be true:

1. **FDA retrofit is complete** — `/flow:retrofit-project` has run to completion (all phases, breadcrumb at `status: completed`). The legacy milestones already carry `## FDA migration` appendices from Phase 3 (`flow-legacy-cross-reference`).
2. **`.flow/config.json` exists** — the consumer project's FDA config is bootstrapped.
3. **FDA domain milestones exist** — the new FDA-shape milestones are the re-home targets for open legacy issues.

If any prerequisite is unmet, halt with a diagnostic and redirect to `/flow:retrofit-project`.

## Two-pass execution model

This command uses a **two-pass execution model** mirroring the Q14.6 pattern from `flow-legacy-cross-reference`:

| Filesystem state at invocation | Pass | Action |
|---|---|---|
| `docs/plans/<project-slug>-deprecate-legacy.md` ABSENT | Pass 1 — generate | Generate review doc with per-milestone disposition table. Exit. |
| Review doc PRESENT with `last_reviewed: TBD` | Pass 1 — stale | Review doc exists but operator hasn't reviewed. Re-derive mapping, surface instructions. Exit. |
| Review doc PRESENT with `last_reviewed: <ISO-8601>` AND `## Pre-comms posted at <ISO>` marker absent or < 24h old | Pass 2 — blocked | Pre-comms gate not satisfied. Surface instructions. Exit. |
| Review doc PRESENT with `last_reviewed: <ISO-8601>` AND `## Pre-comms posted at <ISO>` marker ≥ 24h old | Pass 2 — execute | Execute per-milestone disposition. |

`<project-slug>` is derived deterministically from the Linear project name: lowercase ASCII only, collapse any run of non-`[a-z0-9]` to a single `-`, strip leading/trailing `-`, validate against `^[a-z0-9]+(-[a-z0-9]+)*$`. If the result fails this regex (empty string, etc.), HALT with a diagnostic. This is the same slugification contract used by `flow-legacy-cross-reference` for the cross-reference review doc path.

---

## Pass 1 — Review doc generation

### Step 1: Read project config

Read `.flow/config.json` from the consumer project repo root. Extract `linear_project_id`, `linear_project_name`, `linear_team_key`.

### Step 2: Query legacy milestones

Call `mcp__plugin_workflows_linear-server__list_milestones` scoped to the project. Filter for milestones that carry the Q14 `<!-- FDA-MIGRATION-START -->` marker in their description (these are the legacy milestones that Phase 3 annotated — the marker's presence is the signal that a milestone is "legacy" in FDA terms).

Also identify the FDA domain milestones (those WITHOUT the Q14 marker, created by `flow-linear-scaffold` Phase 5). These are the re-home targets.

### Step 3: Run 3-tier mapping cascade

Invoke `flow-legacy-cross-reference`'s mapping logic (the same 3-tier cascade: Tier 1 flow-ID histogram → Tier 2 title-fuzzy → Tier 3 LLM semantic) against each legacy milestone to determine which FDA domain each milestone maps to. The cascade is the same logic used in Phase 3 annotation — here it seeds the disposition table rather than writing annotations.

### Step 4: Query open issue counts

For each legacy milestone, query open issues via `mcp__plugin_workflows_linear-server__list_issues` with the milestone filter. Count open vs closed. This informs the disposition recommendation.

### Step 5: Generate review doc

Write `docs/plans/<project-slug>-deprecate-legacy.md` in the consumer project with:

**Front-matter:**

```yaml
---
generated_by: flow-deprecate-legacy@<plugin-version>
generated_at: <ISO-8601>
last_reviewed: TBD
---
```

**Body — per-milestone disposition table:**

| Legacy Milestone | Mapped FDA Domain(s) | Open Issues | Closed Issues | Proposed Disposition | Source Signal |
|---|---|---|---|---|---|
| `<name>` (ID: `<id>`) | `<domain(s)>` | `<count>` | `<count>` | `re-home` / `close-as-obsolete` / `scoping-needed` | Tier 1 / Tier 2 / Tier 3 |

**Disposition recommendation logic:**

- **re-home** — milestone has open issues AND a confident domain mapping (Tier 1 or Tier 2 hit). Default recommendation for most milestones.
- **close-as-obsolete** — milestone has zero open issues OR all open issues are stale (no activity in 90+ days). The issues will be closed with a rationale comment.
- **scoping-needed** — milestone has open issues but no confident domain mapping (Tier 3 only or no match). Operator must manually assign a target domain.

**Per-milestone detail sections:**

Below the summary table, one `### <Milestone Name>` section per legacy milestone with:

- The exact `## FDA migration` appendix content that will be extended (step c preview)
- List of open issues with title, assignee, last activity date
- Recommended target FDA domain milestone for re-homing (if disposition is `re-home`)

**Pre-comms template:**

```markdown
## Pre-comms

Post the following message in the team's communication channel before executing Pass 2.
Teammates need to know legacy milestones are being archived.

> [Draft — edit before posting]
> Legacy milestones for <PROJECT> are being deprecated as part of the FDA retrofit completion.
> Open issues will be re-homed to the new FDA domain milestones per the review doc at
> `docs/plans/<project-slug>-deprecate-legacy.md`. If you have concerns about any specific
> issue's disposition, please comment on it in Linear within 24 hours.

## Pre-comms posted at <ISO-8601>

<!-- Replace <ISO-8601> above with the actual timestamp after posting. -->
<!-- Pass 2 will not execute until this marker is ≥24h old. -->
```

### Step 6: Exit with instructions

Surface:

> "Review doc written at `docs/plans/<project-slug>-deprecate-legacy.md` with `last_reviewed: TBD`.
>
> Next steps:
> 1. Review the disposition table. Edit dispositions as needed.
> 2. For `scoping-needed` rows, manually assign a target FDA domain.
> 3. Bump `last_reviewed` to today's ISO-8601 date.
> 4. Post the pre-comms message to the team channel.
> 5. Update the `## Pre-comms posted at` header with the actual ISO-8601 timestamp.
> 6. Wait ≥24 hours, then re-invoke `/flow:deprecate-legacy <PROJECT>`."

---

## Pass 2 — Execute

### Pre-flight checks

1. **`last_reviewed` check.** Parse the review doc front-matter. If `last_reviewed: TBD`, halt with: `"Review doc still has last_reviewed: TBD. Edit the doc, bump the date, and re-run."`

2. **Pre-comms gate.** Parse `## Pre-comms posted at <ISO-8601>` from the review doc body. The header text after `## Pre-comms posted at ` must parse as a valid ISO-8601 timestamp. Calculate the delta from now. If the marker is absent, halt with: `"Pre-comms marker not found. Post the pre-comms message and update the marker before executing."` If < 24 hours old, halt with: `"Pre-comms posted <X hours> ago. The 24h cooling period ensures teammates can raise concerns. Re-run after <timestamp>."`

3. **Disposition completeness.** Scan the disposition table for any `scoping-needed` rows. All `scoping-needed` rows MUST be resolved before Pass 2 — the operator must change the disposition to either `re-home` (with a target domain assigned) or `close-as-obsolete`. Halt with: `"<N> milestones still have 'scoping-needed' disposition. Edit the review doc to change each to 're-home' or 'close-as-obsolete' before executing."` The `scoping-needed` value is a Pass 1 placeholder only — it has no execution path in Pass 2.

### Per-milestone execution (serial)

Process each legacy milestone **serially** in the order they appear in the disposition table. For each milestone, execute the 4 sub-steps in order: re-home → close-obsolete → annotate → archive-handoff. Ordering rationale: issues must be re-homed/closed BEFORE annotation (so the annotation accurately reflects the final state); annotation BEFORE archive (so the appendix is written while the milestone is still accessible).

#### Batch confirmation gate

Before processing each milestone, present an `AskUserQuestion` gate:

> "About to process legacy milestone `<name>` (disposition: `<disposition>`, open issues: `<count>`).
>
> Sub-steps:
> <a. Re-home N open issues to <TARGET> | b. Close M issues as obsolete | c. Annotate milestone | d. Archive hand-off>
>
> Proceed?"

Options:

- **Execute this milestone** *(Recommended)* — proceed with all sub-steps.
- **Skip this milestone** — skip to the next milestone; log as skipped.
- **Pause + resume later** — exit cleanly; review doc tracks progress via completion markers.
- **Cancel remaining** — stop processing; log summary of completed + skipped + remaining milestones.

#### Sub-step a: Re-home open issues

For each open issue under the milestone with disposition `re-home`:

1. Call `mcp__plugin_workflows_linear-server__save_issue` to move the issue to the target FDA domain milestone.
2. Call `mcp__plugin_workflows_linear-server__save_comment` on the issue with a rationale comment:

   > "Moved from legacy milestone `<legacy-milestone-name>` to FDA domain milestone `<target-milestone-name>` as part of Phase 5 legacy deprecation. Original milestone carried `## FDA migration` mapping to domain `<DOMAIN>`. See `docs/plans/<project-slug>-deprecate-legacy.md` for the full disposition review."

3. Record the operation for the Completion Summary step.

For `close-as-obsolete` disposition milestones, skip this sub-step (no issues to re-home — they go to step b).

#### Sub-step b: Close-as-obsolete

For each issue under the milestone with disposition `close-as-obsolete` (or remaining issues after re-homing that the operator marked for closure):

1. Call `mcp__plugin_workflows_linear-server__save_issue` to transition the issue to `Canceled` state.
2. Call `mcp__plugin_workflows_linear-server__save_comment` with:

   > "Closed as obsolete during Phase 5 legacy deprecation. Legacy milestone `<legacy-milestone-name>` is being archived. If this issue is still relevant, re-open and move to the appropriate FDA domain milestone. See `docs/plans/<project-slug>-deprecate-legacy.md`."

3. Record the operation for the Completion Summary step.

#### Sub-step c: Annotate milestone description

Extend `flow-legacy-cross-reference`'s `## FDA migration` appendix on the legacy milestone. Locate the existing `<!-- FDA-MIGRATION-START -->` / `<!-- FDA-MIGRATION-END -->` markers and rewrite the content between them to include deprecation sub-tables:

**Extended appendix content (between markers):**

```markdown
## FDA migration

<existing content from Phase 3 annotation>

### Phase 5 deprecation summary

**Deprecated on:** <ISO-8601>
**Disposition:** <re-home | close-as-obsolete>

#### Re-homed issues

| Issue | Target Milestone | Moved At |
|---|---|---|
| BC-NNNN: <title> | <target-milestone-name> | <ISO-8601> |

#### Closed-as-obsolete issues

| Issue | Closed At |
|---|---|
| BC-NNNN: <title> | <ISO-8601> |

Generated by flow-deprecate-legacy on <ISO-8601>.
```

**Marker discipline:** use the same literal-string-search (NOT regex) for the Q14 marker pair `<!-- FDA-MIGRATION-START -->` / `<!-- FDA-MIGRATION-END -->` per the retrofit-project.md § 3.3 discipline. Never conflate with Q46's typed `FDA-WRITEBACK-` family.

**Mutation order:**

1. `mcp__plugin_workflows_linear-server__get_milestone` — pre-read for marker detection.
2. Build new description with extended appendix.
3. `mcp__plugin_workflows_linear-server__save_milestone` — write.
4. `mcp__plugin_workflows_linear-server__get_milestone` — post-write spot-check (Q13.5 Prosemirror mangling pattern).

#### Sub-step d: Archive hand-off

Linear MCP does not expose a milestone archive API. Present an `AskUserQuestion`:

> "Milestone `<name>` processing complete (re-homed: <N>, closed: <M>, annotated: yes).
>
> **Manual step required:** Archive this milestone in the Linear UI (Milestone → ··· menu → Archive).
>
> Have you archived the milestone?"

Options:

- **Yes, archived** — log as archived; continue to next milestone.
- **Skip archive for now** — log as `archive-pending`; continue.
- **Cancel remaining** — stop processing.

### Completion summary

After all milestones are processed (or processing is halted), write a completion summary to the review doc:

```markdown
## Execution summary

**Executed at:** <ISO-8601>
**Operator:** <from git config>

| Milestone | Disposition | Re-homed | Closed | Annotated | Archived |
|---|---|---|---|---|---|
| <name> | re-home | <N> | <M> | yes | yes/pending/skipped |

**Totals:** <X> milestones processed, <Y> issues re-homed, <Z> issues closed, <W> milestones archived.
```

Surface the summary to stdout as well.

---

## Failure recovery

Each milestone is independent (no dependency chains). Per-milestone failure semantics mirror Q14.5:

- **Transient** (timeout, rate-limit) → 1 retry + 2s backoff.
- **Permanent** (auth error, missing project membership, invalid state transition) → log + continue to next milestone.

End-of-run summary surfaces errored rows. Re-running the command is idempotent:

- Re-home: `save_issue` with the same milestone is a no-op if already moved.
- Close: `save_issue` with Canceled state is idempotent.
- Annotate: marker-based rewrite replaces between markers.
- Archive: operator confirms status via AskUserQuestion.

---

## Cadence linear-housekeeping integration (EVALUATED — NOT EXTENDED)

Per Q59 design decision, the cadence plugin's linear-housekeeping batch-mutation framework is **not** extended with `milestone-archive` / `milestone-rehome` mutation types. Rationale:

1. **Cross-plugin coupling.** Adding mutation types to cadence for a flow-architecture use case creates a dependency direction violation (flow-architecture → cadence). The two plugins currently have no coupling.
2. **Self-contained batch logic.** This command already has AskUserQuestion gates at each milestone boundary and can do its own preview/approve/execute cycle without cadence's framework.
3. **Low reuse likelihood.** Milestone deprecation is an infrequent lifecycle event (once per completed retrofit), not a weekly cadence operation. The overhead of extending cadence's enum + bumping cadence's version is not justified.

The batch logic is self-contained in this command. If a future use case requires milestone mutations from cadence (e.g., bulk milestone renames during weekly planning), a Q-lock amendment can add the types at that time.

---

## Review doc progress tracking

The review doc doubles as a progress tracker. During Pass 2 execution, each milestone row in the disposition table is updated with a completion marker:

- `[DONE]` — all 4 sub-steps completed successfully.
- `[SKIPPED]` — operator chose to skip at the batch gate.
- `[ERROR: <reason>]` — permanent failure logged.
- `[PENDING]` — not yet processed (default state).

On re-invocation, the command skips milestones already marked `[DONE]` or `[SKIPPED]`, processing only `[PENDING]` and `[ERROR]` rows. This makes the command resumable across sessions.

---

## See also

- `skills/flow-legacy-cross-reference/SKILL.md` — 3-tier mapping cascade reused for Pass 1 disposition mapping.
- `commands/retrofit-project.md` Phase 3 — the annotation phase that creates the `## FDA migration` appendices this command extends.
- `docs/design-rationale/fda-plugin-interview.md` Q59 — canonical design lock for this command.
- `docs/design-rationale/fda-plugin-interview.md` Q9 — additive-only retrofit lock; Q59 explicitly widens for controlled mutations.
- `docs/design-rationale/fda-plugin-interview.md` Q14 — cross-reference internals (3-tier cascade, two-pass model, marker contract).
- BriteBase precedent: `docs/plans/BC-6580-phase-5-deprecate-legacy-milestones.md` (in brite-base repo) — the manual Phase 5 execution this command automates.
