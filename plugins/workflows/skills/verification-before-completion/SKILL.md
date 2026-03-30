---
name: verification-before-completion
description: Ensures tasks are genuinely resolved before marking them done. Activates at task checkpoints during plan execution — validates that fixes actually work, tests genuinely pass, and acceptance criteria are met. Prevents premature completion declarations.
user-invocable: false
---
<!-- AUTO-GENERATED from SKILL.md.tmpl — do not edit directly -->

# Verification Before Completion

You are verifying that a task is genuinely complete before it's marked as done. The goal is to prevent the common failure mode where an agent declares success while the problem still exists.

## When to Activate

- At every task checkpoint during plan execution
- Before marking a Linear issue as done
- After fixing a bug (verify the fix, not just that the code compiles)
- Before shipping — final pre-review verification

## Preconditions

This skill is invoked directly by `executing-plans` at each task checkpoint. No independent precondition checks are needed.

## Activation

After being invoked, print the activation banner (see `_shared/observability.md`):

```
---
**Verification Before Completion** activated
Trigger: Task checkpoint reached
Produces: 4-level verification report
---
```

## Verification Protocol

### Level 1: Build Verification

Narrate: `Level 1/4: Build verification...`

Minimum bar — the project compiles and runs:

1. **Build succeeds**: Run the build command, check for zero errors
2. **No type errors**: Run typecheck (`tsc --noEmit` or equivalent)
3. **Lint passes**: Run the linter with zero errors (warnings OK)

If Level 1 fails, the task is NOT complete. Stop and fix.

Narrate: `Level 1/4: Build verification... [PASS/FAIL]`

### Level 2: Test Verification

Narrate: `Level 2/4: Test verification...`

Tests prove the behavior works:

1. **All tests pass**: Run the full test suite, not just the new tests
2. **New tests exist**: The task's changes should have corresponding tests
3. **Tests are meaningful**: The tests actually verify the behavior, not just that the code runs
4. **No skipped tests**: `describe.skip` or `test.todo` for the current task's tests = not done

Verify tests are genuine by checking:
- Does the test fail if you revert the implementation change?
- Does the test cover the acceptance criteria from the issue?
- Does the test cover edge cases mentioned in the plan?

Narrate: `Level 2/4: Test verification... [PASS/FAIL]`

### Level 3: Acceptance Criteria

Narrate: `Level 3/4: Acceptance criteria...`

The issue's requirements are met:

1. **Read the acceptance criteria** from the Linear issue
2. **Check each criterion individually**:
   ```
   Acceptance Criteria:
   - [x] Users can log in with email/password — VERIFIED (test: auth.test.ts:24)
   - [x] Invalid credentials show error message — VERIFIED (test: auth.test.ts:38)
   - [ ] Rate limiting after 5 failed attempts — NOT VERIFIED (no test, no implementation found)
   ```
3. **If any criterion is unmet**: The task is NOT complete

Narrate: `Level 3/4: Acceptance criteria... [PASS/FAIL]`

### Level 4: Integration Verification

Narrate: `Level 4/4: Integration verification...`

The changes work in context:

1. **No regression**: Pre-existing tests still pass
2. **No side effects**: Changes don't break unrelated features
3. **API contracts**: If you changed an interface, all consumers are updated
4. **Data consistency**: If you changed a schema, migrations exist and work

## Verification Strategies

### For Bug Fixes
1. Confirm the original reproduction steps no longer trigger the bug
2. Confirm the regression test fails on the old code and passes on the new
3. Check for related bugs that might have the same root cause

### For New Features
1. Walk through the user flow end-to-end (mentally or via tests)
2. Check empty states, error states, edge cases
3. Verify the feature is discoverable and documented

### For Refactors
1. Behavior is identical before and after (tests prove this)
2. Performance is not degraded (if relevant)
3. The refactored code is actually cleaner (not just different)

Narrate: `Level 4/4: Integration verification... [PASS/FAIL]`

## Failure Handling

When verification fails:

1. **Document what failed**:
   ```
   VERIFICATION FAILED
   Level: [1/2/3/4]
   Criterion: [what was being checked]
   Expected: [what should happen]
   Actual: [what happened instead]
   ```

2. **Don't retry blindly** — Analyze why it failed first. Log the decision:
   > **Decision**: [Retry approach]
   > **Reason**: [root cause analysis]
   > **Alternatives**: [other fix strategies considered]
3. **Fix the root cause**, then re-verify from Level 1
4. **Max 3 retries** — After 3 failures, use error recovery (see `_shared/observability.md`). AskUserQuestion with options: "Retry from Level 1 with different approach / Skip this verification level / Stop and report for manual review."

## Completion Report

Only after all relevant levels pass:

```
## Verification: PASS

**Build**: Clean
**Tests**: [N] passing, 0 failing, [N] new
**Acceptance Criteria**: [N/N] met
**Integration**: No regressions

Task is genuinely complete.
```

Or if issues remain:

```
## Verification: BLOCKED

**Passing**: Levels 1-2
**Failing**: Level 3 — acceptance criterion [X] unmet
**Details**: [what's missing and why]
**Recommendation**: [what needs to happen next]

Task is NOT complete.
```

## Rules

- Never mark a task as done without running verification
- Never trust "it should work" — run the actual commands and check the actual output
- Tests passing is necessary but not sufficient — check acceptance criteria too
- If there's no test suite, flag it as a risk but don't block on it
- Verification should be fast — if it takes more than 2 minutes, the project's test/build setup needs improvement (flag this)
- Be honest about failures — a clearly reported failure is more valuable than a false success
- Check output against anti-slop guardrails (see `_shared/anti-slop-guardrails.md`). Relevant patterns: R1-R2 (premature completion, skipped verification levels). Violations cap Adherence score at 2 in rubric evaluation.
