#!/usr/bin/env bash
# BC-12248 (greptile-gate Slice 1) unit tests for the greptile-verdict reader.
#
#   plugins/workflows/scripts/greptile-verdict.sh
#     --comments-file <path>   pure path: parse a gh-shaped PR-comments JSON
#                              array → single-line JSON verdict on stdout.
#     --pr <number|url>        IO path: gh pr view … --json comments, then the
#                              same parser. (Not exercised here — network.)
#
# Verdict shape:
#   {"present":true,"score":3,"comment_id":"…","commented_at":"…"}
#   {"present":false}                              (no Greptile bot comment)
#   score is null when a Greptile comment exists but has no parseable score.
#
# Hand-rolled assertion harness (no bats-core dep). Bash 3.2 compatible
# (macOS default). Requires jq (used by both the helper and these tests).

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERDICT="$PLUGIN_ROOT/scripts/greptile-verdict.sh"
FIXTURES="$SCRIPT_DIR/fixtures/greptile-verdict"

command -v jq >/dev/null 2>&1 || { echo "fatal: jq required" >&2; exit 2; }

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Run a command; capture stdout/stderr/exit without tripping set -e.
run_capture() {
  local err
  err="$(mktemp -t greptile-verdict-stderr.XXXXXX)"
  set +e
  STDOUT="$("$@" 2>"$err")"
  EXIT=$?
  set -e
  STDERR="$(cat "$err")"
  rm -f "$err"
}

# ── 1. Tracer bullet: a Greptile summary scoring 3/5 ─────────────────
section 1 "happy path — Greptile comment, score 3/5"
run_capture "$VERDICT" --comments-file "$FIXTURES/score-3.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "true" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "3" ]; then
  pass "present:true, score:3"
else
  fail "expected present:true score:3 — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 2. Boundary: score 0/5 (must not be dropped as falsy) ────────────
section 2 "boundary — score 0/5"
run_capture "$VERDICT" --comments-file "$FIXTURES/score-0.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "true" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "0" ]; then
  pass "present:true, score:0"
else
  fail "expected present:true score:0 — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 3. Boundary: score 5/5 (the pass condition) ──────────────────────
section 3 "boundary — score 5/5"
run_capture "$VERDICT" --comments-file "$FIXTURES/score-5.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "true" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "5" ]; then
  pass "present:true, score:5"
else
  fail "expected present:true score:5 — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 4. Skip case: no Greptile bot among authors → present:false ──────
# Fixture's human comment contains "Confidence score 5/5" — verdict must
# still be present:false (keys off the Greptile author, not score text).
section 4 "skip — no Greptile comment → present:false"
run_capture "$VERDICT" --comments-file "$FIXTURES/no-greptile.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "false" ]; then
  pass "present:false"
else
  fail "expected present:false — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 5. Greptile present but no parseable score → score:null ──────────
section 5 "unparseable — Greptile comment, no rating → score:null"
run_capture "$VERDICT" --comments-file "$FIXTURES/greptile-no-score.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "true" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "null" ]; then
  pass "present:true, score:null"
else
  fail "expected present:true score:null — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 6. Multiple Greptile comments → latest by commented_at wins ──────
# Older comment (2/5) listed first, newer (5/5) last, human comment between.
section 6 "most-recent — latest Greptile comment wins (5/5 over earlier 2/5)"
run_capture "$VERDICT" --comments-file "$FIXTURES/multi-greptile.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "5" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.comment_id')" = "IC_greptile_late" ]; then
  pass "score:5 from latest comment (IC_greptile_late)"
else
  fail "expected score:5 comment_id:IC_greptile_late — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 7. Regex bound lock: out-of-range "8/5" is not a valid score ─────
# Locks the [0-5] bound. Mutation [0-5]→[0-9] makes this parse 8 → RED here.
section 7 "regex bound — out-of-range 8/5 → score:null"
run_capture "$VERDICT" --comments-file "$FIXTURES/greptile-out-of-range.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "true" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "null" ]; then
  pass "out-of-range rejected → score:null"
else
  fail "expected score:null for 8/5 — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 8. Intervening digits between "confidence" and the rating ────────
# Locks the label-anchored regex against the REAL Greptile shape: a stray N/5
# in the preamble ("toward 5/5") must NOT win over the "Confidence Score:" line.
# The old non-greedy regex returned 5 here — the bug Greptile flagged on PR #420.
section 8 "preamble fraction — '…toward 5/5 … Confidence Score: 3/5' → 3 (not 5)"
run_capture "$VERDICT" --comments-file "$FIXTURES/greptile-intervening-digits.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "true" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "3" ]; then
  pass "present:true, score:3 (preamble 5/5 doesn't win over the label)"
else
  fail "expected score:3 (label-anchored) — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 9. Greptile summary posted as a REVIEW (not an issue comment) ────
# Locks the comments+reviews union — score lives in a review body.
section 9 "review-union — Greptile review body scored 4/5"
run_capture "$VERDICT" --comments-file "$FIXTURES/greptile-review.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "4" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.comment_id')" = "PRR_greptile" ]; then
  pass "score:4 from review body (PRR_greptile)"
else
  fail "expected score:4 from review — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 10. Equal timestamps → last comment in array order wins ──────────
section 10 "tie-break — equal createdAt, last-in-array wins"
run_capture "$VERDICT" --comments-file "$FIXTURES/greptile-tie-break.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "4" ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.comment_id')" = "IC_tie_b" ]; then
  pass "score:4 from IC_tie_b (stable sort, last wins)"
else
  fail "expected score:4 comment_id:IC_tie_b — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 11. Unparseable input → graceful present:false (no jq crash) ─────
section 11 "malformed — non-JSON input → present:false, exit 0"
run_capture "$VERDICT" --comments-file "$FIXTURES/malformed.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.present')" = "false" ]; then
  pass "present:false on unparseable input"
else
  fail "expected present:false exit 0 — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ── 12. Greptile's real HTML <h3> format with a preamble fraction → 4 ─
# Reproduces PR #420's actual body: "<h3>Confidence Score: 4/5</h3>" with
# "toward 5/5" in the prose above it. The shipped regex returned 5 here.
section 12 "real h3 format — preamble 'toward 5/5' + '<h3>Confidence Score: 4/5</h3>' → 4"
run_capture "$VERDICT" --comments-file "$FIXTURES/greptile-h3-format.json"
if [ "$EXIT" -eq 0 ] \
   && [ "$(printf '%s' "$STDOUT" | jq -r '.score')" = "4" ]; then
  pass "score:4 from the real Greptile h3 label"
else
  fail "expected score:4 from h3 format — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
fi

# ──────────────────────────────────────────────────────────────────────
printf '\nBC-12248 greptile-verdict unit tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
