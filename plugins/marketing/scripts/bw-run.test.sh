#!/usr/bin/env bash
# bw-run.test.sh — pure-bash test suite for bw-run.sh (BC-6906).
# Stubs `bw` via PATH-prepended temp dir; real `jq` is required on PATH.
# 11 cases: 5 spec-mandated + 6 review-driven (T-F1 BW_SESSION unset,
# T-F3 mixed-result batch, T-F4 sequential per-item failure, T-F5 empty
# EXPORTS, P3-1 missing command after --, P3-8 bad-arg-shape variants).
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
mkdir -p "$STUB_GET_DIR"

cat >"$STUB_DIR/bw" <<'BWSTUB'
#!/usr/bin/env bash
# bw stub: logs argv, emits scripted output based on $STUB_* env vars.
printf '%s\n' "$*" >>"$STUB_CALL_LOG"
case "$1" in
  status)
    cat "$STUB_STATUS_FILE"
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
export PATH="$STUB_DIR:$PATH"

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
t6_bw_calls=$(grep -c '^' "$STUB_CALL_LOG" || true)
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

# --- Summary ---------------------------------------------------------------
echo ""
echo "$TESTS_RUN tests run, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
