#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/lint_canonicals.py.
#
# Builds an isolated canonicals directory per scenario (mktemp), invokes the
# lint with --canonicals-dir <tmpdir>, asserts both the exit code AND a
# scenario-specific substring in stderr — substring assertion is load-bearing
# (a parser crash that exits 1 satisfies the numeric expectation but exercises
# a different code path than the scenario targets, per BC-8712 follow-up
# discipline).
#
# Scenarios:
#   A  happy path (minimal accept fixture)                          expect 0
#   B  vertical missing required `display`                          expect 1 — "missing required key 'display'"
#   C  unknown top-level key (additionalProperties violation)       expect 1 — "unknown key 'rogue_key'"
#   D  unknown offer key                                            expect 1 — "unknown key 'rogue_offer_key'"
#   E  bad offer.status enum                                        expect 1 — "status 'pending'"
#   F  bad offer.posture enum                                       expect 1 — "posture 'unknown-posture'"
#   G  non-kebab persona slug (camelCase)                           expect 1 — "is not kebab-case"
#   H  duplicate persona slug within a vertical                     expect 1 — "duplicate persona slug 'dup'"
#   I  target_personas references undefined persona                 expect 1 — "not defined in personas[]"
#   J  target_personas item is not kebab-case                       expect 1 — "is not kebab-case"
#   K  _manifest.yaml verticals[] not alphabetized                  expect 1 — "not alphabetized"
#   L  manifest entry has no matching {slug}.yaml file              expect 1 — "but no .*yaml found"
#   M  alias collides with another vertical's canonical slug        expect 1 — "alias 'bravo' collides"
#   N  _manifest.yaml schema_version != linter SCHEMA_VERSION       expect 1 — "schema_version"
#   O  tab character in indent                                      expect 1 — "tabs not allowed in indent"
#
# Usage:
#   bash scripts/test_lint_canonicals.sh
#   bash scripts/test_lint_canonicals.sh /path/to/lint_canonicals.py

set -u  # NOT set -e — non-zero exits are expected for reject scenarios

# Defuse caller's git env (matches test_pre_commit_bump.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
LINT="${1:-$script_dir/../plugins/marketing/scripts/lint_canonicals.py}"

if [ ! -f "$LINT" ]; then
  echo "FATAL: lint script not found: $LINT" >&2
  exit 2
fi
LINT="$(cd "$(dirname "$LINT")" && pwd)/$(basename "$LINT")"

tmproot="$(mktemp -d -t lint-canonicals-test.XXXXXX)" || {
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

run_lint() {
  local dir="$1"
  LAST_OUTPUT="$(python3 "$LINT" --canonicals-dir "$dir" 2>&1)"
  LAST_RC=$?
}

# ── Fixture builders ─────────────────────────────────────────────────────

# Minimal accept fixture: 1 manifest + 1 populated vertical + 1 skeleton.
build_accept_base() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/_manifest.yaml" <<'YAML'
schema_version: 1
verticals:
  - alpha
  - bravo
YAML
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-one
    display: "Offer One"
    status: active
    posture: free-asset
    target_personas: [persona-one]
YAML
  cat > "$dir/bravo.yaml" <<'YAML'
slug: bravo
display: "Bravo"
personas: []
offers: []
YAML
}

# Scenarios overlay on top of accept_base; each mutates one aspect.

mkdir_scenario() {
  local name="$1"
  local dir="$tmproot/$name"
  build_accept_base "$dir"
  printf '%s' "$dir"
}

# ── Scenario A: happy path ───────────────────────────────────────────────
run_a() {
  local dir
  dir="$(mkdir_scenario A)"
  run_lint "$dir"
  assert_exit_and_substring "A: happy path" 0 "Canonicals lint OK"
}

# ── Scenario B: missing required `display` ───────────────────────────────
run_b() {
  local dir
  dir="$(mkdir_scenario B)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
personas: []
offers: []
YAML
  run_lint "$dir"
  assert_exit_and_substring "B: missing required display" 1 "missing required key 'display'"
}

# ── Scenario C: unknown top-level key ────────────────────────────────────
run_c() {
  local dir
  dir="$(mkdir_scenario C)"
  cat >> "$dir/alpha.yaml" <<'YAML'
rogue_key: "should be rejected"
YAML
  run_lint "$dir"
  assert_exit_and_substring "C: unknown top-level key" 1 "unknown key 'rogue_key'"
}

# ── Scenario D: unknown offer key ────────────────────────────────────────
run_d() {
  local dir
  dir="$(mkdir_scenario D)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-one
    display: "Offer One"
    status: active
    posture: free-asset
    rogue_offer_key: "should be rejected"
YAML
  run_lint "$dir"
  assert_exit_and_substring "D: unknown offer key" 1 "unknown key 'rogue_offer_key'"
}

# ── Scenario E: bad status enum ──────────────────────────────────────────
run_e() {
  local dir
  dir="$(mkdir_scenario E)"
  sed -i.bak "s/status: active/status: pending/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  run_lint "$dir"
  assert_exit_and_substring "E: bad status enum" 1 "status 'pending'"
}

# ── Scenario F: bad posture enum ─────────────────────────────────────────
run_f() {
  local dir
  dir="$(mkdir_scenario F)"
  sed -i.bak "s/posture: free-asset/posture: unknown-posture/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  run_lint "$dir"
  assert_exit_and_substring "F: bad posture enum" 1 "posture 'unknown-posture'"
}

# ── Scenario G: non-kebab persona slug ───────────────────────────────────
run_g() {
  local dir
  dir="$(mkdir_scenario G)"
  sed -i.bak "s/slug: persona-one/slug: personaOne/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  run_lint "$dir"
  assert_exit_and_substring "G: non-kebab persona slug" 1 "is not kebab-case"
}

# ── Scenario H: duplicate persona slug ───────────────────────────────────
run_h() {
  local dir
  dir="$(mkdir_scenario H)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: dup
    display: "Persona One"
    titles:
      - "Title One"
  - slug: dup
    display: "Persona Two"
    titles:
      - "Title Two"
offers: []
YAML
  run_lint "$dir"
  assert_exit_and_substring "H: duplicate persona slug" 1 "duplicate persona slug 'dup'"
}

# ── Scenario I: target_personas references undefined persona ─────────────
run_i() {
  local dir
  dir="$(mkdir_scenario I)"
  sed -i.bak "s/target_personas: \[persona-one\]/target_personas: [orphan-persona]/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  run_lint "$dir"
  assert_exit_and_substring "I: target_personas orphan ref" 1 "not defined in personas"
}

# ── Scenario J: target_personas item is not kebab-case ───────────────────
run_j() {
  local dir
  dir="$(mkdir_scenario J)"
  sed -i.bak "s/target_personas: \[persona-one\]/target_personas: [NotKebabCase]/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  run_lint "$dir"
  assert_exit_and_substring "J: target_personas non-kebab item" 1 "is not kebab-case"
}

# ── Scenario K: manifest verticals not alphabetized ──────────────────────
run_k() {
  local dir
  dir="$(mkdir_scenario K)"
  cat > "$dir/_manifest.yaml" <<'YAML'
schema_version: 1
verticals:
  - bravo
  - alpha
YAML
  run_lint "$dir"
  assert_exit_and_substring "K: manifest not alphabetized" 1 "not alphabetized"
}

# ── Scenario L: manifest entry has no matching file ──────────────────────
run_l() {
  local dir
  dir="$(mkdir_scenario L)"
  cat > "$dir/_manifest.yaml" <<'YAML'
schema_version: 1
verticals:
  - alpha
  - bravo
  - charlie
YAML
  run_lint "$dir"
  assert_exit_and_substring "L: manifest entry without file" 1 "manifest lists 'charlie' but no charlie.yaml found"
}

# ── Scenario M: alias collides with canonical slug ───────────────────────
run_m() {
  local dir
  dir="$(mkdir_scenario M)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
aliases:
  - bravo
personas: []
offers: []
YAML
  run_lint "$dir"
  assert_exit_and_substring "M: alias collides with canonical" 1 "alias 'bravo' collides with canonical vertical slug"
}

# ── Scenario N: schema_version mismatch ──────────────────────────────────
run_n() {
  local dir
  dir="$(mkdir_scenario N)"
  cat > "$dir/_manifest.yaml" <<'YAML'
schema_version: 99
verticals:
  - alpha
  - bravo
YAML
  run_lint "$dir"
  assert_exit_and_substring "N: schema_version mismatch" 1 "schema_version 99"
}

# ── Scenario O: tabs in indent ───────────────────────────────────────────
run_o() {
  local dir
  dir="$(mkdir_scenario O)"
  # Emit a vertical YAML with a tab character in the persona indent.
  printf 'slug: alpha\ndisplay: "Alpha"\npersonas:\n\t- slug: persona-one\n\t  display: "Persona One"\n\t  titles:\n\t    - "Title One"\noffers: []\n' > "$dir/alpha.yaml"
  run_lint "$dir"
  assert_exit_and_substring "O: tabs in indent" 1 "tabs not allowed in indent"
}

# ── Run all scenarios ────────────────────────────────────────────────────
echo ""
echo "Running lint_canonicals.py regression harness (15 scenarios)..."
echo ""

run_a
run_b
run_c
run_d
run_e
run_f
run_g
run_h
run_i
run_j
run_k
run_l
run_m
run_n
run_o

echo ""
echo "Summary: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
