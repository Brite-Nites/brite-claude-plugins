#!/usr/bin/env bash
# Behavioral eval for plugins/revops/scripts/promotion_topology.py (BC-19521).
#
# promotion_topology.py is the deterministic decision core behind the ADR-026
# reshape: alias classification, per-developer org resolution, the BLOCKING
# concurrency probe, and the config-gated guidance layer.
#
# The property under test is FAIL-CLOSED. The old Phase 0.5 concurrency lookback
# was prose that said "do not halt the deploy over an advisory check", so a
# Tooling API error read as "nobody else is deploying". Every scenario below
# that feeds the probe a broken, empty, or hostile input asserts a BLOCKING
# verdict — never `clear`.
#
# It also asserts the registry invariant the brite-salesforce PreToolUse hook
# (BC-19519) depends on: every non-`allow` org appears in `protected_aliases`,
# under its own alias and under every `aka`.
#
# Usage:
#   bash plugins/revops/scripts/test_promotion_topology.sh
#   bash plugins/revops/scripts/test_promotion_topology.sh /path/to/promotion_topology.py

set -u  # NOT set -e — non-zero exits are EXPECTED for reject scenarios.

# Defuse caller's git env (matches test_validate_target_org.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD="${1:-$HERE/promotion_topology.py}"
REGISTRY="$HERE/../config/org-aliases.json"

pass=0
fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

# assert_decision <label> <expected-decision> <actual-json>
assert_decision() {
  local label="$1" want="$2" json="$3" got
  got="$(printf '%s' "$json" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("decision",""))
except Exception: print("<unparseable>")' 2>/dev/null)"
  if [ "$got" = "$want" ]; then ok; else bad "$label: expected decision=$want, got=$got"; fi
}

# assert_not_clear <label> <actual-json> — the fail-closed property.
assert_not_clear() {
  local label="$1" json="$2" got
  got="$(printf '%s' "$json" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("decision",""))
except Exception: print("<unparseable>")' 2>/dev/null)"
  case "$got" in
    clear|override) bad "$label: FAIL-OPEN — decision=$got where a block was required" ;;
    *) ok ;;
  esac
}

# ── 1. registry invariant: protected_aliases covers every non-allow org ──────
inv="$(python3 - "$REGISTRY" <<'PY'
import json, sys
reg = json.load(open(sys.argv[1]))
protected = set(reg.get("protected_aliases", []))
missing = []
for org in reg["orgs"]:
    if org.get("enforcement") == "allow":
        continue
    for name in [org["alias"]] + list(org.get("aka", [])):
        if name not in protected:
            missing.append(name)
# Reverse direction: nothing in protected_aliases without a home in orgs[].
known = {n for o in reg["orgs"] for n in [o["alias"]] + list(o.get("aka", []))}
orphans = sorted(protected - known)
print("OK" if not missing and not orphans else f"MISSING={missing} ORPHANS={orphans}")
PY
)"
if [ "$inv" = "OK" ]; then ok; else bad "registry invariant: $inv"; fi

# ── 2. classify ─────────────────────────────────────────────────────────────
assert_decision "classify brite-prod"        block   "$(python3 "$MOD" --classify brite-prod)"
assert_decision "classify brite-integration" block   "$(python3 "$MOD" --classify brite-integration)"
assert_decision "classify briteint (aka)"    block   "$(python3 "$MOD" --classify briteint)"
assert_decision "classify brite-uat"         block   "$(python3 "$MOD" --classify brite-uat)"
assert_decision "classify brite-sandbox"     warn    "$(python3 "$MOD" --classify brite-sandbox)"
assert_decision "classify brite-dev-holden"  allow   "$(python3 "$MOD" --classify brite-dev-holden)"
assert_decision "classify brite-dev-a1"      allow   "$(python3 "$MOD" --classify brite-dev-a1)"
# Unknown and malformed aliases fail CLOSED.
assert_decision "classify unknown alias"     unknown "$(python3 "$MOD" --classify some-other-org)"
assert_decision "classify injection payload" invalid "$(python3 "$MOD" --classify '$(touch pwned)')"
assert_decision "classify empty-ish alias"   invalid "$(python3 "$MOD" --classify ' ')"
# brite-dev-<name> must not match a bare prefix or an uppercase/underscore name.
assert_decision "classify brite-dev- (bare)" unknown "$(python3 "$MOD" --classify brite-dev-)"
assert_decision "classify brite-dev-Holden"  unknown "$(python3 "$MOD" --classify brite-dev-Holden)"

# ── 3. resolve-dev-org ──────────────────────────────────────────────────────
one_dev='{"status":0,"result":{"nonScratchOrgs":[
  {"alias":"brite-dev-holden","username":"h@x.com.bndev","connectedStatus":"Connected"},
  {"alias":"brite-prod","username":"h@x.com","connectedStatus":"Connected"}]}}'
assert_decision "resolve: single dev org" resolved \
  "$(printf '%s' "$one_dev" | python3 "$MOD" --resolve-dev-org -)"

two_dev='{"status":0,"result":{"sandboxes":[
  {"alias":"brite-dev-holden","username":"h@x.com.bndev","connectedStatus":"Connected"},
  {"alias":"brite-dev-kells","username":"k@x.com.bndev","connectedStatus":"Connected"}]}}'
# The headline requirement: two candidates must NEVER silently default to one.
assert_decision "resolve: two dev orgs is ambiguous" ambiguous \
  "$(printf '%s' "$two_dev" | python3 "$MOD" --resolve-dev-org -)"
assert_decision "resolve: ambiguity resolved by --requested" resolved \
  "$(printf '%s' "$two_dev" | python3 "$MOD" --resolve-dev-org - --requested brite-dev-kells)"

no_dev='{"status":0,"result":{"nonScratchOrgs":[
  {"alias":"brite-prod","username":"h@x.com","connectedStatus":"Connected"}]}}'
assert_decision "resolve: no dev org" none \
  "$(printf '%s' "$no_dev" | python3 "$MOD" --resolve-dev-org -)"

# A dev org that is present but NOT Connected is not a candidate.
stale='{"status":0,"result":{"nonScratchOrgs":[
  {"alias":"brite-dev-holden","username":"h@x.com.bndev","connectedStatus":"Unknown"}]}}'
assert_decision "resolve: unconnected dev org is not a candidate" none \
  "$(printf '%s' "$stale" | python3 "$MOD" --resolve-dev-org -)"

# A protected alias asked for explicitly is rejected, not honoured.
assert_decision "resolve: --requested brite-prod rejected" rejected \
  "$(printf '%s' "$one_dev" | python3 "$MOD" --resolve-dev-org - --requested brite-prod)"
assert_decision "resolve: --requested brite-sandbox rejected" rejected \
  "$(printf '%s' "$one_dev" | python3 "$MOD" --resolve-dev-org - --requested brite-sandbox)"

# Unreadable / failed org list is unusable, never a silent pick.
assert_decision "resolve: sf failure is unusable" unusable \
  "$(printf '%s' '{"status":1,"result":{}}' | python3 "$MOD" --resolve-dev-org -)"
assert_decision "resolve: empty payload is unusable" unusable \
  "$(printf '%s' '{"status":0,"result":{}}' | python3 "$MOD" --resolve-dev-org -)"
assert_decision "resolve: garbage payload is unusable" unusable \
  "$(printf '%s' 'not json at all' | python3 "$MOD" --resolve-dev-org - 2>/dev/null)"

# ── 4. concurrency verdict — the fail-closed core ───────────────────────────
empty_ok='{"status":0,"result":{"records":[],"totalSize":0}}'
inflight='{"status":0,"result":{"records":[{"Id":"0Af1","Status":"InProgress","CreatedBy":{"Name":"K"}}]}}'
recent='{"status":0,"result":{"records":[{"Id":"0Af2","Status":"Succeeded","CreatedBy":{"Name":"K"}}]}}'
err='{"status":1,"message":"INVALID_SESSION_ID"}'

probe() { printf '%s' "$1" | python3 "$MOD" --concurrency-verdict - 2>/dev/null; }

assert_decision "probe: nothing running, nothing recent" clear \
  "$(probe "{\"target_org\":\"brite-prod\",\"in_flight\":$empty_ok,\"recent\":$empty_ok}")"

assert_decision "probe: in-flight deploy blocks" blocked_inflight \
  "$(probe "{\"target_org\":\"brite-prod\",\"in_flight\":$inflight,\"recent\":$empty_ok}")"

# An in-flight deploy is NOT overridable — the override flag must not clear it.
assert_decision "probe: override cannot clear an in-flight deploy" blocked_inflight \
  "$(probe "{\"target_org\":\"brite-prod\",\"override\":true,\"in_flight\":$inflight,\"recent\":$empty_ok}")"

assert_decision "probe: recent deploy blocks" blocked_recent \
  "$(probe "{\"target_org\":\"brite-prod\",\"in_flight\":$empty_ok,\"recent\":$recent}")"

assert_decision "probe: recent deploy is overridable" override \
  "$(probe "{\"target_org\":\"brite-prod\",\"override\":true,\"in_flight\":$empty_ok,\"recent\":$recent}")"

# THE regression this whole file exists for: query errors must BLOCK.
assert_decision "probe: in-flight query error blocks" blocked_error \
  "$(probe "{\"target_org\":\"brite-prod\",\"in_flight\":$err,\"recent\":$empty_ok}")"
assert_decision "probe: recent query error blocks" blocked_error \
  "$(probe "{\"target_org\":\"brite-prod\",\"in_flight\":$empty_ok,\"recent\":$err}")"

# Every malformed shape must land on a blocking verdict, never `clear`.
assert_not_clear "probe: missing in_flight key"   "$(probe '{"target_org":"brite-prod","recent":{"status":0,"result":{"records":[]}}}')"
assert_not_clear "probe: missing recent key"      "$(probe '{"target_org":"brite-prod","in_flight":{"status":0,"result":{"records":[]}}}')"
assert_not_clear "probe: records is not a list"   "$(probe '{"in_flight":{"status":0,"result":{"records":"nope"}},"recent":{"status":0,"result":{"records":[]}}}')"
assert_not_clear "probe: result is not an object" "$(probe '{"in_flight":{"status":0,"result":null},"recent":{"status":0,"result":{"records":[]}}}')"
assert_not_clear "probe: empty payload"           "$(probe '{}')"
assert_not_clear "probe: unparseable stdin"       "$(probe 'nope')"
# Even an override flag must not turn a broken probe into a pass.
assert_not_clear "probe: override does not rescue a broken probe" \
  "$(probe "{\"override\":true,\"in_flight\":$err,\"recent\":$err}")"

# Pending / Canceling count as in-flight too.
pending='{"status":0,"result":{"records":[{"Id":"0Af3","Status":"Pending"}]}}'
assert_decision "probe: Pending counts as in-flight" blocked_inflight \
  "$(probe "{\"in_flight\":$pending,\"recent\":$empty_ok}")"

# ── 5. pipeline guidance — config-gated, no-ops where absent ────────────────
box="$(mktemp -d)"
assert_decision "guidance: absent config no-ops" no_config \
  "$(python3 "$MOD" --pipeline-guidance "$box")"

printf 'not json' > "$box/.revops-pipeline.json"
assert_decision "guidance: unreadable config no-ops" unreadable \
  "$(python3 "$MOD" --pipeline-guidance "$box")"

cp "$HERE/../config/pipeline-config.example.json" "$box/.revops-pipeline.json"
guid="$(python3 "$MOD" --pipeline-guidance "$box" --lane integration)"
assert_decision "guidance: valid config guides" guidance "$guid"

# The guidance layer must never claim to enforce (ADR-026 section 5).
enf="$(printf '%s' "$guid" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("enforcing"))')"
if [ "$enf" = "False" ]; then ok; else bad "guidance: enforcing should be False, got $enf"; fi

rm -rf "$box"

# ── 6. no side effects ──────────────────────────────────────────────────────
# The module must not write anything, including when fed injection payloads.
sbox="$(mktemp -d)"
( cd "$sbox" && python3 "$MOD" --classify '$(touch pwned)' >/dev/null 2>&1
  printf '%s' '`touch pwned2`' | python3 "$MOD" --resolve-dev-org - >/dev/null 2>&1 )
if [ -z "$(ls -A "$sbox")" ]; then ok; else bad "side effect: files created: $(ls -A "$sbox")"; fi
rm -rf "$sbox"

printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
