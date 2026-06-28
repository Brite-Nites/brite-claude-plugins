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

# ── §12: redirect-stub emission (BC-12907) ────────────────────────────
section "12" "redirect stub: --doc-type redirect emits REDIRECT_CANON, round-trips the lint, guards"
python3 "$BUILDER" --flow-id SFI-05 --as-of "$AS_OF" --doc-type redirect --redirect-to ACL-06 \
  > "$TMP/redirect.out" 2>"$TMP/redirect.err" \
  && pass "redirect emit exits 0 (no scaffold-log needed)" \
  || { fail "redirect emit non-zero"; cat "$TMP/redirect.err" >&2; }
if grep -q '^doc_type: redirect$' "$TMP/redirect.out" && grep -q '^redirect_to: ACL-06$' "$TMP/redirect.out" \
   && ! grep -qE '^(children|status|personas|qa_status):' "$TMP/redirect.out"; then
  pass "redirect frontmatter has doc_type+redirect_to, no story-only keys"
else
  fail "redirect frontmatter shape wrong"; cat "$TMP/redirect.out" >&2
fi
RLINT="$(python3 - "$PLUGIN_ROOT/scripts/lib" "$TMP/redirect.out" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_frontmatter_lint as m
r = m.lint_text(open(sys.argv[2]).read(), "redirect")
print("%d %d" % (len(r["missing"]), len(r["drift"])))
PY
)"
[ "$RLINT" = "0 0" ] \
  && pass "emitted redirect round-trips REDIRECT_CANON (0 missing / 0 drift)" \
  || fail "emitted redirect fails its own lint: missing/drift=$RLINT"
python3 "$BUILDER" --flow-id SFI-05 --as-of "$AS_OF" --doc-type redirect >/dev/null 2>&1 \
  && fail "redirect without --redirect-to should exit 2" \
  || pass "redirect without --redirect-to → exit 2"
python3 "$BUILDER" --flow-id SFI-05 --as-of "$AS_OF" >/dev/null 2>&1 \
  && fail "story without --scaffold-log should exit 2" \
  || pass "story without --scaffold-log → exit 2"

# ── §13: last_reviewed is YAML-quoted (BC-13796) ──────────────────────
# Stdlib-only proxy for "yaml.safe_load(...)['last_reviewed'] is str": for an ISO
# YYYY-MM-DD, quoted ⟺ string, unquoted ⟺ YAML coerces it to a date. Locks the value
# type-consistent with consumer repos (which quote it); the line-based lint is blind to
# this, so assert the emitted FORM here.
section "13" "last_reviewed emitted quoted (no YAML date-coercion)"
for out in "$TMP/WGT-01.out" "$TMP/redirect.out"; do
  if grep -qE "^last_reviewed: '[0-9]{4}-[0-9]{2}-[0-9]{2}'\$" "$out"; then
    pass "$(basename "$out"): last_reviewed is quoted"
  else
    fail "$(basename "$out"): last_reviewed NOT quoted — YAML would coerce to a date: $(grep '^last_reviewed:' "$out")"
  fi
done

# ── §14: list tokens YAML-coercion-guarded (BC-13797) ─────────────────
# personas/related_flows tokens are double-quoted IFF YAML would coerce them
# (off→bool, 123→int, 2024-01-01→date); safe slugs stay raw. Without the guard a
# `personas: [off]` parses as [False].
section "14" "list tokens quoted iff YAML-coercion-prone (off/123/date), safe raw"
python3 "$BUILDER" --scaffold-log "$LOG" --flow-id WGT-01 --as-of "$AS_OF" \
  --personas "operator,off,123" --related-flows "WGT-02,2024-01-01" > "$TMP/coerce.out" 2>/dev/null
if grep -qxF 'personas: [operator, "off", "123"]' "$TMP/coerce.out" \
   && grep -qxF 'related_flows: [WGT-02, "2024-01-01"]' "$TMP/coerce.out"; then
  pass "coercing list tokens quoted, safe tokens raw"
else
  fail "list tokens not coercion-guarded: $(grep -E '^(personas|related_flows):' "$TMP/coerce.out")"
fi
# domain (flow_id prefix) is coercion-guarded too — a prefix like ON/NO/OFF coerces
# (case-insensitive). Tested via the redirect path (no scaffold-log needed); _emit and
# _emit_redirect share the identical guarded `domain:` line (BC-13797 review-fix).
python3 "$BUILDER" --flow-id ON-01 --doc-type redirect --redirect-to WGT-01 --as-of "$AS_OF" > "$TMP/coerce-dom.out" 2>/dev/null
if grep -qxF 'domain: "ON"' "$TMP/coerce-dom.out"; then
  pass "coercion-prone domain prefix (ON) quoted"
else
  fail "domain prefix not coercion-guarded: $(grep '^domain:' "$TMP/coerce-dom.out")"
fi

# ── §15: slash-form opaque flow_id (ADR-040, brite-sites shape) ───────
# End-to-end proof that an opaque slash-form flow_id (`<domain>/<slug>`) works:
# accepted by the relaxed _FLOW_ID_RE, domain read from the scaffold-log's explicit
# domain_code (NOT split out of flow_id → the load-bearing landmine: split("-") would
# yield "admin"), and children/parent matched by the shape-agnostic _cell_is_flow.
section "15" "slash-form flow_id: accepted, domain from scaffold-log domain_code, children matched"
SLASHLOG="$TMP/slash-log.md"
{
  printf -- '---\n'
  printf -- 'domain: admin-panel\n'
  printf -- 'domain_code: admin-panel\n'
  printf -- 'linear_milestone_id: 9a059ce3-ec63-4c82-92c8-6f4a0fa11612\n'
  printf -- 'linear_milestone_name: Admin Panel\n'
  printf -- '---\n\n'
  printf -- '## Parents\n\n'
  printf -- '| # | Sub-flow | Linear identifier | Result |\n'
  printf -- '|---|---|---|---|\n'
  printf -- '| 2 | admin-panel/layout-and-auth — Operator signs in | BC-30001 | executed |\n\n'
  printf -- '## Discipline children\n\n'
  printf -- '| Sub-flow | Story | Engineering | Design | QA | Docs | Result |\n'
  printf -- '|---|---|---|---|---|---|---|\n'
  printf -- '| admin-panel/layout-and-auth | BC-30002 | BC-30003 | BC-30004 | BC-30005 | BC-30006 | executed |\n'
} > "$SLASHLOG"
python3 "$BUILDER" --scaffold-log "$SLASHLOG" --flow-id admin-panel/layout-and-auth --as-of "$AS_OF" \
  --personas operator > "$TMP/slash.out" 2>"$TMP/slash.err" \
  || { fail "builder exited non-zero on slash-form flow_id (ADR-040 regression)"; cat "$TMP/slash.err" >&2; }
grep -qxF 'flow_id: admin-panel/layout-and-auth' "$TMP/slash.out" \
  && pass "slash-form flow_id accepted + emitted verbatim (opaque, not DOMAIN-NN)" \
  || fail "slash-form flow_id not emitted"
grep -qxF 'domain: admin-panel' "$TMP/slash.out" \
  && pass "domain from scaffold-log domain_code (NOT split → 'admin' — the landmine)" \
  || fail "domain not resolved from scaffold-log domain_code: $(grep '^domain:' "$TMP/slash.out")"
grep -qxF '  story: BC-30002' "$TMP/slash.out" \
  && pass "slash-form Sub-flow cell matched (children populated, shape-agnostic)" \
  || fail "slash-form children cell silently missed → all-TBD regression"
grep -qxF 'parent_issue: BC-30001' "$TMP/slash.out" \
  && pass "slash-form annotated parents cell matched" \
  || fail "slash-form parents cell not matched"

# ── §16: coercion-prone OPAQUE flow_id / redirect_to are YAML-quoted ───
# The relaxed _FLOW_ID_RE (ADR-040) now admits bare coercion-prone ids (off / 2024); like
# personas/domain, every flow_id-family emission must be _yaml_safe_token-guarded or a YAML
# consumer silently reads a bool/int instead of the string id. Covers _emit (story flow_id) +
# _emit_redirect (redirect flow_id + redirect_to).
section "16" "coercion-prone opaque flow_id + redirect_to emitted quoted (no YAML bool/int coercion)"
COERCELOG="$TMP/coerce-log.md"
{
  printf -- '---\ndomain_code: ops\n---\n\n'
  printf -- '## Parents\n\n| # | Sub-flow | Linear identifier | Result |\n|---|---|---|---|\n'
  printf -- '| 2 | off — Toggle widget | BC-40001 | executed |\n'
} > "$COERCELOG"
python3 "$BUILDER" --scaffold-log "$COERCELOG" --flow-id off --as-of "$AS_OF" \
  > "$TMP/coerce-story.out" 2>/dev/null || true
grep -qxF 'flow_id: "off"' "$TMP/coerce-story.out" \
  && pass "story-path coercion-prone flow_id (off) quoted (parses as str, not bool)" \
  || fail "story flow_id not coercion-guarded: $(grep '^flow_id:' "$TMP/coerce-story.out")"
python3 "$BUILDER" --flow-id 2024 --as-of "$AS_OF" --doc-type redirect --redirect-to off --domain ops \
  > "$TMP/coerce-redirect.out" 2>/dev/null || true
grep -qxF 'flow_id: "2024"' "$TMP/coerce-redirect.out" \
  && pass "redirect-path coercion-prone flow_id (2024) quoted (parses as str, not int)" \
  || fail "redirect flow_id not coercion-guarded: $(grep '^flow_id:' "$TMP/coerce-redirect.out")"
grep -qxF 'redirect_to: "off"' "$TMP/coerce-redirect.out" \
  && pass "redirect_to coercion-prone target (off) quoted (resolver reads str, not bool)" \
  || fail "redirect_to not coercion-guarded: $(grep '^redirect_to:' "$TMP/coerce-redirect.out")"
# Radix literals (hex/octal) are digit-led but NOT matched by the enumerated coercion regex —
# the all-digit-led quote rule must catch them, else `0x1A` parses back as int 26.
python3 "$BUILDER" --flow-id 0x1A --as-of "$AS_OF" --doc-type redirect --redirect-to 0o17 --domain ops \
  > "$TMP/coerce-radix.out" 2>/dev/null || true
grep -qxF 'flow_id: "0x1A"' "$TMP/coerce-radix.out" \
  && pass "radix-literal flow_id (0x1A) quoted (parses as str, not hex int)" \
  || fail "radix flow_id not coercion-guarded: $(grep '^flow_id:' "$TMP/coerce-radix.out")"
grep -qxF 'redirect_to: "0o17"' "$TMP/coerce-radix.out" \
  && pass "radix-literal redirect_to (0o17) quoted (parses as str, not octal int)" \
  || fail "radix redirect_to not coercion-guarded: $(grep '^redirect_to:' "$TMP/coerce-radix.out")"

# ── §17: backtick-wrapped Sub-flow id WITH a description still matches ──
# A parents cell `` `<id>` — <desc> `` (backtick-wrapped id + description) must match — else a
# whole-cell strip("`") leaves the closing backtick interior and silently degrades parent to TBD
# (the exact all-TBD miss _cell_is_flow exists to prevent). The bare-backticked + plain-with-desc
# cells are already covered by §7/§1; this pins the combined form.
section "17" "backtick-wrapped id WITH description matches (no silent parent-TBD)"
BTLOG="$TMP/backtick-log.md"
{
  printf -- '---\ndomain_code: WGT\n---\n\n'
  printf -- '## Parents\n\n| # | Sub-flow | Linear identifier | Result |\n|---|---|---|---|\n'
  printf -- '| 2 | `WGT-77` — Backtick-wrapped with desc | BC-77001 | executed |\n'
} > "$BTLOG"
python3 "$BUILDER" --scaffold-log "$BTLOG" --flow-id WGT-77 --as-of "$AS_OF" \
  > "$TMP/backtick.out" 2>/dev/null || true
grep -qxF 'parent_issue: BC-77001' "$TMP/backtick.out" \
  && pass "backtick-wrapped id with desc matched (parent stamped, not TBD)" \
  || fail "backtick-wrapped id with desc silently missed → parent: $(grep '^parent_issue:' "$TMP/backtick.out")"

printf '\n──────────\n%d passed, %d failed\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
