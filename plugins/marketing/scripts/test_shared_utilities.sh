#!/usr/bin/env bash
# Regression harness for plugins/marketing/scripts/_shared/ modules (BC-8728).
# Tests canonicals_reader, slug_parts, and manifest_loader via inline Python
# invocations against tempdir fixtures. Mirrors test_portfolio_snapshot.sh
# substring-assertion + RESULT-line discipline.
#
# Usage:
#   bash plugins/marketing/scripts/test_shared_utilities.sh

set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

script_dir="$(cd "$(dirname "$0")" && pwd)"

tmproot="$(mktemp -d -t test-shared-utilities.XXXXXX)" || {
  echo "FATAL: mktemp -d failed" >&2
  exit 2
}
trap 'rm -rf "$tmproot"' EXIT

pass=0
fail=0
LAST_OUTPUT=""
LAST_RC=0

assert_exit_and_substring() {
  local label="$1"
  local expected_rc="$2"
  local substring="$3"
  local actual_rc="$LAST_RC"
  local output="$LAST_OUTPUT"

  if [ "$expected_rc" -ne "$actual_rc" ]; then
    echo "  FAIL  $label — exit expected=$expected_rc actual=$actual_rc"
    echo "    output: $output"
    fail=$((fail + 1))
    return
  fi
  if ! printf '%s' "$output" | grep -qE -- "$substring"; then
    echo "  FAIL  $label — substring not found"
    echo "    expected regex: $substring"
    echo "    output: $output"
    fail=$((fail + 1))
    return
  fi
  echo "  PASS  $label (exit=$actual_rc, substring matched)"
  pass=$((pass + 1))
}

invoke_python() {
  LAST_OUTPUT="$(cd "$script_dir" && python3 -c "$1" 2>&1)"
  LAST_RC=$?
}

# ── Fixture builders ──────────────────────────────────────────────────────

mk_canonicals_dir() {
  local name="$1"
  local d="$tmproot/$name/canonicals"
  mkdir -p "$d"
  printf '%s' "$d"
}

mk_campaigns_dir() {
  local name="$1"
  local d="$tmproot/$name/campaigns"
  mkdir -p "$d"
  printf '%s' "$d"
}

# ══════════════════════════════════════════════════════════════════════════
# canonicals_reader tests
# ══════════════════════════════════════════════════════════════════════════

echo "── canonicals_reader ──"

# CR1: load_canonicals_verticals — valid manifest
cdir=$(mk_canonicals_dir "CR1")
cat > "$cdir/_manifest.yaml" <<'YAML'
schema_version: 2
verticals:
  - hotels-resorts
  - wineries-breweries
YAML

invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import load_canonicals_verticals
from pathlib import Path
v = load_canonicals_verticals(Path('$cdir'))
print(repr(v))
"
assert_exit_and_substring "CR1: load_canonicals_verticals" 0 "hotels-resorts.*wineries-breweries"

# CR2: load_canonicals_verticals — missing manifest
cdir2=$(mk_canonicals_dir "CR2")
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import load_canonicals_verticals
from pathlib import Path
v = load_canonicals_verticals(Path('$cdir2'))
print(repr(v))
"
assert_exit_and_substring "CR2: missing manifest returns empty" 0 "\\[\\]"

# CR3: lookup_posture — valid offer
cdir3=$(mk_canonicals_dir "CR3")
cat > "$cdir3/_manifest.yaml" <<'YAML'
schema_version: 2
verticals:
  - hotels-resorts
YAML
cat > "$cdir3/hotels-resorts.yaml" <<'YAML'
slug: hotels-resorts
display: "Hotels & Resorts"
personas:
  - slug: director-of-resort-experience
    display: "Director of Resort Experience"
    titles:
      - "Director of Resort Experience"
offers:
  - slug: holiday-anchor-audit
    display: "Resort Holiday Anchor Audit"
    status: draft
    posture: free-asset
    target_personas:
      - director-of-resort-experience
YAML

invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import lookup_posture
from pathlib import Path
p = lookup_posture(Path('$cdir3'), 'hotels-resorts', 'holiday-anchor-audit')
print(p)
"
assert_exit_and_substring "CR3: lookup_posture valid" 0 "free-asset"

# CR4: lookup_posture — missing offer
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import lookup_posture
from pathlib import Path
p = lookup_posture(Path('$cdir3'), 'hotels-resorts', 'nonexistent-offer')
print(repr(p))
"
assert_exit_and_substring "CR4: lookup_posture missing offer" 0 "None"

# CR5: lookup_posture — missing vertical
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import lookup_posture
from pathlib import Path
p = lookup_posture(Path('$cdir3'), 'nonexistent-vertical', 'holiday-anchor-audit')
print(repr(p))
"
assert_exit_and_substring "CR5: lookup_posture missing vertical" 0 "None"

# CR6: lookup_persona_titles — valid
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import lookup_persona_titles
from pathlib import Path
t = lookup_persona_titles(Path('$cdir3'), 'hotels-resorts', 'director-of-resort-experience')
print(repr(t))
"
assert_exit_and_substring "CR6: lookup_persona_titles valid" 0 "Director of Resort Experience"

# CR7: validate_canonical_ref — valid
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import validate_canonical_ref
from pathlib import Path
ok, msg = validate_canonical_ref(Path('$cdir3'), 'hotels-resorts', 'holiday-anchor-audit')
print(ok, msg)
"
assert_exit_and_substring "CR7: validate_canonical_ref valid" 0 "True"

# CR8: validate_canonical_ref — invalid offer
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import validate_canonical_ref
from pathlib import Path
ok, msg = validate_canonical_ref(Path('$cdir3'), 'hotels-resorts', 'bogus-offer')
print(ok, msg)
"
assert_exit_and_substring "CR8: validate_canonical_ref invalid offer" 0 "False"

# CR9: find_offer_vertical — auto-detect
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import find_offer_vertical
from pathlib import Path
v = find_offer_vertical(Path('$cdir3'), 'holiday-anchor-audit')
print(v)
"
assert_exit_and_substring "CR9: find_offer_vertical auto-detect" 0 "hotels-resorts"

# CR10: find_offer_vertical — unknown offer
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.canonicals_reader import find_offer_vertical
from pathlib import Path
v = find_offer_vertical(Path('$cdir3'), 'totally-fake')
print(repr(v))
"
assert_exit_and_substring "CR10: find_offer_vertical unknown" 0 "None"

# ══════════════════════════════════════════════════════════════════════════
# slug_parts tests
# ══════════════════════════════════════════════════════════════════════════

echo "── slug_parts ──"

# SP1: slug_to_launch_month — valid
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import slug_to_launch_month
d = slug_to_launch_month('hotels-resorts-director-holiday-anchor-audit-fy26-m02')
print(d.strftime('%Y-%m-%d'))
"
assert_exit_and_substring "SP1: slug_to_launch_month valid" 0 "2026-02-01"

# SP2: slug_to_launch_month — with version
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import slug_to_launch_month
d = slug_to_launch_month('some-slug-fy26-m01-v3')
print(d.strftime('%Y-%m-%d'))
"
assert_exit_and_substring "SP2: slug_to_launch_month with version" 0 "2026-01-01"

# SP3: slug_to_launch_month — invalid (no fy/m)
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import slug_to_launch_month
d = slug_to_launch_month('no-date-here')
print(repr(d))
"
assert_exit_and_substring "SP3: slug_to_launch_month invalid" 0 "None"

# SP4: slug_to_launch_month — invalid month (m13)
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import slug_to_launch_month
d = slug_to_launch_month('some-slug-fy26-m13')
print(repr(d))
"
assert_exit_and_substring "SP4: slug_to_launch_month m13 invalid" 0 "None"

# SP5: slug_to_launch_month — leading zero m01
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import slug_to_launch_month
d = slug_to_launch_month('some-slug-fy26-m01')
print(d.strftime('%Y-%m-%d'))
"
assert_exit_and_substring "SP5: slug_to_launch_month m01 leading zero" 0 "2026-01-01"

# SP6: slug_version — with version
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import slug_version
v = slug_version('slug-fy26-m02-v3')
print(v)
"
assert_exit_and_substring "SP6: slug_version v3" 0 "^3$"

# SP7: slug_version — no version = 1
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import slug_version
v = slug_version('slug-fy26-m02')
print(v)
"
assert_exit_and_substring "SP7: slug_version absent = 1" 0 "^1$"

# SP8: format_window_label
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.slug_parts import format_window_label
print(format_window_label(2026, 4))
"
assert_exit_and_substring "SP8: format_window_label April 2026" 0 "April 2026"

# ══════════════════════════════════════════════════════════════════════════
# manifest_loader tests
# ══════════════════════════════════════════════════════════════════════════

echo "── manifest_loader ──"

# ML1: load_manifests — in-range window
campdir=$(mk_campaigns_dir "ML1")
mkdir -p "$campdir/labs/test-slug-fy26-m04"
cat > "$campdir/labs/test-slug-fy26-m04/manifest.json" <<'JSON'
{"slug": "test-slug-fy26-m04", "entity": "labs", "vertical": "hotels-resorts", "offer": "holiday-anchor-audit"}
JSON

invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import load_manifests, filter_in_window
from pathlib import Path
from datetime import datetime, timezone
ms = load_manifests(Path('$campdir'))
print('loaded', len(ms))
start = datetime(2026, 4, 1, tzinfo=timezone.utc)
end = datetime(2026, 4, 30, tzinfo=timezone.utc)
filtered = filter_in_window(ms, start, end)
print('filtered', len(filtered))
"
assert_exit_and_substring "ML1: window match" 0 "filtered 1"

# ML2: window miss
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import load_manifests, filter_in_window
from pathlib import Path
from datetime import datetime, timezone
ms = load_manifests(Path('$campdir'))
start = datetime(2026, 5, 1, tzinfo=timezone.utc)
end = datetime(2026, 5, 31, tzinfo=timezone.utc)
filtered = filter_in_window(ms, start, end)
print('filtered', len(filtered))
"
assert_exit_and_substring "ML2: window miss" 0 "filtered 0"

# ML3: multiple matches
campdir3=$(mk_campaigns_dir "ML3")
mkdir -p "$campdir3/labs/a-fy26-m04" "$campdir3/labs/b-fy26-m04" "$campdir3/labs/c-fy26-m05"
echo '{"slug":"a-fy26-m04","entity":"labs","offer":"a"}' > "$campdir3/labs/a-fy26-m04/manifest.json"
echo '{"slug":"b-fy26-m04","entity":"labs","offer":"a"}' > "$campdir3/labs/b-fy26-m04/manifest.json"
echo '{"slug":"c-fy26-m05","entity":"labs","offer":"b"}' > "$campdir3/labs/c-fy26-m05/manifest.json"

invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import load_manifests, filter_in_window
from pathlib import Path
from datetime import datetime, timezone
ms = load_manifests(Path('$campdir3'))
start = datetime(2026, 4, 1, tzinfo=timezone.utc)
end = datetime(2026, 4, 30, tzinfo=timezone.utc)
filtered = filter_in_window(ms, start, end)
print('filtered', len(filtered))
"
assert_exit_and_substring "ML3: multiple matches in window" 0 "filtered 2"

# ML4: glob_manifests_by_offer
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import glob_manifests_by_offer
from pathlib import Path
ms = glob_manifests_by_offer(Path('$campdir3'), 'a')
print('matched', len(ms))
"
assert_exit_and_substring "ML4: glob_manifests_by_offer" 0 "matched 2"

# ML5: read_sibling_artifacts — missing siblings (soft-fail)
invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import read_sibling_artifacts
from pathlib import Path
arts = read_sibling_artifacts(Path('$campdir3/labs/a-fy26-m04/manifest.json'))
print('learnings', repr(arts['learnings']))
print('mmf', repr(arts['mmf_matrix']))
print('disc', repr(arts['discoveries']))
"
assert_exit_and_substring "ML5: missing siblings soft-fail" 0 "learnings None"

# ML6: read_sibling_artifacts — with learnings.md
mkdir -p "$campdir3/labs"
cat > "$campdir3/labs/learnings.md" <<'MD'
## Summary stats
- Total debriefs: 2
MD

invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import read_sibling_artifacts
from pathlib import Path
arts = read_sibling_artifacts(Path('$campdir3/labs/a-fy26-m04/manifest.json'))
print('has_learnings', arts['learnings'] is not None)
"
assert_exit_and_substring "ML6: learnings.md found" 0 "has_learnings True"

# ML7: bad JSON manifest — soft-fail
campdir7=$(mk_campaigns_dir "ML7")
mkdir -p "$campdir7/labs/bad-json-fy26-m04"
echo "NOT JSON" > "$campdir7/labs/bad-json-fy26-m04/manifest.json"

invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import load_manifests
from pathlib import Path
ms = load_manifests(Path('$campdir7'))
print('loaded', len(ms))
"
assert_exit_and_substring "ML7: bad JSON manifest soft-fail" 0 "loaded 0"

# ML8: glob_campaign_files — skips _reviews
campdir8=$(mk_campaigns_dir "ML8")
mkdir -p "$campdir8/_reviews/something" "$campdir8/labs/real-fy26-m04"
echo '{"slug":"real-fy26-m04"}' > "$campdir8/labs/real-fy26-m04/manifest.json"
echo '{"slug":"review-artifact"}' > "$campdir8/_reviews/something/manifest.json"

invoke_python "
import sys; sys.path.insert(0, '.')
from _shared.manifest_loader import glob_campaign_files
from pathlib import Path
paths = glob_campaign_files(Path('$campdir8'), 'manifest.json')
print('count', len(paths))
for p in paths:
    print(p.name)
"
assert_exit_and_substring "ML8: glob_campaign_files skips _reviews" 0 "count 1"

# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "shared utilities harness: $((pass))/$((pass + fail)) passing"
echo "RESULT pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  echo "FAIL — $fail scenario(s) failed"
  exit 1
fi
echo "PASS — all scenarios green"
