#!/usr/bin/env python3
"""WS-A frontmatter-schema lint (A-10 story / A-11 journey) — BC-12572.

The RETENTION half of the FDA frontmatter work. BC-13168 (story builder) +
BC-13028 (journey builder) made fresh scaffolds EMIT the canonical frontmatter;
this lint keeps docs on that canon afterward — it names drift the existing audit
gate could only ever report as "key missing". Two pure detectors over a single
doc's first `---` block; key-level only (values are BC-12692's territory).

Three severity classes (the runner + main map these to exit codes):
  DRIFT_KEY    a wrong-name key impersonating a canonical one (`sub_flow_id` for
               `flow_id`, `linear_parent` for `parent_issue`, singular `persona`
               for `personas`, journey `milestone` for `linear_milestone`, the
               ADR-033-dropped `linear_project_id`). LOUD (exit 1). Flags even
               when the canonical twin is ALSO present — the stale duplicate is a
               fork in the road (brite-roster carries `linear_parent` alongside
               `parent_issue` on all 41 docs; the next editor updates one, not both).
  MISSING_KEY  a canonical key absent — including a nested slot (`children.qa`,
               `linear_milestone.id`). LOUD (exit 1). Honest-empty PASSES:
               `personas: []` / `qa_last_signed_off: null` are PRESENT. Presence,
               never non-emptiness. A doc with no frontmatter block at all yields a
               single MISSING_KEY (not 20) — and never a traceback.
  UNKNOWN_KEY  an off-canon extra (`title`, `slug`, `agent_context`, and
               `display_name` ON A STORY DOC — it is canonical on journeys, mere
               luggage on stories). QUIET (printed, exit 0): extras never broke a
               reading robot the way wrong names did. ADR-033's blessed journey
               extras (`l2_reviewed`, `related_domains`, primary/secondary personas)
               are SILENTLY allowlisted — warning on every GOLD journey is noise.

The canonical key sets are HARDCODED here (ADR-029 story / ADR-033 journey +
the job-story / domain-journey templates) and ASSERTED against the fixture-locked
builder goldens by the vslice (`run-flow-frontmatter-lint-vslice.sh`) — so a builder
canon change this lint doesn't track reds CI. (The lock is against the committed
goldens, which are themselves pinned to the builders by their own vslices — so the
builder↔lint chain is transitive, not a single-test guarantee.)

The frontmatter parser is twin-copied from
build_journey_frontmatter.py._parse_frontmatter (the proven in-repo reference),
EXTENDED to descend into the indented `children:` / `linear_milestone:` mappings
the builder version deliberately ignores. Duplicated per the house twin-helper
rule — NOT cross-imported (the builders and the lint have independent lifecycles).

python3 3.6+. Stdlib only.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# ── Canonical key sets ────────────────────────────────────────────────────────
# Story (ADR-029 + templates/docs/templates/job-story.md). Order is the template's
# emission order; the lint enforces the SET, not the order (hand-edited GOLD docs
# legitimately reorder — locked by a vslice assertion).
STORY_CANON = (
    "flow_id", "domain", "status", "parent_issue", "children", "personas",
    "related_flows", "figma", "sandbox_url", "staging_url", "real_app_url",
    "e2e_test", "user_docs_url", "qa_status", "qa_last_signed_off", "eng_status",
    "design_status", "docs_status", "intent", "last_reviewed",
)
STORY_CHILDREN_SLOTS = ("story", "engineering", "design", "qa", "docs")

# Journey (ADR-033 + templates/docs/templates/domain-journey.md).
JOURNEY_CANON = (
    "domain", "display_name", "linear_milestone", "personas", "flow_ids_in_scope",
    "status", "figma", "intent", "last_reviewed",
)
JOURNEY_MILESTONE_SUBKEYS = ("name", "id")

# ── Drift maps (wrong-name key → its remediation hint) ────────────────────────
# Grounded in the live census of all 7 WS-E consumer repos, not invented:
# brand-hub (sub_flow_id/linear_parent/linear_children), brite-roster + brite-labs
# (singular persona, linear_parent), brite-supply-react (sub_flow_id /
# linear_parent_issue), brite-pim (linear_parent). The value is the full remediation
# hint INCLUDING the verb (`use <canon>` for a rename, `drop …` for a removed key),
# emitted verbatim after `<key> → ` — so a drop-only key (`linear_project_id`, which
# ADR-033 deleted with no replacement) doesn't read as the nonsensical "use (dropped)".
STORY_DRIFT = {
    "sub_flow_id": "use flow_id",
    "linear_parent": "use parent_issue",
    "linear_parent_issue": "use parent_issue",
    "linear_children": "use children",
    "persona": "use personas",
}
# Journey drift: `milestone:`/`milestone_name:`/`linear_milestone_name:` predate the
# ADR-033 nested `linear_milestone: {name, id}`; `linear_project_id` was DROPPED by
# ADR-033 (zero consumers) — brand-hub's 10 journeys still carry it.
JOURNEY_DRIFT = {
    "milestone": "use linear_milestone",
    "milestone_name": "use linear_milestone.name",
    "linear_milestone_name": "use linear_milestone.name",
    "linear_project_id": "drop (removed per ADR-033, no replacement)",
}
# ADR-033 § "real-doc extras tolerated, not canon" — silently allowed on journeys.
JOURNEY_TOLERATED = frozenset(
    {"l2_reviewed", "related_domains", "primary_persona", "secondary_personas"})

# Frontmatter line shapes (top-level `key: value`; indented sub-`key:` one level in).
# Keys are snake_case/underscore per the FDA canon + the observed drift census across
# all 7 WS-E repos (`sub_flow_id`, `linear_parent`, `persona`, …) — all snake_case. A
# hypothetical kebab drift key (`sub-flow-id`) is out of the current census: it matches
# neither regex, so it's dropped from `present` and surfaces only via the canonical key
# it displaces going MISSING (the doc still reds — just without the precise drift hint).
_KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):(.*)$")
_SUBKEY_RE = re.compile(r"^(\s+)([A-Za-z_][A-Za-z0-9_]*):(.*)$")


def parse_frontmatter(text):
    """The first `---` block → {"present": [top-level keys, in order],
    "nested": {parent_key: [sub-keys]}}; None if no closed frontmatter block.

    Line-based (stdlib has no YAML), twin-copied from
    build_journey_frontmatter.py._parse_frontmatter and EXTENDED: where the builder
    version drops indented mappings, this one records each top-level `key:`-with-no-
    inline-value's immediately-indented `sub_key:` lines under `nested[key]`. Good
    enough for the two nested canon shapes (`children:`, `linear_milestone:`); it is
    a schema-key extractor, not a YAML loader. `present` preserves order + duplicates
    so a drift key alongside its canonical twin is visible to the caller.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    present = []
    nested = {}
    parent = None  # the most recent top-level key opening an indented block
    closed = False
    for raw in lines[1:]:
        if raw.strip() == "---":
            closed = True
            break
        if not raw.strip():
            continue
        sub = _SUBKEY_RE.match(raw)
        if sub and parent is not None:
            nested.setdefault(parent, []).append(sub.group(2))
            continue
        top = _KEY_RE.match(raw)
        if not top:
            parent = None
            continue
        key, rest = top.group(1), top.group(2).strip()
        present.append(key)
        # A top-level key with no inline value opens a potential nested block
        # (`children:` / `linear_milestone:`); one with a value (scalar or `[...]`)
        # closes any open block.
        parent = key if rest == "" else None
    if not closed:
        return None
    return {"present": present, "nested": nested}


def _lint(present, nested, canon, drift_map, nested_spec, tolerated, doc_type):
    """Core set-diff over parsed keys → {drift, missing, unknown} string lists."""
    present_set = set(present)
    drift, missing, unknown = [], [], []

    # DRIFT — a wrong-name key present (flagged even if its canonical twin is too).
    seen_drift = set()
    for key in present:
        if key in drift_map and key not in seen_drift:
            seen_drift.add(key)
            # drift_map value already carries the verb (`use <canon>` / `drop …`).
            drift.append("{k} → {hint}".format(k=key, hint=drift_map[key]))

    # MISSING — a canonical top-level key absent; if present-but-nested, descend.
    for key in canon:
        if key not in present_set:
            missing.append("{k} (canonical {dt} key absent)".format(k=key, dt=doc_type))
            continue
        subkeys = nested_spec.get(key)
        if subkeys:
            have = set(nested.get(key, []))
            for sk in subkeys:
                if sk not in have:
                    missing.append("{k}.{sk} (nested canonical key absent)".format(k=key, sk=sk))

    # UNKNOWN — an off-canon extra that is neither canonical nor a known drift key
    # nor an explicitly-tolerated extra. Quiet (exit 0).
    canon_set = set(canon)
    seen_unknown = set()
    for key in present:
        if key in canon_set or key in drift_map or key in tolerated:
            continue
        if key in seen_unknown:
            continue
        seen_unknown.add(key)
        unknown.append(key)

    return {"drift": drift, "missing": missing, "unknown": unknown}


# Only the leading frontmatter block is ever inspected, so a doc with a huge body
# (or a pathological never-closed block) must not be slurped whole — bound the read
# to the frontmatter region (open + close fence) or this many lines, whichever comes
# first, so the linter can't OOM on an accidentally-committed multi-MB file.
_MAX_FRONTMATTER_LINES = 10000


def _read_frontmatter_text(p):
    """Read `p` up to the close of its leading `---` block (or _MAX_FRONTMATTER_LINES),
    never the whole file. Bounds memory on a huge/unterminated doc; the truncated text
    re-parses identically (parse_frontmatter only reads the leading block)."""
    out = []
    dashes = 0
    with p.open(encoding="utf-8", errors="replace") as fh:
        for i, line in enumerate(fh):
            out.append(line)
            if line.strip() == "---":
                dashes += 1
                if dashes >= 2:  # opening + closing fence seen → frontmatter complete
                    break
            if i + 1 >= _MAX_FRONTMATTER_LINES:
                break
    return "".join(out)


def lint_text(text, doc_type):
    """Lint already-read frontmatter `text` → {"drift": [...], "missing": [...],
    "unknown": [...]}. The text-accepting core; callers holding the doc bytes (the
    audit gate) use this to avoid a re-read. Never raises on doc CONTENT — a doc with
    no frontmatter block degrades to a single MISSING_KEY (not 20, not a traceback),
    keeping the pure-detector-crash-on-malformed-input class (4 prior instances) shut.
    Raises ValueError only on a programmer-error `doc_type` (a caller bug, not content)."""
    parsed = parse_frontmatter(text)
    if parsed is None:
        return {"drift": [], "missing": ["<no frontmatter block>"], "unknown": []}
    if doc_type == "story":
        return _lint(parsed["present"], parsed["nested"], STORY_CANON, STORY_DRIFT,
                     {"children": STORY_CHILDREN_SLOTS}, frozenset(), "story")
    if doc_type == "journey":
        return _lint(parsed["present"], parsed["nested"], JOURNEY_CANON, JOURNEY_DRIFT,
                     {"linear_milestone": JOURNEY_MILESTONE_SUBKEYS}, JOURNEY_TOLERATED,
                     "journey")
    raise ValueError("doc_type must be 'story' or 'journey', got {!r}".format(doc_type))


def lint_doc(path, doc_type):
    """Lint one story|journey doc by path. Bounded-reads the frontmatter region then
    delegates to lint_text. An unreadable file (incl. a directory) degrades to a single
    MISSING_KEY, never a traceback."""
    p = Path(path)
    try:
        text = _read_frontmatter_text(p)
    except OSError as exc:
        return {"drift": [], "missing": ["<unreadable: {}>".format(exc)], "unknown": []}
    return lint_text(text, doc_type)


def main(argv):
    if len(argv) < 2 or argv[0] not in ("--type",) or argv[1] not in ("story", "journey"):
        sys.stderr.write("usage: flow_frontmatter_lint.py --type {story|journey} <doc> [<doc> ...]\n")
        return 2
    doc_type = argv[1]
    docs = argv[2:]
    if not docs:
        sys.stderr.write("usage: at least one <doc> path required\n")
        return 2
    loud = 0
    for doc in docs:
        res = lint_doc(doc, doc_type)
        clean = not (res["drift"] or res["missing"] or res["unknown"])
        if clean:
            print("PASS  {}".format(doc))
            continue
        print("{}".format(doc))
        for v in res["drift"]:
            print("  DRIFT_KEY    {}".format(v))
        for v in res["missing"]:
            print("  MISSING_KEY  {}".format(v))
        for v in res["unknown"]:
            print("  UNKNOWN_KEY  {}".format(v))
        if res["drift"] or res["missing"]:
            loud += 1
    return 1 if loud else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
