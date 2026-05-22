#!/usr/bin/env python3
"""Migrate pre-BC-8719 long-form entity directories to the short-form canonical.

Per BC-8719 (O15 migration), the canonical filesystem layout for campaign
artifacts is `docs/campaigns/{short_entity}/` where `{short_entity}` is one of
`nites` / `supply` / `labs`. Before BC-8719, `campaign-debrief` wrote to the
long-form `docs/campaigns/brite-{short_entity}/` while sibling skills used
short-form, creating parallel directories that did not overlap on disk.

This script walks the three known long-form directories under a target
campaigns root, moves their contents into the matching short-form directory,
and reports each move. Safety rules:

  - Aborts (per long-form entity) if the short-form destination directory
    already exists. Operators must resolve overlap manually — the script will
    not merge or overwrite. This protects against duplicate-entry footguns
    introduced by skill runs between BC-8719 deployment and migration.
  - Idempotent on re-run: if a long-form directory is absent, the entity is a
    no-op. Running twice in a row is safe.
  - Read-only on `docs/` outside the three known long-form paths. Never
    touches non-`brite-*` entries.

Usage:

  python3 plugins/marketing/scripts/migrate_entity_slugs.py
  python3 plugins/marketing/scripts/migrate_entity_slugs.py --campaigns-root path/to/docs/campaigns
  python3 plugins/marketing/scripts/migrate_entity_slugs.py --dry-run

Exits 0 on success (including no-op), 1 on any abort (destination conflict).
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ENTITIES = ("nites", "supply", "labs")
DEFAULT_CAMPAIGNS_ROOT = Path("docs/campaigns")


def migrate_entity(
    campaigns_root: Path,
    short_entity: str,
    *,
    dry_run: bool,
) -> str:
    """Migrate one entity's long-form directory to short-form.

    Returns a status string:
      "moved"  — long-form existed and was moved (or would be in dry-run)
      "noop"   — long-form did not exist; nothing to do
      "abort"  — long-form AND short-form both exist; conflict needs operator
    """
    long_dir = campaigns_root / f"brite-{short_entity}"
    short_dir = campaigns_root / short_entity

    if not long_dir.exists():
        return "noop"

    if long_dir.is_symlink():
        print(
            f"  ABORT  brite-{short_entity}/ → {short_entity}/ — long-form path is a symlink ({long_dir} → {long_dir.resolve()}).\n"
            f"         Refusing to move: shutil.move would rename the symlink without touching its target.\n"
            f"         Resolve manually: delete the symlink and either re-create the data at the short-form path, or re-run after replacing it with a real directory.",
            file=sys.stderr,
        )
        return "abort"

    if short_dir.exists():
        print(
            f"  ABORT  brite-{short_entity}/ → {short_entity}/ — destination already exists.\n"
            f"         Long-form: {long_dir}\n"
            f"         Short-form: {short_dir}\n"
            f"         Resolve manually: merge entries or delete one side, then re-run.",
            file=sys.stderr,
        )
        return "abort"

    try:
        child_count = sum(1 for _ in long_dir.iterdir())
    except OSError:
        child_count = 0

    if dry_run:
        print(f"  DRY    brite-{short_entity}/ → {short_entity}/  ({child_count} child entries would move)")
        return "moved"

    try:
        shutil.move(str(long_dir), str(short_dir))
    except (OSError, shutil.Error) as exc:
        print(
            f"  ERROR  brite-{short_entity}/ → {short_entity}/ — move failed: {exc}\n"
            f"         Partial state may exist at both paths. Inspect and resolve manually before re-running.",
            file=sys.stderr,
        )
        return "abort"
    print(f"  MOVE   brite-{short_entity}/ → {short_entity}/  ({child_count} child entries moved)")
    return "moved"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--campaigns-root",
        type=Path,
        default=DEFAULT_CAMPAIGNS_ROOT,
        help="Campaigns root directory (default: docs/campaigns relative to cwd)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would move without touching the filesystem.",
    )
    args = parser.parse_args(argv)

    campaigns_root: Path = args.campaigns_root
    print(f"BC-8719 entity-slug migration ({'DRY-RUN' if args.dry_run else 'LIVE'})")
    print(f"Campaigns root: {campaigns_root.resolve() if campaigns_root.exists() else campaigns_root}")

    if not campaigns_root.exists():
        print(
            f"  NOTE   campaigns root '{campaigns_root}' does not exist — nothing to migrate (no-op).",
        )
        return 0

    aborted = 0
    moved = 0
    noops = 0
    for entity in ENTITIES:
        status = migrate_entity(campaigns_root, entity, dry_run=args.dry_run)
        if status == "abort":
            aborted += 1
        elif status == "moved":
            moved += 1
        else:
            noops += 1

    print(
        f"\nSummary: moved={moved}  noop={noops}  abort={aborted}"
        f"{'  (dry-run)' if args.dry_run else ''}"
    )
    if aborted:
        print(
            "One or more entities aborted due to destination conflict. Resolve manually and re-run.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
