#!/usr/bin/env bash
# measure.sh — latency measurement helper for BC-6905 spike (Q1/Q2/Q3).
# Wraps bw CLI calls inside a script so per-call output is captured cleanly.
# Throwaway POC; deleted alongside spike-bw-run/ when BC-6906 lands.
#
# Usage:
#   measure.sh q1q2 [warm|cold] [item=tam-map-spider-api-key] [trials=5]
#   measure.sh q3   [warm|cold] [search=tam-map-] [trials=5]
set -euo pipefail

cmd="${1:-q1q2}"
mode="${2:-warm}"
arg3="${3:-}"
trials="${4:-5}"

case "$cmd" in
  q1q2)
    item="${arg3:-tam-map-spider-api-key}"
    echo "## Q1/Q2 — single-call \`bw get password $item\` ($mode, n=$trials)"
    if [ "$mode" = "warm" ]; then bw sync >/dev/null; fi
    for i in $(seq 1 "$trials"); do
      out=$( { /usr/bin/time -p bw get password "$item" >/dev/null; } 2>&1 )
      real=$(echo "$out" | awk '/^real/ {print $2}')
      printf "trial %d: real=%ss\n" "$i" "$real"
    done
    ;;
  q3)
    search="${arg3:-tam-map-}"
    echo "## Q3 — \`bw list items --search $search\` ($mode, n=$trials)"
    if [ "$mode" = "warm" ]; then bw sync >/dev/null; fi
    for i in $(seq 1 "$trials"); do
      out=$( { /usr/bin/time -p bw list items --search "$search" >/dev/null; } 2>&1 )
      real=$(echo "$out" | awk '/^real/ {print $2}')
      printf "trial %d: real=%ss\n" "$i" "$real"
    done
    ;;
  *)
    echo "measure.sh: unknown command \`$cmd\` (expected q1q2 or q3)" >&2
    exit 2
    ;;
esac
