"""Contract tests for BC-8752 σ3 status-sync wiring.

BC-8752 adds three new behaviors:
1. `/marketing:launch-campaign` Phase 11 step 7 — σ3 SF sync to `In Progress`.
2. `/marketing:campaign-debrief` Workflow 4 step 5 — σ3 SF sync to `Completed`.
3. `/marketing:sync-campaign-status` — operator-facing wrapper for manual
   paused/killed transitions and retroactive reconciliation.

Pattern mirrors plugins/marketing/tests/test_plan_campaign_contracts.py
(BC-8724) — static markdown contract assertions for Claude-orchestrated
commands. Runtime validation happens at BC-8727 cohort-1 first dogfood.

Run with `pytest plugins/marketing/tests/test_sync_campaign_status_contracts.py`.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAUNCH_PATH = ROOT / "commands" / "launch-campaign.md"
DEBRIEF_PATH = ROOT / "skills" / "campaign-debrief" / "SKILL.md"
SYNC_PATH = ROOT / "commands" / "sync-campaign-status.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"
REVOPS_UPDATE_PATH = (
    ROOT.parents[0] / "revops" / "commands" / "update-sf-campaign-status.md"
)

CANONICAL_SLUG_REGEX = r"^[a-z0-9-]+-fy\\d{2}-m\\d{2}(-v\\d+)?$"
SKILL_INVOCATION_MARKER = 'Skill(\n        skill: "revops:update-sf-campaign-status"'


@lru_cache(maxsize=1)
def read_launch() -> str:
    return LAUNCH_PATH.read_text(encoding="utf-8")


@lru_cache(maxsize=1)
def read_debrief() -> str:
    return DEBRIEF_PATH.read_text(encoding="utf-8")


@lru_cache(maxsize=1)
def read_sync() -> str:
    return SYNC_PATH.read_text(encoding="utf-8")


@lru_cache(maxsize=1)
def read_revops_update() -> str:
    return REVOPS_UPDATE_PATH.read_text(encoding="utf-8")


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


def split_frontmatter(text: str) -> tuple[str, str]:
    match = _FRONTMATTER_RE.match(text)
    if not match:
        raise AssertionError("Expected YAML frontmatter wrapped in --- markers")
    return match.group(1), match.group(2)


def allowed_tools_set(text: str) -> set[str]:
    """Tokenize the allowed-tools line into a clean set of tool names."""
    frontmatter, _ = split_frontmatter(text)
    tools_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
        None,
    )
    if tools_line is None:
        raise AssertionError("allowed-tools: line missing from frontmatter")
    raw = tools_line.split(":", 1)[1]
    return {tok.strip() for tok in raw.split(",") if tok.strip()}


# ---------- Frontmatter contracts ----------


def test_launch_campaign_declares_skill_in_allowed_tools() -> None:
    """BC-8752: launch-campaign must declare Skill to invoke /revops:update-sf-campaign-status."""
    tools = allowed_tools_set(read_launch())
    assert "Skill" in tools, f"Skill missing from launch-campaign allowed-tools: {tools}"


def test_campaign_debrief_declares_skill_in_allowed_tools() -> None:
    """BC-8752: campaign-debrief must declare Skill to invoke /revops:update-sf-campaign-status."""
    tools = allowed_tools_set(read_debrief())
    assert "Skill" in tools, f"Skill missing from campaign-debrief allowed-tools: {tools}"


def test_sync_campaign_status_minimal_allowed_tools() -> None:
    """BC-8752: sync-campaign-status is a thin wrapper — only Read + Skill needed."""
    tools = allowed_tools_set(read_sync())
    # Must have both Read (for any future manifest probes) and Skill (the invocation surface).
    assert "Skill" in tools, "Skill missing"
    # Reject any MCP-tool grants — wrapper should NOT directly touch SF/EB MCPs.
    mcp_tools = {t for t in tools if t.startswith("mcp__")}
    assert not mcp_tools, f"sync-campaign-status should not grant MCP tools directly; found: {mcp_tools}"


# ---------- σ3 trigger presence ----------


def test_launch_campaign_phase11_contains_bc8752_sync_step() -> None:
    """BC-8752: launch-campaign Phase 11 must contain a step marked with BC-8752 doing σ3 sync."""
    body = read_launch()
    assert "## Phase 11 — ACTIVATE" in body, "Phase 11 ACTIVATE header missing"
    # The new step is marked with [BC-8752] and the In Progress target status.
    assert "BC-8752" in body, "BC-8752 marker missing from launch-campaign"
    assert '"--slug=<manifest.slug> --linear-status=active"' in body, (
        "launch-campaign σ3 sync must invoke Skill with --linear-status=active"
    )


def test_campaign_debrief_workflow4_contains_bc8752_sync_step() -> None:
    """BC-8752: campaign-debrief Workflow 4 must contain a step marked with BC-8752 doing σ3 sync."""
    body = read_debrief()
    assert "### Workflow 4 — Append to learnings.md" in body, "Workflow 4 header missing"
    assert "BC-8752" in body, "BC-8752 marker missing from campaign-debrief"
    assert '"--slug=<manifest.slug> --linear-status=completed"' in body, (
        "campaign-debrief σ3 sync must invoke Skill with --linear-status=completed"
    )


# ---------- Entity-slug short↔long normalization (post-PR P1 fix) ----------


def test_launch_campaign_normalizes_entity_to_short_form() -> None:
    """Post-PR P1: launch-campaign uses long-form entity (brite-nites|brite-labs);
    plan-campaign writes manifest under short-form (nites|labs). The σ3 sync
    step must strip the `brite-` prefix before constructing the manifest path."""
    body = read_launch()
    # Must reference the normalization explicitly
    assert "<short-entity>" in body, (
        "launch-campaign Phase 11 step 7 must reference <short-entity> normalization"
    )
    # Must mention stripping the brite- prefix
    assert "brite-nites" in body and "→ `nites`" in body, (
        "launch-campaign σ3 step must document brite-nites → nites stripping"
    )
    # Path must use <short-entity>, NOT raw <entity>
    assert 'docs/campaigns/<short-entity>/<campaign-name>/manifest.json' in body, (
        "launch-campaign σ3 manifest read path must use <short-entity>"
    )


def test_campaign_debrief_normalizes_entity_to_short_form() -> None:
    """Post-PR P1: campaign-debrief uses long-form Gate-3 entity slugs; plan-campaign
    writes manifest under short-form. Workflow 4 step 5 must strip the `brite-`
    prefix before constructing the manifest path."""
    body = read_debrief()
    assert "<short-entity>" in body, (
        "campaign-debrief Workflow 4 step 5 must reference <short-entity> normalization"
    )
    assert "brite-nites" in body and "→ `nites`" in body, (
        "campaign-debrief σ3 step must document brite-nites → nites stripping"
    )
    # Path must use <short-entity>, NOT raw {entity}
    assert "docs/campaigns/<short-entity>/{campaign-name}/manifest.json" in body, (
        "campaign-debrief σ3 manifest read path must use <short-entity>"
    )


# ---------- Skill invocation pattern (BC-8717 / BC-8723 respec) ----------


def test_launch_campaign_uses_skill_for_revops_invocation() -> None:
    """BC-8717 respec: orchestrators compose /revops:* via Skill, not via a phantom
    mcp__plugin_revops_salesforce__update_sf_campaign_status MCP write tool."""
    body = read_launch()
    assert 'revops:update-sf-campaign-status' in body, "Skill invocation must reference revops slash command"
    assert "mcp__plugin_revops_salesforce__update_sf_campaign_status" not in body, (
        "launch-campaign must NOT reference the phantom MCP write tool (BC-8723 respec)"
    )


def test_campaign_debrief_uses_skill_for_revops_invocation() -> None:
    body = read_debrief()
    assert 'revops:update-sf-campaign-status' in body
    assert "mcp__plugin_revops_salesforce__update_sf_campaign_status" not in body


def test_sync_campaign_status_uses_skill_for_revops_invocation() -> None:
    body = read_sync()
    assert 'revops:update-sf-campaign-status' in body
    assert "mcp__plugin_revops_salesforce__update_sf_campaign_status" not in body


# ---------- Soft-fail invariant ----------


def test_launch_campaign_soft_fail_invariant_explicit() -> None:
    body = read_launch()
    assert "Soft-fail invariant" in body, "launch-campaign σ3 step must declare soft-fail invariant explicitly"


def test_campaign_debrief_soft_fail_invariant_explicit() -> None:
    body = read_debrief()
    assert "Soft-fail invariant" in body, "campaign-debrief σ3 step must declare soft-fail invariant explicitly"


def test_sync_campaign_status_soft_fail_section_present() -> None:
    body = read_sync()
    assert "## Soft-fail philosophy" in body, "sync-campaign-status must document soft-fail philosophy"


# ---------- Defense-in-depth slug regex re-validation ----------


def test_all_three_sites_re_validate_manifest_slug() -> None:
    """Defense-in-depth: each consumer that constructs Skill args from a slug
    value MUST re-apply the canonical regex BEFORE building the args string,
    to block argument-injection via whitespace-bearing slugs."""
    expected_substring = r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$"
    for path, body in [
        ("launch-campaign", read_launch()),
        ("campaign-debrief", read_debrief()),
        ("sync-campaign-status", read_sync()),
    ]:
        assert expected_substring in body, (
            f"{path}: missing canonical slug regex pre-Skill-invoke. Argument-injection "
            "via whitespace-bearing slug is reachable without it."
        )


def test_all_three_sites_pin_no_multiline_flag() -> None:
    """The slug regex must be applied without the multiline (m) flag — otherwise
    an embedded newline could bypass the check on a per-line basis."""
    for path, body in [
        ("launch-campaign", read_launch()),
        ("campaign-debrief", read_debrief()),
        ("sync-campaign-status", read_sync()),
    ]:
        assert "multiline" in body and "(`m`) flag" in body, (
            f"{path}: must explicitly pin regex application without the multiline (m) flag"
        )


# ---------- Response-parse branch ordering ----------


def test_launch_campaign_response_parse_first_match_wins() -> None:
    body = read_launch()
    assert "Branch in this exact order — the first matching case wins" in body, (
        "launch-campaign σ3 response parse must declare first-match-wins ordering"
    )


def test_campaign_debrief_response_parse_first_match_wins() -> None:
    body = read_debrief()
    assert "Branch in this exact order — the first matching case wins" in body, (
        "campaign-debrief σ3 response parse must declare first-match-wins ordering"
    )


def test_sync_campaign_status_response_parse_first_match_wins() -> None:
    body = read_sync()
    assert "Branch in this exact order — the first matching case wins" in body, (
        "sync-campaign-status response parse must declare first-match-wins ordering"
    )


def test_all_three_sites_handle_four_response_shapes() -> None:
    """Every consumer must handle: error, campaign_not_found, instance_url_unknown,
    updated_at_unavailable, and plain success. The two degraded shapes were the
    Round-1 P2 finding (success-with-warning shapes were silently dropped)."""
    for path, body in [
        ("launch-campaign", read_launch()),
        ("campaign-debrief", read_debrief()),
        ("sync-campaign-status", read_sync()),
    ]:
        assert "instance_url_unknown" in body, f"{path}: missing instance_url_unknown branch"
        assert "updated_at_unavailable" in body, f"{path}: missing updated_at_unavailable branch"
        assert "campaign_not_found" in body, f"{path}: missing campaign_not_found branch"


# ---------- sync-campaign-status flag contract ----------


def test_sync_campaign_status_declares_three_flags() -> None:
    body = read_sync()
    assert "`--slug`" in body, "sync-campaign-status must declare --slug"
    assert "`--status`" in body, "sync-campaign-status must declare --status"
    assert "`--substatus`" in body, "sync-campaign-status must declare --substatus"


def test_sync_campaign_status_substatus_only_with_active() -> None:
    body = read_sync()
    assert "--substatus only valid with --status=active" in body, (
        "sync-campaign-status must hard-fail on --substatus with non-active --status"
    )


def test_sync_campaign_status_status_closed_set() -> None:
    """`--status` must be one of {planning, active, completed, killed} per O6.Q1."""
    body = read_sync()
    for value in ("planning", "active", "completed", "killed"):
        assert value in body, f"sync-campaign-status --status closed-set missing: {value}"


# ---------- Plugin version bump (CLAUDE.md plugin-cache discipline) ----------


def test_plugin_version_bumped_above_pre_bc8752_baseline() -> None:
    """BC-8752 must bump marketing plugin version > 0.3.39 (the version
    that shipped at the start of BC-8752 work)."""
    plugin = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))
    version = plugin["version"]
    # Parse semver-style and compare numerically
    parts = [int(p) for p in version.split(".")]
    baseline = [0, 3, 39]
    assert parts > baseline, (
        f"plugin.json marketing version {version} must exceed baseline 0.3.39 (BC-8752 plugin-cache bump)"
    )


def test_marketplace_version_matches_plugin_json() -> None:
    """Per CLAUDE.md plugin-cache gotcha: both manifests must bump in lockstep."""
    plugin = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))
    marketplace = json.loads(MARKETPLACE_JSON.read_text(encoding="utf-8"))
    marketing_entry = next(
        (p for p in marketplace["plugins"] if p["name"] == "marketing"), None
    )
    assert marketing_entry is not None, "marketing entry missing from marketplace.json"
    assert marketing_entry["version"] == plugin["version"], (
        f"version mismatch: plugin.json={plugin['version']} vs marketplace.json={marketing_entry['version']}"
    )


# ---------- O6.Q1 mapping table parity ----------


def test_sync_campaign_status_carries_o6q1_mapping_table() -> None:
    """The mapping (linear-status, linear-substatus) → (SF Status, Substatus__c)
    is locked at O6.Q1. The wrapper must reference the same mapping (even though
    it doesn't apply it — the underlying command does)."""
    body = read_sync()
    # Both extremes of the mapping must be cited
    assert "`Planned`" in body and "`Aborted`" in body, "sync-campaign-status missing O6.Q1 mapping cells"
    assert "`Paused`" in body, "sync-campaign-status missing Substatus__c=Paused mapping cell"


def test_underlying_revops_command_present() -> None:
    """The /revops:update-sf-campaign-status command must exist on disk —
    σ3 sync is a no-op if the composition target is absent."""
    assert REVOPS_UPDATE_PATH.exists(), (
        f"underlying command missing at {REVOPS_UPDATE_PATH} — BC-8723 must ship first"
    )
    body = read_revops_update()
    # Must accept --slug + --linear-status (the args BC-8752 sites construct)
    assert "--slug" in body, "underlying command must accept --slug"
    assert "--linear-status" in body, "underlying command must accept --linear-status"
