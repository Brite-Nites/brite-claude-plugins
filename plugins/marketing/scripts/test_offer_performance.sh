#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/offer_performance.py
# (BC-8728). Builds isolated campaigns + canonicals directories per scenario
# via mktemp, drives the helper non-interactively, asserts exit code AND
# scenario-specific substrings.
#
# Scenarios:
#   A  happy single-version offer (EB + SF) → emits one performance.md
#   B  multi-version offer (3 versions) → cross-version comparison populated
#   C  graceful empty (no campaigns for offer) → no-op exit
#   D  missing EB stats (soft-fail, still emit SF data with EB-degraded banner)
#   E  missing SF data (soft-fail, still emit EB data with SF-degraded banner)
#   F  invalid --offer-slug (not in canonicals) → exit non-zero
#   G  anti-creep --out path refusal → exit 2
#   H  retirement-candidate detection (3 consecutive degrading) → flagged
#
# Usage:
#   bash plugins/marketing/scripts/test_offer_performance.sh

set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${1:-$script_dir/offer_performance.py}"

if [ ! -f "$SCRIPT" ]; then
  echo "FATAL: helper script not found: $SCRIPT" >&2
  exit 2
fi
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"

tmproot="$(mktemp -d -t test-offer-performance.XXXXXX)" || {
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

assert_file_substring() {
  local label="$1"
  local file="$2"
  local substring="$3"

  if [ ! -f "$file" ]; then
    echo "  FAIL  $label — file not found: $file"
    fail=$((fail + 1))
    return
  fi
  if ! grep -qE -- "$substring" "$file"; then
    echo "  FAIL  $label — substring not found in file"
    echo "    expected regex: $substring"
    echo "    file: $file"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (file substring matched)"
  pass=$((pass + 1))
}

assert_file_absent() {
  local label="$1"
  local file="$2"

  if [ -f "$file" ]; then
    echo "  FAIL  $label — file should NOT exist: $file"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (file correctly absent)"
  pass=$((pass + 1))
}

invoke() {
  LAST_OUTPUT="$(cd "$script_dir" && python3 "$SCRIPT" "$@" 2>&1)"
  LAST_RC=$?
}

# ── Fixture builders ──────────────────────────────────────────────────────

mk_fixture_dirs() {
  local name="$1"
  local camp="$tmproot/$name/campaigns"
  local canon="$tmproot/$name/canonicals"
  mkdir -p "$camp" "$canon"
  # Minimal canonicals
  cat > "$canon/_manifest.yaml" <<'YAML'
schema_version: 2
verticals:
  - hotels-resorts
YAML
  cat > "$canon/hotels-resorts.yaml" <<'YAML'
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
    target_personas:
      - director-of-resort-experience
YAML
}

mk_manifest() {
  # $1: campaigns_dir, $2: entity, $3: slug, $4: offer
  local dir="$1/$2/$3"
  mkdir -p "$dir"
  cat > "$dir/manifest.json" <<EOF
{
  "slug": "$3",
  "entity": "$2",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "$4",
  "email_bison": {"campaign_id": "eb-$3", "launched_at": "2026-04-15"}
}
EOF
}

mk_manifest_v2() {
  # $1: campaigns_dir, $2: entity, $3: slug, $4: offer
  # Schema-v2 manifest: email_bison.campaigns[] (multi-record). First record's
  # campaign_id is 8801; earliest launched_at is 2025-09-20 (the SECOND record),
  # so "earliest" is distinct from both first-record-order and latest — the
  # rendered Launched column proving 2025-09-20 locks earliest specifically.
  local dir="$1/$2/$3"
  mkdir -p "$dir"
  cat > "$dir/manifest.json" <<EOF
{
  "schema_version": 2,
  "slug": "$3",
  "entity": "$2",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "$4",
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_name": "$3",
    "campaigns": [
      {"workspace": "emailbison-b2b", "campaign_id": 8801, "audience_tier": {"tier": "professional", "seniority": null, "modifiers": []}, "launched_at": "2025-09-22"},
      {"workspace": "emailbison-personal", "campaign_id": 8802, "audience_tier": {"tier": "personal", "seniority": null, "modifiers": []}, "launched_at": "2025-09-20"}
    ]
  }
}
EOF
}

mk_eb_json() {
  # $1: output path, $2+: slug:reply_rate:meeting_rate triples
  local out="$1"
  shift
  local campaigns=""
  local first=1
  for triple in "$@"; do
    IFS=: read -r slug rr mr <<< "$triple"
    if [ "$first" -eq 0 ]; then campaigns="$campaigns,"; fi
    first=0
    campaigns="$campaigns{\"slug\":\"$slug\",\"stats\":{\"reply_rate\":$rr,\"meeting_rate\":$mr,\"total_sent\":100,\"total_replies\":10}}"
  done
  printf '{"campaigns":[%s]}' "$campaigns" > "$out"
}

mk_sf_json() {
  # $1: output path, $2+: slug:amtAll:amtWon:leads quads
  local out="$1"
  shift
  local records=""
  local first=1
  for quad in "$@"; do
    IFS=: read -r slug aa aw ld <<< "$quad"
    if [ "$first" -eq 0 ]; then records="$records,"; fi
    first=0
    records="$records{\"Name\":\"$slug\",\"AmountAllOpportunities\":$aa,\"AmountWonOpportunities\":$aw,\"NumberOfLeads\":$ld}"
  done
  printf '{"records":[%s]}' "$records" > "$out"
}

# ══════════════════════════════════════════════════════════════════════════
# Scenario A: happy single-version offer with EB + SF data
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario A: happy single-version ──"
mk_fixture_dirs "A"
camp_a="$tmproot/A/campaigns"
canon_a="$tmproot/A/canonicals"
mk_manifest "$camp_a" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m04" "holiday-anchor-audit"

eb_a="$tmproot/A/eb.json"
mk_eb_json "$eb_a" "hotels-resorts-director-holiday-anchor-audit-fy26-m04:5.2:1.1"

sf_a="$tmproot/A/sf.json"
mk_sf_json "$sf_a" "hotels-resorts-director-holiday-anchor-audit-fy26-m04:50000:20000:15"

invoke \
  --offer-slug holiday-anchor-audit \
  --entity labs \
  --campaigns-dir "$camp_a" \
  --canonicals-dir "$canon_a" \
  --eb-json "$eb_a" \
  --sf-json "$sf_a" \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "A: exit OK" 0 "OK: offer-performance written"
assert_file_substring "A: frontmatter present" \
  "$camp_a/labs/offers/holiday-anchor-audit/v1/performance.md" \
  "schema_version: 1"
assert_file_substring "A: reply rate in table" \
  "$camp_a/labs/offers/holiday-anchor-audit/v1/performance.md" \
  "5.2%"
assert_file_substring "A: SF pipeline in table" \
  "$camp_a/labs/offers/holiday-anchor-audit/v1/performance.md" \
  '\$50,000'

# ══════════════════════════════════════════════════════════════════════════
# Scenario B: multi-version offer (3 versions)
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario B: multi-version ──"
mk_fixture_dirs "B"
camp_b="$tmproot/B/campaigns"
canon_b="$tmproot/B/canonicals"
mk_manifest "$camp_b" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m02" "holiday-anchor-audit"
mk_manifest "$camp_b" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m03-v2" "holiday-anchor-audit"
mk_manifest "$camp_b" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m04-v3" "holiday-anchor-audit"

eb_b="$tmproot/B/eb.json"
mk_eb_json "$eb_b" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m02:6.0:1.5" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m03-v2:5.5:1.2" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m04-v3:7.0:2.0"

sf_b="$tmproot/B/sf.json"
mk_sf_json "$sf_b" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m02:30000:10000:10" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m03-v2:40000:15000:12" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m04-v3:60000:25000:20"

invoke \
  --offer-slug holiday-anchor-audit \
  --entity labs \
  --campaigns-dir "$camp_b" \
  --canonicals-dir "$canon_b" \
  --eb-json "$eb_b" \
  --sf-json "$sf_b" \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "B: exit OK" 0 "versions: 3"
assert_file_substring "B: cross-version comparison populated" \
  "$camp_b/labs/offers/holiday-anchor-audit/performance.md" \
  "Cross-version comparison"
assert_file_substring "B: summary has all 3 versions" \
  "$camp_b/labs/offers/holiday-anchor-audit/performance.md" \
  "versions_analyzed: 3"

# ══════════════════════════════════════════════════════════════════════════
# Scenario C: graceful empty (no campaigns for offer)
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario C: graceful empty ──"
mk_fixture_dirs "C"
camp_c="$tmproot/C/campaigns"
canon_c="$tmproot/C/canonicals"
# No manifests created

invoke \
  --offer-slug holiday-anchor-audit \
  --entity labs \
  --campaigns-dir "$camp_c" \
  --canonicals-dir "$canon_c" \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "C: graceful empty exit 0" 0 "no campaigns found"
assert_file_absent "C: no performance.md written" \
  "$camp_c/labs/offers/holiday-anchor-audit/v1/performance.md"

# ══════════════════════════════════════════════════════════════════════════
# Scenario D: missing EB stats (soft-fail)
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario D: EB degraded ──"
mk_fixture_dirs "D"
camp_d="$tmproot/D/campaigns"
canon_d="$tmproot/D/canonicals"
mk_manifest "$camp_d" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m04" "holiday-anchor-audit"

sf_d="$tmproot/D/sf.json"
mk_sf_json "$sf_d" "hotels-resorts-director-holiday-anchor-audit-fy26-m04:50000:20000:15"

invoke \
  --offer-slug holiday-anchor-audit \
  --entity labs \
  --campaigns-dir "$camp_d" \
  --canonicals-dir "$canon_d" \
  --sf-json "$sf_d" \
  --eb-status degraded \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "D: exit OK with EB degraded" 0 "OK: offer-performance written"
assert_file_substring "D: EB degraded banner" \
  "$camp_d/labs/offers/holiday-anchor-audit/v1/performance.md" \
  "EB stats degraded"
assert_file_substring "D: SF pipeline still shown" \
  "$camp_d/labs/offers/holiday-anchor-audit/v1/performance.md" \
  '\$50,000'

# ══════════════════════════════════════════════════════════════════════════
# Scenario E: missing SF data (soft-fail)
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario E: SF degraded ──"
mk_fixture_dirs "E"
camp_e="$tmproot/E/campaigns"
canon_e="$tmproot/E/canonicals"
mk_manifest "$camp_e" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m04" "holiday-anchor-audit"

eb_e="$tmproot/E/eb.json"
mk_eb_json "$eb_e" "hotels-resorts-director-holiday-anchor-audit-fy26-m04:5.2:1.1"

invoke \
  --offer-slug holiday-anchor-audit \
  --entity labs \
  --campaigns-dir "$camp_e" \
  --canonicals-dir "$canon_e" \
  --eb-json "$eb_e" \
  --sf-status degraded_auth \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "E: exit OK with SF degraded" 0 "OK: offer-performance written"
assert_file_substring "E: SF degraded banner" \
  "$camp_e/labs/offers/holiday-anchor-audit/v1/performance.md" \
  "SF rollup degraded"
assert_file_substring "E: EB data still shown" \
  "$camp_e/labs/offers/holiday-anchor-audit/v1/performance.md" \
  "5.2%"

# ══════════════════════════════════════════════════════════════════════════
# Scenario F: invalid --offer-slug
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario F: invalid offer slug ──"
mk_fixture_dirs "F"
camp_f="$tmproot/F/campaigns"
canon_f="$tmproot/F/canonicals"

invoke \
  --offer-slug totally-bogus-offer \
  --entity labs \
  --campaigns-dir "$camp_f" \
  --canonicals-dir "$canon_f" \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "F: invalid slug exit 1" 1 "not found in any vertical"

# ══════════════════════════════════════════════════════════════════════════
# Scenario G: anti-creep out path refusal
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario G: anti-creep path guard ──"
mkdir -p "$tmproot/G/campaigns"
LAST_OUTPUT="$(cd "$script_dir" && python3 -c "
import sys; sys.path.insert(0, '.')
from offer_performance import assert_out_under_offers
from pathlib import Path
assert_out_under_offers(Path('/tmp/evil/path.md'), Path('$tmproot/G/campaigns'))
" 2>&1)"
LAST_RC=$?
assert_exit_and_substring "G: anti-creep exit 2" 2 "anti-creep guard"

# ══════════════════════════════════════════════════════════════════════════
# Scenario H: retirement-candidate detection
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario H: retirement-candidate ──"
mk_fixture_dirs "H"
camp_h="$tmproot/H/campaigns"
canon_h="$tmproot/H/canonicals"
mk_manifest "$camp_h" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m01" "holiday-anchor-audit"
mk_manifest "$camp_h" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m02-v2" "holiday-anchor-audit"
mk_manifest "$camp_h" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m03-v3" "holiday-anchor-audit"

eb_h="$tmproot/H/eb.json"
mk_eb_json "$eb_h" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m01:8.0:2.0" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m02-v2:6.0:1.5" \
  "hotels-resorts-director-holiday-anchor-audit-fy26-m03-v3:4.0:1.0"

invoke \
  --offer-slug holiday-anchor-audit \
  --entity labs \
  --campaigns-dir "$camp_h" \
  --canonicals-dir "$canon_h" \
  --eb-json "$eb_h" \
  --degradation-threshold 2 \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "H: exit OK" 0 "retirement_signal: YES"
assert_file_substring "H: retirement flag in summary" \
  "$camp_h/labs/offers/holiday-anchor-audit/performance.md" \
  "RETIREMENT CANDIDATE"
assert_file_substring "H: consecutive degrading count" \
  "$camp_h/labs/offers/holiday-anchor-audit/performance.md" \
  "2 consecutive versions"

# ══════════════════════════════════════════════════════════════════════════
# Scenario I: schema-v2 manifest (email_bison.campaigns[]) — BC-12593
# A v2 manifest has no singular email_bison.campaign_id/launched_at; the
# Launched column must render the EARLIEST campaigns[].launched_at, not n/a.
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario I: v2 manifest email_bison.campaigns[] ──"
mk_fixture_dirs "I"
camp_i="$tmproot/I/campaigns"
canon_i="$tmproot/I/canonicals"
mk_manifest_v2 "$camp_i" "labs" "hotels-resorts-director-holiday-anchor-audit-fy26-m04" "holiday-anchor-audit"

invoke \
  --offer-slug holiday-anchor-audit \
  --entity labs \
  --campaigns-dir "$camp_i" \
  --canonicals-dir "$canon_i" \
  --generated-at "2026-05-26T12:00:00Z"

assert_exit_and_substring "I: exit OK on v2 manifest" 0 "OK: offer-performance written"
# Earliest launched_at (2025-09-20) renders — proves v2 campaigns[] is read AND
# that EARLIEST (not the first record's 2025-09-22 / latest) is chosen.
assert_file_substring "I: v2 earliest launched_at rendered in Launched column" \
  "$camp_i/labs/offers/holiday-anchor-audit/v1/performance.md" \
  "2025-09-20"

# ══════════════════════════════════════════════════════════════════════════
# Scenario J: eb_fields_from_manifest helper — v1 + v2 + empty (BC-12593)
# eb_campaign_id is computed-but-unrendered, so assert the helper directly:
# v2 → (campaigns[0].campaign_id, earliest launched_at); v1 → singular fields;
# empty campaigns[] → (None, None).
# ══════════════════════════════════════════════════════════════════════════

echo "── Scenario J: eb_fields_from_manifest (v1/v2/empty) ──"
LAST_OUTPUT="$(cd "$script_dir" && python3 -c "
import sys; sys.path.insert(0, '.')
from offer_performance import eb_fields_from_manifest
# v2: first-record campaign_id + EARLIEST launched_at (records out of order)
v2 = {'workspace':'emailbison-b2b','campaign_name':'x','campaigns':[
  {'campaign_id':8801,'launched_at':'2025-09-22'},
  {'campaign_id':8802,'launched_at':'2025-09-20'}]}
cid, la = eb_fields_from_manifest(v2)
assert cid == 8801, f'v2 campaign_id={cid!r}'
assert la == '2025-09-20', f'v2 launched_at={la!r}'
# v1 fallback: singular fields unchanged
cid, la = eb_fields_from_manifest({'campaign_id':'eb-x','launched_at':'2026-04-15'})
assert cid == 'eb-x', f'v1 campaign_id={cid!r}'
assert la == '2026-04-15', f'v1 launched_at={la!r}'
# empty v2 campaigns[] (unlaunched) -> (None, None)
cid, la = eb_fields_from_manifest({'workspace':'emailbison-b2b','campaign_name':'x','campaigns':[]})
assert cid is None and la is None, f'empty=({cid!r},{la!r})'
# v2 records present but none launched -> campaign_id from first, launched_at None
cid, la = eb_fields_from_manifest({'campaigns':[{'campaign_id':9001}]})
assert cid == 9001 and la is None, f'unlaunched-record=({cid!r},{la!r})'
# MIXED OFFSET ZONES: must pick chronologically-earliest, NOT lexicographically
# smallest. B (09:00+05:00 = 04:00Z) precedes A (06:00Z), but lexicographically
# '...T06:00:00Z' < '...T09:00:00+05:00' — a naive min() would wrongly return A.
cid, la = eb_fields_from_manifest({'campaigns':[
  {'campaign_id':1,'launched_at':'2025-09-20T06:00:00Z'},
  {'campaign_id':2,'launched_at':'2025-09-20T09:00:00+05:00'}]})
assert la == '2025-09-20T09:00:00+05:00', f'mixed-offset earliest={la!r}'
# NAIVE (date-only) + AWARE (Z) must not raise (naive treated as UTC midnight).
cid, la = eb_fields_from_manifest({'campaigns':[
  {'campaign_id':3,'launched_at':'2025-09-21'},
  {'campaign_id':4,'launched_at':'2025-09-20T23:00:00Z'}]})
assert la == '2025-09-20T23:00:00Z', f'naive+aware earliest={la!r}'
print('HELPER_OK')
" 2>&1)"
LAST_RC=$?
assert_exit_and_substring "J: eb_fields_from_manifest v1+v2+empty correct" 0 "HELPER_OK"

# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "offer_performance.py harness: $((pass))/$((pass + fail)) passing"
echo "RESULT pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  echo "FAIL — $fail scenario(s) failed"
  exit 1
fi
echo "PASS — all scenarios green"
