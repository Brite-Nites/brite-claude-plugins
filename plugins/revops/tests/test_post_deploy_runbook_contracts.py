"""Contract tests for the /revops:post-deploy-runbook slash command,
locking the BC-11038 Flow Draft cleanup phase.

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (phase ordering, SOQL shape, gate presence,
delete paths) rather than runtime execution.

Pattern mirrors test_doctor_contracts.py: read the artifact, assert the
contract is met. No mocks, no subprocess, no SF org dependency. Stdlib only —
the repo has no third-party deps.

No pytest installed locally? Run as a plain script:
    cd plugins/revops/tests
    python3 -c "import test_post_deploy_runbook_contracts as t; \\
[getattr(t,n)() for n in dir(t) if n.startswith('test_')]; print('all pass')"
"""

from __future__ import annotations

import functools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "post-deploy-runbook.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"


@functools.lru_cache(maxsize=1)
def read_command() -> str:
    return COMMAND_PATH.read_text()


def split_frontmatter(text: str) -> tuple[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, "Expected YAML frontmatter wrapped in --- markers"
    return match.group(1), match.group(2)


# ── File existence ──────────────────────────────────────────────────────

def test_command_file_exists() -> None:
    assert COMMAND_PATH.is_file(), f"Slash command file missing: {COMMAND_PATH}"


# ── Frontmatter ─────────────────────────────────────────────────────────

def test_frontmatter_has_description_and_allowed_tools() -> None:
    frontmatter, _ = split_frontmatter(read_command())
    assert re.search(r"^description: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare a `description` field"
    assert re.search(r"^allowed-tools: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare an `allowed-tools` field"


def test_allowed_tools_is_bash_and_ask() -> None:
    frontmatter, _ = split_frontmatter(read_command())
    tools_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
        None,
    )
    assert tools_line, "allowed-tools line not found"
    declared = {t.strip() for t in tools_line.split(":", 1)[1].split(",") if t.strip()}
    assert declared == {"Bash", "AskUserQuestion"}, (
        f"allowed-tools must be exactly {{Bash, AskUserQuestion}}; got {sorted(declared)}"
    )


# ── Phase ordering: Phase 3 sits between Flow activation and Scheduled Apex ─

def test_phase_ordering_flow_draft_between_activation_and_scheduled() -> None:
    """BC-11038 AC: new phase between Flow activation and Scheduled Apex."""
    body = read_command()
    phase2_pos = body.find("## Phase 2 — Flow activation")
    phase3_pos = body.find("## Phase 3 — Flow Draft cleanup")
    phase4_pos = body.find("## Phase 4 — Scheduled Apex re-schedule")
    assert phase2_pos != -1, "Phase 2 (Flow activation) not found"
    assert phase3_pos != -1, "Phase 3 (Flow Draft cleanup) not found"
    assert phase4_pos != -1, "Phase 4 (Scheduled Apex re-schedule) not found"
    assert phase2_pos < phase3_pos < phase4_pos, (
        "Phase ordering violated: Phase 3 (Flow Draft cleanup) must sit between "
        "Phase 2 (Flow activation) and Phase 4 (Scheduled Apex re-schedule)"
    )


def test_seven_phases_total() -> None:
    """After the insert, the runbook has 7 phases (was 6)."""
    body = read_command()
    phase_headings = re.findall(r"^## Phase (\S+) —", body, re.MULTILINE)
    assert len(phase_headings) == 7, (
        f"Expected 7 phase headings; found {len(phase_headings)}: {phase_headings}"
    )
    assert phase_headings == ["1", "2", "3", "4", "5", "6", "7"], (
        f"Phase numbering must be sequential 1-7; got {phase_headings}"
    )


def test_narration_denominators_are_seven() -> None:
    """All Phase N/M narrations must use /7 as denominator."""
    body = read_command()
    narrations = re.findall(r"Phase (\d+)/(\d+):", body)
    assert len(narrations) >= 14, (
        f"Expected at least 14 narration markers (opening+closing per phase); found {len(narrations)}"
    )
    wrong = [(n, d) for n, d in narrations if d != "7"]
    assert not wrong, f"Narration denominators must all be /7; found: {wrong}"


# ── SOQL query shape: Status = 'Draft' + time-bounded CreatedDate ────────

def test_soql_queries_draft_status() -> None:
    """BC-11038 AC: SOQL must filter Status = 'Draft'."""
    body = read_command()
    assert "Status = 'Draft'" in body, (
        "Phase 3 SOQL must contain Status = 'Draft' predicate"
    )


def test_soql_has_time_bounded_created_date() -> None:
    """BC-11038 AC: SOQL bounded by deploy timestamp, not 'all Drafts'."""
    body = read_command()
    assert re.search(r"CreatedDate\s*>=\s*<deploy-window-start>", body), (
        "Phase 3 SOQL must contain CreatedDate >= <deploy-window-start> predicate"
    )


def test_soql_selects_required_fields() -> None:
    """The SOQL must select Id, DeveloperName (via Definition), VersionNumber, CreatedDate."""
    body = read_command()
    soql_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    for field in ["Id", "Definition.DeveloperName", "VersionNumber", "CreatedDate", "Status"]:
        assert field in soql_section, (
            f"Phase 3 SOQL must SELECT {field}"
        )


def test_soql_queries_from_flow() -> None:
    """The SOQL must query FROM Flow (Tooling API)."""
    body = read_command()
    soql_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    assert re.search(r"FROM\s+Flow\b", soql_section), (
        "Phase 3 SOQL must query FROM Flow (Tooling API)"
    )


def test_query_uses_json_flag() -> None:
    """The sf data query command must use --json for parseable output."""
    body = read_command()
    phase3_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    assert "sf data query --use-tooling-api --json" in phase3_section, (
        "Phase 3 query must use --json for parseable output"
    )


def test_fallback_to_last_n_hours() -> None:
    """The spec mandates LAST_N_HOURS:2 as fallback when git date extraction fails."""
    body = read_command()
    assert "LAST_N_HOURS:2" in body, (
        "Phase 3 must fall back to LAST_N_HOURS:2 when git date extraction fails"
    )


# ── AskUserQuestion gate presence (no silent deletion) ───────────────────

def test_phase3_has_ask_user_question_gate() -> None:
    """BC-11038 AC: AskUserQuestion gate — no silent deletion."""
    body = read_command()
    phase3_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    assert "Ask via `AskUserQuestion`:" in phase3_section, (
        "Phase 3 must have an AskUserQuestion gate (no silent deletion contract)"
    )


def test_phase3_gate_has_three_options() -> None:
    """The gate must offer Delete all, Skip, and Pick individually."""
    body = read_command()
    phase3_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    assert "Delete all" in phase3_section, "Phase 3 gate must offer 'Delete all' option"
    assert "Skip" in phase3_section, "Phase 3 gate must offer a Skip option"
    assert "Pick individually" in phase3_section, "Phase 3 gate must offer 'Pick individually' option"


# ── Delete-individual path exists alongside bulk-delete ──────────────────

def test_bulk_delete_path_exists() -> None:
    """Phase 3.4 must implement bulk delete via sf data delete record."""
    body = read_command()
    phase3_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    assert "### 3.4" in phase3_section, "Phase 3.4 (Bulk delete) sub-section must exist"
    assert "sf data delete record" in phase3_section, (
        "Phase 3 must use sf data delete record for deletion"
    )
    assert "--use-tooling-api" in phase3_section, (
        "Phase 3 delete must use --use-tooling-api flag"
    )
    assert "--sobject Flow" in phase3_section, (
        "Phase 3 delete must target --sobject Flow (Tooling API Flow object)"
    )


def test_individual_delete_path_exists() -> None:
    """Phase 3.5 must implement per-Draft gate alongside bulk delete."""
    body = read_command()
    phase3_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    assert "### 3.5" in phase3_section, "Phase 3.5 (Per-Draft gate) sub-section must exist"
    gate_markers = [m for m in re.finditer(r"Ask via `AskUserQuestion`:", phase3_section)]
    assert len(gate_markers) >= 2, (
        "Phase 3 must have at least two AskUserQuestion gates "
        "(3.3 bulk gate + 3.5 per-Draft gate)"
    )


# ── Phase 3 failure tolerance ───────────────────────────────────────────

def test_query_failure_does_not_halt() -> None:
    """Phase 3.2 query failure must not halt the runbook (advisory check)."""
    body = read_command()
    phase3_section = body[body.find("## Phase 3"):body.find("## Phase 4")]
    assert "do **not** halt the runbook over an advisory check" in phase3_section, (
        "Phase 3 must not halt on Tooling API query failure (advisory check)"
    )


# ── Phase 7 summary includes Flow Draft cleanup ─────────────────────────

def test_summary_includes_flow_draft_cleanup() -> None:
    """Phase 7 completion summary must include Flow Draft cleanup status."""
    body = read_command()
    phase7_section = body[body.find("## Phase 7"):]
    assert "Flow Draft cleanup" in phase7_section, (
        "Phase 7 summary matrix must include Flow Draft cleanup"
    )


# ── Phase 3 structural contracts ─────────────────────────────────────────

def test_phase3_is_unconditional() -> None:
    """Phase 3 must NOT be conditional on a diff flag — it self-determines."""
    body = read_command()
    phase3_heading = re.search(r"^## Phase 3 — (.*)$", body, re.MULTILINE)
    assert phase3_heading, "Phase 3 heading not found"
    assert "conditional" not in phase3_heading.group(1).lower(), (
        "Phase 3 must not be conditional on a diff flag — it self-determines "
        "via the Tooling API query result"
    )


def test_summary_includes_phase3_unique_statuses() -> None:
    """Phase 7 must surface Phase 3's unique N/A statuses."""
    body = read_command()
    phase7_section = body[body.find("## Phase 7"):]
    assert "N/A — no Drafts detected" in phase7_section, (
        "Phase 7 must surface Phase 3's 'N/A — no Drafts detected' status"
    )
    assert "N/A — query failed" in phase7_section, (
        "Phase 7 must surface Phase 3's 'N/A — query failed' status"
    )


# ── BC-11038 rationale callout ──────────────────────────────────────────

def test_cites_bc_11038() -> None:
    """The command must cite BC-11038 for traceability."""
    body = read_command()
    assert re.search(
        r"\[BC-11038\]\(https://linear\.app/brite-nites/issue/BC-11038\)",
        body,
    ), "Phase 3 must cite BC-11038 as a markdown link"


# ── Rules section updates ──────────────────────────────────────────────

def test_rules_acknowledge_phase3_mutations() -> None:
    """The zero-mutation rule must carve out Phase 3 in the same sentence."""
    body = read_command()
    rules_section = body[body.find("## Rules"):]
    first_rule = rules_section.split("\n")[2]
    assert "except" in first_rule.lower() and "Phase 3" in first_rule, (
        "The first rule must carve out Phase 3 from the zero-mutation contract "
        "in the same sentence"
    )


def test_rules_reference_phase7_for_followup() -> None:
    """The Rules gate-advance rule must reference Phase 7 for skip follow-ups."""
    body = read_command()
    rules_section = body[body.find("## Rules"):]
    assert "Phase 7" in rules_section, (
        "Rules must reference Phase 7 (not Phase 6) for skip follow-up surfacing"
    )


# ── Cross-reference consistency ─────────────────────────────────────────

def test_no_stale_phase_6_total_references() -> None:
    """After renumbering, no '/6:' or 'Phase 6 —' completion references should remain
    (Phase 6 is now Kanban, not Completion summary)."""
    body = read_command()
    assert "Phase 6 — Completion" not in body, (
        "Stale reference: Phase 6 — Completion should be Phase 7 — Completion"
    )
    stale_narrations = re.findall(r"Phase \d+/6:", body)
    assert not stale_narrations, (
        f"Stale /6 denominator narrations found: {stale_narrations}"
    )


# ── Version bump ────────────────────────────────────────────────────────

def test_plugin_version_matches_marketplace() -> None:
    """BC-6000 discipline: plugin.json and marketplace.json must agree on version."""
    plugin = json.loads(PLUGIN_JSON.read_text())
    marketplace = json.loads(MARKETPLACE_JSON.read_text())
    revops_entry = next(
        (p for p in marketplace["plugins"] if p["name"] == "revops"),
        None,
    )
    assert revops_entry, "revops entry not found in marketplace.json"
    assert plugin["version"] == revops_entry["version"], (
        f"Version mismatch: plugin.json={plugin['version']}, "
        f"marketplace.json={revops_entry['version']}"
    )


if __name__ == "__main__":
    import sys
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    failed = []
    for test_fn in tests:
        try:
            test_fn()
            print(f"  PASS  {test_fn.__name__}")
        except AssertionError as e:
            print(f"  FAIL  {test_fn.__name__}: {e}")
            failed.append(test_fn.__name__)
    print(f"\n{len(tests)} tests, {len(failed)} failed")
    sys.exit(1 if failed else 0)
