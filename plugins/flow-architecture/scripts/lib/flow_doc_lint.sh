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
#                  amendment 3 (BC-11983) rejects the constraint-spec frame in any
#                  consumer repo whose `.flow/config.json` sets `story_frame:
#                  strict`, and still tolerates it under the default `lenient`
#                  floor (BC-12134) so not-yet-reframed repos keep passing. The
#                  deterministic mirror is `tests/run-audit-smoke.sh`
#                  `story_frame_present <doc> <mode>`. This lint is intentionally
#                  NOT a second detection surface for the constraint-spec frame
#                  (the floor gate is authoritative — the 2-surface scope locked
#                  with Q29 amendment 3); under `lenient` such a doc is also caught
#                  by the LLM quality-reviewer via rubric D11.
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
  local status_fm
  status_fm="$(grep -E '^status:' "$doc" 2>/dev/null | head -1 \
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

  if [ -n "$defects" ]; then
    printf '%s' "${defects# }"
    return 1
  fi
  printf 'PASS'
  return 0
}
