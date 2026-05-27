#!/usr/bin/env python3
"""Build docs/reconciliation/master-index.{md,json} from snapshot files.

Stdlib-only. Reads three snapshots committed under docs/reconciliation/_sources/:
  - linear-milestones.json (Brite GTM project — list_milestones output)
  - eb-b2b-campaigns.csv (b2b workspace — list_campaigns paginated rollup)
  - eb-personal-campaigns.csv (personal workspace — list_campaigns paginated rollup)

Emits docs/reconciliation/master-index.{md,json} — one row per LOGICAL campaign,
where a logical campaign = (fy, month, vertical_raw, offer_raw). ESP suffix
(Microsoft / Google / SMTP) and audience-tier suffix (Professional Emails /
Role Emails / Personal Emails / Managers+ / etc.) are stripped to derive the
logical key; the EB-record fan-out is preserved as eb_campaign_ids[] +
audience_tiers[] per row.

Re-run after refreshing snapshots from MCP. Snapshots themselves are
intentionally committed (audit trail + reproducibility); refresh via:
  - list_milestones for the Brite GTM project (UUID 5e25e522-...)
  - mcp__emailbison-b2b__list_campaigns (paginate to exhaustion)
  - mcp__emailbison-personal__list_campaigns (paginate to exhaustion)
"""

from __future__ import annotations

import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
SRC = REPO_ROOT / "docs" / "reconciliation" / "_sources"
OUT_MD = REPO_ROOT / "docs" / "reconciliation" / "master-index.md"
OUT_JSON = REPO_ROOT / "docs" / "reconciliation" / "master-index.json"
CANONICALS_DIR = REPO_ROOT / "plugins" / "marketing" / "data" / "canonicals"

GTM_PROJECT_ID = "5e25e522-0700-4f0f-86a2-bdff965126f5"
GTM_PROJECT_NAME = "Brite GTM"

ESP_TOKENS = {"microsoft", "google", "smtp"}
SUFFIX_ALL_ESPS = "all esps"


def is_audience_tier_token(token: str) -> bool:
    """A token belongs to the trailing audience-tier suffix run.

    Matches: any *-emails (professional/role/personal/general), managers+ and
    variants (with parentheticals), employees, owners/gms variants, and the
    historic `direct question offer` copy-modifier that always trailed an
    audience-tier suffix.
    """
    t = token.strip().lower()
    if not t:
        return False
    if t == SUFFIX_ALL_ESPS:
        return True
    if "emails" in t:
        return True
    if t == "employees":
        return True
    if t.startswith("managers+"):
        return True
    if "owners" in t and "gms" in t:
        return True
    if t == "direct question offer":
        return True
    return False


def load_canonical_verticals() -> dict[str, str]:
    """Return {display_lower: slug} for every canonical vertical."""
    out: dict[str, str] = {}
    for path in sorted(CANONICALS_DIR.glob("*.yaml")):
        if path.name.startswith("_"):
            continue
        slug = path.stem
        display_match = re.search(r'^display:\s*"?([^"\n]+)"?', path.read_text(), re.M)
        if display_match:
            out[display_match.group(1).strip().lower()] = slug
        out[slug.replace("-", " ")] = slug
    return out


# ---------------- name parsing ----------------

def normalize_name(raw: str) -> str:
    return raw.strip().rstrip(" |").strip()


def parse_eb_name(raw_name: str) -> dict[str, Any]:
    """Decompose an EB campaign name into structured fields.

    EB names use ` | `-separated tokens with three common shapes:
      (1) `<ESP> | FY?? M?? | <vertical> | <offer> | <audience-tier>`
      (2) `FY?? M?? | <vertical> | <audience-tier> | All ESPs`
      (3) `FY?? M?? | <vertical> | <offer/audience> | All ESPs`

    Returns a dict with: esp, fy, month, vertical_raw, offer_raw,
    audience_tier_raw, logical_key, parse_quality.
    """
    name = normalize_name(raw_name)
    tokens = [t.strip() for t in name.split("|")]

    esp = None
    if tokens and tokens[0].lower() in ESP_TOKENS:
        esp = tokens[0]
        tokens = tokens[1:]

    all_esps = False
    if tokens and tokens[-1].lower() == SUFFIX_ALL_ESPS:
        all_esps = True
        tokens = tokens[:-1]

    fy_month_match = None
    if tokens:
        fy_month_match = re.match(
            r"^(?:FY\s*(\d{2})|FY(\d{2}))\s*,\s*M(\d{1,2})\s*$",
            tokens[0],
            re.IGNORECASE,
        )

    fy = month = None
    if fy_month_match:
        fy = fy_month_match.group(1) or fy_month_match.group(2)
        month = fy_month_match.group(3).zfill(2)
        tokens = tokens[1:]

    audience_tier_parts: list[str] = []
    while tokens and is_audience_tier_token(tokens[-1]):
        audience_tier_parts.insert(0, tokens.pop())
    if all_esps:
        audience_tier_parts.append("All ESPs")
    audience_tier_raw = " | ".join(audience_tier_parts) if audience_tier_parts else None

    vertical_raw = tokens[0] if tokens else None
    offer_raw = " | ".join(tokens[1:]) if len(tokens) > 1 else None

    logical_key = (
        (fy or "??"),
        (month or "??"),
        (vertical_raw or "??").lower(),
        (offer_raw or "").lower(),
    )

    quality = "ok"
    if not fy or not month or not vertical_raw:
        quality = "partial"

    return {
        "raw_name": raw_name,
        "esp": esp,
        "all_esps": all_esps,
        "fy": fy,
        "month": month,
        "vertical_raw": vertical_raw,
        "offer_raw": offer_raw,
        "audience_tier_raw": audience_tier_raw,
        "logical_key": logical_key,
        "parse_quality": quality,
    }


def parse_milestone_name(
    raw_name: str, canonical_slugs: set[str] | None = None
) -> dict[str, Any]:
    """Pull FY/month/vertical/offer out of a Linear milestone name.

    `canonical_slugs` lets the slug-form parser do a longest-prefix-match
    against the canonical vertical inventory so e.g.
    `hotels-resorts-director-of-resort-experience-custom-illuminated-artwork-fy26-m07`
    decomposes into vertical=`hotels-resorts`, persona+offer in the middle.
    """
    name = raw_name.strip()
    archived = name.startswith("[ARCHIVED]")
    if archived:
        name = name[len("[ARCHIVED]"):].strip()

    if re.match(r"^[a-z0-9-]+$", name):
        slug_parts = name.rsplit("-fy", 1)
        if len(slug_parts) == 2 and re.match(r"^\d{2}-m\d{1,2}$", slug_parts[1]):
            fy_chunk, month_chunk = slug_parts[1].split("-m")
            body = slug_parts[0]
            vertical_slug = None
            remainder = body
            if canonical_slugs:
                for cand in sorted(canonical_slugs, key=len, reverse=True):
                    if body == cand or body.startswith(cand + "-"):
                        vertical_slug = cand
                        remainder = body[len(cand) + 1 :] if body != cand else ""
                        break
            return {
                "raw_name": raw_name,
                "archived": archived,
                "shape": "slug",
                "fy": fy_chunk,
                "month": month_chunk.zfill(2),
                "vertical_raw": vertical_slug or body,
                "offer_raw": remainder or None,
            }
        return {
            "raw_name": raw_name,
            "archived": archived,
            "shape": "slug-unparsed",
            "fy": None,
            "month": None,
            "vertical_raw": None,
            "offer_raw": None,
        }

    tokens = [t.strip() for t in name.split("|")]
    fy = month = None
    if tokens:
        m = re.match(
            r"^FY\s*(\d{2})\s*,\s*M(\d{1,2})\s*$", tokens[0], re.IGNORECASE
        )
        if m:
            fy = m.group(1)
            month = m.group(2).zfill(2)
            tokens = tokens[1:]
    vertical_raw = tokens[0] if tokens else None
    offer_raw = " | ".join(tokens[1:]) if len(tokens) > 1 else None
    return {
        "raw_name": raw_name,
        "archived": archived,
        "shape": "pipe",
        "fy": fy,
        "month": month,
        "vertical_raw": vertical_raw,
        "offer_raw": offer_raw,
    }


# ---------------- canonical inference ----------------

# Display-form → canonical slug overrides for EB/Linear strings that don't
# match a canonical yaml's `display:` value verbatim. Add new entries here
# rather than mutating canonicals (canonicals are source-of-truth per ADR-016).
VERTICAL_DISPLAY_OVERRIDES: dict[str, str] = {
    "hotels": "hotels-resorts",
    "hotels summer activation": "hotels-resorts",
    "hotels & resorts": "hotels-resorts",
    "car dealerships": "auto-dealerships",
    "auto dealerships": "auto-dealerships",
    "golf & country clubs": "country-clubs",
    "country clubs": "country-clubs",
    "colleges & universities": "universities",
    "universities": "universities",
    "hospitals & healthcare facilities": "hospitals",
    "healthcare facilities": "hospitals",
    "hospitals": "hospitals",
    "bars": "bars-restaurants",
    "restaurants & bars": "bars-restaurants",
    "restaurants & bars america 250": "bars-restaurants",
    "opentable restaurants": "bars-restaurants",
    "drive-thru": "bars-restaurants",
    "drive-thru restaurants": "bars-restaurants",
    "drive thru restaurants": "bars-restaurants",
    "wineries & breweries": "wineries-breweries",
    "tribes & reservations": "tribes-reservations",
    "amusement parks": "amusement-parks",
    "shopping centers, malls, outlets": "shopping-centers",
    "shopping centers": "shopping-centers",
    "stadiums, arenas & sports complexes": "sports-stadiums",
    "sports stadiums": "sports-stadiums",
    "ski resorts": "ski-resorts",
    "botanical gardens": "botanical-gardens",
    "historic sites": "historic-sites",
    "corporate campuses": "corporate-campuses",
    "event venues": "event-venues",
    "landscape architects": "landscape-architects",
    "landscape lighting": "landscape-lighting",
    "lighting installers": None,
    "hoas self-managed": "hoas",
    "hoas": "hoas",
    "municipalities": "municipalities",
    "municipalities america 250": "municipalities",
    "bars owners, gms": "bars-restaurants",
    "casinos": "casinos",
    "zoos": "zoos",
    "aquariums": "aquariums",
    "churches": "churches",
    "theaters": "theaters",
    "apartments": "apartments",
    "community management": None,
    "banks": None,
    "car washes": None,
    "luxury retail stores": None,
    "museums & art galleries": None,
    "flagship retail": "flagship-retail",
    "flagship-retail": "flagship-retail",
    "local retail (utah)": "local-retail",
    "prior year interested": None,
    "brite recruiting": None,
    "brite supply s4": None,
    "trade companies": None,
}

NON_VERTICAL_BUCKETS = {
    "prior year interested": "cross-vertical-reengagement",
    "250th anniversary": "cross-vertical-campaign",
    "brite recruiting": "brite-recruiting",
    "lighting installers": "supply-installer-network",
    "trade companies": "supply-installer-network",
    "flagship retail": "off-canon-retail",
    "local retail (utah)": "off-canon-retail",
    "luxury retail stores": "off-canon-retail",
    "banks": "off-canon-banks",
    "car washes": "off-canon-car-washes",
    "museums & art galleries": "off-canon-museums",
    "hotels summer activation": "hotels-resorts",
    "restaurants & bars america 250": "bars-restaurants",
    "municipalities america 250": "municipalities",
    "opentable restaurants": "bars-restaurants",
    "drive-thru": "bars-restaurants",
    "drive thru restaurants": "bars-restaurants",
    "drive-thru restaurants": "bars-restaurants",
    "stadiums, arenas & sports complexes": "sports-stadiums",
    "community management": "off-canon-community-management",
    "bars": "bars-restaurants",
}


def infer_vertical_slug(
    vertical_raw: str | None, canonical_map: dict[str, str]
) -> tuple[str | None, str]:
    """Return (slug_or_bucket, source). source ∈ canonical|override|bucket|miss."""
    if not vertical_raw:
        return None, "miss"
    key = vertical_raw.strip().lower()
    if key in canonical_map:
        return canonical_map[key], "canonical"
    if key in VERTICAL_DISPLAY_OVERRIDES:
        slug = VERTICAL_DISPLAY_OVERRIDES[key]
        if slug:
            return slug, "override"
    if key in NON_VERTICAL_BUCKETS:
        return NON_VERTICAL_BUCKETS[key], "bucket"
    return None, "miss"


def infer_entity(
    vertical_slug: str | None, vertical_raw: str | None, offer_raw: str | None
) -> str:
    """Best-effort entity assignment per the 3-entity model.

    nites = end-customer holiday-lighting verticals (most)
    supply = installer-network/trade outreach
    labs = bespoke creative direction / one-off Custom Illuminated Artwork
    cross-entity = re-engagement, recruiting, anything spanning entities
    """
    v_lower = (vertical_raw or "").lower()
    o_lower = (offer_raw or "").lower()
    if v_lower in {"lighting installers", "trade companies"}:
        return "supply"
    if v_lower == "brite recruiting":
        return "cross-entity"
    if v_lower in {"prior year interested"} or "250th anniversary" in v_lower:
        return "cross-entity"
    if "custom illuminated artwork" in o_lower:
        return "labs"
    if "aman-tier" in o_lower or "bespoke" in o_lower:
        return "labs"
    return "nites"


# ---------------- aggregation ----------------

def normalize_eb_row(
    row: dict[str, str], workspace: str, canonical_map: dict[str, str]
) -> dict[str, Any]:
    parsed = parse_eb_name(row["name"])
    slug, _src = infer_vertical_slug(parsed.get("vertical_raw"), canonical_map)
    fy, month, _vraw, offer_lower = parsed["logical_key"]
    canonical_key = (fy, month, (slug or _vraw), offer_lower)
    parsed["logical_key"] = canonical_key
    parsed["resolved_vertical_slug"] = slug
    parsed.update(
        {
            "eb_id": int(row["id"]),
            "workspace": workspace,
            "status": row["status"],
            "leads": int(row.get("leads") or 0),
            "sent": int(row.get("sent") or 0),
            "replies": int(row.get("replies") or 0),
            "bounced": int(row.get("bounced") or 0),
            "completion_pct": float(row.get("completion") or 0),
        }
    )
    return parsed


def load_eb_csv(
    path: Path, workspace: str, canonical_map: dict[str, str]
) -> list[dict[str, Any]]:
    with path.open() as f:
        return [normalize_eb_row(r, workspace, canonical_map) for r in csv.DictReader(f)]


def load_milestones(
    path: Path, canonical_slugs: set[str]
) -> list[dict[str, Any]]:
    data = json.loads(path.read_text())
    return [
        {
            "id": m["id"],
            "name": m["name"],
            "description": m.get("description") or "",
            "progress": m.get("progress"),
            "target_date": m.get("targetDate"),
            "parsed": parse_milestone_name(m["name"], canonical_slugs),
        }
        for m in data["milestones"]
    ]


def milestone_lookup_key(
    parsed_ms: dict[str, Any], canonical_map: dict[str, str]
) -> tuple | None:
    if not parsed_ms.get("fy") or not parsed_ms.get("month") or not parsed_ms.get("vertical_raw"):
        return None
    slug, _ = infer_vertical_slug(parsed_ms["vertical_raw"], canonical_map)
    return (parsed_ms["fy"], parsed_ms["month"], slug or parsed_ms["vertical_raw"].lower())


def aggregate_logical_campaigns(
    eb_records: list[dict[str, Any]], milestones: list[dict[str, Any]], canonical_map: dict[str, str]
) -> list[dict[str, Any]]:
    groups: dict[tuple, dict[str, Any]] = defaultdict(
        lambda: {
            "eb_campaigns": [],
            "audience_tiers": set(),
            "esps": set(),
            "workspaces": set(),
            "statuses": set(),
            "leads": 0,
            "sent": 0,
            "replies": 0,
            "bounced": 0,
        }
    )

    for rec in eb_records:
        key = rec["logical_key"]
        g = groups[key]
        g["eb_campaigns"].append(
            {
                "id": rec["eb_id"],
                "workspace": rec["workspace"],
                "name": rec["raw_name"].strip(),
                "esp": rec["esp"],
                "all_esps": rec["all_esps"],
                "audience_tier": rec["audience_tier_raw"],
                "status": rec["status"],
                "leads": rec["leads"],
                "sent": rec["sent"],
                "replies": rec["replies"],
                "bounced": rec["bounced"],
            }
        )
        if rec["audience_tier_raw"]:
            g["audience_tiers"].add(rec["audience_tier_raw"])
        if rec["esp"]:
            g["esps"].add(rec["esp"])
        if rec["all_esps"]:
            g["esps"].add("all-esps")
        g["workspaces"].add(rec["workspace"])
        g["statuses"].add(rec["status"])
        g["leads"] += rec["leads"]
        g["sent"] += rec["sent"]
        g["replies"] += rec["replies"]
        g["bounced"] += rec["bounced"]
        g.setdefault("fy", rec["fy"])
        g.setdefault("month", rec["month"])
        g.setdefault("vertical_raw", rec["vertical_raw"])
        g.setdefault("offer_raw", rec["offer_raw"])

    ms_index: dict[tuple, list[dict[str, Any]]] = defaultdict(list)
    for ms in milestones:
        key = milestone_lookup_key(ms["parsed"], canonical_map)
        if key:
            ms_index[key].append(ms)

    matched_ms_ids: set[str] = set()
    rows: list[dict[str, Any]] = []

    for key, g in groups.items():
        fy, month, vertical_key, offer_raw_lower = key
        vertical_raw = g.get("vertical_raw")
        offer_raw = g.get("offer_raw")
        ms_key = (fy, month, vertical_key) if vertical_key else None
        candidates = ms_index.get(ms_key, []) if ms_key else []
        for ms in candidates:
            matched_ms_ids.add(ms["id"])

        vertical_slug, vertical_source = infer_vertical_slug(vertical_raw, canonical_map)
        entity = infer_entity(vertical_slug, vertical_raw, offer_raw)
        reply_rate = (g["replies"] / g["sent"] * 100) if g["sent"] else 0.0

        cross_ref = "match" if candidates else "orphan-eb"
        rows.append(
            {
                "logical_key": f"fy{fy}-m{month}-{vertical_key}-{offer_raw_lower}",
                "fy": fy,
                "month": month,
                "vertical_raw": vertical_raw,
                "vertical_slug": vertical_slug,
                "vertical_inference": vertical_source,
                "offer_raw": offer_raw,
                "offer_slug": None,
                "persona_slug": None,
                "entity": entity,
                "audience_tiers": sorted(g["audience_tiers"]),
                "esps": sorted(g["esps"]),
                "eb_workspaces": sorted(g["workspaces"]),
                "eb_campaigns": sorted(g["eb_campaigns"], key=lambda c: c["id"]),
                "eb_status_set": sorted(g["statuses"]),
                "eb_stats": {
                    "leads": g["leads"],
                    "sent": g["sent"],
                    "replies": g["replies"],
                    "bounced": g["bounced"],
                    "reply_rate_pct": round(reply_rate, 2),
                },
                "linear_milestones": [
                    {
                        "id": ms["id"],
                        "name": ms["name"],
                        "progress": ms["progress"],
                        "target_date": ms["target_date"],
                    }
                    for ms in candidates
                ],
                "cross_reference": cross_ref,
                "reconciliation_status": derive_reconciliation_status(
                    has_eb=True,
                    has_linear=bool(candidates),
                    vertical_slug=vertical_slug,
                ),
            }
        )

    for ms in milestones:
        if ms["id"] in matched_ms_ids:
            continue
        parsed = ms["parsed"]
        vertical_raw = parsed.get("vertical_raw")
        offer_raw = parsed.get("offer_raw")
        vertical_slug, vertical_source = infer_vertical_slug(vertical_raw, canonical_map)
        entity = infer_entity(vertical_slug, vertical_raw, offer_raw)
        fy = parsed.get("fy")
        month = parsed.get("month")
        logical_key = (
            f"fy{fy or '??'}-m{month or '??'}-"
            f"{(vertical_raw or 'unknown').lower()}-"
            f"{(offer_raw or '').lower()}"
        )
        rows.append(
            {
                "logical_key": logical_key,
                "fy": fy,
                "month": month,
                "vertical_raw": vertical_raw,
                "vertical_slug": vertical_slug,
                "vertical_inference": vertical_source,
                "offer_raw": offer_raw,
                "offer_slug": None,
                "persona_slug": None,
                "entity": entity,
                "audience_tiers": [],
                "esps": [],
                "eb_workspaces": [],
                "eb_campaigns": [],
                "eb_status_set": [],
                "eb_stats": {
                    "leads": 0,
                    "sent": 0,
                    "replies": 0,
                    "bounced": 0,
                    "reply_rate_pct": 0.0,
                },
                "linear_milestones": [
                    {
                        "id": ms["id"],
                        "name": ms["name"],
                        "progress": ms["progress"],
                        "target_date": ms["target_date"],
                    }
                ],
                "cross_reference": "orphan-linear",
                "reconciliation_status": derive_reconciliation_status(
                    has_eb=False,
                    has_linear=True,
                    vertical_slug=vertical_slug,
                    archived=parsed.get("archived", False),
                ),
            }
        )

    rows.sort(
        key=lambda r: (
            r["fy"] or "00",
            r["month"] or "00",
            (r["vertical_slug"] or r["vertical_raw"] or "zz").lower(),
            r["logical_key"],
        )
    )
    return rows


def derive_reconciliation_status(
    *,
    has_eb: bool,
    has_linear: bool,
    vertical_slug: str | None,
    archived: bool = False,
) -> str:
    """Three-state output per BC body: not-started | partial | complete."""
    if archived and not has_eb:
        return "complete"
    if has_eb and has_linear and vertical_slug:
        return "complete"
    if has_eb and (not has_linear or not vertical_slug):
        return "partial"
    if has_linear and not has_eb:
        return "partial"
    return "not-started"


# ---------------- markdown rendering ----------------

def md_truncate(s: str | None, n: int) -> str:
    if not s:
        return ""
    return s if len(s) <= n else s[: n - 1] + "…"


def render_markdown(rows: list[dict[str, Any]]) -> str:
    total = len(rows)
    matched = sum(1 for r in rows if r["cross_reference"] == "match")
    orphan_eb = sum(1 for r in rows if r["cross_reference"] == "orphan-eb")
    orphan_linear = sum(1 for r in rows if r["cross_reference"] == "orphan-linear")
    eb_record_count = sum(len(r["eb_campaigns"]) for r in rows)
    linear_record_count = sum(len(r["linear_milestones"]) for r in rows)

    rec_counts = defaultdict(int)
    for r in rows:
        rec_counts[r["reconciliation_status"]] += 1

    lines: list[str] = []
    lines.append("# GTM Campaign Master Inventory")
    lines.append("")
    lines.append(
        "**Authored by**: BC-11851 (A1 Master Inventory)  "
        "**Linear project**: Brite GTM (`5e25e522-0700-4f0f-86a2-bdff965126f5`)  "
        "**EB workspaces**: b2b + personal  "
        "**Snapshot date**: 2026-05-27"
    )
    lines.append("")
    lines.append(
        "One row per **logical campaign** — the conceptual unit one operator "
        "schedules, copies, and reviews. Logical key = "
        "`(fy, month, vertical_raw, offer_raw)`. Multiple EB IDs per row come "
        "from ESP-splits (Microsoft / Google / SMTP) and audience-tier splits "
        "(Professional / Role / Personal / Managers+ / etc.). The audience-tier "
        "fan-out is preserved in `audience_tiers[]` so BC-11852 (A2 schema v2) "
        "can lock the audience-tier enum."
    )
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- **Logical campaigns**: {total}")
    lines.append(f"  - matched (EB ↔ Linear): {matched}")
    lines.append(f"  - orphan EB (no Linear milestone): {orphan_eb}")
    lines.append(f"  - orphan Linear (no EB record): {orphan_linear}")
    lines.append(f"- **Raw records folded in**: {eb_record_count} EB + {linear_record_count} Linear")
    lines.append("- **Reconciliation status**:")
    for status in ("complete", "partial", "not-started"):
        lines.append(f"  - {status}: {rec_counts.get(status, 0)}")
    lines.append("")
    lines.append("## Out-of-canon observations (feed-forward)")
    lines.append("")
    lines.append(
        "Verticals appearing in EB/Linear that aren't (yet) in "
        "`plugins/marketing/data/canonicals/_manifest.yaml` — flagged for "
        "BC-11853 (A3 canonicals bulk backfill) and BC-11854 (A4 flagship-retail "
        "vs shopping-centers taxonomy)."
    )
    lines.append("")
    misses: set[str] = set()
    bucket_rows: dict[str, set[str]] = defaultdict(set)
    for r in rows:
        if r["vertical_inference"] == "miss" and r["vertical_raw"]:
            misses.add(r["vertical_raw"])
        if r["vertical_inference"] == "bucket" and r["vertical_raw"]:
            bucket_rows[r["vertical_slug"] or "unknown"].add(r["vertical_raw"])
    if misses:
        for v in sorted(misses):
            lines.append(f"- `{v}` — no canonical mapping (candidate for BC-11853/BC-11854)")
    if bucket_rows:
        lines.append("")
        lines.append("**Folded into bucket slugs** (not in canonical _manifest.yaml; needs A3 decision):")
        for bucket, raws in sorted(bucket_rows.items()):
            lines.append(f"- `{bucket}` ← " + ", ".join(f"`{v}`" for v in sorted(raws)))
    lines.append("")
    lines.append("## Inventory")
    lines.append("")
    header = (
        "| # | FY/Mo | Vertical (raw → slug) | Offer (raw) | Entity | "
        "Linear milestone | EB IDs (workspace) | Audience tiers | EB status | "
        "Leads / Sent / Repl / Bnc | Reply % | X-ref | Recon |"
    )
    sep = "|" + "|".join(["---"] * 13) + "|"
    lines.append(header)
    lines.append(sep)

    for idx, r in enumerate(rows, start=1):
        fy_mo = (
            f"FY{r['fy']}/M{r['month']}"
            if r["fy"] and r["month"]
            else "??"
        )
        v_disp = (
            f"{md_truncate(r['vertical_raw'], 28)} → "
            f"`{r['vertical_slug'] or 'MISS'}`"
            f"{'' if r['vertical_inference'] == 'canonical' else ' *(' + r['vertical_inference'] + ')*'}"
        )
        offer_disp = md_truncate(r["offer_raw"], 40)
        ms_disp = "; ".join(
            f"`{ms['id'][:8]}` {md_truncate(ms['name'], 40)}"
            for ms in r["linear_milestones"]
        ) or "—"
        eb_disp = (
            ", ".join(
                f"{c['id']}({c['workspace'][0]})" for c in r["eb_campaigns"]
            )
            or "—"
        )
        tiers_disp = ", ".join(r["audience_tiers"]) or "—"
        status_disp = ", ".join(r["eb_status_set"]) or "—"
        stats_disp = (
            f"{r['eb_stats']['leads']} / {r['eb_stats']['sent']} / "
            f"{r['eb_stats']['replies']} / {r['eb_stats']['bounced']}"
        )
        reply_disp = f"{r['eb_stats']['reply_rate_pct']}%"
        lines.append(
            "| "
            + " | ".join(
                str(x)
                for x in [
                    idx,
                    fy_mo,
                    v_disp,
                    offer_disp or "—",
                    r["entity"],
                    ms_disp,
                    eb_disp,
                    tiers_disp,
                    status_disp,
                    stats_disp,
                    reply_disp,
                    r["cross_reference"],
                    r["reconciliation_status"],
                ]
            )
            + " |"
        )

    lines.append("")
    lines.append("## How to read this")
    lines.append("")
    lines.append(
        "- **Vertical (raw → slug)**: `raw` is the EB/Linear display string; "
        "`slug` is the canonical_manifest.yaml entry (or `bucket-…` / `MISS` "
        "when inference falls through). `*(override)*` means matched via the "
        "build script's display-overrides table; `*(bucket)*` means folded "
        "into a non-canonical bucket pending an A3/A4 decision."
    )
    lines.append(
        "- **EB IDs**: `(b)` = b2b workspace; `(p)` = personal. Three IDs for "
        "one row typically = ESP split (Microsoft / Google / SMTP)."
    )
    lines.append(
        "- **Audience tiers**: each tier is its own EB record but the same "
        "logical campaign. BC-11852 will lock the enum."
    )
    lines.append(
        "- **Recon**: `complete` = EB + Linear + canonical slug all present; "
        "`partial` = one of {EB, Linear, canonical slug} missing; "
        "`not-started` = none of the three (this should be 0 for valid rows)."
    )
    lines.append("")
    lines.append("## Spot-check (validation criterion)")
    lines.append("")
    lines.append(
        "5 random EB IDs verified resolvable via `get_campaign` at snapshot time "
        "(BC-11851 validation criterion). Replied/bounced counts may have drifted "
        "since the list snapshot was taken — `get_campaign` is live, `list_campaigns` "
        "lags by a session."
    )
    lines.append("")
    lines.append("| EB ID | Workspace | Name | Status | Verified |")
    lines.append("|---|---|---|---|---|")
    lines.append("| 7 | b2b | `FY25, M09 \\| Community Management \\| Managers+ \\| Professional Emails \\| All ESPs` | paused | yes |")
    lines.append("| 33 | b2b | `FY25, M11 \\| Churches \\| Managers+ \\| Professional Emails \\| All ESPs` | active | yes |")
    lines.append("| 73 | b2b | `FY26, M4 \\| Aquariums \\| Professional Emails \\| All ESPs` | completed | yes |")
    lines.append("| 134 | b2b | `SMTP \\| FY26, M05 \\| Prior Year Interested \\| Re-engagement \\| Professional Emails` | active | yes |")
    lines.append("| 52 | personal | `FY26, M05 \\| Brite Recruiting \\| Trade Companies \\| Personal Emails \\| All ESPs` | active | yes |")
    lines.append("")
    lines.append("## Sources")
    lines.append("")
    lines.append("- `docs/reconciliation/_sources/linear-milestones.json` — Brite GTM `list_milestones` snapshot")
    lines.append("- `docs/reconciliation/_sources/eb-b2b-campaigns.csv` — b2b workspace paginated rollup (109 records)")
    lines.append("- `docs/reconciliation/_sources/eb-personal-campaigns.csv` — personal workspace paginated rollup (21 records)")
    lines.append("- Generator: `plugins/marketing/scripts/build_master_index.py` (stdlib-only)")
    lines.append("")
    lines.append(
        "Refresh: pull the three snapshots via MCP "
        "(`list_milestones` + `list_campaigns` x2 paginated), replace files in "
        "`_sources/`, then `python3 plugins/marketing/scripts/build_master_index.py`."
    )
    lines.append("")
    lines.append("## Feed-forward for sibling BCs")
    lines.append("")
    lines.append(
        "- **BC-11852 (A2 schema v2 — audience tier enum)**: audience-tier strings "
        "found in EB across the inventory: `Professional Emails`, `Role Emails`, "
        "`Personal Emails`, `General Emails`, `Managers+`, `Managers+ (Reverified)`, "
        "`Employees`, `Bar Owners, GMs`, plus `Direct Question Offer` as a copy-modifier "
        "appended to Professional Emails. These should drive the enum lock."
    )
    lines.append(
        "- **BC-11853 (A3 canonicals bulk backfill)**: 4 verticals appear in EB/Linear "
        "with no canonical mapping (see *Out-of-canon observations* above); 9 more are "
        "folded into ad-hoc bucket slugs pending decision (`off-canon-banks`, "
        "`off-canon-car-washes`, `off-canon-museums`, `off-canon-retail`, "
        "`off-canon-community-management`, `cross-vertical-reengagement`, "
        "`cross-vertical-campaign`, `brite-recruiting`, `supply-installer-network`)."
    )
    lines.append(
        "- **BC-11854 (A4 flagship-retail vs shopping-centers taxonomy)**: 3 EB "
        "campaigns + 1 Linear milestone use `flagship-retail` as a distinct vertical; "
        "`shopping-centers` (canonical) is a separate sibling. Decision needed."
    )
    lines.append(
        "- **BC-11856 (A6 build /marketing:audit-campaigns)**: this index is a one-shot; "
        "the recurring drift detector reads from the same three snapshot sources and "
        "diffs against the previous run."
    )
    lines.append(
        "- **BC-11858 (A8 M07 in-flight scaffolds resolve)**: 2 slug-form milestones "
        "(`hotels-resorts-...-fy26-m07`, `flagship-retail-...-fy26-m07`) co-exist with "
        "matching pipe-form milestones from earlier scaffolding passes — clean-up "
        "decision needed."
    )
    lines.append("")
    return "\n".join(lines) + "\n"


# ---------------- main ----------------

def main() -> int:
    canonical_map = load_canonical_verticals()
    # Known-but-non-canonical slugs that appear in slug-form milestones
    # (e.g. /marketing:plan-campaign scaffolds for verticals pending an
    # A3/A4 canonical decision). Listed here so slug-form milestone parsing
    # can still longest-prefix-match a vertical out of the slug.
    extra_known_slugs = {
        "flagship-retail",
        "local-retail",
        "prior-year-interested",
        "brite-supply-s4",
        "brite-recruiting",
        "lighting-installers",
    }
    canonical_slugs = set(canonical_map.values()) | extra_known_slugs
    milestones = load_milestones(SRC / "linear-milestones.json", canonical_slugs)
    eb_b2b = load_eb_csv(SRC / "eb-b2b-campaigns.csv", "b2b", canonical_map)
    eb_personal = load_eb_csv(SRC / "eb-personal-campaigns.csv", "personal", canonical_map)
    eb_all = eb_b2b + eb_personal

    rows = aggregate_logical_campaigns(eb_all, milestones, canonical_map)

    OUT_JSON.write_text(
        json.dumps(
            {
                "snapshot_date": "2026-05-27",
                "linear_project": {
                    "id": GTM_PROJECT_ID,
                    "name": GTM_PROJECT_NAME,
                },
                "eb_workspaces": ["b2b", "personal"],
                "row_count": len(rows),
                "raw_record_counts": {
                    "linear_milestones": len(milestones),
                    "eb_b2b": len(eb_b2b),
                    "eb_personal": len(eb_personal),
                },
                "rows": rows,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n"
    )
    OUT_MD.write_text(render_markdown(rows))

    matched = sum(1 for r in rows if r["cross_reference"] == "match")
    print(
        f"wrote {len(rows)} logical rows "
        f"({matched} matched, {len(rows) - matched} orphan) "
        f"-> {OUT_MD.relative_to(REPO_ROOT)} + {OUT_JSON.relative_to(REPO_ROOT)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
