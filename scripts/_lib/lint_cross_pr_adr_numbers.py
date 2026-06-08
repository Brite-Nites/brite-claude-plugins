#!/usr/bin/env python3
"""Cross-PR ADR-number collision guard — the deterministic core (BC-12698).

WHAT THIS CLOSES
----------------
The WITHIN-repo guard `lint_adr_numbers.py` (BC-12617) catches a duplicate ADR
number within ONE PR's tree, post-merge on `main`, AND vs-main at PR-open time
(the pull_request merge-ref checkout contains main ∪ this PR's added file, and the
guard is a tree scan). What it CANNOT see is two concurrently-open PRs that each
git-ADD the same `NNN` with DIFFERENT slugs before either merges — git never flags
that (the filenames differ), and until the loser is brought up-to-date, no single
tree contains both. That residual cross-PR-pre-merge window is what this guard
closes: it compares THIS PR's added ADR numbers against the added numbers of the
OTHER open PRs and flags any reuse, naming the colliding PR so the author can
renumber before the cascade.

DETERMINISTIC CORE vs THIN ADAPTER
----------------------------------
The live open-PR set is non-deterministic (it depends on what's open at the moment
CI runs, and on a race over which PR's CI sees which), so the JOB can't be
fixture-tested. This core is the part that CAN: it is a pure function of its JSON
input — `{self, others[]}` → collisions → exit code + report — so it is locked by
a synthetic mutation matrix (`test_lint_cross_pr_adr_numbers.sh`, wired into
`validate.sh §15a-bc-12698`). The non-deterministic half lives in the thin gh
adapter `scripts/ci/cross-pr-adr-guard.sh`, which gathers the data, drops THIS PR
from the open-PR list, scopes to added `docs/decisions/*.md`, and pipes the model
in here. The adapter is validated by reading the workflow + a manual `gh` dry-run,
NOT by this harness.

WHY ADVISORY, NOT BLOCKING
--------------------------
The signal is inherently racy: PR-X's run only sees PR-Y if Y is open at that
instant, and a green X goes stale the moment Y opens — so BOTH colliding PRs may
red on their own runs, and there is no reliable "only the later one fails"
ordering. Hard-blocking a racy signal would punish whoever's CI happens to run
second. The within-repo guard + the claim-first convention are the real guards;
this is the earlier-surface optimization. So the CI job carries
`continue-on-error: true`; this core still honestly exits 1 on a collision (the
JOB makes it advisory, not the core).

INPUT MODEL
-----------
A JSON object on stdin (or a file path argument):

    {
      "self":   {"pr": 460, "url": "<pr url>", "added": ["docs/decisions/021-foo.md", ...]},
      "others": [{"pr": 455, "url": "<pr url>", "added": ["docs/decisions/021-bar.md", ...]}, ...]
    }

`added` entries are the files each PR ADDS (status=added). They may be repo-relative
paths or bare filenames — the number is read off the BASENAME via the shared
`adr_numbers.adr_number` rule (the SAME rule the within-repo guard uses; a parity
test locks them so they cannot drift), and the given string is shown verbatim so a
GitHub annotation can carry a real `file=` path. Scoping `added` to
`docs/decisions/` is the ADAPTER's job; a non-ADR basename here simply yields no
number and is ignored.

OUTPUT
------
Default: a human report on stdout. With `--github`: additionally a `::warning`
workflow annotation per colliding PR + a markdown table appended to the file named
by `$GITHUB_STEP_SUMMARY` (the visibility that keeps an advisory check from being
cry-wolf). Exit 0 = no cross-PR collision, 1 = ≥1 collision, 2 = usage / unreadable
input / malformed model.
"""
from __future__ import annotations

import json
import os
import sys

from adr_numbers import adr_number

USAGE = "usage: lint_cross_pr_adr_numbers.py [--github] [INPUT_JSON]"


class InputError(Exception):
    """A malformed input model (vs an unexpected crash) → exit 2 with a reason."""


def _basename(path: str) -> str:
    """Final path component (the gh files API returns repo-relative paths)."""
    return path.rsplit("/", 1)[-1]


def _oneline(s: str) -> str:
    """Collapse CR/LF so an attacker-controlled filename (from another PR) can't
    break out of a single GitHub annotation line. Newlines already can't survive
    the adapter's line-based filter, but the core escapes here too (defense in
    depth — the core is independently invokable with arbitrary JSON)."""
    return s.replace("\r", " ").replace("\n", " ")


def _md_cell(s: str) -> str:
    """Escape a value for a markdown table cell: a literal `|` in an untrusted
    filename would break the column layout, so backslash-escape it (and drop
    CR/LF, which would break the row)."""
    return _oneline(s).replace("|", "\\|")


def _disp(pr) -> str:
    """Display a PR number that may be int, str, or missing."""
    return str(pr) if pr is not None else "?"


def _sortkey(pr):
    """Sort PRs numerically when possible, else lexically — stable, no crash."""
    try:
        return (0, int(pr))
    except (TypeError, ValueError):
        return (1, str(pr))


def _numbers_to_files(added: list[str]) -> dict[int, list[str]]:
    """Map each NORMALIZED ADR number → sorted display strings among `added`.

    Uses the shared `adr_number` rule on each entry's basename; non-ADR entries
    contribute nothing. The display string is the entry AS GIVEN (full path or
    bare name) so the report/annotation can point at the real file."""
    out: dict[int, list[str]] = {}
    for item in added:
        num = adr_number(_basename(item))
        if num is None:
            continue
        bucket = out.setdefault(num, [])
        if item not in bucket:
            bucket.append(item)
    for num in out:
        out[num].sort()
    return out


def _validate_added(added, where: str) -> list[str]:
    if not isinstance(added, list):
        raise InputError(f"'added' in {where} must be a list")
    for x in added:
        if not isinstance(x, str):
            raise InputError(f"'added' in {where} must contain only strings")
    return added


def parse_model(raw: str):
    """Parse + structurally validate the input model, or raise InputError.

    Returns (self_pr, self_url, self_added, others) where others is a list of
    normalized {pr, url, added} dicts."""
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise InputError(f"not valid JSON: {exc}")
    if not isinstance(data, dict):
        raise InputError("top-level value must be a JSON object")

    sobj = data.get("self")
    if not isinstance(sobj, dict):
        raise InputError("missing or non-object 'self'")
    others_raw = data.get("others")
    if not isinstance(others_raw, list):
        raise InputError("missing or non-list 'others'")

    self_pr = sobj.get("pr")
    self_url = sobj.get("url", "") or ""
    self_added = _validate_added(sobj.get("added", []), "'self'")

    others = []
    for i, o in enumerate(others_raw):
        if not isinstance(o, dict):
            raise InputError(f"'others[{i}]' must be an object")
        others.append(
            {
                "pr": o.get("pr"),
                "url": o.get("url", "") or "",
                "added": _validate_added(o.get("added", []), f"'others[{i}]'"),
            }
        )
    return self_pr, self_url, self_added, others


def find_collisions(self_pr, self_added, others):
    """Return (self_map, collisions).

    self_map: number → this PR's files claiming it.
    collisions: number → [(other_pr, other_url, [other files]), ...] for every
    OTHER open PR that also claims a number this PR claims. A PR whose number is
    self's own pr is skipped (self-exclusion defense — the adapter should already
    have dropped it, but a self-entry must never be reported as a collision)."""
    self_map = _numbers_to_files(self_added)
    collisions: dict[int, list] = {}
    for o in others:
        opr = o["pr"]
        if opr is not None and self_pr is not None and str(opr) == str(self_pr):
            continue
        for num, ofiles in _numbers_to_files(o["added"]).items():
            if num in self_map:
                collisions.setdefault(num, []).append((opr, o["url"], ofiles))
    return self_map, collisions


def _print_human(self_pr, self_map, collisions) -> None:
    print(
        f"cross-PR ADR-number guard: COLLISION — this PR (#{_disp(self_pr)}) "
        "reuses ADR number(s) already claimed by another open PR"
    )
    for num in sorted(collisions):
        print(f"  number {num}:")
        for f in self_map[num]:
            print(f"    this PR (#{_disp(self_pr)}): {f}")
        for opr, ourl, ofiles in sorted(collisions[num], key=lambda t: _sortkey(t[0])):
            loc = f" ({ourl})" if ourl else ""
            print(f"    PR #{_disp(opr)}{loc}: {', '.join(ofiles)}")
    print(
        "  → renumber all but one: read the next free number off origin/main, "
        "claim it in your PR/issue title, and coordinate with the author(s) above."
    )


def _summary_fh():
    """Append handle to $GITHUB_STEP_SUMMARY, or None if unset/unwritable."""
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return None
    try:
        return open(path, "a", encoding="utf-8")
    except OSError:
        return None


def _emit_github(self_pr, self_map, collisions) -> None:
    """One ::warning annotation per colliding PR + a step-summary table."""
    for num in sorted(collisions):
        self_files = self_map[num]
        anchor = self_files[0] if self_files else ""
        self_disp = ", ".join(_oneline(f) for f in self_files)
        for opr, ourl, ofiles in sorted(collisions[num], key=lambda t: _sortkey(t[0])):
            loc = f" ({_oneline(ourl)})" if ourl else ""
            other_disp = ", ".join(_oneline(f) for f in ofiles)
            msg = (
                f"ADR number {num} in this PR (#{_disp(self_pr)}) collides with "
                f"PR #{_disp(opr)}{loc}: {self_disp} vs {other_disp} — renumber off "
                "origin/main and claim it in your PR/issue title."
            )
            file_attr = f"file={_oneline(anchor)}," if anchor else ""
            print(f"::warning {file_attr}title=Cross-PR ADR-number collision::{msg}")

    fh = _summary_fh()
    if fh is None:
        return
    with fh:
        fh.write("\n### ⚠️ Cross-PR ADR-number collision (advisory)\n\n")
        fh.write(
            f"This PR (#{_disp(self_pr)}) adds ADR number(s) already claimed by "
            "another **open** PR. Renumber before merge to avoid the renumber "
            "cascade — read the next free number off `origin/main`, claim it in "
            "your PR/issue title, and coordinate with the author(s) below.\n\n"
        )
        fh.write("| ADR number | this PR | colliding PR | colliding file |\n")
        fh.write("|---|---|---|---|\n")
        for num in sorted(collisions):
            sf = ", ".join(_md_cell(f) for f in self_map[num])
            for opr, ourl, ofiles in sorted(
                collisions[num], key=lambda t: _sortkey(t[0])
            ):
                pr_cell = f"[#{_disp(opr)}]({_oneline(ourl)})" if ourl else f"#{_disp(opr)}"
                of_cell = ", ".join(_md_cell(f) for f in ofiles)
                fh.write(f"| {num} | {sf} | {pr_cell} | {of_cell} |\n")


def _write_summary_ok(self_pr, n_others: int) -> None:
    fh = _summary_fh()
    if fh is None:
        return
    with fh:
        fh.write("\n### ✓ Cross-PR ADR-number guard\n\n")
        fh.write(
            f"No cross-PR ADR-number collision — this PR (#{_disp(self_pr)}) "
            f"checked against {n_others} other open PR(s).\n"
        )


def main(argv: list[str]) -> int:
    github = False
    input_path = None
    for a in argv[1:]:
        if a in ("-h", "--help"):
            print(USAGE)
            return 0
        if a == "--github":
            github = True
        elif a.startswith("-"):
            print(f"{USAGE}\nunknown option: {a}", file=sys.stderr)
            return 2
        elif input_path is None:
            input_path = a
        else:
            print(f"{USAGE}\nunexpected extra argument: {a}", file=sys.stderr)
            return 2

    try:
        if input_path is not None:
            with open(input_path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        else:
            raw = sys.stdin.read()
    except OSError as exc:
        print(
            f"cross-PR ADR-number guard: ERROR — cannot read input: {exc}",
            file=sys.stderr,
        )
        return 2

    try:
        self_pr, _self_url, self_added, others = parse_model(raw)
    except InputError as exc:
        print(
            f"cross-PR ADR-number guard: ERROR — malformed input: {exc}",
            file=sys.stderr,
        )
        return 2

    self_map, collisions = find_collisions(self_pr, self_added, others)

    if not collisions:
        print(
            f"cross-PR ADR-number guard: OK — no cross-PR ADR-number collision "
            f"(this PR #{_disp(self_pr)} vs {len(others)} other open PR(s))"
        )
        if github:
            _write_summary_ok(self_pr, len(others))
        return 0

    _print_human(self_pr, self_map, collisions)
    if github:
        _emit_github(self_pr, self_map, collisions)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
