#!/usr/bin/env bash
# WS-A cross-domain double-credit linter (BC-12690) — runs the cross-doc
# double-credit check (scripts/lib/flow_evidence_lint.py --double-credit) over a
# consumer repo's story docs.
#
# Usage:
#   flow-double-credit-lint.sh <repo-root>
#
# Scans every story doc's `## Status notes` and flags any strict-`src/…` evidence
# anchor cited as a built deliverable in ≥2 docs UNLESS at least one citing bullet
# frames it with an ownership qualifier (owns / owned by / reuses / reused by /
# shared with). Prints one `FAIL double-credit <path> …` line per offending path
# plus the docs that double-claim it; exit 1 if any.
#
# Standalone TRUTH surface (like flow-evidence-lint.sh) — reports drift regardless
# of repo config. Bash 3.2 compatible. Stdlib python3 only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/flow_evidence_lint.py"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 2; }

repo="${1:-}"
if [ -z "$repo" ] || [ ! -d "$repo" ]; then
  echo "usage: flow-double-credit-lint.sh <repo-root>" >&2
  exit 2
fi

python3 "$LIB" --double-credit "$repo"
