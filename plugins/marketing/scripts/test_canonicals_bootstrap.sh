#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/canonicals_bootstrap.py (BC-8725).
# Tests vertical, offer, and persona subcommands via tempdir fixtures.
# Mirrors test_shared_utilities.sh substring-assertion + RESULT-line discipline.
#
# Usage:
#   bash plugins/marketing/scripts/test_canonicals_bootstrap.sh [path-to-helper]

set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
helper="${1:-$script_dir/canonicals_bootstrap.py}"

if [ ! -f "$helper" ]; then
  echo "FATAL: helper not found at $helper" >&2
  exit 2
fi

tmproot="$(mktemp -d -t test-canonicals-bootstrap.XXXXXX)" || {
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

assert_exit_and_no_substring() {
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
  if printf '%s' "$output" | grep -qE -- "$substring"; then
    echo "  FAIL  $label — substring unexpectedly found"
    echo "    unexpected regex: $substring"
    echo "    output: $output"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (exit=$actual_rc, substring absent)"
  pass=$((pass + 1))
}

invoke() {
  LAST_OUTPUT="$(cd "$script_dir" && python3 "$helper" "$@" 2>&1)"
  LAST_RC=$?
}

# ── Fixture builders ──────────────────────────────────────────────────────

mk_canonicals_dir() {
  local name="$1"
  local d="$tmproot/$name"
  mkdir -p "$d"
  printf '%s' "$d"
}

mk_standard_fixture() {
  local name="$1"
  local d
  d=$(mk_canonicals_dir "$name")

  cat > "$d/_manifest.yaml" <<'YAML'
schema_version: 2
verticals:
  - apartments
  - hotels-resorts
  - zoos
YAML

  cat > "$d/apartments.yaml" <<'YAML'
slug: apartments
display: "Apartments"
personas:
  - slug: property-manager
    display: "Property Manager"
    titles:
      - "Property Manager"
      - "Apartment Manager"
offers:
  - slug: curb-appeal-guide
    display: "Curb Appeal Guide"
    status: draft
    posture: knowledge
YAML

  cat > "$d/hotels-resorts.yaml" <<'YAML'
slug: hotels-resorts
display: "Hotels & Resorts"
personas:
  - slug: director-of-resort-experience
    display: "Director of Resort Experience"
    titles:
      - "Director of Resort Experience"
offers:
  - slug: holiday-anchor-audit
    display: "Resort Holiday Anchor Audit"
    status: draft
    posture: free-asset
YAML

  cat > "$d/zoos.yaml" <<'YAML'
slug: zoos
display: "Zoos"
personas: []
offers: []
YAML

  # Discovery ICP stubs (ADR-024) — mandatory per vertical; lint ERRORs
  # without them, which would mask the bootstrap scenarios' own assertions.
  mkdir -p "$d/icp"
  local v
  for v in apartments hotels-resorts zoos; do
    cat > "$d/icp/$v.json" <<JSON
{
  "vertical": "$v",
  "source": "marketing/go-to-market/verticals/$v/README.md",
  "clarifications_needed": ["category / segment", "size band", "geography"],
  "segments": {}
}
JSON
  done

  printf '%s' "$d"
}

# ══════════════════════════════════════════════════════════════════════════
# VERTICAL TESTS
# ══════════════════════════════════════════════════════════════════════════

echo "── vertical ──"

# V1: Valid new vertical
d=$(mk_standard_fixture "V1")
invoke --canonicals-dir "$d" vertical --slug "water-parks" --display "Water Parks"
assert_exit_and_substring "V1: valid new vertical" 0 '"ok": true'
# Check manifest was updated
assert_file_content_v1="$(cat "$d/_manifest.yaml")"
if printf '%s' "$assert_file_content_v1" | grep -q "water-parks"; then
  echo "  PASS  V1: manifest contains water-parks"
  pass=$((pass + 1))
else
  echo "  FAIL  V1: manifest missing water-parks"
  fail=$((fail + 1))
fi
# Check YAML file was created
if [ -f "$d/water-parks.yaml" ]; then
  echo "  PASS  V1: water-parks.yaml created"
  pass=$((pass + 1))
else
  echo "  FAIL  V1: water-parks.yaml not created"
  fail=$((fail + 1))
fi
# Check handbook draft emission
assert_exit_and_substring "V1: handbook draft present" 0 '"handbook_draft"'
# Check resume instruction
assert_exit_and_substring "V1: resume instruction" 0 'plan-campaign.*--vertical=water-parks'

# V2: Kebab-case violation
d=$(mk_standard_fixture "V2")
invoke --canonicals-dir "$d" vertical --slug "Water_Parks" --display "Water Parks"
assert_exit_and_substring "V2: kebab-case violation" 1 "not kebab-case"

# V3: Already exists
d=$(mk_standard_fixture "V3")
invoke --canonicals-dir "$d" vertical --slug "apartments" --display "Apartments"
assert_exit_and_substring "V3: already exists" 1 "already exists"
assert_exit_and_substring "V3: resume on exists" 1 "resume"

# V4: Manifest alphabetized insertion (slug should sort between apartments and hotels-resorts)
d=$(mk_standard_fixture "V4")
invoke --canonicals-dir "$d" vertical --slug "botanical-gardens" --display "Botanical Gardens"
manifest_v4="$(cat "$d/_manifest.yaml")"
# apartments should come before botanical-gardens which should come before hotels-resorts
apts_line=$(printf '%s' "$manifest_v4" | grep -n "apartments" | head -1 | cut -d: -f1)
bot_line=$(printf '%s' "$manifest_v4" | grep -n "botanical-gardens" | head -1 | cut -d: -f1)
hot_line=$(printf '%s' "$manifest_v4" | grep -n "hotels-resorts" | head -1 | cut -d: -f1)
if [ -n "$apts_line" ] && [ -n "$bot_line" ] && [ -n "$hot_line" ] && \
   [ "$apts_line" -lt "$bot_line" ] && [ "$bot_line" -lt "$hot_line" ]; then
  echo "  PASS  V4: manifest alphabetized (apts=$apts_line < bot=$bot_line < hot=$hot_line)"
  pass=$((pass + 1))
else
  echo "  FAIL  V4: manifest not alphabetized (apts=$apts_line bot=$bot_line hot=$hot_line)"
  fail=$((fail + 1))
fi

# V5: Handbook draft emission contains suggested path
d=$(mk_standard_fixture "V5")
invoke --canonicals-dir "$d" vertical --slug "test-vert" --display "Test Vert"
assert_exit_and_substring "V5: handbook draft path" 0 "suggested_path"
assert_exit_and_substring "V5: handbook draft commit msg" 0 "suggested_commit_message"

# V6: Lint-clean after creation
d=$(mk_standard_fixture "V6")
invoke --canonicals-dir "$d" vertical --slug "theme-parks" --display "Theme Parks"
lint_out="$(cd "$script_dir" && python3 "$script_dir/lint_canonicals.py" --canonicals-dir "$d" 2>&1)"
lint_rc=$?
if [ "$lint_rc" -eq 0 ]; then
  echo "  PASS  V6: lint clean after vertical creation"
  pass=$((pass + 1))
else
  echo "  FAIL  V6: lint failed after vertical creation (rc=$lint_rc)"
  echo "    output: $lint_out"
  fail=$((fail + 1))
fi

# V7: Preview mode (no mutations)
d=$(mk_standard_fixture "V7")
manifest_before="$(cat "$d/_manifest.yaml")"
invoke --canonicals-dir "$d" vertical --slug "water-parks" --display "Water Parks" --preview
assert_exit_and_substring "V7: preview returns ok" 0 '"ok": true'
assert_exit_and_substring "V7: preview key present" 0 '"preview"'
manifest_after="$(cat "$d/_manifest.yaml")"
if [ "$manifest_before" = "$manifest_after" ]; then
  echo "  PASS  V7: preview made no mutations"
  pass=$((pass + 1))
else
  echo "  FAIL  V7: preview mutated the manifest"
  fail=$((fail + 1))
fi

# V8: With aliases
d=$(mk_standard_fixture "V8")
invoke --canonicals-dir "$d" vertical --slug "water-parks" --display "Water Parks" --aliases "waterparks,splash-parks"
assert_exit_and_substring "V8: vertical with aliases created" 0 '"ok": true'
yaml_v8="$(cat "$d/water-parks.yaml")"
if printf '%s' "$yaml_v8" | grep -q "waterparks" && printf '%s' "$yaml_v8" | grep -q "splash-parks"; then
  echo "  PASS  V8: aliases present in YAML"
  pass=$((pass + 1))
else
  echo "  FAIL  V8: aliases missing from YAML"
  echo "    content: $yaml_v8"
  fail=$((fail + 1))
fi

# V9: Invalid alias slug
d=$(mk_standard_fixture "V9")
invoke --canonicals-dir "$d" vertical --slug "water-parks" --display "Water Parks" --aliases "Valid,INVALID_SLUG"
assert_exit_and_substring "V9: invalid alias rejected" 1 "not kebab-case"

# ══════════════════════════════════════════════════════════════════════════
# OFFER TESTS
# ══════════════════════════════════════════════════════════════════════════

echo "── offer ──"

# O1: Valid new offer with posture
d=$(mk_standard_fixture "O1")
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "led-savings-calc" --display "LED Savings Calculator" --posture "knowledge"
assert_exit_and_substring "O1: valid new offer" 0 '"ok": true'
assert_exit_and_substring "O1: posture in output" 0 '"posture": "knowledge"'
# Check offer was appended
yaml_o1="$(cat "$d/apartments.yaml")"
if printf '%s' "$yaml_o1" | grep -q "led-savings-calc"; then
  echo "  PASS  O1: offer present in YAML"
  pass=$((pass + 1))
else
  echo "  FAIL  O1: offer missing from YAML"
  fail=$((fail + 1))
fi

# O2: Invalid posture
d=$(mk_standard_fixture "O2")
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "test-offer" --display "Test" --posture "invalid-posture"
assert_exit_and_substring "O2: invalid posture" 1 "posture.*invalid"

# O3: Unknown vertical
d=$(mk_standard_fixture "O3")
invoke --canonicals-dir "$d" offer --vertical "nonexistent" --slug "test-offer" --display "Test" --posture "knowledge"
assert_exit_and_substring "O3: unknown vertical" 1 "not in canonicals manifest"

# O4: Already exists
d=$(mk_standard_fixture "O4")
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "curb-appeal-guide" --display "Curb Appeal Guide" --posture "knowledge"
assert_exit_and_substring "O4: already exists" 1 "already exists"
assert_exit_and_substring "O4: resume on exists" 1 "resume"

# O5: Handbook draft emission
d=$(mk_standard_fixture "O5")
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "led-calc" --display "LED Calculator" --posture "free-asset"
assert_exit_and_substring "O5: handbook draft" 0 "suggested_path"
assert_exit_and_substring "O5: resume instruction" 0 'plan-campaign.*--vertical=apartments.*--offer=led-calc'

# O6: Lint-clean after offer addition
d=$(mk_standard_fixture "O6")
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "led-calc" --display "LED Calculator" --posture "pilot" --status "active"
lint_out="$(cd "$script_dir" && python3 "$script_dir/lint_canonicals.py" --canonicals-dir "$d" 2>&1)"
lint_rc=$?
if [ "$lint_rc" -eq 0 ]; then
  echo "  PASS  O6: lint clean after offer addition"
  pass=$((pass + 1))
else
  echo "  FAIL  O6: lint failed after offer addition (rc=$lint_rc)"
  echo "    output: $lint_out"
  fail=$((fail + 1))
fi

# O7: Add offer to empty offers list
d=$(mk_standard_fixture "O7")
invoke --canonicals-dir "$d" offer --vertical "zoos" --slug "night-safari" --display "Night Safari Experience" --posture "risk-reversal"
assert_exit_and_substring "O7: offer added to empty list" 0 '"ok": true'
yaml_o7="$(cat "$d/zoos.yaml")"
if printf '%s' "$yaml_o7" | grep -q "night-safari"; then
  echo "  PASS  O7: offer present in previously-empty list"
  pass=$((pass + 1))
else
  echo "  FAIL  O7: offer missing from YAML"
  fail=$((fail + 1))
fi

# O8: Kebab-case slug violation
d=$(mk_standard_fixture "O8")
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "LED_Calc" --display "LED Calculator" --posture "knowledge"
assert_exit_and_substring "O8: kebab-case violation" 1 "not kebab-case"

# O9: Invalid status
d=$(mk_standard_fixture "O9")
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "test-offer" --display "Test" --posture "knowledge" --status "archived"
assert_exit_and_substring "O9: invalid status" 1 "status.*invalid"

# O10: Preview mode (no mutations)
d=$(mk_standard_fixture "O10")
yaml_before="$(cat "$d/apartments.yaml")"
invoke --canonicals-dir "$d" offer --vertical "apartments" --slug "new-offer" --display "New Offer" --posture "knowledge" --preview
assert_exit_and_substring "O10: preview returns ok" 0 '"ok": true'
yaml_after="$(cat "$d/apartments.yaml")"
if [ "$yaml_before" = "$yaml_after" ]; then
  echo "  PASS  O10: preview made no mutations"
  pass=$((pass + 1))
else
  echo "  FAIL  O10: preview mutated the YAML"
  fail=$((fail + 1))
fi

# ══════════════════════════════════════════════════════════════════════════
# PERSONA TESTS
# ══════════════════════════════════════════════════════════════════════════

echo "── persona ──"

# P1: Valid new persona
d=$(mk_standard_fixture "P1")
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "facilities-director" --display "Facilities Director" --titles "Facilities Director,Director of Maintenance"
assert_exit_and_substring "P1: valid new persona" 0 '"ok": true'
yaml_p1="$(cat "$d/apartments.yaml")"
if printf '%s' "$yaml_p1" | grep -q "facilities-director"; then
  echo "  PASS  P1: persona present in YAML"
  pass=$((pass + 1))
else
  echo "  FAIL  P1: persona missing from YAML"
  fail=$((fail + 1))
fi

# P2: Kebab-case violation
d=$(mk_standard_fixture "P2")
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "Facilities_Dir" --display "Facilities Director"
assert_exit_and_substring "P2: kebab-case violation" 1 "not kebab-case"

# P3: Unknown vertical
d=$(mk_standard_fixture "P3")
invoke --canonicals-dir "$d" persona --vertical "nonexistent" --slug "test-persona" --display "Test"
assert_exit_and_substring "P3: unknown vertical" 1 "not in canonicals manifest"

# P4: Already exists
d=$(mk_standard_fixture "P4")
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "property-manager" --display "Property Manager"
assert_exit_and_substring "P4: already exists" 1 "already exists"
assert_exit_and_substring "P4: resume on exists" 1 "resume"

# P5: Titles list parsed correctly
d=$(mk_standard_fixture "P5")
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "leasing-agent" --display "Leasing Agent" --titles "Leasing Agent,Leasing Consultant,Leasing Specialist"
assert_exit_and_substring "P5: persona created" 0 '"ok": true'
yaml_p5="$(cat "$d/apartments.yaml")"
if printf '%s' "$yaml_p5" | grep -q "Leasing Consultant" && printf '%s' "$yaml_p5" | grep -q "Leasing Specialist"; then
  echo "  PASS  P5: all titles present in YAML"
  pass=$((pass + 1))
else
  echo "  FAIL  P5: some titles missing from YAML"
  echo "    content: $yaml_p5"
  fail=$((fail + 1))
fi

# P6: Lint-clean after persona addition
d=$(mk_standard_fixture "P6")
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "leasing-agent" --display "Leasing Agent" --titles "Leasing Agent,Leasing Consultant"
lint_out="$(cd "$script_dir" && python3 "$script_dir/lint_canonicals.py" --canonicals-dir "$d" 2>&1)"
lint_rc=$?
if [ "$lint_rc" -eq 0 ]; then
  echo "  PASS  P6: lint clean after persona addition"
  pass=$((pass + 1))
else
  echo "  FAIL  P6: lint failed after persona addition (rc=$lint_rc)"
  echo "    output: $lint_out"
  fail=$((fail + 1))
fi

# P7: Default title from display name (no --titles flag)
d=$(mk_standard_fixture "P7")
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "concierge" --display "Concierge"
assert_exit_and_substring "P7: persona created" 0 '"ok": true'
yaml_p7="$(cat "$d/apartments.yaml")"
if printf '%s' "$yaml_p7" | grep -q '"Concierge"'; then
  echo "  PASS  P7: display used as default title"
  pass=$((pass + 1))
else
  echo "  FAIL  P7: default title not found"
  echo "    content: $yaml_p7"
  fail=$((fail + 1))
fi

# P8: Add persona to empty personas list
d=$(mk_standard_fixture "P8")
invoke --canonicals-dir "$d" persona --vertical "zoos" --slug "zoo-director" --display "Zoo Director" --titles "Zoo Director,Director of Animal Programs"
assert_exit_and_substring "P8: persona added to empty list" 0 '"ok": true'
yaml_p8="$(cat "$d/zoos.yaml")"
if printf '%s' "$yaml_p8" | grep -q "zoo-director"; then
  echo "  PASS  P8: persona present in previously-empty list"
  pass=$((pass + 1))
else
  echo "  FAIL  P8: persona missing from YAML"
  fail=$((fail + 1))
fi

# P9: Preview mode (no mutations)
d=$(mk_standard_fixture "P9")
yaml_before="$(cat "$d/apartments.yaml")"
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "new-persona" --display "New Persona" --preview
assert_exit_and_substring "P9: preview returns ok" 0 '"ok": true'
yaml_after="$(cat "$d/apartments.yaml")"
if [ "$yaml_before" = "$yaml_after" ]; then
  echo "  PASS  P9: preview made no mutations"
  pass=$((pass + 1))
else
  echo "  FAIL  P9: preview mutated the YAML"
  fail=$((fail + 1))
fi

# P10: Handbook draft emission
d=$(mk_standard_fixture "P10")
invoke --canonicals-dir "$d" persona --vertical "apartments" --slug "leasing-mgr" --display "Leasing Manager"
assert_exit_and_substring "P10: handbook draft" 0 "suggested_path"
assert_exit_and_substring "P10: resume instruction" 0 'plan-campaign.*--vertical=apartments.*--persona=leasing-mgr'

# ══════════════════════════════════════════════════════════════════════════
# CROSS-CUTTING TESTS
# ══════════════════════════════════════════════════════════════════════════

echo "── cross-cutting ──"

# X1: No subcommand → exit 2
invoke --canonicals-dir "$tmproot"
assert_exit_and_substring "X1: no subcommand" 2 "usage"

# X2: Missing manifest → error
d=$(mk_canonicals_dir "X2")
invoke --canonicals-dir "$d" vertical --slug "test" --display "Test"
assert_exit_and_substring "X2: missing manifest" 1 "manifest not found"

# X3: Sequential add — vertical then persona then offer, lint stays clean
d=$(mk_standard_fixture "X3")
invoke --canonicals-dir "$d" vertical --slug "marinas" --display "Marinas"
assert_exit_and_substring "X3a: vertical created" 0 '"ok": true'
invoke --canonicals-dir "$d" persona --vertical "marinas" --slug "harbor-master" --display "Harbor Master" --titles "Harbor Master,Marina Director"
assert_exit_and_substring "X3b: persona created" 0 '"ok": true'
invoke --canonicals-dir "$d" offer --vertical "marinas" --slug "dock-lighting-audit" --display "Dock Lighting Audit" --posture "free-asset"
assert_exit_and_substring "X3c: offer created" 0 '"ok": true'
lint_out="$(cd "$script_dir" && python3 "$script_dir/lint_canonicals.py" --canonicals-dir "$d" 2>&1)"
lint_rc=$?
if [ "$lint_rc" -eq 0 ]; then
  echo "  PASS  X3d: lint clean after sequential add"
  pass=$((pass + 1))
else
  echo "  FAIL  X3d: lint failed after sequential add (rc=$lint_rc)"
  echo "    output: $lint_out"
  fail=$((fail + 1))
fi

# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "RESULT pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
