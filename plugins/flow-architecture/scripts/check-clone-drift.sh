#!/usr/bin/env bash
set -euo pipefail

# ── FDA Clone-Drift Detection (BC-7060) ───────────────────────────────
# Promotes parking-lot #45 from manual-grep contract to automated CI guard.
#
# Three flow-architecture commands are clones of workflows v3.29.4
# (Cloned from workflows v3.29.4 on 2026-05-07 — session-start.md, review.md,
# ship.md). Each FDA clone header records an `Upstream-SHA:` blob SHA of the
# upstream file as it stood at clone time. This script re-resolves the
# upstream blob SHA from origin/main and compares.
#
# Outcomes per file:
#   match                                   → PASS
#   diff but ≤5 lines AND whitespace-only   → WARN (trivial)
#   diff and substantive                    → FAIL (exits 1)
#
# CI wiring: clone-drift-check job in .github/workflows/validate-plugin.yml
# runs with continue-on-error: true so substantive drift surfaces as a red
# advisory check without blocking merge.
#
# Upstream-ref override: set UPSTREAM_REF env var to override the default
# `origin/main` comparison target. Useful when the BC-7060 regression test
# (`tests/test-clone-drift.sh`) needs to exercise the classifier against a
# branch's HEAD blob (i.e., when a PR's intent is to modify the upstream file
# itself and origin/main is therefore stale).
# ──────────────────────────────────────────────────────────────────────

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

UPSTREAM_REF="${UPSTREAM_REF:-origin/main}"

errors=0
warnings=0
passes=0

pass()    { printf "  \033[32mPASS\033[0m  %s\n" "$1"; passes=$((passes + 1)); }
fail()    { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; errors=$((errors + 1)); }
warn()    { printf "  \033[33mWARN\033[0m  %s\n" "$1"; warnings=$((warnings + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# Matches the v1.0 cribbing scope of Q51/Q52/Q53.
# Cross-plugin reach into plugins/workflows/commands/ is sanctioned by the
# FDA → workflows dependency declared at plugins/flow-architecture/CLAUDE.md
# § Workflows plugin dependency. Adding a 4th clone in v1.1 stays inside the
# FDA plugin directory.
CLONES=(session-start review ship)
# Match the HTML comment opener, not the bare phrase — `ship.md`'s frontmatter
# description also contains "Cloned from workflows" (Q53 lock language). The
# AC grep `grep -q "Cloned from workflows" ...` on this script is satisfied by
# this comment's literal phrase.
HEADER_MARKER="<!-- Cloned from workflows"

section "FDA clone-drift check vs workflows (ref: ${UPSTREAM_REF})"

# Refresh origin/main so blob lookups resolve. Best-effort; CI checkout with
# fetch-depth: 0 already has it. Local runs without network keep working
# against the previously-fetched origin/main. Skip the fetch when the test
# harness overrides UPSTREAM_REF to a local ref like HEAD.
if [ "$UPSTREAM_REF" = "origin/main" ] && ! git rev-parse origin/main >/dev/null 2>&1; then
  git fetch --depth=1 origin main >/dev/null 2>&1 || true
fi

if ! git rev-parse "$UPSTREAM_REF" >/dev/null 2>&1; then
  fail "$UPSTREAM_REF not reachable; cannot resolve upstream blob SHAs"
  printf "\n\033[1msummary:\033[0m pass=%d warn=%d fail=%d\n" "$passes" "$warnings" "$errors"
  exit 1
fi

for name in "${CLONES[@]}"; do
  clone_path="plugins/flow-architecture/commands/${name}.md"
  upstream_path="plugins/workflows/commands/${name}.md"

  if [ ! -f "$clone_path" ]; then
    fail "${name}: clone file missing at $clone_path"
    continue
  fi

  # Anchor to line start so an embedded marker inside fenced code or prose
  # can't forge a header (drift-suppression hardening; the real clone headers
  # live at line 5 and start with `<!--`).
  header_line="$(grep -m1 -E "^${HEADER_MARKER}" "$clone_path" || true)"
  if [ -z "$header_line" ]; then
    fail "${name}: HTML-comment header missing marker '$HEADER_MARKER' in $clone_path"
    continue
  fi

  recorded_sha="$(printf '%s\n' "$header_line" | sed -nE 's/.*Upstream-SHA: ([0-9a-fA-F]{40}).*/\1/p')"
  if [ -z "$recorded_sha" ]; then
    fail "${name}: header missing parseable 'Upstream-SHA: <40-hex>' in $clone_path"
    continue
  fi
  # Normalize to lowercase — git always emits lowercase, but the regex above
  # tolerates uppercase for hand-edited headers. Without this, a case-different
  # but content-identical SHA would skip the match branch and fall into the
  # diff-classify branch with an empty numstat (false "could not compute diff").
  recorded_sha="$(printf '%s' "$recorded_sha" | tr 'A-Z' 'a-z')"

  current_sha="$(git rev-parse "${UPSTREAM_REF}:${upstream_path}" 2>/dev/null || true)"
  if [ -z "$current_sha" ]; then
    fail "${name}: upstream file missing on ${UPSTREAM_REF} at $upstream_path"
    continue
  fi

  if [ "$recorded_sha" = "$current_sha" ]; then
    pass "${name}: SHA match ($recorded_sha)"
    continue
  fi

  # Drift detected. Classify trivial vs substantive.
  # `--numstat` returns added/removed counts directly — avoids piping the full
  # diff into awk and dodges the `grep -c` exit-1-on-zero trap under `set -e`.
  numstat="$(git diff --numstat "$recorded_sha" "$current_sha" 2>/dev/null || true)"
  if [ -z "$numstat" ]; then
    fail "${name}: could not compute diff between blobs ${recorded_sha} and ${current_sha}"
    continue
  fi
  read -r added_lines removed_lines _rest <<< "$numstat"
  # Defensive: `--numstat` emits `-\t-\t<path>` for binary diffs. Markdown
  # files never trigger that, but `set -e` + arithmetic on `-` would crash
  # with `operand expected` — guard belt-and-suspenders.
  if ! [[ "$added_lines" =~ ^[0-9]+$ && "$removed_lines" =~ ^[0-9]+$ ]]; then
    fail "${name}: numstat returned non-numeric counts — added=${added_lines} removed=${removed_lines}"
    continue
  fi
  total_lines=$((added_lines + removed_lines))

  # Whitespace-only detection: `-w` ignores intra-line whitespace differences
  # (incl. tab-vs-space, trailing-space tweaks); `--ignore-blank-lines` ignores
  # added/removed blank lines. Together they classify any change made entirely
  # of whitespace as "ws_only=yes".
  ws_diff="$(git diff -w --ignore-blank-lines "$recorded_sha" "$current_sha" 2>/dev/null || true)"
  if [ -z "$ws_diff" ]; then
    ws_only="yes"
  else
    ws_only="no"
  fi

  if [ "$total_lines" -le 5 ] && [ "$ws_only" = "yes" ]; then
    warn "${name}: trivial drift — ${total_lines} lines (whitespace-only); recorded=${recorded_sha} current=${current_sha}"
  else
    fail "${name}: substantive drift — +${added_lines} −${removed_lines} (whitespace-only=${ws_only}); recorded=${recorded_sha} current=${current_sha}"
    printf "         run: git diff %s %s -- %s\n" "$recorded_sha" "$current_sha" "$upstream_path"
  fi
done

printf "\n\033[1msummary:\033[0m pass=%d warn=%d fail=%d\n" "$passes" "$warnings" "$errors"

if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
