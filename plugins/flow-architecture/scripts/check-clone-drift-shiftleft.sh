#!/usr/bin/env bash
set -euo pipefail

# ── FDA Shift-Left Clone-Drift (BC-12410) ─────────────────────────────
# Surfaces the clone re-sync obligation ON the PR that edits an upstream clone
# source — instead of (lagging, silent-at-source) on the next, unrelated PR,
# which is all the origin/main `clone-drift-check` (BC-7060) can do.
#
# This is a thin PATH-FILTERED gate over the check-clone-drift.sh core, reusing
# it via two additive, default-preserving env seams (UPSTREAM_REF + CLONES_FILTER)
# rather than forking its drift-classification logic — so the existing
# clone-drift-check behaviour is unchanged (BC-7060 no-regression / AC#3):
#
#   1. Compute the PR's changed-file set (CHANGED_FILES env, else `git diff`).
#   2. Intersect it with the three cloned upstream commands
#      plugins/workflows/commands/{session-start,review,ship}.md.
#   3. If the intersection is EMPTY → not applicable, exit 0 (the job does no
#      work and emits no noise on PRs that don't touch a clone source — this is
#      why the signal is targeted, not cry-wolf).
#   4. If NON-empty → this PR edits a cloned upstream. Run check-clone-drift.sh
#      SCOPED to just the matched clone(s) (CLONES_FILTER) and pinned to the PR's
#      HEAD (UPSTREAM_REF=HEAD), so the recorded Upstream-SHA is compared to the
#      upstream blob AS THIS PR LEAVES IT — and an unrelated clone's pre-existing
#      drift (which the lagging clone-drift-check backstop owns) never reds this PR:
#        - matched clone(s) in sync (re-synced, or the edit didn't move the blob) → exit 0
#        - matched clone stale → print the re-sync obligation recipe, exit 1
#
# Severity is ADVISORY: the CI job runs with continue-on-error: true, so a stale
# clone shows as a red advisory check on the editing PR without hard-blocking
# merge (honours BC-7060's advisory-v1.0 / hard-block-only-if-drift-rate-
# motivates-it-in-v1.1 contract). Flip to blocking later by dropping the job's
# continue-on-error — a one-line change; this script is unchanged either way.
#
# Ownership convention (documented at plugins/flow-architecture/CLAUDE.md
# § Workflows plugin dependency): the upstream-editing author OWNS the re-sync
# in the same PR; escape hatch is to revert the upstream edit or loop in the
# FDA owner for changes that touch a locked FDA-swap axis.
#
# Inputs (all overridable; CI supplies the real PR context, the regression test
# supplies synthetic values):
#   CHANGED_FILES  newline/space-separated changed paths. If unset, computed
#                  from `git diff --name-only "$BASE_REF" "$HEAD_REF"`.
#   BASE_REF       diff base for the auto-computed file set (default origin/main)
#   HEAD_REF       ref whose upstream blob is the comparison target (default HEAD)
# ──────────────────────────────────────────────────────────────────────

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BASE_REF="${BASE_REF:-origin/main}"
HEAD_REF="${HEAD_REF:-HEAD}"
DRIFT_SCRIPT="plugins/flow-architecture/scripts/check-clone-drift.sh"

# The three workflows commands FDA clones (Q51/Q52/Q53). Editing any of these
# upstream is what should surface the re-sync obligation on the editing PR.
# Kept in lock-step with check-clone-drift.sh's CLONES list — the BC-12410
# regression harness asserts the two lists agree (Assertion A) so a future 4th
# clone can't be added to one but silently missed by the other.
UPSTREAM_CLONE_PATHS="plugins/workflows/commands/session-start.md plugins/workflows/commands/review.md plugins/workflows/commands/ship.md"

section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

section "FDA shift-left clone-drift (BC-12410) — ref: ${HEAD_REF}"

# 1. Resolve the changed-file set. Guard the env read under `set -u`: only
#    expand CHANGED_FILES in the branch where it is actually set.
if [ "${CHANGED_FILES+set}" = "set" ]; then
  # Injected (regression test / manual run). Word-split on IFS so either a
  # space- or newline-separated list normalizes to one path per line. `set -f`
  # disables pathname expansion for the split so a path containing a glob
  # metacharacter (*, ?, [) can't expand against the cwd; restored immediately.
  set -f
  # shellcheck disable=SC2086
  changed_files="$(printf '%s\n' $CHANGED_FILES)"
  set +f
else
  # Best-effort: a CI checkout may fetch the PR ref without setting up the
  # origin/main remote-tracking ref. Mirror check-clone-drift.sh's defensive
  # fetch so the diff base resolves. Skip when BASE_REF is overridden to a
  # local ref (regression test / manual run).
  if [ "$BASE_REF" = "origin/main" ] && ! git rev-parse origin/main >/dev/null 2>&1; then
    git fetch --depth=1 origin main >/dev/null 2>&1 || true
  fi
  # Two-arg (tree-vs-tree) diff — avoids a merge-base computation, so it stays
  # correct even when BASE_REF was shallow-fetched. On a pull_request merge
  # checkout HEAD already includes the base, so this yields exactly the PR's
  # net changes.
  changed_files="$(git diff --name-only "$BASE_REF" "$HEAD_REF" 2>/dev/null || true)"
fi

# 2. Path-filter: which cloned upstream commands does this PR touch? Track the
#    full paths (for the human-readable line) and the basenames (to scope the
#    drift check to exactly those clones via CLONES_FILTER). grep -Fxq is fixed-
#    string + whole-line, so a near-miss like `…/session-start.md.bak` cannot
#    match — keeping the gate targeted.
matched=""
matched_names=""
for up in $UPSTREAM_CLONE_PATHS; do
  if printf '%s\n' "$changed_files" | grep -Fxq "$up"; then
    matched="$matched $up"
    matched_names="$matched_names $(basename "$up" .md)"
  fi
done

# 3. Empty intersection → not applicable. No run, no noise.
if [ -z "$matched" ]; then
  printf "  not applicable — no cloned upstream command in this diff; nothing to check\n"
  printf "  (clone sources: %s)\n" "$UPSTREAM_CLONE_PATHS"
  exit 0
fi

printf "  cloned upstream command(s) edited in this PR:%s\n" "$matched"
printf "  checking the matching FDA clones against the PR's HEAD upstream blobs…\n"

# 4. Reuse the drift core via its env seams: CLONES_FILTER scopes the check to
#    only the matched clone(s) (so an unrelated clone's pre-existing drift can't
#    red this PR); UPSTREAM_REF=HEAD pins the comparison to the upstream AS THIS
#    PR LEAVES IT (origin/main is stale here). Stream the core's per-clone
#    PASS/FAIL output straight through — its exit code drives the verdict.
set +e
CLONES_FILTER="$matched_names" UPSTREAM_REF="$HEAD_REF" bash "$DRIFT_SCRIPT"
inner_rc=$?
set -e

if [ "$inner_rc" -eq 0 ]; then
  printf "\n\033[32mSHIFT-LEFT CLONE-DRIFT (BC-12410): clones in sync\033[0m\n"
  printf "  the matching FDA clone(s) already record the current upstream blob — nothing to re-sync.\n"
  exit 0
fi

# Stale clone → surface the obligation ON this PR.
printf "\n\033[31mSHIFT-LEFT CLONE-DRIFT (BC-12410): clone re-sync required\033[0m\n"
cat <<'EOF'
  This PR edits an upstream command that FDA clones, but the matching FDA clone
  is now stale. Re-sync it IN THIS PR so the obligation does not land on the
  next, unrelated PR:

    1. Port your change into plugins/flow-architecture/commands/<name>.md
       (respect the locked FDA-swap axes — see plugins/flow-architecture/CLAUDE.md
        § Workflows plugin dependency).
    2. Bump that clone header's `Upstream-SHA:` to the new upstream blob SHA.
    3. Re-run: bash plugins/flow-architecture/scripts/check-clone-drift.sh
       (expect pass=3 fail=0).

  Escape hatch: if the change touches a locked FDA-swap axis you cannot
  reconcile, revert the upstream edit or loop in the FDA owner.

  (Advisory — does not block merge. Promotes to hard-block per BC-7060's
   v1.1 criterion if the drift-rate empirically motivates it.)
EOF
exit 1
