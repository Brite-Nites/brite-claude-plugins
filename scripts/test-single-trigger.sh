#!/usr/bin/env bash
set -euo pipefail

# ── Test Single Trigger — Test trigger matching for one skill ────────
# Usage:
#   scripts/test-single-trigger.sh <skill-name> <phrase>
#   scripts/test-single-trigger.sh <skill-name>           # runs registry test cases only
#
# Tests whether a given phrase matches a specific skill in the trigger
# registry, and also runs any registry test cases involving that skill.
# ─────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Discover all trigger registries across plugins, then pick the one containing the target skill.
# Falls back to first found if skill isn't in any registry. Override with TRIGGER_REGISTRY_PATH.
_all_registries=()
for _reg in "$REPO_ROOT"/plugins/*/skills/_shared/trigger-registry.json; do
  [ -f "$_reg" ] && _all_registries+=("$_reg")
done
REGISTRY=""
if [ -z "${TRIGGER_REGISTRY_PATH:-}" ]; then
  # Search all registries for the target skill (first arg)
  _target="${1:-}"
  for _reg in "${_all_registries[@]}"; do
    if [ -n "$_target" ] && python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    r = json.load(f)
sys.exit(0 if any(s['name'] == sys.argv[2] for s in r['skills']) else 1)
" "$_reg" "$_target" 2>/dev/null; then
      REGISTRY="$_reg"
      break
    fi
  done
  # Fall back to first found if skill not in any registry
  if [ -z "$REGISTRY" ] && [ ${#_all_registries[@]} -gt 0 ]; then
    REGISTRY="${_all_registries[0]}"
  fi
else
  REGISTRY="$TRIGGER_REGISTRY_PATH"
fi

pass_count=0
fail_count=0
total=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass_count=$((pass_count + 1)); total=$((total + 1)); }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail_count=$((fail_count + 1)); total=$((total + 1)); }
info() { printf "  \033[34mINFO\033[0m  %s\n" "$1"; }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# ── Usage ────────────────────────────────────────────────────────────
if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <skill-name> [phrase]"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") brainstorming \"design a feature\"    # test ad-hoc phrase"
  echo "  $(basename "$0") brainstorming                       # run registry tests only"
  exit 1
fi

SKILL_NAME="$1"
PHRASE="${2:-}"

# ── Prereqs ──────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found." >&2
  exit 2
fi

if [ -z "$REGISTRY" ] || [ ! -f "$REGISTRY" ]; then
  echo "ERROR: No trigger-registry.json found in any plugin" >&2
  echo "Set TRIGGER_REGISTRY_PATH to specify a registry file." >&2
  exit 2
fi

# ── Run all checks in a single python3 invocation ────────────────────
results=$(TRIGGER_REGISTRY="$REGISTRY" SKILL_NAME="$SKILL_NAME" PHRASE="$PHRASE" python3 << 'PYEOF'
import json, os, sys

with open(os.environ["TRIGGER_REGISTRY"]) as f:
    registry = json.load(f)

target = os.environ["SKILL_NAME"]
phrase = os.environ.get("PHRASE", "")
skills = registry["skills"]
test_cases = registry["test_cases"]

# ── Section 1: Skill existence check ─────────────────────────────
skill_data = next((s for s in skills if s["name"] == target), None)
if not skill_data:
    names = sorted(s["name"] for s in skills)
    print(f"NOT_FOUND:Available: {', '.join(names)}")
    sys.exit(0)

kw = len(skill_data["keywords"])
neg = len(skill_data.get("negative_keywords", []))
beats = len(skill_data.get("beats", []))
print(f"FOUND:{kw} keywords, {neg} negative, {beats} beats")

# ── Matching helpers ─────────────────────────────────────────────
def match_skills_detailed(phrase_lower):
    """Match with per-keyword detail tracking for ad-hoc diagnostics."""
    matched = []
    match_details = {}
    for skill in skills:
        keyword_match = None
        for k in skill["keywords"]:
            if k.lower() in phrase_lower:
                keyword_match = k
                break
        if not keyword_match:
            continue
        neg_match = None
        for nk in skill.get("negative_keywords", []):
            if nk.lower() in phrase_lower:
                neg_match = nk
                break
        if neg_match:
            match_details[skill["name"]] = f"keyword '{keyword_match}' matched but blocked by negative '{neg_match}'"
            continue
        matched.append(skill["name"])
        match_details[skill["name"]] = f"keyword '{keyword_match}' matched"
    to_remove = set()
    for skill in skills:
        if skill["name"] in matched:
            for loser in skill.get("beats", []):
                if loser in matched:
                    to_remove.add(loser)
                    match_details[loser] = match_details.get(loser, '') + f" (beaten by {skill['name']})"
    final = [s for s in matched if s not in to_remove]
    return final, match_details

def match_skills_simple(phrase_str):
    """Match returning only the final list — for batch test cases."""
    phrase_lower = phrase_str.lower()
    matched = []
    for skill in skills:
        if not any(k.lower() in phrase_lower for k in skill["keywords"]):
            continue
        if any(nk.lower() in phrase_lower for nk in skill.get("negative_keywords", [])):
            continue
        matched.append(skill["name"])
    to_remove = set()
    for skill in skills:
        if skill["name"] in matched:
            for loser in skill.get("beats", []):
                if loser in matched:
                    to_remove.add(loser)
    return [s for s in matched if s not in to_remove]

# ── Section 2: Ad-hoc phrase test (if phrase provided) ───────────
if phrase:
    print("__SECTION:PHRASE__")
    phrase_lower = phrase.lower()
    final, details = match_skills_detailed(phrase_lower)
    if target in final:
        print(f"MATCH:'{target}' matches — {details.get(target, 'matched')}")
    elif target in details:
        print(f"BLOCKED:{details[target]}")
    else:
        print(f"NO_MATCH:No keywords matched. Keywords: {skill_data['keywords']}")
    others = [s for s in final if s != target]
    for o in others:
        print(f"ALSO:{o} — {details.get(o, 'matched')}")

# ── Section 3: Registry test cases ───────────────────────────────
print("__SECTION:REGISTRY__")
relevant = [tc for tc in test_cases
            if target in tc.get("expected", []) or target in tc.get("not_expected", [])]

if not relevant:
    print("NONE:No test cases reference this skill")
else:
    for tc in relevant:
        result = match_skills_simple(tc["phrase"])
        result_set = set(result)
        target_expected = target in tc.get("expected", [])
        target_not_expected = target in tc.get("not_expected", [])
        target_in_result = target in result_set
        ok = True
        detail = ""
        if target_expected and not target_in_result:
            ok = False
            detail = f"expected '{target}' but not matched"
        elif target_not_expected and target_in_result:
            ok = False
            detail = f"'{target}' matched but should not have"
        if ok:
            print(f"PASS:{tc['description']}")
        else:
            print(f"FAIL:{tc['description']}|{detail}, got={sorted(result)}")
PYEOF
)

# ── Parse sectioned output ───────────────────────────────────────────
current_section=""

while IFS= read -r line; do
  case "$line" in
    NOT_FOUND:*)
      echo "ERROR: Skill '$SKILL_NAME' not found in trigger registry." >&2
      echo "${line#NOT_FOUND:}" >&2
      exit 1
      ;;
    FOUND:*)
      echo "Skill: $SKILL_NAME (${line#FOUND:})"
      ;;
    "__SECTION:PHRASE__")
      current_section="phrase"
      section "Ad-hoc Phrase Test"
      info "Phrase: \"$PHRASE\""
      ;;
    "__SECTION:REGISTRY__")
      current_section="registry"
      section "Registry Test Cases for '$SKILL_NAME'"
      ;;
    *)
      case "$current_section" in
        phrase)
          if [[ "$line" == MATCH:* ]]; then
            pass "${line#MATCH:}"
          elif [[ "$line" == BLOCKED:* ]]; then
            fail "Blocked — ${line#BLOCKED:}"
          elif [[ "$line" == NO_MATCH:* ]]; then
            fail "${line#NO_MATCH:}"
          elif [[ "$line" == ALSO:* ]]; then
            info "Also matched: ${line#ALSO:}"
          fi
          ;;
        registry)
          if [[ "$line" == PASS:* ]]; then
            pass "${line#PASS:}"
          elif [[ "$line" == FAIL:* ]]; then
            msg="${line#FAIL:}"
            desc="${msg%%|*}"
            detail="${msg#*|}"
            fail "$desc ($detail)"
          elif [[ "$line" == NONE:* ]]; then
            info "${line#NONE:}"
          fi
          ;;
      esac
      ;;
  esac
done <<< "$results"

# ── Summary ──────────────────────────────────────────────────────────
section "Summary"

echo "  Total: $total  Passed: $pass_count  Failed: $fail_count"
echo ""

if [ "$fail_count" -gt 0 ]; then
  printf "  \033[31m%d test(s) failed\033[0m\n" "$fail_count"
  echo ""
  exit 1
elif [ "$total" -eq 0 ]; then
  echo "  No tests executed"
  echo ""
  exit 0
else
  printf "  \033[32mAll tests passed\033[0m\n"
  echo ""
  exit 0
fi
