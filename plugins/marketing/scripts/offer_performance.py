#!/usr/bin/env python3
"""Section composer for /marketing:offer-performance (BC-8728 / T9-V).

Per-offer-version performance synthesis. Reads manifest.json glob + pre-fetched
EB campaign stats + pre-fetched SF Campaign data; emits one
`docs/campaigns/{entity}/offers/{slug}/{version}/performance.md` per
offer-version. Feeds back into mmf ITERATE Step 3.6.

Inherits metric definitions from `campaign-analysis` §3.3 per
handbook/marketing/frameworks/vocabulary.md Section 5. See
docs/v3-ratification-outcome-2026-05-22.md for anti-creep guards ratified at V3.

Anti-creep guards (mirror BC-8731 load-bearing pattern):

  1. Read-only on canonicals, manifest, learnings.md, mmf-matrix.md.
  2. No new metric definitions — inherit from campaign-analysis §3.3.
  3. No automated retirement decisions — flag candidates only.
  4. Writes ONLY to docs/campaigns/{entity}/offers/{slug}/{version}/performance.md.
  5. No cross-tenant rollup (single-tenant per ADR-014).

Stdlib-only per `CLAUDE.md` § Conventions; no PyYAML / no jsonschema.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _shared import canonicals_reader, manifest_loader, slug_parts

SCHEMA_VERSION = 1
DEFAULT_DEGRADATION_THRESHOLD = 2


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="offer_performance.py",
        description="Per-offer-version performance synthesis (BC-8728 / T9-V).",
    )
    p.add_argument("--offer-slug", required=True, help="Offer slug to analyze")
    p.add_argument(
        "--version",
        default=None,
        type=int,
        help="Specific version to analyze (default: all versions)",
    )
    p.add_argument(
        "--entity",
        default=None,
        help="Entity short slug (auto-detect from canonicals if absent)",
    )
    p.add_argument("--campaigns-dir", required=True, help="Path to docs/campaigns/ root")
    p.add_argument(
        "--canonicals-dir",
        required=True,
        help="Path to plugins/marketing/data/canonicals/ root",
    )
    p.add_argument(
        "--eb-json",
        default=None,
        help="Optional JSON file with pre-fetched EB campaign stats. Shape: {campaigns: [{slug, stats}]}",
    )
    p.add_argument(
        "--eb-status",
        default="ok",
        choices=["ok", "degraded"],
        help="Status of the upstream EB fetch.",
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
        help="Status of the upstream SF fetch.",
    )
    p.add_argument(
        "--command-version",
        default="marketing@unknown",
        help="Output frontmatter command_version field.",
    )
    p.add_argument(
        "--generated-at",
        default=None,
        help="Override ISO-8601 UTC timestamp for frontmatter (deterministic tests).",
    )
    p.add_argument(
        "--degradation-threshold",
        default=DEFAULT_DEGRADATION_THRESHOLD,
        type=int,
        help="Consecutive degrading versions to flag retirement candidate (default: 2).",
    )
    return p.parse_args(argv)


# ── Anti-creep path guard ───────────────────────────────────────────────


def assert_out_under_offers(out_path: Path, campaigns_dir: Path) -> None:
    """Refuse any output path that isn't under <campaigns-dir>/<entity>/offers/."""
    out_abs = out_path.resolve()
    campaigns_abs = campaigns_dir.resolve()
    try:
        rel = out_abs.relative_to(campaigns_abs)
    except ValueError:
        sys.stderr.write(
            f"ERROR: output must be under {campaigns_abs} (got {out_abs}). "
            "V3 anti-creep guard.\n"
        )
        sys.exit(2)
    parts = rel.parts
    if len(parts) < 3 or parts[1] != "offers":
        sys.stderr.write(
            f"ERROR: output must be under <campaigns>/<entity>/offers/ "
            f"(got {out_abs}). V3 anti-creep guard.\n"
        )
        sys.exit(2)


# ── Data loading ────────────────────────────────────────────────────────


def load_eb_json(path: str | None) -> dict[str, Any]:
    """Load pre-fetched EB campaign stats. Returns {slug: stats_dict}."""
    if not path:
        return {}
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"[BC-8728] Unreadable --eb-json at {path}: {exc}\n")
        return {}
    result: dict[str, Any] = {}
    for c in data.get("campaigns", []):
        if isinstance(c, dict) and "slug" in c:
            result[c["slug"]] = c.get("stats", {})
    return result


def load_sf_json(path: str | None) -> dict[str, Any]:
    """Load pre-fetched SF Campaign records keyed by Name (slug)."""
    if not path:
        return {}
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"[BC-8728] Unreadable --sf-json at {path}: {exc}\n")
        return {}
    return {r.get("Name", ""): r for r in data.get("records", []) if isinstance(r, dict)}


# ── Metric extraction ──────────────────────────────────────────────────


def _earliest_iso(values: list[str]) -> str | None:
    """Return the chronologically earliest ISO-8601 string, preserving its
    original display form.

    `launched_at` legitimately spans date-only, fractional-second, `Z`, and
    numeric-offset (`±HH:MM`) forms (see the sibling contract guard
    `import_campaign.CREATED_AT_RE`). Plain `min()` over raw strings orders
    lexicographically, which diverges from chronological order across offset
    zones (e.g. `...10:00:00+05:00` is 05:00Z, earlier than `...06:00:00Z`).
    Parse to an instant before comparing; naive values (date-only) are treated
    as UTC so naive/aware never mix in the comparison. Unparseable input falls
    back to lexicographic min (never raises).
    """
    def instant(s: str):
        try:
            dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        except (ValueError, AttributeError, TypeError):
            return None
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)

    parseable = [(s, instant(s)) for s in values]
    parseable = [(s, k) for s, k in parseable if k is not None]
    if parseable:
        return min(parseable, key=lambda pair: pair[1])[0]
    # No parseable instant — lexicographic fallback over STRING values only, so a
    # malformed manifest carrying a non-string launched_at can't raise TypeError
    # (honors the never-raises contract). Returns None when nothing usable remains.
    strings = [v for v in values if isinstance(v, str)]
    return min(strings) if strings else None


def eb_fields_from_manifest(manifest_eb: dict[str, Any]) -> tuple[Any, Any]:
    """Return ``(eb_campaign_id, launched_at)`` from a manifest's email_bison block.

    Schema-v2-aware (BC-11852 / BC-12593): when ``email_bison.campaigns[]`` is a
    non-empty list, ``eb_campaign_id`` is the FIRST record's id (mirrors
    ``portfolio_snapshot.eb_render_fields``) and ``launched_at`` is the EARLIEST
    non-null ``campaigns[].launched_at`` — the campaign's first-live date, matching
    ``/marketing:import-campaign``'s ``created_at`` derivation. (ISO-8601 strings
    sort chronologically under ``min``.) Falls back to the v1 singular
    ``email_bison.campaign_id`` / ``.launched_at`` when no ``campaigns[]`` array is
    present, so existing v1 manifests behave exactly as before. An empty/unlaunched
    v2 block yields ``(None, None)``.
    """
    eb = manifest_eb or {}
    campaigns = eb.get("campaigns")
    if isinstance(campaigns, list) and campaigns:
        first = campaigns[0] if isinstance(campaigns[0], dict) else {}
        campaign_id = first.get("campaign_id")
        launched_dates = [
            la
            for c in campaigns
            if isinstance(c, dict) and (la := c.get("launched_at"))
        ]
        launched_at = _earliest_iso(launched_dates)
        return campaign_id, launched_at
    # v1 fallback — singular fields (unchanged behavior for legacy manifests).
    return eb.get("campaign_id"), eb.get("launched_at")


def extract_version_metrics(
    manifests: list[dict[str, Any]],
    eb_by_slug: dict[str, Any],
    sf_by_slug: dict[str, Any],
) -> list[dict[str, Any]]:
    """Build a sorted list of per-version metric dicts."""
    versions: list[dict[str, Any]] = []
    for m in manifests:
        slug = m.get("slug", "")
        version = slug_parts.slug_version(slug)
        sf = sf_by_slug.get(slug, {})
        eb = eb_by_slug.get(slug, {})
        manifest_eb = m.get("email_bison") or {}
        # Schema-v1/v2-aware read (BC-12593): v2 manifests carry
        # email_bison.campaigns[] instead of the singular campaign_id/launched_at.
        manifest_campaign_id, manifest_launched_at = eb_fields_from_manifest(manifest_eb)

        metrics: dict[str, Any] = {
            "version": version,
            "slug": slug,
            "entity": m.get("entity", ""),
            "vertical": m.get("vertical", ""),
            "persona": m.get("persona", ""),
            "sf_amount_all": sf.get("AmountAllOpportunities"),
            "sf_amount_won": sf.get("AmountWonOpportunities"),
            "sf_leads": sf.get("NumberOfLeads"),
            "eb_reply_rate": eb.get("reply_rate"),
            "eb_meeting_rate": eb.get("meeting_rate"),
            "eb_total_sent": eb.get("total_sent"),
            "eb_total_replies": eb.get("total_replies"),
            "eb_campaign_id": manifest_campaign_id or eb.get("campaign_id"),
            "launched_at": manifest_launched_at,
        }
        versions.append(metrics)
    versions.sort(key=lambda x: x["version"])
    return versions


def detect_retirement_candidate(
    versions: list[dict[str, Any]], threshold: int
) -> dict[str, Any] | None:
    """Flag if N consecutive versions show degrading reply rates.

    Returns a dict with the degradation details if triggered, else None.
    """
    if len(versions) < 2:
        return None
    consecutive_degrading = 0
    for i in range(1, len(versions)):
        prev_rate = versions[i - 1].get("eb_reply_rate")
        curr_rate = versions[i].get("eb_reply_rate")
        if prev_rate is not None and curr_rate is not None:
            if curr_rate < prev_rate:
                consecutive_degrading += 1
            else:
                consecutive_degrading = 0
        else:
            consecutive_degrading = 0
    if consecutive_degrading >= threshold:
        return {
            "consecutive_degrading": consecutive_degrading,
            "threshold": threshold,
            "latest_version": versions[-1]["version"],
            "latest_reply_rate": versions[-1].get("eb_reply_rate"),
        }
    return None


# ── Cell formatters ────────────────────────────────────────────────────


def fmt_money(value: float | int | None) -> str:
    if value is None:
        return "n/a"
    return f"${value:,.0f}"


def fmt_pct(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"{value:.1f}%"


def fmt_int(value: int | None) -> str:
    if value is None:
        return "n/a"
    return str(value)


# ── Rendering ──────────────────────────────────────────────────────────


def render_performance(
    args: argparse.Namespace,
    offer_slug: str,
    entity: str,
    vertical: str,
    posture: str | None,
    versions: list[dict[str, Any]],
    eb_status: str,
    sf_status: str,
    retirement: dict[str, Any] | None,
) -> str:
    """Render the full performance markdown."""
    generated_at = (
        args.generated_at
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    )

    lines = [
        "---",
        f"schema_version: {SCHEMA_VERSION}",
        f"generated_at: {generated_at}",
        f"command_version: {args.command_version}",
        f"offer_slug: {offer_slug}",
        f"entity: {entity}",
        f"vertical: {vertical}",
        f"posture: {posture or 'unknown'}",
        f"versions_analyzed: {len(versions)}",
        "---",
        "",
        f"# Offer Performance — {offer_slug}",
        "",
        f"**Entity:** {entity} | **Vertical:** {vertical} | **Posture:** {posture or 'unknown'}",
        "",
    ]

    # Degradation banners
    if eb_status == "degraded":
        lines.append(
            "> ⚠ EB stats degraded — reply/meeting rates unavailable. "
            "SF pipeline data (if available) still shown below."
        )
        lines.append("")
    if sf_status in ("degraded_auth", "degraded_query"):
        lines.append(
            "> ⚠ SF rollup degraded — pipeline contribution unavailable. "
            "EB engagement data (if available) still shown below."
        )
        lines.append("")

    # Section 1: Per-version metrics table
    lines.append("## 1. Per-version metrics")
    lines.append("")
    lines.append(
        "| Version | Slug | Reply Rate | Meeting Rate | Sent | Replies "
        "| AmountAll | AmountWon | Leads | Launched |"
    )
    lines.append("|---|---|---|---|---|---|---|---|---|---|")
    for v in versions:
        lines.append(
            f"| v{v['version']} | {v['slug']} | {fmt_pct(v['eb_reply_rate'])} "
            f"| {fmt_pct(v['eb_meeting_rate'])} | {fmt_int(v['eb_total_sent'])} "
            f"| {fmt_int(v['eb_total_replies'])} | {fmt_money(v['sf_amount_all'])} "
            f"| {fmt_money(v['sf_amount_won'])} | {fmt_int(v['sf_leads'])} "
            f"| {v.get('launched_at') or 'n/a'} |"
        )
    lines.append("")

    # Section 2: Cross-version comparison
    if len(versions) >= 2:
        lines.append("## 2. Cross-version comparison")
        lines.append("")
        latest = versions[-1]
        previous = versions[-2]
        lines.append(f"**Latest (v{latest['version']}) vs Previous (v{previous['version']}):**")
        lines.append("")
        for metric, label, formatter in [
            ("eb_reply_rate", "Reply rate", fmt_pct),
            ("eb_meeting_rate", "Meeting rate", fmt_pct),
            ("sf_amount_all", "Pipeline (AmountAll)", fmt_money),
            ("sf_amount_won", "Won revenue (AmountWon)", fmt_money),
            ("sf_leads", "Leads", fmt_int),
        ]:
            prev_val = previous.get(metric)
            curr_val = latest.get(metric)
            if prev_val is not None and curr_val is not None:
                if isinstance(prev_val, (int, float)) and isinstance(curr_val, (int, float)):
                    diff = curr_val - prev_val
                    direction = "↑" if diff > 0 else "↓" if diff < 0 else "→"
                    lines.append(
                        f"- {label}: {formatter(prev_val)} → {formatter(curr_val)} ({direction})"
                    )
                else:
                    lines.append(f"- {label}: {formatter(prev_val)} → {formatter(curr_val)}")
            else:
                lines.append(f"- {label}: {formatter(prev_val)} → {formatter(curr_val)}")
        lines.append("")

    # Section 3: Pipeline contribution
    lines.append("## 3. Pipeline contribution")
    lines.append("")
    total_all = sum(
        v["sf_amount_all"] for v in versions
        if v.get("sf_amount_all") is not None
    )
    total_won = sum(
        v["sf_amount_won"] for v in versions
        if v.get("sf_amount_won") is not None
    )
    has_sf = any(v.get("sf_amount_all") is not None for v in versions)
    if has_sf:
        lines.append(f"- **Total pipeline (sum AmountAllOpportunities):** {fmt_money(total_all)}")
        lines.append(f"- **Total won (sum AmountWonOpportunities):** {fmt_money(total_won)}")
    else:
        lines.append("- Pipeline data unavailable (no SF Campaign records matched).")
    lines.append("")

    # Section 4: Retirement candidate flag
    lines.append("## 4. Retirement signal")
    lines.append("")
    if retirement:
        lines.append(
            f"⚠ **RETIREMENT CANDIDATE** — {retirement['consecutive_degrading']} "
            f"consecutive versions show declining reply rates "
            f"(threshold: {retirement['threshold']}). "
            f"Latest v{retirement['latest_version']} reply rate: "
            f"{fmt_pct(retirement['latest_reply_rate'])}."
        )
        lines.append("")
        lines.append(
            "This is a FLAG, not an automated decision. Operator reviews via "
            "`discoveries.json` offer-retirement signal (BC-8722 schema)."
        )
    else:
        lines.append("No retirement signal. Offer performance within acceptable range.")
    lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("End of performance report.")
    lines.append("")
    return "\n".join(lines)


# ── Main ───────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    campaigns_dir = Path(args.campaigns_dir).resolve()
    canonicals_dir = Path(args.canonicals_dir).resolve()
    offer_slug = args.offer_slug

    # Validate offer slug exists in canonicals (searches all verticals)
    valid, msg = canonicals_reader.validate_canonical_ref(
        canonicals_dir, "", offer_slug
    )
    if not valid:
        sys.stderr.write(f"ERROR: {msg}\n")
        return 1

    # Resolve vertical + posture from canonicals
    vertical = canonicals_reader.find_offer_vertical(canonicals_dir, offer_slug) or ""
    posture = (
        canonicals_reader.lookup_offer_posture(canonicals_dir, vertical, offer_slug)
        if vertical else None
    )

    # Auto-detect entity if not provided
    entity = args.entity
    if not entity:
        manifests = manifest_loader.glob_manifests_by_offer(campaigns_dir, offer_slug)
        if manifests:
            entity = manifests[0].get("entity", "")
        if not entity:
            entity = "labs"

    # Glob manifests for this offer
    matching = manifest_loader.glob_manifests_by_offer(campaigns_dir, offer_slug)
    if args.version is not None:
        matching = [
            m for m in matching
            if slug_parts.slug_version(m.get("slug", "")) == args.version
        ]

    if not matching:
        sys.stdout.write(
            f"OK: no campaigns found for offer '{offer_slug}'"
            + (f" version v{args.version}" if args.version else "")
            + f" in {campaigns_dir}. Graceful empty — no output written.\n"
        )
        return 0

    # Load external data
    eb_by_slug = load_eb_json(args.eb_json)
    sf_by_slug = load_sf_json(args.sf_json)

    # Build per-version metrics
    versions = extract_version_metrics(matching, eb_by_slug, sf_by_slug)

    # Detect retirement candidate
    retirement = detect_retirement_candidate(versions, args.degradation_threshold)

    # Determine output paths — one file per version
    written = 0
    for v in versions:
        ver = v["version"]
        out_path = campaigns_dir / entity / "offers" / offer_slug / f"v{ver}" / "performance.md"
        assert_out_under_offers(out_path, campaigns_dir)
        out_path.parent.mkdir(parents=True, exist_ok=True)

        body = render_performance(
            args,
            offer_slug,
            entity,
            vertical,
            posture,
            [v],
            args.eb_status,
            args.sf_status,
            None,
        )
        out_path.write_text(body)
        written += 1

    # Also write a cross-version summary if multiple versions
    if len(versions) > 1:
        summary_path = campaigns_dir / entity / "offers" / offer_slug / "performance.md"
        assert_out_under_offers(summary_path, campaigns_dir)
        summary_path.parent.mkdir(parents=True, exist_ok=True)

        body = render_performance(
            args,
            offer_slug,
            entity,
            vertical,
            posture,
            versions,
            args.eb_status,
            args.sf_status,
            retirement,
        )
        summary_path.write_text(body)
        written += 1

    rel_base = campaigns_dir / entity / "offers" / offer_slug
    try:
        rel_base = rel_base.relative_to(Path.cwd())
    except ValueError:
        pass
    sys.stdout.write(
        f"OK: offer-performance written → {rel_base}/\n"
        f"    offer: {offer_slug} (entity={entity}, vertical={vertical}, "
        f"posture={posture or 'unknown'})\n"
        f"    versions: {len(versions)}\n"
        f"    files_written: {written}\n"
        f"    sources: sf={args.sf_status}, eb={args.eb_status}\n"
        f"    retirement_signal: {'YES' if retirement else 'no'}\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
