#!/usr/bin/env bash
# WS-A reusable story-doc linter — runs the A-1/A-2/A-3 + D11-frame checks
# (scripts/lib/flow_doc_lint.sh) against every story doc in a consumer repo.
#
# Usage:
#   flow-doc-lint.sh <flows-dir>        # e.g. <repo>/docs/product/flows
#   flow-doc-lint.sh --json <flows-dir> # machine-readable one-object-per-line
#
# Lints every `*.md` under <flows-dir> except `INDEX.md`. Prints one line per
# doc (PASS or the defect codes), a summary, and exits 1 if any doc has a
# defect — so it drops cleanly into WS-E remediation (lint a repo's docs before
# and after re-authoring) or a `/flow:audit` advisory gate.
#
# Bash 3.2 compatible. Stdlib only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/flow_doc_lint.sh"

json=0
if [ "${1:-}" = "--json" ]; then json=1; shift; fi
flows_dir="${1:-}"

if [ -z "$flows_dir" ] || [ ! -d "$flows_dir" ]; then
  echo "usage: flow-doc-lint.sh [--json] <flows-dir>" >&2
  exit 2
fi
if [ ! -f "$LIB" ]; then
  echo "FATAL: lib not found at $LIB" >&2
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

total=0
defective=0

while IFS= read -r doc; do
  [ -n "$doc" ] || continue
  total=$((total + 1))
  verdict="$(lint_story_doc "$doc" || true)"
  rel="${doc#"$flows_dir"/}"
  if [ "$verdict" = "PASS" ]; then
    [ "$json" -eq 1 ] && printf '{"doc":"%s","verdict":"PASS","defects":[]}\n' "$rel" \
                      || printf '  PASS  %s\n' "$rel"
  else
    defective=$((defective + 1))
    if [ "$json" -eq 1 ]; then
      # codes -> JSON array
      arr="$(printf '%s' "$verdict" | awk '{for(i=1;i<=NF;i++){printf "%s\"%s\"",(i>1?",":""),$i}}')"
      printf '{"doc":"%s","verdict":"DEFECT","defects":[%s]}\n' "$rel" "$arr"
    else
      printf '  FAIL  %-52s %s\n' "$rel" "$verdict"
    fi
  fi
done < <(find "$flows_dir" -type f -name '*.md' ! -name 'INDEX.md' 2>/dev/null | sort)

if [ "$json" -eq 0 ]; then
  printf '\nflow-doc-lint: %d docs, %d clean, %d with defects\n' \
    "$total" "$((total - defective))" "$defective"
fi
[ "$defective" -gt 0 ] && exit 1
exit 0
