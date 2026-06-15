#!/usr/bin/env bash
# M5 eval-gate self-test — "test the gate" (BC-12590, ADR-028 Phase-1).
#
# Two layers, both wired into validate.sh §15a-bc-12590:
#   1. PURE decision-core cases (scripts/eval/_eval_gate_cases.py) — looped in
#      lock-step via its --list (the _assert_cases.py idiom). They certify the
#      Split-A′ precedence ladder + the debt-list integrity invariants + the marker
#      parser, authored FROM THE LOCKED SPEC (not by reverse-engineering the draft).
#   2. I/O-shell INTEGRATION cases (this file) — drive the real `eval_gate.py`:
#      the git-diff changed-command detector (A/M/R in, D out; is_new from the ADD
#      status — the deterministic laundering close), the real lint_spec R1 wiring,
#      the real ADAPTERS eval run, the --name-status → decide() plumbing, and the
#      --check integrity lint (incl. the symmetric waiver↔row coupling).
#
# A red assertion here FAILS the build (a mandatory gate that can't silently vanish —
# the §15a-bc-12589 "a check nobody is forced to run rots" lesson).
#
# RESULT contract line drives the count (matches §2e / §15a-bc-12587/12588/12589).
#
# Usage: bash scripts/eval/test_eval_gate.sh

set -u  # NOT set -e — gate verdicts are asserted by inspecting exit code + output.

# Defuse the caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md) —
# doubly important here: the detector shells out to git against throw-away repos,
# and a leaked GIT_DIR would point those git commands at the caller's repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
GATE="$script_dir/eval_gate.py"
CASES="$script_dir/_eval_gate_cases.py"
REPO_ROOT="$(cd "$script_dir/../.." && pwd)"

for f in "$GATE" "$CASES"; do
  [ -f "$f" ] || { echo "FATAL: required file not found: $f" >&2; exit 2; }
done

pass=0
fail=0
LAST=""
LAST_RC=0

gate() {  # run the gate, capture combined output + rc into globals
  LAST="$(python3 "$GATE" "$@" 2>&1)"
  LAST_RC=$?
}

assert_rc() {  # label expected
  if [ "$LAST_RC" -eq "$2" ]; then
    echo "  PASS  $1 (exit=$LAST_RC)"; pass=$((pass + 1))
  else
    echo "  FAIL  $1 (expected exit=$2, got exit=$LAST_RC)"
    printf '%s\n' "$LAST" | tail -8 | sed 's/^/        | /'
    fail=$((fail + 1))
  fi
}

assert_rc_and_contains() {  # label expected_rc substring
  local ok=true
  [ "$LAST_RC" -eq "$2" ] || ok=false
  case "$LAST" in *"$3"*) ;; *) ok=false ;; esac
  if [ "$ok" = true ]; then
    echo "  PASS  $1 (exit=$LAST_RC, contains '$3')"; pass=$((pass + 1))
  else
    echo "  FAIL  $1 (expected exit=$2 + '$3', got exit=$LAST_RC)"
    printf '%s\n' "$LAST" | tail -8 | sed 's/^/        | /'
    fail=$((fail + 1))
  fi
}

assert_not_contains() {  # label substring
  case "$LAST" in
    *"$2"*) echo "  FAIL  $1 (unexpectedly contains '$2')";
            printf '%s\n' "$LAST" | tail -8 | sed 's/^/        | /'; fail=$((fail + 1)) ;;
    *)      echo "  PASS  $1 (absent '$2')"; pass=$((pass + 1)) ;;
  esac
}

# json_is — run a python predicate over the captured --json $LAST; PASS iff exit 0.
json_is() {  # label python-snippet
  if printf '%s' "$LAST" | python3 -c "$2" 2>/dev/null; then
    echo "  PASS  $1"; pass=$((pass + 1))
  else
    echo "  FAIL  $1"; printf '%s\n' "$LAST" | tail -6 | sed 's/^/        | /'; fail=$((fail + 1))
  fi
}

# ── isolated tmp + cleanup ─────────────────────────────────────────────────────
tmproot="$(mktemp -d -t evalgate-test.XXXXXX)" || { echo "FATAL: mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$tmproot"' EXIT

# Minimal valid command spec body (clean of advisory + R1 findings unless asked).
write_clean_cmd() {  # $1 = path
  mkdir -p "$(dirname "$1")"
  printf -- '---\nname: %s\ndescription: third-person summary of what it does and when to use it\n---\nA short body with no side effects.\n' "$(basename "$1" .md)" > "$1"
}

# A spec whose description trips R3 (gate-tier since BC-13213) — section F's fixture.
write_first_person_spec() {  # $1 = path, $2 = description
  mkdir -p "$(dirname "$1")"
  printf -- '---\nname: %s\ndescription: %s\n---\nbody\n' "$(basename "$1" .md)" "$2" > "$1"
}

# A clean spec with EXACTLY $2 body lines (frontmatter excluded — what body_lines /
# R2 measure). Used to drive the R2 (gate-tier since BC-13216) baseline pair: the
# named file must really exist with real body content or collect_body_counts finds
# no count and the baseline row blocks (the missing-count guard), not suppresses.
write_long_body_cmd() {  # $1 = path, $2 = body line count
  mkdir -p "$(dirname "$1")"
  {
    printf -- '---\nname: %s\ndescription: third-person summary of what it does and when to use it\n---\n' "$(basename "$1" .md)"
    i=1; while [ "$i" -le "$2" ]; do printf 'body line %d\n' "$i"; i=$((i + 1)); done
  } > "$1"
}

# ════════════════════════════════════════════════════════════════════════════
echo "── P. pure decision-core cases (scripts/eval/_eval_gate_cases.py, from spec) ──"
# ════════════════════════════════════════════════════════════════════════════
npure_listed=$(python3 "$CASES" --list | grep -c .)
npure_run=0
for case in $(python3 "$CASES" --list); do
  npure_run=$((npure_run + 1))
  if pure_out=$(python3 "$CASES" "$case" 2>&1); then
    echo "  PASS  pure:$case"; pass=$((pass + 1))
  else
    echo "  FAIL  pure:$case"; printf '%s\n' "$pure_out" | tail -4 | sed 's/^/        | /'; fail=$((fail + 1))
  fi
done
# The loop must visit every listed case (a silently-skipped case can't hide).
if [ "$npure_run" -ne "$npure_listed" ]; then
  echo "FATAL: ran $npure_run pure cases but --list has $npure_listed" >&2; exit 2
fi

# ════════════════════════════════════════════════════════════════════════════
echo "── A. changed-command detector (real git diff: A/M/R in, D out; is_new) ──"
# ════════════════════════════════════════════════════════════════════════════
gitrepo="$tmproot/gitrepo"
mkdir -p "$gitrepo" && cd "$gitrepo" || exit 2
git init -q -b main
git config user.email t@t && git config user.name t
write_clean_cmd plugins/foo/commands/keep.md
write_clean_cmd plugins/foo/commands/old.md
mkdir -p plugins/foo/skills/bar && printf -- '---\nname: bar\ndescription: x\n---\nbody\n' > plugins/foo/skills/bar/SKILL.md
printf 'doc\n' > README.md
git add -A && git commit -q -m baseline
git checkout -q -b feature
echo "more" >> plugins/foo/commands/keep.md                 # A1 modify (M)
write_clean_cmd plugins/foo/commands/added.md               # A2 add (A)
git mv plugins/foo/commands/old.md plugins/foo/commands/renamed.md  # A3 rename
echo "more" >> plugins/foo/skills/bar/SKILL.md              # A5 non-command
echo "more" >> README.md
git add -A && git commit -q -m changes
cd "$REPO_ROOT" || exit 2

gate --repo-root "$gitrepo" --base-ref main --head-ref HEAD --json
json_is "A1 modified command detected, is_new=false" \
  "import json,sys; c={x['command']:x['is_new'] for x in json.load(sys.stdin)['changed']}; sys.exit(0 if c.get('plugins/foo/commands/keep.md') is False else 1)"
json_is "A2 added command detected, is_new=true" \
  "import json,sys; c={x['command']:x['is_new'] for x in json.load(sys.stdin)['changed']}; sys.exit(0 if c.get('plugins/foo/commands/added.md') is True else 1)"
json_is "A3/A4 renamed-new is_new=true; deleted source dropped" \
  "import json,sys; c={x['command']:x['is_new'] for x in json.load(sys.stdin)['changed']}; sys.exit(0 if c.get('plugins/foo/commands/renamed.md') is True and 'plugins/foo/commands/old.md' not in c else 1)"
assert_not_contains "A5a modified skill NOT counted" 'skills/bar/SKILL.md'
assert_not_contains "A5b modified doc NOT counted" 'README.md'

# A6 pure deletion drops out entirely
cd "$gitrepo" || exit 2; git checkout -q main; git checkout -q -b del-only
git rm -q plugins/foo/commands/keep.md; git commit -q -m "delete keep"
cd "$REPO_ROOT" || exit 2
gate --repo-root "$gitrepo" --base-ref main --head-ref HEAD
assert_rc_and_contains "A6 pure deletion → changed=0, exit 0" 0 "GATE changed=0 blocked=0"

# ════════════════════════════════════════════════════════════════════════════
echo "── B. decision integration via --name-status (is_new = A vs M) ──"
# ════════════════════════════════════════════════════════════════════════════
synth="$tmproot/synth"
mkdir -p "$synth/docs"
write_clean_cmd "$synth/plugins/foo/commands/grand.md"
printf -- '---\nname: sideeffect\ndescription: third-person summary of what it does and when to use it\nallowed-tools: mcp__plugin_workflows_linear-server__create_issue\n---\nBody that runs gh pr create and git push.\n' > "$synth/plugins/foo/commands/sideeffect.md"
cat > "$synth/docs/skill-eval-debt.md" <<'EOF'
# debt
| command | plugin | status | reason | added |
|---|---|---|---|---|
| `plugins/foo/commands/grand.md` | foo | grandfathered | no-eval | 2026-06-08 |
| `plugins/foo/commands/sideeffect.md` | foo | grandfathered | no-eval; R1 side-effecting | 2026-06-08 |
EOF

# B1 grandfathered + MODIFIED (M) → EXEMPT
gate --repo-root "$synth" --name-status "$(printf 'M\tplugins/foo/commands/grand.md')"
assert_rc_and_contains "B1 grandfathered MODIFIED → EXEMPT, exit 0" 0 "EXEMPT plugins/foo/commands/grand.md"
# B1b LAUNDERING CLOSE: grandfathered but ADDED (A) → BLOCK (a debt row can't clear a net-new add)
gate --repo-root "$synth" --name-status "$(printf 'A\tplugins/foo/commands/grand.md')"
assert_rc_and_contains "B1b grandfathered-as-ADD → BLOCK (laundering close)" 1 "cannot be grandfathered by a debt row"
# B2 Split-A′ keystone: grandfathered R1 (M) STILL blocks on structural
gate --repo-root "$synth" --name-status "$(printf 'M\tplugins/foo/commands/sideeffect.md')"
assert_rc_and_contains "B2 grandfathered R1 still BLOCKS (Split A′)" 1 "R1-side-effecting-needs-flag"
# B3 net-new (A), not listed → BLOCK
write_clean_cmd "$synth/plugins/foo/commands/netnew.md"
gate --repo-root "$synth" --name-status "$(printf 'A\tplugins/foo/commands/netnew.md')"
assert_rc_and_contains "B3 net-new → BLOCK" 1 "net-new command with no behavioral eval"
# B4 net-new (A) + valid waiver → exit 0
write_clean_cmd "$synth/plugins/foo/commands/waived.md"
printf '\n<!-- eval-waiver: pure interactive interview, no artifact to assert -->\n' >> "$synth/plugins/foo/commands/waived.md"
gate --repo-root "$synth" --name-status "$(printf 'A\tplugins/foo/commands/waived.md')"
assert_rc_and_contains "B4 net-new + valid waiver → WAIVER, exit 0" 0 "eval-waiver accepted: pure interactive"
# B5 net-new (A) + EMPTY waiver → BLOCK
write_clean_cmd "$synth/plugins/foo/commands/emptywaiver.md"
printf '\n# eval-waiver:\n' >> "$synth/plugins/foo/commands/emptywaiver.md"
gate --repo-root "$synth" --name-status "$(printf 'A\tplugins/foo/commands/emptywaiver.md')"
assert_rc_and_contains "B5 net-new + empty waiver → BLOCK" 1 "has no <reason>"
# B6 prose mention of the token (A) must NOT suppress
write_clean_cmd "$synth/plugins/foo/commands/prosewaiver.md"
printf '\nThis command would say `eval-waiver: not really` in its docs.\n' >> "$synth/plugins/foo/commands/prosewaiver.md"
gate --repo-root "$synth" --name-status "$(printf 'A\tplugins/foo/commands/prosewaiver.md')"
assert_rc_and_contains "B6 prose mention does NOT suppress" 1 "net-new command with no behavioral eval"
assert_not_contains "B6b prose mention NOT parsed as a waiver" "eval-waiver accepted"
# B7 side-effecting + disable-model-invocation flag + grandfathered (M) → EXEMPT
printf -- '---\nname: flagged\ndescription: third-person summary of what it does and when to use it\nallowed-tools: mcp__plugin_workflows_linear-server__create_issue\ndisable-model-invocation: true\n---\nBody that runs git push.\n' > "$synth/plugins/foo/commands/flagged.md"
cat >> "$synth/docs/skill-eval-debt.md" <<'EOF'
| `plugins/foo/commands/flagged.md` | foo | grandfathered | no-eval | 2026-06-08 |
EOF
gate --repo-root "$synth" --name-status "$(printf 'M\tplugins/foo/commands/flagged.md')"
assert_rc_and_contains "B7 side-effecting + flag + grandfathered → EXEMPT" 0 "EXEMPT plugins/foo/commands/flagged.md"
# B8 mixed diff — count arithmetic + per-command independence (grand M exempt + netnew A block)
gate --repo-root "$synth" --name-status "$(printf 'M\tplugins/foo/commands/grand.md\nA\tplugins/foo/commands/netnew.md')"
assert_rc_and_contains "B8 mixed (grandfathered M + net-new A) → changed=2 blocked=1" 1 "GATE changed=2 blocked=1"

# B9 fork-① (BC-13216): R2 is gate-tier, but the diff-gate can't read the structural
# debt baselines (only --structural can), so editing a grandfathered >=500-line
# COMMAND must NOT be blocked on R2 here — else every typo-fix to one of the 13
# grandfathered commands is wedged with no escape. The flip drops R2 from
# structural_gate_reasons; --structural (full-surface, every PR) stays R2's authority.
write_long_body_cmd "$synth/plugins/foo/commands/longgrand.md" 520
cat >> "$synth/docs/skill-eval-debt.md" <<'EOF'
| `plugins/foo/commands/longgrand.md` | foo | grandfathered | no-eval | 2026-06-14 |
EOF
gate --repo-root "$synth" --name-status "$(printf 'M\tplugins/foo/commands/longgrand.md')"
assert_rc_and_contains "B9 grandfathered >=500-line command MODIFIED → EXEMPT (R2 not diff-gated)" 0 "EXEMPT plugins/foo/commands/longgrand.md"
assert_not_contains "B9b R2 is NOT a diff-gate block reason post-flip" "R2-body-too-long"
# B10 surgical proof, CO-LOCATED on one file: a >=500-line body (R2 gate) AND a
# first-person description (R3 gate) on the SAME changed command. The diff-gate must
# drop ONLY R2 — so it still BLOCKS on R3 (retained) and never names R2 as a reason.
# Co-locating both rules on one file proves the exclusion is per-rule, not "drop all
# structural" (B10b is RED on the pre-filter code where R2 is also a block reason).
mkdir -p "$synth/plugins/foo/commands"
{
  printf -- '---\nname: fpgrand\ndescription: I will do things for you\n---\n'
  i=1; while [ "$i" -le 500 ]; do printf 'body line %d\n' "$i"; i=$((i + 1)); done
} > "$synth/plugins/foo/commands/fpgrand.md"
cat >> "$synth/docs/skill-eval-debt.md" <<'EOF'
| `plugins/foo/commands/fpgrand.md` | foo | grandfathered | no-eval | 2026-06-14 |
EOF
gate --repo-root "$synth" --name-status "$(printf 'M\tplugins/foo/commands/fpgrand.md')"
assert_rc_and_contains "B10 same-file R2+R3 → still BLOCKS on R3 (retained, filter is surgical)" 1 "R3-description-quality"
assert_not_contains "B10b same-file R2+R3 → R2 dropped, not a diff-gate block reason" "R2-body-too-long"

# ════════════════════════════════════════════════════════════════════════════
echo "── C. integration against the real repo ──"
# ════════════════════════════════════════════════════════════════════════════
gate --name-status "$(printf 'M\tplugins/marketing/commands/plan-campaign.md')"
assert_rc_and_contains "C1 real plan-campaign (ADAPTERS eval runs + passes) → OK" 0 "behavioral eval registered and passing"
gate --check
assert_rc_and_contains "C2 real --check on the bootstrapped debt list → OK" 0 "debt ∩ ADAPTERS == ∅"
# C3′ fixture = capture-idea.md, now EVAL'd (BC-13161): it is in ADAPTERS + flagged
# (disable-model-invocation), so a MODIFIED capture-idea runs its registered behavioral
# eval and PASSES (R1 satisfied by the flag) → exit 0. The C1 pattern on a second
# command — the only PERMANENT end-to-end exercise of `run_eval.py capture-idea` through
# the gate (the builder unit suite tests decide() directly; the diff-gate fires only on
# .md changes). The Split-A′ "grandfathered + R1 still BLOCKS" point is covered
# hermetically by the synthetic B2 above: capture-idea was the LAST grandfathered +
# R1-firing command, so no real-repo fixture for that case remains (ship.md is flagged
# + waived) — hence C3 moves from the Split-A′ proof to the eval-registered proof.
gate --name-status "$(printf 'M\tplugins/marketing/commands/capture-idea.md')"
assert_rc_and_contains "C3 real eval'd capture-idea.md runs its eval + passes (exit 0)" 0 "behavioral eval registered and passing"

# ════════════════════════════════════════════════════════════════════════════
echo "── D. --check integrity failure modes (synthetic) ──"
# ════════════════════════════════════════════════════════════════════════════
# D1 missing: a surface command with no debt row + no eval
chk="$tmproot/chk_missing"; mkdir -p "$chk/docs"
write_clean_cmd "$chk/plugins/foo/commands/unlisted.md"
printf -- '# debt\n| command | plugin | status | reason | added |\n|---|---|---|---|---|\n' > "$chk/docs/skill-eval-debt.md"
gate --repo-root "$chk" --check
assert_rc_and_contains "D1 unlisted command → PROBLEM missing" 1 "neither eval'd (ADAPTERS) nor on the debt list"
# D2 stale: debt row for a command not on the surface
chk2="$tmproot/chk_stale"; mkdir -p "$chk2/docs"
write_clean_cmd "$chk2/plugins/foo/commands/real.md"
cat > "$chk2/docs/skill-eval-debt.md" <<'EOF'
# debt
| command | plugin | status | reason | added |
|---|---|---|---|---|
| `plugins/foo/commands/real.md` | foo | grandfathered | no-eval | 2026-06-08 |
| `plugins/foo/commands/deleted.md` | foo | grandfathered | no-eval | 2026-06-08 |
EOF
gate --repo-root "$chk2" --check
assert_rc_and_contains "D2 stale debt row → PROBLEM stale" 1 "deleted/renamed"
# D3 overlap: a command both eval'd (ADAPTERS basename) AND debt-listed
chk3="$tmproot/chk_overlap"; mkdir -p "$chk3/docs"
write_clean_cmd "$chk3/plugins/marketing/commands/plan-campaign.md"
cat > "$chk3/docs/skill-eval-debt.md" <<'EOF'
# debt
| command | plugin | status | reason | added |
|---|---|---|---|---|
| `plugins/marketing/commands/plan-campaign.md` | marketing | grandfathered | no-eval | 2026-06-08 |
EOF
gate --repo-root "$chk3" --check
assert_rc_and_contains "D3 eval'd AND debt-listed → PROBLEM overlap" 1 "debt ∩ ADAPTERS must be ∅"
# D4 ambiguous bare id: two commands with an ADAPTERS basename across plugins
chk4="$tmproot/chk_ambig"; mkdir -p "$chk4/docs"
write_clean_cmd "$chk4/plugins/a/commands/plan-campaign.md"
write_clean_cmd "$chk4/plugins/b/commands/plan-campaign.md"
printf -- '# debt\n| command | plugin | status | reason | added |\n|---|---|---|---|---|\n' > "$chk4/docs/skill-eval-debt.md"
gate --repo-root "$chk4" --check
assert_rc_and_contains "D4 colliding ADAPTERS basename → PROBLEM ambiguous" 1 "is ambiguous"
# D5 waiver row WITHOUT an in-file marker → coupling problem (silent waiver, one direction)
chk5="$tmproot/chk_wv_norow"; mkdir -p "$chk5/docs"
write_clean_cmd "$chk5/plugins/foo/commands/wv.md"   # no marker
cat > "$chk5/docs/skill-eval-debt.md" <<'EOF'
# debt
| command | plugin | status | reason | added |
|---|---|---|---|---|
| `plugins/foo/commands/wv.md` | foo | waiver | genuinely unevaluable | 2026-06-08 |
EOF
gate --repo-root "$chk5" --check
assert_rc_and_contains "D5 status=waiver row w/o in-file marker → PROBLEM" 1 "status=waiver but the command file has no"
# D6 in-file marker with a non-waiver debt row → coupling problem (other direction)
chk6="$tmproot/chk_mk_wrong"; mkdir -p "$chk6/docs"
write_clean_cmd "$chk6/plugins/foo/commands/mk.md"
printf '\n# eval-waiver: genuinely unevaluable\n' >> "$chk6/plugins/foo/commands/mk.md"
cat > "$chk6/docs/skill-eval-debt.md" <<'EOF'
# debt
| command | plugin | status | reason | added |
|---|---|---|---|---|
| `plugins/foo/commands/mk.md` | foo | grandfathered | no-eval | 2026-06-08 |
EOF
gate --repo-root "$chk6" --check
assert_rc_and_contains "D6 in-file marker + non-waiver row → PROBLEM (should be status=waiver)" 1 "should be status=waiver"

# ════════════════════════════════════════════════════════════════════════════
echo "── E. exit-code contract (could-not-run = 2, distinct from a block) ──"
# ════════════════════════════════════════════════════════════════════════════
gate --repo-root "$gitrepo" --base-ref no-such-ref --head-ref HEAD
assert_rc_and_contains "E1 unresolvable diff base → exit 2 + reason" 2 "could not resolve the diff base"
gate --bootstrap   # missing --added
assert_rc_and_contains "E2 --bootstrap without --added → exit 2 + reason" 2 "requires --added"

# ════════════════════════════════════════════════════════════════════════════
echo "── F. --structural full-surface gate (ADR-034, BC-13213) ──"
# ════════════════════════════════════════════════════════════════════════════
# F1 real repo: a WIRING probe only — the mode dispatches, scans the live surface,
# and emits the STRUCTURAL contract line with a policy verdict (exit 0 or 1, never
# 2). Deliberately NOT asserting blocking=0: live-surface cleanliness is the job of
# validate.sh §15a-bc-12590 Part 3 + the REQUIRED CI step (which run this same
# command), and a self-test that reds on an unrelated dirty working tree conflates
# "gate broken" with "surface dirty" (review-verifier ruling, BC-13213).
gate --structural
if { [ "$LAST_RC" -eq 0 ] || [ "$LAST_RC" -eq 1 ]; } && printf '%s' "$LAST" | grep -qE '^STRUCTURAL blocking=[0-9]+ suppressed=[0-9]+ problems=[0-9]+$'; then
  echo "  PASS  F1 real repo --structural → runs + emits contract line (exit=$LAST_RC)"; pass=$((pass + 1))
else
  echo "  FAIL  F1 real repo --structural — expected exit 0|1 + STRUCTURAL contract line (got exit=$LAST_RC)"
  printf '%s\n' "$LAST" | tail -8 | sed 's/^/        | /'
  fail=$((fail + 1))
fi

# F2 a first-person COMMAND description blocks (R3 is gate-tier now).
st="$tmproot/structural"; mkdir -p "$st/docs"
write_clean_cmd "$st/plugins/foo/commands/ok.md"
write_first_person_spec "$st/plugins/foo/commands/badcmd.md" "I will do things for you"
gate --repo-root "$st" --structural
assert_rc_and_contains "F2 first-person command description → BLOCK (R3 gate)" 1 "R3-description-quality"

# F3 a first-person SKILL description blocks too — the surface the commands-only
# diff-gate can NOT see (the reason --structural is full-surface, ADR-034).
write_first_person_spec "$st/plugins/foo/skills/badskill/SKILL.md" "I am a skill that helps"
gate --repo-root "$st" --structural
assert_rc_and_contains "F3 first-person SKILL description → BLOCK (skills covered)" 1 "plugins/foo/skills/badskill/SKILL.md"

# F4 structural-debt rows suppress exactly their (file, rule) → exit 0.
cat > "$st/docs/structural-lint-debt.md" <<'EOF'
| file | rule | reason | added | baseline |
|---|---|---|---|---|
| `plugins/foo/commands/badcmd.md` | R3-description-quality | self-test grandfather | 2026-06-10 |  |
| `plugins/foo/skills/badskill/SKILL.md` | R3-description-quality | self-test grandfather | 2026-06-10 |  |
EOF
gate --repo-root "$st" --structural
assert_rc_and_contains "F4 debt rows suppress listed (file,rule) → exit 0" 0 "STRUCTURAL blocking=0 suppressed=2"

# F5 a stale row (no live finding for that (file,rule)) → PROBLEM, exit 1.
cat >> "$st/docs/structural-lint-debt.md" <<'EOF'
| `plugins/foo/commands/ok.md` | R3-description-quality | not actually violating | 2026-06-10 |  |
EOF
gate --repo-root "$st" --structural
assert_rc_and_contains "F5 stale debt row → PROBLEM, exit 1" 1 "stale structural-debt row"

# F6 a malformed baseline is a loud problem AND the row does not suppress.
st2="$tmproot/structural2"; mkdir -p "$st2/docs"
write_first_person_spec "$st2/plugins/foo/commands/badcmd2.md" "I will do more things"
cat > "$st2/docs/structural-lint-debt.md" <<'EOF'
| file | rule | reason | added | baseline |
|---|---|---|---|---|
| `plugins/foo/commands/badcmd2.md` | R3-description-quality | bad baseline | 2026-06-10 | lots |
EOF
gate --repo-root "$st2" --structural
assert_rc_and_contains "F6 malformed baseline → PROBLEM (row does not suppress)" 1 "malformed baseline"

# ── R2 baseline end-to-end pair (BC-13216) — the integration BC-13213 deferred ──
# R2 is gate-tier now, so the full-surface gate finally sees a real R2 gate finding
# to suppress-by-baseline / block-on-growth. Each of F7-F9 is non-vacuous: on the
# pre-flip (advisory) lint, filter_structural skips the finding (severity != gate)
# so F8/F9 would exit 0 and F7 would report suppressed=0 — all RED before the flip.
# F7 baseline suppression: body == baseline (the <= boundary) → SUPPRESSED, exit 0.
st3="$tmproot/structural3"; mkdir -p "$st3/docs"
write_long_body_cmd "$st3/plugins/foo/commands/big.md" 500
cat > "$st3/docs/structural-lint-debt.md" <<'EOF'
| file | rule | reason | added | baseline |
|---|---|---|---|---|
| `plugins/foo/commands/big.md` | R2-body-too-long | self-test grandfather | 2026-06-14 | 500 |
EOF
gate --repo-root "$st3" --structural
assert_rc_and_contains "F7 R2 body == baseline (500) → SUPPRESSED, exit 0" 0 "STRUCTURAL blocking=0 suppressed=1"

# F8 growth-block: body == baseline + 1 (the +1 boundary) → BLOCK, exit 1.
st4="$tmproot/structural4"; mkdir -p "$st4/docs"
write_long_body_cmd "$st4/plugins/foo/commands/grew.md" 501
cat > "$st4/docs/structural-lint-debt.md" <<'EOF'
| file | rule | reason | added | baseline |
|---|---|---|---|---|
| `plugins/foo/commands/grew.md` | R2-body-too-long | self-test grandfather | 2026-06-14 | 500 |
EOF
gate --repo-root "$st4" --structural
assert_rc_and_contains "F8 R2 body grew past baseline (501 > 500) → BLOCK, exit 1" 1 "past the grandfathered baseline"

# F9 fresh-bloat: a fresh >=500-line spec with NO debt row → BLOCK, exit 1.
st5="$tmproot/structural5"; mkdir -p "$st5/docs"
write_long_body_cmd "$st5/plugins/foo/commands/fresh.md" 500
printf -- '| file | rule | reason | added | baseline |\n|---|---|---|---|---|\n' > "$st5/docs/structural-lint-debt.md"
gate --repo-root "$st5" --structural
assert_rc_and_contains "F9 fresh >=500-line spec, no debt row → BLOCK, exit 1" 1 "R2-body-too-long"

# ── R4 reference-edit fresh-violation (graph-shaped, BC-13217 ratchet 5/5) ──────
# R4 is GRAPH-shaped (ADR-034's raison d'être): a chain regression can be introduced
# by editing a bundled REFERENCE file, with NO spec (SKILL.md) in the diff at all —
# invisible to the commands-only changed-set diff-gate, which is exactly why
# --structural is full-surface. Two-step proof: a clean one-level skill, then a
# refA→refB edit (refB really exists under the skill dir, resolved relative to refA)
# flips it to blocking with SKILL.md untouched. Non-vacuous: on the pre-flip
# (advisory) R4, filter_structural skips the finding (severity != gate) → F11 exits
# 0 — RED before the flip (F10 is clean either way; F11 is the discriminating case).
sk6="$tmproot/structural6/plugins/foo/skills/chain"; mkdir -p "$sk6"
printf -- '---\nname: chain\ndescription: third-person summary of what it does and when to use it\n---\nFor details see `refA.md` in this directory.\n' > "$sk6/SKILL.md"
printf -- '# Reference A\n\nOne level deep — no further bundled pointers.\n' > "$sk6/refA.md"
printf -- '# Reference B\n\nLeaf reference.\n' > "$sk6/refB.md"   # exists, UNREFERENCED yet
gate --repo-root "$tmproot/structural6" --structural
assert_rc_and_contains "F10 one-level skill ref (refB exists but unreferenced) → clean, exit 0" 0 "STRUCTURAL blocking=0 suppressed=0 problems=0"

# F11 edit ONLY refA to point at the existing refB — a bundled reference-file edit,
# NO SKILL.md change → the chain now resolves → BLOCK on R4.
printf -- '\nSee `refB.md` for the second hop.\n' >> "$sk6/refA.md"
gate --repo-root "$tmproot/structural6" --structural
assert_rc_and_contains "F11 refA→refB added (no SKILL.md change) → BLOCK on R4, exit 1" 1 "R4-nested-refs"

# ── exact count — a silently-skipped (or silently-added) assertion fails loudly ─
# Total = the (dynamic) pure-case count + the fixed integration-assertion count.
# `set -u` (not -e): a mid-section setup failure changes WHAT later assertions test
# without aborting, so assert the EXACT total — catches a 1-assertion skip AND forces
# EXPECTED_INTEGRATION to move in lockstep when integration assertions are added.
echo ""
EXPECTED_INTEGRATION=42
EXPECTED_TOTAL=$((npure_listed + EXPECTED_INTEGRATION))
if [ "$((pass + fail))" -ne "$EXPECTED_TOTAL" ]; then
  echo "FATAL: $((pass + fail)) assertions ran, expected exactly $EXPECTED_TOTAL ($npure_listed pure + $EXPECTED_INTEGRATION integration) — a block was skipped or added without updating EXPECTED_INTEGRATION" >&2
  exit 2
fi

echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
