#!/usr/bin/env bash
# Unit / contract suite for plugins/revops/scripts/build_campaign_payload.py
# (BC-12701, ADR-028 eval #2 — the side-effecting representative).
#
# build_campaign_payload.py is the PURE deterministic decision core
# /revops:create-sf-campaign delegates to in BOTH its normal and emit runs (the
# single shared entrypoint — so the behavioral eval can't certify a parallel
# path). Given (inputs, injected sf_state) it computes the would_create /
# would_skip_duplicate / error VERDICT + the SF Campaign payload, with NO SOQL,
# NO SF write, NO shell-out. This suite drives the builder directly across every
# verdict branch AND proves the security property the command's --target-org guard
# rests on: a `$(touch pwned)` value is REJECTED with no side effect (the builder
# only ever regex-matches it — it never reaches a shell). The behavioral eval
# (scripts/eval/test_eval_harness.sh) asserts the emit-artifact STRUCTURE; this
# asserts the builder's per-branch DECISIONS + injection-safety + determinism.
#
# Usage:
#   bash plugins/revops/scripts/test_build_campaign_payload.sh
#   bash plugins/revops/scripts/test_build_campaign_payload.sh /path/to/build_campaign_payload.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.

# Defuse caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md; matches
# test_validate_target_org.sh / test_build_manifest.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_campaign_payload.py}"
FIXTURE="$HERE/../tests/eval/create-sf-campaign.fixture.json"

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

# A complete, valid would_create scenario (slug matches the canonical regex).
BASE='"slug":"municipalities-fy26-m05","entity":"nites","vertical":"v","persona":"p","offer":"o","year":2026,"month":5,"owner_email":"a@b.com","launch_date":"2026-05-01","target_org":"brite-prod"'

# ── verdict branches ──────────────────────────────────────────────────────────

decide 'would_create' "{${BASE},\"sf_state\":{\"existing_campaigns\":[],\"owner\":{\"id\":\"005ABC\"}}}"
want   'would_create' '"verdict": "would_create"'
want   'would_create' '"OwnerId": "005ABC"'
want   'would_create' '"Status": "Planned"'
want   'would_create' '"campaign_id": null'

decide 'duplicate' "{${BASE},\"sf_state\":{\"existing_campaigns\":[{\"Id\":\"701DUP\",\"Name\":\"municipalities-fy26-m05\"}],\"owner\":{\"id\":\"005ABC\"}}}"
want   'duplicate' '"verdict": "would_skip_duplicate"'
want   'duplicate' '"existing_id": "701DUP"'

# Exact-match dedup (refinement #2): a row with a DIFFERENT Name is NOT a duplicate.
decide 'near_miss_not_duplicate' "{${BASE},\"sf_state\":{\"existing_campaigns\":[{\"Id\":\"701X\",\"Name\":\"municipalities-fy26-m06\"}],\"owner\":{\"id\":\"005ABC\"}}}"
want   'near_miss_not_duplicate' '"verdict": "would_create"'

decide 'missing_owner' "{${BASE},\"sf_state\":{\"existing_campaigns\":[],\"owner\":null}}"
want   'missing_owner' '"verdict": "error"'
want   'missing_owner' '"error": "missing_owner"'

# invalid_slug — a slug that fails the canonical regex.
decide 'invalid_slug' '{"slug":"Not A Slug","entity":"nites","vertical":"v","persona":"p","offer":"o","year":2026,"month":5,"owner_email":"a@b.com","launch_date":"2026-05-01","sf_state":{"existing_campaigns":[],"owner":{"id":"005"}}}'
want   'invalid_slug' '"error": "invalid_slug_format"'

# invalid_owner_email — fails EMAIL_RE.
decide 'invalid_owner_email' '{"slug":"municipalities-fy26-m05","entity":"nites","vertical":"v","persona":"p","offer":"o","year":2026,"month":5,"owner_email":"not-an-email","launch_date":"2026-05-01","sf_state":{"existing_campaigns":[],"owner":{"id":"005"}}}'
want   'invalid_owner_email' '"error": "invalid_owner_email"'

# missing_required_flag — --offer (index 5) omitted; reported in flag-table order.
decide 'missing_required_flag' '{"slug":"municipalities-fy26-m05","entity":"nites","vertical":"v","persona":"p","year":2026,"month":5,"owner_email":"a@b.com","launch_date":"2026-05-01","sf_state":{"existing_campaigns":[],"owner":{"id":"005"}}}'
want   'missing_required_flag' '"error": "missing_required_flag"'
want   'missing_required_flag' '"flag": "offer"'

# Early-flag precedence: omit --slug (index 0) → the FIRST missing flag is reported,
# locking the flag-table-order contract at the early end too (not only the offer index).
decide 'missing_required_flag (early: slug)' '{"entity":"nites","vertical":"v","persona":"p","offer":"o","year":2026,"month":5,"owner_email":"a@b.com","launch_date":"2026-05-01","sf_state":{"existing_campaigns":[],"owner":{"id":"005"}}}'
want   'missing_required_flag (early: slug)' '"error": "missing_required_flag"'
want   'missing_required_flag (early: slug)' '"flag": "slug"'

# ── SECURITY: --target-org shell-injection rejected with NO side effect ────────
# command-substitution + backtick payloads, explicit. CRITICAL: each scenario JSON is
# SINGLE-QUOTED so bash performs NO expansion on the `$(...)` / backtick payload at the
# call site — the literal injection string reaches the builder, which regex-rejects it.
# (A double-quoted or `${var/pat/repl}`-built payload would let bash itself run the
# command substitution during argument construction — the test would then execute the
# payload in its own CWD and prove nothing about the builder. Single quotes are the fix.)
decide 'inject command-substitution' '{"slug":"municipalities-fy26-m05","entity":"nites","vertical":"v","persona":"p","offer":"o","year":2026,"month":5,"owner_email":"a@b.com","launch_date":"2026-05-01","target_org":"$(touch pwned)","sf_state":{"existing_campaigns":[],"owner":{"id":"005"}}}'
want   'inject command-substitution' '"error": "invalid_target_org"'
decide 'inject backtick' '{"slug":"municipalities-fy26-m05","entity":"nites","vertical":"v","persona":"p","offer":"o","year":2026,"month":5,"owner_email":"a@b.com","launch_date":"2026-05-01","target_org":"`touch pwned`","sf_state":{"existing_campaigns":[],"owner":{"id":"005"}}}'
want   'inject backtick' '"error": "invalid_target_org"'

# ── determinism — same fixture twice → byte-identical emit artifact ───────────
if [ -f "$FIXTURE" ]; then
  # Run the batch builder inside an ISOLATED cwd (not the harness's) so the
  # no-side-effect check below is CWD-independent — a stray `pwned` from any other
  # source can't trip it, and a real regression's sentinel is found wherever in the box.
  box="$(mktemp -d)"; d1="$box/r1"; d2="$box/r2"
  ( cd "$box" && python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d1" ) >/dev/null 2>&1
  ( cd "$box" && python3 "$BUILDER" --scenarios "$FIXTURE" --out-dir "$d2" ) >/dev/null 2>&1
  if diff -q "$d1/campaign-emit.json" "$d2/campaign-emit.json" >/dev/null 2>&1; then ok; else
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
# SLUG_RE / EMAIL_RE in the builder MUST stay byte-identical to the canonical
# regexes documented in the command + build_manifest.py; target-org delegates to
# the shared validate_target_org.is_valid_target_org (no fork). Lock all three.
PARITY="$(BUILDER="$BUILDER" HERE="$HERE" python3 - <<'PY'
import os, sys, importlib.util, re
here = os.environ["HERE"]
spec = importlib.util.spec_from_file_location("bcp", os.environ["BUILDER"])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
problems = []
if m.SLUG_RE.pattern != r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$":
    problems.append(f"SLUG_RE drifted: {m.SLUG_RE.pattern!r}")
if m.EMAIL_RE.pattern != r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$":
    problems.append(f"EMAIL_RE drifted: {m.EMAIL_RE.pattern!r}")
# target-org delegates to the shared validator (imported, not re-defined).
if not m.is_valid_target_org("brite-prod") or m.is_valid_target_org("$(id)"):
    problems.append("is_valid_target_org not behaving as the shared validator")
# Cross-file: the same SLUG_RE/EMAIL_RE literals appear in build_manifest.py.
bm = os.path.join(here, "../../marketing/scripts/build_manifest.py")
try:
    bmtext = open(bm, encoding="utf-8").read()
    for lit in (r"^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$",
                r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"):
        if lit not in bmtext:
            problems.append(f"canonical regex absent from build_manifest.py: {lit}")
except OSError as e:
    problems.append(f"could not read build_manifest.py for parity: {e}")
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
okfix="$(mktemp)"; printf '%s' "{${BASE},\"sf_state\":{\"existing_campaigns\":[],\"owner\":{\"id\":\"005FILE\"}}}" > "$okfix"
fileout="$(python3 "$BUILDER" --decide "$okfix" 2>&1)"; filerc=$?
if [ "$filerc" -eq 0 ] && printf '%s' "$fileout" | grep -qF '"OwnerId": "005FILE"'; then ok; else
  bad "--decide <file>: expected would_create from a file path, got rc=$filerc: $fileout"
fi
rm -f "$okfix"

# --decide on a MISSING file must exit 2 (BuildError), NOT an uncaught traceback.
( python3 "$BUILDER" --decide /no/such/scenario.json ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad '--decide on a missing file must exit 2 (BuildError, not a traceback)'; fi

# ── count floor — a vanished test block must fail loudly, not pass on a thin count
FLOOR=30
if [ "$pass" -lt "$FLOOR" ]; then
  echo "FATAL: only $pass assertions ran (floor=$FLOOR) — a test block was silently skipped" >&2
  exit 2
fi

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
