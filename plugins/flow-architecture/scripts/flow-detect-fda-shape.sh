#!/usr/bin/env bash
set -euo pipefail

# flow-detect-fda-shape.sh — emit presence flags for FDA artifacts.
#
# Per Q30.6 (memory:292) — read-only filesystem inspection of locked FDA paths.
# Output: KEY=VALUE lines on stdout. Consumed by flow-detect-mode.sh and
# flow-context-load.sh.
#
# Usage:
#   flow-detect-fda-shape.sh [REPO_ROOT]
#
# REPO_ROOT defaults to `git rev-parse --show-toplevel`.
#
# Output keys (Q12.2 / Q12.4 / Q31.4 path canon):
#   INTENT_EXISTS         docs/product/intent.md
#   INVENTORY_EXISTS      docs/product/master-flow-inventory.md
#   FLOWS_DIR_EXISTS      docs/product/flows/ exists AND contains *.md
#   JOURNEYS_DIR_EXISTS   docs/product/journeys/ exists AND contains *.md
#   BREADCRUMB_EXISTS     docs/plans/.flow-phase-state.json
#
# bash 3.2+ compatible (Q32): no bash-4-only features (see plugin CONTRIBUTING).

REPO_ROOT="${1:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  echo "flow-detect-fda-shape: REPO_ROOT not resolvable (argv[1] or git)" >&2
  exit 1
fi

flag_file() {
  if [ -f "$1" ]; then echo "yes"; else echo "no"; fi
}

# Directory presence + at least one *.md inside (any depth).
flag_dir_with_md() {
  local dir="$1"
  if [ ! -d "$dir" ]; then echo "no"; return; fi
  # bash 3.2: use find rather than `compgen` or bash-4 globstar.
  local first_md
  first_md="$(find "$dir" -type f -name '*.md' -print -quit 2>/dev/null || true)"
  if [ -n "$first_md" ]; then echo "yes"; else echo "no"; fi
}

INTENT_EXISTS="$(flag_file "$REPO_ROOT/docs/product/intent.md")"
INVENTORY_EXISTS="$(flag_file "$REPO_ROOT/docs/product/master-flow-inventory.md")"
FLOWS_DIR_EXISTS="$(flag_dir_with_md "$REPO_ROOT/docs/product/flows")"
JOURNEYS_DIR_EXISTS="$(flag_dir_with_md "$REPO_ROOT/docs/product/journeys")"
BREADCRUMB_EXISTS="$(flag_file "$REPO_ROOT/docs/plans/.flow-phase-state.json")"

printf 'INTENT_EXISTS=%s\n' "$INTENT_EXISTS"
printf 'INVENTORY_EXISTS=%s\n' "$INVENTORY_EXISTS"
printf 'FLOWS_DIR_EXISTS=%s\n' "$FLOWS_DIR_EXISTS"
printf 'JOURNEYS_DIR_EXISTS=%s\n' "$JOURNEYS_DIR_EXISTS"
printf 'BREADCRUMB_EXISTS=%s\n' "$BREADCRUMB_EXISTS"
