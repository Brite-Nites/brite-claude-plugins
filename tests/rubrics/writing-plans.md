---
skill: writing-plans
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

# Writing Plans Rubric

## Clarity (1-5)

Is the output well-organized, easy to follow, and free of confusion?

| Score | Anchor |
|-------|--------|
| 1 | Incoherent — tasks jumbled, no structure, impossible to follow execution order |
| 2 | Partially organized but task boundaries unclear or dependencies confusing |
| 3 | Acceptable structure — tasks exist with headings but flow and dependencies could improve |
| 4 | Well-organized with clear task numbering, file paths, implementation steps, and dependency graph |
| 5 | Exemplary — each task self-contained, dependencies explicit, verification steps precise, zero ambiguity |

## Completeness (1-5)

Does the output cover all required aspects of the planning task?

| Score | Anchor |
|-------|--------|
| 1 | Major gaps — most acceptance criteria unaddressed, no test specifications |
| 2 | Addresses some requirements but significant tasks missing or underspecified |
| 3 | Covers basics — tasks exist for core requirements but lacks edge cases or test detail |
| 4 | Thorough — all acceptance criteria mapped to tasks with implementation and test steps |
| 5 | Comprehensive — full coverage including edge cases, CDR alignment, precedent references, and dependency graph |

### Skill-Specific Completeness Criteria

- Loads context: Linear issue details, design document (if exists), project CLAUDE.md, CDR INDEX, precedent INDEX, relevant source code, test patterns
- CDR conflict handling performed (comply/exception/override) when conflicts detected
- Precedent INDEX checked and relevant precedents noted in Prerequisites
- Plan saved to `docs/plans/<issue-id>-plan.md` with correct template structure
- Prerequisites section includes CDR alignment, CDR exceptions, and precedent alignment (or notes their absence)
- Task Dependencies section maps sequential vs parallelizable tasks
- Verification Checklist uses project-specific commands from CLAUDE.md
- Each task includes: Files, Why, Implementation steps, Test specification, Verify step

## Actionability (1-5)

Can execution start immediately from this plan?

| Score | Anchor |
|-------|--------|
| 1 | No clear tasks — plan is abstract descriptions with no concrete implementation steps |
| 2 | Tasks exist but too vague for a fresh subagent to execute without significant interpretation |
| 3 | Some tasks are actionable but others require clarification of file paths or implementation details |
| 4 | Clear tasks — a fresh subagent with no prior context can execute each task correctly |
| 5 | Immediately executable — exact file paths, complete signatures, explicit test commands, zero ambiguity for any task |

## Adherence to Instructions (1-5)

Does the output follow the writing-plans skill's defined protocol?

| Score | Anchor |
|-------|--------|
| 1 | Ignores protocol entirely — no plan file, no structure, skips to implementation. Anti-slop violations throughout (PL1-PL4) |
| 2 | Follows some protocol but skips major steps or contains multiple anti-slop violations (vague tasks, missing paths) |
| 3 | Follows general protocol but misses specific requirements (e.g., task size limits, CDR check) |
| 4 | Follows all major steps with minor deviations |
| 5 | Strict compliance — all 3 steps, all task rules, all artifacts produced correctly |

### Skill-Specific Instruction Criteria

- Prints activation banner with trigger reason
- Follows 3-step structure: Load Context, Write Plan, Get Approval
- Narrates step progress (e.g., `Step 1/3: Loading context... done`)
- Each task is 2-5 minutes for a focused agent (max 5 implementation steps, max 3 files)
- Tasks include exact file paths (no "find the relevant file")
- Tasks include complete implementation details (not "implement the function")
- Tasks include TDD cycle: test file changes alongside implementation
- Verification steps are automated, specific, and use project commands from CLAUDE.md
- Plan saved to `docs/plans/<issue-id>-plan.md`
- Issue ID sanitized against `^[a-zA-Z0-9]([a-zA-Z0-9_-]*[a-zA-Z0-9])?$` before use in file paths
- Approval requested with iteration support (max 3 iterations before error recovery)
- Completion marker printed with artifacts, key decisions, and task counts
- Hands off to git-worktrees

### Anti-Slop Criteria

Guardrail violations cap Adherence score at 3 (see `docs/quality-guardrails.md`):

- **PL1**: Vague task descriptions using hedge phrases ("implement the feature", "set up the module") without exact file paths or function signatures
- **PL2**: Oversized tasks with >5 implementation steps or >3 files
- **PL3**: Tasks missing file paths entirely — no concrete file references in task body
- **PL4**: Tasks missing verification steps — no `Verify:` or `Test:` section with a runnable command
