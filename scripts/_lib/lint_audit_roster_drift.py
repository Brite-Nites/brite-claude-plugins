#!/usr/bin/env python3
"""Audit-invariant error-key roster drift-guard (BC-12640).

Machine-checks that each σ3 SF-write command's soft-fail `error`-key catalog stays
in lock-step across THREE surfaces, per command:

  1. the ADR-015 per-command roster   — `docs/decisions/015-...md` marker blocks
  2. the command's inline `{"error":"…"}` emits   — what it actually RETURNS
  3. the command's error-catalog table   — what a human READS

This is the systematic answer to roster-vs-catalog drift — the sibling to
BC-12638's guard-precedes-sink consolidating lint. It would have auto-caught the
"6 keys → 7" prose staleness BC-12623 fixed by hand: BC-12594 added
`invalid_owner_email` to `/revops:create-sf-campaign`'s catalog without updating
ADR-015's enumerated roster, and nothing failed.

SOURCE OF TRUTH
---------------
The command **emits LEAD**; the ADR roster and the table FOLLOW. The historical
bug was the ADR prose rotting *after* a command gained a key, so the emit set is
the pivot: every check is `<surface> == emits`, and a failure means "reconcile the
ADR roster / table to match the command." The check is bidirectional set-equality,
so a key SILENTLY ADDED to a command (which the old presence-only contract tests
missed) trips it just as a removed key does.

WHY PER-COMMAND ROSTERS
-----------------------
ADR-015 #5's roster (7 keys) equals `create-sf-campaign`'s catalog exactly, but
`update-sf-campaign-status` diverges — it adds `invalid_status` and lacks
`invalid_owner_email` / `duplicate_slug` / `missing_owner` (it updates an existing
Campaign, so no owner-lookup or slug-idempotency phase). A single shared roster
cannot set-equal both, so the ADR carries one marker-delimited roster per command
and this lint correlates each command file to the block whose `command=<stem>`
matches the file's name.

EXTRACTION
----------
  * emits  → inline `"error":"<key>"` JSON. `"warning":"…"` is DELIBERATELY
             excluded — this is the error roster only (`create-sf-campaign` emits a
             `"warning":"instance_url_unknown"` that must NOT count). The live
             `{"error":"<kind>", ...}` soft-fail-contract template is excluded by the
             leading-letter `[a-z][a-z0-9_]*` key class (a `<placeholder>` starts
             with `<`).
  * table  → the first backtick span of the first cell of each data row under the
             `(?i)… error … catalog` heading, AFTER the header separator (so the
             `| `error` key |` / `| key |` header is never a key). Both idioms are
             handled: a bare `` `<key>` `` (create) and an `` `error: <key>` ``
             prefix (update); `` `warning: …` `` rows are skipped, and only the
             FIRST span is read so `` `error: invalid_status` (with `flag` …) ``
             yields `invalid_status`, not `flag`.
  * roster → the first backtick span of each markdown LIST ITEM between
             `<!-- audit-invariant:error-roster command=<stem> -->` and
             `<!-- /audit-invariant:error-roster -->` (prose between the markers is
             ignored). The count is DERIVED from the list — never hand-typed (the very
             drift this guards).

Usage:
  lint_audit_roster_drift.py [--adr ADR_PATH] [COMMAND_FILE ...]
    no args → the canonical ADR-015 + the two σ3 command files (repo-anchored)
Exit 0 = in sync, 1 = ≥1 drift, 2 = usage / IO error.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import IO

# scripts/_lib/ → repo root is two levels up (parents[2]).
_REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ADR = "docs/decisions/015-gtm-sigma3-sf-campaign-sync.md"
DEFAULT_COMMANDS = [
    "plugins/revops/commands/create-sf-campaign.md",
    "plugins/revops/commands/update-sf-campaign-status.md",
]

# A soft-fail error KEY: a snake_case identifier — leading lowercase letter, then
# lowercase / digit / underscore. Digits are allowed deliberately so a future key
# like `oauth2_failure` is VISIBLE to the guard: a key the class cannot match would
# be dropped symmetrically from ALL THREE surfaces, the sets would still agree, and
# the drift would pass unseen — the exact silent-PASS this guard exists to prevent.
# The leading-letter requirement still excludes `<placeholder>` noise (the live
# `{"error":"<kind>", ...}` soft-fail-contract template starts with `<`, not a
# letter) and `warning` emits (matched only via the `"error":` prefix below).
_KEY = r"[a-z][a-z0-9_]*"
_KEY_RE = re.compile(_KEY)
# Inline emit — ERROR keys only (warnings deliberately excluded).
_EMIT_RE = re.compile(r'"error"\s*:\s*"(' + _KEY + r')"')
# ADR roster block markers.
_ROSTER_OPEN_RE = re.compile(r"<!--\s*audit-invariant:error-roster\s+command=(\S+?)\s*-->")
_ROSTER_CLOSE_RE = re.compile(r"<!--\s*/audit-invariant:error-roster\s*-->")
# A markdown list item ("- " / "* ") — the ONLY lines inside a roster block that
# contribute keys, so explanatory prose between the markers cannot leak phantom
# keys (symmetric with the table parser's first-cell-first-span scoping).
_LIST_ITEM_RE = re.compile(r"^\s*[-*]\s+")
# Error-catalog section heading (both "Error path catalog" + "Error / warning path catalog").
_CATALOG_HEADING_RE = re.compile(r"(?i)^#{1,6}\s.*error.*catalog")
# Any markdown heading — ends the catalog scan if hit before the table opens.
_ANY_HEADING_RE = re.compile(r"^#{1,6}\s")
# A markdown table separator row: only |, -, :, whitespace.
_SEPARATOR_RE = re.compile(r"^\s*\|[\s\-:|]+\|\s*$")
# First backtick span inside a table cell / list item (captures any non-backtick run).
_FIRST_SPAN_RE = re.compile(r"`([^`]+)`")


def emit_keys(text: str) -> set[str]:
    """Set of soft-fail `error` keys the command actually emits (warnings excluded)."""
    return set(_EMIT_RE.findall(text))


def table_keys(text: str) -> set[str]:
    """Set of `error` keys documented in the command's error-catalog TABLE.

    Scopes to the `(?i)… error … catalog` section's first table, reads only rows
    AFTER the header separator (so the column header is never a key), and from
    each row takes the first backtick span of the first cell — stripping an
    `error:` prefix and skipping `warning:` rows."""
    lines = text.split("\n")
    keys: set[str] = set()
    heading = next((i for i, ln in enumerate(lines) if _CATALOG_HEADING_RE.match(ln)), None)
    if heading is None:
        return keys

    # Walk to the separator row that opens the data region, then read data rows.
    i = heading + 1
    n = len(lines)
    saw_separator = False
    while i < n:
        ln = lines[i]
        if not saw_separator:
            if _SEPARATOR_RE.match(ln):
                saw_separator = True
            elif _ANY_HEADING_RE.match(ln):
                break  # next section before any table — no catalog table here
            i += 1
            continue
        # In the data region: a row must start with '|'; anything else ends it.
        if not ln.lstrip().startswith("|"):
            break
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        first = cells[0] if cells else ""
        span = _FIRST_SPAN_RE.search(first)
        if span:
            content = span.group(1).strip()
            if content.startswith("error:"):
                key = content[len("error:"):].strip()
            elif content.startswith("warning:"):
                key = ""  # warning row — not an error key
            else:
                key = content  # bare-key idiom
            if _KEY_RE.fullmatch(key):
                keys.add(key)
        i += 1
    return keys


def roster_map(adr_text: str) -> tuple[dict[str, set[str]], list[str]]:
    """Map command-stem → its ADR error-key roster, parsed from the marker blocks.

    Open/close markers MUST be STANDALONE lines (the stripped line IS the marker) —
    a marker mentioned inside backtick prose (e.g. the sibling-#3 `command=<name>`
    template) is documentation, not a block, so `fullmatch` ignores it (mirrors
    BC-12638's standalone-marker rule). Inside a block ONLY markdown list items
    contribute keys (the first backtick span of each `-`/`*` item), so an
    explanatory sentence between the markers cannot leak phantom keys — symmetric
    with the table parser's first-cell-first-span scoping.

    Returns (rosters, structural_violations). The latter flags malformed authoring
    a set-equality check would otherwise mask with a misleading diagnostic: a block
    re-opened before its predecessor closed, an unclosed final block, or a
    duplicate block for one command."""
    lines = adr_text.split("\n")
    rosters: dict[str, set[str]] = {}
    structural: list[str] = []
    cmd: str | None = None
    acc: set[str] = set()
    open_line = 0

    def _close(stem: str, keys: set[str]) -> None:
        if stem in rosters:
            structural.append(
                f"duplicate `audit-invariant:error-roster command={stem}` block — "
                f"keep exactly one block per command."
            )
        rosters[stem] = keys

    for idx, ln in enumerate(lines, start=1):
        open_m = _ROSTER_OPEN_RE.fullmatch(ln.strip())
        if cmd is None:
            if open_m:
                cmd, acc, open_line = open_m.group(1), set(), idx
            continue
        if open_m:
            structural.append(
                f"`command={open_m.group(1)}` roster block opens at line {idx} "
                f"before `command={cmd}` (opened line {open_line}) was closed — add "
                f"the missing `<!-- /audit-invariant:error-roster -->`."
            )
            _close(cmd, acc)
            cmd, acc, open_line = open_m.group(1), set(), idx
        elif _ROSTER_CLOSE_RE.fullmatch(ln.strip()):
            _close(cmd, acc)
            cmd = None
        elif _LIST_ITEM_RE.match(ln):
            span = _FIRST_SPAN_RE.search(ln)
            if span and _KEY_RE.fullmatch(span.group(1).strip()):
                acc.add(span.group(1).strip())
    if cmd is not None:  # open marker never closed
        structural.append(
            f"`command={cmd}` roster block (opened line {open_line}) is never "
            f"closed — add `<!-- /audit-invariant:error-roster -->`."
        )
        _close(cmd, acc)
    return rosters, structural


def check(adr_path: Path, command_paths: list[Path]) -> list[str]:
    """Return drift violations (empty = every surface in lock-step)."""
    violations: list[str] = []
    adr_name = adr_path.name
    rosters, structural = roster_map(adr_path.read_text(encoding="utf-8"))
    violations.extend(f"{adr_name}: {m}" for m in structural)
    linted: set[str] = set()

    for cmd_path in command_paths:
        stem = cmd_path.stem
        linted.add(stem)
        text = cmd_path.read_text(encoding="utf-8")
        emits = emit_keys(text)
        tbl = table_keys(text)

        if stem not in rosters:
            violations.append(
                f"{adr_name}: no `audit-invariant:error-roster command={stem}` "
                f"block found for command {cmd_path} — add a roster block "
                f"enumerating its soft-fail error keys (emitted: {sorted(emits)})."
            )
        else:
            adr_set = rosters[stem]
            if adr_set != emits:
                parts = []
                missing = sorted(emits - adr_set)
                extra = sorted(adr_set - emits)
                if missing:
                    parts.append(f"missing from ADR roster: {missing}")
                if extra:
                    parts.append(f"in ADR roster but not emitted: {extra}")
                violations.append(
                    f"{cmd_path}: ADR roster is STALE vs the command's inline "
                    f"`error` emits — " + "; ".join(parts) + f". Reconcile the "
                    f"`command={stem}` roster in {adr_name} to match the command "
                    f"(emits LEAD)."
                )

        if tbl != emits:
            parts = []
            missing = sorted(emits - tbl)
            extra = sorted(tbl - emits)
            if missing:
                parts.append(f"emitted but absent from table: {missing}")
            if extra:
                parts.append(f"in table but not emitted: {extra}")
            violations.append(
                f"{cmd_path}: error-catalog TABLE disagrees with the inline "
                f"`error` emits — " + "; ".join(parts) + "."
            )

    for dangling in sorted(set(rosters) - linted):
        violations.append(
            f"{adr_name}: `audit-invariant:error-roster command={dangling}` block "
            f"has no corresponding linted command file — remove the stale roster "
            f"or restore the command."
        )
    return violations


def _usage(stream: IO[str]) -> None:
    print(
        "usage: lint_audit_roster_drift.py [--adr ADR_PATH] [COMMAND_FILE ...]",
        file=stream,
    )


def main(argv: list[str]) -> int:
    adr: str | None = None
    cmds: list[str] = []
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--adr":
            i += 1
            if i >= len(argv):
                _usage(sys.stderr)
                return 2
            adr = argv[i]
        elif a in ("-h", "--help"):
            _usage(sys.stdout)
            return 0
        else:
            cmds.append(a)
        i += 1

    adr_path = Path(adr) if adr else _REPO_ROOT / DEFAULT_ADR
    command_paths = [Path(c) for c in cmds] if cmds else [_REPO_ROOT / c for c in DEFAULT_COMMANDS]

    try:
        violations = check(adr_path, command_paths)
    except OSError as e:
        print(f"lint_audit_roster_drift: cannot read input: {e}", file=sys.stderr)
        return 2

    if violations:
        for v in violations:
            print(f"VIOLATION: {v}", file=sys.stderr)
        print(
            f"\nlint_audit_roster_drift: {len(violations)} drift violation(s) "
            f"across {len(command_paths)} command(s).",
            file=sys.stderr,
        )
        return 1

    print(
        f"lint_audit_roster_drift: OK — {len(command_paths)} command roster(s) in "
        f"lock-step (ADR ↔ emits ↔ table)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
