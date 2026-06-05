#!/usr/bin/env python3
"""Compose v2 GTM campaign manifests from existing Linear + EB records.

Pure JSON-in / JSON-out helper for `/marketing:import-campaign` (BC-11849).
The slash command orchestrator handles every MCP and filesystem call; this
helper is responsible for the deterministic pieces:

  classify-name  Map a single EB campaign-name string to a structured
                 audience_tier object per the _manifest.yaml taxonomy
                 (BC-11852 / ADR-020).

  compose        Read a JSON description of a campaign import on stdin,
                 auto-classify the audience_tier of every eb_records[] entry,
                 and emit the full v2 manifest on stdout.

Per CLAUDE.md § Conventions: stdlib only (no PyYAML / json5 / jsonschema).
The `_manifest.yaml` audience_tiers block is parsed via a narrow regex
reader — the same approach used by sibling helpers (canonicals_reader.py).

Exit codes:
  0  Success.
  1  Caller error (malformed input JSON, missing required fields, EB record
     references an unknown workspace, etc.).
  2  Usage error (canonicals manifest missing, unknown subcommand).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

DEFAULT_CANONICALS_MANIFEST = (
    Path(__file__).resolve().parent.parent / "data" / "canonicals" / "_manifest.yaml"
)

ALLOWED_WORKSPACES = ("emailbison-b2b", "emailbison-personal")
ALLOWED_ENTITIES = ("nites", "supply", "labs")
# Canonical campaign-slug shape per ADR-012 + plan-campaign Step 3.2:
# kebab-case prefix + -fy<YY> + -m<MM> + optional -v<N> collision suffix.
CAMPAIGN_SLUG_RE = re.compile(
    r"^[a-z][a-z0-9]*(-[a-z0-9]+)*-fy\d{2}-m\d{2}(-v\d+)?$"
)
# Strict kebab-case for the vertical/persona/offer slug fields — mirrors the
# schema.json#/definitions/campaign_manifest component patterns.
KEBAB_RE = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")
# created_at must be an ISO-8601 date or UTC timestamp (schema declares a string;
# this shape guard keeps a non-conforming upstream value out of the contract).
CREATED_AT_RE = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}Z)?$")
# Campaign-manifest year bounds — must match schema.json (minimum 2025).
YEAR_MIN, YEAR_MAX = 2025, 2099


def _read_audience_tiers(manifest_path: Path) -> list[dict[str, Any]]:
    """Parse the audience_tiers[] block out of _manifest.yaml.

    Stdlib-only YAML carve-out: the block is line-oriented and well-formed
    (linted by lint_canonicals.py), so a per-line regex walker is sufficient.
    Returns a list of {slug, axis, display, matches[]} dicts.
    """
    if not manifest_path.is_file():
        raise FileNotFoundError(f"canonicals manifest not found: {manifest_path}")
    in_block = False
    entries: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    in_matches = False
    for raw in manifest_path.read_text().splitlines():
        line = raw.rstrip()
        if not in_block:
            if line.startswith("audience_tiers:"):
                in_block = True
            continue
        if line and not line.startswith(" ") and not line.startswith("#"):
            break
        stripped = line.lstrip()
        if stripped.startswith("#") or not stripped:
            continue
        if line.startswith("  - slug:"):
            if current is not None:
                entries.append(current)
            current = {
                "slug": stripped.split(":", 1)[1].strip(),
                "matches": [],
            }
            in_matches = False
            continue
        if current is None:
            continue
        if stripped.startswith("axis:"):
            current["axis"] = stripped.split(":", 1)[1].strip()
            in_matches = False
        elif stripped.startswith("display:"):
            current["display"] = stripped.split(":", 1)[1].strip()
            in_matches = False
        elif stripped.startswith("description:"):
            current["description"] = stripped.split(":", 1)[1].strip()
            in_matches = False
        elif stripped.startswith("matches:"):
            in_matches = True
        elif in_matches and stripped.startswith("- "):
            current["matches"].append(stripped[2:].strip())
    if current is not None:
        entries.append(current)
    return entries


def classify_name(
    eb_name: str,
    audience_tiers: list[dict[str, Any]],
    *,
    default_tier: str = "professional",
) -> dict[str, Any]:
    """Map an EB campaign-name string to a structured audience_tier object.

    Returns {"tier": <slug>, "seniority": <slug>|None, "modifiers": [<slug>,...]}.

    Rules (ADR-020 worked-examples lock):
      - Case-insensitive substring match against each entry's matches[].
      - At MOST one slug per (tier, seniority) axis. If multiple tier slugs
        match (e.g., 'Personal Emails' contains 'Personal' and 'Emails'),
        the LONGEST matching token wins (more-specific beats less-specific).
        Ties break by entry order in _manifest.yaml.
      - ANY number of modifier slugs may match.
      - tier defaults to ``default_tier`` (configurable, default
        "professional") when no tier match is found — ADR-020 calls this out
        for seniority-only EB strings like "Managers+ | All ESPs".
    """
    haystack = eb_name.lower()
    by_axis: dict[str, list[tuple[int, str]]] = {"tier": [], "seniority": []}
    modifiers: list[str] = []

    for entry in audience_tiers:
        axis = entry.get("axis")
        slug = entry.get("slug")
        if not axis or not slug:
            continue
        best_match_len = 0
        for token in entry.get("matches", []):
            if token and token.lower() in haystack:
                best_match_len = max(best_match_len, len(token))
        if best_match_len == 0:
            continue
        if axis == "modifier":
            if slug not in modifiers:
                modifiers.append(slug)
        elif axis in ("tier", "seniority"):
            by_axis[axis].append((best_match_len, slug))

    def pick(axis: str) -> str | None:
        candidates = by_axis.get(axis, [])
        if not candidates:
            return None
        candidates.sort(key=lambda pair: -pair[0])
        return candidates[0][1]

    tier_slug = pick("tier") or default_tier
    return {
        "tier": tier_slug,
        "seniority": pick("seniority"),
        "modifiers": modifiers,
    }


def _require(payload: dict[str, Any], key: str) -> Any:
    if key not in payload:
        raise ValueError(f"input missing required field: {key}")
    return payload[key]


def _coerce_eb_record(
    raw: dict[str, Any],
    audience_tiers: list[dict[str, Any]],
) -> dict[str, Any]:
    # A non-dict element (scalar / string / null) would otherwise raise a raw
    # TypeError out of _require's `in`/subscript ops — past _cmd_compose's
    # (ValueError, KeyError) catch — surfacing as an unhandled traceback instead
    # of the documented exit-1 caller-error. Guard it to a clean ValueError.
    if not isinstance(raw, dict):
        raise ValueError(
            f"eb_record must be an object; got {type(raw).__name__}"
        )
    workspace = _require(raw, "workspace")
    if workspace not in ALLOWED_WORKSPACES:
        raise ValueError(
            f"eb_record.workspace must be one of {ALLOWED_WORKSPACES}; got {workspace!r}"
        )
    cid = _require(raw, "campaign_id")
    if not isinstance(cid, (int, str)) or isinstance(cid, bool):
        raise ValueError(
            f"eb_record.campaign_id must be int or numeric string; got {cid!r}"
        )
    if isinstance(cid, str) and not (cid.isascii() and cid.isdigit()):
        # isascii() guard: bare .isdigit() accepts non-ASCII digits (e.g.
        # Arabic-Indic) that the schema's ^[0-9]+$ pattern rejects.
        raise ValueError(
            f"eb_record.campaign_id string must be numeric; got {cid!r}"
        )
    name = raw.get("name", "")
    if not isinstance(name, str):
        raise ValueError("eb_record.name must be a string when present")

    audience_tier = raw.get("audience_tier")
    pending = False
    if audience_tier is None:
        if not name.strip():
            # No name AND no explicit audience_tier — can't classify reliably.
            # Stamp the placeholder + pending_classification per ADR-020 § Migration
            # so the record surfaces in greps for operator review.
            audience_tier = {"tier": "professional", "seniority": None, "modifiers": []}
            pending = True
        else:
            audience_tier = classify_name(name, audience_tiers)
    else:
        # Operator-supplied audience_tier — defense-in-depth shape validation
        # against the schema.json #/definitions/audience_tier_object contract.
        if not isinstance(audience_tier, dict):
            raise ValueError(
                f"eb_record.audience_tier must be an object; got {type(audience_tier).__name__}"
            )
        tier_val = audience_tier.get("tier")
        if not isinstance(tier_val, str) or not tier_val:
            raise ValueError(
                "eb_record.audience_tier.tier required (non-empty string)"
            )
        # Finish the shape validation the schema's audience_tier_object declares
        # (additionalProperties:false + seniority string|null + modifiers list of
        # strings) — otherwise the operator-override path leaks unknown keys and
        # bad axis types past the helper into the manifest contract.
        extra_keys = set(audience_tier) - {"tier", "seniority", "modifiers"}
        if extra_keys:
            raise ValueError(
                f"eb_record.audience_tier has unknown keys: {sorted(extra_keys)} "
                f"(allowed: tier, seniority, modifiers)"
            )
        seniority_val = audience_tier.get("seniority")
        if seniority_val is not None and not isinstance(seniority_val, str):
            raise ValueError(
                "eb_record.audience_tier.seniority must be a string or null"
            )
        modifiers_val = audience_tier.get("modifiers", [])
        if not isinstance(modifiers_val, list) or not all(
            isinstance(m, str) for m in modifiers_val
        ):
            raise ValueError(
                "eb_record.audience_tier.modifiers must be a list of strings"
            )

    record: dict[str, Any] = {
        "workspace": workspace,
        "campaign_id": cid,
        "audience_tier": audience_tier,
    }
    if pending:
        record["pending_classification"] = True
    if name:
        record["name"] = name
    if "esp" in raw and raw["esp"]:
        record["esp"] = raw["esp"]
    if "launched_at" in raw:
        record["launched_at"] = raw["launched_at"]
    if "status" in raw and raw["status"]:
        record["status"] = raw["status"]
    return record


def compose_manifest(
    payload: dict[str, Any],
    audience_tiers: list[dict[str, Any]],
) -> dict[str, Any]:
    """Build the full v2 manifest from a JSON-shaped import description."""
    slug = _require(payload, "slug")
    if not CAMPAIGN_SLUG_RE.match(slug):
        raise ValueError(
            f"slug failed campaign-slug kebab-case + -fy<YY>-m<MM>[-v<N>] regex: {slug!r}"
        )
    entity = _require(payload, "entity")
    if entity not in ALLOWED_ENTITIES:
        raise ValueError(
            f"entity must be one of {ALLOWED_ENTITIES}; got {entity!r}"
        )

    linear = _require(payload, "linear")
    if not isinstance(linear, dict):
        raise ValueError("linear must be an object")
    for key in ("milestone_id", "milestone_url", "project"):
        if key not in linear:
            raise ValueError(f"linear.{key} required")
        if not isinstance(linear[key], str) or not linear[key].strip():
            raise ValueError(
                f"linear.{key} required (non-empty string); got {linear[key]!r}"
            )
    if not linear["milestone_url"].startswith("https://"):
        raise ValueError(
            f"linear.milestone_url must be an https:// URL; got {linear['milestone_url']!r}"
        )

    # vertical / persona / offer carry the schema's kebab-case pattern as their
    # own manifest fields (not just as slug components) — validate each so an
    # upstream-malformed value can't land in the contract.
    for key in ("vertical", "persona", "offer"):
        value = _require(payload, key)
        if not isinstance(value, str) or not KEBAB_RE.match(value):
            raise ValueError(f"{key} must be strict kebab-case; got {value!r}")

    # year / month arrive from JSON and the schema requires bounded integers.
    # Reject string-typed or out-of-range values (common JSON-stringification bug).
    year = _require(payload, "year")
    if not isinstance(year, int) or isinstance(year, bool) or not (YEAR_MIN <= year <= YEAR_MAX):
        raise ValueError(f"year must be an integer {YEAR_MIN}-{YEAR_MAX}; got {year!r}")
    month = _require(payload, "month")
    if not isinstance(month, int) or isinstance(month, bool) or not (1 <= month <= 12):
        raise ValueError(f"month must be an integer 1-12; got {month!r}")

    created_at = _require(payload, "created_at")
    if not isinstance(created_at, str) or not CREATED_AT_RE.match(created_at):
        raise ValueError(
            f"created_at must be ISO-8601 date or UTC timestamp; got {created_at!r}"
        )

    eb_workspace = _require(payload, "eb_workspace")
    if eb_workspace not in ALLOWED_WORKSPACES:
        raise ValueError(
            f"eb_workspace must be one of {ALLOWED_WORKSPACES}; got {eb_workspace!r}"
        )
    eb_campaign_name = _require(payload, "eb_campaign_name")

    raw_records = payload.get("eb_records", [])
    if not isinstance(raw_records, list):
        raise ValueError("eb_records must be a list")
    composed_records = [
        _coerce_eb_record(r, audience_tiers) for r in raw_records
    ]

    sf_campaign_id = payload.get("salesforce_campaign_id")
    sf_campaign_name = payload.get("salesforce_campaign_name", slug)

    manifest: dict[str, Any] = {
        "schema_version": 2,
        "slug": slug,
        "entity": entity,
        "vertical": payload["vertical"],
        "persona": payload["persona"],
        "offer": payload["offer"],
        "year": year,
        "month": month,
        "linear": {
            "milestone_id": linear["milestone_id"],
            "milestone_url": linear["milestone_url"],
            "project": linear["project"],
        },
        "salesforce": {
            "campaign_id": sf_campaign_id,
            "campaign_name": sf_campaign_name,
        },
        "email_bison": {
            "workspace": eb_workspace,
            "campaign_name": eb_campaign_name,
            "campaigns": composed_records,
        },
        "created_at": created_at,
        "scaffolded_by": payload.get("scaffolded_by", "/marketing:import-campaign"),
    }
    return manifest


def _cmd_classify_name(args: argparse.Namespace) -> int:
    tiers = _read_audience_tiers(args.canonicals_manifest)
    obj = classify_name(args.eb_name, tiers, default_tier=args.default_tier)
    sys.stdout.write(json.dumps(obj) + "\n")
    return 0


def _cmd_compose(args: argparse.Namespace) -> int:
    tiers = _read_audience_tiers(args.canonicals_manifest)
    raw = sys.stdin.read()
    if not raw.strip():
        sys.stderr.write("ERROR: compose subcommand expects JSON on stdin\n")
        return 1
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"ERROR: stdin JSON parse failed: {exc}\n")
        return 1
    if not isinstance(payload, dict):
        sys.stderr.write("ERROR: stdin JSON root must be an object\n")
        return 1
    try:
        manifest = compose_manifest(payload, tiers)
    except (ValueError, KeyError, TypeError) as exc:
        # TypeError included as a backstop so a malformed-shape payload surfaces
        # as the documented exit-1 caller-error, never an unhandled traceback.
        sys.stderr.write(f"ERROR: {exc}\n")
        return 1
    sys.stdout.write(json.dumps(manifest, indent=2) + "\n")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subs = parser.add_subparsers(dest="subcommand", required=True)

    p_class = subs.add_parser(
        "classify-name",
        help="Map a single EB campaign name to a structured audience_tier object.",
    )
    p_class.add_argument("--eb-name", required=True)
    p_class.add_argument(
        "--canonicals-manifest",
        type=Path,
        default=DEFAULT_CANONICALS_MANIFEST,
    )
    p_class.add_argument(
        "--default-tier",
        default="professional",
        help="Fallback tier slug when no tier substring matches (default: professional).",
    )
    p_class.set_defaults(func=_cmd_classify_name)

    p_comp = subs.add_parser(
        "compose",
        help="Read import payload JSON on stdin; emit composed v2 manifest on stdout.",
    )
    p_comp.add_argument(
        "--canonicals-manifest",
        type=Path,
        default=DEFAULT_CANONICALS_MANIFEST,
    )
    p_comp.set_defaults(func=_cmd_compose)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except FileNotFoundError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
