#!/usr/bin/env bash
# greptile-verdict.sh — read a PR's Greptile summary comment and emit a
# structured verdict on stdout (single-line JSON).
#
#   --comments-file <path>   parse a gh-shaped {"comments":[…]} JSON file
#   --pr <number|url>        gh pr view <ref> --json comments, then parse
#
# Verdict:
#   {"present":true,"score":<0-5|null>,"comment_id":"…","commented_at":"…"}
#   {"present":false}                              (no Greptile bot comment)
#
# A "Greptile comment" is any PR comment whose author login contains
# "greptile" (case-insensitive). score is the 0–5 confidence rating parsed
# from the comment body.

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
    --comments-file) MODE="file"; ARG="${2:-}"; shift 2 ;;
    --pr)            MODE="pr";   ARG="${2:-}"; shift 2 ;;
    -h|--help)       usage ;;
    *)               echo "unknown arg: $1" >&2; usage ;;
  esac
done
[ -n "$MODE" ] && [ -n "$ARG" ] || usage

case "$MODE" in
  file)
    [ -f "$ARG" ] || { echo "no such file: $ARG" >&2; exit 2; }
    COMMENTS_JSON="$(cat "$ARG")" ;;
  pr)
    command -v gh >/dev/null 2>&1 || { echo '{"error":"gh required"}' >&2; exit 2; }
    COMMENTS_JSON="$(gh pr view "$ARG" --json comments 2>/dev/null)" \
      || { echo '{"error":"gh pr view failed"}' >&2; exit 2; } ;;
esac

# Pure parse: comments JSON → verdict.
printf '%s' "$COMMENTS_JSON" | jq -c '
  def score_of(b): ((b | capture("(?i)confidence[^0-9]*(?<s>[0-5])\\s*/\\s*5") | .s) // null)
                   | if . == null then null else tonumber end;
  [.comments[]? | select((.author.login // "") | ascii_downcase | test("greptile"))] as $g
  | if ($g | length) == 0
    then {present: false}
    else ($g | sort_by(.createdAt) | last) as $c
         | {present: true, score: score_of($c.body), comment_id: $c.id, commented_at: $c.createdAt}
    end
'
