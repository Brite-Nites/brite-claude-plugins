#!/usr/bin/env bash
# Unit / contract suite for plugins/workflows/scripts/build_raise_ticket_payload.py
# (BC-12944, ADR-028 Phase-2 Batch C — the workflows plugin's first build_* script).
#
# build_raise_ticket_payload.py is the PURE deterministic decision core
# /workflows:raise-a-ticket delegates to for the NON-conversational parts of intake:
# given the reporter-facing kind + severity + resolved project/team candidates and
# the INJECTED Linear reads (list_issue_labels + list_issues), it computes the
# label/priority/team PROJECTION of the ticket that would be filed, with NO MCP call
# and NO Linear write. This suite drives the builder directly across every branch
# (Steps 2/4/1g/8) AND proves the builder never shells a value (it has no shell-out
# sink at all — a `$(touch pwned)` reporter is treated as literal data) AND that the
# emit is deterministic. The behavioral eval (scripts/eval/test_eval_harness.sh)
# asserts the emit-artifact STRUCTURE; this asserts the builder's per-branch
# DECISIONS + injection-safety + determinism.
#
# Usage:
#   bash plugins/workflows/scripts/test_build_raise_ticket_payload.sh
#   bash plugins/workflows/scripts/test_build_raise_ticket_payload.sh /path/to/build_raise_ticket_payload.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.

# Defuse caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md; matches
# the revops builder-suite discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_raise_ticket_payload.py}"

if [ ! -f "$BUILDER" ]; then
  echo "FATAL: builder not found: $BUILDER" >&2
  exit 2
fi

pass=0
fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

# decide "<label>" "<scenario-json>"  → runs --decide in an isolated sandbox cwd,
# asserts exit 0 (a decision is always a successful run, even a reject) AND that no
# `pwned` side-effect sentinel was created. Echoes the single-line decision JSON so
# the caller can assert substrings.
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

want() {  # want "<label>" "<substring>"  — assert DECIDE_OUT contains substring
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then ok; else
    bad "$label: missing [$sub] in: $DECIDE_OUT"
  fi
}
nowant() {  # nowant "<label>" "<substring>"  — assert DECIDE_OUT does NOT contain substring
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then
    bad "$label: unexpected [$sub] in: $DECIDE_OUT"
  else ok; fi
}

# Injected reads (the target team's provisioned labels + the multi-team tally rows).
FULL_LABELS='"existing_labels":["type:bug","type:task","needs-triage","executor:hybrid","severity:sev0","severity:sev1","severity:sev2","severity:sev3"]'
NO_SEVERITY='"existing_labels":["type:bug","type:task","needs-triage","executor:hybrid"]'

# ── Step 2 type map + Step 4 severity→(label,priority): Bug ────────────────────
decide 'bug high single-team' "{\"kind\":\"bug\",\"severity\":\"high\",\"project_teams\":[\"Brite Company\"],\"linear_state\":{${FULL_LABELS}}}"
want   'bug high single-team' '"error": null'
want   'bug high single-team' '"type_label": "type:bug"'
want   'bug high single-team' '"severity_label": "severity:sev1"'
want   'bug high single-team' '"priority": 2'
want   'bug high single-team' '"team_tiebreak": "single"'
want   'bug high single-team' '"severity:sev1"'

# critical→sev0/1, low→sev3/4 mapping coverage (lock the full table, not one row).
decide 'bug critical' "{\"kind\":\"bug\",\"severity\":\"critical\",\"project_teams\":[\"Brite Company\"],\"linear_state\":{${FULL_LABELS}}}"
want   'bug critical' '"severity_label": "severity:sev0"'
want   'bug critical' '"priority": 1'
decide 'bug low' "{\"kind\":\"bug\",\"severity\":\"low\",\"project_teams\":[\"Brite Company\"],\"linear_state\":{${FULL_LABELS}}}"
want   'bug low' '"severity_label": "severity:sev3"'
want   'bug low' '"priority": 4'

# ── Step 2 Idea/Feedback → type:task, NO severity, NO priority (Step 4 skipped) ─
decide 'idea no severity' "{\"kind\":\"idea\",\"project_teams\":[\"Brite Company\"],\"linear_state\":{${NO_SEVERITY}}}"
want   'idea no severity' '"type_label": "type:task"'
want   'idea no severity' '"severity_label": null'
want   'idea no severity' '"priority": null'
want   'idea no severity' '"type:task"'

# ── Step 8 reconcile: severity:* group not provisioned → priority carries it ────
decide 'severity not provisioned' "{\"kind\":\"bug\",\"severity\":\"medium\",\"project_teams\":[\"Brite Company\"],\"linear_state\":{${NO_SEVERITY}}}"
want   'severity not provisioned' '"severity_carried_by_priority": true'
want   'severity not provisioned' '"priority": 3'
want   'severity not provisioned' 'severity:* not provisioned'
nowant 'severity not provisioned' '"applied_labels": ["type:bug", "needs-triage", "executor:hybrid", "severity:sev2"]'

# ── Step 8 reconcile: needs-triage label absent → built-in Triage state fallback ─
decide 'needs-triage absent' "{\"kind\":\"idea\",\"project_teams\":[\"Brite Company\"],\"linear_state\":{\"existing_labels\":[\"type:task\",\"executor:hybrid\"]}}"
want   'needs-triage absent' '"triage_state_fallback": "Triage"'
want   'needs-triage absent' 'set built-in Triage state'
# needs-triage must NOT be in the APPLIED set (it's in missing_labels + the note,
# so assert the exact applied set rather than a bare-substring nowant).
want   'needs-triage absent' '"applied_labels": ["type:task", "executor:hybrid"]'

# needs-triage PRESENT → no fallback (the non-vacuous twin of the row above).
decide 'needs-triage present' "{\"kind\":\"idea\",\"project_teams\":[\"Brite Company\"],\"linear_state\":{${NO_SEVERITY}}}"
want   'needs-triage present' '"triage_state_fallback": null'

# ── Step 1g modal-team tiebreak (the four branches) ────────────────────────────
# single already covered above. modal: Brite Base spans [Supply, Company], issues
# predominantly live in Company.
decide 'multi-team modal' "{\"kind\":\"bug\",\"severity\":\"low\",\"project_teams\":[\"Brite Supply\",\"Brite Company\"],\"linear_state\":{${FULL_LABELS},\"project_issues\":[{\"team\":\"Brite Company\"},{\"team\":\"Brite Company\"},{\"team\":\"Brite Supply\"}]}}"
want   'multi-team modal' '"team": "Brite Company"'
want   'multi-team modal' '"team_tiebreak": "modal"'

# tie on count → Brite Company.
decide 'multi-team tie' "{\"kind\":\"idea\",\"project_teams\":[\"Brite Supply\",\"Brite Labs\"],\"linear_state\":{${NO_SEVERITY},\"project_issues\":[{\"team\":\"Brite Supply\"},{\"team\":\"Brite Labs\"}]}}"
want   'multi-team tie' '"team": "Brite Company"'
want   'multi-team tie' '"team_tiebreak": "tie-brite-company"'

# empty / no-team-field tally → Brite Company fallback (guards the dropped-field case).
decide 'multi-team no team field' "{\"kind\":\"idea\",\"project_teams\":[\"Brite Supply\",\"Brite Labs\"],\"linear_state\":{${NO_SEVERITY},\"project_issues\":[{\"id\":\"X\"},{\"id\":\"Y\"}]}}"
want   'multi-team no team field' '"team": "Brite Company"'
want   'multi-team no team field' '"team_tiebreak": "fallback-brite-company"'

# ── Step 5b domain:<slug> applied only when confirmed present in the team ──────
decide 'domain applied' "{\"kind\":\"bug\",\"severity\":\"high\",\"project_teams\":[\"Brite Company\"],\"domain\":\"domain:quo\",\"linear_state\":{\"existing_labels\":[\"type:bug\",\"needs-triage\",\"executor:hybrid\",\"severity:sev1\",\"domain:quo\"]}}"
want   'domain applied' '"domain:quo"'

# ── error rows (a decision, still exit 0; no payload projection) ───────────────
decide 'invalid kind' '{"kind":"frobnicate"}'
want   'invalid kind' '"error": "invalid_kind"'
want   'invalid kind' '"type_label": null'
decide 'bug missing severity' '{"kind":"bug","project_teams":["Brite Company"]}'
want   'bug missing severity' '"error": "missing_severity"'
decide 'bug invalid severity' '{"kind":"bug","severity":"sorta-bad","project_teams":["Brite Company"]}'
want   'bug invalid severity' '"error": "invalid_severity"'

# ── injection-safety: the builder has NO shell-out sink; a $(touch pwned) reporter
#    is literal data. SINGLE-QUOTED so bash performs no expansion at the call site —
#    the literal string reaches the builder, lands verbatim in the footer, and the
#    sandbox stays clean (decide() asserts no pwned sentinel). ───────────────────
decide 'reporter injection is literal' '{"kind":"idea","project_teams":["Brite Company"],"reporter":"$(touch pwned)","linear_state":{"existing_labels":["type:task","needs-triage","executor:hybrid"]}}'
want   'reporter injection is literal' '$(touch pwned)'

# ── determinism: the emit artifact is byte-identical across two runs ────────────
FIXTURE="$HERE/../tests/eval/raise-a-ticket.fixture.json"
if [ -f "$FIXTURE" ]; then
  d1="$(mktemp -d)"; d2="$(mktemp -d)"
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d1" >/dev/null 2>&1
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d2" >/dev/null 2>&1
  if diff -q "$d1/raise-ticket-emit.json" "$d2/raise-ticket-emit.json" >/dev/null 2>&1; then ok; else
    bad "determinism: two emit runs differ"
  fi
  rm -rf "$d1" "$d2"
else
  echo "  (skip determinism — fixture not yet present: $FIXTURE)"
fi

# ── infra error: a malformed --decide payload exits 2 (distinct from a reject) ──
box="$(mktemp -d)"
printf '%s' 'not json' | (cd "$box" && python3 "$BUILDER" --decide - >/dev/null 2>&1); rc=$?
rm -rf "$box"
if [ "$rc" -eq 2 ]; then ok; else bad "malformed --decide should exit 2, got $rc"; fi

echo ""
echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
