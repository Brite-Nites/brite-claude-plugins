#!/usr/bin/env python3
"""WS-A Linear-graph lints (A-4 / A-5 / A-6 / A-7).

Four pure detectors over a *Linear-state snapshot* (a JSON dict). Each takes the
loaded `state` (plus, for A-5, a flows directory) and returns a list of human-
readable violation strings — one per defect, empty list on clean. No I/O side
effects beyond reading story-doc files for A-5.

These lints need *Linear* data, which a bash/python script cannot fetch itself.
The data-flow mirrors the `cross-domain-deps-bidirectional` gate (BC-10729):

  - **CI / tests** feed a synthetic `linear-state-mock.json` fixture (see
    `tests/fixtures/synthetic-linear-graph/`).
  - **WS-E remediation / live `/flow:audit` Phase C** fetch real Linear state via
    MCP (`list_issues({label:"domain:<slug>"})` per domain for titles/labels/
    parentId/projectMilestone, plus a per-parent `get_issue(includeRelations)` for
    blockedBy), serialize it to the SAME schema, then run this lib.

The serialize contract (the exact MCP→JSON mapping) is documented in
`tests/fixtures/synthetic-linear-graph/README.md`.

Snapshot schema
---------------
    {
      "parents": {
        "<issue-id>": {
          "flow_id":   "<domain>-NN" | "<domain>/<slug>",
          "domain":    "<domain-slug>",
          "title":     "<DOMAIN-NN: ...>",
          "milestone": "<milestone name>" | null,
          "blockedBy": ["<issue-id>", ...],
          "labels":    ["type:parent", "domain:<slug>", ...]
        }, ...
      },
      "children": {
        "<issue-id>": {
          "parent":    "<parent-issue-id>",
          "title":     "[Story|Eng|Design|QA|Docs] <DOMAIN-NN ...>",
          "milestone": "<milestone name>" | null,
          "labels":    ["type:story", "domain:<slug>", ...]
        }, ...
      }
    }

Scope notes (decided with the maintainer)
------------------------------------------
- **A-4** flags only a *contradictory* `type:*` label (a child whose present
  discipline label disagrees with its `[Discipline]` title prefix — e.g.
  brite-supply's 33 `[Design]` children carrying `type:eng`). A child *missing*
  its expected `type:*` label is left to `verify-linear-references.mts`
  (`fda-child-missing-type-label`), which already FAILs that case — A-4 does not
  re-report it.
- **A-5** reuses the cross-domain-deps bidirectional predicate verbatim: it
  compares the structured `## Cross-domain dependencies` story-doc section
  against cross-domain Linear `blockedBy` edges. It does NOT scan free prose.

python3 3.6+. Stdlib only.
"""

import json
import re
import sys
from pathlib import Path

# ── Canonical discipline mapping (Q24 mod 3 + templates/scripts/lib/fda-title.mts)
# Title-prefix discipline token -> the `type:<x>` label it must carry.
TITLE_DISCIPLINE_TO_TYPE = {
    "Story": "type:story",
    "Eng": "type:eng",
    "Design": "type:design",
    "QA": "type:qa",
    "Docs": "type:docs",
}

# Canonical FDA discipline-child title shapes, mirroring fda-title.mts's
# LEADING_BRACKET_CHILD / TRAILING_BRACKET_CHILD: the `[Discipline]` tag is
# ANCHORED to the title start and bound to a DOMAIN-NN code — it is NOT matched
# anywhere in prose. This deliberately rejects non-FDA issues that merely mention
# a discipline in brackets ("[Frontend Handoff] …", "[Rework: eng] …", "Audit
# [Design] consistency"), exactly as fda-title.mts excludes them — keeping A-4/A-7
# aligned with the verify-linear-references.mts FDA-shape boundary instead of
# firing on prose brackets. (FDA_DOMAINS membership is the one fda-title.mts gate
# not replicated here — this lib carries no per-project domain list; the DOMAIN-NN
# anchor alone removes the prose/handoff false positives.)
_LEADING_CHILD_RE = re.compile(r"^\[(Story|Eng|Design|QA|Docs)\]\s+[A-Z]+-\d{1,3}[:\s]")
_TRAILING_CHILD_RE = re.compile(r"^[A-Z]+-\d{1,3}\s+\[(Story|Eng|Design|QA|Docs)\]")

# Cross-domain-deps doc parse (identical shape to run-cross-domain-deps-vslice.sh).
_SECTION_RE = re.compile(
    r"(?ms)^##\s+Cross-domain\s+dependencies\s*\n(.*?)(?=^##\s|\Z)"
)
_BULLET_RE = re.compile(
    r"^\s*[-*]\s+([a-z0-9][a-z0-9\-]*-\d+)\s+(blockedBy|gates)\s+([a-z0-9][a-z0-9\-]*-\d+)\b"
)


def load_state(path):
    """Load a Linear-state snapshot JSON file into a dict."""
    # Explicit utf-8: real consumer docs + these fixtures carry em-dashes/smart
    # quotes; Path.read_text() defaults to the locale encoding, which is ASCII
    # under LC_ALL=C on the python3 3.6/3.7 floor → UnicodeDecodeError.
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _discipline_of(title):
    """The discipline of a CANONICAL FDA child title, or None if not FDA-shaped.

    Mirrors fda-title.mts: a leading `[Disc] DOMAIN-NN …` or a trailing
    `DOMAIN-NN [Disc]` bracket only. A discipline mentioned in prose elsewhere in
    the title (a handoff/rework issue, a body cross-reference) does not count and
    yields None — so A-4/A-7 never classify a non-FDA issue as a discipline child.
    """
    if not title:
        return None
    m = _LEADING_CHILD_RE.match(title) or _TRAILING_CHILD_RE.match(title)
    return m.group(1) if m else None


def _type_labels(labels):
    """The `type:*` labels on an issue, excluding the parent marker."""
    return [l for l in (labels or []) if l.startswith("type:") and l != "type:parent"]


# ── A-4: label ↔ title-prefix contamination (contradictory label only) ────────
def detect_label_contamination(state):
    """A `[Discipline]` child carrying a `type:*` label for a DIFFERENT discipline.

    Catches brite-supply's `[Design]` → `type:eng` bug. A child *missing* its
    expected label (no contradictory label present) is NOT reported here — that
    is `verify-linear-references.mts`'s `fda-child-missing-type-label` gate.
    """
    out = []
    children = state.get("children", {})
    for cid in sorted(children):
        child = children[cid]
        discipline = _discipline_of(child.get("title", ""))
        if discipline is None:
            continue  # not a discipline-tagged child by title; A-4 N/A
        expected = TITLE_DISCIPLINE_TO_TYPE[discipline]
        present = _type_labels(child.get("labels", []))
        wrong = [l for l in present if l != expected]
        if wrong:
            out.append(
                "{cid} '{title}' is tagged [{disc}] but carries {wrong} "
                "(expected {exp})".format(
                    cid=cid,
                    title=child.get("title", ""),
                    disc=discipline,
                    wrong=", ".join(sorted(wrong)),
                    exp=expected,
                )
            )
    return out


# ── A-5: blockedBy-wiring (prose ↔ Linear) — reuse cross-domain-deps predicate ─
def _linear_cross_domain_pairs(parents):
    """Cross-domain Linear blockedBy edges as (this_flow_id, blocker_flow_id).

    Same-domain siblings and blockedBy pointing at non-FDA-parent issues are
    excluded — identical to the cross-domain-deps gate.
    """
    pairs = set()
    for p in parents.values():
        this_fid = p.get("flow_id")
        this_domain = p.get("domain")
        for blocker_id in p.get("blockedBy", []) or []:
            blocker = parents.get(blocker_id)
            if blocker is None:
                continue  # blockedBy a non-FDA-parent issue; excluded
            if blocker.get("domain") == this_domain:
                continue  # same-domain sibling; tracked via related_flows
            blocker_fid = blocker.get("flow_id")
            if not this_fid or not blocker_fid:
                # A parent with no resolvable flow_id (serializer couldn't key it
                # to a master-flow-inventory row) is an A-8 inventory concern, not
                # a cross-domain wiring defect — excluding it keeps A-5 from
                # emitting a meaningless "None blockedBy …" pair.
                continue
            pairs.add((this_fid, blocker_fid))
    return pairs


def _doc_cross_domain_pairs(flows_dir):
    """Doc-side `## Cross-domain dependencies` bullets as (this_fid, blocker_fid)."""
    pairs = set()
    flows_root = Path(flows_dir)
    if not flows_root.exists():
        return pairs
    for doc_path in sorted(flows_root.rglob("*.md")):
        if doc_path.name == "INDEX.md":
            continue
        # A stray non-UTF-8 / unreadable .md in an arbitrary consumer repo must not
        # abort the whole A-5 pass with a traceback — skip it.
        try:
            text = doc_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        match = _SECTION_RE.search(text)
        if not match:
            continue
        for line in match.group(1).splitlines():
            m = _BULLET_RE.match(line)
            if not m:
                continue
            this_fid, verb, other_fid = m.group(1), m.group(2), m.group(3)
            if verb == "blockedBy":
                pairs.add((this_fid, other_fid))
            else:  # gates is the inverse view: this_fid blocks other_fid
                pairs.add((other_fid, this_fid))
    return pairs


def detect_blockedby_wiring(state, flows_dir):
    """Bidirectional mirror between doc cross-domain deps and Linear blockedBy.

    Returns nothing when `flows_dir` is None/absent (A-5 cannot evaluate without
    the doc side; the runner skips it). Otherwise flags both halves:
      - doc bullet with no matching Linear blockedBy edge (prose-only, never wired)
      - Linear blockedBy edge with no matching doc bullet
    """
    if not flows_dir:
        return []
    parents = state.get("parents", {})
    linear_pairs = _linear_cross_domain_pairs(parents)
    doc_pairs = _doc_cross_domain_pairs(flows_dir)

    out = []
    for this_fid, blocker_fid in sorted(doc_pairs - linear_pairs):
        out.append(
            "doc says '{a}' blockedBy '{b}' but no cross-domain Linear blockedBy "
            "edge exists (prose-only — never wired)".format(a=this_fid, b=blocker_fid)
        )
    for this_fid, blocker_fid in sorted(linear_pairs - doc_pairs):
        out.append(
            "Linear has '{a}' blockedBy '{b}' but no '## Cross-domain dependencies' "
            "doc bullet mirrors it".format(a=this_fid, b=blocker_fid)
        )
    return out


# ── A-6: child-milestone-inheritance ──────────────────────────────────────────
def detect_milestone_inheritance(state):
    """Every child must have a milestone matching its parent's.

    Flags: a parent with no milestone (no inheritance source), a child with no
    milestone (NO_MILESTONE — brite-supply's 141/208), and a child whose
    milestone differs from its parent's.
    """
    out = []
    parents = state.get("parents", {})
    children = state.get("children", {})

    for pid in sorted(parents):
        if not parents[pid].get("milestone"):
            out.append(
                "parent {pid} '{title}' has no milestone (cannot anchor child "
                "inheritance)".format(pid=pid, title=parents[pid].get("title", ""))
            )

    for cid in sorted(children):
        child = children[cid]
        cm = child.get("milestone")
        title = child.get("title", "")
        if not cm:
            out.append(
                "child {cid} '{title}' has no milestone (NO_MILESTONE)".format(
                    cid=cid, title=title
                )
            )
            continue
        parent_id = child.get("parent")
        parent = parents.get(parent_id) if parent_id else None
        if parent is None:
            continue  # parent wiring is verify-linear-references.mts territory
        pm = parent.get("milestone")
        if pm and cm != pm:
            out.append(
                "child {cid} '{title}' milestone '{cm}' != parent {pid} "
                "milestone '{pm}'".format(
                    cid=cid, title=title, cm=cm, pid=parent_id, pm=pm
                )
            )
    return out


# ── A-7: duplicate-discipline-child ───────────────────────────────────────────
def detect_duplicate_discipline_child(state):
    """A sub-flow parent should have exactly one child per discipline.

    Catches DRO-586/588 (both `[Design] Error Pages` under one parent). Children
    whose title has no parseable discipline tag are skipped (can't classify).
    """
    out = []
    parents = state.get("parents", {})
    children = state.get("children", {})

    # parent_id -> discipline -> [child_id, ...]
    by_parent = {}
    for cid in sorted(children):
        child = children[cid]
        discipline = _discipline_of(child.get("title", ""))
        if discipline is None:
            continue
        parent_id = child.get("parent")
        if not parent_id:
            continue
        by_parent.setdefault(parent_id, {}).setdefault(discipline, []).append(cid)

    for parent_id in sorted(by_parent):
        for discipline in sorted(by_parent[parent_id]):
            ids = by_parent[parent_id][discipline]
            if len(ids) > 1:
                ptitle = parents.get(parent_id, {}).get("title", "")
                out.append(
                    "parent {pid} '{ptitle}' has {n} [{disc}] children ({ids}) "
                    "— expected exactly one per discipline".format(
                        pid=parent_id,
                        ptitle=ptitle,
                        n=len(ids),
                        disc=discipline,
                        ids=", ".join(ids),
                    )
                )
    return out


# ── Orchestration ─────────────────────────────────────────────────────────────
# (code, label, needs_flows_dir)
_LINTS = [
    ("A-4", "label↔title-prefix contamination", False),
    ("A-5", "blockedBy-wiring (doc ↔ Linear)", True),
    ("A-6", "child-milestone-inheritance", False),
    ("A-7", "duplicate-discipline-child", False),
]


def run_all(state, flows_dir=None):
    """Return an ordered dict-like list of (code, label, [violations]) tuples."""
    results = []
    results.append(("A-4", _LINTS[0][1], detect_label_contamination(state)))
    results.append(("A-5", _LINTS[1][1], detect_blockedby_wiring(state, flows_dir)))
    results.append(("A-6", _LINTS[2][1], detect_milestone_inheritance(state)))
    results.append(("A-7", _LINTS[3][1], detect_duplicate_discipline_child(state)))
    return results


def main(argv):
    if not argv:
        sys.stderr.write(
            "usage: flow_linear_lint.py <linear-state.json> [flows-dir]\n"
        )
        return 2
    state_path = argv[0]
    flows_dir = argv[1] if len(argv) > 1 else None
    try:
        state = load_state(state_path)
    except (OSError, ValueError, RecursionError) as exc:
        # ValueError covers JSON decode errors; RecursionError covers pathologically
        # nested JSON. A type-confused-but-parseable snapshot is shape-checked below.
        sys.stderr.write("FATAL: could not load state '{}': {}\n".format(state_path, exc))
        return 2
    # Shape guard: detectors index parents/children as dicts. A malformed snapshot
    # (e.g. "parents": [...]) would otherwise crash a detector with a TypeError
    # mid-run; fail cleanly with the same exit-2 "unusable state" contract instead.
    if not isinstance(state, dict) \
       or not isinstance(state.get("parents", {}), dict) \
       or not isinstance(state.get("children", {}), dict):
        sys.stderr.write(
            "FATAL: malformed state '{}': 'parents' and 'children' must be objects\n".format(state_path)
        )
        return 2

    total = 0
    for code, label, violations in run_all(state, flows_dir):
        if code == "A-5" and not flows_dir:
            print("→ {code} {label}: SKIP (no flows-dir given)".format(code=code, label=label))
            continue
        print("→ {code} {label}".format(code=code, label=label))
        for v in violations:
            print("  {}".format(v))
            total += 1

    if total == 0:
        print("✓ Linear-graph lints clean")
        return 0
    print("✗ {} Linear-graph-lint violation(s)".format(total))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
