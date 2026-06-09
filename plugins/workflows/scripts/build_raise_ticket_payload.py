#!/usr/bin/env python3
"""Deterministic ticket-payload projection builder for /workflows:raise-a-ticket
(BC-12944, ADR-028 Phase-2 Batch C — the workflows plugin's FIRST build_* script).

The PURE, hermetic decision core the command delegates to for the parts of intake
that are NOT conversational: given the reporter-facing kind + severity + resolved
project/team candidates, and the INJECTED Linear reads (`list_issue_labels` for the
target team + `list_issues` for the multi-team tally), it computes — with NO MCP
call and NO Linear write — the deterministic label/priority/team **projection** of
the ticket that WOULD be filed:

    - type label        Bug → type:bug | Idea/Feedback → type:task (Step 2)
    - severity → (severity:sevN label, native priority)            (Step 4)
    - the modal-team tiebreak for a multi-team project             (Step 1g)
    - the existence-aware label reconcile + per-label fallbacks    (Step 8)
    - the provenance footer                                        (Step 8)

What's OUT of scope (over-claim guard, ADR-028 D2): the Step-1a product-vs-tooling
fork, the title, the body structuring, the FDA domain inference, and the duplicate
search — all LLM-narrated / conversational, OR (the dup search) a branch that does
NOT affect the filed payload. The mutating `save_issue` stays UN-driven (this emits
no write; the issue id is never produced). So the builder owns the label/routing
projection a downstream triage consumer actually depends on — the slice that breaks
SILENTLY when a team's label canon drifts — and frames the eval claim there.

The seam (the inject-the-reads idiom from build_campaign_payload / BC-12701): the
team resolution + the reconcile both depend on LIVE Linear reads. To keep THIS
builder pure — hence the eval hermetic — those reads are passed in as `linear_state`:

    linear_state = {
      "existing_labels": ["type:bug", "needs-triage", "executor:hybrid", ...],  # list_issue_labels(team)
      "project_issues":  [{"team": "Brite Company"}, ...],                       # list_issues(project) for 1g
    }

At RUNTIME the command performs the reads and passes them here; at EVAL time the
fixture injects the same shapes. decide() does its OWN modal tally + set-membership
reconcile so that logic is itself under test, not stubbed past.

Severity → (priority, severity:sevN) + the reconcile are shared with report-issue
via intake_common.py (Rule-of-Three: 2 consumers each). The modal-team tiebreak is
raise-a-ticket-only (1 consumer) so it lives here.

emit artifact (`--scenarios <fixture> --out-dir <dir>`):
    raise-ticket-emit.json = {
      "schema_version": 1,
      "command": "/workflows:raise-a-ticket",
      "scenarios": [ {id, error|null, kind, type_label, severity_label, priority,
                      team, team_tiebreak, applied_labels[], missing_labels[],
                      triage_state_fallback, severity_carried_by_priority,
                      notes[], footer}, ... ]
    }
The behavioral eval (BC-12589 harness) golden-compares a structural projection of
this matrix; a flipped reconcile (e.g. dropping the needs-triage→Triage fallback,
or a modal-team mis-default) shows up as a golden diff.

Stdlib-only per CLAUDE.md § Conventions; same command+helper pattern as
build_status_update_payload.py.

Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture
(an infra error, distinct from any per-scenario `error` verdict).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from intake_common import (  # noqa: E402  (BC-12944 shared primitives, reused not forked)
    SEVERITY_TO_PRIORITY,
    reconcile_labels,
    severity_to_priority,
    severity_to_sev_label,
)

SCHEMA_VERSION = 1
COMMAND = "/workflows:raise-a-ticket"

# The two reporter-facing kinds (Step 2) → CDR-016 type axis. There is no
# type:feature/type:feedback at Brite; an Idea/Feedback is the type:task default.
KIND_TO_TYPE = {"bug": "type:bug", "idea": "type:task"}

# Canonical always-on labels (Step 8): the type axis + the load-bearing triage
# signal + the default executor axis. severity:sevN (bugs) + domain:<slug> (FDA,
# confirmed) are appended conditionally below.
TRIAGE_LABEL = "needs-triage"
EXECUTOR_LABEL = "executor:hybrid"
TRIAGE_STATE = "Triage"  # the built-in workflow state used when needs-triage is unprovisioned
BRITE_COMPANY = "Brite Company"

E_INVALID_KIND = "invalid_kind"
E_MISSING_SEVERITY = "missing_severity"
E_INVALID_SEVERITY = "invalid_severity"


def resolve_team(project_teams, project_issues) -> tuple[str, str]:
    """The Step-1g multi-team tiebreak. PURE given the injected reads.

    `project_teams` = the team names the resolved project belongs to (a project
    can span >1 team — e.g. Brite Base spans [Brite Supply, Brite Company]).
    `project_issues` = the `list_issues({project})` rows for the modal tally.

      - exactly one team           → (that team, "single")
      - >1 team, a clear modal      → (modal team where its issues predominantly live, "modal")
      - >1 team, a tie on count     → (Brite Company, "tie-brite-company")
      - >1 team, empty/no-team tally → (Brite Company, "fallback-brite-company")

    The fallback also guards the case the `list_issues` response ever drops the
    per-issue `team` field (it carries it today) so an empty tally never silently
    mis-defaults — exactly the Step-1g prose.
    """
    teams = list(project_teams or [])
    if len(teams) == 1:
        return teams[0], "single"
    if not teams:
        return BRITE_COMPANY, "fallback-brite-company"

    counts: dict[str, int] = {}
    for issue in project_issues or []:
        team = issue.get("team") if isinstance(issue, dict) else None
        if team:
            counts[team] = counts.get(team, 0) + 1
    if not counts:
        return BRITE_COMPANY, "fallback-brite-company"

    top = max(counts.values())
    modal = sorted(t for t, c in counts.items() if c == top)
    if len(modal) == 1:
        return modal[0], "modal"
    return BRITE_COMPANY, "tie-brite-company"


def _error(error: str, *, kind=None) -> dict:
    """An infra/validation reject row. No payload projection is produced."""
    return {
        "error": error,
        "kind": kind,
        "type_label": None,
        "severity_label": None,
        "priority": None,
        "team": None,
        "team_tiebreak": None,
        "applied_labels": [],
        "missing_labels": [],
        "triage_state_fallback": None,
        "severity_carried_by_priority": False,
        "notes": [],
        "footer": None,
    }


def decide(inputs: dict, linear_state: dict | None = None) -> dict:
    """PURE decision: (inputs, injected linear_state) -> a projection row.

    The single entrypoint shared by the command (runtime, with live reads) and the
    behavioral eval (with fixture-injected reads). Models Steps 2 / 4 / 1g / 8; the
    conversational steps (1a fork, title, body, domain inference, dup search) are
    NOT modelled — they are out of the deterministic scope (see module docstring).
    """
    linear_state = linear_state or {}

    kind = inputs.get("kind")
    if kind not in KIND_TO_TYPE:
        return _error(E_INVALID_KIND, kind=kind)
    type_label = KIND_TO_TYPE[kind]

    # Severity is bugs-only (Step 4 is skipped entirely for an Idea/Feedback).
    severity = inputs.get("severity")
    if kind == "bug":
        if not severity:
            return _error(E_MISSING_SEVERITY, kind=kind)
        if severity not in SEVERITY_TO_PRIORITY:
            return _error(E_INVALID_SEVERITY, kind=kind)
        severity_label = severity_to_sev_label(severity)
        priority = severity_to_priority(severity)
    else:
        # An Idea/Feedback never carries severity or priority (Step 4 skipped).
        severity_label = None
        priority = None

    team, team_tiebreak = resolve_team(inputs.get("project_teams"), linear_state.get("project_issues"))

    # Intended labels in the Step-8 order: type, needs-triage, executor:hybrid,
    # [severity:sevN], [domain:<slug>]. domain is appended only when the command
    # already confirmed the specific label exists (Step 5b) — passed in as a slug
    # or None; reconcile still verifies it against the team.
    intended = [type_label, TRIAGE_LABEL, EXECUTOR_LABEL]
    if severity_label:
        intended.append(severity_label)
    domain = inputs.get("domain")
    if domain:
        intended.append(domain)

    applied, missing = reconcile_labels(intended, linear_state.get("existing_labels"))

    notes: list[str] = []
    # needs-triage is load-bearing — it must NOT be dropped. When the label isn't
    # provisioned, set the built-in Triage workflow state instead (Step 8).
    triage_state_fallback = None
    if TRIAGE_LABEL in missing:
        triage_state_fallback = TRIAGE_STATE
        notes.append("needs-triage label not provisioned in team; set built-in Triage state")
    # severity:sevN absent → the native priority carries the severity signal.
    severity_carried_by_priority = False
    if severity_label and severity_label in missing:
        severity_carried_by_priority = True
        notes.append("severity:* not provisioned in this team; captured via priority")
    if EXECUTOR_LABEL in missing:
        notes.append("executor:hybrid not provisioned in this team")
    if type_label in missing:
        notes.append(f"{type_label} not provisioned in this team")

    reporter = inputs.get("reporter") or "the reporter"
    footer = (
        "---\n> Filed via `/workflows:raise-a-ticket` from "
        f"{reporter}'s report; structured by AI."
    )

    return {
        "error": None,
        "kind": kind,
        "type_label": type_label,
        "severity_label": severity_label,
        "priority": priority,
        "team": team,
        "team_tiebreak": team_tiebreak,
        "applied_labels": applied,
        "missing_labels": missing,
        "triage_state_fallback": triage_state_fallback,
        "severity_carried_by_priority": severity_carried_by_priority,
        "notes": notes,
        "footer": footer,
    }


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any reject row."""


# Keys that describe a scenario's INPUTS (everything else on the row is metadata
# like `id`/`note` or the injected `linear_state`).
_INPUT_KEYS = ("kind", "severity", "project_teams", "domain", "reporter")


def _scenario_inputs(scenario: dict) -> dict:
    return {k: scenario[k] for k in _INPUT_KEYS if k in scenario}


def run_scenarios(scenarios: list) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        decision = decide(_scenario_inputs(sc), sc.get("linear_state"))
        rows.append({"id": sc.get("id", f"scenario-{i}"), **decision})
    return {"schema_version": SCHEMA_VERSION, "command": COMMAND, "scenarios": rows}


def _load_scenarios(path: Path) -> list:
    if not path.exists():
        raise BuildError(f"fixture not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise BuildError(f"fixture is not valid JSON: {exc}") from exc
    scenarios = data.get("scenarios") if isinstance(data, dict) else data
    if not isinstance(scenarios, list):
        raise BuildError("fixture must be a list of scenarios or {'scenarios': [...]}")
    return scenarios


# ── CLI ───────────────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="build_raise_ticket_payload.py",
        description="Deterministic /workflows:raise-a-ticket payload projection builder (BC-12944).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write raise-ticket-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one projection row to stdout")
    args = ap.parse_args(argv)

    try:
        if args.decide is not None:
            try:
                raw = sys.stdin.read() if args.decide == "-" else Path(args.decide).read_text(encoding="utf-8")
            except OSError as exc:
                raise BuildError(f"--decide input file unreadable: {exc}") from exc
            try:
                sc = json.loads(raw)
            except json.JSONDecodeError as exc:
                raise BuildError(f"--decide input is not valid JSON: {exc}") from exc
            if not isinstance(sc, dict):
                raise BuildError("--decide input must be a single scenario object")
            row = {"id": sc.get("id", "runtime"), **decide(_scenario_inputs(sc), sc.get("linear_state"))}
            print(json.dumps(row, ensure_ascii=False))
            return 0

        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios)
            (out_dir / "raise-ticket-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
