#!/usr/bin/env bash
# Unit / contract suite for plugins/workflows/scripts/build_promotion_candidates.py
# (BC-12945, ADR-028 Phase-2 Batch D — S2 promote-precedent candidate pipeline).
#
# build_promotion_candidates.py is the PURE decide() the command delegates to for the
# candidate merge/dedup/gate/sort/generalize projection (the slice before any human
# review or git/Linear mutation). This suite drives decide() directly across the
# verdict ladder precedence (id guard > Source-B conf gate > handbook dedup), the
# A-vs-B dedup (A wins), the case-insensitive handbook match, the category filter, the
# Source-A trust (never conf-gated), the (conf desc, date desc, id asc) sort tiebreak,
# the path generalization (idempotent, leaves absolute), and the SECURITY id guard (a
# `../`/`$(touch pwned)` value → rejected_invalid_id, no side effect — single-quoted
# injection fixtures). The behavioral eval asserts the emit STRUCTURE; this asserts the
# per-branch DECISIONS + injection-safety.
#
# Usage:
#   bash plugins/workflows/scripts/test_build_promotion_candidates.sh
#   bash plugins/workflows/scripts/test_build_promotion_candidates.sh /path/to/build_promotion_candidates.py

set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_promotion_candidates.py}"
[ -f "$BUILDER" ] || { echo "FATAL: builder not found: $BUILDER" >&2; exit 2; }

BUILDER="$BUILDER" SCRIPTS_DIR="$HERE" python3 - "$@" <<'PY'
import json, os, subprocess, sys, tempfile, shutil
sys.path.insert(0, os.environ["SCRIPTS_DIR"])
import build_promotion_candidates as bp

BUILDER = os.environ["BUILDER"]
p = f = 0
def ok():
    global p; p += 1
def bad(msg):
    global f; f += 1; sys.stderr.write(f"FAIL: {msg}\n")
def eq(label, got, want):
    ok() if got == want else bad(f"{label}: got {got!r} want {want!r}")

def verdict(cands, issue_id):
    for c in cands:
        if c["issue_id"] == issue_id:
            return c["verdict"]
    return None

# ── generalize_path (idempotent; leaves absolute + already-generalized) ───────
eq("generalize relative", bp.generalize_path("src/a.ts"), "<project>/src/a.ts")
eq("generalize idempotent", bp.generalize_path("<project>/src/a.ts"), "<project>/src/a.ts")
eq("generalize leaves absolute", bp.generalize_path("/etc/x"), "/etc/x")
eq("generalize empty", bp.generalize_path(""), "")

# ── verdict ladder + Source-A trust + A-vs-B dedup + category filter ───────────
out = bp.decide({
    "linear_candidates": [
        {"issue_id": "BC-1", "decision": "d-a1", "confidence": 9, "date": "2026-04-10", "category": "architecture"},
        {"issue_id": "BC-2", "decision": "dup-in-hb", "confidence": 9, "date": "2026-04-05", "category": "architecture"},
    ],
    "index_rows": [
        {"issue": "BC-1", "decision": "d-a1", "category": "architecture", "date": "2026-04-10"},   # A-vs-B dup of BC-1
        {"issue": "BC-3", "decision": "d-b3", "category": "library-selection", "date": "2026-04-12"},  # conf 8 -> promotable
        {"issue": "BC-4", "decision": "d-b4", "category": "trade-off", "date": "2026-04-01"},  # conf 6 -> low
        {"issue": "BC-5", "decision": "d-b5", "category": "architecture", "date": "2026-03-20"},  # no trace conf -> missing
        {"issue": "BC-6", "decision": "ignored", "category": "pattern-choice", "date": "2026-03-15"},  # not eligible
    ],
    "trace_confidence": {"BC-3": 8, "BC-4": 6},
    "handbook_rows": [{"issue": "BC-2", "decision": "DUP-IN-HB"}],  # case-insensitive match
    "paths": {"BC-1": ["src/auth.ts"], "BC-3": ["lib/io.py"]},
})
cands = out["candidates"]
ids = sorted(c["issue_id"] for c in cands)
eq("BC-6 (pattern-choice) filtered out + BC-1 deduped A-vs-B",
   ids, ["BC-1", "BC-2", "BC-3", "BC-4", "BC-5"])
eq("BC-1 (Source A) promotable", verdict(cands, "BC-1"), "promotable")
eq("BC-2 already in handbook (case-insensitive)", verdict(cands, "BC-2"), "skipped_already_in_handbook")
eq("BC-3 (Source B, conf 8) promotable", verdict(cands, "BC-3"), "promotable")
eq("BC-4 (Source B, conf 6) low confidence", verdict(cands, "BC-4"), "rejected_low_confidence")
eq("BC-5 (Source B, no trace conf) trace missing", verdict(cands, "BC-5"), "rejected_trace_missing")
bc1 = next(c for c in cands if c["issue_id"] == "BC-1")
eq("BC-1 source is linear (won A-vs-B)", bc1["source"], "linear")
eq("BC-1 generalized path", bc1["generalized_paths"], ["<project>/src/auth.ts"])

# Source A is TRUSTED — a Source-A candidate is NEVER confidence-gated even at conf 1.
trusted = bp.decide({"linear_candidates": [
    {"issue_id": "BC-9", "decision": "low-but-trusted", "confidence": 1, "date": "2026-04-01", "category": "architecture"}]})
eq("Source A low-conf still promotable (trusted)", verdict(trusted["candidates"], "BC-9"), "promotable")

# Precedence: an invalid id wins over every other rejection reason.
prec = bp.decide({"index_rows": [
    {"issue": "../bad", "decision": "x", "category": "architecture", "date": "2026-01-01"}],
    "trace_confidence": {}, "handbook_rows": []})
eq("invalid id wins precedence", verdict(prec["candidates"], "../bad"), "rejected_invalid_id")

# ── sort tiebreak: conf DESC, date DESC, id ASC ───────────────────────────────
so = bp.decide({"linear_candidates": [
    {"issue_id": "BC-7002", "decision": "d", "confidence": 9, "date": "2026-04-01", "category": "architecture"},
    {"issue_id": "BC-7001", "decision": "d", "confidence": 9, "date": "2026-04-01", "category": "architecture"},
    {"issue_id": "BC-7003", "decision": "d", "confidence": 9, "date": "2026-05-01", "category": "architecture"},
    {"issue_id": "BC-7004", "decision": "d", "confidence": 7, "date": "2026-06-01", "category": "architecture"},
]})
eq("sort conf>date>id", [c["issue_id"] for c in so["candidates"]],
   ["BC-7003", "BC-7001", "BC-7002", "BC-7004"])

# ── summary tallies ───────────────────────────────────────────────────────────
eq("summary total", out["summary"]["total"], 5)
eq("summary promotable", out["summary"]["promotable"], 2)
eq("summary low confidence", out["summary"]["rejected_low_confidence"], 1)

# ── empty input is valid, not a crash ─────────────────────────────────────────
e = bp.decide({})
eq("empty candidates", e["candidates"], [])
eq("empty summary total", e["summary"]["total"], 0)

# ── DEFENSIVE: a malformed injected `date` (non-string) must NOT crash the sort ──
# (the BC-12944 P1 regression class — a non-total sort key over int<str). Two
# eligible candidates force a comparison; the int-dated row coerces to "" (sorts last).
md = bp.decide({"linear_candidates": [
    {"issue_id": "BC-100", "decision": "good date", "confidence": 9, "date": "2026-04-01", "category": "architecture"},
    {"issue_id": "BC-101", "decision": "int date", "confidence": 9, "date": 123, "category": "architecture"},
    {"issue_id": "BC-102", "decision": "bool date", "confidence": 9, "date": True, "category": "architecture"},
]})
eq("malformed date does not crash; well-dated sorts first",
   [c["issue_id"] for c in md["candidates"]], ["BC-100", "BC-101", "BC-102"])

# ── SECURITY: injection / traversal ids reject with NO side effect ────────────
box = tempfile.mkdtemp()
try:
    for evil in ['../../etc/passwd', '$(touch pwned)', 'BC-1; touch pwned', '`touch pwned`', 'bc-1', 'BC-1\n']:
        r = bp.decide({"linear_candidates": [
            {"issue_id": evil, "decision": "x", "confidence": 9, "date": "2026-04-01", "category": "architecture"}]})
        eq(f"guard rejects {evil!r}", verdict(r["candidates"], evil), "rejected_invalid_id")
    eq("no pwned in cwd", os.path.exists(os.path.join(box, "pwned")), False)
finally:
    shutil.rmtree(box, ignore_errors=True)
eq("no pwned leaked to test cwd", os.path.exists("pwned"), False)

# ── infra exit codes (exit-2-or-clean contract via the CLI) ───────────────────
box = tempfile.mkdtemp()
badfix = os.path.join(box, "bad.json"); open(badfix, "w").write("{not json")
rc = subprocess.run([sys.executable, BUILDER, "--scenarios", badfix, "--out-dir", box],
                    capture_output=True, text=True).returncode
eq("malformed fixture → exit 2", rc, 2)
shutil.rmtree(box, ignore_errors=True)

print(f"RESULT pass={p} fail={f}")
sys.exit(1 if f else 0)
PY
