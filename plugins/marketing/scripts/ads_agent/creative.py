"""Ads creative pipeline core (BC-28221, BC-28299). Stdlib only — CI installs nothing but pytest.

Code places every exact item (city name, tracking phone number, logo) into the ad and code
checks it. AI may only edit the photo. An AI-edited photo is stored in its own ImageKit folder,
never brand-hub's approved library, and the ad cannot be marked ready until the Head of GTM
approves it in Slack.

Data in, never constants. This repo is public — real tracking numbers, account ids and client
photos never live here:
  territories  load_territories(path): the private runner config's `territories_path`, shaped
               like data/ads-creative/territories.schema.json (placeholder:
               territories.example.json, fictional 555-010-xxxx numbers)
  brand rules  load_brand_rules(): data/ads-creative/brite-nites-brand-rules.toml, taken from
               the brand book in brand-hub with the page of each value cited

Adapters (fakes in fakes.py, real ones in creative_adapters.py):
  photos.photo(file_id) -> {"url", "approved"}             brand-hub photos via ImageKit
  photos.upload_ai_edit(image_url, file_name=) -> {"file_id", "url"}   AI_EDITED_FOLDER only
  renderers["placid"].create_image(payload) -> {"id", "image_url"}
  renderers["hyperframes"].render_video(payload) -> {"id", "url"}
  editor.model, editor.edit(image_url, prompt, settings) -> image_url   Vertex AI / Higgsfield
  ocr.read_text(image_url) -> {"text", "confidence"}        text recognition on the render
  inspector.inspect(image_url) -> {"overlay_colors": ["#RRGGBB", ...], "logo": id or None}
  judge.review(image_url, rules, locked) -> {"pass", "reasons", "fonts", "blocked"}   Claude
  approvals.request(text, image_url) -> request id          Slack message to the Head of GTM
  approvals.decision(request_id) -> None | {"decision": "approve" | "reject", "by"}
"""

from __future__ import annotations

import dataclasses
import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path

BRAND_RULES_PATH = (
    Path(__file__).resolve().parents[2] / "data" / "ads-creative" / "brite-nites-brand-rules.toml"
)
PLATFORMS = ("google_ads", "meta_ads")
# AI-edited photos live here, tagged AI_EDITED_TAG, never in brand-hub's approved library.
AI_EDITED_FOLDER = "/ads/ai-edited/"
AI_EDITED_TAG = "AI-edited"
# The 2026-10-06 creative amendment: nothing in an ad may identify a client's home, car or
# family. The judge reports these; code blocks the ad.
BLOCKED_CONTENT = ("face", "house_number", "license_plate")


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
    edit_model: str | None = None  # every AI tool that touched the ad, comma-separated
    prompt: str | None = None
    settings: dict = field(default_factory=dict)  # {"edit": {...}, "platform": {...}}
    approved_by: str | None = None


def load_brand_rules(path=BRAND_RULES_PATH):
    """The brand rules file as a dict, after checking every color name it uses is in its
    palette."""
    import tomllib  # Python 3.11+; imported here so the rest of the module runs on 3.10

    with open(path, "rb") as f:
        rules = tomllib.load(f)
    palette, cr = rules["palette"], rules["color_rules"]
    bad = [f"{name} = {hex_!r} is not #RRGGBB" for name, hex_ in palette.items()
           if not re.fullmatch(r"#[0-9A-Fa-f]{6}", hex_)]
    names = [n for group in rules["schemes"].values() for n in group]
    names += cr["not_for_text"] + cr["never_background"] + [n for pair in cr["gradient_bans"] for n in pair]
    names += [p[k] for p in cr["text_pairings"] for k in ("text", "ground")]
    names += [p[k] for p in rules["logo"]["pairings"] for k in ("mark", "ground")]
    bad += [f"color {n!r} is not in the palette" for n in dict.fromkeys(names) if n not in palette]
    if not rules["fonts"]:
        bad.append("no fonts")
    if bad:
        raise ValueError(f"brand rules {path}: " + "; ".join(bad))
    return rules


_SITE_KEYS = ("site", "territory", "cities", "phones", "logo")
_PHONE = re.compile(r"\(\d{3}\) \d{3}-\d{4}")


def load_territories(path):
    """The territory table, keyed by site. path is the private runner config's
    `territories_path`. Refuses a file that does not match territories.schema.json."""
    with open(path) as f:
        doc = json.load(f)
    sites = doc.get("sites") if isinstance(doc, dict) else None
    problems = [] if isinstance(doc, dict) and set(doc) == {"sites"} else ['top level must be {"sites": [...]}']
    if not isinstance(sites, list) or not sites:
        problems.append("sites must be a non-empty list")
        sites = []
    table = {}
    for i, row in enumerate(sites):
        problems += [f"sites[{i}]: {p}" for p in _site_problems(row)]
        key = row.get("site") if isinstance(row, dict) else None
        if isinstance(key, str) and key in table:
            problems.append(f"sites[{i}]: site {key!r} appears twice")
        elif isinstance(key, str) and key:
            table[key] = row
    if problems:
        raise ValueError(f"territory table {path}: " + "; ".join(problems))
    return table


def _site_problems(row):
    if not isinstance(row, dict) or set(row) != set(_SITE_KEYS):
        return [f"keys must be exactly {', '.join(_SITE_KEYS)}"]
    p = [f"{k} must be a non-empty string" for k in ("site", "territory")
         if not isinstance(row[k], str) or not row[k]]
    cities = row["cities"]
    if not isinstance(cities, list) or not cities or not all(isinstance(c, str) and c for c in cities):
        p.append("cities must be a non-empty list of names")
    phones = row["phones"]
    if not isinstance(phones, dict) or set(phones) != set(PLATFORMS):
        p.append(f"phones must have exactly {', '.join(PLATFORMS)}")
    else:
        # The value stays out of the message: a real tracking number never goes to a log.
        p += [f"phones.{k} is not written (NNN) NNN-NNNN" for k, v in phones.items()
              if not isinstance(v, str) or not _PHONE.fullmatch(v)]
    logo = row["logo"]
    if (not isinstance(logo, dict) or set(logo) != {"id", "url"} or not logo["id"]
            or not str(logo["url"]).startswith("https://")):
        p.append("logo must be {id, url} with an https url")
    return p


def make_ad(*, site, template, photo_id, platform, territories, rules, photos, renderers,
            city=None, edit=None, platform_settings=None):
    """Render one site's version of a template. city picks the headline's city (default: the
    site's first city).

    edit = {"editor", "prompt", "settings"} runs an AI photo edit first. The edited photo is
    stored in AI_EDITED_FOLDER, and the ad then needs the Head of GTM's approval (mark_ready).

    platform_settings = the platform's creative settings for this ad, recorded on the
    creative-inputs row. Its "ai_features" maps each platform AI feature to on/off; any that
    is on is recorded as an AI tool that touched the ad.
    """
    t = territories[site]
    city = city or t["cities"][0]
    if city not in t["cities"]:
        raise ValueError(f"{city!r} is not a city of site {site}")
    _locked(template, rules)  # an off-brand template is refused before any render
    photo = photos.photo(photo_id)
    if not photo["approved"]:
        raise ValueError(f"photo {photo_id} is not approved in brand-hub; refusing to render")
    photo_url = photo["url"]
    if edit:
        edited = edit["editor"].edit(photo_url, edit["prompt"], edit.get("settings", {}))
        photo_url = photos.upload_ai_edit(edited, file_name=f"{photo_id}-ai-edited")["url"]
    headline = template["headline"].format(city=city)
    phone = t["phones"][platform]
    logo_url = t["logo"]["url"]
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
    platform_settings = platform_settings or {}
    ai_tools = [edit["editor"].model] if edit else []
    ai_tools += [f"{platform}:{name}" for name, on in sorted(platform_settings.get("ai_features", {}).items()) if on]
    return Ad(
        territory=t["territory"],
        platform=platform,
        template_id=template["id"],
        render_engine=engine,
        source_photo_id=photo_id,
        headline=headline,
        phone=phone,
        logo_id=t["logo"]["id"],
        render_id=result["id"],
        render_url=render_url,
        ai_edited=bool(edit),
        edit_model=", ".join(ai_tools) or None,
        prompt=edit["prompt"] if edit else None,
        settings={"edit": edit.get("settings", {}) if edit else {}, "platform": platform_settings},
    )


def brand_check(ad, template, rules, *, ocr, inspector, judge):
    """One brand check for every system's ads (Brite's and vendors'). It reads the finished
    render itself: text recognition for the exact headline and phone number, a pixel read of
    the overlay colors and logo, then the Claude review. Fonts and colors are checked against
    the ones the template locks, not the whole brand palette.

    Returns {"status": "pass" | "fix" | "needs_human", "findings": [{"check", "detail"}]}.
    "fix" goes back for a fix in code; "needs_human" waits for a person (see mark_ready).
    """
    locked = _locked(template, rules)
    limits = rules["checks"]
    read = ocr.read_text(ad.render_url)
    findings = [{"check": c, "detail": d} for c, d in _text_problems(ad, read["text"])]
    if read["confidence"] < limits["min_ocr_confidence"]:
        findings.append({"check": "text", "detail": f"text read at confidence {read['confidence']:.2f}, "
                                                    f"under {limits['min_ocr_confidence']}"})
    seen = inspector.inspect(ad.render_url)
    if not seen["overlay_colors"]:
        findings.append({"check": "colors", "detail": "no overlay color read off the render"})
    findings += [
        {"check": "colors", "detail": f"overlay color {c} is not a color the template locks"}
        for c in seen["overlay_colors"]
        if min(_delta_e(c, h) for h in locked["colors"].values()) > limits["max_color_distance"]
    ]
    if seen["logo"] != ad.logo_id:
        findings.append({"check": "logo", "detail": f"expected logo {ad.logo_id}, read {seen['logo']}"})
    if not findings:  # a code failure goes back anyway; review the fixed render instead
        review = judge.review(ad.render_url, rules, locked)
        if not review["fonts"]:
            findings.append({"check": "fonts", "detail": "the review named no font in the render"})
        findings += [{"check": "fonts", "detail": f"font {f!r} is not a font the template locks"}
                     for f in review["fonts"] if f not in locked["fonts"]]
        findings += [{"check": "blocked", "detail": f"{b['kind']}: {b['detail']}"} for b in review["blocked"]]
        if not review["pass"]:
            findings += [{"check": "judge", "detail": r} for r in review["reasons"]]
    status = "fix" if findings else "pass"
    # Spec: a person reviews every AI-edited photo, all season. No check can waive it.
    if ad.ai_edited and not ad.approved_by:
        findings.append({"check": "human_approval",
                         "detail": f"AI-edited photo ({ad.edit_model}) needs a person's approval"})
        status = "fix" if status == "fix" else "needs_human"
    return {"status": status, "findings": findings}


def request_approval(ad, approvals):
    """Ask the Head of GTM in Slack to approve or reject one AI-edited ad. Returns the request
    id; keep it with the ad until mark_ready finds the answer."""
    if not ad.ai_edited:
        raise ValueError("only an AI-edited ad goes to the Head of GTM for approval")
    return approvals.request(
        f"AI-edited ad to approve: {ad.territory}, {ad.platform}, template {ad.template_id}.\n"
        f"AI tools: {ad.edit_model}. Prompt: {ad.prompt}\n"
        "Reply approve or reject in this thread.",
        ad.render_url,
    )


def mark_ready(ad, check, *, approvals=None, request_id=None):
    """The one way an ad becomes ready to publish. Returns {"status", "ad", "detail"}:
      ready     the brand check passed; an AI-edited ad also has a recorded approval, and the
                approver is written to approved_by
      fix       the brand check found a problem
      waiting   AI-edited, and no recorded approve or reject yet
      rejected  the Head of GTM rejected it
    approved_by comes only from the recorded Slack decision. A value set by hand does not count.
    """
    problems = [f for f in check["findings"] if f["check"] != "human_approval"]
    if problems:
        return {"status": "fix", "ad": ad, "detail": "; ".join(f["detail"] for f in problems)}
    if not ad.ai_edited:
        return {"status": "ready", "ad": ad, "detail": "brand check passed"}
    decision = approvals.decision(request_id) if approvals and request_id else None
    if decision is None:
        return {"status": "waiting", "ad": dataclasses.replace(ad, approved_by=None),
                "detail": "no recorded decision from the Head of GTM yet"}
    if decision["decision"] != "approve":
        return {"status": "rejected", "ad": dataclasses.replace(ad, approved_by=None),
                "detail": f"rejected by {decision['by']}"}
    return {"status": "ready", "ad": dataclasses.replace(ad, approved_by=decision["by"]),
            "detail": f"approved by {decision['by']}"}


def creative_inputs_row(ad, *, ad_account_id, ad_id):
    """One row for brite-data-platform ANALYTICS.OPERATIONS.ADS_CREATIVE_INPUTS, written when
    the ad is published. creative_key is deterministic, so re-logging the same ad is a no-op
    upsert, and (platform, ad_account_id, ad_id) is the join to ad results."""
    if ad.ai_edited and not ad.approved_by:
        raise ValueError("an AI-edited ad without a recorded approval cannot be published")
    return {
        "creative_key": f"{ad.platform}:{ad_account_id}:{ad_id}",
        "ad_account_id": ad_account_id,
        "ad_id": ad_id,
        **asdict(ad),
    }


def _locked(template, rules):
    """The fonts and colors a template locks, each one checked against the brand rules."""
    fonts, colors = template.get("fonts") or [], template.get("colors") or []
    off = [f"font {f!r}" for f in fonts if f not in rules["fonts"]]
    off += [f"color {c!r}" for c in colors if c not in rules["palette"]]
    if not fonts or not colors or off:
        raise ValueError(f"template {template['id']} must lock brand fonts and colors; "
                         f"off-brand: {', '.join(off) or 'none'}")
    return {"fonts": list(fonts), "colors": {c: rules["palette"][c] for c in colors}}


# Digit groups joined by phone punctuation or single spaces: "(555) 010-0001", "+1 555.010.0001".
_NUMBER_RUN = re.compile(r"[\d()+.\-]+(?: [\d()+.\-]+)*")


def _phone_digits(s):
    d = re.sub(r"\D", "", s)
    # ponytail: US numbers only (+1 country code dropped); widen if a non-US territory appears.
    return d[1:] if len(d) == 11 and d.startswith("1") else d


def _numbers(text):
    return [n for n in (_phone_digits(m) for m in _NUMBER_RUN.findall(text)) if n]


def _text_problems(ad, text):
    """(check, detail) pairs for the text read off the render."""
    problems = []
    if " ".join(ad.headline.split()) not in " ".join(text.split()):
        problems.append(("text", f"headline {ad.headline!r} not found exactly"))
    want = _phone_digits(ad.phone)
    numbers = _numbers(text)
    if want not in numbers:
        problems.append(("text", f"tracking number {ad.phone} not found"))
    # Code places every number in the ad: the tracking number and any number in the headline.
    # Anything else is wrong. A phone-length number is another territory's or platform's number
    # or a misread; a shorter one is most likely a house number, a plate or a street sign.
    for n in _numbers(ad.headline) + [want]:
        if n in numbers:
            numbers.remove(n)
    for n in numbers:
        if len(n) >= 7:
            problems.append(("text", f"unexpected number {n}"))
        else:
            problems.append(("blocked", f"number {n} in the render: a house number, plate or sign"))
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
    # limit is calibrated on labelled ads. checks.max_color_distance in the rules is the knob.
    return sum((x - y) ** 2 for x, y in zip(_lab(a), _lab(b))) ** 0.5
