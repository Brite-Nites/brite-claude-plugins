"""Contract tests for the /marketing:import-campaign slash command (BC-11849).

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared tools, documented
flags, soft-fail composition, v2 manifest shape, slug regex, idempotency gate,
non-goals, version bump) rather than runtime execution. The deterministic
compose/classify logic in plugins/marketing/scripts/import_campaign.py has its
own behavioural harness at scripts/test_import_campaign.sh; these tests own the
*command contract* + a cross-file lock that ties the command, the helper, and
the canonical schema (schema.json#/definitions/campaign_manifest) together.

Pattern mirrors plugins/marketing/tests/test_plan_campaign_contracts.py.
Brite CI does not invoke pytest, so these are dev-runnable contract assertions.
Run with `python3 -m pytest plugins/marketing/tests/test_import_campaign_contracts.py`.
"""

from __future__ import annotations

import json
import re
import sys
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "import-campaign.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"
CANONICALS_DIR = ROOT / "data" / "canonicals"
SCHEMA_JSON = CANONICALS_DIR / "schema.json"
HELPER_PATH = ROOT / "scripts" / "import_campaign.py"
ADR_020 = ROOT.parents[1] / "docs" / "decisions" / "020-gtm-campaign-manifest-schema-v2.md"
# Sibling skill that import-campaign composes via the Skill tool — cross-file
# parity for the σ3 soft-fail contract.
REVOPS_CREATE_PATH = ROOT.parents[0] / "revops" / "commands" / "create-sf-campaign.md"

# Authoritative campaign-slug regex (helper's CAMPAIGN_SLUG_RE). The command
# restates it for operator clarity; the helper enforces it. Both must carry the
# byte-identical pattern or import computes slugs the helper rejects.
EXPECTED_SLUG_RE = r"^[a-z][a-z0-9]*(-[a-z0-9]+)*-fy\d{2}-m\d{2}(-v\d+)?$"

# Version floor — import-campaign ships as marketing >= 0.12.0 (new command =
# minor bump per CLAUDE.md plugin-cache gotcha; baseline is the pre-BC-11849
# 0.11.5 release this builds on).
VERSION_BASELINE = "0.11.5"


@lru_cache(maxsize=1)
def read_command() -> str:
    return COMMAND_PATH.read_text(encoding="utf-8")


@lru_cache(maxsize=1)
def read_helper() -> str:
    return HELPER_PATH.read_text(encoding="utf-8")


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


@lru_cache(maxsize=1)
def split_frontmatter() -> tuple[str, str]:
    match = _FRONTMATTER_RE.match(read_command())
    if not match:
        raise AssertionError("Expected YAML frontmatter wrapped in --- markers")
    return match.group(1), match.group(2)


def parse_allowed_tools_set() -> set[str]:
    """Tokenize the allowed-tools line into a clean set of tool names.

    Scopes to the allowed-tools line ONLY (avoids description-prose / comment
    false positives), splits on commas, strips whitespace.
    """
    frontmatter, _ = split_frontmatter()
    tools_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
        None,
    )
    if tools_line is None:
        raise AssertionError("allowed-tools line not found in frontmatter")
    return {t.strip() for t in tools_line.split(":", 1)[1].split(",") if t.strip()}


def extract_section(body: str, start_marker: str, end_marker: str | None = None) -> str:
    """Extract the substring between two markdown markers. Both markers MUST be
    found when provided (no silent fall-through to body[start:])."""
    start = body.find(start_marker)
    if start < 0:
        raise AssertionError(f"Section start marker not found: {start_marker!r}")
    if end_marker is None:
        return body[start:]
    end = body.find(end_marker, start + len(start_marker))
    if end < 0:
        raise AssertionError(
            f"Section end marker not found: {end_marker!r} (after start {start_marker!r})."
        )
    return body[start:end]


def _parse_semver(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


# --- File existence + frontmatter shape ------------------------------------


def test_command_file_exists() -> None:
    assert COMMAND_PATH.is_file(), f"Slash command file missing: {COMMAND_PATH}"


def test_helper_exists_and_referenced() -> None:
    assert HELPER_PATH.is_file(), f"Compose helper missing: {HELPER_PATH}"
    assert "import_campaign.py" in read_command(), (
        "Command body must cite the import_campaign.py helper it delegates "
        "manifest composition + audience_tier classification to."
    )


def test_frontmatter_has_description_argument_hint_and_allowed_tools() -> None:
    frontmatter, _ = split_frontmatter()
    assert re.search(r"^description: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare a `description` field"
    assert re.search(r"^argument-hint: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare an `argument-hint` field (operator UX)"
    assert re.search(r"^allowed-tools: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare an `allowed-tools` field"


# --- allowed-tools surface --------------------------------------------------


def test_allowed_tools_includes_skill_for_revops_composition() -> None:
    """σ3 SF Campaign create is composed via the Skill tool (BC-8717 pattern).
    Skill must be in allowed-tools or composition fails silently at runtime."""
    assert "Skill" in parse_allowed_tools_set(), (
        "allowed-tools must include `Skill` — import composes /revops:create-sf-campaign."
    )


def test_allowed_tools_includes_eb_read_tools() -> None:
    """Import READS existing EB records via list_campaigns on BOTH workspaces.
    The EB MCPs register at user level (no plugin_ namespace prefix)."""
    tools = parse_allowed_tools_set()
    for tool in (
        "mcp__emailbison-b2b__list_campaigns",
        "mcp__emailbison-personal__list_campaigns",
    ):
        assert tool in tools, f"allowed-tools must include EB read tool {tool!r}"


def test_allowed_tools_includes_linear_and_sf_read_tools() -> None:
    tools = parse_allowed_tools_set()
    expected = {
        "mcp__plugin_workflows_linear-server__get_milestone",
        "mcp__plugin_workflows_linear-server__get_project",
        "mcp__plugin_revops_salesforce__get_username",
        "AskUserQuestion",
        "Bash",
        "Read",
        "Write",
    }
    missing = expected - tools
    assert not missing, f"allowed-tools missing required read tools: {sorted(missing)}"


def test_allowed_tools_excludes_linear_write_and_eb_get_campaign() -> None:
    """Import is read-only against Linear + EB (it does NOT create milestones,
    sub-issues, or EB campaigns) and must NOT declare get_campaign (404s on
    live IDs per the tracker gotcha). Listing write/broken tools is dead-or-
    dangerous surface."""
    tools = parse_allowed_tools_set()
    forbidden = {
        "mcp__plugin_workflows_linear-server__save_milestone",
        "mcp__plugin_workflows_linear-server__save_issue",
        "mcp__plugin_workflows_linear-server__create_issue_label",
        "mcp__plugin_revops_salesforce__create_sf_campaign",
        "mcp__emailbison-b2b__get_campaign",
        "mcp__emailbison-personal__get_campaign",
    }
    illegal = tools & forbidden
    assert not illegal, (
        f"allowed-tools must NOT include {sorted(illegal)} — import is read-only "
        f"against Linear/EB and must avoid the get_campaign 404 path."
    )


# --- Flag table coverage ----------------------------------------------------


def test_all_documented_flags_present() -> None:
    body = read_command()
    flags = [
        "--linear-milestone",
        "--eb-records",
        "--vertical",
        "--persona",
        "--offer",
        "--entity",
        "--month",
        "--year",
        "--launch-date",
        "--owner-email",
        "--dry-run",
    ]
    missing = [f for f in flags if f not in body]
    assert not missing, f"Flags missing from command body: {missing}"


def test_plan_campaign_only_flags_absent() -> None:
    """Import's scope diverges from plan-campaign: no sub-issue scaffolding, so
    the sub-issue-gating flags must NOT appear (they'd imply behaviour import
    explicitly disowns). Guards against copy-paste drift from plan-campaign."""
    tools_excluded_flags = ["--situation-mining", "--creative-angles", "--theme"]
    body = read_command()
    leaked = [f for f in tools_excluded_flags if f in body]
    assert not leaked, (
        f"plan-campaign-only flags leaked into import-campaign: {leaked}. "
        f"Import does not scaffold sub-issues or cross-entity themes."
    )


# --- Soft-fail composition contract ----------------------------------------


def test_soft_fail_philosophy_documented() -> None:
    body = read_command()
    assert "soft-fail" in body.lower(), \
        "Body must use the term `soft-fail` so the contract is greppable"
    assert "salesforce.campaign_id" in body, \
        "Body must reference the manifest field that captures null on SF soft-fail"


def test_sigma3_skill_composition_and_catalog_reuse() -> None:
    """σ3 create is composed via Skill(revops:create-sf-campaign); the error
    catalog is REUSED from plan-campaign Step 8b.1 (not re-enumerated here) —
    the spec must point at it so the two don't silently drift."""
    body = read_command()
    assert "revops:create-sf-campaign" in body, \
        "Body must compose /revops:create-sf-campaign via the Skill tool"
    assert "8b.1" in body, (
        "Body must cite plan-campaign Step 8b.1 as the σ3 error-kind catalog "
        "source (reuse, not redeclare)."
    )


# --- v2 manifest contract (the load-bearing divergence from plan-campaign) ---


def test_v2_schema_documented() -> None:
    """Import emits schema v2 per ADR-020 — the command documents the v2
    decision and the email_bison.campaigns[] (plural array) shape it composes,
    NOT the v1 singular email_bison.campaign_id. The literal `schema_version`
    field is stamped by the helper (locked separately in the helper-compose
    test), so the command-level contract is the 'schema v2' decision + the
    array-shape reference."""
    body = read_command()
    assert re.search(r"schema[ _-]?v2\b|schema-v2", body, re.IGNORECASE), \
        "Body must document the schema v2 decision (per ADR-020)"
    assert '"campaigns"' in body or "campaigns[]" in body or "eb_records" in body, \
        "Body must reference the v2 email_bison.campaigns[] array (composed from eb_records)"
    # The robust v1-output anti-regression lives in the helper-compose test
    # (test_helper_compose_output_matches_schema_required_keys asserts the
    # emitted email_bison carries `campaigns` and NOT the v1 singular
    # `campaign_id`) — that executes the emitter, so it catches a real revert,
    # which a brittle byte-sequence grep of the markdown cannot.


def test_audience_tier_structured_object_documented() -> None:
    """The v2 audience_tier is a structured {tier, seniority, modifiers} object
    (ADR-020), auto-classified from the EB name. All three axes must appear."""
    body = read_command()
    for axis in ("tier", "seniority", "modifiers"):
        assert axis in body, f"Body must document the audience_tier '{axis}' axis"
    assert "audience_tier" in body, "Body must reference the audience_tier object"


def test_scaffolded_by_field_value() -> None:
    assert '"/marketing:import-campaign"' in read_command(), \
        "scaffolded_by must literally state the importer name (provenance marker)"


def test_created_at_provenance_is_original_launch_not_now() -> None:
    """A defining provenance rule (BC-11849 brief): created_at = original EB
    launch date, NOT the import time."""
    body = read_command().lower()
    assert "launched_at" in body, "created_at derivation must reference EB launched_at"
    assert "not now" in body or "(not now)" in body or "not the import" in body, \
        "Body must state created_at = original launch date, NOT now"


# --- Slug + canonicality contract ------------------------------------------


def test_slug_regex_matches_helper() -> None:
    """The slug regex must appear verbatim in BOTH the command AND the helper
    (import_campaign.py CAMPAIGN_SLUG_RE) — drift lets the spec promise a shape
    the helper rejects."""
    assert EXPECTED_SLUG_RE in read_command(), (
        f"Slug regex must appear verbatim in import-campaign.md: {EXPECTED_SLUG_RE!r}"
    )
    assert EXPECTED_SLUG_RE in read_helper(), (
        f"Slug regex parity broken — import_campaign.py CAMPAIGN_SLUG_RE must be "
        f"{EXPECTED_SLUG_RE!r}."
    )


def test_standard_slug_format_documented() -> None:
    assert "{vertical}-{persona}-{offer}-fy{YY}-m{MM}" in read_command(), \
        "Standard slug format must appear verbatim"


def test_canonicals_hard_fail_documented() -> None:
    body = read_command()
    assert "plugins/marketing/data/canonicals" in body, \
        "Body must reference the canonicals data layer path"
    assert "_manifest.yaml" in body, "Body must reference _manifest.yaml (verticals index)"
    for ptr in ("/marketing:new-vertical", "/marketing:new-persona", "/marketing:new-offer"):
        assert ptr in body, f"Canonicals-miss HARD-FAIL must point to {ptr}"


# --- Idempotency + HARD-FAIL gates -----------------------------------------


def test_idempotency_gate_documented() -> None:
    """Step 3.3 existing-manifest gate fires BEFORE any MCP call — a re-import
    is a true no-op (the brief's idempotency criterion)."""
    body = read_command()
    assert "Step 3.3" in body, "Body must define the Step 3.3 idempotency gate"
    section = extract_section(body, "### 3.3", "## Step 4")
    assert "-f " in section and "exit 0" in section, (
        "Step 3.3 must show the structural `-f` existing-manifest check + early exit 0."
    )


def test_linear_milestone_hard_fail_documented() -> None:
    """Import does NOT auto-create the milestone — not-found is a HARD-FAIL."""
    body = read_command()
    assert "get_milestone" in body, "Body must read the milestone via get_milestone"
    assert "does NOT auto-create" in body or "not auto-create" in body.lower(), \
        "Body must state import does NOT auto-create milestones (HARD-FAIL on miss)"


def test_eb_record_handling_uses_list_campaigns_not_get_campaign() -> None:
    """get_campaign 404s on live IDs (tracker gotcha) — import must use
    list_campaigns + client-side filter, and document the gotcha."""
    body = read_command()
    assert "list_campaigns" in body, "Body must fetch EB records via list_campaigns"
    assert "get_campaign" in body, (
        "Body must document the get_campaign 404 gotcha (so the pattern isn't "
        "silently rolled back to get_campaign)."
    )
    assert not re.search(r"use get_campaign|prefer get_campaign|switch to get_campaign", body, re.IGNORECASE), \
        "Body must NOT recommend get_campaign"


# --- Non-goals: no sub-issue scaffolding -----------------------------------


def test_no_sub_issue_creation() -> None:
    """Import imports an already-launched campaign; it does NOT recreate the
    8-sub-issue chain (plan-campaign's job). save_issue must be absent from
    allowed-tools and the non-goal stated."""
    assert "mcp__plugin_workflows_linear-server__save_issue" not in parse_allowed_tools_set(), \
        "Import must NOT declare save_issue — it creates no sub-issues"
    body = read_command().lower()
    assert "do not create sub-issues" in body or "not mirror plan-campaign's step 9" in body, \
        "Body must state 'no sub-issue creation' as an explicit non-goal"


def test_cross_entity_excluded_in_v1() -> None:
    """Cross-entity is out of import v1 (grill-locked). Step 1b's --entity
    validator is the closed set {nites, supply, labs}."""
    body = read_command()
    section = extract_section(body, "### Step 1b", "## Step 2")
    for value in ("nites", "supply", "labs"):
        assert value in section, f"Step 1b --entity validator must list '{value}'"
    # The closed set is checked above; require the explicit not-supported marker
    # directly (a bare disjunction passed even if the text flipped to "supported").
    assert "not supported" in section.lower(), \
        "Step 1b must explicitly mark cross-entity NOT supported in v1"


# --- Citations --------------------------------------------------------------


def test_bc_and_adr_citations() -> None:
    body = read_command()
    for cite in ("BC-11849", "BC-11852", "ADR-020"):
        assert cite in body, f"Body must cite {cite}"


# --- Plugin version bump (CLAUDE.md plugin-cache gotcha) --------------------


def test_plugin_json_version_bumped() -> None:
    """New command = version STRICTLY GREATER than the 0.11.5 baseline."""
    actual = _parse_semver(json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"])
    assert actual > _parse_semver(VERSION_BASELINE), (
        f"plugin.json marketing version must be > {VERSION_BASELINE} — BC-11849 adds "
        f"a new command (CLAUDE.md plugin-cache gotcha)."
    )


def test_marketplace_json_version_mirrors_plugin_json() -> None:
    plugin_data = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))
    marketplace_data = json.loads(MARKETPLACE_JSON.read_text(encoding="utf-8"))
    entry = next(
        (p for p in marketplace_data["plugins"] if p["name"] == "marketing"),
        None,
    )
    assert entry, "marketing plugin entry missing from marketplace.json"
    assert entry["version"] == plugin_data["version"], (
        f"marketplace.json marketing version ({entry['version']}) must match "
        f"plugin.json ({plugin_data['version']}) — CLAUDE.md plugin-cache gotcha"
    )


# --- Cross-file schema lock (command + helper + schema.json) ----------------


@lru_cache(maxsize=1)
def _schema_campaign_manifest_required() -> tuple[str, ...]:
    schema = json.loads(SCHEMA_JSON.read_text(encoding="utf-8"))
    return tuple(schema["definitions"]["campaign_manifest"]["required"])


def test_schema_campaign_manifest_required_keyset_pinned() -> None:
    """Pin the v2 campaign_manifest required key-set. A schema change forces a
    paired test update — the lock that keeps command/helper/schema in lockstep."""
    expected = {
        "schema_version", "slug", "entity", "vertical", "persona", "offer",
        "year", "month", "linear", "salesforce", "email_bison",
        "created_at", "scaffolded_by",
    }
    actual = set(_schema_campaign_manifest_required())
    assert actual == expected, (
        f"schema.json#/definitions/campaign_manifest required key-set changed: "
        f"expected {sorted(expected)}, got {sorted(actual)}. Update the helper "
        f"+ this lock together."
    )


def test_helper_compose_output_matches_schema_required_keys() -> None:
    """Import the helper, compose a minimal manifest, assert its top-level keys
    are EXACTLY the schema's required set — ties the helper's emitter to the
    canonical v2 contract (the 'indistinguishable from plan-campaign' guard at
    the data layer)."""
    sys.path.insert(0, str(HELPER_PATH.parent))
    import import_campaign as ic  # noqa: E402

    tiers = ic._read_audience_tiers(CANONICALS_DIR / "_manifest.yaml")
    payload = {
        "slug": "bars-restaurants-bar-owner-anchor-audit-fy25-m09",
        "entity": "nites",
        "vertical": "bars-restaurants",
        "persona": "bar-owner",
        "offer": "anchor-audit",
        "year": 2025,
        "month": 9,
        "linear": {"milestone_id": "x", "milestone_url": "https://x", "project": "Brite GTM"},
        "salesforce_campaign_id": None,
        "eb_workspace": "emailbison-b2b",
        "eb_campaign_name": "bars-restaurants-bar-owner-anchor-audit-fy25-m09",
        "eb_records": [],
        "created_at": "2025-09-20T08:00:00Z",
    }
    manifest = ic.compose_manifest(payload, tiers)
    assert set(manifest.keys()) == set(_schema_campaign_manifest_required()), (
        f"helper compose output keys {sorted(manifest.keys())} must equal the "
        f"schema's required key-set {sorted(_schema_campaign_manifest_required())}."
    )
    assert manifest["schema_version"] == 2, "helper must emit schema_version 2"
    assert "campaigns" in manifest["email_bison"], "v2 email_bison must carry campaigns[]"
    assert "campaign_id" not in manifest["email_bison"], \
        "v2 email_bison must NOT carry the v1 singular campaign_id"
