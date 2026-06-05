# Fixture: verify-docs-ecosystem-integration

Minimal real-shape project used by `plugins/flow-architecture/tests/run-verify-docs-ecosystem-integration-vslice.sh` (BC-11091) to exercise the `/flow:retrofit-project` Phase 1 templates-scaffold recipe end-to-end.

This file exists so the fixture has a top-level `CLAUDE.md` for `verify-docs.sh`'s internal-link scan to find without erroring. It has no broken links and no project content — it is fixture infrastructure, not documentation.
