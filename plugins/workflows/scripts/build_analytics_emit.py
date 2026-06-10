#!/usr/bin/env python3
"""Deterministic analytics-dashboard emit builder for /workflows:analytics
(BC-12945, ADR-028 Phase-2 Batch D — structure-first WRAP eval).

The hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589 runner)
drives for /workflows:analytics. It does NOT re-implement any of the awk JSONL
parsing or the dashboard rendering: it shells the SAME runtime entrypoint the
command already shells —

  * `scripts/brite-analytics.sh [--since YYYY-MM-DD] [--until YYYY-MM-DD]`

— against a sandbox `$HOME` whose `.brite-plugins/telemetry/events.jsonl` is a copy
of a FROZEN events seed (HOME-override is the injection seam: brite-analytics.sh
keys off `$HOME/.brite-plugins/telemetry/events.jsonl`, NOT a flag, so we do not
modify the runtime script). So the eval certifies the REAL runtime path, not a
parallel one — the only eval-time difference is HOME points at a sandbox seed.

The structure-first seam (ADR-028 D2): this asserts the dashboard the script
renders over a KNOWN events set — the parsed Period/sessions line, the ordered
section headers, the per-command frequency rows (in the script's frequency-sorted
order), the success-rate triples, the average-duration rows, and the recent-error
rows — and the two no-output branches (no telemetry data; a filter window that
matches nothing). It does NOT assert the ASCII bar widths (cosmetic) or the `Data:`
footer (it carries the non-deterministic sandbox HOME path — dropped from the
projection, exactly as build_offer_perf_emit.py drops sandbox paths).

emit artifact (`--scenarios <fixture> --out-dir <dir> [--seed-dir <dir>]`):
    analytics-emit.json = {
      "schema_version": 1,
      "command": "/workflows:analytics",
      "scenarios": [ {id, has_data, no_match, period, sessions, sections,
                      commands, success_rates, durations, recent_errors}, … ]
    }
A no-data row (empty events file) carries has_data:false + nulls; a no-match row
(filter excludes everything) carries no_match:true + nulls. Same builder+harness
shape as build_offer_perf_emit.py.

Stdlib-only per CLAUDE.md § Conventions.

Exit codes: 0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / an
unexpected entrypoint failure (an infra error, distinct from a per-scenario verdict —
a no-data render is a SUCCESSFUL run that yields has_data:false).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCHEMA_VERSION = 1
COMMAND = "/workflows:analytics"

_HERE = Path(__file__).resolve().parent
# repo root = .../plugins/workflows/scripts → up 3. The REAL runtime entrypoint.
REPO_ROOT = _HERE.parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "brite-analytics.sh"
DEFAULT_SEED_DIR = _HERE.parent / "tests" / "eval" / "analytics-seed"

# Stripped from every child env to keep the eval provably hermetic (no API key on the
# PR path) and to defuse a leaked git env (stale-pre-push GIT_DIR, per CLAUDE.md).
HERMETIC_DENY = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY")
GIT_ENV = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
)

# Render markers (brite-analytics.sh END block).
_NO_DATA = "No telemetry data yet."
_NO_MATCH = "No matching telemetry events found."
_SECTION_HEADERS = ("Command Usage:", "Success Rate:", "Avg Duration:", "Recent Errors:")


class BuildError(Exception):
    """Unreadable/malformed fixture or an unexpected entrypoint failure (→ exit 2).
    Distinct from a per-scenario has_data:false render (a successful run)."""


def _child_env(home: Path) -> dict:
    env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
    for k in GIT_ENV:
        env.pop(k, None)
    env["HOME"] = str(home)
    return env


# ── dashboard projection (the structure the golden pins) ──────────────────────


def _parse_usage_row(line: str) -> dict | None:
    """`  <command>  <bar>  <count>` → {command, count}. The bar (cosmetic) is
    dropped — the LAST field is the count, the FIRST is the command name (commands
    carry no internal spaces). A zero-length bar row degrades to command+count."""
    parts = re.split(r"\s{2,}", line.strip())
    if len(parts) < 2:
        return None
    try:
        count = int(parts[-1])
    except ValueError:
        return None
    return {"command": parts[0], "count": count}


def _parse_success_row(line: str) -> dict | None:
    """`  <command>  <pct>% (<success>/<total>)` → {command, pct, success, total}."""
    parts = re.split(r"\s{2,}", line.strip())
    if len(parts) < 2:
        return None
    m = re.match(r"(\d+)% \((\d+)/(\d+)\)", parts[-1])
    if not m:
        return None
    return {
        "command": parts[0], "pct": int(m.group(1)),
        "success": int(m.group(2)), "total": int(m.group(3)),
    }


def _parse_duration_row(line: str) -> dict | None:
    """`  <command>  <avg>` → {command, avg} (avg is the script's format_duration)."""
    parts = re.split(r"\s{2,}", line.strip())
    if len(parts) < 2:
        return None
    return {"command": parts[0], "avg": parts[-1]}


def _parse_error_row(line: str) -> dict | None:
    """`<date> <command>  <detail>` → {date, command, detail}. The awk row is
    `date " " command "  " detail`, so date+command are the first two
    whitespace-tokens and detail is the (2-space-separated) remainder."""
    stripped = line.strip()
    m = re.match(r"(\S+)\s+(\S+)\s{2,}(.+)", stripped)
    if not m:
        return None
    return {"date": m.group(1), "command": m.group(2), "detail": m.group(3).strip()}


def _section_lines(text: str, header: str) -> list:
    """The indented rows under a `Header:` line, up to the next blank line."""
    lines = text.splitlines()
    rows: list = []
    collecting = False
    for ln in lines:
        if ln.strip() == header:
            collecting = True
            continue
        if collecting:
            if not ln.strip():
                break
            rows.append(ln)
    return rows


def _project(text: str) -> dict:
    """Reduce the rendered dashboard to its deterministic STRUCTURE.

    Drops the ASCII bar widths (cosmetic) and the `Data:`/`Privacy:` footer (the
    Data line carries the sandbox HOME path — non-deterministic)."""
    has_data = _NO_DATA not in text
    no_match = _NO_MATCH in text
    if not has_data or no_match:
        return {
            "has_data": has_data, "no_match": no_match, "period": None,
            "sessions": None, "sections": None, "commands": None,
            "success_rates": None, "durations": None, "recent_errors": None,
        }

    period = None
    sessions = None
    pm = re.search(r"^Period: (.+?) \((\d+) sessions?\)", text, re.MULTILINE)
    if pm:
        period = pm.group(1).strip()
        sessions = int(pm.group(2))

    sections = [h[:-1] for h in _SECTION_HEADERS if any(
        ln.strip() == h for ln in text.splitlines())]

    commands = [r for r in (_parse_usage_row(ln)
                for ln in _section_lines(text, "Command Usage:")) if r]
    success_rates = [r for r in (_parse_success_row(ln)
                     for ln in _section_lines(text, "Success Rate:")) if r]
    durations = [r for r in (_parse_duration_row(ln)
                 for ln in _section_lines(text, "Avg Duration:")) if r]
    recent_errors = [r for r in (_parse_error_row(ln)
                     for ln in _section_lines(text, "Recent Errors:")) if r]

    return {
        "has_data": has_data, "no_match": no_match, "period": period,
        "sessions": sessions, "sections": sections, "commands": commands,
        "success_rates": success_rates, "durations": durations,
        "recent_errors": recent_errors,
    }


# ── driving the real script ───────────────────────────────────────────────────


def decide(sc: dict, seed_dir: Path) -> dict:
    """One scenario → one emit row. Builds a sandbox $HOME with a frozen (or, for a
    no_data scenario, empty) events.jsonl, shells the REAL brite-analytics.sh with the
    scenario's --since/--until, and projects the rendered dashboard."""
    sid = sc.get("id", "scenario")
    sandbox = Path(tempfile.mkdtemp(prefix="analytics-emit-"))
    try:
        tele = sandbox / ".brite-plugins" / "telemetry"
        tele.mkdir(parents=True, exist_ok=True)
        events = tele / "events.jsonl"
        if sc.get("no_data"):
            events.write_text("", encoding="utf-8")  # empty file → "No telemetry data yet."
        else:
            shutil.copyfile(seed_dir / "events.jsonl", events)

        argv = ["bash", str(SCRIPT)]
        if sc.get("since"):
            argv += ["--since", str(sc["since"])]
        if sc.get("until"):
            argv += ["--until", str(sc["until"])]

        proc = subprocess.run(
            argv, capture_output=True, text=True, env=_child_env(sandbox),
        )
        if proc.returncode != 0:
            raise BuildError(
                f"brite-analytics.sh exited {proc.returncode} for scenario {sid!r} "
                f"(not a verdict):\n{proc.stderr.strip()}"
            )
        row = {"id": sid}
        row.update(_project(proc.stdout))
        return row
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


def run_scenarios(scenarios: list, seed_dir: Path) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        rows.append(decide(sc, seed_dir))
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


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(
        prog="build_analytics_emit.py",
        description="Deterministic /workflows:analytics dashboard emit builder (BC-12945).",
    )
    ap.add_argument("--scenarios", required=True, help="fixture JSON (scenario list)")
    ap.add_argument("--out-dir", required=True, help="write analytics-emit.json into this dir")
    ap.add_argument("--seed-dir", default=str(DEFAULT_SEED_DIR),
                    help=f"frozen events seed (default: {DEFAULT_SEED_DIR})")
    args = ap.parse_args(argv)

    try:
        seed_dir = Path(args.seed_dir)
        if not (seed_dir / "events.jsonl").is_file():
            raise BuildError(f"seed dir missing events.jsonl: {seed_dir}")
        if not SCRIPT.is_file():
            raise BuildError(f"runtime entrypoint not found: {SCRIPT}")
        scenarios = _load_scenarios(Path(args.scenarios))
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        artifact = run_scenarios(scenarios, seed_dir)
        (out_dir / "analytics-emit.json").write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return 0
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
