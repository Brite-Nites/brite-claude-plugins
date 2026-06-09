#!/usr/bin/env python3
"""Deterministic issue-payload + regression-test-entry builder for
/workflows:report-issue (BC-12944, ADR-028 Phase-2 Batch C).

The agent-tooling branch of the intake front door (ADR-022) produces TWO
deterministic artifacts in one intake act, and this is the PURE core the command
delegates to for both. Given the classification + severity + the trigger details
(all decided/gathered upstream) and the INJECTED reads (`list_issue_labels` for
Brite Company + the existing behavioral-registry ids), it computes — with NO MCP
call and NO Linear/registry write — a composite:

    { "issue_payload": { title, team, project, priority, applied_labels[],
                         missing_labels[], severity_carried_by_priority, notes[] },
      "registry":      { target, entry|null } }

Keyed by the INJECTED classification (Step 2 — sequential-thinking proposes, the
developer confirms; so the classification is an INPUT here, not a decision):
    wrong-skill / skill-not-fired / skill-over-fired → trigger-registry.json
    bad-output                                       → behavioral-registry.json
    hook-issue / subagent-issue / command-flow       → Linear-only (entry = null)

What the builder OWNS (the deterministic surface): the title format
(`f"{classification}: {short_desc}"`), the severity→priority map, the
existence-aware Brite-Company label reconcile, the classification→registry routing,
the **B## next-id allocation** (max(injected ids)+1 — the meatiest S2 nugget), the
`phrase` shell-metachar strip, and the per-classification expected/not_expected
population rule. What's OUT (over-claim guard, ADR-028 D2): the classification
DECISION, the "concise phrase"/expected_markers EXTRACTION (the dev supplies these
— injected inputs; only the sanitize is pure), the Step-1d product-switch, the dup
search, and `judge_rubric` THRESHOLD VALUES (under-specified by the command — the
eval asserts the rubric's SHAPE, keys + 1–5 range, not the judgment value). The
mutating `save_issue` + registry append stay UN-driven.

severity→(priority, severity:sevN) + reconcile_labels are shared with
raise-a-ticket via intake_common.py (Rule-of-Three: 2 consumers each). The
classification routing + registry-entry construction are report-issue-only.

emit artifact (`--scenarios <fixture> --out-dir <dir>`):
    report-issue-emit.json = { schema_version, command, scenarios: [ {id, **decision} ] }

Stdlib-only per CLAUDE.md § Conventions; same command+helper pattern as
build_raise_ticket_payload.py / build_status_update_payload.py.

Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture.
"""
from __future__ import annotations

import argparse
import json
import re
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
COMMAND = "/workflows:report-issue"

# report-issue hardcodes its destination (Step 6a): the agent-tooling defect tracker.
TEAM = "Brite Company"
PROJECT = "Brite Skill Packs"

# Always-on labels (Step 6a): a tooling misbehavior is a defect (type:bug) + the
# load-bearing triage signal + the default executor axis. severity:sevN is appended
# when provisioned (it is NOT in Brite Company today → priority carries it).
TYPE_LABEL = "type:bug"
TRIAGE_LABEL = "needs-triage"
EXECUTOR_LABEL = "executor:hybrid"
TRIAGE_STATE = "Triage"

# Classification → test registry (Step 2 table).
TRIGGER_CLASSES = ("wrong-skill", "skill-not-fired", "skill-over-fired")
BEHAVIORAL_CLASSES = ("bad-output",)
LINEAR_ONLY_CLASSES = ("hook-issue", "subagent-issue", "command-flow")
ALL_CLASSES = TRIGGER_CLASSES + BEHAVIORAL_CLASSES + LINEAR_ONLY_CLASSES

TRIGGER_REGISTRY = "trigger-registry.json"
BEHAVIORAL_REGISTRY = "behavioral-registry.json"

# The default judge_rubric the builder stamps (Step 3 example B10 = 4/4/4). The
# command tunes thresholds by severity at runtime ("4/5 standard, 3/5 minimum") —
# an under-specified judgment, so the eval asserts the rubric SHAPE (keys + 1–5
# range via the schema), NOT these values (the golden projection drops them).
DEFAULT_RUBRIC = {"clarity": 4, "completeness": 4, "actionability": 4}
DEFAULT_ESTIMATED_COST = "$0.30"

E_INVALID_CLASSIFICATION = "invalid_classification"
E_MISSING_SEVERITY = "missing_severity"
E_INVALID_SEVERITY = "invalid_severity"

# Shell-metachar strip for the trigger `phrase` (Step 3): $ ` \ " ' → removed. The
# strip is the pure, golden-able piece; the "make it concise / extract the NL"
# upstream of it is LLM and is injected already-condensed.
_METACHAR_RE = re.compile(r"""[$`\\"']""")


def sanitize_phrase(phrase: str | None) -> str:
    """Strip shell metacharacters ($ ` \\ " ') from a trigger phrase (Step 3)."""
    return _METACHAR_RE.sub("", phrase or "")


def next_behavioral_id(existing_ids) -> str:
    """The next behavioral-registry id: `B` + (max(int(id[1:])) + 1) over the
    injected ids (B10 → B11). An empty/garbage set starts at B01. Non-`B##` / non-str
    ids are ignored.

    The allocation guarantee — what this builder OWNS — is **unique + numerically
    monotonic**: the next id is always greater (numerically) than every existing id,
    so it can never collide. The `:02d` is a MINIMUM width matching the existing
    B01..B99 zero-pad convention; it deliberately does NOT cap (truncating a 3-digit
    value would re-introduce collisions — B100 → "B00" would clash with B00). So past
    99 entries ids widen intentionally: B99 → B100 → B101, still unique + monotonic.
    Downstream consumers must therefore compare ids NUMERICALLY (`int(id[1:])`), never
    lexically — a string sort would order "B100" before "B99". This widening is
    expected, not a silent migration; it's a far-future edge for a registry that holds
    ~10 entries today, and is regression-locked in test_build_report_issue_payload.sh.
    """
    nums = []
    for rid in existing_ids or []:
        if isinstance(rid, str) and rid[:1] == "B" and rid[1:].isdigit():
            nums.append(int(rid[1:]))
    nxt = (max(nums) + 1) if nums else 1
    return f"B{nxt:02d}"  # min-width 2 (B01..B99); widens past 99 — see docstring


def _expected_not_expected(classification: str, expected, fired) -> tuple[list, list]:
    """The per-classification expected/not_expected population rule (Step 3).

      - wrong-skill      : expected = the correct skill(s); not_expected = the wrong
                           skill that fired.
      - skill-not-fired  : expected = the skill that should have fired; not_expected
                           = [] (unless a different skill incorrectly fired → fired).
      - skill-over-fired : a skill fired when NONE should have → expected = [];
                           not_expected = the skill that wrongly fired.
    """
    exp = list(expected or [])
    fired_list = [fired] if fired else []
    if classification == "wrong-skill":
        return exp, fired_list
    if classification == "skill-not-fired":
        return exp, fired_list  # [] unless a different skill also fired
    # skill-over-fired
    return [], fired_list


def _issue_payload(classification: str, short_desc: str, severity: str, existing_labels) -> dict:
    """The Linear issue payload projection (Step 6a). team/project are hardcoded;
    priority from severity; labels reconciled existence-aware against Brite Company."""
    sev_label = severity_to_sev_label(severity)
    intended = [TYPE_LABEL, TRIAGE_LABEL, EXECUTOR_LABEL]
    if sev_label:
        intended.append(sev_label)
    applied, missing = reconcile_labels(intended, existing_labels)

    notes: list[str] = []
    triage_state_fallback = None
    if TRIAGE_LABEL in missing:
        triage_state_fallback = TRIAGE_STATE
        notes.append("needs-triage label not provisioned in Brite Company; set built-in Triage state")
    severity_carried_by_priority = False
    if sev_label and sev_label in missing:
        severity_carried_by_priority = True
        notes.append("severity:* not provisioned in Brite Company; captured via priority")

    return {
        "title": f"{classification}: {short_desc}",
        "team": TEAM,
        "project": PROJECT,
        "priority": severity_to_priority(severity),
        "applied_labels": applied,
        "missing_labels": missing,
        "triage_state_fallback": triage_state_fallback,
        "severity_carried_by_priority": severity_carried_by_priority,
        "notes": notes,
    }


def _registry(classification: str, inputs: dict, state: dict) -> dict:
    """The second artifact: {target, entry|null} for the appropriate registry."""
    if classification in TRIGGER_CLASSES:
        expected, not_expected = _expected_not_expected(
            classification, inputs.get("expected"), inputs.get("fired")
        )
        entry = {
            "phrase": sanitize_phrase(inputs.get("phrase")),
            "expected": expected,
            "not_expected": not_expected,
            "description": "Regression: " + (inputs.get("reg_description") or ""),
        }
        return {"target": TRIGGER_REGISTRY, "entry": entry}

    if classification in BEHAVIORAL_CLASSES:
        entry = {
            "id": next_behavioral_id(state.get("behavioral_ids")),
            "description": inputs.get("reg_description") or "",
            "tier": 2,
            "prompt": inputs.get("prompt") or "",
            "expected_skill": inputs.get("expected_skill"),
            "expected_markers": list(inputs.get("expected_markers") or []),
            "not_expected_markers": [],
            "not_expected_skills": [],
            "judge_rubric": dict(DEFAULT_RUBRIC),
            "estimated_cost": DEFAULT_ESTIMATED_COST,
            "notes": "Regression from /workflows:report-issue — " + (inputs.get("context") or ""),
        }
        return {"target": BEHAVIORAL_REGISTRY, "entry": entry}

    # Linear-only classifications: no appendable registry.
    return {"target": None, "entry": None}


def decide(inputs: dict, state: dict | None = None) -> dict:
    """PURE decision: (inputs, injected state) -> a composite row.

    `state` injects the live reads: {existing_labels: list_issue_labels(Brite Company),
    behavioral_ids: the existing B## ids}. The classification is an INPUT (decided
    upstream); decide() owns the title/priority/reconcile/routing/B##/sanitize/
    population, NOT the classification decision (see module docstring).
    """
    state = state or {}

    classification = inputs.get("classification")
    if classification not in ALL_CLASSES:
        return {"error": E_INVALID_CLASSIFICATION, "classification": classification,
                "issue_payload": None, "registry": None}

    severity = inputs.get("severity")
    if not severity:
        return {"error": E_MISSING_SEVERITY, "classification": classification,
                "issue_payload": None, "registry": None}
    if severity not in SEVERITY_TO_PRIORITY:
        return {"error": E_INVALID_SEVERITY, "classification": classification,
                "issue_payload": None, "registry": None}

    return {
        "error": None,
        "classification": classification,
        "issue_payload": _issue_payload(
            classification, inputs.get("short_desc") or "", severity, state.get("existing_labels")
        ),
        "registry": _registry(classification, inputs, state),
    }


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any reject row."""


_INPUT_KEYS = (
    "classification", "severity", "short_desc", "phrase", "prompt", "expected",
    "fired", "expected_skill", "expected_markers", "reg_description", "context",
)


def _scenario_inputs(scenario: dict) -> dict:
    return {k: scenario[k] for k in _INPUT_KEYS if k in scenario}


def run_scenarios(scenarios: list) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        decision = decide(_scenario_inputs(sc), sc.get("state"))
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
        prog="build_report_issue_payload.py",
        description="Deterministic /workflows:report-issue payload + registry-entry builder (BC-12944).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write report-issue-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one composite row to stdout")
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
            row = {"id": sc.get("id", "runtime"), **decide(_scenario_inputs(sc), sc.get("state"))}
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
            (out_dir / "report-issue-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
