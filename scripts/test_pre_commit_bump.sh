#!/usr/bin/env bash
# Regression harness for the plugin-version-bump section of scripts/pre-commit.sh.
#
# Synthesizes a throw-away git repo with a fake plugin layout, then stages
# 11 scenarios and asserts the pre-commit hook exits with the expected code
# for each. Decoupled from $CLAUDE_JOB_DIR so it can run from CI and from a
# developer shell. Originally shipped ephemerally in BC-8712 then promoted
# per BC-8712 follow-up #1.
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
#   I  plugins/<name>/tests/hooks/<file> (test fixture)        expect PASS (0)  [P2 regression test]
#   J  plugins/<name>/shared/hooks/<file> (non-runtime docs)   expect PASS (0)  [P2 regression test]
#   K  plugins/<name>/skills/<skill>/references/<file>         expect FAIL (1)  [deep nest still triggers]
#
# Usage:
#   bash scripts/test_pre_commit_bump.sh                     # uses scripts/pre-commit.sh next to this file
#   bash scripts/test_pre_commit_bump.sh /path/to/pre-commit.sh

set -u  # do NOT set -e — we expect non-zero exits

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
tmproot="$(mktemp -d -t precommit-test.XXXXXX)"
trap 'rm -rf "$tmproot"' EXIT
cd "$tmproot"

pass=0
fail=0

assert_exit() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" -eq "$actual" ]; then
    echo "  PASS  $label (exit=$actual)"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label (expected exit=$expected, got exit=$actual)"
    fail=$((fail + 1))
  fi
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
  bash "$SCRIPT_UNDER_TEST" > "$tmproot/precommit-out.$$" 2>&1
  echo $?
}

# ── Scenario A: plugin content modified, no bump ────────────────
echo ""
echo "=== Scenario A: plugin content changed, NO version bump (expect FAIL) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
git add plugins/marketing/skills/foo/SKILL.md
rc=$(run_check)
assert_exit "Scenario A: bare content change rejected" 1 "$rc"
cd "$tmproot"

# ── Scenario B: plugin content + plugin.json bumped + marketplace bumped ─
echo ""
echo "=== Scenario B: content + both bumps (expect PASS) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
sed -i.bak 's/"version": "1.0.0"/"version": "1.0.1"/' plugins/marketing/.claude-plugin/plugin.json
sed -i.bak 's/"version": "1.0.0"/"version": "1.0.1"/' .claude-plugin/marketplace.json
rm -f plugins/marketing/.claude-plugin/plugin.json.bak .claude-plugin/marketplace.json.bak
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json
rc=$(run_check)
assert_exit "Scenario B: content + both bumps accepted" 0 "$rc"
cd "$tmproot"

# ── Scenario C: non-plugin file modified ────────────────────────
echo ""
echo "=== Scenario C: non-plugin file changed only (expect PASS) ==="
setup_repo
echo "some doc" > docs.md
git add docs.md
rc=$(run_check)
assert_exit "Scenario C: non-plugin change accepted" 0 "$rc"
cd "$tmproot"

# ── Scenario D: plugin content + plugin.json staged but version unchanged ─
echo ""
echo "=== Scenario D: content staged + plugin.json staged with non-version edit (expect FAIL) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
sed -i.bak 's/"description": "x"/"description": "y"/' plugins/marketing/.claude-plugin/plugin.json
rm -f plugins/marketing/.claude-plugin/plugin.json.bak
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json
rc=$(run_check)
assert_exit "Scenario D: staged plugin.json without version bump rejected" 1 "$rc"
cd "$tmproot"

# ── Scenario E: plugin content + plugin.json bumped but marketplace.json missing ─
echo ""
echo "=== Scenario E: plugin.json bumped but marketplace.json not staged (expect FAIL) ==="
setup_repo
echo "modified body" >> plugins/marketing/skills/foo/SKILL.md
sed -i.bak 's/"version": "1.0.0"/"version": "1.0.1"/' plugins/marketing/.claude-plugin/plugin.json
rm -f plugins/marketing/.claude-plugin/plugin.json.bak
git add plugins/marketing/skills/foo/SKILL.md plugins/marketing/.claude-plugin/plugin.json
rc=$(run_check)
assert_exit "Scenario E: missing marketplace bump rejected" 1 "$rc"
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
rc=$(run_check)
assert_exit "Scenario F: agents/ change without bump rejected" 1 "$rc"
cd "$tmproot"

# ── Scenario G: hooks/ change without bump ───────────────────────
echo ""
echo "=== Scenario G: hooks/ change without bump (expect FAIL) ==="
setup_repo
mkdir -p plugins/marketing/hooks
echo '{}' > plugins/marketing/hooks/hooks.json
git add plugins/marketing/hooks/hooks.json
rc=$(run_check)
assert_exit "Scenario G: hooks/ change without bump rejected" 1 "$rc"
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
rc=$(run_check)
assert_exit "Scenario H: commands/ change without bump rejected" 1 "$rc"
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
rc=$(run_check)
assert_exit "Scenario I: nested tests/hooks/ NOT flagged" 0 "$rc"
cd "$tmproot"

# ── Scenario J: nested shared/hooks path — should NOT trigger ───
echo ""
echo "=== Scenario J: plugins/<name>/shared/hooks/<file> should NOT trigger (expect PASS) ==="
setup_repo
mkdir -p plugins/marketing/shared/hooks
echo "docs" > plugins/marketing/shared/hooks/lifecycle.md
git add plugins/marketing/shared/hooks/lifecycle.md
rc=$(run_check)
assert_exit "Scenario J: nested shared/hooks/ NOT flagged" 0 "$rc"
cd "$tmproot"

# ── Scenario K: deeply nested skill content — SHOULD trigger ────
# Reference docs under a skill ARE plugin runtime content and should trigger.
echo ""
echo "=== Scenario K: plugins/<name>/skills/<skill>/references/<file> SHOULD trigger (expect FAIL without bump) ==="
setup_repo
mkdir -p plugins/marketing/skills/foo/references
echo "ref doc" > plugins/marketing/skills/foo/references/ref.md
git add plugins/marketing/skills/foo/references/ref.md
rc=$(run_check)
assert_exit "Scenario K: deeply nested skill ref content IS flagged without bump" 1 "$rc"
cd "$tmproot"

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "================================="
echo "  PASS: $pass"
echo "  FAIL: $fail"
echo "================================="
[ "$fail" -eq 0 ] && exit 0 || exit 1
