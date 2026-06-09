#!/usr/bin/env bash
# Behavioral-eval harness self-test — "test the tester" (BC-12589, ADR-028 § 5).
#
# This is the single validate.sh-wired entrypoint for the eval spine. It proves
# the harness is trustworthy BOTH directions in one place (the originating-session
# review's requirement + DP2-7's non-negotiable AC):
#
#   1. M3 assertion-lib unit cases — every assert_lib primitive, PASS and FAIL
#      (schema / golden / key-field / contains / no_match), via _assert_cases.py.
#   2. The first plan-campaign behavioral eval runs GREEN — known-good fixture →
#      emit (build_manifest.py directly, DP2-4) → all assertions pass. This is the
#      "plan-campaign eval green in CI" AC; validate.sh fails if it goes red.
#   3. The M2 self-test — feed deliberately MUTATED emit artifacts (flip a
#      blockedBy index / change a dueDate / drop a label / break the slug /
#      un-null a manifest ID / drop a description contract line / reintroduce a
#      brief {{slot}} / corrupt a field type) → the runner exits non-zero AND
#      names the specific diff. Proves a red eval actually fails the build.
#   4. Hermeticity — the eval imports no network module and runs to green with
#      ANTHROPIC_API_KEY unset from an empty cwd, writing nothing outside its
#      sandbox (build_manifest's purity-test idiom; DP2-4 no-API-key contract).
#
# RESULT contract line drives the count (matches §15a-bc-12587 / §2e).
#
# Usage:  bash scripts/eval/test_eval_harness.sh

set -u  # NOT set -e — non-zero exits are EXPECTED for the mutation scenarios.

# Defuse the caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md;
# matches test_build_manifest.sh / test_portfolio_snapshot.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$script_dir/../.." && pwd)"
RUN_EVAL="$script_dir/run_eval.py"
CASES="$script_dir/_assert_cases.py"
ASSERT_LIB="$script_dir/assert_lib.py"

for required in "$RUN_EVAL" "$CASES" "$ASSERT_LIB"; do
  if [ ! -f "$required" ]; then
    echo "FATAL: required file not found: $required" >&2
    exit 2
  fi
done

tmproot="$(mktemp -d -t eval-harness-test.XXXXXX)" || {
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
mutid=0
LAST_OUTPUT=""
LAST_RC=0

# ── helpers ────────────────────────────────────────────────────────────────

invoke() {  # python3 <args...> → captures combined output + rc
  LAST_OUTPUT="$(python3 "$@" 2>&1)"
  LAST_RC=$?
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
  if printf '%s' "$LAST_OUTPUT" | grep -qF -- "$rx"; then
    echo "  PASS  $label"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — substring not in output: $rx"
    printf '    output: %s\n' "$LAST_OUTPUT"; fail=$((fail + 1))
  fi
}

# ── 1. M3 assertion-lib unit cases (pass + fail per primitive) ───────────────

echo "── M3 assertion-lib unit cases ──"
m3_cases="$(python3 "$CASES" --list)"
m3_count="$(printf '%s\n' "$m3_cases" | grep -c .)"
if [ "$m3_count" -lt 1 ]; then
  echo "FATAL: _assert_cases.py --list returned no cases — the M3 layer would silently vanish" >&2
  exit 2
fi
for c in $m3_cases; do
  invoke "$CASES" "$c"
  assert_exit "M3 case: $c" 0
done

# ── 2. first plan-campaign eval runs GREEN ───────────────────────────────────

echo "── plan-campaign eval (known-good → GREEN) ──"
GOOD="$tmproot/good"; mkdir -p "$GOOD"
invoke "$RUN_EVAL" plan-campaign --sandbox "$GOOD"
assert_exit "eval GREEN — known-good fixture builds + passes" 0
assert_substr "eval prints PASS verdict" "PASS: plan-campaign eval"

invoke "$RUN_EVAL" plan-campaign
assert_exit "eval GREEN — default mktemp invocation (the CI form)" 0

# Sanity: the three artifacts were produced.
for art in manifest.json issues.json brief.md; do
  if [ -f "$GOOD/$art" ]; then
    echo "  PASS  artifact produced: $art"; pass=$((pass + 1))
  else
    echo "  FAIL  artifact missing: $art"; fail=$((fail + 1))
  fi
done

# ── 3. M2 self-test — mutated artifacts must fail RED with a named diff ───────

echo "── M2 self-test (mutated artifacts → RED) ──"
mutate_and_assert() {  # label  expected_substr  python_mutation
  local label="$1" rx="$2" code="$3"
  local M="$tmproot/mut.$((mutid++))"; mkdir -p "$M"
  cp "$GOOD/manifest.json" "$GOOD/issues.json" "$GOOD/brief.md" "$M/"
  if ! MUT_DIR="$M" python3 -c "
import json, os, pathlib
M = pathlib.Path(os.environ['MUT_DIR'])
$code
"; then
    echo "  FAIL  mutation setup failed: $label"; fail=$((fail + 1)); return
  fi
  invoke "$RUN_EVAL" plan-campaign --artifact-dir "$M"
  assert_exit "mutation '$label' → red (exit 1)" 1
  assert_substr "mutation '$label' → named diff" "$rx"
}

mutate_and_assert "flip blockedBy index" "golden 1, got 6" \
  'p=M/"issues.json"; d=json.load(open(p)); d["issues"][1]["blockedBy"]=[6]; json.dump(d,open(p,"w"))'
mutate_and_assert "change a dueDate" "dueDate: golden '2026-04-10', got '2026-04-11'" \
  'p=M/"issues.json"; d=json.load(open(p)); d["issues"][0]["dueDate"]="2026-04-11"; json.dump(d,open(p,"w"))'
mutate_and_assert "drop a label" "array length mismatch" \
  'p=M/"issues.json"; d=json.load(open(p)); d["issues"][2]["labels"].pop(); json.dump(d,open(p,"w"))'
mutate_and_assert "break the slug" "container.title: golden" \
  'p=M/"issues.json"; d=json.load(open(p)); d["container"]["title"]="WRONG-SLUG"; json.dump(d,open(p,"w"))'
mutate_and_assert "un-null a manifest id" "milestone_id: expected None, got" \
  'p=M/"manifest.json"; d=json.load(open(p)); d["linear"]["milestone_id"]="LIN-123"; json.dump(d,open(p,"w"))'
mutate_and_assert "drop a description contract line" "missing required substring" \
  'p=M/"issues.json"; d=json.load(open(p)); d["issues"][3]["description"]=d["issues"][3]["description"].replace("**Handbook citation**:","REMOVED:"); json.dump(d,open(p,"w"))'
mutate_and_assert "reintroduce a brief slot token" "leftover template slot" \
  'p=M/"brief.md"; p.write_text(p.read_text()+"\n{{slug}}\n")'
mutate_and_assert "corrupt a field type" "expected type integer, got string" \
  'p=M/"manifest.json"; d=json.load(open(p)); d["month"]="05"; json.dump(d,open(p,"w"))'
# Structural breaks must surface as named SCHEMA diffs (exit 1), never a traceback.
mutate_and_assert "drop an issue key" "required key missing" \
  'p=M/"issues.json"; d=json.load(open(p)); del d["issues"][0]["blockedBy"]; json.dump(d,open(p,"w"))'
mutate_and_assert "issues.json is not an object" "expected type object" \
  'p=M/"issues.json"; json.dump([], open(p,"w"))'
mutate_and_assert "leak an extra manifest key" "unexpected property" \
  'p=M/"manifest.json"; d=json.load(open(p)); d["backdoor"]="x"; json.dump(d,open(p,"w"))'
mutate_and_assert "leak an extra issue key" "unexpected property" \
  'p=M/"issues.json"; d=json.load(open(p)); d["issues"][0]["extra"]="x"; json.dump(d,open(p,"w"))'
# Deterministic value regressions that schema-type alone would miss.
mutate_and_assert "non-deterministic created_at" "created_at: expected" \
  'p=M/"manifest.json"; d=json.load(open(p)); d["created_at"]="2099-01-01T00:00:00Z"; json.dump(d,open(p,"w"))'
mutate_and_assert "wrong linear project" "linear.project: expected 'Brite GTM'" \
  'p=M/"manifest.json"; d=json.load(open(p)); d["linear"]["project"]="Wrong"; json.dump(d,open(p,"w"))'
mutate_and_assert "wipe container description" "container.description" \
  'p=M/"issues.json"; d=json.load(open(p)); d["container"]["description"]="WIPED"; json.dump(d,open(p,"w"))'

# Infra errors (a failed/absent emit) surface as exit 2, distinct from a diff.
echo "── infra-error exit codes ──"
EMPTY="$tmproot/empty"; mkdir -p "$EMPTY"
invoke "$RUN_EVAL" plan-campaign --artifact-dir "$EMPTY"
assert_exit "missing artifacts → exit 2 (infra error, not a diff)" 2
invoke "$RUN_EVAL" no-such-command
assert_exit "unknown command-id → exit 2" 2

# ── 3b. create-sf-campaign eval (BC-12701 — the side-effecting representative) ─
# The SECOND registered command: its default run MUTATES external state (creates a
# Salesforce Campaign). Its emit-mode builder (build_campaign_payload.py) is driven
# over a SCENARIO MATRIX so the GREEN run exercises every verdict branch, then the
# mutation cases prove a red diff — including an IDEMPOTENCY regression (the
# duplicate verdict flipped to would_create), the load-bearing behavior this
# command's eval exists to catch (ADR-028: "green tests on a command that never
# ran"). Same shape as the plan-campaign block above; reuses invoke/assert_*.
echo "── create-sf-campaign eval (BC-12701 — known-good → GREEN) ──"
CSF="$tmproot/csf"; mkdir -p "$CSF"
invoke "$RUN_EVAL" create-sf-campaign --sandbox "$CSF"
assert_exit "create-sf-campaign eval GREEN — known-good matrix builds + passes" 0
assert_substr "create-sf-campaign eval prints PASS verdict" "PASS: create-sf-campaign eval"
if [ -f "$CSF/campaign-emit.json" ]; then
  echo "  PASS  artifact produced: campaign-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: campaign-emit.json"; fail=$((fail + 1))
fi

echo "── create-sf-campaign self-test (mutated matrix → RED) ──"
mutate_csf() {  # label  expected_substr  python_mutation (M = artifact dir)
  local label="$1" rx="$2" code="$3"
  local M="$tmproot/csfmut.$((mutid++))"; mkdir -p "$M"
  cp "$CSF/campaign-emit.json" "$M/"
  if ! MUT_DIR="$M" python3 -c "
import json, os, pathlib
M = pathlib.Path(os.environ['MUT_DIR'])
$code
"; then
    echo "  FAIL  mutation setup failed: $label"; fail=$((fail + 1)); return
  fi
  invoke "$RUN_EVAL" create-sf-campaign --artifact-dir "$M"
  assert_exit "csf mutation '$label' → red (exit 1)" 1
  assert_substr "csf mutation '$label' → named diff" "$rx"
}

mutate_csf "idempotency regression (dup→create)" "golden 'would_skip_duplicate', got 'would_create'" \
  'p=M/"campaign-emit.json"; d=json.load(open(p)); [s.update(verdict="would_create", output=None) for s in d["scenarios"] if s["id"]=="duplicate_slug"]; json.dump(d,open(p,"w"))'
mutate_csf "un-null a campaign_id (no-write invariant)" "expected type null, got string" \
  'p=M/"campaign-emit.json"; d=json.load(open(p)); d["scenarios"][0]["campaign_id"]="701WROTE"; json.dump(d,open(p,"w"))'
mutate_csf "corrupt a payload field" "payload.OwnerId: golden" \
  'p=M/"campaign-emit.json"; d=json.load(open(p)); d["scenarios"][0]["payload"]["OwnerId"]="005WRONG"; json.dump(d,open(p,"w"))'
mutate_csf "leak an extra scenario key" "unexpected property" \
  'p=M/"campaign-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'
mutate_csf "drop the idempotency scenario" "expected scenario id 'duplicate_slug' is absent" \
  'p=M/"campaign-emit.json"; d=json.load(open(p)); d["scenarios"]=[s for s in d["scenarios"] if s["id"]!="duplicate_slug"]; json.dump(d,open(p,"w"))'
mutate_csf "flip a verdict to an off-enum value" "is not one of enum" \
  'p=M/"campaign-emit.json"; d=json.load(open(p)); d["scenarios"][0]["verdict"]="ship_it"; json.dump(d,open(p,"w"))'
# dedup-EXACTNESS regression: a different-slug row wrongly classified as a duplicate
# (the near_miss scenario flipped would_create→would_skip_duplicate) — the symmetric
# twin of the idempotency regression above, proving the harness names that diff too.
mutate_csf "near-miss wrongly deduped" "scenarios[2].verdict: golden 'would_create'" \
  'p=M/"campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="near_miss_not_duplicate"][0]; s.update(verdict="would_skip_duplicate", payload=None, output={"error":"duplicate_slug","existing_id":"701X"}); json.dump(d,open(p,"w"))'

# ── 3b2. update-sf-campaign-status eval (BC-12942 — the σ3 side-effecting sibling) ─
# The σ3 sibling of create-sf-campaign: ALSO side-effecting (its default run MUTATES SF
# via `sf data update record`). Its emit-mode builder (build_status_update_payload.py) is
# driven over a SCENARIO MATRIX so the GREEN run exercises every verdict branch, then the
# mutation cases prove a red diff — including the load-bearing IDEMPOTENCY regression (the
# would_noop verdict flipped to would_update), the OVERLAY-CLEAR regression (its symmetric
# twin), and BOTH precedence edges (dry_run>noop; campaign_not_found>dry_run). Same shape
# as the create-sf-campaign block above; reuses invoke/assert_*.
echo "── update-sf-campaign-status eval (BC-12942 — known-good → GREEN) ──"
USU="$tmproot/usu"; mkdir -p "$USU"
invoke "$RUN_EVAL" update-sf-campaign-status --sandbox "$USU"
assert_exit "update-sf-campaign-status eval GREEN — known-good matrix builds + passes" 0
assert_substr "update-sf-campaign-status eval prints PASS verdict" "PASS: update-sf-campaign-status eval"
if [ -f "$USU/status-update-emit.json" ]; then
  echo "  PASS  artifact produced: status-update-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: status-update-emit.json"; fail=$((fail + 1))
fi

echo "── update-sf-campaign-status self-test (mutated matrix → RED) ──"
mutate_usu() {  # label  expected_substr  python_mutation (M = artifact dir)
  local label="$1" rx="$2" code="$3"
  local M="$tmproot/usumut.$((mutid++))"; mkdir -p "$M"
  cp "$USU/status-update-emit.json" "$M/"
  if ! MUT_DIR="$M" python3 -c "
import json, os, pathlib
M = pathlib.Path(os.environ['MUT_DIR'])
$code
"; then
    echo "  FAIL  mutation setup failed: $label"; fail=$((fail + 1)); return
  fi
  invoke "$RUN_EVAL" update-sf-campaign-status --artifact-dir "$M"
  assert_exit "usu mutation '$label' → red (exit 1)" 1
  assert_substr "usu mutation '$label' → named diff" "$rx"
}

# THE idempotency regression: a would_noop flipped to would_update (the command stops
# short-circuiting an already-matching campaign) — the load-bearing behavior this eval
# exists to catch (ADR-028: "green tests on a command that never ran").
mutate_usu "idempotency regression (noop→update)" "golden 'would_noop', got 'would_update'" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="would_noop"][0]; s.update(verdict="would_update", payload={"Status":"Completed","Substatus__c":""}, output=None); json.dump(d,open(p,"w"))'
# overlay-clear regression: the (active,paused)→(active,null) transition wrongly treated
# as a noop (the overlay never clears) — the symmetric twin of the idempotency regression.
mutate_usu "overlay-clear regression (update→noop)" "scenarios[1].verdict: golden 'would_update'" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="would_update_clears_overlay"][0]; s.update(verdict="would_noop", payload=None, output={"noop":True}); json.dump(d,open(p,"w"))'
# precedence edge #1: dry_run>noop — a dry-run against a matching campaign wrongly noops.
mutate_usu "precedence regression (dry_run→noop)" "golden 'dry_run', got 'would_noop'" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="dry_run_wins_over_noop"][0]; s.update(verdict="would_noop", output={"noop":True}); json.dump(d,open(p,"w"))'
# precedence edge #2: campaign_not_found>dry_run — a dry-run against a missing campaign
# wrongly emits a (degenerate) preview instead of the not-found warning.
mutate_usu "precedence regression (not_found→dry_run)" "golden 'campaign_not_found', got 'dry_run'" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="dry_run_against_missing"][0]; s.update(verdict="dry_run", campaign_id="701ABCDEFGHIJKLMNO", output={"dry_run":True}); json.dump(d,open(p,"w"))'
# no-write invariant: would_noop's Phase-7 campaign_url un-nulled (the URL is out of the
# emit scope — a builder that filled it would be modeling the live read).
mutate_usu "un-null a noop campaign_url (out-of-scope invariant)" "output.campaign_url must be null" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="would_noop"][0]; s["output"]["campaign_url"]="https://x.lightning.force.com/..."; json.dump(d,open(p,"w"))'
# no-write invariant (symmetric twin): would_update's output un-nulled — the Phase-8
# success envelope is IO-assembled post-write, so the hermetic emit row must keep it null.
mutate_usu "un-null a would_update output (no-write invariant)" "would_update output must be null" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="would_update"][0]; s["output"]={"leaked":True}; json.dump(d,open(p,"w"))'
mutate_usu "drop the idempotency scenario" "expected scenario id 'would_noop' is absent" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); d["scenarios"]=[s for s in d["scenarios"] if s["id"]!="would_noop"]; json.dump(d,open(p,"w"))'
mutate_usu "leak an extra scenario key" "unexpected property" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'
mutate_usu "flip a verdict to an off-enum value" "is not one of enum" \
  'p=M/"status-update-emit.json"; d=json.load(open(p)); d["scenarios"][0]["verdict"]="ship_it"; json.dump(d,open(p,"w"))'

# ── 3c. new-offer eval (BC-12702 — the structure-first / LLM-judged representative) ─
# The THIRD registered command: it WRITES a GTM canonical where the operator/LLM chooses
# the content. Its emit builder (build_offer_emit.py) drives the SAME runtime entrypoint
# the command delegates to (canonicals_bootstrap.py `offer`) against a sandbox copy of a
# FROZEN seed, then runs lint_canonicals over the result. The GREEN run exercises a 7-row
# matrix (a clean write + a near-miss + every builder-owned guard); the mutation cases
# prove a red diff — including the load-bearing structure-first regression (a written
# canonical that no longer passes lint_canonicals) and a uniqueness regression
# (duplicate→write). Same shape as the blocks above; reuses invoke/assert_*.
echo "── new-offer eval (BC-12702 — known-good → GREEN) ──"
NO="$tmproot/no"; mkdir -p "$NO"
invoke "$RUN_EVAL" new-offer --sandbox "$NO"
assert_exit "new-offer eval GREEN — known-good matrix builds + passes" 0
assert_substr "new-offer eval prints PASS verdict" "PASS: new-offer eval"
if [ -f "$NO/offer-emit.json" ]; then
  echo "  PASS  artifact produced: offer-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: offer-emit.json"; fail=$((fail + 1))
fi

echo "── new-offer self-test (mutated matrix → RED) ──"
mutate_no() {  # label  expected_substr  python_mutation (M = artifact dir)
  local label="$1" rx="$2" code="$3"
  local M="$tmproot/nomut.$((mutid++))"; mkdir -p "$M"
  cp "$NO/offer-emit.json" "$M/"
  if ! MUT_DIR="$M" python3 -c "
import json, os, pathlib
M = pathlib.Path(os.environ['MUT_DIR'])
$code
"; then
    echo "  FAIL  mutation setup failed: $label"; fail=$((fail + 1)); return
  fi
  invoke "$RUN_EVAL" new-offer --artifact-dir "$M"
  assert_exit "no mutation '$label' → red (exit 1)" 1
  assert_substr "no mutation '$label' → named diff" "$rx"
}

# THE structure-first regression: a valid write whose canonical no longer passes the full
# lint_canonicals contract (exit 1) — the load-bearing proof for this representative.
mutate_no "valid write fails lint (exit 1)" "lint.exit_code 0" \
  'p=M/"offer-emit.json"; d=json.load(open(p)); d["scenarios"][0]["lint"]["exit_code"]=1; json.dump(d,open(p,"w"))'
# uniqueness regression: the duplicate slug is wrongly WRITTEN instead of rejected.
mutate_no "uniqueness regression (dup→write)" "scenarios[2].ok: golden False, got True" \
  'p=M/"offer-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="duplicate_slug"][0]; s.update(ok=True, action="created_offer", appended_offer={"slug":"existing-offer","display":"Dup","status":"draft","posture":"knowledge"}, error=None, lint={"exit_code":0}); json.dump(d,open(p,"w"))'
# passthrough regression: the appended entry's posture no longer matches the input.
mutate_no "corrupt the appended posture" "posture" \
  'p=M/"offer-emit.json"; d=json.load(open(p)); d["scenarios"][0]["appended_offer"]["posture"]="knowledge"; json.dump(d,open(p,"w"))'
mutate_no "drop the uniqueness scenario" "expected scenario id 'duplicate_slug' is absent" \
  'p=M/"offer-emit.json"; d=json.load(open(p)); d["scenarios"]=[s for s in d["scenarios"] if s["id"]!="duplicate_slug"]; json.dump(d,open(p,"w"))'
mutate_no "leak an extra scenario key" "unexpected property" \
  'p=M/"offer-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'
mutate_no "null out a rejection error" "non-empty builder error" \
  'p=M/"offer-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="invalid_slug"][0]; s["error"]=None; json.dump(d,open(p,"w"))'
# dedup-EXACTNESS regression: a different-slug near-miss wrongly classified as a duplicate.
mutate_no "near-miss wrongly deduped" "scenarios[1].ok: golden True, got False" \
  'p=M/"offer-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="near_miss_not_duplicate"][0]; s.update(ok=False, action=None, appended_offer=None, lint=None, error="wrongly deduped"); json.dump(d,open(p,"w"))'

# ── 3d/3e. new-persona + new-vertical evals (BC-12915 — the canonicals backfill batch) ─
# The sibling structure-first commands: same generic CanonicalEmitAdapter + the SAME
# build_canonical_emit.py builder + the SAME frozen seed, different subcommand. Each GREEN
# run exercises its 5-row matrix; the mutation cases prove a red diff — incl. the load-
# bearing structure-first regression (a written canonical that no longer passes
# lint_canonicals) and a uniqueness regression (duplicate→write). `mutate_canon` is the
# command/artifact-parameterized twin of `mutate_no`.
mutate_canon() {  # cmd  good_dir  artifact  label  expected_substr  python_mutation (M)
  local cmd="$1" good="$2" art="$3" label="$4" rx="$5" code="$6"
  local M="$tmproot/cmut.$((mutid++))"; mkdir -p "$M"
  cp "$good/$art" "$M/"
  if ! MUT_DIR="$M" python3 -c "
import json, os, pathlib
M = pathlib.Path(os.environ['MUT_DIR'])
$code
"; then
    echo "  FAIL  mutation setup failed: $label"; fail=$((fail + 1)); return
  fi
  invoke "$RUN_EVAL" "$cmd" --artifact-dir "$M"
  assert_exit "$cmd mutation '$label' → red (exit 1)" 1
  assert_substr "$cmd mutation '$label' → named diff" "$rx"
}

echo "── new-persona eval (BC-12915 — known-good → GREEN) ──"
NP="$tmproot/np"; mkdir -p "$NP"
invoke "$RUN_EVAL" new-persona --sandbox "$NP"
assert_exit "new-persona eval GREEN — known-good matrix builds + passes" 0
assert_substr "new-persona eval prints PASS verdict" "PASS: new-persona eval"
if [ -f "$NP/persona-emit.json" ]; then
  echo "  PASS  artifact produced: persona-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: persona-emit.json"; fail=$((fail + 1))
fi
echo "── new-persona self-test (mutated matrix → RED) ──"
mutate_canon new-persona "$NP" persona-emit.json "valid write fails lint (exit 1)" "lint.exit_code 0" \
  'p=M/"persona-emit.json"; d=json.load(open(p)); d["scenarios"][0]["lint"]["exit_code"]=1; json.dump(d,open(p,"w"))'
mutate_canon new-persona "$NP" persona-emit.json "uniqueness regression (dup→write)" "scenarios[2].ok: golden False, got True" \
  'p=M/"persona-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="duplicate_slug"][0]; s.update(ok=True, action="created_persona", appended_persona={"slug":"ops-director","display":"Dup","titles":["t"]}, error=None, lint={"exit_code":0}); json.dump(d,open(p,"w"))'
mutate_canon new-persona "$NP" persona-emit.json "drop the uniqueness scenario" "expected scenario id 'duplicate_slug' is absent" \
  'p=M/"persona-emit.json"; d=json.load(open(p)); d["scenarios"]=[s for s in d["scenarios"] if s["id"]!="duplicate_slug"]; json.dump(d,open(p,"w"))'
mutate_canon new-persona "$NP" persona-emit.json "leak an extra scenario key" "unexpected property" \
  'p=M/"persona-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'

echo "── new-vertical eval (BC-12915 — known-good → GREEN) ──"
NV="$tmproot/nv"; mkdir -p "$NV"
invoke "$RUN_EVAL" new-vertical --sandbox "$NV"
assert_exit "new-vertical eval GREEN — known-good matrix builds + passes" 0
assert_substr "new-vertical eval prints PASS verdict" "PASS: new-vertical eval"
if [ -f "$NV/vertical-emit.json" ]; then
  echo "  PASS  artifact produced: vertical-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: vertical-emit.json"; fail=$((fail + 1))
fi
echo "── new-vertical self-test (mutated matrix → RED) ──"
mutate_canon new-vertical "$NV" vertical-emit.json "valid write fails lint (exit 1)" "lint.exit_code 0" \
  'p=M/"vertical-emit.json"; d=json.load(open(p)); d["scenarios"][0]["lint"]["exit_code"]=1; json.dump(d,open(p,"w"))'
mutate_canon new-vertical "$NV" vertical-emit.json "uniqueness regression (dup→write)" "scenarios[2].ok: golden False, got True" \
  'p=M/"vertical-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="duplicate_slug"][0]; s.update(ok=True, action="created_vertical", appended_vertical={"slug":"sample-vertical","display":"Dup"}, error=None, lint={"exit_code":0}); json.dump(d,open(p,"w"))'
mutate_canon new-vertical "$NV" vertical-emit.json "alias rejection error nulled" "non-empty builder error" \
  'p=M/"vertical-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="invalid_alias"][0]; s["error"]=None; json.dump(d,open(p,"w"))'
mutate_canon new-vertical "$NV" vertical-emit.json "leak an extra scenario key" "unexpected property" \
  'p=M/"vertical-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'

# ── 3f. offer-performance eval (BC-12943 — structure-first report-builder, Batch B) ─
# The FIRST marketing report-builder wrap: build_offer_perf_emit.py drives the REAL
# offer_performance.py over a sandbox copy of a frozen campaigns+canonicals seed with
# EB/SF stats INJECTED per scenario and --generated-at pinned, then projects the WRITTEN
# performance.md (frontmatter + section headers + degraded banners + retirement signal +
# the parsed per-version metrics table). The GREEN run exercises a 6-row matrix; the
# mutation cases prove a red diff — incl. the retirement decision, the single-vs-multi
# Cross-version branch, an injected-stat table cell, a degraded banner, and the
# --generated-at determinism lock. Reuses the generic mutate_canon helper.
echo "── offer-performance eval (BC-12943 — known-good → GREEN) ──"
OP="$tmproot/op"; mkdir -p "$OP"
invoke "$RUN_EVAL" offer-performance --sandbox "$OP"
assert_exit "offer-performance eval GREEN — known-good matrix builds + passes" 0
assert_substr "offer-performance eval prints PASS verdict" "PASS: offer-performance eval"
if [ -f "$OP/offer-perf-emit.json" ]; then
  echo "  PASS  artifact produced: offer-perf-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: offer-perf-emit.json"; fail=$((fail + 1))
fi
echo "── offer-performance self-test (mutated matrix → RED) ──"
# THE retirement decision: a degrading-versions report that no longer flags the candidate.
mutate_canon offer-performance "$OP" offer-perf-emit.json "retirement flipped off" "retirement_signal" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); [s.update(retirement_signal=False) for s in d["scenarios"] if s["id"]=="retirement_candidate"]; json.dump(d,open(p,"w"))'
# single-vs-multi branch: the multi-version rollup loses its Cross-version comparison.
mutate_canon offer-performance "$OP" offer-perf-emit.json "cross-version section dropped" "Cross-version comparison section is absent" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="multi_version_ok"][0]; s["sections"]=[x for x in s["sections"] if x!="2. Cross-version comparison"]; json.dump(d,open(p,"w"))'
# injected-stat flow: a rendered metrics-table cell no longer matches the injected EB stat.
mutate_canon offer-performance "$OP" offer-perf-emit.json "corrupt a metrics-table cell" "reply_rate" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="multi_version_ok"][0]; s["versions"][0]["reply_rate"]="99.9%"; json.dump(d,open(p,"w"))'
# degraded soft-fail: the EB-degraded banner stops rendering.
mutate_canon offer-performance "$OP" offer-perf-emit.json "eb_degraded banner flipped off" "banners.eb_degraded" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="eb_degraded"][0]; s["banners"]["eb_degraded"]=False; json.dump(d,open(p,"w"))'
# determinism: the pinned --generated-at is ignored (a now()-leak regression).
mutate_canon offer-performance "$OP" offer-perf-emit.json "generated_at drift" "generated_at must be the pinned" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="multi_version_ok"][0]; s["frontmatter"]["generated_at"]="2099-01-01T00:00:00Z"; json.dump(d,open(p,"w"))'
# rejection invariant: an invalid-slug row wrongly carries a report instead of null + error.
mutate_canon offer-performance "$OP" offer-perf-emit.json "un-null a rejection report" "rejection row must have null frontmatter" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="invalid_slug"][0]; s["frontmatter"]={"x":1}; json.dump(d,open(p,"w"))'
mutate_canon offer-performance "$OP" offer-perf-emit.json "drop a load-bearing scenario" "expected scenario id 'retirement_candidate' is absent" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); d["scenarios"]=[x for x in d["scenarios"] if x["id"]!="retirement_candidate"]; json.dump(d,open(p,"w"))'
mutate_canon offer-performance "$OP" offer-perf-emit.json "leak an extra scenario key" "unexpected property" \
  'p=M/"offer-perf-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'

# ── 3g. portfolio-snapshot eval (BC-12943 — structure-first report-builder, Batch B) ─
# The σ-adjacent report wrap: build_portfolio_emit.py drives the REAL portfolio_snapshot.py
# over a sandbox copy of a frozen campaigns+canonicals seed with --generated-at pinned,
# then projects the WRITTEN packet (frontmatter window+sources + window label + ordered
# section headers + degraded banners + verdict distribution + in-window campaign count).
# The GREEN run exercises a 6-row matrix; the mutation cases prove a red diff — incl. the
# monthly-vs-quarterly section branch (both directions), a degraded banner, the
# window-filter campaign count, the anti-creep guard rejection, and the --generated-at
# determinism lock. Reuses the generic mutate_canon helper.
echo "── portfolio-snapshot eval (BC-12943 — known-good → GREEN) ──"
PF="$tmproot/pf"; mkdir -p "$PF"
invoke "$RUN_EVAL" portfolio-snapshot --sandbox "$PF"
assert_exit "portfolio-snapshot eval GREEN — known-good matrix builds + passes" 0
assert_substr "portfolio-snapshot eval prints PASS verdict" "PASS: portfolio-snapshot eval"
if [ -f "$PF/portfolio-emit.json" ]; then
  echo "  PASS  artifact produced: portfolio-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: portfolio-emit.json"; fail=$((fail + 1))
fi
echo "── portfolio-snapshot self-test (mutated matrix → RED) ──"
# monthly-vs-quarterly branch (both directions): the section set must match the span.
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "quarterly loses sections 6-9" "quarterly span must render 9 sections" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="quarterly_ok"][0]; s["sections"]=s["sections"][:5]; json.dump(d,open(p,"w"))'
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "monthly gains a quarterly section" "monthly span must render 5 sections" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="monthly_ok"][0]; s["sections"].append("6. Cross-quarter MSPA transitions"); json.dump(d,open(p,"w"))'
# degraded soft-fail: the SF-rollup-degraded banner stops rendering.
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "sf_degraded banner flipped off" "banners.sf" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="sf_degraded_auth"][0]; s["banners"]["sf"]=False; json.dump(d,open(p,"w"))'
# window filter: the out-of-window row wrongly counts campaigns (a no-op filter).
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "window-filter no-op regression" "campaigns_in_window" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="out_of_window_excluded"][0]; s["campaigns_in_window"]=2; json.dump(d,open(p,"w"))'
# anti-creep guard: the rejection row goes silent (no error string).
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "anti-creep rejection goes silent" "rejection row must carry a non-empty builder error" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="out_anticreep_rejected"][0]; s["error"]=None; json.dump(d,open(p,"w"))'
# determinism: the pinned --generated-at is ignored.
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "generated_at drift" "generated_at must be the pinned" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="monthly_ok"][0]; s["frontmatter"]["generated_at"]="2099-01-01T00:00:00Z"; json.dump(d,open(p,"w"))'
# passthrough: the frontmatter sources echo no longer matches the upstream status.
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "sources.sf passthrough drift" "sources.sf" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="sf_degraded_auth"][0]; s["frontmatter"]["sources"]["sf"]="ok"; json.dump(d,open(p,"w"))'
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "drop a load-bearing scenario" "expected scenario id 'quarterly_ok' is absent" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); d["scenarios"]=[x for x in d["scenarios"] if x["id"]!="quarterly_ok"]; json.dump(d,open(p,"w"))'
mutate_canon portfolio-snapshot "$PF" portfolio-emit.json "leak an extra scenario key" "unexpected property" \
  'p=M/"portfolio-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'

# ── 3h. import-campaign eval (BC-12943 — structure-first manifest composer, Batch B) ─
# The pure-composer wrap: build_import_emit.py pipes each scenario payload to the REAL
# `import_campaign.py compose` (stdin→stdout, no clock) against a frozen audience-tier
# taxonomy, then projects the COMPOSED v2 manifest. The GREEN run exercises an 8-row
# matrix (5 compose + 3 rejection); the mutation cases prove a red diff — incl. the
# v1-singular-campaign_id anti-regression, the schema_version-2 contract, the auto-
# classification (audience_tier), the pending_classification derived flag, the 13-key
# top-level contract, an input passthrough, and a silent rejection. Reuses mutate_canon.
echo "── import-campaign eval (BC-12943 — known-good → GREEN) ──"
IC="$tmproot/ic"; mkdir -p "$IC"
invoke "$RUN_EVAL" import-campaign --sandbox "$IC"
assert_exit "import-campaign eval GREEN — known-good matrix builds + passes" 0
assert_substr "import-campaign eval prints PASS verdict" "PASS: import-campaign eval"
if [ -f "$IC/import-campaign-emit.json" ]; then
  echo "  PASS  artifact produced: import-campaign-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: import-campaign-emit.json"; fail=$((fail + 1))
fi
echo "── import-campaign self-test (mutated matrix → RED) ──"
# v1 anti-regression: the deleted singular email_bison.campaign_id wrongly returns.
mutate_canon import-campaign "$IC" import-campaign-emit.json "v1 singular campaign_id leak" "v1 singular 'campaign_id'" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="single_launched_auto_classified"][0]; s["manifest"]["email_bison"]["campaign_id"]=10; json.dump(d,open(p,"w"))'
# v2 contract: schema_version drifts off 2.
mutate_canon import-campaign "$IC" import-campaign-emit.json "schema_version downgrade" "schema_version must be 2" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="happy_empty_records"][0]; s["manifest"]["schema_version"]=1; json.dump(d,open(p,"w"))'
# auto-classification: a record's classified seniority no longer matches the taxonomy.
mutate_canon import-campaign "$IC" import-campaign-emit.json "audience_tier classification regression" "seniority" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="single_launched_auto_classified"][0]; s["manifest"]["email_bison"]["campaigns"][0]["audience_tier"]["seniority"]="employees"; json.dump(d,open(p,"w"))'
# derived flag: the pending_classification:true on a blank-name record disappears.
mutate_canon import-campaign "$IC" import-campaign-emit.json "pending_classification dropped" "pending_classification" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="pending_classification_set"][0]; s["manifest"]["email_bison"]["campaigns"][0].pop("pending_classification"); json.dump(d,open(p,"w"))'
# 13-key contract: a leaked top-level key.
mutate_canon import-campaign "$IC" import-campaign-emit.json "manifest top-level key leak" "top-level keys != the v2 contract" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="happy_empty_records"][0]; s["manifest"]["backdoor"]="x"; json.dump(d,open(p,"w"))'
# passthrough: a deterministic input field no longer copied verbatim.
mutate_canon import-campaign "$IC" import-campaign-emit.json "input passthrough drift" "slug" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="happy_empty_records"][0]; s["manifest"]["slug"]="wrong-slug-fy26-m02"; json.dump(d,open(p,"w"))'
# rejection invariant: a rejected payload goes silent (no error string).
mutate_canon import-campaign "$IC" import-campaign-emit.json "rejection goes silent" "rejection row must carry a non-empty builder error" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="reject_bad_slug"][0]; s["error"]=None; json.dump(d,open(p,"w"))'
mutate_canon import-campaign "$IC" import-campaign-emit.json "drop a load-bearing scenario" "expected scenario id 'pending_classification_set' is absent" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); d["scenarios"]=[x for x in d["scenarios"] if x["id"]!="pending_classification_set"]; json.dump(d,open(p,"w"))'
mutate_canon import-campaign "$IC" import-campaign-emit.json "leak an extra scenario key" "unexpected property" \
  'p=M/"import-campaign-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'

# ── 3i. icp-refinement-review eval (BC-12943 — structure-first review loop, Batch B) ─
# The pure-disk review-loop wrap: build_icp_review_emit.py drives the REAL scan → apply →
# emit-handbook over a sandbox copy of a frozen discoveries-tree seed, then runs the REAL
# lint_discoveries over the MUTATED tree. The GREEN run exercises a 6-row matrix; the
# mutation cases prove a red diff — incl. the STRUCTURE-FIRST anchor (the mutated file no
# longer lints), the one-way skip-terminal invariant, the defer-noop invariant, the emit
# exclude-rejected behavior, the scan filter count, and both rejection codes. Reuses
# mutate_canon.
echo "── icp-refinement-review eval (BC-12943 — known-good → GREEN) ──"
ICP="$tmproot/icp"; mkdir -p "$ICP"
invoke "$RUN_EVAL" icp-refinement-review --sandbox "$ICP"
assert_exit "icp-refinement-review eval GREEN — known-good matrix builds + passes" 0
assert_substr "icp-refinement-review eval prints PASS verdict" "PASS: icp-refinement-review eval"
if [ -f "$ICP/icp-review-emit.json" ]; then
  echo "  PASS  artifact produced: icp-review-emit.json"; pass=$((pass + 1))
else
  echo "  FAIL  artifact missing: icp-review-emit.json"; fail=$((fail + 1))
fi
echo "── icp-refinement-review self-test (mutated matrix → RED) ──"
# THE structure-first anchor: a mutated discoveries.json that no longer passes lint.
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "mutated file fails lint" "must still pass lint_discoveries" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="apply_promote"][0]; s["lint_exit_code"]=1; json.dump(d,open(p,"w"))'
# one-way invariant: an already-promoted (terminal) signal wrongly OVERWRITTEN with the
# decided value. The scenario decides 'rejected' on a 'promoted' terminal signal, so the
# readback diverges under a regression — mutated_statuses is the non-vacuous guard here
# (deciding the same value would make this field undetectable). golden_compare catches it.
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "one-way invariant broken (terminal overwritten)" "golden 'promoted'" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="apply_skip_terminal"][0]; s["mutated_statuses"]["labs/hotels-resorts-holiday-anchor-fy26-m02/discoveries.json::1"]="rejected"; json.dump(d,open(p,"w"))'
# defer-noop invariant: a deferred signal wrongly written to a terminal status.
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "defer wrote a status" "golden 'pending'" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="apply_defer_noop"][0]; s["mutated_statuses"]["labs/hotels-resorts-holiday-anchor-fy26-m02/discoveries.json::0"]="promoted"; json.dump(d,open(p,"w"))'
# emit exclude-rejected: a rejected signal's vertical wrongly surfaces in the handbook.
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "emit includes rejected vertical" "emit_verticals" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="apply_mixed"][0]; s["emit_verticals"]=["hotels-resorts","installers"]; s["emit_blob_count"]=2; json.dump(d,open(p,"w"))'
# scan filter: the category+pending filter count drifts.
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "scan filter regression" "scan_total_pending must be 2" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); d["scenarios"][0]["scan_total_pending"]=3; json.dump(d,open(p,"w"))'
# rejection invariants: a silent rejection, and a rejection that wrongly carries apply output.
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "rejection goes silent" "rejection row must carry a non-empty builder error" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="reject_bad_decision"][0]; s["error"]=None; json.dump(d,open(p,"w"))'
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "rejection un-nulls counts" "rejection row must have null counts" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); s=[x for x in d["scenarios"] if x["id"]=="reject_out_of_range"][0]; s["counts"]={"promoted":0,"rejected":0,"deferred":0,"skipped":0}; json.dump(d,open(p,"w"))'
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "drop a load-bearing scenario" "expected scenario id 'apply_skip_terminal' is absent" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); d["scenarios"]=[x for x in d["scenarios"] if x["id"]!="apply_skip_terminal"]; json.dump(d,open(p,"w"))'
mutate_canon icp-refinement-review "$ICP" icp-review-emit.json "leak an extra scenario key" "unexpected property" \
  'p=M/"icp-review-emit.json"; d=json.load(open(p)); d["scenarios"][0]["backdoor"]="x"; json.dump(d,open(p,"w"))'

# ── 4. hermeticity guard ─────────────────────────────────────────────────────

echo "── hermeticity ──"
# (a) no network-capable module is imported anywhere in the eval source — incl. the
#     create-sf-campaign builder AND the canonicals-family builder the adapters shell out to.
CSF_BUILDER="$REPO_ROOT/plugins/revops/scripts/build_campaign_payload.py"
USU_BUILDER="$REPO_ROOT/plugins/revops/scripts/build_status_update_payload.py"
NO_BUILDER="$REPO_ROOT/plugins/marketing/scripts/build_canonical_emit.py"
OP_BUILDER="$REPO_ROOT/plugins/marketing/scripts/build_offer_perf_emit.py"
PF_BUILDER="$REPO_ROOT/plugins/marketing/scripts/build_portfolio_emit.py"
IC_BUILDER="$REPO_ROOT/plugins/marketing/scripts/build_import_emit.py"
ICP_BUILDER="$REPO_ROOT/plugins/marketing/scripts/build_icp_review_emit.py"
if grep -nE '^[[:space:]]*(import|from)[[:space:]]+(requests|urllib|http|socket|ftplib|smtplib|telnetlib)([.[:space:]]|$)' \
     "$RUN_EVAL" "$ASSERT_LIB" "$CASES" "$CSF_BUILDER" "$USU_BUILDER" "$NO_BUILDER" \
     "$OP_BUILDER" "$PF_BUILDER" "$IC_BUILDER" "$ICP_BUILDER" >/dev/null 2>&1; then
  echo "  FAIL  hermeticity: a network module is imported in the eval source"; fail=$((fail + 1))
else
  echo "  PASS  hermeticity: no network module imported"; pass=$((pass + 1))
fi
# (b) the eval runs to GREEN with the API keys unset, from an empty cwd, writing
#     nothing into that cwd (build_manifest purity idiom; DP2-4 no-API-key path).
HCWD="$tmproot/hermetic-cwd"; mkdir -p "$HCWD"
before="$(cd "$HCWD" && find . | sort)"
herm_out="$(cd "$HCWD" && env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY python3 "$RUN_EVAL" plan-campaign 2>&1)"
herm_rc=$?
after="$(cd "$HCWD" && find . | sort)"
if [ "$herm_rc" -eq 0 ]; then
  echo "  PASS  hermeticity: eval GREEN with API keys unset, empty cwd"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: eval failed without API keys (rc=$herm_rc)"
  printf '    output: %s\n' "$herm_out"; fail=$((fail + 1))
fi
if [ "$before" = "$after" ]; then
  echo "  PASS  hermeticity: eval wrote nothing into the working dir"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: eval left stray files in the working dir"; fail=$((fail + 1))
fi
# (c) the create-sf-campaign eval (BC-12701) is hermetic too — GREEN with API keys
#     unset from an empty cwd, no stray files (the builder makes NO SF write/SOQL;
#     this is the load-bearing proof for the side-effecting representative).
HCWD2="$tmproot/hermetic-cwd-csf"; mkdir -p "$HCWD2"
before2="$(cd "$HCWD2" && find . | sort)"
herm2_out="$(cd "$HCWD2" && env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY python3 "$RUN_EVAL" create-sf-campaign 2>&1)"
herm2_rc=$?
after2="$(cd "$HCWD2" && find . | sort)"
if [ "$herm2_rc" -eq 0 ]; then
  echo "  PASS  hermeticity: create-sf-campaign eval GREEN with API keys unset, empty cwd"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: create-sf-campaign eval failed without API keys (rc=$herm2_rc)"
  printf '    output: %s\n' "$herm2_out"; fail=$((fail + 1))
fi
if [ "$before2" = "$after2" ]; then
  echo "  PASS  hermeticity: create-sf-campaign eval wrote nothing into the working dir"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: create-sf-campaign eval left stray files in the working dir"; fail=$((fail + 1))
fi
# (c2) the update-sf-campaign-status eval (BC-12942) is hermetic too — GREEN with API keys
#      unset from an empty cwd, no stray files (the builder makes NO SF write/SOQL; the
#      load-bearing proof for the σ3 side-effecting sibling).
HCWD_USU="$tmproot/hermetic-cwd-usu"; mkdir -p "$HCWD_USU"
before_usu="$(cd "$HCWD_USU" && find . | sort)"
herm_usu_out="$(cd "$HCWD_USU" && env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY python3 "$RUN_EVAL" update-sf-campaign-status 2>&1)"
herm_usu_rc=$?
after_usu="$(cd "$HCWD_USU" && find . | sort)"
if [ "$herm_usu_rc" -eq 0 ]; then
  echo "  PASS  hermeticity: update-sf-campaign-status eval GREEN with API keys unset, empty cwd"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: update-sf-campaign-status eval failed without API keys (rc=$herm_usu_rc)"
  printf '    output: %s\n' "$herm_usu_out"; fail=$((fail + 1))
fi
if [ "$before_usu" = "$after_usu" ]; then
  echo "  PASS  hermeticity: update-sf-campaign-status eval wrote nothing into the working dir"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: update-sf-campaign-status eval left stray files in the working dir"; fail=$((fail + 1))
fi
# (d) the new-offer eval (BC-12702) is hermetic too — GREEN with API keys unset from an
#     empty cwd, no stray files. Its builder copies a frozen seed into a sandbox and shells
#     canonicals_bootstrap + lint_canonicals (both stdlib, no network/MCP/real-file write);
#     this is the load-bearing proof for the structure-first representative.
HCWD3="$tmproot/hermetic-cwd-no"; mkdir -p "$HCWD3"
before3="$(cd "$HCWD3" && find . | sort)"
herm3_out="$(cd "$HCWD3" && env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY python3 "$RUN_EVAL" new-offer 2>&1)"
herm3_rc=$?
after3="$(cd "$HCWD3" && find . | sort)"
if [ "$herm3_rc" -eq 0 ]; then
  echo "  PASS  hermeticity: new-offer eval GREEN with API keys unset, empty cwd"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: new-offer eval failed without API keys (rc=$herm3_rc)"
  printf '    output: %s\n' "$herm3_out"; fail=$((fail + 1))
fi
if [ "$before3" = "$after3" ]; then
  echo "  PASS  hermeticity: new-offer eval wrote nothing into the working dir"; pass=$((pass + 1))
else
  echo "  FAIL  hermeticity: new-offer eval left stray files in the working dir"; fail=$((fail + 1))
fi
# (e/f) the new-persona + new-vertical evals (BC-12915) are hermetic too — same builder,
#       same frozen seed, different subcommand. Loop to avoid two near-identical blocks.
for hc in new-persona new-vertical offer-performance portfolio-snapshot import-campaign icp-refinement-review; do
  HCWD="$tmproot/hermetic-cwd-$hc"; mkdir -p "$HCWD"
  hb="$(cd "$HCWD" && find . | sort)"
  ho="$(cd "$HCWD" && env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY python3 "$RUN_EVAL" "$hc" 2>&1)"; hrc=$?
  ha="$(cd "$HCWD" && find . | sort)"
  if [ "$hrc" -eq 0 ]; then
    echo "  PASS  hermeticity: $hc eval GREEN with API keys unset, empty cwd"; pass=$((pass + 1))
  else
    echo "  FAIL  hermeticity: $hc eval failed without API keys (rc=$hrc)"
    printf '    output: %s\n' "$ho"; fail=$((fail + 1))
  fi
  if [ "$hb" = "$ha" ]; then
    echo "  PASS  hermeticity: $hc eval wrote nothing into the working dir"; pass=$((pass + 1))
  else
    echo "  FAIL  hermeticity: $hc eval left stray files in the working dir"; fail=$((fail + 1))
  fi
done

echo ""
# Count floor — a vanished test block (broken --list, swallowed import, emptied
# CASES, or a whole command's eval block disappearing) would otherwise drop the count
# yet still exit 0. Below the floor is a silent-skip and must fail the build loudly
# (the eval's whole reason to exist). Bumped 45→80 (BC-12701 create-sf-campaign block),
# 80→100 (BC-12702 new-offer block, +19), then 100→125 when the BC-12915 canonicals batch
# landed (new-persona + new-vertical: +26, total 131), then 125→146 with the BC-12942
# update-sf-campaign-status block (+23 = 3 GREEN + 9×2 mutations + 2 hermeticity, total
# 154), then 146→231 with the BC-12943 Batch-B marketing-builder blocks (offer-performance
# + portfolio-snapshot + import-campaign + icp-refinement-review: +90 = 4 × ~(3 GREEN +
# 8-9×2 mutations + 2 hermeticity), live total 244) — so losing any one command's eval
# block trips the floor rather than passing. Held at ~95% of the live count to tolerate a
# single intentional assertion edit.
FLOOR=231
if [ "$pass" -lt "$FLOOR" ]; then
  echo "FATAL: only $pass assertions ran (floor=$FLOOR) — a test block was silently skipped" >&2
  exit 2
fi

echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
