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

assert_empty() {
  # $1 desc, $2 actual output — passes only when output is empty
  local desc="$1" got="$2"
  if [ -z "$got" ]; then
    pass=$((pass + 1)); printf "  PASS  %s\n" "$desc"
  else
    fail=$((fail + 1)); printf "  FAIL  %s\n        expected no output, got: %s\n" "$desc" "$got"
  fi
}

assert_not_contains() {
  # $1 desc, $2 substring that must be ABSENT, $3 actual output
  local desc="$1" unwanted="$2" got="$3"
  if printf '%s' "$got" | grep -qF "$unwanted"; then
    fail=$((fail + 1)); printf "  FAIL  %s\n        unexpected substring present: %s\n        got: %s\n" "$desc" "$unwanted" "$got"
  else
    pass=$((pass + 1)); printf "  PASS  %s\n" "$desc"
  fi
}

# Precondition: the function must be defined. A missing/un-sourced lib must HARD-FAIL the suite
# rather than let the "stays silent" scenarios pass vacuously against a do-nothing function.
if type detect_agent_skills_drift >/dev/null 2>&1; then
  pass=$((pass + 1)); printf "  PASS  detect_agent_skills_drift is defined\n"
else
  fail=$((fail + 1)); printf "  FAIL  detect_agent_skills_drift is not defined (lib failed to source)\n"
fi

# ── Scenario 1: orphaned config — docs/agents/*.md present, no '## Agent skills' block ──
d="$tmproot/orphaned"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\nNothing wired here.\n' > "$d/CLAUDE.md"
printf 'tracker\n' > "$d/docs/agents/issue-tracker.md"
assert_contains "orphaned config (docs present, no block) warns" \
  'no `## Agent skills` block' "$(run_detect "$d")"

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
# Anchored to the full message form: a present file counts as "named" only if it is actually
# flagged as missing — avoids the substring collision a bare 'issue-tracker.md' grep would have
# (e.g. a missing 'old-issue-tracker.md' would false-trip an unanchored check).
assert_not_contains "partial set does not flag a present file as missing" \
  'references missing file: docs/agents/issue-tracker.md' "$out"

# ── Scenario 7: docs/agents dir absent entirely + block references a file → rotted fires ──
# The most likely real-world drift state (someone deletes docs/agents but leaves the block).
d="$tmproot/dir_absent"; mkdir -p "$d"   # note: no docs/agents created
printf '# CLAUDE.md\n\n## Agent skills\n\nSee docs/agents/domain.md.\n' > "$d/CLAUDE.md"
assert_contains "block references file but docs/agents dir is absent → rotted warns" \
  'references missing file: docs/agents/domain.md' "$(run_detect "$d")"

# ── Scenario 8: block present, zero references in it, docs present → silent (intended) ──
# Pins the contract: a heading that lists no files is NOT "orphaned" — only missing refs warn.
d="$tmproot/block_no_refs"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## Agent skills\n\nConfigured for this repo.\n\n## Gotchas\n\nstuff\n' > "$d/CLAUDE.md"
printf 'x\n' > "$d/docs/agents/issue-tracker.md"
assert_empty "block present with zero references stays silent" "$(run_detect "$d")"

# ── Scenario 9: CRLF line endings — rotted pointer still detected ──
# Pins that POSIX [[:space:]] absorbs the trailing \r in the heading and grep stops before \r.
d="$tmproot/crlf"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\r\n\r\n## Agent skills\r\n\r\nSee docs/agents/domain.md.\r\n' > "$d/CLAUDE.md"
printf 'tracker\n' > "$d/docs/agents/issue-tracker.md"   # domain.md missing
assert_contains "CRLF file: rotted pointer still detected" \
  'references missing file: docs/agents/domain.md' "$(run_detect "$d")"

# ── Scenario 10: heading is case-sensitive — lowercase '## agent skills' is not the block ──
# docs present + a non-matching heading → treated as orphaned (no recognized block).
d="$tmproot/lowercase"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## agent skills\n\nSee docs/agents/issue-tracker.md.\n' > "$d/CLAUDE.md"
printf 'tracker\n' > "$d/docs/agents/issue-tracker.md"
assert_contains "lowercase heading is not recognized as the block (orphaned warns)" \
  'no `## Agent skills` block' "$(run_detect "$d")"

# ── Scenario 11: nested-path ref is validated by BASENAME only (documented limitation) ──
# A ref to docs/agents/sub/foo.md is satisfied by a top-level docs/agents/foo.md, because
# docs/agents/ is flat by convention. Locks this behavior so a future change to full-path
# resolution trips the suite intentionally.
d="$tmproot/nested"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## Agent skills\n\nSee docs/agents/sub/foo.md.\n' > "$d/CLAUDE.md"
printf 'x\n' > "$d/docs/agents/foo.md"   # top-level basename match → treated as present
assert_empty "nested ref satisfied by basename match stays silent (flat-dir convention)" "$(run_detect "$d")"

# ── Scenario 12: duplicate '## Agent skills' blocks → every block is scanned ──
# A malformed CLAUDE.md with two blocks: the awk flag re-arms on the second heading, so refs
# in BOTH are checked. Locks current behavior (no "first block wins") against a future awk rewrite.
d="$tmproot/dup_heading"; mkdir -p "$d/docs/agents"
printf '# CLAUDE.md\n\n## Agent skills\n\nSee docs/agents/alpha.md.\n\n## Gotchas\n\nstuff\n\n## Agent skills\n\nSee docs/agents/beta.md.\n' > "$d/CLAUDE.md"
out="$(run_detect "$d")"   # neither alpha.md nor beta.md exists → both flagged
assert_contains "duplicate blocks: first block's missing ref flagged" \
  'references missing file: docs/agents/alpha.md' "$out"
assert_contains "duplicate blocks: second block's missing ref flagged" \
  'references missing file: docs/agents/beta.md' "$out"

echo "RESULT pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
