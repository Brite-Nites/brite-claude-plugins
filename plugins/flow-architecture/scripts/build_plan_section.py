#!/usr/bin/env python3
"""Deterministic /flow:plan-{discipline} Plan-section formatter (BC-12946, ADR-028
Phase-2 Batch E — the ONE shared builder behind all 5 plan-* commands).

The 5 commands (/flow:plan-eng, plan-story, plan-design, plan-qa, plan-docs) are
byte-identical except the discipline token; only their Phase 3 — the deterministic
Plan-section transform — is hermetic. This is that transform, extracted once. It
renders the four-mode reviewer outcome (`review_output = {mode, headline,
expansions?|reductions?|rigor_focus?, rationale?, adjustments?}`, the
four-mode-framework.md output_shape) into the Q43 sub-decision-5 Plan-section
markdown, and routes the per-discipline Q46 marker type `plan-<discipline>-section`.

Two orthogonal effects the eval pins:
  * MODE drives the FOLD (which mode-specific field sources the Refinements bullets,
    then adjustments[] last; rationale[] folds into the headline paragraph as a
    trailing sentence) — discipline-agnostic.
  * DISCIPLINE routes the MARKER (`plan-<discipline>-section`, the Q46 type) — the
    ONLY thing that varies across the 5 commands.

OUT of scope (ADR-028 D2): Phase 2 (the LLM reviewer that PRODUCES the review_output)
and Phase 4 (the linear_writeback that writes the section into the Linear issue body).
The eval drives Phase 3 ONLY — it injects a frozen review_output and asserts the
rendered markdown + the marker, never the reviewer's judgment or any live write.

emit artifact (`--discipline <d> --scenarios <fixture> --out-dir <dir>`):
    plan-<discipline>-emit.json = {
      "schema_version": 1,
      "command": "/flow:plan-<discipline>",
      "scenarios": [ {id, discipline, mode, marker_type, section_markdown, error}, … ]
    }
A degenerate review_output (not a dict / unknown-or-missing mode / missing headline)
yields an error row (section_markdown null, error set, mode null-or-echoed) — the
builder never crashes on malformed injected state (the exit-2-or-clean contract;
gotcha-pure-builder-crashes-on-malformed-injected-state). Malformed list fields
(non-list adjustments, non-string bullets) are coerced defensively, never raised.

Stdlib-only per CLAUDE.md § Conventions; same shape as build_canonical_emit.py
(one builder, an N-mode CLI selector). Exit codes (PROCESS): 0 = emitted OK;
2 = usage / unreadable-or-malformed FIXTURE (distinct from a per-scenario error row,
which is a SUCCESSFUL emit).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCHEMA_VERSION = 1

DISCIPLINES = ("eng", "story", "design", "qa", "docs")

# The four scope-axis modes (four-mode-framework.md § The four modes).
MODES = ("SCOPE_EXPANSION", "SELECTIVE_EXPANSION", "HOLD_SCOPE", "SCOPE_REDUCTION")

# Per-mode fold source (Q43 sub-decision 5 fold rules): the field whose entries
# become the leading Refinements bullets, before adjustments[] (always last).
MODE_SOURCE = {
    "SCOPE_EXPANSION": "expansions",
    "SELECTIVE_EXPANSION": "expansions",
    "HOLD_SCOPE": "rigor_focus",
    "SCOPE_REDUCTION": "reductions",
}


class BuildError(Exception):
    """Unreadable/malformed FIXTURE (→ process exit 2). Distinct from a per-scenario
    error row (a degenerate review_output), which is a SUCCESSFUL emit."""


def _str_list(v) -> list:
    """Coerce an injected list field to a list-of-strings, TOTALLY: a non-list (or a
    list with non-string members) never raises — it yields [] / the string members.
    This is the malformed-injected-state defense (the recurring Batch-C/D P1)."""
    if not isinstance(v, list):
        return []
    return [x for x in v if isinstance(x, str)]


def marker_type_for(discipline: str) -> str:
    return f"plan-{discipline}-section"


def render(review_output: dict, discipline: str) -> dict:
    """Pure transform: review_output × discipline → the emit row. The single
    entrypoint shared by the command (runtime) and the eval (injected review_output).
    Never raises on a degenerate review_output — returns an error row instead."""
    marker = marker_type_for(discipline)

    def err(message: str, mode=None) -> dict:
        return {
            "discipline": discipline, "mode": mode, "marker_type": marker,
            "section_markdown": None, "error": message,
        }

    if not isinstance(review_output, dict):
        return err("review_output is not an object")

    mode = review_output.get("mode")
    if mode not in MODES:
        # Echo a string mode for diagnosis; null for a non-string degenerate value.
        return err(f"unknown or missing mode {mode!r}",
                   mode=mode if isinstance(mode, str) else None)

    headline = review_output.get("headline")
    if not isinstance(headline, str) or not headline.strip():
        return err("missing or empty headline", mode=mode)

    # Fold: the mode-specific field, then adjustments[] last. Rationale folds into the
    # headline paragraph as trailing sentence(s) (no separate sub-heading) per Q43.
    source = _str_list(review_output.get(MODE_SOURCE[mode]))
    adjustments = _str_list(review_output.get("adjustments"))
    rationale = _str_list(review_output.get("rationale"))
    bullets = source + adjustments

    paragraph = headline.strip()
    if rationale:
        paragraph = paragraph + " " + " ".join(r.strip() for r in rationale)

    lines = [f"**Mode:** {mode}", "", paragraph, "", "**Refinements:**"]
    lines.extend(f"- {b}" for b in bullets)
    section_markdown = "\n".join(lines)

    return {
        "discipline": discipline, "mode": mode, "marker_type": marker,
        "section_markdown": section_markdown, "error": None,
    }


def decide(scenario: dict, discipline: str) -> dict:
    """One scenario → one emit row. The scenario injects the frozen review_output."""
    sid = scenario.get("id", "scenario")
    row = {"id": sid}
    row.update(render(scenario.get("review_output"), discipline))
    return row


def run_scenarios(scenarios: list, discipline: str) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        rows.append(decide(sc, discipline))
    return {
        "schema_version": SCHEMA_VERSION,
        "command": f"/flow:plan-{discipline}",
        "scenarios": rows,
    }


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


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(
        prog="build_plan_section.py",
        description="Deterministic /flow:plan-{discipline} Plan-section formatter (BC-12946).",
    )
    ap.add_argument("--discipline", required=True, choices=DISCIPLINES,
                    help="which plan-* discipline (selects the Q46 marker type)")
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write plan-<discipline>-emit.json into this dir (with --scenarios)")
    ap.add_argument("--decide", metavar="SCENARIO_JSON", nargs="?", const="-",
                    help="single-scenario mode: a scenario JSON file (or '-' for stdin); "
                         "prints one emit row to stdout")
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
            print(json.dumps(decide(sc, args.discipline), ensure_ascii=False))
            return 0

        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios, args.discipline)
            (out_dir / f"plan-{args.discipline}-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --decide is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
