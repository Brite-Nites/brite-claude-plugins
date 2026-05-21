"""Contract tests for the /revops:deploy-prod + /revops:deploy-sandbox
slash commands, locking the BC-11030 PR-diff-scoped default.

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
    """
    body = read(PROD_PATH)
    assert "--diff-filter=ACMRT" in body, (
        "deploy-prod must use --diff-filter=ACMRT to exclude deletions"
    )
    assert "destructiveChanges.xml" in body, (
        "deploy-prod must mention destructiveChanges.xml as the deletion path"
    )


def test_deploy_sandbox_filters_deletions_via_diff_filter() -> None:
    body = read(SANDBOX_PATH)
    assert "--diff-filter=ACMRT" in body, (
        "deploy-sandbox must use --diff-filter=ACMRT to exclude deletions"
    )
    assert "destructiveChanges.xml" in body, (
        "deploy-sandbox must mention destructiveChanges.xml as the deletion path"
    )


# ── Multi-file LWC/Aura coalescing ───────────────────────────────────────

def test_deploy_prod_coalesces_lwc_aura_bundles() -> None:
    """AC: LWC bundle files (e.g., lwc/Foo/foo.js) must be coalesced to
    their bundle root (lwc/Foo) because sf metadata API treats the bundle
    as the deployable unit. The awk script must reference both lwc and aura
    by name so it doesn't silently miss one.
    """
    body = read(PROD_PATH)
    assert re.search(r'\$4=="lwc".*\$4=="aura"|\$4=="aura".*\$4=="lwc"', body), (
        "deploy-prod must coalesce both LWC and Aura bundle directories"
    )


def test_deploy_sandbox_coalesces_lwc_aura_bundles() -> None:
    body = read(SANDBOX_PATH)
    assert re.search(r'\$4=="lwc".*\$4=="aura"|\$4=="aura".*\$4=="lwc"', body), (
        "deploy-sandbox must coalesce both LWC and Aura bundle directories"
    )


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
    """
    body = read(PROD_PATH)
    # Match the reconcile-mode bash block: a fenced bash block containing
    # the verbatim full-tree invocation, scoped to brite-prod.
    assert re.search(
        r'```bash\s*\n\s*sf project deploy start --source-dir force-app[^\n]*--target-org brite-prod',
        body,
    ), "deploy-prod --reconcile mode must still emit --source-dir force-app for brite-prod"


def test_deploy_sandbox_reconcile_keeps_full_tree() -> None:
    body = read(SANDBOX_PATH)
    assert re.search(
        r'```bash\s*\n\s*sf project deploy start --source-dir force-app[^\n]*--target-org brite-sandbox',
        body,
    ), "deploy-sandbox --reconcile mode must still emit --source-dir force-app for brite-sandbox"


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

def test_revops_version_at_or_above_0_5_0() -> None:
    """BC-11030 changes the default deploy behavior — a minor bump. The
    plugin cache is keyed by version, so both plugin.json AND the
    marketplace.json entry must be at >= 0.5.0 for clients to pick up
    the new commands.
    """
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    parts = tuple(int(p) for p in plugin_data["version"].split("."))
    assert parts >= (0, 5, 0), (
        f"revops version {plugin_data['version']} must be >= 0.5.0 for BC-11030"
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
