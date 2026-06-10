#!/usr/bin/env bash
# BC-13168 story-doc frontmatter-stamp v-slice — exercises the deterministic
# `scripts/build_story_frontmatter.py` builder against a fixture scaffold-log
# (the canonical table shape per `templates/.flow/scaffold-log/SCHEMA.md`,
# modeled on a real brite-roster produced log). Bash 3.2 compatible; stdlib
# python3 only. The ADR-028 D2-style deterministic lock for flow-doc-author's
# frontmatter stamping (skill, outside COMMAND_GLOB — no command-eval ceremony).
#
# Scenarios:
#   WGT-01 — happy: params provided (--status BUILT override + --personas +
#            --related-flows) → golden shows POPULATED children/personas/parent.
#   WGT-02 — backticked children Sub-flow cell + annotated parent cell still match.
#   WGT-03 — errored sub-flow, empty (`—`) Design child cell → degrade to `TBD`.
#   WGT-04 — parents-only flow (no children row) → real parent + all-`TBD` children.
#   WGT-05 — junk parent id cell (`err: rate-limited`) → TBD, never raw into YAML.
#   WGT-06 — duplicate children rows → last-wins (idempotent in-place rewrite).
#   plus determinism, unknown-flow-id→exit 2, and caller-param validation→exit 2.
#
# The populated-key assertions (§3) are the exact check that would have caught
# the empty-frontmatter regression #4 exists to kill: children/personas/parent
# on the happy path MUST be real values, never `TBD`/`[]`/placeholder.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILDER="$PLUGIN_ROOT/scripts/build_story_frontmatter.py"
FIXTURE="$SCRIPT_DIR/fixtures/story-frontmatter-stamp"
LOG="$FIXTURE/.flow/scaffold-log/widget-intake.md"
GOLDEN_DIR="$FIXTURE/golden"
AS_OF="2026-06-10"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$BUILDER" ] || { echo "fatal: builder not found at $BUILDER" >&2; exit 127; }
[ -f "$LOG" ] || { echo "fatal: fixture scaffold-log not found at $LOG" >&2; exit 127; }

PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── §1: WGT-01 happy path — golden compare ────────────────────────────
section "1" "WGT-01 happy path stamps the canonical template frontmatter"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-01 --as-of "$AS_OF" \
  --status BUILT --personas operator,tm --related-flows WGT-02 \
  > "$TMP/WGT-01.out" 2>"$TMP/WGT-01.err" \
  || { fail "builder exited non-zero for WGT-01 (foundational happy path — aborting)"; \
       cat "$TMP/WGT-01.err" >&2; \
       printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"; exit 1; }
if diff -u "$GOLDEN_DIR/WGT-01.frontmatter" "$TMP/WGT-01.out" >"$TMP/WGT-01.diff" 2>&1; then
  pass "WGT-01 output byte-matches golden"
else
  fail "WGT-01 output drifted from golden"; cat "$TMP/WGT-01.diff" >&2
fi

# ── §2: WGT-03 edge — defaults + missing Design child → golden compare ─
section "2" "WGT-03 edge (errored sub-flow, missing Design child, no params)"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-03 --as-of "$AS_OF" \
  > "$TMP/WGT-03.out" 2>"$TMP/WGT-03.err" \
  || { fail "builder exited non-zero for WGT-03"; cat "$TMP/WGT-03.err" >&2; }
if diff -u "$GOLDEN_DIR/WGT-03.frontmatter" "$TMP/WGT-03.out" >"$TMP/WGT-03.diff" 2>&1; then
  pass "WGT-03 output byte-matches golden"
else
  fail "WGT-03 output drifted from golden"; cat "$TMP/WGT-03.diff" >&2
fi

# ── §3: populated-key invariants (the regression #4 exists to kill) ────
section "3" "Happy-path frontmatter is POPULATED, not placeholder"
# Per-slot exact-BC assertion — catches BOTH the literal-TBD form AND the
# empty-value form (`  story:` with no value, which is what the original bug
# actually shipped); this exact-value check is the load-bearing regression lock.
slot_ok=1
for pair in "story:BC-20002" "engineering:BC-20003" "design:BC-20004" "qa:BC-20005" "docs:BC-20006"; do
  slot="${pair%%:*}"; bc="${pair#*:}"
  grep -Eq "^  ${slot}: ${bc}\$" "$TMP/WGT-01.out" || { slot_ok=0; fail "children.${slot} not stamped as ${bc}"; }
done
[ "$slot_ok" -eq 1 ] && pass "all 5 children.* are real BC numbers (no empty/TBD slot)"
grep -Eq '^parent_issue: BC-20001$'  "$TMP/WGT-01.out" \
  && pass "parent_issue is a real BC number" \
  || fail "parent_issue not populated"
grep -Eq '^personas: \[operator, tm\]$' "$TMP/WGT-01.out" \
  && pass "personas populated from --personas (non-empty)" \
  || fail "personas not populated from param"
grep -Eq '^related_flows: \[WGT-02\]$' "$TMP/WGT-01.out" \
  && pass "related_flows populated from --related-flows (non-empty)" \
  || fail "related_flows not populated from param"
grep -Eq '^status: BUILT$'           "$TMP/WGT-01.out" \
  && pass "--status override beats the NOT_STARTED default" \
  || fail "--status override not honored"
# Negative: no literal TBD leaked in the happy children block (the 5 indented child
# slot lines only — bounded so a future personas/related_flows TBD can't mask it).
if grep -E '^  (story|engineering|design|qa|docs): ' "$TMP/WGT-01.out" | grep -q 'TBD'; then
  fail "happy-path children block still contains a TBD placeholder"
else
  pass "happy-path children block has zero TBD placeholders"
fi

# ── §4: missing-child degrades to TBD (graceful, not a crash) ──────────
section "4" "Missing/errored child cell degrades to TBD"
grep -Eq '^  design: TBD$'           "$TMP/WGT-03.out" \
  && pass "WGT-03 missing Design child → design: TBD" \
  || fail "WGT-03 missing Design child not degraded to TBD"
grep -Eq '^  story: BC-20014$'       "$TMP/WGT-03.out" \
  && pass "WGT-03 present children still stamped from the log" \
  || fail "WGT-03 present children not stamped"
grep -Eq '^status: NOT_STARTED$'     "$TMP/WGT-03.out" \
  && pass "default status NOT_STARTED when --status absent" \
  || fail "default status not NOT_STARTED"
grep -Eq '^personas: \[\]$'          "$TMP/WGT-03.out" \
  && pass "personas falls to honest empty [] when --personas absent" \
  || fail "personas not honest-empty without param"

# ── §5: determinism (re-run is byte-identical) ────────────────────────
section "5" "Re-run is byte-identical (no wall-clock / ordering leak)"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-01 --as-of "$AS_OF" \
  --status BUILT --personas operator,tm --related-flows WGT-02 > "$TMP/WGT-01.out2" 2>/dev/null || true
if diff -q "$TMP/WGT-01.out" "$TMP/WGT-01.out2" >/dev/null 2>&1; then
  pass "two runs are byte-identical"
else
  fail "non-deterministic output across runs"
fi

# ── §6: bad flow-id is a clean usage error (exit 2), not a traceback ──
section "6" "Unknown --flow-id exits 2 (usage), not a crash"
if python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-99 --as-of "$AS_OF" >/dev/null 2>"$TMP/WGT-99.err"; then
  fail "unknown flow-id should have failed"
else
  rc=$?
  if [ "$rc" -eq 2 ]; then pass "unknown flow-id → exit 2"; else fail "unknown flow-id → exit $rc (expected 2)"; fi
fi

# ── §7: backticked Sub-flow cell + annotated parent still match (no silent miss) ──
section "7" "WGT-02 (backticked children Sub-flow cell, annotated parent cell)"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-02 --as-of "$AS_OF" \
  --personas operator --related-flows WGT-01,WGT-03 > "$TMP/WGT-02.out" 2>"$TMP/WGT-02.err" \
  || { fail "builder exited non-zero for WGT-02"; cat "$TMP/WGT-02.err" >&2; }
if diff -u "$GOLDEN_DIR/WGT-02.frontmatter" "$TMP/WGT-02.out" >"$TMP/WGT-02.diff" 2>&1; then
  pass "WGT-02 output byte-matches golden"
else
  fail "WGT-02 output drifted from golden"; cat "$TMP/WGT-02.diff" >&2
fi
grep -Eq '^  story: BC-20008$' "$TMP/WGT-02.out" \
  && pass "backticked children Sub-flow cell still matched (children populated, not all-TBD)" \
  || fail "backticked children Sub-flow cell silently missed → all-TBD regression"
grep -Eq '^parent_issue: BC-20007$' "$TMP/WGT-02.out" \
  && pass "annotated parents cell (DOMAIN-NN — desc [annot]) extracted correctly" \
  || fail "annotated parents cell not extracted"

# ── §8: parents-only flow → real parent + all-TBD children (graceful) ──
section "8" "WGT-04 (parents-only, no children row yet)"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-04 --as-of "$AS_OF" \
  > "$TMP/WGT-04.out" 2>"$TMP/WGT-04.err" \
  || { fail "builder exited non-zero for WGT-04"; cat "$TMP/WGT-04.err" >&2; }
if diff -u "$GOLDEN_DIR/WGT-04.frontmatter" "$TMP/WGT-04.out" >"$TMP/WGT-04.diff" 2>&1; then
  pass "WGT-04 output byte-matches golden"
else
  fail "WGT-04 output drifted from golden"; cat "$TMP/WGT-04.diff" >&2
fi
grep -Eq '^parent_issue: BC-20019$' "$TMP/WGT-04.out" \
  && pass "parents-only flow stamps the real parent" \
  || fail "parents-only parent not stamped"
if grep -E '^  (story|engineering|design|qa|docs): ' "$TMP/WGT-04.out" | grep -Eq 'BC-[0-9]'; then
  fail "parents-only flow should have all-TBD children (no BC numbers)"
else
  pass "parents-only flow → all-TBD children (no spurious BC)"
fi

# ── §9: caller-param validation — bad enum/slug → exit 2 (no malformed YAML) ──
section "9" "Invalid --status (closed enum) / --personas (charset) reject with exit 2"
if python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-01 --as-of "$AS_OF" --status 'BUILT # x' >/dev/null 2>&1; then
  fail "off-taxonomy --status should have been rejected"
else
  rc=$?
  [ "$rc" -eq 2 ] && pass "off-taxonomy --status → exit 2 (closed-enum membership)" || fail "bad --status → exit $rc (expected 2)"
fi
if python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-01 --as-of "$AS_OF" --personas 'role: admin' >/dev/null 2>&1; then
  fail "persona slug with YAML metachars should have been rejected"
else
  rc=$?
  [ "$rc" -eq 2 ] && pass "persona slug with YAML metachars → exit 2" || fail "bad persona slug → exit $rc (expected 2)"
fi

# ── §10: junk/non-BC id cell degrades to TBD — never emitted raw into YAML ──
section "10" "WGT-05 (parent id cell 'err: rate-limited' → TBD, no malformed YAML)"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-05 --as-of "$AS_OF" \
  > "$TMP/WGT-05.out" 2>"$TMP/WGT-05.err" \
  || { fail "builder exited non-zero for WGT-05"; cat "$TMP/WGT-05.err" >&2; }
if diff -u "$GOLDEN_DIR/WGT-05.frontmatter" "$TMP/WGT-05.out" >"$TMP/WGT-05.diff" 2>&1; then
  pass "WGT-05 output byte-matches golden"
else
  fail "WGT-05 output drifted from golden"; cat "$TMP/WGT-05.diff" >&2
fi
grep -Eq '^parent_issue: TBD$' "$TMP/WGT-05.out" \
  && pass "non-BC parent id cell ('err: rate-limited') degraded to TBD (parent-TBD branch)" \
  || fail "non-BC parent id cell not degraded to TBD"
# The junk value must NOT leak into the emitted YAML (the malformed-frontmatter path).
if grep -q 'rate-limited' "$TMP/WGT-05.out"; then
  fail "junk id cell leaked into YAML — malformed-frontmatter path still open"
else
  pass "junk id cell did not leak — emitted YAML stays well-formed"
fi

# ── §11: duplicate flow rows resolve last-wins (idempotent in-place rewrite) ──
section "11" "WGT-06 (two children rows → last-wins)"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-06 --as-of "$AS_OF" \
  --status IN_PROGRESS --personas operator > "$TMP/WGT-06.out" 2>"$TMP/WGT-06.err" \
  || { fail "builder exited non-zero for WGT-06"; cat "$TMP/WGT-06.err" >&2; }
if diff -u "$GOLDEN_DIR/WGT-06.frontmatter" "$TMP/WGT-06.out" >"$TMP/WGT-06.diff" 2>&1; then
  pass "WGT-06 output byte-matches golden"
else
  fail "WGT-06 output drifted from golden"; cat "$TMP/WGT-06.diff" >&2
fi
grep -Eq '^  story: BC-26011$' "$TMP/WGT-06.out" \
  && pass "duplicate children rows resolve last-wins (second row's BC stamped)" \
  || fail "duplicate-row last-wins not honored"

printf '\n──────────\n%d passed, %d failed\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
