#!/usr/bin/env python3
"""Canonical ADR-number extraction — the SINGLE filename→number rule (BC-12698).

WHY THIS MODULE EXISTS
----------------------
Two ADR-number guards now read the same rule:
  * the WITHIN-repo duplicate guard `lint_adr_numbers.py` (BC-12617), which scans
    a `docs/decisions/` DIRECTORY, and
  * the CROSS-PR collision guard `lint_cross_pr_adr_numbers.py` (BC-12698), which
    consumes FILENAMES gathered from `gh` (the files each open PR adds).
If each owned its own copy of the `^(\\d+)-.+\\.md$` + `int()` rule, a future tweak
to one (say, a change to how zero-pad or a four-digit number is handled) would
silently diverge producer↔consumer: a cross-PR `021` vs `21` could be flagged by
one guard and missed by the other. Factoring the rule here — imported byte-for-byte
by both — makes that drift impossible (the BC-12594 "reuse the canonical regex
byte-identical, lock it with a parity test" lesson). The parity test lives in the
cross-PR guard's self-test, asserting both guards classify a shared battery
identically.

THE RULE
--------
An ADR number = the leading run of digits of a `<digits>-<slug>.md` filename,
NORMALIZED with `int()`. The normalization is load-bearing: `021-foo.md` and
`21-bar.md` are the SAME number `21`, so a zero-pad variant cannot sneak a
duplicate past a naive string comparison. The `-<slug>` is MANDATORY: `021-.md`
(empty slug) and `099.md` (no hyphen) are NOT ADRs. Anything that is not a
`<digits>-<slug>.md` name — `README.md`, a non-numeric-prefixed `.md`, a
non-`.md` file — is not an ADR and yields None.

This module takes a BARE FILENAME (basename), not a path: callers that hold a
`docs/decisions/foo/bar.md`-style path must pass only the final component. It does
no filesystem I/O — it is a pure string classifier, so it is safe to call on
filenames that do not (or no longer) exist on disk, which is exactly what the
cross-PR guard needs (it classifies filenames reported by the GitHub API).
"""
from __future__ import annotations

import re

# An ADR filename: a leading run of digits, a hyphen, a non-empty slug, then `.md`.
# The captured digits are the ADR NUMBER. A name that does not match is not an ADR.
# This is THE canonical pattern — do not re-declare it in any consumer; import
# `adr_number` instead (see module docstring).
_ADR_RE = re.compile(r"^(\d+)-.+\.md$")


def adr_number(filename: str) -> int | None:
    """Return the NORMALIZED ADR number for an ADR basename, or None if not an ADR.

    `int()`-normalized, so `adr_number("021-foo.md") == adr_number("21-bar.md") == 21`
    and the whole zero-family `000`/`00`/`0` collapses to `0`. Pure string parse —
    no filesystem access, so it works on filenames that exist only as API/diff
    output. Pass a BARE filename; a path with directory components will not match
    (the `^` anchors to the start of the string)."""
    m = _ADR_RE.match(filename)
    if m is None:
        return None
    return int(m.group(1))
