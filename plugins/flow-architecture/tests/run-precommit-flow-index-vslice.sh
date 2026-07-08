#!/usr/bin/env bash
# BC-16783 v-slice for the pre-commit flow-INDEX auto-regen helper
# (templates/scripts/precommit-flow-index.sh, Q60).
#
# Two layers:
#   A. Fidelity — the shipped template is a guarded bash script that calls the
#      DETERMINISTIC regenerate-flow-index.sh (never the flow-regen-index skill),
#      covers the regenerator's FULL input set (flows/**.md + master-flow-
#      inventory.md — the fleet-#18 gap this ticket closes), and carries no
#      placeholder / project-name leaks.
#   B. Behavior — a hermetic temp git repo with a STUBBED regenerator + a FAKE
#      `npx` on PATH exercises the helper's decision logic: trigger surface,
#      INDEX self-trigger exclusion, tsx fail-open, regen-error fail-open, and
#      the idempotent no-op path (no last_reviewed churn, no auto-stage).
#
# The stub/fake design keeps this portable — the plugin monorepo ships neither
# tsx nor gray-matter, so the REAL end-to-end regen is exercised by consumer
# dogfood (fleet #18 precedent), not here. This harness proves the helper's own
# contract deterministically.
#
# Bash 3.2 compatible (macOS default). Stdlib only. No bats-core dep.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER="$PLUGIN_ROOT/templates/scripts/precommit-flow-index.sh"

# ── Counters ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# ── Scratch + cleanup ────────────────────────────────────────────────
SCRATCH_ROOT="$(mktemp -d -t flow-bc-16783.XXXXXX)"
cleanup() { rm -rf "$SCRATCH_ROOT"; }
trap cleanup EXIT

# Capture stdout / stderr / exit of a command into globals STDOUT/STDERR/EXIT.
run_capture() {
  local stderr_file
  stderr_file="$(mktemp -t flow-stderr.XXXXXX)"
  set +e
  STDOUT="$("$@" 2>"$stderr_file")"
  EXIT=$?
  set -e
  STDERR="$(cat "$stderr_file")"
  rm -f "$stderr_file"
}

# Build a hermetic FDA-shaped git repo whose INDEX.md initial content is
# "OLD INDEX". Emits the repo path.
new_repo() {
  local d
  d="$(mktemp -d "$SCRATCH_ROOT/repo.XXXXXX")"
  mkdir -p "$d/docs/product/flows/DEMO" "$d/scripts" "$d/.fakebin" "$d/src"
  printf '### DEMO — Demo (1 flows)\n\n| DEMO-01 | flow |\n' > "$d/docs/product/master-flow-inventory.md"
  printf -- '---\nflow_id: DEMO-01\ndomain: DEMO\nstatus: NOT_STARTED\n---\n# DEMO-01: Demo flow\n' > "$d/docs/product/flows/DEMO/DEMO-01.md"
  printf 'OLD INDEX\n' > "$d/docs/product/flows/INDEX.md"
  git -C "$d" init -q
  git -C "$d" config user.email "bc16783@test.local"
  git -C "$d" config user.name "bc16783 test"
  git -C "$d" add -A
  git -C "$d" commit -q -m "init"
  echo "$d"
}

# Stub regenerator: touches a sentinel (.regen-ran) then behaves per $1:
#   change → rewrite INDEX with new content; noop → rewrite identical content;
#   fail   → exit 2 without writing.
mk_stub_regen() {
  local repo="$1" mode="$2"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'touch .regen-ran\n'
    case "$mode" in
      change) printf "printf 'NEW INDEX\\\\n' > docs/product/flows/INDEX.md\n" ;;
      noop)   printf "printf 'OLD INDEX\\\\n' > docs/product/flows/INDEX.md\n" ;;
      fail)   printf 'exit 2\n' ;;
    esac
    printf 'exit 0\n'
  } > "$repo/scripts/regenerate-flow-index.sh"
  chmod +x "$repo/scripts/regenerate-flow-index.sh"
}

# Fake npx controlling the `npx --no-install tsx --version` probe: exit $2.
mk_fake_npx() {
  local repo="$1" code="$2"
  printf '#!/usr/bin/env bash\nexit %s\n' "$code" > "$repo/.fakebin/npx"
  chmod +x "$repo/.fakebin/npx"
}

# Run the helper inside $1 with the fake bin ahead on PATH.
run_helper() {
  local repo="$1" saved_path="$PATH" saved_pwd="$PWD"
  cd "$repo"
  PATH="$repo/.fakebin:$PATH"
  run_capture bash "$HELPER"
  PATH="$saved_path"
  cd "$saved_pwd"
}

staged_has_index() { # 0 if INDEX.md is in the staged set
  git -C "$1" diff --cached --name-only | grep -q '^docs/product/flows/INDEX.md$'
}

# ══════════════════════════════════════════════════════════════════════
# Section A — fidelity of the shipped template
# ══════════════════════════════════════════════════════════════════════
section "A" "helper template fidelity"

if [ -f "$HELPER" ]; then
  pass "templates/scripts/precommit-flow-index.sh exists"
  head -1 "$HELPER" | grep -q '^#!/usr/bin/env bash$' \
    && pass "has bash shebang" || fail "missing '#!/usr/bin/env bash' shebang"
  grep -q 'regenerate-flow-index.sh' "$HELPER" \
    && pass "calls deterministic regenerate-flow-index.sh" \
    || fail "does not call regenerate-flow-index.sh (must NOT use the flow-regen-index skill)"
  ! grep -q 'flow-regen-index' "$HELPER" \
    && pass "does not reach for the flow-regen-index skill" \
    || fail "references the flow-regen-index skill — must call the deterministic script"
  # Target the escaped-dot regex form (master-flow-inventory\.md) — it appears ONLY
  # in the trigger regex, never in prose comments, so a comment cannot satisfy it.
  grep -qF 'master-flow-inventory\.md' "$HELPER" \
    && pass "trigger REGEX covers master-flow-inventory.md (closes the fleet-#18 gap)" \
    || fail "trigger regex does not include master-flow-inventory\\.md — inventory edits would be missed (requirement #1)"
  grep -q 'docs/product/flows' "$HELPER" \
    && pass "trigger covers docs/product/flows story docs" \
    || fail "helper does not reference docs/product/flows"
  grep -q -- '--no-install' "$HELPER" \
    && pass "guards tsx with npx --no-install (fail-open)" \
    || fail "helper does not guard tsx availability with --no-install"
  ! grep -qE '<[A-Z_]+>' "$HELPER" \
    && pass "no <PLACEHOLDER> tokens (copied verbatim, no sed pass)" \
    || fail "helper carries <PLACEHOLDER> tokens"
else
  fail "templates/scripts/precommit-flow-index.sh does NOT exist"
fi

# ══════════════════════════════════════════════════════════════════════
# Section B — behavior (hermetic temp repos)
# ══════════════════════════════════════════════════════════════════════

# B1 — staged STORY doc triggers regen: INDEX regenerated + auto-staged, exit 0.
section "B1" "staged story doc → regen + auto-stage"
R="$(new_repo)"; mk_stub_regen "$R" change; mk_fake_npx "$R" 0
printf -- '---\nflow_id: DEMO-02\ndomain: DEMO\nstatus: IN_PROGRESS\n---\n# DEMO-02: Second\n' > "$R/docs/product/flows/DEMO/DEMO-02.md"
git -C "$R" add docs/product/flows/DEMO/DEMO-02.md
run_helper "$R"
if [ "${EXIT}" -eq 0 ] && [ -f "$R/.regen-ran" ] && staged_has_index "$R" \
   && printf '%s' "$STDOUT" | grep -qi 'regenerat'; then
  pass "story-doc change regenerates + stages INDEX (exit 0, notice printed)"
else
  fail "story-doc: EXIT=$EXIT regen_ran=$([ -f "$R/.regen-ran" ] && echo y || echo n) staged=$(staged_has_index "$R" && echo y || echo n) stdout='${STDOUT}'"
fi

# B2 — staged INVENTORY triggers regen (the fleet-#18 gap). REQUIREMENT #1.
section "B2" "staged master-flow-inventory.md → regen fires"
R="$(new_repo)"; mk_stub_regen "$R" change; mk_fake_npx "$R" 0
printf '### DEMO — Demo (1 flows)\n### AUTH — Auth (0 flows)\n' > "$R/docs/product/master-flow-inventory.md"
git -C "$R" add docs/product/master-flow-inventory.md
run_helper "$R"
if [ "${EXIT}" -eq 0 ] && [ -f "$R/.regen-ran" ] && staged_has_index "$R"; then
  pass "inventory change fires regen + stages INDEX (requirement #1)"
else
  fail "inventory: EXIT=$EXIT regen_ran=$([ -f "$R/.regen-ran" ] && echo y || echo n) staged=$(staged_has_index "$R" && echo y || echo n)"
fi

# B3 — unrelated staged file → NO regen.
section "B3" "unrelated staged file → no regen"
R="$(new_repo)"; mk_stub_regen "$R" change; mk_fake_npx "$R" 0
printf 'export const x = 1;\n' > "$R/src/foo.ts"
git -C "$R" add src/foo.ts
run_helper "$R"
if [ "${EXIT}" -eq 0 ] && [ ! -f "$R/.regen-ran" ] && ! staged_has_index "$R"; then
  pass "unrelated file does not trigger regen"
else
  fail "unrelated: EXIT=$EXIT regen_ran=$([ -f "$R/.regen-ran" ] && echo y || echo n) staged=$(staged_has_index "$R" && echo y || echo n)"
fi

# B4 — staging ONLY INDEX.md must NOT self-trigger.
section "B4" "INDEX.md-only staged → no self-trigger"
R="$(new_repo)"; mk_stub_regen "$R" change; mk_fake_npx "$R" 0
printf 'hand-edited\n' > "$R/docs/product/flows/INDEX.md"
git -C "$R" add docs/product/flows/INDEX.md
run_helper "$R"
if [ "${EXIT}" -eq 0 ] && [ ! -f "$R/.regen-ran" ]; then
  pass "editing INDEX.md alone does not fire regen (no self-retrigger)"
else
  fail "INDEX-only: EXIT=$EXIT regen_ran=$([ -f "$R/.regen-ran" ] && echo y || echo n)"
fi

# B5 — no tsx → fail-open (warn, exit 0, no regen, commit proceeds).
section "B5" "tsx unavailable → fail-open"
R="$(new_repo)"; mk_stub_regen "$R" change; mk_fake_npx "$R" 1
printf -- '---\nflow_id: DEMO-02\ndomain: DEMO\nstatus: IN_PROGRESS\n---\n# DEMO-02: Second\n' > "$R/docs/product/flows/DEMO/DEMO-02.md"
git -C "$R" add docs/product/flows/DEMO/DEMO-02.md
run_helper "$R"
if [ "${EXIT}" -eq 0 ] && [ ! -f "$R/.regen-ran" ] && printf '%s' "$STDERR" | grep -qi 'tsx'; then
  pass "missing tsx warns + exits 0 without regenerating (fail-open)"
else
  fail "no-tsx: EXIT=$EXIT regen_ran=$([ -f "$R/.regen-ran" ] && echo y || echo n) stderr='${STDERR}'"
fi

# B6 — idempotent no-op: regen writes identical INDEX → no stage, no notice.
section "B6" "no-op regen → no auto-stage, no last_reviewed churn"
R="$(new_repo)"; mk_stub_regen "$R" noop; mk_fake_npx "$R" 0
printf -- '---\nflow_id: DEMO-02\ndomain: DEMO\nstatus: IN_PROGRESS\n---\n# DEMO-02: Second\n' > "$R/docs/product/flows/DEMO/DEMO-02.md"
git -C "$R" add docs/product/flows/DEMO/DEMO-02.md
run_helper "$R"
if [ "${EXIT}" -eq 0 ] && [ -f "$R/.regen-ran" ] && ! staged_has_index "$R" \
   && ! printf '%s' "$STDOUT" | grep -qi 'regenerat'; then
  pass "identical regen output does not stage INDEX or print a notice (no churn)"
else
  fail "no-op: EXIT=$EXIT regen_ran=$([ -f "$R/.regen-ran" ] && echo y || echo n) staged=$(staged_has_index "$R" && echo y || echo n) stdout='${STDOUT}'"
fi

# B7 — regen errors → fail-open (warn, exit 0, no stage, commit proceeds).
section "B7" "regen failure → fail-open"
R="$(new_repo)"; mk_stub_regen "$R" fail; mk_fake_npx "$R" 0
printf -- '---\nflow_id: DEMO-02\ndomain: DEMO\nstatus: IN_PROGRESS\n---\n# DEMO-02: Second\n' > "$R/docs/product/flows/DEMO/DEMO-02.md"
git -C "$R" add docs/product/flows/DEMO/DEMO-02.md
run_helper "$R"
if [ "${EXIT}" -eq 0 ] && ! staged_has_index "$R" && [ -n "$STDERR" ]; then
  pass "regen error warns + exits 0 without staging (CI is the backstop)"
else
  fail "regen-fail: EXIT=$EXIT staged=$(staged_has_index "$R" && echo y || echo n) stderr='${STDERR}'"
fi

# ── Summary ───────────────────────────────────────────────────────────
printf '\n'
printf '─────────────────────────────────────────────\n'
printf 'RESULT pass=%d fail=%d total=%d\n' "$PASS" "$FAIL" $((PASS + FAIL))
printf '─────────────────────────────────────────────\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
