---
description: Run diagnostic checks on the plugin environment — CLI tools, MCP servers, hooks, agent dispatch
---

<!-- eval-waiver: Every check probes live host and environment state (tool versions, MCP connectivity, hook firing, agent dispatch) and the PASS/FAIL/SKIP table is a direct function of that machine's installed tooling and auth, so there is no repeatable artifact independent of the live environment to fixture. -->

# Smoke Test

Run a comprehensive health check of the Brite plugin environment. This is a diagnostic tool for verifying everything is wired up correctly.

## Step 1: Environment Checks

Run each check and record the result:

1. **git** — Run `git --version`. PASS if it returns a version, FAIL otherwise.
2. **gh CLI** — Run `gh auth status`. PASS if authenticated, FAIL if not installed, SKIP if installed but not authenticated (with note: "run `gh auth login`").
3. **node** — Run `node --version`. PASS if it returns a version, FAIL otherwise.
4. **npx** — Run `npx --version`. PASS if it returns a version, FAIL otherwise.

## Step 2: MCP Connectivity

Test that MCP servers respond:

1. **sequential-thinking** — Call the sequential-thinking MCP with a trivial thought (e.g., thought: "Smoke test", thoughtNumber: 1, totalThoughts: 1, nextThoughtNeeded: false). PASS if it responds, FAIL if the tool call errors.
2. **Linear** — Call the Linear MCP to list teams (just 1 result). PASS if it responds with data, SKIP if auth isn't configured, FAIL if the tool call errors unexpectedly.

## Step 3: Hook Verification

Test that security hooks are active:

1. **Attempt a Write** with content containing a known test secret pattern: `sk_test_SMOKETEST12345678`. The Write target should be a temporary path like `/tmp/brite-smoke-test.txt`.
2. **If the Write is BLOCKED** by the PreToolUse hook → PASS (hooks are active and catching secrets).
3. **If the Write SUCCEEDS** → KNOWN ISSUE ("PreToolUse hooks from plugins don't fire — upstream bug [#6305](https://github.com/anthropics/claude-code/issues/6305). Hook definitions are correct; no action needed on our side."). Clean up the temp file.

## Step 4: Agent Dispatch Test

Test that the Task tool can launch subagents:

1. **Launch a trivial Task agent** — Use the general-purpose subagent with the prompt: "Reply with the single word: pong". Set max_turns to 1.
2. **If it completes** with any response → PASS.
3. **If it fails or times out** → FAIL ("Agent dispatch is broken. Task tool may not be available.").

## Step 5: Report

Present all results in a table:

```
## Smoke Test Results

| Check               | Status | Notes                    |
|---------------------|--------|--------------------------|
| git                 | PASS   |                          |
| gh CLI              | PASS   | authenticated as holden  |
| node                | PASS   | v22.x                   |
| npx                 | PASS   |                          |
| sequential-thinking | PASS   |                          |
| Linear              | SKIP   | auth not configured      |
| hooks active        | KNOWN ISSUE | upstream bug #6305  |
| agent dispatch      | PASS   |                          |

**Overall**: 6 PASS, 0 FAIL, 1 SKIP, 1 KNOWN ISSUE
```

If any check is FAIL, add a **Remediation** section below the table with specific fix instructions for each failed check.

## Rules

- Run all checks even if an early one fails — give the complete picture.
- SKIP is not a failure — it means an optional dependency isn't configured.
- The hook test (Step 3) intentionally triggers a security block. If the user sees the hook's block message, that's expected behavior — explain this.
- Clean up any temp files created during testing.
- Keep output concise — the table is the primary artifact.
