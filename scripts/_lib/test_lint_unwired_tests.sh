#!/usr/bin/env bash
# Self-test for lint_unwired_tests.py (BC-16381). Builds a synthetic repo tree and
# locks each wiring form (literal / glob-loop / stem-interpolation / pytest
# discovery) as WIRED, and a genuinely-unreferenced test as UNWIRED.
# Emits `RESULT pass=N fail=M`; exits nonzero iff any assertion failed.
# bash 3.2-safe (no mapfile / no array expansion).
set -u

LINT="${1:-}"
if [ -z "$LINT" ]; then
  LINT="$(cd "$(dirname "$0")" && pwd)/lint_unwired_tests.py"
fi

pass=0
fail=0
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT

check() {  # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s (expected %s got %s)\n' "$1" "$2" "$3" >&2
  fi
}

# ── Build a synthetic repo root exercising all four wiring forms ──────
root="$tmp/root"
mkdir -p "$root/scripts" "$root/plugins/foo/tests" "$root/plugins/foo/scripts" "$root/plugins/bar/tests"

# A runner corpus that wires four tests four different ways.
cat > "$root/scripts/validate.sh" <<'SH'
#!/usr/bin/env bash
# literal wiring:
bash "$REPO_ROOT/scripts/test_wired_literal.sh"
# glob-loop wiring:
for t in "$REPO_ROOT"/plugins/foo/tests/test-*.sh; do bash "$t"; done
# stem-interpolation wiring:
for s in wiredstem; do bash "$REPO_ROOT/plugins/foo/scripts/test_$s.sh"; done
# the python-units runner is itself a test-named file and must be literally wired:
bash "$REPO_ROOT/scripts/test-python-units.sh"
# bare tokens in CODE that are NOT in any test_$VAR loop list (stem must stay tight):
echo "data build report plan"
# comment-only mention must NOT count as wired: scripts/test_commentonly.sh
SH

# pytest plugin list — only `foo` is discovered, not `bar`.
cat > "$root/scripts/test-python-units.sh" <<'SH'
#!/usr/bin/env bash
plugins="foo"
SH

# WIRED test files (must NOT be flagged):
: > "$root/scripts/test_wired_literal.sh"          # literal
: > "$root/plugins/foo/tests/test-glob-one.sh"     # glob-loop
: > "$root/plugins/foo/scripts/test_wiredstem.sh"  # stem
: > "$root/plugins/foo/tests/test_discovered.py"   # pytest (foo listed)

# UNWIRED test files (MUST be flagged):
: > "$root/scripts/test_orphan.sh"                 # no reference anywhere
: > "$root/plugins/bar/tests/test_orphan.py"       # bar not in pytest list
: > "$root/plugins/foo/scripts/test_data.sh"       # stem "data" is a code token but NOT in a test_$VAR loop (P3 stem-tightening)
: > "$root/scripts/test_commentonly.sh"            # referenced ONLY in a comment (P3 comment-strip)

# DEPENDENCY-DIR test files (must NOT be flagged: .venv/node_modules are not
# the repo's test namespace — the 2026-08-03 tam-map virtualenv incident,
# where site-packages test_*.py blocked every push):
mkdir -p "$root/plugins/foo/scripts/.venv/lib/python3.14/site-packages/aiohttp"
: > "$root/plugins/foo/scripts/.venv/lib/python3.14/site-packages/aiohttp/test_utils.py"

out="$(python3 "$LINT" "$root" 2>&1)"; rc="$?"

check "mixed tree exits nonzero (orphans present)" 1 "$rc"

for wired in \
  "scripts/test_wired_literal.sh" \
  "plugins/foo/tests/test-glob-one.sh" \
  "plugins/foo/scripts/test_wiredstem.sh" \
  "plugins/foo/tests/test_discovered.py" \
  "plugins/foo/scripts/.venv/lib/python3.14/site-packages/aiohttp/test_utils.py" ; do
  if printf '%s' "$out" | grep -q "$wired"; then
    fail=$((fail + 1)); printf 'FAIL: %s wrongly flagged as unwired\n' "$wired" >&2
  else
    pass=$((pass + 1))
  fi
done

for orphan in \
  "scripts/test_orphan.sh" \
  "plugins/bar/tests/test_orphan.py" \
  "plugins/foo/scripts/test_data.sh" \
  "scripts/test_commentonly.sh" ; do
  if printf '%s' "$out" | grep -q "$orphan"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); printf 'FAIL: %s should have been flagged unwired\n' "$orphan" >&2
  fi
done

# ── Clean tree: remove the orphans → OK (rc 0) ───────────────────────
rm -f "$root/scripts/test_orphan.sh" "$root/plugins/bar/tests/test_orphan.py" \
      "$root/plugins/foo/scripts/test_data.sh" "$root/scripts/test_commentonly.sh"
python3 "$LINT" "$root" >/dev/null 2>&1
check "all-wired tree passes (rc 0)" 0 "$?"

# ── Missing repo root arg still yields a clean run on cwd default? ────
# (guard: an unreadable validate.sh must not crash — empty corpus, no tests)
empty="$tmp/empty"; mkdir -p "$empty/scripts"
python3 "$LINT" "$empty" >/dev/null 2>&1
check "empty tree (no tests) passes (rc 0)" 0 "$?"

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
