#!/usr/bin/env python3
"""Deterministic decision core for the ADR-026 promotion topology (BC-19521).

The revops commands are orchestrators, not engines. Five decisions inside them
are pure functions of their inputs, so they live here instead of as prose the
model is asked to follow:

  --classify <alias>        Is this org alias safe to deploy to from a laptop?
  --resolve-dev-org -       Which brite-dev-<name> org is THIS developer's?
  --concurrency-verdict -   Is a deploy to this org safe to start right now?
  --pipeline-guidance <dir> What does the repo-local pipeline config say?
  --validate-prod-workflow - Does main expose the complete prod dispatch contract?

Every one of them FAILS CLOSED. An unparseable input, a missing field, or an
unknown alias produces a blocking verdict, never a permissive one. That is the
whole reason these are code: the old Phase 0.5 concurrency lookback was prose
that said "do not halt over an advisory check", so a Tooling API error read as
"nobody else is deploying".

Data source: config/org-aliases.json — the single protected-alias list, shared
with the brite-salesforce PreToolUse deploy-policy hook (BC-19519). This module
is a convenience reader; the JSON is the contract.

Stdlib-only, side-effect-free: no network call, no shell-out, no filesystem
write. Reads are limited to the plugin's own config file and (for
--pipeline-guidance) a named repo-local config file.

Exit codes:
  0  the decision was computed (read the emitted JSON's `decision` field)
  2  usage error — bad flags, unreadable config, missing stdin payload
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import textwrap
from pathlib import Path
from typing import Any

CONFIG_DIR = Path(__file__).resolve().parent.parent / "config"
ORG_ALIASES = CONFIG_DIR / "org-aliases.json"
PIPELINE_CONFIG_NAME = ".revops-pipeline.json"

# Same character set as validate_target_org.py — kept independent on purpose so
# a change to one does not silently widen the other.
ALIAS_SHAPE_RE = re.compile(r"^[a-zA-Z0-9._@-]+$")


# ── registry ────────────────────────────────────────────────────────────────


def load_registry(path: Path | None = None) -> dict[str, Any]:
    """Load config/org-aliases.json. Raises on anything unreadable."""
    p = path or ORG_ALIASES
    with open(p, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict) or "orgs" not in data:
        raise ValueError(f"{p}: not an org-alias registry (no `orgs` key)")
    return data


def protected_aliases(reg: dict[str, Any]) -> list[str]:
    return list(reg.get("protected_aliases", []))


def classify(alias: str, reg: dict[str, Any]) -> dict[str, Any]:
    """Classify *alias* against the registry.

    Returns a verdict dict with `decision` in:
      allow    — a per-developer org; local deploy is the intended path
      warn     — a legacy org; local deploy works but is being retired
      block    — a CI-deployed org; a local deploy must be refused
      unknown  — not in the registry; treated as BLOCKING (fail closed)
      invalid  — not a legal SF alias shape; treated as BLOCKING
    """
    if not alias or not ALIAS_SHAPE_RE.fullmatch(alias):
        return {
            "decision": "invalid",
            "alias": alias,
            "blocking": True,
            "reason": "not a legal Salesforce org alias shape (^[a-zA-Z0-9._@-]+$)",
        }

    dev = reg.get("dev_org", {})
    pattern = dev.get("alias_pattern")
    if pattern and re.fullmatch(pattern, alias):
        return {
            "decision": "allow",
            "alias": alias,
            "blocking": False,
            "lane": dev.get("lane", "inner-loop"),
            "reason": "per-developer org — the intended inner-loop deploy target",
        }

    for org in reg.get("orgs", []):
        names = [org.get("alias")] + list(org.get("aka", []))
        if alias not in names:
            continue
        enforcement = org.get("enforcement", "block")
        return {
            "decision": enforcement,
            "alias": alias,
            "canonical_alias": org.get("alias"),
            "blocking": enforcement == "block",
            "lane": org.get("lane"),
            "status": org.get("status"),
            "deploy_via": org.get("deploy_via"),
            "replaced_by": org.get("replaced_by"),
            "reason": org.get("description", ""),
        }

    return {
        "decision": "unknown",
        "alias": alias,
        "blocking": True,
        "reason": (
            "alias is not in config/org-aliases.json. Unknown orgs fail closed — "
            "add the org to the registry before deploying to it."
        ),
    }


# ── dev-org resolution ──────────────────────────────────────────────────────


def _org_rows(sf_org_list: dict[str, Any]) -> list[dict[str, Any]]:
    """Flatten an `sf org list --json` envelope into one list of org rows."""
    result = sf_org_list.get("result", {})
    if not isinstance(result, dict):
        return []
    rows: list[dict[str, Any]] = []
    for key in ("nonScratchOrgs", "sandboxes", "scratchOrgs", "devHubs", "other"):
        value = result.get(key)
        if isinstance(value, list):
            rows.extend(r for r in value if isinstance(r, dict))
    return rows


def resolve_dev_org(
    sf_org_list: dict[str, Any],
    reg: dict[str, Any],
    requested: str | None = None,
    connected_only: bool = True,
) -> dict[str, Any]:
    """Resolve the developer's own brite-dev-<name> org. Never guesses.

    `decision` is one of:
      resolved   — exactly one candidate (or `requested` matched one)
      ambiguous  — more than one candidate; the caller MUST prompt
      none       — no brite-dev-<name> org is authenticated
      rejected   — `requested` is not a per-developer org alias
      unusable   — the `sf org list` payload could not be read (fail closed)
    """
    if sf_org_list.get("status") not in (0, None):
        return {
            "decision": "unusable",
            "candidates": [],
            "reason": f"`sf org list --json` returned status {sf_org_list.get('status')}",
        }

    pattern = reg.get("dev_org", {}).get("alias_pattern")
    if not pattern:
        return {
            "decision": "unusable",
            "candidates": [],
            "reason": "registry has no dev_org.alias_pattern",
        }

    rows = _org_rows(sf_org_list)
    if not rows:
        return {
            "decision": "unusable",
            "candidates": [],
            "reason": "no org rows in the `sf org list --json` payload",
        }

    candidates: list[dict[str, Any]] = []
    seen: set[str] = set()
    for row in rows:
        # An org can carry several aliases; `alias` is the singular field and
        # `aliases` the list form. Check both so a multi-aliased dev org is
        # still found under its brite-dev-<name> name.
        names = [row.get("alias")] + list(row.get("aliases") or [])
        for name in names:
            if not name or name in seen or not re.fullmatch(pattern, name):
                continue
            connected = row.get("connectedStatus") == "Connected"
            if connected_only and not connected:
                continue
            seen.add(name)
            candidates.append(
                {
                    "alias": name,
                    "username": row.get("username"),
                    "connectedStatus": row.get("connectedStatus"),
                }
            )

    candidates.sort(key=lambda c: c["alias"])

    if requested:
        verdict = classify(requested, reg)
        if verdict["decision"] != "allow":
            return {
                "decision": "rejected",
                "requested": requested,
                "candidates": candidates,
                "reason": (
                    f"`{requested}` is not a per-developer org "
                    f"(classified `{verdict['decision']}`). "
                    "Inner-loop deploys only target brite-dev-<name>."
                ),
            }
        match = [c for c in candidates if c["alias"] == requested]
        if match:
            return {"decision": "resolved", "alias": requested, "candidates": match}
        return {
            "decision": "none",
            "requested": requested,
            "candidates": candidates,
            "reason": (
                f"`{requested}` matches the per-developer pattern but is not "
                "authenticated on this machine. Run /revops:setup-dev-workspace."
            ),
        }

    if len(candidates) == 1:
        return {"decision": "resolved", "alias": candidates[0]["alias"], "candidates": candidates}
    if len(candidates) > 1:
        return {
            "decision": "ambiguous",
            "candidates": candidates,
            "reason": (
                f"{len(candidates)} per-developer orgs are authenticated. "
                "Ask which one to use — never pick one silently."
            ),
        }
    return {
        "decision": "none",
        "candidates": [],
        "reason": (
            "no authenticated brite-dev-<name> org on this machine. "
            "Run /revops:setup-dev-workspace."
        ),
    }


# ── concurrency probe ───────────────────────────────────────────────────────


def concurrency_verdict(payload: dict[str, Any]) -> dict[str, Any]:
    """Decide whether a deploy may start, from two DeployRequest query results.

    Input shape (the command assembles this from two `sf data query` calls):

        {"target_org": "...", "lookback_hours": 24, "override": false,
         "in_flight": <raw sf JSON>, "recent": <raw sf JSON>}

    `decision` is one of:
      clear            — no in-flight deploy, no recent deploy; proceed
      blocked_inflight — a DeployRequest is InProgress; BLOCK, override cannot clear it
      blocked_recent   — a deploy landed inside the lookback; BLOCK unless override
      blocked_error    — a query failed or was unreadable; BLOCK (fail closed)
      override         — a blocking condition was overridden by explicit flag

    Fails CLOSED throughout. A missing key, a non-zero `status`, or an
    unexpected shape produces `blocked_error`, never `clear`.
    """
    override = bool(payload.get("override"))

    def rows(key: str) -> list[dict[str, Any]] | None:
        raw = payload.get(key)
        if not isinstance(raw, dict):
            return None
        if raw.get("status") != 0:
            return None
        result = raw.get("result")
        if not isinstance(result, dict):
            return None
        records = result.get("records")
        if not isinstance(records, list):
            return None
        return [r for r in records if isinstance(r, dict)]

    in_flight = rows("in_flight")
    if in_flight is None:
        return {
            "decision": "blocked_error",
            "blocking": True,
            "overridable": False,
            "reason": (
                "the in-flight DeployRequest query did not return a readable result. "
                "The probe FAILS CLOSED: an unanswered question is not a `no`."
            ),
        }

    active = [r for r in in_flight if r.get("Status") in ("InProgress", "Pending", "Canceling")]
    if active:
        return {
            "decision": "blocked_inflight",
            "blocking": True,
            "overridable": False,
            "records": active,
            "reason": (
                f"{len(active)} deploy(s) currently in flight against "
                f"{payload.get('target_org', 'the target org')}. Two concurrent "
                "deploys to one org interleave unpredictably. Wait for it to finish."
            ),
        }

    recent = rows("recent")
    if recent is None:
        return {
            "decision": "blocked_error",
            "blocking": True,
            "overridable": False,
            "reason": (
                "the recent-deploy lookback query did not return a readable result. "
                "The probe FAILS CLOSED."
            ),
        }

    if recent:
        if override:
            return {
                "decision": "override",
                "blocking": False,
                "overridable": True,
                "records": recent,
                "reason": (
                    f"{len(recent)} deploy(s) inside the last "
                    f"{payload.get('lookback_hours', 24)}h — overridden by explicit flag."
                ),
            }
        return {
            "decision": "blocked_recent",
            "blocking": True,
            "overridable": True,
            "records": recent,
            "reason": (
                f"{len(recent)} deploy(s) landed in the last "
                f"{payload.get('lookback_hours', 24)}h against "
                f"{payload.get('target_org', 'the target org')}. Coordinate with the "
                "prior deployer, or re-run with --override-concurrency."
            ),
        }

    return {
        "decision": "clear",
        "blocking": False,
        "overridable": False,
        "records": [],
        "reason": "no in-flight deploy and none inside the lookback window.",
    }


# ── pipeline guidance (ADR-026 section 5) ───────────────────────────────────


def pipeline_guidance(repo_root: str | Path, lane: str | None = None) -> dict[str, Any]:
    """Read the repo-local `.revops-pipeline.json` and describe the next step.

    `decision` is one of:
      no_config  — the file is absent; guidance NO-OPS and the command proceeds
      unreadable — the file exists but is not valid JSON; guidance no-ops loudly
      guidance   — a lane map was found

    This layer GUIDES. It never blocks, and it never claims to enforce — the
    platform enforces (ADR-026 section 5 / brite-salesforce ADR-016).
    """
    path = Path(repo_root) / PIPELINE_CONFIG_NAME
    if not path.is_file():
        return {
            "decision": "no_config",
            "enforcing": False,
            "reason": (
                f"no {PIPELINE_CONFIG_NAME} in {repo_root} — guidance layer no-ops. "
                "This is the normal state in any repo that is not brite-salesforce."
            ),
        }
    try:
        with open(path, encoding="utf-8") as fh:
            cfg = json.load(fh)
    except (OSError, ValueError) as exc:
        return {
            "decision": "unreadable",
            "enforcing": False,
            "reason": f"{path} exists but could not be read: {exc}. Guidance layer no-ops.",
        }

    lanes = cfg.get("lanes", [])
    if not isinstance(lanes, list) or not lanes:
        return {
            "decision": "unreadable",
            "enforcing": False,
            "reason": f"{path} has no usable `lanes` array. Guidance layer no-ops.",
        }

    out: dict[str, Any] = {
        "decision": "guidance",
        "enforcing": False,
        "lanes": lanes,
        "ci": cfg.get("ci", {}),
        "concurrency": cfg.get("concurrency", {}),
        "note": "revops guides; the platform enforces. Nothing here is a gate.",
    }
    if lane:
        current = next((entry for entry in lanes if entry.get("name") == lane), None)
        out["current_lane"] = current
        if current and current.get("next"):
            out["next_lane"] = next(
                (entry for entry in lanes if entry.get("name") == current["next"]), None
            )
    return out


# ── production workflow contract ───────────────────────────────────────────


def _yaml_block(
    lines: list[str], key: str, start: int = 0, stop: int | None = None
) -> tuple[int, int, int]:
    """Locate an indentation-delimited YAML mapping block without a YAML dependency."""
    stop = len(lines) if stop is None else stop
    for index in range(start, stop):
        stripped = lines[index].strip()
        if stripped != f"{key}:" or stripped.startswith("#"):
            continue
        parent_indent = len(lines[index]) - len(lines[index].lstrip(" "))
        end = index + 1
        while end < stop:
            candidate = lines[end]
            candidate_indent = len(candidate) - len(candidate.lstrip(" "))
            if (
                candidate.strip()
                and not candidate.lstrip().startswith("#")
                and candidate_indent <= parent_indent
            ):
                break
            end += 1
        return index, end, parent_indent
    raise ValueError(f"missing `{key}` block")


def _yaml_direct_children(
    lines: list[str], start: int, stop: int, parent_indent: int
) -> dict[str, tuple[int, int]]:
    """Return direct mapping children and their indentation-delimited spans."""
    child_indent: int | None = None
    children: dict[str, tuple[int, int]] = {}
    indexes: list[tuple[str, int]] = []

    for index in range(start + 1, stop):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        line_indent = len(line) - len(line.lstrip(" "))
        if line_indent <= parent_indent:
            continue
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):(?:\s|$)", line.strip())
        if not match:
            continue
        if child_indent is None:
            child_indent = line_indent
        if line_indent == child_indent:
            indexes.append((match.group(1), index))

    for offset, (name, index) in enumerate(indexes):
        end = indexes[offset + 1][1] if offset + 1 < len(indexes) else stop
        children[name] = (index, end)
    return children


def _yaml_named_steps(
    lines: list[str], start: int, stop: int, parent_indent: int
) -> dict[str, tuple[int, int]]:
    """Return top-level ``- name:`` steps inside one YAML ``steps`` list."""
    step_indent: int | None = None
    indexes: list[tuple[str, int]] = []
    for index in range(start + 1, stop):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        line_indent = len(line) - len(line.lstrip(" "))
        if line_indent <= parent_indent:
            continue
        match = re.match(r"^-\s+name:\s*['\"]?(.+?)['\"]?\s*$", line.strip())
        if not match:
            continue
        if step_indent is None:
            step_indent = line_indent
        if line_indent == step_indent:
            indexes.append((match.group(1), index))

    steps: dict[str, tuple[int, int]] = {}
    for offset, (name, index) in enumerate(indexes):
        end = indexes[offset + 1][1] if offset + 1 < len(indexes) else stop
        if name in steps:
            raise ValueError(f"duplicate workflow step name: {name}")
        steps[name] = (index, end)
    return steps


def _yaml_literal_block(
    lines: list[str], key: str, start: int, stop: int
) -> tuple[int, int, str]:
    """Return one indentation-delimited ``key: |`` scalar body."""
    matches: list[tuple[int, int, str]] = []
    for index in range(start, stop):
        if lines[index].strip() != f"{key}: |":
            continue
        indent = len(lines[index]) - len(lines[index].lstrip(" "))
        end = index + 1
        while end < stop:
            candidate = lines[end]
            candidate_indent = len(candidate) - len(candidate.lstrip(" "))
            if candidate.strip() and candidate_indent <= indent:
                break
            end += 1
        matches.append((index, end, "\n".join(lines[index + 1 : end])))
    if len(matches) != 1:
        raise ValueError(f"expected one `{key}: |` block; found {len(matches)}")
    return matches[0]


def _yaml_scalar_child(
    lines: list[str], children: dict[str, tuple[int, int]], key: str
) -> str:
    """Return one direct scalar mapping value, rejecting nested/decoy text."""
    if key not in children:
        raise ValueError(f"missing direct `{key}` field")
    line = lines[children[key][0]].strip()
    match = re.fullmatch(rf"{re.escape(key)}:\s*(\S(?:.*\S)?)?", line)
    if not match or not match.group(1):
        raise ValueError(f"`{key}` must be a scalar value")
    return match.group(1)


def _yaml_scalar_sequence(
    lines: list[str], start: int, stop: int
) -> set[str]:
    """Parse one indentation-homogeneous YAML sequence of plain scalar tokens."""
    parent_indent = len(lines[start]) - len(lines[start].lstrip(" "))
    item_indent: int | None = None
    values: list[str] = []
    for index in range(start + 1, stop):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent <= parent_indent:
            raise ValueError("options sequence escaped its YAML block")
        if item_indent is None:
            item_indent = indent
        if indent != item_indent:
            raise ValueError("options must be a flat scalar sequence")
        match = re.fullmatch(r"-\s*['\"]?([A-Za-z0-9_-]+)['\"]?", line.strip())
        if not match:
            raise ValueError("options must contain only plain scalar tokens")
        values.append(match.group(1))
    if not values or len(set(values)) != len(values):
        raise ValueError("options must be a non-empty sequence with no duplicates")
    return set(values)


def _consume_fail_red_guard(
    program: list[str], start: int, condition: str, label: str
) -> int:
    """Consume one top-level ``if`` whose only terminal action is ``exit 1``."""
    if start >= len(program) or program[start] != condition:
        raise ValueError(f"approved-SHA gate is missing the top-level {label} guard")
    try:
        end = program.index("fi", start + 1)
    except ValueError as exc:
        raise ValueError(f"approved-SHA {label} guard has no closing `fi`") from exc
    body = program[start + 1 : end]
    if not body or body[-1] != "exit 1":
        raise ValueError(f"approved-SHA {label} guard must end in `exit 1`")
    for line in body[:-1]:
        if not (line.startswith("echo ") or line.startswith("printf ")):
            raise ValueError(
                f"approved-SHA {label} guard contains a non-reporting command"
            )
    return end + 1


def validate_prod_workflow(source: str) -> dict[str, Any]:
    """Prove the reviewed deploy-prod dispatch and SHA gate are present.

    This intentionally parses only the indentation structure needed for the
    GitHub Actions input contract. It does not interpret arbitrary YAML.
    Anything absent or ambiguous blocks the dispatcher before a prod gate.
    """
    lines = source.splitlines()
    required_inputs = {"mode", "confirm", "activation", "expected_sha"}
    required_options = {
        "mode": {"validate", "deploy"},
        "activation": {"plan", "canary", "apply"},
    }

    try:
        dispatch_start, dispatch_end, dispatch_indent = _yaml_block(
            lines, "workflow_dispatch"
        )
        dispatch_children = _yaml_direct_children(
            lines, dispatch_start, dispatch_end, dispatch_indent
        )
        if "inputs" not in dispatch_children:
            raise ValueError("missing `workflow_dispatch.inputs` block")

        inputs_start, inputs_end = dispatch_children["inputs"]
        inputs_indent = len(lines[inputs_start]) - len(lines[inputs_start].lstrip(" "))
        inputs = _yaml_direct_children(lines, inputs_start, inputs_end, inputs_indent)
        missing = sorted(required_inputs - set(inputs))
        if missing:
            raise ValueError("missing workflow_dispatch inputs: " + ", ".join(missing))

        input_children: dict[str, dict[str, tuple[int, int]]] = {}
        for input_name in required_inputs:
            block_start, block_end = inputs[input_name]
            block_indent = len(lines[block_start]) - len(lines[block_start].lstrip(" "))
            input_children[input_name] = _yaml_direct_children(
                lines, block_start, block_end, block_indent
            )

        expected_types = {
            "mode": "choice",
            "confirm": "string",
            "activation": "choice",
            "expected_sha": "string",
        }
        for input_name, expected_type in expected_types.items():
            actual_type = _yaml_scalar_child(
                lines, input_children[input_name], "type"
            )
            if actual_type != expected_type:
                raise ValueError(f"input `{input_name}` must be a {expected_type}")

        for input_name, expected in required_options.items():
            children = input_children[input_name]
            if "options" not in children:
                raise ValueError(f"input `{input_name}` has no direct options block")
            actual = _yaml_scalar_sequence(lines, *children["options"])
            missing_options = sorted(expected - actual)
            if missing_options:
                raise ValueError(
                    f"input `{input_name}` is missing options: "
                    + ", ".join(missing_options)
                )

        defaults = {
            "mode": "validate",
            "confirm": '""',
            "activation": "plan",
            "expected_sha": '""',
        }
        for input_name, expected_default in defaults.items():
            actual_default = _yaml_scalar_child(
                lines, input_children[input_name], "default"
            )
            if actual_default != expected_default:
                raise ValueError(
                    f"input `{input_name}` must default to {expected_default}"
                )
        if _yaml_scalar_child(
            lines, input_children["expected_sha"], "default"
        ) not in {'""', "''"}:
            raise ValueError("input `expected_sha` must default to an empty string")

        jobs_start, jobs_end, jobs_indent = _yaml_block(lines, "jobs")
        jobs = _yaml_direct_children(lines, jobs_start, jobs_end, jobs_indent)
        if "deploy" not in jobs:
            raise ValueError("missing `jobs.deploy` block")
        deploy_start, deploy_end = jobs["deploy"]
        deploy_block = "\n".join(lines[deploy_start:deploy_end])
        if not re.search(
            r"^\s*if:\s*github\.event_name\s*==\s*['\"]workflow_dispatch['\"]"
            r"\s*&&\s*inputs\.mode\s*==\s*['\"]deploy['\"]\s*$",
            deploy_block,
            re.MULTILINE,
        ):
            raise ValueError("deploy job is not restricted to a deploy dispatch")

        steps_start, steps_end, steps_indent = _yaml_block(
            lines, "steps", deploy_start, deploy_end
        )
        steps = _yaml_named_steps(lines, steps_start, steps_end, steps_indent)
        gate_name = "Bind the dispatch to the approved commit"
        checkout_name = "Checkout (full history for hardis git ops)"
        auth_matches = [name for name in steps if name.startswith("JWT auth → prod")]
        if len(auth_matches) != 1:
            raise ValueError("missing or ambiguous production JWT auth step")
        auth_name = auth_matches[0]
        missing_steps = [
            name for name in (gate_name, checkout_name, auth_name) if name not in steps
        ]
        if missing_steps:
            raise ValueError("missing deploy safety steps: " + ", ".join(missing_steps))

        gate_start, gate_end = steps[gate_name]
        if gate_start >= steps[checkout_name][0] or gate_start >= steps[auth_name][0]:
            raise ValueError("approved-SHA gate must run before checkout and production auth")

        env_start, env_end, env_indent = _yaml_block(
            lines, "env", gate_start, gate_end
        )
        env_children = _yaml_direct_children(lines, env_start, env_end, env_indent)
        if "EXPECTED_SHA" not in env_children:
            raise ValueError("approved-SHA gate has no EXPECTED_SHA environment input")
        expected_env_line = lines[env_children["EXPECTED_SHA"][0]].strip()
        if expected_env_line != "EXPECTED_SHA: ${{ inputs.expected_sha }}":
            raise ValueError("EXPECTED_SHA must come directly from inputs.expected_sha")

        _, _, run_program = _yaml_literal_block(lines, "run", gate_start, gate_end)
        executable_program = textwrap.dedent("\n".join(
            line for line in run_program.splitlines() if not line.lstrip().startswith("#")
        )).strip()
        if "${{" in executable_program:
            raise ValueError("approved-SHA input must reach shell through env, not interpolation")
        program = [line.strip() for line in executable_program.splitlines() if line.strip()]
        if not program or program[0] != "set -euo pipefail":
            raise ValueError("approved-SHA gate must begin with `set -euo pipefail`")
        cursor = _consume_fail_red_guard(
            program,
            1,
            'if [[ ! "$EXPECTED_SHA" =~ ^[0-9a-f]{40}$ ]]; then',
            "shape",
        )
        cursor = _consume_fail_red_guard(
            program,
            cursor,
            'if [ "$EXPECTED_SHA" != "$GITHUB_SHA" ]; then',
            "equality",
        )
        for line in program[cursor:]:
            if not (line.startswith("echo ") or line.startswith("printf ")):
                raise ValueError("approved-SHA gate has an unexpected trailing command")

        pre_gate = "\n".join(lines[deploy_start:gate_start])
        if re.search(r"^\s*uses:\s*", pre_gate, re.MULTILINE) or re.search(
            r"(^|[;&|]\s*)(sf|sfdx)\s+", pre_gate
        ):
            raise ValueError("approved-SHA gate must run before any action or Salesforce command")
    except ValueError as exc:
        return {
            "decision": "blocked_error",
            "blocking": True,
            "reason": str(exc),
        }

    return {
        "decision": "ready",
        "blocking": False,
        "inputs": sorted(required_inputs),
        "reason": "main deploy workflow exposes and enforces the reviewed production dispatch contract",
    }


# ── CLI ─────────────────────────────────────────────────────────────────────


def _read_stdin_json(arg: str) -> dict[str, Any]:
    raw = sys.stdin.read() if arg == "-" else Path(arg).read_text(encoding="utf-8")
    return json.loads(raw)


def _read_text(arg: str) -> str:
    return sys.stdin.read() if arg == "-" else Path(arg).read_text(encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="promotion_topology.py",
        description="ADR-026 promotion-topology decision core (BC-19521).",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list-protected", action="store_true", help="print the protected alias list")
    mode.add_argument("--classify", metavar="ALIAS", help="classify one org alias")
    mode.add_argument("--resolve-dev-org", metavar="FILE|-", help="`sf org list --json` payload")
    mode.add_argument("--concurrency-verdict", metavar="FILE|-", help="probe payload")
    mode.add_argument("--pipeline-guidance", metavar="REPO_ROOT", help="repo to read config from")
    mode.add_argument(
        "--validate-prod-workflow",
        metavar="FILE|-",
        help="GitHub Actions workflow YAML to validate",
    )
    parser.add_argument("--requested", help="alias the user explicitly asked for")
    parser.add_argument("--lane", help="lane name for --pipeline-guidance")
    parser.add_argument("--registry", help="override the org-aliases.json path (testing)")
    args = parser.parse_args(argv[1:])

    if args.pipeline_guidance:
        print(json.dumps(pipeline_guidance(args.pipeline_guidance, args.lane), indent=2))
        return 0

    if args.validate_prod_workflow:
        try:
            source = _read_text(args.validate_prod_workflow)
        except OSError as exc:
            print(json.dumps({
                "decision": "blocked_error",
                "blocking": True,
                "reason": f"could not read workflow YAML: {exc}",
            }, indent=2))
            return 2
        print(json.dumps(validate_prod_workflow(source), indent=2))
        return 0

    try:
        reg = load_registry(Path(args.registry) if args.registry else None)
    except (OSError, ValueError) as exc:
        print(json.dumps({"decision": "blocked_error", "blocking": True, "reason": str(exc)}))
        return 2

    if args.list_protected:
        print(json.dumps({"protected_aliases": protected_aliases(reg),
                          "dev_org_alias_pattern": reg.get("dev_org", {}).get("alias_pattern")},
                         indent=2))
        return 0

    if args.classify:
        print(json.dumps(classify(args.classify, reg), indent=2))
        return 0

    source = args.resolve_dev_org or args.concurrency_verdict
    try:
        payload = _read_stdin_json(source)
    except (OSError, ValueError) as exc:
        # Fail closed: an unreadable payload is a blocking verdict, not a usage
        # error the caller can shrug off.
        print(json.dumps({
            "decision": "unusable" if args.resolve_dev_org else "blocked_error",
            "blocking": True,
            "reason": f"could not read the input payload: {exc}",
        }, indent=2))
        return 2

    if args.resolve_dev_org:
        print(json.dumps(resolve_dev_org(payload, reg, args.requested), indent=2))
    else:
        print(json.dumps(concurrency_verdict(payload), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
