#!/usr/bin/env python3
"""Bootstrap new canonicals entries (vertical / offer / persona).

Consolidated helper for BC-8725. Three subcommands:
  - vertical: Add a new vertical to _manifest.yaml + create skeleton YAML.
  - offer: Add a new offer to an existing vertical's YAML.
  - persona: Add a new persona to an existing vertical's YAML.

Consumes _shared/canonicals_reader for validation. Mutations use direct
string/regex serialization — stdlib only (no PyYAML per CLAUDE.md).

Exit codes:
    0 — success (entry added).
    1 — validation failure (invalid slug, already exists, unknown vertical, etc.).
    2 — usage error.

Per vocabulary.md Section 4: canonical slug rule + 4-posture enum
(knowledge / free-asset / pilot / risk-reversal) per ADR-017.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _shared import canonicals_reader

SLUG_RE = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")
ALLOWED_POSTURE = frozenset({"knowledge", "free-asset", "pilot", "risk-reversal"})
ALLOWED_STATUS = frozenset({"draft", "active", "retired"})

DEFAULT_CANONICALS_DIR = (
    Path(__file__).resolve().parent.parent / "data" / "canonicals"
)


def _validate_slug(slug: str) -> str | None:
    """Return error message if slug is invalid, else None."""
    if not slug:
        return "slug cannot be empty"
    if not SLUG_RE.match(slug):
        return f"slug '{slug}' is not kebab-case (must match ^[a-z][a-z0-9]*(-[a-z0-9]+)*$)"
    return None


def _read_manifest_verticals(manifest_path: Path) -> list[str]:
    """Read verticals list from _manifest.yaml."""
    text = manifest_path.read_text()
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


def _insert_vertical_alphabetized(manifest_path: Path, slug: str) -> None:
    """Insert slug into _manifest.yaml verticals list in alphabetical order."""
    text = manifest_path.read_text()
    lines = text.splitlines(keepends=True)
    in_verticals = False
    insert_idx = None
    last_item_idx = None

    for i, line in enumerate(lines):
        if line.rstrip() == "verticals:":
            in_verticals = True
            continue
        if in_verticals:
            m = re.match(r"(\s*-\s*)([a-z0-9-]+)", line)
            if m:
                last_item_idx = i
                existing = m.group(2)
                if insert_idx is None and slug < existing:
                    insert_idx = i
            elif line.strip() and not line.startswith((" ", "\t", "#")):
                break

    if insert_idx is None:
        insert_idx = (last_item_idx + 1) if last_item_idx is not None else len(lines)

    new_line = f"  - {slug}\n"
    lines.insert(insert_idx, new_line)
    manifest_path.write_text("".join(lines))


def _create_vertical_yaml(canonicals_dir: Path, slug: str, display: str,
                           aliases: list[str] | None = None,
                           playbook_path: str | None = None) -> Path:
    """Create a new vertical YAML skeleton."""
    yaml_path = canonicals_dir / f"{slug}.yaml"
    parts = [f"slug: {slug}", f'display: "{display}"']
    if playbook_path:
        parts.append(f'playbook_path: "{playbook_path}"')
    if aliases:
        parts.append("aliases:")
        for a in aliases:
            parts.append(f"  - {a}")
    parts.append("personas: []")
    parts.append("offers: []")
    yaml_path.write_text("\n".join(parts) + "\n")
    return yaml_path


def _create_icp_stub(canonicals_dir: Path, slug: str,
                     playbook_path: str | None = None) -> Path:
    """Create the mandatory Discovery ICP stub for a new vertical (ADR-032).

    Every registered vertical MUST have icp/{slug}.json (lint_canonicals.py
    ERROR-enforces presence). The stub form is empty segments + non-empty
    clarifications_needed — structurally distinguishable from ready.
    """
    icp_dir = canonicals_dir / "icp"
    icp_dir.mkdir(exist_ok=True)
    icp_path = icp_dir / f"{slug}.json"
    stub = {
        "vertical": slug,
        "source": playbook_path or f"marketing/go-to-market/verticals/{slug}/README.md",
        "clarifications_needed": [
            "category / segment — account types (universes) in this vertical",
            "size band — employee and/or revenue floor per universe",
            "geography — confirm BN-territory regions",
            "fit / intent signals — what separates a strong-fit account",
            "seed accounts — 5-10 look-alike exemplars per universe",
            "exclusions — account types to filter out",
        ],
        "segments": {},
    }
    icp_path.write_text(json.dumps(stub, indent=2, ensure_ascii=False) + "\n")
    return icp_path


def _read_vertical_yaml_text(canonicals_dir: Path, vertical: str) -> str:
    """Read the raw text of a vertical YAML file."""
    return (canonicals_dir / f"{vertical}.yaml").read_text()


def _append_persona(canonicals_dir: Path, vertical: str, slug: str,
                    display: str, titles: list[str]) -> None:
    """Append a persona entry to the vertical's YAML."""
    yaml_path = canonicals_dir / f"{vertical}.yaml"
    text = yaml_path.read_text()

    entry_lines = [
        f"  - slug: {slug}",
        f'    display: "{display}"',
        "    titles:",
    ]
    for t in titles:
        entry_lines.append(f'      - "{t}"')
    entry_block = "\n".join(entry_lines) + "\n"

    lines = text.splitlines(keepends=True)
    personas_idx = None
    personas_end = None

    for i, line in enumerate(lines):
        stripped = line.rstrip()
        if stripped == "personas: []":
            lines[i] = "personas:\n" + entry_block
            yaml_path.write_text("".join(lines))
            return
        if stripped == "personas:":
            personas_idx = i
            continue
        if personas_idx is not None and personas_end is None:
            indent = len(line) - len(line.lstrip())
            if indent == 0 and line.strip():
                personas_end = i
                break

    if personas_idx is not None:
        insert_at = personas_end if personas_end is not None else len(lines)
        lines.insert(insert_at, entry_block)
        yaml_path.write_text("".join(lines))
    else:
        text = text.rstrip("\n") + "\npersonas:\n" + entry_block
        yaml_path.write_text(text)


def _append_offer(canonicals_dir: Path, vertical: str, slug: str,
                  display: str, posture: str, status: str) -> None:
    """Append an offer entry to the vertical's YAML."""
    yaml_path = canonicals_dir / f"{vertical}.yaml"
    text = yaml_path.read_text()

    entry_lines = [
        f"  - slug: {slug}",
        f'    display: "{display}"',
        f"    status: {status}",
        f"    posture: {posture}",
    ]
    entry_block = "\n".join(entry_lines) + "\n"

    lines = text.splitlines(keepends=True)
    offers_idx = None
    offers_end = None

    for i, line in enumerate(lines):
        stripped = line.rstrip()
        if stripped == "offers: []":
            lines[i] = "offers:\n" + entry_block
            yaml_path.write_text("".join(lines))
            return
        if stripped == "offers:":
            offers_idx = i
            continue
        if offers_idx is not None and offers_end is None:
            indent = len(line) - len(line.lstrip())
            if indent == 0 and line.strip():
                offers_end = i
                break

    if offers_idx is not None:
        insert_at = offers_end if offers_end is not None else len(lines)
        lines.insert(insert_at, entry_block)
        yaml_path.write_text("".join(lines))
    else:
        text = text.rstrip("\n") + "\noffers:\n" + entry_block
        yaml_path.write_text(text)


def cmd_vertical(args: argparse.Namespace) -> int:
    """Handle 'vertical' subcommand."""
    canonicals_dir: Path = args.canonicals_dir
    manifest_path = canonicals_dir / "_manifest.yaml"

    if not manifest_path.is_file():
        print(json.dumps({"ok": False, "error": "manifest not found",
                          "path": str(manifest_path)}))
        return 1

    slug = args.slug
    display = args.display

    err = _validate_slug(slug)
    if err:
        print(json.dumps({"ok": False, "error": err}))
        return 1

    verticals = _read_manifest_verticals(manifest_path)
    if slug in verticals:
        print(json.dumps({"ok": False, "error": f"vertical '{slug}' already exists in manifest",
                          "resume": f"/marketing:plan-campaign --vertical={slug} ..."}))
        return 1

    aliases = [a.strip() for a in args.aliases.split(",") if a.strip()] if args.aliases else None
    if aliases:
        for a in aliases:
            aerr = _validate_slug(a)
            if aerr:
                print(json.dumps({"ok": False, "error": f"alias {aerr}"}))
                return 1

    if args.preview:
        preview = {
            "action": "create_vertical",
            "slug": slug,
            "display": display,
            "aliases": aliases or [],
            "playbook_path": args.playbook_path or None,
            "manifest_insertion": f"  - {slug}  (alphabetized into _manifest.yaml)",
            "new_file": f"{slug}.yaml",
            "new_icp_stub": f"icp/{slug}.json  (Discovery ICP stub per ADR-032)",
        }
        print(json.dumps({"ok": True, "preview": preview}))
        return 0

    _insert_vertical_alphabetized(manifest_path, slug)
    yaml_path = _create_vertical_yaml(
        canonicals_dir, slug, display,
        aliases=aliases, playbook_path=args.playbook_path
    )
    icp_path = _create_icp_stub(canonicals_dir, slug,
                                playbook_path=args.playbook_path)

    handbook_draft = _handbook_draft_vertical(slug, display, args.playbook_path)

    result = {
        "ok": True,
        "action": "created_vertical",
        "slug": slug,
        "display": display,
        "manifest_path": str(manifest_path),
        "yaml_path": str(yaml_path),
        "icp_path": str(icp_path),
        "handbook_draft": handbook_draft,
        "resume": f"/marketing:plan-campaign --vertical={slug} ...",
    }
    print(json.dumps(result))
    return 0


def cmd_offer(args: argparse.Namespace) -> int:
    """Handle 'offer' subcommand."""
    canonicals_dir: Path = args.canonicals_dir
    vertical = args.vertical
    slug = args.slug
    display = args.display
    posture = args.posture
    status = args.status or "draft"

    err = _validate_slug(slug)
    if err:
        print(json.dumps({"ok": False, "error": err}))
        return 1

    verticals = canonicals_reader.load_canonicals_verticals(canonicals_dir)
    if vertical not in verticals:
        print(json.dumps({"ok": False, "error": f"vertical '{vertical}' not in canonicals manifest"}))
        return 1

    if posture not in ALLOWED_POSTURE:
        print(json.dumps({"ok": False, "error": f"posture '{posture}' invalid; must be one of: {sorted(ALLOWED_POSTURE)}"}))
        return 1

    if status not in ALLOWED_STATUS:
        print(json.dumps({"ok": False, "error": f"status '{status}' invalid; must be one of: {sorted(ALLOWED_STATUS)}"}))
        return 1

    data = canonicals_reader.load_vertical(canonicals_dir, vertical)
    if data is None:
        print(json.dumps({"ok": False, "error": f"vertical '{vertical}' YAML file not found"}))
        return 1

    existing_offers = [o.get("slug") for o in data.get("offers", []) if isinstance(o, dict)]
    if slug in existing_offers:
        print(json.dumps({"ok": False, "error": f"offer '{slug}' already exists in vertical '{vertical}'",
                          "resume": f"/marketing:plan-campaign --vertical={vertical} --offer={slug} ..."}))
        return 1

    if args.preview:
        preview = {
            "action": "add_offer",
            "vertical": vertical,
            "slug": slug,
            "display": display,
            "posture": posture,
            "status": status,
        }
        print(json.dumps({"ok": True, "preview": preview}))
        return 0

    _append_offer(canonicals_dir, vertical, slug, display, posture, status)

    handbook_draft = _handbook_draft_offer(vertical, slug, display, posture, status)

    result = {
        "ok": True,
        "action": "created_offer",
        "vertical": vertical,
        "slug": slug,
        "display": display,
        "posture": posture,
        "status": status,
        "yaml_path": str(canonicals_dir / f"{vertical}.yaml"),
        "handbook_draft": handbook_draft,
        "resume": f"/marketing:plan-campaign --vertical={vertical} --offer={slug} ...",
    }
    print(json.dumps(result))
    return 0


def cmd_persona(args: argparse.Namespace) -> int:
    """Handle 'persona' subcommand."""
    canonicals_dir: Path = args.canonicals_dir
    vertical = args.vertical
    slug = args.slug
    display = args.display
    titles_raw = args.titles

    err = _validate_slug(slug)
    if err:
        print(json.dumps({"ok": False, "error": err}))
        return 1

    verticals = canonicals_reader.load_canonicals_verticals(canonicals_dir)
    if vertical not in verticals:
        print(json.dumps({"ok": False, "error": f"vertical '{vertical}' not in canonicals manifest"}))
        return 1

    data = canonicals_reader.load_vertical(canonicals_dir, vertical)
    if data is None:
        print(json.dumps({"ok": False, "error": f"vertical '{vertical}' YAML file not found"}))
        return 1

    existing_personas = [p.get("slug") for p in data.get("personas", []) if isinstance(p, dict)]
    if slug in existing_personas:
        print(json.dumps({"ok": False, "error": f"persona '{slug}' already exists in vertical '{vertical}'",
                          "resume": f"/marketing:plan-campaign --vertical={vertical} --persona={slug} ..."}))
        return 1

    titles = [t.strip() for t in titles_raw.split(",") if t.strip()] if titles_raw else [display]

    if args.preview:
        preview = {
            "action": "add_persona",
            "vertical": vertical,
            "slug": slug,
            "display": display,
            "titles": titles,
        }
        print(json.dumps({"ok": True, "preview": preview}))
        return 0

    _append_persona(canonicals_dir, vertical, slug, display, titles)

    handbook_draft = _handbook_draft_persona(vertical, slug, display, titles)

    result = {
        "ok": True,
        "action": "created_persona",
        "vertical": vertical,
        "slug": slug,
        "display": display,
        "titles": titles,
        "yaml_path": str(canonicals_dir / f"{vertical}.yaml"),
        "handbook_draft": handbook_draft,
        "resume": f"/marketing:plan-campaign --vertical={vertical} --persona={slug} ...",
    }
    print(json.dumps(result))
    return 0


# ── Handbook draft generators ─────────────────────────────────────────────


def _handbook_draft_vertical(slug: str, display: str, playbook_path: str | None) -> dict:
    path = playbook_path or f"marketing/go-to-market/verticals/{slug}/README.md"
    content = f"""# {display}

## Overview

<!-- Describe the vertical's market characteristics, typical property types, and seasonal patterns. -->

## ICP Characteristics

<!-- Define the Ideal Customer Profile for this vertical. -->

## Competitive Landscape

<!-- Note key competitors and differentiation opportunities. -->

## Playbook

<!-- Campaign playbook: cadence, offer rotation, persona targeting. -->
"""
    return {
        "suggested_path": path,
        "suggested_commit_message": f"docs(verticals): add {display} vertical playbook ({slug})",
        "content": content,
    }


def _handbook_draft_offer(vertical: str, slug: str, display: str,
                          posture: str, status: str) -> dict:
    path = f"marketing/go-to-market/verticals/{vertical}/offers/{slug}.md"
    content = f"""# {display}

**Posture**: {posture}
**Status**: {status}

## Description

<!-- What this offer provides to the prospect. -->

## Delivery Mechanism

<!-- How the offer is delivered (PDF, landing page, consultation, etc.). -->

## Success Metrics

<!-- What constitutes a successful offer engagement. -->
"""
    return {
        "suggested_path": path,
        "suggested_commit_message": f"docs(offers): add {display} offer for {vertical} ({slug})",
        "content": content,
    }


def _handbook_draft_persona(vertical: str, slug: str, display: str,
                            titles: list[str]) -> dict:
    path = f"marketing/go-to-market/verticals/{vertical}/personas/{slug}.md"
    titles_block = "\n".join(f"- {t}" for t in titles)
    content = f"""# {display}

## Titles

{titles_block}

## Responsibilities

<!-- What this persona is responsible for day-to-day. -->

## Pain Points

<!-- Key frustrations and challenges this persona faces. -->

## Decision Criteria

<!-- What factors drive their purchasing decisions. -->
"""
    return {
        "suggested_path": path,
        "suggested_commit_message": f"docs(personas): add {display} persona for {vertical} ({slug})",
        "content": content,
    }


# ── CLI ───────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="canonicals_bootstrap.py",
        description="Bootstrap new GTM canonicals entries (BC-8725).",
    )
    parser.add_argument(
        "--canonicals-dir",
        type=Path,
        default=DEFAULT_CANONICALS_DIR,
        help="Path to canonicals directory.",
    )
    subparsers = parser.add_subparsers(dest="command")

    # vertical
    vp = subparsers.add_parser("vertical", help="Add a new vertical.")
    vp.add_argument("--slug", required=True)
    vp.add_argument("--display", required=True)
    vp.add_argument("--aliases", default=None, help="Comma-separated alias slugs.")
    vp.add_argument("--playbook-path", default=None)
    vp.add_argument("--preview", action="store_true")

    # offer
    op = subparsers.add_parser("offer", help="Add a new offer to a vertical.")
    op.add_argument("--vertical", required=True)
    op.add_argument("--slug", required=True)
    op.add_argument("--display", required=True)
    op.add_argument("--posture", required=True)
    op.add_argument("--status", default="draft")
    op.add_argument("--preview", action="store_true")

    # persona
    pp = subparsers.add_parser("persona", help="Add a new persona to a vertical.")
    pp.add_argument("--vertical", required=True)
    pp.add_argument("--slug", required=True)
    pp.add_argument("--display", required=True)
    pp.add_argument("--titles", default=None, help="Comma-separated title strings.")
    pp.add_argument("--preview", action="store_true")

    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 2

    if args.command == "vertical":
        return cmd_vertical(args)
    elif args.command == "offer":
        return cmd_offer(args)
    elif args.command == "persona":
        return cmd_persona(args)
    return 2


if __name__ == "__main__":
    sys.exit(main())
