#!/usr/bin/env bash
# Verifies the tier-alias lint for type:prompt hook models.
# Exercises both validate.sh (full repo) and validate-single.sh (single file).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$REPO_ROOT/scripts/_fixtures"
REJECT="$FIXTURES/hooks-tier-alias-reject.json"
ACCEPT="$FIXTURES/hooks-concrete-model-accept.json"
HOOKS="$REPO_ROOT/plugins/workflows/hooks/hooks.json"

pass=0
fail=0
failures=()

green() { printf "\033[32m%s\033[0m" "$1"; }
red()   { printf "\033[31m%s\033[0m" "$1"; }

assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf "  %s %s (exit=%s)\n" "$(green PASS)" "$name" "$actual"
    pass=$((pass + 1))
  else
    printf "  %s %s (expected exit=%s got %s)\n" "$(red FAIL)" "$name" "$expected" "$actual"
    fail=$((fail + 1))
    failures+=("$name")
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if grep -qF -- "$needle" <<< "$haystack"; then
    printf "  %s %s\n" "$(green PASS)" "$name"
    pass=$((pass + 1))
  else
    printf "  %s %s (missing: %s)\n" "$(red FAIL)" "$name" "$needle"
    fail=$((fail + 1))
    failures+=("$name")
  fi
}

# Guard: fixtures + target must exist
for f in "$REJECT" "$ACCEPT" "$HOOKS"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: missing file $f" >&2
    exit 2
  fi
done

# Setup: capture a durable backup of the real hooks.json so the trap can
# always restore it. We try git first (survives $TMP loss), then fall back
# to a file copy.
#
# Note: bash's EXIT trap does NOT fire on SIGKILL / power loss. If the
# process is killed between the seed at the bottom of this file and the
# trap running, plugins/workflows/hooks/hooks.json is left mutated and a
# manual `git checkout HEAD -- plugins/workflows/hooks/hooks.json` is
# needed to recover.
TMP=$(mktemp -d)
BACKUP="$TMP/hooks.json.backup"
cp "$HOOKS" "$BACKUP"
cleanup() {
  # Prefer git (backup source is the object store, not $TMP).
  if ! git -C "$REPO_ROOT" checkout HEAD -- "$HOOKS" 2>/dev/null; then
    [ -f "$BACKUP" ] && cp "$BACKUP" "$HOOKS"
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
mkdir -p "$TMP/hooks"

printf "\n== validate-single.sh hooks mode ==\n"

# V2: tier alias "haiku" → exit 1 with message
cp "$REJECT" "$TMP/hooks/hooks.json"
set +e
out=$(VALIDATE_PLUGIN="$TMP" "$REPO_ROOT/scripts/validate-single.sh" hooks 2>&1)
rc=$?
set -e
assert_exit "V2 reject-haiku exits non-zero" 1 "$rc"
assert_contains "V2 error message mentions tier alias" 'is a tier alias' "$out"
assert_contains "V2 error message suggests concrete id" 'claude-haiku-4-5' "$out"

# V3: sonnet and opus — mutate the reject fixture into $TMP via sys.argv.
# Quoted heredoc (<<'PY') prevents bash expansion; paths come via argv.
for alias in sonnet opus; do
  python3 - "$REJECT" "$TMP/hooks/hooks.json" "$alias" <<'PY'
import json, sys
src, dst, alias_val = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, encoding="utf-8") as f:
    data = json.load(f)
data["hooks"]["PreToolUse"][0]["hooks"][0]["model"] = alias_val
with open(dst, "w", encoding="utf-8") as f:
    json.dump(data, f)
PY
  set +e
  out=$(VALIDATE_PLUGIN="$TMP" "$REPO_ROOT/scripts/validate-single.sh" hooks 2>&1)
  rc=$?
  set -e
  assert_exit "V3 reject-$alias exits non-zero" 1 "$rc"
  assert_contains "V3 $alias error mentions tier alias" "\"$alias\" is a tier alias" "$out"
done

# V4+V5: concrete IDs pass
cp "$ACCEPT" "$TMP/hooks/hooks.json"
set +e
out=$(VALIDATE_PLUGIN="$TMP" "$REPO_ROOT/scripts/validate-single.sh" hooks 2>&1)
rc=$?
set -e
assert_exit "V4/V5 concrete models exit 0" 0 "$rc"

printf "\n== validate.sh full repo (baseline) ==\n"

# V1: current main is clean
set +e
out=$("$REPO_ROOT/scripts/validate.sh" 2>&1)
rc=$?
set -e
assert_exit "V1 current tree validates clean" 0 "$rc"

printf "\n== validate.sh detects tier alias injected into a plugin ==\n"

# Seed a tier alias into the first type:prompt hook using an atomic write
# (tempfile in the target's dir, then os.replace). Path via sys.argv.
python3 - "$HOOKS" <<'PY'
import json, os, sys, tempfile
from pathlib import Path
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
for handlers in data.get("hooks", {}).values():
    for handler in handlers:
        for hook in handler.get("hooks", []):
            if hook.get("type") == "prompt":
                hook["model"] = "haiku"
                break
        else:
            continue
        break
    else:
        continue
    break
target_dir = os.path.dirname(path) or "."
fd, tmp = tempfile.mkstemp(dir=target_dir, prefix=".hooks.", suffix=".tmp")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)
finally:
    # On success os.replace moved tmp away; on failure we need to clean it up.
    Path(tmp).unlink(missing_ok=True)
PY

set +e
out=$("$REPO_ROOT/scripts/validate.sh" 2>&1)
rc=$?
set -e
# Trap restores $HOOKS from $BACKUP on EXIT.

assert_exit "V2-full validate.sh fails on seeded tier alias" 1 "$rc"
assert_contains "V2-full error message surfaces hooks.json path" 'hooks.json' "$out"
assert_contains "V2-full error message mentions tier alias" 'is a tier alias' "$out"

printf "\n== Summary ==\n"
printf "  %d passed, %d failed\n" "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf "  failures: %s\n" "${failures[*]}"
  exit 1
fi
exit 0
