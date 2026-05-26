#!/usr/bin/env python3
"""Section composer for /marketing:portfolio-snapshot (BC-8731 / T7-Q).

Read-only synthesis helper invoked by `plugins/marketing/commands/portfolio-snapshot.md`
Phase 5. Builds the 5-section monthly (or 9-section quarterly) markdown packet
under `docs/campaigns/_reviews/` from:

  * Plugin filesystem (manifest.json + learnings.md + mmf-matrix.md +
    analysis-*.md + discoveries.json) — source of truth.
  * SF Campaign records (pre-fetched JSON, optional — passed via --sf-json).
  * Linear milestone data (pre-fetched JSON, optional — passed via --linear-json).

Inherits metric definitions from `campaign-analysis` §3.3 (b2b) and §4 (b2c)
verbatim — never redefines, never re-aggregates. Reads pre-aggregated
`learnings.md` Summary / What works / What doesn't sections produced by
`campaign-debrief` rather than walking the `## Campaign log` entries.

Anti-creep guards (load-bearing per V3 outcome doc item 6):

  1. The ONLY filesystem write this helper performs is the output file under
     `docs/campaigns/_reviews/`. Any path NOT under that subtree is refused
     with a non-zero exit. Defense in depth against operator-supplied --out
     arguments that bypass the markdown command's path construction.
  2. The helper reads — never modifies — every other artifact
     (manifest.json, learnings.md, mmf-matrix.md, analysis-*.md,
     discoveries.json, canonicals/*.yaml).
  3. No metric formulas live here. Section 2 sums pre-computed SF Campaign
     fields; Section 3 tallies pre-aggregated Summary stats; Section 4
     extracts verbatim bullets. The helper is dumb-aggregation by design.

Stdlib-only per `CLAUDE.md` § Conventions; no PyYAML / no jsonschema.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1

# ── Argument parsing ────────────────────────────────────────────────────


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="portfolio_snapshot.py",
        description="Section composer for /marketing:portfolio-snapshot (BC-8731 / T7-Q).",
    )
    p.add_argument("--span", required=True, choices=["monthly", "quarterly"])
    p.add_argument("--window-start", required=True, help="YYYY-MM-DD (inclusive)")
    p.add_argument("--window-end", required=True, help="YYYY-MM-DD (inclusive)")
    p.add_argument("--campaigns-dir", required=True, help="Path to docs/campaigns/ root")
    p.add_argument(
        "--canonicals-dir",
        required=True,
        help="Path to plugins/marketing/data/canonicals/ root",
    )
    p.add_argument(
        "--sf-json",
        default=None,
        help="Optional JSON file with pre-fetched SF Campaign records. Shape: {records: [...]}",
    )
    p.add_argument(
        "--sf-status",
        default="ok",
        choices=["ok", "degraded_auth", "degraded_query", "empty"],
        help="Status of the upstream SF fetch (passed in from the markdown command).",
    )
    p.add_argument(
        "--linear-json",
        default=None,
        help="Optional JSON file with pre-fetched Linear milestone data. Shape: {milestones: [...]}",
    )
    p.add_argument(
        "--linear-status",
        default="ok",
        choices=["ok", "degraded"],
        help="Status of the upstream Linear fetch (passed in from the markdown command).",
    )
    p.add_argument(
        "--command-version",
        default="marketing@unknown",
        help="Output frontmatter command_version field (e.g., marketing@0.6.0).",
    )
    p.add_argument("--out", required=True, help="Output markdown path under docs/campaigns/_reviews/")
    p.add_argument(
        "--generated-at",
        default=None,
        help="Override ISO-8601 UTC timestamp for frontmatter generated_at (deterministic tests).",
    )
    return p.parse_args(argv)


# ── Anti-creep path guard ───────────────────────────────────────────────


def assert_out_under_reviews(out_path: Path, campaigns_dir: Path) -> None:
    """Refuse any --out that isn't under <campaigns-dir>/_reviews/."""
    out_abs = out_path.resolve()
    reviews_dir = (campaigns_dir / "_reviews").resolve()
    try:
        out_abs.relative_to(reviews_dir)
    except ValueError:
        sys.stderr.write(
            f"ERROR: --out must be a path under {reviews_dir} (got {out_abs}). "
            "V3 outcome item 6 anti-creep guard.\n"
        )
        sys.exit(2)


# ── Date utilities ──────────────────────────────────────────────────────


def parse_iso_date(s: str) -> datetime:
    """Parse YYYY-MM-DD as a UTC date at midnight."""
    return datetime.strptime(s, "%Y-%m-%d").replace(tzinfo=timezone.utc)


def in_window(d: datetime, start: datetime, end: datetime) -> bool:
    """Inclusive on both ends (end is at 23:59:59Z)."""
    end_inclusive = end.replace(hour=23, minute=59, second=59)
    return start <= d <= end_inclusive


# ── Manifest discovery + filtering ──────────────────────────────────────


def slug_to_launch_month(slug: str) -> datetime | None:
    """Derive launch month from a `*-fy{YY}-m{MM}(-v{N})?` slug.

    Returns the first day of the launch month as UTC midnight, or None on
    pattern mismatch.
    """
    m = re.search(r"-fy(\d{2})-m(\d{2})(?:-v\d+)?$", slug)
    if not m:
        return None
    yy, mm = m.group(1), m.group(2)
    year = 2000 + int(yy)
    month = int(mm)
    if not (1 <= month <= 12):
        return None
    return datetime(year, month, 1, tzinfo=timezone.utc)


def load_manifests(campaigns_dir: Path) -> list[dict[str, Any]]:
    """Glob docs/campaigns/<short-entity>/<slug>/manifest.json and load each."""
    if not campaigns_dir.is_dir():
        sys.stderr.write(f"ERROR: campaigns directory not found: {campaigns_dir}\n")
        sys.exit(2)
    manifests = []
    for manifest_path in sorted(campaigns_dir.glob("*/*/manifest.json")):
        # Skip _reviews/ — it's the output dir, never contains a manifest.
        if "_reviews" in manifest_path.parts:
            continue
        try:
            data = json.loads(manifest_path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            sys.stderr.write(
                f"[BC-8731] Skipping unreadable manifest {manifest_path}: {exc}\n"
            )
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
    """Filter manifests to those whose created_at OR slug-derived launch month is in-window."""
    in_window_list = []
    for m in manifests:
        # Try created_at first (post-σ3 manifests have it).
        created_at = m.get("created_at")
        landed = False
        if created_at:
            try:
                # Parse ISO-8601 — strip 'Z' for fromisoformat compatibility.
                normalized = created_at.replace("Z", "+00:00")
                d = datetime.fromisoformat(normalized)
                if in_window(d, window_start, window_end):
                    in_window_list.append(m)
                    landed = True
            except ValueError:
                pass
        if landed:
            continue
        # Fallback: derive launch month from slug.
        slug = m.get("slug", "")
        launch_month = slug_to_launch_month(slug)
        if launch_month and in_window(launch_month, window_start, window_end):
            in_window_list.append(m)
    return in_window_list


# ── Canonicals + posture lookup ─────────────────────────────────────────


def load_canonicals_verticals(canonicals_dir: Path) -> list[str]:
    """Read plugins/marketing/data/canonicals/_manifest.yaml to enumerate verticals.

    Stdlib regex parse — matches `lint_canonicals.py` pattern (no PyYAML).
    """
    manifest_path = canonicals_dir / "_manifest.yaml"
    if not manifest_path.is_file():
        return []
    try:
        text = manifest_path.read_text()
    except OSError:
        return []
    verticals = []
    in_verticals = False
    for line in text.splitlines():
        if line.startswith("verticals:"):
            in_verticals = True
            continue
        if in_verticals:
            m = re.match(r"\s*-\s*([a-z0-9-]+)", line)
            if m:
                verticals.append(m.group(1))
            elif line.strip() and not line.startswith((" ", "\t", "-")):
                break
    return verticals


def lookup_posture(canonicals_dir: Path, vertical: str, offer: str) -> str | None:
    """Resolve offer posture from canonicals/<vertical>.yaml. Returns None if missing."""
    if not vertical or not offer:
        return None
    yaml_path = canonicals_dir / f"{vertical}.yaml"
    if not yaml_path.is_file():
        return None
    try:
        text = yaml_path.read_text()
    except OSError:
        return None
    # Find the offers: section, then the matching offer slug, then its posture: line.
    # Regex-based; stdlib only.
    in_offers = False
    current_offer_indent: int | None = None
    current_offer_slug: str | None = None
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("offers:"):
            in_offers = True
            continue
        if not in_offers:
            continue
        if stripped.startswith(("personas:", "discoveries:")) and not line.startswith(
            (" ", "\t")
        ):
            in_offers = False
            continue
        m = re.match(r"^(\s*)-\s*slug:\s*([a-z0-9-]+)", line)
        if m:
            current_offer_indent = len(m.group(1))
            current_offer_slug = m.group(2)
            continue
        if current_offer_slug == offer and current_offer_indent is not None:
            indent = len(line) - len(line.lstrip())
            if indent <= current_offer_indent:
                current_offer_slug = None
                continue
            mp = re.match(r"\s*posture:\s*([a-z0-9-]+)", line)
            if mp:
                return mp.group(1)
    return None


# ── learnings.md parsing ────────────────────────────────────────────────


def parse_learnings_summary(text: str) -> dict[str, Any]:
    """Extract the regenerated ## Summary stats counters + ## What works + ## What doesn't bullets.

    Returns:
      {
        "total_debriefs": int,
        "verdicts": {"SCALE": int, "ITERATE": int, "PAUSE": int, "KILL": int},
        "last_debrief": str | None,
        "what_works": [str, ...],   # bullets verbatim
        "what_doesnt": [str, ...],
      }
    """
    out = {
        "total_debriefs": 0,
        "verdicts": {"SCALE": 0, "ITERATE": 0, "PAUSE": 0, "KILL": 0},
        "last_debrief": None,
        "what_works": [],
        "what_doesnt": [],
    }
    # Total debriefs
    m = re.search(r"^-\s*Total debriefs:\s*(\d+)", text, re.MULTILINE)
    if m:
        out["total_debriefs"] = int(m.group(1))
    # Verdicts line — "Campaign verdicts: SCALE=1, ITERATE=2, PAUSE=0, KILL=1"
    m = re.search(
        r"Campaign verdicts:\s*SCALE=(\d+),\s*ITERATE=(\d+),\s*PAUSE=(\d+),\s*KILL=(\d+)",
        text,
    )
    if m:
        out["verdicts"] = {
            "SCALE": int(m.group(1)),
            "ITERATE": int(m.group(2)),
            "PAUSE": int(m.group(3)),
            "KILL": int(m.group(4)),
        }
    # Last debrief
    m = re.search(r"^-\s*Last debrief:\s*(\d{4}-\d{2}-\d{2})", text, re.MULTILINE)
    if m:
        out["last_debrief"] = m.group(1)
    # What works bullets — between "## What works" and the next "## " header
    out["what_works"] = _extract_section_bullets(text, "## What works")
    out["what_doesnt"] = _extract_section_bullets(text, "## What doesn't")
    return out


def _extract_section_bullets(text: str, header: str) -> list[str]:
    """Extract `- ...` bullets immediately after a `## <header>` line, stopping at the next ## header."""
    lines = text.splitlines()
    bullets = []
    in_section = False
    for line in lines:
        if line.strip() == header:
            in_section = True
            continue
        if not in_section:
            continue
        if line.startswith("## ") and line.strip() != header:
            break
        stripped = line.strip()
        # Accept literal bullet lines; skip italicized header lines + placeholders.
        if stripped.startswith("- ") and not stripped.startswith("- {"):
            bullets.append(stripped[2:])
    return bullets


# ── mmf-matrix.md parsing ───────────────────────────────────────────────


def parse_mmf_verdicts(text: str) -> list[str]:
    """Extract Verdict-column tokens from an mmf-matrix.md Results Log table.

    Returns a flat list — counts come from the caller via Counter().
    """
    verdicts = []
    in_results_log = False
    for line in text.splitlines():
        if re.match(r"^##\s+Results Log\b", line):
            in_results_log = True
            continue
        if not in_results_log:
            continue
        if line.startswith("## ") and not re.match(r"^##\s+Results Log\b", line):
            break
        # Table row: | ... | ... | VERDICT |
        if line.startswith("|") and not re.match(r"^\|[-: |]+$", line):
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) >= 2:
                last = cells[-1].upper()
                if last in {
                    "SUPER WORKS",
                    "KIND OF WORKS",
                    "DEFERRED",
                    "DOESN'T WORK",
                    "PENDING",
                }:
                    verdicts.append(last)
    return verdicts


# ── analysis-*.md parsing ───────────────────────────────────────────────


def parse_analysis_verdicts(text: str) -> list[str]:
    """Extract verdict tokens (TOP PERFORMER / SCALE / TEST MORE / MONITOR / UNDERPERFORM)
    from an analysis-*.md §2 Segment Performance Ranking table."""
    verdicts = []
    in_section = False
    valid = {"TOP PERFORMER", "SCALE", "TEST MORE", "MONITOR", "UNDERPERFORM"}
    for line in text.splitlines():
        if re.match(r"^##\s+2\.\s+Segment Performance Ranking\b", line):
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if not in_section:
            continue
        if line.startswith("|") and not re.match(r"^\|[-: |]+$", line):
            cells = [c.strip() for c in line.strip("|").split("|")]
            for cell in cells:
                token = cell.upper()
                if token in valid:
                    verdicts.append(token)
                    break
    return verdicts


def parse_analysis_actions(text: str) -> list[str]:
    """Extract action-tagged bullets from an analysis-*.md §6 Next Iteration block."""
    actions = []
    in_section = False
    pat = re.compile(r"\b(TODO:|ACTION:|FOLLOW-UP:|SCALE:|UNDERPERFORM:)")
    for line in text.splitlines():
        if re.match(r"^##\s+6\.\s+Next Iteration", line):
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if not in_section:
            continue
        stripped = line.strip()
        if stripped.startswith("- ") and pat.search(stripped):
            actions.append(stripped[2:])
    return actions


# ── discoveries.json reading ────────────────────────────────────────────


def load_discoveries(campaign_dir: Path) -> list[dict[str, Any]]:
    """Read sibling discoveries.json; return pending signals only."""
    path = campaign_dir / "discoveries.json"
    if not path.is_file():
        return []
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return []
    pending = []
    for signal in data.get("signals", []):
        if signal.get("promotion_status", "pending") == "pending":
            pending.append(signal)
    return pending


# ── SF + Linear JSON loading ────────────────────────────────────────────


def load_sf_json(path: str | None) -> list[dict[str, Any]]:
    if not path:
        return []
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"[BC-8731] Unreadable --sf-json at {path}: {exc}\n")
        return []
    return data.get("records", [])


def load_linear_json(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"[BC-8731] Unreadable --linear-json at {path}: {exc}\n")
        return {}
    milestones = data.get("milestones", [])
    return {m.get("slug", m.get("name", "")): m for m in milestones if isinstance(m, dict)}


# ── Section renderers ──────────────────────────────────────────────────


def render_section_1(
    manifests: list[dict[str, Any]],
    linear_by_slug: dict[str, Any],
    linear_status: str,
    canonicals_dir: Path,
) -> str:
    """Section 1 — Portfolio shape."""
    lines = ["## 1. Portfolio shape", ""]
    if not manifests:
        lines.append(
            "No campaigns in window. Verify with `ls docs/campaigns/<short-entity>/<slug>/manifest.json` "
            "and confirm the window range matches the slug's `fy{YY}-m{MM}` suffix."
        )
        lines.append("")
        return "\n".join(lines)

    lines.append("| Entity | Vertical | Persona | Offer | Posture | Status | Slug |")
    lines.append("|---|---|---|---|---|---|---|")
    for m in manifests:
        slug = m.get("slug", "(unknown)")
        entity = m.get("entity", "(unknown)")
        vertical = m.get("vertical", "(unknown)")
        persona = m.get("persona", "(unknown)")
        offer = m.get("offer", "(unknown)")
        posture = (
            m.get("offer_posture")
            or lookup_posture(canonicals_dir, vertical, offer)
            or "(unknown)"
        )
        # Linear status — look up by slug
        milestone = linear_by_slug.get(slug, {})
        status = milestone.get("status", "unknown") if linear_status == "ok" else "unknown"
        lines.append(
            f"| {entity} | {vertical} | {persona} | {offer} | {posture} | {status} | {slug} |"
        )

    # Totals
    entities = sorted({m.get("entity", "") for m in manifests if m.get("entity")})
    verticals = sorted({m.get("vertical", "") for m in manifests if m.get("vertical")})
    personas = sorted({m.get("persona", "") for m in manifests if m.get("persona")})
    offers = sorted({m.get("offer", "") for m in manifests if m.get("offer")})
    postures = sorted(
        {
            (
                m.get("offer_posture")
                or lookup_posture(canonicals_dir, m.get("vertical", ""), m.get("offer", ""))
                or "(unknown)"
            )
            for m in manifests
        }
    )
    lines.append("")
    lines.append(
        f"**Totals:** {len(manifests)} campaigns in window · {len(entities)} entities · "
        f"{len(verticals)} verticals · {len(personas)} personas · {len(offers)} offers · "
        f"{len(postures)} postures"
    )

    # Per-entity rollup
    entity_counts = {"labs": 0, "supply": 0, "nites": 0, "cross-entity": 0}
    for m in manifests:
        e = m.get("entity", "")
        if e in entity_counts:
            entity_counts[e] += 1
    lines.append("")
    lines.append(
        "**By entity:** "
        + " / ".join(f"{k} = {v}" for k, v in entity_counts.items())
    )

    # Per-vertical rollup (top N if many)
    vertical_counts: dict[str, int] = {}
    for m in manifests:
        v = m.get("vertical", "")
        if v:
            vertical_counts[v] = vertical_counts.get(v, 0) + 1
    vertical_rollup = " / ".join(
        f"{k} = {v}" for k, v in sorted(vertical_counts.items(), key=lambda kv: (-kv[1], kv[0]))
    )
    lines.append(f"**By vertical:** {vertical_rollup}")

    # Per-posture rollup
    posture_counts: dict[str, int] = {
        "free-asset": 0,
        "knowledge": 0,
        "pilot": 0,
        "risk-reversal": 0,
    }
    for m in manifests:
        p = m.get("offer_posture") or lookup_posture(
            canonicals_dir, m.get("vertical", ""), m.get("offer", "")
        )
        if p in posture_counts:
            posture_counts[p] += 1
    lines.append(
        "**By posture:** "
        + " / ".join(f"{k} = {v}" for k, v in posture_counts.items())
    )

    # Per-Linear-status rollup
    if linear_status == "ok":
        status_counts: dict[str, int] = {
            "planning": 0,
            "active": 0,
            "completed": 0,
            "killed": 0,
            "paused": 0,
        }
        for m in manifests:
            milestone = linear_by_slug.get(m.get("slug", ""), {})
            s = milestone.get("status", "").lower()
            if s in status_counts:
                status_counts[s] += 1
        lines.append(
            "**By Linear status:** "
            + " / ".join(f"{k} = {v}" for k, v in status_counts.items())
        )
    else:
        lines.append(
            "**By Linear status:** ⚠ Linear MCP degraded — sub-issue rollup unavailable. "
            "Re-run when Linear reachability returns."
        )

    lines.append("")
    return "\n".join(lines)


def render_section_2(
    manifests: list[dict[str, Any]],
    sf_records: list[dict[str, Any]],
    sf_status: str,
) -> str:
    """Section 2 — Pipeline summary."""
    lines = ["## 2. Pipeline summary", ""]
    if sf_status == "degraded_auth":
        lines.append(
            "> ⚠ SF rollup section degraded — auth probe failed at Phase 0. "
            "Run `sf org display --target-org <target> --json` manually to diagnose, then re-run. "
            "Filesystem + Linear sections below are unaffected."
        )
        lines.append("")
        return "\n".join(lines)
    if sf_status == "degraded_query":
        lines.append(
            "> ⚠ SF rollup section degraded — SOQL call failed at Phase 3. "
            "Filesystem + Linear sections below are unaffected."
        )
        lines.append("")
        return "\n".join(lines)

    # Build a lookup from slug → SF record (Campaign.Name matches the canonical slug)
    sf_by_slug = {r.get("Name", ""): r for r in sf_records}

    lines.append(
        "| Slug | SF Campaign | AmountAllOpportunities | AmountWonOpportunities | "
        "NumberOfLeads | EB campaign_id | Launched |"
    )
    lines.append("|---|---|---|---|---|---|---|")
    pipeline_total = 0.0
    won_total = 0.0
    leads_total = 0
    launched_count = 0
    any_sf = False
    for m in manifests:
        slug = m.get("slug", "(unknown)")
        sf = sf_by_slug.get(slug, {})
        sf_id = sf.get("Id") or "(absent)"
        amt_all = sf.get("AmountAllOpportunities")
        amt_won = sf.get("AmountWonOpportunities")
        leads = sf.get("NumberOfLeads")
        if sf:
            any_sf = True
        eb = m.get("email_bison") or {}
        eb_id = eb.get("campaign_id") or "(not launched)"
        launched_at = eb.get("launched_at")
        launched = "yes" if launched_at else "no"
        if launched_at:
            launched_count += 1
        if amt_all is not None:
            pipeline_total += float(amt_all)
        if amt_won is not None:
            won_total += float(amt_won)
        if leads is not None:
            leads_total += int(leads)
        lines.append(
            f"| {slug} | {sf_id} | "
            f"{('$' + format(amt_all, ',.0f')) if amt_all is not None else 'n/a'} | "
            f"{('$' + format(amt_won, ',.0f')) if amt_won is not None else 'n/a'} | "
            f"{leads if leads is not None else 'n/a'} | "
            f"{eb_id} | {launched} |"
        )

    if not manifests:
        lines.append("| (no in-window campaigns) | | | | | | |")

    lines.append("")
    lines.append("**Totals:**")
    if any_sf:
        lines.append(f"- pipeline_value (sum AmountAllOpportunities) = ${pipeline_total:,.0f}")
        lines.append(f"- won_revenue (sum AmountWonOpportunities) = ${won_total:,.0f}")
        lines.append(f"- leads_total (sum NumberOfLeads) = {leads_total:,}")
    else:
        lines.append(
            "- pipeline_value = unavailable (no in-window SF Campaigns matched the manifest slugs)"
        )
        lines.append("- won_revenue = unavailable")
        lines.append("- leads_total = unavailable")
    lines.append(f"- EB campaigns launched in window = {launched_count}")
    lines.append("")
    return "\n".join(lines)


def render_section_3(
    manifests: list[dict[str, Any]], campaigns_dir: Path
) -> str:
    """Section 3 — Verdict distribution (3 subsections)."""
    lines = ["## 3. Verdict distribution", ""]

    # 3a — Angle Verdict (manifest.angles[] or absent)
    lines.append("### 3a. Angle Verdict (from creative-angles outputs in window)")
    lines.append("")
    angle_counts: dict[str, int] = {
        "ALPHA": 0,
        "PROMISING": 0,
        "INTERESTING": 0,
        "COMMODITY": 0,
        "unscored": 0,
    }
    any_angles = False
    for m in manifests:
        angles = m.get("angles") or []
        if angles:
            any_angles = True
            for a in angles:
                token = (a.get("verdict") or "").upper()
                if token in angle_counts:
                    angle_counts[token] += 1
                else:
                    angle_counts["unscored"] += 1
    if not any_angles:
        lines.append(
            "Sub-issue #10 (Creative Angles) is the upstream surface; per-campaign angle scores "
            "live in `manifest.angles[]` when `/marketing:creative-angles` emits them. "
            "Window's angle scores not aggregated until that contract ships."
        )
    else:
        lines.append("Distribution: " + " / ".join(f"{k} = {v}" for k, v in angle_counts.items()))
    lines.append("")

    # 3b — Experiment Verdict (mmf-matrix.md Results Log)
    lines.append("### 3b. Experiment Verdict (from mmf-matrix.md Results Log)")
    lines.append("")
    mmf_counts: dict[str, int] = {
        "SUPER WORKS": 0,
        "KIND OF WORKS": 0,
        "DEFERRED": 0,
        "DOESN'T WORK": 0,
        "PENDING": 0,
    }
    any_mmf = False
    for m in manifests:
        campaign_dir = Path(m["__campaign_dir"])
        mmf_path = campaign_dir / "mmf-matrix.md"
        if not mmf_path.is_file():
            continue
        any_mmf = True
        try:
            verdicts = parse_mmf_verdicts(mmf_path.read_text())
        except OSError:
            continue
        for v in verdicts:
            if v in mmf_counts:
                mmf_counts[v] += 1
    if not any_mmf:
        lines.append(
            "No `mmf-matrix.md` present for any in-window campaign — MSPA experiments not yet batched."
        )
    else:
        lines.append(
            "Distribution: " + " / ".join(f"{k} = {v}" for k, v in mmf_counts.items())
        )
    lines.append("")

    # 3c — Campaign Verdict (learnings.md Summary stats)
    lines.append("### 3c. Campaign Verdict (from learnings.md Summary stats)")
    lines.append("")
    aggregate = {"SCALE": 0, "ITERATE": 0, "PAUSE": 0, "KILL": 0}
    debrief_total = 0
    entities_seen = set()
    for m in manifests:
        entity = m.get("entity", "")
        if not entity or entity in entities_seen:
            continue
        entities_seen.add(entity)
        learnings_path = campaigns_dir / entity / "learnings.md"
        if not learnings_path.is_file():
            continue
        try:
            summary = parse_learnings_summary(learnings_path.read_text())
        except OSError:
            continue
        for k in aggregate:
            aggregate[k] += summary["verdicts"].get(k, 0)
        debrief_total += summary["total_debriefs"]
    not_yet = max(0, len(manifests) - debrief_total)
    lines.append(
        "Distribution: "
        + " / ".join(f"{k} = {v}" for k, v in aggregate.items())
        + f" / not-yet-debriefed = {not_yet}"
    )
    lines.append("")
    return "\n".join(lines)


def render_section_4(
    manifests: list[dict[str, Any]], campaigns_dir: Path
) -> str:
    """Section 4 — Transferable insights (extracted verbatim from learnings.md)."""
    lines = [
        "## 4. Transferable insights",
        "",
        "Source: `learnings.md` \"What works\" + \"What doesn't\" sections across campaigns "
        "in window. Pre-aggregated by `campaign-debrief`; NOT re-aggregated here per BC-8731 "
        "anti-creep guard.",
        "",
    ]
    works: list[str] = []
    doesnt: list[str] = []
    entities_seen = set()
    for m in manifests:
        entity = m.get("entity", "")
        if not entity or entity in entities_seen:
            continue
        entities_seen.add(entity)
        learnings_path = campaigns_dir / entity / "learnings.md"
        if not learnings_path.is_file():
            continue
        try:
            summary = parse_learnings_summary(learnings_path.read_text())
        except OSError:
            continue
        works.extend(summary["what_works"])
        doesnt.extend(summary["what_doesnt"])

    if not works and not doesnt:
        lines.append(
            "No transferable insights available — no in-window campaigns have reached the "
            "campaign-debrief step (sub-issue #8) yet."
        )
        lines.append("")
        return "\n".join(lines)

    if works:
        lines.append("**What works (across debrief'd campaigns):**")
        lines.append("")
        for bullet in works:
            lines.append(f"- {bullet}")
        lines.append("")
    if doesnt:
        lines.append("**What doesn't (across debrief'd campaigns):**")
        lines.append("")
        for bullet in doesnt:
            lines.append(f"- {bullet}")
        lines.append("")
    return "\n".join(lines)


def render_section_5(
    manifests: list[dict[str, Any]],
) -> str:
    """Section 5 — Action items (discoveries.json + analysis-*.md flagged)."""
    lines = ["## 5. Action items", ""]
    # 5a — Pending discoveries.json signals
    lines.append("### 5a. Pending discoveries.json signals")
    lines.append("")
    any_disc = False
    for m in manifests:
        campaign_dir = Path(m["__campaign_dir"])
        slug = m.get("slug", "(unknown)")
        pending = load_discoveries(campaign_dir)
        if not pending:
            continue
        any_disc = True
        for sig in pending:
            category = sig.get("category", "unknown")
            emitted_by = sig.get("emitted_by_skill", "unknown")
            payload = sig.get("payload") or {}
            summary = (
                payload.get("observed_pattern")
                or payload.get("refinement_proposal")
                or payload.get("rationale")
                or payload.get("differs_from_existing")
                or "(no summary in payload)"
            )
            lines.append(
                f"- **{category}** ({slug}, emitted by `{emitted_by}`): {summary}"
            )
    if not any_disc:
        lines.append("(no pending signals across in-window campaigns)")
    lines.append("")

    # 5b — Operational follow-ups (analysis-*.md flagged)
    lines.append("### 5b. Operational follow-ups (from analysis-*.md flagged items)")
    lines.append("")
    any_action = False
    for m in manifests:
        campaign_dir = Path(m["__campaign_dir"])
        slug = m.get("slug", "(unknown)")
        for analysis_path in sorted(campaign_dir.glob("analysis-*.md")):
            try:
                text = analysis_path.read_text()
            except OSError:
                continue
            actions = parse_analysis_actions(text)
            for a in actions:
                any_action = True
                lines.append(f"- {a} ({slug} — `{analysis_path.name}`)")
    if not any_action:
        lines.append(
            "No `analysis-*.md` artifacts in window — `campaign-analysis` (BC-2721) has not "
            "run on any in-window campaign yet, OR no flagged action items in those that have run."
        )
    lines.append("")
    return "\n".join(lines)


def render_section_6(
    manifests: list[dict[str, Any]],
) -> str:
    """Section 6 — Cross-quarter MSPA transitions (quarterly-only)."""
    lines = ["## 6. Cross-quarter MSPA transitions", ""]
    # Naive implementation: scan mmf-matrix.md Results Log for verdict transitions.
    # Detection requires same experiment slug across two quarters with different verdicts.
    # T9-V hasn't shipped; this is a placeholder that surfaces structure when data exists.
    any_mmf = False
    for m in manifests:
        campaign_dir = Path(m["__campaign_dir"])
        mmf_path = campaign_dir / "mmf-matrix.md"
        if mmf_path.is_file():
            any_mmf = True
            break
    if not any_mmf:
        lines.append("No cross-quarter MSPA transitions detected in window.")
        lines.append("")
        return "\n".join(lines)
    lines.append(
        "MSPA matrix detection placeholder — per-experiment cross-quarter transition logic "
        "ships with T9-V (offer-versioning + MSPA cross-quarter walker). Until then, this "
        "section reports presence/absence of mmf-matrix.md artifacts only."
    )
    lines.append("")
    lines.append(f"In-window campaigns with `mmf-matrix.md`: {any_mmf and 'at least one' or 'none'}")
    lines.append("")
    return "\n".join(lines)


def render_section_7(
    manifests: list[dict[str, Any]], campaigns_dir: Path
) -> str:
    """Section 7 — Cumulative transferables (quarterly-only)."""
    lines = ["## 7. Cumulative transferables", ""]
    works_counter: dict[str, int] = {}
    doesnt_counter: dict[str, int] = {}
    entities_seen = set()
    for m in manifests:
        entity = m.get("entity", "")
        if not entity or entity in entities_seen:
            continue
        entities_seen.add(entity)
        learnings_path = campaigns_dir / entity / "learnings.md"
        if not learnings_path.is_file():
            continue
        try:
            summary = parse_learnings_summary(learnings_path.read_text())
        except OSError:
            continue
        for bullet in summary["what_works"]:
            works_counter[bullet] = works_counter.get(bullet, 0) + 1
        for bullet in summary["what_doesnt"]:
            doesnt_counter[bullet] = doesnt_counter.get(bullet, 0) + 1
    if not works_counter and not doesnt_counter:
        lines.append("No cumulative transferables available — see Section 4.")
        lines.append("")
        return "\n".join(lines)
    if works_counter:
        lines.append("**Cumulative What works:**")
        lines.append("")
        for bullet, n in sorted(works_counter.items(), key=lambda kv: (-kv[1], kv[0])):
            suffix = f" (appeared in {n} entities)" if n > 1 else ""
            lines.append(f"- {bullet}{suffix}")
        lines.append("")
    if doesnt_counter:
        lines.append("**Cumulative What doesn't:**")
        lines.append("")
        for bullet, n in sorted(doesnt_counter.items(), key=lambda kv: (-kv[1], kv[0])):
            suffix = f" (appeared in {n} entities)" if n > 1 else ""
            lines.append(f"- {bullet}{suffix}")
        lines.append("")
    return "\n".join(lines)


def render_section_8(
    manifests: list[dict[str, Any]], sf_records: list[dict[str, Any]]
) -> str:
    """Section 8 — Per-offer-version aggregation (quarterly-only)."""
    lines = ["## 8. Per-offer-version aggregation", ""]
    sf_by_slug = {r.get("Name", ""): r for r in sf_records}
    # Group manifests by {vertical}/{persona}/{offer}; derive version from slug suffix.
    groups: dict[tuple[str, str, str], list[tuple[int, dict]]] = {}
    any_version = False
    for m in manifests:
        slug = m.get("slug", "")
        vertical = m.get("vertical", "")
        persona = m.get("persona", "")
        offer = m.get("offer", "")
        vm = re.search(r"-v(\d+)$", slug)
        version = int(vm.group(1)) if vm else 1
        if vm:
            any_version = True
        groups.setdefault((vertical, persona, offer), []).append((version, m))
    if not any_version:
        lines.append(
            "No offer-version aggregation available — no in-window slug uses the `-v{N}` "
            "suffix convention. T9-V (offer-versioning) has not yet shipped, or no campaign "
            "has needed a v2+ iteration in window."
        )
        lines.append("")
        return "\n".join(lines)
    lines.append("| Vertical | Persona | Offer | Version | AmountAll | AmountWon | Leads |")
    lines.append("|---|---|---|---|---|---|---|")
    for (v, p, o), entries in sorted(groups.items()):
        for version, m in sorted(entries, key=lambda kv: kv[0]):
            sf = sf_by_slug.get(m.get("slug", ""), {})
            amt_all = sf.get("AmountAllOpportunities")
            amt_won = sf.get("AmountWonOpportunities")
            leads = sf.get("NumberOfLeads")
            lines.append(
                f"| {v} | {p} | {o} | v{version} | "
                f"{('$' + format(amt_all, ',.0f')) if amt_all is not None else 'n/a'} | "
                f"{('$' + format(amt_won, ',.0f')) if amt_won is not None else 'n/a'} | "
                f"{leads if leads is not None else 'n/a'} |"
            )
    lines.append("")
    return "\n".join(lines)


def render_section_9(
    manifests: list[dict[str, Any]], canonicals_dir: Path
) -> str:
    """Section 9 — Coverage-gap callouts (quarterly-only)."""
    lines = ["## 9. Coverage-gap callouts", ""]
    canonical_verticals = load_canonicals_verticals(canonicals_dir)
    if not canonical_verticals:
        lines.append(
            "Canonical verticals manifest not found at "
            "`plugins/marketing/data/canonicals/_manifest.yaml` — coverage-gap section "
            "cannot enumerate. Run `python3 plugins/marketing/scripts/lint_canonicals.py` "
            "to diagnose."
        )
        lines.append("")
        return "\n".join(lines)
    in_window_verticals = {m.get("vertical", "") for m in manifests}
    gaps = sorted(v for v in canonical_verticals if v not in in_window_verticals)
    total = len(canonical_verticals)
    lines.append(
        f"Source: `plugins/marketing/data/canonicals/_manifest.yaml` enumerates {total} canonical "
        "verticals; this section flags verticals with zero in-window campaigns."
    )
    lines.append("")
    lines.append(f"**Verticals with 0 in-window campaigns:** {len(gaps)} of {total}")
    lines.append("")
    if gaps:
        for v in gaps:
            lines.append(f"- {v}")
    else:
        lines.append("(zero gaps — every canonical vertical has at least one in-window campaign)")
    lines.append("")
    return "\n".join(lines)


# ── Top-level packet renderer ──────────────────────────────────────────


def render_packet(
    args: argparse.Namespace,
    manifests: list[dict[str, Any]],
    sf_records: list[dict[str, Any]],
    linear_by_slug: dict[str, Any],
    canonicals_dir: Path,
    campaigns_dir: Path,
) -> str:
    """Render the full markdown packet."""
    generated_at = (
        args.generated_at
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    )
    window_label = (
        f"{args.window_start[:7]}"
        if args.span == "monthly"
        else f"{args.window_start[:4]}-Q{((int(args.window_start[5:7]) - 1) // 3) + 1}"
    )
    sources_filesystem = "ok"

    frontmatter = [
        "---",
        f"schema_version: {SCHEMA_VERSION}",
        f"generated_at: {generated_at}",
        "window:",
        f"  start: {args.window_start}",
        f"  end: {args.window_end}",
        f"  span: {args.span}",
        f"command_version: {args.command_version}",
        "sources:",
        f"  sf: {args.sf_status}",
        f"  linear: {args.linear_status}",
        f"  filesystem: {sources_filesystem}",
        "---",
        "",
        f"# Portfolio Snapshot — {args.window_start} → {args.window_end} ({window_label})",
        "",
    ]

    sections = [
        render_section_1(manifests, linear_by_slug, args.linear_status, canonicals_dir),
        render_section_2(manifests, sf_records, args.sf_status),
        render_section_3(manifests, campaigns_dir),
        render_section_4(manifests, campaigns_dir),
        render_section_5(manifests),
    ]
    if args.span == "quarterly":
        sections.extend(
            [
                render_section_6(manifests),
                render_section_7(manifests, campaigns_dir),
                render_section_8(manifests, sf_records),
                render_section_9(manifests, canonicals_dir),
            ]
        )

    return "\n".join(frontmatter) + "\n".join(sections) + "\n---\n\nEnd of packet.\n"


# ── Main ───────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    campaigns_dir = Path(args.campaigns_dir).resolve()
    canonicals_dir = Path(args.canonicals_dir).resolve()
    out_path = Path(args.out).resolve()

    # Anti-creep guard 1: refuse out paths outside <campaigns-dir>/_reviews/.
    assert_out_under_reviews(out_path, campaigns_dir)

    # Window parsing
    try:
        window_start = parse_iso_date(args.window_start)
        window_end = parse_iso_date(args.window_end)
    except ValueError as exc:
        sys.stderr.write(f"ERROR: invalid window date: {exc}\n")
        return 2
    if window_end < window_start:
        sys.stderr.write("ERROR: --window-end must be >= --window-start\n")
        return 2

    # Data load
    all_manifests = load_manifests(campaigns_dir)
    in_window_manifests = filter_in_window(all_manifests, window_start, window_end)

    sf_records = load_sf_json(args.sf_json)
    linear_by_slug = load_linear_json(args.linear_json)

    # Render
    body = render_packet(
        args,
        in_window_manifests,
        sf_records,
        linear_by_slug,
        canonicals_dir,
        campaigns_dir,
    )

    # Ensure parent directory exists; the path was already guard-checked.
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(body)

    rel_out = out_path
    try:
        rel_out = out_path.relative_to(Path.cwd())
    except ValueError:
        pass
    sys.stdout.write(
        f"OK: portfolio-snapshot written → {rel_out}\n"
        f"    window: {args.window_start} → {args.window_end} ({args.span})\n"
        f"    sources: sf={args.sf_status}, linear={args.linear_status}, "
        f"filesystem={'ok'}\n"
        f"    campaigns_in_window: {len(in_window_manifests)}\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
