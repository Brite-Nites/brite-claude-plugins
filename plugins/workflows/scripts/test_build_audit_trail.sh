#!/usr/bin/env bash
# Unit / contract suite for plugins/workflows/scripts/build_audit_trail.py +
# the shared precedent_trace.py (BC-12945, ADR-028 Phase-2 Batch D — S3 audit).
#
# build_audit_trail.py reads a frozen docs/precedents/ corpus and reconstructs one
# issue's context audit; the markdown parsing + staleness classification (the shared
# precedent_trace primitives) are the logic under test. This suite drives the PURE
# compute() (frequency top-N cap + the (count desc, path asc) tiebreak, single-use /
# session-only definitions, warnings↔band) and the SECURITY issue-id guard (a `../` /
# `$(touch pwned)` value must reject with NO filesystem read + NO side effect — the
# single-quoted-injection-fixture discipline).
#
# Usage:
#   bash plugins/workflows/scripts/test_build_audit_trail.sh
#   bash plugins/workflows/scripts/test_build_audit_trail.sh /path/to/build_audit_trail.py

set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_audit_trail.py}"
[ -f "$BUILDER" ] || { echo "FATAL: builder not found: $BUILDER" >&2; exit 2; }

BUILDER="$BUILDER" SCRIPTS_DIR="$HERE" python3 - "$@" <<'PY'
import json, os, subprocess, sys, tempfile, shutil
sys.path.insert(0, os.environ["SCRIPTS_DIR"])
import build_audit_trail as at

BUILDER = os.environ["BUILDER"]
SEED = os.path.join(os.environ["SCRIPTS_DIR"], "..", "tests", "eval", "precedents-seed")

p = f = 0
def ok():
    global p; p += 1
def bad(msg):
    global f; f += 1; sys.stderr.write(f"FAIL: {msg}\n")
def eq(label, got, want):
    ok() if got == want else bad(f"{label}: got {got!r} want {want!r}")

def inp(path, band="Fresh", exists=True):
    return {"path": path, "band": band, "exists": exists}
def trace(*paths, **kw):
    return {"summary": "t", "category": "architecture", "confidence": 8,
            "precedent_referenced": "CDR-1", "has_cdr": True,
            "inputs": [inp(p, **kw) for p in paths]}

# ── frequency: top-5 cap + (count desc, path asc) tiebreak ────────────────────
traces = [
    trace("a", "b", "c"),  # a,b,c
    trace("a", "b", "d"),  # a,b,d  → a=3,b=2 after t3
    trace("a", "e"),       # a,e
    trace("f"),            # f
]
# a=3, b=2, c=1, d=1, e=1, f=1
out = at.compute(traces, [], True)
mr = out["frequency"]["most_referenced"]
eq("top-5 cap", len(mr), 5)
eq("ranked by count desc then path asc",
   [(r["path"], r["count"]) for r in mr],
   [("a", 3), ("b", 2), ("c", 1), ("d", 1), ("e", 1)])  # f (path-last of the 1-ties) dropped
eq("single_use = paths in exactly one trace", out["frequency"]["single_use"], ["c", "d", "e", "f"])

# ── session_only: a session @import never cited in a trace input ──────────────
sess = [inp("a"), inp("zzz-session-only.md")]
out2 = at.compute([trace("a", "b")], sess, True)
eq("session_only excludes cited a, keeps the uncited import",
   out2["frequency"]["session_only"], ["zzz-session-only.md"])

# ── warnings ↔ band (MISSING / Stale / Very Stale), over inputs ∪ session ──────
wtr = [trace("ok.md"), {"summary": "t", "category": None, "confidence": None,
                        "precedent_referenced": None, "has_cdr": False,
                        "inputs": [inp("gone.md", "MISSING", False),
                                   inp("old.md", "Stale"),
                                   inp("ancient.md", "Very Stale")]}]
wsess = [inp("sess-missing.md", "MISSING", False)]
w = at.compute(wtr, wsess, True)["warnings"]
eq("warnings.missing (inputs ∪ session, sorted)", w["missing"], ["gone.md", "sess-missing.md"])
eq("warnings.stale", w["stale"], ["old.md"])
eq("warnings.very_stale", w["very_stale"], ["ancient.md"])
eq("warnings.total", w["total"], 4)

# ── no-trace-file branch: trace_count 0, but session context survives ─────────
nt = at.compute([], [inp("s.md")], False)
eq("no-trace trace_count 0", nt["trace_count"], 0)
eq("no-trace traces empty", nt["traces"], [])
eq("no-trace session context kept", len(nt["session_context"]), 1)

# ── SECURITY: the issue-id guard rejects traversal / injection / malformed ────
def decide_id(issue_id):
    box = tempfile.mkdtemp()
    try:
        row = at.decide({"corpus": "full", "issue_id": issue_id, "as_of": "2026-05-01"}, SEED)
        # decide() never shells, but assert the no-side-effect contract regardless.
        side = os.path.exists(os.path.join(box, "pwned"))
        return row, side
    finally:
        shutil.rmtree(box, ignore_errors=True)

for evil in ['../../etc/passwd', '$(touch pwned)', 'BC-1; touch pwned',
             '`touch pwned`', 'bc-9101', 'BC9101', '', 'BC-1/../../x', 'BC-9101\n']:
    row, side = decide_id(evil)
    eq(f"guard rejects {evil!r}", row["error"], "invalid_issue_id")
    eq(f"guard reads nothing for {evil!r}", row["trace_file_exists"], False)
    eq(f"no side effect for {evil!r}", side, False)
eq("no pwned in cwd", os.path.exists("pwned"), False)

# a VALID id is accepted and reads the corpus.
good = at.decide({"corpus": "full", "issue_id": "BC-9101", "as_of": "2026-05-01"}, SEED)
eq("valid id error None", good["error"], None)
eq("valid id parses 2 traces from markdown", good["trace_count"], 2)
eq("valid id top-referenced is doc-fresh (cited twice)",
   good["frequency"]["most_referenced"][0]["path"], "docs/refs/doc-fresh.md")
eq("valid id flags doc-gone MISSING + doc-stale Stale",
   (sorted(good["warnings"]["missing"]), good["warnings"]["stale"]),
   (["docs/refs/doc-gone.md", "docs/refs/doc-missing.md"], ["docs/refs/doc-stale.md"]))

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
