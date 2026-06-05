---
description: Per-domain Flow-Driven Architecture retrospective utility — scope-bounded reflection on a completed domain milestone (Q44 lock; gstack-inspired, NOT time-windowed)
---

# /flow:retro

Per-domain retrospective utility. Reflects on a single **completed domain milestone** — what worked, where to level up, what to carry into the next domain. Scope is the milestone, not a date range or commit window: this is the FDA-shaped substitute for time-windowed engineering retros and is **NOT** a velocity, throughput, or commit-mining tool.

The command is **gstack-inspired, not gstack-cribbed** (Q44 lock; partial inspirational transfer only per parking-lot #39 verification 2026-05-07). Five section headers carry over verbatim from gstack's `retro/SKILL.md`; three more are FDA-specific. The metric machinery (tweet-sized one-liner, session patterns, velocity dashboard, code-quality dashboard + test health, plan-completion ledger from `/ship` JSONL logs, weekly digest / team breakdown) is **deliberately not transferred** and must not be re-introduced — re-litigation already resolved at Q44 lock time.

> **Scope category:** utility (single-purpose, no user-confirmation gates between internal steps) per plugin CLAUDE.md § Surface map. Distinct from `/flow:office-hours` (project-scoped intent interview) and the orchestrators (`/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`) which own breadcrumbs and fire multi-phase gates.

> **DO NOT re-derive** the section structure (8 sections — 5 cribbed verbatim from gstack + 3 FDA-specific), the writeback call signature (Q46 sub-decision 7 single-write contract), or the positional-arg fallback chain. All three are locked at Q44 (memory:1297 + sub-decisions at memory:1300 / 1322-1340 / 1346-1361) with a refinement audit trail at memory:1363. Re-read those before drafting any change to this file.

## Invocation

`/flow:retro [<DOMAIN>]`

The positional `<DOMAIN>` argument is **optional**. Resolution chain per Q44 sub-decision 1 (memory:1300):

1. **Explicit arg present** — `/flow:retro <DOMAIN>` (e.g., `/flow:retro EVENTS`). Use the named domain directly; verify its milestone is in `state.type=completed` before proceeding. If the named domain's milestone is not yet completed, halt with an error directing the user to `/flow:ship` first.

2. **No arg — most-recently-completed domain detection.** Query the Linear MCP for milestones in `state.type=completed` ordered by transition timestamp (most recent first). The `most-recently-completed` milestone wins; capture its `<DOMAIN>` slug as the retro target.

3. **No arg — ambiguous (multiple domains closed back-to-back).** If step 2 finds **two or more** completed milestones whose `completedAt` values fall within the same UTC day, OR straddle a UTC-midnight boundary with `completedAt` deltas < 1 hour, fire `AskUserQuestion` to let the user select **exactly one** domain to retro this run. Remaining candidates are surfaced as stdout recommendations in step 6 (re-invoke `/flow:retro <NEXT_DOMAIN>` per deferred candidate). Do not silently pick the first row — back-to-back closes typically signal a batch ship that the user will want to retro deliberately, one at a time.

### Positional-arg validation (defense-in-depth)

Before any downstream filesystem write or Linear MCP call, validate the positional `<DOMAIN>` at the trust boundary (mirrors `add-sub-flow.md` § Positional-arg validation; BC-6963 `87d5886` slug-halt precedent):

- `<DOMAIN>` must match `^[A-Z][A-Z0-9_]*$` (uppercase Linear-team-style slug; admits `EVENTS`, `BC`, `AUTH_FLOWS`).
- Halt-on-fail with a clear error: `"Invalid positional arg <value>: expected <DOMAIN> form ^[A-Z][A-Z0-9_]*$"`. Path-traversal and command-injection slugs are rejected here rather than relying on downstream consumers.
- The captured `<DOMAIN>` is treated as **opaque content** by the orchestrator — never `echo`-ed, `eval`-ed, backtick-spliced, or shell-interpolated. Filesystem-path composition (step 3) uses `python3 -c 'import sys; print(sys.argv[1].lower())'` or equivalent stdlib lowercase to derive the lowercase `<domain>` for the path; **never** use bash 4's `${var,,}` (macOS bash 3.2 fails per Q32 + MEMORY.md gotcha).
- Linear-derived strings (milestone descriptions, parent-issue bodies, L3 review summary blocks pulled in step 2) are also opaque data. They reach the LLM context for retro authoring but never enter a `bash -c`, `eval`, or unquoted `$(...)` expression. The MCP call is the trust boundary; values stay in LLM context, never inside a shell pipeline.

## How it runs

Single-phase utility — there are no user-confirmation gates between internal steps (utility category, not orchestrator). Internal step ordering:

1. **Resolve target.** Apply the invocation resolution chain above. Capture `<DOMAIN>` + `<MILESTONE_ID>` + `<COMPLETED_AT>` (ISO-8601).
2. **Gather inputs in parallel.** Two independent fetch streams:
   - **Filesystem** — inventory at `docs/product/master-flow-inventory.md` to enumerate the domain's sub-flows + each sub-flow's story doc at `docs/product/flows/<domain>/<flow-id>.md`.
   - **Linear (workflows MCP)** — domain milestone description (1 call) + per-sub-flow parent issues fanned out in parallel (one `get_issue` per sub-flow; L3 review summaries live inline in the parent body's `## L3 review summary` section per Q23 mod 2, so no extra round-trip). Do not serialize the parent-issue reads.

   Code-evidence collection per `skills/_shared/code-evidence-collector.md` patterns runs against the gathered material — e.g., for the `## What worked` and `## Where to level up` sections.
3. **Draft the retro doc.** Render the 8-section template (see § Retro document section structure below) into `docs/retros/<domain>-<YYYY-MM-DD>.md` (filesystem canonical). The `<domain>` token in the path is the **lowercase** transform of the captured uppercase `<DOMAIN>` slug — derive via the stdlib lowercase recipe in § Positional-arg validation above. Use atomic-rename write — never overwrite-in-place. `<YYYY-MM-DD>` is the date the retro is run, not the milestone `completedAt` (multiple retros over the lifetime of a domain are allowed; the date stamps the retrospection event, not the work).
4. **Compose executive summary.** Pull the most load-bearing 3-5 sentences from `## Summary`, `## What worked`, and `## Where to level up`. The executive summary is what surfaces in the Linear comment body; the full retro is the filesystem doc.
5. **Write to Linear via Q46.** Single call to `linear_writeback` per Q44 sub-decision 7 (see § Q46 writeback call signature below). The writeback layer handles idempotency markers, signature dedup, and clobber-with-warning per `skills/_shared/linear-writeback-pattern.md`.
6. **Report to stdout.** Print the filesystem path + Linear comment URL. If step 1 disambiguated multiple back-to-back completed milestones, recommend a follow-up `/flow:retro <NEXT_DOMAIN>` for the deferred candidate(s).

## Output targets

Two surfaces — filesystem-canonical for the full doc, Linear-comment for the executive summary:

- **Filesystem (canonical):** `docs/retros/<domain>-<YYYY-MM-DD>.md`. The full 8-section retro. Versioned in git; reviewable via `git diff`. This is the source of truth; the Linear comment is the discoverable mirror.
- **Linear (executive summary):** comment on the domain's completed milestone via the Q46 `retro-summary` writeback marker. The comment body holds the executive summary + a backlink to the filesystem path. Re-runs against the same milestone update the existing comment via signature-line dedup (no duplicate retro comments accumulate on the milestone).

The kebab-case lowercase `retro-summary` type is registered in the Q46 type registry at `plugins/flow-architecture/skills/_shared/linear-writeback-pattern.md` § v1 type registry (cross-cutting requirement #5 enforcement: unknown writeback types are rejected at the Q46 boundary).

## Q46 writeback call signature

Verbatim from Q44 sub-decision 7 (memory:1346-1361). The single-write call signature is **locked** — do not split into multiple writes, do not change field names, do not add fields without a Q44 amendment + audit trail.

```
linear_writeback({
  issue_id: <milestone_id>,
  type: 'retro-summary',
  surface: 'comment',
  content: <executive-summary + link to docs/retros/<domain>-<YYYY-MM-DD>.md>,
  signature: '_Generated by /flow:retro for <DOMAIN> milestone on <ISO-8601>_',
  breadcrumb_path: <breadcrumb_path>,
  warn_on_clobber: true
})
```

Field notes:

- `issue_id` — the **milestone** ID (not a parent-issue ID; retros are domain-scoped). Q46's `surface: 'comment'` writes a comment on that milestone.
- `type: 'retro-summary'` — lowercase kebab per CC5; the Q46 type registry enforces this literal value. Casing is load-bearing.
- `signature` — interpolates `<DOMAIN>` (uppercase slug) + `<ISO-8601>` (UTC timestamp of the retro run). The signature line is the dedup key: re-runs find the existing comment via signature match and update in place.
- `breadcrumb_path` — utilities do NOT own the orchestrator breadcrumb at `docs/plans/.flow-phase-state.json` (Q31.6 single-orchestrator concurrency rule + plugin CLAUDE.md § Boundaries). Pass a utility-scoped ephemeral path co-located with the retro doc: `docs/retros/.<domain>-<YYYY-MM-DD>.retro-state.json` (leading-dot per the Q31.4 hidden-state convention; one such state file per retro run; gitignored locally — add a per-repo entry if not already covered). Q46's within-run throttle (`linear_writeback_state.written_pairs[]`) writes its state slot there. Since `/flow:retro` issues exactly one writeback per invocation, the throttle is effectively a no-op for this caller; the path is still required by the Q46 interface and serves as an audit-trail record of which milestone received which retro write.
- `warn_on_clobber: true` — clobber-with-warning is the default; explicit here per Q46's interface.

The HTML-comment idempotency markers `<!-- FDA-WRITEBACK-retro-summary-START -->` / `<!-- FDA-WRITEBACK-retro-summary-END -->` bracket the comment content automatically; the writeback layer owns marker placement.

## Retro document section structure

Eight `##` sections in canonical order. The first five are cribbed verbatim from gstack's `retro/SKILL.md` (Q44 sub-decision 6, memory:1322-1332); the last three are FDA-specific additions covering the multi-discipline structure that gstack's solo-engineer assumption doesn't capture.

```
## Summary
## Trends vs Prior Retros
## Focus & Highlights
## What worked
## Where to level up
## Per-discipline highlights
## Cross-references
## Open questions
```

Section authoring notes:

- `## Summary` — 3-5 sentence executive paragraph. Names the domain, the milestone, the timeframe spanned by the sub-flows, and the headline outcome. This is what surfaces in the Linear comment.
- `## Trends vs Prior Retros` — diff against the immediately-prior retro (always) and optionally up to two earlier retros for trajectory context (3 retros total max). Enumerate prior retros via `ls docs/retros/<domain>-*.md` filtered post-glob to filenames matching `^<domain>-\d{4}-\d{2}-\d{2}\.md$` (regex anchoring prevents over-matching for sibling slugs sharing a prefix like `BC` vs `BC_AUTH` — the `.md` suffix + 10-char ISO date enforces structure); sort descending by date; keep only the top 3. If this is the first retro for the domain, write "No prior retros for `<DOMAIN>` — this is the baseline."
- `## Focus & Highlights` — the 2-3 things this milestone explicitly optimized for. Sourced from the milestone description + L1 office-hours intent if applicable.
- `## What worked` — discipline-agnostic positive callouts: patterns to repeat, decisions that paid off, integrations that landed cleanly. Cite specific Linear issue IDs + filesystem paths where applicable.
- `## Where to level up` — the symmetric counterpart: patterns to retire, decisions to revisit, friction points that recurred. Phrase as forward-looking adjustments, not retrospective blame.
- `## Per-discipline highlights` — five sub-headings, one per FDA discipline (Story / Eng / Design / QA / Docs). Each pulls 1-3 callouts from the discipline's children + L3 review summaries. This is the substantive structural addition over gstack (which assumes a single engineer perspective).
- `## Cross-references` — links out: prior retros for adjacent domains, related CDRs, parking-lot promotions surfaced by this milestone, follow-up issues created during retro authoring.
- `## Open questions` — items the retro deliberately leaves unanswered for follow-up: design questions deferred, ADR-worthy decisions noticed mid-flight, dependency-on-other-team callouts. Each entry links to a tracking surface (Linear issue, parking lot, or a TODO with an owner).

## Idempotency

Re-running `/flow:retro <DOMAIN>` on the **same date** overwrites `docs/retros/<domain>-<YYYY-MM-DD>.md` atomically (no append; the date stamps the run, and a same-date re-run is treated as a refinement). Re-running on a **different date** creates a new file at `docs/retros/<domain>-<YYYY-MM-DD>.md` — older retros remain in place as the audit trail; § Trends vs Prior Retros references them.

The Linear comment side dedup uses the `signature` line (`_Generated by /flow:retro for <DOMAIN> milestone on <ISO-8601>_`) and is **same-date scoped**: same-domain re-runs on the same ISO-8601 day match the existing signature and update the comment in place; cross-date re-runs produce a **new** signature (the `<ISO-8601>` token differs) and Q46 creates a **new** comment. This matches the filesystem side: each retro run produces a new doc dated for that run, mirrored by a new comment dated for that run. Older comments remain on the milestone as the Linear-side audit trail, parallel to the older filesystem retros — § Trends vs Prior Retros walks back through both.

## Failure semantics

- **Linear MCP unavailable** during step 1 resolution → halt with the user-actionable error from the MCP transport; do not fall back to inferring domain completion from filesystem.
- **No completed milestones in the project** → halt with: "No completed domain milestones found in `<LINEAR_PROJECT_NAME>`. Run `/flow:ship` against a domain first." This is the most common first-time-user error. `<LINEAR_PROJECT_NAME>` is read from `.flow/config.json` (the same per-repo config `flow-preflight` Section 6 writes at first-run bootstrap).
- **Atomic-rename filesystem write fails** (disk full, permissions) → halt before the Q46 writeback fires; do not leave a Linear comment pointing at a doc that doesn't exist on disk.
- **Q46 writeback fails** after the filesystem doc has landed → surface the writeback error to stdout with the filesystem path; the user can re-run to retry the Linear write. The filesystem doc is the source of truth; the Linear write is a discoverable mirror, not a transactional partner.

## Out of scope

Locked at Q44; do not re-introduce without an amendment:

- **Time-windowed retros** (commit-range, sprint-range, week-range). gstack's mode does this; FDA's retros are milestone-scoped. The right surface for time-windowed reflection is `/flow:office-hours` (project-scoped, periodic).
- **Per-org or cross-domain retros** (parking lots #41 + #44, v1.1 candidates).
- **Body-surface retro** — Q44 sub-decision 7 locks `surface: 'comment'`, not `surface: 'body'` (parking lot #42, v1.1 candidate).
- **Team retro facilitation** — solo `/flow:retro` against a milestone surfaces structured signal; live team retro facilitation is a v1.1 candidate (parking lot #44).

## See also

- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:1297` — Q44 lock (canonical source). Sub-decisions at memory:1300 (positional fallback), memory:1322-1340 (8-section structure + 7-pattern non-transfer audit trail), memory:1346-1361 (Q46 call signature). Refinement audit trail at memory:1363.
- `plugins/flow-architecture/skills/_shared/linear-writeback-pattern.md` — Q46 writeback layer (BC-6955 shipped). Type registry, idempotency markers, double-layer safety, batching convention.
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-architecture-overview.md` § 3c — command surface map (where this utility sits relative to orchestrators + cloned commands).
- `plugins/flow-architecture/commands/add-sub-flow.md` + `start-project.md` + `retrofit-project.md` + `add-domain.md` — full set of FDA orchestrators. This command's lighter utility shape (single phase, no breadcrumb, no gates) intentionally diverges from those.
- Handbook CDR-023 — Flow-Driven Architecture (the policy this command operationalizes through retrospection).
- Handbook `how-we-work/operating-standards/flow-driven-architecture.md` § Retrospection cadence (Q34 lock).
- gstack `retro/SKILL.md` (`repos/garrytan/gstack`) — inspirational source for the first 5 section headers; re-verify via `gh api` per parking-lot #39 discipline before any future amendment that touches the section-structure lock.
- Parking lots #41 / #42 / #44 — v1.1 candidates for cross-domain, body-surface, and team-facilitation retros.
