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
import subprocess
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
SF_DEPLOY_DIR = ROOT / "skills" / "sf-deploy"
SF_DEPLOY_SKILL = SF_DEPLOY_DIR / "SKILL.md"
SF_DEPLOY_README = SF_DEPLOY_DIR / "README.md"
SF_DEPLOY_ORCHESTRATION = SF_DEPLOY_DIR / "references" / "orchestration.md"
SF_DEPLOY_TRIGGER_SAFETY = SF_DEPLOY_DIR / "references" / "trigger-deployment-safety.md"
UNSAFE_DEPLOY_SCRIPT = SF_DEPLOY_DIR / "references" / "deploy.sh"
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


def test_preview_refuses_main_before_reconcile_can_bypass_diff_resolution() -> None:
    body = read(PREVIEW_PATH)
    phase_zero = body.index("## Phase 0 — Deploy-mode resolution")
    early_refusal = body.index('if [ "$BRANCH" = "main" ]; then', phase_zero)
    mode_selection = body.index("If `--reconcile` is in the invocation", phase_zero)

    assert phase_zero < early_refusal < mode_selection
    assert "`--reconcile` changes deploy scope; it never\noverrides the branch boundary" in body
    assert body.count('if [ "$BRANCH" = "main" ]; then') >= 3


def test_preview_binds_actual_deploy_to_the_exact_clean_dry_run_source() -> None:
    body = read(PREVIEW_PATH)
    dry_run = body.index("SOURCE_LOCKED head=$SOURCE_SHA integration=$INTEGRATION_SHA")
    deploy_phase = body.index("## Phase 3 — Actual deploy to your dev org")
    recheck = body.index('CURRENT_SHA=$(git rev-parse HEAD)', deploy_phase)
    first_mutating_deploy = body.index(
        "sf project deploy start --source-dir force-app --target-org {dev-org}",
        deploy_phase,
    )
    assert dry_run < deploy_phase < recheck < first_mutating_deploy
    assert body.count("git status --porcelain") >= 2
    assert '[ "$CURRENT_SHA" != "{dry-run-sha}" ]' in body
    assert '[ "$CURRENT_INTEGRATION_SHA" != "{dry-run-integration-sha}" ]' in body
    assert "restart /revops:preview-changes" in body


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


def test_shared_forceignore_preflight_fails_closed() -> None:
    body = read(FORCEIGNORE_PREFLIGHT)
    code = bash_blocks(body)

    assert "FORCEIGNORE_PREFLIGHT_ERROR=1" in code
    assert "FORCEIGNORE_BLOCKED=1" in code
    assert code.count("exit 2") >= 3
    assert "git diff failed — F1 cannot prove the deploy scope" in body
    assert ".forceignore is unreadable — F1 cannot prove the deploy scope" in body
    assert 'if ! FORCEIGNORE_CONTENT=$(cat .forceignore 2>&1); then' in code
    assert 'done <<< "$FORCEIGNORE_CONTENT"' in code
    assert "done < .forceignore" not in code
    assert "a deploy path is excluded" in body
    assert "Never continue from an uncommitted `.forceignore` edit" in body
    assert 'case "${SCOPE_MODE:-}" in' in code
    assert "diff|reconcile)" in code
    assert "find force-app" not in code
    assert "Reconcile never skips F1" in body
    assert "changed path + ignored = block" in body
    assert "skipping .forceignore pre-flight" not in body
    assert '\\!*) negated=1; pat="${pattern#!}"' in code
    assert 'if [ "$negated" = "1" ]; then' in code
    assert "Never break on the first positive match" in code

    for fail_open_recipe in (
        "not blocking",
        "temporarily comment out",
        "I've resolved the .forceignore conflict",
        "Named Credential exclusions are expected",
    ):
        assert fail_open_recipe not in body


def test_submit_never_skips_f1_when_its_merge_base_is_unavailable() -> None:
    body = read(SUBMIT_PATH)
    assert "if ! MERGE_BASE=$(git merge-base origin/integration HEAD 2>&1); then" in body
    assert "FORCEIGNORE_PREFLIGHT_ERROR=1" in body
    assert "exit 2" in body
    assert "skip the pre-flight with a `WARN`" not in body


def test_forceignore_preflight_honors_ordered_negation_in_both_modes(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()

    def git(*args: str) -> None:
        subprocess.run(
            ["git", *args], cwd=repo, check=True, capture_output=True, text=True
        )

    git("init", "-q")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test")
    target = repo / "force-app/main/default/externalCredentials"
    target.mkdir(parents=True)
    dialpad = target / "Dialpad_Contacts.externalCredential-meta.xml"
    blocked = target / "Other.externalCredential-meta.xml"
    dialpad.write_text("base\n")
    blocked.write_text("base\n")
    (repo / ".forceignore").write_text(
        "**/externalCredentials/*.externalCredential-meta.xml\n"
        "!**/externalCredentials/Dialpad_Contacts.externalCredential-meta.xml\n"
    )
    git("add", ".")
    git("commit", "-qm", "base")

    preflight = bash_blocks(read(FORCEIGNORE_PREFLIGHT))
    dialpad.write_text("changed\n")
    git("add", ".")
    git("commit", "-qm", "change allowed exception")
    for mode in ("diff", "reconcile"):
        result = subprocess.run(
            ["bash", "-c", f'SCOPE_MODE={mode}; RANGE="HEAD~1..HEAD"; {preflight}'],
            cwd=repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        assert "no deploy paths excluded" in result.stdout

    blocked.write_text("changed\n")
    git("add", ".")
    git("commit", "-qm", "change blocked path")
    result = subprocess.run(
        ["bash", "-c", f'SCOPE_MODE=reconcile; RANGE="HEAD~1..HEAD"; {preflight}'],
        cwd=repo,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 2
    assert "FORCEIGNORE_BLOCKED=1" in result.stdout
    assert "Other.externalCredential-meta.xml" in result.stdout


def test_forceignore_preflight_blocks_when_the_policy_file_cannot_be_read(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()

    def git(*args: str) -> None:
        subprocess.run(
            ["git", *args], cwd=repo, check=True, capture_output=True, text=True
        )

    git("init", "-q")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test")
    target = repo / "force-app/main/default/classes/Changed.cls"
    target.parent.mkdir(parents=True)
    target.write_text("base\n")
    policy = repo / ".forceignore"
    policy.write_text("**/classes/*.cls\n")
    git("add", ".")
    git("commit", "-qm", "base")
    target.write_text("changed\n")
    git("add", ".")
    git("commit", "-qm", "change")

    preflight = bash_blocks(read(FORCEIGNORE_PREFLIGHT))
    policy.chmod(0)
    try:
        result = subprocess.run(
            [
                "bash",
                "-c",
                f'SCOPE_MODE=diff; RANGE="HEAD~1..HEAD"; {preflight}',
            ],
            cwd=repo,
            capture_output=True,
            text=True,
        )
    finally:
        policy.chmod(0o600)

    assert result.returncode == 2
    assert "FORCEIGNORE_PREFLIGHT_ERROR=1" in result.stdout
    assert ".forceignore is unreadable" in result.stdout


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


def test_every_shipped_sf_deploy_guide_uses_the_brite_lane_boundary() -> None:
    guides = (
        SF_DEPLOY_SKILL,
        SF_DEPLOY_README,
        SF_DEPLOY_ORCHESTRATION,
        SF_DEPLOY_TRIGGER_SAFETY,
    )
    combined = "\n".join(read(path) for path in guides)

    assert not UNSAFE_DEPLOY_SCRIPT.exists()
    for stale_recipe in (
        "--target-org [alias]",
        "--target-org alias",
        "--target-org <alias>",
        'TARGET_ORG=${1:-"myorg"}',
        "references/deploy.sh",
        "Activate any Screen Flows via Setup",
        "Comment out the `.forceignore`",
    ):
        assert stale_recipe not in combined

    for path in guides:
        body = read(path)
        assert "/revops:preview-changes" in body, path
        assert "/revops:push-to-production" in body, path


def test_breakglass_handoff_never_inherits_the_normal_ci_flow_decision() -> None:
    body = read(EMERGENCY_PATH)
    assert "/revops:run-manual-post-deploy-steps --production-breakglass" in body
    assert "Flow activation stays blocked" in body


def test_breakglass_requires_two_distinct_named_admins_and_durable_evidence() -> None:
    frontmatter, body = split_frontmatter(read(EMERGENCY_PATH))
    hint = next(
        line for line in frontmatter.splitlines() if line.startswith("argument-hint:")
    )
    assert "--second-admin <holdeeno|kells-source>" in hint
    assert "--ack-url <https://evidence>" in hint
    assert "The identities must differ" in body
    assert "the full `{approved-sha}`" in body
    assert "generic or earlier approval is not reusable" in body
    assert "issues/comments/$ACK_ID" in body
    assert "breakglass_deploy_guard.py" in body
    assert "ack /tmp/revops-breakglass-ack.json" in body
    assert 'ACK_OPERATOR="$OPERATOR"' in body
    assert 'ACK_SECOND_ADMIN="$SECOND_ADMIN"' in body
    assert 'ACK_SHA="{approved-sha}"' in body
    assert "A URL supplied by the operator is never proof" in body


def test_breakglass_rechecks_sha_and_enforces_coverage_and_f2() -> None:
    body = read(EMERGENCY_PATH)
    phase4 = body.index("## Phase 4")
    recheck = body.index("### 4.0 Recheck", phase4)
    validate = body.index("### 4.1 Validate", phase4)
    quick = body.index("### 4.2 Quick-deploy", phase4)
    verify = body.index("### 4.3 F2 read-back verification", phase4)

    assert phase4 < recheck < validate < quick < verify
    assert 'git rev-parse origin/main)" = "{approved-sha}"' in body
    assert "--test-level RunLocalTests" in body
    assert "breakglass_deploy_guard.py" in body
    assert "--require-apex-coverage --minimum-coverage 90" in body
    assert "scripts/ci/verify-deploy-components.js" in body
    assert "--deploy-result /tmp/revops-breakglass-deploy.json" in body
    assert "do not retry or declare completion" in body


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
    assert '--raw-field expected_sha="{approved-sha}"' in body
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


def test_push_rechecks_and_binds_the_exact_confirmed_commit() -> None:
    body = read(PUSH_PATH)
    recheck = body.index("### 3.2 Recheck the approved commit")
    dispatch = body.index("### 3.3 Dispatch and capture the exact created run")
    assert recheck < dispatch
    assert 'DISPATCH_LOCAL=$(git rev-parse HEAD)' in body
    assert 'DISPATCH_REMOTE=$(git rev-parse origin/main)' in body
    assert 'APPROVED_SHA_MOVED approved={approved-sha}' in body


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
