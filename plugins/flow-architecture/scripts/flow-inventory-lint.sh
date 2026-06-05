#!/usr/bin/env bash
# WS-A inventory linter — A-8 (inventory ↔ doc two-identifier consistency) and,
# when a base git ref is given, A-9 (flow-ID immutability since that ref).
#
# Usage:
#   flow-inventory-lint.sh <repo-root> [base-ref]
#
# Reads <repo-root>/docs/product/master-flow-inventory.md and
# <repo-root>/docs/product/flows. With <base-ref> (e.g. origin/main, a tag, a
# SHA), also diffs the inventory's flow-ID set against that ref to catch
# removed/renamed flow-IDs. Prints one violation per line; exits 1 if any.
#
# Bash 3.2 compatible. Stdlib only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/flow_inventory_lint.sh"

repo="${1:-}"
base_ref="${2:-}"
if [ -z "$repo" ] || [ ! -d "$repo" ]; then
  echo "usage: flow-inventory-lint.sh <repo-root> [base-ref]" >&2
  exit 2
fi
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 2; }
# shellcheck disable=SC1090
. "$LIB"

inv="$repo/docs/product/master-flow-inventory.md"
flows="$repo/docs/product/flows"
violations=0

emit() { # read violation lines on stdin, print + count
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '  %s\n' "$line"
    violations=$((violations + 1))
  done
}

echo "→ A-8 inventory ↔ doc consistency"
emit < <(detect_inventory_consistency "$inv" "$flows")

if [ -n "$base_ref" ]; then
  echo "→ A-9 flow-ID immutability since $base_ref"
  old_inv="$(mktemp)"
  trap 'rm -f "$old_inv"' EXIT
  if git -C "$repo" show "$base_ref:docs/product/master-flow-inventory.md" > "$old_inv" 2>/dev/null; then
    emit < <(detect_flowid_immutability "$old_inv" "$inv")
  else
    echo "  (skip — could not read inventory at $base_ref)"
  fi
fi

if [ "$violations" -eq 0 ]; then
  echo "✓ inventory lints clean"
  exit 0
fi
echo "✗ $violations inventory-lint violation(s)"
exit 1
