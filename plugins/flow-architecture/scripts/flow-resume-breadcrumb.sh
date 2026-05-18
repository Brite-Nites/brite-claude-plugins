#!/usr/bin/env bash
set -euo pipefail

# flow-resume-breadcrumb.sh — read + write `.flow-phase-state.json` breadcrumb.
#
# Per Q30.6 (memory:292) + Q31.3 stale check (memory:306) + Q31.5 atomic-rename
# write-then-verify (memory:310). Path locked at `docs/plans/.flow-phase-state.json`
# (Q31.4, memory:308).
#
# Subcommands:
#   read [path]                          Emit EXISTS/STATUS/LAST_UPDATED/STALE/STALE_REASON
#                                        to stdout. `path` defaults to
#                                        <REPO_ROOT>/docs/plans/.flow-phase-state.json.
#
#   write <state-path> <input-path>      Read JSON from <input-path> file, atomic-rename +
#                                        parse-verify + content-match into <state-path>.
#                                        On failure: leave <state-path> untouched, remove
#                                        .tmp, exit non-zero. File-arg only (BC-9027);
#                                        stdin pipe is no longer accepted — pipe patterns
#                                        like `python3 <<'PY' | bash $HELPER write ...`
#                                        trip the workflows security-hook classifier.
#
# bash 3.2+ compatible (Q32). python3 3.6+ for JSON parse (no jq).

# Q31.3 stale window in seconds (7 days).
STALE_AGE_SECONDS=$((7 * 24 * 60 * 60))

usage() {
  cat >&2 <<'EOF'
Usage:
  flow-resume-breadcrumb.sh read [path]
  flow-resume-breadcrumb.sh write <state-path> <input-path>   (JSON read from <input-path>)
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

  # Parse via python3 (no jq per Q32). Conservative read-contract: malformed
  # JSON and unparseable timestamps both emit STALE=yes with a specific
  # STALE_REASON so callers fall through to artifact-driven classification
  # rather than hard-aborting on a single corrupted state file. Exit stays 0
  # for these soft-fail cases; the python heredoc only exits non-zero on
  # genuinely unexpected errors that should propagate.
  local parsed
  parsed="$(STALE_AGE_SECONDS="$STALE_AGE_SECONDS" python3 - "$path" <<'PY'
import json, os, sys, datetime

def sanitize(value):
    # Newlines / carriage returns would break the KEY=VALUE per-line contract.
    return (value or "").replace("\n", " ").replace("\r", " ").strip()

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    # Soft-fail: treat malformed JSON as stale so callers fall through.
    print(f"flow-resume-breadcrumb: parse failed for {path} ({exc})", file=sys.stderr)
    print("STATUS=unknown")
    print("LAST_UPDATED=")
    print("STALE=yes")
    print("STALE_REASON=parse-error")
    sys.exit(0)

status = sanitize(data.get("status", "unknown")) or "unknown"
last_updated = sanitize(data.get("last_updated", ""))

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
        # Unparseable timestamp is conservative-stale per Q31.3 spirit
        # (be cautious about resume); caller falls through to fresh start.
        print(f"flow-resume-breadcrumb: unparseable last_updated for {path}", file=sys.stderr)
        stale = "yes"; stale_reason = "timestamp-unparseable"

print(f"STATUS={status}")
print(f"LAST_UPDATED={last_updated}")
print(f"STALE={stale}")
print(f"STALE_REASON={stale_reason}")
PY
)"

  printf 'EXISTS=yes\n'
  printf '%s\n' "$parsed"
}

cmd_write() {
  local path="${1:-}"
  local input="${2:-}"
  if [ -z "$path" ] || [ -z "$input" ]; then
    echo "flow-resume-breadcrumb write: <state-path> and <input-path> required" >&2
    usage
  fi
  if [ ! -f "$input" ]; then
    echo "flow-resume-breadcrumb: input file not found: $input" >&2
    exit 3
  fi

  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"

  # Use mktemp for symlink-attack safety: a hostile pre-staged
  # `<path>.tmp` symlink to /etc/passwd would be followed by a naive
  # `cp` otherwise. mktemp creates with mode 600 + O_EXCL semantics,
  # picks a unique 6-char suffix, and lives in the same directory as
  # $path so the subsequent `mv` is a same-filesystem (atomic) rename.
  local tmp
  if ! tmp="$(mktemp "${path}.tmp.XXXXXX")"; then
    echo "flow-resume-breadcrumb: mktemp failed for $path" >&2
    exit 3
  fi

  # Plan T3 cleanup contract: every failure path below removes $tmp before
  # exiting. Explicit if-checks keep failure modes auditable (preferred
  # over a trap, which would obscure which step triggered the abort).

  # Copy input → tmp. Use `cat <"$input" >"$tmp"` so the existing mktemp'd
  # file (with secure perms) is preserved as the write target — `cp` would
  # replace it with the source file's perms, and `cp -p` would still follow
  # symlinks at the source. The shell redirect respects the open() on $tmp
  # mktemp already established.
  if ! cat <"$input" >"$tmp"; then
    rm -f "$tmp"
    echo "flow-resume-breadcrumb: input copy failed for $path (input: $input)" >&2
    exit 3
  fi

  # Parse-verify before promoting (caller may have written malformed JSON).
  if ! python3 - "$tmp" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    json.load(fh)
PY
  then
    rm -f "$tmp"
    echo "flow-resume-breadcrumb: input failed JSON parse — $path not updated" >&2
    exit 3
  fi

  # Snapshot tmp content for the post-rename content-match check.
  local pre
  pre="$(cat "$tmp")"

  # Atomic rename — POSIX-guaranteed on same filesystem.
  if ! mv "$tmp" "$path"; then
    rm -f "$tmp"
    echo "flow-resume-breadcrumb: mv failed for $path" >&2
    exit 3
  fi

  # Content-match DETECTS (does not prevent) external tampering between
  # mv and read. By transitivity (pre parsed as valid JSON above + pre == post)
  # the post-rename file is still valid JSON, so a separate post-rename
  # `json.load` is redundant. On mismatch the corrupted file is left in
  # place by design — exit 3 signals the caller to investigate.
  local post
  post="$(cat "$path")"
  if [ "$pre" != "$post" ]; then
    echo "flow-resume-breadcrumb: content-match detected pre ≠ post-rename for $path" >&2
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
