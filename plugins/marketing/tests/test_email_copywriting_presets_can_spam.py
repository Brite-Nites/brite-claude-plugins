"""Every email-copywriting preset must agree with the CAN-SPAM rule in SKILL.md.

Flow 1 of the skill reads one preset when a vertical is given, so a preset that
sets a `Re:` step-2 subject or ends a step body with the old name-only sign-off
makes the default way of authoring write the forbidden copy. The launch gate
would stop it, but the tooling should not produce it. Step 2 only goes to a
recipient who has not replied, so its subject carries no `Re:`; both step
bodies end with the company-name and postal-address sign-off.

String-contract tests over markdown; nothing here calls Email Bison.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

PRESETS_DIR = Path(__file__).resolve().parents[1] / "skills" / "email-copywriting" / "presets"
PRESETS = sorted(p for p in PRESETS_DIR.glob("*.md") if p.name != "README.md")

POSTAL_ADDRESS = "4080 S W Temple St, Ste A, Millcreek, UT 84107"
SIGNOFF_TAIL = f"{{SENDER_FIRST_NAME}}<br>[ENTITY_COMPANY_NAME]<br>{POSTAL_ADDRESS}"


def step(text: str, heading: str) -> str:
    m = re.search(rf"^## {heading}.*?(?=^## |\Z)", text, re.DOTALL | re.MULTILINE)
    assert m, f"no '## {heading}' section"
    return m.group(0)


def test_preset_set_is_not_empty() -> None:
    assert len(PRESETS) >= 28, "glob found too few presets; the other tests would pass vacuously"


@pytest.mark.parametrize("preset", PRESETS, ids=lambda p: p.stem)
def test_step2_subject_has_no_re_prefix(preset: Path) -> None:
    sub = re.search(r"^\*\*Subject:\*\* `(.*)`$", step(preset.read_text(encoding="utf-8"), "Step 2"), re.MULTILINE)
    assert sub, "step 2 has no **Subject:** line"
    assert not re.match(r"re:", sub.group(1), re.IGNORECASE), f"step-2 subject starts with Re: {sub.group(1)!r}"


@pytest.mark.parametrize("preset", PRESETS, ids=lambda p: p.stem)
def test_both_step_bodies_end_with_company_name_and_postal_address(preset: Path) -> None:
    text = preset.read_text(encoding="utf-8")
    for heading in ("Step 1", "Step 2"):
        body = step(text, heading).split("**Body:**", 1)[1].split("**wait_in_days:**", 1)[0].strip()
        assert body.endswith(SIGNOFF_TAIL), f"{heading} body does not end with the CAN-SPAM sign-off"
