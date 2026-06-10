---
description: Comprehensive security audit and vulnerability assessment for any project
---

<!-- eval-waiver: The report is built from live host and project probes (npm/pip/go/bundle audit, secret-scan Grep, git ls-files, npm outdated) plus a security-reviewer agent's free-text findings; both halves are environment- and agent-dependent, so the audit report and A-F health grade have no repeatable artifact for a hermetic fixture. -->

# Security Audit

Perform a comprehensive security audit of the current project. This goes beyond diff-based code review — it assesses the project's overall security posture using automated tooling and agent-powered analysis.

**How this differs from `/review` and `/code-review`:**
- `/review` checks your branch diff before shipping
- `/code-review` reviews specific changes or PRs
- `/security-audit` scans the entire project (or scoped area) for vulnerabilities, secrets, dependency issues, and misconfigurations

## Step 0: Determine Scope & Mode

**Scope** — what to audit:

- **If `$ARGUMENTS` specifies files or directories:** Audit only those paths.
- **If `$ARGUMENTS` specifies a PR number or URL:** Audit the files changed in that PR using `gh pr diff`.
- **If `$ARGUMENTS` is empty:** Audit the entire project.

**Mode** — how deep to go:

- **Standard (default):** Run automated checks + dispatch the security-reviewer agent.
- **Quick (when `$ARGUMENTS` contains "quick" or "--quick"):** Run automated checks only. Skip agent dispatch. Fast but surface-level.

## Step 1: Detect Project Type

Identify the project's tech stack to determine which automated checks to run:

1. **Check for project files:**
   - `package.json` → JavaScript/TypeScript (check for Next.js, React, Express, etc.)
   - `pyproject.toml` or `setup.py` or `requirements.txt` → Python
   - `go.mod` → Go
   - `Cargo.toml` → Rust
   - `Gemfile` → Ruby
2. **Check for infrastructure files:** `docker-compose.yml`, `Dockerfile`, `.env*`, `vercel.json`, `railway.json`
3. **Read the project's CLAUDE.md** (if it exists) for tech stack context.

Report what was detected before proceeding.

## Step 2: Automated Security Checks

Run each applicable check. If a tool isn't installed or a file doesn't exist, skip it gracefully — do not fail.

### 2a. Dependency Vulnerabilities

Run the appropriate audit command for the detected project type:

- **JS/TS:** `npm audit --json 2>/dev/null` or `yarn audit --json 2>/dev/null` or `pnpm audit --json 2>/dev/null`
- **Python:** `pip audit --format=json 2>/dev/null` (if installed) or `safety check --json 2>/dev/null`
- **Go:** `govulncheck ./... 2>/dev/null`
- **Ruby:** `bundle audit check 2>/dev/null`

Parse the output. Classify each vulnerability by severity (critical, high, medium, low).

If no audit tool is available, note it as an **Info** finding: "No dependency audit tool detected. Consider installing `npm audit` / `pip audit`."

### 2b. Secret Detection

Scan source code for hardcoded secrets using Grep. Check for these patterns:

- API keys: `sk-proj-`, `sk_live_`, `sk_test_`, `AKIA`, `AIza`
- Tokens: `ghp_`, `gho_`, `github_pat_`, `xoxb-`, `xoxp-`
- Generic secrets: `password\s*=\s*["'][^"']+["']`, `secret\s*=\s*["'][^"']+["']`, `Bearer [A-Za-z0-9\-._~+/]+=*`
- Connection strings: `postgres://`, `mysql://`, `mongodb://`, `redis://`
- Private keys: `-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----`

Exclude matches in:
- `node_modules/`, `.git/`, `vendor/`, `__pycache__/`, `dist/`, `build/`
- Lock files (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Pipfile.lock`)
- Files that are clearly example/template values (e.g., `example.env`, docs with placeholder values)

For each match, verify it looks like an actual secret (not a variable name, regex pattern, or documentation example) before reporting it.

### 2c. Environment Configuration

1. **Check `.gitignore`** — Verify `.env*` patterns are included. Flag if missing.
2. **Check for committed `.env` files** — Run `git ls-files '*.env' '.env*'` to find any `.env` files tracked by git.
3. **Check for `.env.local`** — If it exists and is gitignored, that's good. If it exists and is tracked, that's a P1.
4. **Scan environment variable usage** — Grep for `process.env.` or `os.environ` or `os.Getenv` to understand what secrets the project expects. Verify those aren't hardcoded anywhere.

### 2d. Dependency Hygiene

- **JS/TS:** Run `npm outdated 2>/dev/null` or equivalent. Flag packages more than 2 major versions behind as Medium.
- **Python:** Run `pip list --outdated --format=json 2>/dev/null` if available.

Note: This is informational, not blocking. Outdated doesn't mean vulnerable.

## Step 3: Agent-Powered Code Analysis

**Skip this step if running in Quick mode.**

Dispatch the **security-reviewer** agent via the Task tool for deep code analysis.

Provide this context to the agent:

- The project type and tech stack detected in Step 1
- The scope (full project or specific paths from `$ARGUMENTS`)
- Instruction: "Audit the project's source code for security vulnerabilities. Focus on: input validation, authentication & authorization, data exposure, injection attacks, infrastructure & config, and framework-specific issues. Use P1/P2/P3 severity. Scan the full codebase within the specified scope, not just recent changes."

Wait for the agent to complete.

## Step 4: Compile Security Report

Merge findings from automated checks (Step 2) and agent analysis (Step 3) into a single structured report. Deduplicate any overlapping findings.

Present the report in this format:

```
## Security Audit Report

**Project**: [project name from package.json/pyproject.toml or directory name]
**Scope**: [Full project / specific paths / PR #N]
**Mode**: [Standard / Quick]
**Stack**: [detected tech stack]

---

### Critical Findings
- [Finding] — `file:line` — [source: automated/agent]
  **Risk**: [what could happen]
  **Fix**: [specific remediation]

### High Findings
- ...

### Medium Findings
- ...

### Low Findings
- ...

### Informational
- ...

---

### Dependency Audit
| Package | Current | Vulnerability | Severity | Advisory |
|---------|---------|--------------|----------|----------|
| ...     | ...     | ...          | ...      | ...      |

(or "No vulnerabilities found" / "Audit tool not available")

### Environment Check
- .gitignore covers .env: [Yes/No]
- Committed .env files: [None / list]
- Secrets in source code: [None / count]

---

## Health Score

**[A/B/C/D/F]**

| Grade | Criteria |
|-------|----------|
| A | No critical or high findings |
| B | No critical, 1-2 high findings |
| C | No critical, 3+ high findings |
| D | 1 critical finding |
| F | 2+ critical findings |

**Summary**: X critical, Y high, Z medium, W low, V informational
```

## Step 5: Recommendations

After the report, provide:

1. **Priority fixes** — Top 3 items to address first, ordered by risk.
2. **Quick wins** — Findings that can be fixed in under 5 minutes.
3. **Structural improvements** — Longer-term suggestions (add CSP headers, implement rate limiting, etc.).

If the user wants to fix issues immediately, offer to address them starting with Critical/High severity.

## Rules

- Never run destructive commands. This is a read-only audit.
- Skip checks gracefully when tools aren't installed — report what was skipped.
- Don't flag Prisma query builder methods as SQL injection (only `$queryRaw` with interpolation).
- Don't flag React JSX auto-escaped rendering as XSS.
- Verify secrets are actual secrets, not placeholder values or documentation examples.
- For environment variables, focus on what's committed to git — local-only files are fine.
- If the project is very large (50+ source files in scope), warn the user and suggest scoping to specific directories for faster results.
- Don't report the same finding from both automated checks and agent analysis — deduplicate.
