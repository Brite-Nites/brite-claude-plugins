#!/usr/bin/env bash
# Unit / contract suite for plugins/marketing/scripts/build_deck_template.py
# (BC-12975 follow-on — the per-vertical intro-deck template generator).
#
# build_deck_template.py is the PURE, stdlib-only, deterministic generator that
# resolves a vertical's personas/offers/posture (canonicals) + brand tokens
# (britebase-tokens.json) into that vertical's standard intro-deck template. This
# suite drives it directly: the resolved fields land, the three rep blanks survive
# literally, the posture guardrail is present, an unknown slug hard-fails, internal
# targeting data never leaks, the output is deterministic (no timestamps), and the
# committed municipalities pilot matches a fresh regenerate (--check).
#
# Usage:
#   bash plugins/marketing/scripts/test_build_deck_template.sh
#   bash plugins/marketing/scripts/test_build_deck_template.sh /path/to/build_deck_template.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the unknown-vertical scenario.

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_deck_template.py}"
BUILDER="$(cd "$(dirname "$BUILDER")" 2>/dev/null && pwd)/$(basename "$BUILDER")"

if [ ! -f "$BUILDER" ]; then
  echo "FATAL: builder not found: $BUILDER" >&2
  exit 2
fi

pass=0
fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

assert_contains() { # <label> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then ok; else bad "$1: expected to contain »$3«"; fi
}
assert_absent() { # <label> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then bad "$1: should NOT contain »$3«"; else ok; fi
}

# --- 1. municipalities resolves real persona/posture/tokens + keeps literal blanks ---
MUNI="$(python3 "$BUILDER" --vertical municipalities --stdout 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok; else bad "municipalities --stdout exited $rc"; fi
assert_contains "muni persona title"   "$MUNI" "Director of Parks & Recreation"
assert_contains "muni posture"         "$MUNI" "Posture for this vertical: knowledge"
assert_contains "muni offer resolved"  "$MUNI" "Downtown Revitalization — posture: knowledge"
assert_contains "muni brand primary"   "$MUNI" "#ff4d00"
assert_contains "muni lockup"          "$MUNI" "brite·base"
assert_contains "blank prospect kept"  "$MUNI" '{prospect}'
assert_contains "blank contact kept"   "$MUNI" '{contact}'
assert_contains "blank angle kept"     "$MUNI" '{angle}'
assert_contains "client-facing rule"   "$MUNI" "this is client-facing"

# --- 2. no internal targeting data leaks (generator never reads the ICP layer) ---
assert_absent "no seed_accounts" "$MUNI" "seed_account"

# --- 3. unknown vertical hard-fails (exit 2) and names the slug ---
ERR="$(python3 "$BUILDER" --vertical food-trucks --stdout 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then ok; else bad "unknown vertical exited $rc (expected 2)"; fi
assert_contains "unknown names slug" "$ERR" "unknown vertical 'food-trucks'"

# --- 4. generalizes to another vertical with a different posture ---
HOTELS="$(python3 "$BUILDER" --vertical hotels-resorts --stdout 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok; else bad "hotels-resorts --stdout exited $rc"; fi
assert_contains "hotels brand primary" "$HOTELS" "#ff4d00"
assert_contains "hotels blanks kept"   "$HOTELS" '{prospect}'

# --- 5. deterministic: two stdout runs are byte-identical (no timestamps) ---
MUNI2="$(python3 "$BUILDER" --vertical municipalities --stdout 2>&1)"
if [ "$MUNI" = "$MUNI2" ]; then ok; else bad "non-deterministic output across runs"; fi

# --- 6. committed municipalities pilot matches a fresh regenerate (--check) ---
python3 "$BUILDER" --vertical municipalities --check >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then ok; else bad "--check drift: municipalities-intro-deck.md is stale (exit $rc) — regenerate"; fi

printf '\nbuild_deck_template: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
