#!/usr/bin/env bash
# Self-test for check_version_consistency.py (BC-16373). Synthetic fixtures lock
# the matching / empty / missing / no-entry / mismatch cases + rc discipline.
# Emits `RESULT pass=N fail=M`; exits nonzero iff any assertion failed.
# bash 3.2-safe (no mapfile / no array expansion).
set -u

LINT="${1:-}"
if [ -z "$LINT" ]; then
  LINT="$(cd "$(dirname "$0")" && pwd)/check_version_consistency.py"
fi

pass=0
fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# $1 = label, $2 = expected rc, $3 = actual rc
check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s (expected rc=%s got rc=%s)\n' "$1" "$2" "$3" >&2
  fi
}

# $1 = dir, $2 = marketplace.json content, $3 = plugin.json content
mkfix() {
  mkdir -p "$1"
  printf '%s' "$2" > "$1/marketplace.json"
  printf '%s' "$3" > "$1/plugin.json"
}

run() {  # $1 = dir  -> runs the checker, sets rc in $?
  python3 "$LINT" "$1/marketplace.json" "$1/plugin.json" >/dev/null 2>&1
}

# A — matching versions → clean (rc 0)
mkfix "$tmp/ok" '{"plugins":[{"name":"p","version":"1.0.0"}]}' '{"name":"p","version":"1.0.0"}'
run "$tmp/ok"; check "matching versions pass" 0 "$?"

# B — plugin.json empty version → violation (rc 1)  [the BC-16373 gap]
mkfix "$tmp/empty" '{"plugins":[{"name":"p","version":"1.0.0"}]}' '{"name":"p","version":""}'
run "$tmp/empty"; check "plugin.json empty version fails" 1 "$?"

# C — plugin.json missing version key → violation (rc 1)
mkfix "$tmp/missing" '{"plugins":[{"name":"p","version":"1.0.0"}]}' '{"name":"p"}'
run "$tmp/missing"; check "plugin.json missing version fails" 1 "$?"

# D — marketplace entry missing version → violation (rc 1)
mkfix "$tmp/mpmiss" '{"plugins":[{"name":"p"}]}' '{"name":"p","version":"1.0.0"}'
run "$tmp/mpmiss"; check "marketplace missing version fails" 1 "$?"

# E — version mismatch → violation (rc 1)
mkfix "$tmp/mis" '{"plugins":[{"name":"p","version":"2.0.0"}]}' '{"name":"p","version":"1.0.0"}'
run "$tmp/mis"; check "version mismatch fails" 1 "$?"

# F — plugin.json with no marketplace entry → violation (rc 1)
mkfix "$tmp/noentry" '{"plugins":[{"name":"other","version":"1.0.0"}]}' '{"name":"p","version":"1.0.0"}'
run "$tmp/noentry"; check "no marketplace entry fails" 1 "$?"

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
