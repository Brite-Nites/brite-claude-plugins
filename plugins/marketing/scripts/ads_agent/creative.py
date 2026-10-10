"""Ads creative pipeline core (BC-28221). Stdlib only — CI installs nothing but pytest.

Code places every exact item (territory text, tracking phone number, logo) into the ad and
code checks it. AI may only edit the photo, and an AI-edited photo always goes to a person.

Data in, never constants: the territory table (name, phone per platform, logo) and the brand
rules (fonts, palette, logos) come from the caller. This repo is public — real tracking
numbers, account ids and client photos never live here.

Adapters (fakes in tests, real ones in creative_adapters.py):
  photos.photo(file_id) -> {"url", "approved"}          brand-hub photos via ImageKit
  renderers["placid"].create_image(payload) -> {"id", "image_url"}
  renderers["hyperframes"].render_video(payload) -> {"id", "url"}
  editor.model, editor.edit(image_url, prompt, settings) -> image_url   Vertex AI / Higgsfield
"""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass, field


@dataclass(frozen=True)
class Ad:
    territory: str
    platform: str
    template_id: str
    render_engine: str
    source_photo_id: str
    headline: str
    phone: str
    logo_id: str
    render_id: str
    render_url: str
    ai_edited: bool = False
    edit_model: str | None = None
    prompt: str | None = None
    settings: dict = field(default_factory=dict)
    approved_by: str | None = None


def make_ad(*, territory, template, photo_id, platform, territories, rules, photos, renderers,
            edit=None):
    """Render one territory version. edit = {"editor", "prompt", "settings"} runs an AI
    photo edit first; the ad then needs a person's approval (see brand_check)."""
    t = territories[territory]
    photo = photos.photo(photo_id)
    if not photo["approved"]:
        raise ValueError(f"photo {photo_id} is not approved in brand-hub; refusing to render")
    photo_url = photo["url"]
    if edit:
        photo_url = edit["editor"].edit(photo_url, edit["prompt"], edit.get("settings", {}))
    headline = template["headline"].format(territory=t["name"])
    phone = t["phones"][platform]
    logo_url = rules["logos"][t["logo"]]
    engine = template["engine"]
    if engine == "placid":
        # Layer names are a template convention: the designer names Placid layers
        # photo / headline / phone / logo.
        result = renderers["placid"].create_image({
            "template_uuid": template["placid_uuid"],
            "create_now": True,
            "layers": {
                "photo": {"image": photo_url},
                "headline": {"text": headline},
                "phone": {"text": phone},
                "logo": {"image": logo_url},
            },
        })
        render_url = result["image_url"]
    elif engine == "hyperframes":
        result = renderers["hyperframes"].render_video({
            "composition": template["composition"],
            "variables": {"photo": photo_url, "headline": headline, "phone": phone, "logo": logo_url},
        })
        render_url = result["url"]
    else:
        raise ValueError(f"unknown render engine {engine!r} in template {template['id']}")
    return Ad(
        territory=territory,
        platform=platform,
        template_id=template["id"],
        render_engine=engine,
        source_photo_id=photo_id,
        headline=headline,
        phone=phone,
        logo_id=t["logo"],
        render_id=result["id"],
        render_url=render_url,
        ai_edited=bool(edit),
        edit_model=edit["editor"].model if edit else None,
        prompt=edit["prompt"] if edit else None,
        settings=edit.get("settings", {}) if edit else {},
    )


def brand_check(ad, observed, rules, judge):
    """One brand check for every system's ads (Brite's and vendors').

    observed = what an inspector read off the finished render:
      {"text": OCR text, "fonts": [...], "overlay_colors": ["#RRGGBB", ...], "logo": logo id or None}
    judge.review(image_url, rules) -> {"pass": bool, "reasons": [...]} (taste only).

    Returns {"status": "pass" | "fix" | "needs_human", "findings": [{"check", "detail"}]}.
    "fix" goes back for a fix in code; "needs_human" waits for a person.
    """
    findings = [{"check": "text", "detail": d} for d in _text_problems(ad, observed["text"])]
    if not observed["fonts"]:
        findings.append({"check": "fonts", "detail": "no font read off the render"})
    findings += [
        {"check": "fonts", "detail": f"font {f!r} is not a brand font"}
        for f in observed["fonts"] if f not in rules["fonts"]
    ]
    if not observed["overlay_colors"]:
        findings.append({"check": "colors", "detail": "no overlay color read off the render"})
    findings += [
        {"check": "colors", "detail": f"overlay color {c} is off the palette"}
        for c in observed["overlay_colors"]
        if min(_delta_e(c, p) for p in rules["palette"]) > rules["max_color_distance"]
    ]
    if observed["logo"] != ad.logo_id:
        findings.append({"check": "logo", "detail": f"expected logo {ad.logo_id}, read {observed['logo']}"})
    if not findings:  # a code failure goes back anyway; judge the fixed render instead
        verdict = judge.review(ad.render_url, rules)
        if not verdict["pass"]:
            findings += [{"check": "judge", "detail": r} for r in verdict["reasons"]]
    status = "fix" if findings else "pass"
    # Spec: a person reviews every AI-edited photo, all season. No check can waive it.
    if ad.ai_edited and not ad.approved_by:
        findings.append({"check": "human_approval",
                         "detail": f"AI-edited photo ({ad.edit_model}) needs a person's approval"})
        status = "fix" if status == "fix" else "needs_human"
    return {"status": status, "findings": findings}


def creative_inputs_row(ad, *, ad_account_id, ad_id):
    """One row for brite-data-platform ANALYTICS.OPERATIONS.ADS_CREATIVE_INPUTS, written when
    the ad is published. creative_key is deterministic, so re-logging the same ad is a no-op
    upsert, and (platform, ad_account_id, ad_id) is the join to ad results."""
    return {
        "creative_key": f"{ad.platform}:{ad_account_id}:{ad_id}",
        "ad_account_id": ad_account_id,
        "ad_id": ad_id,
        **asdict(ad),
    }


# Digit groups joined by phone punctuation or single spaces: "(555) 010-0001", "+1 555.010.0001".
_NUMBER_RUN = re.compile(r"[\d()+.\-]+(?: [\d()+.\-]+)*")


def _phone_digits(s):
    d = re.sub(r"\D", "", s)
    # ponytail: US numbers only (+1 country code dropped); widen if a non-US territory appears.
    return d[1:] if len(d) == 11 and d.startswith("1") else d


def _text_problems(ad, text):
    problems = []
    if " ".join(ad.headline.split()) not in " ".join(text.split()):
        problems.append(f"headline {ad.headline!r} not found exactly")
    want = _phone_digits(ad.phone)
    # Any 5+ digit run that is not the territory's number fails: another territory's or
    # platform's number, a misread, a client's house number or a street sign.
    numbers = [_phone_digits(m) for m in _NUMBER_RUN.findall(text)]
    numbers = [n for n in numbers if len(n) >= 5]
    if want not in numbers:
        problems.append(f"tracking number {ad.phone} not found")
    problems += [f"unexpected number {n}" for n in numbers if n != want]
    return problems


def _lab(hex_color):
    """sRGB "#RRGGBB" -> CIELAB (D65)."""
    rgb = [int(hex_color.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    r, g, b = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    xyz = (
        (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047,
        0.2126 * r + 0.7152 * g + 0.0722 * b,
        (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883,
    )
    fx, fy, fz = [t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116 for t in xyz]
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def _delta_e(a, b):
    # ponytail: CIE76 (straight Lab distance). Research recommends CIEDE2000; switch when the
    # limit is calibrated on labelled ads. max_color_distance in the rules is the tuning knob.
    return sum((x - y) ** 2 for x, y in zip(_lab(a), _lab(b))) ** 0.5
