#!/usr/bin/env bash
# Regression-lock for the WS-A Linear-graph lints (scripts/lib/flow_linear_lint.py):
#   A-4 detect_label_contamination       (contradictory type:* label vs [Discipline] prefix)
#   A-5 detect_blockedby_wiring           (doc ## Cross-domain dependencies ↔ Linear blockedBy)
#   A-6 detect_milestone_inheritance      (parent/child NO_MILESTONE + child≠parent mismatch)
#   A-7 detect_duplicate_discipline_child (≥2 children share a discipline under one parent)
#
# Two layers, like run-cross-domain-deps-vslice.sh: (1) DIRECT per-detector
# assertions against the committed synthetic-linear-graph fixtures — exact count
# + substring — so a single-detector regression surfaces precisely; (2) CLI
# verdict assertions on the bash runner (exit codes, A-5 skip-without-flows-dir,
# bad-invocation). Each fail-fixture isolates ONE lint.
#
# Target: bash 3.2 (macOS default). Stdlib python3 only.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIBDIR="$PLUGIN_DIR/scripts/lib"
RUNNER="$PLUGIN_DIR/scripts/flow-linear-lint.sh"
FIXTURE_ROOT="$SCRIPT_DIR/fixtures/synthetic-linear-graph"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIBDIR/flow_linear_lint.py" ] || { echo "fatal: lib missing" >&2; exit 1; }

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

mock() { printf '%s/%s/.flow/linear-state-mock.json' "$FIXTURE_ROOT" "$1"; }
flows() { printf '%s/%s/docs/product/flows' "$FIXTURE_ROOT" "$1"; }

# lint_call <state-json> <detector-fn> [flows-dir]
# Prints the violation count on line 1, then one violation per line.
lint_call() {
  python3 - "$LIBDIR" "$1" "$2" "${3:-}" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_linear_lint as m
state = m.load_state(sys.argv[2])
fn_name = sys.argv[3]
flows = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None
fn = getattr(m, fn_name)
res = fn(state, flows) if fn_name == "detect_blockedby_wiring" else fn(state)
print(len(res))
for v in res:
    print(v)
PY
}

# lint_call_inline <state-json-string> <detector-fn>
# Same contract as lint_call but takes an inline JSON state (for boundary cases
# that don't warrant a committed fixture). count on line 1, then violations.
lint_call_inline() {
  python3 - "$LIBDIR" "$2" "$1" <<'PY'
import sys, json
sys.path.insert(0, sys.argv[1])
import flow_linear_lint as m
state = json.loads(sys.argv[3])
res = getattr(m, sys.argv[2])(state)
print(len(res))
for v in res:
    print(v)
PY
}

count_of() { printf '%s\n' "$1" | head -1; }
body_of() { printf '%s\n' "$1" | tail -n +2; }

# assert_count <label> <out> <expected-count>
assert_count() {
  local label="$1" out="$2" want="$3" got
  got="$(count_of "$out")"
  if [ "$got" = "$want" ]; then pass "$label (n=$got)"; else
    fail "$label (expected n=$want, got n=$got; body: $(body_of "$out" | tr '\n' '|'))"; fi
}
# assert_body_has <label> <out> <substr>
assert_body_has() {
  local label="$1" out="$2" want="$3"
  case "$(body_of "$out")" in *"$want"*) pass "$label" ;;
    *) fail "$label (missing '$want' in: $(body_of "$out" | tr '\n' '|'))" ;; esac
}
# assert_exit <label> <expected-rc> <cmd...>
assert_exit() {
  local label="$1" want="$2"; shift 2
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "$want" ]; then pass "$label (exit $rc)"; else
    fail "$label (expected exit $want, got $rc)"; fi
}

# ── 1: fixture preflight ──────────────────────────────────────────────────────
section "1/6" "Fixture preflight"
for fx in pass fail-label-contamination fail-no-milestone fail-dup-child fail-blockedby-orphan; do
  if [ -f "$(mock "$fx")" ]; then pass "mock present: $fx"; else fail "mock missing: $fx"; fi
done
for fx in pass fail-blockedby-orphan; do
  if [ -d "$(flows "$fx")" ]; then pass "flows dir present: $fx"; else fail "flows dir missing: $fx"; fi
done

# ── 2: A-4 label↔title contamination (contradictory only) ─────────────────────
section "2/6" "A-4 detect_label_contamination"
a4_pass="$(lint_call "$(mock pass)" detect_label_contamination)"
assert_count "pass → no contamination" "$a4_pass" 0
a4_bad="$(lint_call "$(mock fail-label-contamination)" detect_label_contamination)"
assert_count "fail-label-contamination → 2 violations (replacement + extra)" "$a4_bad" 2
assert_body_has "  …names BC-102 ([Design] carrying type:eng alone)" "$a4_bad" "BC-102"
assert_body_has "  …names BC-202 ([Design] carrying BOTH type:design+type:eng — invisible to the .mts missing-label gate)" "$a4_bad" "BC-202"
assert_body_has "  …reports the wrong label type:eng" "$a4_bad" "type:eng"
assert_body_has "  …names the expected label type:design" "$a4_bad" "expected type:design"
# Anchoring boundary (fda-title.mts parity): a title that merely MENTIONS a
# discipline in prose (handoff / rework / body cross-reference) is NOT a canonical
# discipline child — A-4 must classify it as out-of-scope and emit 0, even though
# it carries a type:* label. Locks the _discipline_of anchoring fix against the
# unanchored-search false-positive class.
a4_noncanon="$(lint_call_inline '{"parents":{},"children":{"H1":{"parent":"BC-100","title":"[Backend Handoff] follow-up to [Design] mock","labels":["type:eng"]},"H2":{"parent":"BC-100","title":"Audit [Design] consistency across pages","labels":["type:eng"]}}}' detect_label_contamination)"
assert_count "non-canonical/prose [Design] brackets (type:eng) → 0 A-4 (fda-title.mts boundary)" "$a4_noncanon" 0

# ── 3: A-5 blockedBy-wiring (doc ↔ Linear) ────────────────────────────────────
section "3/6" "A-5 detect_blockedby_wiring"
a5_pass="$(lint_call "$(mock pass)" detect_blockedby_wiring "$(flows pass)")"
assert_count "pass (with flows) → mirror intact" "$a5_pass" 0
a5_bad="$(lint_call "$(mock fail-blockedby-orphan)" detect_blockedby_wiring "$(flows fail-blockedby-orphan)")"
assert_count "fail-blockedby-orphan → 2 violations (both halves)" "$a5_bad" 2
assert_body_has "  …doc-orphan names auth-flow-01 (prose-only)" "$a5_bad" "auth-flow-01"
assert_body_has "  …linear-orphan names content-model-01" "$a5_bad" "content-model-01"
a5_noflows="$(lint_call "$(mock fail-blockedby-orphan)" detect_blockedby_wiring)"
assert_count "no flows-dir → A-5 inert (cannot evaluate doc side)" "$a5_noflows" 0
# Inventory-drift boundary: a parent whose flow_id couldn't be resolved (None) is
# an A-8 inventory concern, not a wiring defect — the cross-domain pair builder
# must drop it rather than emit a meaningless ('None', …) pair. (Tests the
# internal helper directly: it takes the parents map.)
a5_nonefid="$(lint_call_inline '{"BC-1":{"domain":"a","flow_id":null,"blockedBy":["BC-2"]},"BC-2":{"domain":"b","flow_id":"content-model-01","blockedBy":[]}}' _linear_cross_domain_pairs)"
assert_count "parent with unresolved flow_id → excluded from A-5 pairs (no 'None' pair)" "$a5_nonefid" 0

# ── 4: A-6 child-milestone-inheritance ────────────────────────────────────────
section "4/6" "A-6 detect_milestone_inheritance"
a6_pass="$(lint_call "$(mock pass)" detect_milestone_inheritance)"
assert_count "pass → all milestones inherited" "$a6_pass" 0
a6_bad="$(lint_call "$(mock fail-no-milestone)" detect_milestone_inheritance)"
assert_count "fail-no-milestone → 3 violations" "$a6_bad" 3
assert_body_has "  …parent BC-200 has no milestone" "$a6_bad" "parent BC-200"
assert_body_has "  …child BC-104 NO_MILESTONE" "$a6_bad" "NO_MILESTONE"
assert_body_has "  …child BC-105 milestone mismatch" "$a6_bad" "BC-105"

# ── 5: A-7 duplicate-discipline-child ─────────────────────────────────────────
section "5/6" "A-7 detect_duplicate_discipline_child"
a7_pass="$(lint_call "$(mock pass)" detect_duplicate_discipline_child)"
assert_count "pass → one child per discipline" "$a7_pass" 0
a7_bad="$(lint_call "$(mock fail-dup-child)" detect_duplicate_discipline_child)"
assert_count "fail-dup-child → 1 violation" "$a7_bad" 1
assert_body_has "  …names both duplicate children BC-102" "$a7_bad" "BC-102"
assert_body_has "  …and BC-106" "$a7_bad" "BC-106"
assert_body_has "  …identifies the [Design] discipline" "$a7_bad" "[Design]"
# Anchoring boundary: two non-canonical children under one parent that merely
# mention [Design] in prose are NOT discipline children — A-7 must not bucket them
# into a phantom duplicate (shares _discipline_of with A-4).
a7_noncanon="$(lint_call_inline '{"parents":{"BC-100":{"flow_id":"x-01","domain":"x","title":"X-01: parent","milestone":"M","blockedBy":[],"labels":["type:parent"]}},"children":{"C1":{"parent":"BC-100","title":"Polish the [Design] system tokens","milestone":"M","labels":["type:eng"]},"C2":{"parent":"BC-100","title":"Refine [Design] handoff doc","milestone":"M","labels":["type:docs"]}}}' detect_duplicate_discipline_child)"
assert_count "two prose-[Design] siblings → 0 A-7 (no phantom duplicate)" "$a7_noncanon" 0

# ── 6: CLI runner verdicts (exit codes) ───────────────────────────────────────
section "6/6" "Runner exit codes"
assert_exit "pass (with flows) → exit 0" 0 bash "$RUNNER" "$(mock pass)" "$(flows pass)"
assert_exit "fail-label-contamination → exit 1" 1 bash "$RUNNER" "$(mock fail-label-contamination)"
assert_exit "fail-no-milestone → exit 1" 1 bash "$RUNNER" "$(mock fail-no-milestone)"
assert_exit "fail-dup-child → exit 1" 1 bash "$RUNNER" "$(mock fail-dup-child)"
assert_exit "fail-blockedby-orphan (with flows) → exit 1" 1 bash "$RUNNER" "$(mock fail-blockedby-orphan)" "$(flows fail-blockedby-orphan)"
assert_exit "missing state file → exit 2 (bad invocation)" 2 bash "$RUNNER" "$FIXTURE_ROOT/does-not-exist.json"

# ── Summary ───────────────────────────────────────────────────────────────────
printf '\n%s\n' '------------------------------------------'
printf 'WS-A Linear-graph-lint v-slice: %d pass / %d fail (%d hard assertions)\n' \
       "$PASS" "$FAIL" "$((PASS + FAIL))"
printf '%s\n' '------------------------------------------'
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
