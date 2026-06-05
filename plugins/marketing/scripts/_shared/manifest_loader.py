"""Manifest discovery, loading, filtering, and sibling-artifact reading.

Shared utility extracted per Rule-of-Three (BC-8728). Consumers:
  - portfolio_snapshot.py (BC-8731) — load_manifests, filter_in_window
  - icp_refinement_review.py (BC-8726) — load_manifest (single)
  - offer_performance.py (BC-8728) — glob_manifests_by_offer

Stdlib-only per CLAUDE.md § Conventions.
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from . import slug_parts


def glob_campaign_files(
    campaigns_dir: Path, filename: str
) -> list[Path]:
    """Glob docs/campaigns/<entity>/<slug>/<filename> with sorted output.

    Skips `_reviews/` (output dir, never contains campaign artifacts).
    """
    if not campaigns_dir.is_dir():
        return []
    paths = []
    for p in sorted(campaigns_dir.glob(f"*/*/{filename}")):
        if "_reviews" in p.parts:
            continue
        paths.append(p)
    return paths


def load_manifest(path: Path) -> dict[str, Any] | None:
    """Load a single manifest.json. Returns None on read/parse failure."""
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"[BC-8731] Skipping unreadable manifest {path}: {exc}\n")
        return None
    return data


def load_manifests(campaigns_dir: Path) -> list[dict[str, Any]]:
    """Glob docs/campaigns/<entity>/<slug>/manifest.json and load each.

    Each returned dict is augmented with `__path` and `__campaign_dir` keys
    for downstream consumers.
    """
    if not campaigns_dir.is_dir():
        sys.stderr.write(f"ERROR: campaigns directory not found: {campaigns_dir}\n")
        sys.exit(2)
    manifests = []
    for manifest_path in glob_campaign_files(campaigns_dir, "manifest.json"):
        data = load_manifest(manifest_path)
        if data is None:
            continue
        data["__path"] = str(manifest_path)
        data["__campaign_dir"] = str(manifest_path.parent)
        manifests.append(data)
    return manifests


def filter_in_window(
    manifests: list[dict[str, Any]],
    window_start: datetime,
    window_end: datetime,
) -> list[dict[str, Any]]:
    """Filter manifests to those whose launch date is in-window.

    Priority: created_at timestamp > slug fy/m suffix > excluded with warning.
    """
    end_inclusive = window_end.replace(hour=23, minute=59, second=59)
    in_window_list = []
    for m in manifests:
        created_at = m.get("created_at")
        if created_at:
            try:
                normalized = created_at.replace("Z", "+00:00")
                d = datetime.fromisoformat(normalized)
                if window_start <= d <= end_inclusive:
                    in_window_list.append(m)
                continue
            except (ValueError, AttributeError, TypeError):
                pass
        slug = m.get("slug", "")
        launch_month = slug_parts.slug_to_launch_month(slug)
        if launch_month:
            if window_start <= launch_month <= end_inclusive:
                in_window_list.append(m)
        else:
            sys.stderr.write(
                f"[BC-8731] Skipping manifest with no parseable launch date: "
                f"slug={slug!r} created_at={created_at!r} path={m.get('__path', '(unknown)')!r}\n"
            )
    return in_window_list


def glob_manifests_by_offer(
    campaigns_dir: Path, offer_slug: str
) -> list[dict[str, Any]]:
    """Find all manifests whose offer field matches offer_slug."""
    all_manifests = load_manifests(campaigns_dir)
    return [
        m for m in all_manifests
        if m.get("offer") == offer_slug
    ]


def read_sibling_artifacts(manifest_path: Path) -> dict[str, str | None]:
    """Read optional sibling files next to a manifest.json.

    Returns {learnings, mmf_matrix, analyses: [str], discoveries} where
    each value is file content (str) or None if the file is absent/unreadable.
    """
    campaign_dir = manifest_path.parent if isinstance(manifest_path, Path) else Path(manifest_path).parent
    result: dict[str, Any] = {
        "learnings": None,
        "mmf_matrix": None,
        "analyses": [],
        "discoveries": None,
    }

    learnings_path = campaign_dir.parent / "learnings.md"
    if learnings_path.is_file():
        try:
            result["learnings"] = learnings_path.read_text()
        except OSError:
            pass

    mmf_path = campaign_dir / "mmf-matrix.md"
    if mmf_path.is_file():
        try:
            result["mmf_matrix"] = mmf_path.read_text()
        except OSError:
            pass

    for analysis_path in sorted(campaign_dir.glob("analysis-*.md")):
        try:
            result["analyses"].append(analysis_path.read_text())
        except OSError:
            pass

    disc_path = campaign_dir / "discoveries.json"
    if disc_path.is_file():
        try:
            result["discoveries"] = disc_path.read_text()
        except OSError:
            pass

    return result
