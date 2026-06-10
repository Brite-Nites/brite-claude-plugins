---
description: Standardized code review for Brite projects
---

<!-- eval-waiver: The output is an LLM-authored P1/P2/P3 review narrative over an arbitrary diff (or a dispatch of parallel review agents in deep mode); the findings are free-text judgments with no fixed correct artifact, and the deep-mode agent-selection and dedup logic is borrowed from /workflows:review rather than owned here. -->

# Code Review

Perform a thorough code review following Brite standards. Reference the tech stack established in `/workflows:tech-stack` for technology-specific expectations.

## Determine Review Scope

First, determine what to review based on the user's input:

**If `$ARGUMENTS` specifies a PR number or URL:** Use `gh pr diff` to get the changes and `gh pr view` for context.

**If `$ARGUMENTS` specifies files or directories:** Review those files directly.

**If `$ARGUMENTS` is empty:** Check for uncommitted changes with `git diff` and `git diff --staged`. If there are none, ask the user what to review.

## Review Mode

This command supports two modes:

### Quick Mode (default for `$ARGUMENTS` with PR/files)
Perform a direct review yourself, working through the checklists below. Best for quick spot-checks and PR reviews.

### Deep Mode (use when `$ARGUMENTS` contains "deep" or "--deep")
Launch the selected review agents in parallel for comprehensive coverage. This is what `/workflows:review` does during the session loop. Use it for thorough pre-merge reviews.

**To run deep mode:** Use the same dynamic agent selection algorithm as `/workflows:review` Step 4 — Tier 1 (always: code-reviewer, security-reviewer, performance-reviewer), Tier 2 (stack-detected: typescript-reviewer, python-reviewer, data-reviewer), Tier 3 (opt-in/conditional: architecture-reviewer, test-quality-reviewer, accessibility-reviewer). All review agents run on Opus (model specified in agent files). Deep mode always uses `thorough` depth (Tier 1 + Tier 2 + standard Tier 3 logic). To use `fast` or `comprehensive` depth, run `/workflows:review` directly with the depth keyword. Launch all selected agents in parallel via the Task tool, passing the diff context. Agents include confidence scores (1-10) with each finding. Collect and merge their findings into a single P1/P2/P3 report. Apply cross-agent deduplication: when multiple agents flag the same `file:line`, keep the finding with the higher confidence score; on ties, use specialization order (security-reviewer > data-reviewer > performance-reviewer > architecture-reviewer > test-quality-reviewer > python-reviewer > typescript-reviewer > accessibility-reviewer > code-reviewer). Apply the same confidence threshold filtering as `/workflows:review` Step 5 (>= 7 included, low-confidence P2/P3 filtered, borderline P1s marked for human review). Note: deep mode does NOT include Diff Triage or per-finding Validation — those are `/workflows:review`-only features.

---

## Quick Mode: Review Process

Work through each section. Only report issues you actually find — skip sections with no findings.

### 1. Correctness

- Does the code do what it's supposed to?
- Are there logic errors, off-by-one mistakes, or unhandled edge cases?
- Are conditionals and loops correct?
- Are null/undefined/empty states handled?

### 2. Security

- Input validation at system boundaries (user input, API payloads, URL params)
- SQL injection, XSS, command injection risks
- Secrets or credentials in code (API keys, passwords, tokens)
- Proper authentication/authorization checks
- CORS and CSP configuration where applicable

### 3. Frontend Checklist (React / Next.js / TypeScript)

Only apply if reviewing frontend code. Defer to the **react-best-practices** skill for the full 45-rule audit (waterfalls, bundle size, re-renders, server components, etc.). In this review, focus on:

- Server vs. client component boundaries are correct (Next.js App Router)
- Tailwind CSS used for styling (not CSS modules or styled-components)
- TypeScript types are meaningful (no excessive `any`)
- Zod schemas validate external data at system boundaries

### 4. Backend Checklist (FastAPI / Python)

Only apply if reviewing backend code. Defer to the **python-best-practices** skill for the full 38-rule audit (async correctness, DI, database patterns, Pydantic, etc.).

- Pydantic models validate request/response data
- Async endpoints where I/O-bound
- SQLAlchemy queries are efficient (no N+1, proper joins)
- Alembic migrations are reversible
- Error responses follow consistent format
- Type hints on all function signatures
- Black/Ruff formatting compliance

### 5. Data Engineering Checklist

Only apply if reviewing data code:

- Prefect flows have proper error handling and retries
- BigQuery queries are cost-conscious (avoid `SELECT *`, use partitioning)
- dbt models follow the project's naming conventions
- Data transformations are idempotent
- Schema changes are backward-compatible

### 6. Code Quality

- Functions and variables have clear, descriptive names
- No dead code, commented-out code, or TODO comments without tracking
- DRY violations (duplicated logic that should be shared)
- Functions are focused (single responsibility)
- Error handling is appropriate (not swallowing errors silently)
- Tests cover the new/changed behavior

### 7. Architecture

- Changes align with existing project patterns
- New dependencies are justified and from the approved tech stack
- No unnecessary abstractions or premature optimization
- File and folder structure follows project conventions

## Test Suite Execution

Before presenting findings, run the project's test suite if one exists:

1. Check `package.json` for test scripts, or look for common test runners (`vitest`, `jest`, `pytest`).
2. Run tests and report results alongside review findings.
3. If no test suite exists, note it as a P2 finding.

## Output Format

Present findings using **P1/P2/P3 severity**:

**P1 — Must Fix** (blocks merge: bugs, security issues, data loss risks)

**P2 — Should Fix** (user decides: code smells, missing tests, unclear naming)

**P3 — Nit** (report only: formatting, style preferences, minor polish)

For each finding, include:
1. File and line reference
2. What the issue is
3. Why it matters
4. Suggested fix (code snippet when helpful)

End with a summary: total findings by severity, overall assessment (approve, request changes, or needs discussion), and any positive callouts for well-written code.
