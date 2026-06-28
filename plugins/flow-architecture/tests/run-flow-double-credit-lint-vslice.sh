#!/usr/bin/env bash
# Regression-lock for the WS-A cross-domain double-credit lint (BC-12690):
#   scripts/lib/flow_evidence_lint.py  audit_cross_doc_double_credit
#     — a src/ path cited as built in ≥2 docs' ## Status notes, UNLESS ≥1 citing
#       bullet carries an ownership qualifier (same-bullet carve).
#
# Fixtures built in a temp dir (mkdir/printf) — NO committed fixture sprawl (the
# BC-13915 broken-oracle-across-copies trap cannot recur). Two layers: PY-unit
# (section + bullet helpers) + e2e (the runner over built repos).
#
# Bash 3.2 compatible. Stdlib python3 only.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$PLUGIN_ROOT/scripts/lib/flow_evidence_lint.py"
RUNNER="$PLUGIN_ROOT/scripts/flow-double-credit-lint.sh"

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

# mk_doc <flows-dir> <domain> <stem> <status-notes-body...>
# Writes a minimal story doc with a ## Status notes section (body = remaining args,
# one line each).
mk_doc() {
  local flows="$1" dom="$2" stem="$3"; shift 3
  mkdir -p "$flows/$dom"
  {
    printf -- '---\nflow_id: %s\ndomain: %s\nstatus: BUILT\n---\n# %s\n\n## Status notes\n\n' "$stem" "$dom" "$stem"
    for line in "$@"; do printf '%s\n' "$line"; done
  } > "$flows/$dom/$stem.md"
}

# ── Layer 1: section + bullet helpers ────────────────────────────────────────
section "1/3" "## Status notes section + carve-unit helpers"

py <<'PY' && pass "status-notes section: matches '## Status notes', stops at next H2" || fail "status-notes section"
import flow_evidence_lint as m, sys
t = "# T\n\n## Status notes\n\n- `src/a.ts` built.\n\n## Acceptance\n\n- not this\n"
sec = m._status_notes_section(t)
sys.exit(0 if ("src/a.ts" in sec and "not this" not in sec) else 1)
PY

py <<'PY' && pass "status-notes section: '## Statuses' is NOT matched (word boundary)" || fail "status-notes word-boundary"
import flow_evidence_lint as m, sys
t = "# T\n\n## Statuses of the world\n\n- `src/a.ts`\n"
sys.exit(0 if m._status_notes_section(t) == "" else 1)
PY

py <<'PY' && pass "carve-units: each bullet is its own unit" || fail "carve-units split"
import flow_evidence_lint as m, sys
sec = "- `src/a.ts` owns it.\n- `src/b.ts` plain.\n"
u = m._carve_units(sec)
# 2 bullets → 2 units; the qualifier is only in the first.
ok = (len(u) == 2 and m._QUALIFIER.search(u[0]) and not m._QUALIFIER.search(u[1]))
sys.exit(0 if ok else 1)
PY

py <<'PY' && pass "carve-units: a wrapped bullet keeps its continuation line" || fail "carve-units wrap"
import flow_evidence_lint as m, sys
sec = "- `src/a.ts` is the surface\n  which this flow reuses.\n- `src/b.ts` plain.\n"
u = m._carve_units(sec)
# bullet 1 spans 2 physical lines; the qualifier 'reuses' (continuation) is in unit 0.
ok = (len(u) == 2 and "reuses" in u[0])
sys.exit(0 if ok else 1)
PY

# ── Layer 2: e2e — double-credit FLAGGED ─────────────────────────────────────
section "2/3" "e2e: uncarved double-credit is flagged"

# Repo A: two docs (different domains) both cite src/shared.ts as built, neither
# carries a qualifier → FLAGGED.
A="$TMP/repoA/docs/product/flows"
mk_doc "$A" alpha alpha-01 '- `src/shared.ts` — the upload surface.'
mk_doc "$A" beta  beta-01  '- `src/shared.ts` — the dedup surface.'
out_a="$("$RUNNER" "$TMP/repoA" 2>/dev/null || true)"
if printf '%s' "$out_a" | grep -q 'double-credit  src/shared.ts' \
   && printf '%s' "$out_a" | grep -q 'alpha-01' \
   && printf '%s' "$out_a" | grep -q 'beta-01'; then
  pass "two docs double-cite src/shared.ts, no qualifier → FLAGGED (both docs named)"
else
  fail "uncarved double-credit not caught (out: $(printf '%s' "$out_a" | tr '\n' '|'))"
fi

# ── Layer 3: e2e — carve + negative controls ─────────────────────────────────
section "3/3" "e2e: ownership carve + single-cite + relationship mentions"

# Repo B: same double-cite, but doc beta frames it with 'reuses' on the path's
# bullet → carved → clean.
B="$TMP/repoB/docs/product/flows"
mk_doc "$B" alpha alpha-01 '- `src/shared.ts` — owns the upload subsystem.'
mk_doc "$B" beta  beta-01  '- `src/shared.ts` — reuses the upload subsystem.'
if "$RUNNER" "$TMP/repoB" >/dev/null 2>&1; then
  pass "≥1 citing bullet has an ownership qualifier → carved (clean)"
else
  fail "ownership-carved pair wrongly flagged"
fi

# Repo C: qualifier present in the SECTION but on a DIFFERENT bullet than the path
# → NOT carved (same-bullet granularity, start-strict).
C="$TMP/repoC/docs/product/flows"
mk_doc "$C" alpha alpha-01 '- `src/shared.ts` — the upload surface.'
mk_doc "$C" beta  beta-01 \
  '- This flow reuses several primitives.' \
  '- `src/shared.ts` — the dedup surface.'
out_c="$("$RUNNER" "$TMP/repoC" 2>/dev/null || true)"
if printf '%s' "$out_c" | grep -q 'double-credit  src/shared.ts'; then
  pass "qualifier on a different bullet does NOT carve (same-bullet strictness)"
else
  fail "qualifier on a different bullet wrongly carved (out: $(printf '%s' "$out_c" | tr '\n' '|'))"
fi

# Repo G2: two docs in the SAME domain citing the same path, no qualifier → NOT
# flagged (cross-domain by design; same-domain sub-flows legitimately share).
G2="$TMP/repoG2/docs/product/flows"
mk_doc "$G2" alpha alpha-01 '- `src/shared.ts` — surface A.'
mk_doc "$G2" alpha alpha-02 '- `src/shared.ts` — surface B.'
if "$RUNNER" "$TMP/repoG2" >/dev/null 2>&1; then
  pass "same-domain double-citation → NOT flagged (cross-domain scope)"
else
  fail "same-domain sharing wrongly flagged (cross-domain scope not applied)"
fi

# Repo D: a path cited by only ONE doc → never flagged (needs ≥2).
D="$TMP/repoD/docs/product/flows"
mk_doc "$D" alpha alpha-01 '- `src/solo.ts` — only here.'
mk_doc "$D" beta  beta-01  '- `src/other.ts` — elsewhere.'
if "$RUNNER" "$TMP/repoD" >/dev/null 2>&1; then
  pass "single-doc citation → not flagged (≥2 required)"
else
  fail "single citation wrongly flagged"
fi

# Repo E: relationship mentions use flow-IDs (not src/ paths) → grammar excludes
# them → not flagged, even across 2 docs.
E="$TMP/repoE/docs/product/flows"
mk_doc "$E" alpha alpha-01 '- Downstream consumer — `analytics-dashboard-02` aggregates events.'
mk_doc "$E" beta  beta-01  '- Downstream consumer — `analytics-dashboard-02` reads events.'
if "$RUNNER" "$TMP/repoE" >/dev/null 2>&1; then
  pass "flow-ID relationship mentions (no src/ path) → not flagged"
else
  fail "flow-ID mentions wrongly flagged as double-credit"
fi

# Repo F: brace-family overlap — `{a,b}.ts` in one doc, bare `a.ts` in another →
# the real file src/a.ts overlaps → FLAGGED (expanded-token keying).
F="$TMP/repoF/docs/product/flows"
mk_doc "$F" alpha alpha-01 '- `src/api/{a,b}.ts` — the pair.'
mk_doc "$F" beta  beta-01  '- `src/api/a.ts` — just a.'
out_f="$("$RUNNER" "$TMP/repoF" 2>/dev/null || true)"
if printf '%s' "$out_f" | grep -q 'double-credit  src/api/a.ts'; then
  pass "brace-family vs bare path overlap detected at the real-file level"
else
  fail "brace-family overlap missed (out: $(printf '%s' "$out_f" | tr '\n' '|'))"
fi

printf '\nflow-double-credit-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
