#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/migrate_manifest_v1_to_v2.py
# (BC-11852).
#
# Builds isolated synthetic campaigns directories per scenario (mktemp),
# invokes the migration helper, and asserts both the exit code AND
# scenario-specific assertions on the post-migration manifest content (or
# stderr aborts). Mirrors the pattern from test_portfolio_snapshot.sh +
# test_lint_discoveries.sh.
#
# Scenarios:
#
#   A  v1 unlaunched (campaign_id: null) → v2 empty campaigns[]              expect 0
#   B  v1 launched (campaign_id: 12345)  → v2 single-record campaigns[]     expect 0
#   C  already-v2 input → no-op (skip)                                      expect 0
#   D  idempotency — run twice, second run yields zero migrations           expect 0
#   E  dry-run does not touch the filesystem                                 expect 0
#   F  malformed JSON → abort with non-zero, others continue                expect 1
#   G  unexpected schema_version (99) → abort                               expect 1
#   H  missing email_bison block → abort                                    expect 1
#   I  missing campaigns root → exit 2                                      expect 2
#   J  --migrated-at override stamps deterministic timestamp                expect 0
#   K  unknown forward-compat keys preserved through migration              expect 0
#   L  multi-manifest run — 1 v1 + 1 v2 mixed → partial migration           expect 0
#
# Usage:
#   bash plugins/marketing/scripts/test_migrate_manifest_v1_to_v2.sh
#   bash plugins/marketing/scripts/test_migrate_manifest_v1_to_v2.sh /path/to/migrate_manifest_v1_to_v2.py

set -u  # NOT set -e — non-zero exits are expected in F/G/H/I.

# Defuse caller's git env (matches sibling test scripts).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
HELPER="${1:-$script_dir/migrate_manifest_v1_to_v2.py}"

if [ ! -f "$HELPER" ]; then
  echo "FATAL: migration helper not found: $HELPER" >&2
  exit 2
fi
HELPER="$(cd "$(dirname "$HELPER")" && pwd)/$(basename "$HELPER")"

tmproot="$(mktemp -d -t migrate-manifest-test.XXXXXX)" || {
  echo "FATAL: mktemp -d failed" >&2
  exit 2
}
cleanup() {
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
  local label="$1" expected_rc="$2" substring="$3"
  if [ "$expected_rc" -ne "$LAST_RC" ]; then
    echo "  FAIL  $label — exit expected=$expected_rc actual=$LAST_RC"
    printf '    output: %s\n' "$LAST_OUTPUT"
    fail=$((fail + 1))
    return
  fi
  if ! printf '%s' "$LAST_OUTPUT" | grep -qE -- "$substring"; then
    echo "  FAIL  $label — substring not found"
    echo "    expected regex: $substring"
    printf '    output: %s\n' "$LAST_OUTPUT"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (exit=$LAST_RC, substring matched)"
  pass=$((pass + 1))
}

assert_file_contains() {
  local label="$1" file="$2" substring="$3"
  if [ ! -f "$file" ]; then
    echo "  FAIL  $label — expected file not present: $file"
    fail=$((fail + 1)); return
  fi
  if ! grep -qE -- "$substring" "$file"; then
    echo "  FAIL  $label — substring not found in $file"
    echo "    expected regex: $substring"
    echo "    --- file head ---"
    head -25 "$file" | sed 's/^/    /'
    echo "    -----------------"
    fail=$((fail + 1)); return
  fi
  echo "  PASS  $label (file substring matched)"
  pass=$((pass + 1))
}

assert_file_NOT_contains() {
  local label="$1" file="$2" substring="$3"
  if [ ! -f "$file" ]; then
    echo "  FAIL  $label — expected file not present: $file"
    fail=$((fail + 1)); return
  fi
  if grep -qE -- "$substring" "$file"; then
    echo "  FAIL  $label — forbidden substring found in $file"
    echo "    forbidden regex: $substring"
    fail=$((fail + 1)); return
  fi
  echo "  PASS  $label (forbidden substring absent)"
  pass=$((pass + 1))
}

mkdir_scenario() {
  local name="$1"
  local dir="$tmproot/$name/docs/campaigns"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

write_v1_unlaunched() {
  local root="$1" entity="$2" slug="$3"
  local m="$root/$entity/$slug"
  mkdir -p "$m"
  cat > "$m/manifest.json" <<EOF
{
  "schema_version": 1,
  "slug": "$slug",
  "entity": "$entity",
  "vertical": "hotels-resorts",
  "persona": "director",
  "offer": "audit",
  "year": 2026,
  "month": 4,
  "linear": {"milestone_id": null, "milestone_url": null, "project": "Brite GTM"},
  "salesforce": {"campaign_id": null, "campaign_name": "$slug"},
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_id": null,
    "campaign_name": "$slug",
    "launched_at": null
  },
  "created_at": "2026-04-15T10:00:00Z",
  "scaffolded_by": "/marketing:plan-campaign"
}
EOF
}

write_v1_launched() {
  local root="$1" entity="$2" slug="$3" cid="$4"
  local m="$root/$entity/$slug"
  mkdir -p "$m"
  cat > "$m/manifest.json" <<EOF
{
  "schema_version": 1,
  "slug": "$slug",
  "entity": "$entity",
  "vertical": "hotels-resorts",
  "persona": "director",
  "offer": "audit",
  "year": 2026,
  "month": 4,
  "linear": {"milestone_id": null, "milestone_url": null, "project": "Brite GTM"},
  "salesforce": {"campaign_id": null, "campaign_name": "$slug"},
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_id": $cid,
    "campaign_name": "$slug",
    "launched_at": "2026-04-20T12:00:00Z"
  },
  "created_at": "2026-04-15T10:00:00Z",
  "scaffolded_by": "/marketing:plan-campaign"
}
EOF
}

write_v2_already() {
  local root="$1" entity="$2" slug="$3"
  local m="$root/$entity/$slug"
  mkdir -p "$m"
  cat > "$m/manifest.json" <<EOF
{
  "schema_version": 2,
  "slug": "$slug",
  "entity": "$entity",
  "vertical": "hotels-resorts",
  "persona": "director",
  "offer": "audit",
  "year": 2026,
  "month": 4,
  "linear": {"milestone_id": null, "milestone_url": null, "project": "Brite GTM"},
  "salesforce": {"campaign_id": null, "campaign_name": "$slug"},
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_name": "$slug",
    "campaigns": []
  },
  "created_at": "2026-04-15T10:00:00Z",
  "scaffolded_by": "/marketing:plan-campaign"
}
EOF
}

invoke_helper() {
  LAST_OUTPUT="$(python3 "$HELPER" "$@" 2>&1)"
  LAST_RC=$?
}

# ── Scenario A: v1 unlaunched (campaign_id null) → v2 empty campaigns[] ─
run_a() {
  local root; root="$(mkdir_scenario A)"
  write_v1_unlaunched "$root" "labs" "hotels-resorts-pers-offer-fy26-m04"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  local f="$root/labs/hotels-resorts-pers-offer-fy26-m04/manifest.json"
  assert_exit_and_substring "A: v1 unlaunched migrates clean" 0 "migrated=1"
  assert_file_contains "A: schema_version bumped to 2" "$f" '"schema_version": 2'
  assert_file_contains "A: campaigns[] array present + empty" "$f" '"campaigns": \[\]'
  # The salesforce.campaign_id is legitimately retained as null — narrow the
  # assertion to the email_bison block using python3 to walk the parsed JSON.
  if python3 -c "
import json, sys
with open('$f') as h:
    eb = json.load(h).get('email_bison', {})
sys.exit(0 if 'campaign_id' not in eb and 'launched_at' not in eb else 1)
"; then
    echo "  PASS  A: legacy email_bison.campaign_id + launched_at removed"
    pass=$((pass + 1))
  else
    echo "  FAIL  A: legacy email_bison.campaign_id or launched_at still present"
    fail=$((fail + 1))
  fi
  assert_file_contains "A: migrated_from audit block present" "$f" '"migrated_from"'
  assert_file_contains "A: migrated_from.schema_version: 1" "$f" '"schema_version": 1'
  assert_file_contains "A: workspace retained" "$f" '"workspace": "emailbison-b2b"'
}

# ── Scenario B: v1 launched (campaign_id: 12345) → single-record campaigns[] ─
run_b() {
  local root; root="$(mkdir_scenario B)"
  write_v1_launched "$root" "labs" "hotels-resorts-pers-offer-fy26-m04" "12345"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  local f="$root/labs/hotels-resorts-pers-offer-fy26-m04/manifest.json"
  assert_exit_and_substring "B: v1 launched migrates clean" 0 "migrated=1"
  assert_file_contains "B: schema_version bumped to 2" "$f" '"schema_version": 2'
  assert_file_contains "B: campaigns[] contains the legacy campaign_id" "$f" '"campaign_id": 12345'
  assert_file_contains "B: launched_at carried over into the record" "$f" '"launched_at": "2026-04-20T12:00:00Z"'
  assert_file_contains "B: status set to launched" "$f" '"status": "launched"'
  assert_file_contains "B: placeholder audience_tier inserted" "$f" '"tier": "professional"'
  assert_file_contains "B: pending_classification flag set on placeholder" "$f" '"pending_classification": true'
}

# ── Scenario C: already-v2 input → no-op skip ──────────────────────────
run_c() {
  local root; root="$(mkdir_scenario C)"
  write_v2_already "$root" "labs" "already-v2-fy26-m04"
  local f="$root/labs/already-v2-fy26-m04/manifest.json"
  local sha_before
  sha_before="$(shasum -a 256 "$f" | awk '{print $1}')"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  assert_exit_and_substring "C: already-v2 file is no-op" 0 "v2-already=1"
  assert_exit_and_substring "C: zero migrations performed" 0 "migrated=0"
  local sha_after
  sha_after="$(shasum -a 256 "$f" | awk '{print $1}')"
  if [ "$sha_before" = "$sha_after" ]; then
    echo "  PASS  C: file byte-identical after no-op"; pass=$((pass + 1))
  else
    echo "  FAIL  C: file changed despite no-op claim"
    fail=$((fail + 1))
  fi
}

# ── Scenario D: idempotency — second run after a v1 migration ─────────
run_d() {
  local root; root="$(mkdir_scenario D)"
  write_v1_unlaunched "$root" "labs" "hotels-resorts-pers-offer-fy26-m04"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  if [ "$LAST_RC" -ne 0 ]; then
    echo "  FAIL  D: first migration run failed unexpectedly (rc=$LAST_RC)"
    fail=$((fail + 1)); return
  fi
  local f="$root/labs/hotels-resorts-pers-offer-fy26-m04/manifest.json"
  local sha_after_first
  sha_after_first="$(shasum -a 256 "$f" | awk '{print $1}')"
  # Second run — should detect schema_version=2 and skip.
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T12:00:00Z"
  assert_exit_and_substring "D: second run is idempotent" 0 "v2-already=1"
  assert_exit_and_substring "D: second run performs zero migrations" 0 "migrated=0"
  local sha_after_second
  sha_after_second="$(shasum -a 256 "$f" | awk '{print $1}')"
  if [ "$sha_after_first" = "$sha_after_second" ]; then
    echo "  PASS  D: file byte-identical across re-runs"
    pass=$((pass + 1))
  else
    echo "  FAIL  D: file mutated on second run"
    fail=$((fail + 1))
  fi
}

# ── Scenario E: dry-run does not touch filesystem ─────────────────────
run_e() {
  local root; root="$(mkdir_scenario E)"
  write_v1_unlaunched "$root" "labs" "hotels-resorts-pers-offer-fy26-m04"
  local f="$root/labs/hotels-resorts-pers-offer-fy26-m04/manifest.json"
  local sha_before
  sha_before="$(shasum -a 256 "$f" | awk '{print $1}')"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z" --dry-run
  assert_exit_and_substring "E: dry-run reports planned migration" 0 "migrated=1"
  assert_exit_and_substring "E: dry-run flagged in summary" 0 'dry-run'
  local sha_after
  sha_after="$(shasum -a 256 "$f" | awk '{print $1}')"
  if [ "$sha_before" = "$sha_after" ]; then
    echo "  PASS  E: dry-run left file untouched"
    pass=$((pass + 1))
  else
    echo "  FAIL  E: dry-run wrote to file despite --dry-run flag"
    fail=$((fail + 1))
  fi
  assert_file_contains "E: dry-run leaves schema_version: 1 on disk" "$f" '"schema_version": 1'
}

# ── Scenario F: malformed JSON → abort + non-zero exit ────────────────
run_f() {
  local root; root="$(mkdir_scenario F)"
  # Write a malformed manifest at the canonical glob depth.
  local m="$root/labs/malformed-slug-fy26-m04"
  mkdir -p "$m"
  # Trailing comma after last field is invalid JSON.
  printf '{"schema_version": 1, "slug": "malformed-slug-fy26-m04",}\n' > "$m/manifest.json"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  assert_exit_and_substring "F: malformed JSON aborts" 1 "abort=1"
  assert_exit_and_substring "F: ABORT line surfaces the offending file" 1 "ABORT  labs/malformed-slug-fy26-m04"
  assert_exit_and_substring "F: invalid-json detail in abort reason" 1 "invalid-json"
}

# ── Scenario G: unexpected schema_version (99) → abort ────────────────
run_g() {
  local root; root="$(mkdir_scenario G)"
  local m="$root/labs/future-slug-fy26-m04"
  mkdir -p "$m"
  cat > "$m/manifest.json" <<'EOF'
{"schema_version": 99, "slug": "future-slug-fy26-m04", "email_bison": {}}
EOF
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  assert_exit_and_substring "G: unexpected schema_version aborts" 1 "abort=1"
  assert_exit_and_substring "G: abort reason names the unexpected version" 1 "unexpected-schema-version:99"
}

# ── Scenario H: missing email_bison block → abort ─────────────────────
run_h() {
  local root; root="$(mkdir_scenario H)"
  local m="$root/labs/no-eb-slug-fy26-m04"
  mkdir -p "$m"
  cat > "$m/manifest.json" <<'EOF'
{"schema_version": 1, "slug": "no-eb-slug-fy26-m04"}
EOF
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  assert_exit_and_substring "H: missing email_bison aborts" 1 "abort=1"
  assert_exit_and_substring "H: abort reason names missing-or-malformed-email_bison" 1 "missing-or-malformed-email_bison"
}

# ── Scenario I: missing campaigns root → exit 2 ───────────────────────
run_i() {
  invoke_helper --campaigns-root "$tmproot/i-nonexistent-root" --migrated-at "2026-05-27T00:00:00Z"
  assert_exit_and_substring "I: missing campaigns root → usage error" 2 "campaigns root does not exist"
}

# ── Scenario J: --migrated-at override stamps deterministic timestamp ─
run_j() {
  local root; root="$(mkdir_scenario J)"
  write_v1_unlaunched "$root" "labs" "hotels-resorts-pers-offer-fy26-m04"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T08:15:30Z"
  local f="$root/labs/hotels-resorts-pers-offer-fy26-m04/manifest.json"
  assert_exit_and_substring "J: deterministic migrated_at run OK" 0 "migrated=1"
  assert_file_contains "J: migrated_at stamped from CLI override" "$f" '"migrated_at": "2026-05-27T08:15:30Z"'
}

# ── Scenario K: unknown forward-compat keys preserved through migration ─
run_k() {
  local root; root="$(mkdir_scenario K)"
  local m="$root/labs/fwd-compat-fy26-m04"
  mkdir -p "$m"
  cat > "$m/manifest.json" <<'EOF'
{
  "schema_version": 1,
  "slug": "fwd-compat-fy26-m04",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director",
  "offer": "audit",
  "year": 2026,
  "month": 4,
  "linear": {"milestone_id": null, "milestone_url": null, "project": "Brite GTM"},
  "salesforce": {"campaign_id": null, "campaign_name": "fwd-compat-fy26-m04"},
  "email_bison": {
    "workspace": "emailbison-b2b",
    "campaign_id": null,
    "campaign_name": "fwd-compat-fy26-m04",
    "launched_at": null
  },
  "created_at": "2026-04-15T10:00:00Z",
  "scaffolded_by": "/marketing:plan-campaign",
  "future_unknown_field": "preserve-me-please",
  "angles": [{"slug": "angle-a", "verdict": "ALPHA"}]
}
EOF
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  local f="$m/manifest.json"
  assert_exit_and_substring "K: forward-compat migration OK" 0 "migrated=1"
  assert_file_contains "K: unknown top-level field preserved" "$f" '"future_unknown_field": "preserve-me-please"'
  assert_file_contains "K: angles[] survives migration" "$f" '"verdict": "ALPHA"'
}

# ── Scenario L: multi-manifest run (1 v1 + 1 v2) → partial migration ──
run_l() {
  local root; root="$(mkdir_scenario L)"
  write_v1_unlaunched "$root" "labs" "v1-slug-fy26-m04"
  write_v2_already "$root" "labs" "v2-slug-fy26-m05"
  invoke_helper --campaigns-root "$root" --migrated-at "2026-05-27T00:00:00Z"
  assert_exit_and_substring "L: mixed run OK" 0 "migrated=1"
  assert_exit_and_substring "L: mixed run reports v2-already=1" 0 "v2-already=1"
  local f1="$root/labs/v1-slug-fy26-m04/manifest.json"
  local f2="$root/labs/v2-slug-fy26-m05/manifest.json"
  assert_file_contains "L: v1 file bumped to schema_version 2" "$f1" '"schema_version": 2'
  assert_file_contains "L: v1 file has migrated_from block" "$f1" '"migrated_from"'
  assert_file_NOT_contains "L: v2 file did NOT receive migrated_from" "$f2" '"migrated_from"'
}

# ── Run scenarios ─────────────────────────────────────────────────────
echo "Running migrate_manifest_v1_to_v2.py regression harness against $HELPER"
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

echo ""
echo "RESULT pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
