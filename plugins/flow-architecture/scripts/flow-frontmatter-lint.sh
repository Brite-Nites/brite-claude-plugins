#!/usr/bin/env bash
# WS-A frontmatter-schema linter (BC-12572) — runs the A-10 story / A-11 journey
# schema lint (scripts/lib/flow_frontmatter_lint.py) over a consumer repo's docs.
#
# Usage:
#   flow-frontmatter-lint.sh --type {story|journey|redirect} <path> [<path> ...]
#
# Each <path> is a directory (every `*.md` under it except `INDEX.md` is linted)
# OR an explicit doc file. Prints one block per doc — `PASS <path>` or the doc's
# DRIFT_KEY / MISSING_KEY / UNKNOWN_KEY lines — and a summary. Exit 1 if any doc
# carries a LOUD defect (DRIFT_KEY or MISSING_KEY); UNKNOWN_KEY extras are quiet
# (exit 0). Exit 2 on bad invocation.
#
# This is the always-honest TRUTH surface — standalone WS-E remediation tooling,
# NOT a ship gate (the gate is /flow:audit Phase B `story-front-matter-populated`,
# config-gated per repo via .flow/config.json `frontmatter_schema: strict`). It
# reports the full canon regardless of any repo config, so it can go red anywhere
# without halting a ship.
#
# Bash 3.2 compatible. Stdlib python3 only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/flow_frontmatter_lint.py"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 2; }

if [ "${1:-}" != "--type" ] || { [ "${2:-}" != "story" ] && [ "${2:-}" != "journey" ] && [ "${2:-}" != "redirect" ]; }; then
  echo "usage: flow-frontmatter-lint.sh --type {story|journey|redirect} <path> [<path> ...]" >&2
  exit 2
fi
doc_type="$2"
shift 2

if [ "$#" -eq 0 ]; then
  echo "usage: at least one <path> (directory or doc file) required" >&2
  exit 2
fi

# Expand directories to their *.md docs (excluding INDEX.md); pass files through.
docs=()
for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r doc; do
      [ -n "$doc" ] || continue
      docs+=("$doc")
    done <<EOF
$(find "$arg" -type f -name '*.md' ! -name 'INDEX.md' | sort)
EOF
  elif [ -f "$arg" ]; then
    docs+=("$arg")
  else
    echo "warn: skipping non-existent path: $arg" >&2
  fi
done

if [ "${#docs[@]}" -eq 0 ]; then
  echo "no story/journey docs found under the given path(s)" >&2
  exit 0
fi

python3 "$LIB" --type "$doc_type" "${docs[@]}"
