#!/usr/bin/env bash
set -euo pipefail

# ── Skill Output Scorer (Ad-hoc LLM-as-Judge) ──────────────────────
# Scores any skill output against its rubric file. Standalone tool
# for ad-hoc quality evaluation outside the behavioral test pipeline.
#
# Usage:
#   bash scripts/score-skill-output.sh --skill brainstorming --input output.txt
#   bash scripts/score-skill-output.sh --skill brainstorming --input -
#   echo "output" | bash scripts/score-skill-output.sh --skill brainstorming --input -
#   bash scripts/score-skill-output.sh --skill brainstorming --input output.txt --format json
#   bash scripts/score-skill-output.sh --list
#   bash scripts/score-skill-output.sh --help
#
# Environment:
#   ANTHROPIC_API_KEY   Required. API key for Anthropic API.
#   JUDGE_MODEL         Judge model (default: claude-haiku-4-5-20251001)
# ────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JUDGE_MODEL="${JUDGE_MODEL:-claude-haiku-4-5-20251001}"

source "$REPO_ROOT/scripts/_lib/rubric-helpers.sh"

# ── Helpers ─────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: bash $0 --skill NAME --input PATH [--format text|json]

Score a skill's output against its rubric using LLM-as-judge.

Options:
  --skill NAME      Skill name (must have a rubric in tests/rubrics/)
  --input PATH      Path to output file, or - for stdin
  --format FORMAT   Output format: text (default) or json
  --list            List available rubrics and exit
  --help            Show this help

Environment:
  ANTHROPIC_API_KEY   Required. API key for Anthropic API.
  JUDGE_MODEL         Judge model (default: claude-haiku-4-5-20251001)

Examples:
  bash $0 --skill brainstorming --input docs/designs/BC-2468-rubrics.md
  cat output.txt | bash $0 --skill writing-plans --input - --format json
EOF
  exit 0
}

# ── Parse args ──────────────────────────────────────────────────────
SKILL=""
INPUT=""
FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)  SKILL="$2"; shift 2 ;;
    --input)  INPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --list)
      print_available_rubrics
      exit 0
      ;;
    --help)   usage ;;
    *)        printf "ERROR: Unknown argument: %s\n" "$1"; exit 2 ;;
  esac
done

# ── Guards ──────────────────────────────────────────────────────────
if [[ -z "$SKILL" ]]; then
  printf "ERROR: --skill is required.\n\n"
  print_available_rubrics
  exit 2
fi

if [[ -z "$INPUT" ]]; then
  printf "ERROR: --input is required (path or - for stdin).\n"
  exit 2
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  printf "ERROR: ANTHROPIC_API_KEY must be set.\n"
  exit 2
fi

if ! command -v jq &>/dev/null; then
  printf "ERROR: 'jq' is required. Install: brew install jq\n"
  exit 2
fi

# ── Load rubric ─────────────────────────────────────────────────────
if ! load_rubric "$SKILL"; then
  printf "ERROR: No rubric found for skill '%s'.\n\n" "$SKILL"
  print_available_rubrics
  exit 2
fi

# ── Read input ──────────────────────────────────────────────────────
if [[ "$INPUT" == "-" ]]; then
  output_text=$(cat)
else
  if [[ ! -f "$INPUT" ]]; then
    printf "ERROR: Input file not found: %s\n" "$INPUT"
    exit 2
  fi
  output_text=$(cat "$INPUT")
fi

if [[ -z "$output_text" ]]; then
  printf "ERROR: Input is empty.\n"
  exit 2
fi

# ── Score ───────────────────────────────────────────────────────────
judge_prompt=$(build_judge_prompt "Evaluate the output of the '$SKILL' skill" "$output_text")

if ! call_judge_api "$judge_prompt"; then
  printf "ERROR: API call failed (HTTP %s)\n" "$JUDGE_HTTP_CODE"
  exit 1
fi

judge_json=$(printf '%s' "$JUDGE_TEXT" | parse_judge_response)
reasoning=$(printf '%s' "$judge_json" | jq -r '.reasoning // "no reasoning"')

# ── Compute results ─────────────────────────────────────────────────
total_score=0
dim_count=0
all_pass=true
dim_entries=()

for dim in $RUBRIC_DIM_NAMES; do
  score_val=$(printf '%s' "$judge_json" | jq --arg d "$dim" '.[$d] // 0 | floor')
  threshold_val=$(rubric_get_threshold "$dim")
  dim_pass="true"

  if [[ "$score_val" -lt "$threshold_val" ]]; then
    dim_pass="false"
    all_pass=false
  fi

  total_score=$((total_score + score_val))
  dim_count=$((dim_count + 1))

  dim_entries+=("$(jq -n \
    --arg name "$dim" \
    --argjson score "$score_val" \
    --argjson threshold "$threshold_val" \
    --argjson pass "$dim_pass" \
    '{name: $name, score: $score, threshold: $threshold, pass: $pass}')")
done

# Build dimensions_json in one call
dimensions_json=$(printf '%s\n' "${dim_entries[@]}" | jq -s '.')

# Compute average and overall verdict with awk (no python subprocess)
average=$(awk "BEGIN { printf \"%.1f\", $total_score / $dim_count }")
overall_pass="$all_pass"
if ! awk "BEGIN { exit ($average >= $RUBRIC_PASS_THRESH) ? 0 : 1 }"; then
  overall_pass=false
fi

verdict="PASS"
if [[ "$overall_pass" != true ]]; then
  verdict="FAIL"
fi

# ── Output ──────────────────────────────────────────────────────────
if [[ "$FORMAT" == "json" ]]; then
  jq -n \
    --arg skill "$SKILL" \
    --argjson dimensions "$dimensions_json" \
    --argjson average "$average" \
    --argjson pass_threshold "$RUBRIC_PASS_THRESH" \
    --arg verdict "$verdict" \
    --arg reasoning "$reasoning" \
    --arg judge_model "$JUDGE_MODEL" \
    '{skill: $skill, dimensions: $dimensions, average: $average, pass_threshold: $pass_threshold, verdict: $verdict, reasoning: $reasoning, judge_model: $judge_model}'
else
  printf "\n"
  printf "Brite Plugin — Skill Output Scorer\n"
  printf "Skill:    %s\n" "$SKILL"
  printf "Judge:    %s\n" "$JUDGE_MODEL"
  printf "\n"

  # Read all dimension fields in a single jq call per dimension
  local_dim_count=$(printf '%s' "$dimensions_json" | jq 'length')
  for idx in $(seq 0 $((local_dim_count - 1))); do
    read -r dim_name dim_score dim_thresh dim_passed < <(
      printf '%s' "$dimensions_json" | jq -r ".[$idx] | [.name, (.score|tostring), (.threshold|tostring), .pass] | @tsv"
    )
    if [[ "$dim_passed" == "true" ]]; then
      printf "  \033[32mPASS\033[0m  %-20s %s/5 (threshold: %s)\n" "$dim_name" "$dim_score" "$dim_thresh"
    else
      printf "  \033[31mFAIL\033[0m  %-20s %s/5 (threshold: %s)\n" "$dim_name" "$dim_score" "$dim_thresh"
    fi
  done

  printf "\n"
  printf "  Average:        %s/5 (pass: >= %s)\n" "$average" "$RUBRIC_PASS_THRESH"
  printf "  Reasoning:      %s\n" "$reasoning"
  printf "\n"

  if [[ "$verdict" == "PASS" ]]; then
    printf "  \033[32mOverall: PASS\033[0m\n"
  else
    printf "  \033[31mOverall: FAIL\033[0m\n"
  fi
  printf "\n"
fi

# ── Exit code ───────────────────────────────────────────────────────
if [[ "$verdict" == "PASS" ]]; then
  exit 0
else
  exit 1
fi
