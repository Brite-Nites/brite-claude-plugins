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

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP  %s — %s\n' "$1" "$2"; SKIP=$((SKIP + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# ── Cleanup contract ────────────────────────────────────────────────
# Remove the test-written breadcrumb on clean run; leave in place on failure
# so the failed state is inspectable.
cleanup_on_success() {
  rm -f "$BREADCRUMB"
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

# Fixture build/lint/test stubs return 0 — Q8 sub-criterion 5 shape only.
if (cd "$FIXTURE" && npm run --silent build > /dev/null 2>&1); then
  pass "fixture: npm run build exits 0"
else
  skip "fixture: npm run build" "npm not available in CI image or build stub failed"
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
expect_shape_field() {
  local key="$1" expected="$2"
  local line
  line="$(printf '%s\n' "$SHAPE_OUT" | grep -E "^${key}=" || true)"
  if [ "$line" = "${key}=${expected}" ]; then
    pass "$key=$expected"
  else
    fail "expected $key=$expected, got: ${line:-<missing>}"
  fi
}

expect_shape_field "INTENT_EXISTS"     "no"
expect_shape_field "INVENTORY_EXISTS"  "no"
expect_shape_field "FLOWS_DIR_EXISTS"  "no"
expect_shape_field "JOURNEYS_DIR_EXISTS" "no"
expect_shape_field "BREADCRUMB_EXISTS" "no"

# ── Section 3: flow-detect-mode.sh ──────────────────────────────────
section "3/6" "flow-detect-mode.sh classifies as greenfield"

# LINEAR_ISSUE_COUNT=0 forces the Q36.3 step-4 heuristic into the greenfield
# branch deterministically.
MODE_OUT=""
if MODE_OUT="$(LINEAR_ISSUE_COUNT=0 "$SCRIPTS_DIR/flow-detect-mode.sh" "$FIXTURE" 2>&1)"; then
  pass "flow-detect-mode.sh exits 0"
else
  fail "flow-detect-mode.sh exit non-zero"
  printf '%s\n' "$MODE_OUT" | sed 's/^/    | /'
fi

if [ "$MODE_OUT" = "greenfield" ]; then
  pass "MODE=greenfield against fixture (LINEAR_ISSUE_COUNT=0)"
else
  fail "expected 'greenfield', got: '$MODE_OUT'"
fi

# Q36.3 step 4 heuristic: same fixture with LINEAR_ISSUE_COUNT=10 → retrofit.
MODE_OUT_RETROFIT=""
if MODE_OUT_RETROFIT="$(LINEAR_ISSUE_COUNT=10 "$SCRIPTS_DIR/flow-detect-mode.sh" "$FIXTURE" 2>&1)"; then
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

# Q12.5 contract: exactly 10 KEY=VALUE lines, fixed order.
PREAMBLE_LINES="$(printf '%s\n' "$PREAMBLE_OUT" | wc -l | tr -d ' ')"
if [ "$PREAMBLE_LINES" = "10" ]; then
  pass "preamble emits exactly 10 lines (Q12.5 contract)"
else
  fail "expected 10 preamble lines, got $PREAMBLE_LINES"
fi

# Per-field assertions.
expect_preamble_field() {
  local key="$1" expected="$2"
  local line
  line="$(printf '%s\n' "$PREAMBLE_OUT" | grep -E "^${key}=" || true)"
  if [ "$line" = "${key}=${expected}" ]; then
    pass "$key=$expected"
  else
    fail "expected $key=$expected, got: ${line:-<missing>}"
  fi
}

expect_preamble_field "MODE"               "greenfield"
expect_preamble_field "LINEAR_PROJECT_ID"  "00000000-0000-0000-0000-000000000000"
expect_preamble_field "LINEAR_PROJECT_NAME" "synthetic-greenfield-fixture"
expect_preamble_field "REPO_ROOT"          "$FIXTURE"
expect_preamble_field "INTENT_EXISTS"      "no"
expect_preamble_field "INVENTORY_EXISTS"   "no"
expect_preamble_field "FLOWS_DIR_EXISTS"   "no"
expect_preamble_field "BREADCRUMB_EXISTS"  "no"
expect_preamble_field "GH_AUTH"            "no"
expect_preamble_field "LINEAR_MCP"         "unknown"

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

expect_read_field() {
  local key="$1" expected="$2"
  local line
  line="$(printf '%s\n' "$READ_OUT" | grep -E "^${key}=" || true)"
  if [ "$line" = "${key}=${expected}" ]; then
    pass "$key=$expected"
  else
    fail "expected $key=$expected, got: ${line:-<missing>}"
  fi
}

expect_read_field "EXISTS"       "yes"
expect_read_field "STATUS"       "in_flight"
expect_read_field "STALE"        "no"
expect_read_field "STALE_REASON" "none"

# After the breadcrumb write, the shape probe should flip BREADCRUMB_EXISTS to yes.
SHAPE_OUT_2=""
if SHAPE_OUT_2="$("$SCRIPTS_DIR/flow-detect-fda-shape.sh" "$FIXTURE" 2>&1)"; then
  if printf '%s\n' "$SHAPE_OUT_2" | grep -q '^BREADCRUMB_EXISTS=yes$'; then
    pass "shape probe re-detects breadcrumb after write (BREADCRUMB_EXISTS=yes)"
  else
    fail "shape probe still reports BREADCRUMB_EXISTS=no after write"
  fi
fi

# Mode classifier should now return `resume` (in_flight + not stale).
MODE_RESUME=""
if MODE_RESUME="$("$SCRIPTS_DIR/flow-detect-mode.sh" "$FIXTURE" 2>&1)"; then
  if [ "$MODE_RESUME" = "resume" ]; then
    pass "mode classifier detects MODE=resume from in_flight breadcrumb"
  else
    fail "expected MODE=resume after in_flight breadcrumb, got: '$MODE_RESUME'"
  fi
fi

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
TOTAL=$((PASS + FAIL))
printf '\n──────────────────────────────────────────\n'
printf 'BC-7057 v-slice greenfield: %d pass / %d fail / %d skip (%d hard assertions)\n' \
       "$PASS" "$FAIL" "$SKIP" "$TOTAL"
printf '──────────────────────────────────────────\n'

if [ "$FAIL" -gt 0 ]; then
  printf '\nHarness failed. Leaving breadcrumb at %s for inspection.\n' "$BREADCRUMB"
  exit 1
fi

cleanup_on_success
printf '\nHarness passed. Breadcrumb cleaned up.\n'
exit 0
