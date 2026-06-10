#!/usr/bin/env python3
"""Deterministic audit-trail builder for /workflows:audit-trail
(BC-12945, ADR-028 Phase-2 Batch D — S3 precedent-corpus context audit).

The PURE, hermetic decision core the command delegates to for the quantified parts
of a per-issue context audit: given a FROZEN docs/precedents/ corpus + the project
CLAUDE.md @imports + an INJECTED `as_of`, it reconstructs — with NO MCP call and NO
write — one issue's trace inputs, the session-level @import context, each referenced
file's staleness band + existence, and the frequency analysis (most-referenced,
session-only, single-use). The 2nd consumer of precedent_trace.py (Rule-of-Three
with build_flywheel_metrics.py): both parse `## Trace —` sections + run the same
last_refreshed/refresh_cadence staleness classification.

THE MARKDOWN PARSING IS THE LOGIC UNDER TEST (ADR-028 D2): the builder READS the
seed corpus, so the `## Trace —`/Inputs parsing + the existence/freshness
classification are exercised, not stubbed past. `as_of` is INJECTED (never
date.today()) so the staleness bands are reproducible.

What's OUT of scope (over-claim guard, ADR-028 D2): the LLM-narrated report prose;
the AskUserQuestion issue-id prompt; the live MCP session. The claim is "the
extracted builder reconstructs the documented audit (per-trace inputs + staleness +
frequency) over a frozen corpus," NOT runtime-LLM parity.

Security: the issue id is user-derived and used to build a file path, so decide()
re-validates it against `^[A-Z]+-[0-9]+$` (the command's Phase-0 guard) — a
`$(touch pwned)` / `../` value yields an `invalid_issue_id` row, never a path read.

emit artifact (`--scenarios <fixture> --out-dir <dir> [--seed-dir <root>]`):
    audit-trail-emit.json = { schema_version, command, scenarios: [ {id, **audit} ] }
Each scenario names a corpus subdir + an issue id + an as_of.

Stdlib-only; same command+helper pattern as build_flywheel_metrics.py.
Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import precedent_trace as pt  # noqa: E402  (BC-12945 shared precedent primitives)

SCHEMA_VERSION = 1
COMMAND = "/workflows:audit-trail"

ISSUE_ID_RE = re.compile(r"^[A-Z]+-[0-9]+\Z")  # \Z not $ — $ also matches before a trailing \n
E_INVALID_ISSUE_ID = "invalid_issue_id"
TOP_N = 5


def read_seed(corpus_dir: Path, issue_id: str, as_of: str) -> dict:
    """I/O boundary: read the issue's trace file + classify every referenced file
    (trace Inputs + CLAUDE.md @imports) via precedent_trace. Returns the parsed +
    classified inputs compute() consumes. A missing trace file → trace_file_exists
    False + no traces (the command's 'no traces found' branch)."""
    trace_path = corpus_dir / "docs" / "precedents" / f"{issue_id}.md"
    traces: list[dict] = []
    trace_file_exists = trace_path.is_file()
    if trace_file_exists:
        raw = pt.parse_traces(trace_path.read_text(encoding="utf-8", errors="replace"))
        for t in raw:
            classified = [pt.classify_context_file(corpus_dir, rel, as_of) for rel in t["inputs"]]
            traces.append({
                "summary": t["summary"], "category": t["category"],
                "confidence": t["confidence"],
                "precedent_referenced": t["precedent_referenced"],
                "has_cdr": t["has_cdr"],
                "inputs": [{"path": c["path"], "band": c["band"], "exists": c["exists"]}
                           for c in classified],
            })

    session_files: list[dict] = []
    claude_md = corpus_dir / "CLAUDE.md"
    if claude_md.is_file():
        imports = pt.parse_imports(claude_md.read_text(encoding="utf-8", errors="replace"))
        session_files = [pt.classify_context_file(corpus_dir, rel, as_of) for rel in imports]

    return {"traces": traces, "session_files": session_files,
            "trace_file_exists": trace_file_exists}


def compute(traces: list, session_files: list, trace_file_exists: bool) -> dict:
    """PURE audit reconstruction over the parsed+classified corpus reads. Defensive:
    a trace with no inputs contributes nothing to the frequency map; sort keys are
    total (freq desc, then path asc) so ties are reproducible (the sort_backlog
    tertiary-tiebreak lesson). NEVER raises."""
    freq: dict[str, int] = {}
    band_of: dict[str, str] = {}
    for t in traces:
        seen: set[str] = set()
        for inp in t["inputs"]:
            p = inp["path"]
            band_of[p] = inp["band"]
            if p not in seen:  # one trace counts a path once (trace-membership frequency)
                seen.add(p)
                freq[p] = freq.get(p, 0) + 1

    # most-referenced top-N: frequency DESC, then path ASC (a total key — no hash-flake).
    ranked = sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))
    most_referenced = [{"path": p, "count": c, "band": band_of[p]} for p, c in ranked[:TOP_N]]
    single_use = sorted(p for p, c in freq.items() if c == 1)

    trace_input_paths = set(freq)
    session_only = sorted(f["path"] for f in session_files if f["path"] not in trace_input_paths)

    # warnings over the UNION of referenced files (trace inputs + session @imports).
    all_bands = dict(band_of)
    for f in session_files:
        all_bands.setdefault(f["path"], f["band"])
    missing = sorted(p for p, b in all_bands.items() if b == pt.BAND_MISSING)
    stale = sorted(p for p, b in all_bands.items() if b == pt.BAND_STALE)
    very_stale = sorted(p for p, b in all_bands.items() if b == pt.BAND_VERY_STALE)

    return {
        "trace_file_exists": trace_file_exists,
        "trace_count": len(traces),
        "traces": traces,
        "session_context": [
            {"path": f["path"], "band": f["band"], "exists": f["exists"]}
            for f in session_files
        ],
        "frequency": {
            "most_referenced": most_referenced,
            "session_only": session_only,
            "single_use": single_use,
        },
        "warnings": {
            "missing": missing, "stale": stale, "very_stale": very_stale,
            "total": len(missing) + len(stale) + len(very_stale),
        },
    }


def decide(inputs: dict, seed_dir: Path) -> dict:
    """(scenario inputs {corpus, issue_id, as_of}, seed root) -> an audit row. The
    issue id is re-validated (path-traversal guard) before it touches the filesystem."""
    corpus = inputs.get("corpus") or "full"
    as_of = inputs.get("as_of") or "1970-01-01"
    issue_id = inputs.get("issue_id") or ""
    if not ISSUE_ID_RE.match(issue_id):
        return {
            "error": E_INVALID_ISSUE_ID, "issue_id": issue_id, "corpus": corpus,
            "as_of": as_of, "trace_file_exists": False, "trace_count": None,
            "traces": [], "session_context": [],
            "frequency": {"most_referenced": [], "session_only": [], "single_use": []},
            "warnings": {"missing": [], "stale": [], "very_stale": [], "total": 0},
        }
    corpus_dir = Path(seed_dir) / corpus
    parsed = read_seed(corpus_dir, issue_id, as_of)
    row = {"error": None, "issue_id": issue_id, "corpus": corpus, "as_of": as_of}
    row.update(compute(parsed["traces"], parsed["session_files"], parsed["trace_file_exists"]))
    return row


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any audit row."""


_INPUT_KEYS = ("corpus", "issue_id", "as_of")


def _scenario_inputs(scenario: dict) -> dict:
    return {k: scenario[k] for k in _INPUT_KEYS if k in scenario}


def run_scenarios(scenarios: list, seed_dir: Path) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        decision = decide(_scenario_inputs(sc), seed_dir)
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


_HERE = Path(__file__).resolve().parent
DEFAULT_SEED_DIR = _HERE.parent / "tests" / "eval" / "precedents-seed"


# ── CLI ───────────────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="build_audit_trail.py",
        description="Deterministic /workflows:audit-trail builder (BC-12945).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write audit-trail-emit.json into this dir (with --scenarios)")
    ap.add_argument("--seed-dir", default=str(DEFAULT_SEED_DIR),
                    help=f"frozen precedents seed root (default: {DEFAULT_SEED_DIR})")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one audit row to stdout")
    args = ap.parse_args(argv)

    seed_dir = Path(args.seed_dir)
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
            row = {"id": sc.get("id", "runtime"), **decide(_scenario_inputs(sc), seed_dir)}
            print(json.dumps(row, ensure_ascii=False))
            return 0

        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios, seed_dir)
            (out_dir / "audit-trail-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
