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

SCHEMA_VERSION = 2  # Bumped 1 → 2 in BC-11852 (introduces audience_tiers block).

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
# Mirrors schema.json#/definitions/manifest. BC-11852 added audience_tiers[].
MANIFEST_KEYS = frozenset({"schema_version", "verticals", "audience_tiers"})
AUDIENCE_TIER_ENTRY_KEYS = frozenset({"slug", "axis", "display", "description", "matches"})
AUDIENCE_TIER_AXES = frozenset({"tier", "seniority", "modifier"})

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
    """Drop ' # ...' inline comments while keeping '#' inside quotes intact.

    Per YAML 1.2 §6.6, a `#` starts a comment only when preceded by whitespace
    (or appears at line start). Bare `#` inside a non-quoted token (e.g.,
    `value#nocomment`) is part of the scalar.
    """
    in_quote: str | None = None
    out_chars: list[str] = []
    prev_is_space = True  # treat "start of string" as if preceded by whitespace
    for ch in value:
        if in_quote:
            if ch == in_quote:
                in_quote = None
            out_chars.append(ch)
            prev_is_space = False
            continue
        if ch in ('"', "'"):
            in_quote = ch
            out_chars.append(ch)
            prev_is_space = False
            continue
        if ch == "#" and prev_is_space:
            break
        out_chars.append(ch)
        prev_is_space = ch.isspace()
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


_INT_RE = re.compile(r"^(0|-?[1-9][0-9]*)$")  # canonical decimal; rejects -0, 01


def parse_scalar(raw: str) -> object:
    """Parse a YAML scalar (strict YAML 1.2 subset).

    Order matters: inline-list dispatch must precede the bare-string fallback.
    Only `true`/`false` are coerced to bool (not `yes`/`no`/`YES`/`NO` — those
    stay strings in YAML 1.2). Integers are coerced ONLY when the raw form has
    no leading zero (canonical decimal — `0`, `1`, `42`, `-3`), to keep slugs
    like `01-foo`-shaped values unambiguously strings. Float coercion is
    intentionally absent.

    Raises LintError on unterminated bracket forms (`[a, b` or `a, b]`) so
    authoring typos surface loudly instead of silently parsing as strings.
    """
    s = strip_inline_comment(raw).strip()
    if not s:
        return ""
    if s.startswith("[") and s.endswith("]"):
        return parse_inline_list_of_strings(s)
    if s.startswith("[") or s.endswith("]"):
        raise LintError(f"unterminated inline list bracket: {raw!r}")
    if (s.startswith('"') and s.endswith('"')) or (
        s.startswith("'") and s.endswith("'")
    ):
        return s[1:-1]
    if s == "true":
        return True
    if s == "false":
        return False
    if _INT_RE.match(s):
        return int(s)
    return s


# ── YAML parser (subset, stdlib only) ─────────────────────────────────────


def parse_yaml(path: Path) -> dict[str, object]:
    """Parse a canonicals YAML file. Raises LintError on unrecognized shape.

    Iter-3 hardening:
      - Duplicate-key detection: every dict scope (top-level + each list-item
        dict) tracks its seen keys; a repeat raises LintError instead of
        silent last-wins (P1 from iter-3 data review).
      - Sibling block-list keys: an offer with TWO block-form list children
        (e.g., `target_personas:` followed by `target_postures:`) parses
        correctly — each opens a fresh sub_list under its own key. The
        prior over-broad "nested dict" rejection has been replaced by the
        duplicate-key check, which catches authoring typos without the
        false positive (P1 from iter-3 python review).
      - UTF-8 BOM tolerance via `encoding="utf-8-sig"` so editor-saved files
        with a BOM lint cleanly (P3 from iter-3 data review).
    """
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (UnicodeDecodeError, OSError) as e:
        # Wrap decode/read failures in LintError so they surface as clean
        # lint output instead of a Python traceback (P3 from iter-4).
        raise LintError(f"{path}: cannot read file ({type(e).__name__}: {e})") from e
    result: dict[str, object] = {}
    top_seen: set[str] = set()
    cur_list_key: str | None = None
    cur_list_kind: str | None = None  # "strings" | "dicts"
    cur_list: list[object] | None = None
    cur_list_indent: int = -1  # Indent of dict-list items in the current block.
    cur_dict: dict[str, object] | None = None
    cur_dict_seen: set[str] | None = None
    sub_list_key: str | None = None
    sub_list: list[object] | None = None

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
            cur_list_indent = -1
            cur_dict = None
            cur_dict_seen = None
            sub_list_key = None
            sub_list = None

            m = RE_TOP_KV.match(content)
            if not m:
                raise LintError(f"{path}:{lineno}: cannot parse: {content!r}")
            key, rest = m.group(1), m.group(2)
            if key in top_seen:
                raise LintError(
                    f"{path}:{lineno}: duplicate top-level key '{key}'"
                )
            top_seen.add(key)
            if rest == "":
                cur_list_key = key
                cur_list = []
                cur_list_kind = None
                result[key] = cur_list
            else:
                result[key] = parse_scalar(rest)
            continue

        if cur_list_key is None or cur_list is None:
            raise LintError(
                f"{path}:{lineno}: unexpected indented line outside a block: {content!r}"
            )

        # When a sub-list is currently open, a deeper-indent `- value` (even
        # if the value contains a colon) must be a sub-list item, not a new
        # outer dict-list entry. Skip the dict-start branch in two cases:
        #   - cur_list_kind is "strings" (block locked to strings)
        #   - sub_list is open AND this line is at deeper indent than the
        #     dict-list's items (cur_list_indent — locked when the list opens)
        in_sub_list_context = (
            sub_list is not None
            and cur_list_indent >= 0
            and indent > cur_list_indent
        )
        m = (
            None
            if cur_list_kind == "strings" or in_sub_list_context
            else RE_LIST_DICT_START.match(content)
        )
        if m:
            # Lock the dict-list indent on the FIRST item; subsequent dict-list
            # items MUST appear at exactly the same indent. A deeper-indent
            # `- key: value` would otherwise be silently treated as a new
            # sibling persona/offer when a real YAML parser would reject it as
            # a malformed mapping/sequence (P2 from iter-6 data review).
            if cur_list_indent < 0:
                cur_list_indent = indent
            elif indent != cur_list_indent:
                raise LintError(
                    f"{path}:{lineno}: list item at unexpected indent "
                    f"{indent} (locked to {cur_list_indent}): {content!r}"
                )
            cur_list_kind = "dicts"
            cur_dict = {}
            cur_dict_seen = set()
            cur_list.append(cur_dict)
            sub_list_key = None
            sub_list = None
            key, rest = m.group(1), m.group(2)
            cur_dict_seen.add(key)
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
                # May be a sub-list item under sub_list_key (deeper indent
                # than the dict-list's items).
                if (
                    sub_list is not None
                    and cur_list_indent >= 0
                    and indent > cur_list_indent
                ):
                    sub_list.append(parse_scalar(value))
                    continue
                raise LintError(
                    f"{path}:{lineno}: string list item in dict list "
                    f"(is this list intended as dict-of or list-of-strings? "
                    f"did a prior list item contain an unquoted colon?): {content!r}"
                )
            cur_list_kind = "strings"
            cur_list.append(parse_scalar(value))
            continue

        # Continuation of current dict item: `<deeper>key: value`. Sibling
        # block-form keys ARE supported — each opens a fresh sub_list under
        # its own key. Authoring typos surface via the duplicate-key detection
        # above, not via a blanket "nested dict" rejection. When a NEW sibling
        # key arrives with a scalar value (rest != ""), we MUST reset
        # sub_list_key/sub_list so a stale sub-list pointer can't silently
        # absorb later malformed `- value` lines into the prior block (P2 from
        # iter-4 code review). The required-indent threshold is derived from
        # cur_list_indent so the parser accepts any consistent author convention
        # (2/4-space outer-list indents both work — P2 from iter-5 python review).
        m = RE_DICT_CONT.match(content)
        if (
            m
            and cur_list_kind == "dicts"
            and cur_dict is not None
            and cur_dict_seen is not None
            and cur_list_indent >= 0
            and indent > cur_list_indent
        ):
            key, rest = m.group(1), m.group(2)
            if key in cur_dict_seen:
                raise LintError(
                    f"{path}:{lineno}: duplicate key '{key}' in list item"
                )
            cur_dict_seen.add(key)
            if rest == "":
                sub_list_key = key
                sub_list = []
                cur_dict[key] = sub_list
            else:
                sub_list_key = None
                sub_list = None
                cur_dict[key] = parse_scalar(rest)
            continue

        raise LintError(f"{path}:{lineno}: cannot parse: {content!r}")

    return result


# ── Validators ────────────────────────────────────────────────────────────


def _check_unknown_keys(
    data: dict[str, object], allowed: frozenset[str], where: str
) -> list[str]:
    unknown = sorted(set(data.keys()) - allowed)
    return [f"{where}: unknown key '{k}'" for k in unknown]


def _check_non_empty_string(value: object, where: str, field: str) -> list[str]:
    """Mirror schema.json `type: string, minLength: 1` for required string fields."""
    if not isinstance(value, str):
        return [f"{where}: {field} must be a string (got {type(value).__name__})"]
    if not value.strip():
        return [f"{where}: {field} must be a non-empty string"]
    return []


def validate_persona(persona: dict[str, object], vertical_slug: str, idx: int) -> list[str]:
    where = f"{vertical_slug}.yaml personas[{idx}]"
    errs: list[str] = _check_unknown_keys(persona, PERSONA_KEYS, where)
    for required in ("slug", "display", "titles"):
        if required not in persona:
            errs.append(f"{where}: missing required key '{required}'")
    if any("missing required" in e for e in errs):
        return errs
    slug = persona["slug"]
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        errs.append(f"{where}: slug {slug!r} is not kebab-case")
    errs.extend(_check_non_empty_string(persona["display"], where, "display"))
    titles = persona["titles"]
    if not isinstance(titles, list) or len(titles) < 1:
        errs.append(f"{where}: titles must be a non-empty list (got {titles!r})")
    elif not all(isinstance(t, str) and t.strip() for t in titles):
        errs.append(f"{where}: every title must be a non-empty string")
    return errs


def validate_offer(
    offer: dict[str, object],
    vertical_slug: str,
    idx: int,
    persona_slug_set: frozenset[str],
) -> list[str]:
    where = f"{vertical_slug}.yaml offers[{idx}]"
    errs: list[str] = _check_unknown_keys(offer, OFFER_KEYS, where)
    for required in ("slug", "display", "status", "posture"):
        if required not in offer:
            errs.append(f"{where}: missing required key '{required}'")
    if any("missing required" in e for e in errs):
        return errs
    slug = offer["slug"]
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        errs.append(f"{where}: slug {slug!r} is not kebab-case")
    errs.extend(_check_non_empty_string(offer["display"], where, "display"))
    # Type-guard enum membership: `[] in frozenset` raises TypeError on
    # unhashable values, which leaks a Python traceback into stderr (P1 from
    # iter-3 data review — empty `status:` / `posture:` scalar parses as
    # empty list). Validate string-shape first, then enum membership.
    status = offer["status"]
    if not isinstance(status, str):
        errs.append(
            f"{where}: status must be a string (got {type(status).__name__})"
        )
    elif status not in ALLOWED_STATUS:
        errs.append(
            f"{where}: status {status!r} not in {sorted(ALLOWED_STATUS)}"
        )
    posture = offer["posture"]
    if not isinstance(posture, str):
        errs.append(
            f"{where}: posture must be a string (got {type(posture).__name__})"
        )
    elif posture not in ALLOWED_POSTURE:
        errs.append(
            f"{where}: posture {posture!r} not in {sorted(ALLOWED_POSTURE)}"
        )
    tp = offer.get("target_personas")
    if tp is not None:
        if not isinstance(tp, list):
            errs.append(
                f"{where}: target_personas must be a list "
                f"(got {type(tp).__name__})"
            )
        else:
            seen_refs: set[str] = set()
            for j, ref in enumerate(tp):
                if not isinstance(ref, str) or not SLUG_RE.match(ref):
                    errs.append(
                        f"{where}: target_personas[{j}] {ref!r} is not kebab-case"
                    )
                    continue
                if ref in seen_refs:
                    errs.append(
                        f"{where}: target_personas[{j}] '{ref}' duplicated in same offer"
                    )
                seen_refs.add(ref)
                if ref not in persona_slug_set:
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
            seen_postures: set[str] = set()
            for j, ref in enumerate(tpo):
                if not isinstance(ref, str):
                    errs.append(
                        f"{where}: target_postures[{j}] must be a string "
                        f"(got {type(ref).__name__})"
                    )
                    continue
                if ref in seen_postures:
                    errs.append(
                        f"{where}: target_postures[{j}] {ref!r} duplicated in same offer"
                    )
                seen_postures.add(ref)
                if ref not in ALLOWED_POSTURE:
                    errs.append(
                        f"{where}: target_postures[{j}] {ref!r} not in {sorted(ALLOWED_POSTURE)}"
                    )
    for ref_key in ("replaced_by", "iterates_from"):
        ref = offer.get(ref_key)
        if ref is not None:
            if not isinstance(ref, str) or not SLUG_RE.match(ref):
                errs.append(f"{where}: {ref_key} {ref!r} is not kebab-case")
            elif ref == offer.get("slug"):
                errs.append(f"{where}: {ref_key} '{ref}' is a self-reference")
    prose_path = offer.get("prose_path")
    if prose_path is not None and not isinstance(prose_path, str):
        errs.append(
            f"{where}: prose_path must be a string "
            f"(got {type(prose_path).__name__})"
        )
    return errs


def validate_vertical(path: Path) -> tuple[list[str], dict[str, object] | None]:
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
    if not isinstance(slug, str):
        # The hint surfaces the two known authoring footguns that produce
        # non-string slug values: bare `slug:` (parses to empty list) or
        # unquoted digits like `slug: 42` (parses to int).
        if isinstance(slug, list):
            hint = "did the value get parsed as an empty list (bare `slug:` with no value)?"
        elif isinstance(slug, bool):
            # bool is a subclass of int in Python — check before the int arm.
            hint = "is the value `true`/`false`? slug must be a quoted kebab-case string."
        elif isinstance(slug, int):
            hint = "is the value an unquoted integer? slug must be a quoted kebab-case string."
        else:
            hint = "slug must be a quoted kebab-case string."
        errs.append(
            f"{where}: slug must be a string (got {type(slug).__name__}; {hint})"
        )
    elif not SLUG_RE.match(slug):
        errs.append(f"{where}: vertical slug {slug!r} is not kebab-case")
    if isinstance(slug, str) and path.stem != slug:
        errs.append(
            f"{where}: filename stem {path.stem!r} does not match slug {slug!r}"
        )
    errs.extend(_check_non_empty_string(data["display"], where, "display"))

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

    playbook_path = data.get("playbook_path")
    if playbook_path is not None and not isinstance(playbook_path, str):
        errs.append(
            f"{where}: playbook_path must be a string "
            f"(got {type(playbook_path).__name__})"
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

    # Sibling-offer references (replaced_by / iterates_from): existence check.
    replaces_edges: dict[str, str] = {}
    iterates_edges: dict[str, str] = {}
    if isinstance(offers, list):
        for i, o in enumerate(offers):
            if not isinstance(o, dict):
                continue
            o_slug = o.get("slug")
            for ref_key in ("replaced_by", "iterates_from"):
                ref = o.get(ref_key)
                if isinstance(ref, str) and SLUG_RE.match(ref):
                    if ref not in offer_slug_set:
                        errs.append(
                            f"{where} offers[{i}]: {ref_key} '{ref}' not defined in offers[]"
                        )
                    elif isinstance(o_slug, str) and o_slug != ref:
                        if ref_key == "replaced_by":
                            replaces_edges[o_slug] = ref
                        else:
                            iterates_edges[o_slug] = ref

    # Cycle detection: walk each edge map. A cycle is reported ONCE per
    # distinct loop — every node touched during a walk (whether cyclic or
    # acyclic) gets added to `done` so we skip re-walks from any of its
    # members. visited_index gives O(1) cycle-entry lookup.
    for edges, label in (
        (replaces_edges, "replaced_by"),
        (iterates_edges, "iterates_from"),
    ):
        done: set[str] = set()
        for start in list(edges):
            if start in done:
                continue
            visited_order: list[str] = []
            visited_index: dict[str, int] = {}
            cur: str | None = start
            while cur is not None and cur not in visited_index:
                visited_index[cur] = len(visited_order)
                visited_order.append(cur)
                cur = edges.get(cur)
            if cur is not None:
                entry = visited_index[cur]
                cycle_nodes = visited_order[entry:] + [cur]
                errs.append(
                    f"{where}: cycle in {label} chain: {' -> '.join(cycle_nodes)}"
                )
            done.update(visited_index)

    return (errs, data)


# ── main + manifest validation ────────────────────────────────────────────


def _emit(errs: list[str]) -> int:
    if errs:
        print("Canonicals lint FAILED:", file=sys.stderr)
        for e in errs:
            print(f"  {e}", file=sys.stderr)
        return 1
    return 0


def _validate_manifest(manifest: dict[str, object], where: str) -> tuple[list[str], list[str]]:
    """Return (errors, manifest_verticals). manifest_verticals is [] on hard failure."""
    errs: list[str] = _check_unknown_keys(manifest, MANIFEST_KEYS, where)
    for required in ("schema_version", "verticals"):
        if required not in manifest:
            errs.append(f"{where}: missing required key '{required}'")
    if "schema_version" in manifest:
        sv = manifest["schema_version"]
        # Python's `bool` is a subclass of `int`, so `True == 1` silently equates
        # `schema_version: true` to SCHEMA_VERSION=1. Reject non-int explicitly
        # (P2 from iter-4 data review).
        if not isinstance(sv, int) or isinstance(sv, bool):
            errs.append(
                f"{where}: schema_version must be an integer "
                f"(got {type(sv).__name__})"
            )
        elif sv != SCHEMA_VERSION:
            errs.append(
                f"{where}: schema_version {sv!r} != linter SCHEMA_VERSION {SCHEMA_VERSION}"
            )
    raw = manifest.get("verticals")
    if not isinstance(raw, list):
        errs.append(f"{where}: verticals must be a list")
        return (errs, [])
    string_items: list[str] = []
    valid_for_order: list[str] = []
    for j, v in enumerate(raw):
        if not isinstance(v, str):
            errs.append(f"{where}: verticals[{j}] {v!r} is not a string")
            continue
        if not SLUG_RE.match(v):
            errs.append(f"{where}: verticals[{j}] {v!r} is not kebab-case")
            string_items.append(v)
            continue
        string_items.append(v)
        valid_for_order.append(v)
    # Only flag "empty" when verticals[] is *actually* empty. If entries exist
    # but failed per-item type checks (e.g., non-string), the per-item errors
    # already explain the failure — don't pile on a misleading "empty" error.
    if len(raw) == 0:
        errs.append(
            f"{where}: verticals[] is empty — manifest must list at least one vertical"
        )
    # Run alphabetization check on the kebab-valid subset only — including
    # invalid items would emit a confusing "expected [...]" list that
    # contradicts the separate non-kebab errors (P3 from iter-6 python review).
    if valid_for_order != sorted(valid_for_order):
        errs.append(
            f"{where}: verticals[] not alphabetized — expected {sorted(valid_for_order)!r}"
        )
    seen: set[str] = set()
    for v in string_items:
        if v in seen:
            errs.append(f"{where}: duplicate vertical slug '{v}'")
        seen.add(v)
    # BC-11852 — validate audience_tiers[] block if present.
    audience_tiers = manifest.get("audience_tiers")
    if audience_tiers is not None:
        errs.extend(_validate_audience_tiers(audience_tiers, where))
    return (errs, string_items)


def _validate_audience_tiers(
    audience_tiers: object, where: str
) -> list[str]:
    """Validate the BC-11852 audience_tiers[] block in _manifest.yaml.

    Each entry must:
      - be a mapping
      - have required keys slug + axis + display
      - axis ∈ {tier, seniority, modifier}
      - slug be kebab-case
      - matches[] (if present) be a list of non-empty strings

    Cross-entry rule: slug values must be unique within an axis. A 'reverified'
    modifier and a 'reverified' tier would collide (the auto-classifier picks
    by axis-keyed lookup, but reusing the slug across axes makes audits
    confusing — keep slugs globally unique per ADR-020).
    """
    errs: list[str] = []
    label = f"{where} audience_tiers"
    if not isinstance(audience_tiers, list):
        return [f"{label}: must be a list (got {type(audience_tiers).__name__})"]
    if len(audience_tiers) == 0:
        return [f"{label}: list is empty — schema requires >=1 entry"]
    seen_slugs: set[str] = set()
    for i, entry in enumerate(audience_tiers):
        elabel = f"{label}[{i}]"
        if not isinstance(entry, dict):
            errs.append(f"{elabel}: must be a mapping (got {type(entry).__name__})")
            continue
        errs.extend(_check_unknown_keys(entry, AUDIENCE_TIER_ENTRY_KEYS, elabel))
        for required in ("slug", "axis", "display"):
            if required not in entry:
                errs.append(f"{elabel}: missing required key '{required}'")
        if any("missing required" in e for e in errs[-3:]):
            continue
        slug = entry["slug"]
        if not isinstance(slug, str) or not SLUG_RE.match(slug):
            errs.append(f"{elabel}: slug {slug!r} is not kebab-case")
        elif slug in seen_slugs:
            errs.append(f"{elabel}: duplicate slug '{slug}' in audience_tiers[]")
        else:
            seen_slugs.add(slug)
        axis = entry["axis"]
        if not isinstance(axis, str) or axis not in AUDIENCE_TIER_AXES:
            errs.append(
                f"{elabel}: axis {axis!r} not in {sorted(AUDIENCE_TIER_AXES)}"
            )
        errs.extend(_check_non_empty_string(entry["display"], elabel, "display"))
        desc = entry.get("description")
        if desc is not None and not isinstance(desc, str):
            errs.append(
                f"{elabel}: description must be a string "
                f"(got {type(desc).__name__})"
            )
        matches = entry.get("matches")
        if matches is not None:
            if not isinstance(matches, list):
                errs.append(
                    f"{elabel}: matches must be a list "
                    f"(got {type(matches).__name__})"
                )
            else:
                for j, mtoken in enumerate(matches):
                    if not isinstance(mtoken, str) or not mtoken.strip():
                        errs.append(
                            f"{elabel}: matches[{j}] must be a non-empty string"
                        )
    return errs


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
    # Symlinks are rejected — the canonicals contract is one regular file per
    # vertical (P2 from iter-3 data review).
    file_slugs: set[str] = set()
    # Track slugs whose corresponding file failed a pre-parse check (symlink,
    # non-regular file). These are accounted for in the 1:1 manifest-to-file
    # cross-check so we don't emit a duplicate "manifest lists X but no
    # X.yaml found" error for the same slug we already rejected.
    invalid_slugs: set[str] = set()
    for p in sorted(cdir.iterdir(), key=lambda x: x.name):
        entry = p.name
        if (
            entry.startswith("_")
            or entry.startswith(".")
            or not entry.endswith(".yaml")
        ):
            continue
        slug = entry[:-5]
        if p.is_symlink():
            all_errs.append(
                f"{entry}: symlinks not allowed in canonicals dir"
            )
            invalid_slugs.add(slug)
            continue
        # Reject non-regular files (directories named *.yaml, FIFOs, sockets).
        # Without this guard, read_text() on a FIFO would hang the lint, and
        # a directory would surface a confusing "manifest mismatch" error.
        if not p.is_file():
            all_errs.append(
                f"{entry}: not a regular file (directory/FIFO/socket rejected)"
            )
            invalid_slugs.add(slug)
            continue
        file_slugs.add(slug)

    manifest_set = set(manifest_verticals)
    # Skip slugs we already rejected (symlink, non-regular file) so we don't
    # double-report them via the missing-file cross-check.
    for slug in sorted(manifest_set - file_slugs - invalid_slugs):
        all_errs.append(f"manifest lists '{slug}' but no {slug}.yaml found")
    for slug in sorted(file_slugs - manifest_set):
        all_errs.append(f"file {slug}.yaml present but '{slug}' not in manifest")

    parsed_by_slug: dict[str, dict[str, object]] = {}
    for slug in sorted(file_slugs & manifest_set):
        v_errs, data = validate_vertical(cdir / f"{slug}.yaml")
        all_errs.extend(v_errs)
        if data is not None:
            parsed_by_slug[slug] = data

    # Cross-vertical alias collision check.
    # Two failure modes are reported with distinct messages so authors can tell
    # them apart at a glance:
    #   - intra-file duplicate (`aliases: [foo, foo]` in one file)
    #   - cross-file collision (different files claim the same alias)
    # The cross-file message names the OTHER owner explicitly, never the
    # reporter, so an "owned by self" diagnostic is impossible.
    all_canonical_slugs = set(parsed_by_slug)
    alias_to_owner: dict[str, str] = {}
    for slug in sorted(parsed_by_slug):
        data = parsed_by_slug[slug]
        aliases = data.get("aliases") or []
        if not isinstance(aliases, list):
            continue
        seen_in_file: set[str] = set()
        for alias in aliases:
            if not isinstance(alias, str):
                continue
            if alias in seen_in_file:
                all_errs.append(
                    f"{slug}.yaml: duplicate alias '{alias}' within file"
                )
                continue
            seen_in_file.add(alias)
            if alias in all_canonical_slugs:
                all_errs.append(
                    f"{slug}.yaml: alias '{alias}' collides with canonical vertical slug"
                )
            elif alias in alias_to_owner:
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
