#!/usr/bin/env bash
# WS-A inventory lints (A-8 two-identifier consistency + A-9 flow-ID immutability).
#
# Pure: two functions, each (paths in → violation messages out), one message per
# line, nothing on success — the agent_skills_drift interface. Test surface:
# tests/run-flow-inventory-lint-vslice.sh; runner: scripts/flow-inventory-lint.sh.
#
#   detect_inventory_consistency <inventory.md> <flows-dir>
#   detect_flowid_immutability   <old-inventory.md> <new-inventory.md>
#
# Flow-ID schemes (FDA supports both per Q20 amendment 2 / BC-10352):
#   - legacy UPPERCASE code:  AUTH-01, STRIKE-02   (`[A-Z][A-Z0-9]*-[0-9]+`)
#   - canonical kebab slug:   seo-foundation/sitemap-and-robots  (domain/sub, both kebab)
# A split adds a trailing letter (FOO-01a / domain/sub-a); a deprecated flow
# keeps its ID and gains a `[DEPRECATED]` tag in its row.
#
# Bash 3.2 compatible. Stdlib only. Backticks are STRIPPED from inventory lines
# before matching (never embedded in a grep regex — BC-10352 gotcha).

# Flow-ID grammar (no leading/trailing anchors here; callers anchor).
FIL_KEBAB='[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9]+(-[a-z0-9]+)*'
FIL_UPPER='[A-Z][A-Z0-9]*-[0-9]+[a-z]?'

# Echo the flow-IDs declared in an inventory file's table rows (first cell),
# backticks stripped, one per line, sorted-unique. Domain-catalogue rows (bare
# slug, no slash) and prose rows are excluded by the flow-ID grammar.
_fil_inventory_ids() {
  awk -F'|' '/^[[:space:]]*\|/ {
    cell=$2; gsub(/`/,"",cell); gsub(/^[ \t]+|[ \t]+$/,"",cell); print cell
  }' "$1" 2>/dev/null \
    | grep -E "^($FIL_KEBAB|$FIL_UPPER)$" \
    | sort -u
}

# Echo the flow-IDs declared by the story docs under a flows dir (front-matter
# `fda_sub_flow_id:` or `flow_id:`), sorted-unique. Scoped per-file to the leading
# YAML front-matter block (between the first two `---` fences): a `flow_id:` line
# in the BODY (e.g. inside a fenced ```yaml example) is NOT a declared flow-ID and
# must not be counted (it would otherwise produce a spurious A-8 orphan-doc).
_fil_doc_ids() {
  find "$1" -type f -name '*.md' ! -name 'INDEX.md' 2>/dev/null \
    | while IFS= read -r f; do
        awk '
          NR==1 && $0=="---" { infm=1; next }
          infm && $0=="---"  { exit }
          infm && /^(fda_sub_flow_id|flow_id):/ { print }
        ' "$f" 2>/dev/null
      done \
    | sed -E 's/^(fda_sub_flow_id|flow_id):[[:space:]]*//; s/[`"]//g; s/[[:space:]]+$//' \
    | grep -vE '^$' | sort -u
}

# Which scheme(s) does a set of IDs (on stdin) use? echoes "upper", "kebab",
# both, or nothing.
_fil_schemes() {
  local has_u=0 has_k=0 id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if printf '%s' "$id" | grep -qE "^$FIL_UPPER$"; then has_u=1; fi
    if printf '%s' "$id" | grep -qE "^$FIL_KEBAB$"; then has_k=1; fi
  done
  [ "$has_u" -eq 1 ] && echo upper
  [ "$has_k" -eq 1 ] && echo kebab
}

# ── A-8: inventory ↔ doc two-identifier consistency ──────────────────────────
detect_inventory_consistency() {
  local inv="$1" flows="$2"
  [ -f "$inv" ] || { echo "inventory not found: $inv"; return; }
  [ -d "$flows" ] || { echo "flows dir not found: $flows"; return; }

  local inv_ids doc_ids id
  inv_ids="$(_fil_inventory_ids "$inv")"
  doc_ids="$(_fil_doc_ids "$flows")"

  # Orphan docs: a story doc whose flow-ID has no inventory row.
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if ! printf '%s\n' "$inv_ids" | grep -qxF "$id"; then
      echo "story-doc flow-ID '$id' has no matching inventory row"
    fi
  done <<EOF
$doc_ids
EOF

  # Orphan rows: an inventory flow-ID with no story doc.
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if ! printf '%s\n' "$doc_ids" | grep -qxF "$id"; then
      echo "inventory flow-ID '$id' has no matching story doc"
    fi
  done <<EOF
$inv_ids
EOF

  # Two-schema conflict: a single inventory must not mix UPPERCASE and kebab.
  local schemes
  schemes="$(printf '%s\n' "$inv_ids" | _fil_schemes | tr '\n' ' ')"
  case "$schemes" in
    *upper*kebab*|*kebab*upper*)
      echo "inventory mixes flow-ID schemes (UPPERCASE-NN and kebab domain/slug) — pick one per repo (Q20 amendment 2)"
      ;;
  esac
}

# ── A-9: flow-ID immutability (diff-aware) ───────────────────────────────────
# A flow-ID is a stable contract. Every ID present in the old inventory must
# still be present in the new one — UNLESS it was split (new has `<id>` + a
# trailing-letter variant). A deprecated flow keeps its ID (gains [DEPRECATED]),
# so it never goes missing. Renames / silent removals are the FK-fragility
# teardown defect this guards against.
detect_flowid_immutability() {
  local old_inv="$1" new_inv="$2"
  [ -f "$old_inv" ] || { echo "old inventory not found: $old_inv"; return; }
  [ -f "$new_inv" ] || { echo "new inventory not found: $new_inv"; return; }

  local old_ids new_ids id
  old_ids="$(_fil_inventory_ids "$old_inv")"
  new_ids="$(_fil_inventory_ids "$new_inv")"

  while IFS= read -r id; do
    [ -n "$id" ] || continue
    printf '%s\n' "$new_ids" | grep -qxF "$id" && continue   # still present
    # Allowed: split into trailing-letter variants (FOO-01 -> FOO-01a / FOO-01-a).
    if printf '%s\n' "$new_ids" | grep -qE "^${id}-?[a-z]$"; then
      continue
    fi
    echo "flow-ID '$id' was removed/renamed — immutability breach (split to '${id}a'/'${id}-a' or keep + [DEPRECATED] instead)"
  done <<EOF
$old_ids
EOF
}
