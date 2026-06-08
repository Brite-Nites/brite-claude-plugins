#!/usr/bin/env bash
# Self-test for scripts/_lib/lint_audit_roster_drift.py (BC-12640).
#
# lint_audit_roster_drift.py is the audit-invariant error-key roster DRIFT-GUARD.
# Per σ3 command it asserts three-way set-equality across:
#   1. the ADR-015 marker-delimited roster  (`command=<stem>` block)
#   2. the command's inline `{"error":"…"}` emits  (warnings excluded)
#   3. the command's error-catalog TABLE
# The command emits LEAD; the ADR roster + table FOLLOW. It would have auto-caught
# the BC-12594→BC-12623 "6 keys → 7" prose drift.
#
# This harness drives the lint against synthetic FIXTURES covering the mutation
# matrix, asserting exit codes + violation reasons. The fixtures are the spec.
# Fixtures use SYNTHETIC keys (aaa/bbb/…) so the harness locks the LOGIC; the real
# 7-key / 5-key catalogs are covered by the lint's real-tree run in validate.sh.
#
# Usage:
#   bash scripts/_lib/test_lint_audit_roster_drift.sh
#   bash scripts/_lib/test_lint_audit_roster_drift.sh /path/to/lint_audit_roster_drift.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the FAIL fixtures.

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="${1:-$HERE/lint_audit_roster_drift.py}"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

BOX="$(mktemp -d)"
trap 'rm -rf "$BOX"' EXIT

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# Run the lint with the given args; echo "<rc>|<stderr+stdout>".
run_lint() {
  local out rc
  out="$(python3 "$LINT" "$@" 2>&1)"; rc=$?
  printf '%s|%s' "$rc" "$out"
}

# expect_pass <label> <lint-args...>  — lint must exit 0 (in sync).
expect_pass() {
  local label="$1"; shift
  local r; r="$(run_lint "$@")"
  if [ "${r%%|*}" -eq 0 ]; then ok; else bad "$label expected PASS, got rc=${r%%|*}: ${r#*|}"; fi
}

# expect_fail <label> <msg-regex> <lint-args...>  — lint must exit EXACTLY 1 (a
# clean drift, NOT an rc=2 crash) AND the message must match <msg-regex>. The exact
# rc==1 check is load-bearing: a TypeError/crash also exits non-zero, so asserting
# only "non-zero" would false-green a broken parse path.
expect_fail() {
  local label="$1" rx="$2"; shift 2
  local r rc body; r="$(run_lint "$@")"; rc="${r%%|*}"; body="${r#*|}"
  if [ "$rc" -eq 1 ]; then ok; else bad "$label expected FAIL rc=1, got rc=$rc: $body"; fi
  if printf '%s' "$body" | grep -qiE "$rx"; then ok; else bad "$label message should match /$rx/: $body"; fi
}

# ── Fixture builders ──────────────────────────────────────────────────────────
# A bare-key (create-idiom) command: emits + an "Error path catalog" table whose
# data rows are `| `<key>` | … |`.  Args: <path> then key list.
cmd_bare() {
  local path="$1"; shift
  { printf '# %s\n\n' "$(basename "$path" .md)"
    for k in "$@"; do printf 'On failure emit `{"error":"%s","x":1}` exit 0.\n' "$k"; done
    printf '\n## Error path catalog (all exit 0)\n\n'
    printf '| `error` key | When | Recovery |\n|---|---|---|\n'
    for k in "$@"; do printf '| `%s` | when | recovery |\n' "$k"; done
  } | write "$path"
}

# A prefixed (update-idiom) command: emits + an "Error / warning path catalog"
# table whose data rows are `| `error: <key>` | … |`.  Args: <path> then key list.
cmd_prefixed() {
  local path="$1"; shift
  { printf '# %s\n\n' "$(basename "$path" .md)"
    for k in "$@"; do printf 'On failure emit `{"error":"%s"}` exit 0.\n' "$k"; done
    printf '\n## Error / warning path catalog (all exit 0)\n\n'
    printf '| key | When | Recovery |\n|---|---|---|\n'
    for k in "$@"; do printf '| `error: %s` | when | recovery |\n' "$k"; done
  } | write "$path"
}

# An ADR roster block.  Args: <command-stem> then key list. Emits to stdout.
adr_block() {
  local stem="$1"; shift
  printf '<!-- audit-invariant:error-roster command=%s -->\n' "$stem"
  for k in "$@"; do printf -- '- `%s`\n' "$k"; done
  printf '<!-- /audit-invariant:error-roster -->\n\n'
}

# ── (a) IN-SYNC, both idioms, two commands → PASS (the golden tracer) ──────────
da="$BOX/a"; mkdir -p "$da"
cmd_bare     "$da/alpha.md" aaa bbb ccc
cmd_prefixed "$da/beta.md"  aaa bbb ddd
{ adr_block alpha aaa bbb ccc; adr_block beta aaa bbb ddd; } > "$da/adr.md"
expect_pass "(a) in-sync, both idioms" --adr "$da/adr.md" "$da/alpha.md" "$da/beta.md"

# ── (b) command emits a key the ADR roster LACKS (≡ "add fake 8th key" / "remove
#        a key from the ADR roster") → FAIL ────────────────────────────────────
db="$BOX/b"; mkdir -p "$db"
cmd_bare "$db/alpha.md" aaa bbb ccc ddd   # emits ddd …
adr_block alpha aaa bbb ccc > "$db/adr.md"  # … but ADR roster lacks it (and table will too → also table FAIL)
expect_fail "(b) emit key absent from ADR" 'STALE.*missing from ADR roster' --adr "$db/adr.md" "$db/alpha.md"

# ── (c) ADR roster has a PHANTOM key the command never emits → FAIL ────────────
dc="$BOX/c"; mkdir -p "$dc"
cmd_bare "$dc/alpha.md" aaa bbb
adr_block alpha aaa bbb zzz > "$dc/adr.md"  # zzz is phantom
expect_fail "(c) phantom key in ADR" 'STALE.*in ADR roster but not emitted' --adr "$dc/adr.md" "$dc/alpha.md"

# ── (d) emits has a key the TABLE lacks (ADR in sync) → FAIL on table only ─────
dd="$BOX/d"; mkdir -p "$dd"
{ printf '# alpha\n\n'
  printf 'emit `{"error":"aaa"}`\nemit `{"error":"bbb"}`\n\n'
  printf '## Error path catalog (all exit 0)\n\n| `error` key | When | Recovery |\n|---|---|---|\n'
  printf '| `aaa` | w | r |\n'   # bbb emitted but NOT tabulated
} > "$dd/alpha.md"
adr_block alpha aaa bbb > "$dd/adr.md"
expect_fail "(d) emit absent from table" 'TABLE disagrees.*emitted but absent from table' --adr "$dd/adr.md" "$dd/alpha.md"

# ── (e) TABLE has a key the emits lack → FAIL on table ─────────────────────────
de="$BOX/e"; mkdir -p "$de"
{ printf '# alpha\n\nemit `{"error":"aaa"}`\n\n'
  printf '## Error path catalog (all exit 0)\n\n| `error` key | When | Recovery |\n|---|---|---|\n'
  printf '| `aaa` | w | r |\n| `bbb` | w | r |\n'   # bbb tabulated but never emitted
} > "$de/alpha.md"
adr_block alpha aaa > "$de/adr.md"
expect_fail "(e) table key not emitted" 'TABLE disagrees.*in table but not emitted' --adr "$de/adr.md" "$de/alpha.md"

# ── (f) WARNING-NOT-ERROR FILTER LOCK — a `"warning":"X"` emit must NOT count as
#        a roster key. Command emits errors {aaa,bbb} + warning {wwww}; ADR+table
#        list only the two errors → PASS. ───────────────────────────────────────
df="$BOX/f"; mkdir -p "$df"
{ printf '# beta\n\n'
  printf 'emit `{"error":"aaa"}`\nemit `{"error":"bbb"}`\nemit `{"warning":"wwww"}`\n\n'
  printf '## Error / warning path catalog (all exit 0)\n\n| key | When | Recovery |\n|---|---|---|\n'
  printf '| `error: aaa` | w | r |\n| `error: bbb` | w | r |\n| `warning: wwww` | w | r |\n'
} > "$df/beta.md"
adr_block beta aaa bbb > "$df/adr.md"
expect_pass "(f) warning not counted as error key" --adr "$df/adr.md" "$df/beta.md"

# ── (g) command file with NO matching ADR roster block → FAIL ──────────────────
dg="$BOX/g"; mkdir -p "$dg"
cmd_bare "$dg/alpha.md" aaa bbb
adr_block somethingelse aaa bbb > "$dg/adr.md"  # block exists, but not for `alpha`
expect_fail "(g) no roster block for command" 'no .*error-roster command=alpha.* block' --adr "$dg/adr.md" "$dg/alpha.md"

# ── (h) DANGLING ADR roster — a block for a command not among the linted files ─
dh="$BOX/h"; mkdir -p "$dh"
cmd_bare "$dh/alpha.md" aaa bbb
{ adr_block alpha aaa bbb; adr_block ghost aaa; } > "$dh/adr.md"  # `ghost` has no file
expect_fail "(h) dangling roster" 'command=ghost.* has no corresponding' --adr "$dh/adr.md" "$dh/alpha.md"

# ── (i) FIRST-SPAN PARSE — update's `error: invalid_status` (with `flag`
#        discriminator) row must yield `invalid_status`, NOT `flag`. If the parse
#        grabbed the 2nd span, `flag` would be an extra table key → FAIL. PASS
#        proves only the first span is read. ─────────────────────────────────────
di="$BOX/i"; mkdir -p "$di"
{ printf '# beta\n\nemit `{"error":"aaa"}`\nemit `{"error":"invalid_status"}`\n\n'
  printf '## Error / warning path catalog (all exit 0)\n\n| key | When | Recovery |\n|---|---|---|\n'
  printf '| `error: aaa` | w | r |\n'
  printf '| `error: invalid_status` (with `flag` discriminator) | w | r |\n'
} > "$di/beta.md"
adr_block beta aaa invalid_status > "$di/adr.md"
expect_pass "(i) first-span parse ignores flag discriminator" --adr "$di/adr.md" "$di/beta.md"

# ── (j) PER-COMMAND INDEPENDENCE — alpha in-sync, beta drifted → FAIL naming beta
#        only (alpha must not be reported). ─────────────────────────────────────
dj="$BOX/j"; mkdir -p "$dj"
cmd_bare     "$dj/alpha.md" aaa bbb
cmd_prefixed "$dj/beta.md"  aaa bbb ccc   # beta emits ccc …
{ adr_block alpha aaa bbb; adr_block beta aaa bbb; } > "$dj/adr.md"  # … ADR beta lacks ccc
rj="$(run_lint --adr "$dj/adr.md" "$dj/alpha.md" "$dj/beta.md")"
if [ "${rj%%|*}" -eq 1 ]; then ok; else bad "(j) expected FAIL rc=1, got ${rj%%|*}"; fi
if printf '%s' "${rj#*|}" | grep -q 'beta.md'; then ok; else bad "(j) should name beta.md: ${rj#*|}"; fi
if printf '%s' "${rj#*|}" | grep -q 'alpha.md'; then bad "(j) must NOT report in-sync alpha.md: ${rj#*|}"; else ok; fi

# ── (k) the headline issue mutation across BOTH commands at once: a fake extra key
#        in create's emits AND a different fake extra in update's emits → FAIL. ──
dk="$BOX/k"; mkdir -p "$dk"
cmd_bare     "$dk/alpha.md" aaa bbb ccc eee   # eee = fake 8th on create-idiom
cmd_prefixed "$dk/beta.md"  aaa bbb fff        # fff = fake 6th on update-idiom
{ adr_block alpha aaa bbb ccc; adr_block beta aaa bbb; } > "$dk/adr.md"
expect_fail "(k) fake extra key on both commands" 'eee|fff' --adr "$dk/adr.md" "$dk/alpha.md" "$dk/beta.md"

# ── (m) STANDALONE-MARKER RULE — a marker mentioned inside backtick PROSE (the
#        sibling-#3 `command=<name>` template) must NOT be parsed as a roster block
#        (no phantom `ghost` dangling-roster). PASS proves fullmatch-on-standalone.
dm="$BOX/m"; mkdir -p "$dm"
cmd_bare "$dm/alpha.md" aaa bbb
{ adr_block alpha aaa bbb
  printf 'A future sibling adds a `<!-- audit-invariant:error-roster command=ghost -->` block here.\n'
} > "$dm/adr.md"
expect_pass "(m) in-prose marker example is not a block" --adr "$dm/adr.md" "$dm/alpha.md"

# ── (l) clean rc — a missing ADR file is a usage/IO error (rc=2), NOT a drift ──
dl="$BOX/l"; mkdir -p "$dl"
cmd_bare "$dl/alpha.md" aaa
rl="$(run_lint --adr "$dl/does-not-exist.md" "$dl/alpha.md")"
if [ "${rl%%|*}" -eq 2 ]; then ok; else bad "(l) missing ADR should be rc=2, got ${rl%%|*}: ${rl#*|}"; fi

# ── (n) DIGIT-BEARING KEY IS VISIBLE — a key with a digit (e.g. `oauth2_err`) must
#        be extracted from all three surfaces, so a drift in it is CAUGHT. Command
#        emits {aaa, oauth2_err}; ADR roster lacks oauth2_err → FAIL. With the old
#        `[a-z_]+` class the digit key was silently dropped everywhere and the drift
#        passed unseen — this is the load-bearing fixture for that fix. ────────────
dn="$BOX/n"; mkdir -p "$dn"
cmd_bare "$dn/alpha.md" aaa oauth2_err
adr_block alpha aaa > "$dn/adr.md"
expect_fail "(n) digit-bearing key is visible to the guard" 'STALE.*oauth2_err' --adr "$dn/adr.md" "$dn/alpha.md"

# ── (n2) digit-bearing key, fully in sync across all three surfaces → PASS (no
#         false-positive from allowing digits). ─────────────────────────────────
dn2="$BOX/n2"; mkdir -p "$dn2"
cmd_bare "$dn2/alpha.md" aaa oauth2_err
adr_block alpha aaa oauth2_err > "$dn2/adr.md"
expect_pass "(n2) in-sync digit-bearing key" --adr "$dn2/adr.md" "$dn2/alpha.md"

# ── (o) PLACEHOLDER EXCLUSION — the live `{"error":"<kind>", ...}` soft-fail
#        contract template must NOT count as a key. Command emits the <kind>
#        template + real {aaa,bbb}; ADR+table list only the real keys → PASS. Guards
#        a careless `_KEY` widening that re-admits `<>` (emit-side analog of (f)). ─
do_="$BOX/o"; mkdir -p "$do_"
{ printf '# alpha\n\n'
  printf 'Soft-fail contract: every error path emits `{"error":"<kind>", ...}` exit 0.\n'
  printf 'emit `{"error":"aaa"}`\nemit `{"error":"bbb"}`\n\n'
  printf '## Error path catalog (all exit 0)\n\n| `error` key | When | Recovery |\n|---|---|---|\n'
  printf '| `aaa` | w | r |\n| `bbb` | w | r |\n'
} > "$do_/alpha.md"
adr_block alpha aaa bbb > "$do_/adr.md"
expect_pass "(o) <kind> placeholder template is not a key" --adr "$do_/adr.md" "$do_/alpha.md"

# ── (p) ROSTER-PROSE IGNORED — an explanatory sentence between the markers (with an
#        incidental backtick word) must NOT leak a phantom key. PASS proves the
#        list-item-only scoping. ─────────────────────────────────────────────────
dp="$BOX/p"; mkdir -p "$dp"
cmd_bare "$dp/alpha.md" aaa bbb
{ printf '<!-- audit-invariant:error-roster command=alpha -->\n'
  printf 'These keys are emitted on the `error` path (not the `warning` path):\n'
  printf -- '- `aaa`\n- `bbb`\n'
  printf '<!-- /audit-invariant:error-roster -->\n'
} > "$dp/adr.md"
expect_pass "(p) prose between roster markers does not leak phantom keys" --adr "$dp/adr.md" "$dp/alpha.md"

# ── (q) MALFORMED NESTING — a second roster block opens before the first closes →
#        structural FAIL (not a misleading set-mismatch). ─────────────────────────
dq="$BOX/q"; mkdir -p "$dq"
cmd_bare     "$dq/alpha.md" aaa bbb
cmd_prefixed "$dq/beta.md"  aaa ccc
{ printf '<!-- audit-invariant:error-roster command=alpha -->\n'
  printf -- '- `aaa`\n- `bbb`\n'
  printf '<!-- audit-invariant:error-roster command=beta -->\n'
  printf -- '- `aaa`\n- `ccc`\n'
  printf '<!-- /audit-invariant:error-roster -->\n'
} > "$dq/adr.md"
expect_fail "(q) nested roster block (missing close)" 'before .*was closed|never closed' --adr "$dq/adr.md" "$dq/alpha.md" "$dq/beta.md"

# ── (r) DUPLICATE BLOCK — two well-formed blocks for one command → structural FAIL.
dr="$BOX/r"; mkdir -p "$dr"
cmd_bare "$dr/alpha.md" aaa bbb
{ adr_block alpha aaa bbb; adr_block alpha aaa bbb; } > "$dr/adr.md"
expect_fail "(r) duplicate roster block for one command" 'duplicate .*command=alpha' --adr "$dr/adr.md" "$dr/alpha.md"

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
