---
skill: brainstorming
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

# Brainstorming Rubric

## Clarity (1-5)

Is the output well-organized, easy to follow, and free of confusion?

| Score | Anchor |
|-------|--------|
| 1 | Incoherent — no clear structure, topics jumbled, impossible to follow |
| 2 | Partially organized but key sections hard to find or confusing |
| 3 | Acceptable structure — sections exist but flow could improve |
| 4 | Well-organized with clear headings, logical flow, easy to scan |
| 5 | Exemplary — crisp phase narration, each section self-contained, zero confusion |

## Completeness (1-5)

Does the output cover all required aspects of the brainstorming task?

| Score | Anchor |
|-------|--------|
| 1 | Major gaps — misses most requirements, superficial treatment |
| 2 | Addresses some aspects but significant omissions |
| 3 | Covers basics — meets minimum requirements but lacks depth |
| 4 | Thorough — addresses all stated requirements with reasonable depth |
| 5 | Comprehensive — covers requirements plus edge cases, risks, and alternatives |

### Skill-Specific Completeness Criteria

- Explores 2+ alternative approaches with tradeoffs
- Design document includes: Problem, Approach, Key Decisions, Alternatives, Risks, Scope Boundaries
- References relevant context (issue description, CLAUDE.md, precedents if available)
- Scope boundaries clearly defined (in-scope and out-of-scope)
- Open questions addressed or explicitly listed

## Actionability (1-5)

Can the developer move directly to planning based on this output?

| Score | Anchor |
|-------|--------|
| 1 | No clear next steps — output is abstract, no concrete direction |
| 2 | Vague direction but no concrete decisions or recommendations |
| 3 | Some actionable items but requires significant interpretation |
| 4 | Clear chosen approach — developer knows exactly what to plan |
| 5 | Immediately plannable — precise decisions, clear rationale, ready for writing-plans |

## Adherence to Instructions (1-5)

Does the output follow the brainstorming skill's defined protocol?

| Score | Anchor |
|-------|--------|
| 1 | Ignores protocol entirely — no phases, no artifacts, skips to implementation. Anti-slop violation (PL1 vague descriptions) |
| 2 | Follows some protocol but skips major steps or produces vague scope/problem definitions that would carry forward |
| 3 | Follows general protocol but misses specific requirements |
| 4 | Follows all major steps with minor deviations |
| 5 | Strict compliance — all phases, all artifacts, all rules followed |

### Skill-Specific Instruction Criteria

- Prints activation banner with trigger reason
- Follows 4-phase structure: Context Gathering, Socratic Discovery, Design Document, Approval
- Asks 1-2 Socratic questions at a time (not a wall of questions)
- Design document stays under 40 lines
- Saves design document to `docs/designs/<id>-<slug>.md`
- Prints completion marker with artifacts, key decisions, and scope
- Hands off to writing-plans

### Anti-Slop Criteria

Guardrail violations cap Adherence score at 3 (see `docs/quality-guardrails.md`):

- **PL1**: Vague problem statements or scope descriptions that lack concrete specifics — carries forward as vague task descriptions in planning
