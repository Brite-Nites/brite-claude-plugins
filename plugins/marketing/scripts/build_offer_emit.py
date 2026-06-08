#!/usr/bin/env python3
"""Deterministic offer-canonical emit builder for /marketing:new-offer (BC-12702,
ADR-028 eval #3 — the STRUCTURE-FIRST / LLM-judged representative).

This is the hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589
runner) drives. It does NOT re-implement any offer logic: it shells the SAME two
runtime entrypoints the command already delegates to —

  * `canonicals_bootstrap.py --canonicals-dir <sandbox> offer …`  (the deterministic
    builder /marketing:new-offer runs at runtime — it OWNS every input guard:
    invalid-slug / unknown-vertical / invalid-posture / invalid-status /
    duplicate-slug, each emitting a distinguishable `{"ok": false, "error": …}`); and
  * `lint_canonicals.py --canonicals-dir <sandbox>`  (the 19-check ADR-016 contract —
    the schema source of truth: schema validity, additionalProperties:false, kebab,
    filename-stem==slug, status/posture enum, no-dup-slug, AND target_personas
    referential integrity).

so the eval certifies the REAL runtime path, not a parallel one (the BC-12701
refinement-#3 single-shared-entrypoint discipline — satisfied here for free because
`new-offer` already delegates to `canonicals_bootstrap.py` and the only difference at
eval time is `--canonicals-dir` pointing at a sandbox copy of a FROZEN fixture seed
instead of the live `data/canonicals/`).

The structure-first seam (ADR-028 D2): this asserts the artifact's deterministic
STRUCTURE — that the WRITTEN canonical (seed + appended offer) passes `lint_canonicals`
and the appended entry's slug/display/status/posture match the inputs — and explicitly
NOT the operator/LLM-chosen content (WHICH offer/posture/personas, the handbook-PR-draft
prose). `target_personas` referential integrity is asserted at the FILE level (it
executes on the seed's pre-existing offer; the appended entry carries none — `new-offer`
has no `--target-personas` flag, so check #18 is vacuous for it).

Why a sandbox copy of a FROZEN seed (not the live canonicals): `new-offer` WRITES
(appends), and its guards need controlled pre-existing state — `duplicate_slug` needs a
known colliding offer slug, `unknown_vertical` a known vertical set. Seeding from the
live dir would make the golden drift the day someone adds a real vertical/offer AND
would be a hermeticity risk. (This is a deliberate divergence from `PlanCampaignAdapter`,
which points `--canonicals-dir` at the LIVE dir — fine there because plan-campaign only
READS canonicals.)

emit artifact (`--scenarios <fixture> --out-dir <dir>` [`--seed-dir <dir>`]):
    offer-emit.json = {
      "schema_version": 1,
      "command": "/marketing:new-offer",
      "scenarios": [ {id, ok, action, appended_offer|null, error|null, lint|null}, … ]
    }
The eval golden-compares a structural projection of this matrix; the per-scenario
`appended_offer` is the appended entry projected to {slug, display, status, posture}
(NOT `yaml_path` — the sandbox path is non-deterministic — and NOT `handbook_draft` —
that prose is the LLM/template surface we explicitly do not assert). `lint.exit_code`
is `lint_canonicals`'s exit over the mutated sandbox (0 for a clean write); a rejection
row carries `lint: null` (no write happened, so there is no structural claim to make).

Stdlib-only per CLAUDE.md § Conventions; same builder+harness shape as
build_campaign_payload.py / build_manifest.py.

Exit codes: 0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / an
unexpected entrypoint failure (an infra error, distinct from any per-scenario verdict —
a rejected input is a SUCCESSFUL run that yields `ok: false`).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCHEMA_VERSION = 1
COMMAND = "/marketing:new-offer"

_HERE = Path(__file__).resolve().parent
# The two REAL runtime entrypoints (siblings of this file). No logic is duplicated
# here — we shell these exactly as the command does.
BOOTSTRAP = _HERE / "canonicals_bootstrap.py"
LINT = _HERE / "lint_canonicals.py"
# Frozen fixture canonicals seed (plugin-local). Copied into a per-scenario sandbox.
DEFAULT_SEED_DIR = _HERE.parent / "tests" / "eval" / "new-offer-seed"

# Stripped from every child env to keep the eval provably hermetic (DP2-4: no API key
# on the PR path) and to defuse a leaked git env (stale-pre-push GIT_DIR, per CLAUDE.md).
HERMETIC_DENY = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY")
GIT_ENV = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
)

# Scenario keys that map to canonicals_bootstrap `offer` flags. `status` is optional
# (the builder defaults it to "draft"); the other four are required by the command.
_REQUIRED_KEYS = ("vertical", "slug", "display", "posture")


class BuildError(Exception):
    """Unreadable/malformed fixture or an unexpected entrypoint failure (→ exit 2).
    Distinct from a per-scenario `ok: false` verdict (which is a successful run)."""


def _child_env() -> dict:
    env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
    for k in GIT_ENV:
        env.pop(k, None)
    return env


def _run_bootstrap(sandbox: Path, sc: dict) -> dict:
    """Shell the REAL `canonicals_bootstrap.py … offer` over the sandbox; return its
    parsed `{ok, …}` envelope. Raises BuildError on a non-verdict (usage/crash) result."""
    argv = [
        sys.executable, str(BOOTSTRAP),
        "--canonicals-dir", str(sandbox),
        "offer",
        "--vertical", str(sc["vertical"]),
        "--slug", str(sc["slug"]),
        "--display", str(sc["display"]),
        "--posture", str(sc["posture"]),
    ]
    if sc.get("status") is not None:
        argv += ["--status", str(sc["status"])]
    proc = subprocess.run(argv, capture_output=True, text=True, env=_child_env())
    # 0 = created, 1 = validation rejection (both print one JSON envelope to stdout).
    # Anything else (2 = argparse/usage, or a crash) is an infra error, not a verdict.
    if proc.returncode not in (0, 1):
        raise BuildError(
            f"canonicals_bootstrap exited {proc.returncode} for scenario "
            f"{sc.get('id')!r} (not a verdict):\n{proc.stderr.strip()}"
        )
    try:
        env = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise BuildError(
            f"canonicals_bootstrap stdout is not JSON for scenario "
            f"{sc.get('id')!r}: {exc}\nstdout: {proc.stdout!r}"
        ) from exc
    if not isinstance(env, dict) or "ok" not in env:
        raise BuildError(
            f"canonicals_bootstrap envelope missing 'ok' for scenario "
            f"{sc.get('id')!r}: {env!r}"
        )
    return env


def _run_lint(sandbox: Path) -> int:
    """Shell the REAL `lint_canonicals.py` over the mutated sandbox; return its exit
    code (0 = the full 19-check ADR-016 contract holds)."""
    proc = subprocess.run(
        [sys.executable, str(LINT), "--canonicals-dir", str(sandbox)],
        capture_output=True, text=True, env=_child_env(),
    )
    return proc.returncode


def decide(sc: dict, seed_dir: Path) -> dict:
    """One scenario → one emit row. Copies the frozen seed into an isolated sandbox,
    drives the REAL bootstrap entrypoint, and (only on a successful write) the REAL
    lint. The projection drops the non-deterministic sandbox path + the handbook-draft
    prose; what remains is the deterministic STRUCTURE the golden pins."""
    for k in _REQUIRED_KEYS:
        if k not in sc:
            raise BuildError(f"scenario {sc.get('id')!r} missing required key {k!r}")

    sandbox = Path(tempfile.mkdtemp(prefix="offer-emit-"))
    try:
        # Copy the frozen seed canonicals into the sandbox (the controlled pre-existing
        # state the guards run against). dirs_exist_ok so mkdtemp's empty dir is fine.
        shutil.copytree(seed_dir, sandbox, dirs_exist_ok=True)
        env = _run_bootstrap(sandbox, sc)
        if env.get("ok"):
            lint_exit = _run_lint(sandbox)
            return {
                "id": sc.get("id", "scenario"),
                "ok": True,
                "action": env.get("action"),
                "appended_offer": {
                    "slug": env.get("slug"),
                    "display": env.get("display"),
                    "status": env.get("status"),
                    "posture": env.get("posture"),
                },
                "error": None,
                "lint": {"exit_code": lint_exit},
            }
        return {
            "id": sc.get("id", "scenario"),
            "ok": False,
            "action": None,
            "appended_offer": None,
            "error": env.get("error"),
            "lint": None,
        }
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


def run_scenarios(scenarios: list, seed_dir: Path) -> dict:
    """Map each scenario → a decision row, assembling the emit-artifact matrix."""
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        rows.append(decide(sc, seed_dir))
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
    scenarios = data.get("scenarios") if isinstance(data, dict) else data
    if not isinstance(scenarios, list):
        raise BuildError("fixture must be a list of scenarios or {'scenarios': [...]}")
    return scenarios


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="build_offer_emit.py",
        description="Deterministic offer-canonical emit builder (BC-12702).",
    )
    ap.add_argument("--scenarios", required=True, help="fixture JSON (scenario list)")
    ap.add_argument("--out-dir", required=True, help="write offer-emit.json into this dir")
    ap.add_argument("--seed-dir", default=str(DEFAULT_SEED_DIR),
                    help="frozen fixture canonicals dir copied into each sandbox "
                         f"(default: {DEFAULT_SEED_DIR})")
    args = ap.parse_args(argv)

    try:
        seed_dir = Path(args.seed_dir)
        if not (seed_dir / "_manifest.yaml").is_file():
            raise BuildError(f"seed dir missing _manifest.yaml: {seed_dir}")
        for entrypoint in (BOOTSTRAP, LINT):
            if not entrypoint.is_file():
                raise BuildError(f"runtime entrypoint not found: {entrypoint}")
        scenarios = _load_scenarios(Path(args.scenarios))
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        artifact = run_scenarios(scenarios, seed_dir)
        (out_dir / "offer-emit.json").write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return 0
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
