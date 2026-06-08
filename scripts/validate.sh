#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# ── Paths ──────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

# ── Counters & helpers ─────────────────────────────────────────────────
errors=0
warnings=0

pass()    { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail()    { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; errors=$((errors + 1)); }
warn()    { printf "  \033[33mWARN\033[0m  %s\n" "$1"; warnings=$((warnings + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# ── Prereqs ────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found." >&2
  exit 2
fi

# Extract frontmatter (lines between first --- and second ---)
frontmatter() {
  sed -n '2,/^---$/{/^---$/d; p;}' "$1"
}

# Get a YAML value by key (simple single-line values only)
yaml_val() {
  # $1 = frontmatter text, $2 = key
  echo "$1" | grep "^$2:" | head -1 | sed "s/^$2: *//" || true
}

echo "Brite Plugin Validator"
echo "Repo root: $REPO_ROOT"

# ══════════════════════════════════════════════════════════════════════
# Section 1 — Marketplace JSON Validity
# ══════════════════════════════════════════════════════════════════════
section "1. JSON Validity (marketplace)"

if [ ! -f "$MARKETPLACE" ]; then
  fail "$MARKETPLACE does not exist"
else
  label="${MARKETPLACE#"$REPO_ROOT"/}"
  if python3 -m json.tool "$MARKETPLACE" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label is not valid JSON"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2 — Marketplace Fields
# ══════════════════════════════════════════════════════════════════════
section "2. Marketplace Fields"

if [ -f "$MARKETPLACE" ]; then
  mp_errors=$(python3 -c "
import json, sys, os

with open('$MARKETPLACE') as f:
    data = json.load(f)

errors = []

for field in ['name', 'plugins']:
    if field not in data:
        errors.append(f'Missing top-level field: {field}')

owner = data.get('owner', {})
if not owner.get('name'):
    errors.append('Missing owner.name')

for i, plugin in enumerate(data.get('plugins', [])):
    for field in ['name', 'source']:
        if field not in plugin:
            errors.append(f'plugins[{i}] missing {field}')
    source = plugin.get('source', '')
    resolved = os.path.normpath(os.path.join('$REPO_ROOT', source))
    if not os.path.isdir(resolved):
        errors.append(f'plugins[{i}] source resolves to {resolved} which does not exist')

for e in errors:
    print(f'ERROR:{e}')
if not errors:
    print('OK')
" 2>&1)

  if [ "$mp_errors" = "OK" ]; then
    pass "marketplace.json fields valid"
  else
    while IFS= read -r line; do
      fail "${line#ERROR:}"
    done <<< "$mp_errors"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b — Version Consistency
# ══════════════════════════════════════════════════════════════════════
section "2b. Version Consistency"

# Collect all plugin.json paths
pj_paths=()
for pdir in "$REPO_ROOT"/plugins/*/; do
  pj="$pdir.claude-plugin/plugin.json"
  if [ -f "$pj" ]; then
    pj_paths+=("$pj")
  fi
done

# Check each plugin.json version against its marketplace entry version
ver_result=$(python3 - "$MARKETPLACE" "${pj_paths[@]}" <<'PYEOF'
import json, sys

marketplace_path = sys.argv[1]
plugin_paths = sys.argv[2:]
errors = []

# Build marketplace version lookup by plugin name
mp_versions = {}
try:
    with open(marketplace_path) as f:
        data = json.load(f)
    for entry in data.get('plugins', []):
        mp_versions[entry.get('name', '')] = entry.get('version', '')
except (FileNotFoundError, json.JSONDecodeError):
    pass

for path in plugin_paths:
    try:
        with open(path) as f:
            pj = json.load(f)
        pj_name = pj.get('name', '')
        pj_ver = pj.get('version', '')
        mp_ver = mp_versions.get(pj_name, '')
        if pj_ver and mp_ver and pj_ver != mp_ver:
            errors.append(f'{pj_name}: plugin.json={pj_ver} marketplace={mp_ver}')
    except (FileNotFoundError, json.JSONDecodeError):
        errors.append(f'{path}=UNREADABLE')

if errors:
    print('MISMATCH:' + ', '.join(errors))
else:
    print('OK')
PYEOF
)

if [[ "$ver_result" == MISMATCH:* ]]; then
  fail "Version mismatch: ${ver_result#MISMATCH:}"
else
  pass "Version consistent across plugins"
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b' — flow-architecture helper-script unit tests (BC-10728)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/test-helper-scripts.sh — bash unit
# tests for the 4 FDA helper scripts (flow-detect-mode, flow-detect-fda-shape,
# flow-resume-breadcrumb, flow-classify-domain-state). Section 4 includes the
# BC-10352 regression-lock fixture (lowercase + backtick-wrap + em-dash
# inventory shape) per Q40 R3 promotion criterion (BC-10728 § AC#2 ship-order
# coupling). Pass count auto-derived from the harness's RESULT contract line.
#
# TODO: when a 2nd plugin adopts the bash-harness pattern, generalize this
# section to enumerate plugins/*/tests/test-*.sh (matches the Section 13
# TODO at line 813 + Section 15a TODO).
section "2b'. flow-architecture helper-script unit tests (BC-10728)"

fda_helper_test="$REPO_ROOT/plugins/flow-architecture/tests/test-helper-scripts.sh"

if [ ! -f "$fda_helper_test" ]; then
  warn "plugins/flow-architecture/tests/test-helper-scripts.sh not found — skipped"
else
  if fda_helper_out=$(bash "$fda_helper_test" 2>&1); then
    fda_pass_count=$(printf '%s\n' "$fda_helper_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture helper-script unit tests (${fda_pass_count:-?} assertions)"
  else
    fail "flow-architecture helper-script unit tests failed — run plugins/flow-architecture/tests/test-helper-scripts.sh for details"
    printf '%s\n' "$fda_helper_out" | tail -25 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b'' — flow-architecture verify-docs ecosystem vslice (BC-11029, Q58)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-verify-docs-ecosystem-vslice.sh —
# asserts the 10 template files under plugins/flow-architecture/templates/
# exist with required preamble, no brite-roster/brite-nites string leaks
# into templates, and no <PLACEHOLDER> strings appear outside templates/.
# See Q58 § Sub-decision 1 for the schema-discipline contract.
section "2b''. flow-architecture verify-docs ecosystem vslice (BC-11029, Q58)"

fda_ecosystem_test="$REPO_ROOT/plugins/flow-architecture/tests/run-verify-docs-ecosystem-vslice.sh"

if [ ! -f "$fda_ecosystem_test" ]; then
  warn "plugins/flow-architecture/tests/run-verify-docs-ecosystem-vslice.sh not found — skipped"
else
  if fda_ecosystem_out=$(bash "$fda_ecosystem_test" 2>&1); then
    fda_ecosystem_pass_count=$(printf '%s\n' "$fda_ecosystem_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture verify-docs ecosystem vslice (${fda_ecosystem_pass_count:-?} assertions)"
  else
    fail "flow-architecture verify-docs ecosystem vslice failed — run plugins/flow-architecture/tests/run-verify-docs-ecosystem-vslice.sh for details"
    printf '%s\n' "$fda_ecosystem_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b''' — flow-architecture built-criterion fixture vslice (BC-10730)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-built-criterion-fixture-vslice.sh —
# asserts the synthetic-built-criterion-drift fixture matches the
# operator-consumable BUILT criterion locked in flow-inventory-codebase-scan
# SKILL.md § 6.1 and flow-inventory-add SKILL.md § 7. Defends against
# rubric-content drift (catchphrase + structural-clause + negative-case greps)
# and against the API-present-no-UI fixture shape regressing.
section "2b'''. flow-architecture built-criterion fixture vslice (BC-10730)"

fda_built_test="$REPO_ROOT/plugins/flow-architecture/tests/run-built-criterion-fixture-vslice.sh"

if [ ! -f "$fda_built_test" ]; then
  warn "plugins/flow-architecture/tests/run-built-criterion-fixture-vslice.sh not found — skipped"
else
  if fda_built_out=$(bash "$fda_built_test" 2>&1); then
    fda_built_pass_count=$(printf '%s\n' "$fda_built_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture built-criterion fixture vslice (${fda_built_pass_count:-?} assertions)"
  else
    fail "flow-architecture built-criterion fixture vslice failed — run plugins/flow-architecture/tests/run-built-criterion-fixture-vslice.sh for details"
    printf '%s\n' "$fda_built_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b'''' — flow-architecture cross-domain-deps vslice (BC-10729)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-cross-domain-deps-vslice.sh —
# asserts the doc-side parse contract + bidirectional set-comparison logic
# for the Q29 amendment 2 `cross-domain-deps-bidirectional` cross-cutting
# gate against 3 synthetic fixtures (PASS / FAIL_DOC_ORPHAN /
# FAIL_LINEAR_ORPHAN). Filesystem-only; live Phase C Linear MCP check is
# exercised in Brand Hub dogfood per the BC-7059 vslice-greenfield precedent.
section "2b''''. flow-architecture cross-domain-deps vslice (BC-10729)"

fda_cross_deps_test="$REPO_ROOT/plugins/flow-architecture/tests/run-cross-domain-deps-vslice.sh"

if [ ! -f "$fda_cross_deps_test" ]; then
  warn "plugins/flow-architecture/tests/run-cross-domain-deps-vslice.sh not found — skipped"
else
  if fda_cross_deps_out=$(bash "$fda_cross_deps_test" 2>&1); then
    fda_cross_deps_pass_count=$(printf '%s\n' "$fda_cross_deps_out" | sed -n 's/.*: \([0-9]*\) pass.*/\1/p' | tail -1)
    pass "flow-architecture cross-domain-deps vslice (${fda_cross_deps_pass_count:-?} assertions)"
  else
    fail "flow-architecture cross-domain-deps vslice failed — run plugins/flow-architecture/tests/run-cross-domain-deps-vslice.sh for details"
    printf '%s\n' "$fda_cross_deps_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b''''' — flow-architecture orchestrator-recipe integration test (BC-11091)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-verify-docs-ecosystem-integration-vslice.sh —
# asserts the /flow:retrofit-project Phase 1 templates-scaffold recipe end-to-end
# against a fixture project: 9 files land + placeholders substituted + chmod +x
# on .sh files + idempotency-with-flag re-writes + idempotency-without-flag
# halts + verify-docs.sh --no-linear exits 0 on the substituted fixture.
# Sits ON TOP of Section 2b'' (template fidelity) — exercises the recipe-
# execution path which template-fidelity alone cannot catch. Pass count is
# auto-derived from the harness's RESULT contract line. The §7 verify-docs
# pipeline is gated on npm install of fixture devDependencies (tsx + gray-
# matter); a missing npm install path SKIPs rather than FAILs since §1-6
# already cover the recipe-regression surface.
section "2b'''''. flow-architecture orchestrator-recipe integration test (BC-11091)"

fda_recipe_test="$REPO_ROOT/plugins/flow-architecture/tests/run-verify-docs-ecosystem-integration-vslice.sh"

if [ ! -f "$fda_recipe_test" ]; then
  warn "plugins/flow-architecture/tests/run-verify-docs-ecosystem-integration-vslice.sh not found — skipped"
else
  if fda_recipe_out=$(bash "$fda_recipe_test" 2>&1); then
    fda_recipe_pass_count=$(printf '%s\n' "$fda_recipe_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture orchestrator-recipe integration test (${fda_recipe_pass_count:-?} assertions)"
  else
    fail "flow-architecture orchestrator-recipe integration test failed — run plugins/flow-architecture/tests/run-verify-docs-ecosystem-integration-vslice.sh for details"
    printf '%s\n' "$fda_recipe_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# Section 2b'''''' — flow-architecture deprecate-legacy contract tests (BC-10219)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/test-deprecate-legacy-contracts.sh —
# 57 assertions locking two-pass detection, pre-comms gate, sub-step ordering,
# AskUserQuestion gates, review doc schema, and Q59 cross-reference integration.
section "2b''''''. flow-architecture deprecate-legacy contract tests (BC-10219)"

fda_deprecate_test="$REPO_ROOT/plugins/flow-architecture/tests/test-deprecate-legacy-contracts.sh"

if [ ! -f "$fda_deprecate_test" ]; then
  warn "plugins/flow-architecture/tests/test-deprecate-legacy-contracts.sh not found — skipped"
else
  if fda_deprecate_out=$(bash "$fda_deprecate_test" 2>&1); then
    fda_deprecate_pass_count=$(printf '%s\n' "$fda_deprecate_out" | sed -n 's/^Results: \([0-9]*\) PASS.*/\1/p')
    pass "flow-architecture deprecate-legacy contract tests (${fda_deprecate_pass_count:-?} assertions)"
  else
    fail "flow-architecture deprecate-legacy contract tests failed — run plugins/flow-architecture/tests/test-deprecate-legacy-contracts.sh for details"
    printf '%s\n' "$fda_deprecate_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b''''''' — flow-architecture story-doc quality vslice (BC-11985)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-story-quality-vslice.sh — the
# regression lock for the story-doc-author quality rewrite (BC-11985/BC-11986).
# Greps fixture story docs and FAILS on any of four quality defects: (a) job-story
# When/I want to/so I can grammar collapse (verb-less "so I can <noun>" or
# "I want to a/the <noun>"), (b) circular boilerplate AC ("the outcome
# described in" / "holds true"), (c) fewer than 3 Gherkin Scenario blocks,
# (d) a generic project-wide default persona repeated verbatim (T0-2/A-2 seed).
# A GOOD BriteBase-grade fixture passes all four; each BAD fixture trips exactly
# its named defect. Pass count auto-derived from the harness's RESULT line.
section "2b'''''''. flow-architecture story-doc quality vslice (BC-11985)"

fda_story_quality_test="$REPO_ROOT/plugins/flow-architecture/tests/run-story-quality-vslice.sh"

if [ ! -f "$fda_story_quality_test" ]; then
  warn "plugins/flow-architecture/tests/run-story-quality-vslice.sh not found — skipped"
else
  if fda_story_quality_out=$(bash "$fda_story_quality_test" 2>&1); then
    fda_story_quality_pass_count=$(printf '%s\n' "$fda_story_quality_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture story-doc quality vslice (${fda_story_quality_pass_count:-?} assertions)"
  else
    fail "flow-architecture story-doc quality vslice failed — run plugins/flow-architecture/tests/run-story-quality-vslice.sh for details"
    printf '%s\n' "$fda_story_quality_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b'''''''' — flow-architecture WS-A reusable doc-lint vslice (BC-11983)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-flow-doc-lint-vslice.sh — the
# regression lock for the reusable, multi-line-aware story-doc lint lib
# (scripts/lib/flow_doc_lint.sh) used by WS-E remediation to lint any consumer
# repo's flows. Asserts lint_story_doc returns the right verdict on the shared
# synthetic-story-quality fixtures: GOOD (human job-story + constraint-spec +
# human-mentions-infra) → PASS; each BAD fixture → its named defect (A-1 GRAMMAR
# / A-3 BOILERPLATE / FEW_SCENARIOS / A-2 GENERIC_PERSONA / D11 FRAME_MISMATCH).
# Pass count auto-derived from the harness's RESULT line.
section "2b''''''''. flow-architecture WS-A doc-lint vslice (BC-11983)"

fda_doclint_test="$REPO_ROOT/plugins/flow-architecture/tests/run-flow-doc-lint-vslice.sh"

if [ ! -f "$fda_doclint_test" ]; then
  warn "plugins/flow-architecture/tests/run-flow-doc-lint-vslice.sh not found — skipped"
else
  if fda_doclint_out=$(bash "$fda_doclint_test" 2>&1); then
    fda_doclint_pass_count=$(printf '%s\n' "$fda_doclint_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture WS-A doc-lint vslice (${fda_doclint_pass_count:-?} assertions)"
  else
    fail "flow-architecture WS-A doc-lint vslice failed — run plugins/flow-architecture/tests/run-flow-doc-lint-vslice.sh for details"
    printf '%s\n' "$fda_doclint_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b''''''''' — flow-architecture WS-A inventory lints (BC-11983)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-flow-inventory-lint-vslice.sh — the
# regression lock for the inventory lints (scripts/lib/flow_inventory_lint.sh):
# A-8 inventory ↔ doc two-identifier consistency (orphan docs / orphan rows /
# UPPERCASE-vs-kebab scheme mix, handling both Q20-amendment-2 schemes) and A-9
# flow-ID immutability (a removed/renamed flow-ID is the FK-fragility breach;
# `-a`/`-b` splits and [DEPRECATED]-but-present IDs are allowed). Fixtures built
# in a temp dir. Pass count auto-derived from the harness's RESULT line.
section "2b'''''''''. flow-architecture WS-A inventory lints (BC-11983)"

fda_invlint_test="$REPO_ROOT/plugins/flow-architecture/tests/run-flow-inventory-lint-vslice.sh"

if [ ! -f "$fda_invlint_test" ]; then
  warn "plugins/flow-architecture/tests/run-flow-inventory-lint-vslice.sh not found — skipped"
else
  if fda_invlint_out=$(bash "$fda_invlint_test" 2>&1); then
    fda_invlint_pass_count=$(printf '%s\n' "$fda_invlint_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture WS-A inventory lints vslice (${fda_invlint_pass_count:-?} assertions)"
  else
    fail "flow-architecture WS-A inventory lints vslice failed — run plugins/flow-architecture/tests/run-flow-inventory-lint-vslice.sh for details"
    printf '%s\n' "$fda_invlint_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b'''''''''' — flow-architecture WS-A Linear-graph lints (BC-11983)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-flow-linear-lint-vslice.sh — the
# regression lock for the Linear-graph lints (scripts/lib/flow_linear_lint.py):
# A-4 label↔title-prefix contamination (a [Discipline] child carrying a
# contradictory type:* label, e.g. brite-supply's 33 [Design]→type:eng), A-5
# blockedBy-wiring (story-doc ## Cross-domain dependencies ↔ Linear blockedBy —
# reuses the BC-10729 bidirectional predicate), A-6 child-milestone-inheritance
# (NO_MILESTONE + child≠parent), and A-7 duplicate-discipline-child. Unlike the
# doc/inventory lints these consume a Linear-state JSON snapshot (synthetic
# fixtures here; live MCP→JSON at WS-E / /flow:audit Phase C per the fixtures
# README serialize contract). Pass count auto-derived from the harness's RESULT line.
section "2b''''''''''. flow-architecture WS-A Linear-graph lints (BC-11983)"

fda_lglint_test="$REPO_ROOT/plugins/flow-architecture/tests/run-flow-linear-lint-vslice.sh"

if [ ! -f "$fda_lglint_test" ]; then
  warn "plugins/flow-architecture/tests/run-flow-linear-lint-vslice.sh not found — skipped"
else
  if fda_lglint_out=$(bash "$fda_lglint_test" 2>&1); then
    fda_lglint_pass_count=$(printf '%s\n' "$fda_lglint_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture WS-A Linear-graph lints vslice (${fda_lglint_pass_count:-?} assertions)"
  else
    fail "flow-architecture WS-A Linear-graph lints vslice failed — run plugins/flow-architecture/tests/run-flow-linear-lint-vslice.sh for details"
    printf '%s\n' "$fda_lglint_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b''''''''''' — flow-architecture journey/story template alignment (BC-11983 WS-E precursor)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/flow-architecture/tests/run-template-alignment-vslice.sh — the
# regression lock that keeps the journey-doc-author / story-doc-author agents
# AND the canonical templates the plugin seeds into consumers
# (templates/docs/templates/{domain-journey,job-story}.md) from drifting away
# from the canonical handbook structure (the brite-sites teardown root cause:
# missing consumer template file + drifted agent fallback prose). Grep-triad
# per file (catchphrase + structural-clause + negative-case): restores Decision
# points / Open questions / Preconditions / QA history, forbids the domain-level
# duplicate sections, and asserts both orchestrators COPY the templates into the
# consumer's docs/templates/. Pass count auto-derived from the harness RESULT line.
section "2b'''''''''''. flow-architecture journey/story template alignment (BC-11983)"

fda_tmpl_align_test="$REPO_ROOT/plugins/flow-architecture/tests/run-template-alignment-vslice.sh"

if [ ! -f "$fda_tmpl_align_test" ]; then
  warn "plugins/flow-architecture/tests/run-template-alignment-vslice.sh not found — skipped"
else
  if fda_tmpl_align_out=$(bash "$fda_tmpl_align_test" 2>&1); then
    fda_tmpl_align_pass_count=$(printf '%s\n' "$fda_tmpl_align_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture journey/story template alignment vslice (${fda_tmpl_align_pass_count:-?} assertions)"
  else
    fail "flow-architecture journey/story template alignment vslice failed — run plugins/flow-architecture/tests/run-template-alignment-vslice.sh for details"
    printf '%s\n' "$fda_tmpl_align_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2b'''''''''''' — flow-architecture shift-left clone-drift regression (BC-12410)
# ══════════════════════════════════════════════════════════════════════
# Naming: the flow-architecture sub-sections chain off "2b" with one added
# prime-tick (apostrophe) per section in landing order — 2b' (BC-10728), 2b''
# (BC-11029), … through 2b''''''''''' (BC-11983). This is the 12th, so it carries
# 12 ticks. The count is positional, not a copy-paste artifact; a plain letter
# (e.g. 2b') would collide with an existing earlier section.
# Runs plugins/flow-architecture/tests/test-clone-drift-shiftleft.sh — the
# regression lock for check-clone-drift-shiftleft.sh, the path-filtered gate that
# surfaces the FDA-clone re-sync obligation ON the PR that edits a cloned upstream
# command (session-start / review / ship), vs the lagging origin/main
# clone-drift-check (BC-7060). Hermetic cases: list-agreement + upstream-edited-
# not-resynced → FAIL+obligation (per arm); re-synced → PASS; unrelated PR →
# no-run; FDA-clone-only edit → no-run; near-miss exact-match; cross-clone
# scoping. Mutates a clone header in place, restores via .bak + EXIT trap.
section "2b''''''''''''. flow-architecture shift-left clone-drift regression (BC-12410)"

fda_shiftleft_test="$REPO_ROOT/plugins/flow-architecture/tests/test-clone-drift-shiftleft.sh"

if [ ! -f "$fda_shiftleft_test" ]; then
  warn "plugins/flow-architecture/tests/test-clone-drift-shiftleft.sh not found — skipped"
else
  if fda_shiftleft_out=$(bash "$fda_shiftleft_test" 2>&1); then
    fda_shiftleft_pass_count=$(printf '%s\n' "$fda_shiftleft_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "flow-architecture shift-left clone-drift regression (${fda_shiftleft_pass_count:-?} assertions)"
  else
    fail "flow-architecture shift-left clone-drift regression failed — run plugins/flow-architecture/tests/test-clone-drift-shiftleft.sh for details"
    printf '%s\n' "$fda_shiftleft_out" | tail -30 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2c — Pre-commit Guardrail Regression (BC-8712 follow-up)
# ══════════════════════════════════════════════════════════════════════
# Runs scripts/test_pre_commit_bump.sh against scripts/pre-commit.sh in a
# throw-away git repo. Each scenario asserts the hook exits with the expected
# code AND produces the expected diagnostic substring. Scenarios I/J/K/O
# guard the P2 case-glob over-match caught on PR #317; L/M/N/P guard
# silent-bypasses surfaced by /workflows:review on PR #318. The pass count
# below is auto-derived from the harness's RESULT contract line — no
# hardcoded count to drift. (See memory/gotcha_bash_case_glob_crosses_slash.md.)
section "2c. Pre-commit Guardrail Regression"

precommit_test="$REPO_ROOT/scripts/test_pre_commit_bump.sh"
precommit_hook="$REPO_ROOT/scripts/pre-commit.sh"

if [ ! -f "$precommit_test" ]; then
  warn "scripts/test_pre_commit_bump.sh not found — pre-commit regression check skipped"
elif [ ! -f "$precommit_hook" ]; then
  warn "scripts/pre-commit.sh not found — pre-commit regression check skipped"
else
  # Capture into variable rather than mktemp — no tmpfile leak risk on interrupt
  # and avoids re-parsing the harness's human-readable PASS lines.
  if precommit_out=$(bash "$precommit_test" "$precommit_hook" 2>&1); then
    pass_count=$(printf '%s\n' "$precommit_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "pre-commit hook regression (${pass_count:-?} scenarios)"
  else
    fail "pre-commit hook regression failed — run scripts/test_pre_commit_bump.sh for details"
    printf '%s\n' "$precommit_out" | tail -25 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2c' — Pre-push Hook Bare-Root Regression (BC-11951)
# Runs scripts/test-pre-push-hook.sh against .githooks/pre-push in a hermetic
# sandbox. Asserts the hook skips cleanly from a bare-repo root (no worktree)
# instead of aborting the push, and still runs validate.sh from a worktree.
# ══════════════════════════════════════════════════════════════════════
section "2c'. Pre-push Hook Bare-Root Regression"

prepush_test="$REPO_ROOT/scripts/test-pre-push-hook.sh"
prepush_hook="$REPO_ROOT/.githooks/pre-push"

if [ ! -f "$prepush_test" ]; then
  warn "scripts/test-pre-push-hook.sh not found — pre-push regression check skipped"
elif [ ! -f "$prepush_hook" ]; then
  warn ".githooks/pre-push not found — pre-push regression check skipped"
else
  if prepush_out=$(bash "$prepush_test" "$prepush_hook" 2>&1); then
    pass "pre-push hook bare-root regression (test-pre-push-hook.sh)"
  else
    printf '%s\n' "$prepush_out" | sed 's/^/      /'
    fail "pre-push hook regression failed — run scripts/test-pre-push-hook.sh for details"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2d — Security Hook Regex Regression (BC-11889)
# ══════════════════════════════════════════════════════════════════════
# Thin regex-only smoke test for the surviving PreToolUse regex hooks.
# Replaces the BC-11117 classifier harness retired with its Haiku layer.
section "2d. Security Hook Regex Regression"

hooks_test="$REPO_ROOT/scripts/test-hooks.sh"

if [ ! -f "$hooks_test" ]; then
  warn "scripts/test-hooks.sh not found — hook regex regression check skipped"
else
  if hooks_out=$(bash "$hooks_test" 2>&1); then
    pass_count=$(printf '%s\n' "$hooks_out" | sed -n 's/^  Total: \([0-9]*\)  Passed: \([0-9]*\).*/\2\/\1/p' | tail -1)
    pass "security hook regex regression (${pass_count:-?} scenarios)"
  else
    fail "security hook regex regression failed — run scripts/test-hooks.sh for details"
    printf '%s\n' "$hooks_out" | tail -25 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2d' — Pre-commit Advisory Hook (BC-11890)
# ══════════════════════════════════════════════════════════════════════
# Hermetic execution test for the PreToolUse Bash quality hook after its
# block → warn demotion: must always emit {"ok":true} (never block) and
# surface failing-linter output on stderr behind an advisory banner.
section "2d'. Pre-commit Advisory Hook"

advisory_test="$REPO_ROOT/scripts/test_precommit_advisory.sh"

if [ ! -f "$advisory_test" ]; then
  warn "scripts/test_precommit_advisory.sh not found — advisory hook check skipped"
else
  if advisory_out=$(bash "$advisory_test" 2>&1); then
    pass_count=$(printf '%s\n' "$advisory_out" | sed -n 's/^  Total: \([0-9]*\)  Passed: \([0-9]*\).*/\2\/\1/p' | tail -1)
    pass "pre-commit advisory hook (${pass_count:-?} scenarios)"
  else
    fail "pre-commit advisory hook failed — run scripts/test_precommit_advisory.sh for details"
    printf '%s\n' "$advisory_out" | tail -25 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2e — workflows helper-script unit tests (BC-12248)
# ══════════════════════════════════════════════════════════════════════
# Runs plugins/workflows/tests/test-*.sh — bash unit tests for workflows
# helper scripts (currently greptile-verdict.sh, the greptile-gate score
# reader). Pass count auto-derived from each harness's RESULT contract line.
# Mirrors Section 2b' (the flow-architecture helper-test pattern); kept as a
# localized glob so future workflows bash harnesses are picked up automatically.
section "2e. workflows helper-script unit tests (BC-12248)"

wf_ran=0
for wf_test in "$REPO_ROOT"/plugins/workflows/tests/test-*.sh; do
  [ -e "$wf_test" ] || continue   # bash 3.2: glob stays literal when no match
  wf_ran=1
  wf_name="$(basename "$wf_test")"
  if wf_out=$(bash "$wf_test" 2>&1); then
    wf_pass_count=$(printf '%s\n' "$wf_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "workflows: $wf_name (${wf_pass_count:-?} assertions)"
  else
    fail "workflows: $wf_name failed — run $wf_test for details"
    printf '%s\n' "$wf_out" | tail -25 | sed 's/^/    /' >&2
  fi
done
[ "$wf_ran" -eq 1 ] || warn "no plugins/workflows/tests/test-*.sh found — skipped"

# ══════════════════════════════════════════════════════════════════════
# Discover plugins from marketplace.json
# ══════════════════════════════════════════════════════════════════════

plugin_dirs=()
if [ -f "$MARKETPLACE" ]; then
  while IFS= read -r src; do
    resolved=$(cd "$REPO_ROOT" && realpath "$src" 2>/dev/null || echo "$REPO_ROOT/$src")
    if [ -d "$resolved" ]; then
      plugin_dirs+=("$resolved")
    fi
  done < <(python3 -c "
import json
with open('$MARKETPLACE') as f:
    data = json.load(f)
for p in data.get('plugins', []):
    print(p.get('source', ''))
" 2>&1)
fi

if [ ${#plugin_dirs[@]} -eq 0 ]; then
  fail "No plugins discovered from marketplace.json"
  section "Summary"
  printf "  \033[31m%d error(s)\033[0m, %d warning(s)\n" "$errors" "$warnings"
  echo ""
  exit 1
fi

# ══════════════════════════════════════════════════════════════════════
# validate_plugin() — runs per-plugin validation (sections 3-14)
# ══════════════════════════════════════════════════════════════════════
validate_plugin() {
  local PLUGIN_ROOT="$1"
  local PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
  local HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
  local MCP_JSON="$PLUGIN_ROOT/.mcp.json"
  local plugin_name
  plugin_name="$(basename "$PLUGIN_ROOT")"

  printf "\n\033[1;36m── Plugin: %s ──\033[0m\n" "$plugin_name"

  # ── JSON Validity (plugin files) ──────────────────────────────────
  section "3. JSON Validity ($plugin_name)"

  for json_file in "$PLUGIN_JSON" "$HOOKS_JSON" "$MCP_JSON"; do
    label="plugins/$plugin_name/${json_file#"$PLUGIN_ROOT"/}"
    if [ ! -f "$json_file" ]; then
      # plugin.json is required, others are optional
      if [ "$json_file" = "$PLUGIN_JSON" ]; then
        fail "$label does not exist"
      else
        warn "$label not found (optional)"
      fi
      continue
    fi
    if python3 -m json.tool "$json_file" > /dev/null 2>&1; then
      pass "$label"
    else
      fail "$label is not valid JSON"
    fi
  done

  # ── plugin.json Fields ────────────────────────────────────────────
  section "4. plugin.json Fields ($plugin_name)"

  if [ -f "$PLUGIN_JSON" ]; then
    pj_result=$(python3 -c "
import json, sys

with open('$PLUGIN_JSON') as f:
    data = json.load(f)

errors = []

# Required fields
required = ['name', 'description', 'author']
missing = [k for k in required if k not in data]
if missing:
    errors.append(f'Missing required fields: {missing}')

# Author validation
author = data.get('author', {})
if not author.get('name'):
    errors.append('author.name is missing')

# CRITICAL: Claude Code validates plugin.json against a strict Zod schema.
# Unrecognized fields cause a hard validation failure that silently prevents
# the entire plugin from loading. This allowlist matches the actual schema.
allowed_fields = {
    'name', 'description', 'author', 'version',
    'homepage', 'repository', 'license', 'keywords',
    'commands', 'skills', 'mcpServers', 'userConfig'
}
unknown = set(data.keys()) - allowed_fields
if unknown:
    errors.append(f'Unrecognized fields will break plugin loading: {sorted(unknown)}')
    errors.append('agents/, hooks/, and .mcp.json are auto-discovered — do not declare in plugin.json')

# mcpServers must be an object, not a string path
mcp = data.get('mcpServers')
if isinstance(mcp, str):
    errors.append(f'mcpServers must be an inline object, not a file path (\"{mcp}\")')
    errors.append('.mcp.json is auto-discovered — either use inline object or remove the field')

if errors:
    for e in errors:
        print(f'ERROR:{e}')
else:
    print(f'OK:{data[\"name\"]}')
" 2>&1)

    while IFS= read -r line; do
      if [[ "$line" == OK:* ]]; then
        pass "plugin.json: ${line#OK:}"
      elif [[ "$line" == ERROR:* ]]; then
        fail "${line#ERROR:}"
      fi
    done <<< "$pj_result"
  fi

  # ── plugin.json Path References ───────────────────────────────────
  section "5. plugin.json Path References ($plugin_name)"

  if [ -f "$PLUGIN_JSON" ]; then
    path_output=$(python3 -c "
import json, os, sys

with open('$PLUGIN_JSON') as f:
    data = json.load(f)

# Only commands and skills are valid string-path references in plugin.json.
# agents/, hooks/, and .mcp.json are auto-discovered — not declared.
path_keys = ['commands', 'skills']
for key in path_keys:
    if key not in data:
        continue
    ref = data[key]
    if not isinstance(ref, str):
        continue
    resolved = os.path.normpath(os.path.join('$PLUGIN_ROOT', ref))
    exists = os.path.exists(resolved)
    print(f'{\"PASS\" if exists else \"FAIL\"}:{key} -> {ref} ({resolved})')
" 2>&1)

    # A plugin may legitimately declare neither commands nor skills (e.g. a
    # hooks+MCP-only plugin like brite-core), in which case path_output is
    # empty. Guard against the empty here-string yielding one blank iteration
    # (which would emit a spurious "  does not exist" FAIL).
    if [ -n "$path_output" ]; then
      while IFS= read -r line; do
        status="${line%%:*}"
        msg="${line#*:}"
        if [ "$status" = "PASS" ]; then
          pass "$msg"
        else
          fail "$msg does not exist"
        fi
      done <<< "$path_output"
    else
      pass "no commands/skills path references to validate"
    fi
  fi

  # ── Directory Existence ───────────────────────────────────────────
  section "6. Directory Existence ($plugin_name)"

  # commands/ and skills/ are expected if declared in plugin.json
  # agents/ and hooks/ are optional (auto-discovered)
  for dir in commands skills; do
    target="$PLUGIN_ROOT/$dir"
    if [ -d "$target" ]; then
      count=$(ls "$target" | wc -l | tr -d ' ')
      pass "$dir/ ($count entries)"
    else
      # Only fail if declared in plugin.json
      if [ -f "$PLUGIN_JSON" ] && python3 -c "
import json
with open('$PLUGIN_JSON') as f:
    data = json.load(f)
if '$dir' in data:
    exit(0)
exit(1)
" 2>/dev/null; then
        fail "$dir/ not found (declared in plugin.json)"
      else
        warn "$dir/ not found"
      fi
    fi
  done

  for dir in agents hooks; do
    target="$PLUGIN_ROOT/$dir"
    if [ -d "$target" ]; then
      count=$(ls "$target" | wc -l | tr -d ' ')
      pass "$dir/ ($count entries)"
    else
      warn "$dir/ not found (optional)"
    fi
  done

  # ── Command Frontmatter ───────────────────────────────────────────
  section "7. Command Frontmatter ($plugin_name)"

  local cmd_found=false
  for file in "$PLUGIN_ROOT"/commands/*.md; do
    [ -f "$file" ] || continue
    cmd_found=true
    base="$(basename "$file")"

    first_line=$(head -1 "$file")
    if [ "$first_line" != "---" ]; then
      fail "$base: missing YAML frontmatter"
      continue
    fi

    fm=$(frontmatter "$file")
    desc=$(yaml_val "$fm" "description")
    if [ -z "$desc" ]; then
      fail "$base: missing description in frontmatter"
    else
      pass "$base"
    fi
  done

  if [ "$cmd_found" = false ]; then
    warn "No commands found"
  fi

  # ── Skill Frontmatter ─────────────────────────────────────────────
  section "8. Skill Frontmatter ($plugin_name)"

  local skill_found=false
  for file in "$PLUGIN_ROOT"/skills/*/SKILL.md; do
    [ -f "$file" ] || continue
    dirname="$(basename "$(dirname "$file")")"

    # Skip _shared
    [ "$dirname" = "_shared" ] && continue
    skill_found=true

    first_line=$(head -1 "$file")
    if [ "$first_line" != "---" ]; then
      fail "$dirname/SKILL.md: missing YAML frontmatter"
      continue
    fi

    fm=$(frontmatter "$file")
    skill_ok=true

    # name
    name_val=$(yaml_val "$fm" "name")
    if [ -z "$name_val" ]; then
      fail "$dirname: missing 'name' field"
      skill_ok=false
    elif [ "$name_val" != "$dirname" ]; then
      fail "$dirname: name '$name_val' does not match directory"
      skill_ok=false
    fi

    # description — must exist and not be quoted
    desc_val=$(yaml_val "$fm" "description")
    if [ -z "$desc_val" ]; then
      fail "$dirname: missing 'description' field"
      skill_ok=false
    elif [[ "$desc_val" == \"* ]] || [[ "$desc_val" == \'* ]] || [[ "$desc_val" == ">"* ]]; then
      fail "$dirname: description must not be quoted"
      skill_ok=false
    fi

    # user-invocable — must be explicit true or false
    ui_val=$(yaml_val "$fm" "user-invocable")
    if [ -z "$ui_val" ]; then
      fail "$dirname: missing 'user-invocable' field"
      skill_ok=false
    elif [ "$ui_val" != "true" ] && [ "$ui_val" != "false" ]; then
      fail "$dirname: user-invocable must be 'true' or 'false', got '$ui_val'"
      skill_ok=false
    fi

    # allowed-tools — must be comma-separated string, not YAML array
    at_val=$(yaml_val "$fm" "allowed-tools")
    if [ -n "$at_val" ]; then
      # Check if next line after allowed-tools starts with "- " (YAML array)
      next_line=$(sed -n '/^allowed-tools:/{ n; p; }' "$file")
      if [[ "$next_line" =~ ^[[:space:]]*-[[:space:]] ]]; then
        fail "$dirname: allowed-tools must be comma-separated string, not YAML array"
        skill_ok=false
      else
        pass "$dirname: allowed-tools format ok"
      fi
    fi

    # argument-hint — must be top-level, not nested under metadata
    ah_in_meta=$(echo "$fm" | sed -n '/^metadata:/,/^[^ ]/p' | grep "argument-hint:" || true)
    ah_toplevel=$(echo "$fm" | grep "^argument-hint:" || true)
    if [ -n "$ah_in_meta" ]; then
      fail "$dirname: argument-hint must be top-level, not nested under metadata"
      skill_ok=false
    elif [ -n "$ah_toplevel" ]; then
      pass "$dirname: argument-hint is top-level"
    fi

    # agent reference — verify file exists
    agent_val=$(yaml_val "$fm" "agent")
    if [ -n "$agent_val" ]; then
      agent_file="$PLUGIN_ROOT/agents/$agent_val.md"
      if [ -f "$agent_file" ]; then
        pass "$dirname: agent '$agent_val' exists"
      else
        fail "$dirname: agent '$agent_val' references missing file agents/$agent_val.md"
        skill_ok=false
      fi
    fi

    # license — verify LICENSE file exists
    license_val=$(yaml_val "$fm" "license")
    if [ -n "$license_val" ]; then
      skill_dir="$(dirname "$file")"
      if [ -f "$skill_dir/LICENSE" ] || [ -f "$skill_dir/LICENSE.txt" ] || \
         [ -f "$PLUGIN_ROOT/LICENSE" ] || [ -f "$PLUGIN_ROOT/LICENSE.txt" ]; then
        pass "$dirname: LICENSE file found"
      else
        fail "$dirname: declares license '$license_val' but no LICENSE file in skill dir or plugin root"
        skill_ok=false
      fi
    fi

    if [ "$skill_ok" = true ]; then
      pass "$dirname"
    fi
  done

  if [ "$skill_found" = false ]; then
    warn "No skills found"
  fi

  # ── Agent Frontmatter ─────────────────────────────────────────────
  section "9. Agent Frontmatter ($plugin_name)"

  local agent_found=false
  for file in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$file" ] || continue
    agent_found=true
    base="$(basename "$file" .md)"

    first_line=$(head -1 "$file")
    if [ "$first_line" != "---" ]; then
      fail "$base: missing YAML frontmatter"
      continue
    fi

    fm=$(frontmatter "$file")
    agent_ok=true

    # name must match filename
    name_val=$(yaml_val "$fm" "name")
    if [ -z "$name_val" ]; then
      fail "$base: missing 'name' field"
      agent_ok=false
    elif [ "$name_val" != "$base" ]; then
      fail "$base: name '$name_val' does not match filename"
      agent_ok=false
    fi

    # description
    desc_val=$(yaml_val "$fm" "description")
    if [ -z "$desc_val" ]; then
      fail "$base: missing 'description' field"
      agent_ok=false
    fi

    # model
    model_val=$(yaml_val "$fm" "model")
    if [ -z "$model_val" ]; then
      fail "$base: missing 'model' field"
      agent_ok=false
    elif [ "$model_val" != "opus" ] && [ "$model_val" != "sonnet" ] && [ "$model_val" != "haiku" ]; then
      fail "$base: model must be opus/sonnet/haiku, got '$model_val'"
      agent_ok=false
    fi

    # tools — optional, but if present must be comma-separated string
    tools_val=$(yaml_val "$fm" "tools")
    if [ -n "$tools_val" ]; then
      next_line=$(sed -n '/^tools:/{ n; p; }' "$file")
      if [[ "$next_line" =~ ^[[:space:]]*-[[:space:]] ]]; then
        fail "$base: tools must be comma-separated string, not YAML array"
        agent_ok=false
      fi
    fi

    if [ "$agent_ok" = true ]; then
      pass "$base"
    fi
  done

  if [ "$agent_found" = false ]; then
    warn "No agents found (optional)"
  fi

  # ── Cross-References ──────────────────────────────────────────────
  section "10. Cross-References ($plugin_name)"

  # Collect all agent references from skills
  local -a referenced_agents=()
  for file in "$PLUGIN_ROOT"/skills/*/SKILL.md; do
    [ -f "$file" ] || continue
    dirname="$(basename "$(dirname "$file")")"
    [ "$dirname" = "_shared" ] && continue

    fm=$(frontmatter "$file")
    agent_val=$(yaml_val "$fm" "agent")
    if [ -n "$agent_val" ]; then
      referenced_agents+=("$agent_val")
      agent_file="$PLUGIN_ROOT/agents/$agent_val.md"
      if [ ! -f "$agent_file" ]; then
        fail "Skill '$dirname' references agent '$agent_val' — file missing"
      fi
    fi
  done

  # Also collect agent references from commands (agents dispatched via Agent tool)
  # Note: referenced_agents may contain duplicates (one entry per command×agent match).
  # The orphan check only needs existence, so deduplication is unnecessary.
  for file in "$PLUGIN_ROOT"/commands/*.md; do
    [ -f "$file" ] || continue
    for agent_file in "$PLUGIN_ROOT"/agents/*.md; do
      [ -f "$agent_file" ] || continue
      agent_name="$(basename "$agent_file" .md)"
      # Guard: skip agent names with regex metacharacters
      if [[ ! "$agent_name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9_-]*[a-zA-Z0-9])?$ ]]; then
        warn "Agent filename '$agent_name' contains unexpected characters — skipping reference scan"
        continue
      fi
      if grep -qE "(^|[^a-zA-Z0-9_-])${agent_name}([^a-zA-Z0-9_-]|$)" "$file" 2>/dev/null; then
        referenced_agents+=("$agent_name")
      fi
    done
  done

  # Check for orphan agents
  for file in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$file" ] || continue
    base="$(basename "$file" .md)"
    found=false
    for ref in "${referenced_agents[@]+"${referenced_agents[@]}"}"; do
      if [ "$ref" = "$base" ]; then
        found=true
        break
      fi
    done
    if [ "$found" = true ]; then
      pass "Agent '$base' is referenced by a skill or command"
    else
      warn "Agent '$base' is not referenced by any skill or command (orphan)"
    fi
  done

  # plugin.json name matches marketplace entry
  if [ -f "$MARKETPLACE" ] && [ -f "$PLUGIN_JSON" ]; then
    match_result=$(python3 -c "
import json
with open('$MARKETPLACE') as f:
    mp = json.load(f)
with open('$PLUGIN_JSON') as f:
    pj = json.load(f)
pj_name = pj.get('name', '')
mp_names = [p.get('name', '') for p in mp.get('plugins', [])]
if pj_name in mp_names:
    print(f'PASS:plugin.json name \"{pj_name}\" found in marketplace')
else:
    print(f'FAIL:plugin.json name \"{pj_name}\" not found in marketplace plugins ({mp_names})')
" 2>&1)
    status="${match_result%%:*}"
    msg="${match_result#*:}"
    if [ "$status" = "PASS" ]; then
      pass "$msg"
    else
      fail "$msg"
    fi
  fi

  # ── Hooks Structure ──────────────────────────────────────────────
  section "11. Hooks Structure ($plugin_name)"

  if [ -f "$HOOKS_JSON" ]; then
    hooks_result=$(python3 "$REPO_ROOT/scripts/_lib/lint_hooks.py" "$HOOKS_JSON" 2>&1)

    while IFS= read -r line; do
      if [[ "$line" == OK:* ]]; then
        pass "${line#OK:}"
      elif [[ "$line" == ERROR:* ]]; then
        fail "${line#ERROR:}"
      fi
    done <<< "$hooks_result"
  else
    warn "hooks.json not found (optional)"
  fi

  # ── Step Sequence Validation ──────────────────────────────────────
  section "12. Step Sequence Validation ($plugin_name)"

  local step_seq_errors=0
  local step_seq_checked=0
  local dirname_check display_name numeric_ok file_ok current_seq prev dupes found_ref
  local -a all_steps seq_list

  for file in "$PLUGIN_ROOT"/commands/*.md "$PLUGIN_ROOT"/skills/*/SKILL.md; do
    [ -f "$file" ] || continue

    # Skip _shared
    dirname_check="$(basename "$(dirname "$file")")"
    [ "$dirname_check" = "_shared" ] && continue

    # Display name — validate character class to prevent escape sequence injection
    if [[ "$file" == */skills/*/SKILL.md ]]; then
      if [[ ! "$dirname_check" =~ ^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$ ]]; then
        warn "Skipping '$dirname_check' — unexpected characters in directory name"
        continue
      fi
      display_name="$dirname_check/SKILL.md"
    else
      display_name="$(basename "$file")"
    fi

    # Extract integer step numbers from ##/###/#### Step N headers
    # Sub-steps like "Step 2b" are excluded: the number must NOT be followed by a letter
    all_steps=()
    while IFS= read -r num; do
      [ -n "$num" ] && all_steps+=("$num")
    done < <(grep -E '^#{2,4} Step [0-9]+([^0-9a-zA-Z]|$)' "$file" 2>/dev/null | sed -n 's/^#\{2,4\} Step \([0-9][0-9]*\).*/\1/p')

    # Skip files with fewer than 2 steps (nothing to sequence-validate)
    [ ${#all_steps[@]} -lt 2 ] && continue

    # Guard: verify all extracted values are numeric (defense-in-depth for arithmetic)
    numeric_ok=true
    for num in "${all_steps[@]}"; do
      case "$num" in
        *[!0-9]*) numeric_ok=false; break ;;
      esac
    done
    if [ "$numeric_ok" = false ]; then
      warn "$display_name: non-numeric step value extracted — skipping"
      continue
    fi

    file_ok=true

    # Split into contiguous sequences (new sequence when step number drops)
    # Semicolon delimiter is safe because all_steps values are digit-only (guarded above)
    seq_list=()
    current_seq="${all_steps[0]}"
    prev="${all_steps[0]}"

    for ((i = 1; i < ${#all_steps[@]}; i++)); do
      if [ "${all_steps[$i]}" -lt "$prev" ]; then
        # Sequence reset detected — save current, start new
        seq_list+=("$current_seq")
        current_seq="${all_steps[$i]}"
      else
        current_seq="$current_seq;${all_steps[$i]}"
      fi
      prev="${all_steps[$i]}"
    done
    seq_list+=("$current_seq")

    # Validate each sequence: start value, gaps, and duplicates
    for seq in "${seq_list[@]}"; do
      IFS=';' read -ra steps <<< "$seq"

      # Sequences should start at 0 or 1 — anything else suggests misordering
      if [ "${steps[0]}" -gt 1 ]; then
        fail "$display_name: sequence starts at Step ${steps[0]} (expected 0 or 1)"
        file_ok=false
        step_seq_errors=$((step_seq_errors + 1))
      fi

      # Check gaps (each step should be previous + 1)
      for ((j = 1; j < ${#steps[@]}; j++)); do
        expected=$(( steps[j-1] + 1 ))
        if [ "${steps[$j]}" -ne "$expected" ]; then
          fail "$display_name: gap — Step ${steps[$((j-1))]} to Step ${steps[$j]} (expected Step $expected)"
          file_ok=false
          step_seq_errors=$((step_seq_errors + 1))
        fi
      done

      # Check duplicates
      dupes=$(printf '%s\n' "${steps[@]}" | sort -n | uniq -d)
      if [ -n "$dupes" ]; then
        while IFS= read -r d; do
          [ -z "$d" ] && continue
          fail "$display_name: duplicate Step $d"
          file_ok=false
          step_seq_errors=$((step_seq_errors + 1))
        done <<< "$dupes"
      fi
    done

    # Validate skip/jump references point to existing step headers
    while IFS= read -r ref_line; do
      # Extract only target step numbers from "to Step N" — not incidental mentions
      while IFS= read -r ref_num; do
        [ -n "$ref_num" ] || continue
        found_ref=false
        for s in "${all_steps[@]}"; do
          if [ "$s" = "$ref_num" ]; then
            found_ref=true
            break
          fi
        done
        if [ "$found_ref" = false ]; then
          fail "$display_name: references 'Step $ref_num' but no such step header exists"
          file_ok=false
          step_seq_errors=$((step_seq_errors + 1))
        fi
      done < <(grep -oiE 'to Step [0-9]+' <<< "$ref_line" | grep -oE '[0-9]+')
    done < <(grep -iE '(skip|proceed|go|continue|jump|return|fall.?back|advance).*to Step [0-9]+' "$file" 2>/dev/null || true)

    step_seq_checked=$((step_seq_checked + 1))
    if [ "$file_ok" = true ]; then
      pass "$display_name"
    fi
  done

  if [ "$step_seq_checked" -eq 0 ]; then
    warn "No files with step sequences found"
  fi

  # ── Cadence Gate-Respect (BC-5866) ──────────────────────────────
  # TODO(BC-5866): generalize when a 2nd plugin opts in — detect any
  #   $PLUGIN_ROOT/skills/_shared/gate-respect.md and run the linter on it,
  #   replacing the plugin_name hardcode. Rename lint_cadence_gates.py →
  #   lint_gate_respect.py at the same time. See docs/precedents/BC-5866.md.
  if [ "$plugin_name" = "cadence" ]; then
    section "12.5 Cadence Gate-Respect ($plugin_name)"

    gate_result=$(python3 "$REPO_ROOT/scripts/_lib/lint_cadence_gates.py" "$PLUGIN_ROOT" 2>&1)

    while IFS= read -r line; do
      if [[ "$line" == OK:* ]]; then
        pass "${line#OK:}"
      elif [[ "$line" == ERROR:* ]]; then
        fail "${line#ERROR:}"
      fi
    done <<< "$gate_result"
  fi

  # ── Trait Definition Validation ────────────────────────────────
  section "13b. Trait Definition Validation ($plugin_name)"

  local project_start_md="$PLUGIN_ROOT/commands/project-start.md"
  local trait_templates_md="$PLUGIN_ROOT/commands/_shared/trait-doc-templates.md"

  if [ ! -f "$project_start_md" ]; then
    pass "project-start.md not found — trait validation skipped"
  else
    trait_result=$(PROJECT_START="$project_start_md" TRAIT_TEMPLATES="$trait_templates_md" python3 << 'PYEOF'
import os, re

project_start = os.environ["PROJECT_START"]
trait_templates = os.environ["TRAIT_TEMPLATES"]

CANONICAL = {
    "produces-code", "produces-documents", "involves-data", "requires-decisions",
    "has-external-users", "client-facing", "needs-design", "needs-marketing",
    "needs-sales", "cross-team", "automation",
}

errors = []

with open(project_start) as f:
    ps_lines = f.read().splitlines()

def extract_table_traits(lines, section_marker):
    """Find the first markdown table after a line starting with section_marker,
    then extract backtick-wrapped names from the first column."""
    traits = set()
    in_section = False
    in_table = False
    for line in lines:
        if line.strip().startswith(section_marker):
            in_section = True
            continue
        if in_section:
            if not in_table and line.startswith('|') and '---' in line:
                in_table = True
                continue
            if in_table:
                if not line.startswith('|'):
                    break
                m = re.match(r'\|\s*`([^`]+)`', line)
                if m:
                    traits.add(m.group(1))
    return traits

def check_traits(found, label):
    """Validate found traits against CANONICAL set. Appends errors or prints OK."""
    if not found:
        errors.append(f'{label}: no traits found (section missing or table unparseable)')
        return
    missing = CANONICAL - found
    extra = found - CANONICAL
    for t in sorted(missing):
        errors.append(f'{label}: missing trait "{t}"')
    for t in sorted(extra):
        errors.append(f'{label}: unknown trait "{t}"')
    if not missing and not extra:
        print(f"OK:{label} — {len(found)} traits match")

check_traits(extract_table_traits(ps_lines, "## Trait Definitions"), "Trait definition table")
check_traits(extract_table_traits(ps_lines, "### Trait-to-Documentation Mapping"), "Trait-to-doc mapping")
check_traits(extract_table_traits(ps_lines, "**Trait-conditional**"), "Post-setup verification table")

if not os.path.isfile(trait_templates):
    errors.append("trait-doc-templates.md not found")
else:
    with open(trait_templates) as f:
        tmpl_content = f.read()
    tmpl_traits = set(re.findall(r'^## `([^`]+)`', tmpl_content, re.MULTILINE))
    check_traits(tmpl_traits, "trait-doc-templates.md")

for e in errors:
    print(f"ERROR:{e}")
PYEOF
)

    while IFS= read -r line; do
      if [[ "$line" == OK:* ]]; then
        pass "${line#OK:}"
      elif [[ "$line" == ERROR:* ]]; then
        fail "${line#ERROR:}"
      fi
    done <<< "$trait_result"
  fi

  # ── Trigger Registry Validation ──────────────────────────────────
  section "13. Trigger Registry ($plugin_name)"

  local trigger_registry="$PLUGIN_ROOT/skills/_shared/trigger-registry.json"
  if [ ! -f "$trigger_registry" ]; then
    warn "trigger-registry.json not found (optional)"
  else
    if ! python3 -m json.tool "$trigger_registry" > /dev/null 2>&1; then
      fail "trigger-registry.json is not valid JSON"
    else
      pass "trigger-registry.json valid JSON"

      tr_result=$(TRIGGER_REGISTRY="$trigger_registry" PLUGIN_ROOT_VAR="$PLUGIN_ROOT" python3 << 'PYEOF'
import json, os, re

registry_path = os.environ["TRIGGER_REGISTRY"]
plugin_root = os.environ["PLUGIN_ROOT_VAR"]

with open(registry_path) as f:
    registry = json.load(f)

errors = []
skills_data = registry.get('skills', [])
precedence = registry.get('precedence', [])
test_cases = registry.get('test_cases', [])
registry_names = {s['name'] for s in skills_data}

# Tier allowlist
valid_tiers = {'inner-loop', 'design', 'backend-quality', 'post-plan', 'utility'}

# Safe directory name pattern (matches Section 13 guard)
safe_name_re = re.compile(r'^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$')

# 1. Collect actual skill directories (excluding _shared)
skills_dir = os.path.join(plugin_root, 'skills')
actual_dirs = set()
if os.path.isdir(skills_dir):
    for d in os.listdir(skills_dir):
        if d == '_shared':
            continue
        if os.path.isdir(os.path.join(skills_dir, d)):
            actual_dirs.add(d)

# 2. Every skill directory has a registry entry
for d in sorted(actual_dirs - registry_names):
    if safe_name_re.match(d):
        errors.append(f'Skill directory "{d}" has no registry entry')
    else:
        errors.append('Skill directory (name contains unsafe chars) has no registry entry')

# 3. Every registry entry has a skill directory
for n in sorted(registry_names - actual_dirs):
    errors.append(f'Registry entry "{n}" has no skill directory')

# 4. Required fields per entry + tier allowlist
for s in skills_data:
    name = s.get('name', '<unnamed>')
    for field in ['name', 'tier', 'user_invocable', 'keywords']:
        if field not in s:
            errors.append(f'{name}: missing required field "{field}"')
    kw = s.get('keywords', [])
    if isinstance(kw, list) and len(kw) == 0:
        errors.append(f'{name}: keywords must be non-empty')
    t = s.get('tier', '')
    if t and t not in valid_tiers:
        errors.append(f'{name}: unknown tier "{t}" (expected one of {sorted(valid_tiers)})')

# 5. beats entries reference existing skill names
for s in skills_data:
    for b in s.get('beats', []):
        if b not in registry_names:
            errors.append(f'{s["name"]}: beats references unknown skill "{b}"')

# 6. precedence entries reference existing skill names
for p in precedence:
    for role in ['winner', 'loser']:
        val = p.get(role, '')
        if val not in registry_names:
            errors.append(f'precedence: {role} "{val}" is not a registered skill')

# 7. Minimum test case count
if len(test_cases) < 30:
    errors.append(f'test_cases has {len(test_cases)} entries (minimum 30)')

# 8. Each test case has required fields + skill name validation
for i, tc in enumerate(test_cases):
    for field in ['phrase', 'expected', 'description']:
        if field not in tc:
            errors.append(f'test_cases[{i}]: missing "{field}"')
    for role in ['expected', 'not_expected']:
        for name in tc.get(role, []):
            if name not in registry_names:
                errors.append(f'test_cases[{i}].{role}: "{name}" is not a registered skill')

# 9. user_invocable matches SKILL.md frontmatter
for s in skills_data:
    name = s.get('name', '')
    skill_md = os.path.join(skills_dir, name, 'SKILL.md')
    if not os.path.isfile(skill_md):
        continue
    with open(skill_md) as f:
        lines = f.readlines()
    # Extract frontmatter
    if not lines or lines[0].strip() != '---':
        continue
    fm_lines = []
    for line in lines[1:]:
        if line.strip() == '---':
            break
        fm_lines.append(line)
    # Find user-invocable value
    ui_val = None
    for line in fm_lines:
        m = re.match(r'^user-invocable:\s*(.+)', line)
        if m:
            ui_val = m.group(1).strip()
            break
    if ui_val is not None:
        expected_bool = ui_val == 'true'
        registry_bool = s.get('user_invocable')
        if registry_bool != expected_bool:
            errors.append(f'{name}: user_invocable={registry_bool} but SKILL.md has user-invocable: {ui_val}')

for e in errors:
    print(f'ERROR:{e}')
if not errors:
    print(f'OK:registry ({len(skills_data)} skills, {len(precedence)} precedence rules, {len(test_cases)} test cases)')
PYEOF
)

      while IFS= read -r line; do
        if [[ "$line" == OK:* ]]; then
          pass "${line#OK:}"
        elif [[ "$line" == ERROR:* ]]; then
          fail "${line#ERROR:}"
        fi
      done <<< "$tr_result"
    fi
  fi

  # ══════════════════════════════════════════════════════════════════════
  # Section 14 — Template Freshness ($plugin_name)
  # ══════════════════════════════════════════════════════════════════════
  local tmpl_files=()
  for tf in "$PLUGIN_ROOT"/skills/*/SKILL.md.tmpl; do
    [ -f "$tf" ] && tmpl_files+=("$tf")
  done

  if [ "${#tmpl_files[@]}" -gt 0 ]; then
    section "14. Template Freshness ($plugin_name)"
    # Fast path: single invocation checks all templates at once
    if python3 "$REPO_ROOT/scripts/gen-skill-docs.py" --check > /dev/null 2>&1; then
      pass "All ${#tmpl_files[@]} template(s) fresh"
    else
      # Slow path: per-skill detail to identify which failed and why
      local tmpl_stale=0
      for tmpl_file in "${tmpl_files[@]}"; do
        local skill_dir skill_name tmpl_output
        skill_dir="$(dirname "$tmpl_file")"
        skill_name="$(basename "$skill_dir")"
        if tmpl_output=$(python3 "$REPO_ROOT/scripts/gen-skill-docs.py" --check --skill "$skill_name" 2>&1); then
          pass "$skill_name/SKILL.md is fresh"
        else
          fail "$skill_name/SKILL.md needs regeneration (run: bash scripts/gen-skill-docs.sh)"
          # Show generator output for debugging (template errors, stale diffs)
          echo "$tmpl_output" | head -5 | sed 's/^/    /' >&2
          tmpl_stale=$((tmpl_stale + 1))
        fi
      done
      fail "${#tmpl_files[@]} template(s) checked, $tmpl_stale stale"
    fi
  fi

  # ── Plugin Summary ───────────────────────────────────────────────
  local cmd_count=0
  for f in "$PLUGIN_ROOT"/commands/*.md; do [ -f "$f" ] && cmd_count=$((cmd_count + 1)); done

  local skill_count=0
  for f in "$PLUGIN_ROOT"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    d="$(basename "$(dirname "$f")")"
    [ "$d" = "_shared" ] && continue
    skill_count=$((skill_count + 1))
  done

  local agent_count=0
  for f in "$PLUGIN_ROOT"/agents/*.md; do [ -f "$f" ] && agent_count=$((agent_count + 1)); done

  printf "\n  \033[1m%s\033[0m — Commands: %d, Skills: %d, Agents: %d\n" "$plugin_name" "$cmd_count" "$skill_count" "$agent_count"
}

# ══════════════════════════════════════════════════════════════════════
# Run validation for each plugin
# ══════════════════════════════════════════════════════════════════════

for plugin_dir in "${plugin_dirs[@]}"; do
  validate_plugin "$plugin_dir"
done

# ══════════════════════════════════════════════════════════════════════
# Section 15 — Quality Guardrails
# ══════════════════════════════════════════════════════════════════════
section "Quality Guardrails"

guardrail_script="$REPO_ROOT/scripts/check-guardrails.sh"
if [[ -x "$guardrail_script" ]] && [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
  guardrail_output=$("$guardrail_script" --claude-md "$REPO_ROOT/CLAUDE.md" 2>&1) || true
  if echo "$guardrail_output" | grep -q "FAIL"; then
    warn "CLAUDE.md guardrail check reported violations (run scripts/check-guardrails.sh --claude-md CLAUDE.md for details)"
  elif echo "$guardrail_output" | grep -q "WARN"; then
    warn "CLAUDE.md approaching size limit (run scripts/check-guardrails.sh --claude-md CLAUDE.md for details)"
  else
    pass "CLAUDE.md guardrail check clean"
  fi
else
  pass "Quality guardrails (skipped — no check-guardrails.sh or CLAUDE.md)"
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a — GTM Canonicals Lint (BC-8718 / ADR-016)
# ──────────────────────────────────────────────────────────────────────
# TODO: generalize when a 2nd plugin adopts the canonicals pattern —
# detect any plugins/*/data/canonicals/ and run the linter on each
# (matches Section 13 TODO at line 813).
# ══════════════════════════════════════════════════════════════════════
section "GTM Canonicals Lint"

canonicals_lint="$REPO_ROOT/plugins/marketing/scripts/lint_canonicals.py"
canonicals_dir="$REPO_ROOT/plugins/marketing/data/canonicals"
canonicals_tests="$REPO_ROOT/scripts/test_lint_canonicals.sh"
# python3 presence is enforced at the top of validate.sh (line 19-22) — the
# script exits 2 if it's missing — so a python3-availability check here would
# be unreachable.
if [ ! -f "$canonicals_lint" ]; then
  warn "lint_canonicals.py not found — canonicals lint skipped"
elif [ ! -d "$canonicals_dir" ]; then
  warn "canonicals dir not found — canonicals lint skipped"
else
  if canonicals_output=$(python3 "$canonicals_lint" --canonicals-dir "$canonicals_dir" 2>&1); then
    # Success output is single-line by contract ("Canonicals lint OK — N
    # verticals validated."). Emit as a single pass message.
    pass "$canonicals_output"
  else
    fail "Canonicals lint failed:"
    while IFS= read -r line; do
      [ -n "$line" ] && printf "          %s\n" "$line"
    done <<< "$canonicals_output"
  fi

  if [ -f "$canonicals_tests" ]; then
    if tests_output=$(bash "$canonicals_tests" "$canonicals_lint" 2>&1); then
      # Parse the harness's machine-readable RESULT line so the count stays
      # in sync as scenarios are added/removed (matches Section 2c pattern).
      tests_pass_count=$(printf '%s\n' "$tests_output" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
      if [ -n "$tests_pass_count" ]; then
        pass "lint_canonicals regression harness — $tests_pass_count scenarios"
      else
        pass "lint_canonicals regression harness — passed (count unparsed)"
      fi
    else
      fail "Canonicals lint regression harness failed:"
      while IFS= read -r line; do
        [ -n "$line" ] && printf "          %s\n" "$line"
      done <<< "$tests_output"
    fi
  else
    warn "test_lint_canonicals.sh not found — regression harness skipped"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-discoveries — GTM Discoveries Lint (BC-8722)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/marketing/scripts/lint_discoveries.py against the empty-OK
# campaigns tree + the regression harness against an isolated tmpdir per
# scenario. The lint is empty-tolerant by contract — BC-8722 is the first
# ship that introduces the schema; per-campaign-run artifacts arrive later.
#
# TODO: when a 2nd consumer of discoveries.json emerges, generalize this
# section alongside the Section 15a canonicals TODO (line 1167).
# ══════════════════════════════════════════════════════════════════════
section "GTM Discoveries Lint"

discoveries_lint="$REPO_ROOT/plugins/marketing/scripts/lint_discoveries.py"
campaigns_dir="$REPO_ROOT/docs/campaigns"
discoveries_tests="$REPO_ROOT/scripts/test_lint_discoveries.sh"

if [ ! -f "$discoveries_lint" ]; then
  warn "lint_discoveries.py not found — discoveries lint skipped"
else
  if discoveries_output=$(python3 "$discoveries_lint" --campaigns-dir "$campaigns_dir" 2>&1); then
    # Success output is single-line by contract (either "Discoveries lint OK
    # — N file(s) validated." or "Discoveries lint OK — no discoveries.json
    # files found ...").
    pass "$discoveries_output"
  else
    fail "Discoveries lint failed:"
    while IFS= read -r line; do
      [ -n "$line" ] && printf "          %s\n" "$line"
    done <<< "$discoveries_output"
  fi

  if [ -f "$discoveries_tests" ]; then
    if disc_tests_output=$(bash "$discoveries_tests" "$discoveries_lint" 2>&1); then
      # Parse the harness's machine-readable RESULT line so the count stays
      # in sync as scenarios are added/removed (matches Section 2c + 15a).
      disc_tests_pass=$(printf '%s\n' "$disc_tests_output" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
      if [ -n "$disc_tests_pass" ]; then
        pass "lint_discoveries regression harness — $disc_tests_pass scenarios"
      else
        pass "lint_discoveries regression harness — passed (count unparsed)"
      fi
    else
      fail "Discoveries lint regression harness failed:"
      while IFS= read -r line; do
        [ -n "$line" ] && printf "          %s\n" "$line"
      done <<< "$disc_tests_output"
    fi
  else
    warn "test_lint_discoveries.sh not found — regression harness skipped"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-8726 — icp-refinement-review helper harness (BC-8726)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/marketing/scripts/test_icp_refinement_review.sh against an
# isolated tmpdir per scenario. Covers scan / apply / emit-handbook against
# the discoveries.json schema BC-8722 ships. No live-lint step here — the
# slash command's runtime contract is end-to-end driven through the test
# harness, and the mutated files would re-pass Section 15a-discoveries on
# the next validate.sh anyway.
# ══════════════════════════════════════════════════════════════════════
section "ICP Refinement Review Helper"

icp_helper="$REPO_ROOT/plugins/marketing/scripts/icp_refinement_review.py"
icp_tests="$REPO_ROOT/plugins/marketing/scripts/test_icp_refinement_review.sh"

if [ ! -f "$icp_helper" ]; then
  warn "icp_refinement_review.py not found — harness skipped"
elif [ ! -f "$icp_tests" ]; then
  warn "test_icp_refinement_review.sh not found — harness skipped"
else
  if icp_tests_output=$(bash "$icp_tests" "$icp_helper" 2>&1); then
    icp_tests_pass=$(printf '%s\n' "$icp_tests_output" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$icp_tests_pass" ]; then
      pass "icp_refinement_review regression harness — $icp_tests_pass scenarios"
    else
      pass "icp_refinement_review regression harness — passed (count unparsed)"
    fi
  else
    fail "icp_refinement_review regression harness failed:"
    while IFS= read -r line; do
      [ -n "$line" ] && printf "          %s\n" "$line"
    done <<< "$icp_tests_output"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-8719 — Entity-slug short-form lint (BC-8719 / O15)
# ──────────────────────────────────────────────────────────────────────
# Per BC-8719, the canonical campaign filesystem layout is short-form
# (docs/campaigns/{entity}/), not long-form (docs/campaigns/brite-{entity}/).
# This lint fails on any reintroduced hardcoded long-form path under
# plugins/marketing/skills/ and plugins/marketing/commands/, EXCEPT inside
# backward-compat shims explicitly tagged with "BC-8719", "legacy", or
# "backward-compat" on the same line. The exception window closes one
# release cycle after BC-8719 — when removed, this lint becomes
# unconditional.
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-8719. Entity-slug short-form lint (BC-8719)"

# Run grep from REPO_ROOT with relative paths so output omits the absolute
# prefix — that keeps the worktree dirname (e.g. "bc-8719-entity-slug") from
# false-matching the "BC-8719" exception marker. Two-stage filter:
#   (1) case-SENSITIVE match on "BC-8719" — the issue-key marker is uppercase
#       in prose ("BC-8719") and lowercase in worktree paths ("bc-8719-..."),
#       so case-sensitive matching disambiguates.
#   (2) case-INSENSITIVE match on the keyword markers ("legacy",
#       "backward-?compat", "read-compat") — these can appear in prose as
#       "Legacy", "backward-compat", "Backward-Compat", etc., and none of the
#       lowercase forms collide with any path segment in this repo.
# "backward-?compat" matches both "backward-compat" and "backwardcompat".
# "BC-8719" as a substring also matches "Pre-BC-8719".
bc8719_paths=()
for p in "plugins/marketing/skills" "plugins/marketing/commands"; do
  [ -d "$REPO_ROOT/$p" ] && bc8719_paths+=("$p")
done

if [ "${#bc8719_paths[@]}" -eq 0 ]; then
  warn "marketing skills/commands directories not found — BC-8719 lint skipped"
else
  bc8719_hits=$(cd "$REPO_ROOT" && grep -rnE 'docs/campaigns/brite-(nites|supply|labs)' "${bc8719_paths[@]}" 2>/dev/null | grep -vE 'BC-8719' | grep -viE '(legacy|backward-?compat|read-compat)' || true)
  if [ -z "$bc8719_hits" ]; then
    pass "no hardcoded long-form docs/campaigns/brite-{entity}/ paths outside backward-compat shims"
  else
    fail "hardcoded long-form docs/campaigns/brite-{entity}/ path(s) outside backward-compat shims (BC-8719):"
    while IFS= read -r line; do
      [ -n "$line" ] && printf "          %s\n" "$line"
    done <<< "$bc8719_hits"
    printf "          %s\n" "Fix: switch to short-form docs/campaigns/{entity}/ or annotate the line with one of: BC-8719, legacy, backward-compat, read-compat."
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-8731 — Portfolio snapshot helper regression harness (BC-8731)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/marketing/scripts/test_portfolio_snapshot.sh — bash unit
# tests for the portfolio_snapshot.py section composer + static-grep checks
# on plugins/marketing/commands/portfolio-snapshot.md for the V3 outcome
# anti-creep guard clauses (--weekly / --custom-window / --forecast /
# --charts rejection, V3 cite, campaign-analysis §3.3 cite). The harness's
# RESULT contract line drives the pass count (matches Sections 2b' / 2b'' /
# 2b''' / 2c / 15a-discoveries).
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-8731. Portfolio snapshot regression harness (BC-8731)"

ps_harness="$REPO_ROOT/plugins/marketing/scripts/test_portfolio_snapshot.sh"
ps_helper="$REPO_ROOT/plugins/marketing/scripts/portfolio_snapshot.py"

if [ ! -f "$ps_helper" ]; then
  warn "plugins/marketing/scripts/portfolio_snapshot.py not found — portfolio snapshot harness skipped"
elif [ ! -f "$ps_harness" ]; then
  warn "plugins/marketing/scripts/test_portfolio_snapshot.sh not found — portfolio snapshot harness skipped"
else
  if ps_harness_out=$(bash "$ps_harness" "$ps_helper" 2>&1); then
    ps_pass_count=$(printf '%s\n' "$ps_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$ps_pass_count" ]; then
      pass "portfolio-snapshot regression harness (${ps_pass_count} assertions)"
    else
      pass "portfolio-snapshot regression harness — passed (count unparsed)"
    fi
  else
    fail "portfolio-snapshot regression harness failed:"
    printf '%s\n' "$ps_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12587 — plan-campaign deterministic builder harness (BC-12587)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/marketing/scripts/test_build_manifest.sh — the unit/contract
# suite for build_manifest.py, the deterministic builder /marketing:plan-campaign
# delegates to in both its normal and emit runs (ADR-028 D8 emit-mode seam). It
# invokes the builder against the REAL canonicals + sub-issue-template files into
# a temp out-dir and asserts the slug/dates/labels/issue-set/blockedBy structure,
# the HARD-FAIL validation (canonicality/regex/labs-gate), determinism, and the
# purity guard. RESULT contract line drives the count (matches 15a-bc-8731 etc.).
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12587. plan-campaign builder regression harness (BC-12587)"

bm_harness="$REPO_ROOT/plugins/marketing/scripts/test_build_manifest.sh"
bm_helper="$REPO_ROOT/plugins/marketing/scripts/build_manifest.py"

if [ ! -f "$bm_helper" ]; then
  warn "plugins/marketing/scripts/build_manifest.py not found — builder harness skipped"
elif [ ! -f "$bm_harness" ]; then
  warn "plugins/marketing/scripts/test_build_manifest.sh not found — builder harness skipped"
else
  if bm_harness_out=$(bash "$bm_harness" "$bm_helper" 2>&1); then
    bm_pass_count=$(printf '%s\n' "$bm_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$bm_pass_count" ]; then
      pass "plan-campaign builder regression harness (${bm_pass_count} assertions)"
    else
      pass "plan-campaign builder regression harness — passed (count unparsed)"
    fi
  else
    fail "plan-campaign builder regression harness failed:"
    printf '%s\n' "$bm_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12589 — Behavioral-eval harness + first plan-campaign eval (BC-12589)
# ──────────────────────────────────────────────────────────────────────
# Runs scripts/eval/test_eval_harness.sh — the reusable behavioral-eval spine
# (M3 assert_lib + M2 run_eval) "test the tester" (ADR-028 § 5 / DP2-7). It runs
# the M3 assertion-lib unit cases, the first plan-campaign behavioral eval GREEN
# (build_manifest.py emit → schema + golden + key-field asserts, DP2-4/6), the M2
# mutation self-test (mutated artifact → red + named diff), and a hermeticity
# guard (no network module; runs with API keys unset). A red eval fails the build.
# RESULT contract line drives the count (matches §15a-bc-12587 / §2e).
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12589. behavioral-eval harness + plan-campaign eval (BC-12589)"

eval_harness="$REPO_ROOT/scripts/eval/test_eval_harness.sh"

if [ ! -f "$eval_harness" ]; then
  # HARD fail, not warn: this is the mandatory ADR-028 behavioral-eval gate. A
  # `warn` here would let a future accidental delete/rename of the harness pass CI
  # green — silently removing the gate ("a check nobody is forced to run rots").
  fail "scripts/eval/test_eval_harness.sh not found — the mandatory ADR-028 behavioral-eval gate is missing"
else
  if eval_harness_out=$(bash "$eval_harness" 2>&1); then
    eval_pass_count=$(printf '%s\n' "$eval_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$eval_pass_count" ]; then
      pass "behavioral-eval harness + plan-campaign eval (${eval_pass_count} assertions)"
    else
      pass "behavioral-eval harness — passed (count unparsed)"
    fi
  else
    fail "behavioral-eval harness failed:"
    printf '%s\n' "$eval_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12588 — Skill/command structural lint (BC-12588, ADR-028 Phase-1)
# ──────────────────────────────────────────────────────────────────────
# Two parts, mirroring the canonicals §15a (live lint + regression harness):
#   1. The self-test harness (scripts/eval/test_structural_lint.sh) is a MANDATORY
#      gate — FAIL if missing or red, so the lint can't silently vanish (the
#      §15a-bc-12589 "a check nobody is forced to run rots" lesson).
#   2. The live lint over the whole spec surface is ADVISORY this slice (DP2-10):
#      every finding is surfaced WARN-only — NOTHING fails the build here. The
#      `gate`-severity findings are a TIER LABEL ("[gate-tier · advisory this
#      slice]"), destined to flip to build-failing in BC-12590/M5, which consumes
#      this lint's findings[] (the M5 contract). A non-zero exit from the lint
#      itself is "the check couldn't run" → FAIL (distinct from "found issues").
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12588. skill/command structural lint (BC-12588, ADR-028)"

structural_lint="$REPO_ROOT/scripts/eval/structural_lint.py"
structural_lint_test="$REPO_ROOT/scripts/eval/test_structural_lint.sh"

if [ ! -f "$structural_lint_test" ]; then
  # HARD fail, not warn: the mandatory ADR-028 structural-lint self-test. A `warn`
  # would let an accidental delete/rename pass CI green — silently removing the gate.
  fail "scripts/eval/test_structural_lint.sh not found — the mandatory ADR-028 structural-lint self-test is missing"
elif [ ! -f "$structural_lint" ]; then
  fail "scripts/eval/structural_lint.py not found — the ADR-028 structural lint is missing"
else
  # Part 1 — self-test harness (RESULT contract line drives the count).
  if sl_test_out=$(bash "$structural_lint_test" 2>&1); then
    sl_pass_count=$(printf '%s\n' "$sl_test_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    pass "structural-lint self-test (${sl_pass_count:-?} assertions)"
  else
    fail "structural-lint self-test failed — run scripts/eval/test_structural_lint.sh for details"
    printf '%s\n' "$sl_test_out" | tail -30 | sed 's/^/          /' >&2
  fi

  # Part 2 — live lint over the repo surface, WARN-only (findings never fail here).
  if sl_out=$(python3 "$structural_lint" --scan-repo 2>&1); then
    sl_summary=$(printf '%s\n' "$sl_out" | sed -n 's/^SUMMARY //p' | tail -1)
    sl_total=$(printf '%s' "$sl_summary" | sed -n 's/.*findings=\([0-9][0-9]*\).*/\1/p')
    if [ "${sl_total:-0}" -eq 0 ]; then
      pass "structural lint: no findings across the spec surface"
    else
      warn "structural lint — advisory this slice (findings do NOT fail the build; gate-tier flips to blocking in BC-12590/M5): $sl_summary"
      # Surface each finding as its own (indented) line under the banner; the
      # warnings counter stays at +1 so the debt surface can't drown other sections.
      # `|| true`: under `set -euo pipefail` a grep that filters everything exits 1
      # — guard so this advisory section can never abort the build (it must not fail).
      printf '%s\n' "$sl_out" | grep -v '^SUMMARY ' | sed 's/^/          /' || true
    fi
  else
    fail "structural lint could not run (scan-repo exited non-zero) — run: python3 scripts/eval/structural_lint.py --scan-repo"
    printf '%s\n' "$sl_out" | tail -20 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12590 — M5 forward-only eval gate (BC-12590, ADR-028 Phase-1)
# ──────────────────────────────────────────────────────────────────────
# The flip-to-blocking capstone. Two parts are wired HERE; the LIVE diff-gate is
# deliberately NOT one of them — it runs in a dedicated pull_request CI job at
# fetch-depth: 0 (.github/workflows/validate-plugin.yml § eval-gate). The
# `validate` job is a shallow checkout where origin/main is not a resolvable diff
# base, so a diff-gate embedded here would silently no-op (a gate that doesn't
# gate). What runs here is diff-free and therefore meaningful in any checkout:
#   1. The self-test harness (scripts/eval/test_eval_gate.sh) is a MANDATORY gate
#      — FAIL if missing or red, so the gate can't silently vanish (the
#      §15a-bc-12589 "a check nobody is forced to run rots" lesson).
#   2. The debt-list integrity lint (`eval_gate.py --check`) is BLOCKING: it
#      enforces debt ∩ ADAPTERS == ∅ and debt ∪ ADAPTERS == the full command
#      surface (no net-new command merges un-recorded; no stale row for a deleted
#      command). This is what makes grandfathering + `# eval-waiver` explicit,
#      finite, and never silent.
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12590. M5 forward-only eval gate (BC-12590, ADR-028)"

eval_gate="$REPO_ROOT/scripts/eval/eval_gate.py"
eval_gate_test="$REPO_ROOT/scripts/eval/test_eval_gate.sh"

# Part 1 and Part 2 are gated INDEPENDENTLY (each on its own prerequisite) so a
# missing/renamed self-test can't also silently disable the --check integrity lint
# — the recursive form of the §15a-bc-12589 "a check nobody is forced to run rots"
# lesson (Greptile review, PR #453). Both are mandatory; a missing file FAILs.

# Part 1 — self-test harness (RESULT contract line drives the count).
if [ ! -f "$eval_gate_test" ]; then
  fail "scripts/eval/test_eval_gate.sh not found — the mandatory ADR-028 M5 eval-gate self-test is missing"
elif [ ! -f "$eval_gate" ]; then
  fail "scripts/eval/eval_gate.py not found — the ADR-028 M5 eval-gate self-test cannot run"
else
  if eg_test_out=$(bash "$eval_gate_test" 2>&1); then
    eg_pass_count=$(printf '%s\n' "$eg_test_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    pass "eval-gate self-test (${eg_pass_count:-?} assertions)"
  else
    fail "eval-gate self-test failed — run scripts/eval/test_eval_gate.sh for details"
    printf '%s\n' "$eg_test_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# Part 2 — debt-list integrity lint, BLOCKING (diff-free → shallow-checkout-safe).
# Conditioned ONLY on eval_gate.py (not the self-test), so it keeps enforcing the
# debt-list invariants even if the self-test file is ever removed/renamed.
# exit 0 = invariants hold; 1 = a broken invariant; 2 = could-not-run — both FAIL.
if [ ! -f "$eval_gate" ]; then
  fail "scripts/eval/eval_gate.py not found — the ADR-028 M5 debt-list integrity lint cannot run"
elif eg_check_out=$(python3 "$eval_gate" --check 2>&1); then
  pass "debt-list integrity (eval_gate --check): debt ∩ ADAPTERS == ∅, debt ∪ ADAPTERS == surface"
else
  fail "debt-list integrity lint failed — docs/skill-eval-debt.md out of sync with the command surface / ADAPTERS (run: python3 scripts/eval/eval_gate.py --check)"
  printf '%s\n' "$eg_check_out" | grep '^  PROBLEM' | sed 's/^/          /' >&2 || true
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-8728 — Shared utilities + offer-performance harnesses (BC-8728)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/marketing/scripts/test_shared_utilities.sh (canonicals_reader,
# slug_parts, manifest_loader) AND test_offer_performance.sh (8-scenario
# regression harness). Rule-of-Three extraction + new command surface.
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-8728. Shared utilities regression harness (BC-8728)"

su_harness="$REPO_ROOT/plugins/marketing/scripts/test_shared_utilities.sh"

if [ ! -f "$su_harness" ]; then
  warn "plugins/marketing/scripts/test_shared_utilities.sh not found — shared utilities harness skipped"
else
  if su_harness_out=$(bash "$su_harness" 2>&1); then
    su_pass_count=$(printf '%s\n' "$su_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$su_pass_count" ]; then
      pass "shared utilities regression harness (${su_pass_count} assertions)"
    else
      pass "shared utilities regression harness — passed (count unparsed)"
    fi
  else
    fail "shared utilities regression harness failed:"
    printf '%s\n' "$su_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

section "15a-bc-8728b. Offer-performance regression harness (BC-8728)"

op_harness="$REPO_ROOT/plugins/marketing/scripts/test_offer_performance.sh"
op_helper="$REPO_ROOT/plugins/marketing/scripts/offer_performance.py"

if [ ! -f "$op_helper" ]; then
  warn "plugins/marketing/scripts/offer_performance.py not found — offer-performance harness skipped"
elif [ ! -f "$op_harness" ]; then
  warn "plugins/marketing/scripts/test_offer_performance.sh not found — offer-performance harness skipped"
else
  if op_harness_out=$(bash "$op_harness" "$op_helper" 2>&1); then
    op_pass_count=$(printf '%s\n' "$op_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$op_pass_count" ]; then
      pass "offer-performance regression harness (${op_pass_count} assertions)"
    else
      pass "offer-performance regression harness — passed (count unparsed)"
    fi
  else
    fail "offer-performance regression harness failed:"
    printf '%s\n' "$op_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# Section 15a-bc-8725 — Canonicals bootstrap harness (BC-8725)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/marketing/scripts/test_canonicals_bootstrap.sh (vertical,
# offer, persona subcommands against tempdir fixtures).
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-8725. Canonicals bootstrap regression harness (BC-8725)"

cb_harness="$REPO_ROOT/plugins/marketing/scripts/test_canonicals_bootstrap.sh"
cb_helper="$REPO_ROOT/plugins/marketing/scripts/canonicals_bootstrap.py"

if [ ! -f "$cb_helper" ]; then
  warn "plugins/marketing/scripts/canonicals_bootstrap.py not found — bootstrap harness skipped"
elif [ ! -f "$cb_harness" ]; then
  warn "plugins/marketing/scripts/test_canonicals_bootstrap.sh not found — bootstrap harness skipped"
else
  if cb_harness_out=$(bash "$cb_harness" "$cb_helper" 2>&1); then
    cb_pass_count=$(printf '%s\n' "$cb_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$cb_pass_count" ]; then
      pass "canonicals bootstrap regression harness (${cb_pass_count} assertions)"
    else
      pass "canonicals bootstrap regression harness — passed (count unparsed)"
    fi
  else
    fail "canonicals bootstrap regression harness failed:"
    printf '%s\n' "$cb_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-11849 — Import-campaign regression harness (BC-11849)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/marketing/scripts/test_import_campaign.sh — exercises the
# import_campaign.py classify-name + compose surfaces (ADR-020 worked
# examples + cohort-1 reproduction + structural-error rejection) AND
# static-grep checks against import-campaign.md for spec-drift defense.
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-11849. Import-campaign regression harness (BC-11849)"

ic_harness="$REPO_ROOT/plugins/marketing/scripts/test_import_campaign.sh"
ic_helper="$REPO_ROOT/plugins/marketing/scripts/import_campaign.py"

if [ ! -f "$ic_helper" ]; then
  warn "plugins/marketing/scripts/import_campaign.py not found — import-campaign harness skipped"
elif [ ! -f "$ic_harness" ]; then
  warn "plugins/marketing/scripts/test_import_campaign.sh not found — import-campaign harness skipped"
else
  if ic_harness_out=$(bash "$ic_harness" "$ic_helper" 2>&1); then
    ic_pass_count=$(printf '%s\n' "$ic_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$ic_pass_count" ]; then
      pass "import-campaign regression harness (${ic_pass_count} assertions)"
    else
      pass "import-campaign regression harness — passed (count unparsed)"
    fi
  else
    fail "import-campaign regression harness failed:"
    printf '%s\n' "$ic_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12639 — revops --target-org guard behavioral eval (BC-12639)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/revops/scripts/test_validate_target_org.sh — the BEHAVIORAL eval
# for validate_target_org.py, the deterministic side-effect-free `--target-org`
# shape validator the σ3 SF-write commands delegate their Phase 0 guard to
# (ADR-028 emit-mode seam; first SECURITY worked example of the behavioral-eval
# tier). Unlike BC-12623's structural markdown-grep ordering proxy, this harness
# EXECUTES the validator against real injection payloads ($(touch pwned), backtick,
# x'; DROP, metacharacters) in an isolated tmpdir and asserts both rejection AND
# no side effect (the `pwned` sentinel is never created) — proving the guard
# actually stops command substitution, not merely that it is positioned first.
# RESULT contract line drives the count (matches 15a-bc-11849 etc.).
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12639. revops --target-org guard behavioral eval (BC-12639)"

vto_harness="$REPO_ROOT/plugins/revops/scripts/test_validate_target_org.sh"
vto_helper="$REPO_ROOT/plugins/revops/scripts/validate_target_org.py"

if [ ! -f "$vto_helper" ]; then
  warn "plugins/revops/scripts/validate_target_org.py not found — target-org guard behavioral eval skipped"
elif [ ! -f "$vto_harness" ]; then
  warn "plugins/revops/scripts/test_validate_target_org.sh not found — target-org guard behavioral eval skipped"
else
  if vto_harness_out=$(bash "$vto_harness" "$vto_helper" 2>&1); then
    vto_pass_count=$(printf '%s\n' "$vto_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$vto_pass_count" ]; then
      pass "revops --target-org guard behavioral eval (${vto_pass_count} assertions)"
    else
      pass "revops --target-org guard behavioral eval — passed (count unparsed)"
    fi
  else
    fail "revops --target-org guard behavioral eval failed:"
    printf '%s\n' "$vto_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12701 — create-sf-campaign builder unit suite (BC-12701)
# ──────────────────────────────────────────────────────────────────────
# Runs plugins/revops/scripts/test_build_campaign_payload.sh — the unit/contract
# suite for build_campaign_payload.py, the deterministic decision core
# /revops:create-sf-campaign delegates to in BOTH its normal and emit runs (the
# single shared entrypoint — ADR-028 eval #2, the side-effecting representative).
# It drives the builder across every verdict branch (would_create /
# would_skip_duplicate / missing_owner / invalid_*), proves the --target-org
# shell-injection guard REJECTS `$(touch pwned)` with NO side effect (the builder
# only ever regex-matches the value — it never reaches a shell), and locks the
# SLUG_RE/EMAIL_RE byte-identity parity. FAIL-if-missing (not warn): the builder is
# mandatory — both the command and the behavioral eval depend on it, so a future
# delete must fail loudly (the §15a-bc-12589 lesson). RESULT line drives the count.
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12701. create-sf-campaign builder unit suite (BC-12701)"

csf_helper="$REPO_ROOT/plugins/revops/scripts/build_campaign_payload.py"
csf_harness="$REPO_ROOT/plugins/revops/scripts/test_build_campaign_payload.sh"

if [ ! -f "$csf_helper" ]; then
  fail "plugins/revops/scripts/build_campaign_payload.py not found — the create-sf-campaign emit-mode builder is missing"
elif [ ! -f "$csf_harness" ]; then
  fail "plugins/revops/scripts/test_build_campaign_payload.sh not found — the create-sf-campaign builder suite is missing"
else
  if csf_harness_out=$(bash "$csf_harness" "$csf_helper" 2>&1); then
    csf_pass_count=$(printf '%s\n' "$csf_harness_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    if [ -n "$csf_pass_count" ]; then
      pass "create-sf-campaign builder unit suite (${csf_pass_count} assertions)"
    else
      pass "create-sf-campaign builder unit suite — passed (count unparsed)"
    fi
  else
    fail "create-sf-campaign builder unit suite failed:"
    printf '%s\n' "$csf_harness_out" | tail -30 | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12638 — --target-org guard-precedes-sink consolidating lint (BC-12638)
# ──────────────────────────────────────────────────────────────────────
# Repo-wide CONSOLIDATING lint: every command interpolating a non-literal
# `--target-org` into an executable `sf` shell-out (across BOTH plugins) must
# carry a `<!-- guard:target-org -->` marker BEFORE its earliest sink + the
# byte-identical canonical regex. SUBSUMES BC-12623's two bespoke per-file σ3
# ordering tests and fires on any FUTURE non-literal passthrough — the systematic
# answer to the guard-after-sink whack-a-mole. First the self-test (fixtures lock
# the lint's own logic), then the lint run against the real command tree.
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12638. --target-org guard-precedes-sink consolidating lint (BC-12638)"

tog_lint="$REPO_ROOT/scripts/_lib/lint_target_org_guard.py"
tog_selftest="$REPO_ROOT/scripts/_lib/test_lint_target_org_guard.sh"

if [ ! -f "$tog_lint" ]; then
  warn "scripts/_lib/lint_target_org_guard.py not found — target-org guard lint skipped"
else
  # (1) self-test — fixtures prove the lint's literal/marker/ordering/exempt/
  #     byte-identity logic (mutation-locked).
  if [ -f "$tog_selftest" ]; then
    if tog_st_out=$(bash "$tog_selftest" "$tog_lint" 2>&1); then
      tog_st_count=$(printf '%s\n' "$tog_st_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
      pass "target-org guard lint self-test (${tog_st_count:-?} assertions)"
    else
      fail "target-org guard lint self-test failed:"
      printf '%s\n' "$tog_st_out" | tail -30 | sed 's/^/          /' >&2
    fi
  else
    warn "scripts/_lib/test_lint_target_org_guard.sh not found — lint self-test skipped"
  fi
  # (2) the gate — run the lint against the real plugins/*/commands/*.md tree.
  if tog_lint_out=$(python3 "$tog_lint" 2>&1); then
    pass "target-org guard-precedes-sink lint (real tree clean)"
  else
    fail "target-org guard-precedes-sink lint found violations:"
    printf '%s\n' "$tog_lint_out" | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12640 — audit-invariant error-key roster drift-guard (BC-12640)
# ──────────────────────────────────────────────────────────────────────
# Machine-checks that each σ3 command's ADR-015 error-key roster stays in three-way
# lock-step with that command's inline `{"error":"…"}` emits AND its error-catalog
# table (per command, bidirectional set-equality). The sibling to §15a-bc-12638's
# guard-precedes-sink lint — would have auto-caught the BC-12594 → BC-12623 "6 keys
# → 7" prose drift. First the self-test (synthetic fixtures lock the lint's parse +
# warning-exclusion + first-span + standalone-marker logic), then the lint against
# the real ADR-015 + σ3 command tree. Missing files FAIL (not warn-skip): a
# mandatory gate that silently passes when its harness is deleted is the BC-12589
# trap — distinguish "check couldn't RUN" (fail) from "check found issues" (fail).
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12640. audit-invariant roster drift-guard (BC-12640)"

ard_lint="$REPO_ROOT/scripts/_lib/lint_audit_roster_drift.py"
ard_selftest="$REPO_ROOT/scripts/_lib/test_lint_audit_roster_drift.sh"

if [ ! -f "$ard_lint" ]; then
  fail "scripts/_lib/lint_audit_roster_drift.py not found — roster drift-guard cannot run (BC-12640)"
elif [ ! -f "$ard_selftest" ]; then
  fail "scripts/_lib/test_lint_audit_roster_drift.sh not found — roster drift-guard self-test cannot run (BC-12640)"
else
  # (1) self-test — synthetic fixtures prove the lint's parse / equality / filter /
  #     marker logic (mutation-locked).
  if ard_st_out=$(bash "$ard_selftest" "$ard_lint" 2>&1); then
    ard_st_count=$(printf '%s\n' "$ard_st_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    pass "roster drift-guard self-test (${ard_st_count:-?} assertions)"
  else
    fail "roster drift-guard self-test failed:"
    printf '%s\n' "$ard_st_out" | tail -30 | sed 's/^/          /' >&2
  fi
  # (2) the gate — run the lint against the real ADR-015 + σ3 command tree.
  if ard_lint_out=$(python3 "$ard_lint" 2>&1); then
    pass "audit-invariant roster drift-guard (ADR ↔ emits ↔ table in sync)"
  else
    fail "audit-invariant roster drift-guard found drift:"
    printf '%s\n' "$ard_lint_out" | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15a-bc-12617 — ADR-number duplicate guard (BC-12617)
# ──────────────────────────────────────────────────────────────────────
# ADRs live at docs/decisions/NNN-slug.md, numbered by reading "next free number"
# off a stale `main`; concurrent branches grab the SAME NNN with DIFFERENT slugs,
# so git never flags it (filenames differ) and the 2nd merge SILENTLY creates a
# duplicate-numbered ADR (happened 4× in one week). This guard groups the files by
# their NORMALIZED leading integer (so 021 == 21) and fails on any number used by
# >1 file. DUPLICATE-detection only — gaps (004-006 absent, 001 Withdrawn) are
# legitimate and never flagged. First the self-test (synthetic fixtures lock the
# parse / int-normalize / file-selection / rc-discipline logic), then the lint
# against the real docs/decisions/ tree. Missing files FAIL (not warn-skip): a
# mandatory gate that silently passes when its harness is deleted is the BC-12589
# trap — distinguish "check couldn't RUN" (fail) from "check found issues" (fail).
# ══════════════════════════════════════════════════════════════════════
section "15a-bc-12617. ADR-number duplicate guard (BC-12617)"

adr_num_lint="$REPO_ROOT/scripts/_lib/lint_adr_numbers.py"
adr_num_selftest="$REPO_ROOT/scripts/_lib/test_lint_adr_numbers.sh"

if [ ! -f "$adr_num_lint" ]; then
  fail "scripts/_lib/lint_adr_numbers.py not found — ADR-number guard cannot run (BC-12617)"
elif [ ! -f "$adr_num_selftest" ]; then
  fail "scripts/_lib/test_lint_adr_numbers.sh not found — ADR-number guard self-test cannot run (BC-12617)"
else
  # (1) self-test — synthetic fixtures prove the parse / int-normalize / file-
  #     selection / rc-discipline logic (mutation-locked).
  if adr_num_st_out=$(bash "$adr_num_selftest" "$adr_num_lint" 2>&1); then
    adr_num_st_count=$(printf '%s\n' "$adr_num_st_out" | sed -n 's/^RESULT pass=\([0-9][0-9]*\) fail=.*/\1/p' | tail -1)
    pass "ADR-number guard self-test (${adr_num_st_count:-?} assertions)"
  else
    fail "ADR-number guard self-test failed:"
    printf '%s\n' "$adr_num_st_out" | tail -30 | sed 's/^/          /' >&2
  fi
  # (2) the gate — run the lint against the real docs/decisions/ tree.
  if adr_num_lint_out=$(python3 "$adr_num_lint" 2>&1); then
    pass "ADR-number duplicate guard (no duplicate ADR numbers)"
  else
    fail "ADR-number duplicate guard found duplicates:"
    printf '%s\n' "$adr_num_lint_out" | sed 's/^/          /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15b — Plugin install-status (cross-check with claude CLI)
# ══════════════════════════════════════════════════════════════════════
section "Plugin install-status (marketplace.json vs 'claude plugin list')"

if ! command -v claude &>/dev/null; then
  warn "claude CLI not found — install-status check skipped"
else
  claude_plugin_list="$(claude plugin list 2>/dev/null || true)"
  if [ -z "$claude_plugin_list" ]; then
    warn "'claude plugin list' returned no output — install-status check skipped"
  else
    marketplace_name="$(MARKETPLACE_PATH="$MARKETPLACE" python3 <<'PY' 2>/dev/null
import json, os, sys
path = os.environ.get("MARKETPLACE_PATH", "")
try:
    with open(path) as f:
        d = json.load(f)
    print(d.get("name", ""))
except Exception:
    sys.exit(0)
PY
)"

    if [ -z "$marketplace_name" ]; then
      warn "could not resolve marketplace name from $MARKETPLACE — install-status check skipped"
    else
      plugins_tsv="$(MARKETPLACE_PATH="$MARKETPLACE" python3 <<'PY' 2>/dev/null
import json, os, sys
path = os.environ.get("MARKETPLACE_PATH", "")
try:
    with open(path) as f:
        d = json.load(f)
    for p in d.get("plugins", []):
        name = p.get("name", "")
        version = p.get("version", "")
        print(name + "\t" + version)
except Exception:
    sys.exit(0)
PY
)"

      while IFS=$'\t' read -r pname pver; do
        [ -z "$pname" ] && continue
        if printf '%s\n' "$claude_plugin_list" | grep -qE "[[:space:]]${pname}@${marketplace_name}([[:space:]]|$)"; then
          pass "$pname@${marketplace_name} (v$pver) installed"
        else
          warn "$pname (v$pver) is in marketplace.json but NOT installed — run 'claude plugin install ${pname}@${marketplace_name}'"
        fi
      done <<< "$plugins_tsv"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 15z — Agent-skills config drift (BC-11934)
# ══════════════════════════════════════════════════════════════════════
# WARN when docs/agents/ config and the CLAUDE.md '## Agent skills' block
# drift out of sync. Advisory only (never errors) — mirrors check-guardrails.sh
# C2. Logic + unit tests live in scripts/_lib/agent_skills_drift.sh and
# scripts/test_agent_skills_drift.sh (run via test_* harness convention).
section "Agent-skills config drift"
# shellcheck source=/dev/null
. "$REPO_ROOT/scripts/_lib/agent_skills_drift.sh"
_drift_found=0
while IFS= read -r _msg; do
  warn "$_msg"
  _drift_found=1
done < <(detect_agent_skills_drift "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/docs/agents")
[ "$_drift_found" -eq 0 ] && pass "agent-skills config and CLAUDE.md block are in sync"

# Run the drift-detector's fixture unit tests (mirrors Section 2b' pattern).
# Pass count auto-derived from the harness's RESULT contract line.
section "Agent-skills drift unit tests"
drift_test="$REPO_ROOT/scripts/test_agent_skills_drift.sh"
if [ ! -f "$drift_test" ]; then
  warn "scripts/test_agent_skills_drift.sh not found — skipped"
else
  if drift_test_out=$(bash "$drift_test" 2>&1); then
    drift_pass_count=$(printf '%s\n' "$drift_test_out" | sed -n 's/^RESULT pass=\([0-9]*\).*/\1/p')
    pass "agent-skills drift unit tests (${drift_pass_count:-?} assertions)"
  else
    fail "agent-skills drift unit tests failed — run scripts/test_agent_skills_drift.sh for details"
    printf '%s\n' "$drift_test_out" | tail -25 | sed 's/^/    /' >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Section 16 — Summary
# ══════════════════════════════════════════════════════════════════════
section "Summary"

echo "  Plugins validated: ${#plugin_dirs[@]}"
echo ""

if [ "$errors" -gt 0 ]; then
  printf "  \033[31m%d error(s)\033[0m, %d warning(s)\n" "$errors" "$warnings"
  echo ""
  exit 1
else
  if [ "$warnings" -gt 0 ]; then
    printf "  \033[32m0 errors\033[0m, \033[33m%d warning(s)\033[0m\n" "$warnings"
  else
    printf "  \033[32mAll checks passed\033[0m\n"
  fi
  echo ""
  exit 0
fi
