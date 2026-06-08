#!/usr/bin/env python3
"""Deterministic canonical-emit builder for the GTM canonicals command family —
/marketing:new-offer, new-persona, new-vertical (BC-12702 + BC-12915, ADR-028
structure-first / LLM-judged eval representative).

This is the hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589
runner) drives for any of the three canonicals bootstrap commands. It does NOT
re-implement any bootstrap/lint logic: it shells the SAME two runtime entrypoints
the commands already delegate to —

  * `canonicals_bootstrap.py --canonicals-dir <sandbox> <subcommand> …`  (the
    deterministic builder the command runs at runtime — it OWNS every input guard:
    invalid-slug / unknown-vertical / invalid-posture / invalid-status /
    duplicate-slug / invalid-alias, each emitting a distinguishable
    `{"ok": false, "error": …}`); and
  * `lint_canonicals.py --canonicals-dir <sandbox>`  (the 19-check ADR-016 contract
    — the schema source of truth: schema validity, additionalProperties:false,
    kebab, filename-stem==slug, status/posture enum, no-dup-slug, target_personas
    referential integrity).

so the eval certifies the REAL runtime path, not a parallel one (the BC-12701
refinement-#3 single-shared-entrypoint discipline — satisfied for free because the
commands already delegate to `canonicals_bootstrap.py` and the only difference at
eval time is `--canonicals-dir` pointing at a sandbox copy of a FROZEN fixture seed
instead of the live `data/canonicals/`).

The structure-first seam (ADR-028 D2): this asserts the artifact's deterministic
STRUCTURE — that the WRITTEN canonical (seed + the new entry) passes `lint_canonicals`
and the new entry's deterministic fields match the inputs — and explicitly NOT the
operator/LLM-chosen content (WHICH offer/persona/vertical, the handbook-PR-draft prose).

Generalized from BC-12702's `build_offer_emit.py` at the Rule-of-Three point (the 2nd
and 3rd consumers — new-persona + new-vertical — arrived): one parameterized builder
with a per-subcommand SPEC (the flags it maps, the result fields it projects, the
artifact name, the command string). The `offer` artifact is byte-identical to the
BC-12702 output (`offer-emit.json`, entry key `appended_offer`) so its merged golden
is untouched.

emit artifact (`--subcommand <s> --scenarios <fixture> --out-dir <dir> [--seed-dir <dir>]`):
    <subcommand>-emit.json = {
      "schema_version": 1,
      "command": "/marketing:new-<subcommand>",
      "scenarios": [ {id, ok, action, <entry_key>|null, error|null, lint|null}, … ]
    }
The new entry is projected to the SPEC's deterministic result fields (e.g. offer →
slug/display/status/posture); NOT `yaml_path` (the sandbox path is non-deterministic)
and NOT `handbook_draft` (that prose is the LLM/template surface we do not assert).
`lint.exit_code` is `lint_canonicals`'s exit over the mutated sandbox (0 for a clean
write); a rejection row carries `lint: null` (no write happened).

Stdlib-only per CLAUDE.md § Conventions; same builder+harness shape as
build_campaign_payload.py / build_manifest.py.

Exit codes: 0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / an
unexpected entrypoint failure (an infra error, distinct from any per-scenario verdict
— a rejected input is a SUCCESSFUL run that yields `ok: false`).
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

_HERE = Path(__file__).resolve().parent
# The two REAL runtime entrypoints (siblings of this file). No logic is duplicated
# here — we shell these exactly as the commands do.
BOOTSTRAP = _HERE / "canonicals_bootstrap.py"
LINT = _HERE / "lint_canonicals.py"
# Frozen fixture canonicals seed (plugin-local, SHARED across the three subcommands).
DEFAULT_SEED_DIR = _HERE.parent / "tests" / "eval" / "new-offer-seed"

# Per-subcommand spec. `required`/`optional` are the canonicals_bootstrap `<sub>` flags
# (scenario key -> `--<key-with-dashes>`); `project` are the deterministic result fields
# the new entry is reduced to; `entry_key`/`artifact`/`command` shape the emit artifact.
SPECS = {
    "offer": {
        "command": "/marketing:new-offer",
        "artifact": "offer-emit.json",
        "entry_key": "appended_offer",
        "required": ("vertical", "slug", "display", "posture"),
        "optional": ("status",),
        "project": ("slug", "display", "status", "posture"),
    },
    "persona": {
        "command": "/marketing:new-persona",
        "artifact": "persona-emit.json",
        "entry_key": "appended_persona",
        "required": ("vertical", "slug", "display"),
        "optional": ("titles",),
        "project": ("slug", "display", "titles"),
    },
    "vertical": {
        "command": "/marketing:new-vertical",
        "artifact": "vertical-emit.json",
        "entry_key": "appended_vertical",
        "required": ("slug", "display"),
        "optional": ("aliases", "playbook_path"),
        "project": ("slug", "display"),
    },
}

# Stripped from every child env to keep the eval provably hermetic (DP2-4: no API key
# on the PR path) and to defuse a leaked git env (stale-pre-push GIT_DIR, per CLAUDE.md).
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


def _flag(key: str) -> str:
    return "--" + key.replace("_", "-")


def _run_bootstrap(sandbox: Path, subcommand: str, spec: dict, sc: dict) -> dict:
    """Shell the REAL `canonicals_bootstrap.py <sub>` over the sandbox; return its parsed
    `{ok, …}` envelope. Raises BuildError on a non-verdict (usage/crash) result."""
    argv = [sys.executable, str(BOOTSTRAP), "--canonicals-dir", str(sandbox), subcommand]
    for key in spec["required"] + spec["optional"]:
        if sc.get(key) is not None:
            argv += [_flag(key), str(sc[key])]
    proc = subprocess.run(argv, capture_output=True, text=True, env=_child_env())
    # 0 = created, 1 = validation rejection (both print one JSON envelope to stdout).
    # Anything else (2 = argparse/usage, or a crash) is an infra error, not a verdict.
    if proc.returncode not in (0, 1):
        raise BuildError(
            f"canonicals_bootstrap {subcommand} exited {proc.returncode} for scenario "
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


def decide(subcommand: str, sc: dict, seed_dir: Path) -> dict:
    """One scenario → one emit row. Copies the frozen seed into an isolated sandbox,
    drives the REAL bootstrap entrypoint, and (only on a successful write) the REAL lint.
    The projection drops the non-deterministic sandbox path + the handbook-draft prose;
    what remains is the deterministic STRUCTURE the golden pins."""
    spec = SPECS[subcommand]
    for k in spec["required"]:
        if k not in sc:
            raise BuildError(f"scenario {sc.get('id')!r} missing required key {k!r}")

    sandbox = Path(tempfile.mkdtemp(prefix="canonical-emit-"))
    try:
        # Copy the frozen seed canonicals into the sandbox (the controlled pre-existing
        # state the guards run against). dirs_exist_ok so mkdtemp's empty dir is fine.
        shutil.copytree(seed_dir, sandbox, dirs_exist_ok=True)
        env = _run_bootstrap(sandbox, subcommand, spec, sc)
        if env.get("ok"):
            lint_exit = _run_lint(sandbox)
            return {
                "id": sc.get("id", "scenario"),
                "ok": True,
                "action": env.get("action"),
                spec["entry_key"]: {f: env.get(f) for f in spec["project"]},
                "error": None,
                "lint": {"exit_code": lint_exit},
            }
        return {
            "id": sc.get("id", "scenario"),
            "ok": False,
            "action": None,
            spec["entry_key"]: None,
            "error": env.get("error"),
            "lint": None,
        }
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


def run_scenarios(subcommand: str, scenarios: list, seed_dir: Path) -> dict:
    """Map each scenario → a decision row, assembling the emit-artifact matrix."""
    spec = SPECS[subcommand]
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        rows.append(decide(subcommand, sc, seed_dir))
    return {
        "schema_version": SCHEMA_VERSION,
        "command": spec["command"],
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
        prog="build_canonical_emit.py",
        description="Deterministic canonical-emit builder (BC-12702 / BC-12915).",
    )
    ap.add_argument("--subcommand", required=True, choices=sorted(SPECS),
                    help="which canonicals_bootstrap subcommand to drive")
    ap.add_argument("--scenarios", required=True, help="fixture JSON (scenario list)")
    ap.add_argument("--out-dir", required=True, help="write <subcommand>-emit.json into this dir")
    ap.add_argument("--seed-dir", default=str(DEFAULT_SEED_DIR),
                    help="frozen fixture canonicals dir copied into each sandbox "
                         f"(default: {DEFAULT_SEED_DIR})")
    args = ap.parse_args(argv)

    try:
        spec = SPECS[args.subcommand]
        seed_dir = Path(args.seed_dir)
        if not (seed_dir / "_manifest.yaml").is_file():
            raise BuildError(f"seed dir missing _manifest.yaml: {seed_dir}")
        for entrypoint in (BOOTSTRAP, LINT):
            if not entrypoint.is_file():
                raise BuildError(f"runtime entrypoint not found: {entrypoint}")
        scenarios = _load_scenarios(Path(args.scenarios))
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        artifact = run_scenarios(args.subcommand, scenarios, seed_dir)
        (out_dir / spec["artifact"]).write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return 0
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
