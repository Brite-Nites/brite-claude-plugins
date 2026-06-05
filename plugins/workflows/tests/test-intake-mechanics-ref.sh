#!/usr/bin/env bash
# BC-12535 (M2) — shared intake-mechanics reference lint (light).
#
# Invariant: the intake mechanics shared across the product branch
# (raise-a-ticket) and the agent-tooling alias (report-issue) — the Linear
# reachability probe, the duplicate-search procedure, the preview/confirm-gate
# guidance, and the plugins-repo detection signal — are CITED from one canonical
# source (plugins/workflows/commands/_shared/intake-mechanics.md), not re-inlined
# divergently in each command.
#
# This is the LIGHT half of the BC-12535 lint pair (the FULL half is the M1
# redaction lint, test-intake-redaction-canon.sh). It asserts:
#   PRESENT  — the shared mechanics file exists and actually covers the four
#              mechanics it is the canonical home for.
#   CITED    — both commands reference the shared file by path.
#
# NOTE — the cap-proof "reply with the number, or none" disambiguation contract
# is DELIBERATELY kept inline at each pick site and is guarded per-site by the
# separate M3 lint (test-intake-option-cap.sh). M2 does not touch it: a behavioral
# invariant belongs where it is enforced, not behind a citation.
#
# Hand-rolled assertion harness. Bash 3.2 compatible. Auto-discovered by
# validate.sh Section 2e; emits RESULT pass=N.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CMD_DIR="$PLUGIN_ROOT/commands"
RAISE="$CMD_DIR/raise-a-ticket.md"
REPORT="$CMD_DIR/report-issue.md"
SHARED="$CMD_DIR/_shared/intake-mechanics.md"
CITE="_shared/intake-mechanics.md"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ── Assertions ───────────────────────────────────────────────────────
assert_cites() {
  local label="$1" file="$2"
  if grep -Fq -- "$CITE" "$file" 2>/dev/null; then
    pass "$label cites the shared mechanics ($CITE)"
  else
    fail "$label does NOT cite $CITE"
  fi
}

# The shared file must STRUCTURALLY cover each mechanic it is canonical for: each
# must have its own `## ` section heading. This is stronger than a word-anywhere
# grep (a blank or word-dropping stub without the section headings fails) but is
# still "light" — it asserts the section exists, not that its prose is complete.
assert_shared_covers() {
  local label="$1" heading_re="$2"
  if grep -Eiq -- "$heading_re" "$SHARED" 2>/dev/null; then
    pass "shared mechanics has a section for $label"
  else
    fail "shared mechanics MISSING a section for $label (expected heading matching: $heading_re)"
  fi
}

# ── Preconditions ────────────────────────────────────────────────────
for f in "$RAISE" "$REPORT"; do
  [ -f "$f" ] || { echo "fatal: missing $f" >&2; exit 2; }
done
if [ -f "$SHARED" ]; then
  pass "shared mechanics file exists: $CITE"
else
  fail "shared mechanics file missing: $CITE"
fi

# ── Coverage: each of the four mechanics has its own section heading ──
assert_shared_covers "the Linear reachability probe" '^#{2,3} .*reachability'
assert_shared_covers "the duplicate search"          '^#{2,3} .*duplicate'
assert_shared_covers "the preview / confirm gate"    '^#{2,3} .*preview'
assert_shared_covers "the plugins-repo detection"    '^#{2,3} .*plugins-repo'

# Substance anchors — the canonical MCP calls / signal must actually appear, so a
# headings-only skeleton with empty sections still fails (keeps the file useful
# to the LLM that reads it, not just structurally shaped).
assert_shared_has_token() {
  local label="$1" tok="$2"
  if grep -Fq -- "$tok" "$SHARED" 2>/dev/null; then
    pass "shared mechanics names $label ($tok)"
  else
    fail "shared mechanics MISSING $label (token: $tok)"
  fi
}
assert_shared_has_token "the reachability call" "list_projects"
assert_shared_has_token "the duplicate-search call" "list_issues"
assert_shared_has_token "the plugins-repo signal" "marketplace.json"

# ── Cited by both branches ───────────────────────────────────────────
assert_cites "raise-a-ticket" "$RAISE"
assert_cites "report-issue"   "$REPORT"

# ── Result ───────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT pass=$PASS fail=0"
  exit 0
else
  echo "RESULT pass=$PASS fail=$FAIL"
  exit 1
fi
