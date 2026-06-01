#!/usr/bin/env bash
# greptile-freshness.sh — classify the state of a Greptile re-review wait.
#
#   --trigger <iso8601>     when the re-review was requested
#   --now <iso8601>         current time
#   --deadline <iso8601>    trigger + max-wait (the anti-hang bound)
#   --verdict-ts <iso8601>  commented_at of the latest Greptile comment (empty if none)
#   --score <0-5|null>      score from the latest Greptile verdict (empty/null if none)
#
# Prints exactly one state:
#   FRESH_PASS  fresh review (verdict_ts > trigger) with score == 5
#   FRESH_FAIL  fresh review with score != 5 (including null)
#   PENDING     no fresh review yet, still within the deadline
#   TIMED_OUT   no fresh review and now >= deadline
#
# Pure classifier — ISO-8601 parse/compare via python3 (robust across
# BSD/GNU date). The poll/sleep wait-loop lives in the gate skill, not here.

set -euo pipefail

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

TRIGGER="" NOW="" DEADLINE="" VERDICT_TS="" SCORE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --trigger)    TRIGGER="${2:-}";    shift 2 ;;
    --now)        NOW="${2:-}";        shift 2 ;;
    --deadline)   DEADLINE="${2:-}";   shift 2 ;;
    --verdict-ts) VERDICT_TS="${2:-}"; shift 2 ;;
    --score)      SCORE="${2:-}";      shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

python3 - "$TRIGGER" "$NOW" "$DEADLINE" "$VERDICT_TS" "$SCORE" <<'PY'
import sys, datetime

def parse(s):
    if not s or s == "null":
        return None
    return datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))

trigger, now, deadline, vts, score = sys.argv[1:6]
t, v, n, d = parse(trigger), parse(vts), parse(now), parse(deadline)

fresh = v is not None and t is not None and v > t
if fresh:
    print("FRESH_PASS" if score == "5" else "FRESH_FAIL")
elif n is not None and d is not None and n >= d:
    print("TIMED_OUT")
else:
    print("PENDING")
PY
