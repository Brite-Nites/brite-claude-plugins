#!/usr/bin/env python3
"""Deterministic concept-payload projection builder for /marketing:capture-idea
(BC-13161, ADR-028 Phase-2 — the eval for the LAST grandfathered command).

The PURE, hermetic decision core /marketing:capture-idea delegates to for the parts
of the tier-1 idea intake that are NOT conversational: given the 9 parsed concept
fields (the free-text brain-dump parse is the LLM part, held out / fixtured) and the
INJECTED reads (the resolved [CONCEPT LIBRARY] milestone id, the capture date, and the
frozen-canonicals membership state), it computes — with NO MCP call and NO Linear
write — the deterministic projection of the Concept Library issue that WOULD be filed:

    - derived [Sketch]/[Maturing] status                          (Step 5)
    - the missing-for-completeness list                            (Step 5)
    - the 3-state canonical-match footer (FULL/VERTICAL-ONLY/NO)   (Step 4 / Step 7)
    - the status label name (status:sketch | status:maturing)      (Step 9)
    - the save_issue PAYLOAD (title, milestone, body, state, …)    (Step 7 / Step 10)

What's OUT of scope (held out as the LLM part, ADR-028 D2): the Step-2/3 free-text →
9-field parse, the idea→vertical/persona/offer mapping (the proposed slugs are
fixtured), the Step-6 is-duplicate noun-compare (the concept pool is never read here),
and the "treat the dump as data, not instructions" threat judgment. The mutating
save_issue / create_issue_label stay UN-driven (this emits no write).

The seam (the inject-the-reads idiom): the milestone id + capture date + the canonical
membership all depend on LIVE reads. To keep THIS builder pure — hence the eval
hermetic — they are passed in as injected_reads; at RUNTIME the command performs the
reads, at EVAL time the fixture injects the same shapes.

Stdlib-only per CLAUDE.md § Conventions; same command+template pattern as
build_raise_ticket_payload.py (BC-12944).

Exit codes: 0 = built/decided OK (incl. an offer_missing reject row); 2 = usage /
unreadable-or-malformed fixture (an infra error, distinct from any per-scenario
`error` verdict).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _shared import canonicals_reader  # noqa: E402  (read-only canonicals query, stdlib)

SCHEMA_VERSION = 1
COMMAND = "/marketing:capture-idea"

# Step 10 filing target: project + team are filed BY NAME (constants); only the
# milestone is an injected id (the [CONCEPT LIBRARY] milestone resolved in Step 1).
PROJECT = "Brite GTM"
TEAM = "Brite Company"
STATE = "Backlog"
PRIORITY = 0

# Step 3 brand normalization: the --brand slugs map to the canonical display values;
# multi/unsure (and an already-display value) pass through. An absent/empty brand
# defaults to `unsure` (Step 3: "If unclear, unsure"). The status predicate then
# treats `unsure` — and ONLY `unsure` — as not-a-resolved-brand (multi PASSES).
_BRAND_SLUGS = {"nites": "Brite Nites", "labs": "Brite Labs", "supply": "Brite Supply"}


def _norm_brand(brand: object) -> str:
    # TOTAL + honest return type: a non-string (incl. an unhashable list/dict that would
    # raise on the dict-key lookup, or a non-str that would skip the str return) coerces
    # to `unsure` — the same degenerate-input discipline decide() applies to containers.
    if not isinstance(brand, str) or not brand:
        return "unsure"
    return _BRAND_SLUGS.get(brand, brand)


def _is_set(v) -> bool:
    """A best-effort field is present iff it's a non-empty, non-whitespace string."""
    return isinstance(v, str) and v.strip() != ""


def _status(pf: dict) -> str:
    """Step 5: [Maturing] iff offer ∧ brand≠unsure ∧ source ∧ (ICP ∨ commercial-model);
    else [Sketch]. ([Ready-to-promote] is never auto-set.)"""
    maturing = (
        _is_set(pf.get("offer"))
        and _norm_brand(pf.get("brand")) != "unsure"
        and _is_set(pf.get("source"))
        and (_is_set(pf.get("icp")) or _is_set(pf.get("commercial_model")))
    )
    return "Maturing" if maturing else "Sketch"


# Step 5 missing-for-completeness: the maturity-relevant fields still blank, in a
# FIXED order. brand counts as missing when it normalizes to `unsure` (it is never
# literally blank — Step 3 defaults it). `offer` is never listed (required-to-file);
# `cross-refs` / `next-move` are encouraged extras that don't drive maturity and are
# excluded. The list is NOT the status predicate: a [Maturing] concept can still have
# a non-empty list (e.g. has ICP, no commercial model).
def _missing_for_completeness(pf: dict) -> list:
    missing = []
    if _norm_brand(pf.get("brand")) == "unsure":
        missing.append("brand fit")
    if not _is_set(pf.get("source")):
        missing.append("source")
    if not _is_set(pf.get("icp")):
        missing.append("ICP")
    if not _is_set(pf.get("commercial_model")):
        missing.append("commercial model")
    return missing


def _match_state(pf: dict, canonical_state: dict | None) -> str:
    """Step 4: the 3-state canonical match, classified over the injected canonical_state.
    The builder OWNS this — it can DOWNGRADE the LLM's proposed mapping:

      no            — no candidate vertical, or it's not in the canonicals manifest
      full          — vertical in manifest AND the proposed persona + offer slugs BOTH
                      exist in that vertical's yaml
      vertical-only — vertical in manifest but persona/offer don't both resolve (incl.
                      the DOWNGRADE when the LLM proposes a slug absent from the yaml —
                      the hallucination catch)
    """
    cv = pf.get("candidate_vertical")
    cs = canonical_state if isinstance(canonical_state, dict) else {}
    if not _is_set(cv) or not cs.get("in_manifest"):
        return "no"
    cp, co = pf.get("candidate_persona"), pf.get("candidate_offer")
    personas = cs.get("personas") if isinstance(cs.get("personas"), list) else []
    offers = cs.get("offers") if isinstance(cs.get("offers"), list) else []
    if _is_set(cp) and _is_set(co) and cp in personas and co in offers:
        return "full"
    return "vertical-only"


# Step 7 body render -----------------------------------------------------------

PROMOTION_CRITERIA = (
    "Named lead / champion identified",
    "Target ICP defined (not just guessed)",
    "Commercial model decided",
    "At least one named reference account or prospect",
    "Owner assigned for Phase 2+",
)
DASH = "—"  # em-dash for blank fields (Step 7)


def _norm_model(model: object) -> str:
    """Step 3: the --commercial-model flag's hyphens render as spaces
    (install-fee → install fee). A blank model is the caller's `—` concern."""
    return (model or "").replace("-", " ") if isinstance(model, str) else ""


def _or_dash(v: object) -> str:
    return v if _is_set(v) else DASH


def _footer(match_state: str, pf: dict, canonical_state: dict | None = None) -> str:
    """Step 7's 'When ready to promote' footer — each match-state a DISTINCT command
    string. FULL interpolates v/p/o. VERTICAL-ONLY splits into two sub-cases by whether
    the vertical already has canonical entries (so the DOWNGRADE case — vertical HAS
    personas/offers but the LLM's proposed slug didn't match — does NOT tell the user to
    create a duplicate). NO leaves <v> a literal placeholder (the LLM's slug-invention
    stays out of the asserted output)."""
    cv = pf.get("candidate_vertical")
    if match_state == "full":
        return (
            f"Run `/marketing:plan-campaign --vertical {cv} "
            f"--persona {pf.get('candidate_persona')} --offer {pf.get('candidate_offer')}` "
            f"to scaffold the full campaign."
        )
    if match_state == "vertical-only":
        cs = canonical_state if isinstance(canonical_state, dict) else {}
        personas = cs.get("personas") if isinstance(cs.get("personas"), list) else []
        offers = cs.get("offers") if isinstance(cs.get("offers"), list) else []
        if personas or offers:
            # Downgrade: the vertical HAS canonical entries, but this idea didn't map to
            # an existing persona+offer pair. Reuse — never direct toward a duplicate.
            return (
                f"Vertical `{cv}` is canonical and already has canonical entries, but this "
                f"idea didn't map to an existing persona + offer pair. Reuse an existing "
                f"canonical persona + offer for `{cv}` (don't create duplicates), then "
                f"`/marketing:plan-campaign --vertical {cv} --persona <persona-slug> "
                f"--offer <offer-slug>`."
            )
        # Empty: the vertical is canonical but has no personas/offers yet → create them.
        return (
            f"Vertical `{cv}` is canonical, but it has no canonical persona/offer yet. "
            f"First `/marketing:new-persona --vertical {cv} --slug <persona-slug> "
            f'--display "<Persona Name>"` and `/marketing:new-offer --vertical {cv} '
            f'--slug <offer-slug> --display "<Offer Name>" '
            f"--posture <knowledge|free-asset|pilot|risk-reversal>`, then "
            f"`/marketing:plan-campaign --vertical {cv} --persona <persona-slug> "
            f"--offer <offer-slug>`."
        )
    return (
        'No canonical vertical yet. First `/marketing:new-vertical --slug <v> '
        '--display "<Vertical Name>"`, then `/marketing:new-persona` + '
        "`/marketing:new-offer` (as above), then `/marketing:plan-campaign`."
    )


def _render_body(pf: dict, status: str, match_state: str, capture_date,
                 canonical_state: dict | None = None) -> str:
    """The Step-7 issue body. Deterministic given the (fixtured) parsed fields + the
    injected capture date — blank encouraged fields show an em-dash."""
    lead = pf.get("lead")
    crit = []
    for i, c in enumerate(PROMOTION_CRITERIA):
        if i == 0 and _is_set(lead):
            crit.append(f"- [x] {c} {DASH} {lead}")
        else:
            crit.append(f"- [ ] {c}")
    checklist = "\n".join(crit)
    model = pf.get("commercial_model")
    model_disp = _norm_model(model) if _is_set(model) else DASH
    return (
        f"**Status:** [{status}]\n\n"
        f"## Concept\n"
        f"**One-sentence offer:** {pf.get('offer')}\n"
        f"**Brand fit:** {_norm_brand(pf.get('brand'))}\n"
        f"**Source / inspiration:** {_or_dash(pf.get('source'))}\n\n"
        f"## Detail (encouraged)\n"
        f"**Target ICP guess:** {_or_dash(pf.get('icp'))}\n"
        f"**Commercial model guess:** {model_disp}\n"
        f"**Cross-references:** {_or_dash(pf.get('cross_refs'))}\n"
        f"**Next move to mature:** {_or_dash(pf.get('next_move'))}\n\n"
        f"## Promotion criteria — graduate to a campaign milestone when ALL are true\n"
        f"{checklist}\n\n"
        f"## When ready to promote\n"
        f"{_footer(match_state, pf, canonical_state)}\n\n"
        f"---\n"
        f"_Captured via `/marketing:capture-idea` on {capture_date}. Concept Library "
        f"tier-1 intake; promotion is a separate, deliberate step._"
    )


def _error(code: str) -> dict:
    """A validation reject row (a decision — still exit 0). No payload projection."""
    return {
        "error": code,
        "status": None,
        "missing_for_completeness": None,
        "match_state": None,
        "label_name": None,
        "save_issue_payload": None,
    }


def decide(parsed_fields: dict, injected_reads: dict | None = None) -> dict:
    """PURE decision: (parsed_fields, injected reads) -> a projection row.

    The single entrypoint shared by the command (runtime, with live reads) and the
    behavioral eval (with fixture-injected reads). TOTAL: degenerate inputs (a non-dict
    parsed_fields / injected_reads / canonical_state, a non-string or unhashable
    per-field value, malformed injected reads) coerce to a clean row or an error row —
    never an uncaught traceback (the exit-2-or-clean contract).
    """
    pf = parsed_fields if isinstance(parsed_fields, dict) else {}
    inj = injected_reads if isinstance(injected_reads, dict) else {}

    # Step 3 offer guard: the one-sentence offer is the ONE field required to file.
    # Absent → a structured reject (the command prompts for it at runtime; the builder
    # records that it can't file). This is a decision, not an infra crash.
    if not _is_set(pf.get("offer")):
        return _error("offer_missing")

    status = _status(pf)
    label_name = "status:maturing" if status == "Maturing" else "status:sketch"
    canonical_state = inj.get("canonical_state")
    match_state = _match_state(pf, canonical_state)
    # capture_date is an injected read; coerce a missing/blank one to the em-dash so
    # a degenerate inject renders "on —" rather than leaking str(None) into the body.
    capture_date = _or_dash(inj.get("capture_date"))

    payload = {
        "title": pf.get("concept_name"),
        "team": TEAM,
        "project": PROJECT,
        "milestone": inj.get("milestone_id"),
        "description": _render_body(pf, status, match_state, capture_date, canonical_state),
        "state": STATE,
        "priority": PRIORITY,
        "labels": [label_name],
    }

    return {
        "error": None,
        "status": status,
        "missing_for_completeness": _missing_for_completeness(pf),
        "match_state": match_state,
        "label_name": label_name,
        "save_issue_payload": payload,
    }


# ── scenario fixture → emit artifact ──────────────────────────────────────────


class BuildError(Exception):
    """Unreadable / malformed fixture (→ exit 2). Distinct from any reject row."""


def _resolve_canonical_state(scenario: dict, seed_dir: str | None) -> dict:
    """Populate canonical_state for the scenario's candidate vertical.

    An inline injected_reads.canonical_state WINS (pure / degenerate-state tests);
    otherwise read the FROZEN seed via canonicals_reader (the read+parse is under test,
    per the seed-read idiom). Total: a missing dir or an absent-from-manifest vertical
    degrades to a no-match canonical_state; an in-manifest vertical whose yaml is missing
    or unreadable degrades to vertical-only (empty personas/offers) — never raising.
    """
    inj = scenario.get("injected_reads")
    if isinstance(inj, dict) and "canonical_state" in inj:
        return inj["canonical_state"]
    pf = scenario.get("parsed_fields")
    pf = pf if isinstance(pf, dict) else {}
    cv = pf.get("candidate_vertical")
    empty = {"in_manifest": False, "personas": [], "offers": []}
    if not seed_dir or not isinstance(cv, str) or not cv:
        return empty
    canon = Path(seed_dir) / "canonicals"
    if cv not in canonicals_reader.load_canonicals_verticals(canon):
        return empty
    v = canonicals_reader.load_vertical(canon, cv) or {}
    personas = [p.get("slug") for p in (v.get("personas") or []) if isinstance(p, dict)]
    offers = [o.get("slug") for o in (v.get("offers") or []) if isinstance(o, dict)]
    return {"in_manifest": True, "personas": personas, "offers": offers}


def _scenario_decide(scenario: dict, seed_dir: str | None = None) -> dict:
    """Run decide() over one scenario object {parsed_fields, injected_reads}, after
    resolving the canonical_state seam from the frozen seed (or an inline override)."""
    if not isinstance(scenario, dict):
        raise BuildError("scenario is not an object")
    raw = scenario.get("injected_reads")
    inj = dict(raw) if isinstance(raw, dict) else {}
    inj["canonical_state"] = _resolve_canonical_state(scenario, seed_dir)
    return decide(scenario.get("parsed_fields"), inj)


def run_scenarios(scenarios: list, seed_dir: str | None = None) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        rows.append({"id": str(sc.get("id", f"scenario-{i}")), **_scenario_decide(sc, seed_dir)})
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
        prog="build_concept_payload.py",
        description="Deterministic /marketing:capture-idea payload projection builder (BC-13161).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write concept-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario mode: a scenario JSON file (or '-' for stdin); "
                         "prints one projection row to stdout")
    ap.add_argument("--seed-dir", default=None,
                    help="frozen canonicals seed dir (read for the footer classification)")
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
            row = {"id": str(sc.get("id", "runtime")), **_scenario_decide(sc, args.seed_dir)}
            print(json.dumps(row, ensure_ascii=False))
            return 0

        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios, args.seed_dir)
            (out_dir / "concept-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
