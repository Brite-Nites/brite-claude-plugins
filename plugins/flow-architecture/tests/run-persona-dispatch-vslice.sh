#!/usr/bin/env bash
# Persona auto-dispatch v-slice (BC-14018).
#
# Locks the prose contract of the persona-authoring DISPATCH wiring so the
# orchestrators cannot silently stop authoring personas (the "defined-but-unwired"
# state the persona subsystem shipped in #505 and this ticket closes):
#
#   1. skills/flow-persona-author/SKILL.md        the dispatch sub-skill (mirror of flow-journey-author)
#   2. commands/start-project.md                  greenfield orchestrator wires it as a phase AFTER journey-author
#   3. commands/add-domain.md                     incremental-add orchestrator wires it as a phase AFTER journey-author
#   4. commands/retrofit-project.md               retrofit orchestrator wires it as a phase AFTER journey-author
#
# This is a PROSE tripwire, not a behavior test: the orchestrators + skill are
# AI-dispatched markdown, so this asserts the instruction text carries the
# dispatch contract — the same kind of lock run-persona-subsystem-vslice.sh
# (#505) provides for the persona authoring artifacts and run-template-alignment-vslice.sh
# provides for the templates.
#
# Bash 3.2 compatible (macOS default). No external deps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILL="$PLUGIN_ROOT/skills/flow-persona-author/SKILL.md"
START="$PLUGIN_ROOT/commands/start-project.md"
ADD="$PLUGIN_ROOT/commands/add-domain.md"
RETROFIT="$PLUGIN_ROOT/commands/retrofit-project.md"

PASS=0
FAIL=0

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
# grep -E (regex) present
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

# ── Section 1: the dispatch sub-skill exists + carries its contract ──────────
section "1/4" "flow-persona-author SKILL.md carries the dispatch contract"
assert_file "skill present" "$SKILL"
# NOT user-invocable (orchestrator-dispatched only, per Q7).
assert_grep "skill: user-invocable false"       "user-invocable: false" "$SKILL"
assert_grep "skill: disable-model-invocation"   "disable-model-invocation: true" "$SKILL"
# Dispatches the per-persona agent.
assert_grep "skill: dispatches persona-doc-author" "persona-doc-author" "$SKILL"
# Whole-file / NO deterministic builder — the differentiator from story/journey authors.
assert_grep "skill: whole-file (no builder)"    "NO deterministic frontmatter builder" "$SKILL"
assert_grep_re "skill: only last_reviewed stamped" "only .last_reviewed. is dispatcher-supplied" "$SKILL"
# Ordering: runs AFTER flow-journey-author.
assert_grep "skill: runs after flow-journey-author" "AFTER \`flow-journey-author\`" "$SKILL"
# Persona set = reconciled union of story slugs ∪ inventory column, minus honest-empty.
assert_grep "skill: persona set is the union of story slugs" "union" "$SKILL"
assert_grep "skill: minus honest-empty"         "honest-empty" "$SKILL"
# Idempotency skip-if-exists + INDEX promotion contract.
assert_grep "skill: skip-if-exists"             "skip-if-exists" "$SKILL"
assert_grep "skill: INDEX Drafted then Reviewed" "never self-certifies" "$SKILL"
# 1 agent per unique persona slug (NOT per domain).
assert_grep "skill: 1 agent per persona slug"   "1 agent per unique persona slug" "$SKILL"
# NEGATIVE — must NOT claim a deterministic persona frontmatter builder.
assert_no_grep "skill: NOT a builder (no build_persona_frontmatter)" "build_persona_frontmatter" "$SKILL"

# ── Section 2: /flow:start-project wires it as a phase AFTER journey-author ──
section "2/4" "start-project dispatches flow-persona-author after journey-author"
assert_grep "start-project: 9 phases (was 8)"   "9 phases / 4 gates" "$START"
assert_grep "start-project: Phase 7 persona author" "## Phase 7: persona author" "$START"
assert_grep "start-project: dispatches flow-persona-author" "flow-persona-author" "$START"
assert_grep "start-project: journey author still Phase 6" "## Phase 6: journey author" "$START"
assert_grep "start-project: regen index moved to Phase 8" "## Phase 8: regen index" "$START"
assert_grep "start-project: complete moved to Phase 9" "## Phase 9: complete" "$START"
# Persona phase advances the breadcrumb to 8 (chain coherence).
assert_grep "start-project: persona phase breadcrumb → 8" 'current_phase: 8`, `completed_phases: ["1", "2", "3", "4", "5", "6", "7"]' "$START"

# ── Section 3: /flow:add-domain wires it as a phase AFTER journey-author ─────
section "3/4" "add-domain dispatches flow-persona-author after journey-author"
assert_grep "add-domain: 7 phases (was 6)"      "7 phases / 2 gates" "$ADD"
assert_grep "add-domain: Phase 6 persona author" "## Phase 6: persona author" "$ADD"
assert_grep "add-domain: dispatches flow-persona-author" "flow-persona-author" "$ADD"
assert_grep "add-domain: journey author still Phase 5" "## Phase 5: journey author" "$ADD"
assert_grep "add-domain: regen index moved to Phase 7" "## Phase 7: regen index" "$ADD"
# Persona phase advances the breadcrumb to 7 (chain coherence).
assert_grep "add-domain: persona phase breadcrumb → 7" 'next phase is `7`' "$ADD"

# ── Section 4: /flow:retrofit-project wires it as a phase AFTER journey-author ─
section "4/4" "retrofit-project dispatches flow-persona-author after journey-author"
assert_grep "retrofit: 10 phases (was 9)"        "10 phases / 5 gates" "$RETROFIT"
assert_grep "retrofit: Phase 8 persona author"   "## Phase 8: persona author" "$RETROFIT"
assert_grep "retrofit: dispatches flow-persona-author" "flow-persona-author" "$RETROFIT"
assert_grep "retrofit: journey author still Phase 7" "## Phase 7: journey author" "$RETROFIT"
assert_grep "retrofit: regen index moved to Phase 9" "## Phase 9: regen index" "$RETROFIT"
assert_grep "retrofit: complete moved to Phase 10" "## Phase 10: complete" "$RETROFIT"
# Persona phase advances the breadcrumb to 9 (chain coherence).
assert_grep "retrofit: persona phase breadcrumb → 9" 'current_phase: 9`, `completed_phases: ["1", "2", "3", "4", "5", "6", "7", "8"]' "$RETROFIT"
# ADR-041: retrofit's code-evidence layer must NOT feed personas (the Follow-on-A decision).
assert_grep "retrofit: personas not code-derived (ADR-041)" "intent/journey-derived, NOT code-derived (ADR-041)" "$RETROFIT"

# ── Summary ─────────────────────────────────────────────────────────────────
printf '\npersona-dispatch v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
