#!/usr/bin/env python3
"""Shared deterministic cycle-metrics primitives for the workflows-plugin S3 evals
(BC-12944, ADR-028 Phase-2 Batch C).

The Rule-of-Three extraction point for `/workflows:retrospective` and
`/workflows:sprint-planning`. Both commands tally a cycle's issues by Linear
state-type and compute a completion rate — that is `cycle_snapshot`, the ONLY true
overlap (2 consumers), so it lives here. The two divergent primitives also live here
(they ARE cycle metrics) but each has a single consumer today:
  - `health(rate)`   — retrospective-only (Step 4a thresholds).
  - `velocity(cycles, as_of)` — sprint-planning-only (Step 2b last-3-completed math).
Kept as separate pure fns (NOT a monolithic decide() that returns dead output for
the command that doesn't use it).

PURE + stdlib-only (CLAUDE.md § Conventions) — no MCP, no network, no I/O, and
NEVER `date.today()` (the now() equivalent): every wall-clock input is INJECTED as
`as_of` so the builders that import this run hermetically + deterministically in the
behavioral eval (the plan-campaign inject-`created_at` idiom). The cycle/issue reads
(`list_issues` / `list_cycles`) are likewise injected by the caller.
"""
from __future__ import annotations

from datetime import date

# Linear state-types (retrospective Step 2 categorization). "completed" → delivered;
# "started" → in-progress (carried over); "unstarted"/"backlog" → not started
# (carried over); "canceled" → canceled.
_DELIVERED = ("completed",)
_CARRIED = ("started", "unstarted", "backlog")
_CANCELED = ("canceled",)

# Native Linear priority (sprint-planning Step 3 backlog sort): 1=Urgent, 2=High,
# 3=Medium, 4=Low, 0=None. Urgent first, None last.
_PRIORITY_NONE_RANK = 99


def _pct(numerator: int, denominator: int) -> int:
    """Integer completion percentage; 0 when the denominator is 0 (an empty cycle is
    0%, not a divide-by-zero). round() is deterministic."""
    if denominator <= 0:
        return 0
    return round(numerator * 100 / denominator)


def _sorted_ids(issues) -> list:
    """The issue ids in a stable, input-order-independent order (sorted) — so the
    golden never churns on a fixture reorder."""
    return sorted(str(i.get("id")) for i in issues if isinstance(i, dict) and i.get("id") is not None)


def cycle_snapshot(issues) -> dict:
    """Tally a cycle's issues by state-type → the delivery snapshot (retrospective
    Step 2 / sprint-planning Step 2a). PURE given the injected `list_issues` rows.

    `total` is EVERY issue in the cycle (delivered + carried + canceled — matching
    sprint-planning's "done / total issues"); `completion_rate` = completed / total.
    The id lists are the deterministic categorization; the command renders the full
    rows (titles, assignees — untrusted external content) at runtime, NOT here.
    """
    issues = [i for i in (issues or []) if isinstance(i, dict)]
    delivered = [i for i in issues if i.get("state_type") in _DELIVERED]
    carried = [i for i in issues if i.get("state_type") in _CARRIED]
    canceled = [i for i in issues if i.get("state_type") in _CANCELED]

    total = len(issues)
    completed = len(delivered)
    return {
        "total": total,
        "completed": completed,
        "carried_over": len(carried),
        "canceled": len(canceled),
        "completion_rate": _pct(completed, total),
        "delivered_ids": _sorted_ids(delivered),
        "carried_ids": _sorted_ids(carried),
        "canceled_ids": _sorted_ids(canceled),
    }


def health(completion_rate: int) -> str:
    """Retrospective Step 4a health indicator: 80%+ → onTrack, 50–79% → atRisk,
    <50% → offTrack. The `>=` boundaries (80 → onTrack, 50 → atRisk) are load-bearing
    (a `>` regression flips 80→atRisk and 50→offTrack)."""
    if completion_rate >= 80:
        return "onTrack"
    if completion_rate >= 50:
        return "atRisk"
    return "offTrack"


def _history_end(history) -> int | None:
    """The end-of-cycle total = the FINAL entry of a Linear count-history array
    (sprint-planning Step 2b). None when the array is empty or has <2 entries — the
    command's "Insufficient data for Cycle N" skip rule (a single-entry array can't
    establish an end-of-cycle figure)."""
    if not isinstance(history, list) or len(history) < 2:
        return None
    return history[-1]


def _is_completed(cycle, as_of: date) -> bool:
    """A cycle counts for velocity iff it has a `completedAt` that is on/before
    `as_of` (a still-in-progress cycle has no completedAt and is excluded)."""
    completed_at = cycle.get("completedAt")
    if not completed_at:
        return False
    try:
        return date.fromisoformat(str(completed_at)[:10]) <= as_of
    except ValueError:
        return False


def velocity(cycles, as_of: str) -> dict:
    """Sprint-planning Step 2b team velocity over the last 3 COMPLETED cycles. PURE
    given the injected `list_cycles` array + the injected `as_of` date.

      - select cycles with a `completedAt` on/before `as_of` (skip in-progress);
      - take the 3 most recently completed (by cycle number, desc);
      - per cycle: completed = final entry of completedIssueCountHistory, total =
        final entry of issueCountHistory; if either array has <2 entries, SKIP it
        with "Insufficient data for Cycle N";
      - average issues/cycle + average completion rate over the non-skipped cycles;
      - if fewer than 3 completed cycles contribute, note the limited data.

    Returns {rows, skipped, avg_completed, avg_rate, contributing, note}. avg_* are
    None when nothing contributes (no false 0% average from an empty set).
    """
    try:
        as_of_date = date.fromisoformat(str(as_of)[:10])
    except (ValueError, TypeError):
        as_of_date = date.max  # an unparseable as_of treats every completedAt as past

    # A velocity row is reported as "Cycle N", so a cycle without an integer `number`
    # can't be one — exclude it (like an in-progress cycle). This also keeps the two
    # sort keys below total over ints, so a null/missing number never raises a
    # TypeError (the exit-2-or-clean contract holds, never a traceback).
    completed_cycles = [
        c for c in (cycles or [])
        if isinstance(c, dict) and isinstance(c.get("number"), int) and _is_completed(c, as_of_date)
    ]
    completed_cycles.sort(key=lambda c: c["number"], reverse=True)
    selected = completed_cycles[:3]

    rows = []
    skipped = []
    for c in selected:
        number = c.get("number")
        completed = _history_end(c.get("completedIssueCountHistory"))
        total = _history_end(c.get("issueCountHistory"))
        if completed is None or total is None:
            skipped.append({"cycle": number, "reason": f"Insufficient data for Cycle {number}"})
            continue
        rows.append({"cycle": number, "completed": completed, "total": total, "rate": _pct(completed, total)})

    rows.sort(key=lambda r: r["cycle"])  # present oldest→newest (N-2, N-1, N)
    contributing = len(rows)
    if contributing:
        avg_completed = round(sum(r["completed"] for r in rows) / contributing, 1)
        avg_rate = round(sum(r["rate"] for r in rows) / contributing)
    else:
        avg_completed = None
        avg_rate = None

    note = None
    if contributing < 3:
        note = "Limited data: fewer than 3 completed cycles contributed."

    return {
        "rows": rows,
        "skipped": skipped,
        "avg_completed": avg_completed,
        "avg_rate": avg_rate,
        "contributing": contributing,
        "note": note,
    }


def sort_backlog(issues, cap: int = 20) -> dict:
    """Sprint-planning Step 3 backlog projection. PURE given the merged backlog +
    unstarted `list_issues` rows. Excludes any issue already assigned to a cycle
    (`cycle` non-null), sorts by native priority (Urgent>High>Medium>Low>None,
    stable within a tier), and applies the display thresholds:
      - 50+ items → `large` (suggest /workflows:scope first);
      - more than `cap` (default 20) → show the top `cap`, `truncated`, remainder.

    Returns {ordered_ids, total, shown, truncated, remaining, large}. ordered_ids is
    the priority-sorted id list (the load-bearing ordering), capped to `cap`."""
    # Exclude already-assigned issues (cycle non-null) AND any row without a usable
    # id (mirrors cycle_snapshot._sorted_ids — a null id must never surface as the
    # literal string "None" in ordered_ids).
    rows = [
        i for i in (issues or [])
        if isinstance(i, dict) and i.get("cycle") is None and i.get("id") is not None
    ]

    def _rank(issue):
        p = issue.get("priority")
        return p if isinstance(p, int) and 1 <= p <= 4 else _PRIORITY_NONE_RANK

    ordered = sorted(rows, key=_rank)  # stable → ties keep input order
    total = len(ordered)
    shown_rows = ordered[:cap]
    return {
        "ordered_ids": [str(i.get("id")) for i in shown_rows],
        "total": total,
        "shown": len(shown_rows),
        "truncated": total > cap,
        "remaining": max(0, total - cap),
        "large": total >= 50,
    }
