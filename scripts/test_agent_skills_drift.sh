#!/usr/bin/env bash
# TDD harness for detect_agent_skills_drift (scripts/_lib/agent_skills_drift.sh).
#
# Builds throwaway fixture repos under a mktemp dir and asserts the drift-detect
# function's line output. Behavior-focused: we assert on the messages the function
# emits through its public interface (CLAUDE.md path + docs/agents dir → messages),
# never on its internals.
#
# Usage: bash scripts/test_agent_skills_drift.sh
set -u  # do NOT set -e — assertions inspect output, not exit status

HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/_lib/agent_skills_drift.sh"
# shellcheck source=/dev/null
. "$LIB" 2>/dev/null || true   # if the lib is missing, the function is undefined → scenarios FAIL (RED)

pass=0
fail=0
tmproot="$(mktemp -d -t agentdrift.XXXXXX)" || { echo "FATAL: mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$tmproot"' EXIT

# run_detect <fixture-dir> → echoes the function's output ("" if the lib isn't loaded yet)
run_detect() {
  local dir="$1"
  if type detect_agent_skills_drift >/dev/null 2>&1; then
    detect_agent_skills_drift "$dir/CLAUDE.md" "$dir/docs/agents"
  fi
}

assert_contains() {
  # $1 desc, $2 expected substring, $3 actual output
  local desc="$1" want="$2" got="$3"
  if printf '%s' "$got" | grep -qF "$want"; then
    pass=$((pass + 1)); printf "  PASS  %s\n" "$desc"
  else
    fail=$((fail + 1)); printf "  FAIL  %s\n        expected substring: %s\n        got: %s\n" "$desc" "$want" "${got:-<empty>}"
  fi
}

# ── Scenario 1: orphaned config — docs/agents/*.md present, no '## Agent skills' block ──
d="$tmproot/orphaned"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\nNothing wired here.\n' > "$d/CLAUDE.md"
printf 'tracker\n' > "$d/docs/agents/issue-tracker.md"
assert_contains "orphaned config (docs present, no block) warns" \
  'no `## Agent skills` block' "$(run_detect "$d")"

assert_empty() {
  # $1 desc, $2 actual output — passes only when output is empty
  local desc="$1" got="$2"
  if [ -z "$got" ]; then
    pass=$((pass + 1)); printf "  PASS  %s\n" "$desc"
  else
    fail=$((fail + 1)); printf "  FAIL  %s\n        expected no output, got: %s\n" "$desc" "$got"
  fi
}

# ── Scenario 2: un-set-up repo — no block AND no docs/agents → no warning ──
d="$tmproot/unset"; mkdir -p "$d"
printf '# CLAUDE.md\n\nPlain repo.\n' > "$d/CLAUDE.md"
assert_empty "un-set-up repo (no block, no docs) stays silent" "$(run_detect "$d")"

# ── Scenario 3: in-sync — block present AND docs present → no orphaned warning ──
d="$tmproot/insync"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## Agent skills\n\nSee docs/agents/issue-tracker.md.\n' > "$d/CLAUDE.md"
printf 'tracker\n' > "$d/docs/agents/issue-tracker.md"
assert_empty "in-sync repo (block + docs) stays silent" "$(run_detect "$d")"

# ── Scenario 4: rotted pointer — block references a docs/agents file that's missing ──
d="$tmproot/rotted"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## Agent skills\n\nSee docs/agents/issue-tracker.md and docs/agents/domain.md.\n' > "$d/CLAUDE.md"
printf 'tracker\n' > "$d/docs/agents/issue-tracker.md"   # domain.md intentionally NOT created
assert_contains "rotted pointer (block references missing file) warns" \
  'references missing file: docs/agents/domain.md' "$(run_detect "$d")"

# ── Scenario 5: in-sync with references — all referenced files exist → silent ──
# Also verifies a following H2 ('## Gotchas') closes the block (its content isn't scanned).
d="$tmproot/insync_refs"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## Agent skills\n\nSee docs/agents/issue-tracker.md, docs/agents/triage-labels.md, docs/agents/domain.md.\n\n## Gotchas\n\nunrelated docs/agents/ghost.md mention here.\n' > "$d/CLAUDE.md"
printf 'x\n' > "$d/docs/agents/issue-tracker.md"
printf 'x\n' > "$d/docs/agents/triage-labels.md"
printf 'x\n' > "$d/docs/agents/domain.md"
assert_empty "in-sync with all referenced files present stays silent" "$(run_detect "$d")"

# ── Scenario 6: partial set — 3 referenced, 1 missing → names only the missing one ──
d="$tmproot/partial"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## Agent skills\n\nSee docs/agents/issue-tracker.md, docs/agents/triage-labels.md, docs/agents/domain.md.\n' > "$d/CLAUDE.md"
printf 'x\n' > "$d/docs/agents/issue-tracker.md"
printf 'x\n' > "$d/docs/agents/domain.md"   # triage-labels.md missing
out="$(run_detect "$d")"
assert_contains "partial set names the missing file" 'references missing file: docs/agents/triage-labels.md' "$out"
if printf '%s' "$out" | grep -qF 'issue-tracker.md'; then
  fail=$((fail + 1)); printf "  FAIL  partial set must not name present files (named issue-tracker.md)\n"
else
  pass=$((pass + 1)); printf "  PASS  partial set does not name present files\n"
fi

echo "RESULT pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
