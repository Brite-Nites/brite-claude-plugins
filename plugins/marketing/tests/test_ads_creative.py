"""Seam tests for the ads creative pipeline (BC-28221).

Three seams, all on fakes — no network, no keys:
1. make_ad: a territory + template + source photo reference in, a render request with the
   exact territory text, phone number and logo out (fake Placid / Hyperframes / ImageKit).
2. brand_check: passes a good ad, fails a bad one on each code check (fonts, colors,
   logo, text accuracy); the Claude judge sits behind a fake; an AI-edited ad always
   needs a person's approval.
3. creative_inputs_row: every ad's inputs become one creative-inputs row.

Every territory, number, id and URL here is made up. This repo is public: never put real
ad accounts, tracking numbers or client photos in a fixture.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_agent import creative  # noqa: E402

TERRITORIES = {
    "testville": {
        "name": "Testville",
        "phones": {"google_ads": "(555) 010-0001", "meta_ads": "(555) 010-0002"},
        "logo": "logo-fake-primary",
    },
}

RULES = {
    "fonts": ["Fake Sans"],
    "palette": ["#0B1F3A", "#F2C14E"],
    "max_color_distance": 10.0,
    "logos": {"logo-fake-primary": "https://example.invalid/logo-fake-primary.png"},
}

PLACID_TEMPLATE = {
    "id": "fake-holiday-hero-v1",
    "engine": "placid",
    "placid_uuid": "placid-fake-uuid",
    "headline": "Holiday lighting in {territory}",
}


class FakeImageKit:
    def __init__(self, photos):
        self.photos = photos

    def photo(self, file_id):
        return self.photos[file_id]


class FakeRenderer:
    """Stands in for Placid (create_image) and Hyperframes (render_video)."""

    def __init__(self, url="https://example.invalid/render-1.png"):
        self.requests = []
        self.url = url

    def create_image(self, payload):
        self.requests.append(payload)
        return {"id": "render-1", "image_url": self.url}

    def render_video(self, payload):
        self.requests.append(payload)
        return {"id": "video-1", "url": self.url}


APPROVED_PHOTOS = FakeImageKit(
    {"fake-photo-1": {"url": "https://example.invalid/fake-photo-1.jpg", "approved": True}}
)


@pytest.mark.parametrize(
    "platform, phone", [("google_ads", "(555) 010-0001"), ("meta_ads", "(555) 010-0002")]
)
def test_image_render_request_carries_exact_territory_text_phone_and_logo(platform, phone):
    placid = FakeRenderer()

    ad = creative.make_ad(
        territory="testville",
        template=PLACID_TEMPLATE,
        photo_id="fake-photo-1",
        platform=platform,
        territories=TERRITORIES,
        rules=RULES,
        photos=APPROVED_PHOTOS,
        renderers={"placid": placid},
    )

    assert placid.requests == [
        {
            "template_uuid": "placid-fake-uuid",
            "create_now": True,
            "layers": {
                "photo": {"image": "https://example.invalid/fake-photo-1.jpg"},
                "headline": {"text": "Holiday lighting in Testville"},
                "phone": {"text": phone},
                "logo": {"image": "https://example.invalid/logo-fake-primary.png"},
            },
        }
    ]
    assert ad.render_url == "https://example.invalid/render-1.png"
    assert ad.ai_edited is False


def test_photo_not_approved_in_brand_hub_is_refused_before_any_render():
    placid = FakeRenderer()
    draft = FakeImageKit(
        {"fake-photo-2": {"url": "https://example.invalid/fake-photo-2.jpg", "approved": False}}
    )

    with pytest.raises(ValueError, match="fake-photo-2"):
        creative.make_ad(
            territory="testville",
            template=PLACID_TEMPLATE,
            photo_id="fake-photo-2",
            platform="google_ads",
            territories=TERRITORIES,
            rules=RULES,
            photos=draft,
            renderers={"placid": placid},
        )
    assert placid.requests == []


def test_video_render_request_carries_the_same_exact_fields():
    hyperframes = FakeRenderer(url="https://example.invalid/video-1.mp4")
    template = {
        "id": "fake-holiday-video-v1",
        "engine": "hyperframes",
        "composition": "compositions/fake-holiday-15s.html",
        "headline": "Lights up in {territory}",
    }

    ad = creative.make_ad(
        territory="testville",
        template=template,
        photo_id="fake-photo-1",
        platform="meta_ads",
        territories=TERRITORIES,
        rules=RULES,
        photos=APPROVED_PHOTOS,
        renderers={"hyperframes": hyperframes},
    )

    assert hyperframes.requests == [
        {
            "composition": "compositions/fake-holiday-15s.html",
            "variables": {
                "photo": "https://example.invalid/fake-photo-1.jpg",
                "headline": "Lights up in Testville",
                "phone": "(555) 010-0002",
                "logo": "https://example.invalid/logo-fake-primary.png",
            },
        }
    ]
    assert (ad.render_engine, ad.render_url) == ("hyperframes", "https://example.invalid/video-1.mp4")


class FakeEditor:
    """Stands in for Vertex AI or Higgsfield."""

    model = "fake-editor:image-v1"

    def __init__(self):
        self.calls = []

    def edit(self, image_url, prompt, settings):
        self.calls.append((image_url, prompt, settings))
        return "https://example.invalid/fake-photo-1-edited.jpg"


def test_ai_edit_feeds_the_edited_photo_to_the_render_and_marks_the_ad():
    placid = FakeRenderer()
    editor = FakeEditor()

    ad = creative.make_ad(
        territory="testville",
        template=PLACID_TEMPLATE,
        photo_id="fake-photo-1",
        platform="google_ads",
        territories=TERRITORIES,
        rules=RULES,
        photos=APPROVED_PHOTOS,
        renderers={"placid": placid},
        edit={"editor": editor, "prompt": "extend the sky upward", "settings": {"seed": 7}},
    )

    assert editor.calls == [
        ("https://example.invalid/fake-photo-1.jpg", "extend the sky upward", {"seed": 7})
    ]
    assert placid.requests[0]["layers"]["photo"] == {
        "image": "https://example.invalid/fake-photo-1-edited.jpg"
    }
    assert (ad.ai_edited, ad.edit_model, ad.prompt, ad.settings, ad.approved_by) == (
        True, "fake-editor:image-v1", "extend the sky upward", {"seed": 7}, None
    )


# ── brand check ────────────────────────────────────────────────────────────


class FakeJudge:
    """Stands in for the Claude judge: taste only (look, legibility, layout, tone)."""

    def __init__(self, passed=True, reasons=()):
        self.verdict = {"pass": passed, "reasons": list(reasons)}
        self.calls = []

    def review(self, image_url, rules):
        self.calls.append(image_url)
        return self.verdict


def _ad(**overrides):
    import dataclasses

    ad = creative.make_ad(
        territory="testville",
        template=PLACID_TEMPLATE,
        photo_id="fake-photo-1",
        platform="google_ads",
        territories=TERRITORIES,
        rules=RULES,
        photos=APPROVED_PHOTOS,
        renderers={"placid": FakeRenderer()},
    )
    return dataclasses.replace(ad, **overrides)


# What an inspector (OCR, logo match, overlay colors) read off the finished render.
CLEAN = {
    "text": "Holiday lighting\nin Testville   Call (555) 010-0001",
    "fonts": ["Fake Sans"],
    "overlay_colors": ["#0B1F3A", "#F3C24F"],  # second is a hair off #F2C14E: within tolerance
    "logo": "logo-fake-primary",
}


def test_clean_ad_passes_and_the_judge_sees_the_render():
    judge = FakeJudge()

    verdict = creative.brand_check(_ad(), CLEAN, RULES, judge)

    assert verdict == {"status": "pass", "findings": []}
    assert judge.calls == ["https://example.invalid/render-1.png"]


def _checks(verdict):
    return [f["check"] for f in verdict["findings"]]


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
    verdict = creative.brand_check(_ad(), {**CLEAN, "text": text}, RULES, FakeJudge())

    assert verdict["status"] == "fix"
    assert "text" in _checks(verdict)


@pytest.mark.parametrize(
    "fonts", [["Fake Sans", "Comic Fake"], []], ids=["off-brand-font", "no-font-read"]
)
def test_font_outside_the_brand_rules_fails(fonts):
    verdict = creative.brand_check(_ad(), {**CLEAN, "fonts": fonts}, RULES, FakeJudge())

    assert verdict["status"] == "fix"
    assert _checks(verdict) == ["fonts"]


@pytest.mark.parametrize(
    "colors",
    [["#0B1F3A", "#E0302A"], ["#0B1F3A", "#C9A227"], []],
    ids=["red-overlay", "muddier-gold", "no-color-read"],
)
def test_overlay_color_off_the_palette_fails(colors):
    verdict = creative.brand_check(_ad(), {**CLEAN, "overlay_colors": colors}, RULES, FakeJudge())

    assert verdict["status"] == "fix"
    assert _checks(verdict) == ["colors"]


@pytest.mark.parametrize("logo", [None, "logo-fake-retired"], ids=["missing", "wrong-variant"])
def test_logo_missing_or_not_the_territory_variant_fails(logo):
    verdict = creative.brand_check(_ad(), {**CLEAN, "logo": logo}, RULES, FakeJudge())

    assert verdict["status"] == "fix"
    assert _checks(verdict) == ["logo"]


def test_judge_failure_goes_back_for_a_fix_with_its_reasons():
    judge = FakeJudge(passed=False, reasons=["headline unreadable over the roofline"])

    verdict = creative.brand_check(_ad(), CLEAN, RULES, judge)

    assert verdict == {
        "status": "fix",
        "findings": [{"check": "judge", "detail": "headline unreadable over the roofline"}],
    }


def test_judge_is_not_paid_for_when_a_code_check_already_failed():
    judge = FakeJudge()

    creative.brand_check(_ad(), {**CLEAN, "logo": None}, RULES, judge)

    assert judge.calls == []


def test_ai_edited_ad_waits_for_a_person_even_when_every_check_passes():
    ad = _ad(ai_edited=True, edit_model="fake-editor:image-v1", prompt="extend the sky upward")

    verdict = creative.brand_check(ad, CLEAN, RULES, FakeJudge())

    assert verdict["status"] == "needs_human"
    assert _checks(verdict) == ["human_approval"]


def test_ai_edited_ad_that_fails_a_code_check_goes_back_still_flagged_for_a_person():
    ad = _ad(ai_edited=True, edit_model="fake-editor:image-v1", prompt="extend the sky upward")

    verdict = creative.brand_check(ad, {**CLEAN, "logo": None}, RULES, FakeJudge())

    assert verdict["status"] == "fix"
    assert sorted(_checks(verdict)) == ["human_approval", "logo"]


def test_ai_edited_ad_passes_once_a_person_approved_it():
    ad = _ad(ai_edited=True, edit_model="fake-editor:image-v1", approved_by="fake.reviewer")

    assert creative.brand_check(ad, CLEAN, RULES, FakeJudge()) == {"status": "pass", "findings": []}


# ── creative-inputs row ────────────────────────────────────────────────────


def test_every_published_ad_becomes_one_creative_inputs_row_keyed_to_the_platform_ad():
    import dataclasses

    ad = creative.make_ad(
        territory="testville",
        template=PLACID_TEMPLATE,
        photo_id="fake-photo-1",
        platform="google_ads",
        territories=TERRITORIES,
        rules=RULES,
        photos=APPROVED_PHOTOS,
        renderers={"placid": FakeRenderer()},
        edit={"editor": FakeEditor(), "prompt": "extend the sky upward", "settings": {"seed": 7}},
    )
    ad = dataclasses.replace(ad, approved_by="fake.reviewer")

    row = creative.creative_inputs_row(ad, ad_account_id="fake-acct-1", ad_id="fake-ad-1")

    assert row == {
        "creative_key": "google_ads:fake-acct-1:fake-ad-1",
        "platform": "google_ads",
        "ad_account_id": "fake-acct-1",
        "ad_id": "fake-ad-1",
        "territory": "testville",
        "template_id": "fake-holiday-hero-v1",
        "render_engine": "placid",
        "source_photo_id": "fake-photo-1",
        "headline": "Holiday lighting in Testville",
        "phone": "(555) 010-0001",
        "logo_id": "logo-fake-primary",
        "render_id": "render-1",
        "render_url": "https://example.invalid/render-1.png",
        "ai_edited": True,
        "edit_model": "fake-editor:image-v1",
        "prompt": "extend the sky upward",
        "settings": {"seed": 7},
        "approved_by": "fake.reviewer",
    }
