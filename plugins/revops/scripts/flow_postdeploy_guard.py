#!/usr/bin/env python3
"""Fail-closed proof for dev Flow activation and Draft-cleanup ownership."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable


DEPLOY_ID = re.compile(r"^0Af[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?$")
FLOW_ID = re.compile(r"^301[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?$")
FLOW_NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
MAX_DEPLOY_WINDOW = timedelta(hours=6)


class GuardError(ValueError):
    """The supplied evidence cannot authorize the next post-deploy step."""


def _nonnegative_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise GuardError(f"{label} must be a non-negative integer; got {value!r}")
    return value


def _positive_int(value: Any, label: str) -> int:
    number = _nonnegative_int(value, label)
    if number == 0:
        raise GuardError(f"{label} must be positive")
    return number


def _timestamp(value: Any, label: str) -> datetime:
    if not isinstance(value, str) or not value:
        raise GuardError(f"{label} must be an ISO 8601 timestamp")
    candidate = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError as exc:
        raise GuardError(f"{label} must be an ISO 8601 timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise GuardError(f"{label} must include a timezone")
    return parsed.astimezone(timezone.utc)


def _utc_literal(value: datetime) -> str:
    return value.isoformat().replace("+00:00", "Z")


def _flows(values: Iterable[str]) -> tuple[str, ...]:
    names = tuple(values)
    if not names:
        raise GuardError("at least one affected Flow name is required")
    for name in names:
        if not isinstance(name, str) or not FLOW_NAME.fullmatch(name):
            raise GuardError(f"invalid affected Flow name: {name!r}")
    if len(set(names)) != len(names):
        raise GuardError("affected Flow names must be unique")
    return tuple(sorted(names))


def _complete_query(payload: Any) -> list[dict[str, Any]]:
    status = payload.get("status") if isinstance(payload, dict) else None
    if isinstance(status, bool) or status != 0:
        raise GuardError("query receipt must be a CLI status-0 object")
    result = payload.get("result")
    if not isinstance(result, dict) or result.get("done") is not True:
        raise GuardError("query result must be a completed object")
    records = result.get("records")
    if not isinstance(records, list):
        raise GuardError("query result.records must be an array")
    total = _nonnegative_int(result.get("totalSize"), "query result.totalSize")
    if total != len(records):
        raise GuardError(f"query totalSize does not reconcile ({total} vs {len(records)})")
    if not all(isinstance(record, dict) for record in records):
        raise GuardError("every query record must be an object")
    return records


def evaluate_deploy_receipt(
    payload: Any,
    *,
    deploy_id: str,
    flows: Iterable[str],
    now: datetime | None = None,
) -> dict[str, Any]:
    names = _flows(flows)
    if not DEPLOY_ID.fullmatch(deploy_id):
        raise GuardError("deploy id must be a trustworthy 0Af id")
    status = payload.get("status") if isinstance(payload, dict) else None
    if isinstance(status, bool) or status != 0:
        raise GuardError("deploy receipt must be a CLI status-0 object")
    result = payload.get("result")
    if not isinstance(result, dict):
        raise GuardError("deploy receipt has no result object")
    if result.get("id") != deploy_id:
        raise GuardError("deploy receipt id does not match the requested deployment")
    if (
        result.get("done") is not True
        or result.get("success") is not True
        or result.get("status") != "Succeeded"
        or result.get("checkOnly") is not False
    ):
        raise GuardError("deployment is not a completed, successful, real deploy")

    started = _timestamp(result.get("startDate"), "result.startDate")
    completed = _timestamp(result.get("completedDate"), "result.completedDate")
    current = now or datetime.now(timezone.utc)
    if current.tzinfo is None or current.utcoffset() is None:
        raise GuardError("current time must include a timezone")
    current = current.astimezone(timezone.utc)
    if started > completed:
        raise GuardError("deployment start is after completion")
    if completed > current:
        raise GuardError("deployment completion is in the future")
    if completed - started > MAX_DEPLOY_WINDOW:
        raise GuardError("deployment window is longer than six hours")

    details = result.get("details")
    if not isinstance(details, dict) or "componentSuccesses" not in details:
        raise GuardError("deploy details must report componentSuccesses")
    raw_rows = details["componentSuccesses"]
    rows = [raw_rows] if isinstance(raw_rows, dict) else raw_rows
    if not isinstance(rows, list) or not rows:
        raise GuardError("componentSuccesses must be a non-empty object or array")
    flow_counts: Counter[str] = Counter()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise GuardError(f"componentSuccesses[{index}] must be an object")
        component_type = row.get("componentType")
        full_name = row.get("fullName")
        if not isinstance(component_type, str) or not component_type:
            raise GuardError(f"componentSuccesses[{index}].componentType is malformed")
        if not isinstance(full_name, str) or not full_name:
            raise GuardError(f"componentSuccesses[{index}].fullName is malformed")
        if component_type == "Flow":
            flow_counts[full_name] += 1
    for name in names:
        if flow_counts[name] != 1:
            raise GuardError(
                f"affected Flow {name!r} must appear exactly once in componentSuccesses"
            )

    return {
        "decision": "ready",
        "deploy_id": deploy_id,
        "flows": list(names),
        "window_start": _utc_literal(started),
        "window_end": _utc_literal(completed),
    }


def evaluate_draft_query(
    payload: Any,
    *,
    flows: Iterable[str],
    window_start: str,
    window_end: str,
) -> dict[str, Any]:
    names = _flows(flows)
    allowed = set(names)
    started = _timestamp(window_start, "window start")
    completed = _timestamp(window_end, "window end")
    if started > completed or completed - started > MAX_DEPLOY_WINDOW:
        raise GuardError("cleanup window is reversed or longer than six hours")

    records = _complete_query(payload)
    ids: set[str] = set()
    drafts: list[dict[str, Any]] = []
    for index, record in enumerate(records):
        flow_id = record.get("Id")
        if not isinstance(flow_id, str) or not FLOW_ID.fullmatch(flow_id):
            raise GuardError(f"records[{index}].Id is not a trustworthy 301 id")
        if flow_id in ids:
            raise GuardError(f"duplicate Flow id in query result: {flow_id}")
        ids.add(flow_id)
        if record.get("Status") != "Draft":
            raise GuardError(f"records[{index}] is not a Draft")
        definition = record.get("Definition")
        name = definition.get("DeveloperName") if isinstance(definition, dict) else None
        if name not in allowed:
            raise GuardError(f"records[{index}] is outside the affected Flow set")
        version = _positive_int(record.get("VersionNumber"), f"records[{index}].VersionNumber")
        created = _timestamp(record.get("CreatedDate"), f"records[{index}].CreatedDate")
        if not started <= created <= completed:
            raise GuardError(f"records[{index}] is outside the deployment window")
        drafts.append(
            {
                "id": flow_id,
                "flow": name,
                "version": version,
                "created_at": _utc_literal(created),
            }
        )

    return {
        "decision": "ready",
        "draft_count": len(drafts),
        "delete_ids": [draft["id"] for draft in drafts],
        "drafts": drafts,
    }


def evaluate_activation_query(payload: Any, *, flows: Iterable[str]) -> dict[str, Any]:
    names = _flows(flows)
    expected = set(names)
    records = _complete_query(payload)
    seen: set[str] = set()
    active: list[dict[str, Any]] = []
    for index, record in enumerate(records):
        name = record.get("DeveloperName")
        if name not in expected or name in seen:
            raise GuardError(f"records[{index}] has an unexpected or duplicate Flow name")
        seen.add(name)
        active_node = record.get("ActiveVersion")
        latest_node = record.get("LatestVersion")
        active_version = _positive_int(
            active_node.get("VersionNumber") if isinstance(active_node, dict) else None,
            f"records[{index}].ActiveVersion.VersionNumber",
        )
        latest_version = _positive_int(
            latest_node.get("VersionNumber") if isinstance(latest_node, dict) else None,
            f"records[{index}].LatestVersion.VersionNumber",
        )
        if active_version != latest_version:
            raise GuardError(
                f"Flow {name!r} latest v{latest_version} is not active (active v{active_version})"
            )
        active.append({"flow": name, "version": active_version})
    if seen != expected:
        missing = ", ".join(sorted(expected - seen))
        raise GuardError(f"activation query omitted affected Flow(s): {missing}")
    return {"decision": "ready", "active": sorted(active, key=lambda row: row["flow"])}


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="kind", required=True)
    for kind in ("receipt", "draft-query", "activation-query"):
        command = subparsers.add_parser(kind)
        command.add_argument("evidence", type=Path)
        command.add_argument("--flow", action="append", required=True)
        if kind == "receipt":
            command.add_argument("--deploy-id", required=True)
        if kind == "draft-query":
            command.add_argument("--window-start", required=True)
            command.add_argument("--window-end", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        payload = json.loads(args.evidence.read_text(encoding="utf-8"))
        if args.kind == "receipt":
            result = evaluate_deploy_receipt(
                payload, deploy_id=args.deploy_id, flows=args.flow
            )
        elif args.kind == "draft-query":
            result = evaluate_draft_query(
                payload,
                flows=args.flow,
                window_start=args.window_start,
                window_end=args.window_end,
            )
        else:
            result = evaluate_activation_query(payload, flows=args.flow)
    except (OSError, json.JSONDecodeError, GuardError) as exc:
        print(json.dumps({"decision": "blocked", "reason": str(exc)}, sort_keys=True))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
