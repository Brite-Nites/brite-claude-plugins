#!/usr/bin/env bash
# Non-blocking SessionStart nudge: warn when brite-core is not enabled.
#
# brite-core (Layer 2) centralizes brain-first guidance + the shared security/quality
# guardrails for all Brite domain plugins. Per design Q7, v0.1 treats it as *strongly
# recommended*; v0.2 (BC-11757) upgrades this to a PreToolUse block. This script only
# prints a one-time startup nudge and always exits 0 — it never blocks work.
#
# Usage: core-enablement-warning.sh <plugin-name>
set -u

PLUGIN="${1:-Brite}"
CORE_KEY='"brite-core@brite-claude-plugins"'

# Resolve the effective enablement by checking settings files most-specific first
# (local project > project > user). The first file that mentions the key decides;
# if no file mentions it, treat brite-core as not enabled. Detection is a line-
# oriented grep (not a JSON parse) — matches how Claude Code writes enabledPlugins
# (key:value on one line) and the repo's other grep-based settings probes. A
# pretty-printer that split the value onto its own line would fail *open* to a
# spurious (still non-blocking) nudge, never a false silence.
core_state=""
for f in \
  "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/settings.local.json" \
  "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/settings.json" \
  "${HOME:-}/.claude/settings.json"; do
  [ -r "$f" ] || continue
  v=$(grep -oE "${CORE_KEY}"'[[:space:]]*:[[:space:]]*(true|false)' "$f" 2>/dev/null \
      | grep -oE '(true|false)$' | head -1)
  if [ -n "$v" ]; then
    core_state="$v"
    break
  fi
done

if [ "$core_state" != "true" ]; then
  printf '⚠️  brite-core is not enabled. The %s plugin relies on brite-core (Layer 2) for brain-first guidance and the shared security/quality guardrails. Enable it — strongly recommended:\n    /plugin install brite-core@brite-claude-plugins\nWork continues without it. See plugins/core/README.md.\n' "$PLUGIN"
fi

exit 0
