#!/usr/bin/env bash
set -euo pipefail

# ── Behavioral Test Runner (Tier 2) ─────────────────────────────────
# Validates skill runtime behavior via claude -p subprocess invocations.
# Reads test cases from tests/fixtures/behavioral-registry.json.
#
# Usage:
#   EVALS=1 bash scripts/test-behavioral.sh              # run all tests
#   EVALS=1 bash scripts/test-behavioral.sh --dry-run     # parse fixtures, no invocations
#   EVALS=1 bash scripts/test-behavioral.sh --list        # list test case IDs
#   EVALS=1 bash scripts/test-behavioral.sh --filter B01  # run single test
#
# Environment:
#   EVALS=1              Required. Safety guard against accidental runs.
#   EVALS_PLUGIN_DIR     Plugin directory to test (default: plugins/workflows)
#   EVALS_MODEL          Model to use (default: claude-sonnet-4-6)
#   EVALS_TRIALS         Trials per test for non-determinism (default: 1)
#   EVALS_TIMEOUT        Timeout per invocation in seconds (default: 120)
#   EVALS_RESULTS_DIR    Directory for results JSON (default: tests/evals)
# ─────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="${EVALS_PLUGIN_DIR:-$REPO_ROOT/plugins/workflows}"
# Derive default fixture from plugin name: behavioral-registry-<plugin>.json (falls back to behavioral-registry.json)
_plugin_name="$(basename "$PLUGIN_DIR")"
_default_fixture="$REPO_ROOT/tests/fixtures/behavioral-registry-${_plugin_name}.json"
if [ ! -f "$_default_fixture" ]; then
  _default_fixture="$REPO_ROOT/tests/fixtures/behavioral-registry.json"
fi
FIXTURE="${EVALS_FIXTURE:-$_default_fixture}"
MODEL="${EVALS_MODEL:-claude-sonnet-4-6}"
TRIALS="${EVALS_TRIALS:-1}"
TIMEOUT="${EVALS_TIMEOUT:-120}"
RESULTS_DIR="${EVALS_RESULTS_DIR:-$REPO_ROOT/tests/evals}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESULTS_FILE="$RESULTS_DIR/behavioral-${TIMESTAMP}.json"

# ── Counters & helpers ───────────────────────────────────────────────
# Test-level counters (used in summary)
test_pass=0
test_fail=0
skip_count=0
total_cost="0"

# Assertion-level detail (printed inline but not counted in summary)
detail_pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
detail_fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; }

# Test-level verdict (counted in summary)
pass()    { printf "  \033[32mPASS\033[0m  %s\n" "$1"; test_pass=$((test_pass + 1)); }
fail()    { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; test_fail=$((test_fail + 1)); }
skip()    { printf "  \033[33mSKIP\033[0m  %s\n" "$1"; skip_count=$((skip_count + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

usage() {
  printf "Usage: EVALS=1 bash %s [--dry-run|--list|--filter <id>]\n\n" "$0"
  printf "Flags:\n"
  printf "  --dry-run   Parse fixtures and print test plan without invoking Claude\n"
  printf "  --list      Print test case IDs and descriptions\n"
  printf "  --filter ID Run only the specified test case (e.g., --filter B01)\n"
  printf "  --help      Show this help message\n\n"
  printf "Environment:\n"
  printf "  EVALS=1           Required safety guard\n"
  printf "  EVALS_PLUGIN_DIR  Plugin directory (default: plugins/workflows)\n"
  printf "  EVALS_MODEL       Model override (default: claude-sonnet-4-6)\n"
  printf "  EVALS_TRIALS      Trials per test (default: 1)\n"
  printf "  EVALS_TIMEOUT     Timeout per invocation in seconds (default: 120)\n"
  exit 0
}

# ── Parse flags ──────────────────────────────────────────────────────
DRY_RUN=false
LIST_ONLY=false
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --list)    LIST_ONLY=true; shift ;;
    --filter)
      if [[ $# -lt 2 ]]; then
        printf "ERROR: --filter requires an argument (e.g., --filter B01)\n"
        exit 2
      fi
      FILTER="$2"; shift 2 ;;
    --help)    usage ;;
    *) printf "Unknown flag: %s\n" "$1"; usage ;;
  esac
done

# ── Guards ───────────────────────────────────────────────────────────
if [[ "${EVALS:-}" != "1" ]]; then
  printf "ERROR: Set EVALS=1 to run behavioral tests (they cost money).\n"
  printf "  Dry run:  EVALS=1 bash %s --dry-run\n" "$0"
  printf "  List:     EVALS=1 bash %s --list\n" "$0"
  exit 2
fi

if [[ "$DRY_RUN" == false ]] && [[ "$LIST_ONLY" == false ]]; then
  if [[ -n "${CLAUDE_SESSION_ID:-}" ]] || [[ -n "${CLAUDECODE:-}" ]]; then
    printf "ERROR: Live tests must run OUTSIDE a Claude session.\n"
    printf "Run from a regular terminal or CI. (--dry-run and --list work inside sessions.)\n"
    exit 2
  fi
fi

# ── Portability: timeout command (GNU coreutils) ─────────────────────
if ! command -v timeout &>/dev/null; then
  if command -v gtimeout &>/dev/null; then
    timeout() { gtimeout "$@"; }
  else
    printf "WARN: 'timeout' (coreutils) not found. Install: brew install coreutils\n"
    printf "WARN: Tests will run without timeout protection.\n"
    timeout() { shift; "$@"; }  # no-op: skip the timeout arg, run the command
  fi
fi

if ! command -v jq &>/dev/null; then
  printf "ERROR: 'jq' is required but not found. Install it: brew install jq\n"
  exit 2
fi

if [[ ! -f "$FIXTURE" ]]; then
  printf "ERROR: Fixture file not found: %s\n" "$FIXTURE"
  exit 2
fi

if [[ "$DRY_RUN" == false ]] && [[ "$LIST_ONLY" == false ]]; then
  if ! command -v claude &>/dev/null; then
    printf "ERROR: 'claude' CLI not found.\n"
    printf "Install it first: https://docs.anthropic.com/en/docs/claude-code\n"
    exit 2
  fi
fi

# ── Load fixture ─────────────────────────────────────────────────────
test_count=$(jq '.test_cases | length' "$FIXTURE")

echo "Brite Plugin — Behavioral Test Runner (Tier 2)"
echo "Fixture:  $FIXTURE"
echo "Plugin:   $PLUGIN_DIR"
echo "Model:    $MODEL"
echo "Trials:   $TRIALS"
echo "Timeout:  ${TIMEOUT}s"
echo "Tests:    $test_count"
echo ""

# ── --list mode ──────────────────────────────────────────────────────
if [[ "$LIST_ONLY" == true ]]; then
  printf "%-4s  %-60s  %s\n" "ID" "Description" "Skill"
  printf "%-4s  %-60s  %s\n" "----" "------------------------------------------------------------" "----------"
  jq -r '.test_cases[] | [.id, .description, (.expected_skill // "(none)")] | @tsv' "$FIXTURE" |
  while IFS=$'\t' read -r id desc skill; do
    printf "%-4s  %-60s  %s\n" "$id" "$desc" "$skill"
  done
  exit 0
fi

# ── Initialize results JSON ──────────────────────────────────────────
mkdir -p "$RESULTS_DIR"
cat > "$RESULTS_FILE" <<JSONEOF
{
  "version": "1.0.0",
  "timestamp": "$TIMESTAMP",
  "model": "$MODEL",
  "trials": $TRIALS,
  "timeout": $TIMEOUT,
  "fixture": "$(basename "$FIXTURE")",
  "results": []
}
JSONEOF

# ── Helper: collect results for batch write ──────────────────────────
all_results=()
collect_result() {
  all_results+=("$1")
}

# Write all collected results to the results JSON file at once
write_results() {
  local tmp results_json
  if [[ ${#all_results[@]} -eq 0 ]]; then
    # No results to write
    return
  fi
  tmp=$(mktemp)
  results_json=$(printf '%s\n' "${all_results[@]}" | jq -s '.') || { rm -f "$tmp"; echo "write_results: failed to serialize results JSON" >&2; return 1; }
  if jq --argjson results "$results_json" '.results = $results' "$RESULTS_FILE" > "$tmp"; then
    mv "$tmp" "$RESULTS_FILE"
  else
    rm -f "$tmp"
    echo "write_results: jq failed, results not written" >&2
    return 1
  fi
}

# ── Helper: check markers in output ──────────────────────────────────
check_markers() {
  local output="$1"
  local markers_json="$2"
  local should_match="$3"  # "true" = markers should be found, "false" = should NOT be found
  local marker_count
  local all_ok=true

  marker_count=$(echo "$markers_json" | jq '. | length')
  if [[ "$marker_count" -eq 0 ]]; then
    return 0
  fi

  for j in $(seq 0 $((marker_count - 1))); do
    marker=$(echo "$markers_json" | jq -r ".[$j]")
    if echo "$output" | grep -Fqi "$marker"; then
      if [[ "$should_match" == "false" ]]; then
        detail_fail "Unexpected marker found: '$marker'"
        all_ok=false
      fi
    else
      if [[ "$should_match" == "true" ]]; then
        detail_fail "Expected marker not found: '$marker'"
        all_ok=false
      fi
    fi
  done

  if [[ "$all_ok" == true ]]; then
    return 0
  else
    return 1
  fi
}

# ── Helper: check skill activation ───────────────────────────────────
check_skill_activation() {
  local output="$1"
  local expected_skill="$2"  # skill name or "null"
  local not_expected_json="$3"
  local ok=true

  # Check expected skill activated
  if [[ "$expected_skill" != "null" ]]; then
    # Look for activation banner pattern: **SkillName** activated
    if echo "$output" | grep -Fqi "activated"; then
      if echo "$output" | grep -Fqi "$expected_skill"; then
        detail_pass "Skill '$expected_skill' activated"
      else
        detail_fail "Expected skill '$expected_skill' to activate, but different skill activated"
        ok=false
      fi
    else
      detail_fail "Expected skill '$expected_skill' to activate, but no activation banner found"
      ok=false
    fi
  else
    # No skill should activate
    if echo "$output" | grep -qi "\*\*.*\*\* activated"; then
      detail_fail "No skill expected but an activation banner was found"
      ok=false
    else
      detail_pass "No skill activated (as expected)"
    fi
  fi

  # Check not_expected_skills
  local ne_count
  ne_count=$(echo "$not_expected_json" | jq 'length')
  for j in $(seq 0 $((ne_count - 1))); do
    ne_skill=$(echo "$not_expected_json" | jq -r ".[$j]")
    if echo "$output" | grep -Fqi "$ne_skill"; then
      if echo "$output" | grep -Fqi "activated"; then
        detail_fail "Skill '$ne_skill' should NOT have activated"
        ok=false
      fi
    fi
  done

  [[ "$ok" == true ]]
}

# ── Run tests ────────────────────────────────────────────────────────
start_time=$(date +%s)

for i in $(seq 0 $((test_count - 1))); do
  id=$(jq -r ".test_cases[$i].id" "$FIXTURE")
  desc=$(jq -r ".test_cases[$i].description" "$FIXTURE")
  prompt=$(jq -r ".test_cases[$i].prompt" "$FIXTURE")
  expected_skill=$(jq -r ".test_cases[$i].expected_skill // \"null\"" "$FIXTURE")
  expected_markers=$(jq -c ".test_cases[$i].expected_markers" "$FIXTURE")
  not_expected_markers=$(jq -c ".test_cases[$i].not_expected_markers" "$FIXTURE")
  not_expected_skills=$(jq -c ".test_cases[$i].not_expected_skills" "$FIXTURE")
  est_cost=$(jq -r ".test_cases[$i].estimated_cost" "$FIXTURE")
  has_rubric=$(jq ".test_cases[$i].judge_rubric != null" "$FIXTURE")
  judge_rubric=$(jq -c ".test_cases[$i].judge_rubric" "$FIXTURE")
  rubric_file=$(jq -r ".test_cases[$i].rubric_file // \"\"" "$FIXTURE")

  # Apply filter
  if [[ -n "$FILTER" ]] && [[ "$id" != "$FILTER" ]]; then
    continue
  fi

  section "$id: $desc"

  # ── Dry-run mode ─────────────────────────────────────────────────
  if [[ "$DRY_RUN" == true ]]; then
    printf "  Prompt:    %.80s...\n" "$prompt"
    printf "  Skill:     %s\n" "$expected_skill"
    printf "  Markers+:  %s\n" "$expected_markers"
    printf "  Markers-:  %s\n" "$not_expected_markers"
    printf "  Cost:      %s\n" "$est_cost"
    printf "  Judge:     %s\n" "$has_rubric"
    skip "Dry run — skipped invocation"
    collect_result "{\"id\":\"$id\",\"status\":\"skipped\",\"reason\":\"dry-run\"}"
    continue
  fi

  # ── Live execution with trials ───────────────────────────────────
  trial_passes=0
  trial_outputs=()

  for trial in $(seq 1 "$TRIALS"); do
    if [[ "$TRIALS" -gt 1 ]]; then
      printf "  Trial %d/%d...\n" "$trial" "$TRIALS"
    fi

    output=""
    exit_code=0
    invocation_start=$(date +%s)

    output=$(timeout "${TIMEOUT}s" claude --plugin-dir "$PLUGIN_DIR" -p --model "$MODEL" "$prompt" 2>&1) || exit_code=$?

    invocation_end=$(date +%s)
    duration=$((invocation_end - invocation_start))

    if [[ $exit_code -eq 124 ]]; then
      printf "  \033[33mTIMEOUT\033[0m after %ds\n" "$TIMEOUT"
      continue
    fi

    if [[ -z "$output" ]]; then
      printf "  \033[33mEMPTY\033[0m Claude returned no output\n"
      continue
    fi

    printf "  Duration: %ds | Output: %d chars\n" "$duration" "${#output}"

    # Run assertions for this trial
    trial_ok=true

    # Check skill activation
    if ! check_skill_activation "$output" "$expected_skill" "$not_expected_skills"; then
      trial_ok=false
    fi

    # Check expected markers
    if ! check_markers "$output" "$expected_markers" "true"; then
      trial_ok=false
    fi

    # Check not-expected markers
    if ! check_markers "$output" "$not_expected_markers" "false"; then
      trial_ok=false
    fi

    if [[ "$trial_ok" == true ]]; then
      trial_passes=$((trial_passes + 1))
    fi

    trial_outputs+=("$output")
  done

  # ── Evaluate trial results ─────────────────────────────────────
  pass_rate=0
  if [[ "$TRIALS" -gt 0 ]]; then
    pass_rate=$((trial_passes * 100 / TRIALS))
  fi

  threshold=80
  if [[ "$pass_rate" -ge "$threshold" ]]; then
    pass "$id: $trial_passes/$TRIALS trials passed ($pass_rate%)"
    status="passed"
  else
    fail "$id: $trial_passes/$TRIALS trials passed ($pass_rate%) — below ${threshold}% threshold"
    status="failed"
  fi

  # Track cost
  cost_num=$(echo "$est_cost" | tr -d '$')
  total_cost=$(echo "$total_cost + $cost_num" | bc 2>/dev/null || echo "$total_cost")

  # Save the last trial's output for potential LLM-as-judge scoring
  last_output=""
  if [[ ${#trial_outputs[@]} -gt 0 ]]; then
    last_output="${trial_outputs[-1]}"
  fi

  # Escape output for JSON (handle newlines, quotes, backslashes)
  escaped_output=$(printf '%s' "$last_output" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""')

  # Build result JSON safely with jq
  result_json=$(jq -n \
    --arg id "$id" \
    --arg desc "$desc" \
    --arg status "$status" \
    --argjson trials "$TRIALS" \
    --argjson passes "$trial_passes" \
    --argjson pass_rate "$pass_rate" \
    --argjson expected_skill "$(jq ".test_cases[$i].expected_skill" "$FIXTURE")" \
    --argjson has_rubric "$has_rubric" \
    --argjson judge_rubric "$judge_rubric" \
    --arg rubric_file "$rubric_file" \
    --arg estimated_cost "$est_cost" \
    --argjson output "$escaped_output" \
    '{id: $id, description: $desc, status: $status, trials: $trials, passes: $passes, pass_rate: $pass_rate, expected_skill: $expected_skill, has_rubric: $has_rubric, judge_rubric: $judge_rubric, rubric_file: $rubric_file, estimated_cost: $estimated_cost, output: $output}')
  collect_result "$result_json"
done

# ── Write all results to JSON at once ─────────────────────────────────
write_results

# ══════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════
end_time=$(date +%s)
total_duration=$((end_time - start_time))

section "Summary"
echo "  Total:     $((test_pass + test_fail + skip_count))"
echo "  Passed:    $test_pass"
echo "  Failed:    $test_fail"
echo "  Skipped:   $skip_count"
echo "  Duration:  ${total_duration}s"
echo "  Est. Cost: \$$total_cost"
echo "  Results:   $RESULTS_FILE"
echo ""

if [[ "$test_fail" -gt 0 ]]; then
  printf "  \033[31m%d test(s) failed\033[0m\n" "$test_fail"
  echo ""
  exit 1
elif [[ "$skip_count" -gt 0 ]] && [[ "$test_pass" -eq 0 ]]; then
  printf "  \033[33mAll tests skipped (dry-run mode)\033[0m\n"
  echo ""
  exit 0
else
  printf "  \033[32mAll tests passed\033[0m\n"
  echo ""
  exit 0
fi
