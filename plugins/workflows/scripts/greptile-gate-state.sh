#!/usr/bin/env bash
# greptile-gate-state.sh — classify the greptile-gate's terminal state at
# PR-open time from a greptile-verdict.sh verdict. Pure classifier (no IO);
# the gate skill calls it right after `greptile-verdict.sh --pr <PR>`.
#
#   --verdict '<json>'   the single-line verdict JSON from greptile-verdict.sh
#
# Prints exactly one state:
#   NO_REVIEWER   verdict.present == false — Greptile never reviewed this PR
#                 (not installed on the repo, or hasn't posted yet). This is
#                 its own terminal state, distinct from a pass — BC-18947:
#                 absence used to read as an implicit pass because the gate
#                 skipped silently instead of naming the condition.
#   CONVERGED     verdict.present == true, score == 5 — already at the
#                 target; skip straight to Final review.
#   NEEDS_ROUND   verdict.present == true, score != 5 (including null) —
#                 enter the convergence loop.
#
# Fails open, never blocks a ship: unparseable/missing input degrades to
# NO_REVIEWER, the same direction greptile-verdict.sh itself takes on
# malformed input (a verdict it can't read is a verdict it doesn't have).

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "fatal: jq required" >&2; exit 2; }

VERDICT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --verdict) VERDICT="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    -h|--help) echo "usage: greptile-gate-state.sh --verdict '<json>'" >&2; exit 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$VERDICT" ] || { echo "usage: greptile-gate-state.sh --verdict '<json>'" >&2; exit 2; }

printf '%s' "$VERDICT" | jq -r '
  if (.present // false) != true then "NO_REVIEWER"
  elif (.score == 5)             then "CONVERGED"
  else                                 "NEEDS_ROUND"
  end
' 2>/dev/null || echo "NO_REVIEWER"
