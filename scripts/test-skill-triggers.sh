#!/usr/bin/env bash
set -euo pipefail

# ── Test Skill Trigger Matching ───────────────────────────────────────
# Loads trigger-registry.json and runs test cases through a keyword
# matching engine with negative keywords and precedence resolution.
# ──────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass_count=0
fail_count=0
total=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass_count=$((pass_count + 1)); total=$((total + 1)); }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail_count=$((fail_count + 1)); total=$((total + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# ── Prereqs ───────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found." >&2
  exit 2
fi

# ── Discover trigger registries across all plugins ────────────────────
registries=()
for reg in "$REPO_ROOT"/plugins/*/skills/_shared/trigger-registry.json; do
  [ -f "$reg" ] && registries+=("$reg")
done

if [ ${#registries[@]} -eq 0 ]; then
  echo "ERROR: No trigger-registry.json found in any plugin" >&2
  exit 2
fi

# ── Test each registry ────────────────────────────────────────────────
for REGISTRY in "${registries[@]}"; do
  plugin_name="$(basename "$(dirname "$(dirname "$(dirname "$REGISTRY")")")")"
  section "Skill Trigger Matching ($plugin_name)"

results=$(TRIGGER_REGISTRY="$REGISTRY" python3 << 'PYEOF'
import json, os

registry_path = os.environ["TRIGGER_REGISTRY"]

with open(registry_path) as f:
    registry = json.load(f)

skills = registry["skills"]
test_cases = registry["test_cases"]

def match_skills(phrase):
    """Match a phrase against all skills using keyword substring matching."""
    phrase_lower = phrase.lower()
    matched = []

    for skill in skills:
        # Check if any keyword matches (case-insensitive substring)
        keyword_match = any(kw.lower() in phrase_lower for kw in skill["keywords"])
        if not keyword_match:
            continue

        # Check negative keywords — exclude if any match
        neg_match = any(nk.lower() in phrase_lower for nk in skill.get("negative_keywords", []))
        if neg_match:
            continue

        matched.append(skill["name"])

    # Apply precedence: if A beats B and both matched, remove B
    to_remove = set()
    for skill in skills:
        if skill["name"] in matched:
            for loser in skill.get("beats", []):
                if loser in matched:
                    to_remove.add(loser)

    return [s for s in matched if s not in to_remove]

for tc in test_cases:
    phrase = tc["phrase"]
    expected = set(tc["expected"])
    not_expected = set(tc.get("not_expected", []))
    desc = tc["description"]

    result = match_skills(phrase)
    result_set = set(result)

    # Check: all expected skills are present
    missing = expected - result_set
    # Check: no not_expected skills are present
    unwanted = not_expected & result_set

    if not missing and not unwanted:
        print(f"PASS:{desc}")
    else:
        details = []
        if missing:
            details.append(f"missing={sorted(missing)}")
        if unwanted:
            details.append(f"unwanted={sorted(unwanted)}")
        details.append(f"got={sorted(result)}")
        print(f"FAIL:{desc}|{', '.join(details)}")
PYEOF
)

while IFS= read -r line; do
  if [[ "$line" == PASS:* ]]; then
    pass "${line#PASS:}"
  elif [[ "$line" == FAIL:* ]]; then
    msg="${line#FAIL:}"
    desc="${msg%%|*}"
    detail="${msg#*|}"
    fail "$desc ($detail)"
  elif [[ "$line" == ERROR:* ]]; then
    echo "ERROR: ${line#ERROR:}" >&2
    exit 2
  fi
done <<< "$results"

done  # end per-plugin registry loop

if [ "$total" -eq 0 ]; then
  echo "ERROR: no test cases executed — registries may be empty or Python output malformed" >&2
  exit 2
fi

# ══════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════
section "Summary"

echo "  Total: $total  Passed: $pass_count  Failed: $fail_count"
echo ""

if [ "$fail_count" -gt 0 ]; then
  printf "  \033[31m%d test(s) failed\033[0m\n" "$fail_count"
  echo ""
  exit 1
else
  printf "  \033[32mAll tests passed\033[0m\n"
  echo ""
  exit 0
fi
