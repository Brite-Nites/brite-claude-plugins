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
eq("broken fixture: EXACTLY the 4 documented hard-fails", fails(BROKEN), {
    ("story-docs-complete", "domain:TEAM"),
    ("index-complete", "project"),
    ("eng-children-engineering-populated", "flow:SHIP-01"),
    # SHIP-01's missing children.engineering is a STORY_CANON key, so since BC-13915
    # hardcoded the full-canon floor it trips story-front-matter-populated too (one
    # structural omission, two gates). See tests/fixtures/audit-broken-shape/README.md.
    ("story-front-matter-populated", "flow:SHIP-01"),
})

# ── 2. story-frame predicate: human-only (constraint-spec rejected) ───────────
# BC-12197 collapsed the per-repo story_frame flag — the predicate is now single-arg
# and accepts ONLY the human job-story frame; the retired constraint-spec frame is
# rejected unconditionally.
HUMAN = "# T\n\n> **When** x, **I want to** y, **so I can** z.\n\n## Acceptance\n"
CONSTRAINT = ("# T\n\n> **Given** a req, the system **MUST** serve, **so that** crawlable.\n\n"
              "## Acceptance\n")
FRAMELESS = "# T\n\n> This renders a page for a crawler. No frame.\n\n## Acceptance\n"
truthy("human frame passes", bar._story_frame_present(HUMAN))
truthy("constraint frame REJECTED (human-only end-state)", not bar._story_frame_present(CONSTRAINT))
truthy("frameless rejected (gate not vacuous)", not bar._story_frame_present(FRAMELESS))
# A decoy 'When' AFTER the ## Acceptance heading (Gherkin) must not satisfy the region-scoped gate.
DECOY = "# T\n\n> no frame here.\n\n## Acceptance\n\nScenario: s\n  When the user acts\n"
truthy("region-scoped: Gherkin 'When' below ## Acceptance does not satisfy the frame",
       not bar._story_frame_present(DECOY))

# ── 2b. marker-form brittleness (BC-13751): core keyword INSIDE a bold span ────
# The predicate matches a marker's keyword inside a bold span, not only as the exact
# `**keyword**` span — so the "to"-less human near-miss stops being a false-negative.
# The bold REQUIREMENT is unchanged (unbolded prose never passes); keywords are
# word-boundaried (no "I want" in "I wanted"). The negatives confirm the keyword-in-span
# loosening does NOT over-widen: none carry the human frame, so all are rejected —
# including the phrase-bolded constraint marker (no human frame, human-only end-state).
# Mirror of tests/run-audit-smoke.sh § 4b (kept in lockstep per BC-13148).
IWANT_NO_TO = "# T\n\n> **When** x, **I want** y, **so I can** z.\n\n## Acceptance\n"
truthy("human **I want** (no 'to') accepted (keyword-in-span, BC-13751)",
       bar._story_frame_present(IWANT_NO_TO))
PHRASE_MUST = ("# T\n\n> **Given** a req, **the system MUST** serve, **so that** crawlable.\n\n"
               "## Acceptance\n")
truthy("phrase-bolded constraint **the system MUST** REJECTED (no human frame)",
       not bar._story_frame_present(PHRASE_MUST))
UNBOLDED = ("# T\n\n> Given a crawler requests the page, the system MUST serve a sitemap, "
            "so that pages rank.\n\n## Acceptance\n")
truthy("UNBOLDED prose rejected (bold requirement intact)",
       not bar._story_frame_present(UNBOLDED))
SO_TRUNC = "# T\n\n> **When** x, **I want to** y, **so** z.\n\n## Acceptance\n"
truthy("**so** (not 'so I can') still rejected — human marker incomplete (deferred to brite-base epic)",
       not bar._story_frame_present(SO_TRUNC))
MUSTARD = ("# T\n\n> **Given** a req, **mustard glaze** is applied, **so that** it works.\n\n"
           "## Acceptance\n")
truthy("constraint-shaped doc with no human markers rejected (**mustard** is not a marker)",
       not bar._story_frame_present(MUSTARD))
IWANTED = "# T\n\n> **When** x, **I wanted to** y, **so I can** z.\n\n## Acceptance\n"
truthy("word-boundary: 'I want' in **I wanted to** does NOT satisfy the want marker",
       not bar._story_frame_present(IWANTED))
# GAP control (the real brite-labs false-positive): two UNRELATED bold spans with
# unbolded prose BETWEEN them must NOT read as one bold span. The closing `**` of span
# A + the opening `**` of span B must never pair across the gap.
GAP = ("# T\n\n> **Doc type:** Constraint spec. Given a req, the system MUST serve, "
       "so that crawlable. Beneficiary: **[Persona](p.md)**\n\n## Acceptance\n")
truthy("UNBOLDED markers between two bold spans do not satisfy the frame (gap is not a span)",
       not bar._story_frame_present(GAP))

# ── R. redirect-stub predicates (BC-12907): doc_type marker + resolvable pointer ──
eq("_doc_type reads the marker", bar._doc_type("---\ndoc_type: redirect\n---\n# x\n"), "redirect")
eq("_doc_type case/quote tolerant", bar._doc_type('---\ndoc_type: "Redirect"\n---\n'), "redirect")
eq("_doc_type absent → ''", bar._doc_type("---\nflow_id: X-01\n---\n"), "")
def _redirect_repo():
    box = tempfile.mkdtemp()
    for dom, fid in (("audit-acl", "ACL-06"), ("secure-file-ingestion", "SFI-05")):
        d = os.path.join(box, "docs", "product", "flows", dom)
        os.makedirs(d)
        open(os.path.join(d, fid + ".md"), "w").write("# " + fid + "\n")
    return box
_RB = _redirect_repo()
try:
    truthy("redirect_to resolvable across domains (SFI-05 alias → ACL-06)",
           bar._redirect_to_resolvable(bar.Path(_RB), "ACL-06"))
    truthy("redirect_to tolerates backticks/space (`ACL-06`)",
           bar._redirect_to_resolvable(bar.Path(_RB), "`ACL-06`"))
    truthy("redirect_to dangling (no such flow) → False",
           not bar._redirect_to_resolvable(bar.Path(_RB), "NOPE-99"))
    truthy("redirect_to empty → False",
           not bar._redirect_to_resolvable(bar.Path(_RB), ""))
    truthy("redirect_to self-pointer (== own flow_id) → False (no-op loop, BC-12907 review-fix)",
           not bar._redirect_to_resolvable(bar.Path(_RB), "SFI-05", "SFI-05"))
    truthy("redirect_to to a DIFFERENT flow with self_fid set still resolves",
           bar._redirect_to_resolvable(bar.Path(_RB), "ACL-06", "SFI-05"))
finally:
    shutil.rmtree(_RB, ignore_errors=True)

# ── R2. evaluate() honors the redirect profile (BC-12907): redirect gates, story gates skipped ──
def _eval_redirect_repo(target):
    box = tempfile.mkdtemp()
    a = os.path.join(box, "docs", "product", "flows", "audit-acl"); os.makedirs(a)
    open(os.path.join(a, "ACL-06.md"), "w").write("# ACL-06\n")
    s = os.path.join(box, "docs", "product", "flows", "secure-file-ingestion"); os.makedirs(s)
    open(os.path.join(s, "SFI-05.md"), "w").write(
        "---\nflow_id: SFI-05\ndomain: secure-file-ingestion\ndoc_type: redirect\n"
        "redirect_to: %s\nintent: x\nlast_reviewed: y\n---\n# SFI-05 (redirect)\n" % target)
    return box
def _sfi_gates(box):
    return {(g["id"], g["status"]) for g in bar.evaluate(bar.Path(box)) if g["scope"] == "flow:SFI-05"}
_E1 = _eval_redirect_repo("ACL-06")
try:
    g1 = _sfi_gates(_E1); ids1 = {i for (i, s) in g1}
    truthy("evaluate: valid redirect → redirect-target-resolvable=pass", ("redirect-target-resolvable", "pass") in g1)
    truthy("evaluate: redirect SKIPS story-job-story-regex", "story-job-story-regex" not in ids1)
    truthy("evaluate: redirect SKIPS story-front-matter-populated", "story-front-matter-populated" not in ids1)
finally:
    shutil.rmtree(_E1, ignore_errors=True)
_E2 = _eval_redirect_repo("NOPE-99")
try:
    truthy("evaluate: dangling redirect → redirect-target-resolvable=hard-fail",
           ("redirect-target-resolvable", "hard-fail") in _sfi_gates(_E2))
finally:
    shutil.rmtree(_E2, ignore_errors=True)
_E3 = _eval_redirect_repo("SFI-05")  # self-pointer: redirect_to == own flow_id
try:
    truthy("evaluate: self-pointer redirect → redirect-target-resolvable=hard-fail (BC-12907 review-fix)",
           ("redirect-target-resolvable", "hard-fail") in _sfi_gates(_E3))
finally:
    shutil.rmtree(_E3, ignore_errors=True)

# R2b. redirect-front-matter-valid enforces REDIRECT_CANON unconditionally (BC-13915 —
# no longer gated on `frontmatter_schema: strict`; the per-repo flag was collapsed).
def _eval_redirect_canon_repo(omit_key=None):
    box = tempfile.mkdtemp()
    a = os.path.join(box, "docs", "product", "flows", "audit-acl"); os.makedirs(a)
    open(os.path.join(a, "ACL-06.md"), "w").write("# ACL-06\n")
    s = os.path.join(box, "docs", "product", "flows", "secure-file-ingestion"); os.makedirs(s)
    pairs = [("flow_id", "SFI-05"), ("domain", "secure-file-ingestion"),
             ("doc_type", "redirect"), ("redirect_to", "ACL-06"),
             ("intent", "../../intent.md"), ("last_reviewed", "2026-06-23")]
    fm = "---\n" + "".join("%s: %s\n" % (k, v) for k, v in pairs if k != omit_key) + "---\n# SFI-05\n"
    open(os.path.join(s, "SFI-05.md"), "w").write(fm)
    return box
_ES1 = _eval_redirect_canon_repo()
try:
    truthy("evaluate: complete redirect canon → redirect-front-matter-valid=pass",
           ("redirect-front-matter-valid", "pass") in _sfi_gates(_ES1))
finally:
    shutil.rmtree(_ES1, ignore_errors=True)
_ES2 = _eval_redirect_canon_repo(omit_key="intent")
try:
    truthy("evaluate: redirect missing canon key → redirect-front-matter-valid=hard-fail (BC-12907 review-fix)",
           ("redirect-front-matter-valid", "hard-fail") in _sfi_gates(_ES2))
finally:
    shutil.rmtree(_ES2, ignore_errors=True)

# R2c. cross-cutting parity (BC-12907 review-fix): a redirect stub has a flow_id but NO status,
# so index-story-doc-status-match must SKIP it (guarded `fid and stat`) — not emit a spurious
# project-scope hard-fail — while inventory-story-doc-id-match still PASSES (its fid is in the
# inventory). Locks the Python side of the bash-twin guard fix (Greptile #487).
def _eval_redirect_xcut_repo():
    box = tempfile.mkdtemp()
    s = os.path.join(box, "docs", "product", "flows", "secure-file-ingestion"); os.makedirs(s)
    open(os.path.join(s, "SFI-05.md"), "w").write(
        "---\nflow_id: SFI-05\ndomain: secure-file-ingestion\ndoc_type: redirect\n"
        "redirect_to: ACL-06\nintent: ../../intent.md\nlast_reviewed: 2026-06-23\n---\n# SFI-05\n")
    a = os.path.join(box, "docs", "product", "flows", "audit-acl"); os.makedirs(a)
    open(os.path.join(a, "ACL-06.md"), "w").write(
        "---\nflow_id: ACL-06\ndomain: audit-acl\nstatus: BUILT\n---\n# ACL-06\n")
    flows = os.path.join(box, "docs", "product", "flows")
    open(os.path.join(flows, "INDEX.md"), "w").write(
        "# INDEX\n\n| F | S | x |\n|---|---|---|\n| SFI-05 | NOT_STARTED | a |\n| ACL-06 | BUILT | b |\n")
    open(os.path.join(box, "docs", "product", "master-flow-inventory.md"), "w").write(
        "# Inv\n\n## Domain: secure-file-ingestion\n\n| SFI-05 | x |\n\n## Domain: audit-acl\n\n| ACL-06 | y |\n")
    return box
_EX = _eval_redirect_xcut_repo()
try:
    _xg = {(g["id"], g["status"]) for g in bar.evaluate(bar.Path(_EX)) if g["scope"] == "project"}
    truthy("evaluate: redirect stub (no status) does NOT trip index-story-doc-status-match",
           ("index-story-doc-status-match", "pass") in _xg)
    truthy("evaluate: redirect stub does NOT trip inventory-story-doc-id-match (fid in inventory)",
           ("inventory-story-doc-id-match", "pass") in _xg)
finally:
    shutil.rmtree(_EX, ignore_errors=True)

# ── R3. flow_index:skip excludes overview/index docs from story gates (BC-13805) ──
def _skip_repo():
    box = tempfile.mkdtemp()
    d = os.path.join(box, "docs", "product", "flows", "quotes"); os.makedirs(d)
    # a real sub-flow + an overview doc opting out via flow_index: skip
    open(os.path.join(d, "QUO-01.md"), "w").write(
        "---\nflow_id: QUO-01\ndomain: quotes\nstatus: BUILT\n---\n# QUO-01\n")
    open(os.path.join(d, "user-flows.md"), "w").write(
        "---\ndomain: quotes\nflow_index: skip\n---\n# Quote user flows (overview)\nNo job story.\n")
    return box
_SK = _skip_repo()
try:
    stems = {p.stem for p in bar._story_docs(bar.Path(_SK), "quotes")}
    truthy("_story_docs EXCLUDES a flow_index:skip doc", "user-flows" not in stems)
    truthy("_story_docs keeps the real sub-flow", "QUO-01" in stems)
    truthy("_flow_index_skipped True for skip doc",
           bar._flow_index_skipped(bar.Path(_SK) / "docs/product/flows/quotes/user-flows.md"))
    truthy("_flow_index_skipped False for real doc",
           not bar._flow_index_skipped(bar.Path(_SK) / "docs/product/flows/quotes/QUO-01.md"))
    sk_scopes = {g["scope"] for g in bar.evaluate(bar.Path(_SK))}
    truthy("evaluate emits NO gates for the skip doc", "flow:user-flows" not in sk_scopes)
finally:
    shutil.rmtree(_SK, ignore_errors=True)

# ── 3. story-front-matter-populated predicate: full canon required (unconditional) ──
# The story_frame AND frontmatter_schema mode readers were both deleted with their flags
# (BC-12197 / BC-13915); both gates are now hardcoded, so there is no config to resolve.
# This directly exercises the single-arg full-canon predicate (lint_text delegation), the
# twin of run-audit-smoke.sh §4e — the bash↔Python ORACLE covers BOTH impls.
FM_LEAN = "---\nflow_id: X-01\nstatus: BUILT\nfigma: TBD\nuser_docs_url: TBD\n---\n# b\n"
FM_FULL = ("---\nflow_id: X-01\ndomain: X\nstatus: BUILT\nparent_issue: BC-1\n"
           "children:\n  story: BC-2\n  engineering: BC-3\n  design: BC-4\n  qa: BC-5\n  docs: BC-6\n"
           "personas: []\nrelated_flows: []\nfigma: TBD\nsandbox_url: TBD\nstaging_url: TBD\n"
           "real_app_url: TBD\ne2e_test: TBD\nuser_docs_url: TBD\nqa_status: not-tested\n"
           "qa_last_signed_off: null\neng_status: not-started\ndesign_status: not-started\n"
           "docs_status: not-started\nintent: ../../intent.md\nlast_reviewed: 2026-06-14\n---\n# b\n")
truthy("the 4-key floor doc FAILs populated (full canon required — BC-13915)",
       not bar._story_frontmatter_populated(FM_LEAN))
truthy("the full-canon doc PASSes populated", bar._story_frontmatter_populated(FM_FULL))
truthy("honest-empty personas:[]/null still PASS (presence not non-emptiness)",
       bar._story_frontmatter_populated(FM_FULL))

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

# BC-12197: the story-frame gate is hardcoded human-only — no config to set. A
# constraint-spec doc FAILs story-job-story-regex unconditionally (the per-repo flag +
# its lenient floor were removed).
def constraint_doc(r):
    d = os.path.join(r, "docs/product/flows/TEAM/TEAM-01.md")
    t = open(d).read()
    import re as _re
    t = _re.sub(r"^> \*\*When\*\*.*$",
                "> **Given** a req, the system **MUST** act, **so that** it works.",
                t, count=1, flags=_re.M)
    open(d, "w").write(t)
truthy("constraint-spec doc → story-job-story-regex fails (human-only end-state)",
       ("story-job-story-regex", "flow:TEAM-01") in with_mutation(constraint_doc))

# story-front-matter-populated requires full canon UNCONDITIONALLY (BC-13915) e2e: the
# clean fixture is now full canon (so fails(CLEAN) is empty — §1 pins that); a doc
# DOWNGRADED to the lean 4-key floor hard-fails through evaluate(), exercising the Python
# full-canon lint_text path — the twin of run-audit-smoke.sh §4e (bash↔Python ORACLE).
def lean_frontmatter(r):
    import re as _re
    d = os.path.join(r, "docs/product/flows/TEAM/TEAM-01.md")
    strip = {"domain", "parent_issue", "personas", "related_flows", "sandbox_url",
             "staging_url", "real_app_url", "e2e_test", "eng_status", "design_status",
             "docs_status", "intent"}
    out = []
    for l in open(d):
        m = _re.match(r'^([a-z_]+):', l)
        if m and m.group(1) in strip:
            continue
        out.append(l)
    open(d, "w").write("".join(out))
truthy("lean doc (canon keys stripped) → story-front-matter-populated fails (full canon required, BC-13915)",
       ("story-front-matter-populated", "flow:TEAM-01") in with_mutation(lean_frontmatter))

# journey-front-matter-populated requires the ADR-033 journey canon UNCONDITIONALLY over
# ALL journeys (Q29 amendment 6 / BC-13935). A journey DOWNGRADED by dropping a canon key
# hard-fails through evaluate() at domain:<D> for a per-domain journey (journey:<stem> for an
# orphan) — the Python twin of run-audit-smoke.sh
# §2-journey (bash↔Python ORACLE). The clean fixture's journeys are full canon, so
# fails(CLEAN) is empty (§1 pins that); these mutations exercise the FAIL path without
# touching the shared broken fixture's oracle.
def lean_journey_frontmatter(r):
    import re as _re
    d = os.path.join(r, "docs/product/journeys/TEAM.md")
    t = open(d).read()
    # Drop the ADR-033 `display_name:` canon key → journey lint reports it MISSING.
    open(d, "w").write(_re.sub(r"^display_name:.*\n", "", t, count=1, flags=_re.M))
truthy("journey w/ dropped canon key (display_name) → journey-front-matter-populated fails (ADR-033, BC-13935)",
       ("journey-front-matter-populated", "domain:TEAM") in with_mutation(lean_journey_frontmatter))

def drift_journey_frontmatter(r):
    import re as _re
    d = os.path.join(r, "docs/product/journeys/TEAM.md")
    t = open(d).read()
    # Inject a DRIFT key (linear_project_id, dropped by ADR-033) INSIDE the frontmatter →
    # the gate must FAIL on drift, not just on missing (lockstep w/ the bash twin's
    # single-sourced lint_doc; a presence-only check would silently pass this).
    open(d, "w").write(_re.sub(r"^(---\n)", r"\1linear_project_id: dead-beef\n", t, count=1, flags=_re.M))
truthy("journey w/ drift key (linear_project_id) → journey-front-matter-populated fails (drift parity, BC-13148)",
       ("journey-front-matter-populated", "domain:TEAM") in with_mutation(drift_journey_frontmatter))

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
eq("broken row hard_fail count 4", broken_row["summary"]["hard_fail"], 4)
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
# the redirect gate ids evaluate() emits MUST be in VALID_GATE_IDS, else a --gate filter on
# them hits the arg-guard and returns exit-64 instead of running (BC-12907 review-fix).
for rgid in ("redirect-target-resolvable", "redirect-front-matter-valid"):
    truthy(f"{rgid} ∈ VALID_GATE_IDS", rgid in bar.VALID_GATE_IDS)
    rg = bar.decide({"id": "rg", "repo": "audit-clean-shape", "gate": rgid}, bar.Path(FIXTURES))
    truthy(f"--gate={rgid} not rejected as 64", rg["summary"]["exit_code"] != 64)
# the journey-frontmatter gate evaluate() emits MUST be in VALID_GATE_IDS, else a --gate
# filter on it hits the arg-guard and returns exit-64 instead of running (BC-13935).
truthy("journey-front-matter-populated ∈ VALID_GATE_IDS",
       "journey-front-matter-populated" in bar.VALID_GATE_IDS)
jg = bar.decide({"id": "jg", "repo": "audit-clean-shape", "gate": "journey-front-matter-populated"}, bar.Path(FIXTURES))
truthy("--gate=journey-front-matter-populated not rejected as 64", jg["summary"]["exit_code"] != 64)

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
