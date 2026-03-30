#!/usr/bin/env bash
set -euo pipefail

# ── Validate Single — Run checks on one skill or command ─────────────
# Usage:
#   scripts/validate-single.sh <skill-name>     # validates skills/<name>/SKILL.md
#   scripts/validate-single.sh <command.md>      # validates commands/<name>.md
#   scripts/validate-single.sh agents/<name>     # validates agents/<name>.md
#
# Runs the same frontmatter and structural checks as validate.sh but
# for a single file — fast feedback during development (~1s).
# ─────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/workflows"

errors=0
warnings=0

pass()    { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail()    { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; errors=$((errors + 1)); }
warn()    { printf "  \033[33mWARN\033[0m  %s\n" "$1"; warnings=$((warnings + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# Extract frontmatter (lines between first --- and second ---)
frontmatter() {
  sed -n '2,/^---$/{/^---$/d; p;}' "$1"
}

# Get a YAML value by key (simple single-line values only)
yaml_val() {
  echo "$1" | grep "^$2:" | head -1 | sed "s/^$2: *//" || true
}

# ── Usage ────────────────────────────────────────────────────────────
if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <skill-name|command.md|agents/name>"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") brainstorming           # skill"
  echo "  $(basename "$0") session-start.md        # command"
  echo "  $(basename "$0") session-start           # command (auto-adds .md)"
  echo "  $(basename "$0") agents/code-reviewer    # agent"
  exit 1
fi

TARGET="$1"

# ── Resolve target to a file ─────────────────────────────────────────
resolve_target() {
  local target="$1"
  local file=""
  local kind=""

  # Explicit agents/ prefix
  if [[ "$target" == agents/* ]]; then
    local agent_name="${target#agents/}"
    agent_name="${agent_name%.md}"
    file="$PLUGIN_ROOT/agents/$agent_name.md"
    kind="agent"
  # Ends in .md → treat as command
  elif [[ "$target" == *.md ]]; then
    file="$PLUGIN_ROOT/commands/$target"
    kind="command"
  # Check if it's a skill directory
  elif [ -d "$PLUGIN_ROOT/skills/$target" ]; then
    file="$PLUGIN_ROOT/skills/$target/SKILL.md"
    kind="skill"
  # Check if it's a command without .md
  elif [ -f "$PLUGIN_ROOT/commands/${target}.md" ]; then
    file="$PLUGIN_ROOT/commands/${target}.md"
    kind="command"
  # Check if it's an agent without prefix
  elif [ -f "$PLUGIN_ROOT/agents/${target}.md" ]; then
    file="$PLUGIN_ROOT/agents/$target.md"
    kind="agent"
  else
    echo ""
    return 1
  fi

  echo "$kind:$file"
}

resolved=$(resolve_target "$TARGET") || {
  echo "ERROR: Could not find '$TARGET' as a skill, command, or agent." >&2
  echo "" >&2
  echo "Available skills:" >&2
  for d in "$PLUGIN_ROOT"/skills/*/; do
    name="$(basename "$d")"
    [ "$name" = "_shared" ] && continue
    echo "  $name" >&2
  done
  echo "" >&2
  echo "Available commands:" >&2
  for f in "$PLUGIN_ROOT"/commands/*.md; do
    echo "  $(basename "$f")" >&2
  done
  exit 1
}

KIND="${resolved%%:*}"
FILE="${resolved#*:}"

if [ ! -f "$FILE" ]; then
  echo "ERROR: File not found: $FILE" >&2
  exit 1
fi

echo "Validating $KIND: $(basename "$(dirname "$FILE")")/$(basename "$FILE")"

# ── Frontmatter check ───────────────────────────────────────────────
section "Frontmatter"

first_line=$(head -1 "$FILE")
if [ "$first_line" != "---" ]; then
  fail "Missing YAML frontmatter (first line must be ---)"
  section "Summary"
  printf "  \033[31m%d error(s)\033[0m, %d warning(s)\n" "$errors" "$warnings"
  exit 1
fi

fm=$(frontmatter "$FILE")

case "$KIND" in
  skill)
    dirname="$(basename "$(dirname "$FILE")")"

    # name must match directory
    name_val=$(yaml_val "$fm" "name")
    if [ -z "$name_val" ]; then
      fail "Missing 'name' field"
    elif [ "$name_val" != "$dirname" ]; then
      fail "name '$name_val' does not match directory '$dirname'"
    else
      pass "name matches directory"
    fi

    # description — must exist and not be quoted
    desc_val=$(yaml_val "$fm" "description")
    if [ -z "$desc_val" ]; then
      fail "Missing 'description' field"
    elif [[ "$desc_val" == \"* ]] || [[ "$desc_val" == \'* ]] || [[ "$desc_val" == ">"* ]]; then
      fail "description must not be quoted"
    else
      pass "description present"
    fi

    # user-invocable — must be explicit true or false
    ui_val=$(yaml_val "$fm" "user-invocable")
    if [ -z "$ui_val" ]; then
      fail "Missing 'user-invocable' field"
    elif [ "$ui_val" != "true" ] && [ "$ui_val" != "false" ]; then
      fail "user-invocable must be 'true' or 'false', got '$ui_val'"
    else
      pass "user-invocable: $ui_val"
    fi

    # allowed-tools — must be comma-separated string, not YAML array
    at_val=$(yaml_val "$fm" "allowed-tools")
    if [ -n "$at_val" ]; then
      next_line=$(sed -n '/^allowed-tools:/{ n; p; }' "$FILE")
      if [[ "$next_line" =~ ^[[:space:]]*-[[:space:]] ]]; then
        fail "allowed-tools must be comma-separated string, not YAML array"
      else
        pass "allowed-tools format ok"
      fi
    fi

    # argument-hint — must be top-level, not nested under metadata
    ah_in_meta=$(echo "$fm" | sed -n '/^metadata:/,/^[^ ]/p' | grep "argument-hint:" || true)
    ah_toplevel=$(echo "$fm" | grep "^argument-hint:" || true)
    if [ -n "$ah_in_meta" ]; then
      fail "argument-hint must be top-level, not nested under metadata"
    elif [ -n "$ah_toplevel" ]; then
      pass "argument-hint is top-level"
    fi

    # agent reference — verify file exists
    agent_val=$(yaml_val "$fm" "agent")
    if [ -n "$agent_val" ]; then
      agent_file="$PLUGIN_ROOT/agents/$agent_val.md"
      if [ -f "$agent_file" ]; then
        pass "agent '$agent_val' exists"
      else
        fail "agent '$agent_val' references missing file agents/$agent_val.md"
      fi
    fi

    # license — verify LICENSE file exists
    license_val=$(yaml_val "$fm" "license")
    if [ -n "$license_val" ]; then
      skill_dir="$(dirname "$FILE")"
      if [ -f "$skill_dir/LICENSE" ] || [ -f "$skill_dir/LICENSE.txt" ] || \
         [ -f "$PLUGIN_ROOT/LICENSE" ] || [ -f "$PLUGIN_ROOT/LICENSE.txt" ]; then
        pass "LICENSE file found"
      else
        fail "declares license '$license_val' but no LICENSE file in skill dir or plugin root"
      fi
    fi
    ;;

  command)
    desc=$(yaml_val "$fm" "description")
    if [ -z "$desc" ]; then
      fail "Missing 'description' in frontmatter"
    else
      pass "description present"
    fi
    ;;

  agent)
    base="$(basename "$FILE" .md)"

    # name must match filename
    name_val=$(yaml_val "$fm" "name")
    if [ -z "$name_val" ]; then
      fail "Missing 'name' field"
    elif [ "$name_val" != "$base" ]; then
      fail "name '$name_val' does not match filename '$base'"
    else
      pass "name matches filename"
    fi

    # description
    desc_val=$(yaml_val "$fm" "description")
    if [ -z "$desc_val" ]; then
      fail "Missing 'description' field"
    else
      pass "description present"
    fi

    # model
    model_val=$(yaml_val "$fm" "model")
    if [ -z "$model_val" ]; then
      fail "Missing 'model' field"
    elif [ "$model_val" != "opus" ] && [ "$model_val" != "sonnet" ] && [ "$model_val" != "haiku" ]; then
      fail "model must be opus/sonnet/haiku, got '$model_val'"
    else
      pass "model: $model_val"
    fi

    # tools — optional, but if present must be comma-separated string
    tools_val=$(yaml_val "$fm" "tools")
    if [ -n "$tools_val" ]; then
      next_line=$(sed -n '/^tools:/{ n; p; }' "$FILE")
      if [[ "$next_line" =~ ^[[:space:]]*-[[:space:]] ]]; then
        fail "tools must be comma-separated string, not YAML array"
      else
        pass "tools format ok"
      fi
    fi
    ;;
esac

# ── Step Sequence ────────────────────────────────────────────────────
section "Step Sequence"

all_steps=()
while IFS= read -r num; do
  [ -n "$num" ] && all_steps+=("$num")
done < <(grep -E '^#{2,4} Step [0-9]+([^0-9a-zA-Z]|$)' "$FILE" 2>/dev/null | sed -n 's/^#\{2,4\} Step \([0-9][0-9]*\).*/\1/p')

if [ ${#all_steps[@]} -lt 2 ]; then
  pass "No step sequence to validate (${#all_steps[@]} steps)"
else
  # Guard: verify all extracted values are numeric
  numeric_ok=true
  for num in "${all_steps[@]}"; do
    case "$num" in
      *[!0-9]*) numeric_ok=false; break ;;
    esac
  done

  if [ "$numeric_ok" = false ]; then
    warn "Non-numeric step value extracted — skipping"
  else
    step_ok=true

    # Split into contiguous sequences
    seq_list=()
    current_seq="${all_steps[0]}"
    prev="${all_steps[0]}"

    for ((i = 1; i < ${#all_steps[@]}; i++)); do
      if [ "${all_steps[$i]}" -lt "$prev" ]; then
        seq_list+=("$current_seq")
        current_seq="${all_steps[$i]}"
      else
        current_seq="$current_seq;${all_steps[$i]}"
      fi
      prev="${all_steps[$i]}"
    done
    seq_list+=("$current_seq")

    for seq in "${seq_list[@]}"; do
      IFS=';' read -ra steps <<< "$seq"

      if [ "${steps[0]}" -gt 1 ]; then
        fail "Sequence starts at Step ${steps[0]} (expected 0 or 1)"
        step_ok=false
      fi

      for ((j = 1; j < ${#steps[@]}; j++)); do
        expected=$(( steps[j-1] + 1 ))
        if [ "${steps[$j]}" -ne "$expected" ]; then
          fail "Gap — Step ${steps[$((j-1))]} to Step ${steps[$j]} (expected Step $expected)"
          step_ok=false
        fi
      done

      dupes=$(printf '%s\n' "${steps[@]}" | sort -n | uniq -d)
      if [ -n "$dupes" ]; then
        while IFS= read -r d; do
          [ -z "$d" ] && continue
          fail "Duplicate Step $d"
          step_ok=false
        done <<< "$dupes"
      fi
    done

    if [ "$step_ok" = true ]; then
      pass "Step sequence valid (${#all_steps[@]} steps)"
    fi
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────
section "Summary"

if [ "$errors" -eq 0 ]; then
  printf "  \033[32m%s passed\033[0m, %d warning(s)\n" "$KIND" "$warnings"
  echo ""
  exit 0
else
  printf "  \033[31m%d error(s)\033[0m, %d warning(s)\n" "$errors" "$warnings"
  echo ""
  exit 1
fi
