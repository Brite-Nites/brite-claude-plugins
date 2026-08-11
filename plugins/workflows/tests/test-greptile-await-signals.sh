#!/usr/bin/env bash
# BC-18961 integration tests for greptile-await.sh's SIGNAL READS.
#
# WHY THIS FILE EXISTS. The classifier is covered by test-greptile-freshness.sh
# and the body parse by test-greptile-verdict.sh. Neither reaches the layer in
# between: the jq programs inside greptile-await.sh that turn GitHub responses
# into `review_ts` / `reviewed_sha` / `head_sha`. That layer was uncovered, and it
# broke during this very fix — the conclusion allow-list was first written as
#
#     select(["success","failure","action_required"] | index(.conclusion // ""))
#
# where `.` inside `index()` is the ALLOW-LIST, not the check-run. It matched
# nothing, emptying review_ts on every poll. Every unit test still passed. Only
# running it against a real PR exposed it. These cases close that hole.
#
# Method: a fake `gh` first on PATH, answering from fixtures. Hermetic — no
# network, fixed timestamps, no `date` calls. Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AWAIT="$PLUGIN_ROOT/scripts/greptile-await.sh"

command -v jq >/dev/null 2>&1      || { echo "fatal: jq required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# ── The measured mission-control#2 timeline ──────────────────────────
SHA_HEAD="2323f2ac830135fb438fecdcfa2a6f57d01ed8c2"
SHA_PREV="cf770b9ebcace90e51d63a7ee5c24eabe699c4a6"
TRIGGER="2026-08-11T17:33:58Z"
ACK_DONE="2026-08-11T17:34:06Z"    # neutral ack — completed AFTER the trigger
REAL_DONE="2026-08-11T17:35:32Z"   # the real review

TMP="$(mktemp -d -t greptile-await-signals.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

# ── The fake `gh` ────────────────────────────────────────────────────
# Dispatches on the same call shapes greptile-await.sh and greptile-verdict.sh
# make. Honours `--jq` the way real gh does (applies the filter to the response),
# because the filter under test is passed that way.
cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
FIX="${GREPTILE_FIXTURES:?}"
args="$*"
emit() { # emit <file> — apply a --jq program if one was requested
  local prog="" want=0 a
  for a in "$@"; do
    if [ "$want" = 1 ]; then prog="$a"; want=0; fi
    [ "$a" = "--jq" ] && want=1
  done
  if [ -n "$prog" ]; then jq -r "$prog" < "$1"; else cat "$1"; fi
}
case "$args" in
  *"--json headRepositoryOwner,headRepository"*) echo "Brite-Nites/mission-control" ;;
  *"--json headRefOid"*)
    # head_fails.txt lets a test simulate N consecutive transient `gh` failures
    # before the call starts succeeding — the TLS-error shape seen live.
    n="$(cat "$FIX/head_fails.txt" 2>/dev/null || echo 0)"
    if [ "${n:-0}" -gt 0 ]; then
      echo $((n - 1)) > "$FIX/head_fails.txt"
      echo "fake gh: transient failure" >&2
      exit 1
    fi
    cat "$FIX/head_sha.txt" ;;
  *"--json url"*)         echo "https://github.com/Brite-Nites/mission-control/pull/2" ;;
  *"--json comments,reviews"*) cat "$FIX/comments.json" ;;
  *check-runs*)           emit "$FIX/check-runs.json" "$@" ;;
  *"/issues/2/comments"*) cat "$FIX/issue-comments.json" ;;
  *) echo "fake gh: unhandled call: $args" >&2; exit 1 ;;
esac
STUB
chmod +x "$TMP/bin/gh"

export GREPTILE_FIXTURES="$TMP/fix"
mkdir -p "$GREPTILE_FIXTURES"
echo '[]' > "$GREPTILE_FIXTURES/issue-comments.json"

# check_runs <json-array-body>
set_check_runs() { printf '{"total_count":9,"check_runs":%s}\n' "$1" > "$GREPTILE_FIXTURES/check-runs.json"; }
# summary <bound-sha|""> <score>
set_summary() {
  local sha="$1" score="$2" footer=""
  [ -n "$sha" ] && footer="<sub>Reviews (2): Last reviewed commit: [\\\"msg\\\"](https://github.com/brite-nites/mission-control/commit/$sha)</sub>"
  printf '{"comments":[{"id":"IC_summary","author":{"login":"greptile-apps"},"body":"<h3>Confidence Score: %s/5</h3>\\n\\n%s","createdAt":"2026-08-11T17:15:30Z"}],"reviews":[]}\n' \
    "$score" "$footer" > "$GREPTILE_FIXTURES/comments.json"
}
echo "$SHA_HEAD" > "$GREPTILE_FIXTURES/head_sha.txt"

# run_await [max-wait] — default 0, which puts the deadline AT the trigger so a
# single non-fresh poll lands on TIMED_OUT instead of sleeping. Pass a large
# max-wait to let the loop actually poll more than once.
#
# Always wrapped in `timeout`: a multi-poll case that fails to converge would
# otherwise spin for the whole max-wait. A prior regression test in this repo
# hung the code it was testing; this harness fails in seconds instead.
echo 0 > "$GREPTILE_FIXTURES/head_fails.txt"
run_await() {
  local out
  set +e
  out="$(PATH="$TMP/bin:$PATH" timeout 30 bash "$AWAIT" --pr 2 --trigger "$TRIGGER" \
          --max-wait "${1:-0}" --interval 1 2>"$TMP/stderr")"
  set -e
  STATE="$(printf '%s' "$out" | tail -1)"
  TRACE="$(cat "$TMP/stderr")"
}

assert_state() {
  if [ "$STATE" = "$2" ]; then pass "$1 → $2"; else fail "$1: expected $2, got '$STATE' (trace: $TRACE)"; fi
}
assert_trace() {
  case "$TRACE" in *"$2"*) pass "$1" ;; *) fail "$1: trace lacks '$2' — got: $TRACE" ;; esac
}

# ── 1. THE INCIDENT, end to end through the real signal reads ────────
# Neutral ack completed 8s after the trigger; the real review has not started.
# Summary still bound to the PREVIOUS head. This returned FRESH_PASS before.
section 1 "INCIDENT — neutral ack post-trigger, summary bound to previous head"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"neutral\",\"completed_at\":\"$ACK_DONE\"}]"
set_summary "$SHA_PREV" 5
run_await
assert_state "incident-not-a-pass" "TIMED_OUT"
assert_trace "incident trace names the mismatch" "MISMATCH"

# ── 2. the ack alone must NOT populate review_ts ─────────────────────
# Pins the conclusion allow-list from the "excluded" side.
section 2 "conclusion filter — a lone neutral ack yields no review_ts"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"neutral\",\"completed_at\":\"$ACK_DONE\"}]"
set_summary "$SHA_HEAD" 5
run_await
assert_trace "neutral ack excluded" "review_ts=-"
assert_state "ack-alone-is-not-fresh" "TIMED_OUT"

# ── 3. a real verdict MUST populate review_ts ────────────────────────
# The case that catches an allow-list matching nothing. Without this, the jq bug
# described in the header ships silently: review_ts empty forever reads as a
# safe-looking TIMED_OUT, and every unit test still passes.
section 3 "conclusion filter — a success run IS counted, and wins over the ack"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"neutral\",\"completed_at\":\"$ACK_DONE\"},{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"success\",\"completed_at\":\"$REAL_DONE\"}]"
set_summary "$SHA_HEAD" 5
run_await
assert_trace "review_ts is the success run, not the ack" "review_ts=$REAL_DONE"
assert_state "real-review-bound-to-head" "FRESH_PASS"

# ── 4. an in-progress run contributes nothing ────────────────────────
section 4 "in-progress check-run yields no review_ts"
set_check_runs '[{"name":"Greptile Review","status":"in_progress","conclusion":null,"completed_at":null}]'
set_summary "$SHA_HEAD" 5
run_await
assert_trace "in-progress excluded" "review_ts=-"

# ── 5. identity overrules a genuine, completed review ────────────────
# The real review finished — but on a commit that is no longer the head.
section 5 "success run + summary bound to previous head → never a pass"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"success\",\"completed_at\":\"$REAL_DONE\"}]"
set_summary "$SHA_PREV" 5
run_await
assert_state "identity-overrules-time" "TIMED_OUT"

# ── 6. unreadable footer → UNBOUND, not a pass and not silence ───────
section 6 "summary with no commit footer → UNBOUND"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"success\",\"completed_at\":\"$REAL_DONE\"}]"
set_summary "" 5
run_await
assert_state "unreadable-footer" "UNBOUND"
assert_trace "trace says the binding was unreadable" "bound=<unreadable>"

# ── 7. the head is re-read per poll, not pinned at startup ───────────
# A head that moved mid-wait must be the one compared. Pins the resolve-once fix.
section 7 "head SHA is re-read each poll"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"success\",\"completed_at\":\"$REAL_DONE\"}]"
set_summary "$SHA_HEAD" 5
echo "$SHA_PREV" > "$GREPTILE_FIXTURES/head_sha.txt"   # head is NOT what the summary reviewed
run_await
assert_state "moved-head-is-not-a-pass" "TIMED_OUT"
echo "$SHA_HEAD" > "$GREPTILE_FIXTURES/head_sha.txt"

# ── 8. a non-5 score bound to the head still fails, not passes ───────
section 8 "score 3 bound to head → FRESH_FAIL"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"success\",\"completed_at\":\"$REAL_DONE\"}]"
set_summary "$SHA_HEAD" 3
run_await
assert_state "bound-but-failing" "FRESH_FAIL"

# ── 9. a transient head-resolution failure RECOVERS on the next poll ─
# Raised by Greptile on PR #580, and correctly. The head is re-read every poll so
# a `gh` flake can clear — but the first draft routed an empty head to the
# terminal UNBOUND, which ended the wait on exactly the failure the re-read was
# added to survive. `gh` fails once here, then succeeds; the wait must continue
# and then pass. Multi-poll on purpose: every other case here is single-poll,
# which is why the defect got through.
section 9 "transient gh failure on the head → wait continues, next poll passes"
set_check_runs "[{\"name\":\"Greptile Review\",\"status\":\"completed\",\"conclusion\":\"success\",\"completed_at\":\"$REAL_DONE\"}]"
set_summary "$SHA_HEAD" 5
echo 1 > "$GREPTILE_FIXTURES/head_fails.txt"     # fail once, then recover
run_await 86400                                   # deadline far out, so it polls again
assert_state "transient-head-failure-recovers" "FRESH_PASS"
assert_trace "first poll shows the unresolved head" "head=<unresolved>"
if [ "$(grep -c '^poll=' "$TMP/stderr")" -ge 2 ]; then
  pass "the wait actually polled more than once"
else
  fail "expected >=2 polls, trace shows: $TRACE"
fi
echo 0 > "$GREPTILE_FIXTURES/head_fails.txt"

# ── 10. an unresolved head still never becomes a pass ────────────────
# The recovery in case 9 must not weaken the safety property. With `gh` failing
# every time, the wait is bounded and ends without a verdict — never FRESH_*.
section 10 "head never resolves → bounded TIMED_OUT, never a pass"
echo 99 > "$GREPTILE_FIXTURES/head_fails.txt"     # fails on every poll
run_await 3
assert_state "unresolved-head-never-passes" "TIMED_OUT"
echo 0 > "$GREPTILE_FIXTURES/head_fails.txt"

# ── 11. no Greptile verdict at all — fields must not shift ───────────
# A {"present":false} verdict emits three EMPTY fields in a row. The first draft
# joined them with a tab, and tab is IFS *whitespace* — bash collapses runs of it
# and strips trailing ones, so every field after the first empty one shifted:
# `present` landed empty and `vts` got the literal string "false". Caught in the
# live gate trace for this PR (`poll=4 … score=null verdict_ts=false`), not by
# any test. The delimiter is now 0x1F, which is not IFS whitespace.
#
# It failed safe — an empty `present` reads as "no verdict" → keep waiting — so
# this case asserts the state AND the trace, because only the trace shows the
# corruption. A test on state alone would have passed against the bug.
section 11 "absent verdict — empty fields must not shift the parse"
set_check_runs '[]'
printf '{"comments":[],"reviews":[]}\n' > "$GREPTILE_FIXTURES/comments.json"
run_await
assert_state "absent-verdict-still-waits" "TIMED_OUT"
assert_trace "score reads as null" "score=null"
assert_trace "verdict_ts is empty, NOT the string 'false'" "verdict_ts=-"
case "$TRACE" in
  *"verdict_ts=false"*) fail "field shift: 'false' leaked into verdict_ts — $TRACE" ;;
  *) pass "no field shift — 'present' did not leak into an earlier field" ;;
esac

# ──────────────────────────────────────────────────────────────────────
printf '\nBC-18961 greptile-await signal-read tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
