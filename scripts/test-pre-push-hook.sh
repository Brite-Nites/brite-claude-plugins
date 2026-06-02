#!/usr/bin/env bash
set -euo pipefail

# ── Test the pre-push hook's worktree resolution (BC-11951) ──────────
# The primary checkout of this repo is bare (core.bare=true; all work happens
# in worktrees). A push issued from the bare root has no worktree, so
# `git rev-parse --show-toplevel` fails. The hook must NOT collapse to an
# absolute "/scripts/validate.sh" path and abort the push (including ref-only
# pushes like branch deletions) — it must skip validation cleanly. Pushes from
# a real worktree must still run validate.sh (no regression to the gate).
#
# Usage: test-pre-push-hook.sh [path-to-pre-push-hook]
#   Defaults to <repo>/.githooks/pre-push
# ─────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${1:-$REPO_ROOT/.githooks/pre-push}"

# ── Defuse caller's git env ──────────────────────────────────────────
# This harness is wired into validate.sh, which the pre-push hook invokes on
# `git push`. git presets GIT_DIR / GIT_WORK_TREE / GIT_INDEX_FILE (etc.) in the
# hook's environment to point at the CALLER's repo, and those override the
# cwd-based discovery that the fixtures' `git init` and the hook's own
# `git rev-parse --show-toplevel` rely on. Unset them BEFORE any git command so
# every fixture resolves its own .git by cwd. Mirrors test_pre_commit_bump.sh.
# (Without this the worktree fixture's toplevel comes back empty under push-time
# env and the hook wrongly takes its bare-root skip branch — the very class of
# bug BC-11951 fixes, one level up.)
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

pass=0
fail=0

# total is derived at summary time ($((pass + fail))) rather than incremented in
# both helpers — single source of truth, no drift if a counter is ever added.
pass()    { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass=$((pass + 1)); }
fail()    { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail=$((fail + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

if [ ! -f "$HOOK" ]; then
  echo "ERROR: pre-push hook not found: $HOOK" >&2
  exit 2
fi

# ── Hermetic sandbox ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/bc11951.XXXXXX")"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# Run the hook-under-test with cwd in $1, capturing combined output (HOOK_OUT)
# and exit code (RC). Never aborts the harness on a non-zero hook exit.
#
# Why direct `bash "$HOOK"` is equivalent to a real `git push` here: git pipes
# the pushed refspec lines to a pre-push hook on stdin and passes <remote> <url>
# as $1/$2. This hook reads neither — it only calls `git rev-parse`. So a
# `--delete` (ref-only) push and a normal content push are indistinguishable at
# this hook's surface, and `</dev/null` faithfully models every refspec shape,
# including AC1's named `--delete` case. (If a future revision makes the hook
# read stdin refspecs, add a real-`git push` integration case here.)
run_hook() {
  local workdir="$1"
  set +e
  # Git env is already scrubbed at script top (see "Defuse caller's git env"),
  # so the hook resolves --show-toplevel purely from $workdir's cwd.
  HOOK_OUT="$(cd "$workdir" && bash "$HOOK" origin "file://$workdir" </dev/null 2>&1)"
  RC=$?
  set -e
}

# Fixture 1 — real worktree (non-bare) with a sentinel validate.sh that proves
# whether the gate ran.
WORK="$SANDBOX/work"
mkdir -p "$WORK/scripts"
git init -q "$WORK"
cat > "$WORK/scripts/validate.sh" <<'SENTINEL'
#!/usr/bin/env bash
echo "VALIDATE_RAN"
exit 0
SENTINEL
chmod +x "$WORK/scripts/validate.sh"

# Fixture 2 — bare repo (no worktree), reproducing the bare-root push context.
BARE="$SANDBOX/bare.git"
git init -q --bare "$BARE"

# Fixture 3 — worktree whose sentinel validate.sh FAILS (exit 1), to prove the
# hook propagates a non-zero gate result so a failing push aborts. This locks
# the load-bearing `exec` behavior: a regression that swallowed the gate's exit
# status (e.g. `validate.sh || true`) would still pass every other assertion.
WORKFAIL="$SANDBOX/workfail"
mkdir -p "$WORKFAIL/scripts"
git init -q "$WORKFAIL"
cat > "$WORKFAIL/scripts/validate.sh" <<'SENTINEL'
#!/usr/bin/env bash
echo "VALIDATE_FAILED"
exit 1
SENTINEL
chmod +x "$WORKFAIL/scripts/validate.sh"

# Fixture 4 — worktree whose sentinel validate.sh reports whether the caller's
# git env leaked through to it. Locks the hook's env-scrub-before-exec fix.
WORKENV="$SANDBOX/workenv"
mkdir -p "$WORKENV/scripts"
git init -q "$WORKENV"
cat > "$WORKENV/scripts/validate.sh" <<'SENTINEL'
#!/usr/bin/env bash
if [ -n "${GIT_DIR:-}" ] || [ -n "${GIT_INDEX_FILE:-}" ]; then
  echo "GIT_ENV_LEAKED"
else
  echo "GIT_ENV_CLEAN"
fi
exit 0
SENTINEL
chmod +x "$WORKENV/scripts/validate.sh"

# ═════════════════════════════════════════════════════════════════════
section "Worktree context — validation still runs (AC2, regression lock)"
# ═════════════════════════════════════════════════════════════════════
run_hook "$WORK"
if [ "$RC" -eq 0 ]; then
  pass "worktree push: hook exits 0"
else
  fail "worktree push: hook exited $RC (expected 0)"
fi
if printf '%s\n' "$HOOK_OUT" | grep -q "VALIDATE_RAN"; then
  pass "worktree push: validate.sh actually ran"
else
  fail "worktree push: validate.sh did NOT run -- output: $HOOK_OUT"
fi

# ═════════════════════════════════════════════════════════════════════
section "Bare-root context — push not aborted (AC1) + graceful skip (AC3)"
# ═════════════════════════════════════════════════════════════════════
run_hook "$BARE"
if [ "$RC" -eq 0 ]; then
  pass "bare-root push: hook exits 0 (push not aborted)"
else
  fail "bare-root push: hook exited $RC (expected 0) -- push would abort"
fi
if printf '%s\n' "$HOOK_OUT" | grep -q "No such file or directory"; then
  fail "bare-root push: hit the '/scripts/validate.sh: No such file or directory' bug"
else
  pass "bare-root push: no '/scripts/validate.sh' path error"
fi
# Anchor on the hook's distinctive action phrase, not the bare token "skip" —
# a degraded message (e.g. "fatal: cannot skip ahead") must NOT satisfy AC3.
if printf '%s\n' "$HOOK_OUT" | grep -qi "skipping plugin validation"; then
  pass "bare-root push: emits the distinctive skip message"
else
  fail "bare-root push: no distinctive skip message -- output: $HOOK_OUT"
fi
if printf '%s\n' "$HOOK_OUT" | grep -q "VALIDATE_RAN"; then
  fail "bare-root push: unexpectedly ran validate.sh from the bare root"
else
  pass "bare-root push: correctly skipped validate.sh"
fi

# ═════════════════════════════════════════════════════════════════════
section "Worktree context, failing gate — push aborts (exec propagates non-zero)"
# ═════════════════════════════════════════════════════════════════════
run_hook "$WORKFAIL"
if [ "$RC" -ne 0 ]; then
  pass "failing gate: hook exits non-zero (push would abort)"
else
  fail "failing gate: hook exited 0 -- a failing gate must abort the push"
fi
if printf '%s\n' "$HOOK_OUT" | grep -q "VALIDATE_FAILED"; then
  pass "failing gate: validate.sh actually ran before failing"
else
  fail "failing gate: validate.sh did NOT run -- output: $HOOK_OUT"
fi

# ═════════════════════════════════════════════════════════════════════
section "Worktree context, leaked git env — hook scrubs before exec (env-leak lock)"
# ═════════════════════════════════════════════════════════════════════
# `git push` presets GIT_DIR / GIT_INDEX_FILE in the hook env, pointing at the
# caller's repo. Set them for THIS invocation (overriding the harness-top scrub),
# pointing at the fixture's own .git so worktree resolution still succeeds, and
# assert the hook unsets them before exec — so validate.sh and its hermetic
# sub-tests run clean (the test_precommit_advisory.sh failure mode this fixes).
set +e
ENV_OUT="$(cd "$WORKENV" && GIT_DIR="$WORKENV/.git" GIT_INDEX_FILE="$WORKENV/.git/index" bash "$HOOK" origin "file://$WORKENV" </dev/null 2>&1)"
ENV_RC=$?
set -e
if printf '%s\n' "$ENV_OUT" | grep -q "GIT_ENV_CLEAN"; then
  pass "leaked git env: hook scrubbed it before exec (validate saw a clean env)"
elif printf '%s\n' "$ENV_OUT" | grep -q "GIT_ENV_LEAKED"; then
  fail "leaked git env: validate.sh saw leaked GIT_DIR/GIT_INDEX_FILE -- output: $ENV_OUT"
else
  fail "leaked git env: validate.sh did not run (worktree unresolved?) -- RC=$ENV_RC output: $ENV_OUT"
fi

# ── Summary ──────────────────────────────────────────────────────────
section "Summary"
total=$((pass + fail))
echo "  Total: $total  Passed: $pass  Failed: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  printf "  \033[31m%d test(s) failed\033[0m\n" "$fail"
  echo ""
  exit 1
else
  printf "  \033[32mAll tests passed\033[0m\n"
  echo ""
  exit 0
fi
