#!/usr/bin/env python3
"""ADR-number duplicate guard (BC-12617).

Machine-checks that no two ADRs under `docs/decisions/` share a number.

THE SILENT FAILURE THIS PREVENTS
--------------------------------
ADRs live at `docs/decisions/NNN-slug.md` and are numbered by reading the "next
free number" off `main`. With several branches open at once, each reads the same
*stale* `main`, independently grabs the SAME `NNN`, and gives it a DIFFERENT slug.
Git never flags the collision on merge — the filenames differ
(`021-raise-a-ticket-intake.md` vs `021-sfdx-hardis-adoption.md`) — so the second
merge SILENTLY creates a duplicate-numbered ADR. Each collision then costs a full
renumber cascade (file rename + CLAUDE.md index + cross-ADR `Related:` links +
Linear bodies). This happened 4× in one week (2026-06-05). This guard is the loud
backstop: it fails the instant two same-numbered files coexist in the tree (within
a branch, or post-merge on `main`).

DUPLICATE-DETECTION, NOT CONTIGUITY
-----------------------------------
The ONLY thing flagged is a number used by more than one file. Gaps are
LEGITIMATE and never flagged: the live set is 001-028 with 004/005/006 absent and
001 Withdrawn. This guard says nothing about sequence, gaps, or "next free" — only
"no number appears twice."

EXTRACTION
----------
An ADR number = the leading run of digits of a `docs/decisions/<digits>-<slug>.md`
filename, NORMALIZED with `int()`. The normalization is load-bearing: `021-foo.md`
and `21-bar.md` collide on the same number `21`, so a zero-pad variant cannot sneak
a duplicate past a naive string comparison. Anything that is not a
`<digits>-<slug>.md` file is IGNORED — a `README.md`, a non-numeric-prefixed `.md`,
a non-`.md` file, or a subdirectory cannot crash the guard or be mistaken for an
ADR.

Usage:
  lint_adr_numbers.py [DECISIONS_DIR]
    no arg → the repo-anchored docs/decisions/ directory.
Exit 0 = all ADR numbers unique, 1 = ≥1 duplicate number, 2 = usage / IO error.
"""
from __future__ import annotations

import sys
import re
from collections import defaultdict
from pathlib import Path
from typing import IO

# scripts/_lib/ → repo root is two levels up (parents[2]).
_REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIR = _REPO_ROOT / "docs" / "decisions"

# An ADR filename: a leading run of digits, a hyphen, a non-empty slug, then `.md`.
# The captured digits are the ADR NUMBER. A filename that does not match is not an
# ADR and is ignored entirely (README.md, non-numeric .md, *.txt, etc.).
_ADR_RE = re.compile(r"^(\d+)-.+\.md$")


def group_by_number(decisions_dir: Path) -> dict[int, list[str]]:
    """Map each NORMALIZED ADR number (int) → sorted list of filenames using it.

    Only regular files whose name matches `<digits>-<slug>.md` contribute; every
    other directory entry is ignored. `int()` normalization means `021` and `21`
    map to the same key, so a zero-pad variant is a collision, not a near-miss."""
    groups: dict[int, list[str]] = defaultdict(list)
    for entry in decisions_dir.iterdir():
        if not entry.is_file():
            continue
        m = _ADR_RE.match(entry.name)
        if m:
            groups[int(m.group(1))].append(entry.name)
    # Sort filenames within each group for deterministic, diff-stable output
    # (the only sort that matters — iterdir() order is otherwise irrelevant
    # since group keys are emitted via sorted() in main()).
    return {num: sorted(files) for num, files in groups.items()}


def _usage(stream: IO[str]) -> None:
    print("usage: lint_adr_numbers.py [DECISIONS_DIR]", file=stream)


def main(argv: list[str]) -> int:
    args = argv[1:]
    if args and args[0] in ("-h", "--help"):
        _usage(sys.stdout)
        return 0

    decisions_dir = Path(args[0]) if args else DEFAULT_DIR

    if not decisions_dir.is_dir():
        print(
            f"ADR-number guard: ERROR — decisions dir not found: {decisions_dir}",
            file=sys.stderr,
        )
        return 2

    # An unreadable/racing dir is an IO error (rc=2), NOT a duplicate (rc=1):
    # conflating the two would defeat the rc-discipline fixture (6) protects and
    # surface a traceback as "found duplicates". Mirrors the sibling lint.
    try:
        groups = group_by_number(decisions_dir)
    except OSError as exc:
        print(
            f"ADR-number guard: ERROR — cannot read {decisions_dir}: {exc}",
            file=sys.stderr,
        )
        return 2

    duplicates = {num: files for num, files in groups.items() if len(files) > 1}

    if duplicates:
        print(
            f"ADR-number guard: FAIL — {len(duplicates)} duplicated ADR number(s) "
            f"in {decisions_dir}"
        )
        for num in sorted(duplicates):
            files = duplicates[num]
            print(f"  number {num} used by {len(files)} files:")
            for filename in files:
                print(f"    {filename}")
        print(
            "  → renumber all but one. Read the next free number off origin/main "
            "and claim it in your PR/issue title before re-authoring."
        )
        return 1

    total = sum(len(files) for files in groups.values())
    print(
        f"ADR-number guard: OK — {total} ADR(s), all numbers unique "
        f"in {decisions_dir}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
