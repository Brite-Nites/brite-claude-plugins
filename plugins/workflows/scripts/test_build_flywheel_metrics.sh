#!/usr/bin/env bash
# Unit / contract suite for plugins/workflows/scripts/build_flywheel_metrics.py +
# the shared precedent_trace.py (BC-12945, ADR-028 Phase-2 Batch D — S3 metrics).
#
# build_flywheel_metrics.py reads a frozen docs/precedents/ corpus and computes the
# 3 computable flywheel metrics; the markdown parsing (precedent_trace) is the logic
# under test. The behavioral eval asserts the emit-artifact STRUCTURE over the
# committed seed; this suite drives the PURE compute() + the parsing primitives at
# finer granularity — the trend bands (improving/declining/stable/insufficient), the
# M4 computed/N/A branch, the CDR-coverage arithmetic, and the DEFENSIVE parsing
# (a malformed trace must not crash — the exit-2-or-clean contract).
#
# Usage:
#   bash plugins/workflows/scripts/test_build_flywheel_metrics.sh
#   bash plugins/workflows/scripts/test_build_flywheel_metrics.sh /path/to/build_flywheel_metrics.py

set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_flywheel_metrics.py}"
[ -f "$BUILDER" ] || { echo "FATAL: builder not found: $BUILDER" >&2; exit 2; }

BUILDER="$BUILDER" SCRIPTS_DIR="$HERE" python3 - "$@" <<'PY'
import json, os, subprocess, sys, tempfile
sys.path.insert(0, os.environ["SCRIPTS_DIR"])
import build_flywheel_metrics as fm
import precedent_trace as pt

BUILDER = os.environ["BUILDER"]
SEED = os.path.join(os.environ["SCRIPTS_DIR"], "..", "tests", "eval", "precedents-seed")

p = f = 0
def ok():
    global p; p += 1
def bad(msg):
    global f; f += 1; sys.stderr.write(f"FAIL: {msg}\n")
def eq(label, got, want):
    ok() if got == want else bad(f"{label}: got {got!r} want {want!r}")

# ── compute() trend bands (the load-bearing M2 edges) ─────────────────────────
def tr(months_conf):
    # months_conf: list of (date, confidence) -> traces; trend over months
    traces = [{"confidence": c, "has_cdr": False, "date": d} for d, c in months_conf]
    return fm.compute(traces, [], [], "2026-05-01")["m2"]["trend"]

eq("trend improving", tr([("2026-03-01", 6), ("2026-04-01", 8)]), "improving")   # +2.0
eq("trend declining", tr([("2026-03-01", 9), ("2026-04-01", 7)]), "declining")   # -2.0
eq("trend stable (diff 0.5, not >0.5)", tr([("2026-03-01", 7), ("2026-04-01", 7)]), "stable")
eq("trend stable boundary 0.5", tr([("2026-03-01", 7), ("2026-04-15", 7),
                                    ("2026-03-02", 8)]), "stable")  # 03 avg 7.5, 04 avg 7 -> -0.5 (not < -0.5)
eq("trend insufficient (1 month)", tr([("2026-04-01", 8)]), "insufficient data for trend")
eq("trend insufficient (empty)", tr([]), "insufficient data for trend")

# ── M3 CDR-coverage arithmetic + exclusions ───────────────────────────────────
traces = [
    {"confidence": 8, "has_cdr": True,  "date": "2026-03-01"},
    {"confidence": 6, "has_cdr": False, "date": "2026-03-01"},
    {"confidence": 7, "has_cdr": True,  "date": "2026-04-01"},
]
m = fm.compute(traces, [], [], "2026-05-01")
eq("m3 covered", m["m3"]["covered"], 2)
eq("m3 total", m["m3"]["total"], 3)
eq("m3 coverage pct", m["m3"]["cdr_coverage_pct"], 67)   # round(2/3*100)
eq("avg confidence", m["m2"]["avg_confidence"], 7.0)      # (8+6+7)/3

# ── M4 freshness computed vs N/A ──────────────────────────────────────────────
fresh = [
    {"path": "a", "band": "Fresh",     "in_denominator": True,  "fresh": True},
    {"path": "b", "band": "Aging",     "in_denominator": True,  "fresh": False},
    {"path": "c", "band": "on-change (skip)", "in_denominator": False, "fresh": False},
]
m4 = fm.compute([], [], fresh, "2026-05-01")["m4"]
eq("m4 computed status", m4["status"], "computed")
eq("m4 denominator excludes skip", m4["denominator"], 2)
eq("m4 fresh count", m4["fresh"], 1)
eq("m4 freshness pct", m4["freshness_pct"], 50)
m4na = fm.compute([], [], [{"path": "z", "band": "No freshness metadata",
                            "in_denominator": False, "fresh": False}], "2026-05-01")["m4"]
eq("m4 N/A status", m4na["status"], "N/A")
eq("m4 N/A pct null", m4na["freshness_pct"], None)

# ── empty corpus is valid, not a crash ────────────────────────────────────────
e = fm.compute([], [], [], "2026-05-01")
eq("empty total", e["total_traces"], 0)
eq("empty avg None", e["m2"]["avg_confidence"], None)
eq("empty cdr pct None", e["m3"]["cdr_coverage_pct"], None)
eq("empty m1 N/A", e["m1_status"], "N/A")

# ── DEFENSIVE: a malformed trace (no confidence / no date) must not crash ──────
malformed = [
    {"confidence": None, "has_cdr": False, "date": None},     # undated + confidence-less
    {"confidence": 8, "has_cdr": True, "date": "2026-04-01"},  # one good trace
]
md = fm.compute(malformed, [], [], "2026-05-01")
eq("malformed total counts both", md["total_traces"], 2)
eq("malformed avg ignores None conf", md["m2"]["avg_confidence"], 8.0)
eq("malformed monthly drops undated", sum(mm["traces"] for mm in md["monthly"]), 1)

# ── parsing primitives drive the real seed corpus (integration, parsing-under-test) ─
def decide_corpus(corpus, as_of="2026-05-01"):
    box = tempfile.mkdtemp()
    try:
        sc = json.dumps({"corpus": corpus, "as_of": as_of})
        out = subprocess.run([sys.executable, BUILDER, "--seed-dir", SEED, "--decide", "-"],
                             input=sc, capture_output=True, text=True, cwd=box)
        side = os.path.exists(os.path.join(box, "pwned"))
        return out.returncode, out.stdout, side
    finally:
        import shutil; shutil.rmtree(box, ignore_errors=True)

rc, out, side = decide_corpus("full")
eq("full corpus --decide rc 0", rc, 0)
eq("full corpus no side effect", side, False)
row = json.loads(out)
eq("full corpus 4 traces (parsed from markdown)", row["total_traces"], 4)
eq("full corpus declining trend", row["m2"]["trend"], "declining")
eq("full corpus M3 50%", row["m3"]["cdr_coverage_pct"], 50)
eq("full corpus M4 33%", row["m4"]["freshness_pct"], 33)
bands = {d["path"].split("/")[-1]: d["band"] for d in row["freshness_detail"]}
eq("doc-stale parsed Stale", bands["doc-stale.md"], "Stale")
eq("doc-missing classified MISSING", bands["doc-missing.md"], "MISSING")

# ── infra exit codes (exit-2-or-clean contract) ───────────────────────────────
box = tempfile.mkdtemp()
badfix = os.path.join(box, "bad.json"); open(badfix, "w").write("{not json")
rc = subprocess.run([sys.executable, BUILDER, "--scenarios", badfix, "--out-dir", box],
                    capture_output=True, text=True).returncode
eq("malformed fixture → exit 2", rc, 2)
import shutil; shutil.rmtree(box, ignore_errors=True)

print(f"RESULT pass={p} fail={f}")
sys.exit(1 if f else 0)
PY
