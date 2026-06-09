#!/usr/bin/env python3
"""Deterministic import-campaign emit builder for /marketing:import-campaign
(BC-12943, ADR-028 Phase-2 Batch B — structure-first manifest-composer eval).

The hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589 runner)
drives for /marketing:import-campaign. It does NOT re-implement any compose logic:
it shells the SAME runtime entrypoint the command already shells —

  * `import_campaign.py compose --canonicals-manifest <frozen seed>`  (the PURE
    JSON-in/JSON-out composer — the import payload on stdin, the v2 manifest on
    stdout; it OWNS every input guard: slug / entity / per-record workspace /
    shape, each emitting a distinguishable `ERROR:` + rc 1)

against a FROZEN copy of the canonicals `_manifest.yaml` (the audience-tier taxonomy
the auto-classifier reads). `compose` has no clock and no injected reads — `created_at`
is an INPUT field — so it is deterministic given (payload, taxonomy); no sandbox copy
is needed (compose only READS the taxonomy). So the eval certifies the REAL runtime
path (the only eval-time difference is `--canonicals-manifest` pointing at the frozen
seed instead of the live dir, so a new taxonomy entry upstream can't drift the golden).

The structure-first seam (ADR-028 D2): this asserts the WRITTEN manifest's deterministic
STRUCTURE — the 13-key top level, schema_version 2, the scaffolded_by literal, the
input passthroughs, and the email_bison.campaigns[] records WITH their auto-classified
audience_tier objects + the derived pending_classification flag — and NOT prose.

emit artifact (`--scenarios <fixture> --out-dir <dir> [--seed-manifest <path>]`):
    import-campaign-emit.json = {
      "schema_version": 1,
      "command": "/marketing:import-campaign",
      "scenarios": [ {id, ok, manifest|null, error|null}, … ]
    }
A clean row carries the composed manifest; a rejection row (a builder-owned input
guard, rc 1) carries `ok:false` + the builder's stderr error string + a null manifest.
Same builder+harness shape as build_canonical_emit.py.

Stdlib-only per CLAUDE.md § Conventions.

Exit codes: 0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / a missing
canonicals seed / an unexpected entrypoint failure (an infra error, distinct from a
per-scenario verdict — a rejected payload is a SUCCESSFUL run that yields `ok: false`).
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

SCHEMA_VERSION = 1
COMMAND = "/marketing:import-campaign"

_HERE = Path(__file__).resolve().parent
# The REAL runtime entrypoint (sibling of this file). No logic duplicated here.
BUILDER = _HERE / "import_campaign.py"
# Frozen canonicals taxonomy seed (a verbatim copy of the live _manifest.yaml).
DEFAULT_SEED_MANIFEST = _HERE.parent / "tests" / "eval" / "import-campaign-seed" / "_manifest.yaml"

HERMETIC_DENY = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY")
GIT_ENV = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
)


class BuildError(Exception):
    """Unreadable/malformed fixture or an unexpected entrypoint failure (→ exit 2).
    Distinct from a per-scenario `ok: false` verdict (which is a successful run)."""


def _child_env() -> dict:
    env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
    for k in GIT_ENV:
        env.pop(k, None)
    return env


def decide(sc: dict, seed_manifest: Path) -> dict:
    """One scenario → one emit row. Pipes the scenario's payload to the REAL
    `import_campaign.py compose` and projects the composed manifest. A builder-owned
    input rejection (rc 1) yields ok:false + the stderr error string."""
    sid = sc.get("id", "scenario")
    if "payload" not in sc:
        raise BuildError(f"scenario {sid!r} missing required key 'payload'")
    payload = json.dumps(sc["payload"])

    proc = subprocess.run(
        [sys.executable, str(BUILDER), "compose", "--canonicals-manifest", str(seed_manifest)],
        input=payload, capture_output=True, text=True, env=_child_env(),
    )
    # 0 = composed; 1 = a builder-owned input rejection (bad slug/entity/record/shape).
    # 2 = usage (missing canonicals) and anything else is an infra error, not a verdict.
    if proc.returncode not in (0, 1):
        raise BuildError(
            f"import_campaign.py compose exited {proc.returncode} for scenario {sid!r} "
            f"(not a verdict):\n{proc.stderr.strip()}"
        )
    if proc.returncode == 1:
        return {
            "id": sid, "ok": False, "manifest": None,
            "error": (proc.stderr.strip().splitlines() or ["(no stderr)"])[0],
        }
    try:
        manifest = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise BuildError(
            f"scenario {sid!r}: compose stdout is not JSON: {exc}\nstdout: {proc.stdout!r}"
        ) from exc
    return {"id": sid, "ok": True, "manifest": manifest, "error": None}


def run_scenarios(scenarios: list, seed_manifest: Path) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        rows.append(decide(sc, seed_manifest))
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
        prog="build_import_emit.py",
        description="Deterministic import-campaign emit builder (BC-12943).",
    )
    ap.add_argument("--scenarios", required=True, help="fixture JSON (scenario list)")
    ap.add_argument("--out-dir", required=True, help="write import-campaign-emit.json into this dir")
    ap.add_argument("--seed-manifest", default=str(DEFAULT_SEED_MANIFEST),
                    help=f"frozen canonicals _manifest.yaml (default: {DEFAULT_SEED_MANIFEST})")
    args = ap.parse_args(argv)

    try:
        seed_manifest = Path(args.seed_manifest)
        if not seed_manifest.is_file():
            raise BuildError(f"seed manifest not found: {seed_manifest}")
        if not BUILDER.is_file():
            raise BuildError(f"runtime entrypoint not found: {BUILDER}")
        scenarios = _load_scenarios(Path(args.scenarios))
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        artifact = run_scenarios(scenarios, seed_manifest)
        (out_dir / "import-campaign-emit.json").write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return 0
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
