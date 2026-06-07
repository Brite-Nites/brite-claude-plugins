#!/usr/bin/env bash
# Behavioral eval for plugins/revops/scripts/validate_target_org.py (BC-12639).
#
# validate_target_org.py is the DETERMINISTIC, side-effect-free validator the σ3
# SF-write commands (/revops:create-sf-campaign, /revops:update-sf-campaign-status)
# delegate their Phase 0 `--target-org` shape guard to (ADR-028 emit-mode seam).
# It is a pure boolean check: exit 0 iff the candidate matches the canonical
# shell-injection guard regex ^[a-zA-Z0-9._@-]+$ (the SF org alias / username
# character set), non-zero otherwise. It makes NO shell-out / network / fs write —
# the command owns the emit idiom (σ3 soft-fail JSON; marketing hard-fail ERROR:).
#
# This is the FIRST security worked example of ADR-028's behavioral-eval tier:
# unlike BC-12623's structural markdown-grep proxy (which only asserts the guard
# is POSITIONED before the sink), this harness EXECUTES the validator against real
# injection payloads and asserts (a) rejection AND (b) no side effect — proving the
# guard actually stops `$(...)` / backtick / metacharacter command substitution
# rather than merely standing in the right place.
#
# Usage:
#   bash plugins/revops/scripts/test_validate_target_org.sh
#   bash plugins/revops/scripts/test_validate_target_org.sh /path/to/validate_target_org.py

set -u  # NOT set -e — non-zero exits are EXPECTED for reject scenarios.

# Defuse caller's git env (matches test_build_manifest.sh discipline; guards the
# stale-pre-push-hook GIT_DIR leak documented in CLAUDE.md).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${1:-$HERE/validate_target_org.py}"

pass=0
fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

# Run the validator on $1 inside an isolated sandbox tmpdir, capture exit code,
# and report whether the side-effect sentinel file `pwned` was created. Echoes
# "<rc> <sidefx:0|1>".
run_in_sandbox() {
  local candidate="$1"
  local box rc sidefx=0
  box="$(mktemp -d)"
  ( cd "$box" && python3 "$VALIDATOR" "$candidate" ) >/dev/null 2>&1
  rc=$?
  [ -e "$box/pwned" ] && sidefx=1
  rm -rf "$box"
  printf '%s %s' "$rc" "$sidefx"
}

# assert_reject "<label>" "<payload>"  — the payload must be REJECTED (rc != 0)
# AND leave no side-effect sentinel. The no-side-effect half is what makes this a
# behavioral eval rather than a regex unit test: if the validator ever shelled
# the value out, a `$(touch pwned)` / backtick payload would create `pwned`.
assert_reject() {
  local label="$1" payload="$2" rc sidefx
  read -r rc sidefx <<<"$(run_in_sandbox "$payload")"
  if [ "$rc" -ne 0 ]; then ok; else bad "reject: $label should be REJECTED (rc!=0)"; fi
  if [ "$sidefx" -eq 0 ]; then ok; else bad "reject: $label created the pwned sentinel (side effect!)"; fi
}

# assert_accept "<label>" "<value>"  — a legitimate alias/username must be
# ACCEPTED (rc == 0). The accept cases also make the harness fail CLOSED when the
# validator is absent/broken (python exits non-zero → not accepted → RED), so a
# reject-only suite can't go falsely green on a missing script.
assert_accept() {
  local label="$1" value="$2" rc sidefx
  read -r rc sidefx <<<"$(run_in_sandbox "$value")"
  if [ "$rc" -eq 0 ]; then ok; else bad "accept: $label should be ACCEPTED (rc==0) — also RED if validator absent"; fi
}

# ── Reject: shell-injection / metacharacter payloads (the residual vector) ────
# Each must be rejected AND cause no side effect. These are the values that
# survive the command's `"<value>"` double-quoting because bash expands them
# inside double quotes (command substitution) or that smuggle metacharacters.
assert_reject 'command-substitution $(touch pwned)' '$(touch pwned)'
assert_reject 'backtick `touch pwned`'              '`touch pwned`'
assert_reject 'backtick `id`'                       '`id`'
assert_reject 'SOQL-ish breakout x'"'"'; DROP'      "x'; DROP TABLE Campaign--"
assert_reject 'semicolon chain ;rm -rf'             'brite-prod;rm -rf /'
assert_reject 'pipe a|b'                            'brite-prod|cat'
assert_reject 'ampersand a&b'                       'brite-prod&id'
assert_reject 'redirect a>b'                        'brite-prod>/tmp/x'
assert_reject 'embedded space'                      'brite prod'
assert_reject 'double-quote'                        'brite"prod'
assert_reject 'single-quote'                        "brite'prod"
assert_reject 'env-var $HOME'                       '$HOME'
assert_reject 'leading-dollar $(id)inline'          'org$(id)'
assert_reject 'empty string'                        ''
assert_reject 'slash path-ish'                      'a/b'
assert_reject 'newline-embedded'                    $'brite\nprod'
assert_reject 'trailing-newline'                    $'brite-prod\n'

# ── Accept: legitimate SF org aliases / usernames ────────────────────────────
# Every character the canonical class allows: alphanumerics, dot, underscore,
# at, hyphen. A missing/broken validator fails these → RED.
assert_accept 'prod alias'        'brite-prod'
assert_accept 'sandbox alias'     'brite-sandbox'
assert_accept 'dotted alias'      'marketing-claude-prod'
assert_accept 'underscore alias'  'Dev_Sandbox_Access'
assert_accept 'SF username (@/.)' 'corinne@brite.com.sandbox'
assert_accept 'mixed-case+digits' 'Org123_Alias-v2'
assert_accept 'all-allowed-chars' 'a.B_9-z@x'

# ── Usage: no candidate supplied ─────────────────────────────────────────────
# The σ3 guard only fires when --target-org is explicitly supplied; calling the
# validator with no arg is a usage error, not an accept (must NOT exit 0).
( python3 "$VALIDATOR" ) >/dev/null 2>&1
if [ "$?" -ne 0 ]; then ok; else bad 'usage: no-arg invocation must NOT exit 0 (would wrongly accept absent value)'; fi

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
