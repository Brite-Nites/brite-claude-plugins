#!/usr/bin/env bash
set -euo pipefail

# ── Prerequisites Check ─────────────────────────────────────────────
# Verifies the runtime environment has everything the plugin needs.
# Each check outputs PASS/FAIL/SKIP.
# ─────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

pass_count=0
fail_count=0
skip_count=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass_count=$((pass_count + 1)); }
fail() { printf "  \033[31mFAIL\033[0m  %s — %s\n" "$1" "$2"; fail_count=$((fail_count + 1)); }
skip() { printf "  \033[33mSKIP\033[0m  %s — %s\n" "$1" "$2"; skip_count=$((skip_count + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

echo "Brite Plugin — Prerequisites Check"
echo "Repo root: $REPO_ROOT"

# ══════════════════════════════════════════════════════════════════════
# Section 1 — CLI Tools
# ══════════════════════════════════════════════════════════════════════
section "1. CLI Tools"

# git
if command -v git &>/dev/null; then
  git_ver=$(git --version 2>&1 | head -1)
  git_user=$(git config user.name 2>/dev/null || echo "")
  if [ -n "$git_user" ]; then
    pass "git ($git_ver, user: $git_user)"
  else
    fail "git" "installed but user.name not configured"
  fi
else
  fail "git" "not installed"
fi

# gh CLI
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    pass "gh CLI (authenticated as $gh_user)"
  else
    fail "gh CLI" "installed but not authenticated — run \`gh auth login\`"
  fi
else
  skip "gh CLI" "not installed (needed for /workflows:ship)"
fi

# node
if command -v node &>/dev/null; then
  node_ver=$(node --version 2>&1)
  pass "node ($node_ver)"
else
  fail "node" "not installed"
fi

# npx
if command -v npx &>/dev/null; then
  npx_ver=$(npx --version 2>&1)
  pass "npx ($npx_ver)"
else
  fail "npx" "not installed (needed for MCP servers)"
fi

# python3 (needed for validate.sh)
if command -v python3 &>/dev/null; then
  py_ver=$(python3 --version 2>&1)
  pass "python3 ($py_ver)"
else
  skip "python3" "not installed (needed for validate.sh)"
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2 — MCP Server Availability
# ══════════════════════════════════════════════════════════════════════
section "2. MCP Servers"

# sequential-thinking — check if the package resolves
if command -v npx &>/dev/null; then
  if npx --yes --package @modelcontextprotocol/server-sequential-thinking -- echo "ok" &>/dev/null; then
    pass "sequential-thinking MCP (package resolves)"
  else
    # Try a lighter check — just see if the package exists in npm
    if npm view @modelcontextprotocol/server-sequential-thinking version &>/dev/null; then
      pass "sequential-thinking MCP (package exists in registry)"
    else
      fail "sequential-thinking MCP" "package not found"
    fi
  fi
else
  skip "sequential-thinking MCP" "npx not available"
fi

# Linear MCP — check if the endpoint is reachable
if command -v curl &>/dev/null; then
  if curl -sf --max-time 5 https://mcp.linear.app/sse -o /dev/null 2>/dev/null; then
    pass "Linear MCP (endpoint reachable)"
  else
    skip "Linear MCP" "endpoint not reachable (may need auth or VPN)"
  fi
else
  skip "Linear MCP" "curl not available"
fi

# ══════════════════════════════════════════════════════════════════════
# Section 3 — Plugin JSON Validity (all plugins from marketplace)
# ══════════════════════════════════════════════════════════════════════
section "3. Plugin JSON"

if [ -f "$MARKETPLACE" ]; then
  while IFS= read -r src; do
    resolved=$(cd "$REPO_ROOT" && realpath "$src" 2>/dev/null || echo "$REPO_ROOT/$src")
    plugin_name="$(basename "$resolved")"
    plugin_json="$resolved/.claude-plugin/plugin.json"

    if [ ! -f "$plugin_json" ]; then
      fail "$plugin_name/plugin.json" "file not found at $plugin_json"
      continue
    fi

    if python3 -m json.tool "$plugin_json" > /dev/null 2>&1; then
      pass "$plugin_name/plugin.json is valid JSON"
    else
      fail "$plugin_name/plugin.json" "invalid JSON"
      continue
    fi

    # Check for disallowed fields (reuse validate.sh logic)
    disallowed_check=$(python3 -c "
import json, sys
with open('$plugin_json') as f:
    data = json.load(f)
allowed = {'name', 'description', 'author', 'version', 'homepage',
           'repository', 'license', 'keywords', 'commands', 'skills',
           'mcpServers', 'userConfig'}
unknown = set(data.keys()) - allowed
if unknown:
    print(f'FAIL:Disallowed fields: {sorted(unknown)}')
else:
    print('PASS')
" 2>&1)

    if [ "$disallowed_check" = "PASS" ]; then
      pass "$plugin_name/plugin.json has no disallowed fields"
    else
      fail "$plugin_name/plugin.json" "${disallowed_check#FAIL:}"
    fi
  done < <(python3 -c "
import json
with open('$MARKETPLACE') as f:
    data = json.load(f)
for p in data.get('plugins', []):
    print(p.get('source', ''))
" 2>&1)
else
  fail "marketplace.json" "not found at $MARKETPLACE"
fi

# ══════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════
section "Summary"

echo "  Passed: $pass_count  Failed: $fail_count  Skipped: $skip_count"
echo ""

if [ "$fail_count" -gt 0 ]; then
  printf "  \033[31m%d check(s) failed\033[0m\n" "$fail_count"
  echo ""
  exit 1
else
  printf "  \033[32mAll required checks passed\033[0m\n"
  echo ""
  exit 0
fi
