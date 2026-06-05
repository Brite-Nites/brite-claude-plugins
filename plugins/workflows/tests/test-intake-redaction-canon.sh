#!/usr/bin/env bash
# BC-12535 (M1) — canonical secret-redaction list lint.
#
# Invariant: the secret-redaction pattern list lives in ONE canonical source,
# plugins/workflows/commands/_shared/intake-redaction.md. The intake front door
# (raise-a-ticket) and its agent-tooling alias (report-issue) CITE that file;
# neither inlines a divergent copy. The prior "keep both in sync — update both
# together" note was a drift hazard: a new pattern had to be added in two places,
# and the v3.37.0 UAT found three (eyJ / api_key= / AIza) missing from BOTH copies.
#
# Rubric-lock grep-triad (per the BC-10730 / test-intake-option-cap.sh precedent):
#   COMPLETENESS — the shared list carries every required pattern AS A LIST ENTRY
#                  (backtick-wrapped), including the three UAT-added ones.
#   POSITIVE     — both commands reference the shared file by path.
#   NEGATIVE     — neither command inlines a divergent secret list: a command body
#                  carrying >= 3 backtick-wrapped canonical patterns is a re-inlined
#                  copy. Detecting the BACKTICK-WRAPPED form (the format a real
#                  list uses) guards ALL 21 patterns (high recall) while avoiding
#                  the substring false-positives that counting bare tokens would
#                  hit — e.g. "sk-" inside "task-", or "token:" / "Bearer " in
#                  narrative prose, which are NOT wrapped as standalone patterns.
#   SELF-TEST    — the negative discriminates a divergent copy (must flag, incl. a
#                  re-inline of just the 3 UAT patterns) from a bare citation and
#                  from a single backticked example (both must allow), so a future
#                  loosening can't rot.
#
# Hand-rolled assertion harness (no bats dep). Bash 3.2 compatible (macOS
# default). Auto-discovered by validate.sh Section 2e; emits RESULT pass=N.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CMD_DIR="$PLUGIN_ROOT/commands"
RAISE="$CMD_DIR/raise-a-ticket.md"
REPORT="$CMD_DIR/report-issue.md"
SHARED="$CMD_DIR/_shared/intake-redaction.md"
CITE="_shared/intake-redaction.md"
BT='`'   # backtick, kept in a var to avoid escaping it inside double-quoted greps

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ── Pattern set ──────────────────────────────────────────────────────
# The canonical patterns — the shared list must carry ALL of these as list
# entries (completeness), including the three UAT adds at the tail. The negative
# check counts how many appear BACKTICK-WRAPPED in a command body.
REQUIRED=( 'Bearer ' 'password=' 'password:' 'token=' 'token:' 'sk-' 'AKIA' \
  'postgres://' 'mongodb+srv://' 'redis://' 'ghp_' 'gho_' 'glpat-' 'xoxb-' \
  'xoxp-' 'hooks.slack.com' 'PRIVATE KEY' '-----BEGIN' 'eyJ' 'api_key=' 'AIza' )

# Count how many REQUIRED patterns appear backtick-wrapped (`pattern`) in a file.
count_wrapped() {
  local f="$1" n=0 p
  for p in "${REQUIRED[@]}"; do
    if grep -Fq -- "${BT}${p}${BT}" "$f" 2>/dev/null; then n=$((n + 1)); fi
  done
  printf '%s' "$n"
}

# ── Assertions ───────────────────────────────────────────────────────
assert_shared_has() {
  local p="$1"
  if grep -Fq -- "${BT}${p}${BT}" "$SHARED" 2>/dev/null; then
    pass "shared list carries pattern as a list entry: $p"
  else
    fail "shared list MISSING pattern (or not backtick-wrapped as an entry): $p"
  fi
}

assert_cites() {
  local label="$1" file="$2"
  if grep -Fq -- "$CITE" "$file" 2>/dev/null; then
    pass "$label cites the canonical list ($CITE)"
  else
    fail "$label does NOT cite $CITE (must reference the shared list, not inline one)"
  fi
}

assert_no_inline() {
  local label="$1" file="$2" n
  n=$(count_wrapped "$file")
  if [ "$n" -lt 3 ]; then
    pass "$label: no inlined divergent list ($n backtick-wrapped canonical patterns)"
  else
    fail "$label: inlines a divergent redaction list ($n backtick-wrapped patterns — cite $CITE instead)"
  fi
}

# ── Preconditions (RAISE/REPORT always exist; SHARED is asserted) ─────
for f in "$RAISE" "$REPORT"; do
  [ -f "$f" ] || { echo "fatal: missing $f" >&2; exit 2; }
done
if [ -f "$SHARED" ]; then
  pass "canonical redaction file exists: $CITE"
else
  fail "canonical redaction file missing: $CITE"
fi

# ── Completeness ─────────────────────────────────────────────────────
for p in "${REQUIRED[@]}"; do
  assert_shared_has "$p"
done

# ── Positive: both commands cite the shared list ─────────────────────
assert_cites "raise-a-ticket" "$RAISE"
assert_cites "report-issue"   "$REPORT"

# ── Negative: neither command inlines a divergent list ───────────────
assert_no_inline "raise-a-ticket" "$RAISE"
assert_no_inline "report-issue"   "$REPORT"

# ── Self-test (mutation guard): the negative must discriminate ───────
tmp_copy="$(mktemp 2>/dev/null || echo /tmp/m1copy.$$)"
tmp_uat="$(mktemp 2>/dev/null || echo /tmp/m1uat.$$)"
tmp_cite="$(mktemp 2>/dev/null || echo /tmp/m1cite.$$)"
tmp_example="$(mktemp 2>/dev/null || echo /tmp/m1ex.$$)"
printf 'Patterns: `Bearer `, `AKIA`, `postgres://`, `ghp_`\n' > "$tmp_copy"     # full-style divergent copy
printf 'Patterns: `eyJ`, `api_key=`, `AIza`\n'              > "$tmp_uat"      # re-inline of JUST the 3 UAT patterns
printf 'Redact secrets per the shared list — see %s\n' "$CITE" > "$tmp_cite"  # bare citation
printf 'redact bearer headers like `Bearer ` before filing\n' > "$tmp_example"  # single backticked example
if [ "$(count_wrapped "$tmp_copy")" -ge 3 ]; then
  pass "self-test: divergent-copy string is flagged ($(count_wrapped "$tmp_copy") wrapped patterns)"
else
  fail "self-test: divergent-copy string was NOT flagged (negative rotted)"
fi
if [ "$(count_wrapped "$tmp_uat")" -ge 3 ]; then
  pass "self-test: re-inline of the 3 UAT patterns is flagged (the gap the M1 lint exists to close)"
else
  fail "self-test: re-inline of the 3 UAT patterns was NOT flagged (recall gap reopened)"
fi
if [ "$(count_wrapped "$tmp_cite")" -lt 3 ]; then
  pass "self-test: bare-citation string is allowed"
else
  fail "self-test: bare-citation string was false-flagged (negative too broad)"
fi
if [ "$(count_wrapped "$tmp_example")" -lt 3 ]; then
  pass "self-test: single backticked example is allowed (precision held)"
else
  fail "self-test: single backticked example was false-flagged (threshold too tight)"
fi
rm -f "$tmp_copy" "$tmp_uat" "$tmp_cite" "$tmp_example"

# ── Result ───────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT pass=$PASS fail=0"
  exit 0
else
  echo "RESULT pass=$PASS fail=$FAIL"
  exit 1
fi
