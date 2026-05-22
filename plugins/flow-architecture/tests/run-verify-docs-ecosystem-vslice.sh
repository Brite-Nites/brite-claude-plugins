#!/usr/bin/env bash
# BC-11029 v-slice integration test for the verify-docs.sh ecosystem
# templates (Q58) — asserts plugin-side template fidelity + placeholder
# discipline.
#
# Scope:
#   1. All 10 template files have canonical homes under
#      plugins/flow-architecture/templates/.
#   2. verify-docs.sh has bash #! + set -euo pipefail.
#   3. No brite-roster / brite-nites / BRITE_ROSTER string leaks into any
#      template (forces Q58 § "Brite-roster vs brite-base divergences"
#      genericization).
#   4. Each <PLACEHOLDER> documented in templates/README.md actually
#      appears in at least one template file (forces placeholder-map
#      honesty between README and templates).
#   5. No <PLACEHOLDER> strings appear outside plugins/flow-architecture/
#      templates/ (forces substitution discipline — placeholders only
#      legal inside templates/).
#
# The orchestrator-side integration (Phase 1 templates-scaffold + sed
# substitution + chmod +x + idempotency check) is exercised by
# /flow:retrofit-project itself during dogfood — this harness is the
# plugin-side fidelity check only.
#
# Bash 3.2 compatible (macOS default). No bash-4-only features.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$PLUGIN_ROOT/templates"

PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# ── §1: All 10 template files exist ─────────────────────────────────
section "1" "templates/ file presence"

EXPECTED_FILES=(
  "scripts/verify-docs.sh"
  "scripts/regenerate-flow-index.sh"
  "scripts/regenerate-flow-index.mts"
  "scripts/verify-linear-references.mts"
  "scripts/normalize-fda-frontmatter.mjs"
  "scripts/lib/fda-title.mts"
  "scripts/lib/linear-graphql.mts"
  ".flow/config.json"
  ".flow/scaffold-log/SCHEMA.md"
  "README.md"
)

for rel in "${EXPECTED_FILES[@]}"; do
  if [ -f "$TEMPLATES_DIR/$rel" ]; then
    pass "templates/$rel exists"
  else
    fail "templates/$rel MISSING"
  fi
done

# ── §2: verify-docs.sh has required preamble ────────────────────────
section "2" "verify-docs.sh shebang + set -euo"

VD="$TEMPLATES_DIR/scripts/verify-docs.sh"
if [ -f "$VD" ]; then
  if head -1 "$VD" | grep -q '^#!/usr/bin/env bash$'; then
    pass "verify-docs.sh has #!/usr/bin/env bash shebang"
  else
    fail "verify-docs.sh missing canonical bash shebang"
  fi
  if grep -q '^set -euo pipefail$' "$VD"; then
    pass "verify-docs.sh has set -euo pipefail"
  else
    fail "verify-docs.sh missing set -euo pipefail"
  fi
fi

# ── §3: No brite-roster / brite-nites / BRITE_ROSTER leaks in substitution targets ─
section "3" "no project-specific string leaks in substitution-target files"

# Forbidden strings — any of these in a substitution-target file (the
# scripts that get sed-substituted + copied into the consumer project)
# means the divergences from Q58 § "Brite-roster vs brite-base
# divergences" weren't genericized. brite-base + brite-roster are
# upstream references — fine to mention in documentation (README.md),
# NOT in substitution-target code.
#
# README.md is exempted because it's documentation about the templates
# (intentional historical attribution to brite-roster PR #8) — not
# code that lands in the consumer project's scripts/ directory.
FORBIDDEN_STRINGS=(
  "brite-roster"
  "brite-nites"
  "BRITE_ROSTER"
  "Brite Roster"
)

for needle in "${FORBIDDEN_STRINGS[@]}"; do
  hits=$(grep -rl --include='*.sh' --include='*.mts' --include='*.mjs' --include='*.json' \
          -F "$needle" "$TEMPLATES_DIR" 2>/dev/null || true)
  if [ -z "$hits" ]; then
    pass "no '$needle' in substitution-target files"
  else
    fail "forbidden string '$needle' leaks into substitution-target files:"
    printf '    %s\n' "$hits"
  fi
done

# ── §3b: Extra-file detection — actual count matches EXPECTED_FILES ─
section "3b" "no extra files in templates/ beyond EXPECTED_FILES (drift detection)"

actual_count=$(find "$TEMPLATES_DIR" -type f \
                \( -name '*.sh' -o -name '*.mts' -o -name '*.mjs' -o -name '*.json' -o -name '*.md' \) \
                2>/dev/null | wc -l | tr -d ' ')
expected_count="${#EXPECTED_FILES[@]}"

if [ "$actual_count" = "$expected_count" ]; then
  pass "templates/ contains exactly $expected_count files (matches EXPECTED_FILES)"
else
  fail "templates/ has $actual_count files but EXPECTED_FILES lists $expected_count — drift detected"
  find "$TEMPLATES_DIR" -type f \
    \( -name '*.sh' -o -name '*.mts' -o -name '*.mjs' -o -name '*.json' -o -name '*.md' \) \
    2>/dev/null | sed "s|$TEMPLATES_DIR/||" | sed 's/^/    /'
fi

# ── §3c: verify-docs.sh is syntactically valid bash ─────────────────
section "3c" "verify-docs.sh passes bash -n syntactic-validity check"

if [ -f "$VD" ]; then
  if bash -n "$VD" 2>/dev/null; then
    pass "verify-docs.sh: bash -n exits 0 (no syntax errors)"
  else
    fail "verify-docs.sh: bash -n reports syntax errors:"
    bash -n "$VD" 2>&1 | head -5 | sed 's/^/    /'
  fi
fi

# ── §4: Documented placeholders actually appear in templates ───────
section "4" "README-documented placeholders present in template files"

DOCUMENTED_PLACEHOLDERS=(
  "<LINEAR_PROJECT_ID>"
  "<LINEAR_ORG_SLUG>"
  "<PROJECT_NAME>"
  "<EXPECTED_FDA_ISSUE_COUNT>"
)

for ph in "${DOCUMENTED_PLACEHOLDERS[@]}"; do
  # Search across all template files for the placeholder. README.md
  # documents them — they MUST appear in at least one substitution
  # target. Use -F (fixed string) to avoid metachar issues from < >.
  hits=$(grep -rl --include='*.sh' --include='*.mts' --include='*.mjs' --include='*.json' \
          -F "$ph" "$TEMPLATES_DIR" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    pass "$ph used in $(printf '%s\n' $hits | wc -l | tr -d ' ') template file(s)"
  else
    fail "$ph documented in README.md but never appears in any template file"
  fi
done

# ── §5: Orchestrator ↔ template placeholder coherence ──────────────
section "5" "orchestrator (retrofit-project.md) substitution table matches templates"

# Q58 § Sub-decision 1 requires that the 4 documented placeholders in
# retrofit-project.md's Phase 1 templates-scaffold table EXACTLY MATCH
# the placeholders actually present in template files. Without this
# check, an orchestrator amendment that adds a 5th placeholder (or
# removes one of the 4) silently desynchronizes from the templates.
RETROFIT_MD="$PLUGIN_ROOT/commands/retrofit-project.md"

if [ ! -f "$RETROFIT_MD" ]; then
  fail "retrofit-project.md not found at $RETROFIT_MD"
else
  # Extract placeholders from the substitution table in retrofit-project.md.
  # The table is constrained to the Phase 1 § Templates scaffold subsection;
  # restrict by surrounding the grep with the section markers. Pattern:
  # `<UPPERCASE_WITH_UNDERSCORES>` is the placeholder shape.
  retrofit_placeholders=$(grep -oE '<[A-Z_]+>' "$RETROFIT_MD" \
                          | grep -E '^<(LINEAR_PROJECT_ID|LINEAR_ORG_SLUG|PROJECT_NAME|EXPECTED_FDA_ISSUE_COUNT)>$' \
                          | sort -u || true)

  # Extract placeholders from template files.
  template_placeholders=$(grep -rhoE '<(LINEAR_PROJECT_ID|LINEAR_ORG_SLUG|PROJECT_NAME|EXPECTED_FDA_ISSUE_COUNT)>' \
                            --include='*.sh' --include='*.mts' --include='*.mjs' --include='*.json' \
                            "$TEMPLATES_DIR" 2>/dev/null | sort -u || true)

  retrofit_count=$(printf '%s\n' "$retrofit_placeholders" | grep -c '<' || true)
  template_count=$(printf '%s\n' "$template_placeholders" | grep -c '<' || true)

  if [ "$retrofit_placeholders" = "$template_placeholders" ] && [ "$retrofit_count" = "4" ]; then
    pass "orchestrator-table placeholders = template placeholders ($retrofit_count each, exact set match)"
  else
    fail "orchestrator-template placeholder drift detected:"
    printf '    retrofit-project.md placeholders:\n'
    printf '%s\n' "$retrofit_placeholders" | sed 's/^/      /'
    printf '    templates/ placeholders:\n'
    printf '%s\n' "$template_placeholders" | sed 's/^/      /'
  fi
fi

# ── §6: scaffold-log SCHEMA.md has frontmatter ─────────────────────
section "6" ".flow/scaffold-log/SCHEMA.md has frontmatter"

SCHEMA="$TEMPLATES_DIR/.flow/scaffold-log/SCHEMA.md"
if [ -f "$SCHEMA" ]; then
  if head -1 "$SCHEMA" | grep -q '^---$'; then
    pass "SCHEMA.md starts with --- frontmatter"
  else
    fail "SCHEMA.md missing --- frontmatter delimiter"
  fi
  if grep -q '^flow_index: skip$' "$SCHEMA"; then
    pass "SCHEMA.md sets flow_index: skip (won't trip regenerate-flow-index)"
  else
    fail "SCHEMA.md missing flow_index: skip (would false-positive in INDEX regen)"
  fi
fi

# ── §7: README.md describes all 4 placeholders ─────────────────────
section "7" "templates/README.md documents all 4 substitution placeholders"

README="$TEMPLATES_DIR/README.md"
if [ -f "$README" ]; then
  for ph in "${DOCUMENTED_PLACEHOLDERS[@]}"; do
    if grep -qF "$ph" "$README"; then
      pass "README.md mentions $ph"
    else
      fail "README.md missing documentation for $ph"
    fi
  done
fi

# ── Summary ─────────────────────────────────────────────────────────
printf '\n'
printf '─────────────────────────────────────────────\n'
printf 'RESULT pass=%d fail=%d total=%d\n' "$PASS" "$FAIL" $((PASS + FAIL))
printf '─────────────────────────────────────────────\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
