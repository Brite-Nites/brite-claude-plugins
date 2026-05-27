#!/usr/bin/env bash
# Verify the docs tree is internally consistent.
# Checks: build/lint/test, internal links, orphan flow IDs, front-matter, flow INDEX drift, doc freshness, Linear references.
# Long-lived docs older than 90 days emit warnings (exit code unchanged).
# Run with --stale-only to print just the stale-doc list (for doc-steward audit).
# Run with --no-linear to skip the Linear reference check (offline / pre-commit).
#
# Provenance: shipped by `flow-architecture` plugin templates (BC-11029).
# Project-owned post-retrofit per Q29.7 + Q58 (consumer-project ownership; plugin-sourced template).
# Edit freely — the plugin will not overwrite this file on subsequent /flow:retrofit-project runs
# unless --overwrite-scripts is passed.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

stale_only=false
no_linear=false
for arg in "$@"; do
  case "$arg" in
    --stale-only) stale_only=true ;;
    --no-linear) no_linear=true ;;
  esac
done

ok=0
warn=0
fail=0
stale=0

if [ "$stale_only" = false ]; then
  echo "→ Build / lint / test"
  if npm run build >/dev/null 2>&1 && npm run lint >/dev/null 2>&1 && npm test >/dev/null 2>&1; then
    echo "  ✓ build, lint, test all pass"
    ok=$((ok + 1))
  else
    echo "  ✗ build, lint, or test failed — run them individually to see why"
    fail=$((fail + 1))
  fi

  echo ""
  echo "→ Internal link check (relative paths in markdown)"
  broken=0
  broken_lines=""
  # Generic cross-repo exclusion: skip links that reach into vendored / sibling-repo
  # paths (../something/) by default. Tighten this regex if your project keeps
  # documentation that legitimately cross-links into specific sibling repos.
  while IFS= read -r f; do
    # Extract ](path) links where path is not http(s), mailto, or anchor-only
    while IFS= read -r link; do
      [ -z "$link" ] && continue
      # Strip optional #anchor suffix
      target="${link%%#*}"
      [ -z "$target" ] && continue
      # Resolve absolute (/foo) vs relative (./foo, foo)
      if [[ "$target" == /* ]]; then
        resolved="$repo_root$target"
      else
        resolved="$(dirname "$f")/$target"
      fi
      if [ ! -e "$resolved" ]; then
        broken=$((broken + 1))
        broken_lines+="    $f → $link"$'\n'
      fi
    done < <(awk 'BEGIN{in_block=0} /^```/{in_block=!in_block; next} !in_block' "$f" 2>/dev/null | sed -E 's/`[^`]*`//g' | grep -oE '\]\([^)]+\)' 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | grep -vE "^(https?://|mailto:|#|/sandbox/|/api/|/_next/|\\.\\./)" || true)
  done < <(find docs CLAUDE.md README.md -name "*.md" -type f 2>/dev/null | grep -v "^docs/templates/" || true)
  if [ "$broken" -eq 0 ]; then
    echo "  ✓ no broken internal links"
    ok=$((ok + 1))
  else
    echo "  ✗ $broken broken internal links:"
    printf "%s" "$broken_lines"
    fail=$((fail + 1))
  fi

  echo ""
  echo "→ Orphan flow ID check"
  inv="docs/product/master-flow-inventory.md"
  if [ -f "$inv" ]; then
    defined=$(grep -ohE "^\| [A-Za-z][A-Za-z0-9]*(-[A-Za-z][A-Za-z0-9]*)*-[0-9]+[a-z]?" "$inv" | tr -d '| ' | sort -u || true)
    # Derive flow-ID prefix allowlist from inventory rows (the actual FDA domain
    # codes for this project). Strictly limit orphan-check matches to that set
    # so non-flow IDs (JTBD-N, NFR-N, FR-N, OQ-N, ADR-NNNN, CDR-NNN, RFC-NNN,
    # GH-NNN, Pillar-N, etc.) don't false-positive as orphans.
    prefixes=$(echo "$defined" | sed -E 's/-[0-9]+[a-z]?$//' | sort -u | grep -v '^$' | tr '\n' '|' | sed 's/|$//' || true)
    if [ -n "$prefixes" ]; then
      refd=$(grep -rohE "($prefixes)-[0-9]+[a-z]?" docs/product/flows/ docs/product/journeys/ docs/designs/ 2>/dev/null | sort -u || true)
    else
      refd=""
    fi
    orphans=$(comm -23 <(echo "$refd") <(echo "$defined") | grep -v '^$' || true)
    if [ -z "$orphans" ]; then
      echo "  ✓ all flow IDs referenced in flows/journeys/designs exist in inventory"
      ok=$((ok + 1))
    else
      echo "  ✗ flow IDs referenced but not in inventory:"
      echo "$orphans" | sed 's/^/    /'
      fail=$((fail + 1))
    fi
  else
    echo "  ⚠ $inv not present yet — skipping orphan check"
    warn=$((warn + 1))
  fi

  echo ""
  echo "→ Front-matter check (long-lived docs)"
  missing_fm=""
  for f in $(find docs/product/flows docs/product/journeys docs/product/personas docs/designs docs/decisions docs/runbooks -name "*.md" -type f 2>/dev/null | grep -v INDEX.md || true); do
    if ! head -1 "$f" 2>/dev/null | grep -q "^---$"; then
      missing_fm="$missing_fm  $f"$'\n'
    fi
  done
  if [ -z "$missing_fm" ]; then
    echo "  ✓ all long-lived docs have front-matter"
    ok=$((ok + 1))
  else
    echo "  ✗ missing front-matter:"
    printf "%s" "$missing_fm"
    fail=$((fail + 1))
  fi

  echo ""
  echo "→ Flow INDEX regenerator drift check"
  if bash scripts/regenerate-flow-index.sh --check >/dev/null 2>&1; then
    echo "  ✓ docs/product/flows/INDEX.md is up to date with story-doc front-matter"
    ok=$((ok + 1))
  else
    echo "  ✗ docs/product/flows/INDEX.md is out of date — run \`bash scripts/regenerate-flow-index.sh\` and commit"
    fail=$((fail + 1))
  fi

  echo ""
  echo "→ Doc freshness check (long-lived docs, 90-day threshold)"
fi

today_ts=$(date +%s)
# This loop runs in both modes; the --stale-only block below short-circuits
# before the summary so callers get just the warning lines.
for f in $(find docs/product/flows docs/product/journeys docs/product/personas docs/designs docs/decisions docs/runbooks -name "*.md" -type f 2>/dev/null | grep -v INDEX.md || true); do
  lr=$(grep -m1 -E '^last_reviewed:' "$f" 2>/dev/null | sed -E 's/^last_reviewed:[[:space:]]*//; s/[[:space:]].*$//; s/["'\'']//g' || true)
  if [ -z "$lr" ]; then
    continue
  fi
  doc_ts=$(date -j -f "%Y-%m-%d" "$lr" +%s 2>/dev/null || date -d "$lr" +%s 2>/dev/null || echo "")
  if [ -z "$doc_ts" ]; then
    continue
  fi
  # Compare timestamps directly for the future-date check — bash arithmetic
  # truncates toward zero, so a signed days_ago miscounts dates <24h ahead
  # on Linux (where `date -d "$lr"` resolves to midnight of $lr).
  if [ "$doc_ts" -gt "$today_ts" ]; then
    echo "  ⚠ $f has future last_reviewed: $lr"
    stale=$((stale + 1))
    continue
  fi
  days_ago=$(( (today_ts - doc_ts) / 86400 ))
  if [ "$days_ago" -gt 90 ]; then
    echo "  ⚠ $f last reviewed $lr ($days_ago days ago)"
    stale=$((stale + 1))
  fi
done

if [ "$stale_only" = true ]; then
  exit 0
fi

if [ "$stale" -eq 0 ]; then
  echo "  ✓ all long-lived docs reviewed within 90 days"
  ok=$((ok + 1))
else
  warn=$((warn + 1))
fi

echo ""
echo "→ Linear reference check"
# Skip is the documented offline default — print the message but do NOT
# increment the warn counter. The check is an opt-in extension, not a
# regression in its absence.
if [ "$no_linear" = true ]; then
  echo "  ⊝ Linear reference check skipped (--no-linear passed)"
elif [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "  ⊝ Linear reference check skipped (LINEAR_API_KEY unset — set it to enable)"
else
  if npx tsx scripts/verify-linear-references.mts; then
    echo "  ✓ Linear references resolve; parent-child wiring + labels consistent"
    ok=$((ok + 1))
  else
    echo "  ✗ Linear reference drift — see output above"
    fail=$((fail + 1))
  fi
fi

echo ""
echo "─────────────────────────────"
echo "  $ok passed · $warn warned · $fail failed · $stale stale (warning)"
echo "─────────────────────────────"

[ $fail -eq 0 ]
