#!/usr/bin/env bash
# WS-A evidence-reality linter (BC-12692) — runs the inventory ↔ story-doc
# consistency lint (scripts/lib/flow_evidence_lint.py) over a consumer repo.
#
# Usage:
#   flow-evidence-lint.sh <repo-root>
#
# Reads <repo-root>/docs/product/master-flow-inventory.md and the story docs
# under <repo-root>/docs/product/flows. Checks, per inventory row:
#   (a) the status glyph (✓/⚠/✗; ? exempt) agrees with the linked story doc's
#       canonical `status:` (off-canon status defers to flow_doc_lint BAD_STATUS);
#   (b) every strict-`src/…{.ts,.tsx,.js,.jsx}` evidence anchor resolves on disk
#       (brace-expanded + glob-aware; high-precision / best-effort).
# Prints one `FAIL <check> <flow_id> <detail>` line per violation; exit 1 if any.
#
# This is a standalone TRUTH surface (like flow-frontmatter-lint.sh) — reports
# drift regardless of repo config, so it can go red anywhere without halting a
# ship. Bash 3.2 compatible. Stdlib python3 only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/flow_evidence_lint.py"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }
[ -f "$LIB" ] || { echo "FATAL: lib not found at $LIB" >&2; exit 2; }

repo="${1:-}"
if [ -z "$repo" ] || [ ! -d "$repo" ]; then
  echo "usage: flow-evidence-lint.sh <repo-root>" >&2
  exit 2
fi

python3 "$LIB" "$repo"
