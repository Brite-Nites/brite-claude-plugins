# verify-docs-ecosystem-integration fixture

Test fixture for the `/flow:retrofit-project` Phase 1 templates-scaffold integration test. Read by `plugins/flow-architecture/tests/run-verify-docs-ecosystem-integration-vslice.sh` (BC-11091).

The fixture is a minimal greenfield-shape project — `package.json` with no-op build/lint/test scripts, a single-domain inventory stub, and the documentation roots `verify-docs.sh` expects to find. The test driver copies this directory into a tmpdir before mutating it, so the in-repo fixture stays clean across runs.

See `plugins/flow-architecture/tests/run-verify-docs-ecosystem-integration-vslice.sh` for the assertion inventory and the recipe-extraction contract.
