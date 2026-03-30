#!/usr/bin/env bash
set -euo pipefail

# ── Release automation for Brite Claude Plugins ──────────────────────
# Usage: scripts/release.sh <major|minor|patch> [release-name]
#
# Bumps VERSION, plugin.json, marketplace.json, updates CHANGELOG,
# commits, and creates a git tag. Does NOT push.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

# ── Helpers ───────────────────────────────────────────────────────────
pass()  { printf "  \033[32m✓\033[0m  %s\n" "$1"; }
fail()  { printf "  \033[31m✗\033[0m  %s\n" "$1" >&2; exit 1; }
info()  { printf "  \033[34m→\033[0m  %s\n" "$1"; }

# ── Usage ─────────────────────────────────────────────────────────────
if [ $# -lt 1 ] || [[ ! "$1" =~ ^(major|minor|patch)$ ]]; then
  echo "Usage: scripts/release.sh <major|minor|patch> [release-name]"
  echo ""
  echo "Examples:"
  echo "  scripts/release.sh minor \"Plugin Ecosystem Foundation\""
  echo "  scripts/release.sh patch"
  exit 1
fi

BUMP_TYPE="$1"
RELEASE_NAME="${2:-}"

# Validate release name — reject shell metacharacters that corrupt commit messages
if [[ -n "$RELEASE_NAME" ]]; then
  if [[ "$RELEASE_NAME" =~ [\$\`\\] ]] || [[ "$RELEASE_NAME" =~ [[:cntrl:]] ]]; then
    fail "Release name contains unsafe characters (\$, \`, \\, or control chars)"
  fi
  if [[ ${#RELEASE_NAME} -gt 100 ]]; then
    fail "Release name exceeds 100 characters"
  fi
fi

# ── Pre-flight checks ────────────────────────────────────────────────
echo ""
echo "Pre-flight checks"
echo "─────────────────"

# Clean working tree
if ! git diff --quiet || ! git diff --cached --quiet; then
  fail "Working tree is dirty. Commit or stash changes first."
fi
pass "Working tree clean"

# On main branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
  fail "Must be on main branch (currently on: $BRANCH)"
fi
pass "On main branch"

# VERSION file exists
if [ ! -f "$VERSION_FILE" ]; then
  fail "VERSION file not found at $VERSION_FILE"
fi
pass "VERSION file exists"

# Read current version
CURRENT_VERSION=$(head -1 "$VERSION_FILE")
CURRENT_NAME=$(sed -n '2p' "$VERSION_FILE")
CURRENT_NAME="${CURRENT_NAME:-Unnamed}"

if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "Invalid version format in VERSION: $CURRENT_VERSION"
fi
pass "Current version: $CURRENT_VERSION"

# Cache plugin.json paths (reused for version check, update, and git add)
mapfile -t PLUGIN_JSONS < <(find "$REPO_ROOT/plugins" -name "plugin.json" -path "*/.claude-plugin/*")

# Check version consistency across files (single python3 call)
version_check=$(python3 - "$MARKETPLACE" "$CURRENT_VERSION" "${PLUGIN_JSONS[@]}" <<'PYEOF'
import json, sys

marketplace_path = sys.argv[1]
expected = sys.argv[2]
plugin_paths = sys.argv[3:]
errors = []

with open(marketplace_path) as f:
    mp_ver = json.load(f)['plugins'][0].get('version', '')
if mp_ver != expected:
    errors.append(f'marketplace.json={mp_ver}')

for path in plugin_paths:
    with open(path) as f:
        pj_ver = json.load(f).get('version', '')
    if pj_ver and pj_ver != expected:
        errors.append(f'{path}={pj_ver}')

if errors:
    print('MISMATCH:' + ', '.join(errors))
else:
    print('OK')
PYEOF
)

if [[ "$version_check" == MISMATCH:* ]]; then
  fail "Version mismatch: VERSION=$CURRENT_VERSION ${version_check#MISMATCH:}"
fi
pass "Versions consistent across all files"

# Check [Unreleased] has content
UNRELEASED_CONTENT=$(sed -n '/^## \[Unreleased\]/,/^## \[/{/^## \[/d; /^$/d; p;}' "$CHANGELOG")
if [ -z "$UNRELEASED_CONTENT" ]; then
  printf "  \033[33m!\033[0m  [Unreleased] section is empty — changelog entry will be minimal\n"
fi

# ── Compute new version ──────────────────────────────────────────────
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
if [ -z "$RELEASE_NAME" ] && [ "$BUMP_TYPE" = "patch" ]; then
  NEW_NAME="Patch release"
else
  NEW_NAME="${RELEASE_NAME:-$CURRENT_NAME}"
fi
TODAY=$(date +%Y-%m-%d)

echo ""
echo "Release plan"
echo "────────────"
info "$CURRENT_VERSION → $NEW_VERSION"
info "Release name: $NEW_NAME"
info "Date: $TODAY"
echo ""

# ── Update VERSION ───────────────────────────────────────────────────
printf "%s\n%s\n" "$NEW_VERSION" "$NEW_NAME" > "$VERSION_FILE"
pass "Updated VERSION"

# ── Update marketplace.json + plugin.json files ─────────────────────
python3 - "$NEW_VERSION" "$MARKETPLACE" "${PLUGIN_JSONS[@]}" <<'PYEOF'
import json, sys

new_version = sys.argv[1]
marketplace_path = sys.argv[2]
plugin_paths = sys.argv[3:]

# Update marketplace.json
with open(marketplace_path, 'r') as f:
    data = json.load(f)
data['plugins'][0]['version'] = new_version
with open(marketplace_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

# Update each plugin.json
for path in plugin_paths:
    with open(path, 'r') as f:
        data = json.load(f)
    if 'version' in data:
        data['version'] = new_version
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
PYEOF
pass "Updated marketplace.json"
for pj in "${PLUGIN_JSONS[@]}"; do
  label="${pj#"$REPO_ROOT"/}"
  pass "Updated $label"
done

# ── Update CHANGELOG.md ──────────────────────────────────────────────
# Insert new version heading after [Unreleased], move content down
python3 - "$CHANGELOG" "$NEW_VERSION" "$TODAY" "$CURRENT_VERSION" <<'PYEOF'
import re, sys

changelog_path = sys.argv[1]
new_version = sys.argv[2]
today = sys.argv[3]
current_version = sys.argv[4]

with open(changelog_path, 'r') as f:
    content = f.read()

# Find the [Unreleased] heading and the next ## heading
pattern = r'(## \[Unreleased\])\n(.*?)(## \[)'
match = re.search(pattern, content, re.DOTALL)

if not match:
    print('ERROR: Could not find [Unreleased] section followed by a version heading in CHANGELOG', file=sys.stderr)
    sys.exit(1)

unreleased_heading = match.group(1)
unreleased_body = match.group(2)
next_heading_start = match.group(3)

# Build new content: empty Unreleased + new version with old content
replacement = (
    unreleased_heading + '\n\n'
    f'## [{new_version}] - {today}\n'
    + unreleased_body
    + next_heading_start
)
content = content[:match.start()] + replacement + content[match.end():]

# Update compare links
old_link = f'[Unreleased]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v{current_version}...HEAD'
if old_link not in content:
    print(f'ERROR: [Unreleased] compare link not found for v{current_version} in CHANGELOG', file=sys.stderr)
    sys.exit(1)

new_links = (
    f'[Unreleased]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v{new_version}...HEAD\n'
    f'[{new_version}]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v{current_version}...v{new_version}'
)
content = content.replace(old_link, new_links)

with open(changelog_path, 'w') as f:
    f.write(content)
PYEOF
pass "Updated CHANGELOG.md"

# ── Git commit & tag ─────────────────────────────────────────────────
git add "$VERSION_FILE" "$MARKETPLACE" "$CHANGELOG" "${PLUGIN_JSONS[@]}"

git commit -m "$(cat <<EOF
chore: release v$NEW_VERSION ($NEW_NAME)

Bump version $CURRENT_VERSION → $NEW_VERSION.
Move [Unreleased] changelog entries under [$NEW_VERSION].
EOF
)"
pass "Created commit"

git tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION — $NEW_NAME"
pass "Created tag v$NEW_VERSION"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
printf "  \033[1;32mRelease v%s complete\033[0m\n" "$NEW_VERSION"
echo "═══════════════════════════════════════"
echo ""
echo "  Version:  $CURRENT_VERSION → $NEW_VERSION"
echo "  Name:     $NEW_NAME"
echo "  Tag:      v$NEW_VERSION"
echo ""
echo "  Next steps:"
echo "    git push && git push --tags"
echo ""
