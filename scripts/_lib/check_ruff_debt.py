#!/usr/bin/env python3
"""Ratchet the ruff grandfather debt (BC-16867 / ADR-043).

`[tool.ruff.lint.per-file-ignores]` suppresses a code for a whole file, so it
cannot tell a pre-existing violation from a NEW one of the same code in that same
file. Without a second check, a fresh `F401` in a file already ignoring `F401`
ships silently — the exact silent-disarm this gate exists to prevent.

This is the ADR-034 R2-baseline idiom applied to ruff: a committed COUNT per
(file, code, message) that only ratchets DOWN.

    count > baseline  -> FAIL (a new violation of a grandfathered code)
    new key           -> FAIL (should have been caught by the gate itself)
    count < baseline  -> FAIL, loudly: the debt was paid but the ledger wasn't
                         updated. A stale-high baseline silently grants headroom
                         to re-add what was just fixed (BC-13287's lesson).
    file deleted      -> FAIL for the same reason (stale row).

The MESSAGE is part of the key, not decoration. Keyed on (file, code) alone, a
fix-one-add-one edit inside a grandfathered file keeps the count equal and passes
— so `'os' imported but unused` could be swapped for `'hashlib' imported but
unused` invisibly. Ruff's message names the offending symbol, so including it
makes that substitution a new key. Ruff is pinned in CI, so a message-wording
change arrives only with a deliberate pin bump, which already requires re-running
this snapshot.

KNOWN RESIDUAL, deliberately accepted: two findings that share a file, a code AND
a message are indistinguishable, so one can be RELOCATED within that file without
tripping the ratchet — e.g. an `f-string without any placeholders` (F541, a
message that names no symbol) removed at one site and introduced at another. What
this cannot do is ADD debt: the count is pinned, so the file's total for that
message can only fall. Closing the gap would mean putting position in the key, and
both forms cost more than they buy — line numbers churn the baseline on every
unrelated edit above a finding, and a source-text anchor churns on reformatting.
This matches the precedent it is modelled on: ADR-034's R2 baseline pins a body's
LINE COUNT, not which lines, and accepts the same relocation property.

Reads `ruff check --select E9,F --output-format=concise` on stdin so it needs no
ruff import and stays stdlib-only.

    ruff check --isolated --select E9,F --output-format=concise . \\
      | python3 scripts/_lib/check_ruff_debt.py docs/ruff-debt-baseline.tsv
    # regenerate after a burn-down:
    ruff check --isolated --select E9,F --output-format=concise . \\
      | python3 scripts/_lib/check_ruff_debt.py --write docs/ruff-debt-baseline.tsv

Exit 0 = in sync. Exit 1 = drift (message names every offending pair). Exit 2 =
usage error.
"""

from __future__ import annotations

import collections
import re
import sys
from pathlib import Path

FINDING = re.compile(r"^(?P<path>[^:]+):\d+:\d+: (?P<code>[A-Z]+[0-9]+) (?P<msg>.*)$")
HEADER = (
    "# ruff grandfather baseline (BC-16867 / ADR-043) — `count\\tpath\\tcode\\tmessage`, sorted.\n"
    "# Ratchets DOWN only: growth, a new key, AND an un-updated shrink all FAIL.\n"
    "# The message is part of the key so a fix-one-add-one swap inside a grandfathered\n"
    "# file cannot keep the count equal and slip through.\n"
    "# Regenerate: ruff check --isolated --select E9,F --output-format=concise . \\\n"
    "#   | python3 scripts/_lib/check_ruff_debt.py --write docs/ruff-debt-baseline.tsv\n"
)
Key = tuple[str, str, str]


def _norm_msg(msg: str) -> str:
    # Strip ruff's fixability marker ("[*] ") so toggling --fix availability between
    # pinned versions isn't mistaken for a different finding. Tabs would corrupt the
    # TSV, so collapse any whitespace run to a single space.
    return " ".join(msg.replace("[*]", "", 1).split())


def parse_findings(stream) -> dict[Key, int]:
    counts: collections.Counter = collections.Counter()
    for raw in stream:
        m = FINDING.match(raw.strip())
        if not m:
            continue  # summary lines ("Found N errors."), blank lines, fix hints
        path = m.group("path")
        if path.startswith("./"):
            path = path[2:]
        counts[(path, m.group("code"), _norm_msg(m.group("msg")))] += 1
    return dict(counts)


def parse_baseline(text: str) -> dict[Key, int]:
    out: dict[Key, int] = {}
    for line in text.splitlines():
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 4:
            raise SystemExit(
                f"malformed baseline row (want 'count\\tpath\\tcode\\tmessage'): {line!r}"
            )
        count, path, code, msg = parts
        if not count.isdigit():
            raise SystemExit(f"malformed baseline count: {line!r}")
        out[(path, code, msg)] = int(count)
    return out


def render(counts: dict[Key, int]) -> str:
    rows = "".join(f"{counts[k]}\t{k[0]}\t{k[1]}\t{k[2]}\n" for k in sorted(counts))
    return HEADER + rows


def main(argv: list[str]) -> int:
    write = "--write" in argv
    args = [a for a in argv if a != "--write"]
    if len(args) != 1:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        print("usage: check_ruff_debt.py [--write] <baseline.tsv>", file=sys.stderr)
        return 2

    baseline_path = Path(args[0])
    live = parse_findings(sys.stdin)

    if write:
        baseline_path.write_text(render(live), encoding="utf-8")
        print(f"wrote {len(live)} (file, code, message) rows to {baseline_path}")
        return 0

    if not baseline_path.exists():
        print(f"ERROR: baseline not found: {baseline_path}", file=sys.stderr)
        return 2
    baseline = parse_baseline(baseline_path.read_text(encoding="utf-8"))

    problems: list[str] = []
    for key in sorted(set(live) | set(baseline)):
        path, code, msg = key
        have, want = live.get(key, 0), baseline.get(key, 0)
        if have == want:
            continue
        if want == 0:
            problems.append(
                f"  NEW      {path} [{code}] {msg} — {have} finding(s), no baseline row. "
                "A new violation of a grandfathered code, or a swapped-in different one; "
                "fix it, or add a row if it is genuinely legacy."
            )
        elif have > want:
            problems.append(
                f"  GREW     {path} [{code}] {msg} — {have} findings, baseline {want}. "
                "per-file-ignores hides same-code regressions; fix the new one."
            )
        elif have == 0:
            problems.append(
                f"  RESOLVED {path} [{code}] {msg} — 0 findings, baseline {want}. "
                "Debt paid: drop the row (and its per-file-ignores entry once the file "
                "has no findings left for that code) to ratchet down."
            )
        else:
            problems.append(
                f"  SHRANK   {path} [{code}] {msg} — {have} findings, baseline {want}. "
                "Debt partly paid: lower the baseline so it can't grant headroom back."
            )

    if problems:
        print("ruff debt baseline is out of sync:", file=sys.stderr)
        print("\n".join(problems), file=sys.stderr)
        print(
            "\nRegenerate with:\n"
            "  ruff check --isolated --select E9,F --output-format=concise . \\\n"
            f"    | python3 scripts/_lib/check_ruff_debt.py --write {baseline_path}",
            file=sys.stderr,
        )
        return 1

    print(f"ruff debt baseline OK — {sum(live.values())} grandfathered finding(s) across {len(live)} (file, code, message) key(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
