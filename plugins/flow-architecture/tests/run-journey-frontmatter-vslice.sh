#!/usr/bin/env bash
# BC-13028 journey-doc frontmatter-stamp v-slice — exercises the deterministic
# `scripts/build_journey_frontmatter.py` builder against fixture scaffold-logs
# (frontmatter shape per `templates/.flow/scaffold-log/SCHEMA.md`) plus a fixture
# story-doc dir (the post-BC-13168 standardized aggregation source per ADR-033).
# Bash 3.2 compatible; stdlib python3 only. The ADR-028 D2-style deterministic
# lock for flow-journey-author's frontmatter stamping (skill, outside
# COMMAND_GLOB — no command-eval ceremony). Right-sized to the journey's small
# deterministic surface (ADR-033) — deliberately not a clone of the 27-assertion
# story harness.
#
# Scenarios:
#   §1 happy       — golden byte-compare + populated-key invariants (milestone
#                    UUID, non-empty personas/flow_ids — the regression BC-13028
#                    #4 exists to kill).
#   §2 dedup       — personas first-seen dedup walking flow_id order; flow-style
#                    AND block-style lists both parsed.
#   §3 natsort     — WGT-10 sorts after WGT-2/WGT-3 (numeric suffix, not
#                    lexicographic).
#   §4 degrade     — missing `domain` → TBD; junk milestone UUID → TBD;
#                    YAML-unsafe milestone name → double-quoted, never raw.
#   §4b/§4c        — numeric/YAML-keyword name → double-quoted (bare `2024`
#                    would coerce to int); missing name → TBD.
#   §5 skip        — no-frontmatter, junk-flow_id, and unterminated-frontmatter
#                    docs excluded without abort (leak grep pins sentinels).
#   §5b totality   — a >9-digit flow_id suffix is a VALID opaque id (ADR-040) →
#                    aggregated via _natural_key's lexicographic degrade branch,
#                    never an uncaught int() ValueError (CPython int_max_str_digits).
#   §6 empty dir   — zero valid story docs → exit 2 (Q16.8 ordering violation).
#   §7 no log      — missing scaffold-log → exit 2.
#   §8 bad as-of   — malformed --as-of → exit 2; missing required arg → exit 2
#                    (argparse usage path, pinned).
#   §9 determinism — two runs byte-identical.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILDER="$PLUGIN_ROOT/scripts/build_journey_frontmatter.py"
FIXTURE="$SCRIPT_DIR/fixtures/journey-frontmatter-stamp"
LOG="$FIXTURE/.flow/scaffold-log/widget-intake.md"
BROKEN_LOG="$FIXTURE/.flow/scaffold-log/broken-widget.md"
FLOWS="$FIXTURE/docs/product/flows/widget-intake"
GOLDEN_DIR="$FIXTURE/golden"
AS_OF="2026-06-11"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$BUILDER" ] || { echo "fatal: builder not found at $BUILDER" >&2; exit 127; }
[ -f "$LOG" ] || { echo "fatal: fixture scaffold-log not found at $LOG" >&2; exit 127; }
[ -d "$FLOWS" ] || { echo "fatal: fixture flows dir not found at $FLOWS" >&2; exit 127; }

PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Shared exit-2 expectation (§6-§8) — label first, then builder args.
expect_exit2() {
  local label="$1"; shift
  set +e
  python3 "$BUILDER" "$@" > /dev/null 2>"$TMP/exit2.err"
  local rc=$?
  set -e
  if [ "$rc" -eq 2 ]; then
    pass "$label"
  else
    fail "$label — exited $rc (want 2)"; cat "$TMP/exit2.err" >&2
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── §1: happy path — golden compare + populated-key invariants ─────────
section "1" "happy path stamps the ADR-033 canonical frontmatter"
python3 "$BUILDER" --scaffold-log "$LOG" --flows-dir "$FLOWS" --as-of "$AS_OF" \
  > "$TMP/happy.out" 2>"$TMP/happy.err" \
  || { fail "builder exited non-zero on the happy path (foundational — aborting)"; \
       cat "$TMP/happy.err" >&2; \
       printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"; exit 1; }
if diff -u "$GOLDEN_DIR/happy.frontmatter" "$TMP/happy.out" >"$TMP/happy.diff" 2>&1; then
  pass "happy output byte-matches golden"
else
  fail "happy output drifted from golden"; cat "$TMP/happy.diff" >&2
fi
# Populated-key invariants — the exact checks that would catch the
# empty-frontmatter regression: real UUID, non-empty lists, never placeholders.
if grep -qE '^  id: [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' "$TMP/happy.out"; then
  pass "linear_milestone.id is a populated UUID (not TBD)"
else
  fail "linear_milestone.id is not a populated UUID"
fi
if grep -qE '^personas: \[[a-z]' "$TMP/happy.out"; then
  pass "personas is populated (not [])"
else
  fail "personas is empty or missing"
fi
if grep -qE '^flow_ids_in_scope: \[WGT-' "$TMP/happy.out"; then
  pass "flow_ids_in_scope is populated (not [])"
else
  fail "flow_ids_in_scope is empty or missing"
fi

# ── §2: dedup + both list styles ───────────────────────────────────────
section "2" "personas first-seen dedup across flow-style + block-style lists"
if grep -qF 'personas: [operator, tm, finance-auditor, "off", intake-clerk]' "$TMP/happy.out"; then
  pass "personas dedup'd first-seen in flow_id order; YAML-keyword token quoted"
else
  fail "personas line wrong (dedup/order/list-style parse/keyword quoting)"; grep '^personas:' "$TMP/happy.out" >&2 || true
fi

# ── §3: natural sort ───────────────────────────────────────────────────
section "3" "flow_ids natural-sorted by numeric suffix"
if grep -qF 'flow_ids_in_scope: [WGT-1, WGT-2, WGT-3, WGT-10]' "$TMP/happy.out"; then
  pass "WGT-10 sorts after WGT-3 (natural, not lexicographic)"
else
  fail "flow_ids_in_scope ordering wrong"; grep '^flow_ids_in_scope:' "$TMP/happy.out" >&2 || true
fi

# ── §4: degrade, never malform ─────────────────────────────────────────
section "4" "degraded scaffold-log: TBD + quoted-name, never raw/malformed YAML"
if python3 "$BUILDER" --scaffold-log "$BROKEN_LOG" --flows-dir "$FLOWS" --as-of "$AS_OF" \
    > "$TMP/degraded.out" 2>"$TMP/degraded.err"; then
  if diff -u "$GOLDEN_DIR/degraded.frontmatter" "$TMP/degraded.out" >"$TMP/degraded.diff" 2>&1; then
    pass "degraded output byte-matches golden"
  else
    fail "degraded output drifted from golden"; cat "$TMP/degraded.diff" >&2
  fi
  grep -qF 'domain: TBD' "$TMP/degraded.out" \
    && pass "missing domain key degrades to TBD" \
    || fail "missing domain key did not degrade to TBD"
  grep -qF '  id: TBD' "$TMP/degraded.out" \
    && pass "junk milestone UUID degrades to TBD" \
    || fail "junk milestone UUID did not degrade to TBD"
  grep -qF '  name: "Broken & Widget: <v2>"' "$TMP/degraded.out" \
    && pass "YAML-unsafe milestone name emitted double-quoted" \
    || fail "YAML-unsafe milestone name not safely quoted"
else
  fail "builder exited non-zero on the degraded log (degrade must stay exit 0)"
  cat "$TMP/degraded.err" >&2
fi

# ── §4b: numeric milestone name must emit double-quoted ────────────────
section "4b" "numeric / YAML-keyword milestone name emits double-quoted"
printf -- '---\ndomain: numeric-widget\nlinear_milestone_id: 7f3c2a10-aaaa-4bbb-8ccc-0123456789ab\nlinear_milestone_name: 2024\n---\nbody\n' > "$TMP/numeric-log.md"
python3 "$BUILDER" --scaffold-log "$TMP/numeric-log.md" --flows-dir "$FLOWS" --as-of "$AS_OF" \
  > "$TMP/numeric.out" 2>/dev/null || true
if grep -qF 'display_name: "2024"' "$TMP/numeric.out" && grep -qF '  name: "2024"' "$TMP/numeric.out"; then
  pass "name 2024 emitted quoted (bare 2024 would YAML-coerce to int)"
else
  fail "numeric milestone name not safely quoted"; grep -E 'display_name|^  name' "$TMP/numeric.out" >&2 || true
fi
printf -- '---\ndomain: dated-widget\nlinear_milestone_id: 7f3c2a10-aaaa-4bbb-8ccc-0123456789ab\nlinear_milestone_name: 2026-01-01\n---\nbody\n' > "$TMP/dated-log.md"
python3 "$BUILDER" --scaffold-log "$TMP/dated-log.md" --flows-dir "$FLOWS" --as-of "$AS_OF" \
  > "$TMP/dated.out" 2>/dev/null || true
if grep -qF 'display_name: "2026-01-01"' "$TMP/dated.out" && grep -qF '  name: "2026-01-01"' "$TMP/dated.out"; then
  pass "date-shaped name emitted quoted (bare 2026-01-01 would YAML-coerce to date)"
else
  fail "date-shaped milestone name not safely quoted"; grep -E 'display_name|^  name' "$TMP/dated.out" >&2 || true
fi

# ── §4c: missing milestone name degrades to TBD ────────────────────────
section "4c" "missing milestone name degrades to TBD"
printf -- '---\ndomain: no-name-widget\nlinear_milestone_id: 7f3c2a10-aaaa-4bbb-8ccc-0123456789ab\n---\nbody\n' > "$TMP/noname-log.md"
python3 "$BUILDER" --scaffold-log "$TMP/noname-log.md" --flows-dir "$FLOWS" --as-of "$AS_OF" \
  > "$TMP/noname.out" 2>/dev/null || true
if grep -qF 'display_name: TBD' "$TMP/noname.out" && grep -qF '  name: TBD' "$TMP/noname.out"; then
  pass "missing name → TBD (display_name + linear_milestone.name)"
else
  fail "missing milestone name did not degrade to TBD"; grep -E 'display_name|^  name' "$TMP/noname.out" >&2 || true
fi

# ── §4d: coercion-prone kebab domain is YAML-quoted (BC-13797) ─────────
# A single-token kebab domain like `off`/`on`/`2024` passes _KEBAB_RE but YAML
# would coerce it (off→bool, 2024→int); it must be quoted to stay a string.
section "4d" "coercion-prone kebab domain (off) is YAML-quoted"
printf -- '---\ndomain: off\nlinear_milestone_id: 7f3c2a10-aaaa-4bbb-8ccc-0123456789ab\nlinear_milestone_name: Widgets\n---\nbody\n' > "$TMP/coerce-domain-log.md"
python3 "$BUILDER" --scaffold-log "$TMP/coerce-domain-log.md" --flows-dir "$FLOWS" --as-of "$AS_OF" \
  > "$TMP/coerce-domain.out" 2>/dev/null || true
if grep -qxF 'domain: "off"' "$TMP/coerce-domain.out"; then
  pass "coercion-prone domain quoted (parses as str, not bool)"
else
  fail "domain not coercion-guarded: $(grep '^domain:' "$TMP/coerce-domain.out")"
fi

# ── §5: skip-don't-crash ───────────────────────────────────────────────
section "5" "stray / junk-flow_id / unterminated docs are skipped whole, never aborting"
if grep -qE 'stray|ghost-persona|not-a-flow|leaky-persona|WGT-7' "$TMP/happy.out"; then
  fail "skipped-doc content leaked into the output"
else
  pass "no-frontmatter + junk-flow_id + unterminated-frontmatter docs excluded"
fi

# ── §5b: over-long flow_id suffix — valid opaque id (ADR-040), aggregated via the
#         lexicographic degrade branch, never an uncaught int() crash ──
section "5b" "a >9-digit flow_id suffix is a valid opaque id, sorted without int() crash (ADR-040)"
mkdir -p "$TMP/long-flows"
cp "$FLOWS/WGT-1.md" "$TMP/long-flows/"
{ printf -- '---\nflow_id: WGT-'; printf '9%.0s' $(seq 1 5000); printf -- '\npersonas: [longsuffix-persona]\n---\nbody\n'; } > "$TMP/long-flows/long.md"
set +e
python3 "$BUILDER" --scaffold-log "$LOG" --flows-dir "$TMP/long-flows" --as-of "$AS_OF" \
  > "$TMP/long.out" 2>"$TMP/long.err"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  pass "exit 0 — _natural_key opaque branch avoids int() on the >9-digit suffix (CPython 4300-digit guard)"
else
  fail "over-long suffix exited $rc (want 0)"; cat "$TMP/long.err" >&2
fi
# Under ADR-040 the id is a valid opaque slug (safe charset), so it IS aggregated — it is
# no longer dropped the way the old DOMAIN-NN-only `\d{1,9}` regex skipped it whole.
if grep -qF 'longsuffix-persona' "$TMP/long.out"; then
  pass "over-long-suffix opaque id aggregated, not skipped (ADR-040)"
else
  fail "over-long-suffix opaque id was dropped (should aggregate under ADR-040)"
fi

# ── §6: empty flows-dir → exit 2 ───────────────────────────────────────
section "6" "zero valid story docs fails loud (exit 2)"
mkdir -p "$TMP/empty-flows"
expect_exit2 "empty flows-dir exits 2 (Q16.8 ordering violation is loud)" \
  --scaffold-log "$LOG" --flows-dir "$TMP/empty-flows" --as-of "$AS_OF"

# ── §7: missing scaffold-log → exit 2 ──────────────────────────────────
section "7" "missing scaffold-log fails loud (exit 2)"
expect_exit2 "missing scaffold-log exits 2" \
  --scaffold-log "$TMP/no-such-log.md" --flows-dir "$FLOWS" --as-of "$AS_OF"

# ── §8: bad --as-of → exit 2 ───────────────────────────────────────────
section "8" "malformed --as-of fails loud (exit 2)"
expect_exit2 "malformed --as-of exits 2" \
  --scaffold-log "$LOG" --flows-dir "$FLOWS" --as-of "06/11/2026"
expect_exit2 "missing required --flows-dir exits 2 (argparse usage path)" \
  --scaffold-log "$LOG" --as-of "$AS_OF"

# ── §9: determinism ────────────────────────────────────────────────────
section "9" "re-run is byte-identical"
python3 "$BUILDER" --scaffold-log "$LOG" --flows-dir "$FLOWS" --as-of "$AS_OF" \
  > "$TMP/happy2.out" 2>/dev/null || true
if cmp -s "$TMP/happy.out" "$TMP/happy2.out"; then
  pass "two runs byte-identical"
else
  fail "output differs across runs (non-determinism)"
fi

# last_reviewed is YAML-quoted (BC-13796): stdlib-only proxy for "parses as str" —
# for an ISO YYYY-MM-DD, quoted ⟺ string, unquoted ⟺ YAML date-coercion. Keeps the
# value type-consistent with consumer repos (which quote it).
section "10" "last_reviewed emitted quoted (no YAML date-coercion)"
if grep -qE "^last_reviewed: '[0-9]{4}-[0-9]{2}-[0-9]{2}'\$" "$TMP/happy.out"; then
  pass "journey last_reviewed is quoted"
else
  fail "journey last_reviewed NOT quoted — YAML would coerce to a date: $(grep '^last_reviewed:' "$TMP/happy.out")"
fi

# ── §11: slash-form opaque flow_ids aggregate (ADR-040, brite-sites shape) ──
# End-to-end proof that slash-form story docs aggregate into flow_ids_in_scope (no
# DOMAIN-NN skip), ordered by _natural_key's lexicographic degrade branch — matching
# the real brite-sites journey (alphabetical [admin-panel/..., admin-panel/...]).
section "11" "slash-form flow_ids: aggregated + lexicographically ordered (opaque degrade branch)"
mkdir -p "$TMP/slash-flows"
printf -- '---\nflow_id: admin-panel/website-management\ndomain: admin-panel\npersonas: [brite-nites-ops]\n---\nbody\n' > "$TMP/slash-flows/website-management.md"
printf -- '---\nflow_id: admin-panel/layout-and-auth\ndomain: admin-panel\npersonas: [brite-nites-ops]\n---\nbody\n' > "$TMP/slash-flows/layout-and-auth.md"
printf -- '---\ndomain: admin-panel\ndomain_code: admin-panel\nlinear_milestone_id: 9a059ce3-ec63-4c82-92c8-6f4a0fa11612\nlinear_milestone_name: Admin Panel\n---\nbody\n' > "$TMP/slash-journey-log.md"
python3 "$BUILDER" --scaffold-log "$TMP/slash-journey-log.md" --flows-dir "$TMP/slash-flows" --as-of "$AS_OF" \
  > "$TMP/slash-journey.out" 2>"$TMP/slash-journey.err" \
  || { fail "journey builder exited non-zero on slash-form flows (ADR-040 regression)"; cat "$TMP/slash-journey.err" >&2; }
if grep -qxF 'flow_ids_in_scope: [admin-panel/layout-and-auth, admin-panel/website-management]' "$TMP/slash-journey.out"; then
  pass "slash-form flow_ids aggregated + lexicographically ordered (no DOMAIN-NN skip, no int() crash)"
else
  fail "slash-form flow_ids_in_scope wrong: $(grep '^flow_ids_in_scope:' "$TMP/slash-journey.out")"
fi
grep -qxF 'domain: admin-panel' "$TMP/slash-journey.out" \
  && pass "journey domain from scaffold-log frontmatter (kebab path, unchanged)" \
  || fail "journey domain wrong: $(grep '^domain:' "$TMP/slash-journey.out")"

# ── §12: coercion-prone opaque flow_id is YAML-quoted in flow_ids_in_scope ──
# The relaxed _FLOW_ID_RE (ADR-040) admits bare coercion-prone ids (off / 2024); each must be
# _yaml_safe_token-guarded in the flow_ids_in_scope list (as personas already are) or a YAML
# consumer reads [False]/[2024] instead of the string id.
section "12" "coercion-prone opaque flow_id quoted in flow_ids_in_scope (no YAML bool coercion)"
mkdir -p "$TMP/coerce-flows"
printf -- '---\nflow_id: off\ndomain: ops\npersonas: [op]\n---\nbody\n' > "$TMP/coerce-flows/off.md"
printf -- '---\ndomain: ops\ndomain_code: ops\nlinear_milestone_id: 7f3c2a10-aaaa-4bbb-8ccc-0123456789ab\nlinear_milestone_name: Ops\n---\nbody\n' > "$TMP/coerce-journey-log.md"
python3 "$BUILDER" --scaffold-log "$TMP/coerce-journey-log.md" --flows-dir "$TMP/coerce-flows" --as-of "$AS_OF" \
  > "$TMP/coerce-journey.out" 2>/dev/null || true
if grep -qxF 'flow_ids_in_scope: ["off"]' "$TMP/coerce-journey.out"; then
  pass "coercion-prone flow_id quoted in flow_ids_in_scope (parses as str, not bool)"
else
  fail "flow_ids_in_scope not coercion-guarded: $(grep '^flow_ids_in_scope:' "$TMP/coerce-journey.out")"
fi

printf '\nRESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
