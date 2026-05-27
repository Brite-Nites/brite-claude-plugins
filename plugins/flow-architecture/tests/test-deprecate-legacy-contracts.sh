#!/usr/bin/env bash
# BC-10219 contract tests for /flow:deprecate-legacy orchestrator.
# Locks: two-pass detection logic, pre-comms gate enforcement,
# per-milestone sub-step ordering, AskUserQuestion gate presence,
# review doc schema (required columns in the disposition table).
#
# Scope: structural assertions on the command markdown + cross-reference
# skill SKILL.md. No Linear MCP calls; no LLM invocation. These tests
# defend the command's contract as expressed in its prose.
#
# Bash 3.2 compatible (macOS default). Stdlib python3 only.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CMD="$PLUGIN_ROOT/commands/deprecate-legacy.md"
XREF_SKILL="$PLUGIN_ROOT/skills/flow-legacy-cross-reference/SKILL.md"
INTERVIEW="$PLUGIN_ROOT/docs/design-rationale/fda-plugin-interview.md"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

assert_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then
    pass "$label"
  else
    fail "$label (needle '$needle' not found in $path)"
  fi
}

assert_no_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then
    fail "$label (unexpected match for '$needle' in $path)"
  else
    pass "$label"
  fi
}

assert_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label (missing: $path)"; fi
}

# ══════════════════════════════════════════════════════════════════════
section "1/7" "File presence"

assert_file "deprecate-legacy.md exists" "$CMD"
assert_file "flow-legacy-cross-reference SKILL.md exists" "$XREF_SKILL"
assert_file "fda-plugin-interview.md exists" "$INTERVIEW"

# ══════════════════════════════════════════════════════════════════════
section "2/7" "Two-pass detection logic"

# The command must document both passes with filesystem-derived detection.
assert_grep "Pass 1 generate mode documented" \
  "Pass 1 — generate" "$CMD"
assert_grep "Pass 2 execute mode documented" \
  "Pass 2 — execute" "$CMD"
assert_grep "last_reviewed: TBD blocker for Pass 1" \
  "last_reviewed: TBD" "$CMD"
assert_grep "filesystem-derived pass detection (review doc ABSENT)" \
  "ABSENT" "$CMD"
assert_grep "filesystem-derived pass detection (review doc PRESENT)" \
  "PRESENT" "$CMD"
assert_grep "last_reviewed != TBD triggers execute" \
  "last_reviewed: <ISO-8601>" "$CMD"
assert_grep "project-slug in review doc path" \
  "<project-slug>-deprecate-legacy.md" "$CMD"

# ══════════════════════════════════════════════════════════════════════
section "3/7" "Pre-comms gate enforcement"

assert_grep "Pre-comms 24h gate documented" \
  "Pre-comms posted at" "$CMD"
assert_grep "24h cooling period enforcement" \
  "24h cooling period" "$CMD"
assert_grep "Pre-comms gate halt on absent marker" \
  "Pre-comms marker not found" "$CMD"
assert_grep "Pre-comms gate halt on <24h" \
  "24h cooling period" "$CMD"
assert_grep "ISO-8601 timestamp delta check" \
  "≥24" "$CMD"
assert_grep "disposition completeness gate blocks scoping-needed" \
  "scoping-needed' disposition" "$CMD"

# ══════════════════════════════════════════════════════════════════════
section "4/7" "Per-milestone sub-step ordering"

# Extract line numbers for the 4 sub-steps to verify ordering.
LINE_REHOME=$(grep -n "Sub-step a: Re-home" "$CMD" | head -1 | cut -d: -f1 || true)
LINE_CLOSE=$(grep -n "Sub-step b: Close-as-obsolete" "$CMD" | head -1 | cut -d: -f1 || true)
LINE_ANNOTATE=$(grep -n "Sub-step c: Annotate" "$CMD" | head -1 | cut -d: -f1 || true)
LINE_ARCHIVE=$(grep -n "Sub-step d: Archive" "$CMD" | head -1 | cut -d: -f1 || true)

if [ -n "$LINE_REHOME" ] && [ -n "$LINE_CLOSE" ] && [ -n "$LINE_ANNOTATE" ] && [ -n "$LINE_ARCHIVE" ]; then
  pass "all 4 sub-steps present"
else
  fail "missing sub-step headers (re-home=$LINE_REHOME close=$LINE_CLOSE annotate=$LINE_ANNOTATE archive=$LINE_ARCHIVE)"
fi

if [ -n "$LINE_REHOME" ] && [ -n "$LINE_CLOSE" ] && [ "$LINE_REHOME" -lt "$LINE_CLOSE" ]; then
  pass "re-home before close-as-obsolete"
else
  fail "re-home must come before close-as-obsolete"
fi

if [ -n "$LINE_CLOSE" ] && [ -n "$LINE_ANNOTATE" ] && [ "$LINE_CLOSE" -lt "$LINE_ANNOTATE" ]; then
  pass "close-as-obsolete before annotate"
else
  fail "close-as-obsolete must come before annotate"
fi

if [ -n "$LINE_ANNOTATE" ] && [ -n "$LINE_ARCHIVE" ] && [ "$LINE_ANNOTATE" -lt "$LINE_ARCHIVE" ]; then
  pass "annotate before archive-handoff"
else
  fail "annotate must come before archive-handoff"
fi

# Ordering rationale documented
assert_grep "ordering rationale (issues before annotation)" \
  "issues must be re-homed/closed BEFORE annotation" "$CMD"

# ══════════════════════════════════════════════════════════════════════
section "5/7" "AskUserQuestion gate presence"

assert_grep "batch confirmation gate at milestone boundary" \
  "Batch confirmation gate" "$CMD"
assert_grep "AskUserQuestion in batch gate" \
  "AskUserQuestion" "$CMD"
assert_grep "execute this milestone option" \
  "Execute this milestone" "$CMD"
assert_grep "skip this milestone option" \
  "Skip this milestone" "$CMD"
assert_grep "pause + resume later option" \
  "Pause + resume later" "$CMD"
assert_grep "cancel remaining option" \
  "Cancel remaining" "$CMD"
assert_grep "archive hand-off AskUserQuestion" \
  "Have you archived the milestone" "$CMD"

# ══════════════════════════════════════════════════════════════════════
section "6/7" "Review doc schema"

# Required disposition table columns
assert_grep "column: Legacy Milestone" \
  "Legacy Milestone" "$CMD"
assert_grep "column: Mapped FDA Domain(s)" \
  "Mapped FDA Domain(s)" "$CMD"
assert_grep "column: Open Issues" \
  "Open Issues" "$CMD"
assert_grep "column: Closed Issues" \
  "Closed Issues" "$CMD"
assert_grep "column: Proposed Disposition" \
  "Proposed Disposition" "$CMD"
assert_grep "column: Source Signal" \
  "Source Signal" "$CMD"

# Valid disposition values
assert_grep "disposition: re-home" \
  "re-home" "$CMD"
assert_grep "disposition: close-as-obsolete" \
  "close-as-obsolete" "$CMD"
assert_grep "disposition: scoping-needed" \
  "scoping-needed" "$CMD"

# Progress markers
assert_grep "progress marker: DONE" \
  "[DONE]" "$CMD"
assert_grep "progress marker: SKIPPED" \
  "[SKIPPED]" "$CMD"
assert_grep "progress marker: ERROR" \
  "[ERROR:" "$CMD"
assert_grep "progress marker: PENDING" \
  "[PENDING]" "$CMD"

# Front-matter fields
assert_grep "frontmatter: generated_by" \
  "generated_by:" "$CMD"
assert_grep "frontmatter: generated_at" \
  "generated_at:" "$CMD"
assert_grep "frontmatter: last_reviewed" \
  "last_reviewed:" "$CMD"

# ══════════════════════════════════════════════════════════════════════
section "7/7" "Cross-reference skill + Q59 lock integration"

# flow-legacy-cross-reference is now user-invocable
assert_grep "xref skill user-invocable" \
  "user-invocable: true" "$XREF_SKILL"
assert_no_grep "xref skill NOT disable-model-invocation" \
  "disable-model-invocation: true" "$XREF_SKILL"

# Q59 lock exists in the interview
assert_grep "Q59 lock present in design rationale" \
  "Q59" "$INTERVIEW"
assert_grep "Q59 references BC-10219" \
  "BC-10219" "$INTERVIEW"
assert_grep "Q59 documents two-pass model" \
  "Two-pass execution model" "$INTERVIEW"
assert_grep "Q59 documents pre-comms gate" \
  "Pre-comms 24h gate" "$INTERVIEW"
assert_grep "Q59 documents Q9 scope widening" \
  "Q9 scope widening" "$INTERVIEW"
assert_grep "Q59 documents cadence NOT extended" \
  "Cadence linear-housekeeping NOT extended" "$INTERVIEW"
assert_grep "Q59 documents cross-reference reuse decision" \
  "flow-legacy-cross-reference" "$INTERVIEW"

# Deprecate-legacy references Q59
assert_grep "command references Q59 lock" \
  "Q59" "$CMD"

# Marker discipline preserved
assert_grep "Q14 marker pair in command" \
  "<!-- FDA-MIGRATION-START -->" "$CMD"
assert_grep "Q14 end marker in command" \
  "<!-- FDA-MIGRATION-END -->" "$CMD"
assert_grep "literal-string-search discipline" \
  "literal-string-search" "$CMD"

# ══════════════════════════════════════════════════════════════════════
printf '\n══════════════════════════════════════════════════════════════\n'
printf 'Results: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'FAILED — %d contract(s) broken.\n' "$FAIL"
  exit 1
fi
printf 'ALL CONTRACTS HOLD.\n'
exit 0
