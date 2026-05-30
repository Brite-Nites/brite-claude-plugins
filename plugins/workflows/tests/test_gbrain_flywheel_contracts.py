"""Contract tests for the team-gbrain read/write flywheel (BC-11754 + BC-11755).

These artifacts are Claude-orchestrated markdown (slash commands + a subagent),
not executable code, so — like plugins/marketing/tests/test_plan_campaign_contracts.py
— these tests verify the markdown's *contract* rather than runtime behavior:

  - WRITE side (BC-11755): /workflows:ship and /workflows:review declare a
    save-results phase that writes to the team brain via
    `mcp__plugin_workflows_gbrain-team__put_page` with the documented
    slug/title/tags/content pattern.
  - READ side (BC-11754): 5 artifacts declare `gbrain: context_queries`
    frontmatter (gstack manifest schema) AND a context-load prose phase that
    tells the agent to fulfill those queries via the gbrain-team MCP tools.

Runtime behavior ("invoke /review on a real PR, observe the brain queries
fire") is inherently manual and is NOT covered here — see the issues' manual
verification steps.

Brite CI does not invoke pytest (per .github/dependabot.yml). These are
dev-runnable contract assertions. Run with:
    pytest plugins/workflows/tests/test_gbrain_flywheel_contracts.py
"""

from __future__ import annotations

import re
import subprocess
from functools import lru_cache
from pathlib import Path

import yaml

# plugins/workflows/tests/ -> repo root is parents[3]
REPO_ROOT = Path(__file__).resolve().parents[3]

# Read-side artifacts (BC-11754) — 5 of them.
SESSION_START = REPO_ROOT / "plugins" / "workflows" / "commands" / "session-start.md"
REVIEW = REPO_ROOT / "plugins" / "workflows" / "commands" / "review.md"
SHIP = REPO_ROOT / "plugins" / "workflows" / "commands" / "ship.md"
PLAN_CAMPAIGN = REPO_ROOT / "plugins" / "marketing" / "commands" / "plan-campaign.md"
ARCH_REVIEWER = REPO_ROOT / "plugins" / "workflows" / "agents" / "architecture-reviewer.md"

# Write-side artifacts (BC-11755) — subset of the above.
WRITE_ARTIFACTS = {"ship": SHIP, "review": REVIEW}
READ_ARTIFACTS = {
    "session-start": SESSION_START,
    "review": REVIEW,
    "ship": SHIP,
    "plan-campaign": PLAN_CAMPAIGN,
    "architecture-reviewer": ARCH_REVIEWER,
}

GBRAIN_TEAM_PREFIX = "mcp__plugin_workflows_gbrain-team__"
VALID_KINDS = {"list", "vector", "filesystem"}

_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


@lru_cache(maxsize=None)
def read(path: Path) -> str:
    # Normalize CRLF so the frontmatter regex + section scoping are line-ending
    # agnostic (a Windows checkout with core.autocrlf=true would otherwise make
    # every split_frontmatter raise a misleading "no frontmatter" error).
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def split_frontmatter(path: Path) -> tuple[str, str]:
    """Return (frontmatter, body). Raise if no `---`-wrapped frontmatter.

    `if not X: raise` rather than `assert` so the guard survives `python -O`.
    """
    match = _FRONTMATTER_RE.match(read(path))
    if not match:
        raise AssertionError(f"{path.name}: expected YAML frontmatter wrapped in --- markers")
    return match.group(1), match.group(2)


def _frontmatter_mapping(path: Path) -> dict[str, object]:
    """YAML-parse the frontmatter, asserting it's a mapping (clear AssertionError
    rather than an opaque AttributeError if it parses to a list/scalar)."""
    frontmatter, _ = split_frontmatter(path)
    data = yaml.safe_load(frontmatter)
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise AssertionError(f"{path.name}: frontmatter is not a YAML mapping")
    return data


def gbrain_block(path: Path) -> dict[str, object]:
    """Parse the `gbrain:` frontmatter block as YAML and return it (or {})."""
    gb = _frontmatter_mapping(path).get("gbrain") or {}
    if not isinstance(gb, dict):
        raise AssertionError(f"{path.name}: `gbrain:` frontmatter is not a mapping")
    return gb


def body_of(path: Path) -> str:
    _, body = split_frontmatter(path)
    return body


def section(body: str, heading_keyword: str) -> str:
    """Return the section whose `##`/`###` heading contains heading_keyword,
    scoped from that heading to the next same-or-higher-level heading.

    Scoping prevents a keyword (e.g. "content") elsewhere in the doc from
    false-passing an assertion meant for this section.
    """
    # Strip fenced code blocks first so a `#`-prefixed line inside a ``` fence
    # can't be mistaken for the section heading (latent false-anchor trap).
    scrubbed = re.sub(r"(?ms)^```.*?^```", "", body)
    m = re.search(rf"^(#+)\s+.*{re.escape(heading_keyword)}.*$", scrubbed, re.MULTILINE)
    if not m:
        raise AssertionError(f"No heading containing {heading_keyword!r} found")
    level = len(m.group(1))
    rest = scrubbed[m.end():]
    # Next heading at the same or higher level (<= this heading's depth) ends the section.
    nxt = re.search(rf"^#{{1,{level}}}\s+\S", rest, re.MULTILINE)
    return rest[: nxt.start()] if nxt else rest


# --- WRITE side (BC-11755): save-results phase -----------------------------


def test_ship_declares_save_results_to_releases_slug() -> None:
    """/workflows:ship saves a release page to the team brain at releases/<version>."""
    save = section(body_of(SHIP), "Save-results")
    assert f"{GBRAIN_TEAM_PREFIX}put_page" in save, \
        "ship.md Save-results must call mcp__plugin_workflows_gbrain-team__put_page"
    assert "releases/" in save, \
        "ship.md Save-results must use the releases/<version> slug pattern"
    for field in ("title", "tags", "content"):
        assert re.search(rf"\*\*{field}:\*\*", save), \
            f"ship.md Save-results must document the **{field}:** field as a bullet"


def test_review_declares_save_results_to_reviews_or_learnings_slug() -> None:
    """/workflows:review saves findings at reviews/<pr> (or learnings/<topic>)."""
    save = section(body_of(REVIEW), "Save-results")
    assert f"{GBRAIN_TEAM_PREFIX}put_page" in save, \
        "review.md Save-results must call mcp__plugin_workflows_gbrain-team__put_page"
    assert "reviews/" in save, \
        "review.md Save-results must use the reviews/<pr-number> slug pattern"
    assert "learnings/" in save, \
        "review.md Save-results must offer the learnings/<topic-slug> slug for recurring patterns"
    for field in ("title", "tags", "content"):
        assert re.search(rf"\*\*{field}:\*\*", save), \
            f"review.md Save-results must document the **{field}:** field as a bullet"


# --- READ side (BC-11754): gbrain.context_queries + context-load phase -----

# Required key per query kind, per the gstack manifest schema
# (~/.claude/skills/gstack design-shotgun/design-consultation SKILL.md +
# gstack-brain-context-load.test.ts): list -> filter, vector -> query,
# filesystem -> glob.
_KIND_REQUIRED_KEY = {"list": "filter", "vector": "query", "filesystem": "glob"}


def assert_valid_context_queries(name: str, path: Path) -> None:
    gb = gbrain_block(path)
    assert gb, f"{name}: missing `gbrain:` frontmatter block (BC-11754)"
    assert gb.get("schema") == 1, f"{name}: gbrain.schema must be 1 (got {gb.get('schema')!r})"
    cqs = gb.get("context_queries")
    assert isinstance(cqs, list) and cqs, f"{name}: gbrain.context_queries must be a non-empty list"
    seen_ids: set[str] = set()
    for i, q in enumerate(cqs):
        where = f"{name}.context_queries[{i}]"
        assert isinstance(q, dict), f"{where} must be a mapping"
        qid = q.get("id")
        assert isinstance(qid, str) and qid, f"{where} must have a string `id`"
        assert qid not in seen_ids, f"{where}: duplicate id {qid!r}"
        seen_ids.add(qid)
        kind = q.get("kind")
        assert kind in VALID_KINDS, f"{where}: kind must be one of {sorted(VALID_KINDS)} (got {kind!r})"
        assert isinstance(q.get("render_as"), str) and q["render_as"], \
            f"{where} must have a string `render_as` heading"
        req = _KIND_REQUIRED_KEY[kind]
        assert req in q, f"{where}: kind={kind} requires a `{req}` field (gstack schema)"


def assert_context_load_prose(name: str, path: Path) -> None:
    cl = section(body_of(path), "Context-load")
    # Require the full wiring, not just a name-drop — a gutted "TODO: wire later
    # (mentions query and render_as)" stub must fail. Every context-load block
    # maps BOTH kinds and anchors on the declared frontmatter.
    assert f"{GBRAIN_TEAM_PREFIX}list_pages" in cl, \
        f"{name}: Context-load must map kind:list -> gbrain-team list_pages"
    assert f"{GBRAIN_TEAM_PREFIX}query" in cl, \
        f"{name}: Context-load must map kind:vector -> gbrain-team query"
    assert "context_queries" in cl, \
        f"{name}: Context-load must instruct fulfilling the declared gbrain.context_queries"
    assert "render_as" in cl, \
        f"{name}: Context-load must render results under each query's render_as"


def assert_tool_allowlist_includes_gbrain(name: str, path: Path, key: str) -> None:
    """For artifacts with a RESTRICTED tool list (commands' allowed-tools, agents'
    tools), the gbrain-team query/list_pages tool must be present — a restricted
    surface cannot call a tool it doesn't declare, so context-load would no-op."""
    raw = _frontmatter_mapping(path).get(key)
    if isinstance(raw, str):
        toolset = {t.strip() for t in raw.split(",") if t.strip()}
    elif isinstance(raw, list):
        toolset = {str(t).strip() for t in raw}
    else:
        raise AssertionError(f"{name}: frontmatter `{key}` missing or unparseable")
    assert any(
        t.startswith(GBRAIN_TEAM_PREFIX) and ("query" in t or "list_pages" in t)
        for t in toolset
    ), f"{name}: `{key}` must include a gbrain-team query/list_pages tool for context-load to call"


def test_session_start_has_context_queries_and_context_load() -> None:
    assert_valid_context_queries("session-start", SESSION_START)
    assert_context_load_prose("session-start", SESSION_START)


def test_plan_campaign_has_context_queries_context_load_and_tools() -> None:
    assert_valid_context_queries("plan-campaign", PLAN_CAMPAIGN)
    assert_context_load_prose("plan-campaign", PLAN_CAMPAIGN)
    assert_tool_allowlist_includes_gbrain("plan-campaign", PLAN_CAMPAIGN, key="allowed-tools")


def test_architecture_reviewer_has_context_queries_context_load_and_tools() -> None:
    assert_valid_context_queries("architecture-reviewer", ARCH_REVIEWER)
    assert_context_load_prose("architecture-reviewer", ARCH_REVIEWER)
    assert_tool_allowlist_includes_gbrain("architecture-reviewer", ARCH_REVIEWER, key="tools")


def test_review_has_context_queries_and_context_load() -> None:
    assert_valid_context_queries("review", REVIEW)
    assert_context_load_prose("review", REVIEW)


def test_ship_has_context_queries_and_context_load() -> None:
    assert_valid_context_queries("ship", SHIP)
    assert_context_load_prose("ship", SHIP)


# --- Flywheel coherence: write-tags and read-filters must use the same -------
#     repo: tag convention, or saved pages never surface in later context-loads.


def test_flywheel_repo_tag_convention_is_consistent() -> None:
    for name, path in WRITE_ARTIFACTS.items():
        save = section(body_of(path), "Save-results")
        assert "repo:<repo-slug>" in save, (
            f"{name} Save-results must tag pages with `repo:<repo-slug>` so the "
            "context-load `tags_contains: \"repo:{repo_slug}\"` filter finds them"
        )
    for name, path in {"session-start": SESSION_START, "review": REVIEW, "ship": SHIP}.items():
        gb = gbrain_block(path)
        list_filters = [
            str((q.get("filter") or {}).get("tags_contains", ""))
            for q in gb.get("context_queries", [])
            if q.get("kind") == "list"
        ]
        assert any("repo:{repo_slug}" in t for t in list_filters), (
            f"{name} must have a list context_query filtering on "
            'tags_contains "repo:{repo_slug}" (closes the flywheel)'
        )


def test_flywheel_page_type_convention_is_consistent() -> None:
    """Write side must stamp the page `type` that the read side filters on, or
    the `type:`-filtered context_queries never match what was saved."""
    # ship writes type=release; ship/session-start context-load filter type: release.
    ship_save = section(body_of(SHIP), "Save-results")
    assert re.search(r"\*\*type:\*\*\s*`?release`?", ship_save), \
        "ship.md Save-results must set page type `release` (matches the recent-releases type filter)"
    # review writes type=review-finding (reviews/) — review context-load filters type: review-finding.
    review_save = section(body_of(REVIEW), "Save-results")
    assert re.search(r"\*\*type:\*\*\s*`?review-finding`?", review_save), \
        "review.md Save-results must set page type `review-finding` (matches the prior-review-learnings type filter)"


# --- FDA clones (BC-11754/55 propagation) ----------------------------------
# flow-architecture clones session-start/review/ship from workflows; the
# flywheel propagates verbatim so the clone-drift guard stays minimal.
FDA_SESSION_START = REPO_ROOT / "plugins" / "flow-architecture" / "commands" / "session-start.md"
FDA_REVIEW = REPO_ROOT / "plugins" / "flow-architecture" / "commands" / "review.md"
FDA_SHIP = REPO_ROOT / "plugins" / "flow-architecture" / "commands" / "ship.md"


def test_fda_session_start_has_context_queries_and_context_load() -> None:
    assert_valid_context_queries("flow:session-start", FDA_SESSION_START)
    assert_context_load_prose("flow:session-start", FDA_SESSION_START)


def test_fda_review_has_flywheel() -> None:
    assert_valid_context_queries("flow:review", FDA_REVIEW)
    assert_context_load_prose("flow:review", FDA_REVIEW)
    save = section(body_of(FDA_REVIEW), "Save-results")
    assert f"{GBRAIN_TEAM_PREFIX}put_page" in save and "reviews/" in save and "learnings/" in save, \
        "flow:review Save-results must put_page to reviews/ or learnings/"


def test_fda_ship_has_flywheel() -> None:
    assert_valid_context_queries("flow:ship", FDA_SHIP)
    assert_context_load_prose("flow:ship", FDA_SHIP)
    save = section(body_of(FDA_SHIP), "Save-results")
    assert f"{GBRAIN_TEAM_PREFIX}put_page" in save and "releases/" in save, \
        "flow:ship Save-results must put_page to releases/"


def _blob_sha(path: Path) -> str:
    """git blob SHA of the WORKING-TREE file content (`git hash-object`).

    This validates that the FDA clone headers were re-recorded to match the
    workflows source AS EDITED ON THIS BRANCH — the same content that becomes
    origin/main's blob once the PR merges. NOTE this intentionally differs from
    the production guard (check-clone-drift.sh defaults UPSTREAM_REF=origin/main):
    mid-PR, origin/main still holds the pre-flywheel blob, so the production
    `clone-drift-check` job is advisory (continue-on-error) and goes green on
    merge. The BC-7060 regression test (test-clone-drift.sh) likewise overrides
    to UPSTREAM_REF=HEAD. `git hash-object` needs no repo, but surface a clear
    error if git is unavailable / the file is unreadable rather than an opaque
    CalledProcessError that hides stderr.
    """
    r = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "hash-object", str(path)],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        raise AssertionError(f"git hash-object failed for {path}: {r.stderr.strip()}")
    return r.stdout.strip()


def test_fda_clone_upstream_sha_matches_current_workflows_blob() -> None:
    """After re-syncing the flywheel into the FDA clones, each clone's recorded
    Upstream-SHA must equal the current workflows source blob — or the
    flow-architecture clone-drift guard (vslice-greenfield CI) fails."""
    for name, fda_path in {
        "session-start": FDA_SESSION_START,
        "review": FDA_REVIEW,
        "ship": FDA_SHIP,
    }.items():
        upstream = REPO_ROOT / "plugins" / "workflows" / "commands" / f"{name}.md"
        expected = _blob_sha(upstream)
        m = re.search(r"Upstream-SHA:\s*([0-9a-fA-F]{40})", fda_path.read_text(encoding="utf-8"))
        assert m, f"{name} FDA clone: header missing Upstream-SHA"
        assert m.group(1).lower() == expected, (
            f"{name} FDA clone Upstream-SHA {m.group(1)[:7]} != current workflows blob "
            f"{expected[:7]} — re-record the header after propagating the flywheel"
        )
