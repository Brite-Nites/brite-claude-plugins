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
import json
import re
import sys
from pathlib import Path

# Canonical job-story template frontmatter key order
# (plugins/flow-architecture/templates/docs/templates/job-story.md).
TBD = "TBD"
# `flow_id` is an OPAQUE identifier (ADR-040): both `DOMAIN-NN` (`PROD-08`) and slash-form
# (`admin-panel/layout-and-auth`) are valid. The ONLY constraint on the value is a safe
# CHARACTER SET so it can never malform emitted YAML — NOT a `DOMAIN-NN` shape. Domain is read
# explicitly (scaffold-log `domain_code`), never split out of flow_id (see _resolve_domain).
# `\Z` not `$` ($ matches before a trailing `\n` — the BC-12945 lesson).
_FLOW_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9/_-]*\Z")
# `BC-NNNN` Linear-id CELLS stay strict (alpha prefix + numeric suffix) — a DISTINCT namespace
# from flow_id (which is opaque above). Scaffold-log id cells failing _LINEAR_ID_RE degrade to TBD
# (not emitted raw), the same charset rigor the caller params get below — so a degraded cell's
# stray `#`/`:`/`,` can never malform the emitted YAML at exit 0.
_LINEAR_ID_RE = re.compile(r"^[A-Za-z]+-\d+\Z")
_AS_OF_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\Z")
# Caller-derived enums/slugs are emitted raw into YAML, so they are validated to a
# safe charset up front (exit 2).
_STATUS_TAXONOMY = frozenset(
    {"NOT_STARTED", "IN_PROGRESS", "BUILT", "QA_SIGNED_OFF", "SHIPPED", "BLOCKED"})
_SLUG_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*\Z")
# A token whose bare YAML form coerces to a non-string (bool/null/int/date)
# — mirrors build_journey_frontmatter's _YAML_AMBIGUOUS_RE/_yaml_safe_token (BC-13797).
# `y|n` are the single-char YAML-1.1 bool short forms: now that an opaque flow_id (ADR-040)
# can BE a single letter, they're quoted for consistency with the on/off/yes/no the guard
# already covers under the strict-YAML-1.1 standard (defensive — PyYAML/js-yaml don't coerce
# bare y/n, but a strict YAML-1.1 reader would). `(?i)` covers Y/N. Real ids are never y/n.
_YAML_AMBIGUOUS_RE = re.compile(r"(?i)^(?:null|true|false|yes|no|y|n|on|off)\Z|^\d[\d_.,:-]*\Z")
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


def _cell_is_flow(cell: str, flow_id: str) -> bool:
    """True if a scaffold-log Sub-flow cell names `flow_id`. flow_id is OPAQUE (ADR-040),
    so we match the KNOWN id as the cell's first whitespace-delimited token rather than
    extracting a `DOMAIN-NN` shape (which slash-form ids like `admin-panel/layout-and-auth`
    don't have). The cell is either the bare id (children table) or `<id> — <desc> [<annot>]`
    (parents table), with the id optionally backtick-wrapped; an opaque id contains no
    whitespace, so the first token IS the whole id. Backticks are stripped AFTER splitting —
    `strip("`")` on the whole cell would leave the closing backtick of a `` `<id>` — <desc> ``
    cell interior and silently miss it. Exact match on the de-backticked token also rules out
    `WGT-01` vs `WGT-010`. Header / separator / milestone cells never lead with the id."""
    tokens = cell.split()
    return bool(tokens) and tokens[0].strip("`") == flow_id


def _parse_scaffold_log(text: str, flow_id: str) -> tuple[str, dict[str, str]]:
    """Return (parent_issue, children{slot->BC}) for flow_id from the log's tables.

    Parents table rows have 4 cells: `# | Sub-flow | Linear identifier | Result`, where
    Sub-flow is `<flow_id> — <desc> [<annot>]`. Discipline-children rows have 7 cells:
    `Sub-flow | Story | Engineering | Design | QA | Docs | Result`, where Sub-flow is the
    bare `<flow_id>`. BOTH Sub-flow columns are matched by `_cell_is_flow` against the known
    opaque flow_id (backticks stripped first), so a `` `<id>` `` or `<id> — desc` cell still
    matches — never a silent all-`TBD` miss. Header/separator/milestone rows never equal or
    lead with the id, so they fall through. The `Result` column is informational-only (never
    parsed); duplicate rows for one flow_id resolve last-wins (an idempotent in-place rewrite
    per SCHEMA.md).
    """
    parent = TBD
    children = {slot: TBD for slot in _CHILD_SLOTS}
    found = False
    for line in text.splitlines():
        cells = _split_row(line)
        if not cells or _is_separator(cells):
            continue
        if len(cells) == 7:  # discipline-children row
            if _cell_is_flow(cells[0], flow_id):
                for i, slot in enumerate(_CHILD_SLOTS, start=1):
                    children[slot] = _clean_id(cells[i])
                found = True
        elif len(cells) == 4:  # parents row: # | Sub-flow | Linear identifier | Result
            if _cell_is_flow(cells[1], flow_id):
                parent = _clean_id(cells[2])
                found = True
    if not found:
        raise BuildError(f"flow-id {flow_id!r} not present in the scaffold-log")
    return parent, children


def _fallback_domain(flow_id: str) -> str:
    """Derive domain from flow_id — a BACKWARD-COMPAT fallback ONLY, used when no explicit
    domain is available (a legacy scaffold-log without `domain_code`, or the redirect path
    which has no scaffold-log). ADR-040 keeps domain EXPLICIT in the normal path; this
    fallback honors the id's own separator so it stays correct for both shapes: a slash-form
    `<domain>/<slug>` splits on the first `/`; a `DOMAIN-NN` splits on the first `-`. The
    result is a prefix of the safe-charset flow_id, so it is always _SLUG_RE-valid."""
    if "/" in flow_id:
        return flow_id.split("/", 1)[0]
    return flow_id.split("-", 1)[0]


def _scaffold_log_domain(text: str) -> str:
    """The scaffold-log's EXPLICIT domain from its frontmatter (ADR-040: domain is explicit,
    never derived from flow_id). Prefers `domain_code` (the code that matches the story-doc
    `domain` field + master-flow-inventory per SCHEMA.md), falling back to `domain` (kebab),
    else ''. Line-based — stdlib has no YAML; only the leading `---` block is scanned. A value
    failing the safe charset is ignored (caller falls back), never emitted raw."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return ""
    found: dict[str, str] = {}
    for raw in lines[1:]:
        if raw.strip() == "---":
            break
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):(.*)$", raw)
        if m and m.group(1) in ("domain_code", "domain"):
            found[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return found.get("domain_code", "") or found.get("domain", "")


def _resolve_domain(explicit: str, scaffold_text: str | None, flow_id: str) -> str:
    """The story-doc `domain` value, EXPLICIT-first (ADR-040): an explicit `--domain` arg,
    then the scaffold-log's `domain_code`/`domain` frontmatter, then the `_fallback_domain`
    split (legacy / redirect). Each candidate must pass the safe charset (_SLUG_RE) to be
    emitted; an invalid one is skipped. The final `_fallback_domain` is a prefix of the
    safe-charset flow_id, so it always passes — domain is never empty and never malforms YAML."""
    scaffold_domain = _scaffold_log_domain(scaffold_text) if scaffold_text else ""
    for cand in (explicit, scaffold_domain):
        if cand and _SLUG_RE.match(cand):
            return cand
    return _fallback_domain(flow_id)


def _yaml_safe_token(token: str) -> str:
    """A token → double-quoted iff YAML would coerce it to a non-string; else raw (BC-13797).
    Quote iff a bool/null keyword OR ANY digit-led token. Quoting every digit-led token covers
    ints/dates AND radix literals (`0x1A`/`0o17`/`0b11`) that `_YAML_AMBIGUOUS_RE`'s digit branch
    misses — complete without enumerating each coercion form, now that opaque flow_ids (ADR-040)
    can be bare digit-led tokens. A letter-led non-keyword token (`PROD-08`, `admin-panel/x`) is
    provably a YAML string → stays raw, so existing DOMAIN-NN / slash-form output is byte-identical."""
    return (json.dumps(token, ensure_ascii=True)
            if token[:1].isdigit() or _YAML_AMBIGUOUS_RE.match(token) else token)


def _yaml_list(values: list[str]) -> str:
    """Flow-style YAML list matching the job-story template (`[a, b]` / `[]`).
    Each token is YAML-coercion-guarded (BC-13797)."""
    return "[" + ", ".join(_yaml_safe_token(v) for v in values) + "]"


def _emit(flow_id: str, domain: str, parent: str, children: dict[str, str], status: str,
          personas: list[str], related_flows: list[str], as_of: str) -> str:
    # domain is resolved EXPLICITLY by _resolve_domain (ADR-040) — never split from flow_id here.
    lines = [
        "---",
        f"flow_id: {_yaml_safe_token(flow_id)}",  # opaque id may be coercion-prone (ADR-040)
        f"domain: {_yaml_safe_token(domain)}",
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
        f"last_reviewed: '{as_of}'",  # quote: an unquoted ISO date is YAML-coerced to a date (BC-13796)
        "---",
    ]
    return "\n".join(lines) + "\n"


def _emit_redirect(flow_id: str, domain: str, redirect_to: str, as_of: str) -> str:
    """Minimal redirect-stub frontmatter (BC-12907 / REDIRECT_CANON): an intentional
    alias to `redirect_to`'s canonical home. No children / story / status keys — the
    audit applies the redirect-validation profile (resolvable pointer + these keys) and
    skips the story-frame / gherkin / children gates for it. domain is resolved explicitly
    (ADR-040) — for the redirect path, from --domain or the _fallback_domain split."""
    return "\n".join([
        "---",
        f"flow_id: {_yaml_safe_token(flow_id)}",  # opaque id may be coercion-prone (ADR-040)
        f"domain: {_yaml_safe_token(domain)}",
        "doc_type: redirect",
        f"redirect_to: {_yaml_safe_token(redirect_to)}",  # opaque target may be coercion-prone (ADR-040)
        "intent: ../../intent.md",
        f"last_reviewed: '{as_of}'",  # quote: an unquoted ISO date is YAML-coerced to a date (BC-13796)
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
    p.add_argument("--domain", default="",
                   help="explicit domain code (ADR-040); default reads the scaffold-log "
                        "`domain_code` frontmatter, else falls back to the flow_id prefix")
    p.add_argument("--doc-type", default="story", choices=("story", "redirect"),
                   help="story (default) or redirect — an intentional alias stub (BC-12907)")
    p.add_argument("--redirect-to", default="",
                   help="for --doc-type=redirect: the canonical flow_id this aliases (opaque slug)")
    p.add_argument("--as-of", required=True, help="ISO date for last_reviewed (defeats now())")
    p.add_argument("--status", default="NOT_STARTED",
                   help="story-doc status (skill passes code-evidence result; default NOT_STARTED)")
    p.add_argument("--personas", default="", help="comma-separated role slugs (caller-derived)")
    p.add_argument("--related-flows", default="", help="comma-separated flow_id slugs (caller-derived)")
    args = p.parse_args(argv)

    # flow_id is an OPAQUE identifier (ADR-040): validated to a safe charset, NOT a DOMAIN-NN shape.
    if not _FLOW_ID_RE.match(args.flow_id):
        print(f"usage: --flow-id must be a safe-charset slug [A-Za-z0-9][A-Za-z0-9/_-]* "
              f"(DOMAIN-NN or slash-form), got {args.flow_id!r}", file=sys.stderr)
        return 2
    if args.domain and not _SLUG_RE.match(args.domain):
        print(f"usage: --domain must be a slug [A-Za-z0-9][A-Za-z0-9_-]*, got {args.domain!r}",
              file=sys.stderr)
        return 2
    if not _AS_OF_RE.match(args.as_of):
        print(f"usage: --as-of must be YYYY-MM-DD, got {args.as_of!r}", file=sys.stderr)
        return 2
    if args.doc_type == "redirect":
        # Redirect stub (BC-12907): a minimal alias marker, no scaffold-log / children.
        if not _FLOW_ID_RE.match(args.redirect_to or ""):
            print(f"usage: --doc-type=redirect requires --redirect-to as an opaque flow_id slug, "
                  f"got {args.redirect_to!r}", file=sys.stderr)
            return 2
        # No scaffold-log on the redirect path → domain from --domain or the flow_id-prefix fallback.
        redirect_domain = _resolve_domain(args.domain, None, args.flow_id)
        sys.stdout.write(_emit_redirect(args.flow_id, redirect_domain, args.redirect_to, args.as_of))
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

    # domain EXPLICIT-first (ADR-040): --domain > scaffold-log `domain_code` > flow_id-prefix fallback.
    domain = _resolve_domain(args.domain, text, args.flow_id)
    sys.stdout.write(_emit(
        args.flow_id, domain, parent, children, args.status, personas, related_flows, args.as_of))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
