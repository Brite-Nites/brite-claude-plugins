#!/usr/bin/env python3
"""Deterministic journey-doc frontmatter builder (BC-13028 #4 journey half, ADR-033).

The hermetic, side-effect-free stamper `flow-journey-author` shells out to so a
fresh FDA scaffold emits POPULATED journey frontmatter (`linear_milestone` name +
UUID, `personas`, `flow_ids_in_scope`) instead of LLM-side placeholders — the
journey-side close of the silent-return family BC-13028 #4 exists to kill (the
story half shipped as `build_story_frontmatter.py` in BC-13168).

Pure function of its inputs. Two read surfaces, both standardized (ADR-033):

* `--scaffold-log` — the per-domain scaffold-log's FRONTMATTER only (`domain`,
  `linear_milestone_id`, `linear_milestone_name` per
  `templates/.flow/scaffold-log/SCHEMA.md`). Unlike the story builder, the body
  tables are never parsed — the journey's scaffold-sourced facts all live in the
  log's YAML header.
* `--flows-dir` — the domain's story docs (`docs/product/flows/<domain>/*.md`),
  whose frontmatter is deterministically stamped since BC-13168 and therefore a
  clean aggregation source: `flow_ids_in_scope` = the docs' `flow_id` values
  natural-sorted by numeric suffix; `personas` = first-seen dedup walking that
  order. The unstandardized master-flow-inventory is deliberately NOT read.
  Zero valid story docs → exit 2 (the Q16.8 flow-doc-author-before-journey
  ordering contract was violated; fail loud, never stamp honest-empties).

Degrade-never-malform: a missing/junk scaffold-log value degrades to `TBD`
(junk UUID, missing domain); a YAML-unsafe milestone name is emitted
double-quoted via json.dumps (valid YAML, never raw, never lost); a story doc
with no frontmatter or a charset-invalid `flow_id` is skipped whole; a
charset-invalid persona token is skipped. Nothing unvalidated is ever emitted
raw into YAML at exit 0. This is a SEPARATE builder from
`build_story_frontmatter.py` by design (ADR-033): the two share no parsing core
(tables vs frontmatter), so the ~15 lines of common helpers are duplicated
rather than cross-imported — each script stays independently runnable and
independently golden-locked.

Output: the `---…---` YAML frontmatter block to stdout (no body — the
`journey-doc-author` agent authors the body per its body-only contract; the
skill concatenates). No Linear MCP, no filesystem scan beyond the two named
inputs. Stdlib-only per CLAUDE.md.

Exit codes: 0 = emitted OK; 2 = usage / unreadable or frontmatter-less
scaffold-log / missing flows dir / zero valid story docs / malformed --as-of
(a deliberate literal `2`, matched by the harness — not POSIX os.EX_USAGE, =64).
Missing-required-arg usage errors also exit 2, via argparse's own error path —
same code, different mechanism (pinned by the harness so a refactor that wraps
argparse can't silently change it). Locked by
`tests/run-journey-frontmatter-vslice.sh`. If you fix a YAML-emission or
parsing bug here, check the story twin (`build_story_frontmatter.py`) for the
same class — the helpers are duplicated, not shared.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

TBD = "TBD"
# `\Z` not `$` ($ matches before a trailing `\n` — the BC-12945 lesson).
_AS_OF_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\Z")
_UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\Z")
_KEBAB_RE = re.compile(r"^[a-z0-9][a-z0-9-]*\Z")
# Persona tokens share the story builder's slug charset (duplicated, not imported).
_SLUG_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*\Z")
# Suffix bounded to 9 digits so `int(suffix)` in _natural_key is TOTAL — an
# unbounded `\d+` admits a >4300-digit suffix that raises ValueError under
# CPython's int-conversion guard (sys.int_max_str_digits), breaking the
# exit-0-degrade/exit-2 contract. The story twin keeps `\d+` because it never
# int()s the suffix. An over-long suffix fails the match → doc skipped whole.
_FLOW_ID_RE = re.compile(r"^[A-Za-z]+-\d{1,9}\Z")
# Milestone/display names safe to emit UNQUOTED in YAML value position: must not
# start with an indicator char and must avoid `:`/`#`/quotes/brackets anywhere.
# Anything else is emitted via json.dumps (a JSON string is a valid YAML
# double-quoted scalar) so real names are preserved, never TBD'd, never raw.
_SAFE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 &/().,'+_-]*\Z")
# Whole-string forms YAML 1.1 coerces to non-string (bool/null/number/timestamp)
# even when charset-safe — "Off" → False, "2024" → int, "2024-01-01" → date.
# These must be double-quoted or a downstream YAML consumer silently loses the
# string type. The digit-led branch admits `-`/`:` so date/time shapes are
# covered too. Leading +/- can't reach here (first char must be alnum in both
# charsets above); mixed digit+alpha/space strings ("2024 Holiday") don't coerce.
_YAML_AMBIGUOUS_RE = re.compile(r"(?i)^(?:null|true|false|yes|no|on|off)\Z|^\d[\d_.,:-]*\Z")
# Frontmatter line shapes (top-level `key: value` and block-list `- item`).
_KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):(.*)$")
_ITEM_RE = re.compile(r"^\s+-\s*(.+?)\s*$")


class BuildError(Exception):
    """Usage / unreadable inputs / zero story docs → process exit 2."""


def _parse_frontmatter(text: str) -> tuple[dict[str, str], dict[str, list[str]]] | None:
    """The first `---` block → ({key: scalar}, {key: [items]}); None if absent.

    Line-based on purpose (stdlib has no YAML): top-level `key: value` scalars,
    flow-style `key: [a, b]` lists, and block-style `key:` + indented `- item`
    lists. Indented mappings (e.g. a story doc's `children:` block) are ignored.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    scalars: dict[str, str] = {}
    lists: dict[str, list[str]] = {}
    pending: str | None = None  # block-list key currently collecting `- item` lines
    closed = False
    for raw in lines[1:]:
        if raw.strip() == "---":
            closed = True
            break
        if pending is not None:
            if not raw.strip():
                continue  # a blank line inside a block list is a continuation, not a terminator
            item = _ITEM_RE.match(raw)
            if item:
                lists[pending].append(item.group(1))
                continue
        key_match = _KEY_RE.match(raw)
        if not key_match:
            pending = None
            continue
        key, rest = key_match.group(1), key_match.group(2).strip()
        pending = None
        if rest.startswith("[") and rest.endswith("]"):
            inner = rest[1:-1].strip()
            lists[key] = [c.strip() for c in inner.split(",")] if inner else []
        elif rest == "":
            lists[key] = []
            pending = key
        else:
            scalars[key] = rest
    if not closed:
        return None
    return scalars, lists


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        raise BuildError(f"cannot read {path}: {exc}") from exc


def _yaml_safe_name(raw: str) -> str:
    """Milestone/display name → its YAML-safe emission (TBD / unquoted / quoted)."""
    if not raw:
        return TBD
    if _SAFE_NAME_RE.match(raw) and not _YAML_AMBIGUOUS_RE.match(raw):
        return raw
    return json.dumps(raw, ensure_ascii=True)


def _yaml_safe_token(token: str) -> str:
    """A _SLUG_RE-validated list token → quoted iff YAML would coerce it ("off", "123")."""
    return json.dumps(token, ensure_ascii=True) if _YAML_AMBIGUOUS_RE.match(token) else token


def _natural_key(flow_id: str) -> tuple[str, int]:
    prefix, _, suffix = flow_id.rpartition("-")
    # suffix is all-digits and ≤9 long by _FLOW_ID_RE, so int() is total here.
    # The prefix component is defensive — the builder runs per-domain (one
    # prefix in practice); kept so ordering stays total if a mixed-prefix
    # flows dir ever occurs.
    return (prefix, int(suffix))


def _aggregate_story_docs(flows_dir: Path) -> tuple[list[str], list[str]]:
    """flows-dir → (natural-sorted flow_ids, first-seen-dedup'd personas)."""
    if not flows_dir.is_dir():
        raise BuildError(f"flows dir not found: {flows_dir}")
    personas_by_flow_id: dict[str, list[str]] = {}
    for doc in sorted(flows_dir.glob("*.md")):
        try:
            text = _read_text(doc)
        except BuildError:
            continue  # an unreadable sibling never aborts the aggregation
        parsed = _parse_frontmatter(text)
        if parsed is None:
            continue  # no frontmatter block → not a story doc
        scalars, lists = parsed
        flow_id = scalars.get("flow_id", "").strip().strip("`")
        if not _FLOW_ID_RE.match(flow_id):
            continue  # junk/missing flow_id → skip the doc whole (and its personas)
        personas = [t for t in lists.get("personas", []) if _SLUG_RE.match(t)]
        # A duplicate flow_id across docs merges personas (first-seen dedup runs
        # downstream); builder-stamped docs can't produce duplicates, hand-edits
        # merge benignly.
        personas_by_flow_id.setdefault(flow_id, []).extend(personas)
    if not personas_by_flow_id:
        raise BuildError(
            f"no story docs with a valid flow_id under {flows_dir} "
            "(flow-doc-author must run before flow-journey-author — Q16.8)")
    flow_ids = sorted(personas_by_flow_id, key=_natural_key)
    # First-seen dedup walking flow_id order — dict preserves insertion order,
    # so the result is deterministic (no set ordering).
    personas_out = list(dict.fromkeys(
        token for fid in flow_ids for token in personas_by_flow_id[fid]))
    return flow_ids, personas_out


def build_frontmatter(scaffold_log: Path, flows_dir: Path, as_of: str) -> str:
    if not _AS_OF_RE.match(as_of):
        raise BuildError(f"--as-of must be YYYY-MM-DD, got: {as_of!r}")
    parsed = _parse_frontmatter(_read_text(scaffold_log))
    if parsed is None:
        raise BuildError(f"scaffold-log has no frontmatter block: {scaffold_log}")
    log_scalars, _ = parsed

    domain_raw = log_scalars.get("domain", "").strip()
    domain = domain_raw if _KEBAB_RE.match(domain_raw) else TBD
    name = _yaml_safe_name(log_scalars.get("linear_milestone_name", "").strip())
    mid_raw = log_scalars.get("linear_milestone_id", "").strip()
    milestone_id = mid_raw if _UUID_RE.match(mid_raw) else TBD

    flow_ids, personas = _aggregate_story_docs(flows_dir)

    # ADR-033 canonical key order — byte shape locked by the vslice goldens.
    lines = [
        "---",
        f"domain: {domain}",
        f"display_name: {name}",
        "linear_milestone:",
        f"  name: {name}",
        f"  id: {milestone_id}",
        f"personas: [{', '.join(_yaml_safe_token(t) for t in personas)}]",
        f"flow_ids_in_scope: [{', '.join(flow_ids)}]",
        "status: in-progress",
        "figma: TBD",
        "intent: ../intent.md",
        f"last_reviewed: '{as_of}'",  # quote: an unquoted ISO date is YAML-coerced to a date (BC-13796)
        "---",
    ]
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Stamp ADR-033 canonical journey-doc frontmatter from the "
                    "scaffold-log frontmatter + the domain's story docs.")
    parser.add_argument("--scaffold-log", required=True, type=Path,
                        help=".flow/scaffold-log/<domain>.md (frontmatter is read; tables are not)")
    parser.add_argument("--flows-dir", required=True, type=Path,
                        help="docs/product/flows/<domain>/ (story-doc frontmatter aggregation source)")
    parser.add_argument("--as-of", required=True,
                        help="ISO date for last_reviewed (defeats now())")
    args = parser.parse_args(argv)
    try:
        sys.stdout.write(build_frontmatter(args.scaffold_log, args.flows_dir, args.as_of))
    except BuildError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
