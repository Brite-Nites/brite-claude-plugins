#!/usr/bin/env bash
# Unit / contract suite for plugins/workflows/scripts/build_sprint_plan.py
# (BC-12944, ADR-028 Phase-2 Batch C — S3 Linear cycle-metrics).
#
# build_sprint_plan.py is the PURE deterministic decision core
# /workflows:sprint-planning delegates to for the quantified projection: the current
# snapshot + days-elapsed (Step 2a), the last-3-completed velocity (Step 2b), and the
# priority-sorted backlog (Step 3), with NO MCP call and NO Linear write. now() is
# defeated by an injected as_of. This suite drives the builder across the velocity
# edges (in-progress exclusion, <2-entry skip, <3-completed partial average), the
# days math, the backlog sort + cycle!=null exclusion + truncation, and the
# prioritization-only mode. The behavioral eval asserts the emit-artifact STRUCTURE;
# this asserts the per-branch DECISIONS + injection-safety + determinism.
#
# Usage:
#   bash plugins/workflows/scripts/test_build_sprint_plan.sh
#   bash plugins/workflows/scripts/test_build_sprint_plan.sh /path/to/build_sprint_plan.py

set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_sprint_plan.py}"
[ -f "$BUILDER" ] || { echo "FATAL: builder not found: $BUILDER" >&2; exit 2; }

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
want() { local l="$1" s="$2"; if printf '%s' "$DECIDE_OUT" | grep -qF -- "$s"; then ok; else bad "$l: missing [$s] in: $DECIDE_OUT"; fi; }

# A cycle set: 6 + 7 completed (valid history), 8 completed but single-entry (skip),
# 9 in-progress (completedAt null → excluded). as_of after all completedAt.
CYCLES='"cycles":[{"number":6,"completedAt":"2026-04-01","completedIssueCountHistory":[0,5,8],"issueCountHistory":[10,10,10]},{"number":7,"completedAt":"2026-04-15","completedIssueCountHistory":[0,6],"issueCountHistory":[8,8]},{"number":8,"completedAt":"2026-04-30","completedIssueCountHistory":[3],"issueCountHistory":[9]},{"number":9,"completedAt":null,"completedIssueCountHistory":[1,2],"issueCountHistory":[12,12]}]'

# ── velocity + current snapshot + days (the full plan row) ────────────────────
decide 'plan row' "{\"as_of\":\"2026-05-08\",\"current_cycle\":{\"number\":9,\"startsAt\":\"2026-05-01\",\"endsAt\":\"2026-05-15\"},\"linear_state\":{${CYCLES},\"current_issues\":[{\"id\":\"X\",\"state_type\":\"completed\"},{\"id\":\"Y\",\"state_type\":\"started\"}],\"backlog_issues\":[{\"id\":\"P3\",\"priority\":3,\"cycle\":null},{\"id\":\"P1\",\"priority\":1,\"cycle\":null},{\"id\":\"PN\",\"priority\":0,\"cycle\":null},{\"id\":\"ASSIGNED\",\"priority\":1,\"cycle\":9},{\"id\":\"P2\",\"priority\":2,\"cycle\":null}]}}"
want 'plan row' '"mode": "plan"'
want 'plan row' '"completion_rate": 50'
# days: May 1 → May 8 = 7 elapsed; May 1 → May 15 = 14 total.
want 'plan row' '"days_elapsed": 7'
want 'plan row' '"total_days": 14'
# velocity: cycle 9 (in-progress) EXCLUDED; cycle 8 (<2 entries) SKIPPED; 6 + 7 contribute.
want 'plan row' '"reason": "Insufficient data for Cycle 8"'
want 'plan row' '"avg_completed": 7.0'
want 'plan row' '"avg_rate": 78'
want 'plan row' '"contributing": 2'
# velocity rows oldest→newest with per-cycle rate.
want 'plan row' '"cycle": 6'
want 'plan row' '"rate": 80'
want 'plan row' '"rate": 75'
# in-progress cycle 9 must NOT appear as a velocity row.
if printf '%s' "$DECIDE_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 9 not in [r['cycle'] for r in d['velocity']['rows']] else 1)"; then ok; else bad "plan row: in-progress cycle 9 leaked into velocity rows"; fi
# backlog: priority sort P1>P2>P3>PN, ASSIGNED (cycle=9) excluded.
want 'plan row' '"ordered_ids": ["P1", "P2", "P3", "PN"]'

# ── prioritization-only mode (no current cycle) ───────────────────────────────
decide 'prioritization-only' '{"as_of":"2026-05-08","current_cycle":null,"linear_state":{"cycles":[],"backlog_issues":[{"id":"P1","priority":1,"cycle":null}]}}'
want 'prioritization-only' '"mode": "prioritization-only"'
want 'prioritization-only' '"current_snapshot": null'
want 'prioritization-only' '"days_elapsed": null'
want 'prioritization-only' '"contributing": 0'

# ── a completed cycle without an integer `number` is excluded (not crashed) ───
# (regression lock for the velocity None-number sort TypeError) — only the numbered
# cycle 5 contributes; the number-less completed cycle vanishes, exit stays 0.
decide 'number-less cycle excluded' '{"as_of":"2026-06-01","current_cycle":{"number":7,"startsAt":"2026-05-25","endsAt":"2026-06-08"},"linear_state":{"cycles":[{"number":5,"completedAt":"2026-05-01","completedIssueCountHistory":[0,6],"issueCountHistory":[8,8]},{"completedAt":"2026-04-01","completedIssueCountHistory":[0,4],"issueCountHistory":[7,7]}],"current_issues":[],"backlog_issues":[]}}'
want 'number-less cycle excluded' '"contributing": 1'
want 'number-less cycle excluded' '"cycle": 5'

# ── backlog truncation (20+ → top 20, remaining) + large (50+) flags ──────────
BIG="$(python3 -c 'import json; print(json.dumps([{"id":"I%02d"%i,"priority":2,"cycle":None} for i in range(55)]))')"
decide 'large backlog truncates' "{\"as_of\":\"2026-05-08\",\"current_cycle\":null,\"linear_state\":{\"cycles\":[],\"backlog_issues\":${BIG}}}"
want 'large backlog truncates' '"total": 55'
want 'large backlog truncates' '"shown": 20'
want 'large backlog truncates' '"truncated": true'
want 'large backlog truncates' '"remaining": 35'
want 'large backlog truncates' '"large": true'

# ── injection-safety: a $(touch pwned) id is literal data (no shell-out sink) ─
decide 'id injection is literal' '{"as_of":"2026-05-08","current_cycle":null,"linear_state":{"cycles":[],"backlog_issues":[{"id":"$(touch pwned)","priority":1,"cycle":null}]}}'

# ── determinism: byte-identical across two emit runs ──────────────────────────
FIXTURE="$HERE/../tests/eval/sprint-planning.fixture.json"
if [ -f "$FIXTURE" ]; then
  d1="$(mktemp -d)"; d2="$(mktemp -d)"
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d1" >/dev/null 2>&1
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d2" >/dev/null 2>&1
  if diff -q "$d1/sprint-plan-emit.json" "$d2/sprint-plan-emit.json" >/dev/null 2>&1; then ok; else
    bad "determinism: two emit runs differ"
  fi
  rm -rf "$d1" "$d2"
else
  echo "  (skip determinism — fixture not yet present: $FIXTURE)"
fi

# ── infra error: malformed --decide payload exits 2 ───────────────────────────
box="$(mktemp -d)"; printf '%s' 'not json' | (cd "$box" && python3 "$BUILDER" --decide - >/dev/null 2>&1); rc=$?; rm -rf "$box"
if [ "$rc" -eq 2 ]; then ok; else bad "malformed --decide should exit 2, got $rc"; fi

echo ""
echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
