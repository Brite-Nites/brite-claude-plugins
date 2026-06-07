#!/usr/bin/env bash
# BC-12536 (M6) — session-start discoverability lint.
#
# Invariant: the unified intake front door (/workflows:raise-a-ticket) MUST be
# surfaced in the SessionStart "Key commands:" list so a new Claude-Code user
# discovers "where do I report things" without learning a command catalog.
#
# Source of truth: plugins/workflows/hooks/hooks.json — the SessionStart
# `command` hook whose printf echoes "Key commands:" followed by one line per
# command (`/workflows:<cmd> — <description>`). That whole printf is a single
# physical JSON line, so a same-line ordered grep (Key commands: … the command)
# proves the command sits INSIDE the rendered surface, not in some unrelated JSON
# field (e.g. the file-level "description" on line 1).
#
# This lint asserts:
#   SURFACE  — hooks.json carries a SessionStart "Key commands:" surface at all.
#   PRESENT  — /workflows:raise-a-ticket appears within that surface (same-line
#              ordering, so it can't pass on a stray match elsewhere in the JSON).
#   DESCRIBED— the entry carries an em-dash description like its siblings (a bare
#              command with no "— …" would be a half-edit).
#   TARGET   — the command the surface advertises actually exists on disk.
#
# Hand-rolled assertion harness (no bats dep). Bash 3.2 compatible (macOS
# default). Auto-discovered by validate.sh Section 2e; emits RESULT pass=N.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS="$PLUGIN_ROOT/hooks/hooks.json"
CMD_DIR="$PLUGIN_ROOT/commands"

# The command the session-start surface must advertise. The on-disk command file
# is DERIVED from this slug (strip the `/workflows:` prefix, append `.md`) so a
# rename keeps the two in lockstep — a surface advertising a command whose file
# moved should not silently pass TARGET.
CMD='/workflows:raise-a-ticket'
FRONT_DOOR="$CMD_DIR/${CMD#/workflows:}.md"

# CMD is interpolated into ERE patterns below. Escape any regex metacharacters so
# the checks stay literal if the slug is ever renamed to one containing '.', '+',
# '(', '[', etc. — today's kebab slug has none, but the derive-from-slug design
# above invites future renames. Backslash-escaping every non-alphanumeric char is
# a superset of the ERE metacharacter set, and GNU/BSD/ugrep all treat '\<char>'
# as the literal — so this is portable and can't over- or under-match.
CMD_RE=$(printf '%s' "$CMD" | sed 's/[^[:alnum:]_]/\\&/g')

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ── Preconditions ────────────────────────────────────────────────────
[ -f "$HOOKS" ] || { echo "fatal: missing $HOOKS" >&2; exit 2; }

# ── SURFACE: the SessionStart "Key commands:" block exists ───────────
if grep -q 'Key commands:' "$HOOKS"; then
  pass "hooks.json carries a SessionStart 'Key commands:' surface"
else
  fail "hooks.json has no 'Key commands:' surface — the session-start list is gone"
fi

# ── PRESENT: the front door is in that surface (same-line ordering) ──
# The printf is one physical JSON line, so requiring "Key commands:" and the
# command on the SAME line anchors the match to the rendered list. A grep that
# only checked "command appears anywhere in hooks.json" would also pass on the
# file-level "description" field — this one cannot.
if grep -Eq "Key commands:.*${CMD_RE}" "$HOOKS"; then
  pass "${CMD} appears within the Key-commands surface"
else
  fail "${CMD} is NOT in the session-start Key-commands list (BC-12536 AC)"
fi

# ── DESCRIBED: the entry carries an em-dash description like its siblings ─
# Siblings render as "/workflows:<cmd> — <description>". Assert the command is
# followed by a space, an em-dash, a space, then a describing character — a bare
# command with no description would be a half-edit. ANCHORED to "Key commands:"
# on the same physical line (like PRESENT) so a stray describing mention
# elsewhere in the JSON (e.g. the file-level "description" field) can't mask a
# genuine bare-command half-edit in the rendered surface.
if grep -Eq "Key commands:.*${CMD_RE} — [A-Za-z]" "$HOOKS"; then
  pass "${CMD} entry carries an em-dash description"
else
  fail "${CMD} has no '— <description>' (matches the sibling format)"
fi

# ── TARGET: the advertised command actually exists on disk ───────────
if [ -f "$FRONT_DOOR" ]; then
  pass "advertised command file exists ($(basename "$FRONT_DOOR"))"
else
  fail "advertised command file missing: $FRONT_DOOR"
fi

# ── Result ───────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT pass=$PASS fail=0"
  exit 0
else
  echo "RESULT pass=$PASS fail=$FAIL"
  exit 1
fi
