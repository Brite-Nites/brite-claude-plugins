#!/usr/bin/env bash
# BC-12249 (greptile-gate Slice 2) unit tests for the freshness classifier.
#
#   plugins/workflows/scripts/greptile-freshness.sh
#     --trigger <iso8601>     when the re-review was requested
#     --now <iso8601>         current time (injected; defaults to now in prod)
#     --deadline <iso8601>    trigger + max-wait
#     --verdict-ts <iso8601>  commented_at of the latest Greptile comment (or empty)
#     --score <0-5|null>      score from the latest Greptile verdict (or empty)
#
# Prints exactly one state:
#   FRESH_PASS   fresh review (verdict_ts > trigger) with score == 5
#   FRESH_FAIL   fresh review with score != 5 (incl. null)
#   PENDING      no fresh review yet, still within the deadline
#   TIMED_OUT    no fresh review and now >= deadline
#
# The classifier core is pure (ISO-8601 parse + compare via python3, robust
# across BSD/GNU date); the poll/sleep wait-loop is a thin shell around it.
# Hand-rolled assertion harness. Bash 3.2 compatible. Hermetic — all
# timestamps are fixed literals, no `date` calls.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRESH="$PLUGIN_ROOT/scripts/greptile-freshness.sh"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

# Fixed timeline (UTC):
TRIGGER="2026-06-01T12:00:00Z"
TS_FRESH="2026-06-01T12:05:00Z"   # after trigger
TS_STALE="2026-06-01T11:55:00Z"   # before trigger
NOW_OPEN="2026-06-01T12:03:00Z"   # before deadline
NOW_PAST="2026-06-01T12:11:00Z"   # after deadline
DEADLINE="2026-06-01T12:10:00Z"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

run_capture() {
  local err
  err="$(mktemp -t greptile-freshness-stderr.XXXXXX)"
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

# ── 1. Tracer bullet: fresh review, score 5, within window → FRESH_PASS ─
section 1 "fresh review, score 5, within window"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5
assert_state "fresh+5" "FRESH_PASS"

# ── 2. Fresh review, score 3 → FRESH_FAIL ────────────────────────────
section 2 "fresh review, score 3 (below pass)"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 3
assert_state "fresh+3" "FRESH_FAIL"

# ── 3. Fresh review, score null → FRESH_FAIL ─────────────────────────
section 3 "fresh review, no parseable score"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score null
assert_state "fresh+null" "FRESH_FAIL"

# ── 4. No Greptile comment yet, within window → PENDING ──────────────
section 4 "no verdict yet, within window"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "" --score ""
assert_state "no-verdict" "PENDING"

# ── 5. Stale verdict (<= trigger), within window → PENDING ───────────
# A pre-trigger Greptile comment must NOT count as a fresh re-review.
section 5 "stale verdict (pre-trigger), within window"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --score 5
assert_state "stale+5" "PENDING"

# ── 6. No fresh verdict, past deadline → TIMED_OUT ───────────────────
section 6 "no fresh verdict, past deadline"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "" --score ""
assert_state "timeout" "TIMED_OUT"

# ── 7. Boundary: now == deadline → TIMED_OUT (>= deadline) ───────────
section 7 "boundary — now exactly at deadline"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$DEADLINE" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --score 5
assert_state "now==deadline" "TIMED_OUT"

# ──────────────────────────────────────────────────────────────────────
printf '\nBC-12249 greptile-freshness unit tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
