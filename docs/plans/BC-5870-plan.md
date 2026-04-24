# BC-5870 Plan — Phase 1 quality-flags rendering

**Issue:** [BC-5870](https://linear.app/brite-nites/issue/BC-5870/cadence-phase-1-quality-flags-rendering-aggregates-silently-codify)
**Parent:** BC-5763 (W17 dogfood)
**Decision:** Option A — threshold aggregation at 10 flags
**Branch:** `holden/bc-5870-phase-1-flags-rendering`
**Worktree:** `.claude/worktrees/bc-5870/`
**Pre-edit baseline:** `./scripts/validate.sh` → 0 errors, 16 warnings

## Context

W17 Phase 1 rendered 75 quality flags as a single aggregated summary line while the literal spec in `plugins/cadence/commands/weekly.md § 1.6 item 4` said "one line per flag." The aggregation was pragmatic (75 literal lines would blow the 300-word target) but undocumented. BC-5870 codifies a deterministic rule; Option A was picked because (a) W17 output already matches A's shape, (b) A is consistent with the BC-5869 "render at decision-relevant granularity" pattern, and (c) A keeps scale + density + category signals visible at Gate #1 without introducing a second interactive prompt.

## The rule (Option A)

`plugins/cadence/commands/weekly.md § 1.6 item 4` becomes:

> 5. **Quality flags** subsection — only if any flagged:
>    - **≤10 flags total**: one line per flag — `<issue_id> — <check>: <message>`.
>    - **>10 flags total**: one aggregation line —
>      `<N> flags total; highest density in <proj-1> (<n1>), <proj-2> (<n2>), <proj-3> (<n3>); by check: <check-1> (<m1>), <check-2> (<m2>), <check-3> (<m3>). Full records in audit.json.`
>    - Top-3 projects are ranked by absolute flag count, ties broken alphabetically by project name. Top-3 check types use the same rule over check name. If fewer than 3 distinct projects or check types, emit the actual count (e.g., 2 entries if only 2 projects have flags). `audit.json` always retains the full per-flag record regardless of which render path fires (§ 1.5 persistence is unchanged).

## Tasks

### Task 1 — Amend § 1.6 item 4 in `weekly.md`

- **File:** `plugins/cadence/commands/weekly.md:283`
- **Edit:** Replace the current one-line `5. **Quality flags**...` bullet with the block above (indented under the numbered list).
- **Preserve:** Items 1–4, item 5's Audit-gaps subsection (currently item 4 in the text — renumber carefully), Scale-target paragraph (lines 285–287).
- **Determinism check:** Rule must be reproducible across runs — threshold + top-K + alphabetical ties is a total order over audit.json content.
- **Verify:** `rg -n "Quality flags" plugins/cadence/commands/weekly.md` returns the amended text; `rg -n "^\d+\. \*\*" plugins/cadence/commands/weekly.md | grep -A0 "1\.6"` confirms item numbering 1–5 intact.

### Task 2 — Append gotcha bullet to `plugins/cadence/CLAUDE.md`

- **File:** `plugins/cadence/CLAUDE.md`, under `## Gotchas`, after the BC-5869 synthesis-scale bullet.
- **Bullet:** *"**Phase 1 quality-flags render has a 10-flag threshold, not a word cap.** `commands/weekly.md § 1.6 item 4` renders one line per flag when `≤10 flagged total`; at `>10` it renders a single aggregation line (top-3 projects by density + top-3 check types, alphabetical tie-break). `audit.json` always holds the full per-flag record regardless — the render is a display decision, not a data-loss decision. Origin: BC-5870 (W17 dogfood surfaced 75 flags silently aggregated against the literal per-flag spec)."*
- **Verify:** `rg -n "10-flag threshold" plugins/cadence/CLAUDE.md` returns the new line.

### Task 3 — Seeded verification (large-N + small-N)

Following the BC-5869 precedent: no CI fixture; verification lives in the commit body as reproducible walkthroughs.

- **Large-N case:** Read `~/Projects/work/brite-nites/weekly-planning/w17-2026-04-20/audit.json` (sibling repo per cadence CLAUDE.md gotcha). Count `flags[]` entries across all `audit_cards[]`. Expected: >10 (W17 had ~75). Group by project → get top-3 by count, alphabetical tie-break. Group by check type → get top-3 by count, alphabetical tie-break. Manually produce the aggregation line per the rule. Paste into commit body.
- **Small-N case:** Synthesize an inline 3-flag audit.json fragment in the commit body (fabricated issue IDs + check + message). Manually produce the three per-flag lines. Confirms the ≤10-path still fires.
- **Verify:** Both renders present in commit body; aggregation line obeys top-K + alphabetical tie-break rule exactly.

### Task 4 — Version bump

- **File 1:** `plugins/cadence/.claude-plugin/plugin.json` → patch-bump (read current, +1 patch).
- **File 2:** `.claude-plugin/marketplace.json` → matching `cadence` entry patch-bump to the same version.
- **Why:** CLAUDE.md gotcha + BC-6000 precedent — clients' plugin cache is keyed by plugin version; edits to `plugins/cadence/commands/**` that ship without a version bump sit uncollected in cache across `/workflows:ship` sessions.
- **Verify:** Both version strings match; `git diff` shows exactly one patch digit change per file.

### Task 5 — Run validate.sh

- **Command:** `./scripts/validate.sh` inside the worktree.
- **Expected:** `0 errors, 16 warning(s)` — identical to pre-edit baseline.
- **If regression:** halt; investigate before ship. Gate-lint (`lint_cadence_gates.py`) touches `commands/weekly.md` — watch for false-positive italic-quote hits in the new aggregation-line text (BC-5951 tracks the FP-tightening follow-up).

## Acceptance criteria mapping

| AC | Satisfied by |
|---|---|
| #1 Decision codified between A/B in § 1.6 item 4 | Task 1 |
| #2 Deterministic given flag count, reproducible across runs | Task 1 (threshold + top-K + alphabetical) |
| #3 Seeded >10-flag test confirms aggregation path fires | Task 3 large-N |
| #3 Seeded ≤10-flag test confirms per-flag path fires | Task 3 small-N |
| #4 audit.json always has full per-flag record | Already guaranteed by § 1.5 persistence — spec notes unchanged, no code change needed |

## Risks

- **"One-line categorical breakdown" field length.** The 7 issue-quality-gate check names include long strings like "done-with-evidence" and "state/cycle alignment". At top-3 + counts, the aggregation line stays under ~200 chars — well inside the 300-word synthesis scale target. Mitigation: none needed.
- **Alphabetical tie-break may produce uninformative top-3 in small-count regimes.** If 5 projects each have 1 flag, the top-3 is alphabetical — technically true, less informative than a random sample. Acceptable: the aggregation line stays deterministic, and the `audit.json` full-list covers the edge case.
- **Gate-lint false positive on new aggregation-line text.** The new text uses backticks (code fences for the rendered line) — unlikely to trigger italic-quote FPs. Task 5 catches this if it happens.

## Rollback

Single-commit PR. Revert restores BC-5869 baseline. Version bump reverts with it; no migration.

## Out of scope

- Option C (always-aggregate at all N, no threshold) — deferred; BC-5870 AC is binary between A and B per issue body.
- BC-5871 scope-reconciliation fields — sibling follow-up, same § 1.6 surface; will use BC-5870's threshold-aggregation pattern once landed.
- `lint_cadence_gates.py` FP tightening — tracked in BC-5951 (Backlog).

## Seeded verification (executed 2026-04-24)

### Large-N path — synthetic 12-flag fragment

```json
{
  "audit_cards": [
    {"project_name": "Brite Sites", "quality_gate_flags": [
      {"issue_id": "BC-1", "check": "missing-AC", "message": "..."},
      {"issue_id": "BC-2", "check": "missing-AC", "message": "..."},
      {"issue_id": "BC-3", "check": "missing-AC", "message": "..."},
      {"issue_id": "BC-4", "check": "missing-AC", "message": "..."},
      {"issue_id": "BC-5", "check": "missing-AC", "message": "..."},
      {"issue_id": "BC-6", "check": "missing-assignee", "message": "..."}
    ]},
    {"project_name": "Brite Handbook", "quality_gate_flags": [
      {"issue_id": "BC-7", "check": "missing-AC", "message": "..."},
      {"issue_id": "BC-8", "check": "done-with-evidence", "message": "..."},
      {"issue_id": "BC-9", "check": "done-with-evidence", "message": "..."}
    ]},
    {"project_name": "Brite GTM", "quality_gate_flags": [
      {"issue_id": "BC-10", "check": "missing-AC", "message": "..."},
      {"issue_id": "BC-11", "check": "missing-assignee", "message": "..."},
      {"issue_id": "BC-12", "check": "state-cycle-alignment", "message": "..."}
    ]}
  ]
}
```

N=12 (>10) → aggregation path fires. Per-project sort: Brite Sites (6), Brite GTM (3), Brite Handbook (3) — tie resolved alphabetically (Brite GTM before Brite Handbook). Per-check sort: missing-AC (7), done-with-evidence (2), missing-assignee (2) — tie resolved alphabetically (done-with-evidence before missing-assignee).

**Rendered aggregation line:**

> `12 flags total; highest density in Brite Sites (6), Brite GTM (3), Brite Handbook (3); by check: missing-AC (7), done-with-evidence (2), missing-assignee (2). Full records in audit.json.`

### Small-N path — synthetic 3-flag fragment

```json
{
  "audit_cards": [
    {"project_name": "Brite Sites", "quality_gate_flags": [
      {"issue_id": "BC-5100", "check": "missing-AC", "message": "Issue has no acceptance criteria"},
      {"issue_id": "BC-5101", "check": "missing-assignee", "message": "No assignee set"}
    ]},
    {"project_name": "Brite Supply Website", "quality_gate_flags": [
      {"issue_id": "BC-5102", "check": "missing-AC", "message": "Issue has no acceptance criteria"}
    ]}
  ]
}
```

N=3 (≤10) → per-flag path fires.

**Rendered lines:**

```
BC-5100 — missing-AC: Issue has no acceptance criteria
BC-5101 — missing-assignee: No assignee set
BC-5102 — missing-AC: Issue has no acceptance criteria
```

### W17 supporting evidence

Real W17 `audit.json` at `~/Projects/work/brite-nites/weekly-planning/w17-2026-04-20/audit.json` → 100 flags total across 10 projects. Per-project aggregation (computed deterministically): Asset Studio (30), Brite Base (15), Brite GTM (15). The per-check ranking was **not reachable from the W17 file** because the project-audit subagent persisted `quality_gate_flags_count` (int) only, with `quality_gate_flags: []` empty — a spec departure from `agents/project-audit.md:42` which declares the full `{issue_id, check, message}` list. This is a separate bug worth a sibling issue (does not block BC-5870; the § 1.6 render rule is correct, and the § 1.5 persistence guarantee stands per spec — the violation is agent-side, not spec-side). Filed as a follow-up note in commit body.

## Post-merge

- File sibling issue: project-audit agent persists `quality_gate_flags_count` only, drops the per-flag list (spec says full list required). Surfaces during BC-5870 seeded verification against W17.
- Precedent trace for compound learnings (at ship time).
- Update MEMORY.md session entry.
- Next actionable: BC-5871 (scope reconciliation, same § 1.6 surface, tightest next-batch partner).
