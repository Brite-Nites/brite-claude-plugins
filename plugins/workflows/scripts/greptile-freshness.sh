#!/usr/bin/env bash
# greptile-freshness.sh — classify the state of a Greptile re-review wait.
#
#   --trigger <iso8601>     when the re-review was requested
#   --now <iso8601>         current time
#   --deadline <iso8601>    trigger + max-wait (the anti-hang bound)
#   --verdict-ts <iso8601>  commented_at of the latest Greptile comment (empty if none)
#   --review-ts <iso8601>   completed_at of the head-SHA Greptile check-run (empty if none)
#   --score <0-5|null>      score from the latest Greptile verdict (empty/null if none)
#
# Prints exactly one state:
#   FRESH_PASS  fresh review (max(verdict_ts, review_ts) > trigger) with score == 5
#   FRESH_FAIL  fresh review with score != 5 (including null)
#   PENDING     no fresh review yet, still within the deadline
#   TIMED_OUT   no fresh review and now >= deadline
#
# Pure classifier — ISO-8601 parse/compare via python3 (robust across
# BSD/GNU date). The poll/sleep wait-loop lives in the gate skill, not here.

set -euo pipefail

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

TRIGGER="" NOW="" DEADLINE="" VERDICT_TS="" REVIEW_TS="" SCORE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --trigger)    TRIGGER="${2:-}";    shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --now)        NOW="${2:-}";        shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --deadline)   DEADLINE="${2:-}";   shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --verdict-ts) VERDICT_TS="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --review-ts)  REVIEW_TS="${2:-}";  shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --score)      SCORE="${2:-}";      shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

python3 - "$TRIGGER" "$NOW" "$DEADLINE" "$VERDICT_TS" "$SCORE" "$REVIEW_TS" <<'PY'
import sys, datetime

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

trigger, now, deadline, vts, score, rts = sys.argv[1:7]
t, v, n, d, r = parse(trigger), parse(vts), parse(now), parse(deadline), parse(rts)

# Freshness keys on the latest signal that advances on a re-review. A comment's
# createdAt (verdict-ts) stays pinned when Greptile edits its summary IN PLACE,
# but the head-SHA check-run's completed_at (review-ts) advances per re-review —
# so use whichever is later (BC-16924). Either alone still works.
candidates = [ts for ts in (v, r) if ts is not None]
effective = max(candidates) if candidates else None
fresh = effective is not None and t is not None and effective > t
if fresh:
    print("FRESH_PASS" if score == "5" else "FRESH_FAIL")
elif n is not None and d is not None and n >= d:
    print("TIMED_OUT")
else:
    print("PENDING")
PY
