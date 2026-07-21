#!/usr/bin/env bash
# Self-test for lint_workflow_pins.py (BC-16291 / audit plan 004). Synthetic
# fixtures lock the SHA-pin + npm-pin detection and rc discipline. Emits the
# `RESULT pass=N fail=M` line validate.sh §15a-bc-16291 parses; exits nonzero
# iff any assertion failed. bash 3.2-safe (no mapfile / no array expansion).
set -u

LINT="${1:-}"
if [ -z "$LINT" ]; then
  LINT="$(cd "$(dirname "$0")" && pwd)/lint_workflow_pins.py"
fi

pass=0
fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# $1 = label, $2 = expected rc, $3 = actual rc
check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s (expected rc=%s got rc=%s)\n' "$1" "$2" "$3" >&2
  fi
}

# Fixture A — fully pinned (SHA action + versioned npm global) → clean (rc 0)
mkdir -p "$tmp/good"
cat > "$tmp/good/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - run: npm install -g @salesforce/cli@2.141.6
YAML
python3 "$LINT" "$tmp/good" >/dev/null 2>&1
check "fully-pinned fixture passes" 0 "$?"

# Fixture B — unpinned action tag → violation (rc 1)
mkdir -p "$tmp/bad_uses"
cat > "$tmp/bad_uses/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - uses: actions/checkout@v4
YAML
python3 "$LINT" "$tmp/bad_uses" >/dev/null 2>&1
check "unpinned action tag fails" 1 "$?"

# Fixture C — unpinned npm global (scoped, no version) → violation (rc 1)
mkdir -p "$tmp/bad_npm"
cat > "$tmp/bad_npm/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - run: npm install -g @anthropic-ai/claude-code
YAML
python3 "$LINT" "$tmp/bad_npm" >/dev/null 2>&1
check "unpinned npm global fails" 1 "$?"

# Fixture D — commented-out unpinned line is ignored → clean (rc 0)
mkdir -p "$tmp/comment"
cat > "$tmp/comment/w.yml" <<'YAML'
jobs:
  a:
    steps:
      # - uses: actions/checkout@v4
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
YAML
python3 "$LINT" "$tmp/comment" >/dev/null 2>&1
check "commented unpinned line ignored" 0 "$?"

# Fixture E — dist-tag (@latest) is NOT an exact pin → violation (rc 1)
mkdir -p "$tmp/latest"
cat > "$tmp/latest/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - run: npm install -g typescript@latest
YAML
python3 "$LINT" "$tmp/latest" >/dev/null 2>&1
check "npm @latest dist-tag fails" 1 "$?"

# Fixture F — --global long flag + exact version → clean (rc 0)
mkdir -p "$tmp/global"
cat > "$tmp/global/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - run: npm install --global @salesforce/cli@2.141.6
YAML
python3 "$LINT" "$tmp/global" >/dev/null 2>&1
check "--global with exact version passes" 0 "$?"

# Fixture G — multi-package global install, 2nd package unpinned → violation (rc 1)
mkdir -p "$tmp/multi"
cat > "$tmp/multi/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - run: npm install -g @salesforce/cli@2.141.6 typescript
YAML
python3 "$LINT" "$tmp/multi" >/dev/null 2>&1
check "multi-package 2nd unpinned fails" 1 "$?"

# Fixture H — inline trailing comment mentioning an unpinned ref → clean (rc 0)
mkdir -p "$tmp/inline"
cat > "$tmp/inline/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - run: echo building   # e.g. npm install -g foo (not a real install)
YAML
python3 "$LINT" "$tmp/inline" >/dev/null 2>&1
check "inline trailing comment ignored" 0 "$?"

# Fixture I — semver range (@^5.0.0) is NOT an exact pin → violation (rc 1)
mkdir -p "$tmp/range"
cat > "$tmp/range/w.yml" <<'YAML'
jobs:
  a:
    steps:
      - run: npm install -g typescript@^5.0.0
YAML
python3 "$LINT" "$tmp/range" >/dev/null 2>&1
check "npm semver range fails" 1 "$?"

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
