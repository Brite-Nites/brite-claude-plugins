"""Contracts for ADR-026's preview and production-dispatch commands.

The old test read the deprecated ``deploy-sandbox`` and ``deploy-prod`` shims,
so every assertion inspected redirect prose after the ADR-026 rename. These
tests follow the canonical commands and pin the new lane boundary: a developer
may deploy a scoped diff only to a per-dev org, while production is dispatched
to the brite-salesforce CI workflow and never deployed from the laptop.
"""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREVIEW_PATH = ROOT / "commands" / "preview-changes.md"
PUSH_PATH = ROOT / "commands" / "push-to-production.md"
SUBMIT_PATH = ROOT / "commands" / "submit-changes-to-integration.md"
PREVIEW_SHIM = ROOT / "commands" / "deploy-sandbox.md"
PUSH_SHIM = ROOT / "commands" / "deploy-prod.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"
FORCEIGNORE_PREFLIGHT = ROOT / "commands" / "_shared" / "forceignore-preflight.md"
EMERGENCY_PATH = ROOT / "commands" / "emergency-deploy-to-production.md"
DEPLOY_WORKFLOWS = ROOT / "skills" / "sf-deploy" / "references" / "deployment-workflows.md"
SAFE_DESTRUCTIVE_ASSET = ROOT / "skills" / "sf-deploy" / "assets" / "BC-ticket.xml"
UNSAFE_DESTRUCTIVE_ASSET = ROOT / "skills" / "sf-deploy" / "assets" / "destructiveChanges.xml"


def read(path: Path) -> str:
    return path.read_text()


def split_frontmatter(text: str) -> tuple[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, "expected YAML frontmatter wrapped in --- markers"
    return match.group(1), match.group(2)


def bash_blocks(text: str) -> str:
    return "\n".join(re.findall(r"```bash\n(.*?)\n```", text, re.DOTALL))


def test_canonical_commands_and_deprecated_shims_exist() -> None:
    for path in (PREVIEW_PATH, PUSH_PATH, SUBMIT_PATH, PREVIEW_SHIM, PUSH_SHIM):
        assert path.is_file(), f"missing command artifact: {path}"
    assert "/revops:preview-changes" in read(PREVIEW_SHIM)
    assert "/revops:push-to-production" in read(PUSH_SHIM)


def test_preview_declares_scoped_dev_org_inputs() -> None:
    frontmatter, body = split_frontmatter(read(PREVIEW_PATH))
    hint = next(
        line for line in frontmatter.splitlines() if line.startswith("argument-hint:")
    )
    for token in (
        "--reconcile",
        "--target-org brite-dev-<name>",
        "--override-concurrency",
    ):
        assert token in hint
    assert "Mode: `branch-diff`" in body
    assert "Mode: `reconcile`" in body
    assert "--resolve-dev-org" in body


def test_preview_preserves_diff_scope_safety_contract() -> None:
    body = read(PREVIEW_PATH)
    assert "integration~1..integration" in body
    assert body.count("git merge-base origin/integration HEAD") >= 2
    assert "git merge-base origin/main HEAD" not in body
    assert body.count("--diff-filter=ACMRT") >= 2
    assert body.count("if ! RAW_CHANGED=$(git diff") >= 2
    assert body.count('($4=="lwc" || $4=="aura")') >= 2
    assert "No force-app/** files changed" in body
    assert "/revops:preview-changes --reconcile" in body
    assert "--source-dir force-app --dry-run --target-org {dev-org}" in body
    assert "--source-dir force-app --target-org {dev-org}" in body


def test_preview_refuses_deletions_and_routes_to_ticket_scoped_ceremony() -> None:
    body = read(PREVIEW_PATH)
    assert "manifest/destructive/BC-<ticket>.xml" in body
    assert "destructive-deploy.yml" in body
    assert "must stop this command" in body
    assert "fold the destructive manifest in and re-run" not in body


def test_shared_forceignore_scope_matches_the_integration_based_preview() -> None:
    body = read(FORCEIGNORE_PREFLIGHT)
    preview_row = next(
        line for line in body.splitlines()
        if line.startswith("| `/revops:preview-changes`")
    )
    assert "origin/integration" in preview_row
    assert "integration~1..integration" in preview_row
    assert "origin/main" not in preview_row


def test_submit_routes_deletions_to_the_same_ticket_scoped_ceremony() -> None:
    body = read(SUBMIT_PATH)
    assert "manifest/destructive/BC-<ticket>.xml" in body
    assert "destructive-deploy.yml" in body
    assert "Never commit `manifest/destructiveChanges.xml`" in body
    assert "these need `destructiveChanges.xml` in the PR" not in body
    assert "Deletions need `destructiveChanges.xml`" not in body


def test_sf_deploy_reference_and_asset_cannot_reintroduce_raw_prod_deletes() -> None:
    reference = read(DEPLOY_WORKFLOWS)
    assert "--target-org brite-prod" not in reference
    assert "--post-destructive-changes" not in reference
    assert "manifest/destructive/BC-<ticket>.xml" in reference
    assert SAFE_DESTRUCTIVE_ASSET.is_file()
    assert not UNSAFE_DESTRUCTIVE_ASSET.exists()
    asset = read(SAFE_DESTRUCTIVE_ASSET)
    assert "manifest/destructive/BC-<ticket>.xml" in asset
    assert "destructive-deploy.yml" in asset


def test_breakglass_handoff_never_inherits_the_normal_ci_flow_decision() -> None:
    body = read(EMERGENCY_PATH)
    assert "/revops:run-manual-post-deploy-steps --production-breakglass" in body
    assert "Flow activation stays blocked" in body


def test_preview_never_emits_a_shared_or_protected_org_deploy() -> None:
    code = bash_blocks(read(PREVIEW_PATH))
    assert "--target-org {dev-org}" in code
    for alias in (
        "brite-sandbox",
        "brite-integration",
        "briteint",
        "brite-uat",
        "brite-prod",
    ):
        assert f"--target-org {alias}" not in code


def test_preview_cites_the_scope_and_concurrency_rulings() -> None:
    body = read(PREVIEW_PATH)
    assert "[BC-11030](https://linear.app/brite-nites/issue/BC-11030)" in body
    assert "[BC-11037](https://linear.app/brite-nites/issue/BC-11037)" in body
    assert "_shared/concurrency-probe.md" in body
    assert "blocks and fails closed" in body


def test_push_declares_activation_but_refuses_laptop_scope_flags() -> None:
    frontmatter, body = split_frontmatter(read(PUSH_PATH))
    hint = next(
        line for line in frontmatter.splitlines() if line.startswith("argument-hint:")
    )
    assert "--activation <plan|canary|apply>" in hint
    assert "--override-concurrency" in hint
    assert "--ref <sha>" not in hint
    assert "--reconcile" not in hint
    assert "There is deliberately no `--ref`" in body
    assert "There is no `--reconcile` here any more" in body


def test_push_dispatches_main_with_every_required_input() -> None:
    body = read(PUSH_PATH)
    assert "gh workflow run deploy-prod.yml" in body
    assert "--ref main" in body
    assert "--raw-field mode=deploy" in body
    assert "--raw-field confirm=DEPLOY-PROD" in body
    assert '--raw-field activation="$ACTIVATION"' in body
    assert "RUN_URL=\"$(gh workflow run deploy-prod.yml" in body
    assert "2.87.0 or newer" in body


def test_push_fails_closed_until_main_exposes_the_required_input_contract() -> None:
    body = read(PUSH_PATH)
    contract = body.find("Confirm the `main` workflow's dispatch contract")
    confirmation = body.find("## Phase 2 — DOUBLE confirmation gate")
    assert 0 <= contract < confirmation
    assert "gh workflow view deploy-prod.yml" in body
    assert "--ref main" in body
    assert "--validate-prod-workflow -" in body
    assert "CI_CONTRACT_OK" in body


def test_push_binds_to_the_dispatch_receipt_not_a_run_listing() -> None:
    body = read(PUSH_PATH)
    assert "returned URL is the dispatch receipt" in body
    assert "Do not call `gh run list`" in body
    assert "RUN_ID" in body
    assert "gh run list --repo Brite-Nites/brite-salesforce" not in body


def test_push_contains_no_laptop_salesforce_deploy_command() -> None:
    code = bash_blocks(read(PUSH_PATH))
    assert "sf project deploy" not in code
    assert "sfdx force:source:deploy" not in code
    assert "This command does not deploy. CI does." in read(PUSH_PATH)


def test_push_keeps_preflight_scope_and_blocking_concurrency() -> None:
    body = read(PUSH_PATH)
    assert 'RANGE="main~1..main"' in body
    assert "_shared/forceignore-preflight.md" in body
    assert "_shared/concurrency-probe.md" in body
    assert "blocking and failing closed" in body
    assert "[BC-11037](https://linear.app/brite-nites/issue/BC-11037)" in body


def test_revops_version_and_marketplace_entry_match() -> None:
    plugin = json.loads(PLUGIN_JSON.read_text())
    marketplace = json.loads(MARKETPLACE_JSON.read_text())
    version = tuple(int(part) for part in plugin["version"].split("."))
    assert version >= (0, 6, 0)
    entry = next(item for item in marketplace["plugins"] if item["name"] == "revops")
    assert entry["version"] == plugin["version"]
