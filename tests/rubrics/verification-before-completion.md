---
skill: verification-before-completion
version: "1.0"
pass_threshold: 3.0
dimensions:
  - name: clarity
    threshold: 4
  - name: completeness
    threshold: 4
  - name: actionability
    threshold: 4
  - name: adherence
    threshold: 3
---

# Verification Before Completion Rubric

## Clarity (1-5)

Is the output well-organized, easy to follow, and free of confusion?

| Score | Anchor |
|-------|--------|
| 1 | Incoherent — verification results jumbled, no level structure, impossible to determine pass/fail |
| 2 | Partially organized but level results unclear or failure details missing |
| 3 | Acceptable structure — levels reported but specific criterion results could be clearer |
| 4 | Well-organized with clear level-by-level reporting, pass/fail per criterion, failure details present |
| 5 | Exemplary — each level narrated, every criterion individually checked, failure diagnostics precise, zero ambiguity about verification status |

## Completeness (1-5)

Does the output cover all required aspects of the verification task?

| Score | Anchor |
|-------|--------|
| 1 | Major gaps — most verification levels skipped, no actual commands run |
| 2 | Some levels checked but significant omissions (e.g., skips acceptance criteria or integration check) |
| 3 | Covers basics — build and tests run but acceptance criteria or integration verification incomplete |
| 4 | Thorough — all 4 levels verified with specific criterion checks |
| 5 | Comprehensive — all 4 levels verified with task-specific strategies (bug fix/feature/refactor), test genuineness checked, edge cases covered |

### Skill-Specific Completeness Criteria

- Level 1 (Build): build command succeeds, typecheck passes, lint passes with zero errors
- Level 2 (Test): full test suite passes, new tests exist for task changes, tests are meaningful (not just "code runs"), no skipped tests for current task
- Level 2 test genuineness: verifies test fails if implementation reverted, covers acceptance criteria, covers plan edge cases
- Level 3 (Acceptance): each criterion from Linear issue individually checked and marked (verified/not verified with evidence)
- Level 4 (Integration): no regression in pre-existing tests, no unrelated side effects, API consumer updates verified, schema migrations verified
- Task-specific strategy applied: bug fix (reproduction steps, regression test), feature (user flow, empty/error states), refactor (behavior identical, performance preserved)

## Actionability (1-5)

Is the verification report clear about pass/fail?

| Score | Anchor |
|-------|--------|
| 1 | No clear verdict — report is vague narrative with no definitive pass/fail |
| 2 | Verdict stated but missing failure details or next steps for blocked items |
| 3 | Pass/fail clear but specific criterion failures lack diagnostic detail |
| 4 | Clear verdict with per-level and per-criterion pass/fail, failure details include expected vs actual |
| 5 | Immediately actionable — precise pass/fail per criterion, failure diagnostics include root cause and recommended fix, PASS/BLOCKED report follows exact template |

## Adherence to Instructions (1-5)

Does the output follow the verification-before-completion skill's defined protocol?

| Score | Anchor |
|-------|--------|
| 1 | Ignores protocol entirely — declares success without running commands. Anti-slop violations (R1 premature completion, R2 skipped levels) |
| 2 | Follows some protocol but skips major verification levels or declares completion despite FAIL/BLOCKED status |
| 3 | Follows general protocol but misses specific requirements (e.g., test genuineness check, max retries) |
| 4 | Follows all major levels with minor deviations |
| 5 | Strict compliance — all 4 levels, all failure handling, all reporting rules followed |

### Skill-Specific Instruction Criteria

- Prints activation banner with trigger reason
- Follows 4-level structure: Build Verification, Test Verification, Acceptance Criteria, Integration Verification
- Narrates level progress (e.g., `Level 2/4: Test verification... PASS`)
- Level 1 failure stops verification immediately (does not proceed to Level 2)
- Runs actual commands and checks actual output (never trusts "it should work")
- Test genuineness verified: test fails on reverted implementation, covers acceptance criteria, covers edge cases
- Acceptance criteria checked individually with evidence (test reference or command output)
- Failure handling: documents what failed (level, criterion, expected, actual), analyzes root cause before retry
- Max 3 retries before error recovery (retry/skip/stop options via AskUserQuestion)
- Does not retry blindly — logs decision with root cause analysis and alternatives
- Completion report follows exact PASS or BLOCKED template format
- PASS report includes: Build status, test counts (passing/failing/new), acceptance criteria count, integration status
- BLOCKED report includes: passing levels, failing level and criterion, details, recommendation
- Applies task-specific verification strategy for bug fixes, new features, and refactors
- Flags missing test suite as risk without blocking
- Flags slow verification (>2 minutes) as project improvement needed

### Anti-Slop Criteria

<!-- Cap is 2 (stricter than the default 3) because verification is the final quality gate.
     Premature completion or skipped levels are higher-severity anti-patterns. -->
Guardrail violations cap Adherence score at 2 (see `docs/quality-guardrails.md`):

- **R1**: Premature completion — declaring task complete or printing completion marker when verification shows FAIL or BLOCKED
- **R2**: Skipped verification levels — jumping from Level 1 to Level 3 or skipping Level 4 entirely
