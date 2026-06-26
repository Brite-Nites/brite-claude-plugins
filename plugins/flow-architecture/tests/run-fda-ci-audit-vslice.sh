#!/usr/bin/env bash
# BC-12303 vslice — the deterministic FDA CI-audit runner (run_fda_ci_audit.py).
#
# The runner is the headless, exit-code-contract core that consumer-repo CI calls
# (via the brite-claude-plugins composite action) to BLOCK off-canon FDA docs at PR
# time — layer-3 / continuous enforcement (vs layer-2 audit-time /flow:audit).
#
# It reuses the CANONICAL Phase-B predicates from build_audit_report.py
# (_story_frontmatter_populated / _story_frame_present / _domains / _story_docs) so
# there is ONE source of truth, plus journey frontmatter-schema lint and a body
# link-resolution check (every `](path.md)` resolves on disk — the BC-13710
# broken-link class). Exit-code contract: 0 all-pass, 1 ≥1 hard-fail, 2 usage.
#
# Both the frontmatter-schema gate (full canon) and the story-frame gate (human-only)
# are UNCONDITIONAL — the per-repo `frontmatter_schema` (BC-13915) and `story_frame`
# (BC-12197) strangler-fig flags were collapsed once every consumer converged. The
# tests/fixtures/audit-clean-shape fixture carries the FULL canon, so a fresh copy passes
# clean; the FAIL paths are exercised by downgrading one doc (mirrors run-audit-smoke.sh § 4e).
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

# fresh_copy → a temp copy of the clean (FULL canon) fixture; echo its path.
fresh_copy() { local d; d="$(mktemp -d)"; cp -R "$CLEAN_FIXTURE/." "$d/"; TMPS+=("$d"); printf '%s' "$d"; }

# strip_canon <doc> — remove the non-floor canonical story keys to downgrade a full-canon
# doc to the lean 4-key shape (so it FAILs the now-unconditional full-canon gate).
strip_canon() {
  python3 - "$1" <<'PY'
import re, sys
p = sys.argv[1]
strip = {"domain","parent_issue","personas","related_flows","sandbox_url","staging_url",
         "real_app_url","e2e_test","eng_status","design_status","docs_status","intent"}
out = []
for l in open(p):
    m = re.match(r'^([a-z_]+):', l)
    if m and m.group(1) in strip:
        continue
    out.append(l)
open(p, 'w').write("".join(out))
PY
}

first_story() { ls "$1"/docs/product/flows/*/*.md | head -1; }

# ── Section 0: runner exists + usage contract ────────────────────────────────
section "0/8" "runner present + usage contract"
if [ -f "$RUNNER" ]; then pass "run_fda_ci_audit.py present"; else fail "run_fda_ci_audit.py MISSING at $RUNNER"; fi
run_audit; [ "$RC" = "2" ] && pass "no-arg → exit 2 (usage)" || fail "no-arg exit $RC (expected 2)"
run_audit /nonexistent/repo/path; [ "$RC" = "2" ] && pass "bad repo path → exit 2" || fail "bad path exit $RC (expected 2)"

# ── Section 1: clean full-canon fixture → PASS, exit 0 ───────────────────────
section "1/8" "clean full-canon fixture → exit 0"
F1="$(fresh_copy)"
run_audit "$F1"
if [ "$RC" = "0" ]; then pass "clean full-canon fixture → exit 0"; else fail "clean fixture → exit $RC; OUT: $OUT"; fi

# ── Section 2: a doc downgraded to the lean 4-key floor → exit 1 ──────────────
# The full-canon frontmatter gate is unconditional (BC-13915) — no flag to set; strip a
# doc back to the lean shape → the missing canon keys FAIL frontmatter-schema.
section "2/8" "lean (non-canon) doc → exit 1 (names frontmatter-schema)"
F2="$(fresh_copy)"; strip_canon "$(first_story "$F2")"
run_audit "$F2"
if [ "$RC" = "1" ] && printf '%s' "$OUT" | grep -qi 'frontmatter-schema'; then
  pass "lean doc → exit 1 + names frontmatter-schema"
else
  fail "full-canon schema gate not enforced: exit $RC; OUT: $OUT"
fi

# ── Section 3: a constraint-spec frame → exit 1 ───────────────────────────────
# The story-frame gate is hardcoded human-only (BC-12197) — no flag to set. All fixture
# docs carry the human When-frame; mutate ONE to constraint-spec, keeping its full-canon
# frontmatter intact (so ONLY story-frame can flip) → it FAILs unconditionally.
section "3/8" "constraint-spec frame → exit 1 (names story-frame)"
F3="$(fresh_copy)"
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

# (The former Section 5 — "lenient repo NOT blocked by a non-canon doc → exit 0" — was
# removed with the frontmatter_schema flag: BC-13915 collapsed the lenient 4-key floor,
# so there is no longer a config-gated pass for a non-canon doc. Section 2 now pins the
# unconditional FAIL path.)

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

# ── §10: flow_index:skip excludes overview/index docs (BC-13805) ──────────────
# A non-sub-flow doc opting out via `flow_index: skip` must NOT be audited — even
# with content that would otherwise hard-fail (no canon frontmatter, no frame).
section "10" "flow_index:skip overview doc excluded from the audit"
FS="$(fresh_copy)"
ADOM="$(basename "$(dirname "$(ls "$FS"/docs/product/flows/*/*.md | head -1)")")"
printf -- '---\ndomain: %s\nflow_index: skip\n---\n# Overview\nNo job story, no canon frontmatter.\n' "$ADOM" \
  > "$FS/docs/product/flows/$ADOM/overview.md"
run_audit "$FS"
if [ "$RC" = "0" ]; then
  pass "flow_index:skip overview doc excluded → exit 0 (not audited as a story)"
else
  fail "flow_index:skip doc was audited: exit $RC; OUT: $OUT"
fi

# ── §11: flow_index:skip excludes overview/index JOURNEY docs (BC-13819) ──────
# Mirrors §10 for the journey surface. _journey_docs honors flow_index:skip so an
# overview index (e.g. journeys/INDEX.md) is excluded from BOTH the ADR-033 schema
# lint AND link-resolution — symmetric with the _story_docs exclusion. Tested via
# the always-on link-resolution gate under LENIENT (a broken link in a skip doc must
# NOT fire), isolating the exclusion where §4b proves a NON-skip journey link WOULD.
section "11" "flow_index:skip journey overview excluded (broken link in skip doc → exit 0)"
FJ="$(fresh_copy)"
printf -- '---\nflow_index: skip\n---\n# Journey Index\n\nSee [ghost](./nonexistent-journey-overview-ref.md).\n' \
  > "$FJ/docs/product/journeys/INDEX.md"
run_audit "$FJ"
if [ "$RC" = "0" ]; then
  pass "flow_index:skip journey overview excluded → exit 0 (schema + link-res skipped)"
else
  fail "flow_index:skip journey doc was audited: exit $RC; OUT: $OUT"
fi

# ── §11b: …and from the journey schema-lint path too ─────────────────────────
# §11 isolates the exclusion via the always-on link-resolution gate. This covers the
# OTHER consumer of _journey_docs: the ADR-033 journey schema lint (now unconditional —
# BC-13915). We assert on the OUTPUT — a skip journey with junk frontmatter must NOT be
# NAMED as a journey frontmatter-schema failure (it would be, were it not excluded).
section "11b" "flow_index:skip journey excluded from the journey schema lint (not named)"
FJS="$(fresh_copy)"
printf -- '---\nflow_index: skip\n---\n# Overview\nNot a journey — no ADR-033 canon.\n' \
  > "$FJS/docs/product/journeys/zzz-overview.md"
run_audit "$FJS"
if printf '%s' "$OUT" | grep -qi 'journey:zzz-overview'; then
  fail "flow_index:skip journey was schema-linted under strict: $OUT"
else
  pass "flow_index:skip journey excluded from strict schema lint (not named as a failure)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf '\n%s\n' '------------------------------------------'
printf 'BC-12303 fda-ci-audit vslice: %d pass / %d fail\n' "$PASS" "$FAIL"
printf '%s\n' '------------------------------------------'
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then printf '\nHarness failed.\n'; exit 1; fi
exit 0
