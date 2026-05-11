#!/usr/bin/env bash
set -euo pipefail

# flow-resume-breadcrumb.sh — read + write `.flow-phase-state.json` breadcrumb.
#
# Per Q30.6 (memory:292) + Q31.3 stale check (memory:306) + Q31.5 atomic-rename
# write-then-verify (memory:310). Path locked at `docs/plans/.flow-phase-state.json`
# (Q31.4, memory:308).
#
# Subcommands:
#   read [path]      Emit EXISTS/STATUS/LAST_UPDATED/STALE/STALE_REASON to stdout.
#                    `path` defaults to <REPO_ROOT>/docs/plans/.flow-phase-state.json.
#
#   write <path>     Read JSON from stdin, atomic-rename + parse-verify + content-match.
#                    On failure: leave <path> untouched, remove .tmp, exit non-zero.
#
# bash 3.2+ compatible (Q32). python3 3.6+ for JSON parse (no jq).

# Q31.3 stale window in seconds (7 days).
STALE_AGE_SECONDS=$((7 * 24 * 60 * 60))

usage() {
  cat >&2 <<'EOF'
Usage:
  flow-resume-breadcrumb.sh read [path]
  flow-resume-breadcrumb.sh write <path>   (JSON on stdin)
EOF
  exit 2
}

resolve_default_path() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$root" ]; then
    echo "flow-resume-breadcrumb: REPO_ROOT not resolvable via git" >&2
    exit 1
  fi
  echo "$root/docs/plans/.flow-phase-state.json"
}

cmd_read() {
  local path="${1:-}"
  if [ -z "$path" ]; then path="$(resolve_default_path)"; fi

  if [ ! -f "$path" ]; then
    printf 'EXISTS=no\n'
    printf 'STATUS=unknown\n'
    printf 'LAST_UPDATED=\n'
    printf 'STALE=no\n'
    printf 'STALE_REASON=none\n'
    return 0
  fi

  # Parse via python3 (no jq per Q32). Emit STATUS / LAST_UPDATED to caller env-style.
  # Python3 must succeed; malformed JSON is a hard error (caller should re-prompt).
  local parsed
  if ! parsed="$(STALE_AGE_SECONDS="$STALE_AGE_SECONDS" python3 - "$path" <<'PY'
import json, os, sys, datetime
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print(f"PARSE_ERROR={exc}", file=sys.stderr)
    sys.exit(3)

status = data.get("status", "unknown") or "unknown"
last_updated = data.get("last_updated", "") or ""

stale = "no"
stale_reason = "none"
if status == "completed":
    stale = "yes"; stale_reason = "status-completed"
elif status == "abandoned":
    stale = "yes"; stale_reason = "status-abandoned"
elif last_updated:
    try:
        # Accept trailing Z; tolerate timezone-aware ISO 8601.
        iso = last_updated.replace("Z", "+00:00")
        dt = datetime.datetime.fromisoformat(iso)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        now = datetime.datetime.now(datetime.timezone.utc)
        age_seconds = (now - dt).total_seconds()
        if age_seconds > int(os.environ["STALE_AGE_SECONDS"]):
            stale = "yes"; stale_reason = "age"
    except Exception:
        # Unparseable timestamp — treat as fresh; caller may surface a warning.
        pass

print(f"STATUS={status}")
print(f"LAST_UPDATED={last_updated}")
print(f"STALE={stale}")
print(f"STALE_REASON={stale_reason}")
PY
)"; then
    echo "flow-resume-breadcrumb: parse failed for $path" >&2
    exit 3
  fi

  printf 'EXISTS=yes\n'
  printf '%s\n' "$parsed"
}

cmd_write() {
  local path="${1:-}"
  if [ -z "$path" ]; then
    echo "flow-resume-breadcrumb write: <path> required" >&2
    usage
  fi

  local tmp="${path}.tmp"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"

  # Capture stdin into the tmp file.
  cat > "$tmp"

  # Parse-verify before promoting (defends against caller writing malformed JSON).
  if ! python3 - "$tmp" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    json.load(fh)
PY
  then
    rm -f "$tmp"
    echo "flow-resume-breadcrumb: stdin failed JSON parse — $path not updated" >&2
    exit 3
  fi

  # Snapshot tmp content for the post-rename content-match defense.
  local pre
  pre="$(cat "$tmp")"

  # Atomic rename — POSIX-guaranteed on same filesystem.
  mv "$tmp" "$path"

  # Content-match: bytes at $path must equal the parse-verified bytes from $tmp.
  # By transitivity (pre parsed as valid JSON above + pre == post) the post-rename
  # file is still valid JSON, so a separate post-rename `json.load` is redundant.
  # Defends against partial promotion or external tampering between mv and read.
  local post
  post="$(cat "$path")"
  if [ "$pre" != "$post" ]; then
    echo "flow-resume-breadcrumb: content-match failed (pre ≠ post-rename) for $path" >&2
    exit 3
  fi

  printf 'WRITE=ok\nPATH=%s\n' "$path"
}

if [ "$#" -lt 1 ]; then usage; fi

sub="$1"; shift
case "$sub" in
  read)  cmd_read  "$@" ;;
  write) cmd_write "$@" ;;
  *)     usage ;;
esac
