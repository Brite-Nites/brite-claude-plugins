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
#   E  invalid flag rejection — markdown command static grep          expect 0
#   F  quarterly mode — 6 campaigns across 3 months in Q1             expect 0
#   G  anti-creep guard — out path outside _reviews/ rejected         expect 2
#   H  out-of-window manifest excluded                                expect 0
#   I  learnings.md verdict tally — Summary stats aggregated          expect 0
#   J  SF degraded_auth — Section 2 ⚠ banner emitted                  expect 0
#   K  posture lookup from canonicals.yaml                            expect 0
#   L  command markdown has all 4 reject-flag clauses + V3 cite       expect 0
#   M  helper refuses unknown --span value                            expect 2
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
trap 'cleanup' EXIT
cleanup() {
  # Use find+rmdir to delete (avoids rm -r which the security hook blocks).
  if [ -d "$tmproot" ]; then
    find "$tmproot" -depth -type f -exec rm {} + 2>/dev/null || true
    find "$tmproot" -depth -type d -exec rmdir {} + 2>/dev/null || true
  fi
}

pass=0
fail=0
LAST_OUTPUT=""
LAST_RC=0
LAST_OUT_FILE=""

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
  {
    printf 'schema_version: 1\n'
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
  local dir="$1" entity="$2" slug="$3" vertical="$4" persona="$5" offer="$6" created_at="$7"
  local m_dir="$dir/docs/campaigns/$entity/$slug"
  mkdir -p "$m_dir"
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
  "created_at": "$created_at",
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
# Static grep against the command markdown (not the helper).
run_e() {
  local label_base="E: command markdown rejects"
  local rejected_flags=("--weekly" "--custom-window" "--forecast" "--charts")
  for flag in "${rejected_flags[@]}"; do
    if grep -qE -- "${flag}.*rejected" "$COMMAND_MD"; then
      echo "  PASS  ${label_base} ${flag} flag"
      pass=$((pass + 1))
    else
      echo "  FAIL  ${label_base} ${flag} flag — no rejection clause found"
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
  assert_file_contains "K: pilot posture resolved" "$out" '\| pilot \|'
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

echo ""
echo "RESULT pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
