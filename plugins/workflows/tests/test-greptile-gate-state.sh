#!/usr/bin/env bash
# BC-18947 unit tests for the gate-entry-state classifier.
#
#   plugins/workflows/scripts/greptile-gate-state.sh
#     --verdict '<json>'   a greptile-verdict.sh verdict:
#                          {"present":true|false,"score":<0-5|null>,...}
#
# Prints exactly one state:
#   NO_REVIEWER    verdict.present == false — no Greptile on this repo (or no
#                  review yet). Its own terminal state, distinct from a pass.
#   CONVERGED      verdict.present == true, score == 5
#   NEEDS_ROUND    verdict.present == true, score != 5 (including null)
#
# The defect this locks down (BC-18947): a repo with no Greptile must never
# classify the same as a repo that passed. Hand-rolled assertion harness
# (no bats-core dep). Bash 3.2 compatible. Requires jq.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE="$PLUGIN_ROOT/scripts/greptile-gate-state.sh"

command -v jq >/dev/null 2>&1 || { echo "fatal: jq required" >&2; exit 2; }

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

run_capture() {
  local err
  err="$(mktemp -t greptile-gate-state-stderr.XXXXXX)"
  set +e
  STDOUT="$("$@" 2>"$err")"
  EXIT=$?
  set -e
  STDERR="$(cat "$err")"
  rm -f "$err"
}

assert_state() {
  local label="$1" expected="$2"
  if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "$expected" ]; then
    pass "$label → $expected"
  else
    fail "$label: expected $expected — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
  fi
}

# ── 1. The absent case: Greptile never posted → NO_REVIEWER ─────────
# The core of BC-18947 — this must NOT read as a pass.
section 1 "absent — present:false → NO_REVIEWER, not a pass"
run_capture "$STATE" --verdict '{"present":false}'
assert_state "absent" "NO_REVIEWER"

# ── 2. Converged: present, score 5 → CONVERGED ───────────────────────
section 2 "converged — present:true, score:5"
run_capture "$STATE" --verdict '{"present":true,"score":5,"comment_id":"IC_x","commented_at":"2026-06-01T00:00:00Z"}'
assert_state "converged" "CONVERGED"

# ── 3. Below target: present, score 3 → NEEDS_ROUND ──────────────────
section 3 "below target — present:true, score:3"
run_capture "$STATE" --verdict '{"present":true,"score":3,"comment_id":"IC_x","commented_at":"2026-06-01T00:00:00Z"}'
assert_state "below-target" "NEEDS_ROUND"

# ── 4. Boundary: score 0 must NOT be conflated with absent ───────────
# A reviewed-and-scored-0 PR is a different condition from never-reviewed —
# both are "not a pass" but only one is NO_REVIEWER.
section 4 "boundary — present:true, score:0 → NEEDS_ROUND (not NO_REVIEWER)"
run_capture "$STATE" --verdict '{"present":true,"score":0,"comment_id":"IC_x","commented_at":"2026-06-01T00:00:00Z"}'
assert_state "score-zero" "NEEDS_ROUND"

# ── 5. Present but unparseable score → NEEDS_ROUND ───────────────────
section 5 "present, no parseable score — present:true, score:null"
run_capture "$STATE" --verdict '{"present":true,"score":null,"comment_id":"IC_x","commented_at":"2026-06-01T00:00:00Z"}'
assert_state "null-score" "NEEDS_ROUND"

# ── 6. Fail-open: malformed verdict JSON → NO_REVIEWER, exit 0 ───────
# Never hard-fails the ship — an unreadable verdict degrades to the same
# state as no verdict, matching greptile-verdict.sh's own malformed-input
# handling (present:false on unparseable input).
section 6 "malformed input — garbage JSON → NO_REVIEWER, exit 0 (fail-open)"
run_capture "$STATE" --verdict 'not json'
assert_state "malformed" "NO_REVIEWER"

# ── 7. Missing fields entirely → NO_REVIEWER ──────────────────────────
section 7 "empty object — {} → NO_REVIEWER"
run_capture "$STATE" --verdict '{}'
assert_state "empty-object" "NO_REVIEWER"

# ──────────────────────────────────────────────────────────────────────
printf '\nBC-18947 greptile-gate-state unit tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
