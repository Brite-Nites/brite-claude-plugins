#!/usr/bin/env bash
# BC-12909 v-slice for the symmetric status-vs-code cross-check (C3 of the
# BC-12905 PRD; plugin 1.2.32). Locks the advisory contract in
# `commands/audit.md` § Status-vs-code advisory + the reframed convention in
# `agents/codebase-inferrer.md` § Conventions against the
# synthetic-status-vs-code-drift fixture (deflation / inflation / agreeing-clean
# / doc-only-skip).
#
# Scope: structural assertions on the four fixture shapes + literal-string checks
# on audit.md and codebase-inferrer.md. The cross-check is AGENT-BACKED (it
# dispatches the existing `codebase-inferrer`, an LLM agent whose output is not
# byte-deterministic) and ADVISORY (soft-warn, never a hard gate), so — exactly
# like run-built-criterion-fixture-vslice.sh (BC-10730) — this harness defends the
# prose contract + fixture shapes the prose cites, NOT a deterministic engine. The
# deterministic Phase-B oracle (build_audit_report.py / run-audit-smoke.sh /
# audit.golden.json) is intentionally UNTOUCHED by C3.
#
# Bash 3.2 compatible (macOS default). Stdlib only.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
FIXTURE="$FIXTURES_DIR/synthetic-status-vs-code-drift"

AUDIT_MD="$PLUGIN_ROOT/commands/audit.md"
INFERRER_MD="$PLUGIN_ROOT/agents/codebase-inferrer.md"

DEFL="$FIXTURE/deflation"
INFL="$FIXTURE/inflation"
AGREE="$FIXTURE/agreeing"
DOCONLY="$FIXTURE/doc-only"

DEFL_DOC="$DEFL/docs/product/flows/audit-acl/ACL-02.md"
INFL_DOC="$INFL/docs/product/flows/billing/BILL-01.md"
AGREE_DOC="$AGREE/docs/product/flows/team/TEAM-01.md"
DOCONLY_DOC="$DOCONLY/docs/product/flows/onboarding/ONB-01.md"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
# SKIP is part of the shared `RESULT pass=N fail=N skip=N` line contract that
# validate.sh + the sibling vslices emit. Every assertion here is a fixture-shape
# or prose grep that always runs, so nothing is skippable and skip stays 0 — kept
# for RESULT-line parity with the sibling harnesses, not dead scaffolding.
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Assert a path exists as a regular file.
assert_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label (missing: $path)"; fi
}

# Assert a path exists as a directory.
assert_dir() {
  local label="$1" path="$2"
  if [ -d "$path" ]; then pass "$label"; else fail "$label (missing dir: $path)"; fi
}

# Assert a path does NOT exist (file or directory).
assert_no_path() {
  local label="$1" path="$2"
  if [ -e "$path" ]; then fail "$label (unexpectedly present: $path)"; else pass "$label"; fi
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

# Assert `find <dir> -name <pattern>` matches zero files (no file whose name
# carries the pattern, e.g. a flow_id token in the deflation tree).
assert_no_find() {
  local label="$1" dir="$2" pattern="$3"
  local n
  n=$(find "$dir" -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ]; then pass "$label"; else fail "$label ($n file(s) match '$pattern' under $dir)"; fi
}

# ── Section 1: Fixture story-doc presence ───────────────────────────
section "1/7" "Fixture story-doc presence"

assert_file "deflation story doc present" "$DEFL_DOC"
assert_file "inflation story doc present" "$INFL_DOC"
assert_file "agreeing story doc present" "$AGREE_DOC"
assert_file "doc-only story doc present" "$DOCONLY_DOC"
assert_file "fixture README.md present" "$FIXTURE/README.md"

# ── Section 2: Deflation shape (doc NOT_STARTED, code present, UNMAPPED) ─
section "2/7" "Deflation shape — declared NOT_STARTED + built code (unmapped)"

assert_grep "deflation doc declares status: NOT_STARTED" \
  "status: NOT_STARTED" "$DEFL_DOC"
assert_file "deflation impl present under src/" \
  "$DEFL/src/audit/audit-log.ts"
assert_file "deflation test present under src/ (tips scan to BUILT)" \
  "$DEFL/src/audit/audit-log.test.ts"
# The costly shape: the code carries NO flow_id token, so a deterministic
# flow_id->path map finds nothing — only a semantic scan recovers the build.
assert_no_find "deflation code does NOT carry the flow_id token (unmapped-build shape)" \
  "$DEFL/src" "*ACL-02*"

# ── Section 3: Inflation shape (doc BUILT, code root present, no flow impl) ─
section "3/7" "Inflation shape — declared BUILT + code root but no flow impl"

assert_grep "inflation doc declares status: BUILT" \
  "status: BUILT" "$INFL_DOC"
assert_dir "inflation has a code root (src/ exists → NOT the doc-only skip)" \
  "$INFL/src"
assert_no_path "inflation has NO implementation for the flow (no src/billing/)" \
  "$INFL/src/billing"

# ── Section 4: Agreeing-clean shape (doc BUILT, code present) ────────
section "4/7" "Agreeing-clean shape — declared BUILT + built code (no warn)"

assert_grep "agreeing doc declares status: BUILT" \
  "status: BUILT" "$AGREE_DOC"
assert_file "agreeing impl present under src/" \
  "$AGREE/src/team/invite-teammate.tsx"
assert_file "agreeing test present under src/" \
  "$AGREE/src/team/invite-teammate.test.tsx"

# ── Section 5: Doc-only shape (no code root → repo-level skip) ───────
section "5/7" "Doc-only shape — no code root (repo-level skip precondition)"

assert_grep "doc-only doc declares status: BUILT" \
  "status: BUILT" "$DOCONLY_DOC"
assert_no_path "doc-only has NO src/ directory" "$DOCONLY/src"
assert_no_path "doc-only has NO app/ directory" "$DOCONLY/app"

# ── Section 6: audit.md encodes the advisory cross-check ─────────────
section "6/7" "audit.md § Status-vs-code advisory contract"

assert_grep "audit.md has the Status-vs-code advisory section" \
  "## Status-vs-code advisory" "$AUDIT_MD"
assert_grep "audit.md names the deflation direction" \
  "deflation" "$AUDIT_MD"
assert_grep "audit.md names the inflation direction" \
  "inflation" "$AUDIT_MD"
assert_grep "audit.md encodes the code-root skip precondition" \
  "no code tree to diff" "$AUDIT_MD"
# The --discipline skip is the one filter invariant a regression could silently
# drop (auto-invoked from /flow:plan-{discipline}), so lock its prose too.
assert_grep "audit.md skips the advisory entirely under --discipline" \
  "skipped entirely under" "$AUDIT_MD"
assert_grep "audit.md sets the advisory soft-warn altitude" \
  "advisory soft-warn" "$AUDIT_MD"
assert_grep "audit.md keeps the advisory outside the 37 hard gates" \
  "outside the 37" "$AUDIT_MD"
assert_grep "audit.md uses the status-vs-code-agreement json gate id" \
  "status-vs-code-agreement" "$AUDIT_MD"
assert_grep "audit.md reuses the codebase-inferrer engine (does not rebuild)" \
  "codebase-inferrer" "$AUDIT_MD"

# ── Section 7: codebase-inferrer.md convention reframed (US-14) ──────
section "7/7" "codebase-inferrer.md § Conventions reframe (US-14)"

assert_grep "inferrer convention reframed to a provisional scan bias" \
  "provisional scan bias" "$INFERRER_MD"
assert_grep "inferrer convention points to the audit cross-check for reconciliation" \
  "reconciled at the /flow:audit status-vs-code" "$INFERRER_MD"
assert_no_grep "inferrer no longer cites the phantom 'next manual gate'" \
  "next manual gate" "$INFERRER_MD"

# ── Summary ──────────────────────────────────────────────────────────
printf '\nBC-12909 v-slice summary: %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
printf 'RESULT pass=%d fail=%d skip=%d\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
