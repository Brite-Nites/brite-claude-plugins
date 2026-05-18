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
# Scenarios (anchored substrings include the `where:` qualifier where useful,
# to prevent cross-scenario substring overlap from masking regressions):
#
#   A  happy path                                                   expect 0
#   B  vertical missing required `display`                          expect 1
#   C  unknown top-level key                                        expect 1
#   D  unknown offer key                                            expect 1
#   E  bad offer.status enum                                        expect 1
#   F  bad offer.posture enum                                       expect 1
#   G  non-kebab persona slug                                       expect 1
#   H  duplicate persona slug within a vertical                     expect 1
#   I  target_personas references undefined persona                 expect 1
#   J  target_personas item is not kebab-case                       expect 1
#   K  _manifest.yaml verticals[] not alphabetized                  expect 1
#   L  manifest entry has no matching {slug}.yaml file              expect 1
#   M  alias collides with another vertical's canonical slug        expect 1
#   N  _manifest.yaml schema_version != linter SCHEMA_VERSION       expect 1
#   O  tab character in indent                                      expect 1
#   P  bad offer.target_postures enum                               expect 1
#   Q  replaced_by orphan reference                                 expect 1
#   R  alias collides with another vertical's alias                 expect 1
#   S  duplicate offer slug within a vertical                       expect 1
#   T  filename stem does not match inner slug                      expect 1
#   U  cycle in replaced_by chain                                   expect 1
#   V  self-reference on replaced_by                                expect 1
#   W  empty display string                                         expect 1
#   X  duplicate alias within a single file                         expect 1
#   Y  non-kebab offer slug                                         expect 1
#   Z  empty status scalar (TypeError-prevention guard)              expect 1
#   AA duplicate top-level key                                       expect 1
#   AB duplicate key in list item                                    expect 1
#   AC sibling block-list keys on one offer (happy path)             expect 0
#   AD target_postures duplicate item                                expect 1
#   AE unterminated inline list bracket                              expect 1
#   AF cycle in iterates_from chain                                  expect 1
#   AG 3-node cycle emits exactly one error message (dedup)          expect 1
#   AH symlink rejected from canonicals dir (isolated)               expect 1
#   AI iterates_from self-reference (symmetric to V)                 expect 1
#   AJ target_personas duplicate item (symmetric to AD)              expect 1
#   AK file present but absent from manifest (symmetric to L)        expect 1
#   AL empty manifest verticals[]                                    expect 1
#   AM --canonicals-dir /nonexistent                                 expect 2
#   AN missing _manifest.yaml in canonicals dir                      expect 2
#   AO schema_version: true (bool/int subclass gotcha)               expect 1
#   AP editor swap dotfile silently skipped                          expect 0
#   AQ UTF-8 BOM tolerated (utf-8-sig)                               expect 0
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

invoke_lint() {
  local dir="$1"
  LAST_OUTPUT="$(python3 "$LINT" --canonicals-dir "$dir" 2>&1)"
  LAST_RC=$?
}

# ── Fixture builders ─────────────────────────────────────────────────────

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
  invoke_lint "$dir"
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
  invoke_lint "$dir"
  assert_exit_and_substring "B: missing required display" 1 "alpha.yaml: missing required key 'display'"
}

# ── Scenario C: unknown top-level key ────────────────────────────────────
run_c() {
  local dir
  dir="$(mkdir_scenario C)"
  cat >> "$dir/alpha.yaml" <<'YAML'
rogue_key: "should be rejected"
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "C: unknown top-level key" 1 "alpha.yaml: unknown key 'rogue_key'"
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
  invoke_lint "$dir"
  assert_exit_and_substring "D: unknown offer key" 1 "offers\\[0\\]: unknown key 'rogue_offer_key'"
}

# ── Scenario E: bad status enum ──────────────────────────────────────────
run_e() {
  local dir
  dir="$(mkdir_scenario E)"
  sed -i.bak "s/status: active/status: pending/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  invoke_lint "$dir"
  assert_exit_and_substring "E: bad status enum" 1 "offers\\[0\\]: status 'pending'"
}

# ── Scenario F: bad posture enum ─────────────────────────────────────────
run_f() {
  local dir
  dir="$(mkdir_scenario F)"
  sed -i.bak "s/posture: free-asset/posture: unknown-posture/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  invoke_lint "$dir"
  assert_exit_and_substring "F: bad posture enum" 1 "offers\\[0\\]: posture 'unknown-posture'"
}

# ── Scenario G: non-kebab persona slug ───────────────────────────────────
run_g() {
  local dir
  dir="$(mkdir_scenario G)"
  sed -i.bak "s/slug: persona-one/slug: personaOne/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  invoke_lint "$dir"
  assert_exit_and_substring "G: non-kebab persona slug" 1 "personas\\[0\\]: slug 'personaOne' is not kebab-case"
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
  invoke_lint "$dir"
  assert_exit_and_substring "H: duplicate persona slug" 1 "alpha.yaml: duplicate persona slug 'dup'"
}

# ── Scenario I: target_personas references undefined persona ─────────────
run_i() {
  local dir
  dir="$(mkdir_scenario I)"
  sed -i.bak "s/target_personas: \[persona-one\]/target_personas: [orphan-persona]/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  invoke_lint "$dir"
  assert_exit_and_substring "I: target_personas orphan ref" 1 "target_personas\\[0\\] 'orphan-persona' not defined in personas"
}

# ── Scenario J: target_personas item is not kebab-case ───────────────────
run_j() {
  local dir
  dir="$(mkdir_scenario J)"
  sed -i.bak "s/target_personas: \[persona-one\]/target_personas: [NotKebabCase]/" "$dir/alpha.yaml"
  rm -f "$dir/alpha.yaml.bak"
  invoke_lint "$dir"
  assert_exit_and_substring "J: target_personas non-kebab item" 1 "target_personas\\[0\\] 'NotKebabCase' is not kebab-case"
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
  invoke_lint "$dir"
  assert_exit_and_substring "K: manifest not alphabetized" 1 "_manifest.yaml: verticals\\[\\] not alphabetized"
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
  invoke_lint "$dir"
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
  invoke_lint "$dir"
  assert_exit_and_substring "M: alias collides with canonical" 1 "alpha.yaml: alias 'bravo' collides with canonical vertical slug"
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
  invoke_lint "$dir"
  assert_exit_and_substring "N: schema_version mismatch" 1 "_manifest.yaml: schema_version 99"
}

# ── Scenario O: tabs in indent ───────────────────────────────────────────
run_o() {
  local dir
  dir="$(mkdir_scenario O)"
  printf 'slug: alpha\ndisplay: "Alpha"\npersonas:\n\t- slug: persona-one\n\t  display: "Persona One"\n\t  titles:\n\t    - "Title One"\noffers: []\n' > "$dir/alpha.yaml"
  invoke_lint "$dir"
  assert_exit_and_substring "O: tabs in indent" 1 "tabs not allowed in indent"
}

# ── Scenario P: bad target_postures enum ─────────────────────────────────
run_p() {
  local dir
  dir="$(mkdir_scenario P)"
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
    target_postures: [bogus-posture]
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "P: bad target_postures enum" 1 "target_postures\\[0\\] 'bogus-posture' not in"
}

# ── Scenario Q: replaced_by orphan reference ─────────────────────────────
run_q() {
  local dir
  dir="$(mkdir_scenario Q)"
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
    replaced_by: nonexistent-offer
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "Q: replaced_by orphan ref" 1 "offers\\[0\\]: replaced_by 'nonexistent-offer' not defined in offers\\[\\]"
}

# ── Scenario R: alias collides with another vertical's alias ─────────────
run_r() {
  local dir
  dir="$(mkdir_scenario R)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
aliases:
  - shared-alias
personas: []
offers: []
YAML
  cat > "$dir/bravo.yaml" <<'YAML'
slug: bravo
display: "Bravo"
aliases:
  - shared-alias
personas: []
offers: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "R: alias-alias collision across verticals" 1 "alias 'shared-alias' already owned by alpha.yaml"
}

# ── Scenario S: duplicate offer slug within vertical ─────────────────────
run_s() {
  local dir
  dir="$(mkdir_scenario S)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-dup
    display: "Offer A"
    status: active
    posture: free-asset
  - slug: offer-dup
    display: "Offer B"
    status: active
    posture: knowledge
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "S: duplicate offer slug" 1 "alpha.yaml: duplicate offer slug 'offer-dup'"
}

# ── Scenario T: filename stem does not match inner slug ──────────────────
run_t() {
  local dir
  dir="$(mkdir_scenario T)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: not-alpha
display: "Not Alpha"
personas: []
offers: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "T: filename stem mismatch" 1 "alpha.yaml: filename stem 'alpha' does not match slug 'not-alpha'"
}

# ── Scenario U: cycle in replaced_by chain ───────────────────────────────
run_u() {
  local dir
  dir="$(mkdir_scenario U)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-a
    display: "Offer A"
    status: active
    posture: free-asset
    replaced_by: offer-b
  - slug: offer-b
    display: "Offer B"
    status: active
    posture: free-asset
    replaced_by: offer-a
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "U: cycle in replaced_by chain" 1 "alpha.yaml: cycle in replaced_by chain"
}

# ── Scenario V: self-reference on replaced_by ────────────────────────────
run_v() {
  local dir
  dir="$(mkdir_scenario V)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-self
    display: "Self-Replacer"
    status: active
    posture: free-asset
    replaced_by: offer-self
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "V: self-reference on replaced_by" 1 "replaced_by 'offer-self' is a self-reference"
}

# ── Scenario W: empty display string ─────────────────────────────────────
run_w() {
  local dir
  dir="$(mkdir_scenario W)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: ""
personas: []
offers: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "W: empty display string" 1 "alpha.yaml: display must be a non-empty string"
}

# ── Scenario X: duplicate alias within a single file ─────────────────────
run_x() {
  local dir
  dir="$(mkdir_scenario X)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
aliases:
  - dup-alias
  - dup-alias
personas: []
offers: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "X: duplicate alias within file" 1 "alpha.yaml: duplicate alias 'dup-alias' within file"
}

# ── Scenario Y: non-kebab offer slug ─────────────────────────────────────
run_y() {
  local dir
  dir="$(mkdir_scenario Y)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: BadOfferSlug
    display: "Bad Offer Slug"
    status: active
    posture: free-asset
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "Y: non-kebab offer slug" 1 "offers\\[0\\]: slug 'BadOfferSlug' is not kebab-case"
}

# ── Scenario Z: empty status scalar (TypeError-prevention) ──────────────
run_z() {
  local dir
  dir="$(mkdir_scenario Z)"
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
    status:
    posture: free-asset
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "Z: empty status scalar" 1 "offers\\[0\\]: status must be a string"
}

# ── Scenario AA: duplicate top-level key ─────────────────────────────────
run_aa() {
  local dir
  dir="$(mkdir_scenario AA)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "First"
display: "Second"
personas: []
offers: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AA: duplicate top-level key" 1 "duplicate top-level key 'display'"
}

# ── Scenario AB: duplicate key in list item ──────────────────────────────
run_ab() {
  local dir
  dir="$(mkdir_scenario AB)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    display: "Persona One Repeat"
    titles:
      - "Title One"
offers: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AB: duplicate key in list item" 1 "duplicate key 'display' in list item"
}

# ── Scenario AC: sibling block-list keys (happy path) ────────────────────
run_ac() {
  local dir
  dir="$(mkdir_scenario AC)"
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
    target_personas:
      - persona-one
    target_postures:
      - free-asset
      - knowledge
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AC: sibling block-list keys" 0 "Canonicals lint OK"
}

# ── Scenario AD: target_postures duplicate ───────────────────────────────
run_ad() {
  local dir
  dir="$(mkdir_scenario AD)"
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
    target_postures: [knowledge, knowledge]
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AD: target_postures duplicate" 1 "target_postures\\[1\\] 'knowledge' duplicated in same offer"
}

# ── Scenario AE: unterminated inline list bracket ────────────────────────
run_ae() {
  local dir
  dir="$(mkdir_scenario AE)"
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
    target_personas: [persona-one
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AE: unterminated inline list" 1 "unterminated inline list bracket"
}

# ── Scenario AF: cycle in iterates_from ──────────────────────────────────
run_af() {
  local dir
  dir="$(mkdir_scenario AF)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-a
    display: "Offer A"
    status: active
    posture: free-asset
    iterates_from: offer-b
  - slug: offer-b
    display: "Offer B"
    status: active
    posture: free-asset
    iterates_from: offer-a
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AF: cycle in iterates_from" 1 "cycle in iterates_from chain"
}

# ── Scenario AG: 3-node cycle emits ONE message (dedup verification) ─────
run_ag() {
  local dir
  dir="$(mkdir_scenario AG)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-a
    display: "A"
    status: active
    posture: free-asset
    replaced_by: offer-b
  - slug: offer-b
    display: "B"
    status: active
    posture: free-asset
    replaced_by: offer-c
  - slug: offer-c
    display: "C"
    status: active
    posture: free-asset
    replaced_by: offer-a
YAML
  invoke_lint "$dir"
  # Exactly one cycle line should appear; assert single occurrence.
  local cycle_count
  cycle_count=$(printf '%s' "$LAST_OUTPUT" | grep -cE "cycle in replaced_by chain")
  if [ "$LAST_RC" -eq 1 ] && [ "$cycle_count" -eq 1 ]; then
    echo "  PASS  AG: 3-node cycle dedup (exit=$LAST_RC, 1 cycle msg)"
    pass=$((pass + 1))
  else
    echo "  FAIL  AG: 3-node cycle dedup — exit=$LAST_RC cycle_count=$cycle_count"
    echo "    output: $LAST_OUTPUT"
    fail=$((fail + 1))
  fi
}

# ── Scenario AH: symlink rejected (isolated — no other failures) ─────────
run_ah() {
  local dir
  dir="$(mkdir_scenario AH)"
  # Add a symlink at a slug NOT in the manifest; lint should reject the
  # symlink without coupling to a manifest-missing-file error.
  ln -sf alpha.yaml "$dir/rogue.yaml"
  invoke_lint "$dir"
  assert_exit_and_substring "AH: symlink rejection (isolated)" 1 "rogue.yaml: symlinks not allowed in canonicals dir"
}

# ── Scenario AI: iterates_from self-reference (symmetric to V) ───────────
run_ai() {
  local dir
  dir="$(mkdir_scenario AI)"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas:
  - slug: persona-one
    display: "Persona One"
    titles:
      - "Title One"
offers:
  - slug: offer-self
    display: "Self-Iterator"
    status: active
    posture: free-asset
    iterates_from: offer-self
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AI: self-reference on iterates_from" 1 "iterates_from 'offer-self' is a self-reference"
}

# ── Scenario AJ: target_personas duplicate item (symmetric to AD) ────────
run_aj() {
  local dir
  dir="$(mkdir_scenario AJ)"
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
    target_personas: [persona-one, persona-one]
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AJ: target_personas duplicate" 1 "target_personas\\[1\\] 'persona-one' duplicated in same offer"
}

# ── Scenario AK: file present but not in manifest (symmetric to L) ───────
run_ak() {
  local dir
  dir="$(mkdir_scenario AK)"
  # Drop bravo from manifest while leaving bravo.yaml on disk.
  cat > "$dir/_manifest.yaml" <<'YAML'
schema_version: 1
verticals:
  - alpha
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AK: file without manifest entry" 1 "file bravo.yaml present but 'bravo' not in manifest"
}

# ── Scenario AL: empty manifest verticals[] ──────────────────────────────
run_al() {
  local dir
  dir="$(mkdir_scenario AL)"
  rm "$dir/alpha.yaml" "$dir/bravo.yaml"
  cat > "$dir/_manifest.yaml" <<'YAML'
schema_version: 1
verticals: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AL: empty verticals[]" 1 "verticals\\[\\] is empty"
}

# ── Scenario AM: --canonicals-dir /nonexistent (exit 2) ──────────────────
run_am() {
  local nonexistent="$tmproot/AM-does-not-exist"
  invoke_lint "$nonexistent"
  assert_exit_and_substring "AM: nonexistent canonicals dir (exit 2)" 2 "canonicals dir not found"
}

# ── Scenario AN: missing _manifest.yaml (exit 2) ─────────────────────────
run_an() {
  local dir="$tmproot/AN"
  mkdir -p "$dir"
  cat > "$dir/alpha.yaml" <<'YAML'
slug: alpha
display: "Alpha"
personas: []
offers: []
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AN: missing _manifest.yaml (exit 2)" 2 "missing _manifest.yaml"
}

# ── Scenario AO: schema_version: true (bool/int gotcha) ──────────────────
run_ao() {
  local dir
  dir="$(mkdir_scenario AO)"
  cat > "$dir/_manifest.yaml" <<'YAML'
schema_version: true
verticals:
  - alpha
  - bravo
YAML
  invoke_lint "$dir"
  assert_exit_and_substring "AO: schema_version: true rejected" 1 "schema_version must be an integer"
}

# ── Scenario AP: dotfile (e.g., editor swap) skipped, not treated as vertical ──
run_ap() {
  local dir
  dir="$(mkdir_scenario AP)"
  # Editor swap file ending in .yaml. Should be silently skipped, not surfaced
  # as a manifest-missing-file error. Happy path expected.
  printf 'slug: rogue\ndisplay: "Rogue"\npersonas: []\noffers: []\n' > "$dir/.editor.yaml"
  invoke_lint "$dir"
  assert_exit_and_substring "AP: dotfile skipped" 0 "Canonicals lint OK"
}

# ── Scenario AQ: UTF-8 BOM tolerated ─────────────────────────────────────
run_aq() {
  local dir
  dir="$(mkdir_scenario AQ)"
  # Re-write alpha.yaml with a leading UTF-8 BOM and verify lint stays clean.
  {
    printf '\xef\xbb\xbf'
    cat <<'YAML'
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
  } > "$dir/alpha.yaml"
  invoke_lint "$dir"
  assert_exit_and_substring "AQ: UTF-8 BOM tolerated" 0 "Canonicals lint OK"
}

# ── Run all scenarios ────────────────────────────────────────────────────
# Discover every `run_*` function and invoke in name order. Adding a new
# scenario only requires defining a `run_<letter>` function — no second
# invocation list to keep in sync.
scenarios=()
while IFS= read -r fn; do
  scenarios+=("$fn")
done < <(compgen -A function | grep '^run_[a-z]' | sort)

echo ""
echo "Running lint_canonicals.py regression harness (${#scenarios[@]} scenarios)..."
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
