#!/usr/bin/env bash
# Regression harness for the plugin-version-bump section of scripts/pre-commit.sh.
#
# Synthesizes a throw-away git repo with a fake plugin layout, then stages
# 15 scenarios (A-O) and asserts the pre-commit hook exits with the expected
# code AND produces the expected diagnostic message for each. The substring
# check is load-bearing — a bash crash that happens to exit 1 satisfies the
# numeric expectation but fires a different code path than the scenario
# targets (round 2 of /workflows:review surfaced exactly this masking via
# Scenario M's deletion-only `${staged_files[@]}` unbound-variable crash).
# Decoupled from $CLAUDE_JOB_DIR so it can run from CI and a developer shell.
# Originally shipped ephemerally in BC-8712 then promoted per BC-8712
# follow-up #1, hardened by review rounds 1+2.
#
# Scenarios:
#   A  plugin content changed, NO version bump                 expect FAIL (1)
#   B  content + plugin.json bump + marketplace.json bump      expect PASS (0)
#   C  non-plugin file changed only                            expect PASS (0)
#   D  plugin.json staged with non-version edit                expect FAIL (1)
#   E  plugin.json bumped, marketplace.json not staged         expect FAIL (1)
#   F  agents/<file> changed without bump                      expect FAIL (1)
#   G  hooks/<file> changed without bump                       expect FAIL (1)
#   H  commands/<file> changed without bump                    expect FAIL (1)
#   I  plugins/<name>/tests/hooks/<file> (test fixture)        expect PASS (0)  [P2 case-glob regression]
#   J  plugins/<name>/shared/hooks/<file> (non-runtime docs)   expect PASS (0)  [P2 case-glob regression]
#   K  plugins/<name>/skills/<skill>/references/<file>         expect FAIL (1)  [deep nest still triggers]
#   L  corrupt staged plugin.json + content change             expect FAIL (1)  [silent-bypass guard]
#   M  deletion of plugin runtime content without bump         expect FAIL (1)  [--diff-filter=d guard]
#   N  marketplace entry bumped for wrong plugin name          expect FAIL (1)  [per-plugin name-match]
#   O  plugins/<name>/tests/commands/<file>                    expect PASS (0)  [case-glob symmetric — commands keyword]
#
# Usage:
#   bash scripts/test_pre_commit_bump.sh                     # uses scripts/pre-commit.sh next to this file
#   bash scripts/test_pre_commit_bump.sh /path/to/pre-commit.sh

set -u  # do NOT set -e — we expect non-zero exits

# ── Defuse caller's git env ──────────────────────────────────────────
# When this harness is invoked from inside a git hook (e.g., pre-push via
# validate.sh), git presets GIT_DIR / GIT_WORK_TREE / GIT_INDEX_FILE in
# the environment to point at the CALLER's repo. Those env vars override
# the cwd-based discovery that `git init` / `git add` / `git commit` would
# otherwise use — so the synthetic baseline commit would land on the
# caller's branch and `git config user.email t@t` would clobber the
# caller's .git/config. Unset them so all subsequent git commands resolve
# the scenario's own .git directory by cwd, as intended.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

# ── Locate script-under-test ─────────────────────────────────────────
script_dir="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_UNDER_TEST="${1:-$script_dir/pre-commit.sh}"

if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  echo "FATAL: script-under-test not found: $SCRIPT_UNDER_TEST"
  exit 2
fi

# Convert to absolute path so the test harness can cd freely without losing it
SCRIPT_UNDER_TEST="$(cd "$(dirname "$SCRIPT_UNDER_TEST")" && pwd)/$(basename "$SCRIPT_UNDER_TEST")"

# ── Set up isolated tmp dir + cleanup trap ───────────────────────────
tmproot="$(mktemp -d -t precommit-test.XXXXXX)" || { echo "FATAL: mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$tmproot"' EXIT
cd "$tmproot"

pass=0
fail=0
LAST_HOOK_OUTPUT=""
LAST_RC=0

assert_exit() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" -eq "$actual" ]; then
    echo "  PASS  $label (exit=$actual)"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label (expected exit=$expected, got exit=$actual)"
    # Surface the hook's own diagnostics on mismatch — otherwise debugging
    # a failing scenario means re-running the harness by hand.
    if [ -n "${LAST_HOOK_OUTPUT:-}" ]; then
      printf '%s\n' "$LAST_HOOK_OUTPUT" | tail -10 | sed 's/^/      | /'
    fi
    fail=$((fail + 1))
  fi
}

# Combined exit-code + substring check. Use on FAIL-expecting scenarios so a
# bash crash (e.g., the pre-commit.sh `staged_files[@]` unbound-variable bug
# surfaced in /workflows:review round 2) doesn't silently satisfy `expect=1`
# without actually firing the policy-rejection code path the scenario targets.
# The substring is matched against the captured hook stdout+stderr.
assert_exit_and_contains() {
  local label="$1"
  local expected_exit="$2"
  local actual_exit="$3"
  local expected_substr="$4"

  local exit_ok=true substr_ok=true
  [ "$expected_exit" -eq "$actual_exit" ] || exit_ok=false
  case "${LAST_HOOK_OUTPUT:-}" in
    *"$expected_substr"*) ;;
    *) substr_ok=false ;;
  esac

  if [ "$exit_ok" = true ] && [ "$substr_ok" = true ]; then
    echo "  PASS  $label (exit=$actual_exit, contains '$expected_substr')"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label"
    [ "$exit_ok" = false ] && echo "         expected exit=$expected_exit, got exit=$actual_exit"
    [ "$substr_ok" = false ] && echo "         expected output to contain: '$expected_substr'"
    if [ -n "${LAST_HOOK_OUTPUT:-}" ]; then
      printf '%s\n' "$LAST_HOOK_OUTPUT" | tail -10 | sed 's/^/      | /'
    fi
    fail=$((fail + 1))
  fi
}

bump_version() {
  # Rewrite "version": "1.0.0" to "version": "$2" in file $1; clean BSD-sed backup.
  sed -i.bak 's/"version": "1.0.0"/"version": "'"$2"'"/' "$1"
  rm -f "$1.bak"
  # Post-condition: the sed pattern is anchored on the literal "1.0.0"
  # baseline. If setup_repo's baseline version ever drifts, the sed silently
  # no-ops and scenarios start asserting the inverse of their intent. Guard.
  grep -q "\"version\": \"$2\"" "$1" || { echo "FATAL: bump_version no-op on $1 (baseline drift?)" >&2; exit 2; }
}

setup_repo() {
  rm -rf scenario && mkdir scenario && cd scenario
  git init -q -b main
  git config user.email t@t && git config user.name t

  mkdir -p plugins/marketing/skills/foo
  mkdir -p plugins/marketing/.claude-plugin
  mkdir -p .claude-plugin

  cat > plugins/marketing/skills/foo/SKILL.md <<'EOF'
---
name: foo
description: orig
user-invocable: true
---
orig body
EOF

  cat > plugins/marketing/.claude-plugin/plugin.json <<'EOF'
{ "name": "marketing", "description": "x", "author": {"name": "t"}, "version": "1.0.0" }
EOF

  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "britenites",
  "owner": {"name": "t"},
  "plugins": [
    {"name": "marketing", "source": "plugins/marketing", "version": "1.0.0"}
  ]
}
EOF

  git add -A
  git commit -q -m "baseline"
}

run_check() {
  # Set LAST_HOOK_OUTPUT + LAST_RC as globals (NOT echoed) so the assignment
  # propagates to the parent scope. Round 1 used `LAST_HOOK_OUTPUT=$(...);
  # echo $?` invoked via `rc=$(run_check)`, but that wrapper subshell trapped
  # the global assignment — the surfaced-diagnostic branch in assert_exit was
  # dead code. Caller pattern: `run_check; assert_exit ... "$LAST_RC"`.
  # (Bug surfaced by /workflows:review round 2 on PR #318.)
  LAST_HOOK_OUTPUT=$(bash "$SCRIPT_UNDER_TEST" 2>&1)
  LAST_RC=$?
}

# ── Scenario A: plugin content modified, no bump ────────────────
echo ""
echo "=== Scenario A: plugin content changed, NO version bump (expect FAIL) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
git add plugins/marketing/skills/foo/SKILL.md
run_check
assert_exit_and_contains "Scenario A: bare content change rejected" 1 "$LAST_RC" "is not staged"
cd "$tmproot"

# ── Scenario B: plugin content + plugin.json bumped + marketplace bumped ─
echo ""
echo "=== Scenario B: content + both bumps (expect PASS) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
bump_version plugins/marketing/.claude-plugin/plugin.json 1.0.1
bump_version .claude-plugin/marketplace.json 1.0.1
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json
run_check
assert_exit "Scenario B: content + both bumps accepted" 0 "$LAST_RC"
cd "$tmproot"

# ── Scenario C: non-plugin file modified ────────────────────────
echo ""
echo "=== Scenario C: non-plugin file changed only (expect PASS) ==="
setup_repo
echo "some doc" > docs.md
git add docs.md
run_check
assert_exit "Scenario C: non-plugin change accepted" 0 "$LAST_RC"
cd "$tmproot"

# ── Scenario D: plugin content + plugin.json staged but version unchanged ─
echo ""
echo "=== Scenario D: content staged + plugin.json staged with non-version edit (expect FAIL) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
sed -i.bak 's/"description": "x"/"description": "y"/' plugins/marketing/.claude-plugin/plugin.json
rm -f plugins/marketing/.claude-plugin/plugin.json.bak
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json
run_check
assert_exit_and_contains "Scenario D: staged plugin.json without version bump rejected" 1 "$LAST_RC" "version is unchanged"
cd "$tmproot"

# ── Scenario E: plugin content + plugin.json bumped but marketplace.json missing ─
echo ""
echo "=== Scenario E: plugin.json bumped but marketplace.json not staged (expect FAIL) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
bump_version plugins/marketing/.claude-plugin/plugin.json 1.0.1
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json
run_check
assert_exit_and_contains "Scenario E: missing marketplace bump rejected" 1 "$LAST_RC" "is not staged"
cd "$tmproot"

# ── Scenario F: agents/ change (not skills/) — also covered ─────
echo ""
echo "=== Scenario F: agents/ change without bump (expect FAIL) ==="
setup_repo
mkdir -p plugins/marketing/agents
echo "---
name: x
description: y
model: haiku
---" > plugins/marketing/agents/x.md
git add plugins/marketing/agents/x.md
run_check
assert_exit_and_contains "Scenario F: agents/ change without bump rejected" 1 "$LAST_RC" "is not staged"
cd "$tmproot"

# ── Scenario G: hooks/ change without bump ───────────────────────
echo ""
echo "=== Scenario G: hooks/ change without bump (expect FAIL) ==="
setup_repo
mkdir -p plugins/marketing/hooks
echo '{}' > plugins/marketing/hooks/hooks.json
git add plugins/marketing/hooks/hooks.json
run_check
assert_exit_and_contains "Scenario G: hooks/ change without bump rejected" 1 "$LAST_RC" "is not staged"
cd "$tmproot"

# ── Scenario H: commands/ change without bump ───────────────────
echo ""
echo "=== Scenario H: commands/ change without bump (expect FAIL) ==="
setup_repo
mkdir -p plugins/marketing/commands
echo '---
description: x
---
body' > plugins/marketing/commands/cmd.md
git add plugins/marketing/commands/cmd.md
run_check
assert_exit_and_contains "Scenario H: commands/ change without bump rejected" 1 "$LAST_RC" "is not staged"
cd "$tmproot"

# ── Scenario I: nested tests/hooks path — should NOT trigger ────
# Regression test for P2 case-glob over-match (PR #317 review finding).
# See memory/gotcha_bash_case_glob_crosses_slash.md.
echo ""
echo "=== Scenario I: plugins/<name>/tests/hooks/<file> should NOT trigger (expect PASS) ==="
setup_repo
mkdir -p plugins/marketing/tests/hooks
echo "test fixture" > plugins/marketing/tests/hooks/test_fixture.py
git add plugins/marketing/tests/hooks/test_fixture.py
run_check
assert_exit "Scenario I: nested tests/hooks/ NOT flagged" 0 "$LAST_RC"
cd "$tmproot"

# ── Scenario J: nested shared/hooks path — should NOT trigger ───
echo ""
echo "=== Scenario J: plugins/<name>/shared/hooks/<file> should NOT trigger (expect PASS) ==="
setup_repo
mkdir -p plugins/marketing/shared/hooks
echo "docs" > plugins/marketing/shared/hooks/lifecycle.md
git add plugins/marketing/shared/hooks/lifecycle.md
run_check
assert_exit "Scenario J: nested shared/hooks/ NOT flagged" 0 "$LAST_RC"
cd "$tmproot"

# ── Scenario K: deeply nested skill content — SHOULD trigger ────
# Reference docs under a skill ARE plugin runtime content and should trigger.
echo ""
echo "=== Scenario K: plugins/<name>/skills/<skill>/references/<file> SHOULD trigger (expect FAIL without bump) ==="
setup_repo
mkdir -p plugins/marketing/skills/foo/references
echo "ref doc" > plugins/marketing/skills/foo/references/ref.md
git add plugins/marketing/skills/foo/references/ref.md
run_check
assert_exit_and_contains "Scenario K: deeply nested skill ref content IS flagged without bump" 1 "$LAST_RC" "is not staged"
cd "$tmproot"

# ── Scenario L: corrupt staged plugin.json — silent-bypass guard ─
# Regression test for the silent-bypass surfaced by /workflows:review on PR #318.
# Without the fail-closed check in pre-commit.sh, malformed staged plugin.json
# yields pj_staged_ver="" and the equality check short-circuits — letting the
# hook exit 0 with no real bump enforced.
echo ""
echo "=== Scenario L: corrupt staged plugin.json rejected (expect FAIL) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
# Overwrite plugin.json with invalid JSON; bump marketplace correctly so
# the only failure mode under test is the plugin.json parse-error path.
echo "GARBAGE NOT JSON {" > plugins/marketing/.claude-plugin/plugin.json
bump_version .claude-plugin/marketplace.json 1.0.1
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json
run_check
assert_exit_and_contains "Scenario L: corrupt plugin.json IS flagged (no silent bypass)" 1 "$LAST_RC" "unparseable or missing version"
cd "$tmproot"

# ── Scenario M: deletion of plugin runtime content ──────────────
# Regression test for the --diff-filter=d bypass. Prior to the fix, the hook
# excluded deletions from staged_files, so `git rm` of a plugin runtime file
# silently passed (the deletion is also a content change per BC-6000 — the
# old version stays in clients' plugin caches and serves now-deleted content).
echo ""
echo "=== Scenario M: deletion of plugin runtime without bump (expect FAIL) ==="
setup_repo
git rm -q plugins/marketing/skills/foo/SKILL.md
run_check
# Substring check pins the right code path — without it, the macOS bash 3.2
# unbound-variable crash on `${staged_files[@]}` (Round 2 P1) would exit 1
# and silently satisfy the assertion.
assert_exit_and_contains "Scenario M: deletion of plugin runtime IS flagged without bump" 1 "$LAST_RC" "is not staged"
cd "$tmproot"

# ── Scenario N: marketplace entry mismatch ──────────────────────
# Regression test for the per-plugin name-match in marketplace.json. Without
# it, bumping any plugins[].version would falsely satisfy the marketplace
# bump check for an unrelated plugin.
echo ""
echo "=== Scenario N: marketplace entry bumped for wrong plugin (expect FAIL) ==="
setup_repo
# Add a second plugin 'other' to the baseline so we can mis-bump its entry
cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "britenites",
  "owner": {"name": "t"},
  "plugins": [
    {"name": "marketing", "source": "plugins/marketing", "version": "1.0.0"},
    {"name": "other", "source": "plugins/other", "version": "1.0.0"}
  ]
}
EOF
mkdir -p plugins/other/.claude-plugin
cat > plugins/other/.claude-plugin/plugin.json <<'EOF'
{ "name": "other", "description": "x", "author": {"name": "t"}, "version": "1.0.0" }
EOF
git add -A && git commit -q -m "add other plugin"

# Stage marketing content, bump marketing's plugin.json, but bump 'other' (not 'marketing') in marketplace
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
bump_version plugins/marketing/.claude-plugin/plugin.json 1.0.1
cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "britenites",
  "owner": {"name": "t"},
  "plugins": [
    {"name": "marketing", "source": "plugins/marketing", "version": "1.0.0"},
    {"name": "other", "source": "plugins/other", "version": "1.0.1"}
  ]
}
EOF
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json
run_check
assert_exit_and_contains "Scenario N: wrong-plugin marketplace bump rejected" 1 "$LAST_RC" "version for 'marketing' is unchanged"
cd "$tmproot"

# ── Scenario O: case-glob spot-check for commands keyword ───────
# Scenario I covers tests/hooks/ NOT triggering. The regex
# `^plugins/[^/]+/(commands|skills|hooks|agents)/` puts all four runtime
# keywords in one alternation arm, so a regression in one tends to regress
# all four — but this scenario pins the `commands` keyword explicitly so a
# future special-case for one keyword can't re-introduce the over-match
# silently. (`skills` and `agents` are implicit-but-untested via the shared
# regex arm.) See [[gotcha-bash-case-glob-crosses-slash]].
echo ""
echo "=== Scenario O: plugins/<name>/tests/commands/<file> should NOT trigger (expect PASS) ==="
setup_repo
mkdir -p plugins/marketing/tests/commands
echo "test fixture" > plugins/marketing/tests/commands/test_fixture.py
git add plugins/marketing/tests/commands/test_fixture.py
run_check
assert_exit "Scenario O: nested tests/commands/ NOT flagged" 0 "$LAST_RC"
cd "$tmproot"

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "================================="
echo "  PASS: $pass"
echo "  FAIL: $fail"
echo "================================="
# Machine-parseable contract line for scripts/validate.sh Section 2c — must be
# the last non-empty line. Independent of the human-readable banner above.
printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
