#!/usr/bin/env bash
# BC-10730 v-slice for the tightened operator-consumable BUILT criterion
# (plugin 1.2.2). Locks the rubric in `flow-inventory-codebase-scan/SKILL.md`
# § 6.1 + `flow-inventory-add/SKILL.md` § 7 against the
# synthetic-built-criterion-drift fixture (API-present-no-UI shape mirroring
# the iter-3 batch 2 `analytics-dashboard-01` correction).
#
# Scope: structural assertions on the fixture + literal-string checks on both
# SKILL.md files. The LLM-driven classifier behavior is rubric-prose; this
# harness defends the rubric content + fixture shape that the rubric cites.
#
# Bash 3.2 compatible (macOS default). Stdlib python3 only.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
FIXTURE="$FIXTURES_DIR/synthetic-built-criterion-drift"

SCAN_SKILL="$PLUGIN_ROOT/skills/flow-inventory-codebase-scan/SKILL.md"
ADD_SKILL="$PLUGIN_ROOT/skills/flow-inventory-add/SKILL.md"

# Hermetic env per the greenfield-vslice + BC-9971 precedent.
unset LINEAR_ISSUE_COUNT FLOW_GH_AUTH_CACHE FLOW_SHAPE_CACHE \
      _FLOW_SHAPE_INTENT_EXISTS _FLOW_SHAPE_INVENTORY_EXISTS \
      _FLOW_SHAPE_FLOWS_DIR_EXISTS _FLOW_SHAPE_BREADCRUMB_EXISTS

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Assert a path exists as a regular file.
assert_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label (missing: $path)"; fi
}

# Assert grep -F (fixed-string) finds the needle in the file at least once.
assert_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then
    pass "$label"
  else
    fail "$label (needle '$needle' not found in $path)"
  fi
}

# Assert grep -F does NOT find the needle in the file (zero occurrences).
assert_no_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then
    fail "$label (unexpected match for '$needle' in $path)"
  else
    pass "$label"
  fi
}

# ── Section 1: Fixture file presence ────────────────────────────────
section "1/4" "Fixture file presence"

assert_file "fixture README.md present" \
  "$FIXTURE/README.md"
assert_file "fixture master-flow-inventory.md present" \
  "$FIXTURE/docs/product/master-flow-inventory.md"
assert_file "fixture API route.ts present" \
  "$FIXTURE/src/app/api/search-logs/dashboard/route.ts"
assert_file "fixture decoy page.tsx present" \
  "$FIXTURE/src/app/(frontend)/(app)/search/page.tsx"

# ── Section 2: API-without-UI signal ────────────────────────────────
section "2/4" "API-without-UI signal"

# route.ts contains an export'ed handler (any of GET/POST/...).
ROUTE_FILE="$FIXTURE/src/app/api/search-logs/dashboard/route.ts"
if grep -qE '^export async function (GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)' "$ROUTE_FILE"; then
  pass "route.ts exports a Next.js route handler"
else
  fail "route.ts does not export a Next.js route handler (expected GET/POST/etc.)"
fi

# No .tsx anywhere under the fixture references /api/search-logs/dashboard.
TSX_HITS=0
while IFS= read -r tsx; do
  if grep -qF '/api/search-logs/dashboard' "$tsx"; then
    TSX_HITS=$((TSX_HITS + 1))
    fail "unexpected UI consumer of /api/search-logs/dashboard in $tsx"
  fi
done < <(find "$FIXTURE" -type f -name '*.tsx')

if [ "$TSX_HITS" -eq 0 ]; then
  pass "no .tsx file under fixture references /api/search-logs/dashboard (operator-consumable absence signal)"
fi

# ── Section 3: Inventory classifies as ⚠ PARTIAL ────────────────────
section "3/4" "Inventory row classified ⚠ PARTIAL"

INVENTORY="$FIXTURE/docs/product/master-flow-inventory.md"
assert_grep "inventory contains analytics-dashboard-01 row" \
  "analytics-dashboard-01" "$INVENTORY"
assert_grep "inventory row tagged partially-implemented" \
  "partially-implemented" "$INVENTORY"
assert_no_grep "inventory row NOT tagged ✓ BUILT" \
  "✓ BUILT" "$INVENTORY"

# The literal short-form `implemented` (without `partially-` prefix) only
# appears inside the `partially-implemented` longer string, which we want.
# Confirm there's no standalone "(implemented)" or "✓ implemented" claim.
assert_no_grep "inventory row does NOT claim '✓ implemented'" \
  "✓ implemented" "$INVENTORY"

# ── Section 4: Rubric content + cross-references ────────────────────
section "4/4" "Rubric content (operator-consumable criterion) + fixture cross-references"

# Catchphrase grep — smoke level. The structural-clause greps below are what
# actually defends against rubric-gutting (a future edit could leave the
# catchphrase in a deprecation note while replacing the live rubric body).

# Scan skill must encode the criterion + cross-link the fixture.
assert_grep "flow-inventory-codebase-scan SKILL.md contains 'operator can consume'" \
  "operator can consume" "$SCAN_SKILL"
assert_grep "flow-inventory-codebase-scan SKILL.md has § 6.1 header" \
  "6.1 BUILT criterion" "$SCAN_SKILL"
assert_grep "flow-inventory-codebase-scan SKILL.md encodes the user-facing-entry-point clause" \
  "user-facing entry point" "$SCAN_SKILL"
assert_grep "flow-inventory-codebase-scan SKILL.md explicitly rejects API-only sufficiency" \
  "API existence alone" "$SCAN_SKILL"
assert_grep "flow-inventory-codebase-scan SKILL.md cross-links the fixture" \
  "synthetic-built-criterion-drift" "$SCAN_SKILL"

# Incremental-add skill must encode the criterion + cross-link the fixture.
assert_grep "flow-inventory-add SKILL.md contains 'operator can consume'" \
  "operator can consume" "$ADD_SKILL"
assert_grep "flow-inventory-add SKILL.md has operator-consumable-criterion section" \
  "operator-consumable criterion" "$ADD_SKILL"
assert_grep "flow-inventory-add SKILL.md encodes the user-facing-entry-point clause" \
  "user-facing entry point" "$ADD_SKILL"
assert_grep "flow-inventory-add SKILL.md explicitly rejects API-only sufficiency" \
  "API existence alone" "$ADD_SKILL"
assert_grep "flow-inventory-add SKILL.md cross-links the canonical rubric" \
  "flow-inventory-codebase-scan/SKILL.md" "$ADD_SKILL"
assert_grep "flow-inventory-add SKILL.md cross-links the fixture" \
  "synthetic-built-criterion-drift" "$ADD_SKILL"

# ── Summary ──────────────────────────────────────────────────────────
printf '\nBC-10730 v-slice summary: %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
printf 'RESULT pass=%d fail=%d skip=%d\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
