#!/usr/bin/env bash
# BC-12400 / BC-12534 (M3 option-cap) — intake disambiguation lint.
#
# Invariant: the intake front door (raise-a-ticket) and its tooling alias
# (report-issue) must NEVER instruct an AskUserQuestion whose option list is
# built one-per-candidate (per duplicate match, per active project, per team).
# AskUserQuestion caps at 4 options; a candidate set can be 6 dup matches or 46
# projects, so a per-candidate option list overflows the cap (the BC-12400 bug).
#
# The cap-proof contract: render candidates as a NUMBERED TEXT LIST in the prompt
# body, then a single free-text follow-up — "reply with the number, or none".
# That scales to any N and never builds an option-per-candidate prompt.
#
# This lint enforces three things:
#   NEGATIVE  — the per-candidate-option anti-pattern is absent from both files.
#   POSITIVE  — the numbered-list "reply with the number" + "or none" contract is
#               present at EVERY candidate-list site (count-based, per file).
#   SELF-TEST — the anti-pattern regex demonstrably DISCRIMINATES instruction
#               phrasings (must flag) from the reserved prohibition form (must
#               allow), so a future broadening can't silently rot.
#
# Hand-rolled assertion harness (no bats dep). Bash 3.2 compatible (macOS
# default). Auto-discovered by validate.sh Section 2e; emits RESULT pass=N.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CMD_DIR="$PLUGIN_ROOT/commands"
RAISE="$CMD_DIR/raise-a-ticket.md"
REPORT="$CMD_DIR/report-issue.md"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ── Anti-pattern regex ───────────────────────────────────────────────
# Matches an instruction to build a per-candidate AskUserQuestion option list,
# in either clause ordering:
#   forward:  <head-noun> … per|for each|for every … <candidate-noun>
#   reverse:  each|every <candidate-noun> … <head-noun>
# Head-nouns: option|button|choice|item. `[^a-zA-Z]` guards keep "per" from
# matching inside oPERator/proPERty and "each" from matching inside bEACH/rEACH.
#
# CONVENTION — 'entry' is the reserved PROHIBITION word. A substring lint can't
# tell "do X" from "do NOT X", so both commands phrase the prohibition canonically
# as "one entry per <noun>" (forward order, head-noun 'entry'), which this regex
# deliberately does NOT match. When you forbid the anti-pattern in prose, use ONLY
# that exact shape — never option/button/choice/item, and never reverse order — or
# the lint will (correctly) flag your prohibition as if it were an instruction.
NOUN='match|candidate|project|issue|result|team|dup|duplicate|row'
HEAD='option|button|choice|item'
ANTI_FWD="(${HEAD})s?.{0,30}[^a-zA-Z](per|for each|for every)[^a-zA-Z].{0,40}(${NOUN})"
ANTI_REV="[^a-zA-Z](each|every)[^a-zA-Z](${NOUN})s?.{0,40}(${HEAD})"
ANTI="(${ANTI_FWD})|(${ANTI_REV})"

# ── Assertions ───────────────────────────────────────────────────────
assert_no_anti() {
  local label="$1" file="$2"
  if grep -niE "$ANTI" "$file" >/dev/null 2>&1; then
    fail "$label: per-candidate AskUserQuestion option anti-pattern present"
    grep -niE "$ANTI" "$file" | sed 's/^/        /' >&2
  else
    pass "$label: no per-candidate option anti-pattern"
  fi
}

# Count-based positive: every candidate-list site that renders a pick must carry
# the contract phrase, so a regression at ONE site (e.g. the picker) can't hide
# behind another site's phrase. raise-a-ticket has 2 such sites (Step 6 dup-check
# + Step 1f operator picker); report-issue has 1 (Step 4 dup-check). The Step 1g
# multi-team site renders no pick (it auto-defaults to the modal team), so it is
# guarded by the NEGATIVE regex (which now includes the 'team' noun), not here.
assert_contract_count() {
  local label="$1" file="$2" min="$3" n
  # -c counts matching lines (one disambiguation site per line); avoid -o here
  # (combining -o with -c is non-portable across grep implementations).
  n=$(grep -ciE 'reply with the number' "$file" || true)
  if [ "$n" -ge "$min" ]; then
    pass "$label: numbered-list 'reply with the number' contract present (${n} >= ${min} sites)"
  else
    fail "$label: numbered-list contract at ${n} site(s), expected >= ${min} (a candidate-list site lost the contract)"
  fi
}

# Structural triad piece (per BC-10730 rubric-lock precedent): the free-text
# "or none" fallback must accompany the catchphrase, so a half-rewrite that keeps
# "reply with the number" but drops the escape hatch is still caught.
assert_contract_fallback() {
  local label="$1" file="$2"
  if grep -niE "or '?none'?" "$file" >/dev/null 2>&1; then
    pass "$label: free-text 'or none' fallback present"
  else
    fail "$label: missing 'or none' free-text fallback"
  fi
}

# Self-test: prove the regex discriminates. Each BAD string is a realistic
# re-introduced overflow (mapped to a real cap-sensitive site); each GOOD string
# is the reserved prohibition form. A future edit that loosens the regex enough to
# miss a BAD — or tightens it enough to flag a GOOD — fails here, in the lint.
assert_regex_flags() {
  local s="$1"
  if printf '%s\n' "$s" | grep -qiE "$ANTI"; then
    pass "regex flags overflow phrasing: \"$s\""
  else
    fail "regex MISSED overflow phrasing: \"$s\""
  fi
}
assert_regex_allows() {
  local s="$1"
  if printf '%s\n' "$s" | grep -qiE "$ANTI"; then
    fail "regex false-flagged reserved prohibition form: \"$s\""
  else
    pass "regex allows reserved prohibition form: \"$s\""
  fi
}

# ── Preconditions ────────────────────────────────────────────────────
for f in "$RAISE" "$REPORT"; do
  [ -f "$f" ] || { echo "fatal: missing $f" >&2; exit 2; }
done

# ── File-level invariant ─────────────────────────────────────────────
assert_no_anti          "raise-a-ticket" "$RAISE"
assert_no_anti          "report-issue"   "$REPORT"
assert_contract_count   "raise-a-ticket" "$RAISE" 2
assert_contract_count   "report-issue"   "$REPORT" 1
assert_contract_fallback "raise-a-ticket" "$RAISE"
assert_contract_fallback "report-issue"   "$REPORT"

# ── Regex self-test (mutation guard) ─────────────────────────────────
# BAD — must all be flagged (one per gap class the reviewers found):
assert_regex_flags "one option per team"                                   # noun gap (multi-team site)
assert_regex_flags "one option per project"                                # picker site
assert_regex_flags "an AskUserQuestion option for every match"             # quantifier gap
assert_regex_flags "render each candidate as its own AskUserQuestion option"  # reverse order
assert_regex_flags "one button per match"                                  # head-noun synonym
assert_regex_flags "one choice per duplicate"                              # synonym + noun
# GOOD — reserved prohibition form, must all be allowed:
assert_regex_allows "one entry per match"
assert_regex_allows "one entry per project"
assert_regex_allows "one entry per candidate"

# ── Result ───────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT pass=$PASS fail=0"
  exit 0
else
  echo "RESULT pass=$PASS fail=$FAIL"
  exit 1
fi
