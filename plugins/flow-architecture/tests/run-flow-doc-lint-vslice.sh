#!/usr/bin/env bash
# Regression-lock for the WS-A reusable story-doc lint lib
# (scripts/lib/flow_doc_lint.sh — A-1 grammar / A-2 persona / A-3 boilerplate /
# FEW_SCENARIOS / D11 FRAME_MISMATCH).
#
# Sources the lib and asserts `lint_story_doc` returns the right verdict on the
# shared synthetic-story-quality fixtures (good + one-per-defect bad). The lib
# is the reusable, MULTI-LINE-AWARE real-doc linter; these single-line fixtures
# prove the same detection holds on the Q27 single-line shape too. (Real
# multi-line GOLD coverage is exercised live against brite-base/brite-sites at
# remediation time; CI fixtures stay single-line + self-contained.)
#
# Bash 3.2 compatible. Stdlib only. No literal backtick in any grep regex.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../scripts/lib/flow_doc_lint.sh"
FIX="$SCRIPT_DIR/fixtures/synthetic-story-quality"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

if [ ! -f "$LIB" ]; then
  echo "FATAL: lib not found at $LIB" >&2
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"

# Assert a doc lints CLEAN (verdict PASS).
assert_clean() {
  local label="$1" doc="$2" verdict
  verdict="$(lint_story_doc "$doc" || true)"
  if [ "$verdict" = "PASS" ]; then pass "$label"; else fail "$label (expected PASS, got: $verdict)"; fi
}
# Assert a doc trips a specific defect code (substring on the verdict).
assert_defect() {
  local label="$1" doc="$2" want="$3" verdict
  verdict="$(lint_story_doc "$doc" || true)"
  case " $verdict " in
    *" $want "*) pass "$label (caught: $verdict)" ;;
    *)           fail "$label (expected '$want', got: $verdict)" ;;
  esac
}

GOOD="$FIX/good-britebase-grade/docs/product/flows/team/team-01.md"
GOOD_CS="$FIX/good-constraint-spec/docs/product/flows/seo/seo-01.md"
GOOD_HI="$FIX/good-human-infra-mention/docs/product/flows/ops/ops-01.md"
BAD_GRAMMAR="$FIX/bad-grammar-collapse/docs/product/flows/team/team-02.md"
BAD_BOILER="$FIX/bad-boilerplate-ac/docs/product/flows/team/team-03.md"
BAD_SCEN="$FIX/bad-too-few-scenarios/docs/product/flows/team/team-04.md"
BAD_PERSONA="$FIX/bad-generic-persona/docs/product/flows/team/team-05.md"
BAD_FRAME="$FIX/bad-frame-mismatch/docs/product/flows/seo/seo-02.md"

section "1/3" "lib loads + fixtures present"
for d in "$GOOD" "$GOOD_CS" "$GOOD_HI" "$BAD_GRAMMAR" "$BAD_BOILER" "$BAD_SCEN" "$BAD_PERSONA" "$BAD_FRAME"; do
  if [ -f "$d" ]; then pass "fixture present: ${d#$FIX/}"; else fail "fixture MISSING: $d"; fi
done

section "2/3" "GOOD fixtures lint clean (human job-story + constraint-spec + human-mentions-infra)"
assert_clean "good human job-story → PASS" "$GOOD"
assert_clean "good constraint-spec → PASS" "$GOOD_CS"
assert_clean "good human-mentions-infra (crawler as object) → PASS" "$GOOD_HI"

section "3/3" "BAD fixtures trip their defect"
assert_defect "bad-grammar-collapse → GRAMMAR" "$BAD_GRAMMAR" "GRAMMAR"
assert_defect "bad-boilerplate-ac → BOILERPLATE" "$BAD_BOILER" "BOILERPLATE"
assert_defect "bad-too-few-scenarios → FEW_SCENARIOS" "$BAD_SCEN" "FEW_SCENARIOS"
assert_defect "bad-generic-persona → GENERIC_PERSONA" "$BAD_PERSONA" "GENERIC_PERSONA"
assert_defect "bad-frame-mismatch → FRAME_MISMATCH" "$BAD_FRAME" "FRAME_MISMATCH"

# Single-axis check: the frame-mismatch fixture is otherwise well-formed and must
# trip ONLY FRAME_MISMATCH (proves the lint's defects are independent).
frame_verdict="$(lint_story_doc "$BAD_FRAME" || true)"
case " $frame_verdict " in
  *" GRAMMAR "*|*" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*)
    fail "bad-frame-mismatch leaks an unintended defect: $frame_verdict" ;;
  *) pass "bad-frame-mismatch trips ONLY the frame defect" ;;
esac

printf '\nflow-doc-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
