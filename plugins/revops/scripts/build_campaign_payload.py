#!/usr/bin/env python3
"""Deterministic SF-Campaign payload + dedup-verdict builder for
/revops:create-sf-campaign (BC-12701, ADR-028 emit-mode seam).

This is the PURE, hermetic decision core the command delegates to in BOTH its
normal and emit runs (ADR-028 D2 / D8 — single source of truth; refinement #3 of
the BC-12701 grill: runtime and eval MUST share one entrypoint so the eval can't
certify a parallel path). Given the campaign-defining inputs AND the *injected*
results of the command's two live SOQL reads, it computes — with NO MCP/network
call and NO Salesforce write — the would-create / would-skip / error **verdict**
plus the SF Campaign **payload** that *would* be sent.

The seam (the hard part of this command): the command's idempotency/dedup decision
depends on a LIVE SOQL existence check (Phase 2: `SELECT Id FROM Campaign WHERE
Name='<slug>'`) and its owner resolution on a second live read (Phase 3: `SELECT Id
FROM User WHERE Email='<owner-email>' AND IsActive=TRUE`). To make THIS builder pure
— hence the eval hermetic — those two reads are passed in as `sf_state`:

    sf_state = {
      "existing_campaigns": [ {"Id": "701...", "Name": "<slug>"}, ... ],  # Phase-2 rows
      "owner": {"email": "<owner-email>", "id": "005..."} | null,        # Phase-3 row
    }

At RUNTIME the command performs the two SOQL reads and passes the rows in here; at
EVAL time the fixture injects the same shapes (exactly the plan-campaign idiom of
injecting `created_at` to defeat `now()`). `decide()` does its OWN `Name == slug`
match over `existing_campaigns` (case-sensitive, exact) so that matching logic is
itself under test, not stubbed past.

Input-shape guards REUSE the BC-12639 validators byte-identically (no fork): the
`--target-org` shell-injection guard delegates to
`validate_target_org.is_valid_target_org`; the slug + owner-email guards apply the
canonical regexes documented in the command's Phase 1 flag table (and mirrored in
`build_manifest.py`). Keeping them byte-identical is the producer↔consumer parity
discipline from BC-12594 — `test_build_campaign_payload.sh` locks it.

emit artifact (`--scenarios <fixture> --out-dir <dir>`):
    campaign-emit.json = {
      "schema_version": 1,
      "command": "/revops:create-sf-campaign",
      "scenarios": [ {id, verdict, target_org, payload|null, campaign_id, output|null}, ... ]
    }
`campaign_id` is ALWAYS null — emit makes no SF write (refinement #4: assert the
nullness explicitly, mirroring plan-campaign asserting `milestone_id: None`). The
behavioral eval (BC-12589 harness) golden-compares a structural projection of this
matrix; a flipped verdict (e.g. an idempotency regression that stops skipping a
duplicate) shows up as a golden diff.

Stdlib-only per CLAUDE.md § Conventions; same command+helper pattern as
build_manifest.py / validate_target_org.py.

Exit codes: 0 = built/decided OK; 2 = usage / unreadable-or-malformed fixture
(an infra error, distinct from any verdict — every verdict is a successful run).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_target_org import is_valid_target_org  # noqa: E402  (BC-12639, reused not forked)

SCHEMA_VERSION = 1
COMMAND = "/revops:create-sf-campaign"

# Canonical input-shape regexes — BYTE-IDENTICAL to /revops:create-sf-campaign
# Phase 1 + build_manifest.py (SLUG_RE/EMAIL_RE). Parity is locked by
# test_build_campaign_payload.sh; do NOT "improve" these in isolation (a producer
# that drifts from the consumer is the BC-12594 failure mode). fullmatch (not
# search) so a trailing newline can't sneak past the `$`, matching
# validate_target_org.py's discipline.
SLUG_RE = re.compile(r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$")
EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")

# Required campaign-defining flags (the command's flag table; --target-org is
# optional with a brite-prod default, --dry-run is a mode). A scenario missing any
# of these resolves to the missing_required_flag verdict — checked in flag-table
# order so the reported flag is deterministic (the first absent flag wins).
# `year`/`month` are PRESENCE-ONLY: the command lists them required but neither
# value-validates them (there is no invalid_year/invalid_month error kind) nor puts
# them in the SF payload — the slug already encodes fy/m and StartDate comes from
# launch_date. The builder mirrors that faithfully (presence gate, no value check)
# so it cannot diverge from the command (adding a range check here would invent an
# error kind the command doesn't emit, breaking the audit-roster lint).
REQUIRED_FLAGS = (
    "slug", "entity", "vertical", "persona", "offer",
    "year", "month", "owner_email", "launch_date",
)
DEFAULT_TARGET_ORG = "brite-prod"

# Verdicts (the behavioral signal). would_skip_duplicate is the idempotent no-op
# (a SUCCESS for the caller — the existing Id is returned), distinct from `error`.
V_CREATE = "would_create"
V_SKIP = "would_skip_duplicate"
V_ERROR = "error"


def _missing_flag(inputs: dict) -> str | None:
    """First required flag that is absent or blank (flag-table order)."""
    for flag in REQUIRED_FLAGS:
        v = inputs.get(flag)
        if v is None or (isinstance(v, str) and v.strip() == ""):
            return flag
    return None


def _result(verdict: str, *, target_org: str, payload=None, output=None) -> dict:
    """One scenario's decision row. campaign_id is ALWAYS null — emit never writes."""
    return {
        "verdict": verdict,
        "target_org": target_org,
        "payload": payload,
        "campaign_id": None,
        "output": output,
    }


def decide(inputs: dict, sf_state: dict | None = None) -> dict:
    """PURE decision: (inputs, injected sf_state) -> a decision row.

    The single entrypoint shared by the command (runtime, with live SOQL rows) and
    the behavioral eval (with fixture-injected rows). Precedence mirrors the
    command's phase order exactly: missing flags → Phase-0 target-org guard →
    Phase-1 slug/owner-email guards → Phase-2 duplicate → Phase-3 missing-owner →
    would_create. Every branch's `output` is the EXACT soft-fail JSON envelope the
    command emits on stdout for that case (so the command's error catalog and this
    builder can't drift)."""
    sf_state = sf_state or {}
    target_org = inputs.get("target_org") or DEFAULT_TARGET_ORG

    # missing_required_flag (the command checks presence before anything else).
    missing = _missing_flag(inputs)
    if missing is not None:
        return _result(
            V_ERROR, target_org=target_org,
            output={"error": "missing_required_flag", "flag": missing},
        )

    # Phase 0 — target-org shell-injection guard (reused validator, byte-identical).
    # The command only validates an EXPLICITLY-supplied value; an unset default
    # (brite-prod) is trusted and passes anyway, so validating it here is harmless.
    if not is_valid_target_org(target_org):
        return _result(
            V_ERROR, target_org=target_org,
            output={"error": "invalid_target_org", "value": target_org},
        )

    # Phase 1 — slug shape (also the SOQL-literal guard for Phase 2).
    slug = inputs["slug"]
    if SLUG_RE.fullmatch(slug) is None:
        return _result(
            V_ERROR, target_org=target_org,
            output={"error": "invalid_slug_format", "slug": slug},
        )

    # Phase 1 — owner-email shape (also the SOQL-literal guard for Phase 3).
    owner_email = inputs["owner_email"]
    if EMAIL_RE.fullmatch(owner_email) is None:
        return _result(
            V_ERROR, target_org=target_org,
            output={"error": "invalid_owner_email", "value": owner_email},
        )

    # Phase 2 — idempotency precheck. The builder does its OWN exact Name==slug
    # match over the injected rows (refinement #2: the match logic is under test),
    # so a near-miss row (different case / different slug) is NOT a duplicate.
    existing = sf_state.get("existing_campaigns") or []
    dup = next((r for r in existing if r.get("Name") == slug), None)
    if dup is not None:
        return _result(
            V_SKIP, target_org=target_org,
            output={"error": "duplicate_slug", "existing_id": dup.get("Id")},
        )

    # Phase 3 — owner lookup. owner is the injected Phase-3 row, or null = 0 rows.
    owner = sf_state.get("owner")
    if not owner or not owner.get("id"):
        return _result(
            V_ERROR, target_org=target_org,
            output={"error": "missing_owner", "email": owner_email},
        )

    # would_create — assemble the deterministic SF Campaign field-map (the exact
    # values Phase 5's `sf data create record` would send). output stays null: the
    # success envelope {campaign_id, campaign_url, campaign_name} needs the
    # post-write Id, which does not exist on the hermetic emit path.
    payload = {
        "Name": slug,
        "Vertical__c": inputs["vertical"],
        "Persona__c": inputs["persona"],
        "Offer__c": inputs["offer"],
        "Entity__c": inputs["entity"],
        "StartDate": inputs["launch_date"],
        "OwnerId": owner["id"],
        "Status": "Planned",
    }
    return _result(V_CREATE, target_org=target_org, payload=payload)


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any verdict."""


# Keys that describe a scenario's INPUTS (everything else on the row is metadata
# like `id`/`note` or the injected `sf_state`).
_INPUT_KEYS = (
    "slug", "entity", "vertical", "persona", "offer",
    "year", "month", "owner_email", "launch_date", "target_org",
)


def _scenario_inputs(scenario: dict) -> dict:
    return {k: scenario[k] for k in _INPUT_KEYS if k in scenario}


def run_scenarios(scenarios: list) -> dict:
    """Map each scenario → a decision row, assembling the emit-artifact matrix."""
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        decision = decide(_scenario_inputs(sc), sc.get("sf_state"))
        rows.append({"id": sc.get("id", f"scenario-{i}"), **decision})
    return {
        "schema_version": SCHEMA_VERSION,
        "command": COMMAND,
        "scenarios": rows,
    }


def _load_scenarios(path: Path) -> list:
    if not path.exists():
        raise BuildError(f"fixture not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise BuildError(f"fixture is not valid JSON: {exc}") from exc
    # Accept either {"scenarios": [...]} or a bare list.
    scenarios = data.get("scenarios") if isinstance(data, dict) else data
    if not isinstance(scenarios, list):
        raise BuildError("fixture must be a list of scenarios or {'scenarios': [...]}")
    return scenarios


# ── CLI ───────────────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="build_campaign_payload.py",
        description="Deterministic SF-Campaign payload + verdict builder (BC-12701).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write campaign-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one decision row to stdout")
    args = ap.parse_args(argv)

    try:
        # Single-scenario runtime path (what the command calls after its SOQL reads):
        # one scenario in → one decision row out (stdout). Same decide() as the eval.
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
            row = {"id": sc.get("id", "runtime"), **decide(_scenario_inputs(sc), sc.get("sf_state"))}
            print(json.dumps(row, ensure_ascii=False))
            return 0

        # Emit batch path (the eval adapter): fixture → campaign-emit.json.
        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios)
            (out_dir / "campaign-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
