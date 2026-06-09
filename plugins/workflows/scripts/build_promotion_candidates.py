#!/usr/bin/env python3
"""Deterministic promotion-candidate pipeline for /workflows:promote-precedent
(BC-12945, ADR-028 Phase-2 Batch D — S2 side-effecting decision core).

The PURE, hermetic decision core the command delegates to for the candidate
pipeline that precedes any human review or git/Linear mutation: given the two
INJECTED candidate sources + the handbook dedup set, it computes — with NO MCP
call and NO write — the merge / ISSUE-ID guard / Source-B confidence gate /
dedup-vs-handbook / sort / path-generalization projection.

The inject-the-reads idiom (S2, like build_raise_ticket_payload.py / BC-12701):
the markdown PARSING of the project INDEX + the trace confidences is done UPSTREAM
(it is exactly the parsing build_flywheel_metrics / build_audit_trail already test —
so injecting the parsed rows here is non-vacuous: the candidate DECISION pipeline is
the unit under test, not the parser). The reads injected per scenario:

    linear_candidates : Source A — issues with the `precedent-promotion` label
                        (already flagged by compound-learnings → trusted, no conf gate)
    index_rows        : Source B — parsed project INDEX.md rows (parse_index shape)
    trace_confidence  : {issue_id: int} — the pre-read trace confidence for the
                        Source-B >=8 gate (a missing entry = trace file missing)
    handbook_rows     : the handbook INDEX dedup set ({issue, decision})
    paths             : {issue_id: [path,...]} — the project-specific paths to
                        generalize on a promotable candidate

What's OUT of scope (over-claim guard, ADR-028 D2): the human Promote/Skip/Edit
decision (Phase 3d), the git clone/branch/commit/PR, the `save_issue` Linear
transitions, and the handbook write (Phases 4-6 — the real mutations). The claim is
"the candidate merge/dedup/gate/sort/generalize projection is correct," NOT runtime
parity. This command IS side-effecting (git push + gh pr create + save_issue), so it
carries `disable-model-invocation: true` — the eval drives only the pre-mutation slice.

Security: the issue id is user-derived (it builds file paths + git refs downstream),
so every candidate id is re-validated against `^[A-Z]+-[0-9]+$` (the command's Phase-3a
guard); a `../`/`$()` value yields a `rejected_invalid_id` verdict, never a path/ref use.

emit artifact (`--scenarios <fixture> --out-dir <dir>`):
    promotion-candidates-emit.json = { schema_version, command, scenarios: [ {id, **projection} ] }

Stdlib-only; same command+helper pattern as build_raise_ticket_payload.py.
Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA_VERSION = 1
COMMAND = "/workflows:promote-precedent"

ISSUE_ID_RE = re.compile(r"^[A-Z]+-[0-9]+\Z")  # \Z not $ — $ also matches before a trailing \n
# Only these categories are gathered from the INDEX scan (Source B); the command's
# Phase-1 filter. A row outside this set is never a candidate (silently ignored).
ELIGIBLE_CATEGORIES = ("architecture", "library-selection", "trade-off")
CONFIDENCE_THRESHOLD = 8  # Source-B promotion gate (>= 8)
PROJECT_TOKEN = "<project>"

V_PROMOTABLE = "promotable"
V_INVALID_ID = "rejected_invalid_id"
V_LOW_CONFIDENCE = "rejected_low_confidence"
V_TRACE_MISSING = "rejected_trace_missing"
V_ALREADY = "skipped_already_in_handbook"


def generalize_path(p: str) -> str:
    """`src/middleware/auth.ts` → `<project>/src/middleware/auth.ts`. An already-
    generalized (`<project>/…`) or absolute (`/…`) path is left unchanged (idempotent +
    no double-prefix). PURE string transform."""
    if not p or p.startswith(PROJECT_TOKEN + "/") or p.startswith("/"):
        return p
    return f"{PROJECT_TOKEN}/{p}"


def _dedup_key(issue_id: str, decision: str) -> tuple:
    """The composite dedup key: issue id + case-insensitive Decision text."""
    return (issue_id, (decision or "").strip().casefold())


def decide(inputs: dict) -> dict:
    """PURE decision: the injected reads → the candidate projection. The single
    entrypoint shared by the command (runtime, with live reads) and the eval (with
    fixture-injected reads). Defensive: a malformed row (missing id/decision) is
    coerced to a string and routed by the id guard, never a crash."""
    linear = inputs.get("linear_candidates") or []
    index_rows = inputs.get("index_rows") or []
    trace_conf = inputs.get("trace_confidence") or {}
    handbook_rows = inputs.get("handbook_rows") or []
    paths = inputs.get("paths") or {}

    handbook_keys = {
        _dedup_key(str(r.get("issue", "")), str(r.get("decision", "")))
        for r in handbook_rows if isinstance(r, dict)
    }

    # ── merge Source A (trusted) + Source B (INDEX scan, eligible categories only) ──
    candidates: list[dict] = []
    seen_ab: set[tuple] = set()  # A-vs-B dedup (keep A when both present)

    for c in linear:
        if not isinstance(c, dict):
            continue
        issue_id = str(c.get("issue_id", ""))
        decision = str(c.get("decision", ""))
        candidates.append({
            "issue_id": issue_id, "decision": decision,
            "category": c.get("category"), "confidence": c.get("confidence"),
            "date": c.get("date"), "source": "linear",
        })
        seen_ab.add(_dedup_key(issue_id, decision))

    for r in index_rows:
        if not isinstance(r, dict):
            continue
        if r.get("category") not in ELIGIBLE_CATEGORIES:
            continue  # Phase-1 category filter — non-eligible rows are not gathered
        issue_id = str(r.get("issue", ""))
        decision = str(r.get("decision", ""))
        key = _dedup_key(issue_id, decision)
        if key in seen_ab:
            continue  # already gathered from Source A (A carries the Linear context)
        seen_ab.add(key)
        candidates.append({
            "issue_id": issue_id, "decision": decision,
            "category": r.get("category"),
            "confidence": trace_conf.get(issue_id),  # pre-read trace confidence (Source B)
            "date": r.get("date"), "source": "index",
        })

    # ── per-candidate verdict ladder (precedence: id guard > conf gate > handbook) ──
    for c in candidates:
        if not ISSUE_ID_RE.match(c["issue_id"]):
            c["verdict"] = V_INVALID_ID
            c["generalized_paths"] = []
            continue
        # Source-B confidence gate (Source A is trusted — already flagged).
        if c["source"] == "index":
            if c["issue_id"] not in trace_conf:
                c["verdict"] = V_TRACE_MISSING
                c["generalized_paths"] = []
                continue
            if not isinstance(c["confidence"], int) or c["confidence"] < CONFIDENCE_THRESHOLD:
                c["verdict"] = V_LOW_CONFIDENCE
                c["generalized_paths"] = []
                continue
        # Dedup vs the handbook (composite key, case-insensitive Decision).
        if _dedup_key(c["issue_id"], c["decision"]) in handbook_keys:
            c["verdict"] = V_ALREADY
            c["generalized_paths"] = []
            continue
        c["verdict"] = V_PROMOTABLE
        c["generalized_paths"] = [generalize_path(p) for p in (paths.get(c["issue_id"]) or [])]

    # ── sort for review presentation: conf DESC, date DESC, id ASC (a TOTAL key) ──
    # Composed stable sorts, least-significant first (the sort_backlog tiebreak lesson).
    # EVERY key is total: a non-string date or non-int confidence in an injected row
    # must not raise (the exit-2-or-clean contract — a degenerate `date: 123` cell from
    # a malformed INDEX/Linear read coerces to "" rather than crashing the whole emit).
    candidates.sort(key=lambda c: c["issue_id"])
    candidates.sort(key=lambda c: c["date"] if isinstance(c.get("date"), str) else "", reverse=True)
    candidates.sort(key=lambda c: c["confidence"] if isinstance(c.get("confidence"), int) else -1,
                    reverse=True)

    summary = {
        "total": len(candidates),
        V_PROMOTABLE: sum(1 for c in candidates if c["verdict"] == V_PROMOTABLE),
        V_INVALID_ID: sum(1 for c in candidates if c["verdict"] == V_INVALID_ID),
        V_LOW_CONFIDENCE: sum(1 for c in candidates if c["verdict"] == V_LOW_CONFIDENCE),
        V_TRACE_MISSING: sum(1 for c in candidates if c["verdict"] == V_TRACE_MISSING),
        V_ALREADY: sum(1 for c in candidates if c["verdict"] == V_ALREADY),
    }
    return {"candidates": candidates, "summary": summary}


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any verdict."""


_INPUT_KEYS = ("linear_candidates", "index_rows", "trace_confidence", "handbook_rows", "paths")


def _scenario_inputs(scenario: dict) -> dict:
    return {k: scenario[k] for k in _INPUT_KEYS if k in scenario}


def run_scenarios(scenarios: list) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        decision = decide(_scenario_inputs(sc))
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
        prog="build_promotion_candidates.py",
        description="Deterministic /workflows:promote-precedent candidate pipeline (BC-12945).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write promotion-candidates-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one projection row to stdout")
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
            row = {"id": sc.get("id", "runtime"), **decide(_scenario_inputs(sc))}
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
            (out_dir / "promotion-candidates-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
