#!/usr/bin/env bash
set -euo pipefail

# ── Pre-Commit Quality Hook ──────────────────────────────────────────
# Runs linters on staged files by project type.
#
# Install as a git hook:
#   cp scripts/pre-commit.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Or reference from husky/lefthook configs.
# ─────────────────────────────────────────────────────────────────────

errors=0

# ── Get staged files ────────────────────────────────────────────────
# `staged_files` excludes deletions because the linter sections (ESLint /
# tsc / Ruff below) cannot lint files that no longer exist on disk.
# `all_changed_files` includes deletions and is used by the plugin-version-
# bump enforcement section — per BC-6000, REMOVING a plugin runtime file is
# also a content change that requires a version bump so clients' caches
# invalidate.
staged_files=()
while IFS= read -r f; do
  [ -n "$f" ] && staged_files+=("$f")
done < <(git diff --cached --name-only --diff-filter=d 2>/dev/null || true)

all_changed_files=()
while IFS= read -r f; do
  [ -n "$f" ] && all_changed_files+=("$f")
done < <(git diff --cached --name-only 2>/dev/null || true)

if [ "${#all_changed_files[@]}" -eq 0 ]; then
  exit 0
fi

# ── Detect project type ──────────────────────────────────────────────
is_js=false
is_python=false

[ -f "package.json" ] && is_js=true
{ [ -f "pyproject.toml" ] || [ -f "setup.py" ]; } && is_python=true

# ── JS/TS linting ────────────────────────────────────────────────────
if [ "$is_js" = true ]; then
  # Filter staged JS/TS files
  js_files=()
  for f in "${staged_files[@]}"; do
    case "$f" in
      *.js|*.jsx|*.ts|*.tsx) js_files+=("$f") ;;
    esac
  done

  if [ "${#js_files[@]}" -gt 0 ]; then
    # ESLint
    if command -v npx >/dev/null 2>&1 && npx --no-install eslint --version >/dev/null 2>&1; then
      echo "Running ESLint on staged files..."
      if ! npx --no-install eslint --no-error-on-unmatched-pattern -- "${js_files[@]}"; then
        echo ""
        echo "ESLint found issues. Fix with: npx eslint --fix <file>"
        errors=$((errors + 1))
      fi
    fi

    # TypeScript type checking
    # Note: tsc --noEmit checks the entire project (per tsconfig.json), not just staged files.
    # Pre-existing type errors in unstaged files will also block the commit.
    if [ -f "tsconfig.json" ] && command -v npx >/dev/null 2>&1 && npx --no-install tsc --version >/dev/null 2>&1; then
      echo "Running tsc --noEmit..."
      if ! npx --no-install tsc --noEmit; then
        echo ""
        echo "TypeScript found type errors."
        errors=$((errors + 1))
      fi
    fi
  fi
fi

# ── Python linting ───────────────────────────────────────────────────
if [ "$is_python" = true ]; then
  py_files=()
  for f in "${staged_files[@]}"; do
    case "$f" in
      *.py) py_files+=("$f") ;;
    esac
  done

  if [ "${#py_files[@]}" -gt 0 ]; then
    if command -v ruff >/dev/null 2>&1; then
      echo "Running Ruff on staged files..."
      if ! ruff check -- "${py_files[@]}"; then
        echo ""
        echo "Ruff found issues. Fix with: ruff check --fix <file>"
        errors=$((errors + 1))
      fi
    fi
  fi
fi

# ── Plugin Version Bump Enforcement (BC-8712 Step 7 / BC-6000 precedent) ─
# Any staged change under plugins/<name>/{commands,skills,hooks,agents}/**
# REQUIRES a version bump in BOTH plugins/<name>/.claude-plugin/plugin.json
# AND the matching entry in .claude-plugin/marketplace.json — same commit.
# Clients' plugin cache is keyed by version; without the bump, every client
# serves stale content. Costly precedent: BC-6000 lost 4+ ship sessions.

affected_plugins=()
# Iterate `all_changed_files` (not `staged_files`) because deletions of
# plugin runtime files also require a bump (BC-6000 — plugin cache is keyed
# by version; without a bump, clients serve cached now-deleted content).
# Regex anchors the second path segment to a single name (no slashes), so
# only plugins/<name>/{commands,skills,hooks,agents}/... at the canonical
# depth triggers — NOT nested matches like plugins/<name>/tests/hooks/...
# (pytest fixtures) or plugins/<name>/shared/hooks/... (non-runtime docs).
for f in "${all_changed_files[@]}"; do
  if [[ "$f" =~ ^plugins/[^/]+/(commands|skills|hooks|agents)/ ]]; then
    pname=$(printf '%s' "$f" | cut -d/ -f2)
    already=false
    if [ "${#affected_plugins[@]}" -gt 0 ]; then
      for p in "${affected_plugins[@]}"; do
        if [ "$p" = "$pname" ]; then
          already=true
          break
        fi
      done
    fi
    [ "$already" = false ] && affected_plugins+=("$pname")
  fi
done

if [ "${#affected_plugins[@]}" -gt 0 ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo ""
    echo "WARN: python3 not found — plugin-version-bump check skipped."
    echo "      Manually verify plugin.json + marketplace.json versions bumped"
    echo "      for: ${affected_plugins[*]} (per CLAUDE.md plugin-cache gotcha)."
  else
    for pname in "${affected_plugins[@]}"; do
      pj="plugins/$pname/.claude-plugin/plugin.json"
      mp=".claude-plugin/marketplace.json"

      pj_staged=false
      mp_staged=false
      for f in "${staged_files[@]}"; do
        [ "$f" = "$pj" ] && pj_staged=true
        [ "$f" = "$mp" ] && mp_staged=true
      done

      if [ "$pj_staged" = false ]; then
        echo ""
        echo "Plugin '$pname' content staged but $pj is not staged."
        echo "  Bump plugin.json version per CLAUDE.md plugin-cache gotcha (BC-6000)."
        errors=$((errors + 1))
        continue
      fi

      # Compare HEAD version to staged version (JSON-aware — handles single-line JSON)
      pj_head_ver=$(git show "HEAD:$pj" 2>/dev/null | python3 -c \
        'import json,sys
try: print(json.load(sys.stdin).get("version",""))
except Exception: pass' 2>/dev/null || true)
      pj_staged_ver=$(git show ":$pj" 2>/dev/null | python3 -c \
        'import json,sys
try: print(json.load(sys.stdin).get("version",""))
except Exception: pass' 2>/dev/null || true)

      # Fail-closed when the staged file is unparseable — without this, a
      # malformed plugin.json yields pj_staged_ver="" and the equality check
      # below short-circuits, letting corrupt JSON commit through with no
      # enforced bump (silent-bypass surfaced by /workflows:review on PR #318).
      if [ -z "$pj_staged_ver" ]; then
        echo ""
        echo "Plugin '$pname' content staged but $pj has an unparseable or missing version (malformed JSON?)."
        echo "  Fix the file and bump the version field per CLAUDE.md plugin-cache gotcha (BC-6000)."
        errors=$((errors + 1))
        continue
      fi

      if [ -n "$pj_head_ver" ] && [ "$pj_head_ver" = "$pj_staged_ver" ]; then
        echo ""
        echo "Plugin '$pname' content staged but $pj version is unchanged ($pj_head_ver)."
        echo "  Bump the version field per CLAUDE.md plugin-cache gotcha (BC-6000)."
        errors=$((errors + 1))
      fi

      if [ "$mp_staged" = false ]; then
        echo ""
        echo "Plugin '$pname' content staged but $mp is not staged."
        echo "  Bump the matching marketplace.json entry to keep versions consistent."
        errors=$((errors + 1))
        continue
      fi

      mp_head_ver=$(git show "HEAD:$mp" 2>/dev/null | PNAME="$pname" python3 -c \
        'import json,os,sys
try:
    target=os.environ["PNAME"]
    for p in json.load(sys.stdin).get("plugins",[]):
        if p.get("name")==target: print(p.get("version","")); break
except Exception: pass' 2>/dev/null || true)
      mp_staged_ver=$(git show ":$mp" 2>/dev/null | PNAME="$pname" python3 -c \
        'import json,os,sys
try:
    target=os.environ["PNAME"]
    for p in json.load(sys.stdin).get("plugins",[]):
        if p.get("name")==target: print(p.get("version","")); break
except Exception: pass' 2>/dev/null || true)

      # Fail-closed when the marketplace entry for this plugin can't be parsed
      # or doesn't exist in the staged file. Same silent-bypass guard as above.
      if [ -z "$mp_staged_ver" ]; then
        echo ""
        echo "Plugin '$pname' content staged but $mp has no parseable version entry for '$pname' (malformed JSON or missing entry?)."
        echo "  Add/repair the matching plugins[].version entry per CLAUDE.md plugin-cache gotcha (BC-6000)."
        errors=$((errors + 1))
        continue
      fi

      if [ -n "$mp_head_ver" ] && [ "$mp_head_ver" = "$mp_staged_ver" ]; then
        echo ""
        echo "Plugin '$pname' content staged but $mp version for '$pname' is unchanged ($mp_head_ver)."
        echo "  Bump the matching plugins[].version entry per CLAUDE.md plugin-cache gotcha (BC-6000)."
        errors=$((errors + 1))
      fi

      # Versions changed but to different values would be a separate consistency
      # issue — validate.sh Section 2b catches per-plugin version mismatch on
      # the post-commit tree.
    done
  fi
fi

# ── Result ───────────────────────────────────────────────────────────
if [ "$errors" -gt 0 ]; then
  echo ""
  echo "Pre-commit checks failed. Fix the issues above before committing."
  exit 1
fi

exit 0
