#!/usr/bin/env bash
# greptile-pr-ref.sh — resolve a PR html url to "<owner>/<repo><TAB><number>".
#
#   --url <pr-url>   the PR's html url (`gh pr view <ref> --json url -q .url`)
#
# Prints one tab-separated line, or an EMPTY line when the url is not a
# recognizable PR url. Failing closed is the contract: callers treat an empty
# result as "no signal" and degrade, so a half-parsed value that builds a wrong
# API path is strictly worse than nothing.
#
# The PR's BASE repo is what issue comments hang off — for a fork PR that is the
# upstream repo, not `headRepository`, which is why this parses the url rather
# than reusing the head-repo fields the check-run probe needs.
#
# Pure string manipulation (bash 3.2 compatible), no IO. Unit-tested in
# test-greptile-pr-ref.sh.

set -euo pipefail

URL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

path="${URL#*://}"   # host/OWNER/REPO/pull/N   (no-op if there is no scheme)
path="${path#*/}"    # OWNER/REPO/pull/N

repo=""
num=""
case "$path" in
  */pull/*)
    # `%` (shortest suffix) not `%%` (longest): a repo literally named `pull`
    # — owner/pull/pull/5 — must keep its full name rather than lose a segment.
    repo="${path%/pull/*}"
    num="${path##*/}" ;;
esac

# Anything non-numeric after /pull/ means the url carried a suffix, query or
# fragment (…/pull/5/files, …/pull/5?x=1, …/pull/5/) — reject rather than guess.
case "$num" in ''|*[!0-9]*) repo=""; num="" ;; esac
# `repo` must be exactly owner/name — one slash, both halves non-empty.
case "$repo" in ''|/*|*/|*/*/*) repo=""; num="" ;; esac

[ -n "$repo" ] || { printf '\n'; exit 0; }
printf '%s\t%s\n' "$repo" "$num"
