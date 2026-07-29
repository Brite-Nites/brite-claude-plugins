#!/usr/bin/env bash
# BC-12580 unit tests for the PR-url parser behind the comment-edit freshness
# probe.
#
#   plugins/workflows/scripts/greptile-pr-ref.sh --url <pr-url>
#     → "<owner>/<repo><TAB><number>", or an empty line when unparseable.
#
# Why this exists: the parser's whole job is to fail CLOSED. A half-parsed value
# builds a wrong API path, which returns an error body that degrades to "no
# signal" — i.e. the greptile-await fix silently no-ops and the false TIMED_OUT
# comes back. Silent disarm is exactly the failure class this repo keeps hitting,
# so every malformed shape is pinned here.
#
# Hand-rolled assertion harness. Bash 3.2 compatible. Hermetic — no network.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSE="$PLUGIN_ROOT/scripts/greptile-pr-ref.sh"

[ -f "$PARSE" ] || { echo "fatal: greptile-pr-ref.sh missing" >&2; exit 2; }

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }

TAB="$(printf '\t')"

# assert_parse <label> <url> <expected>   — expected "" means "empty line"
assert_parse() {
  local label="$1" url="$2" expected="$3" got rc
  set +e
  got="$(bash "$PARSE" --url "$url" 2>/dev/null)"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ] && [ "$got" = "$expected" ]; then
    pass "$label"
  else
    fail "$label: expected [${expected}] got [${got}] rc=$rc"
  fi
}

echo "[1] well-formed urls"
assert_parse "github.com PR" \
  "https://github.com/Brite-Nites/brite-claude-plugins/pull/552" \
  "Brite-Nites/brite-claude-plugins${TAB}552"
assert_parse "GitHub Enterprise host" \
  "https://ghe.corp.example.com/org/repo/pull/12" \
  "org/repo${TAB}12"
assert_parse "multi-digit number" \
  "https://github.com/o/r/pull/1234567" \
  "o/r${TAB}1234567"

echo "[2] fail-closed shapes (must yield an empty line, never a partial)"
assert_parse "trailing slash"        "https://github.com/o/r/pull/5/"        ""
assert_parse "query string"          "https://github.com/o/r/pull/5?foo=bar" ""
assert_parse "fragment"              "https://github.com/o/r/pull/5#c1"      ""
assert_parse "sub-path (/files)"     "https://github.com/o/r/pull/5/files"   ""
assert_parse "issues url, not a PR"  "https://github.com/o/r/issues/5"       ""
assert_parse "repo root"             "https://github.com/o/r"                ""
assert_parse "empty url (gh failed)" ""                                      ""
assert_parse "non-numeric id"        "https://github.com/o/r/pull/abc"       ""
assert_parse "owner-only path"       "https://github.com/o/pull/5"           "o${TAB}5"

echo "[3] pathological — repo literally named 'pull'"
# Regression for the shortest-vs-longest suffix strip: `%%` would return "owner"
# here and silently build repos/owner/issues/5/comments.
assert_parse "repo named pull" \
  "https://github.com/owner/pull/pull/5" \
  "owner/pull${TAB}5"

echo "[4] usage errors"
set +e
bash "$PARSE" --bogus >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 2 ]; then pass "unknown arg → exit 2"; else fail "unknown arg: expected exit 2, got $rc"; fi

printf '\nBC-12580 greptile-pr-ref unit tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
