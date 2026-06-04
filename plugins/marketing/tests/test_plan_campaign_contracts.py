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
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "plan-campaign.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"
CANONICALS_DIR = ROOT / "data" / "canonicals"
# Sibling skill that plan-campaign composes via Skill tool — used for cross-file
# parity assertions (slug regex, error catalog) so the two surfaces don't drift.
REVOPS_CREATE_PATH = (
    ROOT.parents[0] / "revops" / "commands" / "create-sf-campaign.md"
)


@lru_cache(maxsize=1)
def read_command() -> str:
    """Read the command body once per session.

    Cached because 30+ tests call this and the file is ~30KB — without caching
    the suite re-reads ~900KB of disk content per run, all to assert against
    the same content. Explicit UTF-8 encoding to avoid locale-dependent decoding.
    """
    return COMMAND_PATH.read_text(encoding="utf-8")


@lru_cache(maxsize=1)
def read_sibling_create_sf_campaign() -> str:
    """Read plugins/revops/commands/create-sf-campaign.md once per session."""
    return REVOPS_CREATE_PATH.read_text(encoding="utf-8")


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


@lru_cache(maxsize=1)
def split_frontmatter() -> tuple[str, str]:
    """Cached parse of (frontmatter, body) for read_command()'s output.

    Always returns the cached parse of the canonical read_command() output.
    Use `if not X: raise AssertionError(...)` rather than `assert X` so the
    invariant survives `python -O` execution (test runners typically don't
    strip asserts, but helper modules might be imported by code that does).
    """
    match = _FRONTMATTER_RE.match(read_command())
    if not match:
        raise AssertionError("Expected YAML frontmatter wrapped in --- markers")
    return match.group(1), match.group(2)


def parse_allowed_tools_set() -> set[str]:
    """Tokenize the allowed-tools line into a clean set of tool names.

    Substring-match against the raw frontmatter has two false-positive modes:
    (a) tool name appears in the `description:` prose, (b) tool name appears
    in a YAML comment. This parser scopes to the allowed-tools line ONLY,
    splits on commas, and strips whitespace.
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
    """Extract the substring between two markdown markers (e.g., ##/### headings).

    Used to scope substring assertions to a specific section block — e.g.,
    the Step 8b error-catalog table — so a string mention elsewhere in prose
    doesn't false-positive the assertion.

    BOTH markers MUST be found when provided — a silent fall-through to
    `body[start:]` on a missing end_marker would quietly widen the scope to
    the rest of the document, defeating the purpose of scoping.

    Uses explicit if/raise rather than `assert` so the guards survive `-O`.
    """
    start = body.find(start_marker)
    if start < 0:
        raise AssertionError(f"Section start marker not found: {start_marker!r}")
    if end_marker is None:
        return body[start:]
    end = body.find(end_marker, start + len(start_marker))
    if end < 0:
        raise AssertionError(
            f"Section end marker not found: {end_marker!r} (after start {start_marker!r}). "
            f"Section assertions need both markers to scope correctly."
        )
    return body[start:end]


# --- File existence + frontmatter shape ------------------------------------


def test_command_file_exists() -> None:
    assert COMMAND_PATH.is_file(), f"Slash command file missing: {COMMAND_PATH}"


def test_frontmatter_has_description_argument_hint_and_allowed_tools() -> None:
    frontmatter, _ = split_frontmatter()
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

    Uses tokenized parse to avoid false-positive from `Skill` substring matching
    inside a different tool name or description text.
    """
    tools = parse_allowed_tools_set()
    assert "Skill" in tools, (
        "allowed-tools must include `Skill` — the orchestrator composes /revops:create-sf-campaign "
        "(BC-8717) via the Skill tool, not via a direct MCP write tool (which doesn't exist)."
    )


def test_allowed_tools_excludes_nonexistent_mcp_write_tools() -> None:
    """The original BC-8724 spec listed mcp__plugin_revops_salesforce__create_sf_campaign
    in allowed-tools — but that MCP write tool does NOT exist (BC-8717 was respec'd
    from MCP tool to slash command on 2026-05-19, PR #329). Listing a non-existent
    MCP tool fails silently at runtime (per CLAUDE.md gotcha on allowed-tools).

    Uses tokenized parse so a documentation mention in `description:` doesn't
    false-trigger this assertion.
    """
    tools = parse_allowed_tools_set()
    forbidden = {
        "mcp__plugin_revops_salesforce__create_sf_campaign",
        "mcp__plugin_revops_salesforce__update_sf_campaign_status",
    }
    illegal = tools & forbidden
    assert not illegal, (
        f"allowed-tools must NOT include {sorted(illegal)} — those MCP write tools do not exist "
        f"(BC-8717/BC-8723 respec'd 2026-05-19). Use Skill tool to compose the sibling slash command."
    )


def test_allowed_tools_excludes_unused_sf_soql_read() -> None:
    """run_soql_query was in the initial frontmatter but is never invoked in the
    body — plan-campaign delegates SOQL to /revops:create-sf-campaign which has its
    own SOQL declarations. Keeping an unused MCP tool in allowed-tools is dead
    surface area (architecture-reviewer P2, simplify pass).
    """
    tools = parse_allowed_tools_set()
    assert "mcp__plugin_revops_salesforce__run_soql_query" not in tools, (
        "run_soql_query is not invoked anywhere in plan-campaign.md — drop it from "
        "allowed-tools to minimize the cross-plugin MCP surface."
    )


def test_allowed_tools_excludes_unused_linear_get_issue() -> None:
    """get_issue is not invoked in the body — plan-campaign uses save_issue,
    list_milestones, list_projects, list_issue_labels but never reads back an
    individual issue. Independent PR review flagged this as dead surface area
    (parallel to test_allowed_tools_excludes_unused_sf_soql_read).
    """
    tools = parse_allowed_tools_set()
    if "mcp__plugin_workflows_linear-server__get_issue" in tools:
        # Confirm by grepping the body — if a future change DOES use get_issue,
        # the tool should be re-added and this test relaxed.
        body = read_command()
        # Strip the frontmatter so the allowed-tools listing isn't a self-hit.
        _, doc_body = split_frontmatter()
        assert "get_issue" in doc_body, (
            "get_issue is in allowed-tools but never invoked in the spec body. "
            "Drop it from allowed-tools, or add an explicit invocation to the body."
        )


def test_allowed_tools_includes_linear_and_sf_read_tools() -> None:
    """All required tools are PRESENT in the tokenized allowed-tools set."""
    tools = parse_allowed_tools_set()
    expected = {
        "mcp__plugin_workflows_linear-server__list_projects",
        "mcp__plugin_workflows_linear-server__list_milestones",
        "mcp__plugin_workflows_linear-server__save_milestone",
        "mcp__plugin_workflows_linear-server__save_issue",
        "mcp__plugin_workflows_linear-server__list_issue_labels",
        "mcp__plugin_workflows_linear-server__create_issue_label",
        "mcp__plugin_revops_salesforce__get_username",
        "AskUserQuestion",
        "Bash",
        "Read",
        "Write",
    }
    missing = expected - tools
    assert not missing, f"allowed-tools missing required tools: {sorted(missing)}"


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
        "--segment",
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


def test_all_soft_fail_error_keys_handled_in_8b_catalog() -> None:
    """The 5 error kinds emitted by /revops:create-sf-campaign (BC-8717) must
    each appear in plan-campaign's Step 8b.1 error-catalog block — NOT just
    anywhere in the body. Scope the assertion to the catalog so a stray
    mention in prose elsewhere doesn't false-confirm coverage.
    """
    _, body = split_frontmatter()
    # 8b.1 catalog extends from "#### 8b.1" until the next top-level "###" or "##"
    catalog = extract_section(body, "#### 8b.1", "### ")
    error_keys = [
        "duplicate_slug",
        "missing_owner",
        "sf_cli_error",
        "invalid_slug_format",
        "missing_required_flag",
    ]
    missing = [key for key in error_keys if key not in catalog]
    assert not missing, (
        f"Error keys missing from Step 8b.1 catalog block: {missing}. "
        f"Each /revops:create-sf-campaign error kind must have a documented manifest "
        f"action + Step 11 reminder row in 8b.1, not just an incidental mention."
    )


def test_soft_fail_catalog_has_unknown_kind_default_branch() -> None:
    """The Step 8b.1 catalog must have a default-branch row for unknown error
    kinds — otherwise a 6th error kind added by /revops:create-sf-campaign in
    a future release would silently no-op here (architecture-reviewer P2:
    consumer-redeclares-producer-enum coupling).
    """
    _, body = split_frontmatter()
    catalog = extract_section(body, "#### 8b.1", "### ")
    # Default branch marker — keep flexible but pinned to a substantive phrase
    assert "unknown" in catalog.lower() and "error kind" in catalog.lower(), (
        "Step 8b.1 catalog must document a default branch for unknown error kinds "
        "(architecture-reviewer P2 fix: prevents silent no-op when sibling adds new kinds)."
    )


# --- Slug + canonicality contract ------------------------------------------


def test_slug_regex_matches_create_sf_campaign() -> None:
    """The slug regex must appear verbatim in plan-campaign.md AND match
    /revops:create-sf-campaign's Phase 1 regex byte-for-byte. The substring
    presence check alone isn't enough — drift between the two files would
    let plan-campaign compute slugs that the sibling skill rejects at the
    Skill-tool boundary (test-quality-reviewer P2 fix).
    """
    body = read_command()
    expected = r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$"
    assert expected in body, (
        f"Slug regex must appear verbatim in plan-campaign.md. Expected: {expected!r}"
    )
    # Cross-file parity check: assert the same regex is in the sibling skill
    sibling = read_sibling_create_sf_campaign()
    assert expected in sibling, (
        f"Slug regex parity broken — {REVOPS_CREATE_PATH} does not contain "
        f"the regex {expected!r}. If /revops:create-sf-campaign changed its slug "
        f"regex, plan-campaign must be updated in lockstep or the Skill-tool "
        f"boundary will reject slugs that plan-campaign computes."
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
    """The entity ↔ EB workspace map at Step 4.1 must enumerate all 4 entities
    + both EB workspaces. SCOPED to the Step 4.1 section — without scoping,
    these substrings appear all over the body (`Labs-gated`, `cross-entity-
    {theme}`, etc.) and the assertion would pass even if the map were
    deleted (test-quality-reviewer P3 fix, confidence 8/10).
    """
    _, body = split_frontmatter()
    section = extract_section(body, "### 4.1 — Entity → EB workspace map", "### 4.2 ")
    assert "emailbison-personal" in section, "EB workspace personal must be in §4.1 entity map"
    assert "emailbison-b2b" in section, "EB workspace b2b must be in §4.1 entity map"
    for entity in ["nites", "supply", "labs", "cross-entity"]:
        assert entity in section, f"Entity '{entity}' must appear in the §4.1 EB workspace map"


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


def _parse_semver(version: str) -> tuple[int, ...]:
    """Parse a dotted version string into an integer tuple for ordered comparison.

    Accepts standard semver (1.2.3) — does NOT handle pre-release/build metadata,
    which this repo doesn't use.
    """
    return tuple(int(part) for part in version.split("."))


def test_plugin_json_version_bumped() -> None:
    """BC-8724 adds a new command — version MUST be STRICTLY GREATER than 0.3.38
    in plugin.json. A simple `!=` check would let an accidental downgrade pass
    (e.g., 0.3.37) — semver-tuple comparison catches that (python-reviewer P3).
    """
    plugin_data = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))
    actual = _parse_semver(plugin_data["version"])
    baseline = _parse_semver("0.3.38")
    assert actual > baseline, (
        f"plugin.json marketing version ({plugin_data['version']}) must be > 0.3.38 — "
        f"BC-8724 adds a new command and clients' plugin cache is keyed by version "
        f"(CLAUDE.md plugin-cache gotcha). An accidental downgrade fails this check."
    )


def test_marketplace_json_version_mirrors_plugin_json() -> None:
    plugin_data = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))
    marketplace_data = json.loads(MARKETPLACE_JSON.read_text(encoding="utf-8"))

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

    muni_text = municipalities_path.read_text(encoding="utf-8")
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


def test_gotcha_citation_link_shape_is_consistent() -> None:
    """Gotcha/memory citations follow the project convention of relative-path
    links from the command file to a `memory/<gotcha-slug>.md` anchor. The
    targets don't physically exist in the repo (memory is auto-memory at
    ~/.claude/.../memory/, not committed to the repo) — they're conceptual
    anchors for human readability + greppability.

    What we CAN verify: every memory link uses the same relative-path depth
    that the file requires to reach the conceptual `memory/` root. For
    plan-campaign.md at plugins/marketing/commands/, that's 3 levels up.
    """
    body = read_command()
    link_pattern = re.compile(
        r"\]\((\.\./[^)]*memory/(?:gotcha|feedback|project|session|reference)_[^)]+\.md)\)"
    )
    targets = link_pattern.findall(body)
    assert targets, (
        "Expected at least one memory/* link in the body — citation test is "
        "vacuously passing if no links are present."
    )
    wrong_depth = [t for t in targets if not t.startswith("../../../memory/")]
    assert not wrong_depth, (
        f"memory/* citations must use 3-ups relative path (../../../memory/...) "
        f"from plugins/marketing/commands/ — found inconsistent depths: {wrong_depth}"
    )


# --- Container-issue pattern (Step 9.0) ------------------------------------


def test_container_issue_pattern_documented() -> None:
    """Step 9.0 introduced the container-issue parent pattern (Linear milestones
    can't take child issues directly). This is a load-bearing design decision
    that every downstream consumer (launch-campaign, campaign-debrief, σ3 status
    sync) must agree on. The spec MUST document the pattern explicitly so
    consumers can locate it (test-quality-reviewer P3 coverage gap).
    """
    body = read_command()
    assert "container-issue pattern" in body.lower(), (
        "Step 9.0 must document the container-issue pattern by name — load-bearing "
        "for downstream consumers."
    )
    assert "projectMilestoneId" in body, (
        "Spec must reference projectMilestoneId — the field that ties the container "
        "issue to the milestone."
    )


def test_container_issue_rollback_path_documented() -> None:
    """If the container-issue create fails at runtime, the orchestrator MUST
    document a rollback path so the operator isn't left with an orphan
    milestone + manifest in inconsistent state (cdr-compliance P3 fix).
    """
    body = read_command()
    assert "delete the milestone" in body.lower() or "manual-cleanup" in body.lower(), (
        "Step 9.0 must document explicit rollback guidance for container-issue create failure."
    )


# --- Label set parity (Step 8a.6 ↔ Step 9 sub-issues) ----------------------


_EXPECTED_LABELS = [
    "slug:",
    "entity:",
    "vertical:",
    "persona:",
    "offer:",
    "year:",
    "month:",
    "status:planning",
]


def test_8label_set_canonical_definition_present() -> None:
    """The 8-label canonical set must be enumerated as a CONSTANT statement
    in Step 8a.6 — drift between this enumeration and Step 9's labels: field
    is a silent defect (test-quality-reviewer P3 coverage gap).
    """
    body = read_command()
    section = extract_section(body, "#### 8a.6", "### ")
    missing = [label for label in _EXPECTED_LABELS if label not in section]
    assert not missing, (
        f"Step 8a.6 must enumerate all 8 canonical label prefixes. Missing: {missing}"
    )


def test_8label_set_referenced_in_step_9() -> None:
    """Step 9 must reference the 8-label set (either by listing all 8 again, or
    by citing § Step 8a.6). Without this anchor, a future edit to Step 9's
    labels: field could drift from the canonical without test detection.
    """
    body = read_command()
    section = extract_section(body, "## Step 9 — Create 8 standard sub-issues", "## Step 10")
    # Either explicit re-enumeration OR cross-reference to 8a.6 satisfies the contract
    has_reference = "8a.6" in section or all(label in section for label in _EXPECTED_LABELS)
    assert has_reference, (
        "Step 9 must either re-list the 8 canonical labels OR cite § Step 8a.6 — "
        "otherwise sub-issue label-application can silently drift from canonical."
    )


# --- Owner-email regex appears verbatim ------------------------------------


def test_email_regex_verbatim_in_step_4_2() -> None:
    """Step 4.2 owner-email resolution depends on a specific email regex for
    re-validation across all three resolution paths (security-reviewer P2 fix).
    The regex must appear verbatim so a future regex change is auditable in
    diffs.
    """
    body = read_command()
    expected = r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
    assert expected in body, (
        f"Owner-email regex must appear verbatim in Step 4.2 (or Step 1.5 input "
        f"validation). Expected: {expected!r}"
    )


# --- Parse-time input validation (Step 1.5) --------------------------------


def test_step_1b_input_validation_documented() -> None:
    """Step 1b enforces parse-time HARD-FAIL invariants on every operator-
    controlled flag (security-reviewer P1 fix). Without it, --entity could
    flow into mkdir as `../../../etc` and --theme could inject shell
    metacharacters into the SF Campaign Name via the slug.

    Named "Step 1b" rather than "Step 1.5" because validate.sh's step-sequence
    lint treats a decimal as a duplicate integer Step 1 (its regex extracts
    the leading integer); "Step 1b" matches the sub-step exclusion rule.
    """
    body = read_command()
    assert "Step 1b" in body, (
        "Spec must define a parse-time input-validation sub-step (Step 1b)."
    )
    section = extract_section(body, "### Step 1b", "## Step 2")
    # Closed-set validators must be present for --entity
    for value in ["nites", "supply", "labs", "cross-entity"]:
        assert value in section, (
            f"Step 1b --entity validator must enumerate closed-set value '{value}'."
        )
    # --theme validator must be present
    assert "--theme" in section, "Step 1b must document --theme validator"
    # --owner-email validator must be present
    assert "--owner-email" in section, "Step 1b must document --owner-email validator"


# --- Idempotency contract --------------------------------------------------


def test_idempotency_section_present() -> None:
    body = read_command()
    assert "Idempotency" in body, \
        "Body must document the orchestrator's idempotency behavior (partial-idempotency)"


# --- Discovery ICP contract (ADR-024) ---------------------------------------


def test_icp_source_resolution_documented() -> None:
    """Step 2.5 must resolve the Discovery ICP from the single canonical
    vertical icp file (collapsed resolution — no playbook branch, no MISSING
    state) and classify ready vs stub."""
    body = read_command()
    assert "### 2.5" in body, (
        "Spec must define the ICP-source resolution sub-step (2.5, ADR-024)."
    )
    section = extract_section(body, "### 2.5", "## Step 3")
    assert "data/canonicals/icp/{vertical}.json" in section, (
        "2.5 must resolve from the canonical vertical icp file path."
    )
    for state in ("ready", "stub"):
        assert state in section, (
            f"2.5 must classify the icp file as ready or stub (missing '{state}')."
        )
    assert "ADR-024" in section, "2.5 must cite ADR-024."


def test_segment_flag_documented() -> None:
    """--segment must appear in the flag table AND carry a Step 1b shape
    validator (segment names flow into filesystem paths)."""
    body = read_command()
    flag_section = extract_section(body, "### Flag table", "### Interactive prompt example")
    assert "--segment" in flag_section, "--segment missing from the flag table."
    validator_section = extract_section(body, "### Step 1b", "## Step 2")
    assert "--segment" in validator_section, (
        "--segment must have a Step 1b parse-time shape validator "
        "(path-traversal guard — segment names flow into the Step 7 copy path)."
    )


def test_icp_source_in_preview() -> None:
    """The Step 5 dry-run preview must surface the resolved ICP source."""
    body = read_command()
    section = extract_section(body, "## Step 5", "## Step 6")
    assert "ICP source:" in section, (
        "Step 5 preview must carry an 'ICP source:' line (ready/segments vs STUB)."
    )


def test_segment_copy_path_documented() -> None:
    """Step 7 must write uniform per-segment criteria copies."""
    body = read_command()
    section = extract_section(body, "## Step 7", "## Step 8")
    assert "tam/<slug>/<segment>/icp.json" in section, (
        "Step 7 must document the uniform per-segment copy path "
        "docs/campaigns/<entity>/tam/<slug>/<segment>/icp.json (ADR-024)."
    )
    assert '"segments"' in section or "`segments`" in section, (
        "Step 7 manifest must document the optional segments[] key (ADR-024)."
    )


def test_marketing_context_warn_documented() -> None:
    """2.5 must WARN (advisory, never block) when docs/marketing-context.md
    is absent, pointing at /marketing:product-marketing-context."""
    body = read_command()
    section = extract_section(body, "### 2.5", "## Step 3")
    assert "docs/marketing-context.md" in section, (
        "2.5 must check for docs/marketing-context.md (Input 1 of the dependency map)."
    )
    assert "/marketing:product-marketing-context" in section, (
        "The WARN must point operators at /marketing:product-marketing-context."
    )


def test_handoff_carries_icp_status() -> None:
    """The 11.3 hand-off must carry the per-segment criteria-file paths (ready)
    or the stub warning, so the list-build owner never starts blind."""
    body = read_command()
    section = extract_section(body, "### 11.3", "## Idempotency notes")
    assert "Discovery ICP" in section, (
        "11.3 hand-off must include the Discovery ICP status line (ADR-024)."
    )
