#!/usr/bin/env python3
"""Deterministic SF-Campaign status-update payload + verdict builder for
/revops:update-sf-campaign-status (BC-12942, ADR-028 Phase-2 Batch A).

The side-effecting σ3 *sibling* of build_campaign_payload.py (BC-12701): this is
the PURE, hermetic decision core the command delegates to in BOTH its normal and
emit runs (ADR-028 D2 — single source of truth; the BC-12701 refinement #3 that
runtime and eval MUST share one entrypoint so the eval can't certify a parallel
path). Given the status-transition inputs AND the *injected* result of the
command's ONE live SOQL read, it computes — with NO MCP/network call and NO
Salesforce write — the would_update / would_noop / dry_run / campaign_not_found /
error **verdict** plus the SF Campaign UPDATE **payload** that *would* be sent.

The seam (the hard part of this command): the noop/dry_run decision depends on a
LIVE SOQL existence-and-current-state read (Phase 2: `SELECT Id, Status,
Substatus__c, LastModifiedDate FROM Campaign WHERE Name='<slug>'`). To make THIS
builder pure — hence the eval hermetic — that ONE read is passed in as `sf_state`
(create-sf-campaign injected TWO; there is NO owner lookup here — the cheaper-than-
create delta):

    sf_state = {
      "campaign": {"Id": "701...", "Status": "In Progress",
                   "Substatus__c": null, "LastModifiedDate": "..."}   # the Phase-2 row
                  | null,                                              # 0 rows
    }

At RUNTIME the command performs the SOQL read and passes the row in here; at EVAL
time the fixture injects the same shape (exactly the plan-campaign idiom of
injecting `created_at` to defeat `now()`). `decide()` does its OWN mapping-table
lookup + null≡empty Substatus__c noop comparison so that logic is itself under
test, not stubbed past.

Verdict precedence MIRRORS the command's phase order EXACTLY (Fork #1, BC-12942
grill — the ONLY ladder where decide() faithfully models the command):

    missing_required_flag        (presence, before Phase 0)
    invalid_target_org           (Phase 0 — reused BC-12639 validator, byte-identical)
    invalid_slug_format          (Phase 1)
    invalid_status --linear-status     (Phase 1)
    invalid_status --linear-substatus  (Phase 1)
    campaign_not_found           (Phase 2 — sf_state.campaign is null; a WARNING)
    dry_run                      (Phase 4 — WINS over noop; but campaign-existence
                                  at Phase 2 is upstream, so dry-run-against-missing
                                  is campaign_not_found, not a degenerate preview)
    would_noop                   (Phase 5 — current == mapped, null≡empty Substatus__c)
    would_update                 (Phase 6 — the UPDATE payload that WOULD be sent)

What's IN scope vs OUT (Fork #3): IN = the pre-write decision (Phases 0-5 + the
assembled Phase-6 payload) + the injected pre-write reads (the existing campaign
Id; the current LastModifiedDate for noop). OUT = the actual `sf data update
record` write, the post-write LastModifiedDate re-read, the Phase-7 URL
construction, and the degradation paths (sf_cli_error / instance_url_unknown /
updated_at_unavailable) — these are post-write/live-read failures, not pure
decisions. So per-field, NOT blanket: the record-id is a pre-write READ and
belongs in the emit (it appears in the dry_run preview's `command` string AND as
the row's `campaign_id`); only the genuinely post-write fields pin null (the new
LastModifiedDate, the Phase-7 `campaign_url`). would_noop's `updated_at` is the
EXCEPTION — it legitimately echoes the injected Phase-2 LastModifiedDate (no
re-read), so it carries the injected value, not null.

emit artifact (`--scenarios <fixture> --out-dir <dir>`):
    status-update-emit.json = {
      "schema_version": 1,
      "command": "/revops:update-sf-campaign-status",
      "scenarios": [ {id, verdict, target_org, payload|null, campaign_id, output|null}, ... ]
    }
The behavioral eval (BC-12589 harness) golden-compares a structural projection of
this matrix; a flipped verdict (e.g. a noop regression that stops short-circuiting
an already-matching campaign, or dropping the dry_run>noop precedence) shows up as
a golden diff.

Input-shape guards REUSE the BC-12639 validator byte-identically (no fork): the
`--target-org` shell-injection guard delegates to
`validate_target_org.is_valid_target_org`; the slug guard applies the canonical
regex documented in the command's Phase 1 flag table (byte-identical to
build_campaign_payload.SLUG_RE). Keeping them byte-identical is the producer↔
consumer parity discipline from BC-12594 — test_build_status_update_payload.sh
locks it.

Stdlib-only per CLAUDE.md § Conventions; same command+helper pattern as
build_campaign_payload.py / validate_target_org.py.

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
COMMAND = "/revops:update-sf-campaign-status"

# Canonical slug regex — BYTE-IDENTICAL to /revops:update-sf-campaign-status
# Phase 1 + build_campaign_payload.SLUG_RE. Parity is locked by
# test_build_status_update_payload.sh; do NOT "improve" this in isolation (a
# consumer that drifts from the canonical regex is the BC-12594 failure mode).
# fullmatch (not search) so a trailing newline can't sneak past the `$`, matching
# validate_target_org.py's discipline.
SLUG_RE = re.compile(r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$")

# Required flags (the command's flag table): --slug + --linear-status. The rest
# (--linear-substatus, --target-org, --dry-run) are optional. A scenario missing a
# required flag resolves to missing_required_flag — checked in flag-table order so
# the reported flag is deterministic (the first absent flag wins). Reported as the
# bare internal key (matching build_campaign_payload's "offer"/"slug" precedent);
# invalid_status, by contrast, reports the literal "--linear-status" flag per the
# command's Phase-1 prose. The golden locks both.
REQUIRED_FLAGS = ("slug", "linear_status")
DEFAULT_TARGET_ORG = "brite-prod"

# Closed sets the command's Phase 1 validates.
LINEAR_STATUSES = ("planning", "active", "completed", "killed")
LINEAR_SUBSTATUSES = ("", "paused")

# Verdicts (the behavioral signal). would_noop + dry_run are SUCCESS verdicts (no
# error — like create-sf-campaign's would_skip_duplicate); campaign_not_found is a
# WARNING (the underlying state is not caller-correctable from the update path).
V_UPDATE = "would_update"
V_NOOP = "would_noop"
V_DRY_RUN = "dry_run"
V_NOT_FOUND = "campaign_not_found"
V_ERROR = "error"


def _missing_flag(inputs: dict) -> str | None:
    """First required flag that is absent or blank (flag-table order)."""
    for flag in REQUIRED_FLAGS:
        v = inputs.get(flag)
        if v is None or (isinstance(v, str) and v.strip() == ""):
            return flag
    return None


def _map_target(linear_status: str, linear_substatus: str | None) -> tuple[str, str | None]:
    """The locked O6.Q1 mapping table → (sf_status, sf_substatus). sf_substatus is
    None for every transition except (active, paused). `linear_substatus` is only
    meaningful when linear_status == 'active'; other statuses treat it as (any)."""
    if linear_status == "planning":
        return ("Planned", None)
    if linear_status == "active":
        return ("In Progress", "Paused" if linear_substatus == "paused" else None)
    if linear_status == "completed":
        return ("Completed", None)
    # killed
    return ("Aborted", None)


def _norm_sub(value: str | None) -> str:
    """Normalize a Substatus__c value for the noop comparison: SF returns null for
    an unset overlay, and both a flag-omitted and a `--linear-substatus=` (empty)
    input map to a null mapped-substatus — all three compare equal. None/'' → ''."""
    return value or ""


def _payload(mapped_status: str, mapped_substatus: str | None) -> dict:
    """The Phase-6 UPDATE field-map that WOULD be sent. Substatus__c is the empty
    string when the mapped overlay is null — SF CLI v2.x treats '' as clear-the-
    field, so a (active,paused)→(active,null) transition clears the overlay (the
    segment is ALWAYS present, never omitted)."""
    return {"Status": mapped_status, "Substatus__c": mapped_substatus or ""}


def _result(verdict: str, *, target_org: str, payload=None, campaign_id=None, output=None) -> dict:
    """One scenario's decision row. `campaign_id` is the injected PRE-write read Id
    (present whenever the campaign exists; null otherwise) — NOT a post-write id, so
    unlike create-sf-campaign it is not blanket-nulled. The genuinely post-write
    fields (the new LastModifiedDate, the Phase-7 campaign_url) are what pin null."""
    return {
        "verdict": verdict,
        "target_org": target_org,
        "payload": payload,
        "campaign_id": campaign_id,
        "output": output,
    }


def decide(inputs: dict, sf_state: dict | None = None) -> dict:
    """PURE decision: (inputs, injected sf_state) -> a decision row.

    The single entrypoint shared by the command (runtime, with the live SOQL row)
    and the behavioral eval (with the fixture-injected row). Precedence mirrors the
    command's phase order exactly (see module docstring). Every branch's `output` is
    the EXACT soft-fail JSON envelope the command emits on stdout for that case (so
    the command's error/warning catalog and this builder can't drift) — except
    would_update, whose Phase-8 success envelope needs the post-write
    LastModifiedDate + URL and is therefore IO-layer-owned (output stays null, the
    in-scope artifact is `payload`; mirrors create-sf-campaign's would_create)."""
    sf_state = sf_state or {}
    target_org = inputs.get("target_org") or DEFAULT_TARGET_ORG

    # missing_required_flag (presence check before anything else).
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

    # Phase 1 — linear-status enum (fail-fast, in flag order: status before substatus).
    linear_status = inputs["linear_status"]
    if linear_status not in LINEAR_STATUSES:
        return _result(
            V_ERROR, target_org=target_org,
            output={"error": "invalid_status", "flag": "--linear-status", "value": linear_status},
        )

    # Phase 1 — linear-substatus enum (empty or 'paused'; omitted → '').
    linear_substatus = inputs.get("linear_substatus") or ""
    if linear_substatus not in LINEAR_SUBSTATUSES:
        return _result(
            V_ERROR, target_org=target_org,
            output={"error": "invalid_status", "flag": "--linear-substatus", "value": linear_substatus},
        )

    # Phase 2 — campaign lookup. sf_state.campaign is the injected row, or null = 0
    # rows. A WARNING (not error): the missing campaign is not caller-correctable
    # from the update path (auto-create upstream must be reconciled first).
    campaign = sf_state.get("campaign")
    if not campaign:
        return _result(
            V_NOT_FOUND, target_org=target_org,
            output={"warning": "campaign_not_found", "slug": slug},
        )

    # Phase 3 — compute the mapped target state (closed-set lookup).
    mapped_status, mapped_substatus = _map_target(linear_status, linear_substatus)
    campaign_id = campaign.get("Id")
    payload = _payload(mapped_status, mapped_substatus)

    # Phase 4 — dry-run preview. WINS over the Phase-5 noop short-circuit (a caller
    # passing --dry-run always gets the dry_run shape, even when it would be a noop),
    # but is downstream of the Phase-2 existence check above (campaign_not_found wins
    # over dry_run — the preview embeds the record-id from the Phase-2 read). The
    # output is the EXACT preview envelope the command emits verbatim at runtime.
    if inputs.get("dry_run"):
        mapped_sub_str = mapped_substatus or ""
        command_str = (
            "sf data update record --sobject Campaign --record-id "
            f"{campaign_id} --values \"Status='{mapped_status}' "
            f"Substatus__c='{mapped_sub_str}'\" --target-org \"{target_org}\" --json"
        )
        return _result(
            V_DRY_RUN, target_org=target_org, payload=payload, campaign_id=campaign_id,
            output={
                "dry_run": True,
                "mapping": {
                    "linear_status": linear_status,
                    "linear_substatus": linear_substatus,
                    "sf_status": mapped_status,
                    "sf_substatus": mapped_sub_str,
                },
                "command": command_str,
                "payload": payload,
                "target_org": target_org,
            },
        )

    # Phase 5 — idempotency noop pre-check. current == mapped (treating SOQL-null and
    # empty-string Substatus__c as equivalent) → already in target state, return
    # success without issuing the UPDATE. The success envelope is emitted directly
    # (no post-write step), so decide() owns all of it EXCEPT the Phase-7
    # campaign_url (an IO-derived field the command fills at runtime — pinned null
    # here, the out-of-scope invariant); updated_at echoes the injected Phase-2
    # LastModifiedDate (no re-read — the in-scope exception).
    current_status = campaign.get("Status")
    current_substatus = campaign.get("Substatus__c")
    if current_status == mapped_status and _norm_sub(current_substatus) == _norm_sub(mapped_substatus):
        return _result(
            V_NOOP, target_org=target_org, payload=None, campaign_id=campaign_id,
            output={
                "campaign_id": campaign_id,
                "campaign_url": None,
                "campaign_name": slug,
                "status": mapped_status,
                "substatus": mapped_substatus or "",
                "updated_at": campaign.get("LastModifiedDate"),
                "noop": True,
            },
        )

    # would_update — the Phase-6 UPDATE that WOULD be sent. output stays null: the
    # Phase-8 success envelope needs the post-write LastModifiedDate + URL, which do
    # not exist on the hermetic emit path (mirrors create-sf-campaign would_create).
    return _result(V_UPDATE, target_org=target_org, payload=payload, campaign_id=campaign_id)


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any verdict."""


# Keys that describe a scenario's INPUTS (everything else on the row is metadata
# like `id`/`note` or the injected `sf_state`).
_INPUT_KEYS = ("slug", "linear_status", "linear_substatus", "target_org", "dry_run")


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
        prog="build_status_update_payload.py",
        description="Deterministic SF-Campaign status-update payload + verdict builder (BC-12942).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write status-update-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario runtime mode: a scenario JSON file (or '-' for stdin); "
                         "prints one decision row to stdout")
    args = ap.parse_args(argv)

    try:
        # Single-scenario runtime path (what the command calls after its SOQL read):
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

        # Emit batch path (the eval adapter): fixture → status-update-emit.json.
        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios)
            (out_dir / "status-update-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
