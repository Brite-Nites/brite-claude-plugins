#!/usr/bin/env bash
# Regression-lock for the WS-A evidence-reality lint (BC-12692):
#   scripts/lib/flow_evidence_lint.py — inventory ↔ story-doc consistency
#     (a) status-glyph ↔ canonical story `status:` agreement
#     (b) strict-`src/` evidence-anchor existence (brace + glob + [id]-literal)
#
# Fixtures are built in a temp dir (mkdir/printf/touch) — NO committed fixture
# sprawl, so the BC-13915 broken-oracle-across-copies trap cannot recur here.
# Two layers: PY-unit (the pure helpers) + e2e (the runner over a built repo).
#
# Bash 3.2 compatible. Stdlib python3 only.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$PLUGIN_ROOT/scripts/lib/flow_evidence_lint.py"
RUNNER="$PLUGIN_ROOT/scripts/flow-evidence-lint.sh"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 1; }

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# py_expect <label> <python-expr-printing-PASS-or-FAIL>
# Runs an inline python check that imports the lib and prints "PASS"/"FAIL".
py() {
  PYTHONPATH="$PLUGIN_ROOT/scripts/lib" python3 - "$@"
}

# ── Layer 1: pure-helper unit checks ─────────────────────────────────────────
section "1/4" "brace expansion + src-token extraction (pure helpers)"

py <<'PY' && pass "brace_expand: single group" || fail "brace_expand: single group"
import flow_evidence_lint as m
r = m._brace_expand("src/api/{a,b}/route.ts")
import sys
sys.exit(0 if r == ["src/api/a/route.ts", "src/api/b/route.ts"] else 1)
PY

py <<'PY' && pass "brace_expand: nested group" || fail "brace_expand: nested group"
import flow_evidence_lint as m, sys
r = m._brace_expand("x/{p,[id]/{q,r}}.tsx")
sys.exit(0 if r == ["x/p.tsx", "x/[id]/q.tsx", "x/[id]/r.tsx"] else 1)
PY

py <<'PY' && pass "extract: drops prose / glyph / flow-id, keeps src paths" || fail "extract: token filter"
import flow_evidence_lint as m, sys
cell = ("`src/app/api/upload/route.ts`; `src/collections/X.ts, Y.ts`; "
        "`access-governance-04` is `✓`; `/assets`; `?text_query=`")
r = m._extract_src_tokens(cell)
# Y.ts has no src/ prefix → dropped; the two src/ paths kept; prose dropped.
sys.exit(0 if r == ["src/app/api/upload/route.ts", "src/collections/X.ts"] else 1)
PY

py <<'PY' && pass "extract: brace span expands inside backticks" || fail "extract: brace span"
import flow_evidence_lint as m, sys
r = m._extract_src_tokens("`src/app/api/imagekit/{auth,config}/route.ts`")
sys.exit(0 if r == ["src/app/api/imagekit/auth/route.ts",
                    "src/app/api/imagekit/config/route.ts"] else 1)
PY

py <<'PY' && pass "flow_index:skip is front-matter-scoped (body example ignored)" || fail "flow_index:skip scoping"
import flow_evidence_lint as m, sys
fm_skip = "---\nflow_id: a\nflow_index: skip\n---\n# t\n"
body_skip = "---\nflow_id: a\n---\n# t\n```yaml\nflow_index: skip\n```\n"
# Real skip in front-matter → True; a `flow_index: skip` only in the BODY → False
# (must not exclude a real story doc from the status index).
sys.exit(0 if (m._flow_index_skipped(fm_skip) and not m._flow_index_skipped(body_skip)) else 1)
PY

section "2/4" "on-disk resolution: literal / glob / [id]-literal"
# Build a tiny tree to resolve against.
mkdir -p "$TMP/r/src/app/api/dedup/x" "$TMP/r/src/app/api/assets/[id]" "$TMP/r/src/lib"
touch "$TMP/r/src/app/api/dedup/x/route.ts" "$TMP/r/src/app/api/assets/[id]/route.ts" \
      "$TMP/r/src/lib/audit.ts"

py "$TMP/r" <<'PY' && pass "resolve: literal hit + miss" || fail "resolve: literal"
import flow_evidence_lint as m, sys
ok = m._resolve(sys.argv[1], "src/lib/audit.ts")
miss = m._resolve(sys.argv[1], "src/lib/gone.ts")
sys.exit(0 if (ok and not miss) else 1)
PY

py "$TMP/r" <<'PY' && pass "resolve: glob '*' matches a dir level" || fail "resolve: glob"
import flow_evidence_lint as m, sys
sys.exit(0 if m._resolve(sys.argv[1], "src/app/api/dedup/*/route.ts") else 1)
PY

py "$TMP/r" <<'PY' && pass "resolve: [id] treated as literal dir (not glob class)" || fail "resolve: [id] literal"
import flow_evidence_lint as m, sys
sys.exit(0 if m._resolve(sys.argv[1], "src/app/api/assets/[id]/route.ts") else 1)
PY

# ── Layer 2: e2e through the runner over a built repo ────────────────────────
section "3/4" "e2e status-agreement (glyph ↔ canonical status)"

# mk_repo <name> — scaffolds docs/product/{master-flow-inventory.md,flows/<dom>/}
# Helper writers append rows / docs.
mk_inv_header() {  # <inv-path>  (4-col: ID | Title | Status | Evidence anchor)
  mkdir -p "$(dirname "$1")"
  printf '# inv\n\n## Domain: demo\n\n| Sub-flow ID | Title | Status | Evidence anchor |\n|---|---|---|---|\n' > "$1"
}
mk_story() {  # <flows-dir> <domain> <flow-id> <status>
  mkdir -p "$1/$2"
  printf -- '---\nflow_id: %s\ndomain: %s\nstatus: %s\n---\n# t\n' "$3" "$2" "$4" \
    > "$1/$2/$(basename "$3").md"
}

# Repo A: ✓ marker but doc says NOT_STARTED → status-agreement FAIL.
A="$TMP/repoA"
mk_inv_header "$A/docs/product/master-flow-inventory.md"
printf '| demo-01 | One | ✓ | |\n' >> "$A/docs/product/master-flow-inventory.md"
mk_story "$A/docs/product/flows" demo demo-01 NOT_STARTED
# Capture-then-grep (NOT a pipe): the runner exits 1 on a violation, and
# `set -o pipefail` would propagate that 1 through `runner | grep`, failing the
# `if` even when grep matched. `|| true` neutralizes the expected non-zero exit.
out_a="$("$RUNNER" "$A" 2>/dev/null || true)"
if printf '%s' "$out_a" | grep -q 'status-agreement .*demo-01'; then
  pass "✓-marker vs NOT_STARTED doc → status-agreement FAIL"
else
  fail "✓/NOT_STARTED disagreement not caught (out: $(printf '%s' "$out_a" | tr '\n' '|'))"
fi

# Repo B: ✓ marker, doc BUILT → agree → clean.
B="$TMP/repoB"
mk_inv_header "$B/docs/product/master-flow-inventory.md"
printf '| demo-01 | One | ✓ | |\n' >> "$B/docs/product/master-flow-inventory.md"
mk_story "$B/docs/product/flows" demo demo-01 BUILT
if "$RUNNER" "$B" >/dev/null 2>&1; then
  pass "✓-marker vs BUILT doc → clean (exit 0)"
else
  fail "agreeing ✓/BUILT row wrongly flagged"
fi

# Repo C: ? marker is exempt even against a mismatched status.
C="$TMP/repoC"
mk_inv_header "$C/docs/product/master-flow-inventory.md"
printf '| demo-01 | One | ? | |\n' >> "$C/docs/product/master-flow-inventory.md"
mk_story "$C/docs/product/flows" demo demo-01 NOT_STARTED
if "$RUNNER" "$C" >/dev/null 2>&1; then
  pass "?-marker is exempt (no status-agreement fire)"
else
  fail "?-marker wrongly enforced"
fi

# Repo D: off-canon legacy status (PARTIAL) defers to BAD_STATUS → no fire here.
D="$TMP/repoD"
mk_inv_header "$D/docs/product/master-flow-inventory.md"
printf '| demo-01 | One | ✓ | |\n' >> "$D/docs/product/master-flow-inventory.md"
mk_story "$D/docs/product/flows" demo demo-01 PARTIAL
if "$RUNNER" "$D" >/dev/null 2>&1; then
  pass "off-canon status (PARTIAL) deferred to BAD_STATUS → clean"
else
  fail "off-canon status wrongly flagged by agreement check"
fi

# Repo E: slash-form (opaque) flow_id resolves row → doc correctly.
E="$TMP/repoE"
mk_inv_header "$E/docs/product/master-flow-inventory.md"
printf '| `hosting/perf-tune` | Perf | ✗ | |\n' >> "$E/docs/product/master-flow-inventory.md"
mk_story "$E/docs/product/flows" hosting hosting/perf-tune NOT_STARTED
# ✗ ↔ NOT_STARTED agree → clean (and proves slash-form opaque match works).
if "$RUNNER" "$E" >/dev/null 2>&1; then
  pass "slash-form opaque flow_id row→doc match (✗/NOT_STARTED agree → clean)"
else
  fail "slash-form flow_id mis-resolved"
fi

section "4/4" "e2e evidence-anchor reality (existence)"

# Repo F: ✓ row cites a real path + a missing path → one evidence FAIL (missing).
F="$TMP/repoF"
mk_inv_header "$F/docs/product/master-flow-inventory.md"
mkdir -p "$F/src/lib"
touch "$F/src/lib/real.ts"
printf '| demo-01 | One | ✓ | `src/lib/real.ts`; `src/lib/gone.ts` |\n' \
  >> "$F/docs/product/master-flow-inventory.md"
mk_story "$F/docs/product/flows" demo demo-01 BUILT
out_f="$("$RUNNER" "$F" 2>/dev/null || true)"
if printf '%s' "$out_f" | grep -q "evidence-anchor .*gone.ts" \
   && ! printf '%s' "$out_f" | grep -q "real.ts"; then
  pass "missing evidence anchor flagged; existing one not flagged"
else
  fail "evidence-anchor existence check wrong (out: $(printf '%s' "$out_f" | tr '\n' '|'))"
fi

# Repo G: ✗ (missing) row may cite a not-yet-built path → NOT flagged.
G="$TMP/repoG"
mk_inv_header "$G/docs/product/master-flow-inventory.md"
printf '| demo-01 | One | ✗ | `src/lib/future.ts` |\n' \
  >> "$G/docs/product/master-flow-inventory.md"
mk_story "$G/docs/product/flows" demo demo-01 NOT_STARTED
if "$RUNNER" "$G" >/dev/null 2>&1; then
  pass "✗-row citing a not-yet-built path → evidence check skipped (clean)"
else
  fail "✗-row evidence wrongly enforced"
fi

# Repo H: brace-expanded anchor where BOTH expansions exist → clean.
H="$TMP/repoH"
mk_inv_header "$H/docs/product/master-flow-inventory.md"
mkdir -p "$H/src/api/auth" "$H/src/api/config"
touch "$H/src/api/auth/route.ts" "$H/src/api/config/route.ts"
printf '| demo-01 | One | ✓ | `src/api/{auth,config}/route.ts` |\n' \
  >> "$H/docs/product/master-flow-inventory.md"
mk_story "$H/docs/product/flows" demo demo-01 BUILT
if "$RUNNER" "$H" >/dev/null 2>&1; then
  pass "brace-expanded anchor (both exist) → clean"
else
  fail "brace-expanded anchor wrongly flagged"
fi

# Repo J: file-family ANY-resolves — the Next.js route shorthand
# `{route,dashboard}/route.ts` literal-expands to `route/route.ts` (does NOT exist)
# + `dashboard/route.ts` (DOES exist). The real-data false-positive class from
# brand-hub. ANY member resolving → clean (high-precision / best-effort).
J="$TMP/repoJ"
mk_inv_header "$J/docs/product/master-flow-inventory.md"
mkdir -p "$J/src/app/api/search-logs/dashboard"
touch "$J/src/app/api/search-logs/dashboard/route.ts"
printf '| demo-01 | One | ✓ | `src/app/api/search-logs/{route,dashboard}/route.ts` |\n' \
  >> "$J/docs/product/master-flow-inventory.md"
mk_story "$J/docs/product/flows" demo demo-01 BUILT
if "$RUNNER" "$J" >/dev/null 2>&1; then
  pass "file-family anchor (≥1 member exists) → clean (no notation false-positive)"
else
  fail "file-family anchor false-flagged despite a real member"
fi

# Repo K: wholesale-dead family — NO member of the brace family exists → FLAGGED.
K="$TMP/repoK"
mk_inv_header "$K/docs/product/master-flow-inventory.md"
printf '| demo-01 | One | ✓ | `src/app/api/ghost/{route,dashboard}/route.ts` |\n' \
  >> "$K/docs/product/master-flow-inventory.md"
mk_story "$K/docs/product/flows" demo demo-01 BUILT
out_k="$("$RUNNER" "$K" 2>/dev/null || true)"
if printf '%s' "$out_k" | grep -q 'evidence-anchor .*ghost'; then
  pass "wholesale-dead family (no member resolves) → evidence-anchor FAIL"
else
  fail "dead family not caught (out: $(printf '%s' "$out_k" | tr '\n' '|'))"
fi

# Repo N: nested story doc (flows/dom/sub/deep-01.md) is indexed (rglob) — a status
# mismatch on a deeper-than-2-level doc is still caught (matches A-8 recursive find).
N="$TMP/repoN"
mk_inv_header "$N/docs/product/master-flow-inventory.md"
printf '| deep-01 | Deep | ✓ | |\n' >> "$N/docs/product/master-flow-inventory.md"
mkdir -p "$N/docs/product/flows/demo/sub"
printf -- '---\nflow_id: deep-01\ndomain: demo\nstatus: NOT_STARTED\n---\n# t\n' \
  > "$N/docs/product/flows/demo/sub/deep-01.md"
out_n="$("$RUNNER" "$N" 2>/dev/null || true)"
if printf '%s' "$out_n" | grep -q 'status-agreement .*deep-01'; then
  pass "nested story doc (3-level) is indexed → status mismatch caught (rglob)"
else
  fail "nested story doc not indexed (out: $(printf '%s' "$out_n" | tr '\n' '|'))"
fi

# Repo I: brite-supply-react shape — inventory with NO Status / NO Evidence column
# → neither check fires → clean (no false-fail on a non-migrated layout).
I="$TMP/repoI"
mkdir -p "$I/docs/product/flows/pdp"
printf '# inv\n\n## Domain: shop\n\n| Sub-flow ID | Display name | Description | Release gate |\n|---|---|---|---|\n| pdp-01 | PDP | renders | R1 |\n' \
  > "$I/docs/product/master-flow-inventory.md"
mk_story "$I/docs/product/flows" pdp pdp-01 IN_PROGRESS
if "$RUNNER" "$I" >/dev/null 2>&1; then
  pass "no Status/Evidence column → checks skip → clean (no false-fail)"
else
  fail "column-less inventory wrongly flagged"
fi

printf '\nflow-evidence-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
