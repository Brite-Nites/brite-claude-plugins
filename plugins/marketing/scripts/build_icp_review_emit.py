#!/usr/bin/env python3
"""Deterministic icp-refinement-review emit builder for /marketing:icp-refinement-review
(BC-12943, ADR-028 Phase-2 Batch B — structure-first review-loop eval).

The hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589 runner)
drives for /marketing:icp-refinement-review. It does NOT re-implement any logic: it
shells the SAME runtime entrypoints the command already shells, per scenario, against
a sandbox copy of a FROZEN discoveries-tree seed —

  * `icp_refinement_review.py --campaigns-dir <sandbox> scan`                  (Step 0)
  * `icp_refinement_review.py --campaigns-dir <sandbox> apply --decision-map …` (Step 2)
  * `icp_refinement_review.py --campaigns-dir <sandbox> emit-handbook …`        (Step 3)
  * `lint_discoveries.py --campaigns-dir <sandbox>`  (the command's Validation §)

`apply` MUTATES discoveries.json IN PLACE under `--campaigns-dir`, so it is fully
hermetic when that dir is a per-scenario sandbox copy (no inject-to-defeat-now() — the
helper has no clock; the frozen seed IS the input). The structure-first anchor (ADR-028
D2): the MUTATED discoveries.json still passes `lint_discoveries.py` (exit 0), AND the
apply count summary + the per-signal promotion_status flips + the emit-handbook
promoted-blob set match — NOT prose.

emit artifact (`--scenarios <fixture> --out-dir <dir> [--seed-dir <dir>]`):
    icp-review-emit.json = {
      "schema_version": 1,
      "command": "/marketing:icp-refinement-review",
      "scenarios": [ {id, ok, counts|null, scan_total_pending, mutated_statuses|null,
                      lint_exit_code|null, emit_blob_count|null, emit_verticals|null,
                      error|null}, … ]
    }
A clean row carries the apply/scan/emit/lint projection; a rejection row (a builder-owned
decision-map guard, exit 1 data-error or exit 2 usage-error) carries `ok:false` + the
builder's error string + nulls for the apply-side fields (scan still ran). Same
builder+harness shape as build_canonical_emit.py.

Stdlib-only per CLAUDE.md § Conventions.

Exit codes: 0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / an unexpected
entrypoint failure (an infra error, distinct from a per-scenario verdict — a rejected
decision-map is a SUCCESSFUL run that yields `ok: false`).
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
COMMAND = "/marketing:icp-refinement-review"

_HERE = Path(__file__).resolve().parent
BUILDER = _HERE / "icp_refinement_review.py"
LINT = _HERE / "lint_discoveries.py"
DEFAULT_SEED_DIR = _HERE.parent / "tests" / "eval" / "icp-refinement-review-seed"

HERMETIC_DENY = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY")
GIT_ENV = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
)

# emit-handbook prints one blob per PROMOTED decision, each headed
# "### ICP refinement — <vertical> / <persona>". Anchor the vertical on the " / "
# separator (non-greedy) rather than \S+, so a future multi-token vertical can't be
# silently truncated at the first space.
_EMIT_HEADER_RE = re.compile(r"^### ICP refinement — (?P<vertical>.+?) / ")


class BuildError(Exception):
    """Unreadable/malformed fixture or an unexpected entrypoint failure (→ exit 2).
    Distinct from a per-scenario `ok: false` verdict (which is a successful run)."""


def _child_env() -> dict:
    env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
    for k in GIT_ENV:
        env.pop(k, None)
    return env


def _run(argv: list) -> subprocess.CompletedProcess:
    return subprocess.run(argv, capture_output=True, text=True, env=_child_env())


def _scan_total_pending(sandbox: Path, sid: str) -> int:
    proc = _run([sys.executable, str(BUILDER), "--campaigns-dir", str(sandbox), "scan"])
    if proc.returncode != 0:
        raise BuildError(f"scenario {sid!r}: scan exited {proc.returncode} (infra):\n{proc.stderr.strip()}")
    try:
        return int(json.loads(proc.stdout).get("total_pending"))
    except (json.JSONDecodeError, TypeError, ValueError) as exc:
        raise BuildError(f"scenario {sid!r}: scan stdout not parseable: {exc}\n{proc.stdout!r}") from exc


def _read_mutated_statuses(sandbox: Path, decisions: dict, sid: str) -> dict:
    """For each decision-map signal_id (<relpath>::<idx>), the promotion_status read
    back from the mutated file (absent → 'pending'). Keys iterated SORTED for a stable
    golden, regardless of fixture decision-map order."""
    out: dict = {}
    for signal_id in sorted(decisions):
        rel, _, idx = signal_id.rpartition("::")
        try:
            data = json.loads((sandbox / rel).read_text(encoding="utf-8"))
            sig = data["signals"][int(idx)]
        except (OSError, json.JSONDecodeError, KeyError, IndexError, ValueError) as exc:
            raise BuildError(f"scenario {sid!r}: cannot read back signal {signal_id!r}: {exc}") from exc
        out[signal_id] = sig.get("promotion_status", "pending")
    return out


def _emit_projection(sandbox: Path, dm_path: Path, sid: str) -> tuple[int, list]:
    """(blob_count, sorted unique verticals) from emit-handbook stdout."""
    proc = _run([sys.executable, str(BUILDER), "--campaigns-dir", str(sandbox),
                 "emit-handbook", "--decision-map", str(dm_path)])
    if proc.returncode != 0:
        raise BuildError(f"scenario {sid!r}: emit-handbook exited {proc.returncode} (infra):\n{proc.stderr.strip()}")
    verticals = []
    count = 0
    for line in proc.stdout.splitlines():
        m = _EMIT_HEADER_RE.match(line)
        if m:
            count += 1
            verticals.append(m.group("vertical"))
    return count, sorted(set(verticals))


def _lint_exit(sandbox: Path) -> int:
    return _run([sys.executable, str(LINT), "--campaigns-dir", str(sandbox)]).returncode


def decide(sc: dict, seed_dir: Path) -> dict:
    """One scenario → one emit row. Copies the frozen seed into an isolated sandbox,
    drives scan → apply → (on success) emit-handbook + lint over the MUTATED tree."""
    sid = sc.get("id", "scenario")
    if "decisions" not in sc or not isinstance(sc["decisions"], dict):
        raise BuildError(f"scenario {sid!r} missing a 'decisions' object")

    sandbox = Path(tempfile.mkdtemp(prefix="icp-review-emit-"))
    try:
        shutil.copytree(seed_dir, sandbox, dirs_exist_ok=True)
        dm_path = sandbox / "_decision.json"
        dm_path.write_text(json.dumps(sc["decisions"]), encoding="utf-8")

        scan_total = _scan_total_pending(sandbox, sid)

        apply_proc = _run([sys.executable, str(BUILDER), "--campaigns-dir", str(sandbox),
                           "apply", "--decision-map", str(dm_path)])
        # 0 = applied; 1 = data error; 2 = usage error (both builder-owned rejections).
        if apply_proc.returncode not in (0, 1, 2):
            raise BuildError(
                f"scenario {sid!r}: apply exited {apply_proc.returncode} (infra):\n{apply_proc.stderr.strip()}"
            )
        if apply_proc.returncode != 0:
            return {
                "id": sid, "ok": False, "counts": None, "scan_total_pending": scan_total,
                "mutated_statuses": None, "lint_exit_code": None,
                "emit_blob_count": None, "emit_verticals": None,
                "error": (apply_proc.stderr.strip().splitlines() or ["(no stderr)"])[0],
            }

        try:
            counts = json.loads(apply_proc.stdout)
        except json.JSONDecodeError as exc:
            raise BuildError(f"scenario {sid!r}: apply stdout not JSON: {exc}\n{apply_proc.stdout!r}") from exc
        mutated = _read_mutated_statuses(sandbox, sc["decisions"], sid)
        blob_count, verticals = _emit_projection(sandbox, dm_path, sid)
        lint_exit = _lint_exit(sandbox)
        return {
            "id": sid, "ok": True, "counts": counts, "scan_total_pending": scan_total,
            "mutated_statuses": mutated, "lint_exit_code": lint_exit,
            "emit_blob_count": blob_count, "emit_verticals": verticals, "error": None,
        }
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
        prog="build_icp_review_emit.py",
        description="Deterministic icp-refinement-review emit builder (BC-12943).",
    )
    ap.add_argument("--scenarios", required=True, help="fixture JSON (scenario list)")
    ap.add_argument("--out-dir", required=True, help="write icp-review-emit.json into this dir")
    ap.add_argument("--seed-dir", default=str(DEFAULT_SEED_DIR),
                    help=f"frozen discoveries-tree seed (default: {DEFAULT_SEED_DIR})")
    args = ap.parse_args(argv)

    try:
        seed_dir = Path(args.seed_dir)
        if not seed_dir.is_dir():
            raise BuildError(f"seed dir not found: {seed_dir}")
        for entrypoint in (BUILDER, LINT):
            if not entrypoint.is_file():
                raise BuildError(f"runtime entrypoint not found: {entrypoint}")
        scenarios = _load_scenarios(Path(args.scenarios))
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        artifact = run_scenarios(scenarios, seed_dir)
        (out_dir / "icp-review-emit.json").write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return 0
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
