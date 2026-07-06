#!/usr/bin/env bash
set -euo pipefail

# scripts/test-python-units.sh — BC-16289
#
# Runs the pytest suites owned by each Brite plugin that ships Python unit
# tests (revops, marketing, workflows — an EXPLICIT list; repo convention is
# explicit wiring over glob discovery, per BC-12909) and prints a single
# `RESULT pass=<total-passed> fail=<total-failed>` line that validate.sh's
# §2j section parses (same contract as the other test-*.sh harnesses).
#
# Each plugin's tests/ dir is pytest-rootdir-sensitive (e.g. revops/tests
# imports `from tests.hooks.conftest import ...`), so each suite MUST be run
# from inside its own plugin directory, not from the repo root.
#
# pytest missing → prints `SKIP: pytest not installed` and exits 0 (advisory —
# don't block a bare-checkout dev loop, and don't block validate.sh §2j which
# runs this wrapper in the CI `validate` job that does NOT install pytest).
# The dedicated `python-units` CI job — the one that DOES install pytest and is
# the blocking source of truth — sets REQUIRE_PYTEST=true, which turns a missing
# pytest there into a hard failure (exit 1). NOTE: do NOT gate on `CI=true` —
# GitHub Actions sets CI=true in EVERY job, including `validate` (which runs
# this via §2j without pytest), so keying on CI would fail that job spuriously.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── pytest availability guard ──────────────────────────────────────────
if ! python3 -m pytest --version >/dev/null 2>&1; then
  if [ "${REQUIRE_PYTEST:-}" = "true" ]; then
    echo "ERROR: pytest required here but not installed — run: python3 -m pip install pytest" >&2
    exit 1
  fi
  echo "SKIP: pytest not installed (run: python3 -m pip install pytest)"
  exit 0
fi

# Explicit plugin list — add a plugin here when it grows a tests/ dir with
# pytest-style tests. Repo convention is explicit wiring, not glob discovery
# (BC-12909).
plugins="revops marketing workflows"

total_pass=0
total_fail=0

for p in $plugins; do
  plugin_dir="$REPO_ROOT/plugins/$p"
  if [ ! -d "$plugin_dir/tests" ]; then
    echo "  (skip) plugins/$p/tests not found"
    continue
  fi

  echo "-- plugins/$p/tests --"
  if plugin_output=$(cd "$plugin_dir" && python3 -m pytest tests/ -q --no-header 2>&1); then
    plugin_rc=0
  else
    plugin_rc=$?
  fi
  printf '%s\n' "$plugin_output"

  # Parse pytest's terminal summary, e.g.:
  #   "17 failed, 257 passed, 5 skipped in 144.44s (0:02:24)"
  #   "100 passed in 0.17s"
  #   "1 error in 0.35s"
  # Collection errors ("N error(s)") count as failures — they mean a whole
  # file never ran, which is strictly worse than a normal assertion failure.
  pass_n=$(printf '%s\n' "$plugin_output" | grep -oE '[0-9]+ passed' | tail -1 | grep -oE '[0-9]+' || true)
  fail_n=$(printf '%s\n' "$plugin_output" | grep -oE '[0-9]+ failed' | tail -1 | grep -oE '[0-9]+' || true)
  error_n=$(printf '%s\n' "$plugin_output" | grep -oE '[0-9]+ error' | tail -1 | grep -oE '[0-9]+' || true)

  pass_n="${pass_n:-0}"
  fail_n="${fail_n:-0}"
  error_n="${error_n:-0}"

  total_pass=$((total_pass + pass_n))
  total_fail=$((total_fail + fail_n + error_n))

  if [ "$plugin_rc" -ne 0 ] && [ "$fail_n" -eq 0 ] && [ "$error_n" -eq 0 ]; then
    # pytest exited nonzero without a parseable failed/error count (e.g. a
    # usage error) — count it so a bare fail=0 never masks a real problem.
    total_fail=$((total_fail + 1))
  fi
done

echo ""
echo "RESULT pass=$total_pass fail=$total_fail"

[ "$total_fail" -eq 0 ]
