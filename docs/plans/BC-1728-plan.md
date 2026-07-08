# BC-1728: Update CI and docs for marketing plugin

## Summary

Extend quality infrastructure, CI pipeline, and documentation to support the marketing plugin alongside workflows. This is the integration point where all multi-plugin tooling proves it works.

## Research Findings

Scripts already multi-plugin ready: `validate.sh`, `gen-skill-docs.py`, `release.sh`, `test-contracts.sh` (by design).
Scripts needing updates: `telemetry-log.sh`, `test-behavioral.sh`, `test-skill-triggers.sh`, `probe-single-trigger.sh`, `validate-single.sh`.
Partially ready: CI workflow (`validate-plugin.yml`), `probe-plugin-load.sh`, `dev-validate.sh`.

## Tasks

### Task 1: Fix `telemetry-log.sh` for multi-plugin support
- **Files**: `scripts/telemetry-log.sh`
- **What**: Replace hardcoded `plugins/workflows/.claude-plugin/plugin.json` path with dynamic lookup that finds the first (or contextually relevant) plugin.json
- **How**: Use a glob pattern `plugins/*/.claude-plugin/plugin.json` or accept plugin name as parameter
- **Verify**: Run `bash scripts/telemetry-log.sh start test-cmd 2>/dev/null; echo $?` — should exit 0

### Task 2: Parameterize `test-behavioral.sh` for multi-plugin
- **Files**: `scripts/test-behavioral.sh`
- **What**: Replace hardcoded `PLUGIN_DIR="$REPO_ROOT/plugins/workflows"` with parameter or plugin discovery loop
- **How**: Accept optional `PLUGIN_DIR` argument; if none, iterate over all `plugins/*/`
- **Verify**: Run with `plugins/marketing/` as argument — should complete without error (0 evals found is OK)

### Task 3: Parameterize trigger test scripts for multi-plugin
- **Files**: `scripts/test-skill-triggers.sh`, `scripts/probe-single-trigger.sh`
- **What**: Replace hardcoded `plugins/workflows/skills/_shared/trigger-registry.json` with per-plugin discovery
- **How**: Accept plugin dir parameter or discover all `plugins/*/skills/_shared/trigger-registry.json`; skip plugins without a trigger registry gracefully
- **Verify**: Run script — should test workflows triggers and skip marketing (no trigger registry)

### Task 4: Fix remaining quality scripts for multi-plugin
- **Files**: `scripts/test-health-scores.sh`, `scripts/dev-validate.sh`, `scripts/validate-single.sh`, `scripts/test-scenarios.sh`, `scripts/probe-plugin-load.sh`
- **What**: Audit each for hardcoded `plugins/workflows/` paths. Fix where appropriate; leave as-is where workflows-specific is intentional (e.g., test-scenarios.sh tests project-start which is workflows-only)
- **How**: For each script, read → identify hardcoded paths → determine if multi-plugin or intentionally workflows-only → fix or add comment
- **Verify**: Each fixed script runs without error against the marketing plugin

### Task 5: Update CI workflow
- **Files**: `.github/workflows/validate-plugin.yml`
- **What**: Ensure updated scripts from tasks 1-4 are invoked correctly in CI
- **How**: Review each step; add plugin parameterization where scripts now support it; add comments for workflows-only steps
- **Verify**: Read final YAML; all steps should have clear scope (all plugins vs workflows-only)

### Task 6: Update CLAUDE.md Repository Structure
- **Files**: `CLAUDE.md`
- **What**: Generalize Repository Structure section to show multi-plugin pattern
- **How**: Change to show `plugins/<domain>/` pattern with both workflows and marketing examples
- **Verify**: Structure matches actual filesystem (`ls -R plugins/`)

### Task 7: Add LICENSE to marketing plugin
- **Files**: `plugins/marketing/LICENSE`
- **What**: Add MIT license with attribution to upstream source (coreyhaines31/marketingskills)
- **How**: Create LICENSE file matching the format used in `plugins/workflows/LICENSE`
- **Verify**: File exists with correct attribution

### Task 8: Document context-skill pattern in marketing README
- **Files**: `plugins/marketing/README.md`
- **What**: Add section explaining the `product-marketing-context` foundational skill pattern
- **How**: Reference BC-1966 context-skill standard; explain how domain skills depend on the context skill for enrichment
- **Verify**: README has dedicated "Context-Skill Pattern" section with clear explanation

### Task 9: Seed behavioral test cases for marketing
- **Files**: `tests/evals/` (new files)
- **What**: Add at least 3 seed eval definitions for marketing skills
- **How**: Create eval spec files following the format in `tests/fixtures/behavioral-registry.json`; target product-marketing-context, social-media-strategy, content-strategy
- **Verify**: `bash scripts/test-behavioral.sh plugins/marketing/` discovers the evals (may show 0 pass if Claude CLI not available — discovery is sufficient)

## Task Dependencies

```
Tasks 1, 2, 3, 4, 6, 7, 8 → independent (can run in parallel)
Task 5 (CI) → depends on 1, 2, 3, 4
Task 9 (seed evals) → depends on 2
```

## Acceptance Criteria Mapping

| AC | Task |
|----|------|
| validate.sh validates both plugins | Already works — verify in Task 4 |
| CI workflow passes with both plugins | Task 5 |
| CLAUDE.md reflects marketing plugin | Task 6 |
| Marketing README documents context-skill pattern | Task 8 |
| MIT license attribution present | Task 7 |
| test-contracts.sh validates marketing | N/A — contracts are workflows-only by design |
| test-behavioral.sh discovers marketing evals | Tasks 2 + 9 |
| Template generation covers marketing | Already works — gen-skill-docs.py uses glob |
| Health scoring covers marketing skills | Task 4 |
| Release script handles multi-plugin | Already works — verify in Task 4 |
| Telemetry and dev tooling work cross-plugin | Tasks 1 + 4 |
