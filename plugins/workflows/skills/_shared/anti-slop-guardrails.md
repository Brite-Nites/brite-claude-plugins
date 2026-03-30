## Anti-Slop Guardrails

Check your output against these anti-patterns before completing. Violations are Adherence scoring penalties in rubric evaluation. Full catalog: `docs/quality-guardrails.md`.

### Planning Phase (PL1-PL4)

- **PL1**: DO NOT use vague task descriptions ("implement the feature", "set up the module"). Every task needs exact file paths and concrete behavior.
- **PL2**: DO NOT create oversized tasks. Max 5 implementation steps, max 3 files per task.
- **PL3**: DO NOT omit file paths from tasks. Every task must reference specific files.
- **PL4**: DO NOT skip verification steps. Every task needs a `**Verify**:` section with a runnable command.

### Execution Phase (E1-E5)

- **E1**: DO NOT skip TDD. Write a failing test first (RED), then implement (GREEN), then clean up (REFACTOR).
- **E2**: DO NOT claim "it should work" without command output evidence. Run the actual command and show results.
- **E3**: DO NOT pollute subagent context. Each subagent gets only task-scoped context, not the full plan.
- **E4**: DO NOT skip execution traces. Emit `execution-trace-v1` YAML after each task checkpoint.
- **E5**: DO NOT retry blindly. Diagnose root cause before retrying a failed command.

### Review Phase (R1-R2)

- **R1**: DO NOT declare completion when verification shows FAIL or BLOCKED. Report the failure instead.
- **R2**: DO NOT skip verification levels. Run all 4 levels in order: build → test → acceptance → integration.

### Compound Phase (C1-C2)

- **C1**: DO NOT save ephemeral knowledge to CLAUDE.md. No session narrative, no generic advice, no temporary state.
- **C2**: DO NOT bloat CLAUDE.md past ~100 lines. Extract detailed sections to `docs/` with `@import`.
