#!/usr/bin/env bash
# Journey/Story template re-alignment v-slice (BC-11983 WS-E precursor).
#
# Locks the canonical journey + story templates the plugin SEEDS into consumers
# (templates/docs/templates/{domain-journey,job-story}.md) and the authoring
# agents (journey-doc-author, story-doc-author) against the drift that produced
# the brite-sites structural regression. Three-layer defense per the
# rubric-lock grep-triad (catchphrase + structural-clause + negative-case):
#   - the seeded templates carry the canonical sections (Decision points,
#     Open questions, Preconditions, QA history, …) and NOT the drifted ones;
#   - the agent prose enumerates the canonical section order and forbids the
#     domain-level duplicate sections;
#   - the seeded templates + authoring agents carry the human-anchored JTBD
#     frame ONLY — the retired T0-4 constraint-spec / system-as-actor frame
#     must not reappear (BC-12134 human-anchoring durability lock);
#   - both orchestrators COPY the two templates into the consumer's
#     docs/templates/ (the missing-template-file root cause).
#
# Bash 3.2 compatible (macOS default). No external deps.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

JOURNEY_TMPL="$PLUGIN_ROOT/templates/docs/templates/domain-journey.md"
STORY_TMPL="$PLUGIN_ROOT/templates/docs/templates/job-story.md"
PERSONA_TMPL="$PLUGIN_ROOT/templates/docs/templates/persona.md"
JOURNEY_AGENT="$PLUGIN_ROOT/agents/journey-doc-author.md"
STORY_AGENT="$PLUGIN_ROOT/agents/story-doc-author.md"
START_CMD="$PLUGIN_ROOT/commands/start-project.md"
RETROFIT_CMD="$PLUGIN_ROOT/commands/retrofit-project.md"

# Retired-frame negative guard (BC-12134): the system-as-subject "the system MUST"
# shape, GENERALIZED so a PARAPHRASED reintroduction (the platform / service / engine /
# generator MUST|SHALL …) is caught — not only the exact string this change removed.
# The generators (story/journey doc-authors + their seeded templates) are kept LITERALLY
# clean of the retired frame: they teach the human frame positively, and any failure-mode
# naming of the retired frame lives in the rubric / lint / audit, never in doc-author prose
# — so the bare-token bans below are intentional, not over-strict.
SYS_SUBJECT_RE='(the|a|an)[*[:space:]]+(system|platform|service|engine|generator)s?[*[:space:]]*(MUST|SHALL)'

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

assert_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label (missing: $path)"; fi
}

# grep -F (fixed string) present
assert_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then pass "$label"
  else fail "$label (needle '$needle' not found in $path)"; fi
}

# grep -F (fixed string) absent
assert_no_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then
    fail "$label (unexpected match for '$needle' in $path)"
  else pass "$label"; fi
}

# grep -E (regex) present — for H2-anchored section checks
assert_grep_re() {
  local label="$1" re="$2" path="$3"
  if grep -qE "$re" "$path" 2>/dev/null; then pass "$label"
  else fail "$label (regex '$re' not found in $path)"; fi
}

# grep -E (regex) absent
assert_no_grep_re() {
  local label="$1" re="$2" path="$3"
  if grep -qE "$re" "$path" 2>/dev/null; then
    fail "$label (unexpected regex match '$re' in $path)"
  else pass "$label"; fi
}

# ── Section 1: Seeded template files present ────────────────────────
section "1/5" "Seeded canonical template files present"

assert_file "journey template present in plugin templates/" "$JOURNEY_TMPL"
assert_file "story template present in plugin templates/" "$STORY_TMPL"
assert_file "persona template present in plugin templates/" "$PERSONA_TMPL"

# Extra-file guard: the docs-template seed subtree must contain EXACTLY these three
# files. run-verify-docs-ecosystem-vslice.sh §3b excludes templates/docs/ from ITS
# count, so without this guard an undeclared fourth file dropped under templates/docs/
# would be caught by neither harness.
DOCS_TMPL_DIR="$PLUGIN_ROOT/templates/docs/templates"
docs_tmpl_count=$(find "$DOCS_TMPL_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [ "$docs_tmpl_count" = "3" ]; then
  pass "templates/docs/templates/ contains exactly 3 seeded templates (no undeclared extras)"
else
  fail "templates/docs/templates/ has $docs_tmpl_count files, expected 3 (domain-journey.md + job-story.md + persona.md)"
  find "$DOCS_TMPL_DIR" -type f -name '*.md' 2>/dev/null | sed "s|$PLUGIN_ROOT/||; s/^/    /"
fi

# ── Section 2: Journey template — canonical sections + no drift ──────
section "2/5" "Journey template carries canonical sections (and not the drift)"

assert_grep_re "journey: ## Actor / Persona"        '^## Actor / Persona'                          "$JOURNEY_TMPL"
assert_grep_re "journey: ## Scenario + Expectations" '^## Scenario \+ Expectations'                 "$JOURNEY_TMPL"
assert_grep_re "journey: ## Journey phases"          '^## Journey phases'                           "$JOURNEY_TMPL"
assert_grep_re "journey: ## Decision points (J6)"    '^## Decision points'                          "$JOURNEY_TMPL"
assert_grep_re "journey: ## Out of scope"            '^## Out of scope'                             "$JOURNEY_TMPL"
assert_grep_re "journey: ## Related domains"         '^## Related domains and cross-scenario journeys' "$JOURNEY_TMPL"
assert_grep_re "journey: ## Open questions (J8)"     '^## Open questions'                           "$JOURNEY_TMPL"
assert_grep_re "journey: ## See also"                '^## See also'                                "$JOURNEY_TMPL"
assert_grep_re "journey: ## L2 review summary (FDA-additive)" '^## L2 review summary'               "$JOURNEY_TMPL"
# per-phase sub-structure (pain/opps/job-stories live PER PHASE)
assert_grep "journey: per-phase Pain points marker"        "**Pain points:**"           "$JOURNEY_TMPL"
assert_grep "journey: per-phase Opportunities marker"      "**Opportunities:**"         "$JOURNEY_TMPL"
assert_grep "journey: per-phase Job stories table marker"  "**Job stories in this phase:**" "$JOURNEY_TMPL"
# NEGATIVE — the drifted domain-level standalone sections must NOT exist
assert_no_grep_re "journey: NO standalone ## Narrative shape (drift)"        '^## Narrative shape'        "$JOURNEY_TMPL"
assert_no_grep_re "journey: NO standalone ## Sub-flows in this domain (drift)" '^## Sub-flows'            "$JOURNEY_TMPL"
assert_no_grep_re "journey: NO domain-level ## Pain points (per-phase only)" '^## Pain points'           "$JOURNEY_TMPL"
assert_no_grep_re "journey: NO domain-level ## Opportunities (per-phase only)" '^## Opportunities'       "$JOURNEY_TMPL"
assert_no_grep_re "journey: NO ## Title + domain code (Q26 mod 3 dropped it; H1 carries it)" '^## Title \+ domain code' "$JOURNEY_TMPL"
# NEGATIVE — the retired T0-4 system-as-actor / constraint-lens framing must be GONE (BC-12134)
assert_no_grep "journey: NO 'second actor' system framing (retired BC-12134)"  "second actor"   "$JOURNEY_TMPL"
assert_no_grep "journey: NO 'constraint lens' framing (retired BC-12134)"      "constraint lens" "$JOURNEY_TMPL"
# Symmetric with the story template + both agents: catch a paraphrased reintroduction,
# not only the two literals that existed before (the journey template is a seeded generator).
assert_no_grep    "journey: NO 'constraint-spec' terminology (retired BC-12134)"      "constraint-spec" "$JOURNEY_TMPL"
assert_no_grep_re "journey: NO system-subject MUST/SHALL framing (retired BC-12134)"  "$SYS_SUBJECT_RE" "$JOURNEY_TMPL"

# ── Section 3: Story template — canonical sections + frames + no boilerplate ──
section "3/5" "Story template carries canonical sections + the human JTBD frame (no constraint-spec residue, no boilerplate)"

assert_grep_re "story: ## Job story"            '^## Job story'              "$STORY_TMPL"
assert_grep_re "story: ## Actor"                '^## Actor'                  "$STORY_TMPL"
assert_grep_re "story: ## Preconditions (restored)" '^## Preconditions'      "$STORY_TMPL"
assert_grep_re "story: ## Acceptance criteria"  '^## Acceptance criteria'    "$STORY_TMPL"
assert_grep_re "story: ## Out of scope / no-gos" '^## Out of scope / no-gos' "$STORY_TMPL"
assert_grep_re "story: ## Cross-domain dependencies (conditional gate)" '^## Cross-domain dependencies' "$STORY_TMPL"
assert_grep_re "story: ## Cross-references"     '^## Cross-references'        "$STORY_TMPL"
assert_grep_re "story: ## QA history (restored)" '^## QA history'            "$STORY_TMPL"
# human JTBD frame present; the T0-4 constraint-spec frame is RETIRED (BC-12134 human-anchoring)
assert_grep "story: human JTBD marker (**When**)"     "**When**"      "$STORY_TMPL"
assert_grep "story: human JTBD marker (**I want to**)" "**I want to**" "$STORY_TMPL"
assert_grep "story: human JTBD marker (**so I can**)"  "**so I can**"  "$STORY_TMPL"
assert_no_grep "story: NO constraint-spec frame 'the system **MUST**' (retired BC-12134)" "the system **MUST**" "$STORY_TMPL"
assert_no_grep_re "story: NO 'constraint-spec' / 'constraint spec' terminology (retired BC-12134)" 'constraint[ -]spec' "$STORY_TMPL"
assert_no_grep_re "story: NO system-subject MUST/SHALL framing, any noun (retired BC-12134)" "$SYS_SUBJECT_RE" "$STORY_TMPL"
assert_no_grep "story: GOLD gherkin — no 'Feature:' wrapper (retired BC-12134)" "Feature:" "$STORY_TMPL"
# Positive asserts above confirm the human frame is TAUGHT; this confirms the worked GOLD
# infra example (operator-anchored sitemap job story) isn't silently deleted — exclusivity
# of the human frame rests on the negative guards, presence of the example on this one.
assert_grep "story: GOLD infra example present (operator-anchored sitemap job story)" "my domain's pages go live" "$STORY_TMPL"
# full canonical frontmatter — per-discipline delivery mirror feeding INDEX.md
assert_grep "story: frontmatter eng_status (INDEX mirror)"    "eng_status:"    "$STORY_TMPL"
assert_grep "story: frontmatter qa_status (INDEX mirror)"     "qa_status:"     "$STORY_TMPL"
assert_grep "story: frontmatter children: map"               "children:"      "$STORY_TMPL"
# Anti-boilerplate is two-sided: the template must TEACH against the circular
# placeholder clause (positive prohibition) AND must not SHIP it inside the
# example gherkin block. A naive whole-file negative would false-fail on the
# prohibition's own counterexample quote (the deprecation-note gaming trap the
# grep-triad warns about) — so scope the negative to the fenced gherkin block.
assert_grep "story: AC guidance forbids the boilerplate clause" \
  "Never emit the placeholder clauses" "$STORY_TMPL"
assert_grep_re "story: an example gherkin block is present (not just guidance)" \
  '^```gherkin' "$STORY_TMPL"
GHERKIN_BLOCK="$(awk '/^```gherkin/{f=1;next} /^```/{f=0} f' "$STORY_TMPL")"
if printf '%s' "$GHERKIN_BLOCK" | grep -qF "Then the outcome described in 'So I can"; then
  fail "story: example gherkin block ships the boilerplate AC clause"
else
  pass "story: example gherkin block carries no boilerplate AC clause"
fi

# ── Section 4: Agent prose re-aligned to canonical ──────────────────
section "4/5" "Authoring agents enumerate the canonical section order"

# journey-doc-author: canonical sections named + per-phase-only rule + no old drift
assert_grep "journey-author: names ## Decision points"   "## Decision points"   "$JOURNEY_AGENT"
assert_grep "journey-author: names ## Open questions"    "## Open questions"    "$JOURNEY_AGENT"
assert_grep "journey-author: per-phase-only rule"        "per-phase only"       "$JOURNEY_AGENT"
assert_no_grep "journey-author: drifted '8 H2 sections after Q26 mod 3' GONE" \
  "8 H2 sections after Q26 mod 3" "$JOURNEY_AGENT"
assert_no_grep "journey-author: drifted 'why-this-domain-exists' GONE" \
  "why-this-domain-exists" "$JOURNEY_AGENT"
# NEGATIVE — the retired T0-4 system-as-actor / constraint-lens framing must be GONE (BC-12134)
assert_no_grep "journey-author: NO 'second actor' system framing (retired BC-12134)"  "second actor"   "$JOURNEY_AGENT"
assert_no_grep "journey-author: NO 'constraint lens' framing (retired BC-12134)"      "constraint lens" "$JOURNEY_AGENT"
# Symmetric with the story-author guards: catch a paraphrased reintroduction, not just the
# two strings that happened to exist before (the journey author is a generator too).
assert_no_grep    "journey-author: NO 'constraint-spec' terminology (retired BC-12134)"      "constraint-spec" "$JOURNEY_AGENT"
assert_no_grep_re "journey-author: NO system-subject MUST/SHALL framing (retired BC-12134)"  "$SYS_SUBJECT_RE" "$JOURNEY_AGENT"

# story-doc-author: canonical sections named + human-anchored frame ONLY (constraint-spec RETIRED BC-12134)
assert_grep "story-author: names ## Preconditions"   "## Preconditions"   "$STORY_AGENT"
assert_grep "story-author: names ## QA history"      "## QA history"      "$STORY_AGENT"
assert_grep "story-author: teaches the human JTBD frame"           "I want to"     "$STORY_AGENT"
assert_no_grep    "story-author: NO 'constraint-spec' frame rule (retired BC-12134)"      "constraint-spec" "$STORY_AGENT"
assert_no_grep_re "story-author: NO system-subject MUST/SHALL framing (retired BC-12134)" "$SYS_SUBJECT_RE" "$STORY_AGENT"
assert_grep "story-author: retains cross-domain-deps gate awareness" "cross-domain-deps-bidirectional" "$STORY_AGENT"

# ── Section 5: Orchestrators copy the templates into consumers ──────
section "5/5" "Both orchestrators seed the templates into consumer docs/templates/"

for cmd_label in "start-project:$START_CMD" "retrofit-project:$RETROFIT_CMD"; do
  label="${cmd_label%%:*}"
  cmd="${cmd_label#*:}"
  assert_grep "$label SRC array includes domain-journey.md" \
    "templates/docs/templates/domain-journey.md" "$cmd"
  assert_grep "$label SRC array includes job-story.md" \
    "templates/docs/templates/job-story.md" "$cmd"
  assert_grep "$label SRC array includes persona.md" \
    "templates/docs/templates/persona.md" "$cmd"
  # Needle includes the $REPO_ROOT/ prefix so it matches ONLY the TARGET-array line,
  # not the SRC line ($CLAUDE_PLUGIN_ROOT/templates/docs/templates/<f>), whose path
  # contains "/docs/templates/<f>" as a substring.
  assert_grep "$label TARGET array writes \$REPO_ROOT/docs/templates/domain-journey.md" \
    "\$REPO_ROOT/docs/templates/domain-journey.md" "$cmd"
  assert_grep "$label TARGET array writes \$REPO_ROOT/docs/templates/job-story.md" \
    "\$REPO_ROOT/docs/templates/job-story.md" "$cmd"
  assert_grep "$label TARGET array writes \$REPO_ROOT/docs/templates/persona.md" \
    "\$REPO_ROOT/docs/templates/persona.md" "$cmd"
  assert_grep "$label orchestrator prose states the seeded-template count (currently 12)" \
    "Build the 12 template-source" "$cmd"
  # Lock the confirmation-line count too — it must move in lockstep with the array
  # count (the stale-"9" drift class already hit once, fixed in 63ae7a0e).
  assert_grep "$label confirmation line states 12 files + docs/templates/" \
    "12 files written under scripts/ + docs/templates/" "$cmd"
done

# ── Summary ──────────────────────────────────────────────────────────
printf '\nTemplate-alignment v-slice summary: %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
printf 'RESULT pass=%d fail=%d skip=%d\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
