#!/usr/bin/env bash
# Regression-lock v-slice for the story-doc-author quality rewrite.
#
# Greps fixture story docs under tests/fixtures/synthetic-story-quality/ and
# FAILS a doc on any of four quality defects the rewrite must eliminate:
#
#   (a) Job-story grammar collapse — a `## Job story` `When/I want to/so I can`
#       sentence whose `so I can` clause has no verb (a bare noun phrase, e.g.
#       "so I can a faster workflow" / "so I can the dashboard") OR an
#       `I want to a/an/the <noun>` shape (article directly after "I want to",
#       which is never grammatical). The canonical sentence shape is the Q27
#       lock (fda-plugin-interview.md:304):
#         ^> \*\*When\*\*.*\*\*I want to\*\*.*\*\*so I can\*\*
#   (b) Circular boilerplate AC — the placeholder strings "the outcome
#       described in" or "holds true" that the old template emitted verbatim.
#   (c) Fewer than 3 `Scenario:` blocks (Q27 requires 3-5 Gherkin scenarios).
#   (d) Generic project-wide default persona repeated verbatim — the seed for
#       defect classes T0-2 / A-2. A `personas:` front-matter value that is one
#       of the known boilerplate defaults ("the user", "primary user",
#       "Brite team member") rather than a sub-flow-specific persona.
#
# Contract: a GOOD BriteBase-grade fixture PASSES all four checks; each BAD
# fixture trips exactly the defect it is named for.
#
# Bash 3.2 compatible (macOS default) per FDA parking-lot #32. Stdlib only.
#
# Gotcha guards applied:
#  - Literal backtick never embedded in a grep regex; all greps here are
#    fixed-string (grep -F) or use bracket classes without backticks. (See
#    memory/gotcha_bash_backtick_in_regex_construction.md.)
#  - No `grep -r` against absolute paths: every per-doc grep targets a single
#    file by explicit path, so marker tokens in this script / the fixture
#    directory name can never self-match. (See
#    memory/gotcha_lint_marker_token_collides_with_worktree_dirname.md.)

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/synthetic-story-quality"

GOOD_DIR="$FIXTURES_DIR/good-britebase-grade"
BAD_GRAMMAR_DIR="$FIXTURES_DIR/bad-grammar-collapse"
BAD_BOILERPLATE_DIR="$FIXTURES_DIR/bad-boilerplate-ac"
BAD_SCENARIOS_DIR="$FIXTURES_DIR/bad-too-few-scenarios"
BAD_PERSONA_DIR="$FIXTURES_DIR/bad-generic-persona"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Known generic project-wide default personas (defect d / T0-2 / A-2 seed).
# A story doc whose `personas:` front-matter value is verbatim one of these is
# a quality defect — personas must be sub-flow-specific.
GENERIC_PERSONAS="the user
primary user
Brite team member"

# ──────────────────────────────────────────────────────────────────────
# Quality scanner — runs the four defect checks against ONE story doc.
# Echoes a verdict (PASS / one or more defect codes) and returns 0 if clean,
# 1 if any defect found. Stdlib-only, single-file grep (no -r).
#
# Defect codes: GRAMMAR / BOILERPLATE / FEW_SCENARIOS / GENERIC_PERSONA.
# ──────────────────────────────────────────────────────────────────────
scan_doc() {
  local doc="$1"
  local defects=""

  if [ ! -f "$doc" ]; then
    printf 'MISSING'
    return 1
  fi

  # ── Check (a): job-story grammar collapse ──────────────────────────
  # Pull the job-story sentence. Q27 canonical shape is a blockquote with
  # bold When / I want to / so I can markers. We accept either the
  # bold-marker form or a plain "When ..., I want to ..., so I can ..." line.
  local jobstory
  jobstory="$(grep -iE 'I want to' "$doc" 2>/dev/null | grep -iE 'so I can' | head -1 || true)"

  if [ -n "$jobstory" ]; then
    # (a1) Article directly after "I want to" — "I want to a/an/the <noun>"
    # is never grammatical (a verb must follow "to").
    if printf '%s' "$jobstory" | grep -iqE 'I want to[*[:space:]]+(a|an|the)[[:space:]]'; then
      defects="$defects GRAMMAR"
    else
      # (a2) "so I can" must be followed by a verb, not a bare noun phrase.
      # Collapse pattern: "so I can <article> <noun>" or "so I can <noun>."
      # with no verb. Heuristic: the first word after "so I can" (stripping
      # bold markers) must NOT be an article, and the clause must contain at
      # least one lowercase word that could be a verb. We flag the high-signal
      # collapse shape: "so I can" immediately followed by an article.
      local tail
      tail="$(printf '%s' "$jobstory" | sed -E 's/.*[Ss]o I can[*]*[[:space:]]+//')"
      # Strip a leading bold marker if any already consumed; check first token.
      if printf '%s' "$tail" | grep -iqE '^(a|an|the)[[:space:]]'; then
        defects="$defects GRAMMAR"
      fi
    fi
  fi

  # ── Check (b): circular boilerplate AC ─────────────────────────────
  # Fixed-string greps — no regex, no backtick risk.
  if grep -qF 'the outcome described in' "$doc" 2>/dev/null \
     || grep -qF 'holds true' "$doc" 2>/dev/null; then
    defects="$defects BOILERPLATE"
  fi

  # ── Check (c): fewer than 3 Scenario blocks ────────────────────────
  local scen_count
  scen_count="$(grep -cE '^[[:space:]]*Scenario:' "$doc" 2>/dev/null || true)"
  # grep -c emits 0 on no match under set -e via the `|| true` above.
  [ -n "$scen_count" ] || scen_count=0
  if [ "$scen_count" -lt 3 ]; then
    defects="$defects FEW_SCENARIOS"
  fi

  # ── Check (d): generic project-wide default persona ────────────────
  # Pull the personas: front-matter value, normalize surrounding whitespace,
  # and compare verbatim against the known generic-default list.
  local persona_val
  persona_val="$(grep -iE '^personas:[[:space:]]*' "$doc" 2>/dev/null \
    | head -1 \
    | sed -E 's/^[Pp]ersonas:[[:space:]]*//; s/[[:space:]]+$//' || true)"
  if [ -n "$persona_val" ]; then
    while IFS= read -r generic; do
      [ -n "$generic" ] || continue
      if [ "$persona_val" = "$generic" ]; then
        defects="$defects GENERIC_PERSONA"
        break
      fi
    done <<EOF
$GENERIC_PERSONAS
EOF
  fi

  if [ -n "$defects" ]; then
    # Trim leading space.
    printf '%s' "${defects# }"
    return 1
  fi
  printf 'PASS'
  return 0
}

# Assert a doc is CLEAN (scan returns PASS).
assert_clean() {
  local label="$1" doc="$2" verdict
  verdict="$(scan_doc "$doc" || true)"
  if [ "$verdict" = "PASS" ]; then
    pass "$label"
  else
    fail "$label (expected clean, got defects: $verdict)"
  fi
}

# Assert a doc trips a SPECIFIC defect code (substring match on the verdict).
assert_defect() {
  local label="$1" doc="$2" want="$3" verdict
  verdict="$(scan_doc "$doc" || true)"
  case " $verdict " in
    *" $want "*) pass "$label (caught: $verdict)" ;;
    *)           fail "$label (expected defect '$want', got: $verdict)" ;;
  esac
}

# ──────────────────────────────────────────────────────────────────────
# Section 1 — Fixture presence
# ──────────────────────────────────────────────────────────────────────
section "1/3" "Fixture presence"

GOOD_DOC="$GOOD_DIR/docs/product/flows/team/team-01.md"
BAD_GRAMMAR_DOC="$BAD_GRAMMAR_DIR/docs/product/flows/team/team-02.md"
BAD_BOILERPLATE_DOC="$BAD_BOILERPLATE_DIR/docs/product/flows/team/team-03.md"
BAD_SCENARIOS_DOC="$BAD_SCENARIOS_DIR/docs/product/flows/team/team-04.md"
BAD_PERSONA_DOC="$BAD_PERSONA_DIR/docs/product/flows/team/team-05.md"

for d in "$GOOD_DOC" "$BAD_GRAMMAR_DOC" "$BAD_BOILERPLATE_DOC" \
         "$BAD_SCENARIOS_DOC" "$BAD_PERSONA_DOC"; do
  if [ -f "$d" ]; then
    pass "fixture present: ${d#$FIXTURES_DIR/}"
  else
    fail "fixture MISSING: $d"
  fi
done

# ──────────────────────────────────────────────────────────────────────
# Section 2 — GOOD fixture passes all four checks
# ──────────────────────────────────────────────────────────────────────
section "2/3" "GOOD BriteBase-grade fixture is clean"

assert_clean "good fixture passes all four quality checks" "$GOOD_DOC"

# Cross-checks on the good fixture's structural soundness — these guard the
# fixture itself against rotting into a trivially-passing stub.
if grep -qiE '^> \*\*When\*\*.*\*\*I want to\*\*.*\*\*so I can\*\*' "$GOOD_DOC"; then
  pass "good fixture job story matches the Q27 canonical bold-marker shape"
else
  fail "good fixture job story does NOT match the Q27 canonical shape"
fi

good_scen="$(grep -cE '^[[:space:]]*Scenario:' "$GOOD_DOC" 2>/dev/null || true)"
[ -n "$good_scen" ] || good_scen=0
if [ "$good_scen" -ge 3 ] && [ "$good_scen" -le 5 ]; then
  pass "good fixture has 3-5 Scenario blocks (found $good_scen)"
else
  fail "good fixture must have 3-5 Scenario blocks (found $good_scen)"
fi

# ──────────────────────────────────────────────────────────────────────
# Section 3 — Each BAD fixture trips exactly its defect
# ──────────────────────────────────────────────────────────────────────
section "3/3" "BAD fixtures trip their defects"

assert_defect "bad-grammar-collapse trips GRAMMAR" \
  "$BAD_GRAMMAR_DOC" "GRAMMAR"
assert_defect "bad-boilerplate-ac trips BOILERPLATE" \
  "$BAD_BOILERPLATE_DOC" "BOILERPLATE"
assert_defect "bad-too-few-scenarios trips FEW_SCENARIOS" \
  "$BAD_SCENARIOS_DOC" "FEW_SCENARIOS"
assert_defect "bad-generic-persona trips GENERIC_PERSONA" \
  "$BAD_PERSONA_DOC" "GENERIC_PERSONA"

# Negative-cross-checks: each bad fixture must NOT spuriously trip the
# *other* defects (keeps each fixture a single-axis regression lock). The
# good fixture already proved all four checks can be clean simultaneously,
# so here we only assert the bad fixtures are otherwise well-formed.
gram_verdict="$(scan_doc "$BAD_GRAMMAR_DOC" || true)"
case " $gram_verdict " in
  *" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*)
    fail "bad-grammar-collapse leaks an unintended defect: $gram_verdict" ;;
  *) pass "bad-grammar-collapse trips ONLY the grammar defect" ;;
esac

# ──────────────────────────────────────────────────────────────────────
# Summary — machine-readable RESULT line for validate.sh
# ──────────────────────────────────────────────────────────────────────
printf '\nstory-doc quality v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
