"""Hermetic tests for the emergency-deploy receipt guard."""

from __future__ import annotations

import copy
import importlib.util
from pathlib import Path

import pytest


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "breakglass_deploy_guard.py"
SPEC = importlib.util.spec_from_file_location("breakglass_deploy_guard", MODULE_PATH)
assert SPEC and SPEC.loader
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


ACK_SHA = "a" * 40
ACK_URL = (
    "https://github.com/Brite-Nites/brite-salesforce/"
    "issues/123#issuecomment-456"
)


def ack_receipt() -> dict:
    return {
        "id": 456,
        "html_url": ACK_URL,
        "user": {"login": "kells-source"},
        "body": "\n".join(
            (
                "BREAKGLASS-ACK",
                "operator: holdeeno",
                f"sha: {ACK_SHA}",
                "reason: GitHub Actions is unavailable",
            )
        ),
    }


def evaluate_ack(payload: dict, **overrides):
    values = {
        "operator": "holdeeno",
        "second_admin": "kells-source",
        "ack_url": ACK_URL,
        "reason": "GitHub Actions is unavailable",
        "approved_sha": ACK_SHA,
    }
    values.update(overrides)
    return guard.evaluate_ack_receipt(payload, **values)


def test_ack_receipt_binds_two_distinct_admins_to_sha_and_reason() -> None:
    result = evaluate_ack(ack_receipt())
    assert result["decision"] == "ready"
    assert result["comment_id"] == 456


@pytest.mark.parametrize(
    ("mutation", "overrides", "message"),
    [
        (lambda p: p["user"].update(login="holdeeno"), {}, "named second admin"),
        (lambda p: p.update(html_url=ACK_URL + "x"), {}, "permalink"),
        (lambda p: p.update(id=457), {}, "comment id"),
        (lambda p: p.update(body=p["body"].replace(ACK_SHA, "b" * 40)), {}, "structured fields"),
        (lambda p: p.update(body=p["body"].replace("GitHub Actions is unavailable", "other")), {}, "structured fields"),
        (lambda p: None, {"second_admin": "holdeeno"}, "two distinct"),
        (lambda p: None, {"approved_sha": "short"}, "40 lowercase"),
        (lambda p: None, {"reason": "line one\nline two"}, "one nonblank line"),
        (lambda p: None, {"ack_url": "https://example.com/ack"}, "comment permalink"),
    ],
)
def test_ack_receipt_rejects_spoofed_or_unbound_evidence(
    mutation, overrides, message: str
) -> None:
    payload = copy.deepcopy(ack_receipt())
    mutation(payload)
    with pytest.raises(guard.GuardError, match=message):
        evaluate_ack(payload, **overrides)


def receipt() -> dict:
    return {
        "status": 0,
        "result": {
            "id": "0Af123456789012",
            "done": True,
            "success": True,
            "status": "Succeeded",
            "checkOnly": True,
            "numberComponentErrors": 0,
            "numberComponentsTotal": 2,
            "numberComponentsDeployed": 2,
            "numberTestErrors": 0,
            "numberTestsTotal": 10,
            "numberTestsCompleted": 10,
            "details": {
                "componentFailures": [],
                "runTestResult": {
                    "numFailures": 0,
                    "codeCoverage": [
                        {"numLocations": 80, "numLocationsNotCovered": 8},
                        {"numLocations": 20, "numLocationsNotCovered": 2},
                    ],
                },
            },
        },
    }


def test_completed_non_apex_validation_is_ready() -> None:
    result = guard.evaluate_validate_receipt(receipt(), require_apex_coverage=False)
    assert result["decision"] == "ready"
    assert result["apex_coverage_percent"] is None


def test_apex_validation_requires_weighted_ninety_percent() -> None:
    result = guard.evaluate_validate_receipt(receipt(), require_apex_coverage=True)
    assert result["apex_coverage_percent"] == 90.0


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (lambda p: p.update(status=1), "status is not integer 0"),
        (lambda p: p.update(status=False), "status is not integer 0"),
        (lambda p: p["result"].update(done=False), "not a completed success"),
        (lambda p: p["result"].update(success=False), "not a completed success"),
        (lambda p: p["result"].update(status="InProgress"), "not a completed success"),
        (lambda p: p["result"].update(checkOnly=False), "checkOnly must be True"),
        (lambda p: p["result"].update(id="not-a-deploy-id"), "no trustworthy 0Af id"),
        (
            lambda p: p["result"]["details"].update(componentFailures=[{"problem": "no"}]),
            "componentFailures",
        ),
        (
            lambda p: p["result"]["details"].pop("componentFailures"),
            "explicitly report componentFailures",
        ),
        (
            lambda p: p["result"].update(numberComponentErrors=1),
            "1 component error",
        ),
        (
            lambda p: p["result"].update(numberComponentsTotal=3),
            "2 deployed of 3",
        ),
        (
            lambda p: p["result"].update(numberTestsCompleted=9),
            "9 completed of 10",
        ),
        (
            lambda p: p["result"].update(
                numberTestsTotal=0, numberTestsCompleted=0
            ),
            "reported zero tests",
        ),
        (
            lambda p: p["result"]["details"].pop("runTestResult"),
            "requires a runTestResult",
        ),
        (
            lambda p: p["result"]["details"]["runTestResult"].pop("numFailures"),
            "no explicit numFailures",
        ),
        (
            lambda p: p["result"]["details"]["runTestResult"].update(
                numFailures=1, failures=[{"name": "FailingTest"}]
            ),
            "1 failure",
        ),
        (
            lambda p: p["result"]["details"]["runTestResult"].update(codeCoverage=[]),
            "absent or empty",
        ),
        (
            lambda p: p["result"]["details"]["runTestResult"].update(
                codeCoverage=[{"numLocations": 100, "numLocationsNotCovered": 11}]
            ),
            "below 90.00%",
        ),
        (
            lambda p: p["result"]["details"]["runTestResult"].update(
                codeCoverage=[{"numLocations": 3, "numLocationsNotCovered": 4}]
            ),
            "4 uncovered of 3",
        ),
    ],
)
def test_malformed_or_unsafe_validate_receipts_block(mutation, message: str) -> None:
    payload = copy.deepcopy(receipt())
    mutation(payload)
    with pytest.raises(guard.GuardError, match=message):
        guard.evaluate_validate_receipt(payload, require_apex_coverage=True)


def test_quick_receipt_requires_completed_success_and_deployed_count() -> None:
    payload = receipt()
    payload["result"]["checkOnly"] = False
    result = guard.evaluate_quick_receipt(payload)
    assert result == {
        "decision": "ready",
        "deploy_id": "0Af123456789012",
        "components_deployed": 2,
    }

    payload = receipt()
    payload["result"]["checkOnly"] = False
    del payload["result"]["numberComponentsDeployed"]
    with pytest.raises(guard.GuardError, match="numberComponentsDeployed"):
        guard.evaluate_quick_receipt(payload)


def test_quick_receipt_rejects_zero_or_partial_deploys() -> None:
    payload = receipt()
    payload["result"].update(
        checkOnly=False,
        numberComponentsTotal=0,
        numberComponentsDeployed=0,
    )
    with pytest.raises(guard.GuardError, match="zero components"):
        guard.evaluate_quick_receipt(payload)

    payload = receipt()
    payload["result"].update(checkOnly=False, numberComponentsDeployed=1)
    with pytest.raises(guard.GuardError, match="1 deployed of 2"):
        guard.evaluate_quick_receipt(payload)


@pytest.mark.parametrize("minimum", [float("nan"), float("inf"), -1, 101])
def test_coverage_threshold_must_be_a_finite_percentage(minimum: float) -> None:
    with pytest.raises(guard.GuardError, match="finite percentage"):
        guard.evaluate_validate_receipt(
            receipt(), require_apex_coverage=True, minimum_coverage=minimum
        )
