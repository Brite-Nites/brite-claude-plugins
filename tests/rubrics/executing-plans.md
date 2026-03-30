---
skill: executing-plans
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

# Executing Plans Rubric

## Clarity (1-5)

Is the output well-organized, easy to follow, and free of confusion?

| Score | Anchor |
|-------|--------|
| 1 | Incoherent — task execution jumbled, no progress tracking, impossible to determine what was completed |
| 2 | Partially organized but checkpoint reports unclear or task boundaries hard to identify |
| 3 | Acceptable structure — tasks executed with some progress reporting but gaps in verification detail |
| 4 | Well-organized with clear task progress, checkpoint results, and execution traces per task |
| 5 | Exemplary — every task narrated, verification levels visible, execution traces complete, zero confusion about overall progress |

## Completeness (1-5)

Does the output cover all required aspects of the plan execution task?

| Score | Anchor |
|-------|--------|
| 1 | Major gaps — most tasks unexecuted, no verification, no traces emitted |
| 2 | Some tasks completed but significant omissions (e.g., no TDD, no checkpoints, missing traces) |
| 3 | Covers basics — tasks executed with tests but verification or trace emission incomplete |
| 4 | Thorough — all tasks executed with TDD, 4-level verification, and execution traces |
| 5 | Comprehensive — full execution with parallel task optimization, context refresh, stuck detection, two-stage review, and complete trace emission |

### Skill-Specific Completeness Criteria

- Reads plan file and extracts task count, dependencies, and verification checklist
- Context Anchor restated from persisted files (design doc, plan, artifact inventory)
- TaskCreate entries created for all tasks before execution begins
- Each task delegated to a fresh subagent with task-scoped context only
- Context classified per task (Frontend/Backend/Data/Config/Test/Docs) with appropriate CLAUDE.md sections
- TDD cycle enforced: RED (failing test), GREEN (minimum code to pass), REFACTOR (clean up)
- Two-stage review per task: spec compliance + code quality
- 4-level checkpoint verification invoked after each task (Build, Test, Acceptance, Integration)
- Execution trace YAML emitted after each task checkpoint
- Independent tasks parallelized when marked in plan
- Context refresh performed after every 3rd task or when total exceeds 6
- Completion marker printed with files changed, commits, test counts, build/lint status

## Actionability (1-5)

Are completed tasks verified and ready for review?

| Score | Anchor |
|-------|--------|
| 1 | No verifiable output — tasks claimed complete but no evidence of verification |
| 2 | Some tasks verified but checkpoint reports incomplete or traces missing |
| 3 | Tasks completed with basic verification but review readiness unclear |
| 4 | All tasks verified with clear pass/fail status — reviewer can assess quality from checkpoint reports |
| 5 | Immediately reviewable — complete execution traces, all 4 verification levels passed, holistic diff reviewed, ready for /workflows:review |

## Adherence to Instructions (1-5)

Does the output follow the executing-plans skill's defined protocol?

| Score | Anchor |
|-------|--------|
| 1 | Ignores protocol entirely — executes tasks ad-hoc without subagents, TDD, or verification. Anti-slop violations throughout (E1-E5) |
| 2 | Follows some protocol but skips major steps or contains multiple anti-slop violations (skipped TDD, blind retries, missing traces) |
| 3 | Follows general protocol but misses specific requirements (e.g., trace emission, stuck detection, context classification) |
| 4 | Follows all major steps with minor deviations |
| 5 | Strict compliance — subagent-per-task, TDD enforced, all checkpoints, all traces, all rules followed |

### Skill-Specific Instruction Criteria

- Prints activation banner with trigger reason
- Validates preconditions: plan file exists and working directory is clean
- Uses subagent-per-task model: fresh context per task, no accumulated state
- Classifies task context (Frontend/Backend/Data/Config/Test/Docs) and logs classification
- Task prompt includes only task-scoped context (not full plan or previous task results)
- TDD enforced for testable code: RED-GREEN-REFACTOR cycle mandatory
- TDD skip logged with decision rationale when appropriate (config changes, docs, etc.)
- Two-stage review after each task: Stage 1 spec compliance, Stage 2 code quality
- 4-level verification invoked at every checkpoint (delegates to verification-before-completion skill)
- Stuck detection triggers after 3+ consecutive tool calls without progress
- Error recovery used for stuck tasks and failed checkpoints (retry/skip/stop options)
- Execution trace YAML emitted after every task checkpoint with correct schema (task, agent, timestamp, context_used, decisions_made, files_changed, tests, verification)
- Trace data safety enforced: relative paths only, no secrets, character allowlists, length caps
- Max 3 decisions per trace; excess combined or dropped by confidence
- Context refresh from plan file after every 3rd task or when total exceeds 6
- Tasks never executed out of dependency order
- Progress report printed after each task with task status and next task
- Completion marker printed with artifacts summary
- Hands off to /workflows:review

### Anti-Slop Criteria

Guardrail violations cap Adherence score at 3 (see `docs/quality-guardrails.md`):

- **E1**: Skipped TDD — testable code committed without a red-green-refactor cycle
- **E2**: "It should work" declarations — claiming success without command output evidence
- **E3**: Context pollution — subagent receives full plan or unrelated context instead of task-scoped data
- **E4**: Missing execution traces — task checkpoint completed without `execution-trace-v1` YAML block
- **E5**: Blind retry — retrying failed commands without root cause analysis
