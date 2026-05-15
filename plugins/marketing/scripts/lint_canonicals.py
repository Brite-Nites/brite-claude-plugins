#!/usr/bin/env python3
"""Lint the GTM canonicals data layer.

Validates plugins/marketing/data/canonicals/{_manifest,<vertical>}.yaml against
the contract in ADR-016 + the T3-G acceptance criteria (BC-8718):

  1. Every {vertical}.yaml has required keys (slug, display, personas, offers).
  2. _manifest.yaml lists every vertical slug, alphabetized, with no duplicates.
  3. Every vertical slug in _manifest has a matching {slug}.yaml file (1:1).
  4. Every persona slug is kebab-case; every persona has titles[] with >=1 entry.
  5. Every offer slug is kebab-case.
  6. Every offer.status in {draft, active, retired}.
  7. Every offer.posture in {knowledge, free-asset, pilot, risk-reversal}.

Stdlib only — no PyYAML (per CLAUDE.md: repo has no Python dependencies).

Exit codes:
    0 — all canonicals valid.
    1 — one or more lint failures (errors printed to stderr).
    2 — usage error (canonicals dir missing or unreadable).
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

SLUG_RE = re.compile(r"^[a-z][a-z0-9-]*$")
ALLOWED_STATUS = {"draft", "active", "retired"}
ALLOWED_POSTURE = {"knowledge", "free-asset", "pilot", "risk-reversal"}

REPO_ROOT = Path(__file__).resolve().parents[3]
CANONICALS_DIR = REPO_ROOT / "plugins" / "marketing" / "data" / "canonicals"


class LintError(Exception):
    pass


def strip_inline_comment(value: str) -> str:
    """Drop ' # ...' inline comments while keeping '#' inside quotes intact."""
    in_quote = None
    out_chars: list[str] = []
    for ch in value:
        if in_quote:
            if ch == in_quote:
                in_quote = None
            out_chars.append(ch)
            continue
        if ch in ('"', "'"):
            in_quote = ch
            out_chars.append(ch)
            continue
        if ch == "#":
            break
        out_chars.append(ch)
    return "".join(out_chars).rstrip()


def parse_scalar(raw: str) -> object:
    """Parse a YAML scalar value (string, int, bool, inline empty list)."""
    s = strip_inline_comment(raw).strip()
    if s == "[]":
        return []
    if (s.startswith('"') and s.endswith('"')) or (
        s.startswith("'") and s.endswith("'")
    ):
        return s[1:-1]
    if s.lower() in ("true", "yes"):
        return True
    if s.lower() in ("false", "no"):
        return False
    try:
        return int(s)
    except ValueError:
        pass
    try:
        return float(s)
    except ValueError:
        pass
    return s


def parse_inline_list_of_strings(raw: str) -> list[str]:
    """Parse '[a, b, "c"]' into a list of strings. Empty -> []."""
    s = raw.strip()
    if not (s.startswith("[") and s.endswith("]")):
        raise LintError(f"expected inline list, got: {raw!r}")
    body = s[1:-1].strip()
    if not body:
        return []
    items = [p.strip() for p in body.split(",")]
    out: list[str] = []
    for item in items:
        if (item.startswith('"') and item.endswith('"')) or (
            item.startswith("'") and item.endswith("'")
        ):
            out.append(item[1:-1])
        else:
            out.append(item)
    return out


def parse_yaml(path: Path) -> dict:
    """Parse a small subset of YAML sufficient for the canonicals shape.

    Supports: top-level scalars + inline `[]`, block keys, block string lists
    (`  - "value"`), block dict lists (`  - key: value` followed by indented
    sibling `    key: value` lines), inline `[a, b]` lists for `target_personas`
    + `titles` + `aliases` + `verticals`.

    Raises LintError with line number on any unrecognized shape.
    """
    text = path.read_text()
    result: dict = {}
    cur_list_key: str | None = None
    cur_list_kind: str | None = None  # 'strings' | 'dicts'
    cur_list: list | None = None
    cur_dict: dict | None = None
    sub_list_key: str | None = None
    sub_list: list | None = None

    lines = text.splitlines()
    for lineno, raw_line in enumerate(lines, start=1):
        line = raw_line.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue

        indent = len(line) - len(line.lstrip(" "))
        content = line.strip()

        # Top-level scalar / block start: "key: value" or "key:".
        if indent == 0:
            # Reset all list/dict state.
            cur_list_key = None
            cur_list_kind = None
            cur_list = None
            cur_dict = None
            sub_list_key = None
            sub_list = None

            m = re.match(r"^([a-zA-Z_][\w-]*)\s*:\s*(.*)$", content)
            if not m:
                raise LintError(f"{path}:{lineno}: cannot parse: {content!r}")
            key, rest = m.group(1), m.group(2)
            if rest == "":
                # block start — next lines should be `  - ...`
                cur_list_key = key
                cur_list = []
                cur_list_kind = None  # determined by first item
                result[key] = cur_list
            else:
                result[key] = parse_scalar(rest)
            continue

        # Indented line: must be inside a block list.
        if cur_list_key is None:
            raise LintError(
                f"{path}:{lineno}: unexpected indented line outside a block: {content!r}"
            )

        # List-of-strings item: '  - "value"' or '  - value'
        m = re.match(r"^-\s+(.*)$", content)
        if m and not re.match(r"^-\s+[a-zA-Z_][\w-]*\s*:", content):
            value = m.group(1).strip()
            # If parsing dicts already, reject string item.
            if cur_list_kind == "dicts":
                # Could be a sub-list item under sub_list_key (deeper indent).
                if sub_list is not None and indent > 2:
                    sub_list.append(parse_scalar(value))
                    continue
                raise LintError(
                    f"{path}:{lineno}: string list item in dict list: {content!r}"
                )
            cur_list_kind = "strings"
            cur_list.append(parse_scalar(value))
            continue

        # Dict list start: '  - key: value'
        m = re.match(r"^-\s+([a-zA-Z_][\w-]*)\s*:\s*(.*)$", content)
        if m:
            if cur_list_kind == "strings":
                raise LintError(
                    f"{path}:{lineno}: dict list item in string list: {content!r}"
                )
            cur_list_kind = "dicts"
            cur_dict = {}
            cur_list.append(cur_dict)
            sub_list_key = None
            sub_list = None
            key, rest = m.group(1), m.group(2)
            if rest == "":
                # block start for sub-list under this dict item
                sub_list_key = key
                sub_list = []
                cur_dict[key] = sub_list
            else:
                cur_dict[key] = parse_scalar(rest)
            continue

        # Continuation of current dict item: '    key: value' (indent >= 4)
        m = re.match(r"^([a-zA-Z_][\w-]*)\s*:\s*(.*)$", content)
        if m and cur_list_kind == "dicts" and cur_dict is not None:
            key, rest = m.group(1), m.group(2)
            if rest == "":
                sub_list_key = key
                sub_list = []
                cur_dict[key] = sub_list
            else:
                cur_dict[key] = parse_scalar(rest)
            continue

        raise LintError(f"{path}:{lineno}: cannot parse: {content!r}")

    return result


def validate_persona(persona: dict, vertical_slug: str, idx: int) -> list[str]:
    errs: list[str] = []
    where = f"{vertical_slug}.yaml personas[{idx}]"
    for required in ("slug", "display", "titles"):
        if required not in persona:
            errs.append(f"{where}: missing required key '{required}'")
            return errs
    slug = persona["slug"]
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        errs.append(f"{where}: slug {slug!r} is not kebab-case")
    titles = persona["titles"]
    if not isinstance(titles, list) or len(titles) < 1:
        errs.append(f"{where}: titles must be a non-empty list (got {titles!r})")
    elif not all(isinstance(t, str) and t for t in titles):
        errs.append(f"{where}: every title must be a non-empty string")
    return errs


def validate_offer(offer: dict, vertical_slug: str, idx: int) -> list[str]:
    errs: list[str] = []
    where = f"{vertical_slug}.yaml offers[{idx}]"
    for required in ("slug", "display", "status", "posture"):
        if required not in offer:
            errs.append(f"{where}: missing required key '{required}'")
            return errs
    slug = offer["slug"]
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        errs.append(f"{where}: slug {slug!r} is not kebab-case")
    if offer["status"] not in ALLOWED_STATUS:
        errs.append(
            f"{where}: status {offer['status']!r} not in {sorted(ALLOWED_STATUS)}"
        )
    if offer["posture"] not in ALLOWED_POSTURE:
        errs.append(
            f"{where}: posture {offer['posture']!r} not in {sorted(ALLOWED_POSTURE)}"
        )
    return errs


def validate_vertical(path: Path) -> list[str]:
    errs: list[str] = []
    try:
        data = parse_yaml(path)
    except LintError as e:
        return [str(e)]
    where = path.name
    for required in ("slug", "display", "personas", "offers"):
        if required not in data:
            errs.append(f"{where}: missing required key '{required}'")
    if errs:
        return errs
    slug = data["slug"]
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        errs.append(f"{where}: vertical slug {slug!r} is not kebab-case")
    if path.stem != slug:
        errs.append(
            f"{where}: filename stem {path.stem!r} does not match slug {slug!r}"
        )
    personas = data["personas"]
    if not isinstance(personas, list):
        errs.append(f"{where}: personas must be a list")
    else:
        for i, p in enumerate(personas):
            if not isinstance(p, dict):
                errs.append(f"{where}: personas[{i}] must be a mapping")
                continue
            errs.extend(validate_persona(p, slug, i))
    offers = data["offers"]
    if not isinstance(offers, list):
        errs.append(f"{where}: offers must be a list")
    else:
        for i, o in enumerate(offers):
            if not isinstance(o, dict):
                errs.append(f"{where}: offers[{i}] must be a mapping")
                continue
            errs.extend(validate_offer(o, slug, i))
    return errs


def main() -> int:
    if not CANONICALS_DIR.is_dir():
        print(
            f"ERROR: canonicals dir not found: {CANONICALS_DIR}",
            file=sys.stderr,
        )
        return 2

    manifest_path = CANONICALS_DIR / "_manifest.yaml"
    if not manifest_path.is_file():
        print(f"ERROR: missing _manifest.yaml at {manifest_path}", file=sys.stderr)
        return 2

    all_errs: list[str] = []
    try:
        manifest = parse_yaml(manifest_path)
    except LintError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    if "schema_version" not in manifest:
        all_errs.append("_manifest.yaml: missing schema_version")
    if "verticals" not in manifest or not isinstance(manifest.get("verticals"), list):
        all_errs.append("_manifest.yaml: verticals must be a list")
        for e in all_errs:
            print(f"  {e}", file=sys.stderr)
        return 1

    manifest_verticals: list[str] = manifest["verticals"]
    if manifest_verticals != sorted(manifest_verticals):
        all_errs.append(
            "_manifest.yaml: verticals[] not alphabetized — "
            f"expected {sorted(manifest_verticals)!r}"
        )
    if len(manifest_verticals) != len(set(manifest_verticals)):
        all_errs.append("_manifest.yaml: duplicate vertical slugs")
    for v in manifest_verticals:
        if not isinstance(v, str) or not SLUG_RE.match(v):
            all_errs.append(f"_manifest.yaml: slug {v!r} is not kebab-case")

    # 1:1 manifest-to-file mapping.
    file_slugs: set[str] = set()
    for entry in sorted(os.listdir(CANONICALS_DIR)):
        if entry == "_manifest.yaml" or entry == "schema.json":
            continue
        if not entry.endswith(".yaml"):
            continue
        file_slugs.add(entry[:-5])

    manifest_set = set(manifest_verticals)
    only_in_manifest = manifest_set - file_slugs
    only_in_files = file_slugs - manifest_set
    for slug in sorted(only_in_manifest):
        all_errs.append(f"manifest lists {slug!r} but no {slug}.yaml found")
    for slug in sorted(only_in_files):
        all_errs.append(f"file {slug}.yaml present but {slug!r} not in manifest")

    for slug in sorted(file_slugs & manifest_set):
        all_errs.extend(validate_vertical(CANONICALS_DIR / f"{slug}.yaml"))

    if all_errs:
        print("Canonicals lint FAILED:", file=sys.stderr)
        for e in all_errs:
            print(f"  {e}", file=sys.stderr)
        return 1
    print(
        f"Canonicals lint OK — {len(manifest_verticals)} verticals validated."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
