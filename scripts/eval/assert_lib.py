#!/usr/bin/env python3
"""M3 — the behavioral-eval assertion library (BC-12589).

Pure, stdlib-only assertion primitives shared by every command's behavioral eval
(ADR-028 § 5). The runner (`run_eval.py`, M2) executes a command's emit mode into
a sandbox, collects the produced artifacts, and delegates *what counts as correct*
to the four primitives here. They are deliberately generic — they know nothing
about plan-campaign or any specific artifact — so a second plugin's eval reuses
them unchanged (BC-12589 AC: "reusable across all plugins").

The primitives, each returning a list of human-readable diff strings (empty list =
pass), so a red eval names the artifact + JSON path + expected-vs-got rather than
just returning False (the originating-session review's "failure output quality"):

  * schema_validate(instance, schema)  — a MINIMAL hand-rolled JSON-Schema-subset
        validator (no `jsonschema` dependency — repo is stdlib-only per CLAUDE.md;
        same hand-roll posture as build_manifest.py's YAML mini-parser). Supported
        keywords ONLY (documented so there is no magic): `type` (a single name or a
        list of names; the name "null" matches None), `required`, `properties`
        (recurses), `additionalProperties: false` (reject object keys not in
        `properties` — catches a builder leaking an extra field), `items` (one
        schema applied to every array element), `enum`, `const`. Anything else in a
        schema is ignored — keep schemas to this subset.
  * golden_compare(actual, expected)   — deep structural equality of two JSON-able
        values, reporting the first divergence per path (type mismatch, scalar
        mismatch, missing/extra object keys, list-length mismatch, per-element
        divergence). The eval golden-compares a *structural projection* of an
        artifact (built by the adapter), NEVER the raw artifact — drop prose and
        real IDs before comparing (DP2-6).
  * key_fields(instance, expectations) — assert specific dotted-path values
        (e.g. "linear.milestone_id" is None, "entity" == "nites"). The companion
        to schema_validate: schema checks SHAPE, key_fields checks VALUES.
  * contains(text, needles, label)     — assert each required substring/line is
        present in a text blob (the key-line / structural check for prose-bearing
        artifacts: issue-description contract lines, brief section headers). This is
        how DP2-6 keeps descriptions asserted by SHAPE, immune to verbatim edits.

`Result` bundles a pass flag + the accumulated diffs; `combine()` merges several.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

# ── result type ──────────────────────────────────────────────────────────


@dataclass
class Result:
    """Outcome of one or more assertions. `ok` is True iff `diffs` is empty."""

    diffs: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.diffs


def combine(*results: "Result | list[str]") -> Result:
    """Merge Results and/or raw diff lists into one Result."""
    merged: list[str] = []
    for r in results:
        if isinstance(r, Result):
            merged.extend(r.diffs)
        else:
            merged.extend(r)
    return Result(merged)


# ── path helpers ───────────────────────────────────────────────────────────


def get_path(obj, dotted: str):
    """Resolve a dotted path ("linear.milestone_id") against nested dicts.

    Returns the sentinel ``_MISSING`` if any segment is absent so callers can
    distinguish "present and None" from "absent". Only object keys are supported
    (key_fields targets manifest objects — no array indexing needed); a non-dict
    encountered mid-path resolves to ``_MISSING``.
    """
    cur = obj
    for seg in dotted.split("."):
        if isinstance(cur, dict) and seg in cur:
            cur = cur[seg]
        else:
            return _MISSING
    return cur


class _Missing:
    def __repr__(self) -> str:  # pragma: no cover - cosmetic
        return "<missing>"


_MISSING = _Missing()


def _typename(value) -> str:
    """JSON-Schema type name for a Python value (so diffs speak schema-ese)."""
    if value is None:
        return "null"
    if isinstance(value, bool):  # bool before int — bool is a subclass of int
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def _matches_type(value, type_spec) -> bool:
    """True if `value`'s JSON type satisfies `type_spec` (a name or list of names).

    `integer` accepts ints (not bools); `number` accepts ints or floats (not bools).
    """
    names = [type_spec] if isinstance(type_spec, str) else list(type_spec)
    actual = _typename(value)
    for name in names:
        if name == actual:
            return True
        # An integer is a valid `number`; a bare int also satisfies `number`.
        if name == "number" and actual == "integer":
            return True
    return False


def _json_eq(a, b) -> bool:
    """JSON-type-aware equality. Plain `==` conflates `True`/`1` and `False`/`0`
    (and `1`/`1.0`) in Python; an eval must not treat a boolean as the integer 1.
    Require the JSON type to match first, then the value (`_typename` already
    separates boolean / integer / number)."""
    return _typename(a) == _typename(b) and a == b


# ── primitive 1: schema_validate ────────────────────────────────────────────


def schema_validate(instance, schema, path: str = "$", artifact: str = "") -> list[str]:
    """Validate `instance` against a JSON-Schema-*subset* (see module docstring).

    Returns diff strings (empty = valid). Recurses through `properties` and
    `items`; reports type mismatches, missing required keys, and enum/const
    violations with the offending JSON path.
    """
    prefix = f"{artifact} " if artifact else ""
    diffs: list[str] = []

    if "type" in schema and not _matches_type(instance, schema["type"]):
        want = schema["type"]
        want_s = want if isinstance(want, str) else "[" + ", ".join(want) + "]"
        diffs.append(
            f"{prefix}{path}: expected type {want_s}, got {_typename(instance)} "
            f"({instance!r})"
        )
        # A wrong top-level type makes deeper checks meaningless — stop here.
        return diffs

    if "const" in schema and not _json_eq(instance, schema["const"]):
        diffs.append(f"{prefix}{path}: expected const {schema['const']!r}, got {instance!r}")

    if "enum" in schema and not any(_json_eq(instance, e) for e in schema["enum"]):
        diffs.append(
            f"{prefix}{path}: {instance!r} is not one of enum {schema['enum']!r}"
        )

    if isinstance(instance, dict):
        props = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in instance:
                diffs.append(f"{prefix}{path}.{key}: required key missing")
        for key, subschema in props.items():
            if key in instance:
                diffs.extend(
                    schema_validate(instance[key], subschema, f"{path}.{key}", artifact)
                )
        if schema.get("additionalProperties") is False:
            for key in instance:
                if key not in props:
                    diffs.append(
                        f"{prefix}{path}.{key}: unexpected property "
                        f"(not in schema; additionalProperties:false)"
                    )

    if isinstance(instance, list) and "items" in schema:
        for i, elem in enumerate(instance):
            diffs.extend(
                schema_validate(elem, schema["items"], f"{path}[{i}]", artifact)
            )

    return diffs


# ── primitive 2: golden_compare ─────────────────────────────────────────────


def golden_compare(actual, expected, path: str = "$", artifact: str = "") -> list[str]:
    """Deep structural compare of two JSON-able values; precise per-path diffs.

    The eval compares a *projection* of the artifact (adapter-built, prose/IDs
    dropped) against a committed golden — so this asserts the deterministic
    structure only. Reports type mismatches, scalar inequality, object key
    add/drop, array-length mismatch, and recurses into matching containers.
    """
    prefix = f"{artifact} " if artifact else ""
    diffs: list[str] = []

    if _typename(actual) != _typename(expected):
        diffs.append(
            f"{prefix}{path}: type mismatch — golden {_typename(expected)} "
            f"({expected!r}), got {_typename(actual)} ({actual!r})"
        )
        return diffs

    if isinstance(expected, dict):
        for key in expected:
            if key not in actual:
                diffs.append(f"{prefix}{path}.{key}: missing in actual (golden has {expected[key]!r})")
            else:
                diffs.extend(
                    golden_compare(actual[key], expected[key], f"{path}.{key}", artifact)
                )
        for key in actual:
            if key not in expected:
                diffs.append(f"{prefix}{path}.{key}: unexpected extra key in actual ({actual[key]!r})")
    elif isinstance(expected, list):
        if len(actual) != len(expected):
            diffs.append(
                f"{prefix}{path}: array length mismatch — golden {len(expected)}, "
                f"got {len(actual)}"
            )
        for i in range(min(len(actual), len(expected))):
            diffs.extend(
                golden_compare(actual[i], expected[i], f"{path}[{i}]", artifact)
            )
    else:  # scalar
        if actual != expected:
            diffs.append(f"{prefix}{path}: golden {expected!r}, got {actual!r}")

    return diffs


# ── primitive 3: key_fields ─────────────────────────────────────────────────


def key_fields(instance, expectations: dict, artifact: str = "") -> list[str]:
    """Assert specific dotted-path values. `expectations` maps a dotted path to its
    expected value (use Python None to assert JSON null). An absent path is a diff
    distinct from a present-but-wrong value."""
    prefix = f"{artifact} " if artifact else ""
    diffs: list[str] = []
    for path, expected in expectations.items():
        got = get_path(instance, path)
        if got is _MISSING:
            diffs.append(f"{prefix}$.{path}: expected {expected!r}, but path is absent")
        elif not _json_eq(got, expected):
            diffs.append(f"{prefix}$.{path}: expected {expected!r}, got {got!r}")
    return diffs


# ── primitive 4: contains ───────────────────────────────────────────────────


def contains(text: str, needles, label: str = "") -> list[str]:
    """Assert every needle (substring) appears in `text`. The key-line / structural
    check for prose-bearing artifacts — asserts SHAPE (a contract line is present),
    never the surrounding prose, so verbatim copy edits don't flake the eval."""
    prefix = f"{label}: " if label else ""
    if not isinstance(text, str):
        return [f"{prefix}expected text, got {_typename(text)} ({text!r})"]
    return [f"{prefix}missing required substring {n!r}" for n in needles if n not in text]


def no_match(text: str, pattern: str, label: str = "") -> list[str]:
    """Assert a regex does NOT match anywhere in `text` (e.g. no leftover `{{slot}}`
    template tokens). Lists every offending matched string (group(0), so a pattern
    with capture groups still reports the full match, not the group) so the diff is
    actionable."""
    prefix = f"{label}: " if label else ""
    if not isinstance(text, str):
        return [f"{prefix}expected text, got {_typename(text)} ({text!r})"]
    hits = [m.group(0) for m in re.finditer(pattern, text)]
    return [f"{prefix}unexpected match for /{pattern}/: {h!r}" for h in dict.fromkeys(hits)]
