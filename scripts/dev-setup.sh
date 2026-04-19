#!/usr/bin/env bash
set -euo pipefail

# ── Dev Setup — Symlink plugin for local development ─────────────────
# Replaces the installed marketplace clone with a symlink to this dev
# repo so edits are immediately reflected in Claude Code sessions.
# ─────────────────────────────────────────────────────────────────────

DEV_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces"
STATE_FILE="$HOME/.brite-plugins/.dev-state"

info()  { printf "\033[34mINFO\033[0m  %s\n" "$1"; }
ok()    { printf "\033[32m  OK\033[0m  %s\n" "$1"; }
err()   { printf "\033[31mERR\033[0m  %s\n" "$1" >&2; }

# ── Find the installed marketplace clone ─────────────────────────────
find_install_path() {
  # 1. Try .brite-plugins/.repo-root (a shortcut written by the SessionStart
  #    telemetry hook). Only trust it if it points inside $MARKETPLACE_DIR —
  #    otherwise `.repo-root` may hold a dev-repo path (e.g. when Claude Code
  #    loaded the plugin from a source outside the marketplace) and returning
  #    that here would cause the subsequent `mv` to move the user's dev repo.
  local repo_root_file="$HOME/.brite-plugins/.repo-root"
  if [ -f "$repo_root_file" ]; then
    local path
    path="$(cat "$repo_root_file")"
    case "$path" in
      "$MARKETPLACE_DIR"/*)
        if [ -d "$path" ] || [ -L "$path" ]; then
          echo "$path"
          return 0
        fi
        ;;
    esac
  fi

  # 2. Scan marketplace dir for matching plugin name
  local dev_name
  dev_name=$(DEV_ROOT="$DEV_ROOT" python3 -c "
import json, os
mp = os.path.join(os.environ['DEV_ROOT'], '.claude-plugin', 'marketplace.json')
with open(mp) as f:
    print(json.load(f).get('name', ''))
" 2>/dev/null) || true

  if [ -z "$dev_name" ]; then
    return 1
  fi

  for dir in "$MARKETPLACE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local mp_file="$dir.claude-plugin/marketplace.json"
    [ -f "$mp_file" ] || continue
    local mp_name
    mp_name=$(MP_FILE="$mp_file" python3 -c "
import json, os
with open(os.environ['MP_FILE']) as f:
    print(json.load(f).get('name', ''))
" 2>/dev/null) || continue
    if [ "$mp_name" = "$dev_name" ]; then
      echo "${dir%/}"
      return 0
    fi
  done

  return 1
}

# ── Pre-checks ───────────────────────────────────────────────────────
if [ ! -f "$DEV_ROOT/.claude-plugin/marketplace.json" ]; then
  err "Not a plugin repo — .claude-plugin/marketplace.json not found"
  exit 1
fi

INSTALL_PATH=$(find_install_path) || {
  err "Could not find installed marketplace clone"
  err "Is the plugin installed via Claude Code?"
  exit 1
}

# ── Already in dev mode? ─────────────────────────────────────────────
if [ -L "$INSTALL_PATH" ]; then
  target=$(readlink "$INSTALL_PATH")
  if [ "$target" = "$DEV_ROOT" ]; then
    ok "Already in dev mode ($INSTALL_PATH -> $DEV_ROOT)"
    exit 0
  else
    err "$INSTALL_PATH is a symlink to $target (not this repo)"
    err "Run dev-teardown.sh first, then retry"
    exit 1
  fi
fi

# ── Back up & symlink ────────────────────────────────────────────────
BACKUP_PATH="${INSTALL_PATH}.dev-backup"

if [ -d "$BACKUP_PATH" ]; then
  err "Backup already exists at $BACKUP_PATH"
  err "A previous dev-setup may not have been cleaned up. Remove the backup manually or run dev-teardown.sh."
  exit 1
fi

info "Backing up $INSTALL_PATH"
mv "$INSTALL_PATH" "$BACKUP_PATH"

info "Creating symlink: $INSTALL_PATH -> $DEV_ROOT"
ln -s "$DEV_ROOT" "$INSTALL_PATH"

# ── Save state for teardown ──────────────────────────────────────────
mkdir -p "$(dirname "$STATE_FILE")"
cat > "$STATE_FILE" << EOF
INSTALL_PATH="$INSTALL_PATH"
BACKUP_PATH="$BACKUP_PATH"
DEV_ROOT="$DEV_ROOT"
EOF

ok "Dev mode enabled"
echo ""
echo "  Installed at: $INSTALL_PATH"
echo "  Points to:    $DEV_ROOT"
echo "  Backup at:    $BACKUP_PATH"
echo ""
echo "  Edits in this repo are now live. Restart Claude Code to pick up changes."
echo "  Run 'scripts/dev-teardown.sh' to restore the original installation."
