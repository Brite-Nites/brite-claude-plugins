#!/usr/bin/env bash
# Self-test for scripts/_lib/lint_cross_pr_adr_numbers.py (BC-12698).
#
# lint_cross_pr_adr_numbers.py is the DETERMINISTIC CORE of the cross-PR ADR-number
# collision guard. The WITHIN-repo guard (lint_adr_numbers.py, BC-12617) catches a
# duplicate ADR number within ONE PR's tree and post-merge on `main` (and vs-main
# at PR time, via the merge-ref tree scan). It does NOT catch two concurrently-open
# PRs that each git-ADD the same NNN with DIFFERENT slugs before either merges —
# the residual cross-PR-pre-merge window. This core closes it: given THIS PR's
# added ADR filenames + the added filenames of the other OPEN PRs (gathered by the
# thin `gh` adapter scripts/ci/cross-pr-adr-guard.sh, which is NOT exercised here),
# it reports any number this PR reuses, naming the colliding PR. The job is
# advisory; the core honestly exits 1 on a collision.
#
# The live `gh` data is non-deterministic, so the JOB can't be fixture-tested — but
# the CORE (data-in → collisions-out) can, and is, here. The fixtures are the spec.
# Every FAIL fixture proves the core goes RED on the specific regression it guards,
# and the rc check is EXACT (1 = collision, 2 = bad input) so a TypeError/crash
# (also non-zero) can't false-green a broken path.
#
# Usage:
#   bash scripts/_lib/test_lint_cross_pr_adr_numbers.sh
#   bash scripts/_lib/test_lint_cross_pr_adr_numbers.sh /path/to/lint_cross_pr_adr_numbers.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the FAIL fixtures.

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
# A GITHUB_STEP_SUMMARY inherited from a CI run would make the --github fixtures
# append to the real job summary instead of the fixture's temp file. Drop it; each
# --github fixture sets its own.
unset GITHUB_STEP_SUMMARY

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="${1:-$HERE/lint_cross_pr_adr_numbers.py}"
SHARED="$HERE/adr_numbers.py"
WITHIN="$HERE/lint_adr_numbers.py"

# Precondition: the core must EXIST and PARSE before any fixture runs. A missing /
# renamed core makes run_core return rc=2 + "can't open file" for every fixture —
# most assertions go RED, but the negative ones (the no-traceback grep, the bare
# rc==2 checks) would false-PASS. Fail fast and unambiguously (BC-12589: a check
# that can't RUN must FAIL, not silently pass).
[ -f "$CORE" ] || { printf 'FAIL: core not found at %s\n' "$CORE" >&2; exit 2; }
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$CORE" 2>/dev/null \
  || { printf 'FAIL: %s does not parse as Python\n' "$CORE" >&2; exit 2; }
[ -f "$SHARED" ] || { printf 'FAIL: shared adr_numbers.py not found at %s\n' "$SHARED" >&2; exit 2; }

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

BOX="$(mktemp -d)"
trap 'rm -rf "$BOX"' EXIT

# Run the core with the given args; echo "<rc>|<stderr+stdout>".
run_core() {
  local out rc
  out="$(python3 "$CORE" "$@" 2>&1)"; rc=$?
  printf '%s|%s' "$rc" "$out"
}

# Write a JSON model file and echo its path. Args: <name> <json>.
mkjson() {
  local path="$BOX/$1"; shift
  printf '%s\n' "$1" > "$path"
  printf '%s' "$path"
}

# ── (1) NO COLLISION (golden tracer) → PASS. self claims a number no other open
#        PR claims; --github leaves an OK trace and NO ::warning. ──────────────────
j1="$(mkjson clean.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["029-new.md"]},
  "others": [{"pr": 455, "url": "https://x/pull/455", "added": ["030-a.md"]},
             {"pr": 456, "url": "https://x/pull/456", "added": ["031-b.md"]}]
}')"
r1="$(run_core "$j1")"
if [ "${r1%%|*}" -eq 0 ]; then ok; else bad "(1) no-collision expected PASS, got rc=${r1%%|*}: ${r1#*|}"; fi
# --github on a clean run: an OK summary line, but NO annotation (no cry-wolf).
sum1="$BOX/sum1.md"; : > "$sum1"
g1out="$(GITHUB_STEP_SUMMARY="$sum1" python3 "$CORE" --github "$j1" 2>&1)"; g1rc=$?
if [ "$g1rc" -eq 0 ]; then ok; else bad "(1) --github clean expected rc=0, got $g1rc: $g1out"; fi
if printf '%s' "$g1out" | grep -q '::warning'; then bad "(1) clean run must NOT emit a ::warning annotation: $g1out"; else ok; fi

# ── (2) SINGLE COLLISION, same zero-pad → FAIL naming number, BOTH PRs, BOTH
#        files. The core's reason-for-existing. ─────────────────────────────────
j2="$(mkjson single.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["021-foo.md"]},
  "others": [{"pr": 455, "url": "https://x/pull/455", "added": ["021-bar.md"]}]
}')"
r2="$(run_core "$j2")"; b2="${r2#*|}"
if [ "${r2%%|*}" -eq 1 ]; then ok; else bad "(2) single-collision expected rc=1, got ${r2%%|*}: $b2"; fi
if printf '%s' "$b2" | grep -qE 'number 21\b'; then ok; else bad "(2) should name number 21: $b2"; fi
if printf '%s' "$b2" | grep -q '460'; then ok; else bad "(2) should name this PR 460: $b2"; fi
if printf '%s' "$b2" | grep -q '455'; then ok; else bad "(2) should name colliding PR 455: $b2"; fi
if printf '%s' "$b2" | grep -q '021-foo.md' && printf '%s' "$b2" | grep -q '021-bar.md'; then ok; else bad "(2) should name both files: $b2"; fi
# No traceback on the collision path (a mutant that finds it but raises mid-report).
if printf '%s' "$b2" | grep -qi 'traceback'; then bad "(2) collision must not print a python traceback: $b2"; else ok; fi

# ── (3) CROSS-PR ZERO-PAD COLLISION 021 (this PR) vs 21 (other) → FAIL. The
#        load-bearing case: int()-normalize must hold ACROSS the PR boundary, via
#        the SHARED adr_number. A string-keyed core sees "021" != "21" and
#        false-GREENs here. This is the cross-PR analogue of BC-12617 fixture (3).
j3="$(mkjson zeropad.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["021-foo.md"]},
  "others": [{"pr": 455, "url": "https://x/pull/455", "added": ["21-bar.md"]}]
}')"
r3="$(run_core "$j3")"; b3="${r3#*|}"
if [ "${r3%%|*}" -eq 1 ]; then ok; else bad "(3) cross-PR zero-pad expected rc=1 (shared int-normalize load-bearing), got ${r3%%|*}: $b3"; fi
if printf '%s' "$b3" | grep -qE 'number 21\b'; then ok; else bad "(3) should name number 21: $b3"; fi
if printf '%s' "$b3" | grep -q '021-foo.md' && printf '%s' "$b3" | grep -q '21-bar.md'; then ok; else bad "(3) should name both 021-foo.md and 21-bar.md: $b3"; fi

# ── (4) SELF-EXCLUSION — `others` contains an entry whose pr == self.pr (the
#        adapter SHOULD drop it; the core DEFENDS). A self-entry sharing self's
#        own number must NOT count as a collision. Real other (#455) claims a
#        different number → overall PASS. ─────────────────────────────────────
j4="$(mkjson selfdup.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["021-foo.md"]},
  "others": [{"pr": 460, "url": "https://x/pull/460", "added": ["021-foo.md"]},
             {"pr": 455, "url": "https://x/pull/455", "added": ["099-z.md"]}]
}')"
r4="$(run_core "$j4")"
if [ "${r4%%|*}" -eq 0 ]; then ok; else bad "(4) self-entry in others must be ignored (expected PASS), got rc=${r4%%|*}: ${r4#*|}"; fi

# ── (5) MULTI-PR COLLISION — the SAME number claimed by self AND two other PRs
#        (one zero-padded) → FAIL naming BOTH #455 and #456. Proves every
#        colliding PR is reported, not just the first. ────────────────────────
# others are listed DESCENDING (#456 before #455) so the ordering assertion below
# can actually distinguish a real sort from raw insertion order.
j5="$(mkjson multipr.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["021-foo.md"]},
  "others": [{"pr": 456, "url": "https://x/pull/456", "added": ["21-b.md"]},
             {"pr": 455, "url": "https://x/pull/455", "added": ["021-a.md"]}]
}')"
r5="$(run_core "$j5")"; b5="${r5#*|}"
if [ "${r5%%|*}" -eq 1 ]; then ok; else bad "(5) multi-PR collision expected rc=1, got ${r5%%|*}: $b5"; fi
for pr in 455 456; do
  if printf '%s' "$b5" | grep -q "$pr"; then ok; else bad "(5) should name colliding PR $pr: $b5"; fi
done
# Deterministic ORDER: #455 before #456 (the core sorts PRs by _sortkey) EVEN THOUGH
# the input lists #456 first. A mutant that drops the sort emits dict-insertion
# order (#456 first) and is caught here.
l5a="$(printf '%s\n' "$b5" | grep -n 'PR #455' | head -1 | cut -d: -f1)"
l5b="$(printf '%s\n' "$b5" | grep -n 'PR #456' | head -1 | cut -d: -f1)"
if [ -n "$l5a" ] && [ -n "$l5b" ] && [ "$l5a" -lt "$l5b" ]; then ok; else bad "(5) PRs must be ordered #455 before #456 (deterministic): $b5"; fi

# ── (6) MULTIPLE DISTINCT COLLISIONS + a one-sided number → report 21 (vs #455)
#        and 22 (vs #456), but NOT 23 (claimed only by #455, not by self). Proves
#        only self∩other is reported and several numbers are handled. ──────────
j6="$(mkjson multinum.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["021-foo.md", "022-bar.md"]},
  "others": [{"pr": 455, "url": "https://x/pull/455", "added": ["021-x.md", "023-y.md"]},
             {"pr": 456, "url": "https://x/pull/456", "added": ["022-z.md"]}]
}')"
r6="$(run_core "$j6")"; b6="${r6#*|}"
if [ "${r6%%|*}" -eq 1 ]; then ok; else bad "(6) multi-number collision expected rc=1, got ${r6%%|*}: $b6"; fi
if printf '%s' "$b6" | grep -qE 'number 21\b'; then ok; else bad "(6) should name number 21: $b6"; fi
if printf '%s' "$b6" | grep -qE 'number 22\b'; then ok; else bad "(6) should name number 22: $b6"; fi
if printf '%s' "$b6" | grep -qE 'number 23\b'; then bad "(6) must NOT flag number 23 (only the other PR claims it, not self): $b6"; else ok; fi
# Deterministic ORDER: number 21 before 22 (sorted(collisions)). Pins diff-stable
# output — a dropped sort() would not be caught by the presence-only greps above.
l6a="$(printf '%s\n' "$b6" | grep -n 'number 21:' | head -1 | cut -d: -f1)"
l6b="$(printf '%s\n' "$b6" | grep -n 'number 22:' | head -1 | cut -d: -f1)"
if [ -n "$l6a" ] && [ -n "$l6b" ] && [ "$l6a" -lt "$l6b" ]; then ok; else bad "(6) numbers must be ordered 21 before 22 (deterministic sorted): $b6"; fi

# ── (7) NON-ADR + EMPTY added IGNORED → PASS. self adds only non-ADR names; a
#        second model with self.added == [] → both vacuously pass (no number to
#        collide). ─────────────────────────────────────────────────────────────
j7="$(mkjson nonadr.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["README.md", "099.md", "021-.md"]},
  "others": [{"pr": 455, "url": "https://x/pull/455", "added": ["021-real.md"]}]
}')"
r7="$(run_core "$j7")"
if [ "${r7%%|*}" -eq 0 ]; then ok; else bad "(7) non-ADR self names must be ignored (expected PASS), got rc=${r7%%|*}: ${r7#*|}"; fi
j7b="$(mkjson empty.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": []},
  "others": [{"pr": 455, "url": "https://x/pull/455", "added": ["021-real.md"]}]
}')"
r7b="$(run_core "$j7b")"
if [ "${r7b%%|*}" -eq 0 ]; then ok; else bad "(7b) empty self.added must vacuously PASS, got rc=${r7b%%|*}: ${r7b#*|}"; fi

# ── (8) FULL-PATH ENTRIES — `added` carries repo-relative paths (what the gh
#        files API returns). The core must extract the BASENAME for the number and
#        still collide, displaying the full path for a useful annotation file=. ─
j8="$(mkjson fullpath.json '{
  "self":   {"pr": 460, "url": "https://x/pull/460", "added": ["docs/decisions/021-foo.md"]},
  "others": [{"pr": 455, "url": "https://x/pull/455", "added": ["docs/decisions/021-bar.md"]}]
}')"
r8="$(run_core "$j8")"; b8="${r8#*|}"
if [ "${r8%%|*}" -eq 1 ]; then ok; else bad "(8) full-path entries expected rc=1 (basename extraction), got ${r8%%|*}: $b8"; fi
if printf '%s' "$b8" | grep -q 'docs/decisions/021-foo.md'; then ok; else bad "(8) should display the full self path: $b8"; fi

# ── (9) --github VISIBILITY (load-bearing per the advisory-or-cry-wolf rule). On a
#        collision: stdout carries a ::warning annotation naming the number; the
#        $GITHUB_STEP_SUMMARY file gets a markdown table naming the number + other
#        PR. Both are mutation-locked here, NOT just the collision math. ─────────
sum9="$BOX/sum9.md"; : > "$sum9"
g9out="$(GITHUB_STEP_SUMMARY="$sum9" python3 "$CORE" --github "$j2" 2>&1)"; g9rc=$?
if [ "$g9rc" -eq 1 ]; then ok; else bad "(9) --github collision expected rc=1, got $g9rc: $g9out"; fi
if printf '%s' "$g9out" | grep -q '::warning'; then ok; else bad "(9) --github must emit a ::warning annotation on collision: $g9out"; fi
if printf '%s' "$g9out" | grep -qE 'number 21\b'; then ok; else bad "(9) the annotation must name number 21: $g9out"; fi
# Row-anchored, not loose substrings: the number cell must literally be 21 (not 21
# matched inside 021-bar.md), and the PR cell must be a markdown link to #455 (not
# 455 matched inside the URL). A blanked number column or a link-only PR cell would
# false-pass a bare `grep -q '21'`/`grep -q '455'`.
if grep -qE '^\| *21 *\|' "$sum9"; then ok; else bad "(9) step-summary number cell must be 21: $(cat "$sum9")"; fi
if grep -qE '\| *\[#455\]\(' "$sum9"; then ok; else bad "(9) step-summary PR cell must link #455: $(cat "$sum9")"; fi
if grep -qiE '\| *ADR number|collision' "$sum9"; then ok; else bad "(9) step-summary should be a titled collision table: $(cat "$sum9")"; fi
# Default (no --github) must NOT leak annotation syntax into the plain report.
if printf '%s' "$b2" | grep -q '::warning'; then bad "(9) default report must not contain ::warning (gate it behind --github): $b2"; else ok; fi

# ── (10) MALFORMED INPUT → rc=2, DISTINCT from a collision (rc=1), with a reason
#         (not a bare code, not a traceback). Three shapes: non-JSON, missing
#         'self', 'others' not a list. ──────────────────────────────────────────
jbad="$(mkjson bad.json 'this is not json {')"
rb="$(run_core "$jbad")"; bb="${rb#*|}"
if [ "${rb%%|*}" -eq 2 ]; then ok; else bad "(10a) non-JSON should be rc=2, got ${rb%%|*}: $bb"; fi
if printf '%s' "$bb" | grep -qiE 'json|parse|malformed|invalid'; then ok; else bad "(10a) rc=2 must explain the parse failure: $bb"; fi
if printf '%s' "$bb" | grep -qi 'traceback'; then bad "(10a) bad input must not dump a python traceback: $bb"; else ok; fi
jmiss="$(mkjson missing.json '{"others": []}')"
rm2="$(run_core "$jmiss")"
if [ "${rm2%%|*}" -eq 2 ]; then ok; else bad "(10b) missing 'self' should be rc=2, got ${rm2%%|*}: ${rm2#*|}"; fi
if printf '%s' "${rm2#*|}" | grep -qi 'self'; then ok; else bad "(10b) rc=2 must name the missing 'self' key: ${rm2#*|}"; fi
jolist="$(mkjson otherslist.json '{"self": {"pr": 1, "added": []}, "others": "nope"}')"
ro="$(run_core "$jolist")"; bo="${ro#*|}"
if [ "${ro%%|*}" -eq 2 ]; then ok; else bad "(10c) 'others' not a list should be rc=2, got ${ro%%|*}: $bo"; fi
# Symmetric with (10a)/(10b): bind rc=2 to THIS cause (name 'others'), no traceback.
if printf '%s' "$bo" | grep -qi 'others'; then ok; else bad "(10c) rc=2 must name the 'others' key: $bo"; fi
if printf '%s' "$bo" | grep -qi 'traceback'; then bad "(10c) bad input must not dump a python traceback: $bo"; else ok; fi

# ── (11) SELF-EXCLUSION across a pr TYPE skew — self.pr is int 460, the self-entry
#         in `others` carries pr "460" (string, a shape gh JSON can yield). The
#         core's str(opr)==str(self_pr) coercion must STILL exclude it, so the only
#         real other (#455, different number) leaves it PASS. Pins the coercion: a
#         bare opr==self_pr would treat "460"!=460 and false-report a collision. ──
j12="$(mkjson selfstr.json '{
  "self":   {"pr": 460, "url": "u", "added": ["021-foo.md"]},
  "others": [{"pr": "460", "url": "u", "added": ["021-foo.md"]},
             {"pr": 455, "url": "u", "added": ["099-z.md"]}]
}')"
r12="$(run_core "$j12")"
if [ "${r12%%|*}" -eq 0 ]; then ok; else bad "(11) string-vs-int self pr must still self-exclude (PASS), got rc=${r12%%|*}: ${r12#*|}"; fi

# ── (12) --github on a collision with GITHUB_STEP_SUMMARY UNSET (a CI step with no
#         job summary) → still rc=1 + ::warning on stdout, no crash, summary just
#         skipped. Pins the _summary_fh()-is-None branch on the COLLISION path. ───
g13out="$(env -u GITHUB_STEP_SUMMARY python3 "$CORE" --github "$j2" 2>&1)"; g13rc=$?
if [ "$g13rc" -eq 1 ]; then ok; else bad "(12) --github w/o GITHUB_STEP_SUMMARY expected rc=1, got $g13rc: $g13out"; fi
if printf '%s' "$g13out" | grep -q '::warning'; then ok; else bad "(12) --github w/o summary must still annotate: $g13out"; fi
if printf '%s' "$g13out" | grep -qi 'traceback'; then bad "(12) must not crash when GITHUB_STEP_SUMMARY unset: $g13out"; else ok; fi

# ── (13) URL-LESS other PR on a collision (a gh race can drop a url) → no "(url)"
#         in the report, the table PR cell is plain #455 (no link), rc=1, no crash.
j14="$(mkjson nourl.json '{
  "self":   {"pr": 460, "url": "u", "added": ["021-foo.md"]},
  "others": [{"pr": 455, "added": ["021-bar.md"]}]
}')"
sum14="$BOX/sum14.md"; : > "$sum14"
g14out="$(GITHUB_STEP_SUMMARY="$sum14" python3 "$CORE" --github "$j14" 2>&1)"; g14rc=$?
if [ "$g14rc" -eq 1 ]; then ok; else bad "(13) url-less other expected rc=1, got $g14rc: $g14out"; fi
if printf '%s' "$g14out" | grep -q '455'; then ok; else bad "(13) should still name PR 455 without a url: $g14out"; fi
if grep -qE '\| *#455 *\|' "$sum14"; then ok; else bad "(13) url-less PR cell should be plain #455 (no link): $(cat "$sum14")"; fi

# ── (14) MARKDOWN-CELL ESCAPING (security hardening) — an attacker-controlled
#         other-PR filename with markdown metacharacters must be neutralised in the
#         summary table: a literal `|` (would forge a column) AND a `[` (would
#         render as a `[text](url)` hyperlink → open-redirect phishing in CI output
#         a maintainer could mistake for a real ADR link) are BOTH backslash-
#         escaped. (Newline/workflow-command injection is blocked upstream by the
#         adapter's line filter; the core escapes defensively because it is
#         independently invokable.) ─────────────────────────────────────────────
j15="$(mkjson pipe.json '{
  "self":   {"pr": 460, "url": "u", "added": ["021-foo.md"]},
  "others": [{"pr": 455, "url": "u", "added": ["021-ev|il[x](evil).md"]}]
}')"
sum15="$BOX/sum15.md"; : > "$sum15"
g15out="$(GITHUB_STEP_SUMMARY="$sum15" python3 "$CORE" --github "$j15" 2>&1)"; g15rc=$?
if [ "$g15rc" -eq 1 ]; then ok; else bad "(14) metachar-in-filename expected rc=1, got $g15rc: $g15out"; fi
if grep -F '021-ev\|il' "$sum15" >/dev/null; then ok; else bad "(14) a '|' in an untrusted filename must be escaped in the table cell: $(cat "$sum15")"; fi
if grep -F '\[x]' "$sum15" >/dev/null; then ok; else bad "(14) a '[' in an untrusted filename must be escaped (no live markdown link) in the table cell: $(cat "$sum15")"; fi

# ── (15) ORDER DETERMINISM — inputs in DESCENDING number order; the report must
#         still be ASCENDING (sorted), so a dropped sorted(collisions) (dict-
#         insertion order) is caught. Fixture (6)'s ascending input can't tell the
#         two apart; this one feeds 22 before 21 and asserts 21 prints first. ─────
j16="$(mkjson order.json '{
  "self":   {"pr": 460, "url": "u", "added": ["022-a.md", "021-b.md"]},
  "others": [{"pr": 455, "url": "u", "added": ["022-x.md", "021-y.md"]}]
}')"
r16="$(run_core "$j16")"; b16="${r16#*|}"
if [ "${r16%%|*}" -eq 1 ]; then ok; else bad "(15) descending-input collision expected rc=1, got ${r16%%|*}: $b16"; fi
o16a="$(printf '%s\n' "$b16" | grep -n 'number 21:' | head -1 | cut -d: -f1)"
o16b="$(printf '%s\n' "$b16" | grep -n 'number 22:' | head -1 | cut -d: -f1)"
if [ -n "$o16a" ] && [ -n "$o16b" ] && [ "$o16a" -lt "$o16b" ]; then ok; else bad "(15) report must be ascending-sorted even when input is descending: $b16"; fi

# ── (16) PARITY — both guards must REUSE the single shared filename→number rule
#         (adr_numbers.adr_number), never re-implement it (the BC-12594 byte-
#         identical-reuse lesson). Placed last as a meta/structural check. Three locks:
#         (a) SOURCE (consumer): the core imports adr_number and declares no ADR
#             regex of its own — necessary, but a NON-regex re-impl could evade the
#             grep, hence (b).
#         (b) BEHAVIORAL: drive the REAL core over an edge-case battery and assert
#             the set of numbers it collides on == the set the shared rule yields.
#             Runs the consumer end-to-end, implementation-agnostic — ANY drift
#             (dropped int-normalize, accepting 099.md, rejecting a valid name)
#             changes the set and goes RED. NOT tautological: the core's actual
#             output is compared to an INDEPENDENT oracle, not to itself.
#         (c) SOURCE (producer): the within-repo lint also imports the shared rule,
#             so producer and consumer are bound to the same module. ──────────────
if grep -qE 'from adr_numbers import|import adr_numbers' "$CORE"; then ok; else bad "(16a) core must import the shared adr_number, not re-implement it"; fi
if grep -qE 're\.compile\(.*\\d' "$CORE"; then bad "(16a) core must NOT declare its own ADR-number regex (drift risk) — import adr_number"; else ok; fi

# (b) self.added == others[0].added == the battery, so the core collides on EXACTLY
#     the distinct ADR numbers present. sort -u is LEXICAL, not numeric: a string-
#     keyed drift emits "021" AND "21" as separate numbers, which a numeric -u would
#     wrongly fold together — lexical keeps them distinct, so the mismatch is caught.
battery='["021-foo.md","21-bar.md","000-a.md","00-b.md","0-c.md","7-d.md","0007-e.md","README.md","099.md","021-.md","1234-big.md","notes.md"]'
j17="$(mkjson parity.json "{\"self\":{\"pr\":460,\"url\":\"u\",\"added\":$battery},\"others\":[{\"pr\":999,\"url\":\"u\",\"added\":$battery}]}")"
r17="$(run_core "$j17")"; b17="${r17#*|}"
if [ "${r17%%|*}" -eq 1 ]; then ok; else bad "(16b) battery should collide (rc=1), got ${r17%%|*}: $b17"; fi
core_nums="$(printf '%s\n' "$b17" | grep -oE 'number [0-9]+:' | grep -oE '[0-9]+' | sort -u | xargs)"
oracle_nums="$(cd "$HERE" && python3 -c '
import adr_numbers as a
b=["021-foo.md","21-bar.md","000-a.md","00-b.md","0-c.md","7-d.md","0007-e.md","README.md","099.md","021-.md","1234-big.md","notes.md"]
for n in {a.adr_number(f) for f in b if a.adr_number(f) is not None}:
    print(n)' | sort -u | xargs)"
if [ "$core_nums" = "$oracle_nums" ]; then ok; else bad "(16b) core extraction diverges from the shared rule: core='[$core_nums]' oracle='[$oracle_nums]'"; fi

# (c) producer side bound to the same module.
if grep -qE 'from adr_numbers import|import adr_numbers' "$WITHIN"; then ok; else bad "(16c) within-repo lint must import the shared adr_number too (producer↔consumer parity)"; fi
if grep -qE 're\.compile\(.*\\d' "$WITHIN"; then bad "(16c) within-repo lint must NOT declare its own ADR-number regex — import adr_number"; else ok; fi

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
