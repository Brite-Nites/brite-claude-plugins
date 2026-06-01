#!/usr/bin/env bash
# BC-12250 grep-triad locks for the greptile-gate loop semantics.
#
# Defends the prose that encodes the gate's behavior against rewrite drift,
# per the rubric-triad pattern (catchphrase + structural-clause + negative-case):
#   SKILL.md  — 5/5 pass bar, max-3 rounds, grill-every-round, stop-before-merge,
#               and a negative lock that NO auto-merge language creeps in.
#   ship.md   — gate wired as Step 2b (after Step 2, before Step 3), terminal
#               steps after the gate, Linear stays In Review (no auto-Done).
#
# Bash 3.2 compatible. No network. Auto-run by validate.sh Section 2e.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/greptile-gate/SKILL.md"
SHIP="$PLUGIN_ROOT/commands/ship.md"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

have()   { grep -qF -- "$2" "$1"; }                      # literal substring present
lineno() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }

[ -f "$SKILL" ] || { echo "fatal: greptile-gate SKILL.md missing" >&2; exit 2; }
[ -f "$SHIP" ]  || { echo "fatal: ship.md missing" >&2; exit 2; }

# ── SKILL.md loop-semantics triad ────────────────────────────────────
section 1 "SKILL.md: 5/5 pass bar (catchphrase)"
if have "$SKILL" "5/5"; then pass "5/5 present"; else fail "'5/5' missing"; fi

section 2 "SKILL.md: max-3 rounds (structural)"
if have "$SKILL" "maximum of 3 rounds"; then pass "'maximum of 3 rounds' present"; else fail "max-3 clause missing"; fi

section 3 "SKILL.md: grill every round (structural)"
if have "$SKILL" "Grill on intent — every round"; then pass "grill-every-round present"; else fail "grill-every-round clause missing"; fi

section 4 "SKILL.md: stop-before-merge (structural)"
if have "$SKILL" "the gate never merges"; then pass "stop-before-merge present"; else fail "'the gate never merges' missing"; fi

section 5 "SKILL.md: no auto-merge (negative-case)"
if grep -qiE 'gh pr merge|automatically merge|auto-merge' "$SKILL"; then
  fail "auto-merge language present — the gate must never merge"
else
  pass "no auto-merge language"
fi

# ── ship.md structural locks ─────────────────────────────────────────
section 6 "ship.md: greptile gate wired as Step 2b"
if have "$SHIP" "## Step 2b: Greptile Gate"; then pass "Step 2b heading present"; else fail "Step 2b heading missing"; fi

section 7 "ship.md: gate after Step 2, before Step 3 (order)"
s2="$(lineno "$SHIP" "## Step 2: Create Pull Request")"
s2b="$(lineno "$SHIP" "## Step 2b: Greptile Gate")"
s3="$(lineno "$SHIP" "## Step 3: Update Linear")"
if [ -n "$s2" ] && [ -n "$s2b" ] && [ -n "$s3" ] && [ "$s2" -lt "$s2b" ] && [ "$s2b" -lt "$s3" ]; then
  pass "order Step 2 ($s2) < 2b ($s2b) < Step 3 ($s3)"
else
  fail "ordering wrong: s2=$s2 s2b=$s2b s3=$s3"
fi

section 8 "ship.md: terminal steps run after the gate"
s4="$(lineno "$SHIP" "## Step 4: Compound Learnings")"
if [ -n "$s2b" ] && [ -n "$s4" ] && [ "$s2b" -lt "$s4" ]; then
  pass "compound-learnings ($s4) after gate ($s2b)"
else
  fail "compound-learnings not after gate: s2b=$s2b s4=$s4"
fi

section 9 "ship.md: Linear stays In Review (no auto-Done)"
if have "$SHIP" 'Leave it **In Review**' && ! grep -qF 'or "Done" if team merges' "$SHIP"; then
  pass "Linear In Review lock (auto-Done phrasing removed)"
else
  fail "Linear should stay In Review and drop the auto-Done phrasing"
fi

# ──────────────────────────────────────────────────────────────────────
printf '\nBC-12250 greptile-gate lock tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
