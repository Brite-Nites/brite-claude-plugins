#!/usr/bin/env bash
# BC-9971 v-slice integration test for the inventory-only-domain re-scaffold
# classifier helper (`flow-classify-domain-state.sh`) — the filesystem-side
# of the Q20 amendment 1 fix.
#
# Scope: only the helper script + its 4 fixture outcomes + input-validation
# error paths. The orchestrator-side Linear-MCP overlay (`FDA: <domain>`
# milestone present?) is LLM-dispatched per Q32 and outside this harness.
#
# Bash 3.2 compatible (macOS default). Stdlib python3 only.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$PLUGIN_ROOT/scripts"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
HELPER="$SCRIPTS_DIR/flow-classify-domain-state.sh"

INVENTORY_ONLY_FIXTURE="$FIXTURES_DIR/synthetic-inventory-only-domain"
JOURNEY_EXISTS_FIXTURE="$FIXTURES_DIR/synthetic-journey-exists-domain"
FULLY_SCAFFOLDED_FIXTURE="$FIXTURES_DIR/synthetic-fully-scaffolded-domain"
GREENFIELD_FIXTURE="$FIXTURES_DIR/synthetic-greenfield"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

# Hermetic env per the greenfield-vslice precedent — drop any env-vars that
# could influence helper behavior across runs.
unset LINEAR_ISSUE_COUNT FLOW_GH_AUTH_CACHE FLOW_SHAPE_CACHE \
      _FLOW_SHAPE_INTENT_EXISTS _FLOW_SHAPE_INVENTORY_EXISTS \
      _FLOW_SHAPE_FLOWS_DIR_EXISTS _FLOW_SHAPE_BREADCRUMB_EXISTS

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP  %s — %s\n' "$1" "$2"; SKIP=$((SKIP + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Run the helper and assert exact stdout + exit code. Captures stderr
# separately so failure messages disambiguate the two channels (review fix
# 2026-05-18, test-quality-reviewer P3 #1).
assert_classification() {
  local label="$1" fixture="$2" domain="$3" expected_stdout="$4" expected_exit="$5"
  local stdout stderr exit_code stderr_file
  stderr_file="$(mktemp -t flow-9971-stderr.XXXXXX)"
  set +e
  stdout="$("$HELPER" \
      "$fixture/docs/product/master-flow-inventory.md" \
      "$fixture/docs/product/flows" \
      "$fixture/docs/product/journeys" \
      "$domain" 2>"$stderr_file")"
  exit_code=$?
  set -e
  stderr="$(cat "$stderr_file")"; rm -f "$stderr_file"
  if [ "$exit_code" -ne "$expected_exit" ]; then
    fail "$label: expected exit=$expected_exit, got exit=$exit_code (stdout='${stdout:-<empty>}' stderr='${stderr:-<empty>}')"
    return
  fi
  if [ "$stdout" != "$expected_stdout" ]; then
    fail "$label: expected stdout='$expected_stdout', got stdout='${stdout:-<empty>}' stderr='${stderr:-<empty>}'"
    return
  fi
  pass "$label"
}

# Helper for invalid-input scenarios where stdout has a stderr message we
# only need to spot-check via substring.
assert_error_exit() {
  local label="$1" expected_substring="$2"; shift 2
  local combined exit_code
  set +e
  combined="$("$HELPER" "$@" 2>&1)"
  exit_code=$?
  set -e
  if [ "$exit_code" -ne 2 ]; then
    fail "$label: expected exit=2, got exit=$exit_code (output: ${combined:-<empty>})"
    return
  fi
  if ! printf '%s' "$combined" | grep -qF "$expected_substring"; then
    fail "$label: expected stderr to contain '$expected_substring', got: ${combined:-<empty>}"
    return
  fi
  pass "$label"
}

# ── Section 1: Helper presence ──────────────────────────────────────
section "1/5" "Helper script presence"

if [ -x "$HELPER" ]; then
  pass "flow-classify-domain-state.sh present and executable"
else
  fail "flow-classify-domain-state.sh missing or not executable at $HELPER"
  exit 1
fi

# ── Section 2: Fixture presence ──────────────────────────────────────
section "2/5" "Fixture presence"

for f in "$INVENTORY_ONLY_FIXTURE" "$JOURNEY_EXISTS_FIXTURE" "$FULLY_SCAFFOLDED_FIXTURE" "$GREENFIELD_FIXTURE"; do
  if [ -d "$f" ]; then
    pass "fixture present: $(basename "$f")"
  else
    fail "fixture missing: $f"
  fi
done

# Inventory file presence per fixture — explicit check so an empty fixture
# doesn't silently flip a classification.
for f in "$INVENTORY_ONLY_FIXTURE" "$JOURNEY_EXISTS_FIXTURE" "$FULLY_SCAFFOLDED_FIXTURE"; do
  if [ -f "$f/docs/product/master-flow-inventory.md" ]; then
    pass "$(basename "$f") has master-flow-inventory.md"
  else
    fail "$(basename "$f") missing master-flow-inventory.md"
  fi
done

# Journey doc presence checks — assert the fixture state matches the README.
if [ -f "$INVENTORY_ONLY_FIXTURE/docs/product/journeys/asset-discovery.md" ]; then
  fail "synthetic-inventory-only-domain has a journey doc — should be absent"
else
  pass "synthetic-inventory-only-domain has no journey doc (expected)"
fi
if [ -f "$JOURNEY_EXISTS_FIXTURE/docs/product/journeys/asset-discovery.md" ]; then
  pass "synthetic-journey-exists-domain has journey doc (expected)"
else
  fail "synthetic-journey-exists-domain missing journey doc"
fi
if [ -f "$FULLY_SCAFFOLDED_FIXTURE/docs/product/journeys/asset-discovery.md" ]; then
  pass "synthetic-fully-scaffolded-domain has journey doc (expected)"
else
  fail "synthetic-fully-scaffolded-domain missing journey doc"
fi
if [ -f "$FULLY_SCAFFOLDED_FIXTURE/docs/product/flows/asset-discovery/asset-discovery-01.md" ]; then
  pass "synthetic-fully-scaffolded-domain has story doc (expected)"
else
  fail "synthetic-fully-scaffolded-domain missing story doc"
fi

# ── Section 3: Four-outcome classification ───────────────────────────
section "3/5" "Four classification outcomes"

# `absent` — greenfield fixture has no inventory file at all; the helper
# should exit 2 with the missing-inventory error rather than fall through
# to a misclassification. (This protects against a future regression where
# `absent` is silently returned for a missing-inventory rather than a
# present-inventory-without-the-H3.)
assert_error_exit "greenfield (no inventory file) -> exit 2" \
  "inventory-path" \
  "$GREENFIELD_FIXTURE/docs/product/master-flow-inventory.md" \
  "$GREENFIELD_FIXTURE/docs/product/flows" \
  "$GREENFIELD_FIXTURE/docs/product/journeys" \
  "asset-discovery"

# `absent` — inventory file present, but DOMAIN not in it.
assert_classification \
  "inventory-only fixture + nonexistent domain -> absent" \
  "$INVENTORY_ONLY_FIXTURE" \
  "nonexistent" \
  "absent" \
  0

# `inventory-only` — H3 present, no journey doc, no story docs.
assert_classification \
  "synthetic-inventory-only-domain + asset-discovery -> inventory-only" \
  "$INVENTORY_ONLY_FIXTURE" \
  "asset-discovery" \
  "inventory-only" \
  0

# `journey-exists` — H3 present, journey doc present, no story docs.
assert_classification \
  "synthetic-journey-exists-domain + asset-discovery -> journey-exists" \
  "$JOURNEY_EXISTS_FIXTURE" \
  "asset-discovery" \
  "journey-exists" \
  0

# `fully-scaffolded-fs` — H3 present, journey doc present, story doc present.
assert_classification \
  "synthetic-fully-scaffolded-domain + asset-discovery -> fully-scaffolded-fs" \
  "$FULLY_SCAFFOLDED_FIXTURE" \
  "asset-discovery" \
  "fully-scaffolded-fs" \
  0

# ── Section 4: Input validation ──────────────────────────────────────
section "4/5" "Input validation (exit 2 paths)"

# Missing positional args.
assert_error_exit "no args -> exit 2" "usage:"
assert_error_exit "three args -> exit 2" "usage:" "$INVENTORY_ONLY_FIXTURE/docs/product/master-flow-inventory.md" "$INVENTORY_ONLY_FIXTURE/docs/product/flows" "$INVENTORY_ONLY_FIXTURE/docs/product/journeys"

# Empty DOMAIN string.
assert_error_exit "empty DOMAIN -> exit 2" "DOMAIN" \
  "$INVENTORY_ONLY_FIXTURE/docs/product/master-flow-inventory.md" \
  "$INVENTORY_ONLY_FIXTURE/docs/product/flows" \
  "$INVENTORY_ONLY_FIXTURE/docs/product/journeys" \
  ""

# Domain code violating Q20 amendment 2 schema (UPPERCASE / space / slash /
# dot-dot / underscore / leading-digit). Lowercase kebab-case is the only
# valid form post-BC-10352.
for bad in "ASSET-DISCOVERY" "asset discovery" "asset/discovery" "../asset" "asset_discovery" "9-startswith-digit"; do
  assert_error_exit "DOMAIN='$bad' rejected by Q20 amendment 2 schema -> exit 2" "Q20 amendment 2 schema" \
    "$INVENTORY_ONLY_FIXTURE/docs/product/master-flow-inventory.md" \
    "$INVENTORY_ONLY_FIXTURE/docs/product/flows" \
    "$INVENTORY_ONLY_FIXTURE/docs/product/journeys" \
    "$bad"
done

# Missing inventory file.
assert_error_exit "missing inventory file -> exit 2" "inventory-path" \
  "/tmp/flow-9971-does-not-exist.$$.md" \
  "$INVENTORY_ONLY_FIXTURE/docs/product/flows" \
  "$INVENTORY_ONLY_FIXTURE/docs/product/journeys" \
  "asset-discovery"

# ── Section 5: H3 boundary precision ─────────────────────────────────
section "5/5" "H3 boundary precision (no prefix-match false positives)"

# Verify the H3 regex requires a whitespace boundary after DOMAIN. Build an
# inline scratch fixture with a `### asset-discovery-extended` H3 (no
# `### asset-discovery ` line); classifier should report `absent` for
# asset-discovery rather than match the prefix line. Schema reflects Q20
# amendment 2 (BC-10352): lowercase + backtick + em-dash.
SCRATCH="$(mktemp -d -t flow-9971.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

mkdir -p "$SCRATCH/docs/product/flows" "$SCRATCH/docs/product/journeys"
printf '# Master Flow Inventory\n\n### `asset-discovery-extended` — Extended (1 flows)\n\n| ID | Title |\n|---|---|\n| asset-discovery-extended-01 | Foo |\n' \
  > "$SCRATCH/docs/product/master-flow-inventory.md"

assert_classification \
  "prefix-only H3 (asset-discovery-extended) does NOT match asset-discovery -> absent" \
  "$SCRATCH" \
  "asset-discovery" \
  "absent" \
  0

# And the reverse — searching for the actual H3 prefix returns inventory-only.
assert_classification \
  "asset-discovery-extended + matching DOMAIN -> inventory-only" \
  "$SCRATCH" \
  "asset-discovery-extended" \
  "inventory-only" \
  0

# UPPERCASE H3 must not match lowercase DOMAIN — grep is case-sensitive.
# Also: under Q20 amendment 2 the regex pre-rejects UPPERCASE DOMAIN before
# the grep runs; this assertion targets the regex layer.
printf '# Master Flow Inventory\n\n### `ASSET-DISCOVERY` — foo (1 flows)\n' \
  > "$SCRATCH/docs/product/master-flow-inventory.md"
assert_classification \
  "UPPERCASE H3 does NOT match lowercase DOMAIN -> absent" \
  "$SCRATCH" \
  "asset-discovery" \
  "absent" \
  0

# Trailing-hyphen-only DOMAIN H3 must not match because the regex requires a
# whitespace boundary after the slug.
printf '# Master Flow Inventory\n\n### `asset-discovery-`\n' \
  > "$SCRATCH/docs/product/master-flow-inventory.md"
assert_classification \
  "trailing-hyphen-only H3 does NOT match asset-discovery -> absent" \
  "$SCRATCH" \
  "asset-discovery" \
  "absent" \
  0

# H3 at EOF with no terminal newline still matches — defends against LLM
# authoring sub-skills that emit files without trailing \n.
printf '# Master Flow Inventory\n\n### `asset-discovery` — foo (1 flows)' \
  > "$SCRATCH/docs/product/master-flow-inventory.md"
assert_classification \
  "H3 at EOF without newline still matches -> inventory-only" \
  "$SCRATCH" \
  "asset-discovery" \
  "inventory-only" \
  0

# Non-story-shaped *.md inside the flows subdir must NOT flip to
# fully-scaffolded-fs — defends the tightened `<DOMAIN>-NN.md` shape filter
# in the classifier against accidental README.md / INDEX.md tripwires.
mkdir -p "$SCRATCH/docs/product/flows/asset-discovery"
printf '# README\n' > "$SCRATCH/docs/product/flows/asset-discovery/README.md"
printf '# Index\n' > "$SCRATCH/docs/product/flows/asset-discovery/INDEX.md"
# Restore a valid inventory H3 (the prior writes left it short).
printf '# Master Flow Inventory\n\n### `asset-discovery` — foo (1 flows)\n' \
  > "$SCRATCH/docs/product/master-flow-inventory.md"
mkdir -p "$SCRATCH/docs/product/journeys"
printf '# Stub\n' > "$SCRATCH/docs/product/journeys/asset-discovery.md"
assert_classification \
  "README.md + INDEX.md in flows subdir do NOT count as stories -> journey-exists" \
  "$SCRATCH" \
  "asset-discovery" \
  "journey-exists" \
  0

# Adding a story-doc-shaped file flips to fully-scaffolded-fs.
printf '# Story\n' > "$SCRATCH/docs/product/flows/asset-discovery/asset-discovery-01.md"
assert_classification \
  "adding asset-discovery-01.md flips to fully-scaffolded-fs" \
  "$SCRATCH" \
  "asset-discovery" \
  "fully-scaffolded-fs" \
  0

# ── Summary ──────────────────────────────────────────────────────────
printf '\nBC-9971 v-slice summary: %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
