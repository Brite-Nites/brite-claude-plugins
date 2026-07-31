#!/usr/bin/env bash
# BC-7060 regression test for plugins/flow-architecture/scripts/check-clone-drift.sh
#
# Exercises the three classifier paths:
#   1. Match     — recorded SHA equals current origin/main SHA  → exit 0, pass=3
#   2. Trivial   — recorded SHA points to a synthetic blob that differs only
#                  in whitespace (≤5 lines, whitespace-only)    → exit 0, warn=1
#   3. Substantive — recorded SHA points to the empty blob       → exit 1, fail=1
#
# Mutates clone headers in-place, restores from .bak files via trap on exit.
# Bash 3.2 compatible (macOS default). No PyYAML / no external deps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

DRIFT="plugins/flow-architecture/scripts/check-clone-drift.sh"
CLONE_FILE="plugins/flow-architecture/commands/session-start.md"
# Baseline re-synced in BC-12947 (Batch F added an eval-waiver marker to the
# workflows session-start upstream, so the clone's recorded Upstream-SHA was
# bumped to the new upstream blob in the same PR).
TARGET_LINE='Upstream-SHA: 5c2b9e561cdd5c41220df3ac4d8847cc7c09f324'
EMPTY_BLOB='e69de29bb2d1d6434b8b29ae775ad8c2e48c5391'

# Drive the classifier from the branch's HEAD blob, not origin/main. The test
# fixture exercises the classifier paths using the WORKING-TREE / HEAD state of
# the upstream file as the baseline so this regression test passes even on PRs
# that legitimately modify the cloned source (BC-11891 was the trigger — both
# the workflows session-start.md AND its FDA clone changed in tandem; origin/
# main was therefore stale during this PR's CI). The production drift check
# (clone-drift-check CI job) still defaults to origin/main per check-clone-
# drift.sh — only this regression test overrides.
export UPSTREAM_REF="HEAD"

errors=0
pass_t() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail_t() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; errors=$((errors + 1)); }

# Always restore the clone file from .bak if a test left it mutated.
cleanup() {
  if [ -f "${CLONE_FILE}.bak" ]; then
    mv "${CLONE_FILE}.bak" "${CLONE_FILE}"
  fi
}
trap cleanup EXIT

# Pre-flight: refuse to run if the target clone file is dirty (would lose work).
if ! grep -q "$TARGET_LINE" "$CLONE_FILE"; then
  echo "fatal: $CLONE_FILE missing expected baseline SHA — refusing to mutate"
  exit 2
fi

run_drift() {
  set +e
  bash "$DRIFT" >/tmp/clone-drift-test.out 2>&1
  EXIT=$?
  set -e
  echo "$EXIT"
}

printf "\n\033[1m=== BC-7060 clone-drift classifier regression ===\033[0m\n"

# ── Path 1: match (baseline state) ────────────────────────────────────
EXIT=$(run_drift)
if [ "$EXIT" -eq 0 ] && grep -q "pass=3 warn=0 fail=0" /tmp/clone-drift-test.out; then
  pass_t "Path 1 (match) → exit 0, pass=3"
else
  fail_t "Path 1 expected exit=0 + pass=3; got exit=$EXIT"
  cat /tmp/clone-drift-test.out
fi

# ── Path 2: trivial whitespace drift ──────────────────────────────────
# Pull from HEAD (matches the classifier's UPSTREAM_REF=HEAD override above)
# so the synthetic WS blob differs from the recorded baseline by ONLY the
# whitespace tweak — independent of working-tree edits relative to origin/main.
git show "HEAD:plugins/workflows/commands/session-start.md" > /tmp/clone-drift-ws.md
printf ' \n' >> /tmp/clone-drift-ws.md
WS_BLOB="$(git hash-object -w /tmp/clone-drift-ws.md)"
sed -i.bak "s|$TARGET_LINE|Upstream-SHA: $WS_BLOB|" "$CLONE_FILE"
EXIT=$(run_drift)
if [ "$EXIT" -eq 0 ] && grep -q "warn=1" /tmp/clone-drift-test.out && grep -q "trivial drift" /tmp/clone-drift-test.out; then
  pass_t "Path 2 (trivial-whitespace) → exit 0, warn=1"
else
  fail_t "Path 2 expected exit=0 + warn=1 + trivial-drift line; got exit=$EXIT"
  cat /tmp/clone-drift-test.out
fi
mv "${CLONE_FILE}.bak" "$CLONE_FILE"

# ── Path 3: substantive drift (empty blob baseline) ───────────────────
sed -i.bak "s|$TARGET_LINE|Upstream-SHA: $EMPTY_BLOB|" "$CLONE_FILE"
EXIT=$(run_drift)
if [ "$EXIT" -eq 1 ] && grep -q "fail=1" /tmp/clone-drift-test.out && grep -q "substantive drift" /tmp/clone-drift-test.out; then
  pass_t "Path 3 (substantive) → exit 1, fail=1"
else
  fail_t "Path 3 expected exit=1 + fail=1 + substantive-drift line; got exit=$EXIT"
  cat /tmp/clone-drift-test.out
fi
mv "${CLONE_FILE}.bak" "$CLONE_FILE"

# ── Final state: clone file restored, baseline clean ──────────────────
EXIT=$(run_drift)
if [ "$EXIT" -eq 0 ]; then
  pass_t "Post-test baseline restored"
else
  fail_t "Post-test baseline NOT restored — exit=$EXIT"
fi

printf "\n\033[1msummary:\033[0m errors=%d\n" "$errors"
if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
