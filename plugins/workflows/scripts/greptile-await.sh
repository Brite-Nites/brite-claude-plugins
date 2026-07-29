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
# LIMITATION: this reads ISSUE comments. In the config where Greptile posts its
# summary as a REVIEW body (see greptile-verdict.sh), edited_ts is always empty
# and freshness degrades to the two pre-existing signals — REST exposes no edit
# timestamp for review bodies. Safe degradation, not a regression.
PR_URL="$(gh pr view "$PR" --json url -q .url 2>/dev/null || true)"
BASE_REPO=""
PR_NUM=""
TAB="$(printf '\t')"
if PR_REF="$(bash "$SCRIPT_DIR/greptile-pr-ref.sh" --url "$PR_URL" 2>/dev/null)"; then
  # Literal-substring case match (quoted pattern) — the documented-safe idiom.
  case "$PR_REF" in
    *"$TAB"*)
      BASE_REPO="${PR_REF%%"$TAB"*}"
      PR_NUM="${PR_REF##*"$TAB"}" ;;
  esac
fi
# A `+` in an ISO offset (…T20:59:51+00:00) decodes as a space in a query
# string — verified to silently return [] rather than error, so the encoding is
# load-bearing. Z-form triggers pass through untouched.
TRIGGER_Q="${TRIGGER//+/%2B}"

edited_ts() {
  # updated_at of THE comment the verdict's score was read from, when that exact
  # comment was edited since the trigger (empty otherwise).
  #
  # Binding to the verdict's own comment id is the point. A max() across all
  # greptile-authored comments would let one comment's fresh edit terminate the
  # wait while the score came from a DIFFERENT comment — reporting a verdict that
  # no single review object ever asserted. REST `node_id` is the same identifier
  # `greptile-verdict.sh` emits as `comment_id` (both GraphQL node ids), so the
  # two are joinable exactly.
  #
  # `since=` keeps the server-side filter on updated_at (verified against a real
  # edited comment): the response stays small on a busy PR and the summary can't
  # fall off page 1. It is inclusive; the classifier's strict `>` rejects the
  # boundary. A comment absent from the filtered set simply wasn't edited since
  # the trigger → empty → not fresh.
  local node_id="${1:-}"
  [ -n "$BASE_REPO" ] && [ -n "$PR_NUM" ] && [ -n "$node_id" ] || { echo ""; return; }
  # A verdict sourced from a REVIEW body carries a review node id, which matches
  # no issue comment → empty → freshness degrades to the two other signals.
  case "$node_id" in IC_*) ;; *) echo ""; return ;; esac
  # Piped to real `jq` rather than gh's built-in `--jq`, because the id must be
  # passed as data via `--arg` (gh's --jq takes no jq flags, and interpolating an
  # id into the program text would be an injection seam). `set -o pipefail` is on,
  # so a failing `gh` still fails the substitution → the else branch.
  #
  # Branching on exit status matters: `gh api` prints the HTTP error BODY to
  # stdout before exiting nonzero, so a trailing `|| echo ""` would assign a JSON
  # blob rather than empty (the repo's `if x=$(...)` set-e idiom).
  local out
  if out="$(gh api "repos/$BASE_REPO/issues/$PR_NUM/comments?since=$TRIGGER_Q&per_page=100" 2>/dev/null \
    | jq -r --arg id "$node_id" '
      [ .[] | select((.node_id // "") == $id) | (.updated_at // "") ]
      | map(select(. != "")) | sort | last // ""' 2>/dev/null)"; then
    printf '%s\n' "$out"
  else
    echo ""
  fi
}

review_ts() {
  # Latest completed_at among Greptile check-runs on HEAD (empty if none/pending).
  # An in-progress check-run has a null completed_at → empty → not yet fresh.
  [ -n "$HEAD_SHA" ] && [ -n "$REPO" ] && [ "$REPO" != "/" ] || { echo ""; return; }
  # per_page=100 so the Greptile run can't fall off page 1 on a busy HEAD (the
  # default 30 would silently empty review_ts → revert to the bug). Keep the
  # case-insensitive name filter (robust if Greptile ever renames the check).
  # Same `if out=$(...)` guard as edited_ts: on a bad SHA `gh api` writes the
  # error body to stdout, which a trailing `|| echo ""` would NOT suppress.
  local out
  if out="$(gh api "repos/$REPO/commits/$HEAD_SHA/check-runs?per_page=100" --jq '
    [ .check_runs[]
      | select((.name // "") | test("greptile"; "i"))
      | select(.status == "completed")
      | (.completed_at // "") ]
    | map(select(. != "")) | sort | last // ""' 2>/dev/null)"; then
    printf '%s\n' "$out"
  else
    echo ""
  fi
}

# Defensive backstop so a clock anomaly can't loop forever.
max_iters=$(( MAX_WAIT / (INTERVAL > 0 ? INTERVAL : 1) + 2 ))

verdict='{"present":false}'
# The summary comment's id, carried across polls. Greptile edits IN PLACE, so this is
# stable once known — which lets each poll read the edit timestamp BEFORE the verdict
# (below) while still keying on the right comment.
cid=""
i=0
while [ "$i" -lt "$max_iters" ]; do
  i=$((i + 1))
  # Read the freshness signal (check-run) BEFORE the verdict, so the score
  # snapshot is at least as fresh as the signal — shrinks the propagation race
  # between check-run completion and the in-place comment edit (BC-16924 review).
  # BOTH freshness signals are read BEFORE the verdict, so the score snapshot is at
  # least as fresh as every signal it is paired with (the BC-16924 ordering rule). An
  # edit landing after these reads is simply not counted this poll — the fail-safe
  # direction. Reading them AFTER would invert it: a fresh timestamp could be paired
  # with a pre-edit score, which is the inconsistency Greptile flagged on #559.
  #
  # `edited_ts` needs the summary comment's id, which comes from the verdict — hence
  # `cid` is carried over from the PREVIOUS poll rather than read here. Greptile edits
  # in place, so the id is stable across the wait. On the first poll `cid` is empty and
  # the edit signal simply doesn't participate (the other two still do).
  rts="$(review_ts)"      # head-SHA Greptile check-run completed_at (BC-16924)
  ets="$(edited_ts "$cid")"  # that comment's updated_at, if edited since the trigger
  verdict="$("$VERDICT" --pr "$PR" 2>/dev/null || echo '{"present":false}')"
  # One jq pass extracts all three fields (tab-separated) to save forks per poll.
  # `cid` is refreshed here for the NEXT poll's edit read.
  IFS="$(printf '\t')" read -r score vts cid <<EOF
$(printf '%s' "$verdict" | jq -r '[(.score // "null"), (.commented_at // ""), (.comment_id // "")] | @tsv')
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
