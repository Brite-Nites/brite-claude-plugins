#!/usr/bin/env python3
"""Deterministic per-vertical intro-deck template generator for rapid-asset-design
(BC-12975 follow-on — the "generated prompts + 1 DS skeleton" standard).

Given a vertical slug, this builder resolves that vertical's persona titles, offers,
and offer posture from the GTM canonicals (data/canonicals/<vertical>.yaml) and the
BriteBase brand tokens (data/brand/britebase-tokens.json), then emits the vertical's
standard intro-deck TEMPLATE: a rep-facing cheat-sheet + a paste-ready claude.ai/design
handoff prompt in which the ONLY remaining blanks are the three prospect-specific
fields ({prospect}, {contact}, {angle}).

Why a generator and not 27 hand-authored files: the canonicals already are the
per-vertical source of truth (personas/offers/posture) and they change; the brand
tokens are synced from the BriteBase Design System. Generation keeps all 27 templates
honest — re-run on any canonical or brand change instead of hand-patching 27 copies.

This builder is PURE and stdlib-only (per CLAUDE.md § Conventions), mirrors the
build_*.py house style, and emits NO volatile fields (no timestamps) so its output is
stable under --check. It reads only persona/offer/posture data — it never touches the
ICP layer, so seed_accounts / exclusions cannot leak into a client-facing template.

Exit codes:
  0 — built OK (or --check found no drift)
  2 — usage / unknown vertical / unreadable inputs
  3 — --check drift (committed template differs from a fresh regenerate)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _shared import canonicals_reader  # noqa: E402  (read-only canonicals query, stdlib)

SCHEMA_VERSION = 1

_HERE = Path(__file__).resolve().parent
_PLUGIN_ROOT = _HERE.parent  # plugins/marketing
DEFAULT_CANONICALS = _PLUGIN_ROOT / "data" / "canonicals"
DEFAULT_BRAND = _PLUGIN_ROOT / "data" / "brand" / "britebase-tokens.json"
DEFAULT_OUT_DIR = _PLUGIN_ROOT / "data" / "deck-templates"


def _die(msg: str, code: int = 2) -> "None":
    sys.stderr.write(f"build_deck_template: {msg}\n")
    raise SystemExit(code)


def load_brand(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        _die(f"cannot read brand tokens {path}: {exc}")


def primary_posture(offers: list[dict]) -> str:
    """The posture that governs the deck: the most common across the vertical's
    offers (first-in-file wins a tie). Empty string if no offer carries one."""
    counts: dict[str, int] = {}
    order: list[str] = []
    for o in offers:
        p = (o.get("posture") or "").strip()
        if not p:
            continue
        if p not in counts:
            counts[p] = 0
            order.append(p)
        counts[p] += 1
    if not order:
        return ""
    return max(order, key=lambda p: (counts[p], -order.index(p)))


def audience_line(personas: list[dict]) -> str:
    """`Display (Title / Title / …); …` — pre-resolved, never re-derived by the rep."""
    chunks = []
    for persona in personas:
        display = (persona.get("display") or persona.get("slug") or "").strip()
        titles = [t for t in (persona.get("titles") or []) if t]
        if display and titles:
            chunks.append(f"{display} ({' / '.join(titles)})")
        elif display:
            chunks.append(display)
    return "; ".join(chunks)


def render(vertical: str, vert: dict, brand: dict, entity: str) -> str:
    display = (vert.get("display") or vertical).strip()
    personas = vert.get("personas") or []
    offers = vert.get("offers") or []

    posture = primary_posture(offers)
    voice = (brand.get("posture_voice") or {}).get(posture, "on-brand and audience-appropriate")
    audience = audience_line(personas)
    short_audience = "; ".join(
        (p.get("display") or p.get("slug") or "").strip() for p in personas if (p.get("display") or p.get("slug"))
    )

    offer_lines = "\n".join(
        f"- {(o.get('display') or o.get('slug') or '').strip()} — posture: {(o.get('posture') or 'n/a').strip()}"
        for o in offers
        if (o.get("display") or o.get("slug"))
    ) or "- _(no offers in the canonical yet — name the angle yourself, hypothesis-framed)_"

    primary = brand.get("primary", "#ff4d00")
    s = brand.get("surfaces", {})
    bg, card, hero = s.get("background", "#efefef"), s.get("card", "#fbfbfa"), s.get("hero_dark", "#0b0b0b")
    f = brand.get("fonts", {})
    sans, mono, disp = f.get("sans", "Geist"), f.get("mono", "Geist Mono"), f.get("display", "MagdaClean")

    posture_label = posture or "(no canonical posture — frame neutrally, hypothesis-framed)"
    posture_rule = {
        "knowledge": "Educate, don't hard-sell. The deck makes the buyer look smart to their own stakeholders — outcomes that matter to their role, not pricing or a hard CTA.",
        "free-asset": "Lead with something genuinely useful, given away. The CTA is to claim the asset, not to buy.",
        "pilot": "Pitch a small, low-commitment first step that earns the next conversation — proof over promise.",
        "risk-reversal": "Remove the downside first (guarantee / no-risk framing); only then ask for the step.",
    }.get(posture, "Keep the tone and CTA true to the offer's posture; never a hard sell unless the posture says so.")

    # The paste-prompt block: %%MARKERS%% are injected here; {prospect}/{contact}/{angle}
    # stay LITERAL — they are the three blanks the rep fills.
    paste_prompt = (
        "Build an animated intro / concept deck for {prospect} (%%ENTITY%% — %%VOICE%% voice).\n\n"
        "Audience: {contact} and their stakeholders — decision-makers in the %%DISPLAY%% vertical "
        "(%%SHORT_AUDIENCE%%).\n"
        "Angle: {angle} — stance = %%POSTURE%%. %%POSTURE_RULE%%\n"
        "Brand tokens (use exactly): orange %%PRIMARY%% as the only saturated color on a light "
        "%%BG%% / %%CARD%% monochrome base; %%SANS%% + %%MONO%% + %%DISP%% type; the brite·base "
        "lockup; 1.5px inset strokes (never 1px solid); Linear-style focus ring; lightbulb + soft "
        "orange-glow motif.\n"
        "Shape: dark %%HERO%% title slide (lockup + animated orange glow) → light content slides "
        "(eyebrow + tight display + one supporting line; cards with 1.5px inset strokes) → an "
        "optional program/product peek → a dark orange-glow close with a %%POSTURE%%-appropriate CTA.\n"
        "Sections: title; the opportunity for {prospect}; what a %%ENTITY%% program looks like; "
        "outcomes that matter to {contact}; the next step.\n"
        "Interactivity: keyboard-navigable, one idea per slide, staggered entrance, "
        "prefers-reduced-motion respected.\n\n"
        "Rules: no fabricated stats, logos, or case studies. Do not include any internal account "
        "names or targeting/exclusion notes — this is client-facing."
    )
    repl = {
        "%%ENTITY%%": entity,
        "%%VOICE%%": voice,
        "%%DISPLAY%%": display,
        "%%SHORT_AUDIENCE%%": short_audience,
        "%%POSTURE%%": posture or "knowledge",
        "%%POSTURE_RULE%%": posture_rule,
        "%%PRIMARY%%": primary,
        "%%BG%%": bg,
        "%%CARD%%": card,
        "%%HERO%%": hero,
        "%%SANS%%": sans,
        "%%MONO%%": mono,
        "%%DISP%%": disp,
    }
    for k, v in repl.items():
        paste_prompt = paste_prompt.replace(k, v)

    doc = f"""<!-- GENERATED by plugins/marketing/scripts/build_deck_template.py (schema v{SCHEMA_VERSION}).
     Source: data/canonicals/{vertical}.yaml + data/brand/britebase-tokens.json.
     Do NOT hand-edit — regenerate: python3 plugins/marketing/scripts/build_deck_template.py --vertical {vertical} -->

# {display} — Intro Deck Template

**The standard concept-deck starting point for the {display} vertical.** Brand-, persona-, and posture-resolved from the canonicals — you fill three prospect blanks and generate in `claude.ai/design`. Power-user reps self-serve; the GTM asset team runs it for everyone else.

## Fill these three blanks

- **`{{prospect}}`** — the org you're pitching, e.g. "City of Frisco, TX"
- **`{{contact}}`** — who you're sending it to + their role
- **`{{angle}}`** — pick ONE offer below to anchor the deck

## Offers you can anchor on (this vertical)

{offer_lines}

> **Posture for this vertical: {posture_label}.** {posture_rule}

## Audience (pre-resolved — don't re-derive)

{audience}

## Generate the deck

1. Open a new `claude.ai/design` project **seeded from the _BriteBase — Intro Deck Skeleton_** (so brand + slide structure are inherited). If the skeleton isn't seeded, paste the prompt as-is — it carries the tokens inline.
2. Paste the prompt below, with your three blanks filled.

```
{paste_prompt}
```

## After generating

- Swap `{{prospect}}` into the title; optionally drop in a real photo of the prospect (their downtown, campus, venue, etc.).
- Run the **Brand-Consistency Checklist** in the `rapid-asset-design` skill before sharing.
- Export a share link, or hand off to Claude Code to clean up and deploy.

---
_Generated from `{vertical}.yaml` + `britebase-tokens.json`. Regenerate whenever the canonical or the brand tokens change — never hand-edit this file._
"""
    return doc


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Generate a per-vertical intro-deck template (BC-12975).")
    ap.add_argument("--vertical", required=True, help="canonical vertical slug (validated against _manifest.yaml)")
    ap.add_argument("--canonicals-dir", type=Path, default=DEFAULT_CANONICALS)
    ap.add_argument("--brand-tokens", type=Path, default=DEFAULT_BRAND)
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    ap.add_argument("--entity", default=None, help="override entity (default: brand tokens entity_default)")
    ap.add_argument("--stdout", action="store_true", help="print to stdout instead of writing the file")
    ap.add_argument("--check", action="store_true", help="exit 3 if the committed template differs from a fresh regenerate")
    args = ap.parse_args(argv)

    valid = canonicals_reader.load_canonicals_verticals(args.canonicals_dir)
    if args.vertical not in valid:
        _die(f"unknown vertical '{args.vertical}'. Valid slugs ({len(valid)}): {', '.join(sorted(valid))}")

    vert = canonicals_reader.load_vertical(args.canonicals_dir, args.vertical)
    if vert is None:
        _die(f"canonical file not found for '{args.vertical}' in {args.canonicals_dir}")

    brand = load_brand(args.brand_tokens)
    entity = args.entity or brand.get("entity_default", "brite-nites")

    content = render(args.vertical, vert, brand, entity)
    out_path = args.out_dir / f"{args.vertical}-intro-deck.md"

    if args.check:
        if not out_path.is_file():
            _die(f"--check: committed template missing at {out_path} (run without --check to generate)", 3)
        if out_path.read_text() != content:
            _die(f"--check: {out_path} is stale — regenerate with build_deck_template.py --vertical {args.vertical}", 3)
        print(f"OK — {out_path.name} matches a fresh regenerate")
        return 0

    if args.stdout:
        sys.stdout.write(content)
        return 0

    args.out_dir.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content)
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
