#!/usr/bin/env python3
"""Deterministic flywheel-metrics builder for /workflows:flywheel-metrics
(BC-12945, ADR-028 Phase-2 Batch D — S3 precedent-corpus metrics).

The PURE, hermetic decision core the command delegates to for the computable
flywheel metrics: given a FROZEN docs/precedents/ corpus + the project CLAUDE.md
@imports + an INJECTED `as_of`, it computes — with NO MCP call and NO write — the
three computable metrics (M2 decision-confidence avg + monthly trend, M3 CDR
coverage, M4 context freshness) and marks M1/M5 N/A (they need instrumentation
that does not exist — the command documents this).

THE MARKDOWN PARSING IS THE LOGIC UNDER TEST (ADR-028 D2, the Batch-D shaping
call): unlike the Batch-C cycle builders (which take pre-parsed Linear JSON), the
load-bearing work here is reading `## Trace —` sections + freshness frontmatter out
of real markdown, so this builder READS a seed corpus (the build_offer_perf_emit.py
copy-seed-then-parse shape) rather than receiving parsed JSON — injecting parsed
rows would move the actual point of the eval out of the test surface. The parsing
primitives + the staleness math live in precedent_trace.py (shared with
build_audit_trail.py — Rule-of-Three).

Determinism: `as_of` is INJECTED (never date.today()) so the M4 staleness bands +
the monthly trend are reproducible (the cycle_metrics inject-as_of idiom).

What's OUT of scope (over-claim guard, ADR-028 D2): M1 (precedent hit rate) + M5
(override rate) — both N/A pending instrumentation; the LLM-authored "Insights"
prose; the rendered dashboard markdown (the command narrates it from this data).
The claim is "the extracted builder computes the documented metrics over a frozen
precedents corpus," NOT runtime-LLM parity (the command is un-rewired prose).

emit artifact (`--scenarios <fixture> --out-dir <dir> [--seed-dir <root>]`):
    flywheel-metrics-emit.json = { schema_version, command, scenarios: [ {id, **metrics} ] }
Each scenario names a corpus subdir under the seed root + an as_of.

Stdlib-only; same command+helper pattern as build_retro_snapshot.py.
Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import precedent_trace as pt  # noqa: E402  (BC-12945 shared precedent primitives)

SCHEMA_VERSION = 1
COMMAND = "/workflows:flywheel-metrics"

# Trace files glob, minus the non-trace docs the command excludes by name.
_NON_TRACE = {"INDEX.md", "INDEX-archive.md", "README.md"}


def read_corpus(corpus_dir: Path, as_of: str) -> dict:
    """Read a frozen precedents corpus → the parsed inputs compute() consumes. The
    I/O boundary; the parsing/classification is delegated to precedent_trace."""
    precedents = corpus_dir / "docs" / "precedents"
    traces: list[dict] = []
    if precedents.is_dir():
        for f in sorted(precedents.glob("*.md")):
            if f.name in _NON_TRACE:
                continue
            traces.extend(pt.parse_traces(f.read_text(encoding="utf-8", errors="replace")))

    index_rows: list[dict] = []
    index = precedents / "INDEX.md"
    if index.is_file():
        index_rows = pt.parse_index(index.read_text(encoding="utf-8", errors="replace"))

    freshness: list[dict] = []
    claude_md = corpus_dir / "CLAUDE.md"
    if claude_md.is_file():
        imports = pt.parse_imports(claude_md.read_text(encoding="utf-8", errors="replace"))
        freshness = [pt.classify_context_file(corpus_dir, rel, as_of) for rel in imports]

    return {"traces": traces, "index_rows": index_rows, "freshness": freshness}


def _trend(monthly: list[dict]) -> str:
    """Compare the last two months' avg confidence: improving (>+0.5) / declining
    (<-0.5) / stable; insufficient when <2 months carry a numeric average (the
    command's '<2 months of data' rule)."""
    usable = [m for m in monthly if m["avg_confidence"] is not None]
    if len(usable) < 2:
        return "insufficient data for trend"
    diff = usable[-1]["avg_confidence"] - usable[-2]["avg_confidence"]
    if diff > 0.5:
        return "improving"
    if diff < -0.5:
        return "declining"
    return "stable"


def compute(traces: list, index_rows: list, freshness: list, as_of: str) -> dict:
    """PURE metric computation over the parsed corpus. Defensive: an undated /
    confidence-less trace is simply excluded from the affected aggregate, never a
    crash (the exit-2-or-clean contract). `as_of` is accepted for symmetry with
    audit (the freshness was classified upstream against it)."""
    total = len(traces)
    confs = [t["confidence"] for t in traces if isinstance(t.get("confidence"), int)]
    avg_conf = round(sum(confs) / len(confs), 1) if confs else None

    by_month: dict[str, dict] = {}
    for t in traces:
        mo = pt.month_of(t.get("date"))
        if mo is None:
            continue  # an undated trace can't be grouped (defensive)
        b = by_month.setdefault(mo, {"confs": [], "cdr": 0, "n": 0})
        b["n"] += 1
        if isinstance(t.get("confidence"), int):
            b["confs"].append(t["confidence"])
        if t.get("has_cdr"):
            b["cdr"] += 1
    months = sorted(by_month)
    monthly = [{
        "month": m,
        "traces": by_month[m]["n"],
        "avg_confidence": round(sum(by_month[m]["confs"]) / len(by_month[m]["confs"]), 1)
        if by_month[m]["confs"] else None,
        "cdr_coverage_pct": round(by_month[m]["cdr"] * 100 / by_month[m]["n"]),
    } for m in months]

    cdr_n = sum(1 for t in traces if t.get("has_cdr"))
    cdr_pct = round(cdr_n * 100 / total) if total else None

    denom = [f for f in freshness if f.get("in_denominator")]
    fresh_n = sum(1 for f in denom if f.get("fresh"))
    if denom:
        m4 = {"status": "computed", "freshness_pct": round(fresh_n * 100 / len(denom)),
              "fresh": fresh_n, "denominator": len(denom)}
    else:
        m4 = {"status": "N/A", "freshness_pct": None, "fresh": 0, "denominator": 0}

    return {
        "total_traces": total,
        "months": months,
        "m1_status": "N/A",
        "m2": {"avg_confidence": avg_conf, "trend": _trend(monthly)},
        "m3": {"cdr_coverage_pct": cdr_pct, "covered": cdr_n, "total": total},
        "m4": m4,
        "m5_status": "N/A",
        "monthly": monthly,
        "index_row_count": len(index_rows),
        "freshness_detail": [
            {"path": f["path"], "band": f["band"],
             "in_denominator": f["in_denominator"], "fresh": f["fresh"]}
            for f in freshness
        ],
    }


def decide(inputs: dict, seed_dir: Path) -> dict:
    """(scenario inputs {corpus, as_of}, seed root) -> a metrics row. Reads the
    named corpus subdir, then computes. A missing/blank corpus → an empty-but-valid
    metrics row (total 0, trend insufficient, M4 N/A) — never a crash."""
    corpus = inputs.get("corpus") or "full"
    as_of = inputs.get("as_of") or "1970-01-01"
    corpus_dir = Path(seed_dir) / corpus
    parsed = read_corpus(corpus_dir, as_of)
    row = {"corpus": corpus, "as_of": as_of}
    row.update(compute(parsed["traces"], parsed["index_rows"], parsed["freshness"], as_of))
    return row


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any metrics row."""


_INPUT_KEYS = ("corpus", "as_of")


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
        prog="build_flywheel_metrics.py",
        description="Deterministic /workflows:flywheel-metrics builder (BC-12945).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write flywheel-metrics-emit.json into this dir (with --scenarios)")
    ap.add_argument("--seed-dir", default=str(DEFAULT_SEED_DIR),
                    help=f"frozen precedents seed root (default: {DEFAULT_SEED_DIR})")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one metrics row to stdout")
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
            (out_dir / "flywheel-metrics-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
