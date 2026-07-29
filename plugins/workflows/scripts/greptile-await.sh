#!/usr/bin/env bash
# greptile-await.sh — poll an open PR until Greptile posts a FRESH re-review
# or the wait times out. The thin IO/sleep shell that composes:
#   greptile-verdict.sh   (read the latest verdict)   +
#   greptile-freshness.sh (classify vs the trigger time, with a deadline)
# Freshness keys on max(comment createdAt, head-SHA check-run completed_at,
# comment updated_at), so an in-place-edited re-review (Greptile edits its summary
# rather than reposting) is not misread as stale → false TIMED_OUT (BC-16924 added
# the check-run signal; BC-12580 / BC-17025 added the comment-edit signal, which
# also covers the case where the check-run completed BEFORE the trigger).
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

# Head-SHA freshness signal (BC-16924). Resolve the PR's repo + HEAD sha ONCE
# (they don't change during a single wait); the check-run itself is re-read each
# poll because it completes DURING the wait. If resolution fails, review_ts is
# empty and freshness degrades to the verdict-ts-only behavior — no regression.
# NOTE: uses the PR's HEAD repository — correct for same-repo PRs (the norm here).
# A fork PR resolves to the fork, whose commit may lack the base-repo Greptile
# check-run → review_ts empty → verdict-ts-only fallback (no crash). Fork PRs are
# out of scope for this gate.
REPO="$(gh pr view "$PR" --json headRepositoryOwner,headRepository -q '(.headRepositoryOwner.login // "") + "/" + (.headRepository.name // "")' 2>/dev/null || true)"
HEAD_SHA="$(gh pr view "$PR" --json headRefOid -q .headRefOid 2>/dev/null || true)"

# Comment-edit freshness signal (BC-12580 / BC-17025). Greptile re-scores by
# EDITING its summary comment, which bumps only the comment's updated_at —
# invisible to both createdAt and (when Greptile auto-reviewed the push before
# the re-review was requested) the head-SHA check-run. Resolved from the PR's
# BASE repo + number, which is where issue comments live regardless of fork.
PR_URL="$(gh pr view "$PR" --json url -q .url 2>/dev/null || true)"
BASE_PATH="${PR_URL#*://}"          # host/OWNER/REPO/pull/N
BASE_PATH="${BASE_PATH#*/}"         # OWNER/REPO/pull/N
BASE_REPO=""
PR_NUM=""
case "$BASE_PATH" in
  */pull/*)
    BASE_REPO="${BASE_PATH%%/pull/*}"
    PR_NUM="${BASE_PATH##*/}" ;;
esac
case "$PR_NUM" in ''|*[!0-9]*) BASE_REPO=""; PR_NUM="" ;; esac
# A `+` in an ISO offset (…T20:59:51+00:00) decodes as a space in a query
# string — percent-encode it. Z-form triggers pass through untouched.
TRIGGER_Q="${TRIGGER//+/%2B}"

edited_ts() {
  # Latest updated_at among Greptile comments EDITED since the trigger (empty if
  # none). `since` filters server-side on updated_at, so the response stays small
  # on a busy PR and can't push the summary off the first page — the classifier
  # still re-checks the timestamp, so a boundary-equal value is not fresh.
  [ -n "$BASE_REPO" ] && [ -n "$PR_NUM" ] || { echo ""; return; }
  gh api "repos/$BASE_REPO/issues/$PR_NUM/comments?since=$TRIGGER_Q&per_page=100" --jq '
    [ .[]
      | select(((.user.login // "") | ascii_downcase) | test("greptile"))
      | (.updated_at // "") ]
    | map(select(. != "")) | sort | last // ""' 2>/dev/null || echo ""
}

review_ts() {
  # Latest completed_at among Greptile check-runs on HEAD (empty if none/pending).
  # An in-progress check-run has a null completed_at → empty → not yet fresh.
  [ -n "$HEAD_SHA" ] && [ -n "$REPO" ] && [ "$REPO" != "/" ] || { echo ""; return; }
  # per_page=100 so the Greptile run can't fall off page 1 on a busy HEAD (the
  # default 30 would silently empty review_ts → revert to the bug). Keep the
  # case-insensitive name filter (robust if Greptile ever renames the check).
  gh api "repos/$REPO/commits/$HEAD_SHA/check-runs?per_page=100" --jq '
    [ .check_runs[]
      | select((.name // "") | test("greptile"; "i"))
      | select(.status == "completed")
      | (.completed_at // "") ]
    | map(select(. != "")) | sort | last // ""' 2>/dev/null || echo ""
}

# Defensive backstop so a clock anomaly can't loop forever.
max_iters=$(( MAX_WAIT / (INTERVAL > 0 ? INTERVAL : 1) + 2 ))

verdict='{"present":false}'
i=0
while [ "$i" -lt "$max_iters" ]; do
  i=$((i + 1))
  # Read the freshness signal (check-run) BEFORE the verdict, so the score
  # snapshot is at least as fresh as the signal — shrinks the propagation race
  # between check-run completion and the in-place comment edit (BC-16924 review).
  rts="$(review_ts)"   # head-SHA Greptile check-run completed_at (BC-16924)
  ets="$(edited_ts)"   # latest Greptile comment updated_at since trigger (BC-12580)
  verdict="$("$VERDICT" --pr "$PR" 2>/dev/null || echo '{"present":false}')"
  # One jq pass extracts both fields (tab-separated) to save a fork per poll.
  IFS="$(printf '\t')" read -r score vts <<EOF
$(printf '%s' "$verdict" | jq -r '[(.score // "null"), (.commented_at // "")] | @tsv')
EOF
  state="$("$FRESHNESS" --trigger "$TRIGGER" --now "$(now_iso)" --deadline "$DEADLINE" --verdict-ts "$vts" --review-ts "$rts" --edited-ts "$ets" --score "$score")"
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
