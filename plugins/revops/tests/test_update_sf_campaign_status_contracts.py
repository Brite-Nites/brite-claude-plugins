"""Contract tests for the /revops:update-sf-campaign-status slash command.

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared tools, documented
flags, mapping table, soft-fail keys, Phase 2 SOQL, idempotency no-op) rather
than runtime execution. Runtime validation happens in BC-8723's PR via manual
--dry-run + throwaway-slug evidence.

Pattern mirrors test_create_sf_campaign_contracts.py (BC-8717).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "update-sf-campaign-status.md"
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
        "allowed-tools must include Bash (for sf data update record + sf org display)"
    assert "mcp__plugin_revops_salesforce__run_soql_query" in tools_line, (
        "allowed-tools must include mcp__plugin_revops_salesforce__run_soql_query "
        "(for Phase 2 lookup + current-state read)"
    )


def test_all_required_input_flags_documented() -> None:
    body = read_command()
    required_flags = [
        "--slug",
        "--linear-status",
        "--linear-substatus",
        "--target-org",
        "--dry-run",
    ]
    missing = [flag for flag in required_flags if flag not in body]
    assert not missing, f"Input flags missing from command body: {missing}"


def test_all_mapping_table_outputs_present() -> None:
    """All 5 mapping table rows must appear verbatim so reviewers and
    orchestrators can audit the locked O6.Q1 mapping without re-deriving it.
    """
    body = read_command()
    required_sf_values = [
        "Planned",
        "In Progress",
        "Paused",
        "Completed",
        "Aborted",
    ]
    missing = [val for val in required_sf_values if val not in body]
    assert not missing, f"SF Status/Substatus values missing from mapping table: {missing}"


def test_all_linear_status_values_documented() -> None:
    body = read_command()
    linear_statuses = ["planning", "active", "completed", "killed"]
    missing = [s for s in linear_statuses if s not in body]
    assert not missing, f"Linear status values missing from mapping table: {missing}"


def test_all_soft_fail_keys_present() -> None:
    """Soft-fail contract per BC-8752 trigger automation — orchestrators detect
    failure by parsing the `error` / `warning` key, not by exit code. All
    documented failure paths must appear verbatim in the command body.
    """
    body = read_command()
    failure_keys = [
        # error keys (caller-correctable)
        "missing_required_flag",
        "invalid_slug_format",
        "invalid_target_org",
        "invalid_status",
        "sf_cli_error",
        # warning keys (soft-degradations / not caller-correctable from this path)
        "campaign_not_found",
        "instance_url_unknown",
        "updated_at_unavailable",
    ]
    missing = [key for key in failure_keys if key not in body]
    assert not missing, f"Soft-fail keys missing from command body: {missing}"


def test_warning_shapes_for_all_warning_keys() -> None:
    """All three documented `warning` paths must appear in `warning:` form
    (not `error:`). The semantic distinction is load-bearing: `error` is
    caller-correctable, `warning` is degrade-and-continue.
    """
    body = read_command()
    warning_keys = ["campaign_not_found", "instance_url_unknown", "updated_at_unavailable"]
    for key in warning_keys:
        pattern = re.compile(r'"warning"\s*:\s*"' + re.escape(key) + r'"')
        assert pattern.search(body), (
            f"`{key}` must use `warning:` key (not `error:`) per BC-8723 spec / "
            f"BC-8717 convention. Search pattern: {pattern.pattern!r}"
        )


def test_invalid_status_has_flag_discriminator() -> None:
    """`invalid_status` fires for two distinct flags (`--linear-status` and
    `--linear-substatus`). The payload must include a `flag` field so callers
    can surface a precise diagnostic without re-parsing the input.
    """
    body = read_command()
    for flag in ("--linear-status", "--linear-substatus"):
        pattern = re.compile(r'"flag"\s*:\s*"' + re.escape(flag) + r'"')
        assert pattern.search(body), (
            f"invalid_status payload must include `flag: {flag}` discriminator. "
            f"Search pattern: {pattern.pattern!r}"
        )


def test_target_org_regex_documented() -> None:
    """Phase 0 must validate `--target-org` against the SF org alias character
    set BEFORE shell-interpolating it into Phase 0/6/7 `sf` CLI calls (the
    guard is hoisted ahead of the Phase 0 sink per BC-12623; the guard-precedes-
    sink ordering is now locked repo-wide by the consolidating lint
    scripts/_lib/lint_target_org_guard.py per BC-12638, which subsumed the prior
    per-file ordering test). Defense-in-depth against shell injection.
    """
    body = read_command()
    expected = r"^[a-zA-Z0-9._@-]+$"
    assert expected in body, (
        f"--target-org regex must appear verbatim. Expected: {expected!r}"
    )
    assert "invalid_target_org" in body, (
        "invalid_target_org error key must be documented in error catalog"
    )


def test_phase_2_soql_present_verbatim() -> None:
    """Phase 2 SOQL must appear verbatim so reviewers can audit the lookup
    contract without re-deriving it from prose. Must include Status +
    Substatus__c + LastModifiedDate so the idempotency pre-check + noop
    payload have the data they need without an extra round-trip.
    """
    body = read_command()
    expected = (
        "SELECT Id, Status, Substatus__c, LastModifiedDate "
        "FROM Campaign WHERE Name = '<slug>' LIMIT 1"
    )
    assert expected in body, (
        f"Phase 2 SOQL not present verbatim. Expected: {expected!r}"
    )


def test_slug_regex_documented() -> None:
    """Phase 1 must validate slug regex BEFORE Phase 2 SOQL interpolation —
    mirrors BC-8717's pattern + acts as SOQL-injection guard since the slug
    flows into a string literal in the SOQL query.
    """
    body = read_command()
    expected = r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$"
    assert expected in body, (
        f"Slug regex must appear verbatim so reviewers can audit it. Expected: {expected!r}"
    )
    assert "invalid_slug_format" in body, (
        "invalid_slug_format error key must be documented in error catalog"
    )


def test_idempotency_noop_documented() -> None:
    """Phase 4's no-op pre-check is the load-bearing optimization for σ3
    webhook re-fires. The `noop: true` payload + the pre-check logic must be
    documented so reviewers can audit it.
    """
    body = read_command()
    assert "noop" in body.lower(), (
        "Idempotency no-op pre-check must be documented (`noop` key in payload)"
    )
    assert "idempoten" in body.lower(), (
        "Body must use the term `idempotency` / `idempotent` so the contract is greppable"
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


def test_default_target_org_is_brite_prod() -> None:
    body = read_command()
    assert "brite-prod" in body, \
        "`--target-org` must default to brite-prod per the Linear spec"


def test_substatus_clearing_documented() -> None:
    """The `(active, paused) → (active, null)` transition depends on SF CLI
    interpreting empty-string in --values as clear. This must be tied to the
    `--values "..."` shell-wrapper context — a bare `Substatus__c=''` token
    in prose without the shell-wrap rationale would be confusing.
    """
    body = read_command()
    # The empty-string literal must appear (proves the clear-the-field syntax is documented).
    assert "Substatus__c=''" in body, (
        "Body must document `Substatus__c=''` as the empty-string-clears-the-field convention"
    )
    # The bash --values segment showing the placeholder form must also appear (proves shell wrap).
    assert re.search(r"--values\s+\"Status='[^\"]*Substatus__c='[^\"]*'\"", body), (
        "Body must show the `--values \"Status='...' Substatus__c='...'\"` shell wrapper "
        "so the empty-string-clears convention has explicit shell-wrap context"
    )


def test_composite_rest_fallback_documented() -> None:
    """Phase 6's documented fallback (if SF CLI `Substatus__c=''` doesn't clear)
    is a Composite REST `PATCH /services/data/vXX.X/sobjects/Campaign/<id>` with
    `{"Substatus__c": null}` body. The fallback is the recovery path if SF CLI
    v2.x ever regresses the empty-string-clears behavior.
    """
    body = read_command()
    assert "/services/data/v" in body, (
        "Composite REST fallback endpoint shape must be documented"
    )
    null_body_pattern = re.compile(r'"Substatus__c"\s*:\s*null')
    assert null_body_pattern.search(body), (
        "Composite REST fallback body shape (`{\"Substatus__c\": null}`) must be documented"
    )


def test_post_update_soql_present_verbatim() -> None:
    """Phase 6's post-UPDATE re-read SOQL is a separately-load-bearing contract
    from Phase 2's SOQL. It uses `WHERE Id = '<campaign-id>'` (not `Name = '<slug>'`)
    because `Id` is the indexed primary key. Must appear verbatim.
    """
    body = read_command()
    expected = "SELECT LastModifiedDate FROM Campaign WHERE Id = '<campaign-id>' LIMIT 1"
    assert expected in body, (
        f"Phase 6 post-UPDATE SOQL not present verbatim. Expected: {expected!r}"
    )


def test_mapping_row_active_paused_pairing() -> None:
    """The `(active, paused) → (In Progress, Paused)` row is the highest-risk
    in the mapping table (only row that branches on `--linear-substatus`).
    Verify the pairing — not just that the individual values appear somewhere.
    """
    body = read_command()
    # Find a mapping table row where `In Progress` is paired with `Paused`.
    pattern = re.compile(r"`In Progress`\s*\|\s*`Paused`")
    assert pattern.search(body), (
        "Mapping table must pair `In Progress` with `Paused` in the `(active, paused)` row"
    )


def test_success_payload_all_keys_present() -> None:
    """The Phase 8 success payload is the union of BC-8717's three fields and
    BC-8723's three additional confirmation fields. All six keys must appear
    in the documented JSON shape.
    """
    body = read_command()
    required_keys = [
        '"campaign_id"',
        '"campaign_url"',
        '"campaign_name"',
        '"status"',
        '"substatus"',
        '"updated_at"',
    ]
    missing = [key for key in required_keys if key not in body]
    assert not missing, (
        f"Success payload keys missing from command body: {missing}. "
        "Phase 8 must emit all six (BC-8717 union + BC-8723 confirmation fields)."
    )


def test_linear_status_set_token_present() -> None:
    """The full Linear-status enum must appear as a verbatim set token —
    a substring-only check for `planning`/`active`/`completed`/`killed` can
    false-positive on incidental prose use (`active` is a common English word).
    """
    body = read_command()
    expected = "{planning, active, completed, killed}"
    assert expected in body, (
        f"Linear-status enum set must appear verbatim. Expected: {expected!r}"
    )


def test_dry_run_wins_over_noop() -> None:
    """Per code-reviewer's P2 finding: `--dry-run` must always emit
    `dry_run:true` shape, never `noop:true`, regardless of current SF state.
    Phase 4 (dry-run) must precede Phase 5 (noop).
    """
    body = read_command()
    dry_run_pos = body.find("## Phase 4 — Dry-run preview")
    noop_pos = body.find("## Phase 5 — Idempotency no-op pre-check")
    assert dry_run_pos > 0, "Phase 4 (Dry-run preview) heading not found"
    assert noop_pos > 0, "Phase 5 (Idempotency no-op pre-check) heading not found"
    assert dry_run_pos < noop_pos, (
        "Dry-run preview (Phase 4) must precede idempotency no-op pre-check (Phase 5) "
        "so `--dry-run` always wins over noop short-circuit"
    )


def test_dry_run_no_write_documented() -> None:
    """Beyond Phase 4/5 ordering, the body must explicitly assert that
    `--dry-run` exits without invoking the SF write. A future refactor could
    keep the heading order but leak the UPDATE into the dry-run branch.
    """
    body = read_command()
    # Look for either "NO UPDATE attempted" or "exit without writing" near "dry-run" / "--dry-run".
    pattern = re.compile(
        r"(?:--dry-run|dry-run|`--dry-run`).{0,400}?"
        r"(?:NO UPDATE attempted|exit without writing)",
        re.DOTALL | re.IGNORECASE,
    )
    assert pattern.search(body), (
        "Body must explicitly state that `--dry-run` exits WITHOUT performing the "
        "SF UPDATE (e.g., `NO UPDATE attempted` or `exit without writing`) — "
        "the heading-order test alone doesn't catch a future leak of Phase 6 into "
        "the dry-run branch"
    )


def test_plugin_json_version_bumped() -> None:
    """CLAUDE.md plugin-cache gotcha: bumping plugin.json without bumping the
    matching marketplace.json entry leaves clients serving stale content.
    BC-8723 adds a new command, so version MUST be > 0.2.7 in BOTH files.
    """
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    assert plugin_data["version"] != "0.2.7", (
        "plugin.json revops version must be bumped from 0.2.7 — BC-8723 adds a new command "
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
