#!/usr/bin/env python3
"""Deterministic sprint-planning projection builder for /workflows:sprint-planning
(BC-12944, ADR-028 Phase-2 Batch C).

The PURE, hermetic decision core the command delegates to for the quantified parts
of planning: given the INJECTED reads (`list_cycles`, the current cycle's
`list_issues`, the backlog+unstarted `list_issues`) + the injected `as_of`, it
computes — with NO MCP call and NO Linear write — the current-cycle snapshot +
days-elapsed (Step 2a), the last-3-completed-cycles velocity (Step 2b), and the
priority-sorted backlog projection (Step 3).

What's OUT of scope (over-claim guard, ADR-028 D2): the Step-4 LLM sprint suggestion
+ rationale, and the mutating Step-5 `save_issue` cycle assignment. The backlog's
ordered ids are the deterministic priority sort; the command renders the full rows
at runtime, NOT here.

cycle_snapshot + velocity + sort_backlog are imported from cycle_metrics.py (the
shared S3 module — cycle_snapshot has 2 consumers; velocity is sprint-only). now()
is defeated by the injected `as_of` (the plan-campaign inject-`created_at` idiom):
days-elapsed and the completed-cycle selection are computed against `as_of`, never
`date.today()`.

emit artifact (`--scenarios <fixture> --out-dir <dir>`):
    sprint-plan-emit.json = { schema_version, command, scenarios: [ {id, **decision} ] }

Stdlib-only; same command+helper pattern as build_retro_snapshot.py.
Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cycle_metrics import cycle_snapshot, sort_backlog, velocity  # noqa: E402  (BC-12944 shared)

SCHEMA_VERSION = 1
COMMAND = "/workflows:sprint-planning"

MODE_PLAN = "plan"
MODE_PRIORITIZATION_ONLY = "prioritization-only"


def _days_between(start: str | None, end: str | None) -> int | None:
    """Whole days from `start` to `end` (ISO dates); None if either is missing or
    unparseable. Used for days-elapsed (start → as_of) + total days (start → end)."""
    if not start or not end:
        return None
    try:
        d0 = date.fromisoformat(str(start)[:10])
        d1 = date.fromisoformat(str(end)[:10])
    except ValueError:
        return None
    return (d1 - d0).days


def decide(inputs: dict, linear_state: dict | None = None) -> dict:
    """PURE decision: (as_of + current cycle meta, injected reads) -> a plan row.

    `inputs.as_of` = the injected "today" (defeats now()); `inputs.current_cycle` =
    the active cycle meta {number, startsAt, endsAt} or null (→ prioritization-only
    mode when no cycle exists, Step 1). `linear_state` injects {cycles, current_issues,
    backlog_issues}.
    """
    linear_state = linear_state or {}
    as_of = inputs.get("as_of")
    current_cycle = inputs.get("current_cycle")

    vel = velocity(linear_state.get("cycles"), as_of)
    backlog = sort_backlog(linear_state.get("backlog_issues"))

    if not isinstance(current_cycle, dict) or current_cycle.get("number") is None:
        # No active cycle → prioritization-only mode (Step 1): skip the current
        # snapshot + days; still surface velocity + the ordered backlog.
        return {
            "error": None,
            "mode": MODE_PRIORITIZATION_ONLY,
            "current_cycle_number": None,
            "current_snapshot": None,
            "days_elapsed": None,
            "total_days": None,
            "velocity": vel,
            "backlog": backlog,
        }

    snap = cycle_snapshot(linear_state.get("current_issues"))
    return {
        "error": None,
        "mode": MODE_PLAN,
        "current_cycle_number": current_cycle.get("number"),
        "current_snapshot": {
            "total": snap["total"],
            "completed": snap["completed"],
            "carried_over": snap["carried_over"],
            "canceled": snap["canceled"],
            "completion_rate": snap["completion_rate"],
        },
        "days_elapsed": _days_between(current_cycle.get("startsAt"), as_of),
        "total_days": _days_between(current_cycle.get("startsAt"), current_cycle.get("endsAt")),
        "velocity": vel,
        "backlog": backlog,
    }


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any reject row."""


_INPUT_KEYS = ("as_of", "current_cycle")


def _scenario_inputs(scenario: dict) -> dict:
    return {k: scenario[k] for k in _INPUT_KEYS if k in scenario}


def run_scenarios(scenarios: list) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        decision = decide(_scenario_inputs(sc), sc.get("linear_state"))
        rows.append({"id": sc.get("id", f"scenario-{i}"), **decision})
    return {"schema_version": SCHEMA_VERSION, "command": COMMAND, "scenarios": rows}


def _load_scenarios(path: Path) -> list:
    if not path.exists():
        raise BuildError(f"fixture not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise BuildError(f"fixture is not valid JSON: {exc}") from exc
    scenarios = data.get("scenarios") if isinstance(data, dict) else data
    if not isinstance(scenarios, list):
        raise BuildError("fixture must be a list of scenarios or {'scenarios': [...]}")
    return scenarios


# ── CLI ───────────────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="build_sprint_plan.py",
        description="Deterministic /workflows:sprint-planning projection builder (BC-12944).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write sprint-plan-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one plan row to stdout")
    args = ap.parse_args(argv)

    try:
        if args.decide is not None:
            try:
                raw = sys.stdin.read() if args.decide == "-" else Path(args.decide).read_text(encoding="utf-8")
            except OSError as exc:
                raise BuildError(f"--decide input file unreadable: {exc}") from exc
            try:
                sc = json.loads(raw)
            except json.JSONDecodeError as exc:
                raise BuildError(f"--decide input is not valid JSON: {exc}") from exc
            if not isinstance(sc, dict):
                raise BuildError("--decide input must be a single scenario object")
            row = {"id": sc.get("id", "runtime"), **decide(_scenario_inputs(sc), sc.get("linear_state"))}
            print(json.dumps(row, ensure_ascii=False))
            return 0

        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios)
            (out_dir / "sprint-plan-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
