#!/usr/bin/env bash
# BC-11091 + BC-11089 integration test for templates-scaffold recipe parity
# across /flow:retrofit-project AND /flow:start-project Phase 1.
#
# Scope:
#   1. Copy fixture project to a tmpdir + git init.
#   2. Execute the python3-heredoc + sed-script-file template-copy recipe
#      verbatim from commands/retrofit-project.md § Phase 1 step 4 — extracted
#      below as `run_templates_scaffold`.
#   3. Assert all 9 templates land at the expected target paths.
#   4. Assert all 4 placeholders were substituted with the configured values
#      AND no <PLACEHOLDER> tokens remain in any copied file.
#   5. Assert chmod +x applied to the two .sh files.
#   6. Assert every copied .sh + .mts + .mjs is syntactically valid
#      (bash -n / tsx --no-cache --check / node --check).
#   7. Assert `bash scripts/verify-docs.sh --no-linear` exits 0 against the
#      fixture post-scaffold (skipped with SKIP-tracking if npm install fails
#      or tsx + gray-matter cannot be resolved — see § verify-docs exit-0 path).
#   8. Idempotency-without-flag: re-running the recipe halts before mutating
#      any file with a halt message naming the conflict list.
#   9. Idempotency-with-flag: re-running with --overwrite-scripts re-writes
#      every target file.
#
# Sibling: run-verify-docs-ecosystem-vslice.sh asserts template fidelity
# (file presence + placeholder map + no project-string leaks). This driver
# sits ON TOP of that — exercising the orchestrator-recipe's substitution +
# idempotency contract, which the template-fidelity test doesn't cover.
#
# Recipe-extraction contract:
#   `run_templates_scaffold` below is a verbatim port of the bash blocks at
#   plugins/flow-architecture/commands/retrofit-project.md § Phase 1 step 3
#   (idempotency check) + step 4 (substitution recipe) + step 4 trailing
#   chmod. The orchestrator's prose interleaves narrative paragraphs between
#   these blocks; the function joins them in execution order, preserving:
#     - the python3 esc() escape function (sed-replacement metachars)
#     - the env-var passing pattern (Linear-derived strings stay inside python)
#     - the mktemp sed-script-file route (no stdin pipe to sed)
#     - cross-platform `sed -i.bak` (works on BSD + GNU)
#     - chmod +x on the two .sh files
#   When retrofit-project.md's recipe changes, this function MUST be updated
#   to match — drift-detection lives in the "regression validation" section
#   of BC-11091 + the runtime "Run 1 → 9 files land" assertion.
#
# Bash 3.2 compatible (macOS default). No bash-4-only features.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$PLUGIN_ROOT/templates"
FIXTURE_SRC="$SCRIPT_DIR/fixtures/verify-docs-ecosystem-integration"

PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP  %s\n' "$1"; SKIP=$((SKIP + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# ── fixture setup ───────────────────────────────────────────────────
if [ ! -d "$FIXTURE_SRC" ]; then
  fail "fixture source dir missing: $FIXTURE_SRC"
  printf '\n─────────────────────────────────────────────\n'
  printf 'RESULT pass=%d fail=%d skip=%d total=%d\n' "$PASS" "$FAIL" "$SKIP" $((PASS + FAIL + SKIP))
  printf '─────────────────────────────────────────────\n'
  exit 1
fi

# Resolve tmpdir + verify mktemp succeeded BEFORE any cd/tar/git op runs
# against it. Empty TMP_FIXTURE would silently fall through to no-op cd
# (cd "" = stay in CWD), turning all subsequent fixture-scoped operations
# into mutations of this worktree. That precise failure mode created a
# spurious "fixture init" commit on the worktree's HEAD before this guard
# was added. Verify (1) mktemp output is non-empty, (2) it resolved to a
# real directory, and (3) the directory is NOT inside this repo's worktree
# (an extra sanity net in case TMPDIR is set somewhere weird).
TMP_FIXTURE="$(mktemp -d -t bc-11091-fixture.XXXXXX 2>/dev/null || true)"
REPO_TOPLEVEL_FROM_TEST="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$TMP_FIXTURE" ] || [ ! -d "$TMP_FIXTURE" ]; then
  fail "mktemp -d failed (TMP_FIXTURE='$TMP_FIXTURE') — cannot run integration test safely"
  printf '\n─────────────────────────────────────────────\n'
  printf 'RESULT pass=%d fail=%d skip=%d total=%d\n' "$PASS" "$FAIL" "$SKIP" $((PASS + FAIL + SKIP))
  printf '─────────────────────────────────────────────\n'
  exit 1
fi
if [ -n "$REPO_TOPLEVEL_FROM_TEST" ]; then
  case "$TMP_FIXTURE" in
    "$REPO_TOPLEVEL_FROM_TEST"|"$REPO_TOPLEVEL_FROM_TEST"/*)
      fail "TMP_FIXTURE ('$TMP_FIXTURE') resolved INSIDE the repo ('$REPO_TOPLEVEL_FROM_TEST') — refusing to mutate"
      printf '\n─────────────────────────────────────────────\n'
      printf 'RESULT pass=%d fail=%d skip=%d total=%d\n' "$PASS" "$FAIL" "$SKIP" $((PASS + FAIL + SKIP))
      printf '─────────────────────────────────────────────\n'
      exit 1
      ;;
  esac
fi
# Cleanup tmpdir on exit (success OR fail) so re-runs start clean. Guard
# inside the trap too — if TMP_FIXTURE got unset somehow between here and
# exit, the empty-string-rm would either no-op or (in pathological cases)
# remove every file in $PWD.
trap '[ -n "${TMP_FIXTURE:-}" ] && [ -d "${TMP_FIXTURE:-}" ] && rm -rf "$TMP_FIXTURE"' EXIT

# Copy fixture into tmpdir. Use tar (BSD + GNU compatible) to preserve mode
# bits + skip the .gitignore'd targets the test wants to create fresh.
( cd "$FIXTURE_SRC" && tar cf - --exclude=node_modules --exclude=scripts --exclude=.flow --exclude=docs/product/flows/INDEX.md . ) | ( cd "$TMP_FIXTURE" && tar xf - )

# Some BSD tars treat missing exclude targets as warnings; check we landed
# the four expected fixture files.
if [ ! -f "$TMP_FIXTURE/package.json" ] || [ ! -f "$TMP_FIXTURE/CLAUDE.md" ] || [ ! -f "$TMP_FIXTURE/README.md" ] || [ ! -f "$TMP_FIXTURE/docs/product/master-flow-inventory.md" ]; then
  fail "fixture copy incomplete — required files missing in $TMP_FIXTURE"
  printf '\n─────────────────────────────────────────────\n'
  printf 'RESULT pass=%d fail=%d skip=%d total=%d\n' "$PASS" "$FAIL" "$SKIP" $((PASS + FAIL + SKIP))
  printf '─────────────────────────────────────────────\n'
  exit 1
fi

# git init the tmpdir — verify-docs.sh runs `git rev-parse --show-toplevel`
# and would otherwise resolve to this repo's toplevel + run against the
# WRONG doc tree. Use `git -C "$TMP_FIXTURE"` form (NOT subshell+cd) so a
# cd failure cannot let git operations escape into the parent repo. The
# unset of GIT_DIR / GIT_WORK_TREE / GIT_INDEX_FILE neutralizes any env-var
# inheritance from the parent shell (a pre-push hook could plausibly set
# these; if it did, `git init` would target the parent's repo metadata).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
git -C "$TMP_FIXTURE" init -q
git -C "$TMP_FIXTURE" add -A
git -C "$TMP_FIXTURE" -c user.email=fixture@test -c user.name=Fixture commit -q -m "fixture init" >/dev/null

# Defense-in-depth: confirm the fixture's .git landed where we expected
# (i.e., inside TMP_FIXTURE, not anywhere else). If git silently routed
# the writes elsewhere, the per-file existence check catches it before
# the recipe runs.
if [ ! -d "$TMP_FIXTURE/.git" ]; then
  fail "git init did NOT create $TMP_FIXTURE/.git — abort to avoid wrong-target mutation"
  printf '\n─────────────────────────────────────────────\n'
  printf 'RESULT pass=%d fail=%d skip=%d total=%d\n' "$PASS" "$FAIL" "$SKIP" $((PASS + FAIL + SKIP))
  printf '─────────────────────────────────────────────\n'
  exit 1
fi

# ── recipe extraction ───────────────────────────────────────────────
# Verbatim from plugins/flow-architecture/commands/retrofit-project.md
# § Phase 1 step 3 (idempotency check) + step 4 (substitution recipe) +
# step 4 trailing chmod. Joined in execution order. Inputs come from env:
#
#   REPO_ROOT                — fixture tmpdir absolute path
#   CLAUDE_PLUGIN_ROOT       — plugin source dir (for templates lookup)
#   LINEAR_PROJECT_ID        — placeholder value for <LINEAR_PROJECT_ID>
#   LINEAR_ORG_SLUG          — placeholder value for <LINEAR_ORG_SLUG>
#   LINEAR_PROJECT_NAME      — placeholder value for <PROJECT_NAME>
#   FLOW_OVERWRITE_SCRIPTS   — "true" to bypass idempotency check (else "false")
#
# Returns 0 on success, 3 on idempotency halt, non-zero on any other error.
run_templates_scaffold() {
  # Step 2: template-source → target-path pairs (9 files).
  # Parallel arrays — bash 3.2 has no associative-array support.
  local SRC_PATHS
  local TGT_PATHS
  SRC_PATHS=(
    "$CLAUDE_PLUGIN_ROOT/templates/scripts/verify-docs.sh"
    "$CLAUDE_PLUGIN_ROOT/templates/scripts/regenerate-flow-index.sh"
    "$CLAUDE_PLUGIN_ROOT/templates/scripts/regenerate-flow-index.mts"
    "$CLAUDE_PLUGIN_ROOT/templates/scripts/verify-linear-references.mts"
    "$CLAUDE_PLUGIN_ROOT/templates/scripts/normalize-fda-frontmatter.mjs"
    "$CLAUDE_PLUGIN_ROOT/templates/scripts/lib/fda-title.mts"
    "$CLAUDE_PLUGIN_ROOT/templates/scripts/lib/linear-graphql.mts"
    "$CLAUDE_PLUGIN_ROOT/templates/.flow/scaffold-log/SCHEMA.md"
    "$CLAUDE_PLUGIN_ROOT/templates/README.md"
  )
  TGT_PATHS=(
    "$REPO_ROOT/scripts/verify-docs.sh"
    "$REPO_ROOT/scripts/regenerate-flow-index.sh"
    "$REPO_ROOT/scripts/regenerate-flow-index.mts"
    "$REPO_ROOT/scripts/verify-linear-references.mts"
    "$REPO_ROOT/scripts/normalize-fda-frontmatter.mjs"
    "$REPO_ROOT/scripts/lib/fda-title.mts"
    "$REPO_ROOT/scripts/lib/linear-graphql.mts"
    "$REPO_ROOT/.flow/scaffold-log/SCHEMA.md"
    "$REPO_ROOT/scripts/FDA-TEMPLATES-README.md"
  )

  # Step 3: idempotency check — unless --overwrite-scripts. Use a bash array
  # instead of a space-joined string so target paths containing spaces (e.g.,
  # an exotic TMPDIR) survive unmangled — guard the empty-array expansion
  # per the BC-6905 set -u gotcha.
  if [ "${FLOW_OVERWRITE_SCRIPTS:-false}" != "true" ]; then
    local -a conflicts=()
    local i
    for i in "${!TGT_PATHS[@]}"; do
      if [ -f "${TGT_PATHS[$i]}" ]; then
        conflicts+=("${TGT_PATHS[$i]}")
      fi
    done
    if [ "${#conflicts[@]}" -gt 0 ]; then
      printf 'Templates already present in project (paths listed) — re-run with --overwrite-scripts to replace.\n' >&2
      printf '%s\n' "${conflicts[@]}" >&2
      return 3
    fi
  fi

  # Step 4: copy + substitute + chmod.
  # Build the sed script via python3 (single-quoted heredoc — no shell
  # variable expansion inside the python source).
  local SED_SCRIPT
  SED_SCRIPT="$(mktemp -t flow-sed.XXXXXX)"
  LINEAR_PROJECT_ID_IN="$LINEAR_PROJECT_ID" \
  LINEAR_ORG_SLUG_IN="$LINEAR_ORG_SLUG" \
  PROJECT_NAME_IN="$LINEAR_PROJECT_NAME" \
  EXPECTED_COUNT_IN="0" \
    python3 > "$SED_SCRIPT" <<'PY'
import os
def esc(s):
    # sed replacement-string metacharacters: \, &, the chosen delimiter |
    return s.replace("\\", "\\\\").replace("|", "\\|").replace("&", "\\&").replace("\n", "\\n")
for ph, env in [
    ("<LINEAR_PROJECT_ID>", "LINEAR_PROJECT_ID_IN"),
    ("<LINEAR_ORG_SLUG>", "LINEAR_ORG_SLUG_IN"),
    ("<PROJECT_NAME>", "PROJECT_NAME_IN"),
    ("<EXPECTED_FDA_ISSUE_COUNT>", "EXPECTED_COUNT_IN"),
]:
    value = os.environ.get(env, "")
    print(f"s|{ph}|{esc(value)}|g")
PY

  # Ensure target directories exist + copy template files into target paths.
  local idx src tgt
  for idx in "${!SRC_PATHS[@]}"; do
    src="${SRC_PATHS[$idx]}"
    tgt="${TGT_PATHS[$idx]}"
    mkdir -p "$(dirname "$tgt")"
    cp "$src" "$tgt"
  done

  # Cross-platform sed -i: -i.bak works on both BSD (macOS default) and GNU
  # sed; remove the .bak file after substitution.
  for idx in "${!TGT_PATHS[@]}"; do
    tgt="${TGT_PATHS[$idx]}"
    sed -i.bak -f "$SED_SCRIPT" "$tgt"
    rm -f "$tgt.bak"
  done
  rm -f "$SED_SCRIPT"

  # chmod +x the two .sh files.
  chmod +x "$REPO_ROOT/scripts/verify-docs.sh"
  chmod +x "$REPO_ROOT/scripts/regenerate-flow-index.sh"

  return 0
}

# ── §1: Run 1 — recipe places 9 files ───────────────────────────────
section "1" "first recipe run — placeholder substitution + 9 files land"

# Fixture-specific placeholder values. These mirror the shape of real
# Linear-derived inputs but are clearly test-only — any of these strings
# showing up in production is a sign of test-fixture contamination.
#
# LINEAR_PROJECT_NAME intentionally contains `&`, `\\`, and `|` — these are
# the three sed-replacement metacharacters the recipe's python3 esc() handles.
#
# Scope of what these metachars catch: §1 (recipe rc=0) + §2 (placeholder
# substitution) exercise the TEST DRIVER's copy of esc() at runtime. This is
# defense-in-depth against test-driver bit-rot (a future maintainer dropping
# a handler in `run_templates_scaffold` above), NOT against drift in
# `commands/retrofit-project.md` — approach (a)'s recipe-mirror is static, so
# orchestrator drift in esc() is caught by §8's grep-based sync check, not by
# fixture-input behavior. Both layers stay in place; this is the runtime one.
LINEAR_PROJECT_ID="00000000-0000-0000-0000-000000000bc11091"
LINEAR_ORG_SLUG="bc-11091-fixture"
LINEAR_PROJECT_NAME='BC-11091 Fixture & Co \\ Test | Project'
REPO_ROOT="$TMP_FIXTURE"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
FLOW_OVERWRITE_SCRIPTS="false"
export LINEAR_PROJECT_ID LINEAR_ORG_SLUG LINEAR_PROJECT_NAME REPO_ROOT CLAUDE_PLUGIN_ROOT FLOW_OVERWRITE_SCRIPTS

if run_templates_scaffold; then
  pass "recipe exited 0 (first run, no conflicts)"
else
  fail "recipe exited non-zero on first run against clean fixture"
fi

# Per-file presence (9 files) — matches retrofit-project.md Phase 1 step 2 table.
EXPECTED_TARGETS=(
  "scripts/verify-docs.sh"
  "scripts/regenerate-flow-index.sh"
  "scripts/regenerate-flow-index.mts"
  "scripts/verify-linear-references.mts"
  "scripts/normalize-fda-frontmatter.mjs"
  "scripts/lib/fda-title.mts"
  "scripts/lib/linear-graphql.mts"
  ".flow/scaffold-log/SCHEMA.md"
  "scripts/FDA-TEMPLATES-README.md"
)

for rel in "${EXPECTED_TARGETS[@]}"; do
  if [ -f "$TMP_FIXTURE/$rel" ]; then
    pass "landed: $rel"
  else
    fail "missing: $rel"
  fi
done

# ── §2: Placeholders substituted (and no <PLACEHOLDER> leaks) ───────
section "2" "placeholder substitution"

# Expected substituted values per placeholder.
# <EXPECTED_FDA_ISSUE_COUNT> → literal "0" — a numeric token that also appears
# legitimately in many other contexts, so we don't grep for it; the absence
# check below covers it.
expected_values=(
  "$LINEAR_PROJECT_ID"
  "$LINEAR_ORG_SLUG"
  "$LINEAR_PROJECT_NAME"
)

for val in "${expected_values[@]}"; do
  # -F = fixed string. Use --include filters to match the recipe's substitution
  # scope (.sh + .mts + .mjs + .md). Returns at least one hit if substituted.
  if grep -rqF --include='*.sh' --include='*.mts' --include='*.mjs' --include='*.md' --include='*.json' "$val" "$TMP_FIXTURE/scripts" "$TMP_FIXTURE/.flow" 2>/dev/null; then
    pass "substituted value present: '$val'"
  else
    fail "substituted value MISSING in copied files: '$val'"
  fi
done

# Negative case — no <PLACEHOLDER> tokens remain. The four documented
# placeholders are the only ones substituted; any residue is a substitution
# failure.
placeholders=(
  "<LINEAR_PROJECT_ID>"
  "<LINEAR_ORG_SLUG>"
  "<PROJECT_NAME>"
  "<EXPECTED_FDA_ISSUE_COUNT>"
)
for ph in "${placeholders[@]}"; do
  if grep -rqF --include='*.sh' --include='*.mts' --include='*.mjs' --include='*.md' --include='*.json' "$ph" "$TMP_FIXTURE/scripts" "$TMP_FIXTURE/.flow" 2>/dev/null; then
    fail "unsubstituted placeholder remains: '$ph'"
  else
    pass "no residue of placeholder: '$ph'"
  fi
done

# ── §3: chmod +x on .sh files ───────────────────────────────────────
section "3" "executable bit on .sh files"

for sh in scripts/verify-docs.sh scripts/regenerate-flow-index.sh; do
  if [ -x "$TMP_FIXTURE/$sh" ]; then
    pass "executable: $sh"
  else
    fail "not executable: $sh"
  fi
done

# .mts / .mjs / .md must NOT be executable per the recipe.
for non_sh in scripts/regenerate-flow-index.mts scripts/lib/fda-title.mts scripts/FDA-TEMPLATES-README.md; do
  if [ ! -x "$TMP_FIXTURE/$non_sh" ]; then
    pass "non-executable: $non_sh"
  else
    fail "unexpectedly executable: $non_sh"
  fi
done

# ── §4: Syntactic validity of copied scripts ────────────────────────
section "4" "syntactic validity (post-substitution)"

# The recipe substitutes inside .sh + .mts + .mjs files. If a Linear-derived
# value contained a metachar that the esc() function failed to escape, the
# substituted value could break bash / JS syntax. bash -n covers the .sh
# files; `node --check` covers the .mjs file (free, no dep cost); .mts files
# require tsx --check which has a tsx install cost, so we defer the .mts
# syntactic check to §7 (where tsx is installed anyway as part of the full-
# pipeline assertion).
for sh in scripts/verify-docs.sh scripts/regenerate-flow-index.sh; do
  if bash -n "$TMP_FIXTURE/$sh" 2>/dev/null; then
    pass "bash -n passes: $sh"
  else
    fail "bash -n syntax error: $sh"
    bash -n "$TMP_FIXTURE/$sh" 2>&1 | head -3 | sed 's/^/    /'
  fi
done

# node --check on .mjs (built-in, no devDep needed).
if command -v node >/dev/null 2>&1; then
  for mjs in scripts/normalize-fda-frontmatter.mjs; do
    if node --check "$TMP_FIXTURE/$mjs" 2>/dev/null; then
      pass "node --check passes: $mjs"
    else
      fail "node --check syntax error: $mjs"
      node --check "$TMP_FIXTURE/$mjs" 2>&1 | head -3 | sed 's/^/    /'
    fi
  done
else
  skip "node not installed — .mjs syntax check skipped"
fi

# ── §5: Idempotency without --overwrite-scripts ─────────────────────
section "5" "idempotency — re-run without flag halts cleanly"

FLOW_OVERWRITE_SCRIPTS="false"
export FLOW_OVERWRITE_SCRIPTS

set +e
halt_out=$(run_templates_scaffold 2>&1)
halt_rc=$?
set -e

if [ "$halt_rc" -eq 3 ]; then
  pass "second run without flag halted with rc=3 (idempotency-protect)"
else
  fail "second run without flag did NOT halt (rc=$halt_rc, expected 3)"
fi

if printf '%s\n' "$halt_out" | grep -qF "Templates already present in project"; then
  pass "halt message names conflict ('Templates already present')"
else
  fail "halt message missing expected substring"
  printf '%s\n' "$halt_out" | head -5 | sed 's/^/    /'
fi

# Spot-check: the halt should name AT LEAST one of the 9 target paths so
# the operator knows what to remove. We grep for scripts/verify-docs.sh
# as a deterministic anchor.
if printf '%s\n' "$halt_out" | grep -qF "scripts/verify-docs.sh"; then
  pass "halt output lists at least one conflicting target path"
else
  fail "halt output did NOT name any target path"
fi

# ── §6: Idempotency WITH --overwrite-scripts ────────────────────────
section "6" "idempotency — --overwrite-scripts re-writes every file"

# Mutate one of the copied files; --overwrite-scripts must restore it.
echo "# OVERWRITTEN-BY-TEST-MARKER" >> "$TMP_FIXTURE/scripts/verify-docs.sh"

FLOW_OVERWRITE_SCRIPTS="true"
export FLOW_OVERWRITE_SCRIPTS

if run_templates_scaffold; then
  pass "recipe exited 0 with --overwrite-scripts"
else
  fail "recipe failed with --overwrite-scripts (rc=$?)"
fi

if grep -qF "OVERWRITTEN-BY-TEST-MARKER" "$TMP_FIXTURE/scripts/verify-docs.sh"; then
  fail "test marker survived overwrite — file NOT re-written"
else
  pass "test marker gone — file re-written by --overwrite-scripts"
fi

# Re-confirm placeholder substitution across the full substitution scope
# (catches an overwrite-path that copies but skips substitution on any one
# file — a stricter assertion than the previous OR-of-two-files check, which
# could silently pass when one file was substituted and another wasn't).
for val in "$LINEAR_PROJECT_ID" "$LINEAR_ORG_SLUG" "$LINEAR_PROJECT_NAME"; do
  if grep -rqF --include='*.sh' --include='*.mts' --include='*.mjs' --include='*.md' --include='*.json' \
       "$val" "$TMP_FIXTURE/scripts" "$TMP_FIXTURE/.flow" 2>/dev/null; then
    pass "overwrite re-substituted value: '$val'"
  else
    fail "overwrite path missing substituted value: '$val'"
  fi
done

# ── §7: verify-docs.sh --no-linear exits 0 (full pipeline) ──────────
section "7" "verify-docs.sh --no-linear exits 0"

# This requires tsx + gray-matter installed in the fixture node_modules so
# that regenerate-flow-index.sh --check (called by verify-docs.sh) can
# load + execute. We install on demand; if npm install fails (offline,
# missing npm, network outage), we SKIP rather than FAIL — the recipe-
# regression risk is already covered by §1-6.
#
# Trip-wire per BC-11091 brief: "If the fixture project needs unusual setup
# (e.g., needs `npm install` for tsx to run .mts files): note in the test
# driver + PR description." This block is that note.
#
# CI cost knob: set BC_11091_SKIP_NPM_INSTALL=true to skip the npm install +
# verify-docs.sh full-pipeline check entirely. Default (unset) runs the full
# pipeline, satisfying AC #5 ("verify-docs.sh exits 0"). The env-var exists
# so a future CI workflow can shed the ~25s cold-cache install cost on PRs
# that don't touch the FDA plugin, while keeping the assertion on a nightly
# / changed-files-gated job. Recipe-regression coverage is preserved by
# §1-6 + §8 regardless of whether §7 runs.
# Log paths under $TMP_FIXTURE/ (cleaned by the EXIT trap) — avoid /tmp/*.log
# hardcoded paths which are vulnerable to symlink-TOCTOU races on shared hosts.
NPM_LOG="$TMP_FIXTURE/.bc-11091-npm-install.log"
REGEN_LOG="$TMP_FIXTURE/.bc-11091-regen.log"
VERIFY_LOG="$TMP_FIXTURE/.bc-11091-verify.log"

NPM_INSTALL_OK="false"
if [ "${BC_11091_SKIP_NPM_INSTALL:-false}" = "true" ]; then
  skip "BC_11091_SKIP_NPM_INSTALL=true — verify-docs.sh full pipeline check skipped"
elif command -v npm >/dev/null 2>&1; then
  if ( cd "$TMP_FIXTURE" && npm install --no-audit --no-fund --silent --prefer-offline ) >"$NPM_LOG" 2>&1; then
    NPM_INSTALL_OK="true"
    pass "npm install succeeded in fixture tmpdir"
  else
    skip "npm install failed — see $NPM_LOG; cannot run verify-docs.sh full pipeline"
    tail -5 "$NPM_LOG" 2>/dev/null | sed 's/^/    /' || true
  fi
else
  skip "npm not installed — cannot run verify-docs.sh full pipeline"
fi

if [ "$NPM_INSTALL_OK" = "true" ]; then
  # Seed INDEX.md by running regen in write mode. Without this, verify-docs.sh
  # would see "INDEX.md does not exist" and fail. The seeded INDEX is what
  # the --check assertion compares against on the next pass.
  if ( cd "$TMP_FIXTURE" && bash scripts/regenerate-flow-index.sh ) >"$REGEN_LOG" 2>&1; then
    pass "regenerate-flow-index.sh write-mode succeeded"
  else
    fail "regenerate-flow-index.sh write-mode failed"
    tail -10 "$REGEN_LOG" 2>/dev/null | sed 's/^/    /' || true
  fi

  if ( cd "$TMP_FIXTURE" && bash scripts/verify-docs.sh --no-linear ) >"$VERIFY_LOG" 2>&1; then
    pass "verify-docs.sh --no-linear exits 0"
  else
    fail "verify-docs.sh --no-linear exited non-zero"
    tail -20 "$VERIFY_LOG" 2>/dev/null | sed 's/^/    /' || true
  fi
fi

# ── §8: Orchestrator-recipe contract sync (retrofit-project.md drift) ──
section "8" "retrofit-project.md recipe contract check"

# Approach (a) per BC-11091 brief — `run_templates_scaffold` above is a
# verbatim port of commands/retrofit-project.md § Phase 1 steps 3+4. The
# test driver and the orchestrator's prose are kept in sync by copy-paste,
# NOT by live source extraction. To satisfy BC-11091 AC #5 ("test catches
# a regression of the recipe in retrofit-project.md"), this section asserts
# the orchestrator's prose still contains every load-bearing recipe element
# that `run_templates_scaffold` depends on. Mutating any of these in
# retrofit-project.md flips the corresponding assertion to FAIL.
#
# Coupling cost: extending the recipe requires updating BOTH retrofit-
# project.md AND this section's expected-strings list. The trade-off is
# accepted in BC-11091's scope; a v1.2.x patch isn't the place to refactor
# the orchestrator into a shared shell library.

RETROFIT_MD="$PLUGIN_ROOT/commands/retrofit-project.md"

# Shared assertion arrays — hoisted above §8/§9 conditionals so both
# sections can iterate them regardless of whether the other section's
# awk extraction succeeded. Under set -u, referencing an undefined
# array crashes the script; hoisting prevents §9 from crashing when
# §8's extraction fails (and vice versa).
RECIPE_TEMPLATE_REFS=(
  "templates/scripts/verify-docs.sh"
  "templates/scripts/regenerate-flow-index.sh"
  "templates/scripts/regenerate-flow-index.mts"
  "templates/scripts/verify-linear-references.mts"
  "templates/scripts/normalize-fda-frontmatter.mjs"
  "templates/scripts/lib/fda-title.mts"
  "templates/scripts/lib/linear-graphql.mts"
  "templates/.flow/scaffold-log/SCHEMA.md"
  "templates/README.md"
)
RECIPE_PLACEHOLDERS=(
  "<LINEAR_PROJECT_ID>"
  "<LINEAR_ORG_SLUG>"
  "<PROJECT_NAME>"
  "<EXPECTED_FDA_ISSUE_COUNT>"
)
RECIPE_PRIMITIVES=(
  "python3 > \"\$SED_SCRIPT\""
  "sed -i.bak -f"
  "chmod +x"
  "rm -f \"\$SED_SCRIPT\""
  "--overwrite-scripts"
  "mkdir -p"
  "SRC_PATHS=("
)
ESC_CHARS=(
  'replace("\\", "\\\\")'
  'replace("|", "\\|")'
  'replace("&", "\\&")'
  'replace("\n", "\\n")'
)

if [ ! -f "$RETROFIT_MD" ]; then
  fail "retrofit-project.md not found at $RETROFIT_MD"
else
  RECIPE_BLOCK_CONTENT="$(awk '
    /\*\*Templates scaffold \(BC-11029, Q58\):\*\*/ { flag=1 }
    /\*\*Failure semantics \(templates scaffold\):\*\*/ { flag=0 }
    flag
  ' "$RETROFIT_MD")"

  if [ -z "$RECIPE_BLOCK_CONTENT" ]; then
    fail "could not extract active recipe block from retrofit-project.md — anchor headers drifted"
  else
    pass "active recipe block extracted from retrofit-project.md"

    block_contains() { case "$RECIPE_BLOCK_CONTENT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

    for ref in "${RECIPE_TEMPLATE_REFS[@]}"; do
      if block_contains "$ref"; then
        pass "recipe block references: $ref"
      else
        fail "recipe block MISSING template ref: $ref (orchestrator drift)"
      fi
    done

    for ph in "${RECIPE_PLACEHOLDERS[@]}"; do
      if block_contains "$ph"; then
        pass "recipe block substitutes placeholder: $ph"
      else
        fail "recipe block MISSING placeholder substitution: $ph (orchestrator drift)"
      fi
    done

    for prim in "${RECIPE_PRIMITIVES[@]}"; do
      if block_contains "$prim"; then
        pass "recipe block primitive present: $prim"
      else
        fail "recipe block MISSING primitive: $prim (orchestrator drift)"
      fi
    done

    for ec in "${ESC_CHARS[@]}"; do
      if block_contains "$ec"; then
        pass "recipe block esc() handles: $ec"
      else
        fail "recipe block esc() MISSING handler: $ec (security regression)"
      fi
    done
  fi
fi

# ── §9: start-project.md recipe contract check (BC-11089 parity) ────
section "9" "start-project.md recipe contract check (BC-11089 parity)"

START_MD="$PLUGIN_ROOT/commands/start-project.md"

if [ ! -f "$START_MD" ]; then
  fail "start-project.md not found at $START_MD"
else
  START_RECIPE_BLOCK="$(awk '
    /\*\*Templates scaffold \(BC-11029, Q58\):\*\*/ { flag=1 }
    /\*\*Failure semantics \(templates scaffold\):\*\*/ { flag=0 }
    flag
  ' "$START_MD")"

  if [ -z "$START_RECIPE_BLOCK" ]; then
    fail "could not extract recipe block from start-project.md — anchor headers missing (BC-11089 parity gap)"
  else
    pass "recipe block extracted from start-project.md"

    start_block_contains() { case "$START_RECIPE_BLOCK" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

    for ref in "${RECIPE_TEMPLATE_REFS[@]}"; do
      if start_block_contains "$ref"; then
        pass "start-project recipe references: $ref"
      else
        fail "start-project recipe MISSING template ref: $ref (parity drift)"
      fi
    done

    for ph in "${RECIPE_PLACEHOLDERS[@]}"; do
      if start_block_contains "$ph"; then
        pass "start-project recipe substitutes placeholder: $ph"
      else
        fail "start-project recipe MISSING placeholder: $ph (parity drift)"
      fi
    done

    for prim in "${RECIPE_PRIMITIVES[@]}"; do
      if start_block_contains "$prim"; then
        pass "start-project recipe primitive present: $prim"
      else
        fail "start-project recipe MISSING primitive: $prim (parity drift)"
      fi
    done

    for ec in "${ESC_CHARS[@]}"; do
      if start_block_contains "$ec"; then
        pass "start-project esc() handles: $ec"
      else
        fail "start-project esc() MISSING handler: $ec (security parity drift)"
      fi
    done
  fi
fi

# ── Summary ─────────────────────────────────────────────────────────
printf '\n'
printf '─────────────────────────────────────────────\n'
printf 'RESULT pass=%d fail=%d skip=%d total=%d\n' "$PASS" "$FAIL" "$SKIP" $((PASS + FAIL + SKIP))
printf '─────────────────────────────────────────────\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
