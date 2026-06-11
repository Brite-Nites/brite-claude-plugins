#!/usr/bin/env python3
"""M5 gate unit cases — the pure decision core + parsers (BC-12590, ADR-028 Phase-1).

Authored FROM THE LOCKED SPEC (Split A′ precedence ladder, the §0 non-negotiables,
the debt-list integrity invariants), NOT by reverse-engineering eval_gate.py — so a
green run certifies the BEHAVIOR the ADR mandates, never "what the draft happens to
do" (the exact rot ADR-028 was born from: 47/47 passing on a command that never ran).

Each case exercises ONE pure function and returns True iff it behaved per spec.
`main(case)` exits 0 when the function behaved correctly, 1 otherwise; `--list`
prints every case name so the bash harness loops in lock-step (the _assert_cases.py
idiom — no hand-maintained duplicate list). Pure + hermetic: no git, no subprocess,
no filesystem.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import eval_gate as G  # noqa: E402
from structural_lint import Finding  # noqa: E402  (synthetic findings for the ADR-033 filter)


def _reasons(d) -> str:
    return " || ".join(d.block_reasons)


def _notes(d) -> str:
    return " || ".join(d.notes)


# ── decide() — Split A′ precedence ladder ─────────────────────────────────────
# decide(command, structural_block_reasons, eval_status, on_debt, waiver_reason, is_new)

CMD = "plugins/marketing/commands/plan-campaign.md"


def decide_pass_clean() -> bool:
    # A passing eval + no structural gate finding → OK, never blocked.
    d = G.decide(CMD, [], "pass", on_debt=False, waiver_reason=None, is_new=False)
    return d.blocked is False and d.status == "ok-eval"


def decide_pass_with_r1() -> bool:
    # Split A′: structural R1 blocks ANY changed command, even one with a passing
    # eval. R1 is gated by changed-set membership alone.
    d = G.decide(CMD, ["structural[R1-side-effecting-needs-flag]: declares ..."],
                 "pass", on_debt=False, waiver_reason=None, is_new=False)
    return d.blocked is True and d.status == "blocked" and "structural[R1" in _reasons(d)


def decide_eval_registered_but_fails() -> bool:
    # A registered eval that FAILS → BLOCK (registration alone is not enough).
    d = G.decide(CMD, [], "fail", on_debt=False, waiver_reason=None, is_new=False)
    return d.blocked is True and "FAILS" in _reasons(d)


def decide_grandfathered_exempt() -> bool:
    # Pre-existing (not net-new) command on the debt list, no eval → eval-exempt.
    d = G.decide(CMD, [], "absent", on_debt=True, waiver_reason=None, is_new=False)
    return d.blocked is False and d.status == "exempt-grandfathered"


def decide_grandfathered_still_r1() -> bool:
    # A grandfathered command that is CHANGED and trips R1 still blocks on R1 — the
    # debt list grandfathers ONLY the (expensive) eval, never the (cheap) R1 flag.
    d = G.decide(CMD, ["structural[R1-side-effecting-needs-flag]: ..."],
                 "absent", on_debt=True, waiver_reason=None, is_new=False)
    return d.blocked is True and d.status == "blocked"


def decide_netnew_launder_blocked() -> bool:
    # NOTE #1 deterministic close: a net-new command (git ADD) is NOT cleared by a
    # grandfathered debt row — that's the laundering the ∪==surface invariant would
    # otherwise push devs toward. Must carry an eval or a waiver instead.
    d = G.decide(CMD, [], "absent", on_debt=True, waiver_reason=None, is_new=True)
    return d.blocked is True and "grandfathered" in _reasons(d).lower()


def decide_netnew_waiver_ok() -> bool:
    # A net-new command with a valid `# eval-waiver: <reason>` marker → exempt-waiver.
    d = G.decide(CMD, [], "absent", on_debt=False, waiver_reason="builder lands in BC-9999", is_new=True)
    return d.blocked is False and d.status == "exempt-waiver" and "BC-9999" in _notes(d)


def decide_netnew_empty_waiver_blocked() -> bool:
    # An EMPTY waiver marker does not suppress (mirrors lint:not-side-effecting).
    d = G.decide(CMD, [], "absent", on_debt=False, waiver_reason="", is_new=True)
    return d.blocked is True and "empty marker" in _reasons(d).lower()


def decide_netnew_nothing_blocked() -> bool:
    # Net-new, not listed, no eval, no waiver → BLOCK.
    d = G.decide(CMD, [], "absent", on_debt=False, waiver_reason=None, is_new=True)
    return d.blocked is True and d.status == "blocked"


def decide_modified_unlisted_blocked() -> bool:
    # A modified pre-existing command not on the debt list and not eval'd → BLOCK
    # (the debt list should have listed it; the integrity --check also catches this).
    d = G.decide(CMD, [], "absent", on_debt=False, waiver_reason=None, is_new=False)
    return d.blocked is True and d.status == "blocked"


def decide_modified_waiver_ok() -> bool:
    # A waiver marker also clears a modified-but-unlisted command (recorded, never silent).
    d = G.decide(CMD, [], "absent", on_debt=False, waiver_reason="reason here", is_new=False)
    return d.blocked is False and d.status == "exempt-waiver"


def decide_eval_pass_beats_debt() -> bool:
    # Strongest signal wins: a passing eval → OK even if also (wrongly) on the debt
    # list. (The --check invariant separately flags the debt∩ADAPTERS overlap.)
    d = G.decide(CMD, [], "pass", on_debt=True, waiver_reason=None, is_new=False)
    return d.blocked is False and d.status == "ok-eval"


# ── classify_changes() — git --name-status → {command_path: is_new} ───────────


def classify_add_is_new() -> bool:
    out = G.classify_changes("A\tplugins/marketing/commands/foo.md")
    return out == {"plugins/marketing/commands/foo.md": True}


def classify_modify_not_new() -> bool:
    out = G.classify_changes("M\tplugins/marketing/commands/foo.md")
    return out == {"plugins/marketing/commands/foo.md": False}


def classify_delete_dropped() -> bool:
    # A pure deletion drops out of the changed set (its stale row is the --check's job).
    out = G.classify_changes("D\tplugins/marketing/commands/foo.md")
    return out == {}


def classify_noncommand_ignored() -> bool:
    out = G.classify_changes(
        "A\tplugins/marketing/skills/x/SKILL.md\n"
        "M\tdocs/skill-eval-debt.md\n"
        "M\tscripts/eval/eval_gate.py"
    )
    return out == {}


def classify_rename_newpath_is_new() -> bool:
    # Defensive: if a rename ever surfaces (R<score>) despite --no-renames, the NEW
    # path is treated as net-new (forces eval/waiver/re-list — safe, deterministic).
    out = G.classify_changes(
        "R100\tplugins/marketing/commands/old.md\tplugins/marketing/commands/new.md"
    )
    return out == {"plugins/marketing/commands/new.md": True}


def classify_typechange_modified() -> bool:
    out = G.classify_changes("T\tplugins/workflows/commands/ship.md")
    return out == {"plugins/workflows/commands/ship.md": False}


def classify_mixed() -> bool:
    out = G.classify_changes(
        "A\tplugins/a/commands/new.md\n"
        "M\tplugins/b/commands/mod.md\n"
        "D\tplugins/c/commands/gone.md\n"
        "M\tREADME.md\n"
        "\n"
    )
    return out == {"plugins/a/commands/new.md": True, "plugins/b/commands/mod.md": False}


# ── parse_debt_table() — the one markdown table → {path: row} ─────────────────

_DEBT = """\
# header prose
| command | plugin | status | reason | added |
|---|---|---|---|---|
| `plugins/workflows/commands/ship.md` | workflows | grandfathered | no-eval | 2026-06-07 |
| `plugins/marketing/commands/new-offer.md` | marketing | waiver | builder pending | 2026-06-07 |
some trailing prose
"""


def debt_parse_rows() -> bool:
    rows = G.parse_debt_table(_DEBT)
    return (
        set(rows) == {
            "plugins/workflows/commands/ship.md",
            "plugins/marketing/commands/new-offer.md",
        }
        and rows["plugins/workflows/commands/ship.md"]["status"] == "grandfathered"
        and rows["plugins/marketing/commands/new-offer.md"]["status"] == "waiver"
    )


def debt_parse_skips_header_separator() -> bool:
    # The "| command |" header row and the "|---|" separator are NOT command paths,
    # so the glob-guard self-skips them with no positional bookkeeping.
    rows = G.parse_debt_table(_DEBT)
    return "command" not in rows and "---" not in rows


def debt_parse_empty() -> bool:
    return G.parse_debt_table("") == {} and G.parse_debt_table("no table here") == {}


# ── check_invariants() — debt∩ADAPTERS=∅, ∪=surface, symmetric waiver↔row ─────
# check_invariants(surface, evald, debt_rows, waiver_markers) -> list[problem]

A = "plugins/marketing/commands/plan-campaign.md"   # eval'd (in ADAPTERS)
B = "plugins/workflows/commands/ship.md"            # grandfathered
C = "plugins/marketing/commands/new-offer.md"       # waiver
SURFACE = {A, B, C}


def _rows(**status_by_path) -> dict:
    return {p: {"status": s} for p, s in status_by_path.items()}


def check_clean() -> bool:
    probs = G.check_invariants(SURFACE, {A}, _rows(**{B: "grandfathered", C: "waiver"}), {C})
    return probs == []


def check_overlap_flagged() -> bool:
    # A is both eval'd AND on the debt list → debt ∩ ADAPTERS must be ∅.
    probs = G.check_invariants(SURFACE, {A}, _rows(**{A: "grandfathered", B: "grandfathered", C: "waiver"}), {C})
    return any(A in p and "∩" in p for p in probs)


def check_stale_flagged() -> bool:
    # A debt row for a command no longer on the surface → stale.
    ghost = "plugins/marketing/commands/deleted.md"
    probs = G.check_invariants(SURFACE, {A}, _rows(**{B: "grandfathered", C: "waiver", ghost: "grandfathered"}), {C})
    return any(ghost in p and "stale" in p.lower() for p in probs)


def check_missing_flagged() -> bool:
    # B is neither eval'd nor on the debt list → ∪ != surface.
    probs = G.check_invariants(SURFACE, {A}, _rows(**{C: "waiver"}), {C})
    return any(B in p for p in probs)


def check_waiver_row_without_marker() -> bool:
    # C has a status=waiver row but NO in-file marker → silent waiver (forbidden).
    probs = G.check_invariants(SURFACE, {A}, _rows(**{B: "grandfathered", C: "waiver"}), set())
    return any(C in p and "marker" in p.lower() for p in probs)


def check_marker_without_row() -> bool:
    # B carries an in-file waiver marker but has no debt row → not recorded.
    probs = G.check_invariants(SURFACE, {A}, _rows(**{C: "waiver"}), {B, C})
    # B is also "missing" (∪!=surface); assert specifically the marker-no-row problem.
    return any(B in p and "marker" in p.lower() for p in probs)


def check_marker_wrong_status() -> bool:
    # B carries a marker but its debt row is grandfathered (should be waiver).
    probs = G.check_invariants(SURFACE, {A}, _rows(**{B: "grandfathered", C: "waiver"}), {B, C})
    return any(B in p and "waiver" in p.lower() for p in probs)


def check_waiver_coupled_ok() -> bool:
    # status=waiver row + matching in-file marker → no coupling problem.
    probs = G.check_invariants(SURFACE, {A}, _rows(**{B: "grandfathered", C: "waiver"}), {C})
    return probs == []


# ── parse_structural_debt() + filter_structural() — ADR-033 full-surface gate ──
# Authored from the BC-13213 locked spec: rows keyed (file, rule); baseline only on
# R2 and pins the grandfathered body line count (growth past it blocks; equality
# suppresses); malformed rows are loud problems that never suppress; a row with no
# live finding of ANY severity is stale.

BIG = "plugins/a/commands/big.md"
SKL = "plugins/b/skills/s/SKILL.md"

_SDEBT = f"""\
# header prose
| file | rule | reason | added | baseline |
|---|---|---|---|---|
| `{BIG}` | R2-body-too-long | flagship, split later | 2026-06-10 | 906 |
| `{SKL}` | R4-nested-refs | upstream subtree | 2026-06-10 |  |
trailing prose
"""


def _gf(file: str, rule: str, sev: str = "gate") -> Finding:
    return Finding(rule, sev, "msg", file, 1)


def sdebt_parse_rows() -> bool:
    rows, problems = G.parse_structural_debt(_SDEBT)
    return (
        problems == []
        and set(rows) == {(BIG, "R2-body-too-long"), (SKL, "R4-nested-refs")}
        and rows[(BIG, "R2-body-too-long")]["baseline"] == 906
        and rows[(SKL, "R4-nested-refs")]["baseline"] is None
    )


def sdebt_parse_skips_header_separator() -> bool:
    rows, _ = G.parse_structural_debt(_SDEBT)
    return all(k[0].startswith("plugins/") for k in rows)


def sdebt_parse_empty() -> bool:
    return G.parse_structural_debt("") == ({}, []) and G.parse_structural_debt("no table") == ({}, [])


def sdebt_parse_malformed_baseline() -> bool:
    # A non-integer baseline must be a loud problem AND the row must not suppress
    # (dropped) — never a silent exemption (the pure-builder-crash family lesson).
    text = f"| `{BIG}` | R2-body-too-long | r | d | lots |\n"
    rows, problems = G.parse_structural_debt(text)
    return rows == {} and any("malformed baseline" in p for p in problems)


def sdebt_parse_baseline_only_r2() -> bool:
    # A baseline on a non-R2 rule is a schema problem (it would be meaningless).
    text = f"| `{SKL}` | R4-nested-refs | r | d | 100 |\n"
    rows, problems = G.parse_structural_debt(text)
    return rows == {} and any("only valid" in p for p in problems)


def sdebt_parse_missing_rule_id() -> bool:
    text = f"| `{BIG}` |  | r | d |  |\n"
    rows, problems = G.parse_structural_debt(text)
    return rows == {} and any("no valid rule id" in p for p in problems)


def sdebt_parse_duplicate_row() -> bool:
    text = (f"| `{SKL}` | R4-nested-refs | r | d |  |\n"
            f"| `{SKL}` | R4-nested-refs | r2 | d |  |\n")
    rows, problems = G.parse_structural_debt(text)
    return len(rows) == 1 and any("duplicate" in p for p in problems)


def sfilter_blocks_unlisted() -> bool:
    blocking, suppressed, problems = G.filter_structural([_gf(BIG, "R3-description-quality")], {}, {})
    return len(blocking) == 1 and suppressed == [] and problems == []


def sfilter_suppresses_listed() -> bool:
    rows = {(SKL, "R4-nested-refs"): {"reason": "r", "added": "d", "baseline": None}}
    blocking, suppressed, problems = G.filter_structural([_gf(SKL, "R4-nested-refs")], rows, {})
    return blocking == [] and len(suppressed) == 1 and problems == []


def sfilter_rule_scoped_row() -> bool:
    # A row grandfathers ONE rule on ONE file: the same file's OTHER gate finding
    # still blocks (the (file, rule) key is the whole point vs a file-level mute).
    rows = {(SKL, "R4-nested-refs"): {"reason": "r", "added": "d", "baseline": None}}
    blocking, suppressed, _ = G.filter_structural(
        [_gf(SKL, "R4-nested-refs"), _gf(SKL, "R3-description-quality")], rows, {})
    return len(suppressed) == 1 and len(blocking) == 1 and blocking[0].rule_id == "R3-description-quality"


def sfilter_baseline_at_limit_suppresses() -> bool:
    rows = {(BIG, "R2-body-too-long"): {"reason": "r", "added": "d", "baseline": 906}}
    blocking, suppressed, problems = G.filter_structural(
        [_gf(BIG, "R2-body-too-long")], rows, {BIG: 906})
    return blocking == [] and len(suppressed) == 1 and problems == []


def sfilter_baseline_growth_blocks() -> bool:
    rows = {(BIG, "R2-body-too-long"): {"reason": "r", "added": "d", "baseline": 906}}
    blocking, suppressed, problems = G.filter_structural(
        [_gf(BIG, "R2-body-too-long")], rows, {BIG: 907})
    return len(blocking) == 1 and suppressed == [] and problems == []


def sfilter_baseline_missing_count_is_loud() -> bool:
    # No current body count available for a baseline row → problem + blocking,
    # never a silent exemption.
    rows = {(BIG, "R2-body-too-long"): {"reason": "r", "added": "d", "baseline": 906}}
    blocking, suppressed, problems = G.filter_structural(
        [_gf(BIG, "R2-body-too-long")], rows, {})
    return len(blocking) == 1 and suppressed == [] and any("no current body line count" in p for p in problems)


def sfilter_stale_row_problem() -> bool:
    rows = {(BIG, "R2-body-too-long"): {"reason": "r", "added": "d", "baseline": 906}}
    blocking, suppressed, problems = G.filter_structural([], rows, {BIG: 100})
    return blocking == [] and suppressed == [] and any("stale" in p for p in problems)


def sfilter_advisory_live_not_blocked() -> bool:
    # An advisory finding never blocks, but it DOES keep a pre-flip debt row live
    # (rows may land one PR before their rule's severity flips).
    rows = {(BIG, "R2-body-too-long"): {"reason": "r", "added": "d", "baseline": 906}}
    blocking, suppressed, problems = G.filter_structural(
        [_gf(BIG, "R2-body-too-long", sev="advisory")], rows, {BIG: 100})
    return blocking == [] and suppressed == [] and problems == []


CASES = {
    "decide-pass-clean": decide_pass_clean,
    "decide-pass-with-r1": decide_pass_with_r1,
    "decide-eval-registered-but-fails": decide_eval_registered_but_fails,
    "decide-grandfathered-exempt": decide_grandfathered_exempt,
    "decide-grandfathered-still-r1": decide_grandfathered_still_r1,
    "decide-netnew-launder-blocked": decide_netnew_launder_blocked,
    "decide-netnew-waiver-ok": decide_netnew_waiver_ok,
    "decide-netnew-empty-waiver-blocked": decide_netnew_empty_waiver_blocked,
    "decide-netnew-nothing-blocked": decide_netnew_nothing_blocked,
    "decide-modified-unlisted-blocked": decide_modified_unlisted_blocked,
    "decide-modified-waiver-ok": decide_modified_waiver_ok,
    "decide-eval-pass-beats-debt": decide_eval_pass_beats_debt,
    "classify-add-is-new": classify_add_is_new,
    "classify-modify-not-new": classify_modify_not_new,
    "classify-delete-dropped": classify_delete_dropped,
    "classify-noncommand-ignored": classify_noncommand_ignored,
    "classify-rename-newpath-is-new": classify_rename_newpath_is_new,
    "classify-typechange-modified": classify_typechange_modified,
    "classify-mixed": classify_mixed,
    "debt-parse-rows": debt_parse_rows,
    "debt-parse-skips-header-separator": debt_parse_skips_header_separator,
    "debt-parse-empty": debt_parse_empty,
    "check-clean": check_clean,
    "check-overlap-flagged": check_overlap_flagged,
    "check-stale-flagged": check_stale_flagged,
    "check-missing-flagged": check_missing_flagged,
    "check-waiver-row-without-marker": check_waiver_row_without_marker,
    "check-marker-without-row": check_marker_without_row,
    "check-marker-wrong-status": check_marker_wrong_status,
    "check-waiver-coupled-ok": check_waiver_coupled_ok,
    "sdebt-parse-rows": sdebt_parse_rows,
    "sdebt-parse-skips-header-separator": sdebt_parse_skips_header_separator,
    "sdebt-parse-empty": sdebt_parse_empty,
    "sdebt-parse-malformed-baseline": sdebt_parse_malformed_baseline,
    "sdebt-parse-baseline-only-r2": sdebt_parse_baseline_only_r2,
    "sdebt-parse-missing-rule-id": sdebt_parse_missing_rule_id,
    "sdebt-parse-duplicate-row": sdebt_parse_duplicate_row,
    "sfilter-blocks-unlisted": sfilter_blocks_unlisted,
    "sfilter-suppresses-listed": sfilter_suppresses_listed,
    "sfilter-rule-scoped-row": sfilter_rule_scoped_row,
    "sfilter-baseline-at-limit-suppresses": sfilter_baseline_at_limit_suppresses,
    "sfilter-baseline-growth-blocks": sfilter_baseline_growth_blocks,
    "sfilter-baseline-missing-count-is-loud": sfilter_baseline_missing_count_is_loud,
    "sfilter-stale-row-problem": sfilter_stale_row_problem,
    "sfilter-advisory-live-not-blocked": sfilter_advisory_live_not_blocked,
}


def main(argv: list[str]) -> int:
    if not argv or argv[0] == "--list":
        print("\n".join(CASES))
        return 0
    case = argv[0]
    fn = CASES.get(case)
    if fn is None:
        sys.stderr.write(f"unknown case: {case}\n")
        return 2
    try:
        ok = fn()
    except Exception as exc:  # a function raising is itself a failure
        sys.stderr.write(f"case {case} raised: {exc!r}\n")
        return 1
    if not ok:
        sys.stderr.write(f"case {case}: pure function did not behave per spec\n")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
