#!/usr/bin/env bash
# BC-7061 flow-architecture mode-classifier eval harness.
#
# Stages a temp project directory per case in fixtures/mode-classifier-eval.json,
# invokes scripts/flow-detect-mode.sh against it, and compares stdout to the
# case's expected_mode. Mirrors the BC-7059 run-audit-smoke.sh pattern
# (literal-string-in-source AC anchor + skip-with-reason for non-headless phases)
# and the BC-6316 RevOps skill-activation eval pattern (per-case TP/TN matrix).
#
# Scope: classifier-output correctness only. Q12.5 preamble emission, Q36.3 user
# confirmation gate, and the Linear MCP path-A re-validation (.flow/config.json
# stale-detection) are skip-with-reason — none are filesystem-headless. The four
# modes (greenfield / retrofit / incremental-add / resume) are exercised at
# least once each across the eval cases.
#
# AC #5 anchor: this script contains the literal string MODE-CLASSIFIER-DRIFT-FAIL.
# The bucket names any case whose expected_mode falls outside the recognized
# {greenfield, retrofit, incremental-add, resume} registry — guards against
# a case-authoring typo (e.g., the issue body explicitly warns against
# "incremental" without the hyphen) silently passing through to a false PASS.
#
# bash 3.2+ compatible (Q32 floor). python3 3.6+ stdlib only (no jq).

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_JSON="$SCRIPT_DIR/fixtures/mode-classifier-eval.json"
DETECT_MODE="$SCRIPT_DIR/../scripts/flow-detect-mode.sh"
REPORT_MD="$SCRIPT_DIR/mode-classifier-eval-report.md"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$FIXTURE_JSON" ] || { echo "fatal: fixture missing: $FIXTURE_JSON" >&2; exit 1; }
[ -x "$DETECT_MODE" ] || [ -f "$DETECT_MODE" ] || { echo "fatal: flow-detect-mode.sh missing: $DETECT_MODE" >&2; exit 1; }

RECOGNIZED_MODES="greenfield retrofit incremental-add resume"
is_recognized_mode() {
  case " $RECOGNIZED_MODES " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

PASS=0
FAIL=0
SKIP=0
DRIFT=0

# Per-case result rows (TSV): id<TAB>expected<TAB>actual<TAB>status
RESULT_TSV="$(mktemp)"
WORKROOT="$(mktemp -d)"
trap 'rm -rf "$WORKROOT" "$RESULT_TSV"' EXIT

pass()    { printf '  PASS   %s\n' "$1"; PASS=$((PASS + 1)); }
fail()    { printf '  FAIL   %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip()    { printf '  SKIP   %s\n' "$1"; SKIP=$((SKIP + 1)); }
drift()   { printf '  DRIFT  %s\n' "$1"; DRIFT=$((DRIFT + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# stage_fixture <case-json-line> <dest-dir>
# Reads a single case JSON object via stdin, materializes the fixture_state on disk
# under <dest-dir>. Emits LINEAR_ISSUE_COUNT (the env name flow-detect-mode.sh reads)
# on stdout when set in the case — empty string when absent, which the caller treats
# as unset. The case JSON arrives via env var (CASE_JSON) to keep argv clean.
stage_fixture() {
  local dest="$1"
  mkdir -p "$dest/docs/product" "$dest/docs/plans"
  CASE_JSON="$CASE_JSON" DEST="$dest" python3 - <<'PY'
import json, os, pathlib, sys, datetime

case = json.loads(os.environ["CASE_JSON"])
state = case["fixture_state"]
dest = pathlib.Path(os.environ["DEST"])

if state.get("intent"):
    (dest / "docs/product/intent.md").write_text(
        "# intent (eval fixture stub)\n", encoding="utf-8"
    )
if state.get("inventory"):
    (dest / "docs/product/master-flow-inventory.md").write_text(
        "# master-flow-inventory (eval fixture stub)\n", encoding="utf-8"
    )
if state.get("flows"):
    flows_dir = dest / "docs/product/flows/SAMPLE"
    flows_dir.mkdir(parents=True, exist_ok=True)
    (flows_dir / "SAMPLE-01.md").write_text(
        "# SAMPLE-01 (eval fixture stub)\n", encoding="utf-8"
    )

bc = state.get("breadcrumb")
if bc is not None:
    bc_path = dest / "docs/plans/.flow-phase-state.json"
    if bc.get("malformed"):
        bc_path.write_text("{ this is not valid json", encoding="utf-8")
    else:
        # ISO-8601 UTC timestamp offset by age_days into the past. flow-resume-
        # breadcrumb.sh's STALE_AGE_SECONDS is 7 days; we span that boundary
        # with 0d (fresh), 1d (fresh), 14d (stale-age) across the case list.
        age_days = int(bc.get("age_days", 0))
        ts = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(
            days=age_days
        )
        last_updated = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
        payload = {
            "version": "1",
            "mode": "incremental-add",
            "status": bc["status"],
            "linear_project_id": "00000000-0000-0000-0000-000000000000",
            "linear_project_name": "mode-classifier-eval-fixture",
            "linear_team_key": "BC",
            "run_started_at": last_updated,
            "last_updated": last_updated,
            "current_phase": "1",
            "completed_phases": [],
            "domains": [],
            "overrides": [],
        }
        bc_path.write_text(
            json.dumps(payload, indent=2) + "\n", encoding="utf-8"
        )

lic = state.get("linear_issue_count")
# Print LIC verbatim (string OR int OR empty). Caller decides how to apply.
print("" if lic is None else str(lic))
PY
}

# extract_field <case-json> <field>
# Pulls a single field from the case JSON via python3. Used for id /
# expected_mode / description after the iterator hands them out.
extract_field() {
  CASE_JSON="$1" FIELD="$2" python3 - <<'PY'
import json, os, sys
case = json.loads(os.environ["CASE_JSON"])
val = case.get(os.environ["FIELD"], "")
sys.stdout.write(str(val))
PY
}

# === Run cases =================================================================

section "1/3" "Fixture preflight"
total_cases="$(FIXTURE_JSON="$FIXTURE_JSON" python3 - <<'PY'
import json, os
print(len(json.load(open(os.environ["FIXTURE_JSON"]))))
PY
)"
if [ "$total_cases" -ge 14 ]; then
  pass "fixture JSON contains $total_cases cases (>= 14 per AC #2)"
else
  fail "fixture JSON contains $total_cases cases (< 14 per AC #2)"
fi

# AC #3 — each case has id / description / fixture_state / expected_mode.
schema_ok="$(FIXTURE_JSON="$FIXTURE_JSON" python3 - <<'PY'
import json, os, sys
required = ("id", "description", "fixture_state", "expected_mode")
cases = json.load(open(os.environ["FIXTURE_JSON"]))
missing = [c.get("id", "<no-id>") for c in cases
           if not all(k in c for k in required)]
if missing:
    print(",".join(missing))
    sys.exit(0)
print("OK")
PY
)"
if [ "$schema_ok" = "OK" ]; then
  pass "all cases have required fields (id, description, fixture_state, expected_mode)"
else
  fail "cases missing required fields: $schema_ok"
fi

section "2/3" "Mode-classifier sweep ($total_cases cases)"

# Iterate via python3 line-by-line so each case is a self-contained JSON object
# (avoids shell-side JSON parsing under bash 3.2). Process substitution (rather
# than pipe-to-while) keeps the loop body in the parent shell so PASS/FAIL/DRIFT
# counter increments propagate — a pipe would fork a subshell and lose them.
case_index=0
while IFS= read -r case_line; do
  case_index=$((case_index + 1))
  CASE_JSON="$case_line"
  case_id="$(extract_field "$CASE_JSON" id)"
  expected="$(extract_field "$CASE_JSON" expected_mode)"
  description="$(extract_field "$CASE_JSON" description)"

  if ! is_recognized_mode "$expected"; then
    drift "$case_id: expected_mode='$expected' → MODE-CLASSIFIER-DRIFT-FAIL (not in registry: $RECOGNIZED_MODES)"
    printf '%s\t%s\t%s\t%s\n' "$case_id" "$expected" "(skipped)" DRIFT >> "$RESULT_TSV"
    continue
  fi

  case_dir="$WORKROOT/$case_id"
  mkdir -p "$case_dir"
  lic="$(CASE_JSON="$CASE_JSON" stage_fixture "$case_dir")"

  # Invoke flow-detect-mode.sh against the staged dir. LINEAR_ISSUE_COUNT is
  # honoured by the script via env (validates as non-negative integer; malformed
  # values are warned to stderr + ignored, matching MC-15's contract).
  if [ -n "$lic" ]; then
    actual="$(LINEAR_ISSUE_COUNT="$lic" bash "$DETECT_MODE" "$case_dir" 2>/dev/null || true)"
  else
    actual="$(bash "$DETECT_MODE" "$case_dir" 2>/dev/null || true)"
  fi
  # Strip trailing whitespace / CR for cross-platform safety (LC_ALL=C already
  # rules out locale weirdness, but stdout from a child shell can carry \r on
  # some CI runners; cheap insurance).
  actual="$(printf '%s' "$actual" | tr -d '\r\n')"

  if [ "$actual" = "$expected" ]; then
    pass "$case_id: $expected"
    printf '%s\t%s\t%s\t%s\n' "$case_id" "$expected" "$actual" PASS >> "$RESULT_TSV"
  else
    fail "$case_id: expected='$expected' actual='$actual' — $description"
    printf '%s\t%s\t%s\t%s\n' "$case_id" "$expected" "$actual" FAIL >> "$RESULT_TSV"
  fi
done < <(FIXTURE_JSON="$FIXTURE_JSON" python3 - <<'PY'
import json, os
for case in json.load(open(os.environ["FIXTURE_JSON"])):
    # Compact one-line JSON per case — newline-delimited stream feeds the
    # bash `while read` loop above via process substitution. ensure_ascii
    # keeps it bash 3.2 + LC_ALL=C safe.
    print(json.dumps(case, ensure_ascii=True))
PY
)

section "3/3" "Skipped phases (not headlessly invocable)"
skip "Q12.5 preamble emission via flow-context-load.sh — covered by BC-6956's own helper tests"
skip "Q36.3 step 5 user-confirmation gate — AskUserQuestion is interactive-only"
skip ".flow/config.json stale-detection (path-A revalidation) — requires Linear MCP"
skip "Override hard-coded mode via /flow:<orch> --force-incremental-add — orchestrator flag, not classifier-side"

# === Generate report.md =======================================================
RESULT_TSV="$RESULT_TSV" REPORT_MD="$REPORT_MD" FIXTURE_JSON="$FIXTURE_JSON" \
  PASS="$PASS" FAIL="$FAIL" SKIP="$SKIP" DRIFT="$DRIFT" python3 - <<'PY'
import json, os, pathlib, datetime

tsv = pathlib.Path(os.environ["RESULT_TSV"]).read_text(encoding="utf-8").splitlines()
report = pathlib.Path(os.environ["REPORT_MD"])
cases = json.load(open(os.environ["FIXTURE_JSON"]))
desc_by_id = {c["id"]: c["description"] for c in cases}

rows = []
mode_matrix = {"greenfield": {"tp": 0, "fp": 0},
               "retrofit": {"tp": 0, "fp": 0},
               "incremental-add": {"tp": 0, "fp": 0},
               "resume": {"tp": 0, "fp": 0}}
for line in tsv:
    if not line.strip():
        continue
    cid, expected, actual, status = line.split("\t")
    rows.append((cid, expected, actual, status))
    if status == "PASS":
        mode_matrix.setdefault(expected, {"tp": 0, "fp": 0})["tp"] += 1
    elif status == "FAIL":
        mode_matrix.setdefault(actual, {"tp": 0, "fp": 0})["fp"] += 1

now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
lines = [
    "# BC-7061 mode-classifier eval report",
    "",
    f"Generated: `{now}`",
    "",
    "Per-case classifier output vs expected_mode, plus per-mode TP/FP matrix.",
    "Companion to `fixtures/mode-classifier-eval.json` (AC #6).",
    "",
    "## Summary",
    "",
    f"- PASS: {os.environ['PASS']}",
    f"- FAIL: {os.environ['FAIL']}",
    f"- DRIFT: {os.environ['DRIFT']} (expected_mode outside recognized registry)",
    f"- SKIP: {os.environ['SKIP']} (non-headless phases)",
    "",
    "## Per-mode matrix",
    "",
    "| Mode | TP (pass) | FP (other mode misclassified as this) |",
    "|---|---|---|",
]
for mode in ("greenfield", "retrofit", "incremental-add", "resume"):
    m = mode_matrix.get(mode, {"tp": 0, "fp": 0})
    lines.append(f"| `{mode}` | {m['tp']} | {m['fp']} |")

lines += [
    "",
    "## Per-case results",
    "",
    "| ID | Expected | Actual | Status | Description |",
    "|---|---|---|---|---|",
]
for cid, expected, actual, status in rows:
    desc = desc_by_id.get(cid, "").replace("|", "\\|")
    lines.append(f"| {cid} | `{expected}` | `{actual}` | {status} | {desc} |")

report.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

# === Summary ===================================================================
printf '\n%s\n' '------------------------------------------'
printf 'BC-7061 mode-classifier eval: %d pass / %d fail / %d drift / %d skip\n' \
       "$PASS" "$FAIL" "$DRIFT" "$SKIP"
printf 'Report: %s\n' "$REPORT_MD"
printf '%s\n' '------------------------------------------'

if [ "$FAIL" -gt 0 ] || [ "$DRIFT" -gt 0 ]; then
  printf '\nHarness failed.\n'
  exit 1
fi
exit 0
