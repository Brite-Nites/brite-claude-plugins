"""Contract tests for the CAN-SPAM launch gate in /marketing:launch-campaign.

Cold outbound went out with no unsubscribe toggle, no postal address and a `Re:`
subject on step 2. The command, the email-bison skill and the outbound skill
template now refuse to launch a campaign that is missing any of them. These
tests pin the markdown contract; the commands are Claude-orchestrated, so
nothing here executes a launch (and nothing calls Email Bison).

Same shape as test_plan_campaign_contracts.py. Run with
`python3 -m pytest plugins/marketing/tests/`.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "launch-campaign.md"
SKILL_PATH = ROOT / "skills" / "email-bison" / "SKILL.md"
INTEGRATION_PATH = ROOT / "tools" / "integrations" / "email-bison.md"
TEMPLATE_PATH = ROOT / "skills" / "_template" / "OUTBOUND-SKILL-TEMPLATE.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"

POSTAL_ADDRESS = "4080 S W Temple St, Ste A, Millcreek, UT 84107"
GATE_HEADING = "## CAN-SPAM compliance gate"
# The stop message every missing item is reported through.
STOP_MESSAGE = "CAN-SPAM gate: launch stopped. Missing:"


@lru_cache(maxsize=None)
def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def section(text: str, start: str, end: str) -> str:
    """Text from `start` up to the next `end` marker; both must exist."""
    i = text.find(start)
    if i < 0:
        raise AssertionError(f"section start not found: {start!r}")
    j = text.find(end, i + len(start))
    if j < 0:
        raise AssertionError(f"section end not found: {end!r} after {start!r}")
    return text[i:j]


def gate() -> str:
    return section(read(COMMAND_PATH), GATE_HEADING, "\n## ")


def phase(n: str, nxt: str) -> str:
    return section(read(COMMAND_PATH), f"## Phase {n} ", f"\n## Phase {nxt} ")


def json_blocks(text: str) -> list[str]:
    # Fences inside numbered list items are indented, so allow leading spaces on the closer.
    return re.findall(r"```json\n(.*?)\n[ \t]*```", text, re.DOTALL)


# --- The gate section -------------------------------------------------------


def test_gate_section_names_all_three_requirements() -> None:
    g = gate()
    assert "can_unsubscribe: true" in g, "gate must require can_unsubscribe: true"
    assert POSTAL_ADDRESS in g, "gate must carry the exact postal address"
    assert "company name" in g.lower(), "gate must require the company name in the footer"
    assert "thread_reply" in g and "Re:" in g, "gate must state the step-2 subject rule"
    assert "has not replied" in g, "step-2 rule is scoped to a recipient who has not replied"


def test_gate_stop_message_names_what_is_missing() -> None:
    g = gate()
    assert STOP_MESSAGE in g, f"gate must define the stop message {STOP_MESSAGE!r}"
    for item in ("can_unsubscribe", "footer", "step 2 subject"):
        assert item in g.lower(), f"stop message must be able to name {item!r}"


def test_gate_has_no_operator_opt_out() -> None:
    g = gate()
    assert "no operator opt-out" in g.lower()
    assert "--skip-compliance" not in read(COMMAND_PATH)
    assert "--no-footer" not in read(COMMAND_PATH)


def test_gate_runs_in_phase_1_before_any_mutation() -> None:
    p1 = phase("1", "1b")
    assert "CAN-SPAM compliance gate" in p1, "Phase 1 must run the gate (read-only, pre-mutation)"
    assert "step_1.body" in gate() and "step_2.body" in gate(), "footer is checked in BOTH step bodies"


# --- can_unsubscribe at Phase 5 ---------------------------------------------


def test_phase5_patch_sends_plain_text_and_can_unsubscribe_in_one_body() -> None:
    p5 = phase("5", "6")
    bodies = [b for b in json_blocks(p5) if '"plain_text": true' in b]
    assert bodies, "Phase 5 must show the PATCH body as a json block"
    assert any('"can_unsubscribe": true' in b for b in bodies), (
        "plain_text and can_unsubscribe must be sent in the SAME PATCH body so "
        "neither resets the other (EB treats an omitted boolean as false)"
    )
    assert "same body" in p5.lower() or "same patch" in p5.lower()


def test_phase5_no_longer_claims_a_single_plain_text_patch() -> None:
    p5 = phase("5", "6")
    assert "single `plain_text: true` PATCH" not in p5, (
        "stale wording: the PATCH now carries both booleans"
    )
    assert "re-send" in p5.lower() and "can_unsubscribe: true" in p5


def test_phase5_applies_to_reused_campaigns_and_reads_back() -> None:
    p5 = phase("5", "6")
    assert "reused" in p5.lower() and "can_unsubscribe" in p5
    assert "get_campaign" in p5
    assert re.search(r"read.?back", p5, re.IGNORECASE), "PATCH result must be read back"
    assert STOP_MESSAGE in p5 or "CAN-SPAM compliance gate" in p5, (
        "a campaign whose can_unsubscribe is not true after the PATCH stops the launch"
    )


def test_phase5_gate_prompt_discloses_can_unsubscribe() -> None:
    p5 = phase("5", "6")
    gate5 = section(p5, "**User gate 5.**", "6. **Execute creates")
    assert "can_unsubscribe: true" in gate5


# --- footer + step-2 subject at Phase 9 -------------------------------------


def test_phase9_requires_footer_in_every_step_body() -> None:
    p9 = phase("9", "10")
    assert POSTAL_ADDRESS in p9
    assert "company name" in p9.lower()
    assert "step_1.body" in p9 and "step_2.body" in p9
    assert STOP_MESSAGE in p9 or "CAN-SPAM compliance gate" in p9


def test_phase9_step2_threads_with_subject_that_carries_no_re() -> None:
    p9 = phase("9", "10")
    body = section(p9, "3. **Build the request body.**", "4. **Show sequence plan.**")
    blocks = json_blocks(body)
    assert blocks and '"thread_reply": true' in blocks[0], "step 2 keeps reply-in-thread on"
    assert "has not replied" in p9
    stale = "the artifact's bare step_2.subject becomes `\"Re: <subject>\"` in the recipient's inbox"
    assert stale not in p9, "stale claim: step 2 must NOT be documented as delivering `Re:`"


def test_phase9_verifies_stored_steps_not_just_the_request() -> None:
    p9 = phase("9", "10")
    verify = section(p9, "7. **Verify per campaign.**", "8. **Append to metadata JSON.**")
    for needle in ("footer", "thread_reply", "Re:"):
        assert needle in verify, f"Phase 9 step 7 read-back must check {needle!r}"


# --- activation + metadata ---------------------------------------------------


def test_phase11_refuses_to_activate_unverified_campaigns() -> None:
    p11 = section(read(COMMAND_PATH), "## Phase 11 ", "\n---\n\n## ")  # noqa: E501
    assert "compliance" in p11.lower()
    assert "--no-sequence" in p11, "a campaign launched with --no-sequence has no verified footer"


def test_metadata_schema_records_compliance_results() -> None:
    cmd = read(COMMAND_PATH)
    for key in ("can_unsubscribe_applied", "footer_verified", "step_2_subject_verified"):
        assert f'"{key}"' in cmd or f"`{key}" in cmd, f"metadata schema must record {key}"


# --- email-bison skill + integration notes ----------------------------------


def test_email_bison_skill_carries_the_rule() -> None:
    s = read(SKILL_PATH)
    assert "can_unsubscribe: true" in s
    assert POSTAL_ADDRESS in s
    assert "thread_reply" in s and "Re:" in s
    assert "same body" in s.lower() or "same patch" in s.lower()


def test_email_bison_skill_refuses_noncompliant_campaign_creation() -> None:
    s = read(SKILL_PATH)
    assert STOP_MESSAGE in s, "skill must stop with the same message the command uses"
    assert "create_campaign" in s and "update_campaign" in s


def test_integration_doc_documents_the_same_calls() -> None:
    d = read(INTEGRATION_PATH)
    row = next(line for line in d.splitlines() if line.startswith("| 2a |"))
    assert "can_unsubscribe" in row and "plain_text" in row
    assert POSTAL_ADDRESS in d
    assert "has not replied" in d


def test_integration_doc_no_longer_says_eb_appends_unsubscribe_footers() -> None:
    d = read(INTEGRATION_PATH)
    assert not re.search(r"automatically appends? unsubscribe", d, re.IGNORECASE)


# --- outbound skill template -------------------------------------------------


def test_template_carries_the_same_rule() -> None:
    t = read(TEMPLATE_PATH)
    assert "can_unsubscribe: true" in t
    assert POSTAL_ADDRESS in t
    assert "thread_reply" in t and "Re:" in t
    assert STOP_MESSAGE in t


# --- version bump -------------------------------------------------------------


def _ver(v: str) -> tuple[int, ...]:
    return tuple(int(p) for p in v.split("."))


def test_marketing_version_bumped_and_mirrored() -> None:
    plugin = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"]
    assert _ver(plugin) > _ver("0.16.8"), "per-PR bump: command/skills changed"
    entry = next(
        p for p in json.loads(MARKETPLACE_JSON.read_text(encoding="utf-8"))["plugins"]
        if p["name"] == "marketing"
    )
    assert entry["version"] == plugin
