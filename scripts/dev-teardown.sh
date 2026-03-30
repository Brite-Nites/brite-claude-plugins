#!/usr/bin/env bash
set -euo pipefail

# ── Dev Teardown — Remove dev symlinks ───────────────────────────────
# Reverses dev-setup.sh: removes the symlink and restores the original
# installed marketplace clone from backup.
# ─────────────────────────────────────────────────────────────────────

STATE_FILE="$HOME/.brite-plugins/.dev-state"

info()  { printf "\033[34mINFO\033[0m  %s\n" "$1"; }
ok()    { printf "\033[32m  OK\033[0m  %s\n" "$1"; }
err()   { printf "\033[31mERR\033[0m  %s\n" "$1" >&2; }

# ── Load state ───────────────────────────────────────────────────────
if [ ! -f "$STATE_FILE" ]; then
  err "No dev state found at $STATE_FILE"
  err "Dev mode does not appear to be active."
  exit 1
fi

# shellcheck source=/dev/null
source "$STATE_FILE"

# ── Validate state ───────────────────────────────────────────────────
if [ -z "${INSTALL_PATH:-}" ] || [ -z "${BACKUP_PATH:-}" ]; then
  err "Corrupted state file — missing INSTALL_PATH or BACKUP_PATH"
  exit 1
fi

# ── Check current state ─────────────────────────────────────────────
if [ ! -L "$INSTALL_PATH" ]; then
  if [ -d "$INSTALL_PATH" ]; then
    err "$INSTALL_PATH is a regular directory, not a symlink"
    err "Dev mode may have already been cleaned up."

    # Clean up backup if it exists and paths match
    if [ -d "$BACKUP_PATH" ]; then
      err "Backup still exists at $BACKUP_PATH — remove manually if not needed."
    fi
    rm -f "$STATE_FILE"
    exit 1
  else
    err "$INSTALL_PATH does not exist"
    # Try to restore from backup anyway
    if [ -d "$BACKUP_PATH" ]; then
      info "Restoring from backup"
      mv "$BACKUP_PATH" "$INSTALL_PATH"
      rm -f "$STATE_FILE"
      ok "Restored from backup"
      exit 0
    fi
    exit 1
  fi
fi

if [ ! -d "$BACKUP_PATH" ]; then
  err "Backup not found at $BACKUP_PATH"
  err "Cannot restore — you may need to reinstall the plugin."
  exit 1
fi

# ── Remove symlink & restore ────────────────────────────────────────
info "Removing symlink at $INSTALL_PATH"
rm "$INSTALL_PATH"

info "Restoring backup from $BACKUP_PATH"
mv "$BACKUP_PATH" "$INSTALL_PATH"

rm -f "$STATE_FILE"

ok "Dev mode disabled — original installation restored"
echo ""
echo "  Restart Claude Code to pick up the restored plugin."
