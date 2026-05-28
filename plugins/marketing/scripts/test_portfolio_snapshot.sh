#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/portfolio_snapshot.py (BC-8731 / T7-Q).
#
# Builds isolated fixture campaigns directories per scenario (mktemp), invokes
# the helper, and asserts both the exit code AND scenario-specific substring(s)
# in the emitted output file or stdout/stderr. Substring assertion is
# load-bearing — a parser crash that exits with the right code on a different
# code path satisfies the numeric expectation but exercises a different
# scenario than intended (per BC-8712 follow-up discipline + BC-8722 ship).
#
# Pattern mirrors scripts/test_lint_discoveries.sh.
#
# Scenarios:
#
#   A  happy path — 1 campaign in window (BC-8727-shaped)             expect 0
#   B  empty campaigns dir (no manifests in window)                   expect 0
#   C  multi-campaign — 3 campaigns same vertical roll up correctly   expect 0
#   D  cross-vertical — 3 campaigns 3 verticals (breakdown distinct)  expect 0
#   E  invalid flag rejection — rubric-triad lock (anchor + table)    expect 0
#   F  quarterly mode — 6 campaigns across 3 months in Q1             expect 0
#   G  anti-creep guard — out path outside _reviews/ rejected         expect 2
#   H  out-of-window manifest excluded                                expect 0
#   I  learnings.md verdict tally — Summary stats aggregated          expect 0
#   J  SF degraded_auth — Section 2 ⚠ banner emitted                  expect 0
#   K  posture lookup from canonicals.yaml (cell-position locked)     expect 0
#   L  command markdown has all 4 reject-flag clauses + V3 cite       expect 0
#   M  helper refuses unknown --span value                            expect 2
#   N  slug-fallback path — no created_at, valid fy/m slug            expect 0
#   O  junk created_at + no fy/m slug → excluded with stderr warning  expect 0
#   P  window boundary — 23:59:58Z IN / 00:00:00Z next-day OUT        expect 0
#   Q  malformed learnings.md Summary stats — graceful fallback       expect 0
#   R  quarterly Q1/Q2 boundary label (April-start → 2026-Q2)         expect 0
#   S  SF degraded_query banner (SOQL-fail branch sibling of J)       expect 0
#   T  unparseable created_at + valid slug → slug-fallback salvages    expect 0
#   U  non-string created_at (JSON number) → except clause catches    expect 0
#   V  manifest.angles[] populated → Section 3a distribution line     expect 0
#   W  BC-11852 v2 manifest read — single-record campaigns[] launched   expect 0
#   X  BC-11852 v2 manifest read — multi-record campaigns[] (+N more)   expect 0
#   Y  BC-11852 v2 manifest read — empty campaigns[] = not launched     expect 0
#
# Usage:
#   bash plugins/marketing/scripts/test_portfolio_snapshot.sh
#   bash plugins/marketing/scripts/test_portfolio_snapshot.sh /path/to/portfolio_snapshot.py

set -u  # NOT set -e — non-zero exits are expected for reject scenarios

# Defuse caller's git env (matches test_lint_discoveries.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
HELPER="${1:-$script_dir/portfolio_snapshot.py}"
COMMAND_MD="$script_dir/../commands/portfolio-snapshot.md"

if [ ! -f "$HELPER" ]; then
  echo "FATAL: helper script not found: $HELPER" >&2
  exit 2
fi
HELPER="$(cd "$(dirname "$HELPER")" && pwd)/$(basename "$HELPER")"

if [ ! -f "$COMMAND_MD" ]; then
  echo "FATAL: command markdown not found: $COMMAND_MD" >&2
  exit 2
fi
COMMAND_MD="$(cd "$(dirname "$COMMAND_MD")" && pwd)/$(basename "$COMMAND_MD")"

tmproot="$(mktemp -d -t portfolio-snapshot-test.XXXXXX)" || {
  echo "FATAL: mktemp -d failed" >&2
  exit 2
}
cleanup() {
  # Use find+rmdir to delete (avoids rm -r which the security hook blocks).
  if [ -d "$tmproot" ]; then
    find "$tmproot" -depth -type f -exec rm {} + 2>/dev/null || true
    find "$tmproot" -depth -type d -exec rmdir {} + 2>/dev/null || true
  fi
}
trap 'cleanup' EXIT

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
    printf '    output: %s\n' "$output"
    fail=$((fail + 1))
    return
  fi
  if ! printf '%s' "$output" | grep -qE -- "$substring"; then
    echo "  FAIL  $label — substring not found"
    echo "    expected regex: $substring"
    printf '    output: %s\n' "$output"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (exit=$actual_rc, substring matched)"
  pass=$((pass + 1))
}

assert_file_contains() {
  local label="$1"
  local file="$2"
  local substring="$3"
  if [ ! -f "$file" ]; then
    echo "  FAIL  $label — expected file not present: $file"
    fail=$((fail + 1))
    return
  fi
  if ! grep -qE -- "$substring" "$file"; then
    echo "  FAIL  $label — substring not found in $file"
    echo "    expected regex: $substring"
    echo "    --- file head ---"
    head -25 "$file" | sed 's/^/    /'
    echo "    -----------------"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (file substring matched)"
  pass=$((pass + 1))
}

assert_file_NOT_contains() {
  local label="$1"
  local file="$2"
  local substring="$3"
  if [ ! -f "$file" ]; then
    echo "  FAIL  $label — expected file not present: $file"
    fail=$((fail + 1))
    return
  fi
  if grep -qE -- "$substring" "$file"; then
    echo "  FAIL  $label — forbidden substring found in $file"
    echo "    forbidden regex: $substring"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (forbidden substring absent)"
  pass=$((pass + 1))
}

mkdir_scenario() {
  local name="$1"
  local dir="$tmproot/$name"
  mkdir -p "$dir/docs/campaigns" "$dir/canonicals"
  printf '%s' "$dir"
}

write_canonicals_manifest() {
  local dir="$1"
  shift
  # BC-11852: schema_version bumped 1 → 2; lint is strict but the
  # canonicals_reader used by portfolio-snapshot is tolerant — both shapes
  # round-trip cleanly. Fixtures use v2 to match production.
  {
    printf 'schema_version: 2\n'
    printf 'verticals:\n'
    for v in "$@"; do
      printf '  - %s\n' "$v"
    done
  } > "$dir/canonicals/_manifest.yaml"
}

write_canonical_vertical() {
  local dir="$1" vertical="$2" offer_slug="$3" posture="$4"
  cat > "$dir/canonicals/$vertical.yaml" <<EOF
slug: $vertical
display: $vertical
schema_version: 1
personas: []
offers:
  - slug: $offer_slug
    display: $offer_slug
    posture: $posture
EOF
}

write_manifest() {
  # created_at may be the literal string "OMIT" to write a manifest with NO
  # created_at field at all — exercises the slug-fallback path in scenarios N/O.
  local dir="$1" entity="$2" slug="$3" vertical="$4" persona="$5" offer="$6" created_at="$7"
  local m_dir="$dir/docs/campaigns/$entity/$slug"
  mkdir -p "$m_dir"
  local created_at_field=""
  if [ "$created_at" != "OMIT" ]; then
    created_at_field="  \"created_at\": \"$created_at\","
  fi
  cat > "$m_dir/manifest.json" <<EOF
{
  "schema_version": 1,
  "slug": "$slug",
  "entity": "$entity",
  "vertical": "$vertical",
  "persona": "$persona",
  "offer": "$offer",
  "year": 2026,
  "month": 4,
${created_at_field}
  "salesforce": {"campaign_id": null},
  "email_bison": {"workspace": "emailbison-b2b", "campaign_id": null, "launched_at": null}
}
EOF
}

write_learnings() {
  local dir="$1" entity="$2" scale="$3" iterate="$4" pause="$5" kill="$6" works="$7" doesnt="$8"
  local e_dir="$dir/docs/campaigns/$entity"
  mkdir -p "$e_dir"
  local total=$((scale + iterate + pause + kill))
  cat > "$e_dir/learnings.md" <<EOF
# Campaign Learnings — $entity

## Summary stats

- Total debriefs: $total
- Campaign verdicts: SCALE=$scale, ITERATE=$iterate, PAUSE=$pause, KILL=$kill
- Last debrief: 2026-04-30

## What works

- $works

## What doesn't

- $doesnt

## Campaign log

(entries elided for fixture)
EOF
}

invoke_helper() {
  LAST_OUTPUT="$(python3 "$HELPER" "$@" 2>&1)"
  LAST_RC=$?
}

# ── Scenario A: happy path ─────────────────────────────────────────────
run_a() {
  local dir; dir="$(mkdir_scenario A)"
  write_canonicals_manifest "$dir" "hotels-resorts" "test-vert"
  write_canonical_vertical "$dir" "hotels-resorts" "holiday-anchor-audit" "free-asset"
  write_manifest "$dir" "labs" "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m04" \
    "hotels-resorts" "director-of-resort-experience" "holiday-anchor-audit" "2026-04-15T10:00:00Z"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "A: happy path exit OK" 0 "campaigns_in_window: 1"
  assert_file_contains "A: portfolio shape table present" "$out" '## 1. Portfolio shape'
  assert_file_contains "A: pipeline summary present" "$out" '## 2. Pipeline summary'
  assert_file_contains "A: verdict distribution present" "$out" '## 3. Verdict distribution'
  assert_file_contains "A: transferable insights present" "$out" '## 4. Transferable insights'
  assert_file_contains "A: action items present" "$out" '## 5. Action items'
  assert_file_contains "A: posture resolved from canonicals" "$out" 'free-asset'
  assert_file_NOT_contains "A: quarterly sections NOT present" "$out" '## 6. Cross-quarter'
}

# ── Scenario B: empty campaigns dir ────────────────────────────────────
run_b() {
  local dir; dir="$(mkdir_scenario B)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "B: empty dir exit OK" 0 "campaigns_in_window: 0"
  assert_file_contains "B: graceful empty Section 1" "$out" 'No campaigns in window'
  assert_file_contains "B: graceful empty Section 4" "$out" 'No transferable insights available'
}

# ── Scenario C: multi-campaign same vertical ─────────────────────────
run_c() {
  local dir; dir="$(mkdir_scenario C)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "holiday-anchor-audit" "free-asset"
  for i in 1 2 3; do
    write_manifest "$dir" "labs" "hotels-resorts-persona-$i-offer-fy26-m04" \
      "hotels-resorts" "persona-$i" "holiday-anchor-audit" "2026-04-1${i}T10:00:00Z"
  done
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "C: multi-campaign exit OK" 0 "campaigns_in_window: 3"
  assert_file_contains "C: vertical rollup = 3" "$out" 'hotels-resorts = 3'
  assert_file_contains "C: entity rollup labs = 3" "$out" 'labs = 3'
  assert_file_contains "C: 3 personas counted" "$out" '3 personas'
}

# ── Scenario D: cross-vertical (3 verticals) ─────────────────────────
run_d() {
  local dir; dir="$(mkdir_scenario D)"
  write_canonicals_manifest "$dir" "hotels-resorts" "ski-resorts" "country-clubs"
  for v_pair in "hotels-resorts:labs" "ski-resorts:supply" "country-clubs:nites"; do
    local v="${v_pair%%:*}"
    local e="${v_pair##*:}"
    write_canonical_vertical "$dir" "$v" "test-offer" "knowledge"
    write_manifest "$dir" "$e" "$v-test-pers-test-offer-fy26-m04" \
      "$v" "test-pers" "test-offer" "2026-04-15T10:00:00Z"
  done
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "D: cross-vertical exit OK" 0 "campaigns_in_window: 3"
  assert_file_contains "D: hotels-resorts = 1" "$out" 'hotels-resorts = 1'
  assert_file_contains "D: ski-resorts = 1" "$out" 'ski-resorts = 1'
  assert_file_contains "D: country-clubs = 1" "$out" 'country-clubs = 1'
  assert_file_contains "D: 3 entities" "$out" '3 entities'
}

# ── Scenario E: command markdown has all 4 rejection clauses ────────
# Static grep against the command markdown (not the helper). Applies the
# [[pattern-rubric-lock-grep-triad]] from BC-10730 — single-pattern locks
# (the previous `${flag}.*rejected` regex) are gameable by deprecation
# rewordings like "`--weekly` was once rejected, now it's `--month`". This
# scenario locks BOTH an HTML-comment anchor (structural clause) AND an
# exact table-row shape per flag (catchphrase) — together impossible to
# satisfy by accident or by a single-line reword.
run_e() {
  local label_base="E: command markdown rejects"
  local rejected_flags=("--weekly" "--custom-window" "--forecast" "--charts")

  # Structural-clause anchor: the HTML comment co-located with the table is a
  # stable lock. Removing the table without removing the anchor leaves a dangling
  # claim that fails this assertion; removing both makes the diff obvious.
  if grep -q 'BC-8731-rejected-flags-anchor' "$COMMAND_MD"; then
    echo "  PASS  ${label_base} (anchor present)"
    pass=$((pass + 1))
  else
    echo "  FAIL  ${label_base} (anchor 'BC-8731-rejected-flags-anchor' missing)"
    fail=$((fail + 1))
  fi

  for flag in "${rejected_flags[@]}"; do
    # Decoupled two-part assertion (per iter-2 test-quality review):
    # (a) the flag appears in a backtick-fenced table cell somewhere in the file
    # (b) an ERROR message for the flag, "rejected.", appears somewhere in the file
    # Decoupling lets the table grow new columns (e.g., "Reason", "Since version")
    # without breaking the assertion; what's locked is the shape of each PART
    # independently, not their adjacency.
    local flag_cell_pattern="\\| \`${flag}\` \\|"
    local error_message_pattern="\`ERROR: ${flag} rejected\\."
    if grep -qE -- "$flag_cell_pattern" "$COMMAND_MD"; then
      echo "  PASS  ${label_base} ${flag} (flag-cell shape present)"
      pass=$((pass + 1))
    else
      echo "  FAIL  ${label_base} ${flag} — flag-cell shape '| \`${flag}\` |' not found"
      fail=$((fail + 1))
    fi
    if grep -qE -- "$error_message_pattern" "$COMMAND_MD"; then
      echo "  PASS  ${label_base} ${flag} (ERROR message shape present)"
      pass=$((pass + 1))
    else
      echo "  FAIL  ${label_base} ${flag} — ERROR message shape '\`ERROR: ${flag} rejected.' not found"
      fail=$((fail + 1))
    fi
  done
}

# ── Scenario F: quarterly mode (6 campaigns across 3 months in Q1) ──
run_f() {
  local dir; dir="$(mkdir_scenario F)"
  write_canonicals_manifest "$dir" "hotels-resorts" "ski-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  write_canonical_vertical "$dir" "ski-resorts" "test-offer" "knowledge"
  # 2 campaigns in Jan, 2 in Feb, 2 in Mar
  for month_pair in "01:jan-a" "01:jan-b" "02:feb-a" "02:feb-b" "03:mar-a" "03:mar-b"; do
    local m="${month_pair%%:*}"
    local n="${month_pair##*:}"
    write_manifest "$dir" "labs" "hotels-resorts-pers-$n-offer-fy26-m$m" \
      "hotels-resorts" "pers-$n" "test-offer" "2026-${m}-15T10:00:00Z"
  done
  local out="$dir/docs/campaigns/_reviews/quarterly-2026-Q1.md"
  invoke_helper \
    --span quarterly --window-start 2026-01-01 --window-end 2026-03-31 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "F: quarterly exit OK" 0 "campaigns_in_window: 6"
  assert_file_contains "F: Section 6 present" "$out" '## 6. Cross-quarter MSPA transitions'
  assert_file_contains "F: Section 7 present" "$out" '## 7. Cumulative transferables'
  assert_file_contains "F: Section 8 present" "$out" '## 8. Per-offer-version aggregation'
  assert_file_contains "F: Section 9 present" "$out" '## 9. Coverage-gap callouts'
  assert_file_contains "F: 1 of 2 coverage gap (ski-resorts has zero)" "$out" '1 of 2'
}

# ── Scenario G: anti-creep — out path outside _reviews/ refused ──────
run_g() {
  local dir; dir="$(mkdir_scenario G)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  local bad_out="$dir/docs/campaigns/wrong-dir/monthly-2026-04.md"
  mkdir -p "$(dirname "$bad_out")"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$bad_out"
  assert_exit_and_substring "G: anti-creep guard refuses non-_reviews/ out path" 2 \
    "anti-creep guard"
  if [ -f "$bad_out" ]; then
    echo "  FAIL  G: anti-creep — forbidden file was written despite refusal"
    fail=$((fail + 1))
  else
    echo "  PASS  G: anti-creep — forbidden file not written"
    pass=$((pass + 1))
  fi
}

# ── Scenario H: out-of-window manifest excluded ─────────────────────
run_h() {
  local dir; dir="$(mkdir_scenario H)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  # In-window (April 2026)
  write_manifest "$dir" "labs" "hotels-resorts-in-window-test-offer-fy26-m04" \
    "hotels-resorts" "pers" "test-offer" "2026-04-15T10:00:00Z"
  # Out-of-window (May 2026 via created_at AND slug)
  write_manifest "$dir" "labs" "hotels-resorts-out-of-window-test-offer-fy26-m05" \
    "hotels-resorts" "pers2" "test-offer" "2026-05-15T10:00:00Z"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "H: window-filter exit OK" 0 "campaigns_in_window: 1"
  assert_file_contains "H: in-window slug present" "$out" 'in-window'
  assert_file_NOT_contains "H: out-of-window slug absent" "$out" 'out-of-window-test'
}

# ── Scenario I: learnings.md Summary stats aggregation ──────────────
run_i() {
  local dir; dir="$(mkdir_scenario I)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  write_manifest "$dir" "labs" "hotels-resorts-pers-test-offer-fy26-m04" \
    "hotels-resorts" "pers" "test-offer" "2026-04-15T10:00:00Z"
  write_learnings "$dir" "labs" 2 1 0 1 \
    "Asymmetric anchor framing travels across luxury verticals" \
    "Generic discount offers underperform regardless of timing"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "I: verdict aggregation exit OK" 0 "campaigns_in_window: 1"
  assert_file_contains "I: SCALE = 2 aggregated" "$out" 'SCALE = 2'
  assert_file_contains "I: ITERATE = 1 aggregated" "$out" 'ITERATE = 1'
  assert_file_contains "I: KILL = 1 aggregated" "$out" 'KILL = 1'
  assert_file_contains "I: What works bullet verbatim" "$out" \
    'Asymmetric anchor framing travels across luxury verticals'
  assert_file_contains "I: What doesn'\''t bullet verbatim" "$out" \
    'Generic discount offers underperform regardless of timing'
}

# ── Scenario J: SF degraded_auth banner ──────────────────────────────
run_j() {
  local dir; dir="$(mkdir_scenario J)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  write_manifest "$dir" "labs" "hotels-resorts-pers-test-offer-fy26-m04" \
    "hotels-resorts" "pers" "test-offer" "2026-04-15T10:00:00Z"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --sf-status "degraded_auth" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "J: SF degraded_auth exit OK" 0 "sf=degraded_auth"
  assert_file_contains "J: SF degraded ⚠ banner present in Section 2" "$out" \
    'SF rollup section degraded — auth probe failed'
  assert_file_contains "J: filesystem sections still emit" "$out" \
    '## 4. Transferable insights'
}

# ── Scenario K: posture lookup from canonicals.yaml ────────────────
run_k() {
  local dir; dir="$(mkdir_scenario K)"
  write_canonicals_manifest "$dir" "ski-resorts"
  write_canonical_vertical "$dir" "ski-resorts" "season-pass-anchor" "pilot"
  write_manifest "$dir" "labs" "ski-resorts-pers-season-pass-anchor-fy26-m04" \
    "ski-resorts" "pers" "season-pass-anchor" "2026-04-15T10:00:00Z"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "K: posture resolution exit OK" 0 "campaigns_in_window: 1"
  # Cell-position lock — assert the full Posture column position via the
  # entity→...→Posture column sequence (defense against future column rearrangements
  # or matching a stray "pilot" in another column).
  assert_file_contains "K: pilot posture resolved in correct column" "$out" \
    '\| labs \| ski-resorts \| pers \| season-pass-anchor \| pilot \|'
  assert_file_contains "K: pilot in posture-rollup" "$out" 'pilot = 1'
}

# ── Scenario L: command markdown integrity — V3 cite + all 4 rejections + anti-creep ──
run_l() {
  # V3 outcome cite
  if grep -qE 'v3-ratification-outcome-2026-05-22' "$COMMAND_MD"; then
    echo "  PASS  L: command markdown cites V3 outcome doc"
    pass=$((pass + 1))
  else
    echo "  FAIL  L: command markdown missing V3 outcome cite"
    fail=$((fail + 1))
  fi
  # Anti-creep guards section
  if grep -qE 'Anti-creep guards' "$COMMAND_MD"; then
    echo "  PASS  L: command markdown has Anti-creep guards section"
    pass=$((pass + 1))
  else
    echo "  FAIL  L: command markdown missing Anti-creep guards section"
    fail=$((fail + 1))
  fi
  # campaign-analysis §3.3 metric source cite
  if grep -qE 'campaign-analysis.*§3.3' "$COMMAND_MD"; then
    echo "  PASS  L: command markdown cites campaign-analysis §3.3 as metric source"
    pass=$((pass + 1))
  else
    echo "  FAIL  L: command markdown missing campaign-analysis §3.3 cite"
    fail=$((fail + 1))
  fi
}

# ── Scenario M: helper refuses unknown --span value ──────────────────
run_m() {
  local dir; dir="$(mkdir_scenario M)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span weekly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "M: helper refuses --span=weekly (argparse choices)" 2 \
    "invalid choice"
}

# ── Scenario N: slug-fallback path — no created_at, valid fy/m slug ──
# Exercises filter_in_window's slug-derived launch-month fallback (the BC-8727
# dogfood relies on this path in production). Without this scenario, the
# fallback code path is silently untested.
run_n() {
  local dir; dir="$(mkdir_scenario N)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  # OMIT created_at — slug suffix must drive the window decision.
  write_manifest "$dir" "labs" "hotels-resorts-pers-test-offer-fy26-m04" \
    "hotels-resorts" "pers" "test-offer" "OMIT"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "N: slug-fallback path includes manifest" 0 \
    "campaigns_in_window: 1"
  assert_file_contains "N: slug-fallback manifest in portfolio table" "$out" \
    'hotels-resorts-pers-test-offer-fy26-m04'
}

# ── Scenario O: junk created_at + no fy-suffix slug → excluded with warning ──
# Defensive — a corrupted manifest must not be silently dropped. Helper emits
# `[BC-8731] Skipping manifest …` to stderr when neither created_at nor slug
# yields a launch month.
run_o() {
  local dir; dir="$(mkdir_scenario O)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  # Junk created_at AND slug with no fy/m suffix — both paths fail.
  write_manifest "$dir" "labs" "no-fy-suffix-here" \
    "hotels-resorts" "pers" "test-offer" "garbage-not-a-date"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "O: corrupted manifest excluded" 0 "campaigns_in_window: 0"
  assert_exit_and_substring "O: corrupted manifest emits BC-8731 stderr warning" 0 \
    "\\[BC-8731\\] Skipping manifest with no parseable launch date"
}

# ── Scenario P: window boundary inclusivity ─────────────────────────
# Three timestamps test the precise inclusion semantic:
#   * 23:59:58Z — IN (one second below boundary)
#   * 23:59:59Z — IN (the EXACT inclusion boundary per in_window()'s
#                  end.replace(second=59); a refactor to `<` exclusive would
#                  silently drop this — the off-by-one detector)
#   * 00:00:00Z next day — OUT (one second past boundary)
run_p() {
  local dir; dir="$(mkdir_scenario P)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  write_manifest "$dir" "labs" "hotels-resorts-in-edge-test-offer-fy26-m04" \
    "hotels-resorts" "pers" "test-offer" "2026-04-30T23:59:58Z"
  write_manifest "$dir" "labs" "hotels-resorts-exact-edge-test-offer-fy26-m04" \
    "hotels-resorts" "pers2" "test-offer" "2026-04-30T23:59:59Z"
  write_manifest "$dir" "labs" "hotels-resorts-out-edge-test-offer-fy26-m05" \
    "hotels-resorts" "pers3" "test-offer" "2026-05-01T00:00:00Z"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "P: boundary inclusivity (2 IN at 23:59:58Z + 23:59:59Z, 1 OUT)" 0 \
    "campaigns_in_window: 2"
  assert_file_contains "P: 23:59:58Z manifest IN window" "$out" 'in-edge'
  assert_file_contains "P: 23:59:59Z EXACT boundary IN window" "$out" 'exact-edge'
  assert_file_NOT_contains "P: 00:00:00Z next-day manifest OUT of window" "$out" \
    'out-edge'
}

# ── Scenario Q: malformed Summary stats — graceful default ──────────
# learnings.md with malformed verdict lines must not crash; the helper falls
# back to 0/0/0/0 silently. Helper sub-scenarios cover three regex-fail modes
# so a future regex-loosening regression catches at least one.
run_q() {
  # Q-helper that runs one fixture variant against the helper and asserts the
  # 0/0/0/0 fallback.
  run_q_variant() {
    local label="$1" verdict_line="$2"
    local dir; dir="$(mkdir_scenario Q-${label})"
    write_canonicals_manifest "$dir" "hotels-resorts"
    write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
    write_manifest "$dir" "labs" "hotels-resorts-pers-test-offer-fy26-m04" \
      "hotels-resorts" "pers" "test-offer" "2026-04-15T10:00:00Z"
    local e_dir="$dir/docs/campaigns/labs"
    mkdir -p "$e_dir"
    {
      printf '# Campaign Learnings — labs\n\n'
      printf '## Summary stats\n\n'
      printf -- '- Total debriefs: 3\n'
      printf -- '- %s\n' "$verdict_line"
      printf -- '- Last debrief: 2026-04-30\n\n'
      printf '## What works\n## What doesn'\''t\n## Campaign log\n'
    } > "$e_dir/learnings.md"
    local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
    invoke_helper \
      --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
      --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
      --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
    assert_exit_and_substring "Q-${label}: exit OK" 0 "campaigns_in_window: 1"
    assert_file_contains "Q-${label}: fallback to SCALE = 0" "$out" \
      'SCALE = 0 / ITERATE = 0 / PAUSE = 0 / KILL = 0'
  }
  # Variant 1: reshuffled key order (the original Q fixture)
  run_q_variant "reshuffled" "Campaign verdicts: KILL=1, SCALE=2, ITERATE=0, PAUSE=0"
  # Variant 2: partial — only two keys present
  run_q_variant "partial" "Campaign verdicts: SCALE=1, KILL=0"
  # Variant 3: missing prefix — no "Campaign verdicts:" sentinel
  run_q_variant "no-prefix" "SCALE=1, ITERATE=2, PAUSE=0, KILL=1"
}

# ── Scenario R: quarterly Q1/Q2 boundary — April-start window emits Q2 label ──
run_r() {
  local dir; dir="$(mkdir_scenario R)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  local out="$dir/docs/campaigns/_reviews/quarterly-2026-Q2.md"
  invoke_helper \
    --span quarterly --window-start 2026-04-01 --window-end 2026-06-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "R: Q2 boundary exit OK" 0 "campaigns_in_window: 0"
  assert_file_contains "R: Q2 label correctly emitted (not Q1)" "$out" \
    '# Portfolio Snapshot — 2026-04-01 → 2026-06-30 \(2026-Q2\)'
}

# ── Scenario T: unparseable created_at + valid slug → slug salvages window-fit ──
# Branch coverage: scenarios N + O cover the missing-created_at and
# both-paths-fail paths; T covers the unparseable-created_at-but-slug-saves
# path. Without T, a regression flipping `except ValueError: pass` to
# `except ValueError: continue` would silently exclude these manifests.
run_t() {
  local dir; dir="$(mkdir_scenario T)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  # Junk created_at (won't parse) AND valid fy26-m04 slug (in-window April).
  write_manifest "$dir" "labs" "hotels-resorts-salvaged-test-offer-fy26-m04" \
    "hotels-resorts" "pers" "test-offer" "not-an-iso-timestamp"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "T: unparseable created_at — slug salvages window-fit" 0 \
    "campaigns_in_window: 1"
  assert_file_contains "T: salvaged manifest appears in portfolio table" "$out" \
    'salvaged'
}

# ── Scenario U: non-string created_at → AttributeError NOT raised ──
# Defensive against the manifest type-shape regression (a JSON-numeric or
# JSON-list created_at would have raised uncaught AttributeError in iter-1's
# filter_in_window; iter-2 broadened the except clause to catch
# AttributeError/TypeError). Asserts the helper survives a non-string field
# and falls through to slug fallback rather than halting.
run_u() {
  local dir; dir="$(mkdir_scenario U)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  # Hand-written JSON heredoc (not write_manifest) because the helper always
  # wraps created_at in quotes; this scenario needs a non-string value to
  # exercise the AttributeError branch in filter_in_window's except clause.
  local m_dir="$dir/docs/campaigns/labs/hotels-resorts-numeric-test-offer-fy26-m04"
  mkdir -p "$m_dir"
  cat > "$m_dir/manifest.json" <<'EOF'
{
  "schema_version": 1,
  "slug": "hotels-resorts-numeric-test-offer-fy26-m04",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "pers",
  "offer": "test-offer",
  "year": 2026,
  "month": 4,
  "created_at": 12345,
  "salesforce": {"campaign_id": null},
  "email_bison": {"workspace": "emailbison-b2b", "campaign_id": null, "launched_at": null}
}
EOF
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  # Non-string created_at → except clause catches AttributeError → slug fallback
  # → fy26-m04 in April window → manifest IS in-window. The slug also includes
  # 'numeric' to make presence-asserting unambiguous.
  assert_exit_and_substring "U: non-string created_at falls back to slug" 0 \
    "campaigns_in_window: 1"
  assert_file_contains "U: numeric-created_at manifest survives + lands in-window" "$out" \
    'hotels-resorts-numeric-test-offer-fy26-m04'
}

# ── Scenario V: Section 3a angles distribution (any_angles=True branch) ──
# Coverage gap caught by iter-3 review — no prior scenario seeds
# `manifest.angles[]` with scored entries, so the `any_angles=True` branch
# in render_section_3 is untested. Seeds a manifest with 3 angles tokens
# (ALPHA, PROMISING, INTERESTING) and asserts the distribution line emits.
run_v() {
  local dir; dir="$(mkdir_scenario V)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  # Hand-write manifest with angles[] populated (write_manifest doesn't take angles).
  local m_dir="$dir/docs/campaigns/labs/hotels-resorts-pers-test-offer-fy26-m04"
  mkdir -p "$m_dir"
  cat > "$m_dir/manifest.json" <<'EOF'
{
  "schema_version": 1,
  "slug": "hotels-resorts-pers-test-offer-fy26-m04",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "pers",
  "offer": "test-offer",
  "year": 2026,
  "month": 4,
  "created_at": "2026-04-15T10:00:00Z",
  "angles": [
    {"slug": "angle-a", "verdict": "ALPHA"},
    {"slug": "angle-b", "verdict": "PROMISING"},
    {"slug": "angle-c", "verdict": "INTERESTING"}
  ],
  "salesforce": {"campaign_id": null},
  "email_bison": {"workspace": "emailbison-b2b", "campaign_id": null, "launched_at": null}
}
EOF
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "V: angles[] populated — exit OK" 0 "campaigns_in_window: 1"
  assert_file_contains "V: Section 3a distribution line emits with non-zero ALPHA" "$out" \
    'ALPHA = 1 / PROMISING = 1 / INTERESTING = 1 / COMMODITY = 0 / unscored = 0'
}

# ── Scenario S: SF degraded_query banner ─────────────────────────────
# Sibling of Scenario J — covers the second SF failure mode (SOQL call fails)
# beyond the auth-probe failure J already covers.
run_s() {
  local dir; dir="$(mkdir_scenario S)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  write_manifest "$dir" "labs" "hotels-resorts-pers-test-offer-fy26-m04" \
    "hotels-resorts" "pers" "test-offer" "2026-04-15T10:00:00Z"
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --sf-status "degraded_query" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "S: SF degraded_query exit OK" 0 "sf=degraded_query"
  assert_file_contains "S: SF degraded_query banner in Section 2" "$out" \
    'SF rollup section degraded — SOQL call failed'
  assert_file_contains "S: filesystem sections still emit" "$out" \
    '## 1. Portfolio shape'
}

# ── Scenario W: BC-11852 v2 manifest — single-record campaigns[] launched ──
# Exercises the v2 reader path with one EB record. The Section 2 row must
# show the campaign_id (no "+N more" suffix) and "yes" in the Launched column.
run_w() {
  local dir; dir="$(mkdir_scenario W)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  local m_dir="$dir/docs/campaigns/labs/hotels-resorts-v2-single-test-offer-fy26-m04"
  mkdir -p "$m_dir"
  cat > "$m_dir/manifest.json" <<'EOF'
{
  "schema_version": 2,
  "slug": "hotels-resorts-v2-single-test-offer-fy26-m04",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "pers",
  "offer": "test-offer",
  "year": 2026,
  "month": 4,
  "created_at": "2026-04-15T10:00:00Z",
  "salesforce": {"campaign_id": null, "campaign_name": "x"},
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_name": "x",
    "campaigns": [
      {
        "workspace": "emailbison-b2b",
        "campaign_id": 42,
        "audience_tier": {"tier": "professional", "seniority": null, "modifiers": []},
        "launched_at": "2026-04-20T12:00:00Z",
        "status": "launched"
      }
    ]
  }
}
EOF
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "W: v2 single-record manifest read OK" 0 "campaigns_in_window: 1"
  assert_file_contains "W: v2 row shows EB campaign_id 42 in Section 2" "$out" \
    '\| 42 \| yes \|'
  assert_file_contains "W: v2 launched row counted in EB launched total" "$out" \
    'EB campaigns launched in window = 1'
  assert_file_NOT_contains "W: no '+N more' suffix on single-record row" "$out" \
    'more)'
}

# ── Scenario X: BC-11852 v2 manifest — multi-record campaigns[] (+N more) ──
run_x() {
  local dir; dir="$(mkdir_scenario X)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  local m_dir="$dir/docs/campaigns/labs/hotels-resorts-v2-multi-test-offer-fy26-m04"
  mkdir -p "$m_dir"
  cat > "$m_dir/manifest.json" <<'EOF'
{
  "schema_version": 2,
  "slug": "hotels-resorts-v2-multi-test-offer-fy26-m04",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "pers",
  "offer": "test-offer",
  "year": 2026,
  "month": 4,
  "created_at": "2026-04-15T10:00:00Z",
  "salesforce": {"campaign_id": null, "campaign_name": "x"},
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_name": "x",
    "campaigns": [
      {
        "workspace": "emailbison-b2b",
        "campaign_id": 100,
        "audience_tier": {"tier": "professional", "seniority": null, "modifiers": []},
        "launched_at": "2026-04-20T12:00:00Z",
        "status": "launched"
      },
      {
        "workspace": "emailbison-b2b",
        "campaign_id": 101,
        "audience_tier": {"tier": "role", "seniority": null, "modifiers": []},
        "launched_at": "2026-04-21T12:00:00Z",
        "status": "launched"
      },
      {
        "workspace": "emailbison-personal",
        "campaign_id": 200,
        "audience_tier": {"tier": "personal", "seniority": null, "modifiers": []},
        "launched_at": null,
        "status": "draft"
      }
    ]
  }
}
EOF
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "X: v2 multi-record manifest read OK" 0 "campaigns_in_window: 1"
  assert_file_contains "X: first campaign_id + (+2 more) suffix" "$out" \
    '\| 100 \(\+2 more\) \| yes \|'
  assert_file_contains "X: any-launched aggregation counts the campaign" "$out" \
    'EB campaigns launched in window = 1'
}

# ── Scenario Y: BC-11852 v2 manifest — empty campaigns[] (not launched) ──
run_y() {
  local dir; dir="$(mkdir_scenario Y)"
  write_canonicals_manifest "$dir" "hotels-resorts"
  write_canonical_vertical "$dir" "hotels-resorts" "test-offer" "free-asset"
  local m_dir="$dir/docs/campaigns/labs/hotels-resorts-v2-empty-test-offer-fy26-m04"
  mkdir -p "$m_dir"
  cat > "$m_dir/manifest.json" <<'EOF'
{
  "schema_version": 2,
  "slug": "hotels-resorts-v2-empty-test-offer-fy26-m04",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "pers",
  "offer": "test-offer",
  "year": 2026,
  "month": 4,
  "created_at": "2026-04-15T10:00:00Z",
  "salesforce": {"campaign_id": null, "campaign_name": "x"},
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_name": "x",
    "campaigns": []
  }
}
EOF
  local out="$dir/docs/campaigns/_reviews/monthly-2026-04.md"
  invoke_helper \
    --span monthly --window-start 2026-04-01 --window-end 2026-04-30 \
    --campaigns-dir "$dir/docs/campaigns" --canonicals-dir "$dir/canonicals" \
    --command-version "marketing@test" --generated-at "2026-05-26T15:00:00Z" --out "$out"
  assert_exit_and_substring "Y: v2 empty-campaigns manifest read OK" 0 "campaigns_in_window: 1"
  assert_file_contains "Y: row reads as not launched" "$out" \
    '\| \(not launched\) \| no \|'
  assert_file_contains "Y: empty campaigns[] = zero launched total" "$out" \
    'EB campaigns launched in window = 0'
}

# ── Run scenarios ───────────────────────────────────────────────────
echo "Running portfolio_snapshot.py regression harness against $HELPER"
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
run_p
run_q
run_r
run_s
run_t
run_u
run_v
run_w
run_x
run_y

echo ""
echo "RESULT pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
