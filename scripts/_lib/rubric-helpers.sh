#!/usr/bin/env bash
# ── Shared rubric helper functions ──────────────────────────────────
# Sourced by score-behavioral.sh and score-skill-output.sh.
#
# Functions:
#   load_rubric <skill>       — Parse rubric file, set RUBRIC_* vars
#   build_judge_prompt        — Build LLM judge prompt from rubric
#   parse_judge_response      — Extract JSON scores from judge text
#   call_judge_api            — Call Anthropic API with prompt
#   list_available_rubrics    — List skill names with rubric files
# ────────────────────────────────────────────────────────────────────

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBRIC_DIR="${RUBRIC_DIR:-$(cd "$_LIB_DIR/../.." && pwd)/tests/rubrics}"

# ── load_rubric ─────────────────────────────────────────────────────
# Parses tests/rubrics/<skill>.md and sets:
#   RUBRIC_FOUND        — "true" or "false"
#   RUBRIC_BODY         — Markdown body (anchor tables, criteria)
#   RUBRIC_PASS_THRESH  — Overall pass threshold (float)
#   RUBRIC_DIM_COUNT    — Number of dimensions
#   RUBRIC_DIM_NAMES    — Space-separated dimension names
#   RUBRIC_THRESHOLDS   — Space-separated "name=threshold" pairs
#
# Returns 0 if rubric found, 1 if not.
load_rubric() {
  local skill="$1"

  # Reject path traversal and invalid characters
  if [[ "$skill" == */* ]] || [[ "$skill" == *..* ]] || [[ ! "$skill" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    return 1
  fi

  local rubric_file="${RUBRIC_DIR}/${skill}.md"

  RUBRIC_FOUND="false"
  RUBRIC_BODY=""
  RUBRIC_PASS_THRESH="3.0"
  RUBRIC_DIM_COUNT=0
  RUBRIC_DIM_NAMES=""
  RUBRIC_THRESHOLDS=""

  if [[ ! -f "$rubric_file" ]]; then
    return 1
  fi

  local full_json
  full_json=$(python3 "$_LIB_DIR/parse_rubric.py" "$rubric_file" 2>/dev/null) || return 1

  RUBRIC_FOUND="true"

  # Extract all scalar values in one jq call (pass_threshold, dim_count, dim_names, thresholds)
  local scalars
  scalars=$(printf '%s' "$full_json" | jq -r \
    '[(.pass_threshold // 3.0 | tostring),
      (.dimensions | length | tostring),
      ([.dimensions[].name] | join(" ")),
      ([.dimensions[] | "\(.name)=\(.threshold // 3)"] | join(" "))] | join("\t")')
  IFS=$'\t' read -r RUBRIC_PASS_THRESH RUBRIC_DIM_COUNT RUBRIC_DIM_NAMES RUBRIC_THRESHOLDS <<< "$scalars"

  # Extract body separately (may contain tabs/newlines)
  RUBRIC_BODY=$(printf '%s' "$full_json" | jq -r '.body')

  return 0
}

# ── rubric_get_threshold ────────────────────────────────────────────
# Get the threshold for a specific dimension from loaded rubric.
# Uses RUBRIC_THRESHOLDS (set by load_rubric) — zero subprocesses.
# Usage: rubric_get_threshold "clarity"
rubric_get_threshold() {
  local dim_name="$1"
  local entry
  for entry in $RUBRIC_THRESHOLDS; do
    if [[ "${entry%%=*}" == "$dim_name" ]]; then
      printf '%s' "${entry#*=}"
      return 0
    fi
  done
  printf '3'
}

# ── build_judge_prompt ──────────────────────────────────────────────
# Builds the LLM judge prompt using the loaded rubric.
#
# Args: $1=task_description, $2=output_text
# Requires: RUBRIC_BODY and RUBRIC_DIM_NAMES set by load_rubric()
# Prints: prompt string to stdout
build_judge_prompt() {
  local description="$1"
  local output_text="$2"

  # Truncate output to avoid huge API calls
  local truncated="${output_text:0:4000}"

  # Build dimension list for JSON response format
  local dim_json_keys=""
  local dim_num=1
  for dim in $RUBRIC_DIM_NAMES; do
    dim_json_keys="${dim_json_keys}\"${dim}\": N, "
    dim_num=$((dim_num + 1))
  done
  dim_json_keys="${dim_json_keys}\"reasoning\": \"one sentence\""

  cat <<PROMPT
You are an expert evaluator scoring the quality of an AI agent's output.

Task description: ${description}

Use the following rubric to score the output. Each dimension is scored 1-5.

${RUBRIC_BODY}

Output to evaluate:
---
${truncated}
---

Respond with ONLY a JSON object, no other text:
{${dim_json_keys}}
PROMPT
}

# ── build_default_judge_prompt ──────────────────────────────────────
# Fallback prompt when no per-skill rubric exists (original 3-dimension).
#
# Args: $1=task_description, $2=output_text
# Prints: prompt string to stdout
build_default_judge_prompt() {
  local description="$1"
  local output_text="$2"
  local truncated="${output_text:0:4000}"

  cat <<PROMPT
You are an expert evaluator scoring the quality of an AI agent's output.

Task description: ${description}

Score the following output on three dimensions, each on a scale of 1-5:

1. **Clarity** (1-5): Is the output well-organized, easy to follow, and free of confusion?
2. **Completeness** (1-5): Does the output address all aspects of the task? Are there gaps?
3. **Actionability** (1-5): Can the user take concrete next steps based on this output?

Output to evaluate:
---
${truncated}
---

Respond with ONLY a JSON object, no other text:
{"clarity": N, "completeness": N, "actionability": N, "reasoning": "one sentence"}
PROMPT
}

# ── parse_judge_response ────────────────────────────────────────────
# Extracts JSON scores from the judge's text response.
# Reads from stdin, prints JSON to stdout.
parse_judge_response() {
  python3 -c '
import sys, json, re
text = sys.stdin.read()
# Try direct parse first
try:
    d = json.loads(text)
    print(json.dumps(d))
    sys.exit(0)
except (ValueError, json.JSONDecodeError): pass
# Try extracting JSON from markdown code block or wrapped text
m = re.search(r"\{[^{}]+\}", text)
if m:
    try:
        d = json.loads(m.group())
        print(json.dumps(d))
        sys.exit(0)
    except (ValueError, json.JSONDecodeError): pass
print("{}")
' 2>/dev/null || printf '{}'
}

# ── call_judge_api ──────────────────────────────────────────────────
# Calls Anthropic API with the judge prompt.
#
# Args: $1=prompt_text
# Environment: ANTHROPIC_API_KEY, JUDGE_MODEL
# Sets: JUDGE_HTTP_CODE, JUDGE_RESPONSE_BODY, JUDGE_TEXT
# Returns: 0 on success, 1 on API error
call_judge_api() {
  local prompt_text="$1"
  local model="${JUDGE_MODEL:-claude-haiku-4-5-20251001}"

  # Escape the prompt for JSON payload
  local escaped_prompt
  escaped_prompt=$(printf '%s' "$prompt_text" | jq -Rs .)

  local api_response
  api_response=$(curl -s -w "\n%{http_code}" \
    https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
      \"model\": \"$model\",
      \"max_tokens\": 512,
      \"messages\": [{\"role\": \"user\", \"content\": $escaped_prompt}]
    }" 2>/dev/null) || true

  JUDGE_HTTP_CODE=$(printf '%s' "$api_response" | tail -1)
  JUDGE_RESPONSE_BODY=$(printf '%s' "$api_response" | sed '$d')

  if [[ "$JUDGE_HTTP_CODE" != "200" ]]; then
    JUDGE_TEXT=""
    return 1
  fi

  JUDGE_TEXT=$(printf '%s' "$JUDGE_RESPONSE_BODY" | jq -r '.content[0].text // ""')
  if [[ -z "$JUDGE_TEXT" ]]; then
    return 1
  fi

  return 0
}

# ── list_available_rubrics ──────────────────────────────────────────
# Lists skill names that have rubric files.
# Prints one skill name per line to stdout.
list_available_rubrics() {
  for f in "$RUBRIC_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    basename "$f" .md
  done
}

# ── print_available_rubrics ─────────────────────────────────────────
# Prints a formatted list of available rubrics to stdout.
print_available_rubrics() {
  printf "Available rubrics:\n"
  list_available_rubrics | while read -r name; do
    printf "  %s\n" "$name"
  done
}
