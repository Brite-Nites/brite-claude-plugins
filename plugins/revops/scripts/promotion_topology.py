#!/usr/bin/env python3
"""Deterministic decision core for the ADR-026 promotion topology (BC-19521).

The revops commands are orchestrators, not engines. Four decisions inside them
are pure functions of their inputs, so they live here instead of as prose the
model is asked to follow:

  --classify <alias>        Is this org alias safe to deploy to from a laptop?
  --resolve-dev-org -       Which brite-dev-<name> org is THIS developer's?
  --concurrency-verdict -   Is a deploy to this org safe to start right now?
  --pipeline-guidance <dir> What does the repo-local pipeline config say?

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


# ── CLI ─────────────────────────────────────────────────────────────────────


def _read_stdin_json(arg: str) -> dict[str, Any]:
    raw = sys.stdin.read() if arg == "-" else Path(arg).read_text(encoding="utf-8")
    return json.loads(raw)


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
    parser.add_argument("--requested", help="alias the user explicitly asked for")
    parser.add_argument("--lane", help="lane name for --pipeline-guidance")
    parser.add_argument("--registry", help="override the org-aliases.json path (testing)")
    args = parser.parse_args(argv[1:])

    if args.pipeline_guidance:
        print(json.dumps(pipeline_guidance(args.pipeline_guidance, args.lane), indent=2))
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
