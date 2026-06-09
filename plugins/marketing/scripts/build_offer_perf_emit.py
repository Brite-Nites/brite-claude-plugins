#!/usr/bin/env python3
"""Deterministic offer-performance emit builder for /marketing:offer-performance
(BC-12943, ADR-028 Phase-2 Batch B — structure-first report-builder eval).

The hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589 runner)
drives for /marketing:offer-performance. It does NOT re-implement any synthesis
logic: it shells the SAME runtime entrypoint the command already shells —

  * `offer_performance.py --campaigns-dir <sandbox> --canonicals-dir <sandbox>
     --eb-json <sandbox> --sf-json <sandbox> --generated-at <pinned> …`

— against a sandbox copy of a FROZEN seed (a campaigns tree + canonicals) with the
EB/SF stats INJECTED per scenario as pre-fetched JSON (the same `--eb-json`/`--sf-json`
seam the command's Phase-3/4 MCP reads write to). `--generated-at` is pinned so the
one clock call (`datetime.now()` in render_performance) is unreachable. So the eval
certifies the REAL runtime path, not a parallel one (the single-shared-entrypoint
discipline: the only eval-time difference is the dirs/JSON point at a sandbox seed).

The structure-first seam (ADR-028 D2): this asserts the WRITTEN performance.md's
deterministic STRUCTURE — the frontmatter, the ordered section headers, the degraded
banners, the retirement signal, and the fully-parsed per-version metrics table (every
injected stat rendered through the builder's formatters) — and NOT prose.

emit artifact (`--scenarios <fixture> --out-dir <dir> [--seed-dir <dir>]`):
    offer-perf-emit.json = {
      "schema_version": 1,
      "command": "/marketing:offer-performance",
      "scenarios": [ {id, ok, frontmatter|null, sections|null, banners|null,
                      retirement_signal|null, versions|null, error|null}, … ]
    }
A clean row carries the projected report; a rejection row (an invalid offer slug →
the canonicals guard, exit 1) carries `ok:false` + the builder's stderr error string
and nulls for the report fields. Same builder+harness shape as build_canonical_emit.py.

Stdlib-only per CLAUDE.md § Conventions.

Exit codes: 0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / an
unexpected entrypoint failure (an infra error, distinct from a per-scenario verdict —
a rejected slug is a SUCCESSFUL run that yields `ok: false`).
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
COMMAND = "/marketing:offer-performance"
# Pinned so the builder's only clock call (datetime.now in render_performance) is
# unreachable — every scenario gets a deterministic frontmatter generated_at.
GENERATED_AT = "2026-05-26T12:00:00Z"
COMMAND_VERSION = "marketing@eval"

_HERE = Path(__file__).resolve().parent
# The REAL runtime entrypoint (sibling of this file). No logic duplicated here.
BUILDER = _HERE / "offer_performance.py"
DEFAULT_SEED_DIR = _HERE.parent / "tests" / "eval" / "offer-performance-seed"

# Stripped from every child env to keep the eval provably hermetic (DP2-4: no API key
# on the PR path) and to defuse a leaked git env (stale-pre-push GIT_DIR, per CLAUDE.md).
HERMETIC_DENY = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY")
GIT_ENV = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
)

# Degraded-banner markers + the retirement signal (rendered by offer_performance.py).
_EB_BANNER = "⚠ EB stats degraded"
_SF_BANNER = "⚠ SF rollup degraded"
_RETIREMENT = "RETIREMENT CANDIDATE"

# Per-version metrics table columns, in render order (offer_performance.render_performance).
_TABLE_COLS = (
    "version", "slug", "reply_rate", "meeting_rate", "sent", "replies",
    "amount_all", "amount_won", "leads", "launched",
)


class BuildError(Exception):
    """Unreadable/malformed fixture or an unexpected entrypoint failure (→ exit 2).
    Distinct from a per-scenario `ok: false` verdict (which is a successful run)."""


def _child_env() -> dict:
    env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
    for k in GIT_ENV:
        env.pop(k, None)
    return env


# ── markdown projection (the structure the golden pins) ───────────────────────


def _parse_frontmatter(text: str) -> dict:
    """The `---`-delimited frontmatter as a dict. schema_version + versions_analyzed
    are coerced to int; everything else stays a string (deterministic given the pinned
    inputs + --generated-at)."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise BuildError("performance.md has no frontmatter block")
    fm: dict = {}
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        fm[key.strip()] = value.strip()
    if not closed:
        raise BuildError("performance.md frontmatter block is unclosed (missing terminating '---')")
    for k in ("schema_version", "versions_analyzed"):
        if k in fm:
            try:
                fm[k] = int(fm[k])
            except ValueError:
                pass
    return fm


def _section_titles(text: str) -> list:
    """The ordered list of `## ` section header titles (text after `## `)."""
    return [ln[3:].strip() for ln in text.splitlines() if ln.startswith("## ")]


def _parse_version_table(text: str) -> list:
    """Parse Section 1's per-version metrics table → a list of row dicts (every cell,
    as rendered through the builder's fmt_pct/fmt_money/fmt_int). Locks that each
    injected stat flows through to the table — the load-bearing structure-first proof."""
    lines = text.splitlines()
    rows: list = []
    in_table = False
    for ln in lines:
        if ln.startswith("| Version |"):  # header row → next is the |---| separator
            in_table = True
            continue
        if not in_table:
            continue
        if ln.startswith("|---") or ln.startswith("| ---"):
            continue
        if not ln.startswith("|"):  # blank line / next section ends the table
            break
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        if len(cells) != len(_TABLE_COLS):
            raise BuildError(f"unexpected metrics-table row shape: {ln!r}")
        rows.append(dict(zip(_TABLE_COLS, cells)))
    return rows


def _project(text: str) -> dict:
    """Reduce a written performance.md to its deterministic STRUCTURE."""
    return {
        "frontmatter": _parse_frontmatter(text),
        "sections": _section_titles(text),
        "banners": {
            "eb_degraded": _EB_BANNER in text,
            "sf_degraded": _SF_BANNER in text,
        },
        "retirement_signal": _RETIREMENT in text,
        "versions": _parse_version_table(text),
    }


# ── driving the real builder ──────────────────────────────────────────────────


def _build_argv(sc: dict, campaigns: Path, canonicals: Path,
                eb_json: Path | None, sf_json: Path | None) -> list:
    argv = [
        sys.executable, str(BUILDER),
        "--offer-slug", str(sc["offer_slug"]),
        "--entity", str(sc["entity"]),
        "--campaigns-dir", str(campaigns),
        "--canonicals-dir", str(canonicals),
        "--command-version", COMMAND_VERSION,
        "--generated-at", GENERATED_AT,
    ]
    if sc.get("version") is not None:
        argv += ["--version", str(sc["version"])]
    if eb_json is not None:
        argv += ["--eb-json", str(eb_json)]
    if sc.get("eb_status"):
        argv += ["--eb-status", str(sc["eb_status"])]
    if sf_json is not None:
        argv += ["--sf-json", str(sf_json)]
    if sc.get("sf_status"):
        argv += ["--sf-status", str(sc["sf_status"])]
    if sc.get("degradation_threshold") is not None:
        argv += ["--degradation-threshold", str(sc["degradation_threshold"])]
    return argv


def _artifact_path(sc: dict, campaigns: Path) -> Path:
    """Where offer_performance.py wrote the report: a per-version file when --version
    is pinned, else the multi-version rollup."""
    base = campaigns / str(sc["entity"]) / "offers" / str(sc["offer_slug"])
    if sc.get("version") is not None:
        return base / f"v{sc['version']}" / "performance.md"
    return base / "performance.md"


def decide(sc: dict, seed_dir: Path) -> dict:
    """One scenario → one emit row. Copies the frozen seed into an isolated sandbox,
    injects the scenario's EB/SF JSON, drives the REAL offer_performance.py, and (on a
    clean write) projects the written report. A rejected slug (exit 1) yields ok:false."""
    sid = sc.get("id", "scenario")
    if "offer_slug" not in sc or "entity" not in sc:
        raise BuildError(f"scenario {sid!r} missing required key 'offer_slug'/'entity'")

    sandbox = Path(tempfile.mkdtemp(prefix="offer-perf-emit-"))
    try:
        campaigns = sandbox / "campaigns"
        canonicals = sandbox / "canonicals"
        shutil.copytree(seed_dir / "campaigns", campaigns)
        shutil.copytree(seed_dir / "canonicals", canonicals)

        eb_json = None
        if sc.get("eb") is not None:
            eb_json = sandbox / "eb.json"
            eb_json.write_text(json.dumps({"campaigns": sc["eb"]}), encoding="utf-8")
        sf_json = None
        if sc.get("sf") is not None:
            sf_json = sandbox / "sf.json"
            sf_json.write_text(json.dumps({"records": sc["sf"]}), encoding="utf-8")

        proc = subprocess.run(
            _build_argv(sc, campaigns, canonicals, eb_json, sf_json),
            capture_output=True, text=True, env=_child_env(),
        )
        # 0 = wrote (or graceful empty); 1 = a builder-owned rejection (invalid slug).
        # Anything else (2 = anti-creep/usage, or a crash) is an infra error.
        if proc.returncode not in (0, 1):
            raise BuildError(
                f"offer_performance.py exited {proc.returncode} for scenario {sid!r} "
                f"(not a verdict):\n{proc.stderr.strip()}"
            )
        if proc.returncode == 1:
            return {
                "id": sid, "ok": False, "frontmatter": None, "sections": None,
                "banners": None, "retirement_signal": None, "versions": None,
                "error": (proc.stderr.strip().splitlines() or ["(no stderr)"])[0],
            }

        art = _artifact_path(sc, campaigns)
        if not art.is_file():
            raise BuildError(
                f"scenario {sid!r}: expected report not written: "
                f"{art.relative_to(sandbox)} (stdout: {proc.stdout.strip()!r})"
            )
        row = {"id": sid, "ok": True, "error": None}
        row.update(_project(art.read_text(encoding="utf-8")))
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
        prog="build_offer_perf_emit.py",
        description="Deterministic offer-performance emit builder (BC-12943).",
    )
    ap.add_argument("--scenarios", required=True, help="fixture JSON (scenario list)")
    ap.add_argument("--out-dir", required=True, help="write offer-perf-emit.json into this dir")
    ap.add_argument("--seed-dir", default=str(DEFAULT_SEED_DIR),
                    help=f"frozen campaigns+canonicals seed (default: {DEFAULT_SEED_DIR})")
    args = ap.parse_args(argv)

    try:
        seed_dir = Path(args.seed_dir)
        if not (seed_dir / "canonicals" / "_manifest.yaml").is_file():
            raise BuildError(f"seed dir missing canonicals/_manifest.yaml: {seed_dir}")
        if not BUILDER.is_file():
            raise BuildError(f"runtime entrypoint not found: {BUILDER}")
        scenarios = _load_scenarios(Path(args.scenarios))
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        artifact = run_scenarios(scenarios, seed_dir)
        (out_dir / "offer-perf-emit.json").write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return 0
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
