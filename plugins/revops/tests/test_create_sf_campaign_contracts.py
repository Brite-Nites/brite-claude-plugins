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

import functools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "create-sf-campaign.md"
SIBLING_COMMAND_PATH = ROOT / "commands" / "update-sf-campaign-status.md"
# BC-12594: the marketing-side canonical EMAIL_REGEX source of truth, asserted
# byte-identical to the revops owner-email guard below. ROOT.parents[0] is the
# `plugins/` directory, so this resolves the sibling marketing plugin.
MARKETING_PLAN_CAMPAIGN_PATH = (
    ROOT.parents[0] / "marketing" / "commands" / "plan-campaign.md"
)
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"


@functools.cache
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
    parsing the `error` key, not by exit code. All 7 documented error paths
    must appear verbatim in the command body so the contract is auditable.

    BC-10511 added `invalid_target_org` as the 6th key (sibling parity with
    `/revops:update-sf-campaign-status` per ADR-015 amendment).
    BC-12594 added `invalid_owner_email` as the 7th key (Phase 1
    SOQL-injection guard on `--owner-email` before the Phase 3 `WHERE Email`
    literal).
    """
    body = read_command()
    error_keys = [
        "missing_required_flag",
        "invalid_slug_format",
        "invalid_target_org",
        "invalid_owner_email",
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


# ---------------------------------------------------------------------------
# BC-10510 + BC-10511 — σ3 sibling-parity backports from
# `/revops:update-sf-campaign-status` (BC-8723). Tests verify:
#   - BC-10510: Phase 0 metadata cache present + only ONE sf org display
#     invocation in the command body (count-based per BC-8729 round-2
#     pattern, NOT substring-absence assertions — see
#     memory/gotcha_soql_substring_absence_assertions_fragile.md)
#   - BC-10511: --target-org regex present verbatim AND byte-identical
#     to the sibling command's
# ---------------------------------------------------------------------------


def test_phase_0_metadata_cache_present() -> None:
    """BC-10510: Phase 0 caches metadata from a single `sf org display`
    invocation, then Phase 2 + Phase 3 SOQL calls reuse the cached username
    and Phase 6 reuses the cached instanceUrl. The Phase 0 section must
    appear by name + the cache variables must be documented verbatim.
    """
    body = read_command()
    assert "## Phase 0 — Resolve target-org metadata" in body, (
        "BC-10510: Phase 0 section header must appear so the cache step is "
        "discoverable and matches the sibling `/revops:update-sf-campaign-status`"
    )
    assert "`<sf-username>` = `.result.username`" in body, (
        "BC-10510: Phase 0 must cache `<sf-username>` from `.result.username` "
        "for Phase 2 + Phase 3 MCP `run_soql_query` calls"
    )
    assert "`<instance-url>` = `.result.instanceUrl`" in body, (
        "BC-10510: Phase 0 must cache `<instance-url>` from `.result.instanceUrl` "
        "for Phase 6 URL construction"
    )
    assert "cached from Phase 0" in body, (
        "BC-10510: downstream phases must explicitly reference 'cached from "
        "Phase 0' so reviewers can audit the cache-reuse contract"
    )


def test_exactly_one_sf_org_display_invocation() -> None:
    """BC-10510: the command body must contain exactly ONE `sf org display`
    invocation — Phase 0's upfront cache. Phase 6 reuses the cache; no
    fallback re-call is issued. Eliminates the ~200ms-per-σ3-fire round-trip
    that the unscoped pre-cache version paid.

    Count-based assertion per BC-8729 round-2 review pattern. Substring
    "not present" assertions are fragile (see
    memory/gotcha_soql_substring_absence_assertions_fragile.md) — we count
    occurrences instead so a re-introduced second call fails loudly.
    """
    body = read_command()
    occurrences = body.count("sf org display")
    assert occurrences == 1, (
        f"BC-10510: expected exactly 1 `sf org display` invocation in the "
        f"command body (Phase 0 only), got {occurrences}. A second occurrence "
        f"reintroduces the ~200ms-per-invocation round-trip that the BC-10510 "
        f"backport eliminated. If a fallback re-call is genuinely needed, "
        f"update this assertion explicitly and document the divergence from "
        f"the sibling /revops:update-sf-campaign-status pattern."
    )


def test_target_org_regex_present_verbatim() -> None:
    """BC-10511: the --target-org regex must appear verbatim in the command
    body so reviewers can audit the shell-injection guard without re-deriving
    it from prose. Mirrors test_slug_regex_documented.
    """
    body = read_command()
    expected = r"^[a-zA-Z0-9._@-]+$"
    assert expected in body, (
        f"BC-10511: --target-org regex must appear verbatim. Expected: "
        f"{expected!r}. The regex is a shell-injection guard for sf CLI "
        f"interpolation in Phases 0/5/6."
    )


def test_target_org_regex_byte_identical_to_sibling() -> None:
    """BC-10511: both σ3 SF-write surfaces must share the same --target-org
    regex character class — divergent regexes would let a value accepted by
    one command fail in the other, breaking orchestrator portability.

    Source: `/revops:update-sf-campaign-status` Phase 1 (BC-8723). Both
    command bodies must contain the canonical regex string verbatim — if
    either side drifts to a different character class, the substring check
    on the canonical form fails on the drifted file.
    """
    canonical_regex = "^[a-zA-Z0-9._@-]+$"
    create_body = read_command()
    update_body = SIBLING_COMMAND_PATH.read_text()
    assert canonical_regex in create_body, (
        f"BC-10511: canonical --target-org regex {canonical_regex!r} not "
        f"found verbatim in create-sf-campaign.md"
    )
    assert canonical_regex in update_body, (
        f"BC-10511: canonical --target-org regex {canonical_regex!r} not "
        f"found verbatim in sibling update-sf-campaign-status.md — sibling "
        f"source-of-truth may have drifted, re-sync required per ADR-015 "
        f"amendment."
    )


# ---------------------------------------------------------------------------
# BC-12594 — `--owner-email` SOQL-injection guard. Phase 3 builds
# `SELECT Id FROM User WHERE Email = '<owner-email>' AND IsActive = TRUE LIMIT 1`.
# Phase 1 guards `--slug` and `--target-org` but did NOT guard `--owner-email`,
# so a single-quote in the email broke out of the literal. Phase 1 now
# validates `--owner-email` against the canonical EMAIL_REGEX (byte-identical
# to the marketing-side callers) before it reaches the literal. Tests verify:
#   - the regex appears verbatim in the command body (mirrors
#     test_slug_regex_documented)
#   - the regex is byte-identical to the marketing canonical source — the
#     marketing<->revops drift guard (mirrors
#     test_target_org_regex_byte_identical_to_sibling)
# The `invalid_owner_email` error key is asserted in
# test_all_soft_fail_error_keys_present above.
# ---------------------------------------------------------------------------


def test_owner_email_regex_documented() -> None:
    """BC-12594: the `--owner-email` regex must appear verbatim in the command
    body so reviewers can audit the SOQL-injection guard without re-deriving it
    from prose. Mirrors test_slug_regex_documented.

    The character class disallows the single-quote (and backslash / whitespace),
    so a value that passes CANNOT break out of the Phase 3
    `WHERE Email = '<owner-email>'` SOQL string literal.
    """
    body = read_command()
    expected = r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
    assert expected in body, (
        f"BC-12594: --owner-email regex must appear verbatim. Expected: "
        f"{expected!r}. The regex is a SOQL-injection guard for the Phase 3 "
        f"`WHERE Email = '<owner-email>'` literal."
    )


def test_owner_email_regex_byte_identical_to_marketing() -> None:
    """BC-12594: the revops owner-email guard must reuse the SAME canonical
    EMAIL_REGEX as the marketing-side callers (`/marketing:plan-campaign`
    Step 4.2) — a divergent regex would let a value accepted by the marketing
    orchestrator fail at the revops sink (or vice-versa), breaking the
    marketing->revops boundary. Mirrors
    test_target_org_regex_byte_identical_to_sibling.

    Source of truth: plugins/marketing/commands/plan-campaign.md Step 4.2,
    where EMAIL_REGEX is defined once for reuse. If either side drifts to a
    different character class, the substring check on the canonical form fails
    on the drifted file.
    """
    canonical_regex = r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
    create_body = read_command()
    assert MARKETING_PLAN_CAMPAIGN_PATH.is_file(), (
        f"BC-12594: marketing EMAIL_REGEX anchor moved — update "
        f"MARKETING_PLAN_CAMPAIGN_PATH ({MARKETING_PLAN_CAMPAIGN_PATH})"
    )
    marketing_body = MARKETING_PLAN_CAMPAIGN_PATH.read_text()
    assert canonical_regex in create_body, (
        f"BC-12594: canonical EMAIL_REGEX {canonical_regex!r} not found "
        f"verbatim in create-sf-campaign.md"
    )
    assert canonical_regex in marketing_body, (
        f"BC-12594: canonical EMAIL_REGEX {canonical_regex!r} not found "
        f"verbatim in marketing plan-campaign.md — the marketing source of "
        f"truth may have drifted; re-sync required so the marketing->revops "
        f"boundary stays consistent."
    )


# ---------------------------------------------------------------------------
# BC-12638 — guard-precedes-sink ordering is enforced repo-wide by the
# consolidating lint scripts/_lib/lint_target_org_guard.py, which subsumed the
# prior per-file `test_target_org_guard_precedes_phase_0_sink`. Invoke the lint
# on this command file so the ordering check is also reachable from the pytest
# suite in isolation, not only via validate.sh (Greptile PR #450 follow-up).
# ---------------------------------------------------------------------------


def test_target_org_guard_lint_passes() -> None:
    """The `--target-org` guard-precedes-sink ordering for this command is
    enforced by the consolidating lint (BC-12638). Run it here so a
    guard-after-sink / orphaned-marker regression fails the pytest suite too,
    not only validate.sh."""
    import subprocess
    import sys

    lint = ROOT.parents[1] / "scripts" / "_lib" / "lint_target_org_guard.py"
    assert lint.is_file(), f"consolidating lint not found at {lint}"
    result = subprocess.run(
        [sys.executable, str(lint), str(COMMAND_PATH)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"target-org guard-precedes-sink lint failed for {COMMAND_PATH.name} "
        f"(rc={result.returncode}):\n{result.stdout}{result.stderr}"
    )
