"""Hermetic tests for dev Flow post-deploy evidence ownership."""

from __future__ import annotations

import copy
import importlib.util
from datetime import datetime, timezone
from pathlib import Path

import pytest


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "flow_postdeploy_guard.py"
SPEC = importlib.util.spec_from_file_location("flow_postdeploy_guard", MODULE_PATH)
assert SPEC and SPEC.loader
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)

DEPLOY_ID = "0Af123456789012"
FLOWS = ["Lead_Disqualify", "Nurture_MQL_Enrollment"]
NOW = datetime(2026, 8, 18, 21, tzinfo=timezone.utc)


def deploy_receipt() -> dict:
    return {
        "status": 0,
        "result": {
            "id": DEPLOY_ID,
            "done": True,
            "success": True,
            "status": "Succeeded",
            "checkOnly": False,
            "startDate": "2026-08-18T19:00:00Z",
            "completedDate": "2026-08-18T19:12:00Z",
            "details": {
                "componentSuccesses": [
                    {"componentType": "Flow", "fullName": FLOWS[0]},
                    {"componentType": "Flow", "fullName": FLOWS[1]},
                    {"componentType": "CustomObject", "fullName": "Account"},
                ]
            },
        },
    }


def test_deploy_receipt_binds_exact_deploy_flows_and_server_window() -> None:
    result = guard.evaluate_deploy_receipt(
        deploy_receipt(), deploy_id=DEPLOY_ID, flows=FLOWS, now=NOW
    )
    assert result == {
        "decision": "ready",
        "deploy_id": DEPLOY_ID,
        "flows": sorted(FLOWS),
        "window_start": "2026-08-18T19:00:00Z",
        "window_end": "2026-08-18T19:12:00Z",
    }


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (lambda p: p.update(status=1), "status-0"),
        (lambda p: p.update(status=False), "status-0"),
        (lambda p: p["result"].update(id="0Af999999999999"), "does not match"),
        (lambda p: p["result"].update(done=False), "completed, successful"),
        (lambda p: p["result"].update(success=False), "completed, successful"),
        (lambda p: p["result"].update(status="Failed"), "completed, successful"),
        (lambda p: p["result"].update(checkOnly=True), "real deploy"),
        (
            lambda p: p["result"].update(startDate="2026-08-18T19:13:00Z"),
            "start is after",
        ),
        (
            lambda p: p["result"].update(completedDate="2026-08-19T01:00:01Z"),
            "future|longer than six",
        ),
        (lambda p: p["result"].pop("details"), "componentSuccesses"),
        (
            lambda p: p["result"]["details"].update(componentSuccesses=[]),
            "non-empty",
        ),
        (
            lambda p: p["result"]["details"]["componentSuccesses"][0].pop(
                "componentType"
            ),
            "componentType is malformed",
        ),
        (
            lambda p: p["result"]["details"]["componentSuccesses"].pop(0),
            "Lead_Disqualify.*exactly once",
        ),
        (
            lambda p: p["result"]["details"]["componentSuccesses"].append(
                {"componentType": "Flow", "fullName": FLOWS[0]}
            ),
            "Lead_Disqualify.*exactly once",
        ),
    ],
)
def test_deploy_receipt_rejects_untrusted_ownership(mutation, message: str) -> None:
    payload = copy.deepcopy(deploy_receipt())
    mutation(payload)
    with pytest.raises(guard.GuardError, match=message):
        guard.evaluate_deploy_receipt(
            payload, deploy_id=DEPLOY_ID, flows=FLOWS, now=NOW
        )


def draft_query() -> dict:
    return {
        "status": 0,
        "result": {
            "done": True,
            "totalSize": 2,
            "records": [
                {
                    "Id": "301123456789012",
                    "Status": "Draft",
                    "Definition": {"DeveloperName": FLOWS[0]},
                    "VersionNumber": 3,
                    "CreatedDate": "2026-08-18T19:03:00Z",
                },
                {
                    "Id": "301123456789012ABC",
                    "Status": "Draft",
                    "Definition": {"DeveloperName": FLOWS[1]},
                    "VersionNumber": 7,
                    "CreatedDate": "2026-08-18T19:10:00+00:00",
                },
            ],
        },
    }


def evaluate_drafts(payload: dict):
    return guard.evaluate_draft_query(
        payload,
        flows=FLOWS,
        window_start="2026-08-18T19:00:00Z",
        window_end="2026-08-18T19:12:00Z",
    )


def test_draft_query_returns_only_guarded_delete_ids() -> None:
    result = evaluate_drafts(draft_query())
    assert result["decision"] == "ready"
    assert result["draft_count"] == 2
    assert result["delete_ids"] == ["301123456789012", "301123456789012ABC"]


def test_complete_empty_draft_query_is_ready_with_no_delete_ids() -> None:
    payload = draft_query()
    payload["result"].update(totalSize=0, records=[])
    assert evaluate_drafts(payload)["delete_ids"] == []


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (lambda p: p["result"].update(done=False), "completed object"),
        (lambda p: p.update(status=False), "status-0"),
        (lambda p: p["result"].update(totalSize=3), "does not reconcile"),
        (lambda p: p["result"]["records"][0].update(Id="bad"), "trustworthy 301"),
        (lambda p: p["result"]["records"][0].update(Status="Active"), "not a Draft"),
        (
            lambda p: p["result"]["records"][0]["Definition"].update(
                DeveloperName="Other_Flow"
            ),
            "outside the affected Flow set",
        ),
        (
            lambda p: p["result"]["records"][0].update(VersionNumber=0),
            "must be positive",
        ),
        (
            lambda p: p["result"]["records"][0].update(
                CreatedDate="2026-08-18T18:59:59Z"
            ),
            "outside the deployment window",
        ),
        (
            lambda p: p["result"]["records"][1].update(Id="301123456789012"),
            "duplicate Flow id",
        ),
    ],
)
def test_draft_query_rejects_incomplete_or_out_of_scope_rows(mutation, message: str) -> None:
    payload = copy.deepcopy(draft_query())
    mutation(payload)
    with pytest.raises(guard.GuardError, match=message):
        evaluate_drafts(payload)


def activation_query() -> dict:
    return {
        "status": 0,
        "result": {
            "done": True,
            "totalSize": 2,
            "records": [
                {
                    "DeveloperName": FLOWS[0],
                    "ActiveVersion": {"VersionNumber": 3},
                    "LatestVersion": {"VersionNumber": 3},
                },
                {
                    "DeveloperName": FLOWS[1],
                    "ActiveVersion": {"VersionNumber": 7},
                    "LatestVersion": {"VersionNumber": 7},
                },
            ],
        },
    }


def test_activation_query_requires_latest_version_active_for_every_flow() -> None:
    result = guard.evaluate_activation_query(activation_query(), flows=FLOWS)
    assert result == {
        "decision": "ready",
        "active": [
            {"flow": FLOWS[0], "version": 3},
            {"flow": FLOWS[1], "version": 7},
        ],
    }


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (lambda p: p["result"].update(totalSize=1), "does not reconcile"),
        (
            lambda p: (
                p["result"]["records"].pop(),
                p["result"].update(totalSize=1),
            ),
            "omitted affected Flow",
        ),
        (
            lambda p: p["result"]["records"][1].update(DeveloperName=FLOWS[0]),
            "unexpected or duplicate",
        ),
        (
            lambda p: p["result"]["records"][0].update(ActiveVersion=None),
            "ActiveVersion.VersionNumber",
        ),
        (
            lambda p: p["result"]["records"][0]["LatestVersion"].update(
                VersionNumber=4
            ),
            "latest v4 is not active",
        ),
    ],
)
def test_activation_query_rejects_missing_duplicate_or_inactive_flows(
    mutation, message: str
) -> None:
    payload = copy.deepcopy(activation_query())
    mutation(payload)
    with pytest.raises(guard.GuardError, match=message):
        guard.evaluate_activation_query(payload, flows=FLOWS)


@pytest.mark.parametrize("flows", [[], ["bad-name"], [FLOWS[0], FLOWS[0]]])
def test_every_mode_rejects_missing_malformed_or_duplicate_flow_names(flows) -> None:
    with pytest.raises(guard.GuardError):
        guard.evaluate_activation_query(activation_query(), flows=flows)
