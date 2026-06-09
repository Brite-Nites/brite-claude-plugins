#!/usr/bin/env python3
"""Deterministic retrospective delivery-snapshot builder for /workflows:retrospective
(BC-12944, ADR-028 Phase-2 Batch C).

The PURE, hermetic decision core the command delegates to for the quantified parts
of a retro: given the target cycle's INJECTED issues (`list_issues({cycle})`) + the
cycle meta, it computes — with NO MCP call and NO Linear write — the delivery
snapshot (Step 2: the by-state-type tally + completion rate + the delivered /
carried-over / canceled categorization) and the Step-4a health indicator.

What's OUT of scope (over-claim guard, ADR-028 D2): the Step-3 retro discussion
(went-well / needs-improvement / action-items synthesis — LLM), the mid-sprint
"adjust thresholds based on days elapsed" health (unquantified prose), and the
mutating `save_status_update` + follow-up `save_issue` (Steps 4c/5). The snapshot's
id lists are the deterministic categorization; the command renders the full rows
(titles, assignees — untrusted external content) at runtime, NOT here.

cycle_snapshot + health are imported from cycle_metrics.py (shared with
sprint-planning — Rule-of-Three: cycle_snapshot has 2 consumers). The target-cycle
issues + meta are INJECTED (the plan-campaign inject-the-reads idiom) so decide() is
pure; the cycle SELECTION (empty → last completed, etc.) is the command's live-read
step, out of this deterministic slice.

emit artifact (`--scenarios <fixture> --out-dir <dir>`):
    retro-snapshot-emit.json = { schema_version, command, scenarios: [ {id, **decision} ] }

Stdlib-only; same command+helper pattern as build_raise_ticket_payload.py.
Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cycle_metrics import cycle_snapshot, health  # noqa: E402  (BC-12944 shared primitives)

SCHEMA_VERSION = 1
COMMAND = "/workflows:retrospective"

E_NO_TARGET_CYCLE = "no_target_cycle"


def decide(inputs: dict, linear_state: dict | None = None) -> dict:
    """PURE decision: (resolved cycle meta, injected issues) -> a snapshot row.

    `inputs.cycle` = the resolved target cycle meta {number, startsAt, endsAt}
    (the command's Step-1 selection result); `linear_state.issues` = the injected
    `list_issues({cycle})` rows. A missing cycle → the command's "No cycles found"
    stop, modelled as a reject row.
    """
    linear_state = linear_state or {}
    cycle = inputs.get("cycle")
    if not isinstance(cycle, dict) or cycle.get("number") is None:
        return {
            "error": E_NO_TARGET_CYCLE, "cycle_number": None,
            "total": None, "completed": None, "carried_over": None, "canceled": None,
            "completion_rate": None, "delivered_ids": [], "carried_ids": [],
            "canceled_ids": [], "health": None,
        }

    snap = cycle_snapshot(linear_state.get("issues"))
    return {
        "error": None,
        "cycle_number": cycle.get("number"),
        "total": snap["total"],
        "completed": snap["completed"],
        "carried_over": snap["carried_over"],
        "canceled": snap["canceled"],
        "completion_rate": snap["completion_rate"],
        "delivered_ids": snap["delivered_ids"],
        "carried_ids": snap["carried_ids"],
        "canceled_ids": snap["canceled_ids"],
        "health": health(snap["completion_rate"]),
    }


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any reject row."""


_INPUT_KEYS = ("cycle",)


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
        prog="build_retro_snapshot.py",
        description="Deterministic /workflows:retrospective delivery-snapshot builder (BC-12944).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write retro-snapshot-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one snapshot row to stdout")
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
            (out_dir / "retro-snapshot-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
