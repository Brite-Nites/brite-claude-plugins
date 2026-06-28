#!/usr/bin/env bash
# Regression-lock for the WS-A persona-exists lint (BC-12573):
#   scripts/lib/flow_persona_lint.py — every non-empty `personas:` slug resolves to
#   docs/product/personas/<slug>.md; honest-empty / absent passes.
#
# Fixtures built in a temp dir (mkdir/printf) — NO committed fixture sprawl (BC-13915
# broken-oracle-across-copies cannot recur). Two layers: PY-unit (the personas
# front-matter parser) + e2e (the runner over built repos).
#
# Bash 3.2 compatible. Stdlib python3 only.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$PLUGIN_ROOT/scripts/lib/flow_persona_lint.py"
RUNNER="$PLUGIN_ROOT/scripts/flow-persona-lint.sh"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 1; }

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

py() { PYTHONPATH="$PLUGIN_ROOT/scripts/lib" python3 - "$@"; }

# ── Layer 1: personas front-matter parser ────────────────────────────────────
section "1/3" "personas: front-matter parser (inline / block / honest-empty)"

py <<'PY' && pass "inline list [a, b] -> [a, b]" || fail "inline list"
import flow_persona_lint as m, sys
t = "---\npersonas: [installer, commercial-buyer]\n---\n# t\n"
sys.exit(0 if m.personas(t) == ["installer", "commercial-buyer"] else 1)
PY

py <<'PY' && pass "block list (- a / - b) -> [a, b]" || fail "block list"
import flow_persona_lint as m, sys
t = "---\npersonas:\n  - installer\n  - commercial-buyer\nrelated_flows: [x]\n---\n# t\n"
sys.exit(0 if m.personas(t) == ["installer", "commercial-buyer"] else 1)
PY

py <<'PY' && pass "honest-empty [] / absent / null -> [] (no false missing)" || fail "honest-empty"
import flow_persona_lint as m, sys
empty = m.personas("---\npersonas: []\n---\n# t\n")
absent = m.personas("---\nstatus: BUILT\n---\n# t\n")
nul = m.personas("---\npersonas: null\n---\n# t\n")
sys.exit(0 if empty == [] and absent == [] and nul == [] else 1)
PY

py <<'PY' && pass "quoted slugs stripped" || fail "quoted slugs"
import flow_persona_lint as m, sys
t = '---\npersonas: ["installer", \'commercial-buyer\']\n---\n# t\n'
sys.exit(0 if m.personas(t) == ["installer", "commercial-buyer"] else 1)
PY

py <<'PY' && pass "trailing (qualifier) + ;-separator normalize to clean slugs" || fail "qualifier/semicolon"
import flow_persona_lint as m, sys
# Annotated forms seen in the wild (brite-lseo RBAC-style): a trailing parenthetical
# and a ;-separator must yield the leading slug tokens, not garbage multi-word slugs.
t = "---\npersonas: [ADMIN (full); MANAGER (limited)]\n---\n# t\n"
sys.exit(0 if m.personas(t) == ["ADMIN", "MANAGER"] else 1)
PY

# ── Layer 2: e2e — missing persona FLAGGED ───────────────────────────────────
section "2/3" "e2e: a named persona with no file is flagged"

mk_story() {  # <repo> <domain> <stem> <personas-frontmatter-value>
  mkdir -p "$1/docs/product/flows/$2"
  printf -- '---\nflow_id: %s\ndomain: %s\nstatus: BUILT\npersonas: %s\n---\n# t\n' \
    "$3" "$2" "$4" > "$1/docs/product/flows/$2/$3.md"
}
mk_persona() { mkdir -p "$1/docs/product/personas"; printf '# %s\n' "$2" > "$1/docs/product/personas/$2.md"; }

# Repo A: doc names [installer, ghost]; only installer.md exists -> ghost flagged.
A="$TMP/repoA"
mk_persona "$A" installer
mk_story "$A" shop pdp-01 '[installer, ghost]'
out_a="$("$RUNNER" "$A" 2>/dev/null || true)"
if printf '%s' "$out_a" | grep -q "persona 'ghost'" \
   && ! printf '%s' "$out_a" | grep -q "persona 'installer'"; then
  pass "missing persona 'ghost' flagged; existing 'installer' not flagged"
else
  fail "persona-exists wrong (out: $(printf '%s' "$out_a" | tr '\n' '|'))"
fi

# ── Layer 3: e2e — pass paths + honest-empty ─────────────────────────────────
section "3/3" "e2e: all-resolve clean + honest-empty clean"

# Repo B: every slug resolves -> clean (mirrors brite-supply-react).
B="$TMP/repoB"
mk_persona "$B" installer
mk_persona "$B" commercial-buyer
mk_story "$B" shop pdp-01 '[installer, commercial-buyer]'
mk_story "$B" shop plp-01 '[installer]'
if "$RUNNER" "$B" >/dev/null 2>&1; then
  pass "all personas resolve -> clean"
else
  fail "all-resolve repo wrongly flagged"
fi

# Repo C: honest-empty personas: [] and a doc with NO personas key -> clean (even
# though the repo has no personas/ dir at all — nothing named, nothing to resolve).
C="$TMP/repoC"
mk_story "$C" shop pdp-01 '[]'
mkdir -p "$C/docs/product/flows/shop"
printf -- '---\nflow_id: nokey-01\ndomain: shop\nstatus: BUILT\n---\n# t\n' \
  > "$C/docs/product/flows/shop/nokey-01.md"
if "$RUNNER" "$C" >/dev/null 2>&1; then
  pass "honest-empty [] + absent personas key -> clean (no false missing)"
else
  fail "honest-empty wrongly flagged"
fi

# Repo D: block-form personas with one missing -> flagged (block parser e2e).
D="$TMP/repoD"
mk_persona "$D" installer
mkdir -p "$D/docs/product/flows/shop"
printf -- '---\nflow_id: blk-01\ndomain: shop\nstatus: BUILT\npersonas:\n  - installer\n  - missing-one\n---\n# t\n' \
  > "$D/docs/product/flows/shop/blk-01.md"
out_d="$("$RUNNER" "$D" 2>/dev/null || true)"
if printf '%s' "$out_d" | grep -q "persona 'missing-one'"; then
  pass "block-form personas: missing slug flagged"
else
  fail "block-form missing slug not caught (out: $(printf '%s' "$out_d" | tr '\n' '|'))"
fi

printf '\nflow-persona-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
