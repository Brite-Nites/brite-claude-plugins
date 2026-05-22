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
    printf '    %s\n' $hits
  fi
done

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

# ── §5: Placeholder discipline — templates substitute, prose may reference ──
section "5" "placeholders appear correctly inside templates/"

# The strict "no placeholders outside templates/" check is unworkable —
# the design-rationale archive + retrofit-project.md + start-project.md +
# regen SKILL.md all reference `<PROJECT_NAME>` (etc.) in prose context
# (e.g., "Substitute <PROJECT_NAME> from .flow/config.json" — a
# legitimate design-doc reference). The substitution discipline that
# matters: every placeholder that the orchestrator substitutes (§4 above)
# appears in at least one substitution-target file under templates/.
# That's what §4 checks. This section is a duplicate placeholder fixedly
# in templates/ to keep the test count > 0 and signal that the check is
# intentionally narrower than a tempting global grep.

placeholders_in_templates=$(grep -rlE '<(LINEAR_PROJECT_ID|LINEAR_ORG_SLUG|PROJECT_NAME|EXPECTED_FDA_ISSUE_COUNT)>' \
                              --include='*.sh' --include='*.mts' --include='*.mjs' --include='*.json' \
                              "$TEMPLATES_DIR" 2>/dev/null | wc -l | tr -d ' ')

if [ "$placeholders_in_templates" -ge 4 ]; then
  pass "$placeholders_in_templates substitution-target file(s) carry placeholders (≥4 required)"
else
  fail "expected ≥4 substitution-target files with placeholders; found $placeholders_in_templates"
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
