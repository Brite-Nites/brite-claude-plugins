#!/usr/bin/env python3
"""WS-A persona-exists lint (BC-12573).

The deterministic FLOOR of the 3-layer persona system: existence (here — binary,
HARD) + LLM persona-resolution (quality-reviewer, post-#502) + LLM persona-depth
(Lane B C2). For each story doc, every NON-EMPTY `personas:` front-matter slug must
resolve to an existing `docs/product/personas/<slug>.md`. Honest-empty PASSES:
`personas: []` / absent / null is persona-less by design — presence is the
front-matter lint's job (BC-12572); this lint checks that a NAMED slug RESOLVES on
disk. Distinct from WS-A A-2 GENERIC_PERSONA (which checks the persona isn't a
generic project-wide default) — this checks it EXISTS.

Convention (ADR-041): `personas:` is behavioral persona-doc slugs ONLY; RBAC / access
roles are not personas and do not belong in the field. An off-canon consumer (e.g.
brite-lseo's uppercase RBAC enums) CONVERGES; the lint does not carve to tolerate them.

REFRAME (BC-13916 precedent — a falsified-premise ticket re-framed and documented so
it is not re-discovered cold). The ticket bundled persona-exists with a
journey-exists check; journey-exists is ALREADY covered and is NOT re-implemented:

  * "every domain has its journey" → the audit-manifest `journey-complete` gate
    already asserts `docs/product/journeys/<domain>.md` exists per domain.
  * "a story's parent-journey link resolves" → the CI runner's `link-resolution`
    gate already asserts every body `](<path>.md)` link resolves on disk, and the
    parent-journey reference IS such a body link.
  * the only net-new journey sliver (asserting a parent-journey link is PRESENT) is
    deliberately DROPPED: real consumers diverge on its form (brand-hub 51/51 use a
    `- Parent journey: [...]` list line; brite-supply-react 0/32 use a prose
    blockquote variant), so a deterministic presence check keyed on line-form would
    false-fail brite-supply-react, and recognizing the link across prose/bold/list
    forms is the LLM layer's job, not a deterministic floor.

So BC-12573 collapses to pure persona-exists. The persona path convention
`docs/product/personas/<slug>.md` (+ sibling INDEX.md) is G1-locked and verified on
brite-supply-react (installer.md, commercial-buyer.md).

Runner: scripts/flow-persona-lint.sh. Test surface:
tests/run-flow-persona-lint-vslice.sh.

python3 3.6+ (no `from __future__ import annotations` — 3.7+; not needed). Stdlib only.
"""
import re
import sys
from pathlib import Path


def _read(p) -> str:
    return Path(p).read_text(encoding="utf-8", errors="replace")


def _frontmatter_block(text: str) -> str:
    """Text between the opening `---` (line 1) and the next `---`; '' if the doc does
    not open with a front-matter fence or it is unterminated. Twin of the minimal
    parser in flow_evidence_lint / build_journey_frontmatter (house twin-helper rule —
    independent lifecycle, not cross-imported)."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return ""
    out = []
    for ln in lines[1:]:
        if ln.strip() == "---":
            return "\n".join(out)
        out.append(ln)
    return ""


def _flow_index_skipped(text: str) -> bool:
    return bool(re.search(r"^flow_index:\s*[\"']?skip[\"']?\s*$",
                          _frontmatter_block(text), re.M))


def _is_story_doc(text: str) -> bool:
    """A doc is a story doc iff its front-matter declares a flow-ID-family key
    (`flow_id` / `sub_flow_id` / `fda_sub_flow_id`) — mirrors the inventory-lint
    family (`_fil_doc_ids`). A co-located overview / support doc (or a fenced
    `personas:` example) without one of these keys is NOT a story doc and is not
    persona-linted."""
    fm = _frontmatter_block(text)
    return bool(re.search(r"^(flow_id|sub_flow_id|fda_sub_flow_id):\s*\S+", fm, re.M))


def _story_docs(repo: Path) -> list:
    """Story docs under docs/product/flows, recursively (matches the inventory-lint
    family). A doc counts only if it carries a flow-ID-family front-matter key
    (`_is_story_doc`) — INDEX.md, `flow_index: skip` overview docs, and co-located
    non-story support docs are excluded, so a support doc that merely mentions
    `personas:` is never persona-linted."""
    base = repo / "docs" / "product" / "flows"
    if not base.is_dir():
        return []
    docs = []
    for p in sorted(base.rglob("*.md")):
        if p.name == "INDEX.md":
            continue
        text = _read(p)
        if _flow_index_skipped(text):
            continue
        if not _is_story_doc(text):
            continue
        docs.append(p)
    return docs


def _clean_slug(s: str) -> str:
    """Normalize one persona list entry to its slug. Strips quotes/backticks and a
    trailing parenthetical qualifier — some repos annotate an entry as
    `installer (primary)` / `SYSTEM (cron)`; the slug is the leading token, matching
    the `<slug>.md` filename convention. (`;`-separated multi-entries are split
    upstream in `personas()`.)"""
    # Order matters: strip an inline ` # comment` BEFORE the surrounding quotes, else a
    # quoted item's closing quote is left interior once the comment is removed
    # (`"alice"  # note`: quote-strip-first → `alice"  # note` → `alice"`). Comment first,
    # then quotes, then a trailing (qualifier).
    s = s.strip()
    s = re.sub(r"(^|\s+)#.*$", "", s).strip()         # drop a YAML comment: inline (` # note`)
    #                                                   OR a whole-value comment (`# note` → "")
    s = s.strip("`\"'").strip()                       # strip surrounding quotes/backticks
    s = re.sub(r"\s*\([^)]*\)\s*$", "", s).strip()    # drop a trailing (qualifier)
    return s


def personas(text: str) -> list:
    """The `personas:` front-matter slugs (inline `[a, b]` or block `- a` form), with
    quotes/backticks stripped. Honest-empty (`personas: []` / `personas:` with no
    items / `null`) and an absent key both yield [] — never a false 'missing persona'.
    A non-list scalar (`personas: admin`) is tolerated as a single slug."""
    block = _frontmatter_block(text)
    lines = block.splitlines()
    for i, ln in enumerate(lines):
        m = re.match(r"^personas:\s*(.*)$", ln)
        if not m:
            continue
        rest = m.group(1).strip()
        if rest.startswith("["):
            inner = rest[1:rest.index("]")] if "]" in rest else rest[1:]
            # Split on , and ; — some repos use `;` to separate annotated entries
            # (`[ADMIN (full); MANAGER (limited)]`).
            return [_clean_slug(s) for s in re.split(r"[,;]", inner) if _clean_slug(s)]
        if rest in ("", "null", "Null", "NULL", "~"):
            # block list (subsequent `  - <slug>` lines) or genuinely empty
            slugs = []
            for cont in lines[i + 1:]:
                s = cont.strip()
                if not s or s.startswith("#"):
                    continue  # a blank line OR a full-line YAML comment between items
                    #          does NOT end the list (a comment is not a terminator)
                mm = re.match(r"^\s+-\s+(.+?)\s*$", cont)
                if not mm:
                    break  # next top-level key / non-item line ends the block list
                slug = _clean_slug(mm.group(1))
                if slug:
                    slugs.append(slug)
            return slugs
        slug = _clean_slug(rest)  # scalar single value
        return [slug] if slug else []  # `personas: # note` cleans to "" → honest-empty
    return []  # no personas key → honest-absent


def audit_persona_exists(repo) -> list:
    """Return a list of violation dicts {doc, slug}. Each non-empty `personas:` slug
    in a story doc that has no matching docs/product/personas/<slug>.md is a
    violation. Empty ⇒ clean."""
    repo = Path(repo)
    flows_base = repo / "docs" / "product" / "flows"
    personas_dir = repo / "docs" / "product" / "personas"
    violations = []
    for d in _story_docs(repo):
        # Domain-qualified doc id so same-stem stories in different domains are
        # distinguishable (flows/shop/overview vs flows/checkout/overview).
        try:
            doc_id = str(d.relative_to(flows_base).with_suffix(""))
        except ValueError:
            doc_id = d.stem
        for slug in personas(_read(d)):
            if not slug:
                continue
            if not (personas_dir / (slug + ".md")).is_file():
                violations.append({"doc": doc_id, "slug": slug})
    return violations


def main(argv: list) -> int:
    if len(argv) != 1:
        sys.stderr.write("usage: flow_persona_lint.py <repo_root>\n")
        return 2
    repo = Path(argv[0])
    if not repo.is_dir():
        sys.stderr.write("error: repo root not found: %s\n" % repo)
        return 2
    violations = audit_persona_exists(repo)
    if not violations:
        print("✓ persona-exists: clean")
        return 0
    for v in violations:
        print("FAIL  persona-exists  %-28s persona '%s' → no docs/product/"
              "personas/%s.md" % (v["doc"], v["slug"], v["slug"]))
    print("✗ %d persona-exists violation(s)" % len(violations))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
