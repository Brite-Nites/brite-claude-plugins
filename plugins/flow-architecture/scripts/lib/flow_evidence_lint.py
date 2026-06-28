#!/usr/bin/env python3
"""WS-A evidence-reality lint (BC-12692 inventory ↔ story-doc consistency).

The VALUE-LEVEL companion to flow_frontmatter_lint.py — that lint is "key-level
only (values are BC-12692's territory)"; this one IS that territory. It machine-
enforces the two drifts that the brand-hub remediation (BC-11998 session 17) could
only catch by hand:

  (a) status agreement — a `master-flow-inventory.md` row's status GLYPH marker
      (✓ / ⚠ / ✗; the `?` "implemented-no-pattern-match" review-flag is EXEMPT)
      must agree with the linked story doc's canonical `status:` front-matter via a
      glyph → allowed-SET map (not 1:1 — a single glyph spans several canonical
      values). A story `status:` that is OFF the canonical 6-value taxonomy (legacy
      `PARTIAL` etc.) is DEFERRED to flow_doc_lint's BAD_STATUS, never re-reported
      here — this gate only fires on a CANONICAL-but-disagreeing status, so it does
      not double-report taxonomy validity nor false-fail a not-yet-migrated repo.

  (b) evidence-anchor reality — every strict source-path token cited in the row's
      "Evidence anchor" cell resolves to >=1 real file on disk (brace-expanded +
      glob-aware + Next.js `[id]`-literal-safe). HIGH-PRECISION / BEST-EFFORT by
      design: only tokens matching the strict `src/...{.ts,.tsx,.js,.jsx}` grammar
      are checked, so prose, URLs, flow-IDs, status glyphs, and bare-filename
      shorthand are skipped (a deliberate coverage gap — per the ticket, the
      "real path but wrong feature" misattribution case can't be fully automated;
      path-existence catches the bulk). Only rows whose glyph claims built/partial
      (✓ / ⚠) — or an indeterminate row — are checked; an explicitly-missing (✗)
      row is allowed to cite illustrative / not-yet-built paths.

flow_id is treated as an OPAQUE string for row → doc resolution (G2 / ADR-029
pending: brite-sites uses slash-form `domain/sub-flow` flow_ids — splitting on `-`
as DOMAIN-NN would exit-break it). Row col-1 == doc front-matter id, byte-for-byte.

Runner: scripts/flow-evidence-lint.sh. Test surface:
tests/run-flow-evidence-lint-vslice.sh. python3 3.6+; stdlib only.
"""
# No `from __future__ import annotations` — that PEP-563 import is 3.7+, and the
# house target is python3 3.6+ (sibling flow_frontmatter_lint / run_fda_ci_audit).
# The annotations here are all runtime-evaluable builtins (no forward refs).
import glob
import re
import sys
from pathlib import Path

# ── Canonical status taxonomy + glyph map ─────────────────────────────────────
# The 6-value INDEX taxonomy (mirrors flow_doc_lint.sh BAD_STATUS). A story
# `status:` outside this set is legacy/off-canon → deferred to BAD_STATUS.
CANON_STATUS = {
    "NOT_STARTED", "IN_PROGRESS", "BUILT", "QA_SIGNED_OFF", "SHIPPED", "BLOCKED",
}
# glyph → the SET of canonical statuses it may legitimately co-occur with. A
# single inventory glyph is coarser than the 6-value doc taxonomy, so the map is
# one-to-MANY (BC-12692 grill lock). `?` (implemented-no-pattern-match) is a
# review-flag, not a status claim → intentionally absent (exempt).
GLYPH_ALLOWED = {
    "✓": {"BUILT", "QA_SIGNED_OFF", "SHIPPED"},   # ✓ implemented
    "⚠": {"IN_PROGRESS", "BLOCKED"},              # ⚠ partial
    "✗": {"NOT_STARTED"},                         # ✗ missing-but-recommended
}
_STATUS_GLYPHS = "✓⚠✗?"                  # ✓ ⚠ ✗ ?
_GLYPH_MISSING = "✗"                               # ✗ — skip evidence-reality

# Strict source-path grammar: a relative `src/...` path ending in a code
# extension. `.js`/`.jsx` ARE included here (unlike flow_doc_lint's MECHANISM_LEAK
# P1, which excludes them to dodge the prose tokens Node.js / Next.js) because an
# inventory Evidence-anchor cell is a path list, not prose — a bare `Node.js`
# there would not be inside a `src/.../x.js` shape anyway.
_SRC_GRAMMAR = re.compile(r"^src/\S+\.(?:ts|tsx|js|jsx)$")
_BACKTICK = re.compile(r"`([^`]+)`")


# ── IO + front-matter (minimal twin of build_journey_frontmatter._parse) ──────
def _read(p) -> str:
    return Path(p).read_text(encoding="utf-8", errors="replace")


def _frontmatter_block(text: str) -> str:
    """The text between the opening `---` (line 1) and the next `---`. Empty if the
    doc does not open with a front-matter fence or it is unterminated."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return ""
    out = []
    for ln in lines[1:]:
        if ln.strip() == "---":
            return "\n".join(out)
        out.append(ln)
    return ""


def _fm_scalar(text: str, key: str):
    """The raw scalar value of a top-level front-matter `key:` (quotes/backticks
    stripped), or None. Nested keys are not descended (not needed here)."""
    for ln in _frontmatter_block(text).splitlines():
        m = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", ln)
        if m and m.group(1) == key:
            return m.group(2).strip().strip("`\"'")
    return None


def _doc_flow_id(text: str):
    """A story doc's declared flow-ID, opaque. Canonical `flow_id`, else the legacy
    `sub_flow_id` / `fda_sub_flow_id` aliases (brand-hub / older scaffolds)."""
    for key in ("flow_id", "sub_flow_id", "fda_sub_flow_id"):
        v = _fm_scalar(text, key)
        if v:
            return v
    return None


def _flow_index_skipped(text: str) -> bool:
    """True iff the FRONT-MATTER declares `flow_index: skip` (overview/index doc,
    BC-13805). Scoped to the front-matter block — a body line or a fenced-yaml
    example carrying `flow_index: skip` must NOT exclude a real story doc (mirrors
    the front-matter scoping flow_inventory_lint._fil_doc_ids applies to flow_id)."""
    return bool(re.search(r"^flow_index:\s*[\"']?skip[\"']?\s*$",
                          _frontmatter_block(text), re.M))


def _story_docs(repo: Path) -> list:
    """Story docs under docs/product/flows, found RECURSIVELY (rglob) — matching the
    inventory-lint sibling flow_inventory_lint._fil_doc_ids, which likewise `find`s
    docs at any depth. Every real consumer lays story docs out 2-level
    (flows/<domain>/<flow>.md), so on today's repos rglob is identical to a 2-level
    glob; recursing future-proofs a deeper layout without risk, because indexing is
    keyed on a `flow_id` front-matter match — a non-story nested `.md` (no flow_id)
    is simply never added to the status index. INDEX.md and `flow_index: skip`
    overview docs are excluded."""
    base = repo / "docs" / "product" / "flows"
    if not base.is_dir():
        return []
    docs = []
    for p in sorted(base.rglob("*.md")):
        if p.name == "INDEX.md":
            continue
        if _flow_index_skipped(_read(p)):
            continue
        docs.append(p)
    return docs


# ── Brace expansion (nested, top-level-comma aware) ───────────────────────────
def _split_top_commas(body: str) -> list:
    parts, depth, cur = [], 0, ""
    for ch in body:
        if ch == "{":
            depth += 1
            cur += ch
        elif ch == "}":
            depth -= 1
            cur += ch
        elif ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return parts


def _brace_expand(s: str) -> list:
    """Shell-style brace expansion: `a/{x,y}/z` → [a/x/z, a/y/z]. Handles nesting
    (`{p,[id]/{q,r}}`). Unbalanced braces are left verbatim (no expansion)."""
    start = s.find("{")
    if start == -1:
        return [s]
    depth, end = 0, -1
    for k in range(start, len(s)):
        if s[k] == "{":
            depth += 1
        elif s[k] == "}":
            depth -= 1
            if depth == 0:
                end = k
                break
    if end == -1:
        return [s]  # unbalanced
    pre, body, post = s[:start], s[start + 1:end], s[end + 1:]
    results = []
    for part in _split_top_commas(body):
        for sub in _brace_expand(part):
            for rest in _brace_expand(post):
                results.append(pre + sub + rest)
    return results


# ── Source-path extraction + on-disk resolution ───────────────────────────────
def _extract_src_groups(cell: str) -> list:
    """One GROUP per backtick span that yields >=1 strict `src/...` token; the group
    is the list of that span's brace-expansions (de-duplicated, order-preserving).

    A citation is treated as a compressed FILE-FAMILY: it is satisfied if ANY member
    resolves on disk. This is the high-precision / best-effort call — real consumer
    inventories use a Next.js route shorthand (`{route,preview,[id]/…}/route.ts`)
    whose literal expansion does not map one-to-one onto files (the real file is
    `…/route.ts`, not `…/route/route.ts`), so requiring EVERY member to exist
    false-fails legitimate anchors. Requiring only that the family points at >=1 real
    file still catches the in-scope drift — a wholesale-renamed/deleted anchor where
    NOTHING resolves. The partial-misattribution case is explicitly out of scope
    (per the ticket: "can't be fully automated"). Non-`src/` tokens, prose, glyphs,
    URLs and flow-IDs are dropped by the grammar."""
    groups = []
    for span in _BACKTICK.findall(cell or ""):
        members = []
        for expanded in _brace_expand(span):
            for raw in re.split(r"[\s,;]+", expanded):
                tok = raw.strip().strip(".,;:")
                if _SRC_GRAMMAR.match(tok) and tok not in members:
                    members.append(tok)
        if members:
            groups.append(members)
    return groups


def _extract_src_tokens(cell: str) -> list:
    """Flattened strict-`src/` tokens across all backtick-span groups (used for unit
    coverage; the audit resolves per-group via `_extract_src_groups`)."""
    out = []
    for group in _extract_src_groups(cell):
        out.extend(group)
    return out


def _resolve(repo: Path, token: str) -> bool:
    """True iff `token` resolves to >=1 real path under `repo`. A `*`/`?` token is
    globbed (with `[` neutralized to a literal so a Next.js `[id]` dynamic segment
    is not misread as a glob char-class); a plain token is checked literally (its
    `[id]` segment exists verbatim on disk)."""
    repo = Path(repo)
    if "*" in token or "?" in token:
        pattern = token.replace("[", "[[]")   # literal-'[' char class for glob
        return len(glob.glob(str(repo / pattern))) > 0
    return (repo / token).exists()


# ── Inventory table parsing ───────────────────────────────────────────────────
def _split_row(line: str) -> list:
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def _is_separator(line: str) -> bool:
    cells = _split_row(line)
    return bool(cells) and all(re.match(r"^:?-{2,}:?$", c) for c in cells if c != "")


def _norm_header(c: str) -> str:
    return c.strip().strip("`").strip().lower()


def _looks_like_header(line: str) -> bool:
    cells = [_norm_header(c) for c in _split_row(line)]
    return any(c in ("sub-flow id", "sub flow id", "flow_id", "flow id") for c in cells)


def _find_col(headers: list, keyword: str):
    for i, h in enumerate(headers):
        if keyword in _norm_header(h):
            return i
    return None


def _first_glyph(cell: str) -> str:
    for ch in cell:
        if ch in _STATUS_GLYPHS:
            return ch
    return ""


def _strip_id(cell: str) -> str:
    return cell.strip().strip("`").strip()


def _inventory_rows(inv_text: str) -> list:
    """(flow_id, glyph, evidence_cell) per data row, across every table whose
    header has a flow-id-ish first column. glyph / evidence_cell are '' when that
    column is absent (e.g. an inventory with no Status or no Evidence column —
    those checks then simply do not fire, rather than false-failing)."""
    rows = []
    lines = inv_text.splitlines()
    i, n = 0, len(lines)
    while i < n:
        line = lines[i]
        if line.lstrip().startswith("|") and _looks_like_header(line) \
                and i + 1 < n and _is_separator(lines[i + 1]):
            headers = _split_row(line)
            status_idx = _find_col(headers, "status")
            ev_idx = _find_col(headers, "evidence")
            j = i + 2
            while j < n and lines[j].lstrip().startswith("|"):
                if not _is_separator(lines[j]):
                    cells = _split_row(lines[j])
                    fid = _strip_id(cells[0]) if cells else ""
                    glyph = _first_glyph(cells[status_idx]) \
                        if status_idx is not None and status_idx < len(cells) else ""
                    ev = cells[ev_idx] \
                        if ev_idx is not None and ev_idx < len(cells) else ""
                    if fid:
                        rows.append((fid, glyph, ev))
                j += 1
            i = j
            continue
        i += 1
    return rows


# ── The audit ─────────────────────────────────────────────────────────────────
def audit_inventory_consistency(repo) -> list:
    """Return a list of violation dicts {check, flow_id, detail}. Empty ⇒ clean.
    `check` ∈ {status-agreement, evidence-anchor}."""
    repo = Path(repo)
    inv = repo / "docs" / "product" / "master-flow-inventory.md"
    violations = []
    if not inv.is_file():
        return violations  # no inventory → nothing to reconcile (A-8's territory)

    # flow_id → (path, canonical-or-legacy status) index, opaque keys.
    doc_status = {}
    for d in _story_docs(repo):
        t = _read(d)
        fid = _doc_flow_id(t)
        if fid:
            doc_status[fid] = _fm_scalar(t, "status")

    for fid, glyph, ev in _inventory_rows(_read(inv)):
        # (a) status agreement — only when the row has a mapped glyph, the doc
        # exists, AND the doc status is canonical. ?-glyph (not in GLYPH_ALLOWED),
        # a missing doc, or an off-canon status all fall through (deferred).
        if glyph in GLYPH_ALLOWED and fid in doc_status:
            st = doc_status[fid]
            if st in CANON_STATUS and st not in GLYPH_ALLOWED[glyph]:
                violations.append({
                    "check": "status-agreement", "flow_id": fid,
                    "detail": "inventory marker '%s' disagrees with story-doc "
                              "status '%s' (expected one of %s)"
                              % (glyph, st, "/".join(sorted(GLYPH_ALLOWED[glyph]))),
                })

        # (b) evidence-anchor reality — skip explicitly-missing (✗) rows (allowed
        # to cite not-yet-built / illustrative paths). Each backtick span is a
        # file-family; flagged only when NONE of its members resolve.
        if glyph != _GLYPH_MISSING:
            for group in _extract_src_groups(ev):
                if not any(_resolve(repo, tok) for tok in group):
                    violations.append({
                        "check": "evidence-anchor", "flow_id": fid,
                        "detail": "evidence anchor '%s' resolves to no file on "
                                  "disk" % group[0],
                    })
    return violations


def main(argv: list) -> int:
    if len(argv) != 1:
        sys.stderr.write("usage: flow_evidence_lint.py <repo_root>\n")
        return 2
    repo = Path(argv[0])
    if not repo.is_dir():
        sys.stderr.write("error: repo root not found: %s\n" % repo)
        return 2
    violations = audit_inventory_consistency(repo)
    if not violations:
        print("✓ inventory ↔ story-doc consistency: clean")
        return 0
    for v in violations:
        print("FAIL  %-18s %-28s %s" % (v["check"], v["flow_id"], v["detail"]))
    print("✗ %d inventory-consistency violation(s)" % len(violations))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
