#!/usr/bin/env bash
# Persona authoring subsystem v-slice (BC-12905 C2, FDA persona subsystem).
#
# Locks the prose contract of the four persona-subsystem artifacts so the
# depth-spine cannot silently drift back to the thin pre-PRD persona shape
# (the one-line-stub class brite-roster surfaced):
#
#   1. templates/docs/templates/persona.md     the canonical depth-spine (5 FLOOR sections)
#   2. agents/persona-doc-author.md            the sibling author (whole-file, no builder)
#   3. skills/_shared/quality-rubric.md        persona dimensions P1–P5
#   4. agents/quality-reviewer.md              the persona_doc doc_kind
#
# This is a PROSE tripwire, not a behavior test: persona-doc-author and
# quality-reviewer are LLM agents, so this asserts the instruction text carries
# the persona depth-spine + P1–P5 contract — the same kind of lock
# run-quality-reviewer-resolve-first-vslice.sh (#502) provides for the reviewer
# and run-template-alignment-vslice.sh provides for the story/journey authors.
#
# Composition note: the DETERMINISTIC required-sections floor (thin-stub HARD
# fail) is the persona-exists gate's job (BC-12573, Lane A) — this harness locks
# the plugin-side template + grader prose, not the audit gate.
#
# Bash 3.2 compatible (macOS default). No external deps.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PERSONA_TMPL="$PLUGIN_ROOT/templates/docs/templates/persona.md"
PERSONA_AGENT="$PLUGIN_ROOT/agents/persona-doc-author.md"
RUBRIC="$PLUGIN_ROOT/skills/_shared/quality-rubric.md"
QR_AGENT="$PLUGIN_ROOT/agents/quality-reviewer.md"

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

# grep -E (regex) present, anchored
assert_grep_re() {
  local label="$1" re="$2" path="$3"
  if grep -qE "$re" "$path" 2>/dev/null; then pass "$label"
  else fail "$label (pattern '$re' not found in $path)"; fi
}

# grep -F (fixed string) absent
assert_no_grep() {
  local label="$1" needle="$2" path="$3"
  if grep -qF "$needle" "$path" 2>/dev/null; then
    fail "$label (unexpected match for '$needle' in $path)"
  else pass "$label"; fi
}

# ── Section 1: all four artifacts present ────────────────────────────
section "1/6" "Persona subsystem artifacts present"
assert_file "persona template present"      "$PERSONA_TMPL"
assert_file "persona-doc-author present"    "$PERSONA_AGENT"
assert_file "quality-rubric present"        "$RUBRIC"
assert_file "quality-reviewer present"      "$QR_AGENT"

# ── Section 2: template carries the 5 FLOOR depth-spine sections ─────
section "2/6" "persona.md carries the depth-spine FLOOR sections (not the thin pre-PRD shape)"
# The five FLOOR sections the depth check + persona-exists gate key on.
assert_grep_re "template: ## At a glance"                 '^## At a glance'                    "$PERSONA_TMPL"
assert_grep_re "template: ## How they think"              '^## How they think'                 "$PERSONA_TMPL"
assert_grep_re "template: ## What they see — and what they don't" '^## What they see — and what they' "$PERSONA_TMPL"
assert_grep_re "template: ## Hand-offs"                   '^## Hand-offs'                       "$PERSONA_TMPL"
assert_grep_re "template: ## In their words"              '^## In their words'                  "$PERSONA_TMPL"
# The two load-bearing At-a-glance rows that separate behavioral from demographic.
assert_grep "template: At-a-glance Mental unit row"               "**Mental unit**"               "$PERSONA_TMPL"
assert_grep "template: At-a-glance failure-they-can't-absorb row" "The failure they can't absorb" "$PERSONA_TMPL"
# Slug-keyed canonical path (G1) + the no-Linear-children frontmatter.
assert_grep "template: linear_label frontmatter (no Linear children)" "linear_label: persona/<slug>" "$PERSONA_TMPL"
assert_grep "template: cross-links the persona_doc reviewer kind"      "doc_kind: persona_doc"        "$PERSONA_TMPL"

# ── Section 3: persona-doc-author prose contract ────────────────────
section "3/6" "persona-doc-author teaches whole-file + depth-spine + no-fabrication"
# Whole-file (NOT body-only) — the no-builder decision.
assert_grep "author: emits the WHOLE file (front-matter + body)" "whole file" "$PERSONA_AGENT"
assert_grep "author: no persona builder"                         "no persona builder" "$PERSONA_AGENT"
# Anchored on the same behavioral spine as D7/J2.
assert_grep "author: anchors on the failure they cannot absorb"  "failure they cannot absorb" "$PERSONA_AGENT"
assert_grep "author: mental unit in domain terms not machinery"  "never** the system's internals" "$PERSONA_AGENT"
# Scores to the P1–P5 bar; resolves adjacents (P4) rather than fabricating.
assert_grep "author: writes to the P1–P5 bar"                    "P1–P5" "$PERSONA_AGENT"
assert_grep "author: resolves named adjacents (P4, no fabrication)" "an invented adjacent" "$PERSONA_AGENT"
# Slug-keyed path + last_reviewed the only stamped field.
assert_grep "author: canonical slug-keyed path"                  "docs/product/personas/<slug>.md" "$PERSONA_AGENT"
assert_grep "author: last_reviewed the only dispatcher-stamped field" "last_reviewed" "$PERSONA_AGENT"
# NEGATIVE — must NOT claim body-only or a frontmatter builder (the story/journey pattern it deliberately breaks).
assert_no_grep "author: NOT body-only (no build_persona_frontmatter.py)" "build_persona_frontmatter" "$PERSONA_AGENT"

# ── Section 4: rubric persona dimensions P1–P5 ──────────────────────
section "4/6" "quality-rubric.md carries persona dimensions P1–P5 on the D7/J2 spine"
assert_grep "rubric: persona dimensions header"      "# Persona dimensions (per standalone persona doc)" "$RUBRIC"
assert_grep "rubric: P1 at-a-glance substance"       "## P1 — At-a-glance substance" "$RUBRIC"
assert_grep "rubric: P2 how-they-think depth"        "## P2 — How-they-think depth" "$RUBRIC"
assert_grep "rubric: P3 scope shape"                 "## P3 — Scope shape" "$RUBRIC"
assert_grep "rubric: P4 hand-off validity"           "## P4 — Hand-off validity" "$RUBRIC"
assert_grep "rubric: P5 domain-specificity and voice" "## P5 — Domain-specificity and voice" "$RUBRIC"
# Three-layer framing (D/J/P), not the old two-layer.
assert_grep "rubric: three-layer spine framing"      "Three layers of the same spine" "$RUBRIC"
assert_no_grep "rubric: NO stale two-layer framing"  "Two layers of the same spine" "$RUBRIC"
# Corpus-dependency classification: P4 + P5-reuse are corpus-dependent (resolve-first);
# P1/P2/P3 are single-doc-judgeable.
assert_grep "rubric: P1/P2/P3 listed single-doc-judgeable" "P1, P2, P3" "$RUBRIC"
assert_grep "rubric: P4 in corpus-dependent table"   "P4 (hand-off validity)" "$RUBRIC"
assert_grep "rubric: P5 byte-reuse in corpus-dependent table" "P5 (persona byte-reuse)" "$RUBRIC"

# ── Section 5: reviewer persona_doc doc_kind ────────────────────────
section "5/6" "quality-reviewer.md routes the persona_doc doc_kind to P1–P5"
assert_grep "reviewer: persona_doc in doc_kind enum"  "story_doc | journey_doc | persona_doc" "$QR_AGENT"
assert_grep "reviewer: persona_doc selects P1–P5"     "persona_doc\` → P1–P5" "$QR_AGENT"
# Persona corpus dims wired into resolve-first Step 5 + Conventions.
assert_grep "reviewer: P4/P5 in Step-5 corpus list"   "P4 hand-off adjacent validity, P5 persona byte-reuse" "$QR_AGENT"
assert_grep "reviewer: P4/P5 in Conventions resolve-first list" "J4, P4, P5" "$QR_AGENT"
# Guard: persona additions must not have tripped the #502 resolve-first contract.
assert_grep "reviewer: #502 resolve-first title still present" \
  "Resolve corpus-dependent claims with your own tools first" "$QR_AGENT"
assert_no_grep "reviewer: NO retired flag-gate posture reintroduced" \
  "Absence of a field means you do NOT have that evidence" "$QR_AGENT"

# ── Section 6: synthetic fixtures exhibit the thin-vs-rich split ─────
section "6/6" "synthetic fixtures demonstrate the thin-stub-fails / rich-passes split"
# Make the fixtures load-bearing: the thin stub must LACK every FLOOR section
# (this is *why* it fails the depth floor); the rich pair must CARRY all five
# plus the two At-a-glance load-bearing rows, and its hand-off must resolve to a
# real sibling (P4 — no fabricated adjacent). These are the same inputs the
# BC-12573 persona-exists gate calibrates against.
FIX_DIR="$PLUGIN_ROOT/tests/fixtures/synthetic-persona-quality"
THIN_PERSONA="$FIX_DIR/thin-stub/docs/product/personas/commercial-buyer.md"
RICH_PERSONA="$FIX_DIR/rich-persona/docs/product/personas/dispatcher.md"
RICH_ADJACENT="$FIX_DIR/rich-persona/docs/product/personas/booking-agent.md"

assert_file "fixture: thin-stub persona present"                       "$THIN_PERSONA"
assert_file "fixture: rich persona present"                            "$RICH_PERSONA"
assert_file "fixture: rich persona hand-off target present"            "$RICH_ADJACENT"

# Thin stub LACKS every FLOOR section (demonstrates the deterministic-floor fail).
assert_no_grep "fixture: thin stub LACKS ## At a glance"              "## At a glance"        "$THIN_PERSONA"
assert_no_grep "fixture: thin stub LACKS ## How they think"          "## How they think"     "$THIN_PERSONA"
assert_no_grep "fixture: thin stub LACKS ## What they see"           "## What they see"      "$THIN_PERSONA"
assert_no_grep "fixture: thin stub LACKS ## Hand-offs"               "## Hand-offs"          "$THIN_PERSONA"
assert_no_grep "fixture: thin stub LACKS ## In their words"          "## In their words"     "$THIN_PERSONA"

# Rich persona CARRIES every FLOOR section + the two load-bearing At-a-glance rows.
assert_grep_re "fixture: rich persona has ## At a glance"             '^## At a glance'        "$RICH_PERSONA"
assert_grep_re "fixture: rich persona has ## How they think"          '^## How they think'     "$RICH_PERSONA"
assert_grep_re "fixture: rich persona has ## What they see — and …"   '^## What they see — and what they' "$RICH_PERSONA"
assert_grep_re "fixture: rich persona has ## Hand-offs"               '^## Hand-offs'          "$RICH_PERSONA"
assert_grep_re "fixture: rich persona has ## In their words"          '^## In their words'     "$RICH_PERSONA"
assert_grep "fixture: rich persona has Mental unit row"               "**Mental unit**"               "$RICH_PERSONA"
assert_grep "fixture: rich persona has the-failure-they-can't-absorb row" "The failure they can't absorb" "$RICH_PERSONA"
# Hand-off resolves to a real sibling (P4 no-fabrication), both directions.
assert_grep "fixture: rich persona hand-off links the adjacent persona" "booking-agent.md" "$RICH_PERSONA"
assert_grep "fixture: rich adjacent hand-off links back to the persona" "dispatcher.md"    "$RICH_ADJACENT"

# ── Summary ──────────────────────────────────────────────────────────
printf '\npersona subsystem v-slice summary: %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
printf 'RESULT pass=%d fail=%d skip=%d\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
