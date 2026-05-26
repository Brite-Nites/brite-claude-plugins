#!/usr/bin/env bash
# BC-10729 / Q29 amendment 2 v-slice harness for the
# `cross-domain-deps-bidirectional` cross-cutting consistency gate.
#
# Exercises the doc-side parse contract + the bidirectional set-comparison
# logic against three synthetic fixtures under
# `tests/fixtures/synthetic-cross-domain-deps/`:
#
#   pass-bidirectional   — doc bullets 1:1 mirror Linear blockedBy (PASS)
#   fail-doc-orphan      — doc references blockedBy with no matching
#                          Linear relation (FAIL: doc → Linear half)
#   fail-linear-orphan   — Linear has blockedBy between FDA parents with
#                          no matching doc bullet (FAIL: Linear → doc half)
#
# Filesystem-only. The live /flow:audit Phase C check evaluates the same
# predicate against real Linear state via MCP. Per the BC-7059 vslice-greenfield
# precedent, Phase C Linear MCP gates are SKIP in CI and the full verdict is
# exercised in Brand Hub dogfood.
#
# Target: bash 3.2 (macOS default). Stdlib python3 only.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_ROOT="$SCRIPT_DIR/fixtures/synthetic-cross-domain-deps"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }

PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# count_doc_pairs <fixture-dir> — emits the count of doc-side cross-domain
# bullets extracted by the parser. Independent of the verdict logic so a
# parser-only regression surfaces directly (not just through verdict-mapping).
count_doc_pairs() {
  local fixture="$1"
  python3 - "$fixture" <<'PY'
import re
import sys
from pathlib import Path

fixture = Path(sys.argv[1])
section_re = re.compile(
    r'(?ms)^##\s+Cross-domain\s+dependencies\s*\n(.*?)(?=^##\s|\Z)'
)
bullet_re = re.compile(
    r'^\s*[-*]\s+([a-z0-9][a-z0-9\-]*-\d+)\s+(blockedBy|gates)\s+([a-z0-9][a-z0-9\-]*-\d+)\b'
)
count = 0
flows_root = fixture / "docs" / "product" / "flows"
if flows_root.exists():
    for doc_path in flows_root.rglob("*.md"):
        match = section_re.search(doc_path.read_text())
        if not match:
            continue
        for line in match.group(1).splitlines():
            if bullet_re.match(line):
                count += 1
print(count)
PY
}

# evaluate_fixture <fixture-dir> — returns PASS|FAIL_DOC_ORPHAN|FAIL_LINEAR_ORPHAN|FAIL_BOTH
# Mirrors the cross-domain-deps-bidirectional predicate documented in Q29
# amendment 2. Bash + python3 only; no Linear MCP.
evaluate_fixture() {
  local fixture="$1"
  python3 - "$fixture" <<'PY'
import json
import re
import sys
from pathlib import Path

fixture = Path(sys.argv[1])
linear_mock_path = fixture / ".flow" / "linear-state-mock.json"

# --- Load Linear state mock --------------------------------------------------
if not linear_mock_path.exists():
    print("FAIL_MISSING_LINEAR_MOCK")
    sys.exit(0)
linear = json.loads(linear_mock_path.read_text())
parents = linear.get("parents", {})

# Cross-domain blockedBy set as (this_fid, blocker_fid).
# `parents` is the single source of truth — look up flow_id + domain directly.
linear_pairs = set()
for bc, p in parents.items():
    this_fid = p["flow_id"]
    this_domain = p["domain"]
    for blocker_bc in p.get("blockedBy", []):
        blocker = parents.get(blocker_bc)
        if blocker is None:
            # Linear blockedBy points at a non-FDA-parent issue; excluded.
            continue
        if blocker["domain"] == this_domain:
            # Same-domain sibling: tracked via related_flows front-matter, excluded.
            continue
        linear_pairs.add((this_fid, blocker["flow_id"]))

# --- Parse doc-side `## Cross-domain dependencies` section -------------------
# Regex anchors: literal H2 header + bullet lines of shape
# `- <this-flow-id> blockedBy <other-flow-id> — <reason>` or
# `- <this-flow-id> gates <other-flow-id> — <reason>`.
section_re = re.compile(
    r'(?ms)^##\s+Cross-domain\s+dependencies\s*\n(.*?)(?=^##\s|\Z)'
)
bullet_re = re.compile(
    r'^\s*[-*]\s+([a-z0-9][a-z0-9\-]*-\d+)\s+(blockedBy|gates)\s+([a-z0-9][a-z0-9\-]*-\d+)\b'
)

doc_pairs = set()
flows_root = fixture / "docs" / "product" / "flows"
if flows_root.exists():
    for doc_path in flows_root.rglob("*.md"):
        text = doc_path.read_text()
        match = section_re.search(text)
        if not match:
            continue
        for line in match.group(1).splitlines():
            m = bullet_re.match(line)
            if not m:
                continue
            this_fid, verb, other_fid = m.group(1), m.group(2), m.group(3)
            if verb == "blockedBy":
                doc_pairs.add((this_fid, other_fid))
            else:
                # gates is the inverse view: this_fid blocks other_fid
                doc_pairs.add((other_fid, this_fid))

# --- Bidirectional set comparison --------------------------------------------
doc_orphans = doc_pairs - linear_pairs       # doc references blockedBy with no Linear relation
linear_orphans = linear_pairs - doc_pairs    # Linear has blockedBy with no doc mention

if not doc_orphans and not linear_orphans:
    print("PASS")
elif doc_orphans and not linear_orphans:
    print("FAIL_DOC_ORPHAN")
elif linear_orphans and not doc_orphans:
    print("FAIL_LINEAR_ORPHAN")
else:
    print("FAIL_BOTH")
PY
}

# === Tests ====================================================================

section "1/6" "Fixture shape preflight"
for fixture in pass-bidirectional fail-doc-orphan fail-linear-orphan fail-both; do
  if [ -d "$FIXTURE_ROOT/$fixture" ]; then
    pass "fixture present: $fixture"
  else
    fail "fixture missing: $fixture"
  fi
  if [ -f "$FIXTURE_ROOT/$fixture/.flow/linear-state-mock.json" ]; then
    pass "Linear state mock present: $fixture/.flow/linear-state-mock.json"
  else
    fail "Linear state mock missing: $fixture/.flow/linear-state-mock.json"
  fi
done

# Direct parser-extraction assertions: catch parser-only regressions that
# would otherwise only surface indirectly through verdict-mapping (the case
# where a parser break flips a FAIL_DOC_ORPHAN to PASS-by-emptiness is real
# enough; this gives the harness a direct signal of "did the parser find
# what we expect?" independent of bidirectional set-comparison).
section "2/6" "Parser-extraction assertions (doc-side bullet count per fixture)"
expected_pass_count=2     # pass-bidirectional has 2 blockedBy bullets
expected_doc_orphan_count=1   # fail-doc-orphan has 1 blockedBy bullet
expected_linear_orphan_count=0 # fail-linear-orphan has NO Cross-domain section
expected_both_count=1     # fail-both has 1 orphan bullet + 1 missing linear pair

actual_pass="$(count_doc_pairs "$FIXTURE_ROOT/pass-bidirectional")"
actual_doc_orphan="$(count_doc_pairs "$FIXTURE_ROOT/fail-doc-orphan")"
actual_linear_orphan="$(count_doc_pairs "$FIXTURE_ROOT/fail-linear-orphan")"
actual_both="$(count_doc_pairs "$FIXTURE_ROOT/fail-both")"

if [ "$actual_pass" = "$expected_pass_count" ]; then
  pass "parser extracted $actual_pass bullets from pass-bidirectional (expected $expected_pass_count)"
else
  fail "parser extracted $actual_pass bullets from pass-bidirectional (expected $expected_pass_count) — parser regression?"
fi
if [ "$actual_doc_orphan" = "$expected_doc_orphan_count" ]; then
  pass "parser extracted $actual_doc_orphan bullets from fail-doc-orphan (expected $expected_doc_orphan_count)"
else
  fail "parser extracted $actual_doc_orphan bullets from fail-doc-orphan (expected $expected_doc_orphan_count) — parser regression?"
fi
if [ "$actual_linear_orphan" = "$expected_linear_orphan_count" ]; then
  pass "parser extracted $actual_linear_orphan bullets from fail-linear-orphan (expected $expected_linear_orphan_count — no section in doc)"
else
  fail "parser extracted $actual_linear_orphan bullets from fail-linear-orphan (expected $expected_linear_orphan_count)"
fi
if [ "$actual_both" = "$expected_both_count" ]; then
  pass "parser extracted $actual_both bullets from fail-both (expected $expected_both_count)"
else
  fail "parser extracted $actual_both bullets from fail-both (expected $expected_both_count)"
fi

section "3/6" "Fixture pass-bidirectional → expect PASS"
result_pass="$(evaluate_fixture "$FIXTURE_ROOT/pass-bidirectional")"
if [ "$result_pass" = "PASS" ]; then
  pass "pass-bidirectional → PASS (doc bullets 1:1 mirror Linear blockedBy)"
else
  fail "pass-bidirectional → expected PASS, got $result_pass"
fi

section "4/6" "Fixture fail-doc-orphan → expect FAIL_DOC_ORPHAN"
result_doc="$(evaluate_fixture "$FIXTURE_ROOT/fail-doc-orphan")"
if [ "$result_doc" = "FAIL_DOC_ORPHAN" ]; then
  pass "fail-doc-orphan → FAIL_DOC_ORPHAN (doc bullet has no matching Linear relation)"
else
  fail "fail-doc-orphan → expected FAIL_DOC_ORPHAN, got $result_doc"
fi

section "5/6" "Fixture fail-linear-orphan → expect FAIL_LINEAR_ORPHAN"
result_linear="$(evaluate_fixture "$FIXTURE_ROOT/fail-linear-orphan")"
if [ "$result_linear" = "FAIL_LINEAR_ORPHAN" ]; then
  pass "fail-linear-orphan → FAIL_LINEAR_ORPHAN (Linear blockedBy has no matching doc bullet)"
else
  fail "fail-linear-orphan → expected FAIL_LINEAR_ORPHAN, got $result_linear"
fi

section "6/6" "Fixture fail-both → expect FAIL_BOTH"
result_both="$(evaluate_fixture "$FIXTURE_ROOT/fail-both")"
if [ "$result_both" = "FAIL_BOTH" ]; then
  pass "fail-both → FAIL_BOTH (doc orphan + Linear orphan simultaneously)"
else
  fail "fail-both → expected FAIL_BOTH, got $result_both"
fi

# === Summary ==================================================================
printf '\n%s\n' '------------------------------------------'
printf 'BC-10729 cross-domain-deps v-slice: %d pass / %d fail (%d hard assertions)\n' \
       "$PASS" "$FAIL" "$((PASS + FAIL))"
printf '%s\n' '------------------------------------------'

if [ "$FAIL" -gt 0 ]; then
  printf '\nHarness failed.\n'
  exit 1
fi
exit 0
