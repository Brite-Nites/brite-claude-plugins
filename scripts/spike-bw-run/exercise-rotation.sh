#!/usr/bin/env bash
# exercise-rotation.sh — Q6 rotation-propagation test (BC-6905 spike).
# Runs the wrapper with a no-op tail (`true`) so we can observe whether
# bw-run.sh fetches a fresh value on each invocation. Captures stderr
# (where bw-run.sh writes its SHA-256 prefix) — does NOT call Spider.
#
# Wrapper-side rotation only. Lifecycle-side rotation (Claude Code
# re-spawning the MCP without a restart) is BC-6906's measurement
# because it requires `.mcp.json` wiring outside this spike's scope.
set -uo pipefail

WRAPPER="$(dirname "$0")/bw-run.sh"
ITEM="${1:-tam-map-spider-api-key}"
LABEL="${2:-trial}"

bw sync >/dev/null 2>&1
out=$(bash "$WRAPPER" "SPIDER_API_KEY=$ITEM" -- true 2>&1 >/dev/null)
EXIT=$?
sha=$(echo "$out" | awk -F'sha256=' '/sha256=/ {print $2}' | tr -d ']')

printf "label=%s exit=%d sha256_prefix=%s\n" "$LABEL" "$EXIT" "$sha"
