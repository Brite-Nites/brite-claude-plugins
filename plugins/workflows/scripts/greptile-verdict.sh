#!/usr/bin/env bash
# greptile-verdict.sh — read a PR's Greptile summary and emit a structured
# verdict on stdout (single-line JSON).
#
#   --comments-file <path>   parse a gh-shaped {"comments":[…],"reviews":[…]} file
#   --pr <number|url>        gh pr view <ref> --json comments,reviews, then parse
#
# Verdict:
#   {"present":true,"score":<0-5|null>,"comment_id":"…","commented_at":"…",
#    "reviewed_sha":"<40-hex|null>"}
#   {"present":false}                              (no Greptile comment/review)
#
# A "Greptile comment" is any PR comment OR review whose author login contains
# "greptile" (case-insensitive). Greptile posts its summary as a top-level
# comment in the common case, but as a review body in some configs — both are
# scanned. When several exist, the most recent by timestamp wins. score is the
# 0–5 confidence rating parsed from the body.
#
# `reviewed_sha` is the commit the score is BOUND to, read from the summary's
# "Last reviewed commit" footer (BC-18961). It is the only signal that answers
# the gate's actual question — "is this score about MY head?" — because it is
# parsed from the SAME body read as the score, and Greptile rewrites the whole
# body in one edit. Timestamps cannot answer it: `commented_at` is the comment's
# createdAt, which never moves once Greptile starts re-scoring in place.

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo '{"error":"jq required"}' >&2; exit 2; }

usage() {
  echo "usage: greptile-verdict.sh (--comments-file <path> | --pr <number|url>)" >&2
  exit 2
}

MODE=""
ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --comments-file) MODE="file"; ARG="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --pr)            MODE="pr";   ARG="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    -h|--help)       usage ;;
    *)               echo "unknown arg: $1" >&2; usage ;;
  esac
done
[ -n "$MODE" ] && [ -n "$ARG" ] || usage

# Defense-in-depth: refuse a PR ref that would be parsed as a gh flag.
if [ "$MODE" = "pr" ] && [ "${ARG#-}" != "$ARG" ]; then
  echo "refusing PR ref that looks like a flag: $ARG" >&2; exit 2
fi

case "$MODE" in
  file)
    [ -f "$ARG" ] || { echo "no such file: $ARG" >&2; exit 2; }
    COMMENTS_JSON="$(cat "$ARG")" ;;
  pr)
    command -v gh >/dev/null 2>&1 || { echo '{"error":"gh required"}' >&2; exit 2; }
    COMMENTS_JSON="$(gh pr view "$ARG" --json comments,reviews 2>/dev/null)" \
      || { echo '{"error":"gh pr view failed"}' >&2; exit 2; } ;;
esac

# Unparseable input (e.g. a truncated/rate-limited gh response) is treated as
# "no verdict" so the gate skips gracefully rather than erroring.
printf '%s' "$COMMENTS_JSON" | jq empty >/dev/null 2>&1 || { echo '{"present":false}'; exit 0; }

# Pure parse: comments + reviews JSON → verdict. Comments carry .createdAt,
# reviews carry .submittedAt — normalize both to a common shape, then pick the
# latest Greptile-authored entry by timestamp.
printf '%s' "$COMMENTS_JSON" | jq -c '
  # Greptile prints its verdict inside a heading: "<h3>Confidence Score: N/5</h3>"
  # (or a markdown "### …"). A PR body — especially one ABOUT score parsing — also
  # mentions "Confidence Score: N/5" in prose/quotes, so match the HEADING first
  # and only fall back to a bare label when no heading verdict is present.
  def score_of(b):
    ( (b | capture("(?i)(?:<h[1-6][^>]*>|#{1,6}[ \\t]+)\\s*confidence\\s*score:?\\s*(?<s>[0-5])\\s*/\\s*5") | .s)
      // (b | capture("(?i)confidence\\s*(?:score)?[\\s:]*(?<s>[0-5])\\s*/\\s*5") | .s)
      // null )
    | if . == null then null else tonumber end;
  # The commit this score is BOUND to, from the summary footer (BC-18961):
  #   <sub>Reviews (3): Last reviewed commit: ["msg"](https://…/commit/<sha>) | …</sub>
  #
  # SCOPE NOTE — this regex is coupled to the Greptile summary format. It was
  # built against a four-for-four sample (mission-control#2, brite-claude-plugins
  # #579/#576/#575), which is evidence, not a guarantee. If Greptile changes the
  # footer, this yields null, and null MUST route to the UNBOUND state in
  # greptile-freshness.sh — never to a pass. That is the property to preserve if
  # you touch either file: a format drift degrades to "cannot verify", never to
  # "verified". A silent fallback to timestamps here would re-open BC-18961.
  #
  # Anchored on the "last reviewed commit" label rather than on /commit/ alone, so
  # a commit link elsewhere in the review prose cannot be mistaken for the binding
  # (covered by a negative test).
  def sha_of(b):
    ( b | capture("(?i)last\\s+reviewed\\s+commit[^\\n]*?/commit/(?<s>[0-9a-fA-F]{7,40})") | .s | ascii_downcase )
    // null;
  ( [ ((.comments // [])[] | {login: (.author.login // ""), body: (.body // ""), ts: (.createdAt // ""),   id: .id}),
      ((.reviews  // [])[] | {login: (.author.login // ""), body: (.body // ""), ts: (.submittedAt // ""), id: .id}) ]
    | map(select((.login | ascii_downcase) | test("greptile")))
    | map(. + {score: score_of(.body), reviewed_sha: sha_of(.body)}) ) as $g
  | if ($g | length) == 0
    then {present: false}
    # Greptile posts a SCORED comment and, seconds later, an EMPTY COMMENTED
    # review — so "latest by timestamp" alone picks the empty review (score
    # null). Prefer the latest entry that actually carries a score; only fall
    # back to the latest overall when none has one.
    else ( ($g | map(select(.score != null)) | sort_by(.ts) | last)
           // ($g | sort_by(.ts) | last) ) as $c
         | {present: true, score: $c.score, comment_id: $c.id, commented_at: $c.ts,
            reviewed_sha: $c.reviewed_sha}
    end
'
