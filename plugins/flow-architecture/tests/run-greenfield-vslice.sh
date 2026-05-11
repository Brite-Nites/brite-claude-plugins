#!/usr/bin/env bash
# BC-7057 v-slice integration test: greenfield against synthetic fixture.
#
# Scope today (plugin v0.2.8): Phase 1 surface only — exercises the four FDA
# helper scripts end-to-end against the synthetic fixture, asserts they meet
# Q12.5 + Q31.5 contracts. Phase 2-8 deep assertions are skip-with-reason
# pending BC-6959 sub-skill landings; each future sub-skill PR adds its own
# assertion. See `vslice-report.md` for the coverage matrix.
#
# Bash 3.2 compatible (macOS default). Stdlib python3 only.
# Empty-array `${arr[@]}` is guarded per BC-6905 gotcha (not used here, but the
# discipline applies if extending).

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$PLUGIN_ROOT/scripts"
FIXTURE="$SCRIPT_DIR/fixtures/synthetic-greenfield"
BREADCRUMB="$FIXTURE/docs/plans/.flow-phase-state.json"
SCRATCH_BREADCRUMB="$FIXTURE/docs/plans/.flow-test-scratch.json"

# Refuse to operate if the breadcrumb path ever drifts outside the fixture.
# Defensive: guards against a future edit that resolves $BREADCRUMB to the
# parent repo's docs/plans/.flow-phase-state.json (real state).
case "$BREADCRUMB" in
  "$FIXTURE"/*) ;;
  *) echo "fatal: \$BREADCRUMB ($BREADCRUMB) is not under \$FIXTURE ($FIXTURE); refusing to run" >&2
     exit 2 ;;
esac

# Preflight: ensure interpreters the harness assumes are on PATH. We fail
# fast with a clear message rather than emit a confusing assertion mid-run.
command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

# Hermetic env: drop any env-vars that influence helper-script behavior so the
# harness ignores parent-shell state. LINEAR_ISSUE_COUNT in particular comes
# from BriteBase-rooted shells and would silently flip detect-mode behavior.
#
# Source for the `_FLOW_SHAPE_*` and `FLOW_*_CACHE` private-var names: the
# three-tier resolution block at the top of `flow-detect-mode.sh` (`scripts/`
# sibling) and the corresponding cache emissions in `flow-context-load.sh`.
# If those helpers rename or add private vars, sync this unset list — a
# stale unset list silently drops hermeticity protection without a test
# failure.
unset LINEAR_ISSUE_COUNT FLOW_GH_AUTH_CACHE FLOW_SHAPE_CACHE \
      _FLOW_SHAPE_INTENT_EXISTS _FLOW_SHAPE_INVENTORY_EXISTS \
      _FLOW_SHAPE_FLOWS_DIR_EXISTS _FLOW_SHAPE_BREADCRUMB_EXISTS

# Pre-flight rerun reset: a prior failed run may have left a breadcrumb at
# $BREADCRUMB (intentional inspection contract). On rerun we explicitly note
# and clean so Section 2's BREADCRUMB_EXISTS=no assertion is meaningful.
if [ -f "$BREADCRUMB" ]; then
  printf 'pre-flight: removing stale breadcrumb from prior run: %s\n' "$BREADCRUMB"
  rm -f "$BREADCRUMB"
fi
rm -f "$SCRATCH_BREADCRUMB"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP  %s — %s\n' "$1" "$2"; SKIP=$((SKIP + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Match KEY=VALUE inside a captured stdout buffer.
expect_kv() {
  local hay="$1" key="$2" expected="$3"
  local line
  line="$(printf '%s\n' "$hay" | grep -E "^${key}=" || true)"
  if [ "$line" = "${key}=${expected}" ]; then
    pass "$key=$expected"
  else
    fail "expected $key=$expected, got: ${line:-<missing>}"
  fi
}

# ── Cleanup contract ────────────────────────────────────────────────
# Remove test-written breadcrumbs on clean run; leave the main breadcrumb in
# place on failure so the failed state is inspectable. The scratch file (used
# by Section 5b negative-path tests) is always removed.
cleanup_on_success() {
  rm -f "$BREADCRUMB" "$SCRATCH_BREADCRUMB"
}
cleanup_scratch_only() {
  rm -f "$SCRATCH_BREADCRUMB"
}

# ── Section 1: Fixture shape ────────────────────────────────────────
section "1/6" "Fixture shape"

if [ -d "$FIXTURE" ]; then
  pass "fixture directory present: $FIXTURE"
else
  fail "fixture directory missing: $FIXTURE"
fi

if [ -f "$FIXTURE/package.json" ]; then
  pass "package.json present"
else
  fail "package.json missing"
fi

if [ -f "$FIXTURE/.flow/config.json" ]; then
  pass ".flow/config.json present"
else
  fail ".flow/config.json missing"
fi

if [ -f "$FIXTURE/.flow/config.json" ] && \
   python3 -m json.tool "$FIXTURE/.flow/config.json" > /dev/null 2>&1; then
  pass ".flow/config.json parses as valid JSON"
else
  fail ".flow/config.json fails JSON parse"
fi

if [ -d "$FIXTURE/docs/plans" ]; then
  pass "docs/plans/ directory present (breadcrumb target)"
else
  fail "docs/plans/ directory missing — flow-resume-breadcrumb write would mkdir, but explicit is better"
fi

# Fixture build/lint/test stubs all return 0 per Q8 sub-criterion 5
# (build && lint && test pass on the fixture). Test all three so a regression
# in any package.json stub (or removal of a script) surfaces here rather than
# silently slipping under the build-only assertion. Distinguish "npm absent"
# (legit SKIP for the whole row) from "stub returned non-zero" (genuine FAIL).
if ! command -v npm >/dev/null 2>&1; then
  for FIXTURE_SCRIPT in build lint test; do
    skip "fixture: npm run $FIXTURE_SCRIPT" "npm not in PATH on this runner"
  done
else
  for FIXTURE_SCRIPT in build lint test; do
    if (cd "$FIXTURE" && npm run --silent "$FIXTURE_SCRIPT" > /dev/null 2>&1); then
      pass "fixture: npm run $FIXTURE_SCRIPT exits 0"
    else
      fail "fixture $FIXTURE_SCRIPT stub returned non-zero — package.json contract violated"
    fi
  done
fi

# ── Section 2: flow-detect-fda-shape.sh ─────────────────────────────
section "2/6" "flow-detect-fda-shape.sh against greenfield fixture"

SHAPE_OUT=""
if SHAPE_OUT="$("$SCRIPTS_DIR/flow-detect-fda-shape.sh" "$FIXTURE" 2>&1)"; then
  pass "flow-detect-fda-shape.sh exits 0"
else
  fail "flow-detect-fda-shape.sh exit non-zero"
  printf '%s\n' "$SHAPE_OUT" | sed 's/^/    | /'
fi

# Expected: all 5 EXISTS keys = no (fresh greenfield fixture, no FDA artifacts yet).
expect_kv "$SHAPE_OUT" "INTENT_EXISTS"       "no"
expect_kv "$SHAPE_OUT" "INVENTORY_EXISTS"    "no"
expect_kv "$SHAPE_OUT" "FLOWS_DIR_EXISTS"    "no"
expect_kv "$SHAPE_OUT" "JOURNEYS_DIR_EXISTS" "no"
expect_kv "$SHAPE_OUT" "BREADCRUMB_EXISTS"   "no"

# ── Section 3: flow-detect-mode.sh ──────────────────────────────────
section "3/6" "flow-detect-mode.sh classifies as greenfield"

# LINEAR_ISSUE_COUNT=0 forces the Q36.3 step-4 heuristic into the greenfield
# branch deterministically.
#
# Stdout-only capture (`2>/dev/null`) on the MODE_* helpers: detect-mode.sh
# writes the classification result to stdout and may emit diagnostic stderr
# on edge cases. Whole-buffer equality assertions below would silently break
# on benign stderr leakage; stdout-only capture keeps the assertion robust
# and pushes stderr to the terminal where it's still visible during CI.
MODE_OUT=""
if MODE_OUT="$(LINEAR_ISSUE_COUNT=0 "$SCRIPTS_DIR/flow-detect-mode.sh" "$FIXTURE" 2>/dev/null)"; then
  pass "flow-detect-mode.sh exits 0"
else
  fail "flow-detect-mode.sh exit non-zero (run helper standalone for stderr context)"
fi

if [ "$MODE_OUT" = "greenfield" ]; then
  pass "MODE=greenfield against fixture (LINEAR_ISSUE_COUNT=0)"
else
  fail "expected 'greenfield', got: '$MODE_OUT'"
fi

# Q36.3 step 4 heuristic: bracket the 10-issue threshold both sides.
# LINEAR_ISSUE_COUNT=9 → still greenfield (just below threshold).
MODE_OUT_9=""
if MODE_OUT_9="$(LINEAR_ISSUE_COUNT=9 "$SCRIPTS_DIR/flow-detect-mode.sh" "$FIXTURE" 2>/dev/null)"; then
  if [ "$MODE_OUT_9" = "greenfield" ]; then
    pass "MODE=greenfield when LINEAR_ISSUE_COUNT=9 (just below Q36.3 threshold)"
  else
    fail "expected 'greenfield' when LINEAR_ISSUE_COUNT=9, got: '$MODE_OUT_9'"
  fi
else
  fail "flow-detect-mode.sh exit non-zero with LINEAR_ISSUE_COUNT=9"
fi

# LINEAR_ISSUE_COUNT=10 → retrofit (at-and-above threshold).
MODE_OUT_RETROFIT=""
if MODE_OUT_RETROFIT="$(LINEAR_ISSUE_COUNT=10 "$SCRIPTS_DIR/flow-detect-mode.sh" "$FIXTURE" 2>/dev/null)"; then
  if [ "$MODE_OUT_RETROFIT" = "retrofit" ]; then
    pass "MODE=retrofit when LINEAR_ISSUE_COUNT=10 (Q36.3 step 4 heuristic)"
  else
    fail "expected 'retrofit' when LINEAR_ISSUE_COUNT=10, got: '$MODE_OUT_RETROFIT'"
  fi
else
  fail "flow-detect-mode.sh exit non-zero with LINEAR_ISSUE_COUNT=10"
fi

# ── Section 4: flow-context-load.sh emits 10-field preamble ─────────
section "4/6" "flow-context-load.sh emits Q12.5 preamble"

# FLOW_GH_AUTH_CACHE makes the gh check deterministic in CI where gh may
# be installed but unauthenticated (or absent).
PREAMBLE_OUT=""
if PREAMBLE_OUT="$(FLOW_GH_AUTH_CACHE=no LINEAR_ISSUE_COUNT=0 \
                    "$SCRIPTS_DIR/flow-context-load.sh" "$FIXTURE" 2>&1)"; then
  pass "flow-context-load.sh exits 0"
else
  fail "flow-context-load.sh exit non-zero"
  printf '%s\n' "$PREAMBLE_OUT" | sed 's/^/    | /'
fi

# Q12.5 contract: exactly 10 KEY=VALUE lines, fixed order. grep -c counts
# only schema-matching lines, so stderr leakage (warnings, etc.) wouldn't
# inflate the count under 2>&1 capture.
PREAMBLE_KV_COUNT="$(printf '%s\n' "$PREAMBLE_OUT" | grep -cE '^[A-Z_]+=' || true)"
if [ "$PREAMBLE_KV_COUNT" = "10" ]; then
  pass "preamble emits exactly 10 KEY=VALUE lines (Q12.5 contract)"
else
  fail "expected 10 KEY=VALUE preamble lines, got $PREAMBLE_KV_COUNT"
fi

# Per-field assertions.
expect_kv "$PREAMBLE_OUT" "MODE"                "greenfield"
expect_kv "$PREAMBLE_OUT" "LINEAR_PROJECT_ID"   "00000000-0000-0000-0000-000000000000"
expect_kv "$PREAMBLE_OUT" "LINEAR_PROJECT_NAME" "synthetic-greenfield-fixture"
expect_kv "$PREAMBLE_OUT" "REPO_ROOT"           "$FIXTURE"
expect_kv "$PREAMBLE_OUT" "INTENT_EXISTS"       "no"
expect_kv "$PREAMBLE_OUT" "INVENTORY_EXISTS"    "no"
expect_kv "$PREAMBLE_OUT" "FLOWS_DIR_EXISTS"    "no"
expect_kv "$PREAMBLE_OUT" "BREADCRUMB_EXISTS"   "no"
expect_kv "$PREAMBLE_OUT" "GH_AUTH"             "no"
expect_kv "$PREAMBLE_OUT" "LINEAR_MCP"          "unknown"

# Q12.5 preamble is exactly 10 fields — JOURNEYS_DIR_EXISTS comes from the
# shape probe (5 keys) but the preamble deliberately drops it. Catch a
# regression that re-introduces it.
if printf '%s\n' "$PREAMBLE_OUT" | grep -q '^JOURNEYS_DIR_EXISTS='; then
  fail "preamble leaked JOURNEYS_DIR_EXISTS (Q12.5 schema is 10 fields, journeys not included)"
else
  pass "preamble does NOT leak JOURNEYS_DIR_EXISTS (Q12.5 10-field schema)"
fi

# ── Section 5: flow-resume-breadcrumb.sh write/read round-trip ──────
section "5/6" "flow-resume-breadcrumb.sh write/read round-trip"

# Synthesize a Phase-1-complete breadcrumb on stdin to the write subcommand.
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BREADCRUMB_JSON="$(python3 - "$NOW" <<'PY'
import json, sys
print(json.dumps({
    "version": "1",
    "mode": "greenfield",
    "status": "in_flight",
    "run_started_at": sys.argv[1],
    "last_updated": sys.argv[1],
    "current_phase": "2",
    "completed_phases": ["1"],
    "domains": [],
}))
PY
)"

WRITE_OUT=""
if WRITE_OUT="$(printf '%s' "$BREADCRUMB_JSON" | \
                "$SCRIPTS_DIR/flow-resume-breadcrumb.sh" write "$BREADCRUMB" 2>&1)"; then
  pass "flow-resume-breadcrumb.sh write exits 0"
else
  fail "flow-resume-breadcrumb.sh write exit non-zero"
  printf '%s\n' "$WRITE_OUT" | sed 's/^/    | /'
fi

if printf '%s\n' "$WRITE_OUT" | grep -q '^WRITE=ok$'; then
  pass "write emits WRITE=ok"
else
  fail "write did not emit WRITE=ok"
fi

if [ -f "$BREADCRUMB" ]; then
  pass "breadcrumb file landed at canonical path: docs/plans/.flow-phase-state.json (leading dot)"
else
  fail "breadcrumb file missing after write"
fi

READ_OUT=""
if READ_OUT="$("$SCRIPTS_DIR/flow-resume-breadcrumb.sh" read "$BREADCRUMB" 2>&1)"; then
  pass "flow-resume-breadcrumb.sh read exits 0"
else
  fail "flow-resume-breadcrumb.sh read exit non-zero"
  printf '%s\n' "$READ_OUT" | sed 's/^/    | /'
fi

expect_kv "$READ_OUT" "EXISTS"       "yes"
expect_kv "$READ_OUT" "STATUS"       "in_flight"
expect_kv "$READ_OUT" "STALE"        "no"
expect_kv "$READ_OUT" "STALE_REASON" "none"

# After the breadcrumb write, the shape probe should flip BREADCRUMB_EXISTS to yes.
SHAPE_OUT_2=""
if SHAPE_OUT_2="$("$SCRIPTS_DIR/flow-detect-fda-shape.sh" "$FIXTURE" 2>&1)"; then
  if printf '%s\n' "$SHAPE_OUT_2" | grep -q '^BREADCRUMB_EXISTS=yes$'; then
    pass "shape probe re-detects breadcrumb after write (BREADCRUMB_EXISTS=yes)"
  else
    fail "shape probe still reports BREADCRUMB_EXISTS=no after write"
  fi
else
  fail "flow-detect-fda-shape.sh exit non-zero after breadcrumb write"
  printf '%s\n' "$SHAPE_OUT_2" | sed 's/^/    | /'
fi

# Mode classifier should now return `resume` (in_flight + not stale).
# Stdout-only capture matches Section 3's hardened pattern.
MODE_RESUME=""
if MODE_RESUME="$("$SCRIPTS_DIR/flow-detect-mode.sh" "$FIXTURE" 2>/dev/null)"; then
  if [ "$MODE_RESUME" = "resume" ]; then
    pass "mode classifier detects MODE=resume from in_flight breadcrumb"
  else
    fail "expected MODE=resume after in_flight breadcrumb, got: '$MODE_RESUME'"
  fi
else
  fail "flow-detect-mode.sh exit non-zero after breadcrumb write"
fi

# ── Section 5b: breadcrumb-read soft-fail paths ─────────────────────
# flow-resume-breadcrumb.sh `read` has 5 documented soft-fail outcomes per
# Q31.3, each surfacing a distinct STALE_REASON. Exercise each so a regression
# in the stale-detection logic surfaces before reaching production resume
# dispatch decisions.
section "5b/6" "flow-resume-breadcrumb.sh read soft-fail STALE_REASONs"

# Helper: write a synthetic JSON to scratch path (bypasses write subcommand
# which would parse-verify), then read + assert.
assert_read_outcome() {
  local label="$1" payload="$2" exp_status="$3" exp_stale="$4" exp_reason="$5"
  printf '%s' "$payload" > "$SCRATCH_BREADCRUMB"
  local out=""
  if ! out="$("$SCRIPTS_DIR/flow-resume-breadcrumb.sh" read "$SCRATCH_BREADCRUMB" 2>&1)"; then
    fail "[$label] read exit non-zero"
    printf '%s\n' "$out" | sed 's/^/    | /'
    return
  fi
  expect_kv "$out" "EXISTS"       "yes"
  expect_kv "$out" "STATUS"       "$exp_status"
  expect_kv "$out" "STALE"        "$exp_stale"
  expect_kv "$out" "STALE_REASON" "$exp_reason"
}

# (1) Malformed JSON → STALE=yes STALE_REASON=parse-error STATUS=unknown
assert_read_outcome "malformed-json" \
  "this is not json {{{" \
  "unknown" "yes" "parse-error"

# (2) status=completed → STALE=yes STALE_REASON=status-completed
COMPLETED_JSON="$(python3 - "$NOW" <<'PY'
import json, sys
print(json.dumps({"status": "completed", "last_updated": sys.argv[1]}))
PY
)"
assert_read_outcome "status-completed" "$COMPLETED_JSON" \
  "completed" "yes" "status-completed"

# (3) status=abandoned → STALE=yes STALE_REASON=status-abandoned
ABANDONED_JSON="$(python3 - "$NOW" <<'PY'
import json, sys
print(json.dumps({"status": "abandoned", "last_updated": sys.argv[1]}))
PY
)"
assert_read_outcome "status-abandoned" "$ABANDONED_JSON" \
  "abandoned" "yes" "status-abandoned"

# (4) Unparseable timestamp → STALE=yes STALE_REASON=timestamp-unparseable
BAD_TS_JSON="$(python3 <<'PY'
import json
print(json.dumps({"status": "in_flight", "last_updated": "not-a-timestamp-at-all"}))
PY
)"
assert_read_outcome "bad-timestamp" "$BAD_TS_JSON" \
  "in_flight" "yes" "timestamp-unparseable"

# (5) Timestamp 6 days ago (just inside 7-day stale window) → STALE=no
WITHIN_WINDOW_TS="$(python3 <<'PY'
import datetime
now = datetime.datetime.now(datetime.timezone.utc)
print((now - datetime.timedelta(days=6)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
WITHIN_WINDOW_JSON="$(python3 - "$WITHIN_WINDOW_TS" <<'PY'
import json, sys
print(json.dumps({"status": "in_flight", "last_updated": sys.argv[1]}))
PY
)"
assert_read_outcome "within-7d-window" "$WITHIN_WINDOW_JSON" \
  "in_flight" "no" "none"

# (6) Timestamp 8 days ago (outside stale window) → STALE=yes STALE_REASON=age
OUT_OF_WINDOW_TS="$(python3 <<'PY'
import datetime
now = datetime.datetime.now(datetime.timezone.utc)
print((now - datetime.timedelta(days=8)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
OUT_OF_WINDOW_JSON="$(python3 - "$OUT_OF_WINDOW_TS" <<'PY'
import json, sys
print(json.dumps({"status": "in_flight", "last_updated": sys.argv[1]}))
PY
)"
assert_read_outcome "outside-7d-window" "$OUT_OF_WINDOW_JSON" \
  "in_flight" "yes" "age"

cleanup_scratch_only

# ── Section 6: Phase 2-8 skip-with-reason ───────────────────────────
section "6/6" "Phase 2-8 deep assertions (pending BC-6959)"

skip "Phase 2 /flow:office-hours produces intent.md + L1 review" \
     "BC-6959 sub-skill not yet shipped — extend harness when it lands"
skip "Phase 3 flow-inventory-interview produces master-flow-inventory.md + L2 stash" \
     "BC-6959 sub-skill not yet shipped"
skip "Phase 4 flow-linear-scaffold produces Linear milestone + parent + 5N children (with L3)" \
     "BC-6959 sub-skill not yet shipped + Linear-MCP integration test category"
skip "Phase 5 flow-doc-author produces docs/product/flows/<domain>/<id>.md per sub-flow" \
     "BC-6959 sub-skill not yet shipped"
skip "Phase 6 flow-journey-author produces docs/product/journeys/<domain>.md + L2 summary" \
     "BC-6959 sub-skill not yet shipped"
skip "Phase 7 flow-regen-index regenerates docs/product/flows/INDEX.md" \
     "BC-6959 sub-skill not yet shipped"
skip "Phase 8 terminator writes status=completed breadcrumb" \
     "requires LLM-runner; covered by behavioral-tests.yml category"
skip "4 user-confirmation gates fire (G1-G4) per Q37" \
     "AskUserQuestion is LLM-only; not headlessly testable in this category"

# ── Summary ─────────────────────────────────────────────────────────
printf '\n──────────────────────────────────────────\n'
printf 'BC-7057 v-slice greenfield: %d pass / %d fail / %d skip (%d hard assertions)\n' \
       "$PASS" "$FAIL" "$SKIP" "$((PASS + FAIL))"
printf '──────────────────────────────────────────\n'

if [ "$FAIL" -gt 0 ]; then
  printf '\nHarness failed. Leaving breadcrumb at %s for inspection.\n' "$BREADCRUMB"
  printf 'Scratch breadcrumb cleaned up.\n'
  cleanup_scratch_only
  exit 1
fi

cleanup_on_success
printf '\nHarness passed. Breadcrumb cleaned up.\n'
exit 0
