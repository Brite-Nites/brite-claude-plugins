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


def phase5_step8() -> str:
    return section(phase("5", "6"), "8. **Apply plain_text + can_unsubscribe defaults", "\n9. **Attach")


def test_phase5_step8_reaches_reused_campaigns_and_stops_on_readback_mismatch() -> None:
    # Pinned INSIDE step 8: "reused", get_campaign and the stop appear elsewhere in
    # Phase 5, so a looser check survives deleting the read-back paragraph.
    s8 = phase5_step8()
    assert "fresh creates and reused campaigns alike" in s8
    assert "**Read back and stop on mismatch.**" in s8
    assert "`get_campaign` for every campaign ID" in s8
    assert "`can_unsubscribe` is `true`" in s8
    assert "can_unsubscribe on campaign {id}" in s8 and "stops the launch" in s8


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


def test_phase9_artifact_footer_check_is_pinned() -> None:
    p9 = phase("9", "10")
    bullet = section(p9, "**Footer in every step body.**", "\n   - ")
    assert POSTAL_ADDRESS in bullet and "step_1.body" in bullet and "step_2.body" in bullet
    assert "HARD FAIL" in bullet


def test_phase9_step7_halt_resumes_at_step_7_without_recreating_sequences() -> None:
    # A stored `Re:` on step 2 makes this halt the normal path, after step 6 has
    # already created the sequences. Resuming at Phase 9 step 1 would re-create them.
    p9 = phase("9", "10")
    s7 = section(p9, "7. **Verify per campaign.**", "8. **Append to metadata JSON.**")
    assert "resumes at step 7" in s7
    assert "read-back only" in s7 and "`create_sequence_steps`" in s7
    assert "Only this read-back writes" in s7 and "`compliance.footer_verified`" in s7
    fails = p9[p9.index("**If Phase 9 fails mid-campaign:**"):]
    assert "CAN-SPAM halt at step 7" in fails and "resumes at step 7" in fails
    assert "scoped to unsequenced campaigns" in fails, "the partial-creation resume is a different case"


def test_resume_contract_names_the_can_spam_step_7_exception() -> None:
    cmd = read(COMMAND_PATH)
    line = next(l for l in cmd.splitlines() if l.startswith("- **Launch metadata JSON**"))
    assert "CAN-SPAM halt" in line and "Phase 9 step 7" in line


# --- activation + metadata ---------------------------------------------------


def test_phase11_has_no_proceed_anyway_and_keeps_no_override() -> None:
    cmd = read(COMMAND_PATH)
    p11 = cmd[cmd.index("## Phase 11 "):]
    pre = section(p11, "### Compliance precondition (CAN-SPAM gate)", "\n### ")
    assert "No operator override." in pre
    assert "proceed anyway" not in p11.lower()
    # The only "proceed anyway" in the command is the gate's own "never offered" sentence.
    assert cmd.lower().count("proceed anyway") == 1


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
    # The negative above already held at base; this is the positive half that did not.
    assert "appends no unsubscribe footer" in d


def test_integration_doc_can_unsubscribe_gotcha_is_pinned() -> None:
    d = read(INTEGRATION_PATH)
    gotcha = next(
        (line for line in d.splitlines() if line.startswith("- **`can_unsubscribe` defaults to `false`")),
        None,
    )
    assert gotcha, "the can_unsubscribe default-false gotcha must exist in Known gotchas"
    assert "appends no unsubscribe footer" in gotcha
    assert POSTAL_ADDRESS in gotcha
    assert "same `update_campaign` body" in gotcha and "read it back" in gotcha


# Lines that mention EB prepending `Re:` are allowed only as history or as the
# superseded-guidance note. Anything else is the stale "EB prepends Re:" claim.
_STALE_RE_PREPEND = re.compile(r"let EB prepend|prepend\w*[^\n]*Re:|Re:[^\n]*prepend", re.IGNORECASE)
_RE_PREPEND_ALLOWED = ("superseded", "Prior:")
CHECKED_FILES = (
    COMMAND_PATH,
    SKILL_PATH,
    INTEGRATION_PATH,
    TEMPLATE_PATH,
    ROOT / "skills" / "campaign-orchestration" / "SKILL.md",
    ROOT / "skills" / "email-copywriting" / "SKILL.md",
)


def test_no_file_tells_authors_eb_prepends_re() -> None:
    offenders = [
        f"{p.relative_to(ROOT)}:{n}"
        for p in CHECKED_FILES
        for n, line in enumerate(read(p).splitlines(), 1)
        if _STALE_RE_PREPEND.search(line) and not any(m in line for m in _RE_PREPEND_ALLOWED)
    ]
    assert not offenders, f"stale 'EB prepends Re:' claim (the standard forbids a Re: on step 2): {offenders}"


# --- campaign-orchestration: the second launch path ---------------------------

ORCHESTRATION_PATH = ROOT / "skills" / "campaign-orchestration" / "SKILL.md"


def test_orchestration_workflow_3_routes_creation_through_email_bison_workflow_9() -> None:
    w3 = section(read(ORCHESTRATION_PATH), "### Workflow 3:", "### Workflow 4:")
    assert "Workflow 9" in w3 and "`email-bison`" in w3
    assert '{"plain_text": true, "can_unsubscribe": true}' in w3, "toggle goes in the same body"
    assert POSTAL_ADDRESS in w3 and "company name" in w3.lower()
    assert "thread_reply" in w3 and "Re:" in w3 and "has not replied" in w3


def test_orchestration_workflow_4_checks_before_resume_campaign() -> None:
    w4 = section(read(ORCHESTRATION_PATH), "### Workflow 4:", "### Workflow 5:")
    assert "Workflow 9" in w4 and STOP_MESSAGE in w4
    assert "get_campaign" in w4 and "get_sequence_steps" in w4, "re-read what Email Bison stored"
    first_resume_call = w4.index("**Second gate — `resume_campaign`.**")
    assert w4.index("CAN-SPAM") < first_resume_call, "the check comes before the gated call"
    assert "do not call `resume_campaign`" in w4.lower() or "never call `resume_campaign`" in w4.lower()
    assert "proceed anyway" not in w4.lower()


def test_orchestration_architectural_rule_points_at_workflow_9() -> None:
    s = read(ORCHESTRATION_PATH)
    head = s[: s.index("### Workflow 1:")]
    assert "CAN-SPAM" in head and "Workflow 9" in head, "rule must be stated before the workflows"


# --- email-copywriting: artifacts must pass the Phase 1 gate -----------------

COPYWRITING_PATH = ROOT / "skills" / "email-copywriting" / "SKILL.md"
_SIGNOFF = "{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}"


def test_copywriting_signoff_spec_carries_company_name_and_postal_address() -> None:
    s = read(COPYWRITING_PATH)
    spec = next(line for line in s.splitlines() if line.startswith("- Sign-off is"))
    assert POSTAL_ADDRESS in spec
    assert "Brite Nites" in spec and "Brite Labs" in spec, "name is the literal entity company name"
    assert "not an Email Bison variable" in spec
    assert "replaces any sign-off" in spec, "preset bodies carry the old sign-off; the rule overrides them"


def test_copywriting_every_skeleton_signoff_carries_the_footer() -> None:
    lines = [line for line in read(COPYWRITING_PATH).splitlines() if _SIGNOFF in line]
    assert len(lines) >= 4, "two skeletons x two steps"
    for line in lines:
        assert POSTAL_ADDRESS in line and "[ENTITY_COMPANY_NAME]" in line, line[-120:]


def test_copywriting_checklist_and_guardrails_require_the_footer() -> None:
    s = read(COPYWRITING_PATH)
    row = next(line for line in s.splitlines() if "Artifact is EB-format-compliant" in line)
    assert "company name and postal address" in row
    guard = s[s.index("## Anti-Slop Guardrails"):]
    assert POSTAL_ADDRESS in guard, "a body without the footer must be a hard failure"


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
