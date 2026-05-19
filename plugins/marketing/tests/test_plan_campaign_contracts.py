"""Contract tests for the /marketing:plan-campaign slash command (BC-8724).

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared tools, documented
flags, soft-fail composition pattern, soft-fail error key handling, schema
fields, sub-issue chain, slug regex) rather than runtime execution. Runtime
validation happens at BC-8727 (the first dogfood campaign).

Pattern mirrors plugins/revops/tests/test_create_sf_campaign_contracts.py.
Brite CI does not invoke pytest (per .github/dependabot.yml comment), so these
are dev-runnable contract assertions. Run with `pytest plugins/marketing/tests/`
or `python3 -m pytest plugins/marketing/tests/`.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "plan-campaign.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"
CANONICALS_DIR = ROOT / "data" / "canonicals"


def read_command() -> str:
    return COMMAND_PATH.read_text()


def split_frontmatter(text: str) -> tuple[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, "Expected YAML frontmatter wrapped in --- markers"
    return match.group(1), match.group(2)


# --- File existence + frontmatter shape ------------------------------------


def test_command_file_exists() -> None:
    assert COMMAND_PATH.is_file(), f"Slash command file missing: {COMMAND_PATH}"


def test_frontmatter_has_description_argument_hint_and_allowed_tools() -> None:
    frontmatter, _ = split_frontmatter(read_command())
    assert re.search(r"^description: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare a `description` field"
    assert re.search(r"^argument-hint: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare an `argument-hint` field (operator UX)"
    assert re.search(r"^allowed-tools: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare an `allowed-tools` field"


def test_allowed_tools_includes_skill_for_revops_composition() -> None:
    """BC-8717 respec contract: this orchestrator composes /revops:create-sf-campaign
    via the Skill tool. The Skill tool MUST be in allowed-tools or composition fails
    silently with `tool not found` at runtime.
    """
    frontmatter, _ = split_frontmatter(read_command())
    tools_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
        None,
    )
    assert tools_line, "allowed-tools line not found"
    assert "Skill" in tools_line, (
        "allowed-tools must include `Skill` — the orchestrator composes /revops:create-sf-campaign "
        "(BC-8717) via the Skill tool, not via a direct MCP write tool (which doesn't exist)."
    )


def test_allowed_tools_excludes_nonexistent_mcp_write_tools() -> None:
    """The original BC-8724 spec listed mcp__plugin_revops_salesforce__create_sf_campaign
    in allowed-tools — but that MCP write tool does NOT exist (BC-8717 was respec'd
    from MCP tool to slash command on 2026-05-19, PR #329). Listing a non-existent
    MCP tool fails silently at runtime (per CLAUDE.md gotcha on allowed-tools).
    """
    frontmatter, _ = split_frontmatter(read_command())
    forbidden = [
        "mcp__plugin_revops_salesforce__create_sf_campaign",
        "mcp__plugin_revops_salesforce__update_sf_campaign_status",
    ]
    for tool in forbidden:
        assert tool not in frontmatter, (
            f"allowed-tools must NOT include {tool} — that MCP write tool does not exist "
            f"(BC-8717/BC-8723 respec'd 2026-05-19). Use Skill tool to compose the sibling slash command."
        )


def test_allowed_tools_includes_linear_and_sf_read_tools() -> None:
    frontmatter, _ = split_frontmatter(read_command())
    expected = [
        "mcp__plugin_workflows_linear-server__list_projects",
        "mcp__plugin_workflows_linear-server__list_milestones",
        "mcp__plugin_workflows_linear-server__save_milestone",
        "mcp__plugin_workflows_linear-server__save_issue",
        "mcp__plugin_revops_salesforce__get_username",
        "AskUserQuestion",
        "Bash",
        "Read",
        "Write",
    ]
    missing = [tool for tool in expected if tool not in frontmatter]
    assert not missing, f"allowed-tools missing required tools: {missing}"


# --- Flag table coverage ---------------------------------------------------


def test_all_documented_flags_present() -> None:
    body = read_command()
    flags = [
        "--vertical",
        "--persona",
        "--offer",
        "--entity",
        "--month",
        "--year",
        "--launch-date",
        "--owner-email",
        "--eb-workspace",
        "--theme",
        "--situation-mining",
        "--creative-angles",
        "--dry-run",
    ]
    missing = [f for f in flags if f not in body]
    assert not missing, f"Flags missing from command body: {missing}"


# --- Soft-fail composition contract ----------------------------------------


def test_soft_fail_philosophy_documented() -> None:
    """Step 8b is soft-fail per BC-8724 design — SF auto-create failure
    must NOT halt scaffolding. The body must explicitly document this contract.
    """
    body = read_command()
    assert "soft-fail" in body.lower(), \
        "Body must use the term `soft-fail` so the contract is greppable"
    assert "salesforce.campaign_id" in body, \
        "Body must reference the manifest field that captures null on SF soft-fail"


def test_all_soft_fail_error_keys_handled() -> None:
    """The 5 error kinds emitted by /revops:create-sf-campaign (BC-8717) must
    each have a documented manifest action + Step 11 reminder in this orchestrator.
    """
    body = read_command()
    error_keys = [
        "duplicate_slug",
        "missing_owner",
        "sf_cli_error",
        "invalid_slug_format",
        "missing_required_flag",
    ]
    missing = [key for key in error_keys if key not in body]
    assert not missing, f"Error keys from /revops:create-sf-campaign not handled here: {missing}"


# --- Slug + canonicality contract ------------------------------------------


def test_slug_regex_matches_create_sf_campaign() -> None:
    """The slug regex must match /revops:create-sf-campaign's Phase 1 regex
    EXACTLY — otherwise plan-campaign could compute a slug that the sibling
    skill rejects at the boundary.
    """
    body = read_command()
    expected = r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$"
    assert expected in body, (
        f"Slug regex must appear verbatim and match BC-8717's regex. Expected: {expected!r}"
    )


def test_standard_slug_format_documented() -> None:
    body = read_command()
    expected = "{vertical}-{persona}-{offer}-fy{YY}-m{MM}"
    assert expected in body, (
        f"Standard slug format must appear verbatim. Expected: {expected!r}"
    )


def test_cross_entity_slug_format_documented() -> None:
    body = read_command()
    expected = "cross-entity-{theme}-fy{YY}-m{MM}"
    assert expected in body, (
        f"Cross-entity slug format must appear verbatim. Expected: {expected!r}"
    )


def test_target_personas_runtime_check_documented() -> None:
    """The per-offer target_personas membership check is BC-8724's runtime
    addition over the canonicals lint (which catches referential integrity
    but not the campaign-targeting tuple).
    """
    body = read_command()
    assert "target_personas" in body, \
        "Step 2 must document the offer.target_personas runtime membership check"


def test_canonicals_path_referenced() -> None:
    body = read_command()
    assert "plugins/marketing/data/canonicals" in body, \
        "Body must reference the canonicals data layer path"
    assert "_manifest.yaml" in body, \
        "Body must reference _manifest.yaml (the verticals index)"


# --- Manifest schema contract ----------------------------------------------


def test_manifest_schema_keys_present() -> None:
    """The manifest.json schema (Step 7) is THE cross-layer index — its keys
    are consumed by downstream skills (launch-campaign, campaign-debrief,
    campaign-analysis, etc.). Schema regressions break every consumer.
    """
    body = read_command()
    expected_keys = [
        '"schema_version"',
        '"slug"',
        '"entity"',
        '"vertical"',
        '"persona"',
        '"offer"',
        '"year"',
        '"month"',
        '"linear"',
        '"salesforce"',
        '"email_bison"',
        '"created_at"',
        '"scaffolded_by"',
        '"milestone_id"',
        '"milestone_url"',
        '"campaign_id"',
        '"campaign_name"',
        '"workspace"',
        '"launched_at"',
    ]
    missing = [k for k in expected_keys if k not in body]
    assert not missing, f"Manifest schema keys missing from Step 7 spec: {missing}"


def test_manifest_path_format_documented() -> None:
    body = read_command()
    expected = "docs/campaigns/{entity}/{slug}/manifest.json"
    assert expected in body or "docs/campaigns/<entity>/<slug>/manifest.json" in body, (
        "Manifest path format must appear in Step 7 spec"
    )


def test_scaffolded_by_field_value() -> None:
    body = read_command()
    assert '"/marketing:plan-campaign"' in body, \
        "scaffolded_by field must literally state the orchestrator name for trace"


# --- Sub-issue chain contract ----------------------------------------------


def test_eight_standard_sub_issues_present() -> None:
    body = read_command()
    titles = [
        "Brief approved",
        "Target list built",
        "Copy written + approved",
        "Salesforce setup",
        "Pre-launch QA",
        "Launch executed",
        "Active management",
        "Campaign closed + debrief",
    ]
    missing = [t for t in titles if t not in body]
    assert not missing, f"Standard sub-issue titles missing: {missing}"


def test_two_optional_sub_issues_present() -> None:
    body = read_command()
    assert "Situation Mining" in body, "Optional sub-issue #9 (Situation Mining) must be documented"
    assert "Creative Angles" in body, "Optional sub-issue #10 (Creative Angles) must be documented"


def test_situation_mining_labs_gated() -> None:
    body = read_command()
    assert "Labs" in body and "--situation-mining" in body, \
        "--situation-mining must be Labs-gated (HARD-FAIL on non-Labs entity)"


def test_blocked_by_chain_documented() -> None:
    body = read_command()
    assert "blockedBy" in body, \
        "Sub-issue chain must reference blockedBy relations explicitly"
    assert "blocks #2" in body or "blocks: #2" in body or "blocks all downstream" in body.lower(), \
        "Step 9 must document that sub-issue #1 (Brief) gates the rest"


# --- EB workspace map + entity coverage ------------------------------------


def test_eb_workspace_map_documented() -> None:
    body = read_command()
    assert "emailbison-personal" in body, "EB workspace personal must be in entity map"
    assert "emailbison-b2b" in body, "EB workspace b2b must be in entity map"
    for entity in ["nites", "supply", "labs", "cross-entity"]:
        assert entity in body, f"Entity '{entity}' must appear in the entity ↔ EB workspace map"


# --- Two-call confirm gate -------------------------------------------------


def test_two_call_confirm_documented() -> None:
    body = read_command()
    assert "BC-2707" in body, \
        "Step 6 must cite BC-2707 precedent for the two-call confirm semantics"
    assert "AskUserQuestion" in body, \
        "Step 6 must use AskUserQuestion (per BC-2707 turn-structure precedent)"


# --- Brite GTM project dependency ------------------------------------------


def test_brite_gtm_project_referenced() -> None:
    body = read_command()
    assert "Brite GTM" in body, \
        "Body must reference the Brite GTM Linear project (Phase 0 / BC-8712 dependency)"


# --- Plugin version bump (CLAUDE.md plugin-cache gotcha) -------------------


def test_plugin_json_version_bumped() -> None:
    """BC-8724 adds a new command — version MUST be > 0.3.38 in plugin.json."""
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    assert plugin_data["version"] != "0.3.38", (
        "plugin.json marketing version must be bumped from 0.3.38 — BC-8724 adds a new command "
        "and clients' plugin cache is keyed by version (CLAUDE.md plugin-cache gotcha)."
    )


def test_marketplace_json_version_mirrors_plugin_json() -> None:
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    marketplace_data = json.loads(MARKETPLACE_JSON.read_text())

    marketing_entry = next(
        (p for p in marketplace_data["plugins"] if p["name"] == "marketing"),
        None,
    )
    assert marketing_entry, "marketing plugin entry missing from marketplace.json"
    assert marketing_entry["version"] == plugin_data["version"], (
        f"marketplace.json marketing version ({marketing_entry['version']}) must match "
        f"plugin.json ({plugin_data['version']}) — per CLAUDE.md plugin-cache gotcha"
    )


# --- Canonicals integration ------------------------------------------------


def test_municipalities_canonical_exists_for_dogfood_validation() -> None:
    """Step 2 validation example uses municipalities × parks-rec-director × parks-bond.
    These slugs must exist in canonicals (otherwise the dry-run example in the
    PR review would fail).
    """
    manifest_path = CANONICALS_DIR / "_manifest.yaml"
    municipalities_path = CANONICALS_DIR / "municipalities.yaml"

    assert manifest_path.is_file(), "_manifest.yaml must exist (BC-8718 dependency)"
    assert municipalities_path.is_file(), \
        "municipalities.yaml must exist for plan-campaign's dry-run validation example"

    muni_text = municipalities_path.read_text()
    assert "parks-rec-director" in muni_text, \
        "municipalities.yaml must define `parks-rec-director` persona (used in test fixtures)"
    assert "parks-bond" in muni_text, \
        "municipalities.yaml must define `parks-bond` offer (used in test fixtures)"


# --- Memory gotcha cross-references ----------------------------------------


def test_known_gotchas_cited() -> None:
    """The body must cite the relevant memory gotchas so reviewers can audit
    why specific patterns were chosen.
    """
    body = read_command()
    gotchas = [
        "gotcha_linear_save_issue_parent_id",
        "gotcha_sf_mcp_username_not_alias",
        "gotcha_askuserquestion_no_free_text",
    ]
    missing = [g for g in gotchas if g not in body]
    assert not missing, f"Memory gotchas not cited in body: {missing}"


# --- Idempotency contract --------------------------------------------------


def test_idempotency_section_present() -> None:
    body = read_command()
    assert "Idempotency" in body, \
        "Body must document the orchestrator's idempotency behavior (partial-idempotency)"
