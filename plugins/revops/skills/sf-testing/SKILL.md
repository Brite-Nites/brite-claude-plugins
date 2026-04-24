---
name: sf-testing
description: Apex test execution and coverage discipline (Brite edition) with 120-point scoring. TRIGGER when user runs Apex tests, checks coverage, fixes failing tests, touches *Test.cls / *_Test.cls files, works in brite-salesforce, asks about 100% class coverage targets, @TestSetup static-state trap, Queueables inside Test.stopTest() re-entering handlers, @TestVisible + Test.isRunningTest() escape-hatch gating, Bypass_Validation_Rules honoring in tests, LWC Jest pre-commit, or scratch-org-per-PR validation. DO NOT TRIGGER when writing Apex production code (use sf-apex), Agentforce agent testing (use sf-ai-agentforce-testing), or Jest/LWC tests (use sf-lwc).
user-invocable: false
license: MIT
metadata:
  version: "1.1.0-brite.1"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "120 points across 6 categories"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Apex & Automation (lines 175-196) + §Engineering Standards (line 42). -->

# sf-testing: Salesforce Test Execution & Coverage Analysis (Brite edition)

Use this skill when the user needs **Apex test execution and failure analysis**: running tests, checking coverage, interpreting failures, improving coverage, and managing a disciplined test-fix loop for Salesforce code.

## Brite Context

Brite's test stance:

- **Coverage target is 100% per class, not the SF 75% floor.** 90%+ org-wide is the target. Required for all triggers and service classes. Source: `brite-salesforce/CLAUDE.md` §Engineering Standards line 42.
- **Apex-first Brite code requires Apex tests.** Flows are limited to screen flows and simple notifications (sf-flow covers the policy); everything else is Apex, so trigger tests, service tests, and bulk-path coverage are non-negotiable.
- **LWC Jest runs at pre-commit.** The pre-commit hook executes Jest tests for staged LWCs; any new LWC ships with Jest coverage.
- **Escape-hatch discipline.** `@TestVisible` + `Test.isRunningTest()` gate narrow exceptions (e.g., `Bypass_Validation_Rules` honoring on security-critical paths); the pattern is narrow-scoped per check, never a blanket sibling bypass.

**See also:** [sf-apex](../sf-apex/SKILL.md) for production Apex patterns (trigger handler dispatch, Queueable `BATCH_SIZE=90` self-chaining, `Bypass_Validation_Rules` design); [sf-debug](../sf-debug/SKILL.md) for diagnostic signatures when tests leak static state across fixtures.

## Brite Test Discipline

These rules are non-negotiable on `brite-salesforce` and must surface during test authoring, coverage analysis, and failure triage.

### 1. Coverage targets — 100% class / 90%+ org-wide / 75% SF floor

The 75% number is Salesforce's deploy floor, not Brite's target. Individual classes hit 100%; org-wide averages 90%+. Required for all triggers and service classes. Source: §Engineering Standards line 42.

### 2. LWC Jest required for all LWCs

Pre-commit hook runs Jest on staged files; any new LWC ships with Jest coverage. Canonical commands: `npm test`, `npm run test:unit:coverage`.

### 3. Apex tests required for all triggers and service classes

No exceptions. Every trigger and every `*Service` class has a test class with positive-path, negative-path, and bulk-path coverage (251+ records where the handler iterates).

### 4. `@TestSetup` static state does not persist across `@IsTest` methods

Each `@IsTest` method runs a fresh transaction. Set bypass flags inside the `@IsTest` method body, not in `@TestSetup`. A flag set in `@TestSetup` is lost before any individual test method executes. Source: §Apex & Automation.

### 5. Queueables enqueued inside `Test.stopTest()` re-enter trigger handlers with current static state

Reset bypass flags before `Test.startTest()` and again before `Test.stopTest()` when the fixture has set them. Counterpart signature in sf-debug: a fixture that left a flag on manifests as unexpected async handler behavior.

### 6. `@TestVisible` + `Test.isRunningTest()` gates narrow escape hatches

Used together — `@TestVisible` exposes a private field to tests, `Test.isRunningTest()` gates the behavior to test context only. The pattern is narrow-scoped per check (one gated behavior at a time), never a blanket sibling bypass on security-critical paths.

### 7. `Bypass_Validation_Rules` pattern is test-only

Honored via `@TestVisible` on a static flag that production code paths never set. See [sf-apex §Brite Apex Conventions](../sf-apex/SKILL.md#brite-apex-conventions) for the full design.

### 8. Pre-deploy validation + CI

Scratch-org-per-PR validates deploys before merge. Live tests via `sf apex run test --wait 10 --target-org <alias>`. Local validation: `npm run test:unit:coverage` for LWC; `sf apex run test --tests <ClassName> --wait 10` for Apex.

### 9. `System.runAs(...)` for permission scenarios

`User.create()` builds a test user; `System.runAs(testUser) { ... }` establishes the permission context inside the block. Pair with factory-built test users that assign the target permission set programmatically.

## When This Skill Owns the Task

Use `sf-testing` when the work involves:
- `sf apex run test` workflows
- Apex unit-test failures
- code coverage analysis
- identifying uncovered lines and missing test scenarios
- structured test-fix loops for Apex code

Delegate elsewhere when the user is:
- writing or refactoring production Apex → [sf-apex](../sf-apex/SKILL.md)
- testing Agentforce agents → [sf-ai-agentforce-testing](../sf-ai-agentforce-testing/SKILL.md)
- testing LWC with Jest → [sf-lwc](../sf-lwc/SKILL.md)

---

## Required Context to Gather First

Ask for or infer:
- target org alias
- desired test scope: single class, specific methods, suite, or local tests
- coverage threshold expectation
- whether the user wants diagnosis only or a test-fix loop
- whether related test data factories already exist

---

## Recommended Workflow

### 1. Discover test scope
Identify:
- existing test classes
- target production classes
- test data factories / setup helpers

### 2. Run the smallest useful test set first
Start narrow when debugging a failure; widen only after the fix is stable.

### 3. Analyze results
Focus on:
- failing methods
- exception types and stack traces
- uncovered lines / weak coverage areas
- whether failures indicate bad test data, brittle assertions, or broken production logic

### 4. Run a disciplined fix loop
When the issue is code or test quality:
- delegate code fixes to [sf-apex](../sf-apex/SKILL.md) when needed
- add or improve tests
- rerun focused tests before broader regression

### 5. Improve coverage intentionally
Cover:
- positive path
- negative / exception path
- bulk path (251+ records where appropriate)
- callout or async path when relevant

---

## High-Signal Rules

- default to `SeeAllData=false`
- every test should assert meaningful outcomes
- test bulk behavior, not just single-record happy paths
- use factories / `@TestSetup` when they improve clarity and speed
- pair `Test.startTest()` with `Test.stopTest()` when async behavior matters
- do not hide flaky org dependencies inside tests

---

## Output Format

When finishing, report in this order:
1. **What tests were run**
2. **Pass/fail summary**
3. **Coverage result**
4. **Root-cause findings**
5. **Fix or next-run recommendation**

Suggested shape:

```text
Test run: <scope>
Org: <alias>
Result: <passed / partial / failed>
Coverage: <percent / key classes>
Issues: <highest-signal failures>
Next step: <fix class, add test, rerun scope, or widen regression>
```

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| fix production code or author tests | [sf-apex](../sf-apex/SKILL.md) | code generation and repair |
| create bulk / edge-case data | [sf-data](../sf-data/SKILL.md) | realistic test datasets |
| deploy updated tests | [sf-deploy](../sf-deploy/SKILL.md) | rollout |
| inspect detailed runtime logs | [sf-debug](../sf-debug/SKILL.md) | deeper failure analysis |

---

## Reference Map

### Start here
- [references/cli-commands.md](references/cli-commands.md)
- [references/test-patterns.md](references/test-patterns.md)
- [references/testing-best-practices.md](references/testing-best-practices.md)
- [references/test-fix-loop.md](references/test-fix-loop.md)

### Specialized guidance
- [references/mocking-patterns.md](references/mocking-patterns.md)
- [references/performance-optimization.md](references/performance-optimization.md)
- [assets/](assets/)

---

## Score Guide

| Score | Meaning |
|---|---|
| 108+ | strong production-grade test confidence |
| 96–107 | good test suite with minor gaps |
| 84–95 | acceptable but strengthen coverage / assertions |
| < 84 | below standard; revise before relying on it |
