#!/usr/bin/env python3
"""Repo-wide consolidating `--target-org` guard-precedes-sink lint (BC-12638).

SUBSUMES BC-12623's two bespoke per-file σ3 ordering tests with ONE check that
covers every command interpolating a non-literal `--target-org` into an
executable `sf` shell-out — across BOTH plugins — and fires on any FUTURE
non-literal passthrough. The systematic answer to the guard-after-sink
whack-a-mole (BC-10511 → BC-12594 → BC-12623).

THE RULE
--------
A command `.md` with an *executable non-literal* `--target-org` sink MUST place a
standalone `<!-- guard:target-org -->` marker BEFORE its earliest such sink, with
the byte-identical canonical regex `^[a-zA-Z0-9._@-]+$` documented in the window
*between the marker and that sink* (so the marker is bound to the actual guard,
not a free-floating comment an author could orphan from the validation prose).

  * executable      → the `--target-org` token lives inside a ```bash / ```sh /
                      ```shell / ~~~bash (or an UNLABELED, fail-closed) fenced
                      code block — what the agent actually runs. The σ3 dry-run
                      preview lives in a ```json fence and prose / frontmatter
                      `argument-hint` lines are unfenced, so neither is a sink.
  * non-literal     → the token right after `--target-org` (allowing `=` or
                      whitespace, and an optional ' or " quote) starts with `<`
                      (placeholder) or `$` (shell var / command substitution). A
                      literal alias (`brite-prod`, `brite-sandbox`, …) starts with
                      an alphanumeric and is EXEMPT — guarding a constant is dead
                      code (the deploy-prod/doctor finding, BC-12637).

The marker + in-window regex is the idiom-agnostic anchor: it binds the guard
across σ3's soft-fail-JSON and marketing's hard-fail-`ERROR:` contracts (where
BC-12623's emit-JSON anchor could not) AND it is positionally precise — a guard
mention in the flag table (before the marker) or a cross-reference (after the
sink) cannot satisfy it, so moving or deleting the real guard prose trips the
lint. Only the EARLIEST sink is checked: the σ3 "validate-once-at-Phase-0" model
halts on rejection, so downstream sinks reuse the already-validated value.

NON-SILENT, SINK-SCOPED EXEMPTION
---------------------------------
A bash-fenced non-literal `--target-org` that is NOT a real command-driven sink —
e.g. `/revops:post-deploy-runbook`'s `sf apex run --target-org <alias>` copy-paste
runbook snippet the operator runs themselves — declares
`<!-- guard:target-org:exempt <reason> -->` before it (mirrors ADR-028's
`# lint:not-side-effecting` override). The exemption is scoped to the *earliest
sink it precedes*, not the whole file: a real sink earlier than the exempt marker
is still governed by whatever marker precedes IT, so an exempt cannot mask a later
real sink. Explicit, reviewable, never silent.

Usage:
  lint_target_org_guard.py [FILE ...]   # lint these files
  lint_target_org_guard.py              # default-glob plugins/*/commands/*.md
Exit 0 = clean, 1 = ≥1 violation, 2 = usage/IO error.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

CANONICAL_REGEX = r"^[a-zA-Z0-9._@-]+$"
GUARD_MARKER = "<!-- guard:target-org -->"
EXEMPT_PREFIX = "<!-- guard:target-org:exempt"

# bash/sh/shell + UNLABELED ("") fences are executable (fail-closed on unlabeled).
EXEC_FENCE_LANGS = {"bash", "sh", "shell", ""}
# Opens/closes a fenced block: a run of ≥3 backticks or tildes + optional info.
_FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})(.*)$")
# Token immediately after `--target-org`, allowing `=` or whitespace separator and
# an optional single/double quote before the first significant char.
_TOKEN_RE = re.compile(r"""--target-org[=\s]\s*['"]?(\S)""")


def _executable_nonliteral_sinks(lines: list[str]) -> list[int]:
    """0-based line indices of every executable non-literal `--target-org` sink.

    A sink is a `--target-org <placeholder>` / `$var` token inside an executable
    fence. Tilde and backtick fences are tracked separately so a `~~~` block only
    closes on `~~~` (CommonMark)."""
    sinks: list[int] = []
    fence_char: str | None = None  # "`" or "~" while inside a fence, else None
    fence_len = 0  # opening run length (CommonMark: a closer must be >= this)
    fence_lang = ""
    for i, ln in enumerate(lines):
        m = _FENCE_RE.match(ln)
        if m:
            run, info = m.group(1), m.group(2)
            ch = run[0]
            if fence_char is None:
                fence_char, fence_len = ch, len(run)
                # lang = first info-string token, stripped of attribute syntax
                # (`{.bash}` / `bash {.numberLines}` → `bash`) so annotated fences
                # are still recognized as executable.
                tok = (info.strip().split() or [""])[0]
                fence_lang = tok.strip("{}.").lower()
            elif ch == fence_char and len(run) >= fence_len and not info.strip():
                # CommonMark close: same char, run >= opener, no info string. A
                # shorter run (e.g. ``` inside a ```` block) does NOT close.
                fence_char, fence_len, fence_lang = None, 0, ""
            continue
        if fence_char is not None and fence_lang in EXEC_FENCE_LANGS and "--target-org" in ln:
            tok = _TOKEN_RE.search(ln)
            if tok and tok.group(1) in ("<", "$"):
                sinks.append(i)
    return sinks


def lint_text(name: str, text: str) -> list[str]:
    """Return a list of violation strings for one command file (empty = clean)."""
    lines = text.split("\n")
    sinks = _executable_nonliteral_sinks(lines)
    if not sinks:
        return []  # no executable non-literal sink → EXEMPT (literal-only / doc-only)
    earliest = sinks[0]

    # Standalone marker lines (guard or exempt) that PRECEDE the earliest sink.
    # The exemption is sink-scoped: only markers before THIS sink govern it, so a
    # later exempt cannot mask an earlier real sink.
    preceding: list[tuple[int, str]] = []
    for i in range(earliest):
        s = lines[i].strip()
        if s == GUARD_MARKER:
            preceding.append((i, "guard"))
        elif s.startswith(EXEMPT_PREFIX):
            preceding.append((i, "exempt"))

    if not preceding:
        # Distinguish a guard marker that exists but sits AFTER the sink (the
        # guard-after-sink regression) from no marker at all — both are failures.
        later_guard = any(ln.strip() == GUARD_MARKER for ln in lines[earliest:])
        if later_guard:
            return [
                f"{name}: `{GUARD_MARKER}` marker appears AFTER the earliest "
                f"executable --target-org sink at line {earliest + 1} (guard-after-"
                f"sink) — hoist the guard + marker above the sink (and above any "
                f"skip-on-dry-run / cache gate)."
            ]
        return [
            f"{name}: executable non-literal --target-org sink at line {earliest + 1} "
            f"has no `{GUARD_MARKER}` marker preceding it — add the marker at the "
            f"validation point before the sink (or `{EXEMPT_PREFIX} <reason> -->` if "
            f"it is not a real command-driven sink)."
        ]

    governing_idx, governing_kind = preceding[-1]  # nearest marker before the sink
    if governing_kind == "exempt":
        return []  # documented copy-paste snippet, scoped to this sink

    # A guard marker governs: the canonical regex must be documented in the window
    # BETWEEN the marker and the sink — this binds the marker to the real guard
    # prose (a flag-table mention before the marker, or a cross-reference after the
    # sink, does not count), restoring the behavior-bound guarantee of the deleted
    # per-file ordering tests idiom-agnostically.
    window = "\n".join(lines[governing_idx + 1:earliest])
    if CANONICAL_REGEX not in window:
        return [
            f"{name}: `{GUARD_MARKER}` marker at line {governing_idx + 1} is not "
            f"bound to a guard — the canonical regex `{CANONICAL_REGEX}` must appear "
            f"between the marker and the earliest sink at line {earliest + 1} (it is "
            f"absent there). Place the validation prose, byte-identical, directly "
            f"under the marker and above the sink."
        ]
    return []


def _default_targets() -> list[Path]:
    # scripts/_lib/ → repo root is two levels up.
    root = Path(__file__).resolve().parent.parent.parent
    return sorted(root.glob("plugins/*/commands/*.md"))


def main(argv: list[str]) -> int:
    if len(argv) > 1:
        targets = [Path(a) for a in argv[1:]]
    else:
        targets = _default_targets()
        if not targets:
            print("lint_target_org_guard: no command files found", file=sys.stderr)
            return 2

    all_violations: list[str] = []
    for p in targets:
        try:
            text = p.read_text(encoding="utf-8")
        except OSError as e:
            print(f"lint_target_org_guard: cannot read {p}: {e}", file=sys.stderr)
            return 2
        all_violations.extend(lint_text(str(p), text))

    if all_violations:
        for v in all_violations:
            print(f"VIOLATION: {v}", file=sys.stderr)
        print(
            f"\nlint_target_org_guard: {len(all_violations)} violation(s) across "
            f"{len(targets)} file(s).",
            file=sys.stderr,
        )
        return 1

    print(f"lint_target_org_guard: OK — {len(targets)} command file(s) clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
