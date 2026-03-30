# Anti-Slop Quality Guardrails

Explicit anti-patterns for skill outputs. Each pattern has an ID, description, and detection method. Skills reference these guardrails during execution; the rubric pipeline scores violations as Adherence penalties.

**Coverage**: Phase 1 covers the 5 inner-loop skills with the highest anti-slop risk: brainstorming, writing-plans, executing-plans, verification-before-completion, and compound-learnings. Remaining skills (git-worktrees, precedent-search, best-practices-audit, handbook-drift-check, systematic-debugging) will be evaluated for guardrail coverage in a future iteration.

**ID namespace**: Planning patterns use `PL` prefix (PL1-PL4) to avoid collision with P1/P2/P3 review severity levels. Execution (E1-E5), Review (R1-R2), and Compound (C1-C2) prefixes are unique and unchanged.

## How Guardrails Are Checked

**Layer 1 — Skill self-check**: Skills reference `_shared/anti-slop-guardrails.md` and self-check outputs against relevant patterns during execution. Cheapest layer; relies on LLM instruction-following.

**Layer 2 — Machine-checkable script**: `scripts/check-guardrails.sh` runs regex/heuristic checks on plan files and CLAUDE.md. The CLAUDE.md bloat check (C2) is wired into `scripts/validate.sh` (Section 15). Plan file checks are on-demand via the CLI: `bash scripts/check-guardrails.sh --plan <path>`.

**Layer 3 — Rubric integration**: Anti-slop criteria in each rubric's Adherence dimension. The LLM-as-judge scores violations that escape Layers 1-2 (e.g., skipped TDD, ephemeral knowledge in CLAUDE.md).

**Cap enforcement**: The "cap Adherence score at N" rule is LLM-instructional — the LLM judge reads the cap in the rubric anchor text and is expected to follow it. This is consistent with the entire rubric pipeline design (LLM-as-judge, not programmatic enforcement). Most skills cap at 3; verification-before-completion caps at 2 because it is the final quality gate — premature completion or skipped levels are higher-severity anti-patterns.

## Planning Anti-Patterns

| ID | Name | Detection | Skill Scope |
|----|------|-----------|-------------|
| PL1 | Vague task descriptions | Regex | writing-plans |
| PL2 | Oversized tasks | Heuristic | writing-plans |
| PL3 | Missing file paths | Regex | writing-plans |
| PL4 | Missing verification steps | Regex | writing-plans |

### PL1 — Vague Task Descriptions

Task body uses hedge phrases without specifying exact file paths, function signatures, or concrete behavior.

**Bad**: "Implement the authentication feature" / "Set up the module" / "Handle the error cases"

**Good**: "Add `verifyToken()` to `src/lib/auth.ts` that validates JWT expiry and returns `{ valid: boolean, userId: string }`"

**Check**: Regex for hedge phrases: `implement the`, `set up the`, `handle the`, `make it work`, `do the thing`, `add the logic`, `create the function`, `write the code`, `update the file`, `fix the issue` without an adjacent file path.

### PL2 — Oversized Tasks

Task has more than 5 implementation steps OR touches more than 3 files. Violates the writing-plans sizing rule: each task should be 2-5 minutes for a focused agent.

**Bad**: A task with 8 implementation steps spanning 5 files across 3 directories.

**Good**: A task with 3 implementation steps touching 2 files in 1 directory.

**Check**: Count lines matching `^\s*[0-9]+\.` between `**Implementation**:` markers. Count unique file paths in task body.

### PL3 — Missing File Paths

Task description lacks any file path (no `/` separator or `.ext` pattern). Every task must specify exact files — "find the relevant file" is not acceptable.

**Bad**: "Update the configuration to include the new setting"

**Good**: "Add `maxRetries: 3` to `plugins/workflows/.claude-plugin/plugin.json` under the `settings` key"

**Check**: Regex for file path patterns (`[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+` or `[a-zA-Z0-9_-]+\.[a-zA-Z]{1,5}`). Flag if none found in task body.

### PL4 — Missing Verification Steps

Task lacks a `Verify:` or `Test:` section with a runnable command. Every task needs automated verification — "visually inspect" is not acceptable.

**Bad**: "Check that it works correctly"

**Good**: "Verify: `bash scripts/validate.sh` passes with no new errors"

**Check**: Regex for `**Verify**:` or `**Test**:` section containing a command (backtick-wrapped or `bash`/`python3`/`node` prefix).

## Execution Anti-Patterns

| ID | Name | Detection | Skill Scope |
|----|------|-----------|-------------|
| E1 | Skipped TDD | LLM judge | executing-plans |
| E2 | "It should work" | Regex | executing-plans |
| E3 | Context pollution | LLM judge | executing-plans |
| E4 | Missing execution traces | Regex | executing-plans |
| E5 | Blind retry | Regex | executing-plans |

### E1 — Skipped TDD

Testable code committed without a red-green-refactor cycle. No failing test written before implementation.

**Bad**: Writing the implementation first, then adding a test that already passes.

**Good**: Writing a test that fails (RED), implementing the minimum code to pass (GREEN), then cleaning up (REFACTOR).

**Check**: LLM judge evaluates whether execution output shows the RED-GREEN-REFACTOR sequence.

### E2 — "It Should Work" Declarations

Claiming success without running actual commands. No command output or test results as evidence.

**Bad**: "This implementation should work correctly" / "The changes will handle all edge cases"

**Good**: Showing actual command output: `$ bash scripts/validate.sh` followed by PASS results.

**Check**: Regex for phrases: `should work`, `will work correctly`, `is correct`, `should handle`, `will handle` without adjacent code block containing command output.

### E3 — Context Pollution

Subagent receives the full plan, previous task results, or unrelated CLAUDE.md sections instead of task-scoped context. Each subagent should get only the context relevant to its specific task.

**Bad**: Passing the entire plan file and all previous execution traces to a subagent.

**Good**: Passing only the current task definition, relevant file paths, and the specific CLAUDE.md sections for that task's context type.

**Check**: LLM judge evaluates whether subagent context was appropriately scoped.

### E4 — Missing Execution Traces

Task checkpoint completed without emitting an `execution-trace-v1` YAML block. Every task must produce a trace for the compound-learnings skill to process.

**Bad**: Completing a task with only "Task done" and no structured trace.

**Good**: Emitting a YAML block with `task`, `agent`, `timestamp`, `context_used`, `decisions_made`, `files_changed`, `tests`, `verification` fields.

**Check**: Regex for `# execution-trace-v1` presence after each task checkpoint.

### E5 — Blind Retry Without Diagnosis

Retrying a failed command or test without analyzing the root cause first. The retry must be preceded by a decision about what went wrong and what to change.

**Bad**: Running the same failing command 3 times in a row.

**Good**: After failure, analyzing the error output, identifying the root cause, and then running a modified command.

**Check**: Regex for repeated identical commands without intervening analysis text containing `because`, `root cause`, `the error`, or `the issue`.

## Review Anti-Patterns

| ID | Name | Detection | Skill Scope |
|----|------|-----------|-------------|
| R1 | Premature completion | Regex | verification-before-completion |
| R2 | Skipped verification levels | Regex | verification-before-completion |

### R1 — Premature Completion

Declaring task complete or printing a completion marker when verification levels are incomplete or show FAIL/BLOCKED.

**Bad**: Printing "Task complete" when Level 2 (tests) shows 2 failures.

**Good**: Printing "BLOCKED at Level 2: 2 test failures" with root cause analysis and recommendation.

**Check**: Regex for completion markers (`complete`, `done`, `finished`) when preceding verification output contains `FAIL` or `BLOCKED`.

### R2 — Skipped Verification Levels

Jumping from Level 1 (build) directly to Level 3 (acceptance criteria), or skipping Level 4 (integration) entirely. All 4 levels must be checked in order.

**Bad**: "Build passes, acceptance criteria met" (skipped Level 2: tests and Level 4: integration).

**Good**: Sequential Level 1 → Level 2 → Level 3 → Level 4 with evidence at each level.

**Check**: Regex for level headers (`Level 1`, `Level 2`, `Level 3`, `Level 4`). Flag if any level is missing from the verification output.

## Compound Anti-Patterns

| ID | Name | Detection | Skill Scope |
|----|------|-----------|-------------|
| C1 | Ephemeral knowledge in CLAUDE.md | LLM judge | compound-learnings |
| C2 | CLAUDE.md bloat | Line count | compound-learnings |

### C1 — Ephemeral Knowledge in CLAUDE.md

Saving session-specific narrative, generic advice, or temporary state as durable knowledge. CLAUDE.md is for architecture decisions, conventions, gotchas, paths, commands, and integration patterns that persist across sessions.

**Bad**: "Today we refactored the auth module" / "The user prefers dark mode" / "Remember to check the tests"

**Good**: "Auth tokens are validated in `src/lib/auth.ts` using `verifyToken()` — JWT expiry check required" / Adding a convention: "All API routes must return `{ data, error }` shape"

**Check**: LLM judge evaluates whether new CLAUDE.md entries contain temporal language (`today`, `this session`, `just now`) or generic advice without project-specific context.

### C2 — CLAUDE.md Bloat

Adding entries without pruning stale ones, causing CLAUDE.md to exceed ~100 lines. Large CLAUDE.md files should extract detailed sections to `docs/` with `@import` references.

**Bad**: CLAUDE.md at 150 lines with inline architecture documentation.

**Good**: CLAUDE.md at 90 lines with `@import docs/architecture.md` for detailed sections.

**Check**: `wc -l CLAUDE.md` — warn if >100 lines, fail if >150 lines.
