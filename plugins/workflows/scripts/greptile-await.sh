#!/usr/bin/env bash
# greptile-await.sh — poll an open PR until Greptile posts a FRESH re-review
# or the wait times out. The thin IO/sleep shell that composes:
#   greptile-verdict.sh   (read the latest verdict)   +
#   greptile-freshness.sh (classify vs the trigger time, with a deadline)
#
# Prints the terminal state on the last line:
#   FRESH_PASS | FRESH_FAIL | TIMED_OUT
# followed by the final verdict JSON (for the caller to surface the score).
#
#   --pr <ref>           PR number/url (required)
#   --trigger <iso8601>  when "@greptile-apps please re-review" was posted (required)
#   --max-wait <sec>     total bound, default 600 (anti-hang)
#   --interval <sec>     poll interval, default 30
#
# The pure classification is unit-tested in test-greptile-freshness.sh; this
# loop is the IO shell (the deadline check in the classifier terminates it, so
# it cannot hang). A defensive iteration cap backstops a misbehaving clock.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDICT="$SCRIPT_DIR/greptile-verdict.sh"
FRESHNESS="$SCRIPT_DIR/greptile-freshness.sh"

command -v jq >/dev/null 2>&1      || { echo "fatal: jq required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

PR="" TRIGGER="" MAX_WAIT=600 INTERVAL=30
while [ $# -gt 0 ]; do
  case "$1" in
    --pr)       PR="${2:-}";       shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --trigger)  TRIGGER="${2:-}";  shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --max-wait) MAX_WAIT="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --interval) INTERVAL="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$PR" ] && [ -n "$TRIGGER" ] || { echo "usage: greptile-await.sh --pr <ref> --trigger <iso8601> [--max-wait sec] [--interval sec]" >&2; exit 2; }

# Reject non-numeric timing args (they'd otherwise crash the arithmetic / sleep
# with an opaque error), and clamp interval to >=1 so --interval 0 can't hot-spin.
case "$MAX_WAIT" in ''|*[!0-9]*) echo "--max-wait must be a non-negative integer" >&2; exit 2 ;; esac
case "$INTERVAL" in ''|*[!0-9]*) echo "--interval must be a non-negative integer" >&2; exit 2 ;; esac
[ "$INTERVAL" -ge 1 ] || INTERVAL=1

now_iso() { python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00","Z"))'; }

# deadline = trigger + max-wait
DEADLINE="$(python3 - "$TRIGGER" "$MAX_WAIT" <<'PY'
import sys, datetime
t = datetime.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
d = t + datetime.timedelta(seconds=float(sys.argv[2]))
print(d.isoformat().replace("+00:00", "Z"))
PY
)"

# Defensive backstop so a clock anomaly can't loop forever.
max_iters=$(( MAX_WAIT / (INTERVAL > 0 ? INTERVAL : 1) + 2 ))

verdict='{"present":false}'
i=0
while [ "$i" -lt "$max_iters" ]; do
  i=$((i + 1))
  verdict="$("$VERDICT" --pr "$PR" 2>/dev/null || echo '{"present":false}')"
  # One jq pass extracts both fields (tab-separated) to save a fork per poll.
  IFS="$(printf '\t')" read -r score vts <<EOF
$(printf '%s' "$verdict" | jq -r '[(.score // "null"), (.commented_at // "")] | @tsv')
EOF
  state="$("$FRESHNESS" --trigger "$TRIGGER" --now "$(now_iso)" --deadline "$DEADLINE" --verdict-ts "$vts" --score "$score")"
  case "$state" in
    FRESH_PASS|FRESH_FAIL|TIMED_OUT)
      printf '%s\n%s\n' "$verdict" "$state"
      exit 0 ;;
    PENDING)
      sleep "$INTERVAL" ;;
  esac
done

# Backstop tripped — report the last verdict as a timeout so the caller never hangs.
printf '%s\n%s\n' "$verdict" "TIMED_OUT"
