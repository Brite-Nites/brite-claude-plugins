#!/usr/bin/env bash
# Unit / contract suite for plugins/workflows/scripts/build_retro_snapshot.py
# (BC-12944, ADR-028 Phase-2 Batch C — S3 Linear cycle-metrics).
#
# build_retro_snapshot.py is the PURE deterministic decision core
# /workflows:retrospective delegates to for the quantified delivery snapshot: given
# the resolved cycle meta + the injected list_issues, it computes the by-state-type
# tally + completion rate + the Step-4a health indicator, with NO MCP call and NO
# Linear write. This suite drives the builder directly across the categorization,
# the health bands (incl. the >= boundaries), and the no-cycle reject. The behavioral
# eval asserts the emit-artifact STRUCTURE; this asserts the per-branch DECISIONS +
# injection-safety + determinism.
#
# Usage:
#   bash plugins/workflows/scripts/test_build_retro_snapshot.sh
#   bash plugins/workflows/scripts/test_build_retro_snapshot.sh /path/to/build_retro_snapshot.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_retro_snapshot.py}"
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

# ── health band: 80% is the onTrack boundary (>= 80, not > 80) ────────────────
decide 'health 80 onTrack' '{"cycle":{"number":6},"linear_state":{"issues":[{"id":"A","state_type":"completed"},{"id":"B","state_type":"completed"},{"id":"C","state_type":"completed"},{"id":"D","state_type":"completed"},{"id":"E","state_type":"started"}]}}'
want 'health 80 onTrack' '"completion_rate": 80'
want 'health 80 onTrack' '"health": "onTrack"'
want 'health 80 onTrack' '"completed": 4'
want 'health 80 onTrack' '"carried_over": 1'

# 50% is the atRisk boundary (>= 50, not > 50).
decide 'health 50 atRisk' '{"cycle":{"number":7},"linear_state":{"issues":[{"id":"A","state_type":"completed"},{"id":"B","state_type":"unstarted"}]}}'
want 'health 50 atRisk' '"completion_rate": 50'
want 'health 50 atRisk' '"health": "atRisk"'

# 75% in-band atRisk (just below 80 — locks that 79 is NOT onTrack).
decide 'health 75 atRisk' '{"cycle":{"number":7},"linear_state":{"issues":[{"id":"A","state_type":"completed"},{"id":"B","state_type":"completed"},{"id":"C","state_type":"completed"},{"id":"D","state_type":"started"}]}}'
want 'health 75 atRisk' '"completion_rate": 75'
want 'health 75 atRisk' '"health": "atRisk"'

# 40% offTrack (below the 50 cut) + canceled categorization + delivered/carried/canceled ids.
decide 'health 40 offTrack + canceled' '{"cycle":{"number":8},"linear_state":{"issues":[{"id":"A","state_type":"completed"},{"id":"B","state_type":"completed"},{"id":"C","state_type":"started"},{"id":"D","state_type":"canceled"},{"id":"E","state_type":"unstarted"}]}}'
want 'health 40 offTrack + canceled' '"completion_rate": 40'
want 'health 40 offTrack + canceled' '"health": "offTrack"'
want 'health 40 offTrack + canceled' '"canceled": 1'
want 'health 40 offTrack + canceled' '"canceled_ids": ["D"]'
want 'health 40 offTrack + canceled' '"delivered_ids": ["A", "B"]'
want 'health 40 offTrack + canceled' '"carried_ids": ["C", "E"]'

# empty cycle → 0% offTrack (no divide-by-zero, "No issues completed").
decide 'empty cycle 0pct' '{"cycle":{"number":9},"linear_state":{"issues":[]}}'
want 'empty cycle 0pct' '"completion_rate": 0'
want 'empty cycle 0pct' '"health": "offTrack"'
want 'empty cycle 0pct' '"total": 0'

# ── no target cycle → reject row (the command's "No cycles found" stop) ───────
decide 'no target cycle' '{"linear_state":{"issues":[{"id":"A","state_type":"completed"}]}}'
want 'no target cycle' '"error": "no_target_cycle"'
want 'no target cycle' '"health": null'

# ── injection-safety: a $(touch pwned) issue id is literal (no shell-out sink) ─
decide 'issue-id injection is literal' '{"cycle":{"number":1},"linear_state":{"issues":[{"id":"$(touch pwned)","state_type":"completed"}]}}'

# ── determinism: byte-identical across two emit runs ──────────────────────────
FIXTURE="$HERE/../tests/eval/retrospective.fixture.json"
if [ -f "$FIXTURE" ]; then
  d1="$(mktemp -d)"; d2="$(mktemp -d)"
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d1" >/dev/null 2>&1
  python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d2" >/dev/null 2>&1
  if diff -q "$d1/retro-snapshot-emit.json" "$d2/retro-snapshot-emit.json" >/dev/null 2>&1; then ok; else
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
