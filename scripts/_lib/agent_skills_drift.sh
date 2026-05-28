#!/usr/bin/env bash
# Drift detector for the agent-skills config (docs/agents/) vs. the CLAUDE.md
# '## Agent skills' block.
#
# Pure-ish: reads only its two path arguments and echoes one drift message per
# line. Emits nothing when the two are in sync, or when neither is set up. The
# (paths in → messages out) interface is the test surface — see
# scripts/test_agent_skills_drift.sh.
#
#   detect_agent_skills_drift <claude_md_path> <agents_dir>

detect_agent_skills_drift() {
  local claude_md="$1" agents_dir="$2"
  local block_present=0 docs_present=0 md

  if [ -f "$claude_md" ] && grep -qE '^## Agent skills[[:space:]]*$' "$claude_md"; then
    block_present=1
  fi

  if [ -d "$agents_dir" ]; then
    for md in "$agents_dir"/*.md; do
      [ -e "$md" ] && { docs_present=1; break; }  # literal glob when no match → stays 0
    done
  fi

  # Orphaned config: docs present on disk but no block in CLAUDE.md to point at them.
  if [ "$docs_present" -eq 1 ] && [ "$block_present" -eq 0 ]; then
    echo 'docs/agents/ config present but CLAUDE.md has no `## Agent skills` block'
  fi

  # Rotted pointers: the block references a docs/agents/<name>.md that no longer exists.
  if [ "$block_present" -eq 1 ]; then
    local block ref base
    # The block runs from the '## Agent skills' heading to the next H2 (### sub-headings don't close it).
    block="$(awk '/^## Agent skills[[:space:]]*$/{f=1;next} /^## /{f=0} f' "$claude_md")"
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      base="${ref##*/}"
      [ -f "$agents_dir/$base" ] || echo "CLAUDE.md \`## Agent skills\` block references missing file: $ref"
    done < <(printf '%s\n' "$block" | grep -oE 'docs/agents/[A-Za-z0-9._/-]+\.md' | sort -u)
  fi
}
