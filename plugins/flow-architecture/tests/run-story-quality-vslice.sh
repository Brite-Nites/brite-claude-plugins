#!/usr/bin/env bash
# Regression-lock v-slice for the story-doc-author quality rewrite.
#
# Greps fixture story docs under tests/fixtures/synthetic-story-quality/ and
# FAILS a doc on any of five quality defects the rewrite must eliminate:
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
#   (e) Frame mismatch (D11 / T0-4) — a non-human / automated / infra actor
#       (a crawler, googlebot, spider, bot) forced into the first-person
#       job-story frame (`When .. I want .. so I can`) instead of the
#       constraint-spec frame (`Given .. the system MUST .. so that`). This is
#       the canonical "When I'm a search-engine crawler, I want a sitemap.."
#       defect (brite-labs-site / brite-sites sitemap-and-robots). The check is
#       (1) scoped to the `## Job story` section so AC-level `When a crawler
#       requests ..` lines (legitimate in a constraint-spec Given/When/Then)
#       never fire it, and (2) ACTOR-scoped within that section so a human flow
#       that merely names a crawler as an OBJECT ("When I review crawler
#       activity reports, I want ..") does not false-trip — the non-human noun
#       must hold the subject position. The broader infra set (cron, webhook,
#       CDN, ISR, canonical, CSP) is judgment-scored by the `quality-reviewer`;
#       this deterministic lock targets the high-signal crawler/bot agent class.
#
# Contract: each GOOD fixture (a human BriteBase-grade story AND a non-human
# constraint-spec story) PASSES all five checks; each BAD fixture trips exactly
# the defect it is named for.
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
GOOD_CONSTRAINT_DIR="$FIXTURES_DIR/good-constraint-spec"
GOOD_HUMAN_INFRA_DIR="$FIXTURES_DIR/good-human-infra-mention"
BAD_GRAMMAR_DIR="$FIXTURES_DIR/bad-grammar-collapse"
BAD_BOILERPLATE_DIR="$FIXTURES_DIR/bad-boilerplate-ac"
BAD_SCENARIOS_DIR="$FIXTURES_DIR/bad-too-few-scenarios"
BAD_PERSONA_DIR="$FIXTURES_DIR/bad-generic-persona"
BAD_FRAME_DIR="$FIXTURES_DIR/bad-frame-mismatch"

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

# Non-human / automated actor agents (defect e / D11 / T0-4). A first-person
# job-story frame whose ACTOR is one of these is the canonical frame mismatch.
# High-signal agent nouns only — the broader infra set (cron, webhook, CDN,
# ISR, canonical, CSP) is left to the quality-reviewer's judgment so this
# deterministic lock stays free of false positives. `\bbot\b` matches a
# standalone "bot" but not "robot", "chatbot", or "Googlebot" (the last is
# caught by its own alternative). No backtick in the class
# (memory/gotcha_bash_backtick_in_regex_construction).
NONHUMAN_ACTOR_RE='crawler|crawlers|googlebot|google bot|spider|\bbot\b'

# Defect (e) is ACTOR-SCOPED, not section-scoped: the non-human noun must sit in
# the SUBJECT position, so a human flow that merely *mentions* a crawler as an
# object ("When I review crawler activity reports, I want ..") never false-trips.
# Two shapes carry the defect:
#   WHEN_SUBJECT_RE  — 3rd-person subject right after "When", allowing an article
#                      or possessor ("When Google's crawler", "When the crawler",
#                      "When a web bot").
#   FIRST_PERSON_RE  — 1st-person roleplay ("When I'm a search-engine crawler ..",
#                      "When I am a googlebot ..").
# `['’]` matches a straight or curly apostrophe. Both regexes embed the agent
# class above; the {0,3} word window bounds the determiner/adjective run so an
# action verb ("I review crawler ..") falls outside the match.
WHEN_SUBJECT_RE="[Ww]hen[*]*[[:space:]]+((a|an|the|web|search|engine|search-engine|[A-Za-z]+['’]s)[[:space:]]+){0,3}($NONHUMAN_ACTOR_RE)"
FIRST_PERSON_RE="[Ii]([[:space:]]?['’]m|[[:space:]]am)[[:space:]]+(an?|the)[[:space:]]+([a-z-]+[[:space:]]+){0,3}($NONHUMAN_ACTOR_RE)"

# ──────────────────────────────────────────────────────────────────────
# Quality scanner — runs the five defect checks against ONE story doc.
# Echoes a verdict (PASS / one or more defect codes) and returns 0 if clean,
# 1 if any defect found. Stdlib-only, single-file grep (no -r).
#
# Defect codes: GRAMMAR / BOILERPLATE / FEW_SCENARIOS / GENERIC_PERSONA /
# FRAME_MISMATCH.
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

  # ── Check (e): frame mismatch (D11 / T0-4) ─────────────────────────
  # A non-human actor forced into the first-person job-story frame. Scoped
  # to the `## Job story` section ONLY — AC-level `When a crawler requests`
  # lines are legitimate in a constraint-spec doc and must not trip this.
  # The section is extracted from `## Job story` up to the next H2.
  local jobstory_section
  jobstory_section="$(awk '
    /^##[[:space:]]+Job story/ { in_js=1; next }
    /^##[[:space:]]/           { in_js=0 }
    in_js                      { print }
  ' "$doc" 2>/dev/null || true)"
  # Frame is in use only when BOTH first-person markers are present. A
  # constraint-spec section (Given / the system MUST / so that) lacks them
  # and is skipped — exactly the correct frame for a non-human actor.
  if printf '%s' "$jobstory_section" | grep -iqE 'I want' \
     && printf '%s' "$jobstory_section" | grep -iqE 'so I can'; then
    # Flag only when a non-human noun is the ACTOR (subject), never when it is
    # merely an object the human acts on. See WHEN_SUBJECT_RE / FIRST_PERSON_RE.
    if printf '%s' "$jobstory_section" | grep -iqE "$WHEN_SUBJECT_RE" \
       || printf '%s' "$jobstory_section" | grep -iqE "$FIRST_PERSON_RE"; then
      defects="$defects FRAME_MISMATCH"
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
GOOD_CONSTRAINT_DOC="$GOOD_CONSTRAINT_DIR/docs/product/flows/seo/seo-01.md"
GOOD_HUMAN_INFRA_DOC="$GOOD_HUMAN_INFRA_DIR/docs/product/flows/ops/ops-01.md"
BAD_GRAMMAR_DOC="$BAD_GRAMMAR_DIR/docs/product/flows/team/team-02.md"
BAD_BOILERPLATE_DOC="$BAD_BOILERPLATE_DIR/docs/product/flows/team/team-03.md"
BAD_SCENARIOS_DOC="$BAD_SCENARIOS_DIR/docs/product/flows/team/team-04.md"
BAD_PERSONA_DOC="$BAD_PERSONA_DIR/docs/product/flows/team/team-05.md"
BAD_FRAME_DOC="$BAD_FRAME_DIR/docs/product/flows/seo/seo-02.md"

for d in "$GOOD_DOC" "$GOOD_CONSTRAINT_DOC" "$GOOD_HUMAN_INFRA_DOC" \
         "$BAD_GRAMMAR_DOC" "$BAD_BOILERPLATE_DOC" "$BAD_SCENARIOS_DOC" \
         "$BAD_PERSONA_DOC" "$BAD_FRAME_DOC"; do
  if [ -f "$d" ]; then
    pass "fixture present: ${d#$FIXTURES_DIR/}"
  else
    fail "fixture MISSING: $d"
  fi
done

# ──────────────────────────────────────────────────────────────────────
# Section 2 — GOOD fixtures pass all five checks
# ──────────────────────────────────────────────────────────────────────
section "2/3" "GOOD fixtures (human job-story + non-human constraint-spec + human-mentions-infra) are clean"

assert_clean "good human fixture passes all five quality checks" "$GOOD_DOC"
assert_clean "good constraint-spec fixture passes all five quality checks" "$GOOD_CONSTRAINT_DOC"
assert_clean "good human-mentions-infra fixture passes all five quality checks" "$GOOD_HUMAN_INFRA_DOC"

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

# Constraint-spec good fixture: guard it against rotting into either a thin
# stub or a job-story frame. It MUST carry the Given / the system MUST / so
# that constraint-spec shape and MUST NOT use the first-person job-story frame.
if grep -qiE '^> \*\*Given\*\*.*\*\*MUST\*\*.*\*\*so that\*\*' "$GOOD_CONSTRAINT_DOC"; then
  pass "good constraint-spec fixture uses the Given/MUST/so that frame"
else
  fail "good constraint-spec fixture does NOT match the Given/MUST/so that shape"
fi

constraint_js="$(awk '
  /^##[[:space:]]+Job story/ { in_js=1; next }
  /^##[[:space:]]/           { in_js=0 }
  in_js                      { print }
' "$GOOD_CONSTRAINT_DOC" 2>/dev/null || true)"
if printf '%s' "$constraint_js" | grep -iqE 'I want' \
   && printf '%s' "$constraint_js" | grep -iqE 'so I can'; then
  fail "good constraint-spec fixture leaked a first-person job-story frame"
else
  pass "good constraint-spec fixture avoids the first-person job-story frame"
fi

constraint_scen="$(grep -cE '^[[:space:]]*Scenario:' "$GOOD_CONSTRAINT_DOC" 2>/dev/null || true)"
[ -n "$constraint_scen" ] || constraint_scen=0
if [ "$constraint_scen" -ge 3 ] && [ "$constraint_scen" -le 5 ]; then
  pass "good constraint-spec fixture has 3-5 Scenario blocks (found $constraint_scen)"
else
  fail "good constraint-spec fixture must have 3-5 Scenario blocks (found $constraint_scen)"
fi

# Actor-scoping lock: the human-mentions-infra fixture uses the job-story frame
# AND names a crawler — but as an OBJECT, not the actor. It MUST NOT trip
# FRAME_MISMATCH. This guards the actor-position scoping against regressing to a
# naive section-wide keyword grep (which would false-fail this legitimate doc).
human_infra_verdict="$(scan_doc "$GOOD_HUMAN_INFRA_DOC" || true)"
case " $human_infra_verdict " in
  *" FRAME_MISMATCH "*)
    fail "human-mentions-infra fixture false-tripped FRAME_MISMATCH (actor-scoping regressed): $human_infra_verdict" ;;
  *) pass "human-mentions-infra fixture (crawler named as object) does not false-trip FRAME_MISMATCH" ;;
esac
if grep -qiE 'crawler' "$GOOD_HUMAN_INFRA_DOC"; then
  pass "human-mentions-infra fixture genuinely contains a non-human keyword (guard is meaningful)"
else
  fail "human-mentions-infra fixture must contain a non-human keyword or the actor-scoping guard is vacuous"
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
assert_defect "bad-frame-mismatch trips FRAME_MISMATCH" \
  "$BAD_FRAME_DOC" "FRAME_MISMATCH"

# Negative-cross-checks: each bad fixture must NOT spuriously trip the
# *other* defects (keeps each fixture a single-axis regression lock). The
# good fixtures already proved all five checks can be clean simultaneously,
# so here we only assert the bad fixtures are otherwise well-formed.
gram_verdict="$(scan_doc "$BAD_GRAMMAR_DOC" || true)"
case " $gram_verdict " in
  *" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*|*" FRAME_MISMATCH "*)
    fail "bad-grammar-collapse leaks an unintended defect: $gram_verdict" ;;
  *) pass "bad-grammar-collapse trips ONLY the grammar defect" ;;
esac

# The frame-mismatch fixture is grammatically well-formed and fully-specified
# — it must trip ONLY FRAME_MISMATCH, proving the new check is single-axis and
# does not piggy-back on the grammar / boilerplate / scenario / persona checks.
frame_verdict="$(scan_doc "$BAD_FRAME_DOC" || true)"
case " $frame_verdict " in
  *" GRAMMAR "*|*" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*)
    fail "bad-frame-mismatch leaks an unintended defect: $frame_verdict" ;;
  *) pass "bad-frame-mismatch trips ONLY the frame defect" ;;
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
