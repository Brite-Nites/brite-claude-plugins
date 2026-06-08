#!/usr/bin/env bash
# Unit / contract suite for plugins/marketing/scripts/build_offer_emit.py
# (BC-12702, ADR-028 eval #3 — the structure-first / LLM-judged representative).
#
# build_offer_emit.py is the hermetic emit harness /marketing:new-offer's behavioral
# eval drives. It does NOT re-implement offer logic — it shells the SAME runtime
# entrypoints the command delegates to (canonicals_bootstrap.py `offer`, which OWNS
# every input guard, + lint_canonicals.py, the 19-check ADR-016 contract) against a
# sandbox copy of a FROZEN seed. This suite drives the builder directly across every
# verdict branch (clean write / near-miss / duplicate / unknown-vertical /
# invalid-posture / invalid-status / invalid-slug), proves it is deterministic, and
# proves it NEVER shells a scenario value — a `$(touch pwned)` display reaches the
# offer entry as inert data (passed via argv to a subprocess list, never a shell), so
# no `pwned` sentinel is ever created. The behavioral eval
# (scripts/eval/test_eval_harness.sh) asserts the emit-artifact STRUCTURE; this asserts
# the builder's per-branch DECISIONS + injection-safety + determinism + infra exit codes.
#
# Usage:
#   bash plugins/marketing/scripts/test_build_offer_emit.sh
#   bash plugins/marketing/scripts/test_build_offer_emit.sh /path/to/build_offer_emit.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.

# Defuse caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md; matches
# test_build_campaign_payload.sh / test_canonicals_bootstrap.sh discipline).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_offer_emit.py}"
SEED="$HERE/../tests/eval/new-offer-seed"

if [ ! -f "$BUILDER" ]; then
  echo "FATAL: builder not found: $BUILDER" >&2
  exit 2
fi
if [ ! -f "$SEED/_manifest.yaml" ]; then
  echo "FATAL: frozen seed not found: $SEED/_manifest.yaml" >&2
  exit 2
fi

pass=0
fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

# emit "<label>" '<scenarios-json>'  → runs the batch builder in an ISOLATED cwd box,
# asserts exit 0 (a built matrix is always a successful run, even when every row is
# ok:false) AND that no `pwned` side-effect sentinel was created anywhere in the box.
# Loads offer-emit.json into EMIT_OUT for substring asserts.
# CRITICAL: each scenarios JSON is SINGLE-QUOTED at the call site so bash performs NO
# expansion on a `$(...)` / backtick payload — the literal injection string reaches the
# builder. (A double-quoted payload would let bash run the command-substitution during
# argument construction; the test would execute the payload itself and prove nothing.)
EMIT_OUT=""
emit() {
  local label="$1" scenarios="$2" box fixture outdir rc sidefx=0
  box="$(mktemp -d)"; fixture="$box/fixture.json"; outdir="$box/out"
  printf '%s' "$scenarios" > "$fixture"
  EMIT_OUT="$(cd "$box" && python3 "$BUILDER" --scenarios "$fixture" --out-dir "$outdir" --seed-dir "$SEED" 2>&1)"
  rc=$?
  [ -n "$(find "$box" -name pwned 2>/dev/null)" ] && sidefx=1
  if [ -f "$outdir/offer-emit.json" ]; then EMIT_OUT="$(cat "$outdir/offer-emit.json")"; fi
  rm -rf "$box"
  if [ "$rc" -eq 0 ]; then ok; else bad "$label: builder exited $rc (expected 0): $EMIT_OUT"; fi
  if [ "$sidefx" -eq 0 ]; then ok; else bad "$label: created the pwned sentinel — builder shelled a scenario value!"; fi
}

want() {  # want "<label>" "<substring>"  — assert EMIT_OUT contains substring
  local label="$1" sub="$2"
  if printf '%s' "$EMIT_OUT" | grep -qF -- "$sub"; then ok; else
    bad "$label: missing [$sub] in: $EMIT_OUT"
  fi
}

# ── verdict branches (each row isolates one fault; builder owns every guard) ──────

emit 'valid_add' '{"scenarios":[{"id":"v","vertical":"sample-vertical","slug":"holiday-anchor-audit","display":"Resort Holiday Anchor Audit","posture":"pilot","status":"draft"}]}'
want 'valid_add' '"ok": true'
want 'valid_add' '"action": "created_offer"'
want 'valid_add' '"slug": "holiday-anchor-audit"'
want 'valid_add' '"exit_code": 0'

# near-miss: a slug SIMILAR to the seed's 'existing-offer' but different → NOT a duplicate.
emit 'near_miss' '{"scenarios":[{"id":"n","vertical":"sample-vertical","slug":"existing-offer-v2","display":"Existing Offer V2","posture":"knowledge","status":"active"}]}'
want 'near_miss' '"ok": true'
want 'near_miss' '"slug": "existing-offer-v2"'

emit 'duplicate' '{"scenarios":[{"id":"d","vertical":"sample-vertical","slug":"existing-offer","display":"Dup","posture":"knowledge"}]}'
want 'duplicate' '"ok": false'
want 'duplicate' 'already exists'

emit 'unknown_vertical' '{"scenarios":[{"id":"u","vertical":"no-such-vertical","slug":"some-offer","display":"Some Offer","posture":"pilot"}]}'
want 'unknown_vertical' 'not in canonicals manifest'

emit 'invalid_posture' '{"scenarios":[{"id":"p","vertical":"sample-vertical","slug":"premium-offer","display":"Premium","posture":"premium"}]}'
want 'invalid_posture' "posture 'premium' invalid"

emit 'invalid_status' '{"scenarios":[{"id":"s","vertical":"sample-vertical","slug":"status-offer","display":"Status","posture":"knowledge","status":"launched"}]}'
want 'invalid_status' "status 'launched' invalid"

emit 'invalid_slug' '{"scenarios":[{"id":"i","vertical":"sample-vertical","slug":"Not A Slug","display":"Bad","posture":"knowledge"}]}'
want 'invalid_slug' 'not kebab-case'

# ── SECURITY: a scenario value is never shelled (no `pwned` sentinel) ──────────────
# (a) an injection-shaped SLUG fails the kebab guard → ok:false, no side effect.
emit 'inject slug' '{"scenarios":[{"id":"x","vertical":"sample-vertical","slug":"$(touch pwned)","display":"X","posture":"knowledge"}]}'
want 'inject slug' '"ok": false'
want 'inject slug' 'not kebab-case'
# (b) an injection-shaped DISPLAY on an OTHERWISE-VALID offer is written as inert data
#     (display is free text; lint only requires non-empty) — the value reaches the offer
#     entry + the argv of two subprocesses, NEVER a shell, so still no `pwned`. The emit()
#     no-side-effect assertion is the load-bearing check here.
emit 'inject display' '{"scenarios":[{"id":"y","vertical":"sample-vertical","slug":"audit-offer","display":"$(touch pwned)","posture":"knowledge"}]}'
want 'inject display' '"ok": true'

# ── determinism — same fixture twice → byte-identical emit artifact ───────────────
DET_FIX='{"scenarios":[{"id":"v","vertical":"sample-vertical","slug":"holiday-anchor-audit","display":"Resort Holiday Anchor Audit","posture":"pilot","status":"draft"},{"id":"d","vertical":"sample-vertical","slug":"existing-offer","display":"Dup","posture":"knowledge"}]}'
box="$(mktemp -d)"; printf '%s' "$DET_FIX" > "$box/f.json"
( cd "$box" && python3 "$BUILDER" --scenarios "$box/f.json" --out-dir "$box/r1" --seed-dir "$SEED" ) >/dev/null 2>&1
( cd "$box" && python3 "$BUILDER" --scenarios "$box/f.json" --out-dir "$box/r2" --seed-dir "$SEED" ) >/dev/null 2>&1
if diff -q "$box/r1/offer-emit.json" "$box/r2/offer-emit.json" >/dev/null 2>&1; then ok; else
  bad 'determinism: two runs of the same fixture produced different artifacts'
fi
# the batch run leaves NO side-effect sentinel anywhere in its isolated box.
if [ -z "$(find "$box" -name pwned 2>/dev/null)" ]; then ok; else bad 'batch run created a pwned sentinel'; fi
rm -rf "$box"

# ── usage / infra-error exit codes (an infra failure is exit 2, distinct from a verdict)
( python3 "$BUILDER" ) >/dev/null 2>&1
if [ "$?" -ne 0 ]; then ok; else bad 'usage: no-args invocation must exit non-zero'; fi

badfix="$(mktemp)"; printf 'not json\n' > "$badfix"; outbox="$(mktemp -d)"
( python3 "$BUILDER" --scenarios "$badfix" --out-dir "$outbox" --seed-dir "$SEED" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'malformed fixture must exit 2 (infra error)'; fi
rm -f "$badfix"; rm -rf "$outbox"

outbox="$(mktemp -d)"
( python3 "$BUILDER" --scenarios /no/such/fixture.json --out-dir "$outbox" --seed-dir "$SEED" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'missing fixture must exit 2 (BuildError, not a traceback)'; fi
rm -rf "$outbox"

# a scenario missing a required key (no posture) must exit 2 (BuildError), not crash.
missfix="$(mktemp)"; printf '%s' '{"scenarios":[{"id":"m","vertical":"sample-vertical","slug":"x-offer","display":"X"}]}' > "$missfix"; outbox="$(mktemp -d)"
( python3 "$BUILDER" --scenarios "$missfix" --out-dir "$outbox" --seed-dir "$SEED" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'scenario missing a required key must exit 2 (BuildError)'; fi
rm -f "$missfix"; rm -rf "$outbox"

# a seed dir without _manifest.yaml must exit 2 (BuildError), not a confusing crash.
emptyseed="$(mktemp -d)"; okfix="$(mktemp)"; outbox="$(mktemp -d)"
printf '%s' '{"scenarios":[{"id":"v","vertical":"sample-vertical","slug":"x-offer","display":"X","posture":"knowledge"}]}' > "$okfix"
( python3 "$BUILDER" --scenarios "$okfix" --out-dir "$outbox" --seed-dir "$emptyseed" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'seed dir without _manifest.yaml must exit 2 (BuildError)'; fi
rm -rf "$emptyseed" "$outbox"; rm -f "$okfix"

# ── count floor — a vanished test block must fail loudly, not pass on a thin count ──
# Calibrated tight (40 assertions actual, margin 5) to match the eval-harness discipline
# (~95%); a loose floor is a wide wedge where coverage can silently erode before the guard
# fires. Losing the verdict-branch block (~14), the injection block (~4), determinism (~2),
# or any infra case drops the count below 35 and trips this.
FLOOR=35
if [ "$pass" -lt "$FLOOR" ]; then
  echo "FATAL: only $pass assertions ran (floor=$FLOOR) — a test block was silently skipped" >&2
  exit 2
fi

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
