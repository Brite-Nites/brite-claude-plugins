#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/lint_discoveries.py.
#
# Builds an isolated campaigns directory per scenario (mktemp), invokes the
# lint with --campaigns-dir <tmpdir>, asserts both the exit code AND a
# scenario-specific substring in stderr (or stdout, for OK scenarios) —
# substring assertion is load-bearing (a parser crash that exits 1 satisfies
# the numeric expectation but exercises a different code path than the
# scenario targets, per BC-8712 follow-up discipline + BC-8722 ship).
#
# Pattern mirrors scripts/test_lint_canonicals.sh.
#
# Scenarios:
#
#   A  happy path — valid baseline                                  expect 0
#   B  empty campaigns dir (no discoveries.json anywhere)           expect 0
#   C  invalid category enum                                        expect 1
#   D  missing required field (category)                            expect 1
#   E  missing required field (emitted_at)                          expect 1
#   F  missing required field (emitted_by_skill)                    expect 1
#   G  missing required field (payload)                             expect 1
#   H  wrong schema_version (2 != 1)                                expect 1
#   I  missing top-level schema_version                             expect 1
#   J  missing top-level signals                                    expect 1
#   K  unknown top-level key                                        expect 1
#   L  unknown signal key                                           expect 1
#   M  invalid promotion_status enum                                expect 1
#   N  invalid emitted_at (non-ISO-8601)                            expect 1
#   O  payload not an object (string)                               expect 1
#   P  signals not a list (object)                                  expect 1
#   Q  schema_version bool (true subclass-of-int gotcha)            expect 1
#   R  emitted_by_skill empty string                                expect 1
#   S  invalid JSON                                                 expect 1
#   T  top-level is a list (not object)                             expect 1
#   U  --file single-file mode happy path                           expect 0
#   V  --file points at missing file                                expect 2
#   W  --campaigns-dir points at nonexistent dir                    expect 0
#   X  valid baseline with promotion_status: promoted               expect 0
#   Y  valid baseline with date-only emitted_at (YYYY-MM-DD)        expect 0
#   Z  empty signals array on valid file                            expect 0
#   AA all 4 categories in one file (locked enum coverage)          expect 0
#   AB schema-vs-lint-constants drift (6 invariants)                expect 0
#
# Usage:
#   bash scripts/test_lint_discoveries.sh
#   bash scripts/test_lint_discoveries.sh /path/to/lint_discoveries.py

set -u  # NOT set -e — non-zero exits are expected for reject scenarios

# Defuse caller's git env (matches test_lint_canonicals.sh + test_pre_commit_bump.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
LINT="${1:-$script_dir/../plugins/marketing/scripts/lint_discoveries.py}"

if [ ! -f "$LINT" ]; then
  echo "FATAL: lint script not found: $LINT" >&2
  exit 2
fi
LINT="$(cd "$(dirname "$LINT")" && pwd)/$(basename "$LINT")"

tmproot="$(mktemp -d -t lint-discoveries-test.XXXXXX)" || {
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

invoke_lint_dir() {
  local dir="$1"
  LAST_OUTPUT="$(python3 "$LINT" --campaigns-dir "$dir" 2>&1)"
  LAST_RC=$?
}

invoke_lint_file() {
  local file="$1"
  LAST_OUTPUT="$(python3 "$LINT" --file "$file" 2>&1)"
  LAST_RC=$?
}

# ── Fixture builders ─────────────────────────────────────────────────────

# A valid baseline discoveries.json at <campaigns_dir>/<entity>/<slug>/discoveries.json.
build_accept_base() {
  local dir="$1"
  local entity="${2:-labs}"
  local slug="${3:-hotels-resorts-events-director-anchor-audit-fy26-m02}"
  local campaign_dir="$dir/$entity/$slug"
  mkdir -p "$campaign_dir"
  cat > "$campaign_dir/discoveries.json" <<'JSON'
{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": {
        "vertical": "hotels-resorts",
        "persona": "events-director",
        "candidate_title": "Director of Guest Experience",
        "occurrences": 3,
        "example_companies": ["Resort A", "Resort B", "Hotel C"]
      },
      "promotion_status": "pending"
    }
  ]
}
JSON
}

mkdir_scenario() {
  local name="$1"
  local dir="$tmproot/$name"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

# Helper: write a single discoveries.json with provided JSON body.
write_discoveries() {
  local dir="$1"
  local body="$2"
  local entity="${3:-labs}"
  local slug="${4:-test-slug-fy26-m02}"
  local campaign_dir="$dir/$entity/$slug"
  mkdir -p "$campaign_dir"
  printf '%s\n' "$body" > "$campaign_dir/discoveries.json"
  printf '%s/discoveries.json' "$campaign_dir"
}

# ── Scenario A: happy path — valid baseline ─────────────────────────────
run_a() {
  local dir
  dir="$(mkdir_scenario A)"
  build_accept_base "$dir"
  invoke_lint_dir "$dir"
  assert_exit_and_substring "A: happy path baseline" 0 "Discoveries lint OK — 1 discoveries.json file"
}

# ── Scenario B: empty campaigns dir (no discoveries.json) ─────────────────
run_b() {
  local dir
  dir="$(mkdir_scenario B)"
  # Create the dir but no campaigns under it.
  invoke_lint_dir "$dir"
  assert_exit_and_substring "B: empty campaigns dir" 0 "no discoveries.json files found"
}

# ── Scenario C: invalid category enum ───────────────────────────────────
run_c() {
  local dir
  dir="$(mkdir_scenario C)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "not-a-real-category",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": {}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "C: invalid category enum" 1 "category 'not-a-real-category' not in"
}

# ── Scenario D: missing required field — category ───────────────────────
run_d() {
  local dir
  dir="$(mkdir_scenario D)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": {}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "D: missing required category" 1 "missing required key 'category'"
}

# ── Scenario E: missing required field — emitted_at ─────────────────────
run_e() {
  local dir
  dir="$(mkdir_scenario E)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_by_skill": "list-building",
      "payload": {}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "E: missing required emitted_at" 1 "missing required key 'emitted_at'"
}

# ── Scenario F: missing required field — emitted_by_skill ───────────────
run_f() {
  local dir
  dir="$(mkdir_scenario F)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "payload": {}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "F: missing required emitted_by_skill" 1 "missing required key 'emitted_by_skill'"
}

# ── Scenario G: missing required field — payload ────────────────────────
run_g() {
  local dir
  dir="$(mkdir_scenario G)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building"
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "G: missing required payload" 1 "missing required key 'payload'"
}

# ── Scenario H: wrong schema_version (2 != 1) ───────────────────────────
run_h() {
  local dir
  dir="$(mkdir_scenario H)"
  write_discoveries "$dir" '{
  "schema_version": 2,
  "signals": []
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "H: wrong schema_version" 1 "schema_version 2 != linter SCHEMA_VERSION 1"
}

# ── Scenario I: missing top-level schema_version ────────────────────────
run_i() {
  local dir
  dir="$(mkdir_scenario I)"
  write_discoveries "$dir" '{
  "signals": []
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "I: missing top-level schema_version" 1 "missing required key 'schema_version'"
}

# ── Scenario J: missing top-level signals ───────────────────────────────
run_j() {
  local dir
  dir="$(mkdir_scenario J)"
  write_discoveries "$dir" '{
  "schema_version": 1
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "J: missing top-level signals" 1 "missing required key 'signals'"
}

# ── Scenario K: unknown top-level key ───────────────────────────────────
run_k() {
  local dir
  dir="$(mkdir_scenario K)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [],
  "rogue_field": "uh oh"
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "K: unknown top-level key" 1 "unknown key 'rogue_field'"
}

# ── Scenario L: unknown signal key ──────────────────────────────────────
run_l() {
  local dir
  dir="$(mkdir_scenario L)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": {},
      "rogue_signal_key": "nope"
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "L: unknown signal key" 1 "unknown key 'rogue_signal_key'"
}

# ── Scenario M: invalid promotion_status enum ───────────────────────────
run_m() {
  local dir
  dir="$(mkdir_scenario M)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": {},
      "promotion_status": "in-review"
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "M: invalid promotion_status" 1 "promotion_status 'in-review' not in"
}

# ── Scenario N: invalid emitted_at (non-ISO-8601) ────────────────────────
run_n() {
  local dir
  dir="$(mkdir_scenario N)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "yesterday",
      "emitted_by_skill": "list-building",
      "payload": {}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "N: invalid emitted_at" 1 "emitted_at 'yesterday' is not a valid ISO-8601"
}

# ── Scenario O: payload not an object ───────────────────────────────────
run_o() {
  local dir
  dir="$(mkdir_scenario O)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": "should be an object not a string"
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "O: payload not an object" 1 "payload must be an object"
}

# ── Scenario P: signals not a list ──────────────────────────────────────
run_p() {
  local dir
  dir="$(mkdir_scenario P)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": {"not": "a list"}
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "P: signals not a list" 1 "signals must be a list"
}

# ── Scenario Q: schema_version bool subclass-of-int gotcha ──────────────
run_q() {
  local dir
  dir="$(mkdir_scenario Q)"
  write_discoveries "$dir" '{
  "schema_version": true,
  "signals": []
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "Q: schema_version bool" 1 "schema_version must be an integer"
}

# ── Scenario R: emitted_by_skill empty string ───────────────────────────
run_r() {
  local dir
  dir="$(mkdir_scenario R)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "   ",
      "payload": {}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "R: emitted_by_skill empty" 1 "emitted_by_skill must be a non-empty string"
}

# ── Scenario S: invalid JSON ────────────────────────────────────────────
run_s() {
  local dir
  dir="$(mkdir_scenario S)"
  write_discoveries "$dir" '{ this is not json }' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "S: invalid JSON" 1 "invalid JSON"
}

# ── Scenario T: top-level is a list ─────────────────────────────────────
run_t() {
  local dir
  dir="$(mkdir_scenario T)"
  write_discoveries "$dir" '[1, 2, 3]' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "T: top-level list" 1 "top-level must be an object"
}

# ── Scenario U: --file single-file mode happy path ──────────────────────
run_u() {
  local dir
  dir="$(mkdir_scenario U)"
  local target
  target=$(write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "icp-refinement",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "campaign-debrief",
      "payload": {"vertical": "hotels-resorts"}
    }
  ]
}')
  invoke_lint_file "$target"
  assert_exit_and_substring "U: --file happy path" 0 "Discoveries lint OK — 1 discoveries.json"
}

# ── Scenario V: --file points at missing file ───────────────────────────
run_v() {
  local dir
  dir="$(mkdir_scenario V)"
  LAST_OUTPUT="$(python3 "$LINT" --file "$dir/does-not-exist.json" 2>&1)"
  LAST_RC=$?
  assert_exit_and_substring "V: --file missing" 2 "file not found"
}

# ── Scenario W: --campaigns-dir nonexistent ─────────────────────────────
run_w() {
  # Note: nonexistent campaigns dir is treated as an empty-case clean pass
  # (pre-first-campaign-emission). This is the documented behavior.
  invoke_lint_dir "$tmproot/W-does-not-exist"
  assert_exit_and_substring "W: --campaigns-dir nonexistent" 0 "no docs/campaigns/ directory"
}

# ── Scenario X: promotion_status: promoted (valid) ──────────────────────
run_x() {
  local dir
  dir="$(mkdir_scenario X)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "offer-retirement",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "campaign-debrief",
      "payload": {"offer_slug": "stale-offer"},
      "promotion_status": "promoted"
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "X: promotion_status promoted" 0 "Discoveries lint OK"
}

# ── Scenario Y: date-only emitted_at (YYYY-MM-DD) ───────────────────────
run_y() {
  local dir
  dir="$(mkdir_scenario Y)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "persona-discovery",
      "emitted_at": "2026-05-22",
      "emitted_by_skill": "campaign-debrief",
      "payload": {"vertical": "hotels-resorts"}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "Y: date-only emitted_at" 0 "Discoveries lint OK"
}

# ── Scenario Z: empty signals array ─────────────────────────────────────
run_z() {
  local dir
  dir="$(mkdir_scenario Z)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": []
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "Z: empty signals array" 0 "Discoveries lint OK — 1 discoveries.json"
}

# ── Scenario AA: all 4 categories in one file (enum coverage) ───────────
run_aa() {
  local dir
  dir="$(mkdir_scenario AA)"
  write_discoveries "$dir" '{
  "schema_version": 1,
  "signals": [
    {
      "category": "title-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "list-building",
      "payload": {}
    },
    {
      "category": "icp-refinement",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "campaign-debrief",
      "payload": {}
    },
    {
      "category": "offer-retirement",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "campaign-debrief",
      "payload": {}
    },
    {
      "category": "persona-discovery",
      "emitted_at": "2026-05-22T14:30:00Z",
      "emitted_by_skill": "campaign-debrief",
      "payload": {}
    }
  ]
}' >/dev/null
  invoke_lint_dir "$dir"
  assert_exit_and_substring "AA: all 4 categories" 0 "Discoveries lint OK — 1 discoveries.json"
}

# ── Scenario AB: schema-vs-lint-constants drift detection ───────────────
# The lint mirrors the schema's additionalProperties:false allowlists +
# required arrays + enums via module-level frozensets. This scenario asserts
# they stay in sync — the single highest-value invariant for the lint's
# correctness over time. Reviewer-flagged (PR #355 R1 P3).
run_ab() {
  local schema_path
  schema_path="$script_dir/../plugins/marketing/data/discoveries-schema.json"
  if [ ! -f "$schema_path" ]; then
    echo "  FAIL  AB: schema-vs-lint-constants drift — schema not found at $schema_path"
    fail=$((fail + 1))
    return
  fi
  LAST_OUTPUT="$(SCHEMA_PATH="$schema_path" LINT_PATH="$LINT" python3 << 'PYEOF'
import importlib.util
import json
import os
import sys

schema_path = os.environ["SCHEMA_PATH"]
lint_path = os.environ["LINT_PATH"]

with open(schema_path) as f:
    schema = json.load(f)

spec = importlib.util.spec_from_file_location("lint_discoveries", lint_path)
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)

errors = []

# 1. SCHEMA_VERSION must match the schema const declaration.
schema_version_const = schema["properties"]["schema_version"]["const"]
if lint.SCHEMA_VERSION != schema_version_const:
    errors.append(
        f"SCHEMA_VERSION mismatch: lint={lint.SCHEMA_VERSION} schema={schema_version_const}"
    )

# 2. TOP_LEVEL_KEYS must match schema.properties (additionalProperties:false allowlist).
schema_top = set(schema["properties"].keys())
lint_top = set(lint.TOP_LEVEL_KEYS)
if lint_top != schema_top:
    errors.append(
        f"TOP_LEVEL_KEYS mismatch: lint={sorted(lint_top)} schema={sorted(schema_top)}"
    )

# 3. SIGNAL_KEYS must match definitions.signal.properties (allowlist).
signal_def = schema["definitions"]["signal"]
schema_signal = set(signal_def["properties"].keys())
lint_signal = set(lint.SIGNAL_KEYS)
if lint_signal != schema_signal:
    errors.append(
        f"SIGNAL_KEYS mismatch: lint={sorted(lint_signal)} schema={sorted(schema_signal)}"
    )

# 4. SIGNAL_REQUIRED must match definitions.signal.required.
schema_required = set(signal_def["required"])
lint_required = set(lint.SIGNAL_REQUIRED)
if lint_required != schema_required:
    errors.append(
        f"SIGNAL_REQUIRED mismatch: lint={sorted(lint_required)} schema={sorted(schema_required)}"
    )

# 5. ALLOWED_CATEGORIES must match definitions.signal.properties.category.enum.
schema_categories = set(signal_def["properties"]["category"]["enum"])
lint_categories = set(lint.ALLOWED_CATEGORIES)
if lint_categories != schema_categories:
    errors.append(
        f"ALLOWED_CATEGORIES mismatch: lint={sorted(lint_categories)} schema={sorted(schema_categories)}"
    )

# 6. ALLOWED_PROMOTION_STATUS must match definitions.signal.properties.promotion_status.enum.
schema_status = set(signal_def["properties"]["promotion_status"]["enum"])
lint_status = set(lint.ALLOWED_PROMOTION_STATUS)
if lint_status != schema_status:
    errors.append(
        f"ALLOWED_PROMOTION_STATUS mismatch: lint={sorted(lint_status)} schema={sorted(schema_status)}"
    )

if errors:
    print("DRIFT detected:")
    for e in errors:
        print(f"  {e}")
    sys.exit(1)
print("CLEAN: lint constants match schema (6 invariants checked)")
PYEOF
)"
  LAST_RC=$?
  assert_exit_and_substring "AB: schema-vs-lint-constants drift" 0 "CLEAN: lint constants match schema"
}

# ── Run all scenarios ────────────────────────────────────────────────────
# Discover every `run_<letter>` function and invoke in document order:
# single-letter (A-Z) first, then double-letter (AA-AZ), tripled-letter, etc.
# Mirrors test_lint_canonicals.sh discovery loop.
scenarios=()
while IFS= read -r fn; do
  scenarios+=("$fn")
done < <(
  compgen -A function \
    | grep '^run_[a-z]' \
    | awk '{ print length($0), $0 }' \
    | sort -k1,1n -k2,2 \
    | awk '{ print $2 }'
)

if [ "${#scenarios[@]}" -eq 0 ]; then
  echo "FATAL: no scenarios discovered (compgen returned empty — wrong shell?)" >&2
  exit 2
fi

echo ""
echo "Running lint_discoveries.py regression harness (${#scenarios[@]} scenarios)..."
echo ""

for fn in "${scenarios[@]}"; do
  "$fn"
done

echo ""
echo "Summary: $pass passed, $fail failed"
# Machine-readable result line for validate.sh ingestion (must be the last line).
printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
