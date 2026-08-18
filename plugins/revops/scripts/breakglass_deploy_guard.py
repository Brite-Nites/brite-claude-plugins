#!/usr/bin/env python3
"""Fail-closed parser for the emergency production deploy receipts.

The emergency command owns the live I/O. This helper owns the deterministic
question the prose must not improvise: did the CLI return a completed successful
deploy, and (when Apex changed) did RunLocalTests produce zero failures and at
least the required weighted coverage?
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
from pathlib import Path
from typing import Any


DEPLOY_ID = re.compile(r"^0Af[A-Za-z0-9]{12,15}$")
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
ACK_URL = re.compile(
    r"^https://github\.com/Brite-Nites/brite-salesforce/"
    r"(?:issues|pull)/(\d+)#issuecomment-(\d+)$"
)
PROD_ADMINS = {"holdeeno", "kells-source"}


class GuardError(ValueError):
    """The receipt cannot authorize the next break-glass step."""


def evaluate_ack_receipt(
    payload: Any,
    *,
    operator: str,
    second_admin: str,
    ack_url: str,
    reason: str,
    approved_sha: str,
) -> dict[str, Any]:
    if {operator, second_admin} != PROD_ADMINS or operator == second_admin:
        raise GuardError("operator and second admin must be the two distinct production admins")
    if not FULL_SHA.fullmatch(approved_sha):
        raise GuardError("approved SHA must be 40 lowercase hexadecimal characters")
    if not reason or reason.strip() != reason or "\n" in reason or len(reason) > 500:
        raise GuardError("reason must be one nonblank line of at most 500 characters")
    url_match = ACK_URL.fullmatch(ack_url)
    if not url_match:
        raise GuardError("ack URL must be a brite-salesforce issue or PR comment permalink")
    if not isinstance(payload, dict):
        raise GuardError("acknowledgement receipt root must be an object")
    if payload.get("html_url") != ack_url:
        raise GuardError("acknowledgement permalink does not match the fetched comment")
    comment_id = payload.get("id")
    if isinstance(comment_id, bool) or comment_id != int(url_match.group(2)):
        raise GuardError("acknowledgement comment id does not match its permalink")
    user = payload.get("user")
    if not isinstance(user, dict) or user.get("login") != second_admin:
        raise GuardError("acknowledgement was not authored by the named second admin")
    body = payload.get("body")
    if not isinstance(body, str):
        raise GuardError("acknowledgement comment has no text body")
    lines = {line.rstrip("\r") for line in body.splitlines()}
    required_lines = {
        "BREAKGLASS-ACK",
        f"operator: {operator}",
        f"sha: {approved_sha}",
        f"reason: {reason}",
    }
    missing = sorted(required_lines - lines)
    if missing:
        raise GuardError("acknowledgement is missing exact structured fields")
    return {
        "decision": "ready",
        "operator": operator,
        "second_admin": second_admin,
        "approved_sha": approved_sha,
        "comment_id": comment_id,
        "ack_url": ack_url,
    }


def _nonnegative_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise GuardError(f"{label} must be a non-negative integer; got {value!r}")
    return value


def _completed_result(payload: Any, *, expected_check_only: bool) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise GuardError("CLI receipt root must be an object")
    status = payload.get("status")
    if isinstance(status, bool) or status != 0:
        raise GuardError(f"CLI receipt status is not integer 0 ({status!r})")

    result = payload.get("result")
    if not isinstance(result, dict):
        raise GuardError("CLI receipt has no result object")
    if (
        result.get("done") is not True
        or result.get("success") is not True
        or result.get("status") != "Succeeded"
    ):
        raise GuardError(
            "deploy is not a completed success "
            f"(done={result.get('done')!r}, success={result.get('success')!r}, "
            f"status={result.get('status')!r})"
        )
    if result.get("checkOnly") is not expected_check_only:
        raise GuardError(
            f"deploy checkOnly must be {expected_check_only!r}; "
            f"got {result.get('checkOnly')!r}"
        )

    deploy_id = result.get("id")
    if not isinstance(deploy_id, str) or not DEPLOY_ID.fullmatch(deploy_id):
        raise GuardError(f"deploy result has no trustworthy 0Af id ({deploy_id!r})")

    details = result.get("details")
    if not isinstance(details, dict):
        raise GuardError("deploy result has no details object")
    if "componentFailures" not in details:
        raise GuardError("deploy details must explicitly report componentFailures")
    failures = details.get("componentFailures")
    if failures not in (None, [], {}):
        raise GuardError("deploy receipt contains componentFailures")

    component_errors = _nonnegative_int(
        result.get("numberComponentErrors"), "result.numberComponentErrors"
    )
    if component_errors:
        raise GuardError(f"deploy reports {component_errors} component error(s)")
    total = _nonnegative_int(
        result.get("numberComponentsTotal"), "result.numberComponentsTotal"
    )
    deployed = _nonnegative_int(
        result.get("numberComponentsDeployed"), "result.numberComponentsDeployed"
    )
    if total == 0:
        raise GuardError("deploy receipt contains zero components")
    if deployed != total:
        raise GuardError(
            f"component totals do not reconcile ({deployed} deployed of {total})"
        )
    return result


def _test_failure_count(run_tests: dict[str, Any]) -> int:
    if "numFailures" not in run_tests:
        raise GuardError("runTestResult has no explicit numFailures")
    failures = _nonnegative_int(run_tests["numFailures"], "runTestResult.numFailures")
    failure_rows = run_tests.get("failures")
    if failures == 0 and failure_rows not in (None, [], {}):
        raise GuardError("runTestResult reports zero failures but includes failure rows")
    if failures > 0 and not isinstance(failure_rows, (dict, list)):
        raise GuardError("runTestResult failure count has no failure details")
    return failures


def _weighted_coverage(run_tests: dict[str, Any]) -> float:
    rows = run_tests.get("codeCoverage")
    if not isinstance(rows, list) or not rows:
        raise GuardError("Apex changed but runTestResult.codeCoverage is absent or empty")

    total_locations = 0
    uncovered_locations = 0
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise GuardError(f"codeCoverage[{index}] must be an object")
        total = _nonnegative_int(
            row.get("numLocations"), f"codeCoverage[{index}].numLocations"
        )
        uncovered = _nonnegative_int(
            row.get("numLocationsNotCovered"),
            f"codeCoverage[{index}].numLocationsNotCovered",
        )
        if uncovered > total:
            raise GuardError(
                f"codeCoverage[{index}] has {uncovered} uncovered of {total} locations"
            )
        total_locations += total
        uncovered_locations += uncovered

    if total_locations == 0:
        raise GuardError("Apex coverage contains zero executable locations")
    return 100.0 * (total_locations - uncovered_locations) / total_locations


def evaluate_validate_receipt(
    payload: Any, *, require_apex_coverage: bool, minimum_coverage: float = 90.0
) -> dict[str, Any]:
    if (
        isinstance(minimum_coverage, bool)
        or not isinstance(minimum_coverage, (int, float))
        or not math.isfinite(minimum_coverage)
        or not 0 <= minimum_coverage <= 100
    ):
        raise GuardError("minimum coverage must be a finite percentage from 0 to 100")

    result = _completed_result(payload, expected_check_only=True)
    details = result["details"]
    run_tests = details.get("runTestResult")

    coverage: float | None = None
    if not isinstance(run_tests, dict):
        raise GuardError("RunLocalTests validation requires a runTestResult object")
    failures = _test_failure_count(run_tests)
    if failures:
        raise GuardError(f"RunLocalTests reported {failures} failure(s)")
    test_errors = _nonnegative_int(
        result.get("numberTestErrors"), "result.numberTestErrors"
    )
    if test_errors:
        raise GuardError(f"deploy reports {test_errors} test error(s)")
    tests_total = _nonnegative_int(
        result.get("numberTestsTotal"), "result.numberTestsTotal"
    )
    tests_completed = _nonnegative_int(
        result.get("numberTestsCompleted"), "result.numberTestsCompleted"
    )
    if tests_total == 0:
        raise GuardError("RunLocalTests reported zero tests")
    if tests_completed != tests_total:
        raise GuardError(
            f"test totals do not reconcile ({tests_completed} completed of {tests_total})"
        )

    if require_apex_coverage:
        coverage = _weighted_coverage(run_tests)
        if coverage + 1e-12 < minimum_coverage:
            raise GuardError(
                f"weighted Apex coverage is {coverage:.2f}%, below {minimum_coverage:.2f}%"
            )

    return {
        "decision": "ready",
        "deploy_id": result["id"],
        "components_total": result["numberComponentsTotal"],
        "test_failures": failures,
        "apex_coverage_required": require_apex_coverage,
        "apex_coverage_percent": None if coverage is None else round(coverage, 2),
    }


def evaluate_quick_receipt(payload: Any) -> dict[str, Any]:
    result = _completed_result(payload, expected_check_only=False)
    deployed = result["numberComponentsDeployed"]
    return {
        "decision": "ready",
        "deploy_id": result["id"],
        "components_deployed": deployed,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=("ack", "validate", "quick"))
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--require-apex-coverage", action="store_true")
    parser.add_argument("--minimum-coverage", type=float, default=90.0)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        payload = json.loads(args.receipt.read_text(encoding="utf-8"))
        if args.kind == "ack":
            names = (
                "ACK_OPERATOR",
                "ACK_SECOND_ADMIN",
                "ACK_URL",
                "ACK_REASON",
                "ACK_SHA",
            )
            values = {name: os.environ.get(name) for name in names}
            missing = [name for name, value in values.items() if value is None]
            if missing:
                raise GuardError("missing acknowledgement environment: " + ", ".join(missing))
            result = evaluate_ack_receipt(
                payload,
                operator=values["ACK_OPERATOR"] or "",
                second_admin=values["ACK_SECOND_ADMIN"] or "",
                ack_url=values["ACK_URL"] or "",
                reason=values["ACK_REASON"] or "",
                approved_sha=values["ACK_SHA"] or "",
            )
        elif args.kind == "validate":
            result = evaluate_validate_receipt(
                payload,
                require_apex_coverage=args.require_apex_coverage,
                minimum_coverage=args.minimum_coverage,
            )
        else:
            if args.require_apex_coverage:
                raise GuardError("--require-apex-coverage is valid only for validate receipts")
            result = evaluate_quick_receipt(payload)
    except (OSError, json.JSONDecodeError, GuardError) as exc:
        print(json.dumps({"decision": "blocked", "reason": str(exc)}, sort_keys=True))
        return 2

    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
