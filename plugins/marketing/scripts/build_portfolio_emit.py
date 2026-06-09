#!/usr/bin/env python3
"""Deterministic portfolio-snapshot emit builder for /marketing:portfolio-snapshot
(BC-12943, ADR-028 Phase-2 Batch B — structure-first report-builder eval).

The hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589 runner)
drives for /marketing:portfolio-snapshot. It does NOT re-implement any synthesis
logic: it shells the SAME runtime entrypoint the command already shells —

  * `portfolio_snapshot.py --span … --window-start … --window-end …
     --campaigns-dir <sandbox> --canonicals-dir <sandbox> --out <sandbox>/_reviews/…
     --generated-at <pinned> [--sf-status …] [--linear-status …]`

— against a sandbox copy of a FROZEN seed (a campaigns tree + learnings.md +
canonicals). `--generated-at` is pinned so the lone clock call (datetime.now() in
render_packet) is unreachable. So the eval certifies the REAL runtime path (the only
eval-time difference is the dirs point at a sandbox seed).

The structure-first seam (ADR-028 D2): this asserts the WRITTEN packet's deterministic
STRUCTURE — the frontmatter (window + sources), the parenthesized window label, the
ordered section headers (the monthly-5-vs-quarterly-9 branch), the degraded banners,
the entity-cumulative verdict distribution, and the in-window campaign count — and NOT
prose. The anti-creep `--out`-must-be-under-`_reviews/` guard is a load-bearing
rejection branch (rc 2 → an ok:false row), not an infra error.

emit artifact (`--scenarios <fixture> --out-dir <dir> [--seed-dir <dir>]`):
    portfolio-emit.json = {
      "schema_version": 1,
      "command": "/marketing:portfolio-snapshot",
      "scenarios": [ {id, ok, frontmatter|null, title_label|null, sections|null,
                      banners|null, verdicts|null, campaigns_in_window|null, error|null}, … ]
    }
Same builder+harness shape as build_canonical_emit.py / build_offer_perf_emit.py.
Stdlib-only per CLAUDE.md § Conventions.

Exit codes: 0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / an
unexpected entrypoint failure (an infra error, distinct from a per-scenario verdict —
an anti-creep rejection is a SUCCESSFUL run that yields `ok: false`).
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
COMMAND = "/marketing:portfolio-snapshot"
# Pinned so the builder's only clock call (datetime.now in render_packet) is unreachable.
GENERATED_AT = "2026-05-26T15:00:00Z"
COMMAND_VERSION = "marketing@eval"

_HERE = Path(__file__).resolve().parent
BUILDER = _HERE / "portfolio_snapshot.py"
DEFAULT_SEED_DIR = _HERE.parent / "tests" / "eval" / "portfolio-snapshot-seed"

HERMETIC_DENY = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY")
GIT_ENV = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
)

# Degraded-banner markers rendered by portfolio_snapshot.py (substrings, status-agnostic
# within each source: SF covers both degraded_auth + degraded_query).
_SF_BANNER = "SF rollup section degraded"
_LINEAR_BANNER = "Linear MCP degraded"
_TITLE_RE = re.compile(r"^# Portfolio Snapshot — .*\((?P<label>[^)]+)\)\s*$")
# The Section-3c "Campaign Verdict" distribution line. Only 3c emits the
# SCALE/ITERATE/PAUSE/KILL key shape — 3a (angles: ALPHA/PROMISING/…) and 3b (mmf
# prose) use disjoint tokens — so `.search` unambiguously matches the 3c line.
_VERDICT_RE = re.compile(
    r"Distribution: SCALE = (\d+) / ITERATE = (\d+) / PAUSE = (\d+) / KILL = (\d+)"
)
_TOTALS_RE = re.compile(r"\*\*Totals:\*\*\s*(\d+)\s+campaigns in window")
_NO_CAMPAIGNS = "No campaigns in window"
# Nested frontmatter blocks (everything else is a scalar key:value).
_NESTED_KEYS = ("window", "sources")


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
    """The `---`-delimited frontmatter as a dict, with the one-level-nested `window:`
    and `sources:` blocks parsed into sub-dicts. schema_version coerced to int."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise BuildError("packet has no frontmatter block")
    fm: dict = {}
    parent: str | None = None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if not line.strip():
            continue
        if line.startswith("  ") and parent is not None:  # a nested 2-space entry
            k, _, v = line.strip().partition(":")
            fm[parent][k.strip()] = v.strip()
            continue
        key, _, value = line.partition(":")
        key, value = key.strip(), value.strip()
        if value == "" and key in _NESTED_KEYS:
            fm[key] = {}
            parent = key
        else:
            fm[key] = value
            parent = None
    if "schema_version" in fm:
        try:
            fm["schema_version"] = int(fm["schema_version"])
        except (TypeError, ValueError):
            pass
    return fm


def _title_label(text: str) -> str | None:
    for ln in text.splitlines():
        m = _TITLE_RE.match(ln)
        if m:
            return m.group("label").strip()
    return None


def _section_titles(text: str) -> list:
    """The ordered `## ` section headers (text after `## `). The `### 3a/3b/3c`
    subsections are `###`, so the monthly-5-vs-quarterly-9 top-level set is clean."""
    return [ln[3:].strip() for ln in text.splitlines() if ln.startswith("## ")]


def _verdicts(text: str) -> dict | None:
    m = _VERDICT_RE.search(text)
    if not m:
        return None
    return {
        "SCALE": int(m.group(1)), "ITERATE": int(m.group(2)),
        "PAUSE": int(m.group(3)), "KILL": int(m.group(4)),
    }


def _campaigns_in_window(text: str) -> int:
    if _NO_CAMPAIGNS in text:
        return 0
    m = _TOTALS_RE.search(text)
    if not m:
        raise BuildError("packet has neither a Totals campaign count nor the empty marker")
    return int(m.group(1))


def _project(text: str) -> dict:
    return {
        "frontmatter": _parse_frontmatter(text),
        "title_label": _title_label(text),
        "sections": _section_titles(text),
        "banners": {
            "sf": _SF_BANNER in text,
            "linear": _LINEAR_BANNER in text,
        },
        "verdicts": _verdicts(text),
        "campaigns_in_window": _campaigns_in_window(text),
    }


# ── driving the real builder ──────────────────────────────────────────────────


def _build_argv(sc: dict, campaigns: Path, canonicals: Path, out: Path,
                sf_json: Path | None, linear_json: Path | None) -> list:
    argv = [
        sys.executable, str(BUILDER),
        "--span", str(sc["span"]),
        "--window-start", str(sc["window_start"]),
        "--window-end", str(sc["window_end"]),
        "--campaigns-dir", str(campaigns),
        "--canonicals-dir", str(canonicals),
        "--command-version", COMMAND_VERSION,
        "--generated-at", GENERATED_AT,
        "--out", str(out),
    ]
    if sf_json is not None:
        argv += ["--sf-json", str(sf_json)]
    if sc.get("sf_status"):
        argv += ["--sf-status", str(sc["sf_status"])]
    if linear_json is not None:
        argv += ["--linear-json", str(linear_json)]
    if sc.get("linear_status"):
        argv += ["--linear-status", str(sc["linear_status"])]
    return argv


def decide(sc: dict, seed_dir: Path) -> dict:
    """One scenario → one emit row. Copies the frozen seed into an isolated sandbox,
    drives the REAL portfolio_snapshot.py, and (on a clean write) projects the packet.
    The anti-creep guard rejection (exit 2) yields ok:false + the builder's error."""
    sid = sc.get("id", "scenario")
    for req in ("span", "window_start", "window_end"):
        if req not in sc:
            raise BuildError(f"scenario {sid!r} missing required key {req!r}")

    sandbox = Path(tempfile.mkdtemp(prefix="portfolio-emit-"))
    try:
        shutil.copytree(seed_dir, sandbox, dirs_exist_ok=True)
        campaigns = sandbox / "docs" / "campaigns"
        canonicals = sandbox / "canonicals"
        # out_override (relative to sandbox) drives the anti-creep rejection scenario;
        # otherwise write the packet under the canonical _reviews/ dir.
        if sc.get("out_override"):
            out = sandbox / sc["out_override"]
        else:
            out = campaigns / "_reviews" / "portfolio.md"

        sf_json = None
        if sc.get("sf_records") is not None:
            sf_json = sandbox / "sf.json"
            sf_json.write_text(json.dumps({"records": sc["sf_records"]}), encoding="utf-8")
        linear_json = None
        if sc.get("linear_milestones") is not None:
            linear_json = sandbox / "linear.json"
            linear_json.write_text(
                json.dumps({"milestones": sc["linear_milestones"]}), encoding="utf-8"
            )

        proc = subprocess.run(
            _build_argv(sc, campaigns, canonicals, out, sf_json, linear_json),
            capture_output=True, text=True, env=_child_env(),
        )
        # 0 = wrote the packet; 2 = a builder-owned validation/guard rejection (the
        # anti-creep guard, a bad window). Anything else is an infra error.
        if proc.returncode not in (0, 2):
            raise BuildError(
                f"portfolio_snapshot.py exited {proc.returncode} for scenario {sid!r} "
                f"(not a verdict):\n{proc.stderr.strip()}"
            )
        if proc.returncode == 2:
            err_line = (proc.stderr.strip().splitlines() or ["(no stderr)"])[0]
            # Scrub the non-deterministic sandbox path (both the /var and the resolved
            # /private/var macOS forms) so the rejection error is golden-stable. Replace
            # LONGEST-first + in a fixed order: the resolved /private/var/… form contains
            # the raw /var/… form as a substring, so a set-ordered raw-first replace would
            # leave a stray '/private<sandbox>' (a flaky golden, hash-seed dependent).
            for p in sorted({str(sandbox), str(sandbox.resolve())}, key=len, reverse=True):
                err_line = err_line.replace(p, "<sandbox>")
            return {
                "id": sid, "ok": False, "frontmatter": None, "title_label": None,
                "sections": None, "banners": None, "verdicts": None,
                "campaigns_in_window": None,
                "error": err_line,
            }
        if not out.is_file():
            raise BuildError(
                f"scenario {sid!r}: expected packet not written: {out} "
                f"(stdout: {proc.stdout.strip()!r})"
            )
        row = {"id": sid, "ok": True, "error": None}
        row.update(_project(out.read_text(encoding="utf-8")))
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
        prog="build_portfolio_emit.py",
        description="Deterministic portfolio-snapshot emit builder (BC-12943).",
    )
    ap.add_argument("--scenarios", required=True, help="fixture JSON (scenario list)")
    ap.add_argument("--out-dir", required=True, help="write portfolio-emit.json into this dir")
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
        (out_dir / "portfolio-emit.json").write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return 0
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
