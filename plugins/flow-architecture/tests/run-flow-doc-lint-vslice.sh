#!/usr/bin/env bash
# Regression-lock for the WS-A reusable story-doc lint lib
# (scripts/lib/flow_doc_lint.sh — A-1 grammar / A-2 persona / A-3 boilerplate /
# FEW_SCENARIOS / D11 FRAME_MISMATCH / BC-13029 BAD_STATUS).
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

# Inline temp-doc builder — for lib-branch cases the committed fixtures don't
# reach (the fixtures are one-per-defect; these lock specific OR-branches /
# alternate input shapes). Writes stdin to $TMP_DOCS/<name>.md; reference the
# path directly as "$TMP_DOCS/<name>.md" afterward. (Called as a standalone
# statement, NOT inside $() — a quoted heredoc inside command substitution trips
# bash 3.2's parser on an apostrophe like "I'm".)
TMP_DOCS="$(mktemp -d)"
trap 'rm -rf "$TMP_DOCS"' EXIT
mk_tmp_doc() { cat > "$TMP_DOCS/$1.md"; }

GOOD="$FIX/good-britebase-grade/docs/product/flows/team/team-01.md"
GOOD_CS="$FIX/good-constraint-spec/docs/product/flows/seo/seo-01.md"
GOOD_HI="$FIX/good-human-infra-mention/docs/product/flows/ops/ops-01.md"
BAD_GRAMMAR="$FIX/bad-grammar-collapse/docs/product/flows/team/team-02.md"
BAD_BOILER="$FIX/bad-boilerplate-ac/docs/product/flows/team/team-03.md"
BAD_SCEN="$FIX/bad-too-few-scenarios/docs/product/flows/team/team-04.md"
BAD_PERSONA="$FIX/bad-generic-persona/docs/product/flows/team/team-05.md"
BAD_FRAME="$FIX/bad-frame-mismatch/docs/product/flows/seo/seo-02.md"

section "1/4" "lib loads + fixtures present"
for d in "$GOOD" "$GOOD_CS" "$GOOD_HI" "$BAD_GRAMMAR" "$BAD_BOILER" "$BAD_SCEN" "$BAD_PERSONA" "$BAD_FRAME"; do
  if [ -f "$d" ]; then pass "fixture present: ${d#$FIX/}"; else fail "fixture MISSING: $d"; fi
done

section "2/4" "GOOD fixtures lint clean (human job-story + constraint-spec + human-mentions-infra)"
assert_clean "good human job-story → PASS" "$GOOD"
assert_clean "good constraint-spec → PASS" "$GOOD_CS"
assert_clean "good human-mentions-infra (crawler as object) → PASS" "$GOOD_HI"

section "3/4" "BAD fixtures trip their defect"
assert_defect "bad-grammar-collapse → GRAMMAR" "$BAD_GRAMMAR" "GRAMMAR"
assert_defect "bad-boilerplate-ac → BOILERPLATE" "$BAD_BOILER" "BOILERPLATE"
assert_defect "bad-too-few-scenarios → FEW_SCENARIOS" "$BAD_SCEN" "FEW_SCENARIOS"
assert_defect "bad-generic-persona → GENERIC_PERSONA" "$BAD_PERSONA" "GENERIC_PERSONA"
assert_defect "bad-frame-mismatch → FRAME_MISMATCH" "$BAD_FRAME" "FRAME_MISMATCH"

# Single-axis check: the frame-mismatch fixture is otherwise well-formed and must
# trip ONLY FRAME_MISMATCH (proves the lint's defects are independent).
frame_verdict="$(lint_story_doc "$BAD_FRAME" || true)"
case " $frame_verdict " in
  *" GRAMMAR "*|*" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*|*" BAD_STATUS "*)
    fail "bad-frame-mismatch leaks an unintended defect: $frame_verdict" ;;
  *) pass "bad-frame-mismatch trips ONLY the frame defect" ;;
esac

section "4/4" "inline lib-branch coverage (OR-branches the one-per-defect fixtures miss)"

# FRAME_MISMATCH FIRST_PERSON_RE branch — the bad-frame fixture (seo-02) exercises
# only the 3rd-person WHEN_SUBJECT_RE path; this locks the first-person roleplay
# branch ("When I'm a <crawler>…"), the canonical D11 shape.
mk_tmp_doc fp <<'DOC'
---
flow_id: seo-fp
status: BUILT
personas: SEO operator accountable for crawl budget
---
# seo-fp

## Job story

> **When** I'm a search-engine crawler reaching the domain, **I want to** fetch the sitemap, **so I can** enqueue every canonical URL.

## Acceptance criteria

Scenario: served
  Given a page set
  When the crawler requests it
  Then a 200 is returned

Scenario: robots
  Given robots.txt
  When read
  Then the sitemap is referenced

Scenario: canonical
  Given a duplicate
  When fetched
  Then the canonical link is present
DOC
assert_defect "first-person infra roleplay → FRAME_MISMATCH (FIRST_PERSON_RE branch)" "$TMP_DOCS/fp.md" "FRAME_MISMATCH"

# GRAMMAR a1 branch — article directly after "I want to" (the bad-grammar fixture
# trips only the "so I can <article>" a2 branch).
mk_tmp_doc gram <<'DOC'
---
flow_id: team-ga
status: BUILT
personas: Workspace owner onboarding a new hire
---
# team-ga

## Job story

> **When** a new hire joins, **I want to** a faster onboarding, **so I can** reduce ramp time.

## Acceptance criteria

Scenario: a
  Given x
  When y
  Then z

Scenario: b
  Given x
  When y
  Then z

Scenario: c
  Given x
  When y
  Then z
DOC
assert_defect "article after 'I want to' → GRAMMAR (a1 branch)" "$TMP_DOCS/gram.md" "GRAMMAR"

# A-2 ## Actor-lead persona path — the bad-generic-persona fixture trips via the
# front-matter `personas:` value; this locks the alternate `## Actor` lead-line path.
mk_tmp_doc actor <<'DOC'
---
flow_id: team-ac
status: BUILT
---
# team-ac

## Job story

> **When** a user signs in, **I want to** see my dashboard, **so I can** start the day.

## Actor

Primary user

## Acceptance criteria

Scenario: a
  Given x
  When y
  Then z

Scenario: b
  Given x
  When y
  Then z

Scenario: c
  Given x
  When y
  Then z
DOC
assert_defect "generic '## Actor' lead ('Primary user', no personas: front-matter) → GENERIC_PERSONA" "$TMP_DOCS/actor.md" "GENERIC_PERSONA"

# FEW_SCENARIOS Scenario-Outline counting — 3 Gherkin `Scenario Outline:` blocks
# must NOT trip FEW_SCENARIOS (locks the Scenario( Outline)? counter fix).
mk_tmp_doc outline <<'DOC'
---
flow_id: team-so
status: BUILT
personas: Workspace owner onboarding a new hire
---
# team-so

## Job story

> **When** a new hire joins, **I want to** invite them by email, **so I can** grant access fast.

## Acceptance criteria

Scenario Outline: invite by role
  Given a <role>
  When invited
  Then access is <result>

Scenario Outline: invite limits
  Given <count> seats
  When inviting
  Then <outcome>

Scenario Outline: invite errors
  Given <state>
  When inviting
  Then <error>
DOC
assert_clean "3 'Scenario Outline:' blocks → no FEW_SCENARIOS (Outline counted)" "$TMP_DOCS/outline.md"

# BC-13029 BAD_STATUS — front-matter `status:` off the canonical 6-value taxonomy.
# Two off-taxonomy shapes: the exact #1 bug (lowercase `not-started`) and `draft`.
# Each doc is otherwise well-formed, so it must trip ONLY BAD_STATUS.
mk_tmp_doc badstatus_lc <<'DOC'
---
flow_id: team-bs
status: not-started
personas: Workspace owner onboarding a new hire
---
# team-bs

## Job story

> **When** a new hire joins, **I want to** invite them by email, **so I can** grant access fast.

## Acceptance criteria

Scenario: a
  Given x
  When y
  Then z

Scenario: b
  Given x
  When y
  Then z

Scenario: c
  Given x
  When y
  Then z
DOC
assert_defect "lowercase 'not-started' status → BAD_STATUS (the #1 bug)" "$TMP_DOCS/badstatus_lc.md" "BAD_STATUS"
lc_verdict="$(lint_story_doc "$TMP_DOCS/badstatus_lc.md" || true)"
case " $lc_verdict " in
  *" GRAMMAR "*|*" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*|*" FRAME_MISMATCH "*)
    fail "badstatus_lc leaks an unintended defect: $lc_verdict" ;;
  *) pass "badstatus_lc trips ONLY BAD_STATUS" ;;
esac

mk_tmp_doc badstatus_draft <<'DOC'
---
flow_id: team-bd
status: draft
personas: Workspace owner onboarding a new hire
---
# team-bd

## Job story

> **When** a new hire joins, **I want to** invite them by email, **so I can** grant access fast.

## Acceptance criteria

Scenario: a
  Given x
  When y
  Then z

Scenario: b
  Given x
  When y
  Then z

Scenario: c
  Given x
  When y
  Then z
DOC
assert_defect "off-taxonomy 'draft' status → BAD_STATUS" "$TMP_DOCS/badstatus_draft.md" "BAD_STATUS"
draft_verdict="$(lint_story_doc "$TMP_DOCS/badstatus_draft.md" || true)"
case " $draft_verdict " in
  *" GRAMMAR "*|*" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*|*" FRAME_MISMATCH "*)
    fail "badstatus_draft leaks an unintended defect: $draft_verdict" ;;
  *) pass "badstatus_draft trips ONLY BAD_STATUS" ;;
esac

# Accept path: a valid uppercase taxonomy value must NOT trip BAD_STATUS.
mk_tmp_doc goodstatus <<'DOC'
---
flow_id: team-gs
status: QA_SIGNED_OFF
personas: Workspace owner onboarding a new hire
---
# team-gs

## Job story

> **When** a new hire joins, **I want to** invite them by email, **so I can** grant access fast.

## Acceptance criteria

Scenario: a
  Given x
  When y
  Then z

Scenario: b
  Given x
  When y
  Then z

Scenario: c
  Given x
  When y
  Then z
DOC
assert_clean "valid 'QA_SIGNED_OFF' status → no BAD_STATUS (accept path)" "$TMP_DOCS/goodstatus.md"

printf '\nflow-doc-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
