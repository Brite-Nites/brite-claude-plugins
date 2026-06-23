#!/usr/bin/env bash
# BC-12303 vslice — the deterministic FDA CI-audit runner (run_fda_ci_audit.py).
#
# The runner is the headless, exit-code-contract core that consumer-repo CI calls
# (via the brite-claude-plugins composite action) to BLOCK off-canon FDA docs at PR
# time — layer-3 / continuous enforcement (vs layer-2 audit-time /flow:audit).
#
# It reuses the CANONICAL Phase-B predicates from build_audit_report.py
# (_config_frontmatter_schema_mode / _config_story_frame_mode /
# _story_frontmatter_populated / _story_frame_present / _domains / _story_docs) so
# there is ONE source of truth, plus journey frontmatter-schema lint (strict) and a
# body link-resolution check (every `](path.md)` resolves on disk — the BC-13710
# broken-link class). Exit-code contract: 0 all-pass, 1 ≥1 hard-fail, 2 usage.
#
# Fixture note: tests/fixtures/audit-clean-shape ships LEAN story docs (the 4-key
# floor), so it is "clean" under LENIENT but intentionally NOT full-canon under
# STRICT — flipping frontmatter_schema:strict on it is exactly how we exercise the
# strict schema gate firing (mirrors run-audit-smoke.sh § 4e).
#
# Pattern template: run-audit-smoke.sh (copy-the-clean-fixture + targeted mutation).
# Bash 3.2 compatible (macOS); stdlib python3 only.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/../scripts/run_fda_ci_audit.py"
CLEAN_FIXTURE="$SCRIPT_DIR/fixtures/audit-clean-shape"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }

PASS=0; FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# run_audit [repo] → sets RC (exit code) and OUT (combined stdout+stderr).
# Tolerates a missing arg (set -u safe) so the usage-contract test can call it bare.
run_audit() {
  set +e
  OUT="$(python3 "$RUNNER" ${1+"$1"} 2>&1)"; RC=$?
  set -e
}

TMPS=()
# set +e inside the trap so a cleanup non-zero can't leak into the script's exit
# status (EXIT trap runs under the script's set -e otherwise); end on `:` (true).
cleanup() { set +e; for t in "${TMPS[@]:-}"; do [ -n "$t" ] && rm -rf "$t"; done; :; }
trap cleanup EXIT

# fresh_copy → a temp copy of the clean (lean, lenient) fixture; echo its path.
fresh_copy() { local d; d="$(mktemp -d)"; cp -R "$CLEAN_FIXTURE/." "$d/"; TMPS+=("$d"); printf '%s' "$d"; }

# set_flag <repo> <key> <value> — set a .flow/config.json strict flag.
set_flag() {
  python3 - "$1/.flow/config.json" "$2" "$3" <<'PY'
import json, sys
p, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
with open(p) as fh:
    d = json.load(fh)
d[k] = v
with open(p, 'w') as fh:
    json.dump(d, fh)
PY
}

first_story() { ls "$1"/docs/product/flows/*/*.md | head -1; }

# ── Section 0: runner exists + usage contract ────────────────────────────────
section "0/8" "runner present + usage contract"
if [ -f "$RUNNER" ]; then pass "run_fda_ci_audit.py present"; else fail "run_fda_ci_audit.py MISSING at $RUNNER"; fi
run_audit; [ "$RC" = "2" ] && pass "no-arg → exit 2 (usage)" || fail "no-arg exit $RC (expected 2)"
run_audit /nonexistent/repo/path; [ "$RC" = "2" ] && pass "bad repo path → exit 2" || fail "bad path exit $RC (expected 2)"

# ── Section 1: clean fixture under LENIENT (natural) → PASS, exit 0 ───────────
section "1/8" "clean lean canon under lenient → exit 0"
F1="$(fresh_copy)"
run_audit "$F1"
if [ "$RC" = "0" ]; then pass "clean lenient fixture → exit 0"; else fail "clean lenient → exit $RC; OUT: $OUT"; fi

# ── Section 2: frontmatter_schema:strict on the LEAN fixture → exit 1 ─────────
# The lean docs are the 4-key floor, NOT full 20-key canon → strict schema FAILs.
section "2/8" "frontmatter_schema strict on lean docs → exit 1 (names frontmatter-schema)"
F2="$(fresh_copy)"; set_flag "$F2" frontmatter_schema strict
run_audit "$F2"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'frontmatter-schema'; then
  pass "lean docs under strict → exit 1 + names frontmatter-schema"
else
  fail "strict schema gate not enforced: exit $RC; OUT: $OUT"
fi

# ── Section 3: story_frame:strict + a constraint-spec frame → exit 1 ──────────
# Flip ONLY story_frame:strict (schema stays lenient → isolates the frame gate).
# All fixture docs carry the human When-frame; mutate ONE to constraint-spec.
section "3/8" "story_frame strict: constraint-spec frame → exit 1 (names story-frame)"
F3="$(fresh_copy)"; set_flag "$F3" story_frame strict
python3 - "$(first_story "$F3")" <<'PY'
import re, sys
p = sys.argv[1]
with open(p) as fh:
    s = fh.read()
s = re.sub(r'\*\*When\*\*.*?\*\*so I can\*\*[^\n]*',
          '**Given** a request resolves, the system **MUST** serve it, **so that** it works.',
          s, count=1, flags=re.S)
with open(p, 'w') as fh:
    fh.write(s)
PY
run_audit "$F3"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'story-frame'; then
  pass "constraint-spec frame under strict → exit 1 + names story-frame"
else
  fail "story-frame strict not enforced: exit $RC; OUT: $OUT"
fi

# ── Section 4: link-resolution — a broken body .md link → exit 1 ─────────────
# The BC-13710 class: a [..](./missing.md) body link that doesn't resolve on disk.
# Always-on (not config-gated) — pure structural integrity.
section "4/8" "link-resolution: broken body link → exit 1 (names link)"
F4="$(fresh_copy)"
printf '\n\nSee [the ghost](./nonexistent-sibling.md).\n' >> "$(first_story "$F4")"
run_audit "$F4"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'link'; then
  pass "broken .md link → exit 1 + names link-resolution"
else
  fail "broken link not caught: exit $RC; OUT: $OUT"
fi

# ── Section 4b: link-resolution covers JOURNEY docs too ──────────────────────
# audit() appends _journey_docs(repo) to the link surface; without this a regression
# dropping the journey path would still pass §4 (story-only). This is exactly where
# the real BC-12303 find lived — a broken intent link in a brite-sites JOURNEY body.
section "4b/8" "link-resolution covers journey docs: broken journey link → exit 1"
F4B="$(fresh_copy)"
JDOC="$(ls "$F4B"/docs/product/journeys/*.md | head -1)"
printf '\n\nSee [the ghost](./nonexistent-journey-ref.md).\n' >> "$JDOC"
run_audit "$F4B"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'link-resolution' && printf '%s' "$OUT" | grep -qi 'journey:'; then
  pass "broken journey-doc link → exit 1 (journey path covered)"
else
  fail "broken journey link not caught: exit $RC; OUT: $OUT"
fi

# ── Section 5: config-gating — lenient repo NOT blocked by non-canon doc → 0 ──
# Same lean docs as Section 2, but lenient (no strict flag): the schema gate must
# NOT fire on a missing NON-floor canon key. Proves the flag GATES the schema gate
# (pairs with Section 2: identical docs, opposite verdict by flag alone).
section "5/8" "config-gating: lenient repo with non-canon doc → exit 0"
F5="$(fresh_copy)"   # no strict flags
python3 - "$(first_story "$F5")" <<'PY'
import re, sys
p = sys.argv[1]
with open(p) as fh:
    s = fh.read()
s = re.sub(r'^real_app_url:.*\n', '', s, flags=re.M)  # drop a non-floor canon key (no-op if absent)
with open(p, 'w') as fh:
    fh.write(s)
PY
run_audit "$F5"
if [ "$RC" = "0" ]; then pass "lenient + missing non-floor canon key → exit 0 (gated)"; else fail "lenient wrongly blocked: exit $RC; OUT: $OUT"; fi

# ── Section 6: negative control — valid sibling link stays exit 0 ────────────
section "6/8" "negative control: valid sibling .md link does not trip link-resolution"
F6="$(fresh_copy)"
SIB="$(ls "$F6"/docs/product/flows/*/*.md | sed -n '2p')"; SIB="$(basename "${SIB:-$(first_story "$F6")}")"
printf '\n\nSee [sibling](./%s).\n' "$SIB" >> "$(first_story "$F6")"
run_audit "$F6"
if [ "$RC" = "0" ]; then pass "valid sibling link → exit 0"; else fail "valid link wrongly failed: exit $RC; OUT: $OUT"; fi

# ── Section 7: external links (any-scheme + protocol-relative) NOT flagged ────
# P2 regression guard: a `.md` URL behind an UPPERCASE scheme or protocol-relative
# `//` host is external, not a file link — must stay exit 0 (was a false-positive
# block when the scheme exemption was lowercase-only).
section "7/8" "external .md links (HTTPS:// / //host / mailto) → exit 0 (no false block)"
F7="$(fresh_copy)"
{ printf '\nExternal refs that must NOT be resolved on disk:\n'
  printf -- '- [up](HTTPS://example.com/guide.md)\n'
  printf -- '- [lo](http://example.com/x.md)\n'
  printf -- '- [pr](//cdn.example.com/spec.md)\n'
  printf -- '- [ml](mailto:team@example.com)\n'; } >> "$(first_story "$F7")"
run_audit "$F7"
if [ "$RC" = "0" ]; then pass "uppercase/protocol-relative external .md links → exit 0"; else fail "external links wrongly flagged: exit $RC; OUT: $OUT"; fi

# ── Section 8: broken link WITH a markdown title attribute IS caught ──────────
# P3 regression guard: `](./missing.md "Title")` is a real broken link and must be
# detected (the title segment previously defeated the match → false negative).
section "8/8" "broken .md link carrying a title attribute → exit 1 (caught)"
F8="$(fresh_copy)"
printf '\n\nSee [ghost](./nonexistent-titled.md "Hover title").\n' >> "$(first_story "$F8")"
run_audit "$F8"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'link'; then
  pass "broken titled link → exit 1 + names link-resolution"
else
  fail "broken titled link not caught: exit $RC; OUT: $OUT"
fi

# ── Section 9: redirect-stub gate (BC-12907) ─────────────────────────────────
# A doc_type:redirect stub is validated AS a redirect: resolvable pointer + valid
# redirect front-matter; the story-frame/populated gates are skipped (it has no job
# story by design). A dangling redirect_to hard-fails (renamed/removed canonical home).
section "9" "redirect-stub gate: valid alias → exit 0 (story gates skipped); dangling → exit 1"
FR="$(fresh_copy)"
ALIAS="$(ls "$FR"/docs/product/flows/*/*.md | head -1)"
TARGET_FID="$(basename "$(ls "$FR"/docs/product/flows/*/*.md | tail -1)" .md)"
python3 - "$ALIAS" "$TARGET_FID" <<'PY'
import os, sys
p, target = sys.argv[1], sys.argv[2]
fid = os.path.splitext(os.path.basename(p))[0]
dom = os.path.basename(os.path.dirname(p))
open(p, "w").write(
    "---\nflow_id: %s\ndomain: %s\ndoc_type: redirect\nredirect_to: %s\n"
    "intent: ../../intent.md\nlast_reviewed: '2026-05-20'\n---\n# %s (redirect stub)\n"
    % (fid, dom, target, fid))
PY
run_audit "$FR"
if [ "$RC" = "0" ]; then pass "valid redirect stub (lenient) → exit 0 (story-frame skipped)"; else fail "valid redirect blocked: exit $RC; OUT: $OUT"; fi
# dangling: point redirect_to at a non-existent flow (kept LENIENT so redirect-target is the SOLE failure)
python3 - "$ALIAS" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(re.sub(r'^redirect_to:.*$', 'redirect_to: NOPE-00', s, count=1, flags=re.M))
PY
run_audit "$FR"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'redirect-target'; then
  pass "dangling redirect_to → exit 1 + names redirect-target"
else
  fail "dangling redirect not caught: exit $RC; OUT: $OUT"
fi
# self-pointer: redirect_to == the doc's own flow_id (a no-op loop) → exit 1 (BC-12907 review-fix)
python3 - "$ALIAS" <<'PY'
import os, re, sys
p = sys.argv[1]; fid = os.path.splitext(os.path.basename(p))[0]
s = open(p).read()
open(p, "w").write(re.sub(r'^redirect_to:.*$', 'redirect_to: %s' % fid, s, count=1, flags=re.M))
PY
run_audit "$FR"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'redirect-target'; then
  pass "self-pointer redirect_to (== own flow_id) → exit 1 + names redirect-target"
else
  fail "self-pointer redirect not caught: exit $RC; OUT: $OUT"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf '\n%s\n' '------------------------------------------'
printf 'BC-12303 fda-ci-audit vslice: %d pass / %d fail\n' "$PASS" "$FAIL"
printf '%s\n' '------------------------------------------'
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then printf '\nHarness failed.\n'; exit 1; fi
exit 0
