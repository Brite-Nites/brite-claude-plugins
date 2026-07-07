#!/usr/bin/env bash
# Self-test for lint_readme_plugin_coverage.py (BC-16384). Synthetic fixtures lock
# the present / absent / empty-name / unreadable cases + rc discipline.
# Emits `RESULT pass=N fail=M`; exits nonzero iff any assertion failed.
# bash 3.2-safe (no mapfile / no array expansion).
set -u

LINT="${1:-}"
if [ -z "$LINT" ]; then
  LINT="$(cd "$(dirname "$0")" && pwd)/lint_readme_plugin_coverage.py"
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

# $1 = dir, $2 = marketplace.json content, $3 = README.md content
mkfix() {
  mkdir -p "$1"
  printf '%s' "$2" > "$1/marketplace.json"
  printf '%s' "$3" > "$1/README.md"
}

run() { python3 "$LINT" "$1/marketplace.json" "$1/README.md" >/dev/null 2>&1; }

# A — every registered plugin appears in README → clean (rc 0)
mkfix "$tmp/ok" \
  '{"plugins":[{"name":"workflows"},{"name":"brite-core"}]}' \
  '# Repo
Plugins: `workflows` and `brite-core`.'
run "$tmp/ok"; check "all plugins present passes" 0 "$?"

# B — a registered plugin missing from README → violation (rc 1), names it
mkfix "$tmp/absent" \
  '{"plugins":[{"name":"workflows"},{"name":"brite-core"}]}' \
  '# Repo
Plugins: `workflows`.'
run "$tmp/absent"; check "absent plugin fails" 1 "$?"
# Failure message names the missing plugin
if python3 "$LINT" "$tmp/absent/marketplace.json" "$tmp/absent/README.md" 2>&1 | grep -q "brite-core"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "FAIL: absent-plugin message should name brite-core" >&2
fi

# C — marketplace entry with empty name → violation (rc 1)
mkfix "$tmp/empty" \
  '{"plugins":[{"name":""}]}' \
  '# Repo'
run "$tmp/empty"; check "empty plugin name fails" 1 "$?"

# D — marketplace.json unreadable → violation (rc 1), not a silent skip
mkdir -p "$tmp/nomp"; printf '%s' '# Repo `workflows`' > "$tmp/nomp/README.md"
python3 "$LINT" "$tmp/nomp/marketplace.json" "$tmp/nomp/README.md" >/dev/null 2>&1
check "missing marketplace.json fails" 1 "$?"

# E — README.md unreadable → violation (rc 1), not a silent skip
mkdir -p "$tmp/nordm"; printf '%s' '{"plugins":[{"name":"workflows"}]}' > "$tmp/nordm/marketplace.json"
python3 "$LINT" "$tmp/nordm/marketplace.json" "$tmp/nordm/README.md" >/dev/null 2>&1
check "missing README.md fails" 1 "$?"

# F — name appears only as BARE prose (not backtick-wrapped) → violation (rc 1).
# Locks the anchored-match fix: a common-word plugin name occurring in unrelated
# prose must NOT satisfy coverage, otherwise real drift stays green (review P2).
mkfix "$tmp/bareprose" \
  '{"plugins":[{"name":"marketing"}]}' \
  '# Repo
Domain plugins (marketing, engineering, design).'
run "$tmp/bareprose"; check "bare-prose name (no backticks) fails" 1 "$?"

# G — marketplace registers no plugins → violation (rc 1), not a vacuous pass
mkfix "$tmp/noplugins" '{"plugins":[]}' '# Repo'
run "$tmp/noplugins"; check "empty marketplace fails" 1 "$?"

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
