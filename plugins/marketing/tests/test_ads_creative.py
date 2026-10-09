"""Seam tests for the ads creative pipeline (BC-28221 slice 1, BC-28299 slice 2).

All on fakes (scripts/ads_agent/fakes.py) — no network, no keys:
1. make_ad: a site + city + template + source photo in, a render request with the exact city
   text, phone number and logo out. An AI edit is stored in the ads folder, tagged AI-edited.
2. brand_check: reads the finished render itself (text recognition, a pixel read, the Claude
   review) and checks it against the template's locked fonts and colors; blocks house
   numbers, license plates and faces.
3. mark_ready: an AI-edited ad is ready only after a recorded Slack approval.
4. creative_inputs_row: one row per published ad, naming every AI tool that touched it and
   the platform's creative settings.
Plus the brand rules file, the territory table, and the real adapters' requests (urlopen and
the Anthropic client are stubbed, so nothing leaves the machine).

Every territory, number, id and URL here is made up. This repo is public: never put real
ad accounts, tracking numbers or client photos in a fixture.
"""

from __future__ import annotations

import dataclasses
import io
import json
import re
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_agent import creative, creative_adapters  # noqa: E402
from ads_agent.fakes import (  # noqa: E402
    FakeEditor,
    FakeImageKit,
    FakeInspector,
    FakeJudge,
    FakeOCR,
    FakeRenderer,
    FakeSlackApprovals,
)

DATA = Path(__file__).resolve().parents[1] / "data" / "ads-creative"
RULES = creative.load_brand_rules()
TERRITORIES = creative.load_territories(DATA / "territories.example.json")

NIGHT_TEMPLATE = {
    "id": "fake-night-hero-v1",
    "engine": "placid",
    "placid_uuid": "placid-fake-uuid",
    "headline": "Holiday lighting in {city}",
    "fonts": ["GT Eesti", "Peclet"],
    "colors": ["Deep Blue", "Sky Blue"],
}
LOCKED = {"fonts": ["GT Eesti", "Peclet"], "colors": {"Deep Blue": "#272E41", "Sky Blue": "#C6D8E5"}}
LOGO_URL = "https://example.invalid/logos/logo-example-lockup.png"
LIBRARY = {"fake-photo-1": {"url": "https://example.invalid/fake-photo-1.jpg", "approved": True}}


def _make(*, template=NIGHT_TEMPLATE, platform="google_ads", photos=None, renderers=None, **kw):
    return creative.make_ad(
        site="example-north",
        template=template,
        photo_id=kw.pop("photo_id", "fake-photo-1"),
        platform=platform,
        territories=TERRITORIES,
        rules=RULES,
        photos=photos or FakeImageKit(LIBRARY),
        renderers=renderers or {"placid": FakeRenderer()},
        **kw,
    )


# ── make_ad ────────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "platform, phone", [("google_ads", "(555) 010-0001"), ("meta_ads", "(555) 010-0002")]
)
def test_image_render_request_carries_exact_city_text_phone_and_logo(platform, phone):
    placid = FakeRenderer()

    ad = _make(platform=platform, renderers={"placid": placid})

    assert placid.requests == [
        {
            "template_uuid": "placid-fake-uuid",
            "create_now": True,
            "layers": {
                "photo": {"image": "https://example.invalid/fake-photo-1.jpg"},
                "headline": {"text": "Holiday lighting in Testville"},
                "phone": {"text": phone},
                "logo": {"image": LOGO_URL},
            },
        }
    ]
    assert (ad.territory, ad.logo_id, ad.render_url) == (
        "Exampleland", "logo-example-lockup", "https://example.invalid/render-1.png"
    )
    assert ad.ai_edited is False


def test_city_picks_which_of_the_sites_cities_the_headline_names():
    assert _make(city="Sampleton").headline == "Holiday lighting in Sampleton"
    with pytest.raises(ValueError, match="Placeholder Springs"):
        _make(city="Placeholder Springs")  # a city of another site


def test_photo_not_approved_in_brand_hub_is_refused_before_any_render():
    placid = FakeRenderer()
    draft = FakeImageKit({"fake-photo-2": {"url": "https://example.invalid/fake-photo-2.jpg", "approved": False}})

    with pytest.raises(ValueError, match="fake-photo-2"):
        _make(photo_id="fake-photo-2", photos=draft, renderers={"placid": placid})
    assert placid.requests == []


@pytest.mark.parametrize(
    "locks", [{"fonts": ["Comic Fake"]}, {"colors": ["Deep Blue", "Red"]}, {"fonts": []}],
    ids=["off-brand-font", "off-brand-color", "no-font-locked"],
)
def test_template_that_does_not_lock_brand_fonts_and_colors_is_refused_before_any_render(locks):
    placid = FakeRenderer()

    with pytest.raises(ValueError, match="fake-night-hero-v1"):
        _make(template={**NIGHT_TEMPLATE, **locks}, renderers={"placid": placid})
    assert placid.requests == []


def test_video_render_request_carries_the_same_exact_fields():
    hyperframes = FakeRenderer(url="https://example.invalid/video-1.mp4")
    template = {
        "id": "fake-night-video-v1",
        "engine": "hyperframes",
        "composition": "compositions/fake-holiday-15s.html",
        "headline": "Lights up in {city}",
        "fonts": ["GT Eesti"],
        "colors": ["Deep Blue", "Sky Blue"],
    }

    ad = _make(template=template, platform="meta_ads", renderers={"hyperframes": hyperframes})

    assert hyperframes.requests == [
        {
            "composition": "compositions/fake-holiday-15s.html",
            "variables": {
                "photo": "https://example.invalid/fake-photo-1.jpg",
                "headline": "Lights up in Testville",
                "phone": "(555) 010-0002",
                "logo": LOGO_URL,
            },
        }
    ]
    assert (ad.render_engine, ad.render_url) == ("hyperframes", "https://example.invalid/video-1.mp4")


# ── BC-28299 a: AI edits go to their own ImageKit folder, tagged AI-edited ──


def test_ai_edit_is_stored_in_the_ads_folder_tagged_ai_edited_and_never_in_the_library():
    photos = FakeImageKit(LIBRARY)
    placid = FakeRenderer()
    editor = FakeEditor()

    ad = _make(photos=photos, renderers={"placid": placid},
               edit={"editor": editor, "prompt": "extend the sky upward", "settings": {"seed": 7}})

    assert editor.calls == [("https://example.invalid/fake-photo-1.jpg", "extend the sky upward", {"seed": 7})]
    assert photos.uploads == [{
        "source_url": "https://example.invalid/editor-output/fake-photo-1-edited.jpg",
        "file_name": "fake-photo-1-ai-edited",
        "folder": "/ads/ai-edited/",
        "tags": ["AI-edited"],
    }]
    assert photos.library == LIBRARY  # brand-hub's approved library is untouched
    # The render uses the stored copy, not the editor's temporary output.
    assert placid.requests[0]["layers"]["photo"] == {
        "image": "https://example.invalid/ads/ai-edited/fake-photo-1-ai-edited.jpg"
    }
    assert (ad.ai_edited, ad.source_photo_id, ad.approved_by) == (True, "fake-photo-1", None)


def test_a_stored_ai_edit_can_never_pass_as_an_approved_source_photo():
    photos = FakeImageKit(LIBRARY)
    _make(photos=photos, edit={"editor": FakeEditor(), "prompt": "extend the sky upward"})

    with pytest.raises(ValueError, match="not approved"):
        _make(photos=photos, photo_id="fake-upload-1")


class _Reply(io.BytesIO):
    """What urlopen returns: a context manager over the JSON body."""


def _stub_urlopen(monkeypatch, *bodies):
    sent = []
    replies = iter(bodies)

    def urlopen(req, timeout):
        sent.append(req)
        return _Reply(json.dumps(next(replies)).encode())

    monkeypatch.setattr(creative_adapters.urllib.request, "urlopen", urlopen)
    return sent


def test_real_imagekit_upload_writes_only_to_the_ads_folder_with_the_ai_edited_tag(monkeypatch):
    sent = _stub_urlopen(monkeypatch, {"fileId": "fake-file-9", "url": "https://example.invalid/ads/ai-edited/x.jpg"})
    imagekit = creative_adapters.ImageKitPhotos(private_key="fake-key")

    stored = imagekit.upload_ai_edit("https://example.invalid/edited.jpg", file_name="fake-photo-1-ai-edited")

    assert stored == {"file_id": "fake-file-9", "url": "https://example.invalid/ads/ai-edited/x.jpg"}
    [req] = sent
    body = req.data.decode()
    fields = dict(re.findall(r'name="([^"]+)"\r\n\r\n([^\r]*)\r\n', body))
    assert (req.full_url, req.get_method()) == ("https://upload.imagekit.io/api/v1/files/upload", "POST")
    assert fields == {
        "file": "https://example.invalid/edited.jpg",
        "fileName": "fake-photo-1-ai-edited",
        "folder": "/ads/ai-edited/",
        "tags": "AI-edited",
        "useUniqueFileName": "true",
    }  # no customMetadata: an upload never carries brand-hub's approval_status


# ── BC-28299 b: the brand check reads the finished render ──────────────────

CLEAN_TEXT = "Holiday lighting\nin Testville   Call (555) 010-0001"
CLEAN_COLORS = ["#272E41", "#C7D9E6"]  # second is a hair off Sky Blue: within tolerance


def _readers(text=CLEAN_TEXT, confidence=0.98, colors=CLEAN_COLORS, logo="logo-example-lockup", judge=None):
    return {
        "ocr": FakeOCR(text, confidence),
        "inspector": FakeInspector(colors, logo),
        "judge": judge or FakeJudge(),
    }


def _check(ad, template=NIGHT_TEMPLATE, **kw):
    return creative.brand_check(ad, template, RULES, **_readers(**kw))


def _checks(verdict):
    return [f["check"] for f in verdict["findings"]]


def test_clean_ad_passes_and_every_reader_reads_the_finished_render():
    ad = _make()
    readers = _readers()

    verdict = creative.brand_check(ad, NIGHT_TEMPLATE, RULES, **readers)

    assert verdict == {"status": "pass", "findings": []}
    assert readers["ocr"].calls == readers["inspector"].calls == [ad.render_url]
    # The Claude review gets the template's locked fonts and colors, not the whole palette.
    assert readers["judge"].calls == [(ad.render_url, LOCKED)]


@pytest.mark.parametrize(
    "text",
    [
        pytest.param("Holiday lighting in Testville   Call (555) 010-0002", id="other-platform-number"),
        pytest.param("Holiday lighting in Testville   Call (555) 010-0001  (555) 010-0009", id="extra-number"),
        pytest.param("Holiday lighting in Testville   Call (555) 010-001", id="number-misread"),
        pytest.param("Holiday lighting in Testvile   Call (555) 010-0001", id="headline-typo"),
    ],
)
def test_text_that_does_not_match_the_build_record_fails(text):
    verdict = _check(_make(), text=text)

    assert verdict["status"] == "fix"
    assert "text" in _checks(verdict)


def test_text_read_at_low_confidence_fails():
    verdict = _check(_make(), confidence=0.6)

    assert (verdict["status"], _checks(verdict)) == ("fix", ["text"])


@pytest.mark.parametrize(
    "template, fonts",
    [
        ({**NIGHT_TEMPLATE, "fonts": ["GT Eesti"]}, ["GT Eesti", "Peclet"]),
        (NIGHT_TEMPLATE, ["GT Eesti", "other"]),
        (NIGHT_TEMPLATE, []),
    ],
    ids=["brand-font-the-template-does-not-lock", "not-a-locked-font", "no-font-named"],
)
def test_font_the_template_does_not_lock_fails(template, fonts):
    verdict = _check(_make(template=template), template=template, judge=FakeJudge(fonts=fonts))

    assert verdict["status"] == "fix"
    assert _checks(verdict) == ["fonts"]


@pytest.mark.parametrize(
    "colors",
    [["#272E41", "#E0302A"], ["#272E41", "#C24600"], []],
    ids=["red-overlay", "brand-color-the-template-does-not-lock", "no-color-read"],
)
def test_overlay_color_the_template_does_not_lock_fails(colors):
    verdict = _check(_make(), colors=colors)

    assert verdict["status"] == "fix"
    assert _checks(verdict) == ["colors"]


@pytest.mark.parametrize("logo", [None, "logo-fake-retired"], ids=["missing", "wrong-variant"])
def test_logo_missing_or_not_the_sites_logo_fails(logo):
    verdict = _check(_make(), logo=logo)

    assert (verdict["status"], _checks(verdict)) == ("fix", ["logo"])


def test_judge_failure_goes_back_for_a_fix_with_its_reasons():
    verdict = _check(_make(), judge=FakeJudge(passed=False, reasons=["headline unreadable over the roofline"]))

    assert verdict == {
        "status": "fix",
        "findings": [{"check": "judge", "detail": "headline unreadable over the roofline"}],
    }


def test_judge_is_not_paid_for_when_a_code_check_already_failed():
    judge = FakeJudge()

    _check(_make(), logo=None, judge=judge)

    assert judge.calls == []


# ── amendment 4a: house numbers, license plates and faces are blocked ──────


@pytest.mark.parametrize(
    "kind, detail",
    [("face", "a person at the left window"), ("license_plate", "a car in the driveway"),
     ("house_number", "numerals beside the front door")],
)
def test_review_that_sees_a_face_plate_or_house_number_blocks_the_ad(kind, detail):
    verdict = _check(_make(), judge=FakeJudge(blocked=[{"kind": kind, "detail": detail}]))

    assert verdict == {"status": "fix", "findings": [{"check": "blocked", "detail": f"{kind}: {detail}"}]}


def test_house_number_read_off_the_photo_blocks_the_ad_before_the_review_runs():
    judge = FakeJudge()

    verdict = _check(_make(), text=CLEAN_TEXT + "\n1428", judge=judge)

    assert (verdict["status"], _checks(verdict)) == ("fix", ["blocked"])
    assert judge.calls == []


def test_a_number_the_template_placed_in_the_headline_is_not_blocked():
    template = {**NIGHT_TEMPLATE, "headline": "Lighting {city} since 1993"}

    verdict = _check(_make(template=template), template=template,
                     text="Lighting Testville since 1993\nCall (555) 010-0001")

    assert verdict == {"status": "pass", "findings": []}


def test_real_judge_asks_for_fonts_and_blocked_content_and_gets_the_locked_set():
    calls = []
    verdict = {"pass": True, "reasons": [], "fonts": ["GT Eesti"], "blocked": []}

    def create(**kwargs):
        calls.append(kwargs)
        return SimpleNamespace(stop_reason="end_turn",
                               content=[SimpleNamespace(type="text", text=json.dumps(verdict))])

    client = SimpleNamespace(beta=SimpleNamespace(messages=SimpleNamespace(create=create)))

    assert creative_adapters.ClaudeJudge(client=client).review("https://example.invalid/r.png", RULES, LOCKED) == verdict
    schema = calls[0]["output_config"]["format"]["schema"]
    assert schema["required"] == ["pass", "reasons", "fonts", "blocked"]
    assert schema["properties"]["blocked"]["items"]["properties"]["kind"]["enum"] == [
        "face", "house_number", "license_plate"
    ]
    assert json.dumps(LOCKED, sort_keys=True) in calls[0]["messages"][0]["content"][1]["text"]


# ── BC-28299 e: an AI-edited ad is ready only after a recorded approval ────


def _ai_ad():
    return _make(edit={"editor": FakeEditor(), "prompt": "extend the sky upward"})


def test_ai_edited_ad_waits_for_the_head_of_gtm_then_is_ready_with_approved_by():
    ad = _ai_ad()
    check = _check(ad)
    slack = FakeSlackApprovals()

    request_id = creative.request_approval(ad, slack)

    assert check["status"] == "needs_human"
    assert slack.requests[0]["image_url"] == ad.render_url
    assert "Reply approve or reject" in slack.requests[0]["text"]
    assert creative.mark_ready(ad, check, approvals=slack, request_id=request_id)["status"] == "waiting"

    slack.reply(request_id, "Approve", by="fake.head-of-gtm")
    result = creative.mark_ready(ad, check, approvals=slack, request_id=request_id)

    assert (result["status"], result["ad"].approved_by) == ("ready", "fake.head-of-gtm")


def test_a_rejected_ai_edited_ad_is_never_ready():
    ad, slack = _ai_ad(), FakeSlackApprovals()
    request_id = creative.request_approval(ad, slack)
    slack.reply(request_id, "reject", by="fake.head-of-gtm")

    result = creative.mark_ready(ad, _check(ad), approvals=slack, request_id=request_id)

    assert (result["status"], result["ad"].approved_by) == ("rejected", None)


def test_an_approve_from_anyone_but_the_head_of_gtm_does_not_count():
    ad, slack = _ai_ad(), FakeSlackApprovals()
    request_id = creative.request_approval(ad, slack)
    slack.reply(request_id, "approve", by="fake.someone-else")

    assert creative.mark_ready(ad, _check(ad), approvals=slack, request_id=request_id)["status"] == "waiting"


def test_approved_by_set_by_hand_without_a_recorded_approval_is_not_ready_or_publishable():
    ad = dataclasses.replace(_ai_ad(), approved_by="fake.hand-typed")
    check = _check(ad)

    result = creative.mark_ready(ad, check)

    assert check["status"] == "pass"  # the brand check trusts approved_by; the ready gate does not
    assert (result["status"], result["ad"].approved_by) == ("waiting", None)
    with pytest.raises(ValueError, match="recorded approval"):
        creative.creative_inputs_row(result["ad"], ad_account_id="fake-acct-1", ad_id="fake-ad-1")


def test_a_failed_brand_check_is_never_ready_even_when_approved():
    ad, slack = _ai_ad(), FakeSlackApprovals()
    request_id = creative.request_approval(ad, slack)
    slack.reply(request_id, "approve", by="fake.head-of-gtm")

    result = creative.mark_ready(ad, _check(ad, logo=None), approvals=slack, request_id=request_id)

    assert result["status"] == "fix"


def test_an_ad_with_no_ai_edit_is_ready_on_a_passing_check_without_slack():
    ad = _make()

    assert creative.mark_ready(ad, _check(ad))["status"] == "ready"
    with pytest.raises(ValueError, match="only an AI-edited ad"):
        creative.request_approval(ad, FakeSlackApprovals())


def test_real_slack_approvals_count_only_the_approvers_reply(monkeypatch):
    sent = _stub_urlopen(
        monkeypatch,
        {"ok": True, "channel": "D-FAKE", "ts": "1700000000.000100"},
        {"ok": True, "messages": [
            {"user": "U-FAKE-BOT", "text": "AI-edited ad to approve"},
            {"user": "U-FAKE-OTHER", "text": "approve"},
            {"user": "U-FAKE-GTM", "text": "Reject"},
        ]},
    )
    slack = creative_adapters.SlackApprovals("U-FAKE-GTM", "fake.head-of-gtm", token="fake-token")

    request_id = slack.request("AI-edited ad to approve", "https://example.invalid/r.png")
    decision = slack.decision(request_id)

    assert request_id == "D-FAKE:1700000000.000100"
    assert decision == {"decision": "reject", "by": "fake.head-of-gtm"}
    assert sent[0].full_url == "https://slack.com/api/chat.postMessage"
    assert json.loads(sent[0].data)["channel"] == "U-FAKE-GTM"
    assert sent[1].full_url == "https://slack.com/api/conversations.replies?channel=D-FAKE&ts=1700000000.000100"


# ── BC-28299 c: the brand rules file ───────────────────────────────────────


def test_brand_rules_file_is_machine_readable_and_cites_the_book_page_of_every_value():
    assert RULES["palette"] == {
        "Yellow Cream": "#F9EBC9", "Vibrant Orange": "#EA8105", "Orange Red": "#C24600",
        "Sky Blue": "#C6D8E5", "Vibrant Blue": "#3A559D", "Deep Blue": "#272E41",
        "White": "#FBFBFA", "Black": "#131315",
    }
    assert set(RULES["fonts"]) == {"GT Eesti", "Peclet"}
    assert RULES["logo"]["clear_space_ratio"] == 0.5
    assert len(RULES["color_rules"]["text_pairings"]) == len(RULES["logo"]["pairings"]) == 6

    uncited = [
        line for line in creative.BRAND_RULES_PATH.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith(("#", "[")) and line.strip() != "]"
        and not line.rstrip().endswith("[") and not line.startswith("brand =")
        and not re.search(r"#\s*(p\d+|pipeline setting)", line)
    ]
    assert uncited == []


def test_brand_rules_that_name_a_color_outside_the_palette_are_refused(tmp_path):
    bad = tmp_path / "rules.toml"
    bad.write_text(creative.BRAND_RULES_PATH.read_text().replace(
        '{ text = "Sky Blue", ground = "Deep Blue" }', '{ text = "Sky Blue", ground = "Navy" }'))

    with pytest.raises(ValueError, match="'Navy' is not in the palette"):
        creative.load_brand_rules(bad)


# ── BC-28299 d: the territory table comes from the private runner config ───


def test_territory_table_is_read_from_the_path_in_the_runner_config(tmp_path):
    private = tmp_path / "territories.json"
    private.write_text(json.dumps({"sites": [{
        "site": "fake-private-site", "territory": "Fakeland", "cities": ["Fakeburg"],
        "phones": {"google_ads": "(555) 010-0091", "meta_ads": "(555) 010-0092"},
        "logo": {"id": "logo-fake", "url": "https://example.invalid/logo-fake.png"},
    }]}))
    runner_config = {"territories_path": str(private)}

    territories = creative.load_territories(runner_config["territories_path"])
    ad = creative.make_ad(site="fake-private-site", template=NIGHT_TEMPLATE, photo_id="fake-photo-1",
                          platform="meta_ads", territories=territories, rules=RULES,
                          photos=FakeImageKit(LIBRARY), renderers={"placid": FakeRenderer()})

    assert (ad.territory, ad.headline, ad.phone) == ("Fakeland", "Holiday lighting in Fakeburg", "(555) 010-0092")


def test_public_example_matches_the_schema_and_holds_only_fictional_555_010_numbers():
    example = json.loads((DATA / "territories.example.json").read_text())
    schema = json.loads((DATA / "territories.schema.json").read_text())

    phones = [p for s in example["sites"] for p in s["phones"].values()]
    assert phones and all(re.fullmatch(r"\(555\) 010-\d{4}", p) for p in phones)
    site = schema["$defs"]["site"]
    assert site["required"] == list(creative._SITE_KEYS)
    assert site["properties"]["phones"]["required"] == list(creative.PLATFORMS)
    assert set(TERRITORIES) == {"example-north", "example-south"}


@pytest.mark.parametrize(
    "break_it, problem",
    [
        (lambda s: s["phones"].pop("meta_ads"), "phones must have exactly"),
        (lambda s: s["phones"].update(google_ads="555-010-0001"), "phones.google_ads is not written"),
        (lambda s: s.update(region="extra"), "keys must be exactly"),
        (lambda s: s.update(cities=[]), "cities must be"),
        (lambda s: s["logo"].update(url="http://example.invalid/x.png"), "https url"),
    ],
    ids=["missing-platform", "phone-format", "unknown-key", "no-cities", "logo-not-https"],
)
def test_territory_file_that_breaks_the_schema_is_refused_without_echoing_numbers(tmp_path, break_it, problem):
    doc = json.loads((DATA / "territories.example.json").read_text())
    break_it(doc["sites"][0])
    path = tmp_path / "territories.json"
    path.write_text(json.dumps(doc))

    with pytest.raises(ValueError, match=problem) as err:
        creative.load_territories(path)
    assert "010-" not in str(err.value)


def test_a_site_listed_twice_is_refused(tmp_path):
    doc = json.loads((DATA / "territories.example.json").read_text())
    doc["sites"].append(doc["sites"][0])
    path = tmp_path / "territories.json"
    path.write_text(json.dumps(doc))

    with pytest.raises(ValueError, match="appears twice"):
        creative.load_territories(path)


# ── amendment 4b: the creative-inputs row ──────────────────────────────────


def test_row_records_every_ai_tool_that_touched_the_ad_and_the_platform_creative_settings():
    platform_settings = {
        "ai_features": {"text_improvements": False, "image_expansion": True},
        "format": "single_image",
    }
    ad = _make(platform="meta_ads", platform_settings=platform_settings,
               edit={"editor": FakeEditor(), "prompt": "extend the sky upward", "settings": {"seed": 7}})
    ad = dataclasses.replace(ad, approved_by="fake.head-of-gtm")

    row = creative.creative_inputs_row(ad, ad_account_id="fake-acct-1", ad_id="fake-ad-1")

    assert row == {
        "creative_key": "meta_ads:fake-acct-1:fake-ad-1",
        "platform": "meta_ads",
        "ad_account_id": "fake-acct-1",
        "ad_id": "fake-ad-1",
        "territory": "Exampleland",
        "template_id": "fake-night-hero-v1",
        "render_engine": "placid",
        "source_photo_id": "fake-photo-1",
        "headline": "Holiday lighting in Testville",
        "phone": "(555) 010-0002",
        "logo_id": "logo-example-lockup",
        "render_id": "render-1",
        "render_url": "https://example.invalid/render-1.png",
        "ai_edited": True,
        "edit_model": "fake-editor:image-v1, meta_ads:image_expansion",
        "prompt": "extend the sky upward",
        "settings": {"edit": {"seed": 7}, "platform": platform_settings},
        "approved_by": "fake.head-of-gtm",
    }


def test_row_for_an_ad_no_ai_touched_has_no_edit_model_and_records_the_settings_anyway():
    ad = _make(platform_settings={"ai_features": {"image_enhancement": False}})

    row = creative.creative_inputs_row(ad, ad_account_id="fake-acct-1", ad_id="fake-ad-2")

    assert (row["ai_edited"], row["edit_model"], row["approved_by"]) == (False, None, None)
    assert row["settings"] == {"edit": {}, "platform": {"ai_features": {"image_enhancement": False}}}
