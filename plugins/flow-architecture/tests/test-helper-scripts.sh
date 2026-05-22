#!/usr/bin/env bash
# BC-10728 unit tests for the 4 flow-architecture helper scripts:
#
#   1. flow-detect-mode.sh        — greenfield/retrofit/incremental-add/resume classifier
#   2. flow-detect-fda-shape.sh   — intent / inventory / flows-dir / breadcrumb existence
#   3. flow-resume-breadcrumb.sh  — read/write `docs/plans/.flow-phase-state.json`
#   4. flow-classify-domain-state.sh — Branch A/B classifier for /flow:add-domain
#
# Hand-rolled assertion harness (no bats-core dep). Bash 3.2 compatible
# (macOS default) per FDA parking-lot #32. Stdlib python3 only.
#
# BC-10352 regression lock (Section 4): the classifier MUST accept Brand Hub
# iter-2's shipped inventory shape — lowercase kebab-case domain slugs,
# backtick-wrapped H3 headers, em-dash separator. Before BC-10352's Path A
# fix lands, the lowercase + backtick assertions HARD-FAIL on the
# validate-DOMAIN regex + H3 grep blocks of flow-classify-domain-state.sh.
# That failure is the regression-catch evidence.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$PLUGIN_ROOT/scripts"
DETECT_MODE="$SCRIPTS_DIR/flow-detect-mode.sh"
DETECT_SHAPE="$SCRIPTS_DIR/flow-detect-fda-shape.sh"
BREADCRUMB="$SCRIPTS_DIR/flow-resume-breadcrumb.sh"
CLASSIFIER="$SCRIPTS_DIR/flow-classify-domain-state.sh"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 2; }

# Hermetic env — match the vslice precedent so detect-mode behavior doesn't
# leak from a parent shell. If those helpers rename or add private vars,
# update this list (a stale unset silently drops hermeticity).
unset LINEAR_ISSUE_COUNT FLOW_GH_AUTH_CACHE FLOW_SHAPE_CACHE \
      _FLOW_SHAPE_INTENT_EXISTS _FLOW_SHAPE_INVENTORY_EXISTS \
      _FLOW_SHAPE_FLOWS_DIR_EXISTS _FLOW_SHAPE_BREADCRUMB_EXISTS

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Scratch dir + cleanup trap (test-isolated; survives partial failures).
SCRATCH_ROOT="$(mktemp -d -t flow-bc-10728.XXXXXX)"
cleanup() { rm -rf "$SCRATCH_ROOT"; }
trap cleanup EXIT

# Per-test scratch dir factory.
new_scratch() {
  local d
  d="$(mktemp -d "$SCRATCH_ROOT/case.XXXXXX")"
  mkdir -p "$d/docs/product/flows" "$d/docs/product/journeys" "$d/docs/plans"
  echo "$d"
}

# UTC ISO-8601 timestamp factory — single source for breadcrumb test fixtures
# so non-adjacent tests don't share an implicit-state variable.
now_iso() {
  python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00","Z"))'
}

# Run a command, capture stdout + stderr + exit-code, expose as $STDOUT,
# $STDERR, $EXIT.
run_capture() {
  local stderr_file
  stderr_file="$(mktemp -t flow-stderr.XXXXXX)"
  set +e
  STDOUT="$("$@" 2>"$stderr_file")"
  EXIT=$?
  set -e
  STDERR="$(cat "$stderr_file")"
  rm -f "$stderr_file"
}

# ──────────────────────────────────────────────────────────────────────
# Section 1 — flow-detect-fda-shape.sh
# ──────────────────────────────────────────────────────────────────────
section "1/4" "flow-detect-fda-shape.sh"

# 1.1 — pristine empty repo: all flags 'no'.
SC1="$(new_scratch)"
run_capture "$DETECT_SHAPE" "$SC1"
if [ "$EXIT" -eq 0 ] \
   && printf '%s\n' "$STDOUT" | grep -q '^INTENT_EXISTS=no$' \
   && printf '%s\n' "$STDOUT" | grep -q '^INVENTORY_EXISTS=no$' \
   && printf '%s\n' "$STDOUT" | grep -q '^FLOWS_DIR_EXISTS=no$' \
   && printf '%s\n' "$STDOUT" | grep -q '^JOURNEYS_DIR_EXISTS=no$' \
   && printf '%s\n' "$STDOUT" | grep -q '^BREADCRUMB_EXISTS=no$'; then
  pass "pristine repo emits all-no flags"
else
  fail "pristine repo: expected 5 *_EXISTS=no lines, got EXIT=$EXIT stdout='${STDOUT}'"
fi

# 1.2 — populated: intent + inventory + flows/*.md → corresponding flags 'yes'.
SC2="$(new_scratch)"
printf '# intent\n' > "$SC2/docs/product/intent.md"
printf '# inventory\n' > "$SC2/docs/product/master-flow-inventory.md"
printf '# story\n' > "$SC2/docs/product/flows/example-flow.md"
run_capture "$DETECT_SHAPE" "$SC2"
if [ "$EXIT" -eq 0 ] \
   && printf '%s\n' "$STDOUT" | grep -q '^INTENT_EXISTS=yes$' \
   && printf '%s\n' "$STDOUT" | grep -q '^INVENTORY_EXISTS=yes$' \
   && printf '%s\n' "$STDOUT" | grep -q '^FLOWS_DIR_EXISTS=yes$'; then
  pass "populated repo flips intent/inventory/flows to yes"
else
  fail "populated repo: stdout='${STDOUT}'"
fi

# 1.3 — empty flows/ dir (no *.md) → FLOWS_DIR_EXISTS=no per "dir + at least one *.md" rule.
SC3="$(new_scratch)"
run_capture "$DETECT_SHAPE" "$SC3"
if printf '%s\n' "$STDOUT" | grep -q '^FLOWS_DIR_EXISTS=no$'; then
  pass "empty flows/ dir without *.md emits FLOWS_DIR_EXISTS=no"
else
  fail "empty flows/ dir: stdout='${STDOUT}'"
fi

# 1.4 — breadcrumb file presence → BREADCRUMB_EXISTS=yes.
SC4="$(new_scratch)"
printf '{}\n' > "$SC4/docs/plans/.flow-phase-state.json"
run_capture "$DETECT_SHAPE" "$SC4"
if printf '%s\n' "$STDOUT" | grep -q '^BREADCRUMB_EXISTS=yes$'; then
  pass "breadcrumb file present emits BREADCRUMB_EXISTS=yes"
else
  fail "breadcrumb present: stdout='${STDOUT}'"
fi

# 1.5 — invalid REPO_ROOT → exit 1 with diagnostic on stderr.
run_capture "$DETECT_SHAPE" "/tmp/flow-bc-10728-does-not-exist-$$"
if [ "$EXIT" -eq 1 ] && printf '%s' "$STDERR" | grep -q "REPO_ROOT"; then
  pass "invalid REPO_ROOT exits 1 with diagnostic"
else
  fail "invalid REPO_ROOT: EXIT=$EXIT stderr='${STDERR}'"
fi

# ──────────────────────────────────────────────────────────────────────
# Section 2 — flow-resume-breadcrumb.sh
# ──────────────────────────────────────────────────────────────────────
section "2/4" "flow-resume-breadcrumb.sh"

# 2.1 — read missing breadcrumb → EXISTS=no, soft-pass.
SC_BC1="$(new_scratch)"
run_capture "$BREADCRUMB" read "$SC_BC1/docs/plans/.flow-phase-state.json"
if [ "$EXIT" -eq 0 ] && printf '%s\n' "$STDOUT" | grep -q '^EXISTS=no$'; then
  pass "read missing breadcrumb → EXISTS=no, exit 0"
else
  fail "read missing breadcrumb: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 2.2 — read in_flight breadcrumb with fresh timestamp → STALE=no.
SC_BC2="$(new_scratch)"
printf '{"status":"in_flight","last_updated":"%s"}\n' "$(now_iso)" \
  > "$SC_BC2/docs/plans/.flow-phase-state.json"
run_capture "$BREADCRUMB" read "$SC_BC2/docs/plans/.flow-phase-state.json"
if [ "$EXIT" -eq 0 ] \
   && printf '%s\n' "$STDOUT" | grep -q '^EXISTS=yes$' \
   && printf '%s\n' "$STDOUT" | grep -q '^STATUS=in_flight$' \
   && printf '%s\n' "$STDOUT" | grep -q '^STALE=no$'; then
  pass "fresh in_flight breadcrumb → STATUS=in_flight, STALE=no"
else
  fail "fresh breadcrumb: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 2.3 — read aged breadcrumb (> 7 days) → STALE=yes, STALE_REASON=age.
SC_BC3="$(new_scratch)"
OLD_ISO="2020-01-01T00:00:00Z"
printf '{"status":"in_flight","last_updated":"%s"}\n' "$OLD_ISO" \
  > "$SC_BC3/docs/plans/.flow-phase-state.json"
run_capture "$BREADCRUMB" read "$SC_BC3/docs/plans/.flow-phase-state.json"
if printf '%s\n' "$STDOUT" | grep -q '^STALE=yes$' \
   && printf '%s\n' "$STDOUT" | grep -q '^STALE_REASON=age$'; then
  pass "aged breadcrumb → STALE=yes, STALE_REASON=age"
else
  fail "aged breadcrumb: stdout='${STDOUT}'"
fi

# 2.4 — read malformed JSON → STALE=yes, STALE_REASON=parse-error (soft-fail).
SC_BC4="$(new_scratch)"
printf 'this is not json {' > "$SC_BC4/docs/plans/.flow-phase-state.json"
run_capture "$BREADCRUMB" read "$SC_BC4/docs/plans/.flow-phase-state.json"
if [ "$EXIT" -eq 0 ] \
   && printf '%s\n' "$STDOUT" | grep -q '^STALE=yes$' \
   && printf '%s\n' "$STDOUT" | grep -q '^STALE_REASON=parse-error$'; then
  pass "malformed JSON breadcrumb → STALE=yes, parse-error"
else
  fail "malformed JSON: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 2.5 — write happy-path → file lands with content-match.
SC_BC5="$(new_scratch)"
INPUT_BC5="$(mktemp -t flow-bc5.XXXXXX)"
printf '{"status":"in_flight","current_phase":3}\n' > "$INPUT_BC5"
run_capture "$BREADCRUMB" write "$SC_BC5/docs/plans/.flow-phase-state.json" "$INPUT_BC5"
if [ "$EXIT" -eq 0 ] \
   && [ -f "$SC_BC5/docs/plans/.flow-phase-state.json" ] \
   && grep -q '"status"' "$SC_BC5/docs/plans/.flow-phase-state.json"; then
  pass "write happy-path lands breadcrumb"
else
  fail "write happy-path: EXIT=$EXIT stdout='${STDOUT}' stderr='${STDERR}'"
fi
rm -f "$INPUT_BC5"

# 2.6 — write malformed JSON input → exit 3, target untouched.
SC_BC6="$(new_scratch)"
INPUT_BC6="$(mktemp -t flow-bc6.XXXXXX)"
printf 'not valid json' > "$INPUT_BC6"
run_capture "$BREADCRUMB" write "$SC_BC6/docs/plans/.flow-phase-state.json" "$INPUT_BC6"
if [ "$EXIT" -eq 3 ] && [ ! -f "$SC_BC6/docs/plans/.flow-phase-state.json" ]; then
  pass "write malformed JSON → exit 3, target file not created"
else
  fail "write malformed: EXIT=$EXIT target-exists=$([ -f "$SC_BC6/docs/plans/.flow-phase-state.json" ] && echo yes || echo no)"
fi
rm -f "$INPUT_BC6"

# 2.7 — write missing input file → exit 3.
SC_BC7="$(new_scratch)"
run_capture "$BREADCRUMB" write "$SC_BC7/docs/plans/.flow-phase-state.json" "/tmp/flow-bc-10728-missing-input-$$"
if [ "$EXIT" -eq 3 ]; then
  pass "write missing input → exit 3"
else
  fail "write missing input: EXIT=$EXIT"
fi

# 2.8 — usage error: write with no args → exit 2 WITH usage message.
# Substring assertion guards against a future refactor that returns exit 2
# for unrelated reasons (e.g., python3 missing) silently passing this test.
run_capture "$BREADCRUMB" write
if [ "$EXIT" -eq 2 ] && printf '%s' "$STDERR" | grep -qiE 'usage|state-path|input-path'; then
  pass "write with no args → exit 2 (usage message present)"
else
  fail "write no args: EXIT=$EXIT stderr='${STDERR}'"
fi

# 2.9 — read breadcrumb with status=completed → STALE=yes, STALE_REASON=status-completed.
SC_BC9="$(new_scratch)"
printf '{"status":"completed","last_updated":"%s"}\n' "$(now_iso)" \
  > "$SC_BC9/docs/plans/.flow-phase-state.json"
run_capture "$BREADCRUMB" read "$SC_BC9/docs/plans/.flow-phase-state.json"
if printf '%s\n' "$STDOUT" | grep -q '^STALE=yes$' \
   && printf '%s\n' "$STDOUT" | grep -q '^STALE_REASON=status-completed$'; then
  pass "completed breadcrumb → STALE=yes, STALE_REASON=status-completed"
else
  fail "completed-status: stdout='${STDOUT}'"
fi

# 2.10 — read breadcrumb with status=abandoned → STALE=yes, STALE_REASON=status-abandoned.
SC_BC10="$(new_scratch)"
printf '{"status":"abandoned","last_updated":"%s"}\n' "$(now_iso)" \
  > "$SC_BC10/docs/plans/.flow-phase-state.json"
run_capture "$BREADCRUMB" read "$SC_BC10/docs/plans/.flow-phase-state.json"
if printf '%s\n' "$STDOUT" | grep -q '^STALE=yes$' \
   && printf '%s\n' "$STDOUT" | grep -q '^STALE_REASON=status-abandoned$'; then
  pass "abandoned breadcrumb → STALE=yes, STALE_REASON=status-abandoned"
else
  fail "abandoned-status: stdout='${STDOUT}'"
fi

# ──────────────────────────────────────────────────────────────────────
# Section 3 — flow-detect-mode.sh
# ──────────────────────────────────────────────────────────────────────
section "3/4" "flow-detect-mode.sh"

# 3.1 — pristine repo, no LINEAR_ISSUE_COUNT → greenfield.
SC_M1="$(new_scratch)"
run_capture "$DETECT_MODE" "$SC_M1"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "greenfield" ]; then
  pass "pristine repo → greenfield"
else
  fail "pristine→greenfield: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 3.2 — pristine repo, LINEAR_ISSUE_COUNT=42 → retrofit (Q36.3 step 4 heuristic).
SC_M2="$(new_scratch)"
set +e
STDOUT="$(LINEAR_ISSUE_COUNT=42 "$DETECT_MODE" "$SC_M2" 2>/dev/null)"
EXIT=$?
set -e
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "retrofit" ]; then
  pass "pristine + LINEAR_ISSUE_COUNT=42 → retrofit"
else
  fail "linear-count→retrofit: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 3.3 — pristine repo, LINEAR_ISSUE_COUNT=5 → greenfield (< 10 threshold).
SC_M3="$(new_scratch)"
set +e
STDOUT="$(LINEAR_ISSUE_COUNT=5 "$DETECT_MODE" "$SC_M3" 2>/dev/null)"
EXIT=$?
set -e
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "greenfield" ]; then
  pass "pristine + LINEAR_ISSUE_COUNT=5 → greenfield"
else
  fail "linear-count<10→greenfield: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 3.4 — pristine repo, malformed LINEAR_ISSUE_COUNT → greenfield + diagnostic.
SC_M4="$(new_scratch)"
set +e
STDOUT="$(LINEAR_ISSUE_COUNT=not-a-number "$DETECT_MODE" "$SC_M4" 2>/dev/null)"
EXIT=$?
set -e
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "greenfield" ]; then
  pass "malformed LINEAR_ISSUE_COUNT → greenfield (graceful fallback)"
else
  fail "malformed count: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 3.5 — intent + inventory but no flows → retrofit (Q12 edge).
SC_M5="$(new_scratch)"
printf '# intent\n' > "$SC_M5/docs/product/intent.md"
printf '# inventory\n' > "$SC_M5/docs/product/master-flow-inventory.md"
run_capture "$DETECT_MODE" "$SC_M5"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "retrofit" ]; then
  pass "intent + inventory without flows → retrofit"
else
  fail "retrofit edge: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 3.6 — full FDA shape (intent + inventory + flows) → incremental-add.
SC_M6="$(new_scratch)"
printf '# intent\n' > "$SC_M6/docs/product/intent.md"
printf '# inventory\n' > "$SC_M6/docs/product/master-flow-inventory.md"
printf '# story\n' > "$SC_M6/docs/product/flows/example.md"
run_capture "$DETECT_MODE" "$SC_M6"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "incremental-add" ]; then
  pass "full FDA shape → incremental-add"
else
  fail "incremental-add: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 3.7 — fresh in_flight breadcrumb → resume (takes precedence over artifacts).
SC_M7="$(new_scratch)"
printf '# intent\n' > "$SC_M7/docs/product/intent.md"
printf '# inventory\n' > "$SC_M7/docs/product/master-flow-inventory.md"
printf '# story\n' > "$SC_M7/docs/product/flows/example.md"
printf '{"status":"in_flight","last_updated":"%s"}\n' "$(now_iso)" \
  > "$SC_M7/docs/plans/.flow-phase-state.json"
run_capture "$DETECT_MODE" "$SC_M7"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "resume" ]; then
  pass "fresh in_flight breadcrumb → resume (precedence)"
else
  fail "resume precedence: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 3.8 — stale (completed) breadcrumb → fall through to artifact-driven mode.
SC_M8="$(new_scratch)"
printf '# intent\n' > "$SC_M8/docs/product/intent.md"
printf '# inventory\n' > "$SC_M8/docs/product/master-flow-inventory.md"
printf '# story\n' > "$SC_M8/docs/product/flows/example.md"
printf '{"status":"completed","last_updated":"2025-01-01T00:00:00Z"}\n' \
  > "$SC_M8/docs/plans/.flow-phase-state.json"
run_capture "$DETECT_MODE" "$SC_M8"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "incremental-add" ]; then
  pass "stale (completed) breadcrumb falls through → incremental-add"
else
  fail "stale fall-through: EXIT=$EXIT stdout='${STDOUT}'"
fi

# ──────────────────────────────────────────────────────────────────────
# Section 4 — flow-classify-domain-state.sh (BC-10352 regression lock)
# ──────────────────────────────────────────────────────────────────────
section "4/4" "flow-classify-domain-state.sh — BC-10352 schema axes"

# Helper: build a Brand-Hub-iter-2-shape inventory (lowercase + backtick +
# em-dash) on the fly. Mirrors the actual iter-2 inventory at
# brand-hub/docs/product/master-flow-inventory.md (per
# brand-hub-dogfood-findings § iter-2/iter-3 lines).
make_iter2_inventory() {
  local dir="$1"
  cat > "$dir/docs/product/master-flow-inventory.md" <<'INV'
# Master Flow Inventory

Fixture for BC-10352 — Brand Hub iter-2 shipped inventory shape.

## PLATFORM FOUNDATIONS

### `asset-foundation` — Asset Foundation (3 flows)

| ID | Title | Primary persona | Notes |
|---|---|---|---|
| asset-foundation-01 | Asset upload | Brand admin | mvp |
| asset-foundation-02 | Asset metadata | Brand admin | mvp |
| asset-foundation-03 | Asset versioning | Brand admin | nice-to-have |

### `asset-discovery` — Asset Discovery & Catalog (3 flows)

| ID | Title | Primary persona | Notes |
|---|---|---|---|
| asset-discovery-01 | Browse catalog | Brand admin | mvp |
| asset-discovery-02 | Search by metadata | Brand admin | mvp |
| asset-discovery-03 | Filter by collection | Brand admin | nice-to-have |

### `asset-content-libraries` — Content Libraries (2 flows)

| ID | Title | Primary persona | Notes |
|---|---|---|---|
| asset-content-libraries-01 | Browse libraries | Brand admin | mvp |
| asset-content-libraries-02 | Manage libraries | Brand admin | mvp |

---
INV
}

# 4.1 — BC-10352 axis 1 (case): lowercase domain slug must validate.
# Pre-fix: regex `^[A-Z][A-Z0-9_-]*$` rejects `asset-foundation` → exit 2.
# Post-fix: lowercase is canonical, accepted; classification proceeds.
SC_C1="$(new_scratch)"
make_iter2_inventory "$SC_C1"
run_capture "$CLASSIFIER" \
  "$SC_C1/docs/product/master-flow-inventory.md" \
  "$SC_C1/docs/product/flows" \
  "$SC_C1/docs/product/journeys" \
  "asset-foundation"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "inventory-only" ]; then
  pass "BC-10352 axis-1 (lowercase 'asset-foundation') → inventory-only"
else
  fail "BC-10352 axis-1: EXIT=$EXIT stdout='${STDOUT}' stderr='${STDERR}'"
fi

# 4.2 — BC-10352 axis 2 (backtick wrap): backtick-wrapped H3 must match.
# Pre-fix: H3 grep `^### ${DOMAIN}[[:space:]]` doesn't match `### \`<domain>\``.
# Post-fix: optional backtick wrap accepted.
SC_C2="$(new_scratch)"
make_iter2_inventory "$SC_C2"
run_capture "$CLASSIFIER" \
  "$SC_C2/docs/product/master-flow-inventory.md" \
  "$SC_C2/docs/product/flows" \
  "$SC_C2/docs/product/journeys" \
  "asset-discovery"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "inventory-only" ]; then
  pass "BC-10352 axis-2 (backtick-wrapped H3 'asset-discovery') → inventory-only"
else
  fail "BC-10352 axis-2: EXIT=$EXIT stdout='${STDOUT}' stderr='${STDERR}'"
fi

# 4.3 — BC-10352 axis 3 (em-dash separator): em-dash must NOT block matching.
# The classifier already uses a whitespace-boundary regex (separator-agnostic),
# so this axis is the schema-canonicalization axis: Q20.3 + iter-2 reality
# both use em-dash; flow-inventory-add Section 3 must align.
SC_C3="$(new_scratch)"
make_iter2_inventory "$SC_C3"
run_capture "$CLASSIFIER" \
  "$SC_C3/docs/product/master-flow-inventory.md" \
  "$SC_C3/docs/product/flows" \
  "$SC_C3/docs/product/journeys" \
  "asset-content-libraries"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "inventory-only" ]; then
  pass "BC-10352 axis-3 (em-dash separator, multi-hyphen slug) → inventory-only"
else
  fail "BC-10352 axis-3: EXIT=$EXIT stdout='${STDOUT}' stderr='${STDERR}'"
fi

# 4.4 — full BC-10352 fixture, NONEXISTENT slug → absent.
SC_C4="$(new_scratch)"
make_iter2_inventory "$SC_C4"
run_capture "$CLASSIFIER" \
  "$SC_C4/docs/product/master-flow-inventory.md" \
  "$SC_C4/docs/product/flows" \
  "$SC_C4/docs/product/journeys" \
  "nonexistent-domain"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "absent" ]; then
  pass "BC-10352 fixture + nonexistent slug → absent"
else
  fail "absent on iter-2 fixture: EXIT=$EXIT stdout='${STDOUT}' stderr='${STDERR}'"
fi

# 4.5 — full iter-2 flow path: H3 present + journey doc present → journey-exists.
SC_C5="$(new_scratch)"
make_iter2_inventory "$SC_C5"
printf '# Asset Foundation journey\n' > "$SC_C5/docs/product/journeys/asset-foundation.md"
run_capture "$CLASSIFIER" \
  "$SC_C5/docs/product/master-flow-inventory.md" \
  "$SC_C5/docs/product/flows" \
  "$SC_C5/docs/product/journeys" \
  "asset-foundation"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "journey-exists" ]; then
  pass "iter-2 fixture + journey doc → journey-exists"
else
  fail "journey-exists: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 4.6 — full iter-2 flow path: H3 + journey doc + story doc → fully-scaffolded-fs.
SC_C6="$(new_scratch)"
make_iter2_inventory "$SC_C6"
printf '# Asset Foundation journey\n' > "$SC_C6/docs/product/journeys/asset-foundation.md"
mkdir -p "$SC_C6/docs/product/flows/asset-foundation"
printf '# Asset Foundation 01 story\n' > "$SC_C6/docs/product/flows/asset-foundation/asset-foundation-01.md"
run_capture "$CLASSIFIER" \
  "$SC_C6/docs/product/master-flow-inventory.md" \
  "$SC_C6/docs/product/flows" \
  "$SC_C6/docs/product/journeys" \
  "asset-foundation"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "fully-scaffolded-fs" ]; then
  pass "iter-2 fixture + journey + story → fully-scaffolded-fs"
else
  fail "fully-scaffolded-fs: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 4.7 — invalid DOMAIN value (UPPERCASE under Q20 amendment 2) → exit 2.
# Post-fix: UPPERCASE is no longer valid; the regex rejects it. Defends
# against accidental schema regression that would re-accept UPPERCASE.
SC_C7="$(new_scratch)"
make_iter2_inventory "$SC_C7"
run_capture "$CLASSIFIER" \
  "$SC_C7/docs/product/master-flow-inventory.md" \
  "$SC_C7/docs/product/flows" \
  "$SC_C7/docs/product/journeys" \
  "ASSET-FOUNDATION"
# Substring is anchored to the regex literal itself ([a-z][a-z0-9-]*) so a
# future refactor that drops the word "schema" from the error string can't
# silently pass this test. Guards against the review P2 noted on round 1.
if [ "$EXIT" -eq 2 ] && printf '%s' "$STDERR" | grep -qE '\[a-z\]\[a-z0-9-\]|Q20'; then
  pass "UPPERCASE DOMAIN rejected by Q20 amendment 2 schema → exit 2"
else
  fail "UPPERCASE rejection: EXIT=$EXIT stderr='${STDERR}'"
fi

# 4.8 — empty DOMAIN → exit 2.
SC_C8="$(new_scratch)"
make_iter2_inventory "$SC_C8"
run_capture "$CLASSIFIER" \
  "$SC_C8/docs/product/master-flow-inventory.md" \
  "$SC_C8/docs/product/flows" \
  "$SC_C8/docs/product/journeys" \
  ""
if [ "$EXIT" -eq 2 ]; then
  pass "empty DOMAIN → exit 2"
else
  fail "empty DOMAIN: EXIT=$EXIT"
fi

# 4.9 — missing inventory file → exit 2 with diagnostic.
run_capture "$CLASSIFIER" \
  "/tmp/flow-bc-10728-missing-inventory-$$.md" \
  "/tmp/flow-bc-10728-missing-flows-$$" \
  "/tmp/flow-bc-10728-missing-journeys-$$" \
  "asset-foundation"
if [ "$EXIT" -eq 2 ] && printf '%s' "$STDERR" | grep -q "inventory-path"; then
  pass "missing inventory file → exit 2 with diagnostic"
else
  fail "missing inventory: EXIT=$EXIT stderr='${STDERR}'"
fi

# 4.10 — bare (non-backticked) iter-2 H3 still matches.
# Brand Hub's actual iter-2 inventory mixes backtick-wrapped and bare H3s
# (the classifier should tolerate either). Defends against regressing the
# fix to backtick-required.
SC_C10="$(new_scratch)"
cat > "$SC_C10/docs/product/master-flow-inventory.md" <<'INV'
# Master Flow Inventory

## PLATFORM FOUNDATIONS

### asset-foundation — Asset Foundation (1 flows)

| ID | Title |
|---|---|
| asset-foundation-01 | foo |

---
INV
run_capture "$CLASSIFIER" \
  "$SC_C10/docs/product/master-flow-inventory.md" \
  "$SC_C10/docs/product/flows" \
  "$SC_C10/docs/product/journeys" \
  "asset-foundation"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "inventory-only" ]; then
  pass "bare H3 (no backtick) still matches under post-fix schema"
else
  fail "bare H3: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 4.11 — prefix-match defense: `### asset-foundation-extended` does NOT
# match for DOMAIN=asset-foundation. The whitespace boundary after the
# closing-backtick-or-domain-end must hold.
SC_C11="$(new_scratch)"
cat > "$SC_C11/docs/product/master-flow-inventory.md" <<'INV'
# Master Flow Inventory

### `asset-foundation-extended` — Extended (1 flows)

| ID | Title |
|---|---|
| asset-foundation-extended-01 | foo |
INV
run_capture "$CLASSIFIER" \
  "$SC_C11/docs/product/master-flow-inventory.md" \
  "$SC_C11/docs/product/flows" \
  "$SC_C11/docs/product/journeys" \
  "asset-foundation"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "absent" ]; then
  pass "prefix-only H3 (asset-foundation-extended) does NOT match asset-foundation"
else
  fail "prefix-match defense: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 4.12 — H3 at EOF without trailing newline still matches.
SC_C12="$(new_scratch)"
printf '# inv\n\n### `asset-foundation` — foo (1 flows)' \
  > "$SC_C12/docs/product/master-flow-inventory.md"
run_capture "$CLASSIFIER" \
  "$SC_C12/docs/product/master-flow-inventory.md" \
  "$SC_C12/docs/product/flows" \
  "$SC_C12/docs/product/journeys" \
  "asset-foundation"
if [ "$EXIT" -eq 0 ] && [ "$STDOUT" = "inventory-only" ]; then
  pass "H3 at EOF without trailing newline still matches"
else
  fail "EOF-no-newline: EXIT=$EXIT stdout='${STDOUT}'"
fi

# 4.13 — DOMAIN with leading digit rejected by schema.
SC_C13="$(new_scratch)"
make_iter2_inventory "$SC_C13"
run_capture "$CLASSIFIER" \
  "$SC_C13/docs/product/master-flow-inventory.md" \
  "$SC_C13/docs/product/flows" \
  "$SC_C13/docs/product/journeys" \
  "9-startswith-digit"
if [ "$EXIT" -eq 2 ]; then
  pass "DOMAIN with leading digit rejected by schema → exit 2"
else
  fail "leading-digit: EXIT=$EXIT"
fi

# 4.14 — DOMAIN with underscore rejected (Q20 amendment 2 hyphen-only).
SC_C14="$(new_scratch)"
make_iter2_inventory "$SC_C14"
run_capture "$CLASSIFIER" \
  "$SC_C14/docs/product/master-flow-inventory.md" \
  "$SC_C14/docs/product/flows" \
  "$SC_C14/docs/product/journeys" \
  "asset_foundation"
if [ "$EXIT" -eq 2 ]; then
  pass "DOMAIN with underscore rejected (hyphen-only) → exit 2"
else
  fail "underscore-rejection: EXIT=$EXIT"
fi

# 4.15 — wrong arg count → exit 2 usage.
run_capture "$CLASSIFIER"
if [ "$EXIT" -eq 2 ]; then
  pass "no args → exit 2 (usage)"
else
  fail "no args: EXIT=$EXIT"
fi

# ──────────────────────────────────────────────────────────────────────
# Summary — machine-readable RESULT line for validate.sh
# ──────────────────────────────────────────────────────────────────────
printf '\nBC-10728 helper-script unit tests: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
