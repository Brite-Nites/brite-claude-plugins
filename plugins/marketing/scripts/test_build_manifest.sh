#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/build_manifest.py (BC-12587).
#
# build_manifest.py is the DETERMINISTIC builder /marketing:plan-campaign delegates
# to in BOTH its normal and emit runs (ADR-028 D8 / Phase-2 grill DP2-1). It is a
# pure, stdlib-only, hermetic function of its inputs: it computes the slug, the
# back-filled absolute dueDates, the 8-label set, the 8+2 issue set (from the
# BC-12564 sub-issue-template YAML), the two-pass blockedBy graph (by INDEX), and
# assembles manifest.json + issues.json + brief.md into --out-dir. It makes NO
# MCP/network calls — the command owns that IO boundary.
#
# This harness invokes the builder against the REAL canonicals dir + REAL
# sub-issue-template file (testing the real data path, not a synthetic fixture)
# into a temp --out-dir, and asserts exit codes + structural fields. Pattern
# mirrors test_portfolio_snapshot.sh (BC-8731): substring/JSON assertions are
# load-bearing — a parser crash that exits with the right code on a different
# path satisfies the numeric expectation but exercises a different scenario.
#
# Scenarios:
#   A  standard happy path (municipalities/parks-rec-director/parks-bond)   exit 0
#   B  --disambiguator 2 → slug carries -v2                                 exit 0
#   C  invalid vertical → canonical hard-fail                               exit 2
#   D  invalid persona → canonical hard-fail                                exit 2
#   E  invalid offer → canonical hard-fail                                  exit 2
#   F  persona ∉ offer.target_personas → canonical hard-fail                exit 2
#   G  labs-gate: --situation-mining + entity!=labs → hard-fail             exit 2
#   H  labs-gate pass: --situation-mining + entity=labs → issue #9 present  exit 0
#   I  --creative-angles → issue #10 present                                exit 0
#   J  bad --month (13) → hard-fail                                         exit 2
#   K  bad --launch-date format → hard-fail                                 exit 2
#   L  bad --owner-email → hard-fail                                        exit 2
#   M  cross-entity without --theme → hard-fail                             exit 2
#   N  cross-entity with --theme → cross-entity-<theme> slug, 5 labels      exit 0
#   O  determinism: two runs same --created-at → byte-identical manifest    exit 0
#   P  dueDate arithmetic locked (#1 -21d / #6 +0 / #8 +40d)                exit 0
#   Q  blockedBy-by-index graph locked (#2=[1] #4=[3] #6=[5])              exit 0
#   R  purity guard: no network imports + writes ONLY under --out-dir        exit 0
#   S  brief.md fully slot-substituted (no leftover {{...}}) + pinned values  exit 0
#   T  invalid --entity enum (path-traversal guard)                          exit 2
#   U  --year out of range + no-partial-write-on-hard-fail                    exit 2
#   V  invalid --eb-workspace                                                 exit 2
#   W  cross-entity non-kebab --theme                                         exit 2
#   X  non-kebab --vertical (shape check)                                     exit 2
#   Y  impossible-but-shaped date (Feb 30)                                    exit 2
#   Z  --disambiguator < 2 guard                                              exit 2
#
# Usage:
#   bash plugins/marketing/scripts/test_build_manifest.sh
#   bash plugins/marketing/scripts/test_build_manifest.sh /path/to/build_manifest.py

set -u  # NOT set -e — non-zero exits are expected for reject scenarios

# Defuse caller's git env (matches test_portfolio_snapshot.sh discipline; guards
# the stale-pre-push-hook GIT_DIR leak documented in CLAUDE.md).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
BUILDER="${1:-$script_dir/build_manifest.py}"
CANON_DIR="$script_dir/../data/canonicals"
TEMPLATES="$script_dir/../references/campaign-sub-issue-templates.md"

if [ ! -f "$BUILDER" ]; then
  echo "FATAL: builder not found: $BUILDER" >&2
  exit 2
fi
BUILDER="$(cd "$(dirname "$BUILDER")" && pwd)/$(basename "$BUILDER")"

for required in "$CANON_DIR/_manifest.yaml" "$TEMPLATES"; do
  if [ ! -e "$required" ]; then
    echo "FATAL: required input not found: $required" >&2
    exit 2
  fi
done
CANON_DIR="$(cd "$CANON_DIR" && pwd)"
TEMPLATES="$(cd "$(dirname "$TEMPLATES")" && pwd)/$(basename "$TEMPLATES")"

tmproot="$(mktemp -d -t build-manifest-test.XXXXXX)" || {
  echo "FATAL: mktemp -d failed" >&2
  exit 2
}
cleanup() {
  if [ -d "$tmproot" ]; then
    find "$tmproot" -depth -type f -exec rm {} + 2>/dev/null || true
    find "$tmproot" -depth -type d -exec rmdir {} + 2>/dev/null || true
  fi
}
trap 'cleanup' EXIT

pass=0
fail=0
LAST_OUTPUT=""
LAST_RC=0

# ── helpers ────────────────────────────────────────────────────────────

mk_out() {  # name → fresh empty out-dir under tmproot
  local d="$tmproot/$1"
  mkdir -p "$d"
  printf '%s' "$d"
}

invoke_builder() {
  LAST_OUTPUT="$(python3 "$BUILDER" "$@" 2>&1)"
  LAST_RC=$?
}

# Standard happy-path args minus --out-dir (appended by caller).
std_args() {
  printf '%s\0' \
    --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z \
    --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES"
}
# Run the builder with std_args + any extra args + --out-dir (xargs -0 to keep
# paths with spaces intact).
invoke_std() {
  local out="$1"; shift
  local args=()
  while IFS= read -r -d '' a; do args+=("$a"); done < <(std_args)
  invoke_builder "${args[@]}" "$@" --out-dir "$out"
}

assert_exit() {  # label expected_rc
  local label="$1" expected="$2"
  if [ "$expected" -eq "$LAST_RC" ]; then
    echo "  PASS  $label (exit=$LAST_RC)"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — exit expected=$expected actual=$LAST_RC"
    printf '    output: %s\n' "$LAST_OUTPUT"; fail=$((fail + 1))
  fi
}

assert_substr() {  # label regex (against LAST_OUTPUT)
  local label="$1" rx="$2"
  if printf '%s' "$LAST_OUTPUT" | grep -qE -- "$rx"; then
    echo "  PASS  $label"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — regex not in output: $rx"
    printf '    output: %s\n' "$LAST_OUTPUT"; fail=$((fail + 1))
  fi
}

# assert_json LABEL FILE PY_BOOL_EXPR   (d = loaded JSON object)
assert_json() {
  local label="$1" file="$2" expr="$3"
  if [ ! -f "$file" ]; then
    echo "  FAIL  $label — file missing: $file"; fail=$((fail + 1)); return
  fi
  if FILE="$file" python3 -c "
import json, os, sys
d = json.load(open(os.environ['FILE']))
sys.exit(0 if ($expr) else 1)
" 2>/dev/null; then
    echo "  PASS  $label"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — predicate false: $expr"
    fail=$((fail + 1))
  fi
}

EXPECTED_LABELS='["slug:municipalities-parks-rec-director-parks-bond-fy26-m05","entity:nites","vertical:municipalities","persona:parks-rec-director","offer:parks-bond","year:2026","month:05","status:planning"]'

# ── scenarios ──────────────────────────────────────────────────────────

run_a() {  # standard happy path
  local out; out="$(mk_out A)"
  invoke_std "$out"
  assert_exit "A: standard happy path exit 0" 0
  assert_json "A: manifest slug" "$out/manifest.json" \
    "d['slug']=='municipalities-parks-rec-director-parks-bond-fy26-m05'"
  assert_json "A: manifest schema_version 1" "$out/manifest.json" "d['schema_version']==1"
  assert_json "A: manifest entity/vertical/persona/offer" "$out/manifest.json" \
    "d['entity']=='nites' and d['vertical']=='municipalities' and d['persona']=='parks-rec-director' and d['offer']=='parks-bond'"
  assert_json "A: manifest year/month" "$out/manifest.json" "d['year']==2026 and d['month']==5"
  assert_json "A: manifest linear/sf IDs null" "$out/manifest.json" \
    "d['linear']['milestone_id'] is None and d['salesforce']['campaign_id'] is None and d['email_bison']['campaign_id'] is None"
  assert_json "A: manifest eb workspace + sf/eb name" "$out/manifest.json" \
    "d['email_bison']['workspace']=='emailbison-personal' and d['salesforce']['campaign_name']==d['slug'] and d['email_bison']['campaign_name']==d['slug']"
  assert_json "A: manifest created_at injected" "$out/manifest.json" "d['created_at']=='2026-05-01T00:00:00Z'"
  assert_json "A: manifest scaffolded_by" "$out/manifest.json" "d['scaffolded_by']=='/marketing:plan-campaign'"
  assert_json "A: 8 standard issues (no optionals)" "$out/issues.json" "len(d['issues'])==8"
  assert_json "A: container payload present" "$out/issues.json" \
    "d['container']['title']=='municipalities-parks-rec-director-parks-bond-fy26-m05'"
  assert_json "A: every issue carries the 8-label set" "$out/issues.json" \
    "all(i['labels']==$EXPECTED_LABELS for i in d['issues'])"
  assert_json "A: container carries the 8-label set" "$out/issues.json" \
    "d['container']['labels']==$EXPECTED_LABELS"
  assert_json "A: full ordered standard title list" "$out/issues.json" \
    "[i['title'] for i in sorted(d['issues'], key=lambda x: x['index'])][:8]==['Brief approved','Target list built','Copy written + approved','Salesforce setup','Pre-launch QA','Launch executed','Active management — weekly reviews','Campaign closed + debrief']"
  assert_json "A: #2 description is the verbatim multi-part blockquote" "$out/issues.json" \
    "(lambda x: x.startswith('Outbound operator builds') and 'enriched lead CSV' in x and 'Handbook citation' in x and 'Sub-issue role' in x and 'Expected plugin command' in x)([i for i in d['issues'] if i['index']==2][0]['description'])"
  assert_json "A: every issue description carries all 3 contract lines" "$out/issues.json" \
    "all('Handbook citation' in i['description'] and 'Sub-issue role' in i['description'] and 'Expected plugin command' in i['description'] for i in d['issues'])"
  assert_json "A: manifest linear.project + url/launched_at null" "$out/manifest.json" \
    "d['linear']['project']=='Brite GTM' and d['linear']['milestone_url'] is None and d['email_bison']['launched_at'] is None"
}

run_b() {  # disambiguator → -v2
  local out; out="$(mk_out B)"
  invoke_std "$out" --disambiguator 2
  assert_exit "B: disambiguator exit 0" 0
  assert_json "B: slug carries -v2" "$out/manifest.json" \
    "d['slug']=='municipalities-parks-rec-director-parks-bond-fy26-m05-v2'"
  assert_json "B: slug label tracks the disambiguated slug" "$out/issues.json" \
    "d['issues'][0]['labels'][0]=='slug:municipalities-parks-rec-director-parks-bond-fy26-m05-v2'"
}

run_c() {  # invalid vertical
  local out; out="$(mk_out C)"
  local args=(); while IFS= read -r -d '' a; do args+=("$a"); done < <(std_args)
  # replace --vertical value
  invoke_builder --vertical not-a-vertical --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "C: invalid vertical hard-fail" 2
  assert_substr "C: canonical vertical error" "not in canonicals"
}

run_d() {  # invalid persona
  local out; out="$(mk_out D)"
  invoke_builder --vertical municipalities --persona not-a-persona --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "D: invalid persona hard-fail" 2
  assert_substr "D: canonical persona error" "is not defined for vertical"
}

run_e() {  # invalid offer
  local out; out="$(mk_out E)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer not-an-offer \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "E: invalid offer hard-fail" 2
  assert_substr "E: canonical offer error" "is not defined for vertical"
}

run_f() {  # persona not in offer.target_personas (parks-bond targets only parks-rec-director)
  local out; out="$(mk_out F)"
  invoke_builder --vertical municipalities --persona city-manager --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "F: persona∉target_personas hard-fail" 2
  assert_substr "F: target_personas error" "is not in this list|targets personas"
}

run_g() {  # labs-gate: situation-mining + non-labs
  local out; out="$(mk_out G)"
  invoke_std "$out" --situation-mining
  assert_exit "G: situation-mining+non-labs hard-fail" 2
  assert_substr "G: labs-gate error" "Labs"
}

run_h() {  # labs-gate pass
  local out; out="$(mk_out H)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity labs --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-b2b --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" \
    --situation-mining --out-dir "$out"
  assert_exit "H: situation-mining+labs exit 0" 0
  assert_json "H: issue #9 present" "$out/issues.json" \
    "any(i['index']==9 and i['labs_gated'] and i['optional'] for i in d['issues'])"
  assert_json "H: 9 issues total (8 + #9)" "$out/issues.json" "len(d['issues'])==9"
}

run_i() {  # creative-angles
  local out; out="$(mk_out I)"
  invoke_std "$out" --creative-angles
  assert_exit "I: creative-angles exit 0" 0
  assert_json "I: issue #10 present (optional, not labs)" "$out/issues.json" \
    "any(i['index']==10 and i['optional'] and not i['labs_gated'] for i in d['issues'])"
}

run_j() {  # bad month
  local out; out="$(mk_out J)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity nites --month 13 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "J: bad month hard-fail" 2
  assert_substr "J: month error" "month"
}

run_k() {  # bad launch-date
  local out; out="$(mk_out K)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 05-01-2026 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "K: bad launch-date hard-fail" 2
  assert_substr "K: launch-date error" "launch-date|YYYY-MM-DD"
}

run_l() {  # bad owner-email
  local out; out="$(mk_out L)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email "not-an-email" \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "L: bad owner-email hard-fail" 2
  assert_substr "L: owner-email error" "owner-email|email"
}

run_m() {  # cross-entity without theme
  local out; out="$(mk_out M)"
  invoke_builder --entity cross-entity --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-b2b --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "M: cross-entity w/o theme hard-fail" 2
  assert_substr "M: theme-required error" "theme"
}

run_n() {  # cross-entity with theme
  local out; out="$(mk_out N)"
  invoke_builder --entity cross-entity --theme america-250 --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-b2b --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "N: cross-entity w/ theme exit 0" 0
  assert_json "N: cross-entity slug" "$out/manifest.json" "d['slug']=='cross-entity-america-250-fy26-m05'"
  assert_json "N: V/P/O null in manifest" "$out/manifest.json" \
    "d['vertical'] is None and d['persona'] is None and d['offer'] is None"
  assert_json "N: 5 identity labels (no v/p/o labels)" "$out/issues.json" \
    "d['issues'][0]['labels']==['slug:cross-entity-america-250-fy26-m05','entity:cross-entity','year:2026','month:05','status:planning']"
}

run_o() {  # determinism
  local o1; o1="$(mk_out O1)"; local o2; o2="$(mk_out O2)"
  invoke_std "$o1"; invoke_std "$o2"
  if [ -f "$o1/manifest.json" ] && [ -f "$o2/manifest.json" ] && \
     diff -q "$o1/manifest.json" "$o2/manifest.json" >/dev/null 2>&1 && \
     diff -q "$o1/issues.json" "$o2/issues.json" >/dev/null 2>&1; then
    echo "  PASS  O: two runs byte-identical (manifest + issues)"; pass=$((pass + 1))
  else
    echo "  FAIL  O: runs differ (non-deterministic)"; fail=$((fail + 1))
  fi
}

run_p() {  # dueDate arithmetic
  local out; out="$(mk_out P)"
  invoke_std "$out"
  assert_json "P: #1 dueDate = launch-21d" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==1][0]['dueDate']=='2026-04-10'"
  assert_json "P: #6 dueDate = launch+0" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==6][0]['dueDate']=='2026-05-01'"
  assert_json "P: #8 dueDate = launch+40d" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==8][0]['dueDate']=='2026-06-10'"
}

run_q() {  # blockedBy graph
  local out; out="$(mk_out Q)"
  invoke_std "$out"
  assert_json "Q: #1 blockedBy []" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==1][0]['blockedBy']==[]"
  assert_json "Q: #2 blockedBy [1]" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==2][0]['blockedBy']==[1]"
  assert_json "Q: #3 blockedBy [1] (parallel w/ #2)" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==3][0]['blockedBy']==[1]"
  assert_json "Q: #4 blockedBy [3]" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==4][0]['blockedBy']==[3]"
  assert_json "Q: #6 blockedBy [5]" "$out/issues.json" \
    "[i for i in d['issues'] if i['index']==6][0]['blockedBy']==[5]"
}

run_r() {  # purity guard
  # (1) no network/subprocess imports in the builder source. POSIX [[:space:]]
  # (NOT \s, which BSD/macOS grep -E does not support and would silently miss).
  if grep -nE '^[[:space:]]*(import|from)[[:space:]]+(socket|subprocess|urllib|http|ftplib|smtplib|requests|aiohttp|httpx|websocket|paramiko|asyncio)' "$BUILDER" >/dev/null 2>&1; then
    echo "  FAIL  R: builder imports a network/subprocess module"; fail=$((fail + 1))
  else
    echo "  PASS  R: builder has no network/subprocess imports"; pass=$((pass + 1))
  fi
  # (2) write-scope: run from an EMPTY cwd and assert the ONLY new files anywhere
  # under a dedicated workspace are the 3 artifacts under --out-dir, AND the cwd
  # stays empty. This actually verifies "writes only under --out-dir" (the count
  # check alone would pass a builder that also wrote a stray file elsewhere).
  local ws; ws="$(mk_out Rscope)"
  local cwd="$ws/cwd"; mkdir -p "$cwd"
  local out="$ws/out"; mkdir -p "$out"
  local before; before="$(find "$ws" -type f | sort)"
  ( cd "$cwd" && python3 "$BUILDER" \
      --vertical municipalities --persona parks-rec-director --offer parks-bond \
      --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
      --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
      --created-at 2026-05-01T00:00:00Z \
      --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out" ) >/dev/null 2>&1
  local rc=$?
  local after; after="$(find "$ws" -type f | sort)"
  local stray; stray="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep -v "^$out/" || true)"
  local cwd_files; cwd_files="$(find "$cwd" -type f | wc -l | tr -d ' ')"
  local outn; outn="$(find "$out" -type f | wc -l | tr -d ' ')"
  if [ "$rc" -eq 0 ] && [ -z "$stray" ] && [ "$cwd_files" = "0" ] && [ "$outn" = "3" ]; then
    echo "  PASS  R: emit writes ONLY the 3 artifacts under --out-dir (cwd + tree clean)"; pass=$((pass + 1))
  else
    echo "  FAIL  R: write-scope violated (rc=$rc cwd_files=$cwd_files out=$outn stray=[$stray])"; fail=$((fail + 1))
  fi
}

run_s() {  # brief.md substitution
  local out; out="$(mk_out S)"
  invoke_std "$out"
  if [ ! -f "$out/brief.md" ]; then
    echo "  FAIL  S: brief.md missing"; fail=$((fail + 1)); return
  fi
  # For a standard campaign EVERY {{slot}} resolves; only <!-- OPERATOR-FILL -->
  # placeholders remain. Assert no leftover {{...}} of any name (not just slug).
  if grep -qE '\{\{[a-z_]+\}\}' "$out/brief.md"; then
    echo "  FAIL  S: brief.md has unsubstituted slot(s):"
    grep -oE '\{\{[a-z_]+\}\}' "$out/brief.md" | sort -u | sed 's/^/      /'
    fail=$((fail + 1))
  else
    echo "  PASS  S: brief.md — no leftover {{...}} slots"; pass=$((pass + 1))
  fi
  # Pin a spread of substituted values (slug, vertical_display, a title-cascade
  # entry, offer posture, month_display, owner_email, eb_workspace) + section headers.
  if grep -q 'municipalities-parks-rec-director-parks-bond-fy26-m05' "$out/brief.md" && \
     grep -q 'Municipalities' "$out/brief.md" && \
     grep -q 'Director of Parks & Recreation' "$out/brief.md" && \
     grep -q 'posture: knowledge' "$out/brief.md" && \
     grep -q 'May 2026' "$out/brief.md" && \
     grep -q 'marketingadmin@britenites.com' "$out/brief.md" && \
     grep -q 'emailbison-personal' "$out/brief.md" && \
     grep -qE '^## 1\.' "$out/brief.md" && grep -qE '^## 8\.' "$out/brief.md"; then
    echo "  PASS  S: brief.md carries all pinned substituted values + 8 sections"; pass=$((pass + 1))
  else
    echo "  FAIL  S: brief.md missing a pinned value or section header"; fail=$((fail + 1))
  fi
}

run_t() {  # invalid --entity enum (the path-traversal guard)
  local out; out="$(mk_out T)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity bogus --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "T: invalid --entity hard-fail" 2
  assert_substr "T: entity path-traversal guard error" "Path-traversal guard"
}

run_u() {  # --year out of range + no-partial-write-on-hard-fail
  local out; out="$(mk_out U)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 1999 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "U: --year out-of-range hard-fail" 2
  assert_substr "U: year error" "year must be 4-digit"
  local n; n="$(find "$out" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$n" = "0" ]; then
    echo "  PASS  U: no partial artifacts written on hard-fail"; pass=$((pass + 1))
  else
    echo "  FAIL  U: $n partial artifact(s) written on hard-fail"; fail=$((fail + 1))
  fi
}

run_v() {  # invalid --eb-workspace
  local out; out="$(mk_out V)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace bogus --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "V: invalid --eb-workspace hard-fail" 2
  assert_substr "V: eb-workspace error" "eb-workspace must be"
}

run_w() {  # cross-entity non-kebab --theme
  local out; out="$(mk_out W)"
  invoke_builder --entity cross-entity --theme "Not Kebab" --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-b2b --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "W: non-kebab --theme hard-fail" 2
  assert_substr "W: theme kebab error" "theme must be strict kebab-case"
}

run_x() {  # non-kebab --vertical (shape check, before canonicality)
  local out; out="$(mk_out X)"
  invoke_builder --vertical "Bad_Vertical" --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-05-01 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "X: non-kebab --vertical hard-fail" 2
  assert_substr "X: vertical kebab error" "vertical must be strict kebab-case"
}

run_y() {  # impossible-but-shaped date (Feb 30) — regex passes, fromisoformat rejects
  local out; out="$(mk_out Y)"
  invoke_builder --vertical municipalities --persona parks-rec-director --offer parks-bond \
    --entity nites --month 5 --year 2026 --launch-date 2026-02-30 \
    --eb-workspace emailbison-personal --owner-email marketingadmin@britenites.com \
    --created-at 2026-05-01T00:00:00Z --canonicals-dir "$CANON_DIR" --templates "$TEMPLATES" --out-dir "$out"
  assert_exit "Y: impossible date 2026-02-30 hard-fail" 2
  assert_substr "Y: launch-date error" "launch-date must be ISO"
}

run_z() {  # --disambiguator < 2 guard (must be >= 2; v1 is the base slug)
  local out; out="$(mk_out Z)"
  invoke_std "$out" --disambiguator 1
  assert_exit "Z: --disambiguator 1 hard-fail" 2
  assert_substr "Z: disambiguator error" "disambiguator must be an integer >= 2"
}

run_a; run_b; run_c; run_d; run_e; run_f; run_g; run_h; run_i; run_j
run_k; run_l; run_m; run_n; run_o; run_p; run_q; run_r; run_s
run_t; run_u; run_v; run_w; run_x; run_y; run_z

echo ""
echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
