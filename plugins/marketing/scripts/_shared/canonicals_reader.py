"""Read and query GTM canonicals YAML data (ADR-016).

Shared utility extracted per Rule-of-Three (BC-8728). Consumers:
  - portfolio_snapshot.py (BC-8731)
  - icp_refinement_review.py (BC-8726)
  - offer_performance.py (BC-8728)
  - lint_canonicals.py reads canonicals via its own full parser; this module
    uses a simplified regex approach for read-only queries.

Stdlib-only per CLAUDE.md § Conventions. Mirrors the regex-based YAML
parsing approach from portfolio_snapshot.py (pre-extraction).
"""
from __future__ import annotations

import re
from pathlib import Path


def load_canonicals_verticals(canonicals_dir: Path) -> list[str]:
    """Read _manifest.yaml to enumerate canonical vertical slugs."""
    manifest_path = canonicals_dir / "_manifest.yaml"
    if not manifest_path.is_file():
        return []
    try:
        text = manifest_path.read_text()
    except OSError:
        return []
    verticals: list[str] = []
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


def _parse_vertical_yaml(text: str) -> dict:
    """Minimal regex parse of a vertical YAML file.

    Returns {slug, display, personas: [{slug, display, titles}],
    offers: [{slug, display, status, posture, target_personas}]}.
    """
    result: dict = {}
    m = re.match(r"^slug:\s*(.+)$", text, re.MULTILINE)
    if m:
        result["slug"] = m.group(1).strip().strip('"').strip("'")
    m = re.search(r"^display:\s*(.+)$", text, re.MULTILINE)
    if m:
        result["display"] = m.group(1).strip().strip('"').strip("'")

    result["personas"] = _parse_block_list(text, "personas:")
    result["offers"] = _parse_block_list(text, "offers:")
    return result


def _parse_block_list(text: str, header: str) -> list[dict]:
    """Parse a YAML block list section (personas: or offers:)."""
    items: list[dict] = []
    lines = text.splitlines()
    in_section = False
    current_item: dict | None = None
    current_sub_list_key: str | None = None
    current_sub_list: list[str] | None = None

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())

        if indent == 0 and stripped.startswith(header.rstrip(":")):
            if stripped == header.rstrip(":") + ":":
                in_section = True
                continue
        if indent == 0 and in_section and not stripped.startswith("-"):
            in_section = False
            continue
        if not in_section:
            continue

        m = re.match(r"^(\s*)-\s+([a-zA-Z_][\w-]*)\s*:\s*(.*)$", line)
        if m and len(m.group(1)) <= 4:
            if current_item is not None:
                if current_sub_list_key and current_sub_list is not None:
                    current_item[current_sub_list_key] = current_sub_list
                items.append(current_item)
            current_item = {}
            current_sub_list_key = None
            current_sub_list = None
            key, val = m.group(2), m.group(3).strip()
            if val:
                current_item[key] = val.strip('"').strip("'")
            else:
                current_sub_list_key = key
                current_sub_list = []
                current_item[key] = current_sub_list
            continue

        if current_item is not None and indent > 2:
            m_kv = re.match(r"\s+([a-zA-Z_][\w-]*)\s*:\s*(.+)$", line)
            if m_kv:
                if current_sub_list_key and current_sub_list is not None:
                    current_item[current_sub_list_key] = current_sub_list
                    current_sub_list_key = None
                    current_sub_list = None
                key, val = m_kv.group(1), m_kv.group(2).strip()
                current_item[key] = val.strip('"').strip("'")
                continue

            m_kv_bare = re.match(r"\s+([a-zA-Z_][\w-]*)\s*:\s*$", line)
            if m_kv_bare:
                if current_sub_list_key and current_sub_list is not None:
                    current_item[current_sub_list_key] = current_sub_list
                current_sub_list_key = m_kv_bare.group(1)
                current_sub_list = []
                current_item[current_sub_list_key] = current_sub_list
                continue

            m_li = re.match(r"\s+-\s+(.+)$", line)
            if m_li and current_sub_list is not None:
                current_sub_list.append(m_li.group(1).strip().strip('"').strip("'"))
                continue

    if current_item is not None:
        if current_sub_list_key and current_sub_list is not None:
            current_item[current_sub_list_key] = current_sub_list
        items.append(current_item)

    return items


def load_vertical(canonicals_dir: Path, vertical: str) -> dict | None:
    """Load and parse a single vertical YAML file. Returns None if missing."""
    yaml_path = canonicals_dir / f"{vertical}.yaml"
    if not yaml_path.is_file():
        return None
    try:
        text = yaml_path.read_text()
    except OSError:
        return None
    return _parse_vertical_yaml(text)


def lookup_posture(
    canonicals_dir: Path, vertical: str, offer: str
) -> str | None:
    """Resolve offer posture from canonicals/<vertical>.yaml."""
    if not vertical or not offer:
        return None
    data = load_vertical(canonicals_dir, vertical)
    if not data:
        return None
    for o in data.get("offers", []):
        if isinstance(o, dict) and o.get("slug") == offer:
            return o.get("posture")
    return None


def lookup_offer_posture(
    canonicals_dir: Path, vertical: str, offer_slug: str
) -> str | None:
    """Alias for lookup_posture (semantic name used by BC-8728)."""
    return lookup_posture(canonicals_dir, vertical, offer_slug)


def lookup_persona_titles(
    canonicals_dir: Path, vertical: str, persona_slug: str
) -> list[str] | None:
    """Return the titles list for a persona slug, or None if not found."""
    if not vertical or not persona_slug:
        return None
    data = load_vertical(canonicals_dir, vertical)
    if not data:
        return None
    for p in data.get("personas", []):
        if isinstance(p, dict) and p.get("slug") == persona_slug:
            titles = p.get("titles")
            if isinstance(titles, list):
                return titles
    return None


def validate_canonical_ref(
    canonicals_dir: Path, vertical: str, offer_slug: str
) -> tuple[bool, str]:
    """Validate that a vertical + offer_slug pair exists in canonicals.

    Returns (valid, message). Used by BC-8728 to reject unknown offer slugs.
    """
    verticals = load_canonicals_verticals(canonicals_dir)
    if vertical and vertical not in verticals:
        return False, f"vertical '{vertical}' not in canonicals manifest"
    if not vertical:
        for v in verticals:
            data = load_vertical(canonicals_dir, v)
            if data:
                for o in data.get("offers", []):
                    if isinstance(o, dict) and o.get("slug") == offer_slug:
                        return True, f"offer '{offer_slug}' found in vertical '{v}'"
        return False, f"offer '{offer_slug}' not found in any vertical"
    data = load_vertical(canonicals_dir, vertical)
    if not data:
        return False, f"vertical '{vertical}' YAML file not found"
    for o in data.get("offers", []):
        if isinstance(o, dict) and o.get("slug") == offer_slug:
            return True, f"offer '{offer_slug}' valid in vertical '{vertical}'"
    return False, f"offer '{offer_slug}' not found in vertical '{vertical}'"


def find_offer_vertical(
    canonicals_dir: Path, offer_slug: str
) -> str | None:
    """Auto-detect which vertical contains a given offer slug."""
    for v in load_canonicals_verticals(canonicals_dir):
        data = load_vertical(canonicals_dir, v)
        if data:
            for o in data.get("offers", []):
                if isinstance(o, dict) and o.get("slug") == offer_slug:
                    return v
    return None
