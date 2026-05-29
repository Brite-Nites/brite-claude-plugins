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
#                  forced into the first-person job-story frame instead of the
#                  constraint-spec frame. ACTOR-scoped: a human flow that merely
#                  names a crawler as an OBJECT does not trip.
#
# Bash 3.2 compatible (macOS default). Stdlib only. No literal backtick inside
# any grep regex (apostrophes use the ['’] bracket class).

# ── Frame regexes (shared shape with the T0-4 audit gate + vslice) ───────────
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
  local scen
  scen="$(grep -cE '^[[:space:]]*Scenario:' "$doc" 2>/dev/null || true)"
  [ -n "$scen" ] || scen=0
  if [ "$scen" -lt 3 ]; then
    defects="$defects FEW_SCENARIOS"
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
