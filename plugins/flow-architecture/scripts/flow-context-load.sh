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
# Single while/read pass over SHAPE_OUT — same builtin-loop pattern used
# for CONFIG_OUT below. Replaces 4 sed-pipeline subshells.
SHAPE_OUT="$("$SCRIPT_DIR/flow-detect-fda-shape.sh" "$REPO_ROOT")"
INTENT_EXISTS=""; INVENTORY_EXISTS=""; FLOWS_DIR_EXISTS=""; BREADCRUMB_EXISTS=""
while IFS='=' read -r _key _val; do
  case "$_key" in
    INTENT_EXISTS)     INTENT_EXISTS="$_val" ;;
    INVENTORY_EXISTS)  INVENTORY_EXISTS="$_val" ;;
    FLOWS_DIR_EXISTS)  FLOWS_DIR_EXISTS="$_val" ;;
    BREADCRUMB_EXISTS) BREADCRUMB_EXISTS="$_val" ;;
  esac
done <<< "$SHAPE_OUT"

# ── Mode classification (delegates to flow-detect-mode.sh) ───────────
# Pass already-parsed shape signals as individual _FLOW_SHAPE_* env vars
# so the child skips both the `find` walk AND the sed re-parse. Also
# pass FLOW_SHAPE_CACHE for back-compat (older child binaries still
# parse the bulk blob).
MODE="$(_FLOW_SHAPE_INTENT_EXISTS="$INTENT_EXISTS" \
        _FLOW_SHAPE_INVENTORY_EXISTS="$INVENTORY_EXISTS" \
        _FLOW_SHAPE_FLOWS_DIR_EXISTS="$FLOWS_DIR_EXISTS" \
        _FLOW_SHAPE_BREADCRUMB_EXISTS="$BREADCRUMB_EXISTS" \
        FLOW_SHAPE_CACHE="$SHAPE_OUT" \
        "$SCRIPT_DIR/flow-detect-mode.sh" "$REPO_ROOT")"

# ── Linear project from .flow/config.json (Q36.6) ────────────────────
# Soft-fail on parse error: emit empty values + stderr warning + exit 0.
# This is symmetric with the breadcrumb-read soft-fail contract (a
# corrupted config doesn't brick preamble emission; the orchestrator can
# re-prompt). Newlines / CR in string values are sanitized so a hostile
# or corrupted JSON value can't break the 10-line preamble contract.
LINEAR_PROJECT_ID=""
LINEAR_PROJECT_NAME=""
CONFIG_PATH="$REPO_ROOT/.flow/config.json"
if [ -f "$CONFIG_PATH" ]; then
  CONFIG_OUT="$(python3 - "$CONFIG_PATH" <<'PY' || true
import json, sys

def sanitize(value):
    # Newlines / CR would break the KEY=VALUE per-line contract downstream.
    return (value or "").replace("\n", " ").replace("\r", " ").strip()

try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print(f"flow-context-load: failed to parse {sys.argv[1]} ({exc}); "
          "LINEAR_PROJECT_* will be empty", file=sys.stderr)
    sys.exit(0)

print(f"LINEAR_PROJECT_ID={sanitize(data.get('linear_project_id'))}")
print(f"LINEAR_PROJECT_NAME={sanitize(data.get('linear_project_name'))}")
PY
)"
  # Parse the 2-line CONFIG_OUT in a single while/read pass — folds the
  # prior 4 sed-pipeline subshells into one bash builtin loop.
  while IFS='=' read -r _key _val; do
    case "$_key" in
      LINEAR_PROJECT_ID)   LINEAR_PROJECT_ID="$_val" ;;
      LINEAR_PROJECT_NAME) LINEAR_PROJECT_NAME="$_val" ;;
    esac
  done <<< "$CONFIG_OUT"
fi

# ── gh auth (soft per Q32) ───────────────────────────────────────────
# `gh auth status` hits the OS keychain and (depending on version) issues a
# token-validity ping — ~300-400ms wall-clock per call. The orchestrator may
# cache the result for the session via FLOW_GH_AUTH_CACHE (mirrors
# FLOW_SHAPE_CACHE). Standalone callers fall back to a direct probe.
if [ -n "${FLOW_GH_AUTH_CACHE:-}" ]; then
  case "$FLOW_GH_AUTH_CACHE" in
    yes|no) GH_AUTH="$FLOW_GH_AUTH_CACHE" ;;
    *) echo "flow-context-load: FLOW_GH_AUTH_CACHE='$FLOW_GH_AUTH_CACHE' not in {yes,no}; re-probing" >&2
       FLOW_GH_AUTH_CACHE="" ;;
  esac
fi
if [ -z "${GH_AUTH:-}" ]; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    GH_AUTH="yes"
  else
    GH_AUTH="no"
  fi
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
