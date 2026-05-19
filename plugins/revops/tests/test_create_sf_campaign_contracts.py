"""Contract tests for the /revops:create-sf-campaign slash command.

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared tools, documented
flags, soft-fail error keys, idempotency precheck SOQL) rather than runtime
execution. Runtime validation happens in BC-8717's PR via manual --dry-run +
throwaway-slug evidence.

Pattern mirrors test_skill_registry_contracts.py: read the artifact, assert
the contract is met. No mocks, no subprocess, no SF org dependency.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "create-sf-campaign.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"


def read_command() -> str:
    return COMMAND_PATH.read_text()


def split_frontmatter(text: str) -> tuple[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, "Expected YAML frontmatter wrapped in --- markers"
    return match.group(1), match.group(2)


def test_command_file_exists() -> None:
    assert COMMAND_PATH.is_file(), f"Slash command file missing: {COMMAND_PATH}"


def test_frontmatter_has_description_and_allowed_tools() -> None:
    frontmatter, _ = split_frontmatter(read_command())
    assert re.search(r"^description: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare a `description` field"
    assert re.search(r"^allowed-tools: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare an `allowed-tools` field"


def test_allowed_tools_includes_bash_and_soql_mcp() -> None:
    frontmatter, _ = split_frontmatter(read_command())
    tools_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
        None,
    )
    assert tools_line, "allowed-tools line not found"

    assert "Bash" in tools_line, \
        "allowed-tools must include Bash (for sf data create record + sf org display)"
    assert "mcp__plugin_revops_salesforce__run_soql_query" in tools_line, (
        "allowed-tools must include mcp__plugin_revops_salesforce__run_soql_query "
        "(for idempotency precheck + owner lookup)"
    )


def test_all_required_input_flags_documented() -> None:
    body = read_command()
    required_flags = [
        "--slug",
        "--entity",
        "--vertical",
        "--persona",
        "--offer",
        "--year",
        "--month",
        "--owner-email",
        "--launch-date",
        "--target-org",
        "--dry-run",
    ]
    missing = [flag for flag in required_flags if flag not in body]
    assert not missing, f"Input flags missing from command body: {missing}"


def test_all_soft_fail_error_keys_present() -> None:
    """Soft-fail contract per BC-8724 design — orchestrators detect failure by
    parsing the `error` key, not by exit code. All 5 documented error paths
    must appear verbatim in the command body so the contract is auditable.
    """
    body = read_command()
    error_keys = [
        "missing_required_flag",
        "invalid_slug_format",
        "duplicate_slug",
        "missing_owner",
        "sf_cli_error",
    ]
    missing = [key for key in error_keys if key not in body]
    assert not missing, f"Soft-fail error keys missing from command body: {missing}"


def test_idempotency_precheck_soql_present_verbatim() -> None:
    """Phase 2 SOQL must appear verbatim so reviewers and orchestrators can
    audit the idempotency contract without re-deriving it from prose.
    """
    body = read_command()
    expected = "SELECT Id FROM Campaign WHERE Name = '<slug>' LIMIT 1"
    assert expected in body, (
        f"Phase 2 idempotency SOQL not present verbatim. Expected: {expected!r}"
    )


def test_owner_lookup_soql_present_verbatim() -> None:
    """Phase 3 SOQL must constrain on IsActive = TRUE so a deactivated user
    with a stale matching email doesn't get assigned as Campaign OwnerId.
    """
    body = read_command()
    expected = (
        "SELECT Id FROM User WHERE Email = '<owner-email>' "
        "AND IsActive = TRUE LIMIT 1"
    )
    assert expected in body, (
        f"Phase 3 owner-lookup SOQL not present verbatim. Expected: {expected!r}"
    )


def test_soft_fail_contract_documented() -> None:
    """The command body must explicitly state the exit-0-on-error contract,
    because it's load-bearing and easy to regress.
    """
    body = read_command()
    assert "exit 0" in body, \
        "Body must explicitly document `exit 0` for error paths (soft-fail contract)"
    assert "soft-fail" in body.lower(), \
        "Body must use the term `soft-fail` so the contract is greppable"


def test_slug_regex_documented() -> None:
    body = read_command()
    expected = r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$"
    assert expected in body, (
        f"Slug regex must appear verbatim so reviewers can audit it. Expected: {expected!r}"
    )


def test_default_target_org_is_brite_prod() -> None:
    body = read_command()
    assert "brite-prod" in body, \
        "`--target-org` must default to brite-prod per the Linear spec"


def test_plugin_json_version_bumped() -> None:
    """CLAUDE.md plugin-cache gotcha: bumping plugin.json without bumping the
    matching marketplace.json entry leaves clients serving stale content.
    BC-8717 adds a new command, so version MUST be > 0.2.6 in BOTH files.
    """
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    assert plugin_data["version"] != "0.2.6", (
        "plugin.json revops version must be bumped from 0.2.6 — BC-8717 adds a new command "
        "and clients' plugin cache is keyed by version"
    )


def test_marketplace_json_version_mirrors_plugin_json() -> None:
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    marketplace_data = json.loads(MARKETPLACE_JSON.read_text())

    revops_entry = next(
        (p for p in marketplace_data["plugins"] if p["name"] == "revops"),
        None,
    )
    assert revops_entry, "revops plugin entry missing from marketplace.json"
    assert revops_entry["version"] == plugin_data["version"], (
        f"marketplace.json revops version ({revops_entry['version']}) must match "
        f"plugin.json ({plugin_data['version']}) — per CLAUDE.md plugin-cache gotcha"
    )
