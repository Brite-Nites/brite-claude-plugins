#!/usr/bin/env python3
"""Lint the GTM canonicals data layer.

Validates the canonicals contract in ADR-016 + the T3-G acceptance criteria
(BC-8718). Source-of-truth for the schema is `schema.json` next to this script;
this linter is the runtime enforcement (Brite repo is stdlib-only — no
jsonschema dependency).

Checks performed:

  Schema structure
    1. Every {vertical}.yaml has required keys (slug, display, personas, offers).
    2. additionalProperties:false at every level (vertical, persona, offer).
    3. _manifest.yaml has schema_version + verticals[].
    4. schema_version == SCHEMA_VERSION (linter is pinned to one major).

  Slug + naming
    5. Every vertical slug is kebab-case (no trailing or doubled hyphens).
    6. Every persona slug is kebab-case.
    7. Every offer slug is kebab-case.
    8. Filename stem matches the inner `slug:` value.

  Enum + type
    9. Every offer.status in {draft, active, retired}.
   10. Every offer.posture in {knowledge, free-asset, pilot, risk-reversal}.
   11. Every offer.target_postures item (if present) is a valid posture.
   12. Every persona.titles has >=1 non-empty string.

  Uniqueness
   13. _manifest.yaml verticals[] is alphabetized + duplicate-free.
   14. Every vertical slug in _manifest has a matching {slug}.yaml file (1:1).
   15. No duplicate persona slugs within a vertical.
   16. No duplicate offer slugs within a vertical.
   17. No alias collides with a canonical vertical slug or another vertical's
       alias.

  Referential integrity
   18. Every offer.target_personas item refers to a persona defined in the
       same vertical.
   19. Every offer.replaced_by / .iterates_from refers to a sibling offer slug
       in the same vertical (when present).

Supported YAML subset (intentional — stdlib only, no PyYAML per CLAUDE.md):
  - Top-level scalars and block-start keys.
  - Block list-of-strings: `key:\n  - "value"`.
  - Block list-of-dicts: `key:\n  - inner_key: value\n    inner_key_2: value2`.
  - Inline list-of-strings with quote-aware comma tokenizer:
        target_personas: [parks-rec-director, "city-manager"]
  - Inline empty list: `personas: []`.
  - Comments (`#`) — full-line and inline (outside quoted strings).

Unsupported (rejected loudly with a parser error):
  - Tabs in indent.
  - Folded scalars (`>` / `|`).
  - Anchors and aliases.
  - Multi-document streams.

Exit codes:
    0 — all canonicals valid.
    1 — one or more lint failures (errors printed to stderr).
    2 — usage error (canonicals dir missing or unreadable).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# ── Module-level constants ────────────────────────────────────────────────

SCHEMA_VERSION = 1

# Strict kebab: starts with a letter, no doubled or trailing hyphens.
SLUG_RE = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")

ALLOWED_STATUS = frozenset({"draft", "active", "retired"})
ALLOWED_POSTURE = frozenset({"knowledge", "free-asset", "pilot", "risk-reversal"})

# Mirror schema.json `additionalProperties: false` allowlists.
VERTICAL_KEYS = frozenset(
    {"slug", "display", "aliases", "playbook_path", "personas", "offers"}
)
PERSONA_KEYS = frozenset({"slug", "display", "titles"})
OFFER_KEYS = frozenset(
    {
        "slug",
        "display",
        "status",
        "posture",
        "target_personas",
        "target_postures",
        "replaced_by",
        "iterates_from",
        "prose_path",
    }
)
MANIFEST_KEYS = frozenset({"schema_version", "verticals"})

# Pre-compiled parse_yaml regexes (hot loop).
RE_TOP_KV = re.compile(r"^([a-zA-Z_][\w-]*)\s*:\s*(.*)$")
RE_LIST_ITEM = re.compile(r"^-\s+(.*)$")
RE_LIST_DICT_START = re.compile(r"^-\s+([a-zA-Z_][\w-]*)\s*:\s*(.*)$")
RE_DICT_CONT = re.compile(r"^([a-zA-Z_][\w-]*)\s*:\s*(.*)$")

DEFAULT_CANONICALS_DIR = (
    Path(__file__).resolve().parents[3]
    / "plugins"
    / "marketing"
    / "data"
    / "canonicals"
)


class LintError(Exception):
    """Raised by parse_yaml on unrecognized shape; caught at the call site."""


# ── Scalar + inline-list parsers ──────────────────────────────────────────


def strip_inline_comment(value: str) -> str:
    """Drop ' # ...' inline comments while keeping '#' inside quotes intact."""
    in_quote: str | None = None
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


def parse_inline_list_of_strings(raw: str) -> list[str]:
    """Parse `[a, b, "c, d", 'e']` with a quote-aware tokenizer.

    Splits on top-level commas only — commas inside double- or single-quoted
    items are preserved. Empty `[]` returns []. Trailing commas are rejected
    loudly (catch authoring typos rather than silently swallowing them).
    """
    s = raw.strip()
    if not (s.startswith("[") and s.endswith("]")):
        raise LintError(f"expected inline list, got: {raw!r}")
    body = s[1:-1].strip()
    if not body:
        return []
    items: list[str] = []
    buf: list[str] = []
    in_quote: str | None = None
    for ch in body:
        if in_quote:
            if ch == in_quote:
                in_quote = None
            buf.append(ch)
            continue
        if ch in ('"', "'"):
            in_quote = ch
            buf.append(ch)
            continue
        if ch == ",":
            items.append("".join(buf).strip())
            buf = []
            continue
        buf.append(ch)
    if in_quote:
        raise LintError(f"unterminated quoted string in inline list: {raw!r}")
    items.append("".join(buf).strip())
    out: list[str] = []
    for item in items:
        if not item:
            raise LintError(
                f"empty item in inline list (trailing comma?): {raw!r}"
            )
        if (item.startswith('"') and item.endswith('"')) or (
            item.startswith("'") and item.endswith("'")
        ):
            out.append(item[1:-1])
        else:
            out.append(item)
    return out


def parse_scalar(raw: str) -> object:
    """Parse a YAML scalar (strict YAML 1.2 subset).

    Order matters: inline-list dispatch must precede the bare-string fallback.
    Only `true`/`false` are coerced to bool (not `yes`/`no`/`YES`/`NO` — those
    stay strings in YAML 1.2). Integers are coerced for `schema_version`-style
    fields; nothing else is numeric in the canonicals shape, so float coercion
    is intentionally absent.
    """
    s = strip_inline_comment(raw).strip()
    if not s:
        return ""
    if s.startswith("[") and s.endswith("]"):
        return parse_inline_list_of_strings(s)
    if (s.startswith('"') and s.endswith('"')) or (
        s.startswith("'") and s.endswith("'")
    ):
        return s[1:-1]
    if s == "true":
        return True
    if s == "false":
        return False
    try:
        return int(s)
    except ValueError:
        return s


# ── YAML parser (subset, stdlib only) ─────────────────────────────────────


def parse_yaml(path: Path) -> dict[str, object]:
    """Parse a canonicals YAML file. Raises LintError on unrecognized shape."""
    text = path.read_text(encoding="utf-8")
    result: dict[str, object] = {}
    cur_list_key: str | None = None
    cur_list_kind: str | None = None  # "strings" | "dicts"
    cur_list: list | None = None
    cur_dict: dict | None = None
    sub_list_key: str | None = None
    sub_list: list | None = None

    for lineno, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        leading = line[: len(line) - len(line.lstrip())]
        if "\t" in leading:
            raise LintError(
                f"{path}:{lineno}: tabs not allowed in indent (use spaces)"
            )
        indent = len(leading)
        content = line.strip()

        if indent == 0:
            cur_list_key = None
            cur_list_kind = None
            cur_list = None
            cur_dict = None
            sub_list_key = None
            sub_list = None

            m = RE_TOP_KV.match(content)
            if not m:
                raise LintError(f"{path}:{lineno}: cannot parse: {content!r}")
            key, rest = m.group(1), m.group(2)
            if rest == "":
                cur_list_key = key
                cur_list = []
                cur_list_kind = None
                result[key] = cur_list
            else:
                result[key] = parse_scalar(rest)
            continue

        if cur_list_key is None:
            raise LintError(
                f"{path}:{lineno}: unexpected indented line outside a block: {content!r}"
            )

        # Dict-list item start: `  - key: value` or `  - key:`
        m = RE_LIST_DICT_START.match(content)
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
                sub_list_key = key
                sub_list = []
                cur_dict[key] = sub_list
            else:
                cur_dict[key] = parse_scalar(rest)
            continue

        # String-list item: `  - "value"` or `  - value`
        m = RE_LIST_ITEM.match(content)
        if m:
            value = m.group(1).strip()
            if cur_list_kind == "dicts":
                # May be a sub-list item under sub_list_key (deeper indent).
                if sub_list is not None and indent > 2:
                    sub_list.append(parse_scalar(value))
                    continue
                raise LintError(
                    f"{path}:{lineno}: string list item in dict list: {content!r}"
                )
            cur_list_kind = "strings"
            cur_list.append(parse_scalar(value))
            continue

        # Continuation of current dict item: `    key: value` (indent >= 4)
        m = RE_DICT_CONT.match(content)
        if m and cur_list_kind == "dicts" and cur_dict is not None and indent >= 4:
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


# ── Validators ────────────────────────────────────────────────────────────


def _check_unknown_keys(
    data: dict, allowed: frozenset[str], where: str
) -> list[str]:
    unknown = sorted(set(data.keys()) - allowed)
    return [f"{where}: unknown key '{k}'" for k in unknown]


def validate_persona(persona: dict, vertical_slug: str, idx: int) -> list[str]:
    where = f"{vertical_slug}.yaml personas[{idx}]"
    errs: list[str] = _check_unknown_keys(persona, PERSONA_KEYS, where)
    for required in ("slug", "display", "titles"):
        if required not in persona:
            errs.append(f"{where}: missing required key '{required}'")
    if errs:
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


def validate_offer(
    offer: dict,
    vertical_slug: str,
    idx: int,
    persona_slug_set: frozenset[str],
) -> list[str]:
    where = f"{vertical_slug}.yaml offers[{idx}]"
    errs: list[str] = _check_unknown_keys(offer, OFFER_KEYS, where)
    for required in ("slug", "display", "status", "posture"):
        if required not in offer:
            errs.append(f"{where}: missing required key '{required}'")
    if errs:
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
    tp = offer.get("target_personas")
    if tp is not None:
        if not isinstance(tp, list):
            errs.append(
                f"{where}: target_personas must be a list "
                f"(got {type(tp).__name__})"
            )
        else:
            for j, ref in enumerate(tp):
                if not isinstance(ref, str) or not SLUG_RE.match(ref):
                    errs.append(
                        f"{where}: target_personas[{j}] {ref!r} is not kebab-case"
                    )
                elif ref not in persona_slug_set:
                    errs.append(
                        f"{where}: target_personas[{j}] '{ref}' not defined in personas[]"
                    )
    tpo = offer.get("target_postures")
    if tpo is not None:
        if not isinstance(tpo, list):
            errs.append(
                f"{where}: target_postures must be a list "
                f"(got {type(tpo).__name__})"
            )
        else:
            for j, ref in enumerate(tpo):
                if ref not in ALLOWED_POSTURE:
                    errs.append(
                        f"{where}: target_postures[{j}] {ref!r} not in {sorted(ALLOWED_POSTURE)}"
                    )
    for ref_key in ("replaced_by", "iterates_from"):
        ref = offer.get(ref_key)
        if ref is not None and (not isinstance(ref, str) or not SLUG_RE.match(ref)):
            errs.append(f"{where}: {ref_key} {ref!r} is not kebab-case")
    return errs


def validate_vertical(path: Path) -> tuple[list[str], dict | None]:
    """Validate one vertical YAML. Returns (errors, parsed_data_or_None).

    Returns parsed_data so main() can run cross-file checks (alias collisions,
    replaced_by/iterates_from sibling refs) without re-parsing.
    """
    try:
        data = parse_yaml(path)
    except LintError as e:
        return ([str(e)], None)
    where = path.name
    errs: list[str] = _check_unknown_keys(data, VERTICAL_KEYS, where)
    for required in ("slug", "display", "personas", "offers"):
        if required not in data:
            errs.append(f"{where}: missing required key '{required}'")
    if any("missing required" in e for e in errs):
        return (errs, data)
    slug = data["slug"]
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        errs.append(f"{where}: vertical slug {slug!r} is not kebab-case")
    if path.stem != slug:
        errs.append(
            f"{where}: filename stem {path.stem!r} does not match slug {slug!r}"
        )

    aliases = data.get("aliases")
    if aliases is not None:
        if not isinstance(aliases, list):
            errs.append(f"{where}: aliases must be a list")
        else:
            for j, alias in enumerate(aliases):
                if not isinstance(alias, str) or not SLUG_RE.match(alias):
                    errs.append(
                        f"{where}: aliases[{j}] {alias!r} is not kebab-case"
                    )

    personas = data["personas"]
    persona_slugs: list[str] = []
    if not isinstance(personas, list):
        errs.append(f"{where}: personas must be a list")
    else:
        for i, p in enumerate(personas):
            if not isinstance(p, dict):
                errs.append(f"{where}: personas[{i}] must be a mapping")
                continue
            errs.extend(validate_persona(p, slug, i))
            if isinstance(p.get("slug"), str):
                persona_slugs.append(p["slug"])
    persona_slug_set = frozenset(persona_slugs)
    seen: set[str] = set()
    for s in persona_slugs:
        if s in seen:
            errs.append(f"{where}: duplicate persona slug '{s}'")
        seen.add(s)

    offers = data["offers"]
    offer_slugs: list[str] = []
    if not isinstance(offers, list):
        errs.append(f"{where}: offers must be a list")
    else:
        for i, o in enumerate(offers):
            if not isinstance(o, dict):
                errs.append(f"{where}: offers[{i}] must be a mapping")
                continue
            errs.extend(validate_offer(o, slug, i, persona_slug_set))
            if isinstance(o.get("slug"), str):
                offer_slugs.append(o["slug"])
    offer_slug_set = frozenset(offer_slugs)
    seen = set()
    for s in offer_slugs:
        if s in seen:
            errs.append(f"{where}: duplicate offer slug '{s}'")
        seen.add(s)

    # Sibling-offer references (replaced_by / iterates_from)
    if isinstance(offers, list):
        for i, o in enumerate(offers):
            if not isinstance(o, dict):
                continue
            for ref_key in ("replaced_by", "iterates_from"):
                ref = o.get(ref_key)
                if isinstance(ref, str) and SLUG_RE.match(ref):
                    if ref not in offer_slug_set:
                        errs.append(
                            f"{where} offers[{i}]: {ref_key} '{ref}' not defined in offers[]"
                        )

    return (errs, data)


# ── main + manifest validation ────────────────────────────────────────────


def _emit(errs: list[str]) -> int:
    if errs:
        print("Canonicals lint FAILED:", file=sys.stderr)
        for e in errs:
            print(f"  {e}", file=sys.stderr)
        return 1
    return 0


def _validate_manifest(manifest: dict, where: str) -> tuple[list[str], list[str]]:
    """Return (errors, manifest_verticals). manifest_verticals is [] on hard failure."""
    errs: list[str] = _check_unknown_keys(manifest, MANIFEST_KEYS, where)
    for required in ("schema_version", "verticals"):
        if required not in manifest:
            errs.append(f"{where}: missing required key '{required}'")
    if "schema_version" in manifest:
        sv = manifest["schema_version"]
        if sv != SCHEMA_VERSION:
            errs.append(
                f"{where}: schema_version {sv!r} != linter SCHEMA_VERSION {SCHEMA_VERSION}"
            )
    raw = manifest.get("verticals")
    if not isinstance(raw, list):
        errs.append(f"{where}: verticals must be a list")
        return (errs, [])
    string_items: list[str] = []
    for j, v in enumerate(raw):
        if not isinstance(v, str):
            errs.append(f"{where}: verticals[{j}] {v!r} is not a string")
            continue
        if not SLUG_RE.match(v):
            errs.append(f"{where}: verticals[{j}] {v!r} is not kebab-case")
        string_items.append(v)
    if string_items != sorted(string_items):
        errs.append(
            f"{where}: verticals[] not alphabetized — expected {sorted(string_items)!r}"
        )
    seen: set[str] = set()
    for v in string_items:
        if v in seen:
            errs.append(f"{where}: duplicate vertical slug '{v}'")
        seen.add(v)
    return (errs, string_items)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="lint_canonicals.py",
        description="Validate the GTM canonicals data layer (ADR-016).",
    )
    parser.add_argument(
        "--canonicals-dir",
        type=Path,
        default=DEFAULT_CANONICALS_DIR,
        help="Path to canonicals directory (default: plugins/marketing/data/canonicals).",
    )
    args = parser.parse_args(argv)
    cdir: Path = args.canonicals_dir

    if not cdir.is_dir():
        print(f"ERROR: canonicals dir not found: {cdir}", file=sys.stderr)
        return 2
    manifest_path = cdir / "_manifest.yaml"
    if not manifest_path.is_file():
        print(f"ERROR: missing _manifest.yaml at {manifest_path}", file=sys.stderr)
        return 2

    try:
        manifest = parse_yaml(manifest_path)
    except LintError as e:
        return _emit([str(e)])

    all_errs: list[str] = []
    manifest_errs, manifest_verticals = _validate_manifest(
        manifest, "_manifest.yaml"
    )
    all_errs.extend(manifest_errs)

    # 1:1 manifest-to-file mapping. Reserved-prefix convention: files starting
    # with `_` (e.g., _manifest.yaml) and non-`.yaml` (schema.json) are skipped.
    file_slugs: set[str] = set()
    for entry in sorted(p.name for p in cdir.iterdir()):
        if entry.startswith("_") or not entry.endswith(".yaml"):
            continue
        file_slugs.add(entry[:-5])

    manifest_set = set(manifest_verticals)
    for slug in sorted(manifest_set - file_slugs):
        all_errs.append(f"manifest lists '{slug}' but no {slug}.yaml found")
    for slug in sorted(file_slugs - manifest_set):
        all_errs.append(f"file {slug}.yaml present but '{slug}' not in manifest")

    parsed_by_slug: dict[str, dict] = {}
    for slug in sorted(file_slugs & manifest_set):
        v_errs, data = validate_vertical(cdir / f"{slug}.yaml")
        all_errs.extend(v_errs)
        if data is not None:
            parsed_by_slug[slug] = data

    # Cross-vertical alias collision check.
    all_canonical_slugs = set(parsed_by_slug)
    alias_to_owner: dict[str, str] = {}
    for slug in sorted(parsed_by_slug):
        data = parsed_by_slug[slug]
        aliases = data.get("aliases") or []
        if not isinstance(aliases, list):
            continue
        for alias in aliases:
            if not isinstance(alias, str):
                continue
            if alias in all_canonical_slugs:
                all_errs.append(
                    f"{slug}.yaml: alias '{alias}' collides with canonical vertical slug"
                )
            if alias in alias_to_owner:
                all_errs.append(
                    f"{slug}.yaml: alias '{alias}' already owned by "
                    f"{alias_to_owner[alias]}.yaml"
                )
            else:
                alias_to_owner[alias] = slug

    if all_errs:
        return _emit(all_errs)
    print(f"Canonicals lint OK — {len(manifest_verticals)} verticals validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
