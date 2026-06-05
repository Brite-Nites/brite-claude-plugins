#!/usr/bin/env python3
"""Lint the GTM discoveries.json category-tagged signal layer.

Per Phase 2 architectural pivot (memory/project_gtm_campaign_architecture.md)
+ BC-8722. Skills emit category-tagged signals to
docs/campaigns/{entity}/{slug}/discoveries.json; humans promote to handbook
canonicals or prose via PR. BC-8726 (T9-X icp-refinement-review) consumes the
signals downstream.

Source-of-truth for the contract is `discoveries-schema.json` next to
`plugins/marketing/data/`; this linter is the runtime enforcement (Brite repo
is stdlib-only — no jsonschema dependency). It hand-rolls the schema's
type / enum / required / additionalProperties constraints, mirroring
lint_canonicals.py's pattern.

Checks performed:

  File-shape
    1. Each discoveries.json parses as JSON.
    2. Top-level is an object with required keys (schema_version, signals).
    3. No unknown top-level keys (additionalProperties:false).
    4. schema_version == SCHEMA_VERSION (linter pinned to one major).
    5. signals is a list.

  Per-signal
    6. Required keys present (category, emitted_at, emitted_by_skill, payload).
    7. No unknown keys (additionalProperties:false).
    8. category in {title-discovery, icp-refinement, offer-retirement,
       persona-discovery}.
    9. emitted_at parses as ISO-8601 (date or datetime).
   10. emitted_by_skill is a non-empty string.
   11. payload is an object (dict).
   12. promotion_status (if present) in {pending, promoted, rejected}.

Empty case:
  No discoveries.json files anywhere = OK (not an error). BC-8722 is the
  first ship that introduces the schema; per-campaign-run artifacts arrive
  later.

Exit codes:
    0 — all discoveries.json files valid (or none found).
    1 — one or more lint failures (errors printed to stderr).
    2 — usage error (campaigns root missing or unreadable).
"""
from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _shared import manifest_loader

# ── Module-level constants ────────────────────────────────────────────────

SCHEMA_VERSION = 1

ALLOWED_CATEGORIES = frozenset(
    {"title-discovery", "icp-refinement", "offer-retirement", "persona-discovery"}
)

ALLOWED_PROMOTION_STATUS = frozenset({"pending", "promoted", "rejected"})

# Mirror discoveries-schema.json `additionalProperties: false` allowlists.
TOP_LEVEL_KEYS = frozenset({"schema_version", "signals"})
SIGNAL_KEYS = frozenset(
    {"category", "emitted_at", "emitted_by_skill", "payload", "promotion_status"}
)
SIGNAL_REQUIRED = ("category", "emitted_at", "emitted_by_skill", "payload")

DEFAULT_CAMPAIGNS_DIR = (
    Path(__file__).resolve().parents[3] / "docs" / "campaigns"
)


# ── Validators ────────────────────────────────────────────────────────────


def _check_unknown_keys(
    data: dict, allowed: frozenset[str], where: str
) -> list[str]:
    """Mirror schema.json `additionalProperties: false` at one scope."""
    unknown = sorted(set(data.keys()) - allowed)
    return [f"{where}: unknown key '{k}'" for k in unknown]


def _parse_iso8601(value: str) -> bool:
    """Best-effort ISO-8601 parse using stdlib.

    Accepts the date-time form (e.g., `2026-05-22T14:30:00Z` or
    `2026-05-22T14:30:00+00:00`). Trailing-`Z` UTC is normalized to `+00:00`
    for `datetime.fromisoformat`, which doesn't accept the literal `Z` until
    Python 3.11+. Date-only (`2026-05-22`) also accepted — the schema's
    `format: date-time` is advisory under draft-07 for non-validating
    parsers; rejecting bare dates would be stricter than the schema.
    """
    if not isinstance(value, str) or not value:
        return False
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        datetime.datetime.fromisoformat(normalized)
        return True
    except ValueError:
        pass
    try:
        datetime.date.fromisoformat(value)
        return True
    except ValueError:
        return False


def validate_signal(
    signal: object, where: str, idx: int
) -> list[str]:
    """Validate one signals[] entry. Returns the list of errors found."""
    loc = f"{where} signals[{idx}]"
    errs: list[str] = []

    if not isinstance(signal, dict):
        errs.append(f"{loc}: must be an object (got {type(signal).__name__})")
        return errs

    errs.extend(_check_unknown_keys(signal, SIGNAL_KEYS, loc))

    for required in SIGNAL_REQUIRED:
        if required not in signal:
            errs.append(f"{loc}: missing required key '{required}'")
    if any("missing required" in e for e in errs):
        return errs

    category = signal["category"]
    if not isinstance(category, str):
        errs.append(
            f"{loc}: category must be a string (got {type(category).__name__})"
        )
    elif category not in ALLOWED_CATEGORIES:
        errs.append(
            f"{loc}: category {category!r} not in {sorted(ALLOWED_CATEGORIES)}"
        )

    emitted_at = signal["emitted_at"]
    if not isinstance(emitted_at, str):
        errs.append(
            f"{loc}: emitted_at must be a string (got {type(emitted_at).__name__})"
        )
    elif not _parse_iso8601(emitted_at):
        errs.append(
            f"{loc}: emitted_at {emitted_at!r} is not a valid ISO-8601 date or date-time"
        )

    emitted_by_skill = signal["emitted_by_skill"]
    if not isinstance(emitted_by_skill, str):
        errs.append(
            f"{loc}: emitted_by_skill must be a string "
            f"(got {type(emitted_by_skill).__name__})"
        )
    elif not emitted_by_skill.strip():
        errs.append(f"{loc}: emitted_by_skill must be a non-empty string")

    payload = signal["payload"]
    if not isinstance(payload, dict):
        errs.append(
            f"{loc}: payload must be an object (got {type(payload).__name__})"
        )

    promotion_status = signal.get("promotion_status")
    if promotion_status is not None:
        if not isinstance(promotion_status, str):
            errs.append(
                f"{loc}: promotion_status must be a string "
                f"(got {type(promotion_status).__name__})"
            )
        elif promotion_status not in ALLOWED_PROMOTION_STATUS:
            errs.append(
                f"{loc}: promotion_status {promotion_status!r} not in "
                f"{sorted(ALLOWED_PROMOTION_STATUS)}"
            )

    return errs


def validate_file(path: Path) -> list[str]:
    """Validate one discoveries.json file. Returns the list of errors."""
    where = str(path)
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as e:
        return [f"{where}: cannot read file ({type(e).__name__}: {e})"]

    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        return [f"{where}: invalid JSON ({e.msg} at line {e.lineno} col {e.colno})"]

    if not isinstance(data, dict):
        return [
            f"{where}: top-level must be an object (got {type(data).__name__})"
        ]

    errs: list[str] = _check_unknown_keys(data, TOP_LEVEL_KEYS, where)
    for required in ("schema_version", "signals"):
        if required not in data:
            errs.append(f"{where}: missing required key '{required}'")
    if any("missing required" in e for e in errs):
        return errs

    sv = data["schema_version"]
    # Python's `bool` is a subclass of `int`, so `True == 1` silently equates
    # `schema_version: true` to SCHEMA_VERSION=1. Reject non-int explicitly
    # (mirrors lint_canonicals.py's _validate_manifest gotcha).
    if not isinstance(sv, int) or isinstance(sv, bool):
        errs.append(
            f"{where}: schema_version must be an integer "
            f"(got {type(sv).__name__})"
        )
    elif sv != SCHEMA_VERSION:
        errs.append(
            f"{where}: schema_version {sv!r} != linter SCHEMA_VERSION {SCHEMA_VERSION}"
        )

    signals = data["signals"]
    if not isinstance(signals, list):
        errs.append(
            f"{where}: signals must be a list (got {type(signals).__name__})"
        )
        return errs

    for i, signal in enumerate(signals):
        errs.extend(validate_signal(signal, where, i))

    return errs


# ── main ──────────────────────────────────────────────────────────────────


def _emit(errs: list[str]) -> int:
    if errs:
        print("Discoveries lint FAILED:", file=sys.stderr)
        for e in errs:
            print(f"  {e}", file=sys.stderr)
        return 1
    return 0


def discover_files(campaigns_dir: Path) -> list[Path]:
    """Glob docs/campaigns/*/*/discoveries.json. Symlinks rejected at probe.

    Mirrors lint_canonicals.py's symlink-defense pattern — the contract is
    one regular file per campaign run; a symlinked discoveries.json could
    redirect the linter at content outside the campaigns tree.
    """
    return manifest_loader.glob_campaign_files(campaigns_dir, "discoveries.json")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="lint_discoveries.py",
        description=(
            "Validate the GTM discoveries.json category-tagged signal layer "
            "(BC-8722). Walks docs/campaigns/*/*/discoveries.json by "
            "default; pass --campaigns-dir to override or --file to lint a "
            "single file."
        ),
    )
    parser.add_argument(
        "--campaigns-dir",
        type=Path,
        default=DEFAULT_CAMPAIGNS_DIR,
        help="Path to campaigns root (default: docs/campaigns at repo root).",
    )
    parser.add_argument(
        "--file",
        type=Path,
        action="append",
        default=None,
        help=(
            "Lint a specific file instead of walking the campaigns tree. "
            "Repeatable. Useful for ad-hoc validation or test fixtures."
        ),
    )
    args = parser.parse_args(argv)

    files: list[Path] = []
    if args.file:
        for f in args.file:
            if not f.is_file():
                print(f"ERROR: file not found: {f}", file=sys.stderr)
                return 2
            files.append(f)
    else:
        cdir: Path = args.campaigns_dir
        if not cdir.is_dir():
            # Empty case: campaigns dir absent or empty is OK (BC-8722 is the
            # first ship that creates the schema; per-campaign-run artifacts
            # arrive later). Print to stdout so CI logs show the no-op.
            print(
                f"Discoveries lint OK — no docs/campaigns/ directory at {cdir} "
                "(expected pre-first-campaign)."
            )
            return 0
        for p in discover_files(cdir):
            if p.is_symlink():
                print(
                    f"ERROR: {p}: symlinks not allowed under campaigns dir",
                    file=sys.stderr,
                )
                return 1
            files.append(p)

    if not files:
        print(
            "Discoveries lint OK — no discoveries.json files found "
            "(empty case is valid pre-first-campaign-emission)."
        )
        return 0

    all_errs: list[str] = []
    for f in files:
        all_errs.extend(validate_file(f))

    if all_errs:
        return _emit(all_errs)
    print(f"Discoveries lint OK — {len(files)} discoveries.json file(s) validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
