#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/icp_refinement_review.py
# (BC-8726). Builds an isolated campaigns directory per scenario via mktemp,
# drives scan / apply / emit-handbook subcommands non-interactively, asserts
# both exit code AND a scenario-specific substring (per BC-8712 follow-up
# substring-assertion discipline; pattern mirrors test_lint_discoveries.sh).
#
# Fixtures:
#   F1  single-pending-signal              scan → 1, apply promoted, emit markdown
#   F2  multiple-pending-across-verticals  scan → 2 groups, apply mixed decisions
#   F3  mix-of-statuses                    scan filters terminal, apply skips terminal
#   F4  wrong-category                     scan returns 0 (icp-refinement only)
#   F5  empty-signals                      scan returns 0 (vacuous-OK)
#
# Plus 3 negative-path fixtures the prompt did not enumerate but discipline
# requires (defensive of the apply HARD-FAIL invariants):
#   N1  bad-decision-string                apply exits 2 on enum miss
#   N2  out-of-range index                 apply exits 1
#   N3  missing decision-map file          apply exits 2
#
# Usage:
#   bash plugins/marketing/scripts/test_icp_refinement_review.sh
#   bash plugins/marketing/scripts/test_icp_refinement_review.sh /custom/path/script.py

set -u  # NOT set -e — non-zero exits are expected for reject scenarios

# Defuse caller's git env (matches test_lint_discoveries.sh + test_lint_canonicals.sh
# discipline; protects against the BC-8712-followup pre-push git-env-leak gotcha).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${1:-$script_dir/icp_refinement_review.py}"

if [ ! -f "$SCRIPT" ]; then
  echo "FATAL: helper script not found: $SCRIPT" >&2
  exit 2
fi
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"

tmproot="$(mktemp -d -t test-icp-refinement.XXXXXX)" || {
  echo "FATAL: mktemp -d failed" >&2
  exit 2
}
trap 'rm -rf "$tmproot"' EXIT

pass=0
fail=0
LAST_OUTPUT=""
LAST_RC=0

assert_exit_and_substring() {
  local label="$1"
  local expected_rc="$2"
  local substring="$3"
  local actual_rc="$LAST_RC"
  local output="$LAST_OUTPUT"

  if [ "$expected_rc" -ne "$actual_rc" ]; then
    echo "  FAIL  $label — exit expected=$expected_rc actual=$actual_rc"
    echo "    output: $output"
    fail=$((fail + 1))
    return
  fi
  if ! printf '%s' "$output" | grep -qE -- "$substring"; then
    echo "  FAIL  $label — substring not found"
    echo "    expected regex: $substring"
    echo "    output: $output"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (exit=$actual_rc, substring matched)"
  pass=$((pass + 1))
}

invoke() {
  # $@: argv to icp_refinement_review.py
  LAST_OUTPUT="$(python3 "$SCRIPT" "$@" 2>&1)"
  LAST_RC=$?
}

# ── Fixture builders ──────────────────────────────────────────────────────

mk_campaigns_dir() {
  # $1: scenario name → unique subdir
  local name="$1"
  local d="$tmproot/$name/campaigns"
  mkdir -p "$d"
  printf '%s' "$d"
}

mk_signal_pending_icp() {
  # $1: vertical, $2: persona — emits one icp-refinement signal JSON
  local vertical="$1"
  local persona="$2"
  cat <<EOF
{
  "category": "icp-refinement",
  "emitted_at": "2026-05-26T10:00:00Z",
  "emitted_by_skill": "campaign-debrief",
  "payload": {
    "vertical": "$vertical",
    "persona": "$persona",
    "current_icp_summary": "Director of $persona at 200+ room properties",
    "observed_pattern": "Responders skewed to family-resort sub-segment specifically",
    "evidence_metric": "Reply Rate 4.1% on N=120 family-resort vs 0.6% on N=380 non-family",
    "refinement_proposal": "Split persona into ${persona}-family vs ${persona}-luxury"
  }
}
EOF
}

mk_signal_terminal() {
  # $1: vertical, $2: persona, $3: terminal status (promoted|rejected)
  local vertical="$1"
  local persona="$2"
  local status="$3"
  cat <<EOF
{
  "category": "icp-refinement",
  "emitted_at": "2026-05-25T10:00:00Z",
  "emitted_by_skill": "campaign-debrief",
  "payload": {
    "vertical": "$vertical",
    "persona": "$persona",
    "current_icp_summary": "Old summary",
    "observed_pattern": "Old pattern",
    "evidence_metric": "Old evidence",
    "refinement_proposal": "Already decided"
  },
  "promotion_status": "$status"
}
EOF
}

mk_signal_wrong_category() {
  cat <<'EOF'
{
  "category": "title-discovery",
  "emitted_at": "2026-05-26T10:00:00Z",
  "emitted_by_skill": "list-building",
  "payload": {
    "vertical": "hotels-resorts",
    "title": "Director of Resort Activations",
    "occurrences": 3
  }
}
EOF
}

# Wraps signals into a discoveries.json file at <campaigns>/<entity>/<slug>/discoveries.json
write_discoveries() {
  local cdir="$1"
  local entity="$2"
  local slug="$3"
  shift 3
  local target="$cdir/$entity/$slug"
  mkdir -p "$target"
  local signals_json
  signals_json="$(printf '%s,' "$@")"
  # Strip ONLY the final trailing comma — `sed 's/,$//'` would strip the
  # comma at end-of-line on every signal field (multi-line JSON), corrupting
  # the fixture. Parameter substitution `${var%,}` is a single-string op.
  signals_json="${signals_json%,}"
  cat > "$target/discoveries.json" <<EOF
{
  "schema_version": 1,
  "signals": [
$signals_json
  ]
}
EOF
}

# ── F1 single-pending-signal ──────────────────────────────────────────────

f1_dir="$(mk_campaigns_dir f1)"
write_discoveries "$f1_dir" "labs" "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02" \
  "$(mk_signal_pending_icp hotels-resorts director-of-resort-experience)"

invoke --campaigns-dir "$f1_dir" scan
assert_exit_and_substring "F1.scan finds 1 pending" 0 '"total_pending": 1'
assert_exit_and_substring "F1.scan groups by hotels-resorts" 0 '"hotels-resorts"'

# Capture the signal_id for the apply step
F1_SIGNAL_ID="$(printf '%s' "$LAST_OUTPUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(list(d["groups"].values())[0][0]["signal_id"])')"
F1_DECISION_MAP="$tmproot/f1-decisions.json"
printf '{"%s": "promoted"}' "$F1_SIGNAL_ID" > "$F1_DECISION_MAP"

invoke --campaigns-dir "$f1_dir" apply --decision-map "$F1_DECISION_MAP"
assert_exit_and_substring "F1.apply flips promoted" 0 '"promoted": 1'

# Verify file actually mutated
F1_FILE="$f1_dir/labs/hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02/discoveries.json"
F1_STATUS_AFTER="$(python3 -c "import json;print(json.load(open('$F1_FILE'))['signals'][0].get('promotion_status'))")"
LAST_OUTPUT="$F1_STATUS_AFTER"
LAST_RC=0
assert_exit_and_substring "F1.apply file mutation persisted" 0 '^promoted$'

invoke --campaigns-dir "$f1_dir" emit-handbook --decision-map "$F1_DECISION_MAP"
assert_exit_and_substring "F1.emit-handbook prints blob" 0 'ICP refinement — hotels-resorts'
assert_exit_and_substring "F1.emit-handbook cites canonicals" 0 'canonicals/hotels-resorts.yaml'
assert_exit_and_substring "F1.emit-handbook cites prose target" 0 'verticals/hotels-resorts/README.md'

# Re-scan after apply: pending list should now be empty (signal terminalized)
invoke --campaigns-dir "$f1_dir" scan
assert_exit_and_substring "F1.rescan finds 0 pending after apply" 0 '"total_pending": 0'

# ── F2 multiple-pending-across-verticals ──────────────────────────────────

f2_dir="$(mk_campaigns_dir f2)"
write_discoveries "$f2_dir" "labs" "hotels-resorts-x-fy26-m03" \
  "$(mk_signal_pending_icp hotels-resorts director-of-resort-experience)"
write_discoveries "$f2_dir" "supply" "installers-x-fy26-m03" \
  "$(mk_signal_pending_icp installers field-operations-manager)"

invoke --campaigns-dir "$f2_dir" scan
assert_exit_and_substring "F2.scan finds 2 pending" 0 '"total_pending": 2'
assert_exit_and_substring "F2.scan has hotels-resorts group" 0 '"hotels-resorts"'
assert_exit_and_substring "F2.scan has installers group" 0 '"installers"'

# Decision: promote hotels, reject installers — mixed decisions in one apply
F2_HOTELS_ID="$(printf '%s' "$LAST_OUTPUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["groups"]["hotels-resorts"][0]["signal_id"])')"
F2_INSTALLERS_ID="$(printf '%s' "$LAST_OUTPUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["groups"]["installers"][0]["signal_id"])')"
F2_DECISION_MAP="$tmproot/f2-decisions.json"
printf '{"%s":"promoted","%s":"rejected"}' "$F2_HOTELS_ID" "$F2_INSTALLERS_ID" > "$F2_DECISION_MAP"

invoke --campaigns-dir "$f2_dir" apply --decision-map "$F2_DECISION_MAP"
assert_exit_and_substring "F2.apply counts promoted+rejected" 0 '"promoted": 1.*"rejected": 1'

invoke --campaigns-dir "$f2_dir" emit-handbook --decision-map "$F2_DECISION_MAP"
assert_exit_and_substring "F2.emit-handbook only includes promoted" 0 'hotels-resorts'
# Inverse: rejected (installers) signal must NOT appear in emit output
if printf '%s' "$LAST_OUTPUT" | grep -qE 'installers'; then
  echo "  FAIL  F2.emit-handbook leaked rejected signal — output mentions installers"
  fail=$((fail + 1))
else
  echo "  PASS  F2.emit-handbook excludes rejected signal (no installers mention)"
  pass=$((pass + 1))
fi

# ── F3 mix-of-statuses ────────────────────────────────────────────────────

f3_dir="$(mk_campaigns_dir f3)"
write_discoveries "$f3_dir" "labs" "muni-x-fy26-m04" \
  "$(mk_signal_terminal hotels-resorts director-of-resort-experience promoted)" \
  "$(mk_signal_pending_icp hotels-resorts director-of-resort-experience)" \
  "$(mk_signal_terminal hotels-resorts director-of-resort-experience rejected)"

invoke --campaigns-dir "$f3_dir" scan
assert_exit_and_substring "F3.scan filters terminal, finds 1" 0 '"total_pending": 1'

# Construct a decision map that targets the TERMINAL signal at index 0 (defer scenario)
F3_FILE="labs/muni-x-fy26-m04/discoveries.json"
F3_DECISION_MAP="$tmproot/f3-decisions.json"
printf '{"%s::0":"promoted","%s::1":"promoted","%s::2":"promoted"}' "$F3_FILE" "$F3_FILE" "$F3_FILE" > "$F3_DECISION_MAP"

invoke --campaigns-dir "$f3_dir" apply --decision-map "$F3_DECISION_MAP"
# Expect: index 0 terminal-promoted (skipped), index 1 pending → promoted, index 2 terminal-rejected (skipped)
assert_exit_and_substring "F3.apply skips terminal signals" 0 '"skipped": 2'
assert_exit_and_substring "F3.apply promotes the 1 pending" 0 '"promoted": 1'

# ── F4 wrong-category ─────────────────────────────────────────────────────

f4_dir="$(mk_campaigns_dir f4)"
write_discoveries "$f4_dir" "labs" "muni-x-fy26-m05" \
  "$(mk_signal_wrong_category)"

invoke --campaigns-dir "$f4_dir" scan
assert_exit_and_substring "F4.scan filters non-icp-refinement to 0" 0 '"total_pending": 0'

# ── F5 empty-signals ──────────────────────────────────────────────────────

f5_dir="$(mk_campaigns_dir f5)"
mkdir -p "$f5_dir/labs/empty-x-fy26-m06"
cat > "$f5_dir/labs/empty-x-fy26-m06/discoveries.json" <<'EOF'
{
  "schema_version": 1,
  "signals": []
}
EOF

invoke --campaigns-dir "$f5_dir" scan
assert_exit_and_substring "F5.scan empty-signals returns 0" 0 '"total_pending": 0'

# ── N1 bad-decision-string ───────────────────────────────────────────────

n1_dir="$(mk_campaigns_dir n1)"
write_discoveries "$n1_dir" "labs" "muni-x-fy26-m07" \
  "$(mk_signal_pending_icp hotels-resorts director-of-resort-experience)"
N1_DECISION_MAP="$tmproot/n1-decisions.json"
printf '{"labs/muni-x-fy26-m07/discoveries.json::0":"NOT_A_DECISION"}' > "$N1_DECISION_MAP"
invoke --campaigns-dir "$n1_dir" apply --decision-map "$N1_DECISION_MAP"
assert_exit_and_substring "N1.apply rejects bad decision string" 2 'decision must be one of'

# ── N2 out-of-range index ────────────────────────────────────────────────

n2_dir="$(mk_campaigns_dir n2)"
write_discoveries "$n2_dir" "labs" "muni-x-fy26-m08" \
  "$(mk_signal_pending_icp hotels-resorts director-of-resort-experience)"
N2_DECISION_MAP="$tmproot/n2-decisions.json"
printf '{"labs/muni-x-fy26-m08/discoveries.json::99":"promoted"}' > "$N2_DECISION_MAP"
invoke --campaigns-dir "$n2_dir" apply --decision-map "$N2_DECISION_MAP"
assert_exit_and_substring "N2.apply rejects out-of-range index" 1 'signal index out of range'

# ── N3 missing decision-map file ─────────────────────────────────────────

n3_dir="$(mk_campaigns_dir n3)"
mkdir -p "$n3_dir/labs/dummy"
echo '{"schema_version":1,"signals":[]}' > "$n3_dir/labs/dummy/discoveries.json"
invoke --campaigns-dir "$n3_dir" apply --decision-map "$tmproot/does-not-exist.json"
assert_exit_and_substring "N3.apply rejects missing decision-map" 2 '--decision-map file not found'

# ── Report ───────────────────────────────────────────────────────────────

total=$((pass + fail))
echo ""
echo "icp_refinement_review.py harness: $pass/$total passing"
# RESULT line: machine-readable for scripts/validate.sh wiring (mirrors
# scripts/test_lint_discoveries.sh + test_lint_canonicals.sh discipline).
echo "RESULT pass=$pass fail=$fail"
if [ "$fail" -ne 0 ]; then
  echo "FAIL — $fail scenario(s) failed" >&2
  exit 1
fi
echo "PASS — all scenarios green"
exit 0
