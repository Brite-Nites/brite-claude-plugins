#!/usr/bin/env bash
set -euo pipefail

# ── Anti-Slop Guardrail Checker ───────────────────────────────────────
# Scans plan files and CLAUDE.md for machine-checkable anti-slop
# pattern violations. See docs/quality-guardrails.md for full catalog.
#
# Usage:
#   bash scripts/check-guardrails.sh --plan <path>       # Check one plan
#   bash scripts/check-guardrails.sh --all <dir>          # Check all plans in dir
#   bash scripts/check-guardrails.sh --claude-md <path>   # Check CLAUDE.md
#   bash scripts/check-guardrails.sh --help
# ──────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Counters & helpers ────────────────────────────────────────────────
errors=0
warnings=0

pass()    { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail()    { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; errors=$((errors + 1)); }
warn()    { printf "  \033[33mWARN\033[0m  %s\n" "$1"; warnings=$((warnings + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

usage() {
  cat <<'EOF'
Anti-Slop Guardrail Checker

Scans plan files and CLAUDE.md for machine-checkable anti-slop violations.

Usage:
  bash scripts/check-guardrails.sh --plan <path>       Check a single plan file
  bash scripts/check-guardrails.sh --all <dir>          Check all .md files in directory
  bash scripts/check-guardrails.sh --claude-md <path>   Check CLAUDE.md for bloat
  bash scripts/check-guardrails.sh --help               Show this help

Patterns checked:
  PL1  Vague task descriptions (hedge phrases without file paths)
  PL2  Oversized tasks (>5 implementation steps or >3 files)
  PL3  Missing file paths (no file path in task body)
  PL4  Missing verification steps (no Verify/Test section)
  C2   CLAUDE.md bloat (>100 lines)

Exit codes:
  0   No violations found
  1   One or more violations found
  2   Usage error
EOF
  exit 0
}

# ── Parse arguments ───────────────────────────────────────────────────
MODE=""
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)    MODE="plan";     shift; TARGET="${1:-}"; shift || true ;;
    --all)     MODE="all";      shift; TARGET="${1:-}"; shift || true ;;
    --claude-md) MODE="claude"; shift; TARGET="${1:-}"; shift || true ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1" >&2; echo "Run with --help for usage." >&2; exit 2 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "No mode specified. Run with --help for usage." >&2
  exit 2
fi

if [[ -z "$TARGET" ]]; then
  echo "No target path specified for --$MODE." >&2
  exit 2
fi

# ── Plan file checks ─────────────────────────────────────────────────

# Extract task blocks from a plan file.
# A task starts with ### Task or **Task and ends at the next task or EOF.
check_plan_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    fail "File not found: $file"
    return
  fi

  section "Plan: $(basename "$file")"

  local task_count=0
  local current_task=""
  local in_task=false

  # Process line by line, collecting task blocks
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^###[[:space:]]+[Tt]ask ]]; then
      # Process previous task if we had one
      if $in_task && [[ -n "$current_task" ]]; then
        check_task "$current_task" "$task_count"
      fi
      task_count=$((task_count + 1))
      current_task="$line"
      in_task=true
    elif $in_task; then
      current_task="$current_task"$'\n'"$line"
    fi
  done < "$file"

  # Process last task
  if $in_task && [[ -n "$current_task" ]]; then
    check_task "$current_task" "$task_count"
  fi

  if [[ $task_count -eq 0 ]]; then
    warn "No task blocks found (expected ### Task N headings)"
  else
    pass "Found $task_count task(s)"
  fi
}

check_task() {
  local task_body="$1"
  local task_num="$2"
  local task_label="Task $task_num"

  # ── Shared: count file paths once (used by PL1 and PL3) ──────────
  local path_count
  path_count=$(grep -cE '[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+|`[a-zA-Z0-9_-]+\.[a-zA-Z]{1,5}`' <<< "$task_body" || true)

  # ── PL1: Vague task descriptions ─────────────────────────────────
  # If task body contains hedge phrases but no file paths, flag it
  local combined_hedge="implement the [a-z]|set up the [a-z]|handle the [a-z]|make it work|do the thing|add the logic|create the function|write the code|update the file|fix the issue"
  if grep -qiE "$combined_hedge" <<< "$task_body"; then
    if [[ "$path_count" -lt 1 ]]; then
      local matched
      matched=$(grep -oiE "$combined_hedge" <<< "$task_body" | head -1)
      fail "PL1 ($task_label): Vague description matches '$matched' with no file paths"
    fi
  fi

  # ── PL2: Oversized tasks ─────────────────────────────────────────
  # Count numbered implementation steps
  local impl_section
  impl_section=$(sed -n '/\*\*Implementation\*\*/,/\*\*[A-Z]/p' <<< "$task_body" || true)
  if [[ -n "$impl_section" ]]; then
    local step_count
    step_count=$(grep -cE '^\s*[0-9]+\.' <<< "$impl_section" || true)
    if [[ "$step_count" -gt 5 ]]; then
      fail "PL2 ($task_label): $step_count implementation steps (max 5)"
    else
      pass "PL2 ($task_label): $step_count implementation steps"
    fi
  fi

  # Count files mentioned in task (unique file paths)
  local file_count
  file_count=$(grep -oE '[a-zA-Z0-9_-]+/[a-zA-Z0-9_./-]+\.[a-zA-Z]{1,5}' <<< "$task_body" | sort -u | wc -l)
  if [[ "$file_count" -gt 3 ]]; then
    fail "PL2 ($task_label): $file_count files referenced (max 3)"
  fi

  # ── PL3: Missing file paths ─────────────────────────────────────
  if [[ "$path_count" -lt 1 ]]; then
    fail "PL3 ($task_label): No file paths found in task body"
  else
    pass "PL3 ($task_label): $path_count file path references"
  fi

  # ── PL4: Missing verification steps ──────────────────────────────
  if grep -qiE '\*\*Verify\*\*|\*\*Test\*\*|^Verify:' <<< "$task_body"; then
    pass "PL4 ($task_label): Verification section found"
  else
    fail "PL4 ($task_label): No Verify/Test section found"
  fi
}

# ── CLAUDE.md checks ──────────────────────────────────────────────────

check_claude_md() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    fail "File not found: $file"
    return
  fi

  section "CLAUDE.md: $(basename "$file")"

  # ── C2: CLAUDE.md bloat ───────────────────────────────────────────
  local line_count
  line_count=$(wc -l < "$file" | tr -d ' ')

  if [[ "$line_count" -gt 150 ]]; then
    fail "C2: CLAUDE.md is $line_count lines (max 150). Extract sections to docs/ with @import"
  elif [[ "$line_count" -gt 100 ]]; then
    warn "C2: CLAUDE.md is $line_count lines (target: <=100). Consider extracting to docs/"
  else
    pass "C2: CLAUDE.md is $line_count lines"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────

echo "Anti-Slop Guardrail Checker"
echo "Mode: $MODE | Target: $TARGET"

case "$MODE" in
  plan)
    check_plan_file "$TARGET"
    ;;
  all)
    if [[ ! -d "$TARGET" ]]; then
      echo "Directory not found: $TARGET" >&2
      exit 2
    fi
    found=0
    for plan_file in "$TARGET"/*.md; do
      [[ -f "$plan_file" ]] || continue
      check_plan_file "$plan_file"
      found=$((found + 1))
    done
    if [[ $found -eq 0 ]]; then
      echo "No .md files found in $TARGET"
    fi
    ;;
  claude)
    check_claude_md "$TARGET"
    ;;
esac

# ── Summary ───────────────────────────────────────────────────────────
echo ""
if [[ $errors -gt 0 ]]; then
  printf "\033[31m%d violation(s)\033[0m" "$errors"
else
  printf "\033[32m0 violations\033[0m"
fi
if [[ $warnings -gt 0 ]]; then
  printf ", \033[33m%d warning(s)\033[0m" "$warnings"
fi
echo ""

exit $((errors > 0 ? 1 : 0))
