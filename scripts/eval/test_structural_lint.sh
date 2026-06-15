#!/usr/bin/env bash
# M1 structural-lint self-test — "test the lint" (BC-12588, ADR-028 Phase-1).
#
# This is the validate.sh-wired gate that proves the lint is trustworthy: every
# rule fires on a must-flag fixture, stays silent on a must-pass fixture, and the
# findings[] contract (rule_id/severity/message/file) holds. A red assertion here
# FAILS the build (a mandatory check that can't vanish — the §15a-bc-12589 lesson);
# the lint's FINDINGS, by contrast, are surfaced WARN-only by validate.sh.
#
# RESULT contract line drives the count (matches §2e / §15a-bc-12587/12589).
#
# Usage: bash scripts/eval/test_structural_lint.sh

set -u  # NOT set -e — the lint is asserted by inspecting output, not by aborting.

# Defuse the caller's git env (stale-pre-push-hook GIT_DIR leak, per CLAUDE.md).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"
LINT="$script_dir/structural_lint.py"
FIX="$script_dir/fixtures/structural_lint"

if [ ! -f "$LINT" ]; then
  echo "FATAL: structural_lint.py not found: $LINT" >&2
  exit 2
fi

pass=0
fail=0
LAST=""
LAST_RC=0

run() {  # lint --json <args...> → capture output + rc
  LAST="$(python3 "$LINT" --json "$@" 2>&1)"
  LAST_RC=$?
}

run_human() {  # lint <args...> (human renderer) → capture output + rc
  LAST="$(python3 "$LINT" "$@" 2>&1)"
  LAST_RC=$?
}

# has_finding <rule_id> [severity] — true if $LAST (a findings[] JSON array) holds
# a finding with that rule_id (and severity, if given). Robust to non-JSON output.
has_finding() {
  RID="$1" SEV="${2:-}" OUT="$LAST" python3 - <<'PY'
import json, os, sys
try:
    data = json.loads(os.environ["OUT"] or "[]")
except Exception:
    sys.exit(1)
rid = os.environ["RID"]
sev = os.environ["SEV"]
sys.exit(0 if any(f.get("rule_id") == rid and (not sev or f.get("severity") == sev) for f in data) else 1)
PY
}

assert_finding() {  # label rule_id severity
  if has_finding "$2" "$3"; then
    echo "  PASS  $1"; pass=$((pass + 1))
  else
    echo "  FAIL  $1 — expected finding $2/$3"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1))
  fi
}

assert_no_finding() {  # label rule_id
  # Also require the lint ran cleanly (rc 0): a crash / non-JSON output makes
  # has_finding return false, which would read as "no finding" = a false green.
  if [ "$LAST_RC" -ne 0 ]; then
    echo "  FAIL  $1 — lint did not run cleanly (rc=$LAST_RC)"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1)); return
  fi
  if has_finding "$2"; then
    echo "  FAIL  $1 — unexpected finding $2"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1))
  else
    echo "  PASS  $1"; pass=$((pass + 1))
  fi
}

assert_rc() {  # label expected_rc
  if [ "$LAST_RC" -eq "$2" ]; then
    echo "  PASS  $1 (rc=$LAST_RC)"; pass=$((pass + 1))
  else
    echo "  FAIL  $1 — rc expected=$2 got=$LAST_RC"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1))
  fi
}

# ── R1 — side-effecting command needs disable-model-invocation (severity gate) ──
echo "── R1 side-effecting gate ──"
run "$FIX/commands/r1-no-flag.md"
assert_rc       "R1: lint exits 0 even WITH findings (findings never fail the build)" 0
assert_finding  "R1: side-effecting command w/o flag → gate" R1-side-effecting-needs-flag gate

run "$FIX/commands/r1-with-flag.md"
assert_no_finding "R1: side-effecting WITH disable-model-invocation → no R1" R1-side-effecting-needs-flag

run "$FIX/commands/r1-override.md"
assert_finding    "R1: valid override → R1 downgraded to advisory" R1-side-effecting-needs-flag advisory
if has_finding R1-side-effecting-needs-flag gate; then
  echo "  FAIL  R1: valid override must NOT leave a gate finding"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1))
else
  echo "  PASS  R1: valid override leaves no gate finding"; pass=$((pass + 1))
fi

run "$FIX/commands/r1-empty-override.md"
assert_finding    "R1: empty override marker → still gate" R1-side-effecting-needs-flag gate
assert_finding    "R1: empty override marker → advisory note" R1-override-missing-reason advisory

run "$FIX/commands/r1-prose-mentions-override.md"
assert_finding    "R1: prose/inline-code mention of the override token does NOT suppress (still gate)" R1-side-effecting-needs-flag gate

# ── R2 — body too long (>= 500 lines; GATE — flipped BC-13216, ratchet 4/5) ─────
echo "── R2 body-too-long ──"
run "$FIX/commands/r2-long-body.md"
assert_finding    "R2: body >= 500 lines → gate (blocking via eval-gate)" R2-body-too-long gate
run "$FIX/commands/r1-with-flag.md"
assert_no_finding "R2: short body → no R2" R2-body-too-long

# ── R3 — description first-person (GATE — flipped BC-13213, ratchet 1/5) ────────
echo "── R3 description-quality ──"
run "$FIX/commands/r3-first-person.md"
assert_finding    "R3: first-person description → gate (blocking via eval-gate)" R3-description-quality gate
run "$FIX/commands/r1-with-flag.md"
assert_no_finding "R3: third-person description → no R3" R3-description-quality

# ── R5 — MCP tool names must be fully-qualified (GATE — flipped BC-13214, 2/5) ──
echo "── R5 mcp-not-fully-qualified ──"
run "$FIX/commands/r5-bare-mcp.md"
assert_finding    "R5: bare/unqualified allowed-tools entry → gate (blocking via eval-gate)" R5-mcp-not-fully-qualified gate
run "$FIX/commands/r1-with-flag.md"
assert_no_finding "R5: fully-qualified mcp + built-in → no R5" R5-mcp-not-fully-qualified

# ── R6 — hardcoded absolute / backslash paths (GATE — flipped BC-13215, ratchet 3/5) ──
echo "── R6 hardcoded-paths ──"
run "$FIX/commands/r6-absolute-path.md"
assert_finding    "R6: absolute /Users path → gate (blocking via eval-gate)" R6-hardcoded-paths gate
run "$FIX/commands/clean.md"
assert_no_finding "R6: URL + relative plugins/ + \${CLAUDE_PLUGIN_ROOT} → no R6" R6-hardcoded-paths
run "$FIX/commands/r6-placeholder-paths.md"
assert_no_finding "R6: placeholder usernames (.../…/<>/\$VAR) → no R6" R6-hardcoded-paths
run "$FIX/commands/r6-placeholder-then-real.md"
assert_finding    "R6: placeholder then real path on one line → still flags (no dodge)" R6-hardcoded-paths gate
run "$FIX/commands/r6-win-path.md"
assert_finding    "R6: real Windows drive-letter path → gate" R6-hardcoded-paths gate
run "$FIX/commands/r6-placeholder-glued.md"
assert_finding    "R6: real username glued behind an ellipsis lead → still flags" R6-hardcoded-paths gate
run "$FIX/commands/r6-cross-regex.md"
assert_finding    "R6: exempted ABS placeholder falls through to a real WIN path (ABS-before-WIN)" R6-hardcoded-paths gate

# ── R4 — reference chain > 1 level deep (GATE — flipped BC-13217, ratchet 5/5) ──
echo "── R4 nested-refs ──"
run "$FIX/skills/r4-nested/SKILL.md"
assert_finding    "R4: referenced file itself references a further file → gate (blocking via eval-gate)" R4-nested-refs gate
run "$FIX/commands/clean.md"
assert_no_finding "R4: no resolvable nested chain → no R4" R4-nested-refs

# ── R7 — evals.json deprecation marker (advisory) ───────────────────────────────
echo "── R7 evals-json-undeprecated ──"
run "$FIX/evals/unmarked/evals.json"
assert_finding    "R7: evals.json without _deprecated marker → advisory" R7-evals-json-undeprecated advisory
run "$FIX/evals/marked/evals.json"
assert_no_finding "R7: evals.json WITH _deprecated marker → no R7" R7-evals-json-undeprecated

# ── findings[] contract + integration ──────────────────────────────────────────
echo "── findings[] contract + integration ──"

# A clean, canonical command → ZERO findings (no false positives across all rules).
run "$FIX/commands/clean.md"
if [ "$(printf '%s' "$LAST" | tr -d '[:space:]')" = "[]" ]; then
  echo "  PASS  clean command → zero findings"; pass=$((pass + 1))
else
  echo "  FAIL  clean command should produce no findings"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1))
fi

# Every finding carries the M5 consumer-contract keys + a valid severity value.
run "$FIX/commands/r1-no-flag.md"
if OUT="$LAST" python3 - <<'PY'
import json, os, sys
data = json.loads(os.environ["OUT"])
assert data, "expected findings"
for f in data:
    assert {"rule_id", "severity", "message", "file"} <= set(f), f
    assert "line" in f, f  # present (may be null)
    assert f["severity"] in ("gate", "advisory"), f
PY
then
  echo "  PASS  findings carry {rule_id,severity,message,file,line} + valid severity"; pass=$((pass + 1))
else
  echo "  FAIL  findings[] contract violated"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1))
fi

# Human renderer labels gate-tier findings — the validate.sh-visible marker that
# these warnings are the ones eval_gate enforces (diff-gate + --structural, ADR-034).
run_human "$FIX/commands/r1-no-flag.md"
if printf '%s' "$LAST" | grep -qF '[gate-tier · blocking via eval-gate]'; then
  echo "  PASS  human output labels gate-tier findings"; pass=$((pass + 1))
else
  echo "  FAIL  human output missing the gate-tier label"; printf '    out: %s\n' "$LAST"; fail=$((fail + 1))
fi

# Repo-wide scan runs clean: findings are WARN-only, so the lint exits 0 even with
# a large debt surface, and emits a machine SUMMARY line validate.sh parses.
run_human --scan-repo
assert_rc "scan-repo exits 0 (advisory: findings never fail the build)" 0
if printf '%s' "$LAST" | grep -qE '^SUMMARY findings=[0-9]+ gate=[0-9]+ advisory=[0-9]+ files=[0-9]+$'; then
  echo "  PASS  scan-repo emits a SUMMARY line"; pass=$((pass + 1))
else
  echo "  FAIL  scan-repo missing SUMMARY line"; printf '    out: %s\n' "$(printf '%s' "$LAST" | tail -3)"; fail=$((fail + 1))
fi

# ── exit-code contract (validate.sh "couldn't run → FAIL" + the M5 contract) ────
# Findings exit 0 (asserted above); a usage/read/internal error must exit 2 so
# validate.sh's Part-2 else-branch can distinguish "couldn't run" from "found issues".
echo "── exit-code contract ──"
run_human
assert_rc "no paths given → exit 2 (usage error, not a finding)" 2
run_human "$FIX/commands/does-not-exist.md"
assert_rc "nonexistent/unreadable spec → exit 2 (internal error, not a finding)" 2

echo ""
# Count floor — a silently-skipped block must fail loudly, not drop the count.
FLOOR=32
if [ "$pass" -lt "$FLOOR" ]; then
  echo "FATAL: only $pass assertions ran (floor=$FLOOR) — a test block was silently skipped" >&2
  exit 2
fi

echo "RESULT pass=$pass fail=$fail"
[ "$fail" -gt 0 ] && exit 1
exit 0
