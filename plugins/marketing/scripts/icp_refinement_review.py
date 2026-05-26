#!/usr/bin/env python3
"""Mechanical helper for `/marketing:icp-refinement-review` (BC-8726).

The slash command at `plugins/marketing/commands/icp-refinement-review.md`
drives operator decisions via AskUserQuestion. This helper handles the
deterministic IO around those decisions — discoveries.json globbing,
filtering, in-place mutation, and handbook-markdown emission. Stdlib only,
mirrors `lint_discoveries.py` discipline.

Three subcommands, each pure / side-effect-bounded:

  scan            Walk `docs/campaigns/*/*/discoveries.json`. Emit JSON
                  describing every `category=icp-refinement` signal whose
                  `promotion_status` is pending (or absent — schema default).
                  Groups by `payload.vertical` for the operator's per-group
                  review loop.

  apply           Read a `--decision-map` JSON file (operator's
                  promote/reject/defer decisions, keyed by signal_id) and
                  rewrite the touched discoveries.json files in place:
                  `promoted` and `rejected` flip the signal's
                  `promotion_status`; `deferred` is a no-op (signal stays
                  pending for next review cycle). JSON shape preserved
                  (json.dumps indent=2; sorted keys NOT enforced — append-
                  only signal lists must keep order).

  emit-handbook   Walk decisions; for each `promoted` signal, print a
                  markdown blob recommending the handbook playbook edit.
                  Operator review is the point — this helper NEVER touches
                  the handbook repo or opens a PR. Cross-cite the canonicals
                  vs prose target per references/discoveries-promotion.md.

Signal IDs are deterministic: `<relative-file-path>::<signal-index>`. The
file path is relative to the campaigns dir so fixtures + production share
the same shape. The index is the array offset in `signals[]` at scan time;
`apply` re-reads the file and verifies the category + status before
mutating (defensive against operator hand-edits between scan and apply).

Exit codes:
  0   success (or empty case — no pending icp-refinement signals)
  1   data error (missing decision for surfaced signal, stale file, etc.)
  2   usage error (missing dir, malformed --decision-map JSON, etc.)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCHEMA_VERSION = 1
TARGET_CATEGORY = "icp-refinement"
PENDING_STATES = frozenset({"pending"})  # absent == pending per schema default
VALID_DECISIONS = frozenset({"promoted", "rejected", "deferred"})
TERMINAL_PROMOTION = frozenset({"promoted", "rejected"})


def _err(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)


def _glob_discoveries(campaigns_dir: Path) -> list[Path]:
    """Mirrors lint_discoveries.py's `discover_files` (sorted, two-deep glob)."""
    if not campaigns_dir.is_dir():
        return []
    return sorted(campaigns_dir.glob("*/*/discoveries.json"))


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _signal_id(path: Path, campaigns_dir: Path, idx: int) -> str:
    rel = path.relative_to(campaigns_dir).as_posix()
    return f"{rel}::{idx}"


def _is_pending(signal: dict) -> bool:
    status = signal.get("promotion_status", "pending")
    return status in PENDING_STATES


def _read_manifest_vertical(discoveries_path: Path) -> str | None:
    """Sibling manifest.json vertical field, when present."""
    manifest = discoveries_path.parent / "manifest.json"
    if not manifest.is_file():
        return None
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    v = data.get("vertical")
    return v if isinstance(v, str) and v else None


def _signal_vertical(signal: dict, manifest_vertical: str | None) -> str:
    """Per icp-refinement payload schema, `payload.vertical` is canonical;
    fall back to sibling manifest.json's vertical; final fallback "unknown"."""
    payload = signal.get("payload") or {}
    v = payload.get("vertical")
    if isinstance(v, str) and v:
        return v
    if manifest_vertical:
        return manifest_vertical
    return "unknown"


def cmd_scan(args: argparse.Namespace) -> int:
    """Emit JSON of pending icp-refinement signals grouped by vertical."""
    campaigns_dir: Path = args.campaigns_dir
    if not campaigns_dir.is_dir():
        _err(f"--campaigns-dir not a directory: {campaigns_dir}")
        return 2

    groups: dict[str, list[dict]] = {}
    total = 0
    for path in _glob_discoveries(campaigns_dir):
        try:
            data = _load_json(path)
        except (json.JSONDecodeError, OSError) as e:
            _err(f"{path}: cannot read/parse ({e})")
            return 1
        manifest_vertical = _read_manifest_vertical(path)
        for idx, signal in enumerate(data.get("signals", [])):
            if not isinstance(signal, dict):
                continue
            if signal.get("category") != TARGET_CATEGORY:
                continue
            if not _is_pending(signal):
                continue
            vertical = _signal_vertical(signal, manifest_vertical)
            groups.setdefault(vertical, []).append({
                "signal_id": _signal_id(path, campaigns_dir, idx),
                "vertical": vertical,
                "persona": (signal.get("payload") or {}).get("persona", "unknown"),
                "payload": signal.get("payload") or {},
                "emitted_at": signal.get("emitted_at"),
                "emitted_by_skill": signal.get("emitted_by_skill"),
            })
            total += 1

    out = {
        "total_pending": total,
        "groups": {k: groups[k] for k in sorted(groups.keys())},
    }
    print(json.dumps(out, indent=2))
    return 0


def _load_decision_map(path: Path) -> dict[str, str]:
    if not path.is_file():
        _err(f"--decision-map file not found: {path}")
        sys.exit(2)
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        _err(f"--decision-map: invalid JSON ({e})")
        sys.exit(2)
    if not isinstance(raw, dict):
        _err("--decision-map: top-level must be an object")
        sys.exit(2)
    for k, v in raw.items():
        if not isinstance(v, str) or v not in VALID_DECISIONS:
            _err(
                f"--decision-map['{k}']: decision must be one of "
                f"{sorted(VALID_DECISIONS)}; got {v!r}"
            )
            sys.exit(2)
    return raw  # type: ignore[return-value]


def cmd_apply(args: argparse.Namespace) -> int:
    """Mutate discoveries.json files in place per decision map."""
    campaigns_dir: Path = args.campaigns_dir
    if not campaigns_dir.is_dir():
        _err(f"--campaigns-dir not a directory: {campaigns_dir}")
        return 2
    decisions = _load_decision_map(args.decision_map)
    if not decisions:
        print(json.dumps({"promoted": 0, "rejected": 0, "deferred": 0, "skipped": 0}))
        return 0

    # Bucket decisions by file path so we read/write each file once.
    by_file: dict[str, list[tuple[int, str]]] = {}
    for signal_id, decision in decisions.items():
        try:
            rel, idx_str = signal_id.rsplit("::", 1)
            idx = int(idx_str)
        except (ValueError, AttributeError):
            _err(f"malformed signal_id {signal_id!r} (want '<path>::<idx>')")
            return 1
        by_file.setdefault(rel, []).append((idx, decision))

    counts = {"promoted": 0, "rejected": 0, "deferred": 0, "skipped": 0}
    for rel, ops in sorted(by_file.items()):
        path = campaigns_dir / rel
        if not path.is_file():
            _err(f"decision references missing file: {rel}")
            return 1
        try:
            data = _load_json(path)
        except (json.JSONDecodeError, OSError) as e:
            _err(f"{path}: cannot read/parse ({e})")
            return 1

        signals = data.get("signals", [])
        if not isinstance(signals, list):
            _err(f"{path}: signals must be a list")
            return 1

        mutated = False
        for idx, decision in ops:
            if idx < 0 or idx >= len(signals):
                _err(f"{rel}::{idx}: signal index out of range")
                return 1
            signal = signals[idx]
            if not isinstance(signal, dict):
                _err(f"{rel}::{idx}: signal is not an object")
                return 1
            if signal.get("category") != TARGET_CATEGORY:
                _err(
                    f"{rel}::{idx}: category mismatch — refusing to mutate "
                    f"(got {signal.get('category')!r}, expected "
                    f"{TARGET_CATEGORY!r})"
                )
                return 1
            current = signal.get("promotion_status", "pending")
            if current in TERMINAL_PROMOTION:
                # Race: another reviewer already terminalized this signal.
                # Skip rather than overwrite — promotion is one-way per
                # references/discoveries-promotion.md § Promotion-status
                # invariants.
                counts["skipped"] += 1
                continue
            if decision == "deferred":
                counts["deferred"] += 1
                continue
            signal["promotion_status"] = decision
            counts[decision] += 1
            mutated = True

        if mutated:
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(counts))
    return 0


_HANDBOOK_TEMPLATE = """\
<!-- BC-8726 / icp-refinement-review — {signal_id} -->
<!-- Source signal: {emitted_by_skill} @ {emitted_at} -->
<!-- Target file: handbook/marketing/go-to-market/verticals/{vertical}/README.md -->
<!-- Companion target (canonicals): plugins/marketing/data/canonicals/{vertical}.yaml -->

### ICP refinement — {vertical} / {persona}

**Current ICP summary** — {current_icp_summary}

**Observed pattern** — {observed_pattern}

**Evidence** — {evidence_metric}

**Proposed refinement** — {refinement_proposal}

> Suggested commit message: `BC-8726: refine {persona} ICP for {vertical} ({signal_id})`
"""


def cmd_emit_handbook(args: argparse.Namespace) -> int:
    """Print handbook markdown blobs for each `promoted` decision."""
    campaigns_dir: Path = args.campaigns_dir
    if not campaigns_dir.is_dir():
        _err(f"--campaigns-dir not a directory: {campaigns_dir}")
        return 2
    decisions = _load_decision_map(args.decision_map)

    by_file: dict[str, list[tuple[int, str]]] = {}
    for signal_id, decision in decisions.items():
        if decision != "promoted":
            continue
        rel, idx_str = signal_id.rsplit("::", 1)
        by_file.setdefault(rel, []).append((int(idx_str), signal_id))

    if not by_file:
        print("# icp-refinement-review — no promoted signals; nothing to emit.")
        return 0

    blobs: list[str] = []
    for rel, ops in sorted(by_file.items()):
        path = campaigns_dir / rel
        if not path.is_file():
            _err(f"decision references missing file: {rel}")
            return 1
        try:
            data = _load_json(path)
        except (json.JSONDecodeError, OSError) as e:
            _err(f"{path}: cannot read/parse ({e})")
            return 1
        manifest_vertical = _read_manifest_vertical(path)
        signals = data.get("signals", [])
        for idx, signal_id in ops:
            signal = signals[idx]
            payload = signal.get("payload") or {}
            vertical = _signal_vertical(signal, manifest_vertical)
            blobs.append(_HANDBOOK_TEMPLATE.format(
                signal_id=signal_id,
                emitted_by_skill=signal.get("emitted_by_skill", "unknown"),
                emitted_at=signal.get("emitted_at", "unknown"),
                vertical=vertical,
                persona=payload.get("persona", "unknown"),
                current_icp_summary=payload.get("current_icp_summary", "<missing>"),
                observed_pattern=payload.get("observed_pattern", "<missing>"),
                evidence_metric=payload.get("evidence_metric", "<missing>"),
                refinement_proposal=payload.get("refinement_proposal", "<missing>"),
            ))

    print("\n---\n".join(blobs))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="icp_refinement_review.py",
        description=(
            "Mechanical helper for /marketing:icp-refinement-review (BC-8726). "
            "Three subcommands: scan / apply / emit-handbook. See module "
            "docstring for the slash-command orchestration."
        ),
    )
    parser.add_argument(
        "--campaigns-dir",
        type=Path,
        required=True,
        help="Path to docs/campaigns root (override for tests).",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("scan", help="Emit JSON of pending icp-refinement signals.")

    apply_p = sub.add_parser("apply", help="Apply --decision-map mutations.")
    apply_p.add_argument(
        "--decision-map",
        type=Path,
        required=True,
        help="JSON file mapping signal_id → 'promoted'|'rejected'|'deferred'.",
    )

    emit_p = sub.add_parser("emit-handbook", help="Print handbook markdown blobs.")
    emit_p.add_argument(
        "--decision-map",
        type=Path,
        required=True,
        help="JSON file mapping signal_id → decision (only 'promoted' emit).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.cmd == "scan":
        return cmd_scan(args)
    if args.cmd == "apply":
        return cmd_apply(args)
    if args.cmd == "emit-handbook":
        return cmd_emit_handbook(args)
    _err(f"unknown subcommand: {args.cmd}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
