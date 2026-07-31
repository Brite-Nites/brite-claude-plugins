#!/usr/bin/env bash
# bw-run.test.sh — pure-bash test suite for bw-run.sh (BC-6906).
# Stubs `bw` AND `security` via PATH-prepended temp dir; real `jq` is
# required on PATH. 31 cases / 111 assertions: 5 spec-mandated + review-driven additions
# (T-F1 BW_SESSION unset, T-F3 mixed-result batch, T-F4 sequential per-item
# failure, T-F5 empty EXPORTS, P3-1 missing command after --, P3-8
# bad-arg-shape variants, BC-6958 micro-fix coverage) + 16 Keychain
# self-unlock cases (T16–T31, covering the happy path, both fail-closed
# exits, the single-attempt contract, the two binary-trust rejections, and the
# minted-session non-export plus its caller-supplied control, and the two
# path-safety rejections, the symlink-target checks, and the listed-path
# narrowing pair).
# The `security` stub defaults to item-not-found so every pre-self-unlock
# case keeps its exact behavior regardless of the developer's real Keychain.
# macOS bash 3.2 portable.
set -euo pipefail

# --- Locate wrapper under test ---------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="$SCRIPT_DIR/bw-run.sh"
if [ ! -x "$WRAPPER" ]; then
  echo "bw-run.test.sh: wrapper not found or not executable at $WRAPPER" >&2
  exit 2
fi
if ! command -v jq >/dev/null; then
  echo "bw-run.test.sh: jq required on PATH (bw-run.sh depends on it)" >&2
  exit 2
fi

# --- Stub bw via PATH ------------------------------------------------------
STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT
export STUB_CALL_LOG="$STUB_DIR/calls.log"
export STUB_STATUS_FILE="$STUB_DIR/status.json"
export STUB_LIST_FILE="$STUB_DIR/list.json"
export STUB_GET_DIR="$STUB_DIR/passwords"
export STUB_KEYCHAIN_FILE="$STUB_DIR/keychain.pw"
export STUB_UNLOCK_TOKEN_FILE="$STUB_DIR/unlock.token"
export STUB_STATUS_AFTER_UNLOCK_FILE="$STUB_DIR/status-after-unlock.json"
mkdir -p "$STUB_GET_DIR"

cat >"$STUB_DIR/bw" <<'BWSTUB'
#!/usr/bin/env bash
# bw stub: logs argv, emits scripted output based on $STUB_* env vars.
printf '%s\n' "$*" >>"$STUB_CALL_LOG"
case "$1" in
  status)
    # Dynamic status for self-unlock tests: once an `unlock` call has been
    # logged, serve the after-unlock status when one is scripted.
    if [ -f "$STUB_STATUS_AFTER_UNLOCK_FILE" ] && grep -q '^unlock' "$STUB_CALL_LOG"; then
      cat "$STUB_STATUS_AFTER_UNLOCK_FILE"
    else
      cat "$STUB_STATUS_FILE"
    fi
    ;;
  unlock)
    # `unlock --raw --passwordenv BW_PASSWORD` — scripted self-unlock result.
    if [ -f "$STUB_UNLOCK_TOKEN_FILE" ]; then
      cat "$STUB_UNLOCK_TOKEN_FILE"
    else
      echo "Invalid master password." >&2
      exit 1
    fi
    ;;
  list)
    # `list items --search <prefix>` — emit the scripted JSON array.
    cat "$STUB_LIST_FILE"
    ;;
  get)
    # `get password <item>` — emit per-item file or exit nonzero.
    item="$3"
    f="$STUB_GET_DIR/$item"
    if [ -f "$f" ]; then
      cat "$f"
    else
      echo "Not found." >&2
      exit 1
    fi
    ;;
  *)
    echo "bw stub: unhandled argv: $*" >&2
    exit 99
    ;;
esac
BWSTUB
chmod +x "$STUB_DIR/bw"

cat >"$STUB_DIR/security" <<'SECSTUB'
#!/usr/bin/env bash
# security stub: `find-generic-password -s bw-master -w` — scripted Keychain.
# Defaults to not-found (exit 44, matching macOS) so tests never consult the
# developer's real Keychain.
printf 'security %s\n' "$*" >>"$STUB_CALL_LOG"
if [ -f "$STUB_KEYCHAIN_FILE" ]; then
  cat "$STUB_KEYCHAIN_FILE"
else
  echo "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." >&2
  exit 44
fi
SECSTUB
chmod +x "$STUB_DIR/security"
export PATH="$STUB_DIR:$PATH"
# The self-unlock path will only hand the master password to a binary it
# trusts: a mode-0700 directory we own, under ancestors that are ours or
# root's and not group/other-writable unless sticky. A known install path is
# narrowed, not waved through — it skips the 0700 rule a 0755 system directory
# cannot meet, and nothing else (T30/T31). Symlinks are followed and both ends
# checked (T28/T29). The overrides get the same treatment, so pointing them at
# the stubs works only because `mktemp -d` creates STUB_DIR as 0700 under
# sticky /tmp. That is also why an attacker cannot use this route (T22, T26),
# and it means every self-unlock case below exercises the sticky-ancestor
# exemption as a side effect.
#
# Coverage limit, stated rather than left implied: the `[ -O ]` ownership test
# is NOT directly exercised. Constructing the case it defends — a directory
# owned by someone else — needs a second uid, which this suite has no way to
# obtain. T26 covers the ancestor half of the same predicate, and T30 covers
# the write-bit half on the listed branch.
export BW_RUN_SECURITY_BIN="$STUB_DIR/security"
export BW_RUN_BW_BIN="$STUB_DIR/bw"
# The Keychain lookup is scoped to the invoking account, matching the -a the
# provisioning hint documents.
TEST_ACCOUNT="${USER:-$(id -un)}"
# Captured before any jq shadowing (STUB_DIR holds no jq), so the T24/T25
# shadow can record what it saw and then delegate to the real thing.
REAL_JQ="$(command -v jq)"

# --- Test harness ----------------------------------------------------------
TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$1" = "$2" ]; then
    echo "PASS [$3]"
  else
    echo "FAIL [$3]: expected '$2', got '$1'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$1" in
    *"$2"*) echo "PASS [$3]" ;;
    *)
      echo "FAIL [$3]: expected substring '$2' in '$1'"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

setup() {
  : >"$STUB_CALL_LOG"
  printf '{"status":"unlocked"}' >"$STUB_STATUS_FILE"
  printf '[]' >"$STUB_LIST_FILE"
  rm -f "$STUB_GET_DIR"/*
  rm -f "$STUB_KEYCHAIN_FILE" "$STUB_UNLOCK_TOKEN_FILE" "$STUB_STATUS_AFTER_UNLOCK_FILE"
}

# --- TEST 1: Locked vault -> exit 1 ----------------------------------------
echo "--- TEST 1: locked vault -> exit 1 ---"
setup
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
out_file="$STUB_DIR/t1.out"; err_file="$STUB_DIR/t1.err"
set +e
BW_SESSION=fake bash "$WRAPPER" KEY=item -- echo wrapped >"$out_file" 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t1 exit code is 1"
assert_eq "$(cat "$out_file")" "" "t1 stdout empty"
assert_contains "$(cat "$err_file")" "vault is not unlocked" "t1 stderr names remediation"

# --- TEST 2: Missing item -> exit 3 (batch path, prefix=tam-map-) ----------
echo "--- TEST 2: missing item -> exit 3 ---"
setup
printf '[]' >"$STUB_LIST_FILE"
err_file="$STUB_DIR/t2.err"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  SPIDER_API_KEY=tam-map-spider-api-key \
  AIARK_API_KEY=tam-map-aiark-api-key \
  -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "3" "t2 exit code is 3"
assert_contains "$(cat "$err_file")" "tam-map-spider-api-key" "t2 stderr names missing item"
# P3-7: lock down that T2 took the batch path (not sequential) — symmetry with T3/T4.
t2_get_calls=$(grep -c '^get password' "$STUB_CALL_LOG" || true)
assert_eq "$t2_get_calls" "0" "t2 zero sequential get calls"

# --- TEST 3: Multi-key batch -> 1 list call, all keys exported -------------
echo "--- TEST 3: multi-key batch (86% savings case) ---"
setup
cat >"$STUB_LIST_FILE" <<'JSON'
[
  {"name":"tam-map-spider-api-key","login":{"password":"value-S"}},
  {"name":"tam-map-aiark-api-key","login":{"password":"value-A"}},
  {"name":"tam-map-discolike-api-key","login":{"password":"value-D"}}
]
JSON
out_file="$STUB_DIR/t3.out"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  SPIDER_API_KEY=tam-map-spider-api-key \
  AIARK_API_KEY=tam-map-aiark-api-key \
  DISCOLIKE_API_KEY=tam-map-discolike-api-key \
  -- bash -c 'env | grep -E "^(SPIDER|AIARK|DISCOLIKE)_API_KEY=" | sort' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t3 exit code is 0"
list_calls=$(grep -c '^list items --search tam-map-' "$STUB_CALL_LOG" || true)
assert_eq "$list_calls" "1" "t3 exactly 1 batch list call"
get_calls=$(grep -c '^get password' "$STUB_CALL_LOG" || true)
assert_eq "$get_calls" "0" "t3 zero sequential get calls"
assert_contains "$(cat "$out_file")" "AIARK_API_KEY=value-A" "t3 AIARK_API_KEY exported"
assert_contains "$(cat "$out_file")" "DISCOLIKE_API_KEY=value-D" "t3 DISCOLIKE_API_KEY exported"
assert_contains "$(cat "$out_file")" "SPIDER_API_KEY=value-S" "t3 SPIDER_API_KEY exported"

# --- TEST 4: Divergent naming -> sequential fallback ----------------------
echo "--- TEST 4: divergent naming (no common prefix >=3) ---"
setup
# Item names "alpha-key" and "beta-key" share no >=1-char prefix (a vs b).
printf 'val-alpha' >"$STUB_GET_DIR/alpha-key"
printf 'val-beta'  >"$STUB_GET_DIR/beta-key"
out_file="$STUB_DIR/t4.out"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  KEY1=alpha-key \
  KEY2=beta-key \
  -- bash -c 'env | grep -E "^KEY[12]=" | sort' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t4 exit code is 0"
list_calls=$(grep -c '^list items --search' "$STUB_CALL_LOG" || true)
assert_eq "$list_calls" "0" "t4 zero batch list calls"
get_calls=$(grep -c '^get password' "$STUB_CALL_LOG" || true)
assert_eq "$get_calls" "2" "t4 exactly 2 sequential get calls"
assert_contains "$(cat "$out_file")" "KEY1=val-alpha" "t4 KEY1 exported"
assert_contains "$(cat "$out_file")" "KEY2=val-beta" "t4 KEY2 exported"

# --- TEST 5: Usage error (missing --) -> exit 2 ---------------------------
# Pass only `KEY=item` with no following args: parser consumes the KEY=item entry,
# loop exits cleanly with $#==0, then the post-loop `[ "$1" != "--" ]` check trips
# the missing-separator error. Adding stray non-KEY=item args (e.g. `echo wrapped`)
# would instead trip the bad-arg-shape branch (also exit 2) and emit a different
# stderr message, so we keep the failure path narrow to satisfy the spec verbatim.
echo "--- TEST 5: usage error (missing -- separator) ---"
setup
err_file="$STUB_DIR/t5.err"
set +e
BW_SESSION=fake bash "$WRAPPER" KEY=item >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "2" "t5 exit code is 2"
assert_contains "$(cat "$err_file")" "missing -- separator" "t5 stderr names cause"

# --- TEST 6 (T-F1): BW_SESSION unset -> exit 1 -----------------------------
echo "--- TEST 6: BW_SESSION unset -> exit 1 ---"
setup
err_file="$STUB_DIR/t6.err"
set +e
env -u BW_SESSION bash "$WRAPPER" KEY=item -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t6 exit code is 1"
assert_contains "$(cat "$err_file")" "BW_SESSION not set" "t6 stderr names BW_SESSION"
# The self-unlock preflight may consult the local Keychain (`security` lines)
# before failing; the invariant here is zero *bw* subprocess calls.
t6_bw_calls=$(grep -vc '^security ' "$STUB_CALL_LOG" || true)
assert_eq "$t6_bw_calls" "0" "t6 no bw calls before exit"

# --- TEST 7 (T-F3): Mixed-result batch (some present, some missing) -> exit 3
echo "--- TEST 7: mixed-result batch -> exit 3 ---"
setup
# Cache returns 1 of 2 requested items; per-iteration jq trips empty for the missing one.
cat >"$STUB_LIST_FILE" <<'JSON'
[
  {"name":"tam-map-spider-api-key","login":{"password":"value-S"}}
]
JSON
err_file="$STUB_DIR/t7.err"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  SPIDER_API_KEY=tam-map-spider-api-key \
  AIARK_API_KEY=tam-map-aiark-api-key \
  -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "3" "t7 exit code is 3"
assert_contains "$(cat "$err_file")" "tam-map-aiark-api-key" "t7 stderr names the missing item specifically"
t7_list_calls=$(grep -c '^list items --search' "$STUB_CALL_LOG" || true)
assert_eq "$t7_list_calls" "1" "t7 took batch path (1 list call)"

# --- TEST 8 (T-F4): Sequential fallback per-item failure -> exit 3 ---------
echo "--- TEST 8: sequential per-item failure -> exit 3 ---"
setup
# Divergent names so wrapper takes sequential path; only one password file present.
printf 'val-alpha' >"$STUB_GET_DIR/alpha-key"
# beta-key file intentionally absent -> stub `bw get password beta-key` exits 1.
err_file="$STUB_DIR/t8.err"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  KEY1=alpha-key \
  KEY2=beta-key \
  -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "3" "t8 exit code is 3"
assert_contains "$(cat "$err_file")" "beta-key" "t8 stderr names the missing item"
t8_list_calls=$(grep -c '^list items --search' "$STUB_CALL_LOG" || true)
assert_eq "$t8_list_calls" "0" "t8 took sequential path (zero batch calls)"

# --- TEST 9 (T-F5): Empty EXPORTS -> exit 0, exec wrapped command ---------
# Defends BC-6905 task-2 macOS bash 3.2 empty-array guard at bw-run.sh L55, L72.
echo "--- TEST 9: empty EXPORTS -> exit 0 ---"
setup
out_file="$STUB_DIR/t9.out"
set +e
BW_SESSION=fake bash "$WRAPPER" -- bash -c 'echo from-wrapped' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t9 exit code is 0"
assert_eq "$(cat "$out_file")" "from-wrapped" "t9 wrapped command ran with no exports"
t9_bw_calls=$(grep -c '^' "$STUB_CALL_LOG" || true)
# bw status is the only bw call expected (preflight); no list/get since EXPORTS is empty.
assert_eq "$t9_bw_calls" "1" "t9 only the bw status preflight ran"

# --- TEST 10 (P3-1): Missing command after -- -> exit 2 -------------------
echo "--- TEST 10: missing command after -- -> exit 2 ---"
setup
err_file="$STUB_DIR/t10.err"
set +e
BW_SESSION=fake bash "$WRAPPER" KEY=item -- >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "2" "t10 exit code is 2"
assert_contains "$(cat "$err_file")" "missing command after --" "t10 stderr names cause"

# --- TEST 11 (P3-8): Bad-arg-shape variants -> exit 2 ---------------------
# Three sibling exit-2 paths in the parser: KEY= (empty value), =item (empty key),
# bare token (no `=`). All should produce exit 2 with the bad-arg-shape stderr.
echo "--- TEST 11: bad-arg-shape variants -> exit 2 ---"

# 11a: KEY= (empty value)
setup
err_file="$STUB_DIR/t11a.err"
set +e
BW_SESSION=fake bash "$WRAPPER" KEY= -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "2" "t11a exit code is 2"
assert_contains "$(cat "$err_file")" "expected KEY=item" "t11a stderr names cause"

# 11b: =item (empty key)
setup
err_file="$STUB_DIR/t11b.err"
set +e
BW_SESSION=fake bash "$WRAPPER" =item -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "2" "t11b exit code is 2"
assert_contains "$(cat "$err_file")" "expected KEY=item" "t11b stderr names cause"

# 11c: notakeyvaluepair (no `=`)
setup
err_file="$STUB_DIR/t11c.err"
set +e
BW_SESSION=fake bash "$WRAPPER" notakeyvaluepair -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "2" "t11c exit code is 2"
assert_contains "$(cat "$err_file")" "expected KEY=item or --" "t11c stderr names cause"

# --- TEST 12 (BC-6958 micro-fix 1): empty-vs-absent in batch path ----------
# Item is PRESENT in cache (jq matches by name) but `login.password` is empty.
# Defends BC-6958's diagnostic-clarity fix: operator gets "exists but empty"
# instead of the misleading "not found in batch search".
echo "--- TEST 12: present-but-empty password -> exit 3 (new stderr) ---"
setup
cat >"$STUB_LIST_FILE" <<'JSON'
[
  {"name":"tam-map-spider-api-key","login":{"password":""}}
]
JSON
err_file="$STUB_DIR/t12.err"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  SPIDER_API_KEY=tam-map-spider-api-key \
  -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "3" "t12 exit code is 3"
assert_contains "$(cat "$err_file")" "exists in batch but has empty password" "t12 stderr names empty-password branch"
assert_contains "$(cat "$err_file")" "tam-map-spider-api-key" "t12 stderr names the item"
t12_list_calls=$(grep -c '^list items --search' "$STUB_CALL_LOG" || true)
assert_eq "$t12_list_calls" "1" "t12 took batch path (1 list call)"
# Negative: empty-password branch must NOT print the absent-path message.
case "$(cat "$err_file")" in
  *"not found in batch search"*) FAIL_MSG=1 ;;
  *) FAIL_MSG=0 ;;
esac
assert_eq "$FAIL_MSG" "0" "t12 stderr does not also print absent-branch message"
# Symmetry with TESTS 2/3/7: zero sequential get calls (batch path is exclusive).
t12_get_calls=$(grep -c '^get password' "$STUB_CALL_LOG" || true)
assert_eq "$t12_get_calls" "0" "t12 zero sequential get calls"

# --- TEST 13 (BC-6958 micro-fix 1 P3): wrong_type — item without .login ----
# Defends the wrong_type branch added to bw-run.sh. A Bitwarden secure-note
# (or any non-login type) named correctly should produce a `wrong_type`
# diagnostic instead of being silently labeled as empty.
echo "--- TEST 13: wrong-type item (no .login block) -> exit 3 (wrong_type stderr) ---"
setup
cat >"$STUB_LIST_FILE" <<'JSON'
[
  {"name":"tam-map-spider-api-key","notes":"secure-note-no-login-field"}
]
JSON
err_file="$STUB_DIR/t13.err"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  SPIDER_API_KEY=tam-map-spider-api-key \
  -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "3" "t13 exit code is 3"
assert_contains "$(cat "$err_file")" "is not a Bitwarden login type" "t13 stderr names wrong-type branch"
assert_contains "$(cat "$err_file")" "tam-map-spider-api-key" "t13 stderr names the item"
case "$(cat "$err_file")" in
  *"empty password"*|*"not found in batch search"*) FAIL_MSG=1 ;;
  *) FAIL_MSG=0 ;;
esac
assert_eq "$FAIL_MSG" "0" "t13 stderr does not print empty-or-absent branch messages"

# --- TEST 14 (BC-6958 micro-fix 1 P3): null login.password -> empty branch -
# Bitwarden items can technically have `login.password = null` (e.g. partially
# edited via `bw edit`). Pin contract: null is treated the same as empty
# string (the existing `// ""` fallback in the value-fetch jq pipeline).
echo "--- TEST 14: null login.password -> exit 3 (empty-password stderr) ---"
setup
cat >"$STUB_LIST_FILE" <<'JSON'
[
  {"name":"tam-map-spider-api-key","login":{"password":null}}
]
JSON
err_file="$STUB_DIR/t14.err"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  SPIDER_API_KEY=tam-map-spider-api-key \
  -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "3" "t14 exit code is 3"
assert_contains "$(cat "$err_file")" "exists in batch but has empty password" "t14 stderr routes null to empty-password branch"

# --- TEST 15 (BC-6958 micro-fix 1 P3): duplicate-name first-wins -----------
# Bitwarden in principle allows duplicate item names. Pin contract: jq's
# `first(...)` returns the first match — exporting the first item's value.
# If a future refactor changes the behavior, this test surfaces the choice.
echo "--- TEST 15: duplicate-name in cache -> first-wins export ---"
setup
cat >"$STUB_LIST_FILE" <<'JSON'
[
  {"name":"tam-map-spider-api-key","login":{"password":"first-A"}},
  {"name":"tam-map-spider-api-key","login":{"password":"second-B"}}
]
JSON
out_file="$STUB_DIR/t15.out"
set +e
BW_SESSION=fake bash "$WRAPPER" \
  SPIDER_API_KEY=tam-map-spider-api-key \
  -- bash -c 'env | grep "^SPIDER_API_KEY="' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t15 exit code is 0"
assert_contains "$(cat "$out_file")" "SPIDER_API_KEY=first-A" "t15 first-match value wins"
case "$(cat "$out_file")" in
  *"second-B"*) FAIL_MSG=1 ;;
  *) FAIL_MSG=0 ;;
esac
assert_eq "$FAIL_MSG" "0" "t15 second-match value is not exported"

# --- TEST 16: Keychain self-unlock when BW_SESSION unset -------------------
# Opt-in path: no session, but the Keychain item exists and `bw unlock`
# succeeds -> wrapper mints a session and proceeds to fetch + exec.
echo "--- TEST 16: keychain self-unlock, BW_SESSION unset -> success ---"
setup
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
printf '{"status":"unlocked"}' >"$STUB_STATUS_AFTER_UNLOCK_FILE"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
printf '[{"name":"solo-key","login":{"password":"val-solo"}}]' >"$STUB_LIST_FILE"
out_file="$STUB_DIR/t16.out"
set +e
env -u BW_SESSION bash "$WRAPPER" \
  KEY1=solo-key \
  -- bash -c 'env | grep -E "^(KEY1|BW_SESSION)=" | sort' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t16 exit code is 0"
assert_contains "$(cat "$out_file")" "KEY1=val-solo" "t16 KEY1 exported"
unlock_calls=$(grep -c '^unlock --raw --passwordenv BW_PASSWORD' "$STUB_CALL_LOG" || true)
assert_eq "$unlock_calls" "1" "t16 exactly 1 unlock call with --passwordenv"
sec_calls=$(grep -Fxc "security find-generic-password -a $TEST_ACCOUNT -s bw-master -w" "$STUB_CALL_LOG" || true)
assert_eq "$sec_calls" "1" "t16 keychain consulted once, scoped to our account"
# Negative: an unscoped lookup (service name only) can match another account's
# same-service item, so the -a must not regress away.
t16_unscoped=$(grep -Fxc "security find-generic-password -s bw-master -w" "$STUB_CALL_LOG" || true)
assert_eq "$t16_unscoped" "0" "t16 no unscoped keychain lookup"
case "$(cat "$out_file")" in
  *"BW_SESSION="*) T16_LEAK=1 ;;
  *) T16_LEAK=0 ;;
esac
assert_eq "$T16_LEAK" "0" "t16 minted BW_SESSION not visible to wrapped process"

# --- TEST 17: No Keychain item + no session -> original fail-closed --------
echo "--- TEST 17: no keychain item, BW_SESSION unset -> exit 1 + hint ---"
setup
err_file="$STUB_DIR/t17.err"
set +e
env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t17 exit code is 1"
assert_contains "$(cat "$err_file")" "BW_SESSION not set" "t17 stderr keeps original error"
assert_contains "$(cat "$err_file")" "add-generic-password" "t17 stderr carries provisioning hint"

# --- TEST 18: Stale session + Keychain item -> re-mint and proceed ---------
echo "--- TEST 18: stale BW_SESSION, keychain present -> re-mint ---"
setup
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
printf '{"status":"unlocked"}' >"$STUB_STATUS_AFTER_UNLOCK_FILE"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
printf '[{"name":"solo-key","login":{"password":"val-solo"}}]' >"$STUB_LIST_FILE"
out_file="$STUB_DIR/t18.out"
set +e
BW_SESSION=stale-token bash "$WRAPPER" \
  KEY1=solo-key \
  -- bash -c 'env | grep "^KEY1="' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t18 exit code is 0"
assert_contains "$(cat "$out_file")" "KEY1=val-solo" "t18 KEY1 exported"
unlock_calls=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$unlock_calls" "1" "t18 exactly 1 re-mint unlock call"

# --- TEST 19: Keychain present but unlock fails -> fail closed -------------
# Wrong stored master password (bw unlock exits 1). Must land on the
# original stale-session error, not loop or succeed.
echo "--- TEST 19: keychain present, unlock fails -> exit 1 ---"
setup
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
printf 'wrong-master-pw' >"$STUB_KEYCHAIN_FILE"
err_file="$STUB_DIR/t19.err"
set +e
BW_SESSION=stale-token bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t19 exit code is 1"
assert_contains "$(cat "$err_file")" "vault is not unlocked" "t19 stderr keeps stale-session error"

# --- TEST 20: untrusted/unresolvable bw binary -> self-unlock declines ------
# The self-unlock path must not hand the master password to a binary it can't
# resolve in a trusted prefix. With the override pointing nowhere, the mint is
# skipped entirely (no security call) and the wrapper fails closed.
echo "--- TEST 20: unresolvable bw binary -> no mint, exit 1 ---"
setup
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
err_file="$STUB_DIR/t20.err"
set +e
BW_RUN_BW_BIN="$STUB_DIR/does-not-exist" \
  env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t20 exit code is 1"
t20_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t20_unlock" "0" "t20 no unlock attempted with unresolvable bw"
t20_sec=$(grep -c '^security ' "$STUB_CALL_LOG" || true)
assert_eq "$t20_sec" "0" "t20 master password never read when bw is untrusted"

# --- TEST 21: single-attempt contract (ADR-010 § 1) ------------------------
# Mint succeeds but verification still reports locked. The wrapper must NOT
# mint a second time from the stale-session branch.
echo "--- TEST 21: mint succeeds but status still locked -> exactly 1 attempt ---"
setup
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"   # no after-unlock file: stays locked
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
err_file="$STUB_DIR/t21.err"
set +e
env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t21 exit code is 1"
t21_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t21_unlock" "1" "t21 exactly one mint attempt (no double-unlock)"
assert_contains "$(cat "$err_file")" "vault is not unlocked" "t21 fails closed with stale-session error"

# --- TEST 22: override pointing into an untrusted directory -> declines -----
# The regression this pins: BW_RUN_BW_BIN used to accept ANY executable, which
# handed the master password to an attacker-chosen binary and reopened the very
# hole the absolute-path resolution closes. An env var an attacker can set must
# not be an exemption from the trust check. Here the override is a perfectly
# executable copy of the working stub — only its directory is wrong (0755, the
# mode of every place a binary can actually be planted: /tmp, /usr/local/bin,
# node_modules/.bin).
echo "--- TEST 22: bw override in a non-private dir -> no mint, exit 1 ---"
setup
UNTRUSTED_DIR="$STUB_DIR/untrusted"
mkdir -p "$UNTRUSTED_DIR"
chmod 0755 "$UNTRUSTED_DIR"
cp "$STUB_DIR/bw" "$UNTRUSTED_DIR/bw"
chmod +x "$UNTRUSTED_DIR/bw"
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
printf '{"status":"unlocked"}' >"$STUB_STATUS_AFTER_UNLOCK_FILE"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
err_file="$STUB_DIR/t22.err"
# Guard the premise: the override IS executable, so a rejection can only come
# from the trust check and not from the -x test.
assert_eq "$([ -x "$UNTRUSTED_DIR/bw" ] && echo yes || echo no)" "yes" "t22 override is executable"
set +e
BW_RUN_BW_BIN="$UNTRUSTED_DIR/bw" \
  env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t22 exit code is 1"
t22_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t22_unlock" "0" "t22 no unlock attempted with an untrusted bw"
t22_sec=$(grep -c '^security ' "$STUB_CALL_LOG" || true)
assert_eq "$t22_sec" "0" "t22 master password never read for an untrusted bw"
assert_contains "$(cat "$err_file")" "BW_SESSION not set" "t22 fails closed"

# --- TEST 23: security override in an untrusted directory -> declines -------
# Same rule on the other subprocess. A substituted `security` does not receive
# the master password, but it supplies it, so an attacker-chosen one steers the
# unlock; the check is uniform rather than argued case by case.
echo "--- TEST 23: security override in a non-private dir -> no mint, exit 1 ---"
setup
cp "$STUB_DIR/security" "$UNTRUSTED_DIR/security"
chmod +x "$UNTRUSTED_DIR/security"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
err_file="$STUB_DIR/t23.err"
set +e
BW_RUN_SECURITY_BIN="$UNTRUSTED_DIR/security" \
  env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t23 exit code is 1"
t23_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t23_unlock" "0" "t23 no unlock attempted with an untrusted security"
t23_sec=$(grep -c '^security ' "$STUB_CALL_LOG" || true)
assert_eq "$t23_sec" "0" "t23 untrusted security binary never invoked"

# --- TEST 26: private dir under a swappable parent -> declines --------------
# Mode 0700 stops a co-tenant writing INTO the directory. It does nothing about
# renaming the directory itself, which only needs write on the parent — so one
# attacker-writable, non-sticky ancestor and the whole thing can be swapped for
# an attacker's copy. The binary's own directory here is impeccable (0700,
# ours); only its parent is wrong. Contrast /tmp, which is equally
# world-writable but sticky, and which every self-unlock test above already
# walks through successfully — sticky means only an entry's own owner can
# rename it, so a co-tenant cannot swap our temp dir.
echo "--- TEST 26: 0700 dir under a world-writable non-sticky parent -> exit 1 ---"
setup
SWAPPABLE_PARENT="$STUB_DIR/swappable"
rm -rf "$SWAPPABLE_PARENT"
mkdir -p "$SWAPPABLE_PARENT/priv"
chmod 0700 "$SWAPPABLE_PARENT/priv"
cp "$STUB_DIR/bw" "$SWAPPABLE_PARENT/priv/bw"
chmod +x "$SWAPPABLE_PARENT/priv/bw"
chmod 0777 "$SWAPPABLE_PARENT"   # world-writable, NOT sticky
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
err_file="$STUB_DIR/t26.err"
# Premise guards: the binary is executable and its own directory is private,
# so a rejection can only come from the ancestor walk.
assert_eq "$([ -x "$SWAPPABLE_PARENT/priv/bw" ] && echo yes || echo no)" "yes" \
  "t26 override is executable"
assert_eq "$(ls -ld "$SWAPPABLE_PARENT/priv" | cut -c1-10)" "drwx------" \
  "t26 the binary's own directory is private"
set +e
BW_RUN_BW_BIN="$SWAPPABLE_PARENT/priv/bw" \
  env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t26 exit code is 1"
t26_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t26_unlock" "0" "t26 no unlock attempted under a swappable parent"
t26_sec=$(grep -c '^security ' "$STUB_CALL_LOG" || true)
assert_eq "$t26_sec" "0" "t26 master password never read under a swappable parent"

# --- TEST 27: relative override path -> declines ----------------------------
# The ancestor walk is only meaningful against a rooted path.
echo "--- TEST 27: relative bw override -> exit 1 ---"
setup
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
err_file="$STUB_DIR/t27.err"
set +e
(cd "$STUB_DIR" && BW_RUN_BW_BIN="./bw" \
  env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file")
rc=$?
set -e
assert_eq "$rc" "1" "t27 exit code is 1"
t27_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t27_unlock" "0" "t27 no unlock attempted for a relative override"

# --- Shadowed bw/jq on PATH (T24 premise, T25 control) ---------------------
# Both log what BW_SESSION they were handed, then delegate so the run proceeds
# normally. Whether they appear in the call log is the whole assertion.
SHADOW_DIR="$STUB_DIR/shadow"
mkdir -p "$SHADOW_DIR"
cat >"$SHADOW_DIR/bw" <<SHADOWBW
#!/usr/bin/env bash
printf 'SHADOW-BW session=[%s]\n' "\${BW_SESSION:-}" >>"\$STUB_CALL_LOG"
exec "$STUB_DIR/bw" "\$@"
SHADOWBW
cat >"$SHADOW_DIR/jq" <<SHADOWJQ
#!/usr/bin/env bash
printf 'SHADOW-JQ session=[%s]\n' "\${BW_SESSION:-}" >>"\$STUB_CALL_LOG"
exec "$REAL_JQ" "\$@"
SHADOWJQ
chmod +x "$SHADOW_DIR/bw" "$SHADOW_DIR/jq"

# --- TEST 24: a minted session never reaches PATH-resolved binaries ---------
# Minting creates a live vault token that would not otherwise exist, so it is
# the case that must not leak one. The minted session is therefore never
# exported: it goes to the already-trusted binary one invocation at a time.
# A `bw` and a `jq` planted earlier in PATH must come away with nothing —
# the bw must not run at all, and the jq must see an empty BW_SESSION.
echo "--- TEST 24: minted session invisible to PATH-shadowed bw/jq ---"
setup
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
printf '{"status":"unlocked"}' >"$STUB_STATUS_AFTER_UNLOCK_FILE"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
printf '[{"name":"solo-key","login":{"password":"val-solo"}}]' >"$STUB_LIST_FILE"
out_file="$STUB_DIR/t24.out"
set +e
PATH="$SHADOW_DIR:$PATH" env -u BW_SESSION bash "$WRAPPER" \
  KEY1=solo-key -- bash -c 'env | grep "^KEY1="' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t24 exit code is 0 (trusted bw used, shadow bypassed)"
assert_contains "$(cat "$out_file")" "KEY1=val-solo" "t24 KEY1 exported"
t24_shadow_bw=$(grep -c '^SHADOW-BW ' "$STUB_CALL_LOG" || true)
assert_eq "$t24_shadow_bw" "0" "t24 PATH-shadowed bw never invoked"
t24_jq_leak=$(grep -c '^SHADOW-JQ session=\[minted-session-token\]' "$STUB_CALL_LOG" || true)
assert_eq "$t24_jq_leak" "0" "t24 minted session never reaches jq env"
# Premise guard: if the shadowed jq never ran at all, the leak assertion above
# would pass for the wrong reason.
t24_jq_ran=$(grep -c '^SHADOW-JQ session=\[\]' "$STUB_CALL_LOG" || true)
assert_eq "$([ "$t24_jq_ran" -ge 1 ] && echo yes || echo no)" "yes" \
  "t24 premise: shadowed jq did run, and saw an empty session"

# --- TEST 25: caller-supplied session keeps the pre-existing PATH behavior ---
# Negative control with two jobs. It proves T24's detector actually detects —
# a leak shows up in the same log when one genuinely exists — and it pins
# ADR-010's deferred scope line: a caller-exported BW_SESSION still reaches
# PATH-resolved binaries, exactly as it did before this PR. Narrowing that is
# the separate proposal; if someone takes it on, this test should change
# deliberately rather than be discovered by surprise.
echo "--- TEST 25: caller-supplied session still reaches PATH binaries (control) ---"
setup
printf '[{"name":"solo-key","login":{"password":"val-solo"}}]' >"$STUB_LIST_FILE"
out_file="$STUB_DIR/t25.out"
set +e
PATH="$SHADOW_DIR:$PATH" BW_SESSION=caller-token bash "$WRAPPER" \
  KEY1=solo-key -- bash -c 'env | grep "^KEY1="' >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t25 exit code is 0"
assert_contains "$(cat "$out_file")" "KEY1=val-solo" "t25 KEY1 exported"
t25_bw_saw=$(grep -c '^SHADOW-BW session=\[caller-token\]' "$STUB_CALL_LOG" || true)
assert_eq "$([ "$t25_bw_saw" -ge 1 ] && echo yes || echo no)" "yes" \
  "t25 caller session reaches PATH-resolved bw (pre-existing, ADR-010 scope line)"
t25_jq_saw=$(grep -c '^SHADOW-JQ session=\[caller-token\]' "$STUB_CALL_LOG" || true)
assert_eq "$([ "$t25_jq_saw" -ge 1 ] && echo yes || echo no)" "yes" \
  "t25 detector works: a real leak does show up in this log"

# --- TEST 28: symlink in a private dir pointing somewhere unsafe -> declines -
# Checking the link's directory says nothing about where the link points. Here
# the override's own directory is impeccable (0700, ours) and only the TARGET
# sits in a world-writable directory — so the rejection can only come from
# following the link and checking the far end.
echo "--- TEST 28: bw symlink -> world-writable target -> no mint, exit 1 ---"
setup
LINK_DIR="$STUB_DIR/linkdir"
BAD_TARGET_DIR="$STUB_DIR/badtarget"
rm -rf "$LINK_DIR" "$BAD_TARGET_DIR"
mkdir -p "$LINK_DIR" "$BAD_TARGET_DIR"
cp "$STUB_DIR/bw" "$BAD_TARGET_DIR/bw"
chmod +x "$BAD_TARGET_DIR/bw"
chmod 0700 "$LINK_DIR"
chmod 0777 "$BAD_TARGET_DIR"
ln -sf "$BAD_TARGET_DIR/bw" "$LINK_DIR/bw"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
assert_eq "$(ls -ld "$LINK_DIR" | cut -c1-10)" "drwx------" \
  "t28 the link's own directory is private"
assert_eq "$([ -x "$LINK_DIR/bw" ] && echo yes || echo no)" "yes" \
  "t28 the link resolves to an executable"
err_file="$STUB_DIR/t28.err"
set +e
BW_RUN_BW_BIN="$LINK_DIR/bw" \
  env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t28 exit code is 1"
t28_sec=$(grep -c '^security ' "$STUB_CALL_LOG" || true)
assert_eq "$t28_sec" "0" "t28 master password never read for an unsafe link target"

# --- TEST 29: symlink to a safe target -> still works -----------------------
# Symlinks are followed, not banned. Homebrew genuinely symlinks its bin
# entries into ../Cellar, so a blanket rejection would break real installs.
echo "--- TEST 29: bw symlink -> private target -> mint succeeds ---"
setup
SAFE_LINK_DIR="$STUB_DIR/linkdir2"
rm -rf "$SAFE_LINK_DIR"
mkdir -p "$SAFE_LINK_DIR"
chmod 0700 "$SAFE_LINK_DIR"
ln -sf "$STUB_DIR/bw" "$SAFE_LINK_DIR/bw"
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
printf '{"status":"unlocked"}' >"$STUB_STATUS_AFTER_UNLOCK_FILE"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
printf '[{"name":"solo-key","login":{"password":"val-solo"}}]' >"$STUB_LIST_FILE"
out_file="$STUB_DIR/t29.out"
set +e
BW_RUN_BW_BIN="$SAFE_LINK_DIR/bw" \
  env -u BW_SESSION bash "$WRAPPER" KEY1=solo-key -- bash -c 'env | grep "^KEY1="' \
  >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t29 exit code is 0"
assert_contains "$(cat "$out_file")" "KEY1=val-solo" "t29 KEY1 exported through a symlinked bw"
t29_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t29_unlock" "1" "t29 exactly 1 unlock via the symlinked binary"

# --- TESTS 30/31: a known-install path is NARROWED, not waved through --------
# The allowlist branch used to return success on a bare string match, so the
# one branch meaning "known good" was the only branch that checked nothing.
# The real allowlist points at /usr/local/bin and friends, which no test can
# write to, so these two run a COPY of the wrapper with the allowlist rewritten
# to a directory the suite controls. The sed guard below fails loudly if the
# call site ever drifts, so this cannot quietly stop testing anything.
LISTED_WRAPPER="$STUB_DIR/bw-run-listed.sh"
LISTED_BAD_DIR="$STUB_DIR/listed-bad"
LISTED_OK_DIR="$STUB_DIR/listed-ok"
rm -rf "$LISTED_BAD_DIR" "$LISTED_OK_DIR"
mkdir -p "$LISTED_BAD_DIR" "$LISTED_OK_DIR"
cp "$STUB_DIR/bw" "$LISTED_BAD_DIR/bw"; chmod +x "$LISTED_BAD_DIR/bw"
cp "$STUB_DIR/bw" "$LISTED_OK_DIR/bw";  chmod +x "$LISTED_OK_DIR/bw"
chmod 0777 "$LISTED_BAD_DIR"   # group+other writable — the Homebrew-on-macOS shape
chmod 0755 "$LISTED_OK_DIR"    # 0755 but ours and not group/other writable
sed "s#/opt/homebrew/bin/bw /usr/local/bin/bw /usr/bin/bw#$LISTED_BAD_DIR/bw $LISTED_OK_DIR/bw#" \
  "$WRAPPER" >"$LISTED_WRAPPER"
chmod +x "$LISTED_WRAPPER"
listed_rewritten=$(grep -c -- "$LISTED_OK_DIR/bw" "$LISTED_WRAPPER" || true)
assert_eq "$([ "$listed_rewritten" -ge 1 ] && echo yes || echo no)" "yes" \
  "t30 premise: allowlist call site was rewritten (guards against drift)"

echo "--- TEST 30: listed path in a group/other-writable dir -> no mint, exit 1 ---"
setup
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
err_file="$STUB_DIR/t30.err"
set +e
BW_RUN_BW_BIN="$LISTED_BAD_DIR/bw" \
  env -u BW_SESSION bash "$LISTED_WRAPPER" KEY1=solo-key -- echo wrapped >/dev/null 2>"$err_file"
rc=$?
set -e
assert_eq "$rc" "1" "t30 exit code is 1"
t30_sec=$(grep -c '^security ' "$STUB_CALL_LOG" || true)
assert_eq "$t30_sec" "0" "t30 being listed does not skip the directory check"

echo "--- TEST 31: listed path in a sound 0755 dir -> mint succeeds (control) ---"
setup
printf '{"status":"locked"}' >"$STUB_STATUS_FILE"
printf '{"status":"unlocked"}' >"$STUB_STATUS_AFTER_UNLOCK_FILE"
printf 'stub-master-pw' >"$STUB_KEYCHAIN_FILE"
printf 'minted-session-token' >"$STUB_UNLOCK_TOKEN_FILE"
printf '[{"name":"solo-key","login":{"password":"val-solo"}}]' >"$STUB_LIST_FILE"
out_file="$STUB_DIR/t31.out"
set +e
BW_RUN_BW_BIN="$LISTED_OK_DIR/bw" \
  env -u BW_SESSION bash "$LISTED_WRAPPER" KEY1=solo-key -- bash -c 'env | grep "^KEY1="' \
  >"$out_file" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0" "t31 exit code is 0"
assert_contains "$(cat "$out_file")" "KEY1=val-solo" "t31 a sound listed path still works"
# Without this control T30 would pass even if the listed branch rejected
# everything, which would break every real Homebrew install.
t31_unlock=$(grep -c '^unlock' "$STUB_CALL_LOG" || true)
assert_eq "$t31_unlock" "1" "t31 control: listed paths are narrowed, not disabled"

# --- Summary ---------------------------------------------------------------
echo ""
echo "$TESTS_RUN tests run, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
