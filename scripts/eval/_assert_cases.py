#!/usr/bin/env python3
"""M3 unit cases — one named case per assert_lib primitive, pass AND fail (BC-12589).

Each case exercises one `assert_lib` primitive and returns True iff the primitive
*behaved correctly* for that scenario (a pass-case produces no diffs; a fail-case
produces a diff naming the right path). `main(case)` exits 0 when the primitive
behaved correctly, 1 otherwise — so the bash harness asserts a single exit 0 per
case and gets granular, self-describing counts (the test_build_manifest.sh idiom).
`--list` prints every case name so the harness loops over them in lock-step (no
hand-maintained duplicate list).

This is the "test the tester" applied to M3: it proves the assertion library both
PASSES known-good and FAILS known-bad before we trust it to gate a build (DP2-7).
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import assert_lib as A  # noqa: E402


def _has(diffs, needle: str) -> bool:
    return any(needle in d for d in diffs)


# ── schema_validate ──────────────────────────────────────────────────────────

_SCHEMA = {
    "type": "object",
    "required": ["a", "b"],
    "properties": {
        "a": {"type": "integer", "const": 1},
        "b": {"type": ["string", "null"]},
        "c": {"type": "string", "enum": ["x", "y"]},
        "d": {"type": "array", "items": {"type": "integer"}},
    },
}


def schema_valid() -> bool:
    return A.schema_validate({"a": 1, "b": None, "c": "x", "d": [1, 2]}, _SCHEMA) == []


def schema_missing_required() -> bool:
    diffs = A.schema_validate({"a": 1}, _SCHEMA)
    return _has(diffs, ".b") and _has(diffs, "required key missing")


def schema_wrong_type() -> bool:
    diffs = A.schema_validate({"a": "1", "b": "ok"}, _SCHEMA)
    return _has(diffs, "$.a") and _has(diffs, "expected type integer")


def schema_enum_violation() -> bool:
    diffs = A.schema_validate({"a": 1, "b": "ok", "c": "z"}, _SCHEMA)
    return _has(diffs, "$.c") and _has(diffs, "enum")


def schema_const_violation() -> bool:
    diffs = A.schema_validate({"a": 2, "b": "ok"}, _SCHEMA)
    return _has(diffs, "$.a") and _has(diffs, "const")


def schema_null_union_ok() -> bool:
    # b accepts null; supplying null must NOT diff.
    return A.schema_validate({"a": 1, "b": None}, _SCHEMA) == []


def schema_nested_items_bad() -> bool:
    diffs = A.schema_validate({"a": 1, "b": "ok", "d": [1, "two", 3]}, _SCHEMA)
    return _has(diffs, "$.d[1]") and _has(diffs, "expected type integer")


_SCHEMA_CLOSED = {
    "type": "object",
    "additionalProperties": False,
    "required": ["a"],
    "properties": {"a": {"type": "integer"}},
}


def schema_additional_props_ok() -> bool:
    return A.schema_validate({"a": 1}, _SCHEMA_CLOSED) == []


def schema_additional_props_bad() -> bool:
    diffs = A.schema_validate({"a": 1, "leaked": "x"}, _SCHEMA_CLOSED)
    return _has(diffs, "$.leaked") and _has(diffs, "unexpected property")


def schema_const_bool_not_int() -> bool:
    # True must NOT satisfy const 1 (JSON boolean != integer).
    diffs = A.schema_validate(True, {"const": 1})
    return _has(diffs, "const")


def schema_enum_bool_not_int() -> bool:
    diffs = A.schema_validate(True, {"enum": [1]})
    return _has(diffs, "enum")


# ── golden_compare ───────────────────────────────────────────────────────────

_GOLD = {"x": 1, "list": [{"k": "v"}, {"k": "w"}]}


def golden_equal() -> bool:
    return A.golden_compare({"x": 1, "list": [{"k": "v"}, {"k": "w"}]}, _GOLD) == []


def golden_scalar_diff() -> bool:
    diffs = A.golden_compare({"x": 2, "list": [{"k": "v"}, {"k": "w"}]}, _GOLD)
    return _has(diffs, "$.x") and _has(diffs, "golden 1, got 2")


def golden_missing_key() -> bool:
    diffs = A.golden_compare({"list": [{"k": "v"}, {"k": "w"}]}, _GOLD)
    return _has(diffs, "$.x") and _has(diffs, "missing in actual")


def golden_extra_key() -> bool:
    diffs = A.golden_compare({"x": 1, "list": [{"k": "v"}, {"k": "w"}], "z": 9}, _GOLD)
    return _has(diffs, "$.z") and _has(diffs, "unexpected extra key")


def golden_array_length() -> bool:
    diffs = A.golden_compare({"x": 1, "list": [{"k": "v"}]}, _GOLD)
    return _has(diffs, "$.list") and _has(diffs, "array length mismatch")


def golden_type_mismatch() -> bool:
    diffs = A.golden_compare({"x": "1", "list": [{"k": "v"}, {"k": "w"}]}, _GOLD)
    return _has(diffs, "$.x") and _has(diffs, "type mismatch")


# ── key_fields ───────────────────────────────────────────────────────────────

_INST = {"entity": "nites", "linear": {"milestone_id": None}, "year": 2026}


def keyfields_match() -> bool:
    return A.key_fields(_INST, {
        "entity": "nites", "linear.milestone_id": None, "year": 2026,
    }) == []


def keyfields_value_mismatch() -> bool:
    diffs = A.key_fields(_INST, {"entity": "supply"})
    return _has(diffs, "$.entity") and _has(diffs, "expected 'supply'")


def keyfields_none_ok() -> bool:
    return A.key_fields(_INST, {"linear.milestone_id": None}) == []


def keyfields_absent_path() -> bool:
    diffs = A.key_fields(_INST, {"salesforce.campaign_id": None})
    return _has(diffs, "salesforce.campaign_id") and _has(diffs, "absent")


def keyfields_bool_not_int() -> bool:
    # A boolean True must NOT satisfy an expected integer 1 (JSON-type-aware).
    diffs = A.key_fields({"x": True}, {"x": 1})
    return _has(diffs, "$.x") and _has(diffs, "expected 1")


# ── contains / no_match ──────────────────────────────────────────────────────


def contains_all_present() -> bool:
    return A.contains("a b c", ["a", "c"]) == []


def contains_missing() -> bool:
    diffs = A.contains("a b c", ["a", "zzz"])
    return _has(diffs, "missing required substring 'zzz'")


def nomatch_clean() -> bool:
    return A.no_match("no tokens here", r"\{\{\w+\}\}") == []


def nomatch_hit() -> bool:
    diffs = A.no_match("leftover {{slug}} token", r"\{\{\w+\}\}")
    return _has(diffs, "{{slug}}")


CASES = {
    "schema-valid": schema_valid,
    "schema-missing-required": schema_missing_required,
    "schema-wrong-type": schema_wrong_type,
    "schema-enum-violation": schema_enum_violation,
    "schema-const-violation": schema_const_violation,
    "schema-null-union-ok": schema_null_union_ok,
    "schema-nested-items-bad": schema_nested_items_bad,
    "schema-additional-props-ok": schema_additional_props_ok,
    "schema-additional-props-bad": schema_additional_props_bad,
    "schema-const-bool-not-int": schema_const_bool_not_int,
    "schema-enum-bool-not-int": schema_enum_bool_not_int,
    "golden-equal": golden_equal,
    "golden-scalar-diff": golden_scalar_diff,
    "golden-missing-key": golden_missing_key,
    "golden-extra-key": golden_extra_key,
    "golden-array-length": golden_array_length,
    "golden-type-mismatch": golden_type_mismatch,
    "keyfields-match": keyfields_match,
    "keyfields-value-mismatch": keyfields_value_mismatch,
    "keyfields-none-ok": keyfields_none_ok,
    "keyfields-absent-path": keyfields_absent_path,
    "keyfields-bool-not-int": keyfields_bool_not_int,
    "contains-all-present": contains_all_present,
    "contains-missing": contains_missing,
    "nomatch-clean": nomatch_clean,
    "nomatch-hit": nomatch_hit,
}


def main(argv: list[str]) -> int:
    if not argv or argv[0] == "--list":
        print("\n".join(CASES))
        return 0
    case = argv[0]
    fn = CASES.get(case)
    if fn is None:
        sys.stderr.write(f"unknown case: {case}\n")
        return 2
    try:
        ok = fn()
    except Exception as exc:  # a primitive raising is itself a failure
        sys.stderr.write(f"case {case} raised: {exc!r}\n")
        return 1
    if not ok:
        sys.stderr.write(f"case {case}: primitive did not behave as expected\n")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
