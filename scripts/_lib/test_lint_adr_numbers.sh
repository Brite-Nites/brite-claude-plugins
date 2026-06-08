#!/usr/bin/env bash
# Self-test for scripts/_lib/lint_adr_numbers.py (BC-12617).
#
# lint_adr_numbers.py is the ADR-number DUPLICATE guard. ADRs live at
# docs/decisions/NNN-slug.md and are numbered by reading the "next free number"
# off `main`; two concurrent branches read the same stale `main`, grab the SAME
# NNN with DIFFERENT slugs, and git never flags it (filenames differ) — so the 2nd
# merge SILENTLY creates a duplicate-numbered ADR. Happened 4× in one week. The
# guard groups docs/decisions files by their NORMALIZED leading integer and fails
# if any number maps to >1 file. It is DUPLICATE-detection only — gaps (004-006
# absent, 001 Withdrawn) are legitimate and never flagged.
#
# This harness drives the lint against synthetic FIXTURES covering the mutation
# matrix, asserting exit codes + violation reasons. The fixtures are the spec; the
# real ADR set (001-028, gaps at 004-006) is covered by the lint's no-arg
# real-tree run in validate.sh §15a-bc-12617.
#
# Usage:
#   bash scripts/_lib/test_lint_adr_numbers.sh
#   bash scripts/_lib/test_lint_adr_numbers.sh /path/to/lint_adr_numbers.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the FAIL fixtures.

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="${1:-$HERE/lint_adr_numbers.py}"

# Precondition: the lint must EXIST and PARSE before any fixture runs. A missing /
# renamed lint makes run_lint return rc=2 + "can't open file" for every fixture —
# most assertions go RED, but the negative ones ((5)'s no-traceback grep, (6)'s
# bare rc==2) would false-PASS. Fail fast and unambiguously instead (BC-12589: a
# check that can't RUN must FAIL, not silently pass).
[ -f "$LINT" ] || { printf 'FAIL: lint not found at %s\n' "$LINT" >&2; exit 2; }
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$LINT" 2>/dev/null \
  || { printf 'FAIL: %s does not parse as Python\n' "$LINT" >&2; exit 2; }

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

BOX="$(mktemp -d)"
trap 'rm -rf "$BOX"' EXIT

# Run the lint with the given args; echo "<rc>|<stderr+stdout>".
run_lint() {
  local out rc
  out="$(python3 "$LINT" "$@" 2>&1)"; rc=$?
  printf '%s|%s' "$rc" "$out"
}

# expect_pass <label> <lint-args...>  — lint must exit 0 (all numbers unique).
# Used by the GREEN fixtures (1)/(8). There is deliberately NO expect_fail helper:
# every FAIL fixture ((2)/(3)/(5)/(6)/(7)/(9)) needs fixture-specific assertions a
# single-<msg-regex> helper can't express — naming ALL colliding files, the
# no-traceback check, the rc=2-with-reason check — so they capture run_lint once
# and assert inline. The load-bearing rc check is EXACT (rc==1 for a clean
# duplicate, rc==2 for usage/IO): a TypeError/crash also exits non-zero, so
# asserting only "non-zero" would false-green a broken parse path.
expect_pass() {
  local label="$1"; shift
  local r; r="$(run_lint "$@")"
  if [ "${r%%|*}" -eq 0 ]; then ok; else bad "$label expected PASS, got rc=${r%%|*}: ${r#*|}"; fi
}

# Populate a fixture dir with empty-bodied ADR (and non-ADR) files by NAME.
mkfiles() {
  local dir="$1"; shift
  mkdir -p "$dir"
  local f
  for f in "$@"; do printf '# %s\n' "$f" > "$dir/$f"; done
}

# ── (1) ALL-UNIQUE, with legitimate gaps → PASS (the golden tracer). 007 skips
#        004-006 and 001 is "Withdrawn"-style — gaps must NOT be flagged. ────────
d1="$BOX/unique"
mkfiles "$d1" 001-alpha.md 002-beta.md 007-gamma.md 028-delta.md
expect_pass "(1) all-unique numbers, gaps allowed" "$d1"

# ── (2) DOUBLE COLLISION, same zero-pad → FAIL naming the number + BOTH files. ──
d2="$BOX/double"
mkfiles "$d2" 001-alpha.md 021-foo.md 021-bar.md
r2="$(run_lint "$d2")"
if [ "${r2%%|*}" -eq 1 ]; then ok; else bad "(2) double-collision expected rc=1, got ${r2%%|*}: ${r2#*|}"; fi
if printf '%s' "${r2#*|}" | grep -qE 'number 21 used by'; then ok; else bad "(2) should name number 21: ${r2#*|}"; fi
if printf '%s' "${r2#*|}" | grep -q '021-foo.md'; then ok; else bad "(2) should name 021-foo.md: ${r2#*|}"; fi
if printf '%s' "${r2#*|}" | grep -q '021-bar.md'; then ok; else bad "(2) should name 021-bar.md: ${r2#*|}"; fi

# ── (3) ZERO-PAD COLLISION 021 vs 21 → FAIL. int()-normalize is LOAD-BEARING: a
#        naive string-keyed lint sees "021" ≠ "21" and false-GREENs here, so this
#        fixture (rc must be 1) is the regression that pins the normalization. ───
d3="$BOX/zeropad"
mkfiles "$d3" 001-ok.md 021-foo.md 21-bar.md
r3="$(run_lint "$d3")"
if [ "${r3%%|*}" -eq 1 ]; then ok; else bad "(3) zero-pad collision expected rc=1 (int-normalize load-bearing), got ${r3%%|*}: ${r3#*|}"; fi
if printf '%s' "${r3#*|}" | grep -qE 'number 21 used by'; then ok; else bad "(3) should name number 21: ${r3#*|}"; fi
if printf '%s' "${r3#*|}" | grep -q '021-foo.md' && printf '%s' "${r3#*|}" | grep -q '21-bar.md'; then ok; else bad "(3) should name both 021-foo.md and 21-bar.md: ${r3#*|}"; fi

# ── (4) NON-ADR FILES IGNORED → PASS, and the ADR count reflects ONLY the two
#        real ADRs. Covers every ignore branch: README / non-numeric .md /
#        numeric-but-.txt / subdir, PLUS the regex's mandatory `-<slug>` shape —
#        `021-.md` (empty slug) and `099.md` (no hyphen) must NOT match. If the
#        regex were loosened to `^(\d+).*\.md$`, those two would start counting and
#        the count would shift off 2, so this also pins the `-.+` requirement. ────
d4="$BOX/ignore"
mkfiles "$d4" 001-alpha.md 002-beta.md README.md notes.md draft-thing.md 021-.md 099.md
printf 'numeric prefix but not markdown\n' > "$d4/021-foo.txt"   # .txt → ignored
mkdir -p "$d4/021-a-subdir"                                       # dir → ignored
r4="$(run_lint "$d4")"   # capture once, assert PASS + count off the same run
if [ "${r4%%|*}" -eq 0 ]; then ok; else bad "(4) non-ADR files ignored expected PASS, got rc=${r4%%|*}: ${r4#*|}"; fi
if printf '%s' "${r4#*|}" | grep -qE ' 2 ADR'; then ok; else bad "(4) should count exactly 2 ADRs (ignored files + non-slug shapes excluded): ${r4#*|}"; fi

# ── (5) DUPLICATE EXITS rc=1 *WITHOUT A TRACEBACK*. The no-traceback grep is the
#        LOAD-BEARING assertion here — it's the ONLY coverage (2)/(7) don't already
#        provide (they assert rc==1 too). It catches a mutant that finds the
#        duplicate but raises mid-report (rc=1 + traceback). Do NOT "simplify" this
#        fixture by dropping the second grep — that silently removes the only guard
#        on the raise-but-still-rc=1 path. ──────────────────────────────────────
d5="$BOX/cleanrc"
mkfiles "$d5" 005-a.md 005-b.md
r5="$(run_lint "$d5")"
if [ "${r5%%|*}" -eq 1 ]; then ok; else bad "(5) a duplicate must be rc=1, got ${r5%%|*}: ${r5#*|}"; fi
if printf '%s' "${r5#*|}" | grep -qi 'traceback'; then bad "(5) a duplicate must not print a python traceback: ${r5#*|}"; else ok; fi

# ── (6) USAGE/IO ERROR — a nonexistent decisions dir → rc=2, DISTINCT from a
#        duplicate (rc=1). The reason assertion binds rc=2 to *this* cause: a bare
#        `return 2` (or a missing/garbage lint → "can't open file" rc=2) would
#        satisfy an rc-only check, so grep the missing-dir message too. ──────────
r6="$(run_lint "$BOX/does-not-exist")"
if [ "${r6%%|*}" -eq 2 ]; then ok; else bad "(6) nonexistent dir should be rc=2, got ${r6%%|*}: ${r6#*|}"; fi
if printf '%s' "${r6#*|}" | grep -qiE 'not found|decisions dir'; then ok; else bad "(6) rc=2 must be FOR the missing dir (explain it), not a bare exit code: ${r6#*|}"; fi

# ── (7) TRIPLE COLLISION → FAIL naming ALL THREE files (not just the first two).
#        Proves the report lists every colliding file — the feature that makes the
#        renumber target obvious and saves the cascade. ─────────────────────────
d7="$BOX/triple"
mkfiles "$d7" 003-a.md 003-b.md 003-c.md 004-ok.md
r7="$(run_lint "$d7")"
if [ "${r7%%|*}" -eq 1 ]; then ok; else bad "(7) triple-collision expected rc=1, got ${r7%%|*}: ${r7#*|}"; fi
for f in 003-a.md 003-b.md 003-c.md; do
  if printf '%s' "${r7#*|}" | grep -q "$f"; then ok; else bad "(7) should name all three colliding files (missing $f): ${r7#*|}"; fi
done

# ── (8) EMPTY DECISIONS DIR → PASS (vacuously no duplicates; no loop-over-nothing
#        crash). ───────────────────────────────────────────────────────────────
d8="$BOX/empty"
mkdir -p "$d8"
expect_pass "(8) empty decisions dir" "$d8"

# ── (9) ZERO-FAMILY NORMALIZATION — 000 / 00 / 0 all normalize to int 0 and must
#        collide. This pins the int() contract at the leading-zero boundary (3)'s
#        021-vs-21 doesn't reach: a plausible `.lstrip('0')`-style normalization
#        would turn `000` into "" and mis-key (or treat 0 as falsy and skip it),
#        which int() does not. The distinct 001 must NOT be swept into the group. ─
d9="$BOX/zerofamily"
mkfiles "$d9" 000-zero.md 00-b.md 0-a.md 001-distinct.md
r9="$(run_lint "$d9")"
if [ "${r9%%|*}" -eq 1 ]; then ok; else bad "(9) zero-family collision expected rc=1, got ${r9%%|*}: ${r9#*|}"; fi
if printf '%s' "${r9#*|}" | grep -qE 'number 0 used by'; then ok; else bad "(9) should name number 0: ${r9#*|}"; fi
for f in 000-zero.md 00-b.md 0-a.md; do
  if printf '%s' "${r9#*|}" | grep -q "$f"; then ok; else bad "(9) should name all three zero-family files (missing $f): ${r9#*|}"; fi
done

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
