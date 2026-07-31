#!/usr/bin/env bash
# BC-12410 regression test for
# plugins/flow-architecture/scripts/check-clone-drift-shiftleft.sh
#
# The shift-left wrapper surfaces the clone re-sync obligation ON the PR that
# edits an upstream clone source, instead of on the next unrelated PR (which is
# all the lagging origin/main `clone-drift-check` (BC-7060) can do). It is a
# PATH-FILTERED gate that reuses the check-clone-drift.sh core via its
# CLONES_FILTER + UPSTREAM_REF env seams:
#
#   diff touches none of plugins/workflows/commands/{session-start,review,ship}.md
#       → not applicable, exit 0 (no run, no noise)
#   diff touches an upstream clone source AND the matching FDA clone is in sync
#       → clones in sync, exit 0
#   diff touches an upstream clone source AND the matching FDA clone is stale
#       → re-sync required + obligation recipe, exit 1 (advisory red in CI)
#   ...and an UNRELATED clone's drift never reds the editing PR (scoping).
#
# This harness exercises those behaviours hermetically. The changed-file set is
# injected via CHANGED_FILES (CI computes it from the PR diff); the stale-clone
# state is simulated by mutating a clone header's recorded Upstream-SHA in place
# (mirrors tests/test-clone-drift.sh), restored via .bak + an EXIT trap. Bash 3.2
# compatible (macOS default). No external deps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

WRAPPER="plugins/flow-architecture/scripts/check-clone-drift-shiftleft.sh"
CORE="plugins/flow-architecture/scripts/check-clone-drift.sh"
SS_CLONE="plugins/flow-architecture/commands/session-start.md"
SS_UPSTREAM="plugins/workflows/commands/session-start.md"
# Baselines re-synced in BC-12947 (Batch F added an eval-waiver marker — and, for
# ship, disable-model-invocation — to the workflows upstreams, so each clone's
# recorded Upstream-SHA was bumped to the new upstream blob in the same PR).
# review + ship re-synced again in BC-12113 (save-results put_page → the dedicated
# gbrain-team-write server propagated to both upstreams + clones).
SS_TARGET='Upstream-SHA: b0112f052f28fe15800fce4dcd54c57468cf1874'
REV_CLONE="plugins/flow-architecture/commands/review.md"
REV_UPSTREAM="plugins/workflows/commands/review.md"
REV_TARGET='Upstream-SHA: c4607b2cf4679f794a84cf2e1e0e004f2e4864a0'
SHIP_CLONE="plugins/flow-architecture/commands/ship.md"
SHIP_UPSTREAM="plugins/workflows/commands/ship.md"
SHIP_TARGET='Upstream-SHA: 97ed01907ab2fd31939b7c99823ebab7c6083733'
EMPTY_BLOB='e69de29bb2d1d6434b8b29ae775ad8c2e48c5391'
# Unique per-invocation output file (portable mktemp template — trailing X's,
# no suffix, works on both BSD/macOS and GNU/Linux). Avoids a fixed /tmp path
# two concurrent runs could clobber. Removed by the EXIT trap.
OUT="$(mktemp "${TMPDIR:-/tmp}/shiftleft-test.XXXXXX")"

passes=0
errors=0
pass_t() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; passes=$((passes + 1)); }
fail_t() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; errors=$((errors + 1)); }

# Always restore any clone file left mutated (covers a mid-run failure) and
# remove the temp output file.
cleanup() {
  [ -f "${SS_CLONE}.bak" ] && mv "${SS_CLONE}.bak" "${SS_CLONE}"
  [ -f "${REV_CLONE}.bak" ] && mv "${REV_CLONE}.bak" "${REV_CLONE}"
  [ -f "${SHIP_CLONE}.bak" ] && mv "${SHIP_CLONE}.bak" "${SHIP_CLONE}"
  [ -n "${OUT:-}" ] && rm -f "$OUT"
  return 0
}
trap cleanup EXIT

mutate_sha() { sed -i.bak "s|$2|Upstream-SHA: $EMPTY_BLOB|" "$1"; }   # $1=clone $2=target line
restore()    { mv "${1}.bak" "$1"; }

# Pre-flight: wrapper present, both clone baselines intact, and no stale .bak
# left from a previously-crashed run (which mutate_sha would otherwise clobber).
if [ ! -f "$WRAPPER" ]; then
  echo "fatal: $WRAPPER missing — wrapper not built yet"; exit 2
fi
for pair in "$SS_CLONE|$SS_TARGET" "$REV_CLONE|$REV_TARGET" "$SHIP_CLONE|$SHIP_TARGET"; do
  f="${pair%%|*}"; t="${pair#*|}"
  if ! grep -q "$t" "$f"; then
    echo "fatal: $f missing expected baseline SHA — refusing to mutate"; exit 2
  fi
  if [ -f "${f}.bak" ]; then
    echo "fatal: stale ${f}.bak from a prior crashed run — remove it before re-running"; exit 2
  fi
done

# Run the wrapper with an injected changed-file set, comparing against the
# worktree HEAD (so the recorded-SHA-vs-upstream-blob check is independent of
# whatever origin/main happens to be during this test's own CI).
run_wrapper() {
  set +e
  CHANGED_FILES="$1" HEAD_REF="HEAD" bash "$WRAPPER" >"$OUT" 2>&1
  EXIT=$?
  set -e
  echo "$EXIT"
}

printf "\n\033[1m=== BC-12410 shift-left clone-drift regression ===\033[0m\n"

# ── Assertion A: clone-list agreement across wrapper + core ───────────
# The 3 cloned-command names are encoded in the wrapper (UPSTREAM_CLONE_PATHS)
# AND the core (default CLONES). If a future 4th clone is added to one but not
# the other, the shift-left gate silently stops covering it (false green) — the
# exact silent-at-source failure this feature exists to prevent. Lock agreement.
core_set="$(grep -E '^\s*CLONES=\(' "$CORE" | grep -v 'CLONES_FILTER' \
  | sed -E 's/.*CLONES=\(([^)]*)\).*/\1/' | tr ' ' '\n' | sort -u | tr '\n' ' ')"
wrapper_set="$(grep -oE 'plugins/workflows/commands/[a-zA-Z0-9_-]+\.md' "$WRAPPER" \
  | sed -E 's|.*/([^/]+)\.md$|\1|' | sort -u | tr '\n' ' ')"
if [ -n "$core_set" ] && [ "$core_set" = "$wrapper_set" ]; then
  pass_t "Assertion A (clone-list agreement) → core{${core_set}} == wrapper{${wrapper_set}}"
else
  fail_t "Assertion A: clone lists disagree — core{${core_set}} vs wrapper{${wrapper_set}}"
fi

# ── Case 1: upstream edited, clone NOT re-synced → FAIL + obligation ───
# Simulate "upstream moved, clone still records the old SHA" by pointing the
# clone's recorded Upstream-SHA at a blob that differs from HEAD's upstream.
# Use a MULTI-FILE changed set (clone source mid-list) — the CI shape.
mutate_sha "$SS_CLONE" "$SS_TARGET"
EXIT=$(run_wrapper "$(printf 'README.md\n%s\nplugins/marketing/x.md' "$SS_UPSTREAM")")
if [ "$EXIT" -eq 1 ] \
  && grep -q "clone re-sync required" "$OUT" \
  && grep -q "Bump that clone header" "$OUT" \
  && ! grep -q "not applicable" "$OUT"; then
  pass_t "Case 1 (upstream-edited, not re-synced; clone mid-list) → exit 1 + obligation recipe"
else
  fail_t "Case 1 expected exit=1 + 're-sync required' + recipe; got exit=$EXIT"
  cat "$OUT"
fi
restore "$SS_CLONE"

# ── Case 2: upstream edited AND clone re-synced (baseline in-sync) → PASS ─
# Self-contained: re-assert the baseline was restored, so a future reorder or a
# dropped Case 1 restore fails HERE with a clear message rather than as a
# confusing "Case 2" failure (no hidden dependency on Case 1's teardown).
if ! grep -q "$SS_TARGET" "$SS_CLONE"; then
  fail_t "Case 2 precondition: $SS_CLONE not at baseline SHA (Case 1 restore failed?)"
else
  EXIT=$(run_wrapper "$SS_UPSTREAM")
  if [ "$EXIT" -eq 0 ] \
    && grep -q "clones in sync" "$OUT" \
    && ! grep -q "clone re-sync required" "$OUT"; then
    pass_t "Case 2 (upstream-edited, re-synced) → exit 0 + clones in sync"
  else
    fail_t "Case 2 expected exit=0 + 'clones in sync'; got exit=$EXIT"
    cat "$OUT"
  fi
fi

# ── Case 3: unrelated PR (no upstream clone source in diff) → no-run/PASS ─
EXIT=$(run_wrapper "plugins/marketing/skills/example/SKILL.md")
if [ "$EXIT" -eq 0 ] \
  && grep -q "not applicable" "$OUT" \
  && ! grep -q "clone re-sync required" "$OUT"; then
  pass_t "Case 3 (unrelated PR) → exit 0 + not applicable (path-filter targets)"
else
  fail_t "Case 3 expected exit=0 + 'not applicable'; got exit=$EXIT"
  cat "$OUT"
fi

# ── Case 4: FDA-clone-only edit (no upstream change) → no-run/PASS ──────
# Editing the FDA clone is sanctioned divergence (Q50/Q53) — it must NOT red.
EXIT=$(run_wrapper "plugins/flow-architecture/commands/ship.md")
if [ "$EXIT" -eq 0 ] \
  && grep -q "not applicable" "$OUT" \
  && ! grep -q "clone re-sync required" "$OUT"; then
  pass_t "Case 4 (FDA-clone-only edit) → exit 0 + not applicable (scope respected)"
else
  fail_t "Case 4 expected exit=0 + 'not applicable'; got exit=$EXIT"
  cat "$OUT"
fi

# ── Case 5: near-miss path must NOT match (grep -Fxq exactness) ────────
# `…/session-start.md.bak` is a superstring of an upstream clone path; a
# substring/prefix filter would false-positive. Locks the fixed-string,
# whole-line match so the gate stays targeted.
EXIT=$(run_wrapper "${SS_UPSTREAM}.bak")
if [ "$EXIT" -eq 0 ] \
  && grep -q "not applicable" "$OUT" \
  && ! grep -q "clone re-sync required" "$OUT"; then
  pass_t "Case 5 (near-miss '${SS_UPSTREAM}.bak') → exit 0 + not applicable (exact-match)"
else
  fail_t "Case 5 expected exit=0 + 'not applicable' (no false match); got exit=$EXIT"
  cat "$OUT"
fi

# ── Case 6: a DIFFERENT clone arm (review), in sync → PASS ─────────────
# Exercises the review entry of the 3-element loop (Cases 1-2 only drive
# session-start) and the multi-element CLONES_FILTER scoping path.
EXIT=$(run_wrapper "$REV_UPSTREAM")
if [ "$EXIT" -eq 0 ] \
  && grep -q "clones in sync" "$OUT" \
  && ! grep -q "clone re-sync required" "$OUT"; then
  pass_t "Case 6 (review arm, in sync) → exit 0 + clones in sync"
else
  fail_t "Case 6 expected exit=0 + 'clones in sync'; got exit=$EXIT"
  cat "$OUT"
fi

# ── Case 7: cross-clone scoping — unrelated stale clone must NOT red ───
# THE regression lock for the scope fix: review clone is stale, but the PR edits
# only session-start (in sync). The shift-left gate must report in-sync — the
# stale review clone is the lagging clone-drift-check backstop's concern, not
# this PR's. (Before the CLONES_FILTER scoping, the core checked all three and
# this reded the PR, blaming a clone it never touched.)
mutate_sha "$REV_CLONE" "$REV_TARGET"
EXIT=$(run_wrapper "$SS_UPSTREAM")
if [ "$EXIT" -eq 0 ] \
  && grep -q "clones in sync" "$OUT" \
  && ! grep -q "clone re-sync required" "$OUT"; then
  pass_t "Case 7 (edit session-start; review independently stale) → exit 0 (unrelated drift not blamed)"
else
  fail_t "Case 7 expected exit=0 + 'clones in sync' (scoping); got exit=$EXIT"
  cat "$OUT"
fi
restore "$REV_CLONE"

# ── Case 8: ship arm stale-clone → FAIL + obligation ──────────────────
# Cases 1/7 mutate session-start/review; this exercises the third (ship) arm's
# "upstream edited, clone not re-synced → exit 1" path so a future break of the
# ship path in check-clone-drift.sh can't pass all assertions undetected.
mutate_sha "$SHIP_CLONE" "$SHIP_TARGET"
EXIT=$(run_wrapper "$SHIP_UPSTREAM")
if [ "$EXIT" -eq 1 ] \
  && grep -q "clone re-sync required" "$OUT" \
  && grep -q "Bump that clone header" "$OUT" \
  && ! grep -q "not applicable" "$OUT"; then
  pass_t "Case 8 (ship arm, upstream-edited not re-synced) → exit 1 + obligation recipe"
else
  fail_t "Case 8 expected exit=1 + 're-sync required' + recipe; got exit=$EXIT"
  cat "$OUT"
fi
restore "$SHIP_CLONE"

# ── Final state: all three clone files restored, baseline clean ───────
if grep -q "$SS_TARGET" "$SS_CLONE" && grep -q "$REV_TARGET" "$REV_CLONE" \
  && grep -q "$SHIP_TARGET" "$SHIP_CLONE"; then
  pass_t "Post-test baseline restored (session-start + review + ship)"
else
  fail_t "Post-test baseline NOT restored — a clone is still mutated"
fi

printf "\n\033[1msummary:\033[0m errors=%d\n" "$errors"
printf "RESULT pass=%d fail=%d\n" "$passes" "$errors"
if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
