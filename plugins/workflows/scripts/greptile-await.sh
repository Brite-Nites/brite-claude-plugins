#!/usr/bin/env bash
# greptile-await.sh — poll an open PR until Greptile posts a FRESH re-review
# or the wait times out. The thin IO/sleep shell that composes:
#   greptile-verdict.sh   (read the latest verdict)   +
#   greptile-freshness.sh (classify vs the trigger time, with a deadline)
# A pass requires BOTH conditions (BC-18961):
#   IDENTITY  the summary's "Last reviewed commit" == the PR's current head, so
#             the score is known to describe THIS head and not a previous one.
#   TIME      max(comment createdAt, head-SHA check-run completed_at, comment
#             updated_at) > trigger, so an in-place-edited re-review (Greptile
#             edits its summary rather than reposting) is not misread as stale →
#             false TIMED_OUT (BC-16924 added the check-run signal; BC-12580 /
#             BC-17025 added the comment-edit signal, which also covers the case
#             where the check-run completed BEFORE the trigger).
#
# Time alone was the bug: on mission-control#2 a Greptile ACK check-run completed
# 8s after the trigger while the summary still carried the PREVIOUS head's 5/5,
# and the helper reported FRESH_PASS on a score bound to a commit that was no
# longer the head. Identity is the condition that cannot be faked by a clock.
#
# Prints the terminal state on the last line:
#   FRESH_PASS | FRESH_FAIL | TIMED_OUT | UNBOUND
# followed by the final verdict JSON (for the caller to surface the score).
# UNBOUND = a verdict exists but its commit binding could not be read. It is NOT
# a pass and NOT a timeout; it means "verify by hand" (see greptile-freshness.sh).
#
# A per-poll trace goes to STDERR — which signal fired, and which commit the score
# was bound to. stdout keeps the two-line contract.
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

# Head-SHA freshness signal (BC-16924). The repo doesn't change during a wait, so
# it is resolved once. NOTE: uses the PR's HEAD repository — correct for same-repo
# PRs (the norm here). A fork PR resolves to the fork, whose commit may lack the
# base-repo Greptile check-run → review_ts empty (no crash). Fork PRs are out of
# scope for this gate.
REPO="$(gh pr view "$PR" --json headRepositoryOwner,headRepository -q '(.headRepositoryOwner.login // "") + "/" + (.headRepository.name // "")' 2>/dev/null || true)"

# The HEAD SHA, by contrast, is re-read EVERY poll (BC-18961). It was resolved
# once before the loop, on the reasoning that a PR's head does not move during a
# single wait. Two things are wrong with that:
#   1. It is not true. A push during the wait moves the head, and the gate should
#      then be waiting for a review of the NEW head, not the one it started with.
#   2. A single transient `gh` failure at startup pinned HEAD_SHA empty for the
#      WHOLE wait. Re-reading gives every poll a fresh chance to recover — which
#      matters here, because `api.github.com` threw TLS verification errors three
#      times during the incident run.
# Now that the head is load-bearing (it is half of the identity check), a stale or
# empty value must not persist. An empty head is treated as TRANSIENT — PENDING,
# so the next poll can recover — never as a pass, and never as terminal. (Making
# it terminal was a regression Greptile caught on PR #580: it ended the wait on
# the first blip, which is exactly what this per-poll re-read exists to survive.)
head_sha() {
  gh pr view "$PR" --json headRefOid -q .headRefOid 2>/dev/null || true
}
# Deliberately NOT resolved here. The loop re-reads it as its first action, so a
# startup read would be a second API call whose value is never used — and it
# would silently absorb the first transient failure, hiding the recovery path
# from anything trying to exercise it. Declared only to satisfy `set -u`.
HEAD_SHA=""

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
  # Latest completed_at among Greptile check-runs on HEAD that actually CARRY A
  # REVIEW VERDICT (empty if none/pending). An in-progress run has a null
  # completed_at → empty → not yet fresh.
  [ -n "$HEAD_SHA" ] && [ -n "$REPO" ] && [ "$REPO" != "/" ] || { echo ""; return; }
  # per_page=100 so the Greptile run can't fall off page 1 on a busy HEAD (the
  # default 30 would silently empty review_ts → revert to the bug). Keep the
  # case-insensitive name filter (robust if Greptile ever renames the check).
  # Same `if out=$(...)` guard as edited_ts: on a bad SHA `gh api` writes the
  # error body to stdout, which a trailing `|| echo ""` would NOT suppress.
  #
  # CONCLUSION FILTER (BC-18961). `status == "completed"` alone is NOT enough.
  # Greptile puts more than one check-run named "Greptile Review" on a single
  # head: an ACK run that finishes in seconds with conclusion `neutral`, then the
  # real review that finishes with `success`. On mission-control#2 the ack
  # completed at 17:34:06Z — 8s after the trigger, and 4s before the real review
  # even started — so a status-only filter reported "a review finished on your
  # head" while the summary still held the PREVIOUS head's 5/5.
  #
  # Allow-list, not a deny-list: only conclusions that mean "a verdict was
  # reached" count. A conclusion Greptile invents tomorrow is excluded by
  # default, which delays a pass rather than fabricating one.
  #
  # NOTE for anyone re-checking this by hand: the check-runs endpoint defaults to
  # `filter=latest`, which returns only the newest run PER NAME and therefore
  # HIDES the ack run entirely. Add `filter=all` or you will see one run and
  # conclude, wrongly, that this filter is unnecessary. That default is why the
  # defect went unexplained through two investigations.
  local out
  if out="$(gh api "repos/$REPO/commits/$HEAD_SHA/check-runs?per_page=100" --jq '
    [ .check_runs[]
      | select((.name // "") | test("greptile"; "i"))
      | select(.status == "completed")
      # Bind the conclusion BEFORE piping the allow-list: inside `[…] | index(X)`
      # the input `.` is the LIST, so a bare `.conclusion` there reads the array,
      # not the check-run, and silently matches nothing. That mistake empties
      # review_ts on every poll — the failure is a false TIMED_OUT, which is safe
      # but useless, and no classifier unit test would catch it.
      | (.conclusion // "") as $c
      | select(["success","failure","action_required"] | index($c))
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
  # Re-read the head FIRST, so the check-run and the identity check below both
  # describe the same commit this poll is asking about.
  HEAD_SHA="$(head_sha)"
  rts="$(review_ts)"      # head-SHA Greptile check-run completed_at (BC-16924)
  ets_cid="$cid"          # the id `ets` is about (see the id-match guard below)
  ets="$(edited_ts "$ets_cid")"  # that comment's updated_at, if edited since trigger
  verdict="$("$VERDICT" --pr "$PR" 2>/dev/null || echo '{"present":false}')"
  # One jq pass extracts every field to save forks per poll. `cid` is refreshed
  # here for the NEXT poll's edit read. `rsha` is the commit the score is bound
  # to — read from the SAME body as the score, so the two cannot describe
  # different rounds.
  #
  # DELIMITER: unit separator (0x1F), NOT tab. Tab is IFS *whitespace*, so bash
  # collapses runs of it into one separator and strips trailing ones — which
  # SHIFTS every field after an empty one. A `{"present":false}` verdict emits
  # three empty fields in a row, so `present` landed empty and `vts` got the
  # string "false". Observed live in the gate trace for this very PR
  # (`poll=4 ... score=null verdict_ts=false`). It failed safe — an empty
  # `present` reads as "no verdict" → PENDING — but it was wrong, and it made
  # the trace lie. 0x1F is not IFS whitespace, so empty fields are preserved.
  IFS="$(printf '\037')" read -r score vts cid present rsha <<EOF
$(printf '%s' "$verdict" | jq -r '[((.score // "null") | tostring), (.commented_at // ""), (.comment_id // ""), ((.present // false) | tostring), (.reviewed_sha // "")] | join("\u001f")')
EOF
  # Id-match guard: `ets` was read for the PREVIOUS poll's selected comment. If the
  # verdict has since selected a DIFFERENT object (Greptile posted a second comment,
  # or a review body now wins), that edit timestamp no longer describes the object
  # `score` came from — so drop it rather than pair the two. Freshness then rests on
  # verdict-ts / review-ts, which already see a newly-posted comment via its
  # post-trigger createdAt. Cheap, and makes the binding exact under selection churn.
  [ -n "$ets_cid" ] && [ "$ets_cid" = "$cid" ] || ets=""
  state="$("$FRESHNESS" --trigger "$TRIGGER" --now "$(now_iso)" --deadline "$DEADLINE" --verdict-ts "$vts" --review-ts "$rts" --edited-ts "$ets" --score "$score" --present "$present" --reviewed-sha "$rsha" --head-sha "$HEAD_SHA")"
  # Per-poll trace to stderr (BC-18961 step 4). stdout stays exactly the two-line
  # contract — verdict JSON, then state — so callers are unaffected; `2>&1` or a
  # redirect captures this. The whole investigation cost of this defect was that
  # nobody could see WHICH signal fired or WHAT commit the score described, and
  # the deciding evidence (an ack check-run) was gone from every later query by
  # the time anyone looked. Print it while it is still true.
  # Binding note. Prefix-tolerant in both directions, matching the classifier's
  # rule so the trace can't say MISMATCH on an abbreviated id the classifier
  # accepted. `state` remains the authoritative answer; this only explains it.
  bind_note=""
  if [ -n "$rsha" ] && [ -n "$HEAD_SHA" ]; then
    bind_note=" (MISMATCH — score describes another commit)"
    case "$HEAD_SHA" in "$rsha"*) bind_note=" (MATCH)" ;; esac
    case "$rsha" in "$HEAD_SHA"*) bind_note=" (MATCH)" ;; esac
  fi
  printf 'poll=%s state=%s head=%s bound=%s%s score=%s verdict_ts=%s review_ts=%s edited_ts=%s\n' \
    "$i" "$state" "${HEAD_SHA:-<unresolved>}" "${rsha:-<unreadable>}" "$bind_note" \
    "$score" "${vts:--}" "${rts:--}" "${ets:--}" >&2
  case "$state" in
    FRESH_PASS|FRESH_FAIL|TIMED_OUT|UNBOUND)
      printf '%s\n%s\n' "$verdict" "$state"
      exit 0 ;;
    PENDING)
      sleep "$INTERVAL" ;;
  esac
done

# Backstop tripped — report the last verdict as a timeout so the caller never hangs.
printf '%s\n%s\n' "$verdict" "TIMED_OUT"
