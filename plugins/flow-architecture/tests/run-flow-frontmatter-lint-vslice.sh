#!/usr/bin/env bash
# Regression-lock for the WS-A frontmatter-schema lint (BC-12572):
#   scripts/lib/flow_frontmatter_lint.py
#   A-10 story-doc frontmatter schema   (20-key canon, ADR-029 / job-story template)
#   A-11 journey-doc frontmatter schema (9-key canon, ADR-033 / domain-journey template)
#
# The lint reports three severity classes (key-level only — values are BC-12692):
#   DRIFT_KEY    a wrong-name key (sub_flow_id / linear_parent / persona / milestone …)
#                — loud (exit 1). Flags even when the canonical twin is ALSO present
#                (the stale duplicate is the confusion this issue kills).
#   MISSING_KEY  a canonical key (incl. nested children.* / linear_milestone.*) absent
#                — loud (exit 1). Honest-empty (`personas: []`, `…: null`) PASSES;
#                presence, never non-emptiness.
#   UNKNOWN_KEY  an off-canon extra (title / slug / display_name-on-story …) — quiet
#                (exit 0). ADR-033's blessed journey extras are silently allowlisted.
#
# Two layers, mirroring run-flow-linear-lint-vslice.sh: (1) DIRECT per-class
# assertions via the lib's lint_doc() over the committed builder GOLDENS (the
# canonical-good fixtures) + temp-dir mutated variants (one defect each); (2) CLI
# verdict assertions on the bash runner (exit codes, bad invocation). Using the
# builder goldens as the good fixtures structurally couples the lint to exactly
# what build_{story,journey}_frontmatter.py emit — they cannot drift apart silently.
#
# Target: bash 3.2 (macOS default). Stdlib python3 only.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIBDIR="$PLUGIN_DIR/scripts/lib"
RUNNER="$PLUGIN_DIR/scripts/flow-frontmatter-lint.sh"
STORY_GOLDEN="$SCRIPT_DIR/fixtures/story-frontmatter-stamp/golden/WGT-01.frontmatter"
JOURNEY_GOLDEN="$SCRIPT_DIR/fixtures/journey-frontmatter-stamp/golden/happy.frontmatter"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIBDIR/flow_frontmatter_lint.py" ] || { echo "fatal: lib missing at $LIBDIR/flow_frontmatter_lint.py" >&2; exit 1; }

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# lint_bucket <doc-path> <doc-type> <bucket: drift|missing|unknown>
# Prints the count on line 1, then one violation string per line.
lint_bucket() {
  python3 - "$LIBDIR" "$1" "$2" "$3" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_frontmatter_lint as m
res = m.lint_doc(sys.argv[2], sys.argv[3])
bucket = res[sys.argv[4]]
print(len(bucket))
for v in bucket:
    print(v)
PY
}

# count <doc-path> <doc-type> <bucket>
count() { lint_bucket "$1" "$2" "$3" | sed -n '1p'; }

assert_count() { # <label> <doc> <type> <bucket> <expected-count>
  local got; got="$(count "$2" "$3" "$4")"
  if [ "$got" = "$5" ]; then pass "$1"; else fail "$1 (expected $4=$5, got $got)"; fi
}
assert_clean() { # <label> <doc> <type> — all three buckets empty
  local d m u
  d="$(count "$2" "$3" drift)"; m="$(count "$2" "$3" missing)"; u="$(count "$2" "$3" unknown)"
  if [ "$d" = 0 ] && [ "$m" = 0 ] && [ "$u" = 0 ]; then pass "$1"
  else fail "$1 (drift=$d missing=$m unknown=$u, expected 0/0/0)"; fi
}
assert_has() { # <label> <doc> <type> <bucket> <substr>
  local out; out="$(lint_bucket "$2" "$3" "$4" | sed '1d')"
  case "$out" in *"$5"*) pass "$1" ;; *) fail "$1 (expected substr '$5' in $4, got: $(printf '%s' "$out" | tr '\n' '|'))" ;; esac
}

# ── helpers to build mutated story-doc variants in the temp dir ─────────────
# Start from a known-good full-canon story frontmatter, then mutate one thing.
GOOD_STORY="$TMP/good-story.md"
cat > "$GOOD_STORY" <<'EOF'
---
flow_id: WGT-01
domain: WGT
status: BUILT
parent_issue: BC-20001
children:
  story: BC-20002
  engineering: BC-20003
  design: BC-20004
  qa: BC-20005
  docs: BC-20006
personas: [operator, tm]
related_flows: [WGT-02]
figma: TBD
sandbox_url: TBD
staging_url: TBD
real_app_url: TBD
e2e_test: TBD
user_docs_url: TBD
qa_status: not-tested
qa_last_signed_off: null
eng_status: not-started
design_status: not-started
docs_status: not-started
intent: ../../intent.md
last_reviewed: 2026-06-10
---
# WGT-01: Widget
EOF

# ── Section 1: A-10 story canonical-good (tracer) ───────────────────────────
section "1" "A-10 story — canonical-good lints clean"
assert_clean "WGT-01 builder golden (full 20-key canon) → drift/missing/unknown all empty" \
  "$STORY_GOLDEN" story
assert_clean "hand-built full-canon story doc → clean" "$GOOD_STORY" story

# ── Section 2: A-10 story DRIFT_KEY ─────────────────────────────────────────
section "2" "A-10 story — drift keys (loud)"
# sub_flow_id replacing flow_id
sed 's/^flow_id: WGT-01/sub_flow_id: WGT-01/' "$GOOD_STORY" > "$TMP/drift-subflow.md"
assert_has "sub_flow_id flagged DRIFT → flow_id" "$TMP/drift-subflow.md" story drift "sub_flow_id → use flow_id"
# singular persona replacing personas
sed 's/^personas: \[operator, tm\]/persona: operator/' "$GOOD_STORY" > "$TMP/drift-persona.md"
assert_has "singular persona flagged DRIFT → personas" "$TMP/drift-persona.md" story drift "persona → use personas"
# linear_parent ALONGSIDE the canonical parent_issue (roster's IDN-01 shape) — still flags
sed 's/^parent_issue: BC-20001/parent_issue: BC-20001\nlinear_parent: BC-20001/' "$GOOD_STORY" > "$TMP/drift-dup.md"
assert_has "drift key alongside canonical twin still flags" "$TMP/drift-dup.md" story drift "linear_parent → use parent_issue"
assert_count "drift-alongside: parent_issue still satisfies missing (0 missing)" "$TMP/drift-dup.md" story missing 0
# a drift key REPLACING the canonical one → drift AND the canonical now missing
assert_has "sub_flow_id replacing flow_id also reports flow_id MISSING" "$TMP/drift-subflow.md" story missing "flow_id (canonical story key absent)"

# ── Section 3: A-10 story MISSING_KEY (presence, not non-emptiness) ──────────
section "3" "A-10 story — missing keys (loud); honest-empty passes"
# drop a top-level key
grep -v '^figma: TBD' "$GOOD_STORY" > "$TMP/miss-figma.md"
assert_has "absent figma flagged MISSING" "$TMP/miss-figma.md" story missing "figma (canonical story key absent)"
# honest-empty values PASS (presence, never non-emptiness)
sed -e 's/^personas: \[operator, tm\]/personas: []/' \
    -e 's/^related_flows: \[WGT-02\]/related_flows: []/' "$GOOD_STORY" > "$TMP/empty-ok.md"
assert_clean "honest-empty personas: [] + related_flows: [] → clean (presence floor)" "$TMP/empty-ok.md" story
# nested children slot missing → MISSING children.qa, parent still present
sed '/^  qa: BC-20005$/d' "$GOOD_STORY" > "$TMP/miss-childqa.md"
assert_has "nested children.qa absent flagged MISSING" "$TMP/miss-childqa.md" story missing "children.qa (nested canonical key absent)"
assert_count "children present so children itself not double-reported (only the slot)" "$TMP/miss-childqa.md" story missing 1

# ── Section 4: A-10 story UNKNOWN_KEY (quiet, exit 0) ────────────────────────
section "4" "A-10 story — unknown extras are quiet (exit 0)"
# title extra only → UNKNOWN noted, drift+missing empty (insert title: as a
# frontmatter key just before the closing ---).
awk '/^---$/{c++} c==2 && !done {print "title: Widget"; done=1} {print}' "$GOOD_STORY" > "$TMP/extra-title.md"
assert_has "title flagged UNKNOWN (quiet)" "$TMP/extra-title.md" story unknown "title"
assert_count "title-extra: no drift" "$TMP/extra-title.md" story drift 0
assert_count "title-extra: no missing" "$TMP/extra-title.md" story missing 0
# display_name on a STORY doc → UNKNOWN (luggage), NOT drift (it's canon on journeys only)
awk '/^---$/{c++} c==2 && !done {print "display_name: Widget"; done=1} {print}' "$GOOD_STORY" > "$TMP/extra-dispname.md"
assert_has "display_name on story flagged UNKNOWN (not drift)" "$TMP/extra-dispname.md" story unknown "display_name"
assert_count "display_name on story: NOT counted as drift" "$TMP/extra-dispname.md" story drift 0

# ── Section 5: malformed input degrades cleanly (P1 pre-empt, no traceback) ──
section "5" "malformed/absent frontmatter degrades to one MISSING_KEY, never a traceback"
printf '# A doc with no frontmatter at all\n\nbody only\n' > "$TMP/no-fm.md"
assert_has "no frontmatter block → single MISSING_KEY (not 20, not a crash)" "$TMP/no-fm.md" story missing "<no frontmatter block>"
assert_count "no frontmatter: exactly one missing line (not per-canon-key spam)" "$TMP/no-fm.md" story missing 1
# unterminated frontmatter (no closing ---) is treated as absent, not a crash
printf -- '---\nflow_id: X-1\n# never closed\n' > "$TMP/unterminated.md"
assert_has "unterminated frontmatter → single MISSING_KEY, no traceback" "$TMP/unterminated.md" story missing "<no frontmatter block>"
assert_count "unterminated: degrades to exactly one missing line (no per-key spam)" "$TMP/unterminated.md" story missing 1

# ── Section 6: A-11 journey canon + drift + nested + tolerated extras ────────
section "6" "A-11 journey — canon-good clean; drift loud; ADR-033 extras silent"
GOOD_JOURNEY="$TMP/good-journey.md"
cat > "$GOOD_JOURNEY" <<'EOF'
---
domain: widget-intake
display_name: Widget Intake
linear_milestone:
  name: Widget Intake
  id: 7f3c2a10-aaaa-4bbb-8ccc-0123456789ab
personas: [operator, tm]
flow_ids_in_scope: [WGT-01, WGT-02]
status: in-progress
figma: TBD
intent: ../intent.md
last_reviewed: 2026-06-11
---
# WGT: Widget Intake
EOF
assert_clean "happy builder golden (9-key journey canon) → clean" "$JOURNEY_GOLDEN" journey
assert_clean "hand-built full-canon journey doc → clean" "$GOOD_JOURNEY" journey
# journey honest-empty personas: [] passes (presence floor, parallel to the story case)
sed 's/^personas: \[operator, tm\]/personas: []/' "$GOOD_JOURNEY" > "$TMP/j-empty-ok.md"
assert_clean "journey honest-empty personas: [] → clean (presence floor)" "$TMP/j-empty-ok.md" journey
# milestone: drift (also makes linear_milestone missing)
sed 's/^linear_milestone:/milestone:/' "$GOOD_JOURNEY" > "$TMP/j-drift-milestone.md"
assert_has "journey milestone flagged DRIFT → linear_milestone" "$TMP/j-drift-milestone.md" journey drift "milestone → use linear_milestone"
# linear_project_id (ADR-033-dropped) alongside good → drift, with a DROP-not-USE hint
awk '/^---$/{c++} c==2 && !done {print "linear_project_id: abc-123"; done=1} {print}' "$GOOD_JOURNEY" > "$TMP/j-drift-projid.md"
assert_has "journey linear_project_id flagged DRIFT (dropped per ADR-033)" "$TMP/j-drift-projid.md" journey drift "linear_project_id"
# the drop-only entry reads naturally ('→ drop …', not the nonsensical '→ use (dropped)')
assert_has "drop-only drift hint reads as 'drop', not 'use'" "$TMP/j-drift-projid.md" journey drift "linear_project_id → drop"
# nested linear_milestone.id missing
sed '/^  id: 7f3c2a10/d' "$GOOD_JOURNEY" > "$TMP/j-miss-id.md"
assert_has "journey nested linear_milestone.id absent flagged MISSING" "$TMP/j-miss-id.md" journey missing "linear_milestone.id (nested canonical key absent)"
# ADR-033 tolerated extras stay SILENT (not unknown, not drift)
awk '/^---$/{c++} c==2 && !done {print "l2_reviewed: true"; print "related_domains: [foo]"; print "primary_persona: operator"; print "secondary_personas: [tm]"; done=1} {print}' "$GOOD_JOURNEY" > "$TMP/j-tolerated.md"
assert_clean "ADR-033 blessed extras (l2_reviewed/related_domains/primary+secondary personas) → silent" "$TMP/j-tolerated.md" journey

# ── Section 7: goldens-drift structural lock (lint canon == builder emission) ─
# The lib's hardcoded canon MUST equal the key set of the fixture-locked builder
# goldens (themselves pinned to the builders by their own vslices) — so a builder
# canon change this lint doesn't track reds CI. Both the TOP-LEVEL key set AND the
# NESTED-slot sets (children.* / linear_milestone.*) are locked.
section "7" "lint canon is asserted against the builder goldens (top-level + nested)"
golden_keys() { # <golden-frontmatter-file> [<nested-parent>]
  # No 2nd arg: top-level keys. With <nested-parent>: the indented sub-keys under it.
  python3 - "$1" "${2:-}" <<'PY'
import sys, re
parent = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
keys, in_block = [], False
for i, l in enumerate(open(sys.argv[1], encoding="utf-8")):
    s = l.rstrip("\n")
    if i == 0 and s.strip() == "---":
        continue
    if s.strip() == "---":
        break
    top = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):", s)
    sub = re.match(r"^\s+([A-Za-z_][A-Za-z0-9_]*):", s)
    if parent is None:
        if top:
            keys.append(top.group(1))
    else:
        if top:
            in_block = (top.group(1) == parent)
        elif sub and in_block:
            keys.append(sub.group(1))
print(" ".join(sorted(set(keys))))
PY
}
lib_canon() { # story|journey [top|children|milestone]
  python3 - "$LIBDIR" "$1" "${2:-top}" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_frontmatter_lint as m
which = sys.argv[3]
if which == "children":
    canon = m.STORY_CHILDREN_SLOTS
elif which == "milestone":
    canon = m.JOURNEY_MILESTONE_SUBKEYS
else:
    canon = m.STORY_CANON if sys.argv[2] == "story" else m.JOURNEY_CANON
print(" ".join(sorted(set(canon))))
PY
}
lock() { # <label> <expected-golden> <actual-lib>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (golden=[$2] lib=[$3])"; fi
}
lock "STORY_CANON == WGT-01 golden top-level keys" "$(golden_keys "$STORY_GOLDEN")" "$(lib_canon story top)"
lock "STORY_CHILDREN_SLOTS == WGT-01 golden children.* sub-keys" "$(golden_keys "$STORY_GOLDEN" children)" "$(lib_canon story children)"
lock "JOURNEY_CANON == happy golden top-level keys" "$(golden_keys "$JOURNEY_GOLDEN")" "$(lib_canon journey top)"
lock "JOURNEY_MILESTONE_SUBKEYS == happy golden linear_milestone.* sub-keys" "$(golden_keys "$JOURNEY_GOLDEN" linear_milestone)" "$(lib_canon journey milestone)"

# ── Section 8: runner CLI verdicts (exit codes) ─────────────────────────────
section "8" "flow-frontmatter-lint.sh runner — exit codes + scope"
[ -f "$RUNNER" ] || { echo "fatal: runner missing at $RUNNER" >&2; exit 1; }
mkdir -p "$TMP/clean-repo/docs/product/flows/WGT" "$TMP/dirty-repo/docs/product/flows/WGT"
cp "$GOOD_STORY" "$TMP/clean-repo/docs/product/flows/WGT/WGT-01.md"
cp "$GOOD_STORY" "$TMP/dirty-repo/docs/product/flows/WGT/WGT-01.md"
cp "$TMP/drift-subflow.md" "$TMP/dirty-repo/docs/product/flows/WGT/WGT-02.md"
if bash "$RUNNER" --type story "$TMP/clean-repo/docs/product/flows" >/dev/null 2>&1; then
  pass "runner exit 0 on a clean flows-dir"
else
  fail "runner non-zero on a clean flows-dir"
fi
if bash "$RUNNER" --type story "$TMP/dirty-repo/docs/product/flows" >/dev/null 2>&1; then
  fail "runner exit 0 on a dirty flows-dir (should be 1)"
else
  pass "runner exit 1 when any doc has a loud defect"
fi
# unknown-only stays exit 0 (quiet)
mkdir -p "$TMP/extra-repo/docs/product/flows/WGT"
cp "$TMP/extra-title.md" "$TMP/extra-repo/docs/product/flows/WGT/WGT-01.md"
if bash "$RUNNER" --type story "$TMP/extra-repo/docs/product/flows" >/dev/null 2>&1; then
  pass "runner exit 0 when only UNKNOWN_KEY extras present (quiet)"
else
  fail "runner non-zero on unknown-only repo (extras should not block)"
fi
# bad invocation → exit 2
if bash "$RUNNER" --type bogus "$TMP/clean-repo/docs/product/flows" >/dev/null 2>&1; then
  fail "runner exit 0 on bad --type (should be 2)"
else
  pass "runner non-zero on bad invocation"
fi

printf '\nflow-frontmatter-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
