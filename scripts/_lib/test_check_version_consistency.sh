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
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 2; }
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

# --- BC-16293: description parity + cross-plugin URL consistency ---

# G — description differs between plugin.json and marketplace → violation (rc 1)
mkfix "$tmp/descmis" '{"plugins":[{"name":"p","version":"1.0.0","description":"A"}]}' '{"name":"p","version":"1.0.0","description":"B"}'
run "$tmp/descmis"; check "description mismatch fails" 1 "$?"

# H — description matching (non-empty) → clean (rc 0)
mkfix "$tmp/descok" '{"plugins":[{"name":"p","version":"1.0.0","description":"Same"}]}' '{"name":"p","version":"1.0.0","description":"Same"}'
run "$tmp/descok"; check "description match passes" 0 "$?"

# mkfix2 / run2 — two-plugin fixtures for the cross-plugin URL checks
mkfix2() {  # $1=dir $2=marketplace $3=plugin1 $4=plugin2
  mkdir -p "$1"
  printf '%s' "$2" > "$1/marketplace.json"
  printf '%s' "$3" > "$1/p1.json"
  printf '%s' "$4" > "$1/p2.json"
}
run2() { python3 "$LINT" "$1/marketplace.json" "$1/p1.json" "$1/p2.json" >/dev/null 2>&1; }

# I — homepage differs across plugins → violation (rc 1)
mkfix2 "$tmp/hpmis" \
  '{"plugins":[{"name":"a","version":"1.0.0"},{"name":"b","version":"1.0.0"}]}' \
  '{"name":"a","version":"1.0.0","homepage":"https://example/one"}' \
  '{"name":"b","version":"1.0.0","homepage":"https://example/two"}'
run2 "$tmp/hpmis"; check "homepage differs across plugins fails" 1 "$?"

# J — homepage consistent across plugins → clean (rc 0)
mkfix2 "$tmp/hpok" \
  '{"plugins":[{"name":"a","version":"1.0.0"},{"name":"b","version":"1.0.0"}]}' \
  '{"name":"a","version":"1.0.0","homepage":"https://example/same"}' \
  '{"name":"b","version":"1.0.0","homepage":"https://example/same"}'
run2 "$tmp/hpok"; check "homepage consistent across plugins passes" 0 "$?"

# K — repository differs across plugins → violation (rc 1)
mkfix2 "$tmp/rpmis" \
  '{"plugins":[{"name":"a","version":"1.0.0"},{"name":"b","version":"1.0.0"}]}' \
  '{"name":"a","version":"1.0.0","repository":"https://example/one"}' \
  '{"name":"b","version":"1.0.0","repository":"https://example/two"}'
run2 "$tmp/rpmis"; check "repository differs across plugins fails" 1 "$?"

# L — one plugin declares a homepage, the other omits it → clean (rc 0).
# Locks the intended-lenient behavior: only URLs that are PRESENT are compared,
# so an absent field is never treated as a divergent value.
mkfix2 "$tmp/hppartial" \
  '{"plugins":[{"name":"a","version":"1.0.0"},{"name":"b","version":"1.0.0"}]}' \
  '{"name":"a","version":"1.0.0","homepage":"https://example/same"}' \
  '{"name":"b","version":"1.0.0"}'
run2 "$tmp/hppartial"; check "homepage present+absent passes (lenient)" 0 "$?"

# M — repository consistent across plugins → clean (rc 0) [mirrors J for repository]
mkfix2 "$tmp/rpok" \
  '{"plugins":[{"name":"a","version":"1.0.0"},{"name":"b","version":"1.0.0"}]}' \
  '{"name":"a","version":"1.0.0","repository":"https://example/same"}' \
  '{"name":"b","version":"1.0.0","repository":"https://example/same"}'
run2 "$tmp/rpok"; check "repository consistent across plugins passes" 0 "$?"

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
