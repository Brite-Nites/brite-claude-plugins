#!/usr/bin/env bash
# Unit / contract suite for plugins/marketing/scripts/build_concept_payload.py
# (BC-13161, ADR-028 Phase-2 — the eval for /marketing:capture-idea, the LAST
# grandfathered command).
#
# build_concept_payload.py is the PURE deterministic decision core
# /marketing:capture-idea delegates to for the NON-conversational parts of intake:
# given the 9 parsed concept fields (the free-text brain-dump parse is the LLM part,
# held out / fixtured) + the INJECTED reads (the [CONCEPT LIBRARY] milestone id, the
# capture date, and the frozen-canonicals membership state), it computes — with NO
# MCP call and NO Linear write — the derived [Sketch]/[Maturing] status, the
# missing-for-completeness list, the 3-state canonical-match footer, the status label
# name, and the save_issue PAYLOAD that WOULD be filed. This suite drives the builder
# directly across every branch (Steps 3/4/5/7/9/10), proves the builder never shells a
# value (a `$(touch pwned)` field is treated as literal data), and that the emit is
# deterministic. The behavioral eval (scripts/eval/run_eval.py capture-idea) asserts
# the emit-artifact STRUCTURE; this asserts the builder's per-branch DECISIONS +
# injection-safety + determinism.
#
# Usage:
#   bash plugins/marketing/scripts/test_build_concept_payload.sh
#   bash plugins/marketing/scripts/test_build_concept_payload.sh /path/to/build_concept_payload.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.

# Defuse caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md; matches
# the workflows/revops builder-suite discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_concept_payload.py}"
# Absolutize: decide() runs `cd "$box"` (an mktemp) before `python3 "$BUILDER"`, so a
# relative builder arg would break. No-op for the already-absolute default.
BUILDER="$(cd "$(dirname "$BUILDER")" 2>/dev/null && pwd)/$(basename "$BUILDER")"

if [ ! -f "$BUILDER" ]; then
  echo "FATAL: builder not found: $BUILDER" >&2
  exit 2
fi

pass=0
fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

# decide "<label>" "<scenario-json>" [extra args...] → runs --decide in an isolated
# sandbox cwd, asserts exit 0 (a decision is always a successful run, even a reject)
# AND that no `pwned` side-effect sentinel was created. Echoes the single-line
# decision JSON so the caller can assert substrings.
DECIDE_OUT=""
decide() {
  local label="$1" scenario="$2"; shift 2
  local box rc sidefx=0
  box="$(mktemp -d)"
  DECIDE_OUT="$(cd "$box" && printf '%s' "$scenario" | python3 "$BUILDER" --decide - "$@" 2>&1)"
  rc=$?
  [ -e "$box/pwned" ] && sidefx=1
  rm -rf "$box"
  if [ "$rc" -eq 0 ]; then ok; else bad "$label: --decide exited $rc (expected 0): $DECIDE_OUT"; fi
  if [ "$sidefx" -eq 0 ]; then ok; else bad "$label: created the pwned sentinel — builder shelled a value!"; fi
}

want() {  # want "<label>" "<substring>"  — assert DECIDE_OUT contains substring
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then ok; else
    bad "$label: missing [$sub] in: $DECIDE_OUT"
  fi
}
nowant() {  # nowant "<label>" "<substring>"  — assert DECIDE_OUT does NOT contain substring
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then
    bad "$label: unexpected [$sub] in: $DECIDE_OUT"
  else ok; fi
}

# The injected [CONCEPT LIBRARY] milestone id + capture date (the runtime-resolved
# reads, fixtured here). Real Brite GTM milestone id so the payload is realistic.
MILE='1714a6b6-64cb-4ddf-8e95-ab7eb844d3b8'
INJ="\"milestone_id\":\"${MILE}\",\"capture_date\":\"2026-06-10\""
# Frozen canonicals seed (hotels = persona gm + offer lobby-lighting; zoos = empty).
SEED="$HERE/../tests/eval/capture-idea-seed"

# ── Tracer: the [Sketch] floor — name + offer only (brand defaults to unsure) ──
decide 'sketch floor' "{\"parsed_fields\":{\"concept_name\":\"National Park Gobo Series\",\"offer\":\"Projected park-scene gobos for venue lighting\"},\"injected_reads\":{${INJ}}}"
want   'sketch floor' '"error": null'
want   'sketch floor' '"status": "Sketch"'
want   'sketch floor' '"label_name": "status:sketch"'
want   'sketch floor' '"match_state": "no"'
want   'sketch floor' '"state": "Backlog"'
want   'sketch floor' '"priority": 0'
want   'sketch floor' '"project": "Brite GTM"'
want   'sketch floor' '"team": "Brite Company"'
want   'sketch floor' "\"milestone\": \"${MILE}\""
want   'sketch floor' '"title": "National Park Gobo Series"'

# ── Maturing happy path — all four clauses satisfied (brand slug normalized) ───
MATURING_PF='"concept_name":"Botanical Gardens Ticketed Walkthrough","offer":"Lit after-dark walkthrough, ticketed rev-share","brand":"labs","source":"Canyons deck p12","icp":"Regional botanical gardens, 50k+ visitors","commercial_model":"rev-share"'
decide 'maturing full' "{\"parsed_fields\":{${MATURING_PF}},\"injected_reads\":{${INJ}}}"
want   'maturing full' '"status": "Maturing"'
want   'maturing full' '"label_name": "status:maturing"'

# ── brand=unsure SUPPRESSES Maturing (the headline) — only diff from full is brand ─
# Drop a regression of the `!= unsure` clause and this row wrongly flips to Maturing.
UNSURE_PF='"concept_name":"Botanical Gardens Ticketed Walkthrough","offer":"Lit after-dark walkthrough, ticketed rev-share","brand":"unsure","source":"Canyons deck p12","icp":"Regional botanical gardens, 50k+ visitors","commercial_model":"rev-share"'
decide 'brand unsure suppresses' "{\"parsed_fields\":{${UNSURE_PF}},\"injected_reads\":{${INJ}}}"
want   'brand unsure suppresses' '"status": "Sketch"'
# ── brand=multi PASSES (proves ONLY unsure suppresses; multi != unsure) ────────
MULTI_PF='"concept_name":"Cross-Brand Holiday Bundle","offer":"Joint Nites+Labs holiday lighting package","brand":"multi","source":"Q3 planning offsite","icp":"Multi-venue operators","commercial_model":"hybrid"'
decide 'brand multi passes' "{\"parsed_fields\":{${MULTI_PF}},\"injected_reads\":{${INJ}}}"
want   'brand multi passes' '"status": "Maturing"'

# ── source both-ways: present (maturing full, above) ↔ blank → Sketch ──────────
SOURCE_BLANK_PF='"concept_name":"Botanical Gardens Ticketed Walkthrough","offer":"Lit after-dark walkthrough, ticketed rev-share","brand":"labs","icp":"Regional botanical gardens, 50k+ visitors","commercial_model":"rev-share"'
decide 'source blank → sketch' "{\"parsed_fields\":{${SOURCE_BLANK_PF}},\"injected_reads\":{${INJ}}}"
want   'source blank → sketch' '"status": "Sketch"'

# ── (ICP ∨ commercial-model) disjunction: ICP-only / model-only → Maturing; neither → Sketch ─
ICP_ONLY_PF='"concept_name":"Zoo Holiday Walkthrough","offer":"After-dark lit zoo walkthrough, ticketed","brand":"labs","source":"zoo ops call","icp":"Regional zoos, 100k+ visitors"'
decide 'icp only → maturing' "{\"parsed_fields\":{${ICP_ONLY_PF}},\"injected_reads\":{${INJ}}}"
want   'icp only → maturing' '"status": "Maturing"'
MODEL_ONLY_PF='"concept_name":"Zoo Holiday Walkthrough","offer":"After-dark lit zoo walkthrough, ticketed","brand":"labs","source":"zoo ops call","commercial_model":"ticketed"'
decide 'model only → maturing' "{\"parsed_fields\":{${MODEL_ONLY_PF}},\"injected_reads\":{${INJ}}}"
want   'model only → maturing' '"status": "Maturing"'
NEITHER_PF='"concept_name":"Zoo Holiday Walkthrough","offer":"After-dark lit zoo walkthrough, ticketed","brand":"labs","source":"zoo ops call"'
decide 'neither icp nor model → sketch' "{\"parsed_fields\":{${NEITHER_PF}},\"injected_reads\":{${INJ}}}"
want   'neither icp nor model → sketch' '"status": "Sketch"'

# ── missing-for-completeness = {brand-if-unsure, source, ICP, commercial model}, fixed order ─
# Floor: all four blank → all four listed (brand=unsure counts; offer/cross-refs/next-move never).
decide 'missing all four' "{\"parsed_fields\":{\"concept_name\":\"National Park Gobo Series\",\"offer\":\"Projected park-scene gobos\"},\"injected_reads\":{${INJ}}}"
want   'missing all four' '"missing_for_completeness": ["brand fit", "source", "ICP", "commercial model"]'
# Full: nothing missing.
decide 'missing none' "{\"parsed_fields\":{${MATURING_PF}},\"injected_reads\":{${INJ}}}"
want   'missing none' '"missing_for_completeness": []'
# Maturing but model still blank → list is NON-empty even though status is Maturing
# (proves the list is not the status predicate; only the blank field is named).
decide 'maturing with gap' "{\"parsed_fields\":{${ICP_ONLY_PF}},\"injected_reads\":{${INJ}}}"
want   'maturing with gap' '"status": "Maturing"'
want   'maturing with gap' '"missing_for_completeness": ["commercial model"]'

# ── 3-state canonical-match footer, classified BY THE BUILDER over the frozen seed ─
BASE_CONCEPT='"concept_name":"Holiday Lighting Pitch","offer":"Seasonal lit installs for venues"'
# Each footer row asserts BOTH the top-level match_state AND the rendered footer
# command string (interpolation), inline so DECIDE_OUT holds that row's output.
# NO match — candidate vertical not in the seed manifest; <v> stays a literal placeholder.
decide 'footer no-match' "{\"parsed_fields\":{${BASE_CONCEPT},\"candidate_vertical\":\"underwater-basket-weaving\"},\"injected_reads\":{${INJ}}}" --seed-dir "$SEED"
want   'footer no-match' '"match_state": "no"'
want   'footer no-match' 'No canonical vertical yet. First `/marketing:new-vertical --slug <v>'
# VERTICAL-ONLY — vertical in manifest but its yaml has no personas/offers; only <v> interpolated.
decide 'footer vertical-only' "{\"parsed_fields\":{${BASE_CONCEPT},\"candidate_vertical\":\"zoos\"},\"injected_reads\":{${INJ}}}" --seed-dir "$SEED"
want   'footer vertical-only' '"match_state": "vertical-only"'
want   'footer vertical-only' 'Vertical `zoos` is canonical'
want   'footer vertical-only' 'has no canonical persona/offer yet'
want   'footer vertical-only' '/marketing:new-persona --vertical zoos --slug <persona-slug>'
nowant 'footer vertical-only' 'already has canonical entries'
# FULL — vertical + proposed persona + proposed offer all present; v/p/o interpolated.
decide 'footer full' "{\"parsed_fields\":{${BASE_CONCEPT},\"candidate_vertical\":\"hotels\",\"candidate_persona\":\"gm\",\"candidate_offer\":\"lobby-lighting\"},\"injected_reads\":{${INJ}}}" --seed-dir "$SEED"
want   'footer full' '"match_state": "full"'
want   'footer full' 'Run `/marketing:plan-campaign --vertical hotels --persona gm --offer lobby-lighting`'
# DOWNGRADE (the headline footer proof) — LLM proposed a persona slug NOT in the
# yaml → builder downgrades FULL → VERTICAL-ONLY (catches the hallucination).
decide 'footer downgrade' "{\"parsed_fields\":{${BASE_CONCEPT},\"candidate_vertical\":\"hotels\",\"candidate_persona\":\"nonexistent-gm\",\"candidate_offer\":\"lobby-lighting\"},\"injected_reads\":{${INJ}}}" --seed-dir "$SEED"
want   'footer downgrade' '"match_state": "vertical-only"'
# The downgrade footer must NOT tell the user to create a new persona/offer (hotels
# already has gm/lobby-lighting → that would duplicate). Distinct from the empty case.
want   'footer downgrade' 'already has canonical entries'
want   "footer downgrade" "don't create duplicates"
nowant 'footer downgrade' 'has no canonical persona/offer yet'
nowant 'footer downgrade' '/marketing:new-persona --vertical hotels'

# ── Step-7 body structure — Sketch floor (blank fields render em-dash) ─────────
decide 'sketch body' "{\"parsed_fields\":{\"concept_name\":\"National Park Gobo Series\",\"offer\":\"Projected park-scene gobos\"},\"injected_reads\":{${INJ}}}"
want   'sketch body' '**Status:** [Sketch]'
want   'sketch body' '**One-sentence offer:** Projected park-scene gobos'
want   'sketch body' '**Brand fit:** unsure'
want   'sketch body' '**Source / inspiration:** —'
want   'sketch body' '**Target ICP guess:** —'
want   'sketch body' '## Promotion criteria — graduate to a campaign milestone when ALL are true'
want   'sketch body' '- [ ] Named lead / champion identified'
want   'sketch body' 'Captured via `/marketing:capture-idea` on 2026-06-10.'

# ── Step-3 brand slug → display in the body; commercial-model hyphen → space ───
decide 'brand+model normalized in body' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"y\",\"brand\":\"labs\",\"commercial_model\":\"install-fee\"},\"injected_reads\":{${INJ}}}"
want   'brand+model normalized in body' '**Brand fit:** Brite Labs'
want   'brand+model normalized in body' '**Commercial model guess:** install fee'

# ── --lead → first promotion checkbox pre-ticked + named ──────────────────────
decide 'lead pre-tick' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"y\",\"lead\":\"Sarah Chen\"},\"injected_reads\":{${INJ}}}"
want   'lead pre-tick' '- [x] Named lead / champion identified — Sarah Chen'

# ── offer_missing → a structured error row (the one required-to-file field) ────
# A decision (exit 0), NOT an infra crash — null payload, no status/footer/label.
decide 'offer missing → error' "{\"parsed_fields\":{\"concept_name\":\"X\",\"brand\":\"labs\"},\"injected_reads\":{${INJ}}}"
want   'offer missing → error' '"error": "offer_missing"'
want   'offer missing → error' '"status": null'
want   'offer missing → error' '"save_issue_payload": null'
want   'offer missing → error' '"match_state": null'
nowant 'offer missing → error' '"label_name": "status:'

# ── Totality (the recurring P1): degenerate injected state must coerce, never crash ─
# null persona/offer sublists → coerced to [] → vertical-only (not full, not a traceback).
decide 'degenerate canonical_state' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"y\",\"candidate_vertical\":\"hotels\",\"candidate_persona\":\"gm\",\"candidate_offer\":\"o\"},\"injected_reads\":{${INJ},\"canonical_state\":{\"in_manifest\":true,\"personas\":null,\"offers\":null}}}"
want   'degenerate canonical_state' '"match_state": "vertical-only"'
# non-dict canonical_state → coerce to no-match, no crash.
decide 'non-dict canonical_state' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"y\",\"candidate_vertical\":\"hotels\"},\"injected_reads\":{${INJ},\"canonical_state\":\"garbage\"}}"
want   'non-dict canonical_state' '"match_state": "no"'
# Hostile field value → rendered as INERT text (the decide() helper already asserts
# exit 0 + no `pwned` sentinel); it appears verbatim in the body, never shelled.
decide 'hostile field inert' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"\$(touch pwned)\"},\"injected_reads\":{${INJ}}}"
want   'hostile field inert' '**One-sentence offer:** $(touch pwned)'

# ── Totality of the SCENARIO WRAPPER (not just decide()): a non-dict parsed_fields /
#    injected_reads must COERCE, never traceback (the recurring pure-builder-crash; in
#    --scenarios batch mode an uncaught exception aborts the whole emit + masks later rows).
decide 'non-dict parsed_fields coerces' "{\"parsed_fields\":[\"x\"],\"injected_reads\":{${INJ}}}"
want   'non-dict parsed_fields coerces' '"error": "offer_missing"'
decide 'non-dict injected_reads coerces' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"y\"},\"injected_reads\":[\"q\"]}"
want   'non-dict injected_reads coerces' '"error": null'
want   'non-dict injected_reads coerces' '"milestone": null'

# ── capture_date missing → body renders "on —", NOT "on None" (str(None) guard) ───
decide 'null capture_date → dash' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"y\"},\"injected_reads\":{\"milestone_id\":\"${MILE}\"}}"
want   'null capture_date → dash' 'on —. Concept Library'
nowant 'null capture_date → dash' 'on None'

# ── offer guard is OFFER-ONLY: a blank concept_name + present offer FILES (title null),
#    it does NOT trigger offer_missing (pins the guard's scope; widening it → RED here).
decide 'name blank offer present files' "{\"parsed_fields\":{\"offer\":\"y\"},\"injected_reads\":{${INJ}}}"
want   'name blank offer present files' '"error": null'
want   'name blank offer present files' '"status": "Sketch"'
want   'name blank offer present files' '"title": null'

# ── non-string / UNHASHABLE brand value coerces to `unsure` (the dict-key lookup in
#    _norm_brand would TypeError on a list/dict brand — must coerce, not crash). ──────
decide 'unhashable brand coerces' "{\"parsed_fields\":{\"concept_name\":\"X\",\"offer\":\"y\",\"brand\":[\"nites\"]},\"injected_reads\":{${INJ}}}"
want   'unhashable brand coerces' '"status": "Sketch"'
want   'unhashable brand coerces' '**Brand fit:** unsure'
want   'unhashable brand coerces' '"missing_for_completeness": ["brand fit", "source", "ICP", "commercial model"]'

echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
