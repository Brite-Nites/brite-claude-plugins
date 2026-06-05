#!/usr/bin/env bash
# exercise-rotation.sh — Q6 rotation-propagation test (BC-6905 spike).
#
# FROZEN ARTIFACT — preserved for BC-5946 task-3 audit trail.
# This driver depended on a temporary SHA-256 stderr log line in
# bw-run.sh (added in T8 commit f9f48f0, stripped in T10 commit
# 77d33bb per plan T10 step 2). Re-running it now will produce an
# empty `sha256_prefix=` because the log line no longer exists.
# Raw measurements (X→Y→X SHA pattern across 3 trials with mutate/
# restore in Bitwarden UI) are recorded in commit f9f48f0 and in
# `docs/research/bw-run-spike.md` § Q6 + Appendix A1.
#
# To re-run rotation tests for BC-6906, restore the SHA stderr log
# in bw-run.sh's for-loop (see commit f9f48f0 for the exact form).
#
# Original purpose: Runs the wrapper with a no-op tail (`true`) so
# we can observe whether bw-run.sh fetches a fresh value on each
# invocation. Captures stderr (where bw-run.sh wrote its SHA-256
# prefix during T8) — does NOT call Spider.
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
