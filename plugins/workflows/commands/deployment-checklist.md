---
description: Pre-deployment validation checklist — run automated checks and confirm manual items before deploying
---

<!-- eval-waiver: Every input to the READY/CAUTION/BLOCKED verdict is produced by talking to the live machine and repo (npm test, tsc, prisma migrate status, gh pr view, git state); the rollup is deterministic in principle but its check-statuses are non-repeatable host-state diagnostics with no fixturable artifact, and manual developer confirmations gate the verdict. -->
<!-- lint:not-side-effecting R1 fired on the read `git branch --show-current`; the body has no mutating sink (git fetch updates remote-tracking refs only, gh pr view is read-only), so this is a false positive, not a side-effect. -->

# Deployment Checklist

You are running a pre-deployment validation checklist. Your job is to execute automated checks, prompt for manual confirmations, and produce a deployment confidence report. Every automated check must show real evidence (command output) — never claim a check passed without running it.

`$ARGUMENTS` may contain the target environment (e.g., `staging`, `production`). Default to production-level rigor if not specified.

## Step 0: Validate Input & Detect Project

0. **Validate target environment**: `$ARGUMENTS` must be one of `staging`, `production`, `preview`, or empty. If the value doesn't match, default to `production` and note the override in the report.

1. **Detect project type** from these markers (check for all applicable markers — a project may match multiple):

| Marker | Stack | Extra checks |
|---|---|---|
| `package.json` | Node.js/JS/TS | `npm test`, `npm run build`, lint |
| `next.config.*` | Next.js | `next lint`, `next build` (includes type check) |
| `tsconfig.json` | TypeScript | `tsc --noEmit` |
| `prisma/schema.prisma` | Prisma ORM | `npx prisma migrate status` |
| `pyproject.toml` | Python | `pytest`, `ruff check`, `mypy` |
| `vercel.json` or `.vercel/` | Vercel | Vercel-specific env check |
| `fly.toml` | Fly.io | Fly-specific notes |
| `railway.json` or `railway.toml` | Railway | Railway-specific notes |
| `Dockerfile` | Container | Image build check |

2. **Verify git state** (run these checks in order — stop on failure):
   - Run `git status` — working directory must be clean. If dirty, **stop** and ask the developer how to proceed.
   - Run `git branch --show-current` (or `git rev-parse --abbrev-ref HEAD` on older Git) — must be on a feature branch, not `main`/`master`. If on a trunk branch, **stop** and ask the developer to switch to a feature branch.
   - Detect the default branch: run `git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo origin/main` to resolve the trunk ref dynamically.
   - Run `git fetch origin` then `git log <trunk-ref>..HEAD --oneline` — show what will be deployed.

3. **Check tools available**: `gh auth status` for PR checks. If `gh` is not authenticated, skip PR status checks and note it in the report.

## Step 1: Automated Checks

Run each applicable check and record the result. Show the actual command output — never assume a check passed.

### 1a. Tests

- **Node.js**: Run `npm test` (or `yarn test` / `pnpm test` based on lockfile). Use a 120-second timeout (e.g., `timeout 120 npm test`). If the command times out, record as `FAIL — test command timed out` and continue to the next check.
- **Python**: Run `pytest` (or the test command from `pyproject.toml`).
- If no test command is found, record as `SKIP — no test command detected`.

### 1b. Build

- **Next.js**: Run `npm run build`. Note: `next build` type-checks by default unless `typescript.ignoreBuildErrors: true` is set in `next.config.*`. After build, still run `tsc --noEmit` (Step 1c) to catch issues outside the compilation scope.
- **Node.js (non-Next)**: Run `npm run build`. If the `build` script doesn't exist in `package.json`, record as `SKIP`.
- **Python**: Skip (no build step for most Python projects).
- **Docker**: If a `Dockerfile` is present, note it in the report. Do NOT run `docker build` — report the Dockerfile's presence and recommend the developer verify the image builds separately.

### 1c. Lint & Type Check

- **Next.js**: Run `npx --no-install next lint` if `next.config.js`, `next.config.ts`, or `next.config.mjs` is present. This applies `core-web-vitals` and App Router rules that `eslint .` would miss.
- **JS/TS (non-Next)**: Run `npx --no-install eslint . --max-warnings 0`. Run `npx --no-install prettier --check --ignore-unknown .` only if a Prettier config exists (`.prettierrc*`, `prettier` key in `package.json`, or `prettier.config.*`). If no config, record Prettier as `SKIP — no Prettier config found`.
- **TypeScript**: Run `npx --no-install tsc --noEmit` if `tsconfig.json` exists. Still run this for Next.js projects — `next build` type-checks compiled files but `tsc --noEmit` catches issues in files outside the build scope.
- **Python**: Run `ruff check .` and `mypy .` if available.
- If linters are not installed, record as `SKIP — linter not installed`.

### 1d. Database Migrations

- **Prisma**: Run `npx prisma migrate status`. If pending migrations exist, record as WARN: "Run `npx prisma migrate deploy` against the target database before deploying. Do not deploy application code ahead of schema if the migration includes breaking changes (column renames, drops)."
- If no Prisma schema found, record as `N/A`.

## Step 2: Release Readiness

### 2a. PR Status

- Run `gh pr view --json state,reviewDecision,mergeable,statusCheckRollup` to check:
  - PR exists and is open
  - `reviewDecision` is `APPROVED` (not `CHANGES_REQUESTED` or `REVIEW_REQUIRED`)
  - CI checks are passing (`statusCheckRollup` all successful)
  - `mergeable` is `MERGEABLE` (if `UNKNOWN`, record as WARN — GitHub is still computing; if `CONFLICTING`, record as FAIL)
- If no PR exists, warn: "No open PR found for this branch. Create one with `/workflows:ship` before deploying."

### 2b. Environment Variables

- Run `ls -1 .env* 2>/dev/null` to list env files present. Report which files exist. Do NOT use Read, cat, or any command that outputs file contents.
- **Vercel**: Skip local file check. Record WARN: "Verify environment variables are set in the Vercel dashboard under Settings > Environment Variables for the target environment."
- **Fly.io / Railway**: Skip local file check. Record WARN: "Verify environment variables are configured in the platform dashboard."
- **Other**: Check for `.env.production` or `.env`. If neither exists, record WARN.

### 2c. Changelog

- Check if `CHANGELOG.md` exists. If so, run `git diff <trunk-ref>..HEAD -- CHANGELOG.md` (using the trunk ref detected in Step 0) to verify it was updated.
- If no changelog file exists, record as `SKIP — no CHANGELOG.md`.

## Step 3: Manual Confirmations

Present the following questions to the developer and ask for confirmation. Use a multi-select format so all items can be answered at once:

1. **Rollback plan**: "Is a rollback plan documented or understood? (How to revert if this deployment fails)"
2. **Staging verification**: "Has this been verified on staging/preview? (If applicable)"
3. **Monitoring**: "Is monitoring and alerting configured for this service? (Error tracking, uptime, performance)"
4. **Stakeholder communication**: "Have relevant stakeholders been notified about this deployment? (If applicable)"

Mark each as CONFIRMED or SKIPPED based on the developer's response.

## Step 4: Deployment Confidence Report

Present a summary table with all results:

```
## Deployment Confidence Report

**Branch**: [branch-name]
**Target**: [environment from $ARGUMENTS or "production"]
**Commits**: [N commits ahead of main]

### Automated Checks
| Check | Status | Detail |
|-------|--------|--------|
| Tests | PASS/FAIL/SKIP | [summary] |
| Build | PASS/FAIL/SKIP | [summary] |
| Lint | PASS/FAIL/SKIP | [summary] |
| Type check | PASS/FAIL/SKIP/N/A | [summary] |
| Migrations | PASS/WARN/N/A | [summary] |

### Release Readiness
| Check | Status | Detail |
|-------|--------|--------|
| PR status | PASS/WARN | [approved/pending/no PR] |
| CI checks | PASS/FAIL/WARN | [summary] |
| Env vars | PASS/WARN | [file exists / check dashboard] |
| Changelog | PASS/SKIP | [updated / no changelog] |

### Manual Confirmations
| Item | Status |
|------|--------|
| Rollback plan | CONFIRMED/SKIPPED |
| Staging verified | CONFIRMED/SKIPPED |
| Monitoring | CONFIRMED/SKIPPED |
| Stakeholders notified | CONFIRMED/SKIPPED |

### Verdict
[READY — All checks passed / CAUTION — N warnings, review before deploying / BLOCKED — N failures must be resolved]
```

After presenting the report:

- If **READY**: "All checks passed. You can proceed with deployment."
- If **CAUTION**: "There are warnings to review. Proceed at your discretion."
- If **BLOCKED**: "There are failures that should be resolved before deploying. Address the FAIL items above."

## Rules

- Never claim a check passed without running the command and reading the output.
- Never read the contents of `.env` files — only check for their existence.
- Never deploy or trigger a deployment — this command only validates readiness.
- If a check fails, continue running the remaining checks. Report all results, not just the first failure.
- Record SKIP (not FAIL) when a check isn't applicable to the project.
- The developer makes the final go/no-go decision. Present evidence, not orders.
- Keep the report factual. No marketing language or false confidence.
