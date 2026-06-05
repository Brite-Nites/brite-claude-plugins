"""Contract tests for the /marketing:plan-campaign slash command (BC-8724).

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared tools, documented
flags, soft-fail composition pattern, soft-fail error key handling, schema
fields, the 2-work-issue contract, slug regex) rather than runtime execution.
Runtime validation happens at BC-8727 (the first dogfood campaign).

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
# Per-phase sub-issue templates extracted from § 9.1 (BC-12564). This file is
# now the SOURCE OF TRUTH for the sub-issue chain: the command stamps from it
# and these tests assert against it (instead of grepping the command body).
REFERENCE_PATH = ROOT / "references" / "campaign-sub-issue-templates.md"
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


# --- Reference-file parser (BC-12564) --------------------------------------
# The sub-issue templates live in references/campaign-sub-issue-templates.md as
# one fenced ```yaml block per sub-issue (machine-critical fields) + a prose
# description. These tests parse the YAML blocks with a stdlib-only mini-parser
# rather than PyYAML: CLAUDE.md mandates stdlib-only (lint_canonicals.py
# reimplements a YAML subset for the same reason), and the schema is flat
# (scalars + inline int-lists), so a dedicated parser is exactly as
# deterministic as yaml.safe_load for this subset.


@lru_cache(maxsize=1)
def read_reference() -> str:
    """Read the sub-issue templates reference file once per session."""
    return REFERENCE_PATH.read_text(encoding="utf-8")


_YAML_BLOCK_RE = re.compile(r"```yaml\n(.*?)\n```", re.DOTALL)


def _parse_scalar(raw: str) -> object:
    """Parse one flat-YAML value: inline int-list, bool, int, or string.

    Handles `[]` / `[1]` / `[1, 3]`, `true`/`false`, signed ints, and
    quoted/bare strings. No nesting, anchors, or block scalars — the schema is
    deliberately flat (see module note above).
    """
    raw = raw.strip()
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        try:
            return [int(x.strip()) for x in inner.split(",")]
        except ValueError as exc:
            # Surface a malformed list (e.g. a non-integer blockedBy element) as a
            # clear, attributed failure rather than a bare int() traceback that
            # would blow up every test calling parse_subissue_blocks().
            raise AssertionError(
                f"inline list contains a non-integer element in {raw!r}: {exc}"
            ) from exc
    if raw in ("true", "false"):
        return raw == "true"
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    return raw.strip('"').strip("'")


def _parse_block(raw: str) -> dict:
    """Parse one fenced ```yaml block body into a flat dict.

    A quoted value (`title: "..."`) is read as the content between its quotes, so
    a value containing ` #` (e.g. `"Black Friday #promo"`) is NOT truncated; a
    trailing ` #` comment is only stripped from unquoted scalars/lists (offsets,
    `blockedBy`). Comment-only and blank lines are skipped.
    """
    rec: dict = {}
    for line in raw.splitlines():
        line = line.rstrip()
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#") or ":" not in line:
            continue
        key, _, val = line.partition(":")
        val = val.strip()
        if val[:1] in ('"', "'"):
            # Quoted string: take content between the opening quote and its match;
            # anything after (incl. a trailing ` #` comment) is ignored.
            quote = val[0]
            close = val.find(quote, 1)
            if close != -1:
                rec[key.strip()] = val[1:close]
            else:
                # Unclosed quote (malformed): drop the opening quote and any
                # trailing ` #` comment, matching the docstring + unquoted path
                # so the comment is never absorbed into the value.
                tail = val[1:]
                if " #" in tail:
                    tail = tail[: tail.index(" #")]
                rec[key.strip()] = tail.rstrip()
        else:
            # Unquoted scalar/list: drop a trailing ` #` comment, then parse.
            if " #" in val:
                val = val[: val.index(" #")]
            rec[key.strip()] = _parse_scalar(val)
    return rec


@lru_cache(maxsize=1)
def parse_subissue_blocks() -> list[dict]:
    """Parse every fenced ```yaml block in the reference file into a dict.

    Cached (like read_reference / read_command / split_frontmatter): 7 tests call
    this and re-running the regex + line parse each time is wasted work. Callers
    only read the result (they build local `{id: block}` dicts, never mutate the
    shared list/dicts), so a single shared parse is safe.

    Only fenced ```yaml blocks are sub-issue records — the file's schema-doc
    header uses a non-yaml fence so it is not picked up here.
    """
    return [_parse_block(raw) for raw in _YAML_BLOCK_RE.findall(read_reference())]


# The canonical sub-issue chain — the single model these tests assert the
# reference file against. (title, dueDate_offset_days, blockedBy, optional,
# labs_gated). Offsets per docs/gtm-campaign-orchestration-README.md § 3.6.5.
#
# Hand-maintained oracle: it is the TEST's canonical model, compared only
# against the parsed reference file (the README § 3.6.5 cadence is English prose,
# not machine-parsed). It catches a unilateral reference-file change, but a
# schedule/chain change is a DELIBERATE two-place edit — to this constant AND the
# reference file. Reviewers must confirm new values against README § 3.6.5; both
# edits land in the same diff.
_EXPECTED_SUBISSUES: dict[int, tuple] = {
    1:  ("Brief approved",                    -21, [],  False, False),
    2:  ("Target list built",                 -14, [1], False, False),
    3:  ("Copy written + approved",           -10, [1], False, False),
    4:  ("Salesforce setup",                   -7, [3], False, False),
    5:  ("Pre-launch QA",                      -3, [4], False, False),
    6:  ("Launch executed",                     0, [5], False, False),
    7:  ("Active management — weekly reviews",  28, [6], False, False),
    8:  ("Campaign closed + debrief",           40, [7], False, False),
    9:  ("Situation Mining",                  -12, [1], True,  True),
    10: ("Creative Angles",                   -12, [1], True,  False),
}


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
        "--deck-assignee",
        "--list-assignee",
        "--volume",
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


# --- 2-work-issue contract --------------------------------------------------
# --- Sub-issue chain contract (BC-12564: reference file is source of truth) -
# These tests were re-pointed from the command body to the reference file when
# § 9.1's inline specs were extracted. The 8-label-set tests (below) STAY on the
# command body — labels are a milestone-level constant applied by the stamping
# loop, not per-sub-issue data, so they did NOT move to the reference file.


def test_reference_file_exists() -> None:
    assert REFERENCE_PATH.is_file(), (
        f"Sub-issue templates reference file missing: {REFERENCE_PATH} (BC-12564)"
    )


def test_block_parser_quote_and_comment_handling() -> None:
    """Regression guard (BC-12564 review): the block parser must read a quoted
    value containing ` #` verbatim (no silent truncation), while still stripping
    a trailing ` #` comment from unquoted scalars and lists.
    """
    block = _parse_block(
        'id: 1\n'
        'title: "Black Friday #promo"\n'
        'dueDate_offset_days: -21   # T-21d\n'
        'blockedBy: [1]   # NOT [2] — copy ∥ target list\n'
        'optional: false\n'
        'labs_gated: false\n'
    )
    assert block["title"] == "Black Friday #promo", "quoted value with ` #` must not truncate"
    assert block["dueDate_offset_days"] == -21, "trailing ` #` comment on int must be stripped"
    assert block["blockedBy"] == [1], "trailing ` #` comment on list must be stripped"
    assert block["optional"] is False and block["labs_gated"] is False

    # Unclosed quote is malformed, but the fallback must still strip a trailing
    # ` #` comment (not absorb it) — consistent with the docstring (Greptile P2).
    unclosed = _parse_block('title: "Brief approved  # note\n')
    assert unclosed["title"] == "Brief approved", (
        "unclosed-quote fallback must strip the trailing comment, not absorb it"
    )


def test_block_parser_rejects_non_integer_list_element() -> None:
    """A malformed list value (e.g. a non-integer blockedBy element) must fail
    with a clear, attributed AssertionError at parse time — not a bare int()
    ValueError traceback that obscures which sub-issue is wrong (Greptile P2).
    """
    try:
        _parse_block("id: 1\nblockedBy: [1, oops]\n")
    except AssertionError as exc:
        assert "non-integer" in str(exc), f"error message should name the cause, got: {exc}"
    else:
        raise AssertionError("expected an AssertionError for a non-integer blockedBy element")


def test_reference_file_schema_valid() -> None:
    """Parse-contract gate: the reference file is now a parsed data source, so
    every block must carry the required keys with the right types, ids must be
    unique and exactly 1..10, and labs_gated may only be true on optional
    sub-issues. Guards a malformed future edit.
    """
    blocks = parse_subissue_blocks()
    assert len(blocks) == 10, (
        f"Expected 10 sub-issue yaml blocks (8 standard + 2 optional), found {len(blocks)}"
    )
    required = {
        "id": int,
        "title": str,
        "dueDate_offset_days": int,
        "blockedBy": list,
        "optional": bool,
        "labs_gated": bool,
    }
    seen_ids: set[int] = set()
    for b in blocks:
        for key, typ in required.items():
            assert key in b, f"sub-issue block missing key {key!r}: {b}"
            # bool is an int subclass — check bool first / exactly.
            if typ is int:
                assert isinstance(b[key], int) and not isinstance(b[key], bool), (
                    f"sub-issue {b.get('id')} key {key!r} must be int, got {b[key]!r}"
                )
            else:
                assert isinstance(b[key], typ), (
                    f"sub-issue {b.get('id')} key {key!r} must be {typ.__name__}, got {b[key]!r}"
                )
        assert all(isinstance(x, int) and not isinstance(x, bool) for x in b["blockedBy"]), (
            f"sub-issue {b['id']} blockedBy must be list[int], got {b['blockedBy']!r}"
        )
        assert b["id"] not in seen_ids, f"duplicate sub-issue id {b['id']}"
        seen_ids.add(b["id"])
        if b["labs_gated"]:
            assert b["optional"], (
                f"sub-issue {b['id']} has labs_gated:true but optional:false — "
                f"labs gating is only legal on optional sub-issues"
            )
    assert seen_ids == set(range(1, 11)), (
        f"sub-issue ids must be exactly 1..10, got {sorted(seen_ids)}"
    )

# The BC-12xxx rework: the 8-sub-issue process chain is GONE. plan-campaign
# creates exactly 2 substantive work issues modeled on real shipped exemplars:
# Deck Asset (BC-2816 model, → Sarah Cullen) and Data Sourcing & List Building
# (BC-10178 model, → Corinne Brewer).


def _step9_section() -> str:
    _, body = split_frontmatter()
    return extract_section(body, "## Step 9 — Create the 2 campaign work issues", "## Step 10")


def test_two_work_issues_present() -> None:
    section = _step9_section()
    assert "Deck Asset" in section, "Issue #1 (Deck Asset) must be specced in Step 9"
    assert "Data Sourcing & List Building" in section, \
        "Issue #2 (Data Sourcing & List Building) must be specced in Step 9"
    assert "projectMilestoneId" in section, \
        "Both issues must attach to the milestone via projectMilestoneId (no container parent)"


def test_default_assignees_documented() -> None:
    """The whole point of the rework: issues land assigned to the people who do
    the work. Defaults must be documented with override flags.
    """
    body = read_command()
    assert "sarahc@britenites.com" in body, \
        "Deck Asset default assignee (Sarah Cullen) must be documented"
    assert "corinne@britenites.com" in body, \
        "Data Sourcing default assignee (Corinne Brewer) must be documented"
    assert "Sarah Cullen" in body and "Corinne Brewer" in body, \
        "Default assignees must be named, not just email-addressed"


def test_no_process_stub_issues() -> None:
    """The retired 8-chain titles must NOT reappear as issue specs. They may be
    mentioned in the 'why only 2 issues' rationale prose, but Step 9 must not
    spec them as issues to create.
    """
    section = _step9_section()
    retired = [
        "Brief approved",
        "Target list built",
        "Copy written + approved",
        "Pre-launch QA",
        "Launch executed",
        "Active management",
        "Campaign closed + debrief",
        "Situation Mining",
        "Creative Angles",
        "Call Script",
        "Strategy & Positioning",
        "Channel Selection",
        "Measurement & Optimization",
        "Campaign Setup & Launch",
    ]
    present = [t for t in retired if t in section]
    assert not present, f"Retired process-stub issue titles found in Step 9: {present}"


def test_no_blocked_by_chain() -> None:
    """The two work issues are independent and parallel — Step 9 must state
    there is no blockedBy chain, and must not spec blocking relations.
    """
    section = _step9_section()
    assert "no `blockedBy` chain" in section, \
        "Step 9 must explicitly state the two issues have no blockedBy chain"
    assert "blockedBy: [" not in section and "blocks: [" not in section, \
        "Step 9 must not spec blockedBy/blocks relations between the work issues"


def test_issue_bodies_have_substance_contract() -> None:
    """Both issue-body templates must carry the substantive sections from the
    real exemplars (BC-2816 deck / BC-10178 list building) — this is the
    contract that prevents regression to empty-shell issues.
    """
    section = _step9_section()
    # BC-10178 (list building) skeleton
    for marker in [
        "## Source stack",
        "## Target volume",
        "## Decision-maker titles (priority order)",
        "## Exclusion logic (CRITICAL)",
        "MillionVerifier",
        "180-day",
    ]:
        assert marker in section, f"List-building issue body missing substance marker: {marker!r}"
    # BC-2816 (deck) skeleton
    for marker in [
        "**Positioning:**",
        "## Technical approach",
        "## Decision makers addressed",
        "## Dependencies",
        "GitHub Pages",
    ]:
        assert marker in section, f"Deck issue body missing substance marker: {marker!r}"
    # Both must close with acceptance criteria checkboxes
    assert section.count("## Acceptance criteria") >= 2, \
        "Both issue bodies must end with an Acceptance criteria checklist"
    assert "- [ ]" in section, "Acceptance criteria must be markdown checkboxes"


def test_substance_rules_forbid_empty_skeletons() -> None:
    """Step 9a must direct drafting from canonicals + brain context + the
    prior-campaign manifest mine — and forbid bare-TODO sections.
    """
    section = _step9_section()
    assert "NEVER leave a section as a bare TODO" in section, \
        "Step 9a must forbid emitting placeholder-only issue bodies"
    assert "manifest.json" in section, \
        "Step 9a must spec the prior-campaign manifest mine (suppression list source)"
    assert "titles[]" in section, \
        "Step 9a must derive the title cascade from canonicals personas[].titles[]"
def test_eight_standard_sub_issues_present() -> None:
    """The 8 standard sub-issues now live in the reference file (BC-12564 moved
    them out of the command body). Assert exactly 8 non-optional sub-issues with
    the canonical ids + titles.
    """
    standard = {b["id"]: b for b in parse_subissue_blocks() if not b["optional"]}
    assert len(standard) == 8, (
        f"Expected 8 standard (optional:false) sub-issues, found {len(standard)}"
    )
    for sid in range(1, 9):
        assert sid in standard, f"standard sub-issue #{sid} missing from reference file"
        expected_title = _EXPECTED_SUBISSUES[sid][0]
        assert standard[sid]["title"] == expected_title, (
            f"sub-issue #{sid} title drift: {standard[sid]['title']!r} != {expected_title!r}"
        )


def test_two_optional_sub_issues_present() -> None:
    """The 2 optional sub-issues (#9 Situation Mining, #10 Creative Angles) live
    in the reference file under the optional section with optional:true.
    """
    optional = {b["id"]: b for b in parse_subissue_blocks() if b["optional"]}
    assert len(optional) == 2, f"Expected 2 optional sub-issues, found {len(optional)}"
    assert optional.get(9, {}).get("title") == "Situation Mining", (
        "Optional sub-issue #9 must be Situation Mining (optional:true)"
    )
    assert optional.get(10, {}).get("title") == "Creative Angles", (
        "Optional sub-issue #10 must be Creative Angles (optional:true)"
    )


def test_situation_mining_labs_gated() -> None:
    """#9 Situation Mining is Labs-gated; #10 Creative Angles is not. The flag is
    the reference file's source of truth, AND the command must still ENFORCE the
    Labs HARD-FAIL (Step 10) — gating enforcement stays orchestration.
    """
    blocks = {b["id"]: b for b in parse_subissue_blocks()}
    assert blocks[9]["labs_gated"] is True, (
        "#9 (Situation Mining) must be labs_gated:true in the reference file"
    )
    assert blocks[10]["labs_gated"] is False, (
        "#10 (Creative Angles) must NOT be labs_gated in the reference file"
    )
    # Enforcement stays in the command. Scope to Step 10 so the check isn't
    # satisfied incidentally by `labs` appearing elsewhere (it's an entity value
    # enumerated all over the body) — require the HARD-FAIL to co-occur with the
    # flag INSIDE Step 10.
    _, body = split_frontmatter()
    step10 = extract_section(body, "## Step 10 — Optional sub-issues", "## Step 11")
    assert (
        "--situation-mining" in step10
        and "HARD-FAIL" in step10
        and "labs" in step10.lower()
    ), "Step 10 must enforce the Labs HARD-FAIL gate for --situation-mining"


def test_blocked_by_chain_documented() -> None:
    """The blockedBy chain is the authoritative dependency graph — only blockedBy
    is written to Linear; the derivable `blocks` field was dropped (BC-12564).
    Assert the chain matches the canonical edges, references only existing ids,
    is acyclic, with #1 the root gate and #8 terminal.
    """
    blocks = {b["id"]: b for b in parse_subissue_blocks()}
    # every referenced id exists
    for sid, b in blocks.items():
        for dep in b["blockedBy"]:
            assert dep in blocks, f"sub-issue #{sid} blockedBy references missing id #{dep}"
    # canonical edges
    for sid, (_t, _o, expected_bb, _opt, _lg) in _EXPECTED_SUBISSUES.items():
        assert blocks[sid]["blockedBy"] == expected_bb, (
            f"sub-issue #{sid} blockedBy drift: {blocks[sid]['blockedBy']} != {expected_bb}"
        )
    # #1 is the root gate
    assert blocks[1]["blockedBy"] == [], "#1 (Brief) must be the root gate (blockedBy [])"
    # #8 is terminal: no sub-issue is blocked by #8
    blockers = {dep for b in blocks.values() for dep in b["blockedBy"]}
    assert 8 not in blockers, "#8 (Campaign closed) must be terminal — nothing is blockedBy #8"

    # acyclic: no node transitively depends on itself
    def reaches_self(start: int) -> bool:
        stack, seen = list(blocks[start]["blockedBy"]), set()
        while stack:
            n = stack.pop()
            if n == start:
                return True
            if n in seen:
                continue
            seen.add(n)
            stack.extend(blocks[n]["blockedBy"])
        return False

    for sid in blocks:
        assert not reaches_self(sid), f"cycle detected involving sub-issue #{sid}"


def test_copy_parallels_target_list() -> None:
    """Design intent: copy (#3) and target-list (#2) run in PARALLEL — #3 is
    gated by the Brief (#1), NOT by #2. Encodes the explicit source note
    ("NOT #2 — copy and target list can parallel") as its own test so the
    parallelism can't silently regress into a serial chain.
    """
    blocks = {b["id"]: b for b in parse_subissue_blocks()}
    assert blocks[3]["blockedBy"] == [1], (
        "#3 (Copy) must be blocked only by #1 (Brief) — see the parallel-with-#2 design note"
    )
    assert 2 not in blocks[3]["blockedBy"], (
        "#3 (Copy) must NOT be blocked by #2 (Target list) — they run in parallel"
    )


def test_duedate_offsets_locked() -> None:
    """Per-phase dueDate offsets are load-bearing (T-21d … T+40d schedule, per
    docs/gtm-campaign-orchestration-README.md § 3.6.5). Lock them so a silent
    schedule edit fails CI. Asserted against literal canonical values: the README
    cadence is English prose (not machine-readable), so a literal lock carrying
    this citation is the low-fragility choice (BC-12564 grill).
    """
    blocks = {b["id"]: b for b in parse_subissue_blocks()}
    for sid, (_t, expected_offset, _bb, _opt, _lg) in _EXPECTED_SUBISSUES.items():
        assert blocks[sid]["dueDate_offset_days"] == expected_offset, (
            f"sub-issue #{sid} dueDate offset drift: "
            f"{blocks[sid]['dueDate_offset_days']} != {expected_offset} (README § 3.6.5)"
        )


def test_command_reads_reference_file() -> None:
    """After BC-12564, § 9.1 stamps sub-issue bodies from the reference file
    instead of carrying them inline. The command must name the file so the
    Read+stamp seam is auditable and the rewire can't silently revert.
    """
    body = read_command()
    assert "references/campaign-sub-issue-templates.md" in body, (
        "§ 9.1 must reference references/campaign-sub-issue-templates.md as the "
        "sub-issue template source (BC-12564 read+stamp seam)."
    )


def test_expected_plugin_command_routes_exist() -> None:
    """Every /marketing: or /revops: slash command the reference file routes to
    (notably the 'Expected plugin command' lines — the file's own header calls
    command-routing machine-critical) must resolve to a real command OR skill on
    disk. A typo would stamp a dead command reference into every campaign's Linear
    issues with nothing else to catch it. The 8-label-style scalar fields are
    guarded by schema/offset/chain tests; this guards the routing strings.
    """
    plugins_dir = ROOT.parents[0]  # plugins/
    refs = set(re.findall(r"/(marketing|revops):([a-z0-9][a-z0-9-]*)", read_reference()))
    assert refs, "expected at least one /<plugin>:<command> reference in the reference file"
    missing = [
        f"/{plugin}:{name}"
        for plugin, name in sorted(refs)
        if not (plugins_dir / plugin / "commands" / f"{name}.md").is_file()
        and not (plugins_dir / plugin / "skills" / name / "SKILL.md").is_file()
    ]
    assert not missing, (
        f"Reference file routes to non-existent commands/skills: {missing}. "
        f"Fix the typo, or add the command/skill before referencing it."
    )


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


# --- No container-issue pattern (retired with the 8-chain) ------------------


def test_no_container_issue_pattern() -> None:
    """The container-issue parent pattern was retired with the 8-sub-issue
    chain — with only 2 issues there is nothing to roll up, and the real
    exemplars (BC-2816, BC-10178) attach directly to the milestone with no
    parent. A reappearing container issue is scaffolding creep.
    """
    section = _step9_section()
    assert "container-issue" not in section.lower(), \
        "Step 9 must not re-introduce the container-issue parent pattern"
    assert "NO `parentId`" in section, \
        "Step 9 must explicitly state the work issues take no parentId"


def test_issue_create_failure_handling_documented() -> None:
    """If a work-issue create fails, the orchestrator must tell the operator to
    re-issue ONLY the failed save_issue call — not roll back the milestone/
    manifest, and not re-run the whole command (which would duplicate)."""
    section = _step9_section()
    assert "do NOT roll them back" in section, \
        "Step 9d must document partial-failure handling (no rollback of milestone/manifest)"


# --- Label set parity (Step 8a.6 ↔ Step 9 work issues) ----------------------


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
    section = _step9_section()
    # Either explicit re-enumeration OR cross-reference to 8a.6 satisfies the contract
    has_reference = "8a.6" in section or all(label in section for label in _EXPECTED_LABELS)
    assert has_reference, (
        "Step 9 must either re-list the 8 canonical labels OR cite § Step 8a.6 — "
        "otherwise work-issue label-application can silently drift from canonical."
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


# --- Clay lead-list spec (§ 9e) + scaffold PR (§ 9f) ------------------------


def test_lead_list_spec_documented() -> None:
    """§ 9e must spec the Clay lead-list .md next to the manifest — the durable,
    Clay-loadable rendering of the list-building issue body."""
    section = _step9_section()
    assert "### 9e" in section, "Step 9 must contain a § 9e lead-list spec sub-step"
    assert "docs/campaigns/<entity>/<slug>/lead-list.md" in section, \
        "§ 9e must use the canonical campaign-dir path for lead-list.md"
    assert "Clay" in section, \
        "§ 9e must orient the spec at Clay (MCP context loading)"
    assert "Redundant by design" in section, \
        "§ 9e must state the redundancy contract (Linear issue = tracking surface, file = artifact)"


def test_lead_list_spec_single_drafting_pass() -> None:
    """§ 9e renders from the SAME § 9a drafted content as the 9c issue body —
    a second independent drafting pass would let the issue and spec drift."""
    section = _step9_section()
    assert "one drafting pass, two renderings" in section, \
        "§ 9e must state the single-drafting-pass rule (issue body + spec from the same § 9a pass)"


def test_scaffold_pr_step_documented() -> None:
    """§ 9f must spec the campaign/<slug> branch + corinne-brewer reviewer.
    Branch format decision 2026-06-04: the V×P×O×M slug IS the wave naming
    convention's milestone form made git-ref-safe (the literal display format
    contains spaces/pipes — invalid/hostile as a git ref)."""
    section = _step9_section()
    assert "### 9f" in section, "Step 9 must contain a § 9f scaffold-PR sub-step"
    assert "campaign/<slug>" in section, "§ 9f must use the campaign/<slug> branch format"
    assert "corinne-brewer" in section, "§ 9f must assign corinne-brewer as the PR reviewer"
    assert "gh pr create" in section, "§ 9f must create the PR via gh pr create"


def test_scaffold_pr_is_soft_fail() -> None:
    """§ 9f failures must not halt scaffolding — Linear + manifest + lead-list.md
    are the hard gates; git/gh is best-effort with a manual fallback block."""
    _, body = split_frontmatter()
    philosophy = extract_section(body, "## Soft-fail philosophy", "## Non-goals")
    assert "9f" in philosophy, \
        "Soft-fail philosophy must cover the § 9f scaffold-PR sub-step"
    assert "lead-list.md" in philosophy, \
        "Soft-fail philosophy must list lead-list.md among the hard-gate artifacts"


def test_scaffold_pr_never_force_pushes() -> None:
    """The scaffold push must be a plain push — force pushes are regex-blocked
    repo-wide (workflows v3.31.0+ / BC-11889) and a fresh scaffold branch never
    legitimately needs one."""
    section = _step9_section()
    assert "git push -u origin campaign/<slug>" in section, \
        "§ 9f must push via plain `git push -u origin campaign/<slug>`"
    assert "git push --force" not in section and "git push -f" not in section, \
        "§ 9f must never spec a force push command"


def test_scaffold_pr_stages_campaign_dir_only() -> None:
    """§ 9f must stage ONLY the campaign directory — staging the whole tree
    would sweep unrelated operator work into the scaffold commit."""
    section = _step9_section()
    assert "git add docs/campaigns/<entity>/<slug>/" in section, \
        "§ 9f must stage exactly the campaign dir"
    assert "git add -A" not in section and "git add ." not in section, \
        "§ 9f must not stage the whole tree"


def test_no_pr_flag_documented() -> None:
    """--no-pr (skip § 9f) must appear in both the argument-hint and the
    Step 1 flag table."""
    frontmatter, body = split_frontmatter()
    hint_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("argument-hint:")),
        "",
    )
    assert "--no-pr" in hint_line, "--no-pr must be in argument-hint"
    flag_table = extract_section(body, "### Flag table", "### Interactive prompt example")
    assert "--no-pr" in flag_table, "--no-pr must have a row in the Step 1 flag table"
