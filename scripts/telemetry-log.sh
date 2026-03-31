#!/usr/bin/env bash
# ── Brite Plugin Telemetry Logger ──────────────────────────────────
# Appends JSONL events to ~/.brite-plugins/telemetry/events.jsonl.
# Handles crash recovery via pending markers.
#
# Usage:
#   telemetry-log.sh session-start          Log session start, generate session ID
#   telemetry-log.sh start <command>        Create pending marker + log command_start
#   telemetry-log.sh end <command> <outcome> Finalize pending marker + log command_end
#   telemetry-log.sh finalize-stale         Clean up orphaned pending markers
#
# Safety: NEVER exits non-zero. Telemetry must not break the user's workflow.
# ───────────────────────────────────────────────────────────────────

set -uo pipefail
# No -e: we trap errors instead of exiting

# Global safety net — if anything goes wrong, exit cleanly
trap 'exit 0' ERR

TELEMETRY_DIR="$HOME/.brite-plugins/telemetry"
EVENTS_FILE="$TELEMETRY_DIR/events.jsonl"
SESSION_FILE="$TELEMETRY_DIR/.session"
REPO_ROOT_FILE="$HOME/.brite-plugins/.repo-root"

# Cached values — computed once in main(), reused across log_event calls.
# Eliminates repeated subprocess forks for os/version on every event.
_CACHED_OS=""
_CACHED_VERSION=""

# ── Helpers ────────────────────────────────────────────────────────

json_safe() {
  # Escape quotes and backslashes for safe JSON embedding, truncate to 200 chars.
  # Uses bash builtins only — no subprocess forks.
  local input="${1:-}"
  input="${input//\\/\\\\}"   # Escape backslashes first (order matters)
  input="${input//\"/\\\"}"   # Escape double quotes
  printf '%s' "${input:0:200}"
}

format_json_string() {
  # Format a value as a JSON string field: quoted if non-empty, null otherwise.
  local value="${1:-}"
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    printf '"%s"' "$value"
  else
    printf 'null'
  fi
}

ensure_dirs() {
  (umask 077; mkdir -p "$TELEMETRY_DIR")
  chmod 700 "$TELEMETRY_DIR" 2>/dev/null || true
}

read_session_id() {
  cat "$SESSION_FILE" 2>/dev/null || echo "unknown"
}

generate_session_id() {
  echo "$$-$(date +%s)"
}

read_version() {
  # Read plugin version from the primary (workflows) plugin.json. Called once at startup, cached.
  local repo_root=""
  if [ -f "$REPO_ROOT_FILE" ]; then
    repo_root="$(cat "$REPO_ROOT_FILE" 2>/dev/null)"
  fi
  if [ -z "$repo_root" ]; then
    echo "unknown"
    return
  fi
  # Use workflows as the canonical version source for telemetry.
  # Falls back to first discovered plugin if workflows is missing.
  local plugin_json="$repo_root/plugins/workflows/.claude-plugin/plugin.json"
  if [ ! -f "$plugin_json" ]; then
    for candidate in "$repo_root"/plugins/*/.claude-plugin/plugin.json; do
      if [ -f "$candidate" ]; then
        plugin_json="$candidate"
        break
      fi
    done
  fi
  if [ -f "$plugin_json" ]; then
    grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$plugin_json" 2>/dev/null \
      | head -1 \
      | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//;s/"//' \
      || echo "unknown"
  else
    echo "unknown"
  fi
}

get_os() {
  uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown"
}

get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown"
}

log_event() {
  # Append a JSONL line to events.jsonl
  # Args: event_type command [duration_s] [outcome] [error_class] [override_session_id]
  local event_type="${1:-unknown}"
  local command="${2:-}"
  local duration_s="${3:-null}"
  local outcome="${4:-null}"
  local error_class="${5:-null}"
  local override_session_id="${6:-}"

  local ts
  ts="$(get_timestamp)"
  local session_id
  session_id="${override_session_id:-$(read_session_id)}"

  # Use cached os/version (set once in main) — avoids repeated subprocess forks
  local version="${_CACHED_VERSION:-unknown}"
  local os="${_CACHED_OS:-unknown}"

  # Sanitize all string fields with bash builtins
  event_type="$(json_safe "$event_type")"
  command="$(json_safe "$command")"
  outcome="$(json_safe "$outcome")"
  error_class="$(json_safe "$error_class")"
  session_id="$(json_safe "$session_id")"
  version="$(json_safe "$version")"

  # Format nullable fields
  local duration_field="null"
  if [ "$duration_s" != "null" ] && [ -n "$duration_s" ]; then
    duration_field="$duration_s"
  fi

  local outcome_field
  outcome_field="$(format_json_string "$outcome")"
  local error_field
  error_field="$(format_json_string "$error_class")"
  local command_field
  command_field="$(format_json_string "$command")"

  ensure_dirs
  printf '{"v":1,"ts":"%s","event_type":"%s","command":%s,"session_id":"%s","brite_version":"%s","os":"%s","duration_s":%s,"outcome":%s,"error_class":%s}\n' \
    "$ts" "$event_type" "$command_field" "$session_id" "$version" "$os" \
    "$duration_field" "$outcome_field" "$error_field" \
    >> "$EVENTS_FILE"
}

# ── Pending Markers ────────────────────────────────────────────────
# Each command_start creates a .pending-<session_id> file containing
# the start timestamp and command name. On command_end, we read the
# marker, compute duration, and log the event. If the process crashes,
# the next session finalizes stale markers as outcome="unknown".

create_pending() {
  local command="${1:-}"
  local ts
  ts="$(date +%s)"
  local session_id
  session_id="$(read_session_id)"
  ensure_dirs
  printf '%s\n%s\n' "$ts" "$command" > "$TELEMETRY_DIR/.pending-$session_id"
}

finalize_pending() {
  local command="${1:-}"
  local outcome="${2:-success}"
  local error_class="${3:-}"
  local session_id
  session_id="$(read_session_id)"
  local pending_file="$TELEMETRY_DIR/.pending-$session_id"

  if [ ! -f "$pending_file" ]; then
    # No pending marker — log without duration
    log_event "command_end" "$command" "null" "$outcome" "$error_class"
    return
  fi

  local start_ts
  start_ts="$(head -1 "$pending_file" 2>/dev/null || echo "0")"
  local end_ts
  end_ts="$(date +%s)"
  local duration_s=$((end_ts - start_ts))

  log_event "command_end" "$command" "$duration_s" "$outcome" "$error_class"
  rm -f "$pending_file"
}

finalize_stale() {
  # Finalize pending markers from previous sessions as outcome="unknown".
  # Skip the current session's marker to avoid race conditions.
  local current_session
  current_session="$(read_session_id)"

  ensure_dirs
  for pending_file in "$TELEMETRY_DIR"/.pending-*; do
    [ -f "$pending_file" ] || continue

    # Extract session ID from filename
    local marker_session="${pending_file##*.pending-}"

    # Skip own session
    if [ "$marker_session" = "$current_session" ]; then
      continue
    fi

    # Read command from marker
    local stale_command=""
    stale_command="$(sed -n '2p' "$pending_file" 2>/dev/null || echo "")"

    # Read start time for duration
    local start_ts
    start_ts="$(head -1 "$pending_file" 2>/dev/null || echo "0")"
    local end_ts
    end_ts="$(date +%s)"
    local duration_s=$((end_ts - start_ts))

    # Log as unknown outcome, passing stale session ID directly (no file mutation)
    log_event "command_end" "$stale_command" "$duration_s" "unknown" "session_terminated" "$marker_session"

    rm -f "$pending_file"
  done
}

# ── Actions ────────────────────────────────────────────────────────

action_session_start() {
  ensure_dirs
  local session_id
  session_id="$(generate_session_id)"
  printf '%s\n' "$session_id" > "$SESSION_FILE"
  log_event "session_start" "" "null" "null" ""
}

action_start() {
  local command="${1:-}"
  if [ -z "$command" ]; then
    exit 0
  fi
  log_event "command_start" "$command" "null" "null" ""
  create_pending "$command"
}

action_end() {
  local command="${1:-}"
  local outcome="${2:-success}"
  local error_class="${3:-}"
  if [ -z "$command" ]; then
    exit 0
  fi
  finalize_pending "$command" "$outcome" "$error_class"
}

# ── Main ───────────────────────────────────────────────────────────

main() {
  # Cache constant values once — avoids repeated subprocess forks in log_event
  _CACHED_OS="$(get_os)"
  _CACHED_VERSION="$(read_version)"

  local action="${1:-}"
  shift 2>/dev/null || true

  case "$action" in
    session-start)
      action_session_start
      ;;
    start)
      action_start "$@"
      ;;
    end)
      action_end "$@"
      ;;
    finalize-stale)
      finalize_stale
      ;;
    *)
      # Unknown action — exit silently
      ;;
  esac
}

main "$@"
exit 0
