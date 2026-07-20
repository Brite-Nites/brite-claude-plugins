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
ACCT_ID=""; GMAIL_ACCT_ID=""; C1_ID=""; C2_ID=""
cleanup() {
  echo ""
  echo "Cleaning up test records..."
  for id in "$C1_ID" "$C2_ID"; do
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

echo "RESULT pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
