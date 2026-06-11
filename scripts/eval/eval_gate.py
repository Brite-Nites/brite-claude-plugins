#!/usr/bin/env python3
"""M5 — the forward-only blocking gate (BC-12590, ADR-028 Phase-1).

The *flip-to-blocking* half of the Phase-1 ratchet. It consumes the M1 structural
lint's ``findings[]`` (BC-12588) and the M2 behavioral-eval registry (BC-12589),
detects the **changed** command set for a diff, and FAILS the build when a changed
command misses a §0 non-negotiable. This is what makes the discipline real.

Architecture: a PURE decision core (``decide`` / ``classify_changes`` /
``parse_debt_table`` / ``check_invariants``) — no git, no subprocess, no I/O, fully
unit-tested in ``_eval_gate_cases.py`` from the locked spec — wrapped by a thin I/O
shell (git diff, ``run_eval`` subprocess, debt-file + spec reads).

Three enforcement surfaces, by design (they run in DIFFERENT CI checkouts):

  * **diff-gate** (default mode) — ``(base_ref, head_ref)`` → the changed
    ``plugins/*/commands/*.md`` set → a per-command BLOCK/OK verdict. Runs in a
    DEDICATED ``pull_request``-gated CI job at ``fetch-depth: 0`` (the BC-12410
    shift-left template, but BLOCKING — no ``continue-on-error``), where
    ``origin/main`` IS a resolvable base. It is NOT wired into ``validate.sh`` — the
    ``validate`` job is a shallow (depth-1) checkout where ``origin/main`` doesn't
    resolve, so a validate.sh-embedded diff-gate would silently no-op (a gate that
    doesn't gate — the worst outcome).

  * **--check** (integrity lint) — diff-free, so it runs everywhere INCLUDING the
    shallow ``validate`` job. Enforces the debt-list invariants that make the
    grandfather + waiver scheme trustworthy: ``debt ∩ ADAPTERS == ∅``,
    ``debt ∪ ADAPTERS == the full command surface`` (no net-new command slips in
    un-recorded; no stale row for a deleted command), and the SYMMETRIC
    waiver↔row coupling (every ``status: waiver`` row ⇔ an in-file
    ``# eval-waiver: <reason>`` marker) so a waiver can never be silent in EITHER
    direction.

  * **--structural** (full-surface structural gate — ADR-033, BC-13213, the
    BC-12700 bullet-#2 per-rule ratchet's enforcement surface) — diff-free: lints
    the WHOLE commands+skills surface and FAILS on any ``severity == "gate"``
    finding not covered by a ``docs/structural-lint-debt.md`` row. Full-surface
    (not changed-set) because the ratchet's later flips need it: every R4/R5/R6
    violation at flip time lives in a SKILL.md the commands-only diff-gate never
    sees, and an R4 (nested-refs) regression can be introduced by editing a bundled
    REFERENCE file — invisible to any spec-file changed-set. Runs as a second step
    in the REQUIRED eval-gate CI job and (diff-free → shallow-safe) in
    ``validate.sh`` §15a-bc-12590 Part 3. Debt rows are keyed ``(file, rule)``; an
    R2 row carries a line-count BASELINE (suppresses only while the body hasn't
    grown past it); a row whose ``(file, rule)`` has no live finding is STALE and
    fails the gate (self-cleaning list).

Split A′ (locked in the BC-12590 grill, 2026-06-07) — the two §0 non-negotiables
are gated DIFFERENTLY, by cost:

  * **Structural R1** (``disable-model-invocation`` for a side-effecting command)
    flips to blocking on ANY changed command, debt-listed or not — gated by
    changed-set membership ALONE (the debt list is irrelevant to R1; an untouched
    command simply isn't in the diff). Cheap to satisfy: the flag, or the existing
    ``# lint:not-side-effecting`` override that ``lint_spec`` already applies (it
    returns the finding as ``advisory`` once overridden, so the gate — which reads
    ``severity`` only — stops blocking with zero re-detection).
  * **Behavioral eval** is grandfathered by the debt list. Per-changed-command
    precedence: (1) in ``ADAPTERS`` AND ``run_eval.py <id>`` exits 0 → OK (a broken
    eval on an in-ADAPTERS command → BLOCK); (2) else a PRE-EXISTING command on the
    debt list → eval-exempt (grandfathered, the Phase-2 backfill set); (3) else
    (net-new, or modified-and-unlisted) → must carry a passing eval OR a
    ``# eval-waiver: <reason>`` marker, else BLOCK.

NOTE #1 (deterministic laundering close) — a command that appears as a git **ADD**
in the diff (``is_new``) can NOT be cleared by a ``grandfathered`` debt row.
Grandfathering is the BOOTSTRAP set only; the ``∪ == surface`` invariant would
otherwise make "add a grandfathered row" the path of least resistance for a net-new
command. ``is_new`` is read from ``git diff --name-status`` (A vs M); a rename git
scores as A+D (we pass ``--no-renames`` so it always does) → the new path is an ADD
(net-new → eval/waiver) and the old path a deletion (→ stale-row on the next
``--check``). Residual edges (delete-and-readd) likewise force an eval/waiver or a
deliberate re-bootstrap — acceptable and documented.

Command-id = the **full repo-relative path** ``plugins/<p>/commands/<name>.md``.
Bare basenames collide (``ship``/``review``/``session-start`` exist in both
flow-architecture and workflows), so the detector + the debt list key on the full
path; only the ``ADAPTERS`` eval-lookup uses the bare basename — a today-safe shim
(the colliding basenames are all un-eval'd). MIGRATION: when the first
colliding-basename command gets an eval, ``ADAPTERS`` must move to a plugin-qualified
key; ``--check`` HARD-ERRORS on an ambiguous bare id so the trap surfaces loudly.

Exit codes: 0 = OK (no blocked command / integrity clean); 1 = BLOCK (a changed
command failed / an integrity invariant broke); 2 = usage / could-not-run (e.g. an
unresolvable diff base) — distinct from a policy block, mirroring the lint's "the
check couldn't RUN → fail" contract. Stdlib-only.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

# scripts/eval/eval_gate.py → repo root is two parents up. Import the merged
# contracts from the sibling modules (the same sys.path idiom run_eval.py uses).
_HERE = Path(__file__).resolve().parent
REPO_ROOT = _HERE.parents[1]
sys.path.insert(0, str(_HERE))
from structural_lint import (  # noqa: E402
    COMMAND_GLOB,
    SEV_GATE,
    SKILL_GLOB,
    Finding,
    body_lines,
    finding_loc,
    lint_path,
    lint_spec,
    parse_marker,
    scan_surface,
)
from run_eval import ADAPTERS  # noqa: E402

DEBT_LIST_REL = "docs/skill-eval-debt.md"
RUN_EVAL = _HERE / "run_eval.py"

# ── ADR-033 full-surface structural gate (BC-13213) ───────────────────────────
STRUCTURAL_DEBT_REL = "docs/structural-lint-debt.md"
# A structural-debt row's `file` cell must be a lintable spec — the glob-guard that
# self-skips the table header/separator (same idiom as parse_debt_table). The glob
# text is imported from structural_lint (the canonical copy, next to scan_surface)
# so a surface change can't silently strand debt rows.
SPEC_ROW_GLOBS = (COMMAND_GLOB, SKILL_GLOB)
# `baseline` is only meaningful for the body-size rule: it pins the grandfathered
# body line count so the exemption can't silently absorb further growth.
BASELINE_RULE = "R2-body-too-long"

# `# eval-waiver: <reason>` — the net-new escape hatch (ADR-028 D1). Parsed by the
# ONE canonical comment-anchored-marker parser in structural_lint (note #3), so it
# can't drift from the R1 `# lint:not-side-effecting` override: anchored to a comment
# prefix (`#` / `<!--`) so a prose/inline-code MENTION can't suppress the gate (the
# BC-12534 substring-lint gotcha), reason captured after the token, trailing `-->`
# stripped, empty marker → '' (does not suppress).
WAIVER_TOKEN = "eval-waiver:"

# git env vars that leak from a calling hook (stale-pre-push GIT_DIR, per CLAUDE.md)
# and would point git at the WRONG repo — doubly dangerous here because the
# detector shells out to git against throw-away fixture repos in the self-test.
GIT_ENV_STRIP = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
)


# ══════════════════════════════════════════════════════════════════════════════
# PURE decision core — no git, no subprocess, no filesystem (unit-tested directly)
# ══════════════════════════════════════════════════════════════════════════════


@dataclass
class Decision:
    command: str
    blocked: bool
    status: str                      # ok-eval | exempt-grandfathered | exempt-waiver | blocked
    block_reasons: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)


def decide(
    command: str,
    structural_block_reasons: list[str],
    eval_status: str,                # "pass" | "fail" | "absent"
    on_debt: bool,
    waiver_reason: str | None,       # None=absent, ''=empty marker, str=valid reason
    is_new: bool,
) -> Decision:
    """The per-changed-command verdict (Split A′ + note #1). PURE — every input is a
    pre-collected fact, so the whole precedence ladder is unit-testable hermetically."""
    block_reasons: list[str] = list(structural_block_reasons)  # (a) R1 — always-on for the changed set
    notes: list[str] = []

    # (b) behavioral eval precedence.
    if eval_status == "pass":
        eval_label = "ok-eval"
        notes.append("behavioral eval registered and passing")
    elif eval_status == "fail":
        eval_label = "blocked"
        block_reasons.append("behavioral eval is registered (ADAPTERS) but FAILS — fix the eval")
    else:  # "absent"
        # NOTE #1: a net-new command (git ADD) is NOT cleared by a grandfathered row.
        grandfather_clears = on_debt and not is_new
        if grandfather_clears:
            eval_label = "exempt-grandfathered"
            notes.append("grandfathered on the debt list (Phase-2 backfill) — eval not required")
        elif waiver_reason:  # a non-empty reason
            eval_label = "exempt-waiver"
            notes.append(f"eval-waiver accepted: {waiver_reason}")
        elif waiver_reason == "":  # an empty marker is present
            eval_label = "blocked"
            block_reasons.append(
                "a `# eval-waiver` marker is present but has no <reason>, so it is ignored "
                "(an empty marker does not suppress the gate)"
            )
        elif is_new and on_debt:
            eval_label = "blocked"
            block_reasons.append(
                "net-new command (added in this diff) cannot be grandfathered by a debt row "
                "(grandfathering is the bootstrap set only); add a passing eval, or a "
                "`# eval-waiver: <reason>` marker whose debt row is status=waiver"
            )
        elif is_new:
            eval_label = "blocked"
            block_reasons.append(
                "net-new command with no behavioral eval and no `# eval-waiver: <reason>` marker "
                "(author an eval, or add a waiver marker + a status=waiver debt-list row)"
            )
        else:
            eval_label = "blocked"
            block_reasons.append(
                "changed command with no behavioral eval, not on the debt list, and no "
                "`# eval-waiver: <reason>` marker (author an eval, add a waiver, or add a debt-list row)"
            )

    blocked = bool(block_reasons)
    status = "blocked" if blocked else eval_label
    return Decision(command, blocked, status, block_reasons, notes)


def classify_changes(name_status_output: str) -> dict[str, bool]:
    """Parse ``git diff --name-status`` output → ``{command_path: is_new}``.

    Keeps only ``plugins/*/commands/*.md`` paths; drops pure deletions (``D`` — a
    deleted command's stale debt row is caught by ``--check``, not the diff-gate).
    ``is_new`` is True for an ADD (``A``) and, defensively, a rename/copy NEW path
    (``R``/``C`` — we pass ``--no-renames`` so these normally appear as ``A``+``D``,
    but if config forces detection the relocated path is treated as net-new). ``M``
    (modify) and ``T`` (typechange) are existing-path changes → not new."""
    out: dict[str, bool] = {}
    for line in name_status_output.splitlines():
        line = line.rstrip("\n")
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        code = parts[0].strip()[:1]
        if code == "D":
            continue
        path = parts[-1].strip()  # rename/copy → new path is the last field
        if not fnmatch.fnmatch(path, COMMAND_GLOB):
            continue
        out[path] = code in ("A", "R", "C")
    return out


def parse_debt_table(text: str) -> dict[str, dict]:
    """Parse the one markdown table in the debt-list text → ``{command_path: row}``.

    Positional + glob-guarded: only a row whose first cell (de-backticked) matches
    the command glob is a data row, so the header and the ``|---|`` separator are
    skipped without tracking table position. Columns:
    ``| command | plugin | status | reason | added |``."""
    out: dict[str, dict] = {}
    for line in text.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [c.strip().strip("`").strip() for c in line.strip().strip("|").split("|")]
        if not cells:
            continue
        cmd = cells[0]
        if fnmatch.fnmatch(cmd, COMMAND_GLOB):
            out[cmd] = {
                "plugin": cells[1] if len(cells) > 1 else "",
                "status": cells[2] if len(cells) > 2 else "",
                "reason": cells[3] if len(cells) > 3 else "",
                "added": cells[4] if len(cells) > 4 else "",
            }
    return out


def check_invariants(
    surface,
    evald,
    debt_rows: dict[str, dict],
    waiver_markers,
) -> list[str]:
    """The debt-list integrity problems (empty list = clean). PURE.

    ``surface`` = every command path on disk; ``evald`` = paths with an ADAPTERS
    eval; ``debt_rows`` = parsed debt table; ``waiver_markers`` = paths carrying a
    VALID (non-empty) in-file ``# eval-waiver`` marker. Enforces:
      - debt ∩ ADAPTERS == ∅              (can't be both grandfathered and eval'd)
      - debt ∪ ADAPTERS == surface        (no un-recorded net-new; no stale row)
      - symmetric waiver↔row coupling     (a waiver is never silent, both directions)
    """
    surface = set(surface)
    evald = set(evald)
    debt = set(debt_rows)
    problems: list[str] = []

    for c in sorted(debt & evald):
        problems.append(
            f"{c}: on the debt list AND eval'd (ADAPTERS) — debt ∩ ADAPTERS must be ∅; remove its debt row"
        )
    for c in sorted(debt - surface):
        problems.append(
            f"{c}: a debt-list row for a command not on the surface (deleted/renamed?) — remove the stale row"
        )
    for c in sorted(surface - debt - evald):
        problems.append(
            f"{c}: neither eval'd (ADAPTERS) nor on the debt list — add a debt-list row or author an eval "
            "(a net-new command must be recorded; debt ∪ ADAPTERS must == the surface)"
        )

    # Symmetric waiver↔row coupling (BC-12590 grill, 2026-06-07): a status=waiver row
    # must have a matching in-file marker, AND an in-file marker must have a
    # status=waiver row — so neither half of a waiver can exist silently.
    waiver_markers = set(waiver_markers)
    waiver_rows = {c for c, r in debt_rows.items() if (r.get("status") or "") == "waiver"}
    for c in sorted(waiver_rows - waiver_markers):
        problems.append(
            f"{c}: debt row is status=waiver but the command file has no `# eval-waiver: <reason>` marker "
            "(a waiver must never be silent — add the in-file marker or change the row status)"
        )
    for c in sorted(waiver_markers - debt):
        problems.append(
            f"{c}: carries a `# eval-waiver:` marker but has no debt-list row "
            "(a waiver must be recorded as a status=waiver row)"
        )
    for c in sorted(waiver_markers & debt):
        st = debt_rows[c].get("status") or "?"
        if st != "waiver":
            problems.append(
                f"{c}: carries a `# eval-waiver:` marker but its debt row is status={st} (should be status=waiver)"
            )
    return problems


def parse_structural_debt(text: str) -> tuple[dict[tuple[str, str], dict], list[str]]:
    """Parse docs/structural-lint-debt.md → ``({(file, rule): row}, problems)``. PURE.

    Same glob-guarded positional idiom as ``parse_debt_table``, but keyed
    ``(file, rule)`` — a file can be grandfathered for ONE rule while still gated on
    every other. Columns: ``| file | rule | reason | added | baseline |``.

    A malformed row is a loud PROBLEM and never suppresses (the recurring
    pure-builder lesson: degenerate input must not silently become an exemption):
    a non-integer baseline, a baseline on a non-R2 rule, a missing rule id, and a
    duplicate ``(file, rule)`` each drop the row and record a problem.
    """
    rows: dict[tuple[str, str], dict] = {}
    problems: list[str] = []
    for line in text.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [c.strip().strip("`").strip() for c in line.strip().strip("|").split("|")]
        if not cells:
            continue
        fpath = cells[0]
        if not any(fnmatch.fnmatch(fpath, g) for g in SPEC_ROW_GLOBS):
            continue  # header / |---| separator / prose — not a data row
        if ".." in fpath.split("/"):
            # fnmatch's `*` crosses `/`, so a traversal path can match the glob —
            # reject it loudly before anything derives a filesystem path from it.
            problems.append(
                f"structural-debt row file `{fpath}` contains a `..` segment "
                "(must be a plain repo-relative spec path) — fix or remove the row"
            )
            continue
        rule = cells[1] if len(cells) > 1 else ""
        if not rule.startswith("R"):
            problems.append(
                f"structural-debt row for `{fpath}` has no valid rule id in column 2 "
                f"(got '{rule}') — fix or remove the row"
            )
            continue
        raw_baseline = cells[4] if len(cells) > 4 else ""
        baseline: int | None = None
        if raw_baseline not in ("", "-", "—"):
            # ASCII digits ONLY, bounded length: bare isdigit() also accepts
            # '²'/'①' (which int() rejects → uncaught ValueError) and int() itself
            # accepts signs and non-ASCII Nd digits like '٩٠٦'; CPython 3.11+'s
            # int() additionally raises past sys.get_int_max_str_digits() (4300)
            # even on pure ASCII digits. All of it is malformed-row territory,
            # never a crash or a silent parse — and no body line count needs more
            # than 9 digits.
            if raw_baseline.isascii() and raw_baseline.isdigit() and len(raw_baseline) <= 9:
                baseline = int(raw_baseline)
            else:
                problems.append(
                    f"structural-debt row ({fpath}, {rule}) has a malformed baseline "
                    f"'{raw_baseline}' (must be a body line count) — the row does NOT suppress"
                )
                continue
        if baseline is not None and rule != BASELINE_RULE:
            problems.append(
                f"structural-debt row ({fpath}, {rule}): a baseline is only valid for "
                f"{BASELINE_RULE} rows — remove it or fix the rule id"
            )
            continue
        if (fpath, rule) in rows:
            problems.append(
                f"duplicate structural-debt row ({fpath}, {rule}) — keep exactly one"
            )
            continue
        rows[(fpath, rule)] = {
            "reason": cells[2] if len(cells) > 2 else "",
            "added": cells[3] if len(cells) > 3 else "",
            "baseline": baseline,
        }
    return rows, problems


def filter_structural(
    findings: list[Finding],
    debt_rows: dict[tuple[str, str], dict],
    body_lines_by_file: dict[str, int],
) -> tuple[list[Finding], list[Finding], list[str]]:
    """``(blocking, suppressed, problems)`` for the full-surface gate. PURE.

    ``findings`` = the WHOLE surface's lint findings (all severities — advisory
    findings keep a pre-flip debt row "live" for the staleness check, but only
    ``severity == "gate"`` findings can block or be suppressed). ``debt_rows`` =
    ``parse_structural_debt`` rows. ``body_lines_by_file`` = current body line
    counts, consulted only for rows carrying a baseline.

      - gate finding, no row            → blocking
      - gate finding, row w/o baseline  → suppressed
      - gate finding, row w/ baseline   → suppressed iff count <= baseline,
                                          blocking once the body GROWS past it;
                                          a missing count is a loud problem +
                                          blocking (never a silent exemption)
      - row with no live (file, rule) finding of ANY severity → stale problem
        (the self-cleaning invariant: fix the file ⇒ remove the row, same PR)
    """
    blocking: list[Finding] = []
    suppressed: list[Finding] = []
    problems: list[str] = []
    live_keys = {(f.file, f.rule_id) for f in findings}

    for f in findings:
        if f.severity != SEV_GATE:
            continue
        row = debt_rows.get((f.file, f.rule_id))
        if row is None:
            blocking.append(f)
            continue
        baseline = row.get("baseline")
        if baseline is None:
            suppressed.append(f)
            continue
        if not isinstance(baseline, int):
            # parse_structural_debt only emits int | None, but this is a public
            # pure function — a degenerate injected row must be loud, not a
            # TypeError out of `count <= baseline` (mirror of the count guard).
            problems.append(
                f"({f.file}, {f.rule_id}): debt row carries a non-integer baseline "
                f"{baseline!r} — treating the finding as blocking"
            )
            blocking.append(f)
            continue
        count = body_lines_by_file.get(f.file)
        if not isinstance(count, int):
            problems.append(
                f"({f.file}, {f.rule_id}): baseline row but no current body line count "
                "is available — treating the finding as blocking"
            )
            blocking.append(f)
        elif count <= baseline:
            suppressed.append(f)
        else:
            blocking.append(f)  # grew past the grandfathered baseline

    for key in sorted(debt_rows):
        if key not in live_keys:
            problems.append(
                f"stale structural-debt row ({key[0]}, {key[1]}): no live finding for "
                "this (file, rule) — the file was fixed or the rule renamed; remove the row"
            )
    return blocking, suppressed, problems


def collect_body_counts(debt_rows: dict[tuple[str, str], dict], read_text) -> dict[str, int]:
    """Current BODY line counts for every baseline-carrying debt row. PURE (the
    file read is injected as ``read_text(fpath) -> str``, so the unit cases can
    drive this glue hermetically — a real end-to-end baseline pair is impossible
    until R2 itself flips to gate severity, BC-13216).

    Counts BODY lines (``body_lines`` — frontmatter excluded), matching what R2
    itself measures; an unreadable/empty file contributes no entry (the filter
    then raises the loud missing-count problem rather than silently exempting).
    """
    counts: dict[str, int] = {}
    for (fpath, _rule), row in debt_rows.items():
        if row.get("baseline") is not None:
            text = read_text(fpath)
            if text:
                counts[fpath] = len(body_lines(text))
    return counts


# ══════════════════════════════════════════════════════════════════════════════
# I/O shell — git, run_eval, filesystem (kept thin; delegates to the pure core)
# ══════════════════════════════════════════════════════════════════════════════


class GateError(Exception):
    """Could-not-run (→ exit 2): an unresolvable diff base, not a policy block."""


def _git_env() -> dict:
    return {k: v for k, v in os.environ.items() if k not in GIT_ENV_STRIP}


def _run_git(args: list[str], cwd: Path) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["git", *args], cwd=str(cwd), env=_git_env(),
        capture_output=True, text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def changed_commands(
    repo_root: Path,
    base_ref: str,
    head_ref: str,
    name_status: str | None = None,
) -> dict[str, bool]:
    """The changed ``plugins/*/commands/*.md`` set → ``{path: is_new}``.

    Tests inject ``name_status`` (raw ``git diff --name-status`` text) to stay
    hermetic; the live run computes it from a two-arg ``git diff --no-renames
    --name-status base head`` (avoids a merge-base, so it's correct on a shallow
    ``pull_request`` merge checkout where HEAD already includes the base — the
    BC-12410 idiom). ``--no-renames`` makes a rename deterministically appear as
    A+D regardless of the runner's git config."""
    if name_status is not None:
        return classify_changes(name_status)

    # Defensive base resolution — only for the canonical origin/main base, and only
    # when it isn't already present (a CI checkout may not set the tracking ref). A
    # non-origin/main base (the self-test's local refs) NEVER triggers a fetch, so
    # the hermetic tests can't reach the network.
    if base_ref == "origin/main":
        rc, _, _ = _run_git(["rev-parse", "--verify", "--quiet", base_ref], repo_root)
        if rc != 0:
            _run_git(["fetch", "--depth=1", "origin", "main"], repo_root)
            base_ref = "FETCH_HEAD"

    rc, out, err = _run_git(
        ["diff", "--no-renames", "--name-status", base_ref, head_ref], repo_root
    )
    if rc != 0:
        raise GateError(
            f"could not resolve the diff base ({base_ref}..{head_ref}): "
            f"{err.strip() or 'git diff failed'}"
        )
    return classify_changes(out)


def command_surface(repo_root: Path) -> list[str]:
    """Every command spec on disk, repo-relative + sorted (the gate's unit)."""
    return sorted(
        p.relative_to(repo_root).as_posix() for p in repo_root.glob(COMMAND_GLOB)
    )


def _bare_id(cmd_path: str) -> str:
    """The ADAPTERS lookup key for a command path (basename without .md)."""
    return Path(cmd_path).stem


def eval_state(cmd_path: str, repo_root: Path) -> str:
    """'pass' | 'fail' | 'absent' for a command's behavioral eval.

    'absent' when the command's bare id isn't in ``ADAPTERS``. Otherwise the eval is
    actually RUN (``run_eval.py <id>``; sub-second + hermetic for plan-campaign) so a
    changed command that BROKE its registered eval blocks — registration alone is not
    enough. run_eval resolves its own absolute artifact paths, so a synthetic test
    surface (whose basenames aren't in ADAPTERS) never shells out → stays hermetic."""
    if _bare_id(cmd_path) not in ADAPTERS:
        return "absent"
    proc = subprocess.run(
        [sys.executable, str(RUN_EVAL), _bare_id(cmd_path)],
        cwd=str(repo_root), env=_git_env(), capture_output=True, text=True,
    )
    return "pass" if proc.returncode == 0 else "fail"


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def waiver_reason_of(cmd_path: str, repo_root: Path) -> str | None:
    """The in-file ``# eval-waiver: <reason>`` reason via the canonical parse_marker:
    None = absent, '' = empty marker (no-suppress), else the reason string."""
    return parse_marker(_read_text(repo_root / cmd_path), WAIVER_TOKEN)


def structural_gate_reasons(cmd_path: str, repo_root: Path) -> list[str]:
    """The R1 (gate-tier) findings on a command, as block-reason strings — what flips
    to blocking. Advisory findings are dropped (they stay WARN, surfaced by
    validate.sh §15a-bc-12588). Reads ``severity`` only; zero re-detection."""
    return [
        f"structural[{f.rule_id}]: {f.message}"
        for f in lint_spec(repo_root / cmd_path)
        if f.severity == SEV_GATE
    ]


def evald_command_paths(repo_root: Path, surface: list[str]) -> tuple[set[str], list[str]]:
    """Resolve ``ADAPTERS`` bare ids → surface command paths. Exactly-one match is
    expected; >1 is the collision trap (hard error → migrate to a plugin-qualified
    key); 0 is skipped (a synthetic test surface, or an adapter whose command was
    deleted — rare and out of Phase-1 scope)."""
    by_stem: dict[str, list[str]] = {}
    for c in surface:
        by_stem.setdefault(Path(c).stem, []).append(c)
    paths: set[str] = set()
    errors: list[str] = []
    for key in ADAPTERS:
        matches = by_stem.get(key, [])
        if len(matches) == 1:
            paths.add(matches[0])
        elif len(matches) > 1:
            errors.append(
                f"ADAPTERS id '{key}' is ambiguous — matches {matches}; "
                "migrate ADAPTERS to a plugin-qualified key"
            )
    return paths, errors


def waiver_marker_paths(repo_root: Path, surface: list[str]) -> set[str]:
    """Surface commands carrying a VALID (non-empty) in-file ``# eval-waiver`` marker.
    An empty marker is not a valid waiver, so it isn't coupled to a debt row here."""
    out: set[str] = set()
    for c in surface:
        r = parse_marker(_read_text(repo_root / c), WAIVER_TOKEN)
        if r:  # non-empty reason only
            out.add(c)
    return out


def collect_decision(cmd_path: str, repo_root: Path, debt: set[str], is_new: bool) -> Decision:
    """Gather the facts for one changed command (the only place I/O meets the core)."""
    return decide(
        command=cmd_path,
        structural_block_reasons=structural_gate_reasons(cmd_path, repo_root),
        eval_status=eval_state(cmd_path, repo_root),
        on_debt=cmd_path in debt,
        waiver_reason=waiver_reason_of(cmd_path, repo_root),
        is_new=is_new,
    )


# ── modes ─────────────────────────────────────────────────────────────────────


def run_diff_gate(
    repo_root: Path, base_ref: str, head_ref: str,
    name_status: str | None, as_json: bool,
) -> int:
    changed = changed_commands(repo_root, base_ref, head_ref, name_status)
    debt = set(parse_debt_table(_read_text(repo_root / DEBT_LIST_REL)))
    decisions = [
        collect_decision(c, repo_root, debt, is_new)
        for c, is_new in sorted(changed.items())
    ]
    blocked = [d for d in decisions if d.blocked]

    if as_json:
        print(json.dumps({
            "changed": [{"command": c, "is_new": n} for c, n in sorted(changed.items())],
            "blocked": [d.command for d in blocked],
            "decisions": [
                {"command": d.command, "blocked": d.blocked, "status": d.status,
                 "block_reasons": d.block_reasons, "notes": d.notes}
                for d in decisions
            ],
        }, indent=2))
    else:
        print(f"=== eval-gate (BC-12590) — diff {base_ref}..{head_ref} ===")
        if not decisions:
            print("  no changed command specs in the diff — nothing to gate")
        for d in decisions:
            if d.blocked:
                print(f"  BLOCK  {d.command}")
                for r in d.block_reasons:
                    print(f"           - {r}")
            else:
                tag = {"ok-eval": "OK    ", "exempt-grandfathered": "EXEMPT",
                       "exempt-waiver": "WAIVER"}.get(d.status, "OK    ")
                note = f" — {d.notes[0]}" if d.notes else ""
                print(f"  {tag} {d.command}{note}")
        print(f"GATE changed={len(decisions)} blocked={len(blocked)}")
    return 1 if blocked else 0


def run_check(repo_root: Path, as_json: bool) -> int:
    surface = command_surface(repo_root)
    evald, amb_errors = evald_command_paths(repo_root, surface)
    debt_rows = parse_debt_table(_read_text(repo_root / DEBT_LIST_REL))
    markers = waiver_marker_paths(repo_root, surface)

    problems = list(amb_errors) + check_invariants(surface, evald, debt_rows, markers)

    if as_json:
        print(json.dumps({
            "surface": len(surface), "evald": sorted(evald), "debt": len(debt_rows),
            "waiver_markers": sorted(markers), "ambiguous": amb_errors,
            "problems": problems, "ok": not problems,
        }, indent=2))
    else:
        print("=== eval-gate --check (debt-list integrity) ===")
        print(f"  surface={len(surface)} eval'd={len(evald)} debt-listed={len(debt_rows)} "
              f"waiver-markers={len(markers)}")
        if not problems:
            print("  OK — debt ∩ ADAPTERS == ∅, debt ∪ ADAPTERS == surface, waivers coupled")
        for p in problems:
            print(f"  PROBLEM  {p}")
    return 1 if problems else 0


def run_structural(repo_root: Path, as_json: bool) -> int:
    """The ADR-033 full-surface structural gate (thin shell over the pure core).

    Diff-free: lints every spec ``scan_surface`` yields, normalizes finding paths to
    THIS repo_root (structural_lint's ``_rel`` resolves against its own module root,
    which differs under ``--repo-root`` — e.g. the self-test's synthetic repos), then
    filters through the structural-debt rows. Exit 0 = clean; 1 = a blocking finding
    or a list-integrity problem; 2 = the scan itself could not run.
    """
    try:
        targets = scan_surface(repo_root)
        findings: list[Finding] = []
        for t in targets:
            rel = t.relative_to(repo_root).as_posix()
            for f in lint_path(t):
                f.file = rel  # normalize: every rule stamps the linted spec's path
                findings.append(f)
    except Exception as e:
        raise GateError(f"could not scan the structural surface: {e}") from e

    debt_rows, problems = parse_structural_debt(_read_text(repo_root / STRUCTURAL_DEBT_REL))

    # Current body line counts — only for baseline (R2) rows. At most one
    # baseline row per file can exist (the parser rejects duplicates and
    # non-R2 baselines), so no dedup is needed.
    body_counts = collect_body_counts(debt_rows, lambda p: _read_text(repo_root / p))

    blocking, suppressed, fproblems = filter_structural(findings, debt_rows, body_counts)
    problems += fproblems

    if as_json:
        print(json.dumps({
            "surface": len(targets),
            "gate_findings": len(blocking) + len(suppressed),
            "blocking": [asdict(f) for f in blocking],
            "suppressed": [asdict(f) for f in suppressed],
            "debt_rows": len(debt_rows),
            "problems": problems,
            "ok": not blocking and not problems,
        }, indent=2))
    else:
        print("=== eval-gate --structural (ADR-033 full-surface structural gate) ===")
        print(f"  surface={len(targets)} gate-findings={len(blocking) + len(suppressed)} "
              f"debt-rows={len(debt_rows)}")
        for f in blocking:
            note = ""
            row = debt_rows.get((f.file, f.rule_id))
            count = body_counts.get(f.file)
            if row is not None and row.get("baseline") is not None and count is not None:
                # count can be None on the missing-body-count path — the PROBLEM
                # line is the sole explanation there; this note covers only growth.
                note = f" (body grew to {count} lines, past the grandfathered baseline {row['baseline']})"
            print(f"  BLOCK  [{f.rule_id}] {finding_loc(f)} — {f.message}{note}")
        for f in suppressed:
            row = debt_rows[(f.file, f.rule_id)]  # suppressed ⇒ a row exists
            tail = f", baseline {row['baseline']}" if row.get("baseline") is not None else ""
            print(f"  SUPPRESSED  [{f.rule_id}] {f.file} (structural-debt row{tail})")
        for p in problems:
            print(f"  PROBLEM  {p}")
        if not blocking and not problems:
            print("  OK — no unfiltered gate-tier findings on the structural surface")
        print(f"STRUCTURAL blocking={len(blocking)} suppressed={len(suppressed)} "
              f"problems={len(problems)}")
    return 1 if blocking or problems else 0


# ── bootstrap (one-time / regen, like run_eval --update-golden) ────────────────

_DEBT_HEADER = """\
# Skill / command eval-debt list (ADR-028 Phase-1, BC-12590)

<!--
  MACHINE-READ by scripts/eval/eval_gate.py. Keep the table below as the single
  source of truth for which existing commands are grandfathered (no behavioral
  eval yet). Schema (positional columns; rows keyed on the full repo-relative path
  so colliding basenames like ship/review/session-start stay distinct):

    | command | plugin | status | reason | added |

  status ∈ { grandfathered, waiver }.
    - grandfathered: a PRE-EXISTING (bootstrap-time) command with no eval yet — the
      Phase-2 backfill set. A grandfathered row does NOT clear a NET-NEW command
      (one added in the same PR): note #1 keys net-new on the git ADD status, so
      laundering a new command in as "grandfathered" is blocked by the diff-gate.
    - waiver: a command that genuinely can't be eval'd yet. It MUST also carry an
      in-file `# eval-waiver: <reason>` marker (ADR-028 D1: explicit, finite, never
      silent). The --check lint enforces the coupling in BOTH directions.

  Regenerate the grandfathered set from the live surface with:
    python3 scripts/eval/eval_gate.py --bootstrap --added <YYYY-MM-DD>
  …and PR-review the diff. After bootstrap, add/remove rows BY HAND as commands land
  or get evals (re-running --bootstrap overwrites hand edits — it's a regen, not a
  merge). The --check integrity lint keeps the file honest vs the live surface.
-->

This file is the **forward-only ratchet's grandfather record** (ADR-028 D1) and the
**Phase-2 backlog**. The M5 gate (`scripts/eval/eval_gate.py`) reads it two ways:

- **diff-gate** (the `pull_request` CI job): a *changed, pre-existing* command on this
  list stays **eval-exempt** (Split A′ — the eval is grandfathered, deferred to
  Phase 2). A *net-new* command (git ADD) is NOT cleared by a grandfathered row — it
  needs a passing eval or a `# eval-waiver` marker. Structural R1
  (`disable-model-invocation`) is **not** grandfathered — it blocks any changed
  command regardless of this list (gated by changed-set membership alone).
- **`--check`** (the integrity lint, run in `validate.sh`): enforces
  `debt ∩ ADAPTERS == ∅`, `debt ∪ ADAPTERS == the full command surface`, and the
  symmetric `status: waiver` ⇔ in-file `# eval-waiver` coupling — so a net-new command
  can't merge un-recorded, a deleted command can't leave a stale row, and a waiver can
  never be silent. This is what keeps the list honest and waivers "never silent."

## Phase-2 trigger (ADR-028 D1)

Phase 2 (retroactive backfill of behavioral evals across the commands below, and
promotion of advisory structural checks to blocking) starts when **both** hold:

1. the behavioral-eval harness has shipped and is **proven on ≥3 forward commands**
   (today: 1 — `plan-campaign`); **and**
2. the **per-eval authoring cost is known** (so the retrofit across this list is
   estimable).

Until then this is a forward-only gate: it bites net-new / changed commands, not the
grandfathered surface. Committing to Phase 2 up front is what stops "forward-only"
from becoming "forever-only."

## Grandfathered / waived commands

"""


def run_bootstrap(repo_root: Path, added: str) -> int:
    surface = command_surface(repo_root)
    evald, amb = evald_command_paths(repo_root, surface)
    if amb:
        for e in amb:
            sys.stderr.write(f"ERROR: {e}\n")
        return 2
    rows = []
    for c in surface:
        if c in evald:
            continue  # has an eval → not debt
        plugin = c.split("/")[1]
        has_r1 = any(
            f.rule_id.startswith("R1")
            for f in lint_spec(repo_root / c) if f.severity == SEV_GATE
        )
        reason = "no-eval (pre-ADR-028)" + ("; R1 side-effecting (untouched)" if has_r1 else "")
        rows.append((c, plugin, "grandfathered", reason, added))

    lines = [_DEBT_HEADER.rstrip("\n"), "",
             "| command | plugin | status | reason | added |",
             "|---|---|---|---|---|"]
    for c, plugin, status, reason, add in rows:
        lines.append(f"| `{c}` | {plugin} | {status} | {reason} | {add} |")
    lines.append("")
    out = repo_root / DEBT_LIST_REL
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"bootstrapped {len(rows)} grandfathered command(s) → {out.relative_to(repo_root).as_posix()}")
    return 0


# ── CLI ───────────────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="M5 forward-only eval gate (BC-12590 / ADR-028)")
    ap.add_argument("--base-ref", default="origin/main", help="diff base (default origin/main)")
    ap.add_argument("--head-ref", default="HEAD", help="diff head (default HEAD)")
    ap.add_argument("--name-status", default=None,
                    help="raw `git diff --name-status` text (hermetic test hook; skips git)")
    ap.add_argument("--repo-root", default=str(REPO_ROOT))
    ap.add_argument("--check", action="store_true", help="run the debt-list integrity lint (diff-free)")
    ap.add_argument("--structural", action="store_true",
                    help="full-surface structural gate (ADR-033): fail on any gate-tier "
                         "lint finding not covered by docs/structural-lint-debt.md")
    ap.add_argument("--bootstrap", action="store_true",
                    help="(re)generate docs/skill-eval-debt.md from the live surface")
    ap.add_argument("--added", default="", help="the 'added' date written by --bootstrap (YYYY-MM-DD)")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()

    try:
        if args.bootstrap:
            if not args.added:
                sys.stderr.write("ERROR: --bootstrap requires --added <YYYY-MM-DD>\n")
                return 2
            return run_bootstrap(repo_root, args.added)
        if args.check:
            return run_check(repo_root, args.json)
        if args.structural:
            return run_structural(repo_root, args.json)
        return run_diff_gate(repo_root, args.base_ref, args.head_ref, args.name_status, args.json)
    except GateError as e:
        sys.stderr.write(f"ERROR: {e}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
