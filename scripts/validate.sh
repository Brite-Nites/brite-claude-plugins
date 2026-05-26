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

    while IFS= read -r line; do
      status="${line%%:*}"
      msg="${line#*:}"
      if [ "$status" = "PASS" ]; then
        pass "$msg"
      else
        fail "$msg does not exist"
      fi
    done <<< "$path_output"
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
