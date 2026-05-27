# GTM v1.1 Tracker Log

**Source-of-truth**: Linear milestone *GTM Campaign Orchestration v1.1* (`f1e106b8-5882-462f-ab4e-17de5684f3ad`).
**Purpose**: Persistent sweep log written by the GTM v1.1 tracker session after each sweep. Next tracker session reads this during session-start before re-deriving from Linear — faster bootstrap; Linear remains authoritative if this diverges.
**Target date**: 2026-07-15.
**Discipline**: After each sweep, append a new dated section with the BC status table + a brief delta summary. Do not edit prior sections — they're the audit trail.

## How to use this file

- **Reading (next tracker)**: Bottom-most table = most recent known state. Verify any "completed" rows via `get_issue` before trusting; older rows are historical.
- **Writing (current tracker)**: After each sweep, append a new `## YYYY-MM-DD HHMMz — Sweep N` section with a fresh status table + 2-4 sentence delta summary.
- **Cross-repo PRs**: BC-11860 + BC-11861 ship via PRs to `brite-nites/handbook`. When validating, also run `gh pr view --repo brite-nites/handbook <PR#>`. PR numbers live in the Linear issue's `attachments` field.

## Status legend

- **Backlog** — not yet started; matches Linear `status: Backlog`
- **In Progress** — executor session active; matches Linear `status: In Progress`
- **PR Open** — executor opened PR; not yet merged
- **Merged** — PR merged to main; Linear may still say `In Progress` if magic-ID auto-close didn't fire
- **Done** — Linear `status: Done` AND tracker has validated per the class-level + BC-specific criteria
- **Blocked** — Linear or repo state blocks progress; flag in delta summary

## 2026-05-27 1935z — Sweep 1 (session bootstrap)

Tracker session started. 15 BCs fetched via individual `get_issue` (list query truncated at 9; spot-checks done on all 15). Repo at `d2aac87e` (origin/main). Training worktree at detached `1423a65f` (one behind). Bare-repo primary.

| BC | Title | Linear | Validation | Last PR/commit |
|---|---|---|---|---|
| BC-11851 | A1 Master inventory | Backlog | — | — |
| BC-11852 | A2 Manifest schema v2 | Backlog | — | — |
| BC-11853 | A3 Canonicals bulk backfill (26 verticals) | Backlog | — | — |
| BC-11854 | A4 flagship-retail vs shopping-centers taxonomy | Backlog | — | — |
| BC-11849 | Build /marketing:import-campaign | Backlog | — | — |
| BC-11855 | A5 σ3 soft-fail auto-files Linear reminder | Backlog | — | — |
| BC-11856 | A6 Build /marketing:audit-campaigns | Backlog | — | — |
| BC-11857 | A7 plan-campaign atomicity hardening | Backlog | — | — |
| BC-11850 | Reconcile ~20-50 GTM campaigns | Backlog | — | — |
| BC-11847 | Reconcile cohort-1 dogfood SF Campaign | Backlog | — | — |
| BC-11858 | A8 M07 in-flight scaffolds resolve | Backlog | — | — |
| BC-11859 | A9 MSPA learnings.md backfill | Backlog | — | — |
| BC-11845 | Fix EB workspace routing | Backlog | — | — |
| BC-11860 | A10 §3.6 derivative doc sweep | Backlog | — | — |
| BC-11861 | A11 Periodic reconciliation cadence | Backlog | — | — |

**Delta vs prior**: N/A — first sweep.
**Unblocked & ready**: BC-11851, BC-11854 (user decision), BC-11845, BC-11855, BC-11857, BC-11847.
**In flight**: none.
**Risks**: none observed.
**Open user actions**: A4 decision (Merge / Split / Hierarchy) pending — will surface via `AskUserQuestion` when BC-11854 is up.
