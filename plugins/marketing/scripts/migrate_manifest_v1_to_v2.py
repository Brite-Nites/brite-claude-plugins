#!/usr/bin/env python3
"""Migrate v1 GTM campaign manifests to v2 (BC-11852 / ADR-020).

Walks a campaigns root, finds every `docs/campaigns/<entity>/<slug>/manifest.json`,
and converts schema_version: 1 manifests in place to schema_version: 2 by:

  - REMOVING the singular `email_bison.campaign_id` field.
  - REPLACING it with an `email_bison.campaigns[]` array. When the v1
    `campaign_id` was non-null, the array gets a single record with the
    extracted id + workspace + a placeholder `audience_tier` (`{"tier":
    "professional", "seniority": null, "modifiers": []}`) flagged for
    operator review via the new `pending_classification: true` marker.
    When `campaign_id` was null (unlaunched), the array stays empty.
  - APPENDING a `migrated_from` block recording the prior schema_version
    + ISO-8601 UTC migration timestamp + this script's path. This block is
    purely audit metadata — downstream readers ignore it.

Idempotency: an already-v2 manifest is left unchanged (no-op). Re-running
the script in a row is safe — the second run touches zero files. The
`migrated_from` block is itself never modified after the first migration;
re-running on a v2 manifest is detected by the `schema_version` check
BEFORE any disk write happens.

Per CLAUDE.md § Conventions: stdlib only (no PyYAML/json5/jsonschema).
Per CLAUDE.md anti-creep guidance: this script does NOT write to any path
outside the campaigns subtree it was pointed at. All edits are in-place
manifest.json rewrites; no logs, no sidecar files, no canonicals mutation.

Usage:

  python3 plugins/marketing/scripts/migrate_manifest_v1_to_v2.py
  python3 plugins/marketing/scripts/migrate_manifest_v1_to_v2.py --campaigns-root path/to/docs/campaigns
  python3 plugins/marketing/scripts/migrate_manifest_v1_to_v2.py --dry-run

Exit codes:
  0 — every manifest was already v2 OR was successfully migrated to v2.
  1 — one or more manifests aborted (malformed JSON, unexpected schema_version,
      structural anomaly). Other manifests were processed normally.
  2 — usage error (campaigns root missing or unreadable).
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_CAMPAIGNS_ROOT = Path("docs/campaigns")

# The placeholder audience_tier inserted when a v1 manifest had a non-null
# campaign_id but no audience-tier signal. Operators must classify these
# manually via /marketing:import-campaign (BC-11849) — the
# pending_classification marker makes that a grep-able TODO.
PLACEHOLDER_AUDIENCE_TIER: dict[str, Any] = {
    "tier": "professional",
    "seniority": None,
    "modifiers": [],
}


def migrate_one(
    manifest_path: Path,
    *,
    dry_run: bool,
    now_iso: str,
    script_label: str,
) -> str:
    """Migrate one manifest.json. Returns a status string.

    Status:
      "v2-already"    — schema_version was already 2; no change.
      "migrated"      — converted v1 → v2 (written, or would be in dry-run).
      "abort:<reason>" — malformed JSON, missing schema_version,
                         unexpected schema_version, missing email_bison block.
    """
    try:
        text = manifest_path.read_text()
    except OSError as exc:
        return f"abort:read-failed:{exc}"
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        return f"abort:invalid-json:line{exc.lineno}-col{exc.colno}"
    if not isinstance(data, dict):
        return f"abort:not-a-mapping:got-{type(data).__name__}"

    sv = data.get("schema_version")
    if sv == 2:
        return "v2-already"
    if sv != 1:
        return f"abort:unexpected-schema-version:{sv!r}"

    eb = data.get("email_bison")
    if not isinstance(eb, dict):
        return f"abort:missing-or-malformed-email_bison:{type(eb).__name__}"

    # Build the v2 email_bison block. workspace + campaign_name are retained;
    # campaign_id (singular) is removed; campaigns[] is constructed from the
    # v1 singular fields when launched (campaign_id != null), or left empty
    # when unlaunched.
    workspace = eb.get("workspace")
    campaign_name = eb.get("campaign_name")
    legacy_campaign_id = eb.get("campaign_id")
    legacy_launched_at = eb.get("launched_at")

    if workspace is None:
        return "abort:email_bison.workspace-missing"
    if campaign_name is None:
        return "abort:email_bison.campaign_name-missing"

    campaigns: list[dict[str, Any]] = []
    if legacy_campaign_id is not None:
        # Construct a single placeholder record. The placeholder
        # audience_tier carries `pending_classification: true` so a
        # downstream operator + the BC-11849 importer can find + correct
        # these via grep.
        record: dict[str, Any] = {
            "workspace": workspace,
            "campaign_id": legacy_campaign_id,
            "audience_tier": dict(PLACEHOLDER_AUDIENCE_TIER),
            "pending_classification": True,
        }
        if isinstance(eb.get("name"), str):
            record["name"] = eb["name"]
        if legacy_launched_at is not None:
            record["launched_at"] = legacy_launched_at
            record["status"] = "launched"
        else:
            record["status"] = "draft"
        campaigns.append(record)

    new_eb: dict[str, Any] = {
        "workspace": workspace,
        "campaign_name": campaign_name,
        "campaigns": campaigns,
    }

    # Update the top-level manifest. Preserve every other field verbatim —
    # this script ONLY rewrites schema_version + email_bison + appends
    # migrated_from. Other unknown keys (forward-compat) survive unchanged.
    new_data: dict[str, Any] = {}
    for key, value in data.items():
        if key == "schema_version":
            new_data[key] = 2
        elif key == "email_bison":
            new_data[key] = new_eb
        else:
            new_data[key] = value
    new_data["migrated_from"] = {
        "schema_version": 1,
        "migrated_at": now_iso,
        "migrated_by": script_label,
    }

    if dry_run:
        return "migrated"

    # Use a 2-space indent + trailing newline to match the original
    # cohort-1 manifest authored by /marketing:plan-campaign.
    serialized = json.dumps(new_data, indent=2) + "\n"
    try:
        manifest_path.write_text(serialized)
    except OSError as exc:
        return f"abort:write-failed:{exc}"
    return "migrated"


def iter_manifests(campaigns_root: Path):
    """Yield manifest.json paths under campaigns_root.

    Mirrors `plugins/marketing/scripts/_shared/manifest_loader.py` glob
    convention: `<root>/<entity>/<slug>/manifest.json`, skip `_reviews/`.
    """
    if not campaigns_root.is_dir():
        return
    for p in sorted(campaigns_root.glob("*/*/manifest.json")):
        if "_reviews" in p.parts:
            continue
        yield p


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--campaigns-root",
        type=Path,
        default=DEFAULT_CAMPAIGNS_ROOT,
        help="Campaigns root (default: docs/campaigns relative to cwd).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report planned writes without touching the filesystem.",
    )
    parser.add_argument(
        "--migrated-at",
        default=None,
        help=(
            "Override the migrated_from.migrated_at ISO-8601 timestamp "
            "(default: current UTC time). Useful for deterministic tests."
        ),
    )
    parser.add_argument(
        "--script-label",
        default=(
            "plugins/marketing/scripts/migrate_manifest_v1_to_v2.py (BC-11852)"
        ),
        help="Override the migrated_from.migrated_by string (tests).",
    )
    args = parser.parse_args(argv)

    campaigns_root: Path = args.campaigns_root
    if not campaigns_root.exists():
        sys.stderr.write(
            f"ERROR: campaigns root does not exist: {campaigns_root}\n"
        )
        return 2

    now_iso = (
        args.migrated_at
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    )

    print(
        f"BC-11852 manifest v1 → v2 migration ({'DRY-RUN' if args.dry_run else 'LIVE'})"
    )
    print(
        f"Campaigns root: {campaigns_root.resolve() if campaigns_root.exists() else campaigns_root}"
    )

    counts = {"migrated": 0, "v2-already": 0, "abort": 0}
    aborts: list[tuple[Path, str]] = []

    for manifest_path in iter_manifests(campaigns_root):
        status = migrate_one(
            manifest_path,
            dry_run=args.dry_run,
            now_iso=now_iso,
            script_label=args.script_label,
        )
        rel = manifest_path
        try:
            rel = manifest_path.relative_to(campaigns_root)
        except ValueError:
            pass
        if status == "migrated":
            counts["migrated"] += 1
            tag = "DRY  " if args.dry_run else "MOVE "
            print(f"  {tag}  {rel}")
        elif status == "v2-already":
            counts["v2-already"] += 1
            print(f"  SKIP   {rel}  (already v2)")
        else:
            counts["abort"] += 1
            aborts.append((manifest_path, status))
            sys.stderr.write(f"  ABORT  {rel}  ({status})\n")

    print(
        f"\nSummary: migrated={counts['migrated']}  v2-already={counts['v2-already']}  "
        f"abort={counts['abort']}"
        f"{'  (dry-run)' if args.dry_run else ''}"
    )

    if counts["abort"]:
        sys.stderr.write(
            "One or more manifests aborted. Resolve the issues above and re-run.\n"
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
