#!/usr/bin/env bash
# WS-A persona-exists linter (BC-12573) — runs the persona-existence check
# (scripts/lib/flow_persona_lint.py) over a consumer repo's story docs.
#
# Usage:
#   flow-persona-lint.sh <repo-root>
#
# For each story doc under <repo-root>/docs/product/flows, asserts every NON-EMPTY
# `personas:` front-matter slug resolves to an existing
# <repo-root>/docs/product/personas/<slug>.md. Honest-empty (`personas: []` /
# absent / null) passes. Prints one `FAIL persona-exists <doc> …` line per missing
# persona; exit 1 if any.
#
# The deterministic floor of the 3-layer persona system (existence here; LLM
# resolution + depth above). Standalone TRUTH surface — reports drift regardless of
# repo config. Bash 3.2 compatible. Stdlib python3 only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/flow_persona_lint.py"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 2; }

repo="${1:-}"
if [ -z "$repo" ] || [ ! -d "$repo" ]; then
  echo "usage: flow-persona-lint.sh <repo-root>" >&2
  exit 2
fi

python3 "$LIB" "$repo"
