"""Campaign slug parsing and formatting utilities.

Shared utility extracted per Rule-of-Three (BC-8728). The campaign slug
rule is `{vertical}-{persona}-{offer}-fy{YY}-m{MM}` per
handbook/marketing/frameworks/vocabulary.md Section 4.

Consumers:
  - portfolio_snapshot.py (BC-8731) — slug_to_launch_month
  - offer_performance.py (BC-8728) — parse_campaign_slug, format_window_label

Stdlib-only per CLAUDE.md § Conventions.
"""
from __future__ import annotations

import re
from datetime import datetime, timezone

_SLUG_FY_M_RE = re.compile(r"-fy(\d{2})-m(\d{2})(?:-v(\d+))?$")

_FULL_SLUG_RE = re.compile(
    r"^(?P<vertical>[a-z0-9-]+?)"
    r"-(?P<persona>[a-z0-9-]+?)"
    r"-(?P<offer>[a-z0-9-]+?)"
    r"-fy(?P<fy>\d{2})"
    r"-m(?P<mm>\d{2})"
    r"(?:-v(?P<version>\d+))?$"
)


def slug_to_launch_month(slug: str) -> datetime | None:
    """Derive launch month from a `*-fy{YY}-m{MM}(-v{N})?` slug.

    Returns the first day of the launch month as UTC midnight, or None on
    pattern mismatch.
    """
    m = _SLUG_FY_M_RE.search(slug)
    if not m:
        return None
    yy, mm = m.group(1), m.group(2)
    year = 2000 + int(yy)
    month = int(mm)
    if not (1 <= month <= 12):
        return None
    return datetime(year, month, 1, tzinfo=timezone.utc)


def slug_version(slug: str) -> int:
    """Extract version number from slug suffix `-v{N}`. Returns 1 if absent."""
    m = _SLUG_FY_M_RE.search(slug)
    if m and m.group(3):
        return int(m.group(3))
    return 1


def parse_campaign_slug(slug: str) -> dict | None:
    """Parse a full campaign slug into components.

    Returns {vertical, persona, offer, fy, mm, version} or None on mismatch.
    The slug rule is {vertical}-{persona}-{offer}-fy{YY}-m{MM}(-v{N})?.

    NOTE: The regex is greedy-minimal on the three name segments; slugs with
    hyphens in the vertical/persona/offer parts are inherently ambiguous.
    The canonical disambiguator is the offer-slug lookup in canonicals — use
    this function for the fy/m/version suffix, not for reliable segment
    splitting of multi-hyphen names.
    """
    m = _FULL_SLUG_RE.match(slug)
    if not m:
        return None
    return {
        "vertical": m.group("vertical"),
        "persona": m.group("persona"),
        "offer": m.group("offer"),
        "fy": int(m.group("fy")),
        "mm": int(m.group("mm")),
        "version": int(m.group("version")) if m.group("version") else 1,
    }


def format_window_label(year: int, month: int) -> str:
    """Format a year+month as e.g. 'April 2026'."""
    months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    if 1 <= month <= 12:
        return f"{months[month - 1]} {year}"
    return f"M{month:02d} {year}"


def slug_to_path_segments(slug: str) -> dict | None:
    """Derive path-construction segments from a slug.

    Returns {offer_slug, fy_mm_suffix, version_suffix} for building
    `docs/campaigns/{entity}/offers/{offer}/{version}/` paths.
    """
    m = _SLUG_FY_M_RE.search(slug)
    if not m:
        return None
    fy, mm = m.group(1), m.group(2)
    version = int(m.group(3)) if m.group(3) else 1
    offer_part = slug[: m.start()]
    # The offer slug is the last segment before fy/m — strip trailing hyphen.
    # For full slugs like `hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02`,
    # we can't reliably split vertical/persona/offer here (use parse_campaign_slug for that).
    return {
        "offer_slug": offer_part.rstrip("-") if offer_part else None,
        "fy_mm_suffix": f"fy{fy}-m{mm}",
        "version": version,
        "version_suffix": f"v{version}",
    }
