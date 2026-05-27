#!/usr/bin/env bash
# Regression harness for the PreToolUse > Bash security classifier in
# plugins/workflows/hooks/hooks.json. Two tiers:
#
# Tier 1 (Approach B — offline, no API calls):
#   Spec-tests the prompt text and regex pattern to ensure the
#   --force-with-lease carve-out is present with correct branch-aware
#   constraints. Prevents accidental removal on future prompt edits.
#
# Tier 2 (Approach A — optional, requires Haiku):
#   Invokes Haiku with the actual prompt + synthetic commands and asserts
#   the JSON verdict. Enabled via --with-haiku flag. Skipped by default.
#
# Scenarios:
#   A  prompt contains "force-with-lease" keyword                  (content lock)
#   B  prompt contains safe branch patterns (feat/*, fix/*, etc.)  (content lock)
#   C  prompt contains protected-ref block list (main, master)     (content lock)
#   D  prompt contains conservative-default fallback               (content lock)
#   E  regex does NOT match --force-with-lease                     (regex verify)
#   F  regex DOES match --force (space-terminated)                 (regex verify)
#   G  regex DOES match --force" (quote-terminated)                (regex verify)
#   H  regex DOES match -f (short flag)                            (regex verify)
#   I  prompt lists holden/* as safe pattern                       (content lock)
#   J  prompt requires flagging when branch undetermined           (content lock)
#
# Usage:
#   bash scripts/test_security_hook_classifier.sh
#   bash scripts/test_security_hook_classifier.sh /path/to/hooks.json
#   bash scripts/test_security_hook_classifier.sh --with-haiku  # also runs Tier 2

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_JSON="${1:-$SCRIPT_DIR/../plugins/workflows/hooks/hooks.json}"
WITH_HAIKU=false

for arg in "$@"; do
  case "$arg" in
    --with-haiku) WITH_HAIKU=true ;;
  esac
done

if [ ! -f "$HOOKS_JSON" ]; then
  echo "FATAL: hooks.json not found: $HOOKS_JSON"
  exit 2
fi

pass=0
fail=0

assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if printf '%s' "$haystack" | grep -qi "$needle"; then
    echo "  PASS  $label"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label (expected to contain: '$needle')"
    fail=$((fail + 1))
  fi
}

assert_not_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if printf '%s' "$haystack" | grep -qi "$needle"; then
    echo "  FAIL  $label (expected NOT to contain: '$needle')"
    fail=$((fail + 1))
  else
    echo "  PASS  $label"
    pass=$((pass + 1))
  fi
}

assert_regex_matches() {
  local label="$1"
  local pattern="$2"
  local input="$3"
  if printf '%s\n' "$input" | grep -Eiq "$pattern"; then
    echo "  PASS  $label"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label (regex did not match: '$input')"
    fail=$((fail + 1))
  fi
}

assert_regex_no_match() {
  local label="$1"
  local pattern="$2"
  local input="$3"
  if printf '%s\n' "$input" | grep -Eiq "$pattern"; then
    echo "  FAIL  $label (regex unexpectedly matched: '$input')"
    fail=$((fail + 1))
  else
    echo "  PASS  $label"
    pass=$((pass + 1))
  fi
}

PROMPT=$(python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    data = json.load(f)
for group in data.get('hooks', {}).get('PreToolUse', []):
    if group.get('matcher') == 'Bash':
        for hook in group.get('hooks', []):
            if hook.get('type') == 'prompt':
                print(hook['prompt'])
                sys.exit(0)
print('ERROR: prompt hook not found', file=sys.stderr)
sys.exit(1)
")
if [ $? -ne 0 ]; then
  echo "FATAL: could not extract prompt from hooks.json"
  exit 2
fi

REGEX=$(python3 -c "
import json, sys, re
with open('$HOOKS_JSON') as f:
    data = json.load(f)
for group in data.get('hooks', {}).get('PreToolUse', []):
    if group.get('matcher') == 'Bash':
        for hook in group.get('hooks', []):
            if hook.get('type') == 'command' and 'force' in hook.get('command', ''):
                cmd = hook['command']
                m = re.search(r\"grep -Eiq '([^']*)'\", cmd)
                if m:
                    print(m.group(1))
                    sys.exit(0)
print('ERROR: regex hook not found', file=sys.stderr)
sys.exit(1)
")
if [ $? -ne 0 ]; then
  echo "FATAL: could not extract regex from hooks.json"
  exit 2
fi

echo "=== Tier 1: Prompt Content Spec-Tests ==="

# A: prompt mentions force-with-lease
assert_contains \
  "A: prompt contains 'force-with-lease' keyword" \
  "$PROMPT" \
  "force-with-lease"

# B: prompt lists safe branch patterns
assert_contains \
  "B: prompt contains safe branch patterns (feat/*, fix/*)" \
  "$PROMPT" \
  "feat/\*"

# C: prompt contains protected-ref block list
assert_contains \
  "C: prompt contains protected-ref 'main'" \
  "$PROMPT" \
  "main.*master.*release"

# D: prompt contains conservative-default fallback
assert_contains \
  "D: prompt contains conservative default-to-flagging fallback" \
  "$PROMPT" \
  "default to flagging"

# I: prompt lists holden/* as safe pattern
assert_contains \
  "I: prompt lists holden/* as safe pattern" \
  "$PROMPT" \
  'holden/\*'

# J: prompt requires flagging when branch undetermined
assert_contains \
  "J: prompt requires flagging when branch cannot be determined" \
  "$PROMPT" \
  "cannot be determined"

echo ""
echo "=== Tier 1: Regex Pattern Verification ==="

FORCE_REGEX='git[[:space:]]+push.*--force([[:space:]]|"|$)'

# E: regex does NOT match --force-with-lease
assert_regex_no_match \
  "E: regex does NOT match 'git push --force-with-lease origin feat/x'" \
  "$FORCE_REGEX" \
  "git push --force-with-lease origin feat/x"

# F: regex DOES match --force (space-terminated)
assert_regex_matches \
  "F: regex DOES match 'git push --force origin main'" \
  "$FORCE_REGEX" \
  "git push --force origin main"

# G: regex DOES match --force" (quote-terminated)
assert_regex_matches \
  'G: regex DOES match git push --force" (quote-terminated)' \
  "$FORCE_REGEX" \
  'git push --force"'

# H: regex DOES match -f (short flag)
SHORT_REGEX='git[[:space:]]+push.*[[:space:]]-f'
assert_regex_matches \
  "H: regex DOES match 'git push -f origin main'" \
  "$SHORT_REGEX" \
  "git push -f origin main"

echo ""

if [ "$fail" -gt 0 ]; then
  echo "RESULT pass=$pass fail=$fail"
  exit 1
else
  echo "RESULT pass=$pass fail=0"
  exit 0
fi
