#!/usr/bin/env bash
# Unit / contract suite for plugins/workflows/scripts/build_report_issue_payload.py
# (BC-12944, ADR-028 Phase-2 Batch C).
#
# build_report_issue_payload.py is the PURE deterministic decision core
# /workflows:report-issue delegates to for BOTH its artifacts: the Linear issue
# payload AND the regression-test registry entry. Given the (injected) classification
# + severity + trigger details and the injected reads (Brite-Company labels + the
# existing B## ids), it computes the composite {issue_payload, registry} with NO MCP
# call and NO Linear/registry write. This suite drives the builder directly across
# every classification branch AND proves: the B## next-id allocation, the phrase
# shell-metachar strip, the per-classification expected/not_expected population, the
# routing map, and injection-safety (no shell-out sink). The behavioral eval asserts
# the emit-artifact STRUCTURE; this asserts the per-branch DECISIONS + determinism.
#
# Usage:
#   bash plugins/workflows/scripts/test_build_report_issue_payload.sh
#   bash plugins/workflows/scripts/test_build_report_issue_payload.sh /path/to/build_report_issue_payload.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_report_issue_payload.py}"

if [ ! -f "$BUILDER" ]; then
  echo "FATAL: builder not found: $BUILDER" >&2
  exit 2
fi

pass=0
fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

DECIDE_OUT=""
decide() {
  local label="$1" scenario="$2" box rc sidefx=0
  box="$(mktemp -d)"
  DECIDE_OUT="$(cd "$box" && printf '%s' "$scenario" | python3 "$BUILDER" --decide - 2>&1)"
  rc=$?
  [ -e "$box/pwned" ] && sidefx=1
  rm -rf "$box"
  if [ "$rc" -eq 0 ]; then ok; else bad "$label: --decide exited $rc (expected 0): $DECIDE_OUT"; fi
  if [ "$sidefx" -eq 0 ]; then ok; else bad "$label: created the pwned sentinel — builder shelled a value!"; fi
}
want() {
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then ok; else
    bad "$label: missing [$sub] in: $DECIDE_OUT"
  fi
}
nowant() {
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then
    bad "$label: unexpected [$sub] in: $DECIDE_OUT"
  else ok; fi
}

BC_LABELS='"existing_labels":["type:bug","needs-triage","executor:hybrid"]'
BC_LABELS_SEV='"existing_labels":["type:bug","needs-triage","executor:hybrid","severity:sev0","severity:sev1","severity:sev2","severity:sev3"]'

# ── title format = "<classification>: <short_desc>" + severity→priority ────────
decide 'title + priority' "{\"classification\":\"wrong-skill\",\"severity\":\"high\",\"short_desc\":\"brainstorming fired for trivial rename\",\"expected\":[\"systematic-debugging\"],\"fired\":\"brainstorming\",\"reg_description\":\"x\",\"state\":{${BC_LABELS}}}"
want   'title + priority' '"title": "wrong-skill: brainstorming fired for trivial rename"'
want   'title + priority' '"team": "Brite Company"'
want   'title + priority' '"project": "Brite Skill Packs"'
want   'title + priority' '"priority": 2'

# ── classification → registry routing (the 7→3 map) ───────────────────────────
want   'title + priority' '"target": "trigger-registry.json"'
# bad-output → behavioral registry; assert the full entry shape right here (the
# `want` helper reads the LAST decide output, so keep all bad-output asserts
# adjacent to this decide — do not interleave other decide calls between them).
decide 'bad-output → behavioral' "{\"classification\":\"bad-output\",\"severity\":\"medium\",\"short_desc\":\"poor\",\"prompt\":\"full prompt\",\"expected_skill\":\"brainstorming\",\"expected_markers\":[\"design document\"],\"reg_description\":\"q\",\"context\":\"c\",\"state\":{${BC_LABELS},\"behavioral_ids\":[\"B01\",\"B10\"]}}"
want   'bad-output → behavioral' '"target": "behavioral-registry.json"'
want   'bad-output → behavioral' '"id": "B11"'
want   'bad-output → behavioral' '"tier": 2'
want   'bad-output → behavioral' 'Regression from /workflows:report-issue'
decide 'hook-issue → linear only' "{\"classification\":\"hook-issue\",\"severity\":\"low\",\"short_desc\":\"x\",\"state\":{${BC_LABELS}}}"
want   'hook-issue → linear only' '"target": null'
want   'hook-issue → linear only' '"entry": null'
decide 'subagent-issue → linear only' "{\"classification\":\"subagent-issue\",\"severity\":\"low\",\"short_desc\":\"x\",\"state\":{${BC_LABELS}}}"
want   'subagent-issue → linear only' '"target": null'
decide 'command-flow → linear only' "{\"classification\":\"command-flow\",\"severity\":\"low\",\"short_desc\":\"x\",\"state\":{${BC_LABELS}}}"
want   'command-flow → linear only' '"target": null'

# ── B## next-id allocation (the meatiest S2 nugget): B10 → B11 (asserted above) ─
# fresh registry (no ids) → B01.
decide 'empty registry → B01' "{\"classification\":\"bad-output\",\"severity\":\"low\",\"short_desc\":\"x\",\"prompt\":\"p\",\"reg_description\":\"d\",\"context\":\"c\",\"state\":{${BC_LABELS},\"behavioral_ids\":[]}}"
want   'empty registry → B01' '"id": "B01"'
# non-contiguous ids → max+1, not count+1 (B03,B07 → B08, NOT B03).
decide 'non-contiguous → max+1' "{\"classification\":\"bad-output\",\"severity\":\"low\",\"short_desc\":\"x\",\"prompt\":\"p\",\"reg_description\":\"d\",\"context\":\"c\",\"state\":{${BC_LABELS},\"behavioral_ids\":[\"B03\",\"B07\"]}}"
want   'non-contiguous → max+1' '"id": "B08"'
# DESCENDING order → still max+1, not last-element+1 (B07,B03 → B08, NOT B04) —
# binds max() over the set, not a positional read of the last id.
decide 'descending ids → max+1' "{\"classification\":\"bad-output\",\"severity\":\"low\",\"short_desc\":\"x\",\"prompt\":\"p\",\"reg_description\":\"d\",\"context\":\"c\",\"state\":{${BC_LABELS},\"behavioral_ids\":[\"B07\",\"B03\"]}}"
want   'descending ids → max+1' '"id": "B08"'
# OVERFLOW past 99 is INTENTIONAL (regression lock, Greptile P2): :02d is a min-width,
# not a cap — B99 → B100 → B101, unique + numerically monotonic (truncating would
# collide). Locks the documented widening behavior.
decide 'overflow B99 → B100' "{\"classification\":\"bad-output\",\"severity\":\"low\",\"short_desc\":\"x\",\"prompt\":\"p\",\"reg_description\":\"d\",\"context\":\"c\",\"state\":{${BC_LABELS},\"behavioral_ids\":[\"B98\",\"B99\"]}}"
want   'overflow B99 → B100' '"id": "B100"'
decide 'overflow B100 → B101' "{\"classification\":\"bad-output\",\"severity\":\"low\",\"short_desc\":\"x\",\"prompt\":\"p\",\"reg_description\":\"d\",\"context\":\"c\",\"state\":{${BC_LABELS},\"behavioral_ids\":[\"B100\"]}}"
want   'overflow B100 → B101' '"id": "B101"'

# ── tier:2 constant + provenance prefixes (asserted with the bad-output row above) ─

# ── per-classification expected/not_expected population (Step 3) ──────────────
# wrong-skill: expected = correct, not_expected = the wrong skill that fired.
decide 'wrong-skill population' "{\"classification\":\"wrong-skill\",\"severity\":\"low\",\"short_desc\":\"x\",\"phrase\":\"p\",\"expected\":[\"systematic-debugging\"],\"fired\":\"brainstorming\",\"reg_description\":\"d\",\"state\":{${BC_LABELS}}}"
want   'wrong-skill population' '"expected": ["systematic-debugging"]'
want   'wrong-skill population' '"not_expected": ["brainstorming"]'
# skill-not-fired: expected populated, not_expected [] (no other skill fired).
decide 'skill-not-fired population' "{\"classification\":\"skill-not-fired\",\"severity\":\"low\",\"short_desc\":\"x\",\"phrase\":\"p\",\"expected\":[\"tdd\"],\"reg_description\":\"d\",\"state\":{${BC_LABELS}}}"
want   'skill-not-fired population' '"expected": ["tdd"]'
want   'skill-not-fired population' '"not_expected": []'
# skill-over-fired: expected [], not_expected = the over-firing skill.
decide 'skill-over-fired population' "{\"classification\":\"skill-over-fired\",\"severity\":\"low\",\"short_desc\":\"x\",\"phrase\":\"p\",\"fired\":\"brainstorming\",\"reg_description\":\"d\",\"state\":{${BC_LABELS}}}"
want   'skill-over-fired population' '"expected": []'
want   'skill-over-fired population' '"not_expected": ["brainstorming"]'

# ── phrase shell-metachar strip ($ ` \ " ' removed) ───────────────────────────
# SINGLE-QUOTED scenario so bash performs no expansion; the literal metachars reach
# the builder and must be stripped from the emitted phrase.
decide 'phrase sanitize' '{"classification":"wrong-skill","severity":"low","short_desc":"x","phrase":"rename $foo to `bar` with \"quotes\"","expected":["a"],"fired":"b","reg_description":"d","state":{"existing_labels":["type:bug","needs-triage","executor:hybrid"]}}'
want   'phrase sanitize' '"phrase": "rename foo to bar with quotes"'
nowant 'phrase sanitize' 'pwned'

# ── reconcile: severity:* provisioned → label applied, NOT carried by priority ─
decide 'severity provisioned' "{\"classification\":\"command-flow\",\"severity\":\"critical\",\"short_desc\":\"x\",\"state\":{${BC_LABELS_SEV}}}"
want   'severity provisioned' '"severity_carried_by_priority": false'
want   'severity provisioned' '"severity:sev0"'
want   'severity provisioned' '"priority": 1'
# Brite Company today (no severity:*) → carried by priority.
decide 'severity not provisioned' "{\"classification\":\"command-flow\",\"severity\":\"medium\",\"short_desc\":\"x\",\"state\":{${BC_LABELS}}}"
want   'severity not provisioned' '"severity_carried_by_priority": true'
want   'severity not provisioned' 'severity:* not provisioned in Brite Company'

# ── needs-triage absent → built-in Triage state fallback ──────────────────────
decide 'needs-triage absent' "{\"classification\":\"command-flow\",\"severity\":\"low\",\"short_desc\":\"x\",\"state\":{\"existing_labels\":[\"type:bug\",\"executor:hybrid\"]}}"
want   'needs-triage absent' '"triage_state_fallback": "Triage"'

# ── error rows (a decision, still exit 0) ─────────────────────────────────────
decide 'invalid classification' '{"classification":"frobnicate","severity":"low"}'
want   'invalid classification' '"error": "invalid_classification"'
want   'invalid classification' '"issue_payload": null'
decide 'missing severity' '{"classification":"bad-output","short_desc":"x"}'
want   'missing severity' '"error": "missing_severity"'
decide 'invalid severity' '{"classification":"bad-output","severity":"meh","short_desc":"x"}'
want   'invalid severity' '"error": "invalid_severity"'

# ── determinism: byte-identical across two emit runs ──────────────────────────
FIXTURE="$HERE/../tests/eval/report-issue.fixture.json"
if [ -f "$FIXTURE" ]; then
  d1="$(mktemp -d)"; d2="$(mktemp -d)"
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d1" >/dev/null 2>&1
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d2" >/dev/null 2>&1
  if diff -q "$d1/report-issue-emit.json" "$d2/report-issue-emit.json" >/dev/null 2>&1; then ok; else
    bad "determinism: two emit runs differ"
  fi
  rm -rf "$d1" "$d2"
else
  echo "  (skip determinism — fixture not yet present: $FIXTURE)"
fi

# ── infra error: malformed --decide payload exits 2 ───────────────────────────
box="$(mktemp -d)"
printf '%s' 'not json' | (cd "$box" && python3 "$BUILDER" --decide - >/dev/null 2>&1); rc=$?
rm -rf "$box"
if [ "$rc" -eq 2 ]; then ok; else bad "malformed --decide should exit 2, got $rc"; fi

echo ""
echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
