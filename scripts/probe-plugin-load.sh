#!/usr/bin/env bash
set -euo pipefail

# ── Plugin Loading Test ──────────────────────────────────────────────
# Verifies that all expected commands register when the plugin is loaded.
# Must run OUTSIDE a Claude session (from terminal or CI).
#
# Usage:
#   bash scripts/probe-plugin-load.sh                     # default: plugins/workflows
#   bash scripts/probe-plugin-load.sh plugins/my-plugin   # test a specific plugin
# ─────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="${1:-$REPO_ROOT/plugins/workflows}"

# Resolve relative paths
if [[ "$PLUGIN_DIR" != /* ]]; then
  PLUGIN_DIR="$REPO_ROOT/$PLUGIN_DIR"
fi

pass_count=0
fail_count=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass_count=$((pass_count + 1)); }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail_count=$((fail_count + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# Derive plugin name from plugin.json or directory name
plugin_name="$(basename "$PLUGIN_DIR")"
if [ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
  pj_name=$(python3 -c "
import json
with open('$PLUGIN_DIR/.claude-plugin/plugin.json') as f:
    print(json.load(f).get('name', ''))
" 2>/dev/null || true)
  if [ -n "$pj_name" ]; then
    plugin_name="$pj_name"
  fi
fi

echo "Brite Plugin — Loading Test"
echo "Plugin dir: $PLUGIN_DIR"
echo "Plugin name: $plugin_name"

# ── Guard: must be outside a Claude session ──────────────────────────
if [ -n "${CLAUDE_SESSION_ID:-}" ] || [ -n "${CLAUDECODE:-}" ]; then
  echo ""
  echo "ERROR: This test must run OUTSIDE a Claude session."
  echo "Run it from a regular terminal or CI."
  exit 2
fi

# ── Guard: claude CLI must be installed ──────────────────────────────
if ! command -v claude &>/dev/null; then
  echo ""
  echo "ERROR: 'claude' CLI not found."
  echo "Install it first: https://docs.anthropic.com/en/docs/claude-code"
  exit 2
fi

# ── Guard: plugin directory must exist ───────────────────────────────
if [ ! -d "$PLUGIN_DIR" ]; then
  echo ""
  echo "ERROR: Plugin directory not found: $PLUGIN_DIR"
  exit 2
fi

# ── Derive expected commands from commands/ directory ────────────────
expected_commands=()
if [ -d "$PLUGIN_DIR/commands" ]; then
  for file in "$PLUGIN_DIR"/commands/*.md; do
    [ -f "$file" ] || continue
    base="$(basename "$file" .md)"
    expected_commands+=("$plugin_name:$base")
  done
fi

if [ ${#expected_commands[@]} -eq 0 ]; then
  echo ""
  echo "ERROR: No commands found in $PLUGIN_DIR/commands/"
  exit 2
fi

echo "Expected commands: ${#expected_commands[@]}"

# ── Run Claude with the plugin and ask it to list commands ───────────
section "1. Loading Plugin"

echo "  Launching Claude with --plugin-dir to list registered commands..."
echo "  (This may take 10-30 seconds)"

output=$(claude --plugin-dir "$PLUGIN_DIR" -p \
  "List every slash command available that starts with /$plugin_name:. Output only the command names, one per line. No other text." \
  2>&1) || true

if [ -z "$output" ]; then
  echo ""
  echo "ERROR: Claude returned empty output. Plugin may have failed to load."
  echo "Try running manually: claude --plugin-dir $PLUGIN_DIR"
  exit 1
fi

echo ""
echo "  Raw output:"
echo "$output" | sed 's/^/    /'
echo ""

# ── Verify expected commands ─────────────────────────────────────────
section "2. Verifying Commands"

for cmd in "${expected_commands[@]}"; do
  if echo "$output" | grep -qw "$cmd"; then
    pass "$cmd registered"
  else
    fail "$cmd NOT found in output"
  fi
done

# ══════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════
section "Summary"

total=$((pass_count + fail_count))
echo "  Total: $total  Passed: $pass_count  Failed: $fail_count"
echo ""

if [ "$fail_count" -gt 0 ]; then
  printf "  \033[31m%d command(s) failed to register\033[0m\n" "$fail_count"
  echo ""
  exit 1
else
  printf "  \033[32mAll commands registered successfully\033[0m\n"
  echo ""
  exit 0
fi
