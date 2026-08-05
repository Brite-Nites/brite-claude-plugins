#!/usr/bin/env bash
# ============================================================================
# Salesforce pre-load — sandbox smoke test (BC-17213)
# ============================================================================
#
# WHAT THIS IS
#   The live-org half of the salesforce-preload tests (SKILL.md "Tier 2"). The
#   Python unit tests prove the LOGIC is right; this proves the actual WRITES
#   behave in a real org — the right fields land, the wrong ones are blocked,
#   and everything is cleaned up after.
#
# WHAT IT CHECKS
#   A. The free-email guard BLOCKS an Account with Website = gmail.com
#      (the original failure — must be rejected, not created).
#   B. A real-domain Account inserts cleanly.
#   C. A net-new Contact lands with Lifecycle_Stage__c=Cold_Prospect,
#      Lead_Status__c=New, owned by Marketing Admin, under that Account.
#   D. A no-person row lands with FirstName blank + LastName = the company,
#      and NO placeholder.
#   E. A matched Contact null on BOTH governed fields is classified as
#      MATCHED_SEED and seeded by real UPDATE-by-Id.
#   F. A matched Contact with either governed field set is classified as
#      MATCHED and left entirely untouched (D2 opt-out).
#   G. A missing Contact Id fails closed before any Salesforce update.
#   Every record it creates, it deletes again at the end (even on failure).
#
# HOW TO RUN IT (Monday, once you have a working sandbox)
#   1. Authenticate your dev sandbox in the browser:
#        sf org login web --alias brite-dev-corinne --instance-url https://test.salesforce.com
#   2. Run this against it:
#        bash plugins/marketing/scripts/preload_sandbox_smoke.sh --target-org brite-dev-corinne
#   3. Read the PASS/FAIL summary at the end. All PASS → the write path is good
#      and this run is the evidence for the ADR-037 conformance row (Step 8).
#
# SAFETY
#   - It REFUSES to run against a non-sandbox org (checks Organization.IsSandbox).
#     This is the guard that makes it impossible to smoke-test in production.
#   - It only ever creates records prefixed "ZZ_PRELOAD_SMOKE" and deletes them.
#   - It is NOT wired into validate.sh / CI — it does DML and is operator-run only.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_ORG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target-org) TARGET_ORG="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TARGET_ORG" ]; then
  echo "ERROR: --target-org <alias> is required (your dev sandbox)." >&2
  exit 2
fi
# Validate the alias shape before interpolating it into any sf shell-out.
case "$TARGET_ORG" in
  *[!a-zA-Z0-9._@-]*) echo "ERROR: --target-org has unexpected characters." >&2; exit 2 ;;
esac

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  PASS  $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL  $1"; }

# --- created-record tracking + cleanup (runs no matter how we exit) ----------
ACCT_ID=""; GMAIL_ACCT_ID=""; C1_ID=""; C2_ID=""; C3_ID=""; C4_ID=""; C5_ID=""
cleanup() {
  echo ""
  echo "Cleaning up test records..."
  for id in "$C1_ID" "$C2_ID" "$C3_ID" "$C4_ID" "$C5_ID"; do
    [ -n "$id" ] && sf data delete record --sobject Contact --record-id "$id" --target-org "$TARGET_ORG" >/dev/null 2>&1 \
      && echo "  deleted Contact $id"
  done
  for id in "$ACCT_ID" "$GMAIL_ACCT_ID"; do
    [ -n "$id" ] && sf data delete record --sobject Account --record-id "$id" --target-org "$TARGET_ORG" >/dev/null 2>&1 \
      && echo "  deleted Account $id"
  done
}
trap cleanup EXIT

jqid() { python3 -c "import json,sys; print(json.load(sys.stdin).get('result',{}).get('id',''))" 2>/dev/null; }
field() { python3 -c "import json,sys
r=json.load(sys.stdin)['result']['records']
v=r[0].get('$1') if r else None
print('' if v is None else v)" 2>/dev/null; }

classify_contact() {
  line=$(classify_contacts "$1" "$2" "$3" "$4")
  printf '%s\n' "${line#*|}"
}

classify_contacts() {
  python3 - "$SCRIPT_DIR" "$@" <<'PY'
import sys

script_dir = sys.argv[1]
args = sys.argv[2:]
sys.path.insert(0, script_dir)

from salesforce_preload import MatchedContact, classify_rows

if len(args) % 4:
    raise SystemExit("expected groups of: email contact_id lifecycle_stage lead_status")

rows = []
contacts_by_email = {}
for i in range(0, len(args), 4):
    email, contact_id, lifecycle_stage, lead_status = args[i:i + 4]
    email = email.strip().lower()
    rows.append({"email": email, "company": "ZZ_PRELOAD_SMOKE Matched", "domain": "example.com"})
    contacts_by_email[email] = [MatchedContact(contact_id, lifecycle_stage or None, lead_status or None)]

plan = classify_rows(rows, contacts_by_email, {})
for row in plan.rows:
    print(f"{row.email}|{row.disposition}|{row.contact_id}")
PY
}

seed_matched_contact() {
  id="${1:-}"
  if [ -z "$id" ]; then
    echo "Refusing matched-seed update: missing Contact Id" >&2
    return 4
  fi
  case "$id" in
    *[!a-zA-Z0-9]*) echo "Refusing matched-seed update: unexpected Contact Id shape" >&2; return 4 ;;
  esac

  sf data update record --sobject Contact --record-id "$id" \
    --values "Lifecycle_Stage__c='Cold_Prospect' Lead_Status__c='New'" \
    --target-org "$TARGET_ORG" --json >/dev/null 2>&1
}

apply_matched_seed_plan() {
  disposition="${1:-}"
  target_id="${2:-}"

  case "$disposition" in
    matched_seed) seed_matched_contact "$target_id" ;;
    matched) return 0 ;;
    *) echo "Refusing matched-seed write: unexpected disposition '$disposition'" >&2; return 4 ;;
  esac
}

apply_matched_seed_plan_lines() {
  plan_lines="${1:-}"

  printf '%s\n' "$plan_lines" | while IFS='|' read -r _email disposition target_id; do
    [ -z "$_email$disposition$target_id" ] && continue
    apply_matched_seed_plan "$disposition" "$target_id" || exit $?
  done
}

force_contact_seed_state() {
  id="${1:-}"
  mode="${2:-}"
  case "$id" in
    ""|*[!a-zA-Z0-9]*) return 4 ;;
  esac

  apex_file="$(mktemp "${TMPDIR:-/tmp}/preload-smoke-apex.XXXXXX")"
  case "$mode" in
    both_null)
      cat > "$apex_file" <<APEX
Contact c = [SELECT Id, Lifecycle_Stage__c, Lead_Status__c FROM Contact WHERE Id = '$id' LIMIT 1];
c.Lifecycle_Stage__c = null;
c.Lead_Status__c = null;
update c;
APEX
      ;;
    dnp_status_null)
      cat > "$apex_file" <<APEX
Contact c = [SELECT Id, Lifecycle_Stage__c, Lead_Status__c FROM Contact WHERE Id = '$id' LIMIT 1];
c.Lifecycle_Stage__c = 'Do_Not_Prospect';
c.Lead_Status__c = null;
update c;
APEX
      ;;
    *)
      rm -f "$apex_file"
      return 4
      ;;
  esac

  sf apex run --file "$apex_file" --target-org "$TARGET_ORG" --json >/dev/null 2>&1
  status=$?
  rm -f "$apex_file"
  return "$status"
}

# --- hard production guard ---------------------------------------------------
echo "=== Salesforce pre-load sandbox smoke test ==="
echo "Target org: $TARGET_ORG"
IS_SANDBOX=$(sf data query --query "SELECT IsSandbox FROM Organization" --target-org "$TARGET_ORG" --json 2>/dev/null \
  | python3 -c "import json,sys
try: print(str(json.load(sys.stdin)['result']['records'][0]['IsSandbox']))
except Exception: print('UNKNOWN')" 2>/dev/null)
if [ "$IS_SANDBOX" != "True" ]; then
  echo "REFUSING TO RUN: Organization.IsSandbox = '$IS_SANDBOX' (need True)." >&2
  echo "This smoke test writes records and must ONLY run against a sandbox." >&2
  trap - EXIT   # nothing was created yet
  exit 3
fi
echo "Confirmed sandbox (IsSandbox=True). Proceeding."
echo ""

# --- resolve the Marketing Admin owner --------------------------------------
OWNER_ID=$(sf data query --query "SELECT Id FROM User WHERE Username='marketingadmin@britenites.com'" \
  --target-org "$TARGET_ORG" --json 2>/dev/null | field Id)
if [ -n "$OWNER_ID" ]; then
  echo "Marketing Admin owner: $OWNER_ID"
else
  echo "NOTE: Marketing Admin user not found in this sandbox — owner-assignment check skipped."
fi
echo ""

STAMP=$(date +%s)

# --- Check A: the free-email guard must BLOCK a gmail.com website ------------
echo "Check A — gmail.com website must be blocked:"
A_OUT=$(sf data create record --sobject Account \
  --values "Name='ZZ_PRELOAD_SMOKE Gmail $STAMP' Website='gmail.com'" \
  --target-org "$TARGET_ORG" --json 2>&1)
if echo "$A_OUT" | grep -q '"status": 0'; then
  GMAIL_ACCT_ID=$(echo "$A_OUT" | jqid)   # it wrongly succeeded — track for cleanup
  bad "gmail.com Account was CREATED — the free-email guard is NOT active in this org"
else
  ok "gmail.com Account rejected (guard active)"
fi
echo ""

# --- Check B: a real-domain Account inserts ---------------------------------
echo "Check B — real-domain Account inserts:"
ACCT_ID=$(sf data create record --sobject Account \
  --values "Name='ZZ_PRELOAD_SMOKE Winery $STAMP' Website='dubykwinery-$STAMP.com'" \
  --target-org "$TARGET_ORG" --json 2>/dev/null | jqid)
if [ -n "$ACCT_ID" ]; then ok "real Account created ($ACCT_ID)"; else bad "real Account did not insert"; fi
echo ""

# --- Check C: net-new Contact with the seed fields --------------------------
echo "Check C — net-new Contact seeds Cold_Prospect / New, owned by Marketing Admin:"
if [ -n "$ACCT_ID" ]; then
  OWNER_CLAUSE=""; [ -n "$OWNER_ID" ] && OWNER_CLAUSE=" OwnerId='$OWNER_ID'"
  C1_ID=$(sf data create record --sobject Contact \
    --values "FirstName='Joe' LastName='Dubyk' Email='zz-preload-smoke-$STAMP@gmail.com' AccountId='$ACCT_ID' Lifecycle_Stage__c='Cold_Prospect' Lead_Status__c='New'$OWNER_CLAUSE" \
    --target-org "$TARGET_ORG" --json 2>/dev/null | jqid)
  if [ -n "$C1_ID" ]; then
    Q=$(sf data query --query "SELECT FirstName,LastName,Lifecycle_Stage__c,Lead_Status__c,AccountId,OwnerId FROM Contact WHERE Id='$C1_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
    [ "$(echo "$Q" | field Lifecycle_Stage__c)" = "Cold_Prospect" ] && ok "Lifecycle_Stage__c = Cold_Prospect" || bad "Lifecycle_Stage__c did not land"
    [ "$(echo "$Q" | field Lead_Status__c)" = "New" ] && ok "Lead_Status__c = New" || bad "Lead_Status__c did not land"
    [ "$(echo "$Q" | field AccountId)" = "$ACCT_ID" ] && ok "parented to the real Account" || bad "AccountId did not land"
    if [ -n "$OWNER_ID" ]; then
      [ "$(echo "$Q" | field OwnerId)" = "$OWNER_ID" ] && ok "owned by Marketing Admin" || bad "OwnerId is not Marketing Admin"
    fi
  else
    bad "net-new Contact did not insert"
  fi
else
  bad "skipped (no Account from Check B)"
fi
echo ""

# --- Check D: no-person row → company in LastName, blank FirstName -----------
echo "Check D — no-person row: company in LastName, FirstName blank, no placeholder:"
if [ -n "$ACCT_ID" ]; then
  C2_ID=$(sf data create record --sobject Contact \
    --values "LastName='ZZ_PRELOAD_SMOKE Winery $STAMP' Email='zz-preload-nobody-$STAMP@gmail.com' AccountId='$ACCT_ID' Lifecycle_Stage__c='Cold_Prospect' Lead_Status__c='New'" \
    --target-org "$TARGET_ORG" --json 2>/dev/null | jqid)
  if [ -n "$C2_ID" ]; then
    Q=$(sf data query --query "SELECT FirstName,LastName FROM Contact WHERE Id='$C2_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
    fn=$(echo "$Q" | field FirstName); ln=$(echo "$Q" | field LastName)
    [ -z "$fn" ] && ok "FirstName is blank" || bad "FirstName should be blank, got '$fn'"
    echo "$ln" | grep -q "ZZ_PRELOAD_SMOKE Winery" && ok "company is in LastName ('$ln')" || bad "LastName is not the company ('$ln')"
  else
    bad "company-in-LastName Contact did not insert"
  fi
else
  bad "skipped (no Account from Check B)"
fi
echo ""

# --- Check E: matched both-null Contact -> MATCHED_SEED -> UPDATE by Id -----
echo "Check E — matched both-null Contact seeds via real UPDATE-by-Id:"
if [ -n "$ACCT_ID" ]; then
  C3_EMAIL="zz-preload-matched-seed-$STAMP@gmail.com"
  C3_ID=$(sf data create record --sobject Contact \
    --values "LastName='ZZ_PRELOAD_SMOKE Matched Seed $STAMP' Email='$C3_EMAIL' AccountId='$ACCT_ID'" \
    --target-org "$TARGET_ORG" --json 2>/dev/null | jqid)
  if [ -n "$C3_ID" ]; then
    ok "matched-seed fixture Contact created ($C3_ID)"
    if force_contact_seed_state "$C3_ID" both_null; then
      Q=$(sf data query --query "SELECT Lifecycle_Stage__c,Lead_Status__c FROM Contact WHERE Id='$C3_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
      lc=$(echo "$Q" | field Lifecycle_Stage__c); ls=$(echo "$Q" | field Lead_Status__c)
      [ -z "$lc" ] && [ -z "$ls" ] && ok "fixture is blank on both governed fields" || bad "fixture was not both-null before seed (stage='$lc' status='$ls')"

      CLASS=$(classify_contact "$C3_EMAIL" "$C3_ID" "$lc" "$ls")
      DISP="${CLASS%%|*}"; TARGET_ID="${CLASS#*|}"
      [ "$DISP" = "matched_seed" ] && ok "classifier returned MATCHED_SEED" || bad "classifier returned '$DISP' instead of matched_seed"
      [ "$TARGET_ID" = "$C3_ID" ] && ok "MATCHED_SEED carries the Contact Id" || bad "MATCHED_SEED target id was '$TARGET_ID'"

      if [ "$DISP" = "matched_seed" ] && [ "$TARGET_ID" = "$C3_ID" ]; then
        if apply_matched_seed_plan "$DISP" "$TARGET_ID"; then
          Q=$(sf data query --query "SELECT Lifecycle_Stage__c,Lead_Status__c FROM Contact WHERE Id='$C3_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
          [ "$(echo "$Q" | field Lifecycle_Stage__c)" = "Cold_Prospect" ] && ok "matched Contact Lifecycle_Stage__c = Cold_Prospect" || bad "matched Contact Lifecycle_Stage__c was not seeded"
          [ "$(echo "$Q" | field Lead_Status__c)" = "New" ] && ok "matched Contact Lead_Status__c = New" || bad "matched Contact Lead_Status__c was not seeded"
        else
          bad "matched-seed UPDATE-by-Id failed"
        fi
      else
        bad "skipped matched-seed UPDATE because classifier did not produce a safe target"
      fi
    else
      bad "could not prepare both-null matched Contact fixture"
    fi
  else
    bad "matched-seed fixture Contact did not insert"
  fi
else
  bad "skipped (no Account from Check B)"
fi
echo ""

# --- Check F: D2 opt-out, either governed field set -> untouched -------------
echo "Check F — D2 opt-out: matched Contact with one field set is untouched:"
if [ -n "$ACCT_ID" ]; then
  C4_EMAIL="zz-preload-d2-optout-$STAMP@gmail.com"
  C4_ID=$(sf data create record --sobject Contact \
    --values "LastName='ZZ_PRELOAD_SMOKE D2 Optout $STAMP' Email='$C4_EMAIL' AccountId='$ACCT_ID'" \
    --target-org "$TARGET_ORG" --json 2>/dev/null | jqid)
  if [ -n "$C4_ID" ]; then
    ok "D2 opt-out fixture Contact created ($C4_ID)"
    if force_contact_seed_state "$C4_ID" dnp_status_null; then
      Q=$(sf data query --query "SELECT Lifecycle_Stage__c,Lead_Status__c FROM Contact WHERE Id='$C4_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
      before_lc=$(echo "$Q" | field Lifecycle_Stage__c); before_ls=$(echo "$Q" | field Lead_Status__c)
      [ "$before_lc" = "Do_Not_Prospect" ] && [ -z "$before_ls" ] && ok "fixture is Do_Not_Prospect + blank status" || bad "fixture was not in D2 shape (stage='$before_lc' status='$before_ls')"

      C5_EMAIL="zz-preload-d2-control-$STAMP@gmail.com"
      C5_ID=$(sf data create record --sobject Contact \
        --values "LastName='ZZ_PRELOAD_SMOKE D2 Control $STAMP' Email='$C5_EMAIL' AccountId='$ACCT_ID'" \
        --target-org "$TARGET_ORG" --json 2>/dev/null | jqid)
      if [ -n "$C5_ID" ]; then
        ok "D2 control matched-seed fixture Contact created ($C5_ID)"
        if force_contact_seed_state "$C5_ID" both_null; then
          Q=$(sf data query --query "SELECT Lifecycle_Stage__c,Lead_Status__c FROM Contact WHERE Id='$C5_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
          control_lc=$(echo "$Q" | field Lifecycle_Stage__c); control_ls=$(echo "$Q" | field Lead_Status__c)
          [ -z "$control_lc" ] && [ -z "$control_ls" ] && ok "D2 control fixture is blank on both governed fields" || bad "D2 control fixture was not both-null (stage='$control_lc' status='$control_ls')"

          PLAN_LINES=$(classify_contacts \
            "$C4_EMAIL" "$C4_ID" "$before_lc" "$before_ls" \
            "$C5_EMAIL" "$C5_ID" "$control_lc" "$control_ls")
          D2_LINE=$(printf '%s\n' "$PLAN_LINES" | awk -F'|' -v e="$C4_EMAIL" '$1 == e {print; exit}')
          CONTROL_LINE=$(printf '%s\n' "$PLAN_LINES" | awk -F'|' -v e="$C5_EMAIL" '$1 == e {print; exit}')
          D2_DISP=$(echo "$D2_LINE" | cut -d'|' -f2); D2_TARGET=$(echo "$D2_LINE" | cut -d'|' -f3)
          CONTROL_DISP=$(echo "$CONTROL_LINE" | cut -d'|' -f2); CONTROL_TARGET=$(echo "$CONTROL_LINE" | cut -d'|' -f3)
          [ "$D2_DISP" = "matched" ] && ok "write-selection plan keeps D2 row MATCHED, not MATCHED_SEED" || bad "write-selection plan returned '$D2_DISP' for D2 row"
          [ -z "$D2_TARGET" ] && ok "write-selection plan carries no D2 update target" || bad "write-selection plan carried D2 target id '$D2_TARGET'"
          [ "$CONTROL_DISP" = "matched_seed" ] && [ "$CONTROL_TARGET" = "$C5_ID" ] && ok "write-selection plan includes both-null control as MATCHED_SEED" || bad "write-selection plan did not include the control seed target"

          if apply_matched_seed_plan_lines "$PLAN_LINES"; then
            ok "combined write-selection pass completed"
          else
            bad "combined write-selection pass failed"
          fi

          Q=$(sf data query --query "SELECT Lifecycle_Stage__c,Lead_Status__c FROM Contact WHERE Id='$C5_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
          [ "$(echo "$Q" | field Lifecycle_Stage__c)" = "Cold_Prospect" ] && ok "D2 control Contact was seeded by the live update path" || bad "D2 control Contact was not seeded"
          [ "$(echo "$Q" | field Lead_Status__c)" = "New" ] && ok "D2 control Lead_Status__c = New" || bad "D2 control Lead_Status__c was not seeded"

          Q=$(sf data query --query "SELECT Lifecycle_Stage__c,Lead_Status__c FROM Contact WHERE Id='$C4_ID'" --target-org "$TARGET_ORG" --json 2>/dev/null)
          after_lc=$(echo "$Q" | field Lifecycle_Stage__c); after_ls=$(echo "$Q" | field Lead_Status__c)
          [ "$after_lc" = "$before_lc" ] && [ "$after_ls" = "$before_ls" ] && ok "D2 opt-out Contact left entirely untouched while batch seed ran" || bad "D2 opt-out Contact changed (before='$before_lc/$before_ls' after='$after_lc/$after_ls')"
        else
          bad "could not prepare D2 control matched-seed fixture"
        fi
      else
        bad "D2 control matched-seed fixture Contact did not insert"
      fi
    else
      bad "could not prepare D2 opt-out Contact fixture"
    fi
  else
    bad "D2 opt-out fixture Contact did not insert"
  fi
else
  bad "skipped (no Account from Check B)"
fi
echo ""

# --- Check G: missing Contact Id fails closed --------------------------------
echo "Check G — missing matched Contact Id fails closed:"
CLASS=$(classify_contact "zz-preload-missing-id-$STAMP@gmail.com" "" "" "")
DISP="${CLASS%%|*}"; TARGET_ID="${CLASS#*|}"
[ "$DISP" = "matched" ] && ok "classifier does not produce MATCHED_SEED without a Contact Id" || bad "classifier returned '$DISP' for missing Contact Id"
[ -z "$TARGET_ID" ] && ok "missing-id plan carries no update target" || bad "missing-id plan carried target id '$TARGET_ID'"
if apply_matched_seed_plan "matched_seed" ""; then
  bad "empty Contact Id update unexpectedly succeeded"
else
  ok "empty Contact Id refused before Salesforce update"
fi
echo ""

echo "RESULT pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
