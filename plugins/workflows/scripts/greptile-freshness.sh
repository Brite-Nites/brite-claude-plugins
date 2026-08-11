#!/usr/bin/env bash
# greptile-freshness.sh — classify the state of a Greptile re-review wait.
#
#   --trigger <iso8601>     when the re-review was requested. Must carry a UTC
#                           offset (e.g. a trailing Z) — a naive or date-only
#                           value is REJECTED (exit non-zero), not coerced, per
#                           BC-18987: it anchors every comparison below, so a
#                           silent misparse there is a confident wrong answer,
#                           not an absent one.
#   --now <iso8601>         current time
#   --deadline <iso8601>    trigger + max-wait (the anti-hang bound)
#   --verdict-ts <iso8601>  commented_at of the latest Greptile comment (empty if none)
#   --review-ts <iso8601>   completed_at of the head-SHA Greptile check-run (empty if none)
#   --edited-ts <iso8601>   updated_at of the latest edited Greptile comment (empty if none)
#   --score <0-5|null>      score from the latest Greptile verdict (empty/null if none)
#   --present <true|false>  whether a Greptile verdict exists at all
#   --reviewed-sha <sha>    the commit the score is BOUND to (summary footer; empty if unreadable)
#   --head-sha <sha>        the PR's current head commit (empty if unresolved)
#
# Prints exactly one state:
#   FRESH_PASS  score is bound to the head AND a signal advanced past the trigger, score == 5
#   FRESH_FAIL  same, score != 5 (including null)
#   PENDING     not yet — includes "the score is bound to a DIFFERENT commit"
#   TIMED_OUT   still not, and now >= deadline
#   UNBOUND     a verdict exists but its FOOTER cannot be read — cannot verify, never a pass
#
# UNBOUND vs PENDING when identity is unavailable — the distinction is which
# failure recovers. An unreadable footer does not: polling cannot make it appear,
# so it is terminal. An unresolved HEAD does: it means `gh` threw, and the next
# poll re-reads it. Collapsing the two would end a wait on a transient network
# error, which is why they are separate branches below.
#
# TWO CONDITIONS, BOTH REQUIRED (BC-18961)
#
#   1. IDENTITY  reviewed_sha == head_sha. Answers "is this score about MY head?"
#   2. TIME      max(verdict_ts, review_ts, edited_ts) > trigger. Answers "did a
#                review land since I asked?"
#
# Neither alone is sufficient, which is why both are kept:
#
#   Identity alone fails when a re-review is requested WITHOUT a new push — the
#   old summary already names the head, so a stale score would read as fresh.
#   Time alone is what broke on mission-control#2: Greptile put TWO check-runs
#   named "Greptile Review" on one head, and the first completed with conclusion
#   `neutral` eight seconds after the trigger while the summary still carried the
#   PREVIOUS head's 5/5. Time said "fresh", identity would have said "not yours".
#
# UNBOUND exists because a pass we cannot verify is not a pass. Silently falling
# back to timestamps when the footer is unreadable would restore exactly the hole
# BC-18961 opened, and BC-18947 already settled the principle for this helper
# family: absence gets its own state, never a pass.
#
# TRIGGER VALIDATION (BC-18987). Every OTHER timestamp here degrades gracefully
# on bad input — unparseable becomes empty, which reads as PENDING (see the
# --review-ts / --edited-ts robustness cases in the test suite). --trigger does
# NOT get that treatment. A garbage trigger is obviously wrong and safely
# absent; a naive or date-only trigger PARSES — it just silently means the
# wrong instant, one that can sit hours in the past — which lets it promote a
# pre-trigger comment to FRESH_PASS. Coercing it to UTC (the old behaviour) was
# exactly backwards: it made the near-miss more dangerous than garbage, not
# less. So --trigger is checked up front and rejected outright (exit non-zero)
# rather than fed through the lenient parser. The SHA identity binding
# (BC-18961) still contains this hazard for a trigger that is syntactically
# valid but semantically wrong (e.g. reused from an earlier round) — that is
# a different problem and out of scope here.
#
# Pure classifier — ISO-8601 parse/compare via python3 (robust across
# BSD/GNU date). The poll/sleep wait-loop lives in the gate skill, not here.

set -euo pipefail

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

TRIGGER="" NOW="" DEADLINE="" VERDICT_TS="" REVIEW_TS="" EDITED_TS="" SCORE=""
PRESENT="" REVIEWED_SHA="" HEAD_SHA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --trigger)      TRIGGER="${2:-}";      shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --now)          NOW="${2:-}";          shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --deadline)     DEADLINE="${2:-}";     shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --verdict-ts)   VERDICT_TS="${2:-}";   shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --review-ts)    REVIEW_TS="${2:-}";    shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --edited-ts)    EDITED_TS="${2:-}";    shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --score)        SCORE="${2:-}";        shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --present)      PRESENT="${2:-}";      shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --reviewed-sha) REVIEWED_SHA="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --head-sha)     HEAD_SHA="${2:-}";     shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# NOTE: new args are appended LAST so the positional contract of the older ones
# is unchanged. They are NOT optional in effect: omitting --present/--head-sha
# means the binding cannot be checked, which lands in UNBOUND rather than
# silently reverting to the timestamp-only behaviour that BC-18961 broke.
python3 - "$TRIGGER" "$NOW" "$DEADLINE" "$VERDICT_TS" "$SCORE" "$REVIEW_TS" "$EDITED_TS" \
         "$PRESENT" "$REVIEWED_SHA" "$HEAD_SHA" <<'PY'
import sys, datetime, re

def parse(s):
    if not s or s == "null":
        return None
    try:
        dt = datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None  # unparseable → treat as absent (degrade to PENDING/TIMED_OUT)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)  # naive → UTC, never crash on compare
    return dt


def parse_trigger(s):
    """--trigger only (BC-18987). Same grammar as parse(), but a naive result
    is a hard failure instead of a silent UTC coercion — a near-miss trigger is
    a confident wrong answer, not an absent one, so it does not get to degrade
    quietly the way garbage does. Unparseable input still fails loudly too,
    since a required anchor with no value at all is exactly as unusable."""
    try:
        dt = datetime.datetime.fromisoformat((s or "").replace("Z", "+00:00"))
    except (ValueError, TypeError):
        print(f"fatal: --trigger is not a valid ISO-8601 timestamp: {s!r}", file=sys.stderr)
        sys.exit(2)
    if dt.tzinfo is None:
        print(
            f"fatal: --trigger has no UTC offset: {s!r} — a naive timestamp is "
            "silently ambiguous and can misclassify a stale review as fresh; "
            "pass a timezone-aware value (e.g. a trailing Z)",
            file=sys.stderr,
        )
        sys.exit(2)
    return dt


argv = (sys.argv[1:11] + [""] * 10)[:10]
trigger, now, deadline, vts, score, rts, ets, present, reviewed_sha, head_sha = argv
t = parse_trigger(trigger)
v, n, d, r = parse(vts), parse(now), parse(deadline), parse(rts)
e = parse(ets)


def norm_sha(s):
    """A commit id, lowercased, or "" if it is not one. Never raises."""
    s = (s or "").strip().lower()
    return s if re.fullmatch(r"[0-9a-f]{7,40}", s) else ""


rsha, hsha = norm_sha(reviewed_sha), norm_sha(head_sha)
# Prefix-tolerant so an abbreviated id on either side still matches the full one.
# Both sides are validated as hex >= 7 chars first, so a truncated/garbage value
# cannot match by accident.
sha_match = bool(rsha and hsha and (rsha.startswith(hsha) or hsha.startswith(rsha)))

# CONDITION 2 — TIME. The latest signal that advances on a re-review. A comment's
# createdAt (verdict-ts) stays pinned when Greptile edits its summary IN PLACE,
# but two others do advance: the head-SHA check-run's completed_at (review-ts,
# BC-16924) and the comment's own updated_at (edited-ts, BC-12580 / BC-17025).
# review-ts alone has a blind spot — when Greptile auto-reviews the push BEFORE
# the re-review is requested, its check-run completes pre-trigger and the in-place
# edit that follows is invisible. edited-ts closes that at source.
candidates = [ts for ts in (v, r, e) if ts is not None]
effective = max(candidates) if candidates else None
advanced = effective is not None and t is not None and effective > t

timed_out = n is not None and d is not None and n >= d

if str(present).lower() != "true":
    # No Greptile verdict at all yet — nothing to bind. Keep waiting.
    print("TIMED_OUT" if timed_out else "PENDING")
elif not hsha:
    # The HEAD did not resolve. This is a TRANSIENT failure — `gh` threw, or the
    # API was briefly unreachable (TLS verification errors hit three times during
    # the BC-18961 run). The next poll re-reads it and may well succeed, so this
    # must NOT be terminal: ending the wait here would waste the very per-poll
    # re-read that was added to recover from it. Keep waiting; the deadline still
    # bounds us, and an unresolved head can never produce a pass.
    print("TIMED_OUT" if timed_out else "PENDING")
elif not rsha:
    # The head resolved, but the summary footer did not parse — so we have a
    # verdict and no way to tell which commit it describes. Unlike the case
    # above, this does NOT recover: polling cannot make an absent footer appear.
    # Say so immediately rather than burn the deadline and land on a state that
    # reads like "Greptile went quiet". Most likely a format change upstream.
    print("UNBOUND")
elif not sha_match:
    # CONDITION 1 FAILS — this is mission-control#2. The score describes a
    # DIFFERENT commit, so it is not an answer about this head no matter what the
    # clocks say. `advanced` may well be True here; identity overrules it.
    print("TIMED_OUT" if timed_out else "PENDING")
elif advanced:
    print("FRESH_PASS" if score == "5" else "FRESH_FAIL")
else:
    # Bound to the head, but nothing has moved since the trigger — the review
    # being waited on has not landed yet.
    print("TIMED_OUT" if timed_out else "PENDING")
PY
