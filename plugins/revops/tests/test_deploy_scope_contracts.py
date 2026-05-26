"""Contract tests for the /revops:deploy-prod + /revops:deploy-sandbox
slash commands, locking the BC-11030 PR-diff-scoped default and the
BC-11037 Phase 0.5 recent-deploy detector.

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared `--reconcile`
argument, dual-mode bash blocks, edge-case handling) rather than runtime
execution.

Pattern mirrors test_setup_sandbox_contracts.py: read the artifact, assert the
contract is met. No mocks, no subprocess, no SF org dependency.

No pytest installed locally? Run as a plain script:
    cd plugins/revops/tests
    python3 -c "import test_deploy_scope_contracts as t; \
[getattr(t,n)() for n in dir(t) if n.startswith('test_')]; print('all pass')"
"""

from __future__ import annotations

import functools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROD_PATH = ROOT / "commands" / "deploy-prod.md"
SANDBOX_PATH = ROOT / "commands" / "deploy-sandbox.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"


@functools.lru_cache(maxsize=4)
def read(path: Path) -> str:
    return path.read_text()


def split_frontmatter(text: str) -> tuple[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, "Expected YAML frontmatter wrapped in --- markers"
    return match.group(1), match.group(2)


# ── Frontmatter --reconcile argument-hint ────────────────────────────────

def test_deploy_prod_argument_hint_declares_reconcile() -> None:
    """BC-11030 AC: --reconcile is documented as a flag, not a magic word."""
    frontmatter, _ = split_frontmatter(read(PROD_PATH))
    hint = next(
        (line for line in frontmatter.splitlines() if line.startswith("argument-hint:")),
        None,
    )
    assert hint, "deploy-prod must declare argument-hint in frontmatter"
    assert "--reconcile" in hint, (
        "argument-hint must surface --reconcile so /help renders it"
    )


def test_deploy_sandbox_argument_hint_declares_reconcile() -> None:
    frontmatter, _ = split_frontmatter(read(SANDBOX_PATH))
    hint = next(
        (line for line in frontmatter.splitlines() if line.startswith("argument-hint:")),
        None,
    )
    assert hint, "deploy-sandbox must declare argument-hint in frontmatter"
    assert "--reconcile" in hint, (
        "argument-hint must surface --reconcile so /help renders it"
    )


# ── BC-11030 rationale callout ───────────────────────────────────────────

def test_deploy_prod_cites_bc_11030_rationale() -> None:
    """AC: 'Skill body documents the change with one line of rationale.'
    A markdown link to BC-11030 in the deploy-scope preamble proves the
    operator-readable rationale is in the file.
    """
    body = read(PROD_PATH)
    assert re.search(
        r"\[BC-11030\]\(https://linear\.app/brite-nites/issue/BC-11030\)",
        body,
    ), "deploy-prod must cite BC-11030 via a markdown link (Magic-ID-safe form)"


def test_deploy_sandbox_cites_bc_11030_rationale() -> None:
    body = read(SANDBOX_PATH)
    assert re.search(
        r"\[BC-11030\]\(https://linear\.app/brite-nites/issue/BC-11030\)",
        body,
    ), "deploy-sandbox must cite BC-11030 via a markdown link (Magic-ID-safe form)"


# Magic-ID-3-axis discipline (gotcha_linear_pr_title_magic_id_auto_close)
# applies to PR title / branch name / PR body — NOT command-markdown content.
# The deploy commands have pre-existing bare BC refs (BC-4734, BC-5795) that
# have been safe for months because they only appear in operator-readable
# prose, not in any PR title/body when this file gets shipped. So no
# bare-BC check here; the PR body discipline is enforced at PR-creation time
# by the operator, not by this contract test.


# ── Phase 0 deploy-mode resolution ───────────────────────────────────────

def test_deploy_prod_has_phase_0_mode_resolution() -> None:
    body = read(PROD_PATH)
    assert "## Phase 0 — Deploy-mode resolution" in body, (
        "deploy-prod must have a Phase 0 that parses --reconcile from the invocation"
    )


def test_deploy_sandbox_has_phase_0_mode_resolution() -> None:
    body = read(SANDBOX_PATH)
    assert "## Phase 0 — Deploy-mode resolution" in body, (
        "deploy-sandbox must have a Phase 0 that parses --reconcile from the invocation"
    )


# ── PR-diff default is the documented mode ───────────────────────────────

def test_deploy_prod_default_is_pr_diff_scoped() -> None:
    """The skill MUST describe its default as PR-diff-scoped, not full-tree.
    Lock the operator-readable mode label so a future edit can't silently
    revert the default.
    """
    body = read(PROD_PATH)
    assert re.search(r"Mode:\s*`pr-diff`", body), (
        "deploy-prod Phase 0 must surface 'Mode: `pr-diff`' as the default"
    )


def test_deploy_sandbox_default_is_branch_diff_scoped() -> None:
    body = read(SANDBOX_PATH)
    assert re.search(r"Mode:\s*`branch-diff`", body), (
        "deploy-sandbox Phase 0 must surface 'Mode: `branch-diff`' as the default"
    )


# ── Empty-diff edge case ─────────────────────────────────────────────────

def test_deploy_prod_handles_empty_diff() -> None:
    """AC: 'Empty-diff case halts with a clear actionable message
    (don't try to deploy nothing).' The error path must point the operator
    at --reconcile so they know the escape hatch.
    """
    body = read(PROD_PATH)
    # The empty-diff guard must mention --reconcile in its actionable
    # follow-up — case-insensitive substring is fine; this is operator copy.
    empty_diff_section = re.search(
        r'No force-app/\*\* files changed[^\n]*\n[^\n]*--reconcile',
        body,
    )
    assert empty_diff_section, (
        "deploy-prod must halt on empty diff with a message pointing at --reconcile"
    )


def test_deploy_sandbox_handles_empty_diff() -> None:
    body = read(SANDBOX_PATH)
    empty_diff_section = re.search(
        r'No force-app/\*\* files changed[^\n]*\n[^\n]*--reconcile',
        body,
    )
    assert empty_diff_section, (
        "deploy-sandbox must halt on empty diff with a message pointing at --reconcile"
    )


# ── Deletion edge case ───────────────────────────────────────────────────

def test_deploy_prod_filters_deletions_via_diff_filter() -> None:
    """AC: deletions must not be passed to --source-dir (the file no longer
    exists; sf fails). The bash must use --diff-filter=ACMRT (added/copied/
    modified/renamed/type-changed) to exclude deletions, and must surface
    detected deletions for operator awareness (destructiveChanges.xml path).

    The filter must appear at least once per re-resolution phase (Phase 2
    dry-run + Phase 4 real deploy). The `awk_count` test below locks "we
    compute the deploy scope in BOTH phases"; this test independently locks
    "the deletion-safe filter is used in BOTH". Without this, a regression
    could drop --diff-filter from Phase 4 while keeping it in Phase 2 and
    the awk count would still match — but Phase 4 would crash trying to
    deploy a deleted path.
    """
    body = read(PROD_PATH)
    count = body.count("--diff-filter=ACMRT")
    assert count >= 2, (
        "deploy-prod must use --diff-filter=ACMRT in BOTH Phase 2 (dry-run) and "
        f"Phase 4 (real deploy); found {count} occurrences"
    )
    assert "destructiveChanges.xml" in body, (
        "deploy-prod must mention destructiveChanges.xml as the deletion path"
    )


def test_deploy_sandbox_filters_deletions_via_diff_filter() -> None:
    body = read(SANDBOX_PATH)
    count = body.count("--diff-filter=ACMRT")
    assert count >= 2, (
        "deploy-sandbox must use --diff-filter=ACMRT in BOTH Phase 2 (dry-run) and "
        f"Phase 3 (real deploy); found {count} occurrences"
    )
    assert "destructiveChanges.xml" in body, (
        "deploy-sandbox must mention destructiveChanges.xml as the deletion path"
    )


def test_deploy_prod_captures_git_diff_exit_status() -> None:
    """The deploy bash must check `git diff` exit status BEFORE filtering with
    grep, or a git failure (shallow clone, unresolvable ref) silently
    propagates as an empty diff and the script mis-routes the operator to
    --reconcile. Lock the exit-status capture pattern in BOTH phases —
    a `re.search` (matches anywhere) would miss a Phase-4-only revert,
    which is the exact regression iter-1 round-1 review caught.
    """
    body = read(PROD_PATH)
    count = len(re.findall(
        r'if ! RAW_CHANGED=\$\(git diff "\$RANGE" --name-only --diff-filter=ACMRT',
        body,
    ))
    assert count >= 2, (
        "deploy-prod must capture `git diff` exit status in BOTH Phase 2 (dry-run) "
        f"and Phase 4 (real deploy) — found {count} occurrences"
    )


def test_deploy_sandbox_captures_git_diff_exit_status() -> None:
    body = read(SANDBOX_PATH)
    count = len(re.findall(
        r'if ! RAW_CHANGED=\$\(git diff "\$RANGE" --name-only --diff-filter=ACMRT',
        body,
    ))
    assert count >= 2, (
        "deploy-sandbox must capture `git diff` exit status in BOTH Phase 2 (dry-run) "
        f"and Phase 3 (real deploy) — found {count} occurrences"
    )


def test_deploy_sandbox_captures_merge_base_exit_status() -> None:
    """`RANGE="$(git merge-base origin/main HEAD)..HEAD"` swallows merge-base
    failures into a malformed `..HEAD` range. Lock the exit-status capture
    in BOTH Phase 2 + Phase 3 (sandbox computes the branch-diff range twice).
    """
    body = read(SANDBOX_PATH)
    count = len(re.findall(
        r'if ! MERGE_BASE=\$\(git merge-base origin/main HEAD',
        body,
    ))
    assert count >= 2, (
        "deploy-sandbox must capture `git merge-base` exit status in BOTH "
        f"Phase 2 and Phase 3 — found {count} occurrences"
    )


# ── Multi-file LWC/Aura coalescing ───────────────────────────────────────

def test_deploy_prod_coalesces_lwc_aura_bundles() -> None:
    """AC: LWC bundle files (e.g., lwc/Foo/foo.js) must be coalesced to
    their bundle root (lwc/Foo) because sf metadata API treats the bundle
    as the deployable unit. The awk script must reference both lwc and aura
    by name so it doesn't silently miss one.
    """
    body = read(PROD_PATH)
    # Wrap alternation in non-capturing groups so a future edit that adds a
    # third literal can't accidentally regroup the precedence.
    assert re.search(
        r'(?:\$4=="lwc".*\$4=="aura")|(?:\$4=="aura".*\$4=="lwc")',
        body,
    ), "deploy-prod must coalesce both LWC and Aura bundle directories"


def test_deploy_sandbox_coalesces_lwc_aura_bundles() -> None:
    body = read(SANDBOX_PATH)
    assert re.search(
        r'(?:\$4=="lwc".*\$4=="aura")|(?:\$4=="aura".*\$4=="lwc")',
        body,
    ), "deploy-sandbox must coalesce both LWC and Aura bundle directories"


# ── Branch-range detection ───────────────────────────────────────────────

def test_deploy_prod_uses_main_squash_range() -> None:
    """deploy-prod Phase 1.2 already pins branch=main. The diff range is
    therefore main~1..main (the squash commit that just landed the PR).
    BC-6000 squash discipline = standard at Brite, so this is the correct
    default — but it MUST be documented as the assumption.
    """
    body = read(PROD_PATH)
    assert 'RANGE="main~1..main"' in body, (
        "deploy-prod must compute its diff range as main~1..main "
        "(the squash commit on main)"
    )
    # The squash-merge assumption must be surfaced in operator-readable prose.
    assert re.search(r"squash[- ]merge|BC-6000 squash", body, re.IGNORECASE), (
        "deploy-prod must document the squash-merge assumption"
    )


def test_deploy_sandbox_detects_branch_vs_main() -> None:
    """deploy-sandbox normally runs from a feature branch (pre-merge). The
    diff range must be merge-base(origin/main, HEAD)..HEAD. If somehow
    invoked from main itself (post-merge sandbox re-deploy), the skill
    must fall back to main~1..main rather than mis-computing an empty
    range.
    """
    body = read(SANDBOX_PATH)
    assert "git merge-base origin/main HEAD" in body, (
        "deploy-sandbox must use merge-base(origin/main, HEAD) as the diff anchor"
    )
    assert 'BRANCH=$(git rev-parse --abbrev-ref HEAD)' in body, (
        "deploy-sandbox must inspect current branch to pick the diff range"
    )
    assert '"$BRANCH" = "main"' in body, (
        "deploy-sandbox must handle the run-from-main fallback explicitly"
    )


# ── --reconcile branch is preserved ──────────────────────────────────────

def test_deploy_prod_reconcile_keeps_full_tree() -> None:
    """The --reconcile escape hatch must still emit --source-dir force-app
    (the legacy path). Without this, --reconcile would be a no-op.

    Lock `force-app` followed by a whitespace boundary so the assertion
    can't pass on something like `--source-dir force-app/main/something`,
    which would be a scoped path, not the full-tree fallback.
    """
    body = read(PROD_PATH)
    # Match the reconcile-mode bash block: a fenced bash block containing
    # the verbatim full-tree invocation, scoped to brite-prod. The
    # `force-app\s+` requires whitespace after force-app — not a `/` —
    # so a path extension can't satisfy the lock.
    assert re.search(
        r'```bash\s*\n\s*sf project deploy start --source-dir force-app\s+[^\n]*--target-org brite-prod',
        body,
    ), "deploy-prod --reconcile mode must still emit --source-dir force-app (bare) for brite-prod"


def test_deploy_sandbox_reconcile_keeps_full_tree() -> None:
    body = read(SANDBOX_PATH)
    assert re.search(
        r'```bash\s*\n\s*sf project deploy start --source-dir force-app\s+[^\n]*--target-org brite-sandbox',
        body,
    ), "deploy-sandbox --reconcile mode must still emit --source-dir force-app (bare) for brite-sandbox"


# ── Re-resolution at the actual-deploy phase ─────────────────────────────

def test_deploy_prod_re_resolves_at_phase_4() -> None:
    """Phase 4 (real deploy) must re-compute the --source-dir set instead
    of caching state from Phase 2. The Phase 1.3 clean-tree check is the
    first line of defense; re-resolution is belt-and-suspenders against
    unexpected working-tree drift between gates.
    """
    body = read(PROD_PATH)
    # Both Phase 2 and Phase 4 must have the diff-filter / awk coalescing
    # logic. Count occurrences as a proxy for "computed in both phases".
    awk_count = body.count("NF>=5 && $1==\"force-app\"")
    assert awk_count == 2, (
        "deploy-prod must compute the deploy scope in BOTH Phase 2 and Phase 4 "
        f"(re-resolution discipline); found {awk_count} awk blocks"
    )


def test_deploy_sandbox_re_resolves_at_phase_3() -> None:
    body = read(SANDBOX_PATH)
    awk_count = body.count("NF>=5 && $1==\"force-app\"")
    assert awk_count == 2, (
        "deploy-sandbox must compute the deploy scope in BOTH Phase 2 and Phase 3 "
        f"(re-resolution discipline); found {awk_count} awk blocks"
    )


# ── Version bump (plugin-cache propagation) ──────────────────────────────

def test_revops_version_at_or_above_0_5_2() -> None:
    """BC-11037 adds Phase 0.5 — patch bump. The plugin cache is keyed by
    version, so both plugin.json AND the marketplace.json entry must be at
    >= 0.5.2 for clients to pick up the new commands.
    """
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    parts = tuple(int(p) for p in plugin_data["version"].split("."))
    assert parts >= (0, 5, 2), (
        f"revops version {plugin_data['version']} must be >= 0.5.2 for BC-11037"
    )


def test_marketplace_version_mirrors_plugin_json() -> None:
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


# ── Sandbox-specific: inline re-deploy hint also scoped ──────────────────

def test_sandbox_inline_re_deploy_hint_is_scoped() -> None:
    """The Phase 5 Kanban Group-By cache-flush walkthrough used to say
    'Re-deploy: sf project deploy start --source-dir force-app …'. That
    inline hint would silently teach operators to ignore the new default.
    Lock the scoped form so a future edit can't revert it.
    """
    body = read(SANDBOX_PATH)
    # The Phase 5 walkthrough must NOT contain a bare full-tree re-deploy
    # invocation; it must scope to the affected layout path.
    bare_redeploy = re.search(
        r"Re-deploy:\s*`sf project deploy start --source-dir force-app\s*--target-org",
        body,
    )
    assert not bare_redeploy, (
        "Sandbox Phase 5 inline re-deploy hint must scope to the affected layout, "
        "not --source-dir force-app (would teach operators to ignore BC-11030)"
    )
    # And the scoped form must be present (positive lock).
    assert "force-app/main/default/layouts/" in body, (
        "Sandbox Phase 5 must show a scoped layout re-deploy invocation"
    )


# ── Phase 0.5 recent-deploy detector (BC-11037) ────────────────────────

def test_deploy_prod_has_phase_0_5_recent_deploy_detector() -> None:
    body = read(PROD_PATH)
    assert "## Phase 0.5 — Recent-deploy detector" in body, (
        "deploy-prod must have a Phase 0.5 recent-deploy detector"
    )


def test_deploy_sandbox_has_phase_0_5_recent_deploy_detector() -> None:
    body = read(SANDBOX_PATH)
    assert "## Phase 0.5 — Recent-deploy detector" in body, (
        "deploy-sandbox must have a Phase 0.5 recent-deploy detector"
    )


def test_deploy_prod_phase_0_5_ordering() -> None:
    """Phase 0.5 must appear AFTER Phase 0 and BEFORE Phase 1."""
    body = read(PROD_PATH)
    idx_phase_0 = body.index("## Phase 0 — Deploy-mode resolution")
    idx_phase_05 = body.index("## Phase 0.5 — Recent-deploy detector")
    idx_phase_1 = body.index("## Phase 1 — Pre-flight")
    assert idx_phase_0 < idx_phase_05 < idx_phase_1, (
        "Phase 0.5 must appear between Phase 0 and Phase 1 in deploy-prod"
    )


def test_deploy_sandbox_phase_0_5_ordering() -> None:
    body = read(SANDBOX_PATH)
    idx_phase_0 = body.index("## Phase 0 — Deploy-mode resolution")
    idx_phase_05 = body.index("## Phase 0.5 — Recent-deploy detector")
    idx_phase_1 = body.index("## Phase 1 — Pre-flight")
    assert idx_phase_0 < idx_phase_05 < idx_phase_1, (
        "Phase 0.5 must appear between Phase 0 and Phase 1 in deploy-sandbox"
    )


def test_deploy_prod_phase_0_5_soql_shape() -> None:
    """The DeployRequest SOQL must include the documented columns, filter,
    ordering, and limit so the operator sees a useful table. Scoped to
    Phase 0.5 section to avoid false-pass from future SOQL in other phases."""
    body = read(PROD_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "FROM DeployRequest" in phase_05_body, (
        "deploy-prod Phase 0.5 must query the DeployRequest Tooling API object"
    )
    assert "LAST_N_HOURS:24" in phase_05_body, (
        "deploy-prod Phase 0.5 must filter to last 24 hours"
    )
    assert "ORDER BY CreatedDate DESC" in phase_05_body, (
        "deploy-prod Phase 0.5 must order by CreatedDate descending"
    )
    assert "LIMIT 5" in phase_05_body, (
        "deploy-prod Phase 0.5 must limit to 5 results"
    )
    for col in ("CreatedBy.Name", "CreatedDate", "Status", "NumberComponentsTotal"):
        assert col in phase_05_body, (
            f"deploy-prod Phase 0.5 SOQL must SELECT {col}"
        )
    assert "--use-tooling-api" in phase_05_body, (
        "deploy-prod Phase 0.5 must use --use-tooling-api (DeployRequest is a Tooling API object)"
    )


def test_deploy_sandbox_phase_0_5_soql_shape() -> None:
    body = read(SANDBOX_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "FROM DeployRequest" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must query the DeployRequest Tooling API object"
    )
    assert "LAST_N_HOURS:24" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must filter to last 24 hours"
    )
    assert "ORDER BY CreatedDate DESC" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must order by CreatedDate descending"
    )
    assert "LIMIT 5" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must limit to 5 results"
    )
    for col in ("CreatedBy.Name", "CreatedDate", "Status", "NumberComponentsTotal"):
        assert col in phase_05_body, (
            f"deploy-sandbox Phase 0.5 SOQL must SELECT {col}"
        )
    assert "--use-tooling-api" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must use --use-tooling-api (DeployRequest is a Tooling API object)"
    )


def test_deploy_prod_phase_0_5_gate_on_results() -> None:
    """Non-empty results must trigger an AskUserQuestion gate asking the
    operator to confirm coordination with the prior deployer."""
    body = read(PROD_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "AskUserQuestion" in phase_05_body, (
        "deploy-prod Phase 0.5 must use AskUserQuestion when results are non-empty"
    )
    assert re.search(r"coordinated", phase_05_body, re.IGNORECASE), (
        "deploy-prod Phase 0.5 gate must ask about coordination with prior deployer"
    )


def test_deploy_sandbox_phase_0_5_gate_on_results() -> None:
    body = read(SANDBOX_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "AskUserQuestion" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must use AskUserQuestion when results are non-empty"
    )
    assert re.search(r"coordinated", phase_05_body, re.IGNORECASE), (
        "deploy-sandbox Phase 0.5 gate must ask about coordination with prior deployer"
    )


def test_deploy_prod_phase_0_5_empty_result_skips_gate() -> None:
    """Empty result set must narrate 'No prod deploys' and proceed without gate."""
    body = read(PROD_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "No prod deploys in last 24h" in phase_05_body, (
        "deploy-prod Phase 0.5 must narrate skip when no recent deploys found"
    )


def test_deploy_sandbox_phase_0_5_empty_result_skips_gate() -> None:
    body = read(SANDBOX_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "No sandbox deploys in last 24h" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must narrate skip when no recent deploys found"
    )


def test_deploy_prod_phase_0_5_targets_brite_prod() -> None:
    """Phase 0.5 SOQL must target brite-prod, not brite-sandbox."""
    body = read(PROD_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "--target-org brite-prod" in phase_05_body, (
        "deploy-prod Phase 0.5 must target brite-prod"
    )
    assert "--target-org brite-sandbox" not in phase_05_body, (
        "deploy-prod Phase 0.5 must NOT target brite-sandbox"
    )


def test_deploy_sandbox_phase_0_5_targets_brite_sandbox() -> None:
    body = read(SANDBOX_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert "--target-org brite-sandbox" in phase_05_body, (
        "deploy-sandbox Phase 0.5 must target brite-sandbox"
    )
    assert "--target-org brite-prod" not in phase_05_body, (
        "deploy-sandbox Phase 0.5 must NOT target brite-prod"
    )


def test_deploy_prod_phase_0_5_query_failure_does_not_halt() -> None:
    """Query failure must not halt the deploy — Phase 0.5 is advisory only."""
    body = read(PROD_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert re.search(r"[Qq]uery failure", phase_05_body), (
        "deploy-prod Phase 0.5 must document the query-failure path"
    )
    assert re.search(r"do\s+\*\*not\*\*\s+halt", phase_05_body), (
        "deploy-prod Phase 0.5 must explicitly state not to halt on query failure"
    )


def test_deploy_sandbox_phase_0_5_query_failure_does_not_halt() -> None:
    body = read(SANDBOX_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert re.search(r"[Qq]uery failure", phase_05_body), (
        "deploy-sandbox Phase 0.5 must document the query-failure path"
    )
    assert re.search(r"do\s+\*\*not\*\*\s+halt", phase_05_body), (
        "deploy-sandbox Phase 0.5 must explicitly state not to halt on query failure"
    )


def test_phase_0_5_parity_both_files_have_it() -> None:
    """Sandbox parity AC: both commands must have Phase 0.5."""
    prod_body = read(PROD_PATH)
    sandbox_body = read(SANDBOX_PATH)
    assert "## Phase 0.5 — Recent-deploy detector" in prod_body
    assert "## Phase 0.5 — Recent-deploy detector" in sandbox_body


def test_deploy_prod_phase_0_5_cites_bc_11037() -> None:
    """Phase 0.5 must cite BC-11037 via a markdown link (Magic-ID-safe form)."""
    body = read(PROD_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert re.search(
        r"\[BC-11037\]\(https://linear\.app/brite-nites/issue/BC-11037\)",
        phase_05_body,
    ), "deploy-prod Phase 0.5 must cite BC-11037 via markdown link"


def test_deploy_sandbox_phase_0_5_cites_bc_11037() -> None:
    body = read(SANDBOX_PATH)
    phase_05_start = body.index("## Phase 0.5 — Recent-deploy detector")
    phase_1_start = body.index("## Phase 1 — Pre-flight")
    phase_05_body = body[phase_05_start:phase_1_start]
    assert re.search(
        r"\[BC-11037\]\(https://linear\.app/brite-nites/issue/BC-11037\)",
        phase_05_body,
    ), "deploy-sandbox Phase 0.5 must cite BC-11037 via markdown link"
