"""Static contract tests for the BC-19521 production CI dispatcher."""

from pathlib import Path


COMMAND = (
    Path(__file__).resolve().parents[1]
    / "commands"
    / "push-to-production.md"
).read_text()


def test_dispatches_main_with_every_required_prod_input() -> None:
    assert "--ref main" in COMMAND
    assert "--raw-field mode=deploy" in COMMAND
    assert "--raw-field confirm=DEPLOY-PROD" in COMMAND
    assert '--raw-field activation="$ACTIVATION"' in COMMAND


def test_activation_is_explicit_and_defaults_to_plan() -> None:
    assert "[--activation <plan|canary|apply>]" in COMMAND
    assert "Set `ACTIVATION=plan`" in COMMAND
    assert "Reject any other activation value" in COMMAND


def test_arbitrary_ref_dispatch_is_not_supported() -> None:
    assert "[--ref <sha>]" not in COMMAND
    assert 'REF="${REF:-main}"' not in COMMAND


def test_requires_run_url_capable_gh_and_uses_dispatch_receipt() -> None:
    assert "2.87.0 or newer" in COMMAND
    assert 'RUN_URL="$(gh workflow run deploy-prod.yml' in COMMAND
    assert "gh run list --repo Brite-Nites/brite-salesforce" not in COMMAND
    assert "RUN_ID" in COMMAND


def test_preflights_the_main_dispatch_schema_before_any_confirmation() -> None:
    contract = COMMAND.find("Confirm the `main` workflow's dispatch contract")
    confirmation = COMMAND.find("## Phase 2 — DOUBLE confirmation gate")
    assert 0 <= contract < confirmation
    assert "gh workflow view deploy-prod.yml" in COMMAND
    assert "--validate-prod-workflow -" in COMMAND
    assert "CI_CONTRACT_OK" in COMMAND
