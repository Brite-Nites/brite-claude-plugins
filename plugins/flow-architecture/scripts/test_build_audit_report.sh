#!/usr/bin/env bash
# Unit / contract suite for plugins/flow-architecture/scripts/build_audit_report.py
# (BC-12946, ADR-028 Phase-2 Batch E — /flow:audit Phase-B gate evaluator).
#
# build_audit_report.py is an eval-only re-impl of the DOCUMENTED Phase-B gate
# semantics (audit.md § Phase B + the Q29 manifest). This suite drives the gate
# PREDICATES at finer granularity than the behavioral eval: the frame-mode
# strict/lenient narrowing, children-block parsing, per-gate flips via single-field
# repo mutations off the real clean fixture, the exit-code matrix (0/1/64), the
# determinism (gates sorted by total (id,scope), no absolute-path leak), and the
# exit-2-or-clean crash-defense contract via the CLI.
#
# Usage:
#   bash plugins/flow-architecture/scripts/test_build_audit_report.sh
#   bash plugins/flow-architecture/scripts/test_build_audit_report.sh /path/to/build_audit_report.py

set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_audit_report.py}"
[ -f "$BUILDER" ] || { echo "FATAL: builder not found: $BUILDER" >&2; exit 2; }

BUILDER="$BUILDER" SCRIPTS_DIR="$HERE" python3 - <<'PY'
import json, os, subprocess, sys, tempfile, shutil
sys.path.insert(0, os.environ["SCRIPTS_DIR"])
import build_audit_report as bar

BUILDER = os.environ["BUILDER"]
FIXTURES = os.path.abspath(os.path.join(os.environ["SCRIPTS_DIR"], "..", "tests", "fixtures"))
CLEAN = os.path.join(FIXTURES, "audit-clean-shape")
BROKEN = os.path.join(FIXTURES, "audit-broken-shape")

p = f = 0
def ok():
    global p; p += 1
def bad(msg):
    global f; f += 1; sys.stderr.write(f"FAIL: {msg}\n")
def eq(label, got, want):
    ok() if got == want else bad(f"{label}: got {got!r} want {want!r}")
def truthy(label, cond):
    ok() if cond else bad(f"{label}: expected truthy")

def fails(repo):
    """The set of (gate_id, scope) hard-fails for a repo (str or Path)."""
    return {(g["id"], g["scope"]) for g in bar.evaluate(bar.Path(repo)) if g["status"] == "hard-fail"}

# ── 1. the two real fixtures reproduce the documented oracle ──────────────────
eq("clean fixture: zero hard-fails", fails(CLEAN), set())
eq("broken fixture: EXACTLY the 3 documented hard-fails", fails(BROKEN), {
    ("story-docs-complete", "domain:TEAM"),
    ("index-complete", "project"),
    ("eng-children-engineering-populated", "flow:SHIP-01"),
})

# ── 2. frame-mode predicate: strict narrows, lenient floors ───────────────────
HUMAN = "# T\n\n> **When** x, **I want to** y, **so I can** z.\n\n## Acceptance\n"
CONSTRAINT = ("# T\n\n> **Given** a req, the system **MUST** serve, **so that** crawlable.\n\n"
              "## Acceptance\n")
FRAMELESS = "# T\n\n> This renders a page for a crawler. No frame.\n\n## Acceptance\n"
truthy("human frame passes under strict", bar._story_frame_present(HUMAN, "strict"))
truthy("human frame passes under lenient", bar._story_frame_present(HUMAN, "lenient"))
truthy("constraint frame REJECTED under strict", not bar._story_frame_present(CONSTRAINT, "strict"))
truthy("constraint frame accepted under lenient (floor)", bar._story_frame_present(CONSTRAINT, "lenient"))
truthy("frameless rejected (gate not vacuous)", not bar._story_frame_present(FRAMELESS, "lenient"))
# A decoy 'When' AFTER the ## Acceptance heading (Gherkin) must not satisfy the region-scoped gate.
DECOY = "# T\n\n> no frame here.\n\n## Acceptance\n\nScenario: s\n  When the user acts\n"
truthy("region-scoped: Gherkin 'When' below ## Acceptance does not satisfy the frame",
       not bar._story_frame_present(DECOY, "lenient"))

# ── 3. config story_frame mode reader (fail-safe lenient) ─────────────────────
def cfgmode(val):
    box = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(box, ".flow"))
        if val is not None:
            open(os.path.join(box, ".flow", "config.json"), "w").write(json.dumps({"story_frame": val}))
        return bar._config_story_frame_mode(bar.Path(box))
    finally:
        shutil.rmtree(box, ignore_errors=True)
eq("config story_frame:strict → strict", cfgmode("strict"), "strict")
eq("config story_frame:STRICT (uppercase) → strict", cfgmode("STRICT"), "strict")
eq("config story_frame:lenient → lenient", cfgmode("lenient"), "lenient")
eq("config story_frame:banana (unrecognized) → lenient", cfgmode("banana"), "lenient")
eq("config story_frame field absent → lenient", cfgmode(None), "lenient")

# ── 3b. config frontmatter_schema mode reader (BC-12572; fail-safe lenient) ────
def fmcfgmode(val):
    box = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(box, ".flow"))
        if val is not None:
            open(os.path.join(box, ".flow", "config.json"), "w").write(
                json.dumps({"frontmatter_schema": val}))
        return bar._config_frontmatter_schema_mode(bar.Path(box))
    finally:
        shutil.rmtree(box, ignore_errors=True)
eq("config frontmatter_schema:strict → strict", fmcfgmode("strict"), "strict")
eq("config frontmatter_schema:STRICT (uppercase) → strict", fmcfgmode("STRICT"), "strict")
eq("config frontmatter_schema:banana (unrecognized) → lenient", fmcfgmode("banana"), "lenient")
eq("config frontmatter_schema field absent → lenient", fmcfgmode(None), "lenient")
# valid-but-non-dict config.json (a top-level JSON list/scalar) must fail-safe to
# lenient, NOT raise AttributeError on .get — the malformed-injected-state class.
def rawcfg(text, fn):
    box = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(box, ".flow"))
        open(os.path.join(box, ".flow", "config.json"), "w").write(text)
        return fn(bar.Path(box))
    finally:
        shutil.rmtree(box, ignore_errors=True)
eq("non-dict config (JSON list) → frontmatter_schema lenient (no crash)",
   rawcfg('["a","b"]', bar._config_frontmatter_schema_mode), "lenient")
eq("non-dict config (JSON scalar) → frontmatter_schema lenient (no crash)",
   rawcfg('42', bar._config_frontmatter_schema_mode), "lenient")
eq("non-dict config (JSON list) → story_frame lenient (twin hardened too)",
   rawcfg('["a","b"]', bar._config_story_frame_mode), "lenient")

# ── 3c. story-front-matter-populated predicate: lenient floor vs strict canon ──
# Directly exercises the NEW Python strict branch (lint_text delegation), the twin of
# run-audit-smoke.sh §4e — so the bash↔Python ORACLE covers BOTH impls of the widening.
FM_LEAN = "---\nflow_id: X-01\nstatus: BUILT\nfigma: TBD\nuser_docs_url: TBD\n---\n# b\n"
FM_FULL = ("---\nflow_id: X-01\ndomain: X\nstatus: BUILT\nparent_issue: BC-1\n"
           "children:\n  story: BC-2\n  engineering: BC-3\n  design: BC-4\n  qa: BC-5\n  docs: BC-6\n"
           "personas: []\nrelated_flows: []\nfigma: TBD\nsandbox_url: TBD\nstaging_url: TBD\n"
           "real_app_url: TBD\ne2e_test: TBD\nuser_docs_url: TBD\nqa_status: not-tested\n"
           "qa_last_signed_off: null\neng_status: not-started\ndesign_status: not-started\n"
           "docs_status: not-started\nintent: ../../intent.md\nlast_reviewed: 2026-06-14\n---\n# b\n")
truthy("lenient: the 4-key floor doc PASSes populated", bar._story_frontmatter_populated(FM_LEAN, "lenient"))
truthy("strict: the 4-key floor doc FAILs populated (needs full canon)",
       not bar._story_frontmatter_populated(FM_LEAN, "strict"))
truthy("strict: the full-canon doc PASSes populated", bar._story_frontmatter_populated(FM_FULL, "strict"))
truthy("strict: honest-empty personas:[]/null still PASS (presence not non-emptiness)",
       bar._story_frontmatter_populated(FM_FULL, "strict"))
# control: the clean fixture's lean docs do NOT fail story-front-matter-populated under
# the default (lenient) — the e2e strict flip is asserted in Section 5 via with_mutation.
truthy("lenient default: lean clean-fixture doc PASSes story-front-matter-populated",
       ("story-front-matter-populated", "flow:TEAM-01") not in fails(CLEAN))

# ── 4. children-block parser ──────────────────────────────────────────────────
DOC_CHILDREN = ("---\nflow_id: X-01\nchildren:\n  story: BC-1\n  engineering: BC-2\n"
                "  qa: BC-3\n---\n# body\n")
truthy("children.engineering present", bar._children_field_present(DOC_CHILDREN, "engineering"))
truthy("children.qa present", bar._children_field_present(DOC_CHILDREN, "qa"))
truthy("children.design ABSENT", not bar._children_field_present(DOC_CHILDREN, "design"))
# A 'design:' key OUTSIDE the children block (top-level) must not count as a child.
DOC_OUTSIDE = "---\nchildren:\n  story: BC-1\n---\ndesign: not-a-child\n"
truthy("top-level design: key not counted as a child",
       not bar._children_field_present(DOC_OUTSIDE, "design"))

# ── 5. per-gate flips via single-field mutations off the clean fixture ────────
def with_mutation(fn):
    """Copy the clean fixture, apply fn(repo_path), return its hard-fail set."""
    box = tempfile.mkdtemp()
    repo = os.path.join(box, "repo")
    shutil.copytree(CLEAN, repo)
    try:
        fn(repo)
        return fails(repo)
    finally:
        shutil.rmtree(box, ignore_errors=True)

def rm(repo, rel):
    os.remove(os.path.join(repo, rel))

truthy("removing intent.md → intent-exists fails",
       ("intent-exists", "project") in with_mutation(lambda r: rm(r, "docs/product/intent.md")))

def break_config(r):
    p_ = os.path.join(r, ".flow", "config.json")
    d = json.load(open(p_)); d.pop("fda_plugin_version"); json.dump(d, open(p_, "w"))
truthy("dropping a required config field → preflight-complete fails",
       ("preflight-complete", "project") in with_mutation(break_config))

truthy("removing a journey doc → journey-complete fails for that domain",
       ("journey-complete", "domain:TEAM") in with_mutation(lambda r: rm(r, "docs/product/journeys/TEAM.md")))

def drop_scenario(r):
    d = os.path.join(r, "docs/product/flows/TEAM/TEAM-01.md")
    t = open(d).read()
    # Remove the last Scenario block → 2 scenarios → out of the 3-5 band.
    idx = t.rfind("Scenario:")
    open(d, "w").write(t[:idx])
truthy("dropping a Scenario (→2) → story-ac-gherkin-count fails",
       ("story-ac-gherkin-count", "flow:TEAM-01") in with_mutation(drop_scenario))

def strip_children_qa(r):
    d = os.path.join(r, "docs/product/flows/TEAM/TEAM-01.md")
    t = open(d).read().replace("  qa: BC-1103\n", "")
    open(d, "w").write(t)
truthy("removing children.qa → qa-children-qa-populated fails",
       ("qa-children-qa-populated", "flow:TEAM-01") in with_mutation(strip_children_qa))

def strict_constraint(r):
    # strict config + swap one doc's human frame for a constraint-spec frame.
    cfgp = os.path.join(r, ".flow", "config.json")
    c = json.load(open(cfgp)); c["story_frame"] = "strict"; json.dump(c, open(cfgp, "w"))
    d = os.path.join(r, "docs/product/flows/TEAM/TEAM-01.md")
    t = open(d).read()
    import re as _re
    t = _re.sub(r"^> \*\*When\*\*.*$",
                "> **Given** a req, the system **MUST** act, **so that** it works.",
                t, count=1, flags=_re.M)
    open(d, "w").write(t)
truthy("story_frame:strict + constraint-spec doc → story-job-story-regex fails",
       ("story-job-story-regex", "flow:TEAM-01") in with_mutation(strict_constraint))
# control: the SAME swap under lenient (no strict config) must NOT fail the gate.
def lenient_constraint(r):
    d = os.path.join(r, "docs/product/flows/TEAM/TEAM-01.md")
    t = open(d).read()
    import re as _re
    t = _re.sub(r"^> \*\*When\*\*.*$",
                "> **Given** a req, the system **MUST** act, **so that** it works.",
                t, count=1, flags=_re.M)
    open(d, "w").write(t)
truthy("control: constraint-spec doc under lenient does NOT fail (flag, not doc, drives it)",
       ("story-job-story-regex", "flow:TEAM-01") not in with_mutation(lenient_constraint))

# frontmatter_schema:strict (BC-12572) e2e: the clean fixture's docs carry only the
# 4-key floor, so flipping the repo to strict flips story-front-matter-populated to a
# hard-fail — exercising the NEW Python strict branch (lint_text) through evaluate(),
# the twin of run-audit-smoke.sh §4e (bash↔Python ORACLE now covers both impls).
def strict_frontmatter(r):
    cfgp = os.path.join(r, ".flow", "config.json")
    c = json.load(open(cfgp)); c["frontmatter_schema"] = "strict"; json.dump(c, open(cfgp, "w"))
truthy("frontmatter_schema:strict + lean clean-fixture doc → story-front-matter-populated fails (e2e)",
       ("story-front-matter-populated", "flow:TEAM-01") in with_mutation(strict_frontmatter))

# ── 6. determinism: gates sorted by total (id, scope); no absolute-path leak ───
# NOTE: evaluate() returns UNSORTED; decide()/CLI sort. Assert the sort key is total
# (no crash) and that decide() output is sorted.
row = bar.decide({"id": "clean", "repo": "audit-clean-shape"}, bar.Path(FIXTURES))
dk = [(g["id"], g["scope"]) for g in row["gates"]]
eq("decide() sorts gates by total (id, scope)", dk, sorted(dk))
truthy("no absolute path leaks into any gate message",
       all(("/Users/" not in g["message"] and "/private/" not in g["message"]
            and FIXTURES not in g["message"]) for g in row["gates"]))

# ── 7. exit-code matrix via decide() ──────────────────────────────────────────
clean_row = bar.decide({"id": "clean", "repo": "audit-clean-shape"}, bar.Path(FIXTURES))
eq("clean row exit_code 0", clean_row["summary"]["exit_code"], 0)
broken_row = bar.decide({"id": "broken", "repo": "audit-broken-shape"}, bar.Path(FIXTURES))
eq("broken row exit_code 1", broken_row["summary"]["exit_code"], 1)
eq("broken row hard_fail count 3", broken_row["summary"]["hard_fail"], 3)
bad_gate = bar.decide({"id": "ig", "repo": "audit-clean-shape", "gate": "nope"}, bar.Path(FIXTURES))
eq("invalid --gate → exit_code 64", bad_gate["summary"]["exit_code"], 64)
truthy("invalid --gate → error message present", bad_gate["error"] is not None)
eq("invalid --gate → no gates emitted", bad_gate["gates"], [])
# crash-defense regression: a NON-HASHABLE (list/dict) injected gate must route to the
# 64 arg-guard row, not raise on the frozenset hash (the recurring P1).
for bad in (["a"], {"k": "v"}, 42, True):
    row = bar.decide({"id": "x", "repo": "audit-clean-shape", "gate": bad}, bar.Path(FIXTURES))
    eq(f"non-string gate {bad!r} → exit_code 64 (no crash)", row["summary"]["exit_code"], 64)
# a VALID gate id is NOT a 64 (only unrecognized ids guard).
valid_gate = bar.decide({"id": "vg", "repo": "audit-clean-shape", "gate": "intent-exists"}, bar.Path(FIXTURES))
truthy("valid --gate id is not rejected as 64", valid_gate["summary"]["exit_code"] != 64)

# ── 8. exit-2-or-clean crash-defense contract via the CLI ─────────────────────
box = tempfile.mkdtemp()
try:
    badfix = os.path.join(box, "bad.json"); open(badfix, "w").write("{not json")
    rc = subprocess.run([sys.executable, BUILDER, "--scenarios", badfix, "--out-dir", box],
                        capture_output=True, text=True).returncode
    eq("malformed fixture JSON → exit 2", rc, 2)

    nolist = os.path.join(box, "nolist.json"); open(nolist, "w").write('{"scenarios": "x"}')
    rc = subprocess.run([sys.executable, BUILDER, "--scenarios", nolist, "--out-dir", box],
                        capture_output=True, text=True).returncode
    eq("non-list scenarios → exit 2", rc, 2)

    missing_repo = os.path.join(box, "mr.json")
    open(missing_repo, "w").write(json.dumps({"scenarios": [{"id": "x", "repo": "does-not-exist"}]}))
    rc = subprocess.run([sys.executable, BUILDER, "--scenarios", missing_repo, "--out-dir", box,
                         "--fixtures-dir", FIXTURES], capture_output=True, text=True).returncode
    eq("missing fixture repo → exit 2", rc, 2)

    # path-confinement: a `../` repo value must NOT escape the fixtures dir.
    escape = os.path.join(box, "esc.json")
    open(escape, "w").write(json.dumps({"scenarios": [{"id": "x", "repo": "../../../../etc"}]}))
    proc = subprocess.run([sys.executable, BUILDER, "--scenarios", escape, "--out-dir", box,
                           "--fixtures-dir", FIXTURES], capture_output=True, text=True)
    eq("a ../ repo escaping the fixtures dir → exit 2", proc.returncode, 2)
    truthy("the escape error names the confinement", "escapes the fixtures dir" in proc.stderr)

    no_repo = os.path.join(box, "norepo.json")
    open(no_repo, "w").write(json.dumps({"scenarios": [{"id": "x"}]}))
    rc = subprocess.run([sys.executable, BUILDER, "--scenarios", no_repo, "--out-dir", box,
                         "--fixtures-dir", FIXTURES], capture_output=True, text=True).returncode
    eq("scenario missing 'repo' → exit 2", rc, 2)

    # a clean emit run exits 0.
    okfix = os.path.join(box, "ok.json")
    open(okfix, "w").write(json.dumps({"scenarios": [{"id": "clean", "repo": "audit-clean-shape"}]}))
    rc = subprocess.run([sys.executable, BUILDER, "--scenarios", okfix, "--out-dir", box,
                         "--fixtures-dir", FIXTURES], capture_output=True, text=True).returncode
    eq("well-formed emit → exit 0", rc, 0)
finally:
    shutil.rmtree(box, ignore_errors=True)

print(f"RESULT pass={p} fail={f}")
sys.exit(1 if f else 0)
PY
