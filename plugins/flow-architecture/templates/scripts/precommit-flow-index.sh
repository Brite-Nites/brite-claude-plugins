#!/usr/bin/env bash
# Pre-commit helper: keep docs/product/flows/INDEX.md in sync automatically.
#
# When a commit stages anything that feeds the flow INDEX — a story doc under
# docs/product/flows/ OR docs/product/master-flow-inventory.md — this regenerates
# the INDEX and stages the result into the same commit, so the tree never drifts.
#
# Provenance: shipped by the `flow-architecture` plugin templates (BC-16783, Q60).
# Project-owned post-scaffold per Q29.7 (consumer-project ownership; plugin-sourced
# template). Edit freely — the scaffold will not overwrite it without --overwrite-scripts.
#
# Design contract (READ before editing):
#   * FAIL-OPEN, ALWAYS. Every failure path (no tsx, missing regenerator, a regen
#     error) warns and exits 0 — a hook must never block a commit for this. CI's
#     `verify-docs.sh` runs the SAME `regenerate-flow-index.sh --check` and is the
#     authoritative drift backstop, so a skipped local regen is caught downstream.
#   * DETERMINISTIC. It calls scripts/regenerate-flow-index.sh (fast, no LLM) — never
#     the agent-invoked regen skill.
#   * FULL TRIGGER SURFACE. The regenerator reads BOTH the flows/ story docs and
#     master-flow-inventory.md (domain order/headers), so both must trigger it.
#     INDEX.md / INDEX-archive.md / README.md are excluded to avoid self-retrigger.
#   * NO CHURN. The regenerator's last_reviewed is idempotent (unchanged body → same
#     date), so a no-op run rewrites identical bytes; the hash-guard below then skips
#     the `git add`, leaving no one-line timestamp diff.
#
# `set -u` catches unbound-var bugs; `set -e` is intentionally OMITTED so a failing
# guard cannot abort non-zero (that would defeat fail-open). Every step is guarded
# and the script ends on `exit 0`.
set -u

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" 2>/dev/null || exit 0

# All staged paths, INCLUDING deletions: a deleted story doc must still trigger a
# regen so its row is dropped from the INDEX — otherwise CI's verify-docs fails on
# the stale row for a delete-only commit. We only read the path list (never the file
# contents), so a deletion in the list is harmless.
staged=$(git diff --cached --name-only 2>/dev/null) || exit 0
[ -n "$staged" ] || exit 0

# Keep only INDEX-affecting inputs; drop the generated INDEX + non-indexed basenames
# (mirrors the regenerator's own skip-set) so editing the output can't self-trigger.
triggers=$(printf '%s\n' "$staged" \
  | grep -E '^docs/product/(master-flow-inventory\.md|flows/.+\.md)$' \
  | grep -vE '(^|/)(INDEX|INDEX-archive|README)\.md$') || true
[ -n "$triggers" ] || exit 0

# tsx guard — fail-open when the regenerator's runtime is not installed locally.
if ! npx --no-install tsx --version >/dev/null 2>&1; then
  echo "⚠ precommit-flow-index: tsx not available locally — skipping flow-INDEX auto-regen (CI verify-docs is the backstop)." >&2
  exit 0
fi

if [ ! -f scripts/regenerate-flow-index.sh ]; then
  echo "⚠ precommit-flow-index: scripts/regenerate-flow-index.sh not found — skipping flow-INDEX auto-regen." >&2
  exit 0
fi

before=$(git hash-object docs/product/flows/INDEX.md 2>/dev/null || echo absent)

# Fail-open on any regen error — CI's verify-docs --check will catch real drift.
if ! bash scripts/regenerate-flow-index.sh >/dev/null 2>&1; then
  echo "⚠ precommit-flow-index: flow-INDEX regeneration failed — committing anyway (CI verify-docs will catch any drift)." >&2
  exit 0
fi

after=$(git hash-object docs/product/flows/INDEX.md 2>/dev/null || echo absent)

# Only stage (and speak) when the INDEX actually changed — idempotent no-op stays silent.
if [ "$before" != "$after" ]; then
  git add docs/product/flows/INDEX.md 2>/dev/null || true
  echo "✓ precommit-flow-index: regenerated docs/product/flows/INDEX.md and staged it into this commit."
fi

exit 0
