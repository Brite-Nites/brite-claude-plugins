#!/usr/bin/env bash
# greptile-verdict.sh — read a PR's Greptile summary and emit a structured
# verdict on stdout (single-line JSON).
#
#   --comments-file <path>   parse a gh-shaped {"comments":[…],"reviews":[…]} file
#   --pr <number|url>        gh pr view <ref> --json comments,reviews, then parse
#
# Verdict:
#   {"present":true,"score":<0-5|null>,"comment_id":"…","commented_at":"…"}
#   {"present":false}                              (no Greptile comment/review)
#
# A "Greptile comment" is any PR comment OR review whose author login contains
# "greptile" (case-insensitive). Greptile posts its summary as a top-level
# comment in the common case, but as a review body in some configs — both are
# scanned. When several exist, the most recent by timestamp wins. score is the
# 0–5 confidence rating parsed from the body.

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
  def score_of(b): ((b | capture("(?i)confidence[\\s\\S]*?(?<s>[0-5])\\s*/\\s*5") | .s) // null)
                   | if . == null then null else tonumber end;
  ( [ ((.comments // [])[] | {login: (.author.login // ""), body: (.body // ""), ts: (.createdAt // ""),   id: .id}),
      ((.reviews  // [])[] | {login: (.author.login // ""), body: (.body // ""), ts: (.submittedAt // ""), id: .id}) ]
    | map(select((.login | ascii_downcase) | test("greptile"))) ) as $g
  | if ($g | length) == 0
    then {present: false}
    else ($g | sort_by(.ts) | last) as $c
         | {present: true, score: score_of($c.body), comment_id: $c.id, commented_at: $c.ts}
    end
'
