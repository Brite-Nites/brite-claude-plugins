---
name: sf-debug
description: Salesforce debug log analysis and Apex diagnostic discipline (Brite edition) with 100-point scoring. TRIGGER when user analyzes debug logs, hits governor limits, reads stack traces, touches .log files, works in brite-salesforce, asks about Queueable silent-retry signatures, Web-to-Lead BeforeUpdate cascade, TraceFlag-driven root-cause loops (BC-5609 precedent), CronTrigger silent-retry after sandbox refresh, Apex Error email PII discipline, or Test.stopTest() async-drain anomalies. DO NOT TRIGGER when running Apex tests (use sf-testing), fixing Apex code (use sf-apex), or Agentforce session tracing (use sf-ai-agentforce-observability).
user-invocable: false
license: MIT
metadata:
  version: "1.1.0-brite.1"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "100 points across 5 categories"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Apex & Automation + §Integrations (Named Credential + Web-to-Lead specifics). -->

# sf-debug: Salesforce Debug Log Analysis & Troubleshooting (Brite edition)

Use this skill when the user needs **root-cause analysis from debug logs**: governor-limit diagnosis, stack-trace interpretation, slow-query investigation, heap / CPU pressure analysis, or a reproduction-to-fix loop based on log evidence.

## Brite Context

Brite's diagnostic stance:

- **Apex-first Brite code means the debug targets are Apex.** Flows are rare (sf-flow covers the policy); debugging focuses on Apex trigger/service execution paths.
- **Queueable silent-retry is a common Brite signature.** N consecutive "Completed" `AsyncApexJob` rows for the same class in a short window = 1 original + (N-1) silent retries. It signals callout failure — almost always a Named Credential misconfiguration. Check the NC endpoint first, not the Apex.
- **Web-to-Lead has an implicit BeforeUpdate cascade.** Brite's Lead Settings (default Lead Owner + "Override the existing record type") drive an UPDATE after the initial before-insert completes. A trigger that appears to fire twice on a Web-to-Lead insert is exhibiting expected behavior.
- **Apex Error emails for Lead triggers go to the Web-to-Lead admin.** PII or employee emails in exception messages get redistributed broadly — use role-based descriptions ("Lead owner not configured for source X"), never direct names.

**See also:** [sf-testing](../sf-testing/SKILL.md) for prevention (resetting bypass flags before `Test.stopTest()`, static-state hygiene); [sf-apex](../sf-apex/SKILL.md) for the fix loop (trigger handler dispatch, Queueable `BATCH_SIZE=90` design, async defaults); `/revops:post-deploy-runbook` for the post-deploy verification that catches Named Credential misconfigs before they manifest as silent retries in production.

## Brite Diagnostic Patterns

These diagnostic signatures are specific to Brite's org and must surface during log analysis and root-cause investigation.

### 1. Queueable silent-retry diagnostic

N consecutive "Completed" `AsyncApexJob` rows for the same class across a short window = 1 original + (N-1) silent retries. Root cause is almost always a callout failure, and the Queueable is masking it by re-enqueuing. **Check the Named Credential endpoint first** — a deploy that carried a PLACEHOLDER NC URL to sandbox is the most common trigger. Counterpart prevention lives in `/revops:post-deploy-runbook` Phase 3 (NC URL update).

### 2. Web-to-Lead BeforeUpdate cascade

Expected ApexLog signature on a Web-to-Lead insert:

```text
BeforeInsert → Validation → DuplicateDetector(INSERT) → AfterInsert →
Workflow:Lead → BeforeUpdate → DuplicateDetector(UPDATE)
```

The second pass is driven by default Lead Owner + "Override the existing record type" settings, not by a handler bug. If a trigger handler appears to fire twice on a Web-to-Lead, this is why. Design handlers to be idempotent across BeforeInsert + BeforeUpdate on the same transaction.

### 3. TraceFlag-driven debugging for hard-to-reproduce issues

Enable TraceFlag on the affected User; capture ApexLog; decode message-by-message. This is the canonical pattern for bugs that don't reproduce in a fresh-context test. Precedent: **BC-5609** used TraceFlag to surface a webform Lead Owner misconfiguration that unit tests couldn't reach because they bypassed the Lead Settings path.

```bash
# Enable TraceFlag via CLI (current user)
sf data create record --sobject TraceFlag \
  --values "TracedEntityId=<UserId> LogType=USER_DEBUG DebugLevelId=<DebugLevelId> StartDate=<iso> ExpirationDate=<iso>" \
  --target-org <alias>
```

### 4. CronTrigger silent-retry and sandbox-refresh loss

Scheduled jobs that fail silently need manual inspection via the Developer Console or a direct query:

```sql
SELECT Id, State, NextFireTime, CronJobDetail.Name
FROM CronTrigger
WHERE CronJobDetail.Name = '<scheduled class name>'
```

**Scheduled Apex does not survive a sandbox refresh.** Missing `CronTrigger` rows after a refresh are a known cause of "scheduled job stopped running" reports. Re-schedule via `System.schedule(...)` or the Setup UI post-refresh. Covered by `/revops:post-deploy-runbook` Phase 2 (Scheduled Apex re-setup).

### 5. Apex Error email PII discipline

`ConfigException` in Lead triggers surfaces in two places:

1. The Web-to-Lead admin error email (which gets redistributed).
2. The Apex Debug Log.

**Do NOT include PII or employee emails in exception messages.** Use role-based descriptions — `"Lead owner not configured for source X"`, never `"Lead owner alice@example.com invalid"`. This is a data-leak surface, not just a hygiene preference.

### 6. `Test.stopTest()` async drain — counterpart to sf-testing rule 5

When debugging a test fixture, if Queueables fired inside `Test.stopTest()` exhibit unexpected behavior (trigger handler runs with bypass flags still set, static state leaks into async re-entry), suspect that the fixture left a bypass flag on. sf-testing §5 covers prevention (reset flags before `Test.startTest()` and `Test.stopTest()`); this is the diagnostic angle when you're staring at the log wondering why a handler fired differently in the async path.

## When This Skill Owns the Task

Use `sf-debug` when the work involves:
- `.log` files from Salesforce
- stack traces and exception analysis
- governor limits
- SOQL / DML / CPU / heap troubleshooting
- query-plan or performance evidence extracted from logs

Delegate elsewhere when the user is:
- running or repairing Apex tests → [sf-testing](../sf-testing/SKILL.md)
- implementing the code fix → [sf-apex](../sf-apex/SKILL.md)
- debugging Agentforce session traces / parquet telemetry → [sf-ai-agentforce-observability](../sf-ai-agentforce-observability/SKILL.md)

---

## Required Context to Gather First

Ask for or infer:
- org alias
- failing transaction / user flow / test name
- approximate timestamp or transaction window
- user / record / request ID if known
- whether the goal is diagnosis only or diagnosis + fix loop

---

## Recommended Workflow

### 1. Retrieve logs
```bash
sf apex list log --target-org <alias> --json
sf apex get log --log-id <id> --target-org <alias>
sf apex tail log --target-org <alias> --color
```

### 2. Analyze in this order
1. entry point and transaction type
2. exceptions / fatal errors
3. governor limits
4. repeated SOQL / DML patterns
5. CPU / heap hotspots
6. callout timing and external failures

### 3. Classify severity
- **Critical** — runtime failure, hard limit, corruption risk
- **Warning** — near-limit, non-selective query, slow path
- **Info** — optimization opportunity or hygiene issue

### 4. Recommend the smallest correct fix
Prefer fixes that are:
- root-cause oriented
- bulk-safe
- testable
- easy to verify with a rerun

Expanded workflow: [references/analysis-playbook.md](references/analysis-playbook.md)

---

## High-Signal Issue Patterns

| Issue | Primary signal | Default fix direction |
|---|---|---|
| SOQL in loop | repeating `SOQL_EXECUTE_BEGIN` in a repeated call path | query once, use maps / grouped collections |
| DML in loop | repeated `DML_BEGIN` patterns | collect rows, bulk DML once |
| Non-selective query | high rows scanned / poor selectivity | add indexed filters, reduce scope |
| CPU pressure | CPU usage approaching sync limit | reduce algorithmic complexity, cache, async where valid |
| Heap pressure | heap usage approaching sync limit | stream with SOQL for-loops, reduce in-memory data |
| Null pointer / fatal error | `EXCEPTION_THROWN` / `FATAL_ERROR` | guard null assumptions, fix empty-query handling |

Expanded examples: [references/common-issues.md](references/common-issues.md)

---

## Output Format

When finishing analysis, report in this order:

1. **What failed**
2. **Where it failed** (class / method / line / transaction stage)
3. **Why it failed** (root cause, not just symptom)
4. **How severe it is**
5. **Recommended fix**
6. **Verification step**

Suggested shape:

```text
Issue: <summary>
Location: <class / line / transaction>
Root cause: <explanation>
Severity: Critical | Warning | Info
Fix: <specific action>
Verify: <test or rerun step>
```

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| Implement Apex fix | [sf-apex](../sf-apex/SKILL.md) | code change generation / review |
| Reproduce via tests | [sf-testing](../sf-testing/SKILL.md) | test execution and coverage loop |
| Deploy fix | [sf-deploy](../sf-deploy/SKILL.md) | deployment orchestration |
| Create debugging data | [sf-data](../sf-data/SKILL.md) | targeted seed / repro data |

---

## Reference Map

### Start here
- [references/analysis-playbook.md](references/analysis-playbook.md)
- [references/common-issues.md](references/common-issues.md)
- [references/cli-commands.md](references/cli-commands.md)

### Deep references
- [references/debug-log-reference.md](references/debug-log-reference.md)
- [references/log-analysis-tools.md](references/log-analysis-tools.md)
- [references/benchmarking-guide.md](references/benchmarking-guide.md)

### Rubric
- [references/scoring-rubric.md](references/scoring-rubric.md)

---

## Score Guide

| Score | Meaning |
|---|---|
| 90+ | Expert analysis with strong fix guidance |
| 80–89 | Good analysis with minor gaps |
| 70–79 | Acceptable but may miss secondary issues |
| 60–69 | Partial diagnosis only |
| < 60 | Incomplete analysis |
