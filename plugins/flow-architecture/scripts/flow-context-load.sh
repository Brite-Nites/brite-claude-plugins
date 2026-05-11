#!/usr/bin/env bash
set -euo pipefail

# flow-context-load.sh — emit the Q12.5 structured preamble (gstack pattern).
#
# Per Q30.6 (memory:292) — invokes the 3 sibling helpers (fda-shape, mode,
# resume-breadcrumb) and prints the 10-field preamble defined in Q12.5
# (memory:76). Downstream sub-skills read this rather than re-running discovery.
#
# Usage:
#   flow-context-load.sh [REPO_ROOT]
#   LINEAR_ISSUE_COUNT=42 flow-context-load.sh   # forwards to flow-detect-mode.sh
#
# Output (KEY=VALUE lines on stdout — exactly 10):
#   MODE                  greenfield|retrofit|incremental-add|resume
#   LINEAR_PROJECT_ID     UUID from .flow/config.json (empty when config absent)
#   LINEAR_PROJECT_NAME   string from .flow/config.json (empty when config absent)
#   REPO_ROOT             absolute path
#   INTENT_EXISTS         yes|no
#   INVENTORY_EXISTS      yes|no
#   FLOWS_DIR_EXISTS      yes|no
#   BREADCRUMB_EXISTS     yes|no
#   GH_AUTH               yes|no    (`gh auth status` exit code 0 → yes)
#   LINEAR_MCP            unknown   (sentinel — orchestrator probes via list_projects
#                                   and replaces this line in its own context)
#
# bash 3.2+ compatible (Q32). python3 3.6+ for `.flow/config.json` parse.

REPO_ROOT="${1:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  echo "flow-context-load: REPO_ROOT not resolvable (argv[1] or git)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── FDA-shape signals ────────────────────────────────────────────────
SHAPE_OUT="$("$SCRIPT_DIR/flow-detect-fda-shape.sh" "$REPO_ROOT")"
INTENT_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^INTENT_EXISTS=//p')"
INVENTORY_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^INVENTORY_EXISTS=//p')"
FLOWS_DIR_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^FLOWS_DIR_EXISTS=//p')"
BREADCRUMB_EXISTS="$(printf '%s\n' "$SHAPE_OUT" | sed -n 's/^BREADCRUMB_EXISTS=//p')"

# ── Mode classification (delegates to flow-detect-mode.sh) ───────────
# Pass shape signals via FLOW_SHAPE_CACHE so the child doesn't re-walk
# docs/product/{flows,journeys}; saves one `find` traversal per preamble.
MODE="$(FLOW_SHAPE_CACHE="$SHAPE_OUT" "$SCRIPT_DIR/flow-detect-mode.sh" "$REPO_ROOT")"

# ── Linear project from .flow/config.json (Q36.6) ────────────────────
LINEAR_PROJECT_ID=""
LINEAR_PROJECT_NAME=""
CONFIG_PATH="$REPO_ROOT/.flow/config.json"
if [ -f "$CONFIG_PATH" ]; then
  CONFIG_OUT="$(python3 - "$CONFIG_PATH" <<'PY' || true
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(0)
print(f"LINEAR_PROJECT_ID={data.get('linear_project_id', '') or ''}")
print(f"LINEAR_PROJECT_NAME={data.get('linear_project_name', '') or ''}")
PY
)"
  LINEAR_PROJECT_ID="$(printf '%s\n' "$CONFIG_OUT" | sed -n 's/^LINEAR_PROJECT_ID=//p')"
  LINEAR_PROJECT_NAME="$(printf '%s\n' "$CONFIG_OUT" | sed -n 's/^LINEAR_PROJECT_NAME=//p')"
fi

# ── gh auth (soft per Q32) ───────────────────────────────────────────
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  GH_AUTH="yes"
else
  GH_AUTH="no"
fi

# ── LINEAR_MCP sentinel ──────────────────────────────────────────────
# Bash cannot probe MCP tooling; the orchestrator (LLM) calls
# `mcp__plugin_workflows_linear-server__list_projects` (limit:1) per Q12.1 and
# updates this line in its own context. Sentinel `unknown` makes the hand-off
# explicit so a downstream consumer never silently treats it as `yes`.
LINEAR_MCP="unknown"

# ── Emit the Q12.5 preamble (10 fields, fixed order) ─────────────────
printf 'MODE=%s\n'                 "$MODE"
printf 'LINEAR_PROJECT_ID=%s\n'    "$LINEAR_PROJECT_ID"
printf 'LINEAR_PROJECT_NAME=%s\n'  "$LINEAR_PROJECT_NAME"
printf 'REPO_ROOT=%s\n'            "$REPO_ROOT"
printf 'INTENT_EXISTS=%s\n'        "$INTENT_EXISTS"
printf 'INVENTORY_EXISTS=%s\n'     "$INVENTORY_EXISTS"
printf 'FLOWS_DIR_EXISTS=%s\n'     "$FLOWS_DIR_EXISTS"
printf 'BREADCRUMB_EXISTS=%s\n'    "$BREADCRUMB_EXISTS"
printf 'GH_AUTH=%s\n'              "$GH_AUTH"
printf 'LINEAR_MCP=%s\n'           "$LINEAR_MCP"
