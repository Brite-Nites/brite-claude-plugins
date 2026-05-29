#!/usr/bin/env bash
# WS-A Linear-graph linter — A-4 (label↔title-prefix contamination), A-5
# (blockedBy-wiring, doc ↔ Linear), A-6 (child-milestone-inheritance), A-7
# (duplicate-discipline-child).
#
# Usage:
#   flow-linear-lint.sh <linear-state.json> [flows-dir]
#
# Unlike the doc/inventory lints, these need *Linear* data — a bash/python
# script can't fetch it. <linear-state.json> is a snapshot serialized from
# Linear (see plugins/flow-architecture/tests/fixtures/synthetic-linear-graph/
# README.md for the schema + the WS-E MCP→JSON serialize contract). When a
# <flows-dir> is given (a repo's docs/product/flows), A-5 also mirrors the
# story-doc `## Cross-domain dependencies` sections against Linear blockedBy;
# without it, A-5 is skipped.
#
# Prints one violation per line under its lint heading; exits 1 if any, 0 if
# clean, 2 on bad invocation / unreadable state. Bash 3.2 compatible; delegates
# all JSON work to the stdlib-only python3 lib (flow_linear_lint.py).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/flow_linear_lint.py"

state="${1:-}"
flows="${2:-}"

if [ -z "$state" ] || [ ! -f "$state" ]; then
  echo "usage: flow-linear-lint.sh <linear-state.json> [flows-dir]" >&2
  exit 2
fi
# A given-but-nonexistent flows-dir must be a hard invocation error, NOT a silent
# "zero doc bullets" — the latter makes A-5 report every real Linear blockedBy edge
# as a false "never wired" orphan. (Omitting the arg entirely cleanly SKIPs A-5.)
if [ -n "$flows" ] && [ ! -d "$flows" ]; then
  echo "FATAL: flows-dir not found: $flows" >&2
  exit 2
fi
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 required" >&2; exit 2; }

if [ -n "$flows" ]; then
  exec python3 "$LIB" "$state" "$flows"
fi
exec python3 "$LIB" "$state"
