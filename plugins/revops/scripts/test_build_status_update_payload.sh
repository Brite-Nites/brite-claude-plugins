#!/usr/bin/env bash
# Unit / contract suite for plugins/revops/scripts/build_status_update_payload.py
# (BC-12942, ADR-028 Phase-2 Batch A — the side-effecting σ3 sibling of
# create-sf-campaign / BC-12701).
#
# build_status_update_payload.py is the PURE deterministic decision core
# /revops:update-sf-campaign-status delegates to in BOTH its normal and emit runs
# (the single shared entrypoint — so the behavioral eval can't certify a parallel
# path). Given (inputs, injected sf_state) it computes the would_update /
# would_noop / dry_run / campaign_not_found / error VERDICT + the SF Campaign
# UPDATE payload, with NO SOQL, NO SF write, NO shell-out. This suite drives the
# builder directly across every verdict branch AND proves the security property the
# command's --target-org guard rests on: a `$(touch pwned)` value is REJECTED with
# no side effect (the builder only ever regex-matches it — it never reaches a
# shell). The behavioral eval (scripts/eval/test_eval_harness.sh) asserts the
# emit-artifact STRUCTURE; this asserts the builder's per-branch DECISIONS +
# injection-safety + determinism.
#
# Usage:
#   bash plugins/revops/scripts/test_build_status_update_payload.sh
#   bash plugins/revops/scripts/test_build_status_update_payload.sh /path/to/build_status_update_payload.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.

# Defuse caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md; matches
# test_build_campaign_payload.sh / test_validate_target_org.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_status_update_payload.py}"
FIXTURE="$HERE/../tests/eval/update-sf-campaign-status.fixture.json"

if [ ! -f "$BUILDER" ]; then
  echo "FATAL: builder not found: $BUILDER" >&2
  exit 2
fi

pass=0
fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

# decide "<label>" "<scenario-json>"  → runs --decide in an isolated sandbox cwd,
# asserts exit 0 (a decision is always a successful run) AND that no `pwned`
# side-effect sentinel was created. Echoes the single-line decision JSON so the
# caller can assert substrings. A reject scenario (invalid_*) is STILL exit 0 here
# — the builder returns an `error` verdict, it does not fail.
DECIDE_OUT=""
decide() {
  local label="$1" scenario="$2" box rc sidefx=0
  box="$(mktemp -d)"
  DECIDE_OUT="$(cd "$box" && printf '%s' "$scenario" | python3 "$BUILDER" --decide - 2>&1)"
  rc=$?
  [ -e "$box/pwned" ] && sidefx=1
  rm -rf "$box"
  if [ "$rc" -eq 0 ]; then ok; else bad "$label: --decide exited $rc (expected 0): $DECIDE_OUT"; fi
  if [ "$sidefx" -eq 0 ]; then ok; else bad "$label: created the pwned sentinel — builder shelled the value!"; fi
}

want() {  # want "<label>" "<substring>"  — assert DECIDE_OUT contains substring
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then ok; else
    bad "$label: missing [$sub] in: $DECIDE_OUT"
  fi
}
nowant() {  # nowant "<label>" "<substring>"  — assert DECIDE_OUT does NOT contain substring
  local label="$1" sub="$2"
  if printf '%s' "$DECIDE_OUT" | grep -qF -- "$sub"; then
    bad "$label: unexpected [$sub] in: $DECIDE_OUT"
  else ok; fi
}

# Injected Phase-2 SOQL rows (the campaign's current state). 18-char synthetic Id.
CAMP_ACTIVE='"sf_state":{"campaign":{"Id":"701ABCDEFGHIJKLMNO","Status":"In Progress","Substatus__c":null,"LastModifiedDate":"2026-05-01T12:00:00.000+0000"}}'
CAMP_PAUSED='"sf_state":{"campaign":{"Id":"701ABCDEFGHIJKLMNO","Status":"In Progress","Substatus__c":"Paused","LastModifiedDate":"2026-05-01T12:00:00.000+0000"}}'
CAMP_DONE='"sf_state":{"campaign":{"Id":"701ABCDEFGHIJKLMNO","Status":"Completed","Substatus__c":null,"LastModifiedDate":"2026-05-01T12:00:00.000+0000"}}'
CAMP_NULL='"sf_state":{"campaign":null}'

# ── would_update (state differs → emit the UPDATE payload, output null) ────────
decide 'would_update planning' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"planning\",${CAMP_ACTIVE}}"
want   'would_update planning' '"verdict": "would_update"'
want   'would_update planning' '"Status": "Planned"'
want   'would_update planning' '"Substatus__c": ""'
want   'would_update planning' '"campaign_id": "701ABCDEFGHIJKLMNO"'
want   'would_update planning' '"output": null'

# killed → Aborted (mapping coverage).
decide 'would_update killed' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"killed\",${CAMP_ACTIVE}}"
want   'would_update killed' '"verdict": "would_update"'
want   'would_update killed' '"Status": "Aborted"'

# active + paused → set the overlay (current null substatus differs).
decide 'would_update sets paused' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"active\",\"linear_substatus\":\"paused\",${CAMP_ACTIVE}}"
want   'would_update sets paused' '"verdict": "would_update"'
want   'would_update sets paused' '"Substatus__c": "Paused"'

# THE load-bearing overlay-clear: (active,paused) → (active,null). Status already
# matches BUT substatus differs (Paused≠null) → would_update that clears the overlay
# (Substatus__c=''), NOT a noop. The symmetric twin of the noop-equivalence below.
decide 'would_update clears overlay' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"active\",${CAMP_PAUSED}}"
want   'would_update clears overlay' '"verdict": "would_update"'
want   'would_update clears overlay' '"Substatus__c": ""'

# ── would_noop (current == mapped, null≡empty Substatus__c) ───────────────────
decide 'would_noop completed' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"completed\",${CAMP_DONE}}"
want   'would_noop completed' '"verdict": "would_noop"'
want   'would_noop completed' '"noop": true'
want   'would_noop completed' '"updated_at": "2026-05-01T12:00:00.000+0000"'
want   'would_noop completed' '"campaign_url": null'
want   'would_noop completed' '"status": "Completed"'
want   'would_noop completed' '"payload": null'

# null≡empty equivalence, INPUT side: an EMPTY --linear-substatus against a null-overlay
# active campaign → mapped (In Progress, null) == current (In Progress, null) → noop.
# Proves flag-empty maps to null AND compares equal to SOQL-null.
decide 'would_noop null≡empty (input "")' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"active\",\"linear_substatus\":\"\",${CAMP_ACTIVE}}"
want   'would_noop null≡empty (input "")' '"verdict": "would_noop"'

# null≡empty equivalence, SOQL side (the load-bearing twin — closes the _norm_sub gap):
# a campaign whose CURRENT Substatus__c is the empty string "" (NOT null) against an
# active/no-substatus transition (mapped null) → would_noop. SF can return "" for a
# cleared overlay; _norm_sub must reconcile SOQL-"" with mapped-null. A `return value`
# regression in _norm_sub (dropping the `or ""`) flips THIS row to would_update — the
# CAMP_ACTIVE rows above can't catch it (None==None passes raw ==), so this row is the
# one that binds _norm_sub's empty-string normalization to behavior.
CAMP_EMPTY_SUB='"sf_state":{"campaign":{"Id":"701ABCDEFGHIJKLMNO","Status":"In Progress","Substatus__c":"","LastModifiedDate":"2026-05-01T12:00:00.000+0000"}}'
decide 'would_noop SOQL ""≡null' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"active\",${CAMP_EMPTY_SUB}}"
want   'would_noop SOQL ""≡null' '"verdict": "would_noop"'

# ── dry_run (Phase 4 — WINS over noop, but downstream of campaign_not_found) ───
# dry_run against an ALREADY-MATCHING campaign → dry_run, NOT would_noop (locks the
# dry_run>noop precedence edge). The preview embeds the record-id + the command str.
decide 'dry_run wins over noop' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"completed\",\"dry_run\":true,${CAMP_DONE}}"
want   'dry_run wins over noop' '"verdict": "dry_run"'
want   'dry_run wins over noop' '"dry_run": true'
want   'dry_run wins over noop' '--record-id 701ABCDEFGHIJKLMNO'
nowant 'dry_run wins over noop' '"noop": true'

# dry_run against a MISSING campaign → campaign_not_found, NOT a degenerate preview
# (locks the campaign_not_found>dry_run edge — the preview needs the Phase-2 id).
decide 'dry_run against missing' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"active\",\"dry_run\":true,${CAMP_NULL}}"
want   'dry_run against missing' '"verdict": "campaign_not_found"'
want   'dry_run against missing' '"warning": "campaign_not_found"'
nowant 'dry_run against missing' '"dry_run": true'

# ── campaign_not_found (Phase 2 — 0 rows; a WARNING, not error) ───────────────
decide 'campaign_not_found' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"killed\",${CAMP_NULL}}"
want   'campaign_not_found' '"verdict": "campaign_not_found"'
want   'campaign_not_found' '"warning": "campaign_not_found"'
want   'campaign_not_found' '"campaign_id": null'

# ── input-shape guards ─────────────────────────────────────────────────────────
# invalid_slug (one-fault-per-row: target-org valid/absent so Phase 0 passes first).
decide 'invalid_slug' "{\"slug\":\"Not A Slug\",\"linear_status\":\"active\",${CAMP_ACTIVE}}"
want   'invalid_slug' '"error": "invalid_slug_format"'

# invalid linear-status (carries the literal "--linear-status" flag per the command).
decide 'invalid linear-status' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"bogus\",${CAMP_ACTIVE}}"
want   'invalid linear-status' '"error": "invalid_status"'
want   'invalid linear-status' '"flag": "--linear-status"'

# invalid linear-substatus (must be empty|paused).
decide 'invalid linear-substatus' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"active\",\"linear_substatus\":\"snoozed\",${CAMP_ACTIVE}}"
want   'invalid linear-substatus' '"error": "invalid_status"'
want   'invalid linear-substatus' '"flag": "--linear-substatus"'

# missing_required_flag — --linear-status (index 1) omitted; reported in flag-table order.
decide 'missing linear_status' "{\"slug\":\"municipalities-fy26-m05\",${CAMP_ACTIVE}}"
want   'missing linear_status' '"error": "missing_required_flag"'
want   'missing linear_status' '"flag": "linear_status"'

# Early-flag precedence: omit --slug (index 0) → the FIRST missing flag is reported,
# locking the flag-table-order contract at the early end too.
decide 'missing slug (early)' "{\"linear_status\":\"active\",${CAMP_ACTIVE}}"
want   'missing slug (early)' '"error": "missing_required_flag"'
want   'missing slug (early)' '"flag": "slug"'

# ── SECURITY: --target-org shell-injection rejected with NO side effect ────────
# CRITICAL: each scenario JSON is SINGLE-QUOTED so bash performs NO expansion on the
# `$(...)` / backtick payload at the call site — the literal injection string reaches
# the builder, which regex-rejects it. (A double-quoted or `${var/pat/repl}`-built
# payload would let bash itself run the command substitution during argument
# construction — proving nothing about the builder. Single quotes are the fix.)
decide 'inject command-substitution' '{"slug":"municipalities-fy26-m05","linear_status":"active","target_org":"$(touch pwned)","sf_state":{"campaign":{"Id":"701","Status":"In Progress","Substatus__c":null,"LastModifiedDate":"x"}}}'
want   'inject command-substitution' '"error": "invalid_target_org"'
decide 'inject backtick' '{"slug":"municipalities-fy26-m05","linear_status":"active","target_org":"`touch pwned`","sf_state":{"campaign":{"Id":"701","Status":"In Progress","Substatus__c":null,"LastModifiedDate":"x"}}}'
want   'inject backtick' '"error": "invalid_target_org"'

# ── determinism — same fixture twice → byte-identical emit artifact ───────────
if [ -f "$FIXTURE" ]; then
  # Run the batch builder inside an ISOLATED cwd (not the harness's) so the
  # no-side-effect check below is CWD-independent — a stray `pwned` from any other
  # source can't trip it, and a real regression's sentinel is found wherever in the box.
  box="$(mktemp -d)"; d1="$box/r1"; d2="$box/r2"
  ( cd "$box" && python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d1" ) >/dev/null 2>&1
  ( cd "$box" && python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d2" ) >/dev/null 2>&1
  if diff -q "$d1/status-update-emit.json" "$d2/status-update-emit.json" >/dev/null 2>&1; then ok; else
    bad 'determinism: two runs of the same fixture produced different artifacts'
  fi
  # the batch run (over a fixture that includes the injection scenario) leaves NO
  # side-effect sentinel anywhere in its isolated cwd — the payload is data the
  # builder regex-rejects, never shells.
  if [ -z "$(find "$box" -name pwned 2>/dev/null)" ]; then ok; else bad 'batch run created a pwned sentinel'; fi
  rm -rf "$box"
else
  bad "fixture not found for determinism check: $FIXTURE"
fi

# ── regex byte-identity parity (BC-12594 producer↔consumer discipline) ────────
# SLUG_RE in the builder MUST stay byte-identical to the canonical regex documented
# in the command + build_campaign_payload.SLUG_RE; target-org delegates to the shared
# validate_target_org.is_valid_target_org (no fork). Lock both.
PARITY="$(BUILDER="$BUILDER" HERE="$HERE" python3 - <<'PY'
import os, importlib.util
here = os.environ["HERE"]
spec = importlib.util.spec_from_file_location("bsup", os.environ["BUILDER"])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
problems = []
if m.SLUG_RE.pattern != r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$":
    problems.append(f"SLUG_RE drifted: {m.SLUG_RE.pattern!r}")
# target-org delegates to the shared validator (imported, not re-defined).
if not m.is_valid_target_org("brite-prod") or m.is_valid_target_org("$(id)"):
    problems.append("is_valid_target_org not behaving as the shared validator")
# Cross-file: the SAME SLUG_RE literal appears in the sibling build_campaign_payload.py.
bcp = os.path.join(here, "build_campaign_payload.py")
try:
    bcptext = open(bcp, encoding="utf-8").read()
    if r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$" not in bcptext:
        problems.append("canonical SLUG_RE absent from build_campaign_payload.py")
except OSError as e:
    problems.append(f"could not read build_campaign_payload.py for parity: {e}")
print("OK" if not problems else "; ".join(problems))
PY
)"
if [ "$PARITY" = "OK" ]; then ok; else bad "regex parity: $PARITY"; fi

# ── usage / error exit codes ──────────────────────────────────────────────────
( python3 "$BUILDER" ) >/dev/null 2>&1
if [ "$?" -ne 0 ]; then ok; else bad 'usage: no-mode invocation must exit non-zero'; fi

badfix="$(mktemp)"; printf 'not json\n' > "$badfix"
( python3 "$BUILDER" --scenarios "$badfix" --out-dir "$(mktemp -d)" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'malformed fixture must exit 2 (infra error)'; fi
rm -f "$badfix"

# --decide via a FILE path (not stdin) — the documented runtime alternative.
okfix="$(mktemp)"; printf '%s' "{\"slug\":\"municipalities-fy26-m05\",\"linear_status\":\"planning\",${CAMP_ACTIVE}}" > "$okfix"
fileout="$(python3 "$BUILDER" --decide "$okfix" 2>&1)"; filerc=$?
if [ "$filerc" -eq 0 ] && printf '%s' "$fileout" | grep -qF '"verdict": "would_update"'; then ok; else
  bad "--decide <file>: expected would_update from a file path, got rc=$filerc: $fileout"
fi
rm -f "$okfix"

# --decide on a MISSING file must exit 2 (BuildError), NOT an uncaught traceback.
( python3 "$BUILDER" --decide /no/such/scenario.json ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad '--decide on a missing file must exit 2 (BuildError, not a traceback)'; fi

# ── count floor — a vanished test block must fail loudly, not pass on a thin count
# Set to ~95% of the full count (currently 81) to preempt the recurring "loose floor"
# review finding while tolerating a single intentional assertion edit.
FLOOR=77
if [ "$pass" -lt "$FLOOR" ]; then
  echo "FATAL: only $pass assertions ran (floor=$FLOOR) — a test block was silently skipped" >&2
  exit 2
fi

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
