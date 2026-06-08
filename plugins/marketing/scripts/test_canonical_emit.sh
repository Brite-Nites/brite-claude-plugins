#!/usr/bin/env bash
# Unit / contract suite for plugins/marketing/scripts/build_canonical_emit.py
# (BC-12702 + BC-12915, ADR-028 structure-first / LLM-judged representatives).
#
# build_canonical_emit.py is the hermetic emit harness the behavioral evals for the
# canonicals bootstrap command family (/marketing:new-offer, new-persona, new-vertical)
# drive. It does NOT re-implement any logic — it shells the SAME runtime entrypoints the
# commands delegate to (canonicals_bootstrap.py `<subcommand>`, which OWNS every input
# guard, + lint_canonicals.py, the 19-check ADR-016 contract) against a sandbox copy of a
# SHARED frozen seed. This suite drives every verdict branch across all three subcommands,
# proves a scenario value is NEVER shelled (a `$(touch pwned)` display reaches the entry as
# inert data — no `pwned` sentinel), and locks determinism + infra exit codes. The
# behavioral eval (scripts/eval/test_eval_harness.sh) asserts the emit-artifact STRUCTURE;
# this asserts the builder's per-branch DECISIONS + injection-safety + determinism.
#
# Usage:
#   bash plugins/marketing/scripts/test_canonical_emit.sh
#   bash plugins/marketing/scripts/test_canonical_emit.sh /path/to/build_canonical_emit.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the usage/error scenarios.

# Defuse caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="${1:-$HERE/build_canonical_emit.py}"
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

# emit "<subcommand>" "<label>" '<scenarios-json>'  → runs the batch builder in an
# ISOLATED cwd box, asserts exit 0 (a built matrix is always a successful run, even when
# every row is ok:false) AND that no `pwned` side-effect sentinel was created. Loads
# <subcommand>-emit.json into EMIT_OUT for substring asserts.
# CRITICAL: each scenarios JSON is SINGLE-QUOTED at the call site so bash performs NO
# expansion on a `$(...)` payload — the literal injection string reaches the builder.
EMIT_OUT=""
emit() {
  local sub="$1" label="$2" scenarios="$3" box fixture outdir rc sidefx=0 art
  box="$(mktemp -d)"; fixture="$box/fixture.json"; outdir="$box/out"; art="$outdir/${sub}-emit.json"
  printf '%s' "$scenarios" > "$fixture"
  EMIT_OUT="$(cd "$box" && python3 "$BUILDER" --subcommand "$sub" --scenarios "$fixture" --out-dir "$outdir" --seed-dir "$SEED" 2>&1)"
  rc=$?
  [ -n "$(find "$box" -name pwned 2>/dev/null)" ] && sidefx=1
  if [ -f "$art" ]; then EMIT_OUT="$(cat "$art")"; fi
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

# ── offer subcommand ──────────────────────────────────────────────────────────
emit offer 'offer valid_add' '{"scenarios":[{"id":"v","vertical":"sample-vertical","slug":"holiday-anchor-audit","display":"Resort Holiday Anchor Audit","posture":"pilot","status":"draft"}]}'
want 'offer valid_add' '"ok": true'
want 'offer valid_add' '"action": "created_offer"'
want 'offer valid_add' '"exit_code": 0'
emit offer 'offer duplicate' '{"scenarios":[{"id":"d","vertical":"sample-vertical","slug":"existing-offer","display":"Dup","posture":"knowledge"}]}'
want 'offer duplicate' 'already exists'
emit offer 'offer invalid_posture' '{"scenarios":[{"id":"p","vertical":"sample-vertical","slug":"premium-offer","display":"Premium","posture":"premium"}]}'
want 'offer invalid_posture' "posture 'premium' invalid"

# ── persona subcommand ────────────────────────────────────────────────────────
emit persona 'persona valid_add' '{"scenarios":[{"id":"v","vertical":"sample-vertical","slug":"revenue-lead","display":"Revenue Lead","titles":"VP Revenue,CRO"}]}'
want 'persona valid_add' '"action": "created_persona"'
want 'persona valid_add' '"exit_code": 0'
want 'persona valid_add' '"VP Revenue"'
emit persona 'persona duplicate' '{"scenarios":[{"id":"d","vertical":"sample-vertical","slug":"ops-director","display":"Dup","titles":"X"}]}'
want 'persona duplicate' 'already exists'
emit persona 'persona unknown_vertical' '{"scenarios":[{"id":"u","vertical":"no-such-vertical","slug":"x-persona","display":"X","titles":"Y"}]}'
want 'persona unknown_vertical' 'not in canonicals manifest'

# ── vertical subcommand ───────────────────────────────────────────────────────
emit vertical 'vertical valid_add' '{"scenarios":[{"id":"v","slug":"art-museums","display":"Art Museums","aliases":"galleries,museums"}]}'
want 'vertical valid_add' '"action": "created_vertical"'
want 'vertical valid_add' '"exit_code": 0'
emit vertical 'vertical duplicate' '{"scenarios":[{"id":"d","slug":"sample-vertical","display":"Dup"}]}'
want 'vertical duplicate' 'already exists in manifest'
emit vertical 'vertical invalid_alias' '{"scenarios":[{"id":"a","slug":"valid-vert","display":"Valid","aliases":"Bad Alias"}]}'
want 'vertical invalid_alias' 'alias slug'

# ── SECURITY: a scenario value is never shelled (no `pwned` sentinel) ──────────────
# (a) an injection-shaped SLUG fails the kebab guard → ok:false, no side effect.
emit offer 'inject slug' '{"scenarios":[{"id":"x","vertical":"sample-vertical","slug":"$(touch pwned)","display":"X","posture":"knowledge"}]}'
want 'inject slug' '"ok": false'
want 'inject slug' 'not kebab-case'
# (b) an injection-shaped DISPLAY on an OTHERWISE-VALID entry is written as inert data
#     (display is free text) — the value reaches the entry + the argv of two subprocesses,
#     NEVER a shell, so still no `pwned`. The emit() no-side-effect assertion is the
#     load-bearing check here.
emit offer 'inject display' '{"scenarios":[{"id":"y","vertical":"sample-vertical","slug":"audit-offer","display":"$(touch pwned)","posture":"knowledge"}]}'
want 'inject display' '"ok": true'

# ── determinism — same fixture twice → byte-identical emit artifact ───────────────
DET='{"scenarios":[{"id":"v","vertical":"sample-vertical","slug":"holiday-anchor-audit","display":"Resort Holiday Anchor Audit","posture":"pilot","status":"draft"},{"id":"d","vertical":"sample-vertical","slug":"existing-offer","display":"Dup","posture":"knowledge"}]}'
box="$(mktemp -d)"; printf '%s' "$DET" > "$box/f.json"
( cd "$box" && python3 "$BUILDER" --subcommand offer --scenarios "$box/f.json" --out-dir "$box/r1" --seed-dir "$SEED" ) >/dev/null 2>&1
( cd "$box" && python3 "$BUILDER" --subcommand offer --scenarios "$box/f.json" --out-dir "$box/r2" --seed-dir "$SEED" ) >/dev/null 2>&1
if diff -q "$box/r1/offer-emit.json" "$box/r2/offer-emit.json" >/dev/null 2>&1; then ok; else
  bad 'determinism: two runs of the same fixture produced different artifacts'
fi
if [ -z "$(find "$box" -name pwned 2>/dev/null)" ]; then ok; else bad 'batch run created a pwned sentinel'; fi
rm -rf "$box"

# ── usage / infra-error exit codes (an infra failure is exit 2, distinct from a verdict)
( python3 "$BUILDER" ) >/dev/null 2>&1
if [ "$?" -ne 0 ]; then ok; else bad 'usage: no-args invocation must exit non-zero'; fi

# an unknown --subcommand is an argparse usage error (choices=) → exit 2.
okfix="$(mktemp)"; outbox="$(mktemp -d)"
printf '%s' '{"scenarios":[{"id":"v","vertical":"sample-vertical","slug":"x-offer","display":"X","posture":"knowledge"}]}' > "$okfix"
( python3 "$BUILDER" --subcommand widget --scenarios "$okfix" --out-dir "$outbox" --seed-dir "$SEED" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'unknown --subcommand must exit 2 (argparse choices)'; fi
rm -rf "$outbox"

badfix="$(mktemp)"; printf 'not json\n' > "$badfix"; outbox="$(mktemp -d)"
( python3 "$BUILDER" --subcommand offer --scenarios "$badfix" --out-dir "$outbox" --seed-dir "$SEED" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'malformed fixture must exit 2 (infra error)'; fi
rm -f "$badfix"; rm -rf "$outbox"

outbox="$(mktemp -d)"
( python3 "$BUILDER" --subcommand offer --scenarios /no/such/fixture.json --out-dir "$outbox" --seed-dir "$SEED" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'missing fixture must exit 2 (BuildError, not a traceback)'; fi
rm -rf "$outbox"

# a scenario missing a required key (offer with no posture) must exit 2 (BuildError).
missfix="$(mktemp)"; printf '%s' '{"scenarios":[{"id":"m","vertical":"sample-vertical","slug":"x-offer","display":"X"}]}' > "$missfix"; outbox="$(mktemp -d)"
( python3 "$BUILDER" --subcommand offer --scenarios "$missfix" --out-dir "$outbox" --seed-dir "$SEED" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'scenario missing a required key must exit 2 (BuildError)'; fi
rm -f "$missfix"; rm -rf "$outbox"

# a seed dir without _manifest.yaml must exit 2 (BuildError), not a confusing crash.
emptyseed="$(mktemp -d)"; outbox="$(mktemp -d)"
( python3 "$BUILDER" --subcommand offer --scenarios "$okfix" --out-dir "$outbox" --seed-dir "$emptyseed" ) >/dev/null 2>&1
if [ "$?" -eq 2 ]; then ok; else bad 'seed dir without _manifest.yaml must exit 2 (BuildError)'; fi
rm -rf "$emptyseed" "$outbox"; rm -f "$okfix"

# ── count floor — a vanished test block must fail loudly, not pass on a thin count ──
# Calibrated tight (47 assertions actual, margin 5 ≈ 89%) to match the eval-harness
# discipline; a loose floor is a wide wedge where coverage can silently erode before the
# guard fires (the BC-12702 Greptile lesson). Losing any subcommand block (~6), the
# injection block (~6), or determinism (~2) drops the count below 42 and trips this.
FLOOR=42
if [ "$pass" -lt "$FLOOR" ]; then
  echo "FATAL: only $pass assertions ran (floor=$FLOOR) — a test block was silently skipped" >&2
  exit 2
fi

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
