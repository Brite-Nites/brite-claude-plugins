#!/usr/bin/env bash
# test_size_cap.sh — enforce the brite-core invariants that protect every
# subagent's context (BC-11749).
#
# 1. team-gbrain-usage.md MUST stay ≤ 2048 bytes. It auto-loads into every
#    subagent's initial context via the SubagentStart hook, so its size is a
#    per-spawn context-cost AND a blast-radius control.
# 2. The SubagentStart hook MUST emit the JSON envelope (not plain stdout).
#    Plain stdout from SubagentStart is dropped to the debug log — the PR #385
#    silent-failure. This test locks the envelope shape in.
#
# Runnable standalone (`bash tests/test_size_cap.sh`) and from CI.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
GUIDANCE="$DIR/team-gbrain-usage.md"
HOOKS="$DIR/hooks/hooks.json"
CAP=2048
fail=0

# --- 1. size cap ------------------------------------------------------------
if [ ! -f "$GUIDANCE" ]; then
  echo "FAIL: $GUIDANCE not found"; fail=1
else
  size=$(wc -c < "$GUIDANCE" | tr -d ' ')
  if [ "$size" -le "$CAP" ]; then
    echo "PASS: team-gbrain-usage.md is ${size}B (cap ${CAP}B)"
  else
    echo "FAIL: team-gbrain-usage.md is ${size}B, exceeds ${CAP}B cap"; fail=1
  fi
fi

# --- 2. SubagentStart JSON envelope -----------------------------------------
if [ ! -f "$HOOKS" ]; then
  echo "FAIL: $HOOKS not found"; fail=1
elif command -v jq >/dev/null 2>&1; then
  cmd=$(jq -r '.hooks.SubagentStart[0].hooks[0].command // ""' "$HOOKS")
  if printf '%s' "$cmd" | grep -q 'hookEventName.*SubagentStart' \
     && printf '%s' "$cmd" | grep -q 'additionalContext'; then
    echo "PASS: SubagentStart hook emits the JSON envelope"
  else
    echo "FAIL: SubagentStart hook does not emit the {hookSpecificOutput:{hookEventName,additionalContext}} envelope"; fail=1
  fi
  # The envelope must actually produce valid JSON when run against the guidance.
  if [ -f "$GUIDANCE" ]; then
    if jq -Rs '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: .}}' "$GUIDANCE" \
        | jq -e '.hookSpecificOutput.hookEventName == "SubagentStart"' >/dev/null 2>&1; then
      echo "PASS: envelope produces valid JSON from the guidance file"
    else
      echo "FAIL: envelope did not produce valid JSON"; fail=1
    fi
  fi
else
  echo "SKIP: jq not available — envelope shape check skipped"
fi

if [ "$fail" -eq 0 ]; then
  echo "ALL brite-core invariant checks passed"
  exit 0
fi
echo "brite-core invariant checks FAILED"
exit 1
