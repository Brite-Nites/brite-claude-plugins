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
GATE_OWNED_CS="$FIX/constraint-spec-gate-owned/docs/product/flows/seo/seo-01.md"
GOOD_HI="$FIX/good-human-infra-mention/docs/product/flows/ops/ops-01.md"
BAD_GRAMMAR="$FIX/bad-grammar-collapse/docs/product/flows/team/team-02.md"
BAD_BOILER="$FIX/bad-boilerplate-ac/docs/product/flows/team/team-03.md"
BAD_SCEN="$FIX/bad-too-few-scenarios/docs/product/flows/team/team-04.md"
BAD_PERSONA="$FIX/bad-generic-persona/docs/product/flows/team/team-05.md"
BAD_FRAME="$FIX/bad-frame-mismatch/docs/product/flows/seo/seo-02.md"
BAD_MECH="$FIX/bad-mechanism-leak/docs/product/flows/team/team-06.md"

section "1/4" "lib loads + fixtures present"
for d in "$GOOD" "$GATE_OWNED_CS" "$GOOD_HI" "$BAD_GRAMMAR" "$BAD_BOILER" "$BAD_SCEN" "$BAD_PERSONA" "$BAD_FRAME" "$BAD_MECH"; do
  if [ -f "$d" ]; then pass "fixture present: ${d#$FIX/}"; else fail "fixture MISSING: $d"; fi
done

section "2/4" "Deterministically-clean fixtures lint clean (human job-story + gate-owned constraint-spec + human-mentions-infra)"
assert_clean "good human job-story → PASS" "$GOOD"
assert_clean "gate-owned constraint-spec → PASS (frame rejection is the audit gate's + rubric D11's job, not this lint's)" "$GATE_OWNED_CS"
assert_clean "good human-mentions-infra (crawler as object) → PASS" "$GOOD_HI"

section "3/4" "BAD fixtures trip their defect"
assert_defect "bad-grammar-collapse → GRAMMAR" "$BAD_GRAMMAR" "GRAMMAR"
assert_defect "bad-boilerplate-ac → BOILERPLATE" "$BAD_BOILER" "BOILERPLATE"
assert_defect "bad-too-few-scenarios → FEW_SCENARIOS" "$BAD_SCEN" "FEW_SCENARIOS"
assert_defect "bad-generic-persona → GENERIC_PERSONA" "$BAD_PERSONA" "GENERIC_PERSONA"
assert_defect "bad-frame-mismatch → FRAME_MISMATCH" "$BAD_FRAME" "FRAME_MISMATCH"
assert_defect "bad-mechanism-leak → MECHANISM_LEAK (.ts in prose)" "$BAD_MECH" "MECHANISM_LEAK"

# Single-axis check: the frame-mismatch fixture is otherwise well-formed and must
# trip ONLY FRAME_MISMATCH (proves the lint's defects are independent).
frame_verdict="$(lint_story_doc "$BAD_FRAME" || true)"
case " $frame_verdict " in
  *" GRAMMAR "*|*" BOILERPLATE "*|*" FEW_SCENARIOS "*|*" GENERIC_PERSONA "*|*" BAD_STATUS "*)
    fail "bad-frame-mismatch leaks an unintended defect: $frame_verdict" ;;
  *) pass "bad-frame-mismatch trips ONLY the frame defect" ;;
esac

# Single-axis check: bad-mechanism-leak is otherwise well-formed and must trip
# ONLY MECHANISM_LEAK (its leak is a lone .ts filename in the Actor prose).
mech_verdict="$(lint_story_doc "$BAD_MECH" || true)"
if [ "$mech_verdict" = "MECHANISM_LEAK" ]; then
  pass "bad-mechanism-leak trips ONLY MECHANISM_LEAK (verdict exactly: $mech_verdict)"
else
  fail "bad-mechanism-leak expected EXACTLY MECHANISM_LEAK, got: $mech_verdict"
fi

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

# ── MECHANISM_LEAK branch coverage (the committed fixture exercises only P1) ──
# P2 — a function-call shape (lowercase-initial identifier + '(') in the Actor
# prose fires even with no .ts filename present.
mk_tmp_doc mech_func <<'DOC'
---
flow_id: team-09
status: BUILT
personas: Workspace owner auditing access changes
---
# team-09

## Job story

> **When** a teammate's role changes, **I want to** re-check their access from the members screen, **so I can** keep workspace permissions tight.

## Actor

Workspace owner (RBAC: `workspace.admin`). The access gate runs beforeLogin() on every request.

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
assert_defect "function-call shape in prose → MECHANISM_LEAK (P2)" "$TMP_DOCS/mech_func.md" "MECHANISM_LEAK"

# P3 — a source-root path prefix (src/ node_modules/ dist/ build/) in prose fires.
mk_tmp_doc mech_path <<'DOC'
---
flow_id: team-10
status: BUILT
personas: Workspace owner reviewing the audit log
---
# team-10

## Job story

> **When** a teammate is removed, **I want to** see the change in the audit log, **so I can** prove who lost access and when.

## Actor

Workspace owner (RBAC: `workspace.admin`). The audit handler is wired under src/audit before the members screen renders.

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
assert_defect "source-root path in prose → MECHANISM_LEAK (P3)" "$TMP_DOCS/mech_path.md" "MECHANISM_LEAK"

# Region exemption — code symbols confined to `## Status` + the Gherkin ACs
# (everything from `## Acceptance` onward, outside `_fdl_frame_region`) stay clean:
# a `.ts:line`, a `funcName()`, and a `src/` path all in `## Status`/an AC, prose clean.
mk_tmp_doc mech_region_exempt <<'DOC'
---
flow_id: team-11
status: BUILT
personas: Workspace owner confirming a removal took effect
---
# team-11

## Job story

> **When** a teammate is offboarded, **I want to** confirm their access is gone, **so I can** close the ticket with confidence.

## Actor

Workspace owner (RBAC: `workspace.admin`). They watch the members screen update after a removal.

## Acceptance criteria

Scenario: removal invalidates the session
  Given an active teammate
  When the owner removes them and revokeSession() runs
  Then the teammate's next request returns a 401.

Scenario: b
  Given x
  When y
  Then z

Scenario: c
  Given x
  When y
  Then z

## Status

BUILT — enforced in `middleware.ts:42` via revokeSession(); evidence in src/auth/guard.ts.
DOC
assert_clean "code symbols confined to ## Status + ACs stay clean (region exemption)" "$TMP_DOCS/mech_region_exempt.md"

# Narrowness guard — legitimate prose tokens must NOT trip MECHANISM_LEAK:
# a leading-slash route (/photos), the company domain (@britenites.com), a
# camelCase product name (iPhone), and an ALL-CAPS acronym with parens (API(s)).
mk_tmp_doc mech_fp_guards <<'DOC'
---
flow_id: team-12
status: BUILT
personas: Workspace owner managing access on the go
---
# team-12

## Job story

> **When** a teammate leaves, **I want to** revoke access from my iPhone, **so I can** act before I reach a desk.

## Actor

Workspace owner (RBAC: `workspace.admin`). They review activity on the /photos page and over the API(s) we expose, and reach support at help@britenites.com.

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
assert_clean "legitimate prose (/photos, @britenites.com, iPhone, API(s)) stays clean (narrowness guard)" "$TMP_DOCS/mech_fp_guards.md"

# Pluralization guard — lowercase `word(s)` plurals (role(s), page(s), permission(s))
# are legitimate prose and must NOT trip P2. The function-call shape requires EMPTY
# parens `()`, which `(s)` is not.
mk_tmp_doc mech_plural_guard <<'DOC'
---
flow_id: team-13
status: BUILT
personas: Workspace owner assigning the right roles to new hires
---
# team-13

## Job story

> **When** a new hire starts, **I want to** assign the right role(s) on the members screen, **so I can** grant the page(s) they need without over-provisioning.

## Actor

Workspace owner (RBAC: `workspace.admin`). They manage permission(s) for their team's field(s) of work.

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
assert_clean "lowercase pluralization role(s)/page(s)/permission(s) stays clean (P2 requires empty parens)" "$TMP_DOCS/mech_plural_guard.md"

# Front-matter exemption (Greptile #501 P1) — YAML metadata is NOT story prose. A
# front-matter value that carries a code path (`e2e_test: src/auth/revoke.test.ts`)
# must NOT trip MECHANISM_LEAK; the scan is scoped to the prose body, not metadata.
mk_tmp_doc mech_frontmatter_exempt <<'DOC'
---
flow_id: team-14
status: BUILT
personas: Workspace owner offboarding a departing teammate
e2e_test: src/auth/revoke.test.ts
---
# team-14

## Job story

> **When** a teammate leaves, **I want to** revoke their access from the members screen, **so I can** close the security gap immediately.

## Actor

Workspace owner (RBAC: `workspace.admin`). They confirm the removal on the members screen.

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
assert_clean "code path in front-matter (e2e_test: src/auth/revoke.test.ts) stays clean — metadata, not prose (Greptile #501 P1)" "$TMP_DOCS/mech_frontmatter_exempt.md"

# ## Status notes exemption (Greptile #501 P2) — `## Status notes` is the sibling of
# `## Status` (build-state evidence), positioned before `## Acceptance`. It legitimately
# records file:symbol evidence and must be exempt like `## Status`, even though it sits
# inside the pre-Acceptance span.
mk_tmp_doc mech_status_notes_exempt <<'DOC'
---
flow_id: team-15
status: IN_PROGRESS
personas: Workspace owner waiting on the self-serve revoke UI
---
# team-15

## Job story

> **When** a teammate leaves, **I want to** revoke their access right away, **so I can** keep the workspace secure.

## Status notes

Engine ships — getInvoices() query runs in middleware.ts; no /revoke route under src/app yet, so revocation is manual today.

## Actor

Workspace owner (RBAC: `workspace.admin`). They currently ask an admin to remove the seat.

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
assert_clean "code evidence in ## Status notes (getInvoices()/middleware.ts/src/app) stays clean — status sibling, not prose (Greptile #501 P2)" "$TMP_DOCS/mech_status_notes_exempt.md"

printf '\nflow-doc-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
