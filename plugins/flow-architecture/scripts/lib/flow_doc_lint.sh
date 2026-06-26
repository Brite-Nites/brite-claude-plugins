#!/usr/bin/env bash
# WS-A deterministic story-doc lint lib (A-1 / A-2 / A-3 + D11 frame).
#
# Pure: `lint_story_doc <doc>` reads ONE story-doc path and echoes a verdict —
# either `PASS` or a space-separated list of defect codes — and returns 0 when
# clean, 1 when any defect is found. No side effects on source; the
# (path in → codes out) interface is the test surface (see
# tests/run-flow-doc-lint-vslice.sh) and the runner surface (see
# scripts/flow-doc-lint.sh). This is the reusable, MULTI-LINE-AWARE real-doc
# linter — distinct from tests/run-story-quality-vslice.sh's `scan_doc`, which
# is calibrated to the single-line Q27 fixtures. Real brite-base / brite-sites
# docs use the GOLD multi-line blockquoted frame (`> **When** ..\n> **I want
# to** ..\n> **so I can** ..`), so detection here is section-scoped and
# per-clause-line rather than single-line.
#
# Defect codes:
#   GRAMMAR        (A-1) job-story grammatical collapse — an article directly
#                  after "I want to" or "so I can" (a verb-less noun phrase).
#   BOILERPLATE    (A-3) circular placeholder AC ("the outcome described in" /
#                  "holds true").
#   FEW_SCENARIOS        fewer than 3 Gherkin `Scenario:` blocks.
#   GENERIC_PERSONA(A-2) the persona (front-matter `personas:` or the `## Actor`
#                  lead) is a known generic project-wide default.
#   FRAME_MISMATCH (D11) a non-human / infra actor (crawler/bot/spider/googlebot)
#                  placed as the FIRST-PERSON SUBJECT of the job story ("When I'm
#                  a crawler, I want …"). Under human-anchoring (BC-12134) the
#                  remedy is to RE-ANCHOR on the human the mechanism serves (the
#                  operator who trusts the run, or the customer who reads the
#                  output) — NOT to switch to a system-subject "the system MUST"
#                  constraint-spec frame, which is itself retired. Subject-scoped
#                  HEURISTIC: it keys on the non-human term appearing in subject
#                  position (just after `When`, or as the `I'm a <actor>` roleplay)
#                  — so a human flow that names a crawler as the OBJECT of the
#                  `I want to …` clause does not trip. The guard is proximity-based,
#                  not a parser: an infra term named early in the `When` clause
#                  (within ~3 words of `When`) can still trip. Treat FRAME_MISMATCH
#                  as an advisory flag for human review, not a precise actor
#                  classifier — the LLM quality-reviewer is the authoritative judge
#                  of actor/frame fit.
#                  SCOPE: this lint detects ONLY that first-person-non-human shape.
#                  It deliberately does NOT flag a `Given … the system MUST … so
#                  that` constraint-spec doc — that rejection lives in the audit
#                  story-frame gate (`story-job-story-regex`), which since Q29
#                  amendment 4 (BC-12197) rejects the constraint-spec frame
#                  unconditionally (the per-repo `story_frame: strict` flag of
#                  amendment 3 was collapsed to the hardcoded human-only end-state
#                  once all FDA consumers converged). The deterministic mirror is
#                  `tests/run-audit-smoke.sh` `story_frame_present <doc>`. This lint
#                  is intentionally NOT a second detection surface for the
#                  constraint-spec frame (the audit gate is authoritative); a
#                  constraint-spec doc is additionally caught by the LLM
#                  quality-reviewer via rubric D11.
#   BAD_STATUS     (BC-13029) front-matter `status:` is not one of the canonical
#                  6-value INDEX taxonomy (NOT_STARTED / IN_PROGRESS / BUILT /
#                  QA_SIGNED_OFF / SHIPPED / BLOCKED). Catches the lowercase
#                  `not-started` / `built` casing (reserved for the eng/design/
#                  docs_status discipline-mirror fields) and off-taxonomy values
#                  like `draft`. Feeds INDEX.md's Status column via
#                  regenerate-flow-index.mts (which coerces an off-taxonomy value
#                  to NOT_STARTED at render time — this lint is the upstream
#                  deterministic guard). Only a PRESENT-but-invalid value trips;
#                  absence is verify-docs's front-matter presence check.
#
# Bash 3.2 compatible (macOS default). Stdlib only. No literal backtick inside
# any grep regex (apostrophes use the ['’] bracket class).

# ── Frame regexes (shared shape with the audit story-frame gate + vslice) ────
FDL_NONHUMAN_ACTOR_RE='crawler|crawlers|googlebot|google bot|spider|\bbot\b'
FDL_WHEN_SUBJECT_RE="[Ww]hen[*]*[[:space:]]+((a|an|the|web|search|engine|search-engine|[A-Za-z]+['’]s)[[:space:]]+){0,3}($FDL_NONHUMAN_ACTOR_RE)"
FDL_FIRST_PERSON_RE="[Ii]([[:space:]]?['’]m|[[:space:]]am)[[:space:]]+(an?|the)[[:space:]]+([a-z-]+[[:space:]]+){0,3}($FDL_NONHUMAN_ACTOR_RE)"

# Known generic project-wide default personas (A-2). A doc whose persona is
# verbatim (case-insensitively) one of these predicts nothing about the flow.
FDL_GENERIC_PERSONAS="the user
primary user
brite team member
marketing site visitor
commercial buyer
newsletter subscriber
admin user
end user"

# Extract the `## Job story` section body (lines until the next H2). Stdin-free.
_fdl_js_section() {
  awk '/^##[[:space:]]+Job story/{f=1;next} /^##[[:space:]]/{f=0} f' "$1" 2>/dev/null
}

# Extract everything before the first `## Acceptance` heading (front-matter +
# title + summary + status-notes + job story) — the region a frame may live in.
_fdl_frame_region() {
  awk '/^##[[:space:]]+Acceptance/{exit} {print}' "$1" 2>/dev/null
}

# Extract the story PROSE region for the MECHANISM_LEAK check: the body before
# `## Acceptance`, MINUS the YAML front-matter (metadata, not prose) AND the
# conditional `## Status notes` section (the sibling of `## Status` — it
# legitimately records `file:symbol` build evidence and must be exempt like
# `## Status` itself). So the scan sees only the H1, the summary hook,
# `## Job story`, `## Actor`, and `## Preconditions`. Narrower than
# `_fdl_frame_region`, which over-scans both zones (Greptile #501 P1/P2).
_fdl_prose_region() {
  awk '
    NR==1 && /^---[[:space:]]*$/  { infm=1; next }
    infm && /^---[[:space:]]*$/   { infm=0; next }
    infm                          { next }
    /^##[[:space:]]+Acceptance/   { exit }
    /^##[[:space:]]+Status notes/ { skip=1; next }
    /^##[[:space:]]/              { skip=0 }
    skip                          { next }
    { print }
  ' "$1" 2>/dev/null
}

# Extract ONLY the YAML front-matter block (between the opening `---` on line 1
# and the next `---`). Used to scope front-matter-key checks so a body line that
# happens to start with `status:` (prose, a code block) can't false-positive.
_fdl_frontmatter() {
  awk 'NR==1 && /^---[[:space:]]*$/{f=1;next} f && /^---[[:space:]]*$/{exit} f' "$1" 2>/dev/null
}

lint_story_doc() {
  local doc="$1"
  local defects=""

  if [ ! -f "$doc" ]; then
    printf 'MISSING'
    return 1
  fi

  local js region
  js="$(_fdl_js_section "$doc")"
  region="$(_fdl_frame_region "$doc")"

  # Does the doc use the human job-story frame at all? (markers anywhere in the
  # frame region — single- or multi-line.)
  # Loosened to `**I want` (matches both the GOLD "**I want to**" and the legacy
  # house-style "**I want**") so FRAME_MISMATCH catches a non-human actor in
  # EITHER first-person frame; GRAMMAR below still keys specifically on the
  # "I want to <article>" collapse.
  local is_jobstory=0
  if printf '%s' "$region" | grep -qiE '\*\*When\*\*' \
     && printf '%s' "$region" | grep -qiE '\*\*I want' \
     && printf '%s' "$region" | grep -qiE '\*\*so I can\*\*'; then
    is_jobstory=1
  fi

  # ── A-1: job-story grammatical collapse ────────────────────────────
  # Only meaningful for the human job-story frame. Flag the high-signal collapse
  # shape: an article (a/an/the) directly after "I want to" or "so I can", which
  # is never grammatical (a verb must follow). Works per-clause-line, so it
  # covers both the single-line and the GOLD multi-line forms.
  if [ "$is_jobstory" -eq 1 ]; then
    if printf '%s' "$region" | grep -iqE '\*\*I want to\*\*[*[:space:]]+(a|an|the)[[:space:]]'; then
      defects="$defects GRAMMAR"
    elif printf '%s' "$region" | grep -iqE '\*\*so I can\*\*[*[:space:]]+(a|an|the)[[:space:]]'; then
      defects="$defects GRAMMAR"
    fi
  fi

  # ── A-3: circular boilerplate AC ───────────────────────────────────
  if grep -qF 'the outcome described in' "$doc" 2>/dev/null \
     || grep -qF 'holds true' "$doc" 2>/dev/null; then
    defects="$defects BOILERPLATE"
  fi

  # ── FEW_SCENARIOS: fewer than 3 Scenario blocks ────────────────────
  # Count both `Scenario:` and Gherkin `Scenario Outline:` (a parametrized
  # scenario is still a scenario — omitting Outline would false-flag a doc that
  # uses 3 outlines).
  local scen
  scen="$(grep -cE '^[[:space:]]*Scenario( Outline)?:' "$doc" 2>/dev/null || true)"
  [ -n "$scen" ] || scen=0
  if [ "$scen" -lt 3 ]; then
    defects="$defects FEW_SCENARIOS"
  fi

  # ── BAD_STATUS: front-matter `status:` ∈ canonical 6-value taxonomy ─
  # Feeds INDEX.md's Status column (regenerate-flow-index.mts). MUST be uppercase
  # NOT_STARTED|IN_PROGRESS|BUILT|QA_SIGNED_OFF|SHIPPED|BLOCKED — never a lowercase
  # `not-started`/`built` (those casings are reserved for the eng/design/docs_status
  # discipline-mirror fields) nor an off-taxonomy `draft`. Only a PRESENT-but-invalid
  # value trips; absence is verify-docs's front-matter presence check. `^status:`
  # anchors at line start, so it never matches `eng_status:`/`design_status:`/etc.
  # Scoped to the YAML front-matter block (not the whole file) so a body line that
  # starts with `status:` can't false-positive.
  local status_fm
  status_fm="$(_fdl_frontmatter "$doc" | grep -E '^status:' | head -1 \
    | sed -E 's/^status:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]+$//' || true)"
  if [ -n "$status_fm" ]; then
    case "$status_fm" in
      NOT_STARTED|IN_PROGRESS|BUILT|QA_SIGNED_OFF|SHIPPED|BLOCKED) : ;;
      *) defects="$defects BAD_STATUS" ;;
    esac
  fi

  # ── A-2: generic project-wide default persona ──────────────────────
  # Check the `personas:` front-matter value (if any) AND the `## Actor` lead
  # line, normalized, against the generic-default denylist (case-insensitive,
  # punctuation-trimmed).
  local persona_fm actor_lead cand
  persona_fm="$(grep -iE '^personas:[[:space:]]*' "$doc" 2>/dev/null | head -1 \
    | sed -E 's/^[Pp]ersonas:[[:space:]]*//; s/^\[//; s/\]$//; s/[[:space:]]+$//' || true)"
  actor_lead="$(awk '/^##[[:space:]]+(Actor|Persona)/{f=1;next} /^##[[:space:]]/{f=0} f' "$doc" 2>/dev/null \
    | grep -iE '[a-z]' | head -1 \
    | sed -E 's/^[*_>[:space:]-]+//; s/^[Rr]ole:[[:space:]]*//; s/[*_.:]+.*$//; s/[[:space:]]+$//' || true)"
  for cand in "$persona_fm" "$actor_lead"; do
    [ -n "$cand" ] || continue
    local lc
    lc="$(printf '%s' "$cand" | tr '[:upper:]' '[:lower:]')"
    while IFS= read -r generic; do
      [ -n "$generic" ] || continue
      if [ "$lc" = "$generic" ]; then
        case " $defects " in *" GENERIC_PERSONA "*) : ;; *) defects="$defects GENERIC_PERSONA" ;; esac
        break
      fi
    done <<EOF
$FDL_GENERIC_PERSONAS
EOF
  done

  # ── D11: frame mismatch (non-human actor in the job-story frame) ───
  if [ "$is_jobstory" -eq 1 ]; then
    if printf '%s' "$js" | grep -iqE "$FDL_WHEN_SUBJECT_RE" \
       || printf '%s' "$js" | grep -iqE "$FDL_FIRST_PERSON_RE"; then
      defects="$defects FRAME_MISMATCH"
    fi
  fi

  # ── MECHANISM_LEAK (D11 sibling): code-symbol shapes in the story prose ──
  # The locked altitude: the story prose (hook / Job story / Actor / Preconditions)
  # stays plain outcome terms; `file:symbol` / mechanism detail belongs in `## Status`.
  # Scanned over `_fdl_prose_region` (NOT `$region`): the body before `## Acceptance`,
  # MINUS the YAML front-matter (metadata) and the `## Status notes` section (the
  # `## Status` sibling that legitimately carries build evidence) — so metadata, status
  # evidence, the Gherkin ACs, and `## Status` are all exempt (Greptile #501 P1/P2; a
  # test legitimately names confirmed symbols in the ACs per rubric D2). NARROW by
  # design: only unambiguous code shapes flag deterministically; bare camelCase
  # (`beforeLogin`) and hyphenated jargon (`payload-token`) are left to the LLM
  # quality-reviewer (rubric D11) so prose like `iPhone` / `real-time` never
  # false-trips. Single-file greps, no backtick in any regex, bash-3.2 safe.
  #   P1 — code-extension filenames `<word>.ts` / `<word>.tsx`. NOT `.js`/`.jsx`
  #        (collide with the prose tokens Node.js / Next.js) and NOT `.xml`/`.txt`/
  #        `.md` (sitemap.xml, robots.txt, persona `.md` links are legitimate).
  #   P2 — a function-call shape: a LOWERCASE-initial identifier + EMPTY parens
  #        `()` (`beforeLogin()`, `revokeSession()`). The EMPTY parens are load-
  #        bearing: prose plurals `role(s)` / `page(s)` / `permission(s)` and the
  #        ALL-CAPS `API(s)` carry `(s)`, not `()`, so they never match; and
  #        `the workspace (a shared space)` / markdown `[label](…)` never produce
  #        `word()`. A call WITH args (`getUser(id)`) in prose is left to the LLM
  #        rubric — rarer in prose, and not worth widening the net for.
  #   P3 — source-root path prefixes `src/` `node_modules/` `dist/` `build/` at a
  #        token boundary (so `websrc/` doesn't match). NOT `app/` (collides with
  #        "the app"), NOT `docs/` (persona / intent `.md` links), NOT leading-slash
  #        page routes like `/photos` — the dir name itself must be a code root.
  local prose
  prose="$(_fdl_prose_region "$doc")"
  if printf '%s' "$prose" | grep -qE '[A-Za-z0-9_-]\.(ts|tsx)([^[:alnum:]]|$)' \
     || printf '%s' "$prose" | grep -qE '[a-z][A-Za-z0-9_]*\(\)' \
     || printf '%s' "$prose" | grep -qE '(^|[^A-Za-z0-9_])(src|node_modules|dist|build)/'; then
    defects="$defects MECHANISM_LEAK"
  fi

  if [ -n "$defects" ]; then
    printf '%s' "${defects# }"
    return 1
  fi
  printf 'PASS'
  return 0
}
