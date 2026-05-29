#!/usr/bin/env bash
# Regression-lock for the WS-A inventory lints (scripts/lib/flow_inventory_lint.sh):
#   A-8 detect_inventory_consistency  (orphan docs / orphan rows / scheme mix)
#   A-9 detect_flowid_immutability    (removed/renamed flow-ID, split + deprecated allowances)
#
# Fixtures are built in a temp dir (printf), so no committed fixture sprawl.
# Bash 3.2 compatible. Stdlib only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../scripts/lib/flow_inventory_lint.sh"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 1; }
# shellcheck disable=SC1090
. "$LIB"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# assert detect output is EMPTY (clean)
assert_clean() {
  local label="$1" out="$2"
  if [ -z "$out" ]; then pass "$label"; else fail "$label (expected clean, got: $(printf '%s' "$out" | tr '\n' '|'))"; fi
}
# assert detect output CONTAINS a substring
assert_has() {
  local label="$1" out="$2" want="$3"
  case "$out" in *"$want"*) pass "$label" ;; *) fail "$label (expected substr '$want', got: $(printf '%s' "$out" | tr '\n' '|'))" ;; esac
}

# ── Fixture builders ────────────────────────────────────────────────────────
mk_inventory() { # <path> <row-lines...>  (row id is col 1)
  local path="$1"; shift
  mkdir -p "$(dirname "$path")"
  {
    printf '## Sub-flow inventory\n\n| Sub-flow ID | Title | Status |\n|---|---|---|\n'
    for row in "$@"; do printf '%s\n' "$row"; done
  } > "$path"
}
mk_doc() { # <flows-dir> <domain> <file> <flow-id>
  mkdir -p "$1/$2"
  printf -- '---\nfda_sub_flow_id: %s\ntitle: t\n---\n# t\n' "$4" > "$1/$2/$3.md"
}

section "1/2" "A-8 inventory ↔ doc consistency"

# good: 2 kebab rows, 2 matching docs
mk_inventory "$TMP/good/docs/product/master-flow-inventory.md" \
  '| `demo/flow-one` | One | ✓ |' '| `demo/flow-two` | Two | ✓ |'
mk_doc "$TMP/good/docs/product/flows" demo flow-one demo/flow-one
mk_doc "$TMP/good/docs/product/flows" demo flow-two demo/flow-two
assert_clean "good: matched inventory+docs → clean" \
  "$(detect_inventory_consistency "$TMP/good/docs/product/master-flow-inventory.md" "$TMP/good/docs/product/flows")"

# orphan-doc: doc flow-two has no inventory row
mk_inventory "$TMP/od/docs/product/master-flow-inventory.md" '| `demo/flow-one` | One | ✓ |'
mk_doc "$TMP/od/docs/product/flows" demo flow-one demo/flow-one
mk_doc "$TMP/od/docs/product/flows" demo flow-two demo/flow-two
assert_has "orphan-doc: doc with no inventory row flagged" \
  "$(detect_inventory_consistency "$TMP/od/docs/product/master-flow-inventory.md" "$TMP/od/docs/product/flows")" \
  "story-doc flow-ID 'demo/flow-two' has no matching inventory row"

# orphan-row: inventory row flow-two has no doc
mk_inventory "$TMP/or/docs/product/master-flow-inventory.md" \
  '| `demo/flow-one` | One | ✓ |' '| `demo/flow-two` | Two | ✓ |'
mk_doc "$TMP/or/docs/product/flows" demo flow-one demo/flow-one
assert_has "orphan-row: inventory row with no doc flagged" \
  "$(detect_inventory_consistency "$TMP/or/docs/product/master-flow-inventory.md" "$TMP/or/docs/product/flows")" \
  "inventory flow-ID 'demo/flow-two' has no matching story doc"

# mixed-scheme: one kebab + one UPPERCASE row
mk_inventory "$TMP/ms/docs/product/master-flow-inventory.md" \
  '| `demo/flow-one` | One | ✓ |' '| DEMO-02 | Two | ✓ |'
mk_doc "$TMP/ms/docs/product/flows" demo flow-one demo/flow-one
printf -- '---\nflow_id: DEMO-02\n---\n# t\n' > "$TMP/ms/docs/product/flows/demo/DEMO-02.md"
assert_has "mixed-scheme: UPPERCASE + kebab in one inventory flagged" \
  "$(detect_inventory_consistency "$TMP/ms/docs/product/master-flow-inventory.md" "$TMP/ms/docs/product/flows")" \
  "mixes flow-ID schemes"

# body-flow_id-ignored: a flow_id: line in the BODY (e.g. a fenced yaml example)
# must NOT count as a declared flow-ID — only the leading front-matter block does.
# Without the front-matter scoping, demo/ghost below would be a phantom orphan-doc.
mk_inventory "$TMP/bf/docs/product/master-flow-inventory.md" '| `demo/flow-one` | One | ✓ |'
mkdir -p "$TMP/bf/docs/product/flows/demo"
cat > "$TMP/bf/docs/product/flows/demo/flow-one.md" <<'BFDOC'
---
flow_id: demo/flow-one
title: t
---
# t

```yaml
flow_id: demo/ghost
```
BFDOC
assert_clean "body flow_id in a fenced block is ignored (front-matter scoped)" \
  "$(detect_inventory_consistency "$TMP/bf/docs/product/master-flow-inventory.md" "$TMP/bf/docs/product/flows")"

section "2/2" "A-9 flow-ID immutability (diff-aware)"

mk_inventory "$TMP/old.md" '| FOO-01 | a | |' '| FOO-02 | b | |' '| BAR-01 | c | |'
# clean: new keeps all old + adds FOO-03
mk_inventory "$TMP/new_clean.md" '| FOO-01 | a | |' '| FOO-02 | b | |' '| BAR-01 | c | |' '| FOO-03 | d | |'
assert_clean "immutability: superset (added flow) → clean" \
  "$(detect_flowid_immutability "$TMP/old.md" "$TMP/new_clean.md")"
# breach: FOO-02 removed
mk_inventory "$TMP/new_removed.md" '| FOO-01 | a | |' '| BAR-01 | c | |'
assert_has "immutability: removed flow-ID flagged" \
  "$(detect_flowid_immutability "$TMP/old.md" "$TMP/new_removed.md")" \
  "flow-ID 'FOO-02' was removed/renamed"
# split allowed: FOO-02 -> FOO-02a / FOO-02b
mk_inventory "$TMP/new_split.md" '| FOO-01 | a | |' '| FOO-02a | b1 | |' '| FOO-02b | b2 | |' '| BAR-01 | c | |'
assert_clean "immutability: split (FOO-02 → FOO-02a/FOO-02b) → clean" \
  "$(detect_flowid_immutability "$TMP/old.md" "$TMP/new_split.md")"
# deprecated allowed: FOO-02 kept (ID still present, tagged)
mk_inventory "$TMP/new_dep.md" '| FOO-01 | a | |' '| FOO-02 | b [DEPRECATED] | |' '| BAR-01 | c | |'
assert_clean "immutability: deprecated-but-present ID → clean" \
  "$(detect_flowid_immutability "$TMP/old.md" "$TMP/new_dep.md")"

printf '\nflow-inventory-lint v-slice summary: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
printf 'RESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
