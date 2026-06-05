#!/usr/bin/env bash
# Regenerate docs/product/flows/INDEX.md from story-doc front-matter.
# Pass --check to exit non-zero (without writing) if INDEX.md is out of date.
# Provenance: shipped by `flow-architecture` plugin templates (BC-11029).
set -euo pipefail
exec npx tsx "$(dirname "$0")/regenerate-flow-index.mts" "$@"
