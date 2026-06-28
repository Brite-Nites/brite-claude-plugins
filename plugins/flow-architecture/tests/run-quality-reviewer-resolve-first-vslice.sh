#!/usr/bin/env bash
# quality-reviewer resolve-first contract v-slice (BC-13030, WS-B reviewer-precision).
#
# Locks the prose contract of the FDA substance reviewer + its rubric so the
# resolve-first reframe cannot silently revert to the old "default the
# corpus-dependent dimensions to CONCERN whenever the dispatcher didn't pre-
# supply an evidence flag" posture (the false-negative-P2 bug from BC-11996).
#
# This is a PROSE tripwire, not a behavior test: the quality-reviewer is an LLM
# agent, so this asserts the instruction text carries the resolve-first +
# cite-concrete-evidence rule and NO LONGER carries the retired flag-gate
# language. It proves the words are present, not that the model's judgement
# changed — the same contract the $STORY_AGENT / $JOURNEY_AGENT prose locks in
# run-template-alignment-vslice.sh provide for the author agents.
#
# Two-file lock (the fix touches both):
#   - agents/quality-reviewer.md          Step 5 + Conventions + evidence input
#   - skills/_shared/quality-rubric.md    "How to score" evidence Rule + D10 band
#
# Three-layer defense per the rubric-lock grep-triad (positive resolve-first
# clause + citation-forcing clause + negative retired-gate clause).
#
# Bash 3.2 compatible (macOS default). No external deps.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

QR_AGENT="$PLUGIN_ROOT/agents/quality-reviewer.md"
RUBRIC="$PLUGIN_ROOT/skills/_shared/quality-rubric.md"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

assert_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label (missing: $path)"; fi
}

# grep -F (fixed string) present
assert_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then pass "$label"
  else fail "$label (needle '$needle' not found in $path)"; fi
}

# grep -F (fixed string) absent
assert_no_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then
    fail "$label (unexpected match for '$needle' in $path)"
  else pass "$label"; fi
}

# ── Section 1: the edited files are present ──────────────────────────
section "1/3" "Reviewer agent + rubric present"
assert_file "quality-reviewer agent present" "$QR_AGENT"
assert_file "quality-rubric present"          "$RUBRIC"

# ── Section 2: agent prose carries resolve-first + NOT the old gate ──
section "2/3" "quality-reviewer.md teaches resolve-first + cite, not flag-gating"

# POSITIVE — the resolve-first contract
assert_grep "agent: Step 5 resolve-first title" \
  "Resolve corpus-dependent claims with your own tools first" "$QR_AGENT"
assert_grep "agent: evidence flags are shortcuts, not gates" \
  "shortcuts, not gates" "$QR_AGENT"
# CITATION-FORCING — a corpus-dependent Pass must cite the concrete resolution
assert_grep "agent: Pass must cite the concrete resolution" \
  "cite the concrete resolution" "$QR_AGENT"
# OUTCOME (2) — genuine absence is a substantiated finding, not a withhold
assert_grep "agent: genuine absence is a substantiated finding" \
  "substantiated finding at the dimension's own severity band" "$QR_AGENT"

# NEGATIVE — the retired flag-gate language must be GONE
assert_no_grep "agent: NO retired 'Absence of a field means you do NOT have that evidence' gate" \
  "Absence of a field means you do NOT have that evidence" "$QR_AGENT"
assert_no_grep "agent: NO retired 'Withhold Pass without evidence' Conventions posture" \
  "Withhold Pass without evidence" "$QR_AGENT"

# ── Section 3: rubric Rule harmonized to resolve-first ──────────────
section "3/3" "quality-rubric.md evidence Rule harmonized to resolve-first"

# POSITIVE — the Rule + heading say resolve first
assert_grep "rubric: evidence Rule says resolve first" \
  "resolve first" "$RUBRIC"
# NEGATIVE — the retired flag-gate framing must be GONE from the Rule + heading
assert_no_grep "rubric: NO retired 'withhold Pass when you don't have it' heading" \
  "withhold Pass when you don't have it" "$RUBRIC"
assert_no_grep "rubric: NO retired 'unless the reviewer was actually given that evidence' Rule" \
  "unless the reviewer was actually given that evidence" "$RUBRIC"

# ── Summary ──────────────────────────────────────────────────────────
printf '\nquality-reviewer resolve-first v-slice summary: %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
printf 'RESULT pass=%d fail=%d skip=%d\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
