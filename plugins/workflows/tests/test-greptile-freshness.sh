#!/usr/bin/env bash
# BC-12249 (greptile-gate Slice 2) unit tests for the freshness classifier.
#
#   plugins/workflows/scripts/greptile-freshness.sh
#     --trigger <iso8601>     when the re-review was requested
#     --now <iso8601>         current time (injected; defaults to now in prod)
#     --deadline <iso8601>    trigger + max-wait
#     --verdict-ts <iso8601>  commented_at of the latest Greptile comment (or empty)
#     --review-ts <iso8601>   completed_at of the head-SHA Greptile check-run (or empty)
#     --edited-ts <iso8601>   updated_at of the latest edited Greptile comment (or empty)
#     --score <0-5|null>      score from the latest Greptile verdict (or empty)
#     --present <true|false>  whether a Greptile verdict exists at all
#     --reviewed-sha <sha>    the commit the score is bound to (or empty)
#     --head-sha <sha>        the PR's current head (or empty)
#
# Prints exactly one state:
#   FRESH_PASS   bound to head AND a signal advanced past the trigger, score == 5
#   FRESH_FAIL   same, score != 5 (incl. null)
#   PENDING      not yet — includes "score is bound to a DIFFERENT commit"
#   TIMED_OUT    still not, and now >= deadline
#   UNBOUND      a verdict exists but its binding cannot be read (BC-18961)
#
# Cases 1-24 vary the TIME axis with identity held satisfied (via run_fresh).
# Cases 25-34 vary the IDENTITY axis. Cases 35-38 pin the latent trigger hazard.
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

# Commit ids for the identity condition (BC-18961). The pre-existing cases below
# all exercise the TIME axis, so they run with identity held satisfied — a verdict
# that is present and bound to the head. The identity axis gets its own section.
SHA_HEAD="2323f2ac830135fb438fecdcfa2a6f57d01ed8c2"
SHA_PREV="cf770b9ebcace90e51d63a7ee5c24eabe699c4a6"

# Time-axis runner: caller varies the timestamps, identity is pinned satisfied.
run_fresh() {
  run_capture "$FRESH" "$@" --present true --reviewed-sha "$SHA_HEAD" --head-sha "$SHA_HEAD"
}

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

# BC-18987: a bad --trigger is rejected outright (exit non-zero), not
# classified. Distinct from assert_state, which expects EXIT=0 and a printed
# state — a rejection has neither.
assert_rejected() {
  local label="$1" needle="$2"
  if [ "$EXIT" -ne 0 ]; then
    case "$STDERR" in
      *"$needle"*) pass "$label → rejected" ;;
      *) fail "$label: rejected (EXIT=$EXIT) but stderr lacks '$needle' — STDERR=$STDERR" ;;
    esac
  else
    fail "$label: expected rejection (non-zero exit) — EXIT=$EXIT STDOUT=$STDOUT STDERR=$STDERR"
  fi
}

# ── 1. Tracer bullet: fresh review, score 5, within window → FRESH_PASS ─
section 1 "fresh review, score 5, within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5
assert_state "fresh+5" "FRESH_PASS"

# ── 2. Fresh review, score 3 → FRESH_FAIL ────────────────────────────
section 2 "fresh review, score 3 (below pass)"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 3
assert_state "fresh+3" "FRESH_FAIL"

# ── 3. Fresh review, score null → FRESH_FAIL ─────────────────────────
section 3 "fresh review, no parseable score"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score null
assert_state "fresh+null" "FRESH_FAIL"

# ── 4. No Greptile comment yet, within window → PENDING ──────────────
section 4 "no verdict yet, within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "" --score ""
assert_state "no-verdict" "PENDING"

# ── 5. Stale verdict (<= trigger), within window → PENDING ───────────
# A pre-trigger Greptile comment must NOT count as a fresh re-review.
section 5 "stale verdict (pre-trigger), within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --score 5
assert_state "stale+5" "PENDING"

# ── 6. No fresh verdict, past deadline → TIMED_OUT ───────────────────
section 6 "no fresh verdict, past deadline"
run_fresh --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "" --score ""
assert_state "timeout" "TIMED_OUT"

# ── 7. Boundary: now == deadline → TIMED_OUT (>= deadline) ───────────
section 7 "boundary — now exactly at deadline"
run_fresh --trigger "$TRIGGER" --now "$DEADLINE" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --score 5
assert_state "now==deadline" "TIMED_OUT"

# ── 8. Precedence: a fresh 5/5 that lands PAST the deadline → FRESH_PASS
# Locks branch order — fresh must win over timed-out (the await loop relies
# on this: a late-but-fresh pass is still a pass, not a timeout).
section 8 "precedence — fresh 5/5 arriving past deadline"
run_fresh --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5
assert_state "fresh-past-deadline" "FRESH_PASS"

# ── 9. Robustness: garbage verdict-ts → not fresh → PENDING (no crash) ─
section 9 "robust parse — unparseable verdict-ts within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "not-a-timestamp" --score 5
assert_state "garbage-verdict-ts" "PENDING"

# ── BC-16924: --review-ts (head-SHA Greptile check-run completed_at) ─────
# Greptile edits its summary IN PLACE, so a comment's createdAt (verdict-ts)
# never advances past the trigger on a re-review. The head-SHA check-run's
# completed_at DOES advance. Freshness now keys on max(verdict-ts, review-ts),
# so a fresh review-ts rescues a stale verdict-ts. score still gates PASS/FAIL.

# ── 10. THE BUG: stale verdict-ts (in-place edit) + fresh review-ts + 5 → PASS
section 10 "in-place edit — stale verdict-ts, fresh review-ts, score 5"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_FRESH" --score 5
assert_state "stale-verdict+fresh-review+5" "FRESH_PASS"

# ── 11. fresh review-ts, score 3 → FRESH_FAIL ───────────────────────
section 11 "fresh review-ts, score 3"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_FRESH" --score 3
assert_state "fresh-review+3" "FRESH_FAIL"

# ── 12. review-ts alone (verdict-ts empty) fresh + 5 → FRESH_PASS ────
section 12 "review-ts alone (no comment ts), score 5"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "" --review-ts "$TS_FRESH" --score 5
assert_state "review-only-fresh+5" "FRESH_PASS"

# ── 13. backward compat: verdict-ts fresh, review-ts empty + 5 → FRESH_PASS
section 13 "legacy path — verdict-ts fresh, review-ts empty"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --review-ts "" --score 5
assert_state "verdict-only-fresh+5" "FRESH_PASS"

# ── 14. both stale, within window → PENDING ─────────────────────────
section 14 "both verdict-ts and review-ts stale, within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_STALE" --score 5
assert_state "both-stale" "PENDING"

# ── 15. precedence: fresh review-ts past deadline still FRESH_PASS ──
section 15 "fresh review-ts arriving past deadline (fresh > timeout)"
run_fresh --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_FRESH" --score 5
assert_state "fresh-review-past-deadline" "FRESH_PASS"

# ── 16. robust: garbage review-ts + stale verdict-ts → PENDING (no crash)
section 16 "garbage review-ts ignored, verdict-ts stale, within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "not-a-timestamp" --score 5
assert_state "garbage-review-ts" "PENDING"

# ── BC-12580 / BC-17025: --edited-ts (Greptile comment updated_at) ──────
# review-ts has its own blind spot: when Greptile auto-reviews the PUSH, its
# head-SHA check-run completes BEFORE the "@greptile-apps please re-review"
# trigger, so review-ts reads stale too. The only signal that advances is the
# comment's own updated_at when Greptile edits its summary in place.

# ── 17. THE BUG: every other signal stale, comment edited after trigger, 5 → PASS
section 17 "in-place edit — verdict-ts AND review-ts stale, edited-ts fresh, score 5"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_STALE" --edited-ts "$TS_FRESH" --score 5
assert_state "stale-verdict+stale-review+fresh-edit+5" "FRESH_PASS"

# ── 18. fresh edited-ts, score 3 → FRESH_FAIL (score still gates) ────
section 18 "fresh edited-ts, score 3"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_STALE" --edited-ts "$TS_FRESH" --score 3
assert_state "fresh-edit+3" "FRESH_FAIL"

# ── 19. edited-ts alone (no comment ts, no check-run) + 5 → FRESH_PASS ─
section 19 "edited-ts alone, score 5"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "" --review-ts "" --edited-ts "$TS_FRESH" --score 5
assert_state "edit-only-fresh+5" "FRESH_PASS"

# ── 20. all three stale → PENDING (fail-safe direction preserved) ────
section 20 "all three signals stale, within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_STALE" --edited-ts "$TS_STALE" --score 5
assert_state "all-stale" "PENDING"

# ── 21. all three stale, past deadline → TIMED_OUT (genuine no-response) ─
# BC-12580 AC: a real no-response must still time out within the bound.
section 21 "all three stale, past deadline"
run_fresh --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_STALE" --edited-ts "$TS_STALE" --score 5
assert_state "all-stale-past-deadline" "TIMED_OUT"

# ── 22. robust: garbage edited-ts ignored → PENDING (no crash) ───────
section 22 "garbage edited-ts, others stale, within window"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_STALE" --edited-ts "not-a-timestamp" --score 5
assert_state "garbage-edited-ts" "PENDING"

# ── 23. back-compat: --edited-ts omitted entirely behaves as before ───
# The flag is appended LAST in the positional contract, so a caller that never
# passes it (an older skill body, or greptile-await mid-rollout) is unaffected.
section 23 "edited-ts flag omitted — legacy caller"
run_fresh --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --review-ts "" --score 5
assert_state "no-edited-ts-flag" "FRESH_PASS"

# ── 24. precedence: fresh edit past deadline still FRESH_PASS ────────
section 24 "fresh edited-ts arriving past deadline (fresh > timeout)"
run_fresh --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "$TS_STALE" --review-ts "$TS_STALE" --edited-ts "$TS_FRESH" --score 5
assert_state "fresh-edit-past-deadline" "FRESH_PASS"

# ══ BC-18961: the IDENTITY condition ══════════════════════════════════
#
# Time alone reported a pass on a score bound to the previous head. These cases
# vary identity, so they call the classifier directly rather than through
# run_fresh (which pins identity satisfied).

# ── 25. THE INCIDENT, exactly as measured on mission-control#2 ────────
# Greptile put TWO check-runs named "Greptile Review" on head 2323f2a:
#   neutral  started 17:33:44Z  completed 17:34:06Z   <- ack, 8s AFTER the trigger
#   success  started 17:34:10Z  completed 17:35:32Z   <- the real review
# The ack was the only run on that head when the helper polled, so review-ts went
# fresh while the summary still carried cf770b9's 5/5. Every value below is the
# measured artifact. This case returned FRESH_PASS before the fix.
section 25 "INCIDENT — ack check-run fresh, score bound to the PREVIOUS head"
run_capture "$FRESH" --trigger "2026-08-11T17:33:58Z" --now "2026-08-11T17:34:08Z" \
  --deadline "2026-08-11T17:42:58Z" --verdict-ts "2026-08-11T17:15:30Z" \
  --review-ts "2026-08-11T17:34:06Z" --edited-ts "" --score 5 \
  --present true --reviewed-sha "$SHA_PREV" --head-sha "$SHA_HEAD"
assert_state "incident-ack-run-vs-previous-head" "PENDING"

# ── 26. same moment, once the REAL review lands and rebinds to head ───
section 26 "INCIDENT resolved — real review completes, summary rebinds to head"
run_capture "$FRESH" --trigger "2026-08-11T17:33:58Z" --now "2026-08-11T17:35:40Z" \
  --deadline "2026-08-11T17:42:58Z" --verdict-ts "2026-08-11T17:15:30Z" \
  --review-ts "2026-08-11T17:35:32Z" --edited-ts "2026-08-11T17:35:31Z" --score 5 \
  --present true --reviewed-sha "$SHA_HEAD" --head-sha "$SHA_HEAD"
assert_state "incident-resolved" "FRESH_PASS"

# ── 27. identity overrules time, even past the deadline ───────────────
# Locks branch order the other way from case 8: a fresh-by-time signal must NOT
# promote a score bound to another commit, and running out the clock must not
# either. A mismatch is never a pass.
section 27 "mismatched SHA past deadline → TIMED_OUT, never FRESH"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --review-ts "$TS_FRESH" --edited-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "$SHA_PREV" --head-sha "$SHA_HEAD"
assert_state "mismatch-past-deadline" "TIMED_OUT"

# ── 28. UNBOUND: verdict present, footer unreadable ───────────────────
# Greptile changes its summary format → reviewed_sha is null. Must NOT fall back
# to timestamps (that is the hole BC-18961 opened) and must NOT read as silence.
section 28 "unreadable footer + otherwise-passing signals → UNBOUND"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --review-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "" --head-sha "$SHA_HEAD"
assert_state "unreadable-footer" "UNBOUND"

# ── 29. head unresolved is TRANSIENT → PENDING, not UNBOUND ───────────
# `api.github.com` threw TLS errors three times during the incident run, so an
# unresolvable head is a live failure mode, not a hypothetical. It must stay
# recoverable: the head is re-read every poll precisely so a flake can clear, and
# returning a terminal state here would throw that away. Distinct from case 28 —
# an absent footer never recovers, a failed API call often does.
section 29 "head SHA unresolved (transient) → PENDING, recoverable"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "$SHA_HEAD" --head-sha ""
assert_state "head-unresolved-recoverable" "PENDING"

# ── 29b. …but it is still bounded, and still never a pass ─────────────
section "29b" "head unresolved past the deadline → TIMED_OUT, never FRESH"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_PAST" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "$SHA_HEAD" --head-sha ""
assert_state "head-unresolved-bounded" "TIMED_OUT"

# ── 30. no verdict at all is PENDING, not UNBOUND ─────────────────────
# UNBOUND means "a verdict exists that I cannot bind". Silence still means wait.
section 30 "no verdict yet → PENDING (not UNBOUND)"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "" --score "" --present false --reviewed-sha "" --head-sha "$SHA_HEAD"
assert_state "absent-verdict-not-unbound" "PENDING"

# ── 31. abbreviated SHA on either side still matches ──────────────────
section 31 "abbreviated reviewed-sha matches full head"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "2323f2a" --head-sha "$SHA_HEAD"
assert_state "abbrev-sha-match" "FRESH_PASS"

# ── 32. case-insensitive comparison ───────────────────────────────────
section 32 "uppercase reviewed-sha matches lowercase head"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "2323F2AC830135FB438FECDCFA2A6F57D01ED8C2" --head-sha "$SHA_HEAD"
assert_state "case-insensitive-sha" "FRESH_PASS"

# ── 33. a non-SHA value cannot match by accident ──────────────────────
# Guards the prefix tolerance in case 31: prefix matching must not let junk
# through. Anything that is not 7-40 hex chars is treated as unreadable.
section 33 "garbage reviewed-sha → UNBOUND, never a match"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "not-a-sha" --head-sha "$SHA_HEAD"
assert_state "garbage-sha" "UNBOUND"

# ── 34. too-short hex is not a SHA either ─────────────────────────────
section 34 "3-char hex reviewed-sha → UNBOUND (below the 7-char floor)"
run_capture "$FRESH" --trigger "$TRIGGER" --now "$NOW_OPEN" --deadline "$DEADLINE" \
  --verdict-ts "$TS_FRESH" --score 5 \
  --present true --reviewed-sha "232" --head-sha "$SHA_HEAD"
assert_state "short-sha" "UNBOUND"

# ══ BC-18961 / BC-18987: the trigger hazard ════════════════════════════
#
# NOT the cause of the BC-18961 incident — the trigger actually passed was a
# correct Z-form UTC timestamp (2026-08-11T17:33:58Z, confirmed from the
# session transcript). But the sweep that cleared it found a real second
# defect, fixed separately under BC-18987: parse() failed ASYMMETRICALLY.
# Unparseable input returned None and degraded to PENDING, which is safe.
# Input that was only PARTIALLY parseable — no timezone, or date-only — was
# silently stamped UTC and could land hours in the past, making any old
# comment look fresh. Nothing validated the trigger.
#
# BC-18961's SHA identity binding contained this at the time these cases were
# written: a wrong trigger could not manufacture a pass, because the SHA check
# is not time-based. BC-18987 has since closed the hazard at its source —
# --trigger is now validated up front and a naive/date-only value is REJECTED
# (exit non-zero) before identity is ever consulted (see parse_trigger() and
# assert_rejected() above).
#
# Cases 35-36 (syntactically invalid triggers) now assert that rejection
# directly. Case 37 (a trigger that is syntactically valid but semantically
# wrong — reused from an earlier round) is untouched by the parser fix, since
# nothing about its FORMAT is invalid; it still relies on the SHA mismatch, so
# it still asserts PENDING. Case 38 shows the two fixes stacked: the same input
# as 35, but with identity satisfied — proof that rejection now happens
# independently of identity, not merely alongside it.

# ── 35. naive local-time trigger, score bound to the WRONG head ───────
# Format is invalid regardless of SHA — parse_trigger() rejects it before
# identity is checked.
section 35 "hazard — naive local-time trigger is rejected outright (BC-18987)"
run_capture "$FRESH" --trigger "2026-08-11T12:33:58" --now "2026-08-11T17:34:08Z" \
  --deadline "2026-08-11T17:42:58Z" --verdict-ts "2026-08-11T17:15:30Z" --score 5 \
  --present true --reviewed-sha "$SHA_PREV" --head-sha "$SHA_HEAD"
assert_rejected "hazard-naive-local-trigger" "no UTC offset"

# ── 36. date-only trigger, score bound to the WRONG head ──────────────
section 36 "hazard — date-only trigger is rejected outright (BC-18987)"
run_capture "$FRESH" --trigger "2026-08-11" --now "2026-08-11T17:34:08Z" \
  --deadline "2026-08-11T17:42:58Z" --verdict-ts "2026-08-11T17:15:30Z" --score 5 \
  --present true --reviewed-sha "$SHA_PREV" --head-sha "$SHA_HEAD"
assert_rejected "hazard-date-only-trigger" "no UTC offset"

# ── 37. reused earlier-round trigger, score bound to the WRONG head ───
# A valid, timezone-aware timestamp — just the wrong ROUND's. BC-18987 only
# validates format, not provenance, so this is still exactly what the SHA
# identity binding exists to contain. Unchanged by the parser fix.
section 37 "hazard — reused round-1 trigger cannot promote a stale binding"
run_capture "$FRESH" --trigger "2026-08-11T17:12:56Z" --now "2026-08-11T17:34:08Z" \
  --deadline "2026-08-11T17:42:58Z" --verdict-ts "2026-08-11T17:15:30Z" --score 5 \
  --present true --reviewed-sha "$SHA_PREV" --head-sha "$SHA_HEAD"
assert_state "hazard-reused-trigger" "PENDING"

# ── 38. the same naive trigger as 35, now with identity SATISFIED ─────
# Before BC-18987, this exact input (naive trigger, matching SHA) was the case
# that proved 35-37's PENDING came from identity, not from the trigger being
# sound — it printed FRESH_PASS on a pre-trigger comment. Now rejection fires
# before identity is even read, so the outcome here matches case 35 exactly:
# the parser closes the gap directly, rather than relying on containment to
# catch what it lets through.
section 38 "hazard is closed — naive trigger rejected even with matching SHA"
run_capture "$FRESH" --trigger "2026-08-11T12:33:58" --now "2026-08-11T17:34:08Z" \
  --deadline "2026-08-11T17:42:58Z" --verdict-ts "2026-08-11T17:15:30Z" --score 5 \
  --present true --reviewed-sha "$SHA_HEAD" --head-sha "$SHA_HEAD"
assert_rejected "hazard-demonstrated" "no UTC offset"

# ──────────────────────────────────────────────────────────────────────
printf '\nBC-12249 greptile-freshness unit tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
