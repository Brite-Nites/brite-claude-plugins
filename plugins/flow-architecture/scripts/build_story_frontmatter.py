#!/usr/bin/env python3
"""Deterministic story-doc frontmatter builder (BC-13168, BC-13028 #4 story half).

The hermetic, side-effect-free stamper `flow-doc-author` shells out to so a fresh
FDA scaffold emits POPULATED `children:` / `parent_issue` / discipline-status
story-doc frontmatter instead of the empty placeholders that shipped on every
greenfield/retrofit scaffold (the BC-11996 hand-fix that recurred). It is the
deterministic surface that makes the empty-frontmatter regression fixture-lockable
(`tests/run-story-frontmatter-vslice.sh`) — the silent-return failure mode #4 kills.

Pure function of its inputs. Reads ONLY the per-domain scaffold-log (the one clean,
standardized source — canonical table shape per `templates/.flow/scaffold-log/SCHEMA.md`,
join key = `flow_id`/`DOMAIN-NN` per ADR-029). It does NOT parse the inventory: the
inventory schema is unstandardized across consumer repos and usually lacks personas/
related_flows columns, so those (plus the inventory's idiosyncratic status taxonomy)
arrive as caller-derived params — matching BC-13028's own "pass personas via
partial_state; do the deterministic children.* substitution" framing. No Linear MCP,
no filesystem scan beyond the named scaffold-log. Stdlib-only per CLAUDE.md.

What is HARD-deterministic here (golden-locked): `parent_issue` + `children.*` from the
scaffold-log; the `qa/eng/design/docs_status` + url/figma/`intent` constants; `status`
default `NOT_STARTED`; `last_reviewed` from --as-of. What is caller-derived (the skill's
judgment, stamped deterministically when supplied, honest empty `[]` otherwise):
`--status` override (skill-side Q15.7 code-evidence), `--personas`, `--related-flows`.

Output: the `---…---` YAML frontmatter block to stdout (no body — the agent authors
`# H1` → `## QA history` per the body-only contract; the skill concatenates).

Exit codes: 0 = emitted OK; 2 = usage / unreadable scaffold-log / flow-id not present
in the log (a deliberate literal `2`, matched by the harness — not POSIX os.EX_USAGE, =64).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Canonical job-story template frontmatter key order
# (plugins/flow-architecture/templates/docs/templates/job-story.md).
TBD = "TBD"
# `DOMAIN-NN` / `BC-NNNN`: an alpha prefix + numeric suffix. `\Z` not `$` ($ matches before
# a trailing `\n` — the BC-12945 lesson). One shared pattern, two semantically-named compiled
# objects: _FLOW_ID_RE validates the --flow-id ARG (a DOMAIN-NN); _LINEAR_ID_RE validates
# scaffold-log id CELLS (a BC-NNNN) — distinct namespaces that currently share a shape and
# may diverge. Scaffold-log id cells failing _LINEAR_ID_RE degrade to TBD (not emitted raw),
# the same charset rigor the caller params get below — so a degraded cell's stray `#`/`:`/`,`
# can never malform the emitted YAML at exit 0.
_ID_PATTERN = r"^[A-Za-z]+-\d+\Z"
_FLOW_ID_RE = re.compile(_ID_PATTERN)
_LEAD_FLOW_ID_RE = re.compile(r"^([A-Za-z]+-\d+)")  # intentionally unanchored (leading token in `NN — desc`)
_AS_OF_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\Z")
_LINEAR_ID_RE = re.compile(_ID_PATTERN)
# Caller-derived enums/slugs are emitted raw into YAML, so they are validated to a
# safe charset up front (exit 2).
_STATUS_TAXONOMY = frozenset(
    {"NOT_STARTED", "IN_PROGRESS", "BUILT", "QA_SIGNED_OFF", "SHIPPED", "BLOCKED"})
_SLUG_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*\Z")
_CHILD_SLOTS = ("story", "engineering", "design", "qa", "docs")


class BuildError(Exception):
    """Usage / unreadable / flow-id-not-found → process exit 2."""


def _split_row(line: str) -> list[str]:
    """A markdown table row → its trimmed cell values (leading/trailing pipe dropped)."""
    s = line.strip()
    if not s.startswith("|"):
        return []
    return [c.strip() for c in s.strip("|").split("|")]


def _is_separator(cells: list[str]) -> bool:
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c or "") for c in cells)


def _clean_id(cell: str) -> str:
    """A scaffold-log identifier cell → a validated Linear id (`BC-NNNN` shape), or TBD
    for an empty / errored / `—` / otherwise non-conforming cell. Anything that is not a
    clean Linear id degrades to TBD rather than being emitted raw — so a degraded cell
    (e.g. `err: rate-limited` left by a failed write) can never malform the YAML."""
    val = cell.strip("`").strip()
    return val if _LINEAR_ID_RE.match(val) else TBD


def _parse_scaffold_log(text: str, flow_id: str) -> tuple[str, dict[str, str]]:
    """Return (parent_issue, children{slot->BC}) for flow_id from the log's tables.

    Parents table rows have 4 cells: `# | Sub-flow | Linear identifier | Result`, where
    Sub-flow is `DOMAIN-NN — <desc> [<annot>]`. Discipline-children rows have 7 cells:
    `Sub-flow | Story | Engineering | Design | QA | Docs | Result`, where Sub-flow is the
    bare `DOMAIN-NN`. BOTH Sub-flow columns are matched by extracting the leading flow-id
    token (backticks stripped first), so a `` `DOMAIN-NN` `` or `DOMAIN-NN — desc` cell
    still matches — never a silent all-`TBD` miss. Header/separator/milestone rows never
    yield a matching leading token, so they fall through. The `Result` column is
    informational-only (never parsed); duplicate rows for one flow_id resolve last-wins
    (an idempotent in-place rewrite per SCHEMA.md).
    """
    parent = TBD
    children = {slot: TBD for slot in _CHILD_SLOTS}
    found = False
    for line in text.splitlines():
        cells = _split_row(line)
        if not cells or _is_separator(cells):
            continue
        if len(cells) == 7:  # discipline-children row
            m = _LEAD_FLOW_ID_RE.match(cells[0].strip("`").strip())
            if m and m.group(1) == flow_id:
                for i, slot in enumerate(_CHILD_SLOTS, start=1):
                    children[slot] = _clean_id(cells[i])
                found = True
        elif len(cells) == 4:  # parents row: # | Sub-flow | Linear identifier | Result
            m = _LEAD_FLOW_ID_RE.match(cells[1].strip("`").strip())
            if m and m.group(1) == flow_id:
                parent = _clean_id(cells[2])
                found = True
    if not found:
        raise BuildError(f"flow-id {flow_id!r} not present in the scaffold-log")
    return parent, children


def _yaml_list(values: list[str]) -> str:
    """Flow-style YAML list matching the job-story template (`[a, b]` / `[]`)."""
    return "[" + ", ".join(values) + "]"


def _emit(flow_id: str, parent: str, children: dict[str, str], status: str,
          personas: list[str], related_flows: list[str], as_of: str) -> str:
    domain = flow_id.split("-", 1)[0]  # flow_id is pre-validated to DOMAIN-NN in main()
    lines = [
        "---",
        f"flow_id: {flow_id}",
        f"domain: {domain}",
        f"status: {status}",
        f"parent_issue: {parent}",
        "children:",
        f"  story: {children['story']}",
        f"  engineering: {children['engineering']}",
        f"  design: {children['design']}",
        f"  qa: {children['qa']}",
        f"  docs: {children['docs']}",
        f"personas: {_yaml_list(personas)}",
        f"related_flows: {_yaml_list(related_flows)}",
        "figma: TBD",
        "sandbox_url: TBD",
        "staging_url: TBD",
        "real_app_url: TBD",
        "e2e_test: TBD",
        "user_docs_url: TBD",
        "qa_status: not-tested",
        "qa_last_signed_off: null",
        "eng_status: not-started",
        "design_status: not-started",
        "docs_status: not-started",
        "intent: ../../intent.md",
        f"last_reviewed: {as_of}",
        "---",
    ]
    return "\n".join(lines) + "\n"


def _emit_redirect(flow_id: str, redirect_to: str, as_of: str) -> str:
    """Minimal redirect-stub frontmatter (BC-12907 / REDIRECT_CANON): an intentional
    alias to `redirect_to`'s canonical home. No children / story / status keys — the
    audit applies the redirect-validation profile (resolvable pointer + these keys) and
    skips the story-frame / gherkin / children gates for it."""
    domain = flow_id.split("-", 1)[0]
    return "\n".join([
        "---",
        f"flow_id: {flow_id}",
        f"domain: {domain}",
        "doc_type: redirect",
        f"redirect_to: {redirect_to}",
        "intent: ../../intent.md",
        f"last_reviewed: {as_of}",
        "---",
    ]) + "\n"


def _csv(value: str | None) -> list[str]:
    # NB: items are .strip()'d here, BEFORE _SLUG_RE runs in main() — so _SLUG_RE's
    # `\Z` anchor is belt-and-suspenders for the slug path (the real interior-metachar
    # guard is the charset). The `\Z` IS the primary guard on --flow-id / --as-of.
    if not value:
        return []
    return [v.strip() for v in value.split(",") if v.strip()]


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        prog="build_story_frontmatter.py",
        description="Stamp deterministic story-doc frontmatter from a scaffold-log.")
    p.add_argument("--scaffold-log", type=Path,
                   help="required for --doc-type=story; not needed for redirect")
    p.add_argument("--flow-id", required=True)
    p.add_argument("--doc-type", default="story", choices=("story", "redirect"),
                   help="story (default) or redirect — an intentional alias stub (BC-12907)")
    p.add_argument("--redirect-to", default="",
                   help="for --doc-type=redirect: the canonical flow_id this aliases (DOMAIN-NN)")
    p.add_argument("--as-of", required=True, help="ISO date for last_reviewed (defeats now())")
    p.add_argument("--status", default="NOT_STARTED",
                   help="story-doc status (skill passes code-evidence result; default NOT_STARTED)")
    p.add_argument("--personas", default="", help="comma-separated role slugs (caller-derived)")
    p.add_argument("--related-flows", default="", help="comma-separated DOMAIN-NN ids (caller-derived)")
    args = p.parse_args(argv)

    if not _FLOW_ID_RE.match(args.flow_id):
        print(f"usage: --flow-id must be DOMAIN-NN, got {args.flow_id!r}", file=sys.stderr)
        return 2
    if not _AS_OF_RE.match(args.as_of):
        print(f"usage: --as-of must be YYYY-MM-DD, got {args.as_of!r}", file=sys.stderr)
        return 2
    if args.doc_type == "redirect":
        # Redirect stub (BC-12907): a minimal alias marker, no scaffold-log / children.
        if not _FLOW_ID_RE.match(args.redirect_to or ""):
            print(f"usage: --doc-type=redirect requires --redirect-to as a DOMAIN-NN flow_id, "
                  f"got {args.redirect_to!r}", file=sys.stderr)
            return 2
        sys.stdout.write(_emit_redirect(args.flow_id, args.redirect_to, args.as_of))
        return 0
    if args.scaffold_log is None:
        print("usage: --scaffold-log is required for --doc-type=story", file=sys.stderr)
        return 2
    if args.status not in _STATUS_TAXONOMY:
        print(f"usage: --status must be one of {sorted(_STATUS_TAXONOMY)}, got {args.status!r}",
              file=sys.stderr)
        return 2
    personas = _csv(args.personas)
    related_flows = _csv(args.related_flows)
    bad = [v for v in personas + related_flows if not _SLUG_RE.match(v)]
    if bad:
        print(f"usage: --personas/--related-flows items must be slugs "
              f"[A-Za-z0-9][A-Za-z0-9_-]* (first char alphanumeric), got {bad!r}",
              file=sys.stderr)
        return 2
    try:
        text = args.scaffold_log.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"usage: cannot read scaffold-log {args.scaffold_log}: {e}", file=sys.stderr)
        return 2
    try:
        parent, children = _parse_scaffold_log(text, args.flow_id)
    except BuildError as e:
        print(f"usage: {e}", file=sys.stderr)
        return 2

    sys.stdout.write(_emit(
        args.flow_id, parent, children, args.status, personas, related_flows, args.as_of))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
