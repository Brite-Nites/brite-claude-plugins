#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/import_campaign.py
# (BC-11849 — /marketing:import-campaign).
#
# Two surfaces under test:
#
#   classify-name   Maps a single EB campaign name to a structured
#                   audience_tier object per the _manifest.yaml taxonomy.
#                   The 11 ADR-020 worked-example strings (the full §
#                   Worked examples table) are the regression-lock
#                   fixtures — every one must classify exactly as the
#                   ADR § Worked examples table says, with no manual
#                   tweaks. Count drift detection lives in Scenario N
#                   (greps the ADR for table-row count).
#
#   compose         Reads a JSON import payload on stdin and emits a v2
#                   manifest on stdout. Covers happy path (empty records,
#                   single record, multiple records), structural-error
#                   rejection paths, audience_tier override, and a cohort-1
#                   reproduction probe.
#
# Pattern matches sibling harnesses (test_migrate_manifest_v1_to_v2.sh,
# test_portfolio_snapshot.sh, test_offer_performance.sh): per-scenario
# tempdir, exit + substring + file-content asserts, RESULT line at the end
# for the validate.sh wire to parse.
#
# Usage:
#   bash plugins/marketing/scripts/test_import_campaign.sh
#   bash plugins/marketing/scripts/test_import_campaign.sh /path/to/import_campaign.py

set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
HELPER="${1:-$script_dir/import_campaign.py}"

if [ ! -f "$HELPER" ]; then
  echo "FATAL: import-campaign helper not found: $HELPER" >&2
  exit 2
fi
HELPER="$(cd "$(dirname "$HELPER")" && pwd)/$(basename "$HELPER")"

# Resolve canonicals manifest path — same logic as the helper's default.
canonicals="$script_dir/../data/canonicals/_manifest.yaml"
if [ ! -f "$canonicals" ]; then
  echo "FATAL: canonicals manifest not found at $canonicals" >&2
  exit 2
fi
canonicals="$(cd "$(dirname "$canonicals")" && pwd)/$(basename "$canonicals")"

tmproot="$(mktemp -d -t import-campaign-test.XXXXXX)" || {
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

LAST_STDERR=""

invoke_classify() {
  local name="$1"
  local err="$tmproot/stderr.$$"
  LAST_OUTPUT="$(python3 "$HELPER" classify-name --eb-name "$name" --canonicals-manifest "$canonicals" 2>"$err")"
  LAST_RC=$?
  LAST_STDERR="$(cat "$err" 2>/dev/null)"
  rm -f "$err"
}

invoke_classify_default() {
  local name="$1" default="$2"
  local err="$tmproot/stderr.$$"
  LAST_OUTPUT="$(python3 "$HELPER" classify-name --eb-name "$name" --default-tier "$default" --canonicals-manifest "$canonicals" 2>"$err")"
  LAST_RC=$?
  LAST_STDERR="$(cat "$err" 2>/dev/null)"
  rm -f "$err"
}

invoke_compose() {
  local stdin_payload="$1"
  local err="$tmproot/stderr.$$"
  LAST_OUTPUT="$(printf '%s' "$stdin_payload" | python3 "$HELPER" compose --canonicals-manifest "$canonicals" 2>"$err")"
  LAST_RC=$?
  LAST_STDERR="$(cat "$err" 2>/dev/null)"
  rm -f "$err"
}

# Composite buffer used by substring asserts that may match either stream.
combined_output() {
  printf '%s\n%s' "$LAST_OUTPUT" "$LAST_STDERR"
}

assert_rc() {
  local label="$1" expected="$2"
  if [ "$expected" -eq "$LAST_RC" ]; then
    echo "  PASS  $label (rc=$LAST_RC)"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — rc expected=$expected actual=$LAST_RC"
    printf '    output: %s\n' "$LAST_OUTPUT"
    fail=$((fail + 1))
  fi
}

assert_substr() {
  # Matches against stdout + stderr — error messages live on stderr, JSON
  # success output on stdout. Caller asserts presence regardless of stream.
  local label="$1" needle="$2"
  local hay; hay="$(combined_output)"
  if printf '%s' "$hay" | grep -qE -- "$needle"; then
    echo "  PASS  $label (substr matched)"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — substring not found"
    echo "    expected regex: $needle"
    printf '    output: %s\n' "$hay"
    fail=$((fail + 1))
  fi
}

assert_NOT_substr() {
  # Matches against stdout only — used by success-path tests asserting that a
  # forbidden token (e.g., legacy v1 field) was scrubbed from the composed
  # JSON. Stderr is excluded because stderr WARNs may legitimately mention
  # the forbidden token in remediation prose.
  local label="$1" needle="$2"
  if printf '%s' "$LAST_OUTPUT" | grep -qE -- "$needle"; then
    echo "  FAIL  $label — forbidden substring found"
    echo "    forbidden regex: $needle"
    printf '    output: %s\n' "$LAST_OUTPUT"
    fail=$((fail + 1))
  else
    echo "  PASS  $label (forbidden substr absent)"; pass=$((pass + 1))
  fi
}

assert_json_value() {
  # Cheap JSON-path assertion via python3 — extract `.path` from LAST_OUTPUT,
  # compare to expected literal string. Path is dot-separated. Path is passed
  # via env var (TEST_PATH) — never shell-interpolated into the heredoc —
  # to defuse the assert-author-supplies-quote-character footgun.
  local label="$1" path="$2" expected="$3"
  local actual
  actual=$(printf '%s' "$LAST_OUTPUT" | TEST_PATH="$path" python3 -c '
import json, os, sys
try:
    d = json.loads(sys.stdin.read())
except Exception as e:
    sys.stderr.write(f"parse-failed:{e}")
    sys.exit(1)
parts = os.environ.get("TEST_PATH", "").split(".")
cur = d
for p in parts:
    if isinstance(cur, list):
        try:
            cur = cur[int(p)]
        except (ValueError, IndexError):
            sys.stderr.write(f"bad-index:{p}")
            sys.exit(1)
    elif isinstance(cur, dict):
        if p not in cur:
            sys.stderr.write(f"missing-key:{p}")
            sys.exit(1)
        cur = cur[p]
    else:
        sys.stderr.write(f"leaf-deref:{p}")
        sys.exit(1)
if cur is None:
    sys.stdout.write("__NONE__")
else:
    sys.stdout.write(str(cur) if not isinstance(cur, (list, dict)) else json.dumps(cur, sort_keys=True))
' 2>&1)
  if [ "$actual" = "$expected" ]; then
    echo "  PASS  $label (.$path = $expected)"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — .$path expected=$expected actual=$actual"
    fail=$((fail + 1))
  fi
}

assert_json_keyset() {
  # Asserts that the top-level (or nested-path) keys of LAST_OUTPUT match
  # the comma-separated expected sorted-key-set exactly. Anchors the
  # "indistinguishable from plan-campaign" contract — adding or dropping a
  # manifest key forces a corresponding test update.
  local label="$1" path="$2" expected_keys="$3"
  local actual
  actual=$(printf '%s' "$LAST_OUTPUT" | TEST_PATH="$path" python3 -c '
import json, os, sys
try:
    d = json.loads(sys.stdin.read())
except Exception as e:
    sys.stderr.write(f"parse-failed:{e}")
    sys.exit(1)
parts = [p for p in os.environ.get("TEST_PATH", "").split(".") if p]
cur = d
for p in parts:
    if not isinstance(cur, dict) or p not in cur:
        sys.stderr.write(f"missing-key:{p}")
        sys.exit(1)
    cur = cur[p]
if not isinstance(cur, dict):
    sys.stderr.write("leaf-not-dict")
    sys.exit(1)
sys.stdout.write(",".join(sorted(cur.keys())))
' 2>&1)
  if [ "$actual" = "$expected_keys" ]; then
    echo "  PASS  $label (.$path keys = $expected_keys)"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — .$path key-set expected=$expected_keys actual=$actual"
    fail=$((fail + 1))
  fi
}

# ════════════════════════════════════════════════════════════════════════
# Scenario A — Classify all 9 ADR-020 worked-example EB strings
# Regression-lock fixture. If any of these stops matching, audience_tier
# auto-classification is broken and import-campaign produces wrong manifests.
# ════════════════════════════════════════════════════════════════════════
run_a_classify_worked_examples() {
  echo "--- A: classify-name on 9 ADR-020 worked examples ---"

  invoke_classify "Professional Emails"
  assert_rc "A1: Professional Emails — rc=0" 0
  assert_json_value "A1: tier=professional" "tier" "professional"
  assert_json_value "A1: seniority=None" "seniority" "__NONE__"
  assert_json_value "A1: modifiers=[]" "modifiers" "[]"

  invoke_classify "Professional Emails | All ESPs"
  assert_json_value "A2: tier=professional" "tier" "professional"
  assert_json_value "A2: seniority=None" "seniority" "__NONE__"

  invoke_classify "Role Emails | All ESPs"
  assert_json_value "A3: tier=role" "tier" "role"
  assert_json_value "A3: seniority=None" "seniority" "__NONE__"

  invoke_classify "Personal Emails | All ESPs"
  assert_json_value "A4: tier=personal" "tier" "personal"

  invoke_classify "Bar Owners, GMs | General Emails"
  assert_json_value "A5: tier=general" "tier" "general"
  assert_json_value "A5: seniority=bar-owners-gms" "seniority" "bar-owners-gms"

  invoke_classify "Bars Owners, GMs | Personal Emails"
  assert_json_value "A6: tier=personal" "tier" "personal"
  assert_json_value "A6: typo 'Bars' still classifies seniority=bar-owners-gms" "seniority" "bar-owners-gms"

  invoke_classify "Employees | Professional Emails"
  assert_json_value "A7: tier=professional" "tier" "professional"
  assert_json_value "A7: seniority=employees" "seniority" "employees"

  invoke_classify "Managers+ | All ESPs"
  assert_json_value "A8: seniority=managers-plus" "seniority" "managers-plus"
  # Per ADR-020: tier defaults from sibling records — helper default is
  # `professional` when no tier substring matches.
  assert_json_value "A8: tier defaults to professional" "tier" "professional"

  invoke_classify "Managers+ (Reverified) | All ESPs"
  assert_json_value "A9: seniority=managers-plus" "seniority" "managers-plus"
  assert_json_value "A9: modifiers=[reverified]" "modifiers" '["reverified"]'

  invoke_classify "Managers+ | Professional Emails | All ESPs"
  assert_json_value "A10: tier=professional" "tier" "professional"
  assert_json_value "A10: seniority=managers-plus" "seniority" "managers-plus"

  invoke_classify "Professional Emails | All ESPs | Direct Question Offer"
  assert_json_value "A11: tier=professional" "tier" "professional"
  assert_json_value "A11: modifiers=[direct-question-offer]" "modifiers" '["direct-question-offer"]'
}

# ════════════════════════════════════════════════════════════════════════
# Scenario B — compose with empty eb_records (cohort-1 shape)
# ════════════════════════════════════════════════════════════════════════
run_b_compose_empty_records() {
  echo "--- B: compose with empty eb_records[] ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {
    "milestone_id": "17450de2-f8f2-4107-8625-c07594e06066",
    "milestone_url": "https://linear.app/brite-nites/project/brite-gtm-fa8fc238ef28",
    "project": "Brite GTM"
  },
  "salesforce_campaign_id": null,
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02",
  "eb_records": [],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "B: compose rc=0" 0
  assert_json_value "B: schema_version=2" "schema_version" "2"
  assert_json_value "B: scaffolded_by=/marketing:import-campaign" "scaffolded_by" "/marketing:import-campaign"
  assert_json_value "B: empty campaigns[]" "email_bison.campaigns" "[]"
  assert_json_value "B: workspace retained" "email_bison.workspace" "emailbison-b2b"
  assert_json_value "B: salesforce.campaign_id null" "salesforce.campaign_id" "__NONE__"
  assert_NOT_substr "B: legacy singular campaign_id removed" '"campaign_id":[[:space:]]*[0-9]+'
}

# ════════════════════════════════════════════════════════════════════════
# Scenario C — compose with single launched EB record, auto-classified
# ════════════════════════════════════════════════════════════════════════
run_c_compose_single_record() {
  echo "--- C: compose with 1 launched EB record (auto-classified) ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "bars-restaurants-bar-owner-anchor-audit-fy25-m09",
  "entity": "nites",
  "vertical": "bars-restaurants",
  "persona": "bar-owner",
  "offer": "anchor-audit",
  "year": 2025,
  "month": 9,
  "linear": {
    "milestone_id": "lin-abc",
    "milestone_url": "https://linear.app/brite-nites/project/brite-gtm-x",
    "project": "Brite GTM"
  },
  "salesforce_campaign_id": null,
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "bars-restaurants-bar-owner-anchor-audit-fy25-m09",
  "eb_records": [
    {
      "workspace": "emailbison-b2b",
      "campaign_id": 10,
      "name": "FY25, M09 | Bars | Managers+ | Professional Emails | All ESPs",
      "status": "completed",
      "launched_at": "2025-09-20T08:00:00Z"
    }
  ],
  "created_at": "2025-09-20T08:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "C: compose rc=0" 0
  assert_json_value "C: record[0] tier auto-classified=professional" "email_bison.campaigns.0.audience_tier.tier" "professional"
  assert_json_value "C: record[0] seniority=managers-plus" "email_bison.campaigns.0.audience_tier.seniority" "managers-plus"
  assert_json_value "C: record[0] status preserved" "email_bison.campaigns.0.status" "completed"
  assert_json_value "C: record[0] launched_at preserved" "email_bison.campaigns.0.launched_at" "2025-09-20T08:00:00Z"
  assert_NOT_substr "C: no pending_classification flag (operator confirmed)" '"pending_classification"'
}

# ════════════════════════════════════════════════════════════════════════
# Scenario D — compose with multiple EB records across workspaces
# ════════════════════════════════════════════════════════════════════════
run_d_compose_multi_record() {
  echo "--- D: compose with 3 EB records (multi-workspace + multi-tier) ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "bars-restaurants-bar-owner-anchor-audit-fy25-m09",
  "entity": "nites",
  "vertical": "bars-restaurants",
  "persona": "bar-owner",
  "offer": "anchor-audit",
  "year": 2025,
  "month": 9,
  "linear": {
    "milestone_id": "lin-abc",
    "milestone_url": "https://linear.app/brite-nites/project/brite-gtm-x",
    "project": "Brite GTM"
  },
  "salesforce_campaign_id": null,
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "bars-restaurants-bar-owner-anchor-audit-fy25-m09",
  "eb_records": [
    {"workspace": "emailbison-b2b", "campaign_id": 8,
     "name": "FY25, M09 | Bars | Bar Owners, GMs | General Emails",
     "status": "archived", "launched_at": "2025-09-15T10:00:00Z"},
    {"workspace": "emailbison-b2b", "campaign_id": 10,
     "name": "FY25, M09 | Bars | Managers+ | Professional Emails | All ESPs",
     "status": "completed", "launched_at": "2025-09-20T08:00:00Z"},
    {"workspace": "emailbison-personal", "campaign_id": 42,
     "name": "FY25, M09 | Bars | Bars Owners, GMs | Personal Emails",
     "status": "completed", "launched_at": "2025-09-22T09:00:00Z"}
  ],
  "created_at": "2025-09-15T10:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "D: compose rc=0" 0
  # Targeted per-record assertions — avoids brittle whole-array literal that
  # would break on benign serialization changes or new optional fields.
  assert_json_value "D: record[0] tier=general (bar owners)" "email_bison.campaigns.0.audience_tier.tier" "general"
  assert_json_value "D: record[0] seniority=bar-owners-gms" "email_bison.campaigns.0.audience_tier.seniority" "bar-owners-gms"
  assert_json_value "D: record[0] workspace=b2b" "email_bison.campaigns.0.workspace" "emailbison-b2b"
  assert_json_value "D: record[1] tier=professional (managers+)" "email_bison.campaigns.1.audience_tier.tier" "professional"
  assert_json_value "D: record[1] seniority=managers-plus" "email_bison.campaigns.1.audience_tier.seniority" "managers-plus"
  assert_json_value "D: record[2] workspace=personal (multi-workspace)" "email_bison.campaigns.2.workspace" "emailbison-personal"
  assert_json_value "D: record[2] tier=personal" "email_bison.campaigns.2.audience_tier.tier" "personal"
  assert_json_value "D: record[2] seniority=bar-owners-gms (typo-tolerant)" "email_bison.campaigns.2.audience_tier.seniority" "bar-owners-gms"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario E — compose rejects invalid slug
# ════════════════════════════════════════════════════════════════════════
run_e_compose_rejects_bad_slug() {
  echo "--- E: compose rejects malformed slug ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "Bad_Slug_Underscore",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {"milestone_id": "x", "milestone_url": "https://x", "project": "Brite GTM"},
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "x",
  "eb_records": [],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "E: rejects bad slug rc=1" 1
  # Pin to the helper's specific error string — guards against a future
  # validation re-route firing a different "kebab-case" error first.
  assert_substr "E: error from slug-validator specifically" "slug failed campaign-slug"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario F — compose rejects invalid entity
# ════════════════════════════════════════════════════════════════════════
run_f_compose_rejects_bad_entity() {
  echo "--- F: compose rejects invalid entity ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "x-y-z-fy26-m02",
  "entity": "brite-labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {"milestone_id": "x", "milestone_url": "https://x", "project": "Brite GTM"},
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "x",
  "eb_records": [],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "F: rejects entity=brite-labs rc=1" 1
  # Pin to the entity-prefix path. "entity must be one of" also matches the
  # eb_workspace allowlist error (helper uses parallel phrasing); the
  # leading-anchor check disambiguates.
  assert_substr "F: error from entity-validator specifically" "^ERROR: entity must be one of"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario G — compose rejects invalid eb_record workspace
# ════════════════════════════════════════════════════════════════════════
run_g_compose_rejects_bad_eb_workspace() {
  echo "--- G: compose rejects invalid eb_record.workspace ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "x-y-z-fy26-m02",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {"milestone_id": "x", "milestone_url": "https://x", "project": "Brite GTM"},
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "x",
  "eb_records": [
    {"workspace": "emailbison-broken", "campaign_id": 1, "name": "x"}
  ],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "G: rejects bad eb_record workspace rc=1" 1
  # Pin to the eb_record-prefix path specifically — guards against an upstream
  # eb_workspace validator firing first against an unrelated bad value.
  assert_substr "G: error from eb_record.workspace path specifically" "eb_record.workspace must be one of"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario H — compose rejects missing required field
# ════════════════════════════════════════════════════════════════════════
run_h_compose_rejects_missing_field() {
  echo "--- H: compose rejects missing required field (slug) ---"
  local payload
  payload=$(cat <<'EOF'
{
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {"milestone_id": "x", "milestone_url": "https://x", "project": "Brite GTM"},
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "x",
  "eb_records": [],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "H: rejects missing slug rc=1" 1
  assert_substr "H: error names missing slug" "input missing required field: slug"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario I — compose rejects non-numeric campaign_id string
# ════════════════════════════════════════════════════════════════════════
run_i_compose_rejects_bad_campaign_id() {
  echo "--- I: compose rejects non-numeric campaign_id string ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "x-y-z-fy26-m02",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {"milestone_id": "x", "milestone_url": "https://x", "project": "Brite GTM"},
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "x",
  "eb_records": [
    {"workspace": "emailbison-b2b", "campaign_id": "abc-def", "name": "x"}
  ],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "I: rejects non-numeric campaign_id rc=1" 1
  # Pin to the specific "string must be numeric" path — guards against a
  # generic type-error path passing the looser substring check.
  assert_substr "I: error from string-must-be-numeric path" "campaign_id string must be numeric"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario J — compose passes through explicit audience_tier (operator override)
# ════════════════════════════════════════════════════════════════════════
run_j_compose_audience_tier_override() {
  echo "--- J: compose passes through explicit audience_tier (operator override) ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "x-y-z-fy26-m02",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {"milestone_id": "x", "milestone_url": "https://x", "project": "Brite GTM"},
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "x",
  "eb_records": [
    {"workspace": "emailbison-b2b", "campaign_id": 99,
     "name": "Some Free-Form String The Classifier Won't Match",
     "audience_tier": {"tier": "role", "seniority": null, "modifiers": ["reverified"]}}
  ],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "J: compose rc=0" 0
  assert_json_value "J: override tier=role" "email_bison.campaigns.0.audience_tier.tier" "role"
  assert_json_value "J: override seniority=null" "email_bison.campaigns.0.audience_tier.seniority" "__NONE__"
  assert_json_value "J: override modifiers preserved" "email_bison.campaigns.0.audience_tier.modifiers" '["reverified"]'
}

# ════════════════════════════════════════════════════════════════════════
# Scenario K — classify-name --default-tier override
# ════════════════════════════════════════════════════════════════════════
run_k_classify_default_tier_override() {
  echo "--- K: classify-name --default-tier override ---"
  # "Managers+ | All ESPs" has no tier substring; default-tier picks the fallback.
  invoke_classify_default "Managers+ | All ESPs" "role"
  assert_rc "K1: rc=0" 0
  assert_json_value "K1: default override tier=role" "tier" "role"
  assert_json_value "K1: seniority still classified=managers-plus" "seniority" "managers-plus"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario L — cohort-1 reproduction probe
# Compose with cohort-1's canonical inputs + empty eb_records[] produces a
# manifest that's structurally identical to the live cohort-1 manifest on
# every field EXCEPT scaffolded_by + migrated_from (which import-campaign
# would never write). This proves the BC-11849 validation criterion
# "Backfill of a known existing campaign produces a manifest indistinguishable
# from what plan-campaign would have produced if σ3 had succeeded."
# ════════════════════════════════════════════════════════════════════════
run_l_cohort_one_reproduction() {
  echo "--- L: cohort-1 reproduction probe ---"
  local payload
  payload=$(cat <<'EOF'
{
  "slug": "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02",
  "entity": "labs",
  "vertical": "hotels-resorts",
  "persona": "director-of-resort-experience",
  "offer": "holiday-anchor-audit",
  "year": 2026,
  "month": 2,
  "linear": {
    "milestone_id": "17450de2-f8f2-4107-8625-c07594e06066",
    "milestone_url": "https://linear.app/brite-nites/project/brite-gtm-fa8fc238ef28",
    "project": "Brite GTM"
  },
  "salesforce_campaign_id": null,
  "eb_workspace": "emailbison-b2b",
  "eb_campaign_name": "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02",
  "eb_records": [],
  "created_at": "2026-02-01T00:00:00Z"
}
EOF
)
  invoke_compose "$payload"
  assert_rc "L: compose rc=0" 0
  assert_json_value "L: slug matches cohort-1" "slug" "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02"
  assert_json_value "L: entity=labs" "entity" "labs"
  assert_json_value "L: vertical=hotels-resorts" "vertical" "hotels-resorts"
  assert_json_value "L: linear.milestone_id matches" "linear.milestone_id" "17450de2-f8f2-4107-8625-c07594e06066"
  assert_json_value "L: email_bison.campaigns is empty array" "email_bison.campaigns" "[]"
  assert_json_value "L: salesforce.campaign_name = slug" "salesforce.campaign_name" "hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02"
  # Distinguishing field: scaffolded_by — proves the importer asserts itself.
  assert_json_value "L: scaffolded_by=/marketing:import-campaign" "scaffolded_by" "/marketing:import-campaign"

  # KEY-SET LOCK — the load-bearing "indistinguishable from plan-campaign"
  # assertion. Pin the top-level key-set + all required nested object key-sets.
  # Adding/dropping/renaming a top-level field forces a corresponding test
  # update; this is the regression-guard the BC-11849 brief requires
  # ("Backfill produces a manifest indistinguishable from what plan-campaign
  # would have produced if σ3 had succeeded").
  assert_json_keyset "L: top-level key-set locked" "" \
    "created_at,email_bison,entity,linear,month,offer,persona,salesforce,scaffolded_by,schema_version,slug,vertical,year"
  assert_json_keyset "L: linear sub-keys locked" "linear" \
    "milestone_id,milestone_url,project"
  assert_json_keyset "L: salesforce sub-keys locked" "salesforce" \
    "campaign_id,campaign_name"
  assert_json_keyset "L: email_bison sub-keys locked" "email_bison" \
    "campaign_name,campaigns,workspace"
  assert_json_value "L: schema_version=2 (NOT v1)" "schema_version" "2"

  # GOLDEN-FIXTURE STRUCTURAL DIFF — load the live cohort-1 manifest from the
  # repo and diff its top-level key-set against the composer output. Excludes
  # only `migrated_from` (audit-only field from the v1→v2 migration, never
  # written by /marketing:import-campaign).
  cohort_manifest="$script_dir/../../../docs/campaigns/labs/hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02/manifest.json"
  if [ -f "$cohort_manifest" ]; then
    # Path passed via env var (COHORT_MANIFEST) — never interpolated into the
    # python -c source — so a path containing a quote can't break the inline
    # script (matches the assert_json_value / Scenario O convention).
    cohort_keys=$(COHORT_MANIFEST="$cohort_manifest" python3 -c "
import json, os, sys
with open(os.environ['COHORT_MANIFEST']) as f:
    d = json.load(f)
keys = sorted(k for k in d.keys() if k != 'migrated_from')
sys.stdout.write(','.join(keys))
")
    composed_keys=$(printf '%s' "$LAST_OUTPUT" | python3 -c "
import json, sys
sys.stdout.write(','.join(sorted(json.loads(sys.stdin.read()).keys())))
")
    if [ "$cohort_keys" = "$composed_keys" ]; then
      echo "  PASS  L: composed key-set matches live cohort-1 manifest (modulo migrated_from)"
      pass=$((pass + 1))
    else
      echo "  FAIL  L: composed key-set DIVERGES from live cohort-1 manifest"
      echo "    cohort-1 keys:  $cohort_keys"
      echo "    composed keys:  $composed_keys"
      fail=$((fail + 1))
    fi
  else
    echo "  FAIL  L: cohort-1 reference manifest not found at $cohort_manifest"
    fail=$((fail + 1))
  fi
}

# ════════════════════════════════════════════════════════════════════════
# Scenario M — missing canonicals manifest → exit 2
# ════════════════════════════════════════════════════════════════════════
run_m_missing_canonicals() {
  echo "--- M: missing canonicals manifest → exit 2 ---"
  LAST_OUTPUT="$(python3 "$HELPER" classify-name --eb-name "Professional Emails" --canonicals-manifest "$tmproot/nonexistent.yaml" 2>&1)"
  LAST_RC=$?
  assert_rc "M: rc=2" 2
  assert_substr "M: error names missing manifest" "canonicals manifest not found"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario N — spec-file static-grep checks (defense against drift)
# ════════════════════════════════════════════════════════════════════════
run_n_spec_static_checks() {
  echo "--- N: import-campaign.md spec static-grep checks ---"
  local spec="$script_dir/../commands/import-campaign.md"
  if [ ! -f "$spec" ]; then
    echo "  FAIL  N: import-campaign.md spec not found at $spec"
    fail=$((fail + 1)); return
  fi
  # N1: spec cites BC-11849 + BC-11852 + ADR-020 + the helper path
  if grep -q "BC-11849" "$spec"; then
    echo "  PASS  N1: spec cites BC-11849"; pass=$((pass + 1))
  else
    echo "  FAIL  N1: spec does NOT cite BC-11849"; fail=$((fail + 1))
  fi
  if grep -q "BC-11852" "$spec"; then
    echo "  PASS  N2: spec cites BC-11852"; pass=$((pass + 1))
  else
    echo "  FAIL  N2: spec does NOT cite BC-11852"; fail=$((fail + 1))
  fi
  if grep -q "ADR-020" "$spec"; then
    echo "  PASS  N3: spec cites ADR-020"; pass=$((pass + 1))
  else
    echo "  FAIL  N3: spec does NOT cite ADR-020"; fail=$((fail + 1))
  fi
  if grep -q "import_campaign.py" "$spec"; then
    echo "  PASS  N4: spec cites the helper path"; pass=$((pass + 1))
  else
    echo "  FAIL  N4: spec does NOT cite import_campaign.py"; fail=$((fail + 1))
  fi
  # N5: spec warns against get_campaign (per tracker observation)
  if grep -q "get_campaign" "$spec"; then
    echo "  PASS  N5: spec mentions get_campaign (presumably warning against it)"; pass=$((pass + 1))
  else
    echo "  FAIL  N5: spec does NOT mention get_campaign 404 gotcha"; fail=$((fail + 1))
  fi
  # N6: spec uses the literal /marketing:import-campaign scaffolded_by string.
  # Single canonical check — no || short-circuit (per security review, the
  # `||` made the literal-string variant unenforced).
  if grep -q '"/marketing:import-campaign"' "$spec"; then
    echo "  PASS  N6: spec uses literal /marketing:import-campaign scaffolded_by string"; pass=$((pass + 1))
  else
    echo "  FAIL  N6: spec missing literal /marketing:import-campaign scaffolded_by"; fail=$((fail + 1))
  fi
  # N7: spec asserts schema_version 2 (NOT 1)
  if grep -qE 'schema[ _-]?(v2|version 2|version: 2|v2 \(BC)' "$spec"; then
    echo "  PASS  N7: spec asserts schema v2"; pass=$((pass + 1))
  else
    echo "  FAIL  N7: spec does NOT assert schema v2"; fail=$((fail + 1))
  fi
  # N8: idempotency gate is documented at Step 3.3 (defense against silent regression).
  # Triad-strength lock per [[pattern-rubric-lock-grep-triad]]: catchphrase +
  # structural-clause + load-bearing-behavior assertion. A future editor who
  # deletes the bash gate code while leaving the prose intact would now fail
  # N8b (structural pattern) — deleting the prose fails N8a.
  if grep -qE 'Step 3\.3|idempotency gate|existing-manifest' "$spec"; then
    echo "  PASS  N8a: spec documents idempotency gate (prose)"; pass=$((pass + 1))
  else
    echo "  FAIL  N8a: spec missing idempotency-gate prose"; fail=$((fail + 1))
  fi
  if grep -qE 'if \[ -f .*manifest_path.*\]' "$spec" && grep -qE 'exit 0' "$spec"; then
    echo "  PASS  N8b: spec contains structural -f gate + early exit 0"; pass=$((pass + 1))
  else
    echo "  FAIL  N8b: spec missing structural -f gate or early-exit (gate dropped?)"; fail=$((fail + 1))
  fi
  # N8c: forbidden-pattern check — verify no "use get_campaign" or "prefer
  # get_campaign" guidance has crept in (defense against the documented
  # 404 gotcha being silently rolled back).
  if grep -qiE 'use get_campaign|prefer get_campaign|switch to get_campaign' "$spec"; then
    echo "  FAIL  N8c: spec recommends get_campaign — gotcha-rollback risk"; fail=$((fail + 1))
  else
    echo "  PASS  N8c: spec does NOT recommend get_campaign (gotcha intact)"; pass=$((pass + 1))
  fi
  # N9: ADR-020 worked-examples table row count is pinned. Drift detection —
  # adding/removing a row in ADR-020 § Worked examples should force a paired
  # update to Scenario A in this harness.
  adr="$script_dir/../../../docs/decisions/020-gtm-campaign-manifest-schema-v2.md"
  if [ -f "$adr" ]; then
    # Flag-based range (NOT awk's /start/,/end/ — the end pattern /^### / also
    # matches the start line, collapsing the range to one line → 0 rows). Set the
    # flag AFTER the start heading; clear it at the next ### sibling heading.
    row_count=$(awk '/^### Worked examples/{f=1;next} /^### /{f=0} f' "$adr" | grep -c '^| `')
    if [ "$row_count" -eq 11 ]; then
      echo "  PASS  N9: ADR-020 worked-examples row count = 11 (matches Scenario A)"; pass=$((pass + 1))
    else
      echo "  FAIL  N9: ADR-020 worked-examples row count = $row_count (Scenario A expects 11)"; fail=$((fail + 1))
    fi
  else
    echo "  FAIL  N9: ADR-020 not found at $adr"; fail=$((fail + 1))
  fi
}

# ════════════════════════════════════════════════════════════════════════
# Scenario O — master-index.json real-data classify sweep (ground truth)
# Classifies EVERY distinct EB campaign-name string observed in the
# BC-11851 reconciliation data (docs/reconciliation/master-index.json) —
# the actual backfill worklist BC-11850 will feed this command — and asserts
# NO genuine fall-through: every real string yields at least one captured
# axis signal (an explicit tier token OR a seniority slug). Free-form test
# campaigns are explicitly excused. This ground-truths the classifier against
# PRODUCTION data, not just the 11 synthetic ADR worked examples in Scenario A.
# Robust to master-index growth: new real strings carry tier/seniority tokens
# so they pass without edits; a novel unparseable EB-name pattern (a real
# classifier gap) fails loudly. (BC-11849 grill — condition-2 ground-truth.)
# ════════════════════════════════════════════════════════════════════════
run_o_master_index_sweep() {
  echo "--- O: master-index.json real-data classify sweep ---"
  local master_index="$script_dir/../../../docs/reconciliation/master-index.json"
  if [ ! -f "$master_index" ]; then
    echo "  FAIL  O: master-index.json not found at $master_index"
    fail=$((fail + 1)); return
  fi
  local helper_dir; helper_dir="$(dirname "$HELPER")"
  local out
  out=$(HELPER_DIR="$helper_dir" CANON="$canonicals" MASTER_INDEX="$master_index" python3 -c '
import json, os, sys
sys.path.insert(0, os.environ["HELPER_DIR"])
import import_campaign as ic
from pathlib import Path
tiers = ic._read_audience_tiers(Path(os.environ["CANON"]))
# (slug, token) pairs per tier — used to compute the EXPECTED tier from the
# longest matching token, mirroring classify_name. This makes the classifier
# OUTPUT load-bearing: a stubbed/always-default classifier produces mismatches.
tier_pairs = [(e["slug"], t.lower()) for e in tiers if e.get("axis") == "tier"
              for t in e.get("matches", [])]
tier_tokens = [t for _, t in tier_pairs]
d = json.load(open(os.environ["MASTER_INDEX"]))
names = set()
for r in d.get("rows", []):
    for c in (r.get("eb_campaigns") or []):
        n = c.get("name") if isinstance(c, dict) else (c if isinstance(c, str) else None)
        if n:
            names.add(n)
    for t in (r.get("audience_tiers") or []):
        if isinstance(t, str):
            names.add(t)
gaps = []
misclass = []        # name has a tier token but classifier tier != longest-token tier
token_derived = 0    # names whose tier the classifier genuinely derived from a token
for n in sorted(names):
    obj = ic.classify_name(n, tiers)
    low = n.lower()
    present = [(slug, tok) for slug, tok in tier_pairs if tok in low]
    has_tier_token = bool(present)
    has_seniority = obj.get("seniority") is not None
    is_test = "test campaign" in low
    if not (has_tier_token or has_seniority or is_test):
        gaps.append(n)
    if has_tier_token:
        expected = max(present, key=lambda p: len(p[1]))[0]  # longest token wins
        if obj.get("tier") == expected:
            token_derived += 1
        else:
            misclass.append((n, expected, obj.get("tier")))
print("TOTAL", len(names))
print("GAPS", len(gaps))
print("MISCLASS", len(misclass))
print("TOKEN_DERIVED", token_derived)
for g in gaps:
    print("GAP", repr(g))
for n, exp, got in misclass:
    print("MIS", repr(n), "expected", exp, "got", got)
' 2>&1)
  local total gaps misclass token_derived
  total=$(printf '%s\n' "$out" | sed -n 's/^TOTAL \([0-9][0-9]*\)$/\1/p')
  gaps=$(printf '%s\n' "$out" | sed -n 's/^GAPS \([0-9][0-9]*\)$/\1/p')
  misclass=$(printf '%s\n' "$out" | sed -n 's/^MISCLASS \([0-9][0-9]*\)$/\1/p')
  token_derived=$(printf '%s\n' "$out" | sed -n 's/^TOKEN_DERIVED \([0-9][0-9]*\)$/\1/p')
  # Sanity floor: master-index yields ~139 distinct EB strings at authoring time.
  # A >=100 floor guards against a silently-empty parse passing vacuously.
  if [ -n "$total" ] && [ "$total" -ge 100 ]; then
    echo "  PASS  O1: swept $total distinct master-index EB strings (>=100 floor)"; pass=$((pass + 1))
  else
    echo "  FAIL  O1: master-index sweep loaded too few strings (total='$total')"
    printf '%s\n' "$out" | sed 's/^/    /'
    fail=$((fail + 1))
  fi
  if [ "$gaps" = "0" ]; then
    echo "  PASS  O2: zero unparseable EB strings (every real string yields tier or seniority signal)"; pass=$((pass + 1))
  else
    echo "  FAIL  O2: $gaps EB string(s) classify with NO axis signal (classifier gap):"
    printf '%s\n' "$out" | grep '^GAP ' | sed 's/^/    /'
    fail=$((fail + 1))
  fi
  # O3: classifier OUTPUT must match the longest-token-derived tier for EVERY
  # name carrying a tier token — a broken/stub classifier (e.g. always
  # "professional") produces mismatches and fails here.
  if [ "$misclass" = "0" ]; then
    echo "  PASS  O3: classifier tier output matches longest-token expectation on all token-bearing names"; pass=$((pass + 1))
  else
    echo "  FAIL  O3: $misclass name(s) classify to the WRONG tier:"
    printf '%s\n' "$out" | grep '^MIS ' | sed 's/^/    /'
    fail=$((fail + 1))
  fi
  # O4: token-derived floor — proves a substantial population actually exercises
  # the tier-matching path (not just the seniority/default branches).
  if [ -n "$token_derived" ] && [ "$token_derived" -ge 100 ]; then
    echo "  PASS  O4: $token_derived names have a genuinely token-derived tier (>=100 floor)"; pass=$((pass + 1))
  else
    echo "  FAIL  O4: too few token-derived tiers (token_derived='$token_derived'); classifier may be defaulting"
    fail=$((fail + 1))
  fi
}

# ════════════════════════════════════════════════════════════════════════
# Scenario P — classify-name tie-break + modifier accumulation
# The ADR-020 worked examples (Scenario A) never collide on a tier/seniority
# axis, so the docstring-specified longest-token-wins, entry-order tie-break,
# and multi-modifier accumulation branches go unexercised there. These
# synthetic strings force each branch (a shortest-wins mutant survives A but
# dies here). (Review: test-quality P2.)
# ════════════════════════════════════════════════════════════════════════
run_p_classify_edge_cases() {
  echo "--- P: classify-name tie-break + modifier accumulation ---"
  # P1: two tier tokens present — the LONGER token wins ('professional emails'
  # len 19 > 'personal emails' len 15). A shortest-wins mutant returns personal.
  invoke_classify "Professional Emails and also Personal Emails"
  assert_json_value "P1: longest tier token wins (professional)" "tier" "professional"
  # P2: two modifiers accumulate, in _manifest.yaml entry order (reverified
  # before direct-question-offer).
  invoke_classify "Managers+ (Reverified) | Professional Emails | All ESPs | Direct Question Offer"
  assert_json_value "P2: both modifiers accumulate" "modifiers" '["reverified", "direct-question-offer"]'
  assert_json_value "P2: tier professional" "tier" "professional"
  assert_json_value "P2: seniority managers-plus" "seniority" "managers-plus"
  # P3: two equal-length seniority tokens ('Managers+'=9, 'Employees'=9) tie —
  # entry-order winner is managers-plus (declared first in _manifest.yaml).
  invoke_classify "Managers+ Employees | Professional Emails"
  assert_json_value "P3: seniority tie -> entry-order winner managers-plus" "seniority" "managers-plus"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario Q — compose structural-error branches (HARD-FAIL discipline)
# Covers the reachable rc=1 rejection paths E–I don't: the P1 non-dict
# eb_record regression lock (was a raw traceback), eb_records-not-a-list, the
# stdin guards, operator audience_tier shape rejection, and the tightened
# milestone_url/year validators. (Review: code/python/test-quality P1+P2.)
# ════════════════════════════════════════════════════════════════════════
run_q_compose_error_branches() {
  echo "--- Q: compose structural-error branches ---"
  local base_head='{"slug":"x-y-z-fy26-m02","entity":"labs","vertical":"hotels-resorts","persona":"director-of-resort-experience","offer":"holiday-anchor-audit","year":2026,"month":2,'
  local base_tail=',"eb_workspace":"emailbison-b2b","eb_campaign_name":"x","created_at":"2026-02-01T00:00:00Z"}'
  local good_linear='"linear":{"milestone_id":"m","milestone_url":"https://x","project":"Brite GTM"}'

  # Q1 — P1 regression lock: a non-dict eb_records element must be a CLEAN
  # rc=1 error, NEVER an unhandled Python traceback.
  invoke_compose "${base_head}${good_linear},\"eb_records\":[123]${base_tail}"
  assert_rc "Q1: non-dict eb_record rejected rc=1" 1
  assert_substr "Q1: clean 'eb_record must be an object' error" "eb_record must be an object"
  assert_NOT_substr "Q1: no Python traceback leaked" "Traceback \(most recent call last\)"

  # Q2 — eb_records is not a list.
  invoke_compose "${base_head}${good_linear},\"eb_records\":123${base_tail}"
  assert_rc "Q2: non-list eb_records rejected rc=1" 1
  assert_substr "Q2: 'eb_records must be a list'" "eb_records must be a list"

  # Q3 — malformed JSON on stdin.
  invoke_compose '{not valid json'
  assert_rc "Q3: malformed stdin JSON rejected rc=1" 1
  assert_substr "Q3: 'stdin JSON parse failed'" "stdin JSON parse failed"

  # Q4 — operator audience_tier missing required tier.
  invoke_compose "${base_head}${good_linear},\"eb_records\":[{\"workspace\":\"emailbison-b2b\",\"campaign_id\":1,\"audience_tier\":{\"seniority\":null}}]${base_tail}"
  assert_rc "Q4: audience_tier missing tier rejected rc=1" 1
  assert_substr "Q4: 'audience_tier.tier required'" "audience_tier.tier required"

  # Q5 — operator audience_tier with an unknown key (additionalProperties:false).
  invoke_compose "${base_head}${good_linear},\"eb_records\":[{\"workspace\":\"emailbison-b2b\",\"campaign_id\":1,\"audience_tier\":{\"tier\":\"role\",\"bogus\":1}}]${base_tail}"
  assert_rc "Q5: audience_tier unknown key rejected rc=1" 1
  assert_substr "Q5: 'audience_tier has unknown keys'" "audience_tier has unknown keys"

  # Q6 — milestone_url that is not an https URL.
  invoke_compose "${base_head}\"linear\":{\"milestone_id\":\"m\",\"milestone_url\":\"x\",\"project\":\"Brite GTM\"},\"eb_records\":[]${base_tail}"
  assert_rc "Q6: non-https milestone_url rejected rc=1" 1
  assert_substr "Q6: 'milestone_url must be an https'" "milestone_url must be an https"

  # Q7 — year arriving as a string (JSON-stringification bug).
  invoke_compose '{"slug":"x-y-z-fy26-m02","entity":"labs","vertical":"hotels-resorts","persona":"director-of-resort-experience","offer":"holiday-anchor-audit","year":"2026","month":2,"linear":{"milestone_id":"m","milestone_url":"https://x","project":"Brite GTM"},"eb_workspace":"emailbison-b2b","eb_campaign_name":"x","eb_records":[],"created_at":"2026-02-01T00:00:00Z"}'
  assert_rc "Q7: string year rejected rc=1" 1
  assert_substr "Q7: 'year must be an integer'" "year must be an integer"

  # Q8 — created_at with FRACTIONAL seconds + Z must be ACCEPTED (rc=0). Real EB
  # launched_at values carry fractional seconds; Step 6.5 copies them into
  # created_at. Regression lock so CREATED_AT_RE can't narrow back to whole-second.
  invoke_compose '{"slug":"x-y-z-fy26-m02","entity":"labs","vertical":"hotels-resorts","persona":"director-of-resort-experience","offer":"holiday-anchor-audit","year":2026,"month":2,"linear":{"milestone_id":"m","milestone_url":"https://x","project":"Brite GTM"},"eb_workspace":"emailbison-b2b","eb_campaign_name":"x","eb_records":[],"created_at":"2025-09-20T08:00:00.000Z"}'
  assert_rc "Q8: fractional-second created_at accepted rc=0" 0
  assert_json_value "Q8: created_at preserved verbatim" "created_at" "2025-09-20T08:00:00.000Z"

  # Q8b — created_at with an offset zone (+00:00) must also be accepted.
  invoke_compose '{"slug":"x-y-z-fy26-m02","entity":"labs","vertical":"hotels-resorts","persona":"director-of-resort-experience","offer":"holiday-anchor-audit","year":2026,"month":2,"linear":{"milestone_id":"m","milestone_url":"https://x","project":"Brite GTM"},"eb_workspace":"emailbison-b2b","eb_campaign_name":"x","eb_records":[],"created_at":"2025-09-20T08:00:00+00:00"}'
  assert_rc "Q8b: offset-zone created_at accepted rc=0" 0

  # Q8c — but free-form garbage created_at is still REJECTED (guard still bites).
  invoke_compose '{"slug":"x-y-z-fy26-m02","entity":"labs","vertical":"hotels-resorts","persona":"director-of-resort-experience","offer":"holiday-anchor-audit","year":2026,"month":2,"linear":{"milestone_id":"m","milestone_url":"https://x","project":"Brite GTM"},"eb_workspace":"emailbison-b2b","eb_campaign_name":"x","eb_records":[],"created_at":"last tuesday"}'
  assert_rc "Q8c: garbage created_at rejected rc=1" 1
  assert_substr "Q8c: 'created_at must be ISO-8601'" "created_at must be ISO-8601"

  # Q9 — null eb_campaign_name rejected (type/non-empty guard; _require alone
  # would let null through into the manifest).
  invoke_compose '{"slug":"x-y-z-fy26-m02","entity":"labs","vertical":"hotels-resorts","persona":"director-of-resort-experience","offer":"holiday-anchor-audit","year":2026,"month":2,"linear":{"milestone_id":"m","milestone_url":"https://x","project":"Brite GTM"},"eb_workspace":"emailbison-b2b","eb_campaign_name":null,"eb_records":[],"created_at":"2026-02-01T00:00:00Z"}'
  assert_rc "Q9: null eb_campaign_name rejected rc=1" 1
  assert_substr "Q9: 'eb_campaign_name required'" "eb_campaign_name required"
}

# ════════════════════════════════════════════════════════════════════════
# Scenario R — pending_classification SET path (the SET twin of Scenario C's
# absence assertion). A launched record EB returns with a blank/whitespace
# name can't be classified → the helper stamps a placeholder tier AND
# pending_classification:true so it surfaces for operator review (ADR-020 §
# Migration / command Step 9.3). (Review: test-quality P2.)
# ════════════════════════════════════════════════════════════════════════
run_r_pending_classification_set() {
  echo "--- R: pending_classification SET on blank-name record ---"
  invoke_compose '{"slug":"x-y-z-fy26-m02","entity":"labs","vertical":"hotels-resorts","persona":"director-of-resort-experience","offer":"holiday-anchor-audit","year":2026,"month":2,"linear":{"milestone_id":"m","milestone_url":"https://x","project":"Brite GTM"},"eb_workspace":"emailbison-b2b","eb_campaign_name":"x","eb_records":[{"workspace":"emailbison-b2b","campaign_id":7,"name":"   "}],"created_at":"2026-02-01T00:00:00Z"}'
  assert_rc "R: compose rc=0" 0
  assert_json_value "R: pending_classification=true on blank-name record" "email_bison.campaigns.0.pending_classification" "True"
  assert_json_value "R: placeholder tier=professional" "email_bison.campaigns.0.audience_tier.tier" "professional"
  assert_json_value "R: placeholder seniority=null" "email_bison.campaigns.0.audience_tier.seniority" "__NONE__"
}

# ── Run scenarios ────────────────────────────────────────────────────────
echo "Running import_campaign.py regression harness against $HELPER"
echo "Canonicals manifest: $canonicals"
echo ""

run_a_classify_worked_examples
run_b_compose_empty_records
run_c_compose_single_record
run_d_compose_multi_record
run_e_compose_rejects_bad_slug
run_f_compose_rejects_bad_entity
run_g_compose_rejects_bad_eb_workspace
run_h_compose_rejects_missing_field
run_i_compose_rejects_bad_campaign_id
run_j_compose_audience_tier_override
run_k_classify_default_tier_override
run_l_cohort_one_reproduction
run_m_missing_canonicals
run_n_spec_static_checks
run_o_master_index_sweep
run_p_classify_edge_cases
run_q_compose_error_branches
run_r_pending_classification_set

echo ""
echo "RESULT pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
