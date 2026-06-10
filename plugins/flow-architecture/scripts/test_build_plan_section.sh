#!/usr/bin/env bash
# Unit / contract suite for plugins/flow-architecture/scripts/build_plan_section.py
# (BC-12946, ADR-028 Phase-2 Batch E — the shared /flow:plan-{discipline} formatter).
#
# build_plan_section.py renders the Q43 Plan-section markdown from an injected four-mode
# review_output + routes the per-discipline Q46 marker. This suite drives the PURE
# render() at finer granularity than the behavioral eval: the per-mode fold (which field
# sources the bullets; adjustments[] last), the rationale-into-headline fold, the marker
# routing for all 5 disciplines, the mandatory **Mode:** tag, and the EXHAUSTIVE
# malformed-injected-state matrix (the recurring Batch-C/D crash-defense P1: non-dict /
# bad-or-missing mode / missing headline / non-list fields / non-string members — every
# one yields a DEFINED row, never a crash).
#
# Usage:
#   bash plugins/flow-architecture/scripts/test_build_plan_section.sh
#   bash plugins/flow-architecture/scripts/test_build_plan_section.sh /path/to/build_plan_section.py

set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_plan_section.py}"
[ -f "$BUILDER" ] || { echo "FATAL: builder not found: $BUILDER" >&2; exit 2; }

BUILDER="$BUILDER" SCRIPTS_DIR="$HERE" python3 - <<'PY'
import json, os, subprocess, sys, tempfile, shutil
sys.path.insert(0, os.environ["SCRIPTS_DIR"])
import build_plan_section as ps

BUILDER = os.environ["BUILDER"]

p = f = 0
def ok():
    global p; p += 1
def bad(msg):
    global f; f += 1; sys.stderr.write(f"FAIL: {msg}\n")
def eq(label, got, want):
    ok() if got == want else bad(f"{label}: got {got!r} want {want!r}")
def truthy(label, cond):
    ok() if cond else bad(f"{label}: expected truthy")

def ro(mode, headline="A solid headline.", **extra):
    d = {"mode": mode, "headline": headline}
    d.update(extra)
    return d

# ── 1. per-mode fold: the right field sources the bullets, adjustments[] last ──
r = ps.render(ro("SCOPE_EXPANSION", expansions=["e1", "e2"], adjustments=["a1"]), "eng")
eq("SCOPE_EXPANSION folds expansions then adjustments",
   r["section_markdown"].split("**Refinements:**\n")[1], "- e1\n- e2\n- a1")
r = ps.render(ro("SELECTIVE_EXPANSION", expansions=["e1"], adjustments=["a1"]), "story")
eq("SELECTIVE_EXPANSION also folds expansions",
   r["section_markdown"].split("**Refinements:**\n")[1], "- e1\n- a1")
r = ps.render(ro("HOLD_SCOPE", rigor_focus=["g1", "g2"], adjustments=["a1"]), "design")
eq("HOLD_SCOPE folds rigor_focus then adjustments",
   r["section_markdown"].split("**Refinements:**\n")[1], "- g1\n- g2\n- a1")
r = ps.render(ro("SCOPE_REDUCTION", reductions=["d1"], adjustments=[]), "qa")
eq("SCOPE_REDUCTION folds reductions; empty adjustments → no trailing bullets",
   r["section_markdown"].split("**Refinements:**\n")[1], "- d1")
# the off-mode source field is IGNORED (HOLD_SCOPE must not read expansions).
r = ps.render(ro("HOLD_SCOPE", expansions=["should-be-ignored"], rigor_focus=["g1"]), "eng")
truthy("the non-mode source field is ignored", "should-be-ignored" not in r["section_markdown"])

# ── 2. mandatory **Mode:** tag + Refinements heading (Q43 sub-decision 5) ──────
r = ps.render(ro("HOLD_SCOPE", rigor_focus=["g1"]), "docs")
truthy("opens with the **Mode:** tag", r["section_markdown"].startswith("**Mode:** HOLD_SCOPE"))
truthy("carries the **Refinements:** heading", "**Refinements:**" in r["section_markdown"])

# ── 3. rationale folds into the headline paragraph (trailing sentence) ─────────
r = ps.render(ro("HOLD_SCOPE", headline="Core is sound.", rigor_focus=["g1"],
                 rationale=["One surface only."]), "docs")
truthy("rationale folded into the headline paragraph",
       "Core is sound. One surface only." in r["section_markdown"])
truthy("rationale is NOT a separate sub-heading",
       "Rationale" not in r["section_markdown"])

# ── 4. marker routing for ALL 5 disciplines ───────────────────────────────────
for d in ("eng", "story", "design", "qa", "docs"):
    eq(f"marker routes to plan-{d}-section",
       ps.render(ro("HOLD_SCOPE", rigor_focus=["g"]), d)["marker_type"], f"plan-{d}-section")
    eq(f"discipline field is {d}",
       ps.render(ro("HOLD_SCOPE", rigor_focus=["g"]), d)["discipline"], d)

# ── 5. EXHAUSTIVE malformed-injected-state matrix (never crashes) ──────────────
def err_row(review_output, disc="eng"):
    r = ps.render(review_output, disc)
    return r["error"], r["section_markdown"], r["mode"], r["marker_type"]

e, md, mode, mk = err_row("not a dict")
truthy("non-dict review_output → error row, null markdown", e is not None and md is None)
truthy("non-dict still routes the marker (discipline is the CLI arg)", mk == "plan-eng-section")

e, md, mode, mk = err_row(ro("BOGUS_MODE"))
truthy("unknown mode → error row, null markdown", e is not None and md is None)
eq("unknown STRING mode is echoed for diagnosis", mode, "BOGUS_MODE")

e, md, mode, mk = err_row({"mode": 123, "headline": "x"})
truthy("non-string mode (123) → error row, NO crash", e is not None and md is None)
eq("non-string mode echoes null (not the int)", mode, None)

e, md, mode, mk = err_row({"mode": "HOLD_SCOPE"})  # missing headline
truthy("missing headline → error row", e is not None and md is None)
e, md, mode, mk = err_row(ro("HOLD_SCOPE", headline="   "))
truthy("blank headline → error row", e is not None and md is None)
e, md, mode, mk = err_row(ro("HOLD_SCOPE", headline=42))
truthy("non-string headline → error row, NO crash", e is not None and md is None)

# malformed list fields are COERCED (defended), not crashed, on an otherwise-valid row.
r = ps.render(ro("HOLD_SCOPE", rigor_focus="not-a-list", adjustments=["a1"]), "eng")
truthy("non-list rigor_focus coerced to empty (no crash)", r["error"] is None)
eq("non-list source → only adjustments survive",
   r["section_markdown"].split("**Refinements:**\n")[1], "- a1")
r = ps.render(ro("HOLD_SCOPE", rigor_focus=[1, "keep", None, {"x": 1}]), "eng")
eq("non-string list members are filtered out",
   r["section_markdown"].split("**Refinements:**\n")[1], "- keep")
r = ps.render(ro("HOLD_SCOPE", rigor_focus=["g1"], rationale="not-a-list"), "eng")
truthy("non-list rationale coerced (no crash, no fold)",
       r["error"] is None and r["section_markdown"].startswith("**Mode:** HOLD_SCOPE\n\nA solid headline.\n\n"))

# ── 6. determinism: identical inputs → identical markdown ─────────────────────
a = ps.render(ro("SCOPE_EXPANSION", expansions=["e1", "e2"], adjustments=["a1"]), "eng")
b = ps.render(ro("SCOPE_EXPANSION", expansions=["e1", "e2"], adjustments=["a1"]), "eng")
eq("render is deterministic", a, b)

# ── 7. exit-2-or-clean crash-defense via the CLI ──────────────────────────────
box = tempfile.mkdtemp()
try:
    badfix = os.path.join(box, "bad.json"); open(badfix, "w").write("{not json")
    rc = subprocess.run([sys.executable, BUILDER, "--discipline", "eng",
                         "--scenarios", badfix, "--out-dir", box],
                        capture_output=True, text=True).returncode
    eq("malformed fixture JSON → exit 2", rc, 2)

    nolist = os.path.join(box, "nolist.json"); open(nolist, "w").write('{"scenarios": 5}')
    rc = subprocess.run([sys.executable, BUILDER, "--discipline", "eng",
                         "--scenarios", nolist, "--out-dir", box],
                        capture_output=True, text=True).returncode
    eq("non-list scenarios → exit 2", rc, 2)

    # a degenerate review_output is a SUCCESSFUL emit (exit 0) with an error row.
    degen = os.path.join(box, "degen.json")
    open(degen, "w").write(json.dumps({"scenarios": [{"id": "x", "review_output": {"mode": "BOGUS"}}]}))
    rc = subprocess.run([sys.executable, BUILDER, "--discipline", "eng",
                         "--scenarios", degen, "--out-dir", box],
                        capture_output=True, text=True).returncode
    eq("degenerate review_output is a successful emit → exit 0", rc, 0)
    out = json.load(open(os.path.join(box, "plan-eng-emit.json")))
    truthy("the degenerate emit row carries an error", out["scenarios"][0]["error"] is not None)
finally:
    shutil.rmtree(box, ignore_errors=True)

print(f"RESULT pass={p} fail={f}")
sys.exit(1 if f else 0)
PY
