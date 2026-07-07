#!/usr/bin/env bash
# ── Regression test: pre-commit ADVISORY hook (BC-11890) ──────────────
# Locks the behavior of the PreToolUse → Bash quality hook in
# plugins/workflows/hooks/hooks.json after its block → warn demotion:
#   1. NEVER emits {"ok":false} — always {"ok":true} on stdout.
#   2. Surfaces failing-linter output on stderr (not swallowed), for all
#      three arms (eslint, tsc, ruff).
#   3. Prints the advisory banner exactly ONCE, BEFORE the linter output,
#      even when multiple linters fail (the advise() once-flag).
#   4. Stays silent on stderr when linters pass (clean commit → no advisory).
#
# Hermetic: shims `npx`/`eslint`/`tsc`/`ruff` on PATH, so no real toolchain
# or network is required. Run directly, or via scripts/validate.sh (§2d').
#   bash scripts/test_precommit_advisory.sh
#   bash scripts/test_precommit_advisory.sh /path/to/hooks.json
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_JSON="${1:-$REPO_ROOT/plugins/workflows/hooks/hooks.json}"

# BC-16371 regression guard: snapshot the repo working tree up front so the
# end-of-run assertion can prove this harness leaks nothing into it. Six fixture
# files (bad.js/py/ts, stub package.json/tsconfig.json/pyproject.toml) once leaked
# to repo root from a non-hermetic ancestor of this harness. All fabrication now
# happens under mktemp -d below; comparing before/after (not asserting absolute
# cleanliness) keeps this valid even when the dev has unrelated staged changes.
repo_status_before="$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null || true)"

pass_count=0
fail_count=0
total=0
pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass_count=$((pass_count + 1)); total=$((total + 1)); }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail_count=$((fail_count + 1)); total=$((total + 1)); }

# ── Extract the advisory hook command (python3 — no jq dependency) ────
HOOK_CMD="$(python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
for m in d["hooks"].get("PreToolUse", []):
    if m.get("matcher") == "Bash":
        for h in m["hooks"]:
            if "Pre-commit advisory" in h.get("command", ""):
                sys.stdout.write(h["command"])
                sys.exit(0)
sys.exit(7)
PY
)"
if [ -z "$HOOK_CMD" ]; then
  echo "FATAL: could not extract advisory hook command from $HOOKS_JSON" >&2
  echo "       (expected a PreToolUse Bash hook whose command contains 'Pre-commit advisory')" >&2
  exit 2
fi

# ── Hermetic temp tree + shimmed linters ─────────────────────────────
tmproot="$(mktemp -d -t precommit-adv.XXXXXX)" || { echo "FATAL: mktemp -d failed" >&2; exit 2; }
cleanup() { rm -rf "$tmproot"; }
trap cleanup EXIT

# npx shim contract (eslint + tsc go through npx in the hook):
#   npx … eslint --version → exit 0 (eslint "available")
#   npx … tsc --version    → exit 0 (tsc "available")
#   npx … tsc --noEmit     → honor FAKE_TSC_EXIT (default 1), print error
#   npx … eslint <lint>    → honor FAKE_ESLINT_EXIT (default 1), print error
# Case-arm order matters: the specific `--version`/`tsc --noEmit` probes must precede
# the `*eslint*` catch-all. Safe because no real hook invocation mixes those tokens.
mkdir -p "$tmproot/bin"
cat > "$tmproot/bin/npx" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"eslint --version"*) exit 0 ;;
  *"tsc --version"*)    exit 0 ;;
  *"tsc --noEmit"*)
    if [ "${FAKE_TSC_EXIT:-1}" -ne 0 ]; then
      echo "FAKE_TSC_ERROR: bad.ts(1,7): error TS6133: 'unused' is declared but never read."
      exit 1
    fi
    exit 0 ;;
  *eslint*)
    if [ "${FAKE_ESLINT_EXIT:-1}" -ne 0 ]; then
      echo "FAKE_ESLINT_ERROR: 'unused' is assigned a value but never used (no-unused-vars)"
      exit 1
    fi
    exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$tmproot/bin/npx"

# ruff shim (the hook calls bare `ruff check`, not via npx):
#   ruff check -- <files> → honor FAKE_RUFF_EXIT (default 1), print error
cat > "$tmproot/bin/ruff" <<'SH'
#!/usr/bin/env bash
if [ "${FAKE_RUFF_EXIT:-1}" -ne 0 ]; then
  echo "FAKE_RUFF_ERROR: bad.py:1:8: F401 [*] 'os' imported but unused"
  exit 1
fi
exit 0
SH
chmod +x "$tmproot/bin/ruff"

# repo: JS-only — used by Tests 1-3 (eslint arm only; no tsconfig/pyproject).
repo="$tmproot/repo"
mkdir -p "$repo"
(
  cd "$repo" || exit 1
  git init -q
  git config user.email t@example.com
  git config user.name test
  printf '{}\n' > package.json
  printf 'const unused = 1;\n' > bad.js
  git add package.json bad.js
)

# repo_all: all three arms wired — used by Tests 5-6 (eslint + tsc + ruff).
repo_all="$tmproot/repo_all"
mkdir -p "$repo_all"
(
  cd "$repo_all" || exit 1
  git init -q
  git config user.email t@example.com
  git config user.name test
  printf '{}\n' > package.json
  printf '{}\n' > tsconfig.json
  printf '[tool.ruff]\n' > pyproject.toml
  printf 'const unused = 1;\n' > bad.js
  printf 'const unused: number = 1;\n' > bad.ts
  printf 'import os\n' > bad.py
  git add package.json tsconfig.json pyproject.toml bad.js bad.ts bad.py
)

BANNER='Pre-commit advisory: quality checks reported issues below'

# run_hook <input-json> [repo-dir] ; honors FAKE_*_EXIT from env.
# stdout → $tmproot/out, stderr → $tmproot/err
run_hook() {
  local repo_dir="${2:-$repo}"
  ( cd "$repo_dir" && PATH="$tmproot/bin:$PATH" bash -c "$HOOK_CMD" >"$tmproot/out" 2>"$tmproot/err" <<<"$1" )
}

# ── Test 1: lint FAILS → never blocks, error + banner surface ────────
FAKE_ESLINT_EXIT=1 run_hook '{"command":"git commit -m test"}'
out="$(cat "$tmproot/out")"; err="$(cat "$tmproot/err")"
if [ "$out" = '{"ok":true}' ]; then pass 'lint-fail: stdout is {"ok":true} (never blocks)'; else fail "lint-fail: stdout was '$out' (expected {\"ok\":true})"; fi
if printf '%s' "$err" | grep -q "$BANNER"; then pass "lint-fail: advisory banner on stderr"; else fail "lint-fail: advisory banner missing from stderr"; fi
if printf '%s' "$err" | grep -q "FAKE_ESLINT_ERROR"; then pass "lint-fail: linter output surfaced (not swallowed)"; else fail "lint-fail: linter output not surfaced on stderr"; fi
banner_line="$(printf '%s\n' "$err" | grep -n "$BANNER" | head -1 | cut -d: -f1)"
err_line="$(printf '%s\n' "$err" | grep -n "FAKE_ESLINT_ERROR" | head -1 | cut -d: -f1)"
if [ -n "$banner_line" ] && [ -n "$err_line" ] && [ "$banner_line" -lt "$err_line" ]; then
  pass "lint-fail: banner precedes linter output"
else
  fail "lint-fail: banner (line ${banner_line:-?}) does not precede output (line ${err_line:-?})"
fi

# ── Test 2: lint PASSES → ok:true, EMPTY stderr (no advisory) ────────
FAKE_ESLINT_EXIT=0 run_hook '{"command":"git commit -m test"}'
out="$(cat "$tmproot/out")"; err="$(cat "$tmproot/err")"
if [ "$out" = '{"ok":true}' ]; then pass 'lint-pass: stdout is {"ok":true}'; else fail "lint-pass: stdout was '$out'"; fi
if [ -z "$err" ]; then pass "lint-pass: stderr empty (no advisory on clean commit)"; else fail "lint-pass: stderr not empty: '$err'"; fi

# ── Test 3: non-commit command → early ok:true, linters not run ──────
FAKE_ESLINT_EXIT=1 run_hook '{"command":"git status"}'
out="$(cat "$tmproot/out")"; err="$(cat "$tmproot/err")"
if [ "$out" = '{"ok":true}' ]; then pass 'non-commit: stdout is {"ok":true}'; else fail "non-commit: stdout was '$out'"; fi
if [ -z "$err" ]; then pass "non-commit: stderr empty (linters not run)"; else fail "non-commit: stderr not empty: '$err'"; fi

# ── Test 4: structural — no {"ok":false} verdict remains ─────────────
if printf '%s' "$HOOK_CMD" | grep -q '"ok":false'; then
  fail 'structural: advisory hook still contains an {"ok":false} branch'
else
  pass 'structural: advisory hook has no {"ok":false} branch'
fi

# ── Test 5: ALL THREE arms fail → ok:true, banner exactly ONCE, ──────
#            all three linters' output surfaced (eslint + tsc + ruff).
FAKE_ESLINT_EXIT=1 FAKE_TSC_EXIT=1 FAKE_RUFF_EXIT=1 run_hook '{"command":"git commit -m test"}' "$repo_all"
out="$(cat "$tmproot/out")"; err="$(cat "$tmproot/err")"
if [ "$out" = '{"ok":true}' ]; then pass 'multi-fail: stdout is {"ok":true} (3 linters failed, still never blocks)'; else fail "multi-fail: stdout was '$out'"; fi
banner_count="$(printf '%s\n' "$err" | grep -c "$BANNER")"
if [ "$banner_count" -eq 1 ]; then pass "multi-fail: advisory banner printed exactly once (advise() once-flag)"; else fail "multi-fail: banner printed $banner_count times (expected 1 — once-flag broken)"; fi
banner_line="$(printf '%s\n' "$err" | grep -n "$BANNER" | head -1 | cut -d: -f1)"
first_err_line="$(printf '%s\n' "$err" | grep -nE 'FAKE_ESLINT_ERROR|FAKE_TSC_ERROR|FAKE_RUFF_ERROR' | head -1 | cut -d: -f1)"
if [ -n "$banner_line" ] && [ -n "$first_err_line" ] && [ "$banner_line" -lt "$first_err_line" ]; then
  pass "multi-fail: banner precedes all linter output"
else
  fail "multi-fail: banner (line ${banner_line:-?}) does not precede output (line ${first_err_line:-?})"
fi
if printf '%s' "$err" | grep -q "FAKE_ESLINT_ERROR"; then pass "multi-fail: ESLint arm output surfaced"; else fail "multi-fail: ESLint output missing"; fi
if printf '%s' "$err" | grep -q "FAKE_TSC_ERROR"; then pass "multi-fail: tsc arm output surfaced"; else fail "multi-fail: tsc output missing"; fi
if printf '%s' "$err" | grep -q "FAKE_RUFF_ERROR"; then pass "multi-fail: ruff arm output surfaced"; else fail "multi-fail: ruff output missing"; fi
if printf '%s' "$err" | grep -q '── ESLint ──' && printf '%s' "$err" | grep -q '── tsc --noEmit ──' && printf '%s' "$err" | grep -q '── ruff check ──'; then pass "multi-fail: eslint + tsc + ruff section labels present"; else fail "multi-fail: section labels missing"; fi

# ── Test 6: all three arms PASS → ok:true, EMPTY stderr (no advisory) ─
FAKE_ESLINT_EXIT=0 FAKE_TSC_EXIT=0 FAKE_RUFF_EXIT=0 run_hook '{"command":"git commit -m test"}' "$repo_all"
out="$(cat "$tmproot/out")"; err="$(cat "$tmproot/err")"
if [ "$out" = '{"ok":true}' ]; then pass 'multi-pass: stdout is {"ok":true}'; else fail "multi-pass: stdout was '$out'"; fi
if [ -z "$err" ]; then pass "multi-pass: stderr empty (all 3 arms pass → no advisory)"; else fail "multi-pass: stderr not empty: '$err'"; fi

# ── Regression guard (BC-16371): the harness must not dirty the repo tree ─────
# If a future edit reintroduces the non-hermetic fixture fabrication, the repo's
# `git status --porcelain` will change and this assertion catches it. Scope: this
# targets the actual regression class — TRACKED-file leaks at repo root (the six
# historical fixtures were not gitignored). Leaks into gitignored paths are out of
# scope by design (no `--ignored`), so transient `__pycache__`/cache artifacts
# never false-fail the guard.
repo_status_after="$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null || true)"
if [ "$repo_status_after" = "$repo_status_before" ]; then
  pass "hermetic: harness left the repo working tree unchanged (no leaked fixtures)"
else
  fail "hermetic: harness changed the repo working tree — fixtures leaked:"
  diff <(printf '%s\n' "$repo_status_before") <(printf '%s\n' "$repo_status_after") | sed 's/^/          /' >&2
fi

printf "\n  Total: %d  Passed: %d  Failed: %d\n" "$total" "$pass_count" "$fail_count"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
printf "\n  \033[32mAll tests passed\033[0m\n"
