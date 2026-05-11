#!/usr/bin/env bash
set -euo pipefail

# flow-detect-mode.sh — emit the FDA mode classification.
#
# Per Q30.6 (memory:292) + Q12.3 mode classification (memory:74) + Q36.3 step 4
# heuristic (memory:357). Outputs exactly one of:
#
#   greenfield        no FDA artifacts AND (no Linear-issue-count signal OR count < 10)
#   retrofit          intent + inventory but no flows yet  (Q12 edge: zero-domains-with-full-FDA)
#                     OR no FDA artifacts AND LINEAR_ISSUE_COUNT >= 10  (Q36.3 step 4 heuristic)
#   incremental-add   FDA shape complete (intent + inventory + flows) AND no in-flight breadcrumb
#   resume            in-flight breadcrumb present AND not stale (per Q31.3)
#
# Linear-side issue count is NOT filesystem-derivable; orchestrator may pass it
# via LINEAR_ISSUE_COUNT env var to honour the Q36.3 heuristic. User confirmation
# (Q36.3 step 5) remains authoritative — this script emits a tentative mode only.
#
# Usage:
#   flow-detect-mode.sh [REPO_ROOT]
#   LINEAR_ISSUE_COUNT=42 flow-detect-mode.sh
#
# bash 3.2+ compatible (Q32).

REPO_ROOT="${1:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  echo "flow-detect-mode: REPO_ROOT not resolvable (argv[1] or git)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pull FDA-shape signals from sibling helper.
SHAPE_OUT="$("$SCRIPT_DIR/flow-detect-fda-shape.sh" "$REPO_ROOT")"

# Parse KEY=VALUE lines into variables.
INTENT_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^INTENT_EXISTS=//p')"
INVENTORY_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^INVENTORY_EXISTS=//p')"
FLOWS_DIR_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^FLOWS_DIR_EXISTS=//p')"
BREADCRUMB_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^BREADCRUMB_EXISTS=//p')"

# Breadcrumb-driven `resume` takes precedence (Q12.3 + Q31.3 stale check).
if [ "$BREADCRUMB_EXISTS" = "yes" ]; then
  BC_OUT="$("$SCRIPT_DIR/flow-resume-breadcrumb.sh" read "$REPO_ROOT/docs/plans/.flow-phase-state.json")"
  BC_STATUS="$(printf '%s\n' "$BC_OUT" | sed -n 's/^STATUS=//p')"
  BC_STALE="$(printf '%s\n' "$BC_OUT" | sed -n 's/^STALE=//p')"
  if [ "$BC_STATUS" = "in_flight" ] && [ "$BC_STALE" = "no" ]; then
    echo "resume"
    exit 0
  fi
  # Stale or non-in_flight breadcrumb — fall through to artifact-driven classification.
fi

# Artifact-driven classification.
if [ "$INTENT_EXISTS" = "yes" ] && [ "$INVENTORY_EXISTS" = "yes" ]; then
  if [ "$FLOWS_DIR_EXISTS" = "yes" ]; then
    echo "incremental-add"
    exit 0
  fi
  # intent + inventory but no flows yet — Q12 edge: retrofit.
  echo "retrofit"
  exit 0
fi

# No FDA artifacts — Q36.3 step 4 heuristic (LINEAR_ISSUE_COUNT optional).
LIC="${LINEAR_ISSUE_COUNT:-}"
if [ -n "$LIC" ]; then
  # Validate the count is a non-negative integer before comparing.
  case "$LIC" in
    ''|*[!0-9]*)
      echo "flow-detect-mode: LINEAR_ISSUE_COUNT='$LIC' is not a non-negative integer; ignoring" >&2
      ;;
    *)
      if [ "$LIC" -ge 10 ]; then
        echo "retrofit"
        exit 0
      fi
      ;;
  esac
fi

echo "greenfield"
